--!strict
-- Heist/Motion: the motion tokens (docs/research/premium.md D3, D4, D10; roblox_quality §3.5;
-- POLISH §4.1). The only module in src/client/Heist that builds a TweenInfo
-- (tests/ui_kit_check.luau): everyone else names a token, or asks for a duration that lives in
-- Config. Numbers: Config.Ui.MOTION.
--   enter     0.24 s Back Out    panels, chips, toasts coming in
--   exit      0.12 s Quad In     panels leaving (never Back In)
--   feedback  0.08 s Quad Out    colour and small state changes
--   emphasis  0.35 s Back Out    stamps, reveals
--   fade      0.15 s Quad Out    the reduced-motion crossfade
--   press*    the button press: 0.92 at once, then 1.04, settling at 1.0 (0.26 s)
--   pop       0.2 s Back Out     feedback pops (Ui.pop)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local M = Config.Ui.MOTION

local Motion = {}

local function info(spec: { any }): TweenInfo
	return TweenInfo.new(
		spec[1],
		(Enum.EasingStyle :: any)[spec[2]] :: Enum.EasingStyle,
		(Enum.EasingDirection :: any)[spec[3]] :: Enum.EasingDirection
	)
end

local tokens: { [string]: TweenInfo } = {}
for name, spec in M do
	tokens[name] = info(spec)
end
Motion.TOKENS = table.freeze(tokens)

-- The TweenInfo of a token ("enter", "exit", "feedback", "emphasis", "fade", "press...", "pop").
function Motion.info(token: string): TweenInfo
	local t = tokens[token]
	assert(t, "unknown motion token " .. token)
	return t
end

-- The token's duration in seconds.
function Motion.seconds(token: string): number
	return Motion.info(token).Time
end

-- Plays a token tween and returns it.
function Motion.tween(obj: Instance, token: string, goals: { [string]: any }): Tween
	local tw = TweenService:Create(obj, Motion.info(token), goals)
	tw:Play()
	return tw
end

-- A tween with a duration that lives in Config (flashes, dims, pulses): linear by default, or the
-- style and direction of a token. Never a literal at the call site.
function Motion.timed(obj: Instance, seconds: number, goals: { [string]: any }, like: string?): Tween
	local base = if like then Motion.info(like) else nil
	local ti = if base
		then TweenInfo.new(seconds, base.EasingStyle, base.EasingDirection)
		else TweenInfo.new(seconds, Enum.EasingStyle.Linear)
	local tw = TweenService:Create(obj, ti, goals)
	tw:Play()
	return tw
end

-- The breathing outline (POLISH §4.1 "breathing", the NEXT job, the card to delete): a Sine InOut tween
-- to `goals` and back, forever, Config.Ui.BREATH_SECONDS each way. The caller cancels it (or destroys
-- the object) and never starts it under reduced motion (a static colour instead).
function Motion.breathe(obj: Instance, goals: { [string]: any }): Tween
	local ti = TweenInfo.new(Config.Ui.BREATH_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tw = TweenService:Create(obj, ti, goals)
	tw:Play()
	return tw
end

-- D3 button press on a UIScale: down to PRESS_SCALE at once.
function Motion.pressDown(scale: UIScale)
	Motion.tween(scale, "pressDown", { Scale = Config.Ui.PRESS_SCALE })
end

-- D3 release: overshoot to PRESS_OVERSHOOT, then settle at 1.0 (0.2-0.3 s in all).
function Motion.pressUp(scale: UIScale)
	local up = Motion.tween(scale, "pressUp", { Scale = Config.Ui.PRESS_OVERSHOOT })
	up.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			Motion.tween(scale, "pressSettle", { Scale = 1 })
		end
	end)
end

return Motion
