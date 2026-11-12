--!strict
-- Dumps what the server builds for each launch level (and, with "daily", each daily vault) as JSON, for
-- tools/blender/level_shots.py (the level readability audit, docs/audit/LEVELS.md). Read-only: it compiles the
-- level data with Sim/LevelSpec and runs the same pure Heist/KitPlan the server runs (KitDresser), with the
-- kit specs from Kit/KitData, so the Blender reconstruction places every kit piece where the game does.
-- Also: the greybox cables (KitPlan.cables, as LevelBuilder lays them), the lamps (KitPlan.lamps with
-- Heist/LevelDress and Config.Lighting: lights, pools, Lamp_Ceiling), the plate / device letters, Gus's pose at
-- t = 0 (Sim/Guards.patrol) and which greybox solids the kit covers (those turn into invisible colliders).
--   lune run tools/blender/level_plan.luau [xmas|plain] [daily] > level_plan.json

local process = require("@lune/process")
local serde = require("@lune/serde")

local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local LevelDress = require("../../src/server/Heist/LevelDress")
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

-- KitPlan.cables (what LevelBuilder lays): one polyline per (plate, device) pair, as legs.
local function cables(level: any): { any }
	local out = {}
	for _, cb in KitPlan.cables(level, Config.Lighting) do
		local legs = {}
		for k = 1, #cb.points - 1 do
			local a, b = cb.points[k], cb.points[k + 1]
			table.insert(legs, { a[1], a[2], b[1], b[2] })
		end
		table.insert(out, { plate = cb.plate, legs = legs })
	end
	return out
end

local function lamps(level: any, location: string): { any }
	local L = Config.Lighting
	local out = {}
	local list = KitPlan.lamps(level, LevelDress[level.id], L)
	local looks = KitPlan.lampLooks(list, location, L)
	for k, l in list do
		local spec = L.LAMP[l.kind]
		table.insert(out, {
			x = l.x,
			z = l.z,
			kind = l.kind,
			range = spec.range,
			brightness = spec.brightness,
			angle = spec.angle,
			color = looks[k].color,
			poolColor = looks[k].pool,
			shadows = spec.shadows == true,
			pool = if l.kind == "hero" then L.POOL.heroDiameter else L.POOL.diameter,
		})
	end
	return out
end

local function dump(spec: any): any
	local level = LevelSpec.compile(spec)
	local location = KitPlan.location(level, dressing) -- Clone Party is the Toy Shop in Christmas dressing
	local plan = KitPlan.plan(level, specs, {
		dressing = dressing,
		location = location,
		dress = LevelDress[level.id],
		lighting = Config.Lighting,
	})

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
		plates[i] = { id = p.id, box = box(p.box), letter = KitPlan.letter(level, i) }
	end
	local doors = {}
	for i, d in level.doors do
		doors[i] = {
			id = d.id,
			box = box(d.box),
			openBy = sourcesOf(d.openBy),
			need = d.need,
			alarmLock = d.alarmLock,
			letters = KitPlan.deviceLetters(level, d.openBy),
		}
	end
	local lasers = {}
	for i, l in level.lasers do
		lasers[i] = {
			id = l.id,
			box = box(l.box),
			offBy = sourcesOf(l.offBy),
			letters = KitPlan.deviceLetters(level, l.offBy),
		}
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
		lamps = lamps(level, location),
		lighting = Config.Lighting,
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
