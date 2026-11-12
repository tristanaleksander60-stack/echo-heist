--!strict
-- Data/DailyVault: the daily vault and the December advent calendar (pure;
-- Lune-tested). MASTERPLAN §5.3, §4.3.
--
--   * One mini-vault per UTC day, rotating through VAULT_COUNT designs.
--   * First clear of today's vault: FIRST_CLEAR_STARS, FIRST_CLEAR_CASH, Candy Canes
--     while the event runs, and that vault's ornament (in the advent window: that
--     December day's advent ornament). The streak grows with one grace day.
--   * Advent catch-up: a missed advent day (Dec FIRST_DAY..LAST_DAY) can be cleared
--     later, until CATCH_UP_UNTIL, for its ornament and the same rewards; catch-ups
--     never touch the streak.
--   * Board ("biggest haul today"): today's untainted, non-Relaxed best run, ranked by
--     haul, then fewer clones, then less time (the sim's result().daily.timeMs), so two
--     kids with the same haul are not a coin toss (beatsBoard).
--   * The server passes `today` from os.time(); clients never send a time.

local Calendar = require("./Calendar")
local Config = require("../Config")
local Progress = require("./Progress")
local Schema = require("./Schema")

local DailyVault = {}

export type DailyResult = {
	cleared: boolean, -- the heist server decided the vault was cleared
	haul: number,
	clones: number,
	timeMs: number, -- heist duration in loop milliseconds (board tie-break)
	tainted: boolean,
	relaxed: boolean,
}

-- One "biggest haul today" board entry.
export type BoardEntry = { haul: number, clones: number, timeMs: number }

export type DailySummary = {
	mode: string, -- "today" | "catchUp"
	firstClear: boolean,
	stars: number,
	cash: number,
	candyCanes: number,
	ornament: string?,
	streak: number,
	newHaulBest: boolean, -- a new "biggest haul today" board entry (haul, clones, time)
	totalStars: number,
}

-- Streak after a first clear on `today`: (isFirstToday, streakAfter). lastDay -1 = never.
-- Same rule as lihfolk-systems DailyRewards.evaluate.
function DailyVault.evaluateStreak(lastDay: number, streak: number, today: number, grace: number): (boolean, number)
	if lastDay >= 0 and today <= lastDay then
		return false, math.max(streak, 1) -- already cleared today (or the clock moved back)
	end
	local continues = lastDay >= 0 and today - lastDay <= 1 + grace
	return true, if continues then streak + 1 else 1
end

-- Streak as shown before today's clear: 0 once more than the grace has passed.
function DailyVault.currentStreak(lastDay: number, streak: number, today: number, grace: number): number
	if lastDay < 0 or today - lastDay > 1 + grace then
		return 0
	end
	return streak
end

-- Vault design (1..count) for a day: a fixed rotation by UTC date, anchored so launch day
-- (Config.Data.Event.FIRST, Dec 3) is vault 1. Then rotation slot n holds daily design n
-- (Levels/DailyVaults) and Orn_VaultNN looks like design NN's advent ornament (docs/art/KIT_IMPORT.md).
local ROTATION_ANCHOR = Calendar.dayOf(Config.Data.Event.FIRST)

function DailyVault.vaultFor(day: number, count: number?): number
	local n = count or Config.Data.Daily.VAULT_COUNT
	return ((day - ROTATION_ANCHOR) % n) + 1
end

-- December day number if `day` is in the advent window, else nil.
function DailyVault.adventDay(day: number): number?
	local advent = Config.Data.Advent
	local y, m, d = Calendar.civilFromDays(day)
	if y == advent.YEAR and m == 12 and d >= advent.FIRST_DAY and d <= advent.LAST_DAY then
		return d
	end
	return nil
end

function DailyVault.ornamentFor(day: number): string
	local advent = DailyVault.adventDay(day)
	if advent then
		return string.format("Orn_Advent%d_%02d", Config.Data.Advent.YEAR, advent)
	end
	return string.format("Orn_Vault%02d", DailyVault.vaultFor(day))
end

function DailyVault.inEvent(day: number): boolean
	local event = Config.Data.Event
	return day >= Calendar.dayOf(event.FIRST) and day <= Calendar.dayOf(event.LAST)
end

-- How a vault day may be played on `today`: "today", "catchUp", or nil + reason.
function DailyVault.playMode(vaultDay: number, today: number): (string?, string?)
	if not Progress.isWhole(vaultDay, 0, 2 ^ 31) then
		return nil, "BadDay"
	end
	if vaultDay == today then
		return "today", nil
	end
	if
		vaultDay < today
		and DailyVault.adventDay(vaultDay) ~= nil
		and today <= Calendar.dayOf(Config.Data.Advent.CATCH_UP_UNTIL)
	then
		return "catchUp", nil
	end
	return nil, "WrongDay"
end

function DailyVault.validateResult(result: any): (boolean, string?)
	if type(result) ~= "table" then
		return false, "result must be a table"
	end
	for _, flag in { "cleared", "tainted", "relaxed" } do
		if type(result[flag]) ~= "boolean" then
			return false, `{flag} must be a boolean`
		end
	end
	if not Progress.isWhole(result.haul, 0, 1e7) or not Progress.isWhole(result.clones, 0, 16) then
		return false, "haul/clones out of range"
	end
	if not Progress.isWhole(result.timeMs, 0, Config.Data.MAX_HEIST_MS) then
		return false, "timeMs out of range"
	end
	return true, nil
end

-- True if run a goes above b on the board: a bigger haul, then fewer clones, then less
-- time. An empty haul never makes the board.
function DailyVault.beatsBoard(a: BoardEntry, b: BoardEntry): boolean
	if a.haul ~= b.haul then
		return a.haul > b.haul
	end
	if a.haul <= 0 then
		return false
	end
	if a.clones ~= b.clones then
		return a.clones < b.clones
	end
	return a.timeMs < b.timeMs
end

-- Applies a validated daily result. Returns nil + reason when the day cannot be played.
-- `startedDay` (optional, from the heist server): the server day when the heist began.
-- A vault started before the daily reset and finished after it is judged on the day
-- it started (one day at most: a heist lasts under MAX_HEIST_MS), so "today" keeps its
-- streak and a catch-up stays a catch-up.
function DailyVault.apply(
	heist: Schema.Heist,
	vaultDay: number,
	serverToday: number,
	result: DailyResult,
	now: number,
	startedDay: number?
): (DailySummary?, string?)
	local today = serverToday
	if
		startedDay ~= nil
		and Progress.isWhole(startedDay, 0, 2 ^ 31)
		and startedDay < serverToday
		and serverToday - startedDay <= 1
	then
		today = startedDay
	end
	local mode, reason = DailyVault.playMode(vaultDay, today)
	if not mode then
		return nil, reason
	end
	local cfg = Config.Data.Daily
	local daily = heist.daily
	local summary: DailySummary = {
		mode = mode :: string,
		firstClear = false,
		stars = 0,
		cash = 0,
		candyCanes = 0,
		ornament = nil,
		streak = DailyVault.currentStreak(daily.lastClearDay, daily.streak, today, cfg.GRACE_DAYS),
		newHaulBest = false,
		totalStars = Progress.totalStars(heist),
	}
	if result.tainted then
		return summary, nil
	end

	if mode == "today" and not result.relaxed then
		if daily.haulDay ~= today then
			daily.haulDay = today
			daily.haulBest, daily.haulClones, daily.haulTimeMs = 0, 0, 0
		end
		local entry = { haul = daily.haulBest, clones = daily.haulClones, timeMs = daily.haulTimeMs }
		if DailyVault.beatsBoard(result, entry) then
			daily.haulBest, daily.haulClones, daily.haulTimeMs = result.haul, result.clones, result.timeMs
			summary.newHaulBest = true
		end
	end
	if not result.cleared then
		return summary, nil
	end

	local ornament = DailyVault.ornamentFor(vaultDay)
	local first: boolean
	if mode == "today" then
		local isFirst, streak = DailyVault.evaluateStreak(daily.lastClearDay, daily.streak, today, cfg.GRACE_DAYS)
		first = isFirst
		if isFirst then
			daily.lastClearDay = today
			daily.streak = streak
			daily.bestStreak = math.max(daily.bestStreak, streak)
			summary.streak = streak
		end
	else
		-- Catch-up: once per advent day, tracked by its ornament.
		first = heist.trophies[ornament] == nil
	end
	if not first then
		return summary, nil
	end

	summary.firstClear = true
	daily.stars += cfg.FIRST_CLEAR_STARS
	summary.stars = cfg.FIRST_CLEAR_STARS
	summary.cash = cfg.FIRST_CLEAR_CASH
	if DailyVault.inEvent(today) then
		summary.candyCanes = cfg.FIRST_CLEAR_CANDY_CANES
	end
	if Progress.grantTrophy(heist, ornament, now) then
		summary.ornament = ornament
	end
	summary.totalStars = Progress.totalStars(heist)
	return summary, nil
end

return DailyVault
