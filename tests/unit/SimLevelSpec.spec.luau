-- L1: Sim/LevelSpec validator and compiler (MASTERPLAN §8.5 "LevelSpec asserts").

local Assert = require("./Assert")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local TestLevels = require("../sim/TestLevels")

local span = LevelSpec.span

-- Launch level Ln by design number (num = 100 + n): Catalog is in play order.
local function launch(n: number): any
	for _, spec in Catalog do
		if spec.num == 100 + n then
			return spec
		end
	end
	error(`no launch level L{n}`)
end

-- Play order (owner decision 2026-11-12): L1, L2, the L5 party break, L3, L4, L6.
local PLAY_ORDER = { 1, 2, 5, 3, 4, 6 }

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

-- The spec must fail with a message containing `needle`.
local function rejects(spec: any, needle: string)
	local ok, errs = LevelSpec.validate(spec)
	Assert.falsy(ok, "should be rejected: " .. needle)
	local all = table.concat(errs, " | ")
	Assert.truthy(string.find(all, needle, 1, true), "expected '" .. needle .. "' in: " .. all)
end

return function(test)
	test("every launch level validates and compiles", function()
		local seen = {}
		Assert.eq(#Catalog, 6, "six launch levels (§4.2)")
		for i, spec in Catalog do
			local ok, errs = LevelSpec.validate(spec)
			Assert.truthy(ok, spec.id .. ": " .. table.concat(errs, "; "))
			local level = LevelSpec.compile(spec)
			if level.num <= 104 then
				Assert.eq(level.cap, level.par + 2, spec.id .. " teaching cap = par + 2")
			else
				Assert.eq(level.cap, Config.Sim.MAX_LEVEL_CAP, spec.id .. " Clone Party / Big Score grant 8")
			end
			local runLen = if spec.location == "Bank" then Config.Levels.BANK_RUN_SECONDS else 30
			Assert.eq(level.runSeconds, runLen, spec.id .. " run length by location (§3.1)")
			Assert.falsy(seen[level.num], "unique num")
			seen[level.num] = true
			Assert.eq(level.num, 100 + PLAY_ORDER[i], spec.id .. " num = design number, Catalog = play order")
			Assert.truthy(string.find(spec.solution, "PLACEHOLDER", 1, true), "solution is labelled a placeholder")
		end
	end)

	test("launch levels line up with the data layer (Config.Data.Levels)", function()
		local DATA = Config.Data
		Assert.eq(#DATA.LEVEL_ORDER, #Catalog, "same count")
		for i, spec in Catalog do
			Assert.eq(spec.dataId, DATA.LEVEL_ORDER[i], spec.id .. " dataId in play order")
			local rules = DATA.Levels[spec.dataId]
			Assert.truthy(rules, spec.id .. " has data rules")
			Assert.eq(rules.cap, spec.cap, spec.id .. " cap")
			Assert.eq(rules.kind, spec.kind or "story", spec.id .. " kind")
			if rules.parClones then
				Assert.eq(rules.parClones, spec.par, spec.id .. " par")
			end
		end
		-- The new levels' medal numbers are the data layer's (L1-L4's goal vs haulTarget
		-- placeholders differ there; reported, not changed here).
		local party, bank = launch(5), launch(6)
		local tiers = DATA.Levels.CloneParty.haulTiers
		Assert.eq(#party.tiers, #tiers, "three Haul tiers")
		for k = 1, #tiers do
			Assert.eq(party.tiers[k], tiers[k], "Clone Party tier " .. k)
		end
		Assert.eq(bank.goal, DATA.Levels.BigScoreBank.haulTarget, "Big Score goal = haulTarget")
	end)

	test("L5 and L6 match the §4.2 table (slots, Dawn, Alarm Run, scale vault)", function()
		local l5, l6 = LevelSpec.compile(launch(5)), LevelSpec.compile(launch(6))
		Assert.eq(l5.kind, "party", "Clone Party is a party level")
		Assert.eq(l5.cap, 8, "8 slots")
		Assert.eq(l5.dawnRuns, 8, "Dawn at run 8")
		Assert.eq(l5.runSeconds, 30, "after hours: 30 s")
		Assert.truthy(l5.bags, "bag levels count in Clone Party")
		Assert.truthy(l5.alarm ~= nil and l5.loot[l5.alarm.trigger].id == "Register", "Alarm Run on the till")
		local respawning = 0
		for _, item in l5.loot do
			if item.respawn then
				respawning += 1
			end
		end
		Assert.eq(respawning, #l5.loot, "every Clone Party item comes back")
		local till = l5.loot[l5.alarm.trigger]
		Assert.eq(till.opensAt, Config.Levels.PARTY_TILL_OPENS_SECONDS, "the till is time-locked until 0:20")
		Assert.truthy(till.opensAt + l5.alarm.lockSeconds < l5.runSeconds, "its shutter drops inside the run")
		Assert.truthy(till.opensAt + l5.alarm.vanSeconds >= l5.runSeconds, "the van timer outlasts the run")
		for _, l in { l5, l6 } do
			Assert.truthy(l.spec.lineup ~= nil, l.id .. " has its own Crew Line-up spot")
			Assert.truthy(l.lineup.z > l.van.maxZ and l.lineup.fz > 0.99, l.id .. " line-up on the street, facing out")
		end
		Assert.eq(l6.kind, "story", "the Big Score is a story level")
		Assert.eq(l6.par, 4, "par 4")
		Assert.eq(l6.cap, 8, "8 slots")
		Assert.eq(l6.runSeconds, 45, "Bank: 45 s")
		Assert.eq(l6.dawnRuns, LevelSpec.dawnRunsFor(4), "Dawn at par + 4")
		Assert.eq(l6.dawnRuns, 8, "= run 8")
		Assert.truthy(l6.alarm ~= nil and l6.alarm.onCatch, "Big Score: a catch trips the alarm too")
		local vault = l6.doors[LevelSpec.indexOf(l6, "door", "VaultDoor")]
		Assert.eq(vault.need, "all", "scale vault needs every plate")
		Assert.eq(#vault.openBy, 4, "4 actors on 4 plates")
		Assert.eq(#l6.guards, 1, "Gus patrols")
		Assert.truthy(#l6.lasers >= 1 and #l6.hides >= 4, "lasers and hide spots (L3, L4)")
		local locks = 0
		for _, d in l6.doors do
			locks += if d.alarmLock then 1 else 0
		end
		Assert.eq(locks, 2, "LOCKDOWN: front doors and the loading dock")
		-- No launch level uses heavy loot or keycards (§10.4 cut list).
		for _, spec in Catalog do
			for _, item in spec.loot do
				Assert.eq(item.heavy, nil, spec.id .. " no heavy loot at launch")
			end
		end
	end)

	test("party, bags, guardVision, dataId and lineup are validated", function()
		local party = deepCopy(launch(5))
		Assert.truthy((LevelSpec.validate(party)), "Clone Party is valid")
		local s = deepCopy(party)
		s.tiers = nil
		rejects(s, "needs tiers")
		s = deepCopy(party)
		s.tiers = { 1000, 900 }
		rejects(s, "above the previous tier")
		s = deepCopy(party)
		s.dawnRuns = nil
		rejects(s, "needs dawnRuns")
		s = deepCopy(party)
		s.haul = 9000
		rejects(s, "not haul")
		s = TestLevels.corridorSpec()
		s.tiers = { 10 }
		rejects(s, "only for party levels")
		s = TestLevels.corridorSpec()
		s.kind = "boss"
		rejects(s, "kind must be")
		s = TestLevels.corridorSpec()
		s.bags = 2
		rejects(s, "bags must be")
		s = TestLevels.corridorSpec()
		s.guardVision = 3
		rejects(s, "guardVision")
		s = TestLevels.corridorSpec()
		s.dataId = ""
		rejects(s, "dataId")
		s = TestLevels.corridorSpec()
		s.lineup = { x = 0 }
		rejects(s, "lineup")
		s = TestLevels.corridorSpec()
		s.loot[1].opensAt = s.runSeconds
		rejects(s, "opensAt")
		s = TestLevels.corridorSpec()
		s.loot[1].opensAt = -1
		rejects(s, "opensAt")
		-- Compiled defaults.
		local c = TestLevels.corridor()
		Assert.eq(c.kind, "story", "default kind")
		Assert.falsy(c.bags, "no bags by default")
		Assert.eq(c.visionMult, 1, "full vision")
		Assert.near(c.lineup.z, c.van.maxZ + Config.Sim.LINEUP_STREET_GAP, 1e-9, "line-up on the street side")
		Assert.near(c.lineup.yaw, math.pi, 1e-9, "facing +Z, toward a street camera")
		Assert.near(c.lineup.fz, 1, 1e-9, "forward +Z")
		Assert.near(c.lineup.dx, 1, 1e-9, "record order left to right for that camera (+X)")
		local p = LevelSpec.compile(party)
		Assert.eq(p.goal, 1000, "party goal defaults to tier 1")
		Assert.eq(LevelSpec.dawnRunsFor(1), Config.Sim.DAWN_MIN_RUNS, "Dawn minimum")
		Assert.eq(LevelSpec.dawnRunsFor(4), 4 + Config.Sim.DAWN_RUNS_OVER_PAR, "Dawn par + 4")
	end)

	test("L1-L4 match the §4.2 table (par, cap, deadline, verbs)", function()
		local l1, l2, l3, l4 =
			LevelSpec.compile(launch(1)),
			LevelSpec.compile(launch(2)),
			LevelSpec.compile(launch(3)),
			LevelSpec.compile(launch(4))
		Assert.eq(l1.par, 1, "L1 par")
		Assert.eq(l1.cap, 3, "L1 cap")
		Assert.truthy(l1.tutorial and l1.tutorial.autoEnd and l1.tutorial.autoEnd.runs[1], "L1 run 1 auto-ends")
		Assert.eq(#l2.plates, 2, "L2 two plates")
		Assert.eq(#l3.lasers, 1, "L3 laser grid")
		Assert.eq(#l4.guards, 1, "L4 Gus")
		Assert.truthy(#l4.hides >= 1, "L4 hiding spots")
		Assert.eq(l4.deadline, "Dawn", "L4 first Dawn")
		Assert.eq(l4.dawnRuns, math.max(Config.Sim.DAWN_MIN_RUNS, 2 + Config.Sim.DAWN_RUNS_OVER_PAR), "L4 dawn runs")
		for _, l in { l1, l2, l3 } do
			Assert.eq(l.deadline, "None", l.id .. " no deadline")
			Assert.eq(l.dawnRuns, nil, l.id .. " no dawn")
		end
	end)

	test("compile indexes ids, expands plates, builds links and the nav graph", function()
		local level = TestLevels.corridor()
		Assert.eq(LevelSpec.indexOf(level, "loot", "Free"), 2, "loot index")
		Assert.eq(level.doors[3].need, "all", "need all")
		Assert.eq(#level.doors[3].openBy, 2, "two sources")
		Assert.eq(level.doors[2].openBy[1].kind, "switch", "switch source")
		Assert.near(level.plates[1].box.minX, 8 - Config.Sim.PLATE_TOLERANCE, 1e-9, "plate tolerance")
		local ok = pcall(LevelSpec.indexOf, level, "loot", "Nope")
		Assert.falsy(ok, "unknown id errors")
		local alarm = TestLevels.alarm()
		Assert.eq(alarm.alarm.trigger, 1, "alarm trigger index")
		Assert.eq(#alarm.nav.nodes, 8, "nav nodes")
		-- (0,-25) -> (0,-50) crosses the vault's inner wall: no edge.
		for _, e in alarm.nav.edges[3] do
			Assert.truthy(e.to ~= 8, "no edge through the wall")
		end
		-- (0,-10) -> (0,-25) passes the shutter: the edge lists that door.
		local found = false
		for _, e in alarm.nav.edges[2] do
			if e.to == 3 then
				found = #e.doors == 1
			end
		end
		Assert.truthy(found, "edge through the shutter lists the door")
	end)

	test("compileRoute: timed legs, dwell facing, closed loop", function()
		local r = LevelSpec.compileRoute({
			{ x = 0, z = 0, wait = 1 },
			{ x = 8, z = 0, wait = 2, face = 90 },
		}, 8)
		Assert.eq(#r.legs, 2, "two legs")
		Assert.near(r.legs[1].tArrive, 1, 1e-12, "8 studs at 8 studs/s")
		Assert.near(r.legs[1].tEnd, 3, 1e-12, "then 2 s dwell")
		Assert.near(r.legs[1].yawDwell, math.pi / 2, 1e-12, "face 90")
		Assert.near(r.period, 1 + 2 + 1 + 1, 1e-12, "period")
	end)

	test("validator rejects broken wiring and geometry", function()
		local base = TestLevels.corridorSpec()
		Assert.truthy((LevelSpec.validate(base)), "base is valid")

		local s = deepCopy(base)
		s.plates[2].id = "P"
		rejects(s, "duplicate id")

		s = deepCopy(base)
		s.doors[1].openBy = { "Nope" }
		rejects(s, "unknown source")

		s = deepCopy(base)
		s.lasers[1].offBy = { "P" }
		s.doors[3].openBy = { "P" }
		rejects(s, "opens nothing")

		s = deepCopy(base)
		s.par = 5
		rejects(s, "exceeds cap")

		s = deepCopy(base)
		s.goal = 1000
		rejects(s, "more than all the loot")

		s = deepCopy(base)
		s.runSeconds = 120
		rejects(s, "runSeconds")

		s = deepCopy(base)
		s.bounds = span(-3000, -5, -50, 30, 25, 30)
		rejects(s, "exceed")

		s = deepCopy(base)
		s.deadline = "Alarm"
		rejects(s, "needs an alarm table")

		s = deepCopy(base)
		s.dawnRuns = 6
		rejects(s, "deadline is None")

		s = deepCopy(base)
		s.loot[1].x, s.loot[1].z = 4, -20 -- inside the corridor wall
		rejects(s, "inside a solid")

		s = deepCopy(base)
		s.doors[1].need = "most"
		rejects(s, "need must be any or all")
	end)

	test("validator checks reachability with doors open", function()
		local s = TestLevels.corridorSpec()
		-- Seal the corridor at z = -36: the Prize behind it becomes unreachable.
		table.insert(s.solids, { box = span(-3.5, 0, -36.5, 3.5, 12, -35.5) })
		rejects(s, "loot Prize is not reachable")
	end)

	test("validator checks guard routes", function()
		local s = TestLevels.watchSpec({
			route = { { x = 0, z = -20, wait = 1 }, { x = 0, z = 0, wait = 1 } },
		})
		rejects(s, "crosses a solid")
		s = TestLevels.watchSpec({ route = { { x = 0, z = 0 } } })
		rejects(s, "at least 2 points")
		s = TestLevels.watchSpec({ route = { { x = 0, z = 0 }, { x = 0, z = 0 } } })
		rejects(s, "zero length")
		s = TestLevels.alarmSpec()
		s.guards[1].route = { { x = 0, z = -10 }, { x = 0, z = -28 } }
		rejects(s, "walks through door")
	end)

	test("validator checks the alarm and the tutorial", function()
		local s = TestLevels.alarmSpec()
		s.alarm.trigger = "Nope"
		rejects(s, "alarm.trigger")
		s = TestLevels.alarmSpec()
		s.guards = nil
		rejects(s, "needs a guard")
		s = deepCopy(launch(1))
		s.tutorial.autoEnd.plate = "Z"
		rejects(s, "autoEnd.plate")
	end)
end
