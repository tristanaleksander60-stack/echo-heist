--!strict
-- Analytics/PerfSample: client frame-time sampling, aggregation and the performance-tier governor
-- (pure; Lune-tested). MASTERPLAN §8.6 ("one rate-limited sample every 60 s: median and p95 frame
-- time, device platform, memory tier, graphics quality, clone count on screen"), §6.3 (runtime
-- tier steps down when p95 > 33 ms for 20 s), §6.8 (16.6 ms mid phone target, 33 ms low ceiling).
-- "p95 > 33 ms" is read as "slower than 30 fps": a frame is slow above Config SLOW_MS (36 ms), so a
-- device held at exactly 30 fps by the OS never steps down (docs/ANALYTICS.md "PerfSample").
--
-- Client wiring (later, src/client): every RenderStepped dt -> PerfSample.add(window, dt) and
-- PerfSample.govern(governor, dt); every INTERVAL_SECONDS: summary -> PerfSample.pack -> Net.Send
-- ("Analytics.Perf", ...) -> PerfSample.reset. The server re-validates with PerfSample.unpack.
-- Frame times live in a fixed histogram (BIN_MS bins up to MAX_MS plus an overflow bin), so a
-- minute of 60 fps costs no allocation and percentiles are exact to BIN_MS.

local Config = require("../Config")
local Events = require("./Events")

local P = Config.Analytics.Perf

export type Window = {
	bins: { number },
	overflow: number,
	frames: number,
	seconds: number,
	sumMs: number,
	worstMs: number,
	slow: number, -- frames slower than SLOW_MS
}

export type Summary = {
	frames: number,
	seconds: number,
	meanMs: number,
	medianMs: number,
	p95Ms: number,
	p99Ms: number,
	worstMs: number,
	slowShare: number, -- 0..1, frames slower than SLOW_MS
}

export type Governor = {
	secFrames: number,
	secSlow: number,
	secTime: number,
	slowSeconds: number, -- slow seconds in a row
	streakFrames: number, -- frames in those seconds
	streakSlow: number, -- slow frames in those seconds
	cooldown: number, -- seconds left before the governor judges again
	steps: number, -- step-downs so far
	lastShare: number?, -- slow share of the streak that caused the last step
	stalled: boolean, -- a step did not cut the slow share: no more steps this session
	goodSeconds: number, -- good seconds in a row (at most STEP_UP_SHARE slow frames each)
	ups: number, -- step-ups so far (each doubles the good stretch the next one needs)
}

-- What a client script can read about its device (UserInputService, GuiService, VRService, the
-- camera). There is no OS: UserInputService GetPlatform, GetDeviceType and GetDeviceLevel need the
-- RobloxScript capability (checked in a live server, 2026-11-12), so the OS split is Roblox's own
-- Performance and Retention pages, by platform.
export type DeviceFacts = {
	touch: boolean,
	keyboard: boolean,
	gamepad: boolean,
	vr: boolean,
	tenFoot: boolean, -- GuiService:IsTenFootInterface()
	viewportMin: number, -- shorter side of the camera viewport, px
}

export type Sample = {
	medianMs: number,
	p95Ms: number,
	worstMs: number,
	frames: number,
	seconds: number,
	device: string,
	quality: number, -- SavedQualityLevel 0 (automatic) .. 10
	memMb: number,
	clones: number,
	perfTier: string,
}

local PerfSample = {}

local NBINS = math.floor(P.MAX_MS / P.BIN_MS + 0.5)
PerfSample.NBINS = NBINS
-- longest window the server accepts: twice the largest perfIntervalSeconds LiveFlag
local MAX_WINDOW_SECONDS = 2 * Config.LiveFlags.Flags.perfIntervalSeconds.max

---------------------------------------------------------------------------
-- Window (histogram)
---------------------------------------------------------------------------

function PerfSample.new(): Window
	return { bins = table.create(NBINS, 0), overflow = 0, frames = 0, seconds = 0, sumMs = 0, worstMs = 0, slow = 0 }
end

function PerfSample.reset(w: Window)
	table.clear(w.bins)
	for i = 1, NBINS do
		w.bins[i] = 0
	end
	w.overflow = 0
	w.frames = 0
	w.seconds = 0
	w.sumMs = 0
	w.worstMs = 0
	w.slow = 0
end

-- Adds one frame (dt in seconds). Pauses (dt > MAX_FRAME_SECONDS) and junk are ignored.
function PerfSample.add(w: Window, dt: number): boolean
	if not (dt > 0) or dt > P.MAX_FRAME_SECONDS then
		return false
	end
	local ms = dt * 1000
	w.frames += 1
	w.seconds += dt
	w.sumMs += ms
	if ms > w.worstMs then
		w.worstMs = ms
	end
	if ms > P.SLOW_MS then
		w.slow += 1
	end
	if ms >= P.MAX_MS then
		w.overflow += 1
	else
		local i = math.floor(ms / P.BIN_MS) + 1
		w.bins[i] += 1
	end
	return true
