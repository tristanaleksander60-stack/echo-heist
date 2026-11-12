--!strict
-- Dumps what the server builds for each launch level (and, with "daily", each daily vault) as JSON, for
-- tools/blender/level_shots.py (the level readability audit, docs/audit/LEVELS.md). Read-only: it compiles the
-- level data with Sim/LevelSpec and runs the same pure Heist/KitPlan the server runs (KitDresser), with the
-- kit specs from Kit/KitData, so the Blender reconstruction places every kit piece where the game does.
-- Also: the greybox cables (LevelBuilder.deviceCenters + the L-shaped cable), Gus's pose at t = 0
-- (Sim/Guards.patrol) and which greybox solids the kit covers (those turn into invisible colliders).
--   lune run tools/blender/level_plan.luau [xmas|plain] [daily] > level_plan.json

local process = require("@lune/process")
local serde = require("@lune/serde")

local Catalog = require("../../src/shared/Levels/Catalog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local Guards = require("../../src/shared/Sim/Guards")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")

type Box = { minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number }

local specs: { [string]: any } = (KitData :: any).parts
local dressing = table.find(process.args, "plain") == nil
local withDaily = table.find(process.args, "daily") ~= nil

local function box(b: Box): { number }
	return { b.minX, b.minY, b.minZ, b.maxX, b.maxY, b.maxZ }
end

local function centre(b: Box): (number, number)
	return (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
end

local function sourcesOf(list: { any }): { number }
	local out = {}
	for _, src in list do
		if src.kind == "plate" then
			table.insert(out, src.index)
		end
	end
	return out
end

-- LevelBuilder.deviceCenters + cable(): one L-shaped floor cable per (plate, device) pair.
local function cables(level: any): { any }
	local out = {}
	for i, p in level.plates do
		local px, pz = centre(p.box)
		local targets = {}
		for _, d in level.doors do
			for _, src in d.openBy do
				if src.kind == "plate" and src.index == i then
					local dx, dz = centre(d.box)
					table.insert(targets, { dx, dz })
				end
			end
		end
		for _, l in level.lasers do
			for _, src in l.offBy do
				if src.kind == "plate" and src.index == i then
					local _, lz = centre(l.box)
					table.insert(targets, { l.box.maxX + 0.5, lz })
				end
			end
		end
		for _, t in targets do
			-- corner = (to.X, from.Z): first along X at the plate's Z, then along Z
			table.insert(out, { plate = i, legs = { { px, pz, t[1], pz }, { t[1], pz, t[1], t[2] } } })
		end
	end
	return out
end

local function dump(spec: any): any
	local level = LevelSpec.compile(spec)
	local location = spec.location or "CornerShop"
	if dressing and level.kind == "party" and location == "CornerShop" then
		location = "ToyShop" -- LevelBuilder: Clone Party is the Toy Shop in Christmas dressing
	end
	local plan = KitPlan.plan(level, specs, { dressing = dressing, location = location })

	local kit = {}
	for _, item in plan.items do
		local pieces = {}
		for _, name in item.pieces do
			local c, size = KitPlan.partFrame(specs[name], item.pivot, item.scale)
			table.insert(pieces, { name = name, model = specs[name].model, c = c, size = size })
		end
		table.insert(kit, {
			role = item.role,
			mode = item.mode,
			layer = item.layer,
			ref = item.ref,
			index = item.index,
			pivot = { item.pivot.x, item.pivot.y, item.pivot.z, item.pivot.yaw },
			scale = item.scale,
			pieces = pieces,
		})
	end
	local covered = {}
	for solidIndex in plan.solids do
		table.insert(covered, solidIndex)
	end
	table.sort(covered)

	local solids = {}
	for i, s in spec.solids or {} do
		solids[i] = { box = box(s.box), sight = s.sight ~= false, id = s.id }
	end
	local plates = {}
	for i, p in level.plates do
		plates[i] = { id = p.id, box = box(p.box) }
	end
	local doors = {}
	for i, d in level.doors do
		doors[i] = {
			id = d.id,
			box = box(d.box),
			openBy = sourcesOf(d.openBy),
			need = d.need,
			alarmLock = d.alarmLock,
		}
	end
	local lasers = {}
	for i, l in level.lasers do
		lasers[i] = { id = l.id, box = box(l.box), offBy = sourcesOf(l.offBy) }
	end
	local hides = {}
	for i, h in level.hides do
		hides[i] = { id = h.id, box = box(h.box) }
	end
	local loot = {}
	for i, it in level.loot do
		loot[i] = {
			id = it.id,
			x = it.x,
			y = it.y,
			z = it.z,
			kind = it.kind,
			value = it.value,
			top = it.top,
			heavy = it.heavy ~= nil,
		}
	end
	local switches = {}
	for i, s in level.switches do
		switches[i] = { id = s.id, x = s.x, y = s.y, z = s.z }
	end
	local guards = {}
	for i, g in level.guards do
		local x, z, yaw = Guards.patrol(g.route, 0)
		local route = {}
		for _, p in spec.guards[i].route do
			table.insert(route, { x = p.x, z = p.z, face = p.face, wait = p.wait })
		end
		guards[i] = { id = g.id, x = x, z = z, yaw = yaw, route = route, period = g.route.period }
	end
	local spawns = {}
	for i, s in level.spawns do
		spawns[i] = { x = s.x, y = s.y, z = s.z, yaw = s.yaw }
	end

	return {
		id = level.id,
		num = level.num,
		name = level.name,
		kind = level.kind,
		location = location,
		dressing = dressing,
		runSeconds = level.runSeconds,
		par = level.par,
		floorY = level.floorY,
		bounds = box(level.bounds),
		van = box(level.van),
		vanBox = if plan.vanBox then box(plan.vanBox) else nil,
		spawns = spawns,
		solids = solids,
		covered = covered,
		plates = plates,
		doors = doors,
		lasers = lasers,
		hides = hides,
		loot = loot,
		switches = switches,
		guards = guards,
		cables = cables(level),
		kit = kit,
		warnings = plan.warnings,
	}
end

local out = { dressing = dressing, levels = {} }
for _, spec in Catalog do
	table.insert(out.levels, dump(spec))
end
if withDaily then
	for _, spec in DailyVaults.designs do
		table.insert(out.levels, dump(spec))
	end
end
print(serde.encode("json", out, false))
