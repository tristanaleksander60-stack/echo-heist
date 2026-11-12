-- L1: Rec/LoopClock time base, fast-forward, squeeze, fixed-step ticks, lag fairness.

local Config = require("../../src/shared/Config")
local LoopClock = require("../../src/shared/Rec/LoopClock")
local Assert = require("./Assert")

local START = 1763000000.25 -- a realistic GetServerTimeNow() value

return function(test)
	test("loop time maps from server time and clamps to the run", function()
		local c = LoopClock.new(START, 30)
		Assert.eq(LoopClock.t(c, START), 0, "start")
		Assert.near(LoopClock.t(c, START + 12.5), 12.5, 1e-6, "mid")
		Assert.eq(LoopClock.t(c, START - 3), 0, "before start clamps")
		Assert.eq(LoopClock.t(c, START + 99), 30, "after end clamps")
		Assert.near(LoopClock.rawT(c, START - 3), -3, 1e-6, "raw is unclamped")
		Assert.near(LoopClock.remaining(c, START + 20), 10, 1e-6, "remaining")
		Assert.falsy(LoopClock.isOver(c, START + 29.9), "not over")
		Assert.truthy(LoopClock.isOver(c, START + 30), "over")
	end)

	test("serverTimeAt is the inverse mapping", function()
		local c = LoopClock.new(START, 45)
		Assert.near(LoopClock.serverTimeAt(c, 10), START + 10, 1e-6, "1x")
		local ff = LoopClock.setRate(c, START + 10, 3)
		Assert.near(LoopClock.serverTimeAt(ff, 16), START + 12, 1e-6, "3x")
		Assert.near(LoopClock.t(ff, LoopClock.serverTimeAt(ff, 20)), 20, 1e-6, "round trip")
	end)

	test("fast-forward re-anchors without a jump, then runs at 3x", function()
		local c = LoopClock.new(START, 45)
		local now = START + 8
		local ff = LoopClock.setRate(c, now, Config.Rec.SKIP_SPEED)
		Assert.near(LoopClock.t(ff, now), 8, 1e-6, "continuous at switch")
		Assert.near(LoopClock.t(ff, now + 1), 11, 1e-6, "3 loop seconds per second")
		local back = LoopClock.setRate(ff, now + 1, 1)
		Assert.near(LoopClock.t(back, now + 2), 12, 1e-6, "back to 1x")
		Assert.eq(back.length, 45, "length unchanged")
	end)

	test("waiting squeeze: remaining becomes min(remaining, 10 s)", function()
		local c = LoopClock.new(START, 45)
		local s = LoopClock.squeeze(c, START + 5)
		Assert.near(LoopClock.remaining(s, START + 5), Config.Rec.WAIT_SQUEEZE_SECONDS, 1e-6, "squeezed")
		local late = LoopClock.squeeze(c, START + 40)
		Assert.near(LoopClock.remaining(late, START + 40), 5, 1e-6, "already under 10 s: unchanged")
	end)

	test("Relaxed lengthens runs (+50%) up to the 90 s ceiling", function()
		Assert.eq(LoopClock.lengthFor(30, false), 30, "normal")
		Assert.eq(LoopClock.lengthFor(30, true), 45, "relaxed")
		Assert.eq(LoopClock.lengthFor(75, true), Config.Rec.LOOP_MAX_SECONDS, "ceiling")
		Assert.falsy(pcall(LoopClock.new, START, 91), "over the ceiling is refused")
		Assert.falsy(pcall(LoopClock.new, START, 0), "zero length is refused")
	end)

	test("END RUN is locked for the first 1.5 s", function()
		local c = LoopClock.new(START, 30)
		Assert.falsy(LoopClock.canEndRun(c, START + 1.49), "locked")
		Assert.truthy(LoopClock.canEndRun(c, START + Config.Rec.END_RUN_LOCK_SECONDS), "unlocked")
	end)

	test("tick index and tick time agree for every tick of a 90 s run", function()
		for k = 0, 90 * 20 do
			Assert.eq(LoopClock.tickAt(LoopClock.timeOfTick(k, 20), 20), k, "tick " .. k)
		end
	end)

	test("fixed-step accumulator runs every tick exactly once over a run", function()
		local c = LoopClock.new(START, 30)
		local nextTick = 0
		local total = 0
		local frame = 1 / 60
		local now = START - 0.5
		while now < START + 31 do
			local due = LoopClock.ticksDue(c, now, nextTick, 20)
			nextTick += due
			total += due
			now += frame
		end
		Assert.eq(total, 30 * 20 + 1, "ticks 0..600")
		Assert.eq(LoopClock.lastTick(c, 20), 600, "last tick")
	end)

	test("fast-forward runs 3x the ticks per real second", function()
		local c = LoopClock.setRate(LoopClock.new(START, 45), START, 3)
		local nextTick = 0
		for frame = 0, 60 do
			nextTick += LoopClock.ticksDue(c, START + frame / 60, nextTick, 20)
		end
		Assert.eq(nextTick, 61, "ticks 0..60 in one real second")
	end)

	test("a server hitch is caught up in capped batches", function()
		local c = LoopClock.new(START, 30)
		local due = LoopClock.ticksDue(c, START + 2, 0, 20)
		Assert.eq(due, Config.Rec.MAX_CATCHUP_TICKS, "capped")
		local nextTick = due
		while LoopClock.ticksDue(c, START + 2, nextTick, 20) > 0 do
			nextTick += LoopClock.ticksDue(c, START + 2, nextTick, 20)
		end
		Assert.eq(nextTick, 41, "caught up to tick 40")
		Assert.eq(LoopClock.ticksDue(c, START - 1, 0, 20), 0, "nothing before start")
	end)

	test("lag fairness: hazards rewound by latency, capped at 150 ms", function()
		Assert.near(LoopClock.hazardTime(10, 0.08), 9.92, 1e-9, "80 ms")
		Assert.near(LoopClock.hazardTime(10, 0.4), 10 - Config.Rec.LAG_REWIND_CAP, 1e-9, "cap")
		Assert.eq(LoopClock.hazardTime(0.05, 0.1), 0, "not before 0")
		Assert.eq(LoopClock.hazardTime(5, -1), 5, "negative latency ignored")
		Assert.eq(LoopClock.hazardTime(5, 0 / 0), 5, "NaN latency ignored")
	end)
end
