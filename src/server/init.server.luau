-- Echo Heist server: builds the level and runs the heist loop.
--
-- Loop flow: startLoop -> (players act, echoes replay) -> endLoop (timer or
-- everyone pressed Rewind) -> recordings saved -> startLoop with one more
-- echo per player. Banked loot survives loops; when it reaches the target
-- the heist is complete and everything resets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local LevelBuilder = require(script:WaitForChild("LevelBuilder"))
local Actors = require(script:WaitForChild("Actors"))
local Loot = require(script:WaitForChild("Loot"))
local Mechanisms = require(script:WaitForChild("Mechanisms"))
local Guard = require(script:WaitForChild("Guard"))
local Echoes = require(script:WaitForChild("Echoes"))

-- Remotes ---------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local notify = Instance.new("RemoteEvent")
notify.Name = "Notify" -- server -> client: { type = string, ... }
notify.Parent = remotes
local requestRewind = Instance.new("RemoteEvent")
requestRewind.Name = "RequestRewind" -- client -> server, no arguments
requestRewind.Parent = remotes
remotes.Parent = ReplicatedStorage

-- Setup -----------------------------------------------------------------
local level = LevelBuilder.build()
Loot.init(level.folder, level.lootSpots)
Mechanisms.init(level)
Guard.init(level)
Echoes.init()

local function now(): number
	return workspace:GetServerTimeNow()
end

local state = {
	loopIndex = 0,
	loopStart = 0,
	loopEndsAt = 0,
	transitioning = true,
	heistDone = false,
	votes = {} :: { [Player]: boolean },
	lastVote = {} :: { [Player]: number },
}

local function loopTime(): number
	return now() - state.loopStart
end

local function publish()
	ReplicatedStorage:SetAttribute("LoopIndex", state.loopIndex)
	ReplicatedStorage:SetAttribute("LoopEndsAt", state.loopEndsAt)
	ReplicatedStorage:SetAttribute("Banked", Loot.bankedValue())
	ReplicatedStorage:SetAttribute("Target", Loot.totalValue())
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Echoes", Echoes.count(p))
	end
end

local function spawnOffset(i: number): CFrame
	local col = (i - 1) % 4
	local row = math.floor((i - 1) / 4)
	return level.spawnCFrame * CFrame.new((col - 1.5) * 3, 0, row * 3)
end

