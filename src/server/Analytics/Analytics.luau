--!strict
-- Analytics/Analytics: the one server-only analytics module (MASTERPLAN §9.7; vault "Analytics and
-- Funnels" §3). A thin adapter over AnalyticsService: the rules live in the pure, Lune-tested
-- ReplicatedStorage.Shared.Analytics.Tracker (funnel order, the join-source gate, batching, budgets,
-- kill switches, session KPIs) and the schema in Shared.Analytics.Events. docs/ANALYTICS.md lists
-- every event, dashboard and the exact call sites.
--
-- Guarantees: every AnalyticsService call is in pcall, analytics never errors into gameplay (every
-- public function swallows its own errors), clients never log directly (they report a few
-- validated, rate-limited facts through Analytics.Ready / Analytics.Perf / Analytics.Ui), field
-- values come only from fixed sets, custom events are batched, and the whole module obeys the
-- LiveFlags kill switches `analytics` and `analyticsCustom`.
--
-- Environments (Data/Keys): Studio never reaches the dashboard (Roblox drops Studio events), so calls
-- are only recorded in memory (Analytics.recent) and printed when Config.Analytics.STUDIO_PRINT is
-- set. The test experience sends (Config.Analytics.SEND_IN_TEST): it has its own dashboard, which is
-- where the early-tester funnel for the Nov 30 gate lives (§9.5). Live sends.
--
-- Server API (all take the Player; anything that is not a real Player is ignored):
--   Analytics.start(opts?)                 idempotent; opts = { dataService, playerData, currency,
--                                          receipts, heistService, shop } binds Loaded,
--                                          Currency.Changed, Receipts.Granted, HeistService.FtueStep
--                                          and Shop.ProductPrompted (when it exists) when given
--   Analytics.onboarding(player, step)     an onb_v2 step (Events.FUNNELS.onb_v2.steps)
--   Analytics.heistStarted(player, info) -> sessionId    info = { heistId, level, crew, friends, daily? }
--   Analytics.heistStep(player, heistId, step)          FirstRewind | FirstBank | GoalMet |
--                                                       HeistComplete | ResultsShown
--   Analytics.heistEnded(player, heistId, outcome, runs) complete | dawn | left | abandoned | aborted
--   Analytics.cloneFailed(player, cause, level)         busted | zapped | bonk | blocked | orphaned
--   Analytics.deck(player, op, level)                   redo | redoFrom | delete | deleteBusted | undo
--   Analytics.alarmTripped(player, level, by)           by = live | clone | catch
--   Analytics.alarmEscaped(player, level, crew)
--   Analytics.taintedRun(player, validatorFlags, level)
--   Analytics.medal(player, medal, level)               Haul | Crew | Clean | Diamond | Haul1-3
--   Analytics.hint(player, kind, level?)                plate | beam | mentor | ghost
--   Analytics.relaxedChosen(player, level), dailyVault(player, vault, result),
--   quickCrewJoined(player, crew), inviteSent(player, kind), rsvp(player, accepted),
--   referralQualified(player), clip(player, action, kind), store(player, step, detail)
--   Analytics.economy(player, currency, delta, balance, reason)   (bindCurrency does this)
--   Analytics.custom(player, eventName, values, value?)           any catalog event
--   Analytics.setPlayerFacts(player, { isNew?, ftueStep?, created? })
--   Analytics.joinSource(player) -> JoinSource.Result?   (routing: JoinSource.requestedLevel)
--   Analytics.launchData(verb, arg, tag?) -> string?      for share/invite/clip prompts
--   Analytics.environment(), stats(), recent(n?), setBackend(fn?), flush()
--
-- Leaving: PlayerRemoving ends the player's session at the end of the same resumption cycle
-- (task.defer), so the other PlayerRemoving handlers (HeistService removeMember -> heistEnded
-- "left") still land in it whichever order Roblox runs them in. After that, a report for that
-- Player is dropped (stats().noSession); it never opens a second session for a departed Player.

local AnalyticsService = game:GetService("AnalyticsService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

assert(RunService:IsServer(), "Analytics is server-only")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local AnalyticsShared = Shared:WaitForChild("Analytics")
local Events = require(AnalyticsShared:WaitForChild("Events"))
local JoinSource = require(AnalyticsShared:WaitForChild("JoinSource"))
local PerfSample = require(AnalyticsShared:WaitForChild("PerfSample"))
local Tracker = require(AnalyticsShared:WaitForChild("Tracker"))
local DataShared = Shared:WaitForChild("Data")
local Calendar = require(DataShared:WaitForChild("Calendar"))
local Keys = require(DataShared:WaitForChild("Keys"))
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))
local LiveFlags = require(script.Parent:WaitForChild("LiveFlags"))

