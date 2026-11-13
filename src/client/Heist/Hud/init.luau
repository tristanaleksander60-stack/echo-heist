--!strict
-- Heist/Hud: HUD v1 for the sim path (MASTERPLAN §7.4, §3.4 controls, §7.5 L1 FTUE).
-- This is the facade HeistClient uses (Hud.new(state, actions) -> hud with onRun,
-- onRunEnd, onEvent, onDeck, showBetween, onOver, showGarage, update, toast, caption...);
-- the parts live in the child modules:
--   TopBar    "RUN 3" + timer + run bar with event markers, the loot meter with its
--             count-up, the clone strip, the Alarm Run counter, the objective line
--   Controls  REWIND (lock ring, co-op count; the END RUN action), Interact (GRAB /
--             LOCKED 0:07), the hold-to-skip FAST pill, keys and gamepad
--   Messages  the bottom message rail (toast, sound caption, spectate line), the menu
--             sheet, the HIDDEN pill, the "preparing" card, the red vignette, diamond dim
--   Deck      the Clone Deck between runs as crew cards (polaroids of your avatar, last action,
--             full deck and START OVER), the RUN button and its auto-start countdown
--   Results   the job sheet (haul count-up, goal lines, stamps with their reasons, trophy)
--   Garage    the job board, daily vault, advent catch-up, crew, join friend, SETTINGS
--   SettingsPanel  settings and comfort (from MENU and the garage; Heist/Settings holds the values)
--   BankFly   the bank moment's HUD half: "+$100!" flies from the van to the loot meter
--   Hints     the objective line's text, the L1 FTUE lines and the L1 stuck hints, the help
--             after L1 (world-state lines, SHOW ME? and the chalk ghost, TRY RELAXED?), the
--             finger pointer, failure counterplay and the first-time beats
--   Run       run state, events and the per-frame update (and first person's reduced layout)
--   Reticle   first person: the centre reticle and the look-to-interact prompt chip (on the fx layer)
--   CrewView  first person: the hold-to-peek Crew View's touch CREW button, vignette, label and one-time hint
--   Lobby     the hideout's minimal HUD: the reticle's prompt, the touch USE button, the drive's SKIP
--   Wardrobe  the hideout's outfit picker (Data.Equip), opened at the wardrobe station
--   Common    shared helpers
-- Every player-facing string is in Shared/Heist/Strings and every run-HUD box in
-- Shared/Heist/HudLayout (checked by tests/hud_layout.luau at 7 viewports).
-- Mobile first: every button is at least Config.Heist.TAP_MIN design px (>= 64 px on
-- screen), the HUD scales to the safe area, colour is never the only signal (a word or
-- a number with it; no text glyphs as icons, PLAN S4), reduced motion drops the pulses.
-- Roblox's player list is hidden during a heist (it covered the top right, PLAN S8) and
-- shown again in the garage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local HudLayout = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heist"):WaitForChild("HudLayout"))

local Ui = require(script.Parent:WaitForChild("Ui"))
local TypeSpecimen = require(script.Parent:WaitForChild("TypeSpecimen"))
local BankFly = require(script:WaitForChild("BankFly"))
local Controls = require(script:WaitForChild("Controls"))
local CrewView = require(script:WaitForChild("CrewView"))
local Deck = require(script:WaitForChild("Deck"))
local Garage = require(script:WaitForChild("Garage"))
local Hints = require(script:WaitForChild("Hints"))
local Lobby = require(script:WaitForChild("Lobby"))
local Messages = require(script:WaitForChild("Messages"))
local Reticle = require(script:WaitForChild("Reticle"))
local Results = require(script:WaitForChild("Results"))
local Common = require(script:WaitForChild("Common"))
local Run = require(script:WaitForChild("Run"))
local SettingsPanel = require(script:WaitForChild("SettingsPanel"))
local TopBar = require(script:WaitForChild("TopBar"))
local Wardrobe = require(script:WaitForChild("Wardrobe"))

local localPlayer = Players.LocalPlayer

local Hud = {}

export type Actions = {
	endRun: () -> (),
	interact: (kind: number, index: number) -> (),
	deck: (op: string, n: number?) -> (),
	ready: () -> (),
	fastForward: (on: boolean) -> (),
	selectLevel: (index: number, relaxed: boolean?) -> (),
	selectDaily: (day: number?) -> (),
	joinFriend: (userId: number) -> (),
	leave: () -> (),
	hint: (name: string) -> (),
	-- First person (optional): the look-to-interact picker (Heist/LookTarget) and the hands (Heist/Viewmodel).
	look: any?,
	hands: ((action: string) -> ())?,
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
	TypeSpecimen.watch(playerGui) -- Studio only: EH_Scenario = "TYPE" (D8)

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
		deviceScale = deviceScale,
		runHud = runHud,
		waiting = false, -- RUN tapped, waiting for the crew
		lastGrabTap = -math.huge, -- os.clock() of the last GRAB tap (END RUN guard)
		stopsLineUntil = 0, -- L1: "Your clone stops where you stop." from the clone's press
	}
	-- In a heist the player list is off (LineupDirector turns all CoreGui back on after its
	-- cut, then calls setCutscene(false), which applies this again).
	local inHeist = false
	local function applyPlayerList()
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, not inHeist)
	end
	function ctx.setInHeist(on: boolean)
		if on ~= inHeist then
			inHeist = on
			applyPlayerList()
		end
	end

	ctx.top = TopBar.build(ctx)
	ctx.controls = Controls.build(ctx)
	ctx.msg = Messages.build(ctx)
	ctx.reticle = Reticle.build(ctx)
	ctx.deck = Deck.build(ctx)
	ctx.results = Results.build(ctx)
	ctx.garage = Garage.build(ctx)
	ctx.hints = Hints.build(ctx)
	ctx.settings = SettingsPanel.build(ctx)
	BankFly.build(ctx)
	Run.build(ctx)
	ctx.crew = CrewView.build(ctx) -- after Reticle (the prompt chip) and Run
	ctx.lobby = Lobby.build(ctx) -- after Run: it uses ctx.fpLayout
	ctx.wardrobe = Wardrobe.build(ctx)
	-- The hideout (Heist/Hideout): the lobby HUD, the station sheets.
	hud.lobby = ctx.lobby
	hud.wardrobe = ctx.wardrobe
	function hud.openStation(mode: string, back: () -> ())
		ctx.garage.openStation(mode, back)
	end
	function hud.closeStation()
		ctx.garage.closeStation()
	end
	function hud.stationOpen(): boolean
		return ctx.garage.isOpen()
	end
	Controls.bind(ctx)
	-- The deck learns how each run ended (the clone a full deck replaced, START OVER) before the
	-- run's own end handling.
	local runEnd = hud.onRunEnd
	hud.onRunEnd = function(p: any)
		ctx.deck.noteRunEnd(p)
		runEnd(p)
	end
	-- Crew View's one-time hint looks at each run's clones.
	local runStart = hud.onRun
	hud.onRun = function(m: any)
		runStart(m)
		ctx.crew.onRun(m)
	end
	-- The stuck tracker counts a run once its deck is in (Hud/Hints).
	local deckOnDeck = hud.onDeck
	hud.onDeck = function(...)
		deckOnDeck(...)
		ctx.hints.onDeck()
	end

	-- Set by HeistClient (RewindDirector): (text, colour, hold seconds?).
	hud.bigStamp = function(_text: string, _color: Color3, _hold: number?) end
	-- Set by HeistClient (MomentDirector.catchView): when you are caught, the BUSTED stamp and the advice
	-- line wait for the busted view's camera ease (PLAN C3). Default: at once.
	hud.catchView = function(fn: () -> ())
		fn()
	end

	-- Is a sheet up (results, MENU, settings)? First person frees the cursor then (Heist/CameraDirector).
	hud.sheetOpen = Common.sheetUp

	function hud.hideAll()
		ctx.reticle.set(false, nil)
		ctx.lobby.hide()
		ctx.wardrobe.close()
		runHud.Visible = false
		ctx.deck.panel.Visible = false
		ctx.results.card.Visible = false
		ctx.deck.readyWait.Visible = false
		ctx.top.alarmPill.Visible = false
		ctx.msg.pauseChip.Visible = false
		ctx.msg.menuSheet.Visible = false
		ctx.settings.panel.Visible = false
		ctx.msg.setHidden(false)
		ctx.msg.setSpectate("")
		ctx.hints.clear()
		ctx.hints.hideHelp()
		ctx.top.resetCount()
		ctx.setInHeist(false)
	end

	-- The end-of-heist cut hides the whole HUD (HUD, chat and nameplates hidden, §6.6).
	function hud.setCutscene(on: boolean)
		gui.Enabled = not on
		if on then
			ctx.reticle.set(false, nil)
			ctx.hints.clear()
			ctx.hints.hideHelp()
			ctx.msg.menuSheet.Visible = false
			ctx.settings.panel.Visible = false
			ctx.msg.setHidden(false)
		else
			applyPlayerList()
		end
	end

	return hud
end

return Hud
