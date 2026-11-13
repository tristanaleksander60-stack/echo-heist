--!strict
-- Hud/CrewView: the HUD half of the Crew View peek (REVIEW_STEAM_PLUS gap 5; the camera half is Heist/CameraDirector,
-- the maths Shared/Heist/CrewView, numbers Config.Heist.CAMERA.CREW).
--   * the CREW button (hold; HudLayout.CREW, above Interact, left of REWIND): shown in a first-person run whenever
--     Crew View may start; on a keyboard or a gamepad it is the hint, with its key cap (Q / LB: Hud/Common.keyCap); on
--     the narrowest notched phones it steps aside while the prompt chip is up (HudLayout.crewYields);
--   * while held: a subtle edge vignette (four gradient bands on the fx layer) and "CREW VIEW" under the clone strip
--     (HudLayout.CREW_LABEL); the clone pills and the run bar stay; the reticle and its chip hide (Hud/Run);
--   * reduced motion: the camera cuts and a quick dim veil crossfades over the cut (CrewView.veil);
--   * the one-time hint: the first first-person run with 2+ clones, "Hold Q to see your crew." for this device
--     (Strings.forDevice, Heist/FirstTime "crewView"; using it first counts as seen).
-- Keys (Q / LB) are bound in Hud/Controls. Everything goes through ctx.actions (crewHold, crewState, crewAllowed,
-- cameraMode), so the HUD never touches the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local CrewViewMath = require(HeistShared:WaitForChild("CrewView"))
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local FirstTime = require(script.Parent.Parent:WaitForChild("FirstTime"))
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local CR = Config.Heist.CAMERA.CREW
local U = Config.Ui
local KIND = "crewView" -- Heist/FirstTime kind (per session: no profile field)

local CrewView = {}

-- One edge band of the vignette: dark at the screen edge, clear inward (UIGradient on a black frame).
local function band(parent: Instance, name: string, anchor: Vector2, pos: UDim2, size: UDim2, rot: number): Frame
	local f = Ui.frame(parent, {
		Name = name,
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AnchorPoint = anchor,
		Position = pos,
		Size = size,
		Active = false,
	})
	local g = Instance.new("UIGradient")
	g.Rotation = rot
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.55, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return f
end

function CrewView.build(ctx: any): any
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local runHud = ctx.runHud
	local fx: ScreenGui = ctx.fxGui
	local crew = {}

	local function hold(who: string, on: boolean)
		if actions.crewHold then
			actions.crewHold(who, on)
		end
	end

	-- The touch button: hold to peek.
	local btn = Ui.button(runHud, {
		Name = "Crew",
		BackgroundColor3 = Palette.steelHi,
		TextSize = Theme.TYPE.caption,
		TextWrapped = true,
		Text = Strings.CREW,
		Visible = false,
	}, function() end, "")
	Common.place(btn, HudLayout.CREW)
	Ui.iconWord(btn, "clone", "top", U.ICON_SMALL)
	Common.keyCap(btn, "crew")
	btn.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			hold("touch", true)
		end
	end)
	btn.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
			hold("touch", false)
		end
	end)
	crew.button = btn

	-- "CREW VIEW" under the clone strip while held.
	local label = Ui.label(runHud, {
		Name = "CrewViewLabel",
		Text = Strings.CREW_VIEW,
		TextSize = Theme.TYPE.body,
		TextTransparency = 1,
		Visible = false,
	})
	Common.place(label, HudLayout.CREW_LABEL)
	Ui.fit(label, Theme.TYPE.body, Config.Heist.UI_TEXT_MIN)
	local labelStroke = label:FindFirstChildOfClass("UIStroke")

	-- The vignette: four edge bands on the edge-to-edge fx layer, under every other fx frame.
	local vig = Ui.frame(fx, {
		Name = "CrewVignette",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
		Active = false,
	})
	local depth = CR.VIGNETTE_DEPTH
	local bands = {
		band(vig, "Top", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, depth * 1.6), 90),
		band(vig, "Bottom", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, depth * 1.6), -90),
		band(vig, "Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(depth, 1), 0),
		band(vig, "Right", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(depth, 1), 180),
	}
	-- Reduced motion's crossfade veil.
	local veil = Ui.frame(fx, {
		Name = "CrewVeil",
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 1,
		Active = false,
	})

	local shownW = -1
	local used = false
	local function render(w: number, v: number)
		if math.abs(w - shownW) > 1e-3 then
			shownW = w
			local on = w > 0
			vig.Visible = on
			-- the bands' own gradients shape the edge; the group fades with the weight
			for _, f in bands do
				f.BackgroundTransparency = 1 - CR.VIGNETTE * w
			end
			label.Visible = w > 0.05
			label.TextTransparency = 1 - math.clamp((w - 0.3) / 0.7, 0, 1)
			if labelStroke then
				labelStroke.Transparency = label.TextTransparency
			end
		end
		veil.Visible = v > 0
		veil.BackgroundTransparency = 1 - v
	end

	-- The one-time hint, scheduled at a run's start.
	local hintToken = 0
	function crew.onRun(m: any)
		hintToken += 1
		local token = hintToken
		local clones = 0
		for _, a in m.actors or {} do
			if a.kind == "clone" then
				clones += 1
			end
		end
		local mode = if actions.cameraMode then actions.cameraMode() else nil
		if not CrewViewMath.hintDue(clones, mode, FirstTime.seen(KIND), CR) then
			return
		end
		local wait = (tonumber(m.transition) or 0) + CR.HINT_DELAY
		task.delay(wait, function()
			if token ~= hintToken or state.phase ~= "Run" or state.where ~= "heist" then
				return
			end
			if actions.cameraMode and actions.cameraMode() ~= "fp" then
				return
			end
			if FirstTime.firstTime(KIND) then
				hud.toast(Strings.forDevice("CREW_VIEW_HINT", Common.device(), true))
			end
		end)
	end

	-- Every frame (own RenderStepped: the vignette must clear even when the run HUD stops updating).
	local function update()
		local w, v, active = 0, 0, false
		if actions.crewState then
			w, v, active = actions.crewState()
		end
		if active and not used then
			used = true
			FirstTime.markSeen(KIND) -- found it alone: no hint
		end
		render(w, v)
		-- the button: a first-person run, whenever Crew View may start (or is held); keys and pads see it as the hint
		local can = runHud.Visible and (active or (actions.crewAllowed ~= nil and actions.crewAllowed()))
		if can and not active and ctx.reticle and ctx.reticle.promptUp() then
			local cam = workspace.CurrentCamera
			local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
			local inset = ctx.gui.AbsolutePosition
			local size = ctx.gui.AbsoluteSize
			local right = math.max(0, vp.X - inset.X - size.X)
			local bottom = math.max(0, vp.Y - inset.Y - size.Y)
			if HudLayout.crewYields(vp.X, vp.Y, inset.X, inset.Y, right, bottom) then
				can = false -- the prompt chip is up: you are looking at something to use
			end
		end
		if btn.Visible ~= can then
			btn.Visible = can
			if not can then
				hold("touch", false)
			end
		end
		btn.BackgroundColor3 = if active then Palette.gold else Palette.steelHi
	end
	RunService.RenderStepped:Connect(update)

	return crew
end

return CrewView
