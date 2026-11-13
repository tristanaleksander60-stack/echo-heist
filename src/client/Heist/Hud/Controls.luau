--!strict
-- Hud/Controls: the run's buttons and keys (MASTERPLAN §3.4, one verb per button):
-- REWIND on the right edge (it ends your run; the remote stays Heist.EndRun) with its
-- 1.5 s lock ring, the contextual Interact (GRAB) lower right, the hold-to-skip FAST
-- pill, and the keyboard / gamepad bindings (R / ButtonY REWIND or the next run,
-- E / ButtonX Interact, Q / ButtonL1 Clone Deck between runs and, in a first-person run, hold Q / ButtonL1 for
-- Crew View (Hud/CrewView has its touch button), hold F / ButtonR1 fast-forward (B is the slide's: Heist/Slide), M the
-- MENU sheet, Backspace / ButtonB closes the settings or the MENU sheet). Every binding comes from Shared/Heist/
-- KeyHints, and every button here wears its key cap (Hud/Common.keyCap; none on touch).
-- First person: a left click with the cursor locked also interacts (with what you look at:
-- Heist/LookTarget), and the Interact button is the touch fallback, labelled for the looked-at
-- target (GRAB $100, OPEN).

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

-- Key binds only on a client: a server builds the HUD for the engine check (tests/client_engine.luau) and binds nothing.
local CAS: any = if game:GetService("RunService"):IsClient()
	then ContextActionService
	else {
		BindAction = function() end,
		UnbindAction = function() end,
		BindActionAtPriority = function() end,
	}

-- The Enum.KeyCodes bound to a KeyHints action, as arguments.
local function codes(action: string): ...Enum.KeyCode
	return table.unpack(Common.keyCodes(action))
end

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
	Common.keyCap(ffPill, "fast")
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
	Common.keyCap(endBtn, "rewind", "tl")

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
	Common.keyCap(interactBtn, "use")

	-- Fast-forward pill: hold to skip (held, it is also the touch fast slide's modifier: Hud/Slide).
	ffPill.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			ctx.ffHeld = true
			actions.fastForward(true)
		end
	end)
	ffPill.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			ctx.ffHeld = false
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
	-- The run's own keys (REWIND / next run, USE, CREW, DECK, FAST) are bound only while a heist is on
	-- (controls.setRunBinds: HeistClient turns them on with a heist's Sync, Hud.hideHeist turns them off). MENU and
	-- BACK stay bound everywhere (the garage's sheets use them).
	local runBinds: { { any } } = {}
	local runBound = false
	local function bindRun(name: string, fn: any, touch: boolean, ...: Enum.KeyCode)
		table.insert(runBinds, { name, fn, touch, table.pack(...) })
	end
	function ctx.controls.setRunBinds(on: boolean)
		if on == runBound then
			return
		end
		runBound = on
		for _, b in runBinds do
			if on then
				local keys = b[4]
				CAS:BindAction(b[1], b[2], b[3], table.unpack(keys, 1, keys.n))
			else
				CAS:UnbindAction(b[1])
			end
		end
	end
	function ctx.controls.runBindsOn(): boolean
		return runBound
	end
	bindRun("HeistEndRun", function(_, inputState)
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
	end, false, codes("rewind"))
	bindRun("HeistInteract", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and gui.Enabled and runHud.Visible then
			hud.interact()
		end
		return Enum.ContextActionResult.Pass
	end, false, codes("use"))
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
	-- M: the MENU sheet (in first person the cursor is locked during play; a sheet frees it, and so does
	-- holding Left Alt).
	CAS:BindAction("HeistMenu", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and gui.Enabled and ctx.msg and ctx.msg.menuSheet then
			local sheet = ctx.msg.menuSheet
			if Ui.isShown(sheet) then
				Ui.hide(sheet)
			elseif state.where == "heist" and hud.openMenu then
				hud.openMenu()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, codes("menu"))
	-- Crew View: held in a first-person run (CameraDirector ignores it anywhere else; between runs Q is the deck's).
	bindRun("HeistCrewView", function(_, inputState, input)
		if actions.crewHold then
			local who = if input.UserInputType == Enum.UserInputType.Keyboard then "key" else "pad"
			if inputState == Enum.UserInputState.Begin then
				actions.crewHold(who, gui.Enabled and state.phase == "Run")
			elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
				actions.crewHold(who, false)
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, codes("crew"))
	bindRun("HeistDeck", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			hud.toggleDeck()
		end
		return Enum.ContextActionResult.Pass
	end, false, codes("deck"))
	bindRun("HeistFastForward", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			actions.fastForward(true)
		elseif inputState == Enum.UserInputState.End then
			actions.fastForward(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, codes("fast"))
	-- BACK closes the top sheet: the settings, else the MENU sheet (bound above the slide, which also uses B).
	CAS:BindActionAtPriority("HeistBack", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or not gui.Enabled then
			return Enum.ContextActionResult.Pass
		end
		local settings = ctx.settings and ctx.settings.panel
		if settings and Ui.isShown(settings) and ctx.settings.close then
			ctx.settings.close()
			return Enum.ContextActionResult.Sink
		end
		local sheet = ctx.msg and ctx.msg.menuSheet
		if sheet and Ui.isShown(sheet) then
			Ui.hide(sheet)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, codes("back"))
end

return Controls
