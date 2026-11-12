--!strict
-- Analytics/LiveFlags: server-side feature flags and kill switches. MASTERPLAN §8.7 (a DataStore key
-- polled every 60 s turns features off without a republish), §8.12 (kill switches for anything that
-- misbehaves). Pure rules and the definitions: ReplicatedStorage.Shared.Analytics.LiveFlagSpec and
-- Config.LiveFlags. docs/ANALYTICS.md "LiveFlags" has the incident runbook.
--
-- Layers, lowest first (a layer that does not set a flag leaves it alone):
--   default  Config.LiveFlags.Flags[name].default (kill switches on, release flags off)
--   config   ConfigService key "EH_<name>" (Creator Hub > Configs: staged in Studio, live in about a
--            minute, per-switch history and Restore). Read once, refreshed on UpdateAvailable.
--   store    DataStore Config.LiveFlags.STORE_NAME, key "LiveFlags" ("_TEST_LiveFlags" in Studio and
--            the test experience): { v = 1, flags = { store = false }, note = "why" }. Polled every
--            POLL_SECONDS (one GetAsync per server per minute). Open Cloud can write it (Claude, D5).
--   test     LiveFlags.setTestValue (Studio and the test experience only)
-- A failed read keeps the last good layer: an outage never turns a killed feature back on.
-- Kill switches: off wins (any layer that sets one false keeps it off). Other flags: the highest
-- layer that sets them wins, and a ConfigService value shadowed by the DataStore document is warned
-- about (a stale incident override), each time either layer is read.
--
-- Server API (never yields except start/refresh):
--   LiveFlags.start()                        idempotent; Analytics.start() calls it
--   LiveFlags.get(name) -> any               effective value (defaults until loaded)
--   LiveFlags.isOn(name) -> boolean          whole-server on/off (a release percent counts at 100)
--   LiveFlags.forPlayer(name, player) -> any sticky per-player value (release percent, experiment arm)
--   LiveFlags.isOnFor(name, player) -> boolean
--   LiveFlags.source(name) -> "default" | "config" | "store" | "test"
--   LiveFlags.snapshot() -> { values, sources, status }
--   LiveFlags.setTestValue(name, value?)     Studio/test only; nil clears
--   LiveFlags.refresh()                      re-read the DataStore now (yields)
--   LiveFlags.Changed                        Signal (name, value, oldValue, source)
-- Clients: ReplicatedStorage.LiveFlags (Folder) carries one attribute per `client = true` flag; release
-- flags also get a per-player attribute LF_<name> (the sticky rollout answer for that player).
-- Tuning flags are read by the heist server at heist start and stored with the heist, never mid-run.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local LiveFlagSpec = require(Shared:WaitForChild("Analytics"):WaitForChild("LiveFlagSpec"))
local Keys = require(Shared:WaitForChild("Data"):WaitForChild("Keys"))
local Signal = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Signal"))

local LF = Config.LiveFlags
local IS_STUDIO = RunService:IsStudio()
local IS_TEST = Keys.isTestEnvironment(IS_STUDIO, game.GameId)
local STORE_KEY = if IS_TEST then Config.Data.TEST_PREFIX .. LF.KEY else LF.KEY

local LiveFlags = {}
LiveFlags.Changed = Signal.new() -- (name, value, oldValue, source)

local defs = LiveFlagSpec.defs()
local layers: { [string]: { [string]: any } } = { config = {}, store = {}, test = {} }
local values, sources = LiveFlagSpec.resolve(defs, {})
local started = false
local folder: Folder? = nil
local status = {
	store = "idle", -- idle | ok | missing | error
	config = "idle", -- idle | ok | unavailable | error
	storeReadAt = 0,
	configReadAt = 0,
	errors = {} :: { string },
}

---------------------------------------------------------------------------
-- Publishing
---------------------------------------------------------------------------

local function attrValue(value: any): any
	if type(value) == "boolean" or type(value) == "number" or type(value) == "string" then
		return value
	end
	return nil
end

local function publishPlayer(player: Player, name: string)
	local def = defs[name]
	if def and def.client and def.kind == "release" then
		player:SetAttribute("LF_" .. name, LiveFlagSpec.forUser(name, def, values[name], player.UserId) == true)
	end
end

local function publish(name: string)
	local def = defs[name]
	if not def or not def.client then
		return
	end
	if folder then
		folder:SetAttribute(name, attrValue(values[name]))
	end
	for _, player in Players:GetPlayers() do
		publishPlayer(player, name)
	end
end

local function recompute()
	local newValues, newSources = LiveFlagSpec.resolve(defs, {
		{ name = "config", values = layers.config },
		{ name = "store", values = layers.store },
		{ name = "test", values = layers.test },
	})
	local changed = LiveFlagSpec.changed(values, newValues)
	local old = values
	values, sources = newValues, newSources
	for _, name in changed do
		publish(name)
		print(`[LiveFlags] {name} = {tostring(values[name])} (from {sources[name]})`)
		LiveFlags.Changed:Fire(name, values[name], old[name], sources[name])
	end
end

local function note(errors: { string }, layer: string)
	for _, e in errors do
		warn(`[LiveFlags] {layer}: {e}`)
	end
	status.errors = errors
end

local function warnShadowed()
	for _, name in LiveFlagSpec.shadowed(defs, layers.config, layers.store) do
		warn(
			`[LiveFlags] {LiveFlagSpec.configKey(name)} = {tostring(layers.config[name])} has no effect: the DataStore`
				.. ` document sets {name} = {tostring(layers.store[name])}. Clear that entry if it is stale.`
		)
	end
end

