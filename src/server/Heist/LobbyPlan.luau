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
	color: { number }?, -- Van_Paint colour (van items)
}
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
function LobbyPlan.plan(cfg: any, light: any, specs: { [string]: any }?, KP: any): Plan
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
		local b = KP.box(d0, 0, -hz - t, d1, h, -hz)
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
		-- the work lamp off the van's cab end, over its door side (the cab is the kit's -X end: +X in the world once
		-- the back row turns 180)
		local lz = z + (if back then cfg.LAMP_OFFSET else -cfg.LAMP_OFFSET)
		local lx = b.x + (if back then cfg.LAMP_ALONG else -cfg.LAMP_ALONG)
		local L = if i == 1 then cfg.YOUR_LAMP else cfg.WORK_LAMP
		table.insert(plan.lamps, {
			kind = if i == 1 then "yours" else "work",
			x = lx,
			y = light.LIGHT_Y,
			z = lz,
			range = L.range,
			brightness = L.brightness,
			color = L.color,
			shadows = L.shadows == true,
			angle = L.angle,
			pool = L.pool,
			poolColor = L.poolColor,
			bay = i,
		})
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

	return plan
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
