-- L2: L6 "The Big Score: Bank" (MASTERPLAN §4.2 row 6, §3.6, §3.1): the scale vault
-- needs all four plates, LOCKDOWN and the van timer, a catch trips the alarm, a
-- decoy clone draws Gus (over par: a clear without the Crew star), Dawn at run 8.

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Harness = require("./Harness")
local Solutions = require("./Solutions")

local EV = EventLog.EV
local HZ = Config.Rec.HZ

return function(test)
	local level = Harness.level(6)
	local VAULT = LevelSpec.indexOf(level, "door", "VaultDoor")
	local DOCK = LevelSpec.indexOf(level, "door", "LoadingDock")
	local FRONT = LevelSpec.indexOf(level, "door", "FrontDoors")

	test("three clones are not enough: the scale vault stays shut", function()
		local sol = Solutions.planFor(level)
		local final = Solutions.planFor(level).runs[5]
		-- Bail out after a while at the vault door instead of waiting forever.
		final[1][8] = { wait = 6 }
		local _, out = Harness.play(level, { runs = { sol.runs[1], sol.runs[2], sol.runs[3], final } })
		Assert.eq(#out, 4, "four runs")
		Assert.eq(EventLog.count(out[4].log, EV.DoorOpen, VAULT), 0, "no 4th actor, no vault")
		Assert.eq(EventLog.count(out[4].log, EV.Grab), 0, "no gold")
	end)

	test("LOCKDOWN: front doors and the dock shut 10 s after the alarm, the van leaves at 20 s", function()
		local sol = Solutions.planFor(level)
		local greedy = {
			[1] = {
				{ go = { 0, 9 } },
				{ go = { 0, -7 } },
				{ go = { -4, -11 } },
				{ waitUntil = 6.0 },
				{ go = { 0, -13 } },
				{ go = { 0, -38 } },
				{ go = { 0, -46 } },
				Solutions.untilOpen(level, "VaultDoor"),
				{ goLoot = "Gold" },
				{ grab = "Gold" },
				{ stay = true }, -- admiring the gold in the vault
			},
		}
		-- White-box: Gus is held where he stands (chase speed 0) so the run lasts.
		local _, out = Harness.play(level, { runs = { sol.runs[1], sol.runs[2], sol.runs[3], sol.runs[4], greedy } }, {
			onTick = function(s: any)
				s.ctx.chaseSpeed = 0
			end,
		})
		local run = out[5]
		local alarmAt = EventLog.firstTick(run.log, EV.AlarmOn) :: number
		Assert.truthy(alarmAt ~= nil, "the gold trips the alarm")
		local lockAt = EventLog.firstTick(run.log, EV.AlarmLock) :: number
		Assert.eq(lockAt - alarmAt, Config.Sim.ALARM_LOCK_SECONDS * HZ, "LOCKDOWN at 10 s")
		Assert.eq(EventLog.count(run.log, EV.AlarmLock, 2), 1, "two doors lock")
		Assert.truthy(EventLog.firstTick(run.log, EV.DoorShut, DOCK) ~= nil, "the dock shuts though D is held")
		Assert.truthy(EventLog.firstTick(run.log, EV.DoorShut, FRONT) ~= nil, "the front doors shut")
		Assert.eq(run.reason, HeistSim.RUN_END.VanLeft, "the van left without you")
		Assert.eq(EventLog.firstTick(run.log, EV.VanLeft), alarmAt + Config.Sim.ALARM_VAN_SECONDS * HZ, "at 20 s")
		Assert.eq(run.banked, 0, "carried gold is not banked")
	end)

	test("in a Big Score, Gus catching a live player trips the alarm", function()
		local sol = Solutions.planFor(level)
		local reckless = {
			[1] = {
				{ go = { 0, 9 } },
				{ go = { 0, -7 } },
				{ go = { 0, -13 } },
				{ go = { 0, -20 } },
				{ go = { 6, -22 } },
				{ stay = true },
			},
		}
		local _, out = Harness.play(level, { runs = { sol.runs[1], reckless } })
		local run = out[2]
		local caughtAt = EventLog.firstTick(run.log, EV.Caught)
		Assert.truthy(caughtAt ~= nil, "caught in the hall")
		Assert.eq(EventLog.firstTick(run.log, EV.AlarmOn, 0), caughtAt, "the catch trips the alarm (actor 0)")
	end)

	test("a decoy clone draws the chase; over par it is a clear without the Crew star", function()
		local sol = Solutions.planFor(level)
		-- Run 5: wait by the staff door, dash into the hall as the gold is grabbed next
		-- run, then run circles in the lobby.
		local decoy = {
			[1] = {
				{ go = { 0, 9 } },
				{ go = { 0, -7 } },
				{ go = { -4, -11 } },
				{ waitUntil = 9.0 },
				{ go = { 0, -13 } },
				{ go = { 6, -18 } },
				{ go = { 0, -13 } },
				{ go = { 0, -2 } },
				{ go = { -14, 4 } },
				{ go = { 14, 4 } },
				{ stay = true },
			},
		}
		local runs = { sol.runs[1], sol.runs[2], sol.runs[3], sol.runs[4], decoy, Solutions.planFor(level).runs[5] }
		local sim, out = Harness.play(level, { runs = runs })
		local r = HeistSim.result(sim)
		local final = out[6]
		local decoyId = 5 -- clones are actors 1..5 in slot order
		local firstTarget = 0
		for i = 1, final.log.n do
			if final.log.kind[i] == EV.Chase and final.log.b[i] ~= 0 then
				firstTarget = final.log.b[i]
				break
			end
		end
		Assert.eq(firstTarget, decoyId, "Gus goes for the decoy")
		Assert.eq(EventLog.count(final.log, EV.Busted, 1, decoyId), 1, "the decoy takes the hit")
		Assert.eq(EventLog.count(final.log, EV.Caught), 0, "the runner gets away")
		Assert.truthy(r.complete, "the heist is cleared")
		Assert.eq(r.clonesUsed, level.par + 1, "one over par")
		Assert.truthy(r.stars.haul and not r.stars.crew, "Haul without Crew")
	end)

	test("an idle crew meets Dawn at run 8 (par + 4)", function()
		local runs = {}
		for _ = 1, 8 do
			table.insert(runs, { [1] = { { stay = true } } })
		end
		local sim = Harness.play(level, { runs = runs })
		local r = HeistSim.result(sim)
		Assert.eq(r.reason, "Dawn", "Dawn")
		Assert.eq(r.runs, 8, "at run 8")
		Assert.eq(r.stars.count, 0, "no stars")
	end)

	test("waiting by the staff door is safe; a kid who misses a window crosses in the next", function()
		local sol = Solutions.planFor(level)
		-- Anywhere on the lobby side of the staff door, for the whole 45 s run.
		for x = -8, 8, 2 do
			for z = -13, -9, 2 do
				local wait = { [1] = { { go = { 0, 9 } }, { go = { 0, -7 } }, { go = { x, z } }, { stay = true } } }
				local _, out = Harness.play(level, { runs = { sol.runs[1], wait } })
				Assert.eq(EventLog.count(out[2].log, EV.Caught), 0, string.format("never caught at (%d, %d)", x, z))
			end
		end
		-- Run 3 (plate C) missing the 6 s window and crossing one patrol later.
		local late = {
			[1] = {
				{ go = { 0, 9 } },
				{ go = { 0, -7 } },
				{ go = { -4, -11 } },
				{ waitUntil = 14.0 },
				{ go = { 0, -13 } },
				{ go = { 0, -38 } },
				{ goPlate = "C" },
				{ endRun = true },
			},
		}
		local _, out = Harness.play(level, { runs = { sol.runs[1], sol.runs[2], late } })
		local run = out[3]
		for _, k in { "Caught", "Busted", "Zap" } do
			Assert.eq(EventLog.count(run.log, EV[k]), 0, "the second window: no " .. k)
		end
		local c = LevelSpec.indexOf(level, "plate", "C")
		Assert.eq(EventLog.count(run.log, EV.PlateDown, c), 1, "and stands on C")
	end)

	test("the haul is all the loot: the coins still count after the gold", function()
		Assert.eq(level.haul, 2000 + 150 + 50 + 20, "haul = gold + coins + drawer + candy")
		Assert.truthy(level.haul > level.goal, "banking the gold does not end the heist at once")
	end)
end
