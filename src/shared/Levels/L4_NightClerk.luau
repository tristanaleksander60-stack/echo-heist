--!strict
-- L4 "Night Clerk" (Corner Shop). MASTERPLAN §4.2 row 4.
-- Teaches: Gus (3-stage cone), hiding spots, busted clones, Redo #N; the first
-- Dawn (par + 4 = 6 runs). Plate A opens the back room where Gus paces between the
-- shelves; plate B sits under the coat rack (a hide spot) and opens the safe room.
-- Cross while Gus faces the till at the east end. Par 2, cap 4, 30 s runs.
-- Golden solution: PLACEHOLDER scripted run in tests/sim/Solutions.luau (§8.9).

local LevelSpec = require("../Sim/LevelSpec")
local Shop = require("./Shop")

local Z_BACK = -46
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -20, -16.5, 16.5, -3, 3)
Shop.wallZGap(solids, -36, -16.5, 16.5, -3, 3)
-- Counter against the west wall, so the walkway from the plates to the tip jar is clear.
table.insert(solids, { box = LevelSpec.span(-15.5, 0, -4, -11, 3.5, 0), sight = false })

return {
	format = 1,
	version = 1,
	id = "cs4_night_clerk",
	num = 104,
	dataId = "NightClerk",
	name = "Night Clerk",
	location = "CornerShop",
	runSeconds = 30,
	par = 2,
	cap = 4,
	goal = 200,
	deadline = "Dawn",
	seed = 104,
	bounds = Shop.bounds(Z_BACK),
	spawns = Shop.SPAWNS,
	van = Shop.VAN,
	solids = solids,
	plates = {
		{ id = "A", box = Shop.plate(10, -8) },
		{ id = "B", box = Shop.plate(-12, -23) },
	},
	doors = {
		{ id = "BackRoom", box = Shop.doorAt(-20, -3, 3), openBy = { "A" } },
		{ id = "SafeRoom", box = Shop.doorAt(-36, -3, 3), openBy = { "B" } },
	},
	hides = {
		{ id = "CoatRack", box = LevelSpec.span(-15, 0, -26, -9, 7, -20.5) },
		{ id = "Crate", box = LevelSpec.span(3.5, 0, -35.5, 7.5, 6, -32.5) },
	},
	guards = {
		{
			id = "Gus",
			route = {
				{ x = 13, z = -28, wait = 2.5, face = 270 }, -- faces the till (east wall)
				{ x = -6, z = -28, wait = 1.5, face = 90 }, -- faces the west shelves
			},
		},
	},
	loot = {
		{ id = "NightDeposit", x = 0, y = 3, z = -42, value = 200, kind = "Cash" },
		{ id = "TipJar", x = -8, y = 3, z = 4, value = 10, kind = "Cash" },
	},
	solution = "PLACEHOLDER scripted (tests/sim/Solutions.luau); human-recorded solution.bin pending",
}
