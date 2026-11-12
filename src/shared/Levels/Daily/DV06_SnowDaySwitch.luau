--!strict
-- Daily vault 6 "Snow Day Switch" (Bank, par 1). The sleigh bell by the teller
-- window opens the vault for 3 s, and the vault is too far to reach in time: a
-- clone rings it while you wait at the vault door. The lobby opens to the hall only
-- at its east end, so the race from the bell (press range included) is ~3.6 s
-- against a 3.35 s door. The timed switch is the "press" verb of §3.4.

local Bank = require("../Bank")
local Vault = require("./Vault")

local Z_BACK = -56
local solids = Bank.shell(Z_BACK, false)
Bank.wallZGap(solids, -14, -20.5, 20.5, 12, 18) -- lobby | hall, open at the east end
Bank.wallZGap(solids, -44, -20.5, 20.5, -3, 3) -- hall | vault

return Vault.spec(6, "dv06_snow_day_switch", "Snow Day Switch", "Bank", 1, {
	goal = 200,
	bounds = Bank.bounds(Z_BACK),
	solids = solids,
	switches = { { id = "Bell", x = -16, y = 3, z = -8, duration = 3 } },
	doors = { { id = "Vault", box = Bank.doorAt(-44, -3, 3), openBy = { "Bell" } } },
	loot = {
		{ id = "Gift", x = 0, y = 3, z = -50, value = 200, kind = "Present" },
		{ id = "Coins", x = 12, y = 3, z = -50, value = 50, kind = "Gold" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC", "LightsOff" },
		alt = { Gift = { B = { x = -4, z = -51 }, C = { x = 4, z = -49 } } },
	},
})
