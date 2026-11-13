--!strict
-- Heist/FfPill: when the HOLD FAST pill (Hud/Controls, Hud/Run) shows, as a pure rule (numbers in
-- Config.Heist.FF_PILL; tests/unit/HeistFfPill.spec.luau). Owner, live v125: "when you run, the HOLD FAST button keeps
-- disappearing and reappearing". It used to follow the server's CanFF, which is false whenever any live player moves,
-- so walking flipped it on and off. Now:
--   * it shows while a clone still has something to play (the server's FFPending) and your run has not ended, after
--     that held for SHOW_DELAY, and goes only after it has been false for HIDE_DELAY (hysteresis: a one-tick blip
--     never toggles it);
--   * whether fast-forward would run right now (CanFF: everyone stands still) only dims it, eased over FADE_SECONDS,
--     after the change held for READY_DELAY; holding it while you walk starts the skip once you stop (Hud/Run resends);
--   * its opacity eases in and out over FADE_SECONDS (a fade, never a pop).
--   new() -> State
--   step(state, pending, ready, dt, cfg) -> (visible, opacity)   opacity 0..1 (0: hidden; DIM_OPACITY while dimmed)

local FfPill = {}

export type State = {
	shown: boolean, -- the hysteresis output: the pill is up
	pendingFor: number, -- seconds the input has disagreed with `shown` (resets when it agrees)
	ready: boolean, -- the debounced CanFF
	readyFor: number,
	opacity: number, -- 0..1, eased
}

function FfPill.new(): State
	return { shown = false, pendingFor = 0, ready = false, readyFor = 0, opacity = 0 }
end

local function approach(v: number, target: number, dt: number, seconds: number): number
	if seconds <= 0 then
		return target
	end
	local step = math.max(dt, 0) / seconds
	if v < target then
		return math.min(target, v + step)
	end
	return math.max(target, v - step)
end

-- One frame: `pending` = FFPending and your run still going; `ready` = CanFF. Returns whether the pill is visible and
-- its opacity.
function FfPill.step(st: State, pending: boolean, ready: boolean, dt: number, cfg: any): (boolean, number)
	dt = math.max(dt, 0)
	if pending ~= st.shown then
		st.pendingFor += dt
		local need = if pending then cfg.SHOW_DELAY else cfg.HIDE_DELAY
		if st.pendingFor >= need then
			st.shown = pending
			st.pendingFor = 0
		end
	else
		st.pendingFor = 0
	end
	if ready ~= st.ready then
		st.readyFor += dt
		if st.readyFor >= cfg.READY_DELAY then
			st.ready = ready
			st.readyFor = 0
		end
	else
		st.readyFor = 0
	end
	local target = if not st.shown then 0 elseif st.ready then 1 else cfg.DIM_OPACITY
	st.opacity = approach(st.opacity, target, dt, cfg.FADE_SECONDS)
	return st.opacity > 0.001, st.opacity
end

return table.freeze(FfPill)
