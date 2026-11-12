--!strict
-- Heist/LineupPlan: the pure maths of the Crew Line-up cut (Heist/LineupDirector) and the
-- clone age label, kept free of engine calls and requires so Lune tests it
-- (tests/unit/HeistLineup.spec.luau). Positions are level space, plain numbers.
--   * arrange: the row must not stand inside the parked van. The default row sits
--     Config.Sim.LINEUP_STREET_GAP past the sim's van ZONE, which is exactly where
--     LevelBuilder parks the van BODY (zone.maxZ + 4.5, 8 studs deep). When a spot is
--     inside the body, the row turns about its centre (it faces away from the van; record
--     order still reads left to right for the camera) and steps out along its new facing
--     until every spot clears the body: the crew lines up in front of their van.
--   * fitDistance: how far a camera stands to fit a row of `width` studs in `fitWidth` of
--     the frame width and a figure in `fitHeight` of the frame height.
--   * agoRound: the number for the "20 SEC AGO" label (docs/marketing/CLIPS.md §1.2:
--     always the true number, rounded to the nearest 10 s, at least 10; whole minutes
--     from 55 s). The words are Strings.ago.

local LineupPlan = {}

export type Spot = { x: number, z: number }
-- An axis-aligned footprint: centre and half extents (already grown by any clearance).
export type Box = { cx: number, cz: number, hx: number, hz: number }

-- The facing of a yaw, as CFrame.Angles(0, yaw, 0).LookVector (x, z).
function LineupPlan.look(yaw: number): (number, number)
	return -math.sin(yaw), -math.cos(yaw)
end

local function inside(spots: { Spot }, box: Box, sx: number, sz: number): boolean
	for _, p in spots do
		if math.abs(p.x + sx - box.cx) < box.hx and math.abs(p.z + sz - box.cz) < box.hz then
			return true
		end
	end
	return false
end

-- Returns the spots to use, the row's yaw, and whether the row was moved off the van.
function LineupPlan.arrange(
	spots: { Spot },
	yaw: number,
	body: Box?,
	step: number,
	maxSteps: number
): ({ Spot }, number, boolean)
	if not body or #spots == 0 or not inside(spots, body, 0, 0) then
		return spots, yaw, false
	end
	local cx, cz = 0, 0
	for _, p in spots do
		cx += p.x
		cz += p.z
	end
	cx /= #spots
	cz /= #spots
	local turned: { Spot } = {}
	for i, p in spots do
		turned[i] = { x = 2 * cx - p.x, z = 2 * cz - p.z }
	end
	local newYaw = (yaw + math.pi) % (2 * math.pi)
	local fx, fz = LineupPlan.look(newYaw)
	for k = 0, maxSteps do
		local sx, sz = fx * k * step, fz * k * step
		if not inside(turned, body, sx, sz) then
			for _, p in turned do
				p.x += sx
				p.z += sz
			end
			return turned, newYaw, true
		end
	end
	return spots, yaw, false
end

-- C5 (PLAN_STEAM_PLUS §4.2): a row inside the van body keeps its facing (the crew faces the
-- street camera, the lit shop front behind them) and slides back, toward the building, until
-- every spot is `gap` studs clear of the body. Returns the spots and whether they moved.
function LineupPlan.slide(
	spots: { Spot },
	yaw: number,
	body: Box?,
	gap: number,
	step: number,
	maxSteps: number
): ({ Spot }, boolean)
	if not body or #spots == 0 or not inside(spots, body, 0, 0) then
		return spots, false
	end
	local grown = { cx = body.cx, cz = body.cz, hx = body.hx + gap, hz = body.hz + gap }
	local fx, fz = LineupPlan.look(yaw)
	for k = 1, maxSteps do
		local sx, sz = -fx * k * step, -fz * k * step
		if not inside(spots, grown, sx, sz) then
			local out: { Spot } = {}
			for i, p in spots do
				out[i] = { x = p.x + sx, z = p.z + sz }
			end
			return out, true
		end
	end
	return spots, false
end