local A = Config.Analytics
local T = Net.T
local IS_STUDIO = RunService:IsStudio()
local IS_TEST = Keys.isTestEnvironment(IS_STUDIO, game.GameId)
local ENV = if IS_STUDIO then "studio" elseif IS_TEST then "test" else "live"
local SEND = ENV == "live" or (ENV == "test" and A.SEND_IN_TEST == true)

export type Record = {
	kind: string,
	name: string,
	step: number?,
	stepName: string?,
	value: number?,
	fields: { string }?,
	userId: number,
	sent: boolean,
}

export type Options = {
	dataService: any?,
	playerData: any?,
	currency: any?,
	receipts: any?,
	heistService: any?,
	shop: any?, -- Data/Shop; its ProductPrompted signal (player, productKey), when it has one
	liveFlags: boolean?, -- false: do not start LiveFlags here
}

local Analytics = {}

local started = false
local tracker: Tracker.Tracker = Tracker.new({
	clock = os.clock,
	flag = function(name: string): any
		return LiveFlags.get(name)
	end,
	placeVersion = game.PlaceVersion,
})
local playersById: { [number]: Player } = {} -- the Player that owns each user's session
local leftAt: { [number]: number } = {} -- PlayerRemoving seen (os.clock)
local leaving: { [number]: boolean } = {} -- PlayerRemoving seen, the session ends at the deferred finish
local joinUnix: { [number]: number } = {}
local recent: { Record } = {}
local backend: ((Tracker.Call, Player) -> ())? = nil
local counters = { executed = 0, failed = 0, noPlayer = 0, suppressed = 0, noSession = 0 }
local lastWarn = -math.huge
local promptHooked = false -- Shop.ProductPrompted is bound: PromptProductPurchaseFinished is not needed

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

---------------------------------------------------------------------------
-- Execution
---------------------------------------------------------------------------

local function isPlayer(p: any): boolean
	return typeof(p) == "Instance" and (p :: Instance):IsA("Player")
end

local function warnThrottled(message: string)
	if os.clock() - lastWarn > A.WARN_EVERY_SECONDS then
		lastWarn = os.clock()
		warn(message)
	end
end

local function safe(what: string, fn: () -> ())
	local ok, err = pcall(fn)
	if not ok then
		warnThrottled(`[Analytics] {what} failed: {err}`)
	end
end

local function toFields(list: { string }?): { [string]: string }?
	if not list then
		return nil
	end
	local out: { [string]: string } = {}
	for i = 1, math.min(#list, Events.MAX_FIELDS) do
		out[FIELD_KEYS[i]] = list[i]
	end
	return out
end

local function remember(call: Tracker.Call, sent: boolean)
	table.insert(recent, {
		kind = call.kind,
		name = call.name,
		step = call.step,
		stepName = call.stepName,
		value = call.value or call.amount,
		fields = call.fields,
		userId = call.pid,
		sent = sent,
	})
	if #recent > A.RECENT_KEPT then
		table.remove(recent, 1)
	end
	if IS_STUDIO and A.STUDIO_PRINT then
		print(
			`[Analytics] {call.kind} {call.name} {call.stepName or ""} {call.value or call.amount or ""}`,
			if call.fields then table.concat(call.fields, "/") else ""
		)
	end
end

local function send(call: Tracker.Call, player: Player)
	local fields = toFields(call.fields)
	if call.kind == "onboarding" then
		AnalyticsService:LogOnboardingFunnelStepEvent(player, call.step :: number, call.stepName, fields)
	elseif call.kind == "funnel" then
		AnalyticsService:LogFunnelStepEvent(player, call.name, call.session, call.step, call.stepName, fields)
	elseif call.kind == "custom" then
		AnalyticsService:LogCustomEvent(player, call.name, call.value or 1, fields)
	elseif call.kind == "economy" then
		local flow = if call.flow == "Sink"
			then Enum.AnalyticsEconomyFlowType.Sink
			else Enum.AnalyticsEconomyFlowType.Source
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			call.name,
			call.amount :: number,
			call.balance :: number,
			call.transactionType :: string,
			call.sku,
			fields
		)
	elseif call.kind == "progression" then
		local level = call.step :: number
		if call.status == "Start" then
			AnalyticsService:LogProgressionStartEvent(player, call.name, level, call.stepName, fields)
		elseif call.status == "Complete" then
			AnalyticsService:LogProgressionCompleteEvent(player, call.name, level, call.stepName, fields)
		else
			AnalyticsService:LogProgressionFailEvent(player, call.name, level, call.stepName, fields)
		end
	end
