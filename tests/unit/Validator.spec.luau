-- L1: Rec/Validator fixtures: walk, jump, fall, lag, respawn, caught (accepted);
-- speed hack, teleport, fly, wall clip, NaN, bad events (caught and clamped).

local Config = require("../../src/shared/Config")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local Validator = require("../../src/shared/Rec/Validator")
local Assert = require("./Assert")
local Runs = require("./Runs")

local G = Codec.FLAG.GROUNDED
local F = Validator.FLAG
local MAX_STEP = Config.Rec.WALK_SPEED * Config.Rec.SPEED_MULT / 20

local function clean(report: Validator.Report, what: string)
	if report.tainted then
		local v = report.violations[1]
		error(
			string.format(
				"%s: tainted (flags %d, first at sample %s t=%s)",
				what,
				report.flags,
				tostring(v and v.index),
				tostring(v and v.t)
			),
			2
		)
	end
	Assert.eq(report.clamped, 0, what .. " clamped")
end

-- Walks in +X at `speed` for `seconds`, starting at x0.
local function walkRun(speed: number, seconds: number, opts: { flags: number?, x0: number? }?): Codec.Recording
	local o = opts or {}
	local rec = Sampler.new(1, 1, 20)
	local x = o.x0 or 0
	for _ = 0, seconds * 20 do
		Sampler.push(rec, x, 3, 0, 0, o.flags or G)
		x += speed / 20
	end
	return rec
end

local function maxHorizontalStep(rec: Codec.Recording): number
	local worst = 0
	for i = 2, rec.n do
		local dx, dz = rec.px[i] - rec.px[i - 1], rec.pz[i] - rec.pz[i - 1]
		worst = math.max(worst, math.sqrt(dx * dx + dz * dz))
	end
	return worst
end

