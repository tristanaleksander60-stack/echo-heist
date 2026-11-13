-- Clone visibility in a real Roblox server (Open Cloud Luau Execution; PLAN_STEAM_PLUS §1 S1, §4.4 A1).
-- Also (PLAN_STEAM_PLUS §4.4 A2, A3): floor glow, numbered pill, no light objects, the per-frame
-- state (on-plate, carry with the arms forward and the loot between the hands), the tape print's
-- timing, and the animation-upload spike (an Open Cloud Animation asset moves a joint).
-- Run: ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 \
--      --place 70772627070328 --script tests/clone_engine.luau   (add --version N to skip publishing)
--
-- Rookie templates in four outfits (PLAN_FIRST_PERSON "CH": clones are copies of your Rookie, built from
-- the uploaded art kit) go into the avatars folder exactly as the server puts them there. EchoView then replays a recorded L1 run on them for
-- about 3 s of real Heartbeats, with physics running, and every clone must still be whole,
-- visible, animated, in frame from the default camera and not hidden by the level.
-- Luau Execution has no client and no camera of its own: EchoView runs on the server, the way
-- the engine smoke test runs it, against a camera placed by hand where the default follow
-- camera sits behind a player on the L1 spawn.
-- Section 7 (PLAN_FIRST_PERSON wave C): first person, the default camera. From the L1 spawn at the Rookie's
-- eyes, looking at the objective (the cash), your first clone is in frame and not hidden while it walks to the
-- plate; and on L1 built with the kit, the cash shows through the right partition window from the same eyes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

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
local function note(msg: string)
	table.insert(results, "      " .. msg)
end

local shared = ReplicatedStorage:WaitForChild("Shared")
local server = ServerScriptService:WaitForChild("Server")
local heistServer = server:WaitForChild("Heist")
local clientHeist =
	game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client"):WaitForChild("Heist")

local Config = require(shared:WaitForChild("Config")) :: any
local H = Config.Heist
local Codec = require(shared:WaitForChild("Rec"):WaitForChild("Codec"))
local Sampler = require(shared:WaitForChild("Rec"):WaitForChild("Sampler"))
local HeistService = require(heistServer:WaitForChild("HeistService"))
local HeistInstance = require(heistServer:WaitForChild("HeistInstance"))
local Avatars = require(heistServer:WaitForChild("Avatars"))
local EchoView = require(clientHeist:WaitForChild("EchoView"))
local DebugChip = require(clientHeist:WaitForChild("DebugChip"))
local Rigs = require(clientHeist:WaitForChild("Rigs"))
local RigJoints = require(shared:WaitForChild("Heist"):WaitForChild("RigJoints"))

local OWNER_ID = 10346200733 -- the game owner's account (the local viewer: their clones are "yours")
local SECONDS = 3
local VIEW_START = 0.8 -- recording time at the first frame (run 1 stands still for its 1.1 s intro)
local CAM_FOV = 70
local CAM_ASPECT = 16 / 9
local CAM_ZOOM = 12.5 -- the default follow camera's distance from its subject
local CAM_PITCH = math.rad(20) -- looking down at the subject
local MAX_LIMB_DISTANCE = 5
local FP_EYE = 3.8 -- first person: the Rookie's eyes above the floor (Rookie FaceCenterAttachment 3.72 + EYE_UP)

local okHs, hsErr = pcall(HeistService.start, { lobby = false, players = false })
check(okHs, "HeistService starts" .. (if okHs then "" else ": " .. tostring(hsErr)))

---------------------------------------------------------------------------
-- 1. A recorded L1 run (as the engine smoke test records it): run 1 walks to plate A.
---------------------------------------------------------------------------
local FAKE = -301
local inst = HeistService.createInstance(1, {
	{ userId = FAKE, name = "Fake", fake = { x = 0, y = 3, z = 14, yaw = 0 } },
}, FAKE, false)
assert(inst, "L1 instance")
local simNow = 80000
local fakeIn = inst.byId[FAKE].fake
local function step(dt: number)
	simNow += dt
	HeistInstance.update(inst, simNow)
end
local function walkTo(x: number, z: number)
	for _ = 1, 400 do
		local dx, dz = x - fakeIn.x, z - fakeIn.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 0.05 then
			break
		end
		local s = math.min(d, 14 * 0.05)
		HeistInstance.setFakeInput(inst, FAKE, fakeIn.x + dx / d * s, 3, fakeIn.z + dz / d * s, math.atan2(-dx, -dz))
		step(0.05)
	end
end
step(0.05)
for _ = 1, 22 do
	step(0.05) -- intro transition
end
walkTo(0, 4)
walkTo(10, -8)
for _ = 1, 60 do
	if inst.sim.phase ~= "Run" then
		break
	end
	step(0.05)
end
for _ = 1, 12 do
	step(0.05) -- L1 starts run 2 by itself
end
local msg0 = inst.runMsg
local cloneActor = nil
for _, a in msg0 and msg0.actors or {} do
	if a.kind == "clone" then
		cloneActor = a
	end
end
check(
	inst.sim.runIndex == 2 and cloneActor ~= nil,
	"L1 run 2 carries the run-1 clone (run " .. tostring(inst.sim.runIndex) .. ")"
)
assert(cloneActor, "no clone actor")
local rec = Codec.decode(inst.recBufs[cloneActor.key])
note(string.format("recording: %d samples, %.2f s", rec.n, Sampler.duration(rec)))

---------------------------------------------------------------------------
-- 2. Rookie templates (PLAN_FIRST_PERSON "CH": clones are copies of your Rookie), built from the real art kit and
--    filed exactly as Avatars.prepare files them: four outfits that use every cap and scarf and both sweaters,
--    gloves and masks.
---------------------------------------------------------------------------
local Rookie = require(heistServer:WaitForChild("Rookie"))
local Outfit = require(shared:WaitForChild("Heist"):WaitForChild("Outfit"))
local Palette = require(shared:WaitForChild("Heist"):WaitForChild("Palette"))
local KitService = require(server:WaitForChild("Kit"):WaitForChild("KitService"))
KitService.start()
local kitOk = KitService.ready(60)
note("kit " .. KitService.summary())
check(
	Rookie.publishNow(KitService),
	"CharacterKit published from the kit" .. (if kitOk then "" else " (kit report not ok)")
)

local cases = {
	{ name = "owner", id = OWNER_ID, outfit = Outfit.default() },
	{
		name = "beanie",
		id = -302,
		outfit = {
			cap = "Cap_Beanie",
			scarf = "Scarf_Chunky",
			sweater = "Sweater_Block",
			gloves = "Gloves_Leather",
			mask = "Mask_Eye",
		},
	},
	{
		name = "trapper",
		id = -303,
		outfit = {
			cap = "Cap_Trapper",
			scarf = "Scarf_Bandana",
			sweater = "Sweater_Stripes",
			gloves = "Gloves_Knit",
			mask = "Mask_None",
		},
	},
	{
		name = "bobble",
		id = -304,
		outfit = {
			cap = "Cap_Bobble",
			scarf = "Scarf_Knot",
			sweater = "Sweater_Block",
			gloves = "Gloves_Knit",
			mask = "Mask_Eye",
		},
	},
}

