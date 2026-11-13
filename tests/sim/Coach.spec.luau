-- L2: the run coach plays the FTUE (RUN2 CLARITY track; Shared/Heist/RunCoach, Hud/Coach). Coached kids
-- (tests/sim/NaiveKid.coachedBrain: they read the coach's one line, follow its one arrow, slowly, with a wander now
-- and then and a REWIND they sometimes forget) must finish L1, the mandatory tutorial, in about 10 s of play and
-- L2 within its cap, with the coach's lines in the order the design says. The tutorial clock runs from first
-- control in run 1 to the bank: both runs, the quick rewind, the coach's run-start beat and the L1 between-pause.

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local Help = require("../../src/shared/Heist/Help")
local RunCoach = require("../../src/shared/Heist/RunCoach")
local Harness = require("./Harness")
local NaiveKid = require("./NaiveKid")

local H = Config.Heist
local EV = EventLog.EV
local HZ = Config.Rec.HZ

local KIDS = 40
local TUTORIAL_MEDIAN = 16 -- s: the owner's "about 10 seconds" of doing, plus the rewind, the beat and the walk to the van
local TUTORIAL_MAX = 22 -- s: the slowest coached kid (a kid who wanders, reads slowly or never presses REWIND)

-- The rewind before run `r` on a level (+ the coach's beat).
local function rewind(level: any, r: number): number
	local T = H.REWIND_TRANSITION
	local base = if level.tutorial ~= nil or r > H.QUICK_REWIND_FROM_RUN then T[2] else T[1]
	return base + RunCoach.beatSeconds(level.id, r)
end

-- Seconds from first control to the goal's bank (nil: never banked), and the runs it took.
local function toBank(level: any, runs: { any }): (number?, number)
	local t = 0
	for r, run in runs do
		local b = EventLog.firstTick(run.log, EV.GoalMet) or EventLog.firstTick(run.log, EV.HeistComplete)
		if b then
			return t + b / HZ, r
		end
		t += run.t + rewind(level, r + 1) + (if level.tutorial ~= nil then H.TUTORIAL_BETWEEN_SECONDS else 3)
	end
	return nil, #runs
end

local function play(n: number, seed: number, runs: number, opts: any?): (any, { any }, { any })
	local level = Harness.level(n)
	local log = {}
	local o = table.clone(opts or {})
	o.kind = "coached"
	o.log = log
	local _, played = Harness.play(level, NaiveKid.plan(level, seed, runs, o))
	return level, played, log
end

local function median(xs: { number }): number
	local s = table.clone(xs)
	table.sort(s)
	return s[math.ceil(#s / 2)]
end

return function(test)
	test("L1 tutorial: 40 coached kids bank the cash; median <= 16 s of play, slowest <= 22 s", function()
		local times, runsUsed = {}, {}
		local pressed = 0
		for seed = 1, KIDS do
			local level, runs = play(1, seed, 3)
			local t, r = toBank(level, runs)
			Assert.truthy(t ~= nil, "kid " .. seed .. " banks the cash\n" .. Harness.dump(runs))
			table.insert(times, t :: number)
			table.insert(runsUsed, r)
			if Harness.count(runs[1], EV.EndRun) > Harness.count(runs[1], EV.AutoEnd) then
				pressed += 1 -- run 1 ended by the kid's own REWIND, not the auto-end
			end
		end
		local sorted = table.clone(times)
		table.sort(sorted)
		print(
			string.format(
				"        [tutorial] coached kids: median %.1f s, fastest %.1f s, slowest %.1f s; %d/%d pressed REWIND themselves",
				median(times),
				sorted[1],
				sorted[#sorted],
				pressed,
				KIDS
			)
		)
		Assert.le(median(times), TUTORIAL_MEDIAN, "median tutorial time")
		Assert.le(sorted[#sorted], TUTORIAL_MAX, "slowest tutorial time")
		Assert.truthy(pressed >= KIDS / 2, "most kids press REWIND themselves (" .. pressed .. ")")
		for _, r in runsUsed do
			Assert.eq(r, 2, "one idea per run: record (run 1), use the clone (run 2)")
		end
	end)

	test("L1: the coach's lines come in order: plate, REWIND, the door, the cash, the van", function()
		local _, runs, log = play(1, 7, 3, { wander = 0 })
		Assert.eq(#runs, 2, "two runs")
		local seen = {}
		for _, e in log do
			table.insert(seen, e.run .. ":" .. e.key)
		end
		local text = table.concat(seen, " ")
		Assert.truthy(string.find(text, "1:STEP_ON_PLATE 1:STAY_REWIND", 1, true) ~= nil, text)
		Assert.truthy(string.find(text, "2:GO_DOOR", 1, true) ~= nil, text)
		Assert.truthy(string.find(text, "2:GRAB", 1, true) ~= nil, text)
		Assert.truthy(string.find(text, "2:BANK", 1, true) ~= nil, text)
	end)

	test("L1: a kid who never presses REWIND is rewound anyway (no failing) and still finishes in 2 runs", function()
		local level, runs = play(1, 3, 3, { wander = 0, press = 0 })
		Assert.eq(Harness.count(runs[1], EV.AutoEnd), 1, "run 1 auto-ended on the plate")
		local t, r = toBank(level, runs)
		Assert.truthy(t ~= nil and r == 2, "banked in run 2")
		print(string.format("        [tutorial] never presses REWIND: %.1f s", t :: number))
		Assert.le(t :: number, TUTORIAL_MAX, "still within the slowest bar")
	end)

	test("L1 beat: run 2's clone holds the plate; a run that ended off the plate says so", function()
		local level = Harness.level(1)
		local sim = Harness.play(level, NaiveKid.plan(level, 11, 1, { kind = "coached", wander = 0 }))
		local deck = sim.playerById[1].deck
		Assert.eq(#deck.slots, 1, "run 1 made one clone")
		local plate = Help.endPlate(level, deck.slots[1].rec)
		Assert.eq(plate, level.index.plate.A, "it ends on the plate")
		Assert.eq(RunCoach.beat(level, { plate = plate }, {}).key, "CLONE_HOLDS", "the beat names what it does")
		-- A run that ended off the plate (a kid who tapped REWIND out on the street).
		Assert.eq(RunCoach.beat(level, { plate = nil }, {}).key, "RUN_MISSED", "the beat says the run missed")
		Assert.eq(RunCoach.beat(level, nil, {}), nil, "no clone of yours: no beat")
	end)

	test("L2: 40 coached kids clear Two Doors within its cap; run 1 says plate A, run 2 plate B", function()
		local times, used = {}, {}
		for seed = 1, KIDS do
			local level, runs, log = play(2, seed, 4)
			local t, r = toBank(level, runs)
			Assert.truthy(t ~= nil, "kid " .. seed .. " banks the safe\n" .. Harness.dump(runs))
			Assert.le(r, level.cap, "within the cap")
			table.insert(times, t :: number)
			table.insert(used, r)
			Assert.eq(log[1].key, "STAND_PLATEA", "run 1 opens with the staged plan: plate A first")
			local sawB = false
			for _, e in log do
				sawB = sawB or e.key == "STAND_PLATEB"
			end
			Assert.truthy(sawB, "then plate B")
		end
		print(
			string.format(
				"        [L2] coached kids: median %.1f s of play to the safe, median %d runs",
				median(times),
				median(used)
			)
		)
		Assert.le(median(used), 3, "the par plan: A, B, then the safe")
	end)

	test("L2 beat: plate A's clone, then plate B's; a wasted run is named", function()
		local level = Harness.level(2)
		local a, b = level.index.plate.A, level.index.plate.B
		Assert.eq(RunCoach.beat(level, { plate = a }, {}).key, "CLONE_HOLDS_PLATE")
		Assert.eq(RunCoach.beat(level, { plate = b }, { [a] = true }).plate, "B")
		Assert.eq(RunCoach.beat(level, { plate = a }, { [a] = true }).key, "ALREADY_HELD")
		Assert.eq(RunCoach.beat(level, { plate = nil }, {}).key, "RUN_MISSED_PLATES")
	end)
end
