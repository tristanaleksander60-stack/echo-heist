-- Client views in a real Roblox server (Open Cloud Luau Execution): the client wiring.
-- Run: ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 \
--      --place 70772627070328 --script tests/client_engine.luau   (add --version N to skip publishing)
-- 2026-11-12, place v21: 22 checks, 0 failed. Section F (camera track) and H (presentation shell) not yet run in the engine.
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
		"Loading",
		"Cinematic",
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
else
	check(false, "L5 builds with the kit for the Line-up shot")
end

-- H. Signature moments (PLAN_STEAM_PLUS §4.4 F2, §5 "8 OF ME"): the G2 staging's seven Clone Party
-- tapes (src/server/Heist/StagingTapes.luau) drawn by EchoView + you (a mannequin stand-in on the
-- spawn) = 8 rigs. MomentDirector's 8 OF ME moment runs on hand-stepped frames (Luau Execution
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
	local echo = EchoView.new(vstate)
	echo.setRun(msg, recs, os.clock() - 5)
	-- you: a mannequin on the spawn with a HumanoidRootPart, the 8th rig
	local spawn = party.spawns[1]
	local youRig = Rigs.buildMannequin()
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
	for i = 1, 7 do
		local rig = echo.rigOf(i)
		assert(rig, "clone " .. i .. " has a rig")
		check8(rig.model)
	end
	check8(youRig.model)
	assert(worst <= SHARE + 0.02, string.format("all 8 inside the central 32 %% (widest %.3f)", worst))

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
	return string.format(
		"hops %.3f s apart, widest %.3f of the width, tint %.2f",
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
-- every shot (Hoardsworth on his mesh rig and posed, the presents in the air, the globe filling, the garage with
-- the Rookie and the clones' tape print, the wordmark), then a SKIP lands in the same end state, and the camera,
-- Lighting and Sky are restored both times.
local okIntro, introErr = pcall(function()
	local IntroKit = require(heistServer:WaitForChild("IntroKit"))
	local Cinematic = require(clientHeist:WaitForChild("Cinematic"))
	local IntroPlan = require(shared:WaitForChild("Heist"):WaitForChild("IntroPlan"))
	local Config = require(shared:WaitForChild("Config")) :: any
	local Lighting = game:GetService("Lighting")
	local groups = IntroKit.publishNow(KitService)
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
	local counts = cine.counts()
	assert(counts.windows > 40, "lit windows: " .. counts.windows)
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
	stepTo(8.0) -- shot 2: Hoardsworth, low angle
	assert(cine.hoardKind() == "mesh", "Hoardsworth on his mesh rig (" .. cine.hoardKind() .. ")")
	assert(cam.CameraType == Enum.CameraType.Scriptable, "the intro owns the camera")
	local hw = world(ST.hoardsworth.at)
	assert((cam.CFrame.Position - hw).Magnitude < 20, "the camera is on Hoardsworth")
	local hoard = stage:FindFirstChild("Hoardsworth")
	local headInst = if hoard then hoard:FindFirstChild("Hoardsworth_Head") else nil
	local head = if headInst and headInst:IsA("BasePart") then headInst else nil
	assert(head and math.abs(head.Position.Y - (hw.Y + 6.6)) < 1.5, "his head is at head height (posed rig)")
	stepTo(15.6) -- shot 3: the vacuum and the swirl
	assert(cine.counts().presents == Config.Intro.PRESENTS[1], "presents spawned")
	local inAir = 0
	for _, d in stage:GetChildren() do
		if d.Name == "FlyingPresent" and (d :: BasePart).Transparency == 0 then
			inAir += 1
		end
	end
	assert(inAir > 0, "presents in the air")
	stepTo(28.6) -- shot 5: the garage, headlights on, the Rookie
	assert(cine.counts().presents == 0, "presents swallowed")
	assert(cine.rookieKind() ~= "none", "the Rookie is there (" .. cine.rookieKind() .. ")")
	assert(cine.counts().clones == #ST.clones, "clones built")
	assert((cam.CFrame.Position - world(ST.rookie.at)).Magnitude < 20, "the camera is on the Rookie")
	stepTo(33.0) -- shot 6: the clones printed in
	local garage = stage:FindFirstChild("Garage")
	local clone1 = garage and garage:FindFirstChild("Clone1")
	local clonePart = clone1 and clone1:FindFirstChildWhichIsA("BasePart")
	assert(clonePart == nil or clonePart.LocalTransparencyModifier < 0.5, "clone 1 printed in")
	stepTo(35.0) -- the title smash
	assert(cine.gui():FindFirstChild("Title"), "the wordmark is up")
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
	return string.format("stage built in %.0f ms, %d kit groups, rookie %s", buildMs, groups, "ok")
end)
check(okIntro, "story intro: kit, stage, every shot stepped, SKIP end state, restore (" .. tostring(introErr) .. ")")

scratch:Destroy()
return string.format("%d checks, %d failed\n%s", #results, failures, table.concat(results, "\n"))
