--!strict
-- Daily vault 3 "Candy-Cane Lasers" (Corner Shop, par 1). A candy-cane laser grid
-- across the whole shop, switched off while the plate by the window is held (L3).

local Shop = require("../Shop")
local Vault = require("./Vault")

local Z_BACK = -30
local solids = Shop.shell(Z_BACK)

return Vault.spec(3, "dv03_candy_cane_lasers", "Candy-Cane Lasers", "CornerShop", 1, {
	goal = 150,
	bounds = Shop.bounds(Z_BACK),
	solids = solids,
	plates = { { id = "A", box = Shop.plate(12, -2) } },
	lasers = { { id = "Canes", box = Vault.span(-15.5, 0, -12.5, 15.5, 10, -11.5), offBy = { "A" } } },
	loot = {
		{ id = "Present", x = 0, y = 3, z = -22, value = 150, kind = "Present" },
		{ id = "Lollipop", x = -12, y = 3, z = -5, value = 20, kind = "Candy" }, -- in front of the grid
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC", "LightsOff" },
		alt = { Present = { B = { x = 10, z = -24 }, C = { x = -6, z = -26 } } },
	},
})
