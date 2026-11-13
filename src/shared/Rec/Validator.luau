--!strict
-- Rec/Validator: anti-exploit checks on recorded movement and events.
-- MASTERPLAN §8.8. Pure Luau; level geometry and door state are injected.
--
-- Movement rules, per 20 Hz sample, from the server's own view:
--   * horizontal speed <= WalkSpeed x SPEED_MULT, through a leaky bucket whose
--     slack grows with ping (lag bursts pass, sustained speed does not). SPEED_MULT
--     sits above the sprint (Config.Sprint.MULT): a sprint needs no event and never
--     taints (anyone may sprint at any time, so a Sprint flag would allow the same)
--   * one step bigger than the whole bucket is a TELEPORT
--   * vertical rise <= JumpHeight + RISE_MARGIN above the last grounded sample
--   * no segment through a no-go box or a closed dynamic blocker
--   * positions finite and inside the format range
--   * a cut sample (server teleport) is exempt only when a Respawn or Teleport
--     event within one tick backs it; otherwise it is checked as a normal move
--   * a slide (Config.Slide): a Slide event (recorded by the server, Sim/Interact.slide)
--     raises the allowed speed by BURST x ALLOW_MARGIN for the samples strictly after
--     it, up to WINDOW_SECONDS + WINDOW_GRACE + ping later; Slide events closer than
--     SERVER_COOLDOWN, or with an arg other than 0 (the fast slide is gone), open no
--     window (and fail checkEvents).
--     The window is read from the recording itself, so streaming (Validator.step) and
--     whole-run validation give the same result.
-- Violations are clamped in place (the last valid sample advanced at max speed
-- toward the reported one) and the run is tainted: it still plays, but never
-- earns medals or board entries. No kicks on movement alone.
--
-- Event rules: known kind, time inside the run and in order, nothing after a
-- terminal event (Caught, Vanish), holds balanced, at most MAX_EVENTS.
--
-- Streaming use (server, inside the sim tick):
--   local v = Validator.new(rec, opts)
--   ... Sampler.record(rec, tick, ...); Validator.step(v)  -- clamps new samples
-- Whole-run use (tests, ghost audits): Validator.validate(rec, opts)

local Config = require("../Config")
local Codec = require("./Codec")

type Recording = Codec.Recording

export type Box = {
	minX: number,
	minY: number,
	minZ: number,
	maxX: number,
	maxY: number,
	maxZ: number,
}

-- isBlocked(t, x0, y0, z0, x1, y1, z1): true when the segment crosses a closed
-- dynamic blocker (door) at loop time t. Supplied by the sim.
export type BlockedFn = (number, number, number, number, number, number, number) -> boolean

export type Options = {
	walkSpeed: number?, -- server-set Humanoid.WalkSpeed (default Config.Rec.WALK_SPEED)
	ping: number?, -- seconds, the player's measured round trip
	jumpHeight: number?,
	noGo: { Box }?, -- static EH_NoGo volumes and room walls, level space, axis aligned
	isBlocked: BlockedFn?,
}

export type Violation = { index: number, t: number, flag: number }

export type State = {
	rec: Recording,
	checked: number, -- samples already validated
	maxSpeed: number,
	capacity: number, -- bucket size in studs
	bucket: number,
	groundY: number,
	jumpHeight: number,
	noGo: { Box },
	isBlocked: BlockedFn?,
	flags: number,
	clamped: number,
	violations: { Violation },
	ping: number, -- seconds (clamped), widens the slide window's tail
	slideCursor: number, -- events already looked at for Slide windows
	slideFrom: number, -- the open slide window (loop time): samples in (from, to] get `slideExtra`
	slideTo: number,
	slideExtra: number, -- studs/s added to maxSpeed inside the window
	slideReady: number, -- loop time from which the next Slide event may open a window
}

export type Report = {
	tainted: boolean,
	flags: number,
	clamped: number, -- samples changed
	violations: { Violation }, -- first MAX_VIOLATIONS_LOGGED
}

local Validator = {}

