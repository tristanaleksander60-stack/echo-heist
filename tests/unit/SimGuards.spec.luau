-- L1: Sim/Guards: patrol(t), the 3-stage cone, line of sight through occluders,
-- hide spots, the "huh?" freeze, chase steering and A* (MASTERPLAN §3.1, §3.2, §3.6).

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local Geom = require("../../src/shared/Sim/Geom")
local Guards = require("../../src/shared/Sim/Guards")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Mechanisms = require("../../src/shared/Sim/Mechanisms")
local Catalog = require("../../src/shared/Levels/Catalog")
local TestLevels = require("../sim/TestLevels")

local EV = EventLog.EV
local S = Config.Sim
local HZ = Config.Rec.HZ

-- Runs one solo run with the player held at a position given per tick.
local function standRun(level: any, posAt: (number) -> (number, number, number), opts: any?)
	local sim = HeistSim.new(level, { players = { 1 }, firstHeist = opts and opts.firstHeist })
	HeistSim.startRun(sim)
	while sim.phase == "Run" and sim.nextTick < 700 do
		local x, y, z = posAt(sim.nextTick)
		HeistSim.setInput(sim, 1, x, y, z)
		HeistSim.step(sim)
	end
	return sim
end

local function vision(range: number?): any
	return {
		range = range or S.GUARD_VISION_RANGE,
		cosHalf = math.cos(math.rad(S.GUARD_VISION_HALF_ANGLE)),
		allRound = false,
	}
end

