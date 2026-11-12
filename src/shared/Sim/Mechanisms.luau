--!strict
-- Sim/Mechanisms: plates, switches, doors and lasers as tick-driven state machines.
-- MASTERPLAN §3.1 (plate grace, simultaneity), §6.7/§7.3 (doors solid only when
-- fully shut, lasers flicker before re-enabling), §8.2 (state machines with
-- timestamps; clients tween locally), §8.10 (lag fairness).
--
-- Everything is decided from actor positions inside the sim tick. Each door and
-- laser keeps the transitions of the current run (cleared every run), so a live
-- player's hazard check can ask "was this door solid at t - latency?" (§8.10 rule 1),
-- and the view helpers give clients the 0.2 s visual lead (§8.10 rule 2).
--
-- Plate held = an actor stands in it, or it was released less than PLATE_GRACE ago.
-- A door with no sources is open by default (an alarmLock shutter). A door is
-- passable from the tick it starts opening and solid DOOR_CLOSE_SECONDS after it
-- starts closing. A laser is on unless its sources are satisfied.

local Config = require("../Config")
local EventLog = require("./EventLog")
local Geom = require("./Geom")

local EV = EventLog.EV
local EPS = 1e-7
local INF = math.huge

export type PlateState = { pressed: boolean, count: number, releasedAt: number, firstActor: number }
export type SwitchState = { on: boolean, offAt: number? }
export type DoorState = {
	open: boolean, -- logically open (sources satisfied, not alarm-locked)
	solid: boolean, -- physically blocking
	solidAt: number?, -- when it is (closing) or would be (open, predicted) fully shut
	ht: { number },
	hv: { boolean }, -- transitions of `solid` this run
}
export type LaserState = {
	on: boolean,
	onAt: number?, -- predicted re-enable time while off
	ht: { number },
	hv: { boolean }, -- transitions of `on` this run
}
export type State = {
	level: any,
	plates: { PlateState },
	switches: { SwitchState },
	doors: { DoorState },
	lasers: { LaserState },
	lockAt: number?, -- alarm lock time (alarmLock doors are forced shut from then)
}

local Mechanisms = {}

function Mechanisms.new(level: any): State
	local state: State = { level = level, plates = {}, switches = {}, doors = {}, lasers = {}, lockAt = nil }
	for i = 1, #level.plates do
		state.plates[i] = { pressed = false, count = 0, releasedAt = -INF, firstActor = 0 }
	end
	for i = 1, #level.switches do
		state.switches[i] = { on = false, offAt = nil }
	end
	for i = 1, #level.doors do
		state.doors[i] = { open = false, solid = true, solidAt = nil, ht = { -INF }, hv = { true } }
	end
	for i = 1, #level.lasers do
		state.lasers[i] = { on = true, onAt = nil, ht = { -INF }, hv = { true } }
	end
	return state
end

-- Back to the loop-start state (everything resets every loop, §3.1).
function Mechanisms.reset(state: State)
	for _, p in state.plates do
		p.pressed, p.count, p.releasedAt, p.firstActor = false, 0, -INF, 0
	end
	for _, s in state.switches do
		s.on, s.offAt = false, nil
	end
	for _, d in state.doors do
		d.open, d.solid, d.solidAt = false, true, nil
		table.clear(d.ht)
		table.clear(d.hv)
		d.ht[1], d.hv[1] = -INF, true
	end
	for _, l in state.lasers do
		l.on, l.onAt = true, nil
		table.clear(l.ht)
		table.clear(l.hv)
		l.ht[1], l.hv[1] = -INF, true
	end
	state.lockAt = nil
end

local function plateHeld(p: PlateState, t: number): boolean
	return p.pressed or t < p.releasedAt + Config.Sim.PLATE_GRACE - EPS
end

local function sourceHeld(state: State, src: any, t: number): boolean
	if src.kind == "plate" then
		return plateHeld(state.plates[src.index], t)
	end
	return state.switches[src.index].on
end

