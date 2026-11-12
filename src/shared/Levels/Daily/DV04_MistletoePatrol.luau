--!strict
-- Daily vault 4 "Mistletoe Patrol" (Corner Shop + Gus, par 1). A clone holds the
-- back-room door; Gus paces the back room. Grab the present while he faces the
-- east wall (L4's cone and timing). A Christmas tree to hide behind.

local Shop = require("../Shop")
local Vault = require("./Vault")

local Z_BACK = -38
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -20, -16.5, 16.5, -3, 3)

return Vault.spec(4, "dv04_mistletoe_patrol", "Mistletoe Patrol", "CornerShop", 1, {
	goal = 200,
	bounds = Shop.bounds(Z_BACK),
	solids = solids,
	plates = { { id = "A", box = Shop.plate(10, -8) } },
	doors = { { id = "BackRoom", box = Shop.doorAt(-20, -3, 3), openBy = { "A" } } },
	hides = { { id = "Tree", box = Vault.span(-15.5, 0, -26.5, -10.5, 7, -21.5) } },
	guards = {
		{
			id = "Gus",
			route = {
				{ x = 12, z = -28, wait = 3, face = 270 }, -- faces the east wall
				{ x = -8, z = -28, wait = 1.5, face = 90 }, -- faces the west wall
			},
		},
	},
	loot = {
		{ id = "Present", x = 0, y = 3, z = -34, value = 200, kind = "Present" },
		{ id = "Ribbon", x = -12, y = 3, z = -34, value = 40, kind = "Present" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "GuardFast", "GuardSlow", "LightsOff", "LootB", "LootC" },
		alt = { Ribbon = { B = { x = 12, z = -35 }, C = { x = -6, z = -35 } } },
	},
})
