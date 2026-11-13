-- L1: first person (PLAN_FIRST_PERSON FP): the pure maths of the fp camera (Heist/FpMath: look turns, the
-- stick curve, head bob, the landing spring, the eye), the look-to-interact pick with its aim-assist cone and
-- line-of-sight rule (FpMath.pick, deterministic), the server's range rule mirrored on the client
-- (FpMath.inSimRange against Sim/Interact), the viewmodel's pose maths (Heist/ViewmodelMath: envelopes, the
-- carry blend, look lag, the wall pull) and Gus's edge warning weights; plus the numbers in Config. And on
-- L1 as the server builds it (sim solids + kit boxes, tests/unit/LevelBoxes): the cash is pickable from in
-- front of it, and not through the back wall.

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local FpMath = require("../../src/client/Heist/FpMath")
local ViewmodelMath = require("../../src/client/Heist/ViewmodelMath")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Catalog = require("../../src/shared/Levels/Catalog")
local Interact = require("../../src/shared/Sim/Interact")
local Codec = require("../../src/shared/Rec/Codec")
local LevelBoxes = require("./LevelBoxes")

local FP = Config.Heist.CAMERA.FP
local VM = Config.FirstPerson.VIEWMODEL
local LK = Config.FirstPerson.LOOK
local W = Config.FirstPerson.WARN

local function level(id: string): any
	for _, spec in Catalog do
		if spec.id == id then
			return LevelSpec.compile(spec)
		end
	end
	error("no level " .. id)
end

local function opts(extra: any?): any
	local o = {
		reach = LK.REACH,
		assist = LK.ASSIST.mouse,
		distanceWeight = LK.DISTANCE_WEIGHT,
		sticky = LK.STICKY,
		losCandidates = LK.LOS_CANDIDATES,
	}
	for k, v in extra or {} do
		o[k] = v
	end
	return o
end

local function norm(v: { number }): { number }
	local l = FpMath.len(v)
	return { v[1] / l, v[2] / l, v[3] / l }
end

