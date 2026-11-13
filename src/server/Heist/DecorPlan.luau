--!strict
-- Heist/DecorPlan: the eye-level interior props of a compiled level (pure; Lune-tested in
-- tests/unit/HeistInterior.spec.luau). INTERIORS track: docs/audit/REVIEW_STEAM_PLUS.md gaps 8 and 12, STYLE_BIBLE §19,
-- docs/audit/LEVELS.md §13. Numbers in Config.Interior; the kit in assets/blender/interior.py.
--
-- Visual only, always: every item is a KitPlan "visual" item (KitDresser: CanCollide / CanTouch / CanQuery off) and
-- the sim never reads this module, so recordings, Gus and the server's collisions are exactly what they were.
--
-- What it plans, per room band (the strips between the building's X-axis wall lines; the band behind the street front
-- is "front", the band holding the goal loot "goal", the others "back"):
--   * floor props backed onto a wall face (kit wall face + WALL_GAP), facing into the room, in Config.Interior.ROOMS
--     priority order, each in the clear slot farthest from the props already placed;
--   * wall props (posters, the clock, the corkboard, the card string) at their MOUNT height on clear wall spans;
--   * the level's theme (Config.Interior.THEMES): the hero window display against the street front beside the
--     entrance, piece swaps, and a tinted frieze under the crown of every interior wall face;
--   * on the Bank's teller counters, the brass rail.
-- A slot is clear when the prop's footprint keeps off every keep-out: the walls (grown by the kit wall's extra half),
-- every other solid, plates, doors (and their approach and frames), loot, hides, lasers and their posts, switches,
-- spawns, nav points, Gus's route, the van zone, the floor cables, the rugs, the base kit's own props (displays, the
-- till, signature props, hide props, laser posts) and the sightlines from crew seat 1 to every plate, door and the
-- goal. On a LevelDress window line only low props stand (under the sill); wall props never sit on a window line or
-- on the street front. Christmas pieces only with the dressing layer. Deterministic (no randomness): the same level
-- always dresses the same way.

local DecorPlan = {}

type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }
type Rect = { x0: number, x1: number, z0: number, z1: number }

export type Item = {
	role: string, -- "decor" | "hero" | "frieze" | "brass"
	mode: string, -- "visual"
	pieces: { string },
	pivot: { x: number, y: number, z: number, yaw: number },
	scale: { number },
	layer: string, -- "base" | "xmas"
	tier: string?, -- "decor": hidden on the client from Config.Interior.DECOR_OFF_TIER
	color: { number }?, -- runtime colour of a tintable piece (the frieze)
	room: string?, -- the room kind it dresses
	band: number?,
}
export type Options = {
	location: string?, -- KitPlan.location
	dressing: boolean?, -- the Christmas layer
	dress: any?, -- Heist/LevelDress entry (windows, rugs)
	base: { any }?, -- the base kit plan's items (KitPlan.plan(...).items): their props are keep-outs
	why: { [string]: number }?, -- tests: rejected slots counted by reason
}
export type Deps = { KP: any, cfg: any, lighting: any? }
export type Plan = { items: { Item }, theme: string?, rooms: { { kind: string, z0: number, z1: number } } }

local EPS = 1e-6
local WALL_MIN_H = 8
local THIN = 1.5
local WALL_SURFACE = 0.72 -- the kit wall's upper field (wainscot and upper wall) sits 0.3 inside the module plane

---------------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------------