Validator.FLAG = table.freeze({
	SPEED = 1,
	TELEPORT = 2,
	RISE = 4,
	NOGO = 8,
	BOUNDS = 16,
	NONFINITE = 32,
	EVENT = 64,
})

local FLAG = Validator.FLAG
local EVENT = Codec.EVENT
local GROUNDED = Codec.FLAG.GROUNDED
local snapPos = Codec.snapPos
local EPS = 1e-6

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

local function note(state: State, index: number, flag: number)
	state.flags = bit32.bor(state.flags, flag)
	if #state.violations < Config.Rec.MAX_VIOLATIONS_LOGGED then
		table.insert(state.violations, { index = index, t = (index - 1) / state.rec.hz, flag = flag })
	end
end

local function inside(b: Box, x: number, y: number, z: number): boolean
	return x > b.minX and x < b.maxX and y > b.minY and y < b.maxY and z > b.minZ and z < b.maxZ
end

-- One slab of the segment-box test: narrows [tmin, tmax] to where o + d * t lies in [lo, hi].
local function slab(o: number, d: number, lo: number, hi: number, tmin: number, tmax: number): (number, number)
	if math.abs(d) < 1e-12 then
		if o <= lo or o >= hi then
			return 1, 0
		end
		return tmin, tmax
	end
	local t1, t2 = (lo - o) / d, (hi - o) / d
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	return math.max(tmin, t1), math.min(tmax, t2)
end

-- Slab test: does the segment p0 -> p1 enter box b? (Allocation free.)
function Validator.segmentHitsBox(
	b: Box,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number
): boolean
	local tmin, tmax = slab(x0, x1 - x0, b.minX, b.maxX, 0, 1)
	if tmin >= tmax then
		return false
	end
	tmin, tmax = slab(y0, y1 - y0, b.minY, b.maxY, tmin, tmax)
	if tmin >= tmax then
		return false
	end
	tmin, tmax = slab(z0, z1 - z0, b.minZ, b.maxZ, tmin, tmax)
	return tmin < tmax
end

-- True when an exemption event (Respawn, Teleport) lies within one tick of sample i.
local function exempt(rec: Recording, i: number): boolean
	local t = (i - 1) / rec.hz
	local window = 1 / rec.hz + EPS
	for _, e in rec.events do
		if (e.kind == EVENT.Respawn or e.kind == EVENT.Teleport) and math.abs(e.t - t) <= window then
			return true
		end
	end
	return false
end

function Validator.new(rec: Recording, opts: Options?): State
	local o: Options = opts or {}
	local maxSpeed = (o.walkSpeed or Config.Rec.WALK_SPEED) * Config.Rec.SPEED_MULT
	local ping = math.clamp(o.ping or 0, 0, Config.Rec.PING_ALLOWANCE_CAP)
	return {
		rec = rec,
		checked = 0,
		maxSpeed = maxSpeed,
		capacity = Config.Rec.SPEED_BUCKET_STUDS + maxSpeed * ping,
		ping = ping,
		slideCursor = 0,
		slideFrom = math.huge,
		slideTo = -math.huge,
		slideExtra = 0,
		slideReady = -math.huge,
		bucket = 0,
		groundY = 0,
		jumpHeight = o.jumpHeight or Config.Rec.JUMP_HEIGHT,
		noGo = o.noGo or {},
		isBlocked = o.isBlocked,
		flags = 0,
		clamped = 0,
		violations = {},
	}
end

-- The extra speed (studs/s) a Slide event with this arg allows, or nil for an unknown arg (only 0: one slide kind).
function Validator.slideExtra(arg: number): number?
	if arg ~= 0 then
		return nil
	end
	return Config.Slide.BURST * Config.Slide.ALLOW_MARGIN
end

