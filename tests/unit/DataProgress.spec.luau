-- L1: Data/Progress (medals, best-run comparison, Stars, unlock gates, Cash maths).

local Config = require("../../src/shared/Config")
local Progress = require("../../src/shared/Data/Progress")
local Schema = require("../../src/shared/Data/Schema")
local Assert = require("./Assert")

local DATA = Config.Data
local NOW = 1796000000
local ORDER = DATA.LEVEL_ORDER

local function lookup(levelId: string): Progress.LevelRules?
	return DATA.Levels[levelId]
end

local STORY: Progress.LevelRules = {
	kind = "story",
	haulTarget = 500,
	maxHaul = 5000,
	parClones = 2,
	cap = 4,
	devClones = 2,
	firstClearCash = 100,
}
local PARTY: Progress.LevelRules = { kind = "party", haulTiers = { 1000, 2500, 5000 }, maxHaul = 100000, cap = 8 }

local function run(overrides: { [string]: any }?): Progress.HeistResult
	local r: { [string]: any } = {
		haul = 600,
		clones = 2,
		timeMs = 90000,
		catches = 0,
		busted = 0,
		beforeDawn = true,
		tainted = false,
		relaxed = false,
		friends = 0,
	}
	for k, v in overrides or {} do
		r[k] = v
	end
	return r :: any
end

local function medalList(medals: { [string]: boolean }): string
	local list = {}
	for m in medals do
		table.insert(list, m)
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- A cleared story run with exactly the given medal set for `levelId`.
local function clearWith(heist: Schema.Heist, levelId: string, overrides: { [string]: any }?): Progress.AwardSummary
	local rules = assert(lookup(levelId))
	local base: { [string]: any } = { haul = rules.haulTarget or (rules.haulTiers :: { number })[1] }
	for k, v in overrides or {} do
		base[k] = v
	end
	return Progress.applyHeistResult(heist, levelId, rules, run(base), NOW, ORDER, lookup)
end

