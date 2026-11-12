--!strict
-- Heist/CloneState: what a clone is doing at one moment, derived from its recording
-- (PLAN_STEAM_PLUS §4.4 A3; docs/research/roblox_quality.md §4.4 step 1). No new intents and
-- nothing added to the recording format: the state comes from the 20 Hz samples (Sampler
-- position and spline velocity, the GROUNDED / JUMPING flags), the level's plate boxes, and
-- what the server already decided (gone, stuck, carrying), which the view passes in.
--
-- States, in priority order:
--   "busted"   gone (Gus caught it, or a laser zapped it): hands up, glitch, tape burst
--   "stuck"    the server stopped it (a shut door ahead): taps the wall, shrugs
--   "jump" / "fall"  airborne, rising / falling
--   "carry"    holding loot (the view reads the server's loot attributes)
--   "on-plate" standing still inside a plate box: planted, weight shift, one glance back
--   "moving"   walking or running
--   "idle"     standing anywhere else
-- `loco` is the locomotion layer under the state: "idle" | "move" | "jump" | "fall".
-- Pure (no engine calls): Lune unit specs run it (tests/unit/HeistCloneState.spec.luau).

local Config = require("../Config")
local Codec = require("../Rec/Codec")
local Sampler = require("../Rec/Sampler")
local Geom = require("../Sim/Geom")

local C = Config.Clone
local FLAG = Codec.FLAG

local CloneState = {}

CloneState.BUSTED = "busted"
CloneState.STUCK = "stuck"
CloneState.JUMP = "jump"
CloneState.FALL = "fall"
CloneState.CARRY = "carry"
CloneState.PLATE = "on-plate"
CloneState.MOVING = "moving"
CloneState.IDLE = "idle"

export type Frame = {
	state: string,
	loco: string,
	speed: number, -- horizontal, studs per recording second
	vy: number, -- vertical, studs per recording second
	plate: number, -- index of the plate box it stands in (0 = none)
	x: number, -- level space (the recording's frame)
	y: number,
	z: number,
	yaw: number,
}

-- What the view knows besides the recording. `plates`: the compiled level's plates ({box}).
-- `prevLoco`: last frame's loco (hysteresis between standing and walking).
export type Ctx = {
	gone: string?,
	stuck: boolean?,
	carrying: boolean?,
	plates: { any }?,
	prevLoco: string?,
}

function CloneState.newFrame(): Frame
	return { state = "idle", loco = "idle", speed = 0, vy = 0, plate = 0, x = 0, y = 0, z = 0, yaw = 0 }
end

-- Index of the first plate box containing the point (0 = none).
function CloneState.plateAt(plates: { any }?, x: number, y: number, z: number): number
	for i, p in plates or {} do
		local box = p.box
		if box and Geom.contains(box, x, y, z) then
			return i
		end
	end
	return 0
end

-- The state at recording time t, written into `out` (reused every frame: no allocation).
-- Returns nil for an empty recording.
function CloneState.derive(rec: any, t: number, ctx: Ctx, out: Frame?): Frame?
	local x, y, z, yaw, flags = Sampler.at(rec, t)
	if x == nil then
		return nil
	end
	local f = out or CloneState.newFrame()
	local vx, vy, vz = Sampler.velocity(rec, t)
	local speed = math.sqrt(vx * vx + vz * vz)
	local frozen = ctx.gone ~= nil or ctx.stuck == true
	if frozen then
		speed, vy = 0, 0
	end
	local grounded = Codec.hasFlag(flags, FLAG.GROUNDED)
	local jumping = Codec.hasFlag(flags, FLAG.JUMPING)
	local airborne = not frozen and (jumping or not grounded) and math.abs(vy) > C.AIR_RISE

	local loco
	if airborne then
		loco = if vy > 0 then "jump" else "fall"
	else
		local wasMoving = ctx.prevLoco == "move"
		loco = if speed > (if wasMoving then C.STOP_SPEED else C.MOVE_SPEED) then "move" else "idle"
	end
	if frozen then
		loco = "idle"
	end

	local plate = if loco == "idle" then CloneState.plateAt(ctx.plates, x, y, z) else 0
	local state
	if ctx.gone ~= nil then
		state = CloneState.BUSTED
	elseif ctx.stuck then
		state = CloneState.STUCK
	elseif airborne then
		state = loco
	elseif ctx.carrying then
		state = CloneState.CARRY
	elseif plate > 0 then
		state = CloneState.PLATE
	elseif loco == "move" then
		state = CloneState.MOVING
	else
		state = CloneState.IDLE
	end

	f.state, f.loco, f.speed, f.vy, f.plate = state, loco, speed, vy, plate
	f.x, f.y, f.z, f.yaw = x, y, z, yaw
	return f
end

-- Solo only (MASTERPLAN §6.5 #4): the hue of your rank-th newest run (0 = newest) of ownCount
-- drifts up to Config.Clone.DRIFT_DEGREES toward violet. In co-op the seat hue stays put (the
-- four seat hues must stay apart). h is a hue in [0, 1).
function CloneState.driftHue(h: number, rank: number, ownCount: number, solo: boolean): number
	if not solo or ownCount <= 1 then
		return h
	end
	local f = math.clamp(rank / (ownCount - 1), 0, 1)
	return (h + f * C.DRIFT_DEGREES / 360) % 1
end

return table.freeze(CloneState)
