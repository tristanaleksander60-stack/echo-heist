--!strict
-- Rec/Codec: the run recording format (versioned) and its compact `buffer` encoding.
-- MASTERPLAN §8.3. Pure Luau: no engine services, so it runs in Lune and on both
-- Roblox sides (the server sim and the client view decode the same bytes).
--
-- A Recording holds samples taken at a fixed rate from loop time 0: sample i
-- (1-based) is at t = (i - 1) / hz. Positions are in studs relative to the level
-- origin (the caller subtracts it), yaw is in radians, flags is the packed byte.
-- Values are kept on the format grid (1/16 stud, 1/256 turn) from the moment
-- they are recorded (Sampler.record), so decode(encode(rec)) is bit-identical
-- and the server sim sees exactly what clients will see.
--
-- Buffer layout v1 (little endian):
--   header 13 B: u8 version, u8 hz, u16 levelId, u16 loopIndex, u16 sampleCount,
--                u16 eventCount, u16 validatorFlags, u8 endReason
--   samples, one tagged record each (or one record for a run of identical ones):
--     0b000mmmmm  delta: m = mask (dx, dy, dz, yaw, flags present), then
--                 i8 per present axis delta (1/16 stud), u8 yaw, u8 flags
--     0b01rrrrrr  repeat the previous sample r + 1 times (1..64)
--     0b10000000  keyframe: i16 x, i16 y, i16 z, u8 yaw, u8 flags
--     0b11000000  keyframe that is a cut (server teleport: never interpolate across)
--   events, 5 B each: u16 t (centiseconds), u8 kind, u16 arg

local Codec = {}

Codec.VERSION = 1
Codec.POS_SCALE = 16 -- grid units per stud (error <= 1/32 stud)
Codec.POS_MIN = -32768 / 16 -- studs
Codec.POS_MAX = 32767 / 16 -- studs
Codec.YAW_STEPS = 256 -- u8 yaw: 1.40625 degrees per step
Codec.EVENT_TIME_SCALE = 100 -- event times are stored in centiseconds (u16: up to 655 s)
Codec.HEADER_BYTES = 13
Codec.EVENT_BYTES = 5
Codec.MAX_SAMPLES = 65535
Codec.MAX_EVENTS = 65535

-- Flags byte: 5 state bits plus a 3-bit pose/emote id in the top bits.
Codec.FLAG = table.freeze({
	GROUNDED = 1,
	JUMPING = 2,
	CROUCH = 4,
	HEAVY = 8, -- carrying heavy loot
	HIDDEN = 16, -- inside an EH_Hide box
})
Codec.POSE_SHIFT = 5
Codec.POSE_MAX = 7

-- Interaction event kinds (u8). Ids are part of the format: append, never renumber.
Codec.EVENT = table.freeze({
	Grab = 1,
	Release = 2,
	Press = 3,
	HoldStart = 4,
	HoldEnd = 5,
	Hide = 6,
	Emote = 7,
	Gadget = 8,
	Vanish = 9, -- terminal: the actor left the run (fell off the map, left the game)
	Respawn = 10, -- server moved the actor to a spawn: allows a cut sample
	Caught = 11, -- terminal: Gus caught the actor; the run ends (§3.1)
	Teleport = 12, -- any other server move (exemption token): allows a cut sample
})
Codec.EVENT_COUNT = 12

-- Why the recording stopped (u8 in the header).
Codec.END = table.freeze({
	None = 0, -- still recording
	Timeout = 1, -- the loop timer hit 0
	EndRun = 2, -- the player pressed END RUN
	Caught = 3,
	Left = 4, -- the player left or the loop was cut short
	Vanish = 5,
	Zapped = 6, -- walked into an active laser (shared/Sim)
})

export type Event = {
	t: number, -- loop time in seconds (on the centisecond grid)
	kind: number,
	arg: number, -- u16 target id (loot index, plate index, emote id...)
}

