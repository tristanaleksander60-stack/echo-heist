-- L2: latency injection (MASTERPLAN §8.10, §8.9). Live streams are delayed by
-- 50-250 ms (1-5 ticks each way). Asserted rules:
--   1. hazard checks (laser, door bonk) use the state at t - min(latency, 150 ms):
--      the player is favoured, and without the rewind the same play is unfair;
--   2. with the 0.2 s visual lead, what the player sees is never more generous than
--      the server: a zap only happens if the client showed the beam ON while touching
--      it, and a door never taints a player who stopped when it looked shut;
--   3. a plate counts a live player from the server's receipt of their position;
--   5. Gus's detection of live players uses the same rewind (capped at 150 ms).

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local Geom = require("../../src/shared/Sim/Geom")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Mechanisms = require("../../src/shared/Sim/Mechanisms")
local Sampler = require("../../src/shared/Rec/Sampler")
local Bot = require("./Bot")
local Harness = require("./Harness")
local TestLevels = require("./TestLevels")

local EV = EventLog.EV
local HZ = Config.Rec.HZ
local DT = 1 / HZ
local DELAYS = { 1, 2, 3, 4, 5 } -- ticks one way: 50..250 ms
local CAP_TICKS = math.floor(Config.Rec.LAG_REWIND_CAP * HZ + 0.5)

-- A clone that stands at (x, z) until `leaveAt`, then walks to (ax, az); 30 s long.
local function standRec(level: any, x: number, z: number, leaveAt: number?, ax: number?, az: number?): any
	local rec = Sampler.new(level.num, 0, HZ)
	local px, pz = x, z
	for k = 0, 600 do
		local t = k * DT
		if leaveAt and t > leaveAt then
			local dx, dz = (ax :: number) - px, (az :: number) - pz
			local d = math.sqrt(dx * dx + dz * dz)
			local s = math.min(d, 16 * DT)
			if d > 1e-6 then
				px, pz = px + dx / d * s, pz + dz / d * s
			end
		end
		Sampler.push(rec, px, level.rootY, pz, 0, 1)
	end
	Sampler.finish(rec, 1)
	return rec
end

-- One run on the corridor with seeded clones and a delayed bot.
local function play(level: any, clones: { any }, steps: { any }, delay: number, simLatency: number?)
	local sim = HeistSim.new(level, { players = { 1 } })
	HeistSim.seedDeck(sim, 1, clones)
	HeistSim.setLatency(sim, 1, (simLatency or delay) * DT)
	HeistSim.startRun(sim)
	local bot = Bot.new(level, 1, steps, { delay = delay, trace = true })
	local run = Harness.runOnce(sim, { bot }, Harness.history())
	return run, bot, sim
end

local function laserCase(level: any, clones: { any }, s: number, delay: number, simLatency: number?)
	local steps = {
		{ go = { 0, -21 } },
		{ waitUntil = s },
		{ go = { 0, -30 } },
		{ endRun = true },
	}
	local run, bot, sim = play(level, clones, steps, delay, simLatency)
	local live = #sim.actors
	local zapped = EventLog.count(run.log, EV.Zap, live) > 0
	local beam = level.lasers[1].box
	local y = level.rootY
	local seenOn = false
	for _, e in bot.trace do
		if
			e.view
			and Geom.touches(beam, e.x0, y, e.z0, e.x, y, e.z)
			and Mechanisms.laserViewOf(e.view.lasers[1], e.t) == "on"
		then
			seenOn = true
		end
	end
	return zapped, seenOn, run
end