-- When the source stops holding if nothing changes (INF = not on its own; t = already off).
local function sourceLapse(state: State, src: any, t: number): number
	if src.kind == "plate" then
		local p = state.plates[src.index]
		if p.pressed then
			return INF
		end
		local g = p.releasedAt + Config.Sim.PLATE_GRACE
		return if g > t then g else t
	end
	local s = state.switches[src.index]
	if not s.on then
		return t
	end
	return s.offAt or INF
end

function Mechanisms.satisfied(state: State, sources: { any }, need: string, t: number): boolean
	if #sources == 0 then
		return true
	end
	if need == "all" then
		for _, src in sources do
			if not sourceHeld(state, src, t) then
				return false
			end
		end
		return true
	end
	for _, src in sources do
		if sourceHeld(state, src, t) then
			return true
		end
	end
	return false
end

-- Predicted time the sources stop being satisfied (INF when they hold on their own).
function Mechanisms.lapseAt(state: State, sources: { any }, need: string, t: number): number
	if #sources == 0 then
		return INF
	end
	local best = if need == "all" then INF else -INF
	for _, src in sources do
		local l = sourceLapse(state, src, t)
		if need == "all" then
			best = math.min(best, l)
		else
			best = math.max(best, l)
		end
	end
	return best
end

local function push(ht: { number }, hv: { boolean }, t: number, v: boolean)
	table.insert(ht, t)
	table.insert(hv, v)
end

local function histAt(ht: { number }, hv: { boolean }, t: number): boolean
	for i = #ht, 1, -1 do
		if ht[i] <= t + EPS then
			return hv[i]
		end
	end
	return hv[1]
end

-- Presses a switch (Interact). Toggles, or turns a timed switch on (refreshing it).
function Mechanisms.press(state: State, index: number, t: number, actorId: number, log: EventLog.Log, tick: number)
	local def = state.level.switches[index]
	local s = state.switches[index]
	if def.duration then
		local wasOn = s.on
		s.on, s.offAt = true, t + def.duration
		if not wasOn then
			EventLog.append(log, tick, EV.SwitchOn, index, actorId)
		end
	elseif s.on then
		s.on = false
		EventLog.append(log, tick, EV.SwitchOff, index, actorId)
	else
		s.on = true
		EventLog.append(log, tick, EV.SwitchOn, index, actorId)
	end
end

-- One sim tick: plates from present actors (stable order), then switches, doors, lasers.
-- `actors` is the sim's actor array; an actor counts when `present` is true.
function Mechanisms.update(state: State, tick: number, t: number, actors: { any }, log: EventLog.Log)
	local level = state.level
	local S = Config.Sim
	for i, def in level.plates do
		local p = state.plates[i]
		local count, first = 0, 0
		for _, a in actors do
			if a.present and Geom.contains(def.box, a.x, a.y, a.z) then
				count += 1
				if first == 0 then
					first = a.id
				end
			end
		end
		local wasHeld = plateHeld(p, t)
		if count > 0 and not p.pressed then
			p.pressed = true
			p.firstActor = first
			if not wasHeld then
				EventLog.append(log, tick, EV.PlateDown, i, first)
			end
		elseif count == 0 and p.pressed then
			p.pressed = false
			p.releasedAt = t
		end
		p.count = count
		if wasHeld and not plateHeld(p, t) then
			EventLog.append(log, tick, EV.PlateUp, i)
		end
	end
	for i, s in state.switches do
		if s.on and s.offAt and t >= s.offAt - EPS then
			s.on, s.offAt = false, nil
			EventLog.append(log, tick, EV.SwitchOff, i, 0)
		end
	end
	local locked = state.lockAt ~= nil and t >= (state.lockAt :: number) - EPS
	for i, def in level.doors do
		local d = state.doors[i]
		local want = Mechanisms.satisfied(state, def.openBy, def.need, t) and not (def.alarmLock and locked)
		if want then
			if not d.open then
				d.open = true
				EventLog.append(log, tick, EV.DoorOpen, i)
			end
			if d.solid then
				d.solid = false
				push(d.ht, d.hv, t, false)
			end
			local lapse = Mechanisms.lapseAt(state, def.openBy, def.need, t)
			if def.alarmLock and state.lockAt then
				lapse = math.min(lapse, state.lockAt :: number)
			end
			d.solidAt = if lapse < INF then lapse + S.DOOR_CLOSE_SECONDS else nil
		else
			if d.open then
				d.open = false
				d.solidAt = t + S.DOOR_CLOSE_SECONDS
				EventLog.append(log, tick, EV.DoorClosing, i, math.floor((d.solidAt :: number) * 100 + 0.5))
			end
			if not d.solid and d.solidAt and t >= (d.solidAt :: number) - EPS then
				d.solid = true
				push(d.ht, d.hv, t, true)
				EventLog.append(log, tick, EV.DoorShut, i)
			end
		end
	end
	for i, def in level.lasers do
		local l = state.lasers[i]
		local off = Mechanisms.satisfied(state, def.offBy, def.need, t)
		if off and l.on then
			l.on = false
			push(l.ht, l.hv, t, false)
			EventLog.append(log, tick, EV.LaserOff, i)
		elseif not off and not l.on then
			l.on = true
			push(l.ht, l.hv, t, true)
			EventLog.append(log, tick, EV.LaserOn, i)
		end
		if l.on then
			l.onAt = nil
		else
			local lapse = Mechanisms.lapseAt(state, def.offBy, def.need, t)
			l.onAt = if lapse < INF then lapse else nil
		end
	end
