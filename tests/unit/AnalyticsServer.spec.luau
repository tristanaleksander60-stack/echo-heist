-- L1: src/server/Analytics/{Analytics,LiveFlags} loaded in Lune with a fake engine (luau.load with an
-- injected environment): start, joins with launch data, the call shapes AnalyticsService receives,
-- client remotes, economy binding, LiveFlags layers and kill switch, Studio suppression, shutdown,
-- the leave order (another module's PlayerRemoving report after ours) and rejoins.
-- This is a smoke test of the adapter's wiring; the rules themselves are in AnalyticsTracker.spec.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local Config = require("../../src/shared/Config")
local Assert = require("./Assert")

local MODULES: { [string]: any } = {
	Config = Config,
	Events = require("../../src/shared/Analytics/Events"),
	JoinSource = require("../../src/shared/Analytics/JoinSource"),
	PerfSample = require("../../src/shared/Analytics/PerfSample"),
	Tracker = require("../../src/shared/Analytics/Tracker"),
	LiveFlagSpec = require("../../src/shared/Analytics/LiveFlagSpec"),
	Calendar = require("../../src/shared/Data/Calendar"),
	Keys = require("../../src/shared/Data/Keys"),
}

type Fake = { [string]: any }

local function signal(): Fake
	local s: Fake = { handlers = {} }
	function s.Connect(self: Fake, fn: (...any) -> ())
		table.insert(self.handlers, fn)
		return { Disconnect = function() end }
	end
	function s.Fire(self: Fake, ...: any)
		for _, fn in self.handlers do
			fn(...)
		end
	end
	return s
end

local function node(name: string, children: { [string]: any }?, module: string?): Fake
	local n: Fake = { __instance = true, Name = name, children = children or {}, attrs = {}, module = module }
	function n.WaitForChild(self: Fake, child: string): Fake
		local c = self.children[child]
		assert(c ~= nil, `fake WaitForChild: {self.Name} has no {child}`)
		return c
	end
	function n.FindFirstChild(self: Fake, child: string): Fake?
		return self.children[child]
	end
	function n.SetAttribute(self: Fake, k: string, v: any)
		self.attrs[k] = v
	end
	function n.GetAttribute(self: Fake, k: string): any
		return self.attrs[k]
	end
	function n.IsA(self: Fake, class: string): boolean
		return self.className == class
	end
	return n
end

-- Minimal LihFolk Net: records listeners; validators shaped like Net.T.
local function fakeNet(): Fake
	local T = {}
	function T.integer(lo: number, hi: number)
		return function(v: any)
			return type(v) == "number" and v == v and v >= lo and v <= hi and math.floor(v) == v
		end
	end
	function T.number(lo: number, hi: number)
		return function(v: any)
			return type(v) == "number" and v == v and v >= lo and v <= hi
		end
	end
	function T.string(max: number, pattern: string?)
		return function(v: any)
			return type(v) == "string" and #v <= max and (pattern == nil or string.match(v, pattern) ~= nil)
		end
	end
	function T.key(map: { [string]: any })
		return function(v: any)
			return type(v) == "string" and rawget(map, v) ~= nil
		end
	end
	function T.optional(f: (any) -> boolean)
		return function(v: any)
			return v == nil or f(v)
		end
	end
	local net: Fake = { T = T, listeners = {} }
	function net.Listen(name: string, spec: Fake)
		net.listeners[name] = spec
	end
	-- Fires a remote like Net does: argument count and validators first, then the handler.
	function net.call(name: string, player: Fake, ...: any): boolean
		local spec = net.listeners[name]
		assert(spec, "no listener " .. name)
		if select("#", ...) > #spec.args then
			return false
		end
		local args = { ... }
		for i, check in spec.args do
			if not check(args[i]) then
				return false
			end
		end
		spec.handler(player, ...)
		return true
	end
	return net
end

type World = {
	analytics: any,
	liveFlags: any,
	service: Fake,
	logs: { { method: string, args: { any } } },
	net: Fake,
	players: Fake,
	threads: { thread },
	deferred: { thread },
	store: { doc: any, fail: string? },
	config: { [string]: any },
	closers: { () -> () },
	now: { t: number },
	addPlayer: (userId: number, launch: string?, skipAdded: boolean?) -> Fake,
	removePlayer: (p: Fake, keepParent: boolean?) -> (),
	runDeferred: () -> (),
	run: () -> (),
	snapshot: Fake,
}

local function world(isStudio: boolean): World
	local w: any = {
		logs = {},
		threads = {},
		deferred = {},
		store = { doc = nil },
		config = {},
		closers = {},
		now = { t = 100 },
	}
	local function record(method: string)
		return function(_self: any, ...: any)
			table.insert(w.logs, { method = method, args = { ... } })
		end
	end
	local service: Fake = {}
	for _, m in
		{
			"LogOnboardingFunnelStepEvent",
			"LogFunnelStepEvent",
			"LogCustomEvent",
			"LogEconomyEvent",
			"LogProgressionStartEvent",
			"LogProgressionCompleteEvent",
			"LogProgressionFailEvent",
		}
	do
		service[m] = record(m)
	end
	w.service = service
	local net = fakeNet()
	w.net = net
	local players: Fake = node("Players")
	players.PlayerAdded = signal()
	players.PlayerRemoving = signal()
	players.list = {}
	function players.GetPlayers(_self: any)
		return table.clone(players.list)
	end
	function players.GetPlayerByUserId(_self: any, id: number)
		for _, p in players.list do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	w.players = players
	local signalModule = {
		new = signal,
	}
	local replicated = node("ReplicatedStorage", {
		Shared = node("Shared", {
			Config = node("Config", nil, "Config"),
			Analytics = node("Analytics", {
				Events = node("Events", nil, "Events"),
				JoinSource = node("JoinSource", nil, "JoinSource"),
				PerfSample = node("PerfSample", nil, "PerfSample"),
				Tracker = node("Tracker", nil, "Tracker"),
				LiveFlagSpec = node("LiveFlagSpec", nil, "LiveFlagSpec"),
			}),
			Data = node("Data", {
				Calendar = node("Calendar", nil, "Calendar"),
				Keys = node("Keys", nil, "Keys"),
			}),
		}),
		LihFolk = node("LihFolk", {
			Net = node("Net", nil, "Net"),
			Signal = node("Signal", nil, "Signal"),
		}),
	})
	local snapshot: Fake = { UpdateAvailable = signal() }
	function snapshot.GetValue(_self: any, key: string): any
		return w.config[key]
	end
	function snapshot.Refresh(_self: any) end
	w.snapshot = snapshot
	local services: { [string]: any } = {
		AnalyticsService = service,
		MarketplaceService = { PromptProductPurchaseFinished = signal() },
		Players = players,
		ReplicatedStorage = replicated,
		RunService = {
			IsServer = function()
				return true
			end,
			IsStudio = function()
				return isStudio
			end,
		},
		DataStoreService = {
			GetDataStore = function(_self: any, _name: string)
				return {
					GetAsync = function(_s: any, _key: string)
						if w.store.fail then
							error(w.store.fail)
						end
						return w.store.doc
					end,
				}
			end,
		},
		HttpService = {
			JSONEncode = function(_self: any, v: any)
				return serde.encode("json", v)
			end,
			JSONDecode = function(_self: any, s: string)
				return serde.decode("json", s)
			end,
		},
		ConfigService = {
			GetConfigAsync = function(_self: any)
				return snapshot
			end,
			GetConfigForPlayerAsync = function(_self: any, _player: any)
				return snapshot
			end,
		},
	}
	local game: Fake = { GameId = 424242, PlaceVersion = 0 }
	function game.GetService(_self: any, name: string)
		local s = services[name]
		assert(s ~= nil, "fake GetService: " .. name)
		return s
	end
	function game.BindToClose(_self: any, fn: () -> ())
		table.insert(w.closers, fn)
	end
	local function token(name: string)
		return { Name = name }
	end
	local Enum = {
		AnalyticsCustomFieldKeys = {
			CustomField01 = token("CustomField01"),
			CustomField02 = token("CustomField02"),
			CustomField03 = token("CustomField03"),
		},
		AnalyticsEconomyFlowType = { Source = token("Source"), Sink = token("Sink") },
	}
	local fakeTask = {
		spawn = function(fn: (...any) -> (), ...: any)
			local co = coroutine.create(fn)
			table.insert(w.threads, co)
			local ok, err = coroutine.resume(co, ...)
			assert(ok, err)
			return co
		end,
		wait = function(s: number?)
			coroutine.yield(s)
			return s or 0
		end,
		-- like the engine: resumed after the current handlers, at the end of the resumption cycle
		defer = function(fn: (...any) -> (), ...: any)
			local args = table.pack(...)
			local co = coroutine.create(function()
				fn(table.unpack(args, 1, args.n))
			end)
			table.insert(w.deferred, co)
			return co
		end,
	}
	local fakeOs = setmetatable({
		clock = function()
			return w.now.t
		end,
	}, { __index = os })
	local loaded: { [string]: any } = {}
	local env: { [string]: any } = {
		game = game,
		Enum = Enum,
		task = fakeTask,
		os = fakeOs,
		warn = function(...: any)
			local _ = ...
		end,
		print = function(...: any)
			local _ = ...
		end,
		typeof = function(v: any): string
			if type(v) == "table" and rawget(v, "__instance") then
				return "Instance"
			end
			return type(v)
		end,
		Instance = {
			new = function(class: string)
				local n = node(class)
				n.className = class
				return n
			end,
		},
		require = function(target: any): any
			if type(target) == "table" and target.module then
				if target.module == "Net" then
					return net
				elseif target.module == "Signal" then
					return signalModule
				elseif target.module == "LiveFlags" then
					return loaded.LiveFlags
				end
				return MODULES[target.module]
			end
			error("fake require: unexpected target " .. tostring(target))
		end,
	}
	-- script.Parent for both server modules is the Analytics folder holding LiveFlags.
	local folder = node("AnalyticsFolder", { LiveFlags = node("LiveFlags", nil, "LiveFlags") })
	local function loadServer(path: string, name: string): any
		local s = node(name, nil)
		s.Parent = folder
		local fnc = luau.load(fs.readFile(path), {
			debugName = name,
			environment = (function()
				local e = table.clone(env)
				e.script = s
				return e
			end)(),
		})
		return fnc()
	end
	loaded.LiveFlags = loadServer("src/server/Analytics/LiveFlags.luau", "LiveFlags")
	w.liveFlags = loaded.LiveFlags
	w.analytics = loadServer("src/server/Analytics/Analytics.luau", "Analytics")
	-- skipAdded: the Player is in the game but our PlayerAdded handler has not run yet
	function w.addPlayer(userId: number, launch: string?, skipAdded: boolean?): Fake
		local p = node("Player" .. userId)
		p.className = "Player"
		p.UserId = userId
		p.FollowUserId = 0
		p.PartyId = ""
		p.Parent = players
		function p.GetJoinData(_self: any)
			return { LaunchData = launch or "", ReferredByPlayerId = 0 }
		end
		table.insert(players.list, p)
		if not skipAdded then
			players.PlayerAdded:Fire(p)
		end
		return p
	end
	function w.runDeferred()
		while #w.deferred > 0 do
			local co = table.remove(w.deferred, 1)
			local ok, err = coroutine.resume(co)
			assert(ok, err)
		end
	end
	-- PlayerRemoving (every handler, in connection order), then the deferred threads. keepParent:
	-- the Player is still parented to Players afterwards (as inside the same frame)
	function w.removePlayer(p: Fake, keepParent: boolean?)
		players.PlayerRemoving:Fire(p)
		w.runDeferred()
		if not keepParent then
			p.Parent = nil
			table.remove(players.list, table.find(players.list, p) :: number)
		end
	end
	-- Passes of every waiting loop (the 1 s pump, the LiveFlags poll, the GetJoinData polls):
	-- enough for a join without launch data to finish its JOIN_DATA_POLLS reads.
	function w.run()
		w.runDeferred()
		for _ = 1, Config.Analytics.JOIN_DATA_POLLS + 1 do
			for _, co in table.clone(w.threads) do
				if coroutine.status(co) == "suspended" then
					local ok, err = coroutine.resume(co)
					assert(ok, err)
				end
			end
		end
	end
	return w :: World
end

local function logsOf(w: World, method: string, name: string?): { { any } }
	local out = {}
	for _, l in w.logs do
		if l.method == method and (name == nil or l.args[2] == name) then
			table.insert(out, l.args)
		end
	end
	return out
end

return function(test)
	test("live server: a share-link join reaches AnalyticsService with the right shapes", function()
		local w = world(false)
		Assert.eq(w.analytics.environment(), "live", "environment")
		w.analytics.start()
		Assert.truthy(w.net.listeners["Analytics.Perf"], "perf remote declared")
		local p = w.addPlayer(501, "v1|src|yt")
		w.analytics.setPlayerFacts(p, { isNew = true, ftueStep = 0, created = os.time() })
		w.analytics.onboarding(p, "FirstPlate")
		w.run()
		local onb = logsOf(w, "LogOnboardingFunnelStepEvent")
		Assert.eq(#onb, 2, "Joined + FirstPlate")
		Assert.eq(onb[1][1], p, "player first")
		Assert.eq(onb[1][2], 1, "step number")
		Assert.eq(onb[1][3], "Joined", "step name")
		Assert.eq(onb[1][4].CustomField01, "share", "JoinSource in CustomField01")
		Assert.eq(onb[1][4].CustomField02, "yt", "tag in CustomField02")
		Assert.eq(onb[2][4], nil, "no fields after step 1")
		local js = logsOf(w, "LogCustomEvent", "JoinSource")
		Assert.eq(#js, 1, "JoinSource event")
		Assert.eq(js[1][3], 1, "value")
		Assert.eq(js[1][4].CustomField03, "new", "cohort")
		local ret = logsOf(w, "LogFunnelStepEvent", "ret_d1")
		Assert.eq(ret[1][3], "r501", "retention session id")
		Assert.eq(ret[1][5], "FirstDay", "step name")
		Assert.eq(w.analytics.joinSource(p).source, "share", "joinSource()")
		Assert.eq(w.analytics.launchData("reel", "cs1_back_room"), "v1|reel|cs1_back_room", "launchData()")
		Assert.eq(w.analytics.launchData("grant", "x"), nil, "bad launch data")
	end)

	test("live server: heist, economy, client remotes, shutdown flush", function()
		local w = world(false)
		w.analytics.start()
		local p = w.addPlayer(502)
		w.analytics.setPlayerFacts(p, { isNew = false, ftueStep = 12, created = os.time() - 86400 * 3 })
		local currency = { Changed = signal() }
		w.analytics.bindCurrency(currency.Changed)
		local sid = w.analytics.heistStarted(p, { heistId = "H-1", level = "cs2_two_doors", crew = 1 })
		Assert.eq(sid, "H-1", "session id")
		w.analytics.heistStep(p, "H-1", "HeistComplete")
		w.analytics.heistEnded(p, "H-1", "complete", 4)
		p:SetAttribute("Stars", 7)
		currency.Changed:Fire(p, "Cash", 400, 400, "heist:TwoDoors")
		Assert.truthy(w.net.call("Analytics.Ready", p, "phone"), "ready accepted")
		Assert.falsy(w.net.call("Analytics.Ready", p, "toaster"), "bad device refused by the validator")
		local ok = w.net.call("Analytics.Perf", p, 16.5, 20, 45, 3500, 60, "phone", 0, 900, 8, "balanced")
		Assert.truthy(ok, "perf accepted")
		Assert.falsy(w.net.call("Analytics.Ui", p, "GrantRobux", "x"), "unknown ui kind refused")
		w.analytics.cloneFailed(p, "zapped", "TwoDoors")
		w.run()
		local prog = logsOf(w, "LogProgressionStartEvent")
		Assert.eq(prog[1][2], "Heist", "path")
		Assert.eq(prog[1][3], 2, "level index")
		Assert.eq(prog[1][4], "TwoDoors", "level name")
		Assert.eq(#logsOf(w, "LogProgressionCompleteEvent"), 1, "complete")
		local eco = logsOf(w, "LogEconomyEvent")
		Assert.eq(#eco, 1, "economy event")
		Assert.eq(eco[1][2].Name, "Source", "flow enum")
		Assert.eq(eco[1][3], "Cash", "currency")
		Assert.eq(eco[1][4], 400, "amount")
		Assert.eq(eco[1][5], 400, "ending balance")
		Assert.eq(eco[1][6], "Gameplay", "transaction type")
		Assert.eq(eco[1][7], "Heist_TwoDoors", "sku")
		Assert.eq(eco[1][8].CustomField01, "s6-13", "progress band from the Stars attribute")
		Assert.eq(logsOf(w, "LogCustomEvent", "JoinToControl")[1][4].CustomField02, "phone", "ready")
		Assert.eq(#logsOf(w, "LogCustomEvent", "PerfSample"), 1, "perf sample")
		Assert.eq(#logsOf(w, "LogCustomEvent", "CloneFailed"), 0, "batched until the flush")
		for _, close in w.closers do
			close()
		end
		Assert.eq(#logsOf(w, "LogCustomEvent", "CloneFailed"), 1, "BindToClose flushes batches")
		Assert.eq(#logsOf(w, "LogCustomEvent", "SessionEnd"), 1, "and ends sessions")
		local s = w.analytics.stats()
		Assert.eq(s.failed, 0, "no AnalyticsService errors")
		Assert.truthy(s.executed > 0, "executed")
	end)

	test("a step reported before our PlayerAdded handler ran still registers the player, once", function()
		local w = world(false)
		w.analytics.start()
		local p = w.addPlayer(510, "v1|src|tt")
		-- another module's PlayerAdded handler (HeistService "Joined") runs before ours
		local q = w.addPlayer(511, "v1|src|dc", true)
		w.analytics.onboarding(q, "Joined")
		w.analytics.setPlayerFacts(q, { isNew = true, ftueStep = 0 })
		w.players.PlayerAdded:Fire(q) -- ours, late: the same session
		w.analytics.setPlayerFacts(p, { isNew = true, ftueStep = 0 })
		w.run()
		local tags, joined = {}, {}
		for _, l in logsOf(w, "LogOnboardingFunnelStepEvent") do
			tags[l[1].UserId] = l[4].CustomField02
			joined[l[1].UserId] = (joined[l[1].UserId] or 0) + 1
		end
		Assert.eq(tags[510], "tt", "normal join")
		Assert.eq(tags[511], "dc", "registered by the report")
		Assert.eq(joined[511], 1, "one Joined: our late PlayerAdded opened no second session")
		Assert.eq(#logsOf(w, "LogCustomEvent", "JoinSource"), 2, "one JoinSource each")
	end)

	test("leaving: a later PlayerRemoving handler's report lands in the session; no ghost after it", function()
		local w = world(false)
		w.analytics.start()
		-- HeistService's PlayerRemoving handler runs after ours (Roblox does not order handlers):
		-- removeMember -> heistEnded "left"
		w.players.PlayerRemoving:Connect(function(player: any)
			w.analytics.heistEnded(player, "H-9", "left", 2)
		end)
		local p = w.addPlayer(520, "v1|src|yt")
		w.analytics.setPlayerFacts(p, { isNew = true, ftueStep = 0, created = os.time() })
		w.analytics.heistStarted(p, { heistId = "H-9", level = "cs2_two_doors", crew = 1 })
		w.run()
		w.now.t += 90
		w.removePlayer(p, true)
		-- reports for the departed Player while it is still parented (the same frame, the next step)
		w.analytics.heistEnded(p, "H-9", "abandoned", 2)
		w.analytics.onboarding(p, "FirstPlate")
		w.analytics.setPlayerFacts(p, { isNew = true, ftueStep = 0 })
		w.run()
		local ended = logsOf(w, "LogCustomEvent", "HeistEnded")
		Assert.eq(#ended, 1, "one HeistEnded")
		Assert.eq(ended[1][4].CustomField01, "TwoDoors", "the real level, not Other")
		Assert.eq(ended[1][4].CustomField02, "left", "outcome")
		Assert.eq(#logsOf(w, "LogCustomEvent", "JoinSource"), 1, "JoinSource once")
		Assert.eq(#logsOf(w, "LogOnboardingFunnelStepEvent"), 1, "Joined once; the late FirstPlate dropped")
		Assert.eq(#logsOf(w, "LogCustomEvent", "SessionEnd"), 1, "one session end")
		Assert.eq(w.analytics.stats().noSession, 3, "the late reports are counted, not re-registered")
		w.removePlayer(p) -- gone from Players
		-- the user rejoins from another channel: a fresh session with its own source and length
		w.now.t += 30
		local p2 = w.addPlayer(520, "v1|src|tt")
		w.analytics.setPlayerFacts(p2, { isNew = false, ftueStep = 0 })
		w.run()
		Assert.eq(w.analytics.joinSource(p2).tag, "tt", "the new source")
		local js = logsOf(w, "LogCustomEvent", "JoinSource")
		Assert.eq(#js, 2, "a JoinSource per session")
		Assert.eq(js[2][4].CustomField02, "tt", "tagged tt")
		Assert.eq(js[2][4].CustomField03, "returning", "cohort")
		w.now.t += 90
		w.removePlayer(p2)
		local ends = logsOf(w, "LogCustomEvent", "SessionEnd")
		Assert.eq(#ends, 2, "two session ends")
		Assert.eq(ends[2][3], 1.5, "the second session is measured from the rejoin")
		-- our fake HeistService reports "left" on every leave: the new session never had heist H-9
		local again = logsOf(w, "LogCustomEvent", "HeistEnded")
		Assert.eq(#again, 2, "one HeistEnded per leave")
		Assert.eq(again[2][4].CustomField01, "Other", "the old session's heist did not carry over")
	end)

	test("cohort: a profile created minutes before this join (crash rejoin) is returning", function()
		local w = world(false)
		w.analytics.start()
		local snaps: { [number]: any } = {}
		local data: any = { Loaded = signal() }
		function data.getSnapshot(player: any)
			return snaps[player.UserId]
		end
		function data.isReady(_player: any)
			return false
		end
		w.analytics.bindData(data)
		local fresh = w.addPlayer(530, "v1|src|tt")
		snaps[530] = { created = os.time() + 1, heist = { ftueStep = 0, stats = { heists = 0 } } }
		data.Loaded:Fire(fresh)
		local rejoin = w.addPlayer(531, "v1|src|tt")
		snaps[531] = { created = os.time() - 120, heist = { ftueStep = 0, stats = { heists = 0 } } }
		data.Loaded:Fire(rejoin)
		w.run()
		local cohort = {}
		for _, l in logsOf(w, "LogCustomEvent", "JoinSource") do
			cohort[l[1].UserId] = l[4].CustomField03
		end
		Assert.eq(cohort[530], "new", "profile created in this session")
		Assert.eq(cohort[531], "returning", "profile created 2 minutes earlier")
	end)

	test("store: Shop.ProductPrompted logs PromptShown at prompt time; client store steps are metered", function()
		local w = world(false)
		local shop = { ProductPrompted = signal() }
		w.analytics.start({ shop = shop })
		local p = w.addPlayer(540, "v1|src|tt")
		w.analytics.setPlayerFacts(p, { isNew = true, ftueStep = 0 })
		w.run()
		Assert.truthy(w.net.call("Analytics.Ui", p, "StoreOpened", "van"), "store opened")
		shop.ProductPrompted:Fire(p, "StyleNoir")
		w.run()
		local steps = {}
		for _, l in logsOf(w, "LogFunnelStepEvent", "store_v1") do
			table.insert(steps, l[5])
		end
		Assert.eq(table.concat(steps, ","), "StoreOpened,PromptShown", "funnel steps")
		local before = #logsOf(w, "LogFunnelStepEvent", "store_v1")
		for _ = 1, 40 do
			w.net.call("Analytics.Ui", p, "StoreOpened", "garage")
		end
		w.run()
		Assert.eq(#logsOf(w, "LogFunnelStepEvent", "store_v1"), before, "spam reuses the open session")
	end)

	test("Studio: nothing reaches AnalyticsService, calls are recorded; fake members ignored", function()
		local w = world(true)
		Assert.eq(w.analytics.environment(), "studio", "environment")
		w.analytics.start()
		local p = w.addPlayer(503)
		w.analytics.setPlayerFacts(p, { isNew = true, ftueStep = 0 })
		w.analytics.onboarding({ UserId = 1 } :: any, "FirstPlate") -- a fake heist member table
		w.run()
		Assert.eq(#w.logs, 0, "no AnalyticsService calls in Studio")
		local recent = w.analytics.recent()
		Assert.truthy(#recent >= 2, "recorded locally")
		Assert.eq(recent[1].sent, false, "marked as not sent")
		Assert.truthy(w.analytics.stats().suppressed > 0, "suppressed count")
		local seen = {}
		w.analytics.setBackend(function(call: any)
			table.insert(seen, call.name)
		end)
		w.analytics.medal(p, "Haul", "BackRoom")
		w.run()
		Assert.eq(seen[1], "MedalEarned", "a backend sees calls even in Studio (engine smoke hook)")
	end)

	test("LiveFlags: defaults, DataStore + ConfigService layers, kill switch stops analytics", function()
		local w = world(false)
		local LF = w.liveFlags
		Assert.eq(LF.get("store"), true, "default before start")
		w.config.EH_saveClip = false
		w.config.EH_alarmVanSeconds = 999 -- out of range: refused
		w.store.doc = { v = 1, flags = { quickCrew = false, alarmVanSeconds = 25 }, note = "test" }
		w.analytics.start()
		Assert.eq(LF.get("saveClip"), false, "ConfigService layer")
		Assert.eq(LF.source("saveClip"), "config", "source")
		Assert.eq(LF.get("quickCrew"), false, "DataStore layer")
		Assert.eq(LF.get("alarmVanSeconds"), 25, "DataStore beats the refused config value")
		Assert.falsy(LF.setTestValue("store", false), "live servers refuse testing values")
		-- an outage (GetAsync throws) keeps the last good document
		w.store.fail = "502: DataStore unavailable"
		LF.refresh()
		Assert.eq(LF.get("quickCrew"), false, "killed switch stays killed through the outage")
		Assert.eq(LF.get("alarmVanSeconds"), 25, "tuning kept too")
		Assert.eq(LF.snapshot().status.store, "error", "status")
		w.store.fail = nil
		-- a deleted document clears its overrides
		w.store.doc = nil
		LF.refresh()
		Assert.eq(LF.get("quickCrew"), true, "a deleted document clears its overrides")
		Assert.eq(LF.snapshot().status.store, "missing", "status")
		-- a stale "on" in the DataStore never cancels the owner's ConfigService kill
		w.config.EH_store = false
		w.snapshot.UpdateAvailable:Fire()
		w.store.doc = { v = 1, flags = { store = true } }
		LF.refresh()
		Assert.eq(LF.get("store"), false, "off wins")
		Assert.eq(LF.source("store"), "config", "source")
		w.store.doc = { flags = { analytics = false } }
		LF.refresh()
		Assert.falsy(LF.isOn("analytics"), "analytics killed")
		local before = #w.logs
		local p = w.addPlayer(504)
		w.analytics.setPlayerFacts(p, { isNew = true, ftueStep = 0 })
		w.run()
		Assert.eq(#w.logs, before, "nothing sent while killed")
		Assert.truthy(w.analytics.stats().dropKilled > 0, "counted")
		local p2 = w.addPlayer(505)
		Assert.eq(LF.forPlayer("ftueVariant", p2), "base", "experiment arm")
		Assert.eq(p2:GetAttribute("LF_clipUpload"), false, "release flag mirrored per player")
	end)
end
