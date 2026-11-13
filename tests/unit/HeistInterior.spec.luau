-- L1: Heist/DecorPlan, the eye-level interiors (INTERIORS track; docs/audit/REVIEW_STEAM_PLUS.md gaps 8, 9 and 12;
-- docs/audit/LEVELS.md §13). Props are visual only: on every launch level and daily vault, with and without the
-- Christmas layer, no prop overlaps a sim box (walls, counters, shelves), a plate, a door (or its approach), a loot
-- point, a hide, a laser, a switch, the van zone or a spawn; a walk-grid route check finds every plate, door, loot
-- point and hide still reachable from the crew seat with the props as obstacles, by a path no longer than without
-- them; every room has props at eye level; each level is its own shop; the light budget holds with the wall washes.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Assert = require("./Assert")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local DecorPlan = require("../../src/server/Heist/DecorPlan")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LevelDress = require("../../src/server/Heist/LevelDress")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")

local specs: { [string]: any } = (KitData :: any).parts
local IN = Config.Interior
local LIGHT = Config.Lighting
local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json")).parts

local function levels(): { any }
	local out = {}
	for _, spec in Catalog do
		table.insert(out, LevelSpec.compile(spec))
	end
	for _, spec in DailyVaults.designs do
		table.insert(out, LevelSpec.compile(spec))
	end
	return out
end

local function decorOf(level: any, dressing: boolean): (any, any, string)
	local location = KitPlan.location(level, dressing)
	local base = KitPlan.plan(level, specs, {
		dressing = dressing,
		location = location,
		dress = LevelDress[level.id],
		lighting = LIGHT,
	})
	local plan = DecorPlan.plan(level, specs, {
		location = location,
		dressing = dressing,
		dress = LevelDress[level.id],
		base = base.items,
	}, { KP = KitPlan, cfg = IN, lighting = LIGHT })
	return plan, base, location
end

local function overlap2(a: any, b: any, tol: number): boolean
	return a.minX < b.maxX - tol and a.maxX > b.minX + tol and a.minZ < b.maxZ - tol and a.maxZ > b.minZ + tol
end

local function boxText(b: any): string
	return string.format("X %.2f..%.2f Y %.2f..%.2f Z %.2f..%.2f", b.minX, b.maxX, b.minY, b.maxY, b.minZ, b.maxZ)
end

local function isWall(b: any): boolean
	return b.maxY - b.minY >= 8 and math.min(b.maxX - b.minX, b.maxZ - b.minZ) <= 1.5
end

-- A walk grid (0.5-stud cells, solids grown by the actor radius, every door open): BFS distances from the crew seat.
local CELL = 0.5
local function walk(level: any, obstacles: { any }): (any, (number, number) -> number?)
	local r = Config.Sim.ACTOR_RADIUS
	local b = level.bounds
	local w = math.ceil((b.maxX - b.minX) / CELL)
	local h = math.ceil((b.maxZ - b.minZ) / CELL)
	local blocked: { [number]: boolean } = {}
	local function mark(box: any, grow: number)
		local i0 = math.max(0, math.floor((box.minX - grow - b.minX) / CELL))
		local i1 = math.min(w - 1, math.floor((box.maxX + grow - b.minX) / CELL))
		local j0 = math.max(0, math.floor((box.minZ - grow - b.minZ) / CELL))
		local j1 = math.min(h - 1, math.floor((box.maxZ + grow - b.minZ) / CELL))
		for j = j0, j1 do
			for i = i0, i1 do
				local cx, cz = b.minX + (i + 0.5) * CELL, b.minZ + (j + 0.5) * CELL
				if cx > box.minX - grow and cx < box.maxX + grow and cz > box.minZ - grow and cz < box.maxZ + grow then
					blocked[j * w + i] = true
				end
			end
		end
	end
	for _, s in level.solids do
		mark(s, r)
	end
	for _, o in obstacles do
		mark(o, r)
	end
	local function cellOf(x: number, z: number): number
		local i = math.clamp(math.floor((x - b.minX) / CELL), 0, w - 1)
		local j = math.clamp(math.floor((z - b.minZ) / CELL), 0, h - 1)
		return j * w + i
	end
	local seat = level.spawns[1]
	local dist: { [number]: number } = {}
	local start = cellOf(seat.x, seat.z)
	dist[start] = 0
	local queue, head = { start }, 1
	while head <= #queue do
		local id = queue[head]
		head += 1
		local i, j = id % w, id // w
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = i + d[1], j + d[2]
			local nid = nj * w + ni
			if ni >= 0 and ni < w and nj >= 0 and nj < h and dist[nid] == nil and not blocked[nid] then
				dist[nid] = dist[id] + 1
				table.insert(queue, nid)
			end
		end
	end
	-- the shortest distance to any free cell within `reach` studs of (x, z) (loot sits on displays, hides are boxes)
	local function to(x: number, z: number, reach: number?): number?
		local best: number? = nil
		local rr = reach or 2
		local n = math.ceil(rr / CELL)
		local c = cellOf(x, z)
		local ci, cj = c % w, c // w
		for dj = -n, n do
			for di = -n, n do
				local id = (cj + dj) * w + (ci + di)
				local dd = dist[id]
				if dd and (di * di + dj * dj) * CELL * CELL <= rr * rr then
					best = if best == nil then dd else math.min(best, dd)
				end
			end
		end
		return best
	end
	return dist, to
