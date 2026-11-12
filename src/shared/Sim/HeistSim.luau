--!strict
-- Sim/HeistSim: the deterministic heist simulation, one per heist instance.
-- MASTERPLAN §3 (run rules, clone rules, solo/co-op, Alarm Run), §8.2 (fixed-step
-- 20 Hz sim on loop time), §8.3 (recording inside the tick), §8.5, §8.10.
-- Pure Luau: the server feeds it player positions and intents and reads outcomes
-- (event log, snapshot); time comes from the tick index (or an injected LoopClock
-- driven by the caller's server time); randomness from an injected Random.
--
-- Determinism contract (§3.2 rule 3): the world at loop time t is a pure function
-- of (level, seed, run index, actor positions and intents up to t). Two loops with
-- no live player moving give identical event logs; the L2 tests hash them.
--
-- Lifecycle (§3.1):
--   new(level, opts) -> addPlayer(...)* -> startRun() [locks caps on the first run]
--   -> per tick: setInput / request / endRun, then step()  (or update(serverNow))
--   -> the run ends (all live runs ended, timer, heist complete, van left)
--   -> phase "Between": deckAction(...)* -> startRun() ... -> phase "Over".
-- Tick order (fixed): move clones and live players -> intents (clones, then live,
-- in actor order) -> hidden flags -> mechanisms -> carried loot and banking ->
-- lasers -> guards -> alarm -> tutorial auto-end, squeeze, run end.
--
-- Level kinds: "story" levels complete when the goal is banked (Haul / Crew / Clean
-- stars). "party" levels (Clone Party, §4.2) never complete: the crew steals until
-- Dawn and the banked haul is scored against the level's tiers (Haul1..3, `Tier`
-- events as they are reached). Daily vaults are story levels with a fixed 5-clone
-- loadout and Dawn at run 6; result().daily is DailyVault.DailyResult's shape.
-- Hooks for the view: a `Swarm` event SWARM_FANOUT_SECONDS into a run (once the
-- tape-print fan-out has spread the copies) for each player with at least
-- SWARM_SEEN_CLONES of their own clones, or of the crew's, in the world (a = seat,
-- b = copies of that player incl. them, c = the crew's copies: "8 OF ME" when
-- b >= SWARM_OF_ME, "16 ROBBERS" in co-op), HeistSim.ofMe, HeistSim.lineup for the
-- scripted Crew Line-up (§3.2 rule 8, never simulated), and lastRun.alarm (who
-- tripped the alarm, when; `hint` = "RedoAlarm" when a clone did it early) for the
-- Clone Deck hint "Clone #N sets off the alarm: Redo #N?".
-- Party levels: result().data.clones is the most clones ONE player had (<= the
-- per-player cap, which is what Data's party rules check); clonesUsed is the crew's.

local Codec = require("../Rec/Codec")
local Config = require("../Config")
local LoopClock = require("../Rec/LoopClock")
local Sampler = require("../Rec/Sampler")
local Validator = require("../Rec/Validator")
local Actors = require("./Actors")
local Alarm = require("./Alarm")
local Deck = require("./Deck")
local Divergence = require("./Divergence")
local EventLog = require("./EventLog")
local Geom = require("./Geom")
local Guards = require("./Guards")
local Interact = require("./Interact")
local Loot = require("./Loot")
local Mechanisms = require("./Mechanisms")
local Rng = require("./Rng")
local Scoring = require("./Scoring")

local EV = EventLog.EV
local KIND = Codec.EVENT
local END = Codec.END
local HIDDEN = Codec.FLAG.HIDDEN
local EPS = 1e-7

local HeistSim = {}

HeistSim.EV = EV
HeistSim.CAUSE = Divergence.CAUSE
HeistSim.FAIL = Interact.FAIL

-- Why a run ended (RunEnd event arg a).
HeistSim.RUN_END = table.freeze({
	Timeout = 1, -- the timer hit 0 (counts as END RUN for everyone still running)
	AllEnded = 2, -- every live run ended (END RUN, caught, zapped, left)
	Complete = 3, -- the heist was completed mid-run
	VanLeft = 4, -- Alarm Run: the van countdown reached 0
	Abort = 5, -- the server stopped the run
})

-- Opts for HeistSim.new.
export type Opts = {
	seed: number?, -- default level.seed
	newRandom: ((seed: number) -> any)?, -- default Rng.new; the server may pass Random.new
	players: { number }?, -- crew ids in seat order
	firstHeist: boolean?, -- first heist of a new account: detection times x2
	relaxed: boolean?, -- runs +50%, detection times x2 (also on when level.relaxed, Levels/Relaxed)
	walkSpeed: number?, -- server-set WalkSpeed (validator, chase speed)
}

local function newPlayer(id: number, seat: number): any
	return {
		id = id,
		seat = seat,
		deck = Deck.new(0),
		latency = 0,
		orphan = false,
		helper = false,
		bag = 0, -- bag level (Cash upgrade, §5.1); only counts in levels with `bags`
		input = { x = 0, y = 0, z = 0, yaw = 0, flags = Codec.FLAG.GROUNDED },
		queue = {},
		endRequested = false,
		live = nil,
		busts = 0,
	}
end

function HeistSim.new(level: any, opts: Opts?): any
	local o: Opts = opts or {}
	local S = Config.Sim
	-- Relaxed is a level modifier (Levels/Relaxed: slower guards) plus these sim rules; the
	-- `relaxed` opt alone (tests, older callers) applies only the sim rules.
	local relaxed = o.relaxed == true or level.relaxed == true
	local sim = {
		level = level,
		hz = Config.Rec.HZ,
		dt = 1 / Config.Rec.HZ,
		seed = o.seed or level.seed,
		newRandom = o.newRandom or Rng.new,
		rng = nil :: any,
		walkSpeed = o.walkSpeed or Config.Rec.WALK_SPEED,
		firstHeist = o.firstHeist == true,
		autoEndArmed = false, -- the tutorial auto-end applies to this run (set at run start)
		relaxed = relaxed,
		players = {},
		playerById = {},
		crewSize = 0,
		cap = 0,
		phase = "Lobby",
		overReason = "",
		runIndex = 0,
		tick = -1,
		nextTick = 0,
		t = 0,
		tierMet = 0, -- party levels: highest haul tier banked so far
		runLength = LoopClock.lengthFor(level.runSeconds, relaxed),
		clock = nil :: LoopClock.Clock?,
		rate = 1,
		actors = {},
		liveCount = 0,
		squeezed = false,
		mech = Mechanisms.new(level),
		guards = {},
		loot = Loot.new(level),
		alarm = Alarm.new(),
		log = EventLog.new(),
		heistHash = 2166136261,
		banked = 0,
		goalMet = false,
		completeNow = false,
		run = { catches = 0, busted = 0, zapped = 0, stuck = 0, shrugs = 0, clones = 0, tainted = false },
		lastRun = nil :: any,
		clonesUsed = 0,
		ownClonesUsed = 0, -- party levels: most clones of one player (result().data.clones)
		totalTime = 0,
		finalRunTime = 0,
		finalRecordings = {},
		ctx = nil :: any,
		tripAlarm = Alarm.trigger,
		swarmTick = math.ceil(S.SWARM_FANOUT_SECONDS * Config.Rec.HZ - EPS),
	}
	for i, def in level.guards do
		sim.guards[i] = Guards.new(def, level.rootY)
	end
	local mult = (if sim.firstHeist then S.FIRST_HEIST_GRACE_MULT else 1)
		* (if sim.relaxed then S.RELAXED_DETECT_MULT else 1)
	sim.ctx = {
		level = level,
		mech = sim.mech,
		actors = sim.actors,
		log = sim.log,
		tick = 0,
		t = 0,
		dt = sim.dt,
		hz = sim.hz,
		alertT = S.GUARD_ALERT_SECONDS * mult,
		catchT = S.GUARD_CATCH_SECONDS * mult,
		vision = nil :: any,
		coneVision = {
			range = S.GUARD_VISION_RANGE * (level.visionMult or 1),
			cosHalf = math.cos(math.rad(S.GUARD_VISION_HALF_ANGLE)),
			allRound = false,
		},
		chaseVision = { range = S.GUARD_VISION_RANGE * (level.visionMult or 1), cosHalf = -1, allRound = true },
		chase = false,
		-- Relaxed levels: Gus chases at the same reduced share as his patrol (Levels/Relaxed).
		chaseSpeed = S.GUARD_CHASE_SPEED_MULT
			* sim.walkSpeed
			* (if level.relaxed == true then Config.Onboarding.RELAXED_GUARD_SPEED_MULT else 1),
		onCatch = nil :: any,
	}
	sim.ctx.onCatch = function(g: any, a: any)
		HeistSim._catch(sim, g, a)
	end
	for _, id in o.players or {} do
		HeistSim.addPlayer(sim, id)
	end
	return sim
end

-- Seats a crew member. Only before the heist starts (late joiners seat at the next heist).
-- `bag` = the player's bag level (DataService.getBagLevel), fixed for the heist: in a
-- level with `bags`, that player and their clones carry 1 + bag x EXTRA_CARRY items.
function HeistSim.addPlayer(sim: any, id: number, opts: { helper: boolean?, bag: number? }?): boolean
	if sim.phase ~= "Lobby" or sim.playerById[id] or #sim.players >= Config.Sim.MAX_CREW then
		return false
	end
	local p = newPlayer(id, #sim.players + 1)
	p.helper = opts ~= nil and opts.helper == true
	local bag = opts and opts.bag
	if type(bag) == "number" and bag == bag then
		p.bag = math.clamp(math.floor(bag), 0, Config.Data.Bag.MAX_LEVEL)
	end
	table.insert(sim.players, p)
	sim.playerById[id] = p
	return true
end

-- Loads recordings into a player's deck before the heist starts: golden solutions
-- (levels/<id>.solution.bin decoded with Rec/Codec), Mentor tapes, ghost audits.
-- Slots beyond the cap locked at heist start are dropped.
function HeistSim.seedDeck(sim: any, id: number, recs: { any }): boolean
	local p = sim.playerById[id]
	if sim.phase ~= "Lobby" or not p then
		return false
	end
	table.clear(p.deck.slots)
	for _, rec in recs do
		table.insert(p.deck.slots, { rec = rec, status = "OK", run = 0 })
	end
	return true
end

-- Per-player clone cap for a crew size (§0 C3).
function HeistSim.capFor(levelCap: number, crewSize: number): number
	return math.min(levelCap, math.floor(Config.Sim.CREW_CLONE_BUDGET / math.max(crewSize, 1)))
end

-- Items one actor of this player can carry in this level (bag levels, §5.1).
function HeistSim.carryFor(level: any, bag: number): number
	if not level.bags then
		return 1
	end
	return 1 + math.max(0, bag) * Config.Data.Bag.EXTRA_CARRY_PER_LEVEL
end

local function lockCrew(sim: any)
	sim.crewSize = #sim.players
	sim.cap = HeistSim.capFor(sim.level.cap, sim.crewSize)
	for _, p in sim.players do
		p.deck.cap = sim.cap
		for i = #p.deck.slots, sim.cap + 1, -1 do
			table.remove(p.deck.slots, i)
		end
	end
	local S = Config.Sim
	sim.ctx.coneVision.range = S.GUARD_VISION_RANGE
		* (sim.level.visionMult or 1)
		* (1 + S.CREW_VISION_BONUS * (sim.crewSize - 1))
	sim.ctx.chaseVision.range = sim.ctx.coneVision.range
end

local function spawnFor(sim: any, seat: number): any
	local spawns = sim.level.spawns
	return spawns[(seat - 1) % #spawns + 1]
end

-- Starts the next run. With `serverNow`, also starts a LoopClock at that server time
-- for update(). Returns the run index, or nil if the heist cannot run.
function HeistSim.startRun(sim: any, serverNow: number?): number?
	if sim.phase == "Lobby" then
		if #sim.players == 0 then
			return nil
		end
		lockCrew(sim)
	elseif sim.phase ~= "Between" then
		return nil
	end
	local anyLive = false
	for _, p in sim.players do
		anyLive = anyLive or not p.orphan
	end
	if not anyLive then
		sim.phase = "Over"
		sim.overReason = "Abandoned"
		return nil
	end

	local level = sim.level
	sim.runIndex += 1
	sim.phase = "Run"
	-- Tutorial auto-end (§7.5): its listed runs, and with untilDone every run in which no
	-- replayed clone came from an auto-ended run (so a kid who ended run 1 off the plate,
	-- or whose plate clone was replaced at the cap, is led back to the plate).
	local ae = level.tutorial and level.tutorial.autoEnd
	local armed = false
	if ae then
		armed = ae.runs[sim.runIndex] == true
		if not armed and ae.untilDone then
			local onPlate = false
			for _, p in sim.players do
				for i, slot in p.deck.slots do
					if slot.auto == true and Deck.replays(p.deck, i) then
						onPlate = true
					end
				end
			end
			armed = not onPlate
		end
	end
	sim.autoEndArmed = armed
	sim.tick = -1
	sim.nextTick = 0
	sim.t = 0
	sim.rate = 1
	sim.squeezed = false
	sim.completeNow = false
	sim.runLength = LoopClock.lengthFor(level.runSeconds, sim.relaxed)
	sim.clock = if serverNow then LoopClock.new(serverNow, sim.runLength) else nil
	sim.rng = sim.newRandom(sim.seed + sim.runIndex)
	EventLog.clear(sim.log)
	Mechanisms.reset(sim.mech)
	Alarm.reset(sim.alarm)
	Loot.reset(sim.loot, sim.rng)
	for _, g in sim.guards do
		Guards.reset(g)
	end
	local run = sim.run
	run.catches, run.busted, run.zapped, run.stuck, run.shrugs, run.clones, run.tainted = 0, 0, 0, 0, 0, 0, false
	run.ownMax = 0

	-- Actors: clones by (seat, slot), then live players by seat.
	local actors = sim.actors
	table.clear(actors)
	local clones = 0
	for _, p in sim.players do
		local own = 0
		for slot, s in p.deck.slots do
			if Deck.replays(p.deck, slot) then
				local a = Actors.newClone(#actors + 1, p, slot, s.rec)
				a.capacity = HeistSim.carryFor(level, p.bag)
				table.insert(actors, a)
				clones += 1
				if not p.helper then
					run.clones += 1
					own += 1
				end
			end
		end
		run.ownMax = math.max(run.ownMax, own)
	end
	local live = 0
	for _, p in sim.players do
		p.live = nil
		table.clear(p.queue)
		p.endRequested = false
		if not p.orphan then
			local spawn = spawnFor(sim, p.seat)
			local rec = Sampler.new(level.num, sim.runIndex, sim.hz)
			local a = Actors.newLive(#actors + 1, p, spawn, rec)
			a.capacity = HeistSim.carryFor(level, p.bag)
			a.validator = Validator.new(rec, {
				walkSpeed = sim.walkSpeed,
				ping = 2 * p.latency,
				noGo = level.noGo,
				isBlocked = function(
					ts: number,
					x0: number,
					y0: number,
					z0: number,
					x1: number,
					y1: number,
					z1: number
				)
					local T = LoopClock.hazardTime(ts, a.latency)
					return Mechanisms.doorBlocking(sim.mech, T, x0, y0, z0, x1, y1, z1) ~= 0
				end,
			})
			p.input.x, p.input.y, p.input.z, p.input.yaw = spawn.x, spawn.y, spawn.z, spawn.yaw
			p.input.flags = Codec.FLAG.GROUNDED
			p.live = a
			table.insert(actors, a)
			live += 1
		end
	end
	sim.liveCount = live
	EventLog.append(sim.log, 0, EV.RunStart, sim.runIndex, clones, live)
	return sim.runIndex
end

-- The swarm moment (§4.2 "8 OF ME", funnel SwarmSeen = 6+ clones on screen), logged
-- once per run after the tape-print fan-out, when the copies stand apart: one event
-- per crew member still in the crew with 6+ own clones in the world, or 6+ crew
-- clones (co-op crews of 3-4 never reach 6 own clones but see 12). a = seat, b =
-- that player's copies (clones + their live run), c = every copy in the crew.
local function logSwarm(sim: any)
	local need = Config.Sim.SWARM_SEEN_CLONES
	local crewClones, crew = 0, 0
	for _, a in sim.actors do
		if a.present then
			crew += 1
			if a.kind == "clone" then
				crewClones += 1
			end
		end
	end
	for _, p in sim.players do
		local own, mine = 0, 0
		for _, a in sim.actors do
			if a.player == p and a.present then
				mine += 1
				if a.kind == "clone" then
					own += 1
				end
			end
		end
		if not p.orphan and (own >= need or crewClones >= need) then
			EventLog.append(sim.log, sim.tick, EV.Swarm, p.seat, mine, crew)
		end
	end
end

-- Latest position of a live player (the server's view of their character), used
-- at the next tick. Positions are level space (the caller subtracts the origin).
function HeistSim.setInput(sim: any, id: number, x: number, y: number, z: number, yaw: number?, flags: number?)
	local p = sim.playerById[id]
	if not p then
		return
	end
	local inp = p.input
	inp.x, inp.y, inp.z = x, y, z
	if yaw then
		inp.yaw = yaw
	end
	if flags then
		inp.flags = flags
	end
end

-- Measured one-way latency (seconds) for the lag-fairness rewind (§8.10).
function HeistSim.setLatency(sim: any, id: number, oneWay: number)
	local p = sim.playerById[id]
	if p then
		p.latency = math.max(0, if oneWay == oneWay then oneWay else 0)
		if p.live then
			p.live.latency = p.latency
		end
	end
end

-- Queues an intent (Codec.EVENT kind, LevelSpec index) for the next tick.
function HeistSim.request(sim: any, id: number, kind: number, arg: number?): boolean
	local p = sim.playerById[id]
	if sim.phase ~= "Run" or not p or not p.live or not p.live.present or not Interact.REQUESTABLE[kind] then
		return false
	end
	if #p.queue >= Config.Sim.MAX_QUEUED_INTENTS then
		return false
	end
	table.insert(p.queue, { kind = kind, arg = math.floor(arg or 0) })
	return true
end

-- END RUN. Refused during the first END_RUN_LOCK_SECONDS of the run (§3.1).
function HeistSim.endRun(sim: any, id: number): boolean
	local p = sim.playerById[id]
	if sim.phase ~= "Run" or not p or not p.live or not p.live.present then
		return false
	end
	-- Judged at the tick that will process it.
	if sim.nextTick / sim.hz < Config.Rec.END_RUN_LOCK_SECONDS - EPS then
		return false
	end
	p.endRequested = true
	return true
end

local function dropCarried(sim: any, a: any)
	if a.carrying ~= 0 then
		Loot.drop(sim.loot, a, sim.log, sim.tick)
	end
end

-- Ends a live actor's run at the current tick.
local function endLive(sim: any, a: any, state: string, endReason: number, evKind: number?)
	if a.state ~= "Active" then
		return
	end
	a.state = state
	a.present = false
	a.hidden = false
	dropCarried(sim, a)
	Validator.checkEvents(a.validator)
	Sampler.finish(a.rec, endReason)
	if Validator.isTainted(a.rec) then
		sim.run.tainted = true
	end
	if evKind then
		EventLog.append(sim.log, sim.tick, evKind, a.id)
	end
end

-- Gus reached "!" (or touched someone in a chase).
function HeistSim._catch(sim: any, g: any, a: any)
	if not a.present then
		return
	end
	local log, tick = sim.log, sim.tick
	if a.kind == "live" then
		Sampler.addEvent(a.rec, sim.t, KIND.Caught, g.index)
		EventLog.append(log, tick, EV.Caught, g.index, a.id)
		endLive(sim, a, "Caught", END.Caught, nil)
		sim.run.catches += 1
		a.player.busts += 1
		if sim.level.alarm and sim.level.alarm.onCatch then
			Alarm.trigger(sim, 0, a.x, a.z)
		end
	else
		a.state = "Busted"
		a.present = false
		a.hidden = false
		dropCarried(sim, a)
		EventLog.append(log, tick, EV.Busted, g.index, a.id)
		sim.run.busted += 1
		Guards.huh(g, sim.ctx)
	end
end

local function zap(sim: any, a: any, laser: number)
	EventLog.append(sim.log, sim.tick, EV.Zap, a.id, laser)
	sim.run.zapped += 1
	if a.kind == "live" then
		endLive(sim, a, "Zapped", END.Zapped, nil)
	else
		a.state = "Zapped"
		a.present = false
		a.hidden = false
		dropCarried(sim, a)
	end
end

local function moveClone(sim: any, a: any, t: number)
	if not a.present or a.state == "Stuck" then
		return
	end
	local x, y, z, yaw, flags = Sampler.at(a.rec, t)
	if x == nil then
		return
	end
	local nx: number = x
	local cause, index = Divergence.check(sim.mech, t, a.x, a.y, a.z, nx, y, z)
	a.px, a.py, a.pz = a.x, a.y, a.z
	if cause then
		a.state = "Stuck"
		sim.run.stuck += 1
		EventLog.append(sim.log, sim.tick, EV.Stuck, a.id, cause, index)
		return
	end
	a.x, a.y, a.z, a.yaw, a.flags = nx, y, z, yaw, flags
	if a.state == "Active" and Sampler.isHolding(a.rec, t) then
		a.state = "Holding"
	end
end

local function moveLive(sim: any, a: any, tick: number)
	if not a.present then
		return
	end
	local inp = a.player.input
	local x, y, z = inp.x, inp.y, inp.z
	if sim.rate > 1 then
		-- Fast-forward is recorded as standing (§3.1).
		x, y, z = a.x, a.y, a.z
	end
	a.px, a.py, a.pz = a.x, a.y, a.z
	local rec = a.rec
	if Sampler.record(rec, tick, x, y, z, inp.yaw, bit32.band(inp.flags, bit32.bnot(HIDDEN))) then
		Validator.step(a.validator)
	end
	local n = rec.n
	if n > 0 then
		a.x, a.y, a.z, a.yaw, a.flags = rec.px[n], rec.py[n], rec.pz[n], rec.yaw[n], rec.flags[n]
	end
end

local function fireCloneEvents(sim: any, a: any, t: number)
	if not a.present or a.state == "Stuck" then
		return
	end
	local events = a.rec.events
	local last = Sampler.eventsDue(a.rec, a.cursor, t)
	for k = a.cursor + 1, last do
		local e = events[k]
		if Interact.REQUESTABLE[e.kind] then
			local ok, reason = Interact.request(sim, a, e.kind, e.arg)
			if not ok then
				a.shrugs += 1
				sim.run.shrugs += 1
				EventLog.append(sim.log, sim.tick, EV.Shrug, a.id, e.kind, reason or 0)
			end
		end
		if not a.present then
			last = k
			break
		end
	end
	a.cursor = last
end

-- Tutorial (L1): a live run that ends on the armed auto-end plate, by END RUN or by
-- the timeout, counts as auto-ended, so its clone holds the plate and the tutorial
-- does not re-arm (WALKTHROUGH P0-1). Only the timer logs EV.AutoEnd.
local function markOnArmedPlate(sim: any, a: any)
	local ae = HeistSim.autoEndArmed(sim)
	if ae and a.present and Geom.contains(sim.level.plates[ae.plate].box, a.x, a.y, a.z) then
		a.autoEnded = true
	end
end

local function liveIntents(sim: any, a: any)
	local p = a.player
	for _, req in p.queue do
		if not a.present then
			break
		end
		local ok, reason = Interact.request(sim, a, req.kind, req.arg)
		if not ok then
			EventLog.append(sim.log, sim.tick, EV.Rejected, a.id, req.kind, reason or 0)
		end
	end
	table.clear(p.queue)
	if p.endRequested and a.present then
		p.endRequested = false
		markOnArmedPlate(sim, a)
		endLive(sim, a, "Ended", END.EndRun, EV.EndRun)
	end
end

local function updateHidden(sim: any, a: any)
	local hidden, spot = false, 0
	if a.present then
		for i, h in sim.level.hides do
			if Geom.contains(h.box, a.x, a.y, a.z) then
				hidden, spot = true, i
				break
			end
		end
	end
	if hidden ~= a.hidden then
		a.hidden = hidden
		EventLog.append(sim.log, sim.tick, if hidden then EV.Hidden else EV.Unhidden, a.id, spot)
	end
	if a.kind == "live" and hidden and a.present then
		local rec = a.rec
		rec.flags[rec.n] = bit32.bor(rec.flags[rec.n], HIDDEN)
	end
end

local function bankAll(sim: any)
	local level = sim.level
	local van = level.van
	local party = level.kind == "party"
	for _, a in sim.actors do
		if a.present and a.carrying ~= 0 and Geom.contains(van, a.x, a.y, a.z) then
			for _, item in Loot.unload(a) do
				sim.banked += Loot.bankItem(sim.loot, item, sim.t)
				sim.clonesUsed = math.max(sim.clonesUsed, sim.run.clones)
				sim.ownClonesUsed = math.max(sim.ownClonesUsed, sim.run.ownMax)
				EventLog.append(sim.log, sim.tick, EV.Bank, a.id, item, sim.banked)
				if party then
					-- Party levels never complete: tiers are scored at Dawn.
					local tiers = level.tiers
					while sim.tierMet < #tiers and sim.banked >= tiers[sim.tierMet + 1] - EPS do
						sim.tierMet += 1
						EventLog.append(sim.log, sim.tick, EV.Tier, sim.tierMet, sim.banked)
					end
				else
					if sim.banked >= level.haul - EPS then
						sim.completeNow = true
					elseif not sim.goalMet and sim.banked >= level.goal - EPS then
						EventLog.append(sim.log, sim.tick, EV.GoalMet, sim.banked)
					end
					if sim.banked >= level.goal - EPS then
						sim.goalMet = true
					end
				end
			end
		end
	end
end

local function lasers(sim: any)
	if #sim.level.lasers == 0 then
		return
	end
	for _, a in sim.actors do
		if a.present then
			local T = if a.kind == "live" then LoopClock.hazardTime(sim.t, a.latency) else sim.t
			local hit = Mechanisms.laserHit(sim.mech, T, a.px, a.py, a.pz, a.x, a.y, a.z)
			if hit ~= 0 then
				zap(sim, a, hit)
			end
		end
	end
end

local function finishRun(sim: any, reason: number)
	local level = sim.level
	local endReason = if reason == HeistSim.RUN_END.Timeout then END.Timeout else END.Left
	for _, a in sim.actors do
		if a.kind == "live" and a.state == "Active" then
			if reason == HeistSim.RUN_END.Timeout then
				markOnArmedPlate(sim, a)
			end
			endLive(sim, a, "Ended", endReason, if reason == HeistSim.RUN_END.Timeout then EV.Timeout else nil)
		end
		if a.kind == "clone" and Validator.isTainted(a.rec) then
			sim.run.tainted = true
		end
	end
	EventLog.append(sim.log, sim.tick, EV.RunEnd, reason, sim.tick)
	sim.totalTime += sim.t
	local over = level.kind ~= "party" and (sim.completeNow or sim.goalMet)
	if over then
		sim.phase = "Over"
		sim.overReason = "Complete"
		sim.finalRunTime = sim.t
		sim.clonesUsed = math.max(sim.clonesUsed, sim.run.clones)
		EventLog.append(sim.log, sim.tick, EV.HeistComplete, sim.banked, sim.runIndex)
	elseif level.dawnRuns and sim.runIndex >= level.dawnRuns then
		sim.phase = "Over"
		sim.overReason = "Dawn"
		sim.finalRunTime = sim.t
		if level.kind == "party" then
			-- The swarm that ran until Dawn (a story level's count only grows with banks).
			sim.clonesUsed = math.max(sim.clonesUsed, sim.run.clones)
			sim.ownClonesUsed = math.max(sim.ownClonesUsed, sim.run.ownMax)
		end
		EventLog.append(sim.log, sim.tick, EV.Dawn, sim.banked, sim.runIndex)
	else
		sim.phase = "Between"
	end

	-- Deck: statuses of the replayed clones, then each live run becomes a clone.
	table.clear(sim.finalRecordings)
	for _, a in sim.actors do
		if a.kind == "clone" then
			local s = a.player.deck.slots[a.slot]
			if s and s.rec == a.rec then
				s.status = Actors.cloneStatus(a)
			end
		end
	end
	for _, p in sim.players do
		local a = p.live
		if a then
			table.insert(sim.finalRecordings, { playerId = p.id, rec = a.rec })
			if sim.phase ~= "Over" and not p.orphan then
				local slot = Deck.commit(p.deck, a.rec, sim.runIndex, Actors.liveStatus(a))
				if a.autoEnded then
					-- this clone stands on the tutorial plate (LevelSpec autoEnd untilDone)
					p.deck.slots[slot].auto = true
				end
			end
		end
	end

	local h = EventLog.hash(sim.log)
	sim.heistHash = EventLog.fold(sim.heistHash, h)
	-- Who tripped the alarm (Clone Deck hint): a = actor id (0 = a catch).
	local alarm = nil
	local at, id = nil, 0
	for i = 1, sim.log.n do
		if sim.log.kind[i] == EV.AlarmOn then
			at, id = sim.log.tick[i], sim.log.a[i]
			break
		end
	end
	if at then
		local by = sim.actors[id]
		local t = at / sim.hz
		local clone = by ~= nil and by.kind == "clone"
		alarm = {
			t = t,
			actorId = id,
			kind = if by then by.kind else "catch",
			ownerId = if by then by.ownerId else 0,
			slot = if clone then by.slot else 0,
			hint = if clone and t < Config.Sim.ALARM_HINT_SECONDS - EPS then "RedoAlarm" else nil,
		}
	end
	sim.lastRun = {
		runIndex = sim.runIndex,
		reason = reason,
		t = sim.t,
		ticks = sim.tick + 1,
		hash = h,
		banked = sim.banked,
		catches = sim.run.catches,
		busted = sim.run.busted,
		zapped = sim.run.zapped,
		stuck = sim.run.stuck,
		shrugs = sim.run.shrugs,
		clones = sim.run.clones,
		tainted = sim.run.tainted,
		alarm = alarm,
	}
end

-- Runs one fixed sim tick. Returns the phase after it.
function HeistSim.step(sim: any): string
	if sim.phase ~= "Run" then
		return sim.phase
	end
	local tick = sim.nextTick
	local t = tick / sim.hz
	sim.tick, sim.t = tick, t
	sim.nextTick = tick + 1
	local actors = sim.actors

	-- Fast-forward ends when its pill would vanish: a live player moved, or no
	-- clone has anything left to play (§3.1).
	if sim.rate > 1 and not HeistSim.canFastForward(sim) then
		HeistSim.setRate(sim, nil, 1)
	end

	for _, a in actors do
		if a.kind == "clone" then
			moveClone(sim, a, t)
		else
			a.latency = a.player.latency
			moveLive(sim, a, tick)
		end
	end
	for _, a in actors do
		if a.kind == "clone" then
			fireCloneEvents(sim, a, t)
		else
			liveIntents(sim, a)
		end
	end
	for _, a in actors do
		updateHidden(sim, a)
	end
	Mechanisms.update(sim.mech, tick, t, actors, sim.log)
	Loot.follow(sim.loot, actors)
	bankAll(sim)
	Loot.tick(sim.loot, t, sim.rng, sim.log, tick)
	lasers(sim)

	local ctx = sim.ctx
	ctx.tick, ctx.t = tick, t
	for _, g in sim.guards do
		ctx.vision = if g.mode == "Chase" then ctx.chaseVision else ctx.coneVision
		Guards.update(g, ctx)
	end
	local vanLeft = Alarm.update(sim)
	if tick == sim.swarmTick then
		logSwarm(sim)
	end

	-- Tutorial: run 1 of L1 auto-ends after L1_AUTO_END_SECONDS on the plate (§7.5);
	-- with untilDone, every later run too until it has fired once.
	local ae = HeistSim.autoEndArmed(sim)
	if ae then
		local box = sim.level.plates[ae.plate].box
		for _, a in actors do
			if a.kind == "live" and a.present then
				if Geom.contains(box, a.x, a.y, a.z) then
					a.plateTicks += 1
					if a.plateTicks * sim.dt >= ae.seconds - EPS then
						a.autoEnded = true
						EventLog.append(sim.log, tick, EV.AutoEnd, a.id)
						endLive(sim, a, "Ended", END.EndRun, EV.EndRun)
					end
				else
					a.plateTicks = 0
				end
			end
		end
	end

	-- Co-op waiting squeeze: once half the crew has ended, the rest get <= 10 s (§3.1).
	local ended = 0
	for _, a in actors do
		if a.kind == "live" and not a.present then
			ended += 1
		end
	end
	if not sim.squeezed and sim.liveCount >= 2 and ended * 2 >= sim.liveCount and ended < sim.liveCount then
		sim.squeezed = true
		local len = math.min(sim.runLength, t + Config.Rec.WAIT_SQUEEZE_SECONDS)
		if len < sim.runLength then
			sim.runLength = len
			if sim.clock then
				sim.clock =
					LoopClock.squeeze(sim.clock, LoopClock.serverTimeAt(sim.clock, t), Config.Rec.WAIT_SQUEEZE_SECONDS)
			end
			EventLog.append(sim.log, tick, EV.Squeeze, 0, math.floor(len * 100 + 0.5))
		end
	end

	if sim.completeNow then
		finishRun(sim, HeistSim.RUN_END.Complete)
	elseif vanLeft then
		finishRun(sim, HeistSim.RUN_END.VanLeft)
	elseif ended >= sim.liveCount then
		finishRun(sim, HeistSim.RUN_END.AllEnded)
	elseif t >= sim.runLength - EPS then
		finishRun(sim, HeistSim.RUN_END.Timeout)
	end
	return sim.phase
end

-- Runs the ticks due at `serverNow` on the run's LoopClock (Heartbeat accumulator).
function HeistSim.update(sim: any, serverNow: number): number
	if sim.phase ~= "Run" or not sim.clock then
		return 0
	end
	local due = LoopClock.ticksDue(sim.clock, serverNow, sim.nextTick, sim.hz)
	local ran = 0
	for _ = 1, due do
		HeistSim.step(sim)
		ran += 1
		if sim.phase ~= "Run" then
			break
		end
	end
	return ran
end

-- Fast-forward pill (§3.1): every live player stands still and a clone still has
-- something left to play (it is still moving along its recording, or has events
-- left).
-- The level's tutorial auto-end when it applies to the current run (else nil): the
-- listed runs, and with untilDone every run whose replay has no clone from an
-- auto-ended run (decided at run start).
function HeistSim.autoEndArmed(sim: any): any
	local tut = sim.level.tutorial
	local ae = tut and tut.autoEnd
	if not ae then
		return nil
	end
	return if sim.autoEndArmed then ae else nil
end

function HeistSim.canFastForward(sim: any): boolean
	if sim.phase ~= "Run" then
		return false
	end
	local S = Config.Sim
	local pending = false
	for _, a in sim.actors do
		if a.kind == "live" and a.present then
			local inp = a.player.input
			if Geom.dist2(inp.x, inp.z, a.x, a.z) > S.STANDING_EPS * S.STANDING_EPS then
				return false
			end
		elseif
			a.kind == "clone"
			and a.present
			and (a.state == "Active" or (a.state == "Holding" and a.cursor < #a.rec.events))
		then
			pending = true
		end
	end
	return pending
end

-- Sets the clock rate (fast-forward on: Config.Rec.SKIP_SPEED; off: 1).
-- `serverNow` re-anchors the LoopClock; nil re-anchors at the current tick.
function HeistSim.setRate(sim: any, serverNow: number?, rate: number): boolean
	if sim.phase ~= "Run" then
		return false
	end
	if rate > 1 and not HeistSim.canFastForward(sim) then
		return false
	end
	sim.rate = rate
	if sim.clock then
		local now = serverNow or LoopClock.serverTimeAt(sim.clock, sim.t)
		sim.clock = LoopClock.setRate(sim.clock, now, rate)
	end
	return true
end

-- A player left. Their live run ends; their clones stay as orphan tapes (§3.3).
function HeistSim.removePlayer(sim: any, id: number)
	local p = sim.playerById[id]
	if not p then
		return
	end
	if sim.phase == "Lobby" then
		for i, q in sim.players do
			if q == p then
				table.remove(sim.players, i)
				break
			end
		end
		sim.playerById[id] = nil
		for i, q in sim.players do
			q.seat = i
		end
		return
	end
	p.orphan = true
	local a = p.live
	if a and a.state == "Active" then
		endLive(sim, a, "Left", END.Left, EV.Left)
	end
end

-- Clone Deck actions, between runs, own clones only (§3.2 rule 6).
-- op: "Redo" | "RedoFrom" | "Delete" | "DeleteBusted" | "Undo" | "Helper"
HeistSim.DECK_OP = table.freeze({ Redo = 1, RedoFrom = 2, Delete = 3, DeleteBusted = 4, Undo = 5, Helper = 6 })

function HeistSim.deckAction(sim: any, id: number, op: string, n: number?): boolean
	local p = sim.playerById[id]
	if sim.phase ~= "Between" or not p or p.orphan then
		return false
	end
	local deck = p.deck
	local ok = false
	if op == "Redo" then
		ok = Deck.redo(deck, n or 0)
	elseif op == "RedoFrom" then
		ok = Deck.redoFrom(deck, n or 0)
	elseif op == "Delete" then
		ok = Deck.delete(deck, n or 0)
	elseif op == "DeleteBusted" then
		ok = Deck.deleteBusted(deck) > 0
	elseif op == "Undo" then
		ok = Deck.undoLast(deck)
	elseif op == "Helper" then
		p.helper = n == 1
		ok = true
	end
	if ok then
		local code = (HeistSim.DECK_OP[op] or 0) * 65536 + (n or 0) * 16 + p.seat
		sim.heistHash = EventLog.fold(sim.heistHash, code)
	end
	return ok
end

-- The live actor of a player this run (nil between runs or once they left).
function HeistSim.liveActor(sim: any, id: number): any
	local p = sim.playerById[id]
	return p and p.live
end

function HeistSim.deckOf(sim: any, id: number): any
	local p = sim.playerById[id]
	return p and p.deck
end

-- Relaxed is offered after RELAXED_OFFER_BUSTS busts in one heist (§3.1).
function HeistSim.offerRelaxed(sim: any, id: number): boolean
	local p = sim.playerById[id]
	return p ~= nil and not sim.relaxed and p.busts >= Config.Sim.RELAXED_OFFER_BUSTS
end

-- Hash of the current run's event log so far.
function HeistSim.runHash(sim: any): number
	return EventLog.hash(sim.log)
end

-- Log entries after `cursor` (server streaming to clients): returns from, to indices.
function HeistSim.eventsSince(sim: any, cursor: number): (number, number)
	return cursor + 1, sim.log.n
end

-- Heist result and medal inputs (§5.2). Medals only count once phase is "Over".
-- Story levels: Haul / Crew / Clean. Party levels: complete = Haul1 banked by Dawn,
-- stars = tiers met. `data` is shared/Data Progress.HeistResult's shape, `daily`
-- DailyVault.DailyResult's (the server picks the one its level needs).
function HeistSim.result(sim: any): any
	local level = sim.level
	local party = level.kind == "party"
	local over = sim.phase == "Over"
	local complete = if party
		then over and sim.banked >= level.tiers[1] - EPS
		else over and sim.overReason == "Complete"
	local clonesNow = 0
	local bag = 0
	for _, p in sim.players do
		if not p.helper then
			clonesNow += #p.deck.slots
		end
		if level.bags then
			bag = math.max(bag, p.bag)
		end
	end
	local last = sim.lastRun
	local inputs: Scoring.Inputs = {
		complete = complete,
		banked = sim.banked,
		goal = level.goal,
		clonesUsed = sim.clonesUsed,
		par = level.par,
		catchesFinal = if last then last.catches else 0,
		bustedFinal = if last then last.busted else 0,
		tainted = if last then last.tainted else false,
	}
	local stars = if party then Scoring.partyStars(sim.banked, level.tiers, inputs.tainted) else Scoring.stars(inputs)
	return {
		phase = sim.phase,
		reason = sim.overReason,
		kind = level.kind,
		complete = complete,
		runs = sim.runIndex,
		banked = sim.banked,
		goal = level.goal,
		haul = level.haul,
		tiers = level.tiers,
		tierMet = sim.tierMet,
		clonesUsed = sim.clonesUsed,
		clonesPerPlayer = if party then sim.ownClonesUsed else nil,
		clonesNow = clonesNow,
		par = level.par,
		bag = bag, -- highest bag level that counted (bag runs are excluded from Diamond, §4.2)
		finalRunTime = sim.finalRunTime,
		totalTime = sim.totalTime,
		catchesFinal = inputs.catchesFinal,
		bustedFinal = inputs.bustedFinal,
		tainted = inputs.tainted,
		stars = stars,
		heistHash = sim.heistHash,
		-- The same facts in shared/Data Progress.HeistResult's shape (the server adds
		-- friends and heistId): DataService.awardHeistResult(player, level.dataId, data).
		data = {
			haul = sim.banked,
			-- Party levels: one player's swarm (Data's party cap is per player, 8); story
			-- levels: the crew's (the heist server widens their cap to the crew budget).
			clones = if party then sim.ownClonesUsed else sim.clonesUsed,
			timeMs = math.floor(sim.totalTime * 1000 + 0.5),
			catches = inputs.catchesFinal,
			busted = inputs.bustedFinal,
			beforeDawn = complete,
			tainted = inputs.tainted,
			relaxed = sim.relaxed,
			recHash = string.format("%08x", sim.heistHash),
		},
		-- Daily vaults: DataService.awardDailyVault(player, vaultDay, daily).
		daily = {
			cleared = complete,
			haul = sim.banked,
			clones = sim.clonesUsed,
			tainted = inputs.tainted,
			relaxed = sim.relaxed,
			-- Board tie-break after haul and clones (biggest haul today, §5.3).
			timeMs = math.floor(sim.totalTime * 1000 + 0.5),
		},
	}
end

-- Copies of one player in the current run: their clones in the world plus their
-- live run (the "8 OF ME" count; 0 between runs).
function HeistSim.ofMe(sim: any, id: number): number
	local p = sim.playerById[id]
	if not p or sim.phase ~= "Run" then
		return 0
	end
	local n = 0
	for _, a in sim.actors do
		if a.player == p and a.present then
			n += 1
		end
	end
	return n
end

-- The Crew Line-up (§3.2 rule 8): scripted at heist end, never simulated, so it can
-- never desync. Every clone of every crew member in record order (the run that
-- recorded it, then seat, then slot; orphan tapes included), then the players still
-- in the crew by seat. Each entry: kind ("clone" | "player"), ownerId, seat, slot
-- (0 = player), run, delay (seconds: LINEUP_STAGGER per figure) and a spot (x, z,
-- yaw) in rows of LINEUP_ROW in front of the van (level.lineup overrides the row).
function HeistSim.lineup(sim: any): { any }
	local S = Config.Sim
	local level = sim.level
	local out = {}
	for _, p in sim.players do
		for slot, s in p.deck.slots do
			table.insert(out, { kind = "clone", ownerId = p.id, seat = p.seat, slot = slot, run = s.run })
		end
	end
	table.sort(out, function(a: any, b: any): boolean
		if a.run ~= b.run then
			return a.run < b.run
		end
		if a.seat ~= b.seat then
			return a.seat < b.seat
		end
		return a.slot < b.slot
	end)
	for _, p in sim.players do
		if not p.orphan then
			table.insert(out, { kind = "player", ownerId = p.id, seat = p.seat, slot = 0, run = sim.runIndex })
		end
	end
	local row = level.lineup
	for i, e in out do
		local k = i - 1
		local col, line = k % S.LINEUP_ROW, math.floor(k / S.LINEUP_ROW)
		local across = (col - (math.min(#out - line * S.LINEUP_ROW, S.LINEUP_ROW) - 1) / 2) * S.LINEUP_SPACING
		local back = line * S.LINEUP_SPACING
		e.delay = k * S.LINEUP_STAGGER
		e.x = row.x + row.dx * across - row.fx * back
		e.z = row.z + row.dz * across - row.fz * back
		e.yaw = row.yaw
	end
	return out
end

-- Plain-data view for clients and debugging (doors/lasers carry the timestamps the
-- client needs for its local tweens and the 0.2 s telegraph, §8.2).
function HeistSim.snapshot(sim: any): any
	local mech = sim.mech
	local doors, lasersOut, plates, guards, loot, actors = {}, {}, {}, {}, {}, {}
	for i, d in mech.doors do
		doors[i] = { open = d.open, solid = d.solid, solidAt = d.solidAt }
	end
	for i, l in mech.lasers do
		lasersOut[i] = { on = l.on, onAt = l.onAt }
	end
	for i, p in mech.plates do
		plates[i] = { held = Mechanisms.plateHeld(mech, i, sim.t), count = p.count, releasedAt = p.releasedAt }
	end
	for i, g in sim.guards do
		guards[i] = { x = g.x, z = g.z, yaw = g.yaw, mode = g.mode, focus = g.focus }
	end
	for i, item in sim.loot.items do
		loot[i] = { state = item.state, x = item.x, y = item.y, z = item.z, carrier = item.carrier }
	end
	for i, a in sim.actors do
		actors[i] = {
			id = a.id,
			kind = a.kind,
			ownerId = a.ownerId,
			slot = a.slot,
			state = a.state,
			present = a.present,
			x = a.x,
			y = a.y,
			z = a.z,
			yaw = a.yaw,
			carrying = a.carrying,
			bag = table.clone(a.bag),
			hidden = a.hidden,
		}
	end
	return {
		phase = sim.phase,
		runIndex = sim.runIndex,
		t = sim.t,
		runLength = sim.runLength,
		banked = sim.banked,
		tierMet = sim.tierMet,
		alarm = { active = sim.alarm.active, vanAt = sim.alarm.vanAt, lockAt = sim.alarm.lockAt },
		doors = doors,
		lasers = lasersOut,
		plates = plates,
		guards = guards,
		loot = loot,
		actors = actors,
	}
end

return table.freeze(HeistSim)
