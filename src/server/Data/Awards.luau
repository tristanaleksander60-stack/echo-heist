--!strict
-- Data/Awards: the server's Roblox badge pipeline (BADGES track; docs/marketing/BADGES.md, Shared/Heist/Badges).
--
--   earn(player, key)   server code calls this after a server-decided fact (a heist result, a sim event, the
--                       profile, the boss loop). It writes the profile ledger once (DataService.earnBadge), shows
--                       the in-game BADGE UNLOCKED card through the player attribute BadgeToast, and queues the
--                       Roblox award. A per-player cache answers repeats without touching the profile or the API.
--   the worker          drains the queue on a rate budget (Config.Badges: 50 + 35 x players per minute, half of it
--                       for us): GetBadgeInfoAsync once per badge per server (cached; a disabled badge is skipped),
--                       AwardBadgeAsync in pcall with retries and backoff, and UserHasBadgeAsync after a failure.
--                       Success (or "already owns it") sets badgesSent in the profile, so it is never sent again.
--   ids of 0            a badge not created on Roblox yet: earned and kept in the profile, nothing is called; it is
--                       sent on a later join once tools/badge_upload.py has written its id.
--   joins               DataService.Loaded: badges earned this session before the profile loaded are written,
--                       progress from before badges existed counts (a clear, a daily streak), Welcome is earned,
--                       and every earned-but-unsent badge is queued again.
--   the boss            the experience owner (a user-owned game: game.CreatorId; a group-owned game: the group's
--                       owner) plus Config.Badges.STAFF_USER_IDS. While one is in the server: their Player gets
--                       the attribute Boss = true (every client draws a gold pill over their Rookie) and
--                       ReplicatedStorage.BossUserId = their id (every client shows THE BOSS IS HERE!). Everyone
--                       else adds up time together; BOSS_TOGETHER_SECONDS earns Met the Boss (never the boss).
-- No new remotes: the card and the boss marks replicate as attributes.

