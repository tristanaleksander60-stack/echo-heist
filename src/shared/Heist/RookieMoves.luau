--!strict
-- Heist/RookieMoves: the Rookie's locomotion set as joint poses over time (REVIEW_STEAM_PLUS #6). Pure: no engine
-- calls; tools/rookie_clips.luau bakes it into R15 KeyframeSequences, the unit spec checks the feet, and the render
-- tool (tools/blender/rookie_anim.py) poses the kit FBX from the same numbers.
--
-- Clips (Config.Rookie.ANIM): idle (breathing, a smug weight shift), look (the idle variant: a suspicious look left
-- and right), walk (a sneaky-but-cocky caper: crouched, arms swinging wide, a bounce, chest turned against the hips),
-- run (the funny sprint: big pumps, lean, high knees and a heel kick), jump, fall, land.
--
-- Built for his proportions (RookieData pivots: hip 1.48, knee 0.98, ankle 0.5, a 1.3-stud boot): legs are 2-bone
-- IK on feet that are PLANTED while they are on the floor. The walk and run cover WALK_BASE / RUN_BASE studs per
-- second at rate 1 (the R15 Animate's speed maths), so a stance foot moves back under the body at exactly that
-- speed: flat first, then rolling onto its toe (the toe stays put), never sliding. The pelvis drops where a reach
-- needs it (the bounce), never further than MAX_REACH.
--
-- A pose is { [part]: { rx, ry, rz, px, py, pz } }: the joint's Transform (Pose.CFrame) for the joint whose child
-- part is `part`, as CFrame.fromEulerAnglesYXZ(rx, ry, rz) + (px, py, pz). The Rookie's joints have no rotation
-- in C0 / C1, so the axes are the model's (facing -Z): +rx swings a limb forward (tips the head up, toes up), +ry
-- turns left, +rz tilts toward +X (the right side).

local Config = require("../Config")
local RookieData = require("./RookieData") :: any

local A = Config.Rookie.ANIM
local TAU = 2 * math.pi

local RookieMoves = {}

export type Pose = { [string]: { number } }
export type Vec = { number }
export type Mat = { number } -- 3x3 row-major

RookieMoves.WALK_BASE = A.SCALE * A.WALK_NORM / A.ROOT_MOTION -- 6.4 studs/s
RookieMoves.RUN_BASE = A.SCALE * A.RUN_NORM / A.ROOT_MOTION -- 12.8
RookieMoves.WALK_STRIDE = RookieMoves.WALK_BASE * A.CYCLE -- studs per cycle at any rate
RookieMoves.RUN_STRIDE = RookieMoves.RUN_BASE * A.CYCLE

-- name -> length (s), looped, priority (Enum.AnimationPriority name)
RookieMoves.CLIPS = table.freeze({
	idle = { length = A.IDLE.length, looped = true, priority = "Idle", slow = true },
	look = { length = A.LOOK.length, looped = true, priority = "Idle", slow = true },
	walk = { length = A.CYCLE, looped = true, priority = "Movement" },
	run = { length = A.CYCLE, looped = true, priority = "Movement" },
	jump = { length = A.JUMP.length, looped = false, priority = "Movement" },
	fall = { length = A.FALL.length, looped = true, priority = "Movement" },
	land = { length = A.LAND.length, looped = false, priority = "Action" },
})
RookieMoves.ORDER = table.freeze({ "idle", "look", "walk", "run", "jump", "fall", "land" })

-- The part tree (child -> parent) and the joint pivots (rest, model space).
RookieMoves.PARENT = {} :: { [string]: string }
RookieMoves.PIVOT = {} :: { [string]: Vec }
for _, b in RookieData.body do
	RookieMoves.PARENT[b.part] = b.parent or "HumanoidRootPart"
	RookieMoves.PIVOT[b.part] = { b.origin[1], b.origin[2], b.origin[3] }
end
local PIV = RookieMoves.PIVOT

---------------------------------------------------------------------------
-- small vector / matrix maths
---------------------------------------------------------------------------

local function rotX(a: number): Mat
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(a: number): Mat
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(a: number): Mat
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
local function mul(a: Mat, b: Mat): Mat
	local o = table.create(9, 0)
	for r = 0, 2 do
		for c = 1, 3 do
			o[r * 3 + c] = a[r * 3 + 1] * b[c] + a[r * 3 + 2] * b[3 + c] + a[r * 3 + 3] * b[6 + c]
		end
	end
	return o
end
local function app(m: Mat, v: Vec): Vec
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end
local function appT(m: Mat, v: Vec): Vec -- transpose (inverse of a rotation)
	return {
		m[1] * v[1] + m[4] * v[2] + m[7] * v[3],
		m[2] * v[1] + m[5] * v[2] + m[8] * v[3],
		m[3] * v[1] + m[6] * v[2] + m[9] * v[3],
	}
end
local function add(a: Vec, b: Vec): Vec
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end
local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

-- CFrame.fromEulerAnglesYXZ(rx, ry, rz) = Ry * Rx * Rz
function RookieMoves.euler(rx: number, ry: number, rz: number): Mat
	return mul(rotY(ry), mul(rotX(rx), rotZ(rz)))
end
local euler = RookieMoves.euler

-- The (rx, ry, rz) of a rotation for CFrame.fromEulerAnglesYXZ.
function RookieMoves.toEuler(m: Mat): (number, number, number)
	return math.asin(math.clamp(-m[6], -1, 1)), math.atan2(m[3], m[9]), math.atan2(m[4], m[5])
end

local function transpose(m: Mat): Mat
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end

local function smooth(u: number): number
	local x = math.clamp(u, 0, 1)
	return x * x * (3 - 2 * x)
end
local function lerp(a: number, b: number, u: number): number
	return a + (b - a) * u
end

---------------------------------------------------------------------------
-- forward kinematics: part -> (M, t) with world = M * rest + t
---------------------------------------------------------------------------

export type Xf = { m: Mat, t: Vec }
local ORDER_FK = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
}
RookieMoves.PARTS = table.freeze(ORDER_FK)

