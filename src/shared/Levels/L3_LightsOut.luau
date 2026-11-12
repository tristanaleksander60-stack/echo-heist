--!strict
-- L3 "Lights Out" (Corner Shop). MASTERPLAN §4.2 row 3.
-- Teaches: a laser grid switched by a plate; Zap; fast-forward. Plate A opens the
-- back room; plate B, inside it, turns the grid in front of the register off.
-- A clone that walked the grid while it was off zaps itself when it is not.
-- Par 2, cap 4, 30 s runs, no deadline.
-- Golden solution: PLACEHOLDER scripted run in tests/sim/Solutions.luau (§8.9).

local LevelSpec = require("../Sim/LevelSpec")
local Shop = require("./Shop")

local Z_BACK = -46
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -20, -16.5, 16.5, -3, 3)
-- Counter against the west wall, so the walkway from the plates to the tip jar is clear.
table.insert(solids, { box = LevelSpec.span(-15.5, 0, -4, -11, 3.5, 0), sight = false })

return {
	format = 1,
	version = 1,
	id = "cs3_lights_out",
	num = 103,
	name = "Lights Out",
	location = "CornerShop",
	runSeconds = 30,
	par = 2,
	cap = 4,
	goal = 200,
	deadline = "None",
	seed = 103,
	bounds = Shop.bounds(Z_BACK),
	spawns = Shop.SPAWNS,
	van = Shop.VAN,
	solids = solids,
	plates = {
		{ id = "A", box = Shop.plate(10, -8) },
		{ id = "B", box = Shop.plate(12, -26) },
	},
	doors = {
		{ id = "BackRoom", box = Shop.doorAt(-20, -3, 3), openBy = { "A" } },
	},
	lasers = {
		{ id = "Grid", box = LevelSpec.span(-15.5, 0, -34.5, 15.5, 10, -33.5), offBy = { "B" } },
	},
	loot = {
		{ id = "Register", x = 0, y = 3, z = -40, value = 200, kind = "Cash" },
		{ id = "TipJar", x = -8, y = 3, z = 4, value = 10, kind = "Cash" },
	},
	solution = "PLACEHOLDER scripted (tests/sim/Solutions.luau); human-recorded solution.bin pending",
}