return function(test)
	-- Accepted -------------------------------------------------------------

	test("accepts a legit 45 s heist run (walk, turns, jumps, waits)", function()
		clean(Validator.validate(Runs.heist45(0.1)), "heist45")
	end)

	test("accepts sprinting right at WalkSpeed x 1.3", function()
		clean(Validator.validate(walkRun(16 * 1.3, 10)), "1.3x")
	end)

	test("accepts a lag burst within the ping allowance", function()
		-- Server sees the player frozen for 0.4 s, then the backlog arrives at once.
		local rec = Sampler.new(1, 1, 20)
		local x = 0
		for i = 0, 100 do
			if i < 40 or i >= 48 then
				x += 16 / 20
			elseif i == 47 then
				x += 16 * 0.4
			end
			Sampler.push(rec, x, 3, 0, 0, G)
		end
		clean(Validator.validate(rec, { ping = 0.2 }), "lag burst")
	end)

	test("accepts a long fall off a ledge", function()
		local rec = Sampler.new(1, 1, 20)
		local y, vy = 80, 0
		for i = 0, 60 do
			local grounded = y <= 3
			Sampler.push(rec, i * 0.6, math.max(y, 3), 0, 0, if grounded then G else 0)
			vy -= 196.2 / 20
			y += vy / 20
		end
		clean(Validator.validate(rec), "fall")
	end)

	test("accepts a respawn teleport backed by a Respawn event", function()
		local rec = Runs.build({
			{ walk = { 0, -30 } },
			{ teleport = { 400, 3, 400 }, event = Codec.EVENT.Respawn },
			{ walk = { 420, 400 } },
		})
		clean(Validator.validate(rec), "respawn")
		local cuts = 0
		for _ in rec.cut do
			cuts += 1
		end
		Assert.eq(cuts, 1, "cut kept")
	end)

	test("accepts a run that ends with Caught (terminal event at the end)", function()
		local rec = walkRun(12, 6)
		Sampler.addEvent(rec, 2, Codec.EVENT.Grab, 1)
		Sampler.addEvent(rec, 6, Codec.EVENT.Caught, 0)
		Sampler.finish(rec, Codec.END.Caught)
		clean(Validator.validate(rec), "caught")
	end)

	test("accepts balanced holds and an emote", function()
		local rec = walkRun(8, 5)
		Sampler.addEvent(rec, 1, Codec.EVENT.HoldStart, 4)
		Sampler.addEvent(rec, 3, Codec.EVENT.HoldEnd, 4)
		Sampler.addEvent(rec, 4, Codec.EVENT.Emote, 2)
		clean(Validator.validate(rec), "holds")
	end)

	test("edge cases: empty run, one frame, run ended early", function()
		clean(Validator.validate(Sampler.new(1, 1, 20)), "empty")
		local one = Sampler.new(1, 1, 20)
		Sampler.push(one, 1, 3, 1, 0, G)
		clean(Validator.validate(one), "one frame")
		local early = walkRun(16, 3)
		Sampler.finish(early, Codec.END.EndRun)
		clean(Validator.validate(early), "ended early")
	end)

	test("streaming step() per tick matches whole-run validate()", function()
		local a = Runs.heist45(0.1)
		local b = Sampler.new(1, 1, 20)
		local v = Validator.new(b)
		for i = 1, a.n do
			Sampler.push(b, a.px[i], a.py[i], a.pz[i], a.yaw[i], a.flags[i])
			Validator.step(v)
		end
		Assert.eq(v.flags, 0, "stream clean")
		Assert.eq(b.n, a.n, "n")
	end)

	-- Caught -----------------------------------------------------------------

	test("speed hack at 2x WalkSpeed is flagged and clamped to max speed", function()
		local rec = walkRun(32, 5)
		local report = Validator.validate(rec)
		Assert.truthy(report.tainted, "tainted")
		Assert.hasBit(report.flags, F.SPEED, "SPEED")
		Assert.truthy(report.clamped > 50, "most samples clamped: " .. report.clamped)
		-- The bucket lets a short burst through, then the clone is held to max speed:
		-- total distance <= max speed x duration + bucket slack.
		local slack = Config.Rec.SPEED_BUCKET_STUDS
		Assert.le(rec.px[rec.n] - rec.px[1], MAX_STEP * (rec.n - 1) + slack + 1 / 16, "distance bound")
		Assert.le(maxHorizontalStep(rec), 32 / 20 + 1 / 16, "never faster than reported")
		Assert.near(rec.px[rec.n] - rec.px[rec.n - 1], MAX_STEP, 1 / 16, "held to max speed at the end")
		Assert.truthy(Validator.isTainted(rec), "rec.vflags set")
		local out = assert(Codec.decode(Codec.encode(rec)))
		Assert.hasBit(out.vflags, F.SPEED, "taint travels in the header")
	end)

	test("speed hack under the bucket slack is caught within a second", function()
		local rec = walkRun(16 * 1.6, 3)
		local report = Validator.validate(rec)
		Assert.hasBit(report.flags, F.SPEED, "SPEED")
		Assert.le(report.violations[1].t, 1, "first violation time")
	end)

	test("teleport without an exemption is flagged and does not move the clone", function()
		local rec = walkRun(10, 2)
		Sampler.push(rec, 300, 3, 300, 0, G)
		Sampler.push(rec, 300.5, 3, 300, 0, G)
		local report = Validator.validate(rec)
		Assert.hasBit(report.flags, F.TELEPORT, "TELEPORT")
		Assert.le(maxHorizontalStep(rec), MAX_STEP + 1 / 16, "clamped")
		Assert.truthy(rec.px[rec.n] < 30, "clone stays near its path")
	end)

	test("a cut with no Respawn/Teleport event is treated as a teleport", function()
		local rec = walkRun(10, 2)
		Sampler.push(rec, 300, 3, 300, 0, G, true)
		local report = Validator.validate(rec)
		Assert.hasBit(report.flags, F.TELEPORT, "TELEPORT")
		Assert.falsy(rec.cut[rec.n], "cut removed")
	end)

	test("fly hack: rising above the jump apex is flagged and clamped", function()
		local rec = Sampler.new(1, 1, 20)
		for i = 0, 60 do
			Sampler.push(rec, 0, 3 + i * 0.5, 0, 0, if i == 0 then G else 0)
		end
		local report = Validator.validate(rec)
		Assert.hasBit(report.flags, F.RISE, "RISE")
		local top = 0
		for i = 1, rec.n do
			top = math.max(top, rec.py[i])
		end
		Assert.le(top, 3 + Config.Rec.JUMP_HEIGHT + Config.Rec.RISE_MARGIN + 1 / 16, "clamped height")
	end)

	test("fly hack with a faked grounded flag is limited by the rise speed", function()
		local rec = Sampler.new(1, 1, 20)
		for i = 0, 40 do
			Sampler.push(rec, 0, 3 + i * 5, 0, 0, G)
		end
		local report = Validator.validate(rec)
		Assert.hasBit(report.flags, F.RISE, "RISE")
		for i = 2, rec.n do
			Assert.le(rec.py[i] - rec.py[i - 1], Config.Rec.MAX_RISE_SPEED / 20 + 1 / 16, "rise per tick")
		end
	end)

	test("walking through a no-go wall is flagged; the clone stops at the wall", function()
		local wall = { minX = 20, minY = 0, minZ = -50, maxX = 22, maxY = 30, maxZ = 50 }
		local rec = walkRun(16, 4)
		local report = Validator.validate(rec, { noGo = { wall } })
		Assert.hasBit(report.flags, F.NOGO, "NOGO")
		for i = 1, rec.n do
			Assert.truthy(rec.px[i] <= 20, "never past the wall at " .. i)
		end
	end)

	test("a closed door (injected isBlocked) is a blocker only while closed", function()
		local door = { minX = 30, minY = 0, minZ = -5, maxX = 31, maxY = 12, maxZ = 5 }
		local function isBlocked(t, x0, y0, z0, x1, y1, z1)
			return t < 1 and Validator.segmentHitsBox(door, x0, y0, z0, x1, y1, z1)
		end
		-- Arrives at the door at ~1.9 s, after it opened: fine.
		clean(Validator.validate(walkRun(16, 3), { isBlocked = isBlocked }), "open door")
		-- Starts right at the door while it is still closed.
		local rec = walkRun(16, 2, { x0 = 28 })
		local report = Validator.validate(rec, { isBlocked = isBlocked })
		Assert.hasBit(report.flags, F.NOGO, "closed door")
	end)

	test("NaN and out-of-range positions are flagged and held", function()
		local rec = walkRun(10, 1)
		Sampler.push(rec, 0 / 0, 3, 0, 0, G)
		local report = Validator.validate(rec)
		-- Sampler snaps NaN to 0 on the grid, which reads as a jump back to the origin:
		-- the validator must still not let it through unflagged.
		Assert.truthy(report.tainted, "NaN caught")
		local raw = Codec.newRecording(20)
		raw.n = 2
		raw.px, raw.py, raw.pz, raw.yaw, raw.flags = { 0, 0 / 0 }, { 3, 3 }, { 0, 0 }, { 0, 0 }, { G, G }
		local r2 = Validator.validate(raw)
		Assert.hasBit(r2.flags, F.NONFINITE, "NONFINITE")
		Assert.eq(raw.px[2], 0, "held at previous")
		local far = Codec.newRecording(20)
		far.n = 2
		far.px, far.py, far.pz, far.yaw, far.flags = { 2040, 5000 }, { 3, 3 }, { 0, 0 }, { 0, 0 }, { G, G }
		Assert.hasBit(Validator.validate(far).flags, F.BOUNDS, "BOUNDS")
	end)

	test("heavy loot: a lowered WalkSpeed is enforced mid-run", function()
		local rec = Sampler.new(1, 1, 20)
		local v = Validator.new(rec)
		local x = 0
		for i = 0, 100 do
			if i == 20 then
				Validator.setWalkSpeed(v, 8)
			end
			x += 16 / 20
			Sampler.push(rec, x, 3, 0, 0, G)
			Validator.step(v)
		end
		Assert.hasBit(v.flags, F.SPEED, "full speed while carrying heavy loot")
	end)

	test("impossible events are flagged", function()
		local function eventsFlag(build: (Codec.Recording) -> ()): number
			local rec = walkRun(8, 5)
			build(rec)
			return Validator.validate(rec).flags
		end
		Assert.hasBit(
			eventsFlag(function(r)
				table.insert(r.events, { t = 1, kind = 200, arg = 0 })
			end),
			F.EVENT,
			"unknown kind"
		)
		Assert.hasBit(
			eventsFlag(function(r)
				Sampler.addEvent(r, 3, Codec.EVENT.Grab, 1)
				Sampler.addEvent(r, 1, Codec.EVENT.Release, 1)
			end),
			F.EVENT,
			"out of order"
		)
		Assert.hasBit(
			eventsFlag(function(r)
				Sampler.addEvent(r, 2, Codec.EVENT.Caught, 0)
				Sampler.addEvent(r, 3, Codec.EVENT.Grab, 1)
			end),
			F.EVENT,
			"after Caught"
		)
		Assert.hasBit(
			eventsFlag(function(r)
				Sampler.addEvent(r, 2, Codec.EVENT.HoldEnd, 1)
			end),
			F.EVENT,
			"HoldEnd without HoldStart"
		)
		Assert.hasBit(
			eventsFlag(function(r)
				Sampler.addEvent(r, 1, Codec.EVENT.HoldStart, 1)
				Sampler.addEvent(r, 2, Codec.EVENT.HoldStart, 2)
			end),
			F.EVENT,
			"two holds at once"
		)
		Assert.hasBit(
			eventsFlag(function(r)
				Sampler.addEvent(r, 30, Codec.EVENT.Grab, 1)
			end),
			F.EVENT,
			"after the run ended"
		)
		Assert.hasBit(
			eventsFlag(function(r)
				for _ = 1, Config.Rec.MAX_EVENTS + 1 do
					table.insert(r.events, { t = 1, kind = Codec.EVENT.Emote, arg = 0 })
				end
			end),
			F.EVENT,
			"too many events"
		)
		local empty = Sampler.new(1, 1, 20)
		Sampler.addEvent(empty, 0, Codec.EVENT.Grab, 1)
		Assert.hasBit(Validator.validate(empty).flags, F.EVENT, "event in an empty run")
	end)

	test("segment-box test basics", function()
		local b = { minX = 0, minY = 0, minZ = 0, maxX = 1, maxY = 1, maxZ = 1 }
		Assert.truthy(Validator.segmentHitsBox(b, -1, 0.5, 0.5, 2, 0.5, 0.5), "through")
		Assert.falsy(Validator.segmentHitsBox(b, -1, 2, 0.5, 2, 2, 0.5), "above")
		Assert.falsy(Validator.segmentHitsBox(b, -2, 0.5, 0.5, -1, 0.5, 0.5), "short of it")
		Assert.truthy(Validator.segmentHitsBox(b, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5), "point inside")
	end)
end
