--!strict
-- Heist/HeistInstance: one heist for one party (a solo player, or friends who joined
-- each other). MASTERPLAN §3.3 (instances in a shared server), §8.2 (server sim +
-- client view), §8.6 (budgets), §8.10 (lag fairness), §7.5 (L1 FTUE).
--
-- It owns a Sim/HeistSim, a greybox copy of the level at its own origin, its crew,
-- and the routing of their intents. The server is authoritative for every outcome:
-- the sim decides plates, doors, lasers, Gus, loot and banking from actor positions;
-- characters only feed positions in (setInput) and intents go through HeistSim.
--
-- Everything is driven by HeistInstance.update(inst, serverNow) from the service's
-- Heartbeat (or by the engine smoke test with synthetic times): input sampling, the
-- 20 Hz sim (fixed-step accumulator on the run's LoopClock), streaming and timers.
-- No task.wait / task.delay in here, so a test can run a whole heist in one frame.
--
-- Replication per instance (§8.2, Heist/Protocol): attributes on the instance folder
-- for state (doors solidAt, lasers onAt, plates, loot, Gus mode/offset/meter), one
-- reliable push for moments (Run, Ev event-log slices, Clock, RunEnd, Deck, Over)
-- and each new recording once per client as a Codec buffer (Rec).

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
local Catalog = require(Shared:WaitForChild("Levels"):WaitForChild("Catalog"))
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))

local LevelBuilder = require(script.Parent:WaitForChild("LevelBuilder"))

local EV = EventLog.EV
local FLAG = Codec.FLAG
local TAU = 2 * math.pi
local H = Config.Heist

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
}

export type Opts = {
	id: number,
	levelIndex: number,
	origin: Vector3,
	parent: Instance,
	members: { Member },
	leader: number,
	heistId: string,
	firstHeist: boolean?,
	push: ((player: Player, kind: string, payload: any) -> ())?,
	award: ((player: Player, dataKey: string, data: any) -> any)?,
	onFtue: ((player: Player, step: string) -> ())?,
}

local levelCache: { [number]: any } = {}

-- Compiled LevelData for a Catalog index (compiled once per server).
function HeistInstance.levelData(index: number): any
	local cached = levelCache[index]
	if cached then
		return cached
	end
	local spec = Catalog[index]
	assert(spec, "HeistInstance: no level " .. tostring(index))
	local level = LevelSpec.compile(spec)
	levelCache[index] = level
	return level
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

function HeistInstance.new(o: Opts): any
	local level = HeistInstance.levelData(o.levelIndex)
	local folder = Instance.new("Folder")
	folder.Name = Protocol.instanceName(o.id)
	local built = LevelBuilder.build(level, o.origin, folder)
	local ids = {}
	for _, m in o.members do
		table.insert(ids, m.userId)
	end
	local sim = HeistSim.new(level, {
		players = ids,
		firstHeist = o.firstHeist == true,
		walkSpeed = Config.Rec.WALK_SPEED,
	})
	local inst = {
		id = o.id,
		name = folder.Name,
		folder = folder,
		built = built,
		level = level,
		levelIndex = o.levelIndex,
		dataKey = H.LEVEL_DATA_KEYS[level.id],
		origin = o.origin,
		heistId = o.heistId,
		leader = o.leader,
		sim = sim,
		members = o.members,
		byId = {} :: { [number]: Member },
		push = o.push,
		award = o.award,
		onFtue = o.onFtue,
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
		lastPoseAt = -math.huge,
		runMsg = nil :: any,
		overMsg = nil :: any,
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
	end
	folder:SetAttribute("LevelIndex", o.levelIndex)
	folder:SetAttribute("LevelId", level.id)
	folder:SetAttribute("Origin", o.origin)
	folder:SetAttribute("HeistId", o.heistId)
	folder:SetAttribute("Leader", o.leader)
	folder:SetAttribute("Goal", level.goal)
	folder.Parent = o.parent
	return inst
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
	return {
		cap = deck.cap,
		slots = slots,
		redo = deck.redo or 0,
		canUndo = deck.undo ~= nil,
		locked = inst.level.tutorial ~= nil, -- the deck is taught from L2 (§3.4)
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
	for _, a in sim.actors do
		local key, run = 0, sim.runIndex
		if a.kind == "clone" then
			key = keyOf(inst, a.rec, a.ownerId)
			table.insert(keys, key)
			local slot = a.player.deck.slots[a.slot]
			run = if slot then slot.run else 0
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
		})
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

