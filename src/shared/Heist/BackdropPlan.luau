--!strict
-- Heist/BackdropPlan: the world round the lot (PLAN_STEAM_PLUS §4.1 W4, roblox_quality §2; WORLD 2.0,
-- docs/audit/LEVELS.md §10). Pure: no engine calls and no randomness, so tests/unit/HeistBackdrop.spec.luau checks
-- the layout and the budget in Lune, tools/blender/level_shots.py draws the same plan, and
-- src/client/Heist/Backdrop.luau turns it into parts. Every position is in the site's local space (level space for a
-- heist: add the instance origin).
--
-- Layers (near to far): L0 the snowfield under everything; L1 the town (Shared/Heist/TownPlan: the street, the snow
-- over the lot's outdoor floor, the neighbours with lit windows and snowy roofs, lamps with unlit pools, cars, trees,
-- snowmen, the lot fence); L2 / L3 the skyline rings (kit meshes, four quarter copies each, drawn flat in a light haze
-- colour); the sky (Heist City cubemap, turned so the landmark is in the first view).

local Config = require("../Config")
local TownPlan = require("./TownPlan")

local BackdropPlan = {}

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Site = {
	kind: string, -- "heist" | "garage"
	bounds: Rect, -- the playable lot (a level's bounds, the garage floor with its yard)
	footprint: Rect?, -- the building interior (no roof: snow is off inside)
	floorY: number,
	front: number?, -- heist: the street front's wall line (Z); the street is toward +Z
	spawnYaw: number, -- degrees; the first view's facing (0 = toward -Z)
	theme: string, -- Config.Backdrop.TOWN.THEMES key: CornerShop | ToyShop | Bank | Garage
	seed: number, -- the level's own arrangement of its street
}
export type PartSpec = TownPlan.Part
export type KitSpec = TownPlan.Kit
export type PoolSpec = TownPlan.Pool
export type Ring = {
	name: string,
	piece: string,
	windows: string,
	yaws: { number },
	centre: { number },
	color: { number }?,
}
export type Plan = {
	parts: { PartSpec },
	kit: { KitSpec },
	pools: { PoolSpec },
	rings: { Ring },
	facades: number, -- buildings round the lot
	groundY: number,
}

local B = Config.Backdrop
local T = B.TOWN

local function rect(minX: number, maxX: number, minZ: number, maxZ: number): Rect
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

-- The street a level stands on: the Toy Shop high street for the clone party (whatever its build location), else
-- its location's (Corner Shop street, Bank plaza).
function BackdropPlan.themeFor(level: any, location: string?): string
	if level.kind == "party" then
		return "ToyShop"
	end
	local loc = location or (level.spec and level.spec.location) or "CornerShop"
	if T.THEMES[loc] then
		return loc
	end
	return "CornerShop"
end

-- A compiled level (Sim/LevelSpec.compile) as a site: the lot is its bounds; the footprint is the extent of its
-- tall walls (the shop or bank interior); the front is the walls' street-most X line. `location`: the location the
-- level was built as (the Level model's "Location" attribute), when known.
function BackdropPlan.levelSite(level: any, location: string?): Site
	local b = level.bounds
	local fp: Rect? = nil
	local front: number? = nil
	-- The building is the walls inside the street front's X extent; walls past it are a lot's fence (L6's service
	-- alley stays outdoors: snow falls there). Heist/KitPlan.buildingBox uses the same rule for the floor tiles.
	local walls = {}
	local frontLine = -math.huge
	for _, s in level.spec.solids or {} do
		local box = s.box
		local h = box.maxY - box.minY
		local thin = math.min(box.maxX - box.minX, box.maxZ - box.minZ)
		if h >= 8 and thin <= 1.5 then
			table.insert(walls, box)
			if box.maxX - box.minX > box.maxZ - box.minZ then
				frontLine = math.max(frontLine, (box.minZ + box.maxZ) / 2)
			end
		end
	end
	local fx0, fx1 = math.huge, -math.huge
	for _, box in walls do
		if box.maxX - box.minX > box.maxZ - box.minZ and math.abs((box.minZ + box.maxZ) / 2 - frontLine) < 0.01 then
			fx0, fx1 = math.min(fx0, box.minX), math.max(fx1, box.maxX)
		end
	end
	for _, box in walls do
		if fx0 > fx1 or (box.minX >= fx0 - 0.01 and box.maxX <= fx1 + 0.01) then
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
		theme = BackdropPlan.themeFor(level, location),
		seed = level.num or 1,
	}
end

-- The garage (server Heist/Lobby, Config.Lobby: a roofless brick garage at LOBBY_ORIGIN, the yard behind its back
-- wall's roll-up door) as a site. The lot is the garage plus the yard (the street runs past the yard's far edge);
-- the footprint is the interior, so no snow falls inside the garage, only on the yard seen under the door.
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
		theme = "Garage",
		seed = 1,
	}
