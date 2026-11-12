--!strict
-- Heist/ClonePose: the custom clone poses the catalog animations do not have (PLAN_STEAM_PLUS §4.4
-- A3, §5 "First clone" and "Carrying loot"; FEEDBACK_TABLE "Busted (clone)"). Each pose is a few
-- joint rotations, keyed by the joint's child part (R15 names), as Euler angles (x, y, z) in radians
-- for CFrame.fromEulerAnglesYXZ: +x swings a limb forward (and tips the head up), +y turns left,
-- +z tilts toward +X (a left arm in, a right arm out). The view writes them over the animator
-- (Heist/Rigs.writePose, absolute Transform in PreSimulation); mannequins use the arm and head
-- angles on their rigid limbs.
--   "carry"    both arms forward, forearms up, the loot between the hands, bobbing;
--   "on-plate" planted: a slow weight shift at the waist, and one glance back at you (head look-at
--              with elliptical limits, once per stay on the plate);
--   "stuck"    taps the wall ahead with the right hand, then shrugs; again every STUCK_CYCLE;
--   "busted"   hands up, then 3 two-frame glitch slices (a sideways root offset).
-- Pure (no engine calls): Lune unit specs run it (tests/unit/HeistCloneState.spec.luau).

local Config = require("../Config")

local C = Config.Clone
local TAU = 2 * math.pi

local ClonePose = {}

-- Joints a pose may set (the child part of each joint).
ClonePose.JOINTS =
	table.freeze({ "Head", "UpperTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" })

-- States that have a custom pose.
ClonePose.CUSTOM = table.freeze({ carry = true, ["on-plate"] = true, stuck = true, busted = true })

export type Pose = {
	joints: { [string]: { number } }, -- set joints only (the rest belong to the animator)
	glitchX: number, -- studs: sideways root offset of a glitch slice
	bob: number, -- studs: carried-loot bob
	busy: boolean, -- false when nothing is set
}

function ClonePose.new(): Pose
	return { joints = {}, glitchX = 0, bob = 0, busy = false }
end

local function smooth(a: number): number
	local u = math.clamp(a, 0, 1)
	return u * u * (3 - 2 * u)
end

-- 0 -> 1 over [t0, t0 + rise], holds, 1 -> 0 over [t1, t1 + fall].
local function envelope(t: number, t0: number, rise: number, t1: number, fall: number): number
	if t < t0 or t > t1 + fall then
		return 0
	end
	if t < t0 + rise then
		return smooth((t - t0) / rise)
	end
	if t <= t1 then
		return 1
	end
	return 1 - smooth((t - t1) / fall)
end
ClonePose.envelope = envelope

local function set(p: Pose, name: string, x: number, y: number, z: number, w: number)
	local j = p.joints[name]
	if j then
		j[1], j[2], j[3] = x * w, y * w, z * w
	else
		p.joints[name] = { x * w, y * w, z * w }
	end
end

-- Head look-at angles toward a target: (dx, dy, dz) from the head to the target in world/level
-- space, the clone's yaw (Roblox: forward = (-sin yaw, -cos yaw)). Returns yaw (+ = left), pitch
-- (+ = up), clamped to the ellipse LOOK_YAW x LOOK_PITCH, and false when the target is so far
-- behind (30 degrees past the yaw limit) that the clone does not look at all.
function ClonePose.look(dx: number, dy: number, dz: number, yaw: number): (number, number, boolean)
	local s, c = math.sin(yaw), math.cos(yaw)
	local fwd = -dx * s - dz * c
	local right = dx * c - dz * s
	local yawTo = math.atan2(-right, fwd)
	local pitchTo = math.atan2(dy, math.sqrt(fwd * fwd + right * right))
	if math.abs(yawTo) > C.LOOK_YAW + math.rad(30) then
		return 0, 0, false
	end
	local r = (yawTo / C.LOOK_YAW) ^ 2 + (pitchTo / C.LOOK_PITCH) ^ 2
	if r > 1 then
		local k = 1 / math.sqrt(r)
		yawTo, pitchTo = yawTo * k, pitchTo * k
	end
	return yawTo, pitchTo, true
end

-- The glance-back weight `since` seconds into a stay on a plate (0 outside the one glance).
function ClonePose.glance(since: number): number
	local t0 = C.GLANCE_AT
	return envelope(since, t0, C.GLANCE_IN, t0 + C.GLANCE_IN + C.GLANCE_HOLD, C.GLANCE_OUT)
end

