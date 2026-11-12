-- L1: Audio/Voices, the pure voice rules behind AudioDirector.play: cooldown, per-cue cap, choke, global
-- cap with priority stealing, clone rate and nearest-N, and the round-robin bag.

local Config = require("../../src/shared/Config")
local Voices = require("../../src/shared/Audio/Voices")
local Assert = require("./Assert")

local A = Config.Audio

local function req(cue: string, now: number, extra: { [string]: any }?): Voices.Request
	local r: any = {
		cue = cue,
		now = now,
		length = 1,
		cooldown = 0,
		maxPerCue = 4,
		priority = 2,
	}
	for k, v in extra or {} do
		r[k] = v
	end
	return r
end

-- Deterministic stand-in for Random:NextInteger (a small LCG).
local function lcg(seed: number): (m: number) -> number
	local s = seed
	return function(m: number): number
		s = (s * 1103515245 + 12345) % 2147483648
		return s % m + 1
	end
end

return function(test)
	test("a cue cannot restart inside its cooldown", function()
		local st = Voices.new(24, 6, 4)
		Assert.truthy(Voices.request(st, req("Plate", 0, { cooldown = 0.03 })).ok, "first")
		local d = Voices.request(st, req("Plate", 0.01, { cooldown = 0.03 }))
		Assert.falsy(d.ok, "inside cooldown")
		Assert.eq(d.reason, "cooldown", "reason")
		Assert.truthy(Voices.request(st, req("Plate", 0.05, { cooldown = 0.03 })).ok, "after cooldown")
	end)

	test("beyond maxPerCue the oldest copy of the cue is cut", function()
		local st = Voices.new(24, 6, 4)
		local first = Voices.request(st, req("Grab", 0, { maxPerCue = 2 })).voice :: Voices.Voice
		Voices.request(st, req("Grab", 0.1, { maxPerCue = 2 }))
		local d = Voices.request(st, req("Grab", 0.2, { maxPerCue = 2 }))
		Assert.truthy(d.ok, "third starts")
		Assert.eq(#d.stop, 1, "one cut")
		Assert.eq(d.stop[1].serial, first.serial, "the oldest is cut")
		Assert.eq(Voices.live(st, "Grab"), 2, "cap holds")
	end)

	test("a choking cue stops its own live voices", function()
		local st = Voices.new(24, 6, 4)
		Voices.request(st, req("Busted", 0, { choke = true }))
		local d = Voices.request(st, req("Busted", 0.2, { choke = true }))
		Assert.eq(#d.stop, 1, "previous stopped")
		Assert.eq(Voices.live(st, "Busted"), 1, "one live")
	end)

	test("finished one-shots free their voice; loops do not expire", function()
		local st = Voices.new(24, 6, 4)
		Voices.request(st, req("Tick", 0, { length = 0.5 }))
		Voices.request(st, req("Hum", 0, { length = math.huge }))
		Voices.expire(st, 1)
		Assert.eq(Voices.live(st, "Tick"), 0, "one-shot gone")
		Assert.eq(Voices.live(st, "Hum"), 1, "loop stays")
		local d = Voices.request(st, req("Long", 1, { length = 0.5 }))
		Assert.truthy(Voices.extend(st, (d.voice :: Voices.Voice).serial, 3), "extend a live voice")
		Voices.expire(st, 2)
		Assert.eq(Voices.live(st, "Long"), 1, "extended voice survives its estimate")
		Assert.falsy(Voices.extend(st, 9999, 3), "unknown serial")
		Voices.release(st, (d.voice :: Voices.Voice).serial)
		local hum = st.voices[1]
		Voices.release(st, hum.serial)
		Assert.eq(Voices.live(st), 0, "released")
		Voices.release(st, 9999) -- unknown serial is ignored
	end)

	test("the global cap steals the lowest priority, oldest first, never a higher one", function()
		local st = Voices.new(3, 6, 4)
		Voices.request(st, req("Amb", 0, { priority = 1, length = 10 }))
		Voices.request(st, req("Step", 0.1, { priority = 1, length = 10 }))
		Voices.request(st, req("Bank", 0.2, { priority = 4, length = 10 }))
		local d = Voices.request(st, req("Zap", 0.3, { priority = 3, length = 10 }))
		Assert.truthy(d.ok, "a priority 3 sound gets a voice")
		Assert.eq(d.stop[1].cue, "Amb", "the oldest lowest is stolen")
		Assert.eq(Voices.live(st), 3, "cap holds")
		-- now: Step(1), Bank(4), Zap(3); a priority-1 sound may steal only priority <= 1
		local low = Voices.request(st, req("Radio", 0.4, { priority = 1, length = 10 }))
		Assert.truthy(low.ok and low.stop[1].cue == "Step", "equal priority steals")
		local none = Voices.request(st, req("Hover", 0.5, { priority = 1, length = 10 }))
		Assert.truthy(none.ok and none.stop[1].cue == "Radio", "oldest equal again")
		local st2 = Voices.new(1, 6, 4)
		Voices.request(st2, req("Alarm", 0, { priority = 5, length = math.huge }))
		local dropped = Voices.request(st2, req("Hover", 0.1, { priority = 1 }))
		Assert.falsy(dropped.ok, "cannot steal a higher priority")
		Assert.eq(dropped.reason, "full", "reason")
	end)

	test("at most CLONE_MAX_PER_SECOND clone sounds per rolling second", function()
		local st = Voices.new(64, A.CLONE_MAX_PER_SECOND, 64)
		for i = 1, A.CLONE_MAX_PER_SECOND do
			Assert.truthy(Voices.request(st, req("C" .. i, i * 0.01, { clone = true, length = 0.1 })).ok, "clone " .. i)
		end
		local d = Voices.request(st, req("Cx", 0.5, { clone = true }))
		Assert.falsy(d.ok, "rate limited")
		Assert.eq(d.reason, "cloneRate", "reason")
		Assert.truthy(Voices.request(st, req("Cy", 1.2, { clone = true })).ok, "a second later")
		Assert.truthy(Voices.request(st, req("Live", 0.5, {})).ok, "players' sounds are not clone-limited")
	end)

	test("only the nearest CLONE_VOICED_NEAREST clone voices sound", function()
		local st = Voices.new(64, 100, A.CLONE_VOICED_NEAREST)
		for i = 1, A.CLONE_VOICED_NEAREST do
			Voices.request(st, req("C" .. i, 0, { clone = true, distance = 10 * i, length = 5 }))
		end
		local far = Voices.request(st, req("Far", 0.1, { clone = true, distance = 100, length = 5 }))
		Assert.falsy(far.ok, "a farther clone is dropped")
		Assert.eq(far.reason, "cloneFar", "reason")
		local near = Voices.request(st, req("Near", 0.2, { clone = true, distance = 5, length = 5 }))
		Assert.truthy(near.ok, "a nearer clone gets voiced")
		Assert.eq(near.stop[1].distance, 10 * A.CLONE_VOICED_NEAREST, "the farthest is stolen")
	end)

	test("round-robin bag: every take once per cycle, never twice in a row", function()
		local st = Voices.new(24, 6, 4)
		local random = lcg(7)
		local last = nil
		for cycle = 1, 50 do
			local seen = {}
			for _ = 1, 3 do
				local t = Voices.nextTake(st, "Grab", 3, random)
				Assert.truthy(t >= 1 and t <= 3, "range")
				Assert.truthy(t ~= last, "no repeat (cycle " .. cycle .. ")")
				Assert.falsy(seen[t], "once per cycle")
				seen[t] = true
				last = t
			end
		end
		Assert.eq(Voices.nextTake(st, "One", 1, random), 1, "single take")
	end)
end
