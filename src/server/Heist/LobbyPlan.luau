--!strict
-- Heist/LobbyPlan: the garage v1 layout (PLAN_STEAM_PLUS §4.1 W6, docs/GOLDEN_FRAMES.md G3), pure. Heist/Lobby
-- builds it in the engine; tests/unit/HeistLobbyPlan.spec.luau checks it in Lune (8 bays, the light budget, the
-- spawn and the aisle clear, every kit piece inside the lot) and tools/blender/level_shots.py --garage renders it.
-- No requires: the caller passes Config.Lobby, Config.Lighting, the kit specs (Kit/KitData parts) and Heist/KitPlan
-- (its placement maths), so the same plan runs on the server and in Lune.
--
-- Local space (Config.Heist.LOBBY_ORIGIN, floor y = 0): the interior is |x| <= HALF_X, |z| <= HALF_Z; the wall band
-- WALL_T thick runs outside it; the back wall (-Z) carries the GarageDoor_16x12 at DOOR_X, opening onto a street
-- apron STREET_DEPTH deep. Vans park side-on against the back and front walls with their open doors to the aisle.

local LobbyPlan = {}

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }
export type Item = {
	role: string, -- wall | door | floor | van | lamp | board | trophy | snow | rug
	mode: string,
	pieces: { string },
	pivot: { x: number, y: number, z: number, yaw: number },
	scale: { number },
	layer: string,
	index: number?, -- bay (van, lamp) or lamp index
	color: { number }?, -- Van_Paint colour (van items), a facade body's runtime colour
	group: string?, -- the warehouse's cut-away group (Garage/Overhead/<group>); nil = the garage's Kit model
}
-- A plain part (the warehouse shell, its stations' dressing, the mezzanine): centre, size, colour; collide = a
-- greybox collider (the mezzanine deck, posts, rail and stair), group = the cut-away group it is filed under.
export type PartSpec = {
	name: string,
	size: { number },
	pos: { number },
	yaw: number?,
	color: { number },
	material: string?, -- "SmoothPlastic" (default) | "Neon" | "Glass" | "Brick" | "Wood" | "Metal"
	alpha: number?,
	collide: boolean?,
	wedge: boolean?, -- a WedgePart (the stair's collider: low at its front, -Z; its vertical face is Back, +Z)
	group: string?,
	gui: { text: string, color: { number }, face: string }?,
}
export type Anchor = { name: string, x: number, y: number, z: number, yaw: number }
export type Bay = {
	index: number,
	row: string,
	x: number,
	z: number,
	yaw: number,
	paint: { number },
	collider: Box, -- the van's footprint: the garage's own (invisible once dressed) van collider
	yours: boolean,
}
export type Lamp = {
	kind: string, -- "work" | "yours" | "trophy" | "street"
	x: number,
	y: number, -- the light's height above the floor
	z: number,
	range: number,
	brightness: number,
	color: { number },
	shadows: boolean,
	angle: number?, -- SpotLight (yours)
	pool: number?, -- floor pool diameter (nil: no pool)
	poolColor: { number }?,
	bay: number?,
}
export type Plan = {
	bounds: Rect, -- the lot: interior + walls + the street apron
	interior: Rect, -- the building footprint (no roof: snow off inside)
	floor: Box, -- greybox floor (the whole lot)
	walls: { Box }, -- greybox wall colliders (the door gap left open)
	bays: { Bay },
	lamps: { Lamp },
	items: { Item },
	spawn: { number },
	board: { x: number, z: number, yaw: number },
	card: { centre: { number }, size: { number }, yaw: number }, -- the NEXT card (world-local centre)
	lines: { Box }, -- painted bay lines (flat, visual)
	numbers: { { x: number, z: number, yaw: number, text: string } },
	-- the warehouse (Config.Lobby.WAREHOUSE): the shell over the ground course and the stations' dressing
	parts: { PartSpec },
	groups: { { name: string, kind: string, box: Box, normal: { number }?, plane: number? } },
	ceilY: number, -- the trusses' bottom chord: the cut-away's "camera above the ceiling" line
	topY: number,
	anchors: { Anchor }, -- JobBoardSpot, LaptopSpot, WardrobeSpot, TVSpot, CrewSign, VanBay1..8 (the LOBBY track)
}

local function rect(minX: number, maxX: number, minZ: number, maxZ: number): Rect
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
end

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return { minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ }
end

local function item(role: string, pieces: { string }, pivot: any, scale: { number }, index: number?): Item
	return {
		role = role,
		mode = "visual",
		pieces = pieces,
		pivot = pivot,
		scale = scale,
		layer = "base",
		index = index,
	}
end

-- The plan. cfg = Config.Lobby, light = Config.Lighting, specs = Kit/KitData parts (nil or {} = greybox only: no
-- items), KP = Heist/KitPlan.
function LobbyPlan.plan(cfg: any, light: any, specs: { [string]: any }?, KP: any, strings: any?): Plan
	local hx, hz, t, h = cfg.HALF_X, cfg.HALF_Z, cfg.WALL_T, cfg.WALL_H
	local kit: { [string]: any } = specs or {}
	local groups = KP.groups(kit)
	local function has(name: string): boolean
		return kit[name] ~= nil
	end
	local function hasAll(names: { string }?): boolean
		if not names or #names == 0 then
			return false
		end
		for _, n in names do
			if not has(n) then
				return false
			end
		end
		return true
	end
	local function scene(names: { string }): ({ number }, { number })
		local lo = { math.huge, math.huge, math.huge }
		local hi = { -math.huge, -math.huge, -math.huge }
		for _, n in names do
			local s = kit[n]
			for k = 1, 3 do
				lo[k] = math.min(lo[k], s.origin[k] + s.boundsMin[k])
				hi[k] = math.max(hi[k], s.origin[k] + s.boundsMax[k])
			end
		end
		return lo, hi
	end

	local plan: Plan = {
		bounds = rect(-hx - t, hx + t, -hz - t - cfg.STREET_DEPTH, hz + t),
		interior = rect(-hx, hx, -hz, hz),
		floor = box(-hx - t, -2, -hz - t - cfg.STREET_DEPTH, hx + t, 0, hz + t),
		walls = {},
		bays = {},
		lamps = {},
		items = {},
		spawn = { cfg.SPAWN[1], cfg.SPAWN[2] },
		board = { x = cfg.BOARD.x, z = cfg.BOARD.z, yaw = cfg.BOARD.yaw },
		card = { centre = { 0, 0, 0 }, size = cfg.BOARD.card.size, yaw = cfg.BOARD.yaw },
		lines = {},
		numbers = {},
		parts = {},
		groups = {},
		ceilY = 0,
		topY = 0,
		anchors = {},
	}

	---------------------------------------------------------------- walls (greybox colliders + kit tiles)
	local d0, d1 = cfg.DOOR_X - cfg.DOOR_W / 2, cfg.DOOR_X + cfg.DOOR_W / 2
	-- runs: { axis, line (the band's inner face), a, b }; X runs carry the corners
	local runs = {
		{ axis = "X", z0 = -hz - t, z1 = -hz, a = -hx - t, b = d0 },
		{ axis = "X", z0 = -hz - t, z1 = -hz, a = d1, b = hx + t },
		{ axis = "X", z0 = hz, z1 = hz + t, a = -hx - t, b = hx + t },
		{ axis = "Z", x0 = -hx - t, x1 = -hx, a = -hz, b = hz },
		{ axis = "Z", x0 = hx, x1 = hx + t, a = -hz, b = hz },
	}
	for _, r in runs do
		if r.axis == "X" then
			table.insert(plan.walls, box(r.a, 0, r.z0, r.b, h, r.z1))
		else
			table.insert(plan.walls, box(r.x0, 0, r.a, r.x1, h, r.b))
		end
		for _, tile in KP.tiles(r.a, r.b) do
			local name = if tile[3] == 8 then "Wall_8x12" else "Wall_4x12"
			if has(name) then
				local lo, hi = scene({ name })
				local b = if r.axis == "X"
					then KP.box(tile[1], 0, r.z0, tile[2], h, r.z1)
					else KP.box(r.x0, 0, tile[1], r.x1, h, tile[2])
				local pivot, scale = KP.fit(lo, hi, b, if r.axis == "X" then 0 else 90)
				table.insert(plan.items, item("wall", { name }, pivot, scale))
			end
		end
	end
	if has("GarageDoor_16x12") then
		local lo, hi = scene({ "GarageDoor_16x12" })
		local b = KP.box(d0, 0, -hz - t, d1, cfg.DOOR_H or h, -hz) -- the warehouse's big roll-up door
		local pivot, scale = KP.fit(lo, hi, b, 0)
		table.insert(plan.items, item("door", { "GarageDoor_16x12" }, pivot, scale))
	end

	---------------------------------------------------------------- floor tiles (inside)
	if has("Floor_8x8") then
		local lo, hi = scene({ "Floor_8x8" })
		local lift = 0.02
		for x = -hx, hx - 8, 8 do
			for z = -hz, hz - 8, 8 do
				local pivot, scale = KP.fit(lo, hi, KP.box(x, lift - 0.5, z, x + 8, lift, z + 8), 0)
				table.insert(plan.items, item("floor", { "Floor_8x8" }, pivot, scale))
			end
		end
	end

	---------------------------------------------------------------- bays, vans, lines, numbers
	local vanNames = groups.Van
	local vlo, vhi = { -7.45, 0, -3.74 }, { 7.45, 7.75, 3.34 } -- the kit van's scene box (greybox fallback)
	if hasAll(vanNames) then
		vlo, vhi = scene(vanNames :: { string })
	end
	local depth = vhi[3] - vlo[3]
	for i, b in cfg.BAYS do
		local back = b.row == "back"
		local z = if back then -hz + cfg.VAN_GAP + depth / 2 else hz - cfg.VAN_GAP - depth / 2
		local yaw = if back then 180 else 0
		local pivot = KP.place(vlo, vhi, b.x, 0, z, yaw)
		local paint = cfg.BAY_PAINTS[(i - 1) % #cfg.BAY_PAINTS + 1]
		local fake = item("van", vanNames or {}, pivot, { 1, 1, 1 }, i)
		local collider: Box
		if hasAll(vanNames) then
			collider = KP.itemBox(fake, kit)
			fake.color = paint
			table.insert(plan.items, fake)
		else
			local len = vhi[1] - vlo[1]
			collider = box(b.x - len / 2, 0, z - depth / 2, b.x + len / 2, vhi[2] - vlo[2], z + depth / 2)
		end
		table.insert(plan.bays, {
			index = i,
			row = b.row,
			x = b.x,
			z = z,
			yaw = yaw,
			paint = paint,
			collider = collider,
			yours = i == 1,
		})
		-- the work lamp hangs between the van's back and its wall (a warm wash on the brick, never over the open door
		-- from the aisle); your bay adds the key: a shadowed spot over the aisle in front of your van (no fixture)
		local W0 = cfg.WORK_LAMP
		table.insert(plan.lamps, {
			kind = "work",
			x = b.x,
			y = light.LIGHT_Y,
			z = z + (if back then -cfg.LAMP_OFFSET else cfg.LAMP_OFFSET),
			range = W0.range,
			brightness = W0.brightness,
			color = W0.color,
			shadows = false,
			pool = W0.pool,
			poolColor = W0.poolColor,
			bay = i,
		})
		if i == 1 then
			local Y = cfg.YOUR_LAMP
			table.insert(plan.lamps, {
				kind = "yours",
				x = b.x + Y.along,
				y = Y.y,
				z = z + (if back then Y.out else -Y.out),
				range = Y.range,
				brightness = Y.brightness,
				color = Y.color,
				shadows = true,
				angle = Y.angle,
				pool = Y.pool,
				poolColor = Y.poolColor,
				bay = i,
			})
		end
		-- the painted bay number on the floor at the aisle end of the bay
		local nz = z + (if back then depth / 2 + 2.6 else -depth / 2 - 2.6)
		table.insert(plan.numbers, { x = b.x, z = nz, yaw = if back then 0 else 180, text = tostring(i) })
	end
	-- bay lines: between neighbouring vans of a row and at the row ends, from the wall to the aisle end
	local W = cfg.BAY_LINE.width
	for _, row in { "back", "front" } do
		local xs = {}
		for _, b in cfg.BAYS do
			if b.row == row then
				table.insert(xs, b.x)
			end
		end
		table.sort(xs)
		local cuts = {}
		for k = 1, #xs - 1 do
			local m = (xs[k] + xs[k + 1]) / 2
			if row == "back" and m > d0 - 1 and m < d1 + 1 then
				-- the door between two bays: a line at each jamb instead
				table.insert(cuts, d0 - 0.5)
				table.insert(cuts, d1 + 0.5)
			else
				table.insert(cuts, m)
			end
		end
		local len = depth + 4
		for _, x in cuts do
			if row == "back" then
				table.insert(plan.lines, box(x - W / 2, 0, -hz, x + W / 2, 0.04, -hz + len))
			else
				table.insert(plan.lines, box(x - W / 2, 0, hz - len, x + W / 2, 0.04, hz))
			end
		end
	end

	---------------------------------------------------------------- aisle floods
	for _, a in cfg.AISLE_LAMPS do
		local A = cfg.AISLE_LAMP
		table.insert(plan.lamps, {
			kind = "aisle",
			x = a[1],
			y = light.LIGHT_Y,
			z = a[2],
			range = A.range,
			brightness = A.brightness,
			color = A.color,
			shadows = false,
			pool = A.pool,
			poolColor = A.poolColor,
		})
	end

	---------------------------------------------------------------- work-lamp and aisle fixtures
	local lampNames = groups.Lamp_Ceiling
	if hasAll(lampNames) then
		local hang = light.LAMP_HANG_Y - 12
		for k, l in plan.lamps do
			if l.kind ~= "work" and l.kind ~= "aisle" then
				continue
			end
			table.insert(
				plan.items,
				item("lamp", lampNames :: { string }, { x = l.x, y = hang, z = l.z, yaw = 0 }, { 1, 1, 1 }, k)
			)
		end
	end

	---------------------------------------------------------------- the trophy shelf beside your bay
	-- A Counter_8x2 against the back wall; an Ornament_Stand per trophy slot on its top, each ornament hung from its
	-- stand's arm tip (TROPHY_HANG, the stand's local axes); the first trophy lit (TROPHY_LIGHT).
	local TS = cfg.TROPHY_SHELF
	local top = 0
	if has("Counter_8x2") then
		local lo, hi = scene({ "Counter_8x2" })
		local pivot = KP.place(lo, hi, TS.x, 0, TS.z, TS.yaw)
		table.insert(plan.items, item("trophy", { "Counter_8x2" }, pivot, { 1, 1, 1 }))
		top = hi[2] - lo[2]
	end
	-- a piece's own origin (a stand's base, an ornament's hang point) at (x, y, z)
	local function at(name: string, x: number, y: number, z: number, yaw: number): any
		local o = kit[name].origin
		local ox, oz = KP.rotate(yaw, o[1], o[3])
		return { x = x - ox, y = y - o[2], z = z - oz, yaw = yaw }
	end
	if top > 0 and has("Ornament_Stand") then
		for _, tr in cfg.TROPHIES do
			table.insert(
				plan.items,
				item("trophy", { "Ornament_Stand" }, at("Ornament_Stand", tr.x, top, TS.z, TS.yaw), {
					1,
					1,
					1,
				})
			)
			if tr.ornament and has(tr.ornament) then
				local hang = cfg.TROPHY_HANG
				local hx2, hz2 = KP.rotate(TS.yaw, hang[1], hang[3])
				table.insert(
					plan.items,
					item("trophy", { tr.ornament }, at(tr.ornament, tr.x + hx2, top + hang[2], TS.z + hz2, TS.yaw), {
						1,
						1,
						1,
					})
				)
			end
		end
	end
	do
		local T, p = cfg.TROPHY_LIGHT, cfg.TROPHY_LIGHT_AT
		table.insert(plan.lamps, {
			kind = "trophy",
			x = p[1],
			y = p[2],
			z = p[3],
			range = T.range,
			brightness = T.brightness,
			color = T.color,
			shadows = false,
			bay = 1,
		})
	end

	---------------------------------------------------------------- outside: the street lamp and snow
	local S = light.LAMP.street
	table.insert(plan.lamps, {
		kind = "street",
		x = cfg.STREET_LAMP.x,
		y = S.lightY,
		z = cfg.STREET_LAMP.z,
		range = S.range,
		brightness = S.brightness,
		color = S.color,
		shadows = false,
		pool = S.pool,
		poolColor = S.poolColor,
	})
	local streetNames = groups.StreetLamp
	if hasAll(streetNames) then
		table.insert(
			plan.items,
			item(
				"lamp",
				streetNames :: { string },
				{ x = cfg.STREET_LAMP.x, y = 0, z = cfg.STREET_LAMP.z, yaw = 0 },
				{ 1, 1, 1 },
				#plan.lamps
			)
		)
	end
	if has("Xmas_SnowPile") then
		for _, sp in cfg.SNOW_PILES do
			table.insert(
				plan.items,
				item("snow", { "Xmas_SnowPile" }, { x = sp[1], y = 0, z = sp[2], yaw = sp[3] }, { 1, 1, 1 })
			)
		end
	end

	---------------------------------------------------------------- the job board and its NEXT card
	local B = cfg.BOARD
	if has("JobBoard") then
		local lo, hi = scene({ "JobBoard" })
		local pivot = KP.place(lo, hi, B.x, 0, B.z, B.yaw)
		table.insert(plan.items, item("board", { "JobBoard" }, pivot, { 1, 1, 1 }))
	end
	local c = B.card.centre
	local cx, cz = KP.rotate(B.yaw, c[1], c[3] - B.cardDepth / 2)
	plan.card = { centre = { B.x + cx, c[2], B.z + cz }, size = B.card.size, yaw = B.yaw }

	---------------------------------------------------------------- a rug at the spawn (the crews gather on it)
	if has("Rug_8x6") then
		table.insert(
			plan.items,
			item(
				"rug",
				{ "Rug_8x6" },
				{ x = cfg.SPAWN[1], y = light.RUG_LIFT, z = cfg.SPAWN[2], yaw = 0 },
				{ 1.4, 1, 1.4 }
			)
		)
	end

	LobbyPlan.warehouse(plan, cfg, light, kit, KP, strings)
	return plan
end

---------------------------------------------------------------------------------------------------------------------
-- The warehouse hideout (Config.Lobby.WAREHOUSE; PLAN_FIRST_PERSON §5 "BIG"): the shell over the 12-stud ground
-- course, the roof with trusses and skylights, the mezzanine and its stair, the stations' dressing and their anchors.
---------------------------------------------------------------------------------------------------------------------
function LobbyPlan.warehouse(plan: Plan, cfg: any, light: any, kit: { [string]: any }, KP: any, strings: any?)
	local W = cfg.WAREHOUSE
	local hx, hz, t, h = cfg.HALF_X, cfg.HALF_Z, cfg.WALL_T, cfg.WALL_H
	local X0, X1, Z0, Z1 = -hx - t, hx + t, -hz - t, hz + t -- the outer faces
	local yBand, yClere = h + W.BAND, h + W.BAND + W.CLERESTORY
	local roofY = W.ROOF_Y
	local trussY = roofY - W.TRUSS_H
	local top = roofY + W.DECK + 0.3
	local d0, d1 = cfg.DOOR_X - cfg.DOOR_W / 2, cfg.DOOR_X + cfg.DOOR_W / 2
	local doorH = cfg.DOOR_H or h
	local S = strings or {}
	plan.ceilY = trussY
	plan.topY = top
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
	local function add(p: PartSpec): PartSpec
		table.insert(plan.parts, p)
		return p
	end
	local function slab(name: string, b: Box, color: { number }, group: string?, material: string?): PartSpec
		return add({
			name = name,
			size = { b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ },
			pos = { (b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2, (b.minZ + b.maxZ) / 2 },
			color = color,
			material = material,
			group = group,
		})
	end
	local function kitItem(role: string, pieces: { string }, pivot: any, scale: { number }, group: string?): Item
		local it = item(role, pieces, pivot, scale)
		it.group = group
		table.insert(plan.items, it)
		return it
	end

	---------------------------------------------------------------- the shell's faces (cut-away groups)
	local faces = {
		{ name = "front", axis = "X", a = X0, b = X1, plane = Z1, n = 1, yaw = 180, ext = 1 },
		{ name = "back", axis = "X", a = X0, b = X1, plane = Z0, n = -1, yaw = 0, ext = -1 },
		{ name = "left", axis = "Z", a = Z0 + t, b = Z1 - t, plane = X0, n = -1, yaw = 90, ext = 1 },
		{ name = "right", axis = "Z", a = Z0 + t, b = Z1 - t, plane = X1, n = 1, yaw = -90, ext = -1 },
	}
	local function faceBox(f: any, s0: number, s1: number, ya: number, yb: number, i0: number, i1: number): Box
		local p0, p1 = f.plane - f.n * i0, f.plane - f.n * i1
		local lo, hi = math.min(p0, p1), math.max(p0, p1)
		if f.axis == "X" then
			return box(s0, ya, lo, s1, yb, hi)
		end
		return box(lo, ya, s0, hi, yb, s1)
	end
	local function onFace(f: any, s: number, y: number, out: number): { number }
		if f.axis == "X" then
			return { s, y, f.plane + f.n * out }
		end
		return { f.plane + f.n * out, y, s }
	end
	for _, f in faces do
		table.insert(plan.groups, {
			name = f.name,
			kind = "face",
			box = faceBox(f, f.a - t, f.b + t, h, top, -0.6, t),
			normal = if f.axis == "X" then { 0, f.n } else { f.n, 0 },
			plane = f.plane,
		})
	end
	table.insert(plan.groups, { name = "roof", kind = "roof", box = box(X0, roofY - 0.1, Z0, X1, top + 1.5, Z1) })
	table.insert(plan.groups, { name = "trusses", kind = "roof", box = box(X0, h, Z0, X1, roofY, Z1) })
	local M = W.MEZZANINE
	table.insert(plan.groups, {
		name = "mezzanine",
		kind = "occluder",
		box = box(-hx, M.deckY, M.z0 - 0.4, hx, M.deckY + M.thick + 3.6, hz),
	})

	local kitFacade = has("Facade_8x10_Body") and has("Facade_8x10")
	for _, f in faces do
		local back = f.name == "back"
		-- spans of the run that are wall (the back face leaves the roll-up door's gap up to DOOR_H)
		local spans = if back then { { f.a, d0 }, { d1, f.b } } else { { f.a, f.b } }
		local ext = if f.axis == "Z" then t else 0
		for _, sp in spans do
			local a = if sp[1] == f.a then sp[1] - ext else sp[1]
			local b = if sp[2] == f.b then sp[2] + ext else sp[2]
			slab("Band", faceBox(f, a, b, h, yBand, 0, t), W.BAND_COLOR, f.name, "Brick")
			local len = sp[2] - sp[1]
			local n = math.max(0, math.floor((len + 1e-6) / 8))
			local pier = (len - n * 8) / 2
			for side = 0, 1 do
				if pier > 0.05 then
					local s0 = if side == 0 then sp[1] else sp[2] - pier
					slab("Pier", faceBox(f, s0, s0 + pier, yBand, yClere, 0.3, t), W.BODY, f.name, "Brick")
				end
			end
			for m = 1, n do
				local s = sp[1] + pier + (m - 1) * 8
				local along = if f.ext > 0 then s else s + 8
				local p = onFace(f, along, yBand, 0)
				local pivot = { x = p[1], y = p[2], z = p[3], yaw = f.yaw }
				if kitFacade then
					local it = kitItem("shell", { "Facade_8x10_Body" }, pivot, { 1, 1, 1 }, f.name)
					it.color = W.BODY
					kitItem("shell", { "Facade_8x10" }, pivot, { 1, 1, 1 }, f.name)
				else
					slab("Clerestory", faceBox(f, s, s + 8, yBand, yClere, 0.3, t), W.BODY, f.name, "Brick")
				end
				local c = onFace(f, s + 4, yBand + 5.4, -1.03)
				add({
					name = "Pane",
					size = if f.axis == "X" then { 3.6, 5.6, 0.06 } else { 0.06, 5.6, 3.6 },
					pos = c,
					color = { 74, 84, 130 },
					group = f.name,
				})
			end
		end
		if back then
			-- over the roll-up door: brick from the door's head to the frieze
			slab("DoorHead", faceBox(f, d0, d1, doorH, yClere, 0, t), W.BODY, f.name, "Brick")
		end
		slab("Frieze", faceBox(f, f.a - ext, f.b + ext, yClere, top, 0, t), W.BODY, f.name, "Brick")
		slab("Coping", faceBox(f, f.a - ext, f.b + ext, top, top + 0.4, -0.2, t), W.ROOF_SNOW, f.name)
	end

	---------------------------------------------------------------- the roof: deck, snow, skylights
	local holes = {}
	for _, sk in W.SKYLIGHTS do
		table.insert(holes, { sk[1] - sk[3] / 2, sk[1] + sk[3] / 2, sk[2] - sk[4] / 2, sk[2] + sk[4] / 2 })
	end
	-- the deck as strips round the holes (holes share one z band: strips along X between them, full bands beyond)
	local hz0, hz1 = holes[1][3], holes[1][4]
	local function deck(x0: number, x1: number, z0: number, z1: number)
		slab("RoofDeck", box(x0, roofY, z0, x1, roofY + W.DECK, z1), W.ROOF_UNDER, "roof", "Wood")
		slab("RoofSnow", box(x0, roofY + W.DECK, z0, x1, top, z1), W.ROOF_SNOW, "roof")
	end
	deck(X0 + t, X1 - t, Z0 + t, hz0)
	deck(X0 + t, X1 - t, hz1, Z1 - t)
	local x = X0 + t
	for _, hl in holes do
		deck(x, hl[1], hz0, hz1)
		x = hl[2]
	end
	deck(x, X1 - t, hz0, hz1)
	for _, hl in holes do
		slab("Skylight", box(hl[1], top - 0.2, hl[3], hl[2], top - 0.1, hl[4]), W.SKYLIGHT_GLASS, "roof", "Glass").alpha =
			W.SKYLIGHT_ALPHA
		for _, e in
			{
				{ hl[1] - 0.4, hl[2] + 0.4, hl[3] - 0.4, hl[3] },
				{ hl[1] - 0.4, hl[2] + 0.4, hl[4], hl[4] + 0.4 },
				{ hl[1] - 0.4, hl[1], hl[3], hl[4] },
				{ hl[2], hl[2] + 0.4, hl[3], hl[4] },
			}
		do
			slab("SkylightFrame", box(e[1], roofY, e[3], e[2], top + 0.5, e[4]), W.STEEL, "roof", "Metal")
		end
	end

	---------------------------------------------------------------- trusses across the depth, lamp drop cables
	if has("Truss_8") then
		local lo, hi = scene("Truss_8")
		local span = (Z1 - t) - (Z0 + t)
		local segs = math.ceil(span / 8)
		local seg = span / segs
		local xt = -hx + W.TRUSS_EVERY / 2
		while xt < hx do
			for k = 0, segs - 1 do
				local z = Z0 + t + k * seg
				local pivot, scale = KP.fit(lo, hi, box(xt - 0.35, trussY, z, xt + 0.35, roofY, z + seg), 90)
				kitItem("truss", { "Truss_8" }, pivot, scale, "trusses")
			end
			xt += W.TRUSS_EVERY
		end
	else
		local xt = -hx + W.TRUSS_EVERY / 2
		while xt < hx do
			slab("Truss", box(xt - 0.35, roofY - 0.8, Z0 + t, xt + 0.35, roofY, Z1 - t), W.STEEL, "trusses", "Metal")
			xt += W.TRUSS_EVERY
		end
	end
	for _, l in plan.lamps do
		if l.kind == "work" or l.kind == "aisle" then
			local underDeck = l.z > M.z0 and l.z < hz
			local y0 = light.LAMP_HANG_Y
			if not underDeck then
				slab("LampCable", box(l.x - 0.06, y0, l.z - 0.06, l.x + 0.06, roofY, l.z + 0.06), W.CABLE, "trusses")
			end
		end
	end

	---------------------------------------------------------------- the mezzanine and its stair (greybox colliders)
	local deckTop = M.deckY + M.thick
	local st = W.STAIR
	slab("MezzanineDeck", box(-hx, M.deckY, M.z0, hx, deckTop, hz), W.TIMBER, "mezzanine", "Wood").collide = true
	for _, px in W.POSTS do
		slab("MezzaninePost", box(px - 0.4, 0, M.z0, px + 0.4, M.deckY, M.z0 + 0.8), W.STEEL, nil, "Metal").collide =
			true
	end
	-- the rail on the deck's open edge (kit Railing_8 visuals, an invisible collider), the stair landing left open
	if has("Railing_8") then
		local lo, hi = scene("Railing_8")
		for _, tl in KP.tiles(-hx, st.x0) do
			local pivot, scale = KP.fit(lo, hi, box(tl[1], deckTop, M.z0, tl[2], deckTop + 3.6, M.z0 + 0.24), 180)
			kitItem("rail", { "Railing_8" }, pivot, scale, "mezzanine")
		end
	else
		slab("MezzanineRail", box(-hx, deckTop + 3.3, M.z0, st.x0, deckTop + 3.6, M.z0 + 0.24), W.STEEL, "mezzanine")
	end
	local rail = slab("RailCollider", box(-hx, deckTop, M.z0, st.x0, deckTop + 3.6, M.z0 + 0.3), W.STEEL)
	rail.collide, rail.alpha = true, 1
	-- guards on the walls round the deck and up the stair (nobody steps off the deck over a 12-stud wall)
	for _, g in
		{
			{ X0, X1, deckTop, deckTop + M.guard, hz, Z1 },
			{ X0, -hx, deckTop, deckTop + M.guard, M.z0, Z1 },
			{ hx, X1, 0, deckTop + M.guard, st.z0, Z1 },
		}
	do
		local gp = slab("Guard", box(g[1], g[3], g[5], g[2], g[4], g[6]), W.STEEL)
		gp.collide, gp.alpha = true, 1
	end
	-- the stair: one wedge collider (rising toward +Z), timber treads over it, steel stringers
	local run, rise = st.z1 - st.z0, deckTop
	add({
		name = "StairRamp",
		size = { st.x1 - st.x0, rise, run },
		pos = { (st.x0 + st.x1) / 2, rise / 2, (st.z0 + st.z1) / 2 },
		yaw = 0,
		color = W.TIMBER,
		collide = true,
		wedge = true,
		alpha = 1,
	})
	for k = 1, st.steps do
		local zA = st.z0 + (k - 1) * run / st.steps
		local yT = k * rise / st.steps
		slab("StairTread", box(st.x0, yT - 0.3, zA, st.x1, yT, zA + run / st.steps + 0.05), W.TIMBER, nil, "Wood")
	end
	slab("Stringer", box(st.x0 - 0.3, 0, st.z0, st.x0, rise, st.z1), W.STEEL, nil, "Metal")

	---------------------------------------------------------------- the stations' dressing (the LOBBY track's anchors)
	local deskTop = 3.5
	if has("Counter_8x2") then
		local lo, hi = scene("Counter_8x2")
		local L = W.LAPTOP
		kitItem("station", { "Counter_8x2" }, KP.place(lo, hi, L.x, 0, L.z, L.yaw), { 1, 1, 1 })
		deskTop = hi[2] - lo[2]
	end
	do
		local L = W.LAPTOP
		local front = if L.yaw == 180 then 1 else -1 -- the desk faces +Z (the aisle) when it stands on the back wall
		slab(
			"LaptopBase",
			box(L.x - 0.9, deskTop, L.z - 0.6, L.x + 0.9, deskTop + 0.1, L.z + 0.6),
			W.STEEL,
			nil,
			"Metal"
		)
		add({
			name = "LaptopScreen",
			size = { 1.8, 1.2, 0.08 },
			pos = { L.x, deskTop + 0.7, L.z - front * 0.55 },
			yaw = L.yaw,
			color = { 30, 33, 62 },
			gui = { text = S.GARAGE_LAPTOP or "DAILY VAULT", color = { 255, 226, 150 }, face = "Front" },
		})
	end
	do -- the wardrobe and the mirror on the left wall
		local Wd = W.WARDROBE
		slab("Wardrobe", box(-hx, 0, Wd.z - 3, -hx + 2.4, 9, Wd.z + 3), W.TIMBER, nil, "Wood")
		slab("WardrobeSplit", box(-hx + 2.4, 0.4, Wd.z - 0.06, -hx + 2.5, 8.6, Wd.z + 0.06), { 60, 44, 40 })
		for _, s in { -1, 1 } do
			slab("WardrobeKnob", box(-hx + 2.4, 4.4, Wd.z + s * 0.5 - 0.15, -hx + 2.6, 4.7, Wd.z + s * 0.5 + 0.15), {
				216,
				200,
				168,
			})
		end
		slab("Mirror", box(-hx, 1.2, Wd.z + 4, -hx + 0.2, 8, Wd.z + 7.2), { 190, 205, 225 }, nil, "Glass").alpha = 0.1
		slab("MirrorFrame", box(-hx, 0.9, Wd.z + 3.7, -hx + 0.15, 8.3, Wd.z + 7.5), { 216, 200, 168 })
		if has("Hide_CoatStand") then
			local lo, hi = scene("Hide_CoatStand")
			kitItem("station", { "Hide_CoatStand" }, KP.place(lo, hi, -hx + 4, 0, Wd.z - 5, 90), { 1, 1, 1 })
		end
	end
	do -- the TV under the mezzanine's edge
		local T = W.TV
		add({
			name = "TV",
			size = { T.w, T.h, 0.4 },
			pos = { T.x, T.y, T.z },
			color = { 28, 31, 59 },
			gui = { text = S.GARAGE_TV or "HEIST YOURSELF", color = { 236, 226, 200 }, face = "Front" },
		})
		for _, s in { -1, 1 } do
			slab(
				"TVStrap",
				box(
					T.x + s * T.w * 0.35 - 0.1,
					T.y + T.h / 2,
					T.z - 0.1,
					T.x + s * T.w * 0.35 + 0.1,
					M.deckY,
					T.z + 0.1
				),
				W.STEEL,
				nil,
				"Metal"
			)
		end
	end
	do -- the crew sign on the right wall
		local C2 = W.CREW_SIGN
		add({
			name = "CrewSignBoard",
			size = { 0.3, C2.h, C2.w },
			pos = { C2.x, C2.y, C2.z },
			color = { 140, 47, 75 },
			gui = { text = S.GARAGE_CREW_SIGN or "THE CREW", color = { 255, 226, 150 }, face = "Left" },
		})
	end
	if has("Hide_Crate") then
		local lo, hi = scene("Hide_Crate")
		for _, c in W.CRATES do
			kitItem("dressing", { "Hide_Crate" }, KP.place(lo, hi, c[1], deckTop, c[2], c[3]), { 1, 1, 1 }, "mezzanine")
		end
	end
	if has("Shelf_8x2") then
		local lo, hi = scene("Shelf_8x2")
		for _, c in W.SHELVES do
			kitItem("dressing", { "Shelf_8x2" }, KP.place(lo, hi, c[1], 0, c[2], c[3]), { 1, 1, 1 })
		end
	end
	if has("Xmas_Tree") then
		local lo, hi = scene("Xmas_Tree")
		local pivot = KP.place(lo, hi, W.TREE[1], 0, W.TREE[2], 0)
		kitItem("dressing", { "Xmas_Tree" }, pivot, { 1, 1, 1 })
		if has("Xmas_Tree_Lights") then
			kitItem("dressing", { "Xmas_Tree_Lights" }, pivot, { 1, 1, 1 })
		end
	end

	---------------------------------------------------------------- anchors for the LOBBY track
	local B = cfg.BOARD
	local function anchor(name: string, x0: number, y0: number, z0: number, yaw: number)
		table.insert(plan.anchors, { name = name, x = x0, y = y0, z = z0, yaw = yaw })
	end
	anchor("JobBoardSpot", B.x, 0, B.z, B.yaw)
	anchor("LaptopSpot", W.LAPTOP.x, deskTop, W.LAPTOP.z, W.LAPTOP.yaw)
	anchor("WardrobeSpot", -hx + 2.4, 0, W.WARDROBE.z, W.WARDROBE.yaw)
	anchor("TVSpot", W.TV.x, W.TV.y, W.TV.z, 0)
	anchor("CrewSign", W.CREW_SIGN.x, W.CREW_SIGN.y, W.CREW_SIGN.z, 90)
	for _, bay in plan.bays do
		anchor("VanBay" .. bay.index, bay.x, 0, bay.z, bay.yaw)
	end
end

-- The lights of the plan within Config.Lighting.VIEW_RADIUS of a point: (lit, shadowed). The unit spec keeps every
-- view inside Config.Lighting's per-view budget.
function LobbyPlan.lightsNear(plan: Plan, x: number, z: number, radius: number): (number, number)
	local lit, shadowed = 0, 0
	for _, l in plan.lamps do
		local dx, dz = l.x - x, l.z - z
		if dx * dx + dz * dz <= radius * radius then
			lit += 1
			if l.shadows then
				shadowed += 1
			end
		end
	end
	return lit, shadowed
end

return table.freeze(LobbyPlan)
