-- L1: Rec/Codec round trip, size budget, version branch, malformed input.

local Config = require("../../src/shared/Config")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local Assert = require("./Assert")
local Runs = require("./Runs")

local TOL = 1 / 32 + 1e-9
local YAW_TOL = math.pi / 256 + 1e-9

local function yawDiff(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

-- A recording with raw (off-grid) floats, bypassing Sampler's snapping.
local function rawRecording(n: number): Codec.Recording
	local rec = Codec.newRecording(20, 3, 7)
	for i = 1, n do
		rec.n = i
		local t = (i - 1) / 20
		rec.px[i] = 100.123 + math.sin(t) * 37.77
		rec.py[i] = 3.01 + math.abs(math.sin(t * 3)) * 6.3
		rec.pz[i] = -250.987 + t * 13.3
		rec.yaw[i] = t * 2.1 - 3
		rec.flags[i] = Codec.packFlags(if i % 7 == 0 then 2 else 1, i % 8)
	end
	return rec
end

local function sameRecording(a: Codec.Recording, b: Codec.Recording)
	Assert.eq(a.n, b.n, "n")
	Assert.eq(a.hz, b.hz, "hz")
	Assert.eq(a.levelId, b.levelId, "levelId")
	Assert.eq(a.loopIndex, b.loopIndex, "loopIndex")
	Assert.eq(a.vflags, b.vflags, "vflags")
	Assert.eq(a.endReason, b.endReason, "endReason")
	for i = 1, a.n do
		Assert.eq(a.px[i], b.px[i], "px " .. i)
		Assert.eq(a.py[i], b.py[i], "py " .. i)
		Assert.eq(a.pz[i], b.pz[i], "pz " .. i)
		Assert.eq(a.yaw[i], b.yaw[i], "yaw " .. i)
		Assert.eq(a.flags[i], b.flags[i], "flags " .. i)
		Assert.eq(a.cut[i] == true, b.cut[i] == true, "cut " .. i)
	end
	Assert.eq(#a.events, #b.events, "#events")
	for k, e in a.events do
		Assert.eq(e.t, b.events[k].t, "event t")
		Assert.eq(e.kind, b.events[k].kind, "event kind")
		Assert.eq(e.arg, b.events[k].arg, "event arg")
	end
end

local function bytesEqual(a: buffer, b: buffer): boolean
	if buffer.len(a) ~= buffer.len(b) then
		return false
	end
	for k = 0, buffer.len(a) - 1 do
		if buffer.readu8(a, k) ~= buffer.readu8(b, k) then
			return false
		end
	end
	return true
end

return function(test)
	test("raw floats round trip within 1/32 stud and half a yaw step", function()
		local rec = rawRecording(600)
		table.insert(rec.events, { t = 1.234, kind = Codec.EVENT.Grab, arg = 513 })
		local out = assert(Codec.decode(Codec.encode(rec)))
		Assert.eq(out.n, 600, "n")
		local worst = 0
		for i = 1, rec.n do
			worst = math.max(worst, math.abs(out.px[i] - rec.px[i]), math.abs(out.py[i] - rec.py[i]), math.abs(out.pz[i] - rec.pz[i]))
			Assert.le(yawDiff(out.yaw[i], rec.yaw[i]), YAW_TOL, "yaw " .. i)
			Assert.eq(out.flags[i], rec.flags[i], "flags " .. i)
		end
		Assert.le(worst, TOL, "max position error")
		Assert.near(out.events[1].t, 1.23, 1e-9, "event time on the centisecond grid")
		Assert.eq(out.events[1].arg, 513, "event arg")
		Assert.eq(out.levelId, 3, "levelId")
		Assert.eq(out.loopIndex, 7, "loopIndex")
	end)

	test("Sampler-recorded runs round trip bit-identically, bytes too", function()
		local rec = Runs.heist45(0.1)
		local b = Codec.encode(rec)
		local out = assert(Codec.decode(b))
		sameRecording(rec, out)
		Assert.truthy(bytesEqual(b, Codec.encode(out)), "re-encode gives the same bytes")
		Assert.eq(Codec.hash(b), Codec.hash(Codec.encode(out)), "hash stable")
	end)

	test("size budget: 30 s and 45 s runs (bytes printed)", function()
		local budget = Config.Rec.BUDGET_BYTES_PER_SECOND
		local rec45 = Runs.heist45(0.1)
		local b45 = buffer.len(Codec.encode(rec45))
		local raw45 = rec45.n * 8 + Codec.HEADER_BYTES + #rec45.events * 5
		local clean45 = buffer.len(Codec.encode(Runs.heist45(0)))
		-- 30 s: the first 601 samples of the same run.
		local rec30 = Runs.heist45(0.1)
		for i = 602, rec30.n do
			rec30.px[i], rec30.py[i], rec30.pz[i], rec30.yaw[i], rec30.flags[i] = nil, nil, nil, nil, nil
		end
		rec30.n = 601
		local b30 = buffer.len(Codec.encode(rec30))
		print(
			string.format(
				"        45 s: %d B (jittered), %d B (clean), raw 8 B/sample would be %d B; 30 s: %d B; budget %d B/s",
				b45,
				clean45,
				raw45,
				b30,
				budget
			)
		)
		Assert.le(b45, budget * 45, "45 s run")
		Assert.le(b30, budget * 30, "30 s run")
		Assert.le(b45, raw45 * 0.6, "delta coding saves at least 40% over raw")
	end)

	test("worst case stays under 6 bytes per sample without keyframes", function()
		-- Turning and changing flags every tick, moving on all axes.
		local rec = Sampler.new(1, 1, 20)
		for i = 0, 900 do
			Sampler.push(rec, math.sin(i) * 0.7 + i * 0.5, 3 + (i % 2) * 0.5, math.cos(i) * 0.7, i * 0.37, (i % 2) + 1)
		end
		local size = buffer.len(Codec.encode(rec))
		print(string.format("        worst-case 45 s: %d B (%.2f B/sample)", size, size / rec.n))
		Assert.le(size, Codec.HEADER_BYTES + 9 + (rec.n - 1) * 6, "bound")
	end)

	test("cut samples and large deltas become keyframes and survive", function()
		local rec = Sampler.new(2, 3, 20)
		Sampler.push(rec, 0, 3, 0, 0, 1)
		Sampler.push(rec, 0.5, 3, 0, 0, 1)
		Sampler.push(rec, 0.5, -40, 0, 0, 0) -- falls 43 studs in a tick: i8 overflow
		Sampler.addEvent(rec, 0.15, Codec.EVENT.Respawn, 0)
		Sampler.push(rec, 500, 3, -800, 1, 1, true)
		Sampler.push(rec, 500.5, 3, -800, 1, 1)
		local out = assert(Codec.decode(Codec.encode(rec)))
		sameRecording(rec, out)
		Assert.truthy(out.cut[4], "cut kept")
		Assert.falsy(out.cut[3], "overflow keyframe is not a cut")
	end)

	test("long idle stretches compress to repeat records", function()
		local rec = Sampler.new(1, 1, 20)
		for _ = 1, 901 do
			Sampler.push(rec, 10, 3, 10, 0, 1)
		end
		local size = buffer.len(Codec.encode(rec))
		-- header + keyframe + ceil(900 / 64) repeat bytes
		Assert.eq(size, Codec.HEADER_BYTES + 9 + math.ceil(900 / 64), "idle size")
		local out = assert(Codec.decode(Codec.encode(rec)))
		sameRecording(rec, out)
	end)

	test("empty run: header only, decodes to n = 0", function()
		local rec = Sampler.new(4, 2, 20)
		Sampler.finish(rec, Codec.END.Left)
		local b = Codec.encode(rec)
		Assert.eq(buffer.len(b), Codec.HEADER_BYTES, "size")
		local out = assert(Codec.decode(b))
		Assert.eq(out.n, 0, "n")
		Assert.eq(out.endReason, Codec.END.Left, "endReason")
	end)

	test("one-frame run round trips", function()
		local rec = Sampler.new(1, 1, 20)
		Sampler.push(rec, -12.5, 4, 99, 2, Codec.packFlags(1, 5))
		Sampler.finish(rec, Codec.END.EndRun)
		local b = Codec.encode(rec)
		Assert.eq(buffer.len(b), Codec.HEADER_BYTES + 9, "size")
		sameRecording(rec, assert(Codec.decode(b)))
	end)

	test("version branch: unknown versions are rejected, not misread", function()
		local b = Codec.encode(Runs.heist45(0))
		buffer.writeu8(b, 0, Codec.VERSION + 1)
		local out, err = Codec.decode(b)
		Assert.eq(out, nil, "decoded")
		Assert.truthy(err and string.find(err, "version"), "error mentions version: " .. tostring(err))
	end)

	test("truncated or garbage buffers return nil and a reason", function()
		local b = Codec.encode(Runs.heist45(0))
		for _, cutAt in { 0, 5, Codec.HEADER_BYTES, Codec.HEADER_BYTES + 4, buffer.len(b) - 1 } do
			local short = buffer.create(cutAt)
			buffer.copy(short, 0, b, 0, cutAt)
			local out, err = Codec.decode(short)
			Assert.eq(out, nil, "truncated at " .. cutAt)
			Assert.truthy(err, "reason at " .. cutAt)
		end
		local junk = buffer.create(64)
		buffer.writeu8(junk, 0, Codec.VERSION)
		buffer.writeu8(junk, 1, 20)
		buffer.writeu16(junk, 6, 100)
		buffer.fill(junk, Codec.HEADER_BYTES, 0x3F)
		Assert.eq((Codec.decode(junk)), nil, "junk")
	end)

	test("out-of-range and NaN positions are clamped, never crash", function()
		Assert.eq(Codec.quantizePos(0 / 0), 0, "NaN")
		Assert.eq(Codec.quantizePos(1e9), 32767, "huge")
		Assert.eq(Codec.quantizePos(-1e9), -32768, "tiny")
		Assert.eq(Codec.quantizeYaw(-math.pi / 2), 192, "negative yaw wraps")
		Assert.eq(Codec.quantizeYaw(2 * math.pi), 0, "full turn")
	end)

	test("flags pack 5 bits and a 3-bit pose", function()
		local f = Codec.packFlags(Codec.FLAG.GROUNDED + Codec.FLAG.HIDDEN, 6)
		Assert.truthy(Codec.hasFlag(f, Codec.FLAG.HIDDEN), "hidden")
		Assert.falsy(Codec.hasFlag(f, Codec.FLAG.JUMPING), "jumping")
		Assert.eq(Codec.poseOf(f), 6, "pose")
		Assert.eq(Codec.poseOf(Codec.packFlags(0, 99)), 7, "pose clamps")
	end)

	test("hash tells different recordings apart", function()
		local a = Runs.heist45(0)
		local b = Runs.heist45(0)
		b.px[400] += 1 / 16
		Assert.truthy(Codec.hash(Codec.encode(a)) ~= Codec.hash(Codec.encode(b)), "hash differs")
		Assert.eq(Codec.hash(Codec.encode(a)), Codec.hash(Codec.encode(Runs.heist45(0))), "hash repeatable")
	end)
end
