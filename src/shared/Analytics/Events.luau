--!strict
-- Analytics/Events: the analytics schema (pure; Lune-tested). MASTERPLAN §7.5, §9.7; docs/ANALYTICS.md.
--
-- Every event name, funnel step, custom field and value set the game may send is declared here,
-- so the dashboard stays readable: Roblox allows up to 100 custom event names per experience,
-- three custom fields per event (string values) and about 8,000 value combinations across them
-- (vault "Analytics and Funnels" §2). Field values come only from the small fixed DOMAINS below;
-- anything else becomes the domain's `other` value, so a crafted launch string or a new level can
-- never explode cardinality. Bucket edges are part of the schema: changing one changes what a
-- dashboard line means, so do it with a new funnel/event version, not silently.
--
--   Events.DOMAINS[name]      { values, other, edges? }   value sets (edges: numeric buckets)
--   Events.CUSTOM[name]       { fields, value, batch, ref } custom events (LogCustomEvent)
--   Events.FUNNELS[name]      { onboarding, steps, fields, requires } funnels (LogOnboarding/FunnelStepEvent)
--   Events.PROGRESSION[path]  { fields }                    progression paths (LogProgression*Event)
--   Events.ECONOMY            currencies, reason -> transaction type / SKU (LogEconomyEvent)
--   Events.fields(domains, values) -> { string }           canonical field values (others mapped)
--   Events.stepNumber(funnel, step) -> number?
--   Events.validateCatalog() -> { string }                 errors (CI asserts none)

local Config = require("../Config")

local A = Config.Analytics
local DATA = Config.Data

export type Domain = {
	values: { string },
	other: string,
	edges: { number }?, -- numeric bucket edges: value < edges[i] -> values[i]; last value is "and above"
	set: { [string]: boolean },
}

export type ValueSpec = { kind: "count" } | { kind: "number", min: number, max: number, unit: string }

export type CustomDef = {
	fields: { string }, -- domain names, at most three (CustomField01..03)
	value: ValueSpec,
	batch: boolean?, -- counts are summed per player and field combination, flushed every minute
	once: string?, -- "session" = at most once per player session
	ref: string,
}

export type FunnelDef = {
	onboarding: boolean, -- true: LogOnboardingFunnelStepEvent (one-time); false: LogFunnelStepEvent
	steps: { string },
	fields: { string }, -- step-1 fields (the dashboard filters on step 1 only)
	requires: { [string]: { string } }?, -- a step is held until these steps were reached
	ref: string,
}

local Events = {}

Events.MAX_FIELDS = 3
Events.MAX_CUSTOM_EVENTS = 100 -- Roblox limit per experience
Events.MAX_COMBINATIONS = 8000 -- Roblox limit on custom field value combinations per event
Events.MAX_FUNNELS = 10 -- the funnel dashboard shows up to ten
Events.MAX_STEPS = 100 -- onboarding steps are 1-100
Events.MAX_VALUE_BYTES = 32
Events.MAX_NAME_BYTES = 40

---------------------------------------------------------------------------
-- Domains
---------------------------------------------------------------------------

local function list(...: string): { string }
	return { ... }
end

local function range(prefix: string, from: number, to: number, width: number?): { string }
	local out = {}
	for i = from, to do
		table.insert(out, prefix .. (if width then string.format("%0" .. width .. "d", i) else tostring(i)))
	end
	return out
end

local function concat(...: { string }): { string }
	local out = {}
	for _, l in { ... } do
		for _, v in l do
			table.insert(out, v)
		end
	end
	return out
end

local function sortedKeys(map: { [string]: any }): { string }
	local out = {}
	for k in map do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

