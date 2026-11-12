--!strict
-- L5 "Clone Party" (Corner Shop after hours, the Toy Shop in Christmas dressing).
-- MASTERPLAN §4.2 row 5, §3.1 (Dawn at run 8), §3.6 (Alarm Run), §5.2 (Haul tiers),
-- §5.3 (personal-best haul, bag levels), §0 C12 (8 slots in session 1).
--
-- The repeatable loop: "how much can 8 of you steal before Dawn?" No doors, no
-- plates, no par: three aisles of toy shelves whose loot comes back
-- PARTY_RESPAWN_SECONDS after it is banked, so every clone keeps stealing. Gus dozes
-- in the back office facing the wall. The till by the counter is the top loot, and
-- it is TIME-LOCKED: it only opens at 0:20 of every run (PARTY_TILL_OPENS_SECONDS;
-- the view shows its countdown, an early grab is refused as Locked). Robbing it
-- trips the Alarm Run (Gus chases the nearest robber he can see, the shop shutter
-- drops PARTY_SHUTTER_SECONDS later, the van timer outlasts the 30 s run), so the
-- till is always the last act of a run: the getaway beat. The clone that robbed it
-- robs it again at the same second every later run, which costs the final ~10 s of
-- each run (the chase, the shutter), never the whole run. Bag levels count here
-- (`bags`). Haul tiers = the 3 Stars; they match Config.Data.Levels.CloneParty.haulTiers
-- (asserted in tests).
--
-- The swarm moment: run 8 starts with 7 clones + you = "8 OF ME" (a Swarm event
-- after the tape-print fan-out, HeistSim.ofMe), and Dawn ends the heist into the
-- Crew Line-up (HeistSim.lineup) on the street in front of the shop. Played third,
-- right after L2, as the "party break" (owner decision 2026-11-12, Levels/Catalog), so
-- the swarm lands around minute 10 of a first session (tests/sim/Pacing.spec.luau
-- prints the model against the §7.5 "SwarmSeen by minute 10" target). It needs no
-- verb that L3 or L4 teaches: no plates, doors or lasers, and Gus only wakes for the
-- till. The Clone Deck is read-only here (HeistInstance: every clone stays in the party,
-- so no Delete or Redo can turn "8 OF ME" into "7 OF ME"), so there is no RedoAlarm
-- hint: the HUD frames the till as the getaway ("GETAWAY!" once, then the van counter),
-- never as blame. Runs auto-start after Config.Heist.PARTY_BETWEEN_SECONDS. L3 opens
-- alongside it.
-- Golden solution: PLACEHOLDER scripted runs in tests/sim/Solutions.luau (§8.9).

local Config = require("../Config")
local LevelSpec = require("../Sim/LevelSpec")
local Shop = require("./Shop")

local span = LevelSpec.span
local L = Config.Levels

local Z_BACK = -40
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -28, -16.5, 16.5, -3, 3) -- back office, open doorway
-- The counter (west, low: Gus sees over it) with the till on its east end.
table.insert(solids, { box = span(-15.5, 0, -3, -10, 3.5, 1), sight = false })
-- Three tall shelf units (block sight too: cover in the chase).
local SHELF_X = { -8, 0, 8 }
for _, x in SHELF_X do
	table.insert(solids, { box = span(x - 1, 0, -22, x + 1, 7, -6) })
end

-- Shelf loot: both faces of each unit, three rows deep. Front rows are cheap and
-- contested; the back rows are worth more and further from the van.
local ROWS = {
	{ z = -8, value = 15, kind = "Candy" },
	{ z = -14, value = 25, kind = "Toy" },
	{ z = -20, value = 40, kind = "Teddy" },
}
local loot: { any } = {
	-- The till: top loot (Alarm Run), robbed at most once per run.
	{
		id = "Register",
		x = -8.5,
		y = 3,
		z = -1,
		value = 300,
		kind = "Cash",
		top = true,
		respawn = L.PARTY_REGISTER_RESPAWN,
		opensAt = L.PARTY_TILL_OPENS_SECONDS,
	},
}
for u, x in SHELF_X do
	for side, dx in { -2.5, 2.5 } do
		for r, row in ROWS do
			table.insert(loot, {
				id = string.format("Shelf%d%s%d", u, if side == 1 then "W" else "E", r),
				x = x + dx,
				y = 3,
				z = row.z,
				value = row.value,
				kind = row.kind,
				respawn = L.PARTY_RESPAWN_SECONDS,
			})
		end
	end
