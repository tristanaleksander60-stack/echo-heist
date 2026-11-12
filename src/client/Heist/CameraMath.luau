--!strict
-- Heist/CameraMath: the pure maths of Heist/CameraDirector (PLAN_STEAM_PLUS §4.2 C0, C1),
-- kept free of engine types and requires so Lune tests it (tests/unit/HeistCamera.spec.luau).
-- Vectors are plain { x, y, z } triples; angles are degrees unless a name says otherwise.
--
-- Conventions (Roblox): yaw turns about +Y like CFrame.Angles(0, yaw, 0), so yaw 0 looks
-- down -Z (into the shop from the street); pitch is degrees DOWN from the horizon. The
-- camera never rolls: every frame is built from a yaw and a pitch with world up.
--   * orbit: where the camera stands for a focus, yaw, pitch and distance, and the point
--     it looks at. `lead` / `ahead` put the focus ahead of you, so you sit below the centre
--     of the frame (you in the lower third, the objective above).
--   * project: a world point in normalised screen space (-1..1 both ways, +y up) for a
--     camera given by position, yaw and view pitch; the frustum test of the specs.
--   * beatWindow: when the run-start beat holds and eases inside the transition.
--   * approach / damp: frame-rate independent fades and follows.
--   * rayBox: the slab test the specs use as a raycast against axis-aligned boxes.

local CameraMath = {}

export type V3 = { number }
export type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }

local rad = math.rad

-- Unit view direction for a yaw and a downward pitch (degrees).
function CameraMath.look(yawDeg: number, pitchDeg: number): V3
	local y, p = rad(yawDeg), rad(pitchDeg)
	local c = math.cos(p)
	return { -math.sin(y) * c, -math.sin(p), -math.cos(y) * c }
end

