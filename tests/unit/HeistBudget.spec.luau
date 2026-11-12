-- L1: Heist/Budget, the performance budgets per runtime tier (Config.Perf, docs/PERF.md). The tiers only get
-- cheaper, tiers 2 and 3 carry roblox_quality §6.4's mid and low Android numbers, the worst particle moment fits
-- every tier, the light kinds a tier switches off bring every level's busiest view under its light budget, the
-- glow set keeps your own clones first, and recipe C "Soft Toybox" is the one in roblox_quality §1.4.

local BackdropPlan = require("../../src/shared/Heist/BackdropPlan")
local Budget = require("../../src/shared/Heist/Budget")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LevelDress = require("../../src/server/Heist/LevelDress")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Assert = require("./Assert")

local P = Config.Perf
local LIGHT = Config.Lighting
local S = Config.Backdrop.SNOW

local function levels(): { any }
	local out = {}
	for _, spec in Catalog do
		table.insert(out, LevelSpec.compile(spec))
	end
	for _, spec in DailyVaults.designs do
		table.insert(out, LevelSpec.compile(spec))
	end
	return out
end

-- The busiest view of a level at a tier: lamps within VIEW_RADIUS of one another that stay lit.
local function busiestView(lamps: { any }, tier: number): (number, number)
	local worstLit, worstShadowed = 0, 0
	for _, a in lamps do
		local lit, shadowed = 0, 0
		for _, b in lamps do
			local dx, dz = a.x - b.x, a.z - b.z
			if dx * dx + dz * dz <= LIGHT.VIEW_RADIUS * LIGHT.VIEW_RADIUS and Budget.lampOn(tier, b.kind) then
				lit += 1
				if LIGHT.LAMP[b.kind].shadows and tier < LIGHT.SHADOWS_OFF_TIER then
					shadowed += 1
				end
			end
		end
		worstLit = math.max(worstLit, lit)
		worstShadowed = math.max(worstShadowed, shadowed)
	end
	return worstLit, worstShadowed
end