end

local function execute(calls: { Tracker.Call })
	for _, call in calls do
		local player = playersById[call.pid]
		local willSend = SEND and player ~= nil
		remember(call, willSend or backend ~= nil)
		if not player then
			counters.noPlayer += 1
			continue
		end
		local custom = backend
		if custom then
			safe("backend", function()
				custom(call, player)
			end)
			counters.executed += 1
		elseif willSend then
			local ok, err = pcall(send, call, player)
			if ok then
				counters.executed += 1
			else
				counters.failed += 1
				warnThrottled(`[Analytics] {call.kind} {call.name} failed: {err}`)
			end
		else
			counters.suppressed += 1
		end
	end
end

local function pump()
	Tracker.tick(tracker)
	execute(Tracker.drain(tracker))
	local now = os.clock()
	for pid, at in leftAt do
		if now - at > A.LEFT_KEEP_SECONDS and not leaving[pid] then
			leftAt[pid] = nil
			if not Players:GetPlayerByUserId(pid) then
				playersById[pid] = nil
			end
		end
	end
end

---------------------------------------------------------------------------
-- Joining and leaving
---------------------------------------------------------------------------

local function acquisitionHint(player: Player): string?
	if type(A.ACQ_HINT_KEY) ~= "string" or A.ACQ_HINT_KEY == "" then
		return nil
	end
	local okService, service = pcall(game.GetService, game, "ConfigService")
	if not okService or service == nil then
		return nil
	end
	local ok, value = pcall(function()
		return (service :: any):GetConfigForPlayerAsync(player):GetValue(A.ACQ_HINT_KEY)
	end)
	return if ok and type(value) == "string" then value else nil
end

-- Launch data and ReferredByPlayerId can arrive a few seconds after the join (Roblox docs), so
-- poll GetJoinData up to JOIN_DATA_POLLS times.
local function readJoinFacts(player: Player): JoinSource.JoinFacts
	local data: any = nil
	for i = 1, A.JOIN_DATA_POLLS do
		if player.Parent ~= Players then
			break
		end
		local ok, joinData = pcall(player.GetJoinData, player)
		if ok and type(joinData) == "table" then
			data = joinData
			local launch = joinData.LaunchData
			local referred = joinData.ReferredByPlayerId
			if (type(launch) == "string" and launch ~= "") or (type(referred) == "number" and referred > 0) then
				break
			end
		end
		if i < A.JOIN_DATA_POLLS then
			task.wait(A.JOIN_DATA_POLL_SECONDS)
		end
	end
	local okParty, party = pcall(function(): any
		return (player :: any).PartyId
	end)
	return {
		launchData = if data then data.LaunchData else nil,
		referredBy = if data then data.ReferredByPlayerId else nil,
		sourceGameId = if data then data.SourceGameId else nil,
		followUserId = player.FollowUserId,
		partyId = if okParty and type(party) == "string" then party else nil,
		gameId = game.GameId,
		hint = acquisitionHint(player),
	}
end

-- Ends a departed player's session: SessionEnd, SessionSocial and the batched counts, sent now
-- while the Player is still fresh (the budget permitting).
local function finishLeave(pid: number)
	if not leaving[pid] then
		return
	end
	leaving[pid] = nil
	safe("leave", function()
		Tracker.playerLeft(tracker, pid)
		execute(Tracker.drain(tracker))
	end)
end

