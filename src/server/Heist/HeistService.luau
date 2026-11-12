--!strict
-- Heist/HeistService: the sim game path's server (Config.GAME_MODE = "sim").
-- MASTERPLAN §3.3 (garage lobby + one heist instance per party in a shared server),
-- §7.5 (a new account starts L1 at once), §5.3 (daily vault), §8.2, §8.6, §8.7, §8.8.
--
--   * Crews: every player starts as a solo crew. Players who arrive in the same Roblox
--     party (Player.PartyId) share a crew; "Join friend" (Heist.JoinFriend) moves you
--     into a friend's crew in this server. Joiners seat at the next heist.
--   * The crew leader picks a level (Heist.SelectLevel: a Levels/Catalog index, in play
--     order: L1, L2, the Clone Party break, L3, L4, L6) or today's daily vault
--     (Heist.SelectDaily; a missed advent day can be caught up). The crew gets its own
--     HeistInstance built 3,000 studs from the others, up to MAX_INSTANCES (LiveFlag
--     maxInstances can lower it).
--   * Remotes are LihFolk Net (rate limit + per-argument validation); handlers route
--     to the player's instance, and the sim re-validates every intent (§8.5).
--   * Results: story and party levels go to DataService.awardHeistResult (friends and
--     heistId added; party levels with each member's own swarm), daily vaults to
--     DataService.awardDailyVault (the sim's result().daily, timeMs included).
--   * FTUE: HeistService.FtueStep fires (player, step) for the §7.5 funnel steps the
--     server sees; Analytics binds it. The step index is saved with setFtueStep.
--   * LiveFlags (§8.7, read here, never mid-run): kill switches joinFriend, dailyVault,
--     store (no Robux prompt while it is off), alarmRun, dressing; tuning alarmVanSeconds,
--     alarmLockSeconds, alarmChaseSpeedMult, crewCloneBudget and maxInstances, read at
--     heist start and stored with the heist (HeistInstance tuning).
--   * Art kit: HeistService.configureKit(KitService) lets LevelBuilder dress levels with
--     the kit once it is loaded (greybox until then, Config.Heist.KIT_LEVELS switch); the
--     Christmas layer follows Config.Data.Event on the server date (XMAS_DRESSING).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Levels = Shared:WaitForChild("Levels")
local Catalog = require(Levels:WaitForChild("Catalog"))
local DailyVaults = require(Levels:WaitForChild("DailyVaults"))
local DataShared = Shared:WaitForChild("Data")
local Calendar = require(DataShared:WaitForChild("Calendar"))
local DailyVault = require(DataShared:WaitForChild("DailyVault"))
local Codec = require(Shared:WaitForChild("Rec"):WaitForChild("Codec"))
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local Help = require(Shared:WaitForChild("Heist"):WaitForChild("Help"))
local Strings = require(Shared:WaitForChild("Heist"):WaitForChild("Strings"))
local HeistSim = require(Shared:WaitForChild("Sim"):WaitForChild("HeistSim"))
local Scenario = require(Shared:WaitForChild("Heist"):WaitForChild("Scenario"))
local LihFolk = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(LihFolk:WaitForChild("Net"))
local Signal = require(LihFolk:WaitForChild("Signal"))

local HeistInstance = require(script.Parent:WaitForChild("HeistInstance"))
local Avatars = require(script.Parent:WaitForChild("Avatars"))
local Lobby = require(script.Parent:WaitForChild("Lobby"))
local Staging = require(script.Parent:WaitForChild("Staging"))
local LiveFlags = require(script.Parent.Parent:WaitForChild("Analytics"):WaitForChild("LiveFlags"))

local T = Net.T
local H = Config.Heist
local KIND = Codec.EVENT

local HeistService = {}

-- (player, step): a §7.5 funnel step the server saw (Joined, FirstPlate, ...).
HeistService.FtueStep = Signal.new()

-- Funnel order (§7.5 onb_v2) for DataService.setFtueStep; client-only steps are listed
-- so the indices stay stable when the client reports them later.
-- (Heist/Protocol.FTUE_STEPS: the client's Heist/FirstTime reads the saved index too.)
HeistService.FTUE_STEPS = Protocol.FTUE_STEPS

type Crew = {
	id: number,
	leader: Player,
	members: { Player },
	pending: { Player }, -- joined while the crew was mid-heist: seat at the next heist
	instance: any?,
	friends: { [Player]: { [number]: boolean } },
}

export type CreateOpts = {
	daily: HeistInstance.Daily?, -- a daily vault (levelIndex = Protocol.DAILY_INDEX)
	tuning: HeistInstance.Tuning?, -- default: read from LiveFlags now
	relaxed: boolean?, -- the Relaxed version of a story level (Levels/Relaxed)
}

local started = false
local staging: string? = nil -- golden-frame scenario (Studio only, Heist/Staging); nil on live servers
local DataService: any = nil
local Analytics: any = nil
local KitService: any = nil
local msgPush: Net.Push? = nil
local crewOf: { [Player]: Crew } = {}
local crews: { Crew } = {}
local nextCrewId = 0
local instances: { [number]: any } = {} -- slot -> instance
local crewOfInstance: { [any]: Crew } = {}
local nextInstanceId = 0
local lastError = -math.huge
local inHeist: { [Player]: boolean } = {}
-- Players whose first Sync is still being decided (data, kit, FTUE autostart): their
-- client shows a "preparing" card, never the garage, until the server decides.
local preparing: { [Player]: boolean } = {}
-- os.clock() of the last heist a player's pick created (INSTANCE_COOLDOWN_SECONDS).
local lastStartBy: { [Player]: number } = {}
local tryFtueStart: (player: Player) -> boolean
local retryFtue: (player: Player) -> ()

---------------------------------------------------------------------------
-- Data, analytics and kit hooks
---------------------------------------------------------------------------

local function simLevelFor(dataKey: string): any
	for i, spec in Catalog do
		if H.LEVEL_DATA_KEYS[spec.id] == dataKey then
			return HeistInstance.levelData(i)
		end
	end
	return nil
end

-- Medal rules from the level layouts (DataService.setLevelResolver): the sim's goal,
-- par and a crew-wide clone cap replace the Config.Data placeholders.
function HeistService.levelRules(dataKey: string): any
	local base = Config.Data.Levels[dataKey]
	if not base then
		return nil
	end
	local level = simLevelFor(dataKey)
	if not level or base.kind ~= "story" then
		return base
	end
	local rules = table.clone(base)
	rules.haulTarget = math.min(level.goal, base.maxHaul)
	rules.parClones = level.par
	rules.cap =
		math.clamp(math.max(base.cap, Config.Sim.CREW_CLONE_BUDGET, LiveFlags.get("crewCloneBudget") or 0), 1, 16)
	return rules
end

-- Call before DataService.start() (init.server.luau does, on the sim path).
function HeistService.configureData(service: any)
	DataService = service
	if service.status() == "stopped" then
		service.setLevelResolver(HeistService.levelRules, Config.Data.LEVEL_ORDER)
	end
end

-- The server Analytics module (docs/ANALYTICS.md "Call sites"); nil = no analytics.
function HeistService.configureAnalytics(analytics: any)
	Analytics = analytics
end

-- src/server/Kit/KitService: levels are dressed with the art kit once it is loaded.
function HeistService.configureKit(kit: any)
	KitService = kit
end

local function track(fn: string, ...: any)
	local f = Analytics and Analytics[fn]
	if type(f) == "function" then
		pcall(f, ...)
	end
end

local function dataReady(player: Player): boolean
	return DataService ~= nil and DataService.status() == "online" and DataService.isReady(player)
end

local function isUnlocked(player: Player, index: number): boolean
	local spec = Catalog[index]
	if not spec then
		return false
	end
	if DataService == nil or DataService.status() == "offline" then
		return true
	end
	if not dataReady(player) then
		return index == 1
	end
	local key = H.LEVEL_DATA_KEYS[spec.id]
	return key ~= nil and DataService.isLevelUnlocked(player, key)
end

local function snapshotOf(player: Player): any
	if not dataReady(player) then
		return nil
	end
	local ok, snap = pcall(DataService.getSnapshot, player)
	return if ok then snap else nil
end

local function ftueHook(player: Player, step: string)
	HeistService.FtueStep:Fire(player, step)
	local index = table.find(HeistService.FTUE_STEPS, step)
	if index and dataReady(player) then
		pcall(DataService.setFtueStep, player, index)
	end
end

local function award(player: Player, dataKey: string, data: any, opts: any?): any
	if DataService == nil then
		return nil
	end
	return DataService.awardHeistResult(player, dataKey, data, opts)
end

local function awardDaily(player: Player, day: number, result: any, startedDay: number?): any
	if DataService == nil then
		return nil
	end
	return DataService.awardDailyVault(player, day, result, startedDay)
end

-- No Robux prompt during a heist or a bust (§5.4), nor while the LiveFlag `store` is off.
local function applyPrompts(player: Player)
	if DataService ~= nil then
		pcall(DataService.setPromptsBlocked, player, inHeist[player] == true or not LiveFlags.isOn("store"))
	end
end

local function blockPrompts(player: Player, blocked: boolean)
	inHeist[player] = if blocked then true else nil
	applyPrompts(player)
end

local function todayDay(): number
	return Calendar.dayIndex(os.time(), Config.Data.Daily.RESET_OFFSET_HOURS)
end

-- The Christmas dressing layer: the event window on the server date and the LiveFlag.
local function dressingOn(): boolean
	local mode = H.XMAS_DRESSING
	if mode == "on" then
		return true
	elseif mode == "off" then
		return false
	end
	return DailyVault.inEvent(todayDay()) and LiveFlags.isOn("dressing")
end

local function buildOpts(): any
	return {
		kit = if H.KIT_LEVELS then KitService else nil,
		dressing = dressingOn(),
	}
end

-- LiveFlags tuning, read once at heist start (never mid-run) and kept with the heist.
function HeistService.tuning(): HeistInstance.Tuning
	local function num(name: string): number?
		local ok, v = pcall(LiveFlags.get, name)
		return if ok and type(v) == "number" and v == v then v else nil
	end
	local okRun, alarmRun = pcall(LiveFlags.isOn, "alarmRun")
	return {
		alarmRun = not okRun or alarmRun == true,
		alarmVanSeconds = num("alarmVanSeconds"),
		alarmLockSeconds = num("alarmLockSeconds"),
		alarmChaseSpeedMult = num("alarmChaseSpeedMult"),
		crewCloneBudget = num("crewCloneBudget"),
	}
end

-- The daily vault of `day` as it may be played today (nil when it cannot be).
function HeistService.dailyFor(day: number, today: number?): HeistInstance.Daily?
	local now = today or todayDay()
	local mode = DailyVault.playMode(day, now)
	if not mode then
		return nil
	end
	local _, slot, modifier = DailyVaults.forDay(day)
	return {
		day = day,
		slot = slot,
		modifier = modifier,
		mode = mode,
		advent = DailyVault.adventDay(day),
		startDay = now, -- DataService.awardDailyVault judges a reset-crossing heist on this day
	}
end

-- The FTUE level (Config.Heist.FTUE_L1_LEVEL) as a Catalog index and data key.
local function ftueIndex(): number
	return Protocol.catalogIndex(H.FTUE_L1_LEVEL) or 1
end

local function ftueDataKey(): string?
	return H.LEVEL_DATA_KEYS[H.FTUE_L1_LEVEL]
end

-- Why a locked level is locked, for the garage tape and the toast (§5.2-5.3):
-- needsClear = the data key of the level to clear first (nil when it is cleared),
-- starsNeeded = more Stars the player still needs (0 when enough).
local function lockInfo(snap: any, dataKey: string?): (string?, number)
	local rules = dataKey and Config.Data.Levels[dataKey]
	if not rules then
		return nil, 0
	end
	local heist = snap and snap.heist
	local levels = heist and heist.levels or {}
	local after = rules.unlockAfter
	local rec = after and levels[after]
	local cleared = after == nil or (rec ~= nil and (rec.clears or 0) > 0)
	local stars = tonumber(snap and snap.stars) or 0
	return if cleared then nil else after, math.max(0, (rules.starsRequired or 0) - stars)
end

-- The results card's NEXT for one member (read after their award, so a clear that just
-- opened the next tape counts): { unlocked, starsNeeded, needsClear }.
local function nextInfo(player: Player, nextIndex: number): any
	if nextIndex <= 0 or Catalog[nextIndex] == nil then
		return nil
	end
	local unlocked = isUnlocked(player, nextIndex)
	local needsClear, starsNeeded = nil, 0
	if not unlocked then
		needsClear, starsNeeded = lockInfo(snapshotOf(player), H.LEVEL_DATA_KEYS[Catalog[nextIndex].id])
	end
	return { unlocked = unlocked, needsClear = needsClear, starsNeeded = starsNeeded }
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function push(player: Player, kind: string, payload: any)
	if msgPush then
		msgPush:Fire(player, kind, payload)
	end
end

local function levelList(player: Player): { any }
	local snap = snapshotOf(player)
	local out = {}
	for i, spec in Catalog do
		local key = H.LEVEL_DATA_KEYS[spec.id]
		local rec = snap and key and snap.heist and snap.heist.levels and snap.heist.levels[key]
		local unlocked = isUnlocked(player, i)
		local needsClear, starsNeeded = nil, 0
		if not unlocked then
			needsClear, starsNeeded = lockInfo(snap, key)
		end
		local medals = {}
		if rec and type(rec.medals) == "table" then
			for name, on in rec.medals do
				if on == true then
					table.insert(medals, name)
				end
			end
			table.sort(medals)
		end
		table.insert(out, {
			index = i,
			id = spec.id,
			num = spec.num,
			dataKey = key,
			kind = if spec.kind == "party" then Protocol.KIND.Party else Protocol.KIND.Story,
			name = spec.name,
			par = spec.par,
			cap = spec.cap,
			runSeconds = spec.runSeconds,
			unlocked = unlocked,
			needsClear = needsClear, -- data key of the level to clear first (locked only)
			starsNeeded = starsNeeded, -- more Stars needed (locked only)
			medals = medals,
		})
	end
	return out
end

-- A player who has not cleared the FTUE level yet (offline / not loaded counts as new).
local function isNewAccount(player: Player): boolean
	local snap = snapshotOf(player)
	if not snap then
		return true -- offline / not loaded: treat as new so the FTUE path is the default
	end
	local key = ftueDataKey()
	local rec = key and snap.heist and snap.heist.levels and snap.heist.levels[key]
	return not (rec and (rec.clears or 0) > 0)
end

-- The daily vault is offered once Night Clerk is cleared (PLAN D4, WALKTHROUGH P1-7: it can hold
-- Gus, lasers and need-all plates; Config.Onboarding.DAILY_UNLOCK_LEVEL, Help.dailyOpen). Studio
-- without data (offline) keeps it open so play tests are never blocked.
local function dailyOpenFor(player: Player): boolean
	if DataService == nil or DataService.status() == "offline" then
		return true
	end
	if not dataReady(player) then
		return false
	end
	local snap = snapshotOf(player)
	local open = Help.dailyOpen(snap and snap.heist and snap.heist.levels)
	return open
end

local function dailyState(player: Player): any
	local today = todayDay()
	local spec, slot, modifier = DailyVaults.forDay(today)
	local snap = snapshotOf(player)
	local trophies = snap and snap.heist and snap.heist.trophies or {}
	local catchUp = {}
	local advent = Config.Data.Advent
	local first = Calendar.daysFromCivil(advent.YEAR, 12, advent.FIRST_DAY)
	for day = math.max(first, today - 31), today - 1 do
		if #catchUp >= H.DAILY_CATCH_UP_LIST then
			break
		end
		if DailyVault.playMode(day, today) == "catchUp" and trophies[DailyVault.ornamentFor(day)] == nil then
			local s = DailyVaults.forDay(day)
			table.insert(catchUp, { day = day, advent = DailyVault.adventDay(day), name = s.name, id = s.id })
		end
	end
	return {
		enabled = LiveFlags.isOn("dailyVault"),
		-- The daily vault opens after Night Clerk (PLAN D4); the garage names the level to clear.
		locked = not dailyOpenFor(player),
		needsClear = select(2, Help.dailyOpen(nil)),
		day = today,
		slot = slot,
		modifier = modifier,
		id = spec.id,
		name = spec.name,
		advent = DailyVault.adventDay(today),
		clearedToday = snap ~= nil and snap.dailyClearedToday == true,
		streak = if snap then snap.streak else 0,
		secondsUntilReset = if snap
			then snap.secondsUntilReset
			else Calendar.secondsUntilReset(os.time(), Config.Data.Daily.RESET_OFFSET_HOURS),
		catchUp = catchUp,
	}
end

local function garageState(player: Player): any
	local crew = crewOf[player]
	local members = {}
	if crew then
		for seat, p in crew.members do
			table.insert(members, { userId = p.UserId, name = p.DisplayName, seat = seat })
		end
	end
	return {
		where = "garage",
		crewId = if crew then crew.id else 0,
		leader = if crew then crew.leader.UserId else 0,
		members = members,
		pending = crew ~= nil and table.find(crew.pending, player) ~= nil,
		inHeist = crew ~= nil and crew.instance ~= nil,
		levels = levelList(player),
		daily = dailyState(player),
	}
end

local function syncPayload(player: Player): any
	local crew = crewOf[player]
	local inst = crew and crew.instance
	if inst and inst.byId[player.UserId] and not inst.byId[player.UserId].left then
		return HeistInstance.syncFor(inst, player.UserId)
	end
	if preparing[player] then
		return { where = "preparing" } -- the client shows the van-door card, not the garage
	end
	return garageState(player)
end

local function pushGarage(crew: Crew)
	for _, p in crew.members do
		if not (crew.instance and crew.instance.byId[p.UserId]) and not preparing[p] then
			push(p, "Sync", garageState(p))
		end
	end
	for _, p in crew.pending do
		if not preparing[p] then
			push(p, "Sync", garageState(p))
		end
	end
end

---------------------------------------------------------------------------
-- Crews
---------------------------------------------------------------------------

local function newCrew(leader: Player): Crew
	nextCrewId += 1
	local crew: Crew = {
		id = nextCrewId,
		leader = leader,
		members = { leader },
		pending = {},
		instance = nil,
		friends = {},
	}
	table.insert(crews, crew)
	crewOf[leader] = crew
	return crew
end

local function dropCrewIfEmpty(crew: Crew)
	if #crew.members == 0 and #crew.pending == 0 and crew.instance == nil then
		local i = table.find(crews, crew)
		if i then
			table.remove(crews, i)
		end
		table.clear(crew.friends)
	end
end

local function inCrew(crew: Crew, p: Player): boolean
	return p.Parent == Players and crewOf[p] == crew
end

-- Friendship flags for the co-op Cash bonus (cached; yields, so run in a thread).
-- Every write re-checks after the yield that both players are still here and in it.
local function learnFriends(crew: Crew, player: Player)
	if not inCrew(crew, player) then
		return
	end
	crew.friends[player] = crew.friends[player] or {}
	for _, other in table.clone(crew.members) do
		local known = crew.friends[player]
		if other ~= player and known and known[other.UserId] == nil then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if not (inCrew(crew, player) and inCrew(crew, other)) then
				continue
			end
			local mine = crew.friends[player] or {}
			crew.friends[player] = mine
			mine[other.UserId] = ok and isFriend == true
			local back = crew.friends[other] or {}
			crew.friends[other] = back
			back[player.UserId] = mine[other.UserId]
		end
	end
end

local function friendsIn(crew: Crew, player: Player): number
	local n = 0
	local known = crew.friends[player]
	if known then
		for _, other in crew.members do
			if other ~= player and known[other.UserId] then
				n += 1
			end
		end
	end
	return n
end

local function leaveCrew(player: Player)
	local crew = crewOf[player]
	if not crew then
		return
	end
	crewOf[player] = nil
	local i = table.find(crew.members, player)
	if i then
		table.remove(crew.members, i)
	end
	local j = table.find(crew.pending, player)
	if j then
		table.remove(crew.pending, j)
	end
	crew.friends[player] = nil
	if crew.leader == player then
		local nextLeader = crew.members[1] or crew.pending[1]
		if nextLeader then
			crew.leader = nextLeader
			local inst = crew.instance
			if inst then
				inst.leader = nextLeader.UserId
				inst.folder:SetAttribute("Leader", nextLeader.UserId)
				if inst.overMsg then
					inst.overMsg.leader = nextLeader.UserId
					-- The results card is up: the new leader gets REPLAY / NEXT at once.
					for _, p in crew.members do
						local m = inst.byId[p.UserId]
						if m and not m.left then
							push(p, "Leader", { leader = nextLeader.UserId })
						end
					end
				end
			end
		end
	end
	pushGarage(crew)
	dropCrewIfEmpty(crew)
end

local function joinCrew(player: Player, crew: Crew)
	leaveCrew(player)
	crewOf[player] = crew
	if crew.instance then
		table.insert(crew.pending, player)
	else
		table.insert(crew.members, player)
	end
	task.spawn(learnFriends, crew, player)
	pushGarage(crew)
end

local function crewSize(crew: Crew): number
	return #crew.members + #crew.pending
end

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------

local function maxInstances(): number
	local ok, v = pcall(LiveFlags.get, "maxInstances")
	local flag = if ok and type(v) == "number" then math.floor(v) else H.MAX_INSTANCES
	return math.clamp(flag, 1, H.MAX_INSTANCES)
end

local function freeSlot(): number?
	for slot = 1, maxInstances() do
		if instances[slot] == nil then
			return slot
		end
	end
	return nil
end

-- Slots sit on a grid around the lobby (Config.Heist.INSTANCE_SLOTS, in units of
-- INSTANCE_SPACING): at most ~4,300 studs from the origin with 8 slots, where float
-- precision is still fine for characters and animation (LihFolk "Instanced Interiors").
local function originFor(slot: number): Vector3
	local cell = H.INSTANCE_SLOTS[slot] or { slot, 0 }
	return Vector3.new(cell[1] * H.INSTANCE_SPACING, H.INSTANCE_Y, cell[2] * H.INSTANCE_SPACING)
end

local function heistFolder(): Folder
	local f = workspace:FindFirstChild(Protocol.FOLDER)
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = Protocol.FOLDER
	nf.Parent = workspace
	return nf
end

-- Builds a heist instance. `members` are real players or fake ones (tests:
-- { userId, name, fake = {x, y, z, yaw} }). levelIndex is a Catalog index, or
-- Protocol.DAILY_INDEX with opts.daily. Returns the instance and its slot.
function HeistService.createInstance(
	levelIndex: number,
	members: { any },
	leaderId: number,
	firstHeist: boolean?,
	opts: CreateOpts?
): (any, number?)
	local o: CreateOpts = opts or {}
	if levelIndex == Protocol.DAILY_INDEX and o.daily == nil then
		return nil, nil
	end
	local slot = freeSlot()
	if not slot then
		return nil, nil
	end
	nextInstanceId += 1
	local list = {}
	for _, m in members do
		table.insert(list, {
			userId = m.userId,
			player = m.player,
			name = m.name or tostring(m.userId),
			ready = false,
			reduced = false,
			friends = m.friends or 0,
			left = false,
			fake = m.fake,
			ftue = {},
			firstVisit = m.firstVisit == true and levelIndex ~= Protocol.DAILY_INDEX,
		})
	end
	local inst = HeistInstance.new({
		id = nextInstanceId,
		levelIndex = levelIndex,
		daily = if levelIndex == Protocol.DAILY_INDEX then o.daily else nil,
		origin = originFor(slot),
		parent = heistFolder(),
		members = list,
		leader = leaderId,
		heistId = string.gsub(HttpService:GenerateGUID(false), "[{}]", ""),
		firstHeist = firstHeist,
		relaxed = o.relaxed == true and levelIndex ~= Protocol.DAILY_INDEX,
		tuning = o.tuning or HeistService.tuning(),
		build = buildOpts(),
		push = push,
		award = award,
		awardDaily = awardDaily,
		nextInfo = nextInfo,
		onFtue = ftueHook,
		analytics = Analytics,
	})
	inst.slot = slot
	instances[slot] = inst
	return inst, slot
end

function HeistService.destroyInstance(inst: any)
	if instances[inst.slot] == inst then
		instances[inst.slot] = nil
	end
	HeistInstance.destroy(inst)
	local crew = crewOfInstance[inst]
	crewOfInstance[inst] = nil
	if crew and crew.instance == inst then
		crew.instance = nil
		-- A solo player who quit mid-heist leaves an empty crew: drop it now.
		dropCrewIfEmpty(crew)
	end
end

local function toGarage(player: Player, i: number)
	player:SetAttribute(Protocol.PLAYER_ATTR, "")
	blockPrompts(player, false)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = false
		root.AssemblyLinearVelocity = Vector3.zero
		root:PivotTo(Lobby.spawnFor(i))
	end
end

local function returnToGarage(crew: Crew)
	local inst = crew.instance
	if inst then
		HeistService.destroyInstance(inst)
	end
	crew.instance = nil
	for _, p in crew.pending do
		table.insert(crew.members, p)
	end
	table.clear(crew.pending)
	for i, p in crew.members do
		toGarage(p, i)
	end
	pushGarage(crew)
end

local function startHeist(crew: Crew, levelIndex: number, daily: HeistInstance.Daily?, relaxed: boolean?): boolean
	if crew.instance then
		return false
	end
	if not daily then
		-- Co-op carry (docs/DATA.md): crewmates who have not unlocked this tape still
		-- get the result and unlock it by clearing it with the crew.
		for _, p in crew.members do
			if p ~= crew.leader and not isUnlocked(p, levelIndex) then
				push(p, "Toast", { text = "New tape! Clear it with your crew to unlock it." })
			end
		end
	end
	local members = {}
	local firstHeist = false
	-- The free first catch (detection x2) goes to the first heists that HAVE a guard (WALKTHROUGH
	-- P1-6: it used to be spent on L1, which has none): Help.graceFor.
	local levelSpec = Protocol.levelSpec(levelIndex, daily and daily.day)
	local dataKey = if daily or not levelSpec then nil else H.LEVEL_DATA_KEYS[levelSpec.id]
	for _, p in crew.members do
		local snap = snapshotOf(p)
		local levels = snap and snap.heist and snap.heist.levels
		table.insert(members, {
			userId = p.UserId,
			player = p,
			name = p.DisplayName,
			friends = friendsIn(crew, p),
			firstVisit = Help.firstVisit(dataKey, levels), -- run 1's longer intro (HeistInstance)
		})
		if snap and snap.heist and Help.graceFor(levelSpec, snap.heist.levels) then
			firstHeist = true
		end
	end
	if #members == 0 then
		return false
	end
	local inst = HeistService.createInstance(
		levelIndex,
		members,
		crew.leader.UserId,
		firstHeist,
		{ daily = daily, relaxed = relaxed }
	)
	if not inst then
		for _, p in crew.members do
			push(p, "Toast", { text = "All the vans are out. Try again in a minute." })
		end
		return false
	end
	crew.instance = inst
	crewOfInstance[inst] = crew
	local spec = Catalog[levelIndex]
	for _, p in crew.members do
		p:SetAttribute(Protocol.PLAYER_ATTR, inst.name)
		blockPrompts(p, true)
		push(p, "Sync", HeistInstance.syncFor(inst, p.UserId))
		if spec and spec.id == H.FTUE_L2_LEVEL and not daily then
			ftueHook(p, "L2Started")
		end
		track("heistStarted", p, {
			heistId = inst.heistId,
			level = inst.trackLevel,
			crew = #crew.members,
			friends = friendsIn(crew, p),
			daily = if daily then daily.slot else nil,
		})
	end
	return true
end

-- Waits (bounded) for the art kit before a heist the server starts by itself; a
-- player's own pick never waits (no yield inside remote handlers).
local function waitForKit()
	if H.KIT_LEVELS and KitService ~= nil and not KitService.isReady() then
		pcall(KitService.ready, H.KIT_WAIT_SECONDS)
	end
end

-- Golden-frame staging (Studio only: `staging` is nil unless RunService:IsStudio(), see
-- Heist/Staging): G1 / TYPE start L1, G2 / CLONE_AB start the Clone Party with the solution's
-- clones seeded into your deck (you + 7 = 8 OF ME in run 1), G3 stays in the garage.
local function stage(player: Player, crew: Crew, name: string): boolean
	local spec = Scenario.spec(name)
	if not spec then
		return false
	end
	if not spec.level then
		push(player, "Sync", syncPayload(player))
		return true
	end
	local index = Protocol.catalogIndex(spec.level)
	if not index then
		return false
	end
	waitForKit()
	if not startHeist(crew, index) then
		return false
	end
	if spec.tapes and crew.instance then
		Staging.seed(crew.instance, player.UserId)
	end
	return true
end

---------------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------------

local function instanceOf(player: Player): any
	local crew = crewOf[player]
	local inst = crew and crew.instance
	if inst then
		local m = inst.byId[player.UserId]
		if m and not m.left then
			return inst
		end
	end
	return nil
end

local INTERACT_KINDS = { KIND.Grab, KIND.Release, KIND.Press, KIND.Hide, KIND.Emote }

-- Why a tape is locked, in kid words ("Clear Two Doors first." / "2 more ★ to open it.").
local function lockedText(player: Player, index: number): string
	local spec = Catalog[index]
	local key = spec and H.LEVEL_DATA_KEYS[spec.id]
	local needsClear, starsNeeded = lockInfo(snapshotOf(player), key)
	if needsClear then
		local name = needsClear
		for _, other in Catalog do
			if H.LEVEL_DATA_KEYS[other.id] == needsClear then
				name = other.name
			end
		end
		return "Clear " .. name .. " first."
	elseif starsNeeded > 0 then
		return string.format("%d more ★ to open it.", starsNeeded)
	end
	return "That tape is locked."
end

-- The crew leader may start a heist from the garage or the results card.
local function leaderCrew(player: Player): Crew?
	local crew = crewOf[player]
	if not crew or crew.leader ~= player then
		push(player, "Toast", { text = "Your crew leader picks the tape." })
		return nil
	end
	-- One new heist per player pick every INSTANCE_COOLDOWN_SECONDS: alternating
	-- SelectLevel and Leave cannot make the server build level after level.
	local last = lastStartBy[player]
	if last and os.clock() - last < H.INSTANCE_COOLDOWN_SECONDS then
		push(player, "Toast", { text = "Rewinding the tape... try again in a moment." })
		return nil
	end
	local inst = crew.instance
	if inst then
		if inst.overAt == nil then
			return nil -- mid-heist: Leave first
		end
		returnToGarage(crew)
	end
	return crew
end

-- "Try Relaxed?" (PLAN §6.1 item 5): Heist.SelectLevel(index, true). The server decides: only the
-- crew leader, only mid-heist on the level being played, and only when the sim offers it to them
-- (HeistSim.offerRelaxed: 3 catches this heist, a story level not already relaxed). The heist
-- restarts in place as Levels/Relaxed: no garage in between, the kid keeps playing.
local function selectRelaxed(player: Player, index: number)
	local crew = crewOf[player]
	local inst = crew and crew.instance
	if not (crew and inst and crew.leader == player and inst.overAt == nil) then
		return
	end
	if inst.levelIndex ~= index or inst.daily ~= nil or not HeistSim.offerRelaxed(inst.sim, player.UserId) then
		return
	end
	local last = lastStartBy[player]
	if last and os.clock() - last < H.INSTANCE_COOLDOWN_SECONDS then
		return
	end
	local level = inst.trackLevel
	HeistService.destroyInstance(inst)
	crew.instance = nil
	for _, p in crew.pending do
		table.insert(crew.members, p)
	end
	table.clear(crew.pending)
	if startHeist(crew, index, nil, true) then
		lastStartBy[player] = os.clock()
		track("relaxedChosen", player, level)
	else
		returnToGarage(crew)
	end
end

local function declareRemotes()
	local R = Protocol.REMOTE
	local RATE = H.RATE
	msgPush = Net.Push(R.Msg)

	Net.Listen(R.EndRun, {
		rate = RATE.EndRun,
		args = {},
		handler = function(player: Player)
			local inst = instanceOf(player)
			if inst then
				HeistInstance.endRun(inst, player.UserId)
			end
		end,
	})
	Net.Listen(R.Interact, {
		rate = RATE.Interact,
		args = { T.oneOf(INTERACT_KINDS), T.integer(0, 1024) },
		handler = function(player: Player, kind: number, index: number)
			local inst = instanceOf(player)
			if inst then
				HeistInstance.interact(inst, player.UserId, kind, index)
			end
		end,
	})
	Net.Listen(R.Deck, {
		rate = RATE.Deck,
		args = { T.oneOf(Protocol.DECK_OPS :: any), T.optional(T.integer(1, Config.Sim.MAX_LEVEL_CAP)) },
		handler = function(player: Player, op: string, n: number?)
			local inst = instanceOf(player)
			if inst then
				HeistInstance.deckAction(inst, player.UserId, op, n)
			end
		end,
	})
	Net.Listen(R.Ready, {
		rate = RATE.Ready,
		args = { T.optional(T.boolean) },
		handler = function(player: Player, reduced: boolean?)
			local inst = instanceOf(player)
			if inst then
				HeistInstance.ready(inst, player.UserId, reduced)
			end
		end,
	})
	Net.Listen(R.FastForward, {
		rate = RATE.FastForward,
		args = { T.boolean },
		handler = function(player: Player, on: boolean)
			local inst = instanceOf(player)
			if inst then
				HeistInstance.fastForward(inst, player.UserId, on, workspace:GetServerTimeNow())
			end
		end,
	})
	Net.Listen(R.SelectLevel, {
		rate = RATE.SelectLevel,
		args = { T.integer(1, #Catalog), T.optional(T.boolean) },
		handler = function(player: Player, index: number, relaxed: boolean?)
			if relaxed == true then
				selectRelaxed(player, index)
				return
			end
			if not isUnlocked(player, index) then
				push(player, "Toast", { text = lockedText(player, index) })
				return
			end
			local crew = leaderCrew(player)
			if crew and startHeist(crew, index, nil) then
				lastStartBy[player] = os.clock()
			end
		end,
	})
	Net.Listen(R.SelectDaily, {
		rate = RATE.SelectDaily,
		args = { T.optional(T.integer(0, 2 ^ 31)) },
		handler = function(player: Player, day: number?)
			if not LiveFlags.isOn("dailyVault") then
				push(player, "Toast", { text = "The daily vault is closed right now." })
				return
			end
			if not dailyOpenFor(player) then
				local _, name = Help.dailyOpen(nil)
				push(player, "Toast", { text = Strings.dailyLockedToast(name) })
				return
			end
			local today = todayDay()
			local daily = HeistService.dailyFor(day or today, today)
			if not daily then
				push(player, "Toast", { text = "That vault is not open today." })
				return
			end
			local crew = leaderCrew(player)
			if crew and startHeist(crew, Protocol.DAILY_INDEX, daily) then
				lastStartBy[player] = os.clock()
			end
		end,
	})
	Net.Listen(R.JoinFriend, {
		rate = RATE.JoinFriend,
		args = { T.integer(1, 2 ^ 52) },
		handler = function(player: Player, userId: number)
			if not LiveFlags.isOn("joinFriend") then
				push(player, "Toast", { text = "Joining crews is paused right now." })
				return
			end
			local target = Players:GetPlayerByUserId(userId)
			if not target or target == player then
				return
			end
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(userId)
			end)
			-- Re-check everything after the yield (no yield between check and write).
			local crew = crewOf[target]
			if not ok or not isFriend or player.Parent ~= Players or not crew then
				push(player, "Toast", { text = "Could not join that crew." })
				return
			end
			if crewOf[player] == crew or instanceOf(player) ~= nil then
				return
			end
			if crewSize(crew) >= Config.Sim.MAX_CREW then
				push(player, "Toast", { text = "That crew is full." })
				return
			end
			joinCrew(player, crew)
			push(crew.leader, "Toast", { text = player.DisplayName .. " joined your crew!" })
			if crew.instance then
				push(player, "Toast", { text = "You join at their next heist." })
			end
		end,
	})
	Net.Listen(R.Leave, {
		rate = RATE.Leave,
		args = {},
		handler = function(player: Player)
			local crew = crewOf[player]
			if not crew then
				return
			end
			local inst = instanceOf(player)
			if inst then
				if inst.overAt ~= nil and crew.leader == player then
					returnToGarage(crew)
					return
				end
				HeistInstance.removeMember(inst, player.UserId)
				leaveCrew(player)
				newCrew(player)
				toGarage(player, 1)
				push(player, "Sync", garageState(player))
				return
			end
			if #crew.members > 1 or #crew.pending > 0 then
				leaveCrew(player)
				newCrew(player)
				push(player, "Sync", garageState(player))
			end
		end,
	})
	Net.Handle(R.Sync, {
		rate = RATE.Sync,
		args = {},
		handler = function(player: Player): Net.Result
			return Net.ok(syncPayload(player))
		end,
	})
end

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.WalkSpeed = Config.Rec.WALK_SPEED
	end
	local inst = instanceOf(player)
	if inst then
		char:WaitForChild("HumanoidRootPart", 10)
		HeistInstance.placeCharacter(inst, player.UserId)
	end
end

-- Starts the FTUE level for a new solo player in the garage (re-checks everything:
-- callers yield). Returns true when the heist started.
tryFtueStart = function(player: Player): boolean
	local crew = crewOf[player]
	if
		player.Parent ~= Players
		or not crew
		or crew.leader ~= player
		or #crew.members ~= 1
		or #crew.pending > 0
		or crew.instance
	then
		return false
	end
	preparing[player] = nil
	return startHeist(crew, ftueIndex(), nil)
end

-- A failed FTUE start (every van out) retries a few times while the player is still a
-- new, solo leader in the garage; they can also tap the first tape themselves.
retryFtue = function(player: Player)
	for _ = 1, H.FTUE_RETRY_TRIES do
		task.wait(H.FTUE_RETRY_SECONDS)
		local crew = crewOf[player]
		if player.Parent ~= Players or not crew or crew.instance or not isNewAccount(player) then
			return
		end
		if tryFtueStart(player) then
			return
		end
	end
end

local function onPlayerAdded(player: Player)
	task.spawn(Avatars.prepare, player)
	player:SetAttribute(Protocol.PLAYER_ATTR, "")
	applyPrompts(player)
	-- Arrived with a Roblox party: share a crew with a party member here.
	local party = player.PartyId
	local joined = false
	if party ~= "" then
		for _, other in Players:GetPlayers() do
			local crew = other ~= player and other.PartyId == party and crewOf[other]
			if crew and crewSize(crew) < Config.Sim.MAX_CREW then
				crewOf[player] = crew
				if crew.instance then
					table.insert(crew.pending, player)
				else
					table.insert(crew.members, player)
				end
				task.spawn(learnFriends, crew, player)
				joined = true
				pushGarage(crew)
				break
			end
		end
	end
	if not joined then
		newCrew(player)
	end
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	ftueHook(player, "Joined")
	task.spawn(function()
		-- The boot Sync shows "preparing" (the van door), not the garage, until the server
		-- has decided: a new account goes straight into the FTUE level (§7.5).
		preparing[player] = true
		-- The profile, the first LiveFlags read (kill switches apply before the first heist) and the
		-- art kit are awaited side by side: a cold server costs the longest wait, not the sum (premium
		-- G1: control within 10 s of the first frame; PresentPlan.serverWait).
		local kitDone = false
		task.spawn(function()
			pcall(waitForKit)
			kitDone = true
		end)
		local pending = 2
		task.spawn(function()
			if DataService ~= nil and DataService.status() ~= "offline" then
				pcall(DataService.waitForData, player, H.DATA_WAIT_SECONDS)
			end
			pending -= 1
		end)
		task.spawn(function()
			pcall(LiveFlags.waitForFirstRead, H.FLAGS_WAIT_SECONDS)
			pending -= 1
		end)
		while pending > 0 do
			task.wait()
		end
		if player.Parent ~= Players then
			preparing[player] = nil
			return
		end
		local crew = crewOf[player]
		if staging and crew and crew.leader == player and not crew.instance then
			preparing[player] = nil
			if stage(player, crew, staging) then
				return
			end
		end
		if
			crew
			and H.FTUE_AUTOSTART
			and crew.leader == player
			and #crew.members == 1
			and not crew.instance
			and isNewAccount(player)
		then
			while not kitDone do -- started at join, so at most KIT_WAIT_SECONDS from then
				task.wait()
			end
			if tryFtueStart(player) then
				return
			end
			-- Full server (or the player moved on): the garage now, and retry while new.
			preparing[player] = nil
			push(player, "Sync", syncPayload(player))
			task.spawn(retryFtue, player)
			return
		end
		preparing[player] = nil
		push(player, "Sync", syncPayload(player))
	end)
end

local function onPlayerRemoving(player: Player)
	local crew = crewOf[player]
	local inst = crew and crew.instance
	if inst then
		HeistInstance.removeMember(inst, player.UserId)
	end
	leaveCrew(player)
	inHeist[player] = nil
	preparing[player] = nil
	lastStartBy[player] = nil
	Avatars.release(player)
end

local function step()
	local now = workspace:GetServerTimeNow()
	for _, inst in instances do
		debug.profilebegin("EH.Instance")
		local ok, err = pcall(HeistInstance.update, inst, now)
		debug.profileend()
		if not ok and os.clock() - lastError > 10 then
			lastError = os.clock()
			warn("[HeistService] instance " .. tostring(inst.name) .. " errored: " .. tostring(err))
		end
		if inst.dead then
			HeistService.destroyInstance(inst)
		elseif inst.overAt and now - inst.overAt >= H.RESULTS_SECONDS then
			local crew = crewOfInstance[inst]
			if crew then
				returnToGarage(crew)
			else
				HeistService.destroyInstance(inst)
			end
		end
	end
end

export type StartOpts = { lobby: boolean?, players: boolean? }

-- Boots the sim path's server. Safe to call more than once (tests call it too).
-- opts.lobby = false skips the garage build; opts.players = false skips player wiring
-- and the Heartbeat loop (the engine smoke test drives instances itself).
function HeistService.start(opts: StartOpts?)
	if started then
		return
	end
	started = true
	local o: StartOpts = opts or {}
	heistFolder()
	Avatars.folder()
	staging = Staging.active()
	if staging then
		Staging.prepare(staging)
	end
	if o.lobby ~= false then
		-- greybox at once; dressed with the art kit in the background once it is ready (garage v1)
		Lobby.build(if H.KIT_LEVELS then KitService else nil)
	end
	declareRemotes()
	-- The store kill switch applies at once (prompts are re-checked on every change).
	LiveFlags.Changed:Connect(function(name: string)
		if name == "store" then
			for _, p in Players:GetPlayers() do
				applyPrompts(p)
			end
		end
	end)
	if o.players == false then
		return
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	RunService.Heartbeat:Connect(step)
end

-- The live instances (tests and debugging).
function HeistService.instances(): { [number]: any }
	return instances
end

-- Catalog index of a LevelSpec id (Protocol.catalogIndex): never hard-code indices.
function HeistService.indexOf(specId: string): number?
	return Protocol.catalogIndex(specId)
end

return HeistService
