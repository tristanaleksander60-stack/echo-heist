--!strict
-- Sim/EventLog: the ordered log of every sim outcome, and its stable hash.
-- MASTERPLAN §3.2 rule 3, §8.9 L2 ("identical event-log hash twice").
-- One log per run (cleared at run start, so a 500-loop soak does not grow); the
-- heist keeps a rolling hash of run hashes. Entries are integers only (positions
-- on the 1/16-stud grid via Geom.q), so the hash is the same on every machine.
-- The hash is Rec/Codec's FNV-1a over a little-endian byte encoding of the log.

local Codec = require("../Rec/Codec")

-- Event kinds (u8). Append, never renumber: hashes in CI fixtures depend on them.
local EV = table.freeze({
	RunStart = 1, -- a = runIndex, b = clone actors, c = live actors
	RunEnd = 2, -- a = Sim end reason code (HeistSim.RUN_END), b = tick
	EndRun = 3, -- a = actor (live player pressed END RUN)
	Timeout = 4, -- a = actor (the tape ran out on a live run)
	PlateDown = 5, -- a = plate, b = first actor on it
	PlateUp = 6, -- a = plate (grace over)
	DoorOpen = 7, -- a = door
	DoorClosing = 8, -- a = door, b = solidAt (centiseconds)
	DoorShut = 9, -- a = door (now solid)
	LaserOff = 10, -- a = laser
	LaserOn = 11, -- a = laser
	SwitchOn = 12, -- a = switch, b = actor
	SwitchOff = 13, -- a = switch
	Grab = 14, -- a = actor, b = loot
	Release = 15, -- a = actor, b = loot
	Drop = 16, -- a = actor, b = loot (dropped because the actor was taken out)
	Bank = 17, -- a = actor, b = loot, c = banked total
	Shrug = 18, -- a = actor, b = intent kind, c = reason code (Interact.FAIL)
	Rejected = 19, -- a = actor, b = intent kind, c = reason (live intent refused)
	Stuck = 20, -- a = actor, b = cause (HeistSim.CAUSE), c = blocker index
	Zap = 21, -- a = actor, b = laser
	Spotted = 22, -- a = guard, b = actor (meter starts: amber)
	Suspect = 23, -- a = guard, b = actor ("?")
	Lost = 24, -- a = guard, b = actor (meter back to 0)
	Caught = 25, -- a = guard, b = actor (live run ends)
	Busted = 26, -- a = guard, b = actor (clone)
	GuardHuh = 27, -- a = guard ("huh?" freeze)
	GuardResume = 28, -- a = guard
	AlarmOn = 29, -- a = actor that tripped it (0 = catch), b = van leaves at (centiseconds)
	AlarmLock = 30, -- a = door count locked
	VanLeft = 31,
	Squeeze = 32, -- b = new run length (centiseconds)
	HeistComplete = 33, -- a = banked total, b = runIndex
	Dawn = 34, -- a = banked total, b = runIndex
	Respawn = 35, -- a = loot, b = spot
	Hidden = 36, -- a = actor, b = hide spot (entered)
	Unhidden = 37, -- a = actor
	Left = 38, -- a = actor (player left mid-run)
	GoalMet = 39, -- a = banked total
	Chase = 40, -- a = guard, b = target actor (0 = last-seen point)
	AutoEnd = 41, -- a = actor (tutorial forced END RUN on the plate)
})

local NAMES: { [number]: string } = {}
for name, code in EV do
	NAMES[code] = name
end

export type Log = {
	n: number,
	tick: { number },
	kind: { number },
	a: { number },
	b: { number },
	c: { number },
}

local EventLog = {}
EventLog.EV = EV
EventLog.ENTRY_BYTES = 17

function EventLog.new(): Log
	return { n = 0, tick = {}, kind = {}, a = {}, b = {}, c = {} }
end

-- Empties the log in place (keeps the tables, so a soak does not churn memory).
function EventLog.clear(log: Log)
	table.clear(log.tick)
	table.clear(log.kind)
	table.clear(log.a)
	table.clear(log.b)
	table.clear(log.c)
	log.n = 0
end

local function int(v: number?): number
	local x = v or 0
	if x ~= x then
		return 0
	end
	return math.clamp(math.floor(x + 0.5), -2147483648, 2147483647)
end

-- An independent copy (the sim reuses its log table every run).
function EventLog.copy(log: Log): Log
	return {
		n = log.n,
		tick = table.clone(log.tick),
		kind = table.clone(log.kind),
		a = table.clone(log.a),
		b = table.clone(log.b),
		c = table.clone(log.c),
	}
end

function EventLog.append(log: Log, tick: number, kind: number, a: number?, b: number?, c: number?)
	local i = log.n + 1
	log.n = i
	log.tick[i] = tick
	log.kind[i] = kind
	log.a[i] = int(a)
	log.b[i] = int(b)
	log.c[i] = int(c)
end

-- Byte encoding: per entry u32 tick, u8 kind, i32 a, i32 b, i32 c.
function EventLog.encode(log: Log, from: number?, to: number?): buffer
	local i0 = from or 1
	local i1 = to or log.n
	local count = math.max(0, i1 - i0 + 1)
	local b = buffer.create(count * EventLog.ENTRY_BYTES)
	local o = 0
	for i = i0, i1 do
		buffer.writeu32(b, o, log.tick[i] % 4294967296)
		buffer.writeu8(b, o + 4, log.kind[i])
		buffer.writei32(b, o + 5, log.a[i])
		buffer.writei32(b, o + 9, log.b[i])
		buffer.writei32(b, o + 13, log.c[i])
		o += EventLog.ENTRY_BYTES
	end
	return b
end

-- Stable FNV-1a 32-bit hash of the log (or a slice of it).
function EventLog.hash(log: Log, from: number?, to: number?): number
	return Codec.hash(EventLog.encode(log, from, to))
end

-- Folds a 32-bit value into a running hash (heist hash = fold over run hashes).
function EventLog.fold(h: number, v: number): number
	local b = buffer.create(8)
	buffer.writeu32(b, 0, h % 4294967296)
	buffer.writeu32(b, 4, v % 4294967296)
	return Codec.hash(b)
end

function EventLog.name(kind: number): string
	return NAMES[kind] or ("?" .. tostring(kind))
end

-- Human-readable lines (debugging and test failure output).
function EventLog.lines(log: Log, from: number?, to: number?): { string }
	local out = {}
	for i = from or 1, to or log.n do
		table.insert(
			out,
			string.format("%5d %-13s %d %d %d", log.tick[i], EventLog.name(log.kind[i]), log.a[i], log.b[i], log.c[i])
		)
	end
	return out
end

-- Number of entries of one kind (tests).
function EventLog.count(log: Log, kind: number, a: number?, b: number?): number
	local c = 0
	for i = 1, log.n do
		if log.kind[i] == kind and (a == nil or log.a[i] == a) and (b == nil or log.b[i] == b) then
			c += 1
		end
	end
	return c
end

-- First tick of an entry of one kind, or nil.
function EventLog.firstTick(log: Log, kind: number, a: number?, b: number?): number?
	for i = 1, log.n do
		if log.kind[i] == kind and (a == nil or log.a[i] == a) and (b == nil or log.b[i] == b) then
			return log.tick[i]
		end
	end
	return nil
end

return table.freeze(EventLog)
