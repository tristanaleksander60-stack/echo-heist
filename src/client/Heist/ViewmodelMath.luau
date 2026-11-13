--!strict
-- Heist/ViewmodelMath: the pure pose maths of the first-person hands (Heist/Viewmodel, PLAN_FIRST_PERSON FP;
-- docs/research/fp_hands.md). Lune-tested (tests/unit/HeistFirstPerson.spec.luau, HeistHands.spec.luau,
-- HeistFpRig.spec.luau). A hand pose is { x, y, z, rx, ry, rz }: VIEWMODEL camera space at full size (x right,
-- y up, -z forward; studs) and degrees (pitch, yaw, roll), as a camera of Config.FirstPerson.VIEWMODEL.VIEW_FOV
-- sees it.
--
-- One frame of hands = the rest pose, lowered by the visibility blend (the hands sink at idle), the carry pose,
-- each playing action blended over it by its envelope (anticipation, rise with an overshoot, hold, fall), the
-- onboarding point, then the layers that never stop: idle breathing, the walk bob (in step with the camera's head
-- bob, a little behind it), the look lag (a spring that trails how fast you turn), the hide lower and the wall
-- pull. Every layer is a plain sum, so an action never pops: its weight eases in and out.
--
-- The viewmodel FOV (fp_hands.md rule 5): ViewmodelMath.project maps a part's camera-space frame and size the way a
-- separate VIEW_FOV camera would draw it under the real camera FOV.

local ViewmodelMath = {}

export type Pose = { number } -- { x, y, z, rx, ry, rz }

-- Linear blend of two poses (w = 0 -> a, 1 -> b; w < 0 moves away from b: an anticipation).
function ViewmodelMath.blend(a: Pose, b: Pose, w: number): Pose
	local out = table.create(6)
	for k = 1, 6 do
		out[k] = a[k] + (b[k] - a[k]) * w
	end
	return out
end

-- Adds an offset pose times w.
local function add(a: Pose, d: { number }, w: number): Pose
	local out = table.create(6)
	for k = 1, 6 do
		out[k] = a[k] + (d[k] or 0) * w
	end
	return out
end

-- Smoothstep 0..1.
local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- easeOutBack: 0 -> 1 with a single overshoot past 1 (c = 1.70158 overshoots about 10 %).
function ViewmodelMath.easeOutBack(u: number, c: number): number
	u = math.clamp(u, 0, 1)
	local v = u - 1
	return 1 + (c + 1) * v * v * v + c * v * v
end

-- An action's weight `elapsed` seconds after it started: an optional anticipation (anticipate = { seconds, share }:
-- the weight dips to -share, so the hand first pulls back), then it rises over time[1] (easeOutBack when
-- `overshoot` is given, else smoothstep), holds time[2] and falls over time[3]; 0 before and after. `held` keeps it
-- at full weight past the hold (a button kept down).
function ViewmodelMath.envelope(
	elapsed: number,
	time: { number },
	held: boolean?,
	anticipate: { number }?,
	overshoot: number?
): number
	local rise, hold, fall = time[1], time[2], time[3]
	if elapsed < 0 then
		return 0
	end
	local pre, dip = 0, 0
	if anticipate then
		pre, dip = anticipate[1], anticipate[2]
	end
	if elapsed < pre then
		return -dip * smooth(elapsed / math.max(pre, 1e-6))
	end
	local e = elapsed - pre
	if e < rise then
		local u = e / math.max(rise, 1e-6)
		local up = if overshoot then ViewmodelMath.easeOutBack(u, overshoot) else smooth(u)
		return -dip + (1 + dip) * up
	end
	if e < rise + hold or held then
		return 1
	end
	local f = e - rise - hold
	if f >= fall then
		return 0
	end
	return 1 - smooth(f / math.max(fall, 1e-6))
end

-- How long an action lasts (s), unless held.
function ViewmodelMath.duration(time: { number }, anticipate: { number }?): number
	return (if anticipate then anticipate[1] else 0) + time[1] + time[2] + time[3]
end

-- The viewmodel FOV factor: x / y scale that draws the hands as a camera of viewFov (vertical degrees) would,
-- under the camera's real fov. 1 when they match; > 1 when the camera is wider.
function ViewmodelMath.viewK(fovDeg: number, viewFovDeg: number): number
	return math.tan(math.rad(fovDeg) / 2) / math.tan(math.rad(viewFovDeg) / 2)