-- D_child = D_parent * (pivot * T * pivot^-1): every part's motion from the rest pose (the root part fixed).
function RookieMoves.fk(pose: Pose): { [string]: Xf }
	local out: { [string]: Xf } = { HumanoidRootPart = { m = rotX(0), t = { 0, 0, 0 } } }
	for _, part in ORDER_FK do
		local j = pose[part] or { 0, 0, 0, 0, 0, 0 }
		local r = euler(j[1], j[2], j[3])
		local at = PIV[part]
		local lt = add(sub(at, app(r, at)), { j[4] or 0, j[5] or 0, j[6] or 0 })
		local p = out[RookieMoves.PARENT[part]]
		out[part] = { m = mul(p.m, r), t = add(app(p.m, lt), p.t) }
	end
	return out
end

function RookieMoves.point(x: Xf, rest: Vec): Vec
	return add(app(x.m, rest), x.t)
end

---------------------------------------------------------------------------
-- legs: 2-bone IK in the pelvis frame
---------------------------------------------------------------------------

local function legLengths(side: string): (number, number)
	local h, k, a = PIV[side .. "UpperLeg"], PIV[side .. "LowerLeg"], PIV[side .. "Foot"]
	return math.abs(h[2] - k[2]), math.abs(k[2] - a[2])
end

-- The ankle target `ankle` (model space) and the boot's pitch `pitch` (world, + = toes up) -> hip, knee, ankle
-- angles, given the pelvis rotation `pm` and translation `pt` (Root joint). Returns whether it was in reach.
-- `yaw`: the pelvis turn, cancelled at the hip so the knee and boot keep pointing down the path.
local function solveOnce(
	pose: Pose,
	side: string,
	pm: Mat,
	pt: Vec,
	ankle: Vec,
	pitch: number,
	pelvisPitch: number,
	yaw: number
)
	local l1, l2 = legLengths(side)
	local root = PIV.LowerTorso
	-- into the pelvis's rest frame
	local a = add(appT(pm, sub(sub(ankle, pt), root)), root)
	local hip = PIV[side .. "UpperLeg"]
	local restX = PIV[side .. "Foot"][1]
	local d = app(rotY(yaw), sub(a, hip))
	local dy, dz, ex = d[2], d[3], d[1] + hip[1] - restX
	local reach = math.min(A.MAX_REACH, l1 + l2 - 1e-3)
	local full = math.sqrt(dy * dy + dz * dz + ex * ex)
	local inReach = full <= reach + 1e-6
	local r = math.clamp(full, math.abs(l1 - l2) + 1e-3, reach)
	local roll = math.asin(math.clamp(ex / math.max(full, 0.3), -0.5, 0.5))
	local thd = math.atan2(-dz, -dy)
	local alpha = math.acos(math.clamp((l1 * l1 + r * r - l2 * l2) / (2 * l1 * r), -1, 1))
	local beta = math.acos(math.clamp((l2 * l2 + r * r - l1 * l1) / (2 * l2 * r), -1, 1))
	local th1 = thd + alpha
	local th2 = thd - beta
	pose[side .. "UpperLeg"] = { th1, -yaw, roll, 0, 0, 0 }
	pose[side .. "LowerLeg"] = { th2 - th1, 0, 0, 0, 0, 0 }
	pose[side .. "Foot"] = { pitch - pelvisPitch - th2, 0, -roll, 0, 0, 0 }
	return inReach
