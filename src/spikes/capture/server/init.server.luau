-- Video capture spike (S3), server side. Builds a small lit stage, one stripped
-- default R15 dummy in ReplicatedStorage (the client clones and walks it), and
-- copies each player's share launch data into an attribute so the client can
-- show whether an invite from PromptShareCapture carried it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CaptureConfig = require(ReplicatedStorage:WaitForChild("CaptureSpike"):WaitForChild("CaptureConfig"))

local PALETTE = {
	inkIndigo = Color3.fromRGB(28, 31, 59),
	plumSlate = Color3.fromRGB(58, 53, 96),
	warmMarble = Color3.fromRGB(216, 200, 168),
	vaultSteel = Color3.fromRGB(124, 134, 166),
	heistGold = Color3.fromRGB(255, 194, 31),
}

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

local function buildStage()
	local stage = Instance.new("Model")
	stage.Name = "CaptureStage"
	local size = 48
	part(stage, {
		Name = "Floor",
		Size = Vector3.new(size, 1, size),
		CFrame = CFrame.new(0, -0.5, 0),
		Color = PALETTE.plumSlate,
	})
	part(stage, {
		Name = "BackWall",
		Size = Vector3.new(size, 16, 1.5),
		CFrame = CFrame.new(0, 8, -size / 2),
		Color = PALETTE.inkIndigo,
	})
	-- Neon stripes give the encoder high-contrast edges to smear if it drops frames
	for i = -3, 3 do
		part(stage, {
			Name = "Stripe",
			Size = Vector3.new(0.6, 12, 0.3),
			CFrame = CFrame.new(i * 5, 7, -size / 2 + 1),
			Color = if i % 2 == 0 then PALETTE.heistGold else PALETTE.vaultSteel,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
	end
	part(stage, {
		Name = "GoldTable",
		Size = Vector3.new(5, 2.5, 3),
		CFrame = CFrame.new(CaptureConfig.RING_CENTER + Vector3.new(0, 1.25, 0)),
		Color = PALETTE.heistGold,
		Material = Enum.Material.Metal,
	})
	local lamp = part(stage, {
		Name = "Lamp",
		Size = Vector3.new(2, 0.4, 2),
		CFrame = CFrame.new(0, 14, 0),
		Color = PALETTE.warmMarble,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Shadows = true
	light.Parent = lamp

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "CaptureSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.01, size / 2 - 5)
	spawn.Color = PALETTE.vaultSteel
	spawn.Duration = 0
	spawn.Parent = stage

	stage.Parent = workspace
end

-- Dummy template: the default grey avatar, stripped and anchored. The client
-- tints, clones and moves it, so a capture records client-side motion like the
-- planned EchoView does.
local function buildTemplate()
	local folder = Instance.new("Folder")
	folder.Name = "CaptureTemplates"
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			Instance.new("HumanoidDescription"),
			Enum.HumanoidRigType.R15
		)
	end)
	if not ok or not rig then
		warn("[S3] dummy rig build failed, the client uses block dummies:", rig)
		folder:SetAttribute("Status", "failed")
		folder.Parent = ReplicatedStorage
		return
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("Decal") or d:IsA("Clothing") or d:IsA("BodyColors") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.EvaluateStateMachine = false
		if not hum:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = hum
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.Transparency = 1
		rig.PrimaryPart = root
	end
	rig.Name = "Dummy"
	rig.Parent = folder
	folder:SetAttribute("Status", "ready")
	folder.Parent = ReplicatedStorage
end

local function onPlayerAdded(player: Player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local launch = if ok and type(joinData) == "table" then joinData.LaunchData else nil
	player:SetAttribute("LaunchData", if type(launch) == "string" and launch ~= "" then launch else "(none)")
end

buildStage()
task.spawn(buildTemplate)
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
