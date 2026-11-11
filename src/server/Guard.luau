-- A patrolling guard with a flashlight cone. He catches anyone he can see:
-- real players get sent back to the hideout, echoes get "busted" and vanish.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Guard = {}

local model: Model? = nil
local root: BasePart? = nil
local head: BasePart? = nil
local humanoid: Humanoid? = nil
local alertGui: BillboardGui? = nil
local waypoints: { Vector3 } = {}
local excludeExtra: { Instance } = {}
local cosHalf = math.cos(math.rad(Config.GUARD_VISION_HALF_ANGLE))
local patrolGen = 0 -- bumped by Guard.reset so the old patrol thread stops

local function buildModel(): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(234, 184, 146)
	desc.LeftArmColor = Color3.fromRGB(30, 40, 80)
	desc.RightArmColor = Color3.fromRGB(30, 40, 80)
	desc.TorsoColor = Color3.fromRGB(30, 40, 80)
	desc.LeftLegColor = Color3.fromRGB(20, 22, 30)
	desc.RightLegColor = Color3.fromRGB(20, 22, 30)
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if ok and rig then
		return rig
	end
	-- Fallback: a simple block guard so the prototype still runs.
	local m = Instance.new("Model")
	local r = Instance.new("Part")
	r.Name = "HumanoidRootPart"
	r.Size = Vector3.new(2, 5, 1)
	r.Color = Color3.fromRGB(30, 40, 80)
	r.Parent = m
	local h = Instance.new("Part")
	h.Name = "Head"
	h.Size = Vector3.new(1.4, 1.4, 1.4)
	h.Parent = m
	local w = Instance.new("WeldConstraint")
	w.Part0 = r
	w.Part1 = h
	h.CFrame = r.CFrame * CFrame.new(0, 3.2, 0)
	w.Parent = r
	local hum = Instance.new("Humanoid")
	hum.Parent = m
	m.PrimaryPart = r
	return m
end

local function patrol(gen: number)
	local i = 1
	while model and model.Parent and humanoid and gen == patrolGen do
		i = i % #waypoints + 1
		humanoid:MoveTo(waypoints[i])
		local arrived = false
		local conn = humanoid.MoveToFinished:Connect(function()
			arrived = true
		end)
		local t0 = os.clock()
		while not arrived and os.clock() - t0 < 8 and gen == patrolGen do
			task.wait(0.1)
		end
		conn:Disconnect()
		task.wait(0.6) -- look around at each corner
	end
end

function Guard.init(levelInfo: any)
	waypoints = levelInfo.guardWaypoints
	excludeExtra = { levelInfo.plateA, levelInfo.plateB, levelInfo.deliverZone }
	for _, beam in levelInfo.laserParts do
		table.insert(excludeExtra, beam)
	end

	local m = buildModel()
	m.Name = "Guard"
	humanoid = m:FindFirstChildOfClass("Humanoid")
	local foundRoot = m:FindFirstChild("HumanoidRootPart")
	local foundHead = m:FindFirstChild("Head")
	assert(humanoid and foundRoot and foundRoot:IsA("BasePart"), "guard rig missing parts")
	root = foundRoot
	head = if foundHead and foundHead:IsA("BasePart") then foundHead else foundRoot
	humanoid.WalkSpeed = Config.GUARD_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	m:PivotTo(CFrame.new(waypoints[1]))
	m.Parent = levelInfo.folder
	root:SetNetworkOwner(nil)

	-- Flashlight
	local light = Instance.new("SpotLight")
	light.Angle = Config.GUARD_VISION_HALF_ANGLE * 2
	light.Range = Config.GUARD_VISION_RANGE
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 245, 200)
	light.Face = Enum.NormalId.Front
	light.Parent = head

	-- "!" alert bubble
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 80)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.Enabled = false
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 60, 60)
	t.TextStrokeTransparency = 0
	t.Text = "!"
	t.Parent = gui
	gui.Parent = head
	alertGui = gui

	model = m

	task.spawn(patrol, patrolGen)
end

-- New loop: restart the patrol from the first waypoint so echoes replay
-- against the same guard timing their recording saw.
function Guard.reset()
	if not (model and root and humanoid) then
		return
	end
	patrolGen += 1
	root.AssemblyLinearVelocity = Vector3.zero
	model:PivotTo(CFrame.new(waypoints[1]))
	task.spawn(patrol, patrolGen)
end

function Guard.alert()
	if alertGui then
		alertGui.Enabled = true
		task.delay(1.2, function()
			if alertGui then
				alertGui.Enabled = false
			end
		end)
	end
end

-- Returns actors the guard can currently see.
function Guard.scan(actors: { any }, extraExclude: { Instance }): { any }
	if not (model and root and head) then
		return {}
	end
	local origin = head.Position
	local look = root.CFrame.LookVector
	local exclude = { model }
	for _, inst in extraExclude do
		table.insert(exclude, inst)
	end
	for _, inst in excludeExtra do
		table.insert(exclude, inst)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local seen = {}
	for _, a in actors do
		local target = a.root.Position + Vector3.new(0, 1, 0)
		local offset = target - origin
		local dist = offset.Magnitude
		if dist > 0.1 and dist <= Config.GUARD_VISION_RANGE then
			if offset.Unit:Dot(look) >= cosHalf then
				-- Anything hit between the guard and the target is a wall.
				local hit = workspace:Raycast(origin, offset, params)
				if hit == nil then
					table.insert(seen, a)
				end
			end
		end
	end
	return seen
end

return Guard
