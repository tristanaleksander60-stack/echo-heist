--!strict
-- Analytics/Tracker: the analytics core (pure; Lune-tested). MASTERPLAN §7.5, §9.3, §9.7, §8.6.
--
-- The heist server, the data layer and the client remotes report plain facts here ("player 42
-- reached FirstBank", "Cash +300 for heist:BackRoom"); the Tracker turns them into the exact
-- AnalyticsService calls the dashboards need and queues them. src/server/Analytics/Analytics is a
-- thin adapter: it feeds facts in, drains calls out and executes them in pcall. Keeping the logic
-- here makes every rule testable in Lune: forward-only funnels, held steps, the join-source gate,
-- batching, per-player and server budgets, kill switches, Minute10 and the session KPIs.
--
-- Clock and flags are injected (opts.clock, opts.flag), so the Tracker never reads the engine.
--
-- Gate: a player's calls are held until their context is known (join source resolved, and the
-- profile facts arrived or FACTS_WAIT_SECONDS passed), because step 1 "Joined" must carry the
-- JoinSource custom field (dashboard filters apply to step 1 only). Leaving forces the context.

local Config = require("../Config")
local Events = require("./Events")
local Funnel = require("./Funnel")
local JoinSource = require("./JoinSource")
local PerfSample = require("./PerfSample")
local Sampling = require("./Sampling")
local Validator = require("../Rec/Validator")

local A = Config.Analytics
local DATA = Config.Data

export type Kind = "onboarding" | "funnel" | "custom" | "economy" | "progression"

export type Call = {
	kind: Kind,
	pid: number,
	name: string, -- custom event / funnel / progression path / currency
	step: number?, -- funnel step or progression level
	stepName: string?,
	session: string?, -- recurring funnel session id
	status: string?, -- progression: Start | Complete | Fail
	flow: string?, -- economy: Source | Sink
	amount: number?,
	balance: number?,
	transactionType: string?,
	sku: string?,
	value: number?,
	fields: { string }?,
	prio: number, -- 1 funnel/economy/progression, 2 custom
	at: number,
}

export type Facts = {
	isNew: boolean?, -- profile created in this session
	ftueStep: number?, -- saved onboarding index (DataService profile ftueStep)
	firstSeenDay: number?, -- UTC day number of the profile's creation
	today: number?, -- UTC day number now
}

export type HeistInfo = {
	heistId: string?, -- the server's heist id (GUID); also the funnel session id
	level: string, -- data key (BackRoom) or LevelSpec id (cs1_back_room)
	crew: number?, -- live crew size
	friends: number?, -- Roblox friends of this player in the crew
	daily: number?, -- daily vault design number when this is a daily vault
}

type Queued = { essential: boolean, run: () -> () }

type HeistState = {
	sess: Funnel.Session,
	clip: Funnel.Session,
	level: string,
	crew: number,
	daily: number?,
	opened: number,
}

type Player = {
	pid: number,
	joinedAt: number,
	joinUnix: number,
	join: JoinSource.Result?,
	variant: string,
	facts: Facts?,
	factsUntil: number,
	hardUntil: number, -- resolve by now even if the join source never arrived (a failed poll)
	resolved: boolean,
	cohort: string,
	queue: { Queued },
	onb: Funnel.OneTime,
	once: { [string]: boolean },
	timed: { [string]: boolean },
	budget: Sampling.Budget,
	batch: { [string]: { name: string, fields: { string }, value: number } },
	heists: { [string]: HeistState },
	heistCount: number,
	lastResults: string?,
	store: Funnel.Session?,
	storeCount: number,
	friendPlayed: boolean,
	crewMax: number,
	device: string?,
	lastPerfAt: number,
	minute10: boolean,
	lastLevel: string?, -- level of the newest heist (client-reported hints use it)
}

export type Opts = {
	clock: () -> number,
	flag: ((name: string) -> any)?, -- LiveFlags.get; nil = every flag at its default
	placeVersion: number?, -- game.PlaceVersion for ServerBuild (0 or nil: Config.Analytics.BUILD)
}

export type Stats = {
	queued: number,
	sent: number,
	batched: number,
	dropBudget: number,
	dropBacklog: number,
	dropHeld: number,
	dropKilled: number,
	invalid: number,
}

export type Tracker = {
	clock: () -> number,
	flag: (name: string) -> any,
	players: { [number]: Player },
	count: number,
	q1: { Call },
	q2: { Call },
	server: Sampling.Budget,
	lastFlush: number,
	build: string,
	buildLogged: boolean,
	stats: Stats,
}

local Tracker = {}

local K = Events.JOIN_TAG_KINDS

