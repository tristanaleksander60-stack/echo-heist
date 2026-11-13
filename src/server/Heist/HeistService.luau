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
local CrewBoard = require(Shared:WaitForChild("Heist"):WaitForChild("CrewBoard"))
local VanRules = require(Shared:WaitForChild("Heist"):WaitForChild("VanRules"))
local QuickCrew = require(Shared:WaitForChild("Heist"):WaitForChild("QuickCrew"))
local Strings = require(Shared:WaitForChild("Heist"):WaitForChild("Strings"))
local HeistSim = require(Shared:WaitForChild("Sim"):WaitForChild("HeistSim"))
local Scenario = require(Shared:WaitForChild("Heist"):WaitForChild("Scenario"))
local LihFolk = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(LihFolk:WaitForChild("Net"))
local Signal = require(LihFolk:WaitForChild("Signal"))
local RateLimit = require(LihFolk:WaitForChild("RateLimit"))

local HeistInstance = require(script.Parent:WaitForChild("HeistInstance"))
local LookSync = require(script.Parent:WaitForChild("LookSync"))
local Avatars = require(script.Parent:WaitForChild("Avatars"))
local Characters = require(script.Parent:WaitForChild("Characters"))
local Lobby = require(script.Parent:WaitForChild("Lobby"))
local Vans = require(script.Parent:WaitForChild("Vans"))
local Staging = require(script.Parent:WaitForChild("Staging"))
local LiveFlags = require(script.Parent.Parent:WaitForChild("Analytics"):WaitForChild("LiveFlags"))
local HaulBoardService = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("HaulBoardService"))

local T = Net.T
local H = Config.Heist
local HD = Config.Hideout
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
	-- the hideout lobby (Config.Hideout): the job the leader picked on the job board (nil = their next job) and the
	-- departure in progress (GO -> the drive -> the heist)
	job: { index: number, day: number? }?,
	departing: any?,
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
local Awards: any = nil -- server Data/Awards (Roblox badges); nil = no badges
local msgPush: Net.Push? = nil
local crewOf: { [Player]: Crew } = {}
local crews: { Crew } = {}
local nextCrewId = 0
local instances: { [number]: any } = {} -- slot -> instance
local crewOfInstance: { [any]: Crew } = {}
local nextInstanceId = 0
local lastError = -math.huge
local lastLobbyCheck = -math.huge -- os.clock() of the last HeistService.checkLobby (Config.Heist.LEAVE)
local inHeist: { [Player]: boolean } = {}
-- Players whose first Sync is still being decided (data, kit, FTUE autostart): their
-- client shows a "preparing" card, never the garage, until the server decides.
local preparing: { [Player]: boolean } = {}
-- The first heist of a new account (FTUE, intro -> L1) without a server hold: the player is in the hideout with
-- control as soon as the profile is read, the story intro plays over it on the client (Heist/Cinematic), and the
-- client's boot Heist.Ready (the intro or the title is over) starts L1. Nothing waits on a client that never
-- answers: without the Ready the player simply stays in the hideout (the job board offers L1).
--   ftuePending: a new account in the hideout whose L1 start waits for that Ready (the garage Sync says `ftue`);
--   earlyReady: the boot Ready came while the server was still preparing (no intro on that client): L1 at once.
local ftuePending: { [Player]: boolean } = {}
local earlyReady: { [Player]: boolean } = {}
-- os.clock() of the last heist a player's pick created (INSTANCE_COOLDOWN_SECONDS).
local lastStartBy: { [Player]: number } = {}
local tryFtueStart: (player: Player) -> boolean
local retryFtue: (player: Player) -> ()
local startFtueAfterReady: (player: Player) -> ()
-- The hideout's vans (Shared/Heist/VanRules; Heist/Vans draws them): one state for the whole server.
local vans = VanRules.new()
-- Quick Crew (Shared/Heist/QuickCrew; Config.Hideout.QUICK): the seekers on this server and their held seats.
local quick = QuickCrew.new()
-- os.clock() of a player's last quick / open / style op (Config.Hideout.QUICK.COOLDOWN).
local lastLobbyOp: { [Player]: number } = {}
-- os.clock() of a leader's last PARTY op (size / privacy / kick; Config.Hideout.PARTY.COOLDOWN).
local lastPartyOp: { [Player]: number } = {}
local quickPassFn: (() -> ())? = nil

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
	-- "Today's biggest haul" (Data/HaulBoardService): a joining player's saved entry for today goes on this
	-- server's board (it was untainted and not Relaxed when it was saved: DailyVault.apply).
	if service.Loaded and service.Loaded.Connect then
		service.Loaded:Connect(function(player: Player)
			pcall(function()
				local snap = service.getSnapshot(player)
				local daily = snap and snap.heist and snap.heist.daily
				HaulBoardService.seed(player.UserId, player.DisplayName, daily)
			end)
		end)
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

