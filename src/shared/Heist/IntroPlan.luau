--!strict
-- Shared/Heist/IntroPlan: the story intro as data (docs/art/intro/STORYBOARD.md; docs/PLAN_FIRST_PERSON.md §5
-- "INTRO"; MASTERPLAN §4.3 "Steal Back Christmas"). Pure: no engine calls, so Lune tests it
-- (tests/unit/HeistIntro.spec.luau) and tools/blender/intro_plan.luau dumps the same shots for the Blender key
-- frames (docs/art/intro/shot_N.png). The client Heist/Cinematic builds the stage and plays this plan.
--
-- Space: stage-local Roblox studs (Y up), the town square at the origin, Hoardsworth Tower toward -Z (where the
-- Heist City sky has its landmark), the garage at +X. Config.Intro.STAGE_ORIGIN moves the whole stage.
-- Time: seconds from the first frame. Shots run back to back; events are in shot-local seconds.
--
--   IntroPlan.SHOTS                     the shot list (camera keys, caption, mood, entry, events)
--   IntroPlan.total() -> number         every shot's length summed (30-40 s, unit-tested)
--   IntroPlan.locate(t) -> (i, local)   the shot at t
--   IntroPlan.camera(t, reduced)        pos, look, fov, whip (0..1: blur weight of a whip-pan)
--   IntroPlan.caption(t)                key (Strings.INTRO), alpha, scale, wordmark?
--   IntroPlan.shake(t, reduced)         amplitude (studs) of the screen shake at t (0 under reduced motion)
--   IntroPlan.pose(track, t)            poseA, poseB, w (blend) for "hoardsworth" | "rookie"
--   IntroPlan.letter(t)                 the kid's letter: pos, tilt (radians), visible
--   IntroPlan.present(i, n, t)          flying present i of n: pos, spin, alive
--   IntroPlan.globeFill(t)              0..1 how full the Snow Globe is
--   IntroPlan.clonePrint(k, t)          0..1 tape-print reveal of clone k
--   IntroPlan.new() / advance / skip    the event stepper: a skip at any time ends in the same state

local Config = require("../Config")
local Strings = require("./Strings")

local I = Config.Intro

local IntroPlan = {}

export type V3 = { number }
export type Key = { t: number, pos: V3, look: V3, fov: number }
export type Event = { at: number, kind: string, id: string?, cue: string?, stop: boolean?, step: number?, arg: number? }
export type Shot = {
	id: string,
	seconds: number,
	move: string, -- the storyboard's camera move (crane, push, whip, low, follow, pull, hold)
	enter: string, -- "fade" (from ink) | "cut" | "whip" | "flash"
	ease: string, -- "inOut" | "out" | "in" | "linear"
	mood: string, -- IntroPlan.MOODS key
	caption: string, -- Strings.INTRO key
	captionAt: number, -- s into the shot
	wordmark: boolean?, -- the caption is the HEIST YOURSELF wordmark (the title smash)
	keys: { Key }, -- t: 0..1 of the shot (after easing)
	events: { Event },
}
export type State = {
	t: number,
	next: number, -- the next timeline event
	done: boolean,
	skipped: boolean,
	live: { [string]: boolean }, -- spawned prop groups
	loops: { [string]: boolean }, -- looping cues playing
	fx: { [string]: boolean }, -- persistent effects on (aurora, snow, vacuum, headlights...)
	ends: number, -- "end" events emitted (exactly 1 once done)
}

---------------------------------------------------------------------------
-- The stage (stage-local studs). Blender renders read the same numbers (tools/blender/intro_plan.luau).
---------------------------------------------------------------------------
local function houses(): { { number } }
	local out = {}
	-- { x, z, yaw (deg; 0 = front toward -Z), variant (1 | 2), lit (window lights) }
	for i, x in { -99, -77, -55, -33, 33, 55, 77, 99 } do
		table.insert(out, { x, -26, 180, 1 + (i % 2), 1 })
	end
	for i, x in { -99, -77, -55, -33, 33, 55, 77 } do
		table.insert(out, { x, 26, 0, 2 - (i % 2), 1 })
	end
	for i, x in { -88, -66, -44, 44, 66, 88 } do
		table.insert(out, { x, -58, 180, 1 + (i % 2), 0 })
		table.insert(out, { x, 58, 0, 2 - (i % 2), 0 })
	end
	return out
