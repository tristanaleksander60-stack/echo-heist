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
-- setExteriorTint (SKY track): the aurora's faint green on the snow, added to OutdoorAmbient over either recipe.
-- INTERIORS (Config.Interior; docs/audit/LEVELS.md §13): the floor pools fade at grazing view angles (in first person a
-- pool ten studs ahead read as painted fog; the room's real light carries the floor there), at full strength again
-- when you look down into one or the camera is above (diorama, classic); and the interior props (EH_Layer "decor")
-- hide from Config.Interior.DECOR_OFF_TIER. The wall washes are lamp kind "wash" (lightKindsOff from tier 2).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Budget = require(Shared:WaitForChild("Heist"):WaitForChild("Budget"))

local Theme = require(script.Parent:WaitForChild("Theme"))

local L = Config.Lighting
local IN = Config.Interior
local FADE = IN.POOL_FADE
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

-- The exterior tint (setExteriorTint, the aurora's light on the snow): a small RGB amount added on top of
-- OutdoorAmbient. `base` is the OutdoorAmbient without it; a recipe switch takes the tint off first, so recipe C
-- saves and restores untinted values, then it goes back on over the new base.
local tint = {
	add = nil :: { number }?,
	base = nil :: Color3?,
	applied = nil :: Color3?,
}

local function tintedOf(base: Color3, add: { number }): Color3
	return Color3.fromRGB(
		math.min(255, math.floor(base.R * 255 + 0.5) + add[1]),
		math.min(255, math.floor(base.G * 255 + 0.5) + add[2]),
		math.min(255, math.floor(base.B * 255 + 0.5) + add[3])
	)
end

local function tintOff()
	if tint.applied and tint.base and Lighting.OutdoorAmbient == tint.applied then
		Lighting.OutdoorAmbient = tint.base
	end
	tint.applied = nil
end

local function tintOn()
	local add = tint.add
	if add == nil then
		return
	end
	local base = Lighting.OutdoorAmbient
	tint.base = base
	local c = tintedOf(base, add)
	Lighting.OutdoorAmbient = c
	tint.applied = c
end

local function applyRecipe(tier: number)
	local soft = Budget.softToybox(tier)
	local switching = soft ~= recipe.soft
	if switching then
		tintOff()
	end
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
	if switching then
		tintOn()
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
type PoolFade = { gui: SurfaceGui, host: BasePart, alpha: number, base: { [GuiObject]: number } }

-- The share of a pool's strength at a view: 1 when the camera is high over it or inside it, down to FADE.min when the
-- camera looks across it at a grazing angle (elevation of the camera over the pool's nearest point, in degrees).
local function fadeAt(cam: Vector3, host: BasePart): number
	local c = host.Position
	local hx, hz = host.Size.X / 2, host.Size.Y / 2 -- the pool part lies flat: its Y runs along world Z
	local dx = math.max(math.abs(cam.X - c.X) - hx, 0)
	local dz = math.max(math.abs(cam.Z - c.Z) - hz, 0)
	local h = cam.Y - c.Y
	local elev = math.deg(math.atan2(h, math.sqrt(dx * dx + dz * dz)))
	local t = math.clamp((elev - FADE.from) / (FADE.to - FADE.from), 0, 1)
	t = t * t * (3 - 2 * t)
	return FADE.min + (1 - FADE.min) * t
end

local LightDirector = {}

function LightDirector.new(): any
	local director = {}
	local tierNow = 1
	local heroLights: { Light } = {}
	local levelLights: { LevelLight } = {}
	local pools: { SurfaceGui } = {}
	local fades: { PoolFade } = {}
	local decor: { { part: BasePart, base: number } } = {}
	local addedConn: RBXScriptConnection? = nil
	local fadeConn: RBXScriptConnection? = nil
	local fadeClock = 0
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
		local decorOn = tierNow < IN.DECOR_OFF_TIER
		for _, d in decor do
			local want = if decorOn then d.base else 1
			if d.part.Transparency ~= want then
				d.part.Transparency = want
			end
		end
	end

	-- One pool at `alpha` of its built strength (the soft image and the fallback discs alike).
	local function writeFade(f: PoolFade, alpha: number)
		if math.abs(alpha - f.alpha) < 0.01 then
			return
		end
		f.alpha = alpha
		for obj, base in f.base do
			local opacity = (1 - base) * alpha
			if obj:IsA("ImageLabel") then
				obj.ImageTransparency = 1 - opacity
			else
				obj.BackgroundTransparency = 1 - opacity
			end
		end
	end

	local function fadeStep(dt: number)
		fadeClock += dt
		if fadeClock < 1 / FADE.hz then
			return
		end
		fadeClock = 0
		local cam = workspace.CurrentCamera
		if cam == nil then
			return
		end
		local at = cam.CFrame.Position
		for _, f in fades do
			if f.host.Parent then
				writeFade(f, fadeAt(at, f.host))
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
			if host and host:GetAttribute("EH_Kind") == "lightPool" and host:IsA("BasePart") then
				table.insert(pools, d)
				local f: PoolFade = { gui = d, host = host, alpha = 1, base = {} }
				table.insert(fades, f)
				task.defer(function() -- its children may replicate a frame after it
					soften(d)
					for _, c in d:GetDescendants() do
						if c:IsA("ImageLabel") and c.Name == "Soft" then
							f.base[c] = c.ImageTransparency
						elseif c:IsA("Frame") and c.Name == "Ring" then
							f.base[c] = c.BackgroundTransparency
						end
					end
				end)
			end
		elseif d:IsA("BasePart") and d:GetAttribute("EH_Layer") == "decor" then
			table.insert(decor, { part = d, base = d.Transparency })
		end
	end

	function director.clear()
		if addedConn then
			addedConn:Disconnect()
			addedConn = nil
		end
		-- hand the lights back as the server built them (local writes only; the model may be reused)
		if fadeConn then
			fadeConn:Disconnect()
			fadeConn = nil
		end
		for _, rec in levelLights do
			rec.light.Enabled = true
			rec.light.Range = rec.range
		end
		for _, f in fades do
			writeFade(f, 1)
		end
		for _, d in decor do
			if d.part.Parent then
				d.part.Transparency = d.base
			end
		end
		table.clear(heroLights)
		table.clear(levelLights)
		table.clear(pools)
		table.clear(fades)
		table.clear(decor)
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
		fadeConn = RunService.Heartbeat:Connect(fadeStep)
		apply()
	end

	-- Tests: the pool fade share at a camera position for a pool part, and the decor parts bound.
	function director.poolFade(at: Vector3, host: BasePart): number
		return fadeAt(at, host)
	end
	function director.decorCount(): number
		return #decor
	end

	-- Hooked to Telemetry.onTier by the caller (1 = quality ... 4 = minimum). The Lighting recipe follows at once,
	-- in the garage too (no level bound there).
	function director.setTier(tier: number)
		tierNow = tier
		applyRecipe(tier)
		apply()
	end

	-- The aurora's faint light on the snow (Heist/Aurora, Config.Aurora.OUTDOOR_ADD): `add` = {r, g, b} (0-255) added
	-- to Lighting.OutdoorAmbient on top of the recipe in force; nil takes it off. Only ever adds, so Ambient <=
	-- OutdoorAmbient still holds. This module stays the only writer of the Lighting service.
	function director.setExteriorTint(add: { number }?)
		tintOff()
		tint.add = if add and (add[1] ~= 0 or add[2] ~= 0 or add[3] ~= 0) then add else nil
		tintOn()
	end

	-- Diagnostics (tests, docs/PERF.md): "A" or "C", and whether LightingStyle took a script write (nil before
	-- recipe C was first applied).
	function director.recipe(): (string, boolean?)
		return if recipe.soft then "C" else "A", recipe.styleOk
	end

	return director
end

return LightDirector
