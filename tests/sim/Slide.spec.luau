-- L2: the slide in the server-authoritative sim (Config.Slide). A live player walks, slides (the client's push,
-- integrated at 240 Hz from Shared/Heist/SlideMath, sent to the sim the way HeistInstance samples it) and asks for
-- the Slide through HeistSim.request (Heist.Interact on the wire). Asserted:
--   1. the run is accepted untainted and nothing is clamped (the recording is exactly what the server saw), for both
--      kinds, with the push a tick ahead of the request and with 0-150 ms of latency;
--   2. the same push without a Slide request taints the run (the window is what lets it through);
--   3. the server cooldown refuses a second Slide too soon, and fast-forward refuses one;
--   4. the next run's clone replays the slide (its positions are the recorded ones, tick for tick), and its recorded
--      Slide event does nothing (no shrug).

local Assert = require("../unit/Assert")
local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local SlideMath = require("../../src/shared/Heist/SlideMath")
local TestLevels = require("./TestLevels")

local SL = Config.Slide
local HZ = Config.Rec.HZ
local WALK = Config.Rec.WALK_SPEED
local SLIDE = Codec.EVENT.Slide
local G = Codec.FLAG.GROUNDED

type Plan = {
	slides: { { at: number, kind: number, dir: number, request: boolean?, early: number? } },
	latency: number?, -- one-way seconds
	stopAt: number?, -- seconds: END RUN
}

-- Where the player is at loop time t: walks +X from the spawn for 0.5 s, then each slide pushes along `dir` (+1 / -1
-- on X) at SlideMath's speed while walking on; stands in between.
local function positionAt(plan: Plan, t: number): number
	local x = 0
	local sub = 12
	local steps = math.floor(t * HZ * sub + 0.5)
	for s = 0, steps - 1 do
		local ts = s / (HZ * sub)
		local v = 0
		if ts < 0.5 then
			v = WALK
		end
		for _, sl in plan.slides do
			local age = ts - sl.at
			if SlideMath.active(age, sl.kind, SL) then
				v = sl.dir * SlideMath.speed(WALK, age, sl.kind, SL)
			end
		end
		x += v / (HZ * sub)
	end
	return x
end

-- Plays one run: each tick the server reads the position (delayed by the latency), requests arrive delayed too.
local function playRun(sim: any, plan: Plan): any
	local level = sim.level
	local spawn = level.spawns[1]
	local lat = plan.latency or 0
	HeistSim.setLatency(sim, 1, lat)
	HeistSim.startRun(sim)
	local sent: { [number]: boolean } = {}
	local results: { boolean } = {}
	local guard = 0
	while sim.phase == "Run" do
		local tick = sim.nextTick
		local tServer = tick / HZ
		local seen = math.max(0, tServer - lat)
		HeistSim.setInput(sim, 1, spawn.x + positionAt(plan, seen), spawn.y, spawn.z, 0, G)
		for k, sl in plan.slides do
			-- the request leaves the client at the push (or `early` s later: the physics went first)
			local arrive = sl.at + (sl.early or 0) + lat
			if not sent[k] and sl.request ~= false and tServer - 1 / HZ >= arrive - 1e-9 then
				sent[k] = true
				results[k] = HeistSim.request(sim, 1, SLIDE, sl.kind - 1)
			end
		end
		if plan.stopAt and tServer >= plan.stopAt then
			HeistSim.endRun(sim, 1)
		end
		HeistSim.step(sim)
		guard += 1
		assert(guard < 4000, "run did not end")
	end
	return results
end

local function newSim(): any
	return HeistSim.new(TestLevels.corridor(), { players = { 1 } })
end

local function liveRec(sim: any): any
	return sim.finalRecordings[1].rec
end

