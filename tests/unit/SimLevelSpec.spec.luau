-- L1: Sim/LevelSpec validator and compiler (MASTERPLAN §8.5 "LevelSpec asserts").

local Assert = require("./Assert")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local TestLevels = require("../sim/TestLevels")

local span = LevelSpec.span

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
		for i, spec in Catalog do
			local ok, errs = LevelSpec.validate(spec)
			Assert.truthy(ok, spec.id .. ": " .. table.concat(errs, "; "))
			local level = LevelSpec.compile(spec)
			Assert.eq(level.cap, level.par + 2, spec.id .. " teaching cap = par + 2")
			Assert.eq(level.runSeconds, 30, spec.id .. " Corner Shop runs are 30 s")
			Assert.falsy(seen[level.num], "unique num")
			seen[level.num] = true
			Assert.eq(level.num, 100 + i, "num")
			Assert.truthy(string.find(spec.solution, "PLACEHOLDER", 1, true), "solution is labelled a placeholder")
		end
	end)

	test("L1-L4 match the §4.2 table (par, cap, deadline, verbs)", function()
		local l1, l2, l3, l4 =
			LevelSpec.compile(Catalog[1]),
			LevelSpec.compile(Catalog[2]),
			LevelSpec.compile(Catalog[3]),
			LevelSpec.compile(Catalog[4])
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
		s = deepCopy(Catalog[1])
		s.tutorial.autoEnd.plate = "Z"
		rejects(s, "autoEnd.plate")
	end)
end
