--!strict
-- Heist/Hud: HUD v1 for the sim path (MASTERPLAN §7.4, §3.4 controls, §7.5 L1 FTUE).
-- Four elements during a run, everything else contextual:
--   1. Top centre: "RUN 3" (Dawn levels "RUN 6/8", then "☾ LAST RUN") + tape counter
--      "0:27" + a thin run bar with icons for your clones' recorded events and red
--      failure markers; last 10 s pulse (and tick), last 5 s Alarm Red with a ring glyph.
--   2. Top left: loot meter "$400 / $1,000" with a count-up (Clone Party: "$2,350 /
--      $2,500 ★2", the next haul tier).
--   3. Top right: clone strip (glyph, digit, hue per clone; red-flagged = ✕).
--   4. Right edge, ~45% height: 72 px END RUN ("◀◀ END RUN", co-op "· 2/3"), with a
--      ring that fills during the 1.5 s lock.
-- Contextual: Interact (≥ 64 px, lower right left of the jump button, near loot;
-- "LOCKED 0:07" at the time-locked till), ⏩ HOLD pill, one objective line (≤ 8 words,
-- shown when it changes or when stuck), the Alarm Run counter ("◎ VAN LEAVES 0:14" in
-- Alarm Red, a red pulse; the Clone Party's till is the "GETAWAY"), ◐ HIDDEN while you
-- hide, the ❚❚ menu (leave the heist), the Clone Deck between runs (from L2; read-only on
-- L1 and party levels) with the RedoAlarm hint in its title, the RUN n countdown, the
-- results card, one bottom message rail (toast, sound caption, spectate line), and the
-- garage (tapes in play order with the party break tagged and why a tape is locked, the
-- daily vault card with streak and modifier once the first tape is cleared, advent
-- catch-up, crew, join friend). A new account sees a "preparing" card, never the garage,
-- until its first heist starts. Stamps: "N OF ME" (Config.Sim.SWARM_OF_ME copies), haul tiers,
-- ALARM, ESCAPED, DAWN, HEIST COMPLETE. Mobile first: every button is at least
-- Config.Heist.TAP_MIN design px (>= 64 px on screen), the HUD scales to the safe
-- area, colour is never the only signal (glyph + number), reduced motion drops the
-- pulses. Keys: R / ButtonY END RUN (between runs: RUN n), E / ButtonX Interact,
-- Q / ButtonL1 Clone Deck, hold F / ButtonB fast-forward.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Codec = require(Shared:WaitForChild("Rec"):WaitForChild("Codec"))
local Sim = Shared:WaitForChild("Sim")
local EventLog = require(Sim:WaitForChild("EventLog"))
local Interact = require(Sim:WaitForChild("Interact"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Mix = require(Shared:WaitForChild("Audio"):WaitForChild("Mix"))

local Rigs = require(script.Parent:WaitForChild("Rigs"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local H = Config.Heist
local AU = Config.Audio
local EV = EventLog.EV
local KIND = Codec.EVENT
local FAIL = Interact.FAIL
local TAP = Ui.TAP
local localPlayer = Players.LocalPlayer

local Hud = {}

-- The gamepad selection outline only when a gamepad is in use (not on touch or PC).
local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Gamepad1
		or last == Enum.UserInputType.Gamepad2
		or last == Enum.UserInputType.Gamepad3
		or last == Enum.UserInputType.Gamepad4
end

local function selectFor(obj: GuiObject?)
	if usingGamepad() then
		GuiService.SelectedObject = obj
	end
end

local OBJECTIVE_SECONDS = 6 -- an objective line shows this long after it changes (§7.4)
local LEVEL_LINE_STUCK_RUNS = 2 -- runs without a bank before the level line comes back

local STATUS_TEXT = {
	New = "NEW",
	OK = "OK",
	Busted = "BUSTED",
	Caught = "CAUGHT",
	Zapped = "ZAPPED",
	Stuck = "STUCK",
	Shrug = "?",
}
local RED = { Busted = true, Caught = true, Zapped = true, Stuck = true }

-- Level lines shown for the first seconds of run 1, and again when stuck (≤ 8 words
-- each), by LevelSpec id (the Catalog is in play order, so never by index).
local LEVEL_LINES: { [string]: string } = {
	cs2_two_doors = "Two plates. You need two clones.",
	cs5_clone_party = "Rob it all. Bank it before Dawn.",
	cs3_lights_out = "Plate B turns the lasers off.",
	cs4_night_clerk = "Hide from Gus. Cross while he looks away.",
	bk1_big_score = "The vault. Every clone counts.",
}

-- Daily vault modifiers (Levels/DailyVaults.MODIFIERS) as the garage card shows them.
local MODIFIER_TEXT: { [string]: string } = {
	None = "",
	GuardFast = "FAST GUS",
	GuardSlow = "SLEEPY GUS",
	LootB = "LOOT MOVED",
	LootC = "LOOT MOVED",
	LightsOff = "LIGHTS OUT",
}

-- L1 stuck hints at Config.Heist.HINT_SECONDS (§7.5): re-pulse the plate, a beam from
-- your feet, the Mentor ghost doing the step. Names are the analytics `hint` domain.
local HINTS = { "plate", "beam", "mentor" }

local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }

export type Actions = {
	endRun: () -> (),
	interact: (kind: number, index: number) -> (),
	deck: (op: string, n: number?) -> (),
	ready: () -> (),
	fastForward: (on: boolean) -> (),
	selectLevel: (index: number) -> (),
	selectDaily: (day: number?) -> (),
	joinFriend: (userId: number) -> (),
	leave: () -> (),
	hint: (name: string) -> (),
}

local function dateText(day: number): string
	local ok, text = pcall(function()
		local dt = DateTime.fromUnixTimestamp(day * 86400):ToUniversalTime()
		return string.format("%s %d", MONTHS[dt.Month], dt.Day)
	end)
	return if ok then text else ""
end

local function durationText(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
	end
	return string.format("%dm", math.max(1, s // 60))
end

function Hud.new(state: any, actions: Actions): any
	local hud = {}
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HeistHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Edge-to-edge layer (rewind overlay, vignette, Line-up caption): no insets, nothing interactive.
	local fxGui = Instance.new("ScreenGui")
	fxGui.Name = "HeistFX"
	fxGui.ResetOnSpawn = false
	fxGui.DisplayOrder = 6
	fxGui.ScreenInsets = Enum.ScreenInsets.None
	fxGui.IgnoreGuiInset = true
	fxGui.Parent = playerGui
	hud.fxGui = fxGui

	-- One device UIScale on the root (roblox-ui-builder): the HUD is authored at 1x for
	-- UI_DESIGN_SIZE; the root is sized 1/scale so after scaling it fills the safe area.
	local root = Ui.frame(gui, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local deviceScale = Instance.new("UIScale")
	deviceScale.Parent = root
	local function rescale()
		local size = gui.AbsoluteSize
		if size.X < 1 or size.Y < 1 then
			local cam = workspace.CurrentCamera
			size = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		end
		local d = H.UI_DESIGN_SIZE
		local s = math.clamp(math.min(size.X / d[1], size.Y / d[2]), H.UI_SCALE_MIN, H.UI_SCALE_MAX)
		deviceScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

	local vignette = Ui.frame(fxGui, {
		Name = "Vignette",
		BackgroundColor3 = Palette.alarm,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
	})

	-- The diamond moment dims the world (§7.3), under the camera like the rewind grade.
	local dim = Instance.new("ColorCorrectionEffect")
	dim.Name = "EH_Dim"
	dim.Enabled = false
	local function placeDim()
		local cam = workspace.CurrentCamera
		if cam and dim.Parent ~= cam then
			dim.Parent = cam
		end
	end
	placeDim()

	---------------------------------------------------------------------------
	-- Run HUD
	---------------------------------------------------------------------------
	local runHud =
		Ui.frame(root, { Name = "Run", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })

	local top = Ui.frame(runHud, {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(330, 62),
	})
	Ui.corner(top, 14)
	local runLabel = Ui.label(top, {
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.fromOffset(170, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 24,
		TextColor3 = Palette.CLONE_HUES[1],
		Text = "RUN 1",
	})
	local timerLabel = Ui.label(top, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 4),
		Size = UDim2.fromOffset(130, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 30,
		Text = "0:30",
	})
	local timerScale = Instance.new("UIScale")
	timerScale.Parent = timerLabel
	local bar = Ui.frame(top, {
		Name = "RunBar",
		Position = UDim2.new(0, 14, 1, -16),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = Palette.plumHi,
		BackgroundTransparency = 0,
	})
	Ui.corner(bar, 3)
	local barFill = Ui.frame(bar, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0,
	})
	Ui.corner(barFill, 3)
	local markers = Ui.frame(bar, { Name = "Markers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	-- Alarm Run counter (§7.3): "◎ VAN LEAVES 0:14 · SHUTTER 0:04" in Alarm Red.
	local alarmPill = Ui.frame(runHud, {
		Name = "Alarm",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(380, 40),
		Visible = false,
	})
	Ui.corner(alarmPill, 12)
	Ui.stroke(alarmPill, Palette.alarm, 2)
	local alarmLabel = Ui.label(alarmPill, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		TextColor3 = Palette.alarm,
		Text = "",
	})

	local ffPill = Ui.button(runHud, {
		Name = "FastForward",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.42, 0),
		Size = UDim2.fromOffset(150, TAP),
		Text = "⏩ HOLD",
		BackgroundColor3 = Palette.exit,
		Visible = false,
	}, function() end, "")

	local objective = Ui.label(runHud, {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(460, 34),
		TextSize = 22,
		TextStrokeTransparency = 0.2,
		Text = "",
	})

	local lootBox = Ui.frame(runHud, {
		Name = "Loot",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(230, 44),
	})
	Ui.corner(lootBox, 12)
	local lootLabel = Ui.label(lootBox, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		TextColor3 = Palette.gold,
		Text = "$0 / $100",
	})
	local lootPop = Instance.new("UIScale")
	lootPop.Name = "Pop"
	lootPop.Parent = lootBox

	local strip = Ui.frame(runHud, {
		Name = "CloneStrip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(220, 44),
		BackgroundTransparency = 0.4,
	})
	Ui.corner(strip, 12)
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stripLayout.Padding = UDim.new(0, 4)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip
	local stripPad = Instance.new("UIPadding")
	stripPad.PaddingRight = UDim.new(0, 6)
	stripPad.Parent = strip

	local lastGrabTap = -math.huge -- os.clock() of the last GRAB tap (END RUN guard)
	local endBtn = Ui.button(runHud, {
		Name = "EndRun",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, H.END_RUN_Y, 0),
		Size = UDim2.fromOffset(H.END_RUN_BUTTON + 24, H.END_RUN_BUTTON),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 18,
		TextWrapped = true,
		Text = "◀◀\nEND RUN",
	}, function()
		if os.clock() - lastGrabTap < H.END_RUN_GRAB_GUARD then
			return -- a thumb that slid off GRAB
		end
		actions.endRun()
	end, "")
	local lockRing = Ui.frame(endBtn, {
		Name = "Lock",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.45,
		ZIndex = 3,
		Active = false,
	})
	Ui.corner(lockRing, 12)

	-- Interact sits where touch players expect a contextual action: lower right, left of
	-- the jump button, well away from END RUN (a thumb slipping off GRAB must not end the
	-- run; END RUN also ignores taps within END_RUN_GRAB_GUARD of a GRAB).
	local interactBtn = Ui.button(runHud, {
		Name = "Interact",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -120, 1, -16),
		Size = UDim2.fromOffset(H.INTERACT_BUTTON + 56, H.INTERACT_BUTTON),
		BackgroundColor3 = Palette.gold,
		TextSize = 20,
		TextWrapped = true,
		Text = "GRAB",
		Visible = false,
	}, function()
		hud.interact()
	end, "")

	-- One bottom message rail (fixed slots, nothing overlaps): toast above the sound
	-- caption above the spectate line. It sits above Interact during a run and above the
	-- Clone Deck between runs (hud.placeRail).
	local rail = Ui.frame(root, {
		Name = "MessageRail",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(440, 96),
		BackgroundTransparency = 1,
		ZIndex = 20,
	})
	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = Enum.FillDirection.Vertical
	railLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	railLayout.SortOrder = Enum.SortOrder.LayoutOrder
	railLayout.Padding = UDim.new(0, 2)
	railLayout.Parent = rail
	local toastLabel = Ui.label(rail, {
		Name = "Toast",
		Size = UDim2.fromOffset(440, 32),
		TextSize = 20,
		TextStrokeTransparency = 0.2,
		Text = "",
		Visible = false,
		LayoutOrder = 1,
		ZIndex = 20,
	})
	-- Sound captions (on by default, §7.4): "[Alarm!]".
	local captionLabel = Ui.label(rail, {
		Name = "Caption",
		Size = UDim2.fromOffset(300, 26),
		TextSize = 18,
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.35,
		Text = "",
		Visible = false,
		LayoutOrder = 2,
		ZIndex = 20,
	})
	local spectate = Ui.label(rail, {
		Name = "Spectate",
		Size = UDim2.fromOffset(420, 28),
		TextSize = 20,
		Text = "",
		Visible = false,
		LayoutOrder = 3,
		ZIndex = 20,
	})
	local function setRailText(label: TextLabel, text: string)
		label.Text = text
		label.Visible = text ~= ""
	end
	local toastToken = 0
	function hud.toast(text: string)
		toastToken += 1
		local token = toastToken
		setRailText(toastLabel, text)
		task.delay(H.TOAST_SECONDS, function()
			if toastToken == token then
				setRailText(toastLabel, "")
			end
		end)
	end
	local captionToken = 0
	function hud.caption(text: string)
		-- the spectate line already says it ("[Guard spotted you]")
		if spectate.Visible and string.find(spectate.Text, text, 1, true) then
			return
		end
		captionToken += 1
		local token = captionToken
		setRailText(captionLabel, text)
		task.delay(H.CAPTION_SECONDS, function()
			if captionToken == token then
				setRailText(captionLabel, "")
			end
		end)
	end
	local function setSpectate(text: string)
		setRailText(spectate, text)
	end

	-- ❚❚ menu: leave the heist mid-run or between runs (solo: the heist ends; co-op: you
	-- leave your crew's heist). The run keeps going behind the sheet: it is a loop.
	local pauseChip = Ui.button(root, {
		Name = "Menu",
		Position = UDim2.fromOffset(8, 56),
		Size = UDim2.fromOffset(TAP, TAP),
		BackgroundColor3 = Palette.inkHi,
		TextColor3 = Palette.white,
		TextSize = 26,
		Text = "❚❚",
		Visible = false,
	}, function()
		hud.openMenu()
	end, "UIToggle")
	local menuSheet = Ui.frame(root, {
		Name = "MenuSheet",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 190),
		Visible = false,
		ZIndex = 30,
	})
	Ui.corner(menuSheet, 18)
	Ui.label(menuSheet, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 26,
		Text = "Leave this heist?",
		ZIndex = 31,
	})
	local menuButtons = Ui.frame(menuSheet, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -24, 0, TAP),
		BackgroundTransparency = 1,
		ZIndex = 31,
	})
	local menuLayout = Instance.new("UIListLayout")
	menuLayout.FillDirection = Enum.FillDirection.Horizontal
	menuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	menuLayout.Padding = UDim.new(0, 12)
	menuLayout.Parent = menuButtons
	local keepBtn = Ui.button(menuButtons, {
		Size = UDim2.fromOffset(180, TAP),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 20,
		Text = "KEEP PLAYING",
		LayoutOrder = 1,
		ZIndex = 32,
	}, function()
		menuSheet.Visible = false
	end, "UIBack")
	Ui.button(menuButtons, {
		Size = UDim2.fromOffset(180, TAP),
		TextSize = 20,
		Text = "BACK TO GARAGE",
		LayoutOrder = 2,
		ZIndex = 32,
	}, function()
		menuSheet.Visible = false
		actions.leave()
	end, "UIConfirm")
	function hud.openMenu()
		menuSheet.Visible = true
		selectFor(keepBtn)
	end

	-- ◐ HIDDEN (L4's main verb): a pill with glyph + word while your own actor hides,
	-- the screen edges dimmed a little (hud.onEvent Hidden / Unhidden).
	local hiddenPill = Ui.frame(runHud, {
		Name = "Hidden",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 112),
		Size = UDim2.fromOffset(150, 36),
		BackgroundColor3 = Palette.ink,
		Visible = false,
	})
	Ui.corner(hiddenPill, 12)
	Ui.stroke(hiddenPill, Palette.steelHi, 2)
	Ui.label(hiddenPill, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		TextColor3 = Palette.steelHi,
		Text = "◐ HIDDEN",
	})
	-- The edges darken: four bars fading inwards (UIGradient), no motion.
	local hiddenEdge = Ui.frame(fxGui, {
		Name = "HiddenEdge",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Active = false,
	})
	for k, spec in { { 0, 0, 1, 0.14, 90 }, { 0, 0.86, 1, 0.14, -90 }, { 0, 0, 0.1, 1, 0 }, { 0.9, 0, 0.1, 1, 180 } } do
		local edgeBar = Ui.frame(hiddenEdge, {
			Name = "Edge" .. k,
			Position = UDim2.fromScale(spec[1], spec[2]),
			Size = UDim2.fromScale(spec[3], spec[4]),
			BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0,
			Active = false,
		})
		local g = Instance.new("UIGradient")
		g.Rotation = spec[5]
		g.Transparency = NumberSequence.new(0.45, 1)
		g.Parent = edgeBar
	end
	local function setHidden(on: boolean)
		hiddenPill.Visible = on
		hiddenEdge.Visible = on
	end

	-- A new account's first seconds (§7.5: they spawn at the open van door, never in a menu).
	local preparing = Ui.frame(root, {
		Name = "Preparing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 120),
		Visible = false,
	})
	Ui.corner(preparing, 18)
	Ui.label(preparing, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		TextColor3 = Palette.gold,
		Text = "The van door opens...",
	})
	function hud.showPreparing()
		preparing.Visible = true
	end
	function hud.hidePreparing()
		preparing.Visible = false
	end

	---------------------------------------------------------------------------
	-- Clone Deck (between runs, §3.2 rule 6)
	---------------------------------------------------------------------------
	local deckPanel = Ui.frame(root, {
		Name = "Deck",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(620, 212),
		Visible = false,
	})
	Ui.corner(deckPanel, 16)
	local deckTitle = Ui.label(deckPanel, {
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "CLONES",
	})
	local cards = Instance.new("ScrollingFrame")
	cards.Name = "Cards"
	cards.Position = UDim2.fromOffset(12, 34)
	cards.Size = UDim2.new(1, -24, 0, 86)
	cards.BackgroundTransparency = 1
	cards.BorderSizePixel = 0
	cards.ScrollingDirection = Enum.ScrollingDirection.X
	cards.AutomaticCanvasSize = Enum.AutomaticSize.X
	cards.CanvasSize = UDim2.fromScale(0, 0)
	cards.ScrollBarThickness = 4
	cards.Parent = deckPanel
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.Padding = UDim.new(0, 8)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = cards
	local actionRow = Ui.frame(deckPanel, {
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(420, TAP),
		BackgroundTransparency = 1,
	})
	local actLayout = Instance.new("UIListLayout")
	actLayout.FillDirection = Enum.FillDirection.Horizontal
	actLayout.Padding = UDim.new(0, 8)
	actLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actLayout.Parent = actionRow
	local selected = 0
	local redoBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(118, TAP), TextSize = 16, Text = "REDO", LayoutOrder = 1 },
		function()
			if selected > 0 then
				actions.deck("Redo", selected)
			end
		end
	)
	local fromBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(150, TAP), TextSize = 16, Text = "REDO + LATER", LayoutOrder = 2 },
		function()
			if selected > 0 then
				actions.deck("RedoFrom", selected)
			end
		end
	)
	local delBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(118, TAP), TextSize = 16, Text = "DELETE", LayoutOrder = 3 },
		function()
			if selected > 0 then
				actions.deck("Delete", selected)
				selected = 0
			end
		end,
		"UIBack"
	)
	local undoBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(118, TAP), TextSize = 16, Text = "UNDO", LayoutOrder = 4 },
		function()
			actions.deck("Undo")
		end,
		"UIBack"
	)
	local bustedBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(150, TAP), TextSize = 16, Text = "DELETE BUSTED ✕", LayoutOrder = 5 },
		function()
			actions.deck("DeleteBusted")
		end,
		"UIBack"
	)
	local readyBtn = Ui.button(deckPanel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(164, TAP),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 22,
		Text = "▶ RUN 2",
	}, function()
		hud.ready()
	end, "UIConfirm")

	-- RedoAlarm hint (§3.6): the deck's title says "◎ Clone ●3 sets off the alarm. Redo
	-- ●3?", that card is picked and REDO turns Alarm Red (no extra banner: small phones).
	local hintSlot = 0
	local hintShownFor = 0

	local readyWait = Ui.button(root, {
		Name = "ReadySolo",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, H.END_RUN_Y, 0),
		Size = UDim2.fromOffset(170, TAP),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 22,
		Text = "▶ RUN 2",
		Visible = false,
	}, function()
		hud.ready()
	end, "UIConfirm")

	local function isTutorial(): boolean
		return state.level ~= nil and state.level.tutorial ~= nil
	end

	local function dawnRuns(): number?
		local level = state.level
		return if level then level.dawnRuns else nil
	end

	-- "RUN 7" / "RUN 7/8" / "LAST RUN" for the button and the top bar.
	local function runName(n: number): string
		local dawn = dawnRuns()
		if dawn and n >= dawn then
			return "LAST RUN"
		elseif dawn then
			return string.format("RUN %d/%d", n, dawn)
		end
		return "RUN " .. tostring(n)
	end

	local deckOpen = true
	local function selectCard(n: number)
		selected = n
		local seat = state.mySeat or 1
		local badge = if n > 0 then Palette.badge(seat, n) else ""
		redoBtn.Text = "REDO " .. badge
		fromBtn.Text = "REDO " .. badge .. " + LATER"
		delBtn.Text = "DELETE " .. badge
		redoBtn.Visible = n > 0
		fromBtn.Visible = n > 0
		delBtn.Visible = n > 0
		-- The RedoAlarm hint's card: REDO in Alarm Red.
		redoBtn.BackgroundColor3 = if n > 0 and n == hintSlot then Palette.alarm else Palette.steel
		redoBtn.TextColor3 = if n > 0 and n == hintSlot then Palette.white else Palette.ink
		local deck = state.deck
		undoBtn.Visible = n == 0 and deck ~= nil and deck.canUndo == true
		local anyRed = false
		for _, s in if deck then deck.slots else {} do
			anyRed = anyRed or RED[s.status] == true
		end
		bustedBtn.Visible = n == 0 and anyRed
		for _, c in cards:GetChildren() do
			if c:IsA("TextButton") then
				local stroke = c:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if c:GetAttribute("Slot") == n then Palette.white else Palette.ink
					stroke.Thickness = if c:GetAttribute("Slot") == n then 3 else 2
				end
			end
		end
	end

	local function renderHint()
		local deck = state.deck
		local hint = deck and deck.hint
		local slot = if hint and hint.kind == "RedoAlarm" then tonumber(hint.slot) or 0 else 0
		hintSlot = if deck and slot > 0 and slot <= #deck.slots then slot else 0
		if hintSlot > 0 then
			local badge = Palette.badge(state.mySeat or 1, hintSlot)
			deckTitle.Text = string.format("◎ Clone %s sets off the alarm. Redo %s?", badge, badge)
			deckTitle.TextColor3 = Palette.alarm
			if hintShownFor ~= hintSlot then
				hintShownFor = hintSlot
				selectCard(hintSlot) -- the card is picked: one tap on REDO
			end
		else
			hintShownFor = 0
			deckTitle.TextColor3 = Palette.white
		end
	end

	local function renderDeck()
		for _, c in cards:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		for _, c in strip:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local deck = state.deck
		if not deck then
			return
		end
		local seat = state.mySeat or 1
		local hue = Palette.hueFor(seat)
		deckTitle.Text =
			string.format("CLONES %d/%d · tap a card to redo it", #deck.slots, tonumber(deck.cap) or #deck.slots)
		local hint = deck.hint
		local alarmSlot = if hint and hint.kind == "RedoAlarm" then tonumber(hint.slot) or 0 else 0
		for i, s in deck.slots do
			local red = RED[s.status] == true
			local status = if deck.redo == i then "REDO" else (STATUS_TEXT[s.status] or s.status)
			if i == alarmSlot then
				status = "◎ ALARM"
			end
			local card = Ui.button(cards, {
				Size = UDim2.fromOffset(TAP, 80),
				BackgroundColor3 = Palette.inkHi,
				TextColor3 = if red then Palette.tapeGrey else hue,
				TextSize = 20,
				TextWrapped = true,
				Text = Palette.badge(seat, i) .. "\n" .. status,
				LayoutOrder = i,
			}, function()
				selectCard(if selected == i then 0 else i)
			end, "UIToggle")
			card:SetAttribute("Slot", i)
			local chip = Ui.label(strip, {
				Size = UDim2.fromOffset(34, 34),
				TextSize = 18,
				TextColor3 = if red then Palette.tapeGrey else hue,
				Text = if red then Palette.glyphFor(seat) .. "✕" else Palette.badge(seat, i),
				LayoutOrder = i,
			})
			chip.BackgroundTransparency = 1
		end
		if selected > #deck.slots then
			selected = 0
		end
		renderHint()
		selectCard(selected)
	end

	function hud.onDeck()
		renderDeck()
	end

	local waiting = false
	function hud.ready()
		actions.ready()
		waiting = true
		readyBtn.Text = "WAITING..."
		readyWait.Text = "WAITING..."
	end

	---------------------------------------------------------------------------
	-- Results card (§7.3 "heist complete", §6.6)
	---------------------------------------------------------------------------
	local results = Ui.frame(root, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 326),
		Visible = false,
		ZIndex = 10,
	})
	Ui.corner(results, 18)
	local resTitle = Ui.label(results, {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 34,
		Text = "HEIST COMPLETE",
		ZIndex = 11,
	})
	local resHaul = Ui.label(results, {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 28,
		TextColor3 = Palette.gold,
		Text = "$0",
		ZIndex = 11,
	})
	local stampRow = Ui.frame(results, {
		Position = UDim2.fromOffset(16, 94),
		Size = UDim2.new(1, -32, 0, 50),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	local stampLayout = Instance.new("UIListLayout")
	stampLayout.FillDirection = Enum.FillDirection.Horizontal
	stampLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stampLayout.Padding = UDim.new(0, 10)
	stampLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stampLayout.Parent = stampRow
	local stamps: { TextLabel } = {}
	for i = 1, 3 do
		local s = Ui.label(stampRow, {
			Size = UDim2.fromOffset(136, 46),
			TextSize = 20,
			Text = "",
			LayoutOrder = i,
			ZIndex = 12,
		})
		s.BackgroundColor3 = Palette.inkHi
		s.BackgroundTransparency = 0
		Ui.corner(s, 10)
		local sc = Instance.new("UIScale")
		sc.Name = "Pop"
		sc.Parent = s
		stamps[i] = s
	end
	local resLine = Ui.label(results, {
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 20,
		Text = "",
		ZIndex = 11,
	})
	local resAward = Ui.label(results, {
		Position = UDim2.fromOffset(10, 174),
		Size = UDim2.new(1, -20, 0, 40),
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = Palette.goldHi,
		Text = "",
		ZIndex = 11,
	})
	local resButtons = Ui.frame(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, TAP),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	local resLayout = Instance.new("UIListLayout")
	resLayout.FillDirection = Enum.FillDirection.Horizontal
	resLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	resLayout.Padding = UDim.new(0, 10)
	resLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resLayout.Parent = resButtons
	local replayBtn = Ui.button(
		resButtons,
		{ Size = UDim2.fromOffset(136, TAP), Text = "REPLAY", LayoutOrder = 1 },
		function()
			local over = state.over
			if not over then
				return
			end
			if over.kind == "daily" then
				actions.selectDaily(over.daily and over.daily.day or nil)
			else
				actions.selectLevel(over.levelIndex)
			end
		end,
		"UIConfirm"
	)
	local nextBtn = Ui.button(resButtons, {
		Size = UDim2.fromOffset(136, TAP),
		Text = "NEXT ▶",
		LayoutOrder = 2,
		BackgroundColor3 = Palette.CLONE_HUES[1],
	}, function()
		local over = state.over
		local nextIndex = over and tonumber(over.nextIndex) or 0
		if nextIndex > 0 then
			actions.selectLevel(nextIndex)
		end
	end, "UIConfirm")
	local garageBtn = Ui.button(
		resButtons,
		{ Size = UDim2.fromOffset(136, TAP), Text = "GARAGE", LayoutOrder = 3 },
		function()
			actions.leave()
		end,
		"UIBack"
	)
	local resWait = Ui.label(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(TAP + 14)),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		Text = "",
		ZIndex = 11,
	})

	local function setStamp(i: number, text: string, on: boolean)
		local s = stamps[i]
		s.Text = (if on then "★ " else "☆ ") .. text
		s.TextColor3 = if on then Palette.gold else Palette.tapeGrey
		s.Visible = false
	end

	function hud.onOver(payload: any)
		local over = payload.result
		if type(over) ~= "table" then
			return
		end
		state.over = over
		state.overNext = payload.next
		results.Visible = true
		deckPanel.Visible = false
		readyWait.Visible = false
		runHud.Visible = false
		pauseChip.Visible = false
		menuSheet.Visible = false
		setHidden(false)
		local kind = over.kind or "story"
		local st = over.stars or {}
		if kind == "party" then
			-- A party cannot fail: Dawn is just its end (never a plain amber "DAWN").
			local tiersMet = tonumber(over.tierMet) or 0
			resTitle.Text = string.format("PARTY OVER · ★%d", tiersMet)
			resTitle.TextColor3 = if tiersMet > 0 then Palette.ok else Palette.gold
			resHaul.Text = Ui.money(over.banked)
			local tiers = over.tiers or {}
			local met = st.tiers or {}
			for i = 1, 3 do
				setStamp(i, Ui.money(tonumber(tiers[i]) or 0), met[i] == true)
			end
		else
			if kind == "daily" then
				resTitle.Text = if over.complete
					then "VAULT CLEARED"
					elseif over.reason == "Dawn" then "DAWN"
					else "VAULT OVER"
			else
				resTitle.Text = if over.complete
					then "HEIST COMPLETE"
					elseif over.reason == "Dawn" then "DAWN"
					else "HEIST OVER"
			end
			resTitle.TextColor3 = if over.complete then Palette.ok else Palette.amber
			resHaul.Text = Ui.money(over.banked) .. " / " .. Ui.money(over.goal)
			setStamp(1, "HAUL", st.haul == true)
			setStamp(2, "CREW", st.crew == true)
			setStamp(3, "CLEAN", st.clean == true)
		end
		-- Stamps land 0.25 s apart, each a little higher (docs/AUDIO.md §9 item 21).
		for i, s in stamps do
			local show = kind ~= "party" or (over.tiers and over.tiers[i] ~= nil)
			task.delay(AU.MEDAL_STAMP_GAP * i, function()
				if results.Visible and show then
					s.Visible = true
					Ui.pop(s)
					Sound.play("RunStamp", { pitch = 1 + i * AU.MEDAL_PITCH_STEP })
				end
			end)
		end
		local clones = over.clonesUsed or 0
		local bits = {}
		local ofMe = tonumber(over.ofMe) or 0
		if ofMe >= Config.Sim.SWARM_OF_ME then
			table.insert(bits, string.format("%d OF ME", ofMe))
		end
		table.insert(bits, string.format("%d clone%s", clones, if clones == 1 then "" else "s"))
		table.insert(bits, string.format("%d run%s", over.runs or 0, if over.runs == 1 then "" else "s"))
		table.insert(bits, Ui.clock(over.totalTime or 0))
		resLine.Text = table.concat(bits, " · ")
		local award = payload.award
		if award and award.ok and type(award.data) == "table" then
			local d = award.data
			local parts = {}
			if kind == "daily" then
				if (tonumber(d.streak) or 0) > 0 then
					table.insert(parts, string.format("STREAK %d", d.streak))
				end
				if d.ornament then
					table.insert(parts, "NEW ORNAMENT")
				end
				if (tonumber(d.stars) or 0) > 0 then
					table.insert(parts, string.format("+%d ★", d.stars))
				end
			else
				local medals = d.newMedals or {}
				if #medals > 0 then
					table.insert(parts, "NEW: " .. string.upper(table.concat(medals, ", ")))
				end
				if (tonumber(d.starsGained) or 0) > 0 then
					table.insert(parts, string.format("+%d ★", d.starsGained))
				end
				if type(d.unlocked) == "table" and #d.unlocked > 0 then
					table.insert(parts, "NEW TAPE UNLOCKED")
				end
			end
			if (tonumber(d.cash) or 0) > 0 then
				table.insert(parts, "+" .. Ui.money(d.cash))
			end
			resAward.Text = table.concat(parts, " · ")
		elseif award and not award.ok then
			resAward.Text = "Couldn't save this one." -- the code stays in the server log
		else
			resAward.Text = ""
		end
		hud.refreshResults()
	end

	-- Leader buttons on the results card (also when the leader changes while it is up).
	-- NEXT only when the next tape is open for you; else why (§5.2: "2 more ★ opens it").
	function hud.refreshResults()
		local over = state.over
		if not over or not results.Visible then
			return
		end
		local kind = over.kind or "story"
		local leader = over.leader == localPlayer.UserId
		local nextIndex = tonumber(over.nextIndex) or 0
		local nx = state.overNext
		local nextOpen = nx == nil or nx.unlocked ~= false
		local wantsNext = nextIndex > 0 and (over.complete == true or kind == "party")
		replayBtn.Visible = leader
		nextBtn.Visible = leader and wantsNext and nextOpen
		if wantsNext and not nextOpen and type(nx) == "table" then
			local stars = tonumber(nx.starsNeeded) or 0
			resWait.Text = if stars > 0
				then string.format("%d more ★ opens the next tape", stars)
				else "Clear this tape to open the next one"
		elseif not leader then
			resWait.Text = "Your crew leader picks what's next"
		else
			resWait.Text = ""
		end
		garageBtn.Text = if leader then "GARAGE" else "LEAVE"
		selectFor(if nextBtn.Visible then nextBtn else garageBtn)
	end

	---------------------------------------------------------------------------
	-- Garage: tapes (play order), daily vault, crew, join friend (§3.3, §5.3, §7.4)
	---------------------------------------------------------------------------
	local garage = Ui.frame(root, {
		Name = "Garage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(700, 326),
		Visible = false,
	})
	Ui.corner(garage, 18)
	local garageTitle = Ui.label(garage, {
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.fromOffset(440, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 26,
		Text = "PICK A TAPE",
	})
	local tapes = Instance.new("ScrollingFrame")
	tapes.Name = "Tapes"
	tapes.Position = UDim2.fromOffset(14, 44)
	tapes.Size = UDim2.fromOffset(462, 156)
	tapes.BackgroundTransparency = 1
	tapes.BorderSizePixel = 0
	tapes.ScrollingDirection = Enum.ScrollingDirection.Y
	tapes.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tapes.CanvasSize = UDim2.fromScale(0, 0)
	tapes.ScrollBarThickness = 4
	tapes.Parent = garage
	local tapeGrid = Instance.new("UIGridLayout")
	tapeGrid.CellSize = UDim2.fromOffset(146, 88)
	tapeGrid.CellPadding = UDim2.fromOffset(8, 8)
	tapeGrid.SortOrder = Enum.SortOrder.LayoutOrder
	tapeGrid.Parent = tapes

	local daily = Ui.frame(garage, {
		Name = "Daily",
		Position = UDim2.fromOffset(14, 208),
		Size = UDim2.fromOffset(462, 106),
		BackgroundColor3 = Palette.inkHi,
		BackgroundTransparency = 0,
	})
	Ui.corner(daily, 12)
	Ui.stroke(daily, Palette.gold, 2)
	local dailyTitle = Ui.label(daily, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(200, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		TextColor3 = Palette.gold,
		Text = "DAILY VAULT",
	})
	local dailyName = Ui.label(daily, {
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.fromOffset(200, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextSize = 18,
		Text = "",
	})
	local dailyInfo = Ui.label(daily, {
		Position = UDim2.fromOffset(12, 70),
		Size = UDim2.fromOffset(200, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextSize = 16,
		TextColor3 = Palette.steelHi,
		Text = "",
	})
	local catchUpMode = false
	local catchBtn = Ui.button(daily, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -136, 0.5, 0),
		Size = UDim2.fromOffset(116, TAP),
		TextSize = 16,
		TextWrapped = true,
		Text = "CATCH UP",
	}, function()
		catchUpMode = not catchUpMode
		hud.showGarage()
	end, "UIToggle")
	local playDailyBtn = Ui.button(daily, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(116, TAP),
		BackgroundColor3 = Palette.gold,
		TextSize = 20,
		Text = "PLAY",
	}, function()
		local g = state.garage
		local d = g and g.daily
		if not d or d.enabled == false then
			hud.toast("The daily vault is closed right now.")
		elseif g.leader ~= localPlayer.UserId then
			hud.toast("Your crew leader picks the tape.")
		else
			actions.selectDaily(nil)
		end
	end, "UIConfirm")

	local crewBox = Ui.frame(garage, {
		Position = UDim2.fromOffset(486, 44),
		Size = UDim2.fromOffset(200, 270),
		BackgroundColor3 = Palette.inkHi,
		BackgroundTransparency = 0,
	})
	Ui.corner(crewBox, 12)
	local crewList = Instance.new("ScrollingFrame")
	crewList.Position = UDim2.fromOffset(8, 8)
	crewList.Size = UDim2.new(1, -16, 1, -16)
	crewList.BackgroundTransparency = 1
	crewList.BorderSizePixel = 0
	crewList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	crewList.CanvasSize = UDim2.fromScale(0, 0)
	crewList.ScrollBarThickness = 4
	crewList.Parent = crewBox
	local crewLayout = Instance.new("UIListLayout")
	crewLayout.Padding = UDim.new(0, 6)
	crewLayout.SortOrder = Enum.SortOrder.LayoutOrder
	crewLayout.Parent = crewList

	local friendCache: { [number]: boolean } = {}
	local function isFriend(userId: number): boolean
		local known = friendCache[userId]
		if known ~= nil then
			return known
		end
		friendCache[userId] = false
		task.spawn(function()
			local ok, res = pcall(function()
				return localPlayer:IsFriendsWithAsync(userId)
			end)
			friendCache[userId] = ok and res == true
			if friendCache[userId] and state.where == "garage" then
				hud.showGarage()
			end
		end)
		return false
	end

	local garageOpen = false

	local function clearTapes()
		for _, c in tapes:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
	end

	-- A tape's name from its data key (the garage list carries both).
	local function tapeName(dataKey: string): string
		local g = state.garage
		for _, other in (g and g.levels) or {} do
			if other.dataKey == dataKey then
				return tostring(other.name)
			end
		end
		return dataKey
	end

	-- A party level's medals are its haul tiers; a story level's are Haul / Crew / Clean.
	local function starsText(lv: any): string
		local n = #(lv.medals or {})
		return string.rep("★", math.min(n, 3)) .. string.rep("☆", math.max(0, 3 - n))
	end

	local function renderTapes(leader: boolean): TextButton?
		local g = state.garage
		local first: TextButton? = nil
		for _, lv in g.levels or {} do
			local party = lv.kind == "party"
			local tag = if party
				then string.format("PARTY · %d CLONES", tonumber(lv.cap) or 8)
				else string.format("%d SEC RUNS", tonumber(lv.runSeconds) or 0)
			local stars = tonumber(lv.starsNeeded) or 0
			local lockText = if lv.needsClear ~= nil
				then "CLEAR " .. string.upper(tapeName(lv.needsClear))
				elseif stars > 0 then string.format("★ %d MORE", stars)
				else "LOCKED"
			local text = string.format(
				"%d  %s\n%s\n%s",
				lv.index,
				string.upper(tostring(lv.name)),
				tag,
				if lv.unlocked then starsText(lv) else lockText
			)
			local b = Ui.button(tapes, {
				BackgroundColor3 = if not lv.unlocked
					then Palette.plumHi
					elseif party then Palette.goldHi
					else Palette.steelHi,
				TextColor3 = Palette.ink,
				TextSize = 16,
				TextWrapped = true,
				Text = text,
				LayoutOrder = lv.index,
			}, function()
				if not leader then
					hud.toast("Your crew leader picks the tape.")
				elseif not lv.unlocked then
					Sound.play("UIError")
					hud.toast(
						if lv.needsClear ~= nil
							then "Clear " .. tapeName(lv.needsClear) .. " first."
							elseif stars > 0 then string.format("%d more ★ to open it.", stars)
							else "That tape is locked."
					)
				else
					actions.selectLevel(lv.index)
				end
			end)
			first = first or b
		end
		return first
	end

	local function renderCatchUp(leader: boolean): TextButton?
		local g = state.garage
		local d = g and g.daily or {}
		local back = Ui.button(tapes, {
			BackgroundColor3 = Palette.steel,
			TextSize = 18,
			Text = "◀ TAPES",
			LayoutOrder = 0,
		}, function()
			catchUpMode = false
			hud.showGarage()
		end, "UIBack")
		for i, c in d.catchUp or {} do
			Ui.button(tapes, {
				BackgroundColor3 = Palette.goldHi,
				TextColor3 = Palette.ink,
				TextSize = 16,
				TextWrapped = true,
				Text = string.format(
					"%s\n%s\nCATCH UP",
					if c.advent then "DEC " .. tostring(c.advent) else dateText(c.day),
					string.upper(tostring(c.name))
				),
				LayoutOrder = i,
			}, function()
				if not leader then
					hud.toast("Your crew leader picks the tape.")
				else
					actions.selectDaily(c.day)
				end
			end, "UIConfirm")
		end
		return back
	end

	local function renderDaily()
		local g = state.garage
		local d = g and g.daily
		-- Hidden until the first tape is cleared (the server refuses it too, §7.5).
		if type(d) ~= "table" or d.locked == true then
			daily.Visible = false
			return
		end
		daily.Visible = true
		local when = if d.advent then "DEC " .. tostring(d.advent) else dateText(tonumber(d.day) or 0)
		dailyTitle.Text = "DAILY VAULT · " .. when
		dailyName.Text = string.upper(tostring(d.name or ""))
		local info = {}
		local mod = MODIFIER_TEXT[d.modifier or "None"] or ""
		if mod ~= "" then
			table.insert(info, mod)
		end
		if (tonumber(d.streak) or 0) > 0 then
			table.insert(info, string.format("STREAK %d", d.streak))
		end
		if type(d.secondsUntilReset) == "number" then
			table.insert(info, "new in " .. durationText(d.secondsUntilReset))
		end
		dailyInfo.Text = table.concat(info, " · ")
		local catchUps = #(d.catchUp or {})
		catchBtn.Visible = catchUps > 0
		catchBtn.Text = if catchUpMode then "◀ TAPES" else string.format("CATCH UP (%d)", catchUps)
		if d.enabled == false then
			playDailyBtn.Text = "CLOSED"
			playDailyBtn.BackgroundColor3 = Palette.steelLo
		else
			playDailyBtn.Text = if d.clearedToday then "REPLAY ✓" else "PLAY"
			playDailyBtn.BackgroundColor3 = Palette.gold
		end
	end

	function hud.showGarage()
		local g = state.garage
		if not g then
			return
		end
		local wasOpen = garageOpen
		garageOpen = true
		garage.Visible = true
		runHud.Visible = false
		deckPanel.Visible = false
		results.Visible = false
		readyWait.Visible = false
		pauseChip.Visible = false
		menuSheet.Visible = false
		preparing.Visible = false
		clearTapes()
		local leader = g.leader == localPlayer.UserId
		local catchUps = g.daily and g.daily.catchUp and #g.daily.catchUp or 0
		if catchUpMode and catchUps == 0 then
			catchUpMode = false
		end
		garageTitle.Text = if catchUpMode then "ADVENT CATCH-UP" else "PICK A TAPE"
		local first = if catchUpMode then renderCatchUp(leader) else renderTapes(leader)
		renderDaily()
		for _, c in crewList:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		Ui.label(crewList, { Size = UDim2.new(1, 0, 0, 24), Text = "CREW", LayoutOrder = 0 })
		local inCrew: { [number]: boolean } = {}
		for _, m in g.members or {} do
			inCrew[m.userId] = true
			Ui.label(crewList, {
				Size = UDim2.new(1, 0, 0, 24),
				TextSize = 16,
				TextColor3 = Palette.hueFor(m.seat),
				Text = Palette.glyphFor(m.seat) .. " " .. m.name .. (if m.userId == g.leader then " (leader)" else ""),
				LayoutOrder = m.seat,
			})
		end
		if g.pending then
			Ui.label(crewList, {
				Size = UDim2.new(1, 0, 0, 40),
				TextSize = 16,
				TextWrapped = true,
				Text = "You join at their next heist.",
				LayoutOrder = 10,
			})
		end
		if #(g.members or {}) > 1 then
			Ui.button(crewList, { Size = UDim2.new(1, 0, 0, TAP), Text = "LEAVE CREW", LayoutOrder = 20 }, function()
				actions.leave()
			end, "UIBack")
		end
		-- LiveFlag kill switch `joinFriend` (ReplicatedStorage.LiveFlags, docs/ANALYTICS.md) hides JOIN.
		local flags = ReplicatedStorage:FindFirstChild("LiveFlags")
		local joinOn = not (flags and flags:GetAttribute("joinFriend") == false)
		local order = 30
		for _, p in Players:GetPlayers() do
			if joinOn and p ~= localPlayer and not inCrew[p.UserId] and isFriend(p.UserId) then
				order += 1
				Ui.button(crewList, {
					Size = UDim2.new(1, 0, 0, TAP),
					TextSize = 16,
					TextWrapped = true,
					Text = "JOIN " .. p.DisplayName,
					LayoutOrder = order,
				}, function()
					actions.joinFriend(p.UserId)
				end, "UIConfirm")
			end
		end
		if first then
			selectFor(first)
		end
		-- Advent window: sleigh bells once per garage visit (docs/AUDIO.md §9 item 23).
		if not wasOpen and g.daily and g.daily.advent and not g.daily.clearedToday then
			Sound.play("SleighBells")
		end
	end

	function hud.hideGarage()
		garage.Visible = false
		garageOpen = false
	end

	---------------------------------------------------------------------------
	-- Run state
	---------------------------------------------------------------------------
	local endedCount = 0
	local runStartAt = 0
	local myEnded = false
	local hintStage = 0
	local lastWhole = -1
	local lastPulse = -1
	local lastTView = 0
	local worldLocks: { any } = {} -- WorldView.timeLocks() (a cached array)
	-- objective line (§7.4): shown when it changes, then hidden after OBJECTIVE_SECONDS
	local objText = ""
	local objSince = 0
	local stopsLineUntil = 0 -- L1: "Your clone stops where you stop." from the clone's press
	local noBankRuns = 0 -- runs in a row without a bank (the level line comes back)
	local lastLockToast = -math.huge
	local alarmSeenHeist = false -- party levels: the first till alarm is the GETAWAY stamp
	local alarmToastRun = -1 -- the run whose alarm already had its in-run toast
	local function isParty(): boolean
		return state.level ~= nil and state.level.kind == "party"
	end

	-- Loot meter count-up (§7.3: 0.35-1.0 s, a rising tick, a landing ding).
	local shown, countFrom, countTo, countT0, countDur, countTicks, counting = 0, 0, 0, 0, 0, 0, false

	local function clearMarkers()
		for _, c in markers:GetChildren() do
			c:Destroy()
		end
	end

	local function marker(t: number, length: number, color: Color3, text: string)
		local m = Ui.label(markers, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.clamp(t / math.max(length, 0.01), 0, 1), 0.5),
			Size = UDim2.fromOffset(16, 16),
			TextSize = 16,
			TextColor3 = color,
			Text = text,
		})
		m.TextStrokeTransparency = 0.2
	end

	local function myActor(a: any): boolean
		return a ~= nil and a.kind == "live" and a.owner == localPlayer.UserId
	end

	---------------------------------------------------------------------------
	-- L1 stuck hints (§7.5): plate re-pulse -> beam from your feet -> Mentor ghost
	---------------------------------------------------------------------------
	local hintFolder: Folder? = nil
	local hintRing: BasePart? = nil
	local hintBeam: Beam? = nil
	local mentor: any = nil
	local mentorParts: { BasePart } = {}
	local mentorCfs: { CFrame } = {}
	local mentorT0 = 0

	local function hintFolderOf(): Folder
		local f = hintFolder
		if f and f.Parent then
			return f
		end
		local nf = Instance.new("Folder")
		nf.Name = "EH_Hints"
		nf.Parent = workspace
		hintFolder = nf
		return nf
	end

	local function clearHints()
		if hintBeam then
			local a0, a1 = hintBeam.Attachment0, hintBeam.Attachment1
			hintBeam:Destroy()
			if a0 then
				a0:Destroy()
			end
			if a1 then
				a1:Destroy()
			end
			hintBeam = nil
		end
		if hintRing then
			hintRing:Destroy()
			hintRing = nil
		end
		if mentor then
			mentor.model:Destroy()
			mentor = nil
		end
	end

	local function platePart(world: any): BasePart?
		local p = world and world.partFor("plate", 1)
		return if p and p:IsA("BasePart") then p else nil
	end

	local function showHints(world: any, now: number)
		local plate = platePart(world)
		if not plate then
			return
		end
		-- 1: the plate re-pulses (a neon ring breathing on it)
		if hintStage >= 1 and not hintRing then
			local ring = Instance.new("Part")
			ring.Name = "HintRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.CastShadow = false
			ring.Material = Enum.Material.Neon
			ring.Color = Palette.CLONE_HUES[1]
			ring.Parent = hintFolderOf()
			hintRing = ring
		end
		local ring = hintRing
		if ring then
			local k = if state.reduced then 0.5 else 0.5 + 0.5 * math.sin(now * 5)
			ring.Size = Vector3.new(0.08, 4.6 + k, 4.6 + k)
			ring.Transparency = 0.25 + 0.5 * (1 - k)
			ring.CFrame = CFrame.new(plate.Position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		end
		-- 2: a beam from your feet to the plate
		if hintStage >= 2 and not hintBeam then
			local char = localPlayer.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				local a0 = Instance.new("Attachment")
				a0.Name = "HintA0"
				a0.Parent = r
				local a1 = Instance.new("Attachment")
				a1.Name = "HintA1"
				a1.Position = Vector3.new(0, 0.3, 0)
				a1.Parent = plate
				local beam = Instance.new("Beam")
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Color = ColorSequence.new(Palette.white)
				beam.Width0 = 0.4
				beam.Width1 = 0.4
				beam.LightEmission = 1
				beam.FaceCamera = true
				beam.Parent = plate
				hintBeam = beam
			end
		end
		-- 3: the Mentor ghost walks from your spawn to the plate and stands on it
		if hintStage >= 3 and state.level then
			if not mentor then
				local rig = Rigs.buildMannequin()
				Rigs.tint(rig, Palette.white)
				Rigs.setFade(rig, 0.55)
				rig.model.Parent = hintFolderOf()
				mentor = rig
				mentorT0 = now
			end
			local spawns = state.level.spawns
			local sp = spawns[((state.mySeat or 1) - 1) % #spawns + 1]
			local origin: Vector3 = state.origin
			local from = origin + Vector3.new(sp.x, state.level.floorY, sp.z)
			local to = Vector3.new(plate.Position.X, from.Y, plate.Position.Z)
			local cycle = (now - mentorT0) % 5
			local u = math.clamp(cycle / 2.5, 0, 1)
			local dir = to - from
			local yaw = if dir.Magnitude > 0.1 then math.atan2(-dir.X, -dir.Z) else 0
			local feet = CFrame.new(from:Lerp(to, u)) * CFrame.Angles(0, yaw, 0)
			table.clear(mentorParts)
			table.clear(mentorCfs)
			local walking = u < 1
			Rigs.pose(mentor, feet, now * 7, if walking then 1 else 0, mentorParts, mentorCfs)
			workspace:BulkMoveTo(mentorParts, mentorCfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	function hud.onRun(msg: any)
		garage.Visible = false
		garageOpen = false
		results.Visible = false
		deckPanel.Visible = false
		readyWait.Visible = false
		preparing.Visible = false
		runHud.Visible = true
		pauseChip.Visible = true
		waiting = false
		endedCount = 0
		myEnded = false
		setSpectate("")
		setHidden(false)
		hud.placeRail(false)
		objText, objSince = "", 0
		local n = tonumber(msg.run) or 1
		if n <= 1 then
			alarmSeenHeist = false
			noBankRuns = 0
			stopsLineUntil = 0
		end
		-- A redo run says so (§7.4): "REDO ●3" in the run label colour.
		local deck = state.deck
		local redo = if deck and not deck.locked then tonumber(deck.redo) or 0 else 0
		runLabel.Text = if redo > 0 then "REDO " .. Palette.badge(state.mySeat or 1, redo) else runName(n)
		local dawn = dawnRuns()
		runLabel.TextColor3 = if dawn and n >= dawn then Palette.amber else Palette.hueFor(state.mySeat or 1)
		runStartAt = os.clock() + (msg.transition or 0)
		hintStage = 0
		lastWhole = -1
		clearHints()
		clearMarkers()
		-- Your clones' recorded events on the run bar (grabs), so you can time against them.
		local length = if state.clock then state.clock.length else 30
		for _, a in msg.actors do
			local rec = a.kind == "clone" and a.owner == localPlayer.UserId and state.recs[a.key]
			if rec then
				for _, e in rec.events do
					if e.kind == KIND.Grab then
						marker(e.t, length, Palette.gold, "$")
					end
				end
			end
		end
		-- Redo: the replaced clone's old grabs in grey, so you can see what you are redoing.
		local old = if redo > 0 and deck and deck.slots[redo] then state.recs[deck.slots[redo].key] else nil
		if old then
			for _, e in old.events do
				if e.kind == KIND.Grab then
					marker(e.t, length, Palette.tapeGrey, "$")
				end
			end
		end
		GuiService.SelectedObject = nil
	end

	-- Dawn warnings at the start of a run (party and daily levels, §4.2, §5.3).
	function hud.dawnWarning(n: number)
		local dawn = dawnRuns()
		if not dawn then
			return
		end
		local left = dawn - n
		if left <= 0 then
			hud.toast("☾ Last run before Dawn!")
		elseif left < H.DAWN_WARN_RUNS then
			hud.toast(string.format("☾ Dawn after %d more run%s", left, if left == 1 then "" else "s"))
		end
	end

	function hud.onRunEnd(p: any)
		interactBtn.Visible = false
		ffPill.Visible = false
		alarmPill.Visible = false
		setSpectate("")
		setHidden(false)
		clearHints()
		local nextRun = (state.run and state.run.run or 0) + 1
		readyBtn.Text = "▶ " .. runName(nextRun)
		readyWait.Text = "▶ " .. runName(nextRun)
		local summary = p and p.summary
		if type(summary) ~= "table" then
			return
		end
		noBankRuns = if (tonumber(summary.banked) or 0) > 0 then 0 else noBankRuns + 1
		if summary.escaped and not isParty() then
			hud.bigStamp("ESCAPED!", Palette.gold)
		end
		local alarm = summary.alarm
		-- One alarm message per run: no repeat when the in-run toast already said it, and
		-- none on party levels, where the till alarm is the getaway, not a mistake.
		local runIndex = tonumber(p.run) or -1
		if type(alarm) == "table" and not summary.escaped and not isParty() and alarmToastRun ~= runIndex then
			local hint = state.deck and state.deck.hint
			if alarm.kind == "catch" then
				hud.toast("Gus raised the alarm.")
			elseif alarm.kind == "clone" and alarm.ownerId == localPlayer.UserId and not hint then
				hud.toast(string.format("Clone %s set off the alarm.", Palette.badge(state.mySeat or 1, alarm.slot)))
			elseif alarm.kind == "live" and alarm.ownerId == localPlayer.UserId then
				hud.toast("You set off the alarm.")
			end
		end
	end

	-- The message rail: above Interact during a run, above the Clone Deck between runs.
	function hud.placeRail(overDeck: boolean)
		rail.Position = UDim2.new(0.5, 0, 1, if overDeck then -(212 + 16) else -96)
	end

	-- Between runs: show the deck (from L2) or a plain RUN button with its countdown.
	-- Party levels keep every clone ("8 OF ME"): no deck actions, a short auto-start.
	function hud.showBetween()
		runHud.Visible = true
		pauseChip.Visible = true
		endBtn.Visible = false
		interactBtn.Visible = false
		alarmPill.Visible = false
		setSpectate("")
		setHidden(false)
		local deck = state.deck
		local locked = deck == nil or deck.locked == true
		deckPanel.Visible = not locked and deckOpen
		readyWait.Visible = not isTutorial() and (locked or not deckOpen)
		hud.placeRail(deckPanel.Visible)
		objective.Position = UDim2.new(0.5, 0, 0, 74)
		objective.Text = if isParty() and deck
			then string.format("Every clone stays for the party: %d", #deck.slots)
			else ""
		if deckPanel.Visible then
			selectFor(readyBtn)
		elseif readyWait.Visible then
			selectFor(readyWait)
		end
		renderDeck()
	end

	function hud.toggleDeck()
		if state.phase == "Between" and state.deck and not state.deck.locked then
			deckOpen = not deckOpen
			deckPanel.Visible = deckOpen
			readyWait.Visible = not deckOpen
			hud.placeRail(deckOpen)
			renderHint()
			Sound.play("UIToggle")
		end
	end

	local function diamondMoment()
		Sound.play("DiamondShimmer")
		placeDim()
		dim.Enabled = true
		dim.Brightness = -H.DIAMOND_DIM
		local tw = TweenService:Create(dim, TweenInfo.new(H.DIAMOND_DIM_SECONDS), { Brightness = 0 })
		tw.Completed:Once(function()
			dim.Enabled = false
		end)
		tw:Play()
	end

	-- "Locked: opens in 0:14" (the same countdown the button and the till label show),
	-- at most once per TOAST_SECONDS while a kid mashes the till.
	local function lockedToast(opensAt: number?)
		local now = os.clock()
		if now - lastLockToast < H.TOAST_SECONDS then
			return
		end
		lastLockToast = now
		local at = opensAt
		if not at then
			for _, l in worldLocks do
				at = if at then math.min(at, l.opensAt) else l.opensAt
			end
		end
		Sound.play("UIError")
		hud.toast(
			if at then "Locked: opens in " .. Ui.clock(math.max(0, at - lastTView)) else "Locked. Wait for the timer."
		)
	end

	-- Event-log entries (already decoded) for HUD reactions.
	function hud.onEvent(e: any, live: boolean)
		local run = state.run
		if not run then
			return
		end
		local a = run.actorById[e.a]
		local hz = Config.Rec.HZ
		local length = if state.clock then state.clock.length else 30
		if e.kind == EV.EndRun or e.kind == EV.Timeout or e.kind == EV.Left then
			endedCount += 1
			if myActor(a) then
				myEnded = true
				-- Only when others are still running (solo: the run is already over).
				local othersRunning = (state.liveCount or 1) > endedCount
				if e.kind == EV.Timeout then
					setSpectate("The tape ran out.")
				elseif othersRunning and not isTutorial() then
					setSpectate("Wait for your crew")
				end
			end
		elseif e.kind == EV.Caught then
			local target = run.actorById[e.b]
			endedCount += 1
			if myActor(target) then
				myEnded = true
				setSpectate("[Guard spotted you]")
				if live then
					hud.flashRed()
					hud.bigStamp("BUSTED", Palette.alarm)
				end
			end
		elseif e.kind == EV.Zap then
			if a and a.kind == "live" then
				endedCount += 1
				if a.owner == localPlayer.UserId then
					myEnded = true
					setSpectate("Zapped by a laser.")
					if live then
						hud.flashRed()
						hud.bigStamp("ZAPPED", Palette.alarm)
					end
				end
			elseif a and a.owner == localPlayer.UserId then
				marker(e.tick / hz, length, Palette.alarm, "⚡")
			end
		elseif e.kind == EV.Busted then
			local target = run.actorById[e.b]
			if target and target.owner == localPlayer.UserId then
				marker(e.tick / hz, length, Palette.alarm, "✕")
			end
		elseif e.kind == EV.Stuck then
			if a and a.owner == localPlayer.UserId then
				marker(e.tick / hz, length, Palette.alarm, "✕")
			end
		elseif e.kind == EV.Bank and live then
			local value = 0
			local level = state.level
			local def = level and level.loot[e.b]
			if def then
				value = def.value
			end
			local who = if a and a.kind == "clone" then Palette.badge(a.seat, a.slot) .. " " else ""
			hud.toast(who .. "+" .. Ui.money(value))
			Ui.pop(lootBox)
		elseif e.kind == EV.Grab and live then
			local level = state.level
			local def = level and level.loot[e.b]
			if def and def.kind == "Diamond" then
				diamondMoment()
			end
		elseif e.kind == EV.Squeeze and live then
			hud.toast("Crew is waiting")
		elseif e.kind == EV.GoalMet and live then
			hud.toast("Goal banked! Finish the run.")
		elseif e.kind == EV.Swarm and live then
			-- "8 OF ME" (count-correct): copies of you; in co-op "16 ROBBERS" for the crew.
			if e.a == (state.mySeat or 1) then
				local need = Config.Sim.SWARM_OF_ME
				if e.b >= need then
					hud.bigStamp(
						string.format("%d OF ME", e.b),
						Palette.hueFor(state.mySeat or 1),
						H.SWARM_STAMP_SECONDS
					)
				elseif e.c >= need and #(state.crew or {}) > 1 then
					hud.bigStamp(string.format("%d ROBBERS", e.c), Palette.gold, H.SWARM_STAMP_SECONDS)
				end
			end
		elseif e.kind == EV.Tier and live then
			hud.bigStamp(string.format("★ HAUL %d", e.a), Palette.gold, H.TIER_STAMP_SECONDS)
		elseif e.kind == EV.AlarmOn and live then
			alarmToastRun = run.run
			if isParty() then
				-- The party's till is the getaway, not a mistake: one stamp per heist, then
				-- only the counter (no blame, no repeat).
				if not alarmSeenHeist then
					alarmSeenHeist = true
					hud.bigStamp("GETAWAY!", Palette.gold)
					hud.toast("Till alarm: everyone to the van!")
				end
			else
				hud.bigStamp("ALARM!", Palette.alarm)
				hud.flashRed()
				if a and a.kind == "clone" then
					hud.toast(string.format("Clone %s set off the alarm!", Palette.badge(a.seat, a.slot)))
				elseif e.a == 0 then
					hud.toast("Gus raised the alarm! Run for the van!")
				else
					hud.toast("Run for the van!")
				end
			end
		elseif e.kind == EV.VanLeft and live then
			hud.bigStamp("THE VAN LEFT", Palette.alarm)
		elseif e.kind == EV.Dawn and live then
			hud.bigStamp("☾ DAWN", Palette.amber)
		elseif e.kind == EV.HeistComplete and live then
			hud.bigStamp("HEIST COMPLETE", Palette.gold)
		elseif e.kind == EV.Rejected and live then
			if myActor(a) and e.c == FAIL.Locked then
				lockedToast(nil)
			end
		elseif e.kind == EV.Hidden then
			if myActor(a) then
				setHidden(true) -- the tuck sound comes from EventCues (Hidden)
			end
		elseif e.kind == EV.Unhidden then
			if myActor(a) then
				setHidden(false)
			end
		elseif e.kind == EV.PlateDown and live then
			-- L1: the clone's first press is the moment "your clone stops where you stop" lands
			-- (PlateDown: a = plate, b = actor).
			local presser = run.actorById[e.b]
			if
				isTutorial()
				and presser
				and presser.kind == "clone"
				and presser.owner == localPlayer.UserId
				and stopsLineUntil == 0
			then
				stopsLineUntil = os.clock() + H.STOPS_LINE_SECONDS
			end
		end
	end

	function hud.flashRed()
		if state.reduced then
			return
		end
		vignette.BackgroundTransparency = 0.7
		TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end

	-- Set by HeistClient (RewindDirector): (text, colour, hold seconds?).
	hud.bigStamp = function(_text: string, _color: Color3, _hold: number?) end

	---------------------------------------------------------------------------
	-- Per frame
	---------------------------------------------------------------------------
	local function myRootLevelPos(): Vector3?
		local char = localPlayer.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") and state.origin then
			return r.Position - state.origin
		end
		return nil
	end

	local function onPlate(pos: Vector3, plateIndex: number): boolean
		local level = state.level
		local def = level and level.plates[plateIndex]
		if not def then
			return false
		end
		local b = def.box
		return pos.X >= b.minX and pos.X <= b.maxX and pos.Z >= b.minZ and pos.Z <= b.maxZ and pos.Y <= b.maxY
	end

	-- Is the L1 auto-end armed this run (run 1, or later until a clone stood on the plate)?
	local function autoEndArmed(): boolean
		local folder = state.folder
		return folder ~= nil and folder:GetAttribute("AutoEndArmed") == true
	end

	-- L1 FTUE lines (§7.5, from the world state: a kid who ended run 1 off the plate is
	-- led back to it) and the generic objective. Returns the line, whether END RUN should
	-- pulse, and whether the line stays up (else it shows for OBJECTIVE_SECONDS after it
	-- changes, §7.4).
	local function objectiveText(_tView: number, pos: Vector3?): (string, boolean, boolean)
		local run = state.run
		local runIndex = if run then run.run else 1
		local carrying = state.carrying == true
		if isTutorial() then
			if autoEndArmed() then
				local on = pos ~= nil and onPlate(pos, 1)
				if on then
					return "Stay on it. Tap END RUN.", true, true
				end
				return "Step on the plate", false, true
			end
			if os.clock() < stopsLineUntil then
				return "Your clone stops where you stop.", false, true
			end
			local folder = state.folder
			local plateHeld = folder ~= nil and folder:GetAttribute("P1Held") == true
			if not plateHeld and not carrying then
				return "Wait for your clone to open the door", false, true
			end
			return if carrying then "Bank it at the van" else "Grab the cash", false, true
		end
		if carrying then
			return "Bank it at the van", false, false
		end
		local id = state.level and state.level.id
		local line = id and LEVEL_LINES[id]
		if line and (runIndex == 1 or noBankRuns >= LEVEL_LINE_STUCK_RUNS) then
			return line, false, false
		end
		return "Grab the loot", false, false
	end

	local nearLoot: number? = nil
	local nearLock: number? = nil

	function hud.interact()
		if not nearLoot then
			return
		end
		lastGrabTap = os.clock()
		local opensAt = nearLock
		if opensAt and lastTView < opensAt - H.LOCKED_SLACK then
			lockedToast(opensAt)
			return
		end
		actions.interact(KIND.Grab, nearLoot)
		Ui.pop(interactBtn)
	end

	local function updateCount(now: number)
		local banked = (state.folder and state.folder:GetAttribute("Banked")) or 0
		if type(banked) ~= "number" then
			banked = 0
		end
		if banked ~= countTo then
			if banked > countTo then
				countFrom = shown
				countDur = math.clamp(0.35 + (banked - shown) / 1000 * 0.3, 0.35, 1.0)
				countT0 = now
				countTicks = 0
				counting = true
			else
				shown = banked
				counting = false
			end
			countTo = banked
		end
		if counting then
			local u = math.clamp((now - countT0) / countDur, 0, 1)
			shown = countFrom + (countTo - countFrom) * u
			local want = math.floor((now - countT0) / 0.08)
			if want > countTicks and u < 1 then
				countTicks = want
				Sound.play("CountTick", { step = math.min(countTicks - 1, #AU.COUNT_UP_STEPS - 1) })
			end
			if u >= 1 then
				counting = false
				Sound.play("CountDone")
			end
		end
	end

	local function lootText(): string
		local level = state.level
		local tiers = level and level.tiers
		if tiers then
			local met = (state.folder and state.folder:GetAttribute("TierMet")) or 0
			met = if type(met) == "number" then met else 0
			local nextTier = tiers[met + 1]
			if nextTier then
				return string.format("%s / %s ★%d", Ui.money(shown), Ui.money(nextTier), met + 1)
			end
			return Ui.money(shown) .. " " .. string.rep("★", #tiers)
		end
		local goal = if level then level.goal else 0
		return Ui.money(shown) .. " / " .. Ui.money(goal)
	end

	-- Between runs: "▶ RUN 3 · 0:08" counts down to the auto-start; co-op adds "2/3 READY".
	local function updateBetween()
		local folder = state.folder
		if state.phase ~= "Between" or not folder then
			return
		end
		local at = folder:GetAttribute("AutoStartAt")
		local left = if type(at) == "number" then at - workspace:GetServerTimeNow() else nil
		local nextRun = (state.run and state.run.run or 0) + 1
		local crew = tonumber(folder:GetAttribute("Crew")) or 1
		local ready = tonumber(folder:GetAttribute("Ready")) or 0
		local text = if waiting then "WAITING..." else "▶ " .. runName(nextRun)
		if crew > 1 then
			text ..= string.format(" · %d/%d READY", ready, crew)
		end
		if left and left > 0 and not isTutorial() then
			text ..= " · " .. Ui.clock(left)
		end
		if readyBtn.Text ~= text then
			readyBtn.Text = text
			readyWait.Text = text
		end
	end

	function hud.update(tView: number, now: number, _dt: number, world: any)
		if state.where ~= "heist" then
			return
		end
		if state.phase ~= "Run" or not state.clock then
			-- between runs and after: the meter still lands
			updateCount(now)
			lootLabel.Text = lootText()
			updateBetween()
			return
		end
		lastTView = tView
		local clock = state.clock
		local length = clock.length
		local remaining = math.max(0, length - tView)
		local red = remaining <= H.TIMER_RED_SECONDS
		timerLabel.TextColor3 = if red then Palette.alarm else Palette.white
		timerLabel.Text = (if red then "◎ " else "") .. Ui.clock(remaining)
		timerScale.Scale = if remaining <= H.TIMER_PULSE_SECONDS and not state.reduced
			then 1 + 0.08 * math.max(0, math.sin(now * 2 * math.pi))
			else 1
		-- Countdown ticks for the last COUNTDOWN_FROM seconds (docs/AUDIO.md §9 item 19).
		local whole = math.ceil(remaining - 1e-6)
		if whole ~= lastWhole and os.clock() >= runStartAt then
			if lastWhole >= 0 then
				local step = Mix.countdownStep(remaining, AU.COUNTDOWN_FROM)
				if step then
					Sound.play("CountdownTick", { step = step, caption = step == 0 })
				end
				if whole >= 1 and whole <= AU.HEARTBEAT_FROM then
					Sound.play("Heartbeat")
				end
			end
			lastWhole = whole
		end
		barFill.Size = UDim2.fromScale(math.clamp(tView / math.max(length, 0.01), 0, 1), 1)
		updateCount(now)
		lootLabel.Text = lootText()

		-- Alarm Run counter and the red pulse (once per ALARM_PULSE_SECONDS, ≤ 3 flashes/s).
		local folder = state.folder
		local alarmOn = folder ~= nil and folder:GetAttribute("AlarmOn") == true
		alarmPill.Visible = alarmOn
		objective.Position = UDim2.new(0.5, 0, 0, if alarmOn then 120 else 74)
		hiddenPill.Position = UDim2.new(0.5, 0, 0, if alarmOn then 158 else 112)
		if alarmOn and folder then
			local vanAt = folder:GetAttribute("AlarmVanAt")
			local lockAt = folder:GetAttribute("AlarmLockAt")
			local text = "◎ VAN LEAVES "
				.. Ui.clock(math.max(0, (if type(vanAt) == "number" then vanAt else 0) - tView))
			if type(lockAt) == "number" and lockAt >= 0 and lockAt > tView then
				text ..= " · SHUTTER " .. Ui.clock(lockAt - tView)
			end
			alarmLabel.Text = text
			local beat = math.floor(now / H.ALARM_PULSE_SECONDS)
			if beat ~= lastPulse then
				lastPulse = beat
				-- party levels: the getaway is a beat, not a warning (no red pulse)
				if not state.reduced and not isParty() then
					vignette.BackgroundTransparency = 0.82
					TweenService
						:Create(vignette, TweenInfo.new(H.ALARM_PULSE_SECONDS * 0.6), { BackgroundTransparency = 1 })
						:Play()
				end
			end
		end

		-- END RUN: locked ring for the first 1.5 s; co-op count; spectators lose it.
		local started = os.clock() >= runStartAt
		endBtn.Visible = not myEnded and started
		local lockFrac = math.clamp(1 - tView / Config.Rec.END_RUN_LOCK_SECONDS, 0, 1)
		lockRing.Size = UDim2.fromScale(1, lockFrac)
		lockRing.Visible = lockFrac > 0
		local crew = state.liveCount or 1
		endBtn.Text = if crew > 1
			then string.format("◀◀\nEND RUN · %d/%d", endedCount, crew)
			else "◀◀\nEND RUN"

		local pos = myRootLevelPos()
		local text, pulseEnd, sticky = objectiveText(tView, pos)
		if text ~= objText then
			objText, objSince = text, now
		end
		objective.Text = if sticky or now - objSince < OBJECTIVE_SECONDS then text else ""
		-- L1 while the auto-end is armed: END RUN pulses only while you stand on the plate
		-- (a steady glow under reduced motion) and is dimmed off it; stuck hints run in any
		-- such run, so a kid who ended run 1 off the plate is led back (§7.5).
		if isTutorial() and autoEndArmed() then
			endBtn.BackgroundColor3 = if pulseEnd and (state.reduced or math.floor(now * 3) % 2 == 0)
				then Palette.white
				else Palette.CLONE_HUES[1]
			endBtn.BackgroundTransparency = if pulseEnd then 0 else 0.55
			if not pulseEnd and not myEnded then
				local hs = H.HINT_SECONDS
				if hintStage < #hs and tView >= hs[hintStage + 1] then
					hintStage += 1
					actions.hint(HINTS[hintStage] or "other")
				end
				if hintStage > 0 then
					showHints(world, now)
				end
			else
				clearHints()
			end
		else
			endBtn.BackgroundColor3 = Palette.hueFor(state.mySeat or 1)
			endBtn.BackgroundTransparency = 0
			if hintStage > 0 then
				hintStage = 0
				clearHints()
			end
		end

		-- Contextual Interact (nearest loot in range, not while your bag is full or spectating).
		worldLocks = world.timeLocks()
		nearLoot = nil
		nearLock = nil
		local bagFull = (state.carryCount or 0) >= (state.myCapacity or 1)
		if pos and not myEnded and started and not bagFull then
			local worldPos = state.origin + pos
			local index, value, opensAt = world.nearestLoot(worldPos, Config.Sim.INTERACT_RANGE)
			if index then
				nearLoot = index
				nearLock = opensAt
				if opensAt and tView < opensAt then
					interactBtn.Text = "LOCKED " .. Ui.clock(opensAt - tView)
					interactBtn.BackgroundColor3 = Palette.steel
				else
					interactBtn.Text = "GRAB " .. Ui.money(value)
					interactBtn.BackgroundColor3 = Palette.gold
				end
			end
		end
		interactBtn.Visible = nearLoot ~= nil
		ffPill.Visible = folder ~= nil and folder:GetAttribute("CanFF") == true and not myEnded
	end

	-- Fast-forward pill: hold to skip.
	ffPill.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			actions.fastForward(true)
		end
	end)
	ffPill.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			actions.fastForward(false)
		end
	end)

	---------------------------------------------------------------------------
	-- Keys and gamepad (one verb per button)
	---------------------------------------------------------------------------
	ContextActionService:BindAction("HeistEndRun", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and gui.Enabled then
			if state.phase == "Between" then
				Sound.play("UIConfirm")
				hud.ready()
			elseif endBtn.Visible and runHud.Visible and os.clock() - lastGrabTap >= H.END_RUN_GRAB_GUARD then
				Ui.pop(endBtn)
				actions.endRun()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("HeistInteract", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and gui.Enabled and runHud.Visible then
			hud.interact()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("HeistDeck", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			hud.toggleDeck()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	ContextActionService:BindAction("HeistFastForward", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			actions.fastForward(true)
		elseif inputState == Enum.UserInputState.End then
			actions.fastForward(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonB)

	function hud.setLiveCount(n: number)
		state.liveCount = n
	end

	function hud.hideAll()
		runHud.Visible = false
		deckPanel.Visible = false
		results.Visible = false
		readyWait.Visible = false
		alarmPill.Visible = false
		pauseChip.Visible = false
		menuSheet.Visible = false
		setHidden(false)
		setSpectate("")
		clearHints()
		shown, countFrom, countTo, counting = 0, 0, 0, false
	end

	-- The end-of-heist cut hides the whole HUD (HUD, chat and nameplates hidden, §6.6).
	function hud.setCutscene(on: boolean)
		gui.Enabled = not on
		if on then
			clearHints()
			menuSheet.Visible = false
			setHidden(false)
		end
	end

	return hud
end

return Hud
