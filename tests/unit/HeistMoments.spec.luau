-- L1: Shared/Heist/MomentPlan, the pure maths of the signature moments (PLAN_STEAM_PLUS §4.4 F1-F5,
-- §4.2 C3, §5): the 8 OF ME roll call timing, the framing that keeps every copy inside the central
-- 32 % of the width (checked against Heist/CameraMath's own projection), the rewind's path trail
-- sampling and reel, the blooper pick and window, the juice governor and the busted podium.

local MomentPlan = require("../../src/shared/Heist/MomentPlan")
local CameraMath = require("../../src/client/Heist/CameraMath")
local Config = require("../../src/shared/Config")
local Assert = require("./Assert")

local M = Config.Moments
local SW = M.SWARM
local SHARE = Config.Heist.CAMERA.LINEUP.CENTRAL_SHARE

-- Seven clones fanned out round the Clone Party's floor plus you (level space, root height).
local function crowd(spread: number): { { number } }
	local out = {}
	for i = 0, 7 do
		local a = i / 8 * 2 * math.pi
		table.insert(out, { math.cos(a) * spread + 3, 3, math.sin(a) * spread * 0.6 - 10 })
	end
	return out
end

-- Head and feet of each copy (what the moment fits).
local function figurePoints(roots: { { number } }): { { number } }
	local out = {}
	for _, p in roots do
		table.insert(out, { p[1], p[2] + SW.FIGURE_UP, p[3] })
		table.insert(out, { p[1], p[2] - SW.FIGURE_DOWN, p[3] })
	end
	return out
end

return function(test)
	test("roll call: 8 beats 60 ms apart in record order, the choir hit after the last", function()
		local times = MomentPlan.rollCall(8, SW.ROLL_STAGGER, SW.ROLL_START)
		Assert.eq(#times, 8, "one beat per copy")
		Assert.near(times[1], SW.ROLL_START, 1e-9, "first beat")
		for i = 2, 8 do
			Assert.near(times[i] - times[i - 1], 0.06, 1e-9, "60 ms stagger " .. i)
		end
		local choir = MomentPlan.choirAt(8, SW.ROLL_STAGGER, SW.ROLL_START, SW.CHOIR_GAP)
		Assert.near(choir, times[8] + SW.CHOIR_GAP, 1e-9, "choir hit lands after the last note")
		Assert.eq(#MomentPlan.rollCall(0, 0.06, 0), 0, "no copies, no beats")
		Assert.near(MomentPlan.choirAt(0, 0.06, 0.2, 0.06), 0.2, 1e-9, "no copies: choir at the start")
		-- The arpeggio has a note for every beat of 8 OF ME.
		Assert.truthy(#Config.Audio.ARPEGGIO_STEPS >= 8, "8 arpeggio steps")
	end)

	test("framing: every copy inside the central 32 % of the width, 16:9 and 9:16", function()
		for _, aspect in { 16 / 9, 9 / 16, 4 / 3 } do
			for _, spread in { 4, 10, 18 } do
				for _, yaw in { 0, 35, -120 } do
					local pts = figurePoints(crowd(spread))
					local focus, dist, fits = MomentPlan.frame(
						pts,
						yaw,
						SW.CAM_PITCH,
						SW.CAM_FOV,
						aspect,
						SHARE,
						SW.CAM_SHARE_Y,
						SW.CAM_DISTANCE[1],
						2000 -- a 9:16 screen (rare: the clips crop 16:9) needs a long way back
					)
					Assert.truthy(fits, "fits " .. aspect .. " " .. spread)
					local pos = CameraMath.orbit(focus, yaw, SW.CAM_PITCH, dist)
					local worst = 0
					for _, p in pts do
						local nx, ny, depth = CameraMath.project(pos, yaw, SW.CAM_PITCH, p, SW.CAM_FOV, aspect)
						Assert.truthy(depth > 0.1, "in front")
						Assert.le(math.abs(nx), SHARE + 1e-6, "inside the central 32 %")
						Assert.le(math.abs(ny), SW.CAM_SHARE_Y + 1e-6, "inside the height share")
						worst = math.max(worst, math.abs(nx), math.abs(ny) / SW.CAM_SHARE_Y * SHARE)
						-- the frame's own projection agrees with CameraMath's
						local mx, my = MomentPlan.project(focus, dist, yaw, SW.CAM_PITCH, SW.CAM_FOV, aspect, p)
						Assert.near(mx, nx, 1e-6, "project x")
						Assert.near(my, ny, 1e-6, "project y")
					end
					-- tight: some point touches a limit unless the minimum distance held
					if dist > SW.CAM_DISTANCE[1] + 1e-6 then
						Assert.near(worst, SHARE, 1e-4, "the fit is tight")
					end
				end
			end
		end
	end)

	test("framing: too wide for the max distance says so; one point fits at the minimum", function()
		local _, dist, fits = MomentPlan.frame(figurePoints(crowd(80)), 0, 45, 45, 9 / 16, SHARE, 0.8, 12, 30)
		Assert.falsy(fits, "does not fit")
		Assert.eq(dist, 30, "clamped to max")
		local focus, d1, ok1 = MomentPlan.frame({ { 1, 2, 3 } }, 0, 45, 45, 16 / 9, SHARE, 0.8, 12, 90)
		Assert.truthy(ok1, "one point fits")
		Assert.eq(d1, 12, "minimum distance")
		Assert.near(focus[1], 1, 1e-9, "focus x")
		Assert.near(focus[2], 2, 1e-9, "focus y")
		Assert.near(focus[3], 3, 1e-9, "focus z")
	end)

	test("trail: sampled evenly over the run, the reel draws the path up to the head", function()
		local times = MomentPlan.trailTimes(12, 13)
		Assert.eq(#times, 13, "13 samples")
		Assert.near(times[1], 0, 1e-9, "starts at 0")
		Assert.near(times[13], 12, 1e-9, "ends at the run's end")
		Assert.eq(#MomentPlan.trailTimes(0, 13), 1, "an empty run is one point")
		-- A straight walk along +X at 4 studs/s; nil before t = 1 (the recording starts late).
		local pts = MomentPlan.sampleTrail(function(t: number): (number?, number, number)
			if t < 1 then
				return nil, 0, 0
			end
			return t * 4, 3, -2
		end, 12, M.REWIND.TRAIL_POINTS)
		Assert.eq(#pts, 12, "the sample before the recording is skipped")
		Assert.near(pts[1].x, 4, 1e-9, "x at t = 1")
		Assert.near(pts[#pts].x, 48, 1e-9, "x at the end")
		-- The reel: head at the end draws all of it; halfway draws half; before the first point none.
		local k, frac = MomentPlan.trailHead(pts, 12)
		Assert.eq(k, #pts, "all drawn at the start of the reel")
		Assert.eq(frac, 0, "no partial segment")
		k, frac = MomentPlan.trailHead(pts, 6.5)
		Assert.eq(k, 6, "six whole points by t = 6.5 (t = 1..6)")
		Assert.near(frac, 0.5, 1e-9, "half of the next segment")
		k = MomentPlan.trailHead(pts, 0.5)
		Assert.eq(k, 0, "nothing left once the head is back before the path")
		-- Low tier draws a coarser path (the substitute).
		Assert.truthy(M.REWIND.TRAIL_POINTS_LOW < M.REWIND.TRAIL_POINTS, "low tier: fewer points")
	end)

	test("blooper: own clones first, then busted > zapped > stuck, then the latest", function()
		local W = M.BLOOPER.WEIGHTS
		local fails = {
			{ id = 1, owner = 2, kind = "Busted", t = 20 },
			{ id = 2, owner = 1, kind = "Stuck", t = 30 },
			{ id = 3, owner = 1, kind = "Zapped", t = 10 },
			{ id = 4, owner = 1, kind = "Zapped", t = 12 },
		}
		local pick = MomentPlan.pickBlooper(fails, 1, W)
		Assert.eq(pick and pick.id, 4, "own, zapped beats stuck, latest zap")
		table.insert(fails, { id = 5, owner = 1, kind = "Busted", t = 5 })
		pick = MomentPlan.pickBlooper(fails, 1, W)
		Assert.eq(pick and pick.id, 5, "own busted wins")
		pick = MomentPlan.pickBlooper(fails, 99, W)
		Assert.eq(pick and pick.id, 1, "a spectator: busted wins")
		Assert.eq(MomentPlan.pickBlooper({}, 1, W), nil, "no failure, no blooper")
		Assert.eq(MomentPlan.pickBlooper({ { id = 9, owner = 1, kind = "Bonk", t = 3 } }, 1, W), nil, "unknown kind")
	end)

	test("blooper window: the last 3 s, never more than 4 s, never before 0", function()
		local B = M.BLOOPER
		local from, to = MomentPlan.blooperWindow(20, B.LEAD, B.TAIL, B.MAX)
		Assert.near(from, 17, 1e-9, "3 s before")
		Assert.le(to - from, B.MAX + 1e-9, "<= 4 s")
		Assert.truthy(to >= 20, "the failure is in the window")
		from, to = MomentPlan.blooperWindow(1, B.LEAD, B.TAIL, B.MAX)
		Assert.eq(from, 0, "starts at 0")
		Assert.near(to, 1 + B.TAIL, 1e-9, "tail kept")
		from, to = MomentPlan.blooperWindow(10, 3, 3, 4)
		Assert.near(to - from, 4, 1e-9, "the tail gives way to the cap")
		Assert.near(from, 7, 1e-9, "the lead stays")
	end)

	test("governor: <= 3 flashes a second, particles under the cap, rain <= 60", function()
		local log = {}
		local allowed = 0
		for i = 0, 19 do
			if MomentPlan.flashAllowed(log, i * 0.05, M.FLASH_MAX, M.FLASH_WINDOW) then
				allowed += 1
			end
		end
		Assert.eq(allowed, M.FLASH_MAX, "3 in the first second")
		Assert.truthy(MomentPlan.flashAllowed(log, 1.01, M.FLASH_MAX, M.FLASH_WINDOW), "the window moves on")
		local ledger = {}
		local a = MomentPlan.grantParticles(ledger, 0, 300, M.PARTICLE_CAP_TOUCH, 2)
		local b = MomentPlan.grantParticles(ledger, 0.5, 100, M.PARTICLE_CAP_TOUCH, 2)
		Assert.eq(a, 300, "first burst whole")
		Assert.eq(b, 60, "second burst trimmed to the cap")
		Assert.eq(MomentPlan.grantParticles(ledger, 3, 100, M.PARTICLE_CAP_TOUCH, 2), 100, "freed after they die")
		local C = M.COMPLETE
		Assert.le(C.RAIN, 60, "gold rain <= 60")
		Assert.eq(MomentPlan.rainCount(C.RAIN, C.RAIN_LOW, 1, M.LOW_TIER, 1), C.RAIN, "full tier")
		Assert.eq(MomentPlan.rainCount(C.RAIN, C.RAIN_LOW, M.LOW_TIER, M.LOW_TIER, 0.5), 12, "low tier, half scale")
		local parts = MomentPlan.split(C.RAIN, C.RAIN_BURSTS)
		local sum = 0
		for _, n in parts do
			sum += n
		end
		Assert.eq(sum, C.RAIN, "bursts add up")
		Assert.eq(#MomentPlan.split(7, 3), 3, "3 bursts")
		-- hit-stop only on the four heavy beats, each >= 66 ms (premium F3)
		local beats = 0
		for _ in M.HIT_STOP_BEATS do
			beats += 1
		end
		Assert.eq(beats, 4, "four heavy beats")
		Assert.truthy(M.HIT_STOP_SECONDS >= 0.066 - 1e-9, ">= 66 ms")
	end)

	test("podium: busted clones apart, crew row centred together, record order kept", function()
		local L = M.LINEUP
		local spacing = Config.Sim.LINEUP_SPACING
		local busted = { false, true, false, false, true, false, false, false }
		local slots = MomentPlan.podium(busted, Config.Sim.LINEUP_ROW, spacing, L.PODIUM_GAP)
		local maxCrew, minPodium = -math.huge, math.huge
		local lo, hi = math.huge, -math.huge
		local lastCrew, lastPodium = -math.huge, -math.huge
		for i, s in slots do
			Assert.eq(s.podium, busted[i], "podium flag " .. i)
			lo = math.min(lo, s.across)
			hi = math.max(hi, s.across)
			if s.podium then
				minPodium = math.min(minPodium, s.across)
				Assert.truthy(s.across > lastPodium, "podium keeps record order")
				lastPodium = s.across
			else
				maxCrew = math.max(maxCrew, s.across)
				Assert.truthy(s.across > lastCrew, "crew keeps record order")
				lastCrew = s.across
			end
		end
		Assert.near(minPodium - maxCrew, L.PODIUM_GAP, 1e-9, "the gap between crew and podium")
		Assert.near(lo + hi, 0, 1e-9, "the group is centred")
		for i = 1, #slots do
			for j = i + 1, #slots do
				local d = math.abs(slots[i].across - slots[j].across) + math.abs(slots[i].back - slots[j].back)
				Assert.truthy(d >= spacing - 1e-9, "no two figures overlap")
			end
		end
		-- Nobody busted: the plain centred row.
		local plain = MomentPlan.podium({ false, false, false }, 8, spacing, L.PODIUM_GAP)
		Assert.near(plain[1].across, -spacing, 1e-9, "left")
		Assert.near(plain[3].across, spacing, 1e-9, "right")
		-- Everybody busted: one centred podium row.
		local all = MomentPlan.podium({ true, true }, 8, spacing, L.PODIUM_GAP)
		Assert.near(all[1].across + all[2].across, 0, 1e-9, "centred podium")
		-- 10 kept: two crew rows
		local many = {}
		for i = 1, 10 do
			many[i] = false
		end
		local rows = MomentPlan.podium(many, 8, spacing, L.PODIUM_GAP)
		Assert.eq(rows[9].back, spacing, "second row behind")
	end)

	test("blend: eases in, holds, eases out, then done (>= 0.2 s eases, premium H1)", function()
		local S = M.SWARM
		Assert.truthy(S.CAM_IN >= 0.2 and S.CAM_OUT >= 0.2, "swarm eases")
		Assert.truthy(M.BUSTED.CAM_IN >= 0.2 and M.BUSTED.CAM_OUT >= 0.2, "busted eases")
		Assert.near(M.BUSTED.CAM_IN, 0.6, 1e-9, "the busted ease is 0.6 s (C3)")
		local w, done = MomentPlan.blend(0, 0.6, 1, 0.5)
		Assert.eq(w, 0, "starts at 0")
		Assert.falsy(done, "not done")
		w = MomentPlan.blend(0.3, 0.6, 1, 0.5)
		Assert.near(w, 0.5, 1e-9, "half way in")
		w = MomentPlan.blend(1, 0.6, 1, 0.5)
		Assert.eq(w, 1, "holding")
		w, done = MomentPlan.blend(2.2, 0.6, 1, 0.5)
		Assert.eq(w, 0, "out")
		Assert.truthy(done, "done")
	end)
end
