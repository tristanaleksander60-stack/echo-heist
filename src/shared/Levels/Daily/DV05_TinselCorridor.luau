--!strict
-- Daily vault 5 "Tinsel Corridor" (Corner Shop, par 2). Two doors in a row: plate
-- A opens the first, plate B (behind it) the second (L2 in a longer shop).

local Shop = require("../Shop")
local Vault = require("./Vault")

local Z_BACK = -42
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -18, -16.5, 16.5, -3, 3)
Shop.wallZGap(solids, -30, -16.5, 16.5, -3, 3)

return Vault.spec(5, "dv05_tinsel_corridor", "Tinsel Corridor", "CornerShop", 2, {
	goal = 200,
	bounds = Shop.bounds(Z_BACK),
	solids = solids,
	plates = {
		{ id = "A", box = Shop.plate(-10, -8) },
		{ id = "B", box = Shop.plate(10, -24) },
	},
	doors = {
		{ id = "Hall1", box = Shop.doorAt(-18, -3, 3), openBy = { "A" } },
		{ id = "Hall2", box = Shop.doorAt(-30, -3, 3), openBy = { "B" } },
	},
	loot = {
		{ id = "Present", x = 0, y = 3, z = -37, value = 200, kind = "Present" },
		{ id = "Tinsel", x = -10, y = 3, z = -24, value = 40, kind = "Present" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC" },
		alt = { Tinsel = { B = { x = -13, z = -21 }, C = { x = 10, z = -38 } } },
	},
})
