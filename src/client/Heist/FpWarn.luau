--!strict
-- Heist/FpWarn: Gus readable in first person (PLAN_FIRST_PERSON FP §4 "Gus and cones in first person"). Up
-- close his floor cone is hard to read, so while the camera is at your eyes a soft tint creeps in from the
-- screen edges whenever his cone is on you: amber while he is noticing you ("?", stage 1), Alarm Red once
-- he is sure ("!", stage 2), strongest on the side he is on (FpMath.edgeWeights) and never gone from the
-- others. It eases in and out (Config.FirstPerson.WARN): a tint, not a flash. Only the "!" onset adds a short
-- pulse, and only when the one flash limiter allows it (Heist/FlashLimit) and motion is not reduced.
-- Reads the replicated guard attributes (G<i>Focus, G<i>Meter, G<i>Stage, G<i>X, G<i>Z): view only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local FlashLimit = require(script.Parent:WaitForChild("FlashLimit"))
local FpMath = require(script.Parent:WaitForChild("FpMath"))

local W = Config.FirstPerson.WARN

local FpWarn = {}

-- The strongest threat on you from the instance folder's guard attributes: stage (0, 1 "?", 2 "!") and that
-- guard's level-space x, z. `me` = your live actor id this run.
function FpWarn.threat(folder: Instance?, guards: number, me: number?): (number, number?, number?)
	if not folder or not me or me <= 0 then
		return 0, nil, nil
	end
	local best, bx, bz = 0, nil, nil
	for i = 1, guards do
		local focus = folder:GetAttribute("G" .. i .. "Focus")
		local meter = folder:GetAttribute("G" .. i .. "Meter")
		if focus == me and type(meter) == "number" and meter > 0 then
			local stage = folder:GetAttribute("G" .. i .. "Stage")
			local st = if type(stage) == "number" then math.max(1, stage) else 1
			if st > best then
				local x, z = folder:GetAttribute("G" .. i .. "X"), folder:GetAttribute("G" .. i .. "Z")
				best = st
				bx = if type(x) == "number" then x else nil
				bz = if type(z) == "number" then z else nil
			end
		end
	end
	return best, bx, bz
end

function FpWarn.new(state: any, fxGui: ScreenGui): any
	local warn = {}
	local layer = Instance.new("Frame")
	layer.Name = "GusEdgeWarn"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Active = false
	layer.ZIndex = 1
	layer.Visible = false
	layer.Parent = fxGui

	-- One gradient frame per edge: opaque at the edge, clear inward.
	local function edge(name: string, anchor: Vector2, pos: UDim2, size: UDim2, rotation: number): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = anchor
		f.Position = pos
		f.Size = size
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Palette.amber
		f.BackgroundTransparency = 0
		f.Active = false
		f.ZIndex = 1
		local g = Instance.new("UIGradient")
		g.Rotation = rotation
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.75),
			NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = f
		f.Parent = layer
		return f
	end
	local e = W.EDGE
	local left = edge("Left", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(e, 1), 0)
	local right = edge("Right", Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(e, 1), 180)
	local top = edge("Top", Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, e), 90)
	local bottom = edge("Bottom", Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, e), -90)
	local edges = { left, right, top, bottom }

	local strength = 0
	local pulse = 0
	local lastStage = 0
	local colour = Palette.amber

	local function myActor(): number?
		local run = state.run
		local lp = Players.LocalPlayer
		if not run or not lp then
			return nil
		end
		for _, a in run.actors or {} do
			if a.kind == "live" and a.owner == lp.UserId then
				return a.id
			end
		end
		return nil
	end

	function warn.update(now: number, dt: number)
		local active = state.fpView == true and state.where == "heist" and state.phase == "Run"
		local level = state.level
		local guards = if level and level.guards then #level.guards else 0
		local stage, gx, gz = 0, nil, nil
		if active and guards > 0 then
			stage, gx, gz = FpWarn.threat(state.folder, guards, myActor())
		end
		local target = if stage >= 2 then W.SURE elseif stage >= 1 then W.SEEN else 0
		strength = FpMath.approach(strength, target, dt, W.IN_SECONDS, W.OUT_SECONDS)
		if stage >= 2 and lastStage < 2 and state.reduced ~= true and FlashLimit.allow(now) then
			pulse = W.PULSE
		end
		if stage > 0 then
			colour = (Palette :: any)[if stage >= 2 then W.COLOURS.sure else W.COLOURS.seen] or Palette.amber
		end
		lastStage = stage
		pulse = math.max(0, pulse - dt * W.PULSE / math.max(W.PULSE_SECONDS, 1e-3))
		local total = math.clamp(strength + pulse, 0, 1)
		layer.Visible = total > 0.01
		if not layer.Visible then
			return
		end
		local wl, wr, wt, wb = 1, 1, 1, 1
		local cam = workspace.CurrentCamera
		if cam and gx and gz then
			local origin: Vector3 = state.origin or Vector3.zero
			local to = (origin + Vector3.new(gx, 0, gz)) - cam.CFrame.Position
			local look = cam.CFrame.LookVector
			local threatYaw = FpMath.angles({ to.X, 0, to.Z })
			local lookYaw = FpMath.angles({ look.X, 0, look.Z })
			wl, wr, wt, wb = FpMath.edgeWeights(FpMath.wrap(threatYaw - lookYaw), W.SIDE_MIN)
		end
		for k, f in edges do
			local w = if k == 1 then wl elseif k == 2 then wr elseif k == 3 then wt else wb
			f.BackgroundColor3 = colour
			f.BackgroundTransparency = 1 - total * w
		end
	end

	function warn.hide()
		strength, pulse, lastStage = 0, 0, 0
		layer.Visible = false
	end

	return warn
end

return FpWarn
