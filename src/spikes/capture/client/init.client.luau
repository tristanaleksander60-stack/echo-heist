-- Video capture spike (S3, MASTERPLAN §8.11 and §9.3 SAVE CLIP), client side.
-- Records a ~12 s clip of a moving scene with CaptureService:StartVideoCaptureAsync,
-- stops it with StopVideoCapture, then offers the 2026 save and share flows
-- (PromptSaveCapturesToGallery, PromptShareCapture with launch data). A
-- screenshot (TakeScreenshotCaptureAsync) is the SAVE CLIP fallback. Every
-- CaptureService call is wrapped in pcall: the feature is missing on some
-- devices and in Studio, and the panel must say so instead of erroring.
-- Never auto-prompts (§9.3): Save and Share are buttons the owner presses.

local CaptureService = game:GetService("CaptureService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CaptureConfig = require(ReplicatedStorage:WaitForChild("CaptureSpike"):WaitForChild("CaptureConfig"))

local player = Players.LocalPlayer
local TAU = math.pi * 2

type State = "idle" | "starting" | "recording" | "stopping" | "ready" | "failed"

local state: State = "idle"
local lenIndex = 1
local clean = CaptureConfig.CLEAN_DEFAULT
local lastCapture: Instance? = nil
local lastKind = "-"
local recordToken = 0
local recordStart = 0
local recordFrames = 0
local canCapture = "?"
local log: { string } = {}
local sessionStart = os.clock()

local function addLog(text: string)
	local line = string.format("%6.1f  %s", os.clock() - sessionStart, text)
	table.insert(log, line)
	print("[S3] " .. text)
end

local function errText(err: any): string
	local s = tostring(err)
	return if #s > 140 then string.sub(s, 1, 140) .. "..." else s
end

-- Probes ----------------------------------------------------------------------------

local function probeCanCapture()
	-- CanCaptureVideo is in the API dump but not in the public docs; probe it.
	local ok, value = pcall(function()
		return (CaptureService :: any):CanCaptureVideo()
	end)
	canCapture = if ok then tostring(value) else "n/a (" .. errText(value) .. ")"
	addLog("CanCaptureVideo() = " .. canCapture)
end

local function platformName(): string
	local ok, p = pcall(function()
		return UserInputService:GetPlatform()
	end)
	return if ok and typeof(p) == "EnumItem" then p.Name else "?"
end

local function deviceLine(): string
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.zero
	local tenFoot = false
	pcall(function()
		tenFoot = GuiService:IsTenFootInterface()
	end)
	return string.format(
		"platform %s  screen %dx%d  touch %s  keyboard %s  console %s",
		platformName(),
		math.floor(size.X),
		math.floor(size.Y),
		if UserInputService.TouchEnabled then "yes" else "no",
		if UserInputService.KeyboardEnabled then "yes" else "no",
		if tenFoot then "yes" else "no"
	)
end

-- Scene: walking dummies, a spinning vault ring, a caption on dummy 1 -----------

local sceneFolder = Instance.new("Folder")
sceneFolder.Name = "CaptureScene"
sceneFolder.Parent = workspace

type Dummy = { model: Model, root: BasePart, height: number }
local dummies: { Dummy } = {}

local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = CaptureConfig.WALK_ANIM

local ring = Instance.new("Part")
ring.Name = "VaultRing"
ring.Shape = Enum.PartType.Cylinder
ring.Anchored = true
ring.CanCollide = false
ring.CastShadow = false
ring.Size = Vector3.new(0.8, 9, 9)
ring.Color = Color3.fromRGB(124, 134, 166)
ring.Material = Enum.Material.Metal
ring.Parent = sceneFolder
local ringBar = Instance.new("Part")
ringBar.Name = "VaultBar"
ringBar.Anchored = false
ringBar.CanCollide = false
ringBar.Massless = true
ringBar.CastShadow = false
ringBar.Size = Vector3.new(1, 8, 1)
ringBar.Color = Color3.fromRGB(255, 194, 31)
ringBar.Material = Enum.Material.Neon
ringBar.Parent = sceneFolder
local ringWeld = Instance.new("WeldConstraint")
ringWeld.Part0 = ring
ringWeld.Part1 = ringBar
ringBar.CFrame = ring.CFrame * CFrame.new(-0.5, 0, 0)
ringWeld.Parent = ring

local function addCaption(adornee: BasePart)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Caption"
	bb.Size = UDim2.fromOffset(200, 36)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 31, 59)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(61, 232, 255)
	label.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	label.TextScaled = true
	label.Text = CaptureConfig.CAPTION_TEXT
	label.Parent = bb
	bb.Parent = adornee