end

-- Solves, then nudges the target by the forward-kinematics error a few times (the joints' small side offsets and
-- the pelvis turn), so a planted ankle lands where it was asked to within a hundredth of a stud.
local function solveLeg(
	pose: Pose,
	side: string,
	pm: Mat,
	pt: Vec,
	ankle: Vec,
	pitch: number,
	pelvisPitch: number,
	yaw: number
)
	local target = { ankle[1], ankle[2], ankle[3] }
	local ok = true
	for _ = 1, 6 do
		ok = solveOnce(pose, side, pm, pt, target, pitch, pelvisPitch, yaw)
		local at = RookieMoves.point(RookieMoves.fk(pose)[side .. "Foot"], PIV[side .. "Foot"])
		local e = sub(ankle, at)
		if e[1] * e[1] + e[2] * e[2] + e[3] * e[3] < 1e-6 then
			break
		end
		target = add(target, e)
	end
	-- the boot square to the path at its pitch, whatever the pelvis and hip did above it
	local shin = RookieMoves.fk(pose)[side .. "LowerLeg"].m
	local rx, ry, rz = RookieMoves.toEuler(mul(transpose(shin), rotX(pitch)))
	pose[side .. "Foot"] = { rx, ry, rz, 0, 0, 0 }
	return ok
end

-- How high the ankle must be so no part of the sole goes under the floor at a boot pitch.
function RookieMoves.soleLift(pitch: number): number
	local toe, heel = A.FOOT_TOE, A.FOOT_HEEL
	local function low(p: Vec): number
		return -(p[2] * math.cos(pitch) - p[3] * math.sin(pitch))
	end
	return math.max(low(toe), low(heel))
end

---------------------------------------------------------------------------
-- gait: where each foot is, from the cycle phase
---------------------------------------------------------------------------

export type Foot = { pos: Vec, pitch: number, planted: boolean, contact: Vec? }

-- Foot of a leg at cycle phase q (0 = it lands) for a gait spec G with stride S (studs per cycle). Body frame:
-- the body is still, the floor moves back (+Z) at S per cycle. x: the foot's side.
function RookieMoves.foot(G: any, S: number, q: number, x: number): Foot
	local ankleY = PIV.RightFoot[2]
	local toe, d = A.FOOT_TOE, G.duty
	local zTd = -G.front
	if q < d then
		local zg = zTd + S * q
		if q <= G.peelAt then
			local pos = { x, ankleY, zg }
			return { pos = pos, pitch = 0, planted = true, contact = { x, 0, zg } }
		end
		-- the toe is planted where it was when the roll began, moving back with the floor
		local zToe = zTd + S * G.peelAt + toe[3] + S * (q - G.peelAt)
		local phi = -G.peel * smooth((q - G.peelAt) / (d - G.peelAt))
		local c, s = math.cos(phi), math.sin(phi)
		-- toe -> ankle at rest is (0, a, b) = (0, 0.5, 0.9); turned by rotX(phi): y = a cos - b sin, z = a sin + b cos
		local ra, rb = -toe[2], -toe[3]
		local pos = { x, ra * c - rb * s, zToe + ra * s + rb * c }
		return { pos = pos, pitch = phi, planted = true, contact = { x, 0, zToe } }
	end
	-- swing: from lift-off back to the next landing
	local lift = RookieMoves.foot(G, S, d - 1e-6, x)
	local u = (q - d) / (1 - d)
	local e = smooth(u)
	local z = lerp(lift.pos[3], zTd, e)
	if G.kick then
		z += G.kick * math.sin(math.pi * math.min(u * 1.6, 1)) * (1 - u)
	end
	local pitch = lift.pitch * (1 - e) + G.swingToe * math.sin(math.pi * u) * u
	local base = lerp(lift.pos[2], ankleY, e)
	local y = math.max(base + G.lift * math.sin(math.pi * u ^ 0.8), RookieMoves.soleLift(pitch))
	return { pos = { x, y, z }, pitch = pitch, planted = false }