return function(test)
	test("one budget per governor tier; every tier is no dearer than the one above", function()
		Assert.eq(#P.TIERS, #Config.Heist.PERF_TIERS, "a budget per PERF_TIERS entry")
		local keys = {
			"drawCalls",
			"tris",
			"lights",
			"shadowed",
			"liveParticles",
			"highlights",
			"cloneGlows",
			"pillDistance",
			"particleScale",
			"snowAlive",
		}
		for tier = 2, #P.TIERS do
			local up: any, t: any = Budget.forTier(tier - 1), Budget.forTier(tier)
			for _, k in keys do
				Assert.le(t[k], up[k], "tier " .. tier .. " " .. k)
			end
			Assert.truthy(#t.lightKindsOff >= #up.lightKindsOff, "tier " .. tier .. ": lamp kinds only go off")
			for _, kind in up.lightKindsOff do
				Assert.truthy(table.find(t.lightKindsOff, kind) ~= nil, "tier " .. tier .. " keeps " .. kind .. " off")
			end
		end
		Assert.eq(Budget.forTier(0), Budget.forTier(1), "below 1 clamps")
		Assert.eq(Budget.forTier(9), Budget.forTier(#P.TIERS), "above the last clamps")
	end)

	test("tiers 2 and 3 carry roblox_quality §6.4 (mid / low Android); tier 1 stays under MASTERPLAN §6.8", function()
		local mid, low, top = Budget.forTier(2), Budget.forTier(3), Budget.forTier(1)
		Assert.eq(mid.drawCalls, 350, "mid draw calls")
		Assert.eq(mid.tris, 300000, "mid triangles")
		Assert.eq(mid.liveParticles, 360, "mid live particles")
		Assert.eq(mid.shadowed, 2, "mid shadowed lights")
		Assert.eq(low.drawCalls, 250, "low draw calls")
		Assert.eq(low.tris, 150000, "low triangles")
		Assert.eq(low.liveParticles, 150, "low live particles")
		Assert.eq(low.shadowed, 0, "low: no shadowed lights")
		Assert.le(low.lights, 8, "low: recipe C's 6-8 local lights")
		Assert.le(top.drawCalls, 600, "§6.8 draw call ceiling")
		Assert.le(top.tris, 600000, "§6.8 triangle ceiling")
		Assert.le(top.liveParticles, 360, "§6.8 live particles (touch)")
		Assert.le(top.shadowed, 4, "§6.8 shadow-casting lights per view")
		Assert.truthy(low.highlights >= 5, "low: 4 clone groups + your rim")
		Assert.truthy(Budget.othersHighlight(3) and not Budget.othersHighlight(4), "others' Highlights go at tier 4")
		Assert.truthy(low.cloneGlows < top.cloneGlows, "low phones draw fewer floor glows")
		Assert.eq(top.cloneGlows, Config.Sim.CREW_CLONE_BUDGET, "tier 1 draws every clone's glow")
	end)

	test("the worst particle moment fits every tier; bursts keep a readable minimum", function()
		for tier = 1, #P.TIERS do
			local n = Budget.worstParticles(tier)
			Assert.le(n, Budget.forTier(tier).liveParticles, "tier " .. tier .. " worst moment (" .. n .. ")")
		end
		Assert.eq(Budget.burst(1, Config.Clone.RIBBON_COUNT), Config.Clone.RIBBON_COUNT, "tier 1: the full burst")
		Assert.eq(Budget.burst(3, 24), 12, "tier 3: half")
		Assert.eq(Budget.burst(4, 3), P.BURST_MIN, "never below BURST_MIN")
		Assert.eq(Budget.burst(4, 1), 1, "a single particle stays single")
		Assert.eq(Budget.particleScale(3), 0.5, "HeistClient's old tier >= 3 scale")
	end)

	test("snow: rate x lifetime stays under each tier's snowAlive, reduced motion too; never off outdoors", function()
		for tier = 1, #P.TIERS do
			for _, reduced in { false, true } do
				local want = BackdropPlan.snowRate(tier, reduced, false)
				local lifeMax = if reduced then S.lifetime[2] / S.reducedSpeed else S.lifetime[2]
				local rate, life = Budget.snow(tier, want, lifeMax)
				Assert.truthy(rate > 0, "tier " .. tier .. ": snow never off")
				Assert.le(rate, want, "never more than the backdrop asks")
				Assert.le(rate * life, Budget.forTier(tier).snowAlive + 1e-6, "tier " .. tier .. " alive")
			end
		end
		Assert.eq(Budget.forTier(1).snowAlive, S.maxAlive, "tier 1 is the backdrop's own cap")
		local r0, l0 = Budget.snow(1, 0, 6)
		Assert.eq(r0, 0, "indoors stays at 0")
		Assert.eq(l0, 6, "lifetime untouched indoors")
	end)

	test("lights: the kinds a tier switches off bring every level's busiest view under its budget", function()
		for _, level in levels() do
			local lamps = KitPlan.lamps(level, LevelDress[level.id], LIGHT)
			for tier = 1, #P.TIERS do
				local lit, shadowed = busiestView(lamps, tier)
				local t = Budget.forTier(tier)
				Assert.le(lit, t.lights, level.id .. " tier " .. tier .. ": lights in one view")
				Assert.le(shadowed, t.shadowed, level.id .. " tier " .. tier .. ": shadowed lights")
			end
			-- the signals never go dark: plate and hero lamps stay at every tier
			for tier = 1, #P.TIERS do
				Assert.truthy(Budget.lampOn(tier, "plate") and Budget.lampOn(tier, "hero"), "signals stay lit")
			end
		end
		Assert.truthy(Budget.lampOn(4, nil), "a light with no lamp kind (garage, halo) is never switched off")
	end)

	test("recipe C 'Soft Toybox' from tier 3 (roblox_quality §1.4); ranges clamped; Bloom off at tier 4", function()
		Assert.truthy(not Budget.softToybox(2) and Budget.softToybox(3) and Budget.softToybox(4), "tier 3+")
		local L = P.SOFT_TOYBOX.Lighting
		Assert.eq(L.LightingStyle, "Soft", "Soft")
		Assert.eq(L.PrioritizeLightingQuality, true, "Prioritize (shadow maps, not voxels)")
		Assert.eq(L.Brightness, 1.6, "Brightness")
		Assert.eq(L.EnvironmentSpecularScale, 0, "no specular")
		Assert.truthy(L.Ambient[1] <= L.OutdoorAmbient[1] and L.Ambient[3] <= L.OutdoorAmbient[3], "Ambient <= Outdoor")
		Assert.eq(P.SOFT_TOYBOX.Bloom.Intensity, 0.9, "Bloom 0.9")
		Assert.eq(P.SOFT_TOYBOX.ColorCorrection.Contrast, 0.15, "CC contrast")
		Assert.eq(Budget.lightRange(1, 36), 36, "tier 1 keeps the hero's range")
		Assert.eq(Budget.lightRange(3, 36), 24, "tier 3 clamps to Range 24")
		Assert.eq(Budget.lightRange(3, 18), 18, "a short range stays")
		Assert.truthy(Budget.bloomOn(3) and not Budget.bloomOn(4), "Bloom off only at tier 4")
		Assert.truthy(LIGHT.SHADOWS_OFF_TIER <= P.SOFT_TOYBOX_TIER, "hero shadows are off once recipe C is on")
	end)

	test("glow set: your own clones first, then the nearest, up to the tier's cap", function()
		local c = {}
		for i = 1, 12 do
			table.insert(c, { own = i > 9, dist = i * 3 })
		end
		local all = Budget.glowSet(1, c)
		for i = 1, 12 do
			Assert.truthy(all[i], "tier 1 draws glow " .. i)
		end
		local low = Budget.glowSet(3, c)
		local n = 0
		for i = 1, 12 do
			n += if low[i] then 1 else 0
		end
		Assert.eq(n, Budget.forTier(3).cloneGlows, "tier 3 cap")
		Assert.truthy(low[10] and low[11] and low[12], "your own three, though they are the farthest")
		Assert.truthy(low[1] and low[2] and low[3] and not low[9], "then the nearest")
		local tiny = Budget.glowSet(4, c)
		Assert.truthy(tiny[10] and tiny[11] and tiny[12] and not tiny[1], "tier 4: only yours")
		Assert.eq(#Budget.glowSet(3, {}), 0, "no clones, no glows")
	end)

	test("over(): lists what a measured view exceeds", function()
		Assert.eq(#Budget.over(3, { drawCalls = 200, lights = 6 }), 0, "within budget")
		local o = Budget.over(3, { drawCalls = 300, tris = 100000, highlights = 9 })
		Assert.eq(#o, 2, "two lines")
		Assert.truthy(string.find(o[1], "drawCalls", 1, true) ~= nil, "draw calls named")
	end)
end
