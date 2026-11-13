local KitPlan = require("../../src/server/Heist/KitPlan")
local DecorPlan = require("../../src/server/Heist/DecorPlan")
local KitData = require("../../src/server/Kit/KitData")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Catalog = require("../../src/shared/Levels/Catalog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local Config = require("../../src/shared/Config")
local LevelDress = require("../../src/server/Heist/LevelDress")
local specs = (KitData :: any).parts
local list = {}
for _, s in Catalog do table.insert(list, s) end
for _, s in DailyVaults.designs do table.insert(list, s) end
for _, s in list do
	local level = LevelSpec.compile(s)
	local loc = KitPlan.location(level, true)
	local base = KitPlan.plan(level, specs, { dressing = true, location = loc, dress = LevelDress[level.id], lighting = Config.Lighting })
	local p = DecorPlan.plan(level, specs, { location = loc, dressing = true, dress = LevelDress[level.id], base = base.items }, { KP = KitPlan, cfg = Config.Interior, lighting = Config.Lighting })
	local per = {}
	local tris = 0
	for _, it in p.items do
		local key = (it.band or 0) .. ":" .. (it.room or "?")
		per[key] = per[key] or {}
		if it.role ~= "frieze" then table.insert(per[key], (string.gsub(it.pieces[1], "Decor_", ""))) end
		tris += #it.pieces
	end
	print(level.id, p.theme, #p.items, "tris", tris)
	for k, r in p.rooms do
		print(string.format("   band %d %s z %.1f..%.1f: %s", k, r.kind, r.z0, r.z1, table.concat(per[k .. ":" .. r.kind] or {}, ", ")))
	end
	if per["0:front"] then print("   (brass) ", #per["0:front"]) end
end
