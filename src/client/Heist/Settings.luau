--!strict
-- Heist/Settings: the player's settings on the client (PLAN_STEAM_PLUS §4.3 U7). Values come from the
-- player attributes DataService publishes (Setting_<Key>, Shared/Data/Schema.settingAttribute); a change
-- shows at once (a session override) and is saved through the existing Data.SetSetting remote (the server
-- validates it again: Schema.validSetting). Without the data service (offline Studio) a change lasts for
-- the session. Sliders save when released (Hud/Settings), and a burst of changes to one key sends only
-- the last value, at most SEND_GAP apart (Data.SetSetting allows 2/s).
-- Nothing here decides gameplay: these are view and sound preferences.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Schema = require(Shared:WaitForChild("Data"):WaitForChild("Schema"))
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))

local REMOTES = "LihFolkRemotes"
local SET_SETTING = "Data.SetSetting"
local SEND_GAP = 0.6 -- s between two saves of one key (the remote's rate limit is 2 per second)

local Settings = {}

local defaults = Schema.defaultSettings()
local overrides: { [string]: any } = {}
local listeners: { [number]: (key: string, value: any) -> () } = {}
local nextListener = 0
local pending: { [string]: any } = {}
local sending: { [string]: boolean } = {}
local player = Players.LocalPlayer

Settings.KEYS = table.freeze((function()
	local keys = {}
	for k in defaults do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end)())

local seen: { [string]: any } = {} -- the last value listeners heard, per key

local function notify(key: string, value: any)
	if seen[key] == value then
		return
	end
	seen[key] = value
	for _, fn in listeners do
		task.spawn(fn, key, value)
	end
end

-- The value in use for a key (session override, else the saved value, else the default).
function Settings.get(key: string): any
	local v = overrides[key]
	if v ~= nil then
		return v
	end
	if player then
		local saved = player:GetAttribute(Schema.settingAttribute(key))
		if Schema.validSetting(key, saved) then
			return saved
		end
	end
	return defaults[key]
end

-- Calls fn(key, value) after every change (yours or the server's). Returns a disconnect.
function Settings.onChanged(fn: (key: string, value: any) -> ()): () -> ()
	nextListener += 1
	local id = nextListener
	listeners[id] = fn
	return function()
		listeners[id] = nil
	end
end

local function canSave(): boolean
	local folder = ReplicatedStorage:FindFirstChild(REMOTES)
	return folder ~= nil and folder:FindFirstChild(SET_SETTING) ~= nil
end

local function flush(key: string)
	if sending[key] then
		return
	end
	sending[key] = true
	task.spawn(function()
		while pending[key] ~= nil do
			local value = pending[key]
			pending[key] = nil
			Net.Request(SET_SETTING, key, value)
			task.wait(SEND_GAP)
		end
		sending[key] = nil
	end)
end

-- Sets a value now; `save` (default true) also stores it in the profile.
function Settings.set(key: string, value: any, save: boolean?)
	if not Schema.validSetting(key, value) then
		return
	end
	seen[key] = if seen[key] == nil then Settings.get(key) else seen[key]
	overrides[key] = value
	notify(key, value)
	if save ~= false and canSave() then
		pending[key] = value
		flush(key)
	end
end

-- Saved values arriving (profile load, or the echo of a save): the override gives way once they agree.
if player then
	for _, key in Settings.KEYS do
		player:GetAttributeChangedSignal(Schema.settingAttribute(key)):Connect(function()
			local saved = player:GetAttribute(Schema.settingAttribute(key))
			if not Schema.validSetting(key, saved) then
				return
			end
			if overrides[key] == nil or overrides[key] == saved then
				overrides[key] = nil
				notify(key, saved)
			end
		end)
	end
end

return Settings
