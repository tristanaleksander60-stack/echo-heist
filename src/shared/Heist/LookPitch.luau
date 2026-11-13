--!strict
-- Heist/LookPitch: look up / down on other players' screens (Config.Rookie.LOOK). Pure: no engine calls
-- (Lune-tested in tests/unit/HeistLookPitch.spec.luau).
--   * the wire: your first-person camera pitch (degrees, + = up) quantised to STEP_DEG and sent as the n of the
--     existing Heist.Ready lobby table { op = "look", n } (n = 1..STEPS; VanRules.validAction checks the shape,
--     LookPitch.validN the range);
--   * the tilt: shares of the pitch on the Neck and the Waist, each clamped (NECK_MAX, WAIST_MAX), and the
--     exponential follow that smooths the 10 Hz steps on every other client.

local Config = require("../Config")

local L = Config.Rookie.LOOK

local LookPitch = {}

-- How many n values there are (n = 1 .. STEPS; the middle one is level).
LookPitch.STEPS = 2 * math.floor(L.MAX_DEG / L.STEP_DEG) + 1
local MID = (LookPitch.STEPS + 1) / 2

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

-- The wire value for a pitch in degrees (+ = up): clamped to MAX_DEG, rounded to the nearest step.
function LookPitch.quantise(deg: number): number
	if not finite(deg) then
		return MID
	end
	local d = math.clamp(deg, -L.MAX_DEG, L.MAX_DEG)
	local step = math.floor(d / L.STEP_DEG + 0.5)
	return math.clamp(MID + step, 1, LookPitch.STEPS)
end

-- The pitch (degrees) a valid wire value stands for.
function LookPitch.degrees(n: number): number
	return (n - MID) * L.STEP_DEG
end

-- Is this a wire value the server accepts? (a whole number 1..STEPS)
function LookPitch.validN(n: any): boolean
	return finite(n) and n % 1 == 0 and n >= 1 and n <= LookPitch.STEPS
end

-- Is this a pitch attribute value a client may apply? (finite, within MAX_DEG)
function LookPitch.validDegrees(d: any): boolean
	return finite(d) and math.abs(d) <= L.MAX_DEG
end

-- The Neck and Waist tilt (degrees, + = up) for a pitch: shares of it, each clamped to its limit.
function LookPitch.split(deg: number): (number, number)
	if not finite(deg) then
		return 0, 0
	end
	local neck = math.clamp(deg * L.NECK_SHARE, -L.NECK_MAX, L.NECK_MAX)
	local waist = math.clamp(deg * L.WAIST_SHARE, -L.WAIST_MAX, L.WAIST_MAX)
	return neck, waist
end

-- One frame of the exponential follow from `current` toward `target` (frame-rate independent).
function LookPitch.follow(current: number, target: number, dt: number): number
	if not finite(current) then
		current = 0
	end
	if not finite(target) then
		target = 0
	end
	local a = 1 - math.exp(-L.FOLLOW_RATE * math.clamp(if finite(dt) then dt else 0, 0, 0.5))
	return current + (target - current) * a
end

-- Should the sender send this wire value now? Only on a change, and at most SEND_HZ.
function LookPitch.shouldSend(n: number, lastN: number?, now: number, lastAt: number?): boolean
	if n == lastN then
		return false
	end
	return lastAt == nil or now - lastAt >= 1 / L.SEND_HZ - 1e-6
end

return LookPitch