-- How far ahead of the subject (studs, along the camera's flat forward) the orbit's focus goes
-- so the subject lands at `subjectY` (normalised, -1..1, negative = below the centre) for a
-- vertical FOV, a downward pitch and a distance (all degrees / studs). Leading the focus moves
-- the camera forward with it, so it looks over the walls between you and the room ahead (the
-- L1 plate-A fix), where tilting the view in place would not.
function CameraMath.lead(fovDeg: number, pitchDeg: number, distance: number, subjectY: number): number
	local t = -subjectY * math.tan(rad(fovDeg) / 2)
	local p = rad(pitchDeg)
	return t * distance / (math.sin(p) + t * math.cos(p))
end

-- The focus `lead` studs ahead of `subject` for a camera yaw (degrees).
function CameraMath.ahead(subject: V3, yawDeg: number, lead: number): V3
	local y = rad(yawDeg)
	return { subject[1] - math.sin(y) * lead, subject[2], subject[3] - math.cos(y) * lead }
end

-- Camera position for a focus, and the point it looks at (the focus).
function CameraMath.orbit(focus: V3, yawDeg: number, pitchDeg: number, distance: number): (V3, V3)
	local dir = CameraMath.look(yawDeg, pitchDeg)
	local pos = { focus[1] - dir[1] * distance, focus[2] - dir[2] * distance, focus[3] - dir[3] * distance }
	return pos, { focus[1], focus[2], focus[3] }
end

-- The yaw (degrees) and downward pitch (degrees) of a direction.
function CameraMath.angles(dir: V3): (number, number)
	local h = math.sqrt(dir[1] * dir[1] + dir[3] * dir[3])
	return math.deg(math.atan2(-dir[1], -dir[3])), math.deg(math.atan2(-dir[2], h))
end

-- A point in normalised screen space for a camera at `pos` with view yaw and view pitch
-- (degrees down). Returns x (-1 left .. 1 right), y (-1 bottom .. 1 top) and the depth along
-- the view (studs; <= 0 is behind the camera).
function CameraMath.project(
	pos: V3,
	yawDeg: number,
	viewPitchDeg: number,
	point: V3,
	fovDeg: number,
	aspect: number
): (number, number, number)
	local f = CameraMath.look(yawDeg, viewPitchDeg)
	local yr = rad(yawDeg)
	local right = { math.cos(yr), 0, -math.sin(yr) }
	-- up = right x forward
	local up = {
		right[2] * f[3] - right[3] * f[2],
		right[3] * f[1] - right[1] * f[3],
		right[1] * f[2] - right[2] * f[1],
	}
	local d = { point[1] - pos[1], point[2] - pos[2], point[3] - pos[3] }
	local depth = d[1] * f[1] + d[2] * f[2] + d[3] * f[3]
	local x = d[1] * right[1] + d[2] * right[2] + d[3] * right[3]
	local y = d[1] * up[1] + d[2] * up[2] + d[3] * up[3]
	if depth <= 1e-6 then
		return 0, 0, depth
	end
	local tv = math.tan(rad(fovDeg) / 2)
	return x / (depth * tv * aspect), y / (depth * tv), depth
end

-- True when the point is inside the frame (with an optional inset share on every side).
function CameraMath.inFrame(nx: number, ny: number, depth: number, inset: number?): boolean
	local m = 1 - (inset or 0)
	return depth > 0.1 and math.abs(nx) <= m and math.abs(ny) <= m
end

function CameraMath.clamp(v: number, lo: number, hi: number): number
	return math.clamp(v, math.min(lo, hi), math.max(lo, hi))
end

-- Wraps an angle in degrees to (-180, 180].
function CameraMath.wrap(deg: number): number
	local w = (deg + 180) % 360 - 180
	return if w == -180 then 180 else w
end

-- Cubic ease in-out, clamped to 0..1.
function CameraMath.ease(u: number): number
	u = math.clamp(u, 0, 1)
	return if u < 0.5 then 4 * u * u * u else 1 - (-2 * u + 2) ^ 3 / 2
end

-- The run-start beat inside a transition of `transition` seconds: it holds on the objective
-- for `hold` seconds, then eases for `ease` seconds and ends exactly when the transition does
-- (when control returns). A transition shorter than the beat only eases.
function CameraMath.beatWindow(transition: number, beat: number): (number, number)
	local t = math.max(transition, 0)
	local ease = math.min(math.max(beat, 0), t)
	return t - ease, ease
end

-- The blend (0 = objective, 1 = you) of the beat `elapsed` seconds after it started.
function CameraMath.beatBlend(elapsed: number, hold: number, ease: number): number
	if elapsed <= hold then
		return 0
	end
	if ease <= 0 then
		return 1
	end
	return CameraMath.ease((elapsed - hold) / ease)
end

-- Moves `current` toward `target` at a constant rate that covers `full` in `seconds`.
function CameraMath.approach(current: number, target: number, dt: number, full: number, seconds: number): number
	if seconds <= 0 then
		return target
	end
	local step = math.abs(full) / seconds * dt
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-- Exponential follow: the share of the gap to close this frame (frame-rate independent).
function CameraMath.damp(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

-- Zoom for a pinch: the distance scales with the inverse of the finger spread.
function CameraMath.pinch(startZoom: number, startSpread: number, spread: number, lo: number, hi: number): number
	if spread <= 1e-3 or startSpread <= 1e-3 then
		return CameraMath.clamp(startZoom, lo, hi)
	end
	return CameraMath.clamp(startZoom * startSpread / spread, lo, hi)
end

-- A drag of `pixels` over a viewport `size` px wide, as degrees (perScreen for a full width).
function CameraMath.dragDegrees(pixels: number, size: number, perScreen: number): number
	return pixels / math.max(size, 1) * perScreen
end

-- Slab test: the entry distance (0..1 along the segment from `from` to `to`) of the segment
-- into the box, or nil when it misses. A segment starting inside the box enters at 0.
function CameraMath.rayBox(from: V3, to: V3, b: Box): number?
	local t0, t1 = 0, 1
	local lo = { b.minX, b.minY, b.minZ }
	local hi = { b.maxX, b.maxY, b.maxZ }
	for k = 1, 3 do
		local o = from[k]
		local d = to[k] - o
		if math.abs(d) < 1e-9 then
			if o < lo[k] or o > hi[k] then
				return nil
			end
		else
			local a = (lo[k] - o) / d
			local c = (hi[k] - o) / d
			if a > c then
				a, c = c, a
			end
			t0 = math.max(t0, a)
			t1 = math.min(t1, c)
			if t0 > t1 then
				return nil
			end
		end
	end
	return t0
end

-- Distance that fits every point inside `share` of the half width and `shareY` of the half
-- height (normalised) for a camera looking at `focus` with the given yaw / pitch / FOV / aspect
-- (the focus itself, no lead). Searches outward from `from` in `step` studs up to `max`; nil if none fits.
function CameraMath.fitDistance(
	focus: V3,
	points: { V3 },
	yawDeg: number,
	pitchDeg: number,
	fovDeg: number,
	aspect: number,
	share: number,
	shareY: number,
	from: number,
	max: number,
	step: number
): number?
	local d = from
	while d <= max + 1e-9 do
		local pos = CameraMath.orbit(focus, yawDeg, pitchDeg, d)
		local ok = true
		for _, p in points do
			local nx, ny, depth = CameraMath.project(pos, yawDeg, pitchDeg, p, fovDeg, aspect)
			if depth <= 0.1 or math.abs(nx) > share or math.abs(ny) > shareY then
				ok = false
				break
			end
		end
		if ok then
			return d
		end
		d += step
	end
	return nil
end

-- The objective of a level for the run-start beat (C1): the top loot (it trips the alarm and
-- is what the heist is about), else the most valuable item. Level space { x, y, z }, or nil.
function CameraMath.objective(level: any): V3?
	if type(level) ~= "table" or type(level.loot) ~= "table" then
		return nil
	end
	local best: any = nil
	for _, item in level.loot do
		local top, bestTop = item.top == true, best ~= nil and best.top == true
		if best == nil or (top and not bestTop) or (top == bestTop and (item.value or 0) > (best.value or 0)) then
			best = item
		end
	end
	return if best then { best.x, best.y or 3, best.z } else nil
end

return table.freeze(CameraMath)
