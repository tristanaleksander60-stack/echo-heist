-- PLACEHOLDER solutions for the launch levels (not a spec itself).
-- MASTERPLAN §8.9: golden solutions are HUMAN-RECORDED in Studio and pulled into
-- levels/<id>.solution.bin. Until the owner records them, these hand-scripted bot
-- runs prove each level is solvable at par. Replace, do not extend, once the
-- recorded buffers exist (the spec then decodes them with Rec/Codec and feeds the
-- first N runs as clones).
--
-- Each entry is a Harness plan (runs[r][playerId] = Bot steps), or a function of
-- the compiled level that returns one (Solutions.planFor resolves both). Daily vault
-- plans are functions because the day's modifier moves loot and changes Gus's pace:
-- they watch Gus (as a player does) instead of a stopwatch.

local Geom = require("../../src/shared/Sim/Geom")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Loot = require("../../src/shared/Sim/Loot")
local Mechanisms = require("../../src/shared/Sim/Mechanisms")

local Solutions = {}

Solutions.PLACEHOLDER = true

-- L1 Back Room: run 1 stands on the plate (auto-ends after 2 s); run 2 walks
-- through the held door, grabs the cash (behind the right window, off the door's axis) and banks it.
Solutions.cs1_back_room = {
	runs = {
		{ [1] = { { goPlate = "A" }, { stay = true } } },
		{
			[1] = {
				{ go = { 0, -17 } },
				{ go = { 0, -23 } },
				{ goLoot = "Cash" },
				{ grab = "Cash" },
				{ go = { 0, -23 } },
				{ go = { 0, -17 } },
				{ goVan = true },
				{ stay = true },
			},
		},
	},
}

-- L2 Two Doors: clone 1 holds A, clone 2 holds B, run 3 takes the safe.
Solutions.cs2_two_doors = {
	runs = {
		{ [1] = { { goPlate = "A" }, { endRun = true } } },
		{ [1] = { { goPlate = "B" }, { endRun = true } } },
		{ [1] = { { goLoot = "Safe" }, { grab = "Safe" }, { goVan = true }, { stay = true } } },
	},
}

-- L3 Lights Out: clone 1 holds A (door), clone 2 walks in and holds B (grid off);
-- run 3 waits a beat for the grid, then takes the register.
Solutions.cs3_lights_out = {
	runs = {
		{ [1] = { { goPlate = "A" }, { endRun = true } } },
		{ [1] = { { go = { 0, -23 } }, { goPlate = "B" }, { endRun = true } } },
		{ [1] = { { wait = 1 }, { goLoot = "Register" }, { grab = "Register" }, { goVan = true }, { stay = true } } },
	},
}

-- L4 Night Clerk: clone 1 holds A; clone 2 slips to the coat rack (plate B, hidden)
-- while Gus faces east; run 3 crosses for the deposit during his next east turn.
-- Timings are tuned against Gus's patrol(t) (period 8.75 s).
Solutions.cs4_night_clerk = {
	runs = {
		{ [1] = { { goPlate = "A" }, { endRun = true } } },
		{
			[1] = {
				{ go = { 0, -10 } },
				{ waitUntil = 4.2 },
				{ go = { 0, -21.5 } },
				{ goPlate = "B" },
				{ endRun = true },
			},
		},
		{
			[1] = {
				{ go = { 0, -10 } },
				{ waitUntil = 6.0 },
				{ goLoot = "NightDeposit" },
				{ grab = "NightDeposit" },
				{ go = { 0, -10 } },
				{ goVan = true },
				{ stay = true },
			},
		},
	},
}

---------------------------------------------------------------------------
-- Step helpers
---------------------------------------------------------------------------

local function cat(...: { any }): { any }
	local out = {}
	for _, list in { ... } do
		for _, step in list do
			table.insert(out, step)
		end
	end
	return out
end

-- Waits until a door looks open to this client (the server state it has received).
local function untilOpen(level: any, doorId: string): any
	local i = LevelSpec.indexOf(level, "door", doorId)
	return {
		waitFor = function(_bot: any, view: any, t: number): boolean
			return view ~= nil and Mechanisms.doorViewOf(view.doors[i], t) == "open"
		end,
	}
end

-- Waits for the start of Gus's blind window: he walks (or stands) facing the east
-- wall at x >= xMin. Waits for a moment he is NOT in it first, so a late arrival
-- never starts in the middle of a window. Watching Gus (not a clock) keeps the plan
-- valid under the daily +-10% speed modifiers. State lives on the bot (one per run).
local function untilGusEast(xMin: number): any
	local step
	step = {
		decide = function(bot: any, sim: any, _view: any, _t: number): { any }
			local g = sim.guards[1]
			local fx = Geom.forward(g.yaw)
			local safe = g.mode == "Patrol" and fx > 0.9 and g.x >= xMin
			bot.gusUnsafe = bot.gusUnsafe or {}
			if not safe then
				bot.gusUnsafe[step] = true
			elseif bot.gusUnsafe[step] then
				return {}
			end
			return { { wait = 0.05 }, step }
		end,
	}
	return step
end

-- Grabs a respawning item as soon as it is back on its shelf (Clone Party).
local function grabWhenBack(level: any, itemId: string): any
	local idx = LevelSpec.indexOf(level, "loot", itemId)
	local step
	step = {
		decide = function(_bot: any, sim: any, _view: any, _t: number): { any }
			if Loot.available(sim.loot, idx) then
				return { { grab = itemId } }
			end
			return { { wait = 0.05 }, step }
		end,
	}
	return step
end

function Solutions.planFor(level: any): any
	local entry = Solutions[level.id]
	if type(entry) == "function" then
		return entry(level)
	end
	return entry
end

Solutions.untilGusEast = untilGusEast
Solutions.untilOpen = untilOpen
Solutions.grabWhenBack = grabWhenBack

---------------------------------------------------------------------------
-- L5 Clone Party: no par. Each of the 8 runs farms its own pair of shelf items
-- (alternating, so each is back by the next trip), so no clone ever steals from
-- another; run 8 robs the till at the end (Alarm Run) and banks it. Reaches all
-- three Haul tiers before Dawn with bag level 0.
---------------------------------------------------------------------------

local PARTY_PAIRS = {
	{ "Shelf1W3", "Shelf1W2" },
	{ "Shelf3E3", "Shelf3E2" },
	{ "Shelf1E3", "Shelf1E2" },
	{ "Shelf3W3", "Shelf3W2" },
	{ "Shelf2W3", "Shelf2W2" },
	{ "Shelf2E3", "Shelf2E2" },
	{ "Shelf1W1", "Shelf1E1" },
	{ "Shelf3W1", "Shelf3E1" },
}
Solutions.PARTY_PAIRS = PARTY_PAIRS

-- One shelf trip: in through the shop door, down the item's aisle, back to the van.
function Solutions.partyTrip(level: any, itemId: string, out: { any })
	local d = level.loot[LevelSpec.indexOf(level, "loot", itemId)]
	local lane = if d.x < -9 then -12.5 elseif d.x < -1 then -4 elseif d.x < 7 then 4 else 12.5
	local entryX = if lane < 0 then -6 else 6
	for _, step in
		{
			{ go = { 0, 9 } },
			{ go = { entryX, -4.5 } },
			{ go = { lane, -4.5 } },
			{ goLoot = itemId },
			grabWhenBack(level, itemId),
			{ go = { lane, -4.5 } },
			{ go = { entryX, -4.5 } },
			{ go = { 0, 9 } },
			{ go = { 0, 17 } },
		}
	do
		table.insert(out, step)
	end
end

Solutions.cs5_clone_party = function(level: any): any
	local runs = {}
	for r, pair in PARTY_PAIRS do
		local steps = {}
		local trips = if r == #PARTY_PAIRS then 3 else 12
		for k = 1, trips do
			Solutions.partyTrip(level, pair[(k - 1) % 2 + 1], steps)
		end
		if r == #PARTY_PAIRS then
			-- The till, last: the alarm only costs the final seconds of the final run.
			for _, step in
				{
					{ waitUntil = 21 },
					{ go = { 0, 9 } },
					{ go = { -7, 0 } },
					{ goLoot = "Register" },
					{ grab = "Register" },
					{ go = { 0, 9 } },
					{ go = { 0, 17 } },
					{ endRun = true }, -- banked: done for the night (Dawn follows)
				}
			do
				table.insert(steps, step)
			end
		end
		table.insert(steps, { stay = true })
		table.insert(runs, { [1] = steps })
	end
	return { runs = runs }
end

---------------------------------------------------------------------------
-- L6 The Big Score: Bank (par 4). Clone 1 holds A (teller desk); clones 2-4 wait
-- out of Gus's sight beside the staff door, cross the hall while he faces the east
-- wall and hide on B (fern), C and D (deposit stacks). Run 5 crosses the same way,
-- waits at the vault door for the scale, grabs the gold (Alarm Run) and leaves by
-- the loading dock (D) and the service alley to the van, then ENDs the run (the
-- level's haul is all the loot, so the banked gold clears at the end of the run).
-- Crossing windows for C/D measured (tests/sim/BigScore.spec.luau, no catch, bust
-- or zap): 5.2-7.8 s, then about every 9 s (9.4-16.8, 18.4-25.8, ...) now that the
-- staff pillar keeps the wait spot hidden; the plan crosses at 6.0.
---------------------------------------------------------------------------

local BANK_CROSS = 6.0

Solutions.bk1_big_score = function(level: any): any
	local function toStaffDoor(): { any }
		return { { go = { 0, 9 } }, { go = { 0, -7 } }, { go = { -4, -11 } } }
	end
	return {
		runs = {
			{ [1] = { { go = { 0, 9 } }, { go = { 0, -7 } }, { goPlate = "A" }, { endRun = true } } },
			{
				[1] = cat(toStaffDoor(), {
					{ waitUntil = 5.3 },
					{ go = { 0, -13 } },
					{ go = { 0, -16 } },
					{ goPlate = "B" },
					{ endRun = true },
				}),
			},
			{
				[1] = cat(toStaffDoor(), {
					{ waitUntil = BANK_CROSS },
					{ go = { 0, -13 } },
					{ go = { 0, -38 } },
					{ goPlate = "C" },
					{ endRun = true },
				}),
			},
			{
				[1] = cat(toStaffDoor(), {
					{ waitUntil = BANK_CROSS },
					{ go = { 0, -13 } },
					{ go = { 0, -38 } },
					{ goPlate = "D" },
					{ endRun = true },
				}),
			},
			{
				[1] = cat(toStaffDoor(), {
					{ waitUntil = BANK_CROSS },
					{ go = { 0, -13 } },
					{ go = { 0, -38 } },
					{ go = { 0, -46 } },
					untilOpen(level, "VaultDoor"),
					{ goLoot = "Gold" },
					{ grab = "Gold" },
					{ go = { 0, -64 } },
					{ go = { 25, -64 } },
					{ go = { 25, 12 } },
					{ go = { 3, 18 } },
					{ endRun = true },
					{ stay = true },
				}),
			},
		},
	}
end

---------------------------------------------------------------------------
-- Daily vaults (par 1-3, any vetted modifier). The goal item never moves (loot
-- modifiers move the bonus only), so a recording of these runs on the unmodified
-- layout must clear every modified day too (Daily.spec "frozen solution"); Gus is
-- watched, not timed, only to find the window on the base layout. The final run
-- ENDs after banking: a vault's haul is all its loot, so the clear comes at run end.
---------------------------------------------------------------------------

local function plateRun(plate: string): any
	return { [1] = { { goPlate = plate }, { endRun = true } } }
end

-- In through a door at z = zDoor (gap at x = 0), take `item`, back out, bank.
local function throughDoor(zDoor: number, item: string, pre: { any }?): any
	return {
		[1] = cat(pre or {}, {
			{ go = { 0, zDoor + 10 } },
			{ go = { 0, zDoor - 2 } },
			{ goLoot = item },
			{ grab = item },
			{ go = { 0, zDoor - 2 } },
			{ go = { 0, zDoor + 10 } },
			{ goVan = true },
			{ endRun = true },
			{ stay = true },
		}),
	}
end

Solutions.dv01_stocking_stuffer = function(_level: any): any
	return { runs = { plateRun("A"), throughDoor(-20, "Stocking") } }
end

Solutions.dv02_twin_chimneys = function(_level: any): any
	return { runs = { plateRun("A"), plateRun("B"), throughDoor(-20, "Present") } }
end

Solutions.dv03_candy_cane_lasers = function(_level: any): any
	return {
		runs = {
			plateRun("A"),
			{
				[1] = {
					{ wait = 1 },
					{ goLoot = "Present" },
					{ grab = "Present" },
					{ goVan = true },
					{ endRun = true },
					{ stay = true },
				},
			},
		},
	}
end

Solutions.dv04_mistletoe_patrol = function(_level: any): any
	return {
		runs = {
			plateRun("A"),
			{
				[1] = {
					{ go = { -5, -12 } }, -- beside the door, out of Gus's sight
					untilGusEast(2),
					{ go = { 0, -22 } },
					{ goLoot = "Present" },
					{ grab = "Present" },
					{ go = { 0, -22 } },
					{ go = { 0, -12 } },
					{ goVan = true },
					{ endRun = true },
					{ stay = true },
				},
			},
		},
	}
end

Solutions.dv05_tinsel_corridor = function(_level: any): any
	return {
		runs = {
			plateRun("A"),
			{ [1] = { { go = { 0, -10 } }, { go = { 0, -21 } }, { goPlate = "B" }, { endRun = true } } },
			{
				[1] = {
					{ go = { 0, -10 } },
					{ go = { 0, -32 } },
					{ goLoot = "Present" },
					{ grab = "Present" },
					{ go = { 0, -32 } },
					{ go = { 0, -10 } },
					{ goVan = true },
					{ endRun = true },
					{ stay = true },
				},
			},
		},
	}
end

-- The clone rings the bell when the runner (next run) is at the vault door.
local SWITCH_PRESS = 5.0

Solutions.dv06_snow_day_switch = function(level: any): any
	return {
		runs = {
			{
				[1] = {
					{ go = { 0, 9 } },
					{ go = { -12, -6 } },
					{ waitUntil = SWITCH_PRESS },
					{ press = "Bell" },
					{ endRun = true },
				},
			},
			{
				[1] = {
					{ go = { 0, 9 } },
					{ go = { 15, -10 } },
					{ go = { 15, -18 } },
					{ go = { 0, -42 } },
					untilOpen(level, "Vault"),
					{ go = { 0, -46 } },
					{ goLoot = "Gift" },
					{ grab = "Gift" },
					{ go = { 0, -46 } },
					{ go = { 0, -42 } },
					{ go = { 15, -18 } },
					{ go = { 15, -10 } },
					{ go = { 0, 9 } },
					{ goVan = true },
					{ endRun = true },
					{ stay = true },
				},
			},
		},
	}
end

Solutions.dv07_ornament_scale = function(_level: any): any
	return { runs = { plateRun("A"), plateRun("B"), plateRun("C"), throughDoor(-30, "Gift") } }
end

Solutions.dv08_frosty_window = function(_level: any): any
	return {
		runs = {
			plateRun("A"),
			{ [1] = { { wait = 1 }, { goPlate = "B" }, { endRun = true } } },
			throughDoor(-26, "Present", { { wait = 1 } }),
		},
	}
end

Solutions.dv09_sleigh_bell_alarm = function(_level: any): any
	return { runs = { plateRun("A"), throughDoor(-20, "Bell") } }
end

-- Plate B under the fern, then the gift: both cross the hall in Gus's blind window.
local function bankHallRuns(laserPlate: string, item: string, zDoorIn: number): { any }
	return {
		{
			[1] = {
				{ go = { 0, 9 } },
				{ go = { 0, -7 } },
				{ go = { -4, -11 } },
				untilGusEast(4),
				{ go = { 0, -13 } },
				{ go = { 0, -16 } },
				{ goPlate = laserPlate },
				{ endRun = true },
			},
		},
		{
			[1] = {
				{ go = { 0, 9 } },
				{ go = { 0, -7 } },
				{ go = { -4, -11 } },
				untilGusEast(4),
				{ go = { 0, -13 } },
				{ go = { 0, zDoorIn } },
				{ goLoot = item },
				{ grab = item },
				{ go = { 0, zDoorIn } },
				{ go = { 0, -13 } },
				{ go = { 0, 9 } },
				{ goVan = true },
				{ endRun = true },
				{ stay = true },
			},
		},
	}
end

Solutions.dv10_gingerbread_lobby = function(_level: any): any
	local hall = bankHallRuns("B", "Gift", -33)
	return { runs = { plateRun("A"), hall[1], hall[2] } }
end

Solutions.dv11_jingle_vault = function(_level: any): any
	return {
		runs = {
			plateRun("A"),
			{ [1] = { { go = { 0, 9 } }, { go = { 0, -16 } }, { goPlate = "B" }, { endRun = true } } },
			throughDoor(-36, "Gift"),
		},
	}
end

-- Par 2: plate A (staff door + half the vault), then plate B under the fern (grid
-- off + the other half), then the gift: both cross the hall in Gus's blind window.
Solutions.dv12_night_before = function(_level: any): any
	local hall = bankHallRuns("B", "Gift", -40)
	return { runs = { plateRun("A"), hall[1], hall[2] } }
end

return Solutions