end

-- Door solid at loop time T (this run's history; the latest known state for T >= now).
function Mechanisms.doorSolidAt(state: State, i: number, T: number): boolean
	local d = state.doors[i]
	return histAt(d.ht, d.hv, T)
end

function Mechanisms.laserOnAt(state: State, i: number, T: number): boolean
	local l = state.lasers[i]
	return histAt(l.ht, l.hv, T)
end

-- First door (index) that blocks the move p0 -> p1 at loop time T, or 0.
function Mechanisms.doorBlocking(
	state: State,
	T: number,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number
): number
	for i, def in state.level.doors do
		if Mechanisms.doorSolidAt(state, i, T) and Geom.moveBlocked(def.box, x0, y0, z0, x1, y1, z1) then
			return i
		end
	end
	return 0
end

-- First laser (index) that is on at T and touched by the segment p0 -> p1, or 0.
function Mechanisms.laserHit(
	state: State,
	T: number,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number
): number
	for i, def in state.level.lasers do
		if Mechanisms.laserOnAt(state, i, T) and Geom.touches(def.box, x0, y0, z0, x1, y1, z1) then
			return i
		end
	end
	return 0
end

function Mechanisms.plateHeld(state: State, i: number, t: number): boolean
	return plateHeld(state.plates[i], t)
end

-- Client view (§8.10 rule 2): a door looks shut, and is solid in the client's own
-- physics, from VISUAL_LEAD before the server makes it solid. `tView` is the
-- viewer's loop time; the state is what the viewer has received.
-- Returns "open", "closing" or "shut".
function Mechanisms.doorView(state: State, i: number, tView: number): string
	local d = state.doors[i]
	if d.solid then
		return "shut"
	end
	local at = d.solidAt
	if at and tView >= at - Config.Sim.VISUAL_LEAD - EPS then
		return "shut"
	end
	if not d.open then
		return "closing"
	end
	return "open"
end

-- Returns "off", "flicker" (the 3-flicker telegraph) or "on" for the viewer.
function Mechanisms.laserView(state: State, i: number, tView: number): string
	local l = state.lasers[i]
	if l.on then
		return "on"
	end
	local at = l.onAt
	if at then
		local lit = at - Config.Sim.VISUAL_LEAD
		if tView >= lit - EPS then
			return "on"
		elseif tView >= lit - Config.Sim.LASER_FLICKER_SECONDS - EPS then
			return "flicker"
		end
	end
	return "off"
end

return table.freeze(Mechanisms)
