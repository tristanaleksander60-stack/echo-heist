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
--   * ago: "20 SEC AGO" (docs/marketing/CLIPS.md §1.2: always the true number, rounded to
--     the nearest 10 s, at least 10; whole minutes from 55 s).

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

-- "20 SEC AGO" / "1 MIN AGO" (CLIPS §1.2).
function LineupPlan.ago(seconds: number): string
	local s = math.max(0, seconds)
	if s >= 55 then
		return string.format("%d MIN AGO", math.max(1, math.floor(s / 60 + 0.5)))
	end
	return string.format("%d SEC AGO", math.max(10, math.floor(s / 10 + 0.5) * 10))
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