end

-- Lowers the pelvis (root y) until every planted leg is in reach.
local function fitRoot(pm: Mat, pt: Vec, feet: { [string]: Foot }): Vec
	local root = PIV.LowerTorso
	local t = { pt[1], pt[2], pt[3] }
	for _ = 1, 6 do
		local worst = 0
		for side, f in feet do
			if f.planted then
				local hipRest = PIV[side .. "UpperLeg"]
				local hip = add(add(app(pm, sub(hipRest, root)), root), t)
				local d = sub(f.pos, hip)
				local horiz = d[3] * d[3] + (d[1] * 0.3) ^ 2
				local maxV = math.sqrt(math.max(A.MAX_REACH * A.MAX_REACH - horiz, 0))
				worst = math.max(worst, -d[2] - maxV)
			end
		end
		if worst <= 1e-5 then
			break
		end
		t[2] -= worst
	end
	return t
end

local function arms(pose: Pose, swingR: number, swingL: number, out: number, elbowR: number, elbowL: number)
	pose.RightUpperArm = { swingR, 0, out, 0, 0, 0 }
	pose.LeftUpperArm = { swingL, 0, -out, 0, 0, 0 }
	pose.RightLowerArm = { elbowR, 0, 0, 0, 0, 0 }
	pose.LeftLowerArm = { elbowL, 0, 0, 0, 0, 0 }
	pose.RightHand = { -0.1, 0, 0, 0, 0, 0 }
	pose.LeftHand = { -0.1, 0, 0, 0, 0, 0 }
end

-- walk / run at phase p (0..1). The right foot lands at p = 0, the left at 0.5.
local function gait(G: any, S: number, p: number, running: boolean): (Pose, { [string]: Foot })
	local pose: Pose = {}
	local d = G.duty
	local cr = math.cos(TAU * p) -- +1 when the right foot is forward (landing)
	local yaw = G.yaw * cr
	local mid = p - d / 2
	local sway = (G.sway or 0) * math.cos(TAU * mid)
	local roll = (G.roll or 0) * math.cos(TAU * mid)
	local y: number
	if running then
		y = -G.drop - G.bob * math.cos(2 * TAU * mid) -- low mid-stance, high in the flight
	else
		y = -G.drop - G.bob * math.cos(2 * TAU * p) -- low as a foot lands, up over it (the bounce)
	end
	local pelvisPitch = -G.lean * 0.4
	local pm = euler(pelvisPitch, yaw, roll)
	local feet = {
		Right = RookieMoves.foot(G, S, p % 1, PIV.RightFoot[1]),
		Left = RookieMoves.foot(G, S, (p + 0.5) % 1, PIV.LeftFoot[1]),
	}
	local pt = fitRoot(pm, { sway, y, 0 }, feet)
	pose.LowerTorso = { pelvisPitch, yaw, roll, pt[1], pt[2], pt[3] }
	for side, f in feet do
		solveLeg(pose, side, pm, pt, f.pos, f.pitch, pelvisPitch, yaw)
	end
	local chestPitch = -G.lean * 0.6 + (if running then 0.04 * math.cos(2 * TAU * mid) else 0)
	pose.UpperTorso = { chestPitch, G.chestYaw * cr * 0.5 - yaw * 0.2, -roll * 0.5, 0, 0, 0 }
	local chestYaw = yaw + pose.UpperTorso[2]
	local nod = (if running then 0.05 else 0.04) * math.cos(2 * TAU * p)
	pose.Head = {
		G.headUp - chestPitch - pelvisPitch - G.lean * 0.1 + nod,
		-chestYaw * 0.8,
		(G.headTilt or 0) + roll * -0.6,
		0,
		0,
		0,
	}
	local sw = G.armSwing * cr -- right arm back when the right foot is forward
	local eR = G.elbow + G.elbowSwing * math.max(0, -cr)
	local eL = G.elbow + G.elbowSwing * math.max(0, cr)
	arms(pose, -sw, sw, G.armOut, eR, eL)
	if running then
		-- pumps: the hands come up toward the chin on the forward swing
		pose.RightUpperArm[3] = G.armOut + 0.1 * math.max(0, -cr)
		pose.LeftUpperArm[3] = -G.armOut - 0.1 * math.max(0, cr)
	end
	return pose, feet
