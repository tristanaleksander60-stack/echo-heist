-- Client views in a real Roblox server (Open Cloud Luau Execution): the client wiring.
-- Run: ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 \
--      --place 70772627070328 --script tests/client_engine.luau   (add --version N to skip publishing)
-- 2026-11-12, place v21: 22 checks, 0 failed. Section F (camera track) and H (presentation shell) not yet run in the engine.
-- Section J: first person (PLAN_FIRST_PERSON FP). 2026-11-13, Saved v50 and v52: 49 checks, 0 failed (J: 3 / 3).
-- Section K: the northern lights (SKY track). 2026-11-13, Saved v59: 50 checks, 0 failed (K: 26 / 26 / 13 / 7 Beams).
-- Section J (intro) + L: CH and intro polish (Rookie-copy clones, the real aurora, the kit tower, the vortex, the
-- arms in your outfit, the scarf sway).
-- Loads every client module, builds L6 with the uploaded kit + Christmas layer and runs
-- WorldView on it (vault door skin swing + dial, alarm beacons), the L5 till lock label,
-- Gus on his mesh (every beat attached, head lead, Santa hat), the Line-up arrangement against the real van body, and
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

-- Golden-frame staging helpers (docs/GOLDEN_FRAMES.md, REVIEW_STEAM_PLUS #4): is a world point inside a first-person
-- frame (CameraDirector.lookFrame at yaw / pitch down, vertical FOV, 16:9), and the first opaque thing on a ray from
-- the eye toward it (glass and see-through parts let the eye through).
local function inFrame(cf: CFrame, p: Vector3, vfov: number): boolean
	local lp = cf:PointToObjectSpace(p)
	local depth = -lp.Z
	local tv = math.tan(math.rad(vfov / 2))
	return depth > 0.5 and math.abs(lp.Y / depth) <= tv and math.abs(lp.X / depth) <= tv * 16 / 9
end
local function sightTo(eye: Vector3, p: Vector3, target: Instance?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = {}
	for _ = 1, 24 do
		params.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(eye, p - eye, params)
		if not hit then
			return true
		end
		local inst = hit.Instance
		if (target and inst:IsDescendantOf(target)) or inst == target or (hit.Position - p).Magnitude < 0.6 then
			return true
		end
		if inst.Transparency > 0.2 or inst.Material == Enum.Material.Glass or not inst.CanCollide then
			table.insert(skip, inst)
		else
			return false
		end
	end
	return false
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
		"Motion",
		"Theme",
		"Icons",
		"CameraMath",
		"CameraDirector",
		"CutAway",
		"GoldenShots",
		"Ui",
		"TypeSpecimen",
		"Rigs",
		"EchoView",
		"GusRig",
		"GusView",
		"WorldView",
		"MomentDirector",
		"Particles",
		"FlashLimit",
		"RewindDirector",
		"LineupDirector",
		"Hud",
		"Telemetry",
		"PresentPlan",
		"Transition",
		"Title",
		"LevelIntro",
		"FpMath",
		"ViewmodelMath",
		"Viewmodel",
		"LookTarget",
		"FpWarn",
		"Loading",
		"Cinematic",
		"Aurora",
		"Drive",
		"Hideout",
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

-- One flash limit for the whole client (Heist/FlashLimit): the moments' flashes and the HUD's red vignette share
-- Config.Moments.FLASH_MAX per FLASH_WINDOW.
do
	local okF, fErr = pcall(function()
		local M = (require(shared:WaitForChild("Config")) :: any).Moments
		local FlashLimit = require(clientHeist:WaitForChild("FlashLimit"))
		local Moments = require(clientHeist:WaitForChild("MomentDirector"))
		FlashLimit.reset()
		local t = 1000
		local granted = 0
		for i = 1, 5 do
			local ok = if i % 2 == 0 then Moments.allowFlash(t + i * 0.01) else FlashLimit.allow(t + i * 0.01)
			if ok then
				granted += 1
			end
		end
		assert(granted == M.FLASH_MAX, "granted " .. granted)
		assert(FlashLimit.allow(t + M.FLASH_WINDOW + 0.02), "the window moves on")
		FlashLimit.reset()
	end)
	check(okF, "one flash limit shared by the moments and the HUD" .. (if okF then "" else ": " .. tostring(fErr)))
end

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

-- D. Gus on his mesh (Gus track, PLAN_STEAM_PLUS §4.4 A4-A5): the server replicates the kit's Gus
-- (Heist/GusTemplate), GusRig builds the 18-part mesh, every beat poses with every part attached
-- (each joint within reach of its parent's, everything within a Gus of the root), the head leads the
-- body before a patrol turn, GusView drives the beats from the guard attributes, the Santa hat.
local GusConfig = require(shared:WaitForChild("Config")).Gus
local GusTemplate = require(heistServer:WaitForChild("GusTemplate"))
local GusRig = require(clientHeist:WaitForChild("GusRig"))
local GusBeats = require(shared:WaitForChild("Heist"):WaitForChild("GusBeats"))
local GB = GusBeats.BEAT
local published = KitService.isReady() and GusTemplate.publishNow(KitService)
local gusMap = GusRig.template()
check(
	published and gusMap ~= nil,
	"the kit's Gus is replicated for clients (ReplicatedStorage/" .. GusConfig.TEMPLATE_FOLDER .. ")"
)
if gusMap then
	-- The kit's joint pivots (part:GetPivot at rest) match the skeleton GusRig poses with.
	local rootSpec = GusBeats.PARTS[1]
	local rootPivot = gusMap[rootSpec.name]:GetPivot().Position
	local worst, worstName = 0, ""
	for _, spec in GusBeats.PARTS do
		local p = gusMap[spec.name]:GetPivot().Position - rootPivot
		local o, r = spec.origin, rootSpec.origin
		local e = (p - Vector3.new(o[1] - r[1], o[2] - r[2], o[3] - r[3])).Magnitude
		if e > worst then
			worst, worstName = e, spec.name
		end
	end
	check(worst < 0.05, string.format("kit joint pivots match GusBeats.PARTS (worst %.3f, %s)", worst, worstName))
end
local okMesh, meshInfo = pcall(function()
	local rig = GusRig.build(false)
	assert(rig.kind == "mesh", "mesh rig (got " .. rig.kind .. ")")
	assert(#rig.parts == 18, "18 parts")
	rig.model.Parent = scratch
	local pose = GusBeats.newPose()
	local walk: any = { phase = 0, amount = 1, run = 0, clock = 0 }
	local feet = CFrame.new(-9000, 60, 300)
	local spread, slack = 0, 0
	local parts, cfs = {}, {}
	for _, beat in { GB.Doze, GB.Wake, GB.Patrol, GB.DoubleTake, GB.Chase, GB.Catch, GB.WrongOne, GB.Scratch } do
		for t = 0, 2.0, 0.1 do
			walk.phase = (t * 1.5) % 1
			walk.clock = t
			walk.run = if beat == GB.Chase then 1 else 0
			GusBeats.pose(beat, t, walk, pose)
			table.clear(parts)
			table.clear(cfs)
			GusRig.pose(rig, feet, pose, math.rad(40), 0, parts, cfs)
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			spread = math.max(spread, GusRig.spread(rig))
			for i, spec in GusBeats.PARTS do
				local pi = rig.parentIx[i]
				if pi > 0 then
					local o, po = spec.origin, GusBeats.PARTS[pi].origin
					local rest = Vector3.new(o[1] - po[1], o[2] - po[2], o[3] - po[3]).Magnitude
					local now = (rig.parts[i]:GetPivot().Position - rig.parts[pi]:GetPivot().Position).Magnitude
					slack = math.max(slack, math.abs(now - rest))
				end
			end
		end
	end
	assert(spread < 6.5, string.format("a part drifted %.2f studs from the root", spread))
	assert(slack < 0.75, string.format("a joint moved %.2f studs off its parent", slack))
	assert(GusRig.whole(rig), "every part still in the rig")
	return string.format("spread %.2f, joint slack %.2f", spread, slack)
end)
check(okMesh, "mesh Gus poses every beat with every part attached (" .. tostring(meshInfo) .. ")")
local santa = GusRig.build(true)
check(
	santa.model:FindFirstChild("Gus_SantaHat") ~= nil and santa.model:FindFirstChild("Gus_Cap") == nil,
	"Gus wears the Santa hat (no cap) on the Christmas layer (" .. santa.kind .. ")"
)
santa.model:Destroy()
local box = GusRig.build(false, false)
check(box.kind == "box" and #box.parts == 18, "the box Gus fallback builds the same 18 joints")
box.model:Destroy()

-- GusView on L4: patrol head lead, then each beat from the guard attributes.
local l4 = HeistInstance.levelData(Protocol.catalogIndex("cs4_night_clerk") :: number)
local gusFolder = Instance.new("Folder")
gusFolder.Name = "FakeGusInstance"
gusFolder.Parent = scratch
gusFolder:SetAttribute("G1Mode", "Patrol")
gusFolder:SetAttribute("G1Offset", 0)
local gst = {
	origin = Vector3.new(-9000, 0, 600),
	folder = gusFolder,
	level = l4,
	crew = {},
	dressing = false,
	phase = "Run",
	run = { actors = {}, actorById = {} },
}
local gus = GusView.new(gst)
gus.setLevel(l4)
local okView, viewInfo = pcall(function()
	local route = l4.guards[1].route
	local leg = route.legs[1]
	local turnAt = leg.tEnd - require(shared:WaitForChild("Config")).Sim.GUARD_TURN_SECONDS
	local dt = 1 / 60
	local clock = os.clock()
	local t = turnAt - 0.6
	while t < turnAt - 0.08 do
		t += dt
		clock += dt
		gus.update(t, clock, dt)
	end
	local _, _, bodyYaw = gus.poseOf(1)
	local look = gus.lookOf(1)
	assert(math.abs(bodyYaw - leg.yawDwell) < 1e-6, "body has not turned yet")
	assert(math.abs(look) > math.rad(8), string.format("head leads the turn (%.1f deg)", math.deg(look)))
	local rig = gus.rigOf(1) :: any
	local beats = {}
	local function stepFor(seconds: number)
		local n = math.floor(seconds / dt)
		for _ = 1, n do
			t += dt
			clock += dt
			gus.update(t, clock, dt)
			assert(GusRig.spread(gus.rigOf(1) :: any) < 6.5, "attached")
		end
	end
	local _, _, yawNow = gus.poseOf(1)
	gusFolder:SetAttribute("G1X", leg.x1)
	gusFolder:SetAttribute("G1Z", leg.z1)
	gusFolder:SetAttribute("G1Yaw", yawNow)
	gusFolder:SetAttribute("G1Mode", "Suspicious")
	gusFolder:SetAttribute("G1Stage", 2)
	stepFor(0.3)
	table.insert(beats, gus.beatOf(1))
	gus.bang(1, clock, "catch", Vector3.new(-9000, 3, 590))
	stepFor(0.3)
	table.insert(beats, gus.beatOf(1))
	gusFolder:SetAttribute("G1Stage", 0)
	gusFolder:SetAttribute("G1Mode", "Huh")
	stepFor(GusConfig.CATCH_SECONDS)
	table.insert(beats, gus.beatOf(1))
	gusFolder:SetAttribute("G1Mode", "Chase")
	stepFor(1.0)
	table.insert(beats, gus.beatOf(1))
	local want = { GB.DoubleTake, GB.Catch, GB.WrongOne, GB.Chase }
	for i, b in want do
		assert(beats[i] == b, "beat " .. i .. ": " .. tostring(beats[i]) .. " (want " .. b .. ")")
	end
	return string.format("%s rig, look %.1f deg, %s", rig.kind, math.deg(look), table.concat(beats, " > "))
end)
check(okView, "GusView: head leads the patrol turn; ? / catch / huh / chase beats (" .. tostring(viewInfo) .. ")")
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

-- F. UI kit v2 (PLAN_STEAM_PLUS §4.3 U1-U3): the kit builds in the engine, the display faces exist,
-- the UI Decals resolve to image ids, the run-bar markers compute on a real level
local okKit, kitErr = pcall(function()
	local Ui = require(clientHeist:WaitForChild("Ui"))
	local Theme = require(clientHeist:WaitForChild("Theme"))
	local gui = Instance.new("ScreenGui")
	gui.Parent = scratch
	local panel = Ui.panel(gui, { Size = UDim2.fromOffset(200, 100), Visible = false })
	Ui.show(panel)
	assert(Ui.isShown(panel), "panel shown")
	Ui.hide(panel)
	assert(not Ui.isShown(panel), "panel hidden")
	local b = Ui.button(gui, { Size = UDim2.fromOffset(120, 72), Text = "GO" }, function() end)
	assert(b:FindFirstChild("Outline") and b:FindFirstChild("Lip") and b:FindFirstChild("TextStroke"), "raised button")
	Ui.iconWord(b, "rewind", "top")
	local l = Ui.label(gui, { TextSize = 18, Text = "x" })
	assert(l.TextSize == 20, "type scale snap 18 -> 20")
	local digits = Ui.digits(gui, {}, 24)
	digits.set("0:27")
	Ui.lockRing(b, 64, Color3.new()).set(0.5)
	for _, face in { "LuckiestGuy", "FredokaOne" } do
		local f = Theme.displayFont(face)
		assert(string.find(f.Family, face, 1, true), face .. " family " .. f.Family)
	end
	return true
end)
check(
	okKit and kitErr == true,
	"UI kit builds: panel, raised button, label snap, digits, ring, display faces (" .. tostring(kitErr) .. ")"
)
local UiAssets = require(shared:WaitForChild("Heist"):WaitForChild("UiAssets"))
for stem, entry in UiAssets do
	local okLoad, loaded = pcall(function()
		return game:GetService("InsertService"):LoadAsset(entry.decal)
	end)
	local decal = okLoad and loaded and loaded:FindFirstChildWhichIsA("Decal", true)
	local texture = if decal and decal:IsA("Decal") then decal.Texture else ""
	-- the integrator records it: python3 tools/kit_upload.py --set-ui-image <stem> <id>
	check(string.match(texture, "%d+") ~= nil, string.format("UI Decal %s %d -> image %s", stem, entry.decal, texture))
end
local okMarkers, markersErr = pcall(function()
	local RunMarkers = require(shared:WaitForChild("Heist"):WaitForChild("RunMarkers"))
	local LevelSpec = require(shared:WaitForChild("Sim"):WaitForChild("LevelSpec"))
	local level = LevelSpec.compile(Protocol.levelSpec(6))
	local m = RunMarkers.compute(level, {}, 60)
	return #m.gus
end)
check(okMarkers, "run-bar markers on L6 (" .. tostring(markersErr) .. " Gus ticks)")

-- BIG buildings (PLAN_FIRST_PERSON §5): a shot still sees its subjects through the tall building. The level's
-- Overhead (ceiling, storeys, roof: CanQuery off in the game) is made queryable for the check; the cut-away's rule
-- (Shared/Heist/CutMath, what client Heist/CutAway runs on the built groups' attributes) decides for the camera,
-- your feet and head and the shot's look point; every Overhead part a ray from the camera to a subject meets must be
-- in a group the cut-away hides. Returns ok and the first blocker (or "clear") and the hidden groups.
local CutMath = require(shared:WaitForChild("Heist"):WaitForChild("CutMath"))
local PresentPlanBig = require(clientHeist:WaitForChild("PresentPlan"))
local BIGCFG = (require(shared:WaitForChild("Config")) :: any).Big
local function cutSees(levelModel: Instance, cam: Vector3, look: Vector3, you: Vector3?, subjects: { Vector3 })
	local over = levelModel:FindFirstChild("Overhead")
	if not over then
		return false, "no Overhead", ""
	end
	local groups: { CutMath.Group } = {}
	local names: { string } = {}
	for _, g in over:GetChildren() do
		local lo, hi = g:GetAttribute("EH_CutMin"), g:GetAttribute("EH_CutMax")
		local nrm = g:GetAttribute("EH_CutNormal")
		if typeof(lo) == "Vector3" and typeof(hi) == "Vector3" then
			table.insert(groups, {
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
	local b = {
		ceilY = over:GetAttribute("CeilY") :: number,
		minX = omin.X,
		maxX = omax.X,
		minZ = omin.Z,
		maxZ = omax.Z,
	}
	-- CutAway's subjects: you (head, feet), then the look ray's floor point
	local subj, n = {}, 0
	local function add(p: Vector3)
		subj[3 * n + 1], subj[3 * n + 2], subj[3 * n + 3] = p.X, p.Y, p.Z
		n += 1
	end
	if you then
		add(you + Vector3.new(0, 1.5, 0))
		add(you - Vector3.new(0, 2.2, 0))
	end
	local dir = (look - cam).Unit
	local floorY = (over:GetAttribute("FloorY") :: number?) or 0
	local lx, ly, lz = CutMath.lookPoint(
		cam.X,
		cam.Y,
		cam.Z,
		dir.X,
		dir.Y,
		dir.Z,
		floorY + BIGCFG.CUT.LOOK_HEIGHT,
		BIGCFG.CUT.LOOK_MAX
	)
	if lx and ly and lz then
		add(Vector3.new(lx, ly, lz))
	end
	local hide = {}
	CutMath.decide(b, groups, cam.X, cam.Y, cam.Z, subj, n, BIGCFG.CUT.MARGIN, BIGCFG.CUT.INSIDE_PAD, hide)
	local hidden: { [string]: boolean } = {}
	local hiddenList = {}
	for i, nm in names do
		hidden[nm] = hide[i] == true
		if hide[i] then
			table.insert(hiddenList, nm)
		end
	end
	local saved = {}
	for _, d in over:GetDescendants() do
		if d:IsA("BasePart") then
			saved[d] = d.CanQuery
			d.CanQuery = true
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { over }
	local blocker = "clear"
	for _, target in subjects do
		local from = cam
		local hit = workspace:Raycast(from, target - from, params)
		while hit do
			local g = hit.Instance
			while g.Parent ~= over do
				g = g.Parent :: Instance
			end
			if not hidden[g.Name] then
				blocker = hit.Instance:GetFullName()
				break
			end
			from = hit.Position + (target - cam).Unit * 0.05
			hit = workspace:Raycast(from, target - from, params)
		end
		if blocker ~= "clear" then
			break
		end
	end
	for p, q in saved do
		p.CanQuery = q
	end
	return blocker == "clear", blocker, table.concat(hiddenList, ",")
end

-- G. Camera track (PLAN_STEAM_PLUS §4.2 C0, C5): on the real kit L1, the diorama camera at the
-- street spawn sees plate A and a clone standing on it (workspace raycasts against the built
-- level, Christmas layer on); the classic follow cam is reported (the old finding); the wall
-- fade's engine call (Camera:GetPartsObscuringTarget) names the shop front for the classic
-- camera; and on the real kit L5 the Line-up shot search finds a clear 9:16-safe lane.
-- CameraDirector itself binds to RenderStepped, so it only runs on a client (Studio play).
local CameraMath = require(clientHeist:WaitForChild("CameraMath"))
local HC = require(shared:WaitForChild("Config")).Heist
local camCfg = HC.CAMERA
local l1Index = Protocol.catalogIndex("cs1_back_room") :: number
local l1 = HeistInstance.levelData(l1Index)
local origin1 = Vector3.new(-9000, 0, 3000)
local okL1, b1 = pcall(LevelBuilder.build, l1, origin1, scratch, { kit = KitService, dressing = true })
check(okL1 and b1 ~= nil, "L1 builds with the kit for the camera checks")
if okL1 and b1 then
	local D = camCfg.DIORAMA
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { b1.model }
	local spawn = l1.spawns[1]
	local yaw = math.deg(spawn.yaw)
	local you = { spawn.x, spawn.y + D.FOCUS_HEIGHT, spawn.z }
	local lead = CameraMath.lead(D.FOV, D.PITCH, D.DISTANCE, D.SUBJECT_SCREEN_Y)
	local dioPos = CameraMath.orbit(CameraMath.ahead(you, yaw, lead), yaw, D.PITCH, D.DISTANCE)
	local clPos = CameraMath.orbit(you, yaw, camCfg.CLASSIC.PITCH, camCfg.CLASSIC.ZOOM)
	local pb = l1.plates[1].box
	local px, pz = (pb.minX + pb.maxX) / 2, (pb.minZ + pb.maxZ) / 2
	local function seen(from: { number }, p: Vector3): (boolean, string)
		local a = origin1 + Vector3.new(from[1], from[2], from[3])
		local b = origin1 + p
		local hit = workspace:Raycast(a, b - a, params)
		-- a hit at the target spot (the pad, its letter, the lamp pool around it) is the target itself
		if not hit or (hit.Position - b).Magnitude < 2.5 then
			return true, "clear"
		end
		return false, hit.Instance:GetFullName()
	end
	for _, t in
		{
			{ "plate A", Vector3.new(px, 0.45, pz) },
			{ "clone feet on plate A", Vector3.new(px, 0.6, pz) },
			{ "clone head on plate A", Vector3.new(px, 5.2, pz) },
		}
	do
		local ok, by = seen(dioPos, t[2])
		check(ok, "diorama camera at the L1 spawn sees " .. t[1] .. " (" .. by .. ")")
		local okC, byC = seen(clPos, t[2])
		table.insert(results, "      classic camera: " .. t[1] .. (if okC then " visible" else " behind " .. byC))
	end
	-- BIG: the tall Corner Shop stands between the spawn's diorama and plate A: the cut-away opens it
	do
		local _, lookL = CameraMath.orbit(CameraMath.ahead(you, yaw, lead), yaw, D.PITCH, D.DISTANCE)
		local cam = origin1 + Vector3.new(dioPos[1], dioPos[2], dioPos[3])
		local ok, by, hid = cutSees(
			b1.model,
			cam,
			origin1 + Vector3.new(lookL[1], lookL[2], lookL[3]),
			origin1 + Vector3.new(spawn.x, spawn.y, spawn.z),
			{ origin1 + Vector3.new(px, 0.45, pz), origin1 + Vector3.new(px, 5.2, pz) }
		)
		check(
			ok,
			"BIG: the diorama at the L1 spawn sees plate A through the cut-away (" .. by .. "; hides " .. hid .. ")"
		)
	end
	local cam = workspace.CurrentCamera
	if cam then
		local target = origin1 + Vector3.new(px, 5.2, pz)
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = camCfg.CLASSIC.FOV
		cam.CFrame = CFrame.lookAt(origin1 + Vector3.new(clPos[1], clPos[2], clPos[3]), target)
		local okObs, obscuring = pcall(cam.GetPartsObscuringTarget, cam, { target }, {})
		local names = {}
		if okObs then
			for _, part in obscuring do
				if part:IsDescendantOf(b1.model) then
					table.insert(names, part.Name)
				end
			end
		end
		check(
			okObs and #names > 0,
			"GetPartsObscuringTarget names the wall to fade (" .. table.concat(names, ", ") .. ")"
		)
	end
end
local l5cIndex = Protocol.catalogIndex("cs5_clone_party") :: number
local l5c = HeistInstance.levelData(l5cIndex)
local origin5c = Vector3.new(-9000, 0, -3000)
local okL5, b5c = pcall(LevelBuilder.build, l5c, origin5c, scratch, { kit = KitService, dressing = true })
if okL5 and b5c then
	local L = camCfg.LINEUP
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { b5c.model }
	local slots = {}
	for k = 1, 7 do
		slots[k] = { run = k }
	end
	local entries = HeistSim.lineup({
		level = l5c,
		players = { { id = 1, seat = 1, orphan = false, deck = { slots = slots } } },
		runIndex = 8,
	})
	local spots = {}
	for k, e in entries do
		spots[k] = { x = e.x, z = e.z }
	end
	local v = l5c.van
	local body = {
		cx = (v.minX + v.maxX) / 2,
		cz = v.maxZ + 4.5,
		hx = (v.maxX - v.minX + 1) / 2 + HC.LINEUP_VAN_CLEARANCE,
		hz = 4 + HC.LINEUP_VAN_CLEARANCE,
	}
	local out = LineupPlan.slide(spots, entries[1].yaw, body, L.ROW_GAP, 0.5, 80)
	local shot = LineupPlan.shot({
		spots = out,
		yaw = entries[1].yaw,
		floorY = l5c.floorY,
		fov = HC.LINEUP_CAM_FOV,
		aspect = 16 / 9,
		share = L.CENTRAL_SHARE,
		shareY = 0.9,
		figureHeight = HC.LINEUP_FIGURE_HEIGHT,
		figureHalfWidth = L.FIGURE_HALF_WIDTH,
		lookHeight = HC.LINEUP_CAM_LOOK_HEIGHT,
		heights = L.HEIGHTS,
		yaws = L.YAWS,
		minDistance = HC.LINEUP_CAM_DISTANCE[1],
		maxDistance = L.MAX_DISTANCE,
		maxPitch = L.MAX_PITCH,
		push = HC.LINEUP_CAM_PUSH,
		blocked = function(from: { number }, to: { number }): boolean
			local a = origin5c + Vector3.new(from[1], from[2], from[3])
			local b = origin5c + Vector3.new(to[1], to[2], to[3])
			local hit = workspace:Raycast(a, b - a, params)
			return hit ~= nil and hit.Distance < (b - a).Magnitude - 0.5
		end,
	})
	local how = if shot
		then string.format(" (height %.0f, yaw %d, %.1f studs)", shot.height, shot.yaw, shot.distance)
		else ""
	check(shot ~= nil, "L5 kit: a clear 9:16-safe Line-up shot" .. how)
	if shot then
		-- BIG: the tall Toy Shop never stands between the Line-up camera and the crew (the cut-away clears it)
		local targets = {}
		for _, sp in out do
			table.insert(targets, origin5c + Vector3.new(sp.x, l5c.floorY + 3, sp.z))
		end
		local ok, by, hid = cutSees(
			b5c.model,
			origin5c + Vector3.new(shot.pos[1], shot.pos[2], shot.pos[3]),
			origin5c + Vector3.new(shot.look[1], shot.look[2], shot.look[3]),
			nil,
			targets
		)
		check(
			ok,
			"BIG: the Line-up shot sees the whole crew past the tall building (" .. by .. "; hides " .. hid .. ")"
		)
		-- the level intro (diorama framing) on each of L5's stops: Gus in the back office through the opened roof
		local stops = PresentPlanBig.introStops(l5c, true, 0, 4)
		local okI, byI = true, "clear"
		for _, st in stops do
			local stop = origin5c + Vector3.new(st[1], st[2], st[3])
			local D2 = camCfg.DIORAMA
			local posL = CameraMath.orbit({ st[1], st[2], st[3] }, 0, D2.PITCH, D2.DISTANCE)
			local o2, b2 = cutSees(b5c.model, origin5c + Vector3.new(posL[1], posL[2], posL[3]), stop, nil, { stop })
			if not o2 then
				okI, byI = false, b2
			end
		end
		check(okI and #stops > 0, "BIG: the level intro sees its stops through the opened roof (" .. byI .. ")")
	end
else
	check(false, "L5 builds with the kit for the Line-up shot")
end

-- J. First person (PLAN_FIRST_PERSON FP): the placeholder hands build (palette colours, never grey, quiet
-- parts, drawn close to the eye), a kit viewmodel binds its parts to GripR / GripL, the held-loot copy of the
-- real L1 cash (scaled, visuals only), the fp camera frame (never rolls; the eye over a real R15 head), and
-- look-to-interact on the real kit L1 (workspace raycasts against the built level, Christmas layer on): the
-- cash is picked from in front of it, never through the back wall, and never beyond the sim's range.
-- CameraDirector / Viewmodel / LookTarget themselves bind to RenderStepped (a client: Studio or a phone).
do
	local FpMath = require(clientHeist:WaitForChild("FpMath"))
	local Viewmodel = require(clientHeist:WaitForChild("Viewmodel"))
	local LookTarget = require(clientHeist:WaitForChild("LookTarget"))
	local CamDir = require(clientHeist:WaitForChild("CameraDirector"))
	local Cfg = require(shared:WaitForChild("Config")) :: any
	local FPC = Cfg.FirstPerson
	local okVm, vmErr = pcall(function(): string
		local rig = Viewmodel.buildPlaceholder()
		rig.model.Parent = scratch
		local n, grey, loud, farthest = 0, 0, 0, 0
		local defaultGrey = Color3.fromRGB(163, 162, 165)
		for _, p in rig.model:GetDescendants() do
			if p:IsA("BasePart") then
				n += 1
				local c = p.Color
				local sat = math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B)
				if c == defaultGrey or (sat < 0.03 and c.R > 0.25 and c.R < 0.8) then
					grey += 1
				end
				if not p.Anchored or p.CanCollide or p.CanQuery or p.CanTouch or p.CastShadow then
					loud += 1
				end
				farthest = math.max(farthest, p.Position.Magnitude + p.Size.Magnitude / 2)
			end
		end
		assert(n >= 24, "placeholder parts: " .. n)
		-- rigid parts + the hinged finger segments' parts (REVIEW #10)
		local function count(hand: any): number
			local c = #hand.parts
			for _, f in hand.fingers or {} do
				c += #f.parts
			end
			return c
		end
		local nR, nL = count(rig.R), count(rig.L)
		assert(nR >= 12 and nL > nR, string.format("two hands, the watch on the left (%d, %d parts)", nR, nL))
		assert(#rig.R.fingers == 3 and #rig.L.fingers == 3, "placeholder fingers hinge (index, the rest, thumb)")
		assert(grey == 0, grey .. " grey part(s)")
		assert(loud == 0, loud .. " part(s) collide, query, touch or cast shadows")
		assert(farthest < 1.4, string.format("scaled close to the grip (%.2f studs)", farthest))
		-- pose both hands at a camera, as Viewmodel's frame does
		local cam = CFrame.new(0, 60, 0)
		local vmParts, vmCfs = {}, {}
		for _, side in { "R", "L" } do
			local pose = FPC.VIEWMODEL.REST[side]
			local s = FPC.VIEWMODEL.SCALE
			local at = cam
				* CFrame.new(pose[1] * s, pose[2] * s, pose[3] * s)
				* CFrame.Angles(math.rad(pose[4]), math.rad(pose[5]), math.rad(pose[6]))
			local hand = (rig :: any)[side]
			for i, p in hand.parts do
				table.insert(vmParts, p)
				table.insert(vmCfs, at * hand.offsets[i])
			end
		end
		workspace:BulkMoveTo(vmParts, vmCfs, Enum.BulkMoveMode.FireCFrameChanged)
		local worst = 0
		for _, p in vmParts do
			local local_ = cam:PointToObjectSpace(p.Position)
			worst = math.max(worst, local_.Magnitude)
			assert(local_.Z < 0.5, "every part is in front of (or beside) the eye")
		end
		assert(worst < 1.6, string.format("posed within %.2f studs of the eye", worst))
		-- a kit viewmodel: parts follow the grip they are nearest to (or named for)
		local kit = Instance.new("Model")
		kit.Name = "Rookie_Viewmodel"
		local function kp(name: string, x: number): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Size = Vector3.new(0.6, 0.4, 1)
			p.Position = Vector3.new(x, 0, 0)
			p.Parent = kit
			return p
		end
		local r, l = kp("GloveR", 0.6), kp("GloveL", -0.6)
		local sleeve = kp("RightSleeve", -0.1)
		local ga, gb = Instance.new("Attachment"), Instance.new("Attachment")
		ga.Name, gb.Name = "GripR", "GripL"
		ga.Parent, gb.Parent = r, l
		local kr = Viewmodel.fromKit(kit)
		assert(kr and kr.kit, "the kit model binds")
		assert(#kr.R.parts == 2 and #kr.L.parts == 1, "grips: by name, then nearest")
		assert(not (kr.R.parts[1] :: BasePart).CanQuery, "kit parts are quiet")
		sleeve:Destroy()
		return string.format("%d parts, %d right / %d left, farthest %.2f", n, #rig.R.parts, #rig.L.parts, farthest)
	end)
	check(okVm, "first person: the placeholder hands and a kit viewmodel (" .. tostring(vmErr) .. ")")

	local okCam, camErr = pcall(function(): string
		for _, yp in { { 0, 0 }, { 37, 25 }, { -140, -70 }, { 179, 80 } } do
			local cf = CamDir.lookFrame(Vector3.new(1, 2, 3), yp[1], yp[2])
			local want = FpMath.look(yp[1], yp[2])
			local lv = cf.LookVector
			assert((lv - Vector3.new(want[1], want[2], want[3])).Magnitude < 1e-5, "look direction")
			assert(math.abs(cf.RightVector.Y) < 1e-6, "never rolls")
		end
		local desc = Instance.new("HumanoidDescription")
		local model = Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
		model:PivotTo(CFrame.new(0, 80, 0))
		model.Parent = scratch
		local rootI = model:FindFirstChild("HumanoidRootPart")
		local headI = model:FindFirstChild("Head")
		assert(rootI and rootI:IsA("BasePart") and headI and headI:IsA("BasePart"), "an R15 root and head")
		local root, head = rootI :: BasePart, headI :: BasePart
		local dy = head.Position.Y - root.Position.Y
		local eye = FpMath.eye({ root.Position.X, root.Position.Y, root.Position.Z }, dy, 0, Cfg.Heist.CAMERA.FP)
		local headTop = head.Position.Y + head.Size.Y / 2
		assert(eye[2] > head.Position.Y and eye[2] < headTop + 0.1, "the eye is in the head")
		return string.format("head %.2f above the root, eye %.2f", dy, eye[2] - root.Position.Y)
	end)
	check(
		okCam,
		"first person: the camera frame never rolls; the eye sits in a real R15 head (" .. tostring(camErr) .. ")"
	)

	if okL1 and b1 then
		local okPick, pickErr = pcall(function(): string
			local cash: BasePart? = nil
			for _, d in b1.model:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("EH_Kind") == "loot" and d:GetAttribute("EH_Index") == 1 then
					cash = d
				end
			end
			assert(cash, "the L1 cash part")
			local cashPart = cash :: BasePart
			-- the held copy (first person draws it in your hands)
			local copy = Viewmodel.heldCopy(cashPart)
			copy.Parent = scratch
			local longest = math.max(copy.Size.X, copy.Size.Y, copy.Size.Z)
			local want = FPC.VIEWMODEL.CARRY.LOOT_SIZE * FPC.VIEWMODEL.SCALE
			assert(math.abs(longest - want) < 1e-3, string.format("held copy scaled (%.3f vs %.3f)", longest, want))
			assert(not copy.CanQuery and not copy.CanCollide, "held copy is quiet")
			for _, d in copy:GetDescendants() do
				assert(not d:IsA("ParticleEmitter") and not d:IsA("BillboardGui"), "visuals only: " .. d.ClassName)
			end
			local to = cashPart.Position
			local LK = FPC.LOOK
			local entries = { { kind = "loot", index = 1, part = cashPart, value = 100 } }
			local function pickFrom(eyeV: Vector3, rootV: Vector3, reach: number): (number?, any)
				local cands = LookTarget.candidates(entries, rootV, { carrying = false, bagFull = false })
				local eye = { eyeV.X, eyeV.Y, eyeV.Z }
				local d = to - eyeV
				local dir = { d.Unit.X, d.Unit.Y, d.Unit.Z }
				local i = FpMath.pick(eye, dir, cands, {
					reach = reach,
					assist = LK.ASSIST.mouse,
					distanceWeight = LK.DISTANCE_WEIGHT,
					sticky = LK.STICKY,
					losCandidates = LK.LOS_CANDIDATES,
					blocked = function(_e: { number }, c: any): boolean
						return not LookTarget.lineOfSight(eyeV, to, c.radius, cashPart, {})
					end,
				})
				return i, cands
			end
			-- In front of it, inside the back room (eye height over your root).
			local frontRoot = to + Vector3.new(0, -1, 3.5)
			local frontEye = frontRoot + Vector3.new(0, 1.65, 0)
			local i1, c1 = pickFrom(frontEye, frontRoot, LK.REACH)
			assert(c1[1].ok, "inside the sim's range from in front")
			assert(i1 == 1, "the cash is picked from in front of it")
			-- Behind the back wall, just outside the shop: blocked even with a long reach.
			local wallZ = math.huge
			for _, sd in l1.solids do
				if sd.minX <= to.X - origin1.X and sd.maxX >= to.X - origin1.X and sd.maxZ < to.Z - origin1.Z then
					if sd.maxY > 5 then
						wallZ = math.min(wallZ, sd.minZ)
					end
				end
			end
			assert(wallZ < math.huge, "a back wall behind the cash")
			local backEye = Vector3.new(to.X, to.Y + 2, origin1.Z + wallZ - 0.8)
			local i2 = pickFrom(backEye, backEye - Vector3.new(0, 1.65, 0), (to - backEye).Magnitude + 2)
			assert(i2 == nil, "not through the back wall")
			-- Out of the sim's range (the server would refuse it): never offered, even in plain view.
			local farRoot = to + Vector3.new(0, -1, Cfg.Sim.INTERACT_RANGE + 0.5)
			local _, c3 = pickFrom(farRoot + Vector3.new(0, 1.65, 0), farRoot, 50)
			assert(c3[1].ok == false, "beyond the sim's range")
			-- GOLDEN_FRAMES G1 in first person: from the staged stand on the street (GOLDEN.G1.STAND, the eye at 3.8)
			-- the staged look keeps the cash in a 16:9 frame, the frame's top runs well up the tenement, and the
			-- stand is clear of the van and the kerb props
			local Scenario = require(shared:WaitForChild("Heist"):WaitForChild("Scenario"))
			local CameraDirector = require(clientHeist:WaitForChild("CameraDirector")) :: any
			local G1 = Cfg.Heist.CAMERA.GOLDEN.G1
			local standEye = origin1 + Vector3.new(G1.STAND[1], (l1.floorY or 0) + 3.8, G1.STAND[2])
			local yawG, pitchG = Scenario.fpLook(G1, { standEye.X, standEye.Y, standEye.Z }, { to.X, to.Y, to.Z })
			local camG = CameraDirector.lookFrame(standEye, yawG, pitchG)
			assert(inFrame(camG, to, G1.FOV), "G1: the cash is in the frame")
			assert(-pitchG + G1.FOV / 2 > 45, "G1: the frame looks up the tenement")
			local free = workspace:GetPartBoundsInRadius(standEye - Vector3.new(0, 1.5, 0), 1.2)
			local blocking = 0
			for _, bp in free do
				if bp.CanCollide and bp:IsDescendantOf(b1.model) then
					blocking += 1
				end
			end
			assert(blocking == 0, "G1: the stand is clear (" .. blocking .. " solid parts)")
			local top = to + Vector3.new(0, cashPart.Size.Y / 2, 0)
			local seen = sightTo(standEye, top, cashPart)
			return string.format(
				"cash at %.1f studs from the front eye; G1 stand %.0f studs away, cash top %s",
				(to - frontEye).Magnitude,
				(to - standEye).Magnitude,
				if seen then "in sight" else "behind the sill"
			)
		end)
		check(
			okPick,
			"first person: kit L1 cash picked from in front, not through the back wall; G1 staged look ("
				.. tostring(pickErr)
				.. ")"
		)
	else
		check(false, "first person: L1 builds for the look-to-interact checks")
	end
end

-- H. Signature moments (PLAN_STEAM_PLUS §4.4 F2, §5 "8 OF ME"): the G2 staging's seven Clone Party
-- tapes (src/server/Heist/StagingTapes.luau) drawn by EchoView + you (a copy of your template on the
-- spawn) = 8 rigs, all Rookies (docs/GOLDEN_FRAMES.md G2, REVIEW_STEAM_PLUS #4: your clone template is the Rookie
-- in your outfit, server Heist/Avatars.buildRookie, so every copy is a Rookie with its crew pieces in your hue). MomentDirector's 8 OF ME moment runs on hand-stepped frames (Luau Execution
-- servers do not simulate or render): the roll call hops each clone 60 ms apart in record order and
-- lights 8 numbered pills, the world dims 15 %, and the camera shot it hands to CameraDirector keeps
-- every one of the 8 rigs (their real parts) inside the central 32 % of a 16:9 frame. Then the
-- hit-stop rule and the blooper cut's replay window on the same run.
local okMoment, momentInfo = pcall(function()
	local Config = require(shared:WaitForChild("Config")) :: any
	local MS = Config.Moments.SWARM
	local SHARE = Config.Heist.CAMERA.LINEUP.CENTRAL_SHARE
	local Codec = require(shared:WaitForChild("Rec"):WaitForChild("Codec"))
	local EV = require(shared:WaitForChild("Sim"):WaitForChild("EventLog")).EV
	local EchoView = require(clientHeist:WaitForChild("EchoView"))
	local MomentDirector = require(clientHeist:WaitForChild("MomentDirector"))
	local StagingTapes = require(heistServer:WaitForChild("StagingTapes"))
	local partyIndex = Protocol.catalogIndex(StagingTapes.LEVEL) :: number
	local party = HeistInstance.levelData(partyIndex)
	local OWNER = -4242
	local originM = Vector3.new(-9000, 0, -6000)
	local recs, actors, byId = {}, {}, {}
	for k, buf in StagingTapes.buffers() do
		local rec = Codec.decode(buf)
		assert(rec, "tape " .. k .. " decodes")
		recs[k] = rec
		local a = { id = k, kind = "clone", owner = OWNER, seat = 1, slot = k, run = k, key = k }
		actors[k] = a
		byId[k] = a
	end
	assert(#actors == 7, "seven staging tapes")
	local msg = { run = 8, actors = actors, actorById = byId, transition = 0 }
	local vstate: any = {
		origin = originM,
		level = party,
		levelIndex = partyIndex,
		crew = { { userId = OWNER, seat = 1 } },
		mySeat = 1,
		actorFx = {},
		run = msg,
		phase = "Run",
		viewerId = OWNER,
		reduced = false,
		particleScale = 1,
	}
	local Avatars = require(heistServer:WaitForChild("Avatars"))
	local Outfit = require(shared:WaitForChild("Heist"):WaitForChild("Outfit"))
	local Palette = require(shared:WaitForChild("Heist"):WaitForChild("Palette"))
	local template = Avatars.buildRookie(OWNER, Outfit.default(), nil)
	assert(template and template:GetAttribute("EH_Rookie") == true, "your clone template is the Rookie")
	local echo = EchoView.new(vstate)
	echo.setRun(msg, recs, os.clock() - 5)
	-- you: a copy of your Rookie template on the spawn with a HumanoidRootPart, the 8th rig
	local spawn = party.spawns[1]
	local youRig = Rigs.buildAvatar(template :: Model) or Rigs.buildMannequin()
	youRig.model.Parent = scratch
	local youModel = Instance.new("Model")
	youModel.Name = "You"
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Anchored = true
	hrp.Transparency = 1
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Position = originM + Vector3.new(spawn.x, spawn.y, spawn.z)
	hrp.Parent = youModel
	youModel.Parent = scratch
	local partsY, cfsY = {}, {}
	Rigs.pose(youRig, CFrame.new(originM + Vector3.new(spawn.x, party.floorY, spawn.z)), 0, 0, partsY, cfsY)
	workspace:BulkMoveTo(partsY, cfsY, Enum.BulkMoveMode.FireCFrameChanged)

	local shotFn: any = nil
	local fakeCamera = {
		setMomentShot = function(fn: any)
			shotFn = fn
		end,
		isSuspended = function(): boolean
			return false
		end,
	}
	local gui = Instance.new("ScreenGui")
	gui.Parent = scratch
	local moments = MomentDirector.new(vstate, {
		gui = gui,
		hud = { setCutscene = function(_on: boolean) end },
		echo = echo,
		camera = fakeCamera,
		myId = OWNER,
		character = function(): Model?
			return youModel
		end,
		aspect = function(): number
			return 16 / 9
		end,
	})
	local tView, dt = 3.0, 1 / 60
	local clock = os.clock()
	for _ = 1, 3 do
		clock += dt
		echo.update(tView, clock, dt, nil)
	end
	local t0 = clock
	moments.swarm({ kind = EV.Swarm, a = 1, b = 8, c = 8 }, t0)
	local plan = moments.swarmPlan()
	assert(plan and #plan.members == 8, "8 copies in the roll call (" .. tostring(plan and #plan.members) .. ")")
	for i = 1, 7 do
		assert(plan.members[i].id == i, "record order: member " .. i .. " is clone " .. tostring(plan.members[i].id))
	end
	assert(plan.members[8].id == nil, "you are the last copy")
	assert(shotFn ~= nil, "the pull-back took the camera")
	-- hand-stepped frames: when each clone's hop starts, the dim's deepest tint, the pills
	local hopAt: { [number]: number } = {}
	local minTint = 1
	local dimFx: any = nil
	local framed: any = nil
	local hold = t0 + MS.CAM_IN + 0.05
	while clock < t0 + 1.4 do
		clock += dt
		echo.update(tView, clock, dt, nil)
		moments.step(clock, dt)
		for i = 1, 7 do
			if not hopAt[i] and echo.hopOf(i) > 0 then
				hopAt[i] = clock
			end
		end
		local cam = workspace.CurrentCamera
		dimFx = dimFx or (cam and cam:FindFirstChild("EH_MomentDim"))
		if dimFx and dimFx.Enabled then
			minTint = math.min(minTint, dimFx.TintColor.R)
		end
		if not framed and clock >= hold then
			local cf, fov, w, fits = moments.swarmShot(clock)
			framed = { cf = cf, fov = fov, w = w, fits = fits }
		end
	end
	for i = 1, 7 do
		assert(hopAt[i], "clone " .. i .. " took its pose beat")
		if i > 1 then
			local gap = hopAt[i] - hopAt[i - 1]
			assert(
				math.abs(gap - MS.ROLL_STAGGER) <= dt + 1e-6,
				string.format("beat %d is %.3f s after %d", i, gap, i - 1)
			)
		end
	end
	assert(math.abs(minTint - (1 - MS.DIM)) < 0.02, string.format("the world dims 15 %% (tint %.3f)", minTint))
	local ink = require(shared:WaitForChild("Heist"):WaitForChild("Palette")).ink
	local row = gui:FindFirstChild("RollCall", true)
	local lit = 0
	for _, p in (row and row:GetChildren()) or {} do
		if p:IsA("Frame") and p.Visible and p.BackgroundColor3 ~= ink then
			lit += 1
		end
	end
	assert(lit == 8, "8 numbered pills lit (" .. lit .. ")")
	-- the framing: every rig's real parts inside the central 32 % of a 16:9 frame
	assert(framed and framed.cf and framed.fits and framed.w > 0.99, "the pull-back is in and fits")
	local tv = math.tan(math.rad(framed.fov) / 2)
	local worst = 0
	local function check8(model: Model)
		local cf, size = model:GetBoundingBox()
		for _, dy in { size.Y / 2, -size.Y / 2 } do
			local p = (cf * CFrame.new(0, dy, 0)).Position
			local lp = framed.cf:PointToObjectSpace(p)
			local depth = -lp.Z
			assert(depth > 0.1, "in front of the camera")
			worst = math.max(worst, math.abs(lp.X) / (depth * tv * 16 / 9))
		end
	end
	local seatHue = Palette.hueFor(1)
	for i = 1, 7 do
		local rig = echo.rigOf(i)
		assert(rig, "clone " .. i .. " has a rig")
		assert(rig.model:GetAttribute("EH_Rookie") == true, "clone " .. i .. " is a Rookie (not a mannequin)")
		-- only the crew pieces take the clone's hue (one colour: your seat hue, aged), the outfit keeps its own
		local crewPieces, colours, newest = 0, {}, i == 7
		for _, d in rig.model:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("EH_Tint") == "crew" then
				crewPieces += 1
				colours[d.Color:ToHex()] = true
				if newest then
					local h = d.Color:ToHSV()
					local sh = seatHue:ToHSV()
					assert(math.min(math.abs(h - sh), 1 - math.abs(h - sh)) < 0.05, "the newest clone in your hue")
				end
			end
		end
		local nColours = 0
		for _ in colours do
			nColours += 1
		end
		assert(
			crewPieces >= 1 and nColours == 1,
			"clone " .. i .. ": crew pieces tinted (" .. crewPieces .. " pieces, " .. nColours .. " colours)"
		)
		check8(rig.model)
	end
	assert(youRig.model:GetAttribute("EH_Rookie") == true, "you are a Rookie too")
	check8(youRig.model)
	assert(worst <= SHARE + 0.02, string.format("all 8 inside the central 32 %% (widest %.3f)", worst))
	-- BIG: the tall Toy Shop over the swarm: the pull-back sees all 8 through the cut-away
	do
		local partyBuilt = LevelBuilder.build(party, originM, scratch, {
			kit = if KitService.isReady() then KitService else nil,
			dressing = true,
		})
		local targets = {}
		for i = 1, 7 do
			local rig = echo.rigOf(i)
			table.insert(targets, (rig.model:GetBoundingBox()).Position)
		end
		local ok8, by8, hid8 = cutSees(
			partyBuilt.model,
			framed.cf.Position,
			framed.cf.Position + framed.cf.LookVector * 30,
			originM + Vector3.new(spawn.x, spawn.y, spawn.z),
			targets
		)
		assert(ok8, "the pull-back sees all 8 through the tall Toy Shop (" .. by8 .. "; hides " .. hid8 .. ")")
		partyBuilt.model:Destroy()
	end

	-- hit-stop: only the four heavy beats; the filter holds the view time through it
	assert(not moments.hitStop("plate", clock), "no hit-stop on a routine beat")
	moments.filter(5, clock, dt) -- the last frame before the beat
	assert(moments.hitStop("busted", clock), "hit-stop on your catch")
	local held, heldDt = moments.filter(5.5, clock + 0.03, dt)
	assert(held == 5 and heldDt == 0, "the view holds for 66 ms")
	local free = moments.filter(5.6, clock + 0.1, dt)
	assert(free == 5.6, "and moves on after")

	-- the blooper cut: clone 3 busted at 12 s replays from 9 s, at most 4 s, then the Line-up
	moments.onEvent({ kind = EV.Busted, a = 1, b = 3, c = 0, tick = 12 * Config.Rec.HZ + 1 }, false)
	local after = false
	assert(
		moments.blooper({}, function()
			after = true
		end, clock),
		"a blooper plays"
	)
	local first, last = nil, nil
	local c2 = clock
	while not after and c2 < clock + 8 do
		c2 += dt
		moments.step(c2, dt)
		if vstate.replayT then
			first = first or vstate.replayT
			last = vstate.replayT
		end
	end
	assert(after, "the Line-up follows")
	assert(first and math.abs(first - 9) < 0.05, "replay starts 3 s before the bust (" .. tostring(first) .. ")")
	assert(last and last - first <= Config.Moments.BLOOPER.MAX + 1e-6, "<= 4 s")
	assert(vstate.replayT == nil and vstate.actorFx ~= nil, "view time and fx restored")
	moments.stop()
	echo.clear()
	youRig.model:Destroy()
	template:Destroy()
	return string.format(
		"8 Rookies; hops %.3f s apart, widest %.3f of the width, tint %.2f",
		(hopAt[7] - hopAt[1]) / 6,
		worst,
		minTint
	)
end)
check(
	okMoment,
	"8 OF ME on the G2 tapes: roll call, dim, pills, framing in the central 32 %; hit-stop; blooper ("
		.. tostring(momentInfo)
		.. ")"
)

-- I. Presentation shell (PLAN_STEAM_PLUS §3.4, §4.1 W7, §4.2 C4; POLISH §4.6): the ReplicatedFirst
-- loading card and the title card build in the engine (no images, no ReplicatedStorage), the reel and
-- the stage hint step by hand (Luau Execution servers render nothing: RenderStepped never fires, so
-- spin / setStage are called directly), and the van doors cover / open. Title.play and Loading.reel
-- bind RenderStepped and only run on a client, so they are not called here.
local okShell, shellErr = pcall(function()
	local rf = game:GetService("ReplicatedFirst")
	local loadingScript = rf:WaitForChild("Loading", 5)
	assert(loadingScript and loadingScript:IsA("LocalScript"), "ReplicatedFirst.Loading is a LocalScript")
	local Brand = require(rf:WaitForChild("Brand"))
	local LoadingCard = require(rf:WaitForChild("LoadingCard"))
	local holder = Instance.new("Folder")
	holder.Parent = scratch

	local t0 = os.clock()
	local card = LoadingCard.build(holder)
	local buildMs = (os.clock() - t0) * 1000
	assert(buildMs < 50, string.format("the first frame builds in %.1f ms (< 50)", buildMs))
	local gui = card.gui
	assert(gui:IsA("ScreenGui") and gui.Name == Brand.GUI_NAME, "card ScreenGui")
	assert(gui.DisplayOrder == Brand.LOADING.ORDER and gui.IgnoreGuiInset and not gui.ResetOnSpawn, "card layer")
	assert(card.bg.BackgroundColor3:ToHex():upper() == string.sub(Brand.COLOR.ink, 2):upper(), "ink background")
	local mark = card.mark
	assert(mark.main.Text == Brand.WORDMARK, "wordmark text")
	assert(string.find(mark.main.FontFace.Family, Brand.FACE, 1, true), "display face " .. mark.main.FontFace.Family)
	assert(#mark.copies == 1 and mark.copies[1].TextTransparency == 0, "one cyan double-exposure copy")
	assert(mark.copies[1].ZIndex < mark.main.ZIndex, "the copy draws behind the white mark")
	assert(mark.copies[1].Position.X.Offset > 0 and mark.copies[1].Position.Y.Offset > 0, "offset down-right")
	assert(mark.strap and mark.strap.Text == Brand.STRAP, "strap")
	assert(mark.main:FindFirstChildOfClass("UIStroke"), "ink stroke on the mark")
	for k = 1, 3 do
		assert(card.reel:FindFirstChild("Hole" .. k), "reel hole " .. k)
	end
	for _, d in gui:GetDescendants() do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then
			error("the card uses no images (it draws before any asset): " .. d:GetFullName())
		end
	end
	-- Step by hand: the reel turns with the clock, stands still under reduced motion.
	LoadingCard.spin(card.reel, 0.3, false)
	local a = card.reel.Rotation
	LoadingCard.spin(card.reel, 0.6, false)
	assert(math.abs(card.reel.Rotation - a - 90) < 1e-3, "a quarter turn in 0.3 s at 1.2 s a turn")
	LoadingCard.spin(card.reel, 0.6, true)
	assert(card.reel.Rotation == 0, "reduced motion: still")
	-- The quiet progress hint: one line and one more pip per real stage.
	for index, stage in Brand.STAGES do
		LoadingCard.setStage(card, stage)
		assert(card.hint.Text == Brand.HINTS[stage], "hint " .. stage)
		local lit = 0
		for _, pip in card.pips do
			if pip.BackgroundColor3 == Color3.fromHex(Brand.COLOR.white) then
				lit += 1
			end
		end
		assert(lit == index, stage .. ": " .. lit .. " pips lit")
		assert(not string.find(string.lower(card.hint.Text), "loading", 1, true), "never a bare Loading")
	end
	local goals = LoadingCard.fadeGoals(gui)
	local fadesInk = false
	for _, pair in goals do
		fadesInk = fadesInk or (pair[1] == card.bg and pair[2].BackgroundTransparency == 1)
	end
	assert(#goals > 10 and fadesInk, "the fade reaches the ink and every label")
	-- The dismissal attributes the client sets are plain attributes on the card.
	gui:SetAttribute(Brand.ATTR.HOLD, true)
	assert(gui:GetAttribute(Brand.ATTR.HOLD) == true, "hold attribute")

	-- The title card: the same frame one layer up, with three copies (2 and 3 hidden in copy 1's place).
	local titleCard = LoadingCard.build(holder, { name = "EH_Title", order = Brand.LOADING.ORDER + 1, copies = 3 })
	local tm = titleCard.mark
	assert(#tm.copies == 3, "three copies")
	assert(tm.copies[2].TextTransparency == 1 and tm.copies[3].TextTransparency == 1, "copies 2, 3 start hidden")
	assert(tm.copies[3].Position == mark.copies[1].Position, "stacked on the double exposure")
	assert(tm.root.Position == mark.root.Position and tm.main.Size == mark.main.Size, "same frame as the card")
	assert(titleCard.reel.Position == card.reel.Position, "the reel in the same place")
	assert(tm.copies[2].TextColor3 ~= tm.copies[1].TextColor3, "copy 2 in another clone hue")

	-- The van doors in a stand-in fx layer.
	local Transition = require(clientHeist:WaitForChild("Transition"))
	local layer = Instance.new("ScreenGui")
	layer.Parent = holder
	local reduced = false
	local doors = Transition.new(layer, function()
		return reduced
	end)
	local left = layer:WaitForChild("VanDoorLeft", 1) :: Frame
	local right = layer:WaitForChild("VanDoorRight", 1) :: Frame
	assert(left and right and not left.Visible, "doors start open (hidden)")
	doors.cover()
	assert(doors.isClosed() and left.Visible and right.Visible, "cover: closed at once")
	assert(left.Position.X.Scale == 0.5 and right.Position.X.Scale == 0.5, "the panels meet in the middle")
	doors.open()
	assert(not doors.isClosed(), "open: no longer closed")
	reduced = true
	doors.cover()
	local veil = layer:WaitForChild("VanDoorVeil", 1) :: Frame
	assert(veil and veil.Visible and veil.BackgroundTransparency == 0 and not left.Visible, "reduced: an ink veil")
	assert(doors.openSeconds() == 0.15, "reduced: a 0.15 s crossfade")
	doors.clear()
	assert(not doors.isClosed() and not veil.Visible and not left.Visible, "clear: open at once (reduced)")
	reduced = false
	doors.cover()
	doors.clear()
	assert(
		not doors.isClosed() and not left.Visible and not right.Visible,
		"clear: the intro's stage is never behind them"
	)
	doors.open()

	local Wordmark = require(rf:WaitForChild("Wordmark"))
	local big = Wordmark.offset(110)
	assert(math.abs(big.X - Brand.WORDMARK_OFFSET[1] * 2) < 1e-6, "the specimen's 110 px mark: offset x2")
	holder:Destroy()
	return string.format("card built in %.1f ms", buildMs)
end)
check(okShell, "presentation shell: loading card, title card, reel, hint, van doors (" .. tostring(shellErr) .. ")")

-- J. The story intro (docs/art/intro/STORYBOARD.md, PLAN_FIRST_PERSON §5): Heist/IntroKit publishes the intro
-- meshes from the real kit, Heist/Cinematic builds the client stage from them and is stepped by hand through
-- every shot (Hoardsworth on his mesh rig and posed, the villain close-up with the gold ring on his glove at the
-- lever's knob and the lever yanked, the presents in the air, the globe filling, the lit garage (aurora door glow,
-- high windows, string lights, then the headlights, their beams and the work lamp) with the Rookie and the clones'
-- tape print, the wordmark), then a SKIP lands in the same end state, and the camera, Lighting and Sky are
-- restored both times. Times come from IntroPlan.at (shot id, seconds into it), so a retimed plan keeps the beats.
local okIntro, introErr = pcall(function()
	local IntroKit = require(heistServer:WaitForChild("IntroKit"))
	local Cinematic = require(clientHeist:WaitForChild("Cinematic"))
	local IntroPlan = require(shared:WaitForChild("Heist"):WaitForChild("IntroPlan"))
	local Config = require(shared:WaitForChild("Config")) :: any
	local Lighting = game:GetService("Lighting")
	local groups = IntroKit.publishNow(KitService)
	-- the CHARACTER track's CharacterKit (server Heist/Rookie publishes it about 3 s after the kit loads)
	if ReplicatedStorage:FindFirstChild(Config.Intro.CHARACTER_KIT) == nil then
		pcall(function()
			require(heistServer:WaitForChild("Rookie")).publishNow(KitService)
		end)
	end
	local kitFolder = ReplicatedStorage:WaitForChild(Config.Intro.CHARACTER_KIT, 20)
	assert(kitFolder and kitFolder:WaitForChild(Config.Intro.ROOKIE_TEMPLATE, 10), "CharacterKit.Rookie published")
	assert(groups >= #IntroKit.MODELS - 1, "intro kit groups published: " .. groups .. "/" .. #IntroKit.MODELS)
	local origin = Vector3.new(table.unpack(Config.Intro.STAGE_ORIGIN))
	local ST = IntroPlan.STAGE
	local function world(p: { number }): Vector3
		return origin + Vector3.new(p[1], p[2], p[3])
	end
	local holder = Instance.new("Folder")
	holder.Name = "IntroTest"
	holder.Parent = workspace
	local cam = Instance.new("Camera")
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = 70
	cam.Parent = holder
	local ambient = Lighting.Ambient
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local skyYaw = if sky then sky.SkyboxOrientation else nil
	local ended: string? = nil
	local t0 = os.clock()
	local cine = Cinematic.new({
		parent = holder,
		gui = holder,
		camera = cam,
		tier = 1,
		reduced = function()
			return false
		end,
		onEnd = function(how: string)
			ended = how
		end,
	})
	local buildMs = (os.clock() - t0) * 1000
	local stage = cine.stage()
	assert(
		stage:FindFirstChild("Town") and stage:FindFirstChild("Top") and stage:FindFirstChild("Aurora"),
		"stage parts"
	)
	assert(cine.gui():FindFirstChild("Skip"), "SKIP from the first frame")
	local auroraFolder = stage:FindFirstChild("Aurora")
	assert(auroraFolder and auroraFolder:FindFirstChild("EH_Aurora"), "the sky is the game's Heist/Aurora")
	local town = stage:FindFirstChild("Town")
	local towerModel = town and town:FindFirstChild("Intro_Tower")
	assert(towerModel and towerModel:FindFirstChild("Intro_Tower_Sign", true), "Hoardsworth Tower is the kit landmark")
	local counts = cine.counts()
	assert(counts.windows > #ST.houses, "lit windows (the town's and the tower's): " .. counts.windows)
	local vortexBeams = 0
	local vortexPart = stage:FindFirstChild("Vortex", true)
	for _, d in (if vortexPart then vortexPart:GetChildren() else {}) do
		if d:IsA("Beam") then
			vortexBeams += 1
		end
	end
	local V = Config.Intro.VORTEX
	assert(vortexBeams == V.ARMS[1] * (V.POINTS - 1), "the suction vortex at tier 1: " .. vortexBeams .. " Beams")
	for _, d in stage:GetDescendants() do
		if d:IsA("BasePart") then
			assert(d.Anchored and not d.CanCollide and not d.CanQuery, d:GetFullName() .. " is quiet")
		end
	end
	local dt = 1 / 30
	local function stepTo(t: number)
		while cine.t() < t and not cine.isDone() do
			cine.step(dt)
		end
	end
	local function into(id: string, s: number): number
		return IntroPlan.at(id, s)
	end
	stepTo(into("hoard", 2.0)) -- shot 2: Hoardsworth, low angle
	assert(cine.hoardKind() == "mesh", "Hoardsworth on his mesh rig (" .. cine.hoardKind() .. ")")
	assert(cam.CameraType == Enum.CameraType.Scriptable, "the intro owns the camera")
	local hw = world(ST.hoardsworth.at)
	assert((cam.CFrame.Position - hw).Magnitude < 20, "the camera is on Hoardsworth")
	local hoard = stage:FindFirstChild("Hoardsworth")
	local headInst = if hoard then hoard:FindFirstChild("Hoardsworth_Head") else nil
	local head = if headInst and headInst:IsA("BasePart") then headInst else nil
	assert(head and math.abs(head.Position.Y - (hw.Y + 6.6)) < 1.5, "his head is at head height (posed rig)")
	local ringInst = hoard and hoard:FindFirstChild("Hoardsworth_Ring")
	assert(ringInst and ringInst:IsA("BasePart"), "the gold ring on his glove")
	stepTo(into("laugh", 1.6)) -- shot 3: the villain close-up, his hand on the lever's knob
	local monoInst = hoard and hoard:FindFirstChild("Hoardsworth_Monocle")
	assert(monoInst and (cam.CFrame.Position - (monoInst :: BasePart).Position).Magnitude < 8, "a close-up on his face")
	assert(cam.FieldOfView <= 40, "a tight lens (" .. cam.FieldOfView .. ")")
	local knob = world(ST.knob)
	local handInst = hoard and hoard:FindFirstChild("Hoardsworth_RightHand")
	assert(
		handInst and ((handInst :: BasePart):GetPivot().Position - knob).Magnitude < 1.2,
		"the glove grips the lever's knob"
	)
	assert(((ringInst :: BasePart).Position - knob).Magnitude < 1.2, "the ring rides the glove")
	local inView = cam.CFrame:PointToObjectSpace((ringInst :: BasePart).Position)
	assert(inView.Z < 0, "the ring is in front of the camera")
	local handle = stage:FindFirstChild("Intro_Lever_Handle", true)
	local handleUp = if handle and handle:IsA("BasePart") then handle.CFrame else nil
	stepTo(into("laugh", 3.2)) -- the yank
	if handle and handle:IsA("BasePart") and handleUp then
		local turned = math.deg(math.acos(math.clamp(handle.CFrame.UpVector:Dot(handleUp.UpVector), -1, 1)))
		assert(turned > 45, string.format("the lever is yanked down (%.0f deg)", turned))
	end
	stepTo(into("every", 3.6)) -- shot 4: the vacuum and the swirl
	assert(cine.counts().presents == Config.Intro.PRESENTS[1], "presents spawned")
	local inAir = 0
	for _, d in stage:GetChildren() do
		if d.Name == "FlyingPresent" and (d :: BasePart).Transparency == 0 then
			inAir += 1
		end
	end
	assert(inAir > 0, "presents in the air")
	local vortexBeam = if vortexPart then vortexPart:FindFirstChildOfClass("Beam") else nil
	assert(vortexBeam and vortexBeam.Enabled, "the vortex runs with the vacuum")
	stepTo(into("one", 1.0)) -- shot 6 before the headlights: the garage is lit by the aurora and the string lights
	local garageEarly = stage:FindFirstChild("Garage")
	local doorGlow = garageEarly and garageEarly:FindFirstChild("DoorGlow")
	local doorLight = doorGlow and doorGlow:FindFirstChildOfClass("SurfaceLight")
	assert(doorLight and doorLight.Enabled, "the aurora pours in at the door from the first frame")
	local panes, bulbs, shafts, headBeamsN = 0, 0, 0, 0
	for _, d in (garageEarly :: Instance):GetDescendants() do
		if d.Name == "WindowPane" then
			panes += 1
		elseif d.Name == "StringBulb" then
			bulbs += 1
		elseif d:IsA("Beam") and string.sub(d.Name, 1, 5) == "Shaft" then
			shafts += 1
		elseif d:IsA("Beam") and string.sub(d.Name, 1, 8) == "HeadBeam" then
			headBeamsN += 1
			assert(not d.Enabled, "the headlight beams wait for the headlights")
		end
	end
	local GL = Config.Intro.GARAGE
	assert(panes == 2 * #ST.windows, "the high windows glow: " .. panes)
	assert(bulbs >= 20, "the string lights: " .. bulbs)
	assert(shafts == #ST.windows, "window shafts at tier 1: " .. shafts)
	assert(headBeamsN == #ST.headlights * #GL.BEAM.LAYERS, "layered headlight beams: " .. headBeamsN)
	local workLamp = garageEarly and garageEarly:FindFirstChild("WorkLamp")
	local workLight = workLamp and workLamp:FindFirstChildOfClass("SpotLight")
	assert(workLight and not workLight.Enabled, "the work lamp waits for the headlights")
	stepTo(into("one", 5.6)) -- shot 6: the garage, headlights on, the Rookie
	assert(cine.counts().presents == 0, "presents swallowed")
	local rookieKind = cine.rookieKind()
	local characterKit = ReplicatedStorage:FindFirstChild(Config.Intro.CHARACTER_KIT)
	local hasRookie = characterKit ~= nil and characterKit:FindFirstChild(Config.Intro.ROOKIE_TEMPLATE) ~= nil
	assert(rookieKind == (if hasRookie then "characterKit" else "standin"), "the Rookie (" .. rookieKind .. ")")
	if hasRookie then
		local g = stage:FindFirstChild("Garage")
		local rk = g and g:FindFirstChild("Rookie")
		local motors = 0
		for _, d in (if rk then rk:GetDescendants() else {}) do
			if d:IsA("Motor6D") then
				motors += 1
			end
		end
		assert(motors >= 10, "the kit Rookie keeps its R15 motors for posing: " .. motors)
	end
	assert(cine.counts().clones == #ST.clones, "clones built")
	assert((cam.CFrame.Position - world(ST.rookie.at)).Magnitude < 20, "the camera is on the Rookie")
	assert(
		(workLight :: SpotLight).Enabled and math.abs(workLight.Brightness - GL.WORK_LAMP.BRIGHTNESS) < 1e-3,
		"the work lamp is on"
	)
	local litBeams = 0
	for _, d in (garageEarly :: Instance):GetDescendants() do
		if d:IsA("Beam") and string.sub(d.Name, 1, 8) == "HeadBeam" and d.Enabled then
			litBeams += 1
		end
	end
	assert(litBeams == headBeamsN, "the headlight beams are on: " .. litBeams)
	stepTo(into("more", 1.8 + 0.2)) -- shot 7: clone 4 mid tape-print
	local garage = stage:FindFirstChild("Garage")
	local crew = garage and garage:FindFirstChild("Crew")
	assert(crew, "the crew group")
	local hl = crew:FindFirstChildOfClass("Highlight")
	assert(hl and hl.Enabled and hl.Adornee == crew, "one crew-hue Highlight over the clones")
	assert(math.abs(hl.FillTransparency - Config.Heist.CLONE_FILL_TRANSPARENCY) < 1e-6, "EchoView's fill")
	if hasRookie then
		local c4 = crew:FindFirstChild("Clone4")
		local shownLow, hiddenHigh = false, false
		for _, d in (if c4 then c4:GetDescendants() else {}) do
			if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
				if d.Name == "LeftFoot" and d.LocalTransparencyModifier == 0 then
					shownLow = true
				elseif d.Name == "Head" and d.LocalTransparencyModifier == 1 then
					hiddenHigh = true
				end
			end
		end
		assert(shownLow and hiddenHigh, "clone 4 prints from the feet up (feet in, head not yet)")
	end
	stepTo(into("more", 3.6)) -- shot 7: the clones printed in
	local clone1 = crew:FindFirstChild("Clone1")
	if hasRookie then
		local crewHue, kept, printed = 0, 0, true
		for _, d in (clone1 :: Model):GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 1 then
				printed = printed and d.LocalTransparencyModifier < 0.5
				if d:GetAttribute("EH_Tint") == "crew" then
					crewHue += 1
				elseif d.Name == "Rookie_Cap_Flat" then
					kept += 1
				end
			end
		end
		assert(printed, "clone 1 printed in")
		assert(crewHue >= 3 and kept == 1, "a Rookie copy: crew pieces tinted, the outfit kept")
	end
	stepTo(into("title", 1.0)) -- the title smash
	assert(cine.gui():FindFirstChild("Title"), "the wordmark is up")
	local veil = cine.gui():FindFirstChild("TitleVeil")
	assert(
		veil and math.abs((veil :: Frame).BackgroundTransparency - Config.Intro.TITLE_VEIL) < 1e-6,
		"the lit crew shows through the veil"
	)
	stepTo(IntroPlan.total() + 1)
	assert(cine.isDone() and ended == "finished", "watched to the end (" .. tostring(ended) .. ")")
	local want = cine.state()
	cine.destroy()
	assert(holder:FindFirstChild("EH_IntroStage") == nil, "stage torn down")
	assert(cam.CameraType == Enum.CameraType.Custom and cam.FieldOfView == 70, "camera restored")
	assert(Lighting.Ambient == ambient and Lighting:FindFirstChild("EH_IntroGrade") == nil, "Lighting restored")
	assert(sky == nil or sky.SkyboxOrientation == skyYaw, "Sky restored")

	-- SKIP mid-shot lands in the same end state
	local ended2: string? = nil
	local cine2 = Cinematic.new({
		parent = holder,
		gui = holder,
		camera = cam,
		tier = 4,
		reduced = function()
			return true
		end,
		onEnd = function(how: string)
			ended2 = how
		end,
	})
	for _ = 1, 400 do
		cine2.step(dt)
	end
	cine2.skip()
	assert(cine2.isDone() and ended2 == "skipped", "SKIP ends it (" .. tostring(ended2) .. ")")
	local got = cine2.state()
	for k, v in want do
		assert(got[k] == v, "skip end state " .. k .. ": " .. tostring(got[k]) .. " vs " .. tostring(v))
	end
	cine2.destroy()
	assert(
		cam.CameraType == Enum.CameraType.Custom and Lighting:FindFirstChild("EH_IntroBlur") == nil,
		"restored after SKIP"
	)
	holder:Destroy()
	return string.format("stage built in %.0f ms, %d kit groups, rookie %s", buildMs, groups, rookieKind)
end)
check(okIntro, "story intro: kit, stage, every shot stepped, SKIP end state, restore (" .. tostring(introErr) .. ")")
-- L. CH polish + the FP hands pass: on the real CharacterKit, the first-person arms are built in your outfit
-- (Viewmodel.fromOutfit -> the dedicated Rookie_FPArms: the glove variant's cuff, the lifted glove colour on the palm and
-- every finger segment, the crew stripes or the colour-block cuff on the sleeve, quiet parts), the sleeve runs back
-- toward the eye; a kit without the FP pieces still builds the old body-piece arms (the fallback, same checks as
-- before); and the long scarf's two tail pieces sway (ScarfSway.bind finds the welds, a pose bends them, the budget
-- picks the nearest, a low tier puts the modelled pose back).
local okCh, chErr = pcall(function(): string
	local Viewmodel = require(clientHeist:WaitForChild("Viewmodel"))
	local ScarfSway = require(clientHeist:WaitForChild("ScarfSway"))
	local Outfit = require(shared:WaitForChild("Heist"):WaitForChild("Outfit"))
	local Config = require(shared:WaitForChild("Config")) :: any
	local kit = ReplicatedStorage:WaitForChild(Config.Rookie.KIT_FOLDER, 20)
	assert(kit and kit:FindFirstChild("Pieces"), "CharacterKit.Pieces")
	local hue = Color3.fromHex("#FF4FD8")
	local leather = Outfit.default()
	leather.gloves = "Gloves_Leather"
	leather.sweater = "Sweater_Block"
	local looks = {}
	local function runsBack(rig: any, name: string)
		local found = 0
		for _, side in { rig.R, rig.L } do
			for i, part in side.parts do
				if string.find(part.Name, name, 1, true) then
					found += 1
					local off = side.offsets[i].Position
					assert(
						off.Z > 0 and off.Z > math.abs(off.Y),
						string.format("%s runs back toward the eye (grip-space %s)", part.Name, tostring(off))
					)
				end
			end
		end
		assert(found == 2, name .. " on both arms (" .. found .. ")")
	end
	for _, o in { Outfit.default(), leather } do
		local rig = Viewmodel.fromOutfit(kit, Outfit.key(o), hue)
		assert(rig and rig.kit and rig.fp, "the dedicated first-person arms for " .. Outfit.key(o))
		local glove = Viewmodel.gloveColour(o)
		local variant = string.sub(o.gloves, 8)
		local sweater = string.sub(o.sweater, 9)
		local cuffs, otherCuffs, gloves, crew, loud = 0, 0, 0, 0, 0
		for _, d in rig.model:GetDescendants() do
			if d:IsA("BasePart") and d.Name ~= "EH_ViewmodelFill" then
				if string.find(d.Name, "_Cuff" .. variant, 1, true) then
					cuffs += 1
					assert(d.Color == glove, d.Name .. " in the glove colour")
				elseif string.find(d.Name, "_Cuff", 1, true) then
					otherCuffs += 1
				elseif string.find(d.Name, "_" .. sweater, 1, true) then
					crew += 1
					assert(d.Color == hue, d.Name .. " in the crew colour")
				elseif d.Color == glove then
					gloves += 1
				end
				if d.CanCollide or d.CanQuery or d.CastShadow or not d.Anchored then
					loud += 1
				end
			end
		end
		assert(cuffs == 2 and otherCuffs == 0, string.format("the %s cuffs only (%d, %d)", variant, cuffs, otherCuffs))
		assert(gloves == 32, "the palm and 15 finger segments a hand in the glove colour: " .. gloves)
		assert(crew == 2, "the sleeve's crew " .. sweater .. ": " .. crew)
		assert(loud == 0, "quiet parts")
		assert(#rig.R.parts >= 19 and #rig.L.parts >= 20, "both hands bound (the watch on the left)")
		runsBack(rig, "_Sleeve")
		table.insert(looks, string.format("%s %d parts", o.gloves, #rig.R.parts + #rig.L.parts))
		rig.model:Destroy()
	end
	-- the fallback: a kit without the dedicated pieces builds the old body-piece arms (v101's checks)
	local old = kit:Clone()
	for _, p in old.Pieces:GetChildren() do
		if string.sub(p.Name, 1, 10) == "Rookie_FP_" then
			p:Destroy()
		end
	end
	local legacy = Viewmodel.fromOutfit(old, Outfit.key(Outfit.default()), hue)
	assert(legacy and legacy.kit and legacy.fp == nil, "the old body-piece arms without Rookie_FPArms")
	runsBack(legacy, "LowerArm")
	legacy.model:Destroy()
	old:Destroy()
	table.insert(looks, "fallback ok")
	-- the scarf tail on the template (default outfit: the long scarf)
	local tplI = kit:FindFirstChild("Rookie")
	assert(tplI and tplI:IsA("Model"), "the Rookie template")
	local m = tplI:Clone()
	m.Parent = scratch
	local rootI = m:FindFirstChild("HumanoidRootPart")
	assert(rootI and rootI:IsA("BasePart"), "its root")
	local root = rootI :: BasePart
	root.Anchored = true
	local rig = ScarfSway.bind(m)
	assert(rig and #rig.welds == 2, "the long scarf's two tail welds")
	local tip = m:FindFirstChild(Config.Rookie.SCARF.PIECES[2])
	assert(tip, "the tail's end piece")
	local rest = (rig :: any).welds[2].C0
	ScarfSway.pose(rig :: any, 60, 0, 25, 0)
	assert((rig :: any).welds[2].C0 ~= rest, "a pose bends the tail")
	ScarfSway.pose(rig :: any, 0, 0, 0, 0)
	local rr = rig :: any
	assert((rr.welds[2].C0.Position - rest.Position).Magnitude < 1e-4, "angles 0: the modelled pose")
	rr.welds[1].C0 = rr.rest[1]
	rr.welds[2].C0 = rest
	local sway = ScarfSway.new({
		autoStep = false,
		models = function()
			return { m }
		end,
	})
	sway.setTier(1)
	sway.step(1 / 30, root.Position + Vector3.new(0, 2, 8))
	sway.step(1 / 30, root.Position + Vector3.new(0, 2, 8))
	assert(sway.count() == 1, "the nearest character sways")
	local swayed = m:FindFirstChild(Config.Rookie.SCARF.PIECES[2])
	local w2 = swayed and swayed:FindFirstChildOfClass("Weld")
	assert(w2 and w2.C0 ~= rest, "standing: the tail hangs (bent from the modelled pose)")
	sway.setTier(Config.Rookie.SCARF.OFF_TIER)
	assert(w2.C0 == rest, "a low tier puts the modelled pose back")
	sway.setTier(1)
	sway.step(1 / 30, root.Position + Vector3.new(0, 2, 500))
	assert(sway.count() == 0, "beyond RANGE: none")
	sway.destroy()
	assert(tip.Parent == m, "the tail piece stays")
	m:Destroy()
	return table.concat(looks, ", ")
end)
check(okCh, "CH polish: arms in your outfit, the scarf tail sways (" .. tostring(chErr) .. ")")
-- M. First-person hands (fp_hands.md; REVIEW_STEAM_PLUS #10): the dedicated arms on the real CharacterKit have >= 3
-- segments on every finger and 3 on the thumb, every finger pose of Config.FirstPerson.VIEWMODEL.HANDS builds finite
-- frames (Heist/FpRig.place, what each frame of Viewmodel applies): the grip folds the fingers in, the point keeps the
-- index out; and every showcase pose (ViewmodelMath.showcase), assembled and projected as Viewmodel's frame does and
-- written to the real MeshParts (per-axis sizes included), keeps every part's box inside the screen-safe rect at 16:9
-- and 19.5:9 through the fp camera maths, nothing nearer the eye than NEAR. The old Rookie_Hands gloves still hinge.
local okHands, handsErr = pcall(function(): string
	local Viewmodel = require(clientHeist:WaitForChild("Viewmodel"))
	local ViewmodelMath = require(clientHeist:WaitForChild("ViewmodelMath"))
	local FpRig = require(clientHeist:WaitForChild("FpRig"))
	local Outfit = require(shared:WaitForChild("Heist"):WaitForChild("Outfit"))
	local Config = require(shared:WaitForChild("Config")) :: any
	local VM = Config.FirstPerson.VIEWMODEL
	local H = VM.HANDS
	local kit = ReplicatedStorage:WaitForChild(Config.Rookie.KIT_FOLDER, 20)
	assert(kit and kit:FindFirstChild("Pieces"), "CharacterKit.Pieces")
	assert(kit.Pieces:FindFirstChild("Rookie_FP_Right_Index3"), "the Rookie_FPArms pieces are in the kit")
	local rig = Viewmodel.fromOutfit(kit, Outfit.key(Outfit.default()), Color3.fromHex("#3DE8FF"))
	assert(rig and rig.fp, "the dedicated arms built")
	local fp = rig.fp :: any
	for _, hand in { fp.R, fp.L } do
		local per: { [string]: number } = {}
		for _, sg in hand.segs do
			local f = string.match(sg.joint, "^(%a+)%d$") :: string
			per[f] = (per[f] or 0) + 1
		end
		for _, f in { "Index", "Middle", "Ring", "Pinky" } do
			assert((per[f] or 0) >= 3, string.format("%s %s: %d segments", hand.side, f, per[f] or 0))
		end
		assert((per.Thumb or 0) >= 3, hand.side .. " thumb: " .. tostring(per.Thumb) .. " segments")
	end
	-- finger poses (grip space, the hand at the origin)
	local function at(name: string, joint: string): number
		local placed = FpRig.place(
			CFrame,
			Vector3,
			fp.R,
			CFrame.new(),
			Vector3.new(0, -1, 1),
			ViewmodelMath.joints(H, H.POSES[name]),
			0.6
		)
		local d = -1
		for _, pc in placed do
			local p = (pc[2] :: CFrame).Position
			assert(p.X == p.X and p.Magnitude < 2, name .. ": finite frames")
			if pc[1] == "Rookie_FP_Right_" .. joint then
				d = p.Magnitude
			end
		end
		return d
	end
	local out = {}
	for _, name in H.ORDER do
		table.insert(out, string.format("%s %.3f/%.3f", name, at(name, "Index3"), at(name, "Middle3")))
	end
	assert(at("grip", "Middle3") < at("push", "Middle3") * 0.85, "grip folds the fingers in")
	assert(at("point", "Index3") > at("point", "Middle3") * 1.1, "point: the index reaches past the folded fingers")
	assert(at("handsUp", "Middle3") >= at("open", "Middle3") * 0.98, "hands-up: open at least as far as relaxed")
	-- the showcase poses on the real parts through the fp camera
	local cam = CFrame.new(0, 80, 0)
	local fov = Config.Heist.CAMERA.FP.FOV
	local k = ViewmodelMath.viewK(fov, VM.VIEW_FOV)
	local s = VM.SCALE
	local S = VM.SAFE
	rig.model.Parent = scratch
	local tanV = math.tan(math.rad(fov) / 2)
	local worstX, worstTop, nearest = 0, -math.huge, math.huge
	for _, entry in ViewmodelMath.showcase(VM) do
		local f = entry[2]
		local R, L = ViewmodelMath.hands(VM, f)
		local fR, fL = ViewmodelMath.fingers(VM, f)
		local posed: { BasePart } = {}
		for _, side in { { fp.R, R, fR, "R" }, { fp.L, L, fL, "L" } } do
			local el = ViewmodelMath.elbow(VM, side[4], side[2])
			local elbow = Vector3.new(el[1], el[2], el[3]) * s
			for _, pc in FpRig.place(CFrame, Vector3, side[1], Viewmodel.poseFrame(side[2]), elbow, side[3], 0.6) do
				local p = fp.parts[pc[1]]
				local b = (rig.base :: any)[p] :: Vector3
				local c, fac = ViewmodelMath.project({ (pc[2] :: CFrame):GetComponents() }, { b.X, b.Y, b.Z }, k)
				p.Size = Vector3.new(b.X * fac[1], b.Y * fac[2], b.Z * fac[3])
				p.CFrame = cam * CFrame.new(table.unpack(c))
				assert((p.Size - Vector3.new(b.X * fac[1], b.Y * fac[2], b.Z * fac[3])).Magnitude < 1e-3, "size kept")
				table.insert(posed, p)
			end
		end
		for _, p in posed do
			local h = p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local q = cam:PointToObjectSpace(p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
						nearest = math.min(nearest, q.Magnitude)
						assert(q.Magnitude >= VM.NEAR, entry[1] .. " " .. p.Name .. " nearer than NEAR")
						if q.Z < -1e-3 then
							local y = q.Y / (-q.Z * tanV)
							for _, aspect in { 16 / 9, 19.5 / 9 } do
								local x = q.X / (-q.Z * tanV * aspect)
								if y > -1 then
									assert(math.abs(x) <= S.X, string.format("%s %s |x| %.3f", entry[1], p.Name, x))
									assert(y <= S.Y_TOP, string.format("%s %s top %.3f", entry[1], p.Name, y))
									worstX = math.max(worstX, math.abs(x))
									worstTop = math.max(worstTop, y)
								end
							end
						end
					end
				end
			end
		end
	end
	rig.model:Destroy()
	table.insert(out, string.format("safe: |x| %.2f, top %.2f, nearest %.3f", worstX, worstTop, nearest))
	-- the fallback gloves (Rookie_Hands) still hinge on a kit without the dedicated pieces
	local old = kit:Clone()
	for _, p in old.Pieces:GetChildren() do
		if string.sub(p.Name, 1, 10) == "Rookie_FP_" then
			p:Destroy()
		end
	end
	local legacy = Viewmodel.fromOutfit(old, Outfit.key(Outfit.default()), Color3.fromHex("#3DE8FF"))
	assert(legacy and #legacy.R.fingers == 6 and #legacy.L.fingers == 6, "fallback: six hinged segments a hand")
	for _, name in H.ORDER do
		local frames = Viewmodel.fingerFrames(legacy.R, ViewmodelMath.joints(H, H.POSES[name]))
		assert(#frames == 6, "fallback " .. name)
	end
	legacy.model:Destroy()
	old:Destroy()
	-- the placeholder's fingers pose too
	local ph = Viewmodel.buildPlaceholder()
	assert(#ph.R.fingers == 3 and #ph.L.fingers == 3, "placeholder: index, finger group and thumb a hand")
	for _, name in H.ORDER do
		local frames = Viewmodel.fingerFrames(ph.R, ViewmodelMath.joints(H, H.POSES[name]))
		assert(#frames == 3, "placeholder " .. name)
	end
	ph.model:Destroy()
	return table.concat(out, ", ")
end)
check(
	okHands,
	"first-person hands: 3-segment fingers, every pose builds and stays on screen (" .. tostring(handsErr) .. ")"
)
-- K. The northern lights (PLAN_FIRST_PERSON "SKY"): Heist/Aurora builds every layer of Config.Aurora as a chain of
-- additive Beams (valid uploaded image ids: Image assets), unlit, never colliding or queried, high over the anchor;
-- the tier switches change how many draw (Budget.auroraLayers: 4 / 4 / 2 / 1) and tier 4 holds still; the layers
-- follow the camera horizontally. Luau Execution servers render nothing (RenderStepped never fires), so the test
-- steps it by hand and marks the textures loaded (ContentProvider preloads only on a client).
local okSky, skyErr = pcall(function(): string
	local Aurora = require(clientHeist:WaitForChild("Aurora"))
	local Budget = require(shared:WaitForChild("Heist"):WaitForChild("Budget"))
	local Config = require(shared:WaitForChild("Config")) :: any
	local A = Config.Aurora
	local MarketplaceService = game:GetService("MarketplaceService")
	-- every tile is an uploaded Image (a Decal id here would draw nothing)
	for _, id in A.TEXTURES do
		local n = tonumber(string.match(id, "%d+"))
		local okInfo, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(n :: number, Enum.InfoType.Asset)
		end)
		assert(okInfo and info and info.AssetTypeId == 1, id .. " is an Image asset (" .. tostring(info) .. ")")
	end
	local holder = Instance.new("Folder")
	holder.Name = "AuroraTest"
	holder.Parent = workspace
	local aurora = Aurora.new(holder)
	local origin = Vector3.new(6000, 0, 0)
	aurora.setAnchor(origin, 0)
	local beams = aurora.beams()
	local want = 0
	for _, l in A.LAYERS do
		want += l.points - 1
	end
	assert(#beams == want and aurora.layersBuilt() == #A.LAYERS, "every layer built: " .. #beams .. " Beams")
	assert(aurora.layerCount() == 0, "nothing shows before the textures load")
	for _, b in beams do
		assert(b.Enabled == false, "hidden until loaded")
	end
	aurora.markLoaded()
	local function enabled(): number
		local n = 0
		for _, b in beams do
			if b.Enabled then
				n += 1
			end
		end
		return n
	end
	local counts = {}
	for tier = 1, 4 do
		aurora.setTier(tier)
		counts[tier] = enabled()
		assert(counts[tier] == Budget.auroraBeams(tier), "tier " .. tier .. ": " .. counts[tier] .. " Beams")
		assert(aurora.layerCount() == Budget.auroraLayers(tier), "tier " .. tier .. " layers")
	end
	assert(counts[1] > counts[3] and counts[3] > counts[4] and counts[4] > 0, "the tiers change the count")
	aurora.setTier(1)
	local cam = origin + Vector3.new(40, 6, -25)
	aurora.step(0, cam)
	aurora.step(10, cam) -- past the 3 s fade-in
	for _, b in beams do
		local a0, a1 = b.Attachment0, b.Attachment1
		assert(a0 and a1 and a0 ~= a1 and a0:IsDescendantOf(workspace), b:GetFullName() .. " has two attachments")
		assert(table.find(A.TEXTURES, b.Texture) ~= nil, b.Name .. " shows an aurora tile")
		assert(b.LightEmission == 1 and b.LightInfluence == 0 and b.FaceCamera, "additive and unlit")
		assert(b.Segments == A.SEGMENTS and b.CurveSize0 > 0 and b.CurveSize1 > 0, "curved")
		local holderPart = a0.Parent :: BasePart
		assert(not holderPart.CanCollide and not holderPart.CanQuery and not holderPart.CanTouch, "quiet holder")
		assert(holderPart.Transparency == 1 and not holderPart.CastShadow, "an invisible holder")
		local low = math.min(a0.WorldPosition.Y, a1.WorldPosition.Y) - b.Width0 / 2
		assert(low >= origin.Y + A.MIN_CLEARANCE - 1e-3, b:GetFullName() .. " never reachable (" .. low .. ")")
	end
	local first = beams[1]
	local mid = first.Transparency.Keypoints[2].Value
	assert(mid < 1, "revealed after the fade-in")
	-- the layer that follows the camera fully sits over it
	local found = holder:FindFirstChild("Aurora_Glow", true)
	assert(found and found:IsA("BasePart"), "the Glow layer's holder")
	local glowHolder = found :: BasePart
	assert(
		math.abs(glowHolder.Position.X - cam.X) < 1e-3 and math.abs(glowHolder.Position.Z - cam.Z) < 1e-3,
		"the Glow follows the camera horizontally"
	)
	-- animated: the spine sways; tier 4: it holds still
	local a = first.Attachment0 :: Attachment
	local before = a.Position
	aurora.step(14, cam)
	assert((a.Position - before).Magnitude > 0.01, "tier 1 sways")
	aurora.setTier(4)
	aurora.step(20, cam)
	local still = a.Position
	aurora.step(40, cam)
	assert((a.Position - still).Magnitude < 1e-6 and first.TextureSpeed == 0, "tier 4 is static")
	aurora.setReducedMotion(true)
	aurora.setTier(1)
	assert(first.TextureSpeed ~= 0 and math.abs(first.TextureSpeed) < math.abs(A.LAYERS[1].scroll), "reduced: slower")
	aurora.destroy()
	assert(holder:FindFirstChild("EH_Aurora") == nil, "destroy removes it")
	holder:Destroy()
	return string.format("%d / %d / %d / %d Beams per tier", counts[1], counts[2], counts[3], counts[4])
end)
check(okSky, "aurora: layers of Beams, valid textures, tier counts, follow, sway (" .. tostring(skyErr) .. ")")

-- M. The hideout lobby (LOBBY track, Config.Hideout) on the real kit-dressed warehouse garage: each station's look
-- target is in reach and in sight from a spot in front of it (Heist/LookTarget.lineOfSight, real workspace rays
-- against the garage), the station camera's eye (LobbyLook.focusFrame) is not inside a wall, every van's side door
-- point is lookable from the aisle, and the drive's stage (Heist/Drive.build) copies the bay's kit van with its
-- plate, never collides or is queried, and its camera frames the van while the town scrolls past.
local okHide, hideErr = pcall(function(): string
	local Cfg = require(shared:WaitForChild("Config")) :: any
	local HD = Cfg.Hideout
	local Lobby = require(heistServer:WaitForChild("Lobby"))
	local Vans = require(heistServer:WaitForChild("Vans"))
	local LookTarget = require(clientHeist:WaitForChild("LookTarget"))
	local Drive = require(clientHeist:WaitForChild("Drive"))
	local LobbyLook = require(shared:WaitForChild("Heist"):WaitForChild("LobbyLook"))
	local garage = Lobby.model() or Lobby.build(KitService)
	if not Lobby.isDressed() then
		Lobby.dress(KitService)
	end
	Vans.build(nil)
	local anchors = garage:WaitForChild("Anchors")
	local exclude: { Instance } = {}
	local stationsOk, notes = 0, {}
	for _, st in HD.STATIONS do
		local a = anchors:FindFirstChild(st.anchor)
		if a and a:IsA("BasePart") then
			local t = st.target
			local target = (a.CFrame * CFrame.new(t[1], t[2], -t[3])).Position
			-- a kid standing 4.5 studs in front of the station, eyes 5 up
			local flat = Vector3.new(a.CFrame.LookVector.X, 0, a.CFrame.LookVector.Z).Unit
			local stand = Vector3.new(target.X, Cfg.Heist.LOBBY_ORIGIN[2], target.Z) + flat * 4.5
			local eye = stand + Vector3.new(0, 5, 0)
			local dist = (target - eye).Magnitude
			local seen = LookTarget.lineOfSight(eye, target, t[4], a, exclude)
			local camEye = LobbyLook.focusFrame({ target.X, target.Y, target.Z }, flat.X, flat.Z, st.cam)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local camV = Vector3.new(camEye[1], camEye[2], camEye[3])
			local hit = workspace:Raycast(target + (camV - target).Unit * (t[4] + 0.2), camV - target, params)
			local camClear = hit == nil or (hit.Position - target).Magnitude >= (camV - target).Magnitude - 0.5
			if seen and dist <= HD.REACH and camClear then
				stationsOk += 1
			else
				table.insert(
					notes,
					string.format("%s seen %s dist %.1f cam %s", st.anchor, tostring(seen), dist, tostring(camClear))
				)
			end
		else
			table.insert(notes, st.anchor .. " missing")
		end
	end
	assert(stationsOk == #HD.STATIONS, "stations: " .. table.concat(notes, "; "))
	-- every van's side door from the aisle
	local vansOk = 0
	local vans = garage:WaitForChild("Vans")
	for bay = 1, HD.BAYS do
		local m = vans:FindFirstChild("Van" .. bay)
		local door = m and m:FindFirstChild("Door")
		local a = Vans.anchor(bay)
		local body: BasePart? = nil
		for _, d in garage:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("EH_Kind") == "garageVan" and d:GetAttribute("EH_Bay") == bay then
				body = d
			end
		end
		if door and door:IsA("BasePart") and a and body then
			local eye = door.Position + a.LookVector * 5 + Vector3.new(0, 0.8, 0)
			if LookTarget.lineOfSight(eye, door.Position, 2.4, body, exclude) then
				vansOk += 1
			end
		end
	end
	assert(vansOk == HD.BAYS, "van side doors in sight: " .. vansOk)
	-- GOLDEN_FRAMES G3 in first person: from the staged stand in the aisle (GOLDEN.G3.STAND, the eye at 3.8) the
	-- staged look holds the job board's NEXT card and your van (bay 1) in a 16:9 frame and in sight, and the stand
	-- is clear of every solid
	do
		local Scenario = require(shared:WaitForChild("Heist"):WaitForChild("Scenario"))
		local CameraDirector = require(clientHeist:WaitForChild("CameraDirector")) :: any
		local G3 = Cfg.Heist.CAMERA.GOLDEN.G3
		local o = Vector3.new(table.unpack(Cfg.Heist.LOBBY_ORIGIN))
		local eye3 = o + Vector3.new(G3.STAND[1], 3.8, G3.STAND[2])
		local la = o + Vector3.new(G3.LOOK_AT[1], G3.LOOK_AT[2], G3.LOOK_AT[3])
		local yaw3, pitch3 = Scenario.fpLook(G3, { eye3.X, eye3.Y, eye3.Z }, { la.X, la.Y, la.Z })
		local cam3 = CameraDirector.lookFrame(eye3, yaw3, pitch3)
		local card = garage:FindFirstChild("JobCard", true)
		assert(card and card:IsA("BasePart"), "the job board's NEXT card")
		assert(inFrame(cam3, card.Position, G3.FOV), "G3: the NEXT card in frame")
		assert(sightTo(eye3, card.Position, card), "G3: the NEXT card in sight")
		local van1: BasePart? = nil
		for _, d in garage:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("EH_Kind") == "garageVan" and d:GetAttribute("EH_Bay") == 1 then
				van1 = d
			end
		end
		assert(van1, "bay 1's van")
		assert(inFrame(cam3, (van1 :: BasePart).Position, G3.FOV), "G3: your van in frame")
		local clear = 0
		for _, bp in workspace:GetPartBoundsInRadius(eye3 - Vector3.new(0, 1.5, 0), 1.2) do
			if bp.CanCollide and bp:IsDescendantOf(garage) then
				clear += 1
			end
		end
		assert(clear == 0, "G3: the stand is clear (" .. clear .. " solid parts)")
	end
	-- the drive's stage
	local st = Drive.build(2)
	local loud, stageParts = 0, 0
	for _, d in st.model:GetDescendants() do
		if d:IsA("BasePart") then
			stageParts += 1
			if d.CanCollide or d.CanQuery or d.CanTouch then
				loud += 1
			end
		end
	end
	assert(st.copied >= 3, "the van copied: " .. st.copied .. " pieces")
	assert(loud == 0, loud .. " stage part(s) collide or are queried")
	local cf0 = Drive.pose(st, 0, 0)
	local first = st.movers[1].p.Position
	local cf1 = Drive.pose(st, 1, 0)
	local moved = (st.movers[1].p.Position - first).Magnitude
	local toVan = (st.origin.Position + Vector3.new(0, 3, 0) - cf1.Position).Unit
	assert(cf0.Position == cf1.Position, "the camera tracks the van (no shake)")
	assert(cf1.LookVector:Dot(toVan) > 0.95, "the camera looks at the van")
	assert(moved > HD.DRIVE.SPEED * 0.5, string.format("the town scrolls past (%.1f studs in 1 s)", moved))
	st.model:Destroy()
	return string.format("%d stations, %d vans, %d stage parts", stationsOk, vansOk, stageParts)
end)
check(okHide, "hideout: stations in reach and sight, van doors, the drive's stage (" .. tostring(hideErr) .. ")")

-- M. Crew View (REVIEW_STEAM_PLUS gap 5; Shared/Heist/CrewView, Config.Heist.CAMERA.CREW): on the real kit L2 (BIG
-- building, Christmas layer on), you standing on plate A and two clones at work (plate B, the door between) plus the
-- objective: the crew shot frames you, both clones and the objective inside SHARE / SHARE_Y on 16:9 and a 19.5:9
-- phone, from above the ceiling; the cut-away rule (CutMath on the built Overhead) leaves no roof, ceiling or storey
-- between the shot and you or a clone; and Heist/CutAway itself, ticked by hand with a director that reports the crew
-- shot, hides the ceiling over you, then shows it all again once the shot is gone and the camera is at your eyes
-- (first person never cuts).
local okCrew, crewErr = pcall(function(): string
	local CrewViewM = require(shared:WaitForChild("Heist"):WaitForChild("CrewView"))
	local CutAwayM = require(clientHeist:WaitForChild("CutAway"))
	local CR = camCfg.CREW
	local l2Index = Protocol.catalogIndex("cs2_two_doors") :: number
	local l2 = HeistInstance.levelData(l2Index)
	local origin2 = Vector3.new(-12000, 0, 3000)
	local b2 = LevelBuilder.build(l2, origin2, scratch, { kit = KitService, dressing = true })
	assert(b2 and b2.model, "L2 builds with the kit")
	local overL2 = b2.model:FindFirstChild("Overhead")
	assert(overL2, "L2 has its BIG Overhead")
	local ceilY = overL2:GetAttribute("CeilY") :: number
	local function centre(b: any, y: number): Vector3
		return origin2 + Vector3.new((b.minX + b.maxX) / 2, y, (b.minZ + b.maxZ) / 2)
	end
	assert(#l2.plates >= 2, "L2 has two plates")
	local floorY = l2.floorY or 0
	local youRoot = centre(l2.plates[1].box, floorY + 3)
	local clones = { centre(l2.plates[2].box, floorY + 3) }
	if l2.doors and l2.doors[1] then
		table.insert(clones, centre(l2.doors[1].box, floorY + 3))
	end
	local obj = CameraMath.objective(l2)
	assert(obj, "L2 has an objective")
	local objective = origin2 + Vector3.new(obj[1], obj[2], obj[3])
	local you = youRoot + Vector3.new(0, CR.FOCUS_HEIGHT, 0)
	local points = {}
	for _, c in clones do
		table.insert(points, { c.X, c.Y, c.Z })
	end
	table.insert(points, { objective.X, objective.Y, objective.Z })
	local spawn = l2.spawns[1]
	local yaw = math.deg(spawn.yaw)
	local shotCf: CFrame? = nil
	for name, aspect in { ["16:9"] = 16 / 9, ["19.5:9"] = 19.5 / 9 } do
		local focus, d, framed = CrewViewM.frame({ you.X, you.Y, you.Z }, points, yaw, aspect, CR)
		assert(framed == #points, string.format("%s: frames %d of %d points", name, framed, #points))
		local pos, look = CrewViewM.orbit(focus, yaw, CR.PITCH, d)
		for i, p in { { you.X, you.Y, you.Z }, table.unpack(points) } do
			local nx, ny, depth = CrewViewM.project(pos, yaw, CR.PITCH, p, CR.FOV, aspect)
			assert(
				depth > 0 and math.abs(nx) <= CR.SHARE + 1e-6 and math.abs(ny) <= CR.SHARE_Y + 1e-6,
				string.format("%s: point %d at (%.2f, %.2f) depth %.1f", name, i, nx, ny, depth)
			)
		end
		assert(pos[2] > ceilY, name .. ": the shot is above the ceiling")
		local camPos = Vector3.new(pos[1], pos[2], pos[3])
		local lookPos = Vector3.new(look[1], look[2], look[3])
		local targets = { you, youRoot - Vector3.new(0, 2.2, 0) }
		for _, c in clones do
			table.insert(targets, c)
		end
		local ok, by, hid = cutSees(b2.model, camPos, lookPos, youRoot, targets)
		assert(ok, string.format("%s: the cut-away clears the shot (%s; hides %s)", name, by, hid))
		if name == "16:9" then
			shotCf = CFrame.lookAt(camPos, lookPos)
		end
	end
	-- Heist/CutAway on the built level, ticked by hand: the crew shot opens the ceiling; your eyes close it again.
	local eye = CFrame.new(youRoot + Vector3.new(0, 1.6, 0))
	local current: CFrame? = shotCf
	local stub = {
		mode = function(): string
			return "fp"
		end,
		presenting = function(): boolean
			return false
		end,
		eye = function(): CFrame?
			return eye
		end,
		crewShot = function(): CFrame?
			return current
		end,
	}
	local cam = workspace.CurrentCamera
	if not cam then
		local c = Instance.new("Camera")
		c.Parent = workspace
		local ws: any = workspace
		ws.CurrentCamera = c
		cam = c
	end
	(cam :: Camera).CFrame = eye
	local cut = CutAwayM.new(stub)
	cut.bind(b2.model)
	for _ = 1, 20 do
		cut.tick(1 / 30)
	end
	local open = cut.debugState()
	assert(open.groups > 0, "CutAway binds the L2 Overhead")
	assert(open.hidden > 0, "the crew shot opens the building")
	-- the ceiling right over you is one of the hidden groups (a ray straight up from your head meets nothing shown)
	local over: Instance = overL2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { over }
	local saved = {}
	for _, d in over:GetDescendants() do
		if d:IsA("BasePart") then
			saved[d] = d.CanQuery
			d.CanQuery = true
		end
	end
	local from = you
	local blockedBy: string? = nil
	local hitCeiling = false
	for _ = 1, 30 do
		local hit = workspace:Raycast(from, Vector3.new(0, 200, 0), params)
		if not hit then
			break
		end
		hitCeiling = true
		if (hit.Instance :: BasePart).LocalTransparencyModifier < 0.99 then
			blockedBy = hit.Instance:GetFullName()
			break
		end
		from = hit.Position + Vector3.new(0, 0.05, 0)
	end
	for p, q in saved do
		p.CanQuery = q
	end
	assert(hitCeiling, "there is a ceiling over plate A")
	assert(blockedBy == nil, "the ceiling over you is open (" .. tostring(blockedBy) .. ")")
	-- let go: the camera is back at your eyes, first person never cuts
	current = nil
	for _ = 1, 20 do
		cut.tick(1 / 30)
	end
	local closed = cut.debugState()
	assert(closed.hidden == 0, "back at your eyes everything shows (" .. closed.hidden .. " hidden)")
	cut.clear()
	b2.model:Destroy()
	return string.format(
		"%d clones + objective framed, %d of %d groups hidden from the shot, all back at your eyes",
		#clones,
		open.hidden,
		open.groups
	)
end)
check(
	okCrew,
	"Crew View on the kit L2: the shot frames you and the clones, the cut-away opens (" .. tostring(crewErr) .. ")"
)

-- M. Look up / down on other screens (Heist/LookTilt, Config.Rookie.LOOK): on a Motor6D Rookie (the template) and an
-- AnimationConstraint Rookie (the clone-template joints, as after the engine's joint upgrade) a tilt turns the face
-- up through the Neck and the chest through the Waist, the follow walks a replicated LookPitch in clamped, and 0
-- puts the rest pose back.
local okLook, lookErr = pcall(function(): string
	local LookTilt = require(clientHeist:WaitForChild("LookTilt"))
	local LookPitch = require(shared:WaitForChild("Heist"):WaitForChild("LookPitch"))
	local Rookie = require(server:WaitForChild("Heist"):WaitForChild("Rookie"))
	local Config = require(shared:WaitForChild("Config")) :: any
	local L = Config.Rookie.LOOK
	local out = {}
	for _, joints in { "motor", "constraint" } do
		local m = Rookie.build(nil, nil, joints :: any)
		m.Parent = scratch
		local rootI, headI, chestI =
			m:FindFirstChild("HumanoidRootPart"), m:FindFirstChild("Head"), m:FindFirstChild("UpperTorso")
		assert(rootI and headI and chestI, joints .. ": root, head and chest")
		local root, head, chest = rootI :: BasePart, headI :: BasePart, chestI :: BasePart
		root.Anchored = true
		local rig = LookTilt.bind(m)
		assert(rig, joints .. ": Neck and Waist found")
		local hum = m:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		local function settle()
			-- no physics runs in Luau Execution: the Animator's step places the parts on a constraint rig, as a
			-- running client's frame would (clone_engine does the same)
			if animator then
				animator:StepAnimations(0)
			end
			task.wait()
		end
		settle()
		local headY0, chestY0 = head.CFrame.LookVector.Y, chest.CFrame.LookVector.Y
		LookTilt.pose(rig :: any, 30, 0)
		settle()
		local headUp = head.CFrame.LookVector.Y
		assert(
			headUp > headY0 + 0.3,
			string.format("%s: neck +30 turns the face up (%.2f -> %.2f)", joints, headY0, headUp)
		)
		assert(math.abs(chest.CFrame.LookVector.Y - chestY0) < 0.02, joints .. ": the neck alone leaves the chest")
		LookTilt.pose(rig :: any, 0, 15)
		settle()
		assert(chest.CFrame.LookVector.Y > chestY0 + 0.15, joints .. ": waist +15 lifts the chest")
		LookTilt.pose(rig :: any, -30, 0)
		settle()
		assert(head.CFrame.LookVector.Y < headY0 - 0.3, joints .. ": neck -30 looks down")
		LookTilt.pose(rig :: any, 0, 0)
		settle()
		assert(math.abs(head.CFrame.LookVector.Y - headY0) < 0.02, joints .. ": 0, 0 is the rest pose")
		-- the follow: a replicated pitch far past the limits walks in clamped (driven by hand: no other player here)
		local current = 0
		m:SetAttribute(L.ATTRIBUTE, L.MAX_DEG)
		for _ = 1, 90 do
			current = LookPitch.follow(current, m:GetAttribute(L.ATTRIBUTE) :: number, 1 / 30)
		end
		local n, w = LookPitch.split(current)
		assert(n <= L.NECK_MAX and w <= L.WAIST_MAX and n > L.NECK_MAX - 1, "the follow settles at the clamp")
		LookTilt.pose(rig :: any, n, w)
		settle()
		table.insert(out, string.format("%s up %.2f", joints, head.CFrame.LookVector.Y))
		m:Destroy()
	end
	-- the sender: a level look goes out once when not at your eyes; no player here, so nothing is sent
	local sent = 0
	local tilt = LookTilt.new({
		autoStep = false,
		camera = {
			inEyes = function()
				return true
			end,
			fpLook = function()
				return 0, -20
			end,
		},
		send = function()
			sent += 1
		end,
	})
	tilt.step(1 / 30, Vector3.zero)
	assert(tilt.count() == 0, "no other players: nothing tilted")
	tilt.destroy()
	return table.concat(out, ", ") .. string.format(", %d sent without a character", sent)
end)
check(okLook, "look tilt: neck and waist on Motor6D and AnimationConstraint Rookies (" .. tostring(lookErr) .. ")")

-- N. The PARTY sheet (PARTY track, Hud/Party): it builds in the engine and draws a van from its server-written
-- attributes (a fake van model: crew size 3, OPEN, one seated member not READY, one seat held): the CREW row (size 3
-- on, 2 off below the seats taken), the JOIN row (OPEN on), the seat list (KICK on seat 2, seat 4 faded past the
-- size), GO waiting then GO once everyone is READY (it sends { go, bay }); the van card for someone else's van.
local okParty, partyErr = pcall(function()
	local Party = require(clientHeist:WaitForChild("Hud"):WaitForChild("Party"))
	local LobbyLook = require(shared:WaitForChild("Heist"):WaitForChild("LobbyLook"))
	local Palette = require(shared:WaitForChild("Heist"):WaitForChild("Palette"))
	local function need(parent: Instance, name: string): any
		local x = parent:FindFirstChild(name, true)
		assert(x ~= nil, "missing " .. name)
		return x
	end
	local gui = Instance.new("ScreenGui")
	gui.Parent = scratch
	local root = Instance.new("Frame")
	root.Size = UDim2.fromOffset(720, 330)
	root.Parent = gui
	local sent = {}
	local party = Party.build({
		root = root,
		hud = {},
		actions = {
			lobbyAction = function(a: any)
				table.insert(sent, a)
			end,
		},
	})
	-- a fake van under workspace.Garage.Vans (made here when the garage is not there)
	local garage = workspace:FindFirstChild("Garage")
	local madeGarage = garage == nil
	if not garage then
		local g = Instance.new("Model")
		g.Name = "Garage"
		g.Parent = workspace
		garage = g
	end
	local g = garage :: Instance
	local vans = g:FindFirstChild("Vans")
	local madeVans = vans == nil
	if not vans then
		local f = Instance.new("Folder")
		f.Name = "Vans"
		f.Parent = g
		vans = f
	end
	local bay = 99
	local m = Instance.new("Model")
	m.Name = "Van" .. bay
	m:SetAttribute("Bay", bay)
	m:SetAttribute("Mode", "crew")
	m:SetAttribute("CrewId", 1)
	m:SetAttribute("LeaderId", -1)
	m:SetAttribute("Seats", "-1,1,0,0;-2,2,1,0")
	m:SetAttribute("Waiting", 1)
	m:SetAttribute("Size", 3)
	m:SetAttribute("Privacy", "open")
	m:SetAttribute("Held", 1)
	m:SetAttribute("Paint", 0)
	m:SetAttribute("Style", 1)
	m.Parent = vans
	party.open(bay, function() end)
	local sheet = party.sheet :: Frame
	assert(party.isOpen(), "the sheet opens")
	assert(need(sheet, "Size3").BackgroundColor3 == Palette.gold, "size 3 on")
	assert(need(sheet, "Size2").Active == false, "size 2 is under the seats taken")
	assert(need(sheet, "Privacy_open").BackgroundColor3 == Palette.gold, "OPEN on")
	assert(need(need(sheet, "Seat2"), "Kick").Visible, "KICK on the seated member")
	assert(need(sheet, "Seat4").BackgroundTransparency > 0.5, "seat 4 past the size")
	local go = need(sheet, "Go") :: TextButton
	assert(string.find(go.Text, "WAITING", 1, true) ~= nil, "GO waits: " .. go.Text)
	-- the attributes change: everyone READY, GO lights up and sends
	m:SetAttribute("Seats", "-1,1,0,0;-2,2,1,1")
	m:SetAttribute("Waiting", 0)
	task.wait()
	assert(string.find(go.Text, "GO", 1, true) == 1, "GO: " .. go.Text)
	party.go()
	assert(#sent == 1 and sent[1].op == "go" and sent[1].bay == bay, "GO sends { go, bay }")
	party.close()
	assert(not party.isOpen(), "the sheet closes")
	-- the read-only card
	local view = {
		bay = bay,
		mode = "crew",
		crewId = 1,
		leaderId = -1,
		waiting = 0,
		size = 2,
		cap = 3,
		privacy = "friends",
		held = 0,
	}
	local me = { userId = -9, crewId = 9, leader = true, crewSize = 1, seatedBay = nil, ready = false }
	party.setCard(LobbyLook.vanCard(view, me, { friend = true }), function() end)
	local card = need(root, "VanCard") :: Frame
	assert(card.Visible and need(card, "Sit").Visible, "the card with SIT")
	party.setCard(nil, nil)
	m:Destroy()
	if madeVans and vans then
		vans:Destroy()
	end
	if madeGarage then
		g:Destroy()
	end
	return "sheet + card"
end)
check(okParty, "PARTY sheet builds and draws a van from its attributes (" .. tostring(partyErr) .. ")")

-- O. Badges (BADGES track, Heist/BadgeView): the BADGE UNLOCKED card builds and shows a badge from the server's
-- BadgeToast attribute (a stand-in local player: a Folder with attributes), with the fallback icon while the id is 0
-- and the "N OF 8 BADGES" line; THE BOSS IS HERE! goes to the rail when BossUserId turns non-zero (a stand-in
-- store), not for your own id; the gold THE BOSS pill builds over a Rookie-shaped model's head.
local okBadge, badgeErr = pcall(function()
	local BadgeView = require(clientHeist:WaitForChild("BadgeView"))
	local Badges = require(shared:WaitForChild("Heist"):WaitForChild("Badges"))
	local Strings = require(shared:WaitForChild("Heist"):WaitForChild("Strings"))
	local gui = Instance.new("ScreenGui")
	gui.Parent = scratch
	local me = Instance.new("Folder")
	me:SetAttribute("UserId", -7)
	me:SetAttribute(Badges.ATTR_EARNED, 3)
	local store = Instance.new("Folder")
	store:SetAttribute(Badges.ATTR_BOSS_HERE, 0)
	local toasts = {}
	local view = BadgeView.new(gui, function(text: string)
		table.insert(toasts, text)
	end, {
		localPlayer = me,
		store = store,
		players = function()
			return {}
		end,
		reduced = function()
			return true
		end,
	})
	local card = view.card :: Frame
	assert(card and not card.Visible, "the card starts hidden")
	me:SetAttribute(Badges.ATTR_TOAST, Badges.toastValue("eight_of_me", 1))
	task.wait()
	assert(card.Visible, "the card shows on BadgeToast")
	local function need(parent: Instance, childName: string): any
		local x = parent:FindFirstChild(childName, true)
		assert(x ~= nil, "missing " .. childName)
		return x
	end
	local name = need(card, "BadgeName") :: TextLabel
	assert(name.Text == "8 OF ME", "the badge name: " .. name.Text)
	local title = need(card, "Title") :: TextLabel
	assert(title.Text == Strings.BADGE_UNLOCKED, "BADGE UNLOCKED")
	local count = need(card, "Count") :: TextLabel
	assert(count.Text == Strings.badgeCount(3, #Badges.LIST), "count line: " .. count.Text)
	local icon = need(card, "BadgeIcon")
	if Badges.iconOf("eight_of_me") == 0 then
		assert(icon:FindFirstChild("Mark", true) ~= nil, "the fallback mark while the icon id is 0")
	end
	view.show("ghost")
	assert(view.pending() == 1, "a second card queues")
	view.show("nope")
	assert(view.pending() == 1, "unknown keys are ignored")
	-- the boss
	store:SetAttribute(Badges.ATTR_BOSS_HERE, -7)
	task.wait()
	assert(#toasts == 0, "no boss toast for your own id")
	store:SetAttribute(Badges.ATTR_BOSS_HERE, 0)
	store:SetAttribute(Badges.ATTR_BOSS_HERE, 42)
	task.wait()
	assert(#toasts == 1 and toasts[1] == Strings.BOSS_HERE, "THE BOSS IS HERE! on the rail")
	local model = Instance.new("Model")
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = true
	head.Parent = model
	model.Parent = scratch
	local pill = BadgeView.pill(model)
	assert(pill and pill.Adornee == head, "the pill over the head")
	assert(pill ~= nil, "a pill")
	local text = need(pill, "Text") :: TextLabel
	assert(text.Text == Strings.BOSS_PILL, "THE BOSS")
	assert(BadgeView.pill(model) == pill, "one pill per head")
	view.destroy()
	return "card + boss"
end)
check(okBadge, "badge card and boss marks build (" .. tostring(badgeErr) .. ")")

-- P. The intro really plays (INTRO LOAD FIX: the owner saw one frozen frame). (1) Stepped by hand: over stepped
-- time the camera CFrame and the shot index change, every shot is reached, and each frame is within the budget.
-- (2) Cinematic.play drives it by itself through a real per-frame connection (opts.bind: Heartbeat here; on a client
-- BindToRenderStep after the camera): after ~1.5 s of real time the plan has advanced in step with the clock and the
-- camera has moved; SKIP ends it and restores the camera. (3) A frame driver that never fires (the frozen-frame
-- case): play's watchdog ends it as "stalled" within START_WATCHDOG_SECONDS, camera restored, so Heist/Loading shows
-- the title card instead of a frozen screen.
local okPlay, playErr = pcall(function()
	local RunService = game:GetService("RunService")
	local Cinematic = require(clientHeist:WaitForChild("Cinematic"))
	local IntroPlan = require(shared:WaitForChild("Heist"):WaitForChild("IntroPlan"))
	local Config = require(shared:WaitForChild("Config")) :: any
	local B = Config.Boot
	local holder = Instance.new("Folder")
	holder.Name = "IntroPlayTest"
	holder.Parent = scratch
	local function newCam(): Camera
		local cam = Instance.new("Camera")
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = 70
		cam.CFrame = CFrame.new(0, 50, 0)
		cam.Parent = holder
		return cam
	end
	-- (1) by hand
	local cam = newCam()
	local t0 = os.clock()
	local cine = Cinematic.new({ parent = holder, gui = holder, camera = cam, tier = 1 })
	local buildMs = (os.clock() - t0) * 1000
	assert(buildMs <= B.INTRO_BUILD_MS, string.format("build %.0f ms <= %d", buildMs, B.INTRO_BUILD_MS))
	local shotsSeen: { [number]: boolean } = {}
	local lastShot = 0
	local shotChanges = 0
	local moved = 0
	local prev = cam.CFrame
	local worst = 0
	local steps = 0
	while not cine.isDone() and steps < 60 * 60 do
		local s = os.clock()
		cine.step(1 / 60)
		worst = math.max(worst, os.clock() - s)
		steps += 1
		if not cine.isDone() then
			local shot = cine.shot()
			shotsSeen[shot] = true
			if shot ~= lastShot then
				shotChanges += 1
				lastShot = shot
			end
			if steps % 30 == 0 then
				if
					(cam.CFrame.Position - prev.Position).Magnitude > 0.05
					or cam.CFrame.LookVector:Dot(prev.LookVector) < 0.9999
				then
					moved += 1
				end
				prev = cam.CFrame
			end
		end
	end
	assert(cine.isDone(), "plays to its end")
	local reached = 0
	for _ in shotsSeen do
		reached += 1
	end
	assert(reached == #IntroPlan.SHOTS, "every shot reached: " .. reached .. "/" .. #IntroPlan.SHOTS)
	assert(shotChanges >= #IntroPlan.SHOTS, "the shot index advances")
	local samples = math.floor(steps / 30)
	assert(moved >= samples * 0.8, string.format("the camera moves over time (%d of %d half-seconds)", moved, samples))
	assert(worst * 1000 <= B.INTRO_FRAME_MS, string.format("worst frame %.1f ms <= %d", worst * 1000, B.INTRO_FRAME_MS))
	cine.destroy()
	assert(cam.CameraType == Enum.CameraType.Custom, "camera restored once torn down")

	-- (2) play() with a real per-frame connection
	local cam2 = newCam()
	local ended: string? = nil
	local frames = 0
	local played = Cinematic.play({
		parent = holder,
		gui = holder,
		camera = cam2,
		tier = 1,
		bind = function(step: (number) -> ())
			local c = RunService.Heartbeat:Connect(function(dt: number)
				frames += 1
				step(dt)
			end)
			return function()
				c:Disconnect()
			end
		end,
		onEnd = function(how: string)
			ended = how
		end,
	})
	assert(played ~= nil, "play() starts with a frame driver")
	assert(Cinematic.isPlaying(), "isPlaying while it runs")
	local p0 = cam2.CFrame
	local wallStart = os.clock()
	task.wait(1.5)
	local wall = os.clock() - wallStart
	local t = played.t()
	assert(frames >= 10, "driven every frame (" .. frames .. " frames in 1.5 s)")
	assert(t >= wall * 0.6 and t <= wall + 0.2, string.format("plan time %.2f s follows the clock (%.2f s)", t, wall))
	assert(cam2.CameraType == Enum.CameraType.Scriptable, "the intro owns the camera while it plays")
	assert((cam2.CFrame.Position - p0.Position).Magnitude > 1, "the camera moved")
	local pMid = cam2.CFrame
	task.wait(0.5)
	assert(cam2.CFrame ~= pMid, "and keeps moving (not one frozen shot)")
	played.skip()
	local deadline = os.clock() + 3
	while ended == nil and os.clock() < deadline do
		task.wait(0.05)
	end
	assert(ended == "skipped", "SKIP ends it (" .. tostring(ended) .. ")")
	assert(not Cinematic.isPlaying(), "nothing playing after SKIP")
	assert(cam2.CameraType == Enum.CameraType.Custom and cam2.FieldOfView == 70, "camera restored after SKIP")

	-- (3) a frame driver that never fires: degrade fast, never freeze
	local cam3 = newCam()
	local ended3: string? = nil
	local s3 = os.clock()
	local dead = Cinematic.play({
		parent = holder,
		gui = holder,
		camera = cam3,
		tier = 1,
		bind = function(_step: (number) -> ())
			return function() end
		end,
		onEnd = function(how: string)
			ended3 = how
		end,
	})
	assert(dead ~= nil, "play() with a dead driver still starts")
	local limit = Config.Intro.START_WATCHDOG_SECONDS + Config.Intro.HANDOFF_SECONDS + 1.5
	while ended3 == nil and os.clock() - s3 < limit do
		task.wait(0.05)
	end
	local took = os.clock() - s3
	assert(ended3 == "stalled", "a frozen intro ends as stalled (" .. tostring(ended3) .. ")")
	assert(took <= limit, string.format("within %.1f s (%.1f s)", limit, took))
	assert(cam3.CameraType == Enum.CameraType.Custom, "camera restored after a stall")
	assert(not Cinematic.isPlaying(), "nothing left playing")
	holder:Destroy()
	return string.format(
		"build %.0f ms, worst frame %.1f ms, %d frames in %.1f s, stall caught in %.1f s",
		buildMs,
		worst * 1000,
		frames,
		wall,
		took
	)
end)
check(
	okPlay,
	"intro plays: camera + shot index advance, play() per-frame driver, SKIP, stall -> title ("
		.. tostring(playErr)
		.. ")"
)

-- Q. Intro polish (owner on v125: "PICK A VAN gets in the way in the intro"; "the characters are just blocks").
-- (1) No stand-ins with the kit: with EH_IntroKit and CharacterKit as the server publishes them, Cinematic.kitStatus
-- is ready and the whole intro, stepped through every shot (and a SKIP), never falls back to a Part stand-in:
-- Hoardsworth is the kit's MeshParts with the atlas texture, the Rookie and every clone are the CharacterKit
-- template's MeshParts, and every hero prop (tower, vacuum, globe, lever, van, houses, presents, letter) is a kit
-- mesh. (2) The HUD hides during the intro and comes back after: on a stand-in PlayerGui and world, the HUD, PICK A
-- VAN and a world billboard on top are hidden, the intro's own gui and the title card are not, a layer added or turned
-- on again meanwhile is hidden on the next frame, the CoreGui player list / chat / backpack go off; after the end
-- every layer is back as it was (one that was off stays off) and so is the CoreGui.
local okPolish, polishErr = pcall(function()
	local Cinematic = require(clientHeist:WaitForChild("Cinematic"))
	local IntroKit = require(heistServer:WaitForChild("IntroKit"))
	local Config = require(shared:WaitForChild("Config")) :: any
	local I = Config.Intro
	if IntroKit.folder() == nil then
		IntroKit.publishNow(KitService)
	end
	if ReplicatedStorage:FindFirstChild(I.CHARACTER_KIT) == nil then
		require(heistServer:WaitForChild("Rookie")).publishNow(KitService)
	end
	local ready, missing = Cinematic.kitStatus()
	assert(ready, "the intro kit is complete: missing " .. table.concat(missing, ", "))
	assert(Cinematic.waitForKit(1), "waitForKit returns at once with the kit here")
	local introFolder = ReplicatedStorage:FindFirstChild(I.KIT_FOLDER)
	assert(introFolder and introFolder.Parent == ReplicatedStorage, "EH_IntroKit in ReplicatedStorage (not streamed)")

	local holder = Instance.new("Folder")
	holder.Name = "IntroPolishTest"
	holder.Parent = scratch
	local cam = Instance.new("Camera")
	cam.CameraType = Enum.CameraType.Custom
	cam.Parent = holder

	-- a stand-in PlayerGui, world and CoreGui
	local pg = Instance.new("Folder")
	pg.Name = "FakePlayerGui"
	pg.Parent = holder
	local function screen(name: string, enabled: boolean): ScreenGui
		local g = Instance.new("ScreenGui")
		g.Name = name
		g.Enabled = enabled
		g.Parent = pg
		return g
	end
	local hud = screen("HeistHUD", true)
	local fx = screen("HeistFX", true)
	local off = screen("SomethingOff", false)
	local loadingCard = screen("EH_Loading", true)
	local pick = Instance.new("BillboardGui")
	pick.Name = "EH_PickAVan"
	pick.AlwaysOnTop = true
	pick.Parent = pg
	local worldF = Instance.new("Folder")
	worldF.Name = "FakeWorld"
	worldF.Parent = holder
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.Parent = worldF
	local onTop = Instance.new("BillboardGui")
	onTop.AlwaysOnTop = true
	onTop.Parent = anchor
	local plainBoard = Instance.new("BillboardGui")
	plainBoard.AlwaysOnTop = false
	plainBoard.Parent = anchor
	local coreState: { [string]: boolean } = { PlayerList = true, Chat = true, Backpack = true, EmotesMenu = false }
	local fakeCore = {
		get = function(name: string): boolean?
			return coreState[name]
		end,
		set = function(name: string, on: boolean)
			coreState[name] = on
		end,
	}

	local cine = Cinematic.new({
		parent = holder,
		gui = pg,
		camera = cam,
		tier = 1,
		reduced = function()
			return false
		end,
		hud = { root = pg, world = worldF, core = fakeCore },
	})
	local introGui = cine.gui()
	assert(introGui.Parent == pg and introGui.Enabled, "the intro's own gui shows")
	assert(not hud.Enabled and not fx.Enabled, "the HUD is hidden during the intro")
	assert(not pick.Enabled, "PICK A VAN is hidden during the intro")
	assert(not onTop.Enabled, "a world billboard drawn on top is hidden")
	assert(plainBoard.Enabled, "a world billboard not on top is left alone")
	assert(loadingCard.Enabled, "the loading card is not touched")
	assert(
		not coreState.PlayerList and not coreState.Chat and not coreState.Backpack,
		"CoreGui player list, chat and backpack off"
	)
	-- the game adds and re-enables layers meanwhile (the hideout's per-frame hint, a toast)
	local late = screen("LateToast", true)
	local title = screen("EH_Title", true) -- the title card at the intro's end
	hud.Enabled = true
	coreState.Chat = true
	cine.step(1 / 30)
	assert(not late.Enabled, "a layer added during the intro is hidden")
	assert(title.Enabled, "the title card that takes over is not hidden")
	assert(not hud.Enabled, "the HUD turned on again is hidden on the next frame")
	assert(not coreState.Chat, "chat turned on again is hidden on the next frame")
	assert(not off.Enabled, "an already hidden layer stays hidden")

	-- every shot (no stand-in anywhere), then SKIP's end state
	local function meshBody(m: Instance, what: string)
		local meshes, boxes = 0, {}
		for _, d in m:GetDescendants() do
			if d:IsA("MeshPart") then
				meshes += 1
			elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
				table.insert(boxes, d.Name)
			end
		end
		assert(meshes >= 6, what .. " is kit meshes (" .. meshes .. ")")
		assert(#boxes == 0, what .. " has no visible block parts: " .. table.concat(boxes, ", "))
	end
	-- hero props: kit models on the stage (the town and the tower top are built with the stage)
	for _, name in { "Intro_Tower", "Intro_Vacuum", "Intro_SnowGlobe", "Intro_Lever", "Intro_House_A" } do
		local m = cine.stage():FindFirstChild(name, true)
		assert(m and m:FindFirstChildWhichIsA("MeshPart", true), name .. " is the kit mesh")
	end
	local dt = 1 / 20
	local textured, hoardParts, clones = 0, 0, 0
	local garageSeen = false
	while not cine.isDone() do
		cine.step(dt)
		local stage = cine.stage()
		for _, d in stage:GetDescendants() do
			assert(not string.find(d.Name, "StandIn", 1, true), "no stand-in part: " .. d:GetFullName())
		end
		local h = stage:FindFirstChild("Hoardsworth")
		if h and hoardParts == 0 then -- Hoardsworth on the stage: his kit meshes with the palette atlas texture
			for _, d in h:GetDescendants() do
				if d:IsA("BasePart") and string.sub(d.Name, 1, 12) == "Hoardsworth_" then
					hoardParts += 1
					if d:IsA("MeshPart") and d.TextureID ~= "" then
						textured += 1
					end
				end
			end
		end
		local garage = stage:FindFirstChild("Garage")
		if garage and not garageSeen then -- the Rookie, the clones and the van, built with the garage
			garageSeen = true
			local rookieModel = garage:FindFirstChild("Rookie")
			assert(rookieModel and rookieModel:IsA("Model"), "the Rookie in the garage")
			meshBody(rookieModel, "the Rookie")
			local crew = garage:FindFirstChild("Crew")
			for _, c in (if crew then crew:GetChildren() else {}) do
				if c:IsA("Model") and string.sub(c.Name, 1, 5) == "Clone" then
					clones += 1
					meshBody(c, c.Name)
				end
			end
			local van = garage:FindFirstChild("Van")
			assert(van and van:FindFirstChildWhichIsA("MeshPart", true), "the van is the kit mesh")
		end
	end
	cine.skip()
	assert(hoardParts > 0, "Hoardsworth came on stage")
	assert(
		textured >= hoardParts - 3,
		string.format("Hoardsworth is textured kit meshes (%d/%d)", textured, hoardParts)
	)
	assert(garageSeen, "the garage came on stage")
	assert(clones >= 1, "the clones are on the stage (" .. clones .. ")")
	local used = cine.standIns()
	assert(#used == 0, "no stand-ins with the kit: " .. table.concat(used, ", "))
	assert(cine.rookieKind() == "characterKit", "the Rookie is the CharacterKit template (" .. cine.rookieKind() .. ")")

	cine.destroy()
	assert(hud.Enabled and fx.Enabled and late.Enabled, "the HUD is back after the intro")
	assert(pick.Enabled and onTop.Enabled, "PICK A VAN and the world billboard are back")
	assert(not off.Enabled, "a layer that was off before stays off")
	assert(coreState.PlayerList and coreState.Chat and coreState.Backpack, "CoreGui back on")
	assert(coreState.EmotesMenu == false, "a CoreGui piece that was off stays off")
	assert(cam.CameraType == Enum.CameraType.Custom, "camera restored")
	holder:Destroy()
	return string.format(
		"0 stand-ins, %d clones on kit meshes, Hoardsworth %d/%d textured meshes",
		clones,
		textured,
		hoardParts
	)
end)
check(
	okPolish,
	"intro polish: no stand-ins with the kit, HUD hidden during the intro and restored (" .. tostring(polishErr) .. ")"
)

scratch:Destroy()
return string.format("%d checks, %d failed\n%s", #results, failures, table.concat(results, "\n"))