local TAINT_BITS: { { bit: number, name: string } } = {}
for name, bit in Validator.FLAG do
	table.insert(TAINT_BITS, { bit = bit, name = string.lower(name) })
end
table.sort(TAINT_BITS, function(a, b)
	return a.bit < b.bit
end)
Tracker.TAINT_BITS = TAINT_BITS

local function defaultFlag(name: string): any
	local def = Config.LiveFlags.Flags[name]
	return if def then def.default else nil
end

local function serverRate(count: number): number
	return (A.SERVER_PER_MINUTE + A.SERVER_PER_MINUTE_PER_PLAYER * count) / 60
end

-- The ServerBuild field: "pv" .. PlaceVersion % 100 (Events.DOMAINS.build), else "b<BUILD>".
function Tracker.buildName(placeVersion: number?): string
	local v = placeVersion
	if type(v) == "number" and v > 0 and v == math.floor(v) then
		return string.format("pv%02d", v % 100)
	end
	return "b" .. tostring(A.BUILD)
end

function Tracker.new(opts: Opts): Tracker
	local now = opts.clock()
	return {
		clock = opts.clock,
		flag = opts.flag or defaultFlag,
		players = {},
		count = 0,
		q1 = {},
		q2 = {},
		server = Sampling.newBudget(A.SERVER_BURST, serverRate(0), now),
		lastFlush = now,
		build = Tracker.buildName(opts.placeVersion),
		buildLogged = false,
		stats = {
			queued = 0,
			sent = 0,
			batched = 0,
			dropBudget = 0,
			dropBacklog = 0,
			dropHeld = 0,
			dropKilled = 0,
			invalid = 0,
		},
	}
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Data key for a LevelSpec id or data key; anything else stays as is (canon maps it to Other).
function Tracker.levelKey(level: any): string
	if type(level) ~= "string" then
		return "Other"
	end
	local mapped = Config.Heist.LEVEL_DATA_KEYS[level]
	return if mapped then mapped else level
end

local function crewName(n: number?): string
	local c = math.clamp(math.floor(n or 1), 1, 4)
	return Events.DOMAINS.crew.values[c]
end

local function source(p: Player): string
	return if p.join then p.join.source else "organic"
end

local function on(t: Tracker, name: string): boolean
	local ok, v = pcall(t.flag, name)
	if not ok or v == nil then
		return defaultFlag(name) == true
	end
	return v == true
end

local function number(t: Tracker, name: string): number
	local ok, v = pcall(t.flag, name)
	if ok and type(v) == "number" and v == v then
		return v
	end
	return defaultFlag(name) :: number
end

local function push(t: Tracker, call: Call)
	if not on(t, "analytics") or (call.kind == "custom" and not on(t, "analyticsCustom")) then
		t.stats.dropKilled += 1
		return
	end
	local q = if call.prio == 1 then t.q1 else t.q2
	table.insert(q, call)
	t.stats.queued += 1
	while #t.q1 + #t.q2 > A.BACKLOG_MAX do
		-- customs go first; funnel and economy calls only when the backlog is all of them
		if #t.q2 > 0 then
			table.remove(t.q2, 1)
		else
			table.remove(t.q1, 1)
		end
		t.stats.dropBacklog += 1
	end
end

-- Runs fn now when the player's context is known, else queues it (bounded).
local function gated(t: Tracker, p: Player, essential: boolean, fn: () -> ())
	if p.resolved then
		fn()
		return
	end
	table.insert(p.queue, { essential = essential, run = fn })
	if #p.queue > A.PENDING_PER_PLAYER then
		local victim = 1
		for i, q in p.queue do
			if not q.essential then
				victim = i
				break
			end
		end
		table.remove(p.queue, victim)
		t.stats.dropHeld += 1
	end
end

-- metered: reported through the public API (a buggy call site); internal session events are not.
local function emitCustom(t: Tracker, p: Player, name: string, values: { any }, raw: number?, metered: boolean?)
	local def = Events.CUSTOM[name]
	if not def then
		t.stats.invalid += 1
		return
	end
	if def.once == "session" then
		if p.once[name] then
			return
		end
		p.once[name] = true
	end
	local fields = Events.fields(def.fields, values)
	local value = Events.value(def, raw)
	if def.batch then
		local key = name .. "\0" .. table.concat(fields, "\0")
		local entry = p.batch[key]
		if entry then
			entry.value += value
		else
			p.batch[key] = { name = name, fields = fields, value = value }
		end
		t.stats.batched += 1
		return
	end
	if metered and not Sampling.take(p.budget, t.clock()) then
		t.stats.dropBudget += 1
		return
	end
	push(t, { kind = "custom", pid = p.pid, name = name, value = value, fields = fields, prio = 2, at = t.clock() })
end

