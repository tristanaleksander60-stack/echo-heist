--!strict
-- L2 "Two Doors" (Corner Shop). MASTERPLAN §4.2 row 2.
-- Teaches: two plates; the Clone Deck; Undo last run. Plate A opens the back room,
-- plate B the stockroom behind it, so the safe needs two clones on two plates.
-- The tip jar by the counter is free (naive-kid guarantee: a bank within 3 runs).
-- Par 2, cap 4, 30 s runs, no deadline.
-- Golden solution: PLACEHOLDER scripted run in tests/sim/Solutions.luau (§8.9).

local LevelSpec = require("../Sim/LevelSpec")
local Shop = require("./Shop")

local Z_BACK = -44
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -20, -16.5, 16.5, -3, 3)
Shop.wallZGap(solids, -32, -16.5, 16.5, -3, 3)
-- Counter against the west wall, so the walkway from the plates to the tip jar is clear.
table.insert(solids, { box = LevelSpec.span(-15.5, 0, -4, -11, 3.5, 0), sight = false })

return {
	format = 1,
	version = 1,
	id = "cs2_two_doors",
	num = 102,
	name = "Two Doors",
	location = "CornerShop",
	runSeconds = 30,
	par = 2,
	cap = 4,
	goal = 200,
	deadline = "None",
	seed = 102,
	bounds = Shop.bounds(Z_BACK),
	spawns = Shop.SPAWNS,
	van = Shop.VAN,
	solids = solids,
	plates = {
		{ id = "A", box = Shop.plate(-10, -8) },
		{ id = "B", box = Shop.plate(10, -8) },
	},
	doors = {
		{ id = "BackRoom", box = Shop.doorAt(-20, -3, 3), openBy = { "A" } },
		{ id = "Stockroom", box = Shop.doorAt(-32, -3, 3), openBy = { "B" } },
	},
	loot = {
		{ id = "Safe", x = 0, y = 3, z = -40, value = 200, kind = "Cash" },
		{ id = "TipJar", x = -8, y = 3, z = 4, value = 10, kind = "Cash" },
	},
	solution = "PLACEHOLDER scripted (tests/sim/Solutions.luau); human-recorded solution.bin pending",
}
