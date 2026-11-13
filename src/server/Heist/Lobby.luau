--!strict
-- Heist/Lobby: the garage v1 (MASTERPLAN §3.3, §6.6; PLAN_STEAM_PLUS §4.1 W6; docs/GOLDEN_FRAMES.md G3): the shared
-- room where every crew's van is parked and new players spawn. Level select and crews stay UI
-- (src/client/Heist/Hud/Garage); heist instances are built far away (Config.Heist.INSTANCE_SPACING).
--
-- The layout is the pure Heist/LobbyPlan (Config.Lobby). Lobby.build() makes the greybox at once (floor, brick-
-- coloured walls with the roll-up door gap, a box van per bay in its paint, the work-lamp lights and pools, the
-- GarageSpawn) so the garage works before the art kit loads; with the kit (Lobby.build(KitService)) a background
-- task dresses it when the kit is ready: kit walls and floor in the Corner Shop atlas, the GarageDoor_16x12 half
-- open onto the snowy street, 8 kit vans (Van_Paint in each bay's colour), Lamp_Ceiling work lamps, the JobBoard
-- with its glowing NEXT card (client Heist/JobBoard writes each player's own next job on it: visual only, no
-- remote), the trophies on your van's shelf, snow drifts at the door. The kit is never the collision: the greybox
-- walls, floor and van boxes stay as the colliders (invisible once dressed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Strings = require(Shared:WaitForChild("Heist"):WaitForChild("Strings"))
local JobCard = require(Shared:WaitForChild("Heist"):WaitForChild("JobCard"))
local Catalog = require(Shared:WaitForChild("Levels"):WaitForChild("Catalog"))

local KitPlan = require(script.Parent:WaitForChild("KitPlan"))
local LobbyPlan = require(script.Parent:WaitForChild("LobbyPlan"))

local Lobby = {}

local C = Config.Lobby
local LIGHT = Config.Lighting

local built: Model? = nil
local spawnCFrame = CFrame.new()
local dressed = false
local greyVisuals: { BasePart } = {} -- greybox parts the kit replaces (hidden once dressed; colliders keep colliding)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function boxPart(parent: Instance, name: string, origin: Vector3, b: any, color: Color3): BasePart
	local size = Vector3.new(b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ)
	local centre = Vector3.new((b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2, (b.minZ + b.maxZ) / 2)
	return part(parent, name, size, CFrame.new(origin + centre), color)
end

local function visualOnly(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
end

-- A light (PointLight, or the shadowed SpotLight over your bay) and its unlit floor pool, like the heist lamps.
local function lamp(parent: Instance, origin: Vector3, l: any, index: number)
	local holder = part(
		parent,
		"WorkLamp",
		Vector3.one * LIGHT.BULB_SIZE,
		CFrame.new(origin + Vector3.new(l.x, l.y + 0.75, l.z)),
		rgb(LIGHT.BULB_COLOR)
	)
	holder.Shape = Enum.PartType.Ball
	holder.Material = Enum.Material.Neon
	holder.CastShadow = false
	visualOnly(holder)
	holder:SetAttribute("EH_Kind", "garageLamp")
	holder:SetAttribute("EH_Index", index)
	holder:SetAttribute("EH_LampKind", l.kind)
	if l.kind == "trophy" or l.kind == "yours" then
		holder.Transparency = 1 -- the shelf lamp and your bay's key spot have no fixture to see
	elseif l.kind == "work" or l.kind == "aisle" or l.kind == "street" then
		table.insert(greyVisuals, holder) -- the kit fixture (Lamp_Ceiling / StreetLamp) carries its own bulb
	end
	local at = Instance.new("Attachment")
	at.Name = "LightAt"
	at.Position = Vector3.new(0, -0.75, 0)
	at.Parent = holder
	local light: Light
	if l.angle then
		local spot = Instance.new("SpotLight")
		spot.Angle = l.angle
		spot.Face = Enum.NormalId.Bottom
		light = spot
	else
		light = Instance.new("PointLight")
	end
	light.Range = l.range
	light.Brightness = l.brightness
	light.Color = rgb(l.color)
	light.Shadows = l.shadows == true
	if l.shadows then
		light:SetAttribute("EH_HeroShadow", true)
	end
	light.Parent = at
	if not l.pool then
		return
	end
	local pc = LIGHT.POOL
	local pool = part(
		parent,
		"LightPool",
		Vector3.new(l.pool, 0.05, l.pool),
		CFrame.new(origin + Vector3.new(l.x, pc.lift, l.z)),
		rgb(l.poolColor or pc.color)
	)
	pool.Transparency = 1
	pool.CastShadow = false
	visualOnly(pool)
	pool:SetAttribute("EH_Kind", "lightPool")
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Pool"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = pc.brightness
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pc.pixelsPerStud
	gui.MaxDistance = 250
	-- soft falloff (Config.Lighting.POOL_SOFT), as the heist pools: the gradient image once resolved, else soft discs
	local rings = (if l.kind == "street" then LIGHT.LAMP.street.poolRings else LIGHT.LAMP.room.poolRings) or pc.rings
	local soft = LIGHT.POOL_SOFT
	local uri = game:GetService("ReplicatedStorage"):GetAttribute("EH_UiImage_" .. soft.image)
	local hasImage = type(uri) == "string" and uri ~= ""
	for _, ring in KitPlan.poolRings(rings, soft) do
		local f = Instance.new("Frame")
		f.Name = "Ring"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(ring.size, ring.size)
		f.BackgroundColor3 = rgb(l.poolColor or pc.color)
		f.BackgroundTransparency = ring.alpha
		f.BorderSizePixel = 0
		f.Visible = not hasImage
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = gui
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Soft"
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.Image = if hasImage then uri :: string else ""
	img.ImageColor3 = rgb(l.poolColor or pc.color)
	img.ImageTransparency = 1 - KitPlan.poolPeak(rings, soft)
	img.Visible = hasImage
	img.Parent = gui
	gui.Parent = pool
end

-- The NEXT card on the job board: a thin dark plate with a glowing SurfaceGui (LightInfluence 0). The server writes
-- the first job; each client rewrites it with its own next job (client Heist/JobBoard, EH_Kind "jobCard").
local function jobCard(parent: Instance, origin: Vector3, card: any)
	local B = C.BOARD
	local size = card.size
	local cf = CFrame.new(origin + Vector3.new(card.centre[1], card.centre[2], card.centre[3]))
		* CFrame.Angles(0, math.rad(card.yaw), 0)
	local p = part(parent, "JobCard", Vector3.new(size[1], size[2], B.cardDepth), cf, rgb(B.cardColor))
	visualOnly(p)
	p.CastShadow = false
	p:SetAttribute("EH_Kind", "jobCard")
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Card"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = B.glowBrightness
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.MaxDistance = 120
	local function label(name: string, y: number, h: number, text: string)
		local t = Instance.new("TextLabel")
		t.Name = name
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0.06, y)
		t.Size = UDim2.fromScale(0.88, h)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = rgb(B.textColor)
		t.Text = text
		t.Parent = gui
	end
	label("Kicker", 0.08, 0.26, Strings.JOB_BOARD_NEXT)
	label("Title", 0.38, 0.52, JobCard.first(Catalog))
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(B.textColor)
	stroke.Thickness = 4
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local frame = Instance.new("Frame")
	frame.Name = "Edge"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	stroke.Parent = frame
	frame.Parent = gui
	gui.Parent = p
end

-- The warehouse (Config.Lobby.WAREHOUSE, LobbyPlan.warehouse): the shell over the ground course, the roof and its
-- skylights, the mezzanine and its stair (the deck, posts, rail, guards and the stair's wedge collide), the stations'
-- dressing, all in Garage/Overhead's cut-away groups or the garage itself; and the LOBBY track's anchors
-- (Garage/Anchors: invisible, non-colliding Parts whose CFrame is the station's spot, LookVector its facing).
local overheadModel: Model? = nil
local groupModels: { [string]: Model } = {}

local MATERIALS: { [string]: Enum.Material } = {
	Neon = Enum.Material.Neon,
	Glass = Enum.Material.Glass,
	Brick = Enum.Material.Brick,
	Wood = Enum.Material.WoodPlanks,
	Metal = Enum.Material.Metal,
}

local function buildWarehouse(model: Model, origin: Vector3, plan: any)
	local over = Instance.new("Model")
	over.Name = "Overhead"
	over:SetAttribute("EH_Kind", "overhead")
	over:SetAttribute("Style", "Warehouse")
	over:SetAttribute("FloorY", origin.Y)
	over:SetAttribute("CeilY", origin.Y + plan.ceilY)
	over:SetAttribute("TopY", origin.Y + plan.topY)
	local b = plan.bounds
	over:SetAttribute("OuterMin", origin + Vector3.new(plan.interior.minX - C.WALL_T, 0, plan.interior.minZ - C.WALL_T))
	over:SetAttribute("OuterMax", origin + Vector3.new(plan.interior.maxX + C.WALL_T, plan.topY, b.maxZ))
	for _, g in plan.groups do
		local m = Instance.new("Model")
		m.Name = g.name
		m:SetAttribute("EH_CutKind", g.kind)
		m:SetAttribute("EH_CutMin", origin + Vector3.new(g.box.minX, g.box.minY, g.box.minZ))
		m:SetAttribute("EH_CutMax", origin + Vector3.new(g.box.maxX, g.box.maxY, g.box.maxZ))
		if g.normal then
			m:SetAttribute("EH_CutNormal", Vector3.new(g.normal[1], 0, g.normal[2]))
			m:SetAttribute("EH_CutPlane", g.plane + (if g.normal[1] ~= 0 then origin.X else origin.Z))
		end
		m.Parent = over
		groupModels[g.name] = m
	end
	for _, ps in plan.parts do
		local p: BasePart = if ps.wedge then Instance.new("WedgePart") else Instance.new("Part")
		p.Name = ps.name
		p.Anchored = true
		p.Size = Vector3.new(ps.size[1], ps.size[2], ps.size[3])
		p.CFrame = CFrame.new(origin + Vector3.new(ps.pos[1], ps.pos[2], ps.pos[3]))
			* CFrame.Angles(0, math.rad(ps.yaw or 0), 0)
		p.Color = rgb(ps.color)
		p.Material = MATERIALS[ps.material or ""] or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Transparency = ps.alpha or 0
		p.CastShadow = false
		if ps.collide then
			p.CanCollide = true
			p.CanTouch = false
			p.CanQuery = true
			p:SetAttribute("EH_Kind", "garageCollider")
		else
			visualOnly(p)
		end
		if ps.gui then
			local gui = Instance.new("SurfaceGui")
			gui.Name = "Sign"
			gui.Face = (Enum.NormalId :: any)[ps.gui.face]
			gui.LightInfluence = 0
			gui.Brightness = 1.3
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 30
			gui.MaxDistance = 200
			local tl = Instance.new("TextLabel")
			tl.BackgroundTransparency = 1
			tl.Position = UDim2.fromScale(0.06, 0.12)
			tl.Size = UDim2.fromScale(0.88, 0.76)
			tl.Font = Enum.Font.FredokaOne
			tl.TextScaled = true
			tl.TextColor3 = rgb(ps.gui.color)
			tl.Text = ps.gui.text
			tl.Parent = gui
			gui.Parent = p
		end
		p.Parent = if ps.group then groupModels[ps.group] else model
		-- the greybox stand-ins the kit replaces once it dresses the garage (the clerestory, trusses, the rail)
		if ps.name == "Clerestory" or ps.name == "Truss" or ps.name == "MezzanineRail" then
			table.insert(greyVisuals, p)
		end
	end
	over.Parent = model
	overheadModel = over
	-- the anchors (named Parts: what the LOBBY track builds its stations on)
	local anchors = Instance.new("Model")
	anchors.Name = "Anchors"
	for _, a in plan.anchors do
		local p = Instance.new("Part")
		p.Name = a.name
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(origin + Vector3.new(a.x, a.y, a.z)) * CFrame.Angles(0, math.rad(a.yaw), 0)
		p.Transparency = 1
		p.Color = Palette.floor
		p.CastShadow = false
		visualOnly(p)
		p:SetAttribute("EH_Kind", "garageAnchor")
		p.Parent = anchors
	end
	anchors.Parent = model
end

-- The garage greybox (works without the kit) and its lights. Idempotent. kit: src/server/Kit/KitService (optional):
-- the garage is dressed with the kit in the background once it is ready.
function Lobby.build(kit: any?): Model
	if built then
		return built
	end
	local o = Config.Heist.LOBBY_ORIGIN
	local origin = Vector3.new(o[1], o[2], o[3])
	local plan = LobbyPlan.plan(C, LIGHT, nil, KitPlan, Strings)
	local model = Instance.new("Model")
	model.Name = "Garage"
	-- StreamingEnabled (docs/PERF.md): every player starts here and is put back here after each heist (3,000+
	-- studs from any instance, so Opportunistic streaming may have dropped it): Persistent keeps it whole on every
	-- client, so a return never lands on a floor that is not there and the client's Garage lookups always find it.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model:SetAttribute("EH_Kind", "garage")
	local floor = boxPart(model, "Floor", origin, plan.floor, rgb(C.FLOOR_COLOR))
	floor.Material = Enum.Material.Concrete
	for i, w in plan.walls do
		local wall = boxPart(model, "Wall" .. i, origin, w, rgb(C.WALL_COLOR))
		wall.Material = Enum.Material.Brick
		table.insert(greyVisuals, wall)
	end
	-- vans: bay 1's collider is the part named "Van" (GoldenShots G3 frames it); a box in the bay's paint
	for _, bay in plan.bays do
		local c = bay.collider
		local van = boxPart(model, if bay.index == 1 then "Van" else "Van" .. bay.index, origin, c, rgb(bay.paint))
		van:SetAttribute("EH_Kind", "garageVan")
		van:SetAttribute("EH_Bay", bay.index)
		van:SetAttribute("EH_Yours", bay.yours)
		table.insert(greyVisuals, van)
	end
	for i, line in plan.lines do
		local l = boxPart(model, "BayLine" .. i, origin, line, rgb(C.BAY_LINE.color))
		visualOnly(l)
		l.CastShadow = false
	end
	for _, n in plan.numbers do
		local s = C.BAY_NUMBER.size
		local p = part(
			model,
			"BayNumber" .. n.text,
			Vector3.new(s, 0.05, s),
			CFrame.new(origin + Vector3.new(n.x, 0.045, n.z)) * CFrame.Angles(0, math.rad(n.yaw), 0),
			rgb(C.BAY_LINE.color)
		)
		p.Transparency = 1
		visualOnly(p)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextColor3 = rgb(C.BAY_NUMBER.color)
		t.TextTransparency = 0.25
		t.Text = n.text
		t.Parent = gui
		gui.Parent = p
	end
	for k, l in plan.lamps do
		lamp(model, origin, l, k)
	end
	jobCard(model, origin, plan.card)
	buildWarehouse(model, origin, plan)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GarageSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.2, 12)
	spawn.CFrame = CFrame.new(origin + Vector3.new(plan.spawn[1], 0.1, plan.spawn[2]))
	spawn.Color = Palette.floor
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Transparency = 1 -- the floor (and the kit rug) show through; it still collides and spawns
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = model
	spawnCFrame = CFrame.new(origin + Vector3.new(plan.spawn[1], 4, plan.spawn[2]))
	model.Parent = workspace
	built = model
	if kit ~= nil then
		task.spawn(function()
			local ok = pcall(kit.ready, C.KIT_WAIT_SECONDS)
			if ok and kit.isReady() then
				local okDress, err = pcall(Lobby.dress, kit)
				if not okDress then
					warn("[Lobby] kit dressing failed; the garage stays greybox: " .. tostring(err))
				end
			end
		end)
	end
	return model
end

-- Dresses the built garage with the kit (KitService ready). Returns the number of kit parts placed. Idempotent.
function Lobby.dress(kit: any): number
	local model = built
	if model == nil or dressed then
		return 0
	end
	local report = kit.report and kit.report()
	if not (report and report.ok) then
		return 0
	end
	local specs: { [string]: any } = {}
	for _, name in kit.names() do
		local spec = kit.spec(name)
		if spec then
			specs[name] = spec
		end
	end
	local o = Config.Heist.LOBBY_ORIGIN
	local origin = Vector3.new(o[1], o[2], o[3])
	local plan = LobbyPlan.plan(C, LIGHT, specs, KitPlan, Strings)
	local container = Instance.new("Model")
	container.Name = "Kit"
	container:SetAttribute("EH_Kind", "kit")
	local placed = 0
	for _, it in plan.items do
		for _, name in it.pieces do
			local tinted = name == "Van_Paint" or name == "Facade_8x10_Body"
			local color = if tinted and it.color then rgb(it.color) else nil
			local p = kit.clone(name, { atlas = C.LOCATION, color = color })
			if p then
				local c, size = KitPlan.partFrame(specs[name], it.pivot, it.scale)
				p.Size = Vector3.new(size[1], size[2], size[3])
				p.CFrame = CFrame.new(origin + Vector3.new(c[1], c[2], c[3]))
					* CFrame.Angles(0, math.rad(it.pivot.yaw), 0)
				visualOnly(p)
				if it.role == "van" then
					p:SetAttribute("EH_Bay", it.index)
				end
				-- the warehouse's shell, trusses and mezzanine dressing go in their cut-away group
				local group = it.group and groupModels[it.group]
				if group then
					p.CastShadow = false
				end
				p.Parent = group or container
				placed += 1
			end
		end
	end
	if placed == 0 then
		container:Destroy()
		return 0
	end
	container.Parent = model
	-- the kit covers the greybox looks; the greybox walls and vans stay as the colliders
	for _, p in greyVisuals do
		p.Transparency = 1
		p.CastShadow = false
	end
	dressed = true
	model:SetAttribute("Kit", true)
	return placed
end

-- Where a player is put back when they return to the garage (spread around the spawn).
function Lobby.spawnFor(i: number): CFrame
	local col = (i - 1) % 4
	local row = math.floor((i - 1) / 4)
	return spawnCFrame * CFrame.new((col - 1.5) * 3, 0, row * 3)
end

-- The built garage (nil before Lobby.build) and whether the kit dressed it.
function Lobby.model(): Model?
	return built
end

-- The warehouse's cut-away model (Garage/Overhead) and a station's anchor by name (Garage/Anchors: JobBoardSpot,
-- LaptopSpot, WardrobeSpot, TVSpot, CrewSign, VanBay1..8): its CFrame is the spot, its LookVector the facing.
function Lobby.overhead(): Model?
	return overheadModel
end

function Lobby.anchor(name: string): BasePart?
	local m = built
	local anchors = m and m:FindFirstChild("Anchors")
	local p = anchors and anchors:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

function Lobby.isDressed(): boolean
	return dressed
end

return Lobby