local avatarsFolder = Avatars.folder()
for _, c in cases do
	local ok, rig = pcall(Avatars.buildRookie, c.id, c.outfit, nil)
	if ok and rig then
		c.template = rig
		local motors, constraints = 0, 0
		for _, d in rig:GetDescendants() do
			if d:IsA("Motor6D") then
				motors += 1
			elseif d:IsA("AnimationConstraint") then
				constraints += 1
			end
		end
		note(
			string.format(
				"template %s: %d instances, %d Motor6Ds, %d AnimationConstraints, %d whole joints",
				c.name,
				#rig:GetDescendants(),
				motors,
				constraints,
				RigJoints.whole(rig)
			)
		)
		-- the outfit is applied: every piece of the outfit is in the template, nothing of another variant
		local want = {}
		for _, piece in Outfit.pieces(c.outfit) do
			want[piece] = true
		end
		local missing, extra = 0, 0
		for piece in want do
			if rig:FindFirstChild(piece) == nil then
				missing += 1
			end
		end
		for _, d in rig:GetChildren() do
			if d:GetAttribute("EH_Slot") ~= nil and not want[d.Name] then
				extra += 1
			end
		end
		check(
			rig.Parent == avatarsFolder
				and rig:GetAttribute("EH_Rookie") == true
				and rig:GetAttribute("EH_Blocks") == false
				and rig:GetAttribute("EH_Outfit") == Outfit.key(c.outfit)
				and missing == 0
				and extra == 0,
			string.format("%s: Rookie template in its outfit (%d missing, %d extra pieces)", c.name, missing, extra)
		)
		local hand = rig:FindFirstChild("RightHand")
		check(
			hand ~= nil
				and hand:IsA("BasePart")
				and hand.Color:ToHex() == Color3.fromHex(Outfit.gloveHex(c.outfit)):ToHex(),
			c.name .. ": gloves in the glove colour"
		)
	end
	check(ok and rig ~= nil, "template builds: " .. c.name .. (if ok then "" else " (" .. tostring(rig) .. ")"))
end

---------------------------------------------------------------------------
-- 3. EchoView replays the run on every template for SECONDS of real Heartbeats.
---------------------------------------------------------------------------
local origin = inst.origin
local msg = table.clone(msg0)
msg.actors = {}
local crew = {}
for i, c in cases do
	local a = table.clone(cloneActor)
	a.id = i
	a.owner = c.id
	a.seat = i
	a.slot = 1
	table.insert(msg.actors, a)
	table.insert(crew, { userId = c.id, seat = i })
	c.actorId = i
end
local recs = { [cloneActor.key] = rec }
local vstate = {
	origin = origin,
	folder = inst.folder,
	level = inst.level,
	levelIndex = 1,
	crew = crew,
	actorFx = {},
	run = msg,
	viewerId = OWNER_ID, -- the owner is the local player (their clones are "yours")
}

-- The default follow camera behind a player facing the room (-Z), as Poppercam places it: a
-- wall between the subject and the camera pulls the camera in front of that wall.
local levelParams = RaycastParams.new()
levelParams.FilterType = Enum.RaycastFilterType.Include
levelParams.FilterDescendantsInstances = { inst.built.model }

local function followCamera(playerRoot: Vector3): CFrame
	local focus = origin + playerRoot + Vector3.new(0, 1.5, 0)
	local back = Vector3.new(0, math.sin(CAM_PITCH), math.cos(CAM_PITCH)) * CAM_ZOOM
	local hit = workspace:Raycast(focus, back, levelParams)
	local pos = if hit then hit.Position - back.Unit * 0.5 else focus + back
	return CFrame.lookAt(pos, focus)
end
local SPAWN_CAM = followCamera(Vector3.new(0, 3, 14)) -- on the street by the van (L1 spawn)
-- First person on the L1 spawn (spawn 1, the floor at y 0), looking at the run-start objective (CameraMath.objective:
-- the cash).
local l1Cash = inst.level.loot[1]
local FP_CAM =
	CFrame.lookAt(origin + Vector3.new(0, FP_EYE, 14), origin + Vector3.new(l1Cash.x, l1Cash.y or 3, l1Cash.z))
local INSIDE_CAM = followCamera(Vector3.new(0, 3, 4)) -- a player who walked in through the door

local camera = workspace.CurrentCamera
if not camera then
	local newCam = Instance.new("Camera")
	newCam.Parent = workspace
	local ws: any = workspace
	ws.CurrentCamera = newCam
	camera = newCam
end
local cam = camera :: Camera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = CAM_FOV
cam.CFrame = SPAWN_CAM -- EchoView's near-camera fade reads it

local function inFrustum(camCf: CFrame, p: Vector3): boolean
	local lp = camCf:PointToObjectSpace(p)
	local depth = -lp.Z
	if depth < 0.1 then
		return false
	end
	local halfV = math.tan(math.rad(CAM_FOV / 2))
	return math.abs(lp.Y) <= depth * halfV and math.abs(lp.X) <= depth * halfV * CAM_ASPECT
end

local function notOccluded(camCf: CFrame, p: Vector3): (boolean, string)
	local from = camCf.Position
	local hit = workspace:Raycast(from, p - from, levelParams)
	if not hit then
		return true, "clear"
	end
	return (hit.Position - p).Magnitude < 0.5, hit.Instance.Name .. " at " .. tostring(hit.Position - origin)
end

local function onScreen(camCf: CFrame, p: Vector3): boolean
	return inFrustum(camCf, p) and (notOccluded(camCf, p))
end

local echo = EchoView.new(vstate)
local okRun, runErr = pcall(echo.setRun, msg, recs, os.clock() - 1)
check(okRun, "EchoView.setRun" .. (if okRun then "" else ": " .. tostring(runErr)))

local clonesFolder = workspace:FindFirstChild("HeistClones")
local function rigOf(c: any): Model?
	if echo.rigOf then
		local r = echo.rigOf(c.actorId)
		return r and r.model
	end
	local group = clonesFolder and clonesFolder:FindFirstChild("Owner_" .. tostring(c.id))
	if not group then
		return nil
	end
	for _, m in group:GetChildren() do
		if m:IsA("Model") then
			return m
		end
	end
	return nil
end

-- What every rig looked like on its first frame (parts that later go missing still count).
for _, c in cases do
	local rig = rigOf(c)
	c.rig = rig
	c.parts = {}
	c.walkFrames, c.walkPlaying = 0, 0
	c.seenFrames, c.allFrames = 0, 0
	if rig then
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(c.parts, d)
			end
		end
	end
end

-- Luau Execution runs the place without simulation (RunService:IsRunning() is false: no PreSimulation,
-- no physics, Animators never step on their own; measured on Saved v32). Each test frame steps every
-- clone's Animator by hand (Animator:StepAnimations poses the parts), as a running client's frame would.
local SIMULATED = RunService:IsRunning()
note("RunService:IsRunning() = " .. tostring(SIMULATED) .. (if SIMULATED then "" else ": Animators stepped by hand"))
local function animatorOf(rig: Model?): Animator?
	local hum = rig and rig:FindFirstChildOfClass("Humanoid")
	return hum and hum:FindFirstChildOfClass("Animator")
end
local function stepAnimators(dt: number)
	if SIMULATED then
		return
	end
	for _, c in cases do
		local animator = animatorOf(c.rig)
		if animator then
			pcall(animator.StepAnimations, animator, dt)
		end
	end
