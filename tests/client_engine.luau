-- Client views in a real Roblox server (Open Cloud Luau Execution): the client wiring.
-- Run: ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 \
--      --place 70772627070328 --script tests/client_engine.luau   (add --version N to skip publishing)
-- 2026-11-12, place v21: 22 checks, 0 failed.
-- Loads every client module, builds L6 with the uploaded kit + Christmas layer and runs
-- WorldView on it (vault door skin swing + dial, alarm beacons), the L5 till lock label,
-- GusView with the Santa hat, the Line-up arrangement against the real van body, and
-- Rigs.buildCopy / playCheer on a default R15 character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

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

local shared = ReplicatedStorage:WaitForChild("Shared")
local server = ServerScriptService:WaitForChild("Server")
local heistServer = server:WaitForChild("Heist")
local client = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local clientHeist = client:WaitForChild("Heist")

-- A. every client module loads in the engine
local loadErr = {}
for _, name in
	{
		"Sound",
		"LineupPlan",
		"Ui",
		"Rigs",
		"EchoView",
		"GusView",
		"WorldView",
		"RewindDirector",
		"LineupDirector",
		"Hud",
		"Telemetry",
		"HeistClient",
	}
do
	local ok, err = pcall(require, clientHeist:WaitForChild(name))
	if not ok then
		table.insert(loadErr, name .. ": " .. tostring(err))
	end
end
local okAd, adErr = pcall(require, client:WaitForChild("Audio"):WaitForChild("AudioDirector"))
if not okAd then
	table.insert(loadErr, "AudioDirector: " .. tostring(adErr))
