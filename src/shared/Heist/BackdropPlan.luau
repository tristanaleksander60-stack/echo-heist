--!strict
-- Heist/BackdropPlan: where the world backdrop goes (PLAN_STEAM_PLUS §4.1 W4, roblox_quality §2). Pure: no
-- engine calls and no randomness, so tests/unit/HeistBackdrop.spec.luau checks the layout and the budget in
-- Lune, tools/blender/level_shots.py draws the same plan, and src/client/Heist/Backdrop.luau turns it into parts.
-- Every position is in the site's local space (level space for a heist: add the instance origin).
--
-- Layers (near to far): L0 the ground plane and the kerb round the lot; L1 the near ring of facade cards (bodies,
-- a marble cornice with snow on it, warm lit windows); L2 / L3 the skyline rings (kit meshes, four quarter
-- copies each, placed by the client); the sky (Heist City cubemap, turned so the landmark is in the first view).

local Config = require("../Config")

local BackdropPlan = {}

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Site = {
	kind: string, -- "heist" | "garage"
	bounds: Rect, -- the playable lot (a level's bounds, the garage floor)
	footprint: Rect?, -- the building interior (no roof: snow is off inside)
	floorY: number,
	front: number?, -- heist: the street front's wall line (Z); the street is toward +Z
	spawnYaw: number, -- degrees; the first view's facing (0 = toward -Z)
}
export type PartSpec = {
	name: string, -- Ground | Kerb | Facade | Cornice | Snow | Window
	size: { number },
	pos: { number }, -- centre
	color: { number },
	neon: boolean?,
	layer: string, -- "ground" | "facade" | "windows"
}
export type Ring = { name: string, piece: string, windows: string, yaws: { number }, centre: { number } }
export type Plan = { parts: { PartSpec }, rings: { Ring }, facades: number, groundY: number }

local B = Config.Backdrop

local function rect(minX: number, maxX: number, minZ: number, maxZ: number): Rect
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

-- A compiled level (Sim/LevelSpec.compile) as a site: the lot is its bounds; the footprint is the extent of its
-- tall walls (the shop or bank interior); the front is the walls' street-most X line.
function BackdropPlan.levelSite(level: any): Site
	local b = level.bounds
	local fp: Rect? = nil
	local front: number? = nil
	for _, s in level.spec.solids or {} do
		local box = s.box
		local h = box.maxY - box.minY
		local thin = math.min(box.maxX - box.minX, box.maxZ - box.minZ)
		if h >= 8 and thin <= 1.5 then
			if fp == nil then
				fp = rect(box.minX, box.maxX, box.minZ, box.maxZ)
			else
				local f = fp :: Rect
				f.minX, f.maxX = math.min(f.minX, box.minX), math.max(f.maxX, box.maxX)
				f.minZ, f.maxZ = math.min(f.minZ, box.minZ), math.max(f.maxZ, box.maxZ)
			end
			if box.maxX - box.minX > box.maxZ - box.minZ then
				local line = (box.minZ + box.maxZ) / 2
				front = if front then math.max(front :: number, line) else line
			end
		end
	end
	local spawn = level.spawns and level.spawns[1]
	return {
		kind = "heist",
		bounds = rect(b.minX, b.maxX, b.minZ, b.maxZ),
		footprint = fp,
		floorY = level.floorY or 0,
		front = front,
		spawnYaw = if spawn then spawn.yaw or 0 else 0,
	}
end

-- The garage (server Heist/Lobby, Config.Lobby: a roofless brick garage at LOBBY_ORIGIN, the street apron behind its
-- back wall's roll-up door) as a site. The lot is the garage plus the apron (the facades stand round it, the row
-- behind the apron across the street from the door); the footprint is the interior, so no snow falls inside the
-- garage, only on the street seen under the door.
function BackdropPlan.garageSite(): Site
	local o = Config.Heist.LOBBY_ORIGIN
	local L = Config.Lobby
	local hx, hz, t = L.HALF_X, L.HALF_Z, L.WALL_T
	return {
		kind = "garage",
		bounds = rect(o[1] - hx - t, o[1] + hx + t, o[3] - hz - t - L.STREET_DEPTH, o[3] + hz + t),
		footprint = rect(o[1] - hx, o[1] + hx, o[3] - hz, o[3] + hz),
		floorY = o[2],
		front = nil,
		spawnYaw = 0,
	}
end

function BackdropPlan.inside(r: Rect?, x: number, z: number): boolean
	if r == nil then
		return false
	end
	return x > r.minX and x < r.maxX and z > r.minZ and z < r.maxZ
end

-- A facade row: buildings along `dir` (+1 / -1 on the row axis) from `start`, fronts on the line `line` of
-- `axis` ("X": the row runs along X, fronts at z = line; "Z": along Z, fronts at x = line) facing `face` (+1/-1).
-- stop: the row axis coordinate no facade may pass (the garage rows stay within the lot's sides, so the rows on
-- the X lines, outside the lot's Z range, and the rows on the Z lines, inside it, never meet at the corners).
type Row = { axis: string, line: number, start: number, dir: number, face: number, count: number, stop: number? }

local function rowsFor(site: Site): { Row }
	local b = site.bounds
	local F = B.FACADE
	local gap = F.gapToLot
	local n = F.count
	if site.kind == "heist" and site.front then
		local front = site.front :: number + 0.5
		-- either side of the shop along its front line (facing the street), across the street (facing the
		-- shop), and behind the lot (facing the street: seen over the roof line)
		local side = math.floor(n * 0.375 / 2 + 0.5)
		local across = math.floor(n * 0.375 + 0.5)
		local back = math.max(0, n - 2 * side - across)
		return {
			{ axis = "X", line = front, start = b.minX - gap, dir = -1, face = 1, count = side },
			{ axis = "X", line = front, start = b.maxX + gap, dir = 1, face = 1, count = side },
			{ axis = "X", line = b.maxZ + F.acrossStreet, start = -across * 13, dir = 1, face = -1, count = across },
			{ axis = "X", line = b.minZ - gap, start = -back * 13, dir = 1, face = 1, count = back },
		}
	end
	local per = math.floor(n / 4)
	return {
		{ axis = "X", line = b.maxZ + gap, start = b.minX, dir = 1, face = -1, count = per, stop = b.maxX },
		{ axis = "X", line = b.minZ - gap, start = b.minX, dir = 1, face = 1, count = per, stop = b.maxX },
		{ axis = "Z", line = b.maxX + gap, start = b.minZ, dir = 1, face = -1, count = per, stop = b.maxZ },
		{ axis = "Z", line = b.minX - gap, start = b.minZ, dir = 1, face = 1, count = per, stop = b.maxZ },
	}
end

-- The whole plan for a site (deterministic: widths, heights and colours cycle through Config lists).
function BackdropPlan.plan(site: Site): Plan
	local F = B.FACADE
	local parts: { PartSpec } = {}
	local b = site.bounds
	local gy = site.floorY - B.GROUND_DROP
	local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
	-- L0: the ground (top at gy) and the kerb band round the lot (from the ground up to the floor)
	table.insert(parts, {
		name = "Ground",
		size = { B.GROUND_SIZE, 1, B.GROUND_SIZE },
		pos = { cx, gy - 0.5, cz },
		color = B.GROUND_COLOR,
		layer = "ground",
	})
	local kw, kh = B.KERB.width, B.GROUND_DROP
	local w, d = b.maxX - b.minX, b.maxZ - b.minZ
	for _, k in
		{
			{ { w + 2 * kw, kh, kw }, { cx, b.minZ - kw / 2 } },
			{ { w + 2 * kw, kh, kw }, { cx, b.maxZ + kw / 2 } },
			{ { kw, kh, d }, { b.minX - kw / 2, cz } },
			{ { kw, kh, d }, { b.maxX + kw / 2, cz } },
		}
	do
		table.insert(parts, {
			name = "Kerb",
			size = k[1],
			pos = { k[2][1], gy + kh / 2, k[2][2] },
			color = B.KERB.color,
			layer = "ground",
		})
	end
	-- L1: the facade cards
	local count = 0
	for _, row in rowsFor(site) do
		local s = row.start
		for _ = 1, row.count do
			local stop = row.stop
			if stop and (s + row.dir * F.widths[count % #F.widths + 1] - stop) * row.dir > 1e-6 then
				break
			end
			count += 1
			local bw = F.widths[(count - 1) % #F.widths + 1]
			local bh = F.heights[(count - 1) % #F.heights + 1]
			local color = F.bodyColors[(count - 1) % #F.bodyColors + 1]
			local along = s + row.dir * bw / 2 -- the building's centre on the row axis
			s += row.dir * (bw + F.gap)
			-- local frame: u along the row, n out of the front (toward the viewer), y up
			local function at(u: number, y: number, n: number): { number }
				local depthPos = row.line + row.face * n
				if row.axis == "X" then
					return { along + u, y, depthPos }
				end
				return { depthPos, y, along + u }
			end
			local function size(su: number, sy: number, sn: number): { number }
				if row.axis == "X" then
					return { su, sy, sn }
				end
				return { sn, sy, su }
			end
			table.insert(parts, {
				name = "Facade",
				size = size(bw, bh, F.depth),
				pos = at(0, gy + bh / 2, -F.depth / 2),
				color = color,
				layer = "facade",
			})
			table.insert(parts, {
				name = "Cornice",
				size = size(bw + 0.6, F.cornice, 1.4),
				pos = at(0, gy + bh - F.cornice / 2, 0),
				color = F.corniceColor,
				layer = "facade",
			})
			table.insert(parts, {
				name = "Snow",
				size = size(bw + 0.4, F.snow, 1.2),
				pos = at(0, gy + bh + F.snow / 2, 0),
				color = B.SNOW_COLOR,
				layer = "facade",
			})
			-- lit windows: every litEvery-th slot of a grid, offset per building so the rows never line up
			local win = F.window
			local cols = math.max(1, math.floor((bw - 2) / win.colPitch))
			local floors = math.max(1, math.floor((bh - win.sill - 2) / win.floorH) + 1)
			local slot = count
			for fl = 0, floors - 1 do
				for c = 0, cols - 1 do
					slot += 1
					if slot % F.litEvery == 0 then
						local u = (c - (cols - 1) / 2) * win.colPitch
						local y = gy + win.sill + fl * win.floorH + win.h / 2
						if y + win.h / 2 < gy + bh - F.cornice - 0.5 then
							table.insert(parts, {
								name = "Window",
								size = size(win.w, win.h, 0.2),
								pos = at(u, y, 0.05),
								color = B.WINDOW_COLOR,
								neon = true,
								layer = "windows",
							})
						end
					end
				end
			end
		end
	end
	-- L2 / L3: the skyline rings round the site centre
	local rings: { Ring } = {}
	for _, r in B.RINGS do
		local yaws = {}
		for q = 0, 3 do
			table.insert(yaws, r.yaw0 + 90 * q)
		end
		table.insert(
			rings,
			{ name = r.name, piece = r.piece, windows = r.windows, yaws = yaws, centre = { cx, gy, cz } }
		)
	end
	return { parts = parts, rings = rings, facades = count, groundY = gy }
end

-- What the backdrop costs at a tier: parts, triangles (12 per box part + the ring meshes x 4 copies) and draw
-- calls (one per material / colour batch of box parts, one per ring mesh: the four copies instance). ringTris =
-- { [piece name] = tris } (kit_manifest). Rings drop out at FAR_RING_OFF_TIER; lit windows at
-- FACADE_WINDOWS_OFF_TIER.
function BackdropPlan.budget(plan: Plan, tier: number, ringTris: { [string]: number }): (number, number, number)
	local parts, tris = 0, 0
	local batches: { [string]: boolean } = {}
	for _, p in plan.parts do
		if p.layer == "windows" and tier >= B.FACADE_WINDOWS_OFF_TIER then
			continue
		end
		parts += 1
		tris += 12
		batches[(if p.neon then "neon" else "plastic") .. table.concat(p.color, ",")] = true
	end
	local draws = 0
	for _ in batches do
		draws += 1
	end
	for _, r in plan.rings do
		if r.name == "far" and tier >= B.FAR_RING_OFF_TIER then
			continue
		end
		for _, piece in { r.piece, r.windows } do
			parts += #r.yaws
			tris += (ringTris[piece] or 0) * #r.yaws
			draws += 1
		end
	end
	draws += 1 -- the snow emitter
	return draws, tris, parts
end

-- Snow emitter rate for a tier, reduced motion and whether the camera looks at the inside of a building.
function BackdropPlan.snowRate(tier: number, reduced: boolean, interior: boolean): number
	local S = B.SNOW
	local rate = S.rate
	if tier >= S.LOW_TIER then
		rate *= S.lowTierScale
	end
	if reduced then
		rate *= S.reducedRate
	end
	if interior then
		rate *= S.interiorScale
	end
	return rate
end

-- Sky.SkyboxOrientation yaw (degrees) that puts the cubemap's landmark in the site's first view.
function BackdropPlan.skyYaw(site: Site): number
	if not B.SKY_TURN then
		return 0
	end
	local y = (site.spawnYaw - B.SKY_LANDMARK_YAW) % 360
	return y
end

return table.freeze(BackdropPlan)
