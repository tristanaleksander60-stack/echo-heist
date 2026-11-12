--!strict
-- Heist/HeistService: the sim game path's server (Config.GAME_MODE = "sim").
-- MASTERPLAN §3.3 (garage lobby + one heist instance per party in a shared server),
-- §7.5 (a new account starts L1 at once), §8.2, §8.6, §8.8.
--
--   * Crews: every player starts as a solo crew. Players who arrive in the same Roblox
--     party (Player.PartyId) share a crew; "Join friend" (Heist.JoinFriend) moves you
--     into a friend's crew in this server. Joiners seat at the next heist.
--   * The crew leader picks a level (Heist.SelectLevel); the crew gets its own
--     HeistInstance built 3,000 studs from the others. Up to Config.Heist.MAX_INSTANCES.
--   * Remotes are LihFolk Net (rate limit + per-argument validation); handlers route
--     to the player's instance, and the sim re-validates every intent (§8.5).
--   * Results go to DataService.awardHeistResult with friends and heistId added.
--   * FTUE: HeistService.FtueStep fires (player, step) for the §7.5 funnel steps the
--     server sees; analytics can subscribe. The step index is saved with setFtueStep.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Catalog = require(Shared:WaitForChild("Levels"):WaitForChild("Catalog"))
local Codec = require(Shared:WaitForChild("Rec"):WaitForChild("Codec"))
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local LihFolk = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(LihFolk:WaitForChild("Net"))
local Signal = require(LihFolk:WaitForChild("Signal"))

local HeistInstance = require(script.Parent:WaitForChild("HeistInstance"))
local Avatars = require(script.Parent:WaitForChild("Avatars"))
local Lobby = require(script.Parent:WaitForChild("Lobby"))

local T = Net.T
local H = Config.Heist
local KIND = Codec.EVENT

local HeistService = {}

-- (player, step): a §7.5 funnel step the server saw (Joined, FirstPlate, ...).
HeistService.FtueStep = Signal.new()

-- Funnel order (§7.5 onb_v2) for DataService.setFtueStep; client-only steps are listed
-- so the indices stay stable when the client reports them later.
HeistService.FTUE_STEPS = table.freeze({
	"Joined",
	"FirstMove",
	"FirstPlate",
	"FirstRewind",
	"FirstCloneSeen",
	"FirstBank",
	"L1Complete",
	"ReelShown",
	"L2Started",
	"FirstCloneBusted",
	"SwarmSeen",
	"Minute10",
})

type Crew = {
	id: number,
	leader: Player,
	members: { Player },
	pending: { Player }, -- joined while the crew was mid-heist: seat at the next heist
	instance: any?,
	friends: { [Player]: { [number]: boolean } },
}

local started = false
local DataService: any = nil
local msgPush: Net.Push? = nil
local crewOf: { [Player]: Crew } = {}
local crews: { Crew } = {}
local nextCrewId = 0
local instances: { [number]: any } = {} -- slot -> instance
local crewOfInstance: { [any]: Crew } = {}
local nextInstanceId = 0
local lastError = -math.huge

---------------------------------------------------------------------------
-- Data hooks
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
	rules.cap = math.clamp(math.max(base.cap, Config.Sim.CREW_CLONE_BUDGET), 1, 16)
	return rules
end

-- Call before DataService.start() (init.server.luau does, on the sim path).
function HeistService.configureData(service: any)
	DataService = service
	if service.status() == "stopped" then
		service.setLevelResolver(HeistService.levelRules, Config.Data.LEVEL_ORDER)
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

local function award(player: Player, dataKey: string, data: any): any
	if DataService == nil then
		return nil
	end
	return DataService.awardHeistResult(player, dataKey, data)
end

local function blockPrompts(player: Player, blocked: boolean)
	if DataService ~= nil then
		pcall(DataService.setPromptsBlocked, player, blocked)
	end
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
			name = spec.name,
			par = spec.par,
			cap = spec.cap,
			runSeconds = spec.runSeconds,
			unlocked = isUnlocked(player, i),
			medals = medals,
		})
	end
	return out
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
	}
end

local function syncPayload(player: Player): any
	local crew = crewOf[player]
	local inst = crew and crew.instance
	if inst and inst.byId[player.UserId] and not inst.byId[player.UserId].left then
		return HeistInstance.syncFor(inst, player.UserId)
	end
	return garageState(player)
end

local function pushGarage(crew: Crew)
	for _, p in crew.members do
		if not (crew.instance and crew.instance.byId[p.UserId]) then
			push(p, "Sync", garageState(p))
		end
	end
	for _, p in crew.pending do
		push(p, "Sync", garageState(p))
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
	end
