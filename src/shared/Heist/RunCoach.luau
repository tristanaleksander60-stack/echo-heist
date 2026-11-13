--!strict
-- Shared/Heist/RunCoach: the run coach (RUN2 CLARITY track, owner report on v125: "run 2 is way too confusing").
-- On the coached levels (Config.Onboarding.COACH.LEVELS: L1, the mandatory tutorial, and L2) it says ONE thing to
-- do at a time, computed from the level and the clones replaying this run, never a static string:
--
--   run 1   L1: "Step on the plate" -> on it: "Now press R" (device key; it rewinds anyway after
--           Config.Sim.L1_AUTO_END_SECONDS). L2: "Stand on plate A. Then REWIND." (the staged plan: plate A first).
--   beat    runs 2..BEAT_MAX_RUN: the server adds BEAT_SECONDS to the frozen transition; the camera holds on the
--           newest clone's path ("YOU, 10 SEC AGO" over it) and the card says what that clone does:
--           "Clone holds the plate!" / "Clone holds plate A!" / "That run missed the plate." / "Plate A already has
--           one." (RunCoach.beat).
--   run 2+  the next missing plate ("Stand on plate B. Then REWIND."), else "YOU: through the door!" (the first
--           shut door) and "Grab the cash!" (the goal loot), "Back to the van!" while you carry (RunCoach.goal).
--
-- Each line has a target for the one world arrow (a plate, a door, the goal loot, the van; none while REWIND is the
-- move: the finger points at REWIND then). Pure (no engine calls): Hud/Coach draws it and the sim's coached kid
-- (tests/sim/NaiveKid.coachedBrain) obeys the very same decisions (tests/sim/Coach.spec.luau).

local Config = require("../Config")
local Geom = require("../Sim/Geom")
local Help = require("./Help")

local C = Config.Onboarding.COACH

local RunCoach = {}

-- A line: a Strings.COACH key, or a builder key with its plate letter / loot id (Strings.coachLine renders it).
export type Line = { key: string, plate: string?, loot: string? }
export type Target = { kind: string, index: number } -- "plate" | "door" | "loot" | "van" (index 0)
export type Goal = { line: Line, target: Target?, rewind: boolean }
export type World = {
	carrying: boolean, -- you carry loot
	onPlate: number?, -- the plate (level index) you stand on
	held: { [number]: any }, -- plates the clones replaying this run hold at their end (Help.deckPlates)
	doorOpen: { [number]: boolean }?, -- doors open now (level index)
	lootHome: { [number]: boolean }?, -- loot still at home (level index; nil = all home)
}
export type Newest = { plate: number? } -- your newest clone this run: the plate its recording ends on

-- Is this level coached?
function RunCoach.coached(level: any): boolean
	return type(level) == "table" and level.id ~= nil and C.LEVELS[level.id] == true
end

-- The most words a coach line may have on this level: L1 (the tutorial) 4, others 6.
function RunCoach.wordsMax(level: any): number
	return if type(level) == "table" and level.tutorial ~= nil then 4 else 6
end

-- Seconds the server adds to the frozen transition before run `nextRun` (the run-start beat).
function RunCoach.beatSeconds(levelId: string?, nextRun: number): number
	if levelId and C.LEVELS[levelId] == true and nextRun >= 2 and nextRun <= C.BEAT_MAX_RUN then
		return C.BEAT_SECONDS
	end
	return 0
end

local function spawnXZ(level: any): (number, number)
	local s = level.spawns and level.spawns[1]
	return if s then s.x else 0, if s then s.z else 0
end

local function dist2(level: any, box: any): number
	local sx, sz = spawnXZ(level)
	local x, _, z = Geom.center(box)
	return (x - sx) ^ 2 + (z - sz) ^ 2
end

-- Doors in walking order (nearest the spawn first).
function RunCoach.doorOrder(level: any): { number }
	local out = {}
	for i in level.doors do
		table.insert(out, i)
	end
	table.sort(out, function(a: number, b: number): boolean
		return dist2(level, level.doors[a].box) < dist2(level, level.doors[b].box)
	end)
	return out
end

-- The plates a clone is needed on, in plan order: by the door (or laser) each opens, nearest the spawn first,
-- then by id (L2: A opens the back room, B the stockroom behind it -> A, B).
function RunCoach.plateOrder(level: any): { number }
	local rank: { [number]: number } = {}
	for k, d in RunCoach.doorOrder(level) do
		for _, src in level.doors[d].openBy or {} do
			if src.kind == "plate" and rank[src.index] == nil then
				rank[src.index] = k
			end
		end
	end
	for _, l in level.lasers or {} do
		for _, src in l.offBy or {} do
			if src.kind == "plate" and rank[src.index] == nil then
				rank[src.index] = 1000
			end
		end
	end
	local out = {}
	for i in rank do
		table.insert(out, i)
	end
	table.sort(out, function(a: number, b: number): boolean
		if rank[a] ~= rank[b] then
			return rank[a] < rank[b]
		end
		return tostring(level.plates[a].id) < tostring(level.plates[b].id)
	end)
	return out