end
-- The right foot in root space: its spread over the moving frames shows the walk really plays.
local function footLocal(rig: Model?): Vector3?
	local root = rig and rig:FindFirstChild("HumanoidRootPart")
	local foot = rig and (rig:FindFirstChild("RightFoot") or rig:FindFirstChild("RightLowerLeg"))
	if root and foot and root:IsA("BasePart") and foot:IsA("BasePart") then
		return root.CFrame:PointToObjectSpace(foot.Position)
	end
	return nil
end

local t0 = os.clock()
local frames = 0
local firstFrameNote = {}
local done = false
local conn = RunService.Heartbeat:Connect(function(dt: number)
	if done then
		return
	end
	local el = os.clock() - t0
	local tView = VIEW_START + el
	local ok, err = pcall(echo.update, tView, os.clock(), dt, nil)
	if not ok then
		table.insert(firstFrameNote, "update error: " .. tostring(err))
		done = true
		return
	end
	stepAnimators(dt)
	frames += 1
	local vx, _, vz = Sampler.velocity(rec, tView)
	local moving = math.sqrt(vx * vx + vz * vz) > 2
	for i, c in cases do
		local rig = c.rig
		local head = rig and rig:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			c.allFrames += 1
			if onScreen(SPAWN_CAM, head.Position) then
				c.seenFrames += 1
			end
			-- first person: the first clone, as it walks out of your body toward the plate
			if i == 1 then
				local torso = rig and rig:FindFirstChild("UpperTorso")
				local seen = onScreen(FP_CAM, head.Position)
					or (torso ~= nil and torso:IsA("BasePart") and onScreen(FP_CAM, torso.Position))
				c.fpFrames = (c.fpFrames or 0) + 1
				if seen then
					c.fpSeen = (c.fpSeen or 0) + 1
					c.fpFirst = c.fpFirst or tView
					c.fpLast = tView
				end
			end
		end
		if moving and frames > 5 and rig then
			c.walkFrames += 1
			local fl = footLocal(rig)
			if fl then
				c.footMin = math.min(c.footMin or math.huge, fl.Z)
				c.footMax = math.max(c.footMax or -math.huge, fl.Z)
			end
			local hum = rig:FindFirstChildOfClass("Humanoid")
			local animator = hum and hum:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in animator:GetPlayingAnimationTracks() do
					if track.IsPlaying then
						c.walkPlaying += 1
						break
					end
				end
			end
		end
	end
	if el >= SECONDS then
		done = true
	end
end)
local waited = 0
while not done and waited < SECONDS + 5 do
	waited += task.wait()
end
conn:Disconnect()
for _, line in firstFrameNote do
	note(line)
end
note(string.format("%d Heartbeats over %.2f s", frames, os.clock() - t0))

---------------------------------------------------------------------------
-- 4. Per clone: whole, visible, animated, on screen.
---------------------------------------------------------------------------
-- Joints: Motor6Ds, or the kinematic AnimationConstraints the 2026 engine builds avatars with.
local function motorsOf(rig: Model): (number, number)
	local all = 0
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			all += 1
		end
	end
	return all, RigJoints.whole(rig)
end

for _, c in cases do
	local rig = c.rig
	local tag = c.name
	if not rig then
		check(false, tag .. ": a rig is drawn")
		continue
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	check(rig.Name ~= "Mannequin" and hum ~= nil, tag .. ": rig.kind == avatar (" .. rig.Name .. ")")
	local rootInst = rig:FindFirstChild("HumanoidRootPart")
	local root: BasePart? = if rootInst and rootInst:IsA("BasePart") then rootInst else nil
	local all, whole = motorsOf(rig)
	check(
		whole >= 15,
		string.format("%s: >= 15 whole joints, Motor6D or AnimationConstraint (%d of %d)", tag, whole, all)
	)
	local lost, far, worst, worstName = 0, 0, 0, "-"
	local seeThrough, seeName, facesShown = 0, "-", 0
	for _, p in c.parts do
		if not p:IsDescendantOf(rig) then
			lost += 1
			continue
		end
		if root and p ~= root then
			local d = (p.Position - root.Position).Magnitude
			if d > worst then
				worst, worstName = d, p.Name
			end
			if d > MAX_LIMB_DISTANCE then
				far += 1
			end
			if p:GetAttribute("EH_Face") ~= nil then
				if p.Transparency < 0.5 then
					facesShown += 1 -- one face shows; the other three are hidden by design
				end
			elseif p.Transparency + p.LocalTransparencyModifier >= 0.5 then
				seeThrough += 1
				seeName = p.Name
			end
		end
	end
	check(
		root ~= nil and lost == 0 and far == 0,
		string.format(
			"%s: all %d parts still in the rig and within %d studs of the root (%d lost, %d far, worst %s %.1f studs)",
			tag,
			#c.parts,
			MAX_LIMB_DISTANCE,
			lost,
			far,
			worstName,
			worst
		)
	)
	local headInst = rig:FindFirstChild("Head")
	local head: BasePart? = if headInst and headInst:IsA("BasePart") then headInst else nil
	local badgeInst = if head then head:FindFirstChild("Badge") else nil
	local badge: BillboardGui? = if badgeInst and badgeInst:IsA("BillboardGui") then badgeInst else nil
	check(
		head ~= nil and head:IsDescendantOf(workspace) and badge ~= nil and badge.Enabled,
		tag .. ": Head and badge alive"
	)
	check(
		seeThrough == 0,
		string.format("%s: visible parts opaque (%d see-through, e.g. %s)", tag, seeThrough, seeName)
	)
	check(facesShown == 1, string.format("%s: one Rookie face shows (%d)", tag, facesShown))
	-- crew colour: only the crew pieces (scarf, stripes) take the owner hue; the cap keeps its own colours
	local crewCol: Color3? = nil
	local crewOk, crewN = true, 0
	local capTinted = false
	for _, d in rig:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("EH_Tint") == "crew" then
			crewN += 1
			crewCol = crewCol or d.Color
			crewOk = crewOk and d.Color == crewCol
		elseif d:IsA("BasePart") and string.find(d.Name, "Rookie_Cap_", 1, true) then
			local tc = c.template and c.template:FindFirstChild(d.Name)
			capTinted = tc ~= nil and tc:IsA("BasePart") and tc.Color ~= d.Color
		end
	end
	local hueOk = false
	if crewCol then
		local seatHue = Palette.hueFor(c.actorId)
		local h1, s1 = crewCol:ToHSV()
		local h2, s2 = seatHue:ToHSV()
		hueOk = (s2 < 0.1 and s1 < 0.15) or math.abs(h1 - h2) < 0.03 or math.abs(h1 - h2) > 0.97
	end
	check(
		crewN >= 2 and crewOk and hueOk and not capTinted,
		string.format(
			"%s: crew pieces (%d) in the owner hue %s, cap untinted",
			tag,
			crewN,
			if crewCol then crewCol:ToHex() else "-"
		)
	)
	local hl = rig.Parent and rig.Parent:FindFirstChildOfClass("Highlight")
	check(hl ~= nil and hl.Enabled, tag .. ": owner Highlight on")
	check(
		c.walkFrames > 0 and c.walkPlaying >= c.walkFrames * 0.8,
		string.format("%s: walk track plays while moving (%d of %d moving frames)", tag, c.walkPlaying, c.walkFrames)
	)
	local stride = (c.footMax or 0) - (c.footMin or 0)
	check(
		stride > 0.5,
		string.format("%s: the walk moves the feet (right foot swings %.2f studs fore-aft)", tag, stride)
	)
	check(
		-- 25 %: with the walk clip really playing (Animators stepped), the bobbing head clips the door
		-- frame in a few more frames than the static rest pose did (52-54 of 182 measured on v33).
		c.seenFrames >= c.allFrames * 0.25,
		string.format(
			"%s: on screen from the street spawn camera while it walks out (%d of %d frames)",
			tag,
			c.seenFrames,
			c.allFrames
		)
	)
	if head then
		check(
			inFrustum(INSIDE_CAM, head.Position),
			tag .. ": on plate A, Head in frame from inside the door " .. tostring(head.Position - origin)
		)
		local clear, by = notOccluded(INSIDE_CAM, head.Position)
		check(clear, tag .. ": on plate A, Head not hidden by the level (" .. by .. ")")
		local streetClear, streetBy = notOccluded(SPAWN_CAM, head.Position)
		note(
			tag .. ": on plate A from the street spawn: " .. (if streetClear then "visible" else "behind " .. streetBy)
		)
	end
	if hum then
		note(
			string.format(
				"%s: AutomaticScalingEnabled=%s, root y %.1f, head y %s",
				tag,
				tostring(hum.AutomaticScalingEnabled),
				if root then root.Position.Y - origin.Y else -1,
				if head then string.format("%.1f", head.Position.Y - origin.Y) else "gone"
			)
		)
	end
