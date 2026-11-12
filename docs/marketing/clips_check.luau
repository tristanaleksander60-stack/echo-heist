-- docs/marketing/clips_check.luau: plays every CLIPS.md / ICON_THUMBNAILS.md shot list
-- that depends on game timing through the headless HeistSim (the tests/sim Harness),
-- so a level or Config change that breaks a shot list shows up here before the owner
-- records it. Not part of CI (marketing folder); run it after any change to
-- src/shared/Levels, src/shared/Sim or Config.Sim / Config.Levels:
--
--   lune run docs/marketing/clips_check.luau
--
-- Each check prints the beats the docs quote (times are elapsed run time, 20 Hz) and
-- exits with code 1 if one of them no longer holds. The bot steps below ARE the shot
-- lists: when a doc number changes, change it here too. Bots walk at WalkSpeed in
-- straight lines between waypoints; a human takes slightly longer, so the docs give
-- each timed step a margin. Positions are level coordinates (CLIPS.md §4).

local process = require("@lune/process")

local Harness = require("../../tests/sim/Harness")
local Solutions = require("../../tests/sim/Solutions")
local Config = require("../../src/shared/Config")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")

local HZ = Config.Rec.HZ
local failures = 0

local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("  FAIL  " .. what)
	end
end

-- Parsed event log of one run: { {t, kind, a, b, c} }.
local function events(run: any): { any }
	local out = {}
	for _, line in run.lines do
		local tick, kind, a, b, c = string.match(line, "^%s*(%d+) (%a+)%s+(%-?%d+)%s+(%-?%d+)%s+(%-?%d+)")
		if tick then
			table.insert(out, {
				t = tonumber(tick) :: number / HZ,
				kind = kind,
				a = tonumber(a),
				b = tonumber(b),
				c = tonumber(c),
			})
		end
	end
	return out
end

-- Events of `kind` (optionally with a = `a`, b = `b`).
local function find(run: any, kind: string, a: number?, b: number?): { any }
	local out = {}
	for _, e in events(run) do
		if e.kind == kind and (a == nil or e.a == a) and (b == nil or e.b == b) then
			table.insert(out, e)
		end
	end
	return out
end

local function first(run: any, kind: string, a: number?, b: number?): number?
	local list = find(run, kind, a, b)
	return if #list > 0 then list[1].t else nil
end

local function near(v: number?, target: number, tol: number): boolean
	return v ~= nil and math.abs(v - target) <= tol
end

local function fmt(v: number?): string
	return if v then string.format("%.2f", v) else "none"
end

local function runEnd(run: any): number
	local t = first(run, "RunEnd")
	return t or 0
end

-- The live actor (solo) in the sim's current run.
local function liveOf(sim: any): any
	for _, a in sim.actors do
		if a.kind == "live" then
			return a
		end
	end
	return nil
end

local function cat(...: { any }): { any }
	local out = {}
	for _, list in { ... } do
		for _, step in list do
			table.insert(out, step)
		end
	end
	return out
end

-- Waits (in the bot) until Gus is frozen in "huh?".
local function untilHuh(): any
	local step
	step = {
		decide = function(_bot: any, sim: any, _view: any, _t: number): { any }
			if sim.guards[1].mode == "Huh" then
				return {}
			end
			return { { wait = 0.05 }, step }
		end,
	}
	return step
end

local function section(name: string)
	print("\n" .. name)
end

---------------------------------------------------------------------------
-- F2-A MY CLONE BETRAYED ME (L2 Two Doors): the plate betrayal
---------------------------------------------------------------------------
do
	section("F2-A plate betrayal (L2)")
	local level = Harness.level(2)
	local minZ = math.huge
	local _, runs = Harness.play(level, {
		runs = {
			{
				[1] = {
					{ goPlate = "A" },
					{ waitUntil = 10.0 },
					{ goLoot = "TipJar" },
					{ grab = "TipJar" },
					{ waitUntil = 18 },
					{ endRun = true },
				},
			},
			{
				[1] = {
					{ go = { 0, 9 } },
					{ go = { 14, 2 } },
					{ go = { 14, -14 } },
					{ waitUntil = 9.95 },
					{ go = { 0, -18 } },
					{ go = { 0, -26 }, giveUp = 0.6 },
					{ waitUntil = 13 },
					{ endRun = true },
				},
			},
		},
	}, {
		onTick = function(sim: any)
			local a = liveOf(sim)
			if sim.runIndex == 2 and a then
				minZ = math.min(minZ, a.z)
			end
		end,
	})
	local shut = first(runs[2], "DoorShut", 1)
	print(
		string.format(
			"  door closing %s, shut %s; clone grabs the tip jar %s",
			fmt(first(runs[2], "DoorClosing", 1)),
			fmt(shut),
			fmt(first(runs[2], "Grab"))
		)
	)
	check(near(shut, 10.95, 0.25), "the back-room door shuts at about 0:10.9 after the clone steps off at 0:10.0")
	check(minZ > -19.5, "the victim is stopped at the door (never gets past z -19.5)")
	check(near(runEnd(runs[1]), 18.05, 0.1), "the traitor run ends at 0:18 (◀ ME, 20 SEC AGO is true)")