-- The theme name of a level: Config.Interior.LEVELS, else by location (the Toy Shop "toystore", the Bank "bank"), else a
-- Corner Shop daily's DAILY_SHOPS entry by its number (DV01 = the deli), else "grocer".
function DecorPlan.themeName(level: any, location: string?, cfg: any): string
	local loc = location or (level.spec and level.spec.location) or "CornerShop"
	if loc == "ToyShop" then
		return "toystore"
	elseif loc == "Bank" then
		return "bank"
	end
	local named = cfg.LEVELS[level.id]
	if named then
		return named
	end
	local num = level.num or 0
	if num > 300 and num < 400 then
		local list = cfg.DAILY_SHOPS
		return list[(num - 301) % #list + 1]
	end
	return "grocer"
end

function DecorPlan.theme(level: any, location: string?, cfg: any): (string, any)
	local name = DecorPlan.themeName(level, location, cfg)
	return name, cfg.THEMES[name]
end

---------------------------------------------------------------------------
-- Geometry helpers
---------------------------------------------------------------------------

local function rectOverlap(a: Rect, b: Rect, tol: number): boolean
	return a.x0 < b.x1 - tol and a.x1 > b.x0 + tol and a.z0 < b.z1 - tol and a.z1 > b.z0 + tol
end

local function grow(b: Box, gx: number, gz: number): Rect
	return { x0 = b.minX - gx, x1 = b.maxX + gx, z0 = b.minZ - gz, z1 = b.maxZ + gz }
end

-- Squared distance from a point to a rect (0 inside).
local function pointRect2(px: number, pz: number, r: Rect): number
	local dx = math.max(r.x0 - px, 0, px - r.x1)
	local dz = math.max(r.z0 - pz, 0, pz - r.z1)
	return dx * dx + dz * dz
end

-- Whether segment (ax, az)-(bx, bz) passes within `d` of rect r (sampled every 0.25 studs).
local function segNear(ax: number, az: number, bx: number, bz: number, r: Rect, d: number): boolean
	local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
	local n = math.max(1, math.ceil(len / 0.25))
	for k = 0, n do
		local t = k / n
		if pointRect2(ax + (bx - ax) * t, az + (bz - az) * t, r) < d * d then
			return true
		end
	end
	return false
end

type Wall = { i: number, axis: string, line: number, a: number, b: number, box: Box }

local function wallOf(i: number, b: Box): Wall?
	local wx, wz, h = b.maxX - b.minX, b.maxZ - b.minZ, b.maxY - b.minY
	if h < WALL_MIN_H - EPS or math.min(wx, wz) > THIN + EPS then
		return nil
	end
	if wx >= wz then
		return { i = i, axis = "X", line = (b.minZ + b.maxZ) / 2, a = b.minX, b = b.maxX, box = b }
	end
	return { i = i, axis = "Z", line = (b.minX + b.maxX) / 2, a = b.minZ, b = b.maxZ, box = b }
end

-- The yaw that turns a piece's front (-Z) toward (dx, dz) (CFrame.Angles(0, yaw, 0)).
local function yawToward(dx: number, dz: number): number
	return math.deg(math.atan2(-dx, -dz))
end

-- The pieces of a "piece set": the named piece plus every manifest name of its model that starts with it and "_"
-- (Decor_Fridge_4 -> its glass and light strip; Xmas_Tree -> its lights).
local function setOf(name: string, specs: { [string]: any }): { string }?
	local spec = specs[name]
	if spec == nil then
		return nil
	end
	local out = { name }
	for n, s in specs do
		if n ~= name and s.model == spec.model and string.sub(n, 1, #name + 1) == name .. "_" then
			table.insert(out, n)
		end
	end
	table.sort(out)
	return out
end

local function sceneOf(names: { string }, specs: { [string]: any }): ({ number }, { number })
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

---------------------------------------------------------------------------
-- The fascia (the shop's name over the entrance, on the street front's sign board)
---------------------------------------------------------------------------

-- The entrance of the street front: its centre x, the front line z (the sim wall's centre), or nil.
function DecorPlan.entrance(level: any, KP: any): (number?, number?)
	local bb = KP.buildingBox(level)
	if bb == nil then
		return nil, nil
	end
	local line = bb.maxZ - 0.5
	local spans = {}
	for i, s in level.spec.solids or {} do
		local w = wallOf(i, s.box)
		if w and w.axis == "X" and math.abs(w.line - line) < 0.1 then
			table.insert(spans, { w.a, w.b })
		end
	end
	table.sort(spans, function(p: any, q: any): boolean
		return p[1] < q[1]
	end)
	for k = 1, #spans - 1 do
		local g0, g1 = spans[k][2], spans[k + 1][1]
		if math.abs((g1 - g0) - 8) < 0.1 then
			return (g0 + g1) / 2, line
		end
	end
	return nil, nil
end

export type Fascia = {
	x: number,
	y: number,
	z: number,
	w: number,
	h: number,
	text: string,
	board: { number },
	color: { number },
}

-- The fascia sign over the entrance (on the kit front's sign board: Storefront_24x12 9.6 x 1.4 at 10.55-11.95, its
-- face 0.45 proud of the front plane; BankFront_24x12 9.2 x 1.4 at 10.45-11.85, 0.5 proud). Level space; the text
-- faces the street (+Z). Nil when the level has no 8-wide street entrance.
function DecorPlan.fascia(level: any, location: string?, deps: Deps): Fascia?
	local c, line = DecorPlan.entrance(level, deps.KP)
	if c == nil or line == nil then
		return nil
	end
	local _, theme = DecorPlan.theme(level, location, deps.cfg)
	if theme == nil then
		return nil
	end
	local bank = location == "Bank"
	local fy = level.floorY or 0
	return {
		x = c,
		y = fy + (if bank then 11.15 else 11.25),
		z = line + 1 + (if bank then 0.5 else 0.45) + 0.02,
		w = if bank then 8.8 else 9.2,
		h = 1.2,
		text = theme.name,
		board = theme.board,
		color = theme.text,
	}
end

---------------------------------------------------------------------------
-- The plan
---------------------------------------------------------------------------

function DecorPlan.plan(level: any, specs: { [string]: any }, opts: Options?, deps: Deps): Plan
	local o: Options = opts or {}
	local cfg, KP = deps.cfg, deps.KP
	local C = cfg.CLEAR
	local location = o.location or KP.location(level, o.dressing == true)
	local themeName, theme = DecorPlan.theme(level, location, cfg)
	local plan: Plan = { items = {}, theme = themeName, rooms = {} }
	if not cfg.ENABLED then
		return plan
	end
	local bb = KP.buildingBox(level)
	if bb == nil then
		return plan
	end
	local fy = level.floorY or 0
	local dressing = o.dressing == true
	local swap = (theme and theme.swap) or {}
	local inner: Rect = { x0 = bb.minX + 0.5, x1 = bb.maxX - 0.5, z0 = bb.minZ + 0.5, z1 = bb.maxZ - 0.5 }

	---------------------------------------------------------------- walls, bands
	local walls: { Wall } = {}
	local others: { Box } = {} -- counters, shelves, pillars
	for i, s in level.spec.solids or {} do
		local w = wallOf(i, s.box)
		if w then
			table.insert(walls, w)
		else
			table.insert(others, s.box)
		end
	end
	local lines: { number } = {}
	for _, w in walls do
		if w.axis == "X" and w.line >= bb.minZ - 0.01 and w.line <= bb.maxZ + 0.01 then
			local dup = false
			for _, z in lines do
				dup = dup or math.abs(z - w.line) < 0.5
			end
			if not dup then
				table.insert(lines, w.line)
			end
		end
	end
	table.sort(lines, function(a: number, b: number): boolean
		return a > b
	end)
	local goal = KP.goal(level)
	local goalZ = if goal then level.loot[goal].z else nil
	for k = 1, #lines - 1 do
		local z1, z0 = lines[k], lines[k + 1]
		local kind = if k == 1 then "front" elseif goalZ and goalZ < z1 and goalZ > z0 then "goal" else "back"
		table.insert(plan.rooms, { kind = kind, z0 = z0, z1 = z1 })
	end
	local function bandOf(z: number): number?
		for k, r in plan.rooms do
			if z > r.z0 and z < r.z1 then
				return k
			end
		end
		return nil
	end

	---------------------------------------------------------------- keep-outs
	local rects: { Rect } = {}
	local wallRects: { Rect } = {} -- for wall props: the doors' frames, laser posts, switches
	local circles: { { number } } = {} -- x, z, r
	local segs: { { number } } = {} -- ax, az, bx, bz, r
	local pad = cfg.WALL_PAD
	for _, b in others do
		table.insert(rects, grow(b, 0.3, 0.3))
	end
	for _, p in level.plates do
		table.insert(rects, grow(p.box, C.plate, C.plate))
	end
	local vaultDoor: { [number]: boolean } = {}
	for _, it in o.base or {} do
		if it.role == "vaultSkin" and it.index then
			vaultDoor[it.index] = true
		end
	end
	for i, d in level.doors do
		local b = d.box
		local alongX = (b.maxX - b.minX) >= (b.maxZ - b.minZ)
		local across = if vaultDoor[i] then 11 else C.doorAcross
		local acrossW = if vaultDoor[i] then 11 else C.doorAcrossWall
		if alongX then
			table.insert(rects, grow(b, across, C.doorNormal))
			table.insert(wallRects, grow(b, acrossW, C.doorNormal))
		else
			table.insert(rects, grow(b, C.doorNormal, across))
			table.insert(wallRects, grow(b, C.doorNormal, acrossW))
		end
	end
	for _, l in level.lasers or {} do
		table.insert(rects, grow(l.box, C.laser, C.laser))
		table.insert(wallRects, grow(l.box, C.laser, C.laser))
	end
	for _, h in level.hides or {} do
		table.insert(rects, grow(h.box, C.hide, C.hide))
		table.insert(wallRects, grow(h.box, 1.1, 1.1)) -- no poster or corkboard behind a coat rack or a fern
	end
	table.insert(rects, grow(level.van, C.van, C.van))
	for _, def in level.loot do
		table.insert(circles, { def.x, def.z, C.loot })
	end
	for _, sw in level.switches or {} do
		table.insert(circles, { sw.x, sw.z, C.switch })
		table.insert(
			wallRects,
			{ x0 = sw.x - C.switch, x1 = sw.x + C.switch, z0 = sw.z - C.switch, z1 = sw.z + C.switch }
		)
	end
	for _, sp in level.spawns do
		table.insert(circles, { sp.x, sp.z, C.spawn })
	end
	for _, n in level.spec.nav or {} do
		table.insert(circles, { n.x, n.z, C.nav })
	end
	for _, g in level.spec.guards or {} do
		local route = g.route or {}
		for k, p in route do
			table.insert(circles, { p.x, p.z, C.guard })
			local q = route[k % #route + 1]
			if q and q ~= p then
				table.insert(segs, { p.x, p.z, q.x, q.z, C.guard })
			end
		end
	end
	if deps.lighting then
		for _, cb in KP.cables(level, deps.lighting) do
			for k = 1, #cb.points - 1 do
				local a, b = cb.points[k], cb.points[k + 1]
				table.insert(segs, { a[1], a[2], b[1], b[2], C.cable })
			end
		end
	end
	local seat = level.spawns[1]
	if seat then
		local function sight(x: number, z: number)
			table.insert(segs, { seat.x, seat.z, x, z, C.sight })
		end
		for _, p in level.plates do
			sight((p.box.minX + p.box.maxX) / 2, (p.box.minZ + p.box.maxZ) / 2)
		end
		for _, d in level.doors do
			sight((d.box.minX + d.box.maxX) / 2, (d.box.minZ + d.box.maxZ) / 2)
		end
		if goal then
			sight(level.loot[goal].x, level.loot[goal].z)
		end
	end
	local rug = specs.Rug_8x6
	for _, r in (o.dress and o.dress.rugs) or {} do
		if rug then
			local item = {
				pieces = { "Rug_8x6" },
				pivot = { x = r.x, y = fy, z = r.z, yaw = r.yaw or 0 },
				scale = { r.sx or 1, 1, r.sz or 1 },
			}
			table.insert(rects, grow(KP.itemBox(item, specs), C.rug, C.rug))
		end
	end
	local KEEP_ROLES = { signature = true, display = true, till = true, hide = true, post = true, switch = true }
	for _, it in o.base or {} do
		if KEEP_ROLES[it.role] then
			local b = KP.itemBox(it, specs)
			if b.minX < b.maxX then
				table.insert(rects, grow(b, 0.3, 0.3))
				table.insert(wallRects, grow(b, 0.3, 0.3))
			end
		end
	end
	local windowLines: { { axis: string, line: number } } = {}
	for _, wl in (o.dress and o.dress.windows) or {} do
		table.insert(windowLines, wl)
	end

	---------------------------------------------------------------- faces
	type Face = { wall: Wall, side: number, plane: number, axis: string, a: number, b: number, front: boolean }
	local faces: { Face } = {}
	local frontLine = bb.maxZ - 0.5
	for _, w in walls do
		local b = w.box
		if b.minX < bb.minX - 0.01 or b.maxX > bb.maxX + 0.01 or b.minZ < bb.minZ - 0.01 or b.maxZ > bb.maxZ + 0.01 then
			continue
		end
		for _, side in { -1, 1 } do
			local mid = (w.a + w.b) / 2
			local px, pz
			if w.axis == "X" then
				px, pz = mid, w.line + side * 2
			else
				px, pz = w.line + side * 2, mid
			end
			if px > inner.x0 and px < inner.x1 and pz > inner.z0 and pz < inner.z1 then
				table.insert(faces, {
					wall = w,
					side = side,
					plane = w.line,
					axis = w.axis,
					a = w.a,
					b = w.b,
					front = w.axis == "X" and math.abs(w.line - frontLine) < 0.1,
				})
			end
		end
	end
	table.sort(faces, function(p: Face, q: Face): boolean
		if p.axis ~= q.axis then
			return p.axis < q.axis
		end
		if p.plane ~= q.plane then
			return p.plane < q.plane
		end
		if p.a ~= q.a then
			return p.a < q.a
		end
		return p.side < q.side
	end)

	local function onWindowLine(f: Face): boolean
		for _, wl in windowLines do
			if wl.axis == f.axis and math.abs(wl.line - f.plane) < 0.1 then
				return true
			end
		end
		return false
	end

	---------------------------------------------------------------- placing
	type Placed = { rect: Rect, y0: number, y1: number, wall: boolean }
	local placed: { Placed } = {}

	local why = o.why
	local function no(reason: string): boolean
		if why then
			why[reason] = (why[reason] or 0) + 1
		end
		return false
	end
	local function clearRect(r: Rect, y0: number, y1: number, isWall: boolean, host: Wall?): boolean
		if r.x0 < inner.x0 or r.x1 > inner.x1 or r.z0 < inner.z0 or r.z1 > inner.z1 then
			return no("outside")
		end
		for _, w in walls do
			if w ~= host and rectOverlap(r, grow(w.box, pad, pad), 0) then
				return no("wall")
			end
		end
		if isWall then
			for _, b in others do
				if b.maxY > y0 and rectOverlap(r, grow(b, 0.3, 0.3), 0) then
					return no("solid")
				end
			end
			for _, k in wallRects do
				if rectOverlap(r, k, 0) then
					return no("wallRect")
				end
			end
		else
			for _, k in rects do
				if rectOverlap(r, k, 0) then
					return no("rect")
				end
			end
			for _, c in circles do
				if pointRect2(c[1], c[2], r) < c[3] * c[3] then
					return no("circle")
				end
			end
			for _, s in segs do
				if segNear(s[1], s[2], s[3], s[4], r, s[5]) then
					return no("seg")
				end
			end
		end
		local g = cfg.PROP_GAP
		local rg = { x0 = r.x0 - g, x1 = r.x1 + g, z0 = r.z0 - g, z1 = r.z1 + g }
		for _, p in placed do
			if p.y1 > y0 and p.y0 < y1 and rectOverlap(rg, p.rect, 0) then
				return no("placed")
			end
		end
		return true
	end

	type Slot = { rect: Rect, cx: number, cz: number, yaw: number, face: Face }
	-- Candidate slots for a piece (width w along the wall, depth d out of it) on face f, back `back` studs off the line.
	local function slots(f: Face, w: number, d: number, back: number): { Slot }
		local out = {}
		local s0, s1 = f.a + w / 2, f.b - w / 2
		local n = math.floor((s1 - s0) / cfg.STEP + EPS)
		if s1 < s0 then
			return out
		end
		local dirX, dirZ = if f.axis == "Z" then f.side else 0, if f.axis == "X" then f.side else 0
		local yaw = yawToward(dirX, dirZ)
		local off = back + d / 2
		for k = 0, n do
			local s = if n == 0 then (s0 + s1) / 2 else s0 + k * cfg.STEP
			local cx, cz, rect
			if f.axis == "X" then
				cx, cz = s, f.plane + f.side * off
				rect = { x0 = s - w / 2, x1 = s + w / 2, z0 = cz - d / 2, z1 = cz + d / 2 }
			else
				cx, cz = f.plane + f.side * off, s
				rect = { x0 = cx - d / 2, x1 = cx + d / 2, z0 = s - w / 2, z1 = s + w / 2 }
			end
			table.insert(out, { rect = rect, cx = cx, cz = cz, yaw = yaw, face = f })
		end
		return out
	end

	local function add(item: Item)
		table.insert(plan.items, item)
	end

	-- Places one piece set in band `band` (nil: any band) or on face filter `want`; returns whether it found a slot.
	local function placeOne(
		name: string,
		role: string,
		roomKind: string,
		band: number?,
		want: ((f: Face, s: Slot) -> boolean)?,
		score: ((s: Slot) -> number)?
	): boolean
		local names = setOf(name, specs)
		if names == nil then
			return false
		end
		local lo, hi = sceneOf(names, specs)
		local w, h, d = hi[1] - lo[1], hi[2] - lo[2], hi[3] - lo[3]
		local mount = cfg.MOUNT[name]
		local isWall = mount ~= nil and mount > 0
		if not isWall and role == "decor" and d > cfg.MAX_DEPTH then
			return false
		end
		local back = if mount ~= nil then WALL_SURFACE else cfg.KIT_WALL_HALF + cfg.WALL_GAP
		local y0 = fy + (mount or 0)
		local best: Slot? = nil
		local bestScore = -math.huge
		for _, f in faces do
			if isWall and (f.front or onWindowLine(f)) then
				continue
			end
			if not isWall and (onWindowLine(f) or (f.front and role ~= "hero")) and h > C.windowLow then
				continue -- never a tall prop against glass (the display windows belong to the hero)
			end
			for _, s in slots(f, w, d, back) do
				local b = bandOf(s.cz)
				if band and b ~= band then
					continue
				end
				if want and not want(f, s) then
					continue
				end
				if not clearRect(s.rect, y0, y0 + h, isWall, f.wall) then
					continue
				end
				local sc
				if score then
					sc = score(s)
				else
					sc = math.huge
					for _, p in placed do
						local px, pz = (p.rect.x0 + p.rect.x1) / 2, (p.rect.z0 + p.rect.z1) / 2
						sc = math.min(sc, (px - s.cx) ^ 2 + (pz - s.cz) ^ 2)
					end
					sc = math.min(sc, 1e6) - s.cx * 1e-6 - s.cz * 1e-7 -- deterministic tie break
				end
				if sc > bestScore then
					best, bestScore = s, sc
				end
			end
		end
		if best == nil then
			return false
		end
		local sl = best :: Slot
		local pivot = KP.place(lo, hi, sl.cx, y0, sl.cz, sl.yaw)
		add({
			role = role,
			mode = "visual",
			pieces = names,
			pivot = pivot,
			scale = { 1, 1, 1 },
			layer = if cfg.XMAS[name] then "xmas" else "base",
			tier = if role == "decor" then "decor" else nil,
			room = roomKind,
			band = bandOf(sl.cz),
		})
		table.insert(placed, { rect = sl.rect, y0 = y0, y1 = y0 + h, wall = isWall })
		return true
	end

	-- 1. the theme's hero window display: in the front band against the street front, beside the entrance
	local entX = DecorPlan.entrance(level, KP)
	if theme and theme.hero and entX and #plan.rooms > 0 and (dressing or not cfg.XMAS[theme.hero]) then
		local cx = entX :: number
		local ok = placeOne(theme.hero, "hero", "front", 1, function(f: Face, s: Slot): boolean
			return f.front and math.abs(s.cx - cx) >= 4.5
		end, function(s: Slot): number
			return -math.abs(math.abs(s.cx - cx) - 8) - s.cx * 1e-4
		end)
		if not ok then
			placeOne(theme.hero, "hero", "front", 1, nil, nil)
		end
	end

	-- 2. the teller brass on the Bank's teller counters (sim counters longer than 5, not walls)
	if location == "Bank" and cfg.TELLER_BRASS and specs[cfg.TELLER_BRASS] then
		local names = { cfg.TELLER_BRASS }
		local lo, hi = sceneOf(names, specs)
		for _, s in level.spec.solids or {} do
			local b = s.box
			local wx, wz = b.maxX - b.minX, b.maxZ - b.minZ
			if s.sight == false and b.maxY - b.minY <= 5 and math.max(wx, wz) > 5 and wallOf(0, b) == nil then
				local alongX = wx >= wz
				local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
				-- the customer side: toward the street front (+Z) or toward the building's middle (X)
				local yaw, px, pz
				if alongX then
					yaw, px, pz = 180, cx, b.maxZ - 0.5
				else
					local toward = if cx < (bb.minX + bb.maxX) / 2 then 1 else -1
					yaw, px, pz = yawToward(toward, 0), if toward > 0 then b.maxX - 0.5 else b.minX + 0.5, cz
				end
				local k = math.min(1, (math.max(wx, wz) - 0.4) / (hi[1] - lo[1]))
				local pivot, scale = KP.place(lo, hi, px, fy + b.maxY - b.minY, pz, yaw, k)
				add({
					role = "brass",
					mode = "visual",
					pieces = names,
					pivot = pivot,
					scale = scale,
					layer = "base",
					tier = "decor",
					room = "front",
				})
			end
		end
	end

	-- 3. the room props, band by band, in priority order (floor props, then wall props)
	local rooms = cfg.ROOMS[location] or cfg.ROOMS.CornerShop
	for k, r in plan.rooms do
		local set = rooms[r.kind] or rooms.back
		for _, name in set.floor do
			local piece = swap[name] or name
			if cfg.XMAS[piece] and not dressing then
				continue
			end
			placeOne(piece, "decor", r.kind, k, nil, nil)
		end
		for _, name in set.wall do
			local piece = swap[name] or name
			if cfg.XMAS[piece] and not dressing then
				continue
			end
			placeOne(piece, "decor", r.kind, k, nil, nil)
		end
	end

	-- 4. the frieze: 8-wide tinted tiles under the crown along every interior wall face, clear of the doors' frames and
	-- the laser posts (wallRects), trimmed at the corners
	local fz = cfg.FRIEZE
	if theme and theme.frieze and specs[fz.piece] then
		local names = { fz.piece }
		local lo, hi = sceneOf(names, specs)
		local d = hi[3] - lo[3]
		for _, f in faces do
			-- the free runs of the face: [a + 1.1, b - 1.1] minus every wall keep-out it crosses
			local runs = { { f.a + 1.1, f.b - 1.1 } }
			local function cut(c0: number, c1: number)
				local nxt = {}
				for _, run in runs do
					if c1 <= run[1] or c0 >= run[2] then
						table.insert(nxt, run)
					else
						if c0 > run[1] then
							table.insert(nxt, { run[1], c0 })
						end
						if c1 < run[2] then
							table.insert(nxt, { c1, run[2] })
						end
					end
				end
				runs = nxt
			end
			local near = f.plane + f.side * (WALL_SURFACE + d / 2)
			for _, k in wallRects do
				local hit = if f.axis == "X" then near > k.z0 and near < k.z1 else near > k.x0 and near < k.x1
				if hit then
					if f.axis == "X" then
						cut(k.x0, k.x1)
					else
						cut(k.z0, k.z1)
					end
				end
			end
			-- perpendicular walls meeting this face mid-run (T junctions)
			for _, w in walls do
				if w.axis ~= f.axis then
					local b = w.box
					local hit = if f.axis == "X"
						then near > b.minZ - pad and near < b.maxZ + pad
						else near > b.minX - pad and near < b.maxX + pad
					if hit then
						if f.axis == "X" then
							cut(b.minX - 1.1, b.maxX + 1.1)
						else
							cut(b.minZ - 1.1, b.maxZ + 1.1)
						end
					end
				end
			end
			local dirX, dirZ = if f.axis == "Z" then f.side else 0, if f.axis == "X" then f.side else 0
			local yaw = yawToward(dirX, dirZ)
			for _, run in runs do
				if run[2] - run[1] < 2 then
					continue
				end
				for _, t in KP.tiles(run[1], run[2]) do
					local s, len = (t[1] + t[2]) / 2, t[2] - t[1]
					local cx = if f.axis == "X" then s else near
					local cz = if f.axis == "X" then near else s
					local pivot = KP.place(lo, hi, cx, fy + fz.y, cz, yaw)
					add({
						role = "frieze",
						mode = "visual",
						pieces = names,
						pivot = pivot,
						scale = { len / (hi[1] - lo[1]), 1, 1 },
						layer = "base",
						tier = "decor", -- the low tiers keep the level's colour in its ceiling and light
						color = theme.frieze,
						room = if bandOf(cz) then plan.rooms[bandOf(cz) :: number].kind else nil,
					})
				end
			end
		end
	end
	return plan
end

-- The light look of a level's theme (Config.Interior.THEMES[...].light), or nil (the location's own).
function DecorPlan.light(level: any, location: string?, cfg: any): any?
	local _, theme = DecorPlan.theme(level, location, cfg)
	return theme and theme.light
end

return table.freeze(DecorPlan)
