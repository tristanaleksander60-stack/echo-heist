-- Clone phone bench, client side (spike S1, MASTERPLAN §8.11). Spawns N clones
-- of the local player's avatar in one of the §6.5 looks, walks them on rings
-- (client-drawn, as planned for EchoView) and measures FPS average, 1% low
-- and render stats over a 10 s window. Results collect in a copyable box.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local BenchConfig = require(ReplicatedStorage:WaitForChild("Bench"):WaitForChild("BenchConfig"))
local Looks = require(script:WaitForChild("Looks"))
local Meter = require(script:WaitForChild("Meter"))

type Rig = Looks.Rig
type Look = Looks.Look

local player = Players.LocalPlayer
local COUNTS: { number } = BenchConfig.COUNTS
local LOOKS: { Look } = BenchConfig.LOOKS
local HUES: { Color3 } = BenchConfig.HUES
local PER_GROUP = BenchConfig.CLONES_PER_GROUP

local countIndex = table.find(COUNTS, BenchConfig.START_COUNT) or 1
local lookIndex = 1
local fixedCam = true
local template: Model? = nil
local templateSource = "loading"
local rigs: { Rig } = {}
local rigKind = "none"
local cloneInstances = 0
local groupsUsed = 0
local logged = false
local baseline: { dc: number?, tri: number? } = {}
local results: { string } = {}
local auto: { steps: { { look: number, count: number } }, index: number }? = nil

-- Clone groups: one Model and one persistent Highlight per owner hue -----------

local cloneFolder = Instance.new("Folder")
cloneFolder.Name = "BenchClones"
cloneFolder.Parent = workspace

local groups: { Model } = {}
local highlights: { Highlight } = {}
for g, hue in HUES do
	local group = Instance.new("Model")
	group.Name = "Group" .. g
	local hl = Instance.new("Highlight")
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.OutlineColor = hue
	hl.FillColor = hue
	hl.Enabled = false
	hl.Parent = group
	group.Parent = cloneFolder
	groups[g] = group
	highlights[g] = hl
end

local function groupOf(i: number): number
	return (math.floor((i - 1) / PER_GROUP) % #HUES) + 1
end

-- Stats helpers ----------------------------------------------------------------

local function stat(name: string): number?
	local ok, value = pcall(function()
		return (Stats :: any)[name]
	end)
	if ok and type(value) == "number" then
		return value
	end
	return nil
end

local function memoryMb(): number?
	local ok, value = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	return if ok then value else nil
end

local function fmt(value: number?, pattern: string): string
	return if value then string.format(pattern, value) else "n/a"
end

local function kilo(value: number?): string
	return if value then string.format("%.0fk", value / 1000) else "n/a"
end

local function qualityLevel(): string
	local ok, q = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel
	end)
	return if ok and typeof(q) == "EnumItem" then q.Name else "?"
end

local function deviceLine(): string
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.zero
	return string.format(
		"screen %dx%d  touch %s  quality %s",
		math.floor(size.X),
		math.floor(size.Y),
		if UserInputService.TouchEnabled then "yes" else "no",
		qualityLevel()
	)
end

-- Camera -------------------------------------------------------------------------

local function applyCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if fixedCam then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = BenchConfig.CAMERA_FOV
		camera.CFrame = CFrame.lookAt(BenchConfig.CAMERA_POSITION, BenchConfig.PATH_CENTER + Vector3.new(0, 2, 0))
	else
		camera.CameraType = Enum.CameraType.Custom
	end
end

player.CharacterAdded:Connect(function()
	task.defer(applyCamera)
end)

-- Clones ---------------------------------------------------------------------------

local function rebuild()
	for _, rig in rigs do
		rig.model:Destroy()
	end
	table.clear(rigs)
	local look = LOOKS[lookIndex]
	local n = COUNTS[countIndex]
	rigKind = if n == 0 then "none" else "?"
	for i = 1, n do
		local g = groupOf(i)
		local rig = Looks.build(look, template, HUES[g])
		rig.model.Name = "Clone" .. i
		rig.model.Parent = groups[g]
		Looks.start(rig)
		rigs[i] = rig
		rigKind = rig.kind
	end
	groupsUsed = if n > 0 then math.min(#HUES, math.ceil(n / PER_GROUP)) else 0
	for g, hl in highlights do
		hl.FillTransparency = look.fillTransparency
		hl.OutlineTransparency = look.outlineTransparency
		hl.Enabled = look.highlight and g <= groupsUsed
	end
	cloneInstances = #cloneFolder:GetDescendants()
	logged = false
	Meter.reset()
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}
local TAU = math.pi * 2

