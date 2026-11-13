-- L1: Shared/Heist/RunCoach (RUN2 CLARITY track): the coach's goal text per level, run and state, the run-start
-- beat, the server's beat seconds, word counts per device, and the tutorial gate (L1 is the mandatory tutorial).

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local Catalog = require("../../src/shared/Levels/Catalog")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local Help = require("../../src/shared/Heist/Help")
local RunCoach = require("../../src/shared/Heist/RunCoach")
local Scenario = require("../../src/shared/Heist/Scenario")
local Strings = require("../../src/shared/Heist/Strings")

local C = Config.Onboarding.COACH

local function level(id: string): any
	for _, spec in Catalog do
		if spec.id == id then
			return LevelSpec.compile(spec)
		end
	end
	error("no level " .. id)
end

local function words(text: string): number
	local n = 0
	for _ in string.gmatch(text, "%S+") do
		n += 1
	end
	return n
end

local DEVICES = { "key", "pad", "touch" }

-- Every rendering of a line a kid can see (each device, first person and not).
local function renderings(line: any): { string }
	local out = {}
	for _, d in DEVICES do
		table.insert(out, Strings.coachLine(line, d, true))
		table.insert(out, Strings.coachLine(line, d, false))
	end
	return out
end

local function world(over: any?): any
	local w = { carrying = false, onPlate = nil, held = {}, doorOpen = {}, lootHome = nil }
	for k, v in over or {} do
		w[k] = v
	end
	return w
end

-- A recording from the street to (x, z) that stands there.
local function cloneTo(lv: any, x: number, z: number): any
	local rec = Sampler.new(nil, nil, 20)
	local s = lv.spawns[1]
	for i = 0, 60 do
		local u = math.min(i / 30, 1)
		Sampler.push(rec, s.x + (x - s.x) * u, lv.rootY, s.z + (z - s.z) * u, 0, 0)
	end
	Sampler.finish(rec, Codec.END.EndRun)
	return rec
end

