--!strict
-- Heist/Help: when help is due and which help (PLAN_STEAM_PLUS §5 "Stuck", §6.1 items 3, 5, 8,
-- §8.4; WALKTHROUGH P0-2, P0-4, P1-6, P1-7; premium G4). Pure (no engine calls), so the client
-- (Hud/Hints) and the sim bots (tests/sim/HelpBots.spec.luau) compute the same help at the same
-- moments. Numbers in Config.Onboarding.
--
--   * Deck plates: a clone holds a plate when its recording ends inside the plate's box and it
--     is not red-flagged (busted, caught, zapped, stuck); `at` = when it got there.
--   * Stuck tracker (per heist): progress is a plate a clone holds for the first time this heist,
--     or the goal banked. SHOW_ME_RUNS runs in a row without progress make "Show me?" due; the
--     level line comes back after LEVEL_LINE_STUCK_RUNS runs without a bank; Relaxed is offered
--     after Config.Sim.RELAXED_OFFER_BUSTS catches (the server decides: HeistSim.offerRelaxed).
--   * Next step: the ghost shows ONE run of the level's solution (Heist/GhostTapes): the first
--     solution run whose plate no deck clone holds in time (else the bank run). A clone that
--     holds the plate more than GHOST_LATE_SLACK s after the solution's is redone ("Redo clone
--     2 like this.").
--   * World-state lines (L2 on): stand on a plate no clone of yours holds -> "Stay here. Tap
--     REWIND." (REWIND is the right move); a plate still missing -> "Find the next plate."; all
--     held -> "Your clones open the way. Grab it!"; carrying -> "Bank it at the van".
--   * Failure counterplay: one line per cause, a level's own line first (Strings.FAIL_ADVICE*).
--   * Unlocks: the daily vault after DAILY_UNLOCK_LEVEL; the free first catch (detection x2) for
--     the first GRACE_GUARD_HEISTS heists that have a guard.
--   * First visits: a profile with no play of a level sees its first look (Heist/LevelIntro), so the
--     server lengthens that run 1's intro (Help.firstRunIntro; never L1, never a daily vault).

local Config = require("../Config")
local Strings = require("./Strings")
local GhostTapes = require("./GhostTapes")
local Catalog = require("../Levels/Catalog")
local Deck = require("../Sim/Deck")
local Geom = require("../Sim/Geom")

local O = Config.Onboarding

local Help = {}

-- Why a run ended badly (the failure counterplay table's keys).
Help.CAUSE = table.freeze({
	Caught = "Caught", -- Gus caught you
	Zapped = "Zapped", -- a laser zapped you
	Timeout = "Timeout", -- the run's time ran out
	Alarm = "Alarm", -- the van left without you (Alarm Run) / the doors locked
	Dawn = "Dawn", -- a story level's last run ended (a party's Dawn is not a failure)
})

export type Held = { [number]: { at: number, slot: number } }
export type Tracker = {
	runs: number,
	noProgress: number, -- runs in a row with no new plate held and no goal banked
	noBank: number, -- runs in a row with no bank at all
	catches: number, -- times you were caught this heist
	ever: { [number]: boolean }, -- plates a clone of yours has held this heist
	goalMet: boolean,
}
export type Facts = {
	held: { [number]: any }, -- plates your deck's clones hold after this run (Help.deckPlates)
	goalBanked: boolean, -- the level's goal was banked this run
	banked: boolean, -- anything was banked this run
	caught: boolean, -- you were caught this run
}
export type Due = { showMe: boolean, relaxed: boolean, levelLine: boolean, any: boolean }
export type Step = { run: number, plate: number?, redo: number?, full: boolean, junk: { number } }
export type World = {
	onPlate: number?, -- the plate you stand on (level index)
	carrying: boolean,
	deckHeld: { [number]: any }, -- Help.deckPlates of the clones replaying this run
}

---------------------------------------------------------------------------
-- Plates
---------------------------------------------------------------------------

-- The plate (level index) a recording ends on, and the loop time it got there.
function Help.endPlate(level: any, rec: any): (number?, number?)
	local n = rec and rec.n or 0
	if n == 0 then
		return nil, nil
	end
	local px, py, pz = rec.px, rec.py, rec.pz
	for i, p in level.plates do
		if Geom.contains(p.box, px[n], py[n], pz[n]) then
			local k = n
			while k > 1 and Geom.contains(p.box, px[k - 1], py[k - 1], pz[k - 1]) do
				k -= 1
			end
			return i, (k - 1) / rec.hz
		end
	end
	return nil, nil
end

