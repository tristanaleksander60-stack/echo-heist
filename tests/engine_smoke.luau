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

-- Boot timings gathered along the way (section 17 checks them against Config.Boot).
local bootTimes: { [string]: number } = {}

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
	local SimConfig = require(sharedFolder:WaitForChild("Config")) :: any
	local SlideMath = require(sharedFolder:WaitForChild("Heist"):WaitForChild("SlideMath"))
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
		-- the cash sits behind the right partition window (10, -26): through the door, then right
		walkTo(0, -16)
		walkTo(0, -23)
		walkTo(7, -25)
		HeistInstance.interact(inst, FAKE, Codec.EVENT.Grab, 1)
		step(0.05)
		step(0.05)
		check(inst.folder:GetAttribute("K1State") == "Carried", "sim: cash grabbed through Interact (attribute)")
		walkTo(0, -23)
		walkTo(0, -16)
		-- A fast slide (Config.Slide) back up the corridor: the Slide request (Heist.Interact) first, then the push
		-- at SlideMath's speeds; the server's validator window must keep the run untainted and unclamped.
		local slideOk = HeistInstance.interact(inst, FAKE, Codec.EVENT.Slide, 1)
		local slideT = 0
		while slideT < SimConfig.Slide.SECONDS[2] do
			local v = SlideMath.speed(SimConfig.Rec.WALK_SPEED, slideT, 2, SimConfig.Slide)
			HeistInstance.setFakeInput(inst, FAKE, fakeIn.x, 3, fakeIn.z + v * 0.05, math.pi)
			step(0.05)
			slideT += 0.05
		end
		local slideLive = HeistSim.liveActor(inst.sim, FAKE)
		local slideEvents = 0
		for _, e in (if slideLive then slideLive.rec.events else {}) :: { any } do
			if e.kind == Codec.EVENT.Slide then
				slideEvents += 1
			end
		end
		check(
			slideOk == true and slideEvents == 1 and slideLive ~= nil and slideLive.rec.vflags == 0,
			string.format(
				"sim: a fast slide is recorded (Slide event) and validated clean (vflags %s, at z %.1f)",
				tostring(slideLive and slideLive.rec.vflags),
				fakeIn.z
			)
		)
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
		-- as the real server boots (init.server): EH_IntroKit goes out as soon as the kit's intro phase is ready
		-- (section 17 times it from this start)
		pcall(function()
			require(server:WaitForChild("Heist"):WaitForChild("IntroKit")).publish(KitService)
		end)
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
				local shades, pools, washes = 0, 0, 0
				for _, dsc in b6.model:GetDescendants() do
					if dsc:IsA("Light") then
						table.insert(lights, dsc)
						local washHolder = dsc:FindFirstAncestorWhichIsA("BasePart")
						if washHolder and washHolder:GetAttribute("EH_LampKind") == "wash" then
							washes += 1 -- INTERIORS: a wall wash is a light only (no fixture, no pool)
						end
					elseif
						dsc:GetAttribute("KitPiece") == "Lamp_Ceiling"
						or dsc:GetAttribute("KitPiece") == "StreetLamp"
					then
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
					shades == #lights - washes and pools == #lights - washes,
					string.format(
						"light: a fixture (Lamp_Ceiling or StreetLamp, %d) and a floor pool (%d) per lamp (+ %d wall washes)",
						shades,
						pools,
						washes
					)
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
					-- (the BIG building's giant order over the street front is the Overhead's, counted in section 11)
					if
						dsc:IsA("BasePart")
						and (piece == "Column_2x12" or piece == "BankersLamp")
						and dsc:FindFirstAncestor("Overhead") == nil
					then
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
					okPub and published == #BackdropKit.pieces() and quietParts == published,
					string.format(
						"world: BackdropKit published %s ring and town pieces (%d visual only)",
						tostring(published),
						quietParts
					)
				)
			else
				check(false, "world: BackdropKit loads: " .. tostring(BackdropKit))
			end
			local BackdropPlan = require(sharedFolder:WaitForChild("Heist"):WaitForChild("BackdropPlan"))
			local l1 = HeistInstance.levelData(HeistService.indexOf("cs1_back_room") :: number)
			local bplan = BackdropPlan.plan(BackdropPlan.levelSite(l1), true)
			-- WORLD 2.0: the town's draws and instances (triangles: the unit spec, from the manifest)
			local draws, _tris, nparts = BackdropPlan.budget(bplan, 1, {})
			local TB = Config.Backdrop.TOWN.BUDGET
			check(
				draws <= TB.draws and nparts <= TB.instances and bplan.facades >= 14,
				string.format(
					"world: L1 backdrop %d draw calls, %d instances, %d buildings",
					draws,
					nparts,
					bplan.facades
				)
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
		local lobbyT0 = os.clock()
		local okBuild, garage = pcall(Lobby.build, if okKit then KitService else nil)
		bootTimes.lobby = os.clock() - lobbyT0
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
			-- the warehouse (Config.Lobby.WAREHOUSE): the high roof and its cut-away groups, the anchors the LOBBY
			-- track builds on, the mezzanine's stair rising from the floor to the deck
			local W = C.WAREHOUSE
			local over = garage:FindFirstChild("Overhead")
			local groupsOk = over ~= nil
				and over:FindFirstChild("roof") ~= nil
				and over:FindFirstChild("trusses") ~= nil
				and over:FindFirstChild("front") ~= nil
				and over:FindFirstChild("mezzanine") ~= nil
			local strays = 0
			for _, d in (over and over:GetDescendants()) or {} do
				if
					d:IsA("BasePart")
					and (d.CanCollide or d.CastShadow)
					and d:GetAttribute("EH_Kind") ~= "garageCollider"
				then
					strays += 1
				end
			end
			check(
				groupsOk and strays == 0 and (over :: any):GetAttribute("CeilY") > C.WALL_H + 8,
				string.format("garage: the warehouse roof, trusses, faces, mezzanine (%d stray colliders)", strays)
			)
			local anchors = garage:FindFirstChild("Anchors")
			local missing = {}
			local names = { "JobBoardSpot", "LaptopSpot", "WardrobeSpot", "TVSpot", "CrewSign" }
			for i = 1, 8 do
				table.insert(names, "VanBay" .. i)
			end
			for _, n in names do
				local a = anchors and anchors:FindFirstChild(n)
				if not (a and a:IsA("BasePart") and not a.CanCollide and not a.CanQuery and a.Transparency == 1) then
					table.insert(missing, n)
				end
			end
			check(#missing == 0, "garage: the LOBBY anchors are there (" .. table.concat(missing, ", ") .. ")")
			local st = W.STAIR
			local origin2 = Vector3.new(table.unpack(Config.Heist.LOBBY_ORIGIN))
			local ramp = garage:FindFirstChild("StairRamp", true)
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { ramp :: Instance }
			local mx = (st.x0 + st.x1) / 2
			local low = workspace:Raycast(origin2 + Vector3.new(mx, 40, st.z0 + 1), Vector3.new(0, -60, 0), rp)
			local high = workspace:Raycast(origin2 + Vector3.new(mx, 40, st.z1 - 1), Vector3.new(0, -60, 0), rp)
			local deckTop = W.MEZZANINE.deckY + W.MEZZANINE.thick
			check(
				ramp ~= nil
					and ramp:IsA("WedgePart")
					and (ramp :: BasePart).CanCollide
					and low ~= nil
					and high ~= nil
					and low.Position.Y - origin2.Y < 1.5
					and high.Position.Y - origin2.Y > deckTop - 1.5,
				string.format(
					"garage: the stair rises from the floor (%.1f) to the mezzanine deck (%.1f of %.1f)",
					if low then low.Position.Y - origin2.Y else -1,
					if high then high.Position.Y - origin2.Y else -1,
					deckTop
				)
			)
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

-- 9. L6 "need all 4" lamp row and the teller lobby (levels and world feedback track, LEVELS P1-3, PLAN §7): the
-- server builds a lettered lamp per vault plate on the vault frame's scale-room face (A-D west to east) and the
-- "VAULT n/4" count; the client's WorldView colours each lamp in its presser's hue from the plate attributes and
-- counts; the lobby counters are TellerCounter_8x4 (with their glass screen) on the sim counters; the pools carry
-- the soft image label and soft discs; plates inside hides hang their letter over the hide.
do
	local Config = GameConfig :: any
	local LIGHT = Config.Lighting
	local heistServer = server:WaitForChild("Heist")
	local Palette = require(sharedFolder:WaitForChild("Heist"):WaitForChild("Palette"))
	local okReq, err = pcall(function()
		local LevelBuilder = require(heistServer:WaitForChild("LevelBuilder"))
		local HeistService = require(heistServer:WaitForChild("HeistService"))
		local HeistInstance = require(heistServer:WaitForChild("HeistInstance"))
		local okKit, KitService = pcall(require, server:WaitForChild("Kit"):WaitForChild("KitService"))
		local kitReady = okKit and KitService.isReady()
		local l6 = HeistInstance.levelData(HeistService.indexOf("bk1_big_score") :: number)
		local scratch = Instance.new("Folder")
		scratch.Name = "RowScratch"
		scratch.Parent = workspace
		local origin = Vector3.new(-9000, 0, 0)
		local b6 = LevelBuilder.build(l6, origin, scratch, {
			kit = if kitReady then KitService else nil,
			dressing = true,
		})
		local lamps: { BasePart } = {}
		local count: BasePart? = nil
		local tellers, glass, pools, softPools, hidePlaques = 0, 0, 0, 0, 0
		for _, d in b6.model:GetDescendants() do
			local kind = d:GetAttribute("EH_Kind")
			if kind == "vaultLamp" and d:IsA("BasePart") then
				table.insert(lamps, d)
			elseif kind == "vaultCount" and d:IsA("BasePart") then
				count = d
			elseif kind == "lightPool" then
				pools += 1
				local gui = d:FindFirstChildOfClass("SurfaceGui")
				local rings = 0
				for _, c in (if gui then gui:GetDescendants() else {}) do
					rings += if c:IsA("Frame") and c.Name == "Ring" then 1 else 0
				end
				local soft = gui and gui:FindFirstChild("Soft", true)
				if soft and soft:IsA("ImageLabel") and rings == LIGHT.POOL_SOFT.rings then
					softPools += 1
				end
			elseif kind == "plaque" and d.Parent and d.Parent:GetAttribute("EH_Kind") == "hide" then
				hidePlaques += 1
			end
			local piece = d:GetAttribute("KitPiece")
			if piece == "TellerCounter_8x4" then
				tellers += 1
			elseif piece == "TellerCounter_8x4_Glass" then
				glass += 1
			end
		end
		table.sort(lamps, function(a: BasePart, b: BasePart): boolean
			return a.Position.X < b.Position.X
		end)
		local letters = ""
		local placed = 0
		for _, l in lamps do
			local gui = l:FindFirstChildOfClass("SurfaceGui")
			local label = gui and gui:FindFirstChildWhichIsA("TextLabel", true)
			letters ..= if label then label.Text else "?"
			local rel = l.Position - origin
			if math.abs(rel.Y - LIGHT.VAULT_ROW.y) < 0.01 and rel.Z > -47.5 and rel.Z < -46.5 then
				placed += 1
			end
		end
		check(
			#lamps == 4 and letters == "ABCD",
			string.format("L6 row: 4 lamps lettered A-D west to east (%s)", letters)
		)
		check(placed == 4, string.format("L6 row: over the vault door on the scale-room face (%d/4)", placed))
		local countLabel = count and count:FindFirstChildWhichIsA("TextLabel", true)
		check(
			countLabel ~= nil and countLabel.Text == "VAULT 0/4",
			"L6 row: the VAULT 0/4 count (" .. (if countLabel then countLabel.Text else "missing") .. ")"
		)
		check(
			pools >= 10 and softPools == pools,
			string.format(
				"soft pools: every pool has its soft label and %d discs (%d/%d)",
				LIGHT.POOL_SOFT.rings,
				softPools,
				pools
			)
		)
		check(
			hidePlaques == 4,
			string.format("L6: the letters of the four hidden plates over their hides (%d)", hidePlaques)
		)
		if kitReady then
			check(
				tellers == 4 and glass == 4,
				string.format("L6 lobby: 4 teller counters with their glass screens (%d, %d glass)", tellers, glass)
			)
		else
			check(false, "L6 lobby: kit ready for the teller counters")
		end
		-- The client view drives the row from the plate attributes (no remote): A and B held by seat 1.
		local clientHeist = game:GetService("StarterPlayer")
			:WaitForChild("StarterPlayerScripts")
			:WaitForChild("Client")
			:WaitForChild("Heist")
		local WorldView = require(clientHeist:WaitForChild("WorldView"))
		local folder = Instance.new("Folder")
		folder.Name = "RowState"
		folder.Parent = scratch
		local vstate = {
			origin = origin,
			folder = folder,
			level = l6,
			levelIndex = HeistService.indexOf("bk1_big_score"),
			crew = {},
			actorFx = {},
			phase = "Run",
			run = { actorById = { [7] = { id = 7, kind = "clone", seat = 1, owner = -1 } } },
		}
		local view = WorldView.new(vstate, function(): Vector3?
			return nil
		end)
		view.bind(b6.model)
		for i = 1, 4 do
			folder:SetAttribute("P" .. i .. "Held", i <= 2)
			folder:SetAttribute("P" .. i .. "By", if i <= 2 then 7 else 0)
		end
		view.update(0, os.clock(), 1 / 60)
		local hue = Palette.hueFor(1)
		local lit, idle = 0, 0
		for k, l in lamps do
			if k <= 2 and l.Color == hue and l.Transparency == 0 then
				lit += 1
			elseif
				k > 2
				and l.Color == Palette.bulbWarm
				and math.abs(l.Transparency - LIGHT.VAULT_ROW.idleAlpha) < 1e-3
			then
				idle += 1
			end
		end
		check(
			lit == 2 and idle == 2,
			string.format("L6 row: A, B in the presser's hue, C, D idle (%d lit, %d idle)", lit, idle)
		)
		check(
			countLabel ~= nil and countLabel.Text == "VAULT 2/4",
			"L6 row: WorldView counts VAULT 2/4 (" .. (if countLabel then countLabel.Text else "missing") .. ")"
		)
		local bankCalls = 0
		local off = view.onBank(function()
			bankCalls += 1
		end)
		off()
		check(bankCalls == 0 and type(off) == "function", "WorldView.onBank: a hook the HUD can add and remove")
		view.clear()
		scratch:Destroy()
	end)
	check(okReq, "L6 row and lobby section ran" .. (if okReq then "" else ": " .. tostring(err)))
end

-- 10. The Rookie (PLAN_FIRST_PERSON "CH"): every player is a Rookie. Heist/Rookie publishes
-- ReplicatedStorage.CharacterKit from the uploaded art kit (the template, the pieces, the first-person arms), and
-- Heist/Characters makes the StarterCharacter a Rookie. Luau Execution has no real Player, so a joining fake player
-- gets exactly what LoadCharacterAsync gives a real one (a clone of the StarterCharacter in workspace), then the
-- CharacterAdded dressing in its outfit and seat colour.
do
	local okRookie, rookieErr = pcall(function()
		local heistDir = server:WaitForChild("Heist")
		local KitService = require(server:WaitForChild("Kit"):WaitForChild("KitService"))
		local Rookie = require(heistDir:WaitForChild("Rookie"))
		local Characters = require(heistDir:WaitForChild("Characters"))
		local sharedDir = ReplicatedStorage:WaitForChild("Shared")
		local Config = require(sharedDir:WaitForChild("Config")) :: any
		local heistShared = sharedDir:WaitForChild("Heist")
		local Outfit = require(heistShared:WaitForChild("Outfit"))
		local Palette = require(heistShared:WaitForChild("Palette"))
		local RigJoints = require(heistShared:WaitForChild("RigJoints"))
		local RookieData = require(heistShared:WaitForChild("RookieData")) :: any
		KitService.start()
		KitService.ready(60)
		check(Rookie.publishNow(KitService), "rookie: CharacterKit published")
		local kit = ReplicatedStorage:FindFirstChild(Config.Rookie.KIT_FOLDER)
		local template = kit and kit:FindFirstChild("Rookie")
		local vm = kit and kit:FindFirstChild("Rookie_Viewmodel")
		local pieces = kit and kit:FindFirstChild("Pieces")
		local nPieces = 0
		for _, names in RookieData.groups do
			for _, name in names do
				if pieces and pieces:FindFirstChild(name) then
					nPieces += 1
				end
			end
		end
		check(
			template ~= nil and vm ~= nil and pieces ~= nil and nPieces == #pieces:GetChildren() and nPieces >= 40,
			"rookie: CharacterKit holds Rookie, Rookie_Viewmodel and every kit piece (" .. nPieces .. ")"
		)
		-- the first-person arms the FP track looks for
		local left = vm and vm:FindFirstChild("LeftArm")
		local right = vm and vm:FindFirstChild("RightArm")
		check(
			left ~= nil
				and right ~= nil
				and left:IsA("BasePart")
				and right:IsA("BasePart")
				and left:FindFirstChild("GripL") ~= nil
				and right:FindFirstChild("GripR") ~= nil
				and left.Anchored
				and not left.CanCollide
				and not right.CastShadow,
			"rookie: Rookie_Viewmodel LeftArm / RightArm with GripL / GripR (anchored, no collision, no shadow)"
		)

		-- an R15 character: 15 named parts, 15 whole joints, the rig attachments, HipHeight 2, the root 3 up
		local function r15(model: Model, tag: string)
			local hum = model:FindFirstChildOfClass("Humanoid")
			local hrp = model:FindFirstChild("HumanoidRootPart")
			local named, rigAtt = 0, 0
			for _, b in RookieData.body do
				local p = model:FindFirstChild(b.part)
				if p and p:IsA("BasePart") then
					named += 1
					local att = (if b.joint == "Root" then "Root" else b.joint) .. "RigAttachment"
					if p:FindFirstChild(att) then
						rigAtt += 1
					end
				end
			end
			local feet = if hrp
					and hrp:IsA("BasePart")
					and hum
				then hrp.Position.Y - hrp.Size.Y / 2 - hum.HipHeight
				else 0
			local lowest = math.huge
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d ~= hrp then
					lowest = math.min(lowest, d.Position.Y - d.Size.Y / 2)
				end
			end
			check(
				hum ~= nil
					and hum.RigType == Enum.HumanoidRigType.R15
					and math.abs(hum.HipHeight - Config.Rookie.HIP_HEIGHT) < 1e-3
					and hum:FindFirstChildOfClass("Animator") ~= nil
					and named == 15
					and rigAtt == 15
					and RigJoints.whole(model) == 15
					and model.PrimaryPart == hrp,
				string.format(
					"%s: R15 (%d parts, %d rig attachments, %d joints, HipHeight %.2f)",
					tag,
					named,
					rigAtt,
					RigJoints.whole(model),
					if hum then hum.HipHeight else -1
				)
			)
			check(
				math.abs(lowest - feet) < 0.15,
				string.format("%s: the boots stand on the floor HipHeight puts them on (gap %.3f)", tag, lowest - feet)
			)
		end
		if template then
			r15(template, "rookie template")
			check(template:GetAttribute("EH_Blocks") == false, "rookie template: kit meshes, not blocks")
		end

		Characters.start() -- no players here: it turns auto-loading and avatar appearance off and builds the starter
		Characters.ensureStarter()
		local starter = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
		check(
			starter ~= nil and starter:GetAttribute("EH_Rookie") == true and starter:GetAttribute("EH_Blocks") == false,
			"rookie: StarterPlayer.StarterCharacter is the kit Rookie"
		)
		check(
			game:GetService("StarterPlayer").LoadCharacterAppearance == false
				and game:GetService("Players").CharacterAutoLoads == false,
			"rookie: no avatar auto-load, no avatar appearance on the Rookie"
		)

		-- a joining fake player: the spawn clone, then the CharacterAdded dressing (outfit + seat 2)
		if starter then
			local char = starter:Clone()
			char.Name = "FakeRookie"
			char:PivotTo(CFrame.new(0, 400, 0))
			for _, d in char:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = d.Name == "HumanoidRootPart" -- hold it in the air: nothing simulates here anyway
				end
			end
			char.Parent = workspace
			r15(char, "fake player's character")
			local outfit = {
				cap = "Cap_Trapper",
				scarf = "Scarf_Knot",
				sweater = "Sweater_Block",
				gloves = "Gloves_Leather",
				mask = "Mask_Eye",
			}
			check(Characters.dressModel(char, outfit, 2), "rookie: the fake player's character is dressed")
			local want = {}
			for _, piece in Outfit.pieces(outfit) do
				want[piece] = true
			end
			local have, extra, crew, crewOk, welded = 0, 0, 0, true, true
			for _, d in char:GetChildren() do
				if d:GetAttribute("EH_Slot") ~= nil then
					if want[d.Name] then
						have += 1
					else
						extra += 1
					end
					local w = d:FindFirstChild("EH_Weld")
					welded = welded and w ~= nil and w:IsA("Weld") and w.Part0 ~= nil and w.Part0.Parent == char
				end
				if d:IsA("BasePart") and d:GetAttribute("EH_Tint") == "crew" then
					crew += 1
					crewOk = crewOk and d.Color == Palette.hueFor(2)
				end
			end
			local nWant = 0
			for _ in want do
				nWant += 1
			end
			check(
				have == nWant and extra == 0 and welded,
				string.format("rookie: outfit applied and welded (%d of %d pieces, %d extra)", have, nWant, extra)
			)
			check(crew >= 2 and crewOk, "rookie: crew pieces in the seat-2 hue (" .. crew .. ")")
			local hand = char:FindFirstChild("LeftHand")
			check(
				hand ~= nil
					and hand:IsA("BasePart")
					and hand.Color == Color3.fromHex(Config.Rookie.GLOVES.Gloves_Leather),
				"rookie: hands in the leather glove colour"
			)
			-- the cap sits on the head (welded by pivot at the head's hat point)
			local cap = char:FindFirstChild("Rookie_Cap_Trapper")
			local head = char:FindFirstChild("Head")
			check(
				cap ~= nil
					and head ~= nil
					and cap:IsA("BasePart")
					and head:IsA("BasePart")
					and (cap:GetPivot().Position - (head:GetPivot() * CFrame.new(0, 1.2, 0)).Position).Magnitude
						< 0.05,
				"rookie: the cap sits at the head's hat point"
			)
			-- faces: one shows at a time
			Rookie.setFace(char, "busted")
			local shown = {}
			for _, d in char:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("EH_Face") ~= nil and d.Transparency < 1 then
					table.insert(shown, d:GetAttribute("EH_Face"))
				end
			end
			check(#shown == 1 and shown[1] == "busted", "rookie: one face shows (" .. table.concat(shown, ",") .. ")")
			-- dressing again in the default outfit removes the old pieces
			Characters.dressModel(char, Outfit.default(), 1)
			check(
				char:FindFirstChild("Rookie_Cap_Trapper") == nil and char:FindFirstChild("Rookie_Cap_Flat") ~= nil,
				"rookie: a new outfit replaces the old pieces"
			)
			char:Destroy()
		end
	end)
	check(okRookie, "rookie section ran" .. (if okRookie then "" else ": " .. tostring(rookieErr)))
end

-- 11. BIG buildings (PLAN_FIRST_PERSON §5 "BIG", Config.Big; docs/audit/LEVELS.md §11). Every launch level and two
-- daily vaults, kit-dressed with the Christmas layer: the Overhead (ceiling, storeys, roof) is there and visual only
-- (CanCollide, CanQuery, CanTouch and CastShadow off: the sim's colliders and the cameras' raycasts are what they
-- were); a first-person "look up" from eye height on a 4-stud grid over every playable room hits the ceiling at the
-- wall tops, never the sky (a real workspace raycast, the Overhead made queryable for the check only); and with the
-- diorama camera above you inside, the cut-away rule (Shared/Heist/CutMath on the built groups' attributes) hides
-- the ceiling and the roof, and every Overhead part a ray from that camera to your head meets is in a hidden group.
do
	local okBig, bigErr = pcall(function()
		local heistDir = server:WaitForChild("Heist")
		local sharedDir = ReplicatedStorage:WaitForChild("Shared")
		local Config = require(sharedDir:WaitForChild("Config")) :: any
		local LevelBuilder = require(heistDir:WaitForChild("LevelBuilder"))
		local KitPlan = require(heistDir:WaitForChild("KitPlan"))
		local KitService = require(server:WaitForChild("Kit"):WaitForChild("KitService"))
		local LevelSpec = require(sharedDir:WaitForChild("Sim"):WaitForChild("LevelSpec"))
		local Catalog = require(sharedDir:WaitForChild("Levels"):WaitForChild("Catalog"))
		local DailyVaults = require(sharedDir:WaitForChild("Levels"):WaitForChild("DailyVaults")) :: any
		local CutMath = require(sharedDir:WaitForChild("Heist"):WaitForChild("CutMath"))
		local CameraMath = require(
			game:GetService("StarterPlayer")
				:WaitForChild("StarterPlayerScripts")
				:WaitForChild("Client")
				:WaitForChild("Heist")
				:WaitForChild("CameraMath")
		)
		KitService.start()
		local kitOk = KitService.ready(60)
		check(kitOk, "big: the kit is ready (" .. KitService.summary() .. ")")
		local BIG = Config.Big
		local D = Config.Heist.CAMERA.DIORAMA
		local specs = {}
		for _, s in Catalog do
			table.insert(specs, s)
		end
		table.insert(specs, DailyVaults.designs[1])
		table.insert(specs, DailyVaults.designs[10])
		local scratch = Instance.new("Folder")
		scratch.Name = "BigScratch"
		scratch.Parent = workspace
		for n, spec in specs do
			local lv = LevelSpec.compile(spec)
			local origin = Vector3.new(-12000, 0, 3000 * n)
			local built = LevelBuilder.build(lv, origin, scratch, { kit = KitService, dressing = true })
			local over = built.model:FindFirstChild("Overhead")
			local groups: { [string]: Instance } = {}
			local parts, loud = 0, 0
			if over then
				for _, g in over:GetChildren() do
					groups[g.Name] = g
				end
				for _, d in over:GetDescendants() do
					if d:IsA("BasePart") then
						parts += 1
						if d.CanCollide or d.CanQuery or d.CanTouch or d.CastShadow then
							loud += 1
						end
					end
				end
			end
			check(
				over ~= nil
					and over:GetAttribute("Kit") == true
					and groups.ceiling ~= nil
					and groups.roof ~= nil
					and groups.front ~= nil
					and parts >= 150
					and loud == 0,
				string.format(
					"big %s: %s building, %d visual-only parts (%d collide, query, touch or cast shadows)",
					spec.id,
					tostring(over and over:GetAttribute("Style")),
					parts,
					loud
				)
			)
			if not over then
				continue
			end
			-- the sim's own colliders: every solid still its exact box, nothing else in the level collides above them
			local solidsOk = true
			for i, sdef in lv.spec.solids do
				local part = built.solids[i]
				local b = sdef.box
				local want = Vector3.new(b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ)
				solidsOk = solidsOk and part ~= nil and part.CanCollide and (part.Size - want).Magnitude < 0.01
			end
			check(solidsOk, "big " .. spec.id .. ": the sim's solids are still their exact colliders")
			-- look up: a grid over the playable footprint, from the first-person eye
			for _, d in over:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanQuery = true
				end
			end
			-- only the Overhead (what is over your head): plates, doors, hides and loot below the ceiling never block
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { over }
			local bb = KitPlan.buildingBox(lv) :: any
			local ceilY = origin.Y + lv.floorY + BIG.CEIL_Y
			local points, misses = 0, {}
			local x = bb.minX + 2
			while x < bb.maxX - 1 do
				local z = bb.minZ + 2
				while z < bb.maxZ - 1 do
					local inSolid = false
					for _, s in lv.spec.solids do
						local sb = s.box
						if x > sb.minX - 0.6 and x < sb.maxX + 0.6 and z > sb.minZ - 0.6 and z < sb.maxZ + 0.6 then
							inSolid = true
						end
					end
					if not inSolid then
						points += 1
						local eye = origin + Vector3.new(x, lv.floorY + 3.8, z)
						local hit = workspace:Raycast(eye, Vector3.new(0, 200, 0), params)
						local ok = hit ~= nil
							and hit.Instance:IsDescendantOf(groups.ceiling)
							and math.abs(hit.Position.Y - ceilY) < 0.7
						if not ok and #misses < 3 then
							table.insert(
								misses,
								string.format(
									"(%g, %g) -> %s",
									x,
									z,
									if hit
										then hit.Instance:GetFullName() .. " y " .. math.floor(hit.Position.Y)
										else "sky"
								)
							)
						end
					end
					z += 4
				end
				x += 4
			end
			check(
				#misses == 0 and points >= 40,
				string.format(
					"big %s: first person looks up at the ceiling from %d spots over the rooms (%s)",
					spec.id,
					points,
					if #misses == 0 then "never the sky" else table.concat(misses, "; ")
				)
			)
			-- the cut-away: the diorama camera above you in the middle of the building
			local cut: { CutMath.Group } = {}
			local names = {}
			for _, g in over:GetChildren() do
				local lo, hi = g:GetAttribute("EH_CutMin"), g:GetAttribute("EH_CutMax")
				local nrm = g:GetAttribute("EH_CutNormal")
				if typeof(lo) == "Vector3" and typeof(hi) == "Vector3" then
					table.insert(cut, {
						kind = g:GetAttribute("EH_CutKind") :: string,
						minX = lo.X,
						minY = lo.Y,
						minZ = lo.Z,
						maxX = hi.X,
						maxY = hi.Y,
						maxZ = hi.Z,
						nx = if typeof(nrm) == "Vector3" then nrm.X else 0,
						nz = if typeof(nrm) == "Vector3" then nrm.Z else 0,
						plane = (g:GetAttribute("EH_CutPlane") :: number?) or 0,
					})
					table.insert(names, g.Name)
				end
			end
			local omin, omax = over:GetAttribute("OuterMin") :: Vector3, over:GetAttribute("OuterMax") :: Vector3
			local b = { ceilY = ceilY, minX = omin.X, maxX = omax.X, minZ = omin.Z, maxZ = omax.Z }
			local youL = { 0, lv.floorY + 3, (bb.minZ + bb.maxZ) / 2 }
			local lead = CameraMath.lead(D.FOV, D.PITCH, D.DISTANCE, D.SUBJECT_SCREEN_Y)
			local focus = { youL[1], youL[2] + D.FOCUS_HEIGHT, youL[3] }
			local camL = CameraMath.orbit(CameraMath.ahead(focus, 0, lead), 0, D.PITCH, D.DISTANCE)
			local cam = origin + Vector3.new(camL[1], camL[2], camL[3])
			local you = origin + Vector3.new(youL[1], youL[2], youL[3])
			local subj = { you.X, you.Y + 1.5, you.Z, you.X, you.Y - 2.2, you.Z }
			local hide = {}
			CutMath.decide(b, cut, cam.X, cam.Y, cam.Z, subj, 2, BIG.CUT.MARGIN, BIG.CUT.INSIDE_PAD, hide)
			local hidden: { [string]: boolean } = {}
			for i, nm in names do
				hidden[nm] = hide[i] == true
			end
			local sees = true
			local head = you + Vector3.new(0, 1.5, 0)
			local hit = workspace:Raycast(cam, head - cam, params)
			local blocker = "clear"
			while hit and hit.Instance:IsDescendantOf(over) do
				local g = hit.Instance
				while g.Parent ~= over do
					g = g.Parent :: Instance
				end
				if not hidden[g.Name] then
					sees = false
					blocker = hit.Instance:GetFullName()
					break
				end
				local from = hit.Position + (head - cam).Unit * 0.05
				hit = workspace:Raycast(from, head - from, params)
			end
			check(
				hidden.ceiling and hidden.roof and sees and cam.Y > ceilY,
				string.format(
					"big %s: the diorama above you inside cuts away the ceiling and roof and sees you (%s)",
					spec.id,
					blocker
				)
			)
			built.model:Destroy()
		end
		scratch:Destroy()
	end)
	check(okBig, "big section ran" .. (if okBig then "" else ": " .. tostring(bigErr)))
end

-- 12. The hideout lobby (LOBBY track, PLAN_FIRST_PERSON "LB", Config.Hideout). Heist/Vans builds a rig on every
-- VanBay anchor of the warehouse garage (look points, plate, seat cards, side door leaf, Seat parts: all visual or
-- seats, no lights); the kit van's open side door is on its local -Z and its cab on its local -X (a precise-collision
-- copy, raycast), so each bay anchor's facing is the side door's, toward the aisle. Then the van rules on the real
-- anchors with fake members (Luau Execution has no players): one claims VanBay2, a friend sits in as crew and is
-- READY, GO starts ONE heist instance with both; a solo player at VanBay3 starts alone; a third player cannot claim
-- the taken van; the seat cap holds. Heist.Ready's validator (VanRules.validReadyArg) and no new Heist.* remote names.
do
	local okLobby, lobbyErr = pcall(function()
		local AssetService = game:GetService("AssetService")
		local heistDir = server:WaitForChild("Heist")
		local sharedDir = ReplicatedStorage:WaitForChild("Shared")
		local Config = require(sharedDir:WaitForChild("Config")) :: any
		local HD = Config.Hideout
		local Lobby = require(heistDir:WaitForChild("Lobby"))
		local Vans = require(heistDir:WaitForChild("Vans"))
		local HeistService = require(heistDir:WaitForChild("HeistService"))
		local KitService = require(server:WaitForChild("Kit"):WaitForChild("KitService"))
		local VanRules = require(sharedDir:WaitForChild("Heist"):WaitForChild("VanRules"))
		local Protocol = require(sharedDir:WaitForChild("Heist"):WaitForChild("Protocol"))
		local garage = Lobby.model() or Lobby.build(nil)
		local folder = Vans.build(nil)
		check(folder ~= nil and folder.Parent == garage, "hideout: Garage/Vans built on the anchors")
		if not folder then
			return
		end
		local rigsOk, visualOk, lights = 0, true, 0
		for bay = 1, HD.BAYS do
			local m = folder:FindFirstChild("Van" .. bay)
			local seats = 0
			if m then
				for _, d in m:GetDescendants() do
					if d:IsA("Seat") then
						seats += if not d.CanCollide and not d.CanTouch then 1 else 0
					elseif d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CanTouch) then
						visualOk = false
					elseif d:IsA("Light") then
						lights += 1
					end
				end
			end
			if
				m
				and m:FindFirstChild("Cab")
				and m:FindFirstChild("Door")
				and m:FindFirstChild("Paint")
				and m:FindFirstChild("Plate")
				and m:FindFirstChild("DoorLeaf")
				and seats == #HD.VAN.SEATS
				and m:GetAttribute("Mode") == VanRules.MODE.Free
			then
				rigsOk += 1
			end
		end
		check(
			rigsOk == HD.BAYS and visualOk and lights == 0,
			string.format(
				"hideout: %d / %d van rigs (points, plate, door, %d seats), visual only %s, %d lights",
				rigsOk,
				HD.BAYS,
				#HD.VAN.SEATS,
				tostring(visualOk),
				lights
			)
		)
		-- every bay's side door faces the aisle (the anchor's LookVector toward the garage's middle)
		local facing = 0
		for bay = 1, HD.BAYS do
			local a = Vans.anchor(bay)
			if a and math.abs((a.Position + a.LookVector * 4).Z) < math.abs(a.Position.Z) then
				facing += 1
			end
		end
		check(facing == HD.BAYS, string.format("hideout: %d / %d side doors face the aisle", facing, HD.BAYS))
		-- the kit van: its open side door on local Z = DOOR_Z, its cab on local X = CAB_X
		if KitService.isReady() then
			local src = KitService.clone("Van", {})
			local okM, van = pcall(function()
				return AssetService:CreateMeshPartAsync(
					(src :: MeshPart).MeshContent,
					{ CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition }
				)
			end)
			if okM and van and src then
				van.Size = src.Size
				van.Anchored = true
				van.CanQuery = true
				van.CFrame = CFrame.new(0, 800 + van.Size.Y / 2, 0)
				van.Parent = workspace
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { van }
				local dz = HD.VAN.DOOR_Z
				local function reach(fromZ: number): number
					local hit = workspace:Raycast(Vector3.new(0.1, 804.5, fromZ), Vector3.new(0, 0, -fromZ * 2), params)
					return if hit then math.abs(hit.Position.Z - fromZ) else math.huge
				end
				local doorSide = reach(dz * 10) -- in through the open door, to the far wall
				local farSide = reach(-dz * 10) -- the closed far side
				local function top(x: number): number
					local hit = workspace:Raycast(Vector3.new(x, 830, 0), Vector3.new(0, -40, 0), params)
					return if hit then hit.Position.Y - 800 else 0
				end
				local cab = top(HD.VAN.CAB_X * 6)
				local rear = top(-HD.VAN.CAB_X * 6)
				check(
					doorSide > 10 and farSide < 8 and cab < rear - 1,
					string.format(
						"hideout: kit van side door on local Z %d (ray in %.1f vs %.1f), cab on local X %d (top %.1f vs %.1f)",
						dz,
						doorSide,
						farSide,
						HD.VAN.CAB_X,
						cab,
						rear
					)
				)
				van:Destroy()
			else
				table.insert(results, "      hideout: no precise van copy (" .. tostring(van) .. ")")
			end
		end

		-- the rules on the real anchors, with fake members
		local st = VanRules.new()
		local function standAt(bay: number, point: string): number
			local p = Vans.point(bay, point) :: Vector3
			local a = Vans.anchor(bay) :: CFrame
			local you = p + a.LookVector * 3 + Vector3.new(0, -1.2, 0) -- outside the side door, root height
			return (you - p).Magnitude
		end
		local A, B, C, D = -301, -302, -303, -304
		local crewA: VanRules.Crew = { id = 9001, leaderId = A, members = { A } }
		local okClaim = VanRules.claim(st, 2, crewA, A, standAt(2, "door"))
		check(okClaim, "hideout: A claims VanBay2 standing at its side door")
		local okFar = VanRules.claim(st, 4, { id = 9009, leaderId = -309, members = { -309 } }, -309, 40)
		check(not okFar, "hideout: a van is not claimed from across the garage")
		local okOpen = VanRules.setMode(st, 2, crewA, A, VanRules.MODE.Crew, standAt(2, "door"))
		local vanA = VanRules.van(st, 2) :: VanRules.Van
		Vans.render(2, vanA, { [A] = "FakeA" })
		local rig = folder:WaitForChild("Van2") :: Model
		local plate = rig:WaitForChild("Plate") :: BasePart
		local plateGui = plate:FindFirstChildOfClass("SurfaceGui")
		local plateName = plateGui and plateGui:FindFirstChild("Name")
		check(
			okOpen
				and rig:GetAttribute("Mode") == VanRules.MODE.Crew
				and rig:GetAttribute("LeaderId") == A
				and plateName ~= nil
				and (plateName :: TextLabel).Text == "FAKEA'S CREW",
			"hideout: VanBay2 is A's: CREW mode, the leader's plate"
		)
		local okSit, codeSit =
			VanRules.canSit(st, 2, { userId = B, crewId = 9002, friend = true }, 1, standAt(2, "door"))
		check(okSit and codeSit == "Join", "hideout: B (a friend) walks in at the side door and joins as crew")
		crewA.members = { A, B }
		VanRules.syncSeats(vanA, crewA)
		VanRules.markSeated(st, 2, B, true)
		local okWait = VanRules.canGo(st, 2, crewA, A, standAt(2, "cab"), false)
		check(not okWait, "hideout: GO waits for B's READY")
		VanRules.setReady(st, 2, B, true)
		Vans.render(2, vanA, { [A] = "FakeA", [B] = "FakeB" })
		local card = rig:WaitForChild("SeatCard2") :: BasePart
		local cardGui = card:FindFirstChildOfClass("SurfaceGui")
		local cardName = cardGui and cardGui:FindFirstChild("Name")
		check(
			cardName ~= nil and (cardName :: TextLabel).Text == "FAKEB" and rig:GetAttribute("Waiting") == 0,
			"hideout: B's seat card lights with B's name, nobody waiting"
		)
		local okGo = VanRules.canGo(st, 2, crewA, A, standAt(2, "cab"), false)
		check(okGo, "hideout: A presses GO at the cab")
		local l1 = HeistService.indexOf(Config.Heist.FTUE_L1_LEVEL) :: number
		if okGo then
			VanRules.depart(st, 2)
			local inst = HeistService.createInstance(l1, {
				{ userId = A, name = "FakeA", fake = { x = 0, y = 3, z = 14, yaw = 0 } },
				{ userId = B, name = "FakeB", fake = { x = 2, y = 3, z = 14, yaw = 0 } },
			}, A, false)
			local count = 0
			if inst then
				for _ in inst.byId do
					count += 1
				end
			end
			check(
				inst ~= nil and inst.byId[A] ~= nil and inst.byId[B] ~= nil and count == 2,
				string.format("hideout: GO starts one instance with both (%d members)", count)
			)
			if inst then
				HeistService.destroyInstance(inst)
			end
			VanRules.setAway(st, 2)
		end
		local okTaken, codeTaken = VanRules.claim(st, 2, { id = 9003, leaderId = C, members = { C } }, C, 1)
		check(not okTaken and codeTaken == "Taken", "hideout: a third player cannot claim the taken van")
		-- a solo player at VanBay3 starts alone
		local crewD: VanRules.Crew = { id = 9004, leaderId = D, members = { D } }
		local okD = VanRules.claim(st, 3, crewD, D, standAt(3, "paint"))
		local okSolo = VanRules.canGo(st, 3, crewD, D, standAt(3, "cab"), true)
		check(okD and okSolo, "hideout: D claims VanBay3 and goes SOLO")
		if okSolo then
			local inst = HeistService.createInstance(l1, {
				{ userId = D, name = "FakeD", fake = { x = 0, y = 3, z = 14, yaw = 0 } },
			}, D, false)
			local count = 0
			if inst then
				for _ in inst.byId do
					count += 1
				end
			end
			check(inst ~= nil and count == 1, string.format("hideout: SOLO starts alone (%d member)", count))
			if inst then
				HeistService.destroyInstance(inst)
			end
		end
		-- the seat cap: a crew of MAX_CREW fills the van; the next friend is refused
		local crewE: VanRules.Crew = { id = 9005, leaderId = -310, members = { -310 } }
		VanRules.claim(st, 5, crewE, -310, standAt(5, "door"))
		VanRules.setMode(st, 5, crewE, -310, VanRules.MODE.Crew, standAt(5, "door"))
		local seated = 1
		for k = 1, Config.Sim.MAX_CREW do
			local uid = -320 - k
			local okK = VanRules.canSit(st, 5, { userId = uid, crewId = 0, friend = true }, seated, standAt(5, "door"))
			if okK then
				seated += 1
			end
		end
		check(
			seated == Config.Sim.MAX_CREW,
			string.format("hideout: seat cap %d holds (%d seated)", Config.Sim.MAX_CREW, seated)
		)
		-- the crew comes back beside its van: clear of every van, inside the garage
		local besideOk = 0
		for i = 1, Config.Sim.MAX_CREW do
			local cf = Vans.besideVan(2, i) :: CFrame
			local clear = true
			for _, d in garage:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("EH_Kind") == "garageVan" then
					local l = d.CFrame:PointToObjectSpace(cf.Position)
					if math.abs(l.X) < d.Size.X / 2 + 1 and math.abs(l.Z) < d.Size.Z / 2 + 1 then
						clear = false
					end
				end
			end
			local p = cf.Position
			if clear and math.abs(p.X) < Config.Lobby.HALF_X and math.abs(p.Z) < Config.Lobby.HALF_Z then
				besideOk += 1
			end
		end
		check(besideOk == Config.Sim.MAX_CREW, "hideout: the crew comes back beside its van, clear of the vans")
		-- the remote: Heist.Ready's validator, and no Heist.* remote outside Protocol.REMOTE
		check(
			VanRules.validReadyArg({ op = "claim", bay = 2 })
				and VanRules.validReadyArg(true)
				and VanRules.validReadyArg(nil)
				and not VanRules.validReadyArg({ op = "claim", bay = 2, hack = 1 })
				and not VanRules.validReadyArg({ op = "claim", bay = 99 })
				and not VanRules.validReadyArg("claim"),
			"hideout: Heist.Ready validates the lobby action table"
		)
		local allowed = {}
		for _, name in Protocol.REMOTE do
			allowed[name] = true
		end
		local extra = {}
		local lf = ReplicatedStorage:FindFirstChild("LihFolkRemotes")
		for _, r in (if lf then lf:GetChildren() else {}) do
			if string.sub(r.Name, 1, 6) == "Heist." and not allowed[r.Name] then
				table.insert(extra, r.Name)
			end
		end
		check(#extra == 0, "hideout: no new Heist.* remote names (" .. table.concat(extra, ", ") .. ")")
		for bay = 1, HD.BAYS do
			Vans.render(bay, nil, {})
		end
	end)
	check(okLobby, "hideout section ran" .. (if okLobby then "" else ": " .. tostring(lobbyErr)))
end

-- 13. LOBBY 2: Quick Crew, the laptop's board, van styles. Quick Crew with fake members on the real anchors (Luau
-- Execution has no players): a leader opens VanBay6 from the crew sign, three seekers are matched into it oldest
-- first and walk in (a held seat joins the crew), a fourth waits (the seat cap), a van that is not open never takes a
-- stranger, closing gives the held seats back; Heist/Vans writes Open / Held. The board (Data/HaulBoardService):
-- an untainted run of today's vault boards and publishes (ReplicatedStorage.EH_HaulBoard), a tainted, a Relaxed and
-- a catch-up run never do. Van styles: each style's kit body swapped onto a bay (Lobby.setVanStyle through
-- Vans.style) on the same pivot: every seat anchor and van point unchanged and inside / beside the new body, the
-- style's paint piece takes the van's paint; a precise copy of each style's body has its side door open on local
-- Z = DOOR_Z and its cab low on local X = CAB_X.
do
	local okL2, l2Err = pcall(function()
		local AssetService = game:GetService("AssetService")
		local heistDir = server:WaitForChild("Heist")
		local sharedDir = ReplicatedStorage:WaitForChild("Shared")
		local Config = require(sharedDir:WaitForChild("Config")) :: any
		local HD = Config.Hideout
		local Lobby = require(heistDir:WaitForChild("Lobby"))
		local Vans = require(heistDir:WaitForChild("Vans"))
		local KitService = require(server:WaitForChild("Kit"):WaitForChild("KitService"))
		local VanRules = require(sharedDir:WaitForChild("Heist"):WaitForChild("VanRules"))
		local QuickCrew = require(sharedDir:WaitForChild("Heist"):WaitForChild("QuickCrew"))
		local HaulBoard = require(sharedDir:WaitForChild("Data"):WaitForChild("HaulBoard"))
		local Calendar = require(sharedDir:WaitForChild("Data"):WaitForChild("Calendar"))
		local HaulBoardService = require(server:WaitForChild("Data"):WaitForChild("HaulBoardService"))
		local garage = Lobby.model() or Lobby.build(nil)
		local folder = Vans.build(nil)
		if not (garage and folder) then
			check(false, "lobby 2: no garage")
			return
		end
		local cap = math.min(Config.Sim.MAX_CREW, #HD.VAN.SEATS)

		---------------------------------------------------------------- Quick Crew with fake members
		local sign = Lobby.anchor("CrewSign")
		check(sign ~= nil, "quick crew: the crew sign's anchor")
		-- a prompt shown at the sign (REACH from the eye, the station open until FOCUS_LEAVE_STUDS) is an op the
		-- server takes (SIGN_REACH from the root)
		check(
			HD.REACH + HD.FOCUS_LEAVE_STUDS + 2 <= HD.QUICK.SIGN_REACH,
			"quick crew: SIGN_REACH covers the sign's prompt and station"
		)
		local st = VanRules.new()
		local q = QuickCrew.new()
		local H = -601
		local host: VanRules.Crew = { id = 9601, leaderId = H, members = { H } }
		local doorD = 3 -- standing at the side door
		check(VanRules.claim(st, 6, host, H, doorD), "quick crew: the host claims VanBay6")
		local okOpen = VanRules.setOpen(st, 6, host, H, true, 1, 0)
		local van6 = VanRules.van(st, 6) :: VanRules.Van
		check(okOpen and van6.open and van6.mode == VanRules.MODE.Crew, "quick crew: opened from the sign (CREW mode)")
		-- a second, closed van: strangers never sit there
		local K = -602
		local closed: VanRules.Crew = { id = 9602, leaderId = K, members = { K } }
		VanRules.claim(st, 8, closed, K, doorD)
		VanRules.setMode(st, 8, closed, K, VanRules.MODE.Crew, doorD)
		local seekers = { -611, -612, -613, -614 }
		for i, uid in seekers do
			QuickCrew.optIn(q, uid, i)
		end
		local function open(): { QuickCrew.OpenVan }
			local out = {}
			for bay, v in st.vans do
				if v.open and v.mode == VanRules.MODE.Crew then
					local crew = if bay == 6 then host else closed
					table.insert(
						out,
						{ bay = bay, crewSize = #crew.members, openedAt = v.openedAt, leaderId = v.leaderId }
					)
				end
			end
			return out
		end
		local res = QuickCrew.pass(q, open(), 10)
		check(
			#res.matched == cap - 1
				and QuickCrew.holdOf(q, -611) == 6
				and QuickCrew.holdOf(q, -614) == nil
				and QuickCrew.heldIn(q, 8) == 0,
			string.format("quick crew: %d matched into the open van oldest first, the 4th waits", #res.matched)
		)
		Vans.render(6, van6, { [H] = "FakeHost" }, QuickCrew.heldIn(q, 6))
		local rig6 = folder:WaitForChild("Van6") :: Model
		check(
			rig6:GetAttribute("Open") == true and rig6:GetAttribute("Held") == cap - 1,
			"quick crew: Heist/Vans writes Open and Held"
		)
		-- the walk-in: each held seat joins the crew; the cap holds
		local joined = 0
		for _, uid in seekers do
			local held = QuickCrew.heldIn(q, 6, uid)
			local okSit, code = VanRules.canSit(
				st,
				6,
				{ userId = uid, crewId = 0, friend = false, quick = QuickCrew.holdOf(q, uid) == 6 },
				#host.members + held,
				doorD
			)
			if okSit and code == "Join" then
				QuickCrew.drop(q, uid)
				table.insert(host.members, uid)
				VanRules.syncSeats(van6, host)
				joined += 1
			end
		end
		check(
			joined == cap - 1 and #host.members == cap and #host.members <= Config.Sim.MAX_CREW,
			string.format("quick crew: %d walked in, crew of %d (cap %d)", joined, #host.members, cap)
		)
		local okStranger, codeStranger =
			VanRules.canSit(st, 8, { userId = -614, crewId = 0, friend = false, quick = true }, 1, doorD)
		check(not okStranger and codeStranger == "NotFriend", "quick crew: a van that is not open takes no stranger")
		local res2 = QuickCrew.pass(q, open(), 11)
		check(#res2.matched == 0 and QuickCrew.isSeeking(q, -614), "quick crew: a full van takes nobody; -614 waits")
		-- the host closes: held seats go back (here: a second open van, then closed)
		local okOpen8 = VanRules.setOpen(st, 8, closed, K, true, 12, 0)
		local res3 = QuickCrew.pass(q, open(), 13)
		VanRules.setOpen(st, 8, closed, K, false, 14, nil)
		local back = QuickCrew.release(q, 8)
		check(
			okOpen8 and #res3.matched == 1 and #back == 1 and QuickCrew.isSeeking(q, -614),
			"quick crew: closing a van gives its held seat back"
		)
		check(
			VanRules.validReadyArg({ op = "quick" })
				and VanRules.validReadyArg({ op = "open", bay = 6 })
				and VanRules.validReadyArg({ op = "style", bay = 6, n = 2 })
				and not VanRules.validReadyArg({ op = "quick", bay = 6 })
				and not VanRules.validReadyArg({ op = "style", bay = 6 }),
			"quick crew: Heist.Ready validates the new ops"
		)
		for bay = 1, HD.BAYS do
			Vans.render(bay, nil, {})
		end

		---------------------------------------------------------------- the board: untainted vs tainted
		HaulBoardService.resetForTest()
		local today = Calendar.dayIndex(os.time(), Config.Data.Daily.RESET_OFFSET_HOURS)
		local function result(haul: number, tainted: boolean, relaxed: boolean): any
			return { cleared = true, haul = haul, clones = 3, timeMs = 25000, tainted = tainted, relaxed = relaxed }
		end
		local okA = HaulBoardService.submit(-701, "FakeAda", today, result(400, false, false))
		local okT = HaulBoardService.submit(-702, "FakeTaint", today, result(9000, true, false))
		local okR = HaulBoardService.submit(-703, "FakeRelax", today, result(8000, false, true))
		local okC = HaulBoardService.submit(-704, "FakeCatch", today - 1, result(7000, false, false))
		local okB = HaulBoardService.submit(-705, "FakeBo", today, result(600, false, false))
		check(
			okA and okB and not okT and not okR and not okC,
			"board: untainted runs of today board; tainted, Relaxed and catch-up runs do not"
		)
		local rank = HaulBoardService.rankOf(-701)
		check(rank == 2 and HaulBoardService.rankOf(-702) == nil, "board: ranks (the tainted run is off the board)")
		task.wait(Config.Data.Board.PUBLISH_MIN_SECONDS + 0.3)
		local bf = ReplicatedStorage:FindFirstChild(HaulBoardService.FOLDER)
		local rows = HaulBoard.decode(bf and bf:GetAttribute("Rows"))
		check(
			bf ~= nil
				and bf:GetAttribute("Day") == today
				and #rows == 2
				and rows[1].userId == -705
				and rows[1].haul == 600
				and rows[2].name == "FakeAda",
			string.format("board: published and read back (%d rows)", #rows)
		)
		HaulBoardService.resetForTest()

		---------------------------------------------------------------- van styles on the real kit
		if not Lobby.isDressed() then
			table.insert(results, "      van styles: the garage is not dressed (no kit): swap checks skipped")
			return
		end
		local bay = 4
		local rig = folder:WaitForChild("Van" .. bay) :: Model
		local before: { [string]: CFrame } = {}
		for _, d in rig:GetChildren() do
			if d:IsA("BasePart") then
				before[d.Name] = d.CFrame
			end
		end
		local anchor = Vans.anchor(bay) :: CFrame
		local kit = garage:WaitForChild("Kit", 5) :: Model
		local doorPart = rig:WaitForChild("Door", 5) :: BasePart
		for n, style in HD.VAN.STYLES do
			local okSwap = Vans.style(bay, n)
			local pieces, paintPiece = 0, nil
			local lo = Vector3.new(math.huge, math.huge, math.huge)
			local hi = -lo
			for _, d in kit:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("EH_Bay") == bay then
					if d:GetAttribute("EH_VanStyle") == n then
						pieces += 1
					end
					if d:GetAttribute("EH_VanPaint") == true then
						paintPiece = d
					end
					-- the piece's box in the anchor's frame (the van's yaw is a multiple of 90)
					local c = anchor:PointToObjectSpace(d.Position)
					local s = anchor:VectorToObjectSpace(d.CFrame:VectorToWorldSpace(d.Size))
					local half = Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z)) / 2
					lo = lo:Min(c - half)
					hi = hi:Max(c + half)
				end
			end
			local moved = 0
			for _, d in rig:GetChildren() do
				if d:IsA("BasePart") and before[d.Name] and d.CFrame ~= before[d.Name] and d.Name ~= "DoorLeaf" then
					moved += 1
				end
			end
			local seatsIn = 0
			for k = 1, #HD.VAN.SEATS do
				local seat = rig:FindFirstChild("Seat" .. k)
				local p = if seat and seat:IsA("BasePart") then anchor:PointToObjectSpace(seat.Position) else nil
				if p and p.X > lo.X and p.X < hi.X and p.Z > lo.Z and p.Z < hi.Z and p.Y > lo.Y and p.Y < hi.Y then
					seatsIn += 1
				end
			end
			local doorAt = anchor:PointToObjectSpace(doorPart.Position)
			Vans.paint(bay, 2)
			local painted = paintPiece ~= nil and (paintPiece :: BasePart).Color == Vans.paintColour(bay, 2)
			check(
				okSwap
					and pieces >= 2
					and paintPiece ~= nil
					and (paintPiece :: BasePart).Name == style.paint
					and painted
					and moved == 0
					and seatsIn == #HD.VAN.SEATS
					and doorAt.Z * HD.VAN.DOOR_Z > 0,
				string.format(
					"van styles: %s on VanBay%d (%d pieces, paint %s, rigs moved %d, seats inside %d / %d)",
					style.id,
					bay,
					pieces,
					tostring(paintPiece and (paintPiece :: BasePart).Name),
					moved,
					seatsIn,
					#HD.VAN.SEATS
				)
			)
			-- a precise copy of the style's body: the open side door on local Z = DOOR_Z, the cab low on X = CAB_X
			if n > 1 then
				local src = KitService.clone(style.group, {})
				local okM, body = pcall(function()
					return AssetService:CreateMeshPartAsync(
						(src :: MeshPart).MeshContent,
						{ CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition }
					)
				end)
				if okM and body and src then
					body.Size = src.Size
					body.Anchored = true
					body.CanQuery = true
					local spec = KitService.spec(style.group)
					local cy = if spec
						then spec.origin[2] + (spec.boundsMin[2] + spec.boundsMax[2]) / 2
						else src.Size.Y / 2
					local cz = if spec then spec.origin[3] + (spec.boundsMin[3] + spec.boundsMax[3]) / 2 else 0
					body.CFrame = CFrame.new(0, 800 + cy, cz) -- the piece's centre at its scene place (origin at y 800)
					body.Parent = workspace
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = { body }
					local dz = HD.VAN.DOOR_Z
					local function reach(fromZ: number): number
						local hit =
							workspace:Raycast(Vector3.new(0.1, 804.5, fromZ), Vector3.new(0, 0, -fromZ * 2), params)
						return if hit then math.abs(hit.Position.Z - fromZ) else math.huge
					end
					local function top(x: number): number
						local hit = workspace:Raycast(Vector3.new(x, 830, 0), Vector3.new(0, -40, 0), params)
						return if hit then hit.Position.Y - 800 else 0
					end
					local doorSide, farSide = reach(dz * 10), reach(-dz * 10)
					-- the nose (a baker's box runs on over the cab, so probe at the bumper end, not mid-cab)
					local cab, rear = top(HD.VAN.CAB_X * 6.9), top(-HD.VAN.CAB_X * 6)
					check(
						doorSide > 10 and farSide < 8 and cab < rear - 1,
						string.format(
							"van styles: %s door side open (ray in %.1f vs %.1f), cab low (top %.1f vs %.1f)",
							style.id,
							doorSide,
							farSide,
							cab,
							rear
						)
					)
					body:Destroy()
				else
					table.insert(
						results,
						"      van styles: no precise copy of " .. style.group .. " (" .. tostring(body) .. ")"
					)
				end
			end
		end
		Vans.render(bay, nil, {})
		check(Lobby.vanStyle(bay) == 1, "van styles: a free van is the step van again")
	end)
	check(okL2, "lobby 2 section ran" .. (if okL2 then "" else ": " .. tostring(l2Err)))
end

-- 14. Random characters and look pitch. A new profile (PlayerData.prepare, as a joining player's) gets its random
-- outfit from DataService.firstOutfit: every slot a wearable id, the flag set, valid as saved, the same after a real
-- DataStore round trip on a _TEST_ key, and never rolled again; a Rookie dressed in it wears its knit colour. Fresh
-- players differ with high probability. Look pitch: the Heist.Ready remote exists, its Net validator takes an
-- in-range { op = "look", n } and refuses bad ones, the remote's limit lets 10 Hz through and stops 60 Hz spam, and
-- Heist/LookSync writes LookPitch on the character, drops a look sent too soon and a bad n.
do
	local okRl, rlErr = pcall(function()
		local heistDir = server:WaitForChild("Heist")
		local sharedDir = ReplicatedStorage:WaitForChild("Shared")
		local Config = require(sharedDir:WaitForChild("Config")) :: any
		local heistShared = sharedDir:WaitForChild("Heist")
		local Outfit = require(heistShared:WaitForChild("Outfit"))
		local LookPitch = require(heistShared:WaitForChild("LookPitch"))
		local VanRules = require(heistShared:WaitForChild("VanRules"))
		local Rookie = require(heistDir:WaitForChild("Rookie"))
		local LookSync = require(heistDir:WaitForChild("LookSync"))
		local RateLimit = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("RateLimit"))
		local R = Config.Rookie

		-- a new player's random outfit
		local prof = PlayerData.prepare(nil, Schema.VERSION, Schema.MIGRATIONS, makeData)
		assert(prof, "a new profile")
		local h = prof.Data.Heist
		Schema.sanitize(h)
		check(h.outfitRolled == false, "random outfit: a new profile has not rolled yet")
		check(DataService.firstOutfit(h) == true and h.outfitRolled == true, "random outfit: rolled at first load")
		local wearable = true
		for _, slot in R.SLOTS do
			wearable = wearable and (Outfit.canWear(h, slot, h.outfit[slot]))
		end
		check(wearable, "random outfit: every slot a wearable id (" .. Outfit.key(h.outfit) .. ")")
		check(
			#Schema.sanitize(h) == 0 and PlayerData.findUnsavable(prof.Data) == nil,
			"random outfit: valid and savable"
		)
		local key = Outfit.key(h.outfit)
		check(DataService.firstOutfit(h) == false and Outfit.key(h.outfit) == key, "random outfit: never rolled again")
		if inTestUniverse then
			local dsKey = GameConfig.Data.TEST_PREFIX .. "outfit_" .. HttpService:GenerateGUID(false)
			assert(Keys.isWritable(dsKey, true), "refusing a non-test key")
			local store = DataStoreService:GetDataStore(GameConfig.Data.STORE_NAME)
			store:SetAsync(dsKey, { Schema = Schema.VERSION, Data = prof.Data })
			local options = Instance.new("DataStoreGetOptions")
			options.UseCache = false
			local back = store:GetAsync(dsKey, options)
			store:RemoveAsync(dsKey)
			local again = PlayerData.prepare(back, Schema.VERSION, Schema.MIGRATIONS, makeData)
			local hb = again and again.Data.Heist
			check(
				hb ~= nil
					and #Schema.sanitize(hb) == 0
					and Outfit.key(hb.outfit) == key
					and DataService.firstOutfit(hb) == false,
				"random outfit: saved and read back unchanged (DataStore, _TEST_ key)"
			)
		end
		local m = Rookie.build(h.outfit, nil, "constraint")
		local hand = m:FindFirstChild("RightHand")
		check(
			m:GetAttribute("EH_Outfit") == key
				and hand ~= nil
				and hand:IsA("BasePart")
				and hand.Color:ToHex() == Color3.fromHex(Outfit.gloveHex(h.outfit)):ToHex(),
			"random outfit: a Rookie wears it (gloves " .. Outfit.gloveHex(h.outfit) .. ")"
		)
		m:Destroy()
		local differ, N = 0, 300
		for _ = 1, N do
			local a = PlayerData.prepare(nil, Schema.VERSION, Schema.MIGRATIONS, makeData)
			local b = PlayerData.prepare(nil, Schema.VERSION, Schema.MIGRATIONS, makeData)
			if a and b then
				DataService.firstOutfit(a.Data.Heist)
				DataService.firstOutfit(b.Data.Heist)
				if Outfit.key(a.Data.Heist.outfit) ~= Outfit.key(b.Data.Heist.outfit) then
					differ += 1
				end
			end
		end
		check(differ / N >= 0.88, string.format("random outfit: %d / %d pairs of new players differ", differ, N))

		-- look pitch
		local remotes = ReplicatedStorage:FindFirstChild("LihFolkRemotes")
		check(remotes ~= nil and remotes:FindFirstChild("Heist.Ready") ~= nil, "look: rides the existing Heist.Ready")
		local up = LookPitch.quantise(25)
		check(VanRules.validReadyArg({ op = "look", n = up }), "look: an in-range pitch passes the Net validator")
		local badOk = false
		for _, bad in { { op = "look" }, { op = "look", n = 0 }, { op = "look", n = 99 }, { op = "look", n = 0.5 } } do
			badOk = badOk or VanRules.validReadyArg(bad)
		end
		check(not badOk, "look: bad looks fail the Net validator")
		local t = 0
		local limiter = RateLimit.new(Config.Heist.RATE.Ready.burst, Config.Heist.RATE.Ready.perSecond, function()
			return t
		end)
		local passed10 = 0
		for i = 1, 50 do
			t = i / 10
			if limiter:Allow("p10") then
				passed10 += 1
			end
		end
		local passed60 = 0
		for i = 1, 300 do
			t = 100 + i / 60
			if limiter:Allow("p60") then
				passed60 += 1
			end
		end
		check(
			passed10 == 50 and passed60 < 120,
			string.format("look: 10 Hz passes (%d / 50), 60 Hz spam does not (%d / 300)", passed10, passed60)
		)
		local char = Instance.new("Model")
		char.Name = "LookDummy"
		local A = R.LOOK.ATTRIBUTE
		local key2 = {}
		check(
			LookSync.accept(key2, char, up, 1) and char:GetAttribute(A) == LookPitch.degrees(up),
			"look: accepted, LookPitch written"
		)
		check(
			not LookSync.accept(key2, char, LookPitch.quantise(-10), 1.02),
			"look: a look 20 ms later is dropped (spam)"
		)
		check(char:GetAttribute(A) == LookPitch.degrees(up), "look: the dropped look changed nothing")
		check(not LookSync.accept(key2, char, 99, 2), "look: a bad n is refused")
		check(not LookSync.accept(key2, char, 0 / 0, 3), "look: NaN is refused")
		check(
			LookSync.accept(key2, char, 1, 4) and char:GetAttribute(A) == -R.LOOK.MAX_DEG,
			"look: the next look counts"
		)
		check(not LookSync.accept({}, nil, up, 5), "look: no character, nothing")
		LookSync.forget(key2)
		char:Destroy()
	end)
	check(okRl, "random characters and look section ran" .. (if okRl then "" else ": " .. tostring(rlErr)))
end

-- 15. The PARTY sheet (PARTY track, Config.Hideout.PARTY): the van leader's size / privacy / kick ops on the real
-- anchors with fake members (Luau Execution has no players). L claims VanBay7 and sets crew size 2, friends only:
-- a stranger cannot sit, a friend can, and the next friend finds it full (the size cap); Heist/Vans writes Size and
-- Privacy and fades the seats past the size; a kick frees the seat and keeps that player out (and out of Quick Crew
-- for that van); size 4 + OPEN lets Quick Crew match strangers into the free seats; the validator takes the new ops.
do
	local okParty, partyErr = pcall(function()
		local heistDir = server:WaitForChild("Heist")
		local sharedDir = ReplicatedStorage:WaitForChild("Shared")
		local Config = require(sharedDir:WaitForChild("Config")) :: any
		local HD = Config.Hideout
		local Lobby = require(heistDir:WaitForChild("Lobby"))
		local Vans = require(heistDir:WaitForChild("Vans"))
		local VanRules = require(sharedDir:WaitForChild("Heist"):WaitForChild("VanRules"))
		local QuickCrew = require(sharedDir:WaitForChild("Heist"):WaitForChild("QuickCrew"))
		local garage = Lobby.model() or Lobby.build(nil)
		local folder = Vans.build(nil)
		if not (garage and folder) then
			check(false, "party: no garage")
			return
		end
		local bay = 7
		local anchor = Vans.anchor(bay)
		check(anchor ~= nil, "party: VanBay7's anchor")
		if not anchor then
			return
		end
		-- standing outside the side door (the server measures from the root to the nearest van point)
		local doorPos = Vans.point(bay, "door") :: Vector3
		local near = ((doorPos + anchor.LookVector * 3 + Vector3.new(0, -1.2, 0)) - doorPos).Magnitude
		local L, F, G, S = -801, -802, -803, -804
		local crewL: VanRules.Crew = { id = 9801, leaderId = L, members = { L } }
		local st = VanRules.new()
		check(VanRules.claim(st, bay, crewL, L, near), "party: L claims VanBay7")
		local van = VanRules.van(st, bay) :: VanRules.Van
		local friends = table.find(HD.PARTY.PRIVACY, "friends") :: number
		local open = table.find(HD.PARTY.PRIVACY, "open") :: number
		local okSize = VanRules.setSize(st, bay, crewL, L, 2, #crewL.members, near)
		local okPriv = VanRules.setPrivacy(st, bay, crewL, L, friends, 1, near)
		local names = { [L] = "FakeL", [F] = "FakeF", [G] = "FakeG", [S] = "FakeS" }
		Vans.render(bay, van, names, 0)
		local rig = folder:WaitForChild("Van" .. bay) :: Model
		local plate = rig:WaitForChild("Plate") :: BasePart
		local gui = plate:FindFirstChildOfClass("SurfaceGui")
		local pip4 = gui and gui:FindFirstChild("Pip4")
		check(
			okSize
				and okPriv
				and van.mode == VanRules.MODE.Crew
				and rig:GetAttribute("Size") == 2
				and rig:GetAttribute("Privacy") == "friends"
				and pip4 ~= nil
				and (pip4 :: Frame).BackgroundTransparency > 0.8,
			"party: size 2 + friends only (CREW mode, Size / Privacy written, seats past the size faded)"
		)
		local okS, codeS = VanRules.canSit(st, bay, { userId = S, crewId = 0, friend = false }, 1, near)
		check(not okS and codeS == "NotFriend", "party: a stranger cannot sit in a friends-only van")
		local okF, codeF = VanRules.canSit(st, bay, { userId = F, crewId = 0, friend = true }, 1, near)
		check(okF and codeF == "Join", "party: a friend can")
		crewL.members = { L, F }
		VanRules.syncSeats(van, crewL)
		VanRules.markSeated(st, bay, F, true)
		local okG, codeG = VanRules.canSit(st, bay, { userId = G, crewId = 0, friend = true }, 2, near)
		check(not okG and codeG == "Full", "party: the size cap holds (2 of 2: the next friend is refused)")
		local okLow, codeLow = VanRules.setSize(st, bay, crewL, L, 2, 2, near)
		local okBelow = VanRules.setSize(st, bay, { id = 9801, leaderId = L, members = { L, F, G } }, L, 2, 3, near)
		check(okLow and codeLow == "Ok" and not okBelow, "party: the size never drops below the seats taken")
		-- the kick: the seat frees, the player stays out
		local clock = 100
		local okK, codeK, kicked = VanRules.kick(st, bay, crewL, L, 2, clock, near)
		crewL.members = { L } -- the server takes them out of the crew (back to the lobby, solo)
		VanRules.syncSeats(van, crewL)
		Vans.render(bay, van, names, 0)
		local card2 = rig:WaitForChild("SeatCard2") :: BasePart
		local cardGui = card2:FindFirstChildOfClass("SurfaceGui")
		local cardName = cardGui and cardGui:FindFirstChild("Name")
		check(
			okK
				and codeK == "Ok"
				and kicked == F
				and #van.seats == 1
				and cardName ~= nil
				and (cardName :: TextLabel).Text == "FREE SEAT",
			"party: a kick frees the seat (seat 2's card says FREE SEAT)"
		)
		local okBack, codeBack = VanRules.canSit(
			st,
			bay,
			{ userId = F, crewId = 0, friend = true, kicked = VanRules.isKicked(van, F, clock + 1) },
			1,
			near
		)
		local okG2 = VanRules.canSit(st, bay, { userId = G, crewId = 0, friend = true }, 1, near)
		check(not okBack and codeBack == "Kicked" and okG2, "party: the kicked friend stays out, another friend fits")
		-- OPEN + size 4: Quick Crew matches strangers into the free seats, never the kicked player
		local okOpen = VanRules.setPrivacy(st, bay, crewL, L, open, clock, near)
		local okBig = VanRules.setSize(st, bay, crewL, L, 4, 1, near)
		local q = QuickCrew.new()
		QuickCrew.optIn(q, F, 1)
		QuickCrew.optIn(q, S, 2)
		QuickCrew.optIn(q, -805, 3)
		QuickCrew.optIn(q, -806, 4)
		local blocked = { [F] = VanRules.isKicked(van, F, clock + 1) }
		local res = QuickCrew.pass(q, {
			{
				bay = bay,
				crewSize = #crewL.members,
				openedAt = van.openedAt,
				leaderId = L,
				size = VanRules.capOf(van),
				blocked = blocked,
			},
		}, clock + 1)
		Vans.render(bay, van, names, QuickCrew.heldIn(q, bay))
		check(
			okOpen
				and okBig
				and van.open
				and #res.matched == 3
				and QuickCrew.holdOf(q, F) == nil
				and QuickCrew.holdOf(q, S) == bay
				and rig:GetAttribute("Privacy") == "open"
				and rig:GetAttribute("Open") == true
				and rig:GetAttribute("Held") == 3,
			string.format("party: OPEN lets Quick Crew match (%d held, the kicked one waits)", #res.matched)
		)
		local okSq = VanRules.canSit(st, bay, { userId = S, crewId = 0, friend = false, quick = true }, 1 + 2, near)
		check(okSq, "party: the matched stranger sits in the open van")
		-- back to friends only: strangers are out again
		VanRules.setPrivacy(st, bay, crewL, L, friends, clock + 2, near)
		local okSf = VanRules.canSit(st, bay, { userId = S, crewId = 0, friend = false, quick = true }, 1, near)
		check(not okSf and not van.open, "party: friends only closes the van to Quick Crew")
		check(
			VanRules.validReadyArg({ op = "size", bay = bay, n = 2 })
				and VanRules.validReadyArg({ op = "privacy", bay = bay, n = open })
				and VanRules.validReadyArg({ op = "kick", bay = bay, n = 2 })
				and not VanRules.validReadyArg({ op = "size", bay = bay, n = 9 })
				and not VanRules.validReadyArg({ op = "kick", bay = bay, n = 1 })
				and not VanRules.validReadyArg({ op = "privacy", bay = bay }),
			"party: Heist.Ready validates size / privacy / kick"
		)
		Vans.render(bay, nil, {})
		check(rig:GetAttribute("Size") == VanRules.cap(), "party: a free van takes every seat again")
	end)
	check(okParty, "party section ran" .. (if okParty then "" else ": " .. tostring(partyErr)))
end

-- 16. Badges (BADGES track; Shared/Heist/Badges, server Data/Awards). Owner detection in the real engine (this test
-- experience is user-owned) and with a fake owner id: the boss attributes, time together earns Met the Boss for
-- the others and never for the boss. Awards through a FAKE BadgeService (no real badge is ever awarded): one API
-- call per badge, repeats answered from the cache, a failed award that the player already owns is marked sent, a
-- disabled badge is skipped, an id of 0 calls nothing but stays earned. The saved flags (Heist.badges / badgesSent)
-- survive a real DataStore round trip on a _TEST_ key and sanitize clean.
do
	local okBadges, badgesErr = pcall(function()
		local sharedDir = ReplicatedStorage:WaitForChild("Shared")
		local Config = require(sharedDir:WaitForChild("Config")) :: any
		local Badges = require(sharedDir:WaitForChild("Heist"):WaitForChild("Badges"))
		local Awards = require(server:WaitForChild("Data"):WaitForChild("Awards"))

		-- real owner detection
		local owner = Awards.resolveOwner()
		check(
			game.CreatorType ~= Enum.CreatorType.User or owner == game.CreatorId,
			string.format("badges: the owner is the experience's creator (%d, %s)", owner, tostring(game.CreatorType))
		)
		check(owner > 0, "badges: an owner was found")

		-- fake players and a fake BadgeService
		local function fakePlayer(id: number): Folder
			local f = Instance.new("Folder")
			f.Name = "FakePlayer" .. id
			f:SetAttribute("UserId", id)
			return f
		end
		local OWNER, A, B = 9000000101, 9000000102, 9000000103 -- fake ids (bossIds takes positive ids only)
		local boss, pa, pb = fakePlayer(OWNER), fakePlayer(A), fakePlayer(B)
		local here = { boss, pa, pb }
		local calls = { award = 0, has = 0, info = 0 }
		local failNext: { [number]: boolean } = {}
		local owns: { [number]: boolean } = {}
		local fakeBadges = {}
		function fakeBadges:GetBadgeInfoAsync(id: number)
			calls.info += 1
			return { IsEnabled = id ~= 999, Name = "fake" }
		end
		function fakeBadges:AwardBadgeAsync(userId: number, _id: number): boolean
			calls.award += 1
			if failNext[userId] then
				failNext[userId] = nil
				error("HTTP 500 (fake)")
			end
			return true
		end
		function fakeBadges:UserHasBadgeAsync(userId: number, _id: number): boolean
			calls.has += 1
			return owns[userId] == true
		end
		local ids = { welcome = 111, first_heist = 222, ghost = 999, first_clone = 0 }
		Awards.resetForTests()
		Awards.start({
			noLoops = true,
			badgeService = fakeBadges,
			ownerId = OWNER,
			players = function()
				return here
			end,
			present = function(p: any): boolean
				return table.find(here, p) ~= nil
			end,
			userIdOf = function(p: any): number
				return p:GetAttribute("UserId")
			end,
			idOf = function(key: string): number
				return ids[key] or 444
			end,
		})
		check(Awards.ownerId() == OWNER and Awards.isBoss(OWNER), "badges: a fake owner id is the boss")

		-- the boss's marks and time together
		check(Awards.refreshBoss() == OWNER, "badges: the boss is found among the players")
		check(
			boss:GetAttribute(Badges.ATTR_BOSS) == true
				and pa:GetAttribute(Badges.ATTR_BOSS) == nil
				and ReplicatedStorage:GetAttribute(Badges.ATTR_BOSS_HERE) == OWNER,
			"badges: Boss on the owner, BossUserId on ReplicatedStorage"
		)
		local need = Config.Badges.BOSS_TOGETHER_SECONDS
		local steps = 0
		while not Awards.hasEarned(pa, "met_the_boss") and steps < 100 do
			Awards.bossStep(Config.Badges.BOSS_TICK_SECONDS)
			steps += 1
		end
		check(
			Awards.hasEarned(pa, "met_the_boss")
				and Awards.hasEarned(pb, "met_the_boss")
				and not Awards.hasEarned(boss, "met_the_boss"),
			string.format(
				"badges: Met the Boss after %d s together, never for the boss",
				steps * Config.Badges.BOSS_TICK_SECONDS
			)
		)
		check(steps * Config.Badges.BOSS_TICK_SECONDS >= need, "badges: not before BOSS_TOGETHER_SECONDS")
		check(
			Badges.parseToast(pa:GetAttribute(Badges.ATTR_TOAST)) == "met_the_boss",
			"badges: the card attribute is set"
		)

		-- awards through the fake BadgeService
		local before = calls.award
		check(Awards.earn(pa, "welcome") == true, "badges: welcome earned")
		check(Awards.earn(pa, "welcome") == false, "badges: earned once")
		Awards.drain(math.huge)
		check(Awards.wasSent(pa, "welcome") and calls.award >= before + 1, "badges: awarded through BadgeService")
		local afterFirst = calls.award
		Awards.earn(pa, "welcome")
		Awards.drain(math.huge)
		check(calls.award == afterFirst, "badges: a sent badge never calls the API again")
		-- a failed award the player already owns: marked sent after UserHasBadgeAsync
		failNext[B] = true
		owns[B] = true
		Awards.earn(pb, "first_heist")
		Awards.drain(math.huge)
		check(Awards.wasSent(pb, "first_heist") and calls.has >= 1, "badges: failure + already owned = sent")
		-- a failure then success: retried with backoff
		failNext[A] = true
		Awards.earn(pa, "crew_up")
		Awards.drain(math.huge)
		check(not Awards.wasSent(pa, "crew_up") and Awards.queued() >= 1, "badges: a failed award waits to retry")
		Awards.drain(math.huge)
		check(Awards.wasSent(pa, "crew_up"), "badges: the retry is sent")
		-- disabled (id 999) and not created (id 0)
		local n0 = calls.award
		Awards.earn(pa, "ghost")
		Awards.earn(pa, "first_clone")
		Awards.drain(math.huge)
		check(calls.award == n0, "badges: a disabled badge and an id of 0 call nothing")
		check(
			Awards.hasEarned(pa, "first_clone") and not Awards.wasSent(pa, "first_clone"),
			"badges: id 0 stays earned, unsent"
		)
		-- the heist-end facts
		Awards.onHeistOver(pb, {
			complete = true,
			tainted = false,
			relaxed = false,
			guarded = true,
			spottedFinal = false,
			inFinal = true,
			crewPlayers = 2,
		})
		check(
			Awards.hasEarned(pb, "ghost") and Awards.hasEarned(pb, "crew_up"),
			"badges: Ghost and Crew Up from heist facts"
		)

		-- the saved flags: DataStore round trip on a _TEST_ key
		local prof = PlayerData.prepare(nil, Schema.VERSION, Schema.MIGRATIONS, makeData)
		assert(prof, "a new profile")
		local h = prof.Data.Heist
		h.badges.welcome = os.time()
		h.badges.first_clone = os.time()
		h.badgesSent.welcome = true
		check(
			#Schema.sanitize(h) == 0 and PlayerData.findUnsavable(prof.Data) == nil,
			"badges: flags valid and savable"
		)
		if inTestUniverse then
			local dsKey = GameConfig.Data.TEST_PREFIX .. "badges_" .. HttpService:GenerateGUID(false)
			assert(Keys.isWritable(dsKey, true), "refusing a non-test key")
			local store = DataStoreService:GetDataStore(GameConfig.Data.STORE_NAME)
			store:SetAsync(dsKey, { Schema = Schema.VERSION, Data = prof.Data })
			local options = Instance.new("DataStoreGetOptions")
			options.UseCache = false
			local back = store:GetAsync(dsKey, options)
			store:RemoveAsync(dsKey)
			local again = PlayerData.prepare(back, Schema.VERSION, Schema.MIGRATIONS, makeData)
			local hb = again and again.Data.Heist
			check(
				hb ~= nil
					and #Schema.sanitize(hb) == 0
					and hb.badges.welcome == h.badges.welcome
					and hb.badgesSent.welcome == true
					and hb.badges.first_clone ~= nil
					and hb.badgesSent.first_clone == nil
					and #Badges.pending(hb.badges, hb.badgesSent) == 1,
				"badges: earned + sent flags saved and read back (DataStore, _TEST_ key)"
			)
		end
		Awards.resetForTests()
		ReplicatedStorage:SetAttribute(Badges.ATTR_BOSS_HERE, 0)
	end)
	check(okBadges, "badges section ran" .. (if okBadges then "" else ": " .. tostring(badgesErr)))
end

-- 17. Boot timing (INTRO LOAD FIX): the server's join path against Config.Boot, on this cold Luau Execution server.
-- The art kit's own load (KitService.report().seconds, loaded in section 7), CharacterKit and EH_IntroKit published
-- from it, the hideout (Lobby.build, section 8), the FTUE heist (L1), and the client intro's build and frames. And
-- the shape of the join: no server hold for the intro; the hideout answer waits only for the profile and the flags.
do
	local Config = GameConfig :: any
	local B = Config.Boot
	local heistServer = server:WaitForChild("Heist")
	local okT, tErr = pcall(function()
		local KitService = require(server:WaitForChild("Kit"):WaitForChild("KitService"))
		local HeistService = require(heistServer:WaitForChild("HeistService"))
		local IntroKit = require(heistServer:WaitForChild("IntroKit"))
		local Rookie = require(heistServer:WaitForChild("Rookie"))
		local Cinematic = require(
			game:GetService("StarterPlayer")
				:WaitForChild("StarterPlayerScripts")
				:WaitForChild("Client")
				:WaitForChild("Heist")
				:WaitForChild("Cinematic")
		)
		local lines = {}
		local function within(name: string, value: number?, budget: number, unit: string)
			local v = value or math.huge
			table.insert(lines, string.format("%s %.2f%s (budget %s%s)", name, v, unit, tostring(budget), unit))
			check(v <= budget, string.format("boot: %s %.2f%s within %s%s", name, v, unit, tostring(budget), unit))
		end
		if not KitService.isReady() then
			KitService.ready(B.KIT_READY_SECONDS * 2)
		end
		local report = KitService.report()
		within("kit load", if report.done then report.seconds else nil, B.KIT_READY_SECONDS, " s")
		check(KitService.isPriorityReady(), "boot: the kit's priority phase (the Rookie) is ready")
		if report.source == "cloud" then
			within("kit priority (the Rookie)", report.prioritySeconds, B.KIT_PRIORITY_SECONDS, " s")
			check(
				report.prioritySeconds > 0 and report.prioritySeconds < report.seconds,
				"boot: the Rookie is ready before the whole kit"
			)
		end
		-- EH_IntroKit as the server publishes it at boot (section 7 started the kit and IntroKit.publish): from the
		-- kit's start (the server's boot), at the kit's intro phase (Config.Kit.INTRO_GROUPS), before the whole kit
		local it = IntroKit.timing()
		check(it.published, "boot: EH_IntroKit published in the background (IntroKit.publish)")
		within("EH_IntroKit published (from the server's start)", it.sinceKitStart, B.INTRO_KIT_PUBLISHED_SECONDS, " s")
		local introFolder = IntroKit.folder()
		check(
			introFolder ~= nil and introFolder.Parent == ReplicatedStorage,
			"boot: EH_IntroKit lives in ReplicatedStorage (never streamed)"
		)
		check(
			introFolder ~= nil and introFolder:GetAttribute("Groups") == #Config.Kit.INTRO_GROUPS,
			"boot: every intro group published ("
				.. tostring(introFolder and introFolder:GetAttribute("Groups"))
				.. "/"
				.. #Config.Kit.INTRO_GROUPS
				.. ")"
		)
		if report.source == "cloud" then
			within("kit intro phase (the intro's groups)", report.introSeconds, B.KIT_INTRO_SECONDS, " s")
			check(
				report.introSeconds >= report.prioritySeconds and report.introSeconds < report.seconds,
				string.format(
					"boot: the intro's groups are ready after the Rookie and before the whole kit (%.2f / %.2f / %.2f s)",
					report.prioritySeconds,
					report.introSeconds,
					report.seconds
				)
			)
			check(
				(it.sinceKitStart or math.huge) < report.seconds,
				"boot: EH_IntroKit is published before the whole kit is ready"
			)
		end
		for _, name in { Config.Intro.KIT_FOLDER, Config.Rookie.KIT_FOLDER } do
			local published = ReplicatedStorage:FindFirstChild(name)
			if published then
				published:Destroy()
			end
		end
		local p0 = os.clock()
		local groups = IntroKit.publishNow(KitService)
		local okRookie = Rookie.publishNow(KitService)
		within("kit publish (intro + character)", os.clock() - p0, B.KIT_PUBLISH_SECONDS, " s")
		check(groups > 0 and okRookie, "boot: EH_IntroKit and CharacterKit published from the kit")
		within("hideout build", bootTimes.lobby, B.LOBBY_BUILD_SECONDS, " s")
		local l1 = HeistService.indexOf(Config.Heist.FTUE_L1_LEVEL) :: number
		local b0 = os.clock()
		local inst = HeistService.createInstance(l1, {
			{ userId = -171, name = "Boot", fake = { x = 0, y = 3, z = 14, yaw = 0 } },
		}, -171, true)
		within("L1 build", if inst then os.clock() - b0 else nil, B.L1_BUILD_SECONDS, " s")
		if inst then
			HeistService.destroyInstance(inst)
		end
		local stageHolder = Instance.new("Folder")
		stageHolder.Parent = workspace
		local cam = Instance.new("Camera")
		cam.Parent = stageHolder
		local c0 = os.clock()
		local cine = Cinematic.new({ parent = stageHolder, gui = stageHolder, camera = cam, tier = 1 })
		within("intro build", (os.clock() - c0) * 1000, B.INTRO_BUILD_MS, " ms")
		local worst = 0
		for _ = 1, 240 do
			local s0 = os.clock()
			cine.step(1 / 60)
			worst = math.max(worst, os.clock() - s0)
		end
		within("intro frame (worst of 240)", worst * 1000, B.INTRO_FRAME_MS, " ms")
		cine.destroy()
		stageHolder:Destroy()
		-- the join's shape (HeistService.onPlayerAdded): no hold, the hideout after the profile and flags only
		check(Config.Intro.SERVER_HOLD_SECONDS == nil, "boot: no server hold for the intro")
		local P = Config.Presentation
		local answer = math.max(Config.Heist.DATA_WAIT_SECONDS, Config.Heist.FLAGS_WAIT_SECONDS)
		within(
			"join -> hideout control (worst waits)",
			answer + P.PRELOAD_MAX_SECONDS + P.LOADING.FADE_SECONDS,
			B.JOIN_TO_CONTROL_SECONDS,
			" s"
		)
		table.insert(results, "      " .. table.concat(lines, "; "))
	end)
	check(okT, "boot timing section ran" .. (if okT then "" else ": " .. tostring(tErr)))
end

table.insert(results, string.format("%d failure(s)", failures))
return table.concat(results, "\n")