---------------------------------------------------------------------------
-- DataStore layer
---------------------------------------------------------------------------

local function readStore(): (boolean, any)
	return pcall(function()
		local store = DataStoreService:GetDataStore(LF.STORE_NAME)
		return store:GetAsync(STORE_KEY)
	end)
end

local function pollStore()
	local ok, result = readStore()
	if not ok then
		if status.store ~= "error" then
			warn(`[LiveFlags] DataStore read failed, keeping the last good flags: {result}`)
		end
		status.store = "error"
		return
	end
	local doc = result
	if type(doc) == "string" then
		local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, doc)
		if not okDecode then
			status.store = "error"
			note({ "document is not valid JSON" }, "store")
			return
		end
		doc = decoded
	end
	if doc ~= nil then
		local okSize, encoded = pcall(HttpService.JSONEncode, HttpService, doc)
		if not okSize or #encoded > LF.MAX_DOC_BYTES then
			status.store = "error"
			note({ `document over {LF.MAX_DOC_BYTES} bytes` }, "store")
			return
		end
	end
	local overrides, errors = LiveFlagSpec.parseDocument(defs, doc)
	note(errors, "store")
	local before = layers.store
	layers.store = overrides
	status.store = if doc == nil then "missing" else "ok"
	status.storeReadAt = os.time()
	if #LiveFlagSpec.changed(before, overrides) > 0 or #LiveFlagSpec.changed(overrides, before) > 0 then
		warnShadowed()
	end
	recompute()
end

---------------------------------------------------------------------------
-- ConfigService layer
---------------------------------------------------------------------------

local function readSnapshot(snapshot: any)
	local out: { [string]: any } = {}
	local errors: { string } = {}
	for name, def in defs do
		local okGet, raw = pcall(function()
			return snapshot:GetValue(LiveFlagSpec.configKey(name))
		end)
		if okGet and raw ~= nil then
			local value, why = LiveFlagSpec.coerce(def, raw)
			if value ~= nil then
				out[name] = value
			else
				table.insert(errors, `{LiveFlagSpec.configKey(name)}: {why} ({tostring(raw)})`)
			end
		end
	end
	note(errors, "config")
	layers.config = out
	status.config = "ok"
	status.configReadAt = os.time()
	warnShadowed()
	recompute()
end

local function loadConfig()
	local okService, service = pcall(game.GetService, game, "ConfigService")
	if not okService or service == nil then
		status.config = "unavailable"
		return
	end
	local okSnap, snapshot = pcall(function()
		return (service :: any):GetConfigAsync()
	end)
	if not okSnap or snapshot == nil then
		status.config = "error"
		warn(`[LiveFlags] ConfigService unavailable, using the other layers: {snapshot}`)
		return
	end
	readSnapshot(snapshot)
	local okSignal = pcall(function()
		(snapshot :: any).UpdateAvailable:Connect(function()
			-- kill switches apply at once; tuning flags are read by the heist server at heist start
			local okRefresh = pcall(function()
				(snapshot :: any):Refresh()
			end)
			if okRefresh then
				readSnapshot(snapshot)
			end
		end)
	end)
	if not okSignal then
		warn("[LiveFlags] ConfigService snapshot has no UpdateAvailable; values stay as first read")
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

local function known(name: string): boolean
	if defs[name] == nil then
		warn(`[LiveFlags] unknown flag '{tostring(name)}' (add it to Config.LiveFlags.Flags)`)
		return false
	end
	return true
end

function LiveFlags.get(name: string): any
	if not known(name) then
		return nil
	end
	return values[name]
end

function LiveFlags.isOn(name: string): boolean
	if not known(name) then
		return false
	end
	return LiveFlagSpec.isOn(defs[name], values[name])
end

function LiveFlags.forPlayer(name: string, player: Player): any
	if not known(name) then
		return nil
	end
	return LiveFlagSpec.forUser(name, defs[name], values[name], player.UserId)
end

function LiveFlags.isOnFor(name: string, player: Player): boolean
	return LiveFlags.forPlayer(name, player) == true
end

function LiveFlags.source(name: string): string
	return sources[name] or "unknown"
end

function LiveFlags.snapshot(): { values: { [string]: any }, sources: { [string]: string }, status: any }
	return { values = table.clone(values), sources = table.clone(sources), status = table.clone(status) }
end

-- Studio and the test experience only (live servers refuse): a quick way to try a switch.
function LiveFlags.setTestValue(name: string, value: any): boolean
	if not (IS_STUDIO or IS_TEST) or not known(name) then
		return false
	end
	if value == nil then
		layers.test[name] = nil
	else
		local v = LiveFlagSpec.coerce(defs[name], value)
		if v == nil then
			return false
		end
		layers.test[name] = v
	end
	recompute()
	return true
end

function LiveFlags.refresh()
	pollStore()
end

function LiveFlags.start()
	if started then
		return
	end
	started = true
	local errors = LiveFlagSpec.validateDefs(defs)
	note(errors, "definitions")
	local f = Instance.new("Folder")
	f.Name = LF.ATTRIBUTE_FOLDER
	for name, def in defs do
		if def.client then
			f:SetAttribute(name, attrValue(values[name]))
		end
	end
	f.Parent = ReplicatedStorage
	folder = f
	Players.PlayerAdded:Connect(function(player: Player)
		for name in defs do
			publishPlayer(player, name)
		end
	end)
	for _, player in Players:GetPlayers() do
		for name in defs do
			publishPlayer(player, name)
		end
	end
	task.spawn(loadConfig)
	task.spawn(function()
		while true do
			pollStore()
			task.wait(LF.POLL_SECONDS)
		end
	end)
end

return LiveFlags
