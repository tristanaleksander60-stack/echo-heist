-- L1: Data/DailyVault (streak with grace, rotation, advent ornaments, catch-up, board haul).

local Calendar = require("../../src/shared/Data/Calendar")
local Config = require("../../src/shared/Config")
local DailyVault = require("../../src/shared/Data/DailyVault")
local Schema = require("../../src/shared/Data/Schema")
local Assert = require("./Assert")

local DATA = Config.Data
local DEC = function(d: number): number
	return Calendar.daysFromCivil(DATA.Advent.YEAR, 12, d)
end
local NOV20 = Calendar.daysFromCivil(DATA.Advent.YEAR, 11, 20)
local NOW = 1796000000

local function result(o: { [string]: any }?): DailyVault.DailyResult
	local r: { [string]: any } = { cleared = true, haul = 400, clones = 5, tainted = false, relaxed = false }
	for k, v in o or {} do
		r[k] = v
	end
	return r :: any
end

return function(test)
	test("streak: first clear 1, next day +1, one grace day, then reset", function()
		local grace = DATA.Daily.GRACE_DAYS
		Assert.eq(grace, 1, "plan: one grace day")
		local first, s1 = DailyVault.evaluateStreak(-1, 0, 100, grace)
		Assert.truthy(first and s1 == 1, "first ever")
		local _, s2 = DailyVault.evaluateStreak(100, 1, 101, grace)
		Assert.eq(s2, 2, "next day")
		local _, s3 = DailyVault.evaluateStreak(101, 2, 103, grace)
		Assert.eq(s3, 3, "one missed day is forgiven")
		local _, s4 = DailyVault.evaluateStreak(103, 3, 106, grace)
		Assert.eq(s4, 1, "two missed days reset")
		local again = DailyVault.evaluateStreak(106, 1, 106, grace)
		Assert.falsy(again, "same day is not a first clear")
		Assert.falsy((DailyVault.evaluateStreak(106, 1, 105, grace)), "clock moved back")
		Assert.eq(DailyVault.currentStreak(100, 5, 102, grace), 5, "shown streak within grace")
		Assert.eq(DailyVault.currentStreak(100, 5, 103, grace), 0, "shown streak after it lapsed")
		Assert.eq(DailyVault.currentStreak(-1, 0, 103, grace), 0, "never")
	end)

	test("vault rotation and ornaments by UTC date", function()
		local seen = {}
		for day = NOV20, NOV20 + 23 do
			local v = DailyVault.vaultFor(day)
			Assert.truthy(v >= 1 and v <= DATA.Daily.VAULT_COUNT, "in range")
			seen[v] = true
		end
		Assert.eq(#seen, DATA.Daily.VAULT_COUNT, "every vault comes up")
		Assert.eq(DailyVault.vaultFor(NOV20), DailyVault.vaultFor(NOV20 + DATA.Daily.VAULT_COUNT), "repeats")
		Assert.eq(DailyVault.vaultFor(DEC(3)), 1, "launch day is vault 1 (slot n = daily design n)")
		Assert.eq(DailyVault.vaultFor(DEC(14)), DATA.Daily.VAULT_COUNT, "Dec 14 is the last vault")
		Assert.eq(DailyVault.adventDay(DEC(3)), 3, "Dec 3")
		Assert.eq(DailyVault.adventDay(DEC(24)), 24, "Dec 24")
		Assert.eq(DailyVault.adventDay(DEC(2)), nil, "before launch")
		Assert.eq(DailyVault.adventDay(DEC(25)), nil, "after Christmas Eve")
		Assert.eq(DailyVault.adventDay(DEC(3) + 365), nil, "next year")
		Assert.eq(DailyVault.ornamentFor(DEC(7)), "Orn_Advent2026_07", "advent ornament")
		local nov = DailyVault.ornamentFor(NOV20)
		Assert.truthy(string.match(nov, "^Orn_Vault%d%d$") ~= nil, "vault ornament " .. nov)
		for day = NOV20, DEC(31) do
			Assert.truthy(DATA.Trophies[DailyVault.ornamentFor(day)] ~= nil, "ornament exists for day " .. day)
		end
	end)

	test("play mode: today, advent catch-up until Dec 31, never the future", function()
		Assert.eq(DailyVault.playMode(DEC(10), DEC(10)), "today", "today")
		Assert.eq(DailyVault.playMode(DEC(4), DEC(10)), "catchUp", "missed advent day")
		Assert.eq(DailyVault.playMode(DEC(4), DEC(31)), "catchUp", "last catch-up day")
		Assert.eq(DailyVault.playMode(DEC(4), DEC(31) + 1), nil, "catch-up closed")
		Assert.eq(DailyVault.playMode(DEC(11), DEC(10)), nil, "future day")
		Assert.eq(DailyVault.playMode(NOV20, NOV20 + 1), nil, "past non-advent day")
		Assert.eq(DailyVault.playMode(0.5, DEC(10)), nil, "fractional day")
	end)

	test("first clear today: Star, Cash, Candy Canes in the event, ornament; once per day", function()
		local heist = Schema.defaultHeist()
		local s = assert(DailyVault.apply(heist, DEC(5), DEC(5), result(), NOW))
		Assert.truthy(s.firstClear, "first")
		Assert.eq(s.stars, DATA.Daily.FIRST_CLEAR_STARS, "star")
		Assert.eq(s.cash, DATA.Daily.FIRST_CLEAR_CASH, "cash")
		Assert.eq(s.candyCanes, DATA.Daily.FIRST_CLEAR_CANDY_CANES, "candy canes in the event")
		Assert.eq(s.ornament, "Orn_Advent2026_05", "ornament")
		Assert.eq(s.streak, 1, "streak")
		Assert.eq(heist.daily.stars, 1, "daily stars saved")
		Assert.eq(s.totalStars, 1, "total stars")
		Assert.eq(#heist.shelf, 0, "ornaments go on the tree, not the shelf")
		local again = assert(DailyVault.apply(heist, DEC(5), DEC(5), result(), NOW))
		Assert.falsy(again.firstClear, "once per day")
		Assert.eq(again.cash + again.stars, 0, "nothing twice")
		local nextDay = assert(DailyVault.apply(heist, DEC(6), DEC(6), result(), NOW))
		Assert.eq(nextDay.streak, 2, "streak grows")
		Assert.eq(heist.daily.bestStreak, 2, "best streak")
	end)

	test("no Candy Canes outside the event", function()
		local heist = Schema.defaultHeist()
		local s = assert(DailyVault.apply(heist, NOV20, NOV20, result(), NOW))
		Assert.eq(s.candyCanes, 0, "no candy in November")
		Assert.truthy(s.ornament ~= nil, "vault ornament")
	end)

	test("catch-up: the missed day's ornament and rewards, once, without touching the streak", function()
		local heist = Schema.defaultHeist()
		assert(DailyVault.apply(heist, DEC(10), DEC(10), result(), NOW))
		local c = assert(DailyVault.apply(heist, DEC(4), DEC(10), result(), NOW))
		Assert.eq(c.mode, "catchUp", "mode")
		Assert.truthy(c.firstClear, "rewarded")
		Assert.eq(c.ornament, "Orn_Advent2026_04", "missed ornament")
		Assert.eq(heist.daily.lastClearDay, DEC(10), "streak day untouched")
		Assert.eq(heist.daily.streak, 1, "streak untouched")
		local twice = assert(DailyVault.apply(heist, DEC(4), DEC(11), result(), NOW))
		Assert.falsy(twice.firstClear, "a catch-up day pays once")
		local _, why = DailyVault.apply(heist, DEC(12), DEC(11), result(), NOW)
		Assert.eq(why, "WrongDay", "future refused")
	end)

	test("tainted and uncleared runs; the board haul is today's untainted, non-Relaxed best", function()
		local heist = Schema.defaultHeist()
		local t = assert(DailyVault.apply(heist, DEC(5), DEC(5), result({ tainted = true, haul = 9000 }), NOW))
		Assert.falsy(t.firstClear or t.newHaulBest, "tainted earns nothing")
		Assert.eq(heist.daily.haulBest, 0, "tainted not on the board")
		local miss = assert(DailyVault.apply(heist, DEC(5), DEC(5), result({ cleared = false, haul = 300 }), NOW))
		Assert.falsy(miss.firstClear, "not cleared")
		Assert.truthy(miss.newHaulBest, "board still counts the haul")
		assert(DailyVault.apply(heist, DEC(5), DEC(5), result({ cleared = false, haul = 900, relaxed = true }), NOW))
		Assert.eq(heist.daily.haulBest, 300, "Relaxed is off the board")
		assert(DailyVault.apply(heist, DEC(6), DEC(6), result({ cleared = false, haul = 100 }), NOW))
		Assert.eq(heist.daily.haulBest, 100, "a new day starts a new board entry")
		Assert.eq(heist.daily.haulDay, DEC(6), "board day")
	end)

	test("validateResult refuses junk", function()
		Assert.truthy(DailyVault.validateResult(result()), "good")
		Assert.falsy((DailyVault.validateResult(result({ cleared = 1 }))), "flag type")
		Assert.falsy((DailyVault.validateResult(result({ haul = -5 }))), "negative haul")
		Assert.falsy((DailyVault.validateResult(result({ clones = 0 / 0 }))), "NaN clones")
		Assert.falsy((DailyVault.validateResult(nil)), "nil")
	end)
end