local function custom(t: Tracker, pid: number, name: string, values: { any }, raw: number?)
	local p = t.players[pid]
	if not p then
		t.stats.invalid += 1
		return
	end
	gated(t, p, false, function()
		emitCustom(t, p, name, values, raw, true)
	end)
end

local function funnelCall(t: Tracker, p: Player, funnel: string, session: string, n: number, fields: { string }?)
	local f = Events.FUNNELS[funnel]
	push(t, {
		kind = "funnel",
		pid = p.pid,
		name = funnel,
		session = session,
		step = n,
		stepName = f.steps[n],
		fields = if n == 1 then fields else nil,
		prio = 1,
		at = t.clock(),
	})
end

local function joinFields(p: Player, domains: { string }): { string }
	local values = {}
	for i, d in domains do
		if d == "source" then
			values[i] = source(p)
		elseif d == "tag" then
			values[i] = if p.join then p.join.tag else K.none
		elseif d == "variant" then
			values[i] = p.variant
		elseif d == "cohort" then
			values[i] = p.cohort
		end
	end
	return Events.fields(domains, values)
end

local function progression(t: Tracker, p: Player, h: HeistState, status: string)
	local path = if h.daily then "Daily" else "Heist"
	local level = if h.daily then h.daily else (table.find(DATA.LEVEL_ORDER, h.level) or 0)
	if level <= 0 then
		return
	end
	push(t, {
		kind = "progression",
		pid = p.pid,
		name = path,
		status = status,
		step = level,
		stepName = if h.daily then string.format("v%02d", h.daily) else h.level,
		fields = Events.fields(Events.PROGRESSION[path].fields, { crewName(h.crew), source(p) }),
		prio = 1,
		at = t.clock(),
	})
end

---------------------------------------------------------------------------
-- Onboarding
---------------------------------------------------------------------------

local function sendOnboarding(t: Tracker, p: Player, steps: { number })
	local f = Events.FUNNELS[Events.ONBOARDING]
	for _, n in steps do
		push(t, {
			kind = "onboarding",
			pid = p.pid,
			name = Events.ONBOARDING,
			step = n,
			stepName = f.steps[n],
			fields = if n == 1 then joinFields(p, f.fields) else nil,
			prio = 1,
			at = t.clock(),
		})
	end
end

local function onboardingNow(t: Tracker, p: Player, step: string, at: number)
	local f = Events.FUNNELS[Events.ONBOARDING]
	if not table.find(f.steps, step) then
		t.stats.invalid += 1
		return
	end
	local first = not Funnel.isReached(p.onb, step)
	sendOnboarding(t, p, Funnel.reach(p.onb, step))
	if first and p.cohort == "new" and Events.DOMAINS.ftueStep.set[step] and not p.timed[step] then
		p.timed[step] = true
		local secs = at - p.joinedAt
		emitCustom(t, p, "FtueTiming", { step, secs, source(p) }, secs)
	end
end

-- A §7.5 funnel step (Events.FUNNELS.onb_v2.steps). Forward-only; held until the context is known.
function Tracker.onboarding(t: Tracker, pid: number, step: string)
	local p = t.players[pid]
	if not p then
		t.stats.invalid += 1
		return
	end
	local at = t.clock()
	gated(t, p, true, function()
		onboardingNow(t, p, step, at)
	end)
end

---------------------------------------------------------------------------
-- Players and context
---------------------------------------------------------------------------

function Tracker.playerJoined(t: Tracker, pid: number, joinUnix: number)
	if t.players[pid] then
		return
	end
	local now = t.clock()
	t.players[pid] = {
		pid = pid,
		joinedAt = now,
		joinUnix = math.floor(joinUnix),
		join = nil,
		variant = A.VARIANTS[1],
		facts = nil,
		factsUntil = now + A.FACTS_WAIT_SECONDS,
		hardUntil = now + A.JOIN_DATA_POLLS * A.JOIN_DATA_POLL_SECONDS + A.FACTS_WAIT_SECONDS,
		resolved = false,
		cohort = "unknown",
		queue = {},
		onb = Funnel.oneTime(Events.ONBOARDING),
		once = {},
		timed = {},
		budget = Sampling.newBudget(A.PLAYER_BURST, A.PLAYER_PER_MINUTE / 60, now),
		batch = {},
		heists = {},
		heistCount = 0,
		lastResults = nil,
		store = nil,
		storeCount = 0,
		friendPlayed = false,
		crewMax = 1,
		device = nil,
		lastPerfAt = -math.huge,
		minute10 = false,
		lastLevel = nil,
	}
	t.count += 1
	Sampling.setRate(t.server, now, serverRate(t.count))
end