-- Join tags: every value that may appear as the `tag` of a JoinSource (shared/Analytics/JoinSource).
Events.JOIN_TAG_KINDS = table.freeze({
	reel = "reel", -- a SAVE CLIP share (v1|reel|<levelId>)
	player = "player", -- a player-generated share link (v1|share|<levelKey>)
	invite = "invite", -- an in-game invite (v1|inv|...) or ReferredByPlayerId with it
	referral = "referral", -- ReferredByPlayerId (referral link or invite without launch data)
	follow = "follow", -- joined a friend through their profile (Player.FollowUserId)
	party = "party", -- arrived in a Roblox party (Player.PartyId)
	hint = "hint", -- ConfigService acquisition-source hint (EH_AcqSource)
	internal = "internal", -- teleported from another place of this experience
	none = "none", -- nothing recognised: organic (Recommended, search, direct)
	invalid = "invalid", -- launch data present but not ours or not whitelisted
})

local function creatorTags(): { string }
	return range("cr", 1, A.CREATOR_SLOTS, 2)
end

local JOIN_TAGS = concat(A.CHANNEL_TAGS, A.AD_TAGS, creatorTags(), sortedKeys(Events.JOIN_TAG_KINDS))

local LEVELS = concat(DATA.LEVEL_ORDER, list("Daily", "Other"))

