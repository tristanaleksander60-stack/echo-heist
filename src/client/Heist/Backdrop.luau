--!strict
-- Heist/Backdrop: the world around the active heist instance or the garage (PLAN_STEAM_PLUS §4.1 W4,
-- roblox_quality §2; WORLD 2.0, docs/audit/LEVELS.md §10). Built on the client from the pure
-- Shared/Heist/BackdropPlan (+ TownPlan), so it costs the server nothing and never replicates:
--   L0 the snowfield under everything;
--   L1 the town: the street (pavements, kerbs, a snowy road with tyre tracks), snow over the lot's outdoor floor,
--      the neighbours (lit windows, snowy roofs, shop fronts, garlands and wreaths), street lamps with unlit warm
--      pools (no Light objects), parked cars, decorated trees, snowmen, and the lot fence (invisible colliders);
--   L2 / L3 the skyline rings, drawn flat in a light haze colour;
--   the sky: Lighting.Sky turned so Hoardsworth's tower and the Snow Globe stand in the first view;
--   falling snow in a volume that follows the camera (exterior views only), and snow caps plus a warm window
--   spill on the street side of the kit fronts.
-- The kit pieces (lamps, roofs, cars, trees, snowmen, the Christmas pieces, the rings) are templates server
-- Heist/BackdropKit publishes to ReplicatedStorage/BackdropKit; a piece that has not arrived yet draws its box
-- fallback (if it has one) and is swapped in when the kit is Ready.
-- Static decoration: every part is Anchored with CanCollide / CanQuery / CanTouch / CastShadow off (the lot fence
-- alone collides, for your own character), so the sim, Poppercam and Gus's fan never see it. Tier-aware like
-- Heist/LightDirector (Telemetry.onTier): the far ring goes from Config.Backdrop.FAR_RING_OFF_TIER, props and the
-- Christmas pieces from TOWN.PROPS_OFF_TIER, the pools from TOWN.POOLS_OFF_TIER, the snow halves from SNOW.LOW_TIER
-- and stays under the tier's snowAlive (Shared/Heist/Budget). The snowfield, the streets, every building and its
-- windows stay at every tier: the frame is never black. Reduced motion: the snow falls slower and sparser.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local BackdropPlan = require(Shared:WaitForChild("Heist"):WaitForChild("BackdropPlan"))
local Budget = require(Shared:WaitForChild("Heist"):WaitForChild("Budget"))

local Theme = require(script.Parent:WaitForChild("Theme"))

local B = Config.Backdrop
local S = B.SNOW
local LOC = Config.Lighting.LOCATION
local POOL_IMAGE = Config.Lighting.POOL_SOFT.image