export type Recording = {
	version: number,
	hz: number,
	levelId: number,
	loopIndex: number,
	vflags: number, -- Validator.FLAG bits; non-zero means tainted
	endReason: number,
	n: number, -- sample count
	px: { number },
	py: { number },
	pz: { number },
	yaw: { number },
	flags: { number },
	cut: { [number]: boolean }, -- sample index -> true when a server teleport lands there
	events: { Event },
}

local TAU = 2 * math.pi
local POS_SCALE = Codec.POS_SCALE
local YAW_STEPS = Codec.YAW_STEPS
local HEADER = Codec.HEADER_BYTES

local TAG_REPEAT = 0x40
local TAG_KEY = 0x80
local TAG_CUT = 0xC0
local MASK_DX, MASK_DY, MASK_DZ, MASK_YAW, MASK_FLAGS = 1, 2, 4, 8, 16

local function clampInt(v: number, lo: number, hi: number): number
	if v < lo then
		return lo
	elseif v > hi then
		return hi
	end
	return v
end

-- Studs -> grid units (i16). NaN becomes 0; out-of-range values clamp.
function Codec.quantizePos(v: number): number
	if v ~= v then
		return 0
	end
	return clampInt(math.floor(v * POS_SCALE + 0.5), -32768, 32767)
end

function Codec.dequantizePos(q: number): number
	return q / POS_SCALE
end

-- Radians (any range) -> u8 step.
function Codec.quantizeYaw(yaw: number): number
	if yaw ~= yaw or yaw == math.huge or yaw == -math.huge then
		return 0
	end
	return math.floor(yaw / TAU * YAW_STEPS + 0.5) % YAW_STEPS
end

function Codec.dequantizeYaw(q: number): number
	return q * TAU / YAW_STEPS
end

-- Snap a value to the grid without leaving studs/radians.
function Codec.snapPos(v: number): number
	return Codec.quantizePos(v) / POS_SCALE
end

function Codec.snapYaw(yaw: number): number
	return Codec.quantizeYaw(yaw) * TAU / YAW_STEPS
end

function Codec.snapEventTime(t: number): number
	if t ~= t or t < 0 then
		return 0
	end
	return clampInt(math.floor(t * Codec.EVENT_TIME_SCALE + 0.5), 0, 65535) / Codec.EVENT_TIME_SCALE
end

function Codec.packFlags(bits: number, pose: number?): number
	local p = clampInt(math.floor(pose or 0), 0, Codec.POSE_MAX)
	return bit32.bor(bit32.band(bits, 0x1F), bit32.lshift(p, Codec.POSE_SHIFT))
end

function Codec.hasFlag(flags: number, bit: number): boolean
	return bit32.band(flags, bit) ~= 0
end

function Codec.poseOf(flags: number): number
	return bit32.rshift(bit32.band(flags, 0xE0), Codec.POSE_SHIFT)
end

-- An empty recording (no samples, no events).
function Codec.newRecording(hz: number, levelId: number?, loopIndex: number?): Recording
	return {
		version = Codec.VERSION,
		hz = hz,
		levelId = levelId or 0,
		loopIndex = loopIndex or 0,
		vflags = 0,
		endReason = Codec.END.None,
		n = 0,
		px = {},
		py = {},
		pz = {},
		yaw = {},
		flags = {},
		cut = {},
		events = {},
	}
end

-- Upper bound of the encoded size, in bytes.
function Codec.maxSize(rec: Recording): number
	return HEADER + rec.n * 9 + #rec.events * Codec.EVENT_BYTES
end

