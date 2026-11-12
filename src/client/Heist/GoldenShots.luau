--!strict
-- Heist/GoldenShots: the client side of golden-frame staging (docs/GOLDEN_FRAMES.md
-- "Capture", Shared/Heist/Scenario). Studio only: nothing happens unless
-- RunService:IsStudio() and the Workspace attribute EH_Scenario names a scenario (the server's
-- Heist/Staging starts the level). It puts the camera at the frame's framing through
-- Heist/CameraDirector.setShot, and draws the type specimen for TYPE. The Studio debug chip
-- hides itself while a scenario is set (Heist/DebugChip).
--   G1 / TYPE  the gameplay camera in the mode in use (MENU flips DIORAMA / CLASSIC for the
--              (a) / (b) pair)
--   G2 / CLONE_AB  the "8 OF ME" pull-back: pitch 45, FOV 45, distance fitted so you and every
--              clone of yours sit inside the central 32 % of the width (9:16-safe)
--   G3         a 3/4 shot of the first garage van bay: pitch 30, 22 studs, FOV 45

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

	if spec.shot == "G2" then
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
	elseif spec.shot == "G3" then
		camera.setShot(function(): (CFrame?, number?)
			local garage = workspace:FindFirstChild("Garage")
			local van = garage and garage:FindFirstChild("Van")
			if state.where ~= "garage" or not van or not van:IsA("BasePart") then
				return nil, nil
			end
			local pos, lookAt = CameraMath.orbit(t3(van.Position), G.G3.YAW, G.G3.PITCH, G.G3.DISTANCE)
			return CFrame.lookAt(v3(pos), v3(lookAt)), G.G3.FOV
		end)
	end
	-- TYPE (spec.specimen): Heist/TypeSpecimen draws the specimen.
end

return GoldenShots
