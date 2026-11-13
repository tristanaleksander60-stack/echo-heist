--!strict
-- Hud/Controls: the run's buttons and keys (MASTERPLAN §3.4, one verb per button):
-- REWIND on the right edge (it ends your run; the remote stays Heist.EndRun) with its
-- 1.5 s lock ring, the contextual Interact (GRAB) lower right, the hold-to-skip FAST
-- pill, and the keyboard / gamepad bindings (R / ButtonY REWIND or the next run,
-- E / ButtonX Interact, Q / ButtonL1 Clone Deck, hold F / ButtonB fast-forward). First person: a left
-- click with the cursor locked also interacts (with what you look at: Heist/LookTarget), and the Interact
-- button is the touch fallback, labelled for the looked-at target (GRAB $100, OPEN).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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
local U = Config.Ui

local Controls = {}

function Controls.build(ctx: any): any
	local hud = ctx.hud
	local actions = ctx.actions
	local runHud = ctx.runHud
	local controls = {}

	local ffPill = Ui.button(runHud, {
		Name = "FastForward",
		TextSize = 16,
		TextWrapped = true,
		Text = Strings.FAST_FORWARD,
		BackgroundColor3 = Palette.exit,
		Visible = false,
	}, function() end, "")
	Common.place(ffPill, HudLayout.FAST_FORWARD)
	Ui.iconWord(ffPill, "fast_forward", "top", U.ICON_SMALL)
	controls.ffPill = ffPill

	local endBtn = Ui.button(runHud, {
		Name = "EndRun",
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 16,
		TextWrapped = true,
		Text = Strings.REWIND,
	}, function()
		if os.clock() - ctx.lastGrabTap < H.END_RUN_GRAB_GUARD then
			return -- a thumb that slid off GRAB
		end
		actions.endRun()
	end, "")
	Common.place(endBtn, HudLayout.END_RUN)
	controls.endBtn = endBtn
	-- REWIND keeps its word under the ◀◀ icon (U2); the ring lock is a circle of dots around it
	-- that go out over the 1.5 s lock (Run.update).
	controls.endIcon = Ui.iconWord(endBtn, "rewind", "top", U.ICON_SIZE + 8)
	controls.lock = Ui.lockRing(endBtn, HudLayout.END_RUN.h - 8, Palette.ink)

	-- Interact sits where touch players expect a contextual action: lower right, left of
	-- the jump button, well away from REWIND (a thumb slipping off GRAB must not end the
	-- run; REWIND also ignores taps within END_RUN_GRAB_GUARD of a GRAB).
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
	controls.interactIcon = Ui.iconWord(interactBtn, "coin", "left", U.ICON_SIZE)

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
	-- First person with the cursor locked: a left click uses what you look at (a click on a GUI is the GUI's).
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if
			not processed
			and input.UserInputType == Enum.UserInputType.MouseButton1
			and gui.Enabled
			and runHud.Visible
			and actions.cursorLocked
			and actions.cursorLocked()
		then
			hud.interact()
		end
	end)
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
