-- Clone phone bench, server side (spike S1). The server only builds a lit room
-- and one stripped avatar template per player in ReplicatedStorage; every
-- clone is cloned, moved and animated on the client, as planned for EchoView.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BenchConfig = require(ReplicatedStorage:WaitForChild("Bench"):WaitForChild("BenchConfig"))

local PALETTE = {
	inkIndigo = Color3.fromRGB(28, 31, 59),
	plumSlate = Color3.fromRGB(58, 53, 96),
	warmMarble = Color3.fromRGB(216, 200, 168),
	vaultSteel = Color3.fromRGB(124, 134, 166),
	heistGold = Color3.fromRGB(255, 194, 31),
}
local LAMP_COLOR = Color3.fromRGB(255, 236, 200)

local templateFolder = Instance.new("Folder")
templateFolder.Name = "BenchTemplates"
templateFolder.Parent = ReplicatedStorage

-- Room ---------------------------------------------------------------------

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function buildRoom(): Model
	local room = Instance.new("Model")
	room.Name = "BenchRoom"
	local size = BenchConfig.ROOM_SIZE
	local h = BenchConfig.WALL_HEIGHT
	local half = size / 2

	part(room, {
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = PALETTE.plumSlate,
	})
	part(room, {
		Name = "Table",
		Size = Vector3.new(size + 24, 1, size + 24),
		CFrame = CFrame.new(0, -1.6, 0),
		Color = PALETTE.inkIndigo,
	})
	-- Three walls (cut-away diorama: the camera side is open)
	part(room, {
		Name = "WallN",
		Size = Vector3.new(size, h, 1.5),
		CFrame = CFrame.new(0, h / 2, -half),
		Color = PALETTE.plumSlate,
	})
	part(room, {
		Name = "WallW",
		Size = Vector3.new(1.5, h, size),
		CFrame = CFrame.new(-half, h / 2, 0),
		Color = PALETTE.plumSlate,
	})
	part(room, {
		Name = "WallE",
		Size = Vector3.new(1.5, h, size),
		CFrame = CFrame.new(half, h / 2, 0),
		Color = PALETTE.plumSlate,
	})
	part(room, {
		Name = "Skirting",
		Size = Vector3.new(size, 0.6, 0.4),
		CFrame = CFrame.new(0, 0.3, -half + 0.9),
		Color = PALETTE.vaultSteel,
	})

	-- Steel pillars give occlusion and overdraw behind the clones
	for _, x in { -24, -8, 8, 24 } do
		part(room, {
			Name = "Pillar",
			Size = Vector3.new(2.4, h, 2.4),
			CFrame = CFrame.new(x, h / 2, -half + 6),
			Color = PALETTE.vaultSteel,
		})
	end

	-- Gold table with bars (loot hue) in the middle of the rings
	part(
		room,
		{ Name = "GoldTable", Size = Vector3.new(6, 3, 3), CFrame = CFrame.new(0, 1.5, 0), Color = PALETTE.vaultSteel }
	)
	for i = -2, 2 do
		part(room, {
			Name = "GoldBar",
			Size = Vector3.new(0.9, 0.5, 1.6),
			CFrame = CFrame.new(i * 1.1, 3.25, 0),
			Color = PALETTE.heistGold,
			Material = Enum.Material.Metal,
		})
	end

	-- Warm light pools: a Neon fixture, a marble floor disc and a PointLight.
	-- Only the first HERO_SHADOW_LIGHTS lamps cast shadows (plan: <= 4 per view).
	local lampSpots =
		{ Vector3.new(-18, 12, -12), Vector3.new(18, 12, -12), Vector3.new(-18, 12, 14), Vector3.new(18, 12, 14) }
	for i, pos in lampSpots do
		local fixture = part(room, {
			Name = "LampFixture",
			Size = Vector3.new(2, 0.4, 2),
			CFrame = CFrame.new(pos),
			Color = PALETTE.warmMarble,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
		local light = Instance.new("PointLight")
		light.Range = BenchConfig.LAMP_RANGE
		light.Brightness = BenchConfig.LAMP_BRIGHTNESS
		light.Color = LAMP_COLOR
		light.Shadows = i <= BenchConfig.HERO_SHADOW_LIGHTS
		light.Parent = fixture
		local disc = part(room, {
			Name = "LightPool",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.05, 14, 14),
			CFrame = CFrame.new(pos.X, 0.03, pos.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = PALETTE.warmMarble,
			Transparency = 0.8,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		disc.CanTouch = false
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "BenchSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.01, half - 6)
	spawn.Color = PALETTE.vaultSteel
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Parent = room

	room.Parent = workspace
	return room
end

buildRoom()

-- Avatar templates -----------------------------------------------------------

local KEEP_ACCESSORY = {
	[Enum.AccessoryType.Hair] = true,
	[Enum.AccessoryType.Hat] = true,
}

-- MASTERPLAN §6.5 #2: no SurfaceAppearance, textures, decals, face or layered
-- clothing; at most 2 rigid hair/hat accessories; SmoothPlastic; no shadows.
local function strip(rig: Model)
	local kept = 0
	for _, acc in rig:GetChildren() do
		if acc:IsA("Accessory") then
			local layered = acc:FindFirstChildWhichIsA("WrapLayer", true) ~= nil
			if layered or not KEEP_ACCESSORY[acc.AccessoryType] or kept >= BenchConfig.MAX_ACCESSORIES then
				acc:Destroy()
			else
				kept += 1
			end
		end
	end
	for _, d in rig:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("SurfaceAppearance")
			or d:IsA("Decal")
			or d:IsA("Clothing")
			or d:IsA("ShirtGraphic")
			or d:IsA("BodyColors")
			or d:IsA("WrapTarget")
			or d:IsA("FaceControls")
			or d:IsA("HumanoidDescription") -- build data, not needed once the rig exists
			or d:IsA("ValueBase") -- OriginalSize / scale-type helpers
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Material = Enum.Material.SmoothPlastic
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.CastShadow = false
			d.Massless = true
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.EvaluateStateMachine = false
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		if not hum:FindFirstChildOfClass("Animator") then
			local animator = Instance.new("Animator")
			animator.Parent = hum
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.Transparency = 1
		rig.PrimaryPart = root
	end
	rig:SetAttribute("AccessoriesKept", kept)
end

local function describe(player: Player): (HumanoidDescription?, string)
	if player.UserId > 0 then
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
		end)
		if ok and desc then
			return desc, "avatar"
		end
		warn("[Bench] avatar description failed for", player.Name, desc)
	end
	-- Studio test players have negative ids: use the spawned character's look.
	local deadline = os.clock() + BenchConfig.TEMPLATE_TIMEOUT
	while not player.Character and player.Parent and os.clock() < deadline do
		task.wait(0.25)
	end
	local character = player.Character
	local hum = character and character:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		local ok, desc = pcall(function()
			return hum:GetAppliedDescription()
		end)
		if ok and desc then
			return desc, "applied"
		end
	end
	return nil, "none"
end

local function build(desc: HumanoidDescription): Model?
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and rig then
		return rig
	end
	warn("[Bench] rig build failed:", rig)
	return nil
end

local function prepareTemplate(player: Player)
	local desc, source = describe(player)
	local rig = desc and build(desc)
	if not rig then
		-- Fallback 1: the default grey avatar. Fallback 2 (no rig at all) is the
		-- client's procedural mannequin, signalled by TemplateStatus = "failed".
		source = "default"
		rig = build(Instance.new("HumanoidDescription"))
	end
	if not player.Parent then
		if rig then
			rig:Destroy()
		end
		return
	end
	if not rig then
		player:SetAttribute("TemplateStatus", "failed")
		return
	end
	strip(rig)
	rig.Name = tostring(player.UserId)
	rig:SetAttribute("Source", source)
	rig.Parent = templateFolder
	player:SetAttribute("TemplateStatus", "ready")
end

local function onPlayerAdded(player: Player)
	player:SetAttribute("TemplateStatus", "loading")
	task.spawn(prepareTemplate, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	local rig = templateFolder:FindFirstChild(tostring(player.UserId))
	if rig then
		rig:Destroy()
	end
end)