local function syncAttributes(inst: any, now: number)
	local sim = inst.sim
	local mech = sim.mech
	setAttr(inst, "Phase", sim.phase)
	setAttr(inst, "RunIndex", sim.runIndex)
	setAttr(inst, "Banked", sim.banked)
	setAttr(inst, "CanFF", sim.phase == "Run" and now >= inst.startAt and HeistSim.canFastForward(sim))
	for i, d in mech.doors do
		setAttr(inst, "D" .. i .. "Open", d.open)
		setAttr(inst, "D" .. i .. "Solid", d.solid)
		setAttr(inst, "D" .. i .. "SolidAt", if d.solidAt then round(d.solidAt, 0.001) else -1)
	end
	for i, l in mech.lasers do
		setAttr(inst, "L" .. i .. "On", l.on)
		setAttr(inst, "L" .. i .. "OnAt", if l.onAt then round(l.onAt, 0.001) else -1)
	end
	for i, p in mech.plates do
		setAttr(inst, "P" .. i .. "Held", Mechanisms.plateHeld(mech, i, sim.t))
		setAttr(inst, "P" .. i .. "By", p.firstActor)
	end
	for i, item in sim.loot.items do
		setAttr(inst, "K" .. i .. "State", item.state)
		setAttr(inst, "K" .. i .. "Carrier", item.carrier)
		if item.state ~= "Carried" then
			setAttr(inst, "K" .. i .. "Pos", Vector3.new(round(item.x, 0.01), round(item.y, 0.01), round(item.z, 0.01)))
		end
	end
	local poseDue = now - inst.lastPoseAt >= 1 / H.GUARD_POSE_HZ
	if poseDue then
		inst.lastPoseAt = now
	end
	for i, g in sim.guards do
		local p = "G" .. i
		setAttr(inst, p .. "Offset", round(g.offset, 0.001))
		setAttr(inst, p .. "Mode", g.mode)
		setAttr(inst, p .. "Focus", g.focus)
		if g.mode ~= "Patrol" and poseDue then
			setAttr(inst, p .. "X", round(g.x, 0.01))
			setAttr(inst, p .. "Z", round(g.z, 0.01))
			setAttr(inst, p .. "Yaw", round(g.yaw, 0.01))
		end
		local meter, stage = 0, 0
		for _, a in sim.actors do
			meter = math.max(meter, g.meter[a.id] or 0)
			stage = math.max(stage, g.stage[a.id] or 0)
		end
		setAttr(inst, p .. "Meter", round(meter, H.METER_STEP))
		setAttr(inst, p .. "Stage", stage)
	end
	setAttr(inst, "AlarmOn", sim.alarm.active)
	setAttr(inst, "AlarmVanAt", round(sim.alarm.vanAt, 0.01))
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
-- FTUE hooks (§7.5 funnel steps the server can see; analytics subscribes)
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

local function scanFtue(inst: any, from: number, to: number)
	local log = inst.sim.log
	for i = from, to do
		local kind = log.kind[i]
		if kind == EV.PlateDown then
			local m, a = memberOfActor(inst, log.b[i])
			if a and a.kind == "live" then
				ftue(inst, m, "FirstPlate")
			end
		elseif kind == EV.RunStart and log.a[i] >= 2 then
			for _, m in inst.members do
				ftue(inst, m, "FirstRewind")
				if log.b[i] > 0 then
					ftue(inst, m, "FirstCloneSeen")
				end
			end
		elseif kind == EV.Bank then
			local m = memberOfActor(inst, log.a[i])
			ftue(inst, m, "FirstBank")
		elseif kind == EV.Busted then
			local m = memberOfActor(inst, log.b[i])
			ftue(inst, m, "FirstCloneBusted")
		elseif (EV :: any).Swarm ~= nil and kind == (EV :: any).Swarm then
			-- 6+ of your own clones in one run (a = seat): the "8 OF ME" promise seen
			ftue(inst, inst.members[log.a[i]], "SwarmSeen")
		elseif kind == EV.HeistComplete and inst.levelIndex == 1 then
			for _, m in inst.members do
				ftue(inst, m, "L1Complete")
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
	scanFtue(inst, from, to)
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

local function onOver(inst: any, now: number)
	local sim = inst.sim
	inst.overAt = now
	setFrozen(inst, false)
	local result = HeistSim.result(sim)
	local slim = {
		reason = result.reason,
		complete = result.complete,
		runs = result.runs,
		banked = result.banked,
		goal = result.goal,
		clonesUsed = result.clonesUsed,
		par = result.par,
		totalTime = result.totalTime,
		finalRunTime = result.finalRunTime,
		stars = result.stars,
		tainted = result.tainted,
		levelIndex = inst.levelIndex,
		hasNext = Catalog[inst.levelIndex + 1] ~= nil,
		leader = inst.leader,
	}
	inst.overMsg = slim
	for _, m in inst.members do
		local player = m.player
		local award = nil
		if player and not m.left and inst.award and inst.dataKey and result.reason ~= "Abandoned" then
			local data = table.clone(result.data)
			data.friends = m.friends
			data.heistId = inst.heistId
			local ok, res = pcall(inst.award, player, inst.dataKey, data)
			if ok and type(res) == "table" then
				award = { ok = res.ok, code = res.code, data = res.data }
			end
		end
		send(inst, m, "Over", { result = slim, award = award })
	end
end

local function onRunEnded(inst: any, now: number)
	local sim = inst.sim
	setFrozen(inst, false)
	local last = sim.lastRun
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
			}
			else nil,
	})
	if sim.phase == "Over" then
		onOver(inst, now)
		return
	end
	for _, m in inst.members do
		m.ready = false
		sendDeck(inst, m)
	end
	local auto = if inst.level.tutorial ~= nil then H.TUTORIAL_BETWEEN_SECONDS else H.BETWEEN_MAX_SECONDS
	inst.autoReadyAt = now + auto
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
	inst.startAt = now + transition
	inst.evCursor = 0
	inst.autoReadyAt = math.huge
	inst.clockRef = sim.clock
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
		HeistSim.update(sim, now)
		flushEvents(inst)
		if sim.phase == "Run" and sim.clock ~= inst.clockRef then
			inst.clockRef = sim.clock
			sendAll(inst, "Clock", { run = sim.runIndex, clock = Protocol.clockData(sim.clock) })
		end
	end
	syncAttributes(inst, now)
	if inst.phaseSeen == "Run" and sim.phase ~= "Run" then
		onRunEnded(inst, now)
	end
	inst.phaseSeen = sim.phase
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

function HeistInstance.deckAction(inst: any, userId: number, op: string, n: number?): boolean
	local m = inst.byId[userId]
	if not m or m.left or inst.level.tutorial ~= nil then
		return false
	end
	local ok = HeistSim.deckAction(inst.sim, userId, op, n)
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
	local root = rootOf(m)
	if root then
		root.Anchored = false
	end
	m.left = true
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
