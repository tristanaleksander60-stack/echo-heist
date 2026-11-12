-- L1: Shared/Heist/GusBeats, Gus's acting beats and intention cues (PLAN_STEAM_PLUS §4.4 A4-A5,
-- premium C1/C3/C4, POLISH §4.3, docs/audit/LEVELS.md G10).

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local Guards = require("../../src/shared/Sim/Guards")
local GusBeats = require("../../src/shared/Heist/GusBeats")
local Strings = require("../../src/shared/Heist/Strings")
local TestLevels = require("../sim/TestLevels")

local G = Config.Gus
local B = GusBeats.BEAT

local function input(mode: string, opts: any?): GusBeats.Input
	local o = opts or {}
	return { mode = mode, alarmOn = o.alarmOn == true, dozer = o.dozer == true, bang = o.bang }
end

local function walk(phase: number?, amount: number?, run: number?, clock: number?): GusBeats.Walk
	return { phase = phase or 0, amount = amount or 0, run = run or 0, clock = clock or 0 }
end

local function j(p: GusBeats.Pose, name: string, k: number): number
	return p.joints[name][k]
end

-- L4's two-point patrol (walks 19 studs between two dwells).
local function l4Route(): any
	return TestLevels.watch({
		route = {
			{ x = 13, z = -28, wait = 2.5, face = 270 },
			{ x = -6, z = -28, wait = 1.5, face = 90 },
		},
	}).guards[1].route
end

local function squareRoute(): any
	return TestLevels.watch({
		route = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 10 }, { x = 0, z = 10 } },
	}).guards[1].route
end

