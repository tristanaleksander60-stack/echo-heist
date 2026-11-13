--!strict
-- Heist/CloneGait: walk and run clip speeds for a clone, locked to its recording (PLAN_STEAM_PLUS
-- §4.4 A3, premium C7 "no foot sliding"; REVIEW_STEAM_PLUS #6: a clone walks exactly like you).
--   * The clones play the Rookie's own walk and run (Shared/Heist/RookieClips) with the R15 Animate's speed maths
--     (vault "The Default Animate Script"), the very rule that drives your character, so the blend matches:
--     runSpeed = speed / 16 x 1.25; walk alone at runSpeed <= 0.5 (walk rate runSpeed / 0.5), walk fading into
--     run up to 1 (both at rate 1), run alone above (run rate runSpeed); a "small but not zero" weight keeps the
--     faded clip running in step.
--   * Ground speed = the recording's horizontal speed x the view's clock rate (1x live, 3x when the run is
--     fast-forwarded, the reel's rate on a rewind): the clip rates scale with the clock, the weights do not
--     (a fast-forwarded walk stays a walk).
--   * AdjustSpeed only when a rate moves by GAIT_SPEED_EPS (relative): the clip-implied travel stays within
--     GAIT_SPEED_EPS x stride of the real travel per stride (under 0.3 studs).
--   * Phase lock: a clip that starts (new run, rewind, reel) starts at (distance / its stride) % 1, so the live
--     loop, the rewind and the reel all put the feet in the same place.
-- Pure (no engine calls): Lune unit specs run it (tests/unit/HeistCloneState.spec.luau).

local Config = require("../Config")

local C = Config.Clone
local A = Config.Rookie.ANIM

local CloneGait = {}

CloneGait.WALK_BASE = A.SCALE * A.WALK_NORM / A.ROOT_MOTION -- studs/s the walk covers at rate 1 (6.4)
CloneGait.RUN_BASE = A.SCALE * A.RUN_NORM / A.ROOT_MOTION -- the run (12.8)
CloneGait.WALK_STRIDE = CloneGait.WALK_BASE * A.CYCLE -- studs per walk cycle
CloneGait.RUN_STRIDE = CloneGait.RUN_BASE * A.CYCLE

export type Gait = {
	speed: number, -- walk clip rate last sent (AdjustSpeed); -1 = nothing sent
	runSpeed: number, -- run clip rate last sent
	walkW: number, -- walk weight last sent
	runW: number, -- run weight last sent
}

function CloneGait.new(): Gait
	return { speed = -1, runSpeed = -1, walkW = -1, runW = -1 }
end

-- The walk rate, run rate, walk weight and run weight for a recorded speed (studs per recording second) at a clock
-- rate: the Animate's setRunSpeed, weights stepped by GAIT_WEIGHT_STEP.
function CloneGait.target(speedRec: number, rate: number): (number, number, number, number)
	local v = math.max(0, speedRec)
	local runSpeed = v / A.SCALE * A.ROOT_MOTION
	local walkRate, runRate = runSpeed / A.WALK_NORM, runSpeed / A.RUN_NORM
	local fade: number
	if runSpeed <= A.WALK_NORM then
		fade = 0
	elseif runSpeed < A.RUN_NORM then
		fade = (runSpeed - A.WALK_NORM) / (A.RUN_NORM - A.WALK_NORM)
		walkRate, runRate = 1, 1
	else
		fade = 1
	end
	fade = math.floor(fade / C.GAIT_WEIGHT_STEP + 0.5) * C.GAIT_WEIGHT_STEP
	local r = math.abs(rate)
	return walkRate * r, runRate * r, math.max(1 - fade, A.SMALL), math.max(fade, A.SMALL)
end

local function moved(new: number, last: number): boolean
	return last < 0 or (new == 0) ~= (last == 0) or math.abs(new - last) > C.GAIT_SPEED_EPS * math.max(new, last)
end

-- Updates the gait; returns whether the rates and whether the weights must be sent again.
function CloneGait.step(g: Gait, speedRec: number, rate: number): (boolean, boolean)
	local walkRate, runRate, walkW, runW = CloneGait.target(speedRec, rate)
	local speedChanged = false
	if moved(walkRate, g.speed) or moved(runRate, g.runSpeed) then
		g.speed, g.runSpeed = walkRate, runRate
		speedChanged = true
	end
	local weightChanged = walkW ~= g.walkW or runW ~= g.runW
	g.walkW, g.runW = walkW, runW
	return speedChanged, weightChanged
end

-- Forget what was sent (a new clip set started).
function CloneGait.reset(g: Gait)
	g.speed, g.runSpeed, g.walkW, g.runW = -1, -1, -1, -1
end

-- The ground speed the playing clips imply (studs per wall second): the weighted walk and run travel.
function CloneGait.implied(g: Gait): number
	if g.speed < 0 then
		return 0
	end
	local w = g.walkW + g.runW
	return (g.walkW * g.speed * CloneGait.WALK_BASE + g.runW * g.runSpeed * CloneGait.RUN_BASE) / w
end

-- The land clip's weight at a horizontal speed (your character and your clones alike): full when dropping on the
-- spot, light over a run (the run's legs keep the feet planted; the squash still shows in the body).
function CloneGait.landWeight(speed: number): number
	local L = A.LAND
	return 1 - L.runShare * math.clamp(speed / L.fullSpeed, 0, 1)
end

-- Cumulative horizontal path length (studs) at each sample of a recording.
function CloneGait.distances(rec: any): { number }
	local out = table.create(math.max(rec.n, 1), 0)
	local px, pz, cut = rec.px, rec.pz, rec.cut
	for i = 2, rec.n do
		local d = 0
		if not cut[i] then
			local dx, dz = px[i] - px[i - 1], pz[i] - pz[i - 1]
			d = math.sqrt(dx * dx + dz * dz)
		end
		out[i] = out[i - 1] + d
	end
	return out
end

-- Path length at recording time t (linear between samples), from CloneGait.distances.
function CloneGait.distanceAt(rec: any, dist: { number }, t: number): number
	local n = rec.n
	if n == 0 then
		return 0
	end
	local u = math.max(0, t * rec.hz)
	local i = math.floor(u) + 1
	if i >= n then
		return dist[n]
	end
	local f = u - (i - 1)
	return dist[i] + (dist[i + 1] - dist[i]) * f
end

-- The walk and run cycle phases (0..1) the clips start at, for a clone that has walked `distance` studs.
function CloneGait.phase(distance: number): (number, number)
	return (distance / CloneGait.WALK_STRIDE) % 1, (distance / CloneGait.RUN_STRIDE) % 1
end

return table.freeze(CloneGait)