end

-- Planted feet for standing clips, with the pelvis offset (sx, sy) and turn.
local STANCE = {
	Right = { PIV.RightFoot[1] + 0.04, PIV.RightFoot[2], 0.1 },
	Left = { PIV.LeftFoot[1] - 0.02, PIV.LeftFoot[2], -0.14 }, -- the smug stance: left foot a little forward
}
local function stand(pose: Pose, pitch: number, yaw: number, roll: number, sx: number, sy: number)
	local pm = euler(pitch, yaw, roll)
	local pt = { sx, sy, 0 }
	local feet = {
		Right = { pos = STANCE.Right, pitch = 0, planted = true },
		Left = { pos = STANCE.Left, pitch = 0, planted = true },
	}
	pt = fitRoot(pm, pt, feet :: any)
	pose.LowerTorso = { pitch, yaw, roll, pt[1], pt[2], pt[3] }
	for side, f in feet do
		solveLeg(pose, side, pm, pt, f.pos, 0, pitch, yaw)
	end
end

local function idlePose(t: number): Pose
	local I = A.IDLE
	local pose: Pose = {}
	local u = t / I.length
	local breath = math.sin(2 * TAU * u) -- two breaths per loop
	local shift = math.sin(TAU * u) -- one slow weight shift
	stand(pose, 0, 0.05 * shift, I.roll * shift, I.sway * shift, -0.035 + 0.012 * breath)
	pose.UpperTorso = { I.breath * breath - 0.02, -0.04 * shift, -I.roll * shift * 0.6, 0, 0, 0 }
	pose.Head = { I.headUp - I.breath * breath * 0.5, 0.03 * shift, I.headTilt - 0.02 * shift, 0, 0, 0 }
	arms(pose, 0.05 + 0.03 * shift, 0.05 - 0.03 * shift, 0.12 + 0.02 * breath, 0.22, 0.22)
	return pose
end

local function lookPose(t: number): Pose
	local Lk = A.LOOK
	local pose = idlePose(t * A.IDLE.length / Lk.length)
	-- left at 0.5-0.9 s, hold, right at 2.0-2.5 s, hold, back by 3.5 s
	local yaw = Lk.yaw * smooth((t - 0.5) / 0.4)
		- 2 * Lk.yaw * smooth((t - 2.0) / 0.5)
		+ Lk.yaw * smooth((t - 3.0) / 0.5)
	pose.Head[2] += yaw * (1 - Lk.chest)
	pose.Head[1] -= 0.06 * math.abs(yaw) / Lk.yaw -- a suspicious squint down the line
	pose.UpperTorso[2] += yaw * Lk.chest
	return pose
end

local function jumpPose(t: number): Pose
	local J = A.JUMP
	local u = smooth(t / J.tuck)
	local pose: Pose = {}
	pose.LowerTorso = { -0.05 * u, 0, 0, 0, 0.1 * u, 0 }
	pose.UpperTorso = { lerp(0.12, -0.05, u), 0, 0, 0, 0, 0 }
	pose.Head = { lerp(0.15, 0.05, u), 0, 0.04, 0, 0, 0 }
	for _, s in { "Right", "Left" } do
		local k = if s == "Right" then 1 else -1
		local fwd = if s == "Right" then 1 else 0.7 -- one knee higher: a cartoon leap
		pose[s .. "UpperLeg"] = { lerp(0, 1.1 * fwd, u), 0, 0.08 * k, 0, 0, 0 }
		pose[s .. "LowerLeg"] = { lerp(-0.1, -1.7, u), 0, 0, 0, 0, 0 }
		pose[s .. "Foot"] = { lerp(-0.5, 0.2, u), 0, 0, 0, 0, 0 }
	end
	arms(pose, lerp(2.2, 2.7, u), lerp(2.0, 2.5, u), lerp(0.25, 0.55, u), 0.35, 0.35)
	return pose
end