-- Opens slide windows for the Slide events at or before loop time t (events in time order).
local function advanceSlides(state: State, t: number)
	local events = state.rec.events
	local SL = Config.Slide
	local k = state.slideCursor
	while k < #events and events[k + 1].t <= t + EPS do
		k += 1
		local e = events[k]
		if e.kind == EVENT.Slide and e.t >= state.slideReady - EPS then
			local extra = Validator.slideExtra(e.arg)
			if extra then
				state.slideFrom = e.t
				state.slideTo = e.t + SL.WINDOW_SECONDS + SL.WINDOW_GRACE + state.ping
				state.slideExtra = extra
				state.slideReady = e.t + SL.SERVER_COOLDOWN
			end
		end
	end
	state.slideCursor = k
end

-- Heavy loot lowers WalkSpeed mid-run; the server tells the validator.
function Validator.setWalkSpeed(state: State, walkSpeed: number)
	state.maxSpeed = walkSpeed * Config.Rec.SPEED_MULT
end

local function blocked(
	state: State,
	i: number,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number
): boolean
	for _, b in state.noGo do
		if not inside(b, x0, y0, z0) and Validator.segmentHitsBox(b, x0, y0, z0, x1, y1, z1) then
			return true
		end
	end
	local fn = state.isBlocked
	if fn and fn((i - 1) / state.rec.hz, x0, y0, z0, x1, y1, z1) then
		return true
	end
	return false
end

-- Checks sample i against the already validated sample i - 1; clamps in place.
local function checkSample(state: State, i: number)
	local rec = state.rec
	local px, py, pz = rec.px, rec.py, rec.pz
	local x, y, z = px[i], py[i], pz[i]
	local grounded = bit32.band(rec.flags[i], GROUNDED) ~= 0

	if i == 1 then
		if not (finite(x) and finite(y) and finite(z)) then
			note(state, i, FLAG.NONFINITE)
			x, y, z = 0, 0, 0
		end
		px[i], py[i], pz[i] = snapPos(x), snapPos(y), snapPos(z)
		state.groundY = py[i]
		return
	end

	local x0, y0, z0 = px[i - 1], py[i - 1], pz[i - 1]
	local dt = 1 / rec.hz
	local changed = false

	if not (finite(x) and finite(y) and finite(z)) then
		note(state, i, FLAG.NONFINITE)
		x, y, z = x0, y0, z0
		changed = true
	end
	if
		x < Codec.POS_MIN
		or x > Codec.POS_MAX
		or y < Codec.POS_MIN
		or y > Codec.POS_MAX
		or z < Codec.POS_MIN
		or z > Codec.POS_MAX
	then
		note(state, i, FLAG.BOUNDS)
		x, y, z = x0, y0, z0
		changed = true
	end

	if rec.cut[i] then
		if exempt(rec, i) then
			-- Server teleport: start fresh from here.
			state.bucket = 0
			state.groundY = y
			if changed then
				state.clamped += 1
				px[i], py[i], pz[i] = snapPos(x), snapPos(y), snapPos(z)
			end
			return
		end
		-- A cut nobody granted is just a jump in position.
		rec.cut[i] = nil
	end

	-- Horizontal speed (leaky bucket) and teleports; a slide window raises the speed.
	local t = (i - 1) / rec.hz
	advanceSlides(state, t)
	local speed = state.maxSpeed
	if t > state.slideFrom + EPS and t <= state.slideTo + EPS then
		speed += state.slideExtra
	end
	local dx, dz = x - x0, z - z0
	local dist = math.sqrt(dx * dx + dz * dz)
	local maxStep = speed * dt
	local excess = dist - maxStep
	local bucket = math.max(0, state.bucket + excess)
	if excess > state.capacity + EPS then
		note(state, i, FLAG.TELEPORT)
	elseif bucket > state.capacity + EPS then
		note(state, i, FLAG.SPEED)
	end
	if bucket > state.capacity + EPS then
		-- Clamp: advance from the last valid sample at max speed toward the report.
		local s = maxStep / dist
		x, z = x0 + dx * s, z0 + dz * s
		bucket = state.capacity
		changed = true
	end
	state.bucket = bucket

	-- Vertical rise: never above the jump apex over the last ground, and never
	-- faster than a jump launch (limits a faked grounded flag).
	local ceiling =
		math.min(state.groundY + state.jumpHeight + Config.Rec.RISE_MARGIN, y0 + Config.Rec.MAX_RISE_SPEED * dt)
	if y > ceiling + EPS then
		note(state, i, FLAG.RISE)
		y = math.max(ceiling, y0)
		changed = true
	end

	-- No-go volumes and closed blockers.
	if blocked(state, i, x0, y0, z0, x, y, z) then
		note(state, i, FLAG.NOGO)
		x, y, z = x0, y0, z0
		changed = true
	end

	if changed then
		state.clamped += 1
		px[i], py[i], pz[i] = snapPos(x), snapPos(y), snapPos(z)
	end
	if grounded then
		state.groundY = py[i]
	end
