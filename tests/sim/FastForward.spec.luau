-- L2: fast-forward equivalence (MASTERPLAN §3.1, §8.2, §8.9): a loop driven by the
-- LoopClock at 3x gives the same event log as at 1x; it is recorded as standing;
-- moving (or nothing left to watch) cancels it; hitches are capped.

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Harness = require("./Harness")
local Solutions = require("./Solutions")

local FRAME = 1 / 60

-- L3 after its two par runs (both clones in the deck), ready for run 3.
local function l3Ready(): any
	local level = Harness.level(3)
	local sol = Solutions[level.id]
	local sim = Harness.play(level, { runs = { sol.runs[1], sol.runs[2] } })
	return sim, level
end

-- Plays run 3 on the clock with the player standing at spawn. `ffAt`: loop time at
-- which the fast-forward pill is held. Returns run hash, server seconds elapsed, sim.
local function clockRun(sim: any, level: any, ffAt: number?, jitter: number?): (number, number, any)
	local now = 1000
	HeistSim.startRun(sim, now)
	local spawn = level.spawns[1]
	local ffOn = false
	local frames = 0
	while sim.phase == "Run" do
		now += FRAME
		frames += 1
		local j = if jitter then (frames % 2) * jitter else 0
		HeistSim.setInput(sim, 1, spawn.x + j, spawn.y, spawn.z)
		if ffAt and not ffOn and sim.t >= ffAt then
			ffOn = HeistSim.setRate(sim, now, Config.Rec.SKIP_SPEED)
			Assert.truthy(ffOn, "fast-forward accepted")
		end
		HeistSim.update(sim, now)
		assert(frames < 10000, "runaway")
	end
	return sim.lastRun.hash, now - 1000, sim
end

return function(test)
	test("3x clock and 1x clock give the same event log", function()
		local simA, level = l3Ready()
		local hA, elapsedA = clockRun(simA, level, nil)
		local simB = l3Ready()
		local hB, elapsedB = clockRun(simB, level, 0.5)
		Assert.eq(hB, hA, "same log hash")
		Assert.eq(simB.lastRun.ticks, simA.lastRun.ticks, "same tick count")
		Assert.truthy(elapsedB < elapsedA - 1, string.format("faster: %.2f vs %.2f s", elapsedB, elapsedA))
		-- Also the same as stepping tick by tick with no clock at all.
		local simC = l3Ready()
		HeistSim.startRun(simC)
		while simC.phase == "Run" do
			HeistSim.setInput(simC, 1, level.spawns[1].x, level.spawns[1].y, level.spawns[1].z)
			HeistSim.step(simC)
		end
		Assert.eq(simC.lastRun.hash, hA, "same as plain steps")
	end)

	test("fast-forward is recorded as standing and ends when the clones are done", function()
		local sim, level = l3Ready()
		local _, _, s = clockRun(sim, level, 0.5, 0.02) -- sub-threshold jitter while holding
		local rec = s.players[1].deck.slots[3].rec
		local x0 = rec.px[12]
		for i = 12, 40 do
			Assert.eq(rec.px[i], x0, "standing sample " .. i)
		end
		Assert.eq(s.rate, 1, "back to 1x once nothing is left to watch")
	end)

	test("moving cancels it; it is refused while moving or with nothing to watch", function()
		local sim, level = l3Ready()
		local spawn = level.spawns[1]
		HeistSim.startRun(sim, 0)
		HeistSim.setInput(sim, 1, spawn.x, spawn.y, spawn.z)
		HeistSim.step(sim)
		Assert.truthy(HeistSim.setRate(sim, 0.05, 3), "accepted while standing")
		HeistSim.setInput(sim, 1, spawn.x + 0.5, spawn.y, spawn.z)
		HeistSim.step(sim)
		Assert.eq(sim.rate, 1, "moving cancelled it")
		HeistSim.setInput(sim, 1, spawn.x + 1, spawn.y, spawn.z) -- still walking
		Assert.falsy(HeistSim.setRate(sim, 0.1, 3), "refused while moving")
		local lone = Harness.level(1)
		local s1 = HeistSim.new(lone, { players = { 1 } })
		HeistSim.startRun(s1, 0)
		HeistSim.step(s1)
		Assert.falsy(HeistSim.canFastForward(s1), "run 1: no clones to watch")
	end)

	test("a server hitch runs at most MAX_CATCHUP_TICKS per update", function()
		local sim, level = l3Ready()
		HeistSim.startRun(sim, 0)
		HeistSim.setInput(sim, 1, level.spawns[1].x, level.spawns[1].y, level.spawns[1].z)
		Assert.eq(HeistSim.update(sim, 5), Config.Rec.MAX_CATCHUP_TICKS, "capped")
		Assert.eq(HeistSim.update(sim, 5), Config.Rec.MAX_CATCHUP_TICKS, "catches up over frames")
	end)
end
