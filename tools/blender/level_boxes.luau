--!strict
-- Dumps the LevelSpec geometry of every launch level and daily vault as JSON, for the kit fit table that
-- tools/blender/kit_docs.py writes into docs/art/KIT_IMPORT.md (kit piece vs sim box, per level).
-- Read-only: it only requires the level data. Run from the repo root:
--   lune run tools/blender/level_boxes.luau > docs/art/level_boxes.json

local serde = require("@lune/serde")

local Catalog = require("../../src/shared/Levels/Catalog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")

type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }

local function box(b: Box?): { number }?
	if b == nil then
		return nil
	end
	return { b.minX, b.minY, b.minZ, b.maxX, b.maxY, b.maxZ }
end

local function items(list: { any }?): { any }
	local out = {}
	for i, item in list or {} do
		table.insert(out, {
			id = item.id or tostring(i),
			box = box(item.box),
			sight = item.sight,
		})
	end
	return out
end

local function loot(list: { any }?): { any }
	local out = {}
	for _, item in list or {} do
		table.insert(out, {
			id = item.id,
			kind = item.kind or "Cash",
			x = item.x,
			y = item.y,
			z = item.z,
			top = item.top == true,
			heavy = item.heavy ~= nil,
		})
	end
	return out
end

local function dump(spec: any): any
	return {
		id = spec.id,
		name = spec.name,
		location = spec.location,
		solids = items(spec.solids),
		plates = items(spec.plates),
		doors = items(spec.doors),
		lasers = items(spec.lasers),
		hides = items(spec.hides),
		switches = spec.switches or {},
		loot = loot(spec.loot),
	}
end

local out = { levels = {} }
for _, spec in Catalog do
	table.insert(out.levels, dump(spec))
end
for _, spec in DailyVaults.designs do
	table.insert(out.levels, dump(spec))
end
print(serde.encode("json", out, true))
