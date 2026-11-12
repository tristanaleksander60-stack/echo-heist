--!strict
-- Daily vault 2 "Twin Chimneys" (Corner Shop, par 2). The fireplace door needs
-- both plates at once (need = "all"), one at each end of the shop.

local Shop = require("../Shop")
local Vault = require("./Vault")

local Z_BACK = -34
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -20, -16.5, 16.5, -3, 3)

return Vault.spec(2, "dv02_twin_chimneys", "Twin Chimneys", "CornerShop", 2, {
	goal = 200,
	bounds = Shop.bounds(Z_BACK),
	solids = solids,
	plates = {
		{ id = "A", box = Shop.plate(-12, -8) },
		{ id = "B", box = Shop.plate(12, -8) },
	},
	doors = { { id = "Fireplace", box = Shop.doorAt(-20, -3, 3), openBy = { "A", "B" }, need = "all" } },
	loot = {
		{ id = "Present", x = 0, y = 3, z = -28, value = 200, kind = "Present" },
		{ id = "Tinsel", x = 12, y = 3, z = -28, value = 40, kind = "Present" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC", "LightsOff" },
		alt = { Present = { B = { x = -10, z = -28 }, C = { x = 4, z = -31 } } },
	},
})
