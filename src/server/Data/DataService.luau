--!strict
-- DataService: Echo Heist's data layer, wired on top of the lihfolk-systems modules
-- in this folder (installed as-is). MASTERPLAN §5, §8.7, §8.8; docs/DATA.md.
--
--   PlayerData  session-locked profile, token-fenced saves, autosave, BindToClose
--   Currency    Cash, Stars (mirror of medal stars, never spent), CandyCanes
--   Receipts    the ONLY ProcessReceipt; idempotent on PurchaseId, saved first
--   Shop        Robux product prompts (prompt-time checks); no soft items there
--   Policy      PolicyService cache (fail closed); needed by Shop
-- Pure rules live in ReplicatedStorage.Shared.Data (Schema, Progress, DailyVault,
-- Store, Keys, Calendar) and are unit-tested in Lune.
--
-- Server API (for the heist server; every call validates, then mutates with no yield):
--   DataService.start()                                   idempotent; init.server.luau calls it
--   DataService.awardHeistResult(player, levelId, result, opts?) -> Net.Result (data = AwardSummary;
--                                                         opts.crew: co-op carry on a locked level)
--   DataService.awardDailyVault(player, vaultDay, result, startedDay?) -> Net.Result (DailySummary)
--   DataService.grantTrophy(player, trophyId, reason)     -> Net.Result
--   DataService.grantCosmetic(player, cosmeticId, reason) -> Net.Result (free grants only)
--   DataService.earnCash / spendCash / earnCandyCanes(player, amount, reason) -> boolean
--   DataService.isLevelUnlocked, getBagLevel, getSettings, getSnapshot, setFtueStep,
--   setPromptsBlocked (no store prompt during a heist or a bust), setLevelResolver
-- Client remotes (Net: rate limit + per-argument validation): Data.Snapshot,
--   Data.SetSetting, Data.Equip, Data.Buy, Data.BuyBagLevel, Data.SetShelf; push
--   Data.Changed. Library: Shop.PromptProduct (+ Shop.Buy/PromptPass, empty here).
--
-- No data, still playable: in Studio without API access (or an unpublished place)
-- the service goes "offline": nobody is kicked, nothing is saved, awards return
-- NotReady and the heist plays on. Live servers never go offline silently.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LihFolk = ReplicatedStorage:WaitForChild("LihFolk")
local Net = require(LihFolk:WaitForChild("Net"))
local Signal = require(LihFolk:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local DataShared = Shared:WaitForChild("Data")
local Calendar = require(DataShared:WaitForChild("Calendar"))
local DailyVault = require(DataShared:WaitForChild("DailyVault"))
local Keys = require(DataShared:WaitForChild("Keys"))
local Progress = require(DataShared:WaitForChild("Progress"))
local Schema = require(DataShared:WaitForChild("Schema"))
local Store = require(DataShared:WaitForChild("Store"))

local PlayerData = require(script.Parent.PlayerData)
local Policy = require(script.Parent.Policy)
local Currency = require(script.Parent.Currency)
local Receipts = require(script.Parent.Receipts)
local Shop = require(script.Parent.Shop)

local T = Net.T
local IS_STUDIO = RunService:IsStudio()
local DATA = Config.Data

export type Status = "stopped" | "starting" | "online" | "offline"

local DataService = {}
DataService.Loaded = Signal.new() -- (player): profile ready, repaired and published
DataService.Changed = Signal.new() -- (player, reason): after any change to the player's data

local status: Status = "stopped"
local offlineReason: string? = nil
local isTest = Keys.isTestEnvironment(IS_STUDIO, game.GameId)
local levelOrder: { string } = DATA.LEVEL_ORDER
local lookup: Progress.RulesLookup = function(levelId: string): Progress.LevelRules?
	return DATA.Levels[levelId]
end

local promptsBlocked: { [Player]: boolean } = {}
local lastAward: { [Player]: { [string]: number } } = {}
local recentHeists: { [Player]: { string } } = {}
local pendingPush: { [Player]: boolean } = {}
local changedPush: Net.Push? = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function today(): number
	return Calendar.dayIndex(os.time(), DATA.Daily.RESET_OFFSET_HOURS)
end

local function heistOf(profile: PlayerData.Profile): Schema.Heist
	return profile.Data[Schema.SLICE] :: Schema.Heist
end

local function settingAttribute(key: string): string
	return "Setting_" .. string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
end

local function publishAttributes(player: Player, heist: Schema.Heist)
	for key, value in heist.settings do
		player:SetAttribute(settingAttribute(key), value)
	end
	for slot, id in heist.cosmetics.equipped do
		player:SetAttribute("Cosmetic_" .. slot, id)
	end
	player:SetAttribute("BagLevel", heist.bagLevel)
end

-- Stars are a mirror of the medals and daily first clears; this keeps the balance exact.
local function syncStars(player: Player, heist: Schema.Heist)
	local total = Progress.totalStars(heist)
	if Currency.Get(player, "Stars") ~= total then
		Currency.Set(player, "Stars", total, "medals")
	end
end

local function buildSnapshot(player: Player, profile: PlayerData.Profile): { [string]: any }
	local heist = heistOf(profile)
	local day = today()
	return {
		cash = Currency.Get(player, "Cash") or 0,
		stars = Currency.Get(player, "Stars") or 0,
		candyCanes = Currency.Get(player, "CandyCanes") or 0,
		heist = PlayerData.deepCopy(heist),
		today = day,
		dailyVault = DailyVault.vaultFor(day),
		dailyClearedToday = heist.daily.lastClearDay == day,
		streak = DailyVault.currentStreak(heist.daily.lastClearDay, heist.daily.streak, day, DATA.Daily.GRACE_DAYS),
		secondsUntilReset = Calendar.secondsUntilReset(os.time(), DATA.Daily.RESET_OFFSET_HOURS),
		nextBagCost = Store.nextBagCost(heist.bagLevel),
	}
end

local function flushPush(player: Player)
	pendingPush[player] = nil
	local profile = PlayerData.Get(player)
	if profile and changedPush then
		changedPush:Fire(player, buildSnapshot(player, profile))
	end
end

-- After every mutation: mark for saving, refresh attributes, push one snapshot per frame.
local function changed(player: Player, profile: PlayerData.Profile, reason: string)
	PlayerData.MarkDirty(profile)
	publishAttributes(player, heistOf(profile))
	if not pendingPush[player] then
		pendingPush[player] = true
		task.defer(flushPush, player)
	end
	DataService.Changed:Fire(player, reason)
end

-- True while a second award of the same kind would come within MIN_SECONDS_BETWEEN_AWARDS.
local function awardTooSoon(player: Player, kind: string): boolean
	local times = lastAward[player]
	local last = times and times[kind]
	return last ~= nil and os.clock() - last < DATA.MIN_SECONDS_BETWEEN_AWARDS
end

local function markAward(player: Player, kind: string)
	local times = lastAward[player]
	if not times then
		times = {}
		lastAward[player] = times
	end
	times[kind] = os.clock()
end

local function seenHeist(player: Player, heistId: string?): boolean
	if heistId == nil then
		return false
	end
	local list = recentHeists[player]
	if not list then
		list = {}
		recentHeists[player] = list
	end
	if table.find(list, heistId) then
		return true
	end
	table.insert(list, heistId)
	while #list > DATA.RECENT_HEIST_IDS do
		table.remove(list, 1)
	end
	return false
end

local function wholeAmount(amount: any): boolean
	return Progress.isWhole(amount, 1, DATA.Economy.MAX_CASH_PER_HEIST)
end

---------------------------------------------------------------------------
-- Server API
---------------------------------------------------------------------------

function DataService.status(): Status
	return status
end

function DataService.offlineReason(): string?
	return offlineReason
end

function DataService.environment(): { isTest: boolean, keyPrefix: string, storeName: string }
	return {
		isTest = isTest,
		keyPrefix = Keys.profilePrefix(isTest),
		storeName = if IS_STUDIO then `{DATA.STORE_NAME}_STUDIO` else DATA.STORE_NAME,
	}
end

-- Lets the heist server supply medal rules from the level layouts (src/shared/Levels).
-- Call before start(). lookup(levelId) returns Progress.LevelRules or nil.
function DataService.setLevelResolver(newLookup: Progress.RulesLookup, order: { string })
	assert(status == "stopped", "DataService.setLevelResolver must be called before start()")
	for _, levelId in order do
		local rules = newLookup(levelId)
		assert(rules, `DataService: resolver has no rules for {levelId}`)
		Progress.validateRules(levelId, rules)
	end
	lookup = newLookup
	levelOrder = order
end

function DataService.isReady(player: Player): boolean
	return PlayerData.Get(player) ~= nil
end

function DataService.waitForData(player: Player, timeout: number): boolean
	if status == "offline" then
		return false
	end
	return PlayerData.WaitForProfile(player, timeout) ~= nil
end

function DataService.getSnapshot(player: Player): { [string]: any }?
	local profile = PlayerData.Get(player)
	return if profile then buildSnapshot(player, profile) else nil
end

-- Offline (Studio without API access) every level is open, so play tests are never blocked.
function DataService.isLevelUnlocked(player: Player, levelId: string): boolean
	if status == "offline" then
		return lookup(levelId) ~= nil
	end
	local profile = PlayerData.Get(player)
	return profile ~= nil and heistOf(profile).unlocked[levelId] == true
end

function DataService.getBagLevel(player: Player): number
	local profile = PlayerData.Get(player)
	return if profile then heistOf(profile).bagLevel else 0
end

function DataService.getSettings(player: Player): { [string]: boolean }
	local profile = PlayerData.Get(player)
	local settings = if profile then heistOf(profile).settings else Schema.defaultHeist().settings
	return table.clone(settings :: any)
end

-- No store prompt during a heist or on a bust (§5.4); the heist server toggles this.
function DataService.setPromptsBlocked(player: Player, blocked: boolean)
	promptsBlocked[player] = if blocked then true else nil
end

-- opts.crew (heist server only): the member played in a crew whose leader picked the
-- level. A crewmate who has not unlocked it yet still gets the full result, and a clear
-- unlocks it for them (owner rule pending, docs/DATA.md "Co-op carry").
export type AwardOpts = { crew: boolean? }

function DataService.awardHeistResult(
	player: Player,
	levelId: string,
	result: Progress.HeistResult,
	opts: AwardOpts?
): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local rules = if type(levelId) == "string" then lookup(levelId) else nil
	if not rules then
		return Net.fail("UnknownLevel")
	end
	local valid, why = Progress.validateResult(rules, result)
	if not valid then
		warn(`[DataService] awardHeistResult refused for {player.UserId} on {levelId}: {why}`)
		return Net.fail("Invalid", why)
	end
	local heist = heistOf(profile)
	if not heist.unlocked[levelId] and not (opts and opts.crew == true) then
		return Net.fail("Locked")
	end
	if awardTooSoon(player, "heist") then
		return Net.fail("TooFast")
	end
	if seenHeist(player, result.heistId) then
		return Net.fail("Duplicate")
	end
	-- Validated: from here to the return nothing yields.
	markAward(player, "heist")
	local summary = Progress.applyHeistResult(heist, levelId, rules, result, os.time(), levelOrder, lookup)
	if summary.cash > 0 then
		Currency.Add(player, "Cash", summary.cash, `heist:{levelId}`)
	end
	syncStars(player, heist)
	changed(player, profile, "heist")
	return Net.ok(summary)
end

-- startedDay: the server day when the heist began (DailyVault.apply: a vault that runs
-- across the daily reset is judged on the day it started).
function DataService.awardDailyVault(
	player: Player,
	vaultDay: number,
	result: DailyVault.DailyResult,
	startedDay: number?
): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local valid, why = DailyVault.validateResult(result)
	if not valid then
		warn(`[DataService] awardDailyVault refused for {player.UserId}: {why}`)
		return Net.fail("Invalid", why)
	end
	if awardTooSoon(player, "daily") then
		return Net.fail("TooFast")
	end
	local heist = heistOf(profile)
	local summary, reason = DailyVault.apply(heist, vaultDay, today(), result, os.time(), startedDay)
	if not summary then
		return Net.fail(reason or "Invalid")
	end
	markAward(player, "daily")
	if summary.cash > 0 then
		Currency.Add(player, "Cash", summary.cash, "daily")
	end
	if summary.candyCanes > 0 then
		Currency.Add(player, "CandyCanes", summary.candyCanes, "daily")
	end
	syncStars(player, heist)
	changed(player, profile, "daily")
	return Net.ok(summary)
end

function DataService.grantTrophy(player: Player, trophyId: string, reason: string): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	if type(trophyId) ~= "string" or DATA.Trophies[trophyId] == nil then
		return Net.fail("Invalid")
	end
	if not Progress.grantTrophy(heistOf(profile), trophyId, os.time()) then
		return Net.fail("AlreadyOwned")
	end
	changed(player, profile, `trophy:{reason}`)
	return Net.ok({ trophy = trophyId })
end

-- Free grants only (gift beat, season ladder). Paid cosmetics come only from receipts.
function DataService.grantCosmetic(player: Player, cosmeticId: string, reason: string): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	local def = if type(cosmeticId) == "string" then DATA.Cosmetics[cosmeticId] else nil
	if def == nil or def.product ~= nil or def.default then
		return Net.fail("Invalid")
	end
	local heist = heistOf(profile)
	if heist.cosmetics.owned[cosmeticId] then
		return Net.fail("AlreadyOwned")
	end
	heist.cosmetics.owned[cosmeticId] = true
	changed(player, profile, `cosmetic:{reason}`)
	return Net.ok({ cosmetic = cosmeticId })
end

function DataService.earnCash(player: Player, amount: number, reason: string): boolean
	return wholeAmount(amount) and Currency.Add(player, "Cash", amount, reason)
end

function DataService.spendCash(player: Player, amount: number, reason: string): boolean
	return wholeAmount(amount) and Currency.Spend(player, "Cash", amount, reason)
end

-- Candy Canes exist only while the event runs (§5.1).
function DataService.earnCandyCanes(player: Player, amount: number, reason: string): boolean
	return DailyVault.inEvent(today()) and wholeAmount(amount) and Currency.Add(player, "CandyCanes", amount, reason)
end

-- FTUE progress only moves forward.
function DataService.setFtueStep(player: Player, step: number): boolean
	local profile = PlayerData.Get(player)
	if not profile or not Progress.isWhole(step, 0, DATA.MAX_FTUE_STEP) then
		return false
	end
	local heist = heistOf(profile)
	if step > heist.ftueStep then
		heist.ftueStep = step
		changed(player, profile, "ftue")
	end
	return true
end

---------------------------------------------------------------------------
-- Client remotes
---------------------------------------------------------------------------

local function withProfile(player: Player, fn: (PlayerData.Profile, Schema.Heist) -> Net.Result): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	return fn(profile, heistOf(profile))
end

local function declareRemotes()
	local settingKeys = Schema.defaultHeist().settings :: any
	local buyable = Store.buyable()
	changedPush = Net.Push("Data.Changed")

	Net.Handle("Data.Snapshot", {
		rate = { burst = 4, perSecond = 1 },
		args = {},
		handler = function(player: Player): Net.Result
			local snapshot = DataService.getSnapshot(player)
			return if snapshot then Net.ok(snapshot) else Net.fail("NotReady")
		end,
	})
	Net.Handle("Data.SetSetting", {
		rate = { burst = 6, perSecond = 2 },
		args = { T.key(settingKeys), T.boolean },
		handler = function(player: Player, key: string, value: boolean): Net.Result
			return withProfile(player, function(profile, heist)
				local settings = heist.settings :: any
				settings[key] = value
				changed(player, profile, "settings")
				return Net.ok()
			end)
		end,
	})
	Net.Handle("Data.Equip", {
		rate = { burst = 6, perSecond = 2 },
		args = { T.key(DATA.DEFAULT_EQUIPPED), T.key(DATA.Cosmetics) },
		handler = function(player: Player, slot: string, itemId: string): Net.Result
			return withProfile(player, function(profile, heist)
				local ok, code = Store.canEquip(heist, slot, itemId)
				if not ok then
					return Net.fail(code)
				end
				heist.cosmetics.equipped[slot] = itemId
				changed(player, profile, "equip")
				return Net.ok()
			end)
		end,
	})
	Net.Handle("Data.Buy", {
		rate = { burst = 3, perSecond = 1 },
		args = { T.key(buyable) },
		handler = function(player: Player, itemId: string): Net.Result
			return withProfile(player, function(profile, heist)
				local ok, code, price = Store.canBuy(heist, itemId, today(), function(currency: string): number
					return Currency.Get(player, currency) or 0
				end)
				if not ok or not price then
					return Net.fail(code)
				end
				-- Checked; spend and grant in one block with no yield.
				if not Currency.Spend(player, price.currency, price.amount, `buy:{itemId}`) then
					return Net.fail("NotEnough")
				end
				Store.applyBuy(heist, itemId, os.time())
				changed(player, profile, "buy")
				return Net.ok({ item = itemId })
			end)
		end,
	})
	Net.Handle("Data.BuyBagLevel", {
		rate = { burst = 3, perSecond = 1 },
		args = {},
		handler = function(player: Player): Net.Result
			return withProfile(player, function(profile, heist)
				local cost = Store.nextBagCost(heist.bagLevel)
				if not cost then
					return Net.fail("LimitReached")
				end
				if not Currency.Spend(player, "Cash", cost, "bag") then
					return Net.fail("NotEnough")
				end
				heist.bagLevel += 1
				changed(player, profile, "bag")
				return Net.ok({ bagLevel = heist.bagLevel })
			end)
		end,
	})
	Net.Handle("Data.SetShelf", {
		rate = { burst = 3, perSecond = 1 },
		args = { T.array(T.key(DATA.Trophies), DATA.SHELF_SLOTS) },
		handler = function(player: Player, ids: { string }): Net.Result
			return withProfile(player, function(profile, heist)
				local ok, code = Store.validShelf(heist, ids)
				if not ok then
					return Net.fail(code)
				end
				heist.shelf = table.move(ids, 1, #ids, 1, {}) -- a copy, never the client's table
				changed(player, profile, "shelf")
				return Net.ok()
			end)
		end,
	})
end

---------------------------------------------------------------------------
-- Purchases (Robux developer products: fixed cosmetics, one per player)
---------------------------------------------------------------------------

local function configureProducts()
	local products = {}
	for key, def in DATA.Products do
		products[key] = { id = def.id, custom = key, limit = 1 }
	end
	Receipts.Init({ products = products })
	for key in DATA.Products do
		Receipts.SetCustomGrant(key, function(_player: Player, profile: PlayerData.Profile): boolean
			-- Synchronous; Receipts records the PurchaseId in the same write.
			return Store.grantProduct(heistOf(profile), key)
		end)
		Receipts.SetPromptCheck(key, function(player: Player): (boolean, string?)
			if promptsBlocked[player] then
				return false, "Unavailable"
			end
			local profile = PlayerData.Get(player)
			if not profile then
				return false, "NotReady"
			end
			local ok, code = Store.canPromptProduct(heistOf(profile), key, today())
			return ok, if ok then nil else code
		end)
	end
	Receipts.Granted:Connect(function(player: Player, _productKey: string)
		local profile = PlayerData.Get(player)
		if profile then
			changed(player, profile, "purchase")
		end
	end)
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

local function goOffline(reason: string)
	status = "offline"
	offlineReason = reason
	ReplicatedStorage:SetAttribute("DataOffline", true)
	warn(
		`[DataService] OFFLINE: progress is not saved this session ({reason}). In Studio, enable `
			.. "Game Settings > Security > Enable Studio Access to API Services (the place must be published)."
	)
end

local function onLoaded(player: Player, profile: PlayerData.Profile)
	local heist = heistOf(profile)
	local repairs = Schema.sanitize(heist)
	if #repairs > 0 then
		warn(`[DataService] repaired {#repairs} field(s) for {player.UserId}: {table.concat(repairs, ", ")}`)
	end
	Progress.computeUnlocks(heist, levelOrder, lookup) -- gates lowered in a later build open now
	syncStars(player, heist)
	changed(player, profile, "load")
	DataService.Loaded:Fire(player)
end

-- In Studio, prove API access with one read before PlayerData kicks anyone.
local function startStorage()
	if IS_STUDIO then
		if game.GameId == 0 then
			goOffline("the place is not published")
			return
		end
		local ok, err = pcall(function()
			local probe = DataStoreService:GetDataStore(`{DATA.STORE_NAME}_STUDIO`)
			return probe:GetAsync(Keys.profileKey(0, true)) -- never written; a read only
		end)
		if not ok then
			goOffline(tostring(err))
			return
		end
	end
	local ok, err = pcall(PlayerData.Start)
	if not ok then
		goOffline(tostring(err))
		return
	end
	status = "online"
end

-- Boots the data layer. Safe to call more than once (tests call it too).
function DataService.start()
	if status ~= "stopped" then
		return
	end
	status = "starting"
	for _, levelId in levelOrder do
		Progress.validateRules(levelId, assert(lookup(levelId), `DataService: no rules for {levelId}`))
	end
	Store.validateCatalog()

	-- lihfolk-systems wiring order (examples/Main.server.luau).
	PlayerData.Configure({
		storeName = DATA.STORE_NAME,
		schemaVersion = Schema.VERSION,
		migrations = Schema.MIGRATIONS,
		keyPrefix = Keys.profilePrefix(isTest),
		leaseSeconds = DATA.LEASE_SECONDS,
		autosaveSeconds = DATA.AUTOSAVE_SECONDS,
		claimAttempts = DATA.CLAIM_ATTEMPTS,
		lockedRetrySeconds = DATA.LOCKED_RETRY_SECONDS,
		saveAttempts = DATA.SAVE_ATTEMPTS,
		receiptsKept = DATA.RECEIPTS_KEPT,
		purchaseLogKept = DATA.PURCHASE_LOG_KEPT,
	})
	Policy.Init()
	Currency.Init({ currencies = DATA.Currencies })
	configureProducts()
	Shop.Init({ items = {}, passes = {} }) -- Robux prompts only; Cash items go through Data.Buy
	PlayerData.RegisterSlice(Schema.SLICE, Schema.defaultHeist)
	declareRemotes()
	PlayerData.Loaded:Connect(onLoaded)
	Players.PlayerRemoving:Connect(function(player: Player)
		promptsBlocked[player] = nil
		lastAward[player] = nil
		recentHeists[player] = nil
		pendingPush[player] = nil
	end)

	Receipts.Start()
	task.spawn(startStorage)
end

return DataService
