-- L1: clone acting (PLAN_STEAM_PLUS §4.4 A3): Heist/CloneState (the per-frame state from a recording),
-- Heist/ClonePose (custom poses) and Heist/CloneGait (clip speeds locked to the recording, premium C7).

local Assert = require("./Assert")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local Config = require("../../src/shared/Config")
local CloneState = require("../../src/shared/Heist/CloneState")
local ClonePose = require("../../src/shared/Heist/ClonePose")
local CloneGait = require("../../src/shared/Heist/CloneGait")
local TestLevels = require("../sim/TestLevels")

local C = Config.Clone
local HZ = 20
local G = Codec.FLAG.GROUNDED

-- A recording from a list of segments: { seconds, vx (studs/s), vy, flags }.
local function path(segments: { { number } }, x0: number?, y0: number?, z0: number?): any
	local rec = Sampler.new(nil, nil, HZ)
	local x, y, z = x0 or 0, y0 or 3, z0 or 0
	Sampler.push(rec, x, y, z, 0, G)
	for _, seg in segments do
		local n = math.floor(seg[1] * HZ + 0.5)
		for _ = 1, n do
			x += seg[2] / HZ
			y += (seg[3] or 0) / HZ
			Sampler.push(rec, x, y, z, 0, seg[4] or G)
		end
	end
	Sampler.finish(rec, Codec.END.EndRun)
	return rec
end

local function ctx(extra: { [string]: any }?): any
	local c: any = { gone = nil, stuck = nil, carrying = nil, plates = nil, prevLoco = nil }
	for k, v in extra or {} do
		c[k] = v
	end
	return c
end