return function(test)
	test(
		"slide: a sliding run is accepted untainted, nothing clamped (both kinds, push first, 0-150 ms latency)",
		function()
			for _, lat in { 0, 0.05, 0.1, 0.15 } do
				for _, early in { 0, 1 / HZ } do
					local sim = newSim()
					local plan: Plan = {
						slides = {
							{ at = 1, kind = 1, dir = 1, early = early },
							{ at = 2.5, kind = 2, dir = -1, early = early },
						},
						latency = lat,
						stopAt = 4.5,
					}
					local results = playRun(sim, plan)
					Assert.truthy(results[1], "slide accepted")
					Assert.truthy(results[2], "fast slide accepted")
					Assert.falsy(sim.lastRun.tainted, string.format("untainted (latency %.2f, early %.2f)", lat, early))
					local rec = liveRec(sim)
					Assert.eq(rec.vflags, 0, "no validator flags")
					local spawn = sim.level.spawns[1]
					for i = 1, rec.n do
						local seen = math.max(0, (i - 1) / HZ - lat)
						local want = Codec.snapPos(spawn.x + positionAt(plan, seen))
						Assert.eq(rec.px[i], want, "sample " .. i .. " recorded as seen (not clamped)")
					end
					local slides = 0
					for _, e in rec.events do
						if e.kind == SLIDE then
							slides += 1
						end
					end
					Assert.eq(slides, 2, "both Slide events recorded")
				end
			end
		end
	)

	test("slide: the same push without the Slide request taints the run", function()
		local sim = newSim()
		playRun(sim, { slides = { { at = 1, kind = 2, dir = 1, request = false } }, stopAt = 3 })
		Assert.truthy(sim.lastRun.tainted, "tainted")
	end)

	test("slide: the server cooldown and fast-forward refuse a Slide", function()
		local sim = newSim()
		HeistSim.startRun(sim)
		local spawn = sim.level.spawns[1]
		for _ = 1, 10 do
			HeistSim.setInput(sim, 1, spawn.x, spawn.y, spawn.z, 0, G)
			HeistSim.step(sim)
		end
		Assert.truthy(HeistSim.request(sim, 1, SLIDE, 0), "first slide")
		HeistSim.step(sim)
		Assert.falsy(HeistSim.request(sim, 1, SLIDE, 1), "inside the cooldown")
		Assert.falsy(HeistSim.request(sim, 1, SLIDE, 5), "unknown kind")
		for _ = 1, math.ceil(SL.SERVER_COOLDOWN * HZ) do
			HeistSim.step(sim)
		end
		Assert.truthy(HeistSim.request(sim, 1, SLIDE, 1), "after the cooldown")
		sim.rate = Config.Rec.SKIP_SPEED
		for _ = 1, math.ceil(SL.SERVER_COOLDOWN * HZ) do
			HeistSim.step(sim)
		end
		sim.rate = Config.Rec.SKIP_SPEED
		Assert.falsy(HeistSim.request(sim, 1, SLIDE, 0), "fast-forwarding")
	end)

	test("slide: the next run's clone replays the slide tick for tick, its Slide event shrugs nothing", function()
		local sim = newSim()
		local plan: Plan = { slides = { { at = 1, kind = 2, dir = 1 } }, stopAt = 3 }
		playRun(sim, plan)
		Assert.falsy(sim.lastRun.tainted, "run 1 untainted")
		local rec1 = liveRec(sim)
		Assert.eq(sim.phase, "Between", "between runs")
		-- run 2: stand still; the clone of run 1 replays
		local spawn = sim.level.spawns[1]
		HeistSim.startRun(sim)
		local clone = nil
		for _, a in sim.actors do
			if a.kind == "clone" then
				clone = a
			end
		end
		assert(clone, "a clone replays run 1")
		local fastest = 0
		local lastX = clone.x
		while sim.phase == "Run" and sim.nextTick < rec1.n do
			HeistSim.setInput(sim, 1, spawn.x, spawn.y, spawn.z, 0, G)
			local tick = sim.nextTick
			HeistSim.step(sim)
			Assert.eq(clone.x, rec1.px[tick + 1], "clone x at tick " .. tick)
			fastest = math.max(fastest, math.abs(clone.x - lastX) * HZ)
			lastX = clone.x
		end
		Assert.truthy(fastest > WALK * Config.Rec.SPEED_MULT, "the clone moved at slide speed")
		Assert.eq(sim.run.shrugs, 0, "no shrug for the Slide event")
	end)
end