end

-- The viewmodel FOV for a rigid arm (FP HANDS v2: a skinned glove's Bones do not follow MeshPart.Size, measured, so
-- that rig is never resized). Drawing an arm k times larger at (k x, k y, z) is the same picture as drawing it at its
-- own size at (x, y, z / k): similar triangles through the eye. So each arm slides along the view axis until its
-- pivot (the hand) sits at depth z / k; every piece of the arm moves by the same amount, so nothing ever parts.
-- Returns that shift along camera Z (z is the pivot's camera-space Z, negative in front of the eye).
function ViewmodelMath.armShift(z: number, k: number): number
	if k <= 0 then
		return 0
	end
	return z / k - z
end

local function unit(x: number, y: number, z: number): (number, number, number)
	local m = math.sqrt(x * x + y * y + z * z)
	if m < 1e-12 then
		return 0, 0, 0
	end
	return x / m, y / m, z / m
end

-- Maps one part's camera-space frame through the viewmodel projection: (x, y, z) -> (k x, k y, z). comps = a
-- CFrame's 12 components { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 } (columns = the part's right, up and
-- back axes); size = its { X, Y, Z } size (only the order of its axes by length is used). Returns the new 12
-- components (orthonormal: the part's longest axis keeps its mapped direction exactly, the next is made square to
-- it) and the per-axis size factors (each axis's mapped length). k = 1 returns the frame and { 1, 1, 1 }.
function ViewmodelMath.project(comps: { number }, size: { number }, k: number): ({ number }, { number })
	local px, py, pz = comps[1] * k, comps[2] * k, comps[3]
	-- the three axes (columns) mapped by diag(k, k, 1)
	local ax = { comps[4] * k, comps[7] * k, comps[10] }
	local ay = { comps[5] * k, comps[8] * k, comps[11] }
	local az = { comps[6] * k, comps[9] * k, comps[12] }
	local axes = { ax, ay, az }
	local f = {}
	for i = 1, 3 do
		local a = axes[i]
		f[i] = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
	end
	-- Gram-Schmidt in the order of the part's sizes: the longest axis is kept, the next made square to it
	local order = { 1, 2, 3 }
	table.sort(order, function(a: number, b: number): boolean
		if size[a] == size[b] then
			return a < b
		end
		return size[a] > size[b]
	end)
	local out: { { number } } = { {}, {}, {} }
	local i1, i2, i3 = order[1], order[2], order[3]
	local a1, a2 = axes[i1], axes[i2]
	local u1x, u1y, u1z = unit(a1[1], a1[2], a1[3])
	local d = a2[1] * u1x + a2[2] * u1y + a2[3] * u1z
	local u2x, u2y, u2z = unit(a2[1] - d * u1x, a2[2] - d * u1y, a2[3] - d * u1z)
	out[i1] = { u1x, u1y, u1z }
	out[i2] = { u2x, u2y, u2z }
	-- the third axis keeps the frame right-handed: X = Y x Z, Y = Z x X, Z = X x Y
	local p, q = out[i3 % 3 + 1], out[(i3 + 1) % 3 + 1]
	out[i3] = { p[2] * q[3] - p[3] * q[2], p[3] * q[1] - p[1] * q[3], p[1] * q[2] - p[2] * q[1] }
	local X, Y, Z = out[1], out[2], out[3]
	return { px, py, pz, X[1], Y[1], Z[1], X[2], Y[2], Z[2], X[3], Y[3], Z[3] }, f
end

-- A camera-space point on the screen: x as a share of the half-width, y of the half-height (fov vertical degrees,
-- aspect = width / height). nil behind the eye.
function ViewmodelMath.ndc(x: number, y: number, z: number, fovDeg: number, aspect: number): (number?, number?)
	if z > -1e-6 then
		return nil, nil
	end
	local t = math.tan(math.rad(fovDeg) / 2)
	return x / (-z * t * aspect), y / (-z * t)
end

export type Frame = {
	t: number, -- seconds (idle breathing clock)
	bobPhase: number, -- the camera's head-bob phase (FpMath.bobStep)
	bobAmp: number, -- 0..1
	lagX: number, -- studs (look lag, from the spring)
	lagY: number,
	lagRoll: number, -- degrees
	carry: number, -- 0..1 blend into the carry pose
	hidden: number, -- 0..1 blend of the hide lower
	wall: number, -- 0..1 wall pull
	actions: { [string]: number }, -- action name -> weight (ViewmodelMath.envelope: may dip below 0 or pass 1)
	tap: number?, -- the watch tap's current travel (studs), on the right hand
	reduced: boolean?, -- reduced motion: no breathing, no bob, a quarter of the lag
	point: number?, -- 0..1: the right hand points (the onboarding look cue; ViewmodelMath.fingers)
	raise: number?, -- 0..1: the visibility blend (1 = raised; nil = raised)
	ready: number?, -- 0..1: something you can use is under the reticle (the fingers open a little)
}

-- The idle offset of the visibility mode (VISIBILITY): "lowered" sinks by LOWER, "hidden" drops by DROP, "always"
-- nothing. side "R" / "L".
function ViewmodelMath.idleOffset(cfg: any, side: string): { number }?
	local V = cfg.VISIBILITY
	if V == nil or V.MODE == "always" then
		return nil
	end
	if V.MODE == "hidden" then
		return V.DROP
	end
	return V.LOWER[side]
end

-- Both hands for a frame: right, left.
function ViewmodelMath.hands(cfg: any, f: Frame): (Pose, Pose)
	local R: Pose = table.clone(cfg.REST.R)
	local L: Pose = table.clone(cfg.REST.L)
	local lower = 1 - math.clamp(if f.raise == nil then 1 else f.raise, 0, 1)
	if lower > 0 then
		local oR, oL = ViewmodelMath.idleOffset(cfg, "R"), ViewmodelMath.idleOffset(cfg, "L")
		if oR then
			R = add(R, oR, smooth(lower))
		end
		if oL then
			L = add(L, oL, smooth(lower))
		end
	end
	if f.carry > 0 then
		R = ViewmodelMath.blend(R, cfg.CARRY.R, f.carry)
		L = ViewmodelMath.blend(L, cfg.CARRY.L, f.carry)
	end
	-- Actions in a fixed order (deterministic layering).
	for _, name in ViewmodelMath.ORDER do
		local w = f.actions[name]
		local a = cfg.ACTIONS[name]
		if w and w ~= 0 and a then
			if a.R then
				R = ViewmodelMath.blend(R, a.R, w)
			end
			if a.L then
				L = ViewmodelMath.blend(L, a.L, w)
			end
		end
	end
	local point = f.point or 0
	if point > 0 and cfg.POINT and cfg.POINT.R then
		R = ViewmodelMath.blend(R, cfg.POINT.R, point)
	end
	if f.tap and f.tap ~= 0 then
		R[3] -= f.tap -- the index taps forward onto the watch
		R[2] -= f.tap * ((cfg.ACTIONS.watch.tap or {})[3] or 0)
	end
	local reduced = f.reduced == true
	local dx, dy, droll = 0, 0, 0
	if not reduced then
		local I, W = cfg.IDLE, cfg.WALK
		local idle = 1 - math.clamp(f.bobAmp, 0, 1)
		dx += math.sin(f.t * 2 * math.pi * I.hzX) * I.x * idle
		dy += math.sin(f.t * 2 * math.pi * I.hzY) * I.y * idle
		local ph = f.bobPhase - (W.LAG or 0) -- the arms follow the head's step a little late
		dx += math.sin(ph / 2) * W.x * f.bobAmp
		dy += -math.abs(math.cos(ph)) * W.y * f.bobAmp
		droll += math.sin(ph / 2) * W.rz * f.bobAmp
	end
	local lagShare = if reduced then 0.25 else 1
	dx += f.lagX * lagShare
	dy += f.lagY * lagShare
	droll += f.lagRoll * lagShare
	local hid = cfg.HIDDEN
	local wall = cfg.WALL.PULL
	for _, h in { R, L } do
		h[1] += dx + hid[1] * f.hidden + wall[1] * f.wall
		h[2] += dy + hid[2] * f.hidden + wall[2] * f.wall
		h[3] += hid[3] * f.hidden + wall[3] * f.wall
		h[6] += droll
	end
	return R, L
end

ViewmodelMath.ORDER = table.freeze({ "stomp", "push", "press", "reach", "watch", "handsUp" })

-- Finger poses (Config ... HANDS.POSES): finger name -> { curl, spread, bend } (the thumb { curl, across }).
export type FingerPose = { [string]: { number } }
-- Joint angles: joint -> { curl, spread } (degrees; spread / across unsigned: Heist/FpRig mirrors it per side).
export type Fingers = { [string]: { number } }

local function posed(hands: any, name: string): FingerPose
	local p = hands.POSES[name] or hands.POSES[hands.REST]
	local out: FingerPose = {}
	for finger, v in p do
		out[finger] = { v[1], v[2], v[3] or 0 }
	end
	return out
end

local function blendPose(a: FingerPose, b: FingerPose, w: number): FingerPose
	w = math.clamp(w, 0, 1) -- an anticipation dip or an overshoot never folds a finger past its pose
	if w <= 0 then
		return a
	end
	local out: FingerPose = {}
	for finger, v in a do
		local t = b[finger] or v
		out[finger] = { v[1] + (t[1] - v[1]) * w, v[2] + (t[2] - v[2]) * w, v[3] + (t[3] - v[3]) * w }
	end
	return out
end

local NAMES = { index = "Index", middle = "Middle", ring = "Ring", pinky = "Pinky", thumb = "Thumb" }

-- One hand's finger pose as joint angles: Index1..3, Middle1..3, Ring1..3, Pinky1..3, Thumb1..3 (curl by CHAIN /
-- THUMB_CHAIN, `bend` added to the 2nd and 3rd joints, the spread on the base joint only, the thumb's across on its
-- base), plus the old keys for the placeholder and the Rookie_Hands fallback (Index1/2, Fingers1/2 = the middle
-- finger's, Thumb1/2).
function ViewmodelMath.joints(hands: any, pose: FingerPose): Fingers
	local out: Fingers = {}
	for finger, v in pose do
		local base = NAMES[finger]
		if base then
			local chain = if finger == "thumb" then hands.THUMB_CHAIN else hands.CHAIN
			for i = 1, 3 do
				local curl = v[1] * chain[i] + (if i > 1 and finger ~= "thumb" then v[3] else 0)
				out[base .. i] = { curl, if i == 1 then v[2] else 0 }
			end
		end
	end
	if out.Middle1 then
		out.Fingers1 = { out.Middle1[1], 0 }
		out.Fingers2 = { out.Middle2[1], 0 }
	end
	return out
end

-- The finger targets of both hands (fp_hands.md rule 17), layered like ViewmodelMath.hands: the rest pose, the
-- look-target READY by f.ready, the carry grip by the carry blend, each action's pose by its weight (same order,
-- clamped 0..1), then the look-cue point (f.point) on the right hand. cfg = Config.FirstPerson.VIEWMODEL.
function ViewmodelMath.fingers(cfg: any, f: Frame): (Fingers, Fingers)
	local H = cfg.HANDS
	local R, L = posed(H, H.REST), posed(H, H.REST)
	local ready = f.ready or 0
	if ready > 0 and H.READY then
		R = blendPose(R, posed(H, H.READY), ready)
		L = blendPose(L, posed(H, H.READY), ready * 0.5)
	end
	if f.carry > 0 then
		R = blendPose(R, posed(H, H.CARRY), f.carry)
		L = blendPose(L, posed(H, H.CARRY), f.carry)
	end
	for _, name in ViewmodelMath.ORDER do
		local w = f.actions[name]
		local a = H.ACTIONS[name]
		if w and w > 0 and a then
			if a.R then
				R = blendPose(R, posed(H, a.R), w)
			end
			if a.L then
				L = blendPose(L, posed(H, a.L), w)
			end
		end
	end
	local point = f.point or 0
	if point > 0 then
		R = blendPose(R, posed(H, H.POINT), point)
	end
	return ViewmodelMath.joints(H, R), ViewmodelMath.joints(H, L)
