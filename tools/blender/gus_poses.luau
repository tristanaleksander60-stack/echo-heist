-- Gus beat key poses for tools/blender/gus_beats.py: runs the game's own Shared/Heist/GusBeats and the
-- Heist/GusRig FK (world[joint] = world[parent] * C0 * pose; the head look on the neck and waist) and prints, per
-- shot, each part's move from its rest pivot as a Roblox CFrame (12 components). Pure Lune (@lune/roblox only for
-- CFrame maths). Run from the repo root: lune run tools/blender/gus_poses.luau

local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Config = require("../../src/shared/Config")
local GusBeats = require("../../src/shared/Heist/GusBeats")

local CFrame = roblox.CFrame
local G = Config.Gus
local B = GusBeats.BEAT

-- label, beat, seconds into it, walk phase, walk amount, run, clock, look yaw (deg, scaled by pose.look)
local SHOTS = {
	{ "Doze (zz)", B.Doze, 1, 0, 0, 0, G.DOZE_NOD_SECONDS * 0.8, 0 },
	{ "Wake: crouch", B.Wake, G.ANTICIPATION, 0, 0, 0, 0, 0 },
	{ "Wake: cap pops", B.Wake, G.ANTICIPATION + 0.17, 0, 0, 0, 0, 0 },
	{ "Patrol", B.Patrol, 1, 0.25, 1, 0, 1, 0 },
	{ "? glance", B.DoubleTake, G.ANTICIPATION + 0.08, 0, 0, 0, 0, 45 },
	{ "? double-take", B.DoubleTake, G.ANTICIPATION + 0.47, 0, 0, 0, 0, 45 },
	{ "! point", B.Chase, G.ANTICIPATION + 0.25, 0, 0, 0, 0, 0 },
	{ "Chase sprint", B.Chase, 1.2, 0.25, 1, 1, 1.2, 0 },
	{ "Chase sprint 2", B.Chase, 1.5, 0.75, 1, 1, 1.5, 0 },
	{ "Catch: lunge", B.Catch, G.ANTICIPATION + 0.25, 0, 0, 0, 0, 0 },
	{ "Wrong one?!", B.WrongOne, 0.8, 0, 0, 0, 0.8, 0 },
	{ "Wrong one: shrug", B.WrongOne, 1.7, 0, 0, 0, 1.7, 0 },
}

local parts = GusBeats.PARTS
local index: { [string]: number } = {}
for i, p in parts do
	index[p.name] = i
end

local function origin(i: number): any
	local o = parts[i].origin
	return CFrame.new(o[1], o[2], o[3])
end

local out = {}
local pose = GusBeats.newPose()
for _, shot in SHOTS do
	local w = { phase = shot[4], amount = shot[5], run = shot[6], clock = shot[7] }
	GusBeats.pose(shot[2], shot[3], w, pose)
	local lookYaw = math.rad(shot[8]) * pose.look
	local world = {}
	local moves = {}
	for i, spec in parts do
		local jp = pose.joints[spec.joint]
		local rx, ry = jp[4], jp[5]
		if spec.joint == "Neck" then
			ry += lookYaw * G.NECK_SHARE
		elseif spec.joint == "Waist" then
			ry += lookYaw * (1 - G.NECK_SHARE)
		end
		local base
		if spec.parent then
			local pi = index[spec.parent]
			base = world[pi] * (origin(pi):Inverse() * origin(i))
		else
			base = origin(i)
		end
		local wcf = base * CFrame.new(jp[1], jp[2], jp[3]) * CFrame.fromEulerAnglesYXZ(rx, ry, jp[6])
		world[i] = wcf
		moves[spec.name] = { (wcf * origin(i):Inverse()):GetComponents() }
	end
	table.insert(out, { label = shot[1], beat = shot[2], moves = moves })
end
print(serde.encode("json", out))