end
-- Wall displays by the door: the first thing a kid sees.
table.insert(
	loot,
	{ id = "WindowW", x = -13, y = 3, z = 6, value = 15, kind = "Candy", respawn = L.PARTY_RESPAWN_SECONDS }
)
table.insert(
	loot,
	{ id = "WindowE", x = 13, y = 3, z = 6, value = 15, kind = "Candy", respawn = L.PARTY_RESPAWN_SECONDS }
)
-- Gus's piggy bank on the office desk, behind his back (once per run).
table.insert(
	loot,
	{ id = "PiggyBank", x = 11, y = 3, z = -33, value = 100, kind = "Cash", respawn = L.PARTY_REGISTER_RESPAWN }
)

return {
	format = 1,
	version = 1,
	id = "cs5_clone_party",
	num = 105,
	dataId = "CloneParty",
	name = "Clone Party",
	location = "CornerShop",
	kind = "party",
	tiers = { 1000, 2500, 5000 },
	runSeconds = 30,
	par = 0,
	cap = L.PARTY_CAP,
	bags = true,
	deadline = "Alarm",
	dawnRuns = L.PARTY_DAWN_RUNS,
	seed = 105,
	bounds = Shop.bounds(Z_BACK),
	spawns = Shop.SPAWNS,
	van = Shop.VAN,
	solids = solids,
	doors = {
		-- The shop shutter: open all night, drops ALARM_LOCK_SECONDS after the alarm.
		{ id = "Shutter", box = Shop.doorAt(10, -4, 4), alarmLock = true },
	},
	guards = {
		{
			id = "Gus",
			-- Dozing at the office desk, facing the back wall, until the alarm.
			route = {
				{ x = 0, z = -36, wait = 60, face = 0 },
				{ x = 0, z = -36, wait = 60, face = 0 },
			},
		},
	},
	nav = {
		{ x = 0, z = -34 },
		{ x = 0, z = -26 },
		{ x = -12.5, z = -25 },
		{ x = -4, z = -25 },
		{ x = 4, z = -25 },
		{ x = 12.5, z = -25 },
		{ x = -12.5, z = -4.5 },
		{ x = -4, z = -4.5 },
		{ x = 4, z = -4.5 },
		{ x = 12.5, z = -4.5 },
		{ x = 0, z = 4 },
		{ x = 0, z = 13 },
		{ x = -8, z = 13 },
		{ x = 8, z = 13 },
	},
	alarm = { trigger = "Register", lockSeconds = L.PARTY_SHUTTER_SECONDS },
	loot = loot,
	-- Crew Line-up on the street in front of the shop, facing a street camera (the van
	-- and the lit shop front behind the crew).
	lineup = { x = 0, z = 28, yaw = 180 },
	hooks = {
		-- The view stamps string.format(stamp, b) on the Swarm event (a = seat, b = copies
		-- of you, c = the crew's) when b >= ofMe, and crewStamp with c in co-op.
		swarm = { run = L.PARTY_DAWN_RUNS, ofMe = Config.Sim.SWARM_OF_ME, stamp = "%d OF ME", crewStamp = "%d ROBBERS" },
		board = "BiggestHaulToday", -- garage server board (§4.2), personal best (§5.3)
		lineup = true,
		till = { loot = "Register", opensAt = L.PARTY_TILL_OPENS_SECONDS }, -- countdown on the till
	},
	solution = "PLACEHOLDER scripted (tests/sim/Solutions.luau); human-recorded solution.bin pending",
}
