--!strict
-- Heist/CutMath: the camera-aware cut-away's decisions (PLAN_FIRST_PERSON §5 "BIG"; Config.Big.CUT). Pure numbers,
-- no allocation per call (the caller passes reusable tables), so the client Heist/CutAway can run it every frame and
-- tests/unit/HeistCutMath.spec.luau and the engine checks can run the very same rule.
--
-- A building (server Heist/TowerPlan via Heist/Overhead, or the warehouse garage) has a ceiling height and a footprint;
-- its groups are "ceiling", "roof", "face" (an upper-floor face with its outward normal and outer plane) or "occluder"
-- (a town building: only the occlusion rule). For a camera at (cx, cy, cz) and subject points:
--   * the dollhouse rule: the camera is above the ceiling (cy > ceilY + margin) and a subject stands inside the
--     footprint under the ceiling: the ceiling and the roof hide, and every face whose outer side the camera is on
--     (the faces that can stand between it and the rooms), or every face when the camera is over the footprint
--     itself (inside the shell their inner sides would wall the view in);
--   * the occlusion rule (any group, any camera): a group whose box crosses the segment from the camera to a subject
--     hides.
-- First person never calls this with its own eye (Heist/CutAway keeps everything shown while the camera is at your
-- eyes), so in first person the ceiling and the storeys are always there.

local CutMath = {}

export type Building = {
	ceilY: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}
export type Group = {
	kind: string, -- "ceiling" | "roof" | "face" | "occluder"
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
	nx: number, -- faces: outward normal (x, z); 0, 0 otherwise
	nz: number,
	plane: number, -- faces: the outer plane on the normal's axis
}

-- Whether the segment a -> b crosses the box (slab test; a segment that starts or ends inside counts).
function CutMath.segmentHitsBox(
	ax: number,
	ay: number,
	az: number,
	bx: number,
	by: number,
	bz: number,
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number
): boolean
	local t0, t1 = 0, 1
	local d = bx - ax
	if math.abs(d) < 1e-9 then
		if ax < minX or ax > maxX then
			return false
		end
	else
		local u, v = (minX - ax) / d, (maxX - ax) / d
		if u > v then
			u, v = v, u
		end
		t0, t1 = math.max(t0, u), math.min(t1, v)
		if t0 > t1 then
			return false
		end
	end
	d = by - ay
	if math.abs(d) < 1e-9 then
		if ay < minY or ay > maxY then
			return false
		end
	else
		local u, v = (minY - ay) / d, (maxY - ay) / d
		if u > v then
			u, v = v, u
		end
		t0, t1 = math.max(t0, u), math.min(t1, v)
		if t0 > t1 then
			return false
		end
	end
	d = bz - az
	if math.abs(d) < 1e-9 then
		if az < minZ or az > maxZ then
			return false
		end
	else
		local u, v = (minZ - az) / d, (maxZ - az) / d
		if u > v then
			u, v = v, u
		end
		t0, t1 = math.max(t0, u), math.min(t1, v)
		if t0 > t1 then
			return false
		end
	end
	return true
end

-- Whether any subject point (subj = { x1, y1, z1, x2, ... }, n points) stands inside the building under its ceiling.
function CutMath.inside(b: Building, subj: { number }, n: number, pad: number): boolean
	for i = 0, n - 1 do
		local x, y, z = subj[3 * i + 1], subj[3 * i + 2], subj[3 * i + 3]
		if y < b.ceilY and x > b.minX - pad and x < b.maxX + pad and z > b.minZ - pad and z < b.maxZ + pad then
			return true
		end
	end
	return false
end

-- Fills out[i] = true for every group to hide (see the header). Returns how many hide.
function CutMath.decide(
	b: Building,
	groups: { Group },
	cx: number,
	cy: number,
	cz: number,
	subj: { number },
	n: number,
	margin: number,
	pad: number,
	out: { boolean }
): number
	local above = cy > b.ceilY + margin
	local dollhouse = above and CutMath.inside(b, subj, n, pad)
	-- a camera over the footprint itself sits inside the shell: every face's inner side would wall the view in
	local over = cx > b.minX and cx < b.maxX and cz > b.minZ and cz < b.maxZ
	local count = 0
	for i, g in groups do
		local hide = false
		if dollhouse then
			if g.kind == "ceiling" or g.kind == "roof" then
				hide = true
			elseif g.kind == "face" then
				local side = if g.nx ~= 0 then (cx - g.plane) * g.nx else (cz - g.plane) * g.nz
				hide = over or side > 0
			end
		end
		if not hide then
			for k = 0, n - 1 do
				local x, y, z = subj[3 * k + 1], subj[3 * k + 2], subj[3 * k + 3]
				if CutMath.segmentHitsBox(cx, cy, cz, x, y, z, g.minX, g.minY, g.minZ, g.maxX, g.maxY, g.maxZ) then
					hide = true
					break
				end
			end
		end
		out[i] = hide
		count += if hide then 1 else 0
	end
	return count
end

-- Where a look ray meets the horizontal plane y = planeY (a presentation shot's subject), or nil when it looks up or
-- the hit is farther than maxDist.
function CutMath.lookPoint(
	px: number,
	py: number,
	pz: number,
	dx: number,
	dy: number,
	dz: number,
	planeY: number,
	maxDist: number
): (number?, number?, number?)
	if dy > -1e-3 then
		return nil, nil, nil
	end
	local t = (planeY - py) / dy
	if t < 0 or t > maxDist then
		return nil, nil, nil
	end
	return px + dx * t, planeY, pz + dz * t
end

-- One step of a fade toward its target (0 shown .. 1 hidden) over `seconds`.
function CutMath.step(alpha: number, target: number, dt: number, seconds: number): number
	local rate = if seconds > 0 then dt / seconds else 1
	if alpha < target then
		return math.min(target, alpha + rate)
	end
	return math.max(target, alpha - rate)
end

return table.freeze(CutMath)