end

-- The q-quantile (0..1) in ms: the upper edge of the bin holding it (worst frame for overflow).
function PerfSample.percentile(w: Window, q: number): number
	if w.frames == 0 then
		return 0
	end
	local target = math.max(1, math.ceil(math.clamp(q, 0, 1) * w.frames))
	local acc = 0
	for i = 1, NBINS do
		acc += w.bins[i]
		if acc >= target then
			return math.min(i * P.BIN_MS, w.worstMs)
		end
	end
	return w.worstMs
end

-- nil while the window has fewer than MIN_FRAMES frames (backgrounded, loading).
function PerfSample.summary(w: Window): Summary?
	if w.frames < P.MIN_FRAMES then
		return nil
	end
	return {
		frames = w.frames,
		seconds = w.seconds,
		meanMs = w.sumMs / w.frames,
		medianMs = PerfSample.percentile(w, 0.5),
		p95Ms = PerfSample.percentile(w, 0.95),
		p99Ms = PerfSample.percentile(w, 0.99),
		worstMs = w.worstMs,
		slowShare = w.slow / w.frames,
	}
end

---------------------------------------------------------------------------
-- Governor: p95 > SLOW_MS for STEP_DOWN_SECONDS -> step the performance tier down (§8.6).
-- p95 > SLOW_MS is the same as "more than 5% of the frames are slower than SLOW_MS", so each
-- second is judged by its slow share without sorting. Stepping back up has hysteresis
-- (PerfSample.stepUp): STEP_UP_SECONDS good seconds in a row (at most STEP_UP_SHARE slow frames
-- each) undo one step down, and each step up multiplies the next wait by STEP_UP_BACKOFF, so a
-- device on the edge settles instead of oscillating. A step that did not cut the slow share by
-- STEP_MIN_GAIN (the next slow streak is about as slow as the one before it) stops the governor:
-- the bottleneck is something a quality tier cannot fix (an OS frame cap, a CPU-bound device), and
-- stepping on would only ratchet quality to the minimum.
---------------------------------------------------------------------------

function PerfSample.governor(): Governor
	return {
		secFrames = 0,
		secSlow = 0,
		secTime = 0,
		slowSeconds = 0,
		streakFrames = 0,
		streakSlow = 0,
		cooldown = 0,
		steps = 0,
		lastShare = nil,
		stalled = false,
		goodSeconds = 0,
		ups = 0,
	}
end

local function endStreak(g: Governor)
	g.slowSeconds, g.streakFrames, g.streakSlow = 0, 0, 0
end

-- Feeds one frame. Returns true exactly when the tier should step down now.
function PerfSample.govern(g: Governor, dt: number): boolean
	if not (dt > 0) or dt > P.MAX_FRAME_SECONDS then
		return false
	end
	g.secFrames += 1
	g.secTime += dt
	if dt * 1000 > P.SLOW_MS then
		g.secSlow += 1
	end
	if g.secTime < 1 then
		return false
	end
	local frames, slow = g.secFrames, g.secSlow
	g.secFrames, g.secSlow, g.secTime = 0, 0, 0
	if frames >= P.MIN_FRAMES_PER_SECOND and slow / frames <= P.STEP_UP_SHARE then
		g.goodSeconds += 1
	elseif frames >= P.MIN_FRAMES_PER_SECOND then
		g.goodSeconds = 0
	end
	if g.stalled then
		return false
	end
	if g.cooldown > 0 then
		g.cooldown -= 1
		endStreak(g)
		return false
	end
	if frames < P.MIN_FRAMES_PER_SECOND then
		-- a long hitch: under 10 frames in a second is slow by any measure, but it is usually a
		-- load, so it neither counts nor resets the streak
		return false
	end
	if slow / frames > P.STEP_DOWN_SHARE then
		g.slowSeconds += 1
		g.streakFrames += frames
		g.streakSlow += slow
	else
		endStreak(g)
	end
	if g.slowSeconds >= P.STEP_DOWN_SECONDS then
		local share = g.streakSlow / g.streakFrames
		endStreak(g)
		local last = g.lastShare
		if last and share > last * (1 - P.STEP_MIN_GAIN) then
			g.stalled = true
			return false
		end
		g.lastShare = share
		g.cooldown = P.STEP_COOLDOWN_SECONDS
		g.steps += 1
		g.goodSeconds = 0
		return true
	end
	return false
