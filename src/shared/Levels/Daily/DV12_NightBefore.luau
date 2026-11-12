--!strict
-- Daily vault 12 "The Night Before" (Bank + Gus, par 2). The advent's hardest
-- vault: every plate does two jobs. Plate A in the lobby holds the staff door AND
-- is one half of the vault lock; a clone hidden under the fern in the hall holds
-- plate B, which turns the laser grid off AND is the other half. Gus paces the hall
-- between them, so both the clone and the runner cross in his blind window (and the
-- runner crosses back). Par 2 leaves 3 spare runs before the fixed Dawn at run 6,
-- like every other daily. A breather follows (the rotation starts again at vault 1).

local Bank = require("../Bank")
local Vault = require("./Vault")

local Z_BACK = -48
local solids = Bank.shell(Z_BACK, false)
Bank.wallZGap(solids, -14, -20.5, 20.5, -3, 3)
Bank.wallZGap(solids, -38, -20.5, 20.5, -3, 3)

return Vault.spec(12, "dv12_night_before", "The Night Before", "Bank", 2, {
	goal = 300,
	bounds = Bank.bounds(Z_BACK),
	solids = solids,
	plates = {
		{ id = "A", box = Bank.plate(-12, -10) },
		{ id = "B", box = Bank.plate(-16, -18) },
	},
	doors = {
		{ id = "StaffDoor", box = Bank.doorAt(-14, -3, 3), openBy = { "A" } },
		{ id = "Vault", box = Bank.doorAt(-38, -3, 3), openBy = { "A", "B" }, need = "all" },
	},
	lasers = { { id = "Grid", box = Vault.span(-19.5, 0, -33.5, 19.5, 10, -32.5), offBy = { "B" } } },
	hides = {
		{ id = "Fern", box = Vault.span(-19.5, 0, -21, -13, 7, -14.5) },
		{ id = "CoatStand", box = Vault.span(13, 0, -21, 19.5, 7, -14.5) },
	},
	guards = {
		{
			id = "Gus",
			route = {
				{ x = 12, z = -26, wait = 5, face = 270 },
				{ x = -6, z = -26, wait = 1.5, face = 90 },
			},
		},
	},
	loot = {
		{ id = "Gift", x = 0, y = 3, z = -43, value = 300, kind = "Present" },
		{ id = "Coins", x = 12, y = 3, z = -44, value = 60, kind = "Gold" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		modifiers = { "None", "GuardFast", "GuardSlow", "LightsOff", "LootB", "LootC" },
		alt = { Coins = { B = { x = -12, z = -45 }, C = { x = 6, z = -46 } } },
	},
})
