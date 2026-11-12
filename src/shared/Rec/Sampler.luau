--!strict
-- Rec/Sampler: how runs are sampled (recording side) and read back (playback side).
-- MASTERPLAN §3.2 rule 1, §8.2, §8.3. Pure Luau, no engine services.
--
-- Sampling policy
--   * One sample per fixed sim tick (20 Hz) from loop time 0: sample i is at
--     t = (i - 1) / hz. Time is the index, never the frame count, so a replay
--     is exact whatever the frame rate ("sample by time, never by frame index").
--   * A skipped tick is filled by repeating the last sample, so the index stays time.
--   * Values are snapped to the Codec grid when recorded: the server sim and every
--     client sample the same numbers.
--   * Keyframe decisions: a server teleport (respawn, sent to spawn, scripted move)
--     is recorded as a cut: record the exemption event first (Respawn/Teleport),
--     then the sample with cut = true. Playback never interpolates across a cut,
--     and the Validator accepts the jump only when an exemption event backs it.
--     The Codec also writes plain keyframes on its own when a delta overflows i8.
--   * The recording ends when the run ends (END RUN, caught, timeout, left);
--     after its last sample the clone holds the final pose.
--
-- Playback
--   Sampler.at(rec, t) gives position, yaw and flags at loop time t:
--   Catmull-Rom over 4 samples for position, shortest-arc yaw, step flags.
--   At exact tick times it returns the recorded sample, so the 20 Hz sim
--   (plates, lasers, Gus) reads exactly what was recorded.

local Config = require("../Config")
local Codec = require("./Codec")

type Recording = Codec.Recording

local Sampler = {}

local snapPos, snapYaw = Codec.snapPos, Codec.snapYaw
local TAU = 2 * math.pi
local EPS = 1e-7

-- Most samples a run can hold: the hard ceiling plus the t = 0 sample.
function Sampler.capacity(hz: number): number
	return math.min(math.floor(Config.Rec.LOOP_MAX_SECONDS * hz + 0.5) + 1, Codec.MAX_SAMPLES)
end

function Sampler.new(levelId: number?, loopIndex: number?, hz: number?): Recording
	return Codec.newRecording(hz or Config.Rec.HZ, levelId, loopIndex)
end

-- Loop time of sample i (1-based).
function Sampler.timeOf(rec: Recording, i: number): number
	return (i - 1) / rec.hz
end

-- Loop time of the last sample (0 for empty or 1-sample runs).
function Sampler.duration(rec: Recording): number
	if rec.n <= 1 then
		return 0
	end
	return (rec.n - 1) / rec.hz
end

local function append(rec: Recording, x: number, y: number, z: number, yaw: number, flags: number)
	local i = rec.n + 1
	rec.n = i
	rec.px[i] = x
	rec.py[i] = y
	rec.pz[i] = z
	rec.yaw[i] = yaw
	rec.flags[i] = flags
end

-- Records the sample for sim tick `tick` (0 = loop time 0). Ticks must increase;
-- a stale or duplicate tick is ignored, a gap repeats the last sample.
-- Returns false when the sample was not taken (stale tick, run over, or full).
function Sampler.record(
	rec: Recording,
	tick: number,
	x: number,
	y: number,
	z: number,
	yaw: number,
	flags: number,
	cut: boolean?
): boolean
	if rec.endReason ~= Codec.END.None then
		return false
	end
	local index = math.floor(tick + EPS) + 1
	if index <= rec.n or index > Sampler.capacity(rec.hz) then
		return false
	end
	local n = rec.n
	if n > 0 then
		local lx, ly, lz, la, lf = rec.px[n], rec.py[n], rec.pz[n], rec.yaw[n], rec.flags[n]
		for _ = n + 1, index - 1 do
			append(rec, lx, ly, lz, la, lf)
		end
	elseif index > 1 then
		-- The first tick was missed: the run starts where it is first seen.
		for _ = 1, index - 1 do
			append(rec, snapPos(x), snapPos(y), snapPos(z), snapYaw(yaw), bit32.band(flags, 0xFF))
		end
	end
	append(rec, snapPos(x), snapPos(y), snapPos(z), snapYaw(yaw), bit32.band(flags, 0xFF))
	if cut and rec.n > 1 then
		rec.cut[rec.n] = true
	end
	return true
end

-- Appends a sample at the next tick.
function Sampler.push(rec: Recording, x: number, y: number, z: number, yaw: number, flags: number, cut: boolean?): boolean
	return Sampler.record(rec, rec.n, x, y, z, yaw, flags, cut)