return function(test)
	test("rig: 18 parts, parent first, unique joints, the hat on the cap's joint", function()
		Assert.eq(#GusBeats.PARTS, 18, "18-part mesh (STYLE_BIBLE §12)")
		local seen, joints = {}, {}
		for i, p in GusBeats.PARTS do
			if i == 1 then
				Assert.eq(p.parent, nil, "the root has no parent")
				Assert.eq(p.joint, "Root", "root joint")
			else
				Assert.truthy(p.parent ~= nil and seen[p.parent :: string], p.name .. "'s parent comes first")
			end
			Assert.falsy(joints[p.joint], "joint " .. p.joint .. " used once")
			seen[p.name], joints[p.joint] = true, true
			for k = 1, 3 do
				Assert.truthy(p.max[k] > p.min[k], p.name .. " bounds")
			end
		end
		Assert.eq(GusBeats.HAT.joint, "HatAttach", "Santa hat shares the cap joint")
		Assert.eq(#GusBeats.JOINTS, 18, "joint list")
	end)

	test("select: patrol, doze, wake on the alarm, then the chase", function()
		local st = GusBeats.newState(0)
		Assert.eq(GusBeats.select(st, input("Patrol"), 0), B.Patrol, "walking guard patrols")
		local d = GusBeats.newState(0)
		Assert.eq(GusBeats.select(d, input("Patrol", { dozer = true }), 0), B.Doze, "posted guard dozes")
		Assert.eq(GusBeats.select(d, input("Patrol", { dozer = true }), 5), B.Doze, "still dozing")
		Assert.eq(
			GusBeats.select(d, input("Patrol", { dozer = true, alarmOn = true }), 6),
			B.Wake,
			"the alarm wakes him (even before the chase mode arrives)"
		)
		Assert.eq(
			GusBeats.select(d, input("Chase", { dozer = true, alarmOn = true }), 6.1),
			B.Wake,
			"startle plays out"
		)
		Assert.eq(
			GusBeats.select(d, input("Chase", { dozer = true, alarmOn = true }), 6 + G.WAKE_SECONDS + 0.01),
			B.Chase,
			"then he chases"
		)
		local c = GusBeats.newState(0)
		Assert.eq(GusBeats.select(c, input("Chase"), 1), B.Chase, "an awake guard chases at once")
	end)

	test("select: double-take, lost sight scratch, wrong one, catch overrides", function()
		local st = GusBeats.newState(0)
		GusBeats.select(st, input("Patrol"), 0)
		Assert.eq(GusBeats.select(st, input("Suspicious"), 1), B.DoubleTake, "? = double-take")
		Assert.eq(GusBeats.select(st, input("Patrol"), 2), B.Scratch, "lost sight: head scratch")
		Assert.eq(GusBeats.select(st, input("Patrol"), 2 + G.SCRATCH_SECONDS * 0.5), B.Scratch, "scratch plays out")
		Assert.eq(GusBeats.select(st, input("Patrol"), 2 + G.SCRATCH_SECONDS + 0.01), B.Patrol, "back on the round")
		Assert.eq(GusBeats.select(st, input("Huh"), 4), B.WrongOne, "busted a clone: WRONG ONE")
		Assert.eq(GusBeats.select(st, input("Patrol"), 6), B.Patrol, "huh over")
		Assert.eq(GusBeats.select(st, input("Suspicious", { bang = "catch" }), 7), B.Catch, "a catch")
		Assert.eq(GusBeats.select(st, input("Patrol"), 7.2), B.Catch, "the lunge holds")
		Assert.eq(GusBeats.select(st, input("Patrol"), 7 + G.CATCH_SECONDS + 0.01), B.Patrol, "then patrol")
		Assert.eq(GusBeats.select(st, input("Chase", { bang = "catch" }), 9), B.Catch, "catch during a chase")
		Assert.eq(GusBeats.select(st, input("Chase"), 9 + G.CATCH_SECONDS + 0.01), B.Chase, "chase resumes")
	end)

	test("isDozer: one-spot posts in levels with an alarm only", function()
		local post = TestLevels.watch()
		Assert.truthy(GusBeats.isPost(post.guards[1].route), "watch level: one spot")
		Assert.falsy(GusBeats.isDozer(post, post.guards[1]), "no alarm: he watches, never dozes")
		local alarm = TestLevels.alarm()
		Assert.truthy(GusBeats.isDozer(alarm, alarm.guards[1]), "alarm level post: dozes")
		Assert.falsy(GusBeats.isPost(l4Route()), "a walking route is no post")
	end)

	test("C1: every launch beat starts with >= 66 ms of anticipation", function()
		for _, beat in GusBeats.LAUNCH do
			Assert.truthy(GusBeats.anticipation(beat) >= 0.066, beat .. " anticipation")
		end
		for _, beat in GusBeats.EXTRA do
			Assert.truthy(GusBeats.anticipation(beat) >= 0.066, beat .. " anticipation")
		end
		local A = G.ANTICIPATION
		local p = GusBeats.newPose()
		-- Wake: down first, then up.
		GusBeats.pose(B.Wake, A, walk(), p)
		Assert.truthy(j(p, "Root", 2) < -0.1, "wake crouches first")
		GusBeats.pose(B.Wake, A + 0.15, walk(), p)
		Assert.truthy(j(p, "Root", 2) > 0.4, "then jumps")
		Assert.truthy(j(p, "HatAttach", 2) > 0.3, "the cap pops")
		-- Catch: back first, then the lunge forward.
		GusBeats.pose(B.Catch, A, walk(), p)
		Assert.truthy(j(p, "Root", 3) > 0.2, "catch pulls back first")
		GusBeats.pose(B.Catch, A + 0.25, walk(), p)
		Assert.truthy(j(p, "Root", 3) < -0.5, "then lunges")
		Assert.truthy(j(p, "RightShoulder", 4) > math.rad(60), "arms out to grab")
		-- Chase: lean back first, then point forward.
		GusBeats.pose(B.Chase, A, walk(0, 1, 1), p)
		Assert.truthy(j(p, "Root", 4) > 0, "chase winds back first")
		GusBeats.pose(B.Chase, A + 0.2, walk(0, 1, 1), p)
		Assert.truthy(j(p, "Root", 4) < 0, "then leans in")
		Assert.truthy(j(p, "LeftShoulder", 4) > math.rad(70), "and points")
		-- Double-take: looks away first.
		GusBeats.pose(B.DoubleTake, A, walk(), p)
		Assert.truthy(p.look < 0, "double-take: a tiny look away first")
	end)

	test("C4: the double-take turns the head first and the body later", function()
		local p = GusBeats.newPose()
		local A = G.ANTICIPATION
		GusBeats.pose(B.DoubleTake, A + 0.05, walk(), p)
		Assert.truthy(p.look > 0.2 and p.follow == 0, "the glance: head only")
		GusBeats.pose(B.DoubleTake, A + 0.25, walk(), p)
		Assert.truthy(p.look < 0.5, "looks away again ('nah')")
		GusBeats.pose(B.DoubleTake, A + 0.47, walk(), p)
		Assert.truthy(p.look >= 1, "snaps back with an overshoot")
		Assert.eq(p.follow, 0, "body still holds")
		GusBeats.pose(B.DoubleTake, G.DOUBLE_TAKE_FOLLOW + 0.3, walk(), p)
		Assert.eq(p.follow, 1, "then the body follows")
		Assert.truthy(G.DOUBLE_TAKE_FOLLOW - (A + 0.48) >= 0.15, "body follows >= 0.15 s after the head")
		Assert.truthy(G.HEAD_LEAD >= 0.15 and G.HEAD_LEAD <= 0.25, "patrol head lead 0.15-0.25 s")
	end)

	test("walk: arms counter-swing, feet stay flat, the sprint is bigger, poses are finite", function()
		local p = GusBeats.newPose()
		GusBeats.pose(B.Patrol, 0, walk(0.25, 1, 0, 0), p)
		Assert.truthy(j(p, "LeftHip", 4) < 0 and j(p, "LeftShoulder", 4) > 0, "left arm against the left leg")
		Assert.truthy(j(p, "RightHip", 4) > 0, "right leg forward at a quarter cycle")
		for _, side in { "Right", "Left" } do
			local sum = j(p, "Root", 4) + j(p, side .. "Hip", 4) + j(p, side .. "Knee", 4) + j(p, side .. "Ankle", 4)
			Assert.near(sum, 0, 1e-9, side .. " foot flat")
		end
		local walkHip = j(p, "RightHip", 4)
		GusBeats.pose(B.Chase, 2, walk(0.25, 1, 1, 0), p)
		Assert.truthy(j(p, "RightHip", 4) - (-j(p, "Root", 4)) > walkHip, "sprint strides further")
		Assert.truthy(j(p, "Root", 4) < -math.rad(10), "sprint leans in")
		for _, beat in { B.Doze, B.Wake, B.Patrol, B.DoubleTake, B.Chase, B.Catch, B.WrongOne, B.Scratch } do
			for t = 0, 3, 0.05 do
				GusBeats.pose(beat, t, walk(t * 1.3, 0.6, 0.5, t), p)
				for name, v in p.joints do
					for k = 1, 6 do
						Assert.truthy(v[k] == v[k] and math.abs(v[k]) < 10, beat .. " " .. name .. " finite")
					end
				end
			end
		end
	end)

	test("C5: torch sway and the head/moustache bounce while he walks", function()
		local p = GusBeats.newPose()
		local seenSway, seenNod = 0, 0
		for i = 0, 40 do
			GusBeats.pose(B.Patrol, 0, walk(i / 40, 1, 0, i * 0.1), p)
			seenSway = math.max(seenSway, math.abs(j(p, "FlashlightGrip", 5)))
			seenNod = math.max(seenNod, math.abs(j(p, "Neck", 4)))
		end
		Assert.truthy(seenSway > math.rad(G.TORCH_SWAY) * 0.8, "torch sways")
		Assert.truthy(seenNod > math.rad(G.MOUSTACHE_BOUNCE) * 0.3, "head bounces")
	end)

	test("blend: halfway between two poses", function()
		local a, b, o = GusBeats.newPose(), GusBeats.newPose(), GusBeats.newPose()
		GusBeats.pose(B.Catch, 0.3, walk(), a)
		GusBeats.pose(B.Patrol, 0, walk(), b)
		GusBeats.blend(a, b, 0.5, o)
		Assert.near(j(o, "Root", 3), (j(a, "Root", 3) + j(b, "Root", 3)) / 2, 1e-9, "root z")
	end)

	test("bubbles name real strings", function()
		for _, beat in { B.Doze, B.Wake, B.Patrol, B.DoubleTake, B.Chase, B.Catch, B.WrongOne, B.Scratch } do
			for t = 0, 3, 0.1 do
				local key = GusBeats.bubble(beat, t)
				if key then
					Assert.truthy(type((Strings :: any)[key]) == "string", beat .. " bubble " .. key)
				end
			end
		end
		Assert.eq(GusBeats.bubble(B.Doze, 0), "GUS_ZZ", "zz")
		Assert.eq(GusBeats.bubble(B.Chase, 0.2), "GUS_SPOTTED", "! at the chase start")
		Assert.eq(GusBeats.bubble(B.Chase, G.BANG_SECONDS + 0.1), nil, "no ! once he runs")
	end)

	test("look: clamped, gives up behind him, re-engages in front", function()
		local max = math.rad(G.LOOK_YAW_MAX)
		local y, lost = GusBeats.look(math.rad(30), false)
		Assert.near(y, math.rad(30), 1e-9, "inside the clamp")
		Assert.falsy(lost, "engaged")
		y, lost = GusBeats.look(math.rad(85), false)
		Assert.near(y, max, 1e-9, "clamped at the max")
		y, lost = GusBeats.look(math.rad(G.LOOK_YAW_MAX + G.LOOK_LOSE + 5), false)
		Assert.eq(y, 0, "behind him: gives up")
		Assert.truthy(lost, "lost")
		y, lost = GusBeats.look(math.rad(85), true)
		Assert.eq(y, 0, "hysteresis: still lost at 85")
		y, lost = GusBeats.look(math.rad(-60), true)
		Assert.near(y, math.rad(-60), 1e-9, "back in front: looks again")
		Assert.falsy(lost, "re-engaged")
		Assert.near(GusBeats.lookPitch(math.rad(80)), math.rad(G.LOOK_PITCH_MAX), 1e-9, "pitch clamp")
	end)

	test("delay line: the body yaw a lead behind, shortest arc", function()
		local d = GusBeats.newDelay(8)
		Assert.eq(GusBeats.delaySample(d, 0), nil, "empty")
		for i = 0, 20 do
			GusBeats.delayPush(d, i * 0.05, i * 0.05)
		end
		Assert.near(GusBeats.delaySample(d, 1.0 - 0.2) :: number, 0.8, 1e-9, "a lead behind")
		Assert.near(GusBeats.delaySample(d, 0.825) :: number, 0.825, 1e-9, "interpolated")
		Assert.near(GusBeats.delaySample(d, 5) :: number, 1.0, 1e-9, "newest")
		local w = GusBeats.newDelay(4)
		GusBeats.delayPush(w, 0, 2 * math.pi - 0.1)
		GusBeats.delayPush(w, 1, 0.1)
		Assert.near(GusBeats.delaySample(w, 0.5) :: number, 0, 1e-9, "wraps through 0")
	end)

	test("boot prints: on the route ahead, fixed in place, alternating, fading, none while he stands", function()
		local route = squareRoute()
		local out = GusBeats.newPrints()
		local n = GusBeats.bootPrints(route, 0.3, out)
		Assert.truthy(n >= 3 and n <= G.PRINT_MAX, "a few prints (" .. n .. ")")
		for i = 1, n do
			-- Back off the lateral spread: the centre is on the square's edges.
			local yaw, side = out.yaw[i], out.side[i]
			local cx = out.x[i] - math.cos(yaw) * G.PRINT_SPREAD * side
			local cz = out.z[i] + math.sin(yaw) * G.PRINT_SPREAD * side
			local onEdge = (
				math.abs(cz) < 1e-6
				or math.abs(cz - 10) < 1e-6
				or math.abs(cx) < 1e-6
				or math.abs(cx - 10) < 1e-6
			)
			Assert.truthy(onEdge, "print " .. i .. " on the route")
			if i > 1 then
				Assert.eq(out.side[i], -out.side[i - 1], "boots alternate")
				Assert.truthy(out.fade[i] > out.fade[i - 1], "farther prints fade more")
			end
		end
		-- The first print is ahead of Gus.
		local gx, gz = Guards.patrol(route, 0.3)
		Assert.truthy(out.x[1] > gx, "ahead of him (" .. gx .. "," .. gz .. ")")
		-- Fixed in place: a moment later the same print index is at the same spot.
		local k1, x1, z1 = out.k[2], out.x[2], out.z[2]
		local out2 = GusBeats.newPrints()
		local n2 = GusBeats.bootPrints(route, 0.4, out2)
		local found = false
		for i = 1, n2 do
			if out2.k[i] == k1 then
				found = true
				Assert.near(out2.x[i], x1, 1e-9, "print x stays")
				Assert.near(out2.z[i], z1, 1e-9, "print z stays")
			end
		end
		Assert.truthy(found, "the print is still ahead")
		-- Next 2 s only: everything within horizon x speed of him.
		local reach = route.speed * G.PRINT_HORIZON + G.PRINT_SPREAD + 1e-6
		for i = 1, n do
			Assert.truthy(math.sqrt((out.x[i] - gx) ^ 2 + (out.z[i] - gz) ^ 2) <= reach, "within 2 s of walking")
		end
		-- Standing for the whole horizon (a post): none.
		local post = TestLevels.watch().guards[1].route
		Assert.eq(GusBeats.bootPrints(post, 3, out), 0, "a post leaves no prints")
		-- Across the period wrap.
		local nWrap = GusBeats.bootPrints(route, route.period - 0.5, out)
		Assert.truthy(nWrap >= 3, "prints continue across the loop")
	end)

	test("route distance and point agree with Guards.patrol", function()
		local route = l4Route()
		for t = 0, route.period * 2, 0.37 do
			local d = GusBeats.routeDistance(route, t)
			local x, z = GusBeats.routePoint(route, d)
			local px, pz = Guards.patrol(route, t)
			Assert.near(x, px, 1e-6, "x at " .. t)
			Assert.near(z, pz, 1e-6, "z at " .. t)
		end
	end)

	test("turnSoon: flickers in the half second before a dwell turn, not while walking", function()
		local route = l4Route()
		local leg = route.legs[1]
		local turnStart = leg.tEnd - Config.Sim.GUARD_TURN_SECONDS
		Assert.truthy(GusBeats.turnSoon(route, turnStart - 0.3), "0.3 s before the turn")
		Assert.falsy(GusBeats.turnSoon(route, turnStart - 1.5), "long before")
		Assert.falsy(GusBeats.turnSoon(route, (leg.tStart + leg.tArrive) / 2), "while walking")
		Assert.falsy(GusBeats.turnSoon(route, turnStart + 0.2), "once turning")
		Assert.truthy(GusBeats.flicker(0) ~= GusBeats.flicker(0.5 / G.FLICKER_HZ), "flicker alternates")
	end)

	test("cone: each wedge only reaches its shorter ray (no amber through walls)", function()
		local rays = { 30, 30, 6, 30, 5 }
		local out = {}
		GusBeats.clipFan(rays, 5, out)
		Assert.eq(out[1], 30, "open")
		Assert.eq(out[2], 6, "wedge next to a wall hit stops at the wall")
		Assert.eq(out[3], 6, "both sides")
		Assert.eq(out[4], 5, "last")
	end)
end