local function onJoin(player: Player)
	local pid = player.UserId
	if playersById[pid] == player then
		return -- registered already, or this Player left (a Player object never comes back)
	end
	if leaving[pid] then
		finishLeave(pid) -- a rejoin before the previous session's deferred end
	end
	playersById[pid] = player
	leftAt[pid] = nil
	joinUnix[pid] = os.time()
	Tracker.playerJoined(tracker, pid, os.time())
	task.spawn(function()
		local facts = readJoinFacts(player)
		if playersById[pid] ~= player or leftAt[pid] then
			return -- left (or rejoined) while GetJoinData was polled: the leave resolved it
		end
		local variant = LiveFlags.forPlayer("ftueVariant", player)
		safe("join", function()
			Tracker.setJoin(tracker, pid, JoinSource.classify(facts), variant)
		end)
	end)
end

local function onLeave(player: Player)
	local pid = player.UserId
	if playersById[pid] ~= player or leftAt[pid] then
		return
	end
	leftAt[pid] = os.clock()
	joinUnix[pid] = nil
	leaving[pid] = true
	-- Roblox does not order PlayerRemoving handlers: let the others report first (the end of this
	-- resumption cycle), then end the session
	task.defer(finishLeave, pid)
end

-- True while this Player owns an open session (including the deferred end after PlayerRemoving).
local function sessionOpen(player: Player): boolean
	local pid = player.UserId
	return playersById[pid] == player and (leftAt[pid] == nil or leaving[pid] == true)
end

---------------------------------------------------------------------------
-- Client reports (validated, rate-limited; analytics only, no gameplay effect)
---------------------------------------------------------------------------

-- Analytics.Ui kinds and the domain their argument must come from.
local UI_KINDS: { [string]: string } = {
	ClipTap = "clipKind",
	ClipCaptured = "clipKind",
	ClipSaved = "clipKind",
	ClipShared = "clipKind",
	ClipCancelled = "clipKind",
	ClipFailed = "clipKind",
	ClipUnsupported = "clipKind",
	StoreOpened = "entry",
	StoreItem = "category",
	PerfStepDown = "perfTier",
	Hint = "hint",
	InviteOpened = "invite",
	Rsvp = "yesno",
	FirstMove = "yesno",
}
local CLIP_ACTION: { [string]: string } = {
	ClipTap = "tap",
	ClipCaptured = "captured",
	ClipSaved = "saved",
	ClipShared = "shared",
	ClipCancelled = "cancelled",
	ClipFailed = "failed",
	ClipUnsupported = "unsupported",
}

local function onUi(player: Player, kind: string, arg: string?)
	local domain = UI_KINDS[kind]
	local value = Events.canon(domain, arg)
	local pid = player.UserId
	local action = CLIP_ACTION[kind]
	if action then
		Tracker.clip(tracker, pid, action, value)
	elseif kind == "StoreOpened" then
		Tracker.store(tracker, pid, "StoreOpened", value, true)
	elseif kind == "StoreItem" then
		Tracker.store(tracker, pid, "ItemViewed", value, true)
	elseif kind == "PerfStepDown" then
		Tracker.perfStepDown(tracker, pid, value)
	elseif kind == "Hint" then
		Tracker.hint(tracker, pid, value, nil)
	elseif kind == "InviteOpened" then
		Tracker.inviteSent(tracker, pid, value)
	elseif kind == "Rsvp" then
		Tracker.rsvp(tracker, pid, value == "yes")
	elseif kind == "FirstMove" then
		-- the client saw the first input-driven move (the server cannot tell a walk from a teleport)
		Tracker.onboarding(tracker, pid, "FirstMove")
	end
end

