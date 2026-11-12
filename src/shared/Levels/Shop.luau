--!strict
-- Levels/Shop: geometry helpers shared by the Corner Shop teaching levels (sim
-- data only; the kit layout replaces this once assets/Kit.rbxm lands, spike S2).
-- Floor at y = 0, walls 12 studs tall and 1 stud thick, actors' roots at y = 3.
-- The shop faces +Z: the street and the van are at z > 10, rooms go toward -Z.

local LevelSpec = require("../Sim/LevelSpec")

local Shop = {}

Shop.WALL_H = 12
Shop.ROOT_Y = 3

-- A wall along X at z, from x0 to x1.
function Shop.wallZ(z: number, x0: number, x1: number, sight: boolean?): any
	return { box = LevelSpec.span(x0, 0, z - 0.5, x1, Shop.WALL_H, z + 0.5), sight = sight }
end

-- A wall along Z at x, from z0 to z1.
function Shop.wallX(x: number, z0: number, z1: number): any
	return { box = LevelSpec.span(x - 0.5, 0, z0, x + 0.5, Shop.WALL_H, z1) }
end

-- A wall along X at z from x0 to x1 with a doorway gap [g0, g1]; adds both pieces.
function Shop.wallZGap(list: { any }, z: number, x0: number, x1: number, g0: number, g1: number)
	table.insert(list, Shop.wallZ(z, x0, g0))
	table.insert(list, Shop.wallZ(z, g1, x1))
end

-- A door leaf filling the gap [g0, g1] of a wall at z (solid only when shut).
function Shop.doorAt(z: number, g0: number, g1: number): any
	return LevelSpec.span(g0, 0, z - 0.5, g1, 10, z + 0.5)
end

-- A plate trigger volume: 4x4 footprint centred at (x, z), tall enough for a root at y 3.
function Shop.plate(x: number, z: number): any
	return LevelSpec.span(x - 2, 0, z - 2, x + 2, 6, z + 2)
end

-- The shop shell: street front at z = 10 with an entrance (x -4..4), side walls at
-- x = +-16 down to the back wall at zBack.
function Shop.shell(zBack: number): { any }
	local solids = {}
	Shop.wallZGap(solids, 10, -16.5, 16.5, -4, 4)
	table.insert(solids, Shop.wallX(-16, zBack, 10))
	table.insert(solids, Shop.wallX(16, zBack, 10))
	table.insert(solids, Shop.wallZ(zBack, -16.5, 16.5))
	return solids
end

-- The van zone at the kerb and the crew seats at its open door, facing the shop.
Shop.VAN = LevelSpec.span(-5, 0, 16, 5, 7, 24)
Shop.SPAWNS = {
	{ x = 0, y = 3, z = 14, yaw = 0 },
	{ x = -3, y = 3, z = 14, yaw = 0 },
	{ x = 3, y = 3, z = 14, yaw = 0 },
	{ x = 0, y = 3, z = 12.5, yaw = 0 },
}

function Shop.bounds(zBack: number): any
	return LevelSpec.span(-30, -5, zBack - 10, 30, 25, 34)
end

return table.freeze(Shop)
