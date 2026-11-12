-- L1: Data/Store (catalog rules, earned-currency buys, equip, bag levels, shelf,
-- Robux product prompt checks and grants). Also the hard monetization rules.

local Calendar = require("../../src/shared/Data/Calendar")
local Config = require("../../src/shared/Config")
local ProductPrices = require("../../src/shared/Data/ProductPrices")
local Schema = require("../../src/shared/Data/Schema")
local Store = require("../../src/shared/Data/Store")
local Assert = require("./Assert")

local DATA = Config.Data
local TODAY = Calendar.daysFromCivil(2026, 12, 10)
local AFTER_EVENT = Calendar.dayOf(DATA.Event.LAST) + 1

local function wallet(balances: { [string]: number }): (string) -> number
	return function(currency: string): number
		return balances[currency] or 0
	end
end

-- Temporarily gives a product a real-looking id (ids are 0 until the dashboard has them).
local function withId(key: string, fn: () -> ())
	local product = DATA.Products[key]
	local old = product.id
	product.id = 123456
	local ok, err = pcall(fn)
	product.id = old
	assert(ok, err)
end

return function(test)
	test("the store config is consistent", function()
		local ok, err = pcall(Store.validateCatalog)
		Assert.truthy(ok, tostring(err))
	end)

	test("monetization rules: nothing random, no Robux-to-currency, no Robux prices in config", function()
		for name, def in DATA.Currencies do
			Assert.eq(def.paid, false, name .. " must never be buyable with Robux")
		end
		for key, product in DATA.Products do
			Assert.eq((product :: any).price, nil, key .. ": no hard-coded Robux price")
			Assert.eq((product :: any).odds, nil, key .. ": no paid randomness")
			for _, id in product.grants do
				Assert.truthy(DATA.Cosmetics[id] ~= nil, key .. " grants a fixed cosmetic " .. id)
			end
		end
		local buyable = Store.buyable()
		for id, item in buyable do
			Assert.truthy(item.price.currency ~= "Stars", id .. ": Stars are never spent")
			Assert.eq(DATA.Cosmetics[id] and DATA.Cosmetics[id].product, nil, id .. ": Robux items are not soft items")
		end
		Assert.truthy(buyable.Paint_MidnightBlue and buyable.Trail_Mint and buyable.Trophy_SnowGlobe, "soft items")
		Assert.eq(buyable.Style_Default, nil, "defaults are not sold")
		Assert.eq(buyable.Style_GoldGhost, nil, "Robux styles are not in Data.Buy")
	end)

	test("buy with earned currency: price, ownership, end date", function()
		local heist = Schema.defaultHeist()
		local ok, code, price = Store.canBuy(heist, "Paint_MidnightBlue", TODAY, wallet({ Cash = 2500 }))
		Assert.truthy(ok and code == "Ok", "affordable")
		Assert.eq(price and price.amount, 2500, "server price")
		Assert.eq(
			select(2, Store.canBuy(heist, "Paint_MidnightBlue", TODAY, wallet({ Cash = 2499 }))),
			"NotEnough",
			"short"
		)
		Store.applyBuy(heist, "Paint_MidnightBlue", 1)
		Assert.truthy(heist.cosmetics.owned.Paint_MidnightBlue, "owned")
		Assert.eq(
			select(2, Store.canBuy(heist, "Paint_MidnightBlue", TODAY, wallet({ Cash = 1e6 }))),
			"AlreadyOwned",
			"twice"
		)
		Assert.eq(
			select(2, Store.canBuy(heist, "Style_GoldGhost", TODAY, wallet({ Cash = 1e6 }))),
			"Unavailable",
			"Robux item"
		)
		Assert.eq(select(2, Store.canBuy(heist, "Nope", TODAY, wallet({ Cash = 1e6 }))), "Unavailable", "unknown")
		local candy = wallet({ CandyCanes = 100 })
		Assert.truthy((Store.canBuy(heist, "Hat_Santa", TODAY, candy)), "event item in the event")
		Assert.eq(select(2, Store.canBuy(heist, "Hat_Santa", AFTER_EVENT, candy)), "Unavailable", "after the event")
		Store.applyBuy(heist, "Trophy_SnowGlobe", 7)
		Assert.eq(heist.trophies.Trophy_SnowGlobe, 7, "trophy bought")
		Assert.eq(heist.shelf[1], "Trophy_SnowGlobe", "trophy on the shelf")
	end)

	test("equip: defaults and owned items in their own slot only", function()
		local heist = Schema.defaultHeist()
		Assert.truthy((Store.canEquip(heist, "vanPaint", "Paint_Default")), "default")
		Assert.eq(select(2, Store.canEquip(heist, "vanPaint", "Paint_Chrome")), "NotOwned", "not owned")
		heist.cosmetics.owned.Paint_Chrome = true
		Assert.truthy((Store.canEquip(heist, "vanPaint", "Paint_Chrome")), "owned")
		Assert.eq(select(2, Store.canEquip(heist, "trail", "Paint_Chrome")), "Invalid", "wrong slot")
		Assert.eq(select(2, Store.canEquip(heist, "hat", "Paint_Chrome")), "Invalid", "unknown slot")
	end)

	test("bag levels cost Cash in order and stop at the top", function()
		for level = 0, DATA.Bag.MAX_LEVEL - 1 do
			Assert.eq(Store.nextBagCost(level), DATA.Bag.COSTS[level + 1], "level " .. level)
		end
		Assert.eq(Store.nextBagCost(DATA.Bag.MAX_LEVEL), nil, "max")
	end)

	test("shelf: owned, unique, within the slots", function()
		local heist = Schema.defaultHeist()
		heist.trophies.Trophy_BackRoom = 1
		heist.trophies.Trophy_TwoDoors = 2
		Assert.truthy((Store.validShelf(heist, { "Trophy_TwoDoors", "Trophy_BackRoom" })), "reorder")
		Assert.truthy((Store.validShelf(heist, {})), "empty")
		Assert.eq(select(2, Store.validShelf(heist, { "Trophy_LightsOut" })), "NotOwned", "not owned")
		Assert.eq(select(2, Store.validShelf(heist, { "Trophy_BackRoom", "Trophy_BackRoom" })), "Invalid", "dupe")
		local many = {}
		for i = 1, DATA.SHELF_SLOTS + 1 do
			heist.trophies["T" .. i] = i
			table.insert(many, "T" .. i)
		end
		Assert.eq(select(2, Store.validShelf(heist, many)), "Invalid", "too many")
	end)

	test("Robux prices come only from GetProductInfoAsync; placeholders and errors give none", function()
		local calls = 0
		local failNext = 1
		local prices = ProductPrices.new(function(productId: number): { [string]: any }
			calls += 1
			if failNext > 0 then
				failNext -= 1
				error("HTTP 500")
			end
			return { ProductId = productId, PriceInRobux = 99 }
		end)
		Assert.eq(prices:getAsync("StyleNoir"), nil, "id 0: no price")
		Assert.eq(calls, 0, "id 0 never asks Roblox")
		Assert.eq(prices:getAsync("Nope"), nil, "unknown key")
		withId("StyleNoir", function()
			Assert.eq(prices:getAsync("StyleNoir"), 99, "price after one retry")
			Assert.eq(calls, 2, "error retried")
			Assert.eq(prices:getAsync("StyleNoir"), 99, "cached")
			Assert.eq(calls, 2, "no second fetch")
		end)
		local broken = ProductPrices.new(function(): { [string]: any }
			error("down")
		end)
		withId("StyleNoir", function()
			Assert.eq(broken:getAsync("StyleNoir"), nil, "all attempts failed: no price shown")
		end)
	end)

	test("Robux products: id 0 never prompts; owned or ended products are refused at prompt", function()
		local heist = Schema.defaultHeist()
		Assert.eq(select(2, Store.canPromptProduct(heist, "StyleNoir", TODAY)), "Unavailable", "placeholder id")
		Assert.eq(select(2, Store.canPromptProduct(heist, "Nope", TODAY)), "Unavailable", "unknown")
		withId("StyleNoir", function()
			Assert.truthy((Store.canPromptProduct(heist, "StyleNoir", TODAY)), "on sale")
			Assert.truthy(Store.grantProduct(heist, "StyleNoir"), "grant")
			Assert.eq(select(2, Store.canPromptProduct(heist, "StyleNoir", TODAY)), "AlreadyOwned", "owned")
			Assert.truthy(Store.grantProduct(heist, "StyleNoir"), "a redelivered receipt still succeeds")
		end)
		withId("ChristmasCrew", function()
			heist.cosmetics.owned.Style_Santa = true -- part of the bundle owned already
			Assert.truthy((Store.canPromptProduct(heist, "ChristmasCrew", TODAY)), "bundle still offered")
			Assert.eq(
				select(2, Store.canPromptProduct(heist, "ChristmasCrew", Calendar.dayOf({ 2027, 1, 5 }))),
				"Unavailable",
				"bundle ends after Jan 4"
			)
			Store.grantProduct(heist, "ChristmasCrew")
			for _, id in DATA.Products.ChristmasCrew.grants do
				Assert.truthy(heist.cosmetics.owned[id], "bundle grants " .. id)
			end
			Assert.eq(select(2, Store.canPromptProduct(heist, "ChristmasCrew", TODAY)), "AlreadyOwned", "all owned")
		end)
		Assert.falsy(Store.grantProduct(heist, "Nope"), "unknown product grants nothing")
	end)
end