end

---------------------------------------------------------------------------
-- F2-B MY CLONE BETRAYED ME (L5 Clone Party): the till alarm (and T2)
---------------------------------------------------------------------------
local PARTY_TRAITOR = {
	{ go = { 0, 9 } },
	{ go = { -6, -4.5 } },
	{ go = { -4, -4.5 } },
	{ goLoot = "Shelf1E1" },
	{ grab = "Shelf1E1" },
	{ go = { -4, -4.5 } },
	{ go = { -6, -4.5 } },
	{ go = { 0, 9 } },
	{ goVan = true }, -- bank it: bag level 0 carries one item, the till needs empty hands
	{ go = { 0, 9 } },
	{ go = { -6, 0 } },
	{ goLoot = "Register" },
	{ waitUntil = 20.5 },
	{ grab = "Register" },
	{ go = { -7, 0.5 } },
	{ waitUntil = 22 },
	{ endRun = true },
}

do
	section("F2-B till alarm (L5)")
	local level = Harness.level(5)
	-- The old timing (grab at 0:16) is refused: the till is time-locked until 0:20.
	local _, early = Harness.play(level, {
		runs = {
			{
				[1] = {
					{ go = { 0, 9 } },
					{ go = { -6, 0 } },
					{ goLoot = "Register" },
					{ waitUntil = 16 },
					{ grab = "Register" },
					{ waitUntil = 18 },
					{ endRun = true },
				},
			},
		},
	})
	check(
		#find(early[1], "Rejected", nil, nil) > 0 and first(early[1], "AlarmOn") == nil,
		string.format(
			"a till grab at 0:16 is refused (Locked until 0:%02d): no alarm",
			Config.Levels.PARTY_TILL_OPENS_SECONDS
		)
	)
	local victim = {
		{ go = { 0, 9 } },
		{ go = { 6, -4.5 } },
		{ go = { 12.5, -4.5 } },
		{ go = { 12.5, -25 } },
		{ go = { 4, -25 } },
		{ waitUntil = 20.6 },
		{ go = { 12.5, -25 } },
		{ go = { 12.5, -4.5 } },
		{ go = { 6, -4.5 } },
		{ go = { 0, 9 } },
		{ goVan = true },
		{ stay = true },
	}
	local piggy = {
		{ go = { 0, 9 } },
		{ go = { 6, -4.5 } },
		{ go = { 12.5, -4.5 } },
		{ go = { 12.5, -25 } },
		{ go = { 4, -25 } },
		{ go = { 0, -26 } },
		{ go = { 3, -30 } },
		{ goLoot = "PiggyBank" },
		{ waitUntil = 19.0 },
		{ grab = "PiggyBank" },
		{ stay = true },
	}
	local _, runs = Harness.play(level, {
		runs = {
			{ [1] = PARTY_TRAITOR },
			{ [1] = victim },
			{ deck = { { 1, "Undo" } }, [1] = piggy },
			{ deck = { { 1, "Undo" } }, [1] = { { stay = true } } },
		},
	})
	local alarm = first(runs[1], "AlarmOn")
	print(
		string.format(
			"  till grab %s, alarm %s, traitor END %s",
			fmt(first(runs[1], "Grab", 1, 1)),
			fmt(alarm),
			fmt(runEnd(runs[1]))
		)
	)
	check(near(alarm, 20.55, 0.3), "the traitor robs the till at about 0:20.5 (alarm)")
	check(runEnd(runs[1]) <= 22.2, "the traitor ENDs by about 0:22 (22 + 1.8 s rewind rounds to 20 SEC AGO)")
	local caught = first(runs[2], "Caught")
	print(
		string.format("  back-aisle victim: chase from %s, caught %s", fmt(first(runs[2], "Chase", 1, 2)), fmt(caught))
	)
	check(first(runs[2], "AlarmOn") ~= nil and caught ~= nil, "back-aisle take: Gus chases the victim (a few seconds)")
	local pc = first(runs[3], "Caught")
	print(string.format("  piggy-bank victim: caught %s", fmt(pc)))
	check(pc ~= nil and pc - (alarm or 0) < 1, "piggy-bank take: caught within a second of the alarm")
	check(first(runs[4], "AlarmOn") ~= nil, "take 3 (stand still, film the till) still shows the clone's alarm")
