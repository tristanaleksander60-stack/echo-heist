--!strict
-- Sim/Alarm: the Alarm Run (MASTERPLAN §3.6). Tripped by grabbing the level's top
-- loot (or, when the level says so, by Gus catching a live player). Then: every
-- guard chases, the van countdown runs ("VAN LEAVES 0:20"; at 0 every live run
-- ends), and doors marked alarmLock shut ALARM_LOCK_SECONDS after the alarm.
-- Resets every loop. All on the sim tick, from actor positions.

local EventLog = require("./EventLog")
local Guards = require("./Guards")

local EV = EventLog.EV
local EPS = 1e-7

export type State = {
	active: boolean,
	t0: number,
	vanAt: number,
	lockAt: number,
	locked: boolean,
	left: boolean,
}

local Alarm = {}

function Alarm.new(): State
	return { active = false, t0 = 0, vanAt = 0, lockAt = 0, locked = false, left = false }
end

function Alarm.reset(state: State)
	state.active, state.t0, state.vanAt, state.lockAt, state.locked, state.left = false, 0, 0, 0, false, false
end

-- Trips the alarm at (x, z). `sim` is the HeistSim state; actorId 0 = tripped by a catch.
function Alarm.trigger(sim: any, actorId: number, x: number, z: number)
	local def = sim.level.alarm
	local state: State = sim.alarm
	if not def or state.active then
		return
	end
	local t = sim.t
	state.active = true
	state.t0 = t
	state.vanAt = t + def.vanSeconds
	state.lockAt = t + def.lockSeconds
	sim.mech.lockAt = state.lockAt
	EventLog.append(sim.log, sim.tick, EV.AlarmOn, actorId, math.floor(state.vanAt * 100 + 0.5))
	for _, g in sim.guards do
		Guards.startChase(g, x, z, sim.log, sim.tick)
	end
end

-- Per tick. Returns true when the van has just left (the run ends).
function Alarm.update(sim: any): boolean
	local state: State = sim.alarm
	if not state.active then
		return false
	end
	local t = sim.t
	if not state.locked and t >= state.lockAt - EPS then
		state.locked = true
		local n = 0
		for _, d in sim.level.doors do
			if d.alarmLock then
				n += 1
			end
		end
		EventLog.append(sim.log, sim.tick, EV.AlarmLock, n)
	end
	if not state.left and t >= state.vanAt - EPS then
		state.left = true
		EventLog.append(sim.log, sim.tick, EV.VanLeft)
		return true
	end
	return false
end

-- Seconds left on the van countdown (nil when no alarm).
function Alarm.vanRemaining(state: State, t: number): number?
	if not state.active then
		return nil
	end
	return math.max(0, state.vanAt - t)
end

return table.freeze(Alarm)