return function(test)
	test("state: moving, idle, on-plate (plate box P of the corridor level)", function()
		local level = TestLevels.corridor() -- plate P: x 8..12, z -7..-3
		local rec = path({ { 1, 10 }, { 2, 0 } }, 0, 3, -5) -- walks +X 10 studs to x = 10, then stands
		local f = CloneState.derive(rec, 0.5, ctx({ plates = level.plates })) :: any
		Assert.eq(f.state, "moving", "walking")
		Assert.eq(f.loco, "move", "walk clips")
		Assert.near(f.speed, 10, 0.5, "speed from the spline")
		f = CloneState.derive(rec, 2.5, ctx({ plates = level.plates })) :: any
		Assert.eq(f.state, "on-plate", "standing inside P")
		Assert.eq(f.plate, 1, "plate index")
		local off = path({ { 2, 0 } }, 0, 3, -5)
		Assert.eq(
			(CloneState.derive(off, 1, ctx({ plates = level.plates })) :: any).state,
			"idle",
			"standing off any plate"
		)
		Assert.eq(
			(CloneState.derive(rec, 0.5, ctx({ plates = level.plates })) :: any).plate,
			0,
			"no plate while moving"
		)
	end)

	test("state: carry wins over moving and on-plate; stuck and busted win over everything", function()
		local level = TestLevels.corridor()
		local rec = path({ { 1, 10 }, { 2, 0 } }, 0, 3, -5)
		Assert.eq((CloneState.derive(rec, 0.5, ctx({ carrying = true })) :: any).state, "carry", "carrying, walking")
		local f = CloneState.derive(rec, 2.5, ctx({ carrying = true, plates = level.plates })) :: any
		Assert.eq(f.state, "carry", "carrying on a plate")
		Assert.eq(f.loco, "idle", "standing under the carry")
		f = CloneState.derive(rec, 0.5, ctx({ stuck = true, carrying = true })) :: any
		Assert.eq(f.state, "stuck", "stuck")
		Assert.eq(f.speed, 0, "a stuck clone stands")
		Assert.eq(f.loco, "idle", "stuck: idle clips")
		f = CloneState.derive(rec, 0.5, ctx({ gone = "Busted", stuck = true })) :: any
		Assert.eq(f.state, "busted", "busted")
		Assert.eq((CloneState.derive(rec, 0.5, ctx({ gone = "Zapped" })) :: any).state, "busted", "zapped too")
	end)

	test("state: jump while rising, fall while dropping (flags and height change)", function()
		local air = Codec.FLAG.JUMPING
		local rec = path({ { 0.5, 8 }, { 0.3, 8, 20, air }, { 0.3, 8, -20, air }, { 0.5, 8 } })
		local f = CloneState.derive(rec, 0.65, ctx()) :: any
		Assert.eq(f.state, "jump", "rising")
		Assert.truthy(f.vy > 0, "vy up")
		f = CloneState.derive(rec, 0.95, ctx()) :: any
		Assert.eq(f.state, "fall", "dropping")
		Assert.eq((CloneState.derive(rec, 1.5, ctx()) :: any).state, "moving", "landed")
		-- A step down a ledge with the GROUNDED flag kept and a slow rise is not a jump.
		local stairs = path({ { 1, 8, 1.5 } })
		Assert.eq((CloneState.derive(stairs, 0.5, ctx()) :: any).state, "moving", "a gentle slope")
	end)

	test("state: walk and stand have hysteresis", function()
		local rec = path({ { 1, 0.6 } })
		Assert.eq((CloneState.derive(rec, 0.5, ctx()) :: any).loco, "idle", "0.6 studs/s from standing: stands")
		Assert.eq((CloneState.derive(rec, 0.5, ctx({ prevLoco = "move" })) :: any).loco, "move", "keeps walking")
	end)

	test("state: empty recording gives nil; the frame table is reused", function()
		local empty = Sampler.new(nil, nil, HZ)
		Assert.eq(CloneState.derive(empty, 0, ctx()), nil, "nil")
		local out = CloneState.newFrame()
		local rec = path({ { 1, 5 } })
		Assert.eq(CloneState.derive(rec, 0.5, ctx(), out), out, "same table")
	end)

	test("violet drift is solo only, oldest run drifts the full amount", function()
		local h = 0.5
		Assert.eq(CloneState.driftHue(h, 2, 3, false), h, "co-op: no drift")
		Assert.eq(CloneState.driftHue(h, 0, 3, true), h, "newest: no drift")
		Assert.near(CloneState.driftHue(h, 2, 3, true), h + C.DRIFT_DEGREES / 360, 1e-9, "oldest: full drift")
		Assert.eq(CloneState.driftHue(h, 0, 1, true), h, "one clone: no drift")
		Assert.truthy(CloneState.driftHue(0.99, 3, 4, true) < 1, "wraps")
	end)

	test("pose: carry holds both arms forward with forearms up and bobs", function()
		local p = ClonePose.compute(ClonePose.new(), "carry", 1, 0, math.pi / 4, true, 0, 0, 1)
		Assert.truthy(p.busy, "busy")
		for _, side in { "Left", "Right" } do
			local up = p.joints[side .. "UpperArm"]
			local low = p.joints[side .. "LowerArm"]
			Assert.truthy(up and up[1] > 0.6, side .. " arm forward")
			Assert.truthy(low and low[1] > 0.6, side .. " forearm up")
		end
		Assert.truthy(p.joints.LeftUpperArm[3] > 0 and p.joints.RightUpperArm[3] < 0, "hands toward the middle")
		Assert.near(p.bob, math.sin(math.pi / 2) * C.CARRY_BOB, 1e-9, "bob: two per walk cycle")
		local half = ClonePose.compute(ClonePose.new(), "carry", 1, 0, 0, false, 0, 0, 0.5)
		Assert.near(half.joints.LeftLowerArm[1], C.CARRY_ELBOW * 0.5, 1e-9, "weight blends")
		local none = ClonePose.compute(ClonePose.new(), "moving", 1, 0, 0, true, 0, 0, 1)
		Assert.falsy(none.busy, "no custom pose for moving")
		Assert.eq(next(none.joints), nil, "no joints set")
	end)

	test("pose: plate stance glances back once, inside the look limits", function()
		local yaw, _, ok = ClonePose.look(-10, 0, 0, 0) -- target 10 studs to the left of a clone facing -Z
		Assert.truthy(ok, "looks")
		Assert.truthy(yaw > 0, "turns left")
		Assert.truthy(yaw <= C.LOOK_YAW + 1e-9, "clamped to the yaw limit")
		local _, _, behind = ClonePose.look(0, 0, 10, 0) -- straight behind
		Assert.falsy(behind, "no look at a target straight behind")
		local y2, p2 = ClonePose.look(-5, 5, -5, 0)
		Assert.truthy((y2 / C.LOOK_YAW) ^ 2 + (p2 / C.LOOK_PITCH) ^ 2 <= 1 + 1e-9, "inside the ellipse")
		Assert.eq(ClonePose.glance(0.1), 0, "planted first")
		Assert.eq(ClonePose.glance(C.GLANCE_AT + C.GLANCE_IN + 0.1), 1, "the glance")
		Assert.eq(ClonePose.glance(C.GLANCE_AT + C.GLANCE_IN + C.GLANCE_HOLD + C.GLANCE_OUT + 0.01), 0, "once")
		Assert.eq(ClonePose.glance(30), 0, "never again on this stay")
		local p =
			ClonePose.compute(ClonePose.new(), "on-plate", C.GLANCE_AT + C.GLANCE_IN + 0.2, 1, 0, false, yaw, 0, 1)
		Assert.near(p.joints.Head[2], yaw, 1e-9, "head turns to the target")
		Assert.truthy(p.joints.UpperTorso ~= nil, "weight shift at the waist")
	end)

	test("pose: stuck taps the wall, then shrugs", function()
		local tap = ClonePose.compute(ClonePose.new(), "stuck", 0.6, 0, 0, false, 0, 0, 1)
		Assert.truthy(tap.joints.RightUpperArm[1] > 1.2, "right hand on the wall")
		Assert.truthy(math.abs(tap.joints.LeftUpperArm[3]) < 0.05, "left arm down while tapping")
		local shrug = ClonePose.compute(ClonePose.new(), "stuck", C.STUCK_TAP + 0.6, 0, 0, false, 0, 0, 1)
		Assert.truthy(shrug.joints.LeftUpperArm[3] < -0.3 and shrug.joints.RightUpperArm[3] > 0.3, "arms out")
		Assert.truthy(shrug.joints.LeftLowerArm[1] > 1, "forearms up")
	end)

	test("pose: busted puts its hands up, then glitches in 3 two-frame slices", function()
		local up = ClonePose.compute(ClonePose.new(), "busted", C.BUSTED_HANDS_UP * 0.99, 0, 0, false, 0, 0, 1)
		Assert.truthy(up.joints.LeftUpperArm[1] > 2.5 and up.joints.RightUpperArm[1] > 2.5, "hands up")
		Assert.eq(up.glitchX, 0, "no glitch while the hands go up")
		local slices, frames, last = 0, 0, 0
		local step = 1 / 240
		for i = 0, math.ceil(C.BUSTED_GLITCH / step) + 4 do
			local g = ClonePose.glitch(i * step)
			if g ~= 0 then
				frames += 1
				if last == 0 then
					slices += 1
				end
				Assert.near(math.abs(g), C.GLITCH_OFFSET, 1e-9, "offset")
			end
			last = g
		end
		Assert.eq(slices, C.GLITCH_SLICES, "slices")
		Assert.le(frames * step, C.GLITCH_SLICES * 2 * C.GLITCH_FRAME + 1e-9, "two frames each")
		Assert.near(ClonePose.bustedSeconds(), C.BUSTED_HANDS_UP + C.BUSTED_GLITCH, 1e-9, "gone after both")
	end)

	-- premium C7: the clip-implied travel matches the real travel within 0.3 studs per stride.
	-- `clipRate`: the rate the clip speed assumes (the real rate when locked to the recording).
	local function maxSlide(rate: number, clipRate: number?): (number, number)
		-- accelerate to a run, run, slow to a walk, stand
		local rec = path({ { 0.5, 6 }, { 0.5, 12 }, { 3, 16 }, { 2, 6 }, { 1, 2.5 }, { 0.5, 0 } })
		local g = CloneGait.new()
		local dt = 1 / 60
		local t = 0
		local worst, strides = 0, 0
		local implied, actual = 0, 0
		local loco = "idle"
		local frame = CloneState.newFrame()
		while t < Sampler.duration(rec) do
			local f = CloneState.derive(rec, t, { prevLoco = loco }, frame) :: any
			loco = f.loco
			local real = f.speed * rate * dt
			actual += real
			if loco == "move" then
				CloneGait.step(g, f.speed, clipRate or rate)
				implied += g.speed * C.GAIT_BASE * dt -- what the playing clip covers
			else
				CloneGait.reset(g)
			end
			if actual >= C.STRIDE then
				worst = math.max(worst, math.abs(implied - actual))
				strides += 1
				implied, actual = 0, 0
			end
			t += dt * rate
		end
		return worst, strides
	end

	test("gait: foot slide under 0.3 studs per stride at 1x and 3x", function()
		for _, rate in { 1, Config.Rec.SKIP_SPEED } do
			local worst, strides = maxSlide(rate)
			Assert.truthy(strides >= 4, "enough strides at " .. rate .. "x (" .. strides .. ")")
			Assert.le(worst, 0.3, string.format("slide per stride at %dx: %.3f studs", rate, worst))
		end
		-- The measure catches sliding: a clip on wall-clock speed (the old view) slides at 3x.
		local unlocked = maxSlide(Config.Rec.SKIP_SPEED, 1)
		Assert.truthy(unlocked > 0.3, string.format("unlocked clip at 3x slides (%.2f studs)", unlocked))
	end)

	test("gait: walk alone, blend, run alone by recorded speed (not the clock rate)", function()
		local _, w, r = CloneGait.target(3, 1)
		Assert.eq(w, 1, "walk")
		Assert.eq(r, 0, "no run")
		local _, w2, r2 = CloneGait.target(16, 1)
		Assert.eq(r2, 1, "run")
		Assert.eq(w2, 0, "no walk")
		local s3, w3 = CloneGait.target(3, 3)
		Assert.eq(w3, 1, "a fast-forwarded walk is still a walk")
		Assert.near(s3, 9 / C.GAIT_BASE, 1e-9, "... played 3x faster")
		local g = CloneGait.new()
		local a, b = CloneGait.step(g, 10, 1)
		Assert.truthy(a and b, "first step sends both")
		local c, d = CloneGait.step(g, 10.01, 1)
		Assert.falsy(c, "a tiny change sends no AdjustSpeed")
		Assert.falsy(d, "same weights")
	end)

	test("gait: path length and phase lock", function()
		local rec = path({ { 1, 10 }, { 1, 0 } })
		local dist = CloneGait.distances(rec)
		Assert.near(CloneGait.distanceAt(rec, dist, 0), 0, 1e-9, "start")
		Assert.near(CloneGait.distanceAt(rec, dist, 0.5), 5, 1e-6, "half way")
		Assert.near(CloneGait.distanceAt(rec, dist, 5), 10, 1e-6, "holds at the end")
		Assert.near(CloneGait.phase(C.STRIDE * 2.25), 0.25, 1e-9, "phase from distance")
	end)
end
