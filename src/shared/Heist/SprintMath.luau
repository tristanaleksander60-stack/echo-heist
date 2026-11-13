--!strict
-- Heist/SprintMath: the pure half of the sprint (numbers in Config.Sprint; Heist/Sprint drives your WalkSpeed with it,
-- Heist/CameraDirector adds the FOV kick; tests/unit/HeistSprint.spec.luau and tests/sim/Sprint.spec.luau check it).
--   wants(input, cfg)                 does this input ask for a sprint? Keyboard: Shift held; gamepad: the L3 toggle;
--                                     touch: the thumbstick pushed to its edge (TOUCH_FULL). Never while standing.
--   padToggle(on, pressed, moving)    the L3 toggle: a press flips it, standing still clears it
--   ease(share, want, dt, cfg)        the sprint's share 0..1, eased toward want over RAMP_SECONDS (linear, exact for
--                                     any frame rate)
--   walkSpeed(base, share, cfg)       base x (1 + (MULT - 1) x share)
--   fovKick(share, comfort, cfg)      degrees (first person); 0 under reduced motion or with camera shake off
--   hintDue(seenBefore, levelId, walked, device, cfg)   the one-time "Hold Shift to sprint" toast

local SprintMath = {}

export type Input = {
	device: string, -- "key" | "pad" | "touch" (Strings.forDevice's)
	shift: boolean?, -- keyboard: Shift held
	padOn: boolean?, -- gamepad: the L3 toggle is on
	stick: number?, -- the move vector's length 0..1 (the thumbstick's push on touch and pads)
}

-- Does this input ask for a sprint? Standing (a move shorter than MIN_MOVE) never sprints.
function SprintMath.wants(input: Input, cfg: any): boolean
	local stick = input.stick or 0
	if stick < cfg.MIN_MOVE then
		return false
	end
	if input.device == "touch" then
		return stick >= cfg.TOUCH_FULL
	end
	if input.device == "pad" then
		return input.padOn == true or input.shift == true
	end
	return input.shift == true
end

-- The gamepad's L3 toggle: `pressed` flips it on this frame; standing still (not moving) turns it off.
function SprintMath.padToggle(on: boolean, pressed: boolean, moving: boolean): boolean
	if pressed then
		on = not on
	end
	if not moving then
		on = false
	end
	return on
end

function SprintMath.ease(share: number, want: boolean, dt: number, cfg: any): number
	local step = if cfg.RAMP_SECONDS > 0 then math.max(dt, 0) / cfg.RAMP_SECONDS else 1
	if want then
		return math.min(1, share + step)
	end
	return math.max(0, share - step)
end

function SprintMath.walkSpeed(base: number, share: number, cfg: any): number
	return base * (1 + (cfg.MULT - 1) * math.clamp(share, 0, 1))
end

-- comfort: { reduced: boolean?, shake: boolean? } (shake false = camera shake off in Settings)
function SprintMath.fovKick(share: number, comfort: { reduced: boolean?, shake: boolean? }, cfg: any): number
	if comfort.reduced == true or comfort.shake == false then
		return 0
	end
	local s = math.clamp(share, 0, 1)
	return cfg.FOV_KICK * s * s * (3 - 2 * s)
end

-- The one-time hint: not seen before (and never sprinted), not on the first level, on a keyboard or a gamepad (touch
-- sprints by pushing the stick: no key to teach), after walking HINT_WALK_SECONDS in a run.
function SprintMath.hintDue(seenBefore: boolean, levelId: string?, walked: number, device: string, cfg: any): boolean
	if seenBefore or device == "touch" then
		return false
	end
	if levelId == nil or levelId == cfg.HINT_SKIP_LEVEL then
		return false
	end
	return walked >= cfg.HINT_WALK_SECONDS
end

return table.freeze(SprintMath)
