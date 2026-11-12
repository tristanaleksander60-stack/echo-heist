-- L1: Heist/RunMarkers: the run bar's next-event markers (Gus's turn points, the laser on-spans
-- your clones' plates leave), MASTERPLAN §7.4 #1, premium §6.4.

local Assert = require("./Assert")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local RunMarkers = require("../../src/shared/Heist/RunMarkers")
local TestLevels = require("../sim/TestLevels")

local HZ = 20

-- A clone that stands at (x, z) from tOn to tOff and elsewhere (0, 10) otherwise.
local function standing(x: number, z: number, tOn: number, tOff: number, length: number, endReason: number?): any
	local rec = Sampler.new(nil, nil, HZ)
	for i = 0, math.floor(length * HZ) do
		local t = i / HZ
		local on = t >= tOn and t < tOff
		Sampler.push(rec, if on then x else 0, 3, if on then z else 10, 0, 0)
	end
	Sampler.finish(rec, endReason or Codec.END.EndRun)
	return rec
end

return function(test)
	test("Gus: a tick at every corner of a square patrol, repeated each period, inside the run", function()
		local level = TestLevels.watch({
			route = { { x = 0, z = 0 }, { x = 10, z = 0 }, { x = 10, z = 10 }, { x = 0, z = 10 } },
		})
		local route = level.guards[1].route
		local length = route.period * 2.5
		local ticks = RunMarkers.gusTurns(level, length, 35, 100)
		Assert.eq(#ticks, 10, "4 corners x 2 periods + 2 of the half period")
		Assert.near(ticks[1], route.legs[1].tArrive, 1e-9, "first corner")
		Assert.near(ticks[5], route.legs[1].tArrive + route.period, 1e-9, "repeats each period")
		for i = 2, #ticks do
			Assert.truthy(ticks[i] >= ticks[i - 1], "sorted")
			Assert.truthy(ticks[i] <= length, "inside the run")
		end
		Assert.eq(#RunMarkers.gusTurns(level, length, 35, 3), 3, "capped")
	end)

	test("Gus: straight-through points do not tick; a wait does", function()
		local straight = TestLevels.watch({ route = { { x = 0, z = 0 }, { x = 5, z = 0 }, { x = 10, z = 0 } } })
		-- 0 -> 5 -> 10 -> back to 0: only the far end (10) and the start (0) turn
		local ticks = RunMarkers.gusTurns(straight, straight.guards[1].route.period - 1e-6, 35, 100)
		Assert.eq(#ticks, 1, "the far end only within one period (the start comes back at the period)")
		local waits = TestLevels.watch()
		Assert.truthy(#RunMarkers.gusTurns(waits, 30, 35, 100) >= 1, "standing guard: his wait counts")
	end)

	test("lasers: the on-spans around the window a clone on the plate opens", function()
		local level = TestLevels.corridor() -- laser Grid is off while plate Q (x -12..-8, z -7..-3) is held
		local rec = standing(-10, -5, 3, 6, 10)
		local lasers = RunMarkers.laserSpans(level, { rec }, 10, 10)
		Assert.eq(#lasers, 1, "one laser")
		local spans = lasers[1].on
		Assert.eq(#spans, 2, "on before and after the window")
		Assert.near(spans[1].t0, 0, 1e-9, "on from the start")
		Assert.near(spans[1].t1, 3, 0.11, "off once the clone stands on Q")
		Assert.truthy(spans[2].t0 >= 6 and spans[2].t0 <= 6 + 0.6, "back on after the plate grace")
		Assert.near(spans[2].t1, 10, 1e-9, "on to the end")
	end)

	test("lasers: none when no clone ever switches it off; a zapped clone stops pressing", function()
		local level = TestLevels.corridor()
		Assert.eq(#RunMarkers.laserSpans(level, { standing(5, 5, 0, 10, 10) }, 10, 10), 0, "never off: no marker")
		Assert.eq(#RunMarkers.laserSpans(level, {}, 10, 10), 0, "no clones")
		-- a recording that ends on the plate holds the pose (the laser stays off) ...
		local held = standing(-10, -5, 2, 99, 4)
		local spans = RunMarkers.laserSpans(level, { held }, 10, 10)[1].on
		Assert.eq(#spans, 1, "on only before the clone arrives")
		-- ... unless it was zapped: then it leaves the run when its recording ends
		local zapped = standing(-10, -5, 2, 99, 4, Codec.END.Zapped)
		local zs = RunMarkers.laserSpans(level, { zapped }, 10, 10)[1].on
		Assert.eq(#zs, 2, "on again after the zapped clone is gone")
	end)
end
