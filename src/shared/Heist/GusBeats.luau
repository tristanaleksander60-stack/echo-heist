--!strict
-- Heist/GusBeats: Gus's acting, as pure data and maths (PLAN_STEAM_PLUS §4.4 A4-A5, POLISH §4.3,
-- premium C1/C3/C4/C5/C6, roblox_quality §4.2-4.3). No engine calls: Lune unit specs run it
-- (tests/unit/HeistGusBeats.spec.luau); Heist/GusRig turns a Pose into part CFrames and Heist/GusView
-- feeds it the guard state the server replicates (G<i>Mode, AlarmOn, Caught/Busted events).
--
--   * PARTS: the 18-part rig (STYLE_BIBLE §12, KIT_IMPORT "Gus"): each part's pivot is its joint, its
--     parent and its rest origin in the model's scene space (feet on the floor at 0, facing -Z). The box
--     rig sizes its boxes from the same bounds, so both rigs pose the same way.
--   * select(): guard state -> beat. Launch beats: Doze, Wake, Patrol, DoubleTake ("?"), Chase ("!"
--     point, then the funny sprint), Catch (a grab lunge). Cut-list beats: WrongOne (busted a clone:
--     a 2 s head scratch), Scratch (lost sight).
--   * pose(): beat + time since it started + walk state -> joint rotations (radians) and offsets
--     (studs), plus how much the head looks at its target and how much the body follows. Every beat
--     starts with >= ANTICIPATION (66 ms, C1) of a counter-move.
--   * look(): the head-leads-body clamp (yaw +-LOOK_YAW_MAX, loses interest past it with hysteresis).
--   * delay line: the body yaw a HEAD_LEAD behind the head when the server drives him (C4).
--   * bootPrints(): his next PRINT_HORIZON seconds of patrol as prints at fixed points along the route
--     (they never slide), turnSoon(): the cone flickers before a patrol turn, clipFan(): each cone wedge
--     only as far as its shorter ray (no amber through walls, docs/audit/LEVELS.md G10).

local Config = require("../Config")
local Guards = require("../Sim/Guards")

local G = Config.Gus
local RAD = math.pi / 180
local TAU = 2 * math.pi
local EPS = 1e-6

local GusBeats = {}

export type Part = {
	name: string,
	joint: string,
	parent: string?, -- parent part name (nil = the root)
	origin: { number }, -- joint position at rest (scene space)
	min: { number }, -- bounds about the pivot
	max: { number },
	role: string, -- box rig colour role
}

local function part(
	name: string,
	joint: string,
	parent: string?,
	origin: { number },
	min: { number },
	max: { number },
	role: string
): Part
	return table.freeze({
		name = name,
		joint = joint,
		parent = parent,
		origin = table.freeze(origin),
		min = table.freeze(min),
		max = table.freeze(max),
		role = role,
	})
end