export type ShotOpts = {
	spots: { Spot },
	yaw: number, -- the row's facing (radians, LineupPlan.look)
	floorY: number,
	fov: number, -- vertical, degrees
	aspect: number,
	share: number, -- every figure inside this share of the half width (0.32 = the central 32 %)
	shareY: number, -- ... and of the half height
	figureHeight: number,
	figureHalfWidth: number,
	lookHeight: number,
	heights: { number }, -- camera heights above the floor, tried in order
	yaws: { number }, -- degrees off the row's facing, tried at each height
	minDistance: number,
	maxDistance: number,
	maxPitch: number?, -- degrees: a higher camera stands further back so it never looks down steeper than this
	push: number, -- the shot starts this share further back (the slow push-in) and must be clear there too
	blocked: (from: { number }, to: { number }) -> boolean,
}
export type Shot =
	{ pos: { number }, look: { number }, start: { number }, distance: number, height: number, yaw: number }

local function shotLook(cx: number, cz: number, o: ShotOpts): { number }
	return { cx, o.floorY + o.lookHeight, cz }
end

-- Projects p for a camera at pos looking at `at` (no roll): normalised x, y and depth.
local function projectAt(
	pos: { number },
	at: { number },
	p: { number },
	fov: number,
	aspect: number
): (number, number, number)
	local fx, fy, fz = at[1] - pos[1], at[2] - pos[2], at[3] - pos[3]
	local fl = math.sqrt(fx * fx + fy * fy + fz * fz)
	fx, fy, fz = fx / fl, fy / fl, fz / fl
	local rl = math.max(math.sqrt(fz * fz + fx * fx), 1e-9)
	local rx, rz = -fz / rl, fx / rl -- right = forward x world up (no roll)
	local ux, uy, uz = -rz * fy, rz * fx - rx * fz, rx * fy -- up = right x forward
	local dx, dy, dz = p[1] - pos[1], p[2] - pos[2], p[3] - pos[3]
	local depth = dx * fx + dy * fy + dz * fz
	if depth <= 1e-6 then
		return 0, 0, depth
	end
	local tv = math.tan(math.rad(fov) / 2)
	local x = dx * rx + dz * rz
	local y = dx * ux + dy * uy + dz * uz
	return x / (depth * tv * aspect), y / (depth * tv), depth
end
LineupPlan.projectAt = projectAt

-- The figure points a shot must hold: each spot's feet at both shoulders and its head.
function LineupPlan.figurePoints(
	spots: { Spot },
	yaw: number,
	floorY: number,
	height: number,
	halfWidth: number
): { { number } }
	local fx, fz = LineupPlan.look(yaw)
	local ax, az = fz, -fx
	local out = {}
	for _, s in spots do
		table.insert(out, { s.x + ax * halfWidth, floorY + 0.3, s.z + az * halfWidth })
		table.insert(out, { s.x - ax * halfWidth, floorY + 0.3, s.z - az * halfWidth })
		table.insert(out, { s.x, floorY + height, s.z })
	end
	return out
end

-- The Line-up camera (C5): for each height (lowest first) and yaw offset, the closest
-- distance that keeps every figure inside `share` of the frame width, accepted when the
-- lanes from the camera (at that distance and at the push-in start) to every figure point
-- are clear. Nil when no candidate works (the caller pulls the camera in instead).
function LineupPlan.shot(o: ShotOpts): Shot?
	if #o.spots == 0 then
		return nil
	end
	local cx, cz = 0, 0
	for _, s in o.spots do
		cx += s.x
		cz += s.z
	end
	cx /= #o.spots
	cz /= #o.spots
	local at = shotLook(cx, cz, o)
	local points = LineupPlan.figurePoints(o.spots, o.yaw, o.floorY, o.figureHeight, o.figureHalfWidth)
	local function fits(pos: { number }): boolean
		for _, p in points do
			local nx, ny, depth = projectAt(pos, at, p, o.fov, o.aspect)
			if depth <= 0.5 or math.abs(nx) > o.share or math.abs(ny) > o.shareY then
				return false
			end
		end
		return true
	end
	local function clear(pos: { number }): boolean
		for _, p in points do
			if o.blocked(pos, p) then
				return false
			end
		end
		return not o.blocked(pos, at)
	end
	for _, h in o.heights do
		for _, off in o.yaws do
			local fx, fz = LineupPlan.look(o.yaw + math.rad(off))
			local function posAt(d: number): { number }
				return { cx + fx * d, o.floorY + h, cz + fz * d }
			end
			local d = o.minDistance
			if o.maxPitch then
				d = math.max(d, (h - o.lookHeight) / math.tan(math.rad(o.maxPitch)))
			end
			while d <= o.maxDistance do
				if fits(posAt(d)) then
					break
				end
				d += 0.5
			end
			if d <= o.maxDistance and clear(posAt(d)) and clear(posAt(d * (1 + o.push))) then
				return {
					pos = posAt(d),
					start = posAt(d * (1 + o.push)),
					look = at,
					distance = d,
					height = h,
					yaw = off,
				}
			end
		end
	end
	return nil