local RAW_DOMAINS: { [string]: { values: { string }, other: string, edges: { number }? } } = {
	level = { values = LEVELS, other = "Other" },
	crew = { values = list("solo", "duo", "trio", "quad"), other = "quad" },
	source = {
		values = list("ad", "share", "creator", "clip", "friend", "rfy", "search", "teleport", "organic"),
		other = "organic",
	},
	tag = { values = JOIN_TAGS, other = "invalid" },
	cohort = { values = list("new", "returning", "unknown"), other = "unknown" },
	variant = { values = table.clone(A.VARIANTS), other = A.VARIANTS[1] },
	-- Form factor only: game scripts cannot read the OS (UserInputService:GetPlatform needs the
	-- RobloxScript capability), so the OS split is Roblox's Performance page (shared/PerfSample).
	device = { values = list("phone", "tablet", "desktop", "console", "vr", "other"), other = "other" },
	cause = { values = list("busted", "zapped", "bonk", "blocked", "orphaned", "other"), other = "other" },
	taint = {
		values = list("speed", "teleport", "rise", "nogo", "bounds", "nonfinite", "event", "multi", "other"),
		other = "other",
	},
	outcome = { values = list("complete", "dawn", "left", "abandoned", "aborted", "other"), other = "other" },
	yesno = { values = list("yes", "no"), other = "no" },
	deckOp = { values = list("redo", "redoFrom", "delete", "deleteBusted", "undo"), other = "redo" },
	ftueStep = {
		values = list("FirstPlate", "FirstRewind", "FirstCloneSeen", "FirstBank", "L1Complete", "SwarmSeen"),
		other = "FirstPlate",
	},
	medal = { values = list("Haul", "Crew", "Clean", "Diamond", "Haul1", "Haul2", "Haul3", "other"), other = "other" },
	clipKind = { values = list("video", "screenshot", "other"), other = "other" },
	clipResult = {
		values = list("saved", "shared", "cancelled", "failed", "unsupported", "other"),
		other = "other",
	},
	invite = { values = list("invite", "referral", "party", "follow", "share", "other"), other = "other" },
	hint = { values = list("plate", "beam", "mentor", "ghost", "other"), other = "other" },
	perfTier = { values = list("quality", "balanced", "performance", "minimum", "other"), other = "other" },
	entry = { values = list("van", "results", "garage", "other"), other = "other" },
	category = {
		values = list("style", "paint", "trail", "hat", "bundle", "trophy", "bag", "other"),
		other = "other",
	},
	product = { values = concat(sortedKeys(DATA.Products), list("other")), other = "other" },
	alarmBy = { values = list("live", "clone", "catch", "other"), other = "other" },
	storeStep = { values = list("PromptShown", "PurchaseGranted", "other"), other = "other" },
	vault = { values = concat(range("v", 1, 16, 2), list("other")), other = "other" },
	dailyResult = { values = list("cleared", "failed", "catchup", "other"), other = "other" },
	-- ServerBuild: "pv" .. game.PlaceVersion % 100 (wraps every 100 versions, enough to tell the new
	-- build from the old servers after a publish), "b<BUILD>" where PlaceVersion is 0
	build = { values = concat(range("pv", 0, 99, 2), range("b", 1, 200), list("other")), other = "other" },

	-- Numeric buckets (Events.bucket). Edges follow the §9.7 bars so a median lands on a bar.
	len = { -- session length, seconds (bounce < 60 s; median first session 5 / 10 / 12 / 18 min)
		values = list("<30s", "30-60s", "1-3m", "3-5m", "5-10m", "10-12m", "12-18m", "18-30m", "30-60m", "60m+"),
		edges = { 30, 60, 180, 300, 600, 720, 1080, 1800, 3600 },
		other = "<30s",
	},
	ftueTime = { -- seconds since join (first clone <= 45 s; median first bank <= 60 s)
		values = list("<15s", "15-30s", "30-45s", "45-60s", "60-90s", "90-180s", "3-5m", "5-10m", "10m+"),
		edges = { 15, 30, 45, 60, 90, 180, 300, 600 },
		other = "<15s",
	},
	load = { -- join to control, seconds (healthy <= 10 s, kill > 20 s)
		values = list("<5s", "5-10s", "10-15s", "15-20s", "20-30s", "30s+"),
		edges = { 5, 10, 15, 20, 30 },
		other = "<5s",
	},
	-- Frame time, ms (16.6 = 60 fps target, 33.3 = low-phone ceiling, §6.8). A PerfSample p95 is the
	-- upper edge of its 0.5 ms bin, so the edges sit clear of 16.7 and 33.3 with room for jitter:
	-- "14-18" is the 60 fps class (budget met), "28-36" the 30 fps class (at the ceiling), and 36+
	-- is over the ceiling (36 = Config.Analytics.Perf.SLOW_MS, the governor's slow line).
	ms = {
		values = list("<14", "14-18", "18-28", "28-36", "36-50", "50+"),
		edges = { 14, 18, 28, 36, 50 },
		other = "<14",
	},
	clones = { -- clones on screen / in the heist
		values = list("0", "1-4", "5-8", "9-12", "13-16", "17+"),
		edges = { 1, 5, 9, 13, 17 },
		other = "0",
	},
	runs = { values = list("1", "2", "3", "4-5", "6-8", "9-12", "13+"), edges = { 2, 3, 4, 6, 9, 13 }, other = "1" },
	quality = { -- SavedQualityLevel 0 (automatic) .. 10
		values = list("auto", "q1-3", "q4-6", "q7-10"),
		edges = { 1, 4, 7 },
		other = "auto",
	},
	mem = { -- client memory in use, MB (Stats:GetTotalMemoryUsageMb)
		values = list("<600", "600-1000", "1000-1500", "1500-2500", "2500+"),
		edges = { 600, 1000, 1500, 2500 },
		other = "<600",
	},
	stars = { -- progress band (gates: Big Score 6, Museum 14, Sky Lounge 26, §5.2)
		values = list("s0", "s1-5", "s6-13", "s14-25", "s26+"),
		edges = { 1, 6, 14, 26 },
		other = "s0",
	},
}

local DOMAINS: { [string]: Domain } = {}
for name, raw in RAW_DOMAINS do
	local set = {}
	for _, v in raw.values do
		set[v] = true
	end
	DOMAINS[name] = table.freeze({
		values = table.freeze(table.clone(raw.values)),
		other = raw.other,
		edges = if raw.edges then table.freeze(table.clone(raw.edges)) else nil,
		set = table.freeze(set),
	})
end
Events.DOMAINS = table.freeze(DOMAINS)

---------------------------------------------------------------------------
-- Custom events (LogCustomEvent). Plan list §9.7 first, then the KPI events §9.7 needs.
---------------------------------------------------------------------------

local COUNT: ValueSpec = { kind = "count" }
local function num(min: number, max: number, unit: string): ValueSpec
	return { kind = "number", min = min, max = max, unit = unit }
end

Events.CUSTOM = table.freeze({
	-- §9.7 plan list
	CloneFailed = { fields = { "cause", "level" }, value = COUNT, batch = true, ref = "§9.7, §9.2 #2-3" },
	RedoUsed = { fields = { "deckOp", "level" }, value = COUNT, batch = true, ref = "§9.7, §3.2" },
	UndoUsed = { fields = { "level" }, value = COUNT, batch = true, ref = "§9.7, §3.1" },
	DeleteUsed = { fields = { "deckOp", "level" }, value = COUNT, batch = true, ref = "§3.2 Clone Deck" },
	AlarmTripped = { fields = { "level", "alarmBy" }, value = COUNT, ref = "§9.7, §3.6" },
	AlarmEscaped = { fields = { "level", "crew" }, value = COUNT, ref = "§9.7, §3.6" },
	ClipSaveTapped = { fields = { "clipKind", "level" }, value = COUNT, ref = "§9.7 SAVE CLIP taps / heists" },
	InviteJoined = { fields = { "invite", "cohort" }, value = COUNT, once = "session", ref = "§9.7, §9.3" },
	JoinSource = { fields = { "source", "tag", "cohort" }, value = COUNT, once = "session", ref = "§9.7" },
	QuickCrewJoined = { fields = { "crew", "cohort" }, value = COUNT, ref = "§9.7, §3.3" },
	TaintedRun = { fields = { "taint", "level" }, value = COUNT, batch = true, ref = "§9.7, §8.8" },
	PerfSample = { fields = { "device", "ms", "clones" }, value = num(0, 1000, "p95 ms"), ref = "§9.7, §8.6" },
	-- KPI support (§9.7 table, §10.2 gates)
	SessionEnd = { fields = { "len", "cohort", "source" }, value = num(0, 1440, "minutes"), ref = "bounce, session" },
	SessionSocial = { fields = { "yesno", "crew", "cohort" }, value = COUNT, ref = "sessions with a friend" },
	JoinToControl = { fields = { "load", "device", "cohort" }, value = num(0, 600, "seconds"), ref = "join -> control" },
	FtueTiming = { fields = { "ftueStep", "ftueTime", "source" }, value = num(0, 3600, "seconds"), ref = "§7.5" },
	FtueMinute10 = { fields = { "yesno", "yesno", "source" }, value = COUNT, once = "session", ref = "SwarmSeen by 10" },
	FtueHint = { fields = { "hint", "level", "cohort" }, value = COUNT, batch = true, ref = "§7.5 stuck hints" },
	HeistEnded = { fields = { "level", "outcome", "runs" }, value = num(0, 200, "runs"), ref = "heist funnel" },
	MedalEarned = { fields = { "medal", "level" }, value = COUNT, ref = "§5.2" },
	ClipShareResult = { fields = { "clipResult", "clipKind" }, value = COUNT, ref = "§9.3" },
	InviteSent = { fields = { "invite" }, value = COUNT, batch = true, ref = "§9.3 (prompt opened)" },
	PerfDetail = { fields = { "device", "quality", "mem" }, value = num(0, 1000, "median ms"), ref = "§8.6" },
	PerfStepDown = { fields = { "device", "perfTier" }, value = COUNT, ref = "§6.3, §8.6" },
	DailyVaultPlayed = { fields = { "vault", "dailyResult", "cohort" }, value = COUNT, ref = "§5.3" },
	RelaxedChosen = { fields = { "level", "cohort" }, value = COUNT, ref = "§3.1 Relaxed" },
	RsvpPrompted = { fields = { "yesno" }, value = COUNT, ref = "§9.5 step 6" },
	ReferralQualified = { fields = { "source" }, value = COUNT, once = "session", ref = "§9.3 referral" },
	ServerBuild = { fields = { "build" }, value = COUNT, ref = "§8.12 rollout check (once per server)" },
	-- a prompt or receipt with no open store_v1 session (an upsell outside the store, a receipt
	-- replayed after a rejoin): logged here, so it never opens a funnel session at step 3 or 4
	OutOfStorePurchase = { fields = { "storeStep", "product", "cohort" }, value = COUNT, ref = "§5.4 store funnel" },
} :: { [string]: CustomDef })

---------------------------------------------------------------------------
-- Funnels
---------------------------------------------------------------------------

Events.ONBOARDING = "onb_v2"

Events.FUNNELS = table.freeze({
	-- §7.5: one-time, server-only, forward-only. Order matches HeistService.FTUE_STEPS (the saved
	-- profile ftueStep index), asserted by tests/unit/AnalyticsEvents.spec.luau.
	onb_v2 = {
		onboarding = true,
		steps = {
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
		},
		fields = { "source", "tag", "variant" },
		-- Roblox counts skipped steps as complete, so a slow player's Minute10 would mark SwarmSeen
		-- (the §9.7 KPI) as done. Minute10 therefore waits for SwarmSeen (decision, docs/ANALYTICS.md).
		requires = { Minute10 = { "SwarmSeen" } },
		ref = "§7.5",
	},
	-- One session per heist attempt (session id = the server's heistId).
	heist_v1 = {
		onboarding = false,
		steps = { "HeistStarted", "FirstRewind", "FirstBank", "GoalMet", "HeistComplete", "ResultsShown", "NextHeist" },
		fields = { "level", "crew", "source" },
		ref = "§9.7 per-heist funnel",
	},
	store_v1 = {
		onboarding = false,
		steps = { "StoreOpened", "ItemViewed", "PromptShown", "PurchaseGranted" },
		fields = { "entry", "cohort", "source" },
		ref = "§5.4, vault shop funnel",
	},
	clip_v1 = {
		onboarding = false,
		steps = { "ResultsShown", "ClipTapped", "ClipCaptured", "ClipKept" },
		fields = { "level", "crew", "source" },
		ref = "§9.3, §9.7 SAVE CLIP",
	},
	-- D1 / D7 split by JoinSource (§9.7): one stable session per player ("r<userId>"), step 1 on the
	-- first-seen UTC day carries the source; step 2 on day +1 (or +7). Funnels cohort by entry date.
	ret_d1 = {
		onboarding = false,
		steps = { "FirstDay", "ReturnedD1" },
		fields = { "source", "tag", "variant" },
		ref = "§9.7 D1 by JoinSource",
	},
	ret_d7 = {
		onboarding = false,
		steps = { "FirstDay", "ReturnedD7" },
		fields = { "source", "tag", "variant" },
		ref = "§9.7 D7 by JoinSource",
	},
} :: { [string]: FunnelDef })

-- Progression paths (LogProgressionStart/Complete/FailEvent). Heist levels use their index in
-- Config.Data.LEVEL_ORDER; the daily vault uses its design number.
Events.PROGRESSION = table.freeze({
	Heist = { fields = { "crew", "source" } },
	Daily = { fields = { "crew", "source" } },
} :: { [string]: { fields: { string } } })

---------------------------------------------------------------------------
-- Economy (LogEconomyEvent): from Currency.Changed, after the change (vault: log in the wallet)
---------------------------------------------------------------------------

export type EconomyEntry = { transactionType: string, sku: string }

Events.ECONOMY = table.freeze({
	CURRENCIES = table.freeze({ "Cash", "Stars", "CandyCanes" }), -- Roblox tracks up to five
	FIELDS = table.freeze({ "stars", "cohort", "source" }),
	SOURCE_ONLY = table.freeze({ Stars = true }), -- a mirror, never spent: negative deltas are repairs
	IGNORED_REASONS = table.freeze({ load = true }),
})

-- Maps a Currency.Changed reason ("heist:BackRoom", "daily", "buy:Paint_MidnightBlue", "bag",
-- "shop:<key>", "medals") to an Enum.AnalyticsEconomyTransactionType name and a stable SKU.
-- Returns nil for reasons that are not a flow (initial load).
function Events.economyEntry(reason: string): EconomyEntry?
	if Events.ECONOMY.IGNORED_REASONS[reason] then
		return nil
	end
	local head, tail = string.match(reason, "^([%w_]+):([%w_]+)$")
	if head == "heist" and tail then
		local known = table.find(DATA.LEVEL_ORDER, tail) ~= nil
		return { transactionType = "Gameplay", sku = if known then "Heist_" .. tail else "Heist_Other" }
	elseif (head == "buy" or head == "shop") and tail then
		local known = DATA.Cosmetics[tail] ~= nil or DATA.Trophies[tail] ~= nil
		return { transactionType = "Shop", sku = if known then tail else "Other" }
	elseif reason == "daily" then
		return { transactionType = "Gameplay", sku = "DailyVault" }
	elseif reason == "bag" then
		return { transactionType = "Shop", sku = "BagLevel" }
	elseif reason == "medals" then
		return { transactionType = "Gameplay", sku = "Medals" }
	elseif reason == "onboarding" then
		return { transactionType = "Onboarding", sku = "Onboarding" }
	end
	return { transactionType = "Gameplay", sku = "Other" }
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- The canonical value of `value` in a domain: known values pass, numbers are bucketed when the
-- domain has edges, everything else becomes the domain's `other`.
function Events.canon(domainName: string, value: any): string
	local d = DOMAINS[domainName]
	assert(d ~= nil, "Events.canon: unknown domain " .. tostring(domainName))
	if type(value) == "string" and d.set[value] then
		return value
	end
	local edges = d.edges
	if edges and type(value) == "number" and value == value then
		for i, edge in edges do
			if value < edge then
				return d.values[i]
			end
		end
		return d.values[#d.values]
	end
	return d.other
end

-- Bucket a number in a domain with edges (alias of canon for readability at call sites).
function Events.bucket(domainName: string, value: number): string
	return Events.canon(domainName, value)
end

-- Canonical field values for a list of domains and raw values (same order). Missing values
-- become the domain's `other`.
function Events.fields(domains: { string }, values: { any }): { string }
	local out = table.create(#domains)
	for i, domainName in domains do
		out[i] = Events.canon(domainName, values[i])
	end
	return out
end

function Events.stepNumber(funnelName: string, step: string): number?
	local f = Events.FUNNELS[funnelName]
	return if f then table.find(f.steps, step) else nil
end

function Events.cardinality(domains: { string }): number
	local n = 1
	for _, d in domains do
		n *= #DOMAINS[d].values
	end
	return n
end

-- Clamps and rounds a custom event value to its spec (count -> the amount, at least 1).
function Events.value(def: CustomDef, raw: number?): number
	local spec = def.value :: any
	local v = if type(raw) == "number" and raw == raw then raw else 1
	if spec.kind == "count" then
		return math.max(1, math.floor(v))
	end
	return math.clamp(math.floor(v * 10 + 0.5) / 10, spec.min, spec.max)
end

local function checkName(name: string, errors: { string }, what: string)
	if #name > Events.MAX_NAME_BYTES or not string.match(name, "^[%a][%w_]*$") then
		table.insert(errors, what .. " name not short alphanumeric: " .. name)
	end
end

-- Every rule the dashboard limits impose. Returns a list of problems (empty = valid).
function Events.validateCatalog(): { string }
	local errors: { string } = {}
	for name, d in DOMAINS do
		if not d.set[d.other] then
			table.insert(errors, `domain {name}: other '{d.other}' is not one of its values`)
		end
		local seen = {}
		for _, v in d.values do
			if #v == 0 or #v > Events.MAX_VALUE_BYTES then
				table.insert(errors, `domain {name}: value '{v}' empty or longer than {Events.MAX_VALUE_BYTES}`)
			end
			if seen[v] then
				table.insert(errors, `domain {name}: duplicate value '{v}'`)
			end
			seen[v] = true
		end
		if d.edges then
			if #d.edges + 1 ~= #d.values then
				table.insert(errors, `domain {name}: {#d.edges} edges need {#d.edges + 1} values`)
			end
			for i = 2, #d.edges do
				if d.edges[i] <= d.edges[i - 1] then
					table.insert(errors, `domain {name}: edges not increasing`)
				end
			end
		end
	end
	local count = 0
	for name, def in Events.CUSTOM do
		count += 1
		checkName(name, errors, "custom event")
		if #def.fields > Events.MAX_FIELDS then
			table.insert(errors, `{name}: more than {Events.MAX_FIELDS} fields`)
		end
		local known = true
		for _, f in def.fields do
			if not DOMAINS[f] then
				known = false
				table.insert(errors, `{name}: unknown domain {f}`)
			end
		end
		if known and Events.cardinality(def.fields) > Events.MAX_COMBINATIONS then
			table.insert(errors, `{name}: {Events.cardinality(def.fields)} field combinations`)
		end
	end
	if count > Events.MAX_CUSTOM_EVENTS then
		table.insert(errors, `{count} custom event names (limit {Events.MAX_CUSTOM_EVENTS})`)
	end
	local funnels = 0
	for name, f in Events.FUNNELS do
		funnels += 1
		checkName(name, errors, "funnel")
		if #f.steps == 0 or #f.steps > Events.MAX_STEPS then
			table.insert(errors, `funnel {name}: step count {#f.steps}`)
		end
		if #f.fields > Events.MAX_FIELDS then
			table.insert(errors, `funnel {name}: more than {Events.MAX_FIELDS} fields`)
		end
		local known = true
		for _, d in f.fields do
			if not DOMAINS[d] then
				known = false
				table.insert(errors, `funnel {name}: unknown domain {d}`)
			end
		end
		if known and Events.cardinality(f.fields) > Events.MAX_COMBINATIONS then
			table.insert(errors, `funnel {name}: {Events.cardinality(f.fields)} step-1 field combinations`)
		end
		local seen = {}
		for _, s in f.steps do
			checkName(s, errors, `funnel {name} step`)
			if seen[s] then
				table.insert(errors, `funnel {name}: duplicate step {s}`)
			end
			seen[s] = true
		end
		for step, reqs in f.requires or {} do
			for _, r in reqs do
				local a, b = table.find(f.steps, step), table.find(f.steps, r)
				if not a or not b or b >= a then
					table.insert(errors, `funnel {name}: {step} requires {r}, which must be an earlier step`)
				end
			end
		end
	end
	if funnels > Events.MAX_FUNNELS then
		table.insert(errors, `{funnels} funnels (dashboard shows {Events.MAX_FUNNELS})`)
	end
	for path, p in Events.PROGRESSION do
		checkName(path, errors, "progression path")
		for _, d in p.fields do
			if not DOMAINS[d] then
				table.insert(errors, `progression {path}: unknown domain {d}`)
			end
		end
	end
	for _, d in Events.ECONOMY.FIELDS do
		if not DOMAINS[d] then
			table.insert(errors, `economy: unknown domain {d}`)
		end
	end
	for _, c in Events.ECONOMY.CURRENCIES do
		if not DATA.Currencies[c] then
			table.insert(errors, `economy: {c} is not a Config.Data currency`)
		end
	end
	return errors
end

return table.freeze(Events)
