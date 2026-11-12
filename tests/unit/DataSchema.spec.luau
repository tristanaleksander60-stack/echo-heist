-- L1: Data/Schema (profile slice v1 defaults, size budget, migrations, repair),
-- Data/Keys (test isolation) and Data/Calendar (UTC days).

local serde = require("@lune/serde")

local Calendar = require("../../src/shared/Data/Calendar")
local Config = require("../../src/shared/Config")
local Keys = require("../../src/shared/Data/Keys")
local Schema = require("../../src/shared/Data/Schema")
local Assert = require("./Assert")

local DATA = Config.Data

-- The same rules lihfolk-systems PlayerData.findUnsavable enforces before a write.
local function unsavable(value: any, path: string): string?
	local t = type(value)
	if t == "number" then
		return if value ~= value or value == math.huge or value == -math.huge then path .. ": NaN/inf" else nil
	elseif t == "string" or t == "boolean" or t == "nil" then
		return nil
	elseif t ~= "table" then
		return path .. ": " .. t
	end
	local numberKeys, stringKeys, count = false, false, 0
	for k, v in value do
		count += 1
		if type(k) == "number" then
			numberKeys = true
		elseif type(k) == "string" then
			stringKeys = true
		else
			return path .. ": bad key type"
		end
		local problem = unsavable(v, path .. "." .. tostring(k))
		if problem then
			return problem
		end
	end
	if numberKeys and stringKeys then
		return path .. ": mixed table"
	end
	if numberKeys and #value ~= count then
		return path .. ": array with holes"
	end
	return nil
end

local function jsonBytes(value: any): number
	return #serde.encode("json", value)
end

-- A heavy slice: 30 levels (launch 6 + every planned location and drop, with room to
-- spare), every trophy and cosmetic owned, 40 future ornaments, a full shelf.
local function maxedHeist(): Schema.Heist
	local heist = Schema.defaultHeist()
	for i = 1, 30 do
		local id = "Level" .. i
		heist.levels[id] = {
			medals = { Haul = true, Crew = true, Clean = true, Diamond = true },
			best = {
				stars = 3,
				clones = 8,
				timeMs = 3599999,
				haul = 99999,
				at = 1800000000,
				recHash = string.rep("f", 64),
			},
			haulBest = 99999,
			plays = 99999,
			clears = 99999,
			firstClearAt = 1800000000,
		}
		heist.unlocked[id] = true
	end
	for id in DATA.Trophies do
		heist.trophies[id] = 1800000000
	end
	for i = 1, 40 do
		heist.trophies["Orn_Future" .. i] = 1800000000 -- later seasons
	end
	for id in DATA.Cosmetics do
		heist.cosmetics.owned[id] = true
	end
	for i = 1, 40 do
		heist.cosmetics.owned["Future_Cosmetic_" .. i] = true
	end
	for i = 1, DATA.SHELF_SLOTS do
		table.insert(heist.shelf, "Orn_Future" .. i)
	end
	return heist
end

