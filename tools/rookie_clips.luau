-- Bakes the Rookie's locomotion set (Shared/Heist/RookieMoves: idle, look, walk, run, jump, fall, land) into R15
-- KeyframeSequences, one .rbxm each, for upload as Animation assets (REVIEW_STEAM_PLUS #6). Every joint is keyed
-- (Weight 1) at KEYS_PER_SECOND with linear easing; Pose.CFrame = the joint's Transform from RookieMoves.
-- Also writes poses.json (the same samples) for the render tool (tools/blender/rookie_anim.py), so the contact
-- sheet shows exactly what the game plays.
--
-- Run:    lune run tools/rookie_clips.luau build/rookie_clips
-- Upload: python3 tools/anim_upload.py --rookie build/rookie_clips   (new ids -> src/shared/Heist/RookieClips.luau)

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local RookieMoves = require("../src/shared/Heist/RookieMoves")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Enum = roblox.Enum

local outDir = process.args[1] or "build/rookie_clips"

local function keyframe(seq: any, time: number, pose: RookieMoves.Pose)
	local k = Instance.new("Keyframe")
	k.Name = "Keyframe"
	k.Time = time
	local made: { [string]: any } = {}
	local function poseFor(name: string): any
		local existing = made[name]
		if existing then
			return existing
		end
		local p = Instance.new("Pose")
		p.Name = name
		p.CFrame = CFrame.new()
		p.Weight = if name == "HumanoidRootPart" then 0 else 1
		p.EasingStyle = Enum.PoseEasingStyle.Linear
		p.EasingDirection = Enum.PoseEasingDirection.In
		local parentName = RookieMoves.PARENT[name]
		p.Parent = if parentName then poseFor(parentName) else k
		made[name] = p
		return p
	end
	for _, part in RookieMoves.PARTS do
		local j = pose[part]
		local p = poseFor(part)
		p.CFrame = CFrame.new(j[4] or 0, j[5] or 0, j[6] or 0) * CFrame.fromEulerAnglesYXZ(j[1], j[2], j[3])
	end
	k.Parent = seq
end

fs.writeDir(outDir)
local dump: { [string]: any } = {}
for _, name in RookieMoves.ORDER do
	local spec = RookieMoves.CLIPS[name]
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "EH_Rookie_" .. name
	seq.Loop = spec.looped
	seq.Priority = (Enum.AnimationPriority :: any)[spec.priority]
	local times = RookieMoves.keyTimes(name)
	local frames = {}
	for i, t in times do
		-- loops end on the first key's pose, so the seam is invisible
		local at = if spec.looped and i == #times then 0 else t
		local pose = RookieMoves.sample(name, at)
		keyframe(seq, t, pose)
		local fk = {}
		for part, x in RookieMoves.fk(pose) do
			fk[part] = { m = x.m, t = x.t }
		end
		table.insert(frames, { t = t, pose = pose, fk = fk })
	end
	dump[name] = { length = spec.length, looped = spec.looped, frames = frames }
	local path = outDir .. "/EH_Rookie_" .. name .. ".rbxm"
	fs.writeFile(path, roblox.serializeModel({ seq }))
	print(string.format("wrote %s (%d keys, %.2f s, loop %s)", path, #times, spec.length, tostring(spec.looped)))
end
dump.pivots = RookieMoves.PIVOT
dump.parent = RookieMoves.PARENT
fs.writeFile(outDir .. "/poses.json", serde.encode("json", dump))
print("wrote " .. outDir .. "/poses.json")