local function retention(t: Tracker, p: Player)
	local facts = p.facts
	if not facts or facts.firstSeenDay == nil or facts.today == nil then
		return
	end
	local days = (facts.today :: number) - (facts.firstSeenDay :: number)
	local sid = "r" .. tostring(p.pid)
	if days == 0 then
		funnelCall(t, p, "ret_d1", sid, 1, joinFields(p, Events.FUNNELS.ret_d1.fields))
		funnelCall(t, p, "ret_d7", sid, 1, joinFields(p, Events.FUNNELS.ret_d7.fields))
	elseif days == 1 then
		funnelCall(t, p, "ret_d1", sid, 2)
	elseif days == 7 then
		funnelCall(t, p, "ret_d7", sid, 2)
	end
end

local function resolve(t: Tracker, p: Player)
	if p.resolved then
		return
	end
	p.resolved = true
	if not p.join then
		p.join = { source = "organic", tag = K.none }
	end
	local facts = p.facts
	if facts then
		p.cohort = if facts.isNew then "new" else "returning"
		if facts.ftueStep and facts.ftueStep > 0 then
			sendOnboarding(t, p, Funnel.seed(p.onb, facts.ftueStep))
		end
	end
	if not t.buildLogged then
		t.buildLogged = true
		emitCustom(t, p, "ServerBuild", { t.build }, 1)
	end
	onboardingNow(t, p, "Joined", p.joinedAt)
	local join = p.join :: JoinSource.Result
	emitCustom(t, p, "JoinSource", { join.source, join.tag, p.cohort }, 1)
	local invite = JoinSource.inviteKind(join)
	if invite then
		emitCustom(t, p, "InviteJoined", { invite, p.cohort }, 1)
	end
	retention(t, p)
	local queue = p.queue
	p.queue = {}
	for _, q in queue do
		q.run()
	end
end

local function maybeResolve(t: Tracker, p: Player)
	if p.resolved then
		return
	end
	local now = t.clock()
	if (p.join and (p.facts or now >= p.factsUntil)) or now >= p.hardUntil then
		resolve(t, p)
	end
end

-- The classified join (JoinSource.classify) and the player's experiment arm.
function Tracker.setJoin(t: Tracker, pid: number, join: JoinSource.Result, variant: string?)
	local p = t.players[pid]
	if not p or p.resolved then
		return
	end
	p.join = {
		source = Events.canon("source", join.source),
		tag = Events.canon("tag", join.tag),
		launch = join.launch,
	}
	p.variant = Events.canon("variant", variant)
	maybeResolve(t, p)
end

-- Profile facts from the data layer (DataService.Loaded). Late facts (after the gate opened)
-- still update the cohort for the session-end events.
function Tracker.setFacts(t: Tracker, pid: number, facts: Facts)
	local p = t.players[pid]
	if not p then
		return
	end
	p.facts = facts
	if p.resolved then
		p.cohort = if facts.isNew then "new" else "returning"
		if facts.ftueStep and facts.ftueStep > 0 then
			sendOnboarding(t, p, Funnel.seed(p.onb, facts.ftueStep))
		end
		return
	end
	maybeResolve(t, p)
end

function Tracker.hasPlayer(t: Tracker, pid: number): boolean
	return t.players[pid] ~= nil
end

function Tracker.cohort(t: Tracker, pid: number): string
	local p = t.players[pid]
	return if p then p.cohort else "unknown"
end

function Tracker.joinOf(t: Tracker, pid: number): JoinSource.Result?
	local p = t.players[pid]
	return if p then p.join else nil
end

local function flushPlayer(t: Tracker, p: Player)
	local keys = {}
	for key in p.batch do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local e = p.batch[key]
		push(t, {
			kind = "custom",
			pid = p.pid,
			name = e.name,
			value = e.value,
			fields = e.fields,
			prio = 2,
			at = t.clock(),
		})
	end
	table.clear(p.batch)
end

-- Session end: SessionEnd (length bucket = bounce and median session), SessionSocial (sessions
-- with a friend), then the player's batched counts. Forces the context if it was never known.
function Tracker.playerLeft(t: Tracker, pid: number)
	local p = t.players[pid]
	if not p then
		return
	end
	resolve(t, p)
	local secs = t.clock() - p.joinedAt
	emitCustom(t, p, "SessionEnd", { secs, p.cohort, source(p) }, secs / 60)
	emitCustom(t, p, "SessionSocial", { if p.friendPlayed then "yes" else "no", crewName(p.crewMax), p.cohort }, 1)
	flushPlayer(t, p)
	t.players[pid] = nil
	t.count -= 1
	Sampling.setRate(t.server, t.clock(), serverRate(t.count))
end

---------------------------------------------------------------------------
-- Timers and draining
---------------------------------------------------------------------------

