--!strict
-- Heist/FpMath: the pure maths of first person (PLAN_FIRST_PERSON FP): the camera's look, head bob and
-- landing dip (Heist/CameraDirector "fp"), the look-to-interact target pick with its aim-assist cone
-- (Heist/LookTarget) and the springs the viewmodel uses (Heist/ViewmodelMath). Free of engine types and
-- requires so Lune tests it (tests/unit/HeistFirstPerson.spec.luau). Vectors are plain { x, y, z } triples,
-- angles are degrees, pitch is degrees DOWN (CameraMath's convention: yaw 0 looks down -Z).
--
-- Determinism: pick() orders candidates by score, then by id, and reads nothing but its arguments, so the
-- same view picks the same target on every machine (the server still decides: Sim/Interact).

local FpMath = {}

export type V3 = { number }

local rad, deg = math.rad, math.deg

local function dot(a: V3, b: V3): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function sub(a: V3, b: V3): V3
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function len(a: V3): number
	return math.sqrt(dot(a, a))
end

FpMath.dot = dot
FpMath.sub = sub
FpMath.len = len

-- Unit view direction for a yaw and a downward pitch.
function FpMath.look(yawDeg: number, pitchDeg: number): V3
	local y, p = rad(yawDeg), rad(pitchDeg)
	local c = math.cos(p)
	return { -math.sin(y) * c, -math.sin(p), -math.cos(y) * c }
end

-- Wraps an angle to (-180, 180].
function FpMath.wrap(a: number): number
	local w = (a + 180) % 360 - 180
	return if w == -180 then 180 else w
end

-- Yaw and downward pitch of a direction.
function FpMath.angles(dir: V3): (number, number)
	local h = math.sqrt(dir[1] * dir[1] + dir[3] * dir[3])
	return deg(math.atan2(-dir[1], -dir[3])), deg(math.atan2(-dir[2], h))
end

-- A look turn: dx / dy are input units (pixels, or stick-seconds), `per` degrees per unit. Moving right
-- turns right (yaw decreases), moving down looks down. Pitch is clamped, yaw wrapped.
function FpMath.turn(
	yaw: number,
	pitch: number,
	dx: number,
	dy: number,
	perX: number,
	perY: number,
	pitchMin: number,
	pitchMax: number
): (number, number)
	return FpMath.wrap(yaw - dx * perX), math.clamp(pitch + dy * perY, pitchMin, pitchMax)
end

-- Stick response: dead zone removed (rescaled so the edge is still 1), then a power curve; keeps the sign.
function FpMath.stick(v: number, deadzone: number, exponent: number): number
	local a = math.abs(v)
	if a <= deadzone then
		return 0
	end
	local u = math.clamp((a - deadzone) / math.max(1 - deadzone, 1e-6), 0, 1)
	return (if v < 0 then -1 else 1) * u ^ exponent
end

-- Exponential follow share (frame-rate independent).
function FpMath.damp(rate: number, dt: number): number
	return 1 - math.exp(-rate * math.max(dt, 0))
end

-- Head bob. `phase` advances by pi per step (STRIDE studs) at the walking speed; `amp` (0..1) follows
-- speed / FULL_SPEED at SETTLE_RATE. Returns the new phase and amplitude.
function FpMath.bobStep(phase: number, amp: number, dt: number, speed: number, cfg: any): (number, number)
	local want = math.clamp(speed / math.max(cfg.FULL_SPEED, 1e-6), 0, 1)
	local a = amp + (want - amp) * FpMath.damp(cfg.SETTLE_RATE, dt)
	local p = phase + math.pi * speed * dt / math.max(cfg.STRIDE, 1e-6)
	return p % (4 * math.pi), a
end

-- The bob offset in camera space (x right, y up): a dip on every step, a sway every other step.
function FpMath.bobOffset(phase: number, amp: number, cfg: any): (number, number)
	local y = -math.abs(math.sin(phase)) * cfg.Y * amp + cfg.Y * amp * 0.5 -- centred: the eye's mean height holds
	local x = math.sin(phase / 2) * cfg.X * amp
	return x, y
end

-- A damped spring toward `target` (frequency hz, damping ratio zeta), stepped in small sub-steps so a long
-- frame never explodes. Returns the new position and velocity.
function FpMath.spring(x: number, v: number, target: number, dt: number, hz: number, zeta: number): (number, number)
	local w = 2 * math.pi * hz
	local steps = math.max(1, math.ceil(math.max(dt, 0) / (1 / 120)))
	local h = math.max(dt, 0) / steps
	for _ = 1, steps do
		local a = -w * w * (x - target) - 2 * zeta * w * v
		v += a * h
		x += v * h
	end
	return x, v
end

-- The landing kick for a fall speed (studs/s, positive down): a downward velocity for FpMath.spring whose
-- dip peaks at about (fall - MIN_FALL) * PER_SPEED studs, capped at MAX. 0 for a soft landing.
function FpMath.landKick(fall: number, cfg: any): number
	if fall <= cfg.MIN_FALL then
		return 0
	end
	local depth = math.min((fall - cfg.MIN_FALL) * cfg.PER_SPEED, cfg.MAX)
	return -depth * 2 * math.pi * cfg.FREQ
end

-- The eye: the root, up by the (smoothed) head height plus EYE_UP, forward by EYE_FORWARD along the yaw.
function FpMath.eye(root: V3, headDy: number, yawDeg: number, cfg: any): V3
	local y = rad(yawDeg)
	local f = cfg.EYE_FORWARD
	return { root[1] - math.sin(y) * f, root[2] + headDy + cfg.EYE_UP, root[3] - math.cos(y) * f }
end

-- How far (degrees) a target sphere is off the view ray, beyond its own angular radius (0 = the centre ray
-- passes through it), and its distance. Behind the eye: math.huge.
function FpMath.offAngle(eye: V3, dir: V3, pos: V3, radius: number): (number, number)
	local to = sub(pos, eye)
	local d = len(to)
	if d < 1e-6 then
		return 0, 0
	end
	local c = math.clamp(dot(dir, to) / (d * math.max(len(dir), 1e-9)), -1, 1)
	if c <= 0 then
		return math.huge, d
	end
	local ang = deg(math.acos(c))
	local own = if radius >= d then 90 else deg(math.asin(radius / d))
	return math.max(0, ang - own), d
end

export type Candidate = {
	id: any, -- stable id (kind .. index): the tie-break
	pos: V3, -- target centre
	radius: number,
	ok: boolean?, -- false: shown to nobody (the sim would refuse it: out of the server's range)
}

export type PickOptions = {
	reach: number, -- studs from the eye
	assist: number, -- degrees beyond a target's own size that still count
	distanceWeight: number,
	sticky: number, -- score bonus for `current`
	current: any?, -- the id picked last frame
	losCandidates: number?, -- line-of-sight checks for at most this many of the best
	blocked: ((eye: V3, c: Candidate) -> boolean)?, -- true: something is in the way
}

-- The score of a candidate (lower is better), or nil when it cannot be picked: out of reach, outside the
-- assist cone, or refused by the sim's own range.
function FpMath.score(eye: V3, dir: V3, c: Candidate, o: PickOptions): number?
	if c.ok == false then
		return nil
	end
	local off, d = FpMath.offAngle(eye, dir, c.pos, c.radius)
	if d - c.radius > o.reach or off > o.assist then
		return nil
	end
	local s = off / math.max(o.assist, 1e-6) + o.distanceWeight * d / math.max(o.reach, 1e-6)
	if o.current ~= nil and c.id == o.current then
		s -= o.sticky
	end
	return s
end

-- The looked-at target: the best-scored candidate that is in reach, inside the cone and not blocked. Returns
-- its index in `list` (or nil) and its score. Ties go to the lower id (tostring order): deterministic.
function FpMath.pick(eye: V3, dir: V3, list: { Candidate }, o: PickOptions): (number?, number)
	local ranked: { { i: number, s: number, id: string } } = {}
	for i, c in list do
		local s = FpMath.score(eye, dir, c, o)
		if s then
			table.insert(ranked, { i = i, s = s, id = tostring(c.id) })
		end
	end
	table.sort(ranked, function(a, b)
		if a.s ~= b.s then
			return a.s < b.s
		end
		return a.id < b.id
	end)
	local checks = o.losCandidates or #ranked
	for k, r in ranked do
		if k > checks then
			break
		end
		if not (o.blocked and o.blocked(eye, list[r.i])) then
			return r.i, r.s
		end
	end
	return nil, math.huge
end

-- The server's own range rule (Sim/Interact inRange: horizontal and vertical from your sim position), less a
-- margin, so the client never offers a target the server would refuse for range.
function FpMath.inSimRange(actor: V3, target: V3, range: number, height: number, margin: number): boolean
	local dx, dz = target[1] - actor[1], target[3] - actor[3]
	local r = math.max(range - margin, 0)
	return dx * dx + dz * dz <= r * r and math.abs(target[2] - actor[2]) <= height
end

-- C1 in first person: the blend from the objective shot to the eye (0 = objective, 1 = you), cubic in-out.
function FpMath.ease(u: number): number
	u = math.clamp(u, 0, 1)
	return if u < 0.5 then 4 * u * u * u else 1 - (-2 * u + 2) ^ 3 / 2
end

-- A glance (the plate stomp): 0 -> 1 -> 0 over `seconds`, a smooth sine hump.
function FpMath.glance(elapsed: number, seconds: number): number
	if elapsed <= 0 or elapsed >= seconds or seconds <= 0 then
		return 0
	end
	return math.sin(math.pi * elapsed / seconds)
end

-- Gus's screen-edge warning (Heist/FpWarn): how strong each edge (left, right, top, bottom) is for a threat
-- at `relDeg` from where you look (FpMath.wrap(threatYaw - lookYaw): positive is to your left, 180 behind).
-- The side he is on is strongest; every edge keeps at least `sideMin`, so a cone on you is always felt.
function FpMath.edgeWeights(relDeg: number, sideMin: number): (number, number, number, number)
	local r = rad(relDeg)
	local s, c = math.sin(r), math.cos(r)
	local function w(v: number): number
		return sideMin + (1 - sideMin) * math.clamp(v, 0, 1)
	end
	return w(s), w(-s), w(c), w(-c)
end

-- The strength an edge tint eases toward over time: up over `inS`, down over `outS` (linear, 0..1 a second).
function FpMath.approach(current: number, target: number, dt: number, inS: number, outS: number): number
	if target > current then
		return math.min(target, current + dt / math.max(inS, 1e-6))
	end
	return math.max(target, current - dt / math.max(outS, 1e-6))
end

return table.freeze(FpMath)