local BadgeService = game:GetService("BadgeService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Badges = require(Shared:WaitForChild("Heist"):WaitForChild("Badges"))

local B = Config.Badges

local Awards = {}

-- Everything the pipeline touches outside itself; tests pass fakes (engine_smoke section 16).
export type Deps = {
	data: any?, -- DataService (badgeFacts / earnBadge / markBadgeSent, Loaded, Changed, status); nil = session only
	badgeService: any?, -- BadgeService or a fake with GetBadgeInfoAsync / AwardBadgeAsync / UserHasBadgeAsync
	players: (() -> { any })?, -- the players in the server (default Players:GetPlayers())
	present: ((player: any) -> boolean)?, -- is this player still here (default: parented to Players)
	userIdOf: ((player: any) -> number)?, -- default player.UserId
	idOf: ((key: string) -> number)?, -- badge id for a key (default Badges.idOf)
	ownerId: number?, -- the experience owner (default: resolved from game.CreatorType / CreatorId)
	noLoops: boolean?, -- tests: no worker / boss threads (they call drain / bossStep themselves)
}

type Job = { player: any, key: string, attempts: number, notBefore: number }

local deps: Deps = {}
local api: any = BadgeService
local started = false

local earnedCache: { [any]: { [string]: boolean } } = {}
local sentCache: { [any]: { [string]: boolean } } = {}
local queued: { [any]: { [string]: boolean } } = {}
local queue: { Job } = {}
local toastCount: { [any]: number } = {}
local together: { [any]: number } = {}
local infoCache: { [number]: { enabled: boolean?, at: number } } = {}
local warned: { [number]: boolean } = {}
local windowStart = os.clock()
local spent = 0
local bossIds: { [number]: boolean } = {}
local ownerResolved: number = 0

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function playerList(): { any }
	return if deps.players then deps.players() else Players:GetPlayers()
end

local function isPresent(player: any): boolean
	if deps.present then
		return deps.present(player)
	end
	return typeof(player) == "Instance" and player.Parent == Players
end

local function userIdOf(player: any): number
	if deps.userIdOf then
		return deps.userIdOf(player)
	end
	return player.UserId
end

local function idOf(key: string): number
	return if deps.idOf then deps.idOf(key) else Badges.idOf(key)
end

local function cacheOf(map: { [any]: { [string]: boolean } }, player: any): { [string]: boolean }
	local c = map[player]
	if not c then
		c = {}
		map[player] = c
	end
	return c
end

local function facts(player: any): any
	local data = deps.data
	if not data then
		return nil
	end
	local ok, f = pcall(data.badgeFacts, player)
	return if ok then f else nil
end

-- Shared rate budget (vault: 50 + 35 x users per minute for AwardBadgeAsync and UserHasBadgeAsync).
local function takeBudget(): boolean
	local now = os.clock()
	if now - windowStart >= B.RATE_WINDOW then
		windowStart = now
		spent = 0
	end
	local limit = (B.RATE_BASE + B.RATE_PER_PLAYER * #playerList()) * B.RATE_HEADROOM
	if spent >= limit then
		return false
	end
	spent += 1
	return true
end

-- true / false = enabled or not; nil = unknown (the call failed; asked again after INFO_RETRY_SECONDS).
local function badgeEnabled(id: number): boolean?
	local now = os.clock()
	local c = infoCache[id]
	if c and (c.enabled ~= nil or now - c.at < B.INFO_RETRY_SECONDS) then
		return c.enabled
	end
	local ok, info = pcall(function()
		return api:GetBadgeInfoAsync(id)
	end)
	local enabled: boolean? = nil
	if ok and type(info) == "table" then
		enabled = info.IsEnabled == true
	end
	infoCache[id] = { enabled = enabled, at = now }
	if enabled == false and not warned[id] then
		warned[id] = true
		warn(`[Awards] badge {id} is disabled on Roblox; skipping it`)
	end
	return enabled
end

local function markSent(player: any, key: string)
	cacheOf(sentCache, player)[key] = true
	local data = deps.data
	if data then
		pcall(data.markBadgeSent, player, key)
	end
end

local function enqueue(player: any, key: string)
	if cacheOf(sentCache, player)[key] or cacheOf(queued, player)[key] then
		return
	end
	if idOf(key) == 0 then
		return -- not created yet: kept in the profile, sent on a later join
	end
	cacheOf(queued, player)[key] = true
	table.insert(queue, { player = player, key = key, attempts = 0, notBefore = 0 })
end

local function toast(player: any, key: string)
	local n = (toastCount[player] or 0) + 1
	toastCount[player] = n
	pcall(function()
		player:SetAttribute(Badges.ATTR_TOAST, Badges.toastValue(key, n))
	end)
end

---------------------------------------------------------------------------
-- Earning
---------------------------------------------------------------------------

-- Earns a badge for a player from a server-decided fact. True when this call earned it (the card shows).
function Awards.earn(player: any, key: string): boolean
	if player == nil or not Badges.isKey(key) then
		return false
	end
	local earned = cacheOf(earnedCache, player)
	if earned[key] then
		return false
	end
	local f = facts(player)
	local newly = true
	if f then
		if f.sent[key] then
			cacheOf(sentCache, player)[key] = true
		end
		if f.earned[key] ~= nil then
			newly = false
		else
			local ok, did = pcall(deps.data.earnBadge, player, key)
			newly = ok and did == true
		end
	end
	earned[key] = true
	if newly then
		toast(player, key)
	end
	enqueue(player, key)
	return newly
end

function Awards.hasEarned(player: any, key: string): boolean
	local earned = earnedCache[player]
	if earned and earned[key] then
		return true
	end
	local f = facts(player)
	return f ~= nil and f.earned[key] ~= nil
end

function Awards.wasSent(player: any, key: string): boolean
	local sent = sentCache[player]
	return sent ~= nil and sent[key] == true
end

-- A heist's end for one member (Heist/HeistInstance onOver), and in-run sim events (first clone, 8 OF ME).
function Awards.onHeistOver(player: any, f: Badges.HeistFacts)
	for _, key in Badges.heistBadges(f) do
		Awards.earn(player, key)
	end
end

-- The profile's own facts (a join, a daily vault): progress from before badges existed counts too.
local function fromProfile(player: any)
	local f = facts(player)
	if not f then
		return
	end
	for _, key in Badges.profileBadges(f) do
		Awards.earn(player, key)
	end
end

-- A join (DataService.Loaded): write what this session earned before the profile loaded, then queue the rest.
function Awards.onLoaded(player: any)
	local f = facts(player)
	local session = earnedCache[player]
	if f and session then
		for key in session do
			if f.earned[key] == nil then
				pcall(deps.data.earnBadge, player, key)
			end
		end
		f = facts(player)
	end
	if f then
		for key in f.sent do
			cacheOf(sentCache, player)[key] = true
		end
		for _, key in Badges.pending(f.earned, f.sent) do
			cacheOf(earnedCache, player)[key] = true
			enqueue(player, key)
		end
	end
	Awards.earn(player, "welcome")
	fromProfile(player)
end

---------------------------------------------------------------------------
-- The award worker
---------------------------------------------------------------------------

-- One award attempt. "done" | "retry" | "wait" (no budget or info yet: try the same job later) | "drop".
local function attempt(job: Job): string
	local player = job.player
	if not isPresent(player) then
		return "drop" -- left: the profile keeps it unsent, the next join queues it again
	end
	if cacheOf(sentCache, player)[job.key] then
		return "drop"
	end
	local id = idOf(job.key)
	if id == 0 then
		return "drop"
	end
	local enabled = badgeEnabled(id)
	if enabled == false then
		return "drop"
	elseif enabled == nil then
		return "retry"
	end
	if not takeBudget() then
		return "wait"
	end
	local userId = userIdOf(player)
	local ok, res = pcall(function()
		return api:AwardBadgeAsync(userId, id)
	end)
	if ok and res == true then
		markSent(player, job.key)
		return "done"
	end
	-- Failed or refused: maybe they own it already (an earlier session, or a badge earned outside this ledger).
	if takeBudget() then
		local okHas, has = pcall(function()
			return api:UserHasBadgeAsync(userId, id)
		end)
		if okHas and has == true then
			markSent(player, job.key)
			return "done"
		end
	end
	return "retry"
end

-- Works through the due jobs once. Returns how many were sent. The worker thread calls it; tests call it directly.
function Awards.drain(now: number?): number
	local t = now or os.clock()
	local sentNow = 0
	local keep: { Job } = {}
	local jobs = queue
	queue = {}
	for _, job in jobs do
		if job.notBefore > t then
			table.insert(keep, job)
			continue
		end
		local outcome = attempt(job)
		if outcome == "done" then
			sentNow += 1
			cacheOf(queued, job.player)[job.key] = nil
		elseif outcome == "drop" then
			cacheOf(queued, job.player)[job.key] = nil
		elseif outcome == "wait" then
			table.insert(keep, job)
		else
			job.attempts += 1
			if job.attempts >= B.AWARD_ATTEMPTS then
				cacheOf(queued, job.player)[job.key] = nil -- the next join tries again
			else
				job.notBefore = t + (B.RETRY_SECONDS[job.attempts] or B.RETRY_SECONDS[#B.RETRY_SECONDS])
				table.insert(keep, job)
			end
		end
	end
	for _, job in queue do -- jobs queued while this drain yielded
		table.insert(keep, job)
	end
	queue = keep
	return sentNow
end

function Awards.queued(): number
	return #queue
end

---------------------------------------------------------------------------
-- The boss
---------------------------------------------------------------------------

-- The experience owner's userId: the user for a user-owned game, the group's owner for a group-owned one (0 when
-- it cannot be read, e.g. an unpublished place).
function Awards.resolveOwner(): number
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId
	end
	if game.CreatorType == Enum.CreatorType.Group and game.CreatorId > 0 then
		local ok, info = pcall(function()
			return GroupService:GetGroupInfoAsync(game.CreatorId)
		end)
		local owner = ok and type(info) == "table" and info.Owner
		if type(owner) == "table" and type(owner.Id) == "number" then
			return owner.Id
		end
	end
	return 0
end

function Awards.ownerId(): number
	return ownerResolved
end

function Awards.isBoss(userId: number): boolean
	return bossIds[userId] == true
end

-- Writes the boss attributes from who is here now. Returns the boss present (0 = none).
function Awards.refreshBoss(): number
	local here = 0
	for _, p in playerList() do
		local uid = userIdOf(p)
		local boss = bossIds[uid] == true
		pcall(function()
			p:SetAttribute(Badges.ATTR_BOSS, if boss then true else nil)
		end)
		if boss and here == 0 then
			here = uid
		end
	end
	ReplicatedStorage:SetAttribute(Badges.ATTR_BOSS_HERE, here)
	return here
end

-- Adds dt seconds of time together for every non-boss here while a boss is here; earns Met the Boss.
function Awards.bossStep(dt: number)
	local here = Awards.refreshBoss()
	for _, p in playerList() do
		local isBoss = bossIds[userIdOf(p)] == true
		local after, earnedNow = Badges.bossTick(together[p] or 0, dt, here ~= 0 and not isBoss, isBoss)
		together[p] = after
		if earnedNow then
			Awards.earn(p, "met_the_boss")
		end
	end
end

function Awards.togetherSeconds(player: any): number
	return together[player] or 0
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function forget(player: any)
	earnedCache[player] = nil
	sentCache[player] = nil
	queued[player] = nil
	toastCount[player] = nil
	together[player] = nil
end

-- Boots the pipeline (init.server.luau, sim path). Safe to call again: a later call replaces the deps (tests).
function Awards.start(newDeps: Deps?)
	deps = newDeps or {}
	api = deps.badgeService or BadgeService
	Badges.validate()
	ownerResolved = if deps.ownerId ~= nil then deps.ownerId else Awards.resolveOwner()
	bossIds = Badges.bossIds(ownerResolved, B.STAFF_USER_IDS)
	if deps.noLoops then
		return
	end
	if started then
		return
	end
	started = true
	local data = deps.data
	if data then
		data.Loaded:Connect(function(player: Player)
			Awards.onLoaded(player)
		end)
		data.Changed:Connect(function(player: Player, reason: string)
			if reason == "daily" or reason == "heist" then
				fromProfile(player)
			end
		end)
	end
	-- No data this session (offline Studio): Welcome still shows (session only; Roblox awards need a live server).
	Players.PlayerAdded:Connect(function(player: Player)
		if data == nil or data.status() == "offline" then
			Awards.earn(player, "welcome")
		end
		Awards.refreshBoss() -- the boss's marks at once, not on the next tick
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		forget(player)
		task.defer(Awards.refreshBoss)
	end)
	task.spawn(function()
		while true do
			task.wait(B.WORKER_SECONDS)
			local ok, err = pcall(Awards.drain)
			if not ok then
				warn("[Awards] worker: " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(B.BOSS_TICK_SECONDS)
			local now = os.clock()
			local ok, err = pcall(Awards.bossStep, now - last)
			last = now
			if not ok then
				warn("[Awards] boss: " .. tostring(err))
			end
		end
	end)
	Awards.refreshBoss()
end

-- Tests: drop every cache and job (between fake scenarios).
function Awards.resetForTests()
	table.clear(earnedCache)
	table.clear(sentCache)
	table.clear(queued)
	table.clear(queue)
	table.clear(toastCount)
	table.clear(together)
	table.clear(infoCache)
	spent = 0
end

return Awards
