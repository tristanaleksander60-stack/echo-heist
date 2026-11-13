--!strict
-- Heist/TowerPlan: the BIG building over a level's playable ground floor (PLAN_FIRST_PERSON §5 "BIG"; numbers in
-- Config.Big; docs/audit/LEVELS.md §11). Pure: no requires and no engine calls (the caller passes Config.Big, the
-- sign texts and Heist/KitPlan), so tests/unit/HeistTowerPlan.spec.luau checks it in Lune, tools/blender/level_plan.luau
-- dumps it for the renders, and server Heist/Overhead builds it into the level's "Overhead" model.
--
-- What it plans, on the building's outer box (KitPlan.buildingBox: the street front at +Z, the kit walls 2 thick on
-- the sim's wall lines, so the outer faces are the lines + 1):
--   * the ceiling over the playable rooms: Ceiling_8x8 tiles line to line, their coffered underside on the wall tops
--     (CEIL_Y: Lamp_Ceiling's pivot), so first person never sees sky indoors;
--   * the band over the wall tops, then STOREYS of facade shell on all four faces (Facade_8x10 bays: a tintable body
--     with a window opening and the atlas trim; a Part pane in each, lit Bulb Warm or a dark night pane, seeded;
--     curtains in some lit ones), corner quoins and piers, the crown cornice (Cornice_8) and a parapet;
--   * the roof (snow) and its details per location (Config.Big.STYLES): the Corner Shop tenement's fire escapes,
--     water tank, chimneys and antenna; the Toy Shop department store's big lit sign and the giant toy soldier on the
--     roof edge; the Bank's giant order of columns, entablature with its name, pediment and clock;
--   * the Christmas light strings along the band and under the crown (the level's dressing layer).
-- Every piece belongs to one cut-away group (the client Heist/CutAway hides groups between the camera and its subject:
-- "ceiling", "roof", and the four faces "front" / "back" / "left" / "right" with their outward normals) and one layer
-- ("base"; "detail": hidden from Config.Big.DETAIL_OFF_TIER, the back and side faces' trims and crowns and the
-- curtains; "fine": hidden from FINE_OFF_TIER, the coffered ceiling tiles (a flat slab inside them takes over), the
-- fire escapes and rooftop props; "xmas": the dressing layer's light strings, hidden like "fine").
-- Nothing here collides or is queried; the sim never sees it. The playable footprint is never touched: everything
-- is at or above the wall tops, or outside the outer faces above the street front's 12-stud storey.

local TowerPlan = {}

export type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }
export type Pivot = { x: number, y: number, z: number, yaw: number }
export type Item = {
	pieces: { string },
	pivot: Pivot,
	scale: { number },
	group: string,
	layer: string,
	color: { number }?, -- tintable pieces (Facade_8x10_Body)
	role: string,
}
export type PartSpec = {
	name: string,
	size: { number },
	pos: { number }, -- centre (level space)
	yaw: number,
	color: { number },
	material: string, -- "SmoothPlastic" | "Neon"
	group: string,
	layer: string,
	sign: { text: string, color: { number }, face: string, vertical: boolean? }?,
}
export type Group = {
	name: string,
	kind: string, -- "ceiling" | "roof" | "face"
	box: Box,
	normal: { number }?, -- faces: outward (x, z)
	plane: number?, -- faces: the outer plane's coordinate on the normal's axis
}
export type Plan = {
	location: string,
	style: string,
	storeys: number,
	outer: { minX: number, maxX: number, minZ: number, maxZ: number },
	floorY: number,
	ceilY: number,
	topY: number, -- the top storey's line (the crown cornice sits on it)
	items: { Item },
	parts: { PartSpec },
	groups: { Group },
	windows: number,
	lit: number,
}
export type Deps = {
	cfg: any, -- Config.Big
	KP: any, -- Heist/KitPlan
	signs: { [string]: string }?, -- Strings.BIG_SIGN
}
export type Options = {
	location: string?, -- KitPlan.location (default: the spec's)
	dressing: boolean?, -- Christmas layer (light strings)
	seed: number?, -- default: the level's num
}

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return { minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ }
end

-- Park-Miller "minimal standard" (exact in doubles), like Shared/Heist/TownPlan.
local function stream(seed: number): () -> number
	local s = math.floor(math.abs(seed)) % 2147483646 + 1
	return function(): number
		s = (s * 16807) % 2147483647
		return (s - 1) / 2147483646
	end
end

type Face = {
	name: string,
	axis: string, -- the run's axis: "X" (front / back) or "Z" (left / right)
	a: number, -- the run along the axis
	b: number,
	plane: number, -- the outer plane (z for front / back, x for left / right)
	n: number, -- the outward normal's sign on the other axis
	yaw: number, -- a wall module's yaw so its front (-Z) faces out
	ext: number, -- +1: a module extends toward +axis from its pivot, -1 toward -axis
}

-- The planned BIG building for a compiled level (Sim/LevelSpec), or nil when it has no building walls or Big is off.
function TowerPlan.plan(level: any, specs: { [string]: any }?, opts: Options?, deps: Deps): Plan?
	local cfg, KP = deps.cfg, deps.KP
	if not cfg.ENABLED then
		return nil
	end
	local bb = KP.buildingBox(level)
	if bb == nil then
		return nil
	end
	local o: Options = opts or {}
	local kit: { [string]: any } = specs or {}
	local location = o.location or KP.location(level, o.dressing == true)
	local styleName = if cfg.STYLES[location] then location else "CornerShop"
	local S = cfg.STYLES[styleName]
	local rnd = stream((o.seed or level.num or 1) * 7919 + #styleName)
	local fy = level.floorY or 0
	-- the outer faces: the sim's wall lines (bb inset by half a sim wall) + 1 (the kit wall's outer half)
	local x0, x1, z0, z1 = bb.minX - 0.5, bb.maxX + 0.5, bb.minZ - 0.5, bb.maxZ + 0.5
	local lx0, lx1, lz0, lz1 = bb.minX + 0.5, bb.maxX - 0.5, bb.minZ + 0.5, bb.maxZ - 0.5 -- the wall lines
	local ceilY = fy + cfg.CEIL_Y
	local y0 = ceilY + cfg.BAND
	local N = S.storeys
	local H = cfg.STOREY
	local top = y0 + N * H
	local D = cfg.WALL_DEPTH
	local body = S.body[math.floor(rnd() * #S.body) + 1]
	local plan: Plan = {
		location = location,
		style = styleName,
		storeys = N,
		outer = { minX = x0, maxX = x1, minZ = z0, maxZ = z1 },
		floorY = fy,
		ceilY = ceilY,
		topY = top,
		items = {},
		parts = {},
		groups = {},
		windows = 0,
		lit = 0,
	}
	local function has(name: string): boolean
		return kit[name] ~= nil
	end
	local function scene(name: string): ({ number }, { number })
		local s = kit[name]
		local lo, hi = {}, {}
		for k = 1, 3 do
			lo[k] = s.origin[k] + s.boundsMin[k]
			hi[k] = s.origin[k] + s.boundsMax[k]
		end
		return lo, hi
	end
	local function item(pieces: { string }, pivot: Pivot, scale: { number }, group: string, layer: string, role: string)
		local it: Item = { pieces = pieces, pivot = pivot, scale = scale, group = group, layer = layer, role = role }
		table.insert(plan.items, it)
		return it
	end
	local function part(
		name: string,
		size: { number },
		pos: { number },
		color: { number },
		group: string,
		layer: string?,
		material: string?,
		yaw: number?
	): PartSpec
		local p: PartSpec = {
			name = name,
			size = size,
			pos = pos,
			yaw = yaw or 0,
			color = color,
			material = material or "SmoothPlastic",
			group = group,
			layer = layer or "base",
		}
		table.insert(plan.parts, p)
		return p
	end
	-- an axis-aligned slab from box corners
	local function slab(name: string, b: Box, color: { number }, group: string, layer: string?, material: string?)
		return part(
			name,
			{ b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ },
			{ (b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2, (b.minZ + b.maxZ) / 2 },
			color,
			group,
			layer,
			material
		)
	end

	local faces: { Face } = {
		{ name = "front", axis = "X", a = x0, b = x1, plane = z1, n = 1, yaw = 180, ext = 1 },
		{ name = "back", axis = "X", a = x0, b = x1, plane = z0, n = -1, yaw = 0, ext = -1 },
		{ name = "left", axis = "Z", a = z0 + D, b = z1 - D, plane = x0, n = -1, yaw = 90, ext = 1 },
		{ name = "right", axis = "Z", a = z0 + D, b = z1 - D, plane = x1, n = 1, yaw = -90, ext = -1 },
	}
	-- a point on a face: s along the run, `out` studs outward from the outer plane (negative: inward)
	local function onFace(f: Face, s: number, y: number, out: number): { number }
		if f.axis == "X" then
			return { s, y, f.plane + f.n * out }
		end
		return { f.plane + f.n * out, y, s }
	end
	-- a box on a face: [s0, s1] along the run, [y0, y1], [i0, i1] studs inward from the outer plane
	local function faceBox(f: Face, s0: number, s1: number, ya: number, yb: number, i0: number, i1: number): Box
		local p0, p1 = f.plane - f.n * i0, f.plane - f.n * i1
		local lo, hi = math.min(p0, p1), math.max(p0, p1)
		if f.axis == "X" then
			return box(s0, ya, lo, s1, yb, hi)
		end
		return box(lo, ya, s0, hi, yb, s1)
	end
	-- a wall-module piece's pivot for the module spanning [s, s + w] along the face (front plane on the outer plane)
	local function modulePivot(f: Face, s: number, w: number, y: number, out: number?): Pivot
		local along = if f.ext > 0 then s else s + w
		local p = onFace(f, along, y, out or 0)
		return { x = p[1], y = p[2], z = p[3], yaw = f.yaw }
	end

	---------------------------------------------------------------- groups
	local reach = 4.5 -- how far face pieces project (columns, signs, fire escapes)
	local roofTop = top + cfg.CORNICE_H + cfg.PARAPET + 30 -- rooftop props and the soldier
	table.insert(plan.groups, { name = "ceiling", kind = "ceiling", box = box(lx0, ceilY, lz0, lx1, y0, lz1) })
	table.insert(plan.groups, { name = "roof", kind = "roof", box = box(x0, top, z0, x1, roofTop, z1) })
	for _, f in faces do
		local g = faceBox(f, f.a - D, f.b + D, ceilY, top + cfg.CORNICE_H + cfg.PARAPET, -reach, D + 0.7)
		table.insert(plan.groups, {
			name = f.name,
			kind = "face",
			box = g,
			normal = if f.axis == "X" then { 0, f.n } else { f.n, 0 },
			plane = f.plane,
		})
	end

	---------------------------------------------------------------- the ceiling
	if has("Ceiling_8x8") then
		local lo, hi = scene("Ceiling_8x8")
		for _, tx in KP.tiles(lx0, lx1) do
			for _, tz in KP.tiles(lz0, lz1) do
				local pivot, scale = KP.fit(lo, hi, box(tx[1], ceilY, tz[1], tx[2], ceilY + cfg.CEIL_DEPTH, tz[2]), 0)
				item({ "Ceiling_8x8" }, pivot, scale, "ceiling", "fine", "ceiling")
			end
		end
		-- the low tiers' ceiling: one flat slab inside the tiles' plates (hidden by them until FINE_OFF_TIER hides the
		-- tiles; then its underside, 0.3 over the wall tops, is the ceiling: still never the sky)
		slab("CeilingFlat", box(lx0, ceilY + 0.3, lz0, lx1, ceilY + 0.4, lz1), cfg.TRIM, "ceiling")
	else
		slab("Ceiling", box(lx0, ceilY, lz0, lx1, ceilY + cfg.CEIL_DEPTH, lz1), cfg.TRIM, "ceiling")
	end
	-- the hollow between the ceiling and the roof is never seen; a lid over the ceiling hides the shell's inside from
	-- the diorama's high angles while the faces are cut away and the ceiling stays (subject outside, camera above)
	slab("CeilingLid", box(lx0, ceilY + cfg.CEIL_DEPTH, lz0, lx1, ceilY + cfg.CEIL_DEPTH + 0.2, lz1), S.band, "ceiling")

	---------------------------------------------------------------- the band over the wall tops (12 - 14)
	for _, f in faces do
		slab(
			"Band",
			faceBox(f, f.a - (if f.axis == "Z" then D else 0), f.b + (if f.axis == "Z" then D else 0), ceilY, y0, 0, 2),
			S.band,
			f.name
		)
	end

	---------------------------------------------------------------- the storeys
	local G = cfg.GLASS
	local bodyPieces = { "Facade_8x10_Body", "Facade_8x10" }
	local kitFacade = has("Facade_8x10_Body") and has("Facade_8x10")
	local fireAt: { [string]: number } = {} -- face -> the module index carrying the fire escape
	if S.fireEscape then
		fireAt.front = -1 -- the last module (the street front's right end, clear of the entrance)
		fireAt.left = -1 -- the side's street end
	end
	local signW = S.sign and S.sign.kind == "board" and S.sign.w or 0
	for _, f in faces do
		local len = f.b - f.a
		local n = math.max(0, math.floor((len + 1e-6) / 8))
		local pier = (len - n * 8) / 2
		for side = 0, 1 do
			if pier > 0.05 then
				local s0 = if side == 0 then f.a else f.b - pier
				slab("Pier", faceBox(f, s0, s0 + pier, y0, top, 0.3, D), body, f.name)
			end
		end
		for st = 1, N do
			local yb = y0 + (st - 1) * H
			for m = 1, n do
				local s = f.a + pier + (m - 1) * 8
				local mid = s + 4
				-- the board sign covers the front's middle bays on the first storey: no window there
				local covered = signW > 0
					and f.name == "front"
					and st == 1
					and math.abs(mid - (x0 + x1) / 2) < signW / 2
				local pivot = modulePivot(f, s, 8, yb)
				local lit = rnd() < G.litShare
				local curtain = lit and rnd() < G.curtainShare
				local trimLayer = if f.name == "front" then "base" else "detail"
				if kitFacade then
					local it = item({ bodyPieces[1] }, pivot, { 1, 1, 1 }, f.name, "base", "facade")
					it.color = body
					item({ bodyPieces[2] }, pivot, { 1, 1, 1 }, f.name, trimLayer, "trim")
				else
					slab("Facade", faceBox(f, s, s + 8, yb, yb + H, 0.3, D), body, f.name)
				end
				if not covered then
					plan.windows += 1
					plan.lit += if lit then 1 else 0
					-- the pane (3.6 x 5.6) in the opening, behind the mullions
					local c = onFace(f, mid, yb + 5.4, -G.inset - 0.03)
					local size = if f.axis == "X" then { 3.6, 5.6, 0.06 } else { 0.06, 5.6, 3.6 }
					part(
						"Pane",
						size,
						c,
						if lit then G.lit else G.dark,
						f.name,
						"base",
						if lit then "Neon" else "SmoothPlastic"
					)
					if curtain and has("Facade_Curtain") then
						item({ "Facade_Curtain" }, pivot, { 1, 1, 1 }, f.name, "detail", "curtain")
					end
				end
				local fe = fireAt[f.name]
				if fe and has("FireEscape_8x10") and (m == (if fe < 0 then n + 1 + fe else fe)) then
					item({ "FireEscape_8x10" }, pivot, { 1, 1, 1 }, f.name, "fine", "fireEscape")
				end
			end
		end
		-- the crown cornice on the top storey's line, then the parapet behind it
		local runA = f.a - (if f.axis == "Z" then D else 0)
		local runB = f.b + (if f.axis == "Z" then D else 0)
		if has("Cornice_8") then
			local lo, hi = scene("Cornice_8")
			for _, t in KP.tiles(runA, runB) do
				local w = t[2] - t[1]
				local pivot = modulePivot(f, t[1], w, top)
				-- the street front keeps its crown at every tier; the other faces' crowns are detail (tier 3+ hides them)
				local layer = if f.name == "front" then "base" else "detail"
				item({ "Cornice_8" }, pivot, { w / (hi[1] - lo[1]), 1, 1 }, f.name, layer, "cornice")
			end
		else
			slab("Cornice", faceBox(f, runA, runB, top, top + cfg.CORNICE_H, -1.4, D), cfg.TRIM, f.name)
		end
		slab(
			"Parapet",
			faceBox(f, runA, runB, top + cfg.CORNICE_H - 0.1, top + cfg.CORNICE_H + cfg.PARAPET, 0.3, D),
			body,
			f.name
		)
		slab(
			"Coping",
			faceBox(
				f,
				runA,
				runB,
				top + cfg.CORNICE_H + cfg.PARAPET,
				top + cfg.CORNICE_H + cfg.PARAPET + 0.3,
				0.15,
				D + 0.15
			),
			cfg.SNOW,
			f.name
		)
		-- Christmas light strings on the street front: along the band and under the crown
		if f.name == "front" and o.dressing and has("Xmas_Lights_8") and has("Xmas_Lights_8_Bulbs") then
			local _, hi = scene("Xmas_Lights_8")
			for _, line in { { y0 - 0.15, 0.32 }, { top - 0.25, 0 } } do
				for _, t in KP.tiles(x0 + 1, x1 - 1) do
					local w = t[2] - t[1]
					local pivot = modulePivot(f, t[1], w, line[1] - hi[2], line[2])
					item({ "Xmas_Lights_8", "Xmas_Lights_8_Bulbs" }, pivot, { w / 8, 1, 1 }, "front", "xmas", "lights")
				end
			end
		end
	end
	-- corner quoins: a stone column on each outer corner over the full height of the shell
	for _, c in { { x0, z0 }, { x1, z0 }, { x0, z1 }, { x1, z1 } } do
		local sx = if c[1] < (x0 + x1) / 2 then 1 else -1
		local sz = if c[2] < (z0 + z1) / 2 then 1 else -1
		local ax, bx = c[1] - sx * 0.25, c[1] + sx * 1.6
		local az, bz = c[2] - sz * 0.25, c[2] + sz * 1.6
		slab(
			"Quoin",
			box(math.min(ax, bx), y0, math.min(az, bz), math.max(ax, bx), top, math.max(az, bz)),
			S.band,
			if c[1] < (x0 + x1) / 2 then "left" else "right"
		)
	end

	---------------------------------------------------------------- the roof
	local roofY = top + cfg.ROOF_LIFT
	slab("RoofSnow", box(x0 + D, top - 0.4, z0 + D, x1 - D, roofY, z1 - D), cfg.SNOW, "roof")
	local hx, hz = (x1 - x0) / 2 - D - 3.5, (z1 - z0) / 2 - D - 3.5
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	for _, r in S.roof or {} do
		if has(r.piece) then
			local lo, hi = scene(r.piece)
			local pivot = KP.place(lo, hi, cx + r.at[1] * hx, roofY, cz + r.at[2] * hz, r.yaw)
			item({ r.piece }, pivot, { 1, 1, 1 }, "roof", "fine", "roofProp")
		end
	end
	if S.soldier and has("ToySoldier") then
		local so = S.soldier
		local lo, hi = scene("ToySoldier")
		local pivot = KP.place(lo, hi, cx + so.at[1] * hx, roofY, cz + so.at[2] * hz, so.yaw, so.scale)
		item({ "ToySoldier" }, pivot, { so.scale, so.scale, so.scale }, "roof", "base", "soldier")
	end

	---------------------------------------------------------------- the street front's signature
	local sign = S.sign
	local signText = deps.signs and deps.signs[styleName] or ""
	if S.kind == "tenement" and sign then
		-- a blade sign off the front's left end, over the band (seen down the street)
		local sx = x0 + 3.2
		local p = part(
			"SignBlade",
			{ 0.5, sign.h, sign.w },
			{ sx, y0 + 1 + sign.h / 2, z1 + sign.w / 2 + 0.2 },
			sign.color,
			"front"
		)
		p.sign = { text = signText, color = sign.text, face = "sides", vertical = true }
		slab(
			"SignBracket",
			box(sx - 0.15, y0 + sign.h - 0.2, z1, sx + 0.15, y0 + sign.h + 0.2, z1 + sign.w + 0.4),
			cfg.TRIM,
			"front"
		)
	elseif S.kind == "store" and sign then
		-- the department store's big lit board over the entrance, framed in Bulb Warm Neon
		local w, h = sign.w, sign.h
		local yc = y0 + 0.4 + h / 2
		local p = part("SignBoard", { w, h, 0.6 }, { cx, yc, z1 + 0.6 }, sign.color, "front")
		p.sign = { text = signText, color = sign.text, face = "front" }
		for _, e in { { 0, h / 2 }, { 0, -h / 2 } } do
			part(
				"SignFrame",
				{ w + 0.5, 0.25, 0.25 },
				{ cx + e[1], yc + e[2], z1 + 0.95 },
				G.lit,
				"front",
				"base",
				"Neon"
			)
		end
		for _, sx in { -w / 2, w / 2 } do
			part("SignFrame", { 0.25, h + 0.5, 0.25 }, { cx + sx, yc, z1 + 0.95 }, G.lit, "front", "base", "Neon")
		end
	elseif S.kind == "bank" then
		-- a giant order over the front's centre: a ledge, columns, the entablature with the bank's name, the pediment
		local nCol = S.columns or 6
		local cs = S.columnScale or { 1.5, 2.5, 1.5 }
		local span = math.min(x1 - x0 - 6, 36)
		local ledgeZ = z1 + 4
		slab("Ledge", box(cx - span / 2 - 1, y0 - 1, z1, cx + span / 2 + 1, y0, ledgeZ), cfg.TRIM, "front")
		local colTop = top
		if has("Column_2x12") then
			local lo, hi = scene("Column_2x12")
			local hgt = (colTop - y0) / (hi[2] - lo[2])
			for k = 0, nCol - 1 do
				local x = cx - span / 2 + 2 + k * (span - 4) / (nCol - 1)
				local pivot = KP.place(lo, hi, x, y0, z1 + 2, 0)
				item({ "Column_2x12" }, pivot, { cs[1], hgt, cs[3] }, "front", "base", "column")
			end
		end
		local ent = part(
			"Entablature",
			{ span + 2, sign and sign.h or 2.2, ledgeZ - z1 },
			{ cx, colTop + (sign and sign.h or 2.2) / 2, (z1 + ledgeZ) / 2 },
			cfg.TRIM,
			"front"
		)
		if sign then
			ent.sign = { text = signText, color = sign.text, face = "front" }
		end
		local pedY = colTop + (sign and sign.h or 2.2)
		if has("Pediment_24") then
			local lo, hi = scene("Pediment_24")
			local pivot, scale =
				KP.fit(lo, hi, box(cx - span / 2 - 1, pedY, z1 + 0.3, cx + span / 2 + 1, pedY + 7.5, ledgeZ), 180)
			item({ "Pediment_24" }, pivot, scale, "front", "base", "pediment")
		end
		if has("Clock_6") then
			local lo, hi = scene("Clock_6")
			local k = 0.55
			-- the clock's origin is its back centre: on the tympanum's face, facing the street
			local pivot = { x = cx, y = pedY + 2.7 - (lo[2] + hi[2]) / 2 * k, z = ledgeZ - 1.5, yaw = 180 }
			item({ "Clock_6" }, pivot, { k, k, k }, "front", "base", "clock")
		end
	end
	-- each group's box holds everything filed under it (a face's columns, signs and the Bank's pediment reach out and up)
	local byName: { [string]: Group } = {}
	for _, g in plan.groups do
		byName[g.name] = g
	end
	local function grow(name: string, b: Box)
		local g = byName[name]
		if g then
			local gb = g.box
			gb.minX, gb.maxX = math.min(gb.minX, b.minX), math.max(gb.maxX, b.maxX)
			gb.minY, gb.maxY = math.min(gb.minY, b.minY), math.max(gb.maxY, b.maxY)
			gb.minZ, gb.maxZ = math.min(gb.minZ, b.minZ), math.max(gb.maxZ, b.maxZ)
		end
	end
	for _, p in plan.parts do
		local sx, sz = p.size[1], p.size[3]
		if math.abs(p.yaw % 180 - 90) < 1e-6 then
			sx, sz = sz, sx
		end
		local c = p.pos
		grow(
			p.group,
			box(c[1] - sx / 2, c[2] - p.size[2] / 2, c[3] - sz / 2, c[1] + sx / 2, c[2] + p.size[2] / 2, c[3] + sz / 2)
		)
	end
	for _, it in plan.items do
		grow(it.group, KP.itemBox(it, kit))
	end
	return plan
end

-- Whether a layer shows at a performance tier (client Heist/CutAway keeps to the same rule).
function TowerPlan.layerOn(layer: string, tier: number, cfg: any): boolean
	if layer == "detail" then
		return tier < cfg.DETAIL_OFF_TIER
	elseif layer == "fine" or layer == "xmas" then
		return tier < cfg.FINE_OFF_TIER
	end
	return true
end

-- A group's parts and items, by group name (the builder files them under one Model each).
function TowerPlan.groupNames(plan: Plan): { string }
	local out = {}
	for _, g in plan.groups do
		table.insert(out, g.name)
	end
	return out
end

-- Whether a level-space point (x, z) is under the planned ceiling, and the ceiling's underside there (the unit spec's
-- "look up" check: every room centre has a ceiling over it; the engine check raycasts the built parts).
function TowerPlan.ceilingOver(plan: Plan, x: number, z: number): number?
	for _, g in plan.groups do
		if g.kind == "ceiling" then
			local b = g.box
			if x >= b.minX - 1e-6 and x <= b.maxX + 1e-6 and z >= b.minZ - 1e-6 and z <= b.maxZ + 1e-6 then
				return b.minY
			end
		end
	end
	return nil
end

-- What the building costs at a tier: instances, triangles, draw calls. kitTris = { [piece] = tris } (kit_manifest).
-- Parts batch by material (SmoothPlastic, Neon); each kit piece is one draw however many copies; each sign gui one.
-- Hidden layers (tier >= cfg.DETAIL_OFF_TIER: "detail" and "xmas") cost no triangles or draws but keep instances.
function TowerPlan.budget(plan: Plan, tier: number, kitTris: { [string]: number }, cfg: any): (number, number, number)
	local instances, tris = 0, 0
	local batches: { [string]: boolean } = {}
	local function on(layer: string): boolean
		return TowerPlan.layerOn(layer, tier, cfg)
	end
	for _, p in plan.parts do
		instances += 1
		if p.sign then
			instances += 3 -- SurfaceGui + label (+ a second face)
			batches["gui:" .. p.name] = true
		end
		if on(p.layer) then
			tris += 12
			batches[p.material] = true
		end
	end
	for _, it in plan.items do
		instances += #it.pieces
		if on(it.layer) then
			for _, name in it.pieces do
				tris += kitTris[name] or 12
				batches["kit:" .. name] = true
			end
		end
	end
	instances += 1 + #plan.groups -- the Overhead model and one Model per group
	local draws = 0
	for _ in batches do
		draws += 1
	end
	return draws, tris, instances
end

return table.freeze(TowerPlan)
