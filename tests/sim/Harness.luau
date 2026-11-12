-- Drives HeistSim with Bots for the L2 specs (not a spec itself).
--   Harness.level(n)                  compiled launch level n (1-4)
--   Harness.play(level, plan, opts)   plays a whole heist from a plan:
--     plan = {
--       players = {ids}?  (default {1}),
--       runs = { { [playerId] = steps, deck = {{id, op, n}}?, delay = {[id] = ticks}? } },
--       latency = {[id] = ticks}?     (one-way delay for every run; also set as the sim's
--                                      measured latency, so the §8.10 rewind applies)
--     }
--   returns sim, runs (each: copy of sim.lastRun plus `lines` = event log lines and
--   `phase` after the run). Steps for a player missing from a run default to {stay}.

local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Catalog = require("../../src/shared/Levels/Catalog")
local Bot = require("./Bot")

local Harness = {}

local HIST = 32

function Harness.level(n: number): any
	return LevelSpec.compile(Catalog[n])
end

-- Rolling history of what clients can see (doors, lasers) after each tick.
function Harness.history()
	local h = { ticks = {}, states = {} }
	function h.push(sim: any)
		local slot = sim.tick % HIST + 1
		local doors, lasers = {}, {}
		for i, d in sim.mech.doors do
			doors[i] = { open = d.open, solid = d.solid, solidAt = d.solidAt }
		end
		for i, l in sim.mech.lasers do
			lasers[i] = { on = l.on, onAt = l.onAt }
		end
		h.ticks[slot] = sim.tick
		h.states[slot] = { doors = doors, lasers = lasers }
	end
	-- State after tick `k` (nil before the run's first tick: everything at reset).
	function h.at(k: number, sim: any): any
		if k < 0 then
			local doors, lasers = {}, {}
			for i = 1, #sim.level.doors do
				doors[i] = { open = false, solid = true, solidAt = nil }
			end
			for i = 1, #sim.level.lasers do
				lasers[i] = { on = true, onAt = nil }
			end
			return { doors = doors, lasers = lasers }
		end
		local slot = k % HIST + 1
		if h.ticks[slot] == k then
			return h.states[slot]
		end
		return nil
	end
	function h.clear()
		table.clear(h.ticks)
		table.clear(h.states)
	end
	return h
end

-- Plays one run with the given bots (already created). Returns the run summary.
function Harness.runOnce(sim: any, bots: { any }, hist: any, onTick: ((sim: any) -> ())?): any
	hist.clear()
	for _, bot in bots do
		bot:start(sim)
	end
	local guard = 0
	local maxTicks = math.floor(Config.Rec.LOOP_MAX_SECONDS * Config.Rec.HZ) + 10
	while sim.phase == "Run" do
		for _, bot in bots do
			bot:tick(sim, hist.at(sim.nextTick - 1 - bot.delay, sim))
		end
		HeistSim.step(sim)
		hist.push(sim)
		if onTick then
			onTick(sim)
		end
		guard += 1
		assert(guard <= maxTicks, "run did not end")
	end
	local summary = table.clone(sim.lastRun)
	summary.lines = EventLog.lines(sim.log)
	summary.log = EventLog.copy(sim.log)
	summary.phase = sim.phase
	return summary
end

function Harness.play(level: any, plan: any, opts: any?): (any, { any })
	local o = opts or {}
	local players = plan.players or { 1 }
	local sim = HeistSim.new(level, {
		players = players,
		firstHeist = o.firstHeist,
		relaxed = o.relaxed,
		seed = o.seed,
	})
	local latency = plan.latency or {}
	for _, id in players do
		HeistSim.setLatency(sim, id, (latency[id] or 0) / Config.Rec.HZ)
	end
	local hist = Harness.history()
	local runs = {}
	for r, run in plan.runs do
		for _, op in run.deck or {} do
			assert(HeistSim.deckAction(sim, op[1], op[2], op[3]), "deck action failed: " .. op[2])
		end
		local idx = HeistSim.startRun(sim)
		assert(idx == r, "run did not start (phase " .. sim.phase .. ")")
		local bots = {}
		for _, id in players do
			if not sim.playerById[id].orphan then
				local delay = (run.delay and run.delay[id]) or latency[id] or 0
				table.insert(bots, Bot.new(level, id, run[id] or { { stay = true } }, { delay = delay }))
			end
		end
		table.insert(runs, Harness.runOnce(sim, bots, hist, o.onTick))
		if sim.phase == "Over" then
			break
		end
	end
	return sim, runs
end

-- Event-log helpers.
function Harness.count(run: any, kind: number, a: number?, b: number?): number
	return EventLog.count(run.log, kind, a, b)
end

-- All runs' logs joined (for failure messages).
function Harness.dump(runs: { any }): string
	local out = {}
	for i, r in runs do
		table.insert(out, "-- run " .. i)
		for _, l in r.lines do
			table.insert(out, l)
		end
	end
	return table.concat(out, "\n")
end

return Harness
