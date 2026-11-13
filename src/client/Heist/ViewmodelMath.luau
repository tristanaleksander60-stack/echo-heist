--!strict
-- Heist/ViewmodelMath: the pure pose maths of the first-person hands (Heist/Viewmodel, PLAN_FIRST_PERSON FP).
-- Lune-tested (tests/unit/HeistFirstPerson.spec.luau). A hand pose is { x, y, z, rx, ry, rz }: camera space at
-- full size (x right, y up, -z forward; studs) and degrees (pitch, yaw, roll), as in Config.FirstPerson.VIEWMODEL.
--
-- One frame of hands = the rest pose (or the carry pose), each playing action blended over it by its envelope
-- (rise, hold, fall), then the layers that never stop: idle breathing, the walk bob (in phase with the camera's
-- head bob), the look lag (a spring that trails how fast you turn), the hide lower and the wall pull. Every
-- layer is a plain sum, so an action never pops: its weight eases in and out.

local ViewmodelMath = {}

export type Pose = { number } -- { x, y, z, rx, ry, rz }

-- Linear blend of two poses (w = 0 -> a, 1 -> b).
function ViewmodelMath.blend(a: Pose, b: Pose, w: number): Pose
	local out = table.create(6)
	for k = 1, 6 do
		out[k] = a[k] + (b[k] - a[k]) * w
	end
	return out
end

-- Smoothstep 0..1.
local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- An action's weight `elapsed` seconds after it started: rises over time[1], holds time[2], falls over
-- time[3]; 0 before and after. `held` keeps it at full weight past the hold (a button kept down).
function ViewmodelMath.envelope(elapsed: number, time: { number }, held: boolean?): number
	local rise, hold, fall = time[1], time[2], time[3]
	if elapsed < 0 then
		return 0
	end
	if elapsed < rise then
		return smooth(elapsed / math.max(rise, 1e-6))
	end
	if elapsed < rise + hold or held then
		return 1
	end
	local f = elapsed - rise - hold
	if f >= fall then
		return 0
	end
	return 1 - smooth(f / math.max(fall, 1e-6))
end

-- How long an action lasts (s), unless held.
function ViewmodelMath.duration(time: { number }): number
	return time[1] + time[2] + time[3]
end

-- x / y scale that keeps a hand at the same screen spot at another FOV (poses are authored at fovRef).
function ViewmodelMath.fovFit(fovDeg: number, fovRef: number): number
	return math.tan(math.rad(fovDeg) / 2) / math.tan(math.rad(fovRef) / 2)
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
	actions: { [string]: number }, -- action name -> weight 0..1 (ViewmodelMath.envelope)
	tap: number?, -- the watch tap's current travel (studs), on the right hand
	reduced: boolean?, -- reduced motion: no breathing, no bob, a quarter of the lag
	point: number?, -- 0..1: the right hand points (the onboarding look cue; ViewmodelMath.fingers)
}

-- Both hands for a frame: right, left.
function ViewmodelMath.hands(cfg: any, f: Frame): (Pose, Pose)
	local R: Pose = table.clone(cfg.REST.R)
	local L: Pose = table.clone(cfg.REST.L)
	if f.carry > 0 then
		R = ViewmodelMath.blend(R, cfg.CARRY.R, f.carry)
		L = ViewmodelMath.blend(L, cfg.CARRY.L, f.carry)
	end
	-- Actions in a fixed order (deterministic layering).
	for _, name in ViewmodelMath.ORDER do
		local w = f.actions[name]
		local a = cfg.ACTIONS[name]
		if w and w > 0 and a then
			if a.R then
				R = ViewmodelMath.blend(R, a.R, w)
			end
			if a.L then
				L = ViewmodelMath.blend(L, a.L, w)
			end
		end
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
		dx += math.sin(f.bobPhase / 2) * W.x * f.bobAmp
		dy += -math.abs(math.cos(f.bobPhase)) * W.y * f.bobAmp
		droll += math.sin(f.bobPhase / 2) * W.rz * f.bobAmp
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

export type Fingers = { [string]: { number } } -- joint -> { curl, across } (degrees)

local function blendFingers(a: Fingers, b: Fingers, w: number): Fingers
	if w <= 0 then
		return a
	end
	local out: Fingers = {}
	for joint, v in a do
		local t = b[joint] or v
		out[joint] = { v[1] + (t[1] - v[1]) * w, v[2] + (t[2] - v[2]) * w }
	end
	return out
end

local function pose(hands: any, name: string): Fingers
	local p = hands.POSES[name] or hands.POSES[hands.REST]
	local out: Fingers = {}
	for joint, v in p do
		out[joint] = { v[1], v[2] }
	end
	return out
end

-- The finger targets of both hands (REVIEW_STEAM_PLUS #10), layered like ViewmodelMath.hands: the rest pose, the
-- carry grip by the carry blend, each action's pose by its weight (same order), then the look-cue point (f.point,
-- 0..1) on the right hand. cfg = Config.FirstPerson.VIEWMODEL.
function ViewmodelMath.fingers(cfg: any, f: Frame): (Fingers, Fingers)
	local H = cfg.HANDS
	local R, L = pose(H, H.REST), pose(H, H.REST)
	if f.carry > 0 then
		R = blendFingers(R, pose(H, H.CARRY), f.carry)
		L = blendFingers(L, pose(H, H.CARRY), f.carry)
	end
	for _, name in ViewmodelMath.ORDER do
		local w = f.actions[name]
		local a = H.ACTIONS[name]
		if w and w > 0 and a then
			if a.R then
				R = blendFingers(R, pose(H, a.R), w)
			end
			if a.L then
				L = blendFingers(L, pose(H, a.L), w)
			end
		end
	end
	local point = f.point or 0
	if point > 0 then
		R = blendFingers(R, pose(H, H.POINT), point)
	end
	return R, L
end

-- The look-lag target for a turn speed (degrees a second, yaw and pitch): the hands trail the turn, clamped.
-- Turning right (yaw speed < 0) leaves the hands to the left, and rolls them a little.
function ViewmodelMath.lagTarget(yawSpeed: number, pitchSpeed: number, lag: any): (number, number, number)
	local x = math.clamp(yawSpeed * lag.PER_DEG_S, -lag.MAX, lag.MAX)
	local y = math.clamp(pitchSpeed * lag.PER_DEG_S, -lag.MAX, lag.MAX)
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

return table.freeze(ViewmodelMath)
