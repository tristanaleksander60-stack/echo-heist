-- L2: first-session pacing to the swarm. Owner decision 2026-11-12: L5 Clone Party is a
-- "party break" right after L2 (play order L1, L2, L5, L3, L4, L6), so the swarm lands
-- around minute 8-10 (MASTERPLAN §4.2 "8 OF ME", §7.5 funnel "SwarmSeen by minute 10",
-- §9.7 KPI bar >= 60 %, §10.3 Nov 30 go/no-go).
--
-- What the sim proves (asserted): the play order; SwarmSeen is the first Clone Party run
-- with SWARM_SEEN_CLONES own clones (run 7) and "8 OF ME" is run 8, a fixed number of
-- full runs into the party; at a perfect player's pace the swarm lands well inside minute
-- 10 (if that floor ever passed 10 the target would be impossible).
--
-- What it cannot prove: a kid's clock. The minute is a MODEL from the plan's own
-- estimates, printed as a band (lo / mid / hi), never asserted against the target, until
-- kid wave 1 (Nov 21-22) measures it. Inputs, each labelled:
--   Join    PlayerAdded to control in L1 (Minute10 counts from the join): 5 s .. 15 s
--           [ESTIMATE] (load, the garage's DATA_WAIT_SECONDS, the FTUE autostart).
--   L1      §7.5: first bank "≈ 40 s" .. the Nov 30 gate's median "≤ 60 s". The built L1
--           ends at that bank (§7.5's 40-180 s "second room" was not built), then a wrap.
--   L2      §4.2 does not split "L1-L4 ≈ 12-18 min". Its L1 is §7.5's 180 s, so L2, L3 and
--           L4 share the other 9-15 min: 3-5 min each. L2 is the easiest of the three, so
--           this is a conservative share for it.
--   Party   built from the level and Config.Heist: run 1 intro, full runSeconds runs (kids
--           steal until the timer runs out), the rewind lengths, and a between-run pause
--           from a glance (3 s) to the party auto-start (PARTY_BETWEEN_SECONDS, 10 s since
--           2026-11-12: the party's deck is read-only, so there is nothing to decide). With
--           the old 25 s pause the band reproduced §4.2's "Clone Party 5-8 min"; the plan now
--           says 5-6.5 min (asserted, so the band cannot drift from the plan unnoticed).
--   Wrap    results + Heist Reel + NEXT: 20 s [ESTIMATE] .. RESULTS_SECONDS (the card's max).
--   Later   L3, L4 3-5 min each (the same split), L6 8-12 min (§4.2): timeline only.

local Assert = require("../unit/Assert")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local Harness = require("./Harness")
local NaiveKid = require("./NaiveKid")
local RunCoach = require("../../src/shared/Heist/RunCoach")
local Solutions = require("./Solutions")

local H = Config.Heist
local S = Config.Sim
local EV = EventLog.EV
local HZ = Config.Rec.HZ

local TARGET_MINUTES = 10 -- §7.5 / §9.7: SwarmSeen by minute 10
local DECK_GLANCE = 3 -- [ESTIMATE] seconds: a glance at the Clone Deck, then the next run

-- Bands are { lo, hi } in seconds.
local JOIN = { 5, 15 } -- [ESTIMATE]
local L1_FIRST_BANK = { 40, 60 } -- §7.5 "≈ 40 s" .. §10.3 "median first bank ≤ 60 s"
local WRAP = { 20, H.RESULTS_SECONDS } -- [ESTIMATE] .. the results card's max
local PLAN_L1_L4 = { 12 * 60, 18 * 60 } -- §4.2 session length, L1-L4
local PLAN_L1 = 180 -- §7.5: the FTUE table runs to 180 s
local PLAN_PARTY = { 5 * 60, 6.5 * 60 } -- §4.2 session length, Clone Party (10 s auto-start)
local PLAN_BIG_SCORE = { 8 * 60, 12 * 60 } -- §4.2 session length, Big Score
local PAUSE = { DECK_GLANCE, H.PARTY_BETWEEN_SECONDS } -- between party runs
local STORY_LEVEL = { -- L2, L3, L4 each: an even share of the plan's L1-L4 after its L1
	(PLAN_L1_L4[1] - PLAN_L1) / 3,
	(PLAN_L1_L4[2] - PLAN_L1) / 3,
}

-- Levers the owner can pull (printed only): L2 in at most this long; the party auto-start
-- before 2026-11-12 (BETWEEN_MAX_SECONDS) for comparison.
local LEVER_L2 = 4 * 60
local OLD_PARTY_PAUSE = H.BETWEEN_MAX_SECONDS

-- The rewind before run `run` of launch level L<designNum>, plus the run coach's beat on the coached levels
-- (Shared/Heist/RunCoach.beatSeconds: L1 and L2, runs 2-3).
local function rewind(designNum: number, run: number): number
	local T = H.REWIND_TRANSITION
	local beat = RunCoach.beatSeconds(Harness.spec(designNum).id, run)
	if designNum == 1 or run > H.QUICK_REWIND_FROM_RUN then
		return T[2] + beat
	end
	return T[1] + beat
end

-- First run of the party whose log has a Swarm event for seat 1 with at least `copies`
-- copies of that player, and the event's time into the run.
local function swarmRun(runs: { any }, copies: number): (number?, number?)
	for r, run in runs do
		for b = copies, S.MAX_LEVEL_CAP + 1 do
			local tick = EventLog.firstTick(run.log, EV.Swarm, 1, b)
			if tick then
				return r, tick / HZ
			end
		end
	end
	return nil, nil
end

-- Party start to the swarm moment in run `upto` (fan-out included), runs of `runLen` s.
local function partyTo(party: any, upto: number, pause: number, runLen: { number }?): number
	local t = H.FIRST_RUN_INTRO
	for r = 1, upto - 1 do
		t += (if runLen then runLen[r] else party.runSeconds) + rewind(5, r + 1) + pause
	end
	return t + S.SWARM_FANOUT_SECONDS
end

-- The whole party: every run, the rewinds between them, then the wrap.
local function partyAll(party: any, pause: number, wrap: number): number
	local t = H.FIRST_RUN_INTRO + party.dawnRuns * party.runSeconds + wrap
	for r = 2, party.dawnRuns do
		t += rewind(5, r) + pause
	end
	return t
end

-- A launch level at the scripted bot's pace (a perfect player: a floor, not a forecast).
local function botLevel(n: number): number
	local level = Harness.level(n)
	local _, runs = Harness.play(level, Solutions.planFor(level))
	local t = H.FIRST_RUN_INTRO
	for r, run in runs do
		t += run.t
		if r > 1 then
			t += rewind(n, r) + (if n == 1 then H.TUTORIAL_BETWEEN_SECONDS else DECK_GLANCE)
		end
	end
	return t + WRAP[1]
end

-- L1 from first control (the run 1 intro included) to the first clone forming and the first bank.
local function l1Times(runs: { any }): (number?, number?)
	local t = H.FIRST_RUN_INTRO
	local clone = nil
	for r, run in runs do
		if r >= 2 and not clone then
			clone = t + H.TUTORIAL_CLONE_FADE_IN
		end
		local b = EventLog.firstTick(run.log, EV.Bank)
		if b then
			return clone, t + b / HZ
		end
		t += run.t + rewind(1, r + 1) + H.TUTORIAL_BETWEEN_SECONDS
	end
	return clone, nil
end

local function band(lo: number, hi: number): { number }
	return { lo, hi }
end

local function add(a: { number }, b: { number }): { number }
	return { a[1] + b[1], a[2] + b[2] }
end

local function fmt(b: { number }): string
	return string.format("%5.1f / %5.1f / %5.1f", b[1] / 60, (b[1] + b[2]) / 120, b[2] / 60)
end

return function(test)
	local party = Harness.level(5)

	-- MASTERPLAN §7.5's bars (first clone <= 30 s, first bank <= 45 s), for the scripted run and the median of 40
	-- coached kids (since the RUN2 CLARITY track the HUD's run coach points at the plate from second 0:
	-- NaiveKid.coachedBrain follows it). The old naive kids, who ignore the coach until the 16 s stuck hint, keep a
	-- floor: their median first bank stays within §10.3's gate (60 s; L1's auto-end now waits 3 s on the plate, so
	-- a kid who only wanders across it no longer makes a clone by accident).
	test("L1: first clone <= 30 s and first bank <= 45 s (bot, and the coached kids' median)", function()
		local level = Harness.level(1)
		local _, runs = Harness.play(level, Solutions.planFor(level))
		local c, b = l1Times(runs)
		Assert.truthy(c and c <= 30, "bot: first clone within 30 s")
		Assert.truthy(b and b <= 45, "bot: first bank within 45 s")
		local function kids(opts: any?): ({ number }, { number })
			local cs, bs = {}, {}
			for seed = 1, 40 do
				local _, kr = Harness.play(level, NaiveKid.plan(level, seed, 3, opts))
				local kc, kb = l1Times(kr)
				table.insert(cs, kc or math.huge)
				table.insert(bs, kb or math.huge)
			end
			table.sort(cs)
			table.sort(bs)
			return cs, bs
		end
		local cs, bs = kids({ kind = "coached" })
		local ns, nb = kids(nil)
		print(
			string.format(
				"        [L1] bot: clone %.1f s, bank %.1f s; coached kids' median: clone %.1f s, bank %.1f s (p90 %.1f s); uncoached: clone %.1f s, bank %.1f s",
				c :: number,
				b :: number,
				cs[20],
				bs[20],
				bs[36],
				ns[20],
				nb[20]
			)
		)
		Assert.le(cs[20], 30, "coached kids' median first clone within 30 s")
		Assert.le(bs[20], 45, "coached kids' median first bank within 45 s")
		Assert.le(nb[20], 60, "uncoached kids' median first bank within the 60 s gate")
	end)

	test("play order: L1, L2, the Clone Party break, L3, L4, then the Big Score", function()
		local nums = {}
		for _, spec in Catalog do
			table.insert(nums, spec.num - 100)
		end
		Assert.eq(table.concat(nums, ","), "1,2,5,3,4,6", "Catalog (garage order, NEXT)")
		Assert.eq(Config.Data.LEVEL_ORDER[3], party.dataId, "data play order")
		Assert.eq(Config.Data.Levels.CloneParty.unlockAfter, "TwoDoors", "the party opens after L2")
		Assert.eq(Config.Data.Levels.LightsOut.unlockAfter, "TwoDoors", "so does L3: a break, never a wall")
	end)

	test("the swarm is structural: SwarmSeen at Clone Party run 7, 8 OF ME at run 8", function()
		local _, runs = Harness.play(party, Solutions.planFor(party))
		local seenRun, seenAt = swarmRun(runs, 1)
		local ofMeRun = swarmRun(runs, S.SWARM_OF_ME)
		Assert.eq(seenRun, S.SWARM_SEEN_CLONES + 1, "SwarmSeen: the first run with 6 own clones")
		Assert.eq(ofMeRun, party.dawnRuns, "8 OF ME: the last run before Dawn")
		Assert.eq(party.dawnRuns, S.SWARM_OF_ME, "Dawn at run 8 = 7 clones + you")
		Assert.truthy(party.cap >= party.dawnRuns - 1, "the cap never blocks the swarm")
		Assert.near(seenAt :: number, S.SWARM_FANOUT_SECONDS, 1 / HZ, "the event waits for the fan-out")
		-- Nothing a kid does shortens this: 6 full runs before SwarmSeen.
		Assert.truthy(partyTo(party, S.SWARM_SEEN_CLONES + 1, 0) >= S.SWARM_SEEN_CLONES * party.runSeconds, "6 runs")
	end)

	test("the party model reproduces the plan's Clone Party estimate (§4.2: 5-6.5 min)", function()
		local lo = partyAll(party, PAUSE[1], WRAP[1])
		local hi = partyAll(party, PAUSE[2], WRAP[2])
		print(
			string.format(
				"        [model] Clone Party start to Dawn + wrap: %.1f-%.1f min (plan %.1f-%.1f)",
				lo / 60,
				hi / 60,
				PLAN_PARTY[1] / 60,
				PLAN_PARTY[2] / 60
			)
		)
		Assert.truthy(math.abs(lo - PLAN_PARTY[1]) <= 30, "fast end within 30 s of the plan's 5 min")
		Assert.truthy(math.abs(hi - PLAN_PARTY[2]) <= 30, "slow end within 30 s of the plan's 6.5 min")
	end)

	test("first session to the swarm: bot floor inside minute 10 (asserted), plan band printed", function()
		local seenRun = S.SWARM_SEEN_CLONES + 1
		local ofMeRun = S.SWARM_OF_ME

		-- Floor: the bot's own L1, L2 and party runs, quick pauses.
		local _, botParty = Harness.play(party, Solutions.planFor(party))
		local botRunLen = {}
		for r, run in botParty do
			botRunLen[r] = run.t
		end
		local floor = JOIN[1] + botLevel(1) + botLevel(2) + partyTo(party, seenRun, DECK_GLANCE, botRunLen)

		-- The plan's band, milestone by milestone (cumulative seconds from the join).
		local l1 = band(JOIN[1] + L1_FIRST_BANK[1] + WRAP[1], JOIN[2] + L1_FIRST_BANK[2] + WRAP[2])
		local l2 = add(l1, STORY_LEVEL)
		local seen = add(l2, band(partyTo(party, seenRun, PAUSE[1]), partyTo(party, seenRun, PAUSE[2])))
		local ofMe = add(l2, band(partyTo(party, ofMeRun, PAUSE[1]), partyTo(party, ofMeRun, PAUSE[2])))
		local partyDone = add(l2, band(partyAll(party, PAUSE[1], WRAP[1]), partyAll(party, PAUSE[2], WRAP[2])))
		local l3 = add(partyDone, STORY_LEVEL)
		local l4 = add(l3, STORY_LEVEL)
		local l6 = add(l4, PLAN_BIG_SCORE)

		print("        [model] first session, minute marks from the join (lo / mid / hi):")
		for _, row in
			{
				{ "L1 Back Room done", l1 },
				{ "L2 Two Doors done", l2 },
				{ `SwarmSeen (party run {seenRun})`, seen },
				{ `8 OF ME (party run {ofMeRun})`, ofMe },
				{ "Clone Party done", partyDone },
				{ "L3 Lights Out done", l3 },
				{ "L4 Night Clerk done", l4 },
				{ "L6 Big Score done", l6 },
			}
		do
			print(string.format("        [model]   %-24s %s", row[1], fmt(row[2])))
		end
		local share = math.clamp((TARGET_MINUTES * 60 - seen[1]) / (seen[2] - seen[1]), 0, 1)
		print(
			string.format(
				"        [model] SwarmSeen by minute %d: floor %.1f (bot), plan band %.1f-%.1f; minute %d is %d %% of the way from lo to hi",
				TARGET_MINUTES,
				floor / 60,
				seen[1] / 60,
				seen[2] / 60,
				TARGET_MINUTES,
				math.floor(share * 100 + 0.5)
			)
		)
		-- What moves the slow end: L2 cleared in LEVER_L2. And what the party's own 10 s
		-- auto-start bought (against the old BETWEEN_MAX_SECONDS pause).
		local l2Fast = math.min(STORY_LEVEL[2], LEVER_L2) - STORY_LEVEL[2]
		local oldPause = (OLD_PARTY_PAUSE - PAUSE[2]) * (seenRun - 1)
		print(
			string.format(
				"        [model] slow end with L2 <= %d min: %.1f; with the old %d s party pause it was %.1f",
				LEVER_L2 / 60,
				(seen[2] + l2Fast) / 60,
				OLD_PARTY_PAUSE,
				(seen[2] + oldPause) / 60
			)
		)
		-- The same plan numbers with the party after L4 (the order before the decision).
		local old = add(add(l2, STORY_LEVEL), STORY_LEVEL)
		old = add(old, band(partyTo(party, seenRun, PAUSE[1]), partyTo(party, seenRun, PAUSE[2])))
		print(
			string.format(
				"        [model] party after L4 (before 2026-11-12): SwarmSeen at %.1f-%.1f",
				old[1] / 60,
				old[2] / 60
			)
		)

		Assert.truthy(floor < TARGET_MINUTES * 60, "a perfect player sees the swarm inside minute 10")
		Assert.truthy(floor < seen[1], "the bot floor is under the plan's fast end")
		Assert.truthy(seen[1] < old[1], "the party break moves the swarm earlier")
	end)
end
