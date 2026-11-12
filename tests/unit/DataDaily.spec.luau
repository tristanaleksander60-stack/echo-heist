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
	local r: { [string]: any } =
		{ cleared = true, haul = 400, clones = 5, timeMs = 120000, tainted = false, relaxed = false }
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

	test("daily reset: a vault started before the reset is judged on the day it started", function()
		local heist = Schema.defaultHeist()
		assert(DailyVault.apply(heist, DEC(5), DEC(5), result(), NOW))
		local s = assert(DailyVault.apply(heist, DEC(6), DEC(7), result(), NOW, DEC(6)))
		Assert.eq(s.mode, "today", "still today's vault")
		Assert.truthy(s.firstClear, "first clear of its day")
		Assert.eq(heist.daily.lastClearDay, DEC(6), "streak day = the start day")
		Assert.eq(heist.daily.streak, 2, "the streak grows")
		local late = assert(DailyVault.apply(heist, DEC(7), DEC(7), result(), NOW))
		Assert.truthy(late.firstClear and late.streak == 3, "the next day's clear still counts")
		local _, why = DailyVault.apply(Schema.defaultHeist(), NOV20, NOV20 + 2, result(), NOW, NOV20)
		Assert.eq(why, "WrongDay", "more than one day back is not honoured")
		local _, why2 = DailyVault.apply(Schema.defaultHeist(), NOV20, NOV20 + 1, result(), NOW)
		Assert.eq(why2, "WrongDay", "without a start day the old rule holds")
		local ok = DailyVault.apply(Schema.defaultHeist(), NOV20, NOV20 + 1, result(), NOW, NOV20)
		Assert.truthy(ok ~= nil, "outside the advent window the start day saves it")
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

	test("board tie-break: same haul, fewer clones first, then less time (the sim's timeMs)", function()
		local heist = Schema.defaultHeist()
		local function apply(o: { [string]: any }): DailyVault.DailySummary
			return assert(DailyVault.apply(heist, DEC(5), DEC(5), result(o), NOW))
		end
		Assert.truthy(apply({ haul = 300, clones = 5, timeMs = 150000 }).newHaulBest, "first entry")
		Assert.falsy(apply({ haul = 300, clones = 5, timeMs = 150000 }).newHaulBest, "an exact tie keeps the first")
		Assert.falsy(apply({ haul = 300, clones = 5, timeMs = 160000 }).newHaulBest, "slower loses")
		Assert.truthy(apply({ haul = 300, clones = 5, timeMs = 140000 }).newHaulBest, "faster wins the tie")
		Assert.eq(heist.daily.haulTimeMs, 140000, "board time")
		Assert.truthy(apply({ haul = 300, clones = 4, timeMs = 170000 }).newHaulBest, "fewer clones beat time")
		Assert.eq(heist.daily.haulClones, 4, "board clones")
		Assert.falsy(apply({ haul = 290, clones = 1, timeMs = 1000 }).newHaulBest, "haul comes first")
		Assert.truthy(apply({ haul = 310, clones = 5, timeMs = 179000 }).newHaulBest, "a bigger haul always wins")
		Assert.eq(heist.daily.haulBest, 310, "board haul")
		local empty = { haul = 0, clones = 0, timeMs = 0 }
		Assert.falsy(DailyVault.beatsBoard({ haul = 0, clones = 0, timeMs = 0 }, empty), "an empty haul never boards")
		-- A new day starts a new entry: the old tie-breaks do not carry over.
		local nextDay = assert(DailyVault.apply(heist, DEC(6), DEC(6), result({ haul = 50, clones = 5 }), NOW))
		Assert.truthy(nextDay.newHaulBest, "new day")
		Assert.eq(heist.daily.haulClones, 5, "clones of the new entry")
		Assert.eq(heist.daily.haulTimeMs, 120000, "time of the new entry")
	end)

	test("validateResult refuses junk", function()
		Assert.truthy(DailyVault.validateResult(result()), "good")
		Assert.falsy((DailyVault.validateResult(result({ cleared = 1 }))), "flag type")
		Assert.falsy((DailyVault.validateResult(result({ haul = -5 }))), "negative haul")
		Assert.falsy((DailyVault.validateResult(result({ clones = 0 / 0 }))), "NaN clones")
		Assert.falsy((DailyVault.validateResult(result({ timeMs = false }))), "timeMs missing")
		Assert.falsy((DailyVault.validateResult(result({ timeMs = 1.5 }))), "fractional timeMs")
		Assert.falsy((DailyVault.validateResult(result({ timeMs = DATA.MAX_HEIST_MS + 1 }))), "timeMs too long")
		Assert.falsy((DailyVault.validateResult(nil)), "nil")
	end)
end
