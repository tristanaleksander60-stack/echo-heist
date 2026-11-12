-- L2: Relaxed (PLAN_STEAM_PLUS §6.1 item 5, WALKTHROUGH P0-2): a level modifier on the spec
-- (Levels/Relaxed, the daily-vault modifier path) plus the sim's Relaxed rules. Slower Gus
-- (patrol and chase), runs +50%, detection x2, no Diamond (Data/Progress, unit spec), and the
-- sim stays deterministic: the same inputs give the same hashes, and the unrelaxed levels are
-- untouched. Every story level's solution still clears at par when relaxed (the "Show me?"
-- ghost replays those solution runs, Shared/Heist/GhostTapes).

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local Catalog = require("../../src/shared/Levels/Catalog")
local Relaxed = require("../../src/shared/Levels/Relaxed")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Harness = require("./Harness")
local NaiveKid = require("./NaiveKid")
local Solutions = require("./Solutions")

local MULT = Config.Onboarding.RELAXED_GUARD_SPEED_MULT

local function relaxedLevel(n: number): any
	return LevelSpec.compile(Relaxed.apply(Harness.spec(n)))
end

local function hashes(runs: { any }): string
	local out = {}
	for _, r in runs do
		table.insert(out, string.format("%08x", r.hash))
	end
	return table.concat(out, ",")
end

return function(test)
	test("Relaxed.apply: a fresh copy, story only, guards slower, flag kept by compile", function()
		local spec = Harness.spec(4)
		local speed = spec.guards[1].speed or Config.Sim.GUARD_SPEED
		local r = Relaxed.apply(spec)
		Assert.truthy(r ~= spec, "a copy")
		Assert.eq(spec.relaxed, nil, "the catalog spec is untouched")
		Assert.near(r.guards[1].speed, speed * MULT, 1e-9, "Gus slower")
		Assert.near(Relaxed.apply(r).guards[1].speed, speed * MULT, 1e-9, "applying twice changes nothing")
		local ok, errs = LevelSpec.validate(r)
		Assert.truthy(ok, table.concat(errs, "; "))
		local level = LevelSpec.compile(r)
		Assert.truthy(level.relaxed, "compiled flag")
		Assert.falsy(Harness.level(4).relaxed, "the plain level is not relaxed")
		Assert.truthy(level.guards[1].route.period > Harness.level(4).guards[1].route.period, "a longer patrol")
		Assert.falsy(Relaxed.canApply(Harness.spec(5)), "not the party")
		Assert.falsy(pcall(Relaxed.apply, Harness.spec(5)), "party refused")
		for _, spec2 in Catalog do
			if (spec2.kind or "story") == "story" then
				Assert.truthy(Relaxed.canApply(spec2), spec2.id .. " can be relaxed")
			end
		end
	end)

	test("a relaxed level turns on the sim rules: 45 s runs, detection x2, slower chase", function()
		local plain = HeistSim.new(Harness.level(4), { players = { 1 } })
		local sim = HeistSim.new(relaxedLevel(4), { players = { 1 } })
		Assert.truthy(sim.relaxed, "relaxed from the level")
		HeistSim.startRun(sim)
		Assert.eq(sim.runLength, 30 * Config.Rec.RELAXED_LENGTH_MULT, "45 s")
		Assert.near(sim.ctx.catchT, Config.Sim.GUARD_CATCH_SECONDS * Config.Sim.RELAXED_DETECT_MULT, 1e-9, "x2")
		Assert.near(sim.ctx.chaseSpeed, plain.ctx.chaseSpeed * MULT, 1e-9, "chase slower")
		Assert.truthy(HeistSim.result(sim).data.relaxed, "the result says so (no Diamond, off the boards)")
		Assert.falsy(HeistSim.offerRelaxed(sim, 1), "never offered again")
	end)

	test("determinism: a relaxed heist twice gives the same hashes; the plain level is unchanged", function()
		local level = relaxedLevel(4)
		local plan = NaiveKid.plan(level, 7, 4)
		local _, a = Harness.play(level, plan)
		local _, b = Harness.play(level, NaiveKid.plan(level, 7, 4))
		Assert.eq(hashes(a), hashes(b), "same inputs, same hashes")
		local plain = Harness.level(4)
		local _, c = Harness.play(plain, NaiveKid.plan(plain, 7, 4))
		local _, d = Harness.play(plain, NaiveKid.plan(plain, 7, 4))
		Assert.eq(hashes(c), hashes(d), "plain still deterministic")
		Assert.truthy(hashes(a) ~= hashes(c), "relaxed is a different world (slower Gus)")
	end)

	for _, n in { 2, 3, 4, 6 } do
		test(string.format("L%d: the solution (the ghost's steps) still clears at par when relaxed", n), function()
			local level = relaxedLevel(n)
			local sim = Harness.play(level, Solutions.planFor(Harness.level(n)))
			local r = HeistSim.result(sim)
			Assert.eq(sim.overReason, "Complete", "complete")
			Assert.le(r.clonesUsed, level.par, "at par")
			Assert.truthy(r.data.relaxed, "relaxed result")
		end)
	end
end
