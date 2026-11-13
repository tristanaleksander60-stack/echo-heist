-- L1: the sprint (Config.Sprint; owner, live v125 "make it possible to sprint with Shift"): Shared/Heist/SprintMath's
-- input rule (Shift held, the L3 toggle, the touch stick at its edge), the eased WalkSpeed, the FOV kick under comfort
-- settings, the one-time hint, and Rec/Validator: a sustained sprint with jitter is never tainted or clamped (the
-- normal limit sits above it: no Sprint event needed), while a run faster than the sprint's margin still is.

local Config = require("../../src/shared/Config")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local Validator = require("../../src/shared/Rec/Validator")
local SprintMath = require("../../src/shared/Heist/SprintMath")
local Assert = require("./Assert")

local SP = Config.Sprint
local HZ = Config.Rec.HZ
local WALK = Config.Rec.WALK_SPEED
local G = Codec.FLAG.GROUNDED

-- A straight run in +X at `speed` for `seconds`, with a +-`jitter` stud wobble on every other sample (packet timing).
local function run(speed: number, seconds: number, jitter: number?): Codec.Recording
	local rec = Sampler.new(1, 1, HZ)
	for i = 0, seconds * HZ do
		local wobble = if jitter and i % 2 == 1 then jitter else 0
		Sampler.push(rec, speed * i / HZ + wobble, 3, 0, 0, G)
	end
	return rec
end

return function(test)
	test("sprint numbers: 1.4-1.5x walk, the validator's limit above it with a margin, kicks within the cap", function()
		Assert.truthy(SP.MULT >= 1.4 and SP.MULT <= 1.5, "sprint = 1.4-1.5x walk")
		Assert.truthy(Config.Rec.SPEED_MULT >= SP.MULT * 1.1, "SPEED_MULT keeps >= 10 % over the sprint")
		Assert.le(Config.Rec.SPEED_MULT, SP.MULT * 1.2, "and not much more (no free speed hack room)")
		Assert.le(SP.FOV_KICK + Config.Slide.FOV_KICK, Config.Heist.CAMERA.FOV_KICK_MAX, "kicks")
		Assert.eq(WALK, 16, "walk speed unchanged (the Roblox default)")
	end)

	test("sprint input: Shift held, the L3 toggle, the touch stick at its edge; never standing", function()
		Assert.truthy(SprintMath.wants({ device = "key", shift = true, stick = 1 }, SP), "Shift + moving")
		Assert.falsy(SprintMath.wants({ device = "key", shift = false, stick = 1 }, SP), "no Shift")
		Assert.falsy(SprintMath.wants({ device = "key", shift = true, stick = 0 }, SP), "Shift, standing")
		Assert.truthy(SprintMath.wants({ device = "pad", padOn = true, stick = 0.5 }, SP), "L3 on, half stick")
		Assert.falsy(SprintMath.wants({ device = "pad", padOn = false, stick = 1 }, SP), "L3 off")
		Assert.truthy(SprintMath.wants({ device = "touch", stick = 1 }, SP), "touch: stick at its edge")
		Assert.truthy(SprintMath.wants({ device = "touch", stick = SP.TOUCH_FULL }, SP), "touch: at TOUCH_FULL")
		Assert.falsy(SprintMath.wants({ device = "touch", stick = 0.7 }, SP), "touch: a partial push walks")
		Assert.falsy(SprintMath.wants({ device = "touch", shift = true, stick = 0.5 }, SP), "touch ignores Shift")
	end)

	test("sprint L3 toggle: a press flips it, standing clears it", function()
		local on = SprintMath.padToggle(false, true, true)
		Assert.truthy(on, "pressed while moving: on")
		on = SprintMath.padToggle(on, false, true)
		Assert.truthy(on, "stays on while moving")
		Assert.falsy(SprintMath.padToggle(on, true, true), "pressed again: off")
		Assert.falsy(SprintMath.padToggle(on, false, false), "standing: off")
		Assert.falsy(SprintMath.padToggle(false, true, false), "a press while standing does nothing")
	end)

	test("sprint speed: eased over RAMP_SECONDS, frame-rate independent, back to walk", function()
		local a, b = 0, 0
		for _ = 1, 6 do
			a = SprintMath.ease(a, true, 1 / 60, SP)
		end
		for _ = 1, 3 do
			b = SprintMath.ease(b, true, 1 / 30, SP)
		end
		Assert.near(a, b, 1e-9, "60 fps = 30 fps")
		Assert.truthy(a > 0 and a < 1, "partway after 0.1 s")
		local s = 0
		for _ = 1, 120 do
			s = SprintMath.ease(s, true, 1 / 60, SP)
		end
		Assert.eq(s, 1, "full")
		Assert.near(SprintMath.walkSpeed(WALK, s, SP), WALK * SP.MULT, 1e-9, "sprint speed")
		for _ = 1, 120 do
			s = SprintMath.ease(s, false, 1 / 60, SP)
		end
		Assert.eq(s, 0, "eased off")
		Assert.eq(SprintMath.walkSpeed(WALK, s, SP), WALK, "walk speed")
	end)

	test("sprint camera: the FOV kick follows the share; none under reduced motion or with shake off", function()
		Assert.near(SprintMath.fovKick(1, {}, SP), SP.FOV_KICK, 1e-9, "full kick")
		Assert.eq(SprintMath.fovKick(0, {}, SP), 0, "none walking")
		Assert.eq(SprintMath.fovKick(1, { reduced = true }, SP), 0, "reduced motion")
		Assert.eq(SprintMath.fovKick(1, { shake = false }, SP), 0, "camera shake off")
	end)

	test("sprint hint: once, after walking a while, not on L1, not on touch", function()
		local lvl = "cs2_two_doors"
		Assert.truthy(SprintMath.hintDue(false, lvl, SP.HINT_WALK_SECONDS, "key", SP), "keyboard")
		Assert.truthy(SprintMath.hintDue(false, lvl, SP.HINT_WALK_SECONDS, "pad", SP), "gamepad")
		Assert.falsy(SprintMath.hintDue(false, lvl, SP.HINT_WALK_SECONDS - 0.1, "key", SP), "too soon")
		Assert.falsy(SprintMath.hintDue(true, lvl, 99, "key", SP), "seen")
		Assert.falsy(SprintMath.hintDue(false, SP.HINT_SKIP_LEVEL, 99, "key", SP), "not on L1")
		Assert.falsy(SprintMath.hintDue(false, lvl, 99, "touch", SP), "not on touch")
		Assert.falsy(SprintMath.hintDue(false, nil, 99, "key", SP), "no level")
	end)

	test("validator: a sustained sprint (with packet jitter, 0-300 ms ping) is never tainted or clamped", function()
		for _, ping in { 0, 0.15, 0.3 } do
			for _, jitter in { 0, 0.4 } do
				local report = Validator.validate(run(WALK * SP.MULT, 8, jitter), { ping = ping })
				Assert.falsy(report.tainted, `ping {ping} jitter {jitter}: tainted (flags {report.flags})`)
				Assert.eq(report.clamped, 0, `ping {ping} jitter {jitter}: clamped`)
			end
		end
	end)

	test("validator: past the sprint's margin a run still taints and clamps", function()
		local report = Validator.validate(run(WALK * Config.Rec.SPEED_MULT * 1.1, 4))
		Assert.truthy(report.tainted, "10 % over the limit")
		Assert.hasBit(report.flags, Validator.FLAG.SPEED, "speed")
		Assert.truthy(report.clamped > 0, "clamped")
	end)
end
