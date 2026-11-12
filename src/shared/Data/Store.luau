--!strict
-- Data/Store: cosmetics, trophies for earned currency, bag levels and Robux
-- products (pure; Lune-tested). MASTERPLAN §5.1, §5.4.
--
-- Hard rules kept here: nothing is random; nothing sells Cash, Stars or Candy Canes
-- for Robux; Robux products are fixed cosmetic contents; prices on screen come from
-- GetProductInfoAsync (no Robux numbers exist in config). Products are one per
-- player (limit 1) and refused at prompt time when everything in them is owned.

local Calendar = require("./Calendar")
local Config = require("../Config")
local Schema = require("./Schema")

local Store = {}

export type Price = { currency: string, amount: number }

local function isWhole(n: any, min: number): boolean
	return type(n) == "number" and n == n and n >= min and n < 2 ^ 53 and math.floor(n) == n
end

-- Errors with a clear message if the store config is inconsistent (startup and tests).
function Store.validateCatalog()
	local data = Config.Data
	local function checkPrice(label: string, price: any)
		assert(type(price) == "table", `{label}: price must be a table`)
		local def = data.Currencies[price.currency]
		assert(def ~= nil, `{label}: unknown currency {price.currency}`)
		assert(price.currency ~= "Stars", `{label}: Stars are never spent`)
		assert(isWhole(price.amount, 1), `{label}: price must be a whole number >= 1`)
	end
	for slot, id in data.DEFAULT_EQUIPPED do
		local def = data.Cosmetics[id]
		assert(
			def and def.default == true and def.slot == slot,
			`Store: default {id} for {slot} must be a default item`
		)
	end
	for id, def in data.Cosmetics do
		assert(string.match(id, "^[%w_]+$") and #id <= 48, `Cosmetic {id}: bad id`)
		assert(data.DEFAULT_EQUIPPED[def.slot] ~= nil, `Cosmetic {id}: unknown slot {def.slot}`)
		local ways = (if def.default then 1 else 0) + (if def.price then 1 else 0) + (if def.product then 1 else 0)
		assert(ways <= 1, `Cosmetic {id}: set at most one of default, price, product`)
		if def.price then
			checkPrice(`Cosmetic {id}`, def.price)
		end
		if def.product then
			local product = data.Products[def.product]
			assert(product and table.find(product.grants, id), `Cosmetic {id}: product {def.product} must grant it`)
		end
		if def.lastDay then
			Calendar.dayOf(def.lastDay)
		end
	end
	for key, product in data.Products do
		assert(string.match(key, "^[%w_]+$") and #key <= 48, `Product {key}: bad key`)
		assert(isWhole(product.id, 0), `Product {key}: id must be a whole number (0 = not created yet)`)
		assert(type(product.grants) == "table" and #product.grants >= 1, `Product {key}: grants nothing`)
		for _, id in product.grants do
			local def = data.Cosmetics[id]
			assert(def and def.product == key, `Product {key}: grant {id} must be a cosmetic with product = {key}`)
		end
		if product.lastDay then
			Calendar.dayOf(product.lastDay)
		end
	end
	for id, def in data.Trophies do
		assert(string.match(id, "^[%w_]+$") and #id <= 48, `Trophy {id}: bad id`)
		assert(def.kind == "level" or def.kind == "ornament" or def.kind == "event", `Trophy {id}: bad kind`)
		if def.price then
			checkPrice(`Trophy {id}`, def.price)
		end
	end
	assert(#data.Bag.COSTS == data.Bag.MAX_LEVEL, "Bag: one cost per level")
	for i, cost in data.Bag.COSTS do
		assert(isWhole(cost, 1), `Bag: COSTS[{i}] must be a whole number >= 1`)
	end
end

-- Everything Data.Buy accepts: cosmetics and trophies with an earned-currency price.
function Store.buyable(): { [string]: { price: Price, lastDay: Calendar.Date?, kind: string } }
	local out = {}
	for id, def in Config.Data.Cosmetics do
		if def.price then
			out[id] = { price = def.price, lastDay = def.lastDay, kind = "cosmetic" }
		end
	end
	for id, def in Config.Data.Trophies do
		if def.price then
			out[id] = { price = def.price, lastDay = def.lastDay, kind = "trophy" }
		end
	end
	return out
end

function Store.owns(heist: Schema.Heist, itemId: string): boolean
	if Config.Data.Trophies[itemId] then
		return heist.trophies[itemId] ~= nil
	end
	return Schema.isOwnedCosmetic(heist, itemId)
end

-- (ok, code, price). balance(currency) returns the player's balance.
function Store.canBuy(
	heist: Schema.Heist,
	itemId: string,
	today: number,
	balance: (string) -> number
): (boolean, string, Price?)
	local item = Store.buyable()[itemId]
	if not item then
		return false, "Unavailable", nil
	end
	if Store.owns(heist, itemId) then
		return false, "AlreadyOwned", nil
	end
	if not Calendar.onOrBefore(today, item.lastDay) then
		return false, "Unavailable", nil
	end
	if balance(item.price.currency) < item.price.amount then
		return false, "NotEnough", nil
	end
	return true, "Ok", item.price
end

-- Marks a bought item owned (call after the currency was spent, in the same block).
function Store.applyBuy(heist: Schema.Heist, itemId: string, now: number)
	if Config.Data.Trophies[itemId] then
		heist.trophies[itemId] = now
		if #heist.shelf < Config.Data.SHELF_SLOTS then
			table.insert(heist.shelf, itemId)
		end
	else
		heist.cosmetics.owned[itemId] = true
	end
end

function Store.canEquip(heist: Schema.Heist, slot: string, itemId: string): (boolean, string)
	local def = Config.Data.Cosmetics[itemId]
	if Config.Data.DEFAULT_EQUIPPED[slot] == nil or def == nil or def.slot ~= slot then
		return false, "Invalid"
	end
	if not Schema.isOwnedCosmetic(heist, itemId) then
		return false, "NotOwned"
	end
	return true, "Ok"
end

-- Cash price of the next bag level, or nil at the top.
function Store.nextBagCost(bagLevel: number): number?
	return Config.Data.Bag.COSTS[bagLevel + 1]
end

-- A new van shelf: unique, owned trophy ids, at most SHELF_SLOTS.
function Store.validShelf(heist: Schema.Heist, ids: { string }): (boolean, string)
	if #ids > Config.Data.SHELF_SLOTS then
		return false, "Invalid"
	end
	local seen: { [string]: boolean } = {}
	for _, id in ids do
		if seen[id] or heist.trophies[id] == nil then
			return false, if seen[id] then "Invalid" else "NotOwned"
		end
		seen[id] = true
	end
	return true, "Ok"
end

-- Prompt-time check for a Robux product (receipts are never refused).
function Store.canPromptProduct(heist: Schema.Heist, productKey: string, today: number): (boolean, string)
	local product = Config.Data.Products[productKey]
	if not product or product.id <= 0 then
		return false, "Unavailable"
	end
	if not Calendar.onOrBefore(today, product.lastDay) then
		return false, "Unavailable"
	end
	for _, id in product.grants do
		if not Schema.isOwnedCosmetic(heist, id) then
			return true, "Ok"
		end
	end
	return false, "AlreadyOwned"
end

-- Grant for a paid receipt: always succeeds (the player paid); idempotent per item.
function Store.grantProduct(heist: Schema.Heist, productKey: string): boolean
	local product = Config.Data.Products[productKey]
	if not product then
		return false
	end
	for _, id in product.grants do
		heist.cosmetics.owned[id] = true
	end
	return true
end

return Store
