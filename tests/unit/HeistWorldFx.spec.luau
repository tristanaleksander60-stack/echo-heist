-- L1: Heist/WorldFx, the maths behind the world-side feedback (docs/FEEDBACK_TABLE.md): the plate and door springs
-- (overshoot and settle times from Config.WorldFx), the drop bounce, the squash, the glint stagger, the coin burst
-- cap, the "+$100!" and "VAULT n/4" words, the hide outline's distance and the haptics gate.

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local WorldFx = require("../../src/shared/Heist/WorldFx")

local F = Config.WorldFx

-- runs a spring from 0 to 1 at 60 fps; returns the peak, its time and when it stays within 2 % for good
local function step(s: any, seconds: number, dt: number?): (number, number, number)
	local h = dt or 1 / 60
	local x, v = 0, 0
	local peak, peakAt, settledAt = 0, 0, 0
	local t = 0
	while t < seconds do
		x, v = WorldFx.spring(x, v, 1, h, s)
		t += h
		if x > peak then
			peak, peakAt = x, t
		end
		if math.abs(x - 1) > 0.02 then
			settledAt = t
		end
	end
	return peak, peakAt, settledAt
end

return function(test: (string, () -> ()) -> ())
	test("spring: exact (any frame rate lands on the same curve), settles on the target", function()
		local s = F.DOOR_SPRING
		local a = { step(s, 2, 1 / 60) }
		local b = { step(s, 2, 1 / 240) }
		Assert.near(a[1], b[1], 0.02, "same peak at 60 and 240 fps")
		local x, v = 0, 0
		for _ = 1, 30 do
			x, v = WorldFx.spring(x, v, 1, 0.1, s)
		end
		Assert.near(x, 1, 1e-3, "settles on the target")
		Assert.near(v, 0, 1e-2, "and stops")
		-- a huge dt is still stable (a hitch never throws a door across the map)
		x, v = WorldFx.spring(0, 0, 1, 5, s)
		Assert.truthy(math.abs(x - 1) < 0.01, "a 5 s hitch lands on the target")
		-- critically damped: no overshoot
		local peak = step({ hz = 3, damping = 1 }, 3)
		Assert.truthy(peak <= 1 + 1e-6, "damping 1 never overshoots")
		local x1, v1 = WorldFx.settle(0.9995, 0, 1, 1 / 60, s)
		Assert.truthy(x1 == 1 and v1 == 0, "settle snaps a negligible offset")
	end)

	test("plate: sinks with a ~0.1 s overshoot (FEEDBACK_TABLE Plate)", function()
		local over, peakAt = WorldFx.overshoot(F.PLATE_SPRING)
		Assert.truthy(over >= 0.1 and over <= 0.3, "overshoot " .. over .. " of the 0.15 sink")
		local _, _, settled = step(F.PLATE_SPRING, 1)
		Assert.truthy(peakAt <= 0.08, "peaks by 0.08 s (" .. peakAt .. ")")
		Assert.truthy(settled <= 0.2, "settles within 0.2 s (" .. settled .. ")")
		Assert.near(Config.Heist.PLATE_SINK, 0.15, 1e-9, "sinks 0.15 studs")
	end)

	test("door: slides with a small overshoot, settles about as fast as the old 0.35 s slide", function()
		local over, peakAt = WorldFx.overshoot(F.DOOR_SPRING)
		Assert.truthy(over > 0.03 and over < 0.15, "overshoot " .. over)
		Assert.truthy(peakAt > 0.2 and peakAt < 0.45, "peak at " .. peakAt)
		local _, _, settled = step(F.DOOR_SPRING, 2)
		Assert.truthy(settled < 0.7, "settles within 0.7 s (" .. settled .. ")")
	end)

	test("loot: squash on grab rings back to 1, a drop hops twice and rests", function()
		local s, v = -F.SQUASH.amount, 0
		local sy, sxz = WorldFx.squashScale(s)
		Assert.truthy(sy < 1 and sxz > 1, "squashed: shorter and wider")
		for _ = 1, 120 do
			s, v = WorldFx.spring(s, v, 0, 1 / 60, F.SQUASH)
		end
		sy, sxz = WorldFx.squashScale(s)
		Assert.near(sy, 1, 0.01, "back to height")
		Assert.near(sxz, 1, 0.01, "back to width")
		local B = F.BOUNCE
		Assert.eq(WorldFx.bounce(0, B), 0, "starts on the floor")
		Assert.eq(WorldFx.bounce(B.seconds, B), 0, "rests at the end")
		local peak, landings, last = 0, 0, 1
		for k = 1, 199 do
			local h = WorldFx.bounce(B.seconds * k / 200, B)
			Assert.truthy(h >= 0 and h <= B.height + 1e-9, "never under the floor or over the height")
			peak = math.max(peak, h)
			if h < 0.02 and last >= 0.02 then
				landings += 1
			end
			last = h
		end
		Assert.near(peak, B.height, 0.02, "the first hop reaches the height")
		Assert.eq(landings, B.hops - 1, "touches down between hops (the last landing is the end)")
	end)

	test("glint: one every GLINT_PERIOD per item, items staggered", function()
		local beats = {}
		for i = 1, 4 do
			local n, last = 0, WorldFx.glintBeat(0, i, F.GLINT_PERIOD)
			for k = 1, 1200 do
				local b = WorldFx.glintBeat(k / 60, i, F.GLINT_PERIOD)
				if b ~= last then
					n += 1
					if n == 1 then
						beats[i] = k / 60
					end
					last = b
				end
			end
			Assert.eq(n, 10, "10 glints in 20 s for item " .. i)
		end
		Assert.truthy(beats[1] ~= beats[2] and beats[2] ~= beats[3], "items glint at different moments")
		Assert.truthy(1 / F.GLINT_PERIOD <= Config.Heist.BLINK_HZ_MAX, "under the flash cap")
	end)

	test("van bank: <= 24 coins, scaled down on low tiers, words", function()
		Assert.truthy(F.COINS <= 24, "Config: at most 24 coins")
		Assert.eq(WorldFx.coinCount(24, 1), 24, "full burst")
		Assert.eq(WorldFx.coinCount(24, 0.5), 12, "half on a low tier")
		Assert.eq(WorldFx.coinCount(40, 1), 24, "never more than 24")
		Assert.truthy(WorldFx.coinCount(24, 0) >= 4, "a few coins even at 0")
		Assert.eq(WorldFx.bankText(100), "+$100!", "the pop")
		Assert.eq(WorldFx.bankText(2000.4), "+$2000!", "rounded")
		Assert.eq(WorldFx.vaultText(2, 4), "VAULT 2/4", "the vault count")
		Assert.eq(WorldFx.vaultText(7, 4), "VAULT 4/4", "clamped")
		local over = WorldFx.overshoot(F.VAN_BOUNCE)
		Assert.truthy(over > 0.2, "the van bounces (overshoot " .. over .. ")")
	end)

	test("hide outline: distance to the hide's footprint", function()
		local box = { minX = -15, maxX = -9, minZ = -26, maxZ = -20.5 }
		Assert.eq(WorldFx.footprintDistance(-12, -23, box), 0, "inside")
		Assert.near(WorldFx.footprintDistance(-12, -14.5, box), 6, 1e-9, "6 studs in front")
		Assert.near(WorldFx.footprintDistance(-6, -17.5, box), math.sqrt(18), 1e-9, "off the corner")
		Assert.eq(Config.Lighting.HIDE_OUTLINE.near, 6, "FEEDBACK_TABLE: within 6 studs")
	end)

	test("haptics: phones only, behind the switch, reduced motion, the setting and a rate cap", function()
		local base = {
			enabled = true,
			touch = true,
			keyboard = false,
			reduced = false,
			setting = nil,
			sinceLast = 1,
			minGap = F.HAPTIC_MIN_GAP,
		}
		local function with(k: string, v: any): any
			local t = table.clone(base)
			t[k] = v
			return t
		end
		Assert.truthy(WorldFx.hapticAllowed(base), "a phone")
		Assert.falsy(WorldFx.hapticAllowed(with("enabled", false)), "Config switch off")
		Assert.falsy(WorldFx.hapticAllowed(with("touch", false)), "no touch: not a phone")
		Assert.falsy(WorldFx.hapticAllowed(with("keyboard", true)), "a touch laptop is not a phone")
		Assert.falsy(WorldFx.hapticAllowed(with("reduced", true)), "reduced motion")
		Assert.falsy(WorldFx.hapticAllowed(with("setting", false)), "the player's setting off")
		Assert.truthy(WorldFx.hapticAllowed(with("setting", true)), "the player's setting on")
		Assert.falsy(WorldFx.hapticAllowed(with("sinceLast", 0.05)), "rate cap")
		Assert.truthy(F.HAPTIC_MIN_GAP >= 0.1, "<= 10 pulses a second")
		for _, verb in { "plate", "grab", "bank" } do
			local name = F.HAPTIC_TYPES[verb]
			Assert.truthy(
				name == "UIClick" or name == "UINotification" or name == "GameplayCollision" or name == "UIHover",
				verb .. ": a HapticEffectType"
			)
		end
	end)
end
