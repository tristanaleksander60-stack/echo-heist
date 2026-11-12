--!strict
-- Heist/LightDirector: the level's lamps and the Lighting recipe by performance tier (PLAN_STEAM_PLUS §4.1 W2,
-- §4.7, §12; roblox_quality §1.4, §6.4; docs/PERF.md). Local only: the server builds every lamp
-- (Heist/LevelBuilder: a Light under each "ceilingLamp" bulb, an unlit "lightPool" SurfaceGui on the floor) and
-- never touches them again. Per tier (Shared/Heist/Budget, numbers in Config.Perf / Config.Lighting):
--   * from Config.Lighting SHADOWS_OFF_TIER the hero lights (EH_HeroShadow) stop casting shadows; from
--     POOLS_OFF_TIER the floor pools are off;
--   * the lamp kinds in the tier's lightKindsOff (bulb attribute EH_LampKind) are switched off (their bulbs and
--     pools stay), and from recipe C every level light's Range is clamped (Budget.lightRange);
--   * from Config.Perf.SOFT_TOYBOX_TIER the Lighting service switches to recipe C "Soft Toybox" (LightingStyle in a
--     pcall, the scriptable rest always), Bloom off from BLOOM_OFF_TIER; a tier that steps back up restores the
--     project file's recipe A exactly as it was read.
-- Disable, never delete. The tier comes from Heist/Telemetry.onTier: the PerfSample governor steps one tier at a
-- time with its own hysteresis (PerfSample.stepUp: 60 good seconds, doubling after each step up), so the recipe
-- never flickers. This module is the tier's only lighting listener.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Budget = require(Shared:WaitForChild("Heist"):WaitForChild("Budget"))

local Theme = require(script.Parent:WaitForChild("Theme"))

local L = Config.Lighting
local SOFT = Config.Perf.SOFT_TOYBOX
local GROUPS = { "Lighting", "Bloom", "ColorCorrection", "Atmosphere" } -- SOFT_TOYBOX tables applied to instances

-- A Config value as the property wants it: { r, g, b } -> Color3, the LightingStyle name -> its EnumItem.
local function value(prop: string, v: any): any
	if type(v) == "table" then
		return Color3.fromRGB(v[1], v[2], v[3])
	end
	if prop == "LightingStyle" and type(v) == "string" then
		local ok, item = pcall(function()
			return (Enum :: any).LightingStyle[v]
		end)
		return if ok then item else nil
	end
	return v
end

local function target(group: string): Instance?
	if group == "Lighting" then
		return Lighting
	end
	return Lighting:FindFirstChild(group)
end

-- One property write; LightingStyle may refuse a script, so every write is guarded.
local function write(inst: Instance, prop: string, v: any): boolean
	if v == nil then
		return false
	end
	return (pcall(function()
		(inst :: any)[prop] = v
	end))
end

-- Lighting is one per client: the recipe state is module-wide (HeistClient makes one director).
local recipe = {
	saved = nil :: { [string]: { [string]: any } }?,
	soft = false,
	bloomOn = true,
	styleOk = nil :: boolean?, -- whether this client could set Lighting.LightingStyle (docs/PERF.md)
}

local function applyRecipe(tier: number)
	local soft = Budget.softToybox(tier)
	if soft and not recipe.soft then
		local saved: { [string]: { [string]: any } } = {}
		for _, group in GROUPS do
			local inst = target(group)
			local props = SOFT[group]
			if not inst or type(props) ~= "table" then
				continue
			end
			local was: { [string]: any } = {}
			for prop, v in props do
				local okRead, current = pcall(function()
					return (inst :: any)[prop]
				end)
				if okRead then
					was[prop] = current
					local okWrite = write(inst, prop, value(prop, v))
					if prop == "LightingStyle" then
						recipe.styleOk = okWrite
					end
				end
			end
			saved[group] = was
		end
		recipe.saved = saved
		recipe.soft = true
	elseif not soft and recipe.soft then
		for group, props in recipe.saved or {} do
			local inst = target(group)
			if inst then
				for prop, was in props do
					write(inst, prop, was)
				end
			end
		end
		recipe.saved = nil
		recipe.soft = false
	end
	local bloomOn = Budget.bloomOn(tier)
	if bloomOn ~= recipe.bloomOn then
		recipe.bloomOn = bloomOn
		local bloom = target("Bloom")
		if bloom and bloom:IsA("BloomEffect") then
			bloom.Enabled = bloomOn
		end
	end
