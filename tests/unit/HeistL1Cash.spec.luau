-- L1's cash shows through the right partition window from every spawn seat (MASTERPLAN §7.5 "cash
-- glittering through glass"; LEVELS.md §9: at (0, -28) the shut back-room door hid it). Geometry only:
-- the plan KitPlan builds (Heist/LevelDress: the windows on the z -20 partition, the Safe under the cash),
-- the sim's solids, and sight lines from first-person eyes to points on the cash bag. A line may cross a
-- partition wall only through a window's glass; every other solid blocks it. The engine check of the
-- same view (and of the first clone) is tests/clone_engine.luau section FP.

local Assert = require("./Assert")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LevelDress = require("../../src/server/Heist/LevelDress")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Validator = require("../../src/shared/Rec/Validator")

local specs: { [string]: any } = (KitData :: any).parts

-- First-person eye heights above the floor: the Rookie's (~3.8, PROJECT_STATE "the Rookie") and a
-- taller margin; the camera's 6-degree start pitch keeps both in frame.
local EYES = { 3.8, 4.6 }
local MIN_SHARE = 0.3 -- of the bag's sample points in sight from each seat

local function l1(): any
	for _, spec in Catalog do
		if spec.id == "cs1_back_room" then
			return LevelSpec.compile(spec)
		end
	end
	error("no L1")
end

local function glassOf(item: any): any?
	for _, name in item.pieces do
		if name == "Wall_Window_8x12_Glass" then
			return KitPlan.itemBox({ pieces = { name }, pivot = item.pivot, scale = item.scale }, specs)
		end
	end
	return nil
end

return function(test)
	local level = l1()
	local plan = KitPlan.plan(level, specs, {
		location = level.spec.location,
		dress = LevelDress[level.id],
		lighting = Config.Lighting,
	})
	local glass, bag, display = {}, nil, nil
	for _, item in plan.items do
		local g = glassOf(item)
		if g then
			table.insert(glass, g)
		elseif item.role == "loot" and item.ref == "loot" and level.loot[item.index].id == "Cash" then
			bag = KitPlan.itemBox(item, specs)
		elseif item.role == "display" then
			display = item
		end
	end

	-- Does the segment eye -> p get through? Partition walls only through a pane's glass (both faces).
	local function seen(ex: number, ey: number, ez: number, px: number, py: number, pz: number): boolean
		for _, b in level.solids do
			if Validator.segmentHitsBox(b, ex, ey, ez, px, py, pz) then
				local through = false
				for _, g in glass do
					local ok = true
					for _, z in { b.minZ, b.maxZ } do
						local u = (z - ez) / (pz - ez)
						local x, y = ex + (px - ex) * u, ey + (py - ey) * u
						ok = ok and x > g.minX and x < g.maxX and y > g.minY and y < g.maxY
					end
					through = through or ok
				end
				if not through then
					return false
				end
			end
		end
		for _, d in level.doors do -- shut at the spawn
			if Validator.segmentHitsBox(d.box, ex, ey, ez, px, py, pz) then
				return false
			end
		end
		return true
	end

	test("L1: the cash sits on a Safe behind the right partition window, off the door's axis", function()
		Assert.truthy(bag ~= nil, "the cash bag is planned")
		Assert.truthy(display ~= nil and display.pieces[1] == "Safe", "the cash's display is a Safe")
		Assert.eq(#glass, 2, "two panes on the z -20 partition")
		local cash = level.loot[1]
		Assert.truthy(math.abs(cash.x) > 6, "off the back-room door's axis (the door spans x -3..3)")
		local b = bag :: any
		local d = KitPlan.itemBox(display :: any, specs)
		Assert.near(b.minY, d.maxY, 0.05, "the cash sits on the safe")
	end)

	test("L1: the cash shows through the glass from every spawn seat at first-person eye height", function()
		local b = bag :: any
		local floorY = level.floorY or 0
		for s, sp in level.spawns do
			for _, eye in EYES do
				local ey = floorY + eye
				local n, hit = 0, 0
				for i = 0, 4 do
					for j = 0, 4 do
						local px = b.minX + (b.maxX - b.minX) * (0.1 + 0.2 * i)
						local py = b.minY + (b.maxY - b.minY) * (0.1 + 0.2 * j)
						local pz = b.maxZ -- the face toward the street
						n += 1
						if seen(sp.x, ey, sp.z, px, py, pz) then
							hit += 1
						end
					end
				end
				Assert.truthy(
					hit / n >= MIN_SHARE,
					string.format("seat %d, eye %.1f: %d of %d points of the cash in sight", s, eye, hit, n)
				)
			end
		end
	end)
end
