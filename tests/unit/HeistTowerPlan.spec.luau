-- L1: Heist/TowerPlan, the BIG buildings (PLAN_FIRST_PERSON §5 "BIG", Config.Big). On every launch level and daily
-- vault: a 3-5 storey shell over the playable ground floor, a ceiling over every room (a first-person "look up" from
-- a grid over the whole footprint meets a ceiling at the wall tops, never the sky), nothing in the playable storey
-- (every planned piece is at or over the wall tops, or outside the outer faces), each location its own building,
-- the cut-away groups cover what they hold, the budget at tier 1 and a cheaper tier 3, and no Light.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Assert = require("./Assert")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Strings = require("../../src/shared/Heist/Strings")
local TowerPlan = require("../../src/server/Heist/TowerPlan")

local BIG = Config.Big
local specs: { [string]: any } = (KitData :: any).parts
local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json"))
local kitTris: { [string]: number } = {}
for name, e in manifest.parts do
	kitTris[name] = e.tris
end
local deps = { cfg = BIG, KP = KitPlan, signs = Strings.BIG_SIGN }

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

local function planFor(level: any, withKit: boolean): any
	return TowerPlan.plan(level, if withKit then specs else nil, { dressing = true }, deps)
end

-- every planned piece's world AABB (kit items through KitPlan.partFrame)
local function boxes(plan: any): { any }
	local out = {}
	for _, p in plan.parts do
		local s, c = p.size, p.pos
		local sx, sz = s[1], s[3]
		if math.abs((p.yaw or 0) % 180 - 90) < 1e-6 then
			sx, sz = sz, sx
		end
		table.insert(out, {
			name = p.name,
			group = p.group,
			minX = c[1] - sx / 2,
			maxX = c[1] + sx / 2,
			minY = c[2] - s[2] / 2,
			maxY = c[2] + s[2] / 2,
			minZ = c[3] - sz / 2,
			maxZ = c[3] + sz / 2,
		})
	end
	for _, it in plan.items do
		local b = KitPlan.itemBox(it, specs)
		b.name = it.pieces[1]
		b.group = it.group
		table.insert(out, b)
	end
	return out
end