return function(test)
	test("every configured level has valid rules; bad rules are refused", function()
		for _, levelId in ORDER do
			local ok, err = pcall(Progress.validateRules, levelId, assert(lookup(levelId)))
			Assert.truthy(ok, tostring(err))
		end
		local bad = table.clone(PARTY)
		bad.haulTiers = { 1000, 900 }
		Assert.falsy(pcall(Progress.validateRules, "Bad", bad), "tiers must rise")
		local over = table.clone(STORY)
		over.haulTarget = 6000
		Assert.falsy(pcall(Progress.validateRules, "Over", over), "target above maxHaul")
		Assert.falsy(pcall(Progress.validateRules, "Bad Id!", STORY), "id must be alphanumeric")
	end)

	test("validateResult refuses anything out of range before awarding", function()
		Assert.truthy(Progress.validateResult(STORY, run()), "good result")
		local cases: { [string]: { [string]: any } } = {
			nan = { haul = 0 / 0 },
			fraction = { haul = 10.5 },
			negative = { clones = -1 },
			overHaul = { haul = 5001 },
			overCap = { clones = 5 },
			inf = { timeMs = math.huge },
			flag = { tainted = "no" },
			friends = { friends = 99 },
			heistId = { heistId = "x y" },
			longHash = { recHash = string.rep("a", 65) },
		}
		for name, o in cases do
			Assert.falsy((Progress.validateResult(STORY, run(o))), name)
		end
		Assert.falsy((Progress.validateResult(STORY, "nope")), "not a table")
		Assert.truthy(Progress.validateResult(STORY, run({ heistId = "a1b2-C3_d4", recHash = "ff00" })), "ids ok")
	end)

	test("story medals: Haul needs the target before Dawn; Crew par; Clean; Diamond beats dev", function()
		Assert.eq(medalList(Progress.evaluate(STORY, run({ haul = 499 })).medals), "", "below target")
		Assert.falsy(Progress.evaluate(STORY, run({ beforeDawn = false })).cleared, "after Dawn")
		local e = Progress.evaluate(STORY, run({ clones = 1 }))
		Assert.truthy(e.cleared, "cleared")
		Assert.eq(medalList(e.medals), "Clean,Crew,Diamond,Haul", "all four")
		Assert.eq(e.stars, 3, "Diamond is not a Star")
		Assert.eq(medalList(Progress.evaluate(STORY, run({ clones = 2 })).medals), "Clean,Crew,Haul", "at par")
		Assert.eq(medalList(Progress.evaluate(STORY, run({ clones = 3 })).medals), "Clean,Haul", "over par")
		Assert.eq(medalList(Progress.evaluate(STORY, run({ busted = 1 })).medals), "Crew,Haul", "busted clone")
		Assert.eq(medalList(Progress.evaluate(STORY, run({ catches = 1 })).medals), "Crew,Haul", "caught")
		local noDev = table.clone(STORY)
		noDev.devClones = nil
		Assert.eq(medalList(Progress.evaluate(noDev, run({ clones = 0 })).medals), "Clean,Crew,Haul", "no dev")
	end)

	test("party medals are haul tiers; tainted runs earn no medals", function()
		Assert.eq(medalList(Progress.evaluate(PARTY, run({ haul = 999 })).medals), "", "below tier 1")
		local e = Progress.evaluate(PARTY, run({ haul = 2500, clones = 8 }))
		Assert.eq(medalList(e.medals), "Haul1,Haul2", "two tiers")
		Assert.truthy(e.cleared, "tier 1 clears")
		Assert.eq(Progress.evaluate(PARTY, run({ haul = 100000 })).stars, 3, "all tiers")
		local t = Progress.evaluate(STORY, run({ tainted = true, clones = 0 }))
		Assert.falsy(t.cleared, "tainted never clears")
		Assert.eq(t.stars, 0, "tainted no stars")
	end)

	test("medals merge as a union; gained medals are reported once", function()
		local have = { Haul = true }
		local gained = Progress.mergeMedals(have, { Haul = true, Clean = true, Crew = true })
		Assert.eq(table.concat(gained, ","), "Clean,Crew", "gained sorted")
		Assert.eq(medalList(have), "Clean,Crew,Haul", "union")
		Assert.eq(#Progress.mergeMedals(have, { Crew = true }), 0, "nothing new")
		Assert.eq(Progress.starCount({ Haul = true, Diamond = true }), 1, "Diamond excluded")
	end)

	test("best run: more Stars, then fewer clones, then faster, then bigger haul", function()
		local base: Schema.BestRun = { stars = 2, clones = 3, timeMs = 60000, haul = 600, at = 0 }
		local function with(o: { [string]: any }): Schema.BestRun
			local r = table.clone(base) :: any
			for k, v in o do
				r[k] = v
			end
			return r
		end
		Assert.truthy(Progress.isBetterRun(base, nil), "anything beats nothing")
		Assert.truthy(Progress.isBetterRun(with({ stars = 3, clones = 8 }), base), "stars first")
		Assert.falsy(Progress.isBetterRun(with({ stars = 1, clones = 1 }), base), "fewer stars lose")
		Assert.truthy(Progress.isBetterRun(with({ clones = 2, timeMs = 99999 }), base), "then clones")
		Assert.truthy(Progress.isBetterRun(with({ timeMs = 59999 }), base), "then time")
		Assert.truthy(Progress.isBetterRun(with({ haul = 601 }), base), "then haul")
		Assert.falsy(Progress.isBetterRun(base, base), "a tie is not better")
	end)

	test("Cash: haul x rate, +10% per friend capped at +30%, first-clear bonus, per-heist cap", function()
		Assert.eq(Progress.cashFor(STORY, run({ haul = 1000 }), false), 1000, "base")
		Assert.eq(Progress.cashFor(STORY, run({ haul = 1000, friends = 2 }), false), 1200, "two friends")
		Assert.eq(Progress.cashFor(STORY, run({ haul = 1000, friends = 3 }), false), 1300, "three friends")
		Assert.eq(Progress.cashFor(STORY, run({ haul = 1000, friends = 7 }), false), 1300, "bonus capped")
		Assert.eq(Progress.cashFor(STORY, run({ haul = 999, friends = 1 }), false), 1098, "rounded down")
		Assert.eq(Progress.cashFor(STORY, run({ haul = 1000 }), true), 1100, "first clear bonus")
		Assert.eq(Progress.cashFor(STORY, run({ haul = 0 }), false), 0, "nothing banked")
		local big = table.clone(PARTY)
		big.maxHaul = 10 ^ 7
		Assert.eq(
			Progress.cashFor(big, run({ haul = 10 ^ 7 }), false),
			DATA.Economy.MAX_CASH_PER_HEIST,
			"per-heist cap"
		)
		local tainted = Progress.cashFor(STORY, run({ haul = 1000, tainted = true }), false)
		Assert.eq(tainted, math.floor(1000 * DATA.Economy.TAINTED_CASH_MULT), "tainted multiplier")
	end)

	test("first clear: trophy on the shelf, next level unlocked, Stars counted", function()
		local heist = Schema.defaultHeist()
		local s = clearWith(heist, "BackRoom", { clones = 1 })
		Assert.truthy(s.cleared and s.firstClear, "first clear")
		Assert.eq(s.trophy, "Trophy_BackRoom", "trophy")
		Assert.eq(heist.shelf[1], "Trophy_BackRoom", "on the shelf")
		Assert.eq(table.concat(s.unlocked, ","), "TwoDoors", "next level")
		Assert.eq(s.starsGained, 3, "three stars")
		Assert.eq(s.totalStars, 3, "total")
		Assert.truthy(s.newBest, "first best")
		Assert.eq(s.cash, 300 + 100, "haul + first clear bonus")
		Assert.truthy(heist.firstHeistDone, "first heist flag")
		local again = clearWith(heist, "BackRoom", { clones = 1 })
		Assert.falsy(again.firstClear, "second clear")
		Assert.eq(again.trophy, nil, "trophy once")
		Assert.eq(again.starsGained, 0, "no new stars")
		Assert.falsy(again.newBest, "a tie is not a new best")
		Assert.eq(again.cash, 300, "no bonus twice")
		Assert.eq(heist.levels.BackRoom.clears, 2, "clears counted")
	end)

	test("medals add up across runs; the best run is replaced only by a better one", function()
		local heist = Schema.defaultHeist()
		clearWith(heist, "BackRoom", { clones = 3, catches = 1 }) -- Haul only
		Assert.eq(medalList(heist.levels.BackRoom.medals), "Haul", "haul only")
		local s = clearWith(heist, "BackRoom", { clones = 1, catches = 1 }) -- adds Crew
		Assert.eq(table.concat(s.newMedals, ","), "Crew", "crew added")
		Assert.truthy(s.newBest, "more stars is a new best")
		local slower = clearWith(heist, "BackRoom", { clones = 1, catches = 1, timeMs = 999999 })
		Assert.falsy(slower.newBest, "slower is not better")
		Assert.eq(heist.levels.BackRoom.best.timeMs, 90000, "best kept")
	end)

	test("tainted runs earn Cash but no medals, bests, clears or trophies", function()
		local heist = Schema.defaultHeist()
		local s = clearWith(heist, "BackRoom", { tainted = true, haul = 1000 })
		Assert.falsy(s.cleared, "not cleared")
		Assert.eq(#s.newMedals, 0, "no medals")
		Assert.eq(s.trophy, nil, "no trophy")
		Assert.eq(heist.levels.BackRoom.haulBest, 0, "no haul best")
		Assert.eq(heist.levels.BackRoom.best, nil, "no best")
		Assert.truthy(s.cash > 0, "Cash still earned")
		Assert.falsy(s.boardEligible, "never on a board")
		Assert.eq(#s.unlocked, 0, "nothing unlocked")
		local relaxed = clearWith(heist, "BackRoom", { relaxed = true })
		Assert.truthy(relaxed.firstClear, "Relaxed clears count")
		Assert.falsy(relaxed.boardEligible, "Relaxed is off the boards")
	end)

	test("Big Score gate: needs Night Clerk cleared AND 6 Stars", function()
		local heist = Schema.defaultHeist()
		for _, id in { "BackRoom", "TwoDoors", "LightsOut" } do
			clearWith(heist, id, { clones = 4, catches = 1 }) -- Haul only: 1 star each
		end
		local s = clearWith(heist, "NightClerk", { clones = 4, catches = 1 })
		Assert.eq(s.totalStars, 4, "4 stars")
		Assert.truthy(heist.unlocked.CloneParty, "Clone Party opens after Night Clerk")
		Assert.falsy(heist.unlocked.BigScoreBank, "Big Score still locked at 4 stars")
		local party = clearWith(heist, "CloneParty", { haul = 2500, clones = 8 })
		Assert.eq(party.totalStars, 6, "6 stars")
		Assert.eq(table.concat(party.unlocked, ","), "BigScoreBank", "gate opens at 6")
		heist.levels.CloneParty.medals = {} -- unlocks are never taken away
		Assert.eq(#Progress.computeUnlocks(heist, ORDER, lookup), 0, "nothing new")
		Assert.truthy(heist.unlocked.BigScoreBank, "still unlocked")
	end)

	test("total Stars include daily-vault Stars", function()
		local heist = Schema.defaultHeist()
		heist.daily.stars = 4
		clearWith(heist, "BackRoom", { clones = 3, catches = 1 })
		Assert.eq(Progress.totalStars(heist), 5, "4 daily + 1 medal")
	end)
end
