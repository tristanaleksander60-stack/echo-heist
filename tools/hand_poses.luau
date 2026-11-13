-- Dumps the first-person hand poses (Config.FirstPerson.VIEWMODEL.HANDS) as piece frames of the Rookie_Hands gloves
-- (RookieData.hands), for the render tool (tools/blender/rookie_anim.py row 4). The chain maths is Heist/Viewmodel's
-- fingerFrames: each segment turns about its hinge after its parent, curl about X (+ folds toward the palm in the
-- glove's rest axes), the thumb's `across` about Z (mirrored for the left hand).
--
-- Run: lune run tools/hand_poses.luau build/hand_poses.json

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Config = require("../src/shared/Config")
local RookieData = require("../src/shared/Heist/RookieData") :: any
local ViewmodelMath = require("../src/client/Heist/ViewmodelMath") :: any

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local H = Config.FirstPerson.VIEWMODEL.HANDS
local out = process.args[1] or "build/hand_poses.json"
local GLOVE = Config.Rookie.GLOVES.Gloves_Leather -- the lighter glove colour reads better on the sheet

-- Display: the hands side by side, fingers toward the camera and palms up (so a curl reads), a little turned in.
local DISPLAY = {
	Right = CFrame.new(0.62, 1.2, 0) * CFrame.Angles(math.rad(70), math.rad(-14), 0),
	Left = CFrame.new(-0.62, 1.2, 0) * CFrame.Angles(math.rad(70), math.rad(14), 0),
}

local function v3(t: { number }): any
	return Vector3.new(t[1], t[2], t[3])
end

local function flat(cf: any): { number }
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local dump: { [string]: any } = { order = H.ORDER }
for _, name in H.ORDER do
	local pose = ViewmodelMath.joints(H, H.POSES[name]) -- the per-finger pose as joint angles
	local entry = {}
	for side, segs in RookieData.hands do
		local across = Vector3.new(0, 0, if side == "Right" then 1 else -1)
		local frames: { [string]: any } = {}
		local hinges: { [string]: any } = {}
		local pieces = {}
		for _, h in segs do
			local hinge = CFrame.new(v3(h.offset))
			hinges[h.joint] = hinge
			local m: any
			if h.joint == "Palm" then
				m = CFrame.new()
			else
				local a = pose[h.joint] or { 0, 0 }
				local parent = h.parent ~= "Palm" and h.parent or nil
				local base = if parent then frames[parent] * hinges[parent]:Inverse() * hinge else hinge
				m = base
					* CFrame.fromAxisAngle(Vector3.new(1, 0, 0), math.rad(a[1]))
					* CFrame.fromAxisAngle(across, math.rad(a[2]))
			end
			frames[h.joint] = m
			table.insert(pieces, { name = h.piece, cf = flat(DISPLAY[side] * m), tint = GLOVE })
		end
		entry[side] = pieces
	end
	dump[name] = entry
end
fs.writeFile(out, serde.encode("json", dump))
print("wrote " .. out)
