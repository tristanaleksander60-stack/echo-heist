--!strict
-- Shared/Heist/ScarfMath: the long scarf's swaying tail (PLAN_FIRST_PERSON "CH"; the Rookie's two-segment tail,
-- Rookie_Scarf_Long_Tail1 / _Tail2). Pure: no engine calls, so tests/unit/HeistScarf.spec.luau checks it in Lune;
-- the client Heist/ScarfSway feeds it each character's motion and writes the result into the tail's welds.
--
-- The tail is modelled streaming out behind (the running pose). Standing still it hangs (DROOP); the faster you
-- move the closer it comes to the modelled pose; a strafe or a turn swings it the other way; a fall lifts it, a
-- jump drops it; while you move its end flutters. Each angle follows its target on a damped spring, so a stop or
-- a turn makes it swing and settle. Angles are degrees in the torso's frame (the Rookie faces -Z):
--   pitch: about the torso's X axis, + swings the tail down (the hang);
--   yaw:   about the torso's Y axis, + swings the tail toward the Rookie's right (+X).
--
--   ScarfMath.new() -> state                     { p1, y1, p2, y2 and their velocities, t }
--   ScarfMath.target(motion, t, cfg) -> p1, y1, p2, y2
--   ScarfMath.step(state, motion, dt, cfg)       advance (sub-stepped: stable at any frame time)
--   ScarfMath.rest(state)                        back to the modelled pose (no sway)
-- motion = { forward, right, up: studs/s in the torso's frame (forward = -Z), turn: rad/s (+ = turning left) }

local ScarfMath = {}

export type State = {
	p1: number,
	y1: number,
	p2: number,
	y2: number,
	vp1: number,
	vy1: number,
	vp2: number,
	vy2: number,
	t: number,
}

export type Motion = { forward: number, right: number, up: number, turn: number }

function ScarfMath.new(): State
	return { p1 = 0, y1 = 0, p2 = 0, y2 = 0, vp1 = 0, vy1 = 0, vp2 = 0, vy2 = 0, t = 0 }
end

-- The pose each angle is pulled toward for this motion at time t (seconds; drives the flutter).
function ScarfMath.target(m: Motion, t: number, cfg: any): (number, number, number, number)
	local speed = math.sqrt(m.forward * m.forward + m.right * m.right)
	local lift = math.clamp(speed / cfg.RUN_SPEED, 0, 1)
	-- hanging at rest, streaming out at full speed; a fall lifts it (wind from below), a jump drops it
	local p1 = cfg.DROOP * (1 - lift) + math.clamp(m.up * cfg.VERTICAL, -cfg.VERTICAL_MAX, cfg.VERTICAL_MAX)
	-- a strafe right swings it left; a turn leaves it behind (to the outside of the turn)
	local y1 = math.clamp(-m.right * cfg.LATERAL - m.turn * cfg.TURN, -cfg.YAW_MAX, cfg.YAW_MAX)
	-- the end segment hangs a little more at rest and flutters while you move
	local w = 2 * math.pi * cfg.FLUTTER_HZ * t
	local flutter = cfg.FLUTTER * lift
	local p2 = cfg.DROOP2 * (1 - lift) + flutter * math.sin(w)
	local y2 = y1 * cfg.FOLLOW + flutter * 0.8 * math.sin(w * 1.37 + 1.1)
	return math.clamp(p1, cfg.PITCH_MIN, cfg.PITCH_MAX), y1, p2, y2
end

-- One damped-spring step toward a target (semi-implicit Euler; dt is kept small by step()).
local function spring(x: number, v: number, goal: number, k: number, c: number, dt: number): (number, number)
	v += (k * (goal - x) - c * v) * dt
	return x + v * dt, v
end

function ScarfMath.step(s: State, m: Motion, dt: number, cfg: any)
	local left = math.clamp(dt, 0, cfg.MAX_DT)
	local k1, c1 = cfg.STIFFNESS, cfg.DAMPING
	local k2, c2 = cfg.STIFFNESS * cfg.END_STIFFNESS, cfg.DAMPING * math.sqrt(cfg.END_STIFFNESS)
	while left > 1e-6 do
		local h = math.min(left, cfg.SUBSTEP)
		left -= h
		s.t += h
		local p1, y1, p2, y2 = ScarfMath.target(m, s.t, cfg)
		s.p1, s.vp1 = spring(s.p1, s.vp1, p1, k1, c1, h)
		s.y1, s.vy1 = spring(s.y1, s.vy1, y1, k1, c1, h)
		s.p2, s.vp2 = spring(s.p2, s.vp2, p2, k2, c2, h)
		s.y2, s.vy2 = spring(s.y2, s.vy2, y2, k2, c2, h)
	end
end

-- Back to the modelled pose at once (a tier switch turns the sway off).
function ScarfMath.rest(s: State)
	s.p1, s.y1, s.p2, s.y2 = 0, 0, 0, 0
	s.vp1, s.vy1, s.vp2, s.vy2 = 0, 0, 0, 0
end

-- A starting state already hanging for this motion (a character first seen standing does not swing in).
function ScarfMath.settled(m: Motion, cfg: any): State
	local s = ScarfMath.new()
	s.p1, s.y1, s.p2, s.y2 = ScarfMath.target(m, 0, cfg)
	return s
end

return table.freeze(ScarfMath)
