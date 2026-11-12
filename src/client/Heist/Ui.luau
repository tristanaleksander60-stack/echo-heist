--!strict
-- Heist/Ui: the Crew Board UI kit v2 (PLAN_STEAM_PLUS §3.2, §4.3 U1; POLISH §4.1; premium D1-D12).
-- Every HUD part builds through these helpers, so the skin lives here:
--   * panels: script-made 9-slice body with a lip and an inner highlight, one drop shadow, a 2 px
--     rim (Ui.panel); a gradient frame until the images are resolved (never a broken image);
--   * raised buttons: a face, a darker lip, a 2 px ink outline, the D3 press (0.92 at once, then
--     1.04, settling at 1.0), real text strokes (UIStroke, never TextStrokeTransparency);
--   * one corner radius (Theme.RADIUS; Ui.pill for full rounds), a type scale of 5 sizes (Ui.label
--     and Ui.button snap TextSize to it), motion tokens only (Heist/Motion);
--   * panels enter and exit with motion (Ui.show / Ui.hide / Ui.setShown), never a bare Visible;
--   * icon + word (Ui.iconWord): the word alone until the icon sheet is known.
-- roblox-ui-builder: Activated everywhere, one UIScale per object (named "Pop": press, pop, enter
-- and exit share it), colour never the only signal. Buttons click through Heist/Sound (AUDIO.md §9
-- item 25): UIClick by default, or the cue the caller names; UIHover on mouse-over (PC only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Strings = require(Shared:WaitForChild("Heist"):WaitForChild("Strings"))

local Icons = require(script.Parent:WaitForChild("Icons"))
local LineupPlan = require(script.Parent:WaitForChild("LineupPlan"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local U = Config.Ui

local Ui = {}

local reducedMotion = false -- Ui.setReducedMotion

-- Smallest button height in design px (>= 64 px on screen at the smallest UI scale).
Ui.TAP = Config.Heist.TAP_MIN

Ui.FONT = Theme.FONT
Ui.FONT_BODY = Theme.FONT_BODY
Ui.FONT_DISPLAY = Theme.FONT_DISPLAY
Ui.TYPE = Theme.TYPE

-- Motion tokens (TweenInfo, built in Heist/Motion).
Ui.MOTION = Motion.TOKENS

---------------------------------------------------------------------------
-- Shape
---------------------------------------------------------------------------

-- The one corner radius (D11). The radius argument is ignored (kept so callers read as before);
-- UICorner clamps it, so thin bars still come out as capsules.
function Ui.corner(parent: Instance, _radius: number?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, Theme.RADIUS)
	c.Parent = parent
	return c
end

-- A full round (chips, pills, badges).
function Ui.pill(parent: Instance): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = parent
	return c
end

function Ui.stroke(parent: Instance, color: Color3, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Name = "Rim"
	s.Color = color
	s.Thickness = thickness or Theme.STROKE
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

-- A real ink text stroke (UIStroke, Contextual: the glyphs, not the box). Never tween its Thickness
-- (it re-renders the glyphs every frame): pulse a UIScale instead.
function Ui.textStroke(obj: Instance, thickness: number?, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Name = "TextStroke"
	s.Color = color or Palette.ink
	s.Thickness = thickness or U.TEXT_STROKE
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = obj
	return s
end

local function strokeFor(size: number): number
	return if size >= U.TEXT_STROKE_BIG then U.TEXT_STROKE else U.TEXT_STROKE_SMALL
end

-- Light text gets the ink stroke, dark (ink) text none; follows later TextColor3 changes.
local function autoStroke(t: TextLabel | TextButton, thickness: number?)
	local s = Ui.textStroke(t, thickness or strokeFor(t.TextSize))
	local function apply()
		s.Enabled = Theme.isLight(t.TextColor3)
	end
	apply()
	t:GetPropertyChangedSignal("TextColor3"):Connect(apply)
end

-- The object's one UIScale ("Pop"): press, pop, enter and exit all use it.
local function scaleOf(obj: Instance): UIScale
	local s = obj:FindFirstChild("Pop")
	if s and s:IsA("UIScale") then
		return s
	end
	local made = Instance.new("UIScale")
	made.Name = "Pop"
	made.Parent = obj
	return made
end
Ui.scaleOf = scaleOf

-- Applies props, minus the kit's own keys (`stroke`).
local function apply(obj: Instance, props: { [string]: any })
	for k, v in props do
		if k ~= "stroke" then
			(obj :: any)[k] = v
		end
	end
end

---------------------------------------------------------------------------
-- Frames and panels
---------------------------------------------------------------------------

-- A plain frame (containers, bars, wells): no skin.
function Ui.frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Palette.ink
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	apply(f, props)
	f.Parent = parent
	return f
end

-- A skinned panel (D11): the 9-slice body (lip + inner highlight) tinted to its colour, one ink drop
-- shadow, the 2 px rim and the radius. Until the images resolve (or without them) it is a gradient
-- frame with the same rim. `rim` = the rim colour (default plumHi; false for none).
-- Later BackgroundColor3 changes retint the skin.
function Ui.panel(parent: Instance, props: { [string]: any }, rim: (Color3 | boolean)?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.COLOR.panel
	f.BackgroundTransparency = U.PANEL_TRANSPARENCY
	f.BorderSizePixel = 0
	apply(f, props)
	Ui.corner(f)
	if rim ~= false then
		Ui.stroke(f, if typeof(rim) == "Color3" then rim else Theme.COLOR.panelRim, Theme.STROKE)
	end
	local shade = Instance.new("UIGradient")
	shade.Name = "Shade"
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.82, 0.82, 0.86))
	shade.Parent = f
	scaleOf(f)
	f.Parent = parent

	local bodyT = f.BackgroundTransparency
	Theme.onImage(Theme.IMAGE_PANEL, function(panelUri: string)
		if f.Parent == nil then
			return
		end
		local spread, off = U.SHADOW_SPREAD, U.SHADOW_OFFSET
		local sc = U.SLICE_CENTER
		local center = Rect.new(sc[1], sc[2], sc[3], sc[4])
		-- The shadow holds the body as its child: the pair draws as one sibling at ZIndex 0, under
		-- every other child of the panel (ZIndexBehavior Sibling).
		local shadow = Instance.new("ImageLabel")
		shadow.Name = "Shadow"
		shadow.BackgroundTransparency = 1
		shadow.Active = false
		shadow.ZIndex = 0
		shadow.Position = UDim2.fromOffset(-spread, -spread + off)
		shadow.Size = UDim2.new(1, spread * 2, 1, spread * 2)
		shadow.ScaleType = Enum.ScaleType.Slice
		shadow.SliceCenter = center
		shadow.SliceScale = U.SLICE_SCALE
		shadow.ImageTransparency = math.max(U.SHADOW_TRANSPARENCY, bodyT)
		Theme.onImage(Theme.IMAGE_SHADOW, function(shadowUri: string)
			shadow.Image = shadowUri
		end)
		local body = Instance.new("ImageLabel")
		body.Name = "Skin"
		body.BackgroundTransparency = 1
		body.Active = false
		body.ZIndex = 0
		body.Position = UDim2.fromOffset(spread, spread - off)
		body.Size = UDim2.new(1, -spread * 2, 1, -spread * 2)
		body.Image = panelUri
		body.ScaleType = Enum.ScaleType.Slice
		body.SliceCenter = center
		body.SliceScale = U.SLICE_SCALE
		body.ImageTransparency = bodyT
		body.ImageColor3 = Theme.panelTint(f.BackgroundColor3)
		body.Parent = shadow
		shadow.Parent = f
		f.BackgroundTransparency = 1
		shade.Enabled = false
		f:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
			body.ImageColor3 = Theme.panelTint(f.BackgroundColor3)
		end)
	end)
	return f
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------

-- A label on the type scale with a real text stroke on light text (`stroke = n` sets its
-- thickness, `stroke = false` none).
function Ui.label(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.FontFace = Theme.FONT
	t.TextColor3 = Palette.white
	t.TextSize = Theme.TYPE.body
	apply(t, props)
	t.TextSize = Theme.snapSize(t.TextSize)
	if props.stroke ~= false then
		autoStroke(t, if type(props.stroke) == "number" then props.stroke else nil)
	end
	t.Parent = parent
	return t
end

-- Display text (stamps of <= 3 words, the wordmark): the display face with a stroke of 6 % of its size.
function Ui.display(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = Theme.FONT_DISPLAY
	t.TextColor3 = Palette.white
	t.TextSize = Theme.TYPE.display
	apply(t, props)
	Ui.textStroke(t, math.max(1, math.floor(t.TextSize * U.DISPLAY_STROKE + 0.5)))
	t.Parent = parent
	return t
end

-- Text that must fit its box: it shrinks from `max` down to `min` design px (never under the
-- smallest type step) instead of spilling past the box.
function Ui.fit(obj: TextLabel | TextButton, max: number, min: number)
	obj.TextScaled = true
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = math.max(U.TYPE_SCALE[1], max)
	c.MinTextSize = math.max(U.TYPE_SCALE[1], math.min(min, max))
	c.Parent = obj
end

-- Fixed-width digit slots (D1: one TextLabel per character, so the timer never jitters). Returns
-- { frame, set(text), setColor(c) }; the frame is right-aligned in its box.
function Ui.digits(parent: Instance, props: { [string]: any }, size: number?): any
	local frame = Ui.frame(parent, { BackgroundTransparency = 1 })
	apply(frame, props)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local textSize = Theme.snapSize(size or U.TIMER_SIZE)
	local slots: { TextLabel } = {}
	local color = Palette.white
	local obj = { frame = frame }
	function obj.set(text: string)
		local n = #text
		while #slots < n do
			table.insert(
				slots,
				Ui.label(frame, { TextSize = textSize, Size = UDim2.fromOffset(U.TIMER_DIGIT_W, textSize + 6) })
			)
		end
		for i, slot in slots do
			local ch = if i <= n then string.sub(text, i, i) else ""
			slot.Visible = i <= n
			slot.LayoutOrder = i
			slot.Text = ch
			slot.TextColor3 = color
			slot.Size = UDim2.fromOffset(if ch == ":" then U.TIMER_COLON_W else U.TIMER_DIGIT_W, textSize + 6)
		end
	end
	function obj.setColor(c: Color3)
		if c ~= color then
			color = c
			for _, slot in slots do
				slot.TextColor3 = c
			end
		end
	end
	return obj
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------

-- The lip: a multiplicative top-to-bottom gradient that darkens the last BUTTON_LIP px (it follows
-- any BackgroundColor3 the caller sets later).
local function lip(b: GuiObject)
	local g = Instance.new("UIGradient")
	g.Name = "Lip"
	g.Rotation = 90
	g.Parent = b
	local function fitLip()
		local h = b.Size.Y.Offset
		if h <= 0 then
			h = math.max(1, b.AbsoluteSize.Y)
		end
		local cut = math.clamp(1 - U.BUTTON_LIP / h, 0.5, 0.97)
		local face, edge, low = Color3.new(1, 1, 1), U.BUTTON_FACE_SHADE, U.BUTTON_LIP_SHADE
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, face),
			ColorSequenceKeypoint.new(cut - 0.02, Color3.new(edge, edge, edge)),
			ColorSequenceKeypoint.new(cut, Color3.new(low, low, low)),
			ColorSequenceKeypoint.new(1, Color3.new(low, low, low)),
		})
	end
	fitLip()
	b:GetPropertyChangedSignal("Size"):Connect(fitLip)
end

-- A raised button with the D3 press that fires `onActivated`. `cue` is the click sound ("UIClick"
-- by default; "" = silent, e.g. a button whose action has its own sound such as REWIND's tape clack).
function Ui.button(parent: Instance, props: { [string]: any }, onActivated: () -> (), cue: string?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = Theme.COLOR.neutral
	b.BorderSizePixel = 0
	b.FontFace = Theme.FONT
	b.TextColor3 = Palette.ink
	b.TextSize = Theme.TYPE.body
	b.Text = ""
	apply(b, props)
	b.TextSize = Theme.snapSize(b.TextSize)
	Ui.corner(b)
	local outline = Ui.stroke(b, Palette.ink, Theme.STROKE)
	outline.Name = "Outline"
	autoStroke(b)
	lip(b)
	local scale = scaleOf(b)
	b.InputBegan:Connect(function(input: InputObject)
		if
			not reducedMotion
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			Motion.pressDown(scale)
		end
	end)
	b.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if reducedMotion then
				scale.Scale = 1
			else
				Motion.pressUp(scale)
			end
		end
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

-- Icon + word on a button or label (U2): "top" stacks the icon over the word (square buttons:
-- REWIND, MENU), "left" puts it before the word (wide buttons). The word shows alone until the
-- icon sheet is known, so nothing ever renders as a broken image. Returns a getter for the icon.
function Ui.iconWord(obj: TextLabel | TextButton, icon: string, placement: string?, size: number?): () -> ImageLabel?
	local made: ImageLabel? = nil
	local px = size or U.ICON_SIZE
	local gap = U.ICON_GAP
	local tint = if obj:IsA("TextButton") and Theme.isLight(obj.BackgroundColor3) then Palette.ink else obj.TextColor3
	if placement == "left" then
		Icons.attach(obj, icon, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -(px + gap), 0.5, 0),
			Size = UDim2.fromOffset(px, px),
			ImageColor3 = tint,
			ZIndex = obj.ZIndex,
		}, function(img: ImageLabel)
			made = img
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, px + gap * 2)
			pad.Parent = obj
		end)
	else
		Icons.attach(obj, icon, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, gap + 2),
			Size = UDim2.fromOffset(px, px),
			ImageColor3 = tint,
			ZIndex = obj.ZIndex,
		}, function(img: ImageLabel)
			made = img
			obj.TextYAlignment = Enum.TextYAlignment.Bottom
			local pad = Instance.new("UIPadding")
			pad.PaddingBottom = UDim.new(0, gap + 2)
			pad.Parent = obj
		end)
	end
	return function()
		return made
	end
