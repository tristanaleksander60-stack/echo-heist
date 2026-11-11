-- Echo Heist HUD: loop timer, loot progress, echo count, rewind button,
-- objective hints and big centre messages (REWIND, CAUGHT, HEIST COMPLETE).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local notify = remotes:WaitForChild("Notify") :: RemoteEvent
local requestRewind = remotes:WaitForChild("RequestRewind") :: RemoteEvent

local FONT = Enum.Font.FredokaOne
local WHITE = Color3.new(1, 1, 1)
local ECHO_BLUE = Color3.fromRGB(80, 200, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "EchoHeistHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = FONT
	t.TextColor3 = WHITE
	t.TextStrokeTransparency = 0.4
	t.TextScaled = true
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

-- Top bar ----------------------------------------------------------------
local top = Instance.new("Frame")
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.new(0.5, 0, 0, 8)
top.Size = UDim2.fromOffset(360, 64)
top.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
top.BackgroundTransparency = 0.25
top.Parent = gui
corner(top, 14)

local loopLabel = label(top, {
	Size = UDim2.new(0.45, 0, 1, -12),
	Position = UDim2.fromOffset(12, 6),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "LOOP 1",
	TextColor3 = ECHO_BLUE,
})
local timerLabel = label(top, {
	Size = UDim2.new(0.5, -12, 1, -12),
	Position = UDim2.new(0.5, 0, 0, 6),
	TextXAlignment = Enum.TextXAlignment.Right,
	Text = "0:60",
})

-- Right panel: loot + echoes ------------------------------------------------
local right = Instance.new("Frame")
right.AnchorPoint = Vector2.new(1, 0)
right.Position = UDim2.new(1, -10, 0, 80)
right.Size = UDim2.fromOffset(200, 74)
right.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
right.BackgroundTransparency = 0.25
right.Parent = gui
corner(right, 12)

local lootLabel = label(right, {
	Size = UDim2.new(1, -16, 0.5, -4),
	Position = UDim2.fromOffset(8, 4),
	Text = "$0 / $1000",
	TextColor3 = Color3.fromRGB(255, 205, 60),
})
local echoLabel = label(right, {
	Size = UDim2.new(1, -16, 0.5, -4),
	Position = UDim2.new(0, 8, 0.5, 0),
	Text = "ECHOES: 0",
	TextColor3 = ECHO_BLUE,
})

-- Objectives (left) ---------------------------------------------------------
local obj = label(gui, {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 10, 0, 80),
	Size = UDim2.fromOffset(300, 120),
	TextScaled = false,
	TextSize = 17,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Text = "",
})
obj.BackgroundTransparency = 0.35
obj.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.Parent = obj

local OBJECTIVES = {
	"1. Stand on the BLUE plate: the vault opens.",
	"2. Press REWIND (R). Your echo repeats you and keeps holding the plate!",
	"3. RED plate in the vault turns the lasers off.",
	"4. Grab loot and bring it to the van. Avoid the guard's flashlight.",
}

-- Rewind button --------------------------------------------------------------
local rewindBtn = Instance.new("TextButton")
rewindBtn.AnchorPoint = Vector2.new(0.5, 1)
rewindBtn.Position = UDim2.new(0.5, 0, 1, -18)
rewindBtn.Size = UDim2.fromOffset(240, 58)
rewindBtn.BackgroundColor3 = ECHO_BLUE
rewindBtn.Font = FONT
rewindBtn.TextScaled = true
rewindBtn.TextColor3 = Color3.fromRGB(10, 20, 40)
rewindBtn.Text = "⏪ REWIND (R)"
rewindBtn.Parent = gui
corner(rewindBtn, 16)

local function doRewind()
	requestRewind:FireServer()
	rewindBtn.Text = "⏪ WAITING..."
end
rewindBtn.Activated:Connect(doRewind)
ContextActionService:BindAction("EchoRewind", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		doRewind()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

-- Big centre message -----------------------------------------------------------
local big = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.38),
	Size = UDim2.fromScale(0.7, 0.14),
	Text = "",
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})
local small = label(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.48),
	Size = UDim2.fromScale(0.6, 0.05),
	Text = "",
	TextTransparency = 1,
	TextStrokeTransparency = 1,
})

local function flash(text: string, sub: string?, color: Color3, hold: number?)
	big.Text = text
	big.TextColor3 = color
	small.Text = sub or ""
	for _, l in { big, small } do
		l.TextTransparency = 0
		l.TextStrokeTransparency = 0.3
	end
	task.delay(hold or 1.4, function()
		if big.Text ~= text then
			return
		end
		local info = TweenInfo.new(0.5)
		for _, l in { big, small } do
			TweenService:Create(l, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- Rewind screen effect
local cc = Instance.new("ColorCorrectionEffect")
cc.Parent = Lighting
local function rewindEffect()
	cc.TintColor = Color3.fromRGB(150, 210, 255)
	cc.Saturation = -0.8
	cc.Contrast = 0.3
	TweenService:Create(cc, TweenInfo.new(1.1), {
		TintColor = Color3.new(1, 1, 1),
		Saturation = 0,
		Contrast = 0,
	}):Play()
end

-- Notifications ------------------------------------------------------------------
obj.Text = table.concat(OBJECTIVES, "\n")

notify.OnClientEvent:Connect(function(msg)
	if type(msg) ~= "table" then
		return
	end
	if msg.type == "rewind" then
		rewindEffect()
		flash("⏪ REWIND", "Your past self will repeat everything you just did", ECHO_BLUE, 1)
	elseif msg.type == "loop" then
		rewindBtn.Text = "⏪ REWIND (R)"
		local echoes = tonumber(msg.echoes) or 0
		flash("LOOP " .. tostring(msg.index), echoes > 0 and (echoes .. " echo(es) in play") or "Make your first move", WHITE, 1.2)
	elseif msg.type == "caught" then
		flash("CAUGHT!", msg.reason == "laser" and "Zapped by a laser" or "The guard saw you", Color3.fromRGB(255, 70, 70), 1.4)
	elseif msg.type == "echoBusted" then
		flash("ECHO BUSTED", tostring(msg.owner) .. "'s echo got caught", Color3.fromRGB(255, 140, 60), 1)
	elseif msg.type == "banked" then
		local who = msg.by == "echo" and ("an echo of " .. tostring(msg.owner)) or tostring(msg.owner)
		flash("+$" .. tostring(msg.value), "Banked by " .. who, Color3.fromRGB(255, 205, 60), 1.2)
	elseif msg.type == "votes" then
		rewindBtn.Text = string.format("⏪ %d/%d READY", msg.n, msg.total)
	elseif msg.type == "complete" then
		flash("HEIST COMPLETE!", string.format("$%d in %d loops", msg.value, msg.loops), Color3.fromRGB(120, 255, 140), 6)
	end
end)

-- Per-frame HUD refresh ------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local endsAt = ReplicatedStorage:GetAttribute("LoopEndsAt") or 0
	local left = math.max(0, endsAt - workspace:GetServerTimeNow())
	timerLabel.Text = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
	timerLabel.TextColor3 = left <= 10 and Color3.fromRGB(255, 90, 90) or WHITE
	loopLabel.Text = "LOOP " .. tostring(ReplicatedStorage:GetAttribute("LoopIndex") or 1)
	lootLabel.Text = string.format("$%d / $%d", ReplicatedStorage:GetAttribute("Banked") or 0, ReplicatedStorage:GetAttribute("Target") or 0)
	echoLabel.Text = "ECHOES: " .. tostring(player:GetAttribute("Echoes") or 0)
end)
