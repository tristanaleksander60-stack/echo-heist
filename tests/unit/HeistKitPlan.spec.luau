-- L1: Heist/KitPlan, where the art kit goes on a level (docs/art/KIT_IMPORT.md). The kit is the
-- look, never the collision: these specs check the placement maths and, on every launch level
-- and daily vault, that wall pieces stay inside their sim walls, door leaves are exactly the
-- door boxes, nothing covers a doorway, and the Christmas layer appears only when asked for. Light and
-- levels (LEVELS.md §4 P0): lamps over plates / goal / rooms within the per-view light budget, honest
-- cables (L2's two never touch), L1's partition windows and the goal displays.

local KitPlan = require("../../src/server/Heist/KitPlan")
local KitData = require("../../src/server/Kit/KitData")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Catalog = require("../../src/shared/Levels/Catalog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local LevelDress = require("../../src/server/Heist/LevelDress")

local LIGHT = Config.Lighting

local specs: { [string]: any } = (KitData :: any).parts
local TOL = 1e-4

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

local function within(inner: any, outer: any, tol: number): boolean
	return inner.minX >= outer.minX - tol
		and inner.maxX <= outer.maxX + tol
		and inner.minY >= outer.minY - tol
		and inner.maxY <= outer.maxY + tol
		and inner.minZ >= outer.minZ - tol
		and inner.maxZ <= outer.maxZ + tol
end

local function overlap(a: any, b: any, tol: number): boolean
	return a.minX < b.maxX - tol
		and a.maxX > b.minX + tol
		and a.minY < b.maxY - tol
		and a.maxY > b.minY + tol
		and a.minZ < b.maxZ - tol
		and a.maxZ > b.minZ + tol
end

local function boxText(b: any): string
	return string.format("X %.2f..%.2f Y %.2f..%.2f Z %.2f..%.2f", b.minX, b.maxX, b.minY, b.maxY, b.minZ, b.maxZ)
end

local function location(level: any): string
	return level.spec.location or "CornerShop"
end

return function(test)
	test("fit: a wall module lands exactly on its box at every quarter turn", function()
		local wall = specs.Wall_8x12
		local lo, hi = { -8, 0, 0 }, { 0, 12, 2 }
		for _, yaw in { 0, 90, 180, -90 } do
			local along = yaw == 0 or yaw == 180
			local box = if along
				then KitPlan.box(-10, 0, -20.5, -2, 12, -19.5)
				else KitPlan.box(-16.5, 0, -34, -15.5, 12, -26)
			local pivot, scale = KitPlan.fit(lo, hi, box, yaw)
			local item = { pieces = { "Wall_8x12" }, pivot = pivot, scale = scale }
			local got = KitPlan.itemBox(item :: any, specs)
			for _, k in { "minX", "maxX", "minY", "maxY", "minZ", "maxZ" } do
				Assert.near(got[k], box[k], TOL, string.format("yaw %d %s", yaw, k))
			end
			local c, size = KitPlan.partFrame(wall, pivot, scale)
			Assert.near(c[2], 6, TOL, "centre height")
			Assert.near(size[1], 8, TOL, "module length")
			Assert.near(size[3], 1, TOL, "thickness squashed to the sim wall")
		end
	end)

	test("place: unscaled piece centred on a point, bottom on the floor", function()
		local lo = { -1.32, 0, -0.55 }
		local hi = { 1.32, 1.1, 0.55 }
		local pivot, scale = KitPlan.place(lo, hi, 4, 2, -7, 90)
		local got = KitPlan.itemBox({ pieces = { "Candy" }, pivot = pivot, scale = scale } :: any, specs)
		Assert.near((got.minX + got.maxX) / 2, 4, TOL, "x")
		Assert.near((got.minZ + got.maxZ) / 2, -7, TOL, "z")
		Assert.near(got.minY, 2, TOL, "bottom")
		Assert.near(got.maxX - got.minX, 1.1, TOL, "rotated footprint")
	end)

	test("tiles: 8-wide modules, then one scaled 4 or 8, slivers widen the last", function()
		local t = KitPlan.tiles(-34, 10)
		Assert.eq(#t, 6, "44 studs")
		Assert.eq(t[6][3], 4, "last module is a 4")
		t = KitPlan.tiles(-15.5, -4)
		Assert.eq(#t, 2, "11.5 studs")
		Assert.near(t[2][2] - t[2][1], 3.5, TOL, "scaled remainder")
		t = KitPlan.tiles(0, 8.1)
		Assert.eq(#t, 1, "a 0.1 sliver widens the module")
		Assert.near(t[1][2], 8.1, TOL, "widened end")
		Assert.eq(#KitPlan.tiles(3, 3), 0, "empty span")
	end)

	test("every level: walls stay inside their sim walls and never cover a doorway", function()
		for _, level in levels() do
			for _, dressing in { false, true } do
				local plan = KitPlan.plan(level, specs, {
					dressing = dressing,
					location = location(level),
					dress = LevelDress[level.id],
					lighting = LIGHT,
				})
				for _, item in plan.items do
					for _, name in item.pieces do
						Assert.truthy(specs[name], level.id .. ": unknown piece " .. name)
					end
					local b = KitPlan.itemBox(item, specs)
					if item.role == "wall" or item.role == "pillar" or item.role == "shelf" then
						local solid = level.spec.solids[item.index].box
						-- walls exactly; shelves and pillars may show their 0.08-0.15 trim lips
						local tol = if item.role == "wall" then 1e-3 else 0.2
						Assert.truthy(
							within(b, solid, tol),
							string.format("%s: %s %s outside solid %s", level.id, item.role, boxText(b), boxText(solid))
						)
					end
					if item.role == "wall" or item.role == "frame" then
						for _, d in level.doors do
							local inner = KitPlan.box(
								d.box.minX + 0.01,
								d.box.minY,
								d.box.minZ + 0.01,
								d.box.maxX - 0.01,
								d.box.maxY - 2.5,
								d.box.maxZ - 0.01
							)
							if item.role == "wall" then
								Assert.falsy(overlap(b, inner, 1e-3), level.id .. ": a wall tile covers door " .. d.id)
							end
						end
					end
				end
			end
		end
	end)

	test("every level: wall tiles of one line never overlap each other or a frame", function()
		for _, level in levels() do
			local plan = KitPlan.plan(level, specs, { location = location(level) })
			local lineItems = {}
			for _, item in plan.items do
				if item.role == "wall" or item.role == "frame" or item.role == "front" or item.role == "vaultFrame" then
					table.insert(lineItems, { item = item, box = KitPlan.itemBox(item, specs) })
				end
			end
			for i = 1, #lineItems do
				for j = i + 1, #lineItems do
					local a, b = lineItems[i], lineItems[j]
					-- Corner joins share at most the wall band of the perpendicular wall.
					if a.item.role == "wall" and b.item.role == "wall" and a.item.index == b.item.index then
						Assert.falsy(
							overlap(a.box, b.box, 1e-3),
							string.format("%s: tiles of solid %d overlap", level.id, a.item.index)
						)
					elseif a.item.role ~= "wall" or b.item.role ~= "wall" then
						-- frames sit in cuts of their own line
						local sameLine = math.abs((a.box.minZ + a.box.maxZ) - (b.box.minZ + b.box.maxZ)) < 0.6
							and math.abs((a.box.maxZ - a.box.minZ) - (b.box.maxZ - b.box.minZ)) < 2
						if sameLine and math.abs(a.box.maxZ - a.box.minZ) < 3 then
							local xa = math.min(a.box.maxX, b.box.maxX) - math.max(a.box.minX, b.box.minX)
							Assert.le(xa, 1e-3, level.id .. ": " .. a.item.role .. " overlaps " .. b.item.role)
						end
					end
				end
			end
		end
	end)

	test("every level: door leaves are exactly the door boxes; plates and loot all dressed", function()
		for _, level in levels() do
			local plan = KitPlan.plan(level, specs, { location = location(level) })
			local doors, plates, loot = {}, {}, {}
			for _, item in plan.items do
				if item.mode == "swap" then
					Assert.truthy(
						item.role == "door" or item.role == "plate" or item.role == "loot",
						"only doors, plates and loot are swapped"
					)
					if item.role == "door" then
						local b = KitPlan.itemBox(item, specs)
						local d = level.doors[item.index].box
						for _, k in { "minX", "maxX", "minY", "maxY", "minZ", "maxZ" } do
							Assert.near(b[k], d[k], 1e-3, level.id .. " door " .. item.index .. " " .. k)
						end
						doors[item.index] = true
					elseif item.role == "plate" then
						local b = KitPlan.itemBox(item, specs)
						local p = level.plates[item.index].box
						Assert.near((b.minX + b.maxX) / 2, (p.minX + p.maxX) / 2, 1e-3, "plate x")
						Assert.near((b.minZ + b.maxZ) / 2, (p.minZ + p.maxZ) / 2, 1e-3, "plate z")
						Assert.near(b.minY, level.floorY, 1e-3, "plate on the floor")
						plates[item.index] = true
					else
						loot[item.index] = true
					end
				end
			end
			for i, d in level.doors do
				local vault = location(level) == "Bank" and string.find(string.lower(d.id), "vault", 1, true)
				Assert.truthy(doors[i] or vault, level.id .. ": door " .. d.id .. " not dressed")
			end
			for i in level.plates do
				Assert.truthy(plates[i], level.id .. ": plate " .. i .. " not dressed")
			end
			for i in level.loot do
				Assert.truthy(loot[i], level.id .. ": loot " .. i .. " has no kit mesh")
			end
		end
	end)

	test("street fronts, vault frames and the swing skin", function()
		for _, level in levels() do
			local plan = KitPlan.plan(level, specs, { location = location(level) })
			local fronts, vaultFrames, skins = 0, 0, 0
			for _, item in plan.items do
				if item.role == "front" then
					fronts += 1
					Assert.eq(
						item.pieces[1],
						if location(level) == "Bank" then "BankFront_24x12" else "Storefront_24x12",
						level.id .. " front piece"
					)
				elseif item.role == "vaultFrame" then
					vaultFrames += 1
				elseif item.role == "vaultSkin" then
					skins += 1
					Assert.eq(item.mode, "skin", "skin mode")
					Assert.eq(item.openYaw, -175, "vault door swing")
				end
			end
			Assert.eq(fronts, 1, level.id .. ": one street front")
			local vaults = 0
			for _, d in level.doors do
				if location(level) == "Bank" and string.find(string.lower(d.id), "vault", 1, true) then
					vaults += 1
				end
			end
			Assert.eq(vaultFrames, vaults, level.id .. ": vault frames")
			Assert.eq(skins, vaults, level.id .. ": vault skins")
		end
	end)

	test("Christmas layer only when dressing; candy-cane posts on lasers", function()
		for _, level in levels() do
			local off = KitPlan.plan(level, specs, { location = location(level) })
			for _, item in off.items do
				local tree = item.role == "hide" and item.pieces[1] == "Xmas_Tree" -- a hide prop (DV04)
				Assert.truthy(item.layer == "base" or tree, level.id .. ": xmas piece with dressing off")
				if item.role == "post" then
					Assert.eq(item.pieces[1], "LaserEmitter", "plain post")
				end
			end
			local on = KitPlan.plan(level, specs, { dressing = true, location = location(level) })
			local xmas = 0
			for _, item in on.items do
				if item.layer == "xmas" then
					xmas += 1
				end
				if item.role == "post" then
					Assert.eq(item.pieces[1], "LaserEmitter_CandyCane", "candy-cane post")
				end
			end
			Assert.truthy(xmas >= 4, level.id .. ": Christmas pieces placed (" .. xmas .. ")")
		end
	end)

	test("hides over plates put the open niche on the plate", function()
		local l4 = nil
		for _, spec in Catalog do
			if spec.id == "cs4_night_clerk" then
				l4 = LevelSpec.compile(spec)
			end
		end
		Assert.truthy(l4, "L4 in the Catalog")
		local plan = KitPlan.plan(l4, specs, { location = "CornerShop" })
		local found = false
		for _, item in plan.items do
			if item.role == "hide" and item.pieces[1] == "Hide_CoatRack" then
				found = true
				local p = l4.plates[2].box -- plate B under the coat rack
				local b = KitPlan.itemBox(item, specs)
				Assert.near((b.minX + b.maxX) / 2, (p.minX + p.maxX) / 2, 1e-3, "niche x on plate B")
				Assert.near((b.minZ + b.maxZ) / 2, (p.minZ + p.maxZ) / 2, 1e-3, "niche z on plate B")
			end
		end
		Assert.truthy(found, "L4 coat rack planned")
	end)

	test("every level: the kit van (visual only) keeps clear of spawns and the van zone", function()
		for _, level in levels() do
			local plan = KitPlan.plan(level, specs, {})
			local vb = plan.vanBox
			if vb then
				local function inside(x: number, z: number, pad: number): boolean
					return x > vb.minX - pad and x < vb.maxX + pad and z > vb.minZ - pad and z < vb.maxZ + pad
				end
				for i, sp in level.spawns do
					Assert.falsy(inside(sp.x, sp.z, 1), level.id .. ": spawn " .. i .. " under the kit van")
				end
				local v = level.van
				Assert.falsy(
					vb.minZ < v.maxZ and vb.maxZ > v.minZ and vb.minX < v.maxX and vb.maxX > v.minX,
					level.id .. ": the kit van covers the van zone"
				)
				-- Centred on the greybox van body (the collider), so the Line-up's van clearance,
				-- which uses the larger of the two footprints (EH_VisualSize), is right.
				local cx, cz = (vb.minX + vb.maxX) / 2, (vb.minZ + vb.maxZ) / 2
				Assert.truthy(
					math.abs(cx - (v.minX + v.maxX) / 2) < 0.01 and math.abs(cz - (v.maxZ + 4.5)) < 0.01,
					level.id .. ": kit van centred on the van body"
				)
			end
		end
	end)

	test("lamps: one over each plate, a hero over the goal, rooms; within the per-view budget", function()
		for _, level in levels() do
			local lamps = KitPlan.lamps(level, LevelDress[level.id], LIGHT)
			Assert.truthy(#lamps >= 2, level.id .. ": at least two lamps (" .. #lamps .. ")")
			for i, p in level.plates do
				local cx, cz = (p.box.minX + p.box.maxX) / 2, (p.box.minZ + p.box.maxZ) / 2
				local found = false
				for _, l in lamps do
					found = found or (l.kind == "plate" and l.index == i and l.x == cx and l.z == cz)
				end
				Assert.truthy(found, level.id .. ": a lamp over plate " .. p.id)
			end
			local heroes = 0
			for _, l in lamps do
				if l.kind == "hero" then
					heroes += 1
					local g = level.loot[KitPlan.goal(level) :: number]
					Assert.truthy(l.x == g.x and l.z == g.z, level.id .. ": the hero lamp is over the goal")
				end
			end
			Assert.eq(heroes, 1, level.id .. ": one hero lamp")
			for _, a in lamps do
				local lit, shadowed = 0, 0
				for _, b in lamps do
					local dx, dz = a.x - b.x, a.z - b.z
					if dx * dx + dz * dz <= LIGHT.VIEW_RADIUS * LIGHT.VIEW_RADIUS then
						lit += 1
						if LIGHT.LAMP[b.kind].shadows then
							shadowed += 1
						end
					end
				end
				Assert.le(lit, LIGHT.MAX_LIGHTS_PER_VIEW, level.id .. ": lights in one view")
				Assert.le(shadowed, LIGHT.MAX_SHADOWED_PER_VIEW, level.id .. ": shadowed lights in one view")
			end
		end
	end)

	test("lamps: L1, L2 and Clone Party at the LEVELS.md §4 P0-3 spots", function()
		local want = {
			cs1_back_room = { { 10, -8, "plate" }, { 10, -26, "hero" }, { -10, -2, "room" } },
			cs2_two_doors = { { -10, -8, "plate" }, { 10, -8, "plate" }, { 0, -26, "room" }, { 0, -40, "hero" } },
			cs5_clone_party = { { -4, -14, "room" }, { 4, -14, "room" }, { -8.5, -1, "hero" }, { 0, -34, "room" } },
		}
		for _, spec in Catalog do
			local list = want[spec.id]
			if list then
				local level = LevelSpec.compile(spec)
				local lamps = KitPlan.lamps(level, LevelDress[level.id], LIGHT)
				for _, w in list do
					local found = false
					for _, l in lamps do
						found = found
							or (math.abs(l.x - w[1]) < 1e-6 and math.abs(l.z - w[2]) < 1e-6 and l.kind == w[3])
					end
					Assert.truthy(found, string.format("%s: %s lamp at (%g, %g)", spec.id, w[3], w[1], w[2]))
				end
			end
		end
	end)

	test("cables: L1 and L2 run to the near jamb, L2's two never touch, none crosses a wall", function()
		local function segs(cb: any): { any }
			local out = {}
			for k = 1, #cb.points - 1 do
				table.insert(out, { cb.points[k], cb.points[k + 1] })
			end
			return out
		end
		-- distance between two axis-aligned segments (cables only run along X or Z)
		local function gap(s1: any, s2: any): number
			local ax0, ax1 = math.min(s1[1][1], s1[2][1]), math.max(s1[1][1], s1[2][1])
			local az0, az1 = math.min(s1[1][2], s1[2][2]), math.max(s1[1][2], s1[2][2])
			local bx0, bx1 = math.min(s2[1][1], s2[2][1]), math.max(s2[1][1], s2[2][1])
			local bz0, bz1 = math.min(s2[1][2], s2[2][2]), math.max(s2[1][2], s2[2][2])
			local dx = math.max(0, bx0 - ax1, ax0 - bx1)
			local dz = math.max(0, bz0 - az1, az0 - bz1)
			return math.sqrt(dx * dx + dz * dz)
		end
		for _, spec in Catalog do
			local level = LevelSpec.compile(spec)
			local cables = KitPlan.cables(level, LIGHT)
			if spec.id == "cs1_back_room" then
				local last = cables[1].points[#cables[1].points]
				Assert.truthy(last[1] == 2.5 and last[2] == -19, "L1: A ends at the east jamb (2.5, -19)")
			elseif spec.id == "cs2_two_doors" then
				Assert.eq(#cables, 2, "L2: two cables")
				local a, b = cables[1], cables[2]
				local ea, eb = a.points[#a.points], b.points[#b.points]
				Assert.truthy(ea[1] == -2.5 and ea[2] == -19, "L2: A ends at the BackRoom's west jamb")
				Assert.truthy(eb[1] == 2.5 and eb[2] == -31, "L2: B ends at the Stockroom's east jamb")
				for _, s1 in segs(a) do
					for _, s2 in segs(b) do
						Assert.truthy(gap(s1, s2) >= 2 * LIGHT.CABLE_WIDTH, "L2: the two cables never touch")
					end
				end
			end
			-- no cable point sits inside a tall solid (it would vanish into a wall); every launch level
			do
				for _, cb in cables do
					for _, sg in segs(cb) do
						for t = 0, 20 do
							local x = sg[1][1] + (sg[2][1] - sg[1][1]) * t / 20
							local z = sg[1][2] + (sg[2][2] - sg[1][2]) * t / 20
							for _, s in level.spec.solids or {} do
								local bx = s.box
								local tall = bx.maxY - bx.minY > 5
								Assert.falsy(
									tall and x > bx.minX and x < bx.maxX and z > bx.minZ and z < bx.maxZ,
									string.format(
										"%s: cable of plate %d inside a wall at (%.1f, %.1f)",
										spec.id,
										cb.plate,
										x,
										z
									)
								)
							end
						end
					end
				end
			end
		end
	end)

	test("letters: plates and the devices they drive share one", function()
		for _, spec in Catalog do
			local level = LevelSpec.compile(spec)
			for i, p in level.plates do
				Assert.eq(KitPlan.letter(level, i), p.id, spec.id .. ": plate letter")
			end
			for _, d in level.doors do
				for _, src in d.openBy do
					if src.kind == "plate" then
						local letters = KitPlan.deviceLetters(level, d.openBy)
						Assert.truthy(
							string.find(letters, KitPlan.letter(level, src.index), 1, true) ~= nil,
							spec.id .. ": door " .. d.id .. " carries its plate's letter"
						)
					end
				end
			end
		end
	end)

	test("L1 windows beside the back-room door; L2 safe and L5 till displays; lamps dressed", function()
		for _, spec in Catalog do
			local level = LevelSpec.compile(spec)
			local plan = KitPlan.plan(level, specs, {
				location = location(level),
				dress = LevelDress[level.id],
				lighting = LIGHT,
			})
			local windows, displays, lamps = {}, {}, 0
			for _, item in plan.items do
				if item.pieces[1] == "Wall_Window_8x12" then
					table.insert(windows, KitPlan.itemBox(item, specs))
				elseif item.role == "display" then
					table.insert(displays, item)
				elseif item.role == "lamp" then
					lamps += 1
				end
			end
			local fixtures = 0
			for _, l in KitPlan.lamps(level, LevelDress[level.id], LIGHT) do
				fixtures += if l.kind == "wash" then 0 else 1 -- a wall wash is a light only
			end
			Assert.eq(lamps, fixtures, spec.id .. ": a Lamp_Ceiling per lamp")
			if spec.id == "cs1_back_room" then
				Assert.eq(#windows, 2, "L1: two partition windows")
				for _, b in windows do
					Assert.near((b.minZ + b.maxZ) / 2, -20, 1e-3, "L1: on the z -20 partition")
					local inner = math.min(math.abs(b.minX), math.abs(b.maxX))
					Assert.near(inner, 4, 1e-3, "L1: the window starts at the door frame")
				end
			elseif spec.id == "cs2_two_doors" then
				Assert.eq(#displays, 1, "L2: one display")
				Assert.eq(displays[1].pieces[1], "Safe", "L2: the safe is a Safe")
				for _, item in plan.items do
					if item.role == "loot" and level.loot[item.index].id == "Safe" then
						local b = KitPlan.itemBox(item, specs)
						local d = KitPlan.itemBox(displays[1], specs)
						Assert.near(b.minY, d.maxY, 0.05, "L2: the cash sits on the safe")
					end
				end
			else
				Assert.eq(#windows, 0, spec.id .. ": no windows")
			end
		end
	end)

	test("signature props: planned where LevelDress puts them, clear of every gameplay spot", function()
		local seen: { [string]: number } = {}
		for _, spec in Catalog do
			local level = LevelSpec.compile(spec)
			local dress = LevelDress[level.id]
			local plan = KitPlan.plan(level, specs, { dress = dress, lighting = LIGHT, dressing = true })
			local items = {}
			for _, item in plan.items do
				if item.role == "signature" then
					table.insert(items, item)
					seen[item.pieces[1]] = (seen[item.pieces[1]] or 0) + 1
				end
			end
			Assert.eq(#items, if dress and dress.props then #dress.props else 0, level.id .. ": one item per prop")
			for _, item in items do
				local b = KitPlan.itemBox(item, specs)
				local what = level.id .. " " .. item.pieces[1] .. " at " .. boxText(b)
				Assert.eq(item.mode, "visual", what .. ": visual only")
				local flat = KitPlan.box(b.minX, -1e3, b.minZ, b.maxX, 1e3, b.maxZ)
				local function clearOf(box: any, label: string)
					Assert.falsy(overlap(flat, box, 0.05), what .. " overlaps " .. label)
				end
				local function pointClear(x: number, z: number, margin: number, label: string)
					local inside = x > b.minX - margin
						and x < b.maxX + margin
						and z > b.minZ - margin
						and z < b.maxZ + margin
					Assert.falsy(inside, what .. " within " .. margin .. " of " .. label)
				end
				for i, p in level.plates do
					clearOf(p.box, "plate " .. i)
				end
				for i, d in level.doors do
					clearOf(d.box, "door " .. i)
				end
				for i, l in level.lasers or {} do
					clearOf(l.box, "laser " .. i)
				end
				for i, h in level.hides or {} do
					clearOf(h.box, "hide " .. i)
				end
				clearOf(level.van, "the van zone")
				for _, s in level.spec.solids or {} do
					if s.box.maxY - s.box.minY < 8 then -- counters, shelves: never inside one (a lamp sits on top)
						Assert.falsy(overlap(b, s.box, 0.05), what .. " cuts into a low solid " .. boxText(s.box))
					end
				end
				for _, def in level.loot do
					pointClear(def.x, def.z, 1, "loot " .. tostring(def.id))
				end
				for _, n in level.spec.nav or {} do
					pointClear(n.x, n.z, 1.5, string.format("nav (%g, %g)", n.x, n.z))
				end
				for _, sp in level.spawns do
					pointClear(sp.x, sp.z, 3, "a spawn")
				end
			end
		end
		Assert.eq(seen.ToySoldier, 1, "one giant toy soldier (L5)")
		Assert.eq(seen.Column_2x12, 6, "six bank columns (L6)")
		Assert.eq(seen.BankersLamp, 2, "two banker's lamps (L6)")
	end)

	test("lamp looks: each location's room colour, signals and the hero unchanged, no light added", function()
		for _, level in levels() do
			local lamps = KitPlan.lamps(level, LevelDress[level.id], LIGHT)
			for _, loc in { "CornerShop", "ToyShop", "Bank" } do
				local looks = KitPlan.lampLooks(lamps, loc, LIGHT)
				Assert.eq(#looks, #lamps, level.id .. ": one look per lamp")
				local look = LIGHT.LOCATION[loc]
				local rooms = 0
				for k, l in lamps do
					if l.kind == "room" then
						rooms += 1
						Assert.eq(looks[k].color, look.room[(rooms - 1) % #look.room + 1], level.id .. " room colour")
						Assert.eq(looks[k].pool, look.pool, level.id .. " room pool")
					else
						Assert.eq(looks[k].color, LIGHT.LAMP[l.kind].color, level.id .. " " .. l.kind .. " keeps warm")
						Assert.eq(
							looks[k].pool,
							LIGHT.LAMP[l.kind].poolColor or LIGHT.POOL.color,
							level.id .. " " .. l.kind .. " pool"
						)
					end
				end
			end
		end
		Assert.eq(KitPlan.location(LevelSpec.compile(Catalog[3]), true), "ToyShop", "Clone Party dressed = Toy Shop")
		Assert.eq(KitPlan.location(LevelSpec.compile(Catalog[3]), false), "CornerShop", "plain = Corner Shop")
	end)

	test("warm pass: street lamps on the pavement and rugs in the pools, clear of every gameplay box", function()
		local streets, rugCount = 0, 0
		for _, level in levels() do
			local dress = LevelDress[level.id]
			local plan = KitPlan.plan(level, specs, { dress = dress, lighting = LIGHT, dressing = true })
			local lamps = KitPlan.lamps(level, dress, LIGHT)
			-- a level without hand dressing (the daily vaults) gets its front's pair (KitPlan.defaultStreet, WORLD 2.0)
			local wantStreet = if dress and dress.street then #dress.street else #KitPlan.defaultStreet(level, dress)
			local n = 0
			for k, l in lamps do
				if l.kind == "street" then
					n += 1
					local fp = (KitPlan.lampLooks(lamps, "CornerShop", LIGHT))[k]
					Assert.eq(fp.color, LIGHT.LAMP.street.color, level.id .. ": street lamps keep their warm colour")
				end
			end
			Assert.eq(n, wantStreet, level.id .. ": one street lamp per LevelDress entry (or the default pair)")
			streets += n
			local footprint = nil
			for _, s in level.spec.solids or {} do
				if s.box.maxY - s.box.minY >= 8 then
					footprint = footprint
						or { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
					footprint.minX = math.min(footprint.minX, s.box.minX)
					footprint.maxX = math.max(footprint.maxX, s.box.maxX)
					footprint.minZ = math.min(footprint.minZ, s.box.minZ)
					footprint.maxZ = math.max(footprint.maxZ, s.box.maxZ)
				end
			end
			for _, item in plan.items do
				local what = level.id .. " " .. item.role .. " " .. item.pieces[1]
				if item.role == "lamp" and item.pieces[1] == "StreetLamp" then
					Assert.eq(item.mode, "visual", what .. ": visual only")
					local b = KitPlan.itemBox(item, specs)
					local cx, cz = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
					local building = KitPlan.buildingBox(level)
					Assert.truthy(
						footprint == nil
							or cz > footprint.maxZ
							or (
								building ~= nil
								and (cx < building.minX - 1.5 or cx > building.maxX + 1.5 or cz < building.minZ - 1.5)
							),
						what .. ": on the pavement or in a lot's alley, outside the building"
					)
					for _, sp in level.spawns do
						local dx, dz = sp.x - cx, sp.z - cz
						Assert.truthy(dx * dx + dz * dz >= 9, what .. ": 3+ studs from every crew seat")
					end
				end
				if item.role == "rug" or (item.role == "lamp" and item.pieces[1] == "StreetLamp") then
					if item.role == "rug" then
						rugCount += 1
						Assert.eq(item.mode, "visual", what .. ": visual only")
					end
					local b = KitPlan.itemBox(item, specs)
					local flat = KitPlan.box(b.minX, -1e3, b.minZ, b.maxX, 1e3, b.maxZ)
					local where = what .. " at " .. boxText(b)
					for i, p in level.plates do
						Assert.falsy(overlap(flat, p.box, 0.05), where .. " overlaps plate " .. i)
					end
					for i, d in level.doors do
						Assert.falsy(overlap(flat, d.box, 0.05), where .. " overlaps door " .. i)
					end
					for i, l in level.lasers or {} do
						Assert.falsy(overlap(flat, l.box, 0.05), where .. " overlaps laser " .. i)
					end
					for i, h in level.hides or {} do
						Assert.falsy(overlap(flat, h.box, 0.05), where .. " overlaps hide " .. i)
					end
					Assert.falsy(overlap(flat, level.van, 0.05), where .. " overlaps the van zone")
					for _, s in level.spec.solids or {} do
						Assert.falsy(overlap(flat, s.box, 0.05), where .. " overlaps a solid " .. boxText(s.box))
					end
					if item.role == "rug" then
						-- under the lamp pools (pool lift) and over the kit floor tiles
						Assert.truthy(
							b.minY > level.floorY + Config.Heist.KIT_FLOOR_LIFT
								and b.maxY < level.floorY + LIGHT.POOL.lift,
							where .. ": between the floor tiles and the pools"
						)
					end
				end
			end
		end
		Assert.eq(
			streets,
			16 + 2 * 12,
			"street lamps: two on L1-L5 each, six on L6 (front, service alley, side alleys), two on every daily vault"
		)
		Assert.truthy(rugCount >= 20, "rugs on L1-L6 (" .. rugCount .. ")")
	end)

	test("van paint: a mid value, never Getaway White", function()
		local c = LIGHT.VAN.paint
		local luma = (0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]) / 255
		Assert.truthy(luma > 0.25 and luma < 0.55, "van paint luma " .. luma .. " is a mid value")
		Assert.truthy(specs.Van_Paint ~= nil and specs.Van_Paint.atlas == false, "Van_Paint is the runtime paint part")
		Assert.eq(specs.Van_Paint.model, "Van", "Van_Paint is planned with the van")
	end)

	test("missing or avoided pieces fall back (nothing planned for them)", function()
		local level = LevelSpec.compile(Catalog[1])
		local plan = KitPlan.plan(level, specs, { avoid = { Wall_Door_8x12_Leaf = true, Wall_8x12 = true } })
		for _, item in plan.items do
			Assert.truthy(item.role ~= "wall", "no walls without Wall_8x12")
			Assert.truthy(item.pieces[1] ~= "Wall_Door_8x12_Leaf", "avoided leaf")
		end
		Assert.eq(next(plan.solids) ~= nil, true, "counters still dressed")
	end)

	-- Levels and world feedback track: the warm pass on L3, L4 and L6, L6's lamp row, lobby, cables and alley,
	-- the soft pools, the hide plates.
	local function byId(id: string): any
		for _, spec in Catalog do
			if spec.id == id then
				return LevelSpec.compile(spec)
			end
		end
		error("no level " .. id)
	end

	local function viewBudget(lamps: { any }): (number, number)
		local worstLit, worstShadow = 0, 0
		for _, a in lamps do
			local lit, shadowed = 0, 0
			for _, b in lamps do
				local dx, dz = a.x - b.x, a.z - b.z
				if dx * dx + dz * dz <= LIGHT.VIEW_RADIUS * LIGHT.VIEW_RADIUS then
					lit += 1
					if LIGHT.LAMP[b.kind].shadows then
						shadowed += 1
					end
				end
			end
			worstLit, worstShadow = math.max(worstLit, lit), math.max(worstShadow, shadowed)
		end
		return worstLit, worstShadow
	end

	test("light budget: L3, L4 and L6 after the warm pass (street lamps, rooms, accents)", function()
		local want = {
			cs3_lights_out = {
				{ 10, -8, "plate" },
				{ 12, -26, "plate" },
				{ 0, -40, "hero" },
				{ -8, -2, "room" },
				{ -4, -27, "room" },
				{ -12.5, 12.5, "street" },
				{ 12.5, 12.5, "street" },
			},
			cs4_night_clerk = {
				{ 10, -8, "plate" },
				{ -12, -23, "plate" },
				{ 0, -42, "hero" },
				{ -8, -2, "room" },
				{ 13, -30, "room" },
				{ -12.5, 12.5, "street" },
				{ 12.5, 12.5, "street" },
			},
			bk1_big_score = {
				{ -12, -10, "plate" },
				{ -16, -18, "plate" },
				{ -13, -42, "plate" },
				{ 13, -42, "plate" },
				{ 0, -55, "hero" },
				{ 0, -6, "room" },
				{ 0, -24, "room" },
				{ -6, -39, "room" },
				{ 6, -39, "room" },
				{ 12, -54, "accent" },
				{ -15, 12.5, "street" },
				{ 15, 12.5, "street" },
				{ -12, -71, "street" },
				{ 12, -71, "street" },
			},
		}
		for id, list in want do
			local level = byId(id)
			local lamps = KitPlan.lamps(level, LevelDress[id], LIGHT)
			for _, w in list do
				local found = false
				for _, l in lamps do
					found = found or (math.abs(l.x - w[1]) < 1e-6 and math.abs(l.z - w[2]) < 1e-6 and l.kind == w[3])
				end
				Assert.truthy(found, string.format("%s: %s lamp at (%g, %g)", id, w[3], w[1], w[2]))
			end
			local lit, shadowed = viewBudget(lamps)
			Assert.le(lit, LIGHT.MAX_LIGHTS_PER_VIEW, id .. ": lights in one view (" .. lit .. ")")
			Assert.le(shadowed, LIGHT.MAX_SHADOWED_PER_VIEW, id .. ": shadowed lights in one view")
			-- the accents keep their warm gold (never the Bank's green), the room lamps take the location colour
			local looks = KitPlan.lampLooks(lamps, KitPlan.location(level, true), LIGHT)
			for k, l in lamps do
				if l.kind == "accent" then
					Assert.eq(looks[k].color, LIGHT.LAMP.accent.color, id .. ": accent keeps its gold")
					Assert.truthy(not LIGHT.LAMP.accent.shadows, id .. ": accents never shadow")
				end
			end
		end
	end)

	test("daily vaults: the readability bar (room lamps, a lamp and a letter per plate, budget)", function()
		for _, spec in DailyVaults.designs do
			local level = LevelSpec.compile(spec)
			local lamps = KitPlan.lamps(level, LevelDress[level.id], LIGHT)
			local rooms, plates = 0, 0
			for _, l in lamps do
				rooms += if l.kind == "room" then 1 else 0
				plates += if l.kind == "plate" then 1 else 0
			end
			Assert.truthy(rooms >= 1, level.id .. ": at least one room lamp")
			Assert.eq(plates, #level.plates, level.id .. ": a lamp over every plate")
			for i in level.plates do
				Assert.truthy(string.match(KitPlan.letter(level, i), "^%u$") ~= nil, level.id .. ": plate letter")
			end
			for _, d in level.doors do
				if #d.openBy > 0 and d.openBy[1].kind == "plate" then
					Assert.truthy(
						KitPlan.deviceLetters(level, d.openBy) ~= "",
						level.id .. ": door " .. d.id .. " lettered"
					)
				end
			end
			local lit, shadowed = viewBudget(lamps)
			Assert.le(lit, LIGHT.MAX_LIGHTS_PER_VIEW, level.id .. ": lights in one view")
			Assert.le(shadowed, LIGHT.MAX_SHADOWED_PER_VIEW, level.id .. ": shadowed lights in one view")
		end
	end)

	test("L6 vault row: A-D left to right from the scale room, on the frame's face, clear of the door lamp", function()
		local level = byId("bk1_big_score")
		local rows = KitPlan.vaultRows(level, LIGHT)
		Assert.eq(#rows, 1, "one need-all door")
		local row = rows[1]
		Assert.eq(level.doors[row.door].id, "VaultDoor", "the vault door")
		Assert.eq(#row.lamps, 4, "four lamps")
		Assert.truthy(row.nz == 1 and row.nx == 0, "on the scale-room (+Z) face, toward the plates")
		local letters = ""
		local lastX = -math.huge
		for _, l in row.lamps do
			letters ..= l.letter
			Assert.truthy(l.x > lastX, "left to right as you face the vault")
			lastX = l.x
			Assert.near(l.y, LIGHT.VAULT_ROW.y, 1e-6, "row height")
			Assert.truthy(l.y + LIGHT.VAULT_ROW.size / 2 < 12, "under the wall top (nothing pokes above the cut-away)")
			Assert.truthy(l.y - LIGHT.VAULT_ROW.size / 2 > 10, "over the door opening")
			Assert.truthy(math.abs(l.x) >= 0.4 + LIGHT.VAULT_ROW.size / 2, "clear of the door lamp in the middle")
			Assert.truthy(math.abs(l.x) <= 8, "inside the vault frame's width")
			Assert.truthy(l.z > -47.5 and l.z < -46.5, "proud of the vault wall's scale-room face")
		end
		Assert.eq(letters, "ABCD", "lettered A-D")
		-- every need-all daily door gets a row, an odd row clears the middle too
		for _, spec in DailyVaults.designs do
			local lv = LevelSpec.compile(spec)
			for _, r in KitPlan.vaultRows(lv, LIGHT) do
				local d = lv.doors[r.door]
				Assert.eq(d.need, "all", lv.id .. ": rows only on need-all doors")
				Assert.eq(#r.lamps, #d.openBy, lv.id .. ": a lamp per plate")
				local cx = (d.box.minX + d.box.maxX) / 2
				for _, l in r.lamps do
					Assert.truthy(
						math.abs(l.x - cx) >= 0.4 + LIGHT.VAULT_ROW.size / 2,
						lv.id .. ": clear of the door lamp"
					)
				end
			end
		end
	end)

	test("L6 lobby: teller counters on the sim counters; shops keep their counters", function()
		local level = byId("bk1_big_score")
		local plan = KitPlan.plan(level, specs, { location = "Bank", dressing = true })
		local tellers = 0
		for _, item in plan.items do
			if item.role == "counter" then
				Assert.eq(item.pieces[1], "TellerCounter_8x4", "L6 counters are teller counters")
				tellers += 1
				local b = KitPlan.itemBox(item, specs)
				Assert.truthy(
					b.minZ >= -6.15 and b.maxZ <= -3.85,
					"inside the sim counter's depth (trim 0.15): " .. boxText(b)
				)
				Assert.truthy(b.maxY <= 8, "screen under 8 studs")
				for _, def in level.loot do
					local onTop = def.x > b.minX and def.x < b.maxX and def.z > b.minZ and def.z < b.maxZ
					Assert.falsy(onTop, "no loot on a teller counter (its glass screen)")
				end
			end
		end
		Assert.eq(tellers, 4, "two 8-stud modules either side of the gate")
		for _, id in { "cs1_back_room", "cs3_lights_out", "cs4_night_clerk" } do
			local lv = byId(id)
			for _, item in KitPlan.plan(lv, specs, { dressing = true }).items do
				Assert.truthy(item.pieces[1] ~= "TellerCounter_8x4", id .. ": no teller counter in a shop")
			end
		end
	end)

	test("L6 cables: B to the grid's west post, vault trunks C B A D west to east, no two cables touch", function()
		local level = byId("bk1_big_score")
		local cables = KitPlan.cables(level, LIGHT)
		local function segs(cb: any): { any }
			local out = {}
			for k = 1, #cb.points - 1 do
				table.insert(out, { cb.points[k], cb.points[k + 1] })
			end
			return out
		end
		local function gap(s1: any, s2: any): number
			local ax0, ax1 = math.min(s1[1][1], s1[2][1]), math.max(s1[1][1], s1[2][1])
			local az0, az1 = math.min(s1[1][2], s1[2][2]), math.max(s1[1][2], s1[2][2])
			local bx0, bx1 = math.min(s2[1][1], s2[2][1]), math.max(s2[1][1], s2[2][1])
			local bz0, bz1 = math.min(s2[1][2], s2[2][2]), math.max(s2[1][2], s2[2][2])
			local dx = math.max(0, bx0 - ax1, ax0 - bx1)
			local dz = math.max(0, bz0 - az1, az0 - bz1)
			return math.sqrt(dx * dx + dz * dz)
		end
		local trunkX: { [string]: number } = {}
		local laserEnd = nil
		for _, cb in cables do
			local last = cb.points[#cb.points]
			local letter = KitPlan.letter(level, cb.plate)
			if math.abs(last[2] - -47) < 1e-6 then
				trunkX[letter] = last[1]
			elseif math.abs(last[2] - -31.5) < 1e-6 then
				laserEnd = { letter, last[1] }
			end
		end
		Assert.truthy(laserEnd ~= nil and laserEnd[1] == "B" and laserEnd[2] == -19, "B ends at the grid's west post")
		Assert.truthy(
			trunkX.C < trunkX.B and trunkX.B < trunkX.A and trunkX.A < trunkX.D,
			"vault trunks west to east: C, B, A, D"
		)
		for i, c1 in cables do
			for j, c2 in cables do
				if j > i and c1.plate ~= c2.plate then
					for _, s1 in segs(c1) do
						for _, s2 in segs(c2) do
							Assert.truthy(
								gap(s1, s2) >= LIGHT.CABLE_WIDTH - 1e-6,
								string.format("plates %d and %d: cables never cross or touch", c1.plate, c2.plate)
							)
						end
					end
				end
			end
		end
	end)

	test("L6 alley: outside the building (no kit floor, snow falls), the shops unchanged", function()
		local BackdropPlan = require("../../src/shared/Heist/BackdropPlan")
		for _, level in levels() do
			local b = KitPlan.buildingBox(level)
			local site = BackdropPlan.levelSite(level)
			if b and site.footprint then
				local f = site.footprint :: any
				Assert.truthy(
					math.abs(f.minX - b.minX) < 1e-6
						and math.abs(f.maxX - b.maxX) < 1e-6
						and math.abs(f.minZ - b.minZ) < 1e-6
						and math.abs(f.maxZ - b.maxZ) < 1e-6,
					level.id .. ": BackdropPlan's footprint is KitPlan's building"
				)
			end
		end
		local l6 = byId("bk1_big_score")
		local b = KitPlan.buildingBox(l6) :: any
		Assert.truthy(b.minX > -21 and b.maxX < 21 and b.minZ > -61, "L6 building: the bank, not the fenced lot")
		local plan = KitPlan.plan(l6, specs, { location = "Bank", dressing = true })
		for _, item in plan.items do
			if item.role == "floor" then
				local fb = KitPlan.itemBox(item, specs)
				Assert.truthy(fb.minX >= b.minX - 1e-3 and fb.maxX <= b.maxX + 1e-3, "no kit floor in the side alleys")
				Assert.truthy(fb.minZ >= b.minZ - 1e-3, "no kit floor in the service alley")
			end
		end
		local l1 = byId("cs1_back_room")
		local b1 = KitPlan.buildingBox(l1) :: any
		Assert.truthy(b1.minX < -16 and b1.maxX > 16 and b1.maxZ > 10, "L1 building: the whole shop")
	end)

	test("soft pools: a smooth falloff with each kind's old brightness (x gain)", function()
		local soft = LIGHT.POOL_SOFT
		for kind, spec in LIGHT.LAMP do
			local stepped = spec.poolRings or LIGHT.POOL.rings
			local rings = KitPlan.poolRings(stepped, soft)
			Assert.eq(#rings, soft.rings, kind .. ": ring count")
			-- stacked opacity at each band's middle follows peak * (1 - u^2)^exponent
			local peak = KitPlan.poolPeak(stepped, soft)
			Assert.truthy(peak > 0.3 and peak <= soft.peakMax, kind .. ": peak " .. peak)
			local through = 1
			local last = -1
			for k, r in rings do
				through *= r.alpha
				local inner = if rings[k + 1] then rings[k + 1].size else 0
				local u = (r.size + inner) / 2
				local want = peak * (1 - u * u) ^ soft.exponent
				Assert.near(1 - through, want, 1e-3, kind .. ": opacity at u " .. u)
				Assert.truthy(1 - through >= last - 1e-9, kind .. ": brighter toward the centre")
				last = 1 - through
				Assert.truthy(r.alpha >= 0 and r.alpha <= 1, kind .. ": a valid transparency")
			end
			Assert.truthy(1 - rings[1].alpha < 0.12, kind .. ": the outermost disc is faint (no hard rim)")
			-- the area-weighted brightness matches the old discs (unless capped)
			local function mean(list: { any }): number
				local sorted = table.clone(list)
				table.sort(sorted, function(a: any, b: any): boolean
					return a.size > b.size
				end)
				local m, t = 0, 1
				for k, r in sorted do
					t *= r.alpha
					local inner = if sorted[k + 1] then sorted[k + 1].size else 0
					m += (1 - t) * (r.size * r.size - inner * inner)
				end
				return m
			end
			if peak < soft.peakMax - 1e-6 then
				Assert.near(
					mean(rings),
					mean(stepped) * (soft.gain or 1),
					0.03,
					kind .. ": the old mean brightness x gain"
				)
			end
		end
	end)

	test(
		"pool rects: no pool crosses a wall (street pools stop at the shop front, the vault's at its walls)",
		function()
			local cut = 0
			for _, level in levels() do
				local walls = {}
				for _, sd in level.spec.solids or {} do
					local bx = sd.box
					if bx.maxY - bx.minY >= 8 and math.min(bx.maxX - bx.minX, bx.maxZ - bx.minZ) <= 1.5 then
						table.insert(walls, bx)
					end
				end
				for _, l in KitPlan.lamps(level, LevelDress[level.id], LIGHT) do
					local spec = LIGHT.LAMP[l.kind]
					local d = spec.pool or (if l.kind == "hero" then LIGHT.POOL.heroDiameter else LIGHT.POOL.diameter)
					local r = KitPlan.poolRect(level, l.x, l.z, d)
					local what = string.format("%s: %s pool at (%g, %g)", level.id, l.kind, l.x, l.z)
					Assert.truthy(
						r.minX <= l.x and r.maxX >= l.x and r.minZ <= l.z and r.maxZ >= l.z,
						what .. ": lamp inside"
					)
					Assert.truthy(r.maxX - r.minX <= d + 1e-9 and r.maxZ - r.minZ <= d + 1e-9, what .. ": never bigger")
					cut += if r.maxX - r.minX < d - 1e-9 or r.maxZ - r.minZ < d - 1e-9 then 1 else 0
					for _, bx in walls do
						-- a wall line strictly inside the rect would mean light on both sides of it
						local alongX = bx.maxX - bx.minX >= bx.maxZ - bx.minZ
						local line = if alongX then (bx.minZ + bx.maxZ) / 2 else (bx.minX + bx.maxX) / 2
						local crosses = if alongX
							then line > r.minZ + 1e-6 and line < r.maxZ - 1e-6 and bx.maxX > r.minX and bx.minX < r.maxX
							else line > r.minX + 1e-6 and line < r.maxX - 1e-6 and bx.maxZ > r.minZ and bx.minZ < r.maxZ
						Assert.falsy(crosses, what .. " crosses the wall " .. boxText(bx))
					end
				end
			end
			Assert.truthy(cut >= 16, "the street pools (and more) are cut (" .. cut .. ")")
		end
	)

	test("hide plates: L4's B under the coat rack, L6's A-D under the desk, fern and stacks", function()
		local function letters(id: string): { [string]: string }
			local out = {}
			local level = byId(id)
			for _, hp in KitPlan.hidePlates(level) do
				out[level.hides[hp.hide].id] = hp.letters
			end
			return out
		end
		local l4 = letters("cs4_night_clerk")
		Assert.eq(l4.CoatRack, "B", "L4: B under the coat rack")
		Assert.eq(l4.Crate, nil, "L4: no plate in the crate")
		local l6 = letters("bk1_big_score")
		Assert.eq(l6.TellerDesk, "A", "L6: A at the teller desk")
		Assert.eq(l6.Fern, "B", "L6: B under the fern")
		Assert.eq(l6.WestStack, "C", "L6: C under the west stack")
		Assert.eq(l6.EastStack, "D", "L6: D under the east stack")
	end)
end