end

---------------------------------------------------------------------------
-- 5. "That's me" look and acting (PLAN_STEAM_PLUS §4.4 A2, A3).
---------------------------------------------------------------------------
local C = Config.Clone

-- Runs echo.update on real Heartbeats for `seconds` (tView frozen unless `tFrom` moves it).
local function runFor(seconds: number, each: ((el: number) -> ())?, tFrom: number?)
	local start = os.clock()
	local finished = false
	local c = RunService.Heartbeat:Connect(function(dt: number)
		if finished then
			return
		end
		local el = os.clock() - start
		if each then
			each(el)
		end
		pcall(echo.update, (tFrom or (VIEW_START + SECONDS)) + (if tFrom then el else 0), os.clock(), dt, nil)
		stepAnimators(dt)
		if el >= seconds then
			finished = true
		end
	end)
	local waitedFor = 0
	while not finished and waitedFor < seconds + 5 do
		waitedFor += task.wait()
	end
	c:Disconnect()
end

-- A2: floor glow and numbered pill on every clone.
for _, c in cases do
	local fxs = echo.fxOf and echo.fxOf(c.actorId)
	local root = c.rig and c.rig:FindFirstChild("HumanoidRootPart")
	local glowOk = fxs ~= nil and fxs.glow.Enabled and fxs.glow.LightInfluence == 0
	if glowOk and root and root:IsA("BasePart") then
		local d = fxs.glowPart.Position - root.Position
		glowOk = Vector2.new(d.X, d.Z).Magnitude < 1 and d.Y < -1
	end
	check(glowOk, c.name .. ": floor glow on, unlit, under the clone")
	local pill = fxs and fxs.pill
	local pillFrame = pill and pill:FindFirstChild("Pill")
	local number = pillFrame and pillFrame:FindFirstChild("Number")
	check(
		pill ~= nil
			and pill.Enabled
			and number ~= nil
			and number:IsA("TextLabel")
			and number.Text == tostring(cloneActor.slot)
			and pillFrame:FindFirstChildOfClass("UICorner") ~= nil,
		c.name .. ": numbered pill badge (" .. tostring(number and (number :: any).Text) .. ")"
	)
	-- you walk through your clones: every body part is in the no-collision group and not CanCollide
	local solid = 0
	for _, d in (c.rig and c.rig:GetDescendants() or {}) do
		if d:IsA("BasePart") and (d.CanCollide or d.CollisionGroup ~= Config.Heist.CLONE_COLLISION_GROUP) then
			solid += 1
		end
	end
	check(c.rig ~= nil and solid == 0, c.name .. ": walk-through (" .. solid .. " solid parts)")
end
local lights = 0
for _, d in (workspace:FindFirstChild("HeistClones") or workspace):GetDescendants() do
	if d:IsA("Light") then
		lights += 1
	end
end
check(lights == 0, "no light objects on clones (" .. lights .. ")")

-- A3: state from the recording. Run 1 ends on plate A: every clone stands "on-plate".
for _, c in cases do
	local st = echo.stateOf and echo.stateOf(c.actorId)
	check(st == "on-plate", c.name .. ": state on-plate at the end of the run (" .. tostring(st) .. ")")
end

-- A3: a carrying clone reports "carry", holds the loot in front and raises its arms (Lua pose on the
-- joints, PreSimulation). K1 is the L1 cash; the server attributes are set by hand here.
local own0 = cases[1]
local function handZ(c: any): number?
	local rig = c.rig
	local root = rig and rig:FindFirstChild("HumanoidRootPart")
	local hand = rig and (rig:FindFirstChild("RightHand") or rig:FindFirstChild("RightLowerArm"))
	if root and hand and root:IsA("BasePart") and hand:IsA("BasePart") then
		return root.CFrame:PointToObjectSpace(hand.Position).Z
	end
	return nil
end
if own0 and own0.rig then
	runFor(0.3)
	local restZ = handZ(own0)
	local folderInst = inst.folder
	local function setCarry()
		folderInst:SetAttribute("K1State", "Carried")
		folderInst:SetAttribute("K1Carrier", own0.actorId)
	end
	runFor(0.6, setCarry)
	setCarry()
	pcall(echo.update, VIEW_START + SECONDS, os.clock(), 1 / 60, nil)
	local st = echo.stateOf(own0.actorId)
	check(st == "carry", "carrying clone reports carry (" .. tostring(st) .. ")")
	local carryZ = handZ(own0)
	check(
		restZ ~= nil and carryZ ~= nil and carryZ < restZ - 0.5,
		string.format(
			"carry pose: right hand forward (z %s -> %s studs in root space)",
			tostring(restZ and math.floor(restZ * 100) / 100),
			tostring(carryZ and math.floor(carryZ * 100) / 100)
		)
	)
	local rootInst = own0.rig:FindFirstChild("HumanoidRootPart")
	local at = echo.carryPointOf(own0.actorId)
	if at and rootInst and rootInst:IsA("BasePart") then
		local root = rootInst
		local lp = root.CFrame:PointToObjectSpace(at + Vector3.new(0, C.CARRY_LIFT, 0))
		check(
			lp.Z < -0.6 and math.abs(lp.Y) < 1.2,
			string.format("carried loot sits between the hands, in front (%.2f, %.2f, %.2f)", lp.X, lp.Y, lp.Z)
		)
	else
		check(false, "carryPointOf gives a point")
	end
	folderInst:SetAttribute("K1State", "Home")
	folderInst:SetAttribute("K1Carrier", 0)
	runFor(0.4)
	check(echo.stateOf(own0.actorId) == "on-plate", "back on the plate once the loot is gone")

	-- The plate glance: an IKControl (LookAt, Head from UpperTorso) aimed along the clamped direction.
	-- Only its set-up is checked here: whether an IKControl solves under a hand-stepped Animator in this
	-- non-simulated server is undocumented and measured inconsistent (0-48 degrees for the same set-up,
	-- by idle clip), so the turn itself is a Studio / phone check.
	local rigT = echo.rigOf(own0.actorId)
	local head = own0.rig:FindFirstChild("Head")
	if rigT and head and head:IsA("BasePart") then
		local target = head.Position + Vector3.new(-4, 0.5, -3)
		Rigs.lookAt(rigT, target, 0.8)
		local ik = rigT.ik
		local ok = ik ~= nil
			and ik.Type == Enum.IKControlType.LookAt
			and ik.EndEffector == head
			and ik:GetChainCount() >= 1
			and math.abs(ik.Weight - 0.8) < 1e-3
			and rigT.lookTarget ~= nil
			and (rigT.lookTarget.WorldPosition - target).Magnitude < 1e-3
		check(
			ok,
			"glance IK set up: LookAt on the Head, chain "
				.. tostring(ik and ik:GetChainCount())
				.. ", weight and target"
		)
		Rigs.lookAt(rigT, nil, 0)
		check(ik ~= nil and ik.Weight == 0, "glance IK fades its weight to 0 (never toggles Enabled)")
	else
		check(false, "glance IK: rig and head found")
	end
