local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
for k, spec in DailyVaults.designs do
	for _, m in DailyVaults.MODIFIERS do
		if m == "None" or table.find(spec.daily.modifiers, m) then
			local s = DailyVaults.apply(spec, m)
			local ok, errs = LevelSpec.validate(s)
			if not ok then print(spec.id, m, table.concat(errs, "; ")) end
		end
	end
	print(k, spec.id, "slot", DailyVaults.numberOf[spec.id], "advent Dec", DailyVaults.adventDayOf(spec))
end
