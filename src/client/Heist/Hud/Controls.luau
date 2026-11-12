--!strict
-- Hud/Controls: the run's buttons and keys (MASTERPLAN §3.4, one verb per button):
-- END RUN on the right edge with its 1.5 s lock ring, the contextual Interact (GRAB) lower
-- right, the hold-to-skip fast-forward pill, and the keyboard / gamepad bindings
-- (R / ButtonY END RUN or RUN n, E / ButtonX Interact, Q / ButtonL1 Clone Deck,
-- hold F / ButtonB fast-forward).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Sound = require(script.Parent.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local H = Config.Heist

local Controls = {}

function Controls.build(ctx: any): any
	local hud = ctx.hud
	local actions = ctx.actions
	local runHud = ctx.runHud
	local controls = {}

	local ffPill = Ui.button(runHud, {
		Name = "FastForward",
		Text = Strings.FAST_FORWARD,
		BackgroundColor3 = Palette.exit,
		Visible = false,
	}, function() end, "")
	Common.place(ffPill, HudLayout.FAST_FORWARD)
	controls.ffPill = ffPill

	local endBtn = Ui.button(runHud, {
		Name = "EndRun",
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 18,
		TextWrapped = true,
		Text = Strings.END_RUN,
	}, function()
		if os.clock() - ctx.lastGrabTap < H.END_RUN_GRAB_GUARD then
			return -- a thumb that slid off GRAB
		end
		actions.endRun()
	end, "")
	Common.place(endBtn, HudLayout.END_RUN)
	controls.endBtn = endBtn
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
	controls.lockRing = lockRing

	-- Interact sits where touch players expect a contextual action: lower right, left of
	-- the jump button, well away from END RUN (a thumb slipping off GRAB must not end the
	-- run; END RUN also ignores taps within END_RUN_GRAB_GUARD of a GRAB).
	local interactBtn = Ui.button(runHud, {
		Name = "Interact",
		BackgroundColor3 = Palette.gold,
		TextSize = 20,
		TextWrapped = true,
		Text = Strings.GRAB,
		Visible = false,
	}, function()
		hud.interact()
	end, "")
	Common.place(interactBtn, HudLayout.INTERACT)
	controls.interactBtn = interactBtn

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

	return controls
end

-- Keys and gamepad (one verb per button). Called once every HUD part exists.
function Controls.bind(ctx: any)
	local hud = ctx.hud
	local actions = ctx.actions
	local state = ctx.state
	local gui = ctx.gui
	local runHud = ctx.runHud
	local endBtn = ctx.controls.endBtn
	ContextActionService:BindAction("HeistEndRun", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and gui.Enabled then
			if state.phase == "Between" then
				Sound.play("UIConfirm")
				hud.ready()
			elseif endBtn.Visible and runHud.Visible and os.clock() - ctx.lastGrabTap >= H.END_RUN_GRAB_GUARD then
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
end

return Controls