end

---------------------------------------------------------------------------
-- F3 HE DOES IT EVERY TIME (L3 Lights Out)
---------------------------------------------------------------------------
do
	section("F3 zap every run (L3)")
	local level = Harness.level(3)
	local stand = { { waitUntil = 19.5 }, { endRun = true } }
	local _, runs = Harness.play(level, {
		runs = {
			{ [1] = { { goPlate = "A" }, { waitUntil = 18 }, { endRun = true } } },
			{
				[1] = {
					{ go = { 0, -23 } },
					{ goPlate = "B" },
					{ waitUntil = 15 },
					{ go = { 12, -21.5 } },
					{ waitUntil = 16 },
					{ endRun = true },
				},
			},
			{
				[1] = {
					{ go = { 0, -23 } },
					{ go = { 0, -30 } },
					{ waitUntil = 17.3 },
					{ go = { 0, -38 } },
					{ stay = true },
				},
			},
			{ [1] = stand },
			{ [1] = stand },
			{ [1] = stand },
			{
				[1] = {
					{ go = { 0, -23 } },
					{ go = { 0, -31 } },
					{ waitUntil = 5.5 },
					{ goLoot = "Register" },
					{ grab = "Register" },
					{ go = { 0, -23 } },
					{ go = { 0, 9 } },
					{ waitUntil = 19.5 },
					{ goVan = true },
					{ stay = true },
				},
			},
		},
	})
	print(string.format("  grid on again at %s (plate B released at 0:15)", fmt(first(runs[2], "LaserOn"))))
	for r = 3, 7 do
		local z = first(runs[r], "Zap")
		check(near(z, 17.55, 0.2), string.format("run %d: clone 3 zaps at about 0:17.5 (%s)", r, fmt(z)))
	end
	for r = 1, 6 do
		check(
			#find(runs[r], "Bank") == 0,
			string.format("run %d banks nothing (the register = the goal ends the heist)", r)
		)
	end
	local bank = first(runs[7], "Bank")
	check(
		#runs == 7 and bank ~= nil and bank > 17.6 and first(runs[7], "HeistComplete") ~= nil,
		"run 7 banks the register after the zap (" .. fmt(bank) .. ") and the heist completes"
	)
end

