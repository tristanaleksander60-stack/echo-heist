--!strict
-- Daily vault 9 "Sleigh Bell Alarm" (Corner Shop + Gus + Alarm Run, par 1). The
-- golden bell is the top loot: grabbing it wakes Gus (dozing in the back room)
-- and the shutter drops 10 s later. A clone hidden under the coat rack holds the
-- back-room door; outrun Gus to the van (§3.6).

local Shop = require("../Shop")
local Vault = require("./Vault")

local Z_BACK = -36
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -20, -16.5, 16.5, -3, 3)

return Vault.spec(9, "dv09_sleigh_bell_alarm", "Sleigh Bell Alarm", "CornerShop", 1, {
	goal = 200,
	deadline = "Alarm",
	bounds = Shop.bounds(Z_BACK),
	solids = solids,
	plates = { { id = "A", box = Shop.plate(10, -8) } },
	hides = { { id = "CoatRack", box = Vault.span(7, 0, -11, 13, 7, -5) } },
	doors = {
		{ id = "BackRoom", box = Shop.doorAt(-20, -3, 3), openBy = { "A" } },
		{ id = "Shutter", box = Shop.doorAt(10, -4, 4), alarmLock = true },
	},
	guards = {
		{
			id = "Gus",
			-- Dozing in the back room's east corner, facing the wall, until the alarm.
			route = {
				{ x = 12, z = -32, wait = 30, face = 270 },
				{ x = 12, z = -32, wait = 30, face = 270 },
			},
		},
	},
	nav = {
		{ x = 10, z = -28 },
		{ x = 0, z = -28 },
		{ x = -10, z = -28 },
		{ x = 0, z = -22 },
		{ x = 0, z = -16 },
		{ x = 0, z = -4 },
		{ x = 0, z = 6 },
		{ x = 0, z = 13 },
	},
	alarm = { trigger = "Bell" },
	loot = {
		{ id = "Bell", x = 0, y = 3, z = -30, value = 200, kind = "Gold", top = true },
		{ id = "Stocking", x = -12, y = 3, z = -28, value = 40, kind = "Present" },
		Vault.candyJar(),
		Vault.cookieTin(),
	},
	daily = {
		-- No GuardFast/GuardSlow: Gus dozes until the alarm (no patrol to speed up).
		modifiers = { "None", "LightsOff", "LootB", "LootC" },
		alt = { Stocking = { B = { x = -13, z = -24 }, C = { x = 5, z = -33 } } },
	},
})
