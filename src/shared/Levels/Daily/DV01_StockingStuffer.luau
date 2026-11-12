--!strict
-- Daily vault 1 "Stocking Stuffer" (Corner Shop, par 1). The launch-day vault:
-- one plate holds the stockroom door, the L1 lesson in a new room. Bonus bauble
-- beside the stocking.

local Shop = require("../Shop")
local Vault = require("./Vault")

local Z_BACK = -34
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -20, -16.5, 16.5, -3, 3)

return Vault.spec(1, "dv01_stocking_stuffer", "Stocking Stuffer", "CornerShop", 1, {
	goal = 150,
	bounds = Shop.bounds(Z_BACK),
	solids = solids,
	plates = { { id = "A", box = Shop.plate(10, -8) } },
	doors = { { id = "Stockroom", box = Shop.doorAt(-20, -3, 3), openBy = { "A" } } },
	loot = {
		{ id = "Stocking", x = 0, y = 3, z = -28, value = 150, kind = "Present" },
		{ id = "Bauble", x = -10, y = 3, z = -28, value = 40, kind = "Present" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC", "LightsOff" },
		alt = { Stocking = { B = { x = 10, z = -28 }, C = { x = 5, z = -31 } } },
	},
})
