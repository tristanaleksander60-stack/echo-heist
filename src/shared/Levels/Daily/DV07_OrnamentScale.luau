--!strict
-- Daily vault 7 "Ornament Scale" (Bank, par 3). A small scale vault: the door opens
-- only while all three plates are held (the Big Score's lock, three pans).

local Bank = require("../Bank")
local Vault = require("./Vault")

local Z_BACK = -46
local solids = Bank.shell(Z_BACK, false)
Bank.wallZGap(solids, -30, -20.5, 20.5, -3, 3)

return Vault.spec(7, "dv07_ornament_scale", "Ornament Scale", "Bank", 3, {
	goal = 250,
	bounds = Bank.bounds(Z_BACK),
	solids = solids,
	plates = {
		{ id = "A", box = Bank.plate(-14, -10) },
		{ id = "B", box = Bank.plate(14, -10) },
		{ id = "C", box = Bank.plate(-14, -24) },
	},
	doors = { { id = "Vault", box = Bank.doorAt(-30, -3, 3), openBy = { "A", "B", "C" }, need = "all" } },
	loot = {
		{ id = "Gift", x = 0, y = 3, z = -38, value = 250, kind = "Present" },
		{ id = "Coins", x = 12, y = 3, z = -40, value = 60, kind = "Gold" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC", "LightsOff" },
		alt = { Gift = { B = { x = -10, z = -40 }, C = { x = 6, z = -36 } } },
	},
})