local function declareRemotes()
	local deviceSet = Events.DOMAINS.device.set :: any
	local tierSet = Events.DOMAINS.perfTier.set :: any
	local maxSeconds = 2 * Config.LiveFlags.Flags.perfIntervalSeconds.max
	Net.Listen("Analytics.Ready", {
		rate = A.RATE.Ready,
		args = { T.optional(T.key(deviceSet)) },
		handler = function(player: Player, device: string?)
			Tracker.clientReady(tracker, player.UserId, device)
		end,
	})
	Net.Listen("Analytics.Perf", {
		rate = A.RATE.Perf,
		args = {
			T.number(0, 1000), -- median ms
			T.number(0, 1000), -- p95 ms
			T.number(0, 5000), -- worst ms
			T.integer(0, 1000 * maxSeconds), -- frames
			T.number(0, maxSeconds), -- seconds
			T.key(deviceSet),
			T.integer(0, 10), -- SavedQualityLevel
			T.integer(0, 65535), -- memory MB
			T.integer(0, 64), -- clones on screen
			T.key(tierSet),
		},
		handler = function(player: Player, ...: any)
			local sample = PerfSample.unpack(...)
			if sample then
				Tracker.perf(tracker, player.UserId, sample)
			end
		end,
	})
	Net.Listen("Analytics.Ui", {
		rate = A.RATE.Ui,
		args = { T.key(UI_KINDS :: any), T.optional(T.string(32, "^[%w_]+$")) },
		handler = function(player: Player, kind: string, arg: string?)
			onUi(player, kind, arg)
		end,
	})
end

---------------------------------------------------------------------------
-- Bindings to the data layer and the heist server (optional; see Analytics.start)
---------------------------------------------------------------------------

local function withPlayer(what: string, player: any, fn: (pid: number) -> ())
	if not isPlayer(player) then
		return
	end
	safe(what, function()
		local p = player :: Player
		if not sessionOpen(p) then
			if started and playersById[p.UserId] ~= p and p.Parent == Players then
				onJoin(p) -- a caller whose PlayerAdded handler ran before ours (HeistService "Joined")
			else
				counters.noSession += 1 -- this Player's session already ended (or start never ran)
				return
			end
		end
		fn(p.UserId)
	end)
end

function Analytics.setPlayerFacts(player: Player, facts: { isNew: boolean?, ftueStep: number?, created: number? })
	withPlayer("facts", player, function(pid)
		local offset = Config.Data.Daily.RESET_OFFSET_HOURS
		local created = facts.created
		Tracker.setFacts(tracker, pid, {
			isNew = facts.isNew,
			ftueStep = facts.ftueStep,
			firstSeenDay = if type(created) == "number" then Calendar.dayIndex(created, offset) else nil,
			today = Calendar.dayIndex(os.time(), offset),
		})
	end)
end

local function factsFromData(player: Player, dataService: any, playerData: any?)
	local snap = dataService.getSnapshot(player)
	local heist = if type(snap) == "table" then snap.heist else nil
	local created = if type(snap) == "table" then snap.created else nil
	if created == nil and playerData then
		local okProfile, profile = pcall(playerData.Get, player)
		local meta = if okProfile and type(profile) == "table" then profile.Meta else nil
		created = if type(meta) == "table" then meta.Created else nil
	end
	local joined = joinUnix[player.UserId] or os.time()
	local isNew: boolean
	if type(created) == "number" then
		isNew = created >= joined - A.NEW_PLAYER_GRACE_SECONDS
	else
		isNew = type(heist) == "table" and heist.ftueStep == 0 and (heist.stats and heist.stats.heists or 0) == 0
	end
	Analytics.setPlayerFacts(player, {
		isNew = isNew,
		ftueStep = if type(heist) == "table" then heist.ftueStep else nil,
		created = created,
	})
end

-- DataService.Loaded -> cohort, saved onboarding step, first-seen day (from the snapshot's `created`
-- when DataService provides it, else PlayerData profile Meta.Created, read only).
function Analytics.bindData(dataService: any, playerData: any?)
	dataService.Loaded:Connect(function(player: Player)
		safe("data facts", function()
			factsFromData(player, dataService, playerData)
		end)
	end)
	for _, player in Players:GetPlayers() do
		if dataService.isReady(player) then
			safe("data facts", function()
				factsFromData(player, dataService, playerData)
			end)
		end
	end
end

-- Currency.Changed (player, name, balance, delta, reason): every Cash/Stars/Candy Cane flow, logged
-- after the change from the one place currency changes (vault: log in the wallet).
function Analytics.bindCurrency(changed: any)
	changed:Connect(function(player: Player, name: string, balance: number, delta: number, reason: string)
		Analytics.economy(player, name, delta, balance, reason)
	end)
end

-- Receipts.Granted (player, productKey, receiptInfo): store funnel PurchaseGranted.
function Analytics.bindReceipts(granted: any)
	granted:Connect(function(player: Player, productKey: string)
		Analytics.store(player, "PurchaseGranted", productKey)
	end)