end

-- Centre (x, z) and width across the row (studs between the outer spots + one figure).
function LineupPlan.extent(spots: { Spot }, yaw: number, figureWidth: number): (number, number, number)
	local fx, fz = LineupPlan.look(yaw)
	local ax, az = fz, -fx -- across
	local cx, cz = 0, 0
	local lo, hi = math.huge, -math.huge
	for _, p in spots do
		cx += p.x
		cz += p.z
		local a = p.x * ax + p.z * az
		lo = math.min(lo, a)
		hi = math.max(hi, a)
	end
	local n = math.max(#spots, 1)
	return cx / n, cz / n, (if #spots > 0 then hi - lo else 0) + figureWidth
end

-- Camera distance that fits the row (width) and a figure (height) at a vertical FOV.
function LineupPlan.fitDistance(
	width: number,
	aspect: number,
	fovDeg: number,
	fitWidth: number,
	figureHeight: number,
	fitHeight: number
): number
	local tv = math.tan(math.rad(fovDeg) / 2)
	local dw = (width / fitWidth) / 2 / (tv * math.max(aspect, 0.1))
	local dh = (figureHeight / fitHeight) / 2 / tv
	return math.max(dw, dh)
end

-- The smallest FOV in [from, to] (step 2) whose fit distance is at most `d` (else `to`).
function LineupPlan.fovFor(
	d: number,
	width: number,
	aspect: number,
	from: number,
	to: number,
	fitWidth: number,
	figureHeight: number,
	fitHeight: number
): number
	for f = from, to, 2 do
		if LineupPlan.fitDistance(width, aspect, f, fitWidth, figureHeight, fitHeight) <= d then
			return f
		end
	end
	return to
end

-- The age label's number and unit (CLIPS §1.2): (20, false) = "20 SEC AGO",
-- (1, true) = "1 MIN AGO" (Strings.ago).
function LineupPlan.agoRound(seconds: number): (number, boolean)
	local s = math.max(0, seconds)
	if s >= 55 then
		return math.max(1, math.floor(s / 60 + 0.5)), true
	end
	return math.max(10, math.floor(s / 10 + 0.5) * 10), false
end

-- The cut's timeline: each figure walks after `startDelay + delay`, for `walk` seconds
-- (min(dist / speed, maxWalk)), then turns; the poses start `poseGap` after the last
-- arrival, rippling by each figure's delay; the cut ends `hold` after the last pose.
-- figures: { { delay: number, dist: number } } -> starts, walks, poseAt, endAt
function LineupPlan.timeline(
	figures: { { delay: number, dist: number } },
	startDelay: number,
	speed: number,
	maxWalk: number,
	turn: number,
	poseGap: number,
	hold: number
): ({ number }, { number }, number, number)
	local starts, walks = {}, {}
	local lastArrive, maxDelay = 0, 0
	for i, f in figures do
		starts[i] = startDelay + f.delay
		walks[i] = math.min(f.dist / math.max(speed, 1e-3), maxWalk)
		lastArrive = math.max(lastArrive, starts[i] + walks[i] + turn)
		maxDelay = math.max(maxDelay, f.delay)
	end
	local poseAt = lastArrive + poseGap
	return starts, walks, poseAt, poseAt + maxDelay + hold
end

return table.freeze(LineupPlan)
