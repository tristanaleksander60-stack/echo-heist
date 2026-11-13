--!strict
-- Heist/SlideMath: the pure half of the slide (numbers in Config.Slide; Heist/Slide drives your character with it,
-- Heist/CameraDirector draws the dip, tests/unit/HeistSlide.spec.luau and tests/sim/Slide.spec.luau check it in Lune).
-- One kind of slide (Ctrl, B); the fast Ctrl + Shift slide and the touch button are gone (Shift is the sprint).
--   envelope(age, cfg)           the burst's share 0..1: a short push-off (ATTACK_SECONDS), then a quadratic decay to
--                                0 at SECONDS
--   speed(walk, age, cfg)        the push's target speed: the speed you move at (WalkSpeed, sprint included) +
--                                BURST x envelope
--   dip(age, cfg)                how far the first-person eye drops (studs): down over DIP_IN_SECONDS, held while the
--                                burst lasts, back up over DIP_OUT_SECONDS
--   fovKick(age, comfort, cfg)   degrees added to the FOV (follows the burst); 0 under reduced motion or shake off
--   active(age, cfg)             the push still runs; cameraActive: the dip is not back yet
--   direction(mx, mz, lx, lz)    the slide's flat unit direction: your move direction, or your look when you stand
--   allowed(gate)                may a slide start now? -> ok, reason (never in a presentation moment or Crew View)

local SlideMath = {}

export type Gate = {
	where: string?, -- "heist" | "garage" | ...
	phase: string?, -- a heist's phase: "Run" | "Between" | ...
	lobbyRoam: boolean?, -- the hideout: walking about (no station, no drive)
	presenting: boolean?, -- a presentation shot holds the camera (intro, 8 OF ME, busted, Line-up, level intro, beat)
	crewView: boolean?, -- Crew View is up (held or easing back)
	rewinding: boolean?, -- the rewind finish plays
	sheet: boolean?, -- a HUD sheet or panel is up
	alive: boolean?, -- nil: unknown, counts as alive
	grounded: boolean?, -- on the floor (nil counts as grounded)
	seated: boolean?, -- sitting (a van seat) or PlatformStand
	frozen: boolean?, -- your root is anchored (between runs, the transition)
	cooling: boolean?, -- the last slide's cooldown runs
}

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

function SlideMath.envelope(age: number, cfg: any): number
	local total = cfg.SECONDS
	if age < 0 or age >= total then
		return 0
	end
	local attack = math.min(cfg.ATTACK_SECONDS, total)
	if age < attack then
		return age / attack
	end
	local u = (age - attack) / math.max(total - attack, 1e-6)
	return (1 - u) * (1 - u)
end

function SlideMath.speed(walk: number, age: number, cfg: any): number
	return walk + cfg.BURST * SlideMath.envelope(age, cfg)
end

function SlideMath.active(age: number, cfg: any): boolean
	return age >= 0 and age < cfg.SECONDS
end

function SlideMath.cameraActive(age: number, cfg: any): boolean
	return age >= 0 and age < cfg.SECONDS + cfg.DIP_OUT_SECONDS
end

function SlideMath.dip(age: number, cfg: any): number
	local total = cfg.SECONDS
	if age < 0 or age >= total + cfg.DIP_OUT_SECONDS then
		return 0
	end
	local down = smooth(age / math.max(cfg.DIP_IN_SECONDS, 1e-6))
	local up = if age <= total then 0 else smooth((age - total) / math.max(cfg.DIP_OUT_SECONDS, 1e-6))
	return cfg.DIP * down * (1 - up)
end

-- comfort: { reduced: boolean?, shake: boolean? } (shake false = camera shake off in Settings)
function SlideMath.fovKick(age: number, comfort: { reduced: boolean?, shake: boolean? }, cfg: any): number
	if comfort.reduced == true or comfort.shake == false then
		return 0
	end
	return cfg.FOV_KICK * SlideMath.envelope(age, cfg)
end

-- The flat unit direction: the move direction (mx, mz) when it is at least minMove long, else the look (lx, lz).
-- Returns 0, 0 when neither has a direction.
function SlideMath.direction(mx: number, mz: number, lx: number, lz: number, minMove: number): (number, number)
	local m = math.sqrt(mx * mx + mz * mz)
	if m >= minMove and m > 1e-6 then
		return mx / m, mz / m
	end
	local l = math.sqrt(lx * lx + lz * lz)
	if l > 1e-6 then
		return lx / l, lz / l
	end
	return 0, 0
end

-- Whether a slide may start, and why not ("ok" when it may). Order: where you are, a presentation moment, Crew View,
-- the rewind, a sheet, your character, the cooldown. Heist/Sprint uses the same gate (without the cooldown and the
-- floor check).
function SlideMath.allowed(g: Gate): (boolean, string)
	if g.where == "heist" then
		if g.phase ~= "Run" then
			return false, "phase"
		end
	elseif g.where == "garage" then
		if g.lobbyRoam ~= true then
			return false, "station"
		end
	else
		return false, "where"
	end
	if g.presenting == true then
		return false, "presenting"
	end
	if g.crewView == true then
		return false, "crewView"
	end
	if g.rewinding == true then
		return false, "rewind"
	end
	if g.sheet == true then
		return false, "sheet"
	end
	if g.alive == false then
		return false, "dead"
	end
	if g.seated == true or g.frozen == true then
		return false, "seated"
	end
	if g.grounded == false then
		return false, "air"
	end
	if g.cooling == true then
		return false, "cooldown"
	end
	return true, "ok"
end

return table.freeze(SlideMath)
