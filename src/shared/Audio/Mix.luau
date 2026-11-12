--!strict
-- Audio/Mix: the pure mix maths behind the AudioDirector (MASTERPLAN §7.1-7.2, feel.md D5): decibels,
-- slider curves and the Warnings floor, music ducks, Crew Layers tiers and per-mix gains, tonal ladders,
-- the clone arpeggio spacing, the bar grid and the Christmas window. No clocks or engine calls: every
-- time is passed in. tests/unit/AudioMix.spec covers it.

local Mix = {}

export type Sliders = { [string]: number } -- bus name -> 0..1 (Master included)
export type Ducks = { [string]: number } -- reason -> mixer/os time the duck ends

function Mix.dbToGain(db: number): number
	return 10 ^ (db / 20)
end

function Mix.gainToDb(gain: number): number
	if gain <= 0 then
		return -math.huge
	end
	return 20 * math.log10(gain)
end

-- Slider 0..1 -> linear gain with a perceptual curve (exponent 2 = squared).
function Mix.sliderGain(slider: number?, exponent: number): number
	local v = math.clamp(if type(slider) == "number" and slider == slider then slider else 1, 0, 1)
	return v ^ exponent
end

-- Final fader gain of one bus: its authored dB, its own slider and the Master slider, mute. Warnings keep
-- at least `floor` of their level (the Alerts slider floor) and ignore the Music slider by construction.
function Mix.busGain(
	bus: string,
	busDb: { [string]: number },
	sliders: Sliders,
	exponent: number,
	floor: number,
	muted: boolean,
	muteKeepsWarnings: boolean
): number
	local base = Mix.dbToGain(busDb[bus] or 0)
	local master = math.clamp(sliders.Master or 1, 0, 1)
	-- The Clone bus follows the SFX slider (it is a sub-bus of SFX)
	local own = math.clamp(sliders[if bus == "Clone" then "SFX" else bus] or 1, 0, 1)
	if bus == "Warnings" then
		if muted and not muteKeepsWarnings then
			return 0
		end
		return base * math.max(floor, own * master) ^ exponent
	end
	if muted then
		return 0
	end
	return base * (own * master) ^ exponent
end

-- Music duck in dB at `now` (0 when no duck is active). Ducks never stack: the strongest wins.
function Mix.duckDb(ducks: Ducks, now: number, depthDb: number): number
	for _, untilT in ducks do
		if now < untilT then
			return depthDb
		end
	end
	return 0
end

-- Starts (or extends) a duck for `reason` until now + seconds; returns the end time.
function Mix.addDuck(ducks: Ducks, reason: string, now: number, seconds: number): number
	local untilT = math.max(ducks[reason] or -math.huge, now + seconds)
	ducks[reason] = untilT
	return untilT
end

-- Removes expired ducks (keeps the table small).
function Mix.pruneDucks(ducks: Ducks, now: number)
	for reason, untilT in ducks do
		if now >= untilT then
			ducks[reason] = nil
		end
	end
end

-- Crew Layers tier S0..S#thresholds for a clone count (§7.2: S1 at 1+, S2 at 3+, S3 at 6+, S4 at 10+).
function Mix.tierFor(clones: number, thresholds: { number }): number
	local tier = 0
	for i, need in thresholds do
		if clones >= need then
			tier = i
		end
	end
	return tier
end

-- Target gain (0..1) of each player in a music set for a tier.
--   "mixes": one-hot on tierToMix[tier + 1] (the S4 fallback applied to alternate mixes)
--   "stems": S0 always on, stem i on when i - 1 <= tier (additive)
-- A playlist plays one track at a time: `active` (1-based) is on.
function Mix.setGains(
	kind: string,
	mode: string,
	tier: number,
	count: number,
	tierToMix: { number }?,
	active: number?
): { number }
	local gains = table.create(count, 0)
	if count == 0 then
		return gains
	end
	if kind == "playlist" then
		gains[math.clamp(active or 1, 1, count)] = 1
		return gains
	end
	if mode == "stems" then
		for i = 1, count do
			gains[i] = if i - 1 <= tier then 1 else 0
		end
		return gains
	end
	local map = tierToMix or {}
	local idx = map[math.clamp(tier + 1, 1, math.max(1, #map))] or math.min(tier + 1, count)
	gains[math.clamp(idx, 1, count)] = 1
	return gains
end

-- PlaybackSpeed for a step on a semitone ladder (0-based step; beyond the ladder holds the last note).
function Mix.stepSpeed(steps: { number }, step: number): number
	if #steps == 0 then
		return 1
	end
	local i = math.clamp(math.floor(step) + 1, 1, #steps)
	return 2 ^ (steps[i] / 12)
end

-- Random jitter: base * (1 + amount * u) for u in [-1, 1].
function Mix.jitter(base: number, amount: number, u: number): number
	return base * (1 + amount * math.clamp(u, -1, 1))
end

-- Start offsets (seconds) of an n-note clone arpeggio: `stagger` apart, squeezed so the whole run never
-- spreads wider than maxSpread (feel.md D2: 60 ms apart, total stagger capped at 0.4 s).
function Mix.arpeggioOffsets(n: number, stagger: number, maxSpread: number): { number }
	local out = {}
	if n <= 0 then
		return out
	end
	local gap = stagger
	if n > 1 and (n - 1) * stagger > maxSpread then
		gap = maxSpread / (n - 1)
	end
	for i = 1, n do
		out[i] = (i - 1) * gap
	end
	return out
end

-- Seconds per bar (4/4 unless beatsPerBar is given).
function Mix.barSeconds(bpm: number, beatsPerBar: number?): number
	return (beatsPerBar or 4) * 60 / bpm
end

-- The first bar line at or after `now` for music that started at `startedAt` (same clock).
function Mix.nextBar(startedAt: number, now: number, bpm: number, beatsPerBar: number?): number
	local bar = Mix.barSeconds(bpm, beatsPerBar)
	if now <= startedAt then
		return startedAt
	end
	local n = math.ceil((now - startedAt) / bar - 1e-9)
	return startedAt + n * bar
end

-- Countdown step for the last `from` seconds of a run: 0 at `from` seconds left, nil outside the window.
function Mix.countdownStep(secondsLeft: number, from: number): number?
	local s = math.ceil(secondsLeft - 1e-9)
	if s < 1 or s > from then
		return nil
	end
	return from - s
end

local function dayNumber(y: number, m: number, d: number): number
	-- days since 1970-01-01 (proleptic Gregorian), Howard Hinnant's days_from_civil
	local yy = if m <= 2 then y - 1 else y
	local era = (if yy >= 0 then yy else yy - 399) // 400
	local yoe = yy - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end
Mix.dayNumber = dayNumber

-- Is the UTC day { year, month, day } inside the inclusive window { from = {y,m,d}, to = {y,m,d} }?
function Mix.inWindow(day: { number }, window: { from: { number }, to: { number } }): boolean
	local n = dayNumber(day[1], day[2], day[3])
	return n >= dayNumber(window.from[1], window.from[2], window.from[3])
		and n <= dayNumber(window.to[1], window.to[2], window.to[3])
end

return Mix