return function(test)
	test("patrol(t) is periodic and a pure function of time", function()
		local level = LevelSpec.compile(Catalog[4])
		local route = level.guards[1].route
		Assert.near(route.period, 2 * (19 / 8) + 2.5 + 1.5, 1e-9, "period")
		for k = 0, 400 do
			local t = k * 0.0371
			local x1, z1, y1 = Guards.patrol(route, t)
			local x2, z2, y2 = Guards.patrol(route, t + route.period)
			local x3, z3, y3 = Guards.patrol(route, t + 7 * route.period)
			Assert.near(x1, x2, 1e-6, "x periodic")
			Assert.near(z1, z2, 1e-6, "z periodic")
			Assert.near(Geom.angleDelta(y1, y2), 0, 1e-6, "yaw periodic")
			Assert.near(x1, x3, 1e-6, "x periodic x7")
			Assert.near(z1, z3, 1e-6, "z")
			Assert.near(Geom.angleDelta(y1, y3), 0, 1e-6, "yaw")
		end
	end)

	test("patrol(t) walks legs at speed, dwells facing, and turns at the end of a dwell", function()
		local route = LevelSpec.compileRoute({
			{ x = 0, z = 0, wait = 1, face = 270 },
			{ x = 16, z = 0, wait = 2, face = 0 },
		}, 8)
		local x, z, yaw = Guards.patrol(route, 1)
		Assert.near(x, 8, 1e-9, "halfway at t = 1")
		Assert.near(z, 0, 1e-9, "z")
		Assert.near(yaw, 3 * math.pi / 2, 1e-9, "facing east while walking east")
		x, _, yaw = Guards.patrol(route, 2.5)
		Assert.near(x, 16, 1e-9, "dwelling at the far end")
		Assert.near(yaw, 0, 1e-9, "dwell face 0 (-Z)")
		-- Last GUARD_TURN_SECONDS of the dwell: turning toward the next leg (west).
		local _, _, mid = Guards.patrol(route, 2 + 2 - S.GUARD_TURN_SECONDS / 2)
		Assert.near(math.abs(Geom.angleDelta(0, mid)), math.pi / 4, 1e-6, "half turned")
		local _, _, done = Guards.patrol(route, 4 - 1e-9)
		Assert.near(math.abs(Geom.angleDelta(done, math.pi / 2)), 0, 1e-6, "facing west at the end")
	end)

	test("3-stage cone: amber at once, '?' at 0.6 s, '!' at 1.2 s; the run ends", function()
		local level = TestLevels.watch()
		local sim = standRun(level, function()
			return 0, 3, -8
		end)
		local log = sim.lastRun and sim.log
		Assert.eq(EventLog.firstTick(log, EV.Spotted, 1), 0, "amber on the first tick")
		Assert.eq(EventLog.firstTick(log, EV.Suspect, 1), math.ceil(S.GUARD_ALERT_SECONDS * HZ) - 1, "'?' at 0.6 s")
		Assert.eq(EventLog.firstTick(log, EV.Caught, 1), math.ceil(S.GUARD_CATCH_SECONDS * HZ) - 1, "'!' at 1.2 s")
		Assert.eq(sim.lastRun.catches, 1, "caught")
		local live = sim.players[1].deck.slots[1]
		Assert.eq(live.status, "Caught", "the new clone is flagged")
		local ev = live.rec.events[#live.rec.events]
		Assert.eq(ev.kind, 11, "recording ends with a Caught event")
	end)

	test("first heist of a new account doubles the stage times", function()
		local sim = standRun(TestLevels.watch(), function()
			return 0, 3, -8
		end, { firstHeist = true })
		Assert.eq(EventLog.firstTick(sim.log, EV.Caught, 1), math.ceil(2 * S.GUARD_CATCH_SECONDS * HZ) - 1, "x2")
	end)

	test("breaking line of sight behind a pillar drains the meter (no catch)", function()
		-- In view beside the pillar (x -1..1, z -16..-14), then step round behind it.
		local path = { [6] = { 1.5, -15.7 }, [7] = { 1.5, -16.4 }, [8] = { 1.5, -17 }, [9] = { 0.75, -17 } }
		local sim = standRun(TestLevels.watch(), function(k)
			if k < 6 then
				return 1.5, 3, -15
			end
			local p = path[k] or { 0, -17 }
			return p[1], 3, p[2]
		end)
		Assert.eq(sim.lastRun.catches, 0, "not caught")
		Assert.truthy(EventLog.firstTick(sim.log, EV.Lost, 1, 1) ~= nil, "lost")
		Assert.eq(EventLog.count(sim.log, EV.Suspect), 0, "never reached '?'")
	end)

	test("line of sight: walls block, low counters do not, shut doors block", function()
		local watch = TestLevels.watch()
		local eye = 3 + S.GUARD_EYE_HEIGHT
		Assert.falsy(Guards.lineOfSight(watch, nil, 0, 0, eye, 0, 0, 4, -20), "pillar")
		Assert.truthy(Guards.lineOfSight(watch, nil, 0, 0, eye, 0, -8, 4, -14), "low counter is see-through")
		Assert.truthy(Guards.lineOfSight(watch, nil, 0, 0, eye, 0, 4, 4, -20), "beside the pillar")
		local corridor = TestLevels.corridor()
		local mech = Mechanisms.new(corridor)
		Assert.falsy(Guards.lineOfSight(corridor, mech, 0, 0, eye, -10, 0, 4, -20), "shut door")
		local log = EventLog.new()
		Mechanisms.update(mech, 0, 0, { { id = 1, present = true, x = 10, y = 3, z = -5 } }, log)
		Assert.truthy(Guards.lineOfSight(corridor, mech, 0, 0, eye, -10, 0, 4, -20), "open door")
	end)

	test("cone half-angle and range", function()
		local watch = TestLevels.watch()
		local v = vision()
		Assert.falsy(Guards.canSee(watch, nil, 0, v, 0, 0, 0, 0, 3, 10), "behind is not in a cone facing -Z")
		Assert.truthy(Guards.canSee(watch, nil, 0, v, 0, 0, 0, 0, 3, -8), "in front")
		Assert.truthy(Guards.canSee(watch, nil, 0, v, 0, 0, 0, 6, 3, -6.5), "44 deg off axis is in")
		Assert.falsy(Guards.canSee(watch, nil, 0, v, 0, 0, 0, 6, 3, -5.5), "47 deg is out")
		Assert.falsy(Guards.canSee(watch, nil, 0, vision(10), 0, 0, 0, 20, 3, -20), "out of range")
	end)

	test("hide spots: invisible unless Gus is within HIDE_REVEAL_RADIUS", function()
		local watch = TestLevels.watch()
		local v = vision()
		Assert.truthy(Guards.canSee(watch, nil, 0, v, 0, 0, 0, 8, 3, -10, false), "seen when not hidden")
		Assert.falsy(Guards.canSee(watch, nil, 0, v, 0, 0, 0, 8, 3, -10, true), "hidden")
		Assert.truthy(Guards.canSee(watch, nil, 0, v, 8, -7.5, 0, 8, 3, -10, true), "revealed within 3 studs")
		-- In the sim: standing in the Plant box the whole run is safe.
		local sim = standRun(watch, function()
			return 8, 3, -10
		end)
		Assert.eq(sim.lastRun.catches, 0, "never caught while hidden")
		Assert.eq(EventLog.count(sim.log, EV.Spotted), 0, "never even amber")
		local rec = sim.players[1].deck.slots[1].rec
		Assert.truthy(bit32.band(rec.flags[10], 16) ~= 0, "HIDDEN flag recorded")
	end)

	test("'huh?' freeze: a busted clone stops Gus for 2 s and pauses his vision", function()
		local level = TestLevels.watch()
		local sim = HeistSim.new(level, { players = { 1 } })
		-- Run 1: walk into view and get caught.
		HeistSim.startRun(sim)
		while sim.phase == "Run" do
			HeistSim.setInput(sim, 1, 0, 3, -8)
			HeistSim.step(sim)
		end
		-- Run 2: the clone repeats the mistake; the live player waits in view at (3, -8).
		HeistSim.startRun(sim)
		local bustedAt, huhAt, resumeAt
		while sim.phase == "Run" and sim.nextTick < 200 do
			HeistSim.setInput(sim, 1, 3, 3, -8)
			HeistSim.step(sim)
			bustedAt = bustedAt or EventLog.firstTick(sim.log, EV.Busted, 1, 1)
			huhAt = huhAt or EventLog.firstTick(sim.log, EV.GuardHuh, 1)
			resumeAt = resumeAt or EventLog.firstTick(sim.log, EV.GuardResume, 1)
		end
		Assert.eq(bustedAt, 23, "clone busted on the same tick as the original catch")
		Assert.eq(huhAt, bustedAt, "huh at once")
		Assert.eq(resumeAt, bustedAt + S.GUARD_HUH_SECONDS * HZ, "resumes 2 s later")
		-- The live player was in view the whole time but is caught only after the freeze.
		local caught = EventLog.firstTick(sim.log, EV.Caught, 1, 2) :: number
		Assert.truthy(caught > (resumeAt :: number), "vision paused during the freeze")
	end)

	test("a stopped guard resumes his route from where he stopped (patrol(t - offset))", function()
		local level = TestLevels.watch({
			route = { { x = -10, z = 0, wait = 0.5, face = 0 }, { x = 10, z = 0, wait = 0.5, face = 0 } },
		})
		local g = Guards.new(level.guards[1], level.rootY)
		g.offset = 2
		local log = EventLog.new()
		local ctx = {
			level = level,
			mech = Mechanisms.new(level),
			actors = {},
			log = log,
			tick = 100,
			t = 5,
			dt = 1 / HZ,
			hz = HZ,
			alertT = 0.6,
			catchT = 1.2,
			vision = vision(),
			chase = false,
			chaseSpeed = 14.4,
			onCatch = function() end,
		}
		Guards.update(g, ctx)
		local x, z = Guards.patrol(level.guards[1].route, 3)
		Assert.near(g.x, x, 1e-9, "x = patrol(5 - 2)")
		Assert.near(g.z, z, 1e-9, "z")
	end)

	test("chase steering goes around the vault wall on the nav graph, deterministically", function()
		local level = TestLevels.alarm()
		local mech = Mechanisms.new(level)
		Mechanisms.update(mech, 0, 0, {}, EventLog.new()) -- shutter open
		local function chase(): (number, { number })
			local x, z = 0, -25
			local trail = {}
			for k = 1, 400 do
				x, z = Guards.steer(level, mech, 0, x, z, 0, -50, 14.4 / HZ)
				table.insert(trail, Geom.q(x) * 65536 + Geom.q(z))
				if Geom.dist2(x, z, 0, -50) < 0.01 then
					return k, trail
				end
			end
			return -1, trail
		end
		local k1, t1 = chase()
		local k2, t2 = chase()
		Assert.truthy(k1 > 0, "reached the diamond")
		Assert.eq(k1, k2, "same length")
		for i = 1, #t1 do
			Assert.eq(t1[i], t2[i], "same path " .. i)
		end
		-- Straight-line distance is 25 studs; going round the wall is longer.
		Assert.truthy(k1 * 14.4 / HZ > 30, "went around")
		-- Straight when clear.
		local x, z = Guards.steer(level, mech, 0, 0, 0, 0, -10, 1)
		Assert.near(x, 0, 1e-9, "x")
		Assert.near(z, -1, 1e-9, "one stud straight")
	end)

	test("A* skips edges through shut doors", function()
		local level = TestLevels.alarm()
		local mech = Mechanisms.new(level) -- everything shut before the first update
		Assert.eq(Guards.astar(level, mech, 0, 2, 3), nil, "shutter shut: no path into the vault")
		Mechanisms.update(mech, 0, 0, {}, EventLog.new())
		local path = Guards.astar(level, mech, 0, 2, 8)
		Assert.truthy(path ~= nil and path[1] == 2 and path[#path] == 8, "path into the vault")
	end)
end
