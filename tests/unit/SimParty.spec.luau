-- L1: party levels, bag levels and the view hooks (MASTERPLAN §3.2 rule 8, §4.2
-- Clone Party "8 OF ME", §5.1 bag levels, §5.2 Haul tiers).

local Assert = require("./Assert")
local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local DailyVault = require("../../src/shared/Data/DailyVault")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Loot = require("../../src/shared/Sim/Loot")
local Progress = require("../../src/shared/Data/Progress")
local Scoring = require("../../src/shared/Sim/Scoring")
local Harness = require("../sim/Harness")
local TestLevels = require("../sim/TestLevels")

local EV = EventLog.EV
local KIND = Codec.EVENT

local function actor(id: number): any
	return { id = id, carrying = 0, bag = {}, capacity = 3, x = 1, y = 3, z = 2, present = true }
end

-- One run: walk to each trinket, grab it, then to the van.
local function grabAll(items: { string }): { any }
	local steps: { any } = {}
	for _, id in items do
		table.insert(steps, { goLoot = id })
		table.insert(steps, { grab = id })
	end
	table.insert(steps, { goVan = true })
	table.insert(steps, { stay = true })
	return steps
end

return function(test)
	test("Loot: an actor carries its first item plus a bag, drops and banks all of it", function()
		local level = TestLevels.party()
		local state = Loot.new(level)
		local log = EventLog.new()
		local a = actor(1)
		Assert.eq(Loot.count(a), 0, "empty hands")
		Loot.take(state, 2, a)
		Loot.take(state, 3, a)
		Assert.eq(a.carrying, 2, "first item")
		Assert.eq(Loot.count(a), 2, "two carried")
		Assert.eq(table.concat(Loot.carried(a), ","), "2,3", "grab order")
		a.x, a.z = 5, 6
		Loot.follow(state, { a })
		Assert.eq(state.items[3].x, 5, "bag item follows")
		Loot.drop(state, a, log, 7)
		Assert.eq(Loot.count(a), 0, "dropped everything")
		Assert.eq(EventLog.count(log, EV.Drop), 2, "one Drop per item")
		Assert.eq(state.items[2].state, "Dropped", "first dropped")
		Assert.eq(state.items[3].z, 6, "where the carrier was")
		Loot.take(state, 2, a)
		Loot.take(state, 3, a)
		Assert.eq(Loot.bank(state, a, 1), 20, "banked the sum")
		Assert.eq(Loot.count(a), 0, "hands free")
		Assert.eq(state.items[2].respawnAt, 3, "respawn timer per item")
	end)

	test("bag levels: capacity 1 + bag level in a `bags` level, 1 elsewhere", function()
		local party = TestLevels.party()
		local corridor = TestLevels.corridor()
		Assert.eq(HeistSim.carryFor(party, 0), 1, "no bag")
		Assert.eq(HeistSim.carryFor(party, 2), 1 + 2 * Config.Data.Bag.EXTRA_CARRY_PER_LEVEL, "bag 2")
		Assert.eq(HeistSim.carryFor(corridor, 3), 1, "bags do not count outside Clone Party")
		local sim = HeistSim.new(party)
		Assert.truthy(HeistSim.addPlayer(sim, 1, { bag = 9 }), "seated")
		Assert.eq(sim.playerById[1].bag, Config.Data.Bag.MAX_LEVEL, "bag level clamped")
	end)

	test("a bag-2 player grabs three trinkets, the fourth grab is refused, all bank at once", function()
		local level = TestLevels.party()
		local sim = HeistSim.new(level)
		HeistSim.addPlayer(sim, 1, { bag = 2 })
		-- A fourth grab while full: refused as Busy (T4 stays on its shelf).
		local steps = grabAll({ "T1", "T2", "T3", "T4" })
		HeistSim.startRun(sim)
		local Bot = require("../sim/Bot")
		local run = Harness.runOnce(sim, { Bot.new(level, 1, steps) }, Harness.history())
		Assert.eq(EventLog.count(run.log, EV.Grab), 3, "three grabs")
		local busy = 0
		for i = 1, run.log.n do
			if run.log.kind[i] == EV.Rejected and run.log.b[i] == KIND.Grab then
				busy += if run.log.c[i] == HeistSim.FAIL.Busy then 1 else 0
			end
		end
		Assert.eq(busy, 1, "fourth grab refused: bag full")
		Assert.eq(EventLog.count(run.log, EV.Bank), 3, "three items banked")
		-- The three Bank events land on one tick, in grab order, with running totals.
		local t, items, totals = nil, {}, {}
		for i = 1, run.log.n do
			if run.log.kind[i] == EV.Bank then
				t = t or run.log.tick[i]
				Assert.eq(run.log.tick[i], t, "same tick")
				table.insert(items, run.log.b[i])
				table.insert(totals, run.log.c[i])
			end
		end
		Assert.eq(table.concat(items, ","), "2,3,4", "grab order")
		Assert.eq(table.concat(totals, ","), "10,20,30", "running total")
		Assert.eq(EventLog.count(run.log, EV.Tier, 1), 1, "Haul1 reached")
	end)

	test("a clone replays with its owner's bag (3 items, one trip)", function()
		local level = TestLevels.party()
		local sim = HeistSim.new(level)
		HeistSim.addPlayer(sim, 1, { bag = 2 })
		local Bot = require("../sim/Bot")
		local hist = Harness.history()
		HeistSim.startRun(sim)
		Harness.runOnce(sim, { Bot.new(level, 1, grabAll({ "T1", "T2", "T3" })) }, hist)
		HeistSim.startRun(sim)
		local run2 = Harness.runOnce(sim, { Bot.new(level, 1, { { go = { -12, 12 } }, { stay = true } }) }, hist)
		Assert.eq(EventLog.count(run2.log, EV.Grab, 1), 3, "the clone (actor 1) grabs all three")
		Assert.eq(EventLog.count(run2.log, EV.Shrug), 0, "no shrugs: same capacity")
		Assert.eq(EventLog.count(run2.log, EV.Bank, 1), 3, "and banks them")
	end)

	test("party levels never complete: tiers, Dawn, result shapes for the data layer", function()
		local level = TestLevels.party()
		-- Run r takes trinket r; every clone keeps taking its own: 10 + 20 + 30 = 60.
		local runs = {}
		for r = 1, 3 do
			table.insert(runs, { [1] = grabAll({ "T" .. r }) })
		end
		local sim, out = Harness.play(level, { runs = runs })
		Assert.eq(#out, 3, "played until Dawn although Haul1 was met in run 2")
		Assert.eq(sim.banked, 60, "10 + 20 + 30")
		Assert.eq(sim.phase, "Over", "over")
		Assert.eq(sim.overReason, "Dawn", "at Dawn")
		Assert.eq(EventLog.count(out[3].log, EV.HeistComplete), 0, "a party never completes")
		local r = HeistSim.result(sim)
		Assert.eq(r.kind, "party", "kind")
		Assert.truthy(r.complete, "cleared = Haul1")
		Assert.eq(r.tierMet, 2, "two tiers")
		Assert.eq(r.stars.count, 2, "Haul1 + Haul2")
		Assert.truthy(r.stars.tiers[1] and r.stars.tiers[2] and not r.stars.tiers[3], "tier flags")
		local tierEvents = 0
		for _, run in out do
			tierEvents += EventLog.count(run.log, EV.Tier)
		end
		Assert.eq(tierEvents, 2, "each tier logged once")
		local rules = { kind = "party", haulTiers = level.tiers, maxHaul = 100000, cap = 8 }
		Assert.truthy((Progress.validateResult(rules, r.data)), "Progress.HeistResult shape")
		local ev = Progress.evaluate(rules, r.data)
		Assert.truthy(ev.medals.Haul1 and ev.medals.Haul2 and not ev.medals.Haul3, "same medals as the data layer")
		Assert.truthy((DailyVault.validateResult(r.daily)), "DailyVault.DailyResult shape")
	end)

	test("Scoring.partyStars: one Star per tier, none when tainted", function()
		local s = Scoring.partyStars(2600, { 1000, 2500, 5000 }, false)
		Assert.eq(s.count, 2, "two tiers")
		Assert.truthy(s.haul, "Haul1 = cleared")
		Assert.falsy(s.crew or s.clean, "no Crew/Clean in a party")
		Assert.eq(Scoring.partyStars(9999, { 1000, 2500, 5000 }, true).count, 0, "tainted")
	end)

	test("Swarm event and ofMe: 6+ own clones log the swarm, with the live copy counted", function()
		local level = TestLevels.party()
		local runs = {}
		for _ = 1, 7 do
			table.insert(runs, { [1] = { { goLoot = "T1" }, { wait = 2 }, { endRun = true } } })
		end
		local spec = TestLevels.partySpec()
		spec.dawnRuns = 8
		level = LevelSpec.compile(spec)
		local swarm = {}
		local sim, out = Harness.play(level, { runs = runs }, {
			onTick = function(s: any)
				if s.tick == 0 then
					table.insert(swarm, HeistSim.ofMe(s, 1))
				end
			end,
		})
		Assert.eq(EventLog.count(out[6].log, EV.Swarm), 0, "run 6: 5 clones, no swarm yet")
		Assert.eq(EventLog.count(out[7].log, EV.Swarm, 1, 7), 1, "run 7: 6 clones + you = 7")
		Assert.eq(
			EventLog.firstTick(out[7].log, EV.Swarm),
			math.ceil(Config.Sim.SWARM_FANOUT_SECONDS * Config.Rec.HZ),
			"after the tape-print fan-out, not at tick 0 (everyone on one spawn)"
		)
		local i = 0
		for k = 1, out[7].log.n do
			if out[7].log.kind[k] == EV.Swarm then
				i = k
			end
		end
		Assert.eq(out[7].log.c[i], 7, "c = the crew's copies (solo: the same 7)")
		Assert.eq(swarm[7], 7, "ofMe at the start of run 7")
		Assert.eq(HeistSim.ofMe(sim, 1), 0, "0 between runs")
	end)

	test("Crew Line-up: every clone in record order, then the players, 60 ms apart", function()
		local level = TestLevels.party()
		local sim = HeistSim.new(level, { players = { 1, 2 } })
		local Bot = require("../sim/Bot")
		local hist = Harness.history()
		for _ = 1, 2 do
			HeistSim.startRun(sim)
			Harness.runOnce(sim, {
				Bot.new(level, 1, { { goLoot = "T1" }, { endRun = true } }),
				Bot.new(level, 2, { { goLoot = "T3" }, { endRun = true } }),
			}, hist)
		end
		HeistSim.removePlayer(sim, 2) -- an orphan: clones stay in the line-up, the player does not
		local lineup = HeistSim.lineup(sim)
		Assert.eq(#lineup, 5, "4 clones + the one player left")
		local order = {}
		for i, e in lineup do
			table.insert(order, string.format("%s%d.%d", e.kind, e.seat, e.slot))
			Assert.near(e.delay, (i - 1) * Config.Sim.LINEUP_STAGGER, 1e-9, "stagger")
		end
		Assert.eq(table.concat(order, " "), "clone1.1 clone2.1 clone1.2 clone2.2 player1.0", "record order")
		Assert.near(lineup[1].z, level.lineup.z, 1e-9, "first row on the street side of the van")
		Assert.truthy(lineup[1].z > level.van.maxZ, "behind the van, not in front of the shop wall")
		Assert.near(lineup[2].x - lineup[1].x, Config.Sim.LINEUP_SPACING, 1e-9, "spaced along the row")
		local x0 = 0
		for _, e in lineup do
			x0 += e.x
		end
		Assert.near(x0 / #lineup, level.lineup.x, 1e-9, "row centred")
	end)

	test("time-locked loot: a grab before opensAt is refused as Locked, a clone replays the late grab", function()
		local spec = TestLevels.partySpec()
		spec.loot[2].opensAt = 10 -- T1, by the spawn
		local level = LevelSpec.compile(spec)
		Assert.eq(level.loot[2].opensAt, 10, "compiled")
		local id = level.loot[2].id
		local _, out = Harness.play(level, {
			runs = {
				{
					[1] = {
						{ goLoot = id },
						{ grab = id },
						{ waitUntil = 10 },
						{ grab = id },
						{ goVan = true },
						{ stay = true },
					},
				},
				{ [1] = { { go = { -12, 12 } }, { stay = true } } },
			},
		})
		local locked = 0
		for i = 1, out[1].log.n do
			if out[1].log.kind[i] == EV.Rejected and out[1].log.c[i] == HeistSim.FAIL.Locked then
				locked += 1
			end
		end
		Assert.eq(locked, 1, "the early grab is refused")
		Assert.eq(EventLog.count(out[1].log, EV.Grab, 1, 2), 1, "the late grab works")
		Assert.eq(EventLog.count(out[2].log, EV.Grab, 1, 2), 1, "the clone replays only the accepted grab")
		Assert.eq(EventLog.count(out[2].log, EV.Shrug), 0, "and never shrugs at the lock")
	end)

	test("lastRun.alarm: a clone that trips the alarm early earns the Redo hint", function()
		local level = TestLevels.alarm()
		local _, out = Harness.play(level, {
			runs = {
				{
					[1] = {
						{ go = { 0, -25 } },
						{ go = { 16, -30 } },
						{ go = { 16, -45 } },
						{ goLoot = "Diamond" },
						{ grab = "Diamond" },
						{ stay = true },
					},
				},
				{ [1] = { { stay = true } } },
			},
		})
		local a1, a2 = out[1].alarm, out[2].alarm
		Assert.truthy(a1 and a1.kind == "live" and a1.slot == 0, "run 1: you tripped it")
		Assert.eq(a1 and a1.hint, nil, "no hint for your own grab")
		Assert.truthy(a2 and a2.kind == "clone" and a2.slot == 1 and a2.ownerId == 1, "run 2: clone #1 did")
		Assert.truthy(a2 and a2.t < Config.Sim.ALARM_HINT_SECONDS, "early")
		Assert.eq(a2 and a2.hint, "RedoAlarm", "Clone #1 sets off the alarm: Redo #1?")
		Assert.near(a2 and a2.t or -1, a1 and a1.t or -2, 1e-9, "at the same second")
	end)

	test("co-op Clone Party: per-player clones pass the data rules; crews of 3 log SwarmSeen", function()
		local level = Harness.level(5)
		local function crewPlay(ids: { number }, runs: number): (any, { any })
			local plan = { players = ids, runs = {} }
			for r = 1, runs do
				local run: any = {}
				for k, id in ids do
					run[id] = if r == 1 and k == 1
						then { { go = { -13, 4 } }, { grab = "WindowW" }, { goVan = true }, { stay = true } }
						else { { stay = true } }
				end
				table.insert(plan.runs, run)
			end
			return Harness.play(level, plan)
		end
		-- Two players: cap min(8, 12 / 2) = 6 each, 12 clones in the crew by Dawn.
		local sim, out = crewPlay({ 1, 2 }, level.dawnRuns)
		local r = HeistSim.result(sim)
		Assert.eq(sim.cap, 6, "6 slots each")
		Assert.eq(r.reason, "Dawn", "Dawn")
		Assert.eq(r.clonesUsed, 12, "the crew's swarm: 12 clones")
		Assert.eq(r.clonesPerPlayer, 6, "one player's swarm: 6")
		Assert.eq(r.data.clones, 6, "data.clones is per player")
		-- HeistService.levelRules passes party rules through unchanged (cap 8).
		local rules = Config.Data.Levels.CloneParty
		local ok, why = Progress.validateResult(rules, r.data)
		Assert.truthy(ok, "Progress accepts a co-op Clone Party: " .. tostring(why))
		Assert.eq(EventLog.count(out[7].log, EV.Swarm, 1, 7), 1, "seat 1: 6 own clones + you")
		Assert.eq(EventLog.count(out[7].log, EV.Swarm, 2, 7), 1, "seat 2 too")
		-- Three players: 4 slots each, never 6 own clones, but 6 crew clones by run 3.
		local _, out3 = crewPlay({ 1, 2, 3 }, 3)
		for seat = 1, 3 do
			Assert.eq(EventLog.count(out3[3].log, EV.Swarm, seat, 3), 1, "seat " .. seat .. ": SwarmSeen from the crew")
		end
		for i = 1, out3[3].log.n do
			if out3[3].log.kind[i] == EV.Swarm then
				Assert.eq(out3[3].log.c[i], 9, "c = 6 crew clones + 3 players")
			end
		end
		Assert.eq(EventLog.count(out3[2].log, EV.Swarm), 0, "run 2: 3 crew clones, not yet")
	end)
end
