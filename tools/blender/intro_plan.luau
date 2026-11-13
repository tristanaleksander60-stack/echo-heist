--!strict
-- Dumps the story intro's plan as JSON for tools/blender/intro_shots.py (the key frames in docs/art/intro/): the
-- stage, the rig, and per shot the key frame's time, camera, caption, mood, poses, props and effects, all from the
-- same pure Shared/Heist/IntroPlan the client plays (Heist/Cinematic), so a render shows what the game frames.
--   lune run tools/blender/intro_plan.luau > intro_plan.json

local serde = require("@lune/serde")

local Config = require("../../src/shared/Config")
local IntroPlan = require("../../src/shared/Heist/IntroPlan")
local IntroRig = require("../../src/shared/Heist/IntroRig")
local Strings = require("../../src/shared/Heist/Strings")

-- The key frame of each shot (s into it): the moment the storyboard draws.
local KEY = { eve = 4.6, hoard = 2.0, every = 2.2, gone = 2.6, one = 6.6, more = 3.2, title = 0.9 }

local function poseTable(track: string, t: number): { [string]: { number } }
	local a, b, w = IntroPlan.pose(track, t)
	local out = {}
	local joints = {
		"Root",
		"Waist",
		"Neck",
		"RightShoulder",
		"RightElbow",
		"RightWrist",
		"LeftShoulder",
		"LeftElbow",
		"LeftWrist",
		"RightHip",
		"RightKnee",
		"LeftHip",
		"LeftKnee",
	}
	for _, j in joints do
		local x, y, z = IntroPlan.joint(a, b, w, j)
		out[j] = { x, y, z }
	end
	return out
end

local shots = {}
for i, shot in IntroPlan.SHOTS do
	local t = IntroPlan.startOf(i) + (KEY[shot.id] or shot.seconds / 2)
	-- what is live / on at t: step the plan there
	local st = IntroPlan.new()
	IntroPlan.advance(st, t)
	local live, fx = {}, {}
	for k in st.live do
		table.insert(live, k)
	end
	for k in st.fx do
		table.insert(fx, k)
	end
	local pos, look, fov = IntroPlan.camera(t, false)
	local key, alpha, scale, wordmark = IntroPlan.caption(t)
	local presents = {}
	local n = Config.Intro.PRESENTS[1]
	for k = 1, n do
		local p, spin, alive = IntroPlan.present(k, n, t)
		if alive then
			table.insert(presents, { pos = p, spin = spin, variant = (k - 1) % 3 + 1 })
		end
	end
	local lp, tilt, lv = IntroPlan.letter(t)
	local clones = {}
	for k = 1, #IntroPlan.STAGE.clones do
		clones[k] = IntroPlan.clonePrint(k, t)
	end
	table.insert(shots, {
		index = i,
		id = shot.id,
		t = t,
		move = shot.move,
		mood = shot.mood,
		cam = { pos = pos, look = look, fov = fov },
		caption = if key then Strings.INTRO[key] else nil,
		captionAlpha = alpha,
		captionScale = scale,
		wordmark = wordmark,
		live = live,
		fx = fx,
		hoardsworth = poseTable("hoardsworth", t),
		rookie = poseTable("rookie", t),
		lever = select(2, IntroPlan.pose("hoardsworth", t)),
		presents = presents,
		letter = { pos = lp, tilt = tilt, visible = lv },
		globeFill = IntroPlan.globeFill(t),
		clones = clones,
		shake = IntroPlan.shake(t, false),
	})
end

local rig = {}
for _, p in IntroRig.PARTS do
	table.insert(rig, { name = p.name, joint = p.joint, parent = p.parent, origin = p.origin })
end

print(serde.encode("json", {
	stage = IntroPlan.STAGE,
	moods = IntroPlan.MOODS,
	rig = rig,
	shots = shots,
	total = IntroPlan.total(),
	letterScale = IntroPlan.LETTER_SCALE,
}, false))
