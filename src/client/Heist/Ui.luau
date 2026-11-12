--!strict
-- Heist/Ui: small UI building blocks and motion tokens for the sim HUD
-- (roblox-ui-builder: Activated everywhere, one UIScale per branch, pops on a child
-- UIScale, motion through named tokens, colour never the only signal). Buttons click
-- through Heist/Sound (docs/AUDIO.md §9 item 25): UIClick by default, or the cue the
-- caller names (UIBack, UIToggle, UIConfirm), UIHover on mouse-over (PC only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local LineupPlan = require(script.Parent:WaitForChild("LineupPlan"))
local Sound = require(script.Parent:WaitForChild("Sound"))

local Ui = {}

local reducedMotion = false -- Ui.setReducedMotion

-- Smallest button height in design px (>= 64 px on screen at the smallest UI scale).
Ui.TAP = Config.Heist.TAP_MIN

Ui.FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
Ui.FONT_BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

-- Motion tokens (seconds)
Ui.MOTION = table.freeze({
	press = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	release = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	enter = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	exit = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	pop = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
})

function Ui.corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

function Ui.stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

function Ui.frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Palette.ink
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

function Ui.label(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = Ui.FONT
	t.TextColor3 = Palette.white
	t.TextSize = 18
	t.TextStrokeTransparency = 0.6
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

-- A raised button with a press pop (child UIScale) that fires `onActivated`. `cue` is
-- the click sound ("UIClick" by default; "" = silent, e.g. a button whose action has
-- its own sound such as END RUN's tape clack).
function Ui.button(parent: Instance, props: { [string]: any }, onActivated: () -> (), cue: string?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Palette.steel
	b.BorderSizePixel = 0
	b.FontFace = Ui.FONT
	b.TextColor3 = Palette.ink
	b.TextSize = 18
	b.Text = ""
	for k, v in props do
		(b :: any)[k] = v
	end
	Ui.corner(b, 12)
	local shadow = Instance.new("UIStroke")
	shadow.Color = Palette.ink
	shadow.Thickness = 2
	shadow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	shadow.Parent = b
	local scale = Instance.new("UIScale")
	scale.Name = "Pop"
	scale.Parent = b
	b.InputBegan:Connect(function(input: InputObject)
		if
			not reducedMotion
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			TweenService:Create(scale, Ui.MOTION.press, { Scale = 0.92 }):Play()
		end
	end)
	b.InputEnded:Connect(function()
		TweenService:Create(scale, Ui.MOTION.release, { Scale = 1 }):Play()
	end)
	b.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
			Sound.play("UIHover")
		end
	end)
	local click = cue or "UIClick"
	b.Activated:Connect(function()
		if click ~= "" then
			Sound.play(click)
		end
		onActivated()
	end)
	b.Parent = parent
	return b
end

-- Reduced motion (GuiService.ReducedMotionEnabled, HeistClient): pops and press bounces stop.
function Ui.setReducedMotion(on: boolean)
	reducedMotion = on
end

function Ui.reducedMotion(): boolean
	return reducedMotion
end

-- Pops an object's child UIScale (feedback within 100 ms of an input, §3.4).
function Ui.pop(obj: Instance)
	if reducedMotion then
		return
	end
	local scale = obj:FindFirstChild("Pop")
	if scale and scale:IsA("UIScale") then
		scale.Scale = 1.15
		TweenService:Create(scale, Ui.MOTION.pop, { Scale = 1 }):Play()
	end
end

function Ui.money(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

function Ui.clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds - 1e-6))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- "20 SEC AGO" / "1 MIN AGO": docs/marketing/CLIPS.md §1.2, the number is always true,
-- rounded to the nearest 10 s (at least 10), whole minutes from 55 s (LineupPlan.ago).
Ui.ago = LineupPlan.ago

-- The burned-in clone label: "◀ ME, 20 SEC AGO" with the ◀ in Clone Cyan (RichText).
function Ui.agoLabel(who: string, seconds: number, arrowHue: Color3?): string
	local hue = (arrowHue or Palette.CLONE_HUES[1]):ToHex()
	return string.format('<font color="#%s">◀</font> %s, %s', hue, who, Ui.ago(seconds))
end

return Ui