-- Kit fronts (STYLE_BIBLE §5.1 local frame: X [-24, 0] along the front, Y up, -Z the street): the awning slopes
-- and window sills of assets/blender/storefront.py, in Roblox axes. Awning: from the wall (z 0, y 9.75) down to
-- the valance (z -2.4, y 8.7) over x ranges; sills: the top of the street-side sill box.
local AWNINGS = { { -7.65, -0.35 }, { -23.65, -16.35 } }
local AWNING_TOP = { 9.75, 8.7, 2.4 } -- y at the wall, y at the valance, depth out to the street
local SILLS = {
	Storefront_24x12 = { y = 2.25, xs = { { -7.65, -0.35 }, { -23.65, -16.35 } } },
	BankFront_24x12 = { y = 2.65, xs = { { -5.45, -1.55 }, { -22.45, -18.55 } } },
}
local SPILL_DEPTH = B.SPILL_DEPTH -- studs of warm window light on the pavement in front of each display window

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local function box(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, neon: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	quiet(p)
	p.Parent = parent
	return p
end

local function seq(a: number, b: number): NumberRange
	return NumberRange.new(a, b)
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- A layer piece the tier can hide: parts by Transparency (their own base value kept), pool guis by Enabled.
type Shown = { part: BasePart?, gui: SurfaceGui?, layer: string, base: number }

local Backdrop = {}

function Backdrop.new(): any
	local director = {}
	local tierNow = 1
	local reduced = false
	local folder: Folder? = nil
	local farParts: { BasePart } = {}
	local shown: { Shown } = {}
	local pools: { SurfaceGui } = {}
	local footprint: BackdropPlan.Rect? = nil -- world space
	local siteNow: BackdropPlan.Site? = nil
	local originNow = Vector3.zero
	local snowPart: Part? = nil
	local emitter: ParticleEmitter? = nil
	local stepConn: RBXScriptConnection? = nil
	local kitConn: RBXScriptConnection? = nil
	local frontConn: RBXScriptConnection? = nil
	local interior = false
	local lastInteriorCheck = 0
	local buildToken = 0
	local poolUri: string? = nil

	local function track(p: BasePart?, gui: SurfaceGui?, layer: string)
		table.insert(shown, { part = p, gui = gui, layer = layer, base = if p then p.Transparency else 0 })
	end

	local function applyTier()
		local farOn = tierNow < B.FAR_RING_OFF_TIER
		for _, p in farParts do
			p.Transparency = if farOn then 0 else 1
		end
		for _, s in shown do
			local on = BackdropPlan.layerOn(s.layer, tierNow)
			if s.part then
				(s.part :: BasePart).Transparency = if on then s.base else 1
			end
			if s.gui then
				(s.gui :: SurfaceGui).Enabled = on
			end
		end
		if emitter then
			local e = emitter :: ParticleEmitter
			local k = if reduced then S.reducedSpeed else 1
			-- slower flakes live longer to fall as far; rate x lifetime stays under the tier's snowAlive
			-- (Shared/Heist/Budget: 240 at tiers 1-2, 60 at 3, 40 at 4)
			local rate, life =
				Budget.snow(tierNow, BackdropPlan.snowRate(tierNow, reduced, interior), S.lifetime[2] / k)
			e.Rate = rate
			e.Speed = seq(S.speed[1] * k, S.speed[2] * k)
			e.Acceleration = Vector3.new(S.drift[1], S.drift[2], S.drift[3]) * k
			e.RotSpeed = seq(S.rotSpeed[1] * k, S.rotSpeed[2] * k)
			e.Lifetime = if reduced then seq(life * 0.8, life) else seq(math.min(S.lifetime[1], life), life)
		end
	end

	local function makeSnow(parent: Instance)
		local p = Instance.new("Part")
		p.Name = "SnowVolume"
		p.Size = Vector3.new(S.box[1], S.box[2], S.box[3])
		p.Transparency = 1
		quiet(p)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Snow" -- Heist/Particles counts it by this name (HeistClient)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Bottom
		e.SpreadAngle = Vector2.new(S.spread, S.spread)
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, S.size[1]),
			NumberSequenceKeypoint.new(1, S.size[2]),
		})
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, S.transparency),
			NumberSequenceKeypoint.new(0.85, S.transparency),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Color = ColorSequence.new(rgb(S.color))
		e.LightInfluence = S.lightInfluence
		e.LightEmission = S.lightEmission
		e.Rotation = seq(0, 360)
		e.LockedToPart = false
		if S.texture ~= "" then
			e.Texture = S.texture
		end
		e.Parent = p
		p.Parent = parent
		snowPart = p
		emitter = e
	end

	local function follow()
		local cam = workspace.CurrentCamera
		local p = snowPart
		if not cam or not p then
			return
		end
		local focus = cam.Focus.Position
		p.CFrame = CFrame.new(focus + Vector3.new(0, S.above, 0))
		local now = os.clock()
		if now - lastInteriorCheck > 0.25 then
			lastInteriorCheck = now
			local inside = BackdropPlan.inside(footprint, focus.X, focus.Z)
			if inside ~= interior then
				interior = inside
				applyTier()
			end
		end
	end

	-- Snow caps on the awnings (upper share of each slope) and sills, and the warm window spill on the
	-- pavement, on every kit street front in the level model.
	local function dressFront(part: Instance, parent: Instance, spillColor: Color3)
		if not part:IsA("MeshPart") then
			return
		end
		local kind = part:GetAttribute("KitPiece")
		local sill = SILLS[kind :: any]
		if sill == nil then
			return
		end
		local pivot = part:GetPivot()
		local snow = rgb(B.SNOW_COLOR)
		local t = B.SNOW_CAPS.thickness
		if kind == "Storefront_24x12" then
			local y0, y1, depth = AWNING_TOP[1], AWNING_TOP[2], AWNING_TOP[3]
			local len = math.sqrt(depth * depth + (y0 - y1) ^ 2)
			local ang = math.atan2(y0 - y1, depth)
			local share = B.SNOW_CAPS.awningShare
			local dir = Vector3.new(0, -(y0 - y1) / len, -depth / len) -- down the slope, toward the street
			local normal = Vector3.new(0, depth / len, -(y0 - y1) / len)
			for _, xs in AWNINGS do
				local mid = Vector3.new((xs[1] + xs[2]) / 2, y0, 0) + dir * (len * share / 2) + normal * (t / 2)
				local cf = pivot * CFrame.new(mid) * CFrame.Angles(-ang, 0, 0)
				box(parent, "AwningSnow", Vector3.new(xs[2] - xs[1] - 0.1, t, len * share), cf, snow)
			end
		end
		for _, xs in sill.xs do
			local cf = pivot * CFrame.new((xs[1] + xs[2]) / 2, sill.y + t / 2, 0)
			box(parent, "SillSnow", Vector3.new(xs[2] - xs[1], t, 0.6), cf, snow)
			-- the window's light on the pavement: an unlit SurfaceGui pool (roblox_quality §1.2 trick 2)
			local w = xs[2] - xs[1]
			local spill = box(
				parent,
				"WindowSpill",
				Vector3.new(w, 0.05, SPILL_DEPTH),
				pivot * CFrame.new((xs[1] + xs[2]) / 2, 0.07, -0.5 - SPILL_DEPTH / 2),
				spillColor
			)
			spill.Transparency = 1
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Top
			gui.LightInfluence = 0
			gui.Brightness = 1
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 8
			gui.MaxDistance = 250
			local grad = Instance.new("Frame")
			grad.Size = UDim2.fromScale(1, 1)
			grad.BackgroundColor3 = spillColor
			grad.BackgroundTransparency = 1 - B.SPILL_ALPHA
			grad.BorderSizePixel = 0
			local g = Instance.new("UIGradient")
			-- bright at the wall, gone at the kerb (the gradient's Y runs along the part's Z)
			g.Rotation = 90
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = grad
			grad.Parent = gui
			gui.Parent = spill
		end
	end

	-- One town part from the plan (site space -> world).
	local function townPart(parent: Instance, ps: any): Part
		local p = box(parent, ps.name, v3(ps.size), CFrame.new(originNow + v3(ps.pos)), rgb(ps.color), ps.neon)
		if ps.collide then
			-- the lot fence: your own character stops at the lot's edge; cameras and raycasts pass through
			p.Transparency = 1
			p.CanCollide = true
		end
		return p
	end

	-- An unlit warm pool on the snow (roblox_quality §1.2 trick 2): the soft radial gradient once its image has
	-- resolved (UiImages), two soft discs until then.
	local function soften(gui: SurfaceGui)
		local img = gui:FindFirstChild("Soft")
		if not poolUri or not img or not img:IsA("ImageLabel") then
			return
		end
		img.Image = poolUri :: string
		img.Visible = true
		for _, c in gui:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
	end

	local function pool(parent: Instance, pl: any)
		local p = box(
			parent,
			"TownPool",
			Vector3.new(pl.size, 0.05, pl.size),
			CFrame.new(originNow + v3(pl.pos)),
			rgb(pl.color)
		)
		p.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0
		gui.Brightness = 1
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 6
		gui.MaxDistance = 400
		local img = Instance.new("ImageLabel")
		img.Name = "Soft"
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.ImageColor3 = rgb(pl.color)
		img.ImageTransparency = 1 - pl.alpha
		img.Visible = false
		img.Parent = gui
		for k, share in { 1, 0.55 } do
			local d = Instance.new("Frame")
			d.Name = "Disc" .. k
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Position = UDim2.fromScale(0.5, 0.5)
			d.Size = UDim2.fromScale(share, share)
			d.BackgroundColor3 = rgb(pl.color)
			d.BackgroundTransparency = 1 - pl.alpha * (if k == 1 then 0.3 else 0.45)
			d.BorderSizePixel = 0
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = d
			d.Parent = gui
		end
		gui.Parent = p
		table.insert(pools, gui)
		track(nil, gui, "pools")
		soften(gui)
	end

	-- A kit piece from the BackdropKit folder at its pivot (uniform scale or a target size), or nil.
	local function kitPiece(kit: Instance, parent: Instance, k: any): BasePart?
		local template = kit:FindFirstChild(k.piece)
		if not (template and template:IsA("BasePart")) then
			return nil
		end
		local p = (template :: BasePart):Clone()
		quiet(p)
		local base = p.Size
		local scale = Vector3.one
		if k.size then
			scale = v3(k.size) / base
		elseif k.scale then
			scale = Vector3.one * k.scale
		end
		if scale ~= Vector3.one then
			local off = p.PivotOffset
			p.Size = base * scale
			p.PivotOffset = CFrame.new(off.Position * scale) * off.Rotation
		end
		if k.color then
			p.Color = rgb(k.color)
		end
		p:PivotTo(CFrame.new(originNow + v3(k.pos)) * CFrame.Angles(0, math.rad(k.yaw), 0))
		p.Parent = parent
		return p
	end

	local function addRing(ring: any, kit: Instance, parent: Instance)
		for _, name in { ring.piece, ring.windows } do
			local template = kit:FindFirstChild(name)
			if not (template and template:IsA("BasePart")) then
				continue
			end
			for _, yaw in ring.yaws do
				local p = (template :: BasePart):Clone()
				quiet(p)
				if name == ring.piece and ring.color and p:IsA("MeshPart") then
					-- a flat haze silhouette (the atlas's Ink faces read black, LEVELS.md §10)
					p.TextureID = ""
					p.Color = rgb(ring.color)
				end
				p:PivotTo(
					CFrame.new(originNow + Vector3.new(ring.centre[1], ring.centre[2], ring.centre[3]))
						* CFrame.Angles(0, math.rad(yaw), 0)
				)
				p.Parent = parent
				if ring.name == "far" then
					table.insert(farParts, p)
				end
			end
		end
	end

	function director.clear()
		buildToken += 1
		if stepConn then
			stepConn:Disconnect()
			stepConn = nil
		end
		if kitConn then
			kitConn:Disconnect()
			kitConn = nil
		end
		if frontConn then
			frontConn:Disconnect()
			frontConn = nil
		end
		if folder then
			folder:Destroy()
			folder = nil
		end
		table.clear(farParts)
		table.clear(shown)
		table.clear(pools)
		snowPart, emitter = nil, nil
		footprint, siteNow = nil, nil
		interior = false
	end

	local function build(site: BackdropPlan.Site, origin: Vector3, levelModel: Instance?, dressing: boolean?)
		director.clear()
		if not B.ENABLED then
			return
		end
		local token = buildToken
		siteNow = site
		originNow = origin
		local fp = site.footprint
		footprint = if fp
			then {
				minX = fp.minX + origin.X,
				maxX = fp.maxX + origin.X,
				minZ = fp.minZ + origin.Z,
				maxZ = fp.maxZ + origin.Z,
			}
			else nil
		local f = Instance.new("Folder")
		f.Name = "EH_Backdrop"
		folder = f
		makeSnow(f) -- first: Heist/Particles finds the "Snow" emitter by name
		local plan = BackdropPlan.plan(site, dressing)
		for _, ps in plan.parts do
			local p = townPart(f, ps)
			if ps.layer ~= "fence" then
				track(p, nil, ps.layer)
			end
		end
		for _, pl in plan.pools do
			pool(f, pl)
		end
		-- the kit pieces and the rings: now if the kit is published, else their fallbacks until it arrives
		local fallbacks: { [number]: BasePart } = {}
		local placed: { [number]: boolean } = {}
		for i, k in plan.kit do
			if k.fallback then
				local p = townPart(f, k.fallback)
				fallbacks[i] = p
				track(p, nil, k.layer)
			end
		end
		local ringsDone = false
		local function addKit(): boolean
			local kit = ReplicatedStorage:FindFirstChild(B.KIT_FOLDER)
			if token ~= buildToken or not kit or kit:GetAttribute("Ready") ~= true then
				return false
			end
			for i, k in plan.kit do
				if placed[i] then
					continue
				end
				local p = kitPiece(kit, f, k)
				if p then
					placed[i] = true
					track(p, nil, k.layer)
					local fb = fallbacks[i]
					if fb then
						fb:Destroy()
						fallbacks[i] = nil
					end
				end
			end
			if not ringsDone then
				ringsDone = true
				for _, ring in plan.rings do
					addRing(ring, kit, f)
				end
			end
			applyTier()
			return true
		end
		if not addKit() then
			task.spawn(function()
				local kit = ReplicatedStorage:WaitForChild(B.KIT_FOLDER, B.KIT_WAIT_SECONDS)
				if not kit or token ~= buildToken or addKit() then
					return
				end
				kitConn = kit:GetAttributeChangedSignal("Ready"):Connect(function()
					if addKit() and kitConn then
						kitConn:Disconnect()
						kitConn = nil
					end
				end)
			end)
		end
		-- the kit fronts: snow caps and window spill (the kit may dress the level a moment later)
		if levelModel then
			local loc = levelModel:GetAttribute("Location")
			local look = loc and LOC[loc :: any]
			local spill = if look then rgb(look.room[1]) else rgb(Config.Lighting.LAMP.room.color)
			for _, d in levelModel:GetDescendants() do
				dressFront(d, f, spill)
			end
			frontConn = levelModel.DescendantAdded:Connect(function(d: Instance)
				if token == buildToken then
					dressFront(d, f, spill)
				end
			end)
		end
		-- the sky: Hoardsworth's tower in the first view
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			pcall(function()
				sky.SkyboxOrientation = Vector3.new(0, BackdropPlan.skyYaw(site), 0)
			end)
		end
		f.Parent = workspace
		-- (perf_engine builds this on a server, where RenderStepped does not exist: the snow just stays put there)
		stepConn = if RunService:IsClient() then RunService.RenderStepped:Connect(follow) else nil
		applyTier()
	end

	Theme.onImage(POOL_IMAGE, function(uri: string)
		poolUri = uri
		for _, gui in pools do
			soften(gui)
		end
	end)

	-- The heist instance's level (compiled LevelSpec) at its origin; levelModel = the instance's Level model;
	-- dressing = the instance's Christmas layer.
	function director.showHeist(levelModel: Instance?, level: any, origin: Vector3, dressing: boolean?)
		if level == nil then
			director.clear()
			return
		end
		local loc = levelModel and levelModel:GetAttribute("Location")
		build(BackdropPlan.levelSite(level, if type(loc) == "string" then loc else nil), origin, levelModel, dressing)
	end

	function director.showGarage()
		build(BackdropPlan.garageSite(), Vector3.zero, nil, nil)
	end

	-- Hooked to Telemetry.onTier by the caller (1 = quality ... 4 = minimum).
	function director.setTier(tier: number)
		tierNow = tier
		applyTier()
	end

	function director.setReducedMotion(on: boolean)
		reduced = on
		applyTier()
	end

	function director.site(): BackdropPlan.Site?
		return siteNow
	end

	return director
end

return Backdrop