-- Parent first (a part's parent is always earlier in the list). Origins and bounds: Kit/KitData.
GusBeats.PARTS = table.freeze({
	part("Gus_LowerTorso", "Root", nil, { 0, 2.1, 0 }, { -1.329, -0.38, -0.98 }, { 1.17, 0.58, 0.936 }, "belt"),
	part(
		"Gus_UpperTorso",
		"Waist",
		"Gus_LowerTorso",
		{ 0, 2.62, 0 },
		{ -1.36, -0.07, -1.347 },
		{ 1.36, 2, 1.088 },
		"shirt"
	),
	part("Gus_Head", "Neck", "Gus_UpperTorso", { 0, 4.5, 0 }, { -1.04, -0.1, -1.145 }, { 1.04, 1.5, 0.8 }, "skin"),
	part("Gus_Cap", "HatAttach", "Gus_Head", { 0, 5.78, 0 }, { -1.02, -0.079, -1.39 }, { 1.02, 0.72, 0.969 }, "cap"),
	part(
		"Gus_RightUpperArm",
		"RightShoulder",
		"Gus_UpperTorso",
		{ 1.42, 4.12, 0 },
		{ -0.42, -0.928, -0.399 },
		{ 0.42, 0.42, 0.399 },
		"shirt"
	),
	part(
		"Gus_RightLowerArm",
		"RightElbow",
		"Gus_RightUpperArm",
		{ 1.52, 3.28, 0 },
		{ -0.312, -0.862, -0.314 },
		{ 0.4, 0.104, 0.314 },
		"shirt"
	),
	part(
		"Gus_RightHand",
		"RightWrist",
		"Gus_RightLowerArm",
		{ 1.6, 2.5, 0 },
		{ -0.35, -0.602, -0.37 },
		{ 0.288, 0.102, 0.27 },
		"skin"
	),
	part(
		"Gus_LeftUpperArm",
		"LeftShoulder",
		"Gus_UpperTorso",
		{ -1.42, 4.12, 0 },
		{ -0.42, -0.928, -0.399 },
		{ 0.42, 0.42, 0.399 },
		"shirt"
	),
	part(
		"Gus_LeftLowerArm",
		"LeftElbow",
		"Gus_LeftUpperArm",
		{ -1.52, 3.28, 0 },
		{ -0.4, -0.862, -0.314 },
		{ 0.312, 0.104, 0.314 },
		"shirt"
	),
	part(
		"Gus_LeftHand",
		"LeftWrist",
		"Gus_LeftLowerArm",
		{ -1.6, 2.5, 0 },
		{ -0.288, -0.602, -0.37 },
		{ 0.35, 0.102, 0.27 },
		"skin"
	),
	part(
		"Gus_RightUpperLeg",
		"RightHip",
		"Gus_LowerTorso",
		{ 0.52, 1.95, 0 },
		{ -0.42, -0.86, -0.399 },
		{ 0.42, 0.08, 0.399 },
		"legs"
	),
	part(
		"Gus_RightLowerLeg",
		"RightKnee",
		"Gus_RightUpperLeg",
		{ 0.52, 1.15, 0 },
		{ -0.36, -0.79, -0.342 },
		{ 0.36, 0.08, 0.342 },
		"legs"
	),
	part(
		"Gus_RightFoot",
		"RightAnkle",
		"Gus_RightLowerLeg",
		{ 0.52, 0.42, 0 },
		{ -0.42, -0.42, -0.97 },
		{ 0.42, 0.23, 0.4 },
		"shoe"
	),
	part(
		"Gus_LeftUpperLeg",
		"LeftHip",
		"Gus_LowerTorso",
		{ -0.52, 1.95, 0 },
		{ -0.42, -0.86, -0.399 },
		{ 0.42, 0.08, 0.399 },
		"legs"
	),
	part(
		"Gus_LeftLowerLeg",
		"LeftKnee",
		"Gus_LeftUpperLeg",
		{ -0.52, 1.15, 0 },
		{ -0.36, -0.79, -0.342 },
		{ 0.36, 0.08, 0.342 },
		"legs"
	),
	part(
		"Gus_LeftFoot",
		"LeftAnkle",
		"Gus_LeftLowerLeg",
		{ -0.52, 0.42, 0 },
		{ -0.42, -0.42, -0.97 },
		{ 0.42, 0.23, 0.4 },
		"shoe"
	),
	part(
		"Gus_Flashlight",
		"FlashlightGrip",
		"Gus_RightHand",
		{ 1.6, 2.25, -0.05 },
		{ -0.49, -0.49, -1.77 },
		{ 0.49, 0.49, 0.52 },
		"torch"
	),
	part(
		"Gus_FlashlightLens",
		"Lens",
		"Gus_Flashlight",
		{ 1.6, 2.25, -1.8 },
		{ -0.4, -0.4, -0.05 },
		{ 0.4, 0.4, 0 },
		"lens"
	),
})

-- The Christmas layer's hat replaces Gus_Cap on the same joint.
GusBeats.HAT = part(
	"Gus_SantaHat",
	"HatAttach",
	"Gus_Head",
	{ 0, 5.78, 0 },
	{ -1.12, -0.185, -1.12 },
	{ 1.12, 1.596, 1.616 },
	"hat"
)

GusBeats.JOINTS = table.freeze((function()
	local out = {}
	for _, p in GusBeats.PARTS do
		table.insert(out, p.joint)
	end
	return out
end)())

GusBeats.BEAT = table.freeze({
	Doze = "Doze",
	Wake = "Wake",
	Patrol = "Patrol",
	DoubleTake = "DoubleTake",
	Chase = "Chase",
	Catch = "Catch",
	WrongOne = "WrongOne",
	Scratch = "Scratch",
})
local B = GusBeats.BEAT

-- The six launch beats (PLAN A4) and the cut-list ones done in this pass.
GusBeats.LAUNCH = table.freeze({ B.Doze, B.Wake, B.Patrol, B.DoubleTake, B.Chase, B.Catch })
GusBeats.EXTRA = table.freeze({ B.WrongOne, B.Scratch })

-- Seconds of counter-move before the main move of each beat (C1, >= 66 ms). Patrol's "anticipation" is
-- the head turning HEAD_LEAD before the body on every corner (C4).
function GusBeats.anticipation(beat: string): number
	if beat == B.Patrol then
		return G.HEAD_LEAD
	end
	return G.ANTICIPATION
end

---------------------------------------------------------------------------
-- Selection: guard state -> beat
---------------------------------------------------------------------------

export type State = { beat: string, since: number, prev: string, prevSince: number }

export type Input = {
	mode: string, -- G<i>Mode: "Patrol" | "Suspicious" | "Huh" | "Chase"
	alarmOn: boolean, -- AlarmOn
	dozer: boolean, -- a guard posted on one spot in a level with an alarm (GusBeats.isDozer)
	bang: string?, -- "catch" this frame (a Caught event on this guard), else nil
}

function GusBeats.newState(now: number): State
	return { beat = B.Patrol, since = now, prev = B.Patrol, prevSince = now }
end

local function enter(st: State, beat: string, now: number)
	if st.beat ~= beat then
		st.prev, st.prevSince = st.beat, st.since
		st.beat, st.since = beat, now
	end
end

-- Updates st for this frame and returns the beat.
function GusBeats.select(st: State, inp: Input, now: number): string
	local cur, age = st.beat, now - st.since
	if inp.bang == "catch" then
		-- A new catch restarts the lunge.
		st.prev, st.prevSince = st.beat, st.since
		st.beat, st.since = B.Catch, now
		return B.Catch
	end
	if cur == B.Catch and age < G.CATCH_SECONDS then
		return cur
	end
	local mode = inp.mode
	if mode == "Huh" then
		enter(st, B.WrongOne, now)
		return st.beat
	end
	if mode == "Chase" or (cur == B.Doze and inp.alarmOn) then
		if cur == B.Doze then
			enter(st, B.Wake, now)
			return st.beat
		end
		if cur == B.Wake and age < G.WAKE_SECONDS then
			return cur
		end
		if mode == "Chase" then
			enter(st, B.Chase, now)
			return st.beat
		end
	end
	if mode == "Suspicious" then
		enter(st, B.DoubleTake, now)
		return st.beat
	end
	-- Patrol (or a dozer the alarm has not reached yet).
	if cur == B.DoubleTake then
		enter(st, B.Scratch, now)
		return st.beat
	end
	if cur == B.Scratch and age < G.SCRATCH_SECONDS then
		return cur
	end
	if cur == B.Wake and age < G.WAKE_SECONDS then
		return cur
	end
	if inp.dozer and not inp.alarmOn then
		enter(st, B.Doze, now)
	else
		enter(st, B.Patrol, now)
	end
	return st.beat
end

-- A guard posted on one spot (every route point the same) dozes in a level with an alarm (L5's back
-- office, DV09) until the alarm wakes him.
function GusBeats.isPost(route: any): boolean
	if route == nil or route.legs == nil or #route.legs == 0 then
		return false
	end
	for _, leg in route.legs do
		if leg.len > EPS then
			return false
		end
	end
	return true
end

function GusBeats.isDozer(level: any, guard: any): boolean
	return level ~= nil and level.alarm ~= nil and guard ~= nil and GusBeats.isPost(guard.route)
end

---------------------------------------------------------------------------
-- Poses
---------------------------------------------------------------------------

-- joints[name] = { px, py, pz, rx, ry, rz }: offset (studs) and rotation (radians, applied as
-- CFrame.fromEulerAnglesYXZ) of the joint, in its parent's frame. Signs (Roblox, facing -Z): rx > 0
-- swings a hanging limb forward and tips a torso or head back; ry > 0 turns toward +yaw (like the
-- guard's own yaw); rz > 0 swings a hanging arm toward +X (out for the right arm, in for the left).
-- look = how much the head turns to its target (0..1+),
-- follow = how much the body turns with the guard yaw (0 = holds the yaw it had when the beat began).
export type Pose = {
	joints: { [string]: { number } },
	look: number,
	follow: number,
	torchPitch: number, -- degrees: the torch's pitch in the body frame (the wrist keeps it there)
	lens: boolean, -- torch on
}

function GusBeats.newPose(): Pose
	local joints = {}
	for _, name in GusBeats.JOINTS do
		joints[name] = { 0, 0, 0, 0, 0, 0 }
	end
	return { joints = joints, look = 1, follow = 1, torchPitch = 0, lens = true }
end

function GusBeats.clear(p: Pose)
	for _, j in p.joints do
		j[1], j[2], j[3], j[4], j[5], j[6] = 0, 0, 0, 0, 0, 0
	end
	p.look, p.follow, p.torchPitch, p.lens = 1, 1, 0, true
end

-- out = a + (b - a) * w (out may be a or b).
function GusBeats.blend(a: Pose, b: Pose, w: number, out: Pose)
	for name, oj in out.joints do
		local aj, bj = a.joints[name], b.joints[name]
		for k = 1, 6 do
			oj[k] = aj[k] + (bj[k] - aj[k]) * w
		end
	end
	out.look = a.look + (b.look - a.look) * w
	out.follow = a.follow + (b.follow - a.follow) * w
	out.torchPitch = a.torchPitch + (b.torchPitch - a.torchPitch) * w
	out.lens = if w >= 0.5 then b.lens else a.lens
end

local function rot(p: Pose, joint: string, rx: number, ry: number, rz: number)
	local j = p.joints[joint]
	j[4] += rx * RAD
	j[5] += ry * RAD
	j[6] += rz * RAD
end

local function move(p: Pose, joint: string, px: number, py: number, pz: number)
	local j = p.joints[joint]
	j[1] += px
	j[2] += py
	j[3] += pz
end

local function clamp01(x: number): number
	return if x < 0 then 0 elseif x > 1 then 1 else x
end

-- 0..1 across [t0, t1].
local function seg(t: number, t0: number, t1: number): number
	return clamp01((t - t0) / (t1 - t0))
end

local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

-- 0 -> 1 -> 0 across [t0, t1].
local function bump(t: number, t0: number, t1: number): number
	if t <= t0 or t >= t1 then
		return 0
	end
	return math.sin(math.pi * (t - t0) / (t1 - t0))
end

-- Back-out ease (overshoots ~10 % then settles).
local function backOut(x: number): number
	x = clamp01(x)
	local c1 = 1.70158
	local c3 = c1 + 1
	local y = x - 1
	return 1 + c3 * y * y * y + c1 * y * y
end

local function lerp(a: number, b: number, w: number): number
	return a + (b - a) * w
end

export type Walk = {
	phase: number, -- step cycle (1 = two steps), advanced by distance walked
	amount: number, -- 0 standing .. 1 full walk
	run: number, -- 0 walk .. 1 sprint (chase)
	clock: number, -- free-running seconds (breathing, sway, nods)
}

-- The FK walk / sprint cycle (roblox_quality §4.2) with secondary motion: the head (and so the
-- moustache) and the cap lag behind the two step dips (C5).
local function walkLayer(p: Pose, w: Walk)
	local amt, run = clamp01(w.amount), clamp01(w.run)
	local a = w.phase * TAU
	local s, c = math.sin(a), math.cos(a)
	local hip = lerp(G.HIP_SWING, G.RUN_HIP_SWING, run) * amt
	local knee = lerp(G.KNEE_LIFT, G.RUN_KNEE_LIFT, run) * amt
	local arm = lerp(G.ARM_SWING, G.RUN_ARM_SWING, run) * amt
	local elbow = lerp(G.ELBOW, G.RUN_ELBOW, run) * amt
	local bob = lerp(G.BOB, G.RUN_BOB, run) * amt
	local lean = lerp(G.LEAN, G.RUN_LEAN, run) * amt
	rot(p, "RightHip", hip * s, 0, 0)
	rot(p, "LeftHip", -hip * s, 0, 0)
	rot(p, "RightKnee", -knee * math.max(0, c), 0, 0)
	rot(p, "LeftKnee", -knee * math.max(0, -c), 0, 0)
	-- Arms counter-swing; the torch arm stays forward (a small swing) until he sprints.
	rot(p, "LeftShoulder", arm * s, 0, 0)
	rot(p, "LeftElbow", elbow, 0, 0)
	local torchArm = lerp(G.TORCH_ARM_SWING * amt, arm, run)
	rot(p, "RightShoulder", -torchArm * s, 0, 0)
	rot(p, "RightElbow", lerp(G.ELBOW * 0.5 * amt, elbow, run), 0, 0)
	-- Two dips per cycle, a forward lean, the torso counter-twist (the head keeps facing forward).
	local dip = (1 + math.cos(2 * a)) / 2
	move(p, "Root", 0, -bob * dip, 0)
	rot(p, "Root", -lean, G.TWIST * s * amt, G.RUN_WADDLE * run * amt * s)
	rot(p, "Neck", 0, -G.TWIST * 0.7 * s * amt, -G.RUN_WADDLE * 0.6 * run * amt * s)
	-- Secondary: the head nods behind each dip (moustache bounce), the cap lags a little more.
	local lagged = (1 + math.cos(2 * a - G.MOUSTACHE_LAG)) / 2
	rot(p, "Neck", -(G.MOUSTACHE_BOUNCE + G.RUN_HEAD_BOB * run) * amt * (lagged - 0.5), 0, 0)
	local capLag = (1 + math.cos(2 * a - 2 * G.MOUSTACHE_LAG)) / 2
	move(p, "HatAttach", 0, G.CAP_BOUNCE * (1 + 2 * run) * amt * capLag, 0)
end

-- Standing: breathing, a slow head drift, the torch swaying (C5).
local function idleLayer(p: Pose, w: Walk, weight: number)
	local still = clamp01(1 - w.amount) * weight
	if still <= 0 then
		return
	end
	local b = math.sin(w.clock * TAU * G.BREATH_HZ)
	move(p, "Root", 0, G.BREATH * b * still, 0)
	rot(p, "Waist", 1.5 * b * still, 0, 0)
	rot(p, "RightShoulder", 2 * b * still, 0, 0)
	rot(p, "LeftShoulder", 2 * b * still, 0, 0)
	rot(p, "Neck", 0, G.IDLE_LOOK * math.sin(w.clock * TAU * 0.13) * still, 0)
end

local function torchSway(p: Pose, w: Walk, weight: number)
	rot(p, "FlashlightGrip", 0, G.TORCH_SWAY * math.sin(w.clock * TAU * G.TORCH_SWAY_HZ) * weight, 0)
end

-- Arms folded over the belly (doze).
local function foldArms(p: Pose, weight: number)
	rot(p, "RightShoulder", 75 * weight, 0, -8 * weight)
	rot(p, "RightElbow", 45 * weight, 30 * weight, 0)
	rot(p, "LeftShoulder", 75 * weight, 0, 8 * weight)
	rot(p, "LeftElbow", 45 * weight, -30 * weight, 0)
end

-- Left hand scratching the back of the cap (WrongOne, Scratch).
local function scratch(p: Pose, t: number, weight: number)
	rot(p, "LeftShoulder", 150 * weight, 0, 25 * weight)
	rot(p, "LeftElbow", (95 + 12 * math.sin(t * TAU * 5)) * weight, 0, 0)
	rot(p, "LeftWrist", 0, 0, 20 * weight)
	rot(p, "Neck", -6 * weight, 0, 12 * math.sin(t * TAU * 0.9) * weight)
end

-- Doze: leaning back on the wall, arms folded, the head droops over DOZE_NOD_SECONDS and jerks up.
local function doze(p: Pose, w: Walk)
	rot(p, "Root", 7, 0, 0)
	move(p, "Root", 0, -0.1, 0.15)
	rot(p, "Waist", 5, 0, 0)
	foldArms(p, 1)
	local cycle = (w.clock % G.DOZE_NOD_SECONDS) / G.DOZE_NOD_SECONDS
	local droop = if cycle < 0.85 then smooth(cycle / 0.85) else 1 - smooth((cycle - 0.85) / 0.15)
	rot(p, "Neck", -(10 + 22 * droop), 0, 6 * droop)
	-- Snoring breath: deep and slow.
	local b = math.sin(w.clock * TAU / G.DOZE_NOD_SECONDS * 2)
	move(p, "Root", 0, 0.05 * b, 0)
	rot(p, "Waist", 2.5 * b, 0, 0)
	move(p, "HatAttach", 0, 0, 0.1 * droop)
	rot(p, "HatAttach", -10 * droop, 0, 0)
	p.look, p.follow, p.lens = 0, 1, false
	p.torchPitch = -60
end

-- Wake-startle: a crouch, a jump with arms flung out and the cap popping off his head, a landing.
local function wake(p: Pose, t: number)
	local A = G.ANTICIPATION
	local crouch = seg(t, 0, A) * (1 - seg(t, A, A + 0.06))
	local air = bump(t, A, A + 0.3)
	local land = bump(t, A + 0.28, A + 0.48)
	local fold = 1 - seg(t, 0, A)
	foldArms(p, fold)
	rot(p, "Neck", -30 * fold, 0, 0)
	-- Anticipation: down (knees bend, root drops).
	move(p, "Root", 0, -0.3 * crouch + 0.8 * air - 0.2 * land, 0)
	rot(p, "RightKnee", -30 * (crouch + land), 0, 0)
	rot(p, "LeftKnee", -30 * (crouch + land), 0, 0)
	rot(p, "RightHip", 20 * (crouch + land), 0, 0)
	rot(p, "LeftHip", 20 * (crouch + land), 0, 0)
	-- Main move: arms out, head back, eyes wide.
	rot(p, "RightShoulder", 30 * air, 0, 55 * air)
	rot(p, "LeftShoulder", 30 * air, 0, -55 * air)
	rot(p, "Root", 6 * air, 0, 0)
	rot(p, "Neck", 12 * air, 0, 0)
	-- The cap pops 0.5 studs and lands 0.1 s after he does.
	local cap = bump(t, A, A + 0.42)
	move(p, "HatAttach", 0, 0.55 * cap, 0)
	rot(p, "HatAttach", -20 * cap, 25 * cap, 0)
	p.look = seg(t, A, A + 0.2)
	p.follow = seg(t, A + 0.3, G.WAKE_SECONDS)
	p.lens = t >= A
	p.torchPitch = lerp(-60, 0, seg(t, A, A + 0.3))
end

-- "?" double-take: a glance, a look away, then the snap back with the cap popping; the body follows
-- DOUBLE_TAKE_FOLLOW later. Held: leaning in, torch raised, head tilted.
local function doubleTake(p: Pose, t: number, w: Walk)
	local A = G.ANTICIPATION
	local look
	if t < A then
		look = -0.15 * seg(t, 0, A) -- anticipation: a tiny look away
	elseif t < A + 0.08 then
		look = lerp(-0.15, 0.6, seg(t, A, A + 0.08)) -- glance
	elseif t < A + 0.3 then
		look = lerp(0.6, 0, smooth(seg(t, A + 0.08, A + 0.3))) -- "nah"
	elseif t < A + 0.4 then
		look = 0
	else
		look = backOut(seg(t, A + 0.4, A + 0.48)) -- the snap (2-3 frames) with overshoot
	end
	p.look = look
	p.follow = smooth(seg(t, G.DOUBLE_TAKE_FOLLOW, G.DOUBLE_TAKE_FOLLOW + 0.2))
	local snap = A + 0.4
	-- Squash before the snap, stretch on it (rigid root: a dip then a rise).
	move(p, "Root", 0, -0.1 * bump(t, snap - 0.08, snap) + 0.08 * bump(t, snap, snap + 0.2), 0)
	move(p, "HatAttach", 0, 0.25 * bump(t, snap, snap + 0.22), 0)
	local held = smooth(seg(t, snap, snap + 0.35))
	rot(p, "Root", -8 * held, 0, 0)
	rot(p, "Neck", 4 * held, 0, 12 * held)
	rot(p, "RightShoulder", 25 * held, 0, 0)
	p.torchPitch = -5 * held
	idleLayer(p, w, 1)
end

local scratchWalk: Walk = { phase = 0, amount = 0, run = 0, clock = 0 }

-- "!" then the funny sprint: wind back, point with the free hand, then run.
local function chase(p: Pose, t: number, w: Walk)
	local A = G.ANTICIPATION
	local wind = seg(t, 0, A) * (1 - seg(t, A, A + 0.08))
	local point = smooth(seg(t, A, A + 0.1)) * (1 - smooth(seg(t, G.POINT_SECONDS, G.POINT_SECONDS + 0.15)))
	rot(p, "Root", 10 * wind - 10 * point, 0, 0)
	move(p, "Root", 0, -0.15 * wind, 0.2 * wind)
	rot(p, "LeftShoulder", -25 * wind + 90 * point, 0, -10 * point)
	rot(p, "LeftElbow", -10 * point, 0, 0)
	rot(p, "RightShoulder", 40 * point, 0, 20 * point)
	rot(p, "Neck", 10 * point, 0, 0)
	move(p, "HatAttach", 0, 0.3 * bump(t, A, A + 0.25), 0)
	local runIn = smooth(seg(t, G.POINT_SECONDS, G.POINT_SECONDS + 0.2))
	local ww = scratchWalk
	ww.phase, ww.clock = w.phase, w.clock
	ww.run = clamp01(w.run) * runIn
	ww.amount = w.amount * math.max(runIn, 0.3)
	walkLayer(p, ww)
	-- Head pushed forward over the lean, torch flailing.
	rot(p, "Neck", 6 * runIn, 0, 0)
	rot(p, "FlashlightGrip", 0, 0, 15 * math.sin(w.phase * TAU) * runIn)
	p.look = 1
	p.follow = 1
	p.torchPitch = -15 * runIn
end

-- Catch: pull back, lunge with both hands out, hold the grab, then the "gotcha" point.
local function catch(p: Pose, t: number)
	local A = G.ANTICIPATION
	local back = seg(t, 0, A) * (1 - seg(t, A, A + 0.05))
	local lunge = smooth(seg(t, A, A + 0.15)) * (1 - smooth(seg(t, G.CATCH_SECONDS - 0.2, G.CATCH_SECONDS)))
	rot(p, "Root", 10 * back - 25 * lunge, 0, 0)
	move(p, "Root", 0, -0.12 * back - 0.25 * lunge, 0.35 * back - 0.9 * lunge)
	rot(p, "RightShoulder", -30 * back + 85 * lunge, 0, -8 * lunge)
	rot(p, "LeftShoulder", -30 * back + 85 * lunge, 0, 8 * lunge)
	rot(p, "RightElbow", 10 * lunge, 0, 0)
	rot(p, "LeftElbow", 10 * lunge, 0, 0)
	rot(p, "RightHip", 25 * lunge, 0, 0)
	rot(p, "RightKnee", -35 * lunge, 0, 0)
	rot(p, "LeftHip", -20 * lunge, 0, 0)
	rot(p, "Neck", 12 * lunge, 0, 0)
	move(p, "HatAttach", 0, 0.2 * bump(t, A, A + 0.2), 0)
	p.look = 1
	p.follow = 1
	p.torchPitch = -20 * lunge
end

-- WRONG ONE?!: freeze, lean toward the clone, then scratch his head, then a palms-up shrug.
local function wrongOne(p: Pose, t: number, w: Walk)
	local A = G.ANTICIPATION
	local freeze = seg(t, 0, A) * (1 - seg(t, A, A + 0.1))
	move(p, "Root", 0, -0.08 * freeze, 0)
	rot(p, "Root", -6 * smooth(seg(t, A, A + 0.3)), 0, 0)
	local sc = smooth(seg(t, A + 0.25, A + 0.45)) * (1 - smooth(seg(t, 1.35, 1.5)))
	scratch(p, t, sc)
	local W = G.WRONG_ONE_SECONDS
	local shrug = smooth(seg(t, 1.35, 1.5)) * (1 - smooth(seg(t, W - 0.12, W)))
	move(p, "RightShoulder", 0, 0.3 * shrug, 0)
	move(p, "LeftShoulder", 0, 0.3 * shrug, 0)
	rot(p, "RightShoulder", 25 * shrug, 0, 45 * shrug)
	rot(p, "LeftShoulder", 25 * shrug, 0, -45 * shrug)
	rot(p, "RightElbow", 80 * shrug, -30 * shrug, 0)
	rot(p, "LeftElbow", 80 * shrug, 30 * shrug, 0)
	rot(p, "Neck", 0, 0, 10 * shrug)
	rot(p, "Neck", 0, 15 * math.sin(t * TAU * 1.6) * shrug, 0)
	p.look = 1 - 0.5 * shrug
	p.follow = 1
	p.torchPitch = -25 * sc
	idleLayer(p, w, 1)
end

-- Lost sight: a short head scratch while he picks up his round again.
local function lostSight(p: Pose, t: number, w: Walk)
	local A = G.ANTICIPATION
	local sc = smooth(seg(t, A, A + 0.2)) * (1 - smooth(seg(t, G.SCRATCH_SECONDS - 0.25, G.SCRATCH_SECONDS)))
	move(p, "Root", 0, -0.06 * seg(t, 0, A) * (1 - seg(t, A, A + 0.06)), 0)
	walkLayer(p, w)
	scratch(p, t, sc)
	torchSway(p, w, 1)
	idleLayer(p, w, 1)
	p.look = 0.5
end

local function patrol(p: Pose, w: Walk)
	walkLayer(p, w)
	idleLayer(p, w, 1)
	torchSway(p, w, 1)
	p.look = 1
	p.follow = 1
end

-- Feet flat, legs under a leaning torso, the torch held at torchPitch (the wrist cancels the arm).
local function finish(p: Pose)
	local j = p.joints
	local root = j.Root[4]
	j.RightHip[4] -= root
	j.LeftHip[4] -= root
	j.RightAnkle[4] = -(root + j.RightHip[4] + j.RightKnee[4])
	j.LeftAnkle[4] = -(root + j.LeftHip[4] + j.LeftKnee[4])
	local arm = j.Root[4] + j.Waist[4] + j.RightShoulder[4] + j.RightElbow[4]
	j.RightWrist[4] = p.torchPitch * RAD - arm
end

-- Fills `out` for `beat` at `t` seconds since it started (out is cleared first).
function GusBeats.pose(beat: string, t: number, w: Walk, out: Pose)
	GusBeats.clear(out)
	if beat == B.Doze then
		doze(out, w)
	elseif beat == B.Wake then
		wake(out, t)
	elseif beat == B.DoubleTake then
		doubleTake(out, t, w)
	elseif beat == B.Chase then
		chase(out, t, w)
	elseif beat == B.Catch then
		catch(out, t)
	elseif beat == B.WrongOne then
		wrongOne(out, t, w)
	elseif beat == B.Scratch then
		lostSight(out, t, w)
	else
		patrol(out, w)
	end
	finish(out)
end

-- The head bubble for a beat: "zz" (doze), "!" (wake, the chase start, catch), "?" (double-take),
-- "huh?" (wrong one), or nil. Keys into Heist/Strings.
function GusBeats.bubble(beat: string, t: number): string?
	if beat == B.Doze then
		return "GUS_ZZ"
	elseif beat == B.Wake or beat == B.Catch then
		return "GUS_SPOTTED"
	elseif beat == B.Chase then
		return if t < G.BANG_SECONDS then "GUS_SPOTTED" else nil
	elseif beat == B.DoubleTake then
		return if t >= G.ANTICIPATION + 0.4 then "GUS_SUSPICIOUS" else nil
	elseif beat == B.WrongOne then
		return "GUS_HUH"
	end
	return nil
end

---------------------------------------------------------------------------
-- Look (C4)
---------------------------------------------------------------------------

-- Head yaw relative to the body for a target `rel` radians off the body's facing (wrapped to
-- [-pi, pi]). Clamped to +-LOOK_YAW_MAX; past LOOK_YAW_MAX + LOOK_LOSE the head gives up (0) and only
-- re-engages once the target is back inside LOOK_YAW_MAX. Returns (yaw, lost).
function GusBeats.look(rel: number, lost: boolean): (number, boolean)
	local max = G.LOOK_YAW_MAX * RAD
	local a = math.abs(rel)
	if lost then
		if a > max then
			return 0, true
		end
		return rel, false
	end
	if a > max + G.LOOK_LOSE * RAD then
		return 0, true
	end
	return math.clamp(rel, -max, max), false
end

function GusBeats.lookPitch(pitch: number): number
	local max = G.LOOK_PITCH_MAX * RAD
	return math.clamp(pitch, -max, max)
end

function GusBeats.angleDelta(a: number, b: number): number
	local d = (b - a + math.pi) % TAU - math.pi
	if d <= -math.pi then
		d += TAU
	end
	return d
end

-- A short ring of (time, yaw) samples: the body yaw HEAD_LEAD behind the head off patrol.
export type Delay = { t: { number }, v: { number }, n: number, head: number, count: number }

function GusBeats.newDelay(n: number): Delay
	return { t = table.create(n, 0), v = table.create(n, 0), n = n, head = 0, count = 0 }
end

function GusBeats.delayReset(d: Delay)
	d.head, d.count = 0, 0
end

function GusBeats.delayPush(d: Delay, t: number, v: number)
	d.head = d.head % d.n + 1
	d.t[d.head] = t
	d.v[d.head] = v
	d.count = math.min(d.count + 1, d.n)
end

-- The yaw at time t (shortest-arc between the two samples around it; the oldest before them all).
function GusBeats.delaySample(d: Delay, t: number): number?
	if d.count == 0 then
		return nil
	end
	local i = d.head
	local newerT, newerV = d.t[i], d.v[i]
	if t >= newerT then
		return newerV
	end
	for _ = 2, d.count do
		i = (i - 2) % d.n + 1
		local ot, ov = d.t[i], d.v[i]
		if t >= ot then
			local f = if newerT > ot then (t - ot) / (newerT - ot) else 1
			return (ov + GusBeats.angleDelta(ov, newerV) * f) % TAU
		end
		newerT, newerV = ot, ov
	end
	return newerV
end

---------------------------------------------------------------------------
-- Intention (A5): boot prints, the turn flicker, the clipped cone
---------------------------------------------------------------------------

-- Distance walked along the route by patrol time t, unrolled across periods (so it only grows).
function GusBeats.routeDistance(route: any, t: number): number
	local period = route.period
	if period <= 0 then
		return 0
	end
	local loops = math.floor(t / period)
	local u = t - loops * period
	local total, d = 0, 0
	local found = false
	for _, leg in route.legs do
		if not found then
			if u < leg.tArrive then
				local span = leg.tArrive - leg.tStart
				local f = if span > 0 then clamp01((u - leg.tStart) / span) else 1
				d = total + leg.len * f
				found = true
			elseif u < leg.tEnd then
				d = total + leg.len
				found = true
			end
		end
		total += leg.len
	end
	if not found then
		d = total
	end
	return loops * total + d
end

local function routeLength(route: any): number
	local total = 0
	for _, leg in route.legs do
		total += leg.len
	end
	return total
end

-- The point (x, z) and walking yaw at unrolled distance d along the route.
function GusBeats.routePoint(route: any, d: number): (number, number, number)
	local total = routeLength(route)
	local legs = route.legs
	if total <= EPS then
		local l = legs[1]
		return l.x0, l.z0, l.yawWalk
	end
	local r = d - math.floor(d / total) * total
	for _, leg in legs do
		if leg.len > EPS then
			if r <= leg.len then
				local f = r / leg.len
				return leg.x0 + (leg.x1 - leg.x0) * f, leg.z0 + (leg.z1 - leg.z0) * f, leg.yawWalk
			end
			r -= leg.len
		end
	end
	local l = legs[#legs]
	return l.x1, l.z1, l.yawWalk
end

export type Prints = {
	x: { number },
	z: { number },
	yaw: { number },
	side: { number }, -- +1 right boot, -1 left boot
	fade: { number }, -- 0 nearest .. 1 farthest (at the horizon)
	k: { number }, -- print index along the route (stable while the print stays)
}

function GusBeats.newPrints(): Prints
	local n = G.PRINT_MAX
	return {
		x = table.create(n, 0),
		z = table.create(n, 0),
		yaw = table.create(n, 0),
		side = table.create(n, 0),
		fade = table.create(n, 0),
		k = table.create(n, 0),
	}
end

-- Gus's next `horizon` seconds of patrol from patrol time t: one print every `stride` studs along the
-- route, at fixed route distances (a print stays put as he walks toward it), alternating boots.
-- Returns how many prints were written (0 while he will stand for the whole horizon).
function GusBeats.bootPrints(
	route: any,
	t: number,
	out: Prints,
	horizon: number?,
	stride: number?,
	maxPrints: number?
): number
	if route == nil or route.period <= 0 then
		return 0
	end
	local h = horizon or G.PRINT_HORIZON
	local step = stride or G.PRINT_STRIDE
	local cap = maxPrints or G.PRINT_MAX
	local d0 = GusBeats.routeDistance(route, t)
	local d1 = GusBeats.routeDistance(route, t + h)
	if d1 - d0 < step * 0.5 then
		return 0
	end
	local n = 0
	local k = math.floor(d0 / step) + 1
	while k * step <= d1 + EPS and n < cap do
		local d = k * step
		local x, z, yaw = GusBeats.routePoint(route, d)
		local side = if k % 2 == 0 then -1 else 1
		n += 1
		-- Right of a yaw-a walker is (cos a, -sin a) in (x, z).
		out.x[n] = x + math.cos(yaw) * G.PRINT_SPREAD * side
		out.z[n] = z - math.sin(yaw) * G.PRINT_SPREAD * side
		out.yaw[n] = yaw
		out.side[n] = side
		out.fade[n] = clamp01((d - d0) / (d1 - d0))
		out.k[n] = k
		k += 1
	end
	return n
end

-- True while Gus stands still on patrol and turns more than FLICKER_TURN_DEG within the next
-- FLICKER_LEAD seconds (the cone flickers to say "he is about to turn").
function GusBeats.turnSoon(route: any, t: number, lead: number?): boolean
	if route == nil or route.period <= 0 then
		return false
	end
	local l = lead or G.FLICKER_LEAD
	local x0, z0, y0 = Guards.patrol(route, t)
	local x1, z1, y1 = Guards.patrol(route, t + 0.05)
	if math.abs(GusBeats.angleDelta(y0, y1)) > 0.5 * RAD or (x1 - x0) ^ 2 + (z1 - z0) ^ 2 > 1e-4 then
		return false -- already turning or walking (a walking corner is led by the head and the prints)
	end
	local limit = G.FLICKER_TURN_DEG * RAD
	for i = 1, 4 do
		local _, _, y = Guards.patrol(route, t + l * i / 4)
		if math.abs(GusBeats.angleDelta(y0, y)) > limit then
			return true
		end
	end
	return false
end

-- 1 on the lit beats of the flicker, 0 on the dim ones.
function GusBeats.flicker(clock: number): number
	return if (clock * G.FLICKER_HZ * 2) % 2 < 1 then 1 else 0
end

-- Wedge k of the cone spans rays k and k+1: drawn only to the shorter of the two, so no wedge spans a
-- hit/miss boundary and paints past a wall into the next room (docs/audit/LEVELS.md G10, P1-5).
function GusBeats.clipFan(rays: { number }, n: number, out: { number })
	for k = 1, n - 1 do
		out[k] = math.min(rays[k], rays[k + 1])
	end
end

return table.freeze(GusBeats)
