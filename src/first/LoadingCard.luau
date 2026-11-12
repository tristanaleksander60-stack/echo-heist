--!strict
-- ReplicatedFirst/LoadingCard: the branded loading card (POLISH §4.6, PLAN_STEAM_PLUS §4.1 W7): an ink
-- screen with the wordmark and its strap, a small reel turning once per Brand.LOADING.REEL_PERIOD and a
-- quiet progress hint (one line per real stage plus three pips; never a bare "Loading"). Built from code
-- with no images, so it draws on the first frame without waiting for any asset.
--
--   LoadingCard.build(parent, opts?) -> Card   opts.name / opts.order (the title beat builds the same
--                                              card one layer up), opts.copies (wordmark copies)
--   LoadingCard.reel(parent, diameter) -> Frame       the reel alone (the HUD's fallback wait card)
--   LoadingCard.reelAngle(now, period) -> degrees     one clock for every reel, so a hand-off between
--                                                     two cards never jumps the reel
--   LoadingCard.spin(reel, now, reduced)
--   LoadingCard.setStage(card, stage)                 Brand.STAGES name: hint line + pips
--   LoadingCard.fadeGoals(root) -> { { obj, goals } } every visible transparency in a tree, to 1
--
-- Used by ReplicatedFirst/Loading (the card itself), Heist/Title (the same card, one layer up, that
-- splits the wordmark) and Heist/Loading (the reel for the HUD's wait card).

local Brand = require(script.Parent:WaitForChild("Brand"))
local Wordmark = require(script.Parent:WaitForChild("Wordmark"))

export type Card = {
	gui: ScreenGui,
	bg: Frame,
	content: Frame,
	mark: Wordmark.Mark,
	reel: Frame,
	hint: TextLabel,
	pips: { Frame },
}

local LoadingCard = {}

local C = Brand.CARD

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function circle(parent: Instance, name: string, d: number, color: Color3): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Size = UDim2.fromOffset(d, d)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

-- A cassette-style reel: a rim, a hub and three holes (rotating the frame turns its children too).
function LoadingCard.reel(parent: Instance, diameter: number): Frame
	local reel = circle(parent, "Reel", diameter, hex(Brand.COLOR.inkHi))
	local rim = Instance.new("UIStroke")
	rim.Color = hex(Brand.COLOR.steelHi)
	rim.Thickness = math.max(2, math.floor(diameter * 0.08 + 0.5))
	rim.Parent = reel
	local hub = circle(reel, "Hub", math.floor(diameter * 0.3), hex(Brand.COLOR.steelHi))
	hub.Position = UDim2.fromScale(0.5, 0.5)
	for k = 0, 2 do
		local a = math.rad(k * 120 - 90)
		local hole = circle(reel, "Hole" .. (k + 1), math.floor(diameter * 0.2), hex(Brand.COLOR.ink))
		hole.Position = UDim2.fromScale(0.5 + 0.3 * math.cos(a), 0.5 + 0.3 * math.sin(a))
	end
	return reel
end

function LoadingCard.reelAngle(now: number, period: number): number
	if period <= 0 then
		return 0
	end
	return (now % period) / period * 360
end

function LoadingCard.spin(reel: GuiObject, now: number, reduced: boolean)
	reel.Rotation = if reduced then 0 else LoadingCard.reelAngle(now, Brand.LOADING.REEL_PERIOD)
end

function LoadingCard.setStage(card: Card, stage: string)
	local index = table.find(Brand.STAGES, stage)
	if not index then
		return
	end
	card.hint.Text = Brand.HINTS[stage]
	for k, pip in card.pips do
		pip.BackgroundColor3 = if k <= index then hex(Brand.COLOR.white) else hex(Brand.COLOR.inkHi)
	end
end

function LoadingCard.fadeGoals(root: Instance): { { any } }
	local out: { { any } } = {}
	local all = root:GetDescendants()
	table.insert(all, root)
	for _, d in all do
		local goals: { [string]: any } = {}
		if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
			goals.BackgroundTransparency = 1
		end
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.TextTransparency < 1 then
			goals.TextTransparency = 1
		end
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.ImageTransparency < 1 then
			goals.ImageTransparency = 1
		end
		if d:IsA("UIStroke") and d.Transparency < 1 then
			goals.Transparency = 1
		end
		if next(goals) ~= nil then
			table.insert(out, { d, goals })
		end
	end
	return out
end

function LoadingCard.build(parent: Instance, opts: { name: string?, order: number?, copies: number? }?): Card
	local o = opts or {}
	local gui = Instance.new("ScreenGui")
	gui.Name = o.name or Brand.GUI_NAME
	gui.DisplayOrder = o.order or Brand.LOADING.ORDER
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local bg = Instance.new("Frame")
	bg.Name = "Ink"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = hex(Brand.COLOR.ink)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	-- One design canvas, scaled to fit the screen (portrait phones included).
	local W, H = C.DESIGN[1], C.DESIGN[2]
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromOffset(W, H)
	content.BackgroundTransparency = 1
	content.Parent = bg
	local scale = Instance.new("UIScale")
	scale.Parent = content
	local function fit()
		local size = gui.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			local cam = workspace.CurrentCamera
			size = if cam then cam.ViewportSize else Vector2.new(W, H)
		end
		scale.Scale = math.clamp(math.min(size.X / W, size.Y / H), 0.3, 1.5)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local mark = Wordmark.build(content, { size = C.MARK_SIZE, width = W, copies = o.copies, strap = true })
	mark.root.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.root.Position = UDim2.fromScale(0.5, C.MARK_Y)

	local reel = LoadingCard.reel(content, C.REEL)
	reel.Position = UDim2.fromScale(0.5, C.REEL_Y)
	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, C.REEL_Y, math.ceil(C.REEL / 2) + 8)
	hint.Size = UDim2.fromOffset(W, C.HINT_SIZE + 4)
	hint.BackgroundTransparency = 1
	hint.FontFace = Font.new(Brand.BODY_FONT, Enum.FontWeight.Bold)
	hint.TextSize = C.HINT_SIZE
	hint.TextColor3 = hex(Brand.COLOR.steelHi)
	hint.Text = Brand.HINTS.boot
	hint.Parent = content
	local pips: { Frame } = {}
	for k = 1, #Brand.STAGES do
		local pip = circle(content, "Pip" .. k, C.PIP, hex(Brand.COLOR.inkHi))
		pip.Position = UDim2.new(0.5, (k - 2) * (C.PIP * 2.5), C.REEL_Y, math.ceil(C.REEL / 2) + C.HINT_SIZE + 22)
		pips[k] = pip
	end

	local card: Card = { gui = gui, bg = bg, content = content, mark = mark, reel = reel, hint = hint, pips = pips }
	LoadingCard.setStage(card, "boot")
	gui.Parent = parent
	return card
end

return LoadingCard