end

-- Call after govern each frame. Returns true exactly when the tier should step back up one
-- step now: only undoes earlier step-downs, after a long good stretch that doubles every time.
-- A step up re-arms the governor (it may step down again, judged afresh).
function PerfSample.stepUp(g: Governor): boolean
	if g.steps <= g.ups then
		return false
	end
	local need = P.STEP_UP_SECONDS * P.STEP_UP_BACKOFF ^ g.ups
	if g.goodSeconds < need then
		return false
	end
	g.goodSeconds = 0
	g.ups += 1
	g.stalled = false
	g.lastShare = nil
	g.cooldown = P.STEP_COOLDOWN_SECONDS
	endStreak(g)
	return true
end

---------------------------------------------------------------------------
-- Device class (Events.DOMAINS.device)
---------------------------------------------------------------------------

-- vr | console (ten-foot UI) | phone / tablet (touch without a keyboard; tablet from a short side
-- of TABLET_MIN_SIDE px) | desktop (everything with a keyboard or without touch, touch laptops too).
function PerfSample.deviceClass(d: DeviceFacts): string
	if d.vr then
		return "vr"
	end
	if d.tenFoot then
		return "console"
	end
	if d.touch and not d.keyboard then
		return if d.viewportMin >= P.TABLET_MIN_SIDE then "tablet" else "phone"
	end
	return "desktop"
end

---------------------------------------------------------------------------
-- Remote payload (client -> server). Positional numbers and short strings only.
---------------------------------------------------------------------------

local function r1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

-- Arguments for Net.Send("Analytics.Perf", ...), in this order.
function PerfSample.pack(
	s: Summary,
	device: string,
	quality: number,
	memMb: number,
	clones: number,
	perfTier: string
): (number, number, number, number, number, string, number, number, number, string)
	return r1(s.medianMs),
		r1(s.p95Ms),
		r1(math.min(s.worstMs, 5000)),
		s.frames,
		r1(s.seconds),
		device,
		math.clamp(math.floor(quality), 0, 10),
		math.clamp(math.floor(memMb), 0, 65535),
		math.clamp(math.floor(clones), 0, 64),
		perfTier
end

local function finite(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and v >= lo and v <= hi
end

local function whole(v: any, lo: number, hi: number): boolean
	return finite(v, lo, hi) and math.floor(v) == v
end

-- Server-side check of a client sample. Never trust the client: ranges, order and plausibility.
function PerfSample.unpack(
	medianMs: any,
	p95Ms: any,
	worstMs: any,
	frames: any,
	seconds: any,
	device: any,
	quality: any,
	memMb: any,
	clones: any,
	perfTier: any
): (Sample?, string?)
	if not (finite(medianMs, 0, 1000) and finite(p95Ms, 0, 1000) and finite(worstMs, 0, 5000)) then
		return nil, "ms"
	end
	if medianMs > p95Ms + P.BIN_MS or p95Ms > worstMs + P.BIN_MS then
		return nil, "order"
	end
	local maxSeconds = MAX_WINDOW_SECONDS
	if not (whole(frames, P.MIN_FRAMES, 1000 * maxSeconds) and finite(seconds, 1, maxSeconds)) then
		return nil, "window"
	end
	if frames / seconds > 1000 then
		return nil, "rate"
	end
	if type(device) ~= "string" or not Events.DOMAINS.device.set[device] then
		return nil, "device"
	end
	if type(perfTier) ~= "string" or not Events.DOMAINS.perfTier.set[perfTier] then
		return nil, "tier"
	end
	if not (whole(quality, 0, 10) and whole(memMb, 0, 65535) and whole(clones, 0, 64)) then
		return nil, "ints"
	end
	return {
		medianMs = medianMs,
		p95Ms = p95Ms,
		worstMs = worstMs,
		frames = frames,
		seconds = seconds,
		device = device,
		quality = quality,
		memMb = memMb,
		clones = clones,
		perfTier = perfTier,
	},
		nil
end

-- Custom event fields and values for a validated sample: PerfSample{device, p95 bucket, clones}
-- with value = p95 ms, and PerfDetail{device, quality, memory} with value = median ms.
function PerfSample.events(s: Sample): { { name: string, fields: { string }, value: number } }
	return {
		{
			name = "PerfSample",
			fields = Events.fields(Events.CUSTOM.PerfSample.fields, { s.device, s.p95Ms, s.clones }),
			value = r1(s.p95Ms),
		},
		{
			name = "PerfDetail",
			fields = Events.fields(Events.CUSTOM.PerfDetail.fields, { s.device, s.quality, s.memMb }),
			value = r1(s.medianMs),
		},
	}
end

return table.freeze(PerfSample)
