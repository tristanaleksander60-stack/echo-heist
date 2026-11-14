-- L1: the ink outlines (BLENDER LOOK track, docs/audit/BLENDER_LOOK.md): Shared/Heist/OutlinePlan picks the tier's
-- nearest units, hidden units take no slot, a hull mirrors its piece's visibility; the tiers only get cheaper and the
-- low tiers outline characters and loot only; KitLib's outline helpers (names, collision / RenderFidelity, size);
-- the kit data pairs every hull with a real piece of a character, hero or loot role, and the manifest says it is
-- quiet (no collision, no shadow, Neon).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Config = require("../../src/shared/Config")
local KitLib = require("../../src/shared/Kit/KitLib")
local OutlinePlan = require("../../src/shared/Heist/OutlinePlan")
local Assert = require("./Assert")

local O = Config.Outline

local function units(): { any }
	return {
		{ key = "you", class = "char", dist = 3, shown = false }, -- first person: hidden
		{ key = "gus", class = "char", dist = 12, shown = true },
		{ key = "mate", class = "char", dist = 8, shown = true },
		{ key = "clone1", class = "char", dist = 20, shown = true },
		{ key = "far", class = "char", dist = 200, shown = true },
		{ key = "cash", class = "loot", dist = 6, shown = true },
		{ key = "bar", class = "loot", dist = 9, shown = true },
		{ key = "door", class = "hero", dist = 10, shown = true },
	}
end

