-- Animation-upload spike (PLAN_STEAM_PLUS §4.4 A3; docs/research/roblox_quality.md §4.1 path A).
-- Writes a 2-key R15 KeyframeSequence as a binary .rbxm with @lune/roblox, no Studio:
--   key 0.0 s: arms at rest; key 0.5 s: the right arm raised forward 90 degrees.
-- Clip rules (roblox_quality §4.1): times on a 30 fps grid, the root pose weight 0, child joints
-- weight 1, the pose tree follows the R15 part tree (HumanoidRootPart > LowerTorso > UpperTorso
-- > RightUpperArm).
-- Run: lune run tools/anim_spike.luau build/anim_spike.rbxm
-- Upload: python3 tools/anim_upload.py build/anim_spike.rbxm

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Enum = roblox.Enum

local out = process.args[1] or "build/anim_spike.rbxm"

local function pose(name: string, parent: any, cf: any, weight: number): any
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.Weight = weight
	p.EasingStyle = Enum.PoseEasingStyle.Linear
	p.EasingDirection = Enum.PoseEasingDirection.In
	p.Parent = parent
	return p
end

local function keyframe(seq: any, time: number, armAngle: number)
	local k = Instance.new("Keyframe")
	k.Name = "Keyframe"
	k.Time = time
	k.Parent = seq
	local root = pose("HumanoidRootPart", k, CFrame.new(), 0)
	local lower = pose("LowerTorso", root, CFrame.new(), 1)
	local upper = pose("UpperTorso", lower, CFrame.new(), 1)
	pose("RightUpperArm", upper, CFrame.Angles(armAngle, 0, 0), 1)
end

local seq = Instance.new("KeyframeSequence")
seq.Name = "EH_Spike_ArmRaise"
seq.Loop = true
seq.Priority = Enum.AnimationPriority.Action
keyframe(seq, 0, 0)
keyframe(seq, 15 / 30, math.rad(90))

fs.writeFile(out, roblox.serializeModel({ seq }))
print("wrote " .. out)
