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
			math.abs(platePos.X - 10) < 0.01 and math.abs(platePos.Z + 8) < 0.01 and origin.Magnitude >= 2999,
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
	-- Catalog indices are the PLAY order (Clone Party is third): look levels up by id.
	local l4Index = HeistService.indexOf("cs4_night_clerk")
	check(l4Index ~= nil, "sim: L4 (cs4_night_clerk) is in the Catalog (index " .. tostring(l4Index) .. ")")
	local inst4 = l4Index
		and HeistService.createInstance(
			l4Index,
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

	local Config = GameConfig :: any
	local Protocol = require(sharedFolder:WaitForChild("Heist"):WaitForChild("Protocol"))
	local DailyVault = require(dataShared:WaitForChild("DailyVault"))
	local Calendar = require(dataShared:WaitForChild("Calendar"))

	-- A fake member walker on synthetic server time, for any instance.
	local function driver(target: any, userId: number, startNow: number)
		local d = { now = startNow }
		local fakeIn = target.byId[userId].fake
		function d.step(dt: number)
			d.now += dt
			HeistInstance.update(target, d.now)
		end
		function d.wait(seconds: number)
			for _ = 1, math.ceil(seconds / 0.05) do
				d.step(0.05)
			end
		end
		function d.walk(x: number, z: number)
			local n = 0
			while n < 600 do
				n += 1
				local dx, dz = x - fakeIn.x, z - fakeIn.z
				local dist = math.sqrt(dx * dx + dz * dz)
				if dist < 0.05 then
					break
				end
				local s = math.min(dist, 14 * 0.05)
				HeistInstance.setFakeInput(target, userId, fakeIn.x + dx / dist * s, 3, fakeIn.z + dz / dist * s)
				d.step(0.05)
			end
		end
		return d
	end
	local function hasEvent(target: any, kind: number, c: number?): boolean
		local log = target.sim.log
		for i = 1, log.n do
			if log.kind[i] == kind and (c == nil or log.c[i] == c) then
				return true
			end
		end
		return false
	end

	-- L5 Clone Party: the till is time-locked until 0:20 (Interact.FAIL.Locked, streamed as a
	-- Rejected event), then robbing it trips the Alarm Run (AlarmOn / AlarmBy / AlarmVanAt).
	local l5Index = HeistService.indexOf("cs5_clone_party")
	check(l5Index == 3, "sim: Clone Party is played third (party break), index " .. tostring(l5Index))
	local inst5 = l5Index
		and HeistService.createInstance(
			l5Index,
			{ { userId = -105, name = "Fake5", fake = { x = 0, y = 3, z = 14, yaw = 0 } } },
			-105,
			false
		)
	if inst5 then
		local d = driver(inst5, -105, 80000)
		d.step(0.05)
		d.wait(1.1)
		check(inst5.folder:GetAttribute("K1OpensAt") == 20, "sim: L5 till carries its opensAt (K1OpensAt = 20)")
		d.walk(0, 4)
		d.walk(-5.5, -1)
		HeistInstance.interact(inst5, -105, Codec.EVENT.Grab, 1)
		d.step(0.05)
		d.step(0.05)
		check(
			hasEvent(inst5, EV.Rejected, HeistSim.FAIL.Locked) and inst5.folder:GetAttribute("K1State") == "Home",
			string.format("sim: L5 till refuses an early grab as Locked (t = %.1f s)", inst5.sim.t)
		)
		while inst5.sim.phase == "Run" and inst5.sim.t < 20.2 do
			d.step(0.05)
		end
		HeistInstance.interact(inst5, -105, Codec.EVENT.Grab, 1)
		d.step(0.05)
		d.step(0.05)
		check(
			inst5.folder:GetAttribute("K1State") == "Carried"
				and inst5.folder:GetAttribute("AlarmOn") == true
				and (inst5.folder:GetAttribute("AlarmBy") or 0) > 0
				and (inst5.folder:GetAttribute("AlarmVanAt") or 0) > 20,
			"sim: robbing the till after 0:20 trips the Alarm Run (AlarmOn, AlarmBy, AlarmVanAt)"
		)
		local lockAt = inst5.folder:GetAttribute("AlarmLockAt") or -1
		check(
			math.abs(lockAt - (inst5.sim.alarm.t0 + Config.Levels.PARTY_SHUTTER_SECONDS)) < 0.02,
			string.format("sim: the shutter drop time is replicated (AlarmLockAt %.2f)", lockAt)
		)
		local waited = 0
		while inst5.sim.phase == "Run" and waited < 15 do
			d.step(0.05)
			waited += 0.05
		end
		local lastAlarm = inst5.sim.lastRun and inst5.sim.lastRun.alarm
		check(
			inst5.sim.phase ~= "Run" and lastAlarm ~= nil and lastAlarm.kind == "live" and inst5.alarmHint == nil,
			"sim: the run's alarm summary names the live robber (no Redo hint for a live run)"
		)
		HeistService.destroyInstance(inst5)
	else
		check(false, "sim: L5 instance created")
	end

	-- Daily vault: today's vault (Levels/DailyVaults) starts as levelIndex 0, plays to Dawn and
	-- hands DataService.awardDailyVault the sim's result().daily (timeMs included). The fake
	-- member gets a stand-in player for the award hook only; DataService answers NotReady
	-- (no profile), so nothing is saved: the path is offline-safe.
	local today = Calendar.dayIndex(os.time(), Config.Data.Daily.RESET_OFFSET_HOURS)
	local daily = HeistService.dailyFor(today)
	check(
		daily ~= nil and daily.mode == "today",
		"sim: today's daily vault is playable (slot " .. tostring(daily and daily.slot) .. ")"
	)
	local instD = daily
		and HeistService.createInstance(Protocol.DAILY_INDEX, {
			{ userId = -106, name = "FakeD", fake = { x = 0, y = 3, z = 14, yaw = 0 } },
		}, -106, false, { daily = daily })
	if instD then
		local spec = Protocol.levelSpec(Protocol.DAILY_INDEX, today)
		check(
			instD.folder:GetAttribute("Daily") == today
				and instD.folder:GetAttribute("Kind") == "daily"
				and instD.folder:GetAttribute("LevelId") == spec.id,
			"sim: daily vault instance (" .. tostring(spec.id) .. ", " .. tostring(daily.modifier) .. ")"
		)
		local stand = { Name = "StandIn" }
		local captured: any = nil
		local realAward = instD.awardDaily
		instD.push = nil
		instD.byId[-106].player = stand :: any
		instD.awardDaily = function(p: any, day: number, result: any)
			captured = { player = p, day = day, result = result }
			return realAward(p, day, result)
		end
		local d = driver(instD, -106, 90000)
		local steps = 0
		while instD.sim.phase ~= "Over" and steps < 4000 do
			steps += 1
			if instD.sim.phase == "Run" and instD.sim.t > 1.6 then
				HeistInstance.endRun(instD, -106)
			elseif instD.sim.phase == "Between" then
				HeistInstance.ready(instD, -106, true)
			end
			d.step(0.05)
		end
		local over = instD.overMsg
		check(
			instD.sim.phase == "Over" and over ~= nil and over.kind == "daily" and over.reason == "Dawn",
			string.format("sim: daily vault ends at Dawn after %d runs (results card kind daily)", instD.sim.runIndex)
		)
		local valid = captured ~= nil and DailyVault.validateResult(captured.result)
		check(
			captured ~= nil and captured.day == today and valid and type(captured.result.timeMs) == "number",
			"sim: awardDailyVault gets today's day and a valid DailyResult with timeMs"
		)
		local payload = HeistInstance.awardPayload(instD, -106)
		check(payload ~= nil and payload.kind == "daily", "sim: award payload is the daily kind")
		local okOffline, offline = pcall(DataService.awardDailyVault, stand :: any, today, payload and payload.result)
		check(
			okOffline and type(offline) == "table" and offline.ok == false and offline.code == "NotReady",
			"sim: awardDailyVault without a profile is a clean NotReady (" .. tostring(offline and offline.code) .. ")"
		)
		HeistService.destroyInstance(instD)
	else
		check(false, "sim: daily vault instance created")
	end

	-- Analytics + LiveFlags start without errors (no players here, so no player events).
	local analyticsFolder = server:WaitForChild("Analytics")
	local okA, Analytics = pcall(require, analyticsFolder:WaitForChild("Analytics"))
	local okStartA, startErrA = false, nil
	if okA then
		okStartA, startErrA = pcall(Analytics.start, {
			dataService = DataService,
			playerData = PlayerData,
			currency = require(dataFolder:WaitForChild("Currency")),
			receipts = require(dataFolder:WaitForChild("Receipts")),
			shop = require(dataFolder:WaitForChild("Shop")),
			heistService = HeistService,
		})
		HeistService.configureAnalytics(Analytics)
	end
	check(
		okA and okStartA,
		"analytics: Analytics.start runs" .. (if okStartA then "" else ": " .. tostring(startErrA or Analytics))
	)
	if okA then
		check(
			Analytics.environment() == (if inTestUniverse then "test" else "live"),
			"analytics: environment " .. tostring(Analytics.environment())
		)
		local LiveFlags = require(analyticsFolder:WaitForChild("LiveFlags"))
		local snap = LiveFlags.snapshot()
		check(type(snap) == "table" and snap.values.dailyVault ~= nil, "analytics: LiveFlags loaded (dailyVault flag)")
		local lfr = ReplicatedStorage:FindFirstChild("LihFolkRemotes")
		local missingA = {}
		for _, name in { "Analytics.Ready", "Analytics.Perf", "Analytics.Ui", "Heist.SelectDaily" } do
			if not (lfr and lfr:FindFirstChild(name)) then
				table.insert(missingA, name)
			end
		end
		check(#missingA == 0, "analytics: client remotes created (" .. table.concat(missingA, ", ") .. ")")
		local tuning = HeistService.tuning()
		check(
			tuning.alarmRun == true and tuning.crewCloneBudget == Config.Sim.CREW_CLONE_BUDGET,
			"liveflags: heist tuning reads the defaults (" .. tostring(tuning.crewCloneBudget) .. ")"
		)
	end

	-- Art kit (spike S2, automated path): KitService loads the uploaded kit, and a level built
	-- after it is ready is dressed with kit pieces while its collision stays the sim's boxes.
	local okKitReq, KitService = pcall(require, server:WaitForChild("Kit"):WaitForChild("KitService"))
	check(okKitReq, "kit: KitService loads" .. (if okKitReq then "" else ": " .. tostring(KitService)))
	if okKitReq then
		KitService.start()
		local kitOk = KitService.ready(45)
		local kitReady = KitService.isReady()
		table.insert(results, "      kit " .. KitService.summary() .. (if kitOk then "" else " (report not ok)"))
		HeistService.configureKit(KitService)
		local l2Index = HeistService.indexOf("cs2_two_doors") :: number
		local instK = HeistService.createInstance(l2Index, {
			{ userId = -107, name = "FakeK", fake = { x = 0, y = 3, z = 14, yaw = 0 } },
		}, -107, false)
		if instK and kitReady and not kitOk then
			-- A partial kit (missing pieces, size errors) keeps every level greybox (KitDresser).
			check(instK.folder:GetAttribute("Kit") == false, "kit: incomplete kit, level stays greybox (Kit = false)")
			check(false, "kit: KitService report ok (" .. KitService.summary() .. ")")
			HeistService.destroyInstance(instK)
		elseif instK and kitReady then
			local built = instK.built
			local pieces = 0
			for _, dsc in built.model:GetDescendants() do
				if dsc:IsA("MeshPart") and dsc:GetAttribute("KitPiece") then
					pieces += 1
				end
			end
			check(
				instK.folder:GetAttribute("Kit") == true and pieces >= 40,
				string.format(
					"kit: L2 dressed with %d kit pieces (%s)",
					pieces,
					tostring(built.kitResult and built.kitResult.why)
				)
			)
			local solidsOk, hidden = true, 0
			for i, sdef in instK.level.spec.solids do
				local part = built.solids[i]
				local b = sdef.box
				local want = Vector3.new(b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ)
				if not (part and part.CanCollide and (part.Size - want).Magnitude < 0.01) then
					solidsOk = false
				end
				if part and part.Transparency == 1 then
					hidden += 1
				end
			end
			check(
				solidsOk and hidden >= 8,
				string.format("kit: every sim solid is still its exact collider (%d hidden under kit)", hidden)
			)
			local leaf = built.doors[1]
			local db = instK.level.doors[1].box
			check(
				leaf:IsA("MeshPart")
					and leaf:GetAttribute("EH_Kind") == "door"
					and leaf.CanCollide
					and math.abs(leaf.Size.X - (db.maxX - db.minX)) < 0.01
					and math.abs(leaf.Size.Y - (db.maxY - db.minY)) < 0.01
					and math.abs(leaf.Size.Z - (db.maxZ - db.minZ)) < 0.01
					and leaf.CollisionFidelity == Enum.CollisionFidelity.Box,
				"kit: door leaf is a kit MeshPart sized to the sim door box (Box collision)"
			)
			-- Gameplay unchanged: plate A still opens the back room through the attributes.
			local d = driver(instK, -107, 100000)
			d.step(0.05)
			d.wait(1.1)
			d.walk(0, 4)
			d.walk(-10, -8)
			check(
				instK.folder:GetAttribute("P1Held") == true and instK.folder:GetAttribute("D1Open") == true,
				"kit: plate A opens the back-room door on the kit-built level"
			)
			HeistService.destroyInstance(instK)
			-- The Christmas layer and the Bank pieces (vault frame + swing skin) build too.
			local LevelBuilder = require(heistServer:WaitForChild("LevelBuilder"))
			local l6 = HeistInstance.levelData(HeistService.indexOf("bk1_big_score") :: number)
			local scratch = Instance.new("Folder")
			scratch.Name = "KitScratch"
			scratch.Parent = workspace
			local okL6, b6 = pcall(LevelBuilder.build, l6, Vector3.new(-6000, 0, 0), scratch, {
				kit = KitService,
				dressing = true,
			})
			local skins, xmas = 0, 0
			if okL6 then
				for _, dsc in b6.model:GetDescendants() do
					if dsc:GetAttribute("EH_Kind") == "doorSkin" then
						skins += 1
					end
					local piece = dsc:GetAttribute("KitPiece")
					if
						type(piece) == "string"
						and (string.sub(piece, 1, 5) == "Xmas_" or piece == "LaserEmitter_CandyCane")
					then
						xmas += 1
					end
				end
			end
			check(
				okL6 and b6.kit and b6.dressing and skins == 1 and xmas >= 10,
				string.format("kit: L6 with the Christmas layer (%d Christmas pieces, %d vault skin)", xmas, skins)
			)
			-- Light and levels (PLAN_STEAM_PLUS W2, LEVELS P0): real Light objects within the per-view
			-- budget (<= MAX_LIGHTS_PER_VIEW lit, <= MAX_SHADOWED_PER_VIEW shadowed), a Lamp_Ceiling over
			-- each, an unlit floor pool, and the plate letters moved onto the kit plates.
			if okL6 then
				local LIGHT = Config.Lighting
				local lights: { Light } = {}
				local shades, pools = 0, 0
				for _, dsc in b6.model:GetDescendants() do
					if dsc:IsA("Light") then
						table.insert(lights, dsc)
					elseif dsc:GetAttribute("KitPiece") == "Lamp_Ceiling" then
						shades += 1
					elseif dsc:GetAttribute("EH_Kind") == "lightPool" and dsc:FindFirstChildOfClass("SurfaceGui") then
						pools += 1
					end
				end
				local worstLit, worstShadow = 0, 0
				for _, a in lights do
					local lit, shadowed = 0, 0
					local pa = (a.Parent :: Attachment).WorldPosition
					for _, l in lights do
						local pb = (l.Parent :: Attachment).WorldPosition
						if Vector3.new(pa.X - pb.X, 0, pa.Z - pb.Z).Magnitude <= LIGHT.VIEW_RADIUS then
							lit += 1
							if l.Shadows then
								shadowed += 1
							end
						end
					end
					worstLit, worstShadow = math.max(worstLit, lit), math.max(worstShadow, shadowed)
				end
				check(
					#lights >= 6
						and worstLit <= LIGHT.MAX_LIGHTS_PER_VIEW
						and worstShadow <= LIGHT.MAX_SHADOWED_PER_VIEW,
					string.format(
						"light: L6 has %d lamps; worst view %d lit / %d shadowed (<= %d / %d)",
						#lights,
						worstLit,
						worstShadow,
						LIGHT.MAX_LIGHTS_PER_VIEW,
						LIGHT.MAX_SHADOWED_PER_VIEW
					)
				)
				check(
					shades == #lights and pools == #lights,
					string.format("light: a Lamp_Ceiling (%d) and a floor pool (%d) per lamp", shades, pools)
				)
				local lettered = 0
				for _, plate in b6.plates do
					for _, c in plate:GetChildren() do
						if c:GetAttribute("EH_Kind") == "plateLetter" and c:FindFirstChildOfClass("SurfaceGui") then
							lettered += 1
						end
					end
				end
				check(
					lettered == #b6.plates,
					string.format("light: %d/%d kit plates carry their letter", lettered, #b6.plates)
				)
				-- W5 signature silhouettes (Heist/LevelDress props): six marble columns and two green banker's
				-- lamps, all visual only; the Bank's room lamps carry the green (Config.Lighting.LOCATION.Bank).
				local columns, bankers, solidSig = 0, 0, 0
				for _, dsc in b6.model:GetDescendants() do
					local piece = dsc:GetAttribute("KitPiece")
					if dsc:IsA("BasePart") and (piece == "Column_2x12" or piece == "BankersLamp") then
						if piece == "Column_2x12" then
							columns += 1
						else
							bankers += 1
						end
						if dsc.CanCollide or dsc.CanQuery or dsc.CanTouch then
							solidSig += 1
						end
					end
				end
				check(
					columns == 6 and bankers == 2 and solidSig == 0,
					string.format("world: L6 has %d columns, %d banker's lamps (%d solid)", columns, bankers, solidSig)
				)
				local green = LIGHT.LOCATION.Bank.room[1]
				local greenRooms = 0
				for _, l in lights do
					local c = l.Color
					if
						math.abs(c.R * 255 - green[1]) < 1
						and math.abs(c.G * 255 - green[2]) < 1
						and math.abs(c.B * 255 - green[3]) < 1
					then
						greenRooms += 1
					end
				end
				check(greenRooms >= 1, string.format("world: L6 room lamps are banker's green (%d)", greenRooms))
			end
			scratch:Destroy()

			-- W4 backdrop: the server hands the client the skyline ring meshes (Heist/BackdropKit); the plan the
			-- client builds fits its budget; the Sky shows the Heist City faces (never the retired night ones).
			local okBk, BackdropKit = pcall(require, server:WaitForChild("Heist"):WaitForChild("BackdropKit"))
			if okBk then
				local okPub, published = pcall(BackdropKit.publish, KitService)
				local folderBk = ReplicatedStorage:FindFirstChild(Config.Backdrop.KIT_FOLDER)
				local quietParts = 0
				if folderBk then
					for _, c in folderBk:GetChildren() do
						if c:IsA("MeshPart") and not c.CanCollide and not c.CanQuery and not c.CanTouch then
							quietParts += 1
						end
					end
				end
				check(
					okPub and published == 2 * #Config.Backdrop.RINGS and quietParts == published,
					string.format(
						"world: BackdropKit published %s ring pieces (%d visual only)",
						tostring(published),
						quietParts
					)
				)
			else
				check(false, "world: BackdropKit loads: " .. tostring(BackdropKit))
			end
			local BackdropPlan = require(sharedFolder:WaitForChild("Heist"):WaitForChild("BackdropPlan"))
			local l1 = HeistInstance.levelData(HeistService.indexOf("cs1_back_room") :: number)
			local bplan = BackdropPlan.plan(BackdropPlan.levelSite(l1))
			local draws, tris, nparts = BackdropPlan.budget(bplan, 1, {
				Skyline_Near = 292,
				Skyline_Near_Windows = 996,
				Skyline_Far = 352,
				Skyline_Far_Windows = 1236,
			})
			check(
				draws <= 30 and tris <= 25000,
				string.format("world: L1 backdrop %d draw calls, %d tris, %d instances", draws, tris, nparts)
			)
			local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
			local retired = { "90458356352519", "108707070296486", "103394177161659" }
			local cityFaces = 0
			if sky then
				for _, face in { "Bk", "Dn", "Ft", "Lf", "Rt", "Up" } do
					local okUri, uri = pcall(function()
						return tostring((sky :: any)["Skybox" .. face])
					end)
					uri = if okUri then uri else ""
					local isRetired = false
					for _, id in retired do
						isRetired = isRetired or string.find(uri, id, 1, true) ~= nil
					end
					if string.find(uri, "rbxassetid://%d+") and not isRetired then
						cityFaces += 1
					end
				end
			end
			check(cityFaces == 6, string.format("world: Sky shows %d/6 Heist City faces", cityFaces))
		elseif instK then
			check(instK.folder:GetAttribute("Kit") == false, "kit: not ready, level stays greybox (fallback)")
			check(false, "kit: KitService.ready (" .. KitService.summary() .. ")")
			HeistService.destroyInstance(instK)
		else
			check(false, "kit: L2 instance created")
		end
	end

	-- Clone template stripping on a real engine rig (§6.5 #2; safe strip, PLAN_STEAM_PLUS §1 S1:
	-- the joints and their attachments stay, physics-only constraints and scripts go).
	-- tests/clone_engine.luau replays real stripped avatars with physics running.
	local RigJoints = require(sharedFolder:WaitForChild("Heist"):WaitForChild("RigJoints"))
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
			local leftover = d:IsA("BaseScript")
				or d:IsA("BallSocketConstraint")
				or d:IsA("NoCollisionConstraint")
				or d:IsA("WrapLayer")
				or (d:IsA("SurfaceAppearance") and not GameConfig.Heist.CLONE_KEEP_SURFACE_APPEARANCE)
			if leftover or (d:IsA("BasePart") and (d.CanCollide or d.CastShadow)) then
				bad += 1
			end
		end
		local joints = RigJoints.whole(rig)
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local rootPart = rig:FindFirstChild("HumanoidRootPart")
		local count = #rig:GetDescendants()
		check(count <= 130, "sim: stripped clone template has " .. count .. " instances (<= 130)")
		check(
			joints >= GameConfig.Heist.CLONE_MIN_JOINTS,
			"sim: stripped clone template keeps its joints (" .. joints .. " whole)"
		)
		check(
			bad == 0
				and hum ~= nil
				and hum.EvaluateStateMachine == false
				and hum.AutomaticScalingEnabled == false
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
	for _, name in
		{ "Ui", "Rigs", "EchoView", "GusView", "WorldView", "RewindDirector", "Hud", "Backdrop", "HeistClient" }
	do
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

-- 8. Garage v1 (PLAN_STEAM_PLUS §4.1 W6, docs/GOLDEN_FRAMES.md G3): server Heist/Lobby builds the garage from the
-- pure Heist/LobbyPlan: greybox at once (brick walls with the roll-up door gap, 8 van colliders in their bay paints,
-- warm work lamps and pools, the glowing NEXT card, the GarageSpawn), then dressed with the kit (walls, door, floor,
-- 8 kit vans with Van_Paint in the bay colours, the job board, trophies) while the greybox stays the collision.
do
	local Config = GameConfig :: any
	local C, LIGHT = Config.Lobby, Config.Lighting
	local heistServer = server:WaitForChild("Heist")
	local okLobby, Lobby = pcall(require, heistServer:WaitForChild("Lobby"))
	check(okLobby, "garage: Lobby loads" .. (if okLobby then "" else ": " .. tostring(Lobby)))
	local okKit, KitService = pcall(require, server:WaitForChild("Kit"):WaitForChild("KitService"))
	if okLobby then
		local okBuild, garage = pcall(Lobby.build, if okKit then KitService else nil)
		check(okBuild and garage ~= nil, "garage: Lobby.build" .. (if okBuild then "" else ": " .. tostring(garage)))
		if okBuild and garage then
			check(garage.Parent == workspace and garage.Name == "Garage", "garage: workspace.Garage")
			local spawn = garage:FindFirstChild("GarageSpawn")
			check(spawn ~= nil and spawn:IsA("SpawnLocation") and spawn.CanCollide, "garage: GarageSpawn collides")
			local van1 = garage:FindFirstChild("Van")
			check(
				van1 ~= nil and van1:IsA("BasePart") and van1:GetAttribute("EH_Bay") == 1,
				"garage: bay 1's van collider is the part named Van (GoldenShots G3 frames it)"
			)
			-- 8 bays, each a colliding van box in its paint
			local bays = {}
			for _, d in garage:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("EH_Kind") == "garageVan" then
					bays[d:GetAttribute("EH_Bay")] = d
				end
			end
			local baysOk = 0
			for i = 1, 8 do
				local v = bays[i]
				local p = C.BAY_PAINTS[i]
				if v and v.CanCollide and v.Color == Color3.fromRGB(p[1], p[2], p[3]) then
					baysOk += 1
				end
			end
			check(baysOk == 8, string.format("garage: 8 van bays in their paints (%d)", baysOk))
			-- spawn spread: inside the garage, never inside a van
			local origin = Vector3.new(table.unpack(Config.Heist.LOBBY_ORIGIN))
			local spawnsOk = 0
			for i = 1, 8 do
				local p = Lobby.spawnFor(i).Position - origin
				local inside = math.abs(p.X) < C.HALF_X and math.abs(p.Z) < C.HALF_Z
				for _, v in bays do
					local l = v.CFrame:PointToObjectSpace(Lobby.spawnFor(i).Position)
					if math.abs(l.X) < v.Size.X / 2 + 1 and math.abs(l.Z) < v.Size.Z / 2 + 1 then
						inside = false
					end
				end
				spawnsOk += if inside then 1 else 0
			end
			check(
				spawnsOk == 8,
				string.format("garage: spawnFor 1-8 inside the garage, clear of the vans (%d)", spawnsOk)
			)
			-- lights inside the per-view budget; your bay is the one shadowed key
			local lights: { Light } = {}
			for _, d in garage:GetDescendants() do
				if d:IsA("Light") then
					table.insert(lights, d)
				end
			end
			local worstLit, worstShadow, shadowedTotal = 0, 0, 0
			for _, a in lights do
				local lit, sh = 0, 0
				local pa = (a.Parent :: Attachment).WorldPosition
				for _, l in lights do
					local pb = (l.Parent :: Attachment).WorldPosition
					if Vector3.new(pa.X - pb.X, 0, pa.Z - pb.Z).Magnitude <= LIGHT.VIEW_RADIUS then
						lit += 1
						sh += if l.Shadows then 1 else 0
					end
				end
				worstLit, worstShadow = math.max(worstLit, lit), math.max(worstShadow, sh)
				shadowedTotal += if a.Shadows then 1 else 0
			end
			check(
				#lights >= 10
					and worstLit <= LIGHT.MAX_LIGHTS_PER_VIEW
					and worstShadow <= LIGHT.MAX_SHADOWED_PER_VIEW
					and shadowedTotal == 1,
				string.format(
					"garage: %d warm lights, worst view %d lit / %d shadowed, %d shadowed in all",
					#lights,
					worstLit,
					worstShadow,
					shadowedTotal
				)
			)
			-- the NEXT card glows (unlit SurfaceGui) and says a job; the client rewrites it with yours
			local card = garage:FindFirstChild("JobCard", true)
			local gui = card and card:FindFirstChild("Card")
			local title = gui and gui:FindFirstChild("Title")
			check(
				card ~= nil
					and card:GetAttribute("EH_Kind") == "jobCard"
					and gui ~= nil
					and (gui :: SurfaceGui).LightInfluence == 0
					and title ~= nil
					and (title :: TextLabel).Text ~= "",
				"garage: the job board's NEXT card glows with a job"
			)
			local okJb, JobBoard = pcall(function()
				return require(
					game:GetService("StarterPlayer")
						:WaitForChild("StarterPlayerScripts")
						:WaitForChild("Client")
						:WaitForChild("Heist")
						:WaitForChild("JobBoard")
				)
			end)
			if okJb and title then
				JobBoard.show({
					levels = {
						{ name = "Back Room", unlocked = true, medals = { "Clear" } },
						{ name = "Two Doors", unlocked = true, medals = {} },
					},
				})
				check((title :: TextLabel).Text == "TWO DOORS", "garage: JobBoard writes your next job on the card")
			else
				check(false, "garage: client JobBoard loads" .. (if okJb then "" else ": " .. tostring(JobBoard)))
			end
			-- no default Roblox grey or white blocks anywhere (visible plain parts carry a palette colour)
			local grey = Color3.fromRGB(163, 162, 165)
			local bad = {}
			for _, d in garage:GetDescendants() do
				if d:IsA("Part") and d.Transparency < 1 and (d.Color == grey or d.Color == Color3.new(1, 1, 1)) then
					table.insert(bad, d.Name)
				end
			end
			check(#bad == 0, "garage: no default grey or white blocks (" .. table.concat(bad, ", ") .. ")")
			-- the kit dressing (visual only; the greybox walls and vans stay the colliders)
			if okKit and KitService.ready(45) and KitService.report().ok then
				local n = Lobby.dress(KitService)
				local deadline = os.clock() + 10
				while not Lobby.isDressed() and os.clock() < deadline do
					task.wait(0.2)
				end
				local kit = garage:FindFirstChild("Kit")
				local meshes, colliding, paints, doors, boards = 0, 0, 0, 0, 0
				for _, d in (kit and kit:GetDescendants()) or {} do
					if d:IsA("MeshPart") then
						meshes += 1
						colliding += if d.CanCollide then 1 else 0
						local piece = d:GetAttribute("KitPiece")
						if piece == "Van_Paint" then
							local bay = d:GetAttribute("EH_Bay")
							local p = bay and C.BAY_PAINTS[bay]
							paints += if p and d.Color == Color3.fromRGB(p[1], p[2], p[3]) then 1 else 0
						elseif piece == "GarageDoor_16x12" then
							doors += 1
						elseif piece == "JobBoard" then
							boards += 1
						end
					end
				end
				check(
					Lobby.isDressed() and garage:GetAttribute("Kit") == true and meshes >= 150 and colliding == 0,
					string.format(
						"garage: dressed with %d kit parts (%d colliding; placed now %d)",
						meshes,
						colliding,
						n
					)
				)
				check(
					paints == 8 and doors == 1 and boards == 1,
					string.format(
						"garage: 8 kit vans in bay paints (%d), roll-up door %d, job board %d",
						paints,
						doors,
						boards
					)
				)
				local wallsCollide = 0
				for _, d in garage:GetChildren() do
					if
						d:IsA("BasePart")
						and string.match(d.Name, "^Wall%d")
						and d.CanCollide
						and d.Transparency == 1
					then
						wallsCollide += 1
					end
				end
				check(
					wallsCollide == 5,
					string.format("garage: greybox walls hidden but colliding (%d/5)", wallsCollide)
				)
			else
				check(false, "garage: kit ready for the dressing")
			end
		end
	end
end

table.insert(results, string.format("%d failure(s)", failures))
return table.concat(results, "\n")