end

-- The look-lag target for a turn speed (degrees a second, yaw and pitch): the hands trail the turn, clamped.
-- Turning right (yaw speed < 0) leaves the hands to the left, and rolls them a little. `scale` (carrying) trails
-- further.
function ViewmodelMath.lagTarget(
	yawSpeed: number,
	pitchSpeed: number,
	lag: any,
	scale: number?
): (number, number, number)
	local s = scale or 1
	local x = math.clamp(yawSpeed * lag.PER_DEG_S * s, -lag.MAX * s, lag.MAX * s)
	local y = math.clamp(pitchSpeed * lag.PER_DEG_S * s, -lag.MAX * s, lag.MAX * s)
	local roll = math.clamp(yawSpeed * lag.ROLL_PER_DEG_S, -lag.MAX_ROLL, lag.MAX_ROLL)
	return x, y, roll
end

-- The wall pull for the distance to a wall straight ahead (studs), 0 beyond `range`, 1 at the eye.
function ViewmodelMath.wallPull(distance: number?, range: number): number
	if distance == nil or distance >= range then
		return 0
	end
	return math.clamp(1 - distance / math.max(range, 1e-6), 0, 1)
end

-- The uniform scale that fits a loot item's longest side (full-size studs) to `size`, at the viewmodel scale.
function ViewmodelMath.lootScale(longest: number, size: number, vmScale: number): number
	return size / math.max(longest, 1e-3) * vmScale