end

-- The goal loot: the most valuable item (L1 Cash, L2 Safe).
function RunCoach.goalLoot(level: any): number?
	local best, value = nil, -math.huge
	for i, d in level.loot do
		if (d.value or 0) > value then
			best, value = i, d.value or 0
		end
	end
	return best
end

local function plateLetter(level: any, i: number): string
	local p = level.plates[i]
	return if p then tostring(p.id) else "?"
end

-- The plates still missing this run (in plan order): needed, and no clone replaying this run holds them.
function RunCoach.missing(level: any, held: { [number]: any }): { number }
	local out = {}
	for _, i in RunCoach.plateOrder(level) do
		if not held[i] then
			table.insert(out, i)
		end
	end
	return out
end

-- Your next move, for the objective line and the world arrow.
function RunCoach.goal(level: any, w: World): Goal
	if w.carrying then
		return { line = { key = "BANK" }, target = { kind = "van", index = 0 }, rewind = false }
	end
	local missing = RunCoach.missing(level, w.held)
	if #missing > 0 then
		for _, i in missing do
			if w.onPlate == i then
				return { line = { key = "STAY_REWIND" }, target = nil, rewind = true }
			end
		end
		local first = missing[1]
		local line: Line = if #level.plates == 1
			then { key = "STEP_ON_PLATE" }
			else { key = "STAND_PLATE", plate = plateLetter(level, first) }
		return { line = line, target = { kind = "plate", index = first }, rewind = false }
	end
	-- Every plate is held: through the first shut door, then the goal.
	local open = w.doorOpen or {}
	for _, d in RunCoach.doorOrder(level) do
		if not open[d] then
			local key = if #level.doors > 1 then "GO_DOORS" else "GO_DOOR"
			return { line = { key = key }, target = { kind = "door", index = d }, rewind = false }
		end
	end
	local home = w.lootHome
	local goal = RunCoach.goalLoot(level)
	if goal and (home == nil or home[goal] ~= false) then
		return {
			line = { key = "GRAB", loot = tostring(level.loot[goal].id) },
			target = { kind = "loot", index = goal },
			rewind = false,
		}
	end
	-- The goal is gone (a clone of yours carries it): the next loot still at home.
	for i, d in level.loot do
		if home == nil or home[i] ~= false then
			return {
				line = { key = "GRAB", loot = tostring(d.id) },
				target = { kind = "loot", index = i },
				rewind = false,
			}
		end
	end
	return { line = { key = "BANK" }, target = { kind = "van", index = 0 }, rewind = false }
end

-- The run-start beat's line: what your newest clone does this run. `newest` nil = no clone of yours (no beat);
-- `others` = plates the OTHER clones of this run hold (Help.deckPlates without the newest).
function RunCoach.beat(level: any, newest: Newest?, others: { [number]: any }): Line?
	if not newest then
		return nil
	end
	local needed = Help.neededPlates(level)
	local p = newest.plate
	if p == nil or not needed[p] then
		return { key = if #level.plates > 1 then "RUN_MISSED_PLATES" else "RUN_MISSED" }
	end
	if others[p] then
		return { key = "ALREADY_HELD", plate = plateLetter(level, p) }
	end
	if #level.plates == 1 then
		return { key = "CLONE_HOLDS" }
	end
	return { key = "CLONE_HOLDS_PLATE", plate = plateLetter(level, p) }
end

-- The card during a run's frozen transition: the beat line when there is one, else the run's first goal.
function RunCoach.card(level: any, beat: Line?, w: World): Line
	return beat or RunCoach.goal(level, w).line
end

-- Where a target is (level space: x, y, z), for the world arrow and the bots.
function RunCoach.targetPos(level: any, t: Target): (number, number, number)
	if t.kind == "plate" then
		return Geom.center(level.plates[t.index].box)
	elseif t.kind == "door" then
		local x, _, z = Geom.center(level.doors[t.index].box)
		return x, level.floorY or 0, z
	elseif t.kind == "loot" then
		local d = level.loot[t.index]
		return d.x, d.y or 3, d.z
	end
	local x, _, z = Geom.center(level.van)
	return x, level.floorY or 0, z
end

return table.freeze(RunCoach)