-- Seconds from the start of the busted pose until the clone is gone (hands up + glitch).
function ClonePose.bustedSeconds(): number
	return C.BUSTED_HANDS_UP + C.BUSTED_GLITCH
end

-- Writes the pose of `state` into p. `since`: seconds in the state; `clock`: any running time (loops);
-- `walkPhase`: the walk cycle in radians (carry bob); `lookYaw` / `lookPitch`: from ClonePose.look
-- (the plate glance); `weight`: 0..1 blend toward this pose (the view blends in and out).
-- Returns p; p.busy is false for a state without a custom pose.
function ClonePose.compute(
	p: Pose,
	state: string,
	since: number,
	clock: number,
	walkPhase: number,
	moving: boolean,
	lookYaw: number,
	lookPitch: number,
	weight: number
): Pose
	table.clear(p.joints)
	p.glitchX, p.bob, p.busy = 0, 0, false
	if not ClonePose.CUSTOM[state] or weight <= 0 then
		return p
	end
	p.busy = true
	local w = math.clamp(weight, 0, 1)
	if state == "carry" then
		local bob = if moving
			then math.sin(walkPhase * 2) * C.CARRY_BOB
			else math.sin(clock * TAU * C.CARRY_BOB_IDLE_HZ) * C.CARRY_BOB * 0.5
		local lift = bob * 0.6 -- the arms follow the loot a little
		set(p, "LeftUpperArm", C.CARRY_SHOULDER + lift, 0, C.CARRY_INWARD, w)
		set(p, "RightUpperArm", C.CARRY_SHOULDER + lift, 0, -C.CARRY_INWARD, w)
		set(p, "LeftLowerArm", C.CARRY_ELBOW, 0, 0, w)
		set(p, "RightLowerArm", C.CARRY_ELBOW, 0, 0, w)
		p.bob = bob * w
	elseif state == "on-plate" then
		local shift = math.sin(clock * TAU * C.PLATE_SHIFT_HZ)
		set(p, "UpperTorso", 0, shift * C.PLATE_SHIFT * 0.4, shift * C.PLATE_SHIFT, w)
		local g = ClonePose.glance(since)
		set(p, "Head", lookPitch * g, lookYaw * g, 0, w)
	elseif state == "stuck" then
		local c = since % C.STUCK_CYCLE
		local tap = envelope(c, 0, 0.2, C.STUCK_TAP - 0.2, 0.2)
		local knock = math.max(0, math.sin(c * TAU * C.STUCK_TAP_HZ))
		local shrug = envelope(c, C.STUCK_TAP, 0.2, C.STUCK_TAP + C.STUCK_SHRUG - 0.25, 0.25)
		set(p, "RightUpperArm", 1.5 * tap + 0.3 * shrug, 0, -0.1 * tap + 0.55 * shrug, w)
		set(p, "RightLowerArm", (0.25 + 0.35 * knock) * tap + 1.4 * shrug, 0, 0, w)
		set(p, "LeftUpperArm", 0.3 * shrug, 0, -0.55 * shrug, w)
		set(p, "LeftLowerArm", 1.4 * shrug, 0, 0, w)
		set(p, "Head", -0.1 * tap, 0, 0.2 * shrug, w)
	elseif state == "busted" then
		local up = smooth(since / C.BUSTED_HANDS_UP)
		set(p, "LeftUpperArm", 2.85 * up, 0, -0.3 * up, w)
		set(p, "RightUpperArm", 2.85 * up, 0, 0.3 * up, w)
		set(p, "LeftLowerArm", 0.35 * up, 0, 0, w)
		set(p, "RightLowerArm", 0.35 * up, 0, 0, w)
		set(p, "Head", 0.15 * up, 0, 0, w)
		p.glitchX = ClonePose.glitch(since - C.BUSTED_HANDS_UP)
	end
	return p
end

-- Sideways offset of the busted glitch `t` seconds after it starts: GLITCH_SLICES slices of two
-- frames each, spread over BUSTED_GLITCH, alternating sides; 0 between and after them.
function ClonePose.glitch(t: number): number
	if t < 0 or t >= C.BUSTED_GLITCH then
		return 0
	end
	local gap = C.BUSTED_GLITCH / C.GLITCH_SLICES
	local k = math.floor(t / gap)
	if t - k * gap < 2 * C.GLITCH_FRAME then
		return if k % 2 == 0 then C.GLITCH_OFFSET else -C.GLITCH_OFFSET
	end
	return 0
end

return table.freeze(ClonePose)