end

-- Shop.ProductPrompted (player, productKey): store funnel PromptShown at the moment Shop.PromptProduct
-- calls MarketplaceService:PromptProductPurchase (the server opens every prompt). Without it the
-- closing prompt (PromptProductPurchaseFinished) stands in, which can arrive after the receipt.
function Analytics.bindShop(prompted: any)
	prompted:Connect(function(player: Player, productKey: string)
		Analytics.store(player, "PromptShown", productKey)
	end)
	promptHooked = true
end

-- HeistService.FtueStep (player, step): the §7.5 steps the heist server sees.
function Analytics.bindFtue(signal: any)
	signal:Connect(function(player: Player, step: string)
		Analytics.onboarding(player, step)
	end)
end

local function productKeyOf(productId: number): string?
	for key, def in Config.Data.Products do
		if def.id ~= 0 and def.id == productId then
			return key
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function Analytics.start(opts: Options?)
	if started then
		return
	end
	started = true
	local o: Options = opts or {}
	if o.liveFlags ~= false then
		safe("LiveFlags.start", LiveFlags.start)
	end
	declareRemotes()
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	-- Fallback for PromptShown until Shop fires ProductPrompted (data layer): the prompt closed, so it
	-- was shown. It can arrive after Receipts.Granted; the funnel then drops it as a backwards step,
	-- which is harmless (a later step counts the earlier ones as complete). Tracker.store never opens
	-- a store session from it.
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number)
		if promptHooked then
			return
		end
		local player = Players:GetPlayerByUserId(userId)
		local key = productKeyOf(productId)
		if player and key then
			Analytics.store(player, "PromptShown", key)
		end
	end)
	if o.dataService then
		safe("bindData", function()
			Analytics.bindData(o.dataService, o.playerData)
		end)
	end
	if o.currency then
		safe("bindCurrency", function()
			Analytics.bindCurrency(o.currency.Changed)
		end)
	end
	if o.receipts then
		safe("bindReceipts", function()
			Analytics.bindReceipts(o.receipts.Granted)
		end)
	end
	if o.heistService then
		safe("bindFtue", function()
			Analytics.bindFtue(o.heistService.FtueStep)
		end)
	end
	local shop = o.shop
	if shop and shop.ProductPrompted then
		safe("bindShop", function()
			Analytics.bindShop(shop.ProductPrompted)
		end)
	end
	game:BindToClose(function()
		local deadline = os.clock() + A.SHUTDOWN_SECONDS
		safe("shutdown", function()
			for pid in leaving do
				leaving[pid] = nil
				Tracker.playerLeft(tracker, pid)
			end
			for _, player in Players:GetPlayers() do
				Tracker.playerLeft(tracker, player.UserId)
			end
			Tracker.flushAll(tracker)
			local calls = Tracker.drainAll(tracker)
			local i = 1
			while i <= #calls and os.clock() < deadline do
				execute({ calls[i] })
				i += 1
			end
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(A.TICK_SECONDS)
			safe("pump", pump)
		end
	end)
end

function Analytics.onboarding(player: Player, step: string)
	withPlayer("onboarding", player, function(pid)
		Tracker.onboarding(tracker, pid, step)
	end)
end

function Analytics.heistStarted(player: Player, info: Tracker.HeistInfo): string?
	local sid: string? = nil
	withPlayer("heistStarted", player, function(pid)
		sid = Tracker.heistStarted(tracker, pid, info)
	end)
	return sid
end

function Analytics.heistStep(player: Player, heistId: string, step: string)
	withPlayer("heistStep", player, function(pid)
		Tracker.heistStep(tracker, pid, heistId, step)
	end)
end

function Analytics.heistEnded(player: Player, heistId: string, outcome: string, runs: number)
	withPlayer("heistEnded", player, function(pid)
		Tracker.heistEnded(tracker, pid, heistId, outcome, runs)
	end)
end

function Analytics.cloneFailed(player: Player, cause: string, level: string)
	withPlayer("cloneFailed", player, function(pid)
		Tracker.cloneFailed(tracker, pid, cause, level)
	end)
end

function Analytics.deck(player: Player, op: string, level: string)
	withPlayer("deck", player, function(pid)
		Tracker.deck(tracker, pid, op, level)
	end)
end

function Analytics.alarmTripped(player: Player, level: string, by: string)
	withPlayer("alarmTripped", player, function(pid)
		Tracker.alarmTripped(tracker, pid, level, by)
	end)
end

function Analytics.alarmEscaped(player: Player, level: string, crew: number)
	withPlayer("alarmEscaped", player, function(pid)
		Tracker.alarmEscaped(tracker, pid, level, crew)
	end)
end

function Analytics.taintedRun(player: Player, flags: number, level: string)
	withPlayer("taintedRun", player, function(pid)
		Tracker.taintedRun(tracker, pid, flags, level)
	end)
end

function Analytics.medal(player: Player, medal: string, level: string)
	withPlayer("medal", player, function(pid)
		Tracker.medal(tracker, pid, medal, level)
	end)
end

function Analytics.hint(player: Player, kind: string, level: string?)
	withPlayer("hint", player, function(pid)
		Tracker.hint(tracker, pid, kind, level)
	end)
end

function Analytics.relaxedChosen(player: Player, level: string)
	withPlayer("relaxedChosen", player, function(pid)
		Tracker.relaxedChosen(tracker, pid, level)
	end)
end

function Analytics.dailyVault(player: Player, vault: number, result: string)
	withPlayer("dailyVault", player, function(pid)
		Tracker.dailyVault(tracker, pid, vault, result)
	end)
end

function Analytics.quickCrewJoined(player: Player, crew: number)
	withPlayer("quickCrewJoined", player, function(pid)
		Tracker.quickCrewJoined(tracker, pid, crew)
	end)
end

function Analytics.inviteSent(player: Player, kind: string)
	withPlayer("inviteSent", player, function(pid)
		Tracker.inviteSent(tracker, pid, kind)
	end)
end

function Analytics.rsvp(player: Player, accepted: boolean)
	withPlayer("rsvp", player, function(pid)
		Tracker.rsvp(tracker, pid, accepted)
	end)
end

function Analytics.referralQualified(player: Player)
	withPlayer("referralQualified", player, function(pid)
		Tracker.referralQualified(tracker, pid)
	end)
end

function Analytics.clip(player: Player, action: string, kind: string)
	withPlayer("clip", player, function(pid)
		Tracker.clip(tracker, pid, action, kind)
	end)
end

function Analytics.store(player: Player, step: string, detail: string?)
	withPlayer("store", player, function(pid)
		Tracker.store(tracker, pid, step, detail)
	end)
end

function Analytics.economy(player: Player, currency: string, delta: number, balance: number, reason: string)
	withPlayer("economy", player, function(pid)
		local stars = player:GetAttribute("Stars")
		Tracker.economy(tracker, pid, currency, delta, balance, reason, if type(stars) == "number" then stars else 0)
	end)
end

function Analytics.custom(player: Player, eventName: string, values: { any }?, value: number?)
	withPlayer("custom", player, function(pid)
		Tracker.custom(tracker, pid, eventName, values, value)
	end)
end

function Analytics.joinSource(player: Player): JoinSource.Result?
	if not isPlayer(player) then
		return nil
	end
	return Tracker.joinOf(tracker, player.UserId)
end

function Analytics.launchData(verb: string, arg: string, tag: string?): string?
	return (JoinSource.build(verb, arg, tag))
end

function Analytics.environment(): string
	return ENV
end

function Analytics.stats(): { [string]: any }
	local s: { [string]: any } = Tracker.stats(tracker) :: any
	for k, v in counters do
		s[k] = v
	end
	s.backlog = Tracker.backlog(tracker)
	s.env = ENV
	s.sending = SEND
	return s
end

-- The last calls (newest last), for Studio checks and the engine smoke test.
function Analytics.recent(n: number?): { Record }
	local count = math.min(n or #recent, #recent)
	return table.move(recent, #recent - count + 1, #recent, 1, {})
end

-- Replaces AnalyticsService with fn(call, player) (engine smoke, debug); nil restores it.
function Analytics.setBackend(fn: ((Tracker.Call, Player) -> ())?)
	backend = fn
end

-- Flushes batches and sends what the budget allows now.
function Analytics.flush()
	safe("flush", function()
		Tracker.flushAll(tracker)
		execute(Tracker.drain(tracker))
	end)
end

return Analytics
