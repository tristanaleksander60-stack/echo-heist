-- Small purpose-built LevelSpecs for focused sim tests (not a spec itself).
-- Logic fixtures only; the launch levels live in src/shared/Levels.

local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Shop = require("../../src/shared/Levels/Shop")

local span = LevelSpec.span
local TestLevels = {}

local function base(id: string, num: number): any
	return {
		format = 1,
		version = 1,
		id = id,
		num = num,
		name = id,
		runSeconds = 30,
		par = 1,
		cap = 4,
		deadline = "None",
		seed = num,
		spawns = { { x = 0, y = 3, z = 10 }, { x = -3, y = 3, z = 10 }, { x = 3, y = 3, z = 10 } },
		van = span(-5, 0, 14, 5, 7, 20),
	}
end

-- A corridor running toward -Z: door D1 (plate P) at z = -15, laser Grid (plate Q)
-- at z = -25, door D2 (switch S toggle, or timed switch T) at z = -32, Prize at the
-- end. Door D4 off to the side needs P AND Q. Free loot by the spawn.
function TestLevels.corridorSpec(): any
	local s = base("t_corridor", 901)
	s.goal = 100
	s.bounds = span(-30, -5, -50, 30, 25, 30)
	s.solids = {
		{ box = span(-4.5, 0, -40, -3.5, 12, 0) },
		{ box = span(3.5, 0, -40, 4.5, 12, 0) },
		{ box = span(-4.5, 0, -41, 4.5, 12, -40) },
	}
	s.plates = {
		{ id = "P", box = span(8, 0, -7, 12, 6, -3) },
		{ id = "Q", box = span(-12, 0, -7, -8, 6, -3) },
	}
	s.switches = {
		{ id = "S", x = 10, y = 3, z = 5 },
		{ id = "T", x = -10, y = 3, z = 5, duration = 3 },
	}
	s.doors = {
		{ id = "D1", box = span(-3.5, 0, -15.5, 3.5, 10, -14.5), openBy = { "P" } },
		{ id = "D2", box = span(-3.5, 0, -32.5, 3.5, 10, -31.5), openBy = { "S", "T" } },
		{ id = "D4", box = span(18, 0, -10.5, 24, 10, -9.5), openBy = { "P", "Q" }, need = "all" },
	}
	s.lasers = {
		{ id = "Grid", box = span(-3.5, 0, -25.5, 3.5, 10, -24.5), offBy = { "Q" } },
	}
	s.loot = {
		{ id = "Prize", x = 0, y = 3, z = -38, value = 100 },
		{ id = "Free", x = 5, y = 3, z = 5, value = 10 },
	}
	return s
end

function TestLevels.corridor(): any
	return LevelSpec.compile(TestLevels.corridorSpec())
end

-- An open room with Gus standing at (0, 0) staring toward -Z for the whole run
-- (a two-point route with long waits). A pillar occludes (0, -10) +- 2; a low
-- counter at x -10..-6, z -12..-10 does not occlude; a hide box at (8, -10).
function TestLevels.watchSpec(opts: any?): any
	local o = opts or {}
	local s = base("t_watch", 902)
	s.goal = 10
	s.bounds = span(-40, -5, -40, 40, 25, 40)
	s.solids = {
		{ box = span(-1, 0, -16, 1, 12, -14) },
		{ box = span(-10, 0, -12, -6, 3, -10), sight = false },
	}
	s.hides = { { id = "Plant", box = span(6, 0, -12, 10, 7, -8) } }
	s.guards = {
		{
			id = "Gus",
			route = o.route or {
				{ x = 0, z = 0, wait = 60, face = 0 },
				{ x = 0, z = 0, wait = 60, face = 0 },
			},
		},
	}
	s.loot = { { id = "Gem", x = 20, y = 3, z = 20, value = 10 } }
	s.spawns = { { x = 25, y = 3, z = 25 }, { x = 22, y = 3, z = 25 } }
	s.van = span(20, 0, 28, 30, 7, 34)
	return s
end

function TestLevels.watch(opts: any?): any
	return LevelSpec.compile(TestLevels.watchSpec(opts))
end

-- An Alarm Run level: a lobby with Gus dozing in a corner, a vault behind a shutter
-- (alarmLock, open until the lock), a wall inside the vault that forces Gus to path
-- around it on the nav graph. Grabbing the Diamond trips the alarm.
function TestLevels.alarmSpec(): any
	local s = base("t_alarm", 903)
	s.goal = 500
	s.deadline = "Alarm"
	s.bounds = span(-40, -5, -70, 40, 25, 40)
	local solids = {}
	Shop.wallZGap(solids, 10, -20.5, 20.5, -4, 4)
	table.insert(solids, Shop.wallX(-20, -60, 10))
	table.insert(solids, Shop.wallX(20, -60, 10))
	table.insert(solids, Shop.wallZ(-60, -20.5, 20.5))
	Shop.wallZGap(solids, -20, -20.5, 20.5, -3, 3)
	table.insert(solids, { box = span(-12, 0, -37, 12, 12, -35) })
	s.solids = solids
	s.spawns = { { x = 0, y = 3, z = 14 }, { x = -3, y = 3, z = 14 } }
	s.van = span(-5, 0, 16, 5, 7, 24)
	s.doors = {
		{ id = "Shutter", box = span(-3, 0, -20.5, 3, 10, -19.5), alarmLock = true },
	}
	-- Gus dozes in the lobby's north-east corner facing the wall until the alarm.
	s.guards = {
		{
			id = "Gus",
			route = { { x = 17, z = 5, wait = 30, face = 270 }, { x = 17, z = 5, wait = 30, face = 270 } },
		},
	}
	s.nav = {
		{ x = 0, z = 0 },
		{ x = 0, z = -10 },
		{ x = 0, z = -25 },
		{ x = -16, z = -30 },
		{ x = 16, z = -30 },
		{ x = -16, z = -45 },
		{ x = 16, z = -45 },
		{ x = 0, z = -50 },
	}
	s.alarm = { trigger = "Diamond", vanSeconds = 8, lockSeconds = 4 }
	s.loot = {
		{ id = "Diamond", x = 0, y = 3, z = -50, value = 500, top = true },
		{ id = "Cash", x = 15, y = 3, z = 0, value = 50 },
	}
	return s
end

function TestLevels.alarm(): any
	return LevelSpec.compile(TestLevels.alarmSpec())
end

return TestLevels
