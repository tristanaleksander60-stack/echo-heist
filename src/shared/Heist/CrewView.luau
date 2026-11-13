--!strict
-- Heist/CrewView: the pure maths of the Crew View peek (docs/audit/REVIEW_STEAM_PLUS.md gap 5; numbers in
-- Config.Heist.CAMERA.CREW). In first person you see walls, not the choreography: hold Q / LB / the touch CREW
-- button and Heist/CameraDirector lifts the camera from your eyes to an overhead diorama shot centred on you that
-- frames your clones and the objective; release drops back to your eyes. Pure (no engine calls), so
-- tests/unit/HeistCrewView.spec.luau checks it in Lune and the client uses the same functions.
--
--   allowed(gate)            may Crew View run now? (a run in first person, no presentation moment, no rewind,
--                            no sheet up, alive) -> ok, reason
--   newHold / step / cancel  the hold: a weight 0..1 that rises over IN_SECONDS while held and falls over
--                            OUT_SECONDS on release; reduced motion holds the old view, then cuts at CUT_AT
--   weight(hold)             the eased blend the camera uses (0 = your eyes, 1 = the crew shot)
--   veil(hold, reduced, cfg) reduced motion's quick dim crossfade (0 = clear .. PEAK at the cut)
--   frame(you, points, yaw, aspect, cfg) -> focus, distance, framed: the shot centred on you that keeps the
--                            framed points (within RADIUS of you) inside SHARE / SHARE_Y of the frame
--   orbit / project          the diorama's camera maths (Heist/CameraMath's conventions: yaw 0 looks down -Z,
--                            pitch is degrees down, the camera never rolls)
--   hintDue                  the one-time "Hold Q to see your crew." line
-- Vectors are plain { x, y, z } triples.

local CrewView = {}

export type V3 = { number }
export type Gate = {
	where: string?, -- "heist" | "garage" | ...
	phase: string?, -- "Run" | "Between" | ...
	mode: string?, -- the camera mode: "fp" | "diorama" | "classic"
	presenting: boolean?, -- a presentation shot holds the camera (8 OF ME, busted, Line-up, level intro, beat)
	rewinding: boolean?, -- the rewind finish plays (Heist/RewindDirector)
	sheet: boolean?, -- a HUD sheet or panel is up
	alive: boolean?, -- your character lives (nil: unknown, counts as alive)
}
export type Hold = { w: number, target: number, from: number, t: number }

local rad = math.rad

-- Whether Crew View may run, and why not ("ok" when it may). Order: where you are, then the phase, the camera
-- mode, a presentation moment, the rewind, a sheet, your character.
function CrewView.allowed(g: Gate): (boolean, string)
	if g.where ~= "heist" then
		return false, "lobby"
	end
	if g.phase ~= "Run" then
		return false, "phase"
	end
	if g.mode ~= "fp" then
		return false, "mode"
	end
	if g.presenting == true then
		return false, "presenting"
	end
	if g.rewinding == true then
		return false, "rewind"
	end
	if g.sheet == true then
		return false, "sheet"
	end
	if g.alive == false then
		return false, "dead"
	end
	return true, "ok"
end

function CrewView.newHold(): Hold
	return { w = 0, target = 0, from = 0, t = 0 }
end

-- Advances the hold by dt with the button `held`. Smooth: the weight moves toward the target at a constant rate
-- (a full lift takes IN_SECONDS, a full drop OUT_SECONDS). Reduced motion: the weight keeps its value until
-- REDUCED.CUT_AT after a change, then snaps (the veil hides the cut). Mutates and returns `h`.
function CrewView.step(h: Hold, held: boolean, dt: number, reduced: boolean, cfg: any): Hold
	local target = if held then 1 else 0
	if target ~= h.target then
		h.target = target
		h.from = h.w
		h.t = 0
	end
	h.t += math.max(dt, 0)
	if reduced then
		if h.t >= cfg.REDUCED.CUT_AT then
			h.w = h.target
		end
		return h
	end
	if h.w < h.target then
		h.w = if cfg.IN_SECONDS > 0 then math.min(h.target, h.w + dt / cfg.IN_SECONDS) else h.target
	elseif h.w > h.target then
		h.w = if cfg.OUT_SECONDS > 0 then math.max(h.target, h.w - dt / cfg.OUT_SECONDS) else h.target
	end
	return h
end