end

IntroPlan.STAGE = table.freeze({
	ground = { size = { 1600, 1, 1600 }, centre = { 0, -0.5, -40 } }, -- reaches the horizon from the tower top
	road = { size = { 240, 0.2, 20 }, centre = { 0, 0.1, 0 } },
	houses = houses(),
	lamps = { { -88, 12 }, { -44, -12 }, { 0, 12 }, { 44, -12 }, { 88, 12 } },
	tree = { 0, 0, 0 },
	tower = { base = { 0, 0, -200 }, tiers = { { 36, 60 }, { 28, 40 }, { 22, 28 } }, deck = { 40, 2, 40 } },
	deckY = 130,
	globe = { centre = { 0, 150, -205 }, radius = 16 },
	vacuum = { at = { 11, 130, -192 }, yaw = 0 },
	nozzle = { 34, 146, -168 }, -- the intake's mouth (presents vanish into it)
	lever = { at = { -12.6, 130, -184.6 }, yaw = 180 }, -- at his right hand
	hoardsworth = { at = { -9, 130, -185 }, yaw = 180 }, -- faces +Z: the town
	garage = { centre = { 130, 0, 46 }, size = { 36, 14, 24 } },
	van = { at = { 130, 0, 42 }, yaw = 90 }, -- the kit van's cab is local -X: yaw 90 turns it to +Z
	headlights = { { 127.7, 2.6, 49.6 }, { 132.3, 2.6, 49.6 } },
	rookie = { at = { 130, 0, 53.5 }, yaw = 180 },
	clones = { { 123, 0, 51 }, { 137, 0, 51 }, { 117.5, 0, 47 }, { 142.5, 0, 47 } },
	-- Where the flying presents lift off (rooftops and doorsteps; a deterministic spread).
	launch = { { -55, 6, -20 }, { -33, 12, 22 }, { 33, 8, -20 }, { 55, 10, 22 }, { -77, 9, 20 }, { 77, 7, -22 } },
})