return function(test)
	test("outline plan: tier 1 draws every shown unit in range, never a hidden or far one", function()
		local p = OutlinePlan.pick(units(), 1)
		for _, k in { "gus", "mate", "clone1", "cash", "bar", "door" } do
			Assert.truthy(p[k], k .. " outlined at tier 1")
		end
		Assert.falsy(p.you, "a hidden unit (first person) takes no slot")
		Assert.falsy(p.far, "past the radius")
	end)

	test("outline plan: low tiers keep the nearest characters and loot, no hero props", function()
		local p2 = OutlinePlan.pick(units(), 2)
		Assert.truthy(p2.mate and p2.gus, "tier 2: the nearest characters")
		Assert.falsy(p2.door, "tier 2: no hero props")
		local p4 = OutlinePlan.pick(units(), 4)
		local chars, loot = 0, 0
		for _, u in units() do
			if p4[u.key] then
				if u.class == "char" then
					chars += 1
				elseif u.class == "loot" then
					loot += 1
				else
					error("tier 4 outlines only characters and loot, not " .. u.key)
				end
			end
		end
		Assert.eq(chars, O.TIERS[4].char, "tier 4 characters")
		Assert.eq(loot, O.TIERS[4].loot, "tier 4 loot")
		Assert.truthy(p4.mate, "the nearest character wins")
		Assert.truthy(p4.cash, "the nearest loot wins")
	end)

	test("outline plan: your own character (its rim Highlight) comes after everyone else's", function()
		local list = {
			{ key = "me", class = "char", dist = 4, shown = true, own = true },
			{ key = "gus", class = "char", dist = 20, shown = true },
		}
		local p4 = OutlinePlan.pick(list, 4)
		Assert.truthy(p4.gus, "Gus gets the one slot")
		Assert.falsy(p4.me, "you wait")
		Assert.truthy(OutlinePlan.pick({ list[1] }, 4).me, "alone, you keep your line")
	end)

	test("outline plan: every tier is no dearer than the one above it", function()
		for t = 2, #O.TIERS do
			for _, k in { "char", "loot", "hero", "radius" } do
				Assert.le(O.TIERS[t][k], O.TIERS[t - 1][k], string.format("tier %d %s", t, k))
			end
			Assert.truthy(O.TIERS[t].char >= 1 and O.TIERS[t].loot >= 1, "characters and loot keep a line")
		end
		Assert.eq(O.TIERS[2].hero, 0, "hero props are tier 1 only")
		local heavy = { char = 4000, loot = 400, hero = 1500 }
		for t = 2, #O.TIERS do
			Assert.le(OutlinePlan.worstTris(t, heavy), OutlinePlan.worstTris(t - 1, heavy), "worst tris by tier")
		end
		Assert.eq(OutlinePlan.worstTris(4, heavy), O.TIERS[4].char * 4000 + O.TIERS[4].loot * 400, "worst tris sum")
	end)

	test("outline plan: a hull mirrors its piece and hides when not picked", function()
		Assert.eq(OutlinePlan.visibility(false, 0, 0), 1, "not picked")
		Assert.eq(OutlinePlan.visibility(true, 0, 0), 0, "picked and shown")
		Assert.eq(OutlinePlan.visibility(true, 1, 0), 1, "piece invisible")
		Assert.eq(OutlinePlan.visibility(true, 0, 1), 1, "piece faded locally (first person, LOD, print)")
		Assert.near(OutlinePlan.visibility(true, 0.5, 0), 0.5, 1e-9, "a ghosted piece ghosts its line")
		Assert.near(OutlinePlan.visibility(true, 0.5, 0.5), 0.75, 1e-9, "both combine")
	end)

	test("outline kit helpers: names, quiet collision, Automatic fidelity, thickness scale", function()
		Assert.truthy(KitLib.isOutlineName("Rookie_Head_Outline"), "hull name")
		Assert.falsy(KitLib.isOutlineName("Rookie_Head"), "piece name")
		Assert.falsy(KitLib.isOutlineName("_Outline"), "bare suffix")
		local hull: any = { model = "Rookie_Outline", collision = "Box", outlineOf = "Rookie_Head" }
		Assert.eq(
			KitLib.gameCollision("Rookie_Head_Outline", hull, Config.Kit.COLLIDER_PIECES),
			"Default",
			"no rebuild"
		)
		Assert.eq(KitLib.renderFidelity("Rookie_Head_Outline", Config.Kit.PRECISE_PREFIXES), "Automatic", "fidelity")
		Assert.eq(
			KitLib.renderFidelity("Rookie_Head", Config.Kit.PRECISE_PREFIXES),
			"Precise",
			"the piece keeps Precise"
		)
		local s = KitLib.outlineSize({ 2, 1, 1 }, { 2.1, 1.1, 1.08 }, 0.5)
		Assert.near(s[1], 2.05, 1e-9, "x")
		Assert.near(s[3], 1.04, 1e-9, "z")
		local m = KitLib.outlineSize({ 2, 1, 1 }, { 2.1, 1.1, 1.08 }, 1)
		Assert.near(m[2], 1.1, 1e-9, "scale 1 = as built")
		Assert.truthy(O.COLOUR[1] + O.COLOUR[2] + O.COLOUR[3] < 120, "the ink is near black")
		Assert.truthy(O.THICKNESS_SCALE > 0, "a positive thickness scale")
	end)

	test("outline kit data: every hull belongs to a real piece and is quiet", function()
		local man = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json")).parts
		local n, classes = 0, {}
		for name, p in man do
			if p.outlineOf then
				n += 1
				local src = man[p.outlineOf]
				Assert.truthy(src ~= nil, name .. " has its piece " .. p.outlineOf)
				Assert.eq(name, p.outlineOf .. KitLib.OUTLINE_SUFFIX, name .. " is named after its piece")
				Assert.eq(p.material, "Neon", name .. " Neon")
				Assert.falsy(p.canCollide, name .. " no collision")
				Assert.falsy(p.castShadow, name .. " no shadow")
				Assert.falsy(p.tags, name .. " carries no gameplay tag")
				Assert.truthy(p.tris <= src.tris, name .. " is no heavier than its piece")
				for i = 1, 3 do
					Assert.truthy(p.size[i] >= src.size[i], name .. " wraps its piece on axis " .. i)
				end
				classes[p.outlineClass] = (classes[p.outlineClass] or 0) + 1
			end
		end
		Assert.truthy(n >= 60, "the characters, hero props and loot have hulls")
		Assert.truthy(classes.char and classes.loot and classes.hero, "every class present")
		for _, piece in { "Rookie_Head", "Gus_Head", "Hoardsworth_Head", "Van", "VaultDoor_Door", "CashBag" } do
			Assert.truthy(man[piece .. "_Outline"] ~= nil, piece .. " is outlined")
		end
		Assert.truthy(man.Rookie_Face_Idle_Outline == nil, "faces are not outlined")
		Assert.truthy(man.Rookie_Stripes_Torso_Outline == nil, "flush overlays ride the body's line")
	end)
end
