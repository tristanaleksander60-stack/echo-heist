--!strict
-- Heist/KitPlan: where the art kit's pieces go for a compiled level (pure; Lune-tested in
-- tests/unit/HeistKitPlan.spec.luau). docs/art/KIT_IMPORT.md "How the game uses the kit",
-- STYLE_BIBLE §5.2. Heist/KitDresser turns the plan into MeshParts.
--
-- Rule zero: the kit is the LOOK, never the collision. Every static piece is visual only
-- (CanCollide off); the greybox part it dresses stays as an invisible collider with the
-- sim's exact box, so gameplay is identical with or without the kit. The only kit parts
-- that collide are the swapped door leaves and plates, which are scaled to exactly the
-- door box / greybox pad and have Box collision (KitDresser keeps the greybox leaf when a
-- piece did not get its Box fidelity).
--
-- Placement: each item is a list of kit pieces sharing one pivot (x, y, z in level space,
-- yaw in degrees) and one scale (per local axis). A piece's centre is
-- pivot + R(yaw) * ((origin + boundsCentre) * scale) and its size is size * scale (all
-- kit parts are axis-aligned at rest), so placement never depends on PivotOffset.
-- Wall-line pieces (walls, door frames, street fronts, the vault frame) map their 2-thick
-- body onto the sim's 1-thick wall band, so faces line up with the colliders; modules run
-- on the 4-stud grid (8 and 4 wide), and the last module of a run is scaled to fit.
--
-- What it plans: wall tiles (trimmed where a perpendicular wall already covers the end,
-- cut where a frame stands), door frames on 6-wide gaps, the street front (Storefront or
-- BankFront) on the 8-wide entrance, the vault frame + a swing skin on Bank vault doors,
-- counters, shelves, pillars, floor tiles inside the building, door leaves and shutters
-- (swaps), plates (swaps), loot meshes (swaps; the till sits on a CashRegister), laser
-- posts, hide props (niche on the plate when a plate is under the hide), the wall switch,
-- the van, and the Christmas layer (lights and snow caps on the street front, garlands on
-- inner walls, a wreath over the entrance, snow piles, candy-cane laser posts).

local KitPlan = {}

export type Vec = { number }
export type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }
export type Pivot = { x: number, y: number, z: number, yaw: number }
export type PartSpec = {
	model: string,
	size: Vec,
	boundsMin: Vec,
	boundsMax: Vec,
	origin: Vec,
	[string]: any,
}
export type Item = {
	role: string, -- wall | counter | shelf | pillar | floor | frame | front | vaultFrame | vaultSkin | signature |
	-- door | plate | loot | till | display | post | hide | switch | van | lamp | rug | xmas
	mode: string, -- "visual" (static, no collision) | "swap" (replaces a tagged greybox part) |
	-- "dress" (inside a tagged Model: laser posts, hide props) | "skin" (vault door, client-drawn)
	pieces: { string },
	pivot: Pivot,
	scale: Vec,
	ref: string?, -- solid | door | laser | plate | loot | hide | switch | van | lamp
	index: number?,
	layer: string, -- "base" | "xmas"
	openYaw: number?, -- skin: degrees about the hinge
	hinge: string?, -- skin: the piece whose pivot is the hinge
}
export type Options = {
	dressing: boolean?, -- Christmas layer
	location: string?, -- "CornerShop" | "ToyShop" | "Bank" (front piece)
	floor: boolean?,
	floorLift: number?,
	avoid: { [string]: boolean }?, -- pieces not to use (missing, wrong fidelity)
	dress: any?, -- Heist/LevelDress entry: room lamps, windows, goal displays (visual only)
	lighting: any?, -- Config.Lighting: plan Lamp_Ceiling over every lamp (KitPlan.lamps); nil = no lamps
}
export type Plan = {
	items: { Item },
	solids: { [number]: { number } }, -- solid index -> item indices that dress it
	vanBox: Box?, -- the van's kit footprint (the invisible van collider takes it)
	warnings: { string },
}

local EPS = 1e-6
local GRID = 4 -- wall modules are 4 and 8 wide
local WALL_MIN_H = 8 -- solids at least this tall and thin are walls
local THIN = 1.5
local SHELF_MIN_H = 5
local COUNTER_MAX_H = 5
local PILLAR_MAX = 3

-- Body boxes (scene space) of pieces whose bounds include trim that must not drive the
-- fit: the 2-thick wall body (Z 0..2) of wall-line pieces, the counter and shelf carcass.
local BODY: { [string]: { Vec } } = {
	Wall_8x12 = { { -8, 0, 0 }, { 0, 12, 2 } },
	Wall_4x12 = { { -4, 0, 0 }, { 0, 12, 2 } },
	Wall_Window_8x12 = { { -8, 0, -0.25 }, { 0, 12, 2.25 } }, -- sills both sides: the whole depth maps to the band
	Wall_Door_8x12 = { { -8, 0, 0 }, { 0, 12, 2 } },
	Storefront_24x12 = { { -24, 0, 0 }, { 0, 12, 2 } },
	BankFront_24x12 = { { -24, 0, 0 }, { 0, 12, 2 } },
	VaultDoor_Frame = { { -16, 0, 0 }, { 0, 12, 2 } },
	Counter_8x4 = { { -8, 0, 0 }, { 0, 3.5, 4 } },
	Counter_4x4 = { { -4, 0, 0 }, { 0, 3.5, 4 } },
	Counter_8x2 = { { -8, 0, 0 }, { 0, 3.5, 2 } },
	TellerCounter_8x4 = { { -8, 0, 0 }, { 0, 4, 4 } }, -- the counter to 4 (the glass screen rides above, scaled with it)
	Shelf_8x2 = { { -8, 0, 0 }, { 0, 7.85, 2 } },
	Shelf_Gondola_8x2 = { { -8, 0, 0 }, { 0, 7.85, 2 } },
	Pillar_2x12 = { { -2, 0, 0 }, { 0, 12, 2 } },
	Floor_8x8 = { { -8, -0.5, 0 }, { 0, 0, 8 } },
	Xmas_SnowCap_8 = { { -8, 11.85, 0 }, { 0, 12.52, 2 } },
}

-- Open floor niches of the walk-in hides (manifest `niche`, scene XZ centre): placed on
-- the plate under the hide so the plate stays visible.
local NICHE: { [string]: { number } } = {
	Hide_CoatRack = { 0, 0 },
	Hide_DepositStack = { 0, -0.475 },
	Hide_Plant = { 0, 0 },
}

local LOOT_MESH: { [string]: string } = {
	Candy = "Candy",
	Cash = "CashBag",
	Diamond = "Diamond",
	Gold = "GoldBar",
	Present = "Present",
	Teddy = "Teddy",
	Toy = "Toy",
}

