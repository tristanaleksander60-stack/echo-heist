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
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
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

-- Type specimen (decision D8): the wordmark and the two candidate display faces at 14, 24, 36
-- and 64 px, each as a stamp, a button label and a results line, over the G1 frame.
local function specimen()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "EH_TypeSpecimen"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(24, 24)
	list.Size = UDim2.new(1, -48, 1, -48)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list
	local function line(text: string, face: Font, size: number, color: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.FontFace = face
		l.TextSize = size
		l.TextColor3 = color
		l.TextStrokeColor3 = Palette.ink
		l.TextStrokeTransparency = 0.2
		l.Text = text
		l.Parent = list
	end
	local luckiest = Font.fromEnum(Enum.Font.LuckiestGuy)
	local fredoka = Font.fromEnum(Enum.Font.FredokaOne)
	line("HEIST YOURSELF", luckiest, 64, Palette.white)
	for _, face in { luckiest, fredoka } do
		for _, size in { 14, 24, 36, 64 } do
			line(string.format("8 OF ME   REWIND   $1,000 BANKED (%d)", size), face, size, Palette.gold)
		end
	end
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- camera: Heist/CameraDirector; state: HeistClient's state; echo: Heist/EchoView.
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
	if spec.specimen then
		task.spawn(specimen)
	end
end

return GoldenShots