function Codec.encode(rec: Recording): buffer
	local n = rec.n
	local events = rec.events
	assert(n <= Codec.MAX_SAMPLES, "Codec.encode: too many samples")
	assert(#events <= Codec.MAX_EVENTS, "Codec.encode: too many events")
	assert(rec.hz >= 1 and rec.hz <= 255, "Codec.encode: hz must fit a u8")

	local b = buffer.create(Codec.maxSize(rec))
	buffer.writeu8(b, 0, Codec.VERSION)
	buffer.writeu8(b, 1, rec.hz)
	buffer.writeu16(b, 2, clampInt(rec.levelId, 0, 65535))
	buffer.writeu16(b, 4, clampInt(rec.loopIndex, 0, 65535))
	buffer.writeu16(b, 6, n)
	buffer.writeu16(b, 8, #events)
	buffer.writeu16(b, 10, bit32.band(rec.vflags, 0xFFFF))
	buffer.writeu8(b, 12, clampInt(rec.endReason, 0, 255))

	local px, py, pz, pyaw, pflags = rec.px, rec.py, rec.pz, rec.yaw, rec.flags
	local qpos, qyaw = Codec.quantizePos, Codec.quantizeYaw
	local o = HEADER
	local lx, ly, lz, lyaw, lfl = 0, 0, 0, 0, 0
	local i = 1
	while i <= n do
		local qx, qy, qz = qpos(px[i]), qpos(py[i]), qpos(pz[i])
		local qa, qf = qyaw(pyaw[i]), bit32.band(pflags[i], 0xFF)
		local dx, dy, dz = qx - lx, qy - ly, qz - lz
		local isCut = rec.cut[i] == true
		if i == 1 or isCut or dx < -128 or dx > 127 or dy < -128 or dy > 127 or dz < -128 or dz > 127 then
			-- Keyframe: first sample, server teleport, or a move too big for i8.
			buffer.writeu8(b, o, if isCut then TAG_CUT else TAG_KEY)
			buffer.writei16(b, o + 1, qx)
			buffer.writei16(b, o + 3, qy)
			buffer.writei16(b, o + 5, qz)
			buffer.writeu8(b, o + 7, qa)
			buffer.writeu8(b, o + 8, qf)
			o += 9
			i += 1
		elseif dx == 0 and dy == 0 and dz == 0 and qa == lyaw and qf == lfl then
			-- Run of samples identical to the previous one (standing still).
			local run = 1
			while run < 64 do
				local j = i + run
				if
					j > n
					or rec.cut[j] == true
					or qpos(px[j]) ~= lx
					or qpos(py[j]) ~= ly
					or qpos(pz[j]) ~= lz
					or qyaw(pyaw[j]) ~= lyaw
					or bit32.band(pflags[j], 0xFF) ~= lfl
				then
					break
				end
				run += 1
			end
			buffer.writeu8(b, o, TAG_REPEAT + run - 1)
			o += 1
			i += run
		else
			local tagAt = o
			local mask = 0
			o += 1
			if dx ~= 0 then
				mask += MASK_DX
				buffer.writei8(b, o, dx)
				o += 1
			end
			if dy ~= 0 then
				mask += MASK_DY
				buffer.writei8(b, o, dy)
				o += 1
			end
			if dz ~= 0 then
				mask += MASK_DZ
				buffer.writei8(b, o, dz)
				o += 1
			end
			if qa ~= lyaw then
				mask += MASK_YAW
				buffer.writeu8(b, o, qa)
				o += 1
			end
			if qf ~= lfl then
				mask += MASK_FLAGS
				buffer.writeu8(b, o, qf)
				o += 1
			end
			buffer.writeu8(b, tagAt, mask)
			i += 1
		end
		lx, ly, lz, lyaw, lfl = qx, qy, qz, qa, qf
	end

	local ts = Codec.EVENT_TIME_SCALE
	for _, e in events do
		buffer.writeu16(b, o, clampInt(math.floor(e.t * ts + 0.5), 0, 65535))
		buffer.writeu8(b, o + 2, clampInt(e.kind, 0, 255))
		buffer.writeu16(b, o + 3, clampInt(e.arg, 0, 65535))
		o += Codec.EVENT_BYTES
	end

	local out = buffer.create(o)
	buffer.copy(out, 0, b, 0, o)
	return out
end

local function decodeUnsafe(b: buffer): Recording
	local len = buffer.len(b)
	if len < HEADER then
		error("truncated header", 0)
	end
	local version = buffer.readu8(b, 0)
	if version ~= Codec.VERSION then
		error("unsupported version " .. version, 0)
	end
	local hz = buffer.readu8(b, 1)
	if hz == 0 then
		error("hz is 0", 0)
	end
	local n = buffer.readu16(b, 6)
	local ne = buffer.readu16(b, 8)
	local rec = Codec.newRecording(hz, buffer.readu16(b, 2), buffer.readu16(b, 4))
	rec.vflags = buffer.readu16(b, 10)
	rec.endReason = buffer.readu8(b, 12)
	rec.n = n

	local px, py, pz, pyaw, pflags, cut = rec.px, rec.py, rec.pz, rec.yaw, rec.flags, rec.cut
	local o = HEADER
	local qx, qy, qz, qa, qf = 0, 0, 0, 0, 0
	local i = 0
	local function need(bytes: number)
		if o + bytes > len then
			error("truncated samples", 0)
		end
	end
	while i < n do
		need(1)
		local tag = buffer.readu8(b, o)
		o += 1
		local count = 1
		if tag >= TAG_KEY then
			need(8)
			qx = buffer.readi16(b, o)
			qy = buffer.readi16(b, o + 2)
			qz = buffer.readi16(b, o + 4)
			qa = buffer.readu8(b, o + 6)
			qf = buffer.readu8(b, o + 7)
			o += 8
			if tag == TAG_CUT then
				cut[i + 1] = true
			elseif tag ~= TAG_KEY then
				error("bad keyframe tag", 0)
			end
		elseif tag >= TAG_REPEAT then
			if i == 0 then
				error("repeat before first sample", 0)
			end
			count = tag - TAG_REPEAT + 1
			if i + count > n then
				error("repeat past sample count", 0)
			end
		else
			if i == 0 then
				error("delta before first sample", 0)
			end
			if tag >= 32 then
				error("bad delta mask", 0)
			end
			if bit32.band(tag, MASK_DX) ~= 0 then
				need(1)
				qx += buffer.readi8(b, o)
				o += 1
			end
			if bit32.band(tag, MASK_DY) ~= 0 then
				need(1)
				qy += buffer.readi8(b, o)
				o += 1
			end
			if bit32.band(tag, MASK_DZ) ~= 0 then
				need(1)
				qz += buffer.readi8(b, o)
				o += 1
			end
			if bit32.band(tag, MASK_YAW) ~= 0 then
				need(1)
				qa = buffer.readu8(b, o)
				o += 1
			end
			if bit32.band(tag, MASK_FLAGS) ~= 0 then
				need(1)
				qf = buffer.readu8(b, o)
				o += 1
			end
		end
		local x, y, z, a = qx / POS_SCALE, qy / POS_SCALE, qz / POS_SCALE, qa * TAU / YAW_STEPS
		for _ = 1, count do
			i += 1
			px[i], py[i], pz[i], pyaw[i], pflags[i] = x, y, z, a, qf
		end
	end

	if o + ne * Codec.EVENT_BYTES ~= len then
		error("event section size mismatch", 0)
	end
	local ts = Codec.EVENT_TIME_SCALE
	local events = rec.events
	for k = 1, ne do
		events[k] = {
			t = buffer.readu16(b, o) / ts,
			kind = buffer.readu8(b, o + 2),
			arg = buffer.readu16(b, o + 3),
		}
		o += Codec.EVENT_BYTES
	end
	return rec
end

-- Returns the recording, or nil and a reason for a malformed or unknown buffer.
function Codec.decode(b: buffer): (Recording?, string?)
	local ok, result = pcall(decodeUnsafe, b)
	if ok then
		return result, nil
	end
	return nil, tostring(result)
end

-- FNV-1a 32-bit hash of the encoded bytes (recording hash for boards and determinism tests).
function Codec.hash(b: buffer): number
	local h = 2166136261
	for k = 0, buffer.len(b) - 1 do
		h = bit32.bxor(h, buffer.readu8(b, k))
		-- h * 16777619 mod 2^32, split so it stays exact in doubles
		h = ((h * 403) % 4294967296 + bit32.lshift(h, 24)) % 4294967296
	end
	return h
end

return table.freeze(Codec)