end

local function blockDummy(hue: Color3): Dummy
	local model = Instance.new("Model")
	model.Name = "BlockDummy"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.CanCollide = false
	root.Size = Vector3.new(2, 3, 1)
	root.Color = hue
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = false
	head.CanCollide = false
	head.Massless = true
	head.Size = Vector3.new(1.4, 1.4, 1.4)
	head.Color = hue
	head.Material = Enum.Material.Neon
	head.CFrame = root.CFrame * CFrame.new(0, 2.3, 0)
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = root
	model.PrimaryPart = root
	return { model = model, root = root, height = 1.5 }
end

local function rigDummy(template: Model, hue: Color3): Dummy?
	local model = template:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Color = hue
			d.Transparency = 0.25
		end
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local height = root.Size.Y / 2 + (if hum then hum.HipHeight else 2)
	return { model = model, root = root, height = height }
end

local function buildDummies(template: Model?)
	for _, d in dummies do
		d.model:Destroy()
	end
	table.clear(dummies)
	for i = 1, CaptureConfig.DUMMY_COUNT do
		local hue = CaptureConfig.HUES[(i - 1) % #CaptureConfig.HUES + 1]
		local dummy = (template and rigDummy(template, hue)) or blockDummy(hue)
		dummy.model.Name = "Dummy" .. i
		dummy.model.Parent = sceneFolder
		dummies[i] = dummy
		if i == 1 then
			addCaption(dummy.root)
		end
		local hum = dummy.model:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			local ok, track = pcall(function()
				return animator:LoadAnimation(walkAnim)
			end)
			if ok and track then
				track.Looped = true
				track:Play(0)
				track:AdjustSpeed(CaptureConfig.WALK_SPEED / CaptureConfig.WALK_ANIM_BASE_SPEED)
			end
		end
	end
	addLog(string.format("scene: %d %s dummies", #dummies, if template then "rig" else "block"))
end

local parts: { BasePart } = {}
local cframes: { CFrame } = {}
local frameTimes: { number } = {}

RunService.PreRender:Connect(function()
	table.insert(frameTimes, os.clock())
	if state == "recording" then
		recordFrames += 1
	end
	local t = os.clock()
	table.clear(parts)
	table.clear(cframes)
	local radius = CaptureConfig.RING_RADIUS
	for i, d in dummies do
		local theta = (CaptureConfig.WALK_SPEED / radius) * t + (i - 1) * (TAU / #dummies)
		local pos = CaptureConfig.RING_CENTER
			+ Vector3.new(math.cos(theta) * radius, d.height, math.sin(theta) * radius)
		local forward = Vector3.new(-math.sin(theta), 0, math.cos(theta))
		table.insert(parts, d.root)
		table.insert(cframes, CFrame.lookAt(pos, pos + forward))
	end
	table.insert(parts, ring)
	table.insert(
		cframes,
		CFrame.new(0, 7, -18) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(t * CaptureConfig.SPIN_RATE, 0, 0)
	)
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end)

local function fps(): number
	local now = os.clock()
	local cutoff = now - CaptureConfig.FPS_WINDOW_SECONDS
	local kept = 0
	for i = 1, #frameTimes do
		if frameTimes[i] >= cutoff then
			kept += 1
			frameTimes[kept] = frameTimes[i]
		end
	end
	for i = #frameTimes, kept + 1, -1 do
		frameTimes[i] = nil
	end
	return kept / CaptureConfig.FPS_WINDOW_SECONDS
end

local function applyCamera()
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = CaptureConfig.CAMERA_FOV
		camera.CFrame = CFrame.lookAt(CaptureConfig.CAMERA_POSITION, CaptureConfig.RING_CENTER + Vector3.new(0, 2, 0))
	end
end

-- UI ------------------------------------------------------------------------------------

local INK = Color3.fromRGB(28, 31, 59)
local MONO = Font.fromEnum(Enum.Font.RobotoMono)

local gui = Instance.new("ScreenGui")
gui.Name = "CaptureGui"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

local panel = Instance.new("TextLabel")
panel.Name = "Panel"
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Size = UDim2.new(1, -230, 0, 0)
panel.Position = UDim2.fromOffset(8, 8)
panel.BackgroundColor3 = INK
panel.BackgroundTransparency = 0.25
panel.TextColor3 = Color3.new(1, 1, 1)
panel.FontFace = MONO
panel.TextSize = 12
panel.TextXAlignment = Enum.TextXAlignment.Left
panel.TextYAlignment = Enum.TextYAlignment.Top
panel.TextWrapped = true
panel.Text = "Capture spike starting..."
local panelPad = Instance.new("UIPadding")
panelPad.PaddingLeft = UDim.new(0, 6)
panelPad.PaddingRight = UDim.new(0, 6)
panelPad.PaddingTop = UDim.new(0, 4)
panelPad.PaddingBottom = UDim.new(0, 4)
panelPad.Parent = panel
local panelMax = Instance.new("UISizeConstraint")
panelMax.MaxSize = Vector2.new(460, math.huge)
panelMax.Parent = panel
panel.Parent = gui

-- Screen caption: tells from the clip whether ScreenGuis are recorded
local screenCaption = Instance.new("TextLabel")
screenCaption.Name = "ScreenCaption"
screenCaption.AnchorPoint = Vector2.new(0.5, 1)
screenCaption.Position = UDim2.new(0.5, 0, 1, -8)
screenCaption.Size = UDim2.fromOffset(300, 28)
screenCaption.BackgroundColor3 = INK
screenCaption.BackgroundTransparency = 0.3
screenCaption.TextColor3 = Color3.fromRGB(255, 194, 31)
screenCaption.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
screenCaption.TextSize = 16
screenCaption.Text = "SCREEN UI CAPTION (is it in the clip?)"
screenCaption.Parent = gui

local recBadge = Instance.new("TextLabel")
recBadge.Name = "RecBadge"
recBadge.AnchorPoint = Vector2.new(0.5, 0)
recBadge.Position = UDim2.new(0.5, 0, 0, 8)
recBadge.Size = UDim2.fromOffset(110, 26)
recBadge.BackgroundColor3 = Color3.fromRGB(200, 30, 60)
recBadge.TextColor3 = Color3.new(1, 1, 1)
recBadge.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
recBadge.TextSize = 15
recBadge.Text = "● REC"
recBadge.Visible = false
recBadge.Parent = gui

local grid = Instance.new("Frame")
grid.Name = "Buttons"
grid.AnchorPoint = Vector2.new(1, 0)
grid.Position = UDim2.new(1, -8, 0, 8)
grid.Size = UDim2.fromOffset(206, 0)
grid.AutomaticSize = Enum.AutomaticSize.Y
grid.BackgroundTransparency = 1
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(100, 40)
gridLayout.CellPadding = UDim2.fromOffset(6, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
grid.Parent = gui

local function makeButton(order: number, text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.BackgroundColor3 = Color3.fromRGB(58, 53, 96)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	b.TextSize = 14
	b.Text = text
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = grid
	return b
end

local function overlayBox(name: string, editable: boolean): TextBox
	local box = Instance.new("TextBox")
	box.Name = name
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.42, 0.55)
	box.Size = UDim2.new(0.8, -200, 0.72, 0)
	box.BackgroundColor3 = INK
	box.BackgroundTransparency = 0.05
	box.TextColor3 = Color3.new(1, 1, 1)
	box.FontFace = MONO
	box.TextSize = 12
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.TextEditable = editable -- editable so a phone can long-press, Select All, Copy
	box.TextWrapped = true
	box.ClipsDescendants = true
	box.Visible = false
	box.Parent = gui
	return box
end

local resultsBox = overlayBox("Results", true)
local checklistBox = overlayBox("Checklist", false)

local CHECKLIST = table.concat({
	"S3 VIDEO CAPTURE: WHAT TO REPORT (one block per device)",
	"1. Device: model, OS version, Roblox app version; PC: Windows/macOS.",
	"2. Header line: CanCaptureVideo = ? and the platform line.",
	"3. RECORD (12 s): start result (Success / NoDeviceSupport / ...)?",
	"   Did the OS ask for a permission? Start latency (log line)?",
	"4. Clip result: Success or TimeLimitReached? Clip length vs 12 s?",
	"   FPS while recording vs idle (log line)?",
	"5. SAVE: did a save prompt appear? Callback true/false? Is the clip",
	"   in Roblox Captures (main menu) and/or the phone gallery?",
	"6. SHARE: did a share sheet appear (phone) or a download (PC)?",
	"   Which apps? Did it carry the video AND an invite link?",
	"7. Watch the clip: smooth? dummies walking? ring spinning?",
	"   3D caption '" .. CaptureConfig.CAPTION_TEXT .. "' visible?",
	"   Bottom SCREEN UI CAPTION and this panel visible? Repeat with",
	"   CLEAN ON: is the panel gone from the clip? Resolution/orientation?",
	"8. LEN 35: does it stop by itself at 30 s (TimeLimitReached)?",
	"9. Fallback: SHOT, then SAVE and SHARE the screenshot. Works?",
	"10. Optional: a friend joins via your shared invite; their panel",
	"   should show launch data " .. CaptureConfig.LAUNCH_DATA .. ".",
	"Do not rotate the phone while recording (ScreenSizeChanged).",
	"Then press RESULTS, long-press > Select All > Copy (or screenshot).",
}, "\n")
checklistBox.Text = CHECKLIST

local function resultsText(): string
	local lines = {
		"HEIST YOURSELF capture spike (S3)  "
			.. DateTime.now():FormatUniversalTime("YYYY-MM-DD HH:mm", "en-us")
			.. " UTC",
		deviceLine(),
		"CanCaptureVideo = " .. canCapture .. "  launch data on join = " .. tostring(player:GetAttribute("LaunchData")),
		"Long-press > Select All > Copy, or screenshot this box.",
		"--- log ---",
	}
	for _, line in log do
		table.insert(lines, line)
	end
	return table.concat(lines, "\n")
end

-- Capture flow ----------------------------------------------------------------------

local function clipSeconds(): number
	return CaptureConfig.CLIP_SECONDS[lenIndex]
end

local function stopRecording(reason: string)
	if state ~= "recording" and state ~= "starting" then
		addLog("STOP ignored (state " .. state .. ")")
		return
	end
	local ok, err = pcall(function()
		CaptureService:StopVideoCapture()
	end)
	if ok then
		state = "stopping"
		addLog(string.format("StopVideoCapture() ok (%s) after %.1f s", reason, os.clock() - recordStart))
	else
		state = "failed"
		addLog("StopVideoCapture() ERROR: " .. errText(err))
	end
end

local function onVideoReady(token: number, result: any, videoCapture: any)
	local resultName = if typeof(result) == "EnumItem" then result.Name else tostring(result)
	local wall = os.clock() - recordStart
	local fpsRec = if wall > 0 then recordFrames / wall else 0
	local length = "?"
	if videoCapture then
		local okLen, len = pcall(function()
			return videoCapture.TimeLength
		end)
		length = if okLen then string.format("%.2f s", len) else "unreadable"
	end
	addLog(
		string.format(
			"clip ready: %s  TimeLength %s  wall %.1f s  fps while recording %.0f%s",
			resultName,
			length,
			wall,
			fpsRec,
			if token ~= recordToken then "  (stale)" else ""
		)
	)
	if videoCapture and typeof(videoCapture) == "Instance" then
		lastCapture = videoCapture
		lastKind = "video " .. length
	end
	if token == recordToken then
		state = if lastCapture == videoCapture and videoCapture ~= nil then "ready" else "failed"
	end
end

local function startRecording()
	if state == "starting" or state == "recording" or state == "stopping" then
		addLog("RECORD ignored (state " .. state .. ")")
		return
	end
	recordToken += 1
	local token = recordToken
	local seconds = clipSeconds()
	state = "starting"
	addLog(string.format("RECORD %d s: calling StartVideoCaptureAsync (fps idle %.0f)", seconds, fps()))
	local called = os.clock()
	recordStart = called
	recordFrames = 0
	task.spawn(function()
		local ok, started = pcall(function()
			return CaptureService:StartVideoCaptureAsync(function(result, videoCapture)
				onVideoReady(token, result, videoCapture)
			end, {})
		end)
		local latency = os.clock() - called
		if token ~= recordToken then
			return
		end
		if not ok then
			state = "failed"
			addLog("StartVideoCaptureAsync ERROR: " .. errText(started))
			return
		end
		local name = if typeof(started) == "EnumItem" then started.Name else tostring(started)
		addLog(string.format("started: %s (returned after %.2f s)", name, latency))
		if started ~= Enum.VideoCaptureStartedResult.Success then
			state = "failed"
			return
		end
		if state == "starting" then
			state = "recording"
		end
		recordStart = os.clock()
		recordFrames = 0
		-- 35 s is past the engine limit on purpose: there we wait for TimeLimitReached
		if seconds <= 30 then
			task.delay(seconds, function()
				if token == recordToken and state == "recording" then
					stopRecording("auto")
				end
			end)
		end
	end)
end

local function saveCapture()
	local capture = lastCapture
	if not capture then
		addLog("SAVE: nothing captured yet")
		return
	end
	addLog("SAVE: PromptSaveCapturesToGallery (" .. lastKind .. ")")
	local ok, err = pcall(function()
		CaptureService:PromptSaveCapturesToGallery({ capture }, function(results)
			local any = false
			for _, accepted in results do
				any = true
				addLog("SAVE result: " .. tostring(accepted))
			end
			if not any then
				addLog("SAVE result: empty table")
			end
		end)
	end)
	if not ok then
		addLog("SAVE ERROR: " .. errText(err))
	end
end

local function shareCapture()
	local capture = lastCapture
	if not capture then
		addLog("SHARE: nothing captured yet")
		return
	end
	addLog("SHARE: PromptShareCapture (" .. lastKind .. ", launch data " .. CaptureConfig.LAUNCH_DATA .. ")")
	local ok, err = pcall(function()
		CaptureService:PromptShareCapture(Content.fromObject(capture), CaptureConfig.LAUNCH_DATA, function()
			addLog("SHARE accepted")
		end, function()
			addLog("SHARE denied / cancelled")
		end)
	end)
	if not ok then
		addLog("SHARE ERROR: " .. errText(err))
	end
end

local function takeScreenshot()
	addLog("SHOT: TakeScreenshotCaptureAsync (UI hidden)")
	local ok, err = pcall(function()
		CaptureService:TakeScreenshotCaptureAsync(function(result, capture)
			local name = if typeof(result) == "EnumItem" then result.Name else tostring(result)
			addLog("SHOT result: " .. name)
			if capture and typeof(capture) == "Instance" then
				lastCapture = capture
				lastKind = "screenshot"
			end
		end, { UICaptureMode = Enum.UICaptureMode.None })
	end)
	if not ok then
		addLog("SHOT ERROR: " .. errText(err))
	end
end

local function setPanelsHidden(hidden: boolean)
	panel.Visible = not hidden
	grid.Visible = not hidden
	if hidden then
		resultsBox.Visible = false
		checklistBox.Visible = false
	end
end

pcall(function()
	CaptureService.CaptureBegan:Connect(function(captureType: Enum.CaptureType)
		addLog("CaptureBegan " .. captureType.Name)
		if captureType == Enum.CaptureType.Video then
			recBadge.Visible = true
			if clean then
				setPanelsHidden(true)
			end
		end
	end)
	CaptureService.CaptureEnded:Connect(function(captureType: Enum.CaptureType)
		addLog("CaptureEnded " .. captureType.Name)
		if captureType == Enum.CaptureType.Video then
			recBadge.Visible = false
			setPanelsHidden(false)
		end
	end)
end)

-- Buttons ---------------------------------------------------------------------------------

local lenButton: TextButton
local cleanButton: TextButton

local function refreshButtons()
	lenButton.Text = "LEN " .. clipSeconds() .. " s"
	cleanButton.Text = if clean then "CLEAN ON" else "CLEAN OFF"
end

makeButton(1, "RECORD", startRecording)
makeButton(2, "STOP", function()
	stopRecording("button")
end)
makeButton(3, "SAVE", saveCapture)
makeButton(4, "SHARE", shareCapture)
makeButton(5, "SHOT", takeScreenshot)
lenButton = makeButton(6, "LEN", function()
	lenIndex = lenIndex % #CaptureConfig.CLIP_SECONDS + 1
	refreshButtons()
end)
cleanButton = makeButton(7, "CLEAN", function()
	clean = not clean
	refreshButtons()
end)
makeButton(8, "CHECKLIST", function()
	resultsBox.Visible = false
	checklistBox.Visible = not checklistBox.Visible
end)
makeButton(9, "RESULTS", function()
	checklistBox.Visible = false
	resultsBox.Text = resultsText()
	resultsBox.Visible = not resultsBox.Visible
end)
refreshButtons()

gui.Parent = player:WaitForChild("PlayerGui")

-- Readout ------------------------------------------------------------------------------

local STATE_HINT: { [string]: string } = {
	idle = "press RECORD",
	starting = "starting (an OS permission prompt may be open)",
	recording = "RECORDING",
	stopping = "stopping, waiting for the clip",
	ready = "clip ready: press SAVE or SHARE",
	failed = "FAILED, see log (SHOT is the fallback)",
}

local function updatePanel()
	local status = STATE_HINT[state] or state
	if state == "recording" then
		status = string.format("RECORDING %.1f / %d s", os.clock() - recordStart, clipSeconds())
	end
	local lines = {
		"S3 VIDEO CAPTURE SPIKE  (CHECKLIST = what to report)",
		deviceLine(),
		"CanCaptureVideo = " .. canCapture .. "   fps " .. string.format("%.0f", fps()),
		"state: " .. status,
		"last capture: " .. lastKind .. "   clean " .. (if clean then "on" else "off"),
		"join launch data: " .. tostring(player:GetAttribute("LaunchData")),
		"--- log ---",
	}
	local first = math.max(1, #log - CaptureConfig.LOG_LINES + 1)
	for i = first, #log do
		table.insert(lines, log[i])
	end
	panel.Text = table.concat(lines, "\n")
end

-- Boot ---------------------------------------------------------------------------------

addLog("boot  " .. deviceLine())
probeCanCapture()
player.CharacterAdded:Connect(function()
	task.defer(applyCamera)
end)
applyCamera()

task.spawn(function()
	local folder = ReplicatedStorage:WaitForChild("CaptureTemplates", CaptureConfig.TEMPLATE_TIMEOUT)
	local template = folder and folder:FindFirstChild("Dummy")
	buildDummies(if template and template:IsA("Model") then template else nil)
end)

while true do
	task.wait(1 / CaptureConfig.READOUT_HZ)
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		applyCamera()
	end
	updatePanel()
end