return function(test)
	test("schema v1 defaults: fresh table per call, first level open, defaults equipped", function()
		Assert.eq(Schema.VERSION, 1, "version")
		local a, b = Schema.defaultHeist(), Schema.defaultHeist()
		Assert.truthy(a ~= b and a.levels ~= b.levels and a.cosmetics.equipped ~= b.cosmetics.equipped, "fresh")
		Assert.truthy(a.unlocked[DATA.LEVEL_ORDER[1]], "first level unlocked")
		for slot, id in DATA.DEFAULT_EQUIPPED do
			Assert.eq(a.cosmetics.equipped[slot], id, "equipped " .. slot)
		end
		Assert.eq(a.bagLevel, 0, "bag")
		Assert.eq(a.daily.lastClearDay, -1, "daily never")
		Assert.falsy(a.settings.reducedMotion or a.settings.relaxed or a.settings.colourBlindGlyphs, "settings off")
		Assert.eq(a.ftueStep, 0, "ftue")
		Assert.falsy(a.firstHeistDone, "first heist")
		a.cosmetics.equipped.cloneStyle = "Style_Noir"
		Assert.eq(Schema.defaultHeist().cosmetics.equipped.cloneStyle, "Style_Default", "no shared defaults")
	end)

	test("default and maxed slices are DataStore-safe and under the 16 KB budget", function()
		Assert.eq(unsavable(Schema.defaultHeist(), "Heist"), nil, "default saves")
		local heavy = maxedHeist()
		Assert.eq(unsavable(heavy, "Heist"), nil, "maxed saves")
		local bytes = jsonBytes(heavy)
		print(string.format("        maxed Heist slice: %d bytes (budget %d)", bytes, DATA.HEIST_SLICE_MAX_BYTES))
		Assert.le(bytes, DATA.HEIST_SLICE_MAX_BYTES, "maxed slice bytes")
		Assert.le(jsonBytes(Schema.defaultHeist()), 1000, "default slice is small")
	end)

	test("JSON round trip keeps the slice intact", function()
		local heavy = maxedHeist()
		local back = serde.decode("json", serde.encode("json", heavy))
		Assert.eq(#back.shelf, #heavy.shelf, "shelf")
		Assert.eq(back.levels.Level7.best.recHash, heavy.levels.Level7.best.recHash, "best")
		Assert.eq(#Schema.sanitize(back), 0, "decoded slice needs no repair")
	end)

	test("migrations: only steps 2..VERSION, run in order on the whole Data table", function()
		for version in Schema.MIGRATIONS do
			Assert.truthy(version >= 2 and version <= Schema.VERSION, "migration index " .. version)
		end
		-- Harness check with a temporary future step (never shipped): v1 -> v3 runs 2 then 3.
		local order = {}
		Schema.MIGRATIONS[2] = function(data)
			table.insert(order, 2)
			data.Heist.renamed = data.Heist.bagLevel
		end
		Schema.MIGRATIONS[3] = function(data)
			table.insert(order, 3)
			data.Heist.renamed += 1
		end
		local data = { Heist = Schema.defaultHeist() }
		data.Heist.bagLevel = 2
		local ok, err = pcall(Schema.migrate, data, 1, 3)
		Schema.MIGRATIONS[2] = nil
		Schema.MIGRATIONS[3] = nil
		Assert.truthy(ok, tostring(err))
		Assert.eq(table.concat(order, ","), "2,3", "order")
		Assert.eq((data.Heist :: any).renamed, 3, "both steps ran")
		local untouched = { Heist = Schema.defaultHeist() }
		Schema.migrate(untouched, Schema.VERSION)
		Assert.eq(#Schema.sanitize(untouched.Heist), 0, "current version: nothing to run")
	end)

	test("sanitize: a clean slice needs no repair", function()
		Assert.eq(#Schema.sanitize(Schema.defaultHeist()), 0, "default")
	end)

	test("sanitize repairs wrong types, clamps numbers and keeps purchases", function()
		local h = Schema.defaultHeist() :: any
		h.bagLevel = 99
		h.settings.relaxed = "yes"
		h.ftueStep = -4
		h.daily.streak = 0 / 0
		h.stats = "broken"
		h.unlocked[DATA.LEVEL_ORDER[1]] = nil
		h.cosmetics.owned.Style_Noir = true
		h.cosmetics.owned.Retired_Item = true -- unknown id from a rollback: kept
		h.cosmetics.owned.Junk = 1
		h.cosmetics.equipped.vanPaint = "Paint_Chrome" -- not owned
		h.cosmetics.equipped.trail = "Style_Noir" -- wrong slot
		h.cosmetics.equipped.cloneStyle = "Style_Noir" -- owned: stays
		h.cosmetics.equipped.bogusSlot = "Style_Noir"
		h.levels.FutureLevel = { medals = { Haul = true, Bad = 1 }, haulBest = 0 / 0, plays = 2.5, clears = 1 }
		h.levels.TwoDoors =
			{ medals = {}, best = { stars = "x" }, haulBest = 5, plays = 1, clears = 0, firstClearAt = 0 }
		local repairs = Schema.sanitize(h)
		Assert.truthy(#repairs > 0, "repairs listed")
		Assert.eq(h.bagLevel, DATA.Bag.MAX_LEVEL, "bag clamped")
		Assert.eq(h.settings.relaxed, false, "setting reset")
		Assert.eq(h.ftueStep, 0, "ftue clamped")
		Assert.eq(h.daily.streak, 0, "NaN streak reset")
		Assert.eq(h.stats.heists, 0, "stats rebuilt")
		Assert.truthy(h.unlocked[DATA.LEVEL_ORDER[1]], "first level always open")
		Assert.truthy(h.cosmetics.owned.Style_Noir and h.cosmetics.owned.Retired_Item, "purchases kept")
		Assert.eq(h.cosmetics.owned.Junk, nil, "junk value dropped")
		Assert.eq(h.cosmetics.equipped.vanPaint, DATA.DEFAULT_EQUIPPED.vanPaint, "unowned paint unequipped")
		Assert.eq(h.cosmetics.equipped.trail, DATA.DEFAULT_EQUIPPED.trail, "wrong slot unequipped")
		Assert.eq(h.cosmetics.equipped.cloneStyle, "Style_Noir", "owned style stays")
		Assert.eq(h.cosmetics.equipped.bogusSlot, nil, "unknown slot removed")
		Assert.truthy(h.levels.FutureLevel.medals.Haul, "unknown level kept")
		Assert.eq(h.levels.FutureLevel.medals.Bad, nil, "junk medal dropped")
		Assert.eq(h.levels.FutureLevel.haulBest, 0, "NaN best haul")
		Assert.eq(h.levels.FutureLevel.plays, 2, "fraction floored")
		Assert.eq(h.levels.FutureLevel.firstClearAt, 0, "missing field filled")
		Assert.eq(h.levels.TwoDoors.best, nil, "malformed best dropped")
		Assert.eq(h.levels.TwoDoors.haulBest, 5, "good field kept")
		Assert.eq(#Schema.sanitize(h), 0, "idempotent")
	end)

	test("sanitize keeps the shelf dense, unique, owned and within the slots", function()
		local h = Schema.defaultHeist()
		h.trophies.Trophy_BackRoom = 1
		h.trophies.Trophy_TwoDoors = 2
		h.shelf = { "Trophy_BackRoom", "Trophy_BackRoom", "Trophy_NightClerk", "Trophy_TwoDoors" }
		Schema.sanitize(h)
		Assert.eq(table.concat(h.shelf, ","), "Trophy_BackRoom,Trophy_TwoDoors", "shelf")
		for i = 1, DATA.SHELF_SLOTS + 3 do
			h.trophies["T" .. i] = i
			table.insert(h.shelf, "T" .. i)
		end
		Schema.sanitize(h)
		Assert.eq(#h.shelf, DATA.SHELF_SLOTS, "shelf capped")
	end)

	test("keys: Studio and the test universe use _TEST_ keys; live does not", function()
		Assert.truthy(Keys.isTestEnvironment(true, 123), "studio")
		Assert.truthy(Keys.isTestEnvironment(false, DATA.TEST_UNIVERSE_IDS[1]), "test universe")
		Assert.falsy(Keys.isTestEnvironment(false, 999), "live")
		Assert.eq(Keys.profilePrefix(false), "U_", "live prefix")
		Assert.eq(Keys.profilePrefix(true), "_TEST_U_", "test prefix")
		Assert.eq(Keys.profileKey(42, true), "_TEST_U_42", "test key")
		Assert.eq(Keys.ghostKey("BackRoom", 42, false), "G_BackRoom_42", "ghost key")
		Assert.eq(Keys.ghostKey("BackRoom", 42, true), "_TEST_G_BackRoom_42", "test ghost key")
		Assert.falsy(pcall(Keys.ghostKey, "Back_Room/../x", 1, true), "level id must be alphanumeric")
		Assert.truthy(Keys.isWritable("_TEST_smoke", true), "test env writes test keys")
		Assert.falsy(Keys.isWritable("U_42", true), "test env never writes live keys")
		Assert.falsy(Keys.isWritable("_TEST_U_42", false), "live never writes test keys")
	end)

	test("calendar: civil dates round trip and match known days", function()
		Assert.eq(Calendar.daysFromCivil(1970, 1, 1), 0, "epoch")
		Assert.eq(Calendar.daysFromCivil(2000, 3, 1), 11017, "2000-03-01")
		local dec3 = Calendar.dayIndex(1764720000) -- 2025-12-03T00:00:00Z
		Assert.eq(dec3, Calendar.daysFromCivil(2025, 12, 3), "unix to day")
		for day = 19000, 22000, 7 do
			local y, m, d = Calendar.civilFromDays(day)
			Assert.eq(Calendar.daysFromCivil(y, m, d), day, "round trip " .. day)
		end
		local y, m, d = Calendar.civilFromDays(Calendar.daysFromCivil(2028, 2, 29))
		Assert.eq(string.format("%d-%d-%d", y, m, d), "2028-2-29", "leap day")
		Assert.eq(Calendar.dayOf({ 2027, 1, 1 }) - Calendar.dayOf({ 2026, 12, 31 }), 1, "year boundary")
		Assert.eq(Calendar.secondsUntilReset(1764720000 + 3600), 82800, "one hour after reset")
		Assert.eq(Calendar.dayIndex(1764720000 - 1), dec3 - 1, "one second before midnight")
		Assert.truthy(Calendar.onOrBefore(dec3, nil), "no end date")
		Assert.falsy(Calendar.onOrBefore(dec3 + 1, { 2025, 12, 3 }), "after the last day")
	end)
end