return function(test: (string, () -> ()) -> ())
	local all = levels()

	test("every level gets a 3-5 storey building over its ground floor, the location's style", function()
		for _, level in all do
			local plan = planFor(level, true)
			Assert.truthy(plan ~= nil, level.id .. ": a building")
			Assert.truthy(plan.storeys >= 3 and plan.storeys <= 5, level.id .. ": 3-5 storeys")
			Assert.truthy(plan.topY - plan.floorY >= 12 + 3 * BIG.STOREY, level.id .. ": tall")
			local loc = KitPlan.location(level, true)
			Assert.eq(plan.style, loc, level.id .. ": the location's style")
			Assert.truthy(plan.windows >= 40, level.id .. ": windows on every storey (" .. plan.windows .. ")")
			local share = plan.lit / plan.windows
			Assert.truthy(share > 0.3 and share < 0.85, level.id .. ": some lit, some dark (" .. share .. ")")
		end
	end)

	test(
		"first person never sees sky indoors: a ceiling over every point of the footprint, at the wall tops",
		function()
			for _, level in all do
				for _, withKit in { true, false } do
					local plan = planFor(level, withKit)
					local bb = KitPlan.buildingBox(level)
					local misses = 0
					local x = bb.minX + 1
					while x < bb.maxX - 1 do
						local z = bb.minZ + 1
						while z < bb.maxZ - 1 do
							local under = TowerPlan.ceilingOver(plan, x, z)
							if under == nil or math.abs(under - (level.floorY + BIG.CEIL_Y)) > 1e-6 then
								misses += 1
							end
							z += 2
						end
						x += 2
					end
					Assert.eq(
						misses,
						0,
						level.id .. (if withKit then " (kit)" else " (greybox)") .. ": points without a ceiling"
					)
					-- and the pieces really cover it: the ceiling tiles (or the fallback slab) span the walls' lines
					local covered = 0
					local area = (bb.maxX - bb.minX - 1) * (bb.maxZ - bb.minZ - 1)
					for _, b in boxes(plan) do
						if b.group == "ceiling" and b.name ~= "CeilingLid" and b.name ~= "CeilingFlat" then
							Assert.near(
								b.minY,
								level.floorY + BIG.CEIL_Y,
								1e-3,
								level.id .. ": the ceiling's underside"
							)
							covered += (b.maxX - b.minX) * (b.maxZ - b.minZ)
						end
					end
					Assert.near(covered, area, 0.5, level.id .. ": the ceiling's area = the rooms' area")
				end
			end
		end
	)

	test("the playable storey is untouched: every piece is over the wall tops or outside the outer faces", function()
		for _, level in all do
			local plan = planFor(level, true)
			local bb = KitPlan.buildingBox(level)
			local o = plan.outer
			for _, b in boxes(plan) do
				local above = b.minY >= level.floorY + BIG.CEIL_Y - 1e-3
				local outside = b.minX >= o.maxX - 1e-3
					or b.maxX <= o.minX + 1e-3
					or b.minZ >= o.maxZ - 1e-3
					or b.maxZ <= o.minZ + 1e-3
				Assert.truthy(above or outside, level.id .. ": " .. b.name .. " reaches into the playable storey")
				-- nothing hangs into the street front's storey either (doors, the van, the spawn)
				Assert.truthy(b.minY >= level.floorY + BIG.CEIL_Y - 1.5, level.id .. ": " .. b.name .. " too low")
				-- the lot: inside the level's bounds' X range, and never past the street's kerb side of the van
				Assert.truthy(b.maxZ <= bb.maxZ + 6, level.id .. ": " .. b.name .. " out over the street")
			end
		end
	end)

	test("each location its own building: tenement, department store, bank", function()
		local seen: { [string]: any } = {}
		for _, level in all do
			local plan = planFor(level, true)
			seen[plan.style] = plan
		end
		local function count(plan: any, piece: string): number
			local n = 0
			for _, it in plan.items do
				if it.pieces[1] == piece then
					n += 1
				end
			end
			return n
		end
		local function partNamed(plan: any, name: string): any
			for _, p in plan.parts do
				if p.name == name then
					return p
				end
			end
			return nil
		end
		Assert.truthy(seen.CornerShop and seen.ToyShop and seen.Bank, "all three styles appear")
		Assert.truthy(count(seen.CornerShop, "FireEscape_8x10") >= 4, "the tenement's fire escapes")
		Assert.truthy(count(seen.CornerShop, "Roof_WaterTank") == 1, "the tenement's water tank")
		Assert.truthy(partNamed(seen.CornerShop, "SignBlade") ~= nil, "the corner shop's blade sign")
		Assert.truthy(count(seen.ToyShop, "ToySoldier") == 1, "the giant toy soldier on the store's roof")
		local board = partNamed(seen.ToyShop, "SignBoard")
		Assert.truthy(board ~= nil and board.sign and board.sign.text == Strings.BIG_SIGN.ToyShop, "the big lit sign")
		Assert.truthy(count(seen.Bank, "Column_2x12") >= 4, "the bank's columns")
		Assert.truthy(count(seen.Bank, "Pediment_24") == 1 and count(seen.Bank, "Clock_6") == 1, "pediment and clock")
		-- the bank's body is stone, the tenement's brick (different body colours)
		local function bodyOf(plan: any): string
			for _, it in plan.items do
				if it.color then
					return table.concat(it.color, ",")
				end
			end
			return ""
		end
		Assert.truthy(bodyOf(seen.Bank) ~= bodyOf(seen.CornerShop), "stone vs brick")
	end)

	test("cut-away groups: every piece in a group, inside its box; faces carry their outward normal", function()
		for _, level in all do
			local plan = planFor(level, true)
			local groups: { [string]: any } = {}
			for _, g in plan.groups do
				groups[g.name] = g
			end
			for _, name in { "ceiling", "roof", "front", "back", "left", "right" } do
				Assert.truthy(groups[name] ~= nil, level.id .. ": group " .. name)
			end
			Assert.eq(groups.front.normal[2], 1, "front faces +Z (the street)")
			Assert.eq(groups.back.normal[2], -1, "back faces -Z")
			Assert.eq(groups.left.normal[1], -1, "left faces -X")
			Assert.eq(groups.right.normal[1], 1, "right faces +X")
			for _, b in boxes(plan) do
				local g = groups[b.group]
				Assert.truthy(g ~= nil, level.id .. ": " .. b.name .. " has a group")
				local gb = g.box
				local tol = 0.6
				Assert.truthy(
					b.minX >= gb.minX - tol
						and b.maxX <= gb.maxX + tol
						and b.minY >= gb.minY - tol
						and b.maxY <= gb.maxY + tol
						and b.minZ >= gb.minZ - tol
						and b.maxZ <= gb.maxZ + tol,
					level.id .. ": " .. b.name .. " inside its group " .. b.group
				)
			end
		end
	end)

	test("budget per building at tier 1, cheaper from the detail tier; no lights", function()
		local B = BIG.BUDGET
		for _, level in all do
			local plan = planFor(level, true)
			local draws, tris, instances = TowerPlan.budget(plan, 1, kitTris, BIG)
			Assert.le(instances, B.instances, level.id .. ": instances")
			Assert.le(draws, B.draws, level.id .. ": draws")
			Assert.le(tris, B.tris, level.id .. ": triangles")
			local d3, t3 = TowerPlan.budget(plan, BIG.DETAIL_OFF_TIER, kitTris, BIG)
			Assert.truthy(
				d3 < draws and t3 < tris * 0.75,
				level.id .. ": cheaper at tier 3 (" .. t3 .. " / " .. tris .. ")"
			)
			Assert.eq(B.lights, 0, "the buildings carry no Light (glow is Neon panes)")
		end
	end)

	test("the plan is deterministic and the greybox fallback has the same shell", function()
		for _, level in all do
			local a, b = planFor(level, true), planFor(level, true)
			Assert.eq(#a.items, #b.items, level.id .. ": same items")
			Assert.eq(a.lit, b.lit, level.id .. ": same lit windows")
			local g = planFor(level, false)
			Assert.eq(#g.items, 0, level.id .. ": no kit items without the kit")
			Assert.eq(g.topY, a.topY, level.id .. ": same height")
		end
	end)

	test("phone budget: the street front's window trims are the tier 4 layer; tier 4 sheds them", function()
		for _, level in levels() do
			local plan = planFor(level, true)
			if not plan then
				continue
			end
			local trims = 0
			for _, it in plan.items do
				if it.role == "trim" then
					Assert.eq(it.layer, if it.group == "front" then "trim" else "detail", level.id .. " " .. it.group)
					trims += if it.group == "front" then 1 else 0
				end
			end
			local _, t3 = TowerPlan.budget(plan, 3, kitTris, BIG)
			local _, t4 = TowerPlan.budget(plan, 4, kitTris, BIG)
			if trims > 0 then
				Assert.truthy(t4 < t3, level.id .. ": tier 4 sheds the front's trims")
			end
			Assert.truthy(TowerPlan.layerOn("trim", 3, BIG) and not TowerPlan.layerOn("trim", 4, BIG), "trim to tier 3")
		end
	end)
end