end

function BackdropPlan.inside(r: Rect?, x: number, z: number): boolean
	if r == nil then
		return false
	end
	return x > r.minX and x < r.maxX and z > r.minZ and z < r.maxZ
end

-- Whether the town's Christmas pieces show (Config.Backdrop.TOWN.XMAS_DECOR; `dressing`: the level's layer).
function BackdropPlan.xmas(dressing: boolean?): boolean
	if T.XMAS_DECOR == "always" then
		return true
	end
	return dressing == true
end

-- The whole plan for a site (deterministic: the town's stream is seeded by the site).
function BackdropPlan.plan(site: Site, dressing: boolean?): Plan
	local b = site.bounds
	local gy = site.floorY - B.GROUND_DROP
	local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
	-- the town in its canonical frame (the street toward +Z); the garage's yard and street are toward -Z
	local mirror = site.kind == "garage"
	local function flip(r: Rect?): Rect?
		if r == nil or not mirror then
			return r
		end
		local q = r :: Rect
		return rect(q.minX, q.maxX, -q.maxZ, -q.minZ)
	end
	local lot = flip(b) :: Rect
	local front = if site.front then site.front :: number else lot.maxZ - T.PAVEMENT
	local town = TownPlan.build({
		theme = site.theme,
		seed = site.seed,
		lot = lot,
		footprint = flip(site.footprint),
		front = front,
		floorY = site.floorY,
		mirror = mirror,
		xmas = BackdropPlan.xmas(dressing),
	})
	local parts: { PartSpec } = {
		{
			name = "Ground",
			size = { B.GROUND_SIZE, 1, B.GROUND_SIZE },
			pos = { cx, gy - 0.5, cz },
			color = B.GROUND_COLOR,
			layer = "ground",
			src = "ground",
		},
	}
	for _, p in town.parts do
		table.insert(parts, p)
	end
	-- L2 / L3: the skyline rings round the site centre
	local rings: { Ring } = {}
	for _, r in B.RINGS do
		local yaws = {}
		for q = 0, 3 do
			table.insert(yaws, r.yaw0 + 90 * q)
		end
		table.insert(rings, {
			name = r.name,
			piece = r.piece,
			windows = r.windows,
			yaws = yaws,
			centre = { cx, gy, cz },
			color = r.color,
		})
	end
	return {
		parts = parts,
		kit = town.kit,
		pools = town.pools,
		rings = rings,
		facades = town.buildings,
		groundY = gy,
	}
end

-- Whether a plan layer is shown at a tier (the client hides the rest; the instances stay).
function BackdropPlan.layerOn(layer: string, tier: number): boolean
	if layer == "props" or layer == "decor" then
		return tier < T.PROPS_OFF_TIER
	end
	if layer == "pools" then
		return tier < T.POOLS_OFF_TIER
	end
	return true
end

-- Instances a pool costs on the client: its part, the SurfaceGui, the gradient image, two fallback discs + corners.
BackdropPlan.POOL_INSTANCES = 7

-- What the backdrop costs at a tier: instances, triangles and draw calls. kitTris = { [piece] = tris }
-- (kit_manifest). Boxes are 12 triangles; box parts instance by material (one draw for the SmoothPlastic boxes,
-- one for the Neon windows), each kit mesh is one draw however many copies (instanced), each pool's SurfaceGui is
-- one draw. Hidden layers (layerOn) cost no triangles or draws but keep their instances. The fence is invisible.
function BackdropPlan.budget(plan: Plan, tier: number, kitTris: { [string]: number }): (number, number, number)
	local instances, tris = 0, 0
	local batches: { [string]: boolean } = {}
	for _, p in plan.parts do
		instances += 1
		if p.layer == "fence" or not BackdropPlan.layerOn(p.layer, tier) then
			continue
		end
		tris += 12
		batches[if p.neon then "neon" else "plastic"] = true
	end
	for _, k in plan.kit do
		instances += 1
		if not BackdropPlan.layerOn(k.layer, tier) then
			continue
		end
		tris += kitTris[k.piece] or 12
		batches["kit:" .. k.piece] = true
	end
	local draws = 0
	for _ in batches do
		draws += 1
	end
	instances += #plan.pools * BackdropPlan.POOL_INSTANCES
	if BackdropPlan.layerOn("pools", tier) then
		draws += #plan.pools
	end
	for _, r in plan.rings do
		instances += 2 * #r.yaws
		if r.name == "far" and tier >= B.FAR_RING_OFF_TIER then
			continue
		end
		for _, piece in { r.piece, r.windows } do
			tris += (kitTris[piece] or 0) * #r.yaws
			draws += 1
		end
	end
	instances += 3 -- the folder, the snow volume and its emitter
	draws += 1 -- the snow emitter
	return draws, tris, instances
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
