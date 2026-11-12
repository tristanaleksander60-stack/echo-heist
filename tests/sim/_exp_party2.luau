local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local EventLog = require("../../src/shared/Sim/EventLog")
local Loot = require("../../src/shared/Sim/Loot")
local Harness = require("./Harness")
local spec = require("../../src/shared/Levels/L5_CloneParty")
local level = LevelSpec.compile(spec)
local EV = EventLog.EV
local function laneOf(x) if x < -9 then return -12.5 elseif x < -1 then return -4 elseif x < 7 then return 4 else return 12.5 end end
local function grabWhenBack(item)
	local idx = LevelSpec.indexOf(level, "loot", item)
	local step
	step = { decide = function(bot, sim, view, t)
		if Loot.available(sim.loot, idx) then return { { grab = item } } end
		return { { wait = 0.05 }, step }
	end }
	return step
end
local function trip(item, out)
	local d = level.loot[LevelSpec.indexOf(level, "loot", item)]
	local lane = laneOf(d.x)
	local entryX = if lane < 0 then -6 else 6
	table.insert(out, { go = { 0, 9 } })
	table.insert(out, { go = { entryX, -4.5 } })
	table.insert(out, { go = { lane, -4.5 } })
	table.insert(out, { goLoot = item })
	table.insert(out, grabWhenBack(item))
	table.insert(out, { go = { lane, -4.5 } })
	table.insert(out, { go = { entryX, -4.5 } })
	table.insert(out, { go = { 0, 9 } })
	table.insert(out, { go = { 0, 17 } })
end
local function farm(items)
	local steps = {}
	for k = 1, 12 do trip(items[(k - 1) % #items + 1], steps) end
	table.insert(steps, { stay = true })
	return steps
end
local plans = {
	{ "Shelf1W3", "Shelf1W2" }, { "Shelf3E3", "Shelf3E2" }, { "Shelf1E3", "Shelf1E2" }, { "Shelf3W3", "Shelf3W2" },
	{ "Shelf2W3", "Shelf2W2" }, { "Shelf2E3", "Shelf2E2" }, { "Shelf1W1", "Shelf1E1" }, { "Shelf3W1", "Shelf3E1" },
}
local plan = { runs = {} }
for r = 1, 8 do table.insert(plan.runs, { [1] = farm(plans[r]) }) end
local sim, runs = Harness.play(level, plan)
local r = HeistSim.result(sim)
for i, run in runs do
	print(i, "banked", run.banked, "shrugs", run.shrugs, "rej", EventLog.count(run.log, EV.Rejected), "banks", EventLog.count(run.log, EV.Bank), "stuck", run.stuck, "busted", run.busted, "t", run.t)
end
print(r.phase, r.reason, r.banked, r.tierMet, r.stars.count, "time", r.totalTime)