-- src/server/Data/Awards: heists earn Roblox badges from their sim facts (BADGES track).
function HeistService.configureAwards(awards: any)
	Awards = awards
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
	-- the server board first (server-decided facts; untainted, non-Relaxed runs of today's vault only), and never
	-- in the way of the award: a board error is a warning
	local okBoard, boardErr = pcall(HaulBoardService.submit, player.UserId, player.DisplayName, day, result)
	if not okBoard then
		warn("[HeistService] haul board: " .. tostring(boardErr))
	end
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

-- Tests only (HeistService.onPush): sees every push, real or fake player.
local pushListener: ((player: any, kind: string, payload: any) -> ())? = nil

local function push(player: Player, kind: string, payload: any)
	local listener = pushListener
	if listener then
		pcall(listener, player, kind, payload)
	end
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
		-- offline Studio (no data): new, so the FTUE path is the default there. A live profile that has not
		-- loaded yet (a session lock from the last server, a slow DataStore) is unknown: the hideout, never a
		-- returning player's intro and L1 by mistake.
		return DataService == nil or DataService.status() == "offline"
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

---------------------------------------------------------------------------
-- The hideout's vans (Config.Hideout; Shared/Heist/VanRules, Heist/Vans)
---------------------------------------------------------------------------

-- Is the van lobby on? (the config switch, and the garage's van rigs exist)
local function lobbyOn(): boolean
	return HD.ENABLED == true and Vans.folder() ~= nil
end

-- What the van rules need to know about a crew.
local function crewInfo(crew: Crew): VanRules.Crew
	local ids = {}
	for _, p in crew.members do
		table.insert(ids, p.UserId)
	end
	return { id = crew.id, leaderId = crew.leader.UserId, members = ids, inHeist = crew.instance ~= nil }
end

local function namesOf(crew: Crew): { [number]: string }
	local out = {}
	for _, p in crew.members do
		out[p.UserId] = p.DisplayName
	end
	for _, p in crew.pending do
		out[p.UserId] = p.DisplayName
	end
	return out
end

-- Redraws a crew's van (seats follow the crew's members).
local function renderVan(crew: Crew?)
	if not crew then
		return
	end
	local v = VanRules.vanOfCrew(vans, crew.id)
	if v then
		VanRules.syncSeats(v, crewInfo(crew))
		Vans.render(v.bay, v, namesOf(crew), QuickCrew.heldIn(quick, v.bay))
	end
end

-- A player's Quick Crew state for their client (server-written attributes): QuickCrew "" | "seek" | "matched",
-- QuickBay = the van holding a seat for them (0 = none).
local function quickAttrs(player: Player)
	local uid = player.UserId
	local bay = QuickCrew.holdOf(quick, uid)
	local state = if bay then "matched" elseif QuickCrew.isSeeking(quick, uid) then "seek" else ""
	if player:GetAttribute("QuickCrew") ~= state then
		player:SetAttribute("QuickCrew", state)
	end
	if player:GetAttribute("QuickBay") ~= (bay or 0) then
		player:SetAttribute("QuickBay", bay or 0)
	end
end

local function releaseVan(crew: Crew)
	local v = VanRules.vanOfCrew(vans, crew.id)
	if v then
		VanRules.release(vans, v.bay)
		Vans.render(v.bay, nil, {})
		for _, uid in QuickCrew.release(quick, v.bay) do
			local p = Players:GetPlayerByUserId(uid)
			if p then
				quickAttrs(p)
			end
		end
	end
end

local function vanBayOf(crew: Crew?): number?
	local v = crew and VanRules.vanOfCrew(vans, crew.id)
	return if v then v.bay else nil
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
		-- the hideout lobby (Config.Hideout): vans on, your crew's van bay (0 = none), the job the leader picked
		lobby = lobbyOn(),
		van = vanBayOf(crew) or 0,
		job = if crew and crew.job then crew.job.index else 0,
		jobDay = if crew and crew.job then crew.job.day else nil,
		-- a new account's first visit: the client plays the intro (or the title) here and its Ready starts L1
		ftue = ftuePending[player] == true,
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

-- kind: "Sync" (a garage refresh) or "Lobby" (the crew just came back from a heist: the client tears the heist down
-- whatever state it was in; garage-exit-fix).
local function pushGarage(crew: Crew, kind: string?)
	-- the crew seat is the Rookie's crew colour (scarf, stripes): members by index, then the ones waiting
	for seat, p in crew.members do
		Characters.setSeat(p, seat)
	end
	for i, p in crew.pending do
		Characters.setSeat(p, #crew.members + i)
	end
	for _, p in crew.members do
		if not (crew.instance and crew.instance.byId[p.UserId]) and not preparing[p] then
			push(p, kind or "Sync", garageState(p))
		end
	end
	for _, p in crew.pending do
		if not preparing[p] then
			push(p, "Sync", garageState(p))
		end
	end
	renderVan(crew)
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
		crew.departing = nil
		releaseVan(crew)
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
	Vans.unseat(player, player.Parent == Players)
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

-- Seats held in a crew's van for matched Quick Crew players (a friend never takes one of those).
local function seatsHeld(crew: Crew): number
	local v = VanRules.vanOfCrew(vans, crew.id)
	return if v then QuickCrew.heldIn(quick, v.bay) else 0
end

-- How many a crew takes (PARTY): its van's crew size in the hideout, else MAX_CREW.
local function crewCap(crew: Crew): number
	local v = VanRules.vanOfCrew(vans, crew.id)
	return if v then VanRules.capOf(v) else Config.Sim.MAX_CREW
end

-- Did this player come in on the leader's invite, follow the leader into the server, or arrive in their Roblox
-- party? (PARTY: INVITE ONLY vans; read from the server's own join data, never from a client.)
local function invitedBy(player: Player, leader: Player): boolean
	if player.FollowUserId == leader.UserId then
		return true
	end
	if player.PartyId ~= "" and player.PartyId == leader.PartyId then
		return true
	end
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	return ok and type(data) == "table" and data.ReferredByPlayerId == leader.UserId
end

-- Has the leader of the crew's van kicked this player a moment ago? (PARTY.KICK_BLOCK_SECONDS)
local function kickedFrom(crew: Crew, player: Player): boolean
	local v = VanRules.vanOfCrew(vans, crew.id)
	return v ~= nil and VanRules.isKicked(v, player.UserId, os.clock())
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
		awards = Awards,
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

-- bay: the crew's van (Config.Hideout): the crew comes back beside it, else round the garage spawn.
-- The instance attribute is cleared first (the client's watchdog reads it); the rest is guarded, so a van or
-- character problem never stops the caller from sending the lobby state (garage-exit-fix).
local function toGarage(player: Player, i: number, bay: number?)
	player:SetAttribute(Protocol.PLAYER_ATTR, "")
	local ok, err = pcall(function()
		blockPrompts(player, false)
		Vans.unseat(player, false)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
			local at = if bay then Vans.besideVan(bay, i) else nil
			root:PivotTo(at or Lobby.spawnFor(i))
		end
	end)
	if not ok then
		warn("[HeistService] toGarage: " .. tostring(err))
	end
end

local function returnToGarage(crew: Crew)
	local inst = crew.instance
	if inst then
		HeistService.destroyInstance(inst)
	end
	crew.instance = nil
	crew.departing = nil
	for _, p in crew.pending do
		table.insert(crew.members, p)
	end
	table.clear(crew.pending)
	local bay = vanBayOf(crew)
	if bay then
		VanRules.returned(vans, bay, crewInfo(crew)) -- the van is parked again, every seat to be taken anew
	end
	for i, p in crew.members do
		toGarage(p, i, bay)
	end
	pushGarage(crew, "Lobby")
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
	local bay = vanBayOf(crew)
	if bay then
		VanRules.setAway(vans, bay) -- the van stays the crew's while it is on the job
		renderVan(crew)
	end
	local spec = Catalog[levelIndex]
	for seat, p in crew.members do
		Characters.setSeat(p, seat)
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

-- The explicit lobby state (Heist.Msg "Lobby" = the garage state): the client treats it as authoritative and
-- idempotent, whatever heist state it was showing (Heist/LeavePlan).
local function sendLobby(player: Player)
	if preparing[player] then
		return -- the preparing card stays until the server decides (its own Sync follows)
	end
	push(player, "Lobby", garageState(player))
end

local function guarded(what: string, fn: (...any) -> ...any, ...: any)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[HeistService] leave " .. what .. ": " .. tostring(err))
	end
end

-- BACK TO GARAGE (Heist.Leave; garage-exit-fix). Whatever the heist was doing (a run, caught, between runs, a rewind,
-- the results card) and whoever else is in it, the leaver ends in the hideout: out of the instance, in a crew of
-- their own (or out of their garage crew), PLAYER_ATTR "", and an explicit "Lobby" state on their client, always (a
-- client that is somehow still showing a heist is put right by pressing it again). Each step is guarded, so one
-- failing step never skips the teleport or the lobby state. A heist nobody is left in is destroyed at once, not on
-- the next tick, so no later tick (Gus) can act on the leaver. The others in a crew heist play on.
function HeistService.leave(player: Player)
	local crew = crewOf[player]
	local inst = instanceOf(player)
	if not crew and not inst then
		return
	end
	if inst and crew and inst.overAt ~= nil and crew.leader == player then
		guarded("returnToGarage", returnToGarage, crew) -- the leader on the results card takes the crew home
		if crewOf[player] == crew and player:GetAttribute(Protocol.PLAYER_ATTR) ~= "" then
			guarded("toGarage", toGarage, player, 1)
			sendLobby(player)
		end
		return
	end
	local wasIn = inst ~= nil or (player:GetAttribute(Protocol.PLAYER_ATTR) or "") ~= ""
	if inst then
		guarded("removeMember", HeistInstance.removeMember, inst, player.UserId)
		guarded("leaveCrew", leaveCrew, player)
		if inst.dead then
			guarded("destroyInstance", HeistService.destroyInstance, inst)
		end
	elseif crew and (#crew.members > 1 or #crew.pending > 0) then
		guarded("leaveCrew", leaveCrew, player)
	end
	if crewOf[player] == nil then
		guarded("newCrew", newCrew, player)
	end
	if wasIn then
		guarded("toGarage", toGarage, player, 1)
	end
	sendLobby(player)
end

-- The server's half of the watchdog (Config.Heist.LEAVE.SERVER_CHECK_SECONDS): a player whose instance attribute
-- names an instance they are no longer in (it ended, they were removed) is put back in the hideout with the lobby
-- state. Returns how many it reset.
function HeistService.checkLobby(): number
	local n = 0
	for player in crewOf do
		local attr = player:GetAttribute(Protocol.PLAYER_ATTR)
		if type(attr) == "string" and attr ~= "" and not preparing[player] and instanceOf(player) == nil then
			n += 1
			guarded("toGarage", toGarage, player, 1)
			sendLobby(player)
		end
	end
	return n
end

-- Tests (tests/engine_smoke.luau, no real players there): a crew of (fake) players bound to an instance as
-- startHeist binds it, the crew a player is in, and every push the server makes (a listener; nil = off).
function HeistService.bindCrew(players: { any }, inst: any?): any
	local crew = newCrew(players[1])
	for i = 2, #players do
		crewOf[players[i]] = crew
		table.insert(crew.members, players[i])
	end
	if inst then
		crew.instance = inst
		crewOfInstance[inst] = crew
		for _, p in players do
			p:SetAttribute(Protocol.PLAYER_ATTR, inst.name)
		end
	end
	return crew
end
function HeistService.crewOf(player: any): any
	return crewOf[player]
end
function HeistService.hasCrew(crew: any): boolean
	return table.find(crews, crew) ~= nil
end
function HeistService.onPush(fn: ((player: any, kind: string, payload: any) -> ())?)
	pushListener = fn
end

-- Heist.Interact(kind, arg): the queued intents, and Slide (arg 0 / 1; Sim/Interact.slide records it at once and
-- has its own server cooldown: the validator's raised speed window, Config.Slide)
local INTERACT_KINDS = { KIND.Grab, KIND.Release, KIND.Press, KIND.Hide, KIND.Emote, KIND.Slide }

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

---------------------------------------------------------------------------
-- The hideout lobby: van actions (Heist.Ready with a VanRules action table)
---------------------------------------------------------------------------

local function crewById(id: number): Crew?
	for _, c in crews do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- Studs from a player's root to a van point ("cab" | "door" | "paint"; "any" = the nearest of them).
local function vanDist(player: Player, bay: number, point: string): number?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local best: number? = nil
	for _, name in (if point == "any" then { "cab", "door", "paint" } else { point }) do
		local pos = Vans.point(bay, name)
		if pos then
			local d = (root.Position - pos).Magnitude
			if best == nil or d < best then
				best = d
			end
		end
	end
	return best
end

local function refused(player: Player, code: string)
	local text = Strings.LOBBY_REFUSED[code]
	if text then
		push(player, "Toast", { text = text })
	end
end

-- The job a departure plays: the one the leader picked on the job board, else their next job (CrewBoard.nextJob).
local function jobFor(crew: Crew): (number?, HeistInstance.Daily?)
	local job = crew.job
	if job and job.index == Protocol.DAILY_INDEX then
		if not LiveFlags.isOn("dailyVault") or not dailyOpenFor(crew.leader) then
			push(crew.leader, "Toast", { text = "The daily vault is closed right now." })
			return nil, nil
		end
		local today = todayDay()
		local daily = HeistService.dailyFor(job.day or today, today)
		if not daily then
			push(crew.leader, "Toast", { text = "That vault is not open today." })
			return nil, nil
		end
		return Protocol.DAILY_INDEX, daily
	end
	local index = (if job then job.index else CrewBoard.nextJob(levelList(crew.leader))) or ftueIndex()
	if not isUnlocked(crew.leader, index) then
		push(crew.leader, "Toast", { text = lockedText(crew.leader, index) })
		return nil, nil
	end
	return index, nil
end

-- SOLO / GO: the doors shut, every member's client plays the drive (Msg "Depart"), and the heist starts
-- Config.Hideout.DRIVE.SERVER_SECONDS later (everything checked again then).
local function depart(crew: Crew, bay: number, player: Player)
	local last = lastStartBy[player]
	if last and os.clock() - last < H.INSTANCE_COOLDOWN_SECONDS then
		push(player, "Toast", { text = "Warming up the engine... try again in a moment." })
		return
	end
	if freeSlot() == nil then
		push(player, "Toast", { text = "All the vans are out. Try again in a minute." })
		return
	end
	local index, daily = jobFor(crew)
	if not index then
		return
	end
	lastStartBy[player] = os.clock()
	VanRules.depart(vans, bay)
	Vans.seat(crew.leader, bay, 1) -- the leader climbs into the driver's seat
	renderVan(crew)
	local v = VanRules.vanOfCrew(vans, crew.id)
	for _, p in crew.members do
		push(p, "Depart", { bay = bay, seconds = HD.DRIVE.SERVER_SECONDS, paint = if v then v.paint else 0 })
	end
	local token = {}
	crew.departing = token
	task.delay(HD.DRIVE.SERVER_SECONDS, function()
		if crew.departing ~= token then
			return -- called off (the crew emptied, or it came back)
		end
		crew.departing = nil
		local van = VanRules.vanOfCrew(vans, crew.id)
		if not van or van.bay ~= bay or crew.instance or #crew.members == 0 then
			return
		end
		for _, p in crew.members do
			Vans.unseat(p, false) -- out of the seat welds before the heist teleports everyone
		end
		if not startHeist(crew, index, daily) then
			VanRules.returned(vans, bay, crewInfo(crew))
			for i, p in crew.members do
				toGarage(p, i, bay)
			end
			pushGarage(crew)
			return
		end
		crew.job = nil -- the next departure plays the next job unless the leader picks again
	end)
end

-- Sitting in a friend's van: the crew size cap and the friend rule are VanRules.canSit's; this seats the player.
local function sitIn(player: Player, vanCrew: Crew, bay: number, joining: boolean)
	if joining then
		joinCrew(player, vanCrew) -- sitting in a friend's van IS joining their crew
		push(vanCrew.leader, "Toast", { text = player.DisplayName .. " sat in your van!" })
	end
	local seatIndex = table.find(vanCrew.members, player)
	if seatIndex then
		renderVan(vanCrew) -- the seat exists before it is marked
		VanRules.markSeated(vans, bay, player.UserId, true)
		Vans.seat(player, bay, seatIndex)
	end
	renderVan(vanCrew)
end

---------------------------------------------------------------------------
-- Quick Crew (Config.Hideout.QUICK; Shared/Heist/QuickCrew): strangers only through this opt-in (MASTERPLAN §3.3)
---------------------------------------------------------------------------

local function quickOn(): boolean
	return lobbyOn() and LiveFlags.isOn("quickCrew")
end

-- Studs from a player's root to the crew sign (nil = no sign or no character).
local function signDist(player: Player): number?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local sign = Lobby.anchor("CrewSign")
	if not (root and root:IsA("BasePart") and sign) then
		return nil
	end
	return (root.Position - sign.Position).Magnitude
end

-- May this player look for a crew right now? A solo crew in the hideout: nobody else in it, not on or leaving for
-- a heist, not sitting in a van, not hosting an open van.
local function quickEligible(player: Player): (boolean, string)
	local crew = crewOf[player]
	if player.Parent ~= Players or not crew or preparing[player] then
		return false, "Busy"
	end
	if crew.instance or crew.departing or instanceOf(player) ~= nil then
		return false, "Busy"
	end
	if crewSize(crew) > 1 then
		return false, "NeedSolo"
	end
	local v = VanRules.vanOfCrew(vans, crew.id)
	if v and v.open then
		return false, "Hosting"
	end
	if v and (v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away) then
		return false, "Busy"
	end
	return true, "Ok"
end

-- The vans open to Quick Crew this pass: CREW mode, open, their crew in the hideout.
local function openVans(): { QuickCrew.OpenVan }
	local out = {}
	for bay, v in vans.vans do
		if v.open and v.mode == VanRules.MODE.Crew then
			local crew = crewById(v.crewId)
			if crew and crew.instance == nil and crew.departing == nil and #crew.members > 0 then
				local blocked: { [number]: boolean } = {}
				for uid in v.kicked or {} do
					blocked[uid] = VanRules.isKicked(v, uid, os.clock()) or nil
				end
				table.insert(out, {
					bay = bay,
					crewSize = crewSize(crew),
					openedAt = v.openedAt,
					leaderId = crew.leader.UserId,
					size = VanRules.capOf(v), -- PARTY: never past the crew size
					blocked = blocked,
				})
			end
		end
	end
	return out
end

local function quickToast(player: Player, key: string)
	push(player, "Toast", { text = Strings.QUICK_TOAST[key] or key })
end

-- One matching pass (every MATCH_EVERY seconds and after each change): seekers who are no longer solo (a friend
-- joined, they left) drop out; lapsed holds queue again; open vans with room receive the longest-waiting seekers.
local function quickPass()
	if not quickOn() then
		for uid in table.clone(quick.seekers) do
			QuickCrew.drop(quick, uid)
			local p = Players:GetPlayerByUserId(uid)
			if p then
				quickAttrs(p)
				quickToast(p, "paused")
			end
		end
		return
	end
	for uid in table.clone(quick.seekers) do
		local p = Players:GetPlayerByUserId(uid)
		if not p or not quickEligible(p) then
			QuickCrew.drop(quick, uid)
			if p then
				quickAttrs(p)
			end
		end
	end
	local open = openVans()
	local res = QuickCrew.pass(quick, open, os.clock())
	local touched: { [number]: boolean } = {}
	for _, m in res.matched do
		local p = Players:GetPlayerByUserId(m.userId)
		local v = VanRules.van(vans, m.bay)
		local crew = v and crewById(v.crewId)
		if p then
			quickAttrs(p)
			quickToast(p, "matched")
		end
		if crew then
			quickToast(crew.leader, "coming")
		end
		touched[m.bay] = true
	end
	for _, uid in res.requeued do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			quickAttrs(p)
			quickToast(p, "lapsed")
		end
	end
	for _, uid in res.dropped do
		local p = Players:GetPlayerByUserId(uid)
		if p then
			quickAttrs(p)
			quickToast(p, "away")
		end
	end
	-- the vans' Held counts and the sheet's status line
	for _, v in vans.vans do
		local held = QuickCrew.heldIn(quick, v.bay)
		local rig = Vans.folder() and (Vans.folder() :: Folder):FindFirstChild("Van" .. v.bay)
		if touched[v.bay] or (rig and rig:GetAttribute("Held") ~= held) then
			renderVan(crewById(v.crewId))
		end
	end
	local folder = Vans.folder()
	if folder then
		local waiting, rooms = QuickCrew.counts(quick, open)
		folder:SetAttribute("QuickWaiting", waiting)
		folder:SetAttribute("QuickOpen", rooms)
	end
end
quickPassFn = quickPass

-- A quick / open / style op: one per COOLDOWN seconds per player (the remote's Net rate limit comes first).
local function lobbyOpTooSoon(player: Player): boolean
	local now = os.clock()
	local last = lastLobbyOp[player]
	if last and now - last < HD.QUICK.COOLDOWN then
		return true
	end
	lastLobbyOp[player] = now
	return false
end

-- Heist.Ready { op = "quick" | "unquick" | "open" | "shut", bay? } (validated shape). Everything checked here.
local function quickAction(player: Player, crew: Crew, op: string, bay: number)
	local uid = player.UserId
	if op == "unquick" then
		if QuickCrew.drop(quick, uid) then
			quickAttrs(player)
			quickToast(player, "stopped")
			quickPass()
		end
		return
	end
	if op == "shut" then
		local ok, code = VanRules.setOpen(vans, bay, crewInfo(crew), uid, false, os.clock(), 0)
		if not ok then
			refused(player, code)
			return
		end
		if code == "Ok" then
			for _, other in QuickCrew.release(quick, bay) do
				local p = Players:GetPlayerByUserId(other)
				if p then
					quickAttrs(p)
					quickToast(p, "gone")
				end
			end
			quickToast(player, "shut")
		end
		renderVan(crew)
		quickPass()
		return
	end
	if not quickOn() then
		quickToast(player, "paused")
		return
	end
	if op == "quick" then
		local d = signDist(player)
		if d == nil or d > HD.QUICK.SIGN_REACH then
			refused(player, "FarSign")
			return
		end
		local ok, code = quickEligible(player)
		if not ok then
			refused(player, code)
			return
		end
		local okIn, codeIn = QuickCrew.optIn(quick, uid, os.clock())
		if okIn and codeIn == "Ok" then
			quickToast(player, "looking")
		end
		quickAttrs(player)
		quickPass()
	elseif op == "open" then
		-- from the crew sign (the Quick Crew sheet) or beside the van
		local d = signDist(player)
		local dv = vanDist(player, bay, "any")
		local near = if d and d <= HD.QUICK.SIGN_REACH then 0 elseif dv then dv else nil
		local ok, code = VanRules.setOpen(vans, bay, crewInfo(crew), uid, true, os.clock(), near)
		if not ok then
			refused(player, code)
			return
		end
		if QuickCrew.drop(quick, uid) then
			quickAttrs(player) -- a host does not look for another crew
		end
		if code == "Ok" then
			quickToast(player, "opened")
		end
		renderVan(crew)
		pushGarage(crew)
		quickPass()
	end
end

-- The job board in the hideout: the leader's pick (Heist.SelectLevel / SelectDaily, validated by the caller) is
-- pinned for the crew's next departure; the van starts it. False = not the hideout (the results card's REPLAY /
-- NEXT, the lobby off): the caller starts the heist as before.
local function pinJob(player: Player, job: { index: number, day: number? }): boolean
	if not lobbyOn() then
		return false
	end
	local crew = crewOf[player]
	if not crew or crew.instance ~= nil then
		return false
	end
	if crew.leader ~= player then
		push(player, "Toast", { text = "Your crew leader picks the job." })
		return true
	end
	if crew.departing then
		return true
	end
	crew.job = { index = job.index, day = job.day }
	local name = if job.index == Protocol.DAILY_INDEX then Strings.DAILY_VAULT else nil
	local spec = Catalog[job.index]
	if spec then
		name = spec.name
	end
	push(player, "Toast", { text = if vanBayOf(crew) then Strings.jobPinned(name or "?") else Strings.JOB_PINNED_PICK })
	pushGarage(crew)
	return true
end

-- The PARTY sheet's ops (Config.Hideout.PARTY; Shared/Heist/VanRules setSize / setPrivacy / kick): the leader near
-- their van, one per PARTY.COOLDOWN seconds. Everything checked here again.
local function partyTooSoon(player: Player): boolean
	local now = os.clock()
	local last = lastPartyOp[player]
	if last and now - last < HD.PARTY.COOLDOWN then
		return true
	end
	lastPartyOp[player] = now
	return false
end

-- Heist.Ready { op = "size" | "privacy" | "kick", bay, n } (validated shape and n range).
local function partyAction(player: Player, crew: Crew, op: string, bay: number, n: number)
	if partyTooSoon(player) then
		refused(player, "Slow")
		return
	end
	local uid = player.UserId
	local dist = vanDist(player, bay, "any")
	if op == "size" then
		local ok, code = VanRules.setSize(vans, bay, crewInfo(crew), uid, n, crewSize(crew) + seatsHeld(crew), dist)
		if not ok then
			refused(player, code)
			return
		end
		renderVan(crew)
		quickPass() -- the room for Quick Crew changed
	elseif op == "privacy" then
		local name = VanRules.privacyName(n)
		if name == "open" and not quickOn() then
			quickToast(player, "paused")
			return
		end
		local ok, code = VanRules.setPrivacy(vans, bay, crewInfo(crew), uid, n, os.clock(), dist)
		if not ok then
			refused(player, code)
			return
		end
		if name == "open" then
			if QuickCrew.drop(quick, uid) then
				quickAttrs(player) -- a host does not look for another crew
			end
			if code == "Ok" then
				quickToast(player, "opened")
			end
		else
			-- closed to strangers: their held seats go back (they queue again at once)
			for _, other in QuickCrew.release(quick, bay) do
				local p = Players:GetPlayerByUserId(other)
				if p then
					quickAttrs(p)
					quickToast(p, "gone")
				end
			end
		end
		renderVan(crew)
		pushGarage(crew)
		quickPass()
	elseif op == "kick" then
		local ok, code, kickedId = VanRules.kick(vans, bay, crewInfo(crew), uid, n, os.clock(), dist)
		if not ok or kickedId == nil then
			refused(player, code)
			return
		end
		local target = Players:GetPlayerByUserId(kickedId)
		if target and crewOf[target] == crew then
			-- back in the lobby as a solo crew, stepped out beside the van (leaveCrew unseats them outside the door)
			leaveCrew(target)
			newCrew(target)
			push(target, "Sync", garageState(target))
			push(target, "Toast", { text = Strings.PARTY_KICKED })
			push(player, "Toast", { text = Strings.partyKickedLeader(target.DisplayName) })
		end
		renderVan(crew)
		quickPass()
	end
end

-- One lobby action from a player (validated shape: VanRules.validAction). Everything is checked here again.
local function lobbyAction(player: Player, a: { [string]: any })
	if not lobbyOn() or preparing[player] or instanceOf(player) ~= nil then
		return
	end
	local crew = crewOf[player]
	if not crew or crew.instance or crew.departing then
		return
	end
	local op: string = a.op
	local bay: number = a.bay or 0
	local uid = player.UserId
	local info = crewInfo(crew)
	if op == "quick" or op == "unquick" or op == "open" or op == "shut" or op == "style" then
		if op ~= "unquick" and lobbyOpTooSoon(player) then
			refused(player, "Slow")
			return
		end
	end
	if op == "quick" or op == "unquick" or op == "open" or op == "shut" then
		quickAction(player, crew, op, bay)
		return
	end
	if op == "size" or op == "privacy" or op == "kick" then
		partyAction(player, crew, op, bay, a.n)
		return
	end
	if op == "claim" then
		local old = vanBayOf(crew)
		-- the van wears the leader's saved style (profile vanStyle, published as the VanStyle attribute)
		local style = VanRules.styleIndex(player:GetAttribute("VanStyle"))
		local ok, code = VanRules.claim(vans, bay, info, uid, vanDist(player, bay, "any"), style)
		if not ok then
			refused(player, code)
			return
		end
		if old and old ~= bay then
			Vans.render(old, nil, {})
		end
		pushGarage(crew)
	elseif op == "paint" then
		local ok, code = VanRules.setPaint(vans, bay, uid, a.n, vanDist(player, bay, "paint"))
		if not ok then
			refused(player, code)
			return
		end
		renderVan(crew)
	elseif op == "style" then
		local ok, code = VanRules.setStyle(vans, bay, uid, a.n, vanDist(player, bay, "style"))
		if not ok then
			refused(player, code)
			return
		end
		-- saved per player (an additive profile field, Schema.validVanStyle); offline data just skips the save
		local s = HD.VAN.STYLES[a.n]
		if s and DataService ~= nil and dataReady(player) then
			pcall(DataService.setVanStyle, player, s.id)
		elseif s then
			player:SetAttribute("VanStyle", s.id)
		end
		renderVan(crew)
	elseif op == "crew" or op == "park" then
		local mode = if op == "crew" then VanRules.MODE.Crew else VanRules.MODE.Parked
		local ok, code = VanRules.setMode(vans, bay, info, uid, mode, vanDist(player, bay, "door"))
		if not ok then
			refused(player, code)
			return
		end
		renderVan(crew)
		if op == "park" then
			quickPass() -- a parked van is closed to Quick Crew: its held seats go back
		end
	elseif op == "solo" or op == "go" then
		local ok, code = VanRules.canGo(vans, bay, info, uid, vanDist(player, bay, "cab"), op == "solo")
		if not ok then
			refused(player, code)
			return
		end
		depart(crew, bay, player)
	elseif op == "sit" then
		local v = VanRules.van(vans, bay)
		local vanCrew = v and crewById(v.crewId)
		if not v or not vanCrew then
			refused(player, "NoVan")
			return
		end
		local friend = false
		if vanCrew ~= crew and QuickCrew.holdOf(quick, uid) ~= bay then
			local leaderId = vanCrew.leader.UserId
			local okF, isFriend = pcall(function()
				return player:IsFriendsWithAsync(leaderId)
			end)
			friend = okF and isFriend == true
			-- re-check everything after the yield
			local now = VanRules.van(vans, bay)
			if
				player.Parent ~= Players
				or crewOf[player] == nil
				or instanceOf(player) ~= nil
				or not now
				or crewById(now.crewId) ~= vanCrew
				or vanCrew.leader.UserId ~= leaderId
			then
				return
			end
		end
		local mine = crewOf[player] :: Crew
		-- a Quick Crew seat held for you in this van (only while it is open: VanRules.canSit checks that too)
		local quickSeat = vanCrew ~= crew and QuickCrew.holdOf(quick, uid) == bay and quickOn()
		-- seats held for OTHER matched players count as taken (a friend never takes one)
		local held = QuickCrew.heldIn(quick, bay, uid)
		local ok, code = VanRules.canSit(vans, bay, {
			userId = uid,
			crewId = mine.id,
			friend = friend,
			quick = quickSeat,
			invited = vanCrew ~= crew and invitedBy(player, vanCrew.leader),
			kicked = vanCrew ~= crew and VanRules.isKicked(v, uid, os.clock()),
		}, crewSize(vanCrew) + held, vanDist(player, bay, "door"))
		if not ok then
			refused(player, code)
			return
		end
		if code == "Join" and not friend then
			-- the Quick Crew walk-in: sitting joins the crew (the seeker is solo: quickEligible)
			if not quickEligible(player) then
				refused(player, "NeedSolo")
				return
			end
			QuickCrew.drop(quick, uid)
			quickAttrs(player)
			sitIn(player, vanCrew, bay, true)
			quickToast(player, "joined")
			track("quickCrewJoined", player, crewSize(vanCrew))
			quickPass()
			return
		end
		if code == "Join" and not LiveFlags.isOn("joinFriend") then
			push(player, "Toast", { text = "Joining crews is paused right now." })
			return
		end
		sitIn(player, vanCrew, bay, code == "Join")
		if code == "Join" and QuickCrew.drop(quick, uid) then
			quickAttrs(player) -- sat in a friend's van: no longer looking
		end
	elseif op == "ready" or op == "unready" then
		local v = VanRules.vanOfCrew(vans, crew.id)
		if not v then
			return
		end
		local ok, code = VanRules.setReady(vans, v.bay, uid, op == "ready")
		if not ok then
			refused(player, code)
			return
		end
		renderVan(crew)
		if op == "ready" and VanRules.waiting(v) == 0 and #crew.members > 1 then
			push(crew.leader, "Toast", { text = "Everyone is READY: GO from the cab!" })
		end
	elseif op == "stand" then
		local v = VanRules.vanOfCrew(vans, crew.id)
		Vans.unseat(player, true)
		if v then
			VanRules.markSeated(vans, v.bay, uid, false)
			renderVan(crew)
		end
	end
end

-- A seated player left their seat themselves (a jump): out of the side door; the seat stays theirs (not READY).
local function onStoodUp(userId: number, bay: number)
	local player = Players:GetPlayerByUserId(userId)
	local crew = player and crewOf[player]
	local v = VanRules.van(vans, bay)
	if not player or not crew or not v or v.crewId ~= crew.id then
		return
	end
	if v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away then
		return -- the heist start unseats everyone itself
	end
	VanRules.markSeated(vans, bay, userId, false)
	local char = player.Character
	local cf = Vans.besideVan(bay, 1)
	if char and cf then
		char:PivotTo(cf)
	end
	renderVan(crew)
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
	-- Heist.Ready(arg?): arg = the reduced-motion flag ("▶ RUN n"), or a hideout lobby action table
	-- { op, bay?, n? } (Shared/Heist/VanRules.validReadyArg: the exact keys, ops and ranges; no new remote names)
	-- { op = "look", n } is the first-person look pitch (Heist/LookSync, at most 10 Hz); everything else still
	-- passes the old Ready limit (RATE.ReadyOps), the remote's own limit being sized for the look.
	local readyOps = RateLimit.new(RATE.ReadyOps.burst, RATE.ReadyOps.perSecond)
	Net.Listen(R.Ready, {
		rate = RATE.Ready,
		args = { VanRules.validReadyArg },
		handler = function(player: Player, arg: any)
			if type(arg) == "table" and arg.op == "look" then
				LookSync.accept(player, player.Character, arg.n, os.clock())
				return
			end
			if not readyOps:Allow(player) then
				return
			end
			if type(arg) == "table" then
				lobbyAction(player, arg)
				return
			end
			local reduced: boolean? = arg
			local inst = instanceOf(player)
			if inst then
				HeistInstance.ready(inst, player.UserId, reduced)
			elseif preparing[player] then
				earlyReady[player] = true -- the boot Ready before the server decided: no intro on that client
			elseif ftuePending[player] then
				ftuePending[player] = nil -- the intro (or the title) is over: L1 now (yields: off the handler)
				task.spawn(startFtueAfterReady, player)
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
			if pinJob(player, { index = index }) then
				return -- the hideout: the job board picks the job, the van starts it
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
			if pinJob(player, { index = Protocol.DAILY_INDEX, day = daily.day }) then
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
			if crewSize(crew) + seatsHeld(crew) >= math.min(Config.Sim.MAX_CREW, crewCap(crew)) then
				push(player, "Toast", { text = "That crew is full." })
				return
			end
			if kickedFrom(crew, player) then
				refused(player, "Kicked")
				return
			end
			joinCrew(player, crew)
			if QuickCrew.drop(quick, player.UserId) then
				quickAttrs(player) -- joined a friend: no longer looking
			end
			push(crew.leader, "Toast", { text = player.DisplayName .. " joined your crew!" })
			if crew.instance then
				push(player, "Toast", { text = "You join at their next heist." })
			elseif lobbyOn() and not crew.departing then
				-- the hideout: a friend who joins takes a seat in the crew's van (its side door opens for them)
				local v = VanRules.vanOfCrew(vans, crew.id)
				if v and v.mode == VanRules.MODE.Parked then
					v.mode = VanRules.MODE.Crew
				end
				if v and v.mode == VanRules.MODE.Crew then
					sitIn(player, crew, v.bay, false)
				end
			end
		end,
	})
	Net.Listen(R.Leave, {
		rate = RATE.Leave,
		args = {},
		handler = function(player: Player)
			HeistService.leave(player)
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

-- The client's boot Ready for a new account in the hideout (the intro or the title is over): the art kit (bounded,
-- usually long loaded by then), then L1. Called off the remote handler (it yields).
startFtueAfterReady = function(player: Player)
	waitForKit()
	if player.Parent ~= Players or not isNewAccount(player) then
		return
	end
	if not tryFtueStart(player) then
		local crew = crewOf[player]
		if crew and not crew.instance then
			task.spawn(retryFtue, player) -- every van out: retry while still new, solo and idle
		end
	end
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
			if crew and crewSize(crew) + seatsHeld(crew) < math.min(Config.Sim.MAX_CREW, crewCap(crew)) then
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
		-- The boot Sync shows "preparing" (the loading card), not the hideout, until the server has read the
		-- profile: a new account's first heist is L1 (§7.5), started by the client's boot Ready (no server hold).
		preparing[player] = true
		-- The profile and the first LiveFlags read (kill switches apply before the first heist) are awaited
		-- side by side, each bounded: a cold server costs the longest wait, not the sum (premium G1: control
		-- within 10 s of the first frame; PresentPlan.serverWait). The art kit is never waited on here: only
		-- the first heist's start waits for it (bounded, from join).
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
			if earlyReady[player] then
				-- the client plays no intro (seen, or off): L1 straight away, as before the hideout
				earlyReady[player] = nil
				while not kitDone do -- started at join, so at most KIT_WAIT_SECONDS from then
					task.wait()
				end
				if tryFtueStart(player) then
					return
				end
				-- Full server (or the player moved on): the hideout now, and retry while new.
				preparing[player] = nil
				push(player, "Sync", syncPayload(player))
				task.spawn(retryFtue, player)
				return
			end
			-- The hideout now (control), the intro over it on the client; its Ready starts L1. No server hold.
			ftuePending[player] = true
		end
		earlyReady[player] = nil
		preparing[player] = nil
		push(player, "Sync", syncPayload(player))
	end)
end

local function onPlayerRemoving(player: Player)
	LookSync.forget(player)
	local crew = crewOf[player]
	local inst = crew and crew.instance
	if inst then
		HeistInstance.removeMember(inst, player.UserId)
	end
	QuickCrew.drop(quick, player.UserId)
	lastLobbyOp[player] = nil
	lastPartyOp[player] = nil
	leaveCrew(player)
	inHeist[player] = nil
	preparing[player] = nil
	ftuePending[player] = nil
	earlyReady[player] = nil
	lastStartBy[player] = nil
	Avatars.release(player)
end

local function step()
	local now = workspace:GetServerTimeNow()
	if os.clock() - lastLobbyCheck >= H.LEAVE.SERVER_CHECK_SECONDS then
		lastLobbyCheck = os.clock()
		local ok, err = pcall(HeistService.checkLobby)
		if not ok then
			warn("[HeistService] checkLobby: " .. tostring(err))
		end
	end
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
		if HD.ENABLED then
			Vans.build(onStoodUp) -- the hideout's van rigs on the warehouse's VanBay anchors
		end
	end
	declareRemotes()
	pcall(HaulBoardService.start) -- the laptop's board folder (empty until today's first untainted haul)
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
	-- Every player is a Rookie (Heist/Characters); an outfit change rebuilds the clone template too.
	Characters.start(function(player: Player)
		task.spawn(Avatars.prepare, player)
	end)
	HeistInstance.setFaceHook(Characters.flashFace)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	RunService.Heartbeat:Connect(step)
	-- Quick Crew matching: a pass every MATCH_EVERY seconds (holds lapse, vans open and fill) besides the passes
	-- that follow each change; an error never stops the loop.
	task.spawn(function()
		while true do
			task.wait(HD.QUICK.MATCH_EVERY)
			local fn = quickPassFn
			if fn and next(quick.seekers) ~= nil then
				local ok, err = pcall(fn)
				if not ok then
					warn("[HeistService] quick crew pass: " .. tostring(err))
				end
			end
		end
	end)
end

-- Quick Crew for tests (engine_smoke: fake members; Luau Execution has no players): the server's own rules state
-- and the pure pass over this server's vans.
function HeistService.quickState(): any
	return quick
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
