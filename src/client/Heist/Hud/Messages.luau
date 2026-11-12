--!strict
-- Hud/Messages: everything that tells the player something without being a control:
-- the one bottom message rail (toast above the sound caption above the spectate line,
-- fixed slots, nothing overlaps), the MENU sheet, the HIDDEN pill and edge dim,
-- the "preparing" card, the red vignette and the diamond dim.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local FlashLimit = require(script.Parent.Parent:WaitForChild("FlashLimit"))
local Loading = require(script.Parent.Parent:WaitForChild("Loading"))
local Motion = require(script.Parent.Parent:WaitForChild("Motion"))
local Sound = require(script.Parent.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local H = Config.Heist
local U = Config.Ui
local TAP = Ui.TAP

local Messages = {}

function Messages.build(ctx: any): any
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local root = ctx.root
	local fxGui = ctx.fxGui
	local runHud = ctx.runHud
	local msg = {}

	local vignette = Ui.frame(fxGui, {
		Name = "Vignette",
		BackgroundColor3 = Palette.alarm,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
	})
	msg.vignette = vignette

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
	-- Message rail: above Interact during a run, above the Clone Deck between runs
	---------------------------------------------------------------------------
	local slots = HudLayout.RAIL_SLOTS
	local railW = HudLayout.RAIL.w
	local rail = Ui.frame(root, {
		Name = "MessageRail",
		BackgroundTransparency = 1,
		ZIndex = 20,
	})
	Common.place(rail, HudLayout.RAIL)
	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = Enum.FillDirection.Vertical
	railLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	railLayout.SortOrder = Enum.SortOrder.LayoutOrder
	railLayout.Padding = UDim.new(0, slots.pad)
	railLayout.Parent = rail
	-- Two lines, so a longer toast wraps instead of running under other boxes.
	local toastLabel = Ui.label(rail, {
		Name = "Toast",
		Size = UDim2.fromOffset(railW, slots.toast),
		TextSize = 18,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Text = "",
		Visible = false,
		LayoutOrder = 1,
		ZIndex = 20,
	})
	-- Sound captions (on by default, §7.4): "[Alarm!]".
	local captionLabel = Ui.label(rail, {
		Name = "Caption",
		Size = UDim2.fromOffset(math.min(300, railW), slots.caption),
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
		Size = UDim2.fromOffset(railW, slots.spectate),
		Text = "",
		Visible = false,
		LayoutOrder = 3,
		ZIndex = 20,
	})
	Ui.fit(spectate, 20, H.UI_TEXT_MIN)
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

	-- Why your run ended (caught, zapped, time's up; §6.1 item 8). It stays on the rail
	-- through the run's end until the deck opens (the deck title then leads with it), or
	-- until the next run when there is no deck. `covers` is the sound caption it already
	-- says, so that caption does not show twice.
	msg.reason = ""
	local reasonCovers = ""
	local captionToken = 0
	function hud.caption(text: string)
		-- the spectate line already says it
		if spectate.Visible and string.find(spectate.Text, text, 1, true) then
			return
		end
		if msg.reason ~= "" and text == reasonCovers then
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
	-- A passing spectate line ("Wait for your crew"); "" clears it and the reason.
	function msg.setSpectate(text: string)
		if text == "" then
			msg.reason = ""
			reasonCovers = ""
		end
		setRailText(spectate, text)
	end
	function msg.setReason(text: string, covers: string?)
		msg.reason = text
		reasonCovers = covers or ""
		setRailText(spectate, text)
		if covers and captionLabel.Text == covers then
			setRailText(captionLabel, "")
		end
	end
	-- The run ended: passing lines go, the reason stays.
	function msg.keepReason()
		setRailText(spectate, msg.reason)
	end
	-- The deck opened and its title carries the reason: off the rail, still remembered.
	function msg.reasonToDeck()
		setRailText(spectate, "")
	end

	function hud.placeRail(overDeck: boolean)
		rail.Position = Common.position(if overDeck then HudLayout.RAIL_DECK else HudLayout.RAIL)
	end

	---------------------------------------------------------------------------
	-- MENU: leave the heist mid-run or between runs (solo: the heist ends; co-op: you
	-- leave your crew's heist). The run keeps going behind the sheet: it is a loop.
	---------------------------------------------------------------------------
	local pauseChip = Ui.button(root, {
		Name = "Menu",
		BackgroundColor3 = Palette.inkHi,
		TextColor3 = Palette.white,
		TextSize = 20,
		Text = Strings.MENU,
		Visible = false,
	}, function()
		hud.openMenu()
	end, "UIToggle")
	Common.place(pauseChip, HudLayout.MENU)
	Ui.iconWord(pauseChip, "menu", "top", U.ICON_SMALL)
	msg.pauseChip = pauseChip
	local menuSheet = Ui.panel(root, { Name = "MenuSheet", Visible = false, ZIndex = 30 })
	Common.place(menuSheet, HudLayout.MENU_SHEET)
	msg.menuSheet = menuSheet
	Common.sheetBlocksTouch("menu", menuSheet)
	-- SETTINGS (U7, Hud/SettingsPanel): volume, comfort and the camera A/B (DIORAMA / CLASSIC, decision
	-- D5) that used to be its own button here. DONE comes back to this sheet.
	local settingsBtn = Ui.button(menuSheet, {
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(300, TAP),
		TextSize = 20,
		Text = Strings.SETTINGS,
		ZIndex = 32,
	}, function()
		if hud.openSettings then
			hud.openSettings(true)
		end
	end, "UIToggle")
	Ui.iconWord(settingsBtn, "settings", "left", U.ICON_SMALL)
	Ui.label(menuSheet, {
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 26,
		Text = Strings.MENU_TITLE,
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
		Text = Strings.KEEP_PLAYING,
		LayoutOrder = 1,
		ZIndex = 32,
	}, function()
		Ui.hide(menuSheet)
	end, "UIBack")
	Ui.button(menuButtons, {
		Size = UDim2.fromOffset(180, TAP),
		TextSize = 20,
		Text = Strings.BACK_TO_GARAGE,
		LayoutOrder = 2,
		ZIndex = 32,
	}, function()
		Ui.hide(menuSheet)
		actions.leave()
	end, "UIConfirm")
	function hud.openMenu()
		Ui.show(menuSheet)
		Common.selectFor(keepBtn)
	end

	---------------------------------------------------------------------------
	-- HIDDEN (L4's main verb): a pill with the word while your own actor hides,
	-- the screen edges dimmed a little (hud.onEvent Hidden / Unhidden).
	---------------------------------------------------------------------------
	local hiddenPill = Ui.panel(runHud, {
		Name = "Hidden",
		BackgroundColor3 = Palette.ink,
		Visible = false,
	}, Palette.steelHi)
	Common.place(hiddenPill, HudLayout.HIDDEN)
	msg.hiddenPill = hiddenPill
	local hiddenLabel = Ui.label(hiddenPill, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		TextColor3 = Palette.steelHi,
		Text = Strings.HIDDEN,
	})
	Ui.iconWord(hiddenLabel, "hidden", "left", U.ICON_SMALL)
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
	function msg.setHidden(on: boolean)
		Ui.setShown(hiddenPill, on)
		hiddenEdge.Visible = on
	end

	---------------------------------------------------------------------------
	-- A new account's first seconds (§7.5: they spawn at the open van door, never in a menu). The
	-- loading card (Heist/Loading) or the title beat covers the server's wait; this is the fallback
	-- when neither is up: the card's turning reel and its hint, never a silent text card.
	---------------------------------------------------------------------------
	local preparing = Ui.panel(root, {
		Name = "Preparing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 120),
		Visible = false,
	})
	local reel = Loading.reel(preparing, 40)
	reel.Position = UDim2.fromScale(0.5, 0.36)
	Ui.label(preparing, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.new(1, -24, 0, 28),
		TextSize = 20,
		TextColor3 = Palette.steelHi,
		Text = Strings.LOADING_HINTS.server,
	})
	msg.preparing = preparing
	function hud.showPreparing()
		Ui.show(preparing)
	end
	function hud.hidePreparing()
		Ui.hide(preparing)
	end

	---------------------------------------------------------------------------
	-- Screen flashes
	---------------------------------------------------------------------------
	-- Both red vignettes are full-screen flashes: they ask the client-wide limiter (Heist/FlashLimit, <= 3 a
	-- second with the rewind and slam flashes); a refused one does not play (its sound and words still do).
	function hud.flashRed()
		if state.reduced or not FlashLimit.allow() then
			return
		end
		vignette.BackgroundTransparency = 0.7
		Motion.timed(vignette, U.FLASH_RED_SECONDS, { BackgroundTransparency = 1 })
	end

	-- The alarm's red pulse (once per ALARM_PULSE_SECONDS, ≤ 3 flashes/s).
	function msg.alarmPulse()
		if not FlashLimit.allow() then
			return
		end
		vignette.BackgroundTransparency = 0.82
		Motion.timed(vignette, H.ALARM_PULSE_SECONDS * 0.6, { BackgroundTransparency = 1 })
	end

	function msg.diamondMoment()
		Sound.play("DiamondShimmer")
		placeDim()
		dim.Enabled = true
		dim.Brightness = -H.DIAMOND_DIM
		local tw = Motion.timed(dim, H.DIAMOND_DIM_SECONDS, { Brightness = 0 })
		tw.Completed:Once(function()
			dim.Enabled = false
		end)
	end

	return msg
end

return Messages
