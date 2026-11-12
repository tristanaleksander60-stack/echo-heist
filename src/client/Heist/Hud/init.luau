--!strict
-- Heist/Hud: HUD v1 for the sim path (MASTERPLAN §7.4, §3.4 controls, §7.5 L1 FTUE).
-- This is the facade HeistClient uses (Hud.new(state, actions) -> hud with onRun,
-- onRunEnd, onEvent, onDeck, showBetween, onOver, showGarage, update, toast, caption...);
-- the parts live in the child modules:
--   TopBar    "RUN 3" + timer + run bar with event markers, the loot meter with its
--             count-up, the clone strip, the Alarm Run counter, the objective line
--   Controls  END RUN (lock ring, co-op count), Interact (GRAB / LOCKED 0:07), the
--             fast-forward pill, keys and gamepad
--   Messages  the bottom message rail (toast, sound caption, spectate line), the menu
--             sheet, the HIDDEN pill, the "preparing" card, the red vignette, diamond dim
--   Deck      the Clone Deck between runs, the RUN button and its auto-start countdown
--   Results   the results card
--   Garage    tapes, daily vault, advent catch-up, crew, join friend
--   Hints     the objective line's text, the L1 FTUE lines and the L1 stuck hints
--   Run       run state, events and the per-frame update
--   Common    shared helpers
-- Every player-facing string is in Shared/Heist/Strings and every run-HUD box in
-- Shared/Heist/HudLayout (checked by tests/hud_layout.luau at 7 viewports).
-- Mobile first: every button is at least Config.Heist.TAP_MIN design px (>= 64 px on
-- screen), the HUD scales to the safe area, colour is never the only signal (glyph +
-- number), reduced motion drops the pulses.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heist"):WaitForChild("HudLayout"))

local Ui = require(script.Parent:WaitForChild("Ui"))
local Controls = require(script:WaitForChild("Controls"))
local Deck = require(script:WaitForChild("Deck"))
local Garage = require(script:WaitForChild("Garage"))
local Hints = require(script:WaitForChild("Hints"))
local Messages = require(script:WaitForChild("Messages"))
local Results = require(script:WaitForChild("Results"))
local Run = require(script:WaitForChild("Run"))
local TopBar = require(script:WaitForChild("TopBar"))

local localPlayer = Players.LocalPlayer

local Hud = {}

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
		local s = HudLayout.scale(size.X, size.Y)
		deviceScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

	local runHud =
		Ui.frame(root, { Name = "Run", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })

	-- What the parts share: the guis, the state, the actions and a few run flags.
	local ctx: any = {
		hud = hud,
		state = state,
		actions = actions,
		gui = gui,
		fxGui = fxGui,
		root = root,
		runHud = runHud,
		waiting = false, -- RUN tapped, waiting for the crew
		lastGrabTap = -math.huge, -- os.clock() of the last GRAB tap (END RUN guard)
		stopsLineUntil = 0, -- L1: "Your clone stops where you stop." from the clone's press
		noBankRuns = 0, -- runs in a row without a bank (the level line comes back)
	}
	ctx.top = TopBar.build(ctx)
	ctx.controls = Controls.build(ctx)
	ctx.msg = Messages.build(ctx)
	ctx.deck = Deck.build(ctx)
	ctx.results = Results.build(ctx)
	ctx.garage = Garage.build(ctx)
	ctx.hints = Hints.build(ctx)
	Run.build(ctx)
	Controls.bind(ctx)

	-- Set by HeistClient (RewindDirector): (text, colour, hold seconds?).
	hud.bigStamp = function(_text: string, _color: Color3, _hold: number?) end

	function hud.hideAll()
		runHud.Visible = false
		ctx.deck.panel.Visible = false
		ctx.results.card.Visible = false
		ctx.deck.readyWait.Visible = false
		ctx.top.alarmPill.Visible = false
		ctx.msg.pauseChip.Visible = false
		ctx.msg.menuSheet.Visible = false
		ctx.msg.setHidden(false)
		ctx.msg.setSpectate("")
		ctx.hints.clear()
		ctx.top.resetCount()
	end

	-- The end-of-heist cut hides the whole HUD (HUD, chat and nameplates hidden, §6.6).
	function hud.setCutscene(on: boolean)
		gui.Enabled = not on
		if on then
			ctx.hints.clear()
			ctx.msg.menuSheet.Visible = false
			ctx.msg.setHidden(false)
		end
	end

	return hud
end

return Hud
