--!strict
-- Daily vault 8 "Frosty Window" (Corner Shop, par 2). Plate A turns the frost grid
-- off; plate B behind the grid opens the pantry (L3 then L2).

local Shop = require("../Shop")
local Vault = require("./Vault")

local Z_BACK = -40
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -26, -16.5, 16.5, -3, 3)

return Vault.spec(8, "dv08_frosty_window", "Frosty Window", "CornerShop", 2, {
	goal = 200,
	bounds = Shop.bounds(Z_BACK),
	solids = solids,
	plates = {
		{ id = "A", box = Shop.plate(12, -4) },
		{ id = "B", box = Shop.plate(12, -20) },
	},
	doors = { { id = "Pantry", box = Shop.doorAt(-26, -3, 3), openBy = { "B" } } },
	lasers = { { id = "Frost", box = Vault.span(-15.5, 0, -14.5, 15.5, 10, -13.5), offBy = { "A" } } },
	loot = {
		{ id = "Present", x = 0, y = 3, z = -34, value = 200, kind = "Present" },
		{ id = "SnowGlobe", x = -12, y = 3, z = -6, value = 30, kind = "Present" }, -- in front of the grid
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC" },
		-- B behind the grid, C in the pantry: the snow globe costs a trip past a clone.
		alt = { SnowGlobe = { B = { x = -12, z = -20 }, C = { x = 12, z = -35 } } },
	},
})