-- Drops Crew View at once (a presentation moment takes the frame, the run ends): no ease, no veil.
function CrewView.cancel(h: Hold)
	h.w, h.target, h.from = 0, 0, 0
	h.t = math.huge
end

-- True while the camera is anywhere but your eyes, or about to leave them.
function CrewView.active(h: Hold): boolean
	return h.w > 0 or h.target > 0
end

-- Smoothstep on 0..1: eases in and out, so the lift starts and lands gently.
function CrewView.ease(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- The camera blend this frame: 0 = your eyes, 1 = the crew shot.
function CrewView.weight(h: Hold): number
	return CrewView.ease(h.w)
end

-- Reduced motion's crossfade veil (0 = clear .. REDUCED.PEAK): it rises to the cut, then fades. Without reduced
-- motion there is no veil.
function CrewView.veil(h: Hold, reduced: boolean, cfg: any): number
	if not reduced or h.t == math.huge then
		return 0
	end
	local R = cfg.REDUCED
	if h.t < R.CUT_AT then
		-- only a real change veils (the very first frames of a hold that started from rest)
		if h.from == h.target then
			return 0
		end
		return R.PEAK * h.t / math.max(R.CUT_AT, 1e-6)
	end
	local u = (h.t - R.CUT_AT) / math.max(R.OUT, 1e-6)
	return if u >= 1 then 0 else R.PEAK * (1 - u)
end

---------------------------------------------------------------------------
-- The shot
---------------------------------------------------------------------------

-- Unit view direction for a yaw and a downward pitch (degrees).
function CrewView.look(yawDeg: number, pitchDeg: number): V3
	local y, p = rad(yawDeg), rad(pitchDeg)
	local c = math.cos(p)
	return { -math.sin(y) * c, -math.sin(p), -math.cos(y) * c }
end

-- Camera position for a focus, yaw, pitch and distance, and the point it looks at (the focus).
function CrewView.orbit(focus: V3, yawDeg: number, pitchDeg: number, distance: number): (V3, V3)
	local d = CrewView.look(yawDeg, pitchDeg)
	return { focus[1] - d[1] * distance, focus[2] - d[2] * distance, focus[3] - d[3] * distance },
		{ focus[1], focus[2], focus[3] }
end

-- A point in normalised screen space (-1..1 both ways, +y up) for a camera at `pos` with a view yaw and pitch;
-- returns x, y and the depth along the view (<= 0: behind the camera).
function CrewView.project(
	pos: V3,
	yawDeg: number,
	pitchDeg: number,
	point: V3,
	fovDeg: number,
	aspect: number
): (number, number, number)
	local f = CrewView.look(yawDeg, pitchDeg)
	local yr = rad(yawDeg)
	local right = { math.cos(yr), 0, -math.sin(yr) }
	local up = {
		right[2] * f[3] - right[3] * f[2],
		right[3] * f[1] - right[1] * f[3],
		right[1] * f[2] - right[2] * f[1],
	}
	local d = { point[1] - pos[1], point[2] - pos[2], point[3] - pos[3] }
	local depth = d[1] * f[1] + d[2] * f[2] + d[3] * f[3]
	if depth <= 1e-6 then
		return 0, 0, depth
	end
	local x = d[1] * right[1] + d[2] * right[2] + d[3] * right[3]
	local y = d[1] * up[1] + d[2] * up[2] + d[3] * up[3]
	local tv = math.tan(rad(fovDeg) / 2)
	return x / (depth * tv * aspect), y / (depth * tv), depth
end

-- The framed points' screen extent from a focus at distance d: the middle (x, y) and whether all fit.
local function extent(focus: V3, pts: { V3 }, yaw: number, d: number, aspect: number, cfg: any): (number, number, boolean)
	local pos = CrewView.orbit(focus, yaw, cfg.PITCH, d)
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	local ok = true
	for _, p in pts do
		local nx, ny, depth = CrewView.project(pos, yaw, cfg.PITCH, p, cfg.FOV, aspect)
		if depth <= 0.1 then
			return 0, 0, false
		end
		x0, x1 = math.min(x0, nx), math.max(x1, nx)
		y0, y1 = math.min(y0, ny), math.max(y1, ny)
		if math.abs(nx) > cfg.SHARE or math.abs(ny) > cfg.SHARE_Y then
			ok = false
		end
	end
	return (x0 + x1) / 2, (y0 + y1) / 2, ok
end

-- Slides the focus over the floor so the framed points sit in the middle of the frame at distance d (perspective
-- makes the near side spread more than the far side; a few passes settle it). Returns the focus and whether every
-- point then fits.
local function settle(start: V3, pts: { V3 }, yaw: number, d: number, aspect: number, cfg: any): (V3, boolean)
	local focus = { start[1], start[2], start[3] }
	local yr = rad(yaw)
	local tv = math.tan(rad(cfg.FOV) / 2)
	local sp = math.max(math.sin(rad(cfg.PITCH)), 0.2)
	for _ = 1, 4 do
		local cx, cy, ok = extent(focus, pts, yaw, d, aspect, cfg)
		if ok and math.abs(cx) < 0.02 and math.abs(cy) < 0.02 then
			return focus, true
		end
		-- screen x is the camera's right (cos y, 0, -sin y); screen y over the floor is its flat forward
		-- (-sin y, 0, -cos y), stretched by 1 / sin(pitch)
		local sx = cx * d * tv * aspect
		local sy = cy * d * tv / sp
		focus[1] += math.cos(yr) * sx - math.sin(yr) * sy
		focus[3] += -math.sin(yr) * sx - math.cos(yr) * sy
	end
	local _, _, ok = extent(focus, pts, yaw, d, aspect, cfg)
	return focus, ok
end

-- The crew shot for `you` (your focus point, already FOCUS_HEIGHT over your root) and the points to frame (your
-- clones, the objective), at your look yaw and the viewport's aspect. Points farther than RADIUS (flat) from you are
-- left out: the shot is always about you. The focus starts PULL of the way toward the middle of you and the framed
-- points and slides over the floor until they sit in the middle of the frame, never more than RADIUS x PULL from
-- you; the distance is the closest in DIST_MIN..DIST_MAX that keeps you and every framed point inside SHARE /
-- SHARE_Y (DIST_MAX when none does). Returns the focus, the distance and how many points were framed.
function CrewView.frame(you: V3, points: { V3 }, yawDeg: number, aspect: number, cfg: any): (V3, number, number)
	local kept: { V3 } = { you }
	local lo = { you[1], you[3] }
	local hi = { you[1], you[3] }
	for _, p in points do
		local dx, dz = p[1] - you[1], p[3] - you[3]
		if dx * dx + dz * dz <= cfg.RADIUS * cfg.RADIUS then
			table.insert(kept, p)
			lo[1], lo[2] = math.min(lo[1], p[1]), math.min(lo[2], p[3])
			hi[1], hi[2] = math.max(hi[1], p[1]), math.max(hi[2], p[3])
		end
	end
	local mx, mz = (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2
	local start = { you[1] + (mx - you[1]) * cfg.PULL, you[2], you[3] + (mz - you[3]) * cfg.PULL }
	if #kept == 1 then
		return start, cfg.DIST_MIN, 0
	end
	local d = cfg.DIST_MIN
	while d <= cfg.DIST_MAX + 1e-9 do
		local focus = CrewView.keepYou((settle(start, kept, yawDeg, d, aspect, cfg)), you, cfg)
		local _, _, ok = extent(focus, kept, yawDeg, d, aspect, cfg)
		if ok then
			return focus, d, #kept - 1
		end
		d += math.max(cfg.DIST_STEP, 0.1)
	end
	local focus = settle(start, kept, yawDeg, cfg.DIST_MAX, aspect, cfg)
	return CrewView.keepYou(focus, you, cfg), cfg.DIST_MAX, #kept - 1
end

-- The shot is about you: the focus never strays more than RADIUS x PULL (flat) from you.
function CrewView.keepYou(focus: V3, you: V3, cfg: any): V3
	local dx, dz = focus[1] - you[1], focus[3] - you[3]
	local m = math.sqrt(dx * dx + dz * dz)
	local cap = cfg.RADIUS * cfg.PULL
	if m <= cap then
		return focus
	end
	local k = cap / m
	return { you[1] + dx * k, focus[2], you[3] + dz * k }
end

-- The one-time hint is due: a run in first person with at least HINT_MIN_CLONES clones, never seen before.
function CrewView.hintDue(clones: number, mode: string?, seen: boolean, cfg: any): boolean
	return not seen and mode == "fp" and clones >= cfg.HINT_MIN_CLONES
end

return table.freeze(CrewView)
