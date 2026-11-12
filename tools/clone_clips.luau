-- Bakes the clone's custom poses (Shared/Heist/ClonePose: carry, plate stance, stuck, busted) into R15
-- KeyframeSequence clips, one .rbxm each, for upload as Animation assets (PLAN_STEAM_PLUS §4.4 A3).
-- ClonePose stays the single source of the poses: each key is ClonePose.compute at that time, written
-- as the joint's Pose.CFrame (= its Transform). Only the joints a pose sets are keyed (Weight 1); the
-- path down from HumanoidRootPart is Weight-0 placeholders, so the clip overrides just those joints
-- (arms, waist, head) at Action priority and the walk or idle clip keeps the rest of the body.
-- The plate glance is not baked (it looks at a live target: an IKControl does it at runtime).
--
-- Run: lune run tools/clone_clips.luau build/clips
-- Upload: python3 tools/anim_upload.py --clips build/clips   (ids -> src/shared/Heist/CloneClips.luau)

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Config = require("../src/shared/Config")
local ClonePose = require("../src/shared/Heist/ClonePose")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Enum = roblox.Enum

local C = Config.Clone
local outDir = process.args[1] or "build/clips"

-- name, state, seconds, keys per second (30 fps grid), looped, joints not to key
local CLIPS = {
	{ "carry", "carry", 1 / C.CARRY_BOB_IDLE_HZ, 15, true, {} },
	{ "plate", "on-plate", 1 / C.PLATE_SHIFT_HZ, 10, true, { Head = true } },
	{ "stuck", "stuck", C.STUCK_CYCLE, 30, true, {} },
	{ "busted", "busted", 1.0, 30, false, {} },
}

-- The R15 part tree from the root down to every joint a pose may key.
local PARENT = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
}

local function snap(t: number): number
	return math.floor(t * 30 + 0.5) / 30
end

local function keyframe(seq: any, time: number, joints: { [string]: { number } }, skip: { [string]: boolean })
	local k = Instance.new("Keyframe")
	k.Name = "Keyframe"
	k.Time = time
	local poses: { [string]: any } = {}
	local function poseFor(name: string): any
		local existing = poses[name]
		if existing then
			return existing
		end
		local p = Instance.new("Pose")
		p.Name = name
		p.CFrame = CFrame.new()
		p.Weight = 0 -- placeholder until keyed
		p.EasingStyle = Enum.PoseEasingStyle.Linear
		p.EasingDirection = Enum.PoseEasingDirection.In
		local parentName = PARENT[name]
		p.Parent = if parentName then poseFor(parentName) else k
		poses[name] = p
		return p
	end
	for name, a in joints do
		if not skip[name] and PARENT[name] then
			local p = poseFor(name)
			p.CFrame = CFrame.fromEulerAnglesYXZ(a[1], a[2], a[3])
			p.Weight = 1
		end
	end
	k.Parent = seq
end

fs.writeDir(outDir)
local pose = ClonePose.new()
for _, spec in CLIPS do
	local name, state, seconds, fps, looped, skip = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "EH_Clone_" .. name
	seq.Loop = looped
	seq.Priority = Enum.AnimationPriority.Action
	local n = math.max(1, math.floor(seconds * fps + 0.5))
	for i = 0, n do
		local t = if i == n then snap(seconds) else snap(i / fps)
		-- loops end on the first key's pose, so the seam is invisible
		local at = if looped and i == n then 0 else t
		ClonePose.compute(pose, state, at, at, 0, false, 0, 0, 1)
		keyframe(seq, t, pose.joints, skip)
	end
	local path = outDir .. "/EH_Clone_" .. name .. ".rbxm"
	fs.writeFile(path, roblox.serializeModel({ seq }))
	print(string.format("wrote %s (%d keys, %.2f s, loop %s)", path, n + 1, snap(seconds), tostring(looped)))
end
