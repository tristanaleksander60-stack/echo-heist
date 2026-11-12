-- L1: Heist/KitPlan, where the art kit goes on a level (docs/art/KIT_IMPORT.md). The kit is the
-- look, never the collision: these specs check the placement maths and, on every launch level
-- and daily vault, that wall pieces stay inside their sim walls, door leaves are exactly the
-- door boxes, nothing covers a doorway, and the Christmas layer appears only when asked for.

local KitPlan = require("../../src/server/Heist/KitPlan")
local KitData = require("../../src/server/Kit/KitData")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Catalog = require("../../src/shared/Levels/Catalog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local Assert = require("./Assert")

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
				local plan = KitPlan.plan(level, specs, { dressing = dressing, location = location(level) })
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

	test("missing or avoided pieces fall back (nothing planned for them)", function()
		local level = LevelSpec.compile(Catalog[1])
		local plan = KitPlan.plan(level, specs, { avoid = { Wall_Door_8x12_Leaf = true, Wall_8x12 = true } })
		for _, item in plan.items do
			Assert.truthy(item.role ~= "wall", "no walls without Wall_8x12")
			Assert.truthy(item.pieces[1] ~= "Wall_Door_8x12_Leaf", "avoided leaf")
		end
		Assert.eq(next(plan.solids) ~= nil, true, "counters still dressed")
	end)
end
