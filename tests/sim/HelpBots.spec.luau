-- L2: the help rules against three kinds of kid (PLAN_STEAM_PLUS §8.4, §6.1 item 5; WALKTHROUGH
-- P0-2, P0-3, P0-4). The naive kid (NaiveKid.brain), the greedy kid (the most valuable loot,
-- never a plate on purpose) and the confused kid (ignores plates, spams REWIND, walks into Gus)
-- play every launch level. After every run the spec computes what the client would show, from the
-- same pure rules (Shared/Heist/Help): the stuck tracker (Show me?, Try Relaxed?, the level line),
-- the world-state lines during the run (Stay here. Tap REWIND. / Find the next plate.) and, on L1,
-- the tutorial hint stage. It fails when
--   * a kid goes 3 runs in a row with no progress and no help line due (progress: a plate a clone
--     holds for the first time, the goal banked; at the party: any bank), or
--   * a kid soft-locks: from the state the kid left (after 2 and after 4 of its runs), a player
--     who copies the "Show me?" ghost (Help.nextStep: redo where it says, then the step's
--     solution run) must clear the heist, unless Dawn comes first because too few runs are left.
-- It also checks the Relaxed offer: Help.due and the server's HeistSim.offerRelaxed agree.

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local Geom = require("../../src/shared/Sim/Geom")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Help = require("../../src/shared/Heist/Help")
local Bot = require("./Bot")
local Harness = require("./Harness")
local NaiveKid = require("./NaiveKid")
local Solutions = require("./Solutions")

local EV = EventLog.EV
local SEEDS = 6
local KID_RUNS = 6
local SWITCH_AT = { 2, 4 }
local KIDS = {
	{ name = "naive", opts = nil },
	{ name = "greedy", opts = { kind = "greedy" } },
	{ name = "confused", opts = { kind = "confused" } },
}
local HELP_LINES = { OBJ_STAY_TAP_REWIND = true, OBJ_NEXT_PLATE = true }

-- Plays one run with the given steps, watching the help a client would show during it.
local function playRun(sim: any, level: any, steps: { any }, hist: any, missed: number): (any, boolean)
	local needed = Help.neededPlates(level)
	local deck = HeistSim.deckOf(sim, 1)
	local replaying = {}
	for i, s in deck.slots do
		if deck.redo ~= i then
			table.insert(replaying, s)
		end
	end
	local deckHeld = Help.deckPlates(level, replaying)
	local helped = false
	local applies = Help.applies(level)
	local run = Harness.runOnce(sim, { Bot.new(level, 1, steps) }, hist, function(s: any)
		if helped or s.phase ~= "Run" then
			return
		end
		if level.tutorial then
			-- L1: the sticky FTUE lines always lead; the hint stage escalates while it is armed.
			helped = HeistSim.autoEndArmed(s) == nil or Help.tutorialHintStage(s.t, missed) >= 1
			return
		end
		if not applies then
			return
		end
		local a = HeistSim.liveActor(s, 1)
		if not (a and a.present) then
			return
		end
		local onPlate = nil
		for i, p in level.plates do
			if Geom.contains(p.box, a.x, a.y, a.z) then
				onPlate = i
			end
		end
		local key =
			Help.worldLine(level, needed, { onPlate = onPlate, carrying = a.carrying ~= 0, deckHeld = deckHeld })
		helped = key ~= nil and HELP_LINES[key] == true
	end)
	return run, helped
end

local function factsOf(sim: any, level: any, run: any): Help.Facts
	return {
		held = Help.deckPlates(level, HeistSim.deckOf(sim, 1).slots),
		goalBanked = EventLog.count(run.log, EV.GoalMet) > 0,
		banked = EventLog.count(run.log, EV.Bank) > 0,
		caught = (run.catches or 0) > 0,
	}
end

-- Plays `kidRuns` runs of a kid, then (follow = true) copies the ghost until the heist ends.
-- Returns the sim, the longest unhelped no-progress streak, and stats.
local function play(level: any, kid: any, seed: number, kidRuns: number, follow: boolean): (any, number, any)
	local sim = HeistSim.new(level, { players = { 1 } })
	local hist = Harness.history()
	local tr = Help.newTracker()
	local due: Help.Due = Help.due(tr, level)
	local streak, worst = 0, 0
	local stats = { relaxedDue = 0, offerMismatch = 0, follows = 0, switchRun = kidRuns }
	local armedMissed = 0
	local plan = Solutions.planFor(level)
	local r = 0
	while sim.phase ~= "Over" do
		r += 1
		local steps
		if r <= kidRuns then
			steps = { NaiveKid.brainFor(level, seed, r, kid.opts) }
		elseif follow and Help.applies(level) then
			local deck = HeistSim.deckOf(sim, 1)
			local step = Help.nextStep(level, deck.slots, deck.cap)
			assert(step, "a next step while the heist runs")
			if step.redo then
				assert(HeistSim.deckAction(sim, 1, "Redo", step.redo), "redo")
			end
			steps = plan.runs[step.run][1]
			stats.follows += 1
		else
			break
		end
		local armedBefore = level.tutorial ~= nil and r > 1 and sim.autoEndArmed
		assert(HeistSim.startRun(sim) == r, "run " .. r .. " starts (phase " .. sim.phase .. ")")
		if level.tutorial and HeistSim.autoEndArmed(sim) and armedBefore then
			armedMissed += 1
		end
		local run, helpedDuring = playRun(sim, level, steps, hist, armedMissed)
		local facts = factsOf(sim, level, run)
		local progress = Help.afterRun(tr, facts)
		if level.kind == "party" then
			progress = facts.banked
		end
		local helped = helpedDuring or due.any
		if progress or helped then
			streak = 0
		else
			streak += 1
			worst = math.max(worst, streak)
		end
		due = Help.due(tr, level)
		if due.relaxed then
			stats.relaxedDue += 1
		end
		if due.relaxed ~= HeistSim.offerRelaxed(sim, 1) then
			stats.offerMismatch += 1
		end
		assert(r <= 40, "the heist never ended")
	end
	return sim, worst, stats
