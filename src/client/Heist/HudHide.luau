--!strict
-- Heist/HudHide: hides every gameplay / lobby HUD layer and the Roblox CoreGui pieces while the story intro plays,
-- and gives each back exactly as it was (owner on v125: "PICK A VAN gets in the way in the intro"). The rules are
-- pure in Shared/Heist/IntroHud; Heist/Cinematic begins it when it builds and restores it on every exit path.
--
--   HudHide.begin(opts) -> h
--     h.enforce()      every intro frame: a hidden layer the game turned on again is hidden again
--     h.restore()      give everything back (idempotent)
--     h.hidden() -> { Instance }   the layers hidden now (tests)
--     h.core() -> { string }       the CoreGui pieces turned off (tests)
-- opts: { root: Instance? (PlayerGui; default the local player's), world: Instance? (default Workspace on a client,
--         none on a server), stage: Instance? (the intro's own stage: never touched), core: { get: (string) ->
--         boolean?, set: (string, boolean) -> () }? (default StarterGui on a client, none on a server) }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local IntroHud = require(Shared:WaitForChild("Heist"):WaitForChild("IntroHud"))

local KEEP_ATTR = Config.Intro.HUD.KEEP_ATTRIBUTE

local HudHide = {}

type Core = { get: (string) -> boolean?, set: (string, boolean) -> () }

local function starterCore(): Core
	return {
		get = function(name: string): boolean?
			local ok, v = pcall(function()
				return StarterGui:GetCoreGuiEnabled((Enum.CoreGuiType :: any)[name])
			end)
			return if ok and type(v) == "boolean" then v else nil
		end,
		set = function(name: string, on: boolean)
			pcall(function()
				StarterGui:SetCoreGuiEnabled((Enum.CoreGuiType :: any)[name], on)
			end)
		end,
	}
end

local function isLayer(i: Instance): boolean
	return i:IsA("LayerCollector")
end

function HudHide.begin(opts: any?): any
	local o = opts or {}
	local isClient = RunService:IsClient()
	local localPlayer = Players.LocalPlayer
	local root: Instance? = o.root or (if localPlayer then localPlayer:FindFirstChildOfClass("PlayerGui") else nil)
	local world: Instance? = o.world or (if isClient then workspace else nil)
	local stage: Instance? = o.stage
	local core: Core? = o.core or (if isClient then starterCore() else nil)

	local h = {}
	local hidden: { [Instance]: boolean } = {} -- layer -> its Enabled before the intro
	local coreOff: { { name: string, was: boolean } } = {}
	local conns: { RBXScriptConnection } = {}
	local restored = false

	local function hide(g: Instance)
		if hidden[g] ~= nil then
			return
		end
		local lc = g :: any
		hidden[g] = true
		lc.Enabled = false
	end

	local function view(g: Instance): any
		local lc = g :: any
		return {
			className = g.ClassName,
			name = g.Name,
			enabled = lc.Enabled == true,
			keep = g:GetAttribute(KEEP_ATTR) == true,
			alwaysOnTop = if g:IsA("BillboardGui") then g.AlwaysOnTop else nil,
			inStage = if stage then g:IsDescendantOf(stage) else false,
		}
	end

	local function considerRoot(g: Instance)
		if not restored and isLayer(g) and IntroHud.hideInPlayerGui(view(g)) then
			hide(g)
		end
	end

	local function considerWorld(g: Instance)
		if not restored and g:IsA("BillboardGui") and IntroHud.hideInWorld(view(g)) then
			hide(g)
		end
	end

	if root then
		for _, g in root:GetChildren() do
			considerRoot(g)
		end
		table.insert(conns, root.ChildAdded:Connect(considerRoot))
	end
	if world then
		for _, d in world:GetDescendants() do
			if d:IsA("BillboardGui") then
				considerWorld(d)
			end
		end
		table.insert(
			conns,
			world.DescendantAdded:Connect(function(d: Instance)
				if d:IsA("BillboardGui") then
					-- its AlwaysOnTop / Adornee are usually set after it is parented: look once it is set up
					task.defer(considerWorld, d)
				end
			end)
		)
	end
	if core then
		local c = core :: Core
		coreOff = IntroHud.corePlan(c.get)
		for _, item in coreOff do
			c.set(item.name, false)
		end
	end

	function h.enforce()
		if restored then
			return
		end
		for g in hidden do
			local lc = g :: any
			if g.Parent ~= nil and lc.Enabled then
				lc.Enabled = false
			end
		end
		if core then
			for _, item in coreOff do
				if (core :: Core).get(item.name) == true then
					(core :: Core).set(item.name, false)
				end
			end
		end
	end

	function h.restore()
		if restored then
			return
		end
		restored = true
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		for g, was in hidden do
			local lc = g :: any
			local v = IntroHud.restoreValue(was, lc.Enabled == true, g.Parent ~= nil)
			if v ~= nil then
				lc.Enabled = v
			end
		end
		table.clear(hidden)
		if core then
			for _, item in coreOff do
				(core :: Core).set(item.name, item.was)
			end
		end
	end

	function h.hidden(): { Instance }
		local out = {}
		for g in hidden do
			table.insert(out, g)
		end
		return out
	end

	function h.core(): { string }
		local out = {}
		for _, item in coreOff do
			table.insert(out, item.name)
		end
		return out
	end

	return h
end

return HudHide