---------------------------------------------------------------------------
-- Lighting moods (Heist/Cinematic sets these on Lighting for the intro and restores the game's afterwards).
---------------------------------------------------------------------------
IntroPlan.MOODS = table.freeze({
	-- the cosy town under the northern lights: cool moon, warm windows
	town = {
		ambient = { 70, 66, 110 },
		outdoor = { 100, 110, 160 },
		brightness = 1.6,
		exposure = 0.2,
		tint = { 236, 240, 255 },
	},
	-- the villain: a hot burgundy-gold underlight, deep shadows
	tower = {
		ambient = { 60, 34, 52 },
		outdoor = { 92, 62, 96 },
		brightness = 1.2,
		exposure = 0.1,
		tint = { 255, 232, 236 },
	},
	-- the town robbed: everything a step colder and darker
	gone = {
		ambient = { 44, 46, 86 },
		outdoor = { 62, 70, 120 },
		brightness = 1.0,
		exposure = -0.1,
		tint = { 222, 230, 255 },
	},
	-- the dark garage: headlights only
	garage = {
		ambient = { 26, 26, 46 },
		outdoor = { 40, 40, 70 },
		brightness = 0.6,
		exposure = 0.0,
		tint = { 245, 238, 255 },
	},
})

---------------------------------------------------------------------------
-- Poses (degrees per joint {x, y, z} as CFrame.fromEulerAnglesYXZ, R15 joint names; missing = rest). A
-- character faces -Z: +x swings an arm forward and up, tips the head up; on the right arm (+X side) -z
-- swings the hand in toward the body. Hoardsworth is a rigid-part rig like Gus
-- (Shared/Heist/IntroRig); the Rookie stand-in uses the same names.
---------------------------------------------------------------------------
IntroPlan.POSES = table.freeze({
	rest = {},
	gloat = { -- chin up, twirling the moustache with his right hand, left hand at the hip
		Neck = { 10, 8, 0 },
		Waist = { 4, 0, 0 },
		RightShoulder = { 118, 0, -28 },
		RightElbow = { 62, 0, 0 },
		LeftShoulder = { -10, 0, 22 },
		LeftElbow = { 30, 0, 0 },
	},
	lever = { -- right hand high on the lever, leaning in
		Neck = { -6, 10, 0 },
		Waist = { -6, 8, 0 },
		RightShoulder = { 150, 0, -6 },
		RightElbow = { 18, 0, 0 },
		LeftShoulder = { -8, 0, 14 },
	},
	pull = { -- the lever yanked down: hand at the hip
		Neck = { -4, 6, 0 },
		Waist = { -10, 4, 0 },
		RightShoulder = { 40, 0, -10 },
		RightElbow = { 60, 0, 0 },
		LeftShoulder = { -8, 0, 16 },
	},
	point = { -- arm flung out at the town: "ALL of it"
		Neck = { 8, -14, 0 },
		Waist = { 6, -10, 0 },
		RightShoulder = { 95, -20, 0 },
		LeftShoulder = { -30, 0, 22 },
		LeftElbow = { 50, 0, 0 },
	},
	-- the Rookie (stand-in or CharacterKit rig with the same joint names)
	stand = {},
	catch = { LeftShoulder = { 70, 0, 10 }, LeftElbow = { 30, 0, 0 }, Neck = { -12, -10, 0 } },
	capTug = {
		RightShoulder = { 140, 0, -22 },
		RightElbow = { 80, 0, 0 },
		LeftShoulder = { 30, 0, 8 },
		Neck = { -6, 0, 0 },
	},
	grin = { RightShoulder = { 20, 0, -6 }, LeftShoulder = { 40, 0, 8 }, LeftElbow = { 40, 0, 0 }, Neck = { 6, 12, 6 } },
} :: { [string]: { [string]: { number } } })

---------------------------------------------------------------------------
-- The shot list (STORYBOARD.md). Camera keys are stage-local; t is 0..1 of the shot after its ease.
---------------------------------------------------------------------------
IntroPlan.SHOTS = table.freeze({
	{
		id = "eve",
		seconds = 6.0,
		move = "crane",
		enter = "fade",
		ease = "inOut",
		mood = "town",
		caption = "EVE",
		captionAt = 0.9,
		keys = {
			{ t = 0, pos = { 26, 112, 168 }, look = { 0, 178, -110 }, fov = 56 },
			{ t = 0.55, pos = { 16, 50, 112 }, look = { 0, 74, -150 }, fov = 52 },
			{ t = 1, pos = { 8, 23, 74 }, look = { 0, 66, -200 }, fov = 48 },
		},
		events = {
			{ at = 0, kind = "spawn", id = "town" },
			{ at = 0, kind = "fx", id = "aurora" },
			{ at = 0, kind = "fx", id = "snow" },
			{ at = 0, kind = "cue", cue = "IntroMusic" },
			{ at = 0.2, kind = "cue", cue = "IntroBells" },
		},
	},
	{
		id = "hoard",
		seconds = 6.0,
		move = "low",
		enter = "cut",
		ease = "out",
		mood = "tower",
		caption = "HOARD",
		captionAt = 0.6,
		keys = {
			{ t = 0, pos = { -6.2, 130.9, -173.5 }, look = { -9.6, 136.6, -185 }, fov = 52 },
			{ t = 1, pos = { -7.6, 131.4, -177.6 }, look = { -9.4, 136.9, -185 }, fov = 42 },
		},
		events = {
			{ at = 0, kind = "spawn", id = "hoardsworth" },
			{ at = 0, kind = "cue", cue = "IntroHoardSting" },
			{ at = 1.3, kind = "fx", id = "glint" },
			{ at = 1.3, kind = "cue", cue = "IntroMonocle" },
			{ at = 3.2, kind = "cue", cue = "IntroLever" },
		},
	},
	{
		id = "every",
		seconds = 6.5,
		move = "whip",
		enter = "whip",
		ease = "inOut",
		mood = "tower",
		caption = "EVERY",
		captionAt = 1.3,
		keys = {
			{ t = 0, pos = { 54, 128, -134 }, look = { 34, 146, -168 }, fov = 55 },
			{ t = 0.5, pos = { 66, 96, -86 }, look = { 30, 118, -160 }, fov = 52 },
			{ t = 1, pos = { 74, 66, -30 }, look = { 6, 138, -200 }, fov = 50 },
		},
		events = {
			{ at = 0, kind = "cue", cue = "IntroWhoosh" },
			{ at = 0.35, kind = "fx", id = "vacuum" },
			{ at = 0.35, kind = "fx", id = "flash" },
			{ at = 0.35, kind = "fx", id = "shake", arg = 1.0 },
			{ at = 0.35, kind = "cue", cue = "IntroVacuumOn" },
			{ at = 0.7, kind = "cue", cue = "IntroSuction" },
			{ at = 0.8, kind = "spawn", id = "presents" },
			{ at = 3.4, kind = "fx", id = "shake", arg = 0.5 },
		},
	},
	{
		id = "gone",
		seconds = 4.0,
		move = "push",
		enter = "cut",
		ease = "out",
		mood = "gone",
		caption = "GONE",
		captionAt = 1.7,
		keys = {
			{ t = 0, pos = { -36, 168, -250 }, look = { 12, 44, 30 }, fov = 52 },
			{ t = 1, pos = { -31, 164, -241 }, look = { 12, 38, 30 }, fov = 48 },
		},
		events = {
			{ at = 0.5, kind = "fx", id = "windowsOut" },
			{ at = 1.5, kind = "cue", cue = "IntroSuction", stop = true },
			{ at = 1.5, kind = "cue", cue = "IntroGlobeThunk" },
			{ at = 1.5, kind = "fx", id = "vacuum", stop = true },
			{ at = 1.6, kind = "despawn", id = "presents" },
		},
	},
	{
		id = "one",
		seconds = 7.0,
		move = "follow",
		enter = "cut",
		ease = "inOut",
		mood = "garage",
		caption = "ONE",
		captionAt = 4.3,
		keys = {
			{ t = 0, pos = { 112, 72, 46 }, look = { 101, 63, 9 }, fov = 50 },
			{ t = 0.42, pos = { 128, 26, 80 }, look = { 124, 22, 46 }, fov = 46 },
			{ t = 0.62, pos = { 130, 2.4, 75 }, look = { 130, 5, 50 }, fov = 42 },
			{ t = 1, pos = { 130, 2.8, 66 }, look = { 130, 4.9, 53.5 }, fov = 36 },
		},
		events = {
			{ at = 0, kind = "despawn", id = "hoardsworth" },
			{ at = 0, kind = "spawn", id = "letter" },
			{ at = 0, kind = "spawn", id = "garage" },
			{ at = 0.1, kind = "cue", cue = "IntroLetter" },
			{ at = 3.9, kind = "fx", id = "headlights" },
			{ at = 3.9, kind = "cue", cue = "IntroHeadlights" },
		},
	},
	{
		id = "more",
		seconds = 4.5,
		move = "pull",
		enter = "cut",
		ease = "out",
		mood = "garage",
		caption = "MORE",
		captionAt = 0.2,
		keys = {
			{ t = 0, pos = { 130, 3, 64 }, look = { 130, 4.6, 50 }, fov = 40 },
			{ t = 1, pos = { 130, 6.5, 83 }, look = { 130, 4.2, 47 }, fov = 52 },
		},
		events = {
			{ at = 0, kind = "despawn", id = "letter" },
			{ at = 1.0, kind = "fx", id = "clone", arg = 1 },
			{ at = 1.0, kind = "cue", cue = "IntroTapePrint" },
			{ at = 1.0, kind = "cue", cue = "CloneChime", step = 0 },
			{ at = 1.3, kind = "fx", id = "clone", arg = 2 },
			{ at = 1.3, kind = "cue", cue = "CloneChime", step = 1 },
			{ at = 1.6, kind = "fx", id = "clone", arg = 3 },
			{ at = 1.6, kind = "cue", cue = "CloneChime", step = 2 },
			{ at = 1.9, kind = "fx", id = "clone", arg = 4 },
			{ at = 1.9, kind = "cue", cue = "CloneChime", step = 3 },
		},
	},
	{
		id = "title",
		seconds = 2.5,
		move = "hold",
		enter = "flash",
		ease = "linear",
		mood = "garage",
		caption = "TITLE",
		captionAt = 0,
		wordmark = true,
		keys = {
			{ t = 0, pos = { 130, 6.5, 83 }, look = { 130, 4.2, 47 }, fov = 52 },
			{ t = 1, pos = { 130, 6.6, 84 }, look = { 130, 4.2, 47 }, fov = 53 },
		},
		events = {
			{ at = 0, kind = "fx", id = "flash" },
			{ at = 0, kind = "fx", id = "title" },
			{ at = 0, kind = "cue", cue = "IntroTitleSmash" },
		},
	},
} :: { Shot })

-- Pose tracks (absolute seconds): between two keys the pose blends with a sine ease.
IntroPlan.TRACKS = table.freeze({
	hoardsworth = {
		{ 0, "gloat" },
		{ 8.7, "gloat" },
		{ 9.2, "lever" },
		{ 9.9, "lever" },
		{ 10.2, "pull" },
		{ 11.0, "point" },
	},
	rookie = {
		{ 0, "stand" },
		{ 26.4, "stand" },
		{ 26.9, "catch" },
		{ 27.6, "catch" },
		{ 28.0, "capTug" },
		{ 28.8, "capTug" },
		{ 29.2, "grin" },
	},
} :: { [string]: { { any } } })

-- The kid's letter (absolute seconds): drifting from over the town into the Rookie's left hand.
IntroPlan.LETTER = table.freeze({
	{ 22.5, { 100, 64, 8 } },
	{ 24.2, { 117, 34, 36 } },
	{ 25.4, { 126, 13, 55 } },
	{ 26.4, { 130.8, 5.2, 56.5 } },
	{ 27.1, { 132.1, 2.7, 54.3 } }, -- caught at chest height, clear of his face
})
IntroPlan.LETTER_FLUTTER = { amp = 2.2, hz = 0.9, tilt = 0.55 }

-- Flying presents: launch window and flight (absolute seconds).
IntroPlan.SWIRL = table.freeze({ start = 12.8, finish = 20.0, flight = 2.4, turns = 1.6, radius = 7 })
IntroPlan.GLOBE = table.freeze({ start = 13.4, full = 20.1, min = 0.4 }) -- he has been hoarding a while

---------------------------------------------------------------------------
-- Timing
---------------------------------------------------------------------------
local starts: { number } = {}
do
	local acc = 0
	for i, shot in IntroPlan.SHOTS do
		starts[i] = acc
		acc += shot.seconds
	end
end

function IntroPlan.total(): number
	local last = #IntroPlan.SHOTS
	return starts[last] + IntroPlan.SHOTS[last].seconds
end

function IntroPlan.startOf(i: number): number
	return starts[i] or 0
end

-- The shot at t (clamped to the plan) and the seconds into it.
function IntroPlan.locate(t: number): (number, number)
	local n = #IntroPlan.SHOTS
	if t <= 0 then
		return 1, 0
	end
	for i = 1, n do
		local e = starts[i] + IntroPlan.SHOTS[i].seconds
		if t < e then
			return i, t - starts[i]
		end
	end
	return n, IntroPlan.SHOTS[n].seconds
end

function IntroPlan.ease(kind: string, u: number): number
	local x = math.clamp(u, 0, 1)
	if kind == "inOut" then
		return 0.5 - 0.5 * math.cos(math.pi * x)
	elseif kind == "out" then
		return 1 - (1 - x) * (1 - x) * (1 - x)
	elseif kind == "in" then
		return x * x * x
	end
	return x
end

local function lerp3(a: V3, b: V3, s: number): V3
	return { a[1] + (b[1] - a[1]) * s, a[2] + (b[2] - a[2]) * s, a[3] + (b[3] - a[3]) * s }
end

-- Centripetal-free uniform Catmull-Rom through p1 -> p2 (p0, p3 the neighbours), s in 0..1.
local function catmull(p0: V3, p1: V3, p2: V3, p3: V3, s: number): V3
	local s2, s3 = s * s, s * s * s
	local out = {}
	for k = 1, 3 do
		out[k] = 0.5
			* (
				2 * p1[k]
				+ (-p0[k] + p2[k]) * s
				+ (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * s2
				+ (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * s3
			)
	end
	return out
end

-- The camera along a shot's keys at eased progress u (0..1).
function IntroPlan.along(shot: Shot, u: number): (V3, V3, number)
	local keys = shot.keys
	local n = #keys
	if n == 1 or u <= keys[1].t then
		return keys[1].pos, keys[1].look, keys[1].fov
	end
	if u >= keys[n].t then
		return keys[n].pos, keys[n].look, keys[n].fov
	end
	local j = 1
	while j < n - 1 and u > keys[j + 1].t do
		j += 1
	end
	local a, b = keys[j], keys[j + 1]
	local s = (u - a.t) / math.max(b.t - a.t, 1e-6)
	local p0 = keys[math.max(1, j - 1)]
	local p3 = keys[math.min(n, j + 2)]
	return catmull(p0.pos, a.pos, b.pos, p3.pos, s),
		catmull(p0.look, a.look, b.look, p3.look, s),
		a.fov + (b.fov - a.fov) * s
end

-- A unit look direction.
local function dir(from: V3, to: V3): V3
	local d = { to[1] - from[1], to[2] - from[2], to[3] - from[3] }
	local m = math.sqrt(d[1] * d[1] + d[2] * d[2] + d[3] * d[3])
	if m < 1e-6 then
		return { 0, 0, -1 }
	end
	return { d[1] / m, d[2] / m, d[3] / m }
end

-- Camera at t: position, look-at point, vertical FOV (deg), and the whip weight (0..1, a bell over the whip:
-- the blur). A whip-pan sweeps the look from the last shot's final direction to this shot's first over
-- Config.Intro.WHIP_SECONDS (a fast yaw: no roll ever); reduced motion cuts.
function IntroPlan.camera(t: number, reduced: boolean?): (V3, V3, number, number)
	local i, lt = IntroPlan.locate(t)
	local shot = IntroPlan.SHOTS[i]
	local u = IntroPlan.ease(shot.ease, lt / shot.seconds)
	local pos, look, fov = IntroPlan.along(shot, u)
	if shot.enter == "whip" and not reduced and i > 1 and lt < I.WHIP_SECONDS then
		local prev = IntroPlan.SHOTS[i - 1]
		local pp, pl = IntroPlan.along(prev, 1)
		local d0, d1 = dir(pp, pl), dir(pos, look)
		local s = IntroPlan.ease("inOut", lt / I.WHIP_SECONDS)
		local d = lerp3(d0, d1, s)
		local whip = math.sin(math.pi * math.clamp(lt / I.WHIP_SECONDS, 0, 1))
		return pos, { pos[1] + d[1] * 50, pos[2] + d[2] * 50, pos[3] + d[3] * 50 }, fov + 6 * whip, whip
	end
	return pos, look, fov, 0
end

-- The caption at t: Strings.INTRO key (nil = none), alpha 0..1, scale (the punch), and whether it is the wordmark.
function IntroPlan.caption(t: number): (string?, number, number, boolean)
	local i, lt = IntroPlan.locate(t)
	local shot = IntroPlan.SHOTS[i]
	local C = I.CAPTION
	local since = lt - shot.captionAt
	if since < 0 or t >= IntroPlan.total() then
		return nil, 0, 1, false
	end
	local left = shot.seconds - lt
	local a = math.min(1, since / C.IN, if shot.wordmark then 1 else left / C.OUT)
	local punch = 1 + (C.PUNCH - 1) * (1 - IntroPlan.ease("out", since / C.IN))
	return shot.caption, math.clamp(a, 0, 1), punch, shot.wordmark == true
end

-- The caption text of a shot (Strings.INTRO).
function IntroPlan.captionText(shot: Shot): string
	return Strings.INTRO[shot.caption] or ""
end

-- Words in a caption (whitespace separated; "..." alone is not a word).
function IntroPlan.words(text: string): number
	local n = 0
	for w in string.gmatch(text, "%S+") do
		if string.find(w, "%w") then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------------
-- Actors and props
---------------------------------------------------------------------------

-- Screen shake amplitude at t: every "shake" event decays over 0.9 s from its arg (x Config.Intro.SHAKE.AMP).
function IntroPlan.shake(t: number, reduced: boolean?): number
	if reduced then
		return 0
	end
	local amp = 0
	for i, shot in IntroPlan.SHOTS do
		for _, e in shot.events do
			if e.kind == "fx" and e.id == "shake" then
				local since = t - (starts[i] + e.at)
				if since >= 0 and since < 0.9 then
					amp = math.max(amp, (e.arg or 1) * (1 - since / 0.9) ^ 2)
				end
			end
		end
	end
	return amp * I.SHAKE.AMP
end

-- (poseA, poseB, weight) for a pose track at t.
function IntroPlan.pose(track: string, t: number): (string, string, number)
	local keys = IntroPlan.TRACKS[track]
	if not keys or #keys == 0 then
		return "rest", "rest", 0
	end
	if t <= keys[1][1] then
		return keys[1][2], keys[1][2], 0
	end
	for j = 1, #keys - 1 do
		local a, b = keys[j], keys[j + 1]
		if t < b[1] then
			local w = IntroPlan.ease("inOut", (t - a[1]) / math.max(b[1] - a[1], 1e-6))
			return a[2], b[2], w
		end
	end
	local last = keys[#keys][2]
	return last, last, 0
end

-- The joint rotation (degrees {x, y, z}) of a blended pose.
function IntroPlan.joint(poseA: string, poseB: string, w: number, joint: string): (number, number, number)
	local a = IntroPlan.POSES[poseA] and IntroPlan.POSES[poseA][joint]
	local b = IntroPlan.POSES[poseB] and IntroPlan.POSES[poseB][joint]
	local ax, ay, az = if a then a[1] else 0, if a then a[2] else 0, if a then a[3] else 0
	local bx, by, bz = if b then b[1] else 0, if b then b[2] else 0, if b then b[3] else 0
	return ax + (bx - ax) * w, ay + (by - ay) * w, az + (bz - az) * w
end

-- The letter at t: position, tilt (radians about its long axis), visible.
function IntroPlan.letter(t: number): (V3, number, boolean)
	local L = IntroPlan.LETTER
	if t < L[1][1] then
		return L[1][2], 0, false
	end
	local n = #L
	if t >= L[n][1] then
		return L[n][2], 0, true
	end
	local j = 1
	while j < n - 1 and t >= L[j + 1][1] do
		j += 1
	end
	local a, b = L[j], L[j + 1]
	local s = (t - a[1]) / (b[1] - a[1])
	local p = catmull(L[math.max(1, j - 1)][2], a[2], b[2], L[math.min(n, j + 2)][2], s)
	local F = IntroPlan.LETTER_FLUTTER
	local calm = math.clamp((L[n][1] - t) / 1.5, 0, 1) -- settles as it reaches the hand
	local phase = 2 * math.pi * F.hz * (t - L[1][1])
	p[1] += math.sin(phase) * F.amp * calm
	return p, math.cos(phase) * F.tilt * calm, true
end

-- Flying present i (1..n) at t: position, spin (radians), alive. Each lifts off a launch point, corkscrews up
-- toward the vacuum's mouth and is swallowed there.
function IntroPlan.present(i: number, n: number, t: number): (V3, number, boolean)
	local S = IntroPlan.SWIRL
	local window = S.finish - S.flight - S.start
	local born = S.start + window * ((i - 1) / math.max(n - 1, 1))
	local since = t - born
	local L = IntroPlan.STAGE.launch
	local from = L[(i - 1) % #L + 1]
	if since < 0 or since >= S.flight then
		return from, 0, false
	end
	local s = IntroPlan.ease("in", since / S.flight) * 0.85 + since / S.flight * 0.15
	local to = IntroPlan.STAGE.nozzle
	local p = lerp3(from, to, s)
	local ang = (i * 2.399) + s * S.turns * 2 * math.pi -- golden-angle phase per present
	local r = S.radius * (1 - s) * (0.6 + 0.4 * ((i * 7) % 5) / 4)
	p[1] += math.cos(ang) * r
	p[3] += math.sin(ang) * r
	p[2] += math.sin(math.pi * s) * 10 -- a loop up before the dive into the mouth
	return p, since * I.PRESENT_SPIN + i, true
end

-- How full the Snow Globe is (0..1): GLOBE.min before the theft, 1 once every present is in.
function IntroPlan.globeFill(t: number): number
	local G = IntroPlan.GLOBE
	local s = math.clamp((t - G.start) / (G.full - G.start), 0, 1)
	return G.min + (1 - G.min) * s
end

-- Clone k's tape print (0 = not there, 1 = solid), from its "clone" event over 0.45 s.
function IntroPlan.clonePrint(k: number, t: number): number
	for i, shot in IntroPlan.SHOTS do
		for _, e in shot.events do
			if e.kind == "fx" and e.id == "clone" and e.arg == k then
				return math.clamp((t - (starts[i] + e.at)) / 0.45, 0, 1)
			end
		end
	end
	return 0
end

---------------------------------------------------------------------------
-- The event stepper. Both a finished intro and a skipped one end with close(): every live prop group
-- despawns, every looping cue and persistent effect stops, and exactly one "end" event fires. So a skip at
-- any time lands in the same end state (tests/unit/HeistIntro.spec.luau).
---------------------------------------------------------------------------
local TIMELINE: { Event } = {}
do
	for i, shot in IntroPlan.SHOTS do
		table.insert(TIMELINE, { at = starts[i], kind = "shot", id = shot.id, arg = i })
		if shot.caption then
			table.insert(TIMELINE, { at = starts[i] + shot.captionAt, kind = "caption", id = shot.caption })
		end
		for _, e in shot.events do
			local c = table.clone(e)
			c.at = starts[i] + e.at
			table.insert(TIMELINE, c)
		end
	end
	-- stable: by time, then in list order
	for k, e in TIMELINE do
		(e :: any).order = k
	end
	table.sort(TIMELINE, function(a: any, b: any)
		if a.at ~= b.at then
			return a.at < b.at
		end
		return a.order < b.order
	end)
end
IntroPlan.TIMELINE = TIMELINE

-- Cues that keep playing until stopped.
IntroPlan.LOOPS = table.freeze({ IntroMusic = true, IntroSuction = true } :: { [string]: boolean })
-- Effects that stay on until stopped (the others are one-shots).
IntroPlan.PERSISTENT = table.freeze({
	aurora = true,
	snow = true,
	vacuum = true,
	headlights = true,
	windowsOut = true,
	title = true,
} :: { [string]: boolean })

function IntroPlan.new(): State
	return { t = 0, next = 1, done = false, skipped = false, live = {}, loops = {}, fx = {}, ends = 0 }
end

local function apply(st: State, e: Event)
	if e.kind == "spawn" and e.id then
		st.live[e.id] = true
	elseif e.kind == "despawn" and e.id then
		st.live[e.id] = nil
	elseif e.kind == "cue" and e.cue and IntroPlan.LOOPS[e.cue] then
		st.loops[e.cue] = if e.stop then nil else true
	elseif e.kind == "fx" and e.id and IntroPlan.PERSISTENT[e.id] then
		st.fx[e.id] = if e.stop then nil else true
	end
end

-- The closing events (and applies them): despawn every live group, stop every loop and persistent effect,
-- then one "end".
local function close(st: State): { Event }
	local out: { Event } = {}
	local function sorted(set: { [string]: boolean }): { string }
		local list = {}
		for k in set do
			table.insert(list, k)
		end
		table.sort(list)
		return list
	end
	for _, id in sorted(st.live) do
		table.insert(out, { at = st.t, kind = "despawn", id = id })
	end
	for _, cue in sorted(st.loops) do
		table.insert(out, { at = st.t, kind = "cue", cue = cue, stop = true })
	end
	for _, id in sorted(st.fx) do
		table.insert(out, { at = st.t, kind = "fx", id = id, stop = true })
	end
	table.insert(out, { at = st.t, kind = "end" })
	for _, e in out do
		apply(st, e)
	end
	st.done = true
	st.ends += 1
	return out
end

-- Moves the clock by dt and returns the events it crossed (at <= new t), in order; the closing events once
-- the plan is over. Nothing after done.
function IntroPlan.advance(st: State, dt: number): { Event }
	if st.done then
		return {}
	end
	st.t += math.max(0, dt)
	local out: { Event } = {}
	while st.next <= #TIMELINE and TIMELINE[st.next].at <= st.t do
		local e = TIMELINE[st.next]
		apply(st, e)
		table.insert(out, e)
		st.next += 1
	end
	if st.t >= IntroPlan.total() then
		for _, e in close(st) do
			table.insert(out, e)
		end
	end
	return out
end

-- SKIP: the closing events now (no pending event fires). Nothing if already done.
function IntroPlan.skip(st: State): { Event }
	if st.done then
		return {}
	end
	st.skipped = true
	st.next = #TIMELINE + 1
	return close(st)
end

-- The end state in one comparable table (tests): what is still live, playing or on, and how many ends.
function IntroPlan.summary(st: State): { [string]: any }
	local function count(set: { [string]: boolean }): number
		local n = 0
		for _ in set do
			n += 1
		end
		return n
	end
	return { done = st.done, live = count(st.live), loops = count(st.loops), fx = count(st.fx), ends = st.ends }
end

return table.freeze(IntroPlan)
