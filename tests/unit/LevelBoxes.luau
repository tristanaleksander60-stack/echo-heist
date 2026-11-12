-- Test helper (not a spec): the boxes a camera ray can hit in a launch level, as the server
-- builds it (Heist/LevelBuilder greybox + Heist/KitPlan kit pieces with the Christmas layer and
-- the lamps, the same inputs tools/blender/level_plan.luau uses). Level space. Kit pieces are
-- taken as their axis-aligned bounds, so a lane that clears them clears the real meshes.
--   LevelBoxes.of(level, dressing?) -> { { box = Box, name = string, role = string?, ref = string?, index = number? } }
--   LevelBoxes.blocked(boxes, from, to, skip?) -> the first box name the segment enters, or nil

local Config = require("../../src/shared/Config")
local LevelDress = require("../../src/server/Heist/LevelDress")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local CameraMath = require("../../src/client/Heist/CameraMath")

local LevelBoxes = {}

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): any
	return { minX = minX, minY = minY, minZ = minZ, maxX = maxX, maxY = maxY, maxZ = maxZ }
end

function LevelBoxes.of(level: any, dressing: boolean?): { any }
	local out = {}
	for i, s in level.solids do
		table.insert(out, { box = s, name = "solid " .. i, role = "solid", index = i })
	end
	for i, d in level.doors do
		table.insert(out, { box = d.box, name = "door " .. tostring(d.id), role = "door", index = i })
	end
	-- LevelBuilder's greybox van body (zone width + 1, 7 tall, 8 deep, behind the zone).
	local v = level.van
	local cx, cz = (v.minX + v.maxX) / 2, v.maxZ + 4.5
	local hx = (v.maxX - v.minX + 1) / 2
	table.insert(out, {
		box = box(cx - hx, level.floorY + 0.5, cz - 4, cx + hx, level.floorY + 7.5, cz + 4),
		name = "VanBody",
		role = "van",
	})
	local location = level.spec and level.spec.location or "CornerShop"
	if dressing and level.kind == "party" and location == "CornerShop" then
		location = "ToyShop"
	end
	local specs = (KitData :: any).parts
	local plan = KitPlan.plan(level, specs, {
		dressing = dressing == true,
		location = location,
		dress = LevelDress[level.id],
		lighting = Config.Lighting,
		floor = true,
	})
	for _, item in plan.items do
		if item.role ~= "floor" then
			table.insert(out, {
				box = KitPlan.itemBox(item, specs),
				name = item.role .. ":" .. table.concat(item.pieces, "+"),
				role = item.role,
				ref = item.ref,
				index = item.index,
			})
		end
	end
	return out
end

-- The first box (by entry distance) the segment from -> to enters, skipping entries for which
-- skip(entry) is true. Returns its name, or nil when the lane is clear.
function LevelBoxes.blocked(boxes: { any }, from: { number }, to: { number }, skip: ((any) -> boolean)?): string?
	local best, bestT = nil, math.huge
	for _, e in boxes do
		if not (skip and skip(e)) then
			local t = CameraMath.rayBox(from, to, e.box)
			if t and t < bestT then
				best, bestT = e.name, t
			end
		end
	end
	return best
end

return LevelBoxes
