--!strict
-- Heist/RunMarkers: the run bar's next-event markers (MASTERPLAN §7.4 #1, docs/research/premium.md
-- §6.4, "The Sexy Brutale's stopwatch"). Gus and the lasers are deterministic, so the run bar can show
-- them before the kid commits a clone:
--   * gus:    the loop times Gus reaches a corner of his patrol (he turns or waits there), from the
--             compiled route (Sim/Guards.patrol is a pure function of time; a guard who saw nothing
--             walks the same route every loop);
--   * lasers: for each laser your clones switch off at some point, its ON spans (the gaps are the
--             windows): the clones' recordings are replayed through Sim/Mechanisms at a low rate.
-- A forecast for the HUD only; the server decides (live players and busts can change the run).
-- Pure (no engine calls): Lune unit specs run it (tests/unit/HeistRunMarkers.spec.luau).

local Config = require("../Config")
local Codec = require("../Rec/Codec")
local Sampler = require("../Rec/Sampler")
local EventLog = require("../Sim/EventLog")
local Mechanisms = require("../Sim/Mechanisms")

local END = Codec.END

local RunMarkers = {}

export type Span = { t0: number, t1: number }
export type Laser = { index: number, on: { Span } }
export type Markers = { gus: { number }, lasers: { Laser } }

local function angleDiff(a: number, b: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return math.abs(d)
end

-- Loop times in [0, length] when a guard reaches a corner where he turns more than turnDeg, or waits.
function RunMarkers.gusTurns(level: any, length: number, turnDeg: number?, maxTicks: number?): { number }
	local limit = math.rad(turnDeg or Config.Ui.GUS_TURN_DEG)
	local cap = maxTicks or Config.Ui.MAX_GUS_TICKS
	local out: { number } = {}
	for _, g in level.guards or {} do
		local route = g.route
		if route and route.period > 0 then
			local corners: { number } = {}
			for _, leg in route.legs do
				local waits = leg.tEnd - leg.tArrive > 1e-6
				local turn = math.max(angleDiff(leg.yawWalk, leg.yawDwell), angleDiff(leg.yawDwell, leg.yawNext))
				if waits or turn > limit then
					table.insert(corners, leg.tArrive)
				end
			end
			local k = 0
			while k * route.period <= length and #out < cap do
				for _, c in corners do
					local t = c + k * route.period
					if t <= length and #out < cap then
						table.insert(out, t)
					end
				end
				k += 1
			end
		end
	end
	table.sort(out)
	return out
end

-- Is a replayed clone still in the run at t? Clones hold their last pose after their recording ends,
-- unless it ended because they were caught, vanished or were zapped.
local function presentAt(rec: any, t: number): boolean
	if rec.n == 0 then
		return false
	end
	local r = rec.endReason
	if r == END.Caught or r == END.Vanish or r == END.Zapped then
		return t <= Sampler.duration(rec)
	end
	return true
end

-- The ON spans of every laser that the given recordings switch off at least once.
function RunMarkers.laserSpans(level: any, recs: { any }, length: number, hz: number?): { Laser }
	local lasers = level.lasers or {}
	if #lasers == 0 or #recs == 0 or length <= 0 then
		return {}
	end
	local rate = hz or Config.Ui.MARKER_SAMPLE_HZ
	local state = Mechanisms.new(level)
	local log = EventLog.new()
	local actors = {}
	for i in recs do
		actors[i] = { id = i, present = false, x = 0, y = 0, z = 0 }
	end
	local spans: { { Span } } = {}
	local openAt: { number? } = {}
	local everOff: { boolean } = {}
	for i = 1, #lasers do
		spans[i] = {}
		everOff[i] = false
	end
	local steps = math.ceil(length * rate)
	for step = 0, steps do
		local t = math.min(step / rate, length)
		for i, rec in recs do
			local a = actors[i]
			a.present = presentAt(rec, t)
			if a.present then
				local x, y, z = Sampler.at(rec, t)
				a.x, a.y, a.z = x or 0, y, z
			end
		end
		Mechanisms.update(state, step, t, actors, log)
		for i = 1, #lasers do
			local on = state.lasers[i].on
			if on and openAt[i] == nil then
				openAt[i] = t
			elseif not on then
				everOff[i] = true
				local t0 = openAt[i]
				if t0 ~= nil then
					table.insert(spans[i], { t0 = t0, t1 = t })
					openAt[i] = nil
				end
			end
		end
	end
	local out: { Laser } = {}
	for i = 1, #lasers do
		if everOff[i] then
			local t0 = openAt[i]
			if t0 ~= nil and t0 < length then
				table.insert(spans[i], { t0 = t0, t1 = length })
			end
			table.insert(out, { index = i, on = spans[i] })
		end
	end
	return out
end

function RunMarkers.compute(level: any, recs: { any }, length: number): Markers
	return { gus = RunMarkers.gusTurns(level, length), lasers = RunMarkers.laserSpans(level, recs, length) }
end

return RunMarkers
