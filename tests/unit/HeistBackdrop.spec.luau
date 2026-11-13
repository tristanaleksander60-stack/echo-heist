-- L1: Heist/BackdropPlan + Heist/TownPlan, the world around the lot (PLAN_STEAM_PLUS §4.1 W4, roblox_quality §2;
-- WORLD 2.0, docs/audit/LEVELS.md §10). The town never reaches into the playable lot (only the client's snow over
-- the lot's outdoor floor, under the kit floor tiles, and the invisible lot fence on its edge), no two buildings
-- overlap, no building stands within a spawn camera's reach, every map has its own street, it costs no Light, it
-- fits its budget at tier 1 and gets cheaper on low tiers, and its snow stays inside MASTERPLAN §6.8's particle
-- budget (slower and sparser under reduced motion, never off).

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local BackdropPlan = require("../../src/shared/Heist/BackdropPlan")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local KitData = require("../../src/server/Kit/KitData")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Assert = require("./Assert")

local B = Config.Backdrop
local T = B.TOWN
local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json"))

local kitTris: { [string]: number } = {}
for name, e in manifest.parts do
	kitTris[name] = e.tris
end

local function sites(): { any }
	local out = {}
	for _, spec in Catalog do
		local level = LevelSpec.compile(spec)
		table.insert(out, { id = level.id, site = BackdropPlan.levelSite(level), level = level })
	end
	for _, spec in DailyVaults.designs do
		local level = LevelSpec.compile(spec)
		table.insert(out, { id = level.id, site = BackdropPlan.levelSite(level), level = level })
	end
	table.insert(out, { id = "garage", site = BackdropPlan.garageSite() })
	return out
end

local function box(p: any): any
	return {
		minX = p.pos[1] - p.size[1] / 2,
		maxX = p.pos[1] + p.size[1] / 2,
		minY = p.pos[2] - p.size[2] / 2,
		maxY = p.pos[2] + p.size[2] / 2,
		minZ = p.pos[3] - p.size[3] / 2,
		maxZ = p.pos[3] + p.size[3] / 2,
	}
end

-- A kit placement's footprint (yaw a multiple of 90, as the town places them).
local function kitBox(k: any): any
	local e = manifest.parts[k.piece]
	local lo, hi = e.boundsMin, e.boundsMax
	local s = { 1, 1, 1 }
	if k.size then
		s = { k.size[1] / e.size[1], k.size[2] / e.size[2], k.size[3] / e.size[3] }
	elseif k.scale then
		s = { k.scale, k.scale, k.scale }
	end
	local a = math.rad(k.yaw)
	local c, sn = math.cos(a), math.sin(a)
	local b = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, x in { lo[1] * s[1], hi[1] * s[1] } do
		for _, z in { lo[3] * s[3], hi[3] * s[3] } do
			local wx, wz = k.pos[1] + x * c + z * sn, k.pos[3] - x * sn + z * c
			b.minX, b.maxX = math.min(b.minX, wx), math.max(b.maxX, wx)
			b.minZ, b.maxZ = math.min(b.minZ, wz), math.max(b.maxZ, wz)
		end
	end
	return b
end

local function overlapXZ(a: any, b: any, tol: number): boolean
	return a.minX < b.maxX - tol and a.maxX > b.minX + tol and a.minZ < b.maxZ - tol and a.maxZ > b.minZ + tol
end

local function inside(a: any, b: any, tol: number): boolean
	return a.minX >= b.minX - tol and a.maxX <= b.maxX + tol and a.minZ >= b.minZ - tol and a.maxZ <= b.maxZ + tol
end

return function(test)
	test("kit pieces are kit pieces (published to the client by server Heist/BackdropKit), never colliders", function()
		local parts = (KitData :: any).parts
		for _, r in B.RINGS do
			Assert.truthy(parts[r.piece], r.piece .. " in KitData")
			Assert.truthy(parts[r.windows], r.windows .. " in KitData")
			Assert.eq(parts[r.windows].material, "Neon", r.windows .. " is Neon (the lit windows)")
			Assert.truthy(kitTris[r.piece] > 0, r.piece .. " has a triangle count in the manifest")
		end
		for _, name in B.KIT_PIECES do
			Assert.truthy(parts[name], name .. " in KitData (uploaded)")
			Assert.eq(parts[name].canCollide, false, name .. " never collides")
		end
	end)

	test("every site: the town stays out of the lot, buildings never overlap, no building by a spawn", function()
		for _, s in sites() do
			local plan = BackdropPlan.plan(s.site)
			local lot = s.site.bounds
			Assert.truthy(plan.facades >= 14, s.id .. ": a neighbourhood of buildings (" .. plan.facades .. ")")
			local bodies = {}
			for _, p in plan.parts do
				local b = box(p)
				if p.name == "Ground" then
					Assert.truthy(b.maxY <= s.site.floorY - 0.2, s.id .. ": the snowfield sits under the floor")
				elseif p.layer == "lot" then
					Assert.truthy(inside(b, lot, 1e-3), s.id .. ": the lot snow stays inside the lot")
					Assert.truthy(b.maxY <= s.site.floorY + 0.04, s.id .. ": the lot snow sits under the kit tiles")
				elseif p.layer == "fence" then
					Assert.truthy(p.collide == true, s.id .. ": the fence collides")
					Assert.falsy(overlapXZ(b, lot, 1e-3), s.id .. ": the fence is outside the lot")
				else
					Assert.falsy(overlapXZ(b, lot, 1e-3), s.id .. ": a town " .. p.name .. " reaches into the lot")
					Assert.falsy(p.collide == true, s.id .. ": the town never collides")
					if p.name == "Body" then
						table.insert(bodies, b)
					end
				end
			end
			for _, k in plan.kit do
				Assert.truthy(manifest.parts[k.piece] ~= nil, s.id .. ": " .. k.piece .. " is a kit piece")
				Assert.falsy(overlapXZ(kitBox(k), lot, 1e-3), s.id .. ": a town " .. k.piece .. " reaches into the lot")
			end
			for _, pl in plan.pools do
				local r = pl.size / 2
				local b = { minX = pl.pos[1] - r, maxX = pl.pos[1] + r, minZ = pl.pos[3] - r, maxZ = pl.pos[3] + r }
				Assert.falsy(
					overlapXZ({ minX = pl.pos[1], maxX = pl.pos[1], minZ = pl.pos[3], maxZ = pl.pos[3] }, lot, -1e-3),
					s.id .. ": a pool's lamp stands in the lot"
				)
				Assert.truthy(b.maxX > b.minX, s.id .. ": a pool has a size")
			end
			for i = 1, #bodies do
				for j = i + 1, #bodies do
					Assert.falsy(overlapXZ(bodies[i], bodies[j], 1e-3), s.id .. ": two buildings overlap")
				end
			end
			if s.level then
				-- no building within a classic camera's reach of a spawn (follow cam 16 studs, plus a margin)
				for _, b in bodies do
					for _, sp in s.level.spawns do
						local dx = math.max(b.minX - sp.x, 0, sp.x - b.maxX)
						local dz = math.max(b.minZ - sp.z, 0, sp.z - b.maxZ)
						Assert.truthy(dx * dx + dz * dz >= 18 * 18, s.id .. ": a building within 18 studs of a spawn")
					end
				end
			end
		end
	end)

	test("every map has its own street: themes, and the levels sharing one differ", function()
		local seen: { [string]: string } = {}
		local themes: { [string]: boolean } = {}
		for _, s in sites() do
			local plan = BackdropPlan.plan(s.site)
			themes[s.site.theme] = true
			local key = {}
			for _, p in plan.parts do
				if p.name == "Body" then
					table.insert(key, string.format("%.1f:%.1f:%d", p.pos[1], p.size[2], p.color[1]))
				end
			end
			for _, k in plan.kit do
				if k.piece == "Car_Parked" or k.piece == "Xmas_Tree" or k.piece == "Snowman" then
					table.insert(key, string.format("%s@%.1f", k.piece, k.pos[1]))
				end
			end
			local sig = table.concat(key, "|")
			if seen[sig] and s.site.kind == "heist" then
				-- the daily vaults share their level's seed space; the six launch levels must all differ
				Assert.truthy(s.level and s.level.kind == "daily", s.id .. ": same street as " .. seen[sig])
			end
			seen[sig] = seen[sig] or s.id
		end
		for _, name in { "CornerShop", "ToyShop", "Bank", "Garage" } do
			Assert.truthy(themes[name], name .. " street is used")
		end
		local six = {}
		for _, spec in Catalog do
			local level = LevelSpec.compile(spec)
			table.insert(six, BackdropPlan.levelSite(level).theme)
		end
		Assert.truthy(table.find(six, "ToyShop") ~= nil and table.find(six, "Bank") ~= nil, "L5 and L6 own streets")
	end)

	test(
		"the Bank's plaza has its big tree; the Toy Shop street its light strings; nothing in the town is a Light",
		function()
			for _, s in sites() do
				local plan = BackdropPlan.plan(s.site, true)
				local trees, strings, maxScale = 0, 0, 0
				for _, k in plan.kit do
					if k.piece == "Xmas_Tree" then
						trees += 1
						maxScale = math.max(maxScale, k.scale or 1)
					elseif k.piece == "Xmas_Lights_8" then
						strings += 1
					end
					Assert.falsy(string.find(k.piece, "Light$") ~= nil, s.id .. ": a Light in the town")
				end
				Assert.truthy(trees >= 1, s.id .. ": a Christmas tree")
				if s.site.theme == "Bank" then
					Assert.truthy(maxScale >= 4, s.id .. ": the plaza's big tree")
				elseif s.site.theme == "ToyShop" then
					Assert.truthy(strings >= 6, s.id .. ": fairy-light strings on the high street")
				end
				Assert.eq(T.BUDGET.lights, 0, "the town adds no Light objects")
			end
		end
	)

	test(
		"budget: within Config.Backdrop.TOWN.BUDGET at tier 1; low tiers drop the far ring, props and pools",
		function()
			for _, s in sites() do
				local plan = BackdropPlan.plan(s.site, true)
				local draws, tris, parts = BackdropPlan.budget(plan, 1, kitTris)
				Assert.le(draws, T.BUDGET.draws, s.id .. ": draw calls at tier 1")
				Assert.le(tris, T.BUDGET.tris, s.id .. ": triangles at tier 1")
				Assert.le(parts, T.BUDGET.instances, s.id .. ": backdrop instances")
				local d3, t3 = BackdropPlan.budget(plan, T.PROPS_OFF_TIER, kitTris)
				Assert.truthy(
					d3 < draws and t3 < tris * 0.5,
					s.id .. ": tier " .. T.PROPS_OFF_TIER .. " costs far less"
				)
				Assert.truthy(BackdropPlan.layerOn("building", 4) and BackdropPlan.layerOn("windows", 4), "never dark")
			end
			for _, id in { 1, 5, 6 } do
				local level = LevelSpec.compile(Catalog[id])
				local plan = BackdropPlan.plan(BackdropPlan.levelSite(level), true)
				local draws, tris, parts = BackdropPlan.budget(plan, 1, kitTris)
				print(
					string.format(
						"    %s backdrop: %d draw calls, %d triangles, %d instances, %d buildings (tier 1)",
						level.id,
						draws,
						tris,
						parts,
						plan.facades
					)
				)
			end
		end
	)

	test("snow: inside the particle budget, sparser and slower under reduced motion, off indoors", function()
		local S = B.SNOW
		Assert.le(S.rate * S.lifetime[2], S.maxAlive, "rate x lifetime <= maxAlive")
		Assert.le(S.maxAlive, 360, "MASTERPLAN §6.8: <= 360 live particles on touch")
		Assert.le(BackdropPlan.snowRate(S.LOW_TIER, false, false) * S.lifetime[2], 120, "low tier: <= 120 alive")
		local reduced = BackdropPlan.snowRate(1, true, false)
		Assert.truthy(reduced > 0 and reduced < S.rate, "reduced motion: sparser, never off")
		Assert.truthy(S.reducedSpeed > 0 and S.reducedSpeed < 1, "reduced motion: slower, never still")
		Assert.eq(BackdropPlan.snowRate(1, false, true), S.rate * S.interiorScale, "indoors: the interior scale")
	end)

	test("sites: the footprint is the building, the spawn is outside it; the sky turns to the first view", function()
		for _, s in sites() do
			if s.level then
				local fp = s.site.footprint
				Assert.truthy(fp ~= nil, s.id .. ": a building footprint")
				for _, sp in s.level.spawns do
					Assert.falsy(BackdropPlan.inside(fp, sp.x, sp.z), s.id .. ": the spawn is on the street")
				end
				local g = s.level.loot[1]
				Assert.truthy(BackdropPlan.inside(fp, g.x, g.z), s.id .. ": the first loot is indoors")
				Assert.truthy(s.site.front ~= nil, s.id .. ": a street front")
			end
			local yaw = BackdropPlan.skyYaw(s.site)
			Assert.truthy(yaw >= 0 and yaw < 360, s.id .. ": a sky yaw in [0, 360)")
		end
		Assert.eq(BackdropPlan.skyYaw(BackdropPlan.garageSite()), 0, "garage faces -Z: the landmark as rendered")
	end)
end
