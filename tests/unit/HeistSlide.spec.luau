-- L1: the slide (Config.Slide): Shared/Heist/SlideMath's envelope, camera dip, FOV kick, direction and gate, and
-- Rec/Validator's slide window (a Slide event raises the allowed speed for a bounded window; without one, or past it,
-- the same burst taints the run).

local Config = require("../../src/shared/Config")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local Validator = require("../../src/shared/Rec/Validator")
local SlideMath = require("../../src/shared/Heist/SlideMath")
local Assert = require("./Assert")

local SL = Config.Slide
local G = Codec.FLAG.GROUNDED
local HZ = Config.Rec.HZ
local WALK = Config.Rec.WALK_SPEED
local SLIDE = Codec.EVENT.Slide

-- A run in +X: walk at WalkSpeed, a slide of `kind` whose push starts at `pushAt` (seconds; integrated at 240 Hz the
-- way the client's physics moves you) and whose Slide event is recorded at `eventAt` (nil = no event). The push can
-- be held `holdExtra` seconds past its end at the burst's peak (a speed hack riding a real slide).
local function slideRun(kind: number, pushAt: number, eventAt: number?, holdExtra: number?): Codec.Recording
	local rec = Sampler.new(1, 1, HZ)
	local x = 0
	local sub = 12
	local seconds = 6
	for tick = 0, seconds * HZ do
		Sampler.push(rec, x, 3, 0, 0, G)
		for s = 0, sub - 1 do
			local t = (tick + s / sub) / HZ
			local age = t - pushAt
			local v = WALK
			if age >= 0 then
				v = SlideMath.speed(WALK, age, kind, SL)
				local total = SL.SECONDS[kind]
				if holdExtra and age >= SL.ATTACK_SECONDS and age < total + holdExtra then
					v = WALK + SL.BURST[kind]
				end
			end
			x += v / (HZ * sub)
		end
	end
	if eventAt then
		Sampler.addEvent(rec, eventAt, SLIDE, kind - 1)
	end
	return rec
end

local function clean(report: Validator.Report, what: string)
	Assert.falsy(report.tainted, what .. ": tainted (flags " .. report.flags .. ")")
	Assert.eq(report.clamped, 0, what .. ": clamped samples")
end

return function(test)
	test("slide envelope: push-off, peak, decay to nothing at SECONDS", function()
		for kind = 1, 2 do
			local total = SL.SECONDS[kind]
			Assert.eq(SlideMath.envelope(0, kind, SL), 0, "starts at 0")
			Assert.near(SlideMath.envelope(SL.ATTACK_SECONDS, kind, SL), 1, 1e-9, "peak after the attack")
			Assert.eq(SlideMath.envelope(total, kind, SL), 0, "spent at SECONDS")
			Assert.eq(SlideMath.envelope(-0.1, kind, SL), 0, "nothing before")
			local last = 2
			for k = 0, 20 do
				local age = SL.ATTACK_SECONDS + (total - SL.ATTACK_SECONDS) * k / 20
				local e = SlideMath.envelope(age, kind, SL)
				Assert.le(e, last + 1e-12, "decays monotonically")
				last = e
			end
			Assert.truthy(total >= 0.6 and total <= 0.8, "decays over 0.6-0.8 s")
			Assert.truthy(SlideMath.active(total - 0.01, kind, SL), "active before the end")
			Assert.falsy(SlideMath.active(total, kind, SL), "over at the end")
		end
		Assert.near(SlideMath.speed(WALK, SL.ATTACK_SECONDS, 2, SL), WALK + SL.BURST[2], 1e-9, "fast peak")
		Assert.truthy(SL.BURST[2] > SL.BURST[1], "the fast slide is the bigger burst")
		Assert.eq(SlideMath.kindOf(true), 2, "fast")
		Assert.eq(SlideMath.kindOf(false), 1, "slide")
	end)

	test("slide camera: the dip goes down, holds, comes back; the FOV kick obeys comfort settings", function()
		local total = SL.SECONDS[1]
		Assert.eq(SlideMath.dip(0, 1, SL), 0, "starts at the eye")
		Assert.near(SlideMath.dip(SL.DIP_IN_SECONDS, 1, SL), SL.DIP[1], 1e-9, "bottom after DIP_IN")
		Assert.near(SlideMath.dip(total, 1, SL), SL.DIP[1], 1e-9, "held while the burst lasts")
		Assert.eq(SlideMath.dip(total + SL.DIP_OUT_SECONDS, 1, SL), 0, "back up")
		Assert.truthy(SlideMath.cameraActive(total + 0.01, 1, SL), "the camera still recovers")
		Assert.falsy(SlideMath.cameraActive(total + SL.DIP_OUT_SECONDS, 1, SL), "and then stops")
		local peak = SL.ATTACK_SECONDS
		Assert.near(SlideMath.fovKick(peak, 2, {}, SL), SL.FOV_KICK[2], 1e-9, "kick at the peak")
		Assert.eq(SlideMath.fovKick(peak, 2, { reduced = true }, SL), 0, "reduced motion: no kick")
		Assert.eq(SlideMath.fovKick(peak, 2, { shake = false }, SL), 0, "camera shake off: no kick")
		Assert.le(SL.FOV_KICK[2], Config.Heist.CAMERA.FOV_KICK_MAX, "a slight kick")
	end)

	test("slide direction: the move direction, else the look", function()
		local x, z = SlideMath.direction(3, 4, 1, 0, SL.MIN_MOVE)
		Assert.near(x, 0.6, 1e-9, "move x")
		Assert.near(z, 0.8, 1e-9, "move z")
		x, z = SlideMath.direction(0.01, 0, 0, -2, SL.MIN_MOVE)
		Assert.near(x, 0, 1e-9, "standing: look x")
		Assert.near(z, -1, 1e-9, "standing: look z")
		x, z = SlideMath.direction(0, 0, 0, 0, SL.MIN_MOVE)
		Assert.eq(x, 0, "none")
		Assert.eq(z, 0, "none")
	end)

	test("slide gate: runs and the hideout, never in a presentation moment or Crew View", function()
		local ok, why = SlideMath.allowed({ where = "heist", phase = "Run" })
		Assert.truthy(ok, "a run: " .. why)
		Assert.truthy((SlideMath.allowed({ where = "garage", lobbyRoam = true })), "the hideout")
		local cases: { { any } } = {
			{ { where = "boot" }, "where" },
			{ { where = "heist", phase = "Between" }, "phase" },
			{ { where = "garage", lobbyRoam = false }, "station" },
			{ { where = "heist", phase = "Run", presenting = true }, "presenting" },
			{ { where = "garage", lobbyRoam = true, presenting = true }, "presenting" },
			{ { where = "heist", phase = "Run", crewView = true }, "crewView" },
			{ { where = "heist", phase = "Run", rewinding = true }, "rewind" },
			{ { where = "heist", phase = "Run", sheet = true }, "sheet" },
			{ { where = "heist", phase = "Run", alive = false }, "dead" },
			{ { where = "garage", lobbyRoam = true, seated = true }, "seated" },
			{ { where = "heist", phase = "Run", frozen = true }, "seated" },
			{ { where = "heist", phase = "Run", grounded = false }, "air" },
			{ { where = "heist", phase = "Run", cooling = true }, "cooldown" },
		}
		for _, c in cases do
			local okc, reason = SlideMath.allowed(c[1])
			Assert.falsy(okc, c[2])
			Assert.eq(reason, c[2], "reason")
		end
	end)

	test(
		"validator: a slide with its Slide event is accepted untouched (both kinds, push up to 2 ticks early)",
		function()
			for kind = 1, 2 do
				for lead = 0, 2 do
					local eventAt = 2 + lead / HZ
					clean(Validator.validate(slideRun(kind, 2, eventAt)), `kind {kind} lead {lead}`)
				end
				-- the event two ticks before the push (the remote first, then the physics)
				clean(Validator.validate(slideRun(kind, 2.1, 2)), `kind {kind} late push`)
			end
		end
	)

	test("validator: the same burst without a Slide event taints and clamps", function()
		local report = Validator.validate(slideRun(2, 2, nil))
		Assert.truthy(report.tainted, "tainted")
		Assert.hasBit(report.flags, Validator.FLAG.SPEED, "speed")
		Assert.truthy(report.clamped > 0, "clamped")
	end)

	test("validator: the window is bounded (riding a slide's peak past it taints)", function()
		local report = Validator.validate(slideRun(2, 2, 2, 0.6))
		Assert.truthy(report.tainted, "held at the peak 0.6 s too long")
		Assert.hasBit(report.flags, Validator.FLAG.SPEED, "speed")
	end)

	test("validator: Slide events inside the server cooldown open no window and fail the event check", function()
		local rec = slideRun(1, 3, 3)
		table.insert(rec.events, 1, { t = 2.5, kind = SLIDE, arg = 0 })
		local report = Validator.validate(rec)
		Assert.truthy(report.tainted, "a slide 0.5 s after the last")
		Assert.hasBit(report.flags, Validator.FLAG.EVENT, "event flag")
		local bad = slideRun(1, 2, 2)
		bad.events[1].arg = 7
		Assert.hasBit(Validator.validate(bad).flags, Validator.FLAG.EVENT, "unknown arg")
		Assert.eq(Validator.slideExtra(1), SL.BURST[2] * SL.ALLOW_MARGIN, "fast allowance")
		Assert.eq(Validator.slideExtra(2), nil, "no third kind")
	end)

	test("validator: streaming (event recorded as the slide arrives) matches whole-run validation", function()
		local whole = slideRun(2, 2, 2)
		local full = Validator.validate(whole)
		-- Streaming: samples arrive tick by tick; the event is added once its tick has been validated.
		local src = slideRun(2, 2, nil)
		local rec = Sampler.new(1, 1, HZ)
		local v = Validator.new(rec)
		for i = 1, src.n do
			Sampler.push(rec, src.px[i], src.py[i], src.pz[i], src.yaw[i], src.flags[i])
			Validator.step(v)
			if (i - 1) / HZ == 2 then
				Sampler.addEvent(rec, 2, SLIDE, 1)
			end
		end
		Validator.checkEvents(v)
		local stream = Validator.report(v)
		Assert.eq(stream.tainted, full.tainted, "same verdict")
		Assert.falsy(stream.tainted, "untainted")
		for i = 1, rec.n do
			Assert.eq(rec.px[i], whole.px[i], "same sample " .. i)
		end
	end)
end