return function(test)
	local level = TestLevels.corridor()
	local qx, _, qz = Geom.center(level.plates[2].box)
	local px, _, pz = Geom.center(level.plates[1].box)

	test("rules 1+2, lasers: never zapped unless the beam looked ON; favoured; capped", function()
		local holdP = standRec(level, px, pz)
		local leaveQ = standRec(level, qx, qz, 3.0, -10, 5)
		local clones = { holdP, leaveQ }
		-- The server's re-enable time, from a reference run.
		local ref = play(level, clones, { { stay = true } }, 0)
		local onTick = EventLog.firstTick(ref.log, EV.LaserOn, 1) :: number
		Assert.truthy(onTick ~= nil, "the grid comes back on")
		local tOn = onTick * DT
		for _, d in DELAYS do
			local favoured, zaps = 0, 0
			for i = -20, 12 do
				local s = tOn + i * 0.05 - 0.25 -- the bot reaches the beam ~0.22 s after leaving
				local zapped, seenOn = laserCase(level, clones, s, d)
				Assert.truthy(
					not zapped or seenOn,
					string.format("delay %d ms, start %.2f: zapped though it looked off", d * 50, s)
				)
				if seenOn and not zapped then
					favoured += 1
				end
				if zapped then
					zaps += 1
				end
				if i >= 8 then
					Assert.truthy(zapped, string.format("delay %d ms: a late crossing is zapped (cap)", d * 50))
				end
			end
			Assert.truthy(zaps > 0, "some crossings are zapped")
			if d <= CAP_TICKS then
				Assert.truthy(favoured > 0, string.format("delay %d ms: the player is favoured", d * 50))
			end
		end
		-- Without the rewind (server thinks latency is 0), 250 ms players get zapped
		-- for crossings that looked safe: rule 1 is what keeps it fair.
		local unfair = 0
		for i = -20, 12 do
			local zapped, seenOn = laserCase(level, clones, tOn + i * 0.05 - 0.25, 5, 0)
			if zapped and not seenOn then
				unfair += 1
			end
		end
		Assert.truthy(unfair > 0, "the rewind matters")
	end)

	test("rules 1+2, doors: a player who stops when the door looks shut is never tainted", function()
		local leaveP = standRec(level, px, pz, 3.0, 10, 5)
		local holdQ = standRec(level, qx, qz)
		local clones = { leaveP, holdQ }
		local ref = play(level, clones, { { stay = true } }, 0)
		local shutTick = EventLog.firstTick(ref.log, EV.DoorShut, 1) :: number
		local tShut = shutTick * DT
		local function case(s: number, d: number, simLatency: number?): (boolean, boolean)
			local steps = {
				{ go = { 0, -8 } },
				{ waitUntil = s },
				{ go = { 0, -19 }, timeout = 1.5 },
				{ endRun = true },
			}
			local run, bot = play(level, clones, steps, d, simLatency)
			return run.tainted, bot.z < -15.5
		end
		local unfair = 0
		for _, d in DELAYS do
			local through, stopped = 0, 0
			for i = -16, 6 do
				local s = tShut + i * 0.05 - 0.4 -- reaches the door ~0.4 s after leaving
				local tainted, crossed = case(s, d)
				Assert.falsy(tainted, string.format("delay %d ms, start %.2f: tainted", d * 50, s))
				if crossed then
					through += 1
				else
					stopped += 1
				end
			end
			Assert.truthy(through > 0 and stopped > 0, "both outcomes exercised at " .. d * 50 .. " ms")
		end
		-- Up to 250 ms the 0.2 s visual lead alone already covers doors (a body stops
		-- before the leaf); at 350 ms the rewind is what keeps them fair.
		for i = -16, 6 do
			local s = tShut + i * 0.05 - 0.4
			Assert.falsy((case(s, 7)), string.format("350 ms with the rewind, start %.2f: tainted", s))
			if case(s, 7, 0) then
				unfair += 1
			end
		end
		Assert.truthy(unfair > 0, "without the rewind a 350 ms player is tainted")
	end)

	test("rule 3: a plate counts a live player from the server's receipt of the position", function()
		for _, d in { 0, 1, 3, 5 } do
			local run, bot = play(level, {}, { { goPlate = "P" }, { stay = true } }, d)
			local box = level.plates[1].box
			local first
			for _, e in bot.trace do
				if first == nil and Geom.contains(box, e.x, level.rootY, e.z) then
					first = math.floor(e.t * HZ + 0.5)
				end
			end
			Assert.eq(EventLog.firstTick(run.log, EV.PlateDown, 1), first + d, "PlateDown at receipt, delay " .. d)
		end
	end)

	test("rule 5: Gus's detection of a live player is rewound by the latency, capped at 150 ms", function()
		local spec = TestLevels.watchSpec({
			route = { { x = 5, z = 30, wait = 0 }, { x = 5, z = -30, wait = 0 } },
		})
		local watch = LevelSpec.compile(spec)
		local function spottedAt(d: number): number
			local sim = HeistSim.new(watch, { players = { 1 } })
			HeistSim.setLatency(sim, 1, d * DT)
			HeistSim.startRun(sim)
			while sim.phase == "Run" and sim.nextTick < 200 do
				HeistSim.setInput(sim, 1, 5, 3, -20)
				HeistSim.step(sim)
			end
			return EventLog.firstTick(sim.log, EV.Spotted, 1) :: number
		end
		local base = spottedAt(0)
		Assert.eq(base, 50, "Gus walking toward the player sees him at 30 studs (t = 2.5 s)")
		for _, d in DELAYS do
			Assert.eq(spottedAt(d), base + math.min(d, CAP_TICKS), "rewind " .. d * 50 .. " ms")
		end
	end)
end