local function sendHome(player: Player, i: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(spawnOffset(i))
	end
end

-- Caught / zapped --------------------------------------------------------
local function handleCaught(actor: any, reason: string)
	if not actor.alive then
		return
	end
	if actor.kind == "echo" then
		Loot.drop(actor)
		Actors.removeEcho(actor)
		notify:FireAllClients({ type = "echoBusted", reason = reason, owner = actor.owner.Name })
		return
	end
	if now() < actor.immuneUntil then
		return
	end
	actor.immuneUntil = now() + Config.CAUGHT_IMMUNITY
	Loot.drop(actor)
	Echoes.recordEvent(actor.owner, loopTime(), "vanish")
	local idx = table.find(Players:GetPlayers(), actor.owner) or 1
	sendHome(actor.owner, idx)
	notify:FireClient(actor.owner, { type = "caught", reason = reason })
	publish()
end

-- Interactions (players trigger prompts; echoes replay the same events) -----
local function tryGrab(actor: any, lootId: string): boolean
	return Loot.grab(actor, lootId)
end

Loot.onPromptTriggered = function(player: Player, lootId: string)
	if state.transitioning then
		return
	end
	local actor = Actors.forPlayer(player)
	if actor and tryGrab(actor, lootId) then
		Echoes.recordEvent(player, loopTime(), "grab", lootId)
	end
end

Echoes.onEvent = function(actor: any, event: any)
	if event.kind == "grab" and event.data then
		tryGrab(actor, event.data)
	elseif event.kind == "vanish" then
		Loot.drop(actor)
		Actors.removeEcho(actor)
	end
end

-- Loop control -----------------------------------------------------------
local startLoop: () -> ()

local function completeHeist()
	state.heistDone = true
	state.transitioning = true
	for _, p in Players:GetPlayers() do
		Echoes.finishRecording(p)
	end
	notify:FireAllClients({ type = "complete", value = Loot.bankedValue(), loops = state.loopIndex })
	task.delay(Config.HEIST_RESET_DELAY, function()
		Echoes.clearAll()
		Loot.resetAll()
		state.loopIndex = 0
		state.heistDone = false
		startLoop()
	end)
end

local function endLoop(reason: string)
	if state.transitioning then
		return
	end
	state.transitioning = true
	for _, p in Players:GetPlayers() do
		Echoes.finishRecording(p)
	end
	-- Return carried loot first: destroying an echo leaves its welded loot falling.
	Loot.resetUnbanked()
	Echoes.despawnAll()
	notify:FireAllClients({ type = "rewind", reason = reason })
	task.delay(0.9, startLoop)
end

startLoop = function()
	state.loopIndex += 1
	state.loopStart = now()
	state.loopEndsAt = state.loopStart + Config.LOOP_SECONDS
	table.clear(state.votes)

	Mechanisms.reset()
	Guard.reset()
	Loot.resetUnbanked()
	for i, p in Players:GetPlayers() do
		local a = Actors.forPlayer(p)
		if a then
			a.carrying = nil
		end
		sendHome(p, i)
	end
	local echoCount = Echoes.spawnAll()
	for _, p in Players:GetPlayers() do
		Echoes.startRecording(p)
	end
	state.transitioning = false
	publish()
	notify:FireAllClients({ type = "loop", index = state.loopIndex, echoes = echoCount })
end

-- Rewind votes -------------------------------------------------------------
requestRewind.OnServerEvent:Connect(function(player: Player)
	if state.transitioning then
		return
	end
	local t = now()
	if t - (state.lastVote[player] or 0) < Config.REWIND_COOLDOWN then
		return
	end
	state.lastVote[player] = t
	if loopTime() < Config.MIN_LOOP_SECONDS then
		return
	end
	state.votes[player] = true
	local n, total = 0, 0
	for _, p in Players:GetPlayers() do
		total += 1
		if state.votes[p] then
			n += 1
		end
	end
	if n >= total then
		endLoop("vote")
	else
		notify:FireAllClients({ type = "votes", n = n, total = total })
	end
end)

-- Players --------------------------------------------------------------------
local function onCharacter(player: Player, character: Model)
	local actor = Actors.setPlayerCharacter(player, character)
	local hum = character:WaitForChild("Humanoid", 10)
	if actor and hum and hum:IsA("Humanoid") then
		hum.Died:Connect(function()
			Loot.drop(actor)
			actor.alive = false
			-- The echo stops here instead of gliding to the respawn point.
			Echoes.recordEvent(player, loopTime(), "vanish")
		end)
	end
end

local function setupPlayer(player: Player)
	task.spawn(Echoes.prepareTemplate, player)
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	if not state.transitioning then
		Echoes.startRecording(player)
	end
	publish()
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in Players:GetPlayers() do
	setupPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	local a = Actors.forPlayer(player)
	if a then
		Loot.drop(a)
	end
	-- Their echoes are destroyed below; return what they carry first.
	for _, e in Actors.all() do
		if e.kind == "echo" and e.owner == player then
			Loot.drop(e)
		end
	end
	Actors.removePlayer(player)
	Echoes.clearPlayer(player)
	state.votes[player] = nil
	state.lastVote[player] = nil
	-- Everyone still here may already have voted.
	if not state.transitioning then
		local n, total = 0, 0
		for _, p in Players:GetPlayers() do
			if p ~= player then
				total += 1
				if state.votes[p] then
					n += 1
				end
			end
		end
		if n > 0 and n >= total then
			endLoop("vote")
		end
	end
end)

-- Main loops -------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	if not state.transitioning then
		Echoes.step(loopTime(), dt)
	end
end)

-- Recording sampler
task.spawn(function()
	while true do
		task.wait(1 / Config.RECORD_HZ)
		if not state.transitioning then
			local t = loopTime()
			for _, p in Players:GetPlayers() do
				local a = Actors.forPlayer(p)
				if a then
					Echoes.recordFrame(p, t, a.root.CFrame)
				end
			end
		end
	end
end)

-- Game logic tick: plates, lasers, guard, delivery, timer
task.spawn(function()
	local guardAccum = 0
	while true do
		local dt = task.wait(0.1)
		if not state.transitioning then
			local actors = Actors.all()
			for _, a in Mechanisms.tick(actors, now()) do
				handleCaught(a, "laser")
			end

			guardAccum += dt
			if guardAccum >= 1 / Config.GUARD_SCAN_HZ then
				guardAccum = 0
				local exclude = Actors.models()
				table.insert(exclude, Loot.models())
				-- Never fall back to excluding workspace: the guard would see through walls.
				local echoFolder = workspace:FindFirstChild("Echoes")
				if echoFolder then
					table.insert(exclude, echoFolder)
				end
				local seen = Guard.scan(Actors.all(), exclude)
				if #seen > 0 then
					Guard.alert()
				end
				for _, a in seen do
					handleCaught(a, "guard")
				end
			end

			for _, a in Actors.all() do
				if a.carrying and a.root.Position.Y < -50 then
					-- Fell off the map: return the loot before the fall height destroys it.
					Loot.drop(a)
				elseif a.carrying and Mechanisms.inDeliverZone(a) then
					local value = Loot.bank(a)
					if value > 0 then
						notify:FireAllClients({ type = "banked", value = value, by = a.kind, owner = a.owner.Name })
						publish()
					end
				end
			end

			if not state.heistDone and Loot.bankedValue() >= Loot.totalValue() then
				completeHeist()
			elseif now() >= state.loopEndsAt then
				endLoop("time")
			end
		end
	end
end)

-- Give the first player a moment to load, then start.
task.wait(1)
startLoop()