end

---------------------------------------------------------------------------
-- Motion
---------------------------------------------------------------------------

-- Reduced motion (GuiService.ReducedMotionEnabled, HeistClient): pops, press bounces and panel
-- scale stop; panels just appear and go.
function Ui.setReducedMotion(on: boolean)
	reducedMotion = on
end

function Ui.reducedMotion(): boolean
	return reducedMotion
end

-- Is a panel shown (or entering)? A panel that is exiting counts as hidden.
function Ui.isShown(obj: GuiObject): boolean
	return obj.Visible and obj:GetAttribute("UiShown") ~= false
end

-- Panel enter (D4): UIScale ENTER_FROM -> 1, Back Out. Input works from the first frame (D6).
function Ui.show(obj: GuiObject)
	local was = Ui.isShown(obj)
	obj:SetAttribute("UiShown", true)
	if was then
		return
	end
	obj.Visible = true
	local scale = scaleOf(obj)
	if reducedMotion then
		scale.Scale = 1
		return
	end
	scale.Scale = U.ENTER_FROM
	Motion.tween(scale, "enter", { Scale = 1 })
end

-- Panel exit (D4): UIScale -> EXIT_TO, Quad In, then hidden if it is still meant to be closed.
function Ui.hide(obj: GuiObject)
	local was = Ui.isShown(obj)
	obj:SetAttribute("UiShown", false)
	if not was then
		return
	end
	local scale = scaleOf(obj)
	if reducedMotion then
		obj.Visible = false
		scale.Scale = 1
		return
	end
	local tw = Motion.tween(scale, "exit", { Scale = U.EXIT_TO })
	tw.Completed:Once(function()
		if obj:GetAttribute("UiShown") == false then
			obj.Visible = false
			scale.Scale = 1
		end
	end)
