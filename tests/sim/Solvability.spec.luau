-- L2: every launch level is solvable at par from its (PLACEHOLDER, scripted)
-- solution, and the same clones replayed from encoded buffers clear it identically
-- (the path human-recorded levels/<id>.solution.bin files will take, §8.9).

local Assert = require("../unit/Assert")
local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Bot = require("./Bot")
local Harness = require("./Harness")
local Solutions = require("./Solutions")

local EV = EventLog.EV

return function(test)
	Assert.truthy(Solutions.PLACEHOLDER, "solutions are labelled placeholders")

	for n = 1, 4 do
		local level = Harness.level(n)
		local plan = Solutions[level.id]

		test(level.id .. ": the scripted solution completes the heist at par with 3 stars", function()
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
			local sim1, runs1 = Harness.play(level, plan)
			-- The deck after the par runs, through the wire format.
			local recs = {}
			for _, slot in sim1.players[1].deck.slots do
				local buf = Codec.encode(slot.rec)
				Assert.le(buffer.len(buf), Config.Rec.BUDGET_BYTES_PER_SECOND * level.runSeconds + 64, "size budget")
				local rec = Codec.decode(buf)
				Assert.truthy(rec, "decodes")
				table.insert(recs, rec)
			end
			Assert.eq(#recs, level.par, "par clones in the deck")
			local sim2 = HeistSim.new(level, { players = { 1 } })
			Assert.truthy(HeistSim.seedDeck(sim2, 1, recs), "seeded")
			-- Fast-forward the heist to the final run: the run index is part of the log.
			sim2.runIndex = level.par
			sim2.phase = "Lobby"
			HeistSim.startRun(sim2)
			local final = plan.runs[#plan.runs]
			local run2 = Harness.runOnce(sim2, { Bot.new(level, 1, final[1]) }, Harness.history())
			local last = runs1[#runs1]
			Assert.eq(run2.hash, last.hash, "final run log hash\n" .. table.concat(run2.lines, "\n"))
			Assert.truthy(HeistSim.result(sim2).complete, "complete")
		end)
	end
end
