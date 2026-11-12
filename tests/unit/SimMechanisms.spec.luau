-- L1: Sim/Mechanisms: plates (tolerance, grace), doors (open at once, solid only when
-- shut, any/all), lasers (off while held), switches (toggle, timed), the per-run
-- history the lag rewind reads, the client view helpers and the alarm lock.

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local Mechanisms = require("../../src/shared/Sim/Mechanisms")
local TestLevels = require("../sim/TestLevels")

local EV = EventLog.EV
local HZ = Config.Rec.HZ
local S = Config.Sim

local function setup()
	local level = TestLevels.corridor()
	local mech = Mechanisms.new(level)
	local log = EventLog.new()
	local a = { id = 1, present = true, x = 0, y = 3, z = 10 }
	local b = { id = 2, present = true, x = 0, y = 3, z = 10 }
	local tick = -1
	local function step(n: number?)
		for _ = 1, n or 1 do
			tick += 1
			Mechanisms.update(mech, tick, tick / HZ, { a, b }, log)
		end
		return tick / HZ
	end
	return level, mech, log, a, b, step
end

return function(test)
	test("plate presses from an actor inside its box, with the 0.5 stud tolerance", function()
		local _, mech, log, a, _, step = setup()
		a.x, a.z = 12.4, -5 -- 0.4 studs outside the authored plate, inside the tolerance
		step()
		Assert.truthy(Mechanisms.plateHeld(mech, 1, 0), "held")
		Assert.eq(EventLog.count(log, EV.PlateDown, 1), 1, "PlateDown")
		a.x = 12.6
		step()
		Assert.truthy(mech.plates[1].pressed == false, "released outside the tolerance")
	end)

	test("plate grace 0.4 s keeps its door open; then the door shuts 0.35 s later", function()
		local _, mech, log, a, _, step = setup()
		a.x, a.z = 10, -5
		step(10) -- t = 0.45, pressed since t = 0
		Assert.falsy(mech.doors[1].solid, "door open")
		a.x, a.z = 0, 10
		local tRelease = step() -- released at 0.5
		local graceTicks = math.floor(S.PLATE_GRACE * HZ + 0.5)
		step(graceTicks - 1)
		Assert.truthy(mech.doors[1].open, "still open inside the grace")
		step()
		Assert.falsy(mech.doors[1].open, "closing once the grace is over")
		Assert.falsy(mech.doors[1].solid, "not solid while sliding")
		Assert.near(mech.doors[1].solidAt :: number, tRelease + S.PLATE_GRACE + S.DOOR_CLOSE_SECONDS, 1e-9, "solidAt")
		local closeTicks = math.ceil(S.DOOR_CLOSE_SECONDS * HZ - 1e-9)
		step(closeTicks)
		Assert.truthy(mech.doors[1].solid, "solid when fully shut")
		Assert.eq(EventLog.count(log, EV.DoorShut, 1), 1, "DoorShut once")
		Assert.eq(EventLog.count(log, EV.PlateUp, 1), 1, "PlateUp after the grace")
	end)

	test("stepping back on inside the grace never closes the door", function()
		local _, mech, log, a, _, step = setup()
		a.x, a.z = 10, -5
		step(5)
		a.x, a.z = 0, 10
		step(4) -- 0.2 s off
		a.x, a.z = 10, -5
		step(20)
		Assert.eq(EventLog.count(log, EV.DoorClosing, 1), 0, "never closing")
		Assert.eq(EventLog.count(log, EV.PlateDown, 1), 1, "one PlateDown")
		Assert.falsy(mech.doors[1].solid, "open")
	end)

	test("need = all: both plates (two actors within the simultaneity window)", function()
		local _, mech, _, a, b, step = setup()
		a.x, a.z = 10, -5
		step(3)
		Assert.truthy(mech.doors[3].solid, "one plate is not enough")
		b.x, b.z = -10, -5
		step()
		Assert.falsy(mech.doors[3].solid, "both held: open")
	end)

	test("laser is off while its plate is held and back on after the grace", function()
		local _, mech, log, _, b, step = setup()
		step()
		Assert.truthy(mech.lasers[1].on, "on by default")
		b.x, b.z = -10, -5
		step()
		Assert.falsy(mech.lasers[1].on, "off")
		Assert.eq(mech.lasers[1].onAt, nil, "no predicted on while held")
		b.x, b.z = 0, 10
		local tr = step()
		Assert.near(mech.lasers[1].onAt :: number, tr + S.PLATE_GRACE, 1e-9, "predicted on")
		step(math.floor(S.PLATE_GRACE * HZ + 0.5))
		Assert.truthy(mech.lasers[1].on, "on again")
		Assert.eq(EventLog.count(log, EV.LaserOn, 1), 1, "LaserOn")
	end)

	test("switches: toggle, and a timed switch turns itself off", function()
		local _, mech, log, _, _, step = setup()
		local t = step()
		Mechanisms.press(mech, 1, t, 1, log, 0)
		step()
		Assert.falsy(mech.doors[2].solid, "toggle on opens D2")
		Mechanisms.press(mech, 1, t, 1, log, 1)
		step(1)
		Assert.falsy(mech.doors[2].open, "toggle off closes D2")
		t = step(20)
		Mechanisms.press(mech, 2, t, 1, log, 21)
		step()
		Assert.truthy(mech.doors[2].open, "timed switch opens D2")
		step(3 * HZ)
		Assert.falsy(mech.switches[2].on, "timed switch off after 3 s")
		Assert.truthy(EventLog.count(log, EV.SwitchOff, 2) >= 1, "SwitchOff logged")
	end)

	test("history answers 'was it solid at T' for the lag rewind", function()
		local _, mech, _, a, _, step = setup()
		a.x, a.z = 10, -5
		step(10) -- open from t = 0
		a.x, a.z = 0, 10
		step(30) -- released at 0.5, solid at 0.5 + 0.4 + 0.35 = 1.25
		Assert.falsy(Mechanisms.doorSolidAt(mech, 1, 1.2), "open at 1.2")
		Assert.truthy(Mechanisms.doorSolidAt(mech, 1, 1.25), "solid at 1.25")
		Assert.truthy(Mechanisms.doorSolidAt(mech, 1, -1), "solid before the run")
		Assert.eq(Mechanisms.doorBlocking(mech, 1.1, 0, 3, -10, 0, 3, -20), 0, "passable at 1.1")
		Assert.eq(Mechanisms.doorBlocking(mech, 1.4, 0, 3, -10, 0, 3, -20), 1, "blocked at 1.4")
		Assert.eq(Mechanisms.laserHit(mech, 1.4, 0, 3, -20, 0, 3, -30), 1, "laser on (Q never held)")
	end)

	test("client view: shut and lit VISUAL_LEAD early, 3 flickers before that (§8.10 rule 2)", function()
		local lead, flick = S.VISUAL_LEAD, S.LASER_FLICKER_SECONDS
		local d = { open = false, solid = false, solidAt = 2.0 }
		Assert.eq(Mechanisms.doorViewOf(d, 2.0 - lead - 0.01), "closing", "before the lead")
		Assert.eq(Mechanisms.doorViewOf(d, 2.0 - lead), "shut", "shut at the lead")
		Assert.eq(Mechanisms.doorViewOf({ open = true, solid = false, solidAt = nil }, 5), "open", "held open")
		local l = { on = false, onAt = 3.0 }
		Assert.eq(Mechanisms.laserViewOf(l, 3.0 - lead - flick - 0.01), "off", "off")
		Assert.eq(Mechanisms.laserViewOf(l, 3.0 - lead - flick), "flicker", "flicker starts")
		Assert.eq(Mechanisms.laserViewOf(l, 3.0 - lead - 0.01), "flicker", "flicker ends at the lead")
		Assert.eq(Mechanisms.laserViewOf(l, 3.0 - lead), "on", "lit 0.2 s before the server")
	end)

	test("alarmLock: a door with no sources is open until the lock, then shut", function()
		local level = TestLevels.alarm()
		local mech = Mechanisms.new(level)
		local log = EventLog.new()
		Mechanisms.update(mech, 0, 0, {}, log)
		Assert.falsy(mech.doors[1].solid, "shutter open")
		mech.lockAt = 1.0
		Mechanisms.update(mech, 1, 0.05, {}, log)
		Assert.near(mech.doors[1].solidAt :: number, 1.0 + S.DOOR_CLOSE_SECONDS, 1e-9, "predicted shut at lock")
		for k = 2, 40 do
			Mechanisms.update(mech, k, k / HZ, {}, log)
		end
		Assert.truthy(mech.doors[1].solid, "locked shut")
	end)

	test("reset puts every mechanism back to loop start", function()
		local _, mech, _, a, _, step = setup()
		a.x, a.z = 10, -5
		step(10)
		Mechanisms.reset(mech)
		Assert.truthy(mech.doors[1].solid, "door shut")
		Assert.eq(#mech.doors[1].ht, 1, "history cleared")
		Assert.falsy(mech.plates[1].pressed, "plate up")
	end)
end