end

function Ui.setShown(obj: GuiObject, on: boolean)
	if on then
		Ui.show(obj)
	else
		Ui.hide(obj)
	end
end

-- Pops an object's UIScale (feedback within 100 ms of an input; D10's 1.12 -> 1 landing).
function Ui.pop(obj: Instance, from: number?)
	if reducedMotion then
		return
	end
	local scale = scaleOf(obj)
	scale.Scale = from or U.POP_SCALE
	Motion.tween(scale, "pop", { Scale = 1 })
end

---------------------------------------------------------------------------
-- REWIND's ring lock: dots on a circle that go out over the lock (POLISH §4.2)
---------------------------------------------------------------------------
function Ui.lockRing(parent: Instance, diameter: number, color: Color3): any
	local ring = Ui.frame(parent, {
		Name = "LockRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
		Active = false,
	})
	local dots: { Frame } = {}
	local n = U.LOCK_SEGMENTS
	local r = diameter / 2
	for i = 1, n do
		local a = (i - 1) / n * 2 * math.pi - math.pi / 2
		local d = Ui.frame(ring, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(r + r * math.cos(a), r + r * math.sin(a)),
			Size = UDim2.fromOffset(5, 5),
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			Active = false,
		})
		Ui.pill(d)
		dots[i] = d
	end
	local obj = { frame = ring }
	-- frac = share of the lock still to run (1 = just started, 0 = unlocked: the ring hides).
	function obj.set(frac: number)
		ring.Visible = frac > 0
		local lit = math.ceil(frac * n)
		for i, d in dots do
			d.BackgroundTransparency = if i <= lit then 0 else 0.85
		end
	end
	return obj
end

---------------------------------------------------------------------------
-- Words and numbers
---------------------------------------------------------------------------

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
-- rounded to the nearest 10 s (at least 10), whole minutes from 55 s (LineupPlan.agoRound).
function Ui.ago(seconds: number): string
	return Strings.ago(LineupPlan.agoRound(seconds))
end

-- The burned-in clone label: "ME, 20 SEC AGO" with the name in the clone's hue (RichText).
function Ui.agoLabel(who: string, seconds: number, arrowHue: Color3?): string
	local hue = (arrowHue or Palette.CLONE_HUES[1]):ToHex()
	return Strings.agoLabel(who, Ui.ago(seconds), hue)
end

return Ui
