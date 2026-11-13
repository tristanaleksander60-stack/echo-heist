-- L1: Heist/Outfit (the Rookie's outfit slots, PLAN_FIRST_PERSON "CH"): defaults, unlocks (stars, trophies),
-- the Data.Equip rule (canWear), repair on load (Schema.sanitize), keys, the pieces an outfit adds, and that the
-- generated Heist/RookieData matches the kit manifest (assets/fbx/kit_manifest.json) and the R15 rig.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Config = require("../../src/shared/Config")
local Outfit = require("../../src/shared/Heist/Outfit")
local RookieData = require("../../src/shared/Heist/RookieData")
local Schema = require("../../src/shared/Data/Schema")
local Assert = require("./Assert")

local R = Config.Rookie

local R15 = {
	LowerTorso = { "Root", nil },
	UpperTorso = { "Waist", "LowerTorso" },
	Head = { "Neck", "UpperTorso" },
	LeftUpperArm = { "LeftShoulder", "UpperTorso" },
	LeftLowerArm = { "LeftElbow", "LeftUpperArm" },
	LeftHand = { "LeftWrist", "LeftLowerArm" },
	RightUpperArm = { "RightShoulder", "UpperTorso" },
	RightLowerArm = { "RightElbow", "RightUpperArm" },
	RightHand = { "RightWrist", "RightLowerArm" },
	LeftUpperLeg = { "LeftHip", "LowerTorso" },
	LeftLowerLeg = { "LeftKnee", "LeftUpperLeg" },
	LeftFoot = { "LeftAnkle", "LeftLowerLeg" },
	RightUpperLeg = { "RightHip", "LowerTorso" },
	RightLowerLeg = { "RightKnee", "RightUpperLeg" },
	RightFoot = { "RightAnkle", "RightLowerLeg" },
}

local function heistWith(stars: number, trophies: { string }?): any
	local h: any = Schema.defaultHeist()
	h.daily.stars = stars
	for _, id in trophies or {} do
		h.trophies[id] = 1700000000
	end
	return h
end

return function(test)
	test("the default outfit fills every slot with a free id of that slot", function()
		local d = Outfit.default()
		for _, slot in R.SLOTS do
			local def = R.OUTFIT[d[slot]]
			Assert.truthy(def ~= nil, "default " .. slot)
			Assert.eq(def.slot, slot, "default " .. slot .. " slot")
			Assert.truthy(def.free == true, "default " .. slot .. " is free")
		end
		Assert.truthy(Outfit.default() ~= Outfit.default(), "a new table every call")
		Assert.eq(Outfit.key(Schema.defaultHeist().outfit), Outfit.key(d), "a new profile wears the default")
	end)

	test("every slot has at least 2 variants and at least one free one; ids are unique against cosmetics", function()
		for _, slot in R.SLOTS do
			local ids = Outfit.idsFor(slot)
			Assert.truthy(#ids >= 2, slot .. " has >= 2 variants")
			Assert.truthy(R.OUTFIT[ids[1]].free == true, slot .. " lists a free id first")
			Assert.truthy(Config.Data.DEFAULT_EQUIPPED[slot] == nil, slot .. " is not a cosmetic slot (Data.Equip)")
		end
		for id in R.OUTFIT do
			Assert.truthy(Config.Data.Cosmetics[id] == nil, id .. " is not a cosmetic id (Data.Equip)")
		end
		Assert.truthy(#Outfit.idsFor("cap") >= 4 and #Outfit.idsFor("scarf") >= 4, "4 caps and 4 scarves")
	end)

	test("unlocks: free ids always, stars from medals + daily, trophies by id", function()
		local fresh = heistWith(0)
		Assert.truthy(Outfit.isUnlocked(fresh, "Cap_Flat"), "free cap")
		Assert.falsy(Outfit.isUnlocked(fresh, "Mask_Eye"), "1 star mask locked at 0")
		Assert.truthy(Outfit.isUnlocked(heistWith(1), "Mask_Eye"), "1 daily star unlocks the mask")
		local medals: any = heistWith(0)
		medals.levels.L1 = Schema.newLevelRecord()
		medals.levels.L1.medals = { Haul = true, Crew = true, Clean = true, Diamond = true }
		Assert.eq(Outfit.stars(medals), 3, "Diamond is not a star")
		Assert.truthy(Outfit.isUnlocked(medals, "Scarf_Bandana"), "3 medal stars unlock the bandana")
		Assert.falsy(Outfit.isUnlocked(medals, "Cap_Bobble"), "6-star cap still locked")
		Assert.falsy(Outfit.isUnlocked(fresh, "Cap_Trapper"), "trophy cap locked")
		Assert.truthy(Outfit.isUnlocked(heistWith(0, { "Trophy_NightClerk" }), "Cap_Trapper"), "trophy unlocks it")
		Assert.falsy(Outfit.isUnlocked(fresh, "Nope"), "unknown id")
		Assert.falsy(Outfit.isUnlocked(nil, "Mask_Eye"), "no profile: free only")
		Assert.truthy(Outfit.isUnlocked(nil, "Mask_None"), "no profile: free ok")
		for id, def in R.OUTFIT do
			if not def.free then
				local rule = def.unlock
				Assert.truthy(type(rule) == "table", id .. " has an unlock rule")
				if rule.trophy then
					Assert.truthy(Config.Data.Trophies[rule.trophy] ~= nil, id .. " unlock trophy exists")
				else
					Assert.truthy(type(rule.stars) == "number" and rule.stars > 0, id .. " unlock stars")
				end
			end
		end
	end)

	test("canWear is the Data.Equip rule: slot, id, slot match, unlock", function()
		local h = heistWith(0)
		Assert.eq(select(2, Outfit.canWear(h, "cap", "Cap_Beanie")), "Ok", "free cap")
		Assert.eq(select(2, Outfit.canWear(h, "hat", "Cap_Beanie")), "BadSlot", "unknown slot")
		Assert.eq(select(2, Outfit.canWear(h, "cap", "Cap_Nope")), "UnknownItem", "unknown id")
		Assert.eq(select(2, Outfit.canWear(h, "scarf", "Cap_Beanie")), "WrongSlot", "cap in the scarf slot")
		Assert.eq(select(2, Outfit.canWear(h, "cap", "Cap_Bobble")), "Locked", "locked cap")
		Assert.eq(select(2, Outfit.canWear(heistWith(6), "cap", "Cap_Bobble")), "Ok", "6 stars")
		Assert.eq(select(2, Outfit.canWear(h, 5, true)), "BadSlot", "junk types")
		Assert.eq(select(2, Outfit.canWear(h, "cap", { "Cap_Flat" })), "UnknownItem", "a table id")
	end)

	test("repair on load: junk, unknown slots, wrong-slot and locked ids fall back to the default", function()
		local h: any = heistWith(0)
		h.outfit = { cap = "Cap_Bobble", scarf = "Cap_Flat", sweater = 7, gloves = "Gloves_Knit", hat = "x" }
		local repairs = Schema.sanitize(h)
		Assert.eq(h.outfit.cap, R.DEFAULT_OUTFIT.cap, "locked cap repaired")
		Assert.eq(h.outfit.scarf, R.DEFAULT_OUTFIT.scarf, "wrong-slot id repaired")
		Assert.eq(h.outfit.sweater, R.DEFAULT_OUTFIT.sweater, "junk repaired")
		Assert.eq(h.outfit.gloves, "Gloves_Knit", "valid kept")
		Assert.eq(h.outfit.mask, R.DEFAULT_OUTFIT.mask, "missing slot filled")
		Assert.truthy(h.outfit.hat == nil, "unknown slot removed")
		Assert.truthy(table.find(repairs, "outfit.cap") ~= nil, "repair reported")
		local g: any = heistWith(0)
		g.outfit = "nope"
		Schema.sanitize(g)
		Assert.eq(Outfit.key(g.outfit), Outfit.key(Outfit.default()), "a non-table outfit becomes the default")
		local ok: any = heistWith(9, { "Trophy_NightClerk" })
		ok.outfit = { cap = "Cap_Trapper", scarf = "Scarf_Chunky", sweater = "Sweater_Block", gloves = "Gloves_Knit" }
		ok.outfit.mask = "Mask_Eye"
		local before = Outfit.key(ok.outfit)
		local rep = Schema.sanitize(ok)
		Assert.eq(Outfit.key(ok.outfit), before, "an unlocked outfit survives")
		for _, r in rep do
			Assert.truthy(string.sub(r, 1, 7) ~= "outfit.", "no outfit repair: " .. r)
		end
		-- the profile still round-trips as JSON (DataStore)
		local back = serde.decode("json", serde.encode("json", ok))
		Assert.eq(back.outfit.cap, "Cap_Trapper", "JSON round trip")
	end)

	test("keys round-trip; clean never trusts its input", function()
		local o = { cap = "Cap_Beanie", scarf = "Scarf_Knot", sweater = "Sweater_Block", gloves = "Gloves_Leather" }
		o.mask = "Mask_Eye"
		Assert.eq(Outfit.key(Outfit.fromKey(Outfit.key(o))), Outfit.key(o), "round trip")
		Assert.eq(Outfit.key(Outfit.fromKey(nil)), Outfit.key(Outfit.default()), "nil key")
		Assert.eq(Outfit.key(Outfit.fromKey("a|b")), Outfit.key(Outfit.default()), "junk key")
		Assert.eq(Outfit.clean({ cap = "Scarf_Long" }).cap, R.DEFAULT_OUTFIT.cap, "wrong slot cleaned")
		Assert.eq(Outfit.gloveHex(o), R.GLOVES.Gloves_Leather, "glove colour")
	end)

	test("an outfit's pieces: one cap and one scarf, 3 sweater pieces, 2 cuffs, the mask only when worn", function()
		local d = Outfit.pieces(Outfit.default())
		Assert.eq(#d, 1 + 1 + 3 + 2, "default pieces (no mask)")
		local masked = Outfit.default()
		masked.mask = "Mask_Eye"
		local m = Outfit.pieces(masked)
		Assert.eq(#m, #d + 1, "the mask adds one piece")
		Assert.truthy(table.find(m, "Rookie_Mask_Eye") ~= nil, "mask piece")
		for id, def in R.OUTFIT do
			if def.variant ~= "" then
				local list = RookieData.outfit[def.slot] and RookieData.outfit[def.slot][def.variant]
				Assert.truthy(list ~= nil and #list > 0, id .. " has kit pieces")
			end
		end
		for slot, variants in RookieData.outfit do
			for variant in variants do
				local found = false
				for _, def in R.OUTFIT do
					found = found or (def.slot == slot and def.variant == variant)
				end
				Assert.truthy(found, "kit variant " .. slot .. "/" .. variant .. " has an OUTFIT id")
			end
		end
	end)

	test("RookieData: an R15 rig (15 parts, R15 joints and parents) that matches the kit manifest", function()
		local man = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json")).parts
		Assert.eq(#RookieData.body, 15, "15 body parts")
		local seen = {}
		for _, b in RookieData.body do
			local want = R15[b.part]
			Assert.truthy(want ~= nil, b.part .. " is an R15 part")
			Assert.eq(b.joint, want[1], b.part .. " joint")
			Assert.eq(b.parent, want[2], b.part .. " parent")
			seen[b.part] = true
			local m = man[b.piece]
			Assert.truthy(m ~= nil, b.piece .. " in the manifest")
			for i = 1, 3 do
				Assert.near(b.origin[i], m.origin[i], 1e-3, b.piece .. " origin " .. i)
				Assert.near(b.size[i], m.size[i], 1e-3, b.piece .. " size " .. i)
			end
		end
		for part in R15 do
			Assert.truthy(seen[part], part .. " present")
		end
		for name, a in RookieData.attach do
			Assert.truthy(man[name] ~= nil, name .. " in the manifest")
			Assert.truthy(R15[a.part] ~= nil, name .. " attaches to an R15 part")
			for i = 1, 3 do
				Assert.near(a.offset[i], man[name].attach.offset[i], 1e-3, name .. " offset " .. i)
			end
		end
		for _, mood in { "idle", "smug", "shocked", "busted" } do
			Assert.truthy(man[RookieData.faces[mood]] ~= nil, mood .. " face")
		end
		local grips = {}
		for side, v in RookieData.viewmodel do
			Assert.truthy(man[v.piece] ~= nil, side .. " viewmodel piece")
			grips[v.grip] = side
		end
		Assert.eq(grips.GripL, "LeftArm", "GripL on the left arm")
		Assert.eq(grips.GripR, "RightArm", "GripR on the right arm")
		-- the root part sits where the sim expects actors (Config.Levels rootHeight 3)
		Assert.eq(R.HIP_HEIGHT + R.ROOT_SIZE[2] / 2, 3, "root part centre 3 studs up")
	end)
end
