--!strict
-- Hud/Reticle: the first-person centre reticle and the prompt chip (PLAN_FIRST_PERSON FP, look-to-interact).
-- Both sit on the edge-to-edge fx layer, centred on the WHOLE screen where the camera ray goes (HudLayout
-- SCREEN_CENTRED: RETICLE, PROMPT), under the HUD's device scale. The reticle: a small dot (with an ink
-- stroke, so it reads on snow and on the night sky), and a ring round it in the target's colour while a
-- target is under it. The chip, just right of it: the key ("E" on a keyboard, "X" on a gamepad, "TAP" on
-- touch, where the GRAB button is the tap target), the verb's icon and its word ("GRAB $100", "LOCKED 0:07",
-- "OPEN", "WALK IN TO BANK": the van has no key). Nothing here is interactive (Active off), so a locked cursor's clicks fall through.
-- Motion: the ring and the chip pop in (Ui.pop / Ui.show), go with the exit token; reduced motion: no pop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Icons = require(script.Parent.Parent:WaitForChild("Icons"))
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local U = Config.Ui
local FH = Config.FirstPerson.HUD

local Reticle = {}

export type Prompt = {
	verb: string, -- Strings.FP_VERB key ("grab" | "locked" | "open" | "press" | "bank")
	text: string, -- the word(s) shown
	colour: Color3,
	key: string?, -- the key cap ("E", "X", "TAP"), nil for the van
	locked: boolean?, -- a lobby target that does nothing for you (steel words)
}

-- The icon for each verb (the 38-icon sheet).
Reticle.ICON = table.freeze({
	grab = "loot",
	locked = "loot",
	open = "door",
	press = "plate",
	bank = "van",
	-- the hideout lobby (Shared/Heist/LobbyLook verbs)
	jobs = "star",
	laptop = "gift",
	wardrobe = "you",
	tv = "play",
	invite = "invite",
	pick = "van",
	leaderPicks = "lock",
	solo = "play",
	go = "play",
	wait = "lock",
	crew = "door",
	park = "door",
	paint = "bolt",
	sit = "seat_circle",
	ready = "check",
	unready = "cross",
	taken = "lock",
	busy = "lock",
})

function Reticle.build(ctx: any): any
	local reticle = {}
	local fx: ScreenGui = ctx.fxGui
	-- Edge-to-edge, scaled like the HUD root (ctx.deviceScale).
	local layer = Ui.frame(fx, {
		Name = "FirstPerson",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
		Active = false,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = layer
	local function rescale()
		local s = if ctx.deviceScale then ctx.deviceScale.Scale else 1
		s = if s > 0 then s else 1
		scale.Scale = s
		layer.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	if ctx.deviceScale then
		ctx.deviceScale:GetPropertyChangedSignal("Scale"):Connect(rescale)
	end
	reticle.layer = layer

	local box = Ui.frame(layer, { Name = "Reticle", BackgroundTransparency = 1, Active = false, ZIndex = 2 })
	Common.place(box, HudLayout.RETICLE)
	local dot = Ui.frame(box, {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(FH.RETICLE, FH.RETICLE),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = FH.RETICLE_ALPHA,
		Active = false,
		ZIndex = 3,
	})
	Ui.pill(dot)
	Ui.stroke(dot, Palette.ink, 1.5)
	local ring = Ui.frame(box, {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(FH.RETICLE_RING, FH.RETICLE_RING),
		BackgroundTransparency = 1,
		Visible = false,
		Active = false,
		ZIndex = 3,
	})
	Ui.pill(ring)
	local ringStroke = Ui.stroke(ring, Palette.gold, Theme.STROKE + 0.5)
	reticle.dot = dot
	reticle.ring = ring

	local chip = Ui.panel(layer, { Name = "Prompt", Visible = false, Active = false, ZIndex = 4 })
	Common.place(chip, HudLayout.PROMPT)
	local keyCap = Ui.frame(chip, {
		Name = "Key",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0,
		Active = false,
		ZIndex = 5,
	})
	Ui.corner(keyCap)
	Ui.stroke(keyCap, Palette.ink, 2)
	local keyLabel = Ui.label(keyCap, {
		Size = UDim2.fromScale(1, 1),
		Text = "E",
		TextColor3 = Palette.ink,
		TextSize = U.TYPE_SCALE[1],
		stroke = false,
		ZIndex = 6,
		Active = false,
	})
	local word = Ui.label(chip, {
		Name = "Word",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 40, 0.5, 0),
		Size = UDim2.new(1, -48, 1, -8),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = U.TYPE_SCALE[2],
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = Strings.GRAB,
		ZIndex = 5,
		Active = false,
	})
	local iconGet = Ui.iconWord(word, Reticle.ICON.grab, "left", U.ICON_SMALL)
	reticle.chip = chip
	reticle.word = word

	local shownText, shownVerb, shownKey = "", "", ""
	local onTarget = false

	-- Shown in first person during a run; `prompt` nil = no target (the bare dot).
	function reticle.set(shown: boolean, prompt: Prompt?)
		if layer.Visible ~= shown then
			layer.Visible = shown
		end
		if not shown then
			prompt = nil
		end
		local has = prompt ~= nil
		if has ~= onTarget then
			onTarget = has
			ring.Visible = has
			dot.BackgroundTransparency = if has then 0 else FH.RETICLE_ALPHA
			if has then
				Ui.pop(ring)
			end
		end
		Ui.setShown(chip, has)
		if not prompt then
			shownVerb = ""
			return
		end
		ringStroke.Color = prompt.colour
		local key = prompt.key or ""
		if key ~= shownKey then
			shownKey = key
			keyCap.Visible = key ~= ""
			keyLabel.Text = key
			-- one letter: a square cap; a word (TAP): a wider one
			local capW = if #key > 1 then FH.KEY_CAP_WIDE else 26
			keyCap.Size = UDim2.fromOffset(capW, 26)
			local left = if key ~= "" then capW + 14 else 12
			word.Position = UDim2.new(0, left, 0.5, 0)
			word.Size = UDim2.new(1, -(left + 8), 1, -8)
		end
		if prompt.text ~= shownText then
			shownText = prompt.text
			word.Text = prompt.text
		end
		if prompt.verb ~= shownVerb then
			shownVerb = prompt.verb
			Icons.set(iconGet(), Reticle.ICON[prompt.verb] or "loot")
			Ui.pop(chip)
		end
		word.TextColor3 = if prompt.verb == "locked" or prompt.locked then Palette.steelHi else Palette.white
	end

	-- The onboarding finger for the chip (Hud/Hints): pointing up at it from below, so it never covers the
	-- reticle. `on` false hides it.
	local O = Config.Onboarding
	local finger = Common.finger(layer, O.POINTER_SIZE, 7)
	finger.AnchorPoint = Vector2.new(0.5, 0.5)
	finger.Rotation = -90
	function reticle.point(on: boolean, now: number)
		if not on or not Ui.isShown(chip) then
			finger.Visible = false
			return
		end
		local b = HudLayout.PROMPT
		local tap = if Ui.reducedMotion() then 0 else (0.5 - 0.5 * math.cos(now * 2 * math.pi / O.POINTER_PERIOD))
		local x = b.ox + O.POINTER_SIZE * 0.6
		local y = b.oy + b.h / 2 + O.POINTER_SIZE / 2 + 2 + O.POINTER_TRAVEL * (1 - tap)
		finger.Position = UDim2.new(0.5, x, 0.5, y)
		finger.Visible = true
	end

	return reticle
end

return Reticle
