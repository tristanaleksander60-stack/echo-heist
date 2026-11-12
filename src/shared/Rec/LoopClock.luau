--!strict
-- Rec/LoopClock: the run's time base. MASTERPLAN §3.1, §8.2, §8.10. Pure Luau:
-- the caller passes server time (workspace:GetServerTimeNow() on both sides),
-- so tests drive it with plain numbers.
--
-- A clock is plain data, safe to replicate as attributes:
--   loopT = anchorLoopT + (serverNow - anchorServerTime) * rate, clamped to [0, length]
-- Fast-forward changes `rate` and re-anchors; Relaxed changes `length`, never the rate.
-- The sim runs whole ticks: tick k covers loop time k / hz.

local Config = require("../Config")

export type Clock = {
	anchorServerTime: number,
	anchorLoopT: number,
	rate: number,
	length: number, -- run length in loop seconds
}

local LoopClock = {}

local EPS = 1e-7

-- Run length for a level's base length, with the Relaxed bonus, capped at the hard ceiling.
function LoopClock.lengthFor(baseSeconds: number, relaxed: boolean?): number
	local length = if relaxed then baseSeconds * Config.Rec.RELAXED_LENGTH_MULT else baseSeconds
	return math.min(length, Config.Rec.LOOP_MAX_SECONDS)
end

-- A clock whose loop time 0 is at server time `startServerTime`.
function LoopClock.new(startServerTime: number, length: number, rate: number?): Clock
	assert(length > 0 and length <= Config.Rec.LOOP_MAX_SECONDS, "LoopClock.new: length out of range")
	local r = rate or 1
	assert(r > 0, "LoopClock.new: rate must be positive")
	return table.freeze({
		anchorServerTime = startServerTime,
		anchorLoopT = 0,
		rate = r,
		length = length,
	})
end

-- Unclamped loop time (negative before the start, past `length` after the end).
function LoopClock.rawT(clock: Clock, serverNow: number): number
	return clock.anchorLoopT + (serverNow - clock.anchorServerTime) * clock.rate
end

-- Loop time in [0, length].
function LoopClock.t(clock: Clock, serverNow: number): number
	return math.clamp(LoopClock.rawT(clock, serverNow), 0, clock.length)
end

-- Server time at which loop time `loopT` happens (or happened) at the current rate.
function LoopClock.serverTimeAt(clock: Clock, loopT: number): number
	return clock.anchorServerTime + (loopT - clock.anchorLoopT) / clock.rate
end

function LoopClock.remaining(clock: Clock, serverNow: number): number
	return clock.length - LoopClock.t(clock, serverNow)
end

function LoopClock.isOver(clock: Clock, serverNow: number): boolean
	return LoopClock.rawT(clock, serverNow) >= clock.length - EPS
end

-- Same loop time now, new rate from now on (fast-forward on/off).
function LoopClock.setRate(clock: Clock, serverNow: number, rate: number): Clock
	assert(rate > 0, "LoopClock.setRate: rate must be positive")
	return table.freeze({
		anchorServerTime = serverNow,
		anchorLoopT = LoopClock.t(clock, serverNow),
		rate = rate,
		length = clock.length,
	})
end

-- Co-op waiting squeeze: remaining time becomes min(remaining, seconds).
function LoopClock.squeeze(clock: Clock, serverNow: number, seconds: number?): Clock
	local s = seconds or Config.Rec.WAIT_SQUEEZE_SECONDS
	local length = math.min(clock.length, LoopClock.t(clock, serverNow) + s)
	return table.freeze({
		anchorServerTime = clock.anchorServerTime,
		anchorLoopT = clock.anchorLoopT,
		rate = clock.rate,
		length = math.max(length, EPS),
	})
end

-- END RUN is locked for the first END_RUN_LOCK_SECONDS of a run.
function LoopClock.canEndRun(clock: Clock, serverNow: number): boolean
	return LoopClock.rawT(clock, serverNow) >= Config.Rec.END_RUN_LOCK_SECONDS - EPS
end

-- Tick index whose time is at or before loop time t.
function LoopClock.tickAt(t: number, hz: number): number
	return math.floor(t * hz + EPS)
end

function LoopClock.timeOfTick(tick: number, hz: number): number
	return tick / hz
end

-- Index of the last tick of a run (its time is <= length).
function LoopClock.lastTick(clock: Clock, hz: number): number
	return LoopClock.tickAt(clock.length, hz)
end

-- Fixed-step accumulator: `nextTick` is the next tick the sim has not run yet
-- (0 at loop start). Returns how many ticks to run now (capped against hitches),
-- never past the run's last tick and never before loop time 0.
function LoopClock.ticksDue(clock: Clock, serverNow: number, nextTick: number, hz: number): number
	local raw = LoopClock.rawT(clock, serverNow)
	if raw < -EPS then
		return 0
	end
	local target = math.min(LoopClock.tickAt(math.min(raw, clock.length), hz), LoopClock.lastTick(clock, hz))
	local due = target - nextTick + 1
	if due <= 0 then
		return 0
	end
	return math.min(due, Config.Rec.MAX_CATCHUP_TICKS)
end

-- Lag fairness (§8.10): a live player's hazard checks use the mechanism state at
-- t minus their one-way latency, capped at LAG_REWIND_CAP. The player is favoured.
function LoopClock.hazardTime(t: number, oneWayLatency: number): number
	local lag = math.clamp(if oneWayLatency == oneWayLatency then oneWayLatency else 0, 0, Config.Rec.LAG_REWIND_CAP)
	return math.max(t - lag, 0)
end

return table.freeze(LoopClock)
