-- L1: flash and motion limits (MASTERPLAN §7.3 "3/s flash cap", §7.4 accessibility). The views
-- blink only at Config.Heist.BLINK_HZ_MAX or slower; these specs pin the timing constants
-- they use, so a later tweak cannot push a blink past the cap unnoticed.

local Config = require("../../src/shared/Config")
local Assert = require("./Assert")

local H = Config.Heist

return function(test)
	test("blinks: never faster than 3 flashes per second", function()
		Assert.truthy(H.BLINK_HZ_MAX <= 3, "BLINK_HZ_MAX <= 3")
		Assert.truthy(1 / H.ALARM_PULSE_SECONDS <= H.BLINK_HZ_MAX, "the alarm vignette pulse")
		Assert.truthy(1 / H.GUS_HEARTBEAT_SECONDS <= H.BLINK_HZ_MAX, "Gus's heartbeat tick")
	end)

	test("party and tutorial pacing knobs stay sane", function()
		Assert.truthy(
			H.PARTY_BETWEEN_SECONDS >= 5 and H.PARTY_BETWEEN_SECONDS < H.BETWEEN_MAX_SECONDS,
			"party auto-start"
		)
		Assert.truthy(H.END_RUN_GRAB_GUARD > 0 and H.END_RUN_GRAB_GUARD <= 0.5, "END RUN guard after GRAB")
		Assert.truthy(H.LINEUP_SKIP_AFTER_POSE >= 0, "first-cut skip after the pose")
		Assert.truthy(H.CLONE_NEAR_UNFADE > H.CLONE_NEAR_FADE, "near-camera fade has hysteresis")
	end)

	test("HUD fits a 360-dp phone in landscape at the smallest scale", function()
		local d = H.UI_DESIGN_SIZE
		-- ~300 px of safe height under the Roblox top bar: the whole design canvas still fits.
		Assert.truthy(d[2] * H.UI_SCALE_MIN <= 300, "design height x min scale <= 300 px")
		Assert.truthy(H.TAP_MIN * H.UI_SCALE_MIN >= 64, "every tap target >= 64 px")
	end)

	test("instance slots: unique cells, never the lobby, within ~4,300 studs", function()
		local seen = {}
		Assert.truthy(#H.INSTANCE_SLOTS >= H.MAX_INSTANCES, "a cell for every instance")
		for _, cell in H.INSTANCE_SLOTS do
			local key = cell[1] .. "," .. cell[2]
			Assert.falsy(seen[key], "unique cell " .. key)
			seen[key] = true
			Assert.falsy(cell[1] == 0 and cell[2] == 0, "not the lobby cell")
			local dist = math.sqrt(cell[1] ^ 2 + cell[2] ^ 2) * H.INSTANCE_SPACING
			Assert.truthy(dist <= 4300, "slot within ~4,300 studs of the origin")
		end
	end)
end
