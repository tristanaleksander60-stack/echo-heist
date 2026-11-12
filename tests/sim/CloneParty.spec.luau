-- L2: L5 "Clone Party" (MASTERPLAN §4.2 row 5, §3.6, §5.1-5.3, §0 C12): the swarm
-- moment ("8 OF ME" at run 8), the Crew Line-up, the time-locked till (opens at
-- 0:20, so its Alarm Run is always the last act of a run) replaying at the same
-- second every loop, the shutter and van timers, bag levels, Gus dozing.

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Harness = require("./Harness")
local Solutions = require("./Solutions")

local EV = EventLog.EV
local HZ = Config.Rec.HZ
local OPENS = Config.Levels.PARTY_TILL_OPENS_SECONDS

-- Straight to the till (a kid's first grab), then wait for its timer and rob it.
local function tillRun(early: boolean?): any
	local steps: { any } = {
		{ go = { 0, 9 } },
		{ go = { -7, 0 } },
		{ goLoot = "Register" },
	}
	if early then
		table.insert(steps, { grab = "Register" }) -- refused: still locked
	end
	for _, step in
		{
			{ waitUntil = OPENS },
			{ grab = "Register" },
			{ go = { 0, 9 } },
			{ go = { 0, 17 } },
			{ endRun = true },
		}
	do
		table.insert(steps, step)
	end
	return { [1] = steps }
end

return function(test)
	local level = Harness.level(5)

	test("the swarm: run 8 starts with 7 clones + you = 8 OF ME; Dawn lines up all 8", function()
		local ofMe = {}
		local sim, runs = Harness.play(level, Solutions.planFor(level), {
			onTick = function(s: any)
				if s.tick == 0 then
					ofMe[s.runIndex] = HeistSim.ofMe(s, 1)
				end
			end,
		})
		Assert.eq(Config.Sim.SWARM_OF_ME, 8, "the stamp is 8 OF ME")
		Assert.eq(ofMe[8], Config.Sim.SWARM_OF_ME, "run 8: 8 copies of you")
		Assert.eq(EventLog.count(runs[8].log, EV.Swarm, 1, 8), 1, "Swarm event, seat 1, 8 copies")
		Assert.eq(EventLog.count(runs[7].log, EV.Swarm, 1, 7), 1, "run 7: 6 clones = SwarmSeen")
		Assert.eq(EventLog.count(runs[6].log, EV.Swarm), 0, "run 6: 5 clones, not yet")
		Assert.eq(level.hooks.swarm.run, level.dawnRuns, "the hook data names the run")
		local lineup = HeistSim.lineup(sim)
		Assert.eq(#lineup, 8, "Crew Line-up: 7 clones + you")
		Assert.eq(lineup[8].kind, "player", "you pose last")
		for i = 1, 7 do
			Assert.eq(lineup[i].slot, i, "clones in record order")
		end
		Assert.near(lineup[8].delay, 7 * Config.Sim.LINEUP_STAGGER, 1e-9, "60 ms ripple")
	end)

	test("Gus dozes through every run without the alarm", function()
		local _, runs = Harness.play(level, Solutions.planFor(level))
		for i = 1, 7 do
			Assert.eq(EventLog.count(runs[i].log, EV.Spotted), 0, "run " .. i .. ": nobody seen")
			Assert.eq(EventLog.count(runs[i].log, EV.AlarmOn), 0, "run " .. i .. ": no alarm")
		end
	end)

	test("the till is time-locked: a grab before 0:20 is refused, then it opens", function()
		local _, out = Harness.play(level, { runs = { tillRun(true) } })
		local run = out[1]
		local refused = 0
		for i = 1, run.log.n do
			if run.log.kind[i] == EV.Rejected and run.log.c[i] == HeistSim.FAIL.Locked then
				refused += 1
				Assert.truthy(run.log.tick[i] < OPENS * HZ, "refused before it opens")
			end
		end
		Assert.eq(refused, 1, "the early grab is refused as Locked")
		local alarmAt = EventLog.firstTick(run.log, EV.AlarmOn) :: number
		Assert.truthy(alarmAt >= OPENS * HZ and alarmAt <= OPENS * HZ + 2, "robbed (alarm on) as it opens")
		Assert.eq(run.banked, 300, "banked")
		Assert.eq(level.hooks.till.opensAt, OPENS, "the view shows the same countdown")
	end)

	test("the till trips the alarm at the same second in every later run", function()
		local runs = { tillRun() }
		for _ = 1, 3 do
			table.insert(runs, { [1] = { { stay = true } } })
		end
		local _, out = Harness.play(level, { runs = runs })
		local t1 = EventLog.firstTick(out[1].log, EV.AlarmOn)
		Assert.truthy(t1 ~= nil, "run 1 trips it")
		Assert.truthy((t1 :: number) >= OPENS * HZ, "never before 0:20")
		for i = 2, 4 do
			Assert.eq(EventLog.firstTick(out[i].log, EV.AlarmOn), t1, "run " .. i .. ": the clone re-trips it")
			Assert.eq(EventLog.count(out[i].log, EV.Bank, 1, 1), 1, "and banks the till again")
			Assert.eq(out[i].alarm and out[i].alarm.slot, 1, "lastRun.alarm names clone #1")
			Assert.eq(out[i].alarm and out[i].alarm.hint, nil, "late: no Redo hint")
		end
		Assert.eq(out[4].banked, 4 * 300, "robbed once per run")
	end)

	test("Alarm Run timers: the shutter drops 6 s after the till, the van timer outlasts the run", function()
		-- White-box: Gus is held in his office (chase speed 0) so the run lasts;
		-- the robber keeps the till inside the shop.
		local hold = function(s: any)
			s.ctx.chaseSpeed = 0
		end
		local _, out2 = Harness.play(level, {
			runs = {
				{
					[1] = {
						{ go = { 0, 9 } },
						{ go = { -7, 0 } },
						{ goLoot = "Register" },
						{ waitUntil = OPENS },
						{ grab = "Register" },
						{ go = { 0, -4 } },
						{ stay = true },
					},
				},
			},
		}, { onTick = hold })
		local run = out2[1]
		local alarmAt = EventLog.firstTick(run.log, EV.AlarmOn) :: number
		local lockAt = EventLog.firstTick(run.log, EV.AlarmLock) :: number
		local shutAt = EventLog.firstTick(run.log, EV.DoorShut, 1) :: number
		Assert.eq(lockAt - alarmAt, Config.Levels.PARTY_SHUTTER_SECONDS * HZ, "the shutter drops 6 s after the till")
		Assert.eq(shutAt - lockAt, math.ceil(Config.Sim.DOOR_CLOSE_SECONDS * HZ), "shutter slides shut")
		Assert.truthy(shutAt < level.runSeconds * HZ, "inside the run: the getaway beat")
		Assert.eq(run.reason, HeistSim.RUN_END.Timeout, "the 30 s run ends before the van timer")
		Assert.eq(EventLog.count(run.log, EV.VanLeft), 0, "the van never leaves in Clone Party")
		Assert.eq(run.banked, 0, "the till was never banked")
	end)

	test("a till robbed in run 1 costs later runs their last seconds, not the run", function()
		-- The reviewer's worst case: a kid robs the till first thing in run 1 (as soon as
		-- it opens) and stands still after; then farms as usual. The clone re-robs it at
		-- 0:20 every run, so every later run keeps its first 20 s and most of its haul.
		local plan = Solutions.planFor(level)
		local runs = { tillRun() }
		for r = 2, #plan.runs do
			table.insert(runs, plan.runs[r - 1])
		end
		local sim, out = Harness.play(level, { runs = runs })
		for r = 2, #out do
			Assert.truthy(out[r].t >= OPENS, string.format("run %d lasts %.1f s (>= 0:20)", r, out[r].t))
		end
		local r = HeistSim.result(sim)
		Assert.truthy(r.tierMet >= 2, "still Haul2 by Dawn: $" .. r.banked)
	end)

	test("bag levels: a bag-1 crew carries two items a trip and banks more", function()
		local function pairTrip(): { any }
			return {
				{ go = { 0, 9 } },
				{ go = { -6, -4.5 } },
				{ go = { -12.5, -4.5 } },
				{ goLoot = "Shelf1W2" },
				{ grab = "Shelf1W2" },
				{ goLoot = "Shelf1W3" },
				{ grab = "Shelf1W3" },
				{ go = { -12.5, -4.5 } },
				{ go = { -6, -4.5 } },
				{ go = { 0, 9 } },
				{ go = { 0, 17 } },
				{ endRun = true },
			}
		end
		local function play(bag: number): (any, any)
			local sim = HeistSim.new(level)
			HeistSim.addPlayer(sim, 1, { bag = bag })
			HeistSim.startRun(sim)
			local Bot = require("./Bot")
			local run = Harness.runOnce(sim, { Bot.new(level, 1, pairTrip()) }, Harness.history())
			return sim, run
		end
		local sim0, run0 = play(0)
		local sim1, run1 = play(1)
		Assert.eq(EventLog.count(run0.log, EV.Rejected), 1, "bag 0: the second grab is refused")
		Assert.eq(EventLog.count(run1.log, EV.Rejected), 0, "bag 1: room for two")
		Assert.eq(run0.banked, 25, "one toy")
		Assert.eq(run1.banked, 25 + 40, "a toy and a teddy")
		Assert.eq(HeistSim.result(sim1).bag, 1, "the result says a bag counted (no Diamond)")
		Assert.eq(HeistSim.result(sim0).bag, 0, "no bag")
	end)
end