end
check(#loadErr == 0, "client modules load (" .. table.concat(loadErr, "; ") .. ")")

local Protocol = require(shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local HeistInstance = require(heistServer:WaitForChild("HeistInstance"))
local LevelBuilder = require(heistServer:WaitForChild("LevelBuilder"))
local WorldView = require(clientHeist:WaitForChild("WorldView"))
local GusView = require(clientHeist:WaitForChild("GusView"))
local Rigs = require(clientHeist:WaitForChild("Rigs"))
local LineupPlan = require(clientHeist:WaitForChild("LineupPlan"))
local Sound = require(clientHeist:WaitForChild("Sound"))
local HeistSim = require(shared:WaitForChild("Sim"):WaitForChild("HeistSim"))

-- Sound is a no-op on the server (the views run here in the smoke test).
local okSnd = pcall(function()
	local stop = Sound.play("RewindClack")
	stop()
	Sound.music("Heist")
end)
check(okSnd and Sound.status().built == false, "Sound facade is a no-op on the server")

-- B. kit L6 + Christmas: vault door skin swing, beacons
local KitService = require(server:WaitForChild("Kit"):WaitForChild("KitService"))
KitService.start()
local kitOk = KitService.ready(60)
table.insert(results, "      kit " .. KitService.summary())
local l6Index = Protocol.catalogIndex("bk1_big_score") :: number
local l6 = HeistInstance.levelData(l6Index)
local scratch = Instance.new("Folder")
scratch.Name = "ClientScratch"
scratch.Parent = workspace
local origin6 = Vector3.new(-9000, 0, 0)
local okB, b6 = pcall(LevelBuilder.build, l6, origin6, scratch, { kit = KitService, dressing = true })
check(
	okB and b6 and b6.kit == true,
	"L6 builds with the kit (" .. tostring(okB and b6.kit) .. ", kit ready " .. tostring(kitOk) .. ")"
)
if okB and b6 then
	local f = Instance.new("Folder")
	f.Name = "FakeInstance"
	f.Parent = scratch
	local skinModel, skinIndex = nil, nil
	for _, d in b6.model:GetDescendants() do
		if d:GetAttribute("EH_Kind") == "doorSkin" then
			skinModel = d
			skinIndex = d:GetAttribute("EH_Index")
		end
	end
	check(skinModel ~= nil, "L6 has a vault door skin (index " .. tostring(skinIndex) .. ")")
	local i = skinIndex or 1
	f:SetAttribute("D" .. i .. "Open", false)
	f:SetAttribute("D" .. i .. "Solid", true)
	f:SetAttribute("D" .. i .. "SolidAt", -1)
	local state = {
		folder = f,
		level = l6,
		origin = origin6,
		phase = "Run",
		run = { actors = {}, actorById = {} },
		crew = {},
	}
	local world = WorldView.new(state, function()
		return nil
	end)
	local okBind, bindErr = pcall(world.bind, b6.model)
	check(okBind, "WorldView binds the kit level" .. (if okBind then "" else ": " .. tostring(bindErr)))
	-- closed first
	for _ = 1, 3 do
		world.update(5, os.clock(), 1 / 30)
	end
	local leaf = world.partFor("door", i)
	local doorPart, dialPart = nil, nil
	if skinModel then
		for _, p in skinModel:GetDescendants() do
			if p:IsA("BasePart") then
				if p.Name == "VaultDoor_Door" then
					doorPart = p
				elseif p.Name == "VaultDoor_Dial" then
					dialPart = p
				end
			end
		end
	end
	local closedDoor = doorPart and doorPart.CFrame
	local closedDial = dialPart and dialPart.CFrame
	check(
		leaf ~= nil and (leaf :: BasePart).LocalTransparencyModifier == 1,
		"the vault door's greybox leaf is hidden locally (skin drawn instead)"
	)
	local alphaOk = true
	if skinModel then
		for _, p in skinModel:GetDescendants() do
			if p:IsA("BasePart") then
				local a = p:GetAttribute("EH_Alpha")
				if type(a) == "number" and math.abs(p.Transparency - a) > 1e-3 then
					alphaOk = false
				end
			end
		end
	end
	check(alphaOk, "skin parts shown at their EH_Alpha")
	-- open it
	f:SetAttribute("D" .. i .. "Open", true)
	f:SetAttribute("D" .. i .. "Solid", false)
	f:SetAttribute("AlarmOn", true)
	f:SetAttribute("AlarmVanAt", 30)
	f:SetAttribute("AlarmLockAt", 25)
	for _ = 1, 30 do
		world.update(5, os.clock(), 1 / 30)
	end
	if doorPart and closedDoor then
		local _, y0 = closedDoor:ToEulerAnglesYXZ()
		local _, y1 = doorPart.CFrame:ToEulerAnglesYXZ()
		local turned = math.deg((y1 - y0 + math.pi) % (2 * math.pi) - math.pi)
		local moved = (doorPart.Position - closedDoor.Position).Magnitude
		table.insert(results, string.format("      door skin turned %.1f deg, centre moved %.2f studs", turned, moved))
		check(
			math.abs(math.abs(turned) - 175) < 2 and moved > 1,
			"vault door skin swings open about its hinge (-175 deg)"
		)
	else
		check(false, "vault door skin parts found (VaultDoor_Door)")
	end
	if dialPart and closedDial and doorPart and closedDoor then
		-- the dial turns relative to the door it sits on
		local relClosed = closedDoor:ToObjectSpace(closedDial)
		local relOpen = doorPart.CFrame:ToObjectSpace(dialPart.CFrame)
		local _, _, rz0 = relClosed:ToEulerAnglesXYZ()
		local _, _, rz1 = relOpen:ToEulerAnglesXYZ()
		local posDrift = (relOpen.Position - relClosed.Position).Magnitude
		table.insert(
			results,
			string.format("      dial roll %.1f -> %.1f deg, drift %.3f", math.deg(rz0), math.deg(rz1), posDrift)
		)
		check(posDrift < 0.05, "the dial stays on the door while it turns")
	end
	local beacons, lit = 0, 0
	local fx = workspace:FindFirstChild("EH_WorldFx")
	if fx then
		for _, m in fx:GetChildren() do
			if m.Name == "EH_AlarmBeacon" then
				beacons += 1
				local dome = m:FindFirstChild("Dome")
				if dome and dome:IsA("BasePart") and dome.Transparency == 0 then
					lit += 1
				end
			end
		end
	end
	check(beacons >= 1 and lit == beacons, string.format("alarm beacons lit while AlarmOn (%d of %d)", lit, beacons))
	-- the Line-up row vs the real van body
	local body = world.vanBody()
	check(body ~= nil, "the van body is found for the Line-up")
	if body then
		local c = body.Position - origin6
		local box = { cx = c.X, cz = c.Z, hx = body.Size.X / 2 + 1.5, hz = body.Size.Z / 2 + 1.5 }
		local slots = {}
		for k = 1, 7 do
			slots[k] = { run = k }
		end
		local entries = HeistSim.lineup({
			level = l6,
			players = { { id = 1, seat = 1, orphan = false, deck = { slots = slots } } },
			runIndex = 8,
		})
		local spots = {}
		for k, e in entries do
			spots[k] = { x = e.x, z = e.z }
		end
		local out, _, moved = LineupPlan.arrange(spots, entries[1].yaw, box, 0.5, 60)
		local clear = true
		for _, p in out do
			if math.abs(p.x - box.cx) < box.hx and math.abs(p.z - box.cz) < box.hz then
				clear = false
			end
		end
		table.insert(
			results,
			string.format(
				"      van body centre (%.1f, %.1f) size (%.1f, %.1f); row moved %s to z %.1f",
				c.X,
				c.Z,
				body.Size.X,
				body.Size.Z,
				tostring(moved),
				out[1].z
			)
		)
		check(clear, "the Line-up row clears the built van body")
	end
	world.clear()
end

-- C. L5 till: LOCKED label counts down to opensAt
local l5Index = Protocol.catalogIndex("cs5_clone_party") :: number
local l5 = HeistInstance.levelData(l5Index)
local origin5 = Vector3.new(-12000, 0, 0)
local okB5, b5 = pcall(LevelBuilder.build, l5, origin5, scratch, nil)
check(okB5, "L5 builds (greybox)")
if okB5 and b5 then
	local f5 = Instance.new("Folder")
	f5.Parent = scratch
	local till = 0
	for k, def in l5.loot do
		if def.opensAt then
			till = k
			f5:SetAttribute("K" .. k .. "OpensAt", def.opensAt)
			f5:SetAttribute("K" .. k .. "State", "Home")
		end
	end
	local st = { folder = f5, level = l5, origin = origin5, phase = "Run", run = { actors = {}, actorById = {} } }
	local w5 = WorldView.new(st, function()
		return nil
	end)
	w5.bind(b5.model)
	w5.update(5, os.clock(), 1 / 30)
	local part = w5.partFor("loot", till)
	local gui = part and part:FindFirstChild("EH_Label")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	check(
		gui ~= nil and (gui :: BillboardGui).Enabled and label ~= nil and label.Text == "LOCKED 0:15",
		"L5 till shows LOCKED 0:15 at 0:05 (" .. tostring(label and label.Text) .. ")"
	)
	local idx, _, opensAt = w5.nearestLoot((part :: BasePart).Position, 10)
	check(idx == till and opensAt == 20, "nearestLoot reports the till's time lock")
	w5.clear()
end

-- D. GusView: Santa hat with the dressing layer
local l4 = HeistInstance.levelData(Protocol.catalogIndex("cs4_night_clerk") :: number)
local gst = { origin = Vector3.zero, folder = scratch, level = l4, crew = {}, dressing = true, phase = "Run" }
local gus = GusView.new(gst)
gus.setLevel(l4)
local gusFolder = workspace:FindFirstChild("HeistGus")
local hat = gusFolder and gusFolder:FindFirstChild("HatPom", true)
local cap = gusFolder and gusFolder:FindFirstChild("Cap", true)
check(hat ~= nil and cap == nil, "Gus wears the Santa hat (no cap) when the dressing layer is on")
gus.clear()

-- E. Line-up figures: a copy of a character keeps its look, anchored root, no scripts; cheer loads
local okRig, rigErr = pcall(function()
	local desc = Instance.new("HumanoidDescription")
	local model = Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	model.Parent = scratch
	local rig = Rigs.buildCopy(model)
	assert(rig, "buildCopy returned nil")
	rig.model.Parent = scratch
	assert(rig.root and rig.root.Anchored, "root anchored")
	for _, d in rig.model:GetDescendants() do
		assert(not d:IsA("BaseScript"), "scripts removed")
	end
	local cheer = Rigs.playCheer(rig, "rbxassetid://507770677")
	local parts, cfs = {}, {}
	Rigs.poseCheer(rig, CFrame.new(0, 50, 0), 1, 0.5, parts, cfs)
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	return cheer
end)
check(okRig and rigErr == true, "Rigs.buildCopy + playCheer on an R15 character (" .. tostring(rigErr) .. ")")
local mq = Rigs.buildMannequin()
mq.model.Parent = scratch
local parts, cfs = {}, {}
Rigs.poseCheer(mq, CFrame.new(0, 50, 0), 1, 0.5, parts, cfs)
workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
local arm = mq.model:FindFirstChild("LeftArm")
local armY = if arm and arm:IsA("BasePart") then arm.Position.Y else nil
check(armY ~= nil and armY > 53.5, "mannequin cheer raises the arms (" .. tostring(armY) .. ")")

scratch:Destroy()
return string.format("%d checks, %d failed\n%s", #results, failures, table.concat(results, "\n"))