end

-- Validates every sample recorded since the last call. Returns the new flag bits.
function Validator.step(state: State): number
	local before = state.flags
	local rec = state.rec
	for i = state.checked + 1, rec.n do
		checkSample(state, i)
	end
	state.checked = rec.n
	rec.vflags = bit32.bor(rec.vflags, state.flags)
	return bit32.band(state.flags, bit32.bnot(before))
end

-- Checks the event list. Returns the flag bits (0 or EVENT) and adds violations to state.
function Validator.checkEvents(state: State): number
	local rec = state.rec
	local events = rec.events
	local bad = false
	local function fail(k: number)
		bad = true
		if #state.violations < Config.Rec.MAX_VIOLATIONS_LOGGED then
			table.insert(state.violations, { index = -k, t = events[k].t, flag = FLAG.EVENT })
		end
	end
	if #events > Config.Rec.MAX_EVENTS then
		bad = true
	end
	local tEnd = (math.max(rec.n, 1) - 1) / rec.hz + 1 / rec.hz + EPS
	local lastT = 0
	local ended = false
	local holding = false
	local slideReady = -math.huge
	for k, e in events do
		local kind = e.kind
		-- One branch per rejection reason, on purpose (same action, different rule)
		-- selene: allow(if_same_then_else)
		if kind < 1 or kind > Codec.EVENT_COUNT or kind ~= math.floor(kind) then
			fail(k)
		elseif rec.n == 0 or not finite(e.t) or e.t < -EPS or e.t > tEnd then
			fail(k)
		elseif e.t < lastT - EPS then
			fail(k)
		elseif ended then
			fail(k)
		elseif kind == EVENT.HoldStart and holding then
			fail(k)
		elseif kind == EVENT.HoldEnd and not holding then
			fail(k)
		elseif kind == EVENT.Slide and (Validator.slideExtra(e.arg) == nil or e.t < slideReady - EPS) then
			fail(k)
		end
		if kind == EVENT.Slide and finite(e.t) and e.t >= slideReady - EPS and Validator.slideExtra(e.arg) then
			slideReady = e.t + Config.Slide.SERVER_COOLDOWN
		end
		if finite(e.t) then
			lastT = math.max(lastT, e.t)
		end
		if kind == EVENT.HoldStart then
			holding = true
		elseif kind == EVENT.HoldEnd then
			holding = false
		elseif kind == EVENT.Caught or kind == EVENT.Vanish then
			ended = true
		end
	end
	if bad then
		state.flags = bit32.bor(state.flags, FLAG.EVENT)
		rec.vflags = bit32.bor(rec.vflags, FLAG.EVENT)
		return FLAG.EVENT
	end
	return 0
end

function Validator.report(state: State): Report
	return {
		tainted = state.flags ~= 0,
		flags = state.flags,
		clamped = state.clamped,
		violations = state.violations,
	}
end

-- Validates a whole recording in place (samples and events) and sets rec.vflags.
function Validator.validate(rec: Recording, opts: Options?): Report
	local state = Validator.new(rec, opts)
	Validator.step(state)
	Validator.checkEvents(state)
	return Validator.report(state)
end

function Validator.isTainted(rec: Recording): boolean
	return rec.vflags ~= 0
end

return table.freeze(Validator)