end

return function(test)
	for n = 1, 6 do
		local level = Harness.level(n)
		for _, kid in KIDS do
			test(string.format("%s: %s kids never go 3 runs without help or progress", level.id, kid.name), function()
				local relaxedDue = 0
				for seed = 1, SEEDS do
					local _, worst, stats = play(level, kid, seed, KID_RUNS, false)
					Assert.le(worst, 2, string.format("seed %d: %d runs with no help and no progress", seed, worst))
					Assert.eq(stats.offerMismatch, 0, "the Relaxed card and the server's offer agree")
					relaxedDue += stats.relaxedDue
				end
				if relaxedDue > 0 then
					print(string.format("        [%s kids] Try Relaxed? due after %d runs", kid.name, relaxedDue))
				end
			end)
		end
	end

	for _, n in { 2, 3, 4, 6 } do
		local level = Harness.level(n)
		for _, kid in KIDS do
			test(
				string.format("%s: no soft lock: after a %s kid, copying the ghost clears it", level.id, kid.name),
				function()
					local cleared, dawn = 0, 0
					for seed = 1, SEEDS do
						for _, at in SWITCH_AT do
							local sim, _, stats = play(level, kid, seed, at, true)
							Assert.eq(sim.phase, "Over", "the heist ends")
							if sim.overReason == "Complete" then
								cleared += 1
							else
								-- Dawn is a real ending (OUT OF TIME + a tip), not a soft lock, but only
								-- when the kid left too few runs for the ghost's steps.
								Assert.eq(sim.overReason, "Dawn", "complete or Dawn")
								local left = (level.dawnRuns or math.huge) - stats.switchRun
								Assert.truthy(
									left < #Solutions.planFor(level).runs,
									string.format("seed %d at run %d: Dawn with %d runs left", seed, at, left)
								)
								dawn += 1
							end
						end
					end
					print(
						string.format("        [%s kid, then the ghost] cleared %d, Dawn %d", kid.name, cleared, dawn)
					)
					Assert.truthy(cleared > 0, "some heists clear")
				end
			)
		end
	end

	test("L4: a confused kid behind a held door walks into Gus: Try Relaxed? after 3 catches", function()
		-- A clone already holds plate A (the ghost's first step), so Gus is in reach.
		local level = Harness.level(4)
		local Codec = require("../../src/shared/Rec/Codec")
		local GhostTapes = require("../../src/shared/Heist/GhostTapes")
		local offered = 0
		for seed = 1, SEEDS do
			local sim = HeistSim.new(level, { players = { 1 } })
			local rec = Codec.decode(assert(GhostTapes.buffer(level.id, 1)))
			assert(HeistSim.seedDeck(sim, 1, { rec }), "seeded")
			local hist = Harness.history()
			local tr = Help.newTracker()
			for r = 1, KID_RUNS do
				if sim.phase == "Over" then
					break
				end
				HeistSim.startRun(sim)
				local steps = { { go = { 0, -10 } }, { go = { 0, -24 } }, NaiveKid.confusedBrain(level, seed, r, 4) }
				local run = Harness.runOnce(sim, { Bot.new(level, 1, steps) }, hist)
				Help.afterRun(tr, factsOf(sim, level, run))
				local due = Help.due(tr, level)
				Assert.eq(due.relaxed, HeistSim.offerRelaxed(sim, 1), "client card and server offer agree")
				Assert.eq(due.relaxed, tr.catches >= Config.Sim.RELAXED_OFFER_BUSTS, "after 3 catches")
				if due.relaxed then
					offered += 1
				end
			end
		end
		print(string.format("        [confused kids past the door] Try Relaxed? due after %d runs", offered))
		Assert.truthy(offered > 0, "kids who keep walking into Gus are offered Relaxed")
	end)

	test("Config: Show me after 2 stuck runs, help within 3 (PLAN §8.4)", function()
		Assert.le(Config.Onboarding.SHOW_ME_RUNS, 2, "Show me? by the second stuck run")
	end)
end
