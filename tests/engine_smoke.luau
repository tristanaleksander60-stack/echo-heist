-- Engine smoke test: runs INSIDE a real Roblox server through Open Cloud
-- Luau Execution (tools/cloud_test.py), against the published place.
-- No real players exist there, so it drives the mechanisms with fake actors
-- (anchored parts) and checks the server-authoritative rules.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local results = {}
local failures = 0
local function check(cond: any, msg: string)
	if cond then
		table.insert(results, "ok    " .. msg)
	else
		failures += 1
		table.insert(results, "FAIL  " .. msg)
	end
end

-- 0. Boot the game server (Luau Execution sessions don't run place scripts).
local server = ServerScriptService:WaitForChild("Server")
require(server:WaitForChild("Main")).start()

-- 1. The server booted and built the level.
local level = workspace:WaitForChild("Level", 15)
check(level ~= nil, "Level built")
check(ReplicatedStorage:WaitForChild("Remotes", 5) ~= nil, "Remotes created")
check(workspace:FindFirstChild("Echoes") ~= nil, "Echoes folder created")
task.wait(2)
check((ReplicatedStorage:GetAttribute("LoopIndex") or 0) >= 1, "First loop started")
check(ReplicatedStorage:GetAttribute("Target") == 1000, "Heist target is $1000")

local Mechanisms = require(server:WaitForChild("Mechanisms"))
local Loot = require(server:WaitForChild("Loot"))
local Guard = require(server:WaitForChild("Guard"))

-- A fake actor: an anchored part standing in for an echo root.
local dummyModel = Instance.new("Model")
dummyModel.Name = "TestActor"
local root = Instance.new("Part")
root.Name = "HumanoidRootPart"
root.Anchored = true
root.CanCollide = false
root.Size = Vector3.new(2, 2, 1)
root.Parent = dummyModel
dummyModel.Parent = workspace
local fake =
	{ kind = "echo", model = dummyModel, root = root, owner = nil, carrying = nil, alive = true, immuneUntil = 0 }

local walls = level:WaitForChild("Walls")
local door = walls:WaitForChild("VaultDoor") :: BasePart
local plateA = level:WaitForChild("PlateA") :: BasePart
local plateB = level:WaitForChild("PlateB") :: BasePart
local now = workspace:GetServerTimeNow()

-- 2. Plate A opens the vault door, and it closes again after release.
Mechanisms.reset()
root.CFrame = plateA.CFrame + Vector3.new(0, 3, 0)
-- Check right after the tick: the game's own 10 Hz loop runs in parallel and
-- does not know this fake actor, so it closes the door again ~0.4 s later.
Mechanisms.tick({ fake }, now)
check(Mechanisms.isDoorOpen() and door.CanCollide == false, "Plate A opens vault door")
root.CFrame = CFrame.new(0, 3, 6)
Mechanisms.tick({ fake }, now + 1)
check(not Mechanisms.isDoorOpen() and door.CanCollide == true, "Door closes after plate A is released")

-- 3. Lasers zap an actor in the grid, but not while plate B is held.
root.CFrame = CFrame.new(114, 3, 0)
local zapped = Mechanisms.tick({ fake }, now + 2)
check(#zapped == 1, "Laser zaps actor in grid")
local holder = table.clone(fake)
local holderRoot = root:Clone()
holderRoot.CFrame = plateB.CFrame + Vector3.new(0, 3, 0)
holderRoot.Parent = dummyModel
holder.root = holderRoot
zapped = Mechanisms.tick({ fake, holder }, now + 3)
check(#zapped == 0, "Plate B disables lasers")
Mechanisms.reset()

-- 4. Loot: grab needs range, banking only from the van zone, no double-grab.
local goldPos = Loot.position("Gold1")
check(goldPos ~= nil, "Gold1 exists")
root.CFrame = CFrame.new(0, 3, 6)
check(Loot.grab(fake, "Gold1") == false, "Cannot grab loot from far away")
root.CFrame = CFrame.new(goldPos + Vector3.new(-3, 0, 0))
check(Loot.grab(fake, "Gold1") == true and fake.carrying == "Gold1", "Grab Gold1 in range")
check(Loot.grab(holder, "Gold1") == false, "Cannot grab loot someone else carries")
root.CFrame = CFrame.new(0, 3, -10)
check(Mechanisms.inDeliverZone(fake), "Van zone detects actor")
local banked = Loot.bank(fake)
check(banked == 100 and Loot.bankedValue() >= 100, "Banking Gold1 gives $100")
check(Loot.grab(fake, "Gold1") == false, "Banked loot cannot be grabbed again")
Loot.resetAll()
check(Loot.bankedValue() == 0, "Loot.resetAll clears banked loot")

-- 5. Guard: sees an actor in front of him in the open, not through a wall.
local guard = level:WaitForChild("Guard") :: Model
local groot = guard:WaitForChild("HumanoidRootPart") :: BasePart
root.CFrame = groot.CFrame * CFrame.new(0, 0, -10)
local seen = Guard.scan({ fake }, {})
check(#seen == 1, "Guard sees actor 10 studs in front")
root.CFrame = groot.CFrame * CFrame.new(0, 0, 10)
seen = Guard.scan({ fake }, {})
check(#seen == 0, "Guard does not see actor behind him")
local spawnPos = CFrame.new(0, 3, 6)
root.CFrame = spawnPos
seen = Guard.scan({ fake }, {})
check(#seen == 0, "Guard cannot see the hideout spawn")

dummyModel:Destroy()

-- 6. Data layer (docs/DATA.md). Luau Execution does not run place scripts, so boot it the
-- way init.server.luau does. DataStore calls here are REAL: the round trip runs only in
-- the test experience (Config.Data.TEST_UNIVERSE_IDS), only on a "_TEST_" key, and
-- removes the key again. No player profile is ever read or written.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local dataFolder = server:WaitForChild("Data")
local DataService = require(dataFolder:WaitForChild("DataService"))
local PlayerData = require(dataFolder:WaitForChild("PlayerData"))
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(sharedFolder:WaitForChild("Config"))
local dataShared = sharedFolder:WaitForChild("Data")
local Keys = require(dataShared:WaitForChild("Keys"))
local Schema = require(dataShared:WaitForChild("Schema"))

local inTestUniverse = Keys.isTestEnvironment(false, game.GameId)
local okStart, startErr = pcall(DataService.start)
check(okStart, "DataService starts" .. (if okStart then "" else ": " .. tostring(startErr)))
local env = DataService.environment()
check(env.isTest and env.keyPrefix == "_TEST_U_", "data uses _TEST_ keys here (prefix " .. env.keyPrefix .. ")")
check(inTestUniverse, "running in the test universe (GameId " .. tostring(game.GameId) .. ")")
local startDeadline = os.clock() + 10
while DataService.status() == "starting" and os.clock() < startDeadline do
	task.wait(0.1)
end
check(DataService.status() == "online", "data layer online (" .. DataService.status() .. ")")
local lfRemotes = ReplicatedStorage:FindFirstChild("LihFolkRemotes")
check(
	lfRemotes ~= nil
		and lfRemotes:FindFirstChild("Data.Snapshot") ~= nil
		and lfRemotes:FindFirstChild("Data.Buy") ~= nil
		and lfRemotes:FindFirstChild("Shop.PromptProduct") ~= nil,
	"data remotes created"
)

-- Library load rules in the real engine (pure; no DataStore).
local function makeData(): { [string]: any }
	return { Heist = Schema.defaultHeist() }
end
local fresh = PlayerData.prepare(nil, Schema.VERSION, Schema.MIGRATIONS, makeData)
check(
	fresh ~= nil
		and fresh.Data.Heist.unlocked[GameConfig.Data.LEVEL_ORDER[1]] == true
		and PlayerData.findUnsavable(fresh.Data) == nil,
	"new profile: v1 defaults, savable"
)
local _, newerReason = PlayerData.prepare({ Schema = Schema.VERSION + 1, Data = {} }, Schema.VERSION, {}, makeData)
check(newerReason == "newer", "a newer schema is refused")
local _, corruptReason = PlayerData.prepare("junk", Schema.VERSION, {}, makeData)
check(corruptReason == "corrupt", "a corrupt document is refused")
local old = PlayerData.prepare({ Schema = 1, Data = { Heist = { bagLevel = 2 } } }, Schema.VERSION, {}, makeData)
check(
	old ~= nil and old.Data.Heist.bagLevel == 2 and old.Data.Heist.settings.relaxed == false,
	"an older document is reconciled additively"
)

-- Real DataStore round trip on a throwaway _TEST_ key (test universe only).
if inTestUniverse then
	local key = GameConfig.Data.TEST_PREFIX .. "smoke_" .. HttpService:GenerateGUID(false)
	local okDs, dsErr = pcall(function()
		assert(Keys.isWritable(key, true), "refusing a non-test key")
		local store = DataStoreService:GetDataStore(GameConfig.Data.STORE_NAME)
		local token = HttpService:GenerateGUID(false)
		store:UpdateAsync(key, function()
			return { Schema = Schema.VERSION, Data = makeData(), Token = token }
		end)
		local options = Instance.new("DataStoreGetOptions")
		options.UseCache = false
		local value = store:GetAsync(key, options)
		check(type(value) == "table" and value.Token == token, "DataStore write + uncached read on a _TEST_ key")
		store:RemoveAsync(key)
	end)
	check(okDs, "DataStore round trip" .. (if okDs then "" else ": " .. tostring(dsErr)))
end

-- 7. Sim path (Config.GAME_MODE = "sim", src/server/Heist). Main.start() above runs the
-- v0.1 path, so the sim path boots through its own entry with no lobby and no player
-- wiring, then drives one L1 heist with a fake crew member on synthetic server times:
-- run 1 auto-ends on the plate (FTUE), run 2's clone holds the door while the fake
-- grabs the cash and banks it, and the heist completes. No real player is involved.
do
	local Players = game:GetService("Players")
	local heistServer = server:WaitForChild("Heist")
	local HeistService = require(heistServer:WaitForChild("HeistService"))
	local HeistInstance = require(heistServer:WaitForChild("HeistInstance"))
	local Avatars = require(heistServer:WaitForChild("Avatars"))
	local Sim = sharedFolder:WaitForChild("Sim")
	local HeistSim = require(Sim:WaitForChild("HeistSim"))
	local EventLog = require(Sim:WaitForChild("EventLog"))
	local Codec = require(sharedFolder:WaitForChild("Rec"):WaitForChild("Codec"))
	local EV = EventLog.EV
	local clientHeist = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Heist")

	local okHs, hsErr = pcall(HeistService.start, { lobby = false, players = false })
	check(okHs, "sim: HeistService starts" .. (if okHs then "" else ": " .. tostring(hsErr)))
	local lf = ReplicatedStorage:FindFirstChild("LihFolkRemotes")
	local missing = {}
	for _, name in { "Heist.EndRun", "Heist.Interact", "Heist.Deck", "Heist.Ready", "Heist.Sync", "Heist.Msg" } do
		if not (lf and lf:FindFirstChild(name)) then
			table.insert(missing, name)
		end
	end
	check(
		#missing == 0,
		"sim: Heist remotes created"
			.. (if #missing > 0 then " (missing " .. table.concat(missing, ", ") .. ")" else "")
	)

	local FAKE = -101
	local inst = HeistService.createInstance(1, {
		{ userId = FAKE, name = "Fake", fake = { x = 0, y = 3, z = 14, yaw = 0 } },
	}, FAKE, false)
	check(inst ~= nil, "sim: L1 instance created")
	if inst then
		local built = inst.built
		local origin = inst.origin
		check(
			workspace:FindFirstChild("Heists") ~= nil and inst.folder.Parent == workspace.Heists,
			"sim: instance folder in workspace.Heists"
		)
		check(
			#built.plates == 1 and #built.doors == 1 and #built.loot == 1 and #built.solids >= 7,
			string.format(
				"sim: L1 greybox from LevelSpec (%d solids, %d plate, %d door, %d loot)",
				#built.solids,
				#built.plates,
				#built.doors,
				#built.loot
			)
		)
		local platePos = built.plates[1].Position - origin
		check(
			math.abs(platePos.X - 10) < 0.01 and math.abs(platePos.Z + 8) < 0.01 and origin.X >= 3000,
			"sim: plate A at its level-space spot, instance offset 3000+ studs"
		)
		check(built.doors[1].CanCollide == true, "sim: door leaf built shut")

		-- Synthetic server time; a waypoint walker at 14 studs/s for the fake member.
		local simNow = 50000
		local fakeIn = inst.byId[FAKE].fake
		local function step(dt: number)
			simNow += dt
			HeistInstance.update(inst, simNow)
		end
		local function waitFor(seconds: number)
			for _ = 1, math.ceil(seconds / 0.05) do
				step(0.05)
			end
		end
		local function walkTo(x: number, z: number)
			local steps = 0
			while steps < 400 do
				steps += 1
				local dx, dz = x - fakeIn.x, z - fakeIn.z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < 0.05 then
					break
				end
				local s = math.min(d, 14 * 0.05)
				HeistInstance.setFakeInput(
					inst,
					FAKE,
					fakeIn.x + dx / d * s,
					3,
					fakeIn.z + dz / d * s,
					math.atan2(-dx, -dz)
				)
				step(0.05)
			end
		end

		-- Run 1 (FTUE): stand on the plate; the run auto-ends after 2 s there.
		step(0.05)
		check(inst.sim.phase == "Run" and inst.sim.runIndex == 1, "sim: run 1 started")
		waitFor(1.1) -- intro transition
		walkTo(0, 4)
		walkTo(10, -8)
		check(inst.folder:GetAttribute("P1Held") == true, "sim: plate A held (attribute)")
		check(inst.folder:GetAttribute("D1Open") == true, "sim: plate A opens the back-room door (attribute)")
		local waited = 0
		while inst.sim.phase == "Run" and waited < 3 do
			step(0.05)
			waited += 0.05
		end
		local deck = HeistSim.deckOf(inst.sim, FAKE)
		check(
			inst.sim.phase == "Between" and deck ~= nil and #deck.slots == 1,
			string.format("sim: L1 run 1 auto-ended on the plate after %.2f s; one clone in the deck", waited)
		)
		local key = deck and inst.recKeys[deck.slots[1].rec]
		local buf = key and inst.recBufs[key]
		local decoded = buf and Codec.decode(buf)
		check(decoded ~= nil and decoded.n > 20, "sim: the new recording encodes and decodes (Codec buffer)")

		-- Run 2: the clone walks to the plate and holds the door; grab the cash, bank it.
		waitFor(0.5) -- L1 starts the next run by itself
		check(inst.sim.phase == "Run" and inst.sim.runIndex == 2, "sim: run 2 started by itself (L1)")
		waitFor(1.1) -- quick rewind
		walkTo(0, 4)
		waitFor(1.0)
		check(
			inst.sim.actors[1] ~= nil
				and inst.sim.actors[1].kind == "clone"
				and inst.folder:GetAttribute("D1Open") == true,
			"sim: run 2 clone holds plate A, door open"
		)
		-- Client views on the real engine (they normally run on clients): the clone rig
		-- posed from its decoded recording, the door drawn from the state attributes.
		local okView, clonePos, doorCollides = pcall(function()
			local EchoView = require(clientHeist:WaitForChild("EchoView"))
			local WorldView = require(clientHeist:WaitForChild("WorldView"))
			local msg = table.clone(inst.runMsg)
			msg.actorById = {}
			for _, a in msg.actors do
				msg.actorById[a.id] = a
			end
			local recs = {}
			for _, k in msg.keys do
				recs[k] = Codec.decode(inst.recBufs[k])
			end
			local vstate = {
				origin = inst.origin,
				folder = inst.folder,
				level = inst.level,
				levelIndex = 1,
				crew = { { userId = FAKE, seat = 1 } },
				actorFx = {},
				run = msg,
			}
			local echo = EchoView.new(vstate)
			echo.setRun(msg, recs, os.clock() - 1)
			echo.update(inst.sim.t, os.clock(), 1 / 60, nil)
			local p = echo.positionOf(1)
			local view = WorldView.new(vstate, echo.positionOf)
			view.bind(inst.built.model)
			for _ = 1, 30 do
				view.update(inst.sim.t, os.clock(), 1 / 30)
			end
			echo.clear()
			local clones = workspace:FindFirstChild("HeistClones")
			if clones then
				clones:Destroy()
			end
			return p, inst.built.doors[1].CanCollide
		end)
		local want = origin + Vector3.new(10, 3, -8)
		check(
			okView and typeof(clonePos) == "Vector3" and (clonePos - want).Magnitude < 2,
			"sim: EchoView poses the clone on plate A ("
				.. (if okView then tostring(clonePos) else tostring(clonePos))
				.. ")"
		)
		check(okView and doorCollides == false, "sim: WorldView opens the door locally (no collision)")
		walkTo(0, -16)
		walkTo(0, -26)
		HeistInstance.interact(inst, FAKE, Codec.EVENT.Grab, 1)
		step(0.05)
		step(0.05)
		check(inst.folder:GetAttribute("K1State") == "Carried", "sim: cash grabbed through Interact (attribute)")
		walkTo(0, -16)
		walkTo(0, 4)
		walkTo(0, 19)
		waitFor(0.2)
		local result = HeistSim.result(inst.sim)
		check(
			inst.sim.phase == "Over" and result.complete == true and result.banked == 100,
			string.format("sim: L1 complete, $%d banked in %d runs", result.banked, result.runs)
		)
		check(
			inst.folder:GetAttribute("Banked") == 100 and inst.overMsg ~= nil and inst.overMsg.complete == true,
			"sim: results ready (Banked attribute, results card payload)"
		)
		check(
			result.data.tainted == false and EventLog.count(inst.sim.log, EV.Bank) == 1,
			"sim: untainted run, one Bank event"
		)
		if failures > 0 then
			for _, line in EventLog.lines(inst.sim.log) do
				table.insert(results, "      log " .. line)
			end
		end
		local sync = HeistInstance.syncFor(inst, FAKE)
		check(sync.where == "heist" and sync.levelIndex == 1 and sync.over ~= nil, "sim: late-join sync payload")
		local folder = inst.folder
		HeistService.destroyInstance(inst)
		check(folder.Parent == nil, "sim: instance destroyed")
	end

	-- L4 builds too (guard level) and its sim steps with a fake member standing still.
	local inst4 = HeistService.createInstance(
		4,
		{ { userId = -104, name = "Fake4", fake = { x = 0, y = 3, z = 14, yaw = 0 } } },
		-104,
		false
	)
	if inst4 then
		local now4 = 70000
		for _ = 1, 60 do
			now4 += 0.05
			HeistInstance.update(inst4, now4)
		end
		check(
			inst4.sim.phase == "Run" and inst4.sim.tick > 0 and inst4.folder:GetAttribute("G1Mode") ~= nil,
			"sim: L4 builds, Gus patrols (guard attributes)"
		)
		local okGus, gusDist = pcall(function()
			local GusView = require(clientHeist:WaitForChild("GusView"))
			local gstate = {
				origin = inst4.origin,
				folder = inst4.folder,
				level = inst4.level,
				crew = { { userId = -104, seat = 1 } },
			}
			local gus = GusView.new(gstate)
			gus.setLevel(inst4.level)
			for _ = 1, 3 do
				gus.update(inst4.sim.t, os.clock(), 1 / 30)
			end
			local gx, gz = gus.poseOf(1)
			local g = inst4.sim.guards[1]
			gus.clear()
			local f = workspace:FindFirstChild("HeistGus")
			if f then
				f:Destroy()
			end
			return math.sqrt((gx - g.x) ^ 2 + (gz - g.z) ^ 2)
		end)
		check(
			okGus and type(gusDist) == "number" and gusDist < 0.5,
			"sim: GusView draws Gus where the sim has him, cone built (" .. tostring(gusDist) .. ")"
		)
		HeistService.destroyInstance(inst4)
	else
		check(false, "sim: L4 instance created")
	end

	-- Clone template stripping on a real engine rig (§6.5 #2).
	local okRig, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			Instance.new("HumanoidDescription"),
			Enum.HumanoidRigType.R15
		)
	end)
	if okRig and rig then
		Avatars.strip(rig)
		local bad = 0
		for _, d in rig:GetDescendants() do
			local leftover = d:IsA("Decal") or d:IsA("SurfaceAppearance") or d:IsA("Shirt") or d:IsA("Pants")
			if leftover or (d:IsA("BasePart") and (d.CanCollide or d.CastShadow)) then
				bad += 1
			end
		end
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local rootPart = rig:FindFirstChild("HumanoidRootPart")
		check(
			bad == 0
				and hum ~= nil
				and hum.EvaluateStateMachine == false
				and hum:FindFirstChildOfClass("Animator") ~= nil
				and rootPart ~= nil
				and (rootPart :: BasePart).Anchored,
			"sim: clone template stripped (" .. bad .. " leftovers)"
		)
		rig:Destroy()
	else
		check(false, "sim: CreateHumanoidModelFromDescriptionAsync: " .. tostring(rig))
	end

	-- The client view modules load in the engine (they run only on clients in play).
	local loadErrors = {}
	for _, name in { "Ui", "Rigs", "EchoView", "GusView", "WorldView", "RewindDirector", "Hud", "HeistClient" } do
		local ok, err = pcall(require, clientHeist:WaitForChild(name))
		if not ok then
			table.insert(loadErrors, name .. ": " .. tostring(err))
		end
	end
	check(
		#loadErrors == 0,
		"sim: client modules load" .. (if #loadErrors > 0 then " (" .. table.concat(loadErrors, "; ") .. ")" else "")
	)
end

table.insert(results, string.format("%d failure(s)", failures))
return table.concat(results, "\n")
