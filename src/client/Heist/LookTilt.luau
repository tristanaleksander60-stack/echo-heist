--!strict
-- Heist/LookTilt: look up / down shows on other players' screens (Config.Rookie.LOOK, Shared/Heist/LookPitch).
--   * Send: in first person (the camera at your eyes) your camera pitch, quantised, goes to the server as
--     Heist.Ready { op = "look", n } at most SEND_HZ and only when it changes; out of first person it sends
--     level once. A new character sends again (the attribute starts empty on it).
--   * Apply: every OTHER player's character within RANGE (the nearest MAX_RIGS) follows its replicated
--     LOOK.ATTRIBUTE smoothly; the Neck and the Waist tilt by their clamped shares (LookPitch.split) on top of the
--     Rookie clips. The tilt is a rotation of the joint's parent-side frame (a Motor6D's C0, or an
--     AnimationConstraint's Attachment0.CFrame after the engine's joint upgrade), so the Animator's own pose stays
--     untouched. Local only: nothing replicates from here. Your own body is hidden in first person: never tilted.
--
--   LookTilt.new(deps) -> tilt     deps.camera (inEyes, fpLook), deps.send(n), deps.autoStep (default true)
--     tilt.step(dt, camPos?)       RenderStepped calls it on a client; tests call it by hand
--     tilt.count() -> number       characters tilted in the last step
--     tilt.destroy()
--   LookTilt.bind(model) -> rig?   the Neck and Waist joints of one character (nil without both)
--   LookTilt.pose(rig, neckDeg, waistDeg)   writes both joints (degrees, + = up); 0, 0 = the rest pose

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local LookPitch = require(Shared:WaitForChild("Heist"):WaitForChild("LookPitch"))

local L = Config.Rookie.LOOK
local EPS = 0.05 -- degrees: smaller changes are not written

local LookTilt = {}

type Joint = { inst: Instance, rest: CFrame } -- a Motor6D (C0) or an AnimationConstraint's Attachment0 (CFrame)
export type Rig = {
	model: Model,
	neck: Joint,
	waist: Joint,
	current: number, -- the smoothed pitch (degrees)
	shown: number, -- the pitch last written
}

local function jointIn(model: Model, partName: string, jointName: string): Joint?
	local part = model:FindFirstChild(partName)
	local j = part and part:FindFirstChild(jointName)
	if j and j:IsA("Motor6D") then
		return { inst = j, rest = j.C0 }
	end
	if j and j:IsA("AnimationConstraint") then
		local a0 = j.Attachment0
		if a0 then
			return { inst = a0, rest = a0.CFrame }
		end
	end
	return nil
end

function LookTilt.bind(model: Model): Rig?
	local neck = jointIn(model, "Head", "Neck")
	local waist = jointIn(model, "UpperTorso", "Waist")
	if not neck or not waist then
		return nil
	end
	return { model = model, neck = neck, waist = waist, current = 0, shown = 0 }
end

local function write(j: Joint, deg: number)
	local cf = j.rest * CFrame.Angles(math.rad(deg), 0, 0) -- + about the joint's X: the face turns up
	local inst = j.inst
	if inst:IsA("Motor6D") then
		inst.C0 = cf
	elseif inst:IsA("Attachment") then
		inst.CFrame = cf
	end
end

function LookTilt.pose(rig: Rig, neckDeg: number, waistDeg: number)
	write(rig.neck, neckDeg)
	write(rig.waist, waistDeg)
end

local function alive(rig: Rig): boolean
	local n, w = rig.neck.inst, rig.waist.inst
	return rig.model.Parent ~= nil and n.Parent ~= nil and w.Parent ~= nil
end

function LookTilt.new(deps: any): any
	local tilt = {}
	local rigs: { [Model]: Rig } = {}
	local lastN: number? = nil
	local lastAt: number? = nil
	local lastChar: Model? = nil
	local tilted = 0
	local conn: RBXScriptConnection? = nil

	local function release(model: Model)
		local rig = rigs[model]
		if rig then
			if alive(rig) then
				LookTilt.pose(rig, 0, 0)
			end
			rigs[model] = nil
		end
	end

	local function sendLook()
		local me = Players.LocalPlayer
		local char = me and me.Character
		if char ~= lastChar then
			lastChar = char
			lastN = nil -- a new character carries no pitch yet
		end
		if not char or not deps.send then
			return
		end
		local cam = deps.camera
		local up = 0
		if cam and cam.inEyes and cam.inEyes() then
			local _, down = cam.fpLook()
			up = -down
		end
		local n = LookPitch.quantise(up)
		local now = os.clock()
		if LookPitch.shouldSend(n, lastN, now, lastAt) then
			lastN = n
			lastAt = now
			deps.send(n)
		end
	end

	-- The characters to tilt this frame: other players', nearest first, within RANGE.
	local function candidates(camPos: Vector3?): { { model: Model, d: number } }
		local list = {}
		local me = Players.LocalPlayer
		for _, p in Players:GetPlayers() do
			local ch = p.Character
			if p ~= me and ch then
				local root = ch:FindFirstChild("HumanoidRootPart")
				local d = if camPos and root and root:IsA("BasePart") then (root.Position - camPos).Magnitude else 0
				if d <= L.RANGE then
					table.insert(list, { model = ch, d = d })
				end
			end
		end
		table.sort(list, function(a, b)
			return a.d < b.d
		end)
		return list
	end

	function tilt.step(dt: number, camPos: Vector3?)
		sendLook()
		local keep: { [Model]: boolean } = {}
		tilted = 0
		for i, c in candidates(camPos) do
			if i > L.MAX_RIGS then
				break
			end
			local model = c.model
			local rig = rigs[model]
			if rig and not alive(rig) then
				rigs[model] = nil
				rig = nil
			end
			if not rig then
				rig = LookTilt.bind(model)
				if rig then
					rigs[model] = rig
				end
			end
			if rig then
				keep[model] = true
				local raw = model:GetAttribute(L.ATTRIBUTE)
				local target = if LookPitch.validDegrees(raw) then raw :: number else 0
				rig.current = LookPitch.follow(rig.current, target, dt)
				if math.abs(rig.current - rig.shown) > EPS or (rig.current == 0 and rig.shown ~= 0) then
					local neck, waist = LookPitch.split(rig.current)
					LookTilt.pose(rig, neck, waist)
					rig.shown = rig.current
				end
				tilted += 1
			end
		end
		for model in rigs do
			if not keep[model] then
				release(model)
			end
		end
	end

	function tilt.count(): number
		return tilted
	end

	function tilt.destroy()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		for model in rigs do
			release(model)
		end
	end

	if RunService:IsClient() and deps.autoStep ~= false then
		conn = RunService.RenderStepped:Connect(function(dt: number)
			local cam = workspace.CurrentCamera
			tilt.step(math.min(dt, 0.25), cam and cam.CFrame.Position)
		end)
	end
	return tilt
end

return LookTilt
