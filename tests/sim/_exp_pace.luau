local HeistSim = require("../../src/shared/Sim/HeistSim")
local Harness = require("./Harness")
local Solutions = require("./Solutions")
local total = 0
for n = 1, 6 do
	local level = Harness.level(n)
	local sim, runs = Harness.play(level, Solutions.planFor(level))
	local r = HeistSim.result(sim)
	local ts = {}
	for _, run in runs do table.insert(ts, string.format("%.2f", run.t)) end
	print(level.id, r.runs, string.format("%.2f", r.totalTime), table.concat(ts, " "))
end
