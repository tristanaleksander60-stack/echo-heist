-- L2: the sprint in the server-authoritative sim (Config.Sprint; owner, live v125). The client raises WalkSpeed to
-- WalkSpeed x MULT (eased over RAMP_SECONDS, Shared/Heist/SprintMath); nothing goes to the server: the recording is
-- positions. Asserted:
--   1. a run that walks, sprints, turns back and sprints again (with the ramps) is accepted untainted and unclamped,
--      every sample recorded exactly as the server saw it, with 0-150 ms of latency;
--   2. the next run's clone replays it tick for tick at sprint speed;
--   3. the HOLD FAST pill's input (HeistSim.ffPending) stays true the whole time you sprint past a pending clone,
--      while fast-forward itself (canFastForward) waits for you to stand: walking never flickers the pill;
--   4. a run 10 % past the validator's limit (faster than any sprint) still taints.

local Assert = require("../unit/Assert")
local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local SprintMath = require("../../src/shared/Heist/SprintMath")
local TestLevels = require("./TestLevels")

local SP = Config.Sprint
local HZ = Config.Rec.HZ
local WALK = Config.Rec.WALK_SPEED
local G = Codec.FLAG.GROUNDED

-- The plan: seconds -> (direction on X, sprinting?). Walk +X 0-0.5 s, sprint +X 0.5-1.6 s, stand 1.6-1.8 s, sprint
-- -X 1.8-3.0 s, walk -X 3.0-3.4 s, stand after.
local function intent(t: number): (number, boolean)
	if t < 0.5 then
		return 1, false
	elseif t < 1.6 then
		return 1, true
	elseif t < 1.8 then
		return 0, false
	elseif t < 3.0 then
		return -1, true
	elseif t < 3.4 then
		return -1, false
	end
	return 0, false
end

-- Where the client is at loop time t (integrated at 240 Hz with SprintMath's eased WalkSpeed); `mult` scales the
-- sprint (1 = the real one) for the speed-hack check.
local function positionAt(t: number, mult: number?): number
	local sub = 12
	local dt = 1 / (HZ * sub)
	local steps = math.floor(t * HZ * sub + 0.5)
	local x, share = 0, 0
	for s = 0, steps - 1 do
		local dir, sprinting = intent(s * dt)
		share = SprintMath.ease(share, sprinting and dir ~= 0, dt, SP)
		local v = SprintMath.walkSpeed(WALK, share, SP)
		if mult and share > 0 then
			v = WALK * mult
		end
		x += dir * v * dt
	end
	return x
end

local function newSim(): any
	return HeistSim.new(TestLevels.corridor(), { players = { 1 } })
end

local function playRun(sim: any, latency: number, stopAt: number, mult: number?)
	local spawn = sim.level.spawns[1]
	HeistSim.setLatency(sim, 1, latency)
	HeistSim.startRun(sim)
	local guard = 0
	while sim.phase == "Run" do
		local tServer = sim.nextTick / HZ
		local seen = math.max(0, tServer - latency)
		HeistSim.setInput(sim, 1, spawn.x + positionAt(seen, mult), spawn.y, spawn.z, 0, G)
		if tServer >= stopAt then
			HeistSim.endRun(sim, 1)
		end
		HeistSim.step(sim)
		guard += 1
		assert(guard < 4000, "run did not end")
	end
end

return function(test)
	test("sprint: a sprinting run is accepted untainted, nothing clamped (0-150 ms latency)", function()
		for _, lat in { 0, 0.05, 0.1, 0.15 } do
			local sim = newSim()
			playRun(sim, lat, 4)
			Assert.falsy(sim.lastRun.tainted, string.format("untainted (latency %.2f)", lat))
			local rec = sim.finalRecordings[1].rec
			Assert.eq(rec.vflags, 0, "no validator flags")
			local spawn = sim.level.spawns[1]
			local fastest = 0
			for i = 1, rec.n do
				local seen = math.max(0, (i - 1) / HZ - lat)
				Assert.eq(rec.px[i], Codec.snapPos(spawn.x + positionAt(seen)), "sample " .. i .. " as seen")
				if i > 1 then
					fastest = math.max(fastest, math.abs(rec.px[i] - rec.px[i - 1]) * HZ)
				end
			end
			Assert.truthy(fastest > WALK * 1.3, "it really sprinted (" .. fastest .. " studs/s)")
		end
	end)

	test("sprint: the next run's clone replays the sprint tick for tick", function()
		local sim = newSim()
		playRun(sim, 0, 4)
		local rec1 = sim.finalRecordings[1].rec
		local spawn = sim.level.spawns[1]
		HeistSim.startRun(sim)
		local clone = nil
		for _, a in sim.actors do
			if a.kind == "clone" then
				clone = a
			end
		end
		assert(clone, "a clone replays run 1")
		local fastest, lastX = 0, clone.x
		while sim.phase == "Run" and sim.nextTick < rec1.n do
			HeistSim.setInput(sim, 1, spawn.x, spawn.y, spawn.z, 0, G)
			local tick = sim.nextTick
			HeistSim.step(sim)
			Assert.eq(clone.x, rec1.px[tick + 1], "clone x at tick " .. tick)
			fastest = math.max(fastest, math.abs(clone.x - lastX) * HZ)
			lastX = clone.x
		end
		Assert.near(fastest, WALK * SP.MULT, 0.5, "the clone moved at sprint speed")
	end)

	test("sprint: the HOLD FAST pill's input stays up while you sprint past a pending clone", function()
		local sim = newSim()
		playRun(sim, 0, 4)
		local spawn = sim.level.spawns[1]
		HeistSim.startRun(sim)
		local pendingFlips, lastPending = 0, nil
		local sawWait = false
		for tick = 0, math.floor(3.4 * HZ) do
			local t = tick / HZ
			HeistSim.setInput(sim, 1, spawn.x + positionAt(t), spawn.y, spawn.z, 0, G)
			-- the server's view this tick: the new input against where you were (HeistInstance syncs after setInput)
			if HeistSim.ffPending(sim) and not HeistSim.canFastForward(sim) then
				sawWait = true
			end
			HeistSim.step(sim)
			local pending = HeistSim.ffPending(sim)
			if lastPending ~= nil and pending ~= lastPending then
				pendingFlips += 1
			end
			lastPending = pending
		end
		Assert.eq(pendingFlips, 0, "FFPending never flips while you move")
		Assert.truthy(lastPending, "the clone is still pending")
		Assert.truthy(sawWait, "fast-forward itself waits while you move")
		HeistSim.setInput(sim, 1, spawn.x + positionAt(3.4) - 1, spawn.y, spawn.z, 0, G)
		Assert.falsy(HeistSim.setRate(sim, nil, Config.Rec.SKIP_SPEED), "refused while you move")
	end)

	test("sprint: 10 % past the validator's limit still taints", function()
		local sim = newSim()
		playRun(sim, 0, 4, Config.Rec.SPEED_MULT * 1.1)
		Assert.truthy(sim.lastRun.tainted, "tainted")
	end)
end
