--!strict
-- Heist/GoldenShots: the client side of golden-frame staging (docs/GOLDEN_FRAMES.md
-- "Capture", Shared/Heist/Scenario; re-specced for first person and the Rookie, REVIEW_STEAM_PLUS #4). Studio
-- only: nothing happens unless RunService:IsStudio() and the Workspace attribute EH_Scenario names a scenario
-- (the server's Heist/Staging starts the level). The Studio debug chip hides itself while a scenario is set
-- (Heist/DebugChip).
--   G1 / TYPE  first person in L1: the camera stays in your eyes (your Rookie hands, the reticle, the HUD); once
--              per run, after the run-start beat, you are moved back onto the street (GOLDEN.G1.STAND: from the
--              spawn itself the doorway fills the frame) and turned toward the cash glinting through the shop's
--              windows, tilted up for the tall tenement and the aurora (Config.Heist.CAMERA.GOLDEN.G1)
--   G2 / CLONE_AB  the "8 OF ME" pull-back: pitch 45, FOV 45, distance fitted so you and every
--              clone of yours (eight Rookies in your crew colours) sit inside the central 32 % of the width
--   G3         first person in the hideout: you are moved once to GOLDEN.G3.STAND in the aisle at the vans and
--              look between the job board and your van
-- The look goes through CameraDirector.frameRunStart (its yaw; the pitch is the run-start pitch, swapped for the
-- golden one for that one call), so the camera director's own first-person code draws the frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Scenario = require(Shared:WaitForChild("Heist"):WaitForChild("Scenario"))

local CameraMath = require(script.Parent:WaitForChild("CameraMath"))

local GoldenShots = {}

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function t3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

-- The active scenario on this client, or nil (always nil outside Studio).
function GoldenShots.active(): string?
	return Scenario.resolve(RunService:IsStudio(), workspace:GetAttribute(Scenario.ATTRIBUTE))
end

-- The level-space position of a level's loot by id, or nil.
local function lootAt(level: any, id: string): { number }?
	for _, item in (if level then level.loot else nil) or {} do
		if item.id == id then
			return { item.x, item.y, item.z }
		end
	end
	return nil
end

-- Turns the first-person look to (yaw, pitch down) through the camera director's run-start framing.
local function look(camera: any, yaw: number, pitch: number)
	local FP = Config.Heist.CAMERA.FP
	local keep = FP.START_PITCH
	FP.START_PITCH = pitch
	camera.frameRunStart(nil, 0, math.rad(yaw))
	FP.START_PITCH = keep
end

-- First-person staging for G1 / G3: once per run (G1) or once in the hideout (G3), when the camera is in your
-- eyes and no beat or moment holds it.
local function stageFp(camera: any, state: any, shot: string)
	local G = Config.Heist.CAMERA.GOLDEN
	local player = Players.LocalPlayer
	local done: string? = nil
	camera.setMode("fp", false)
	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or camera.presenting() then
			return
		end
		if shot == "G1" then
			local run = state.run
			if state.where ~= "heist" or state.phase ~= "Run" or not run then
				return
			end
			local key = "run" .. tostring(run.run)
			if done == key or not camera.inEyes() then
				return
			end
			done = key
			local origin: Vector3 = state.origin or Vector3.zero
			local cash = lootAt(state.level, G.G1.LOOT)
			if cash then
				local s = G.G1.STAND
				local at = if s then origin + Vector3.new(s[1], root.Position.Y - origin.Y, s[2]) else root.Position
				local yaw, pitch = Scenario.fpLook(G.G1, t3(at), t3(origin + v3(cash)))
				char:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
				look(camera, yaw, pitch)
			end
		elseif shot == "G3" then
			if state.where ~= "garage" or done == "garage" then
				return
			end
			done = "garage"
			local o = v3(Config.Heist.LOBBY_ORIGIN)
			local s = G.G3.STAND
			local at = o + Vector3.new(s[1], root.Position.Y - o.Y, s[2])
			local yaw, pitch = Scenario.fpLook(G.G3, t3(at), t3(o + v3(G.G3.LOOK_AT)))
			char:PivotTo(CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0))
			look(camera, yaw, pitch)
		end
	end)
end

-- TYPE: the specimen itself is drawn by Heist/TypeSpecimen (UI kit), which watches the same
-- scenario through Scenario.resolve; this module only places the camera.

function GoldenShots.start(camera: any, state: any, echo: any)
	local name = GoldenShots.active()
	local spec = Scenario.spec(name)
	if not spec then
		return
	end
	local G = Config.Heist.CAMERA.GOLDEN
	local player = Players.LocalPlayer

	if spec.fp then
		stageFp(camera, state, spec.shot)
	elseif spec.shot == "G2" then
		local focus: Vector3? = nil
		local dist = G.G2.MAX_DISTANCE
		camera.setShot(function(): (CFrame?, number?)
			local cam = workspace.CurrentCamera
			local run = state.run
			if not cam or state.where ~= "heist" or not run or not run.actors then
				return nil, nil
			end
			-- You and every clone of yours: feet and head of each.
			local points: { { number } } = {}
			local sum, n = Vector3.zero, 0
			local function add(p: Vector3)
				table.insert(points, t3(p + Vector3.new(0, 2.5, 0)))
				table.insert(points, t3(p - Vector3.new(0, 2.8, 0)))
				sum += p
				n += 1
			end
			for _, a in run.actors do
				if a.kind == "clone" and a.owner == player.UserId then
					local p = echo.positionOf(a.id)
					if p then
						add(p)
					end
				end
			end
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				add(root.Position)
			end
			if n < 2 then
				return nil, nil
			end
			local want = sum / n
			local f = focus
			focus = if f then f:Lerp(want, 0.08) else want
			local vp = cam.ViewportSize
			local aspect = math.max(vp.X, 1) / math.max(vp.Y, 1)
			local fit = CameraMath.fitDistance(
				t3(focus :: Vector3),
				points,
				G.G2.YAW,
				G.G2.PITCH,
				G.G2.FOV,
				aspect,
				Config.Heist.CAMERA.LINEUP.CENTRAL_SHARE,
				0.8,
				10,
				G.G2.MAX_DISTANCE,
				0.5
			) or G.G2.MAX_DISTANCE
			dist += (fit - dist) * 0.08
			local pos, lookAt = CameraMath.orbit(t3(focus :: Vector3), G.G2.YAW, G.G2.PITCH, dist)
			return CFrame.lookAt(v3(pos), v3(lookAt)), G.G2.FOV
		end)
	end
	-- TYPE (spec.specimen): Heist/TypeSpecimen draws the specimen.
end

return GoldenShots
