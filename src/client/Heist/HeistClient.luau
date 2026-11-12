--!strict
-- Heist/HeistClient: the sim path's client (Config.GAME_MODE = "sim"). MASTERPLAN
-- §8.2 ("clients receive each recording once and render local rigs from the loop
-- clock"), §6.5, §7.1, §7.4, §7.5.
--
-- It keeps one state table fed by the server's Heist.Msg push (and Heist.Sync at
-- boot), and once per frame samples the replicated LoopClock and draws:
--   EchoView (clones from Rec/Sampler), GusView (Guards.patrol + pose attributes),
--   WorldView (doors/lasers/plates/loot from attributes), RewindDirector, Hud.
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
local Catalog = require(Shared:WaitForChild("Levels"):WaitForChild("Catalog"))
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))

local Heist = script.Parent
local EchoView = require(Heist:WaitForChild("EchoView"))
local GusView = require(Heist:WaitForChild("GusView"))
local WorldView = require(Heist:WaitForChild("WorldView"))
local RewindDirector = require(Heist:WaitForChild("RewindDirector"))
local Hud = require(Heist:WaitForChild("Hud"))

local EV = EventLog.EV
local R = Protocol.REMOTE
local localPlayer = Players.LocalPlayer

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
		origin = Vector3.zero,
		crew = {},
		mySeat = 1,
		recs = {},
		run = nil,
		clock = nil,
		phase = "",
		frozenT = 0,
		lastRunT = 0,
		deck = nil,
		over = nil,
		actorFx = {},
		carrying = false,
		liveCount = 1,
		reduced = GuiService.ReducedMotionEnabled,
	}
	GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"):Connect(function()
		state.reduced = GuiService.ReducedMotionEnabled
	end)

	local levelCache: { [number]: any } = {}
	local function levelFor(index: number): any
		local cached = levelCache[index]
		if not cached and Catalog[index] then
			cached = LevelSpec.compile(Catalog[index])
			levelCache[index] = cached
		end
		return cached
	end

	local echo = EchoView.new(state)
	local gus = GusView.new(state)
	local world = WorldView.new(state, echo.positionOf)
	local ffOn = false

	local actions = {
		endRun = function()
			RewindDirector.sound("Clack")
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
		joinFriend = function(userId: number)
			Net.Send(R.JoinFriend, userId)
		end,
		leave = function()
			Net.Send(R.Leave)
		end,
	}
	local hud = Hud.new(state, actions)
	local director = RewindDirector.new(hud.fxGui)
	hud.bigStamp = function(text: string, color: Color3)
		director.stamp(text, color, 1.2)
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
		if e.kind == EV.Busted then
			local fx = actorFx(e.b)
			fx.gone = "Busted"
			fx.goneAtLocal = if live then now else -math.huge
			if live then
				echo.effect(e.b, "Busted", now)
				gus.bang(e.a, now)
				RewindDirector.sound("Busted")
			end
		elseif e.kind == EV.Zap then
			local run = state.run
			local a = run and run.actorById[e.a]
			if a and a.kind == "clone" then
				local fx = actorFx(e.a)
				fx.gone = "Zapped"
				fx.goneAtLocal = if live then now else -math.huge
			end
			if live then
				echo.effect(e.a, "Zapped", now)
				RewindDirector.sound("Zap")
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
				RewindDirector.sound("Busted")
			end
		elseif e.kind == EV.Bank then
			if live then
				RewindDirector.sound("KaChing")
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
		local liveCount = 0
		for _, a in msg.actors do
			byId[a.id] = a
			if a.kind == "live" then
				liveCount += 1
			end
		end
		msg.actorById = byId
		state.liveCount = liveCount
		local transition = if live then (msg.transition or 0) else 0
		local reelEnd = state.lastRunT
		echo.setRun(msg, state.recs, os.clock() + transition * 0.75)
		hud.onRun(msg)
		if live then
			local kind = msg.kind or "Standard"
			if state.reduced and kind ~= "Intro" then
				kind = "Reduced"
			end
			director.play(kind, transition, msg.run, function(u: number)
				state.reelT = reelEnd * (1 - u)
			end, function()
				state.reelT = nil
			end)
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
		state.folder = folder
		state.levelIndex = p.levelIndex
		state.level = levelFor(p.levelIndex)
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
		end
		if state.level then
			gus.setLevel(state.level)
		end
		return true
	end

	local function toGarage(p: any)
		state.where = "garage"
		state.garage = p
		state.folder = nil
		state.run = nil
		state.clock = nil
		state.phase = ""
		state.deck = nil
		state.lastRunT = 0
		table.clear(state.recs)
		echo.clear()
		gus.clear()
		world.clear()
		director.stop()
		hud.hideAll()
		hud.showGarage()
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
			if p.where ~= "heist" then
				return
			end
			hud.hideGarage()
			table.clear(state.recs)
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
			state.phase = "Between"
			ffOn = false
			hud.onRunEnd(p)
		elseif kind == "Deck" then
			state.deck = p
			hud.onDeck()
			if state.phase == "Between" then
				hud.showBetween()
			end
		elseif kind == "Over" then
			state.phase = "Over"
			hud.onOver(p)
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
		echo.update(tView, now, dt, state.reelT)
		gus.update(tView, now, dt)
		world.update(tView, now, dt)
		hud.update(tView, now, dt, world)
	end)
end

return HeistClient
