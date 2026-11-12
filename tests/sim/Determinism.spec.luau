-- L2: determinism (MASTERPLAN §3.2 rule 3, §8.9): the same inputs give an identical
-- event-log hash twice; loops where no live player moves are identical; a clone
-- does exactly what its live run did; randomness only comes from the injected seed.

local Assert = require("../unit/Assert")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Rng = require("../../src/shared/Sim/Rng")
local Harness = require("./Harness")
local NaiveKid = require("./NaiveKid")
local Solutions = require("./Solutions")
local TestLevels = require("./TestLevels")

local EV = EventLog.EV

local function idle(n: number, redoSlot: number?): { any }
	local runs = {}
	for i = 1, n do
		local run: any = { [1] = { { stay = true } } }
		if redoSlot and i > 1 then
			run.deck = { { 1, "Redo", redoSlot } }
		end
		table.insert(runs, run)
	end
	return runs
end

return function(test)
	for n = 1, 4 do
		local level = Harness.level(n)
		test(level.id .. ": same inputs twice -> identical event-log hashes", function()
			local simA, runsA = Harness.play(level, Solutions[level.id])
			local simB, runsB = Harness.play(level, Solutions[level.id])
			Assert.eq(#runsA, #runsB, "run count")
			for i = 1, #runsA do
				Assert.eq(runsA[i].hash, runsB[i].hash, "run " .. i)
			end
			Assert.eq(simA.heistHash, simB.heistHash, "heist hash")
		end)
	end

	test("naive wandering inputs are deterministic too (seeded)", function()
		local level = Harness.level(4)
		local plan = NaiveKid.plan(level, 1234, 4)
		local a = Harness.play(level, plan)
		local b = Harness.play(level, NaiveKid.plan(level, 1234, 4))
		Assert.eq(a.heistHash, b.heistHash, "heist hash")
		local c = Harness.play(level, NaiveKid.plan(level, 999, 4))
		Assert.truthy(c.heistHash ~= a.heistHash, "a different kid plays differently")
	end)

	test("loops with no live player moving give identical event logs (L2, L4)", function()
		for _, n in { 2, 4 } do
			local level = Harness.level(n)
			local sol = Solutions[level.id]
			local runs = { sol.runs[1], sol.runs[2] }
			-- Three idle runs (L4's Dawn is at run 6, and its log says so).
			for _, r in idle(3, 3) do
				table.insert(runs, r)
			end
			local _, out = Harness.play(level, { runs = runs })
			Assert.eq(#out, 5, "five runs")
			-- Skip entry 1 (RunStart carries the run index).
			local h3 = EventLog.hash(out[3].log, 2)
			for i = 4, 5 do
				Assert.eq(EventLog.hash(out[i].log, 2), h3, level.id .. " idle run " .. i)
			end
			Assert.truthy(out[3].log.n > 3, "something happened in those loops")
		end
	end)

	test("a clone does exactly what its live run did (same ticks, same outcomes)", function()
		local level = Harness.level(1)
		local _, out = Harness.play(level, {
			runs = {
				{ [1] = { { goPlate = "A" }, { stay = true } } },
				-- Redo #1 would replace it; instead stand aside so only the clone acts.
				{ [1] = { { go = { -12, 12 } }, { stay = true } } },
			},
		})
		local live = EventLog.firstTick(out[1].log, EV.PlateDown, 1)
		local clone = EventLog.firstTick(out[2].log, EV.PlateDown, 1)
		Assert.eq(clone, live, "plate pressed on the same tick")
		Assert.eq(
			EventLog.firstTick(out[2].log, EV.DoorOpen, 1),
			EventLog.firstTick(out[1].log, EV.DoorOpen, 1),
			"door opened on the same tick"
		)
	end)

	test("randomness comes only from the injected seed (respawning loot spots)", function()
		local spec = TestLevels.corridorSpec()
		spec.loot[2].respawn = 1
		spec.loot[2].spots = { { x = 6, y = 3, z = 6 }, { x = -6, y = 3, z = 6 }, { x = 8, y = 3, z = 2 } }
		local level = LevelSpec.compile(spec)
		local seeds = {}
		local function play(seed: number): (number, { number })
			local calls = {}
			local sim = HeistSim.new(level, {
				players = { 1 },
				seed = seed,
				newRandom = function(s: number)
					table.insert(calls, s)
					return Rng.new(s)
				end,
			})
			local spots = {}
			for _ = 1, 3 do
				HeistSim.startRun(sim)
				table.insert(spots, sim.loot.items[2].spot)
				while sim.phase == "Run" do
					HeistSim.step(sim)
				end
			end
			return sim.heistHash, spots, calls
		end
		local h1, s1, calls = play(77)
		local h2, s2 = play(77)
		Assert.eq(h1, h2, "same seed, same heist")
		for i = 1, 3 do
			Assert.eq(s1[i], s2[i], "same spot " .. i)
		end
		Assert.eq(calls[1], 78, "run 1 uses seed + 1")
		Assert.eq(calls[3], 80, "run 3 uses seed + 3")
		local differs = false
		for seed = 1, 10 do
			local _, s = play(seed)
			for i = 1, 3 do
				seeds[i] = seeds[i] or s[i]
				differs = differs or s[i] ~= seeds[i]
			end
		end
		Assert.truthy(differs, "seeds change the spots")
	end)
end
