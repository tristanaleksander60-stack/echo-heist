--!strict
-- Hud/SettingsPanel: settings and comfort (PLAN_STEAM_PLUS §4.3 U7; POLISH §4.2 "Comfort"). Opens from
-- MENU in a heist and from the garage. One big button per setting on a 4 x 3 grid (every cell is a
-- TAP_MIN-tall target): Music and SFX volume (drag the cell, or tap it with a gamepad to step), camera
-- shake, reduced motion, captions, colour-blind shapes, the camera (FIRST PERSON / DIORAMA / CLASSIC; a tap
-- steps to the next, Heist/CameraDirector saves it), the first-person field of view (60-90, a slider), and
-- "Show guard path" (Gus's boot prints). Values live in Heist/Settings (saved through Data.SetSetting);
-- HeistClient applies them. Rows: Config.Ui.SETTINGS_ROWS.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Heist = script.Parent.Parent
local Settings = require(Heist:WaitForChild("Settings"))
local Sound = require(Heist:WaitForChild("Sound"))
local Theme = require(Heist:WaitForChild("Theme"))
local Ui = require(Heist:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local U = Config.Ui
local TAP = Ui.TAP
local COLS, CELL_GAP = U.SETTINGS_COLUMNS, 6
local GAMEPAD_STEP = 0.25 -- a gamepad tap on a slider steps by this (wrapping to 0)

local SettingsPanel = {}

function SettingsPanel.build(ctx: any): any
	local hud = ctx.hud
	local actions = ctx.actions
	local root = ctx.root
	local panelUi = {}

	local box = HudLayout.SETTINGS
	local panel = Ui.panel(root, { Name = "SettingsPanel", Visible = false, ZIndex = 40 })
	Common.place(panel, box)
	panelUi.panel = panel
	Common.sheetBlocksTouch("settings", panel)
	Ui.label(panel, {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(300, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = U.TYPE_SCALE[3],
		Text = Strings.SETTINGS_TITLE,
		ZIndex = 41,
	})
	local fromMenu = false
	-- DONE (or Backspace / B: Hud/Controls "HeistBack") closes it, back to the MENU sheet when it came from there.
	function panelUi.close()
		Ui.hide(panel)
		if fromMenu and hud.openMenu then
			hud.openMenu()
		end
	end
	local doneBtn = Ui.button(panel, {
		Name = "Done",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(150, TAP),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 20,
		Text = Strings.DONE,
		ZIndex = 41,
	}, function()
		panelUi.close()
	end, "UIBack")
	Ui.iconWord(doneBtn, "check", "left", U.ICON_SMALL)
	Common.keyCap(doneBtn, "back")

	local gridTop = TAP + 12
	local cellW = math.floor((box.w - 24 - (COLS - 1) * CELL_GAP) / COLS)
	local function cellPos(k: number): UDim2
		local col = (k - 1) % COLS
		local row = (k - 1) // COLS
		return UDim2.fromOffset(12 + col * (cellW + CELL_GAP), gridTop + row * (TAP + CELL_GAP))
	end

	local refreshers: { () -> () } = {}

	-- A cell: a raised button with the setting's name (left) and its state (right or under it).
	local function cell(k: number, key: string, onTap: () -> ()): (TextButton, TextLabel)
		local b = Ui.button(panel, {
			Name = key,
			Position = cellPos(k),
			Size = UDim2.fromOffset(cellW, TAP),
			BackgroundColor3 = Palette.inkHi,
			TextColor3 = Palette.white,
			Text = "",
			ZIndex = 41,
		}, onTap, "UIToggle")
		Ui.label(b, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = U.TYPE_SCALE[1],
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = Strings.SETTING_LABEL[key] or key,
			ZIndex = 42,
			Active = false,
		})
		local value = Ui.label(b, {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -12),
			Size = UDim2.fromOffset(cellW - 20, 26),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = U.TYPE_SCALE[2],
			Text = "",
			ZIndex = 42,
			Active = false,
		})
		return b, value
	end

	local function toggleCell(k: number, key: string)
		local value: TextLabel
		local function refresh()
			local on = Settings.get(key) == true
			value.Text = if on then Strings.ON else Strings.OFF
			value.TextColor3 = if on then Palette.ok else Palette.steelHi
		end
		value = select(
			2,
			cell(k, key, function()
				Settings.set(key, not (Settings.get(key) == true))
				refresh()
			end)
		)
		refresh()
		table.insert(refreshers, refresh)
	end

	local function cameraCell(k: number)
		local value: TextLabel
		local function refresh()
			local mode = if actions.cameraMode then actions.cameraMode() else "fp"
			value.Text = Strings.SETTING_CAMERA[mode] or Strings.SETTING_CAMERA.fp
			value.TextColor3 = Palette.CLONE_HUES[1]
		end
		value = select(
			2,
			cell(k, "cameraMode", function()
				if actions.toggleCamera then
					actions.toggleCamera()
				end
				refresh()
			end)
		)
		refresh()
		if actions.onCameraMode then
			actions.onCameraMode(function()
				refresh()
			end)
		end
		table.insert(refreshers, refresh)
	end

	-- A slider (volumes 0..1 as a percent; the FOV in degrees): the track along the cell's bottom; drag
	-- anywhere on the cell. It shows (and sounds) while dragging and saves when released. The range is the
	-- key's Config.Data.SETTING_NUMBERS entry; `step` (a share of the range) and the shown text by row.
	local function sliderCell(k: number, key: string, row: any)
		local value: TextLabel
		local b: TextButton
		local fill: Frame
		local range = Config.Data.SETTING_NUMBERS[key] or { 0, 1 }
		local lo, hi = range[1], range[2]
		local span = math.max(hi - lo, 1e-6)
		local fallback = (Config.Data.SETTING_NUMBER_DEFAULTS or {})[key] or hi
		local function current(): number
			return tonumber(Settings.get(key)) or fallback
		end
		local function show(v: number)
			value.Text = if row.text == "degrees" then Strings.fovValue(v) else Strings.percent(v)
			value.TextColor3 = Palette.white
			fill.Size = UDim2.fromScale(math.clamp((v - lo) / span, 0, 1), 1)
		end
		local function snap(v: number): number
			local step = (row.step or U.SLIDER_STEP) * span
			return math.clamp(lo + math.floor((v - lo) / step + 0.5) * step, lo, hi)
		end
		local dragging = false
		local function fromX(x: number): number
			local w = math.max(1, b.AbsoluteSize.X - 24)
			return snap(lo + (x - b.AbsolutePosition.X - 12) / w * span)
		end
		b, value = cell(k, key, function()
			if Common.usingGamepad() then
				local v = current() + GAMEPAD_STEP * span
				Settings.set(key, if v > hi + 1e-6 then lo else snap(v))
				show(current())
			end
		end)
		value.Position = UDim2.new(1, -10, 0, 6)
		value.AnchorPoint = Vector2.new(1, 0)
		local track = Ui.frame(b, {
			Name = "Track",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -14),
			Size = UDim2.new(1, -24, 0, 8),
			BackgroundColor3 = Palette.plumDeep,
			BackgroundTransparency = 0,
			ZIndex = 42,
			Active = false,
		})
		Ui.pill(track)
		fill = Ui.frame(track, {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.CLONE_HUES[1],
			BackgroundTransparency = 0,
			ZIndex = 43,
			Active = false,
		})
		Ui.pill(fill)
		local knob = Ui.frame(fill, {
			Name = "Knob",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = Palette.white,
			BackgroundTransparency = 0,
			ZIndex = 44,
			Active = false,
		})
		Ui.pill(knob)
		Ui.stroke(knob, Palette.ink, Theme.STROKE)
		local function isPointer(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end
		b.InputBegan:Connect(function(input: InputObject)
			if isPointer(input) then
				dragging = true
				local v = fromX(input.Position.X)
				Settings.set(key, v, false)
				show(v)
			end
		end)
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local v = fromX(input.Position.X)
				if v ~= Settings.get(key) then
					Settings.set(key, v, false)
					show(v)
				end
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			if dragging and isPointer(input) then
				dragging = false
				Settings.set(key, current(), true)
				Sound.play("UIToggle")
			end
		end)
		local function refresh()
			show(current())
		end
		refresh()
		table.insert(refreshers, refresh)
	end

	for k, row in U.SETTINGS_ROWS do
		if row.kind == "slider" then
			sliderCell(k, row.key, row)
		elseif row.kind == "camera" then
			cameraCell(k)
		else
			toggleCell(k, row.key)
		end
	end
	Settings.onChanged(function()
		if panel.Visible then
			for _, fn in refreshers do
				fn()
			end
		end
	end)

	-- Opens the panel (fromMenu: DONE goes back to the MENU sheet).
	function hud.openSettings(menu: boolean?)
		fromMenu = menu == true
		for _, fn in refreshers do
			fn()
		end
		if ctx.msg and ctx.msg.menuSheet then
			Ui.hide(ctx.msg.menuSheet)
		end
		Ui.show(panel)
		Common.selectFor(doneBtn)
	end

	function hud.closeSettings()
		Ui.hide(panel)
	end

	return panelUi
end

return SettingsPanel
