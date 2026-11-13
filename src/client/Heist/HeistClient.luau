--!strict
-- Heist/HeistClient: the sim path's client (Config.GAME_MODE = "sim"). MASTERPLAN
-- §8.2 ("clients receive each recording once and render local rigs from the loop
-- clock"), §6.5, §6.6, §7.1-7.5.
--
-- It keeps one state table fed by the server's Heist.Msg push (and Heist.Sync at
-- boot), and once per frame samples the replicated LoopClock and draws:
--   EchoView (clones from Rec/Sampler), GusView (Guards.patrol + pose attributes),
--   WorldView (doors/lasers/plates/loot/alarm from attributes, kit door skins), LightDirector
--   (lamp shadows and floor pools by performance tier), Backdrop (ground, facades, skyline rings, sky turn and
--   falling snow round the heist instance or the garage), Aurora (the northern lights, tier-gated),
--   RewindDirector, Hud, and at heist end the LineupDirector (Crew Line-up cut).
-- The camera is CameraDirector's (diorama / classic, wall fade, run-start beat); the
-- Line-up borrows it through state.camera (suspend / resume), the rewind's FOV dip goes
-- through camera.setFovKick.
-- Sound goes through Heist/Sound (AudioDirector): every live sim event plays its cues
-- (Audio/EventCues), music follows garage / heist / alarm / results, ambience follows
-- the room. Analytics through Heist/Telemetry (Ready, Ui hints, Perf samples).
-- Settings (Heist/Settings, U7) apply here: music and SFX volume, captions, camera shake (the rewind's
-- FOV kick), reduced motion (the device setting OR the player's), colour-blind shapes and the guard
-- path (state flags the views read).
-- Presentation shell (PLAN_STEAM_PLUS §4.1 W7, §4.2 C2 + C4): Heist/Loading hands the first frame off
-- (the ReplicatedFirst card, or the first-join title beat), Heist/Transition is the van-door wipe
-- between garage, heist and results, Heist/LevelIntro the first-visit camera inside run 1's transition.
-- The bank moment: a live Bank event calls hud.onBank(amount, vanPos) (the HUD half: "+$100!" flies
-- to the loot meter); WorldView plays the world half itself (coins, the van bounce).
-- Signature moments (Heist/MomentDirector): every applied event and run goes to it (8 OF ME, the
-- busted view, heist complete, the blooper log), the views draw with its filtered view time
-- (hit-stop, the blooper replay), and at Over the blooper cut plays before the Line-up.
-- The hideout lobby (Heist/Hideout, Config.Hideout): in the garage you walk in first person and use the stations
-- and the vans by looking at them; its intents ride on Heist.Ready (a VanRules action table), the server's "Depart"
-- message plays the drive before the heist's Sync.
-- The client never decides an outcome: it only sends intents (Heist.* remotes).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Rec = Shared:WaitForChild("Rec")
local Codec = require(Rec:WaitForChild("Codec"))
local LoopClock = require(Rec:WaitForChild("LoopClock"))
local Sim = Shared:WaitForChild("Sim")
local EventLog = require(Sim:WaitForChild("EventLog"))
local LevelSpec = require(Sim:WaitForChild("LevelSpec"))
local Budget = require(Shared:WaitForChild("Heist"):WaitForChild("Budget"))
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))