-- Plates a deck's clones hold at the end of their recordings: plate -> {at, slot} (the earliest
-- arrival). `slots` = { {rec, status} } in deck order; red-flagged clones hold nothing.
function Help.deckPlates(level: any, slots: { any }): Held
	local held: Held = {}
	for slot, s in slots do
		if s.rec and not Deck.RED[s.status or ""] then
			local plate, at = Help.endPlate(level, s.rec)
			if plate and at then
				local h = held[plate]
				if not h or at < h.at then
					held[plate] = { at = at, slot = slot }
				end
			end
		end
	end
	return held
end

-- Plates that open a door or switch a laser off (the ones a clone is needed on).
function Help.neededPlates(level: any): { [number]: boolean }
	local out: { [number]: boolean } = {}
	for _, list in { level.doors, level.lasers } do
		for _, d in list do
			for _, src in d.openBy or d.offBy or {} do
				if src.kind == "plate" then
					out[src.index] = true
				end
			end
		end
	end
	return out
end

-- Do the world-state lines and the ghost apply? Story levels after the tutorial (the L1 FTUE
-- has its own lines and Mentor; a party has no plan to show).
function Help.applies(level: any): boolean
	return level ~= nil and level.kind == "story" and level.tutorial == nil
end

-- The L1 stuck hint stage (§7.5: 1 the plate re-pulses, 2 a beam from your feet, 3 the Mentor
-- walks it) at loop time t of a run where the tutorial auto-end is armed. `missedRuns` = earlier
-- armed runs that ended off the plate: each one starts the next run a stage further, so a kid who
-- taps REWIND within seconds every run still gets the beam and the Mentor.
function Help.tutorialHintStage(t: number, missedRuns: number): number
	local hs = Config.Heist.HINT_SECONDS
	local stage = math.clamp(missedRuns, 0, #hs)
	for i, at in hs do
		if t >= at then
			stage = math.max(stage, i)
		end
	end
	return stage
end

---------------------------------------------------------------------------
-- Stuck tracker
---------------------------------------------------------------------------

function Help.newTracker(): Tracker
	return { runs = 0, noProgress = 0, noBank = 0, catches = 0, ever = {}, goalMet = false }
end

-- After a run: returns true if the run made progress.
function Help.afterRun(tr: Tracker, facts: Facts): boolean
	tr.runs += 1
	local progress = facts.goalBanked
	for plate in facts.held do
		if not tr.ever[plate] then
			tr.ever[plate] = true
			progress = true
		end
	end
	tr.goalMet = tr.goalMet or facts.goalBanked
	tr.noProgress = if progress then 0 else tr.noProgress + 1
	tr.noBank = if facts.banked then 0 else tr.noBank + 1
	if facts.caught then
		tr.catches += 1
	end
	return progress
end

-- Which help is due now (between runs and through the next run).
function Help.due(tr: Tracker, level: any): Due
	local story = level.kind == "story"
	local showMe = Help.applies(level)
		and not tr.goalMet
		and GhostTapes.steps(level.id) ~= nil
		and tr.noProgress >= O.SHOW_ME_RUNS
	local relaxed = story and not level.relaxed and tr.catches >= Config.Sim.RELAXED_OFFER_BUSTS
	local levelLine = Strings.LEVEL_LINES[level.id] ~= nil and tr.noBank >= O.LEVEL_LINE_STUCK_RUNS
	return { showMe = showMe, relaxed = relaxed, levelLine = levelLine, any = showMe or relaxed or levelLine }
end

---------------------------------------------------------------------------
-- The ghost's next step
---------------------------------------------------------------------------

-- The ghost's steps with plate ids resolved to level indices (nil: no ghost for this level).
function Help.ghostGoals(level: any): { { plate: number?, at: number?, bank: boolean? } }?
	local steps = GhostTapes.steps(level.id)
	if not steps then
		return nil
	end
	local out = {}
	for k, s in steps do
		local plate = if s.plate then level.index.plate[s.plate] else nil
		out[k] = { plate = plate, at = s.at, bank = s.bank }
	end
	return out
end

-- The ONE next step to show: the first solution run whose plate no clone holds in time, else
-- the bank run. `slots` = the deck ({rec, status}), `cap` its cap. redo = the slot to re-record
-- (a late clone on that plate, or when the deck is full the first clone that holds nothing the
-- plan needs); junk = slots that hold nothing the plan needs (the deck-full advice).
function Help.nextStep(level: any, slots: { any }, cap: number): Step?
	local goals = Help.ghostGoals(level)
	if not goals then
		return nil
	end
	local held = Help.deckPlates(level, slots)
	local wanted: { [number]: number } = {} -- slot -> 1 when it holds a plate the plan uses
	for _, g in goals do
		local h = if g.plate then held[g.plate] else nil
		if h then
			wanted[h.slot] = 1
		end
	end
	local junk = {}
	for i in slots do
		if not wanted[i] then
			table.insert(junk, i)
		end
	end
	local full = #slots >= cap
	for k, g in goals do
		local h = if g.plate then held[g.plate] else nil
		if g.plate and h and h.at <= (g.at or 0) + O.GHOST_LATE_SLACK then
			continue
		end
		local redo = if h then h.slot elseif full and not g.bank then junk[1] else nil
		return { run = k, plate = g.plate, redo = redo, full = full, junk = junk }
	end
	return nil
end

---------------------------------------------------------------------------
-- World-state lines
---------------------------------------------------------------------------

-- The line for the world as it is (a Strings key) and whether REWIND is the right move now.
function Help.worldLine(_level: any, needed: { [number]: boolean }, w: World): (string?, boolean)
	if w.carrying then
		return "OBJ_BANK_IT", false
	end
	local on = w.onPlate
	if on and needed[on] and not w.deckHeld[on] then
		return "OBJ_STAY_TAP_REWIND", true
	end
	for plate in needed do
		if not w.deckHeld[plate] then
			return "OBJ_NEXT_PLATE", false
		end
	end
	if next(needed) ~= nil then
		return "OBJ_CLONES_OPEN_WAY", false
	end
	return "OBJ_GRAB_LOOT", false
end

---------------------------------------------------------------------------
-- Failures
---------------------------------------------------------------------------

-- One line of counterplay for a failure (premium G4): the level's own line, else the cause's.
function Help.advice(cause: string, levelId: string?): string?
	local own = levelId and Strings.FAIL_ADVICE_LEVEL[levelId]
	return (own and own[cause]) or Strings.FAIL_ADVICE[cause]
end

---------------------------------------------------------------------------
-- Unlocks
---------------------------------------------------------------------------

local function specById(id: string): any
	for _, spec in Catalog do
		if spec.id == id then
			return spec
		end
	end
	return nil
end

-- Is the daily vault open for a profile's level records (Data Schema heist.levels)? Also the
-- name of the level that opens it.
function Help.dailyOpen(levels: { [string]: any }?): (boolean, string)
	local spec = specById(O.DAILY_UNLOCK_LEVEL)
	local name = if spec then spec.name else O.DAILY_UNLOCK_LEVEL
	local rec = spec and levels and levels[spec.dataId]
	return rec ~= nil and (tonumber(rec.clears) or 0) > 0, name
end

-- Plays of launch levels that have a guard.
function Help.guardPlays(levels: { [string]: any }?): number
	local n = 0
	for _, spec in Catalog do
		local rec = levels and levels[spec.dataId]
		if rec and spec.guards and #spec.guards > 0 then
			n += tonumber(rec.plays) or 0
		end
	end
	return n
end

-- Does a heist of this spec get the free first catch (detection x FIRST_HEIST_GRACE_MULT)?
-- Only a level with a guard, for the first GRACE_GUARD_HEISTS guarded heists (P1-6).
function Help.graceFor(spec: any, levels: { [string]: any }?): boolean
	return spec ~= nil and spec.guards ~= nil and #spec.guards > 0 and Help.guardPlays(levels) < O.GRACE_GUARD_HEISTS
end

-- Has a profile never played this level (no record with a play; Data Schema heist.levels)? The same
-- "seen" data the client's FirstTime "intro:<data key>" is seeded from (Heist/PresentPlan.seenKinds).
function Help.firstVisit(dataKey: string?, levels: { [string]: any }?): boolean
	if type(dataKey) ~= "string" or type(levels) ~= "table" then
		return false -- no level key (a daily vault) or no profile: nothing to go on
	end
	local rec = levels[dataKey]
	return not (type(rec) == "table" and (tonumber(rec.plays) or 0) > 0)
end

-- Run 1's intro (s, the server's wall-clock wait before the run clock starts): Config.Heist.FIRST_RUN_INTRO,
-- plus FIRST_VISIT_INTRO_EXTRA when `firstVisitors` crew members see this level for the first time, on a
-- story or party level only (never the L1 tutorial, whose first look is the title beat; never a daily vault).
function Help.firstRunIntro(level: any, daily: boolean, firstVisitors: number): number
	local H = Config.Heist
	local base = H.FIRST_RUN_INTRO
	if daily or firstVisitors <= 0 or type(level) ~= "table" then
		return base
	end
	if level.id == H.FTUE_L1_LEVEL or level.tutorial ~= nil or H.LEVEL_DATA_KEYS[level.id] == nil then
		return base
	end
	return base + H.FIRST_VISIT_INTRO_EXTRA
end

return table.freeze(Help)
