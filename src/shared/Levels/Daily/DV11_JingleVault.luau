--!strict
-- Daily vault 11 "Jingle Vault" (Bank, par 2). Plate A opens the staff door; the
-- vault needs A and B held together (a plate that does two jobs).

local Bank = require("../Bank")
local Vault = require("./Vault")

local Z_BACK = -50
local solids = Bank.shell(Z_BACK, false)
Bank.wallZGap(solids, -14, -20.5, 20.5, -3, 3)
Bank.wallZGap(solids, -36, -20.5, 20.5, -3, 3)

return Vault.spec(11, "dv11_jingle_vault", "Jingle Vault", "Bank", 2, {
	goal = 250,
	bounds = Bank.bounds(Z_BACK),
	solids = solids,
	plates = {
		{ id = "A", box = Bank.plate(-12, -8) },
		{ id = "B", box = Bank.plate(12, -24) },
	},
	doors = {
		{ id = "StaffDoor", box = Bank.doorAt(-14, -3, 3), openBy = { "A" } },
		{ id = "Vault", box = Bank.doorAt(-36, -3, 3), openBy = { "A", "B" }, need = "all" },
	},
	loot = {
		{ id = "Gift", x = 0, y = 3, z = -44, value = 250, kind = "Present" },
		{ id = "Coins", x = -12, y = 3, z = -44, value = 50, kind = "Gold" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC", "LightsOff" },
		alt = { Gift = { B = { x = 12, z = -44 }, C = { x = 4, z = -46 } } },
	},
})