local function fallPose(t: number): Pose
	local F = A.FALL
	local w = TAU * t / F.length
	local pose: Pose = {}
	pose.LowerTorso = { 0.08, 0, 0.03 * math.sin(w), 0, 0, 0 }
	pose.UpperTorso = { 0.1, 0.06 * math.sin(w), 0, 0, 0, 0 }
	pose.Head = { 0.18, 0, 0.05 * math.sin(w), 0, 0, 0 }
	for i, s in { "Right", "Left" } do
		local ph = w + (i - 1) * math.pi
		pose[s .. "UpperLeg"] = { 0.45 + F.flail * math.sin(ph), 0, 0, 0, 0, 0 }
		pose[s .. "LowerLeg"] = { -0.9 - F.flail * math.cos(ph), 0, 0, 0, 0, 0 }
		pose[s .. "Foot"] = { 0.25, 0, 0, 0, 0, 0 }
	end
	-- arms windmill: up and out, circling
	arms(
		pose,
		2.1 + F.flail * math.sin(w),
		2.1 + F.flail * math.sin(w + math.pi),
		0.75 + 0.2 * math.cos(w),
		0.5 + 0.3 * math.cos(w),
		0.5 + 0.3 * math.cos(w + math.pi)
	)
	return pose
end

local function landPose(t: number): Pose
	local Ld = A.LAND
	-- squash at 0.08 s, a small overshoot up at 0.24 s, settled by the end
	local down: number
	if t < 0.08 then
		down = smooth(t / 0.08)
	elseif t < 0.24 then
		down = 1 - 1.12 * smooth((t - 0.08) / 0.16)
	else
		down = -0.12 * (1 - smooth((t - 0.24) / (Ld.length - 0.24)))
	end
	local pose: Pose = {}
	stand(pose, -0.18 * down, 0, 0, 0, -0.035 - Ld.squash * down)
	pose.UpperTorso = { -0.22 * down, 0, 0, 0, 0, 0 }
	pose.Head = { 0.3 * down + 0.06, 0, 0.05, 0, 0, 0 }
	arms(
		pose,
		0.25 + 0.5 * down,
		0.25 + 0.5 * down,
		0.15 + 0.6 * math.max(down, 0),
		0.25 + 0.3 * down,
		0.25 + 0.3 * down
	)
	return pose
end

-- The pose of a clip at t seconds (looped clips wrap).
function RookieMoves.sample(clip: string, t: number): Pose
	local spec = RookieMoves.CLIPS[clip]
	assert(spec, "no Rookie clip " .. clip)
	local tt = if spec.looped then t % spec.length else math.clamp(t, 0, spec.length)
	if clip == "walk" then
		return (gait(A.WALK, RookieMoves.WALK_STRIDE, tt / spec.length, false))
	elseif clip == "run" then
		return (gait(A.RUN, RookieMoves.RUN_STRIDE, tt / spec.length, true))
	elseif clip == "idle" then
		return idlePose(tt)
	elseif clip == "look" then
		return lookPose(tt)
	elseif clip == "jump" then
		return jumpPose(tt)
	elseif clip == "fall" then
		return fallPose(tt)
	end
	return landPose(tt)
end

-- walk / run feet at a phase, for the spec (planted flags and contact points).
function RookieMoves.feet(clip: string, p: number): { [string]: Foot }
	local G = if clip == "run" then A.RUN else A.WALK
	local S = if clip == "run" then RookieMoves.RUN_STRIDE else RookieMoves.WALK_STRIDE
	local _, feet = gait(G, S, p % 1, clip == "run")
	return feet
end

-- The boot's sole points (toe, heel; model space) in a pose.
function RookieMoves.sole(pose: Pose, side: string): (Vec, Vec)
	local x = RookieMoves.fk(pose)[side .. "Foot"]
	local ank = PIV[side .. "Foot"]
	return RookieMoves.point(x, add(ank, A.FOOT_TOE)), RookieMoves.point(x, add(ank, A.FOOT_HEEL))
end

-- The baked key times of a clip (KEYS_PER_SECOND, the last key exactly at the length).
function RookieMoves.keyTimes(clip: string): { number }
	local spec = RookieMoves.CLIPS[clip]
	local kps = if spec.slow then A.KEYS_PER_SECOND_SLOW else A.KEYS_PER_SECOND
	local n = math.max(2, math.ceil(spec.length * kps))
	local out = table.create(n + 1, 0)
	for i = 0, n do
		out[i + 1] = spec.length * i / n
	end
	return out
end

return table.freeze(RookieMoves)
