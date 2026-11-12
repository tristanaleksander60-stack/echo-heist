-- L1: Analytics/PerfSample (frame-time histogram, governor, device class, remote payload).

local Config = require("../../src/shared/Config")
local Events = require("../../src/shared/Analytics/Events")
local PerfSample = require("../../src/shared/Analytics/PerfSample")
local Assert = require("./Assert")

local P = Config.Analytics.Perf

local function exactPercentile(times: { number }, q: number): number
	local sorted = table.clone(times)
	table.sort(sorted)
	return sorted[math.max(1, math.ceil(q * #sorted))]
end

local function device(o: { [string]: any }): string
	local d: { [string]: any } =
		{ touch = false, keyboard = true, gamepad = false, vr = false, tenFoot = false, viewportMin = 1080 }
	for k, v in o do
		d[k] = v
	end
	return PerfSample.deviceClass(d :: any)
end

return function(test)
	test("percentiles match an exact sort to the bin width", function()
		local w = PerfSample.new()
		local times = {}
		local seed = 12345
		for i = 1, 3600 do
			seed = (seed * 1103515245 + 12345) % 2147483648
			-- mostly 14-20 ms, a tail of hitches up to 60 ms
			local ms = 14 + (seed % 600) / 100 + (if i % 37 == 0 then 30 + (seed % 1000) / 50 else 0)
			table.insert(times, ms)
			Assert.truthy(PerfSample.add(w, ms / 1000), "added")
		end
		local s = PerfSample.summary(w) :: any
		Assert.eq(s.frames, 3600, "frames")
		for _, q in { 0.5, 0.95, 0.99 } do
			local exact = exactPercentile(times, q)
			local got = PerfSample.percentile(w, q)
			Assert.truthy(got >= exact - 1e-9 and got <= exact + P.BIN_MS + 1e-9, `p{q * 100}: {got} vs {exact}`)
		end
		Assert.near(s.medianMs, PerfSample.percentile(w, 0.5), 1e-9, "summary median")
		Assert.truthy(s.worstMs >= s.p99Ms, "worst >= p99")
		local total = 0
		for _, ms in times do
			total += ms
		end
		Assert.near(s.seconds, total / 1000, 1e-6, "seconds tracked")
		Assert.near(s.meanMs, total / #times, 1e-6, "mean")
	end)

	test("pauses and junk are not frames; small windows give no summary", function()
		local w = PerfSample.new()
		Assert.falsy(PerfSample.add(w, 0), "zero")
		Assert.falsy(PerfSample.add(w, -1), "negative")
		Assert.falsy(PerfSample.add(w, 0 / 0), "NaN")
		Assert.falsy(PerfSample.add(w, P.MAX_FRAME_SECONDS + 1), "app in background")
		for _ = 1, P.MIN_FRAMES - 1 do
			PerfSample.add(w, 1 / 60)
		end
		Assert.eq(PerfSample.summary(w), nil, "too few frames")
		PerfSample.add(w, 0.5) -- one 500 ms hitch lands in the overflow bin
		local s = PerfSample.summary(w) :: any
		Assert.near(s.worstMs, 500, 1e-6, "exact worst frame")
		Assert.eq(w.overflow, 1, "overflow bin")
		PerfSample.reset(w)
		Assert.eq(w.frames, 0, "reset")
		Assert.eq(w.bins[1], 0, "bins cleared")
		Assert.eq(#w.bins, PerfSample.NBINS, "bins kept")
	end)

	test("governor: p95 over the ceiling for 20 s steps down once, cools down, stops when it does not help", function()
		local g = PerfSample.governor()
		local steps = 0
		-- one judged second: `fast` 60 fps frames, then `slow` 40 ms (25 fps) frames
		local function second(slow: number, fast: number)
			for _ = 1, fast do
				if PerfSample.govern(g, 1 / 60) then
					steps += 1
				end
			end
			for _ = 1, slow do
				if PerfSample.govern(g, 0.04) then
					steps += 1
				end
			end
		end
		-- 19 slow seconds (6 of 52 frames slow = 11.5%), then a good second resets the streak
		for _ = 1, 19 do
			second(6, 46)
		end
		Assert.eq(steps, 0, "19 s is not enough")
		second(0, 61)
		for _ = 1, 19 do
			second(6, 46)
		end
		Assert.eq(steps, 0, "streak was reset")
		for _ = 1, 2 do
			second(6, 46)
		end
		Assert.eq(steps, 1, "20 slow seconds in a row step down")
		for _ = 1, P.STEP_COOLDOWN_SECONDS do
			second(6, 46)
		end
		Assert.eq(steps, 1, "cooldown")
		-- the step helped (4 of 55 slow = 7.3% < 11.5%) but not enough: step again
		for _ = 1, P.STEP_DOWN_SECONDS + 1 do
			second(4, 51)
		end
		Assert.eq(steps, 2, "steps again after the cooldown while still slow, and less slow than before")
		for _ = 1, P.STEP_COOLDOWN_SECONDS + P.STEP_DOWN_SECONDS * 3 do
			second(4, 51)
		end
		Assert.eq(steps, 2, "a step that did not lower the slow share stops the governor")
		Assert.truthy(g.stalled, "stalled")
		Assert.eq(g.steps, 2, "count kept")
	end)

	test("governor: steps back up after a sustained good stretch, with a doubling wait (hysteresis)", function()
		local g = PerfSample.governor()
		local downs, ups = 0, 0
		local function second(slow: number, fast: number)
			for _ = 1, fast + slow do
				local dt = if slow > 0 then 0.04 else 1 / 60
				if slow > 0 then
					slow -= 1
				end
				if PerfSample.govern(g, dt) then
					downs += 1
				elseif PerfSample.stepUp(g) then
					ups += 1
				end
			end
		end
		for _ = 1, P.STEP_UP_SECONDS + 5 do
			second(0, 61)
		end
		Assert.eq(ups, 0, "never steps up past where it started")
		for _ = 1, P.STEP_DOWN_SECONDS + 1 do
			second(6, 46)
		end
		Assert.eq(downs, 1, "slow: one step down")
		for _ = 1, P.STEP_UP_SECONDS - 3 do
			second(0, 61)
		end
		Assert.eq(ups, 0, "not before STEP_UP_SECONDS good seconds")
		for _ = 1, 6 do
			second(0, 61)
		end
		Assert.eq(ups, 1, "a sustained good stretch steps back up")
		-- slow again: the governor is re-armed and steps down again
		for _ = 1, P.STEP_COOLDOWN_SECONDS + P.STEP_DOWN_SECONDS + 1 do
			second(6, 46)
		end
		Assert.eq(downs, 2, "steps down again after a step up")
		for _ = 1, P.STEP_UP_SECONDS + 5 do
			second(0, 61)
		end
		Assert.eq(ups, 1, "the next step up waits longer (backoff)")
		for _ = 1, P.STEP_UP_SECONDS * (P.STEP_UP_BACKOFF - 1) do
			second(0, 61)
		end
		Assert.eq(ups, 2, "and comes after STEP_UP_SECONDS x STEP_UP_BACKOFF")
		Assert.eq(g.ups, 2, "count kept")
	end)

	test("governor: a client that starts at tier 3 can step back up to tier 1, with the same backoff", function()
		local g = PerfSample.governor()
		PerfSample.seed(g, 3)
		local ups = 0
		local function goodSeconds(n: number)
			for _ = 1, n do
				for _ = 1, 61 do
					if PerfSample.govern(g, 1 / 60) then
						error("a good second stepped down")
					elseif PerfSample.stepUp(g) then
						ups += 1
					end
				end
			end
		end
		goodSeconds(P.STEP_UP_SECONDS + 2)
		Assert.eq(ups, 1, "tier 3 -> 2 after STEP_UP_SECONDS good seconds")
		goodSeconds(P.STEP_UP_SECONDS * P.STEP_UP_BACKOFF + 2)
		Assert.eq(ups, 2, "tier 2 -> 1 after the doubled wait")
		goodSeconds(P.STEP_UP_SECONDS * P.STEP_UP_BACKOFF ^ 2 * 2)
		Assert.eq(ups, 2, "never past tier 1")
		local g1 = PerfSample.governor()
		PerfSample.seed(g1, 1)
		Assert.eq(g1.steps, 0, "tier 1 start: nothing to undo")
	end)

	test("governor: a 30 fps cap (OS, battery saver) or a missed vsync never steps down", function()
		local function run(seconds: number, dtOf: (i: number) -> number): number
			local g = PerfSample.governor()
			local t, i = 0, 0
			while t < seconds do
				i += 1
				local dt = dtOf(i)
				t += dt
				PerfSample.govern(g, dt)
			end
			return g.steps
		end
		local cases: { { name: string, steps: number, dt: (i: number) -> number } } = {
			{
				name = "steady 30 fps",
				steps = 0,
				dt = function()
					return 1 / 30
				end,
			},
			{
				name = "30 fps with +-2 ms jitter",
				steps = 0,
				dt = function(i)
					return 1 / 30 + (if i % 2 == 0 then 0.002 else -0.002)
				end,
			},
			{
				name = "30 fps with +-2.5 ms scattered jitter",
				steps = 0,
				dt = function(i)
					return 1 / 30 + ((i * 7919) % 11 - 5) / 2000
				end,
			},
			{
				name = "60 fps missing one vsync in 16 (6% of frames at 33.3 ms)",
				steps = 0,
				dt = function(i)
					return if i % 16 == 0 then 1 / 30 else 1 / 60
				end,
			},
			{
				name = "4% slow frames at 50 fps (p95 under the ceiling)",
				steps = 0,
				dt = function(i)
					return if i % 25 == 0 then 0.04 else 0.02
				end,
			},
			-- an OS cap at 25 fps: one step, then the governor sees the step changed nothing and stops
			{
				name = "a cap below 30 fps costs one step, not a ratchet to the minimum",
				steps = 1,
				dt = function()
					return 0.04
				end,
			},
		}
		for _, c in cases do
			Assert.eq(run(300, c.dt), c.steps, c.name)
		end
	end)

	test("device classes (form factor only: game scripts cannot read the OS)", function()
		Assert.eq(device({ touch = true, keyboard = false, viewportMin = 390 }), "phone", "phone")
		Assert.eq(device({ touch = true, keyboard = false, viewportMin = 820 }), "tablet", "tablet")
		Assert.eq(device({}), "desktop", "keyboard")
		Assert.eq(device({ keyboard = false, gamepad = true }), "desktop", "PC with a gamepad only")
		Assert.eq(device({ tenFoot = true, keyboard = false, gamepad = true }), "console", "ten-foot UI")
		Assert.eq(device({ vr = true }), "vr", "vr")
		Assert.eq(device({ touch = true, keyboard = true }), "desktop", "touch laptop")
		for _, class in { "phone", "tablet", "desktop", "console", "vr" } do
			Assert.truthy(Events.DOMAINS.device.set[class], "device domain has " .. class)
		end
	end)

	test("payload: pack -> unpack round trip; hostile payloads refused", function()
		local w = PerfSample.new()
		for _ = 1, 600 do
			PerfSample.add(w, 1 / 60)
		end
		local s = PerfSample.summary(w) :: any
		local sample, why = PerfSample.unpack(PerfSample.pack(s, "phone", 3, 1200.7, 12, "balanced"))
		Assert.truthy(sample, "valid sample: " .. tostring(why))
		local ok = sample :: any
		Assert.eq(ok.memMb, 1200, "whole MB")
		Assert.eq(ok.clones, 12, "clones")
		local events = PerfSample.events(ok)
		Assert.eq(events[1].name, "PerfSample", "event")
		Assert.eq(events[1].fields[1], "phone", "device field")
		Assert.eq(events[1].fields[2], "14-18", "p95 bucket (60 fps)")
		Assert.eq(events[1].value, 16.7, "p95 value")
		Assert.eq(events[1].fields[3], "9-12", "clones bucket")
		Assert.eq(events[2].fields[2], "q1-3", "quality bucket")
		Assert.eq(events[2].fields[3], "1000-1500", "memory bucket")
		local good = { 16.5, 17, 40, 3600, 60, "pc", 5, 900, 4, "quality" }
		local function try(i: number, v: any): string?
			local args = table.clone(good)
			args[i] = v
			local _, reason = PerfSample.unpack(table.unpack(args, 1, 10))
			return reason
		end
		Assert.eq(try(6, "desktop"), nil, "baseline is valid")
		good[6] = "desktop"
		Assert.eq(try(1, 0 / 0), "ms", "NaN median")
		Assert.eq(try(1, 50), "order", "median above p95")
		Assert.eq(try(4, 10), "window", "too few frames")
		Assert.eq(try(4, 3600.5), "window", "fractional frames")
		Assert.eq(try(5, 0.5), "window", "tiny window")
		Assert.eq(try(4, 200000), "rate", "impossible fps")
		Assert.eq(try(6, "toaster"), "device", "unknown device")
		Assert.eq(try(10, "turbo"), "tier", "unknown tier")
		Assert.eq(try(7, 11), "ints", "quality > 10")
		Assert.eq(try(9, -1), "ints", "negative clones")
	end)
end
