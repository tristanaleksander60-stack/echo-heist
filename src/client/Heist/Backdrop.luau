--!strict
-- Heist/Backdrop: the world around the active heist instance or the garage (PLAN_STEAM_PLUS §4.1 W4,
-- roblox_quality §2). Built on the client from the pure Shared/Heist/BackdropPlan, so it costs the server
-- nothing and never replicates:
--   L0 a ground plane under the lot, dropped below the floor, that the Atmosphere fades into haze, and a kerb;
--   L1 a near ring of facade cards (body, marble cornice, snow on it, warm lit windows);
--   L2 / L3 the skyline rings (kit meshes from ReplicatedStorage/BackdropKit, four quarter copies each);
--   the sky: Lighting.Sky turned so Hoardsworth's tower and the Snow Globe stand in the first view;
--   falling snow in a volume that follows the camera (exterior views only), and snow caps plus a warm window
--   spill on the street side of the kit fronts.
-- Static decoration: every part is Anchored with CanCollide / CanQuery / CanTouch / CastShadow off, so the sim,
-- Poppercam and Gus's fan never see it. No searchlights. Tier-aware like Heist/LightDirector (Telemetry.onTier):
-- the far ring goes from Config.Backdrop.FAR_RING_OFF_TIER, facade windows from FACADE_WINDOWS_OFF_TIER, the snow
-- halves from SNOW.LOW_TIER. Reduced motion: the snow falls slower and sparser, never off.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local BackdropPlan = require(Shared:WaitForChild("Heist"):WaitForChild("BackdropPlan"))

local B = Config.Backdrop
local S = B.SNOW
local LOC = Config.Lighting.LOCATION

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

local Backdrop = {}

function Backdrop.new(): any
	local director = {}
	local tierNow = 1
	local reduced = false
	local folder: Folder? = nil
	local farParts: { BasePart } = {}
	local windowParts: { BasePart } = {}
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

	local function applyTier()
		local farOn = tierNow < B.FAR_RING_OFF_TIER
		for _, p in farParts do
			p.Transparency = if farOn then 0 else 1
		end
		local winOn = tierNow < B.FACADE_WINDOWS_OFF_TIER
		for _, p in windowParts do
			p.Transparency = if winOn then 0 else 1
		end
		if emitter then
			local e = emitter :: ParticleEmitter
			e.Rate = BackdropPlan.snowRate(tierNow, reduced, interior)
			local k = if reduced then S.reducedSpeed else 1
			e.Speed = seq(S.speed[1] * k, S.speed[2] * k)
			e.Acceleration = Vector3.new(S.drift[1], S.drift[2], S.drift[3]) * k
			e.RotSpeed = seq(S.rotSpeed[1] * k, S.rotSpeed[2] * k)
			-- slower flakes live longer to fall as far; rate x lifetime stays under SNOW.maxAlive
			local life = if reduced then math.min(S.lifetime[2] / k, S.maxAlive / math.max(e.Rate, 1)) else nil
			e.Lifetime = if life then seq(life * 0.8, life) else seq(S.lifetime[1], S.lifetime[2])
		end
	end

	local function makeSnow(parent: Instance)
		local p = Instance.new("Part")
		p.Name = "SnowVolume"
		p.Size = Vector3.new(S.box[1], S.box[2], S.box[3])
		p.Transparency = 1
		quiet(p)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Snow"
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

	local function addRing(ring: any, kit: Instance, parent: Instance)
		for _, name in { ring.piece, ring.windows } do
			local template = kit:FindFirstChild(name)
			if not (template and template:IsA("BasePart")) then
				continue
			end
			for _, yaw in ring.yaws do
				local p = (template :: BasePart):Clone()
				quiet(p)
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
		table.clear(windowParts)
		snowPart, emitter = nil, nil
		footprint, siteNow = nil, nil
		interior = false
	end

	local function build(site: BackdropPlan.Site, origin: Vector3, levelModel: Instance?)
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
		local plan = BackdropPlan.plan(site)
		for _, ps in plan.parts do
			local p = box(
				f,
				ps.name,
				Vector3.new(ps.size[1], ps.size[2], ps.size[3]),
				CFrame.new(origin + Vector3.new(ps.pos[1], ps.pos[2], ps.pos[3])),
				rgb(ps.color),
				ps.neon
			)
			if ps.layer == "windows" then
				table.insert(windowParts, p)
			end
		end
		-- the skyline rings: now if the kit is published, else when it arrives
		local kit = ReplicatedStorage:FindFirstChild(B.KIT_FOLDER)
		local function rings()
			local k = ReplicatedStorage:FindFirstChild(B.KIT_FOLDER)
			if token ~= buildToken or not k or k:GetAttribute("Ready") ~= true then
				return false
			end
			for _, ring in plan.rings do
				addRing(ring, k, f)
			end
			applyTier()
			return true
		end
		if not rings() then
			local target: Instance = kit or ReplicatedStorage
			kitConn = target:GetAttributeChangedSignal("Ready"):Connect(function()
				if rings() and kitConn then
					kitConn:Disconnect()
					kitConn = nil
				end
			end)
			if kit == nil then
				-- the folder itself has not replicated yet: try again once it does
				task.spawn(function()
					local k = ReplicatedStorage:WaitForChild(B.KIT_FOLDER, B.KIT_WAIT_SECONDS)
					if k and token == buildToken and not rings() and kitConn then
						kitConn:Disconnect()
						kitConn = k:GetAttributeChangedSignal("Ready"):Connect(function()
							rings()
						end)
					end
				end)
			end
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
		makeSnow(f)
		f.Parent = workspace
		stepConn = RunService.RenderStepped:Connect(follow)
		applyTier()
	end

	-- The heist instance's level (compiled LevelSpec) at its origin; levelModel = the instance's Level model.
	function director.showHeist(levelModel: Instance?, level: any, origin: Vector3)
		if level == nil then
			director.clear()
			return
		end
		build(BackdropPlan.levelSite(level), origin, levelModel)
	end

	function director.showGarage()
		build(BackdropPlan.garageSite(), Vector3.zero, nil)
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