end

-- Friendship flags for the co-op Cash bonus (cached; yields, so run in a thread).
local function learnFriends(crew: Crew, player: Player)
	local known = crew.friends[player] or {}
	crew.friends[player] = known
	for _, other in crew.members do
		if other ~= player and known[other.UserId] == nil then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			known[other.UserId] = ok and isFriend == true
			local back = crew.friends[other] or {}
			crew.friends[other] = back
			back[player.UserId] = known[other.UserId]
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

local function freeSlot(): number?
	for slot = 1, H.MAX_INSTANCES do
		if instances[slot] == nil then
			return slot
		end
	end
	return nil
end

local function originFor(slot: number): Vector3
	return Vector3.new(slot * H.INSTANCE_SPACING, H.INSTANCE_Y, 0)
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
-- { userId, name, fake = {x, y, z, yaw} }). Returns the instance and its slot.
function HeistService.createInstance(
	levelIndex: number,
	members: { any },
	leaderId: number,
	firstHeist: boolean?
): (any, number?)
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
		})
	end
	local inst = HeistInstance.new({
		id = nextInstanceId,
		levelIndex = levelIndex,
		origin = originFor(slot),
		parent = heistFolder(),
		members = list,
		leader = leaderId,
		heistId = string.gsub(HttpService:GenerateGUID(false), "[{}]", ""),
		firstHeist = firstHeist,
		push = push,
		award = award,
		onFtue = ftueHook,
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

local function startHeist(crew: Crew, levelIndex: number): boolean
	if crew.instance then
		return false
	end
	local members = {}
	local firstHeist = false
	for _, p in crew.members do
		table.insert(members, { userId = p.UserId, player = p, name = p.DisplayName, friends = friendsIn(crew, p) })
		local snap = snapshotOf(p)
		if snap and snap.heist and snap.heist.firstHeistDone == false then
			firstHeist = true
		end
	end
	if #members == 0 then
		return false
	end
	local inst = HeistService.createInstance(levelIndex, members, crew.leader.UserId, firstHeist)
	if not inst then
		for _, p in crew.members do
			push(p, "Toast", { text = "The garage is full. Try again in a minute." })
		end
		return false
	end
	crew.instance = inst
	crewOfInstance[inst] = crew
	for _, p in crew.members do
		p:SetAttribute(Protocol.PLAYER_ATTR, inst.name)
		blockPrompts(p, true)
		push(p, "Sync", HeistInstance.syncFor(inst, p.UserId))
		if levelIndex == 2 then
			ftueHook(p, "L2Started")
		end
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
		args = { T.integer(1, #Catalog) },
		handler = function(player: Player, index: number)
			local crew = crewOf[player]
			if not crew or crew.leader ~= player then
				push(player, "Toast", { text = "Your crew leader picks the tape." })
				return
			end
			if not isUnlocked(player, index) then
				push(player, "Toast", { text = "Clear the tape before it first." })
				return
			end
			local inst = crew.instance
			if inst then
				if inst.overAt == nil then
					return -- mid-heist: Leave first
				end
				returnToGarage(crew)
			end
			startHeist(crew, index)
		end,
	})
	Net.Listen(R.JoinFriend, {
		rate = RATE.JoinFriend,
		args = { T.integer(1, 2 ^ 52) },
		handler = function(player: Player, userId: number)
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

local function isNewAccount(player: Player): boolean
	local snap = snapshotOf(player)
	if not snap then
		return true -- offline / not loaded: treat as new so the FTUE path is the default
	end
	local rec = snap.heist and snap.heist.levels and snap.heist.levels[H.LEVEL_DATA_KEYS[Catalog[1].id]]
	return not (rec and (rec.clears or 0) > 0)
end

local function onPlayerAdded(player: Player)
	task.spawn(Avatars.prepare, player)
	player:SetAttribute(Protocol.PLAYER_ATTR, "")
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
		if DataService ~= nil and DataService.status() ~= "offline" then
			DataService.waitForData(player, H.DATA_WAIT_SECONDS)
		end
		if player.Parent ~= Players then
			return
		end
		local crew = crewOf[player]
		if not crew then
			return
		end
		if H.FTUE_AUTOSTART and crew.leader == player and #crew.members == 1 and not crew.instance then
			if isNewAccount(player) then
				startHeist(crew, 1)
				return
			end
		end
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
	Avatars.release(player)
end

local function step()
	local now = workspace:GetServerTimeNow()
	for _, inst in instances do
		local ok, err = pcall(HeistInstance.update, inst, now)
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
	if o.lobby ~= false then
		Lobby.build()
	end
	declareRemotes()
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

return HeistService
