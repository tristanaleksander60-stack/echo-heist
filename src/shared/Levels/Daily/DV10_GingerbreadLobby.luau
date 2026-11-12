--!strict
-- Daily vault 10 "Gingerbread Lobby" (Bank + Gus, par 2). A mini Big Score: plate A
-- holds the staff door, a clone hidden under the fern holds the laser plate, and
-- Gus paces the hall. Cross while he faces the east wall.

local Bank = require("../Bank")
local Vault = require("./Vault")

local Z_BACK = -40
local solids = Bank.shell(Z_BACK, false)
Bank.wallZGap(solids, -14, -20.5, 20.5, -3, 3)

return Vault.spec(10, "dv10_gingerbread_lobby", "Gingerbread Lobby", "Bank", 2, {
	goal = 250,
	bounds = Bank.bounds(Z_BACK),
	solids = solids,
	plates = {
		{ id = "A", box = Bank.plate(-12, -10) },
		{ id = "B", box = Bank.plate(-16, -18) },
	},
	doors = { { id = "StaffDoor", box = Bank.doorAt(-14, -3, 3), openBy = { "A" } } },
	lasers = { { id = "Grid", box = Vault.span(-19.5, 0, -31.5, 19.5, 10, -30.5), offBy = { "B" } } },
	hides = { { id = "Fern", box = Vault.span(-19.5, 0, -21, -13, 7, -14.5) } },
	guards = {
		{
			id = "Gus",
			route = {
				{ x = 14, z = -24, wait = 3.5, face = 270 },
				{ x = -6, z = -24, wait = 1.5, face = 90 },
			},
		},
	},
	loot = {
		{ id = "Gift", x = 0, y = 3, z = -36, value = 250, kind = "Present" },
		{ id = "CookieTin", x = 12, y = 3, z = -8, value = 40, kind = "Candy" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "GuardFast", "GuardSlow", "LightsOff", "LootB" },
		alt = { Gift = { B = { x = 4, z = -36 } } },
	},
})
