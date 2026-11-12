--!strict
-- Heist/CloneGait: walk and run clip speeds for a clone, locked to its recording (PLAN_STEAM_PLUS
-- §4.4 A3, premium C7 "no foot sliding"; docs/research/roblox_quality.md §4.4 steps 3-4).
--   * Ground speed = the recording's horizontal speed x the view's clock rate (1x live, 3x when the
--     run is fast-forwarded, the reel's rate on a rewind), so the clip runs as fast as the clone
--     really covers ground on screen, never at wall-clock speed.
--   * Both clips play at speed 1 at GAIT_BASE studs/s (the R15 Animate script's 16 / 1.25); walk
--     alone under WALK_ONLY, run alone over RUN_ONLY, blended between (by the recorded speed, so a
--     fast-forwarded walk stays a walk).
--   * AdjustSpeed only when the speed moves by GAIT_SPEED_EPS (relative): the clip-implied travel
--     stays within GAIT_SPEED_EPS x STRIDE of the real travel per stride (under 0.3 studs).
--   * Phase lock: a clip that starts (new run, rewind, reel) starts at (distance / STRIDE) % 1, so
--     the live loop, the rewind and the reel all put the feet in the same place.
-- Pure (no engine calls): Lune unit specs run it (tests/unit/HeistCloneState.spec.luau).

local Config = require("../Config")

local C = Config.Clone

local CloneGait = {}

export type Gait = {
	speed: number, -- clip speed last sent (AdjustSpeed)
	walkW: number, -- walk weight last sent
	runW: number, -- run weight last sent
}

function CloneGait.new(): Gait
	return { speed = -1, walkW = -1, runW = -1 }
end

-- The clip speed and weights for a recorded speed (studs per recording second) at a clock rate.
function CloneGait.target(speedRec: number, rate: number): (number, number, number)
	local clip = math.max(0, speedRec) * math.abs(rate) / C.GAIT_BASE
	local run = math.clamp((speedRec - C.WALK_ONLY) / (C.RUN_ONLY - C.WALK_ONLY), 0, 1)
	run = math.floor(run / C.GAIT_WEIGHT_STEP + 0.5) * C.GAIT_WEIGHT_STEP
	return clip, 1 - run, run
end

-- Updates the gait; returns whether the speed and whether the weights must be sent again.
function CloneGait.step(g: Gait, speedRec: number, rate: number): (boolean, boolean)
	local clip, walkW, runW = CloneGait.target(speedRec, rate)
	local speedChanged = false
	local last = g.speed
	if last < 0 or (clip == 0) ~= (last == 0) or math.abs(clip - last) > C.GAIT_SPEED_EPS * math.max(clip, last) then
		g.speed = clip
		speedChanged = true
	end
	local weightChanged = walkW ~= g.walkW or runW ~= g.runW
	g.walkW, g.runW = walkW, runW
	return speedChanged, weightChanged
end

-- Forget what was sent (a new clip set started).
function CloneGait.reset(g: Gait)
	g.speed, g.walkW, g.runW = -1, -1, -1
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

-- The walk-cycle phase (0..1) a clip starts at, for a clone that has walked `distance` studs.
function CloneGait.phase(distance: number): number
	return (distance / C.STRIDE) % 1
end

return table.freeze(CloneGait)