---------------------------------------------------------------------------
-- Maths (yaw in degrees about +Y; Roblox's CFrame.Angles(0, yaw, 0) convention)
---------------------------------------------------------------------------

local function cs(yaw: number): (number, number)
	local q = yaw % 360
	if math.abs(q) < EPS or math.abs(q - 360) < EPS then
		return 1, 0
	elseif math.abs(q - 90) < EPS then
		return 0, 1
	elseif math.abs(q - 180) < EPS then
		return -1, 0
	elseif math.abs(q - 270) < EPS then
		return 0, -1
	end
	local r = math.rad(yaw)
	return math.cos(r), math.sin(r)
end

-- Local (x, z) rotated by yaw into world axes.
function KitPlan.rotate(yaw: number, x: number, z: number): (number, number)
	local c, s = cs(yaw)
	return x * c + z * s, -x * s + z * c
end

function KitPlan.box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return { minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ }
end

-- Scale and pivot that map the scene box [bmin, bmax] exactly onto `box` (world-axis
-- aligned) at a yaw that is a multiple of 90. keepY: no vertical scale, bottom on box.minY.
function KitPlan.fit(bmin: Vec, bmax: Vec, box: Box, yaw: number, keepY: boolean?): (Pivot, Vec)
	local c = cs(yaw)
	local alongX = math.abs(c) > 0.5 -- local X runs along world X
	local wx, wz = box.maxX - box.minX, box.maxZ - box.minZ
	local lx, ly, lz = bmax[1] - bmin[1], bmax[2] - bmin[2], bmax[3] - bmin[3]
	local sx = (if alongX then wx else wz) / lx
	local sz = (if alongX then wz else wx) / lz
	local sy = if keepY then 1 else (box.maxY - box.minY) / ly
	local rx, rz = KitPlan.rotate(yaw, (bmin[1] + bmax[1]) / 2 * sx, (bmin[3] + bmax[3]) / 2 * sz)
	return {
		x = (box.minX + box.maxX) / 2 - rx,
		y = box.minY - bmin[2] * sy,
		z = (box.minZ + box.maxZ) / 2 - rz,
		yaw = yaw,
	}, { sx, sy, sz }
end

-- The scene box's XZ centre at (x, z), its bottom at y; uniform scale k (default 1).
function KitPlan.place(bmin: Vec, bmax: Vec, x: number, y: number, z: number, yaw: number, k: number?): (Pivot, Vec)
	local s = k or 1
	local rx, rz = KitPlan.rotate(yaw, (bmin[1] + bmax[1]) / 2 * s, (bmin[3] + bmax[3]) / 2 * s)
	return { x = x - rx, y = y - bmin[2] * s, z = z - rz, yaw = yaw }, { s, s, s }
end

-- A piece's centre (level space) and size for an item's pivot and scale.
function KitPlan.partFrame(spec: PartSpec, pivot: Pivot, scale: Vec): (Vec, Vec)
	local o, lo, hi = spec.origin, spec.boundsMin, spec.boundsMax
	local cx = (o[1] + (lo[1] + hi[1]) / 2) * scale[1]
	local cy = (o[2] + (lo[2] + hi[2]) / 2) * scale[2]
	local cz = (o[3] + (lo[3] + hi[3]) / 2) * scale[3]
	local rx, rz = KitPlan.rotate(pivot.yaw, cx, cz)
	return { pivot.x + rx, pivot.y + cy, pivot.z + rz }, {
		(hi[1] - lo[1]) * scale[1],
		(hi[2] - lo[2]) * scale[2],
		(hi[3] - lo[3]) * scale[3],
	}
end

-- World AABB of an item's pieces (for tests and the van collider).
function KitPlan.itemBox(item: Item, specs: { [string]: PartSpec }): Box
	local b = KitPlan.box(math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge)
	for _, name in item.pieces do
		local spec = specs[name]
		if spec then
			local c, s = KitPlan.partFrame(spec, item.pivot, item.scale)
			local swap = math.abs((cs(item.pivot.yaw))) < 0.5
			local hx = (if swap then s[3] else s[1]) / 2
			local hz = (if swap then s[1] else s[3]) / 2
			b.minX, b.maxX = math.min(b.minX, c[1] - hx), math.max(b.maxX, c[1] + hx)
			b.minY, b.maxY = math.min(b.minY, c[2] - s[2] / 2), math.max(b.maxY, c[2] + s[2] / 2)
			b.minZ, b.maxZ = math.min(b.minZ, c[3] - hz), math.max(b.maxZ, c[3] + hz)
		end
	end
	return b
end

-- Module runs on the 4-stud grid: 8-wide modules, then one 4- or 8-wide module scaled to
-- the remainder (a remainder under 2 studs widens the last module instead).
function KitPlan.tiles(a: number, b: number): { { number } }
	local out: { { number } } = {}
	local len = b - a
	if len <= EPS then
		return out
	end
	local n = math.floor((len + 1e-4) / 8)
	local x = a
	for _ = 1, n do
		table.insert(out, { x, x + 8, 8 })
		x += 8
	end
	local rest = b - x
	if rest > 1e-4 then
		if #out > 0 and rest < 2 then
			out[#out][2] = b
		else
			table.insert(out, { x, b, if rest <= 6 then GRID else 8 })
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Level geometry helpers
---------------------------------------------------------------------------

local function inside2(box: Box, x: number, z: number): boolean
	return x > box.minX + EPS and x < box.maxX - EPS and z > box.minZ + EPS and z < box.maxZ - EPS
end

local DIRS = {
	{ name = "-Z", dx = 0, dz = -1, yaw = 0 }, -- local front (-Z) faces this way at this yaw
	{ name = "+Z", dx = 0, dz = 1, yaw = 180 },
	{ name = "-X", dx = -1, dz = 0, yaw = 90 },
	{ name = "+X", dx = 1, dz = 0, yaw = -90 },
}

-- Free distance from (x, z) along a direction before a solid or the edge of `bounds`
-- (the building footprint, so "most room" never points out of the shop).
local function room(level: any, bounds: Box, x: number, z: number, dx: number, dz: number, ignore: number?): number
	local stepLen = 0.5
	local d = 0
	while d < 60 do
		d += stepLen
		local px, pz = x + dx * d, z + dz * d
		if px < bounds.minX or px > bounds.maxX or pz < bounds.minZ or pz > bounds.maxZ then
			return d
		end
		for i, s in level.spec.solids or {} do
			if i ~= ignore and inside2(s.box, px, pz) then
				return d
			end
		end
	end
	return d
end

-- The direction (of `allowed`) with the most room: a hide's open side, a switch's front.
-- With `prefer` (a point, e.g. the crew's spawn), the allowed direction that points most
-- toward it wins whenever it has at least PREFER_ROOM studs (a counter faces the shop floor).
local PREFER_ROOM = 3
local function openSide(
	level: any,
	bounds: Box,
	x: number,
	z: number,
	allowed: { string }?,
	ignore: number?,
	prefer: { number }?
): any
	local best, bestD = DIRS[1], -1
	local toward, towardDot = nil, -math.huge
	for _, dir in DIRS do
		if allowed == nil or table.find(allowed, dir.name) then
			local d = room(level, bounds, x, z, dir.dx, dir.dz, ignore)
			if d > bestD + EPS then
				best, bestD = dir, d
			end
			if prefer and d >= PREFER_ROOM then
				local dot = dir.dx * (prefer[1] - x) + dir.dz * (prefer[2] - z)
				if dot > towardDot + EPS then
					toward, towardDot = dir, dot
				end
			end
		end
	end
	return toward or best
end

type Wall = {
	i: number,
	axis: string, -- "X" (runs along X) | "Z"
	line: number,
	thick: number,
	a: number,
	b: number,
	y0: number,
	h: number,
	box: Box,
}

local function wallOf(i: number, box: Box): Wall?
	local wx, wz, h = box.maxX - box.minX, box.maxZ - box.minZ, box.maxY - box.minY
	if h < WALL_MIN_H - EPS or math.min(wx, wz) > THIN + EPS then
		return nil
	end
	if wx >= wz then
		return {
			i = i,
			axis = "X",
			line = (box.minZ + box.maxZ) / 2,
			thick = wz,
			a = box.minX,
			b = box.maxX,
			y0 = box.minY,
			h = h,
			box = box,
		}
	end
	return {
		i = i,
		axis = "Z",
		line = (box.minX + box.maxX) / 2,
		thick = wx,
		a = box.minZ,
		b = box.maxZ,
		y0 = box.minY,
		h = h,
		box = box,
	}
end

-- The building's own walls: every wall inside the street front's X extent (the front is the street-most X-axis
-- wall line). Walls past it are lot walls (L6's fence and service alley): outdoors, so the kit floor tiles stop at
-- the building and the client's snow falls there (Shared/Heist/BackdropPlan.levelSite uses the same rule).
-- Returns the building's walls' extent, or nil without walls.
function KitPlan.buildingBox(level: any): Box?
	local walls: { Wall } = {}
	local front = -math.huge
	for i, s in level.spec.solids or {} do
		local w = wallOf(i, s.box)
		if w then
			table.insert(walls, w)
			if w.axis == "X" then
				front = math.max(front, w.line)
			end
		end
	end
	if #walls == 0 then
		return nil
	end
	local fx0, fx1 = math.huge, -math.huge
	for _, w in walls do
		if w.axis == "X" and math.abs(w.line - front) < 0.01 then
			fx0, fx1 = math.min(fx0, w.box.minX), math.max(fx1, w.box.maxX)
		end
	end
	local out: Box? = nil
	for _, w in walls do
		local b = w.box
		if fx0 > fx1 or (b.minX >= fx0 - 0.01 and b.maxX <= fx1 + 0.01) then
			if out == nil then
				out = KitPlan.box(b.minX, b.minY, b.minZ, b.maxX, b.maxY, b.maxZ)
			else
				local o = out :: Box
				o.minX, o.maxX = math.min(o.minX, b.minX), math.max(o.maxX, b.maxX)
				o.minZ, o.maxZ = math.min(o.minZ, b.minZ), math.max(o.maxZ, b.maxZ)
			end
		end
	end
	return out
end

-- A box along a wall line: [s0, s1] along the run, the wall band across it.
local function lineBox(w: Wall, s0: number, s1: number, y0: number?, y1: number?): Box
	local lo, hi = w.line - w.thick / 2, w.line + w.thick / 2
	local ya, yb = y0 or w.y0, y1 or (w.y0 + w.h)
	if w.axis == "X" then
		return KitPlan.box(s0, ya, lo, s1, yb, hi)
	end
	return KitPlan.box(lo, ya, s0, hi, yb, s1)
end

-- The yaw that puts a wall-line piece's front (-Z) on the given side of its line.
local function lineYaw(axis: string, frontPositive: boolean): number
	if axis == "X" then
		return if frontPositive then 180 else 0
	end
	return if frontPositive then -90 else 90
end

-- Moves a wall's ends off perpendicular walls that already cover its whole band there.
local function trimEnds(w: Wall, walls: { Wall })
	local lo, hi = w.line - w.thick / 2, w.line + w.thick / 2
	for _, p in walls do
		if p ~= w and p.axis ~= w.axis then
			local plo, phi = p.line - p.thick / 2, p.line + p.thick / 2
			local covers = p.a <= lo + EPS and p.b >= hi - EPS
			if covers and w.a >= plo - EPS and w.a <= phi + EPS then
				w.a = math.max(w.a, phi)
			end
			if covers and w.b >= plo - EPS and w.b <= phi + EPS then
				w.b = math.min(w.b, plo)
			end
		end
	end
end

local function subtract(a: number, b: number, cuts: { { number } }): { { number } }
	local spans = { { a, b } }
	for _, cut in cuts do
		local nextSpans = {}
		for _, s in spans do
			if cut[2] <= s[1] + EPS or cut[1] >= s[2] - EPS then
				table.insert(nextSpans, s)
			else
				if cut[1] > s[1] + EPS then
					table.insert(nextSpans, { s[1], cut[1] })
				end
				if cut[2] < s[2] - EPS then
					table.insert(nextSpans, { cut[2], s[2] })
				end
			end
		end
		spans = nextSpans
	end
	return spans
end

local function isVaultDoor(door: any, location: string?): boolean
	return location == "Bank" and string.find(string.lower(door.id or ""), "vault", 1, true) ~= nil
end

local function hidePiece(def: any, plateInside: boolean, location: string?): string
	local id = string.lower(def.id or "")
	if string.find(id, "coatrack", 1, true) then
		return "Hide_CoatRack"
	elseif string.find(id, "coatstand", 1, true) then
		return "Hide_CoatStand"
	elseif string.find(id, "crate", 1, true) then
		return "Hide_Crate"
	elseif string.find(id, "fern", 1, true) or string.find(id, "plant", 1, true) then
		return "Hide_Plant"
	elseif string.find(id, "stack", 1, true) then
		return "Hide_DepositStack"
	elseif string.find(id, "curtain", 1, true) then
		return "Hide_Curtain"
	elseif string.find(id, "tree", 1, true) then
		return "Xmas_Tree"
	end
	if plateInside then
		return if location == "Bank" then "Hide_DepositStack" else "Hide_CoatRack"
	end
	return "Hide_CoatStand"
end

---------------------------------------------------------------------------
-- Lights, letters and cables (pure; Heist/LevelBuilder builds them on the greybox, so a level the kit
-- did not dress is lit and signposted the same way). LEVELS.md §4 P0-1..P0-3, PLAN_STEAM_PLUS §4.1 W2.
---------------------------------------------------------------------------

export type Lamp = { x: number, z: number, kind: string, index: number? } -- kind: plate | hero | room | accent | street

local function insideTall(level: any, x: number, z: number): boolean
	for _, s in level.spec.solids or {} do
		local b = s.box
		if b.maxY - b.minY > COUNTER_MAX_H + EPS and inside2(b, x, z) then
			return true
		end
	end
	return false
end

-- The goal loot's index: the first `top` item, else the most valuable (first wins a tie).
function KitPlan.goal(level: any): number?
	local best, bestValue = nil, -math.huge
	for i, def in level.loot do
		if def.top then
			return i
		end
		if (def.value or 0) > bestValue then
			best, bestValue = i, def.value or 0
		end
	end
	return best
end

-- Automatic room centres: one per band between X-axis walls inside the building (two when wide).
local function autoRooms(level: any, cfg: any): { { number } }
	local lines: { number } = {}
	local x0, x1 = math.huge, -math.huge
	for i, s in level.spec.solids or {} do
		local w = wallOf(i, s.box)
		if w then
			x0, x1 = math.min(x0, s.box.minX), math.max(x1, s.box.maxX)
			if w.axis == "X" then
				local dup = false
				for _, z in lines do
					dup = dup or math.abs(z - w.line) < 0.5
				end
				if not dup then
					table.insert(lines, w.line)
				end
			end
		end
	end
	table.sort(lines, function(a: number, b: number): boolean
		return a > b
	end)
	local out = {}
	if x0 >= x1 then
		return out
	end
	local cx, width = (x0 + x1) / 2, x1 - x0
	for k = 1, #lines - 1 do
		local za, zb = lines[k], lines[k + 1]
		if za - zb >= 6 then
			local cz = (za + zb) / 2
			if width > cfg.AUTO_ROOM_WIDE then
				table.insert(out, { cx - width / 4, cz })
				table.insert(out, { cx + width / 4, cz })
			else
				table.insert(out, { cx, cz })
			end
		end
	end
	return out
end

-- Every lamp of a level: one over each plate, the hero over the goal (the only shadowed light), then the
-- room centres (LevelDress `rooms`, else automatic), skipping any within cfg.MIN_LAMP_GAP of a lamp, then the
-- warm accents (LevelDress `accents`: the Bank vault's gold light), then the street lamps on the pavement (LevelDress `street`: warm pools outside, PLAN_STEAM_PLUS §3.1, GOLDEN G1).
function KitPlan.lamps(level: any, dress: any?, cfg: any): { Lamp }
	local out: { Lamp } = {}
	for i, p in level.plates do
		table.insert(
			out,
			{ x = (p.box.minX + p.box.maxX) / 2, z = (p.box.minZ + p.box.maxZ) / 2, kind = "plate", index = i }
		)
	end
	local g = KitPlan.goal(level)
	if g then
		local def = level.loot[g]
		local spot = dress and dress.hero
		table.insert(out, {
			x = if spot then spot[1] else def.x,
			z = if spot then spot[2] else def.z,
			kind = "hero",
			index = g,
		})
	end
	local rooms = if dress and dress.rooms then dress.rooms else autoRooms(level, cfg)
	for _, r in rooms do
		local free = not insideTall(level, r[1], r[2])
		for _, l in out do
			local dx, dz = l.x - r[1], l.z - r[2]
			free = free and dx * dx + dz * dz >= cfg.MIN_LAMP_GAP * cfg.MIN_LAMP_GAP - EPS
		end
		if free then
			table.insert(out, { x = r[1], z = r[2], kind = "room" })
		end
	end
	if cfg.LAMP.accent then
		for _, a in (dress and dress.accents) or {} do
			table.insert(out, { x = a[1], z = a[2], kind = "accent" })
		end
	end
	if cfg.LAMP.street then
		for _, st in (dress and dress.street) or {} do
			table.insert(out, { x = st[1], z = st[2], kind = "street" })
		end
	end
	return out
end

-- The location a level is built as (atlas, street front, light colour): the spec's location, an explicit
-- override, and Clone Party in Christmas dressing is the Toy Shop (MASTERPLAN §4.2). LevelBuilder, KitDresser,
-- tools/blender/level_plan.luau and the client Backdrop all use this one rule.
function KitPlan.location(level: any, dressing: boolean?, override: string?): string
	local location = override or (level.spec and level.spec.location) or "CornerShop"
	if dressing and level.kind == "party" and location == "CornerShop" then
		location = "ToyShop"
	end
	return location
end

-- Each lamp's light and floor-pool colour (PLAN_STEAM_PLUS §3.1: one dominant light colour per location).
-- Room lamps take the location's colour (in turn when it has several: the Toy Shop's pink and gold); plate
-- lamps (signals) and the hero (the focal pool) keep cfg.LAMP's warm white; street lamps keep their own warm
-- colour and pool (cfg.LAMP.street.poolColor). Returns {color, pool} per lamp, in the order of `lamps`. Pure
-- data: never adds or removes a light.
function KitPlan.lampLooks(lamps: { Lamp }, location: string?, cfg: any): { { color: { number }, pool: { number } } }
	local loc = cfg.LOCATION and location and cfg.LOCATION[location]
	local out = {}
	local rooms = 0
	for k, l in lamps do
		local spec = cfg.LAMP[l.kind] or cfg.LAMP.room
		local color, pool = spec.color, spec.poolColor or cfg.POOL.color
		if l.kind == "room" and loc then
			rooms += 1
			color = loc.room[(rooms - 1) % #loc.room + 1]
			pool = loc.pool or pool
		end
		out[k] = { color = color, pool = pool }
	end
	return out
end

-- The letter a plate and every device it drives carry: the plate's id when it is one letter, else its
-- position in the level (A, B, C ...).
function KitPlan.letter(level: any, plateIndex: number): string
	local p = level.plates[plateIndex]
	local id = p and p.id or ""
	if string.match(id, "^%u$") then
		return id
	end
	return string.char(64 + plateIndex)
end

-- Plate indices that drive a source list (door openBy, laser offBy), sorted.
local function platesOf(list: { any }?): { number }
	local out = {}
	for _, src in list or {} do
		if src.kind == "plate" then
			table.insert(out, src.index)
		end
	end
	table.sort(out)
	return out
end

-- The letters on a device (door or laser), e.g. "A" or "ABCD".
function KitPlan.deviceLetters(level: any, sources: { any }?): string
	local s = ""
	for _, i in platesOf(sources) do
		s ..= KitPlan.letter(level, i)
	end
	return s
end

local function sign(v: number): number
	return if v > EPS then 1 elseif v < -EPS then -1 else 0
end

-- Trunk slots of a door several plates open (1 = the lowest run coordinate): plates on the low side of the
-- doorway take the low slots, the one nearest the door's line outermost, and the high side the same from the other
-- end, so no plate's cross run (at its own Z) ever crosses another plate's trunk (L6's vault: C, B, A, D from
-- west to east; tests/unit/HeistKitPlan.spec "L6 cables never cross"). Returns { [plate index] = slot }.
local function trunkSlots(level: any, srcs: { number }, alongX: boolean, cu: number, line: number): { [number]: number }
	local low, high = {}, {}
	for _, i in srcs do
		local p = level.plates[i]
		local px, pz = (p.box.minX + p.box.maxX) / 2, (p.box.minZ + p.box.maxZ) / 2
		local pu, pv = if alongX then px else pz, if alongX then pz else px
		table.insert(if pu < cu - EPS then low else high, { i = i, d = math.abs(pv - line) })
	end
	local function near(a: any, b: any): boolean
		if math.abs(a.d - b.d) > EPS then
			return a.d < b.d
		end
		return a.i < b.i
	end
	table.sort(low, near)
	table.sort(high, near)
	local out = {}
	for k, e in low do
		out[e.i] = k
	end
	for k, e in high do
		out[e.i] = #srcs + 1 - k
	end
	return out
end

export type Cable = { plate: number, points: { { number } } } -- level-space (x, z) polyline

-- Floor cables (LEVELS P0-2): a door cable runs along X at the plate's Z, then along Z to the device's near
-- jamb (inside the doorway, cfg.CABLE_JAMB_INSET from the jamb, one stud short of the leaf on the plate's
-- side); several plates into one device run as parallel trunks cfg.CABLE_TRUNK_GAP apart. A laser cable runs
-- across to one stud in front of the grid first, then along it to the base of the end post nearer the plate
-- (the kit posts stand just inside the grid's ends). Two cables of
-- one level never share a line in L1-L5 (tests/unit/HeistKitPlan.spec.luau).
function KitPlan.cables(level: any, cfg: any): { Cable }
	local out: { Cable } = {}
	for i, p in level.plates do
		local px, pz = (p.box.minX + p.box.maxX) / 2, (p.box.minZ + p.box.maxZ) / 2
		for _, d in level.doors do
			local srcs = platesOf(d.openBy)
			local k = table.find(srcs, i)
			if k then
				local b = d.box
				local alongX = (b.maxX - b.minX) >= (b.maxZ - b.minZ)
				-- u: along the door's run; v: across it (the wall line)
				local cu = if alongX then (b.minX + b.maxX) / 2 else (b.minZ + b.maxZ) / 2
				local half = (if alongX then b.maxX - b.minX else b.maxZ - b.minZ) / 2
				local line = if alongX then (b.minZ + b.maxZ) / 2 else (b.minX + b.maxX) / 2
				local pu, pv = if alongX then px else pz, if alongX then pz else px
				local tu
				if #srcs == 1 then
					local side = sign(pu - cu)
					tu = cu + (if side == 0 then 0 else side * (half - cfg.CABLE_JAMB_INSET))
				else
					local slot = trunkSlots(level, srcs, alongX, cu, line)[i] or k
					tu = cu + (slot - (#srcs + 1) / 2) * cfg.CABLE_TRUNK_GAP
				end
				local tv = line + (if sign(pv - line) >= 0 then 1 else -1)
				local pts = if alongX
					then { { px, pz }, { tu, pz }, { tu, tv } }
					else { { px, pz }, { px, tu }, { tv, tu } }
				table.insert(out, { plate = i, points = pts })
			end
		end
		for _, l in level.lasers do
			if table.find(platesOf(l.offBy), i) then
				local b = l.box
				local alongX = (b.maxX - b.minX) >= (b.maxZ - b.minZ)
				local pts
				if alongX then
					local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
					local postX = if px < cx then b.minX + 0.5 else b.maxX - 0.5
					local frontZ = if pz >= cz then b.maxZ + 1 else b.minZ - 1
					pts = { { px, pz }, { px, frontZ }, { postX, frontZ } }
				else
					local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
					local postZ = if pz < cz then b.minZ + 0.5 else b.maxZ - 0.5
					local frontX = if px >= cx then b.maxX + 1 else b.minX - 1
					pts = { { px, pz }, { frontX, pz }, { frontX, postZ } }
				end
				table.insert(out, { plate = i, points = pts })
			end
		end
	end
	return out
end

-- Soft floor-pool discs (Config.Lighting.POOL_SOFT): `rings` concentric discs, outermost first, whose stacked
-- opacity follows opacity(r) = peak * (1 - (r / R)^2)^exponent, the falloff the uploaded radial image draws in
-- one piece. The peak keeps the kind's old stepped discs' area-weighted opacity (warm share unchanged), capped
-- at peakMax. Returns { size = share of the diameter, alpha = transparency } like Config's rings, and the peak.
function KitPlan.poolPeak(stepped: { { size: number, alpha: number } }, soft: any): number
	-- the stepped discs' mean opacity over the pool's area: each ring adds its opacity to everything inside it
	local sorted = table.clone(stepped)
	table.sort(sorted, function(a: any, b: any): boolean
		return a.size > b.size
	end)
	local mean, through = 0, 1
	for k, ring in sorted do
		through *= ring.alpha
		local outer = ring.size
		local inner = if sorted[k + 1] then sorted[k + 1].size else 0
		mean += (1 - through) * (outer * outer - inner * inner)
	end
	return math.min(mean * (soft.exponent + 1) * (soft.gain or 1), soft.peakMax)
end

-- The floor a lamp's pool may cover (level space): its square, cut at the wall lines between the lamp and the
-- square's edge, so a pool never shines through a wall onto the next room or, for a street lamp, through the shop
-- front onto the roofless interior (the diorama camera sees it). First the walls the lamp faces square on (the
-- wall's run covers the lamp's own X or Z), then any wall still inside what is left (a partition beside a doorway),
-- until nothing changes. LevelBuilder sizes the pool part to this rect and keeps the disc centred on the lamp in it.
export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
function KitPlan.poolRect(level: any, x: number, z: number, diameter: number): Rect
	local r = diameter / 2
	local out = { minX = x - r, maxX = x + r, minZ = z - r, maxZ = z + r }
	local walls: { Wall } = {}
	for i, s in level.spec.solids or {} do
		local w = wallOf(i, s.box)
		if w then
			table.insert(walls, w)
		end
	end
	local function cut(w: Wall)
		local half = w.thick / 2
		if w.axis == "X" then
			if z > w.line then
				out.minZ = math.max(out.minZ, w.line + half)
			else
				out.maxZ = math.min(out.maxZ, w.line - half)
			end
		elseif x > w.line then
			out.minX = math.max(out.minX, w.line + half)
		else
			out.maxX = math.min(out.maxX, w.line - half)
		end
	end
	-- a wall line strictly inside the rect, whose run reaches into it (or, square on, covers the lamp)
	local function crosses(w: Wall, squareOn: boolean): boolean
		if w.axis == "X" then
			local inLine = w.line > out.minZ + EPS and w.line < out.maxZ - EPS
			local run = if squareOn then w.a <= x and w.b >= x else w.b > out.minX + EPS and w.a < out.maxX - EPS
			return inLine and run
		end
		local inLine = w.line > out.minX + EPS and w.line < out.maxX - EPS
		local run = if squareOn then w.a <= z and w.b >= z else w.b > out.minZ + EPS and w.a < out.maxZ - EPS
		return inLine and run
	end
	for _, w in walls do
		if crosses(w, true) then
			cut(w)
		end
	end
	for _ = 1, 4 do
		local changed = false
		for _, w in walls do
			if crosses(w, false) then
				cut(w)
				changed = true
			end
		end
		if not changed then
			break
		end
	end
	return out
end

function KitPlan.poolRings(stepped: { { size: number, alpha: number } }, soft: any): { { size: number, alpha: number } }
	local peak = KitPlan.poolPeak(stepped, soft)
	local n = math.max(2, math.floor(soft.rings))
	local function opacity(u: number): number
		return peak * math.max(0, 1 - u * u) ^ soft.exponent
	end
	local out = {}
	local through = 1 -- transmittance of the rings laid so far
	for k = 1, n do
		local outer = (n - k + 1) / n
		local inner = (n - k) / n
		-- the band (inner, outer) shows the falloff at its middle
		local want = opacity((outer + inner) / 2)
		local a = 1 - (1 - want) / through
		a = math.clamp(a, 0, 1)
		through *= 1 - a
		table.insert(out, { size = outer, alpha = 1 - a })
	end
	return out
end

-- "Need all n" readout (LEVELS P1-3, PLAN §7): for every door that needs all of its 2+ plates, a row of lettered
-- lamps on the face of its frame toward its plates, in letter order from the viewer's left, centred on the door's
-- own lamp (which keeps the middle). cfg = Config.Lighting (VAULT_ROW). Positions are level space.
export type RowLamp = { x: number, y: number, z: number, plate: number, letter: string }
export type VaultRow = { door: number, lamps: { RowLamp }, nx: number, nz: number, alongX: boolean }
function KitPlan.vaultRows(level: any, cfg: any): { VaultRow }
	local out: { VaultRow } = {}
	local r = cfg.VAULT_ROW
	for di, d in level.doors do
		local srcs = platesOf(d.openBy)
		if d.need ~= "all" or #srcs < 2 then
			continue
		end
		local b = d.box
		local alongX = (b.maxX - b.minX) >= (b.maxZ - b.minZ)
		local cu = if alongX then (b.minX + b.maxX) / 2 else (b.minZ + b.maxZ) / 2
		local line = if alongX then (b.minZ + b.maxZ) / 2 else (b.minX + b.maxX) / 2
		local half = (if alongX then b.maxZ - b.minZ else b.maxX - b.minX) / 2
		-- the face toward the plates (their mean, across the line)
		local sum = 0
		for _, i in srcs do
			local p = level.plates[i]
			sum += if alongX then (p.box.minZ + p.box.maxZ) / 2 - line else (p.box.minX + p.box.maxX) / 2 - line
		end
		local side = if sum >= 0 then 1 else -1
		local v = line + side * (half + r.face)
		-- seen from that face, "left" runs toward -u when the face looks +Z / -X (a viewer facing the door)
		local leftToRight = if alongX then (if side > 0 then 1 else -1) else (if side > 0 then -1 else 1)
		local n = #srcs
		local lamps: { RowLamp } = {}
		for k, i in srcs do
			-- slots skip the middle (the door lamp keeps it): the gap is doubled across the centre; an odd row
			-- shifts half a slot to the right so no lamp sits on the door lamp
			local slot = k - (n + 1) / 2 + (if n % 2 == 1 then 0.5 else 0)
			local u = cu + leftToRight * (slot + (if slot < 0 then -0.5 else 0.5)) * r.gap
			table.insert(lamps, {
				x = if alongX then u else v,
				y = level.floorY + r.y,
				z = if alongX then v else u,
				plate = i,
				letter = KitPlan.letter(level, i),
			})
		end
		table.insert(out, {
			door = di,
			lamps = lamps,
			nx = if alongX then 0 else side,
			nz = if alongX then side else 0,
			alongX = alongX,
		})
	end
	return out
end

-- Plates inside hide spots (L4's plate B under the coat rack, L6's A / B / C / D): their letters, to hang on a disc
-- over the hide so "the plate is in there" reads from the room (FEEDBACK_TABLE "Hide spot", LEVELS P1-2).
export type HidePlate = { hide: number, letters: string, x: number, z: number, top: number }
function KitPlan.hidePlates(level: any): { HidePlate }
	local out: { HidePlate } = {}
	for hi, h in level.hides or {} do
		local hb = h.box
		local letters = ""
		for pi, p in level.plates do
			local cx, cz = (p.box.minX + p.box.maxX) / 2, (p.box.minZ + p.box.maxZ) / 2
			if cx > hb.minX and cx < hb.maxX and cz > hb.minZ and cz < hb.maxZ then
				letters ..= KitPlan.letter(level, pi)
			end
		end
		if letters ~= "" then
			table.insert(out, {
				hide = hi,
				letters = letters,
				x = (hb.minX + hb.maxX) / 2,
				z = (hb.minZ + hb.maxZ) / 2,
				top = hb.maxY,
			})
		end
	end
	return out
end

---------------------------------------------------------------------------
-- The plan
---------------------------------------------------------------------------

-- Groups of pieces by kit model (manifest `model`), sorted.
function KitPlan.groups(specs: { [string]: PartSpec }): { [string]: { string } }
	local out: { [string]: { string } } = {}
	for name, spec in specs do
		local list = out[spec.model]
		if not list then
			list = {}
			out[spec.model] = list
		end
		table.insert(list, name)
	end
	for _, list in out do
		table.sort(list)
	end
	return out
end

function KitPlan.plan(level: any, specs: { [string]: PartSpec }, opts: Options?): Plan
	local o: Options = opts or {}
	local avoid = o.avoid or {}
	local groups = KitPlan.groups(specs)
	local floorY = level.floorY
	local location = o.location
	local dressing = o.dressing == true
	local plan: Plan = { items = {}, solids = {}, vanBox = nil, warnings = {} }

	local function has(name: string): boolean
		return specs[name] ~= nil and not avoid[name]
	end
	local function hasAll(names: { string }): boolean
		for _, n in names do
			if not has(n) then
				return false
			end
		end
		return #names > 0
	end
	local function scene(names: { string }): (Vec, Vec)
		local lo = { math.huge, math.huge, math.huge }
		local hi = { -math.huge, -math.huge, -math.huge }
		for _, n in names do
			local s = specs[n]
			for k = 1, 3 do
				lo[k] = math.min(lo[k], s.origin[k] + s.boundsMin[k])
				hi[k] = math.max(hi[k], s.origin[k] + s.boundsMax[k])
			end
		end
		return lo, hi
	end
	local function body(name: string): (Vec, Vec)
		local b = BODY[name]
		if b then
			return b[1], b[2]
		end
		return scene({ name })
	end
	local function add(item: Item): number
		table.insert(plan.items, item)
		local n = #plan.items
		if item.ref == "solid" and item.index then
			local list = plan.solids[item.index]
			if not list then
				list = {}
				plan.solids[item.index] = list
			end
			table.insert(list, n)
		end
		return n
	end
	local function item(
		role: string,
		mode: string,
		pieces: { string },
		pivot: Pivot,
		scale: Vec,
		ref: string?,
		index: number?,
		layer: string?
	): Item
		return {
			role = role,
			mode = mode,
			pieces = pieces,
			pivot = pivot,
			scale = scale,
			ref = ref,
			index = index,
			layer = layer or "base",
		}
	end

	---------------------------------------------------------------- walls
	local solids = level.spec.solids or {}
	local walls: { Wall } = {}
	for i, s in solids do
		local w = wallOf(i, s.box)
		if w then
			table.insert(walls, w)
		end
	end
	-- The building footprint (walls' extent): floor tiles, and the "room" searches.
	local footprint = KitPlan.box(math.huge, floorY, math.huge, -math.huge, floorY, -math.huge)
	for _, w in walls do
		local b = w.box
		footprint.minX, footprint.maxX = math.min(footprint.minX, b.minX), math.max(footprint.maxX, b.maxX)
		footprint.minZ, footprint.maxZ = math.min(footprint.minZ, b.minZ), math.max(footprint.maxZ, b.maxZ)
	end
	if footprint.minX >= footprint.maxX then
		footprint = level.bounds
	end
	local spawn = level.spawns and level.spawns[1]
	local prefer = if spawn then { spawn.x, spawn.z } else nil

	-- Untrimmed spans find the gaps; trimmed spans are tiled.
	local raw: { [Wall]: { number } } = {}
	for _, w in walls do
		raw[w] = { w.a, w.b }
	end
	for _, w in walls do
		trimEnds(w, walls)
	end

	-- Lines: walls sharing an axis, line and thickness.
	local lines: { [string]: { Wall } } = {}
	local lineKeys: { string } = {}
	for _, w in walls do
		local key = string.format("%s%d_%d", w.axis, math.floor(w.line * 100 + 0.5), math.floor(w.thick * 100 + 0.5))
		if not lines[key] then
			lines[key] = {}
			table.insert(lineKeys, key)
		end
		table.insert(lines[key], w)
	end
	table.sort(lineKeys)

	-- The street front: the X line furthest toward the street (+Z) with an 8-wide gap.
	local frontKey: string? = nil
	local frontLine = -math.huge
	for _, key in lineKeys do
		local list = lines[key]
		table.sort(list, function(p: Wall, q: Wall): boolean
			return raw[p][1] < raw[q][1]
		end)
		if list[1].axis == "X" then
			for k = 1, #list - 1 do
				local g = raw[list[k + 1]][1] - raw[list[k]][2]
				if math.abs(g - 8) < 0.1 and list[1].line > frontLine then
					frontKey, frontLine = key, list[1].line
				end
			end
		end
	end

	local cuts: { [string]: { { number } } } = {}
	local doorFramed: { [number]: boolean } = {}
	local frontPiece = if location == "Bank" then "BankFront_24x12" else "Storefront_24x12"
	local frontInfo: any = nil
	for _, key in lineKeys do
		local list = lines[key]
		cuts[key] = {}
		for k = 1, #list - 1 do
			local w1, w2 = list[k], list[k + 1]
			local g0, g1 = raw[w1][2], raw[w2][1]
			local g, c = g1 - g0, (g0 + g1) / 2
			local doorIndex: number? = nil
			for di, d in level.doors do
				local dc = if w1.axis == "X" then (d.box.minX + d.box.maxX) / 2 else (d.box.minZ + d.box.maxZ) / 2
				local dl = if w1.axis == "X" then (d.box.minZ + d.box.maxZ) / 2 else (d.box.minX + d.box.maxX) / 2
				if math.abs(dc - c) < 0.1 and math.abs(dl - w1.line) < 0.1 then
					doorIndex = di
				end
			end
			if key == frontKey and math.abs(g - 8) < 0.1 and w1.axis == "X" then
				local names = groups[frontPiece]
				if names and hasAll(names) then
					local bmin, bmax = body(frontPiece)
					local box = lineBox(w1, c - 12, c + 12)
					local pivot, scale = KitPlan.fit(bmin, bmax, box, lineYaw("X", true))
					add(item("front", "visual", names, pivot, scale))
					table.insert(cuts[key], { c - 12, c + 12 })
					frontInfo = { wall = w1, c = c, key = key }
				end
			elseif math.abs(g - 6) < 0.1 then
				local door = doorIndex and level.doors[doorIndex]
				if door and isVaultDoor(door, location) and has("VaultDoor_Frame") then
					local bmin, bmax = body("VaultDoor_Frame")
					local box = lineBox(w1, c - 8, c + 8)
					local yaw = lineYaw(w1.axis, true)
					local pivot, scale = KitPlan.fit(bmin, bmax, box, yaw)
					add(item("vaultFrame", "visual", { "VaultDoor_Frame" }, pivot, scale, "door", doorIndex))
					local skin = { "VaultDoor_Door", "VaultDoor_Dial", "VaultDoor_DialFace", "VaultDoor_DialRing" }
					local present = {}
					for _, n in skin do
						if has(n) then
							table.insert(present, n)
						end
					end
					if table.find(present, "VaultDoor_Door") then
						local s = item("vaultSkin", "skin", present, pivot, scale, "door", doorIndex)
						s.openYaw = -175
						s.hinge = "VaultDoor_Door"
						add(s)
					end
					table.insert(cuts[key], { c - 8, c + 8 })
					doorFramed[doorIndex :: number] = true
				elseif has("Wall_Door_8x12") then
					local bmin, bmax = body("Wall_Door_8x12")
					local box = lineBox(w1, c - 4, c + 4)
					local pivot, scale = KitPlan.fit(bmin, bmax, box, lineYaw(w1.axis, false))
					add(item("frame", "visual", { "Wall_Door_8x12" }, pivot, scale, "door", doorIndex))
					table.insert(cuts[key], { c - 4, c + 4 })
					if doorIndex then
						doorFramed[doorIndex] = true
					end
				end
			end
		end
	end

	-- Wall tiles, and the Christmas wall dressing that follows them. Window runs (LevelDress `windows`)
	-- tile from the end nearer the building's centre, so the glass sits beside the doorway.
	local windowLines = (o.dress and o.dress.windows) or {}
	local windowNames = groups.Wall_Window_8x12
	local canWindow = windowNames ~= nil and hasAll(windowNames)
	local midX, midZ = (footprint.minX + footprint.maxX) / 2, (footprint.minZ + footprint.maxZ) / 2
	local frontTiles: { { any } } = {}
	for _, key in lineKeys do
		for _, w in lines[key] do
			if not (has("Wall_8x12") and has("Wall_4x12")) then
				continue
			end
			local isWindow = false
			for _, wl in windowLines do
				isWindow = isWindow or (wl.axis == w.axis and math.abs(wl.line - w.line) < 0.1)
			end
			isWindow = isWindow and canWindow
			for _, span in subtract(w.a, w.b, cuts[key]) do
				local tiles = KitPlan.tiles(span[1], span[2])
				if isWindow then
					local mid = if w.axis == "X" then midX else midZ
					if math.abs(span[2] - mid) < math.abs(span[1] - mid) then
						tiles = {}
						for _, t in KitPlan.tiles(-span[2], -span[1]) do
							table.insert(tiles, { -t[2], -t[1], t[3] })
						end
					end
				end
				for _, t in tiles do
					local name = if t[3] == 8 then "Wall_8x12" else "Wall_4x12"
					local names = { name }
					if isWindow and t[3] == 8 and math.abs((t[2] - t[1]) - 8) < 0.01 then
						name, names = "Wall_Window_8x12", windowNames :: { string }
					end
					local bmin, bmax = body(name)
					local box = lineBox(w, t[1], t[2])
					local pivot, scale = KitPlan.fit(bmin, bmax, box, lineYaw(w.axis, false))
					add(item("wall", "visual", names, pivot, scale, "solid", w.i))
					if key == frontKey then
						table.insert(frontTiles, { w, t[1], t[2] })
					elseif dressing and w.axis == "X" and t[2] - t[1] >= 6 then
						-- Garland on the street-facing side of inner walls.
						local garland = groups.Xmas_Garland_8
						if garland and hasAll(garland) then
							local lo, hi = scene(garland)
							local face = w.line + w.thick / 2
							local gbox =
								KitPlan.box(t[1], w.y0 + lo[2], face, t[2], w.y0 + hi[2], face + (hi[3] - lo[3]))
							local pivot2, scale2 = KitPlan.fit(lo, hi, gbox, 180, true)
							add(item("xmas", "visual", garland, pivot2, scale2, nil, nil, "xmas"))
						end
					end
				end
			end
		end
	end

	-- Street front: fairy lights on the street face, snow caps on top, a wreath over the
	-- entrance and snow piles at the corners.
	if dressing and frontInfo then
		for _, ft in frontTiles do
			local w, s0, s1 = ft[1], ft[2], ft[3]
			local face = w.line + w.thick / 2
			local lights = groups.Xmas_Lights_8
			if lights and hasAll(lights) then
				local lo, hi = scene(lights)
				local lbox = KitPlan.box(s0, w.y0 + lo[2], face, s1, w.y0 + hi[2], face + (hi[3] - lo[3]))
				local pivot, scale = KitPlan.fit(lo, hi, lbox, 180, true)
				add(item("xmas", "visual", lights, pivot, scale, nil, nil, "xmas"))
			end
			if has("Xmas_SnowCap_8") and w.h >= 11.9 then
				local bmin, bmax = body("Xmas_SnowCap_8")
				local cbox = lineBox(w, s0, s1, w.y0 + bmin[2], w.y0 + bmax[2])
				local pivot, scale = KitPlan.fit(bmin, bmax, cbox, 0, true)
				add(item("xmas", "visual", { "Xmas_SnowCap_8" }, pivot, scale, nil, nil, "xmas"))
			end
		end
		local w = frontInfo.wall
		local face = w.line + w.thick / 2
		if has("Xmas_Wreath") then
			-- Over the entrance, between its 10-stud lintel and the facade's top.
			local lo, hi = scene({ "Xmas_Wreath" })
			local top = if frontPiece == "BankFront_24x12" then 13.6 else 11.9
			local k = math.min(1, (top - 10.1) / (hi[2] - lo[2]))
			local pivot, scale =
				KitPlan.place(lo, hi, frontInfo.c, w.y0 + 10.1, face + (hi[3] - lo[3]) * k / 2 + 0.05, 180, k)
			add(item("xmas", "visual", { "Xmas_Wreath" }, pivot, scale, nil, nil, "xmas"))
		end
		if has("Xmas_SnowPile") then
			local lo, hi = scene({ "Xmas_SnowPile" })
			local list = lines[frontInfo.key]
			local ends = { list[1].a + 3, list[#list].b - 3 }
			for _, x in ends do
				local pivot = KitPlan.place(lo, hi, x, w.y0, face + 1.8, 180)
				add(item("xmas", "visual", { "Xmas_SnowPile" }, pivot, { 1, 1, 1 }, nil, nil, "xmas"))
			end
		end
	end

	---------------------------------------------------------------- other solids
	local party = level.kind == "party" or location == "ToyShop"
	for i, s in solids do
		if wallOf(i, s.box) then
			continue
		end
		local b = s.box
		local wx, wz, h = b.maxX - b.minX, b.maxZ - b.minZ, b.maxY - b.minY
		local long, short = math.max(wx, wz), math.min(wx, wz)
		local alongX = wx >= wz
		local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
		if h >= WALL_MIN_H - EPS and long <= PILLAR_MAX + EPS and has("Pillar_2x12") then
			local bmin, bmax = body("Pillar_2x12")
			local pivot, scale = KitPlan.fit(bmin, bmax, b, 0)
			add(item("pillar", "visual", { "Pillar_2x12" }, pivot, scale, "solid", i))
		elseif s.sight == false and h <= COUNTER_MAX_H + EPS then
			local name = if short <= 2.5 then "Counter_8x2" elseif long <= 5 then "Counter_4x4" else "Counter_8x4"
			-- The Bank's counters are teller counters (marble top, glass screen; LEVELS P1-3): the real lobby
			if location == "Bank" and not party and long > 5 and has("TellerCounter_8x4") then
				name = "TellerCounter_8x4"
			end
			if not has(name) then
				continue
			end
			local bmin, bmax = body(name)
			local allowed = if name == "Counter_4x4" then nil elseif alongX then { "-Z", "+Z" } else { "-X", "+X" }
			local dir = openSide(level, footprint, cx, cz, allowed, i, prefer)
			local runsX = dir.name == "-Z" or dir.name == "+Z" -- the module length runs across the front
			local a0, a1 = if runsX then b.minX else b.minZ, if runsX then b.maxX else b.maxZ
			local spans = if name == "Counter_4x4" then { { a0, a1, 4 } } else KitPlan.tiles(a0, a1)
			for _, t in spans do
				local box = if runsX
					then KitPlan.box(t[1], b.minY, b.minZ, t[2], b.maxY, b.maxZ)
					else KitPlan.box(b.minX, b.minY, t[1], b.maxX, b.maxY, t[2])
				local pivot, scale = KitPlan.fit(bmin, bmax, box, dir.yaw)
				add(item("counter", "visual", groups[name] or { name }, pivot, scale, "solid", i))
			end
		elseif h >= SHELF_MIN_H - EPS and short <= 3 + EPS then
			local name = if party then "Shelf_Gondola_8x2" else "Shelf_8x2"
			if not has(name) then
				continue
			end
			local bmin, bmax = body(name)
			local a0, a1 = if alongX then b.minX else b.minZ, if alongX then b.maxX else b.maxZ
			for _, t in KitPlan.tiles(a0, a1) do
				local box = if alongX
					then KitPlan.box(t[1], b.minY, b.minZ, t[2], b.maxY, b.maxZ)
					else KitPlan.box(b.minX, b.minY, t[1], b.maxX, b.maxY, t[2])
				local pivot, scale = KitPlan.fit(bmin, bmax, box, if alongX then 0 else 90)
				add(item("shelf", "visual", { name }, pivot, scale, "solid", i))
			end
		end
	end

	---------------------------------------------------------------- floor
	if o.floor ~= false and has("Floor_8x8") and #walls > 0 then
		local lift = o.floorLift or 0.02
		local bmin, bmax = body("Floor_8x8")
		-- inside the building only: a lot's alley stays the street floor (outdoors, LEVELS L6 "the alley")
		local fb = KitPlan.buildingBox(level) or footprint
		for _, tx in KitPlan.tiles(fb.minX, fb.maxX) do
			for _, tz in KitPlan.tiles(fb.minZ, fb.maxZ) do
				local box = KitPlan.box(tx[1], floorY - 0.5 + lift, tz[1], tx[2], floorY + lift, tz[2])
				local pivot, scale = KitPlan.fit(bmin, bmax, box, 0)
				add(item("floor", "visual", { "Floor_8x8" }, pivot, scale))
			end
		end
	end

	---------------------------------------------------------------- doors
	for i, d in level.doors do
		if isVaultDoor(d, location) and doorFramed[i] then
			continue -- greybox leaf stays the collider; the swing skin is drawn by the client
		end
		local streetDoor = d.alarmLock or math.abs((d.box.maxX - d.box.minX) - 8) < 0.1
		local name = if streetDoor then "Shutter_8x10" else "Wall_Door_8x12_Leaf"
		if has(name) then
			local lo, hi = scene({ name })
			local wx, wz = d.box.maxX - d.box.minX, d.box.maxZ - d.box.minZ
			local pivot, scale = KitPlan.fit(lo, hi, d.box, if wx >= wz then 0 else 90)
			add(item("door", "swap", { name }, pivot, scale, "door", i))
		end
	end

	---------------------------------------------------------------- plates
	local plateNames = groups.Plate_4x4
	if plateNames and hasAll(plateNames) then
		local lo, hi = scene(plateNames)
		for i, p in level.plates do
			local cx, cz = (p.box.minX + p.box.maxX) / 2, (p.box.minZ + p.box.maxZ) / 2
			local pivot = KitPlan.place(lo, hi, cx, floorY, cz, 0)
			add(item("plate", "swap", plateNames, pivot, { 1, 1, 1 }, "plate", i))
		end
	end

	---------------------------------------------------------------- loot
	for i, def in level.loot do
		local name = LOOT_MESH[def.kind or ""]
		if def.heavy then
			name = "GiantPresent"
		elseif def.kind == "Gold" and def.top then
			name = "GoldStack"
		end
		if not name or not has(name) then
			continue
		end
		local lo, hi = scene({ name })
		local standTop = floorY + math.max(def.y - floorY - 1, 0.2)
		local till = def.top == true and def.kind == "Cash" and groups.CashRegister and hasAll(groups.CashRegister)
		local display = o.dress and o.dress.displays and o.dress.displays[def.id]
		local displayNames = display and groups[display]
		if not till and displayNames and hasAll(displayNames) then
			-- the goal's own display (LEVELS P0-4: the safe is a Safe, the register a CashRegister), its
			-- front toward the crew, the loot on top; visual only, like the stand it replaces
			local dlo, dhi = scene(displayNames)
			local dir = openSide(level, footprint, def.x, def.z, nil, nil, prefer)
			local dpivot = KitPlan.place(dlo, dhi, def.x, floorY, def.z, dir.yaw)
			add(item("display", "visual", displayNames, dpivot, { 1, 1, 1 }, "loot", i))
			standTop = floorY + (dhi[2] - dlo[2])
		elseif till then
			local rlo, rhi = scene(groups.CashRegister)
			local dir = openSide(level, footprint, def.x, def.z, nil, nil, prefer)
			local rpivot = KitPlan.place(rlo, rhi, def.x, floorY, def.z, dir.yaw)
			add(item("till", "visual", groups.CashRegister, rpivot, { 1, 1, 1 }, "loot", i))
			standTop = floorY + (rhi[2] - rlo[2])
		end
		local pivot = KitPlan.place(lo, hi, def.x, standTop, def.z, 0)
		add(item("loot", "swap", { name }, pivot, { 1, 1, 1 }, "loot", i))
	end

	---------------------------------------------------------------- lasers
	for i, l in level.lasers do
		local b = l.box
		local alongX = (b.maxX - b.minX) >= (b.maxZ - b.minZ)
		local post = if dressing and has("LaserEmitter_CandyCane") then "LaserEmitter_CandyCane" else "LaserEmitter"
		local names = { post }
		if has("LaserEmitter_Lens") then
			table.insert(names, "LaserEmitter_Lens")
		end
		if not has(post) then
			continue
		end
		-- Each post stands inside its end of the box, lens toward the other post.
		local ends = if alongX
			then { { b.minX, (b.minZ + b.maxZ) / 2, -90 }, { b.maxX, (b.minZ + b.maxZ) / 2, 90 } }
			else { { (b.minX + b.maxX) / 2, b.minZ, 180 }, { (b.minX + b.maxX) / 2, b.maxZ, 0 } }
		for _, e in ends do
			add(item("post", "dress", names, { x = e[1], y = floorY, z = e[2], yaw = e[3] }, { 1, 1, 1 }, "laser", i))
		end
	end

	---------------------------------------------------------------- hides
	for i, hdef in level.hides do
		local hb = hdef.box
		local plate: any = nil
		for _, p in level.plates do
			local pcx, pcz = (p.box.minX + p.box.maxX) / 2, (p.box.minZ + p.box.maxZ) / 2
			if pcx > hb.minX and pcx < hb.maxX and pcz > hb.minZ and pcz < hb.maxZ then
				plate = { pcx, pcz }
			end
		end
		local name = hidePiece(hdef, plate ~= nil, location)
		local names = groups[name] or { name }
		if name == "Xmas_Tree" then
			names = groups.Xmas_Tree or { name }
		end
		if not hasAll(names) then
			continue
		end
		local cx, cz = (hb.minX + hb.maxX) / 2, (hb.minZ + hb.maxZ) / 2
		local dir = openSide(level, footprint, cx, cz, nil, nil, nil)
		local yaw = dir.yaw
		if name == "Hide_CoatRack" then
			-- open at both X ends: run the rack across the direction with most room
			yaw = if dir.name == "-X" or dir.name == "+X" then 0 else 90
		end
		local lo, hi = scene(names)
		local pivot: Pivot
		local niche = NICHE[name]
		if plate and niche then
			local rx, rz = KitPlan.rotate(yaw, niche[1], niche[2])
			pivot = { x = plate[1] - rx, y = floorY - lo[2], z = plate[2] - rz, yaw = yaw }
		else
			pivot = KitPlan.place(lo, hi, cx, floorY, cz, yaw)
		end
		add(item("hide", "dress", names, pivot, { 1, 1, 1 }, "hide", i))
	end

	---------------------------------------------------------------- switches
	local switchNames = groups.Switch_Wall
	if switchNames and hasAll(switchNames) then
		for i, sw in level.switches do
			local dir = openSide(level, footprint, sw.x, sw.z, nil, nil, prefer)
			-- The switch's back (local Z 0) goes on a solid face: the face of the solid the
			-- point sits in (on the open side), else the first solid behind the point.
			local px, pz = sw.x, sw.z
			local host: Box? = nil
			for _, s in solids do
				if inside2(s.box, sw.x, sw.z) then
					host = s.box
				end
			end
			if host then
				local b = host :: Box
				if dir.dx ~= 0 then
					px = if dir.dx > 0 then b.maxX else b.minX
				else
					pz = if dir.dz > 0 then b.maxZ else b.minZ
				end
			else
				local back = room(level, footprint, sw.x, sw.z, -dir.dx, -dir.dz, nil)
				if back < 2 then
					local d = math.max(0, back - 0.5)
					px, pz = sw.x - dir.dx * d, sw.z - dir.dz * d
				end
			end
			add(
				item(
					"switch",
					"visual",
					switchNames,
					{ x = px, y = floorY, z = pz, yaw = dir.yaw },
					{ 1, 1, 1 },
					"switch",
					i
				)
			)
		end
	end

	---------------------------------------------------------------- signature props
	-- Each location's signature silhouette (PLAN_STEAM_PLUS §3.1, W5) from Heist/LevelDress `props`: the piece's
	-- own pivot at (x, floor + y, z), turned by yaw. Visual only; the unit spec keeps them off every sim box,
	-- plate, loot point, nav point, spawn and door.
	local props = o.dress and o.dress.props
	if props then
		for _, pr in props do
			if has(pr.piece) then
				add(
					item(
						"signature",
						"visual",
						{ pr.piece },
						{ x = pr.x, y = floorY + (pr.y or 0), z = pr.z, yaw = pr.yaw or 0 },
						{ 1, 1, 1 }
					)
				)
			end
		end
	end

	---------------------------------------------------------------- lamps
	-- Lamp_Ceiling over every indoor lamp, a StreetLamp post under every street lamp (the light and its floor
	-- pool are LevelBuilder's, on the greybox).
	local lampNames = groups.Lamp_Ceiling
	local streetNames = groups.StreetLamp
	if o.lighting then
		local hang = o.lighting.LAMP_HANG_Y - 12 -- the pieces' pivot is 12 studs up (manifest origin)
		for k, l in KitPlan.lamps(level, o.dress, o.lighting) do
			local it: Item? = nil
			if l.kind == "street" then
				if streetNames and hasAll(streetNames) then
					it = item("lamp", "visual", streetNames, { x = l.x, y = floorY, z = l.z, yaw = 0 }, { 1, 1, 1 })
				end
			elseif lampNames and hasAll(lampNames) then
				it = item("lamp", "visual", lampNames, { x = l.x, y = floorY + hang, z = l.z, yaw = 0 }, { 1, 1, 1 })
			end
			if it then
				it.ref = "lamp"
				it.index = k
				add(it)
			end
		end
	end

	---------------------------------------------------------------- rugs
	-- Warm rugs inside the light pools (LevelDress `rugs`, PLAN_STEAM_PLUS §3.1 W3): flat, visual only, a hair
	-- above the floor tiles and under the lamp pools (cfg.RUG_LIFT); scale stretches the rug (a doormat).
	local rugs = o.dress and o.dress.rugs
	if o.lighting and rugs and has("Rug_8x6") then
		for _, r in rugs do
			add(
				item(
					"rug",
					"visual",
					{ "Rug_8x6" },
					{ x = r.x, y = floorY + o.lighting.RUG_LIFT, z = r.z, yaw = r.yaw or 0 },
					{ r.sx or 1, 1, r.sz or 1 }
				)
			)
		end
	end

	---------------------------------------------------------------- van
	local vanNames = groups.Van
	if vanNames and hasAll(vanNames) then
		local v = level.van
		local lo, hi = scene(vanNames)
		local cx, cz = (v.minX + v.maxX) / 2, v.maxZ + 4.5
		local pivot = KitPlan.place(lo, hi, cx, floorY, cz, 0)
		local van = item("van", "visual", vanNames, pivot, { 1, 1, 1 }, "van", 1)
		add(van)
		plan.vanBox = KitPlan.itemBox(van, specs)
	end

	return plan
end

return table.freeze(KitPlan)
