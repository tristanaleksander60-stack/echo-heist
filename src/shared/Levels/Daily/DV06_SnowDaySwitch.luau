--!strict
-- Daily vault 6 "Snow Day Switch" (Bank, par 1). The sleigh bell by the teller
-- window opens the vault for 2 s, and the vault is far too far to reach in time: a
-- clone rings it while you wait at the vault door. The lobby opens to the hall only
-- at its east end, so the race from the bell (from the edge of press range) takes
-- 3.9 s against a door that is shut 2.35 s after the ring: a solo try misses by
-- 1.5 s, and even at the Validator's 1.35x WalkSpeed limit (2.95 s) it misses
-- (tests/sim/Daily.spec.luau). The timed switch is the "press" verb of §3.4; it has
-- no Mentor tape yet (owner decision: approve the verb for the advent, or move this
-- vault later behind a tape).

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
	switches = { { id = "Bell", x = -16, y = 3, z = -8, duration = 2 } },
	doors = { { id = "Vault", box = Bank.doorAt(-44, -3, 3), openBy = { "Bell" } } },
	loot = {
		{ id = "Gift", x = 0, y = 3, z = -50, value = 200, kind = "Present" },
		{ id = "Coins", x = 12, y = 3, z = -50, value = 50, kind = "Gold" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "LootB", "LootC" },
		alt = { Coins = { B = { x = -12, z = -52 }, C = { x = 6, z = -53 } } },
	},
})