RunService.PreRender:Connect(function(dt: number)
	Meter.addFrame(dt)
	if #rigs == 0 then
		return
	end
	local t = os.clock()
	table.clear(parts)
	table.clear(cframes)
	for i, rig in rigs do
		local g = groupOf(i)
		local slot = (i - 1) % PER_GROUP
		local radius = BenchConfig.PATH_RADII[g] or BenchConfig.PATH_RADII[#BenchConfig.PATH_RADII]
		local dir = if g % 2 == 0 then -1 else 1
		local theta = dir * (BenchConfig.WALK_SPEED / radius) * t + slot * (TAU / PER_GROUP) + g * 0.5
		local pos = BenchConfig.PATH_CENTER + Vector3.new(math.cos(theta) * radius, 0, math.sin(theta) * radius)
		local forward = Vector3.new(-math.sin(theta), 0, math.cos(theta)) * dir
		local feet = CFrame.lookAt(pos, pos + forward)
		Looks.pose(rig, feet, t * BenchConfig.MANNEQUIN_STRIDE * TAU + i, parts, cframes)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)

-- UI ---------------------------------------------------------------------------------

local INK = Color3.fromRGB(28, 31, 59)
local MONO = Font.fromEnum(Enum.Font.RobotoMono)

local gui = Instance.new("ScreenGui")
gui.Name = "BenchGui"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

local readout = Instance.new("TextLabel")
readout.Name = "Readout"
readout.AutomaticSize = Enum.AutomaticSize.Y
readout.Size = UDim2.new(1, -140, 0, 0)
readout.Position = UDim2.fromOffset(8, 8)
readout.BackgroundColor3 = INK
readout.BackgroundTransparency = 0.25
readout.TextColor3 = Color3.new(1, 1, 1)
readout.FontFace = MONO
readout.TextSize = 13
readout.TextXAlignment = Enum.TextXAlignment.Left
readout.TextYAlignment = Enum.TextYAlignment.Top
readout.TextWrapped = true
readout.Text = "Clone bench starting..."
local readoutPad = Instance.new("UIPadding")
readoutPad.PaddingLeft = UDim.new(0, 6)
readoutPad.PaddingRight = UDim.new(0, 6)
readoutPad.PaddingTop = UDim.new(0, 4)
readoutPad.PaddingBottom = UDim.new(0, 4)
readoutPad.Parent = readout
local readoutMax = Instance.new("UISizeConstraint")
readoutMax.MaxSize = Vector2.new(420, math.huge)
readoutMax.Parent = readout
readout.Parent = gui

local column = Instance.new("Frame")
column.Name = "Buttons"
column.AnchorPoint = Vector2.new(1, 0)
column.Position = UDim2.new(1, -8, 0, 8)
column.Size = UDim2.fromOffset(120, 0)
column.AutomaticSize = Enum.AutomaticSize.Y
column.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = column
column.Parent = gui

local function makeButton(order: number, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(120, 44)
	b.BackgroundColor3 = Color3.fromRGB(58, 53, 96)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	b.TextSize = 15
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = column
	return b
end

local resultsBox = Instance.new("TextBox")
resultsBox.Name = "Results"
resultsBox.AnchorPoint = Vector2.new(0.5, 0.5)
resultsBox.Position = UDim2.fromScale(0.45, 0.55)
resultsBox.Size = UDim2.new(0.85, -140, 0.7, 0)
resultsBox.BackgroundColor3 = INK
resultsBox.BackgroundTransparency = 0.05
resultsBox.TextColor3 = Color3.new(1, 1, 1)
resultsBox.FontFace = MONO
resultsBox.TextSize = 12
resultsBox.TextXAlignment = Enum.TextXAlignment.Left
resultsBox.TextYAlignment = Enum.TextYAlignment.Top
resultsBox.MultiLine = true
resultsBox.ClearTextOnFocus = false
resultsBox.TextEditable = true -- so a phone can long-press, Select All, Copy
resultsBox.TextWrapped = false
resultsBox.ClipsDescendants = true
resultsBox.Visible = false
resultsBox.Parent = gui

local function resultsText(): string
	local lines = {
		"HEIST YOURSELF clone bench (S1)  " .. DateTime.now():FormatUniversalTime("YYYY-MM-DD HH:mm", "en-us") .. " UTC",
		deviceLine() .. "  avatar " .. templateSource,
		"Long-press > Select All > Copy, or screenshot this box.",
		"look rig  N   fps  1%low worst   dc   +dc  tris  inst  clone  memMB",
	}
	for _, line in results do
		table.insert(lines, line)
	end
	if #results == 0 then
		table.insert(lines, "(no results yet: wait 12 s per setting, or press AUTO)")
	end
	return table.concat(lines, "\n")
end

-- Buttons ----------------------------------------------------------------------------

local countButton: TextButton
local lookButton: TextButton
local camButton: TextButton
local autoButton: TextButton

local function refreshButtons()
	countButton.Text = "N: " .. COUNTS[countIndex]
	lookButton.Text = "LOOK: " .. LOOKS[lookIndex].id
	camButton.Text = if fixedCam then "CAM: FIXED" else "CAM: FREE"
	autoButton.Text = if auto then "STOP AUTO" else "AUTO RUN"
end

local function applyAutoStep()
	local run = auto
	if not run then
		return
	end
	local step = run.steps[run.index]
	lookIndex = step.look
	countIndex = step.count
	rebuild()
	refreshButtons()
end

countButton = makeButton(1, function()
	auto = nil
	countIndex = countIndex % #COUNTS + 1
	rebuild()
	refreshButtons()
end)
lookButton = makeButton(2, function()
	auto = nil
	lookIndex = lookIndex % #LOOKS + 1
	rebuild()
	refreshButtons()
end)
camButton = makeButton(3, function()
	fixedCam = not fixedCam
	applyCamera()
	logged = false
	Meter.reset()
	refreshButtons()
end)
autoButton = makeButton(4, function()
	if auto then
		auto = nil
		refreshButtons()
		return
	end
	-- Baseline (no clones) once, then every look at every N > 0
	local steps = {}
	local zero = table.find(COUNTS, 0)
	if zero then
		table.insert(steps, { look = 1, count = zero })
	end
	for li = 1, #LOOKS do
		for ci, n in COUNTS do
			if n > 0 then
				table.insert(steps, { look = li, count = ci })
			end
		end
	end
	auto = { steps = steps, index = 1 }
	fixedCam = true
	applyCamera()
	resultsBox.Visible = false
	applyAutoStep()
end)
makeButton(5, function()
	resultsBox.Text = resultsText()
	resultsBox.Visible = not resultsBox.Visible
end).Text = "RESULTS"
refreshButtons()

gui.Parent = player:WaitForChild("PlayerGui")

-- Readout and logging -------------------------------------------------------------

local function logResult(summary: Meter.Summary)
	local n = COUNTS[countIndex]
	local dc = stat("SceneDrawcallCount")
	local tri = stat("SceneTriangleCount")
	if n == 0 then
		baseline.dc = dc
		baseline.tri = tri
	end
	local extraDc = if dc and baseline.dc and n > 0 then dc - baseline.dc else nil
	table.insert(
		results,
		string.format(
			"%-4s %-4s %2d %5.1f %5.1f %4.0fms %5s %5s %5s %5s %6d %5s%s",
			LOOKS[lookIndex].id,
			if rigKind == "avatar" then "av" elseif rigKind == "mannequin" then "mq" else "-",
			n,
			summary.avgFps,
			summary.low1Fps,
			summary.worstMs,
			fmt(dc, "%d"),
			fmt(extraDc, "%+d"),
			kilo(tri),
			fmt(stat("InstanceCount"), "%d"),
			cloneInstances,
			fmt(memoryMb(), "%.0f"),
			if fixedCam then "" else " freecam"
		)
	)
	resultsBox.Text = resultsText()
end

local function statusLine(): string
	if Meter.isWarming() then
		return "warming up (changes settle)"
	elseif logged then
		return "DONE, logged (rolling window keeps updating)"
	end
	return string.format("MEASURING %.1f / %d s", Meter.sampledSeconds(), BenchConfig.WINDOW_SECONDS)
end

local function updateReadout()
	local look = LOOKS[lookIndex]
	local n = COUNTS[countIndex]
	local summary = Meter.summary()
	local dc = stat("SceneDrawcallCount")
	local extraDc = if dc and baseline.dc and n > 0 then dc - baseline.dc else nil
	local rigLine = if rigKind == "mannequin" and look.rig == "avatar"
		then "rig FALLBACK mannequin (avatar " .. templateSource .. ")"
		else "rig " .. rigKind .. "  avatar " .. templateSource
	local lines = {
		string.format("CLONE BENCH  N=%d  %s", n, look.name),
		string.format("%s  groups %d  highlights %d", rigLine, groupsUsed, if look.highlight then groupsUsed else 0),
		statusLine() .. (if auto then string.format("  [auto %d/%d]", auto.index, #auto.steps) else ""),
		if summary
			then string.format(
				"fps %.1f avg  1%%low %.1f  worst %.1f ms  (%d frames)",
				summary.avgFps,
				summary.low1Fps,
				summary.worstMs,
				summary.frames
			)
			else "fps -",
		string.format(
			"draw calls %s (%s vs N=0)  tris %s  shadow dc %s",
			fmt(dc, "%d"),
			fmt(extraDc, "%+d"),
			kilo(stat("SceneTriangleCount")),
			fmt(stat("ShadowsDrawcallCount"), "%d")
		),
		string.format(
			"instances %s (clones %d)  mem %s MB",
			fmt(stat("InstanceCount"), "%d"),
			cloneInstances,
			fmt(memoryMb(), "%.0f")
		),
		string.format(
			"render cpu %s gpu %s  frame %s",
			fmt(stat("RenderCPUFrameTime"), "%.2f"),
			fmt(stat("RenderGPUFrameTime"), "%.2f"),
			fmt(stat("FrameTime"), "%.3f")
		),
		deviceLine(),
	}
	readout.Text = table.concat(lines, "\n")
end

local function tick()
	-- The default camera scripts can reset the camera type after a spawn
	local camera = workspace.CurrentCamera
	if fixedCam and camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		applyCamera()
	end
	if not logged and Meter.isComplete() then
		local summary = Meter.summary()
		if summary then
			logged = true
			logResult(summary)
			local run = auto
			if run then
				run.index += 1
				if run.index > #run.steps then
					auto = nil
					refreshButtons()
					resultsBox.Text = resultsText()
					resultsBox.Visible = true
				else
					applyAutoStep()
				end
			end
		end
	end
	updateReadout()
end

-- Template: wait for the server's stripped avatar; until then (or if it fails)
-- the avatar looks use the mannequin, flagged as FALLBACK in the readout.
task.spawn(function()
	local deadline = os.clock() + BenchConfig.TEMPLATE_TIMEOUT
	local folder = ReplicatedStorage:WaitForChild("BenchTemplates", BenchConfig.TEMPLATE_TIMEOUT)
	if not folder then
		templateSource = "FAILED (no template folder)"
		return
	end
	while player.Parent do
		if player:GetAttribute("TemplateStatus") == "failed" then
			templateSource = "FAILED"
			return
		end
		local found = folder:FindFirstChild(tostring(player.UserId))
		if found and found:IsA("Model") then
			template = found
			local source = found:GetAttribute("Source")
			templateSource = if type(source) == "string" then source else "?"
			rebuild()
			return
		end
		if os.clock() > deadline then
			templateSource = "still loading"
		end
		task.wait(0.25)
	end
end)

applyCamera()
rebuild()
while true do
	task.wait(1 / BenchConfig.READOUT_HZ)
	tick()
end
