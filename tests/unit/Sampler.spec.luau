-- L1: Rec/Sampler recording policy and playback (Catmull-Rom, yaw wrap, cuts, holds).

local Config = require("../../src/shared/Config")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local Assert = require("./Assert")
local Runs = require("./Runs")

local G = Codec.FLAG.GROUNDED

local function straight(n: number, speed: number): Codec.Recording
	local rec = Sampler.new(1, 1, 20)
	for i = 0, n - 1 do
		Sampler.push(rec, i * speed / 20, 3, 0, 0, G)
	end
	return rec
end

return function(test)
	test("exact tick times return the recorded sample", function()
		local rec = Runs.heist45(0.1)
		for _, i in { 1, 2, 57, 300, 901 } do
			local x, y, z, yaw, flags = Sampler.at(rec, (i - 1) / 20)
			Assert.eq(x, rec.px[i], "x " .. i)
			Assert.eq(y, rec.py[i], "y " .. i)
			Assert.eq(z, rec.pz[i], "z " .. i)
			Assert.eq(yaw, rec.yaw[i], "yaw " .. i)
			Assert.eq(flags, rec.flags[i], "flags " .. i)
		end
	end)

	test("Catmull-Rom is exact on a straight constant-speed walk", function()
		local rec = straight(40, 16)
		local x = Sampler.at(rec, 0.525) -- between samples 11 and 12
		Assert.near(x :: number, 0.525 * 16, 1 / 16, "x")
		local vx, vy, vz = Sampler.velocity(rec, 0.525)
		Assert.near(vx, 16, 0.5, "vx")
		Assert.near(vy, 0, 1e-9, "vy")
		Assert.near(vz, 0, 1e-9, "vz")
	end)

	test("yaw takes the shortest arc across the wrap", function()
		local rec = Sampler.new(1, 1, 20)
		Sampler.push(rec, 0, 3, 0, math.rad(350), G)
		Sampler.push(rec, 0, 3, 0, math.rad(10), G)
		local _, _, _, yaw = Sampler.at(rec, 0.025)
		local d = math.abs((yaw - 0 + math.pi) % (2 * math.pi) - math.pi)
		Assert.le(d, math.rad(1.5), "midpoint near 0 degrees, got " .. math.deg(yaw))
	end)

	test("before 0 gives the first sample; after the end the clone holds its last pose", function()
		local rec = straight(20, 16)
		Assert.eq((Sampler.at(rec, -5)), rec.px[1], "before start")
		Assert.eq((Sampler.at(rec, 100)), rec.px[20], "after end")
		Assert.truthy(Sampler.isHolding(rec, 0.95), "holding at last sample time")
		Assert.falsy(Sampler.isHolding(rec, 0.9), "not holding before it")
		local vx = Sampler.velocity(rec, 50)
		Assert.eq(vx, 0, "no velocity while holding")
	end)

	test("run ended early: shorter recording, holds the END RUN pose", function()
		local rec = straight(200, 16) -- 10 s
		Sampler.finish(rec, Codec.END.EndRun)
		Assert.falsy(Sampler.push(rec, 0, 0, 0, 0, 0), "no samples after finish")
		Assert.eq(rec.n, 200, "n")
		Assert.near(Sampler.duration(rec), 9.95, 1e-9, "duration")
		Assert.eq((Sampler.at(rec, 30)), rec.px[200], "holds")
		local out = assert(Codec.decode(Codec.encode(rec)))
		Assert.eq(out.endReason, Codec.END.EndRun, "end reason survives")
	end)

	test("never interpolates across a cut (server teleport)", function()
		local rec = Sampler.new(1, 1, 20)
		Sampler.push(rec, 0, 3, 0, 0, G)
		Sampler.push(rec, 1, 3, 0, 0, G)
		Sampler.addEvent(rec, 0.1, Codec.EVENT.Respawn, 0)
		Sampler.push(rec, 500, 3, 500, 0, G, true)
		Sampler.push(rec, 501, 3, 500, 0, G)
		local x = Sampler.at(rec, 0.075) :: number
		Assert.eq(x, 1, "holds before the cut")
		local vx = Sampler.velocity(rec, 0.075)
		Assert.eq(vx, 0, "no velocity spike across the cut")
		-- After the cut the spline does not reach back across it.
		local x2 = Sampler.at(rec, 0.125) :: number
		Assert.truthy(x2 >= 500 and x2 <= 501, "after cut stays on the new segment: " .. x2)
	end)

	test("samples are snapped to the codec grid when recorded", function()
		local rec = Sampler.new(1, 1, 20)
		Sampler.push(rec, 1.01, 3.0312, -7.77, 0.123, G)
		Assert.eq(rec.px[1] * 16, math.floor(rec.px[1] * 16), "x on grid")
		Assert.eq(rec.pz[1] * 16, math.floor(rec.pz[1] * 16), "z on grid")
		Assert.eq(rec.yaw[1], Codec.snapYaw(0.123), "yaw on grid")
	end)

	test("a skipped tick repeats the last sample; stale ticks are ignored", function()
		local rec = Sampler.new(1, 1, 20)
		Assert.truthy(Sampler.record(rec, 0, 0, 3, 0, 0, G), "tick 0")
		Assert.truthy(Sampler.record(rec, 3, 3, 3, 0, 0, G), "tick 3")
		Assert.eq(rec.n, 4, "n")
		Assert.eq(rec.px[2], 0, "gap repeat 1")
		Assert.eq(rec.px[3], 0, "gap repeat 2")
		Assert.eq(rec.px[4], 3, "tick 3 value")
		Assert.falsy(Sampler.record(rec, 3, 9, 3, 0, 0, G), "duplicate tick")
		Assert.falsy(Sampler.record(rec, 1, 9, 3, 0, 0, G), "stale tick")
		Assert.eq(rec.n, 4, "n unchanged")
	end)

	test("first tick missed: the run starts where it is first seen", function()
		local rec = Sampler.new(1, 1, 20)
		Sampler.record(rec, 2, 5, 3, 5, 0, G)
		Assert.eq(rec.n, 3, "n")
		Assert.eq(rec.px[1], 5, "back-filled")
	end)

	test("capacity is the 90 s hard ceiling", function()
		local rec = Sampler.new(1, 1, 20)
		local cap = Sampler.capacity(20)
		Assert.eq(cap, Config.Rec.LOOP_MAX_SECONDS * 20 + 1, "capacity")
		Assert.truthy(Sampler.record(rec, cap - 1, 0, 3, 0, 0, G), "last tick")
		Assert.falsy(Sampler.record(rec, cap, 0, 3, 0, 0, G), "past the ceiling")
		Assert.eq(rec.n, cap, "n")
	end)

	test("empty run: at() gives nil, velocity 0, holding", function()
		local rec = Sampler.new(1, 1, 20)
		Assert.eq((Sampler.at(rec, 1)), nil, "at")
		local vx = Sampler.velocity(rec, 1)
		Assert.eq(vx, 0, "velocity")
		Assert.truthy(Sampler.isHolding(rec, 0), "holding")
		Assert.eq(Sampler.duration(rec), 0, "duration")
	end)

	test("one-frame run: the same pose at every t", function()
		local rec = Sampler.new(1, 1, 20)
		Sampler.push(rec, 4, 3, 2, 1, G)
		for _, t in { -1, 0, 0.01, 0.5, 60 } do
			local x, _, z = Sampler.at(rec, t)
			Assert.eq(x, 4, "x at " .. t)
			Assert.eq(z, 2, "z at " .. t)
		end
		Assert.eq(Sampler.velocity(rec, 0.02), 0, "velocity")
		Assert.eq(Sampler.duration(rec), 0, "duration")
	end)

	test("event cursor fires each event once, in order", function()
		local rec = straight(100, 8)
		Sampler.addEvent(rec, 0.5, Codec.EVENT.Press, 1)
		Sampler.addEvent(rec, 0.5, Codec.EVENT.Grab, 2)
		Sampler.addEvent(rec, 2.0, Codec.EVENT.Release, 2)
		local fired = {}
		local cursor = 0
		for tick = 0, 99 do
			local last = Sampler.eventsDue(rec, cursor, tick / 20)
			for k = cursor + 1, last do
				table.insert(fired, rec.events[k].kind)
			end
			cursor = last
		end
		Assert.eq(#fired, 3, "count")
		Assert.eq(fired[1], Codec.EVENT.Press, "order 1")
		Assert.eq(fired[3], Codec.EVENT.Release, "order 3")
	end)

	test("event limit and arg clamping", function()
		local rec = Sampler.new(1, 1, 20)
		for _ = 1, Config.Rec.MAX_EVENTS do
			Assert.truthy(Sampler.addEvent(rec, 0, Codec.EVENT.Emote, 1), "add")
		end
		Assert.falsy(Sampler.addEvent(rec, 0, Codec.EVENT.Emote, 1), "over the limit")
		local r2 = Sampler.new(1, 1, 20)
		Sampler.addEvent(r2, 0, Codec.EVENT.Grab, 99999)
		Assert.eq(r2.events[1].arg, 65535, "arg clamps to u16")
	end)
end