return function(test)
	test("config: first person is the default, FOV 70 with a 60-90 slider, no roll", function()
		Assert.eq(Config.Heist.CAMERA.DEFAULT_MODE, "fp", "fp is the default camera")
		Assert.eq(FP.FOV, 70, "FOV 70")
		local r = Config.Data.SETTING_NUMBERS.fpFov
		Assert.truthy(r[1] == 60 and r[2] == 90, "the comfort slider is 60-90")
		Assert.eq(Config.Data.SETTING_NUMBER_DEFAULTS.fpFov, FP.FOV, "the setting's default is the camera's FOV")
		Assert.truthy(FP.PITCH_MIN >= -89 and FP.PITCH_MAX <= 89, "pitch never reaches the poles (no flip)")
		Assert.truthy(FP.BOB.Y <= 0.12 and FP.BOB.X <= 0.08, "head bob is subtle")
		Assert.le(FP.LAND.MAX, 0.5, "the landing dip is subtle")
	end)

	test("look: mouse right turns right, down looks down, pitch clamps, yaw wraps", function()
		local y, p = FpMath.turn(0, 0, 10, 0, 1, 1, FP.PITCH_MIN, FP.PITCH_MAX)
		Assert.eq(y, -10, "moving right turns right (yaw decreases)")
		Assert.eq(p, 0, "no pitch change")
		y, p = FpMath.turn(0, 0, 0, 1000, 1, 1, FP.PITCH_MIN, FP.PITCH_MAX)
		Assert.eq(p, FP.PITCH_MAX, "pitch clamps at the floor")
		y, p = FpMath.turn(175, 0, -10, 0, 1, 1, FP.PITCH_MIN, FP.PITCH_MAX)
		Assert.eq(y, -175, "yaw wraps past 180")
		-- look(yaw, pitch) and angles() round-trip
		local d = FpMath.look(30, 20)
		local yy, pp = FpMath.angles(d)
		Assert.near(yy, 30, 1e-9, "yaw round-trip")
		Assert.near(pp, 20, 1e-9, "pitch round-trip")
	end)

	test("stick: dead zone, full at the edge, a curve near the centre, sign kept", function()
		Assert.eq(FpMath.stick(0.1, 0.15, 1.6), 0, "inside the dead zone")
		Assert.near(FpMath.stick(1, 0.15, 1.6), 1, 1e-9, "full at the edge")
		Assert.near(FpMath.stick(-1, 0.15, 1.6), -1, 1e-9, "sign kept")
		local half = FpMath.stick(0.575, 0.15, 1.6)
		Assert.truthy(half > 0 and half < 0.5, "slower than linear near the centre")
	end)

	test("head bob: a step per STRIDE at walking speed, amplitude follows speed, centred", function()
		local phase, amp = 0, 0
		local speed = FP.BOB.FULL_SPEED
		for _ = 1, 600 do
			phase, amp = FpMath.bobStep(phase, amp, 1 / 60, speed, FP.BOB)
		end
		Assert.near(amp, 1, 1e-3, "full amplitude at full speed")
		-- one second at 16 studs/s = 16 / STRIDE steps = that many half-turns of pi
		local p0 = 0
		local p1 = FpMath.bobStep(p0, 1, 1, speed, FP.BOB)
		Assert.near(p1, (math.pi * speed / FP.BOB.STRIDE) % (4 * math.pi), 1e-9, "pi per step")
		local x0, y0 = FpMath.bobOffset(1.2, 0, FP.BOB)
		Assert.truthy(x0 == 0 and y0 == 0, "no bob standing still")
		-- the mean height over a cycle is ~0 (the eye does not sink while walking)
		local sum, n = 0, 400
		for k = 0, n - 1 do
			local _, y = FpMath.bobOffset(k / n * 4 * math.pi, 1, FP.BOB)
			sum += y
		end
		Assert.le(math.abs(sum / n), FP.BOB.Y * 0.15, "centred bob")
		local _, still = FpMath.bobStep(0, 1, 1, 0, FP.BOB)
		Assert.le(still, 0.01, "it settles when you stop")
	end)

	test("spring + landing kick: a soft landing does not dip, a hard one dips about its depth and settles", function()
		Assert.eq(FpMath.landKick(FP.LAND.MIN_FALL - 1, FP.LAND), 0, "soft landing")
		local fall = FP.LAND.MIN_FALL + 10
		local depth = math.min(10 * FP.LAND.PER_SPEED, FP.LAND.MAX)
		local x, v = 0, FpMath.landKick(fall, FP.LAND)
		local low = 0
		for _ = 1, 240 do
			x, v = FpMath.spring(x, v, 0, 1 / 120, FP.LAND.FREQ, FP.LAND.DAMPING)
			low = math.min(low, x)
		end
		Assert.truthy(low < 0, "it dips")
		Assert.near(-low, depth, depth * 0.05, "its depth")
		Assert.le(math.abs(x), 0.01, "settled within 2 s")
		-- frame-rate independent: 60 fps and 144 fps land on the same spot after 0.5 s
		local a60, va = 1, 0
		for _ = 1, 30 do
			a60, va = FpMath.spring(a60, va, 0, 1 / 60, VM.LAG.FREQ, VM.LAG.DAMPING)
		end
		local a144, vb = 1, 0
		for _ = 1, 72 do
			a144, vb = FpMath.spring(a144, vb, 0, 1 / 144, VM.LAG.FREQ, VM.LAG.DAMPING)
		end
		Assert.near(a60, a144, 1e-9, "same at any frame rate")
		-- a long frame does not explode
		local bx = FpMath.spring(1, 0, 0, 0.5, FP.LAND.FREQ, FP.LAND.DAMPING)
		Assert.le(math.abs(bx), 1, "stable over a 0.5 s frame")
		local huge = FpMath.landKick(1000, FP.LAND)
		Assert.near(huge, -FP.LAND.MAX / FpMath.springPeak(FP.LAND.FREQ, FP.LAND.DAMPING), 1e-9, "capped")
	end)

	test("eye: above the head and a little ahead along the look", function()
		local e = FpMath.eye({ 10, 3, 5 }, 1.5, 0, FP)
		Assert.near(e[2], 3 + 1.5 + FP.EYE_UP, 1e-9, "height")
		Assert.near(e[3], 5 - FP.EYE_FORWARD, 1e-9, "ahead along -Z at yaw 0")
		local e90 = FpMath.eye({ 0, 0, 0 }, 1.5, 90, FP)
		Assert.near(e90[1], -FP.EYE_FORWARD, 1e-9, "yaw 90 looks down -X")
	end)

	test("pick: the ray picks what it hits, the cone helps, reach and line of sight rule", function()
		local eye = { 0, 5, 0 }
		local fwd = { 0, 0, -1 }
		local list = {
			{ id = "loot:1", pos = { 0, 5, -4 }, radius = 0.5 },
			{ id = "loot:2", pos = { 3, 5, -4 }, radius = 0.5 },
		}
		local i = FpMath.pick(eye, fwd, list, opts())
		Assert.eq(i, 1, "the one straight ahead")
		-- 2 degrees beyond its edge: inside the mouse cone (2.5), outside with a tighter one
		local ang = math.rad(math.deg(math.asin(0.5 / 4)) + 2)
		local off = norm({ math.sin(ang), 0, -math.cos(ang) })
		Assert.eq(FpMath.pick(eye, off, { list[1] }, opts()), 1, "aim assist catches a near miss")
		Assert.eq(FpMath.pick(eye, off, { list[1] }, opts({ assist = 1 })), nil, "outside a tighter cone")
		-- touch has the widest cone
		Assert.truthy(LK.ASSIST.touch > LK.ASSIST.gamepad and LK.ASSIST.gamepad > LK.ASSIST.mouse, "cones")
		-- out of reach / behind / refused by the sim
		local far = { { id = "loot:9", pos = { 0, 5, -(LK.REACH + 2) }, radius = 0.5 } }
		Assert.eq(FpMath.pick(eye, fwd, far, opts()), nil, "out of reach")
		local behind = { { id = "loot:8", pos = { 0, 5, 3 }, radius = 0.5 } }
		Assert.eq(FpMath.pick(eye, fwd, behind, opts()), nil, "behind you")
		local refused = { { id = "loot:7", pos = { 0, 5, -3 }, radius = 0.5, ok = false } }
		Assert.eq(FpMath.pick(eye, fwd, refused, opts()), nil, "the sim would refuse it")
		-- blocked: the next best wins
		local j = FpMath.pick(
			eye,
			norm({ 0.3, 0, -1 }),
			list,
			opts({
				assist = 30,
				blocked = function(_, c)
					return c.id == "loot:2"
				end,
			})
		)
		Assert.eq(j, 1, "a blocked target gives way to the next")
	end)

	test("pick: deterministic ties (by id) and sticky against a near tie", function()
		local eye = { 0, 0, 0 }
		local fwd = { 0, 0, -1 }
		local a = { id = "loot:2", pos = { 0.2, 0, -4 }, radius = 0.5 }
		local b = { id = "loot:1", pos = { -0.2, 0, -4 }, radius = 0.5 }
		local i1 = FpMath.pick(eye, fwd, { a, b }, opts())
		local i2 = FpMath.pick(eye, fwd, { b, a }, opts())
		Assert.eq(({ a, b })[i1 :: number].id, "loot:1", "the tie goes to the lower id")
		Assert.eq(({ b, a })[i2 :: number].id, "loot:1", "whatever the input order")
		local i3 = FpMath.pick(eye, fwd, { a, b }, opts({ current = "loot:2" }))
		Assert.eq(({ a, b })[i3 :: number].id, "loot:2", "the current target sticks")
	end)

	test("sim range: the client offers only what Sim/Interact's range accepts (less a margin)", function()
		local S = Config.Sim
		Assert.truthy(
			FpMath.inSimRange(
				{ 0, 0, 0 },
				{ S.INTERACT_RANGE - LK.RANGE_MARGIN - 0.01, 3, 0 },
				S.INTERACT_RANGE,
				S.INTERACT_HEIGHT,
				LK.RANGE_MARGIN
			),
			"inside"
		)
		Assert.falsy(
			FpMath.inSimRange(
				{ 0, 0, 0 },
				{ S.INTERACT_RANGE - 0.1, 3, 0 },
				S.INTERACT_RANGE,
				S.INTERACT_HEIGHT,
				LK.RANGE_MARGIN
			),
			"the margin"
		)
		Assert.falsy(
			FpMath.inSimRange(
				{ 0, 0, 0 },
				{ 1, S.INTERACT_HEIGHT + 0.5, 0 },
				S.INTERACT_RANGE,
				S.INTERACT_HEIGHT,
				LK.RANGE_MARGIN
			),
			"too high"
		)
		-- The intents first person sends are ones the server's remote accepts (no new remote, no new kind).
		Assert.truthy(
			Interact.REQUESTABLE[Codec.EVENT.Grab] and Interact.REQUESTABLE[Codec.EVENT.Press],
			"Grab and Press are requestable"
		)
		Assert.truthy(LK.REACH >= S.INTERACT_RANGE, "the eye's reach covers the sim range")
	end)

	test("L1 as built: the cash is pickable from in front of it, not through the back wall", function()
		local l1 = level("cs1_back_room")
		local boxes = LevelBoxes.of(l1, true)
		local cash = l1.loot[1]
		local target = { cash.x, cash.y, cash.z }
		-- skip boxes the cash sits in or on (its counter / stand): the target's own surface
		local function onTarget(e: any): boolean
			local b = e.box
			return cash.x >= b.minX - 1
				and cash.x <= b.maxX + 1
				and cash.z >= b.minZ - 1
				and cash.z <= b.maxZ + 1
				and b.maxY <= cash.y + 1.5
		end
		local function blockedFn(eye: { number })
			return function(_: { number }, c: any): boolean
				return LevelBoxes.blocked(boxes, eye, c.pos, onTarget) ~= nil
			end
		end
		local front = { cash.x, cash.y + 2, cash.z + 3.5 } -- standing in the back room, in front of it
		local dirF = norm(FpMath.sub(target, front))
		local c = { { id = "loot:1", pos = target, radius = LK.RADIUS.loot } }
		local ok = FpMath.pick(front, dirF, c, opts({ blocked = blockedFn(front) }))
		Assert.eq(
			ok,
			1,
			"pickable from in front (" .. tostring(LevelBoxes.blocked(boxes, front, target, onTarget)) .. ")"
		)
		-- Behind the back wall (just outside the shop): even with a reach that long, the wall is in the way.
		local back = { cash.x, cash.y + 2, l1.bounds.minZ - 0.8 }
		local dirB = norm(FpMath.sub(target, back))
		local long = FpMath.len(FpMath.sub(target, back)) + 2
		local through = FpMath.pick(back, dirB, c, opts({ reach = long, blocked = blockedFn(back) }))
		Assert.eq(through, nil, "not through the back wall")
		Assert.eq(FpMath.pick(back, dirB, c, opts({ reach = long })), 1, "(only the wall stops it)")
	end)

	test("viewmodel: envelopes rise, hold and fall; a held action stays up", function()
		local t = { 0.1, 0.2, 0.3 }
		Assert.eq(ViewmodelMath.envelope(-0.1, t), 0, "not yet")
		Assert.near(ViewmodelMath.envelope(0.05, t), 0.5, 1e-9, "half way up (smoothstep)")
		Assert.eq(ViewmodelMath.envelope(0.2, t), 1, "holding")
		Assert.near(ViewmodelMath.envelope(0.45, t), 0.5, 1e-9, "half way down")
		Assert.eq(ViewmodelMath.envelope(0.7, t), 0, "done")
		Assert.eq(ViewmodelMath.envelope(5, t, true), 1, "held")
		Assert.near(ViewmodelMath.duration(t), 0.6, 1e-9, "duration")
		for name, a in VM.ACTIONS do
			Assert.truthy(#a.time == 3 and (a.R ~= nil or a.L ~= nil), name .. " has a pose and an envelope")
			Assert.truthy(table.find(ViewmodelMath.ORDER, name) ~= nil, name .. " is in the layer order")
		end
	end)

	local function frame(extra: any?): any
		local f = {
			t = 0,
			bobPhase = 0,
			bobAmp = 0,
			lagX = 0,
			lagY = 0,
			lagRoll = 0,
			carry = 0,
			hidden = 0,
			wall = 0,
			actions = {},
			reduced = true,
		}
		for k, v in extra or {} do
			f[k] = v
		end
		return f
	end

	test("viewmodel: rest, carry, actions, hide and wall layers", function()
		local R, L = ViewmodelMath.hands(VM, frame())
		for k = 1, 6 do
			Assert.near(R[k], VM.REST.R[k], 1e-9, "rest R " .. k)
			Assert.near(L[k], VM.REST.L[k], 1e-9, "rest L " .. k)
		end
		local Rc = ViewmodelMath.hands(VM, frame({ carry = 1 }))
		Assert.near(Rc[1], VM.CARRY.R[1], 1e-9, "carry pose")
		local Rr = ViewmodelMath.hands(VM, frame({ actions = { reach = 1 } }))
		Assert.near(Rr[3], VM.ACTIONS.reach.R[3], 1e-9, "the reach goes forward")
		Assert.truthy(Rr[3] < VM.REST.R[3], "forward is -z")
		local Rh = ViewmodelMath.hands(VM, frame({ hidden = 1 }))
		Assert.near(Rh[2], VM.REST.R[2] + VM.HIDDEN[2], 1e-9, "lowered while hiding")
		local Rw = ViewmodelMath.hands(VM, frame({ wall = 1 }))
		Assert.truthy(Rw[3] > VM.REST.R[3], "a wall pulls the hands back")
		local _, Lu = ViewmodelMath.hands(VM, frame({ actions = { handsUp = 1 } }))
		Assert.truthy(Lu[2] > 0, "hands up")
		-- the watch tap moves the right hand toward the watch
		local Rt = ViewmodelMath.hands(VM, frame({ actions = { watch = 1 }, tap = 0.05 }))
		Assert.near(Rt[3], VM.ACTIONS.watch.R[3] - 0.05, 1e-9, "the tap")
	end)

	test("viewmodel: look lag trails the turn (clamped), reduced motion keeps a quarter, no bob", function()
		local x, y, roll = ViewmodelMath.lagTarget(-200, 50, VM.LAG)
		Assert.truthy(x < 0, "turning right leaves the hands to the left")
		Assert.truthy(y > 0, "looking down leaves them up")
		Assert.truthy(roll < 0, "a little roll")
		local bx = ViewmodelMath.lagTarget(-1e6, 0, VM.LAG)
		Assert.eq(bx, -VM.LAG.MAX, "clamped")
		local R = ViewmodelMath.hands(VM, frame({ lagX = 0.1 }))
		Assert.near(R[1], VM.REST.R[1] + 0.025, 1e-9, "reduced motion: a quarter of the lag")
		local Rb = ViewmodelMath.hands(VM, frame({ bobPhase = 1, bobAmp = 1 }))
		Assert.near(Rb[2], VM.REST.R[2], 1e-9, "reduced motion: no bob")
		local Rm = ViewmodelMath.hands(VM, frame({ bobPhase = 1, bobAmp = 1, reduced = false }))
		Assert.truthy(Rm[2] < VM.REST.R[2], "the walk bob dips the hands")
	end)

	test("viewmodel: never clips (scaled close), keeps its screen spot at any FOV, loot fits the hands", function()
		-- The farthest any pose reaches, scaled, stays inside the character's own collision (1 stud).
		local far = 0
		local function check(p: { number })
			far = math.max(far, math.sqrt(p[1] ^ 2 + p[2] ^ 2 + p[3] ^ 2) * VM.SCALE)
		end
		check(VM.REST.R)
		check(VM.CARRY.R)
		check(VM.CARRY.LOOT)
		for _, a in VM.ACTIONS do
			if a.R then
				check(a.R)
			end
			if a.L then
				check(a.L)
			end
		end
		-- plus the fingers' length (about 1.3 studs at full size) along the look
		Assert.le(far + 1.3 * VM.SCALE, 1.4, "the rig stays close (" .. far .. ")")
		Assert.truthy(VM.WALL.RANGE >= far, "the wall pull starts before a wall reaches the hands")
		Assert.near(ViewmodelMath.fovFit(VM.FOV_REF, VM.FOV_REF), 1, 1e-9, "same FOV, same spot")
		Assert.truthy(ViewmodelMath.fovFit(90, 70) > 1, "a wider FOV spreads the hands out")
		Assert.near(
			ViewmodelMath.lootScale(2, VM.CARRY.LOOT_SIZE, VM.SCALE) * 2,
			VM.CARRY.LOOT_SIZE * VM.SCALE,
			1e-9,
			"loot fits"
		)
		Assert.eq(ViewmodelMath.wallPull(nil, 1.4), 0, "no wall")
		Assert.eq(ViewmodelMath.wallPull(0, 1.4), 1, "a wall at the eye")
	end)

	test("Gus edge warning: the side he is on is strongest, every edge keeps a share", function()
		local l, r, t, b = FpMath.edgeWeights(90, W.SIDE_MIN)
		Assert.near(l, 1, 1e-9, "on your left")
		Assert.near(r, W.SIDE_MIN, 1e-9, "the far side keeps its share")
		Assert.near(t, W.SIDE_MIN + (1 - W.SIDE_MIN) * 0, 1e-6, "not in front")
		local _, _, t2, b2 = FpMath.edgeWeights(0, W.SIDE_MIN)
		Assert.truthy(t2 > b2, "in front: the top edge")
		local _, _, _, b3 = FpMath.edgeWeights(180, W.SIDE_MIN)
		Assert.near(b3, 1, 1e-9, "behind: the bottom edge")
		Assert.truthy(W.SURE > W.SEEN and W.SEEN > 0, "! is stronger than ?")
		Assert.eq(FpMath.approach(0, 1, 0.1, 0.2, 0.4), 0.5, "eases in")
		Assert.eq(FpMath.approach(1, 0, 0.1, 0.2, 0.4), 0.75, "eases out slower")
		Assert.truthy(b ~= nil, "four edges")
	end)
end
