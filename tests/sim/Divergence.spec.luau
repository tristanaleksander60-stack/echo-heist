-- L2: divergence (MASTERPLAN §3.2 rule 2, §8.9): when the world no longer matches a
-- clone's recording it fails visibly, with a cause: Stuck (a door shut early: Bonk),
-- Shrug (its loot is gone), Zap (its laser is back on), Busted (Gus).

local Assert = require("../unit/Assert")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Interact = require("../../src/shared/Sim/Interact")
local Harness = require("./Harness")
local Solutions = require("./Solutions")

local EV = EventLog.EV

return function(test)
	test("door closed early -> the clone goes Stuck (cause Door = Bonk) and holds its pose", function()
		local level = Harness.level(2)
		local positions = {}
		local sim, runs = Harness.play(level, {
			runs = {
				{ [1] = { { goPlate = "A" }, { endRun = true } } },
				{ [1] = { { go = { 0, -10 } }, { waitUntil = 4.0 }, { go = { 0, -26 } }, { endRun = true } } },
				-- Redo #1: hold A only until 2 s, then step off: the back-room door shuts.
				{
					deck = { { 1, "Redo", 1 } },
					[1] = { { goPlate = "A" }, { waitUntil = 2.0 }, { go = { -10, 6 } }, { stay = true } },
				},
			},
		}, {
			onTick = function(s: any)
				if s.runIndex == 3 then
					local a = s.actors[1]
					table.insert(positions, { a.x, a.z, a.state })
				end
			end,
		})
		local log = runs[3].log
		-- Run 3 actors: slot 2's clone is actor 1 (slot 1 is being redone), the player is 2.
		local tick = EventLog.firstTick(log, EV.Stuck, 1) :: number
		Assert.truthy(tick ~= nil, "clone stuck\n" .. table.concat(runs[3].lines, "\n"))
		local i = 0
		for k = 1, log.n do
			if log.kind[k] == EV.Stuck then
				i = k
			end
		end
		Assert.eq(log.b[i], HeistSim.CAUSE.Door, "cause: door (Bonk)")
		Assert.eq(log.c[i], 1, "the back-room door")
		Assert.truthy((EventLog.firstTick(log, EV.DoorShut, 1) :: number) < tick, "after the door shut")
		local held = positions[tick + 1]
		for k = tick + 1, #positions do
			Assert.eq(positions[k][1], held[1], "holds x")
			Assert.eq(positions[k][2], held[2], "holds z")
			Assert.eq(positions[k][3], "Stuck", "stays Stuck")
		end
		Assert.truthy(held[2] > -19.5, "stopped on the near side of the door")
		Assert.eq(sim.players[1].deck.slots[2].status, "Stuck", "deck status dot")
		Assert.eq(runs[3].stuck, 1, "counted")
	end)

	test("loot already banked -> the clone Shrugs and carries on", function()
		local level = Harness.level(2)
		local sim, runs = Harness.play(level, {
			runs = {
				{ [1] = { { goLoot = "TipJar" }, { grab = "TipJar" }, { goVan = true }, { endRun = true } } },
				{ [1] = { { stay = true } } },
			},
		})
		Assert.eq(EventLog.count(runs[1].log, EV.Bank), 1, "banked in run 1")
		local log = runs[2].log
		Assert.eq(EventLog.count(log, EV.Shrug, 1), 1, "clone shrugs")
		for k = 1, log.n do
			if log.kind[k] == EV.Shrug then
				Assert.eq(log.c[k], Interact.FAIL.Gone, "reason: gone")
			end
		end
		Assert.eq(sim.banked, 10, "banked once, persists across runs")
		Assert.eq(sim.players[1].deck.slots[1].status, "Shrug", "status dot")
	end)

	test("laser back on -> the clone that walked the grid Zaps itself on cue", function()
		local level = Harness.level(3)
		local sol = Solutions[level.id]
		local sim, runs = Harness.play(level, {
			runs = {
				sol.runs[1],
				sol.runs[2],
				{ [1] = { { wait = 1 }, { go = { 0, -40 } }, { endRun = true } } },
				-- Delete clone 2 (the one holding plate B): the grid stays on.
				{ deck = { { 1, "Delete", 2 } }, [1] = { { stay = true } } },
			},
		})
		Assert.eq(EventLog.count(runs[3].log, EV.Zap), 0, "walked through while it was off")
		local log = runs[4].log
		-- Run 4 actors: clone A (1), the grid walker (2), the player (3).
		Assert.eq(EventLog.count(log, EV.Zap, 2, 1), 1, "zapped by the grid")
		Assert.eq(sim.players[1].deck.slots[2].status, "Zapped", "status dot")
	end)

	test("Gus catches the player -> next run the clone repeats it and is Busted; Delete busted", function()
		local level = Harness.level(4)
		local sim, runs = Harness.play(level, {
			runs = {
				{ [1] = { { goPlate = "A" }, { endRun = true } } },
				{ [1] = { { go = { 0, -24 } }, { stay = true } } },
				{ [1] = { { stay = true } } },
				{ deck = { { 1, "DeleteBusted" } }, [1] = { { stay = true } } },
			},
		})
		local caught = EventLog.firstTick(runs[2].log, EV.Caught, 1, 2) :: number
		Assert.truthy(caught ~= nil, "the player was caught in run 2")
		Assert.eq(runs[2].catches, 1, "one catch")
		local busted = EventLog.firstTick(runs[3].log, EV.Busted, 1, 2) :: number
		Assert.eq(busted, caught, "busted on the same tick (the mistake repeats)")
		Assert.eq(EventLog.firstTick(runs[3].log, EV.GuardHuh, 1), busted, "'huh?' freeze (WRONG ONE)")
		Assert.eq(runs[4].log.b[1], 2, "Delete busted: clone 1 and run 3's clone replay in run 4")
		Assert.eq(EventLog.count(runs[4].log, EV.Busted), 0, "the busted clone is gone")
		for _, slot in sim.players[1].deck.slots do
			Assert.truthy(slot.status ~= "Busted", "no busted slot left")
		end
	end)
end