end

-- Records an intent event at loop time t. Events must be added in time order.
function Sampler.addEvent(rec: Recording, t: number, kind: number, arg: number?): boolean
	if #rec.events >= Config.Rec.MAX_EVENTS then
		return false
	end
	table.insert(rec.events, { t = Codec.snapEventTime(t), kind = kind, arg = math.clamp(math.floor(arg or 0), 0, 65535) })
	return true
end

-- Stops the recording. Later record() calls are ignored.
function Sampler.finish(rec: Recording, endReason: number)
	rec.endReason = endReason
end

local function catmull(p0: number, p1: number, p2: number, p3: number, f: number): number
	return 0.5
		* (2 * p1 + (p2 - p0) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f + (3 * p1 - p0 - 3 * p2 + p3) * f * f * f)
end

local function catmullSlope(p0: number, p1: number, p2: number, p3: number, f: number): number
	return 0.5 * ((p2 - p0) + 2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) * f + 3 * (3 * p1 - p0 - 3 * p2 + p3) * f * f)
end

-- Splits loop time t into the segment start index i (1-based) and fraction f,
-- plus the neighbour indices, respecting cuts. Requires rec.n >= 1.
local function locate(rec: Recording, t: number): (number, number, number, number, number, boolean)
	local n = rec.n
	local u = t * rec.hz
	if u <= 0 or n == 1 then
		return 1, 1, 1, 1, 0, true
	end
	local fi = math.floor(u + EPS)
	local i = fi + 1
	if i >= n then
		return n, n, n, n, 0, true
	end
	local f = u - fi
	if f < EPS then
		f = 0
	end
	local cut = rec.cut
	if cut[i + 1] then
		-- Hold until the teleport sample; never slide across a cut.
		return i, i, i, i, 0, true
	end
	local i0 = if i > 1 and not cut[i] then i - 1 else i
	local i3 = if i + 2 <= n and not cut[i + 2] then i + 2 else i + 1
	return i0, i, i + 1, i3, f, false
end

-- Position (studs, level space), yaw (radians, [0, 2pi)) and flags at loop time t.
-- Before t = 0 it gives the first sample, after the end it holds the last one.
-- Returns nil for an empty recording.
function Sampler.at(rec: Recording, t: number): (number?, number, number, number, number)
	if rec.n == 0 then
		return nil, 0, 0, 0, 0
	end
	local i0, i1, i2, i3, f, hold = locate(rec, t)
	local px, py, pz = rec.px, rec.py, rec.pz
	if hold or f == 0 then
		return px[i1], py[i1], pz[i1], rec.yaw[i1], rec.flags[i1]
	end
	local x = catmull(px[i0], px[i1], px[i2], px[i3], f)
	local y = catmull(py[i0], py[i1], py[i2], py[i3], f)
	local z = catmull(pz[i0], pz[i1], pz[i2], pz[i3], f)
	local a1, a2 = rec.yaw[i1], rec.yaw[i2]
	local d = (a2 - a1 + math.pi) % TAU - math.pi
	local yaw = (a1 + d * f) % TAU
	return x, y, z, yaw, rec.flags[i1]
end

-- Velocity (studs/s) at loop time t from the spline; 0 while holding or empty.
-- Feeds the clone's animation speed.
function Sampler.velocity(rec: Recording, t: number): (number, number, number)
	if rec.n < 2 then
		return 0, 0, 0
	end
	local i0, i1, i2, i3, f, hold = locate(rec, t)
	if hold then
		return 0, 0, 0
	end
	local px, py, pz, hz = rec.px, rec.py, rec.pz, rec.hz
	return catmullSlope(px[i0], px[i1], px[i2], px[i3], f) * hz,
		catmullSlope(py[i0], py[i1], py[i2], py[i3], f) * hz,
		catmullSlope(pz[i0], pz[i1], pz[i2], pz[i3], f) * hz
end

-- True once loop time t is past the last sample: the clone holds its final pose.
function Sampler.isHolding(rec: Recording, t: number): boolean
	return rec.n == 0 or t * rec.hz >= rec.n - 1 - EPS
end

-- Event cursor for replay. Given the index of the last event already fired
-- (0 at loop start), returns the index of the last event due at loop time t.
-- Fire events cursor + 1 .. result, then pass result as the next cursor.
function Sampler.eventsDue(rec: Recording, cursor: number, t: number): number
	local events = rec.events
	local last = cursor
	while last < #events and events[last + 1].t <= t + EPS do
		last += 1
	end
	return last
end

return table.freeze(Sampler)