return function(test)
	local L1 = level("cs1_back_room")
	local L2 = level("cs2_two_doors")
	local a1 = L1.index.plate.A
	local a2, b2 = L2.index.plate.A, L2.index.plate.B

	test("coached levels: L1 and L2 only; the beat on runs 2..BEAT_MAX_RUN of them", function()
		Assert.truthy(RunCoach.coached(L1) and RunCoach.coached(L2), "L1 and L2 are coached")
		for _, spec in Catalog do
			local lv = LevelSpec.compile(spec)
			Assert.eq(RunCoach.coached(lv), C.LEVELS[spec.id] == true, spec.id)
		end
		Assert.eq(RunCoach.beatSeconds(L1.id, 1), 0, "run 1 has the level's first look, no beat")
		Assert.eq(RunCoach.beatSeconds(L1.id, 2), C.BEAT_SECONDS, "run 2 beat")
		Assert.eq(RunCoach.beatSeconds(L2.id, 3), C.BEAT_SECONDS, "L2 run 3 beat")
		Assert.eq(RunCoach.beatSeconds(L2.id, C.BEAT_MAX_RUN + 1), 0, "then no more beats")
		Assert.eq(RunCoach.beatSeconds("cs3_lights_out", 2), 0, "not coached: no beat")
		Assert.truthy(C.BEAT_SECONDS > 0 and C.BEAT_SECONDS <= 1.5, "a short beat (about 1 s)")
	end)

	test("L1 run 1: step on the plate (arrow on it), then on it: REWIND (no arrow; the finger)", function()
		local g = RunCoach.goal(L1, world())
		Assert.eq(g.line.key, "STEP_ON_PLATE")
		Assert.eq(g.target and g.target.kind, "plate")
		Assert.eq(g.target and g.target.index, a1)
		local on = RunCoach.goal(L1, world({ onPlate = a1 }))
		Assert.eq(on.line.key, "STAY_REWIND")
		Assert.truthy(on.rewind, "REWIND is the move")
		Assert.eq(on.target, nil, "one pointer: the finger on REWIND, no world arrow")
		Assert.eq(Strings.coachLine(on.line, "key", true), "Now press R")
		Assert.eq(Strings.coachLine(on.line, "pad", true), "Now press Y")
		Assert.eq(Strings.coachLine(on.line, "touch", false), "Tap REWIND now")
	end)

	test("L1 run 2: the clone holds the plate -> YOU through the door, then the cash, then the van", function()
		local held = { [a1] = { at = 1.9, slot = 1 } }
		local g = RunCoach.goal(L1, world({ held = held }))
		Assert.eq(g.line.key, "GO_DOOR", "the door is still shut: go to it")
		Assert.eq(g.target and g.target.kind, "door")
		g = RunCoach.goal(L1, world({ held = held, doorOpen = { true } }))
		Assert.eq(g.line.key, "GRAB")
		Assert.eq(g.target and g.target.kind, "loot")
		Assert.eq(Strings.coachLine(g.line, "touch", false), "Grab the cash!")
		Assert.eq(Strings.coachLine(g.line, "key", true), "Grab it: press E")
		g = RunCoach.goal(L1, world({ held = held, doorOpen = { true }, carrying = true }))
		Assert.eq(g.line.key, "BANK")
		Assert.eq(g.target and g.target.kind, "van")
		-- Standing on the plate the clone already holds is not "REWIND" (that clone does the job).
		g = RunCoach.goal(L1, world({ held = held, onPlate = a1 }))
		Assert.truthy(not g.rewind, "no REWIND on a held plate")
	end)

	test("L2 is a staged plan, never 'you need two clones' on run 1", function()
		local g = RunCoach.goal(L2, world())
		Assert.eq(Strings.coachLine(g.line, "key", true), "Stand on plate A. Then REWIND.")
		Assert.eq(g.target and g.target.index, a2, "the arrow on plate A")
		Assert.eq(RunCoach.goal(L2, world({ onPlate = b2 })).line.key, "STAY_REWIND", "plate B works too")
		-- Run 2: plate A is held by the clone -> plate B.
		local held = { [a2] = { at = 2, slot = 1 } }
		g = RunCoach.goal(L2, world({ held = held }))
		Assert.eq(Strings.coachLine(g.line, "touch", false), "Stand on plate B. Then REWIND.")
		Assert.eq(RunCoach.goal(L2, world({ held = held, onPlate = a2 })).line.key, "STAND_PLATE", "A is done")
		-- Run 3: both held -> the doors, then the safe.
		held[b2] = { at = 2, slot = 2 }
		g = RunCoach.goal(L2, world({ held = held }))
		Assert.eq(g.line.key, "GO_DOORS")
		Assert.eq(g.target and g.target.index, L2.index.door.BackRoom, "the nearer door first")
		g = RunCoach.goal(L2, world({ held = held, doorOpen = { true, false } }))
		Assert.eq(g.target and g.target.index, L2.index.door.Stockroom, "then the stockroom")
		g = RunCoach.goal(L2, world({ held = held, doorOpen = { true, true } }))
		Assert.eq(Strings.coachLine(g.line, "touch", false), "Grab the safe!")
		Assert.eq(g.target and g.target.index, L2.index.loot.Safe)
		Assert.truthy(not string.find(Strings.LEVEL_LINES[L2.id], "need two", 1, true), "the old line is gone")
	end)

	test("beat: computed from the newest clone's recording, never a static string", function()
		local onA = cloneTo(L1, 10, -8)
		local plate = Help.endPlate(L1, onA)
		Assert.eq(Strings.coachLine(RunCoach.beat(L1, { plate = plate }, {}), "key", true), "Clone holds the plate!")
		local street = cloneTo(L1, 0, 4)
		Assert.eq(
			Strings.coachLine(RunCoach.beat(L1, { plate = Help.endPlate(L1, street) }, {}), "key", true),
			"That run missed the plate."
		)
		Assert.eq(Strings.coachLine(RunCoach.beat(L2, { plate = b2 }, {}), "key", true), "Clone holds plate B!")
		Assert.eq(
			Strings.coachLine(RunCoach.beat(L2, { plate = a2 }, { [a2] = true }), "key", true),
			"Plate A already has one."
		)
		-- The card: the beat when there is one, else the run's first goal.
		Assert.eq(RunCoach.card(L2, nil, world()).key, "STAND_PLATE")
		Assert.eq(RunCoach.card(L2, { key = "RUN_MISSED_PLATES" }, world()).key, "RUN_MISSED_PLATES")
	end)

	test("words: every coach line <= 6 words, every L1 line <= 4, on every device", function()
		local lines = {
			{ key = "STEP_ON_PLATE" },
			{ key = "STAY_REWIND" },
			{ key = "GO_DOOR" },
			{ key = "GO_DOORS" },
			{ key = "BANK" },
			{ key = "CLONE_HOLDS" },
			{ key = "RUN_MISSED" },
			{ key = "RUN_MISSED_PLATES" },
			{ key = "GRAB", loot = "Cash" },
			{ key = "GRAB", loot = "Safe" },
			{ key = "STAND_PLATE", plate = "A" },
			{ key = "CLONE_HOLDS_PLATE", plate = "B" },
			{ key = "ALREADY_HELD", plate = "A" },
		}
		for _, line in lines do
			for _, text in renderings(line) do
				Assert.truthy(text ~= "", "line " .. line.key .. " renders")
				Assert.le(words(text), 6, text)
			end
		end
		-- L1 (the tutorial, ≤ 4 words): every line its coach can say.
		Assert.eq(RunCoach.wordsMax(L1), 4)
		for _, line in
			{
				{ key = "STEP_ON_PLATE" },
				{ key = "STAY_REWIND" },
				{ key = "GO_DOOR" },
				{ key = "BANK" },
				{ key = "CLONE_HOLDS" },
				{ key = "GRAB", loot = "Cash" },
			}
		do
			for _, text in renderings(line) do
				Assert.le(words(text), 4, "L1: " .. text)
			end
		end
		Assert.le(words(Strings.LEVEL_LINES[L2.id]), 6, "L2 stuck line")
	end)

	test("every state of L1 and L2 has a line and at most one target", function()
		for _, lv in { L1, L2 } do
			local plates = {}
			for i in lv.plates do
				table.insert(plates, i)
			end
			for mask = 0, 2 ^ #plates - 1 do
				local held = {}
				for k, i in plates do
					if bit32.band(mask, 2 ^ (k - 1)) ~= 0 then
						held[i] = true
					end
				end
				for _, carrying in { false, true } do
					for on = 0, #plates do
						local g = RunCoach.goal(lv, world({ held = held, carrying = carrying, onPlate = plates[on] }))
						local text = Strings.coachLine(g.line, "touch", false)
						Assert.truthy(text ~= "", lv.id .. " has a line")
						Assert.truthy(not (g.rewind and g.target), "REWIND and an arrow never at once")
					end
				end
			end
		end
	end)

	test("the tutorial is mandatory and replayable in Studio", function()
		-- New accounts start L1 (FTUE autostart); L2 opens only after L1 (Data unlock), so nobody skips it.
		Assert.truthy(Config.Heist.FTUE_AUTOSTART, "new accounts start the tutorial")
		Assert.eq(Config.Heist.FTUE_L1_LEVEL, L1.id, "the tutorial is L1")
		Assert.eq(Catalog[1].id, L1.id, "first in play order")
		Assert.eq(Config.Data.Levels.TwoDoors.unlockAfter, "BackRoom", "L2 opens after the tutorial")
		-- Studio: EH_Scenario = "TUTORIAL" replays it whatever the profile says; a live server never stages.
		Assert.eq(Scenario.resolve(true, "tutorial"), "TUTORIAL")
		Assert.eq(Scenario.resolve(false, "TUTORIAL"), nil)
		Assert.eq((Scenario.spec("TUTORIAL") :: any).level, L1.id)
	end)
end
