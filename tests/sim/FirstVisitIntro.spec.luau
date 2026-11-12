-- L2: run 1's longer first-visit intro (Config.Heist.FIRST_VISIT_INTRO_EXTRA, Help.firstRunIntro) is wall-clock
-- presentation only. The server starts the run clock `transition` seconds later (HeistInstance.startRun passes
-- now + transition to HeistSim.startRun); the sim's ticks, event log and recording are the same whether the
-- intro is 1 s or 3 s, and the run ends exactly the extra seconds later on the server clock.

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Help = require("../../src/shared/Heist/Help")
local Harness = require("./Harness")

local FRAME = 1 / 60
local H = Config.Heist

-- Plays L2's run 1 on the server clock with the given run-1 intro. The player stands at spawn through the
-- intro (the server freezes them), then walks a path that depends only on sim time. Returns the run hash,
-- tick count, the run's recording and when (server time) the run ended.
local function run1(transition: number): (number, number, any, number)
	local level = Harness.level(2)
	local sim = HeistSim.new(level, { players = { 1 }, walkSpeed = Config.Rec.WALK_SPEED })
	local now = 5000
	local runIndex = HeistSim.startRun(sim, now + transition)
	Assert.eq(runIndex, 1, "run 1 starts")
	local spawn = level.spawns[1]
	local frames = 0
	while sim.phase == "Run" do
		now += FRAME
		frames += 1
		local t = sim.t
		HeistSim.setInput(sim, 1, spawn.x + 6 * math.sin(t * 0.7), spawn.y, spawn.z - math.min(t, 8) * 1.5)
		HeistSim.update(sim, now)
		assert(frames < 20000, "runaway")
	end
	local rec = sim.players[1].deck.slots[1] and sim.players[1].deck.slots[1].rec
	return sim.lastRun.hash, sim.lastRun.ticks, rec, now
end

return function(test)
	test("first-visit intro: L2 run 1 gets the extra wall-clock time; the sim is identical", function()
		local level = Harness.level(2)
		local long = Help.firstRunIntro(level, false, 1)
		Assert.truthy(long > H.FIRST_RUN_INTRO, "L2's first visit has a longer intro")
		local hA, ticksA, recA, endA = run1(H.FIRST_RUN_INTRO)
		local hB, ticksB, recB, endB = run1(long)
		Assert.eq(hB, hA, "same event log hash")
		Assert.eq(ticksB, ticksA, "same tick count")
		Assert.truthy(recA ~= nil and recB ~= nil, "both runs recorded a clone")
		Assert.eq(#recB.px, #recA.px, "same recording length")
		for i = 1, #recA.px do
			Assert.eq(recB.px[i], recA.px[i], "same recorded x at sample " .. i)
			Assert.eq(recB.pz[i], recA.pz[i], "same recorded z at sample " .. i)
		end
		Assert.near(endB - endA, long - H.FIRST_RUN_INTRO, 2 * FRAME, "the run ends the extra seconds later")
	end)

	test("first-visit intro: never on L1, a daily vault or a repeat visit", function()
		Assert.eq(Help.firstRunIntro(Harness.level(1), false, 1), H.FIRST_RUN_INTRO, "L1 (the tutorial)")
		Assert.eq(Help.firstRunIntro(Harness.level(2), true, 1), H.FIRST_RUN_INTRO, "a daily vault")
		Assert.eq(Help.firstRunIntro(Harness.level(2), false, 0), H.FIRST_RUN_INTRO, "nobody new to it")
	end)
end
