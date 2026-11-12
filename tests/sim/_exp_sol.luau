local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local EventLog = require("../../src/shared/Sim/EventLog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local Catalog = require("../../src/shared/Levels/Catalog")
local Harness = require("./Harness")
local Solutions = require("./Solutions")
local process = require("@lune/process")
local EV = EventLog.EV
local filter = process.args[1]
local function try(spec, tag)
	local level = LevelSpec.compile(spec)
	local sim, runs = Harness.play(level, Solutions.planFor(level))
	local r = HeistSim.result(sim)
	local bad = {}
	for i, run in runs do
		for _, k in { "Rejected", "Stuck", "Zap", "Busted", "Caught", "Suspect", "Shrug" } do
			local n = EventLog.count(run.log, EV[k])
			if n > 0 then table.insert(bad, string.format("run%d %s=%d", i, k, n)) end
		end
	end
	print(string.format("%-26s %-9s %s %-8s banked %5d runs %d clones %d stars %d t %.1f %s", spec.id, tag, r.phase, r.reason, r.banked, r.runs, r.clonesUsed, r.stars.count, r.totalTime, table.concat(bad, " ")))
	if process.args[2] then print(Harness.dump(runs)) end
end
for _, spec in Catalog do if not filter or string.find(spec.id, filter, 1, true) then if spec.num >= 105 then try(spec, "") end end end
for _, spec in DailyVaults.designs do
	if not filter or string.find(spec.id, filter, 1, true) then
		try(spec, "None")
		for _, m in spec.daily.modifiers do if m ~= "None" then try(DailyVaults.apply(spec, m), m) end end
	end
end