local Heist = script.Parent
local Aurora = require(Heist:WaitForChild("Aurora"))
local ScarfSway = require(Heist:WaitForChild("ScarfSway"))
local Backdrop = require(Heist:WaitForChild("Backdrop"))
local EchoView = require(Heist:WaitForChild("EchoView"))
local CameraDirector = require(Heist:WaitForChild("CameraDirector"))
local CutAway = require(Heist:WaitForChild("CutAway"))
local GoldenShots = require(Heist:WaitForChild("GoldenShots"))
local DebugChip = require(Heist:WaitForChild("DebugChip"))
local GusView = require(Heist:WaitForChild("GusView"))
local WorldView = require(Heist:WaitForChild("WorldView"))
local RewindDirector = require(Heist:WaitForChild("RewindDirector"))
local LineupDirector = require(Heist:WaitForChild("LineupDirector"))
local MomentDirector = require(Heist:WaitForChild("MomentDirector"))
local LightDirector = require(Heist:WaitForChild("LightDirector"))
local JobBoard = require(Heist:WaitForChild("JobBoard"))
local Hideout = require(Heist:WaitForChild("Hideout"))
local Hud = require(Heist:WaitForChild("Hud"))
local Settings = require(Heist:WaitForChild("Settings"))
local FirstTime = require(Heist:WaitForChild("FirstTime"))
local Sound = require(Heist:WaitForChild("Sound"))
local Particles = require(Heist:WaitForChild("Particles"))
local Telemetry = require(Heist:WaitForChild("Telemetry"))
local Ui = require(Heist:WaitForChild("Ui"))
local Loading = require(Heist:WaitForChild("Loading"))
local Transition = require(Heist:WaitForChild("Transition"))
local LevelIntro = require(Heist:WaitForChild("LevelIntro"))
local Viewmodel = require(Heist:WaitForChild("Viewmodel"))
local Slide = require(Heist:WaitForChild("Slide"))
local RookieAnim = require(Heist:WaitForChild("RookieAnim"))
local LookTarget = require(Heist:WaitForChild("LookTarget"))
local LookTilt = require(Heist:WaitForChild("LookTilt"))
local FpWarn = require(Heist:WaitForChild("FpWarn"))
local BadgeView = require(Heist:WaitForChild("BadgeView"))
local HudCommon = require(Heist:WaitForChild("Hud"):WaitForChild("Common"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local EV = EventLog.EV
local R = Protocol.REMOTE
local H = Config.Heist
local localPlayer = Players.LocalPlayer

-- Music set per level id (the heist state's default is the Caper set; Big Scores swing).
local MUSIC_SET: { [string]: string } = {
	cs5_clone_party = "BigScore",
	bk1_big_score = "BigScore",
}

local HeistClient = {}

local started = false

function HeistClient.start()
	if started then
		return
	end
	started = true

	local state: any = {
		where = "boot",
		garage = nil,
		folder = nil,
		level = nil,
		levelIndex = 0,
		levelInfo = nil,
		daily = nil,
		dressing = false,
		kit = false,
		origin = Vector3.zero,
		crew = {},
		mySeat = 1,
		recs = {},
		run = nil,
		clock = nil,
		phase = "",
		frozenT = 0,
		lastRunT = 0,
		runEndedAt = 0,
		runEndedAtByRun = {} :: { [number]: number }, -- os.clock() when each run's RunEnd arrived
		deck = nil,
		over = nil,
		actorFx = {},
		carrying = false,
		liveCount = 1,
		reduced = GuiService.ReducedMotionEnabled or Settings.get("reducedMotion") == true,
		particleScale = 1,
		perfTier = 1, -- the runtime performance tier (Telemetry.onTier; Shared/Heist/Budget)
		guardPath = Settings.get("guardPath") ~= false, -- GusView: his boot prints
		colourBlindGlyphs = Settings.get("colourBlindGlyphs") == true, -- seat shapes beside numbers
	}
	Sound.setReducedMotion(state.reduced == true)
	Ui.setReducedMotion(state.reduced == true)
	local backdropRef: any = nil -- set below, once the Backdrop exists
	local auroraRef: any = nil -- set below, once the Aurora exists
	-- Reduced motion: the device's setting, or the player's own (Settings "reducedMotion").
	local function applyReduced()
		state.reduced = GuiService.ReducedMotionEnabled or Settings.get("reducedMotion") == true
		Sound.setReducedMotion(state.reduced == true)
		Ui.setReducedMotion(state.reduced == true)
		if backdropRef then
			backdropRef.setReducedMotion(state.reduced == true)
		end
		if auroraRef then
			auroraRef.setReducedMotion(state.reduced == true)
		end
	end
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(applyReduced)

	-- Compiled levels: Catalog indices (play order) and daily vaults by UTC day.
	local levelCache: { [string]: any } = {}
	local function levelFor(index: number, day: number?, relaxed: boolean?): any
		local key = (if index == Protocol.DAILY_INDEX then "d" .. tostring(day) else tostring(index))
			.. (if relaxed then "r" else "")
		local cached = levelCache[key]
		if not cached then
			local spec = Protocol.levelSpec(index, day, relaxed)
			if spec then
				cached = LevelSpec.compile(spec)
				levelCache[key] = cached
			end
		end
		return cached
	end

	local echo = EchoView.new(state)
	local gus = GusView.new(state)
	local world = WorldView.new(state, echo.carryPointOf) -- clones carry loot in their hands
	local lights = LightDirector.new()
	local camera = CameraDirector.new(state)
	state.camera = camera -- LineupDirector hands the camera back through it
	-- BIG buildings: roofs, ceilings and storeys out of the camera's way (never in first person)
	local cutaway = CutAway.new(camera)
	-- First person (PLAN_FIRST_PERSON FP): the hands, look-to-interact and Gus's edge warning.
	local momentsRef: any = nil -- MomentDirector, made after the HUD (the hands hold during its hit-stop)
	RookieAnim.start() -- your character in the Rookie's own walk, run, idle, jump, fall and land
	local hands = Viewmodel.new(state, {
		camera = camera,
		world = world,
		hue = function(): Color3
			return Palette.hueFor(state.mySeat or 1)
		end,
		frozen = function(): boolean
			return momentsRef ~= nil and momentsRef.frozen(os.clock())
		end,
	})
	local look = LookTarget.new(state, {
		world = world,
		isTouch = HudCommon.usingTouch,
		usingGamepad = HudCommon.usingGamepad,
	})
	local backdrop = Backdrop.new()
	backdropRef = backdrop
	backdrop.setReducedMotion(state.reduced == true)
	-- The northern lights (SKY track): one client-built aurora for the whole session, anchored to the garage or the
	-- crew's instance; its landmark direction is read from Lighting.Sky (the Backdrop turns it per site).
	local aurora = Aurora.new()
	auroraRef = aurora
	aurora.setReducedMotion(state.reduced == true)
	if Config.Aurora.ENABLED then
		lights.setExteriorTint(Config.Aurora.OUTDOOR_ADD)
	end
	-- The long scarf's tail sways on your character and your clones' rigs (CH polish; off from a low tier).
	local swayList: { Model } = {}
	local scarves = ScarfSway.new({
		models = function(): { Model }
			table.clear(swayList)
			local ch = Players.LocalPlayer and Players.LocalPlayer.Character
			if ch then
				table.insert(swayList, ch)
			end
			return if state.where == "heist" then echo.swayModels(swayList) else swayList
		end,
	})
	-- Look up / down: your first-person pitch goes out (Heist.Ready "look"); other players' heads and chests follow.
	LookTilt.new({
		camera = camera,
		send = function(n: number)
			Net.Send(Protocol.REMOTE.Ready, { op = "look", n = n })
		end,
	})
	local ffOn = false
	local slideRef: any = nil -- Heist/Slide, made once the HUD exists
	local doors: any = nil -- Heist/Transition, once the HUD's fx layer exists
	-- A level pick: the doors start closing at once and hold while the server builds the heist
	-- (they open again by themselves, or on the refusal toast, if no heist comes).
	local function pickWipe()
		if state.where == "garage" and state.garage and state.garage.lobby == true then
			return -- the hideout: a job pick only pins the job; the van starts the heist (its drive, then the wipe)
		end
		if doors then
			doors.closeFor(Config.Presentation.DOORS.HOLD_MAX_SECONDS)
		end
	end

	local actions = {
		endRun = function()
			Sound.play("RewindClack") -- the tape-deck clack, before any server reply (§7.1)
			hands.play("watch") -- first person: a tap on the wrist-watch
			Net.Send(R.EndRun)
		end,
		interact = function(kind: number, index: number)
			Net.Send(R.Interact, kind, index)
		end,
		deck = function(op: string, n: number?)
			Net.Send(R.Deck, op, n)
		end,
		ready = function()
			Net.Send(R.Ready, state.reduced == true)
		end,
		fastForward = function(on: boolean)
			if on ~= ffOn then
				ffOn = on
				Net.Send(R.FastForward, on)
			end
		end,
		-- relaxed = true: the "Try Relaxed?" card (the server checks the offer, Protocol).
		selectLevel = function(index: number, relaxed: boolean?)
			pickWipe()
			if relaxed then
				Net.Send(R.SelectLevel, index, true)
			else
				Net.Send(R.SelectLevel, index)
			end
		end,
		selectDaily = function(day: number?)
			pickWipe()
			Net.Send(R.SelectDaily, day)
		end,
		joinFriend = function(userId: number)
			Net.Send(R.JoinFriend, userId)
		end,
		-- a hideout lobby action table (Heist.Ready; Shared/Heist/VanRules.validAction): the Quick Crew sheet's ops
		lobbyAction = function(action: any)
			Net.Send(R.Ready, action)
		end,
		leave = function()
			Net.Send(R.Leave)
		end,
		hint = function(name: string)
			Telemetry.ui("Hint", name)
		end,
		-- MENU > CAMERA: DIORAMA / CLASSIC (C0 A/B): flips and saves the mode, returns it.
		toggleCamera = function(): string
			return camera.toggle()
		end,
		cameraMode = function(): string
			return camera.mode()
		end,
		onCameraMode = function(fn: (string) -> ())
			camera.onModeChanged(fn)
		end,
		-- First person: what you look at (Hud/Run, Hud/Reticle), the hands' actions, the cursor lock.
		look = look,
		hands = function(action: string)
			hands.play(action)
		end,
		cursorLocked = function(): boolean
			return camera.cursorLocked()
		end,
		-- Crew View (Hud/CrewView, Hud/Controls): hold / release, the camera blend + veil + active, may it start.
		crewHold = function(who: string, on: boolean)
			camera.setCrewHeld(who, on)
		end,
		crewState = function(): (number, number, boolean)
			return camera.crew()
		end,
		crewAllowed = function(): boolean
			return camera.crewAllowed()
		end,
		-- The slide (Hud/Slide's touch button; the keys are Heist/Slide's own).
		slide = function(fast: boolean)
			if slideRef then
				slideRef.start(fast)
			end
		end,
		slideAllowed = function(): boolean
			return slideRef ~= nil and slideRef.allowed()
		end,
		-- Your newest clone this run, where it is drawn (world space), or nil: the L1 look cue (Hud/Hints).
		ownClone = function(): Vector3?
			local id = echo.newestOwn()
			return if id ~= 0 then echo.positionOf(id) else nil
		end,
	}
	FirstTime.init() -- first-time beats, seeded from the profile (Heist/FirstTime)
	local hud = Hud.new(state, actions)
	camera.setCursorProbe(hud.sheetOpen) -- first person: the cursor is free while a sheet is up
	local gusWarn = FpWarn.new(state, hud.fxGui)
	-- Badges: the BADGE UNLOCKED card and the boss's marks, from server-written attributes (Heist/BadgeView).
	BadgeView.new(hud.fxGui, hud.toast, {
		reduced = function(): boolean
			return state.reduced == true
		end,
	})
	-- Camera shake off: the rewind's FOV kick stays at 0 (Settings "shake").
	local function fovKick(deg: number)
		camera.setFovKick(if Settings.get("shake") == false then 0 else deg)
	end
	-- The rewind's path trails: the coming run's clones over the last run (EchoView.paths).
	local director = RewindDirector.new(hud.fxGui, fovKick, function()
		return state.origin, if state.level then state.level.floorY or 0 else 0, state.lastRunT, echo.paths()
	end)
	-- Crew View frames every visible clone and the run's objective; the rewind finish drops it.
	local crewList: { Vector3 } = {}
	camera.setCrewSource({
		points = function(): { Vector3 }
			table.clear(crewList)
			return if state.where == "heist" then echo.positions(crewList) else crewList
		end,
		objective = function(): Vector3?
			local o = CameraDirector.objectiveOf(state.level)
			return if o then (state.origin or Vector3.zero) + Vector3.new(o[1], o[2], o[3]) else nil
		end,
		rewinding = function(): boolean
			return director.isPlaying()
		end,
	})
	-- The slide (Config.Slide): Ctrl / B / SLIDE; in a run the server records it (Heist.Interact Slide).
	slideRef = Slide.new(state, {
		camera = camera,
		send = function(arg: number)
			Net.Send(R.Interact, Codec.EVENT.Slide, arg)
		end,
		fastForwardOff = function()
			actions.fastForward(false)
		end,
		sheetOpen = hud.sheetOpen,
		rewinding = function(): boolean
			return director.isPlaying()
		end,
		crewCancel = function()
			camera.cancelCrew()
		end,
	})
	hud.bigStamp = function(text: string, color: Color3, hold: number?)
		director.stamp(text, color, hold or 1.2, not state.reduced)
	end
	local lineup = LineupDirector.new(state, hud.fxGui, echo, world, hud)
	-- 8 OF ME, the busted view, heist complete, the blooper cut, hit-stop (Heist/MomentDirector).
	local moments = MomentDirector.new(state, {
		gui = hud.fxGui,
		hud = hud,
		echo = echo,
		gus = gus,
		world = world,
		camera = camera,
		fovKick = fovKick,
	})
	hud.catchView = moments.catchView
	momentsRef = moments
	local isReduced = function(): boolean
		return state.reduced == true
	end
	doors = Transition.new(hud.fxGui, isReduced)
	local boot = Loading.boot(doors, isReduced, camera, Telemetry.tier) -- camera + tier: the story intro
	-- The hideout lobby: stations, vans, the drive (Heist/Hideout).
	local hideout = Hideout.new(state, {
		camera = camera,
		look = look,
		hud = hud,
		doors = doors,
		send = function(action: any)
			Net.Send(R.Ready, action)
		end,
		reduced = isReduced,
		tier = Telemetry.tier,
		hands = function(action: string)
			hands.play(action)
		end,
		ui = Telemetry.ui,
	})
	local intro = LevelIntro.new(camera, state)
	local revealPending = false
	-- The doors (or, at boot, the card / the title) open onto what was just built; controlAt: when the
	-- server gives control (the doors are open by then).
	local function reveal(controlAt: number?)
		revealPending = false
		if boot.active() then
			boot.landed(controlAt)
		else
			doors.open()
		end
	end

	-- Settings (U7): volumes now and on every change; reduced motion; the flags the views read.
	local function applySetting(key: string, value: any)
		if key == "musicVolume" then
			Sound.setBusVolume("Music", tonumber(value) or 1)
		elseif key == "sfxVolume" then
			for _, bus in Config.Ui.SFX_BUSES do
				Sound.setBusVolume(bus, tonumber(value) or 1)
			end
		elseif key == "reducedMotion" then
			applyReduced()
		elseif key == "guardPath" then
			state.guardPath = value ~= false
		elseif key == "colourBlindGlyphs" then
			state.colourBlindGlyphs = value == true
		end
	end
	Settings.onChanged(applySetting)

	-- Sound: first-impression cues + the likely music; captions into the HUD (on by default).
	task.spawn(function()
		Sound.preload({ "Caper", "Garage" })
		applySetting("musicVolume", Settings.get("musicVolume"))
		applySetting("sfxVolume", Settings.get("sfxVolume"))
		Sound.setCaptionHandler(function(text: string)
			if Settings.get("captions") ~= false then
				hud.caption(text)
			end
		end)
	end)

	-- Telemetry and the runtime performance tier (§6.3, §8.6).
	Telemetry.start()
	Telemetry.setCloneCounter(echo.visibleCount)
	-- Budgets per tier: Shared/Heist/Budget (Config.Perf, docs/PERF.md). LightDirector owns the Lighting service
	-- (recipe C "Soft Toybox" from tier 3, incl. GlobalShadows off).
	-- One particle budget for every effect (Heist/Particles): the backdrop's snow reports what it keeps alive
	-- (rate x lifetime, capped per tier by Budget.snow), so the bursts get only what is left of the tier's cap.
	local snowEmitter: ParticleEmitter? = nil
	Particles.setSteady("snow", function(): number
		local e = snowEmitter
		if not (e and e.Parent) then
			local bd = workspace:FindFirstChild("EH_Backdrop")
			local found = bd and bd:FindFirstChild("Snow", true)
			e = if found and found:IsA("ParticleEmitter") then found else nil
			snowEmitter = e
		end
		return if e and e.Enabled then e.Rate * e.Lifetime.Max else 0
	end)
	Telemetry.onTier(function(tier: number)
		state.perfTier = tier
		Particles.setTier(tier)
		state.particleScale = Budget.particleScale(tier)
		director.setBlurAllowed(tier < 2)
		director.setTier(tier)
		moments.setTier(tier)
		echo.setTier(tier)
		lineup.setTier(tier)
		lights.setTier(tier)
		backdrop.setTier(tier)
		cutaway.setTier(tier)
		aurora.setTier(tier)
		scarves.setTier(tier)
	end)
	DebugChip.start(echo, Telemetry.tier) -- Studio only: clones drawn / healthy / tier / avatar
	GoldenShots.start(camera, state, echo) -- Studio only: golden-frame staging (EH_Scenario)

	-- Where a sim event happened, for AudioDirector.event (docs/AUDIO.md §9 item 3).
	local function actorOf(id: number): any
		local run = state.run
		return run and run.actorById and run.actorById[id]
	end
	local resolver = {
		position = function(what: string, index: number): any
			if what == "actor" then
				local a = actorOf(index)
				if not a then
					return nil
				end
				if a.kind == "clone" then
					return echo.positionOf(index)
				end
				local p = Players:GetPlayerByUserId(a.owner)
				local root = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				return if root and root:IsA("BasePart") then root else nil
			end
			return world.partFor(what, if what == "van" then 1 else index)
		end,
		isClone = function(id: number): boolean
			local a = actorOf(id)
			return a ~= nil and a.kind == "clone"
		end,
		isMine = function(id: number): boolean
			local a = actorOf(id)
			return a ~= nil and a.kind == "live" and a.owner == localPlayer.UserId
		end,
	}

	local function musicSet(): string?
		local info = state.levelInfo
		return if info then MUSIC_SET[info.id] else nil
	end

	-- Current view time on the loop clock (frozen between runs).
	local function viewTime(): (number, number)
		local clock = state.clock
		if state.phase ~= "Run" or not clock then
			return state.frozenT, 0
		end
		local raw = LoopClock.rawT(clock, workspace:GetServerTimeNow())
		return math.clamp(raw, 0, clock.length), raw
	end

	local function actorFx(id: number): any
		local fx = state.actorFx[id]
		if not fx then
			fx = {}
			state.actorFx[id] = fx
		end
		return fx
	end

	-- The bank moment (PLAN §5 "First bank"): the HUD half here, the world half in WorldView if it
	-- has one (world.onBank(amount, worldPos); no-op until the world track adds it).
	local function bankMoment(e: Protocol.Entry)
		local level = state.level
		local def = level and level.loot and level.loot[e.b]
		local amount = if def then tonumber(def.value) or 0 else 0
		local van = world.partFor("van", 1)
		local pos: Vector3? = nil
		if van and van:IsA("BasePart") then
			pos = van.Position
		elseif van and van:IsA("Model") then
			pos = van:GetPivot().Position
		end
		hud.onBank(amount, pos)
		-- The world half (coins, van bounce, "+$100!" pop) is WorldView's own: it fires from the loot
		-- attributes. world.onBank registers a listener (fn(amount, pos)); it is not called here, since
		-- calling it with an amount added a number as a listener and broke every later bank.
	end

	local function applyEvent(e: Protocol.Entry, live: boolean)
		local now = os.clock()
		local hz = Config.Rec.HZ
		if live then
			Sound.event(e, resolver)
		end
		if e.kind == EV.Busted then
			local fx = actorFx(e.b)
			fx.gone = "Busted"
			fx.goneAtLocal = if live then now else -math.huge
			if live then
				echo.effect(e.b, "Busted", now)
				gus.bang(e.a, now, "bust", resolver.position("actor", e.b))
			end
		elseif e.kind == EV.Zap then
			local a = actorOf(e.a)
			if a and a.kind == "clone" then
				local fx = actorFx(e.a)
				fx.gone = "Zapped"
				fx.goneAtLocal = if live then now else -math.huge
			end
			if live then
				echo.effect(e.a, "Zapped", now)
			end
		elseif e.kind == EV.Stuck then
			actorFx(e.a).stuckT = math.max(0, (e.tick - 1) / hz)
			if live then
				echo.effect(e.a, "Stuck", now)
			end
		elseif e.kind == EV.Shrug then
			if live then
				echo.effect(e.a, "Shrug", now)
			end
		elseif e.kind == EV.Caught then
			if live then
				gus.bang(e.a, now, "catch", resolver.position("actor", e.b))
			end
		elseif e.kind == EV.Bank and live then
			bankMoment(e)
		end
		moments.onEvent(e, live)
		hud.onEvent(e, live)
		if live then
			hands.onEvent(e, resolver.isMine, EV)
		end
	end

	local function applyEvents(buf: buffer?, live: boolean)
		if buf == nil then
			return
		end
		for _, e in Protocol.decodeEvents(buf) do
			applyEvent(e, live)
		end
	end

	local function addRec(key: number, buf: any)
		if type(key) ~= "number" or typeof(buf) ~= "buffer" or state.recs[key] then
			return
		end
		local rec = Codec.decode(buf)
		if rec then
			state.recs[key] = rec
		end
	end

	local function applyRun(msg: any, live: boolean)
		local clock = Protocol.readClock(msg.clock)
		if not clock then
			return
		end
		state.run = msg
		state.clock = clock
		state.phase = "Run"
		state.over = nil
		table.clear(state.actorFx)
		local byId = {}
		local liveCount, clones = 0, 0
		state.myCapacity = 1
		for _, a in msg.actors do
			byId[a.id] = a
			if a.kind == "live" then
				liveCount += 1
				if a.owner == localPlayer.UserId and type(a.capacity) == "number" then
					state.myCapacity = math.max(1, a.capacity)
				end
			elseif a.kind == "clone" then
				clones += 1
			end
		end
		msg.actorById = byId
		state.liveCount = liveCount
		local transition = if live then (msg.transition or 0) else 0
		local reelEnd = state.lastRunT
		echo.setRun(msg, state.recs, os.clock() + transition * 0.75)
		hands.onRun()
		moments.onRun(msg, live) -- the rewind's 66 ms freeze; a fresh blooper log
		hud.onRun(msg)
		Telemetry.ready() -- first control (JoinToControl)
		Sound.music("Heist", { set = musicSet() })
		if live then
			-- C1: the run-start beat eases from the objective to you inside the transition.
			local spawns = state.level and state.level.spawns
			local spawn = spawns and spawns[((state.mySeat or 1) - 1) % #spawns + 1]
			camera.frameRunStart(CameraDirector.objectiveOf(state.level), transition, spawn and spawn.yaw)
			if msg.run == 1 then
				-- C2: the level's first look, inside this transition (once per level, never on L1)
				local info = state.levelInfo
				intro.play(state.level, info, transition, info ~= nil and info.kind == Protocol.KIND.Party)
			end
			if revealPending then
				local controlAt = os.clock() + transition
				if boot.active() then
					boot.noteControl(controlAt) -- the first frame -> control rule (G1), FTUE path
				end
				reveal(controlAt)
			end
			local kind = msg.kind or "Standard"
			if state.reduced and kind ~= "Intro" then
				kind = "Reduced"
			end
			director.play(kind, transition, msg.run, function(u: number)
				state.reelT = reelEnd * (1 - u)
			end, function()
				state.reelT = nil
			end, clones)
			hud.dawnWarning(tonumber(msg.run) or 1)
		else
			Sound.go(clones)
		end
	end

	-- Ambience follows the room (docs/AUDIO.md §9 items 5-6).
	local function setAmbience(where: string)
		Sound.stopCue("AmbStreet")
		Sound.stopCue("AmbRoom")
		Sound.stopCue("AmbVault")
		if where == "garage" then
			Sound.play("AmbStreet")
		elseif where == "bank" then
			Sound.play("AmbVault")
		elseif where == "room" then
			Sound.play("AmbRoom")
		end
	end

	local function setupInstance(p: any): boolean
		local heists = workspace:WaitForChild(Protocol.FOLDER, 10)
		local folder = heists and heists:WaitForChild(p.instance, 10)
		if not folder then
			warn("[HeistClient] instance folder " .. tostring(p.instance) .. " did not arrive")
			return false
		end
		local levelModel = folder:WaitForChild("Level", 10)
		local daily = if type(p.daily) == "table" then p.daily else nil
		state.folder = folder
		state.levelIndex = p.levelIndex
		state.daily = daily
		state.levelInfo = if type(p.level) == "table" then p.level else nil
		state.dressing = p.dressing == true
		state.kit = p.kit == true
		state.relaxed = p.relaxed == true
		state.level = levelFor(p.levelIndex, daily and daily.day, state.relaxed)
		if not state.levelInfo and state.level then
			state.levelInfo = { id = state.level.id, name = state.level.name, kind = state.level.kind }
		end
		state.origin = if typeof(p.origin) == "Vector3" then p.origin else Vector3.zero
		state.crew = p.crew or {}
		state.mySeat = 1
		for _, m in state.crew do
			if m.userId == localPlayer.UserId then
				state.mySeat = m.seat
			end
		end
		if levelModel then
			world.bind(levelModel)
			lights.bind(levelModel)
		end
		cutaway.bind(levelModel)
		backdrop.showHeist(levelModel, state.level, state.origin, state.dressing)
		cutaway.addOccluders(backdrop.occluders()) -- the tall town: a block between the camera and you fades
		aurora.setAnchor(state.origin + Vector3.new(0, if state.level then state.level.floorY or 0 else 0, 0))
		if state.level then
			gus.setLevel(state.level)
		end
		Sound.setChristmas(state.dressing)
		local location = state.levelInfo and state.levelInfo.location
			or (state.level and state.level.spec and state.level.spec.location)
		setAmbience(if location == "Bank" then "bank" else "room")
		return true
	end

	local function toGarage(p: any)
		moments.stop()
		lineup.stop()
		state.where = "garage"
		state.garage = p
		state.folder = nil
		state.run = nil
		state.clock = nil
		state.phase = ""
		state.deck = nil
		state.over = nil
		state.lastRunT = 0
		table.clear(state.runEndedAtByRun)
		table.clear(state.recs)
		world.quiet()
		camera.clearFades()
		look.clear()
		gusWarn.hide()
		echo.clear()
		gus.clear()
		world.clear()
		lights.clear()
		cutaway.bind(workspace:FindFirstChild("Garage"))
		backdrop.showGarage()
		cutaway.addOccluders(backdrop.occluders())
		local lobby = Config.Heist.LOBBY_ORIGIN
		aurora.setAnchor(Vector3.new(lobby[1], lobby[2], lobby[3]))
		director.stop()
		hud.hideAll()
		hud.hidePreparing()
		hud.showGarage()
		pcall(JobBoard.show, p) -- your next job on the 3D job board (visual only)
		hideout.enter()
		Sound.stopCue("AlarmBell")
		Sound.stopCue("LaserHum")
		Sound.setChristmas(nil)
		Sound.music("Garage")
		setAmbience("garage")
	end

	local syncSeen = false

	local function handle(kind: string, p: any)
		if type(p) ~= "table" then
			return
		end
		if kind == "Sync" then
			syncSeen = true
			if p.where == "garage" then
				intro.stop()
				if state.where == "garage" and not boot.active() then
					-- already in the hideout: your crew, its van or the job changed (no wipe, nothing rebuilt)
					state.garage = p
					hud.showGarage()
					pcall(JobBoard.show, p)
					hideout.refresh()
					return
				end
				if boot.active() then
					boot.arrive("garage")
					toGarage(p)
					reveal(nil) -- the card fades on the garage's first built frame
				else
					doors.close() -- results / heist -> garage behind the van doors (C4)
					toGarage(p)
					doors.open()
				end
				return
			end
			if p.where == "preparing" then
				-- A new account while the server starts the first heist: the loading card's reel
				-- or the title beat, never the garage (no tapes, no daily vault) and never a silent
				-- text card, until the server decides (§7.5, WALKTHROUGH §2.0).
				state.where = "preparing"
				hideout.leave()
				hud.hideAll()
				hud.hideGarage()
				if not boot.preparing() then
					hud.showPreparing()
				end
				return
			end
			if p.where ~= "heist" then
				return
			end
			moments.stop()
			intro.stop()
			if boot.active() then
				local info = p.level
				local ftue = type(info) == "table" and info.id == H.FTUE_L1_LEVEL
				boot.arrive(if ftue then "heistFtue" else "heist")
			else
				doors.close() -- garage / results -> heist: the level binds behind the doors
			end
			hideout.leave() -- the drive, a station, the lobby HUD (behind the closed doors)
			lineup.stop()
			hud.hideGarage()
			hud.hidePreparing()
			table.clear(state.recs)
			table.clear(state.runEndedAtByRun)
			state.lastRunT = 0
			if not setupInstance(p) then
				reveal(nil)
				return
			end
			state.where = "heist"
			for _, r in p.recs or {} do
				if type(r) == "table" then
					addRec(r.key, r.buf)
				end
			end
			state.deck = p.deck
			if p.run then
				applyRun(p.run, false)
				applyEvents(p.ev, false)
			end
			state.phase = p.phase
			if p.phase == "Between" then
				state.frozenT = 0
				hud.onRunEnd(nil)
				hud.showBetween()
			elseif p.phase == "Over" and p.over then
				Sound.music("Results")
				hud.onOver({ result = p.over })
			end
			if p.run or p.phase == "Between" or p.phase == "Over" then
				reveal(os.clock()) -- joined in progress: control is already there
			else
				-- run 1 is on its way: the doors open with it (reveal in applyRun), or by themselves
				revealPending = true
				task.delay(Config.Presentation.DOORS.HOLD_MAX_SECONDS, function()
					if revealPending then
						reveal(nil)
					end
				end)
			end
		elseif state.where ~= "heist" then
			if kind == "Depart" then
				hideout.depart(p) -- GO: the side door shuts, the drive, then the wipe over its end
				return
			end
			if kind == "Toast" then
				hud.toast(tostring(p.text))
				if not boot.active() and doors.isClosed() and not revealPending then
					doors.open() -- a refused pick ("all the vans are out"): back to the garage view
				end
			end
			return
		elseif kind == "Rec" then
			addRec(p.key, p.buf)
		elseif kind == "Run" then
			applyRun(p, true)
		elseif kind == "Ev" then
			if state.run and p.run == state.run.run then
				applyEvents(p.buf, true)
			end
		elseif kind == "Clock" then
			local clock = Protocol.readClock(p.clock)
			if clock and state.run and p.run == state.run.run then
				state.clock = clock
				if clock.rate <= 1 then
					ffOn = false -- the sim ends fast-forward on its own when someone moves
				end
			end
		elseif kind == "RunEnd" then
			local t = viewTime()
			local summary = p.summary
			state.frozenT = if summary and type(summary.t) == "number" then summary.t else t
			state.lastRunT = state.frozenT
			state.runEndedAt = os.clock()
			if type(p.run) == "number" then
				state.runEndedAtByRun[p.run] = state.runEndedAt
			end
			state.phase = "Between"
			ffOn = false
			Sound.stopCue("AlarmBell")
			Sound.music("Heist", { set = musicSet() }) -- out of the chase
			hud.onRunEnd(p)
			echo.prewarm() -- next run's rigs, a few per frame, while the deck is up
		elseif kind == "Deck" then
			state.deck = p
			hud.onDeck()
			if state.phase == "Between" then
				hud.showBetween()
			end
		elseif kind == "Over" then
			state.phase = "Over"
			world.quiet()
			Sound.stopCue("AlarmBell")
			Sound.music("Results")
			local over = p.result
			-- The Crew Line-up cut, then the results card (§6.6).
			-- "◀ ME, N SEC AGO" (CLIPS §1.2: always true): the figure starts where that
			-- clone's replay ended, i.e. you when its run ended, so its age at the walk-off
			-- is the time since that run's RunEnd plus the start delay. Unknown -> no label.
			local over0 = os.clock()
			local function ageOf(entry: any): number?
				local endedAt = state.runEndedAtByRun[tonumber(entry.run) or -1]
				if not endedAt then
					return nil
				end
				return over0 - endedAt + H.LINEUP_START_DELAY
			end
			-- C4: the van doors close on the heist and open on the Line-up / results (no cut).
			intro.stop()
			doors.close()
			if type(over) == "table" then
				-- The blooper cut first when a clone failed in the final run (MASTERPLAN §9.2 #2).
				moments.blooper(over, function()
					if state.phase ~= "Over" or state.where ~= "heist" then
						return -- left for the garage (or a new heist) meanwhile
					end
					over0 = os.clock() -- the label's age at the walk-off stays true after the blooper
					lineup.play(over, function()
						hud.onOver(p)
					end, ageOf)
				end)
			else
				hud.onOver(p)
			end
			doors.open()
		elseif kind == "Leader" then
			-- The crew leader left while the results card is up: the new one gets REPLAY / NEXT.
			local over = state.over
			if over and type(p.leader) == "number" then
				over.leader = p.leader
				hud.refreshResults()
			end
		elseif kind == "Toast" then
			hud.toast(tostring(p.text))
			if doors.isClosed() and not revealPending then
				doors.open() -- a refused pick (REPLAY / NEXT, Relaxed): back to where you were
			end
		end
	end

	-- Messages are handled in order by one consumer (setup can yield).
	local queue: { { any } } = {}
	local pumping = false
	local function pump()
		if pumping then
			return
		end
		pumping = true
		while #queue > 0 do
			local m = table.remove(queue, 1) :: { any }
			local ok, err = pcall(handle, m[1], m[2])
			if not ok then
				warn("[HeistClient] " .. tostring(m[1]) .. ": " .. tostring(err))
			end
		end
		pumping = false
	end
	local function enqueue(kind: string, payload: any)
		table.insert(queue, { kind, payload })
		task.spawn(pump)
	end

	Net.On(R.Msg, function(kind: any, payload: any)
		if type(kind) == "string" then
			enqueue(kind, payload)
		end
	end)
	task.spawn(function()
		local res = Net.Request(R.Sync)
		if res.ok and not syncSeen then
			enqueue("Sync", res.data)
		end
	end)

	-- The garage's "Join friend" list follows who is in the server.
	local function refreshGarage()
		if state.where == "garage" then
			hud.showGarage()
		end
	end
	Players.PlayerAdded:Connect(refreshGarage)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshGarage)
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		if state.where ~= "heist" then
			if state.where == "garage" then
				debug.profilebegin("EH.Hideout")
				hideout.update(os.clock())
				debug.profileend()
			end
			return
		end
		local now = os.clock()
		local tView = viewTime()
		tView, dt = moments.filter(tView, now, dt) -- hit-stop holds it; the blooper replays its window
		-- MicroProfiler labels (MASTERPLAN §8.6 budgets): constant names, one per view.
		debug.profilebegin("EH.EchoSample")
		echo.update(tView, now, dt, state.reelT)
		debug.profileend()
		debug.profilebegin("EH.GuardVision")
		gus.update(tView, now, dt)
		debug.profileend()
		debug.profilebegin("EH.World")
		world.update(tView, now, dt)
		debug.profileend()
		debug.profilebegin("EH.Hud")
		hud.update(tView, now, dt, world)
		gusWarn.update(now, dt)
		debug.profileend()
	end)
end

return HeistClient
