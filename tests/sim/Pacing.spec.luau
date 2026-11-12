-- L2: first-session pacing to the swarm moment (MASTERPLAN §4.2 "8 OF ME, about
-- minute 8", §7.5 funnel "SwarmSeen by minute 10", §10.3 Nov 30 go/no-go). The sim
-- fixes the STRUCTURE: the swarm is Clone Party run 8 (7 clones + you), after L1-L4,
-- so the Clone Party leg alone (runs 1-7, run length fixed) comes before it. The
-- CLOCK is not the sim's to prove: it is printed as a model, never asserted, until
-- kid wave 1 measures it.
--
-- OPEN CONFLICT (owner decision, MASTERPLAN §4.2 vs §7.5): the plan's own estimate
-- puts L1-L4 at 12-18 min, which lands the swarm at about minute 16-22, not by
-- minute 10. Options: unlock Clone Party earlier in session 1 (e.g. after L2),
-- shorten L1-L4, or move the SwarmSeen target to about minute 15-20. A green suite
-- here means only that the structure holds.

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local Harness = require("./Harness")
local Solutions = require("./Solutions")

local DECK_SECONDS = 3 -- [ESTIMATE] a glance at the Clone Deck, then the next run
local LEVEL_WRAP_SECONDS = 20 -- [ESTIMATE] results + Heist Reel + next level start
local FUNNEL_MINUTES = 10 -- §7.5 target: >= 60% SwarmSeen by minute 10
local PLAN_L1_L4_MINUTES = { 12, 18 } -- §4.2 session-length estimate for L1-L4

local H = Config.Heist

local function rewind(levelIndex: number, run: number): number
	local T = H.REWIND_TRANSITION
	if levelIndex == 1 or run > H.QUICK_REWIND_FROM_RUN then
		return T[2]
	end
	return T[1]
end

-- L1-L4 at the scripted bot's pace (a perfect player: the floor, not a forecast).
local function botStoryMinutes(): number
	local total = 0
	for n = 1, 4 do
		local level = Harness.level(n)
		local _, runs = Harness.play(level, Solutions.planFor(level))
		local t = H.FIRST_RUN_INTRO
		for r, run in runs do
			t += run.t
			if r > 1 then
				t += rewind(n, r) + (if n == 1 then H.TUTORIAL_BETWEEN_SECONDS else DECK_SECONDS)
			end
		end
		total += t + LEVEL_WRAP_SECONDS
	end
	return total / 60
end

-- Clone Party from its start to the start of run 8: runs 1-7 go to the tape (kids
-- steal until the timer runs out), with the transitions between them.
local function partyLegMinutes(): number
	local party = Harness.level(5)
	local t = H.FIRST_RUN_INTRO
	for r = 2, party.dawnRuns do
		t += party.runSeconds + rewind(5, r) + DECK_SECONDS
	end
	return t / 60
end

return function(test)
	test("the swarm is structural: Clone Party run 8 = 7 clones + you, whatever the pace", function()
		local party = Harness.level(5)
		Assert.eq(party.dawnRuns, Config.Levels.PARTY_DAWN_RUNS, "Dawn at run 8")
		local clonesInLastRun = party.dawnRuns - 1
		Assert.eq(clonesInLastRun + 1, Config.Sim.SWARM_OF_ME, "the last run before Dawn holds 8 of you")
		Assert.truthy(party.cap >= party.dawnRuns - 1, "the cap never blocks the swarm")
		-- The Clone Party leg before the swarm cannot be shorter than its 7 full runs.
		Assert.truthy(partyLegMinutes() >= (party.dawnRuns - 1) * party.runSeconds / 60, "7 runs on the tape")
	end)

	test("first session to the swarm: printed model (no pass/fail on the clock)", function()
		local party = partyLegMinutes()
		local bot = botStoryMinutes()
		local lo, hi = PLAN_L1_L4_MINUTES[1] + party, PLAN_L1_L4_MINUTES[2] + party
		local budget = FUNNEL_MINUTES - party
		print(
			string.format(
				"        [model] Clone Party runs 1-7: %.1f min. Swarm at %.1f min at bot pace (L1-L4 %.1f min, a floor)",
				party,
				bot + party,
				bot
			)
		)
		print(
			string.format(
				"        [model] with the plan's L1-L4 estimate (%d-%d min, §4.2): swarm at minute %.1f-%.1f",
				PLAN_L1_L4_MINUTES[1],
				PLAN_L1_L4_MINUTES[2],
				lo,
				hi
			)
		)
		print(
			string.format(
				"        [model] minute %d (§7.5) leaves L1-L4 %.1f min: %s",
				FUNNEL_MINUTES,
				budget,
				if lo > FUNNEL_MINUTES
					then "CONFLICT with the plan's estimate (owner: earlier Clone Party, shorter L1-L4, or a later target)"
					else "inside the plan's estimate"
			)
		)
		-- Only the model's own consistency: a perfect player is faster than the plan's kid.
		Assert.truthy(bot < PLAN_L1_L4_MINUTES[1], "the bot floor is under the plan's estimate")
	end)
end
