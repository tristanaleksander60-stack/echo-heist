--!strict
-- Heist/LightDirector: the level's lamps by performance tier (PLAN_STEAM_PLUS §4.1 W2, roblox_quality §6.4).
-- Local only: the server builds every lamp (Heist/LevelBuilder: a Light under each "ceilingLamp" bulb, an
-- unlit "lightPool" SurfaceGui on the floor) and never touches them again. From Config.Lighting
-- SHADOWS_OFF_TIER the hero lights (attribute EH_HeroShadow) stop casting shadows; from POOLS_OFF_TIER the
-- floor pools are off. Disable, never delete, so a tier that steps back up restores both. The tier comes from
-- Heist/Telemetry.onTier (the PerfSample governor); this module is its only lighting listener.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local L = Config.Lighting

local LightDirector = {}

function LightDirector.new(): any
	local director = {}
	local tierNow = 1
	local heroLights: { Light } = {}
	local pools: { SurfaceGui } = {}
	local addedConn: RBXScriptConnection? = nil

	local function apply()
		local shadows = tierNow < L.SHADOWS_OFF_TIER
		for _, light in heroLights do
			if light.Shadows ~= shadows then
				light.Shadows = shadows
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
		if d:IsA("Light") and d:GetAttribute("EH_HeroShadow") == true then
			table.insert(heroLights, d)
		elseif d:IsA("SurfaceGui") then
			local host = d.Parent
			if host and host:GetAttribute("EH_Kind") == "lightPool" then
				table.insert(pools, d)
			end
		end
	end

	function director.clear()
		if addedConn then
			addedConn:Disconnect()
			addedConn = nil
		end
		table.clear(heroLights)
		table.clear(pools)
	end

	-- The level model of the current instance (HeistClient binds it with WorldView).
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

	-- Hooked to Telemetry.onTier by the caller (1 = quality ... 4 = minimum).
	function director.setTier(tier: number)
		tierNow = tier
		apply()
	end

	return director
end

return LightDirector