end

type LevelLight = { light: Light, kind: string?, range: number }

local LightDirector = {}

function LightDirector.new(): any
	local director = {}
	local tierNow = 1
	local heroLights: { Light } = {}
	local levelLights: { LevelLight } = {}
	local pools: { SurfaceGui } = {}
	local addedConn: RBXScriptConnection? = nil
	local poolImage: string? = nil

	-- One pool onto the gradient image (no-op until it is known, or when the pool has no "Soft" label).
	local function soften(gui: SurfaceGui)
		local img = gui:FindFirstChild("Soft", true) -- under the pool's "Clip" frame
		if not poolImage or not img or not img:IsA("ImageLabel") then
			return
		end
		img.Image = poolImage
		img.Visible = true
		for _, c in gui:GetDescendants() do
			if c:IsA("Frame") and c.Name == "Ring" then
				c.Visible = false
			end
		end
	end
	Theme.onImage(L.POOL_SOFT.image, function(uri: string)
		poolImage = uri
		for _, gui in pools do
			soften(gui)
		end
	end)

	local function apply()
		local shadows = tierNow < L.SHADOWS_OFF_TIER
		for _, light in heroLights do
			if light.Shadows ~= shadows then
				light.Shadows = shadows
			end
		end
		for _, rec in levelLights do
			local on = Budget.lampOn(tierNow, rec.kind)
			if rec.light.Enabled ~= on then
				rec.light.Enabled = on
			end
			local range = Budget.lightRange(tierNow, rec.range)
			if rec.light.Range ~= range then
				rec.light.Range = range
			end
		end
		local poolsOn = tierNow < L.POOLS_OFF_TIER
		for _, gui in pools do
			if gui.Enabled ~= poolsOn then
				gui.Enabled = poolsOn
			end
		end
	end

	local function bindOne(d: Instance)
		if d:IsA("Light") then
			if d:GetAttribute("EH_HeroShadow") == true then
				table.insert(heroLights, d)
			end
			-- the lamp kind sits on the bulb (Light < LightAt attachment < bulb part)
			local bulb = d:FindFirstAncestorWhichIsA("BasePart")
			local kind = bulb and bulb:GetAttribute("EH_LampKind")
			table.insert(
				levelLights,
				{ light = d, kind = if type(kind) == "string" then kind else nil, range = d.Range }
			)
		elseif d:IsA("SurfaceGui") then
			local host = d.Parent
			if host and host:GetAttribute("EH_Kind") == "lightPool" then
				table.insert(pools, d)
				task.defer(soften, d) -- its children may replicate a frame after it
			end
		end
	end

	function director.clear()
		if addedConn then
			addedConn:Disconnect()
			addedConn = nil
		end
		-- hand the lights back as the server built them (local writes only; the model may be reused)
		for _, rec in levelLights do
			rec.light.Enabled = true
			rec.light.Range = rec.range
		end
		table.clear(heroLights)
		table.clear(levelLights)
		table.clear(pools)
	end

	-- The level model of the current instance (HeistClient binds it with WorldView). Lights that stream or
	-- replicate in later are bound as they arrive.
	function director.bind(levelModel: Instance)
		director.clear()
		for _, d in levelModel:GetDescendants() do
			bindOne(d)
		end
		addedConn = levelModel.DescendantAdded:Connect(function(d: Instance)
			bindOne(d)
			apply()
		end)
		apply()
	end

	-- Hooked to Telemetry.onTier by the caller (1 = quality ... 4 = minimum). The Lighting recipe follows at once,
	-- in the garage too (no level bound there).
	function director.setTier(tier: number)
		tierNow = tier
		applyRecipe(tier)
		apply()
	end

	-- Diagnostics (tests, docs/PERF.md): "A" or "C", and whether LightingStyle took a script write (nil before
	-- recipe C was first applied).
	function director.recipe(): (string, boolean?)
		return if recipe.soft then "C" else "A", recipe.styleOk
	end

	return director
end

return LightDirector