end

-- Where a forearm aims (full size, viewmodel camera space): the off-screen elbow ARMS.ELBOW[key], carried along by
-- ARMS.ELBOW_FOLLOW of the hand's move from its rest (a reach takes the elbow forward too, so the visible sleeve
-- keeps a forearm's length instead of stretching into a pole). key "R" / "L", pose = that hand's pose.
function ViewmodelMath.elbow(cfg: any, key: string, pose: Pose): { number }
	local A = cfg.ARMS
	local e, rest = A.ELBOW[key], cfg.REST[key]
	local k = A.ELBOW_FOLLOW or 0
	return { e[1] + (pose[1] - rest[1]) * k, e[2] + (pose[2] - rest[2]) * k, e[3] + (pose[3] - rest[3]) * k }
end

-- An action's weight at its most extended moment (the overshoot's top when it has one).
function ViewmodelMath.peak(cfg: any, name: string): number
	local a = cfg.ACTIONS[name]
	local best = 0
	for i = 0, 400 do
		best = math.max(best, ViewmodelMath.envelope(i / 400, a.time, false, a.anticipate, a.overshoot))
	end
	return best
end

-- The showcase poses every check and the Blender preview use (fp_hands.md): { name, Frame } with the springs
-- settled on their targets: idle (lowered), a look target, the walk bob's top and bottom, the reach and push at
-- their overshoot, carrying, the press, the onboarding point, the REWIND watch tap, hands up, the plate stomp.
function ViewmodelMath.showcase(cfg: any): { { any } }
	local function frame(spec: any): Frame
		return {
			t = 0,
			bobPhase = spec.bobPhase or 0,
			bobAmp = spec.bobAmp or 0,
			lagX = spec.lagX or 0,
			lagY = 0,
			lagRoll = 0,
			carry = spec.carry or 0,
			hidden = 0,
			wall = spec.wall or 0,
			actions = spec.actions or {},
			tap = spec.tap,
			reduced = false,
			point = spec.point or 0,
			raise = spec.raise or 0,
			ready = spec.ready or 0,
		}
	end
	local lag = (cfg.WALK and cfg.WALK.LAG) or 0
	local P = ViewmodelMath.peak
	return {
		{ "idle", frame({}) },
		{ "ready", frame({ raise = 1, ready = 1 }) },
		{ "walkUp", frame({ bobPhase = math.pi / 2 + lag, bobAmp = 1 }) },
		{ "walkDown", frame({ bobPhase = math.pi + lag, bobAmp = 1 }) },
		{ "reach", frame({ raise = 1, actions = { reach = P(cfg, "reach") } }) },
		{ "carry", frame({ raise = 1, carry = 1 }) },
		{ "push", frame({ raise = 1, actions = { push = P(cfg, "push") } }) },
		{ "press", frame({ raise = 1, actions = { press = P(cfg, "press") } }) },
		{ "point", frame({ raise = 1, point = 1 }) },
		{ "watch", frame({ raise = 1, actions = { watch = 1 }, tap = cfg.ACTIONS.watch.tap[1] }) },
		{ "handsUp", frame({ raise = 1, actions = { handsUp = 1 } }) },
		{ "stomp", frame({ raise = 1, actions = { stomp = 1 } }) },
		{ "lag", frame({ raise = 1, lagX = cfg.LAG.MAX * cfg.LAG.CARRY_SCALE }) },
	}
end

-- The visibility blend's target (1 = raised) for a frame's reasons, with the lower delay: `since` = seconds since
-- the last reason to raise (0 while one holds). MODE "always" is always raised.
function ViewmodelMath.raiseTarget(cfg: any, since: number): number
	local V = cfg.VISIBILITY
	if V == nil or V.MODE == "always" then
		return 1
	end
	return if since <= V.LOWER_DELAY then 1 else 0
end

return table.freeze(ViewmodelMath)