-- Call about once a second: facts timeouts, Minute10, the batch flush.
function Tracker.tick(t: Tracker)
	local now = t.clock()
	local pids = {}
	for pid in t.players do
		table.insert(pids, pid)
	end
	table.sort(pids)
	for _, pid in pids do
		local p = t.players[pid]
		maybeResolve(t, p)
		if p.resolved and not p.minute10 and now - p.joinedAt >= A.MINUTE10_SECONDS then
			p.minute10 = true
			local swarm = Funnel.isReached(p.onb, "SwarmSeen")
			local l1 = Funnel.isReached(p.onb, "L1Complete")
			onboardingNow(t, p, "Minute10", now)
			if p.cohort == "new" then
				emitCustom(
					t,
					p,
					"FtueMinute10",
					{ if swarm then "yes" else "no", if l1 then "yes" else "no", source(p) },
					1
				)
			end
		end
	end
	if now - t.lastFlush >= A.BATCH_FLUSH_SECONDS then
		t.lastFlush = now
		for _, pid in pids do
			flushPlayer(t, t.players[pid])
		end
	end
end

-- Flushes every batch now (BindToClose).
function Tracker.flushAll(t: Tracker)
	for _, p in t.players do
		flushPlayer(t, p)
	end
	t.lastFlush = t.clock()
end

-- The kill switches also empty what is already queued: a switch thrown because AnalyticsService
-- itself misbehaves must stop the calls at once, not after the backlog drained for minutes.
-- Returns true when nothing may be sent at all.
local function applyKill(t: Tracker): boolean
	if not on(t, "analytics") then
		local n = #t.q1 + #t.q2
		if n > 0 then
			table.clear(t.q1)
			table.clear(t.q2)
			t.stats.dropKilled += n
		end
		return true
	end
	if #t.q2 > 0 and not on(t, "analyticsCustom") then
		t.stats.dropKilled += #t.q2 -- q2 holds only custom events (prio 2)
		table.clear(t.q2)
	end
	return false
end

-- Calls the server budget allows now, funnel/economy/progression first. max caps the count.
function Tracker.drain(t: Tracker, max: number?): { Call }
	local out: { Call } = {}
	if applyKill(t) then
		return out
	end
	local now = t.clock()
	local limit = max or math.huge
	for _, q in { t.q1, t.q2 } do
		local taken = 0
		while taken < #q and #out < limit and Sampling.take(t.server, now) do
			taken += 1
			table.insert(out, q[taken])
		end
		if taken > 0 then
			local n = #q
			table.move(q, taken + 1, n, 1)
			for i = n - taken + 1, n do
				q[i] = nil
			end
		end
	end
	t.stats.sent += #out
	return out
end

