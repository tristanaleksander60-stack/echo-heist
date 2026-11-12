--!strict
-- Heist/HeistInstance: one heist for one party (a solo player, or friends who joined
-- each other). MASTERPLAN §3.3 (instances in a shared server), §8.2 (server sim +
-- client view), §8.6 (budgets), §8.10 (lag fairness), §7.5 (L1 FTUE), §5.3 (daily vault).
--
-- It owns a Sim/HeistSim, a copy of the level at its own origin (greybox, dressed with
-- the art kit when it is loaded; collision is always the sim's boxes), its crew, and
-- the routing of their intents. The server is authoritative for every outcome: the sim
-- decides plates, doors, lasers, Gus, loot and banking from actor positions; characters
-- only feed positions in (setInput) and intents go through HeistSim.
--
-- Level: a Levels/Catalog index (story and party levels), or Protocol.DAILY_INDEX with
-- opts.daily (the daily vault of a UTC day: Levels/DailyVaults.forDay). LiveFlags tuning
-- (alarm van/lock seconds, chase speed, crew clone budget, the Alarm Run kill switch) is
-- read once by the service at heist start, applied here and kept with the heist
-- (inst.tuning: the Tuning attribute, Sync and the results card), never changed mid-run.
--
-- Everything is driven by HeistInstance.update(inst, serverNow) from the service's
-- Heartbeat (or by the engine smoke test with synthetic times): input sampling, the
-- 20 Hz sim (fixed-step accumulator on the run's LoopClock), streaming and timers.
-- No task.wait / task.delay in here, so a test can run a whole heist in one frame.
--
-- Replication per instance (§8.2, Heist/Protocol): attributes on the instance folder
-- for state (doors solidAt, lasers onAt, plates, loot, Gus mode/offset/meter, alarm),
-- one reliable push for moments (Run, Ev event-log slices, Clock, RunEnd, Deck, Over)
-- and each new recording once per client as a Codec buffer (Rec).
--
-- Results (onOver): story and party levels -> award(player, dataKey, data) per member
-- (party: that member's own swarm as `clones`), daily vaults -> awardDaily(player, day,
-- result.daily) (DataService.awardDailyVault). Analytics (docs/ANALYTICS.md "Call
-- sites") goes through opts.analytics; every call there swallows its own errors.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Sim = Shared:WaitForChild("Sim")
local HeistSim = require(Sim:WaitForChild("HeistSim"))
local LevelSpec = require(Sim:WaitForChild("LevelSpec"))
local Mechanisms = require(Sim:WaitForChild("Mechanisms"))
local EventLog = require(Sim:WaitForChild("EventLog"))
local Rec = Shared:WaitForChild("Rec")
local Codec = require(Rec:WaitForChild("Codec"))
local Validator = require(Rec:WaitForChild("Validator"))
local Catalog = require(Shared:WaitForChild("Levels"):WaitForChild("Catalog"))
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))

local LevelBuilder = require(script.Parent:WaitForChild("LevelBuilder"))

local EV = EventLog.EV
local FLAG = Codec.FLAG
local CAUSE = HeistSim.CAUSE
local RUN_END = HeistSim.RUN_END
local TAU = 2 * math.pi
local H = Config.Heist
local S = Config.Sim

local HeistInstance = {}

export type Member = {
	userId: number,
	player: Player?, -- nil for a fake member (engine smoke test)
	name: string,
	ready: boolean,
	reduced: boolean,
	friends: number, -- friends in this crew (co-op Cash bonus)
	left: boolean,
	fake: { x: number, y: number, z: number, yaw: number }?,
	ftue: { [string]: boolean },
	ownMax: number?, -- party levels: most of this member's own clones in one run
}

-- LiveFlags tuning read at heist start (HeistService.tuning); nil fields = Config defaults.
export type Tuning = {
	alarmRun: boolean?,
	alarmVanSeconds: number?,
	alarmLockSeconds: number?,
	alarmChaseSpeedMult: number?,
	crewCloneBudget: number?,
}

export type Daily = {
	day: number,
	slot: number,
	modifier: string,
	mode: string, -- "today" | "catchUp"
	advent: number?,
	startDay: number?, -- server day when the heist started (the award honours it across the reset)
}

export type Opts = {
	id: number,
	levelIndex: number,
	daily: Daily?, -- with levelIndex = Protocol.DAILY_INDEX
	origin: Vector3,
	parent: Instance,
	members: { Member },
	leader: number,
	heistId: string,
	firstHeist: boolean?,
	tuning: Tuning?,
	build: LevelBuilder.BuildOpts?, -- art kit and Christmas dressing
	push: ((player: Player, kind: string, payload: any) -> ())?,
	award: ((player: Player, dataKey: string, data: any, opts: any?) -> any)?,
	awardDaily: ((player: Player, day: number, result: any, startedDay: number?) -> any)?,
	nextInfo: ((player: Player, nextIndex: number) -> any)?, -- NEXT on the results card
	-- per member (unlocked / starsNeeded / needsClear), read after the award
	onFtue: ((player: Player, step: string) -> ())?,
	analytics: any?, -- server Analytics module (or nil)
}

local levelCache: { [string]: any } = {}

-- Compiled LevelData for a Catalog index, or (index = Protocol.DAILY_INDEX) for the daily
-- vault of `dailyDay`. Compiled once per server (per day for the daily vaults).
function HeistInstance.levelData(index: number, dailyDay: number?): any
	local key = if index == Protocol.DAILY_INDEX then "d" .. tostring(dailyDay) else tostring(index)
	local cached = levelCache[key]
	if cached then
		return cached
	end
	local spec = Protocol.levelSpec(index, dailyDay)
	assert(spec, "HeistInstance: no level " .. key)
	local level = LevelSpec.compile(spec)
	levelCache[key] = level
	return level
end

-- The tuning actually used (every field filled), so it can be stored with the heist.
function HeistInstance.resolveTuning(t: Tuning?): { [string]: any }
	local o = t or {}
	return {
		alarmRun = o.alarmRun ~= false,
		alarmVanSeconds = o.alarmVanSeconds or S.ALARM_VAN_SECONDS,
		alarmLockSeconds = o.alarmLockSeconds or S.ALARM_LOCK_SECONDS,
		alarmChaseSpeedMult = o.alarmChaseSpeedMult or S.GUARD_CHASE_SPEED_MULT,
		crewCloneBudget = o.crewCloneBudget or S.CREW_CLONE_BUDGET,
	}
end

local function tuningText(t: { [string]: any }): string
	return string.format(
		"alarm=%s van=%g lock=%g chase=%g budget=%d",
		if t.alarmRun then "on" else "off",
		t.alarmVanSeconds,
		t.alarmLockSeconds,
		t.alarmChaseSpeedMult,
		t.crewCloneBudget
	)
end

-- A per-heist copy of the level with the alarm tuning applied. Seconds a level sets
-- itself (Clone Party's shutter) are kept; the flags move the Config defaults only.
local function tunedLevel(level: any, t: { [string]: any }): any
	local alarm = level.alarm
	if not alarm then
		return level
	end
	local specAlarm = level.spec and level.spec.alarm or {}
	local van = if specAlarm.vanSeconds == nil then t.alarmVanSeconds else alarm.vanSeconds
	local lock = if specAlarm.lockSeconds == nil then t.alarmLockSeconds else alarm.lockSeconds
	if t.alarmRun and van == alarm.vanSeconds and lock == alarm.lockSeconds then
		return level
	end
	local copy = table.clone(level)
	if not t.alarmRun then
		copy.alarm = nil -- kill switch: grabbing the top loot no longer starts a chase
	else
		local a = table.clone(alarm)
		a.vanSeconds, a.lockSeconds = van, lock
		copy.alarm = a
	end
	return copy
end

local function rootOf(member: Member): BasePart?
	local player = member.player
	local char = player and player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function humanoidOf(member: Member): Humanoid?
	local player = member.player
	local char = player and player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function kindOf(inst: any): string
	if inst.daily then
		return Protocol.KIND.Daily
	end
	return if inst.level.kind == "party" then Protocol.KIND.Party else Protocol.KIND.Story
end

local function levelInfo(inst: any): Protocol.LevelInfo
	local level = inst.level
	return {
		id = level.id,
		name = level.name,
		kind = kindOf(inst),
		num = level.num,
		dataKey = inst.dataKey,
		location = level.spec and level.spec.location,
	}
end

-- The Clone Deck is read-only on the L1 tutorial (taught from L2, §3.4) and on party
-- levels: every clone stays in the party, so Delete / Redo can never silently turn
-- "8 OF ME" into "7 OF ME" (Config.Sim.SWARM_OF_ME at Dawn).
local function deckLocked(level: any): boolean
	return level.tutorial ~= nil or level.kind == "party"
end

-- StreamingEnabled readiness (MASTERPLAN §3.3/§8.6): the level model streams to its
-- crew whatever the distance (PersistentPerPlayer) and to nobody else; harmless while
-- the place has streaming off.
local function persistFor(inst: any, player: Player?, on: boolean)
	local model = inst.built and inst.built.model
	if not (player and model and model:IsA("Model")) then
		return
	end
	pcall(function()
		if on then
			model:AddPersistentPlayer(player)
		else
			model:RemovePersistentPlayer(player)
		end
	end)
end

function HeistInstance.new(o: Opts): any
	local daily = o.daily
	local base = HeistInstance.levelData(o.levelIndex, if daily then daily.day else nil)
	local tuning = HeistInstance.resolveTuning(o.tuning)
	local level = tunedLevel(base, tuning)
	local folder = Instance.new("Folder")
	folder.Name = Protocol.instanceName(o.id)
	local built = LevelBuilder.build(level, o.origin, folder, o.build)
	local ids = {}
	for _, m in o.members do
		table.insert(ids, m.userId)
	end
	local sim = HeistSim.new(level, {
		players = ids,
		firstHeist = o.firstHeist == true,
		walkSpeed = Config.Rec.WALK_SPEED,
	})
	if tuning.alarmChaseSpeedMult ~= S.GUARD_CHASE_SPEED_MULT then
		sim.ctx.chaseSpeed = tuning.alarmChaseSpeedMult * sim.walkSpeed
	end
	local inst = {
		id = o.id,
		name = folder.Name,
		folder = folder,
		built = built,
		level = level,
		levelIndex = o.levelIndex,
		daily = daily,
		dataKey = if daily then nil else H.LEVEL_DATA_KEYS[level.id],
		trackLevel = if daily then "Daily" else (H.LEVEL_DATA_KEYS[level.id] or level.id),
		tuning = tuning,
		origin = o.origin,
		heistId = o.heistId,
		leader = o.leader,
		sim = sim,
		members = o.members,
		byId = {} :: { [number]: Member },
		push = o.push,
		award = o.award,
		awardDaily = o.awardDaily,
		nextInfo = o.nextInfo,
		onFtue = o.onFtue,
		analytics = o.analytics,
		-- recordings
		recKeys = setmetatable({}, { __mode = "k" }) :: any,
		recBufs = {} :: { [number]: buffer },
		recOwner = {} :: { [number]: number },
		nextKey = 0,
		sent = {} :: { [number]: { [number]: boolean } },
		-- streaming
		evCursor = 0,
		clockRef = nil :: any,
		attrs = {} :: { [string]: any },
		attrTick = -2, -- sim tick of the last attribute sync (state changes only on ticks)
		keys = nil :: any, -- attribute names, built once (syncAttributes)
		lastPoseAt = -math.huge,
		runMsg = nil :: any,
		overMsg = nil :: any,
		-- per-run facts seen in the event log (alarm, swarm)
		alarmBy = -1,
		alarmTick = -1,
		bankAfterAlarm = false,
		runSwarm = 0,
		maxOfMe = 0,
		alarmHint = nil :: any,
		-- timers (server time)
		phaseSeen = "Lobby",
		startAt = 0,
		frozen = false,
		autoReadyAt = math.huge,
		overAt = nil :: number?,
		dead = false,
	}
	for _, m in o.members do
		inst.byId[m.userId] = m
		inst.sent[m.userId] = {}
		m.ownMax = 0
		persistFor(inst, m.player, true)
	end
	folder:SetAttribute("LevelIndex", o.levelIndex)
	folder:SetAttribute("LevelId", level.id)
	folder:SetAttribute("Kind", kindOf(inst))
	folder:SetAttribute("Origin", o.origin)
	folder:SetAttribute("HeistId", o.heistId)
	folder:SetAttribute("Leader", o.leader)
	folder:SetAttribute("Goal", level.goal)
	folder:SetAttribute("Tuning", tuningText(tuning))
	folder:SetAttribute("Kit", built.kit == true)
	folder:SetAttribute("Dressing", built.dressing == true)
	if daily then
		folder:SetAttribute("Daily", daily.day)
	end
	for i, def in level.loot do
		if def.opensAt then
			folder:SetAttribute("K" .. i .. "OpensAt", def.opensAt)
		end
	end
	folder.Parent = o.parent
	return inst
end

---------------------------------------------------------------------------
-- Analytics (docs/ANALYTICS.md "Call sites"; never in the way of the game)
---------------------------------------------------------------------------

local function track(inst: any, fn: string, ...: any)
	local a = inst.analytics
	local f = a and a[fn]
	if type(f) == "function" then
		pcall(f, ...)
	end
end

local function trackMember(inst: any, member: Member?, fn: string, ...: any)
	local player = member and member.player
	if player and not (member :: Member).left then
		track(inst, fn, player, ...)
	end
end

local function trackAll(inst: any, fn: string, ...: any)
	for _, m in inst.members do
		trackMember(inst, m, fn, ...)
	end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function send(inst: any, member: Member, kind: string, payload: any)
	local player = member.player
	if player and inst.push and not member.left then
		inst.push(player, kind, payload)
	end
end

local function sendAll(inst: any, kind: string, payload: any)
	for _, m in inst.members do
		send(inst, m, kind, payload)
	end
end

local function keyOf(inst: any, rec: any, ownerId: number): number
	local key = inst.recKeys[rec]
	if key then
		return key
	end
	inst.nextKey += 1
	key = inst.nextKey
	inst.recKeys[rec] = key
	inst.recBufs[key] = Codec.encode(rec)
	inst.recOwner[key] = ownerId
	return key
end

-- Sends every recording in `keys` that this member has not received yet (once each).
local function ensureRecs(inst: any, member: Member, keys: { number })
	local sent = inst.sent[member.userId]
	if not sent then
		return
	end
	for _, key in keys do
		if key > 0 and not sent[key] and inst.recBufs[key] then
			sent[key] = true
			send(inst, member, "Rec", { key = key, owner = inst.recOwner[key], buf = inst.recBufs[key] })
		end
	end
end

local function deckFor(inst: any, member: Member): any
	local deck = HeistSim.deckOf(inst.sim, member.userId)
	if not deck then
		return nil
	end
	local slots = {}
	for i, s in deck.slots do
		slots[i] = { status = s.status, run = s.run, key = keyOf(inst, s.rec, member.userId) }
	end
	local hint = nil
	local alarm = inst.alarmHint
	if alarm and alarm.ownerId == member.userId and alarm.slot > 0 then
		hint = { kind = alarm.hint, slot = alarm.slot, t = alarm.t }
	end
	return {
		cap = deck.cap,
		slots = slots,
		redo = deck.redo or 0,
		canUndo = deck.undo ~= nil,
		locked = deckLocked(inst.level), -- L1 (taught from L2, §3.4) and party levels
		party = inst.level.kind == "party",
		hint = hint,
	}
end

local function sendDeck(inst: any, member: Member)
	local d = deckFor(inst, member)
	if d then
		local keys = {}
		for _, s in d.slots do
			table.insert(keys, s.key)
		end
		ensureRecs(inst, member, keys)
		send(inst, member, "Deck", d)
	end
end

local function runMessage(inst: any, transition: number, kind: string): any
	local sim = inst.sim
	local actors = {}
	local keys = {}
	local own: { [number]: number } = {}
	for _, a in sim.actors do
		local key, run = 0, sim.runIndex
		if a.kind == "clone" then
			key = keyOf(inst, a.rec, a.ownerId)
			table.insert(keys, key)
			local slot = a.player.deck.slots[a.slot]
			run = if slot then slot.run else 0
			if not a.helper then
				own[a.ownerId] = (own[a.ownerId] or 0) + 1
			end
		end
		table.insert(actors, {
			id = a.id,
			kind = a.kind,
			owner = a.ownerId,
			seat = a.seat,
			slot = a.slot,
			key = key,
			run = run,
			orphan = a.player.orphan == true,
			helper = a.helper == true,
			capacity = a.capacity, -- bag size (the HUD hides GRAB only when it is full)
		})
	end
	for userId, n in own do
		local m = inst.byId[userId]
		if m then
			m.ownMax = math.max(m.ownMax or 0, n)
		end
	end
	return {
		run = sim.runIndex,
		clock = Protocol.clockData(sim.clock),
		actors = actors,
		transition = transition,
		kind = kind,
		cap = sim.cap,
		keys = keys,
	}
end

---------------------------------------------------------------------------
-- Attributes (state replication, written only on change)
---------------------------------------------------------------------------

local function setAttr(inst: any, name: string, value: any)
	if inst.attrs[name] ~= value then
		inst.attrs[name] = value
		inst.folder:SetAttribute(name, value)
	end
end

local function round(v: number, step: number): number
	return math.floor(v / step + 0.5) * step
end

-- Attribute names per instance, built once (no string building in the per-frame sync).
local function keysOf(inst: any): any
	local keys = inst.keys
	if keys then
		return keys
	end
	local sim = inst.sim
	local function list(prefix: string, n: number, suffixes: { string }): { { string } }
		local out = {}
		for i = 1, n do
			local row = {}
			for j, suffix in suffixes do
				row[j] = prefix .. i .. suffix
			end
			out[i] = row
		end
		return out
	end
	keys = {
		doors = list("D", #sim.mech.doors, { "Open", "Solid", "SolidAt" }),
		lasers = list("L", #sim.mech.lasers, { "On", "OnAt" }),
		plates = list("P", #sim.mech.plates, { "Held", "By" }),
		loot = list("K", #sim.loot.items, { "State", "Carrier", "Pos" }),
		guards = list("G", #sim.guards, { "Offset", "Mode", "Focus", "X", "Z", "Yaw", "Meter", "Stage" }),
	}
	inst.keys = keys
	return keys
end

local function syncAttributes(inst: any, now: number)
	local sim = inst.sim
	local mech = sim.mech
	setAttr(inst, "Phase", sim.phase)
	setAttr(inst, "RunIndex", sim.runIndex)
	setAttr(inst, "Banked", sim.banked)
	setAttr(inst, "TierMet", sim.tierMet)
	setAttr(inst, "CanFF", sim.phase == "Run" and now >= inst.startAt and HeistSim.canFastForward(sim))
	setAttr(inst, "AutoEndArmed", sim.phase == "Run" and HeistSim.autoEndArmed(sim) ~= nil)
	-- Sim state only changes on its 20 Hz ticks: skip the frames in between.
	if sim.tick == inst.attrTick and sim.phase == "Run" then
		return
	end
	inst.attrTick = sim.tick
	local keys = keysOf(inst)
	for i, d in mech.doors do
		local k = keys.doors[i]
		setAttr(inst, k[1], d.open)
		setAttr(inst, k[2], d.solid)
		setAttr(inst, k[3], if d.solidAt then round(d.solidAt, 0.001) else -1)
	end
	for i, l in mech.lasers do
		local k = keys.lasers[i]
		setAttr(inst, k[1], l.on)
		setAttr(inst, k[2], if l.onAt then round(l.onAt, 0.001) else -1)
	end
	for i, p in mech.plates do
		local k = keys.plates[i]
		setAttr(inst, k[1], Mechanisms.plateHeld(mech, i, sim.t))
		setAttr(inst, k[2], p.firstActor)
	end
	for i, item in sim.loot.items do
		local k = keys.loot[i]
		setAttr(inst, k[1], item.state)
		setAttr(inst, k[2], item.carrier)
		if item.state ~= "Carried" then
			setAttr(inst, k[3], Vector3.new(round(item.x, 0.01), round(item.y, 0.01), round(item.z, 0.01)))
		end
	end
	local poseDue = now - inst.lastPoseAt >= 1 / H.GUARD_POSE_HZ
	if poseDue then
		inst.lastPoseAt = now
	end
	for i, g in sim.guards do
		local k = keys.guards[i]
		-- Clients read Offset only on patrol (GusView): it is not re-sent while he is held.
		if g.mode == "Patrol" then
			setAttr(inst, k[1], round(g.offset, 0.001))
		end
		setAttr(inst, k[2], g.mode)
		setAttr(inst, k[3], g.focus)
		if g.mode ~= "Patrol" and poseDue then
			setAttr(inst, k[4], round(g.x, 0.01))
			setAttr(inst, k[5], round(g.z, 0.01))
			setAttr(inst, k[6], round(g.yaw, 0.01))
		end
		local meter, stage = 0, 0
		for _, a in sim.actors do
			meter = math.max(meter, g.meter[a.id] or 0)
			stage = math.max(stage, g.stage[a.id] or 0)
		end
		setAttr(inst, k[7], round(meter, H.METER_STEP))
		setAttr(inst, k[8], stage)
	end
	local alarm = sim.alarm
	setAttr(inst, "AlarmOn", alarm.active)
	setAttr(inst, "AlarmVanAt", round(alarm.vanAt, 0.01))
	setAttr(inst, "AlarmLockAt", if alarm.active then round(alarm.lockAt, 0.01) else -1)
	setAttr(inst, "AlarmBy", inst.alarmBy)
	local ready, total = 0, 0
	for _, m in inst.members do
		if not m.left then
			total += 1
			if m.ready then
				ready += 1
			end
		end
	end
	setAttr(inst, "Ready", ready)
	setAttr(inst, "Crew", total)
end

---------------------------------------------------------------------------
-- Event-log hooks: FTUE (§7.5 funnel steps the server can see), analytics, alarm
---------------------------------------------------------------------------

local function ftue(inst: any, member: Member?, step: string)
	if not member or member.ftue[step] then
		return
	end
	member.ftue[step] = true
	local player = member.player
	if player and inst.onFtue then
		inst.onFtue(player, step)
	end
end

local function memberOfActor(inst: any, actorId: number): (Member?, any)
	local a = inst.sim.actors[actorId]
	if not a then
		return nil, nil
	end
	return inst.byId[a.ownerId], a
end

-- A crew member to report an orphan tape's failure on (the owner left).
local function reporterFor(inst: any, owner: Member?): Member?
	if owner and not owner.left then
		return owner
	end
	for _, m in inst.members do
		if not m.left then
			return m
		end
	end
	return nil
end

local function cloneFailed(inst: any, actorId: number, cause: string)
	local m, a = memberOfActor(inst, actorId)
	if not a or a.kind ~= "clone" then
		return
	end
	if m == nil or m.left then
		trackMember(inst, reporterFor(inst, m), "cloneFailed", "orphaned", inst.trackLevel)
	else
		trackMember(inst, m, "cloneFailed", cause, inst.trackLevel)
	end
end

local function scanLog(inst: any, from: number, to: number)
	local sim = inst.sim
	local log = sim.log
	for i = from, to do
		local kind = log.kind[i]
		if kind == EV.PlateDown then
			local m, a = memberOfActor(inst, log.b[i])
			if a and a.kind == "live" then
				ftue(inst, m, "FirstPlate")
			end
		elseif kind == EV.RunStart and log.a[i] >= 2 then
			for _, m in inst.members do
				if not m.ftue.FirstRewind then
					trackMember(inst, m, "heistStep", inst.heistId, "FirstRewind")
				end
				ftue(inst, m, "FirstRewind")
				if log.b[i] > 0 then
					ftue(inst, m, "FirstCloneSeen")
				end
			end
		elseif kind == EV.Bank then
			local m = memberOfActor(inst, log.a[i])
			if m and not m.ftue.FirstBank then
				trackMember(inst, m, "heistStep", inst.heistId, "FirstBank")
			end
			ftue(inst, m, "FirstBank")
			if inst.alarmTick >= 0 then
				inst.bankAfterAlarm = true
			end
		elseif kind == EV.GoalMet then
			trackAll(inst, "heistStep", inst.heistId, "GoalMet")
		elseif kind == EV.Busted then
			local m = memberOfActor(inst, log.b[i])
			ftue(inst, m, "FirstCloneBusted")
			cloneFailed(inst, log.b[i], "busted")
		elseif kind == EV.Zap then
			cloneFailed(inst, log.a[i], "zapped")
		elseif kind == EV.Stuck then
			cloneFailed(inst, log.a[i], if log.b[i] == CAUSE.Door then "bonk" else "blocked")
		elseif kind == EV.Swarm then
			-- 6+ clones in one run (a = seat): the "8 OF ME" promise seen
			ftue(inst, inst.members[log.a[i]], "SwarmSeen")
			inst.runSwarm = math.max(inst.runSwarm, log.b[i])
			inst.maxOfMe = math.max(inst.maxOfMe, log.b[i])
		elseif kind == EV.AlarmOn then
			local by = log.a[i]
			inst.alarmBy = by
			inst.alarmTick = log.tick[i]
			local a = if by > 0 then sim.actors[by] else nil
			local who = if by == 0 then "catch" elseif a and a.kind == "clone" then "clone" else "live"
			trackAll(inst, "alarmTripped", inst.trackLevel, who)
		elseif kind == EV.HeistComplete then
			trackAll(inst, "heistStep", inst.heistId, "HeistComplete")
			if inst.level.id == H.FTUE_L1_LEVEL and not inst.daily then
				for _, m in inst.members do
					ftue(inst, m, "L1Complete")
				end
			end
		end
	end
end

local function flushEvents(inst: any)
	local sim = inst.sim
	local from, to = HeistSim.eventsSince(sim, inst.evCursor)
	if to < from then
		return
	end
	inst.evCursor = to
	scanLog(inst, from, to)
	sendAll(inst, "Ev", { run = sim.runIndex, from = from, buf = EventLog.encode(sim.log, from, to) })
end

---------------------------------------------------------------------------
-- Characters
---------------------------------------------------------------------------

local function worldCFrame(inst: any, x: number, y: number, z: number, yaw: number): CFrame
	return CFrame.new(inst.origin + Vector3.new(x, y, z)) * CFrame.Angles(0, yaw, 0)
end

local function setFrozen(inst: any, frozen: boolean)
	inst.frozen = frozen
	for _, m in inst.members do
		local root = rootOf(m)
		if root and not m.left then
			root.Anchored = frozen
		end
	end
end

-- Puts a member's character where the sim says they are (respawn, fell off).
function HeistInstance.placeCharacter(inst: any, userId: number)
	local m = inst.byId[userId]
	if not m then
		return
	end
	local root = rootOf(m)
	if not root then
		return
	end
	local a = HeistSim.liveActor(inst.sim, userId)
	if a then
		root.AssemblyLinearVelocity = Vector3.zero
		root:PivotTo(worldCFrame(inst, a.x, a.y, a.z, a.yaw))
		root.Anchored = inst.frozen
	end
	local hum = humanoidOf(m)
	if hum then
		hum.WalkSpeed = Config.Rec.WALK_SPEED
	end
end

-- Funnel FirstMove: a live player this far from their run-1 spawn (server-side, so a
-- teleport cannot fake it: the sim moves only with sampled positions).
local function checkFirstMove(inst: any, m: Member, a: any)
	if m.ftue.FirstMove or inst.sim.runIndex ~= 1 then
		return
	end
	local spawns = inst.level.spawns
	local spawn = spawns[(a.seat - 1) % #spawns + 1]
	local dx, dz = a.x - spawn.x, a.z - spawn.z
	if dx * dx + dz * dz >= H.FIRST_MOVE_STUDS * H.FIRST_MOVE_STUDS then
		ftue(inst, m, "FirstMove")
	end
end

local function sampleInputs(inst: any)
	local sim = inst.sim
	local floorY = inst.level.floorY
	for _, m in inst.members do
		if m.left then
			continue
		end
		local a = HeistSim.liveActor(sim, m.userId)
		if not a or not a.present then
			continue
		end
		checkFirstMove(inst, m, a)
		local fake = m.fake
		if fake then
			HeistSim.setInput(sim, m.userId, fake.x, fake.y, fake.z, fake.yaw, FLAG.GROUNDED)
			continue
		end
		local root = rootOf(m)
		if not root then
			continue -- no character: the actor stands where it was
		end
		local pos = root.Position - inst.origin
		if pos.Y < floorY - H.OFF_MAP_DROP then
			HeistInstance.placeCharacter(inst, m.userId)
			continue
		end
		local look = root.CFrame.LookVector
		local yaw = math.atan2(-look.X, -look.Z) % TAU
		local flags = 0
		local hum = humanoidOf(m)
		if hum then
			if hum.FloorMaterial ~= Enum.Material.Air then
				flags = bit32.bor(flags, FLAG.GROUNDED)
			end
			local state = hum:GetState()
			if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
				flags = bit32.bor(flags, FLAG.JUMPING)
			end
		end
		HeistSim.setInput(sim, m.userId, pos.X, pos.Y, pos.Z, yaw, flags)
		local player = m.player
		if player then
			local ok, ping = pcall(function()
				return player:GetNetworkPing()
			end)
			if ok and type(ping) == "number" then
				HeistSim.setLatency(sim, m.userId, ping / 2)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Run flow
---------------------------------------------------------------------------

local function chooseTransition(inst: any): (number, string)
	local nextRun = inst.sim.runIndex + 1
	local T = H.REWIND_TRANSITION
	if nextRun == 1 then
		return H.FIRST_RUN_INTRO, Protocol.TRANSITION.Intro
	end
	local allReduced, any = true, false
	for _, m in inst.members do
		if not m.left then
			any = true
			allReduced = allReduced and m.reduced
		end
	end
	if any and allReduced then
		return T[3], Protocol.TRANSITION.Reduced
	end
	if inst.level.tutorial ~= nil or nextRun > H.QUICK_REWIND_FROM_RUN then
		return T[2], Protocol.TRANSITION.Quick
	end
	return T[1], Protocol.TRANSITION.Standard
end

-- LiveFlags crewCloneBudget: the per-player cap is locked when run 1 starts (decks are
-- still empty then), so a tuned budget is applied right after it, before any clone.
local function applyCloneBudget(inst: any)
	local budget = inst.tuning.crewCloneBudget
	local sim = inst.sim
	if budget == S.CREW_CLONE_BUDGET or sim.runIndex ~= 1 then
		return
	end
	local cap = math.clamp(math.floor(budget / math.max(sim.crewSize, 1)), 1, inst.level.cap)
	sim.cap = cap
	for _, p in sim.players do
		p.deck.cap = cap
	end
end

local function award(inst: any, m: Member, result: any): any
	local player = m.player
	if not player or m.left or result.reason == "Abandoned" then
		return nil
	end
	local ok, res
	if inst.daily then
		if not inst.awardDaily then
			return nil
		end
		ok, res = pcall(inst.awardDaily, player, inst.daily.day, table.clone(result.daily), inst.daily.startDay)
	else
		if not (inst.award and inst.dataKey) then
			return nil
		end
		local data = table.clone(result.data)
		data.friends = m.friends
		data.heistId = inst.heistId
		if inst.level.kind == "party" then
			-- Party rules cap clones per player: report this member's own swarm.
			data.clones = math.clamp(m.ownMax or 0, 0, inst.level.cap)
		end
		-- Co-op carry (docs/DATA.md): a crewmate on a tape they have not unlocked still
		-- gets the result (the leader's unlock was checked when the heist started).
		ok, res = pcall(inst.award, player, inst.dataKey, data, { crew = #inst.members > 1 })
	end
	if ok and type(res) == "table" then
		return { ok = res.ok, code = res.code, data = res.data }
	end
	return nil
end

local function outcomeOf(result: any): string
	if result.reason == "Abandoned" then
		return "abandoned"
	elseif result.complete then
		return "complete"
	elseif result.reason == "Dawn" then
		return "dawn"
	end
	return "aborted"
end

local function nextIndexOf(inst: any): number
	if inst.daily then
		return 0
	end
	return if Catalog[inst.levelIndex + 1] ~= nil then inst.levelIndex + 1 else 0
end

local function onOver(inst: any, now: number)
	if inst.overAt then
		return -- once per heist, even if a later step of this one errors
	end
	local sim = inst.sim
	inst.overAt = now
	setFrozen(inst, false)
	local result = HeistSim.result(sim)
	local lineup = {}
	local okLineup, entries = pcall(HeistSim.lineup, sim)
	if okLineup then
		for _, e in entries do
			table.insert(lineup, {
				kind = e.kind,
				ownerId = e.ownerId,
				seat = e.seat,
				slot = e.slot,
				run = e.run,
				delay = e.delay,
				x = e.x,
				z = e.z,
				yaw = e.yaw,
			})
		end
	end
	local nextIndex = nextIndexOf(inst)
	local info = levelInfo(inst)
	local slim = {
		reason = result.reason,
		complete = result.complete,
		runs = result.runs,
		banked = result.banked,
		goal = result.goal,
		haul = result.haul,
		tiers = result.tiers,
		tierMet = result.tierMet,
		clonesUsed = result.clonesUsed,
		par = result.par,
		totalTime = result.totalTime,
		finalRunTime = result.finalRunTime,
		stars = result.stars,
		tainted = result.tainted,
		kind = info.kind,
		levelId = info.id,
		name = info.name,
		levelIndex = inst.levelIndex,
		hasNext = nextIndex > 0,
		nextIndex = nextIndex,
		leader = inst.leader,
		ofMe = inst.maxOfMe,
		lineup = lineup,
		daily = inst.daily,
		tuning = inst.tuning,
	}
	inst.overMsg = slim
	local outcome = outcomeOf(result)
	for _, m in inst.members do
		local res = award(inst, m, result)
		if m.player and not m.left then
			if inst.level.kind == "party" and result.complete then
				-- party levels never log HeistComplete: Haul1 by Dawn is their clear
				trackMember(inst, m, "heistStep", inst.heistId, "HeistComplete")
			end
			trackMember(inst, m, "heistEnded", inst.heistId, outcome, result.runs)
			local data = res and res.ok and res.data
			if type(data) == "table" and type(data.newMedals) == "table" then
				for _, medal in data.newMedals do
					trackMember(inst, m, "medal", medal, inst.trackLevel)
				end
			end
			if inst.daily and result.reason ~= "Abandoned" then
				local how = if inst.daily.mode == "catchUp"
					then "catchup"
					elseif result.daily.cleared then "cleared"
					else "failed"
				trackMember(inst, m, "dailyVault", inst.daily.slot, how)
			end
		end
		local nextFor = nil
		if nextIndex > 0 and m.player and not m.left and inst.nextInfo then
			local okNext, unlockInfo = pcall(inst.nextInfo, m.player, nextIndex)
			nextFor = if okNext then unlockInfo else nil
		end
		send(inst, m, "Over", { result = slim, award = res, daily = inst.daily, next = nextFor })
		trackMember(inst, m, "heistStep", inst.heistId, "ResultsShown")
	end
end

local function alarmInfo(last: any): any
	local alarm = last and last.alarm
	if not alarm then
		return nil
	end
	return {
		t = alarm.t,
		kind = alarm.kind,
		ownerId = alarm.ownerId,
		slot = alarm.slot,
		hint = alarm.hint,
	}
end

local function onRunEnded(inst: any, now: number)
	local sim = inst.sim
	setFrozen(inst, false)
	local last = sim.lastRun
	local alarm = alarmInfo(last)
	local escaped = alarm ~= nil and inst.bankAfterAlarm and last ~= nil and last.reason ~= RUN_END.VanLeft
	inst.alarmHint = if alarm and alarm.hint then alarm else nil
	sendAll(inst, "RunEnd", {
		run = sim.runIndex,
		summary = if last
			then {
				reason = last.reason,
				t = last.t,
				banked = last.banked,
				catches = last.catches,
				busted = last.busted,
				zapped = last.zapped,
				stuck = last.stuck,
				clones = last.clones,
				alarm = alarm,
				tierMet = sim.tierMet,
				swarm = inst.runSwarm,
				escaped = escaped,
			}
			else nil,
	})
	-- Analytics: tainted live recordings (Validator flags, §8.8) and an Alarm Run won.
	for _, a in sim.actors do
		if a.kind == "live" and a.rec and Validator.isTainted(a.rec) then
			trackMember(inst, inst.byId[a.ownerId], "taintedRun", a.rec.vflags, inst.trackLevel)
		end
	end
	if escaped then
		trackAll(inst, "alarmEscaped", inst.trackLevel, sim.crewSize)
	end
	if sim.phase == "Over" then
		onOver(inst, now)
		return
	end
	for _, m in inst.members do
		m.ready = false
		sendDeck(inst, m)
	end
	local auto = if inst.level.tutorial ~= nil
		then H.TUTORIAL_BETWEEN_SECONDS
		elseif inst.level.kind == "party" then H.PARTY_BETWEEN_SECONDS
		else H.BETWEEN_MAX_SECONDS
	inst.autoReadyAt = now + auto
	setAttr(inst, "AutoStartAt", inst.autoReadyAt) -- the RUN button's countdown (server time)
end

local function startRun(inst: any, now: number)
	local sim = inst.sim
	local transition, kind = chooseTransition(inst)
	local runIndex = HeistSim.startRun(sim, now + transition)
	if not runIndex then
		if sim.phase == "Over" then
			onOver(inst, now)
		end
		return
	end
	applyCloneBudget(inst)
	inst.startAt = now + transition
	inst.evCursor = 0
	inst.autoReadyAt = math.huge
	inst.clockRef = sim.clock
	inst.alarmBy, inst.alarmTick, inst.bankAfterAlarm, inst.runSwarm = -1, -1, false, 0
	inst.alarmHint = nil
	for _, m in inst.members do
		m.ready = false
		local a = HeistSim.liveActor(sim, m.userId)
		local root = rootOf(m)
		local fake = m.fake
		if a and fake then
			fake.x, fake.y, fake.z, fake.yaw = a.x, a.y, a.z, a.yaw
		end
		if a and root then
			root.AssemblyLinearVelocity = Vector3.zero
			root:PivotTo(worldCFrame(inst, a.x, a.y, a.z, a.yaw))
		end
		local hum = humanoidOf(m)
		if hum then
			hum.WalkSpeed = Config.Rec.WALK_SPEED
		end
	end
	setFrozen(inst, true)
	local msg = runMessage(inst, transition, kind)
	inst.runMsg = msg
	for _, m in inst.members do
		ensureRecs(inst, m, msg.keys)
	end
	sendAll(inst, "Run", msg)
	flushEvents(inst)
end

-- One server frame for this instance.
function HeistInstance.update(inst: any, now: number)
	if inst.dead then
		return
	end
	local sim = inst.sim
	if sim.phase == "Lobby" then
		startRun(inst, now)
	elseif sim.phase == "Between" then
		local all = true
		for _, m in inst.members do
			if not m.left and not m.ready then
				all = false
			end
		end
		if all or now >= inst.autoReadyAt then
			startRun(inst, now)
		end
	end
	if sim.phase == "Run" then
		if inst.frozen and now >= inst.startAt then
			setFrozen(inst, false)
		end
		if not inst.frozen then
			sampleInputs(inst)
		end
		debug.profilebegin("EH.Sim")
		HeistSim.update(sim, now)
		debug.profileend()
		flushEvents(inst)
		if sim.phase == "Run" and sim.clock ~= inst.clockRef then
			inst.clockRef = sim.clock
			sendAll(inst, "Clock", { run = sim.runIndex, clock = Protocol.clockData(sim.clock) })
		end
	end
	syncAttributes(inst, now)
	local seen = inst.phaseSeen
	-- Recorded before the hooks run, so an error inside them cannot replay them next frame.
	inst.phaseSeen = sim.phase
	if seen == "Run" and sim.phase ~= "Run" then
		onRunEnded(inst, now)
	end
end

---------------------------------------------------------------------------
-- Intents (already rate limited and type checked by Net; the sim re-validates)
---------------------------------------------------------------------------

function HeistInstance.endRun(inst: any, userId: number): boolean
	return HeistSim.endRun(inst.sim, userId)
end

function HeistInstance.interact(inst: any, userId: number, kind: number, arg: number): boolean
	return HeistSim.request(inst.sim, userId, kind, arg)
end

local function opName(op: string): string
	return string.lower(string.sub(op, 1, 1)) .. string.sub(op, 2)
end

function HeistInstance.deckAction(inst: any, userId: number, op: string, n: number?): boolean
	local m = inst.byId[userId]
	if not m or m.left or deckLocked(inst.level) then
		return false
	end
	local ok = HeistSim.deckAction(inst.sim, userId, op, n)
	if ok then
		local hint = inst.alarmHint
		if hint and hint.ownerId == userId then
			inst.alarmHint = nil -- the deck changed under the hint (slots may have moved)
		end
		trackMember(inst, m, "deck", opName(op), inst.trackLevel)
	end
	sendDeck(inst, m)
	return ok
end

function HeistInstance.ready(inst: any, userId: number, reduced: boolean?)
	local m = inst.byId[userId]
	if m and not m.left and inst.sim.phase == "Between" then
		m.ready = true
		m.reduced = reduced == true
	end
end

function HeistInstance.fastForward(inst: any, userId: number, on: boolean, now: number): boolean
	local sim = inst.sim
	local m = inst.byId[userId]
	if not m or m.left or sim.phase ~= "Run" or now < inst.startAt then
		return false
	end
	return HeistSim.setRate(sim, now, if on then Config.Rec.SKIP_SPEED else 1)
end

-- A member left the heist (or the game): their run ends, their clones stay as orphans.
function HeistInstance.removeMember(inst: any, userId: number)
	local m = inst.byId[userId]
	if not m or m.left then
		return
	end
	if inst.overAt == nil then
		trackMember(inst, m, "heistEnded", inst.heistId, "left", inst.sim.runIndex)
	end
	local root = rootOf(m)
	if root then
		root.Anchored = false
	end
	m.left = true
	persistFor(inst, m.player, false)
	HeistSim.removePlayer(inst.sim, userId)
	local anyone = false
	for _, other in inst.members do
		anyone = anyone or not other.left
	end
	if not anyone then
		inst.dead = true
	end
end

-- Engine smoke test: drive a fake member's position (level space).
function HeistInstance.setFakeInput(inst: any, userId: number, x: number, y: number, z: number, yaw: number?)
	local m = inst.byId[userId]
	if m and m.fake then
		local f = m.fake :: any
		f.x, f.y, f.z = x, y, z
		f.yaw = yaw or f.yaw
	end
end

-- What onOver hands DataService for one member (tests and debugging): "daily" with
-- the day and DailyVault.DailyResult, or "heist" with the data key and HeistResult.
function HeistInstance.awardPayload(inst: any, userId: number): any
	local m = inst.byId[userId]
	if not m or inst.sim.phase ~= "Over" then
		return nil
	end
	local result = HeistSim.result(inst.sim)
	if inst.daily then
		return { kind = "daily", day = inst.daily.day, result = table.clone(result.daily) }
	end
	local data = table.clone(result.data)
	data.friends = m.friends
	data.heistId = inst.heistId
	if inst.level.kind == "party" then
		data.clones = math.clamp(m.ownMax or 0, 0, inst.level.cap)
	end
	return { kind = "heist", dataKey = inst.dataKey, result = data }
end

-- Full state for one client (boot, late join, after a resync).
function HeistInstance.syncFor(inst: any, userId: number): any
	local m = inst.byId[userId]
	local crew = {}
	for seat, other in inst.members do
		table.insert(crew, { userId = other.userId, name = other.name, seat = seat, left = other.left })
	end
	local recs = {}
	local keys: { number } = {}
	if inst.runMsg then
		for _, k in inst.runMsg.keys do
			table.insert(keys, k)
		end
	end
	local deck = m and deckFor(inst, m)
	if deck then
		for _, s in deck.slots do
			table.insert(keys, s.key)
		end
	end
	-- An array (remote tables must not have sparse numeric keys).
	local sent = inst.sent[userId]
	local seen: { [number]: boolean } = {}
	for _, k in keys do
		if inst.recBufs[k] and not seen[k] then
			seen[k] = true
			table.insert(recs, { key = k, owner = inst.recOwner[k], buf = inst.recBufs[k] })
			if sent then
				sent[k] = true
			end
		end
	end
	local sim = inst.sim
	return {
		where = "heist",
		instance = inst.name,
		levelIndex = inst.levelIndex,
		level = levelInfo(inst),
		daily = inst.daily,
		tuning = inst.tuning,
		kit = inst.built.kit == true,
		dressing = inst.built.dressing == true,
		origin = inst.origin,
		heistId = inst.heistId,
		leader = inst.leader,
		crew = crew,
		phase = sim.phase,
		run = inst.runMsg,
		recs = recs,
		deck = deck,
		over = inst.overMsg,
		firstHeist = sim.firstHeist,
		evFrom = 1,
		ev = if sim.log.n > 0 then EventLog.encode(sim.log, 1, sim.log.n) else nil,
	}
end

function HeistInstance.destroy(inst: any)
	inst.dead = true
	setFrozen(inst, false)
	inst.folder:Destroy()
end

return HeistInstance
