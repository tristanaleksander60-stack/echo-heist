-- L1: the HOLD FAST pill's visibility rule (Shared/Heist/FfPill, Config.Heist.FF_PILL). Owner, live v125: "when you
-- run, the HOLD FAST button keeps disappearing and reappearing": it followed CanFF, false whenever anyone moves. Now it
-- follows FFPending (a clone still to play) with hysteresis and a fade; moving only dims it.

local Config = require("../../src/shared/Config")
local FfPill = require("../../src/shared/Heist/FfPill")
local Assert = require("./Assert")

local CFG = Config.Heist.FF_PILL
local DT = 1 / 60

-- Runs `seconds` of frames; returns the number of visibility flips and the last (visible, opacity).
local function frames(
	st: any,
	seconds: number,
	pending: (number) -> boolean,
	ready: (number) -> boolean
): (number, boolean, number)
	local flips, last = 0, nil
	local vis, op = false, 0
	local n = math.floor(seconds / DT + 0.5)
	for i = 1, n do
		local t = i * DT
		vis, op = FfPill.step(st, pending(t), ready(t), DT, CFG)
		if last ~= nil and vis ~= last then
			flips += 1
		end
		last = vis
	end
	return flips, vis, op
end

local function always(v: boolean): (number) -> boolean
	return function()
		return v
	end
end

return function(test)
	test("ff pill: walking (CanFF flickering every few frames) never hides it, only dims it", function()
		local st = FfPill.new()
		frames(st, 1, always(true), always(true))
		-- walk: CanFF false, with a 2-frame true blip every half second (a step that reads as standing)
		local flips, vis, op = frames(st, 6, always(true), function(t)
			return math.floor(t / DT + 0.5) % 30 < 2
		end)
		Assert.eq(flips, 0, "never toggled")
		Assert.truthy(vis, "still up")
		Assert.near(op, CFG.DIM_OPACITY, 1e-6, "dimmed while moving")
		-- stop and go (CanFF flickering 3 frames on / 5 off): never toggled either
		local flips2 = frames(st, 3, always(true), function(t)
			return math.floor(t / DT + 0.5) % 8 < 3
		end)
		Assert.eq(flips2, 0, "stop and go never toggles it")
		-- stand still: back to full
		local _, vis2, op2 = frames(st, 1, always(true), always(true))
		Assert.truthy(vis2, "up")
		Assert.near(op2, 1, 1e-6, "full when you stand")
	end)

	test("ff pill: hysteresis on FFPending (a short blip neither shows nor hides it)", function()
		local st = FfPill.new()
		local _, vis = frames(st, CFG.SHOW_DELAY * 0.5, always(true), always(true))
		Assert.falsy(vis, "not up before SHOW_DELAY")
		frames(st, 0.2, always(false), always(false))
		Assert.falsy(st.shown, "a blip did not show it")
		frames(st, CFG.SHOW_DELAY + 0.1, always(true), always(true))
		Assert.truthy(st.shown, "shown after SHOW_DELAY")
		frames(st, CFG.HIDE_DELAY * 0.5, always(false), always(false))
		Assert.truthy(st.shown, "a short drop does not hide it")
		local flips = frames(st, 3, function(t)
			return math.floor(t / 0.2) % 2 == 0 -- 0.2 s on / off, shorter than HIDE_DELAY
		end, always(true))
		Assert.eq(flips, 0, "a 0.2 s on/off stream never toggles it")
		local _, gone = frames(st, CFG.HIDE_DELAY + CFG.FADE_SECONDS + 0.1, always(false), always(false))
		Assert.falsy(gone, "gone after HIDE_DELAY and the fade")
	end)

	test("ff pill: fades in and out (no pop), within FADE_SECONDS", function()
		local st = FfPill.new()
		frames(st, CFG.SHOW_DELAY + DT, always(true), always(true))
		local _, vis, op = frames(st, CFG.FADE_SECONDS * 0.5, always(true), always(true))
		Assert.truthy(vis, "visible while fading in")
		Assert.truthy(op > 0.2 and op < 0.8, "partway")
		local _, _, full = frames(st, CFG.FADE_SECONDS, always(true), always(true))
		Assert.near(full, 1, 1e-6, "full")
		Assert.truthy(CFG.HIDE_DELAY > CFG.SHOW_DELAY, "slower to hide than to show")
		Assert.truthy(CFG.DIM_OPACITY >= 0.4 and CFG.DIM_OPACITY < 1, "the dim still reads")
	end)
end
