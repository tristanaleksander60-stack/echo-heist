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

local Actors = require(server:WaitForChild("Actors"))
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
local fake = { kind = "echo", model = dummyModel, root = root, owner = nil, carrying = nil, alive = true, immuneUntil = 0 }

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
table.insert(results, string.format("%d failure(s)", failures))
return table.concat(results, "\n")
