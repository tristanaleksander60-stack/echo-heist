local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local EventLog = require("../../src/shared/Sim/EventLog")
local Harness = require("./Harness")
local NaiveKid = require("./NaiveKid")
local spec = require("../../src/shared/Levels/L5_CloneParty")
local level = LevelSpec.compile(spec)
local EV = EventLog.EV
local hauls = {}
for seed = 1, 40 do
	local sim, runs = Harness.play(level, NaiveKid.plan(level, seed, 8))
	local r = HeistSim.result(sim)
	local shrugs, busted = 0, 0
	for _, run in runs do shrugs += run.shrugs busted += run.busted end
	table.insert(hauls, r.banked)
	print(seed, r.phase, r.reason, r.banked, r.tierMet, "shrugs", shrugs, "busted", busted, "alarms", (function() local n=0 for _, run in runs do n += EventLog.count(run.log, EV.AlarmOn) end return n end)())
end
table.sort(hauls)
print("median", hauls[20], "min", hauls[1], "max", hauls[40])
