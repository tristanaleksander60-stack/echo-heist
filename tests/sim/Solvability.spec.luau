-- L2: every launch level is solvable at par from its (PLACEHOLDER, scripted)
-- solution, and the same clones replayed from encoded buffers clear it identically
-- (the path human-recorded levels/<id>.solution.bin files will take, §8.9).
-- Story levels (L1-L4, L6): complete at par with 3 stars. Clone Party (L5, no par):
-- all three Haul tiers before Dawn with bag level 0, the Alarm Run included.
-- The daily vaults have their own spec (Daily.spec.luau).

local Assert = require("../unit/Assert")
local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Bot = require("./Bot")
local Harness = require("./Harness")
local Solutions = require("./Solutions")

local EV = EventLog.EV

-- Deck after the plan, through the wire format; then the final run replayed against
-- the decoded clones must give the same log hash.
local function replayFromBuffers(level: any, plan: any, runs1: { any }, clones: number): any
	local sim1 = Harness.play(level, plan)
	local recs = {}
	for _, slot in sim1.players[1].deck.slots do
		local buf = Codec.encode(slot.rec)
		Assert.le(buffer.len(buf), Config.Rec.BUDGET_BYTES_PER_SECOND * level.runSeconds + 64, "size budget")
		local rec = Codec.decode(buf)
		Assert.truthy(rec, "decodes")
		table.insert(recs, rec)
	end
	Assert.eq(#recs, clones, "clones in the deck")
	local sim2 = HeistSim.new(level, { players = { 1 } })
	Assert.truthy(HeistSim.seedDeck(sim2, 1, recs), "seeded")
	-- Fast-forward the heist to the final run: the run index is part of the log, and
	-- so is the banked total (Bank events carry it; a party banks in every run).
	sim2.runIndex = clones
	sim2.phase = "Lobby"
	if #runs1 >= 2 then
		sim2.banked = runs1[#runs1 - 1].banked
		for _, tier in level.tiers or {} do
			sim2.tierMet += if sim2.banked >= tier then 1 else 0
		end
	end
	HeistSim.startRun(sim2)
	local final = Solutions.planFor(level).runs[#plan.runs]
	local run2 = Harness.runOnce(sim2, { Bot.new(level, 1, final[1]) }, Harness.history())
	local last = runs1[#runs1]
	Assert.eq(run2.hash, last.hash, "final run log hash\n" .. table.concat(run2.lines, "\n"))
	return sim2
end

return function(test)
	Assert.truthy(Solutions.PLACEHOLDER, "solutions are labelled placeholders")

	for _, n in { 1, 2, 3, 4, 6 } do
		local level = Harness.level(n)

		test(level.id .. ": the scripted solution completes the heist at par with 3 stars", function()
			local plan = Solutions.planFor(level)
			Assert.truthy(plan, "solution exists")
			local sim, runs = Harness.play(level, plan)
			local r = HeistSim.result(sim)
			local dump = Harness.dump(runs)
			Assert.truthy(r.complete, "complete\n" .. dump)
			Assert.eq(r.runs, level.par + 1, "par clones + the final run")
			Assert.eq(r.clonesUsed, level.par, "clones used = par")
			Assert.eq(r.stars.count, 3, "3 stars")
			Assert.falsy(r.tainted, "no recording was clamped")
			Assert.truthy(r.banked >= level.goal, "goal banked")
			Assert.eq(r.catchesFinal, 0, "clean")
			-- §4.1: a par solution executes in at most par runs x run length x 1.5.
			Assert.le(r.totalTime, math.max(level.par, 1) * level.runSeconds * 1.5, "par execution time")
			for _, run in runs do
				Assert.eq(EventLog.count(run.log, EV.Rejected), 0, "no refused intents")
				Assert.eq(EventLog.count(run.log, EV.Stuck), 0, "no stuck clones")
				Assert.eq(EventLog.count(run.log, EV.Zap), 0, "no zaps")
				Assert.eq(EventLog.count(run.log, EV.Busted), 0, "no busted clones")
			end
		end)

		test(level.id .. ": clones decoded from buffers replay the solution bit-identically", function()
			local plan = Solutions.planFor(level)
			local _, runs1 = Harness.play(level, plan)
			local sim2 = replayFromBuffers(level, plan, runs1, level.par)
			Assert.truthy(HeistSim.result(sim2).complete, "complete")
		end)
	end

	test("bk1_big_score: the final run is the Alarm Run, out by the loading dock", function()
		local level = Harness.level(6)
		local sim, runs = Harness.play(level, Solutions.planFor(level))
		local final = runs[#runs]
		Assert.eq(EventLog.count(final.log, EV.AlarmOn), 1, "the gold trips the alarm")
		Assert.eq(EventLog.count(final.log, EV.Chase), 1, "Gus gives chase (to the vault)")
		Assert.eq(EventLog.count(final.log, EV.Caught), 0, "and never catches anyone")
		Assert.eq(EventLog.count(final.log, EV.DoorOpen, 2), 1, "the scale vault opened")
		local gold = LevelSpec.indexOf(level, "loot", "Gold")
		Assert.eq(EventLog.count(final.log, EV.Bank, level.par + 1, gold), 1, "the runner banks the gold")
		Assert.eq(EventLog.count(final.log, EV.GoalMet), 1, "the gold meets the goal (haul = all the loot)")
		Assert.eq(EventLog.count(final.log, EV.VanLeft), 0, "banked before the van left")
		Assert.eq(final.reason, HeistSim.RUN_END.AllEnded, "then END RUN: the heist clears at the end of the run")
		Assert.truthy(HeistSim.result(sim).complete, "cleared")
	end)

	local party = Harness.level(5)

	test(party.id .. ": the scripted 8 runs bank all three Haul tiers before Dawn (bag 0)", function()
		local sim, runs = Harness.play(party, Solutions.planFor(party))
		local r = HeistSim.result(sim)
		local dump = Harness.dump(runs)
		Assert.eq(r.phase, "Over", "over")
		Assert.eq(r.reason, "Dawn", "a party ends at Dawn\n" .. dump)
		Assert.eq(r.runs, Config.Levels.PARTY_DAWN_RUNS, "Dawn at run 8")
		Assert.truthy(r.complete, "cleared (Haul1)")
		Assert.eq(r.tierMet, 3, "Haul3")
		Assert.eq(r.stars.count, 3, "3 Stars")
		Assert.truthy(r.banked >= party.tiers[3], "top tier banked")
		Assert.eq(r.bag, 0, "no bag level needed")
		Assert.falsy(r.tainted, "no recording was clamped")
		-- §4.1 analogue: the whole party fits in its Dawn x run length.
		Assert.le(r.totalTime, party.dawnRuns * party.runSeconds, "fits before Dawn")
		for i, run in runs do
			Assert.eq(EventLog.count(run.log, EV.Rejected), 0, "run " .. i .. ": no refused intents")
			Assert.eq(EventLog.count(run.log, EV.Shrug), 0, "run " .. i .. ": no clone steals from another")
			Assert.eq(EventLog.count(run.log, EV.Stuck), 0, "run " .. i .. ": no stuck clones")
		end
		local final = runs[#runs]
		Assert.eq(EventLog.count(final.log, EV.AlarmOn), 1, "run 8 robs the till (Alarm Run)")
		local reg = 1 -- the till is loot 1
		Assert.eq(EventLog.count(final.log, EV.Bank, 8, reg), 1, "and banks it (the live run is actor 8)")
	end)

	test(party.id .. ": clones decoded from buffers replay the party bit-identically", function()
		local plan = Solutions.planFor(party)
		local _, runs1 = Harness.play(party, plan)
		replayFromBuffers(party, plan, runs1, party.dawnRuns - 1)
	end)
end
