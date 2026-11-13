-- L1: the slide (Config.Slide): Shared/Heist/SlideMath's envelope, camera dip, FOV kick, direction and gate, and
-- Rec/Validator's slide window (a Slide event raises the allowed speed for a bounded window; without one, or past it,
-- a push over the normal limit taints the run). Owner, live v125: one slide kind, about half the old burst, shorter;
-- the burst rides on the speed you move at (a sprint included).

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
local SPRINT = WALK * Config.Sprint.MULT
local SLIDE = Codec.EVENT.Slide

-- A run in +X at `base` (a walk or a sprint), a slide whose push starts at `pushAt` (seconds; integrated at 240 Hz
-- the way the client's physics moves you) and whose Slide event is recorded at `eventAt` (nil = no event). The push
-- can be held `holdExtra` seconds past its end at the burst's peak (a speed hack riding a real slide).
local function slideRun(base: number, pushAt: number, eventAt: number?, holdExtra: number?): Codec.Recording
	local rec = Sampler.new(1, 1, HZ)
	local x = 0
	local sub = 12
	local seconds = 6
	for tick = 0, seconds * HZ do
		Sampler.push(rec, x, 3, 0, 0, G)
		for s = 0, sub - 1 do
			local t = (tick + s / sub) / HZ
			local age = t - pushAt
			local v = base
			if age >= 0 then
				v = SlideMath.speed(base, age, SL)
				if holdExtra and age >= SL.ATTACK_SECONDS and age < SL.SECONDS + holdExtra then
					v = base + SL.BURST
				end
			end
			x += v / (HZ * sub)
		end
	end
	if eventAt then
		Sampler.addEvent(rec, eventAt, SLIDE, 0)
	end
	return rec
end

local function clean(report: Validator.Report, what: string)
	Assert.falsy(report.tainted, what .. ": tainted (flags " .. report.flags .. ")")
	Assert.eq(report.clamped, 0, what .. ": clamped samples")
end

return function(test)
	test("slide envelope: push-off, peak, decay to nothing at SECONDS; about half the old burst", function()
		local total = SL.SECONDS
		Assert.eq(SlideMath.envelope(0, SL), 0, "starts at 0")
		Assert.near(SlideMath.envelope(SL.ATTACK_SECONDS, SL), 1, 1e-9, "peak after the attack")
		Assert.eq(SlideMath.envelope(total, SL), 0, "spent at SECONDS")
		Assert.eq(SlideMath.envelope(-0.1, SL), 0, "nothing before")
		local last = 2
		for k = 0, 20 do
			local age = SL.ATTACK_SECONDS + (total - SL.ATTACK_SECONDS) * k / 20
			local e = SlideMath.envelope(age, SL)
			Assert.le(e, last + 1e-12, "decays monotonically")
			last = e
		end
		Assert.truthy(total >= 0.35 and total <= 0.55, "decays over 0.35-0.55 s (was 0.65 / 0.75)")
		Assert.truthy(SL.BURST >= 7 and SL.BURST <= 11, "about half the old 18 studs/s burst")
		Assert.truthy(SlideMath.active(total - 0.01, SL), "active before the end")
		Assert.falsy(SlideMath.active(total, SL), "over at the end")
		Assert.near(SlideMath.speed(WALK, SL.ATTACK_SECONDS, SL), WALK + SL.BURST, 1e-9, "peak from a walk")
		Assert.near(SlideMath.speed(SPRINT, SL.ATTACK_SECONDS, SL), SPRINT + SL.BURST, 1e-9, "peak from a sprint")
		Assert.truthy(SL.WINDOW_SECONDS >= SL.SECONDS, "the validator window covers the burst")
	end)

	test("slide camera: the dip goes down, holds, comes back; the FOV kick obeys comfort settings", function()
		local total = SL.SECONDS
		Assert.eq(SlideMath.dip(0, SL), 0, "starts at the eye")
		Assert.near(SlideMath.dip(SL.DIP_IN_SECONDS, SL), SL.DIP, 1e-9, "bottom after DIP_IN")
		Assert.near(SlideMath.dip(total, SL), SL.DIP, 1e-9, "held while the burst lasts")
		Assert.eq(SlideMath.dip(total + SL.DIP_OUT_SECONDS, SL), 0, "back up")
		Assert.truthy(SlideMath.cameraActive(total + 0.01, SL), "the camera still recovers")
		Assert.falsy(SlideMath.cameraActive(total + SL.DIP_OUT_SECONDS, SL), "and then stops")
		local peak = SL.ATTACK_SECONDS
		Assert.near(SlideMath.fovKick(peak, {}, SL), SL.FOV_KICK, 1e-9, "kick at the peak")
		Assert.eq(SlideMath.fovKick(peak, { reduced = true }, SL), 0, "reduced motion: no kick")
		Assert.eq(SlideMath.fovKick(peak, { shake = false }, SL), 0, "camera shake off: no kick")
		Assert.le(SL.FOV_KICK + Config.Sprint.FOV_KICK, Config.Heist.CAMERA.FOV_KICK_MAX, "slide + sprint kicks")
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
		"validator: a slide with its Slide event is accepted untouched (walk or sprint, push up to 2 ticks early)",
		function()
			for _, base in { WALK, SPRINT } do
				for lead = 0, 2 do
					local eventAt = 2 + lead / HZ
					clean(Validator.validate(slideRun(base, 2, eventAt)), `base {base} lead {lead}`)
				end
				-- the event two ticks before the push (the remote first, then the physics)
				clean(Validator.validate(slideRun(base, 2.1, 2)), `base {base} late push`)
			end
		end
	)

	test(
		"validator: a slide out of a sprint held at its peak for the whole window passes only with the Slide event",
		function()
			local hold = SL.WINDOW_SECONDS + SL.WINDOW_GRACE - SL.SECONDS
			clean(Validator.validate(slideRun(SPRINT, 2, 2, hold)), "with the event")
			local report = Validator.validate(slideRun(SPRINT, 2, nil, hold))
			Assert.truthy(report.tainted, "without it: tainted")
			Assert.hasBit(report.flags, Validator.FLAG.SPEED, "speed")
			Assert.truthy(report.clamped > 0, "clamped")
		end
	)

	test("validator: the window is bounded (riding a slide's peak far past it taints)", function()
		local report = Validator.validate(slideRun(SPRINT, 2, 2, 1.2))
		Assert.truthy(report.tainted, "held at the peak 1.2 s too long")
		Assert.hasBit(report.flags, Validator.FLAG.SPEED, "speed")
	end)

	test("validator: Slide events inside the server cooldown, or with arg 1 (the retired fast slide), fail", function()
		local rec = slideRun(WALK, 3, 3)
		table.insert(rec.events, 1, { t = 2.5, kind = SLIDE, arg = 0 })
		local report = Validator.validate(rec)
		Assert.truthy(report.tainted, "a slide 0.5 s after the last")
		Assert.hasBit(report.flags, Validator.FLAG.EVENT, "event flag")
		for _, arg in { 1, 7 } do
			local bad = slideRun(WALK, 2, 2)
			bad.events[1].arg = arg
			Assert.hasBit(Validator.validate(bad).flags, Validator.FLAG.EVENT, "unknown arg " .. arg)
		end
		Assert.eq(Validator.slideExtra(0), SL.BURST * SL.ALLOW_MARGIN, "the allowance")
		Assert.eq(Validator.slideExtra(1), nil, "no fast slide")
	end)

	test("validator: streaming (event recorded as the slide arrives) matches whole-run validation", function()
		local hold = SL.WINDOW_SECONDS + SL.WINDOW_GRACE - SL.SECONDS
		local whole = slideRun(SPRINT, 2, 2, hold)
		local full = Validator.validate(whole)
		-- Streaming: samples arrive tick by tick; the event is added once its tick has been validated.
		local src = slideRun(SPRINT, 2, nil, hold)
		local rec = Sampler.new(1, 1, HZ)
		local v = Validator.new(rec)
		for i = 1, src.n do
			Sampler.push(rec, src.px[i], src.py[i], src.pz[i], src.yaw[i], src.flags[i])
			Validator.step(v)
			if (i - 1) / HZ == 2 then
				Sampler.addEvent(rec, 2, SLIDE, 0)
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
