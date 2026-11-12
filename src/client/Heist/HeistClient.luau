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
--   falling snow round the heist instance or the garage),
--   RewindDirector, Hud, and at heist end the LineupDirector (Crew Line-up cut).
-- The camera is CameraDirector's (diorama / classic, wall fade, run-start beat); the
-- Line-up borrows it through state.camera (suspend / resume), the rewind's FOV dip goes
-- through camera.setFovKick.
-- Sound goes through Heist/Sound (AudioDirector): every live sim event plays its cues
-- (Audio/EventCues), music follows garage / heist / alarm / results, ambience follows
-- the room. Analytics through Heist/Telemetry (Ready, Ui hints, Perf samples).
-- The client never decides an outcome: it only sends intents (Heist.* remotes).

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
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
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))

local Heist = script.Parent
local Backdrop = require(Heist:WaitForChild("Backdrop"))
local EchoView = require(Heist:WaitForChild("EchoView"))
local CameraDirector = require(Heist:WaitForChild("CameraDirector"))
local GoldenShots = require(Heist:WaitForChild("GoldenShots"))
local DebugChip = require(Heist:WaitForChild("DebugChip"))
local GusView = require(Heist:WaitForChild("GusView"))
local WorldView = require(Heist:WaitForChild("WorldView"))
local RewindDirector = require(Heist:WaitForChild("RewindDirector"))
local LineupDirector = require(Heist:WaitForChild("LineupDirector"))
local LightDirector = require(Heist:WaitForChild("LightDirector"))
local JobBoard = require(Heist:WaitForChild("JobBoard"))
local Hud = require(Heist:WaitForChild("Hud"))
local Sound = require(Heist:WaitForChild("Sound"))
local Telemetry = require(Heist:WaitForChild("Telemetry"))
local Ui = require(Heist:WaitForChild("Ui"))

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
		reduced = GuiService.ReducedMotionEnabled,
		particleScale = 1,
	}
	Sound.setReducedMotion(state.reduced == true)
	Ui.setReducedMotion(state.reduced == true)
	local backdropRef: any = nil -- set below, once the Backdrop exists
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		state.reduced = GuiService.ReducedMotionEnabled
		Sound.setReducedMotion(state.reduced == true)
		Ui.setReducedMotion(state.reduced == true)
		if backdropRef then
			backdropRef.setReducedMotion(state.reduced == true)
		end
	end)

	-- Compiled levels: Catalog indices (play order) and daily vaults by UTC day.
	local levelCache: { [string]: any } = {}
	local function levelFor(index: number, day: number?): any
		local key = if index == Protocol.DAILY_INDEX then "d" .. tostring(day) else tostring(index)
		local cached = levelCache[key]
		if not cached then
			local spec = Protocol.levelSpec(index, day)
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
	local backdrop = Backdrop.new()
	backdropRef = backdrop
	backdrop.setReducedMotion(state.reduced == true)
	local ffOn = false

	local actions = {
		endRun = function()
			Sound.play("RewindClack") -- the tape-deck clack, before any server reply (§7.1)
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
		selectLevel = function(index: number)
			Net.Send(R.SelectLevel, index)
		end,
		selectDaily = function(day: number?)
			Net.Send(R.SelectDaily, day)
		end,
		joinFriend = function(userId: number)
			Net.Send(R.JoinFriend, userId)
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
	}
	local hud = Hud.new(state, actions)
	local director = RewindDirector.new(hud.fxGui, camera.setFovKick)
	hud.bigStamp = function(text: string, color: Color3, hold: number?)
		director.stamp(text, color, hold or 1.2, not state.reduced)
	end
	local lineup = LineupDirector.new(state, hud.fxGui, echo, world, hud)

	-- Sound: first-impression cues + the likely music; captions into the HUD (on by default).
	task.spawn(function()
		Sound.preload({ "Caper", "Garage" })
		Sound.setCaptionHandler(function(text: string)
			hud.caption(text)
		end)
	end)

	-- Telemetry and the runtime performance tier (§6.3, §8.6).
	Telemetry.start()
	Telemetry.setCloneCounter(echo.visibleCount)
	local shadowsWere = Lighting.GlobalShadows
	Telemetry.onTier(function(tier: number)
		director.setBlurAllowed(tier < 2)
		echo.setTier(tier)
		lineup.setTier(tier)
		lights.setTier(tier)
		backdrop.setTier(tier)
		state.particleScale = if tier >= 3 then 0.5 else 1
		Lighting.GlobalShadows = if tier >= 3 then false else shadowsWere
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
				gus.bang(e.a, now)
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
				gus.bang(e.a, now)
			end
		end
		hud.onEvent(e, live)
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
		hud.onRun(msg)
		Telemetry.ready() -- first control (JoinToControl)
		Sound.music("Heist", { set = musicSet() })
		if live then
			-- C1: the run-start beat eases from the objective to you inside the transition.
			local spawns = state.level and state.level.spawns
			local spawn = spawns and spawns[((state.mySeat or 1) - 1) % #spawns + 1]
			camera.frameRunStart(CameraDirector.objectiveOf(state.level), transition, spawn and spawn.yaw)
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
		state.level = levelFor(p.levelIndex, daily and daily.day)
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
		backdrop.showHeist(levelModel, state.level, state.origin)
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
		echo.clear()
		gus.clear()
		world.clear()
		lights.clear()
		backdrop.showGarage()
		director.stop()
		hud.hideAll()
		hud.hidePreparing()
		hud.showGarage()
		pcall(JobBoard.show, p) -- your next job on the 3D job board (visual only)
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
				toGarage(p)
				return
			end
			if p.where == "preparing" then
				-- A new account while the server starts the first heist: the van door, never
				-- the garage (no tapes, no daily vault) until the server decides (§7.5).
				state.where = "preparing"
				hud.hideAll()
				hud.hideGarage()
				hud.showPreparing()
				return
			end
			if p.where ~= "heist" then
				return
			end
			lineup.stop()
			hud.hideGarage()
			hud.hidePreparing()
			table.clear(state.recs)
			table.clear(state.runEndedAtByRun)
			state.lastRunT = 0
			if not setupInstance(p) then
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
		elseif state.where ~= "heist" then
			if kind == "Toast" then
				hud.toast(tostring(p.text))
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
			if type(over) == "table" then
				lineup.play(over, function()
					hud.onOver(p)
				end, ageOf)
			else
				hud.onOver(p)
			end
		elseif kind == "Leader" then
			-- The crew leader left while the results card is up: the new one gets REPLAY / NEXT.
			local over = state.over
			if over and type(p.leader) == "number" then
				over.leader = p.leader
				hud.refreshResults()
			end
		elseif kind == "Toast" then
			hud.toast(tostring(p.text))
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
			return
		end
		local now = os.clock()
		local tView = viewTime()
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
		debug.profileend()
	end)
end

return HeistClient
