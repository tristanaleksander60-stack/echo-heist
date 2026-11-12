-- L1: Audio/Mix, the pure mix maths: dB, sliders and the Warnings floor, ducks, Crew Layers tiers and set
-- gains (mixes vs stems vs playlist), tonal ladders, the clone arpeggio, the bar grid and Christmas days.

local Config = require("../../src/shared/Config")
local Mix = require("../../src/shared/Audio/Mix")
local Assert = require("./Assert")

local A = Config.Audio

local function sum(t: { number }): number
	local s = 0
	for _, v in t do
		s += v
	end
	return s
end

return function(test)
	test("dB and gain round-trip", function()
		Assert.near(Mix.dbToGain(0), 1, 1e-9, "0 dB")
		Assert.near(Mix.dbToGain(-6), 0.501, 0.001, "-6 dB")
		Assert.near(Mix.gainToDb(Mix.dbToGain(-4)), -4, 1e-9, "round trip")
		Assert.eq(Mix.gainToDb(0), -math.huge, "silence")
	end)

	test("sliders use the squared curve and clamp", function()
		Assert.near(Mix.sliderGain(0.5, A.SLIDER_EXPONENT), 0.25, 1e-9, "half slider")
		Assert.eq(Mix.sliderGain(2, 2), 1, "clamped high")
		Assert.eq(Mix.sliderGain(-1, 2), 0, "clamped low")
		Assert.eq(Mix.sliderGain(nil, 2), 1, "missing = full")
		Assert.eq(Mix.sliderGain(0 / 0, 2), 1, "NaN = full")
	end)

	test("bus gain: own slider x master, mute, the Clone bus follows SFX", function()
		local db = { SFX = 0, Clone = -4, Music = -6, Warnings = 0 }
		local s = { Master = 1, SFX = 0.5, Music = 1, Warnings = 1 }
		Assert.near(Mix.busGain("SFX", db, s, 2, 0.25, false, false), 0.25, 1e-9, "SFX at half")
		Assert.near(Mix.busGain("Clone", db, s, 2, 0.25, false, false), Mix.dbToGain(-4) * 0.25, 1e-9, "Clone")
		Assert.eq(Mix.busGain("Music", db, s, 2, 0.25, true, false), 0, "muted")
		s.Master = 0.5
		Assert.near(Mix.busGain("Music", db, s, 2, 0.25, false, false), Mix.dbToGain(-6) * 0.25, 1e-9, "master")
	end)

	test("Warnings keep their 25% floor and ignore the Music slider", function()
		local db = { Warnings = 0, Music = 0 }
		local s = { Master = 1, Music = 0, Warnings = 0 }
		local g = Mix.busGain("Warnings", db, s, A.SLIDER_EXPONENT, A.WARNINGS_FLOOR, false, false)
		Assert.near(g, A.WARNINGS_FLOOR ^ A.SLIDER_EXPONENT, 1e-9, "floor with the Alerts slider at 0")
		s.Master = 0
		Assert.near(Mix.busGain("Warnings", db, s, 2, 0.25, false, false), 0.0625, 1e-9, "floor with master 0")
		Assert.eq(Mix.busGain("Warnings", db, s, 2, 0.25, true, false), 0, "mute all silences them")
		Assert.near(Mix.busGain("Warnings", db, s, 2, 0.25, true, true), 0.0625, 1e-9, "unless configured")
	end)

	test("ducks: active until their end, never stack, extend, prune", function()
		local ducks = {}
		Assert.eq(Mix.duckDb(ducks, 0, -4), 0, "no duck")
		Mix.addDuck(ducks, "Busted", 0, A.DUCK_SECONDS)
		Mix.addDuck(ducks, "Diamond", 0.1, A.DUCK_SECONDS)
		Assert.eq(Mix.duckDb(ducks, 0.3, -4), -4, "ducked once, not -8")
		Assert.eq(Mix.addDuck(ducks, "Busted", 0.5, 0.6), 1.1, "extended")
		Assert.eq(Mix.addDuck(ducks, "Busted", 0.2, 0.1), 1.1, "a shorter duck never shortens")
		Mix.pruneDucks(ducks, 1.2)
		Assert.eq(next(ducks), nil, "all expired")
		Assert.eq(Mix.duckDb(ducks, 1.2, -4), 0, "released")
	end)

	test("Crew Layers tiers follow the clone thresholds (§7.2)", function()
		local th = A.LAYER_THRESHOLDS
		Assert.eq(Mix.tierFor(0, th), 0, "S0 base")
		Assert.eq(Mix.tierFor(1, th), 1, "S1 at 1+")
		Assert.eq(Mix.tierFor(2, th), 1, "still S1")
		Assert.eq(Mix.tierFor(3, th), 2, "S2 at 3+")
		Assert.eq(Mix.tierFor(6, th), 3, "S3 at 6+")
		Assert.eq(Mix.tierFor(8, th), 3, "8 OF ME is S3")
		Assert.eq(Mix.tierFor(10, th), 4, "S4 at 10+")
		Assert.eq(Mix.tierFor(16, th), 4, "capped")
	end)

	test("mixes mode: exactly one mix heard, picked by tierToMix", function()
		local map = { 1, 2, 3, 4, 5 }
		for tier = 0, 4 do
			local g = Mix.setGains("mixes", "mixes", tier, 5, map, nil)
			Assert.eq(sum(g), 1, "one-hot at S" .. tier)
			Assert.eq(g[tier + 1], 1, "mix for S" .. tier)
		end
		local g3 = Mix.setGains("mixes", "mixes", 4, 3, { 1, 1, 2, 3, 3 }, nil)
		Assert.eq(g3[3], 1, "3-mix set at S4")
		local beyond = Mix.setGains("mixes", "mixes", 9, 3, { 1, 1, 2, 3, 3 }, nil)
		Assert.eq(beyond[3], 1, "tiers beyond the map hold the last mix")
		Assert.eq(#Mix.setGains("mixes", "mixes", 0, 0, nil, nil), 0, "empty set")
	end)

	test("stems mode: S0 always on, stems add up with the tier", function()
		local g = Mix.setGains("mixes", "stems", 2, 5, nil, nil)
		Assert.eq(sum(g), 3, "S0 + S1 + S2")
		Assert.eq(g[4], 0, "S3 off")
		Assert.eq(sum(Mix.setGains("mixes", "stems", 0, 5, nil, nil)), 1, "base only")
	end)

	test("a playlist plays its active track only", function()
		local g = Mix.setGains("playlist", "mixes", 3, 2, nil, 2)
		Assert.eq(g[1], 0, "track 1 off")
		Assert.eq(g[2], 1, "track 2 on")
		Assert.eq(Mix.setGains("playlist", "mixes", 0, 2, nil, 9)[2], 1, "clamped")
	end)

	test("tonal ladders: semitones to PlaybackSpeed, clamped to the ladder", function()
		local steps = A.ARPEGGIO_STEPS
		Assert.near(Mix.stepSpeed(steps, 0), 1, 1e-9, "root")
		Assert.near(Mix.stepSpeed(steps, 5), 2, 1e-9, "octave (c)")
		Assert.near(Mix.stepSpeed(steps, 2), 2 ^ (4 / 12), 1e-9, "major third (E)")
		Assert.near(Mix.stepSpeed(steps, 20), 2 ^ (16 / 12), 1e-9, "beyond the ladder holds e")
		Assert.near(Mix.stepSpeed(steps, -3), 1, 1e-9, "below holds the root")
		Assert.eq(Mix.stepSpeed({}, 3), 1, "empty ladder")
	end)

	test("jitter stays inside its band", function()
		Assert.near(Mix.jitter(1, 0.04, 1), 1.04, 1e-9, "top")
		Assert.near(Mix.jitter(1, 0.04, -1), 0.96, 1e-9, "bottom")
		Assert.near(Mix.jitter(0.5, 0.1, 5), 0.55, 1e-9, "clamped u")
	end)

	test("the clone arpeggio: 60 ms apart, never wider than 0.4 s", function()
		local four = Mix.arpeggioOffsets(4, A.ARPEGGIO_STAGGER, A.ARPEGGIO_MAX_STAGGER)
		Assert.eq(#four, 4, "four notes")
		Assert.near(four[4], 3 * A.ARPEGGIO_STAGGER, 1e-9, "60 ms apart")
		local sixteen = Mix.arpeggioOffsets(16, 0.06, 0.4)
		Assert.near(sixteen[16], 0.4, 1e-9, "squeezed to 0.4 s")
		Assert.eq(#Mix.arpeggioOffsets(0, 0.06, 0.4), 0, "no clones, no notes")
	end)

	test("the 128 BPM grid: whole bars per run, next bar line", function()
		local bar = Mix.barSeconds(A.MUSIC_BPM)
		Assert.near(bar, 1.875, 1e-9, "one bar")
		Assert.near(30 / bar, 16, 1e-9, "30 s = 16 bars")
		Assert.near(60 / bar, 32, 1e-9, "60 s = 32 bars")
		Assert.near(Mix.nextBar(10, 10.5, 128), 11.875, 1e-9, "next bar")
		Assert.near(Mix.nextBar(10, 11.875, 128), 11.875, 1e-9, "on the bar line")
		Assert.near(Mix.nextBar(10, 9, 128), 10, 1e-9, "before the start")
	end)

	test("countdown steps over the last 10 seconds", function()
		Assert.eq(Mix.countdownStep(10, 10), 0, "10 s left")
		Assert.eq(Mix.countdownStep(9.5, 10), 0, "still the 10th second")
		Assert.eq(Mix.countdownStep(1, 10), 9, "last second")
		Assert.eq(Mix.countdownStep(11, 10), nil, "before the window")
		Assert.eq(Mix.countdownStep(0, 10), nil, "over")
	end)

	test("Christmas window is inclusive and crosses the new year", function()
		local w = A.CHRISTMAS
		Assert.falsy(Mix.inWindow({ 2026, 12, 2 }, w), "the day before launch")
		Assert.truthy(Mix.inWindow({ 2026, 12, 3 }, w), "launch day")
		Assert.truthy(Mix.inWindow({ 2026, 12, 31 }, w), "new year's eve")
		Assert.truthy(Mix.inWindow({ 2027, 1, 4 }, w), "last day")
		Assert.falsy(Mix.inWindow({ 2027, 1, 5 }, w), "after")
		Assert.eq(Mix.dayNumber(1970, 1, 1), 0, "epoch")
		Assert.eq(Mix.dayNumber(2026, 12, 3) - Mix.dayNumber(2026, 11, 12), 21, "21 days to launch")
	end)
end