---------------------------------------------------------------------------
-- F4 WRONG ONE (L4 Night Clerk), 3 takes of the hero run (and T3)
---------------------------------------------------------------------------
do
	section("F4 wrong one, 3 takes (L4)")
	local level = Harness.level(4)
	local function hero(bank: boolean): { any }
		return cat({
			{ go = { 0, -10 } },
			{ waitUntil = 6.6 },
			{ go = { 0, -22 } },
			{ go = { 0, -37.5 } },
			{ goLoot = "NightDeposit" },
			{ grab = "NightDeposit" },
			{ go = { 1.5, -39 } },
			untilHuh(),
			{ go = { 0, -21 } },
			{ go = { 0, -10 } },
		}, if bank then { { goVan = true }, { stay = true } } else { { endRun = true } })
	end
	local sim, runs = Harness.play(level, {
		runs = {
			{ [1] = { { goPlate = "A" }, { waitUntil = 18 }, { endRun = true } } },
			{
				[1] = {
					{ go = { 0, -10 } },
					{ waitUntil = 4.2 },
					{ go = { 0, -21.5 } },
					{ goPlate = "B" },
					{ waitUntil = 18 },
					{ endRun = true },
				},
			},
			{
				[1] = {
					{ go = { 0, -10 } },
					{ waitUntil = 15.3 },
					{ go = { 0, -22 } },
					{ go = { 2, -24 } },
					{ stay = true },
				},
			},
			{ [1] = hero(false) },
			{ deck = { { 1, "Undo" } }, [1] = hero(false) },
			{ deck = { { 1, "Undo" } }, [1] = hero(true) },
		},
	})
	local decoy = first(runs[3], "Caught")
	print(
		string.format(
			"  decoy: spotted %s, ? %s, caught %s",
			fmt(first(runs[3], "Spotted", 1, 3)),
			fmt(first(runs[3], "Suspect", 1, 3)),
			fmt(decoy)
		)
	)
	check(near(decoy, 18.6, 0.3), "run 3 (decoy) is caught at about 0:18.6 (18.6 + 1.8 s rounds to 20 SEC AGO)")
	for r = 4, 6 do
		local b = first(runs[r], "Busted")
		local huh = first(runs[r], "GuardHuh")
		check(
			near(b, 18.6, 0.3) and near(huh, 18.6, 0.3) and first(runs[r], "Caught") == nil,
			string.format(
				"take %d (run %d): clone 3 busted %s, huh? %s-%s, you are not caught",
				r - 3,
				r,
				fmt(b),
				fmt(huh),
				fmt(first(runs[r], "GuardResume"))
			)
		)
	end
	check(#find(runs[4], "Bank") == 0 and #find(runs[5], "Bank") == 0, "takes 1-2 END before the van (no bank)")
	check(
		#runs == 6 and first(runs[6], "HeistComplete") ~= nil and sim.level.dawnRuns == 6,
		"take 3 is run 6 = Dawn's run: its bank completes the heist (" .. fmt(first(runs[6], "Bank")) .. ")"
	)
end

---------------------------------------------------------------------------
-- F1 RUN 1 vs RUN 8 and F5 8 OF ME (L5 Clone Party)
---------------------------------------------------------------------------
local function partyRuns(level: any, run8: { any }): { any }
	local runs = {
		{
			[1] = {
				{ go = { 0, 9 } },
				{ go = { -12, 6 } },
				{ goLoot = "WindowW" },
				{ grab = "WindowW" },
				{ go = { 0, 9 } },
				{ goVan = true },
				{ waitUntil = 12 },
				{ endRun = true },
			},
		},
	}
	for r = 1, 6 do
		local pair = Solutions.PARTY_PAIRS[r]
		local steps = {}
		Solutions.partyTrip(level, pair[1], steps)
		Solutions.partyTrip(level, pair[2], steps)
		table.insert(steps, { waitUntil = 18 })
		table.insert(steps, { endRun = true })
		table.insert(runs, { [1] = steps })
	end
	table.insert(runs, { [1] = run8 })
	return runs
end

do
	section("F1 / F5 run 1 vs run 8, 8 OF ME (L5)")
	local level = Harness.level(5)
	local steps = {}
	Solutions.partyTrip(level, "Shelf2W3", steps)
	Solutions.partyTrip(level, "Shelf2E3", steps)
	table.insert(steps, { stay = true })
	local sim, runs = Harness.play(level, { runs = partyRuns(level, steps) })
	for r = 2, 7 do
		check(runEnd(runs[r]) <= 18.1, string.format("run %d ENDs by 0:18 (%s)", r, fmt(runEnd(runs[r]))))
	end
	local swarm = find(runs[8], "Swarm")
	local sw = swarm[1]
	check(
		sw ~= nil and near(sw.t, Config.Sim.SWARM_FANOUT_SECONDS, 0.06) and sw.b == 8,
		"run 8: the 8 OF ME stamp (Swarm, 8 copies) lands at loop time " .. fmt(sw and sw.t)
	)
	local alarms = 0
	for _, r in runs do
		alarms += #find(r, "AlarmOn")
	end
	check(alarms == 0, "nobody touches the till: no alarm in any run")
	check(#runs == 8 and sim.overReason == "Dawn", "Dawn ends the heist after run 8 (no spare run for a retake)")
end

---------------------------------------------------------------------------
-- F6 POV: the night guard (L6 Big Score hall)
---------------------------------------------------------------------------
do
	section("F6 night guard POV (L6)")
	local level = Harness.level(6)
	local function toDoor(): { any }
		return { { go = { 0, 9 } }, { go = { 0, -7 } }, { go = { -4, -11 } } }
	end
	local function cross(t: number, x: number, z: number): { any }
		return cat(toDoor(), {
			{ waitUntil = t },
			{ go = { 0, -13 } },
			{ go = { x, -16 } },
			{ go = { x, z } },
			{ waitUntil = 17.5 },
			{ endRun = true },
		})
	end
	local runs = {
		{ [1] = { { go = { 0, 9 } }, { go = { 0, -7 } }, { goPlate = "A" }, { waitUntil = 18 }, { endRun = true } } },
	}
	for _, m in
		{
			{ 10.5, -6, -30 },
			{ 10.75, -4, -27 },
			{ 11.0, -2, -31 },
			{ 11.25, 0, -28 },
			{ 11.5, -5, -32 },
			{ 11.75, -1, -25.5 },
		}
	do
		table.insert(runs, { [1] = cross(m[1], m[2], m[3]) })
	end
	table.insert(runs, {
		[1] = cat(toDoor(), {
			{ waitUntil = 12.0 },
			{ go = { 0, -13 } },
			{ go = { -3, -16 } },
			{ go = { -3, -29.5 } },
			untilHuh(),
			{ go = { -3, -16 } },
			{ go = { 0, -13 } },
			{ go = { -4, -10 } },
			{ stay = true },
		}),
	})
	local sim, out = Harness.play(level, { runs = runs })
	for r = 1, 7 do
		check(
			#find(out[r], "Caught") + #find(out[r], "Busted") + #find(out[r], "AlarmOn") == 0,
			string.format("run %d: nobody caught or busted, no alarm", r)
		)
	end
	local r8 = out[8]
	local seen = {}
	for _, e in find(r8, "Spotted") do
		if e.t > 17.5 and e.t < 18.2 then
			seen[e.b] = true
		end
	end
	local n = 0
	for _ in seen do
		n += 1
	end
	local bust = first(r8, "Busted")
	print(string.format("  run 8: %d copies spotted at about 0:17.9, first bust %s", n, fmt(bust)))
	check(n == 7, "run 8: Gus turns at about 0:17.9 onto 7 copies in the hall (6 clones + you)")
	check(near(bust, 19.0, 0.3), "run 8: he busts one at about 0:19.0 (huh? freeze 2 s)")
	check(
		first(r8, "Caught") == nil and first(r8, "AlarmOn") == nil,
		"run 8: you slip out during the huh? (no catch, no alarm)"
	)
	local sw = find(r8, "Swarm")[1]
	check(sw ~= nil and sw.b == 8, "run 8 has 8 copies of you in the bank (8 OF ME); 1 stays on plate A in the lobby")
	check(sim.overReason == "Dawn", "Dawn after run 8")
end

---------------------------------------------------------------------------
-- Icon capture (L6 scale room, vault door closed)
---------------------------------------------------------------------------
do
	section("Icon capture (L6)")
	local level = Harness.level(6)
	local CROSS = 6.0 -- the measured window (Solutions / BigScore.spec): 5.2-7.8 s, 9.4-16.8 s
	local function toDoor(): { any }
		return { { go = { 0, 9 } }, { go = { 0, -7 } }, { go = { -4, -11 } } }
	end
	local function toMark(x: number, z: number, pre: { any }?): { any }
		return cat(pre or {}, toDoor(), {
			{ waitUntil = CROSS },
			{ go = { 0, -13 } },
			{ go = { 0, -38 } },
			{ go = { x, z } },
			{ waitUntil = 14 },
			{ endRun = true },
		})
	end
	local heroPos = nil
	local _, runs = Harness.play(level, {
		runs = {
			{ [1] = { { go = { 0, 9 } }, { go = { 0, -7 } }, { goPlate = "A" }, { endRun = true } } },
			{
				[1] = cat(toDoor(), {
					{ waitUntil = 5.3 },
					{ go = { 0, -13 } },
					{ go = { 0, -16 } },
					{ goPlate = "B" },
					{ endRun = true },
				}),
			},
			{ [1] = toMark(-2.4, -44.5) },
			{ [1] = toMark(-1.2, -44.0) },
			{
				[1] = {
					{ go = { 0, 9 } },
					{ go = { 0, -2 } },
					{ go = { 3, -7 } },
					{ goLoot = "Drawer" },
					{ grab = "Drawer" },
					{ go = { 3, -7 } },
					{ go = { -4, -11 } },
					{ waitUntil = CROSS },
					{ go = { 0, -13 } },
					{ go = { 0, -38 } },
					{ go = { 0, -43.5 } },
					{ waitUntil = 14 },
					{ endRun = true },
				},
			},
		},
	}, {
		onTick = function(s: any)
			local a = liveOf(s)
			if s.runIndex == 5 and a and a.present then
				heroPos = { a.x, a.z }
			end
		end,
	})
	local bad = 0
	for _, r in runs do
		bad += #find(r, "Caught") + #find(r, "Busted") + #find(r, "Zap") + #find(r, "AlarmOn")
	end
	check(bad == 0, "runs 1-5: no catch, bust, zap or alarm")
	local vault = LevelSpec.indexOf(level, "door", "VaultDoor")
	local opened = 0
	for _, r in runs do
		opened += #find(r, "DoorOpen", vault)
	end
	check(opened == 0, "the vault door stays closed (its dial is the halo)")
	check(first(runs[5], "Grab") ~= nil, "the hero carries the drawer cash (the gold glint)")
	check(
		heroPos ~= nil and math.abs(heroPos[1]) < 0.3 and math.abs(heroPos[2] + 43.5) < 0.3,
		"the hero ends on the mark (0, -43.5)"
	)
end

---------------------------------------------------------------------------
-- T1 8 OF ME (L5): 7 clones on V marks, the hero robs the till in run 8
---------------------------------------------------------------------------
do
	section("T1 swarm thumbnail (L5)")
	local level = Harness.level(5)
	local marks = { { -2.5, 0 }, { 2.5, 0 }, { -5, -2.5 }, { 5, -2.5 }, { -7.5, -5 }, { 7.5, -5 }, { 0, -4 } }
	local items = { "Shelf1E1", "Shelf2W1", "Shelf1W2", "Shelf3W1", "Shelf1E3", "Shelf3E2", "Shelf2E1" }
	local runs = {}
	for i, m in marks do
		local d = level.loot[LevelSpec.indexOf(level, "loot", items[i])]
		local lane = if d.x < -9 then -12.5 elseif d.x < -1 then -4 elseif d.x < 7 then 4 else 12.5
		table.insert(runs, {
			[1] = {
				{ go = { 0, 9 } },
				{ go = { if lane < 0 then -6 else 6, -4.5 } },
				{ go = { lane, -4.5 } },
				{ goLoot = items[i] },
				{ grab = items[i] },
				{ go = { lane, -4.5 } },
				{ go = { m[1], m[2] } },
				{ waitUntil = 12 },
				{ endRun = true },
			},
		})
	end
	table.insert(runs, {
		[1] = {
			{ go = { 0, 9 } },
			{ go = { -6, 0 } },
			{ goLoot = "Register" },
			{ waitUntil = 20.2 },
			{ grab = "Register" },
			{ go = { 0, 3 } },
			{ stay = true },
		},
	})
	local onMark, gusAt = 0, nil
	local _, out = Harness.play(level, { runs = runs }, {
		onTick = function(s: any)
			if s.runIndex == 8 and math.abs(s.t - 21.5) < 0.01 then
				for _, a in s.actors do
					if a.kind == "clone" and a.present then
						local m = marks[a.slot]
						if m and math.abs(a.x - m[1]) < 0.3 and math.abs(a.z - m[2]) < 0.3 then
							onMark += 1
						end
					end
				end
				local g = s.guards[1]
				gusAt = { g.x, g.z }
			end
		end,
	})
	local alarm = first(out[8], "AlarmOn")
	check(
		alarm ~= nil and alarm >= Config.Levels.PARTY_TILL_OPENS_SECONDS,
		"run 8: the till opens at 0:20, alarm at " .. fmt(alarm)
	)
	check(onMark == 7, string.format("at 0:21.5 all 7 clones hold their V marks (%d)", onMark))
	print(string.format("  Gus at 0:21.5: (%.1f, %.1f)", gusAt and gusAt[1] or 0, gusAt and gusAt[2] or 0))
	local sw = find(out[8], "Swarm")[1]
	check(sw ~= nil and sw.b == 8, "run 8 is 8 OF ME")
end

---------------------------------------------------------------------------
-- T2 BETRAYED! (L5): the hero at the east aisle when Gus comes up it
---------------------------------------------------------------------------
do
	section("T2 betrayal thumbnail (L5)")
	local level = Harness.level(5)
	local _, out = Harness.play(level, {
		runs = { { [1] = PARTY_TRAITOR }, { [1] = { { go = { 0, 9 } }, { go = { 4, -6 } }, { stay = true } } } },
	})
	local chase = first(out[2], "Chase", 1, 2)
	local caught = first(out[2], "Caught")
	print(
		string.format(
			"  alarm %s, Gus chases you from %s, caught %s",
			fmt(first(out[2], "AlarmOn")),
			fmt(chase),
			fmt(caught)
		)
	)
	check(
		chase ~= nil and caught ~= nil and caught > 21.5,
		"Gus comes up the aisle and reaches you about 2 s after the alarm"
	)
end

---------------------------------------------------------------------------
-- T4 16 ROBBERS (L5, a party of 4)
---------------------------------------------------------------------------
do
	section("T4 16 robbers (L5, 4 players)")
	local level = Harness.level(5)
	local runs = {}
	for r = 1, 8 do
		local run = {}
		for id = 1, 4 do
			run[id] = { { go = { (id - 2.5) * 3, 9 - r } }, { waitUntil = 2 }, { endRun = true } }
		end
		table.insert(runs, run)
	end
	local sim, out = Harness.play(level, { players = { 1, 2, 3, 4 }, runs = runs })
	local sw = find(out[8], "Swarm")[1]
	check(sim.players[1].deck.cap == 3, "each player's cap is floor(12 / 4) = 3")
	check(sw ~= nil and sw.c == 16, "run 8: 4 players + 12 clones = 16 robbers (" .. tostring(sw and sw.c) .. ")")
	check(sim.overReason == "Dawn", "Dawn after run 8 (runs 4-8 replace each player's newest clone)")
end

---------------------------------------------------------------------------
-- T5 STEAL BACK XMAS (DV04 Mistletoe Patrol)
---------------------------------------------------------------------------
do
	section("T5 seasonal thumbnail (DV04)")
	local level = LevelSpec.compile(DailyVaults.designs[4])
	local outPos, atMark = nil, nil
	local _, out = Harness.play(level, {
		runs = {
			{ [1] = { { goPlate = "A" }, { endRun = true } } },
			{
				[1] = {
					{ go = { -5, -12 } },
					Solutions.untilGusEast(2),
					{ go = { 0, -22 } },
					{ goLoot = "Ribbon" },
					{ grab = "Ribbon" },
					{ go = { 0, -22 } },
					{ go = { 1.5, -18.5 } },
					{ endRun = true },
				},
			},
			{
				[1] = {
					{ go = { -5, -12 } },
					Solutions.untilGusEast(2),
					{ go = { 0, -22 } },
					{ goLoot = "Present" },
					{ grab = "Present" },
					{ go = { 0, -22 } },
					{ go = { -1.5, -13 } },
					{ endRun = true },
				},
			},
		},
	}, {
		onTick = function(s: any)
			local a = liveOf(s)
			if s.runIndex == 3 and a and a.present then
				outPos = { a.x, a.z }
				if atMark == nil and a.carrying ~= 0 and a.z > -16 then
					atMark = s.t
				end
			end
		end,
	})
	local bad = 0
	for _, r in out do
		bad += #find(r, "Caught") + #find(r, "Busted")
	end
	check(bad == 0, "runs 1-3: nobody caught or busted")
	check(
		first(out[3], "Grab") ~= nil and outPos ~= nil and outPos[2] > -20,
		"the hero carries the Present out through the doorway"
	)
	print(
		string.format(
			"  the hero is 4 studs in front of the doorway (z -16) at %s, clone 2 holding the Ribbon behind him",
			fmt(atMark)
		)
	)
	local spotted = first(out[3], "Spotted", nil, 2)
	check(atMark ~= nil and (spotted == nil or spotted > atMark), "clone 2 is not spotted before the capture moment")
end

print(string.format("\n%s", if failures == 0 then "all shot lists hold" else failures .. " check(s) failed"))
process.exit(if failures == 0 then 0 else 1)
