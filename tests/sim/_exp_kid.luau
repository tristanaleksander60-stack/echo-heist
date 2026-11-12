local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local EventLog = require("../../src/shared/Sim/EventLog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local Catalog = require("../../src/shared/Levels/Catalog")
local Harness = require("./Harness")
local NaiveKid = require("./NaiveKid")
local EV = EventLog.EV
local specs = { Catalog[5], Catalog[6] }
for _, s in DailyVaults.designs do table.insert(specs, s) end
for _, spec in specs do
	local level = LevelSpec.compile(spec)
	local miss2, miss3 = 0, 0
	local laughs = 0
	for seed = 1, 40 do
		local _, runs = Harness.play(level, NaiveKid.plan(level, seed, 3))
		local b2, b3 = false, false
		for r, run in runs do
			local b = EventLog.count(run.log, EV.Bank) > 0
			if r <= 2 then b2 = b2 or b end
			b3 = b3 or b
			laughs += run.catches + run.busted + run.zapped + run.stuck + run.shrugs
		end
		if not b2 then miss2 += 1 end
		if not b3 then miss3 += 1 end
	end
	print(string.format("%-26s miss2 %2d miss3 %2d laughs %d", spec.id, miss2, miss3, laughs))
end