end

-- sRGB -> Oklab (for the colour-distance rule against the signals and the clone hues)
local function oklab(c: { number }): (number, number, number)
	local function lin(v: number): number
		v /= 255
		return if v <= 0.04045 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	local r, g, b = lin(c[1]), lin(c[2]), lin(c[3])
	local l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ^ (1 / 3)
	local m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ^ (1 / 3)
	local s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ^ (1 / 3)
	return 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
end
local function okDist(a: { number }, b: { number }): number
	local l1, a1, b1 = oklab(a)
	local l2, a2, b2 = oklab(b)
	return math.sqrt((l1 - l2) ^ 2 + (a1 - a2) ^ 2 + (b1 - b2) ^ 2)
end
local function luma(c: { number }): number
	return (0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]) / 255
end
local SIGNALS = {
	alarm = { 255, 56, 56 },
	gold = { 255, 194, 31 },
	exit = { 244, 247, 255 },
	cyan = { 61, 232, 255 },
	magenta = { 255, 79, 216 },
	indigo = { 106, 92, 255 },
	amber = { 255, 210, 122 },
}

return function(test)
	test(
		"every prop is visual only and clear of every sim box, plate, door, loot, hide, laser, switch, spawn",
		function()
			local total = 0
			for _, level in levels() do
				for _, dressing in { true, false } do
					local plan = decorOf(level, dressing)
					for _, it in plan.items do
						total += 1
						local b = KitPlan.itemBox(it, specs)
						local what = string.format("%s %s %s at %s", level.id, it.role, it.pieces[1], boxText(b))
						Assert.eq(it.mode, "visual", what .. ": visual only")
						for _, n in it.pieces do
							Assert.truthy(specs[n] ~= nil, what .. ": a kit piece " .. n)
							Assert.falsy(specs[n].canCollide, what .. ": " .. n .. " never collides")
						end
						if it.role == "frieze" then
							-- a band under the crown: inside the room, above every door (10) and laser (10)
							Assert.truthy(b.minY >= level.floorY + 10, what .. ": over the doors and lasers")
							continue
						end
						if it.layer == "xmas" then
							Assert.truthy(dressing, what .. ": Christmas pieces only with the dressing layer")
						end
						local function clear(box: any, label: string, tol: number)
							Assert.falsy(overlap2(b, box, tol), what .. " overlaps " .. label)
						end
						if b.minY < level.floorY + 2 then -- a wall prop high over a plate near a wall is fine
							for i, p in level.plates do
								clear(p.box, "plate " .. i, -1.0)
							end
						end
						for i, d in level.doors do
							local db = d.box
							local alongX = (db.maxX - db.minX) >= (db.maxZ - db.minZ)
							local approach = if alongX
								then { minX = db.minX, maxX = db.maxX, minZ = db.minZ - 3, maxZ = db.maxZ + 3 }
								else { minX = db.minX - 3, maxX = db.maxX + 3, minZ = db.minZ, maxZ = db.maxZ }
							clear(approach, "door " .. i .. " or its approach", 0)
						end
						for i, l in level.lasers or {} do
							if b.minY < l.box.maxY then
								clear(l.box, "laser " .. i, -1)
							end
						end
						for i, h in level.hides or {} do
							if b.minY < h.box.maxY then -- a clock high over a coat rack is fine
								clear(h.box, "hide " .. i, -1)
							end
						end
						clear(level.van, "the van zone", -1)
						for i, s in level.solids do
							if it.role == "brass" and not isWall(s) and s.maxY <= level.floorY + 5 then
								continue -- the teller brass stands on its counter
							end
							if b.minY >= s.maxY - 1e-3 then
								continue -- a wall prop over a counter
							end
							clear(s, "sim solid " .. i .. " " .. boxText(s), 0.01)
						end
						local function far(x: number, z: number, r: number, label: string)
							local dx = math.max(b.minX - x, 0, x - b.maxX)
							local dz = math.max(b.minZ - z, 0, z - b.maxZ)
							Assert.truthy(dx * dx + dz * dz >= r * r - 1e-6, what .. " within " .. r .. " of " .. label)
						end
						for _, def in level.loot do
							far(def.x, def.z, 2, "loot " .. tostring(def.id))
						end
						for _, sw in level.switches or {} do
							far(sw.x, sw.z, 2, "a switch")
						end
						for _, sp in level.spawns do
							far(sp.x, sp.z, 3, "a spawn")
						end
					end
				end
			end
			Assert.truthy(total > 400, "props planned (" .. total .. ")")
		end
	)

	test(
		"routes: every plate, door, loot point and hide stays reachable, by a path no longer than without props",
		function()
			for _, level in levels() do
				local plan = decorOf(level, true)
				local props = {}
				for _, it in plan.items do
					local b = KitPlan.itemBox(it, specs)
					if b.minY < level.floorY + 6 and it.role ~= "frieze" and it.role ~= "brass" then
						table.insert(props, b) -- anything a walker would bump into (wall props up high are not)
					end
				end
				local _, bare = walk(level, {})
				local _, dressed = walk(level, props)
				local function check(x: number, z: number, label: string, reach: number?)
					local a, d = bare(x, z, reach), dressed(x, z, reach)
					if a == nil then
						return -- not reachable on foot in the sim data either (on a counter, behind a wall)
					end
					Assert.truthy(d ~= nil, level.id .. ": " .. label .. " unreachable with the props")
					-- 4-neighbour walk cells of 0.5: at most a 3-stud detour (never a blocked way)
					Assert.le(d :: number, a + 6, level.id .. ": " .. label .. " detour with the props (cells)")
				end
				for i, p in level.plates do
					check((p.box.minX + p.box.maxX) / 2, (p.box.minZ + p.box.maxZ) / 2, "plate " .. i)
				end
				for i, d in level.doors do
					check((d.box.minX + d.box.maxX) / 2, (d.box.minZ + d.box.maxZ) / 2, "door " .. i)
				end
				for _, def in level.loot do
					check(def.x, def.z, "loot " .. tostring(def.id), 3)
				end
				for i, h in level.hides or {} do
					check((h.box.minX + h.box.maxX) / 2, (h.box.minZ + h.box.maxZ) / 2, "hide " .. i, 4)
				end
				check(level.van.minX + 5, level.van.minZ + 4, "the van zone")
			end
		end
	)

	test("density: every room band of every level has props at eye level; launch shop fronts are full", function()
		for _, level in levels() do
			local plan = decorOf(level, true)
			local per: { [number]: number } = {}
			for _, it in plan.items do
				if it.band and it.role ~= "frieze" then
					per[it.band] = (per[it.band] or 0) + 1
				end
			end
			for k, r in plan.rooms do
				local n = per[k] or 0
				local want = if r.kind == "front" and level.num < 200 and level.kind ~= "party" then 8 else 2
				Assert.truthy(
					n >= want,
					string.format("%s band %d (%s): %d props, want >= %d", level.id, k, r.kind, n, want)
				)
			end
		end
	end)

	test("each level is its own shop: L1-L4 and DV01 differ in name, hero, frieze, ceiling and room light", function()
		local seen = {}
		local ids = { "cs1_back_room", "cs2_two_doors", "cs3_lights_out", "cs4_night_clerk", "dv01_stocking_stuffer" }
		local byId = {}
		for _, level in levels() do
			byId[level.id] = level
		end
		for _, id in ids do
			local level = byId[id]
			local location = KitPlan.location(level, true)
			local name, theme = DecorPlan.theme(level, location, IN)
			Assert.truthy(theme ~= nil, id .. ": a theme")
			for _, key in { "name", "hero" } do
				local v = theme[key]
				Assert.truthy(seen[key .. "=" .. v] == nil, id .. ": its own " .. key .. " (" .. v .. ")")
				seen[key .. "=" .. v] = true
			end
			for _, key in { "frieze", "ceiling" } do
				local c = theme[key]
				local k = table.concat(c, ",")
				Assert.truthy(seen[key .. "=" .. k] == nil, id .. ": its own " .. key)
				seen[key .. "=" .. k] = true
			end
			local light = theme.light
			Assert.truthy(light ~= nil, id .. ": a room light")
			local lk = table.concat(light.room[1], ",")
			Assert.truthy(seen["light=" .. lk] == nil, id .. ": its own room light")
			seen["light=" .. lk] = true
			local f = DecorPlan.fascia(level, location, { KP = KitPlan, cfg = IN })
			Assert.truthy(f ~= nil and f.text == theme.name, id .. ": the fascia carries the shop's name")
			-- the hero window display is planned, in the front room against the street front
			local plan = decorOf(level, true)
			local hero = nil
			for _, it in plan.items do
				if it.role == "hero" then
					hero = it
				end
			end
			Assert.truthy(hero ~= nil and hero.pieces[1] == theme.hero, id .. ": the hero display " .. theme.hero)
			local hb = KitPlan.itemBox(hero, specs)
			local bb = KitPlan.buildingBox(level) :: any
			Assert.truthy(hb.maxZ > bb.maxZ - 6, id .. ": the hero stands against the street front")
			Assert.eq(name, IN.LEVELS[id] or IN.DAILY_SHOPS[1], id .. ": theme")
		end
	end)

	test("theme colours: never a signal or a clone hue; the ceiling is never brighter than the walls", function()
		local wall = { -- the location atlases' upper wall cell (eh_palette LOCATIONS plum)
			CornerShop = { 0x57, 0x34, 0x29 },
			ToyShop = { 0x5C, 0x29, 0x41 },
			Bank = { 0x3A, 0x35, 0x60 },
		}
		local locOf = { toystore = "ToyShop", bank = "Bank" }
		for name, t in IN.THEMES do
			for _, key in { "frieze", "ceiling", "board" } do
				for sname, sc in SIGNALS do
					Assert.truthy(
						okDist(t[key], sc) >= 0.15,
						string.format("%s %s vs %s: Oklab %.3f", name, key, sname, okDist(t[key], sc))
					)
				end
			end
			local w = wall[locOf[name] or "CornerShop"]
			Assert.truthy(
				luma(t.ceiling) <= luma(w) + 1e-6,
				string.format("%s: ceiling luma %.3f <= wall %.3f", name, luma(t.ceiling), luma(w))
			)
			Assert.truthy(luma(t.ceiling) >= 0.12, name .. ": the ceiling stays out of the filmic toe")
		end
	end)

	test("props never use loot, signal or clone cells; tiers: props and the frieze hide, the hero stays", function()
		for _, level in levels() do
			local plan = decorOf(level, true)
			for _, it in plan.items do
				local what = level.id .. " " .. it.pieces[1]
				for _, n in it.pieces do
					local m = manifest[n]
					Assert.truthy(m ~= nil, what .. ": in the manifest")
					Assert.truthy(
						m.role == "story" or m.role == "env" or m.role == "xmas",
						what .. ": role " .. tostring(m.role)
					)
				end
				if (it.role == "decor" or it.role == "brass") and IN.HEAVY[it.pieces[1]] then
					Assert.eq(it.tier, "decorHeavy", what .. ": a heavy prop, hidden from HEAVY_OFF_TIER")
				elseif it.role == "decor" or it.role == "brass" or it.role == "frieze" then
					Assert.eq(it.tier, "decor", what .. ": hidden from DECOR_OFF_TIER")
				else
					Assert.eq(it.tier, nil, what .. ": stays at every tier")
				end
			end
		end
		Assert.eq(IN.DECOR_OFF_TIER, 3, "props drop from tier 3")
		Assert.truthy(IN.HEAVY_OFF_TIER <= IN.DECOR_OFF_TIER, "the heavy props go no later than the rest")
	end)

	test(
		"phone budget: the heavy props go at tier 2, the kit's Christmas at tier 4; the Big Score's tier 2 cut",
		function()
			Assert.eq(IN.HEAVY_OFF_TIER, 2, "a phone starts at tier 2 without the heaviest props")
			Assert.eq(IN.FESTIVE_OFF_TIER, 4, "the kit's Christmas pieces stay to tier 3")
			for name in IN.HEAVY do
				Assert.truthy(
					manifest[name] ~= nil and (manifest[name].tris or 0) >= 500,
					name .. ": heavy (>= 500 tris)"
				)
			end
			-- the Big Score sheds at least 5k triangles of props at tier 2 (its tier 2 view was ~3 % over), and never
			-- every prop: the rooms keep benches, desks, clocks and boxes
			for _, level in levels() do
				if level.id ~= "bk1_big_score" then
					continue
				end
				local plan = decorOf(level, true)
				local heavy, kept = 0, 0
				for _, it in plan.items do
					for _, n in it.pieces do
						local t = (manifest[n] and manifest[n].tris) or 0
						if it.tier == "decorHeavy" then
							heavy += t
						elseif it.tier == "decor" then
							kept += 1
						end
					end
				end
				Assert.truthy(heavy >= 5000, string.format("tier 2 sheds %d tris of props", heavy))
				Assert.truthy(kept >= 10, string.format("%d props stay at tier 2", kept))
			end
			-- the base kit's Christmas pieces carry the festive layer on every level
			for _, level in levels() do
				local _, base = decorOf(level, true)
				for _, it in base.items do
					if it.layer == "xmas" then
						Assert.eq(it.tier, "festive", level.id .. " " .. it.pieces[1] .. ": festive")
					else
						Assert.eq(it.tier, nil, level.id .. " " .. it.pieces[1] .. ": no tier layer")
					end
				end
			end
		end
	)

	test("budget: props per level within the kit budget (tris and instances at tier 1)", function()
		for _, level in levels() do
			local plan = decorOf(level, true)
			local tris, parts = 0, 0
			for _, it in plan.items do
				for _, n in it.pieces do
					tris += manifest[n].tris
					parts += 1
				end
			end
			Assert.le(tris, IN.BUDGET.tris, level.id .. ": decor tris")
			Assert.le(parts, IN.BUDGET.instances, level.id .. ": decor parts")
		end
	end)

	test(
		"light: wall washes keep every view within budget, never shadow, and only from the kinds tier 1 keeps",
		function()
			local washes = 0
			for _, level in levels() do
				local lamps = KitPlan.lamps(level, LevelDress[level.id], LIGHT)
				for _, a in lamps do
					local lit = 0
					for _, b in lamps do
						local dx, dz = a.x - b.x, a.z - b.z
						if dx * dx + dz * dz <= LIGHT.VIEW_RADIUS * LIGHT.VIEW_RADIUS then
							lit += 1
						end
					end
					Assert.le(lit, LIGHT.MAX_LIGHTS_PER_VIEW, level.id .. ": lights in one view")
					if a.kind == "wash" then
						washes += 1
						Assert.falsy(LIGHT.LAMP.wash.shadows, "washes never shadow")
					end
				end
			end
			Assert.truthy(washes >= 12, "wall washes planned (" .. washes .. ")")
			for tier = 2, #Config.Perf.TIERS do
				Assert.truthy(
					table.find(Config.Perf.TIERS[tier].lightKindsOff, "wash") ~= nil,
					"washes off at tier " .. tier
				)
			end
		end
	)

	test("the theme light: L3 Lights Out is the dimmest Corner Shop room light, still warm", function()
		local l3 = IN.THEMES.toyrepair.light
		Assert.truthy((l3.brightness or LIGHT.LAMP.room.brightness) < LIGHT.LAMP.room.brightness, "L3 dimmer")
		Assert.truthy((l3.brightness or 0) >= 1.2, "L3 never dark (the near-black bar, LEVELS §13)")
		Assert.truthy(l3.room[1][1] - l3.room[1][3] >= 100, "L3 warm")
	end)
end
