-- L1: Heist/BackdropPlan, the world around the lot (PLAN_STEAM_PLUS §4.1 W4, roblox_quality §2). The backdrop
-- never reaches into the playable lot, fits its budget (about 30 draw calls and 25k triangles for the whole
-- backdrop, measured on the plan with the ring meshes' real triangle counts), drops the far ring on low tiers,
-- and its snow stays inside MASTERPLAN §6.8's particle budget (slower and sparser under reduced motion, never off).

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
local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json"))

local ringTris: { [string]: number } = {}
for _, r in B.RINGS do
	for _, piece in { r.piece, r.windows } do
		local e = manifest.parts[piece]
		ringTris[piece] = if e then e.tris else 0
	end
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

local function overlapXZ(a: any, b: any, tol: number): boolean
	return a.minX < b.maxX - tol and a.maxX > b.minX + tol and a.minZ < b.maxZ - tol and a.maxZ > b.minZ + tol
end

return function(test)
	test("ring pieces are kit pieces (published to the client by server Heist/BackdropKit)", function()
		local parts = (KitData :: any).parts
		for _, r in B.RINGS do
			Assert.truthy(parts[r.piece], r.piece .. " in KitData")
			Assert.truthy(parts[r.windows], r.windows .. " in KitData")
			Assert.eq(parts[r.windows].material, "Neon", r.windows .. " is Neon (the lit windows)")
			Assert.eq(parts[r.piece].canCollide, false, r.piece .. " never collides")
			Assert.truthy(ringTris[r.piece] > 0, r.piece .. " has a triangle count in the manifest")
		end
	end)

	test("every site: nothing of the backdrop inside the lot, facades never overlap each other", function()
		for _, s in sites() do
			local plan = BackdropPlan.plan(s.site)
			local lot = s.site.bounds
			Assert.truthy(plan.facades >= 12, s.id .. ": a near ring of facades (" .. plan.facades .. ")")
			local bodies = {}
			for _, p in plan.parts do
				local b = box(p)
				if p.name == "Ground" then
					Assert.truthy(b.maxY <= s.site.floorY - 0.5, s.id .. ": the ground sits under the floor")
				elseif p.name == "Kerb" then
					Assert.truthy(b.maxY <= s.site.floorY + 1e-6, s.id .. ": the kerb never rises above the floor")
					Assert.falsy(overlapXZ(b, lot, 1e-3), s.id .. ": the kerb stays outside the lot")
				else
					Assert.falsy(overlapXZ(b, lot, 1e-3), s.id .. ": a " .. p.name .. " reaches into the lot")
					if p.name == "Facade" then
						table.insert(bodies, b)
					end
				end
			end
			for i = 1, #bodies do
				for j = i + 1, #bodies do
					Assert.falsy(overlapXZ(bodies[i], bodies[j], 1e-3), s.id .. ": two facades overlap")
				end
			end
			if s.level then
				-- the across-street row stays behind every camera that starts at a spawn (classic follow 16 studs)
				for _, p in plan.parts do
					if p.name == "Facade" then
						local b = box(p)
						for _, sp in s.level.spawns do
							local dx = math.max(b.minX - sp.x, 0, sp.x - b.maxX)
							local dz = math.max(b.minZ - sp.z, 0, sp.z - b.maxZ)
							Assert.truthy(dx * dx + dz * dz >= 18 * 18, s.id .. ": a facade within 18 studs of a spawn")
						end
					end
				end
			end
		end
	end)

	test("budget: about 30 draw calls and 25k triangles; low tiers drop the far ring", function()
		for _, s in sites() do
			local plan = BackdropPlan.plan(s.site)
			local draws, tris, parts = BackdropPlan.budget(plan, 1, ringTris)
			Assert.le(draws, 30, s.id .. ": draw calls at tier 1")
			Assert.le(tris, 25000, s.id .. ": triangles at tier 1")
			Assert.le(parts, 200, s.id .. ": backdrop instances")
			local d3, t3 = BackdropPlan.budget(plan, B.FAR_RING_OFF_TIER, ringTris)
			Assert.truthy(d3 < draws and t3 < tris, s.id .. ": the far ring goes at tier " .. B.FAR_RING_OFF_TIER)
		end
		local plan = BackdropPlan.plan(BackdropPlan.levelSite(LevelSpec.compile(Catalog[1])))
		local draws, tris, parts = BackdropPlan.budget(plan, 1, ringTris)
		print(string.format("    L1 backdrop: %d draw calls, %d triangles, %d instances (tier 1)", draws, tris, parts))
	end)

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