-- Everything queued, ignoring the budget (shutdown: the server is going away).
function Tracker.drainAll(t: Tracker): { Call }
	if applyKill(t) then
		return {}
	end
	local out = table.move(t.q1, 1, #t.q1, 1, {})
	table.move(t.q2, 1, #t.q2, #out + 1, out)
	table.clear(t.q1)
	table.clear(t.q2)
	t.stats.sent += #out
	return out
end

function Tracker.backlog(t: Tracker): number
	return #t.q1 + #t.q2
end

function Tracker.stats(t: Tracker): Stats
	return table.clone(t.stats)
end

---------------------------------------------------------------------------
-- Heist (heist_v1 + clip_v1 funnels, progression, custom events)
---------------------------------------------------------------------------

local function prune(p: Player)
	local n = 0
	local oldestId, oldestAt = nil, math.huge
	for id, h in p.heists do
		n += 1
		if h.opened < oldestAt and id ~= p.lastResults then
			oldestId, oldestAt = id, h.opened
		end
	end
	if n > A.HEIST_SESSIONS_KEPT and oldestId then
		p.heists[oldestId] = nil
	end
end

-- A heist attempt starts for this player (run 1). Returns the funnel session id it uses.
function Tracker.heistStarted(t: Tracker, pid: number, info: HeistInfo): string?
	local p = t.players[pid]
	if not p then
		t.stats.invalid += 1
		return nil
	end
	p.heistCount += 1
	local id = info.heistId
	if type(id) ~= "string" or #id == 0 or #id > 64 then
		id = string.format("h%d-%d-%d", p.pid, p.joinUnix, p.heistCount)
	end
	local sid = id :: string
	local level = Tracker.levelKey(info.level)
	local crew = math.clamp(math.floor(info.crew or 1), 1, 4)
	local daily = if type(info.daily) == "number" then math.floor(info.daily) else nil
	if (info.friends or 0) > 0 then
		p.friendPlayed = true
	end
	p.crewMax = math.max(p.crewMax, crew)
	p.lastLevel = if daily then "Daily" else level
	local at = t.clock()
	gated(t, p, true, function()
		local prev = p.lastResults and p.heists[p.lastResults :: string]
		if prev then
			local n = Funnel.advance(prev.sess, "NextHeist")
			if n then
				funnelCall(t, p, "heist_v1", prev.sess.id, n)
			end
		end
		local h: HeistState = {
			sess = Funnel.session("heist_v1", sid, at),
			clip = Funnel.session("clip_v1", sid, at),
			level = if daily then "Daily" else level,
			crew = crew,
			daily = daily,
			opened = at,
		}
		p.heists[sid] = h
		prune(p)
		local n = Funnel.advance(h.sess, "HeistStarted") :: number
		local fields = Events.fields(Events.FUNNELS.heist_v1.fields, { h.level, crewName(crew), source(p) })
		funnelCall(t, p, "heist_v1", sid, n, fields)
		progression(t, p, h, "Start")
	end)
	return sid
end

-- A heist_v1 step for this player's heist: FirstRewind, FirstBank, GoalMet, HeistComplete,
-- ResultsShown. ResultsShown also opens the clip funnel, and on Level 1 it is the onboarding
-- ReelShown step (the results card with the Crew Line-up, §7.5).
function Tracker.heistStep(t: Tracker, pid: number, heistId: string, step: string)
	local p = t.players[pid]
	if not p or not Events.stepNumber("heist_v1", step) or step == "HeistStarted" or step == "NextHeist" then
		t.stats.invalid += 1
		return
	end
	gated(t, p, true, function()
		local h = p.heists[heistId]
		if not h then
			t.stats.invalid += 1
			return
		end
		local n = Funnel.advance(h.sess, step)
		if n then
			funnelCall(t, p, "heist_v1", heistId, n)
		end
		if step == "HeistComplete" and n then
			progression(t, p, h, "Complete")
		elseif step == "ResultsShown" then
			p.lastResults = heistId
			local c = Funnel.advance(h.clip, "ResultsShown")
			if c then
				local fields = Events.fields(Events.FUNNELS.clip_v1.fields, { h.level, crewName(h.crew), source(p) })
				funnelCall(t, p, "clip_v1", heistId, c, fields)
			end
			if h.level == DATA.LEVEL_ORDER[1] then
				onboardingNow(t, p, "ReelShown", t.clock())
			end
		end
	end)
end

-- outcome: complete | dawn | left | abandoned | aborted. runs: runs played in this heist.
function Tracker.heistEnded(t: Tracker, pid: number, heistId: string, outcome: string, runs: number)
	local p = t.players[pid]
	if not p then
		t.stats.invalid += 1
		return
	end
	gated(t, p, false, function()
		local h = p.heists[heistId]
		local level = if h then h.level else "Other"
		emitCustom(t, p, "HeistEnded", { level, outcome, runs }, runs)
		if h and outcome == "dawn" then
			progression(t, p, h, "Fail")
		end
	end)
end

function Tracker.cloneFailed(t: Tracker, pid: number, cause: string, level: string)
	custom(t, pid, "CloneFailed", { cause, Tracker.levelKey(level) })
end

-- op: redo | redoFrom | delete | deleteBusted | undo (Protocol.DECK_OPS, first letter lowered)
function Tracker.deck(t: Tracker, pid: number, op: string, level: string)
	local key = Tracker.levelKey(level)
	if op == "redo" or op == "redoFrom" then
		custom(t, pid, "RedoUsed", { op, key })
	elseif op == "undo" then
		custom(t, pid, "UndoUsed", { key })
	elseif op == "delete" or op == "deleteBusted" then
		custom(t, pid, "DeleteUsed", { op, key })
	else
		t.stats.invalid += 1
	end
end

-- by: live | clone | catch (who tripped it; AlarmOn a = 0 means a catch)
function Tracker.alarmTripped(t: Tracker, pid: number, level: string, by: string)
	custom(t, pid, "AlarmTripped", { Tracker.levelKey(level), by })
end

function Tracker.alarmEscaped(t: Tracker, pid: number, level: string, crew: number)
	custom(t, pid, "AlarmEscaped", { Tracker.levelKey(level), crewName(crew) })
end

-- flags: Validator.FLAG bits of a tainted run. One bit -> its name, several -> "multi".
function Tracker.taintName(flags: number): string?
	if type(flags) ~= "number" or flags <= 0 then
		return nil
	end
	local found: string? = nil
	for _, b in TAINT_BITS do
		if bit32.band(flags, b.bit) ~= 0 then
			if found then
				return "multi"
			end
			found = b.name
		end
	end
	return found or "other"
end

function Tracker.taintedRun(t: Tracker, pid: number, flags: number, level: string)
	local name = Tracker.taintName(flags)
	if name then
		custom(t, pid, "TaintedRun", { name, Tracker.levelKey(level) })
	end
end

function Tracker.medal(t: Tracker, pid: number, medal: string, level: string)
	custom(t, pid, "MedalEarned", { medal, Tracker.levelKey(level) })
end

-- kind: plate | beam | mentor | ghost (§7.5 stuck hints). level defaults to the current heist's.
function Tracker.hint(t: Tracker, pid: number, kind: string, level: string?)
	local p = t.players[pid]
	local key = if level then Tracker.levelKey(level) elseif p and p.lastLevel then p.lastLevel else "Other"
	custom(t, pid, "FtueHint", { kind, key, if p then p.cohort else "unknown" })
end

function Tracker.relaxedChosen(t: Tracker, pid: number, level: string)
	local p = t.players[pid]
	custom(t, pid, "RelaxedChosen", { Tracker.levelKey(level), if p then p.cohort else "unknown" })
end

-- vault: design number; result: cleared | failed | catchup
function Tracker.dailyVault(t: Tracker, pid: number, vault: number, result: string)
	local p = t.players[pid]
	local v = string.format("v%02d", math.clamp(math.floor(vault), 0, 99))
	custom(t, pid, "DailyVaultPlayed", { v, result, if p then p.cohort else "unknown" })
end

function Tracker.quickCrewJoined(t: Tracker, pid: number, crew: number)
	local p = t.players[pid]
	custom(t, pid, "QuickCrewJoined", { crewName(crew), if p then p.cohort else "unknown" })
end

-- kind: invite | share (a prompt was opened; sends are invisible, vault "Friend Invites" §2)
function Tracker.inviteSent(t: Tracker, pid: number, kind: string)
	custom(t, pid, "InviteSent", { kind })
end

function Tracker.rsvp(t: Tracker, pid: number, accepted: boolean)
	custom(t, pid, "RsvpPrompted", { if accepted then "yes" else "no" })
end

function Tracker.referralQualified(t: Tracker, pid: number)
	local p = t.players[pid]
	custom(t, pid, "ReferralQualified", { if p then source(p) else "organic" })
end

-- Any catalog event with positional field values (Events.CUSTOM[name].fields order).
function Tracker.custom(t: Tracker, pid: number, name: string, values: { any }?, value: number?)
	custom(t, pid, name, values or {}, value)
end

---------------------------------------------------------------------------
-- SAVE CLIP (clip_v1 + ClipSaveTapped / ClipShareResult), client-reported via Analytics.Ui
---------------------------------------------------------------------------

Tracker.CLIP_ACTIONS = table.freeze({
	tap = true,
	captured = true,
	saved = true,
	shared = true,
	cancelled = true,
	failed = true,
	unsupported = true,
})

-- action: tap | captured | saved | shared | cancelled | failed | unsupported; kind: video | screenshot
function Tracker.clip(t: Tracker, pid: number, action: string, kind: string)
	local p = t.players[pid]
	if not p or not Tracker.CLIP_ACTIONS[action] then
		t.stats.invalid += 1
		return
	end
	gated(t, p, false, function()
		local sid = p.lastResults
		local h = if sid then p.heists[sid] else nil
		local level = if h then h.level else "Other"
		local step = if action == "tap"
			then "ClipTapped"
			elseif action == "captured" then "ClipCaptured"
			elseif action == "saved" or action == "shared" then "ClipKept"
			else nil
		if h and step then
			local n = Funnel.advance(h.clip, step)
			if n then
				funnelCall(t, p, "clip_v1", h.clip.id, n)
			end
		end
		if action == "tap" then
			emitCustom(t, p, "ClipSaveTapped", { kind, level }, 1, true)
		elseif action ~= "captured" then
			emitCustom(t, p, "ClipShareResult", { action, kind }, 1, true)
		end
	end)
end

---------------------------------------------------------------------------
-- Store (store_v1)
---------------------------------------------------------------------------

-- step: StoreOpened (detail = entry: van | results | garage) | ItemViewed (category) |
-- PromptShown (product key) | PurchaseGranted (product key). Only StoreOpened opens a session: a
-- session stays open STORE_SESSION_SECONDS, a StoreOpened within STORE_REOPEN_SECONDS of the last
-- one reuses it, and a player opens at most STORE_SESSIONS_MAX. A prompt or purchase with no open
-- session is OutOfStorePurchase (a funnel session starting at step 3 or 4 would count steps 1-2 as
-- complete with empty step-1 fields). metered = reported by the client (Analytics.Ui): it spends
-- the player's budget, so a spamming client cannot flood the server's.
function Tracker.store(t: Tracker, pid: number, step: string, detail: string?, metered: boolean?)
	local p = t.players[pid]
	if not p or not Events.stepNumber("store_v1", step) then
		t.stats.invalid += 1
		return
	end
	local at = t.clock()
	if metered and not Sampling.take(p.budget, at) then
		t.stats.dropBudget += 1
		return
	end
	gated(t, p, true, function()
		local s = p.store
		local open = s ~= nil and at - s.opened <= A.STORE_SESSION_SECONDS
		if step == "StoreOpened" then
			if open and at - (s :: Funnel.Session).opened < A.STORE_REOPEN_SECONDS then
				return -- reopened right away: the same session
			end
			if p.storeCount >= A.STORE_SESSIONS_MAX then
				t.stats.dropBudget += 1
				return
			end
			p.storeCount += 1
			s = Funnel.session("store_v1", string.format("s%d-%d-%d", p.pid, p.joinUnix, p.storeCount), at)
			p.store = s
		elseif not open then
			if step == "PromptShown" or step == "PurchaseGranted" then
				emitCustom(t, p, "OutOfStorePurchase", { step, detail, p.cohort }, 1)
			else
				t.stats.invalid += 1 -- an item card with no open store
			end
			return
		end
		local sess = s :: Funnel.Session
		local n = Funnel.advance(sess, step)
		if n then
			local entry = if step == "StoreOpened" then detail else "other"
			local fields = Events.fields(Events.FUNNELS.store_v1.fields, { entry, p.cohort, source(p) })
			funnelCall(t, p, "store_v1", sess.id, n, fields)
		end
	end)
end

---------------------------------------------------------------------------
-- Economy (from Currency.Changed, after the change)
---------------------------------------------------------------------------

-- delta: signed change; balance: after it; reason: the Currency reason; stars: the player's Stars.
function Tracker.economy(
	t: Tracker,
	pid: number,
	currency: string,
	delta: number,
	balance: number,
	reason: string,
	stars: number?
)
	local p = t.players[pid]
	if not p then
		t.stats.invalid += 1
		return
	end
	if not table.find(Events.ECONOMY.CURRENCIES, currency) or type(delta) ~= "number" or delta ~= delta then
		t.stats.invalid += 1
		return
	end
	if delta == 0 or (delta < 0 and Events.ECONOMY.SOURCE_ONLY[currency]) then
		return
	end
	local entry = Events.economyEntry(reason)
	if not entry then
		return
	end
	local e = entry :: Events.EconomyEntry
	gated(t, p, true, function()
		push(t, {
			kind = "economy",
			pid = p.pid,
			name = currency,
			flow = if delta > 0 then "Source" else "Sink",
			amount = math.abs(delta),
			balance = math.max(0, balance),
			transactionType = e.transactionType,
			sku = e.sku,
			fields = Events.fields(Events.ECONOMY.FIELDS, { stars or 0, p.cohort, source(p) }),
			prio = 1,
			at = t.clock(),
		})
	end)
end

---------------------------------------------------------------------------
-- Client reports (Analytics.Ready / Analytics.Perf)
---------------------------------------------------------------------------

-- The client has control (first frame with input and a character). Once per session.
function Tracker.clientReady(t: Tracker, pid: number, device: string?)
	local p = t.players[pid]
	if not p or p.once.Ready then
		return
	end
	p.once.Ready = true
	local secs = t.clock() - p.joinedAt
	p.device = Events.canon("device", device)
	gated(t, p, false, function()
		emitCustom(t, p, "JoinToControl", { secs, p.device, p.cohort }, secs)
	end)
end

-- A validated PerfSample.Sample. Sampled per player (perfSampleRate, sticky), at most one per
-- half interval (a client sending faster is ignored).
function Tracker.perf(t: Tracker, pid: number, sample: PerfSample.Sample)
	local p = t.players[pid]
	if not p or not on(t, "perfSampling") then
		return
	end
	local rate = number(t, "perfSampleRate")
	if not Sampling.inPercent(pid, "perf", rate * 100) then
		return
	end
	local now = t.clock()
	local interval = number(t, "perfIntervalSeconds")
	if now - p.lastPerfAt < interval * 0.5 then
		t.stats.dropBudget += 1
		return
	end
	p.lastPerfAt = now
	p.device = sample.device
	gated(t, p, false, function()
		for _, e in PerfSample.events(sample) do
			emitCustom(t, p, e.name, e.fields, e.value)
		end
	end)
end

function Tracker.perfStepDown(t: Tracker, pid: number, tier: string)
	local p = t.players[pid]
	custom(t, pid, "PerfStepDown", { if p and p.device then p.device else "other", tier })
end

return table.freeze(Tracker)