end

-- A2: the tape print: each clone builds up from the feet within PRINT_SECONDS of its turn, 60 ms
-- apart in record order (a new run that starts now).
local printStart = os.clock()
local okPrint, printErr = pcall(echo.setRun, msg, recs, printStart)
check(okPrint, "setRun for the print" .. (if okPrint then "" else ": " .. tostring(printErr)))
local midSeen = false
local other1 = cases[2]
runFor(1.6, function()
	local rig = other1 and other1.rig
	if midSeen or not rig then
		return
	end
	local from = echo.printTimes(other1.actorId)
	local now = os.clock()
	if from and now - from > C.PRINT_SECONDS * 0.3 and now - from < C.PRINT_SECONDS * 0.7 then
		local shown, hidden = 0, 0
		for _, p in rig:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				if p.LocalTransparencyModifier >= 1 then
					hidden += 1
				else
					shown += 1
				end
			end
		end
		if shown > 0 and hidden > 0 then
			midSeen = true
		end
	end
end, VIEW_START)
check(midSeen, "mid-print: the feet are in, the head is not yet")
local k = 0
for _, c in cases do
	local from, doneAt = echo.printTimes(c.actorId)
	local tutorialOwn = c.id == OWNER_ID -- the newest own clone on a tutorial level forms a beat later
	if not tutorialOwn then
		check(
			from ~= nil and math.abs(from - (printStart + k * H.CLONE_SPAWN_STAGGER)) < 1e-6,
			string.format("%s: print starts %d ms after the first", c.name, k * 60)
		)
	end
	k += 1
	check(
		from ~= nil and doneAt ~= nil and doneAt - from <= C.PRINT_SECONDS + 0.05,
		string.format(
			"%s: print finished in %s s (<= %.2f + a frame)",
			c.name,
			if from and doneAt then string.format("%.3f", doneAt - from) else "?",
			C.PRINT_SECONDS
		)
	)
end

---------------------------------------------------------------------------
-- 6. Animation-upload spike (PLAN_STEAM_PLUS §4.4 A3): a Lune-written 2-key KeyframeSequence uploaded
-- through Open Cloud as an Animation asset (tools/anim_spike.luau, tools/anim_upload.py,
-- assets/anim_ids.json) plays on a server-side R15 rig's Animator and moves the shoulder joint. The rig is the
-- player character itself: the Rookie as the StarterCharacter is built (Motor6D joints).
---------------------------------------------------------------------------
local SPIKE_ANIM = 83859875506228
do
	local okRig, spikeRig = pcall(Rookie.build, Outfit.default(), nil, "motor")
	check(okRig and spikeRig ~= nil, "spike: the Rookie (R15, Motor6Ds) builds")
	if okRig and spikeRig then
		local rig = spikeRig :: Model
		local root = rig:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = true
		end
		rig:PivotTo(CFrame.new(origin + Vector3.new(0, 40, 0)))
		rig.Parent = workspace
		local hum = rig:FindFirstChildOfClass("Humanoid")
		local animator: Animator? = hum and hum:FindFirstChildOfClass("Animator")
		if hum and not animator then
			local made = Instance.new("Animator")
			made.Parent = hum
			animator = made
		end
		local joint: any = nil
		for _, d in rig:GetDescendants() do
			local part1: Instance? = nil
			if d:IsA("Motor6D") then
				part1 = d.Part1
			elseif d:IsA("AnimationConstraint") then
				part1 = d.Attachment1 and d.Attachment1.Parent
			end
			if part1 and part1.Name == "RightUpperArm" then
				joint = d
			end
		end
		check(joint ~= nil, "spike: right shoulder joint found (" .. (if joint then joint.ClassName else "none") .. ")")
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. SPIKE_ANIM
		local okLoad, track = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		check(
			okLoad and track ~= nil,
			"spike: Animation " .. SPIKE_ANIM .. " loads" .. (if okLoad then "" else ": " .. tostring(track))
		)
		local hand = rig:FindFirstChild("RightHand")
		if okLoad and track and joint and root and root:IsA("BasePart") and hand and hand:IsA("BasePart") then
			-- Observe the pose, not the property: the right hand's place in the root's frame.
			local rest = root.CFrame:PointToObjectSpace(hand.Position)
			for _ = 1, 100 do
				if track.Length > 0 then
					break
				end
				task.wait(0.05)
			end
			track:Play(0)
			local maxMove, maxAngle = 0, 0
			for _ = 1, 30 do
				if SIMULATED then
					task.wait()
				else
					(animator :: Animator):StepAnimations(1 / 30)
				end
				maxMove = math.max(maxMove, (root.CFrame:PointToObjectSpace(hand.Position) - rest).Magnitude)
				local _, angle = joint.Transform:ToAxisAngle()
				maxAngle = math.max(maxAngle, math.deg(math.abs(angle)))
			end
			note(
				string.format(
					"spike: track Length %.2f s, IsPlaying %s, %s.Transform max %.0f degrees",
					track.Length,
					tostring(track.IsPlaying),
					joint.ClassName,
					maxAngle
				)
			)
			check(
				track.Length > 0 and maxMove > 0.8,
				string.format("spike: the uploaded clip moves the right hand (%.2f studs in root space)", maxMove)
			)
			track:Stop(0)
		end
		rig:Destroy()
	end
end

