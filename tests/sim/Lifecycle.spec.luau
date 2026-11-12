-- L2: run lifecycle and heist rules (MASTERPLAN §3.1-3.3, §3.6, §5.2, §7.5).

local Assert = require("../unit/Assert")
local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Interact = require("../../src/shared/Sim/Interact")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Bot = require("./Bot")
local Harness = require("./Harness")
local Solutions = require("./Solutions")
local TestLevels = require("./TestLevels")

local EV = EventLog.EV
local HZ = Config.Rec.HZ
local RUN_END = HeistSim.RUN_END

local function idleRun(sim: any, ticks: number?)
	while sim.phase == "Run" and (ticks == nil or sim.nextTick < ticks) do
		HeistSim.step(sim)
	end
end

return function(test)
	test("END RUN is locked for the first 1.5 s, then ends the run (solo -> loop end)", function()
		local sim = HeistSim.new(Harness.level(2), { players = { 1 } })
		HeistSim.startRun(sim)
		idleRun(sim, 29)
		Assert.falsy(HeistSim.endRun(sim, 1), "refused at 1.45 s")
		HeistSim.step(sim)
		Assert.truthy(HeistSim.endRun(sim, 1), "accepted for the 1.5 s tick")
		HeistSim.step(sim)
		Assert.eq(sim.phase, "Between", "loop over")
		Assert.eq(sim.lastRun.reason, RUN_END.AllEnded, "all live runs ended")
		local rec = sim.players[1].deck.slots[1].rec
		Assert.eq(rec.endReason, Codec.END.EndRun, "recording end reason")
		Assert.eq(rec.n, 31, "samples through the END RUN tick")
	end)

	test("timeout: the tape runs out at the run length and counts as END RUN", function()
		local level = Harness.level(1)
		local sim = HeistSim.new(level, { players = { 1 } })
		HeistSim.startRun(sim)
		idleRun(sim)
		Assert.eq(sim.lastRun.reason, RUN_END.Timeout, "timeout")
		Assert.eq(sim.tick, level.runSeconds * HZ, "last tick")
		local rec = sim.players[1].deck.slots[1].rec
		Assert.eq(rec.endReason, Codec.END.Timeout, "end reason")
		Assert.eq(rec.n, level.runSeconds * HZ + 1, "sample count")
	end)

	test("Relaxed: runs +50% (never a slower clock) and detection x2", function()
		local level = Harness.level(1)
		local sim = HeistSim.new(level, { players = { 1 }, relaxed = true })
		HeistSim.startRun(sim)
		Assert.eq(sim.runLength, level.runSeconds * Config.Rec.RELAXED_LENGTH_MULT, "45 s")
		Assert.near(sim.ctx.catchT, 2 * Config.Sim.GUARD_CATCH_SECONDS, 1e-9, "x2")
	end)

	test("caps are min(level.cap, floor(12 / crew)) and locked when the heist starts", function()
		local level = Harness.level(2)
		local sim = HeistSim.new(level, { players = { 1, 2, 3, 4 } })
		Assert.falsy(HeistSim.addPlayer(sim, 5), "max crew 4")
		HeistSim.startRun(sim)
		Assert.eq(sim.cap, 3, "4 players: 3 each")
		Assert.falsy(HeistSim.addPlayer(sim, 6), "late joiners wait for the next heist")
		idleRun(sim)
		HeistSim.removePlayer(sim, 4)
		Assert.eq(sim.cap, 3, "never re-split mid-heist")
		Assert.eq(sim.players[1].deck.cap, 3, "deck cap")
		Assert.truthy(sim.players[4].orphan, "leaver is an orphan")
		HeistSim.startRun(sim)
		Assert.eq(sim.actors[4].ownerId, 4, "orphan tape still replays (seat order)")
		Assert.eq(sim.liveCount, 3, "no live actor for the leaver")
	end)

	test("co-op: actors in stable order; waiting squeeze once half the crew has ended", function()
		local level = Harness.level(2)
		local sim = HeistSim.new(level, { players = { 7, 9 } })
		HeistSim.startRun(sim)
		idleRun(sim, 40)
		HeistSim.endRun(sim, 7)
		HeistSim.step(sim)
		local t = sim.t
		Assert.near(sim.runLength, t + Config.Rec.WAIT_SQUEEZE_SECONDS, 1e-9, "squeezed to 10 s")
		Assert.eq(EventLog.count(sim.log, EV.Squeeze), 1, "Squeeze logged")
		idleRun(sim)
		Assert.eq(sim.lastRun.reason, RUN_END.Timeout, "the other run times out")
		Assert.eq(sim.lastRun.ticks, math.floor((t + 10) * HZ + 0.5) + 1, "at the squeezed length")
		HeistSim.startRun(sim)
		Assert.eq(sim.actors[1].ownerId, 7, "seat 1 clone first")
		Assert.eq(sim.actors[2].ownerId, 9, "seat 2 clone")
		Assert.eq(sim.actors[3].kind, "live", "then live players")
		Assert.eq(sim.actors[3].ownerId, 7, "seat order")
	end)

	test("a player who leaves mid-run: run ends Left, their clones stay as orphan tapes", function()
		local sim = HeistSim.new(Harness.level(2), { players = { 1, 2 } })
		HeistSim.startRun(sim)
		idleRun(sim)
		HeistSim.startRun(sim)
		idleRun(sim, 50)
		HeistSim.removePlayer(sim, 2)
		Assert.eq(EventLog.count(sim.log, EV.Left), 1, "Left")
		idleRun(sim)
		Assert.eq(#sim.players[2].deck.slots, 1, "the half run is not kept")
		HeistSim.startRun(sim)
		Assert.eq(sim.log.b[1], 3, "3 clones replay: 2 of player 1, the orphan tape")
		Assert.falsy(HeistSim.deckAction(sim, 2, "Delete", 1), "orphans have no deck actions")
	end)

	test("Clone Deck actions only between runs; Undo last run removes the newest clone", function()
		local sim = HeistSim.new(Harness.level(2), { players = { 1 } })
		HeistSim.startRun(sim)
		Assert.falsy(HeistSim.deckAction(sim, 1, "Undo"), "not during a run")
		idleRun(sim)
		Assert.eq(#sim.players[1].deck.slots, 1, "one clone")
		Assert.truthy(HeistSim.deckAction(sim, 1, "Undo"), "undo")
		Assert.eq(#sim.players[1].deck.slots, 0, "gone")
		Assert.falsy(HeistSim.deckAction(sim, 99, "Undo"), "unknown player")
		HeistSim.startRun(sim)
		Assert.eq(sim.log.b[1], 0, "replays the loop without it")
	end)

	test("L1 tutorial: run 1 auto-ends after 2.0 s on the plate; run 2 does not", function()
		local level = Harness.level(1)
		local _, runs = Harness.play(level, {
			runs = {
				{ [1] = { { goPlate = "A" }, { stay = true } } },
				{ [1] = { { go = { -12, 12 } }, { stay = true } } },
			},
		})
		local down = EventLog.firstTick(runs[1].log, EV.PlateDown, 1) :: number
		local auto = EventLog.firstTick(runs[1].log, EV.AutoEnd) :: number
		Assert.eq(auto - down, Config.Sim.L1_AUTO_END_SECONDS * HZ - 1, "2.0 s on the plate (inclusive ticks)")
		Assert.eq(EventLog.count(runs[2].log, EV.AutoEnd), 0, "run 2 has no auto-end")
		Assert.eq(runs[2].reason, RUN_END.Timeout, "run 2 times out")
	end)

	test("L1 tutorial: run 1 ended off the plate -> run 2 auto-ends on it (untilDone), run 3 does not", function()
		local level = Harness.level(1)
		local _, runs = Harness.play(level, {
			runs = {
				{ [1] = { { go = { -12, 12 } }, { endRun = true } } },
				{ [1] = { { goPlate = "A" }, { stay = true } } },
				{ [1] = { { goPlate = "A" }, { stay = true } } },
			},
		})
		Assert.eq(EventLog.count(runs[1].log, EV.AutoEnd), 0, "run 1 ended by END RUN off the plate")
		Assert.eq(EventLog.count(runs[2].log, EV.AutoEnd), 1, "run 2: the auto-end is still armed")
		Assert.eq(EventLog.count(runs[3].log, EV.AutoEnd), 0, "run 3: a clone stands on the plate, so no more")
		Assert.eq(runs[3].reason, RUN_END.Timeout, "run 3 times out")
	end)

	test("L1 tutorial: END RUN tapped on the armed plate counts as the auto-end (P0-1)", function()
		local level = Harness.level(1)
		local sim, runs = Harness.play(level, {
			runs = {
				{ [1] = { { goPlate = "A" }, { endRun = true } } },
				{ [1] = { { goPlate = "A" }, { stay = true } } },
			},
		})
		Assert.eq(runs[1].reason ~= RUN_END.Timeout, true, "run 1 ended by the player, not the timer")
		Assert.truthy(sim.players[1].deck.slots[1].auto, "the clone from run 1 holds the tutorial plate")
		Assert.eq(EventLog.count(runs[2].log, EV.AutoEnd), 0, "run 2 is not re-armed")
		Assert.eq(runs[2].reason, RUN_END.Timeout, "run 2 times out")
	end)

	test("L1 tutorial: when the plate clone is replaced at the cap, the auto-end re-arms", function()
		local level = Harness.level(1)
		local cap = level.cap
		local plan = { runs = {} }
		for _ = 1, cap - 1 do
			table.insert(plan.runs, { [1] = { { go = { -12, 12 } }, { endRun = true } } })
		end
		table.insert(plan.runs, { [1] = { { goPlate = "A" }, { stay = true } } }) -- run cap: auto-ends
		table.insert(plan.runs, { [1] = { { go = { -12, 12 } }, { endRun = true } } }) -- replaces it
		table.insert(plan.runs, { [1] = { { goPlate = "A" }, { stay = true } } })
		local _, runs = Harness.play(level, plan)
		Assert.eq(EventLog.count(runs[cap].log, EV.AutoEnd), 1, "run " .. cap .. " auto-ends on the plate")
		Assert.eq(EventLog.count(runs[cap + 2].log, EV.AutoEnd), 1, "the plate clone was replaced: armed again")
	end)

	test("heist complete ends the run at once and scores the medal inputs", function()
		local level = Harness.level(2)
		local sim, runs = Harness.play(level, Solutions[level.id])
		Assert.eq(runs[3].reason, RUN_END.Complete, "ended by completion")
		local r = HeistSim.result(sim)
		Assert.eq(r.reason, "Complete", "complete")
		Assert.eq(r.clonesUsed, 2, "clones used")
		Assert.near(r.finalRunTime, runs[3].t, 1e-9, "final run time")
		Assert.truthy(r.totalTime > r.finalRunTime, "total loop time across runs")
		Assert.eq(EventLog.count(runs[3].log, EV.HeistComplete), 1, "logged")
		Assert.eq(r.data.haul, 200, "data: haul")
		Assert.eq(r.data.clones, 2, "data: clones")
		Assert.eq(r.data.timeMs, math.floor(r.totalTime * 1000 + 0.5), "data: loop ms")
		Assert.truthy(r.data.beforeDawn and not r.data.tainted, "data: flags")
		Assert.eq(#r.data.recHash, 8, "data: hash string")
		Assert.eq(HeistSim.startRun(sim), nil, "no runs after the heist")
	end)

	test("goal below haul: completes at the end of the run that met the goal", function()
		local spec = TestLevels.corridorSpec()
		spec.goal = 10
		spec.haul = 110
		local level = LevelSpec.compile(spec)
		local sim, runs = Harness.play(level, {
			runs = { { [1] = { { goLoot = "Free" }, { grab = "Free" }, { goVan = true }, { stay = true } } } },
		})
		Assert.eq(EventLog.count(runs[1].log, EV.GoalMet), 1, "goal met")
		Assert.eq(runs[1].reason, RUN_END.Timeout, "the run went on")
		Assert.eq(HeistSim.result(sim).reason, "Complete", "complete at the end of it")
	end)

	test("Dawn: L4 ends after par + 4 = 6 runs, keeping banked Cash", function()
		local level = Harness.level(4)
		local runs = { { [1] = { { goLoot = "TipJar" }, { grab = "TipJar" }, { goVan = true }, { endRun = true } } } }
		for _ = 2, 8 do
			table.insert(runs, { [1] = { { endRun = true } } })
		end
		local sim, out = Harness.play(level, { runs = runs })
		Assert.eq(#out, 6, "six runs")
		local r = HeistSim.result(sim)
		Assert.eq(r.reason, "Dawn", "Dawn")
		Assert.eq(r.banked, 10, "banked Cash kept")
		Assert.falsy(r.complete, "not complete")
		Assert.eq(r.stars.count, 0, "no stars without the goal")
		Assert.eq(EventLog.count(out[6].log, EV.Dawn), 1, "logged")
	end)

	test("Interact: range, hands full, heavy loot reserved, release and hand-off to a live player", function()
		local level = TestLevels.corridor()
		local free = LevelSpec.indexOf(level, "loot", "Free")
		local sim = HeistSim.new(level, { players = { 1 } })
		HeistSim.startRun(sim)
		HeistSim.setInput(sim, 1, 5, 3, 12) -- 7 studs from Free
		HeistSim.step(sim)
		HeistSim.request(sim, 1, Codec.EVENT.Grab, free)
		HeistSim.step(sim)
		Assert.eq(EventLog.count(sim.log, EV.Rejected), 1, "out of range")
		Assert.eq(sim.log.c[sim.log.n], Interact.FAIL.Range, "reason Range")
		-- Run 1: grab Free, carry it to (0, -5), put it down, END RUN.
		sim = HeistSim.new(level, { players = { 1 } })
		local plan = {
			{ goLoot = "Free" },
			{ grab = "Free" },
			{ go = { 0, -5 } },
			{ release = true },
			{ go = { -2, 8 } },
			{ endRun = true },
		}
		HeistSim.startRun(sim)
		Harness.runOnce(sim, { Bot.new(level, 1, plan) }, Harness.history())
		-- Run 2: the clone repeats it; the live player waits at the drop spot and takes it.
		HeistSim.startRun(sim)
		local take = { { go = { 0.5, -5 } }, { waitUntil = 3.5 }, { grab = "Free" }, { goVan = true }, { stay = true } }
		local run2 = Harness.runOnce(sim, { Bot.new(level, 1, take) }, Harness.history())
		Assert.eq(EventLog.count(run2.log, EV.Release, 1), 1, "the clone put it down")
		Assert.eq(EventLog.count(run2.log, EV.Grab, 2), 1, "the player picked it up")
		Assert.eq(EventLog.count(run2.log, EV.Bank, 2), 1, "and banked it")
		-- Heavy loot is in the format but grips are not live yet.
		local spec = TestLevels.corridorSpec()
		spec.loot[2].heavy = { grips = 2, maxGrips = 4 }
		local heavy = LevelSpec.compile(spec)
		local s3 = HeistSim.new(heavy, { players = { 1 } })
		HeistSim.startRun(s3)
		HeistSim.setInput(s3, 1, 5, 3, 8)
		HeistSim.step(s3)
		HeistSim.request(s3, 1, Codec.EVENT.Grab, 2)
		HeistSim.step(s3)
		Assert.eq(s3.log.c[s3.log.n], Interact.FAIL.Unsupported, "heavy grips reserved")
	end)

	test("Alarm Run: the top loot trips it; Gus chases; shutter locks at +4 s; van leaves at +8 s", function()
		local level = TestLevels.alarm()
		local route = {
			{ go = { 0, -25 } },
			{ go = { 16, -30 } },
			{ go = { 16, -45 } },
			{ goLoot = "Diamond" },
			{ grab = "Diamond" },
			{ go = { 16, -45 } },
			{ stay = true },
		}
		local sim, runs = Harness.play(level, { runs = { { [1] = route } } })
		local log = runs[1].log
		local on = EventLog.firstTick(log, EV.AlarmOn) :: number
		Assert.eq(on, EventLog.firstTick(log, EV.Grab, 1, 1), "tripped by the grab")
		Assert.truthy(EventLog.firstTick(log, EV.Chase, 1) ~= nil, "Gus chases")
		Assert.eq(EventLog.firstTick(log, EV.AlarmLock), on + 4 * HZ, "lock at +4 s")
		local shut = EventLog.firstTick(log, EV.DoorShut, 1) :: number
		Assert.eq(shut, on + 4 * HZ + math.ceil(Config.Sim.DOOR_CLOSE_SECONDS * HZ), "shutter shut after sliding")
		-- Run 1 has one actor: the player (id 1).
		local caught = EventLog.firstTick(log, EV.Caught, 1, 1)
		if caught then
			Assert.eq(runs[1].reason, RUN_END.AllEnded, "caught: the run ends")
			Assert.eq(EventLog.count(log, EV.Drop, 1, 1), 1, "the diamond drops")
			Assert.truthy((caught :: number) < on + 8 * HZ, "caught before the van left")
		else
			Assert.eq(EventLog.firstTick(log, EV.VanLeft), on + 8 * HZ, "van leaves at +8 s")
			Assert.eq(runs[1].reason, RUN_END.VanLeft, "the van ends the run")
		end
		Assert.eq(sim.banked, 0, "nothing banked")
	end)

	test("Alarm Run: an earlier clone is a decoy (Gus chases the nearest actor he can see)", function()
		local level = TestLevels.alarm()
		local _, runs = Harness.play(level, {
			runs = {
				{ [1] = { { go = { -10, 4 } }, { endRun = true } } },
				{
					[1] = {
						{ go = { 0, -25 } },
						{ go = { 16, -30 } },
						{ go = { 16, -45 } },
						{ goLoot = "Diamond" },
						{ grab = "Diamond" },
						{ stay = true },
					},
				},
			},
		})
		local log = runs[2].log
		-- Run 2 actors: the decoy clone is 1, the player is 2.
		Assert.truthy(EventLog.firstTick(log, EV.Chase, 1, 1) ~= nil, "Gus goes for the decoy")
		Assert.truthy(EventLog.firstTick(log, EV.Busted, 1, 1) ~= nil, "and busts it by contact")
		Assert.eq(EventLog.count(log, EV.GuardHuh), 0, "no 'huh?' freeze during a chase")
	end)

	test("Relaxed is offered after 3 busts in one heist", function()
		local level = TestLevels.watch()
		local sim = HeistSim.new(level, { players = { 1 } })
		for _ = 1, 3 do
			Assert.falsy(HeistSim.offerRelaxed(sim, 1), "not yet")
			HeistSim.startRun(sim)
			while sim.phase == "Run" do
				HeistSim.setInput(sim, 1, 0, 3, -8)
				HeistSim.step(sim)
			end
			HeistSim.deckAction(sim, 1, "DeleteBusted")
		end
		Assert.truthy(HeistSim.offerRelaxed(sim, 1), "offered")
	end)
end
