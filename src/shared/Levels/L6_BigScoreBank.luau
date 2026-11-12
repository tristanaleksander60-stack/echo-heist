--!strict
-- L6 "The Big Score: Bank" (Hoardsworth Bank, 45 s runs). MASTERPLAN §4.2 row 6,
-- §3.6 (Alarm Run escape), §3.1 (Dawn at par + 4), §5.2 (6-Star gate, Diamond).
--
-- The launch finale: every verb from L1-L5 in one plan, a breather of known pieces
-- in a new place. The vault door is the "scale": it opens only while all four
-- pressure plates are held (4 actors on 4 plates), and each plate also does one
-- job you already know:
--   A  behind the teller desk (a hide spot)   holds the staff door        (L1, L4)
--   B  under the fern in the hall (hidden)     turns the laser grid off   (L3, L4)
--   C  under the west deposit stack (hidden)   scale only
--   D  under the east deposit stack (hidden)   holds the loading-dock door (§3.6:
--                                              "a clone on a plate holds the escape door")
-- Gus paces the hall between the staff door and the lasers (cross while he faces
-- the east wall). A marble pillar just inside the staff door (east side) blocks his
-- view through the doorway when he turns west at the east end, so the natural spot
-- to wait for the crossing, beside the staff door in the lobby, is safe: a kid who
-- misses one window waits for the next (one every ~9 s). Grabbing the Hoardsworth Gold trips the Alarm Run: Gus chases the
-- nearest robber he can see, LOCKDOWN shuts the front doors and the dock 10 s later
-- (alarmLock), the van leaves after 20 s. The way out is the dock and the service
-- alley; an extra clone running a different route is a decoy (over par: no Crew
-- star, still a clear). Gus catching a live player also trips the alarm.
-- Par 4, cap 8 (Big Scores grant 8), Dawn at run 8. Free loot in the lobby keeps
-- the naive-kid guarantee. `haul` = all the loot, so banking the gold clears the
-- heist at the end of that run, not at once: the coins beside it still count (a
-- second trip under the Alarm Run, or a clone that carries them). Numbers match Config.Data.Levels.BigScoreBank (tests).
-- Golden solution: PLACEHOLDER scripted runs in tests/sim/Solutions.luau (§8.9).

local Bank = require("./Bank")
local Config = require("../Config")
local LevelSpec = require("../Sim/LevelSpec")

local span = LevelSpec.span
local L = Config.Levels
local PAR = 4

local Z_BACK = -60
local solids = Bank.shell(Z_BACK, true)
Bank.fence(solids, Z_BACK)
Bank.wallZGap(solids, -14, -20.5, 20.5, -3, 3) -- lobby | hall (staff door)
Bank.wallZGap(solids, -36, -20.5, 20.5, -3, 3) -- hall | scale room (open arch)
Bank.wallZGap(solids, -48, -20.5, 20.5, -3, 3) -- scale room | vault (vault door)
-- Teller counter across the lobby with a gate in the middle (low: Gus sees over it).
table.insert(solids, { box = span(-19.5, 0, -6, -3, 3.5, -4), sight = false })
table.insert(solids, { box = span(3, 0, -6, 19.5, 3.5, -4), sight = false })
-- Marble pillar (kit Pillar_2x12) in the hall beside the staff door: hides the lobby
-- side of the doorway from Gus at the hall's east end.
table.insert(solids, { id = "StaffPillar", box = span(2, 0, -18, 4, 12, -16) })

local loot = {
	{ id = "Gold", x = 0, y = 3, z = -55, value = 2000, kind = "Gold", top = true },
	{ id = "Coins", x = 13, y = 3, z = -55, value = 150, kind = "Gold" },
	{ id = "Drawer", x = 12, y = 3, z = -9, value = 50, kind = "Cash" },
	{ id = "CandyBowl", x = 8, y = 3, z = 4, value = 20, kind = "Candy" },
}
local allLoot = 0
for _, item in loot do
	allLoot += item.value
end

return {
	format = 1,
	version = 1,
	id = "bk1_big_score",
	num = 106,
	dataId = "BigScoreBank",
	name = "The Big Score: Bank",
	location = "Bank",
	runSeconds = L.BANK_RUN_SECONDS,
	par = PAR,
	cap = L.BIG_SCORE_CAP,
	goal = 2000,
	haul = allLoot,
	deadline = "Alarm",
	dawnRuns = LevelSpec.dawnRunsFor(PAR),
	seed = 106,
	bounds = Bank.bounds(Z_BACK),
	spawns = Bank.SPAWNS,
	van = Bank.VAN,
	solids = solids,
	plates = {
		{ id = "A", box = Bank.plate(-12, -10) },
		{ id = "B", box = Bank.plate(-16, -18) },
		{ id = "C", box = Bank.plate(-13, -42) },
		{ id = "D", box = Bank.plate(13, -42) },
	},
	doors = {
		{ id = "StaffDoor", box = Bank.doorAt(-14, -3, 3), openBy = { "A" } },
		{ id = "VaultDoor", box = Bank.doorAt(-48, -3, 3), openBy = { "A", "B", "C", "D" }, need = "all" },
		{ id = "LoadingDock", box = Bank.doorAt(Z_BACK, -3, 3), openBy = { "D" }, alarmLock = true },
		-- LOCKDOWN: the front doors stand open until the alarm locks them.
		{ id = "FrontDoors", box = Bank.doorAt(10, -4, 4), alarmLock = true },
	},
	lasers = {
		{ id = "HallGrid", box = span(-19.5, 0, -33.5, 19.5, 10, -32.5), offBy = { "B" } },
	},
	hides = {
		{ id = "TellerDesk", box = Bank.hideAt(-12, -10) },
		{ id = "Fern", box = span(-19.5, 0, -21, -13, 7, -14.5) },
		{ id = "WestStack", box = Bank.hideAt(-13, -42) },
		{ id = "EastStack", box = Bank.hideAt(13, -42) },
		{ id = "CoatStand", box = Bank.hideAt(16, -17, 5, 5) },
	},
	guards = {
		{
			id = "Gus",
			route = {
				{ x = 14, z = -24, wait = 2.5, face = 270 }, -- faces the east wall
				{ x = -6, z = -24, wait = 1.5, face = 90 }, -- faces the west wall
			},
		},
	},
	nav = {
		{ x = 0, z = 0 },
		{ x = 0, z = -12 },
		{ x = 0, z = -18 },
		{ x = -12, z = -26 },
		{ x = 12, z = -26 },
		{ x = 0, z = -30 },
		{ x = 0, z = -40 },
		{ x = -8, z = -42 },
		{ x = 8, z = -42 },
		{ x = 0, z = -54 },
		{ x = 0, z = -66 },
		{ x = 25, z = -66 },
		{ x = -25, z = -66 },
		{ x = 25, z = -30 },
		{ x = -25, z = -30 },
		{ x = 25, z = 13 },
		{ x = -25, z = 13 },
		{ x = 0, z = 13 },
	},
	alarm = { trigger = "Gold", onCatch = true },
	loot = loot,
	-- Crew Line-up on the street in front of the bank, facing a street camera.
	lineup = { x = 0, z = 28, yaw = 180 },
	hooks = {
		reel = true, -- "first Heist Reel worth posting" (§4.2)
		lockdown = { doors = { "FrontDoors", "LoadingDock" } },
	},
	solution = "PLACEHOLDER scripted (tests/sim/Solutions.luau); human-recorded solution.bin pending",
}
