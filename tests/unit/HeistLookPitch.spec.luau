-- L1: Heist/LookPitch (look up / down on other screens, Config.Rookie.LOOK): the quantiser and its wire range (inside
-- the Heist.Ready n range), the validator on the Ready "look" table, the Neck / Waist split and clamp, the follow and
-- the 10 Hz send gate.

local Config = require("../../src/shared/Config")
local LookPitch = require("../../src/shared/Heist/LookPitch")
local VanRules = require("../../src/shared/Heist/VanRules")
local Assert = require("./Assert")

local L = Config.Rookie.LOOK

return function(test: (string, () -> ()) -> ())
	test("quantiser: steps, clamp, round trip, inside the Ready n range", function()
		Assert.truthy(LookPitch.STEPS <= 64, "fits VanRules' n (1..64)")
		local mid = LookPitch.quantise(0)
		Assert.eq(LookPitch.degrees(mid), 0, "level is 0")
		Assert.eq(LookPitch.quantise(1000), LookPitch.STEPS, "clamped up")
		Assert.eq(LookPitch.quantise(-1000), 1, "clamped down")
		Assert.eq(LookPitch.degrees(LookPitch.STEPS), L.MAX_DEG, "top = MAX_DEG")
		Assert.eq(LookPitch.degrees(1), -L.MAX_DEG, "bottom = -MAX_DEG")
		Assert.eq(LookPitch.quantise(0 / 0), mid, "NaN reads level")
		Assert.eq(LookPitch.quantise(math.huge), mid, "inf reads level")
		for d = -L.MAX_DEG, L.MAX_DEG, 0.7 do
			local n = LookPitch.quantise(d)
			Assert.truthy(LookPitch.validN(n), "valid n for " .. d)
			Assert.truthy(math.abs(LookPitch.degrees(n) - d) <= L.STEP_DEG / 2 + 1e-9, "within half a step of " .. d)
		end
		Assert.truthy(LookPitch.quantise(30) > mid, "up is above the middle")
	end)

	test("validator: the Ready look table and the attribute value", function()
		Assert.truthy(VanRules.validReadyArg({ op = "look", n = 1 }), "lowest")
		Assert.truthy(VanRules.validReadyArg({ op = "look", n = LookPitch.STEPS }), "highest")
		local bad: { any } = {
			{ op = "look" }, -- needs n
			{ op = "look", n = 0 },
			{ op = "look", n = LookPitch.STEPS + 1 },
			{ op = "look", n = 64 },
			{ op = "look", n = 2.5 },
			{ op = "look", n = 0 / 0 },
			{ op = "look", n = math.huge },
			{ op = "look", n = "3" },
			{ op = "look", n = 3, bay = 1 }, -- no bay
			{ op = "look", n = 3, x = 1 },
		}
		for i, a in bad do
			Assert.falsy(VanRules.validReadyArg(a), "bad look #" .. i)
		end
		Assert.truthy(LookPitch.validDegrees(0) and LookPitch.validDegrees(-L.MAX_DEG), "in range")
		Assert.falsy(LookPitch.validDegrees(L.MAX_DEG + 1), "out of range")
		Assert.falsy(LookPitch.validDegrees(0 / 0), "NaN")
		Assert.falsy(LookPitch.validDegrees("10"), "a string")
		Assert.falsy(LookPitch.validN(nil), "nil n")
	end)

	test("tilt: shares of the pitch, Neck within NECK_MAX and Waist within WAIST_MAX", function()
		local n0, w0 = LookPitch.split(0)
		Assert.eq(n0, 0, "level neck")
		Assert.eq(w0, 0, "level waist")
		local n1, w1 = LookPitch.split(20)
		Assert.truthy(math.abs(n1 - 20 * L.NECK_SHARE) < 1e-9 and math.abs(w1 - 20 * L.WAIST_SHARE) < 1e-9, "shares")
		Assert.truthy(n1 > 0 and w1 > 0, "up tilts up")
		for _, d in { -500, -L.MAX_DEG, -45, 45, L.MAX_DEG, 500 } do
			local n, w = LookPitch.split(d)
			Assert.truthy(math.abs(n) <= L.NECK_MAX + 1e-9, "neck clamp at " .. d)
			Assert.truthy(math.abs(w) <= L.WAIST_MAX + 1e-9, "waist clamp at " .. d)
		end
		Assert.truthy(L.NECK_MAX <= 40 and L.WAIST_MAX <= 20, "the limits stay human")
		local nn, wn = LookPitch.split(0 / 0)
		Assert.eq(nn + wn, 0, "NaN tilts nothing")
	end)

	test("follow and the send gate", function()
		local x = 0
		for _ = 1, 120 do
			x = LookPitch.follow(x, 40, 1 / 60)
		end
		Assert.truthy(math.abs(x - 40) < 0.5, "settles on the target in 2 s")
		local one = LookPitch.follow(0, 40, 1 / 60)
		Assert.truthy(one > 0 and one < 40, "a frame moves part of the way")
		Assert.eq(LookPitch.follow(10, 10, 1 / 60), 10, "no change at the target")
		Assert.eq(LookPitch.follow(0 / 0, 0, 1 / 60), 0, "NaN current recovers")
		Assert.truthy(LookPitch.shouldSend(5, nil, 0, nil), "the first value goes")
		Assert.falsy(LookPitch.shouldSend(5, 5, 10, 0), "no change: nothing")
		Assert.falsy(LookPitch.shouldSend(6, 5, 0.05, 0), "too soon (10 Hz)")
		Assert.truthy(LookPitch.shouldSend(6, 5, 0.1, 0), "after 0.1 s")
	end)
end