---------------------------------------------------------------------------
-- 8. The Rookie's own locomotion (REVIEW_STEAM_PLUS #6): the uploaded RookieClips load on the Rookie and move the
-- joints the data says, the engine's pose matches Shared/Heist/RookieMoves (the baked numbers), and a replaying
-- clone's planted boots slide under 0.3 studs a stride at 1x and 3x (EchoView + CloneGait + the clips).
---------------------------------------------------------------------------
do
	local RookieClips = require(shared:WaitForChild("Heist"):WaitForChild("RookieClips")) :: any
	local RookieMoves = require(shared:WaitForChild("Heist"):WaitForChild("RookieMoves")) :: any
	local okRig, made = pcall(Rookie.build, Outfit.default(), nil, "constraint")
	check(okRig and made ~= nil, "rookie clips: a Rookie (AnimationConstraint joints, as a clone) builds")
	if okRig and made then
		local rig = made :: Model
		local root = rig:WaitForChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		rig:PivotTo(CFrame.new(origin + Vector3.new(30, 40, 0)))
		rig.Parent = workspace
		local hum = rig:WaitForChild("Humanoid") :: Humanoid
		local animator = hum:WaitForChild("Animator") :: Animator
		local function att(part: string, name: string): Attachment?
			local p = rig:FindFirstChild(part)
			local a = p and p:FindFirstChild(name)
			return if a and a:IsA("Attachment") then a else nil
		end
		local ankle = att("RightFoot", "RightAnkleRigAttachment")
		local function rootSpace(p: Vector3): Vector3
			return root.CFrame:PointToObjectSpace(p)
		end
		local function partAt(name: string): Vector3
			local p = rig:WaitForChild(name) :: BasePart
			return rootSpace(p.Position)
		end
		local loaded = 0
		for _, clip in RookieMoves.ORDER do
			local id = RookieClips[clip]
			local anim = Instance.new("Animation")
			anim.AnimationId = id or ""
			local okLoad, track = pcall(function(): AnimationTrack
				return animator:LoadAnimation(anim)
			end)
			if not (id and okLoad and track) then
				check(false, "rookie clips: " .. clip .. " loads (" .. tostring(id) .. ")")
				continue
			end
			for _ = 1, 100 do
				if track.Length > 0 then
					break
				end
				task.wait(0.05)
			end
			loaded += 1
			local spec = RookieMoves.CLIPS[clip]
			track:Play(0, 1, 1)
			-- sweep the clip and measure what moves (part positions in the root's frame)
			local rest: { [string]: Vector3 } = {}
			for _, n in { "RightFoot", "LeftFoot", "RightHand", "Head", "LowerTorso" } do
				rest[n] = partAt(n)
			end
			local footZ0, footZ1, handYMax, torsoYMin, headYaw = math.huge, -math.huge, -math.huge, math.huge, 0
			local handOverHead = -math.huge
			local n = 24
			for i = 0, n do
				track.TimePosition = spec.length * i / n * 0.999
				animator:StepAnimations(0)
				local f = partAt("RightFoot")
				footZ0, footZ1 = math.min(footZ0, f.Z), math.max(footZ1, f.Z)
				handYMax = math.max(handYMax, partAt("RightHand").Y)
				handOverHead = math.max(handOverHead, partAt("RightHand").Y - partAt("Head").Y)
				torsoYMin = math.min(torsoYMin, partAt("LowerTorso").Y)
				local head = rig:WaitForChild("Head") :: BasePart
				local look = root.CFrame:VectorToObjectSpace(head.CFrame.LookVector)
				headYaw = math.max(headYaw, math.deg(math.abs(math.atan2(-look.X, -look.Z))))
			end
			local ok: boolean, what: string
			if clip == "walk" or clip == "run" then
				ok, what =
					footZ1 - footZ0 > 0.9, string.format("the right boot swings %.2f studs fore-aft", footZ1 - footZ0)
			elseif clip == "jump" or clip == "fall" then
				ok, what =
					handOverHead > -0.25,
					string.format("the hands go up by the head (hand %.2f studs from the head's centre)", handOverHead)
			elseif clip == "land" then
				ok, what =
					rest.LowerTorso.Y - torsoYMin > 0.2,
					string.format("the hips squash %.2f studs", rest.LowerTorso.Y - torsoYMin)
			elseif clip == "look" then
				ok, what = headYaw > 30, string.format("the head turns %.0f degrees", headYaw)
			else
				ok, what =
					footZ1 - footZ0 < 0.05 and torsoYMin < rest.LowerTorso.Y + 0.05,
					string.format("stands planted (boot moves %.3f) and breathes", footZ1 - footZ0)
			end
			check(ok, string.format("rookie clips: %s (%s, %.2f s): %s", clip, id, track.Length, what))
			track:Stop(0)
			animator:StepAnimations(0)
		end
		check(loaded == #RookieMoves.ORDER, "rookie clips: all " .. #RookieMoves.ORDER .. " load (" .. loaded .. ")")

		-- The engine plays the data: the right ankle at 8 phases of the walk and the run vs RookieMoves' kinematics.
		if ankle then
			for _, clip in { "walk", "run" } do
				local anim = Instance.new("Animation")
				anim.AnimationId = RookieClips[clip]
				local okLoad, track = pcall(function(): AnimationTrack
					return animator:LoadAnimation(anim)
				end)
				if okLoad and track then
					track:Play(0, 1, 0)
					local worst = 0
					for i = 0, 7 do
						local t = RookieMoves.CLIPS[clip].length * i / 8
						track.TimePosition = t
						animator:StepAnimations(0)
						local fk = RookieMoves.fk(RookieMoves.sample(clip, t))
						local want = RookieMoves.point(fk.RightFoot, RookieMoves.PIVOT.RightFoot)
						local got = rootSpace(ankle.WorldPosition)
						-- RookieMoves' model space has the floor at 0; the root's centre is 3 studs up
						local d = (got - Vector3.new(want[1], want[2] - 3, want[3])).Magnitude
						worst = math.max(worst, d)
					end
					check(
						worst < 0.08,
						string.format("rookie clips: %s ankle matches the baked data (%.3f studs)", clip, worst)
					)
					track:Stop(0)
					animator:StepAnimations(0)
				end
			end
		end
		rig:Destroy()
	end

	-- Your character: the Rookie clips go into the engine's Animate script (its sets of Animations, as the R15 Animate
	-- holds them), the idle set gets the look-around as its rare variant, and a second pass changes nothing.
	do
		local RookieAnimate = require(shared:WaitForChild("Heist"):WaitForChild("RookieAnimate")) :: any
		local animate = Instance.new("Folder")
		animate.Name = "Animate"
		local function set(name: string, anims: { string })
			local sv = Instance.new("StringValue")
			sv.Name = name
			for _, an in anims do
				local a = Instance.new("Animation")
				a.Name = an
				a.AnimationId = "rbxassetid://507766666"
				local w = Instance.new("NumberValue")
				w.Name = "Weight"
				w.Value = 5
				w.Parent = a
				a.Parent = sv
			end
			sv.Parent = animate
		end
		set("idle", { "Animation1", "Animation2" })
		set("walk", { "WalkAnim" })
		set("run", { "RunAnim" })
		set("jump", { "JumpAnim" })
		set("fall", { "FallAnim" })
		set("climb", { "ClimbAnim" })
		local changed = RookieAnimate.apply(animate)
		local idle1 = animate.idle.Animation1 :: Animation
		local idle2 = animate.idle.Animation2 :: Animation
		local W = Config.Rookie.ANIM.IDLE_WEIGHTS
		check(
			changed == 6
				and (animate.walk.WalkAnim :: Animation).AnimationId == RookieClips.walk
				and (animate.run.RunAnim :: Animation).AnimationId == RookieClips.run
				and (animate.jump.JumpAnim :: Animation).AnimationId == RookieClips.jump
				and (animate.fall.FallAnim :: Animation).AnimationId == RookieClips.fall
				and idle1.AnimationId == RookieClips.idle
				and idle2.AnimationId == RookieClips.look
				and (idle1.Weight :: NumberValue).Value == W.idle
				and (idle2.Weight :: NumberValue).Value == W.look
				and (animate.climb.ClimbAnim :: Animation).AnimationId == "rbxassetid://507766666"
				and RookieAnimate.apply(animate) == 0,
			"your Animate: walk, run, jump, fall, idle + the rare look set to the Rookie clips, climb kept, idempotent ("
				.. tostring(changed)
				.. " changed)"
		)
		animate:Destroy()
	end

	-- A replaying clone's boots: each heel / toe that touches the floor stays put until it lifts (1x and 3x).
	local c1 = cases[1]
	local cloneRig = c1 and c1.rig
	if cloneRig and cloneRig:FindFirstChild("RightFoot") then
		-- Per heel / toe: from touching the floor to lifting, its largest horizontal drift. A stride counts while the
		-- recording moves the whole time (speed > 2); the idle <-> run cross-fades are reported, not judged.
		local function slideAt(viewRate: number): (number, number, number, string)
			local dt = 1 / 240
			local tView = VIEW_START
			local worst, contacts, steps, fades = 0, 0, 0, 0
			local worstAt = ""
			local track: { [string]: any } = {}
			local dur = Sampler.duration(rec)
			local function close(id: string)
				local tr = track[id]
				if tr and tr.n >= 3 then
					if tr.moving then
						contacts += 1
						if tr.max > worst then
							worst = tr.max
							worstAt = string.format("%s at t %.2f, %d steps", id, tr.t, tr.n)
						end
					else
						fades = math.max(fades, tr.max)
					end
				end
				track[id] = nil
			end
			while tView < dur - 0.2 do
				tView += dt * viewRate
				pcall(echo.update, tView, os.clock(), dt, nil)
				if not SIMULATED then
					local a = animatorOf(rigOf(c1))
					if a then
						a:StepAnimations(dt) -- wall time: the clips' own speed already carries the view rate
					end
				end
				steps += 1
				local rigNow = rigOf(c1)
				local rootP = rigNow and rigNow:FindFirstChild("HumanoidRootPart")
				if not (rigNow and rootP and rootP:IsA("BasePart")) then
					break
				end
				local vx, _, vz = Sampler.velocity(rec, tView)
				local moving = math.sqrt(vx * vx + vz * vz) > 2
				local floorY = rootP.Position.Y - Config.Rookie.HIP_HEIGHT - Config.Rookie.ROOT_SIZE[2] / 2
				for _, side in { "Right", "Left" } do
					local foot = rigNow:FindFirstChild(side .. "Foot")
					local a = foot and foot:FindFirstChild(side .. "AnkleRigAttachment")
					if a and a:IsA("Attachment") then
						for key, off in { heel = Vector3.new(0, -0.5, 0.4), toe = Vector3.new(0, -0.5, -0.9) } do
							local p = a.WorldCFrame:PointToWorldSpace(off)
							local id = side .. key
							if p.Y - floorY < 0.06 then
								local tr = track[id]
								if not tr then
									track[id] = { at = p, n = 1, max = 0, moving = moving, t = tView }
								else
									tr.n += 1
									tr.moving = tr.moving and moving
									tr.max = math.max(tr.max, Vector3.new(p.X - tr.at.X, 0, p.Z - tr.at.Z).Magnitude)
								end
							else
								close(id)
							end
						end
					end
				end
			end
			note(
				string.format(
					"clone boots at %gx: start/stop cross-fades drift up to %.2f studs (not judged)",
					viewRate,
					fades
				)
			)
			return worst, contacts, steps, worstAt
		end
		for _, r in { 1, 3 } do
			local worst, contacts, steps, worstAt = slideAt(r)
			check(
				contacts >= 4 and worst < 0.3,
				string.format(
					"clone boots at %dx: %d planted contacts in stride over %d steps, worst slide %.3f studs (limit 0.3; %s)",
					r,
					contacts,
					steps,
					worst,
					worstAt
				)
			)
		end
		pcall(echo.update, VIEW_START + SECONDS, os.clock(), 1 / 60, nil)
	else
		check(false, "clone boots: the first clone has a Rookie rig")
	end
end

-- Your own clones are never invisible by design: a fill, kept on at every performance tier.
local own = cases[1]
local ownGroup = own and own.rig and own.rig.Parent
local ownHl = ownGroup and ownGroup:FindFirstChildOfClass("Highlight")
check(
	ownHl ~= nil and ownHl.FillTransparency <= (Config.Heist.CLONE_FILL_TRANSPARENCY or 0.6) + 0.01,
	"own clones: Highlight has a fill (FillTransparency " .. tostring(ownHl and ownHl.FillTransparency) .. ")"
)
pcall(echo.setTier, 4)
check(ownHl ~= nil and ownHl.Enabled, "own clones: Highlight stays on at tier 4")
local other = cases[2]
local otherHl = other and other.rig and other.rig.Parent and other.rig.Parent:FindFirstChildOfClass("Highlight")
check(otherHl ~= nil and not otherHl.Enabled, "other players' clones: Highlight drops at tier 4")
pcall(echo.setTier, 1)

-- Clone LOD (Config.Perf.CLONE_LOD, tier 3+): far clones draw as the crew-hue mannequin with their pill, the
-- textured avatar again inside NEAR; your newest clone in the L1 tutorial ("YOU, 10 SEC AGO") never goes light.
if echo.lodCount and echo.drawnRigOf and own and #cases > 1 then
	local at = echo.positionOf(own.actorId)
	local camWas = cam.CFrame
	if at then
		pcall(echo.setTier, 3)
		cam.CFrame = CFrame.lookAt(at + Vector3.new(0, 12, 38), at)
		for _ = 1, 2 do
			pcall(echo.update, VIEW_START + SECONDS, os.clock(), 1 / 60, nil)
		end
		local light = echo.lodCount()
		local ownDrawn = echo.drawnRigOf(own.actorId)
		local otherDrawn = echo.drawnRigOf(cases[2].actorId)
		local fx = echo.fxOf(cases[2].actorId)
		check(
			light == #cases - 1
				and ownDrawn ~= nil
				and ownDrawn.kind == "avatar"
				and otherDrawn ~= nil
				and otherDrawn.kind == "mannequin"
				and fx ~= nil
				and fx.pill.Enabled,
			string.format(
				"tier 3, camera ~40 studs away: %d of %d clones light, the tutorial's newest own clone textured (%s), others %s with their pill",
				light,
				#cases,
				tostring(ownDrawn and ownDrawn.kind),
				tostring(otherDrawn and otherDrawn.kind)
			)
		)
		cam.CFrame = CFrame.lookAt(at + Vector3.new(0, 4, Config.Perf.CLONE_LOD.NEAR - 4), at)
		for _ = 1, 2 do
			pcall(echo.update, VIEW_START + SECONDS, os.clock(), 1 / 60, nil)
		end
		check(echo.lodCount() == 0, "inside CLONE_LOD.NEAR every clone is its textured avatar again")
		pcall(echo.setTier, 1)
		cam.CFrame = camWas
		for _ = 1, 2 do
			pcall(echo.update, VIEW_START + SECONDS, os.clock(), 1 / 60, nil)
		end
		check(echo.lodCount() == 0, "back at tier 1: no light rigs")
	end
end

-- Studio diagnostic chip text (built only in Studio; its text and stats work anywhere).
if echo.stats then
	-- stats() reports the last periodic CloneHealth count (every CLONE_HEALTH_INTERVAL s) next to
	-- the live drawn count; refresh it first so a clone that printed in since then is counted.
	if echo.checkHealth then
		pcall(echo.checkHealth)
	end
	local okS, drawn, healthy, kind = pcall(echo.stats)
	local chip = if okS then DebugChip.text(drawn, healthy, 1, kind) else tostring(drawn)
	note("chip: " .. chip)
	check(okS and drawn == #cases and healthy == #cases and kind == "avatar", "DebugChip stats: " .. chip)
end

-- The runtime CloneHealth check swaps a broken rig for the mannequin.
if own and own.rig and echo.checkHealth then
	local broke = own.rig:FindFirstChild("Head")
	if broke then
		broke:Destroy()
	end
	local okH, report = pcall(echo.checkHealth)
	local swapped = rigOf(own)
	local okU = pcall(echo.update, VIEW_START + SECONDS, os.clock(), 1 / 60, nil)
	local mHead = swapped and swapped:FindFirstChild("Head")
	check(
		okH
			and okU
			and swapped ~= nil
			and swapped.Name == "Mannequin"
			and mHead ~= nil
			and mHead:IsA("BasePart")
			and inFrustum(INSIDE_CAM, mHead.Position),
		"CloneHealth swaps a headless avatar for the mannequin in place (" .. tostring(report) .. ")"
	)
	local okH2, report2 = pcall(echo.checkHealth)
	check(
		okH2 and report2 == #cases .. "/" .. #cases,
		"after the swap every drawn clone is healthy (" .. tostring(report2) .. ")"
	)
else
	check(false, "CloneHealth: EchoView.checkHealth exists")
end

---------------------------------------------------------------------------
-- 7. First person (PLAN_FIRST_PERSON wave C): the default camera at the L1 spawn's eyes.
---------------------------------------------------------------------------
do
	local first = cases[1]
	local walkEnd = Sampler.duration(rec)
	check(
		(first.fpSeen or 0) > 0 and (first.fpFirst or math.huge) <= walkEnd,
		string.format(
			"first person at the L1 spawn (eyes %.1f), looking at the cash: the first clone is in frame and not hidden "
				.. "while it walks to the plate (%d of %d frames, from %.2f s to %.2f s; the walk ends at %.2f s)",
			FP_EYE,
			first.fpSeen or 0,
			first.fpFrames or 0,
			first.fpFirst or -1,
			first.fpLast or -1,
			walkEnd
		)
	)
end

-- The cash through the glass: L1 built with the kit (LevelDress: the partition windows, the cash on its safe),
-- rays from the same eyes (every spawn seat) to points on the cash. Kit pieces are visual only (CanQuery off) and a
-- shell piece's collision is one box over its openings (the storefront's door, a window), so the scratch copy makes
-- every part queryable and: the walls are the sim's boxes (the invisible colliders under the kit), crossed only
-- through a window's glass pane; the shell pieces with openings are left to those boxes; the glass never blocks;
-- any other visible part (the safe, a counter, a prop) does.
do
	local LevelBuilder = require(heistServer:WaitForChild("LevelBuilder"))
	local scratch = Instance.new("Folder")
	scratch.Name = "FpCashScratch"
	scratch.Parent = workspace
	local at = Vector3.new(-9000, 0, 600)
	-- The kit's level pieces are checked by kit_engine. Here a size error on a group L1 never uses (another track
	-- re-uploading the intro or the Rookie's art) must not keep this one view greybox, so the dresser gets the
	-- kit with its boot report taken as complete; the real report is noted.
	local report = KitService.report and KitService.report()
	if report and not report.ok then
		note("kit boot report not ok (" .. KitService.summary() .. "): dressing this copy of L1 anyway")
	end
	local kitView = setmetatable({
		report = function(): any
			local r = table.clone(KitService.report())
			r.ok = true
			return r
		end,
	}, { __index = KitService })
	local okB, built = pcall(LevelBuilder.build, inst.level, at, scratch, { kit = kitView, dressing = true })
	local cash: { [Instance]: boolean } = {}
	local cashParts, panes, windows = {}, {}, 0
	if okB and built then
		for _, d in built.model:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "Wall_Window_8x12" then
					windows += 1
				elseif d.Name == "Wall_Window_8x12_Glass" then
					table.insert(panes, d)
				end
				local isLoot = d:GetAttribute("EH_Kind") == "loot"
					or (d.Parent ~= nil and d.Parent:GetAttribute("EH_Kind") == "loot")
				if isLoot and d.Transparency < 1 then
					cash[d] = true
					table.insert(cashParts, d)
				end
				d.CanQuery = true
			end
		end
	end
	check(
		okB and windows >= 2 and #panes >= 2 and #cashParts > 0,
		string.format(
			"kit-built L1: %d partition windows, %d glass panes, %d cash part(s)%s",
			windows,
			#panes,
			#cashParts,
			if okB then "" else ": " .. tostring(built)
		)
	)
	-- Does the segment from `eye` along `dir` cross a pane of this window inside its glass?
	local function throughGlass(eye: Vector3, dir: Vector3): boolean
		for _, g in panes do
			local o = g.CFrame:PointToObjectSpace(eye)
			local v = g.CFrame:VectorToObjectSpace(dir)
			if math.abs(v.Z) > 1e-6 then
				local t = -o.Z / v.Z
				local x, y = o.X + v.X * t, o.Y + v.Y * t
				if t > 0 and t < 1 and math.abs(x) <= g.Size.X / 2 and math.abs(y) <= g.Size.Y / 2 then
					return true
				end
			end
		end
		return false
	end
	local SHELL = { Storefront_24x12 = true, Wall_Window_8x12 = true, Wall_Door_8x12 = true }
	local worst, blockers = math.huge, {}
	for _, sp in inst.level.spawns do
		local eye = at + Vector3.new(sp.x, FP_EYE, sp.z)
		local seen, tried = 0, 0
		for _, p in cashParts do
			for ix = -1, 1 do
				for iy = -1, 1 do
					local target =
						p.CFrame:PointToWorldSpace(Vector3.new(ix * p.Size.X * 0.35, iy * p.Size.Y * 0.35, 0))
					local dir = target - eye
					tried += 1
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					local skip: { Instance } = {}
					for _ = 1, 24 do
						params.FilterDescendantsInstances = skip
						local hit = workspace:Raycast(eye, dir, params)
						local part = hit and hit.Instance
						if not part or cash[part] then
							seen += if part then 1 else 0
							break
						end
						local pass = SHELL[part.Name] == true
							or string.sub(part.Name, -6) == "_Glass"
							or (part.Transparency >= 0.99 and (not part.CanCollide or throughGlass(eye, dir)))
						if not pass then
							blockers[part.Name] = (blockers[part.Name] or 0) + 1
							break
						end
						table.insert(skip, part)
					end
				end
			end
		end
		worst = math.min(worst, if tried > 0 then seen / tried else 0)
		note(string.format("seat (%g, %g): %d of %d rays reach the cash", sp.x, sp.z, seen, tried))
	end
	local names = {}
	for name, n in blockers do
		table.insert(names, name .. " " .. n)
	end
	table.sort(names)
	note("rays stopped by: " .. (if #names > 0 then table.concat(names, ", ") else "nothing"))
	check(
		worst > 0,
		string.format(
			"first person at every L1 spawn seat: the cash shows through the window (worst seat %.0f %% of rays)",
			worst * 100
		)
	)
	scratch:Destroy()
end

echo.clear()
local cf = workspace:FindFirstChild("HeistClones")
if cf then
	cf:Destroy()
end
for _, c in cases do
	if c.template then
		c.template:Destroy()
	end
end
HeistService.destroyInstance(inst)

table.insert(results, string.format("%d failure(s)", failures))
return table.concat(results, "\n")
