-- L1: random characters (Heist/Outfit.roll / rollIfNew, the knit tone): a roll only uses unlocked ids, a first join
-- rolls once (a profile that chose keeps its pick), two fresh players differ most of the time, the tone tints only
-- knit gloves, older 5-part keys still read, and the wardrobe's RANDOM equip keys never clash with cosmetics.

local Config = require("../../src/shared/Config")
local Outfit = require("../../src/shared/Heist/Outfit")
local Schema = require("../../src/shared/Data/Schema")
local Assert = require("./Assert")

local R = Config.Rookie

-- A seeded pick (Lune has no Random): a small LCG, 1..n.
local function picker(seed: number): (number) -> number
	local s = seed
	return function(n: number): number
		s = (s * 1103515245 + 12345) % 2147483648
		return (s // 65536) % n + 1
	end
end

return function(test: (string, () -> ()) -> ())
	test("a roll uses only unlocked ids of each slot, and every slot over many rolls", function()
		local fresh: any = Schema.defaultHeist()
		local seen: { [string]: boolean } = {}
		local pick = picker(7)
		for _ = 1, 400 do
			local o = Outfit.roll(fresh, pick)
			for _, slot in R.SLOTS do
				local ok, code = Outfit.canWear(fresh, slot, o[slot])
				Assert.truthy(ok, slot .. " rolled a wearable id (" .. code .. ")")
				seen[o[slot]] = true
			end
		end
		for _, slot in R.SLOTS do
			for _, id in Outfit.unlocked(fresh)[slot] do
				Assert.truthy(seen[id], id .. " comes up")
			end
		end
		Assert.falsy(seen.Cap_Bobble or seen.Mask_Eye or seen.Gloves_Leather, "no locked id for a new player")
		-- with stars and a trophy, the unlocked ids join the roll
		local rich: any = Schema.defaultHeist()
		rich.daily.stars = 20
		rich.trophies.Trophy_BackRoom = 1700000000
		local got: { [string]: boolean } = {}
		for _ = 1, 400 do
			local o = Outfit.roll(rich, pick)
			got[o.cap] = true
			got[o.gloves] = true
			got[o.mask] = true
		end
		Assert.truthy(got.Cap_Bobble and got.Gloves_Leather and got.Mask_Eye, "unlocked ids are rolled")
		Assert.falsy(got.Cap_Trapper, "a still-locked cap is not")
		-- a bad pick clamps instead of breaking the outfit
		local bad = Outfit.roll(fresh, function(): number
			return 0 / 0
		end)
		Assert.eq(Outfit.key(bad), Outfit.key(Outfit.clean(bad)), "a NaN pick still gives a clean outfit")
		local high = Outfit.roll(fresh, function(n: number): number
			return n + 5
		end)
		for _, slot in R.SLOTS do
			Assert.truthy((Outfit.canWear(fresh, slot, high[slot])), slot .. " clamps a too-high pick")
		end
	end)

	test("first join rolls once; a profile that already chose keeps its outfit", function()
		local h: any = Schema.defaultHeist()
		Assert.eq(h.outfitRolled, false, "a new profile has not rolled")
		Assert.truthy(Outfit.rollIfNew(h, picker(3)), "first load rolls")
		Assert.eq(h.outfitRolled, true, "flag saved")
		Assert.eq(#Schema.sanitize(h), 0, "the rolled profile is valid as saved")
		local key = Outfit.key(h.outfit)
		Assert.falsy(Outfit.rollIfNew(h, picker(99)), "never again")
		Assert.eq(Outfit.key(h.outfit), key, "the outfit stays")
		-- an older profile that chose before this existed (no flag yet) keeps its pick
		local old: any = Schema.defaultHeist()
		old.outfitRolled = nil
		old.outfit.cap = "Cap_Beanie"
		old.outfit.tone = nil
		Schema.sanitize(old)
		Assert.eq(old.outfitRolled, false, "missing flag repaired to false")
		Assert.eq(old.outfit.tone, R.DEFAULT_OUTFIT.tone, "missing tone repaired")
		Assert.truthy(Outfit.rollIfNew(old, picker(5)), "flag set")
		Assert.eq(old.outfit.cap, "Cap_Beanie", "their cap is kept")
		Assert.falsy(Outfit.rollIfNew(nil, picker(1)), "no slice: nothing")
	end)

	test("two fresh players differ with high probability", function()
		local pick = picker(12345)
		local differ, N = 0, 500
		for _ = 1, N do
			local a = Outfit.roll(nil, pick)
			local b = Outfit.roll(nil, pick)
			if Outfit.key(a) ~= Outfit.key(b) then
				differ += 1
			end
		end
		-- free ids only: 2 caps x 2 scarves x 6 tones = 24 looks -> about 96% of pairs differ
		Assert.truthy(differ / N >= 0.9, string.format("%d / %d pairs differ", differ, N))
	end)

	test("the knit tone tints knit gloves only; old 5-part keys still read", function()
		for _, id in Outfit.idsFor("tone") do
			local def = R.OUTFIT[id]
			Assert.truthy(def.free == true and def.variant == "", id .. " is a free colour with no piece")
			Assert.truthy(type(def.hex) == "string" and #def.hex == 7, id .. " has a hex")
			Assert.truthy(type(def.name) == "string" and def.name ~= "", id .. " has a name")
		end
		Assert.truthy(#Outfit.idsFor("tone") >= 4, "at least 4 knit colours")
		Assert.eq(Outfit.gloveHex(Outfit.default()), R.GLOVES.Gloves_Knit, "the default tone is the old knit colour")
		local o = Outfit.default()
		o.tone = "Tone_Burgundy"
		Assert.eq(Outfit.gloveHex(o), R.OUTFIT.Tone_Burgundy.hex, "knit gloves take the tone")
		o.gloves = "Gloves_Leather"
		Assert.eq(Outfit.gloveHex(o), R.GLOVES.Gloves_Leather, "leather keeps its colour")
		Assert.eq(#Outfit.pieces(o), #Outfit.pieces(Outfit.default()), "a tone adds no piece")
		local five = "Cap_Beanie|Scarf_Chunky|Sweater_Stripes|Gloves_Knit|Mask_None"
		local read = Outfit.fromKey(five)
		Assert.eq(read.cap, "Cap_Beanie", "old key: cap")
		Assert.eq(read.tone, R.DEFAULT_OUTFIT.tone, "old key: default tone")
		Assert.falsy(Outfit.canWear(nil, "tone", "Cap_Flat"), "a cap is not a tone")
	end)

	test("the RANDOM equip keys never clash with cosmetics or outfit slots", function()
		local RANDOM = R.RANDOM
		Assert.falsy(Outfit.isSlot(RANDOM.EQUIP_SLOT), "not an outfit slot")
		Assert.truthy(Config.Data.DEFAULT_EQUIPPED[RANDOM.EQUIP_SLOT] == nil, "not a cosmetic slot")
		Assert.truthy(Config.Data.Cosmetics[RANDOM.EQUIP_ID] == nil, "not a cosmetic id")
		Assert.truthy(R.OUTFIT[RANDOM.EQUIP_ID] == nil, "not an outfit id")
		for _, s in R.TAB_SLOTS do
			Assert.truthy(Outfit.isSlot(s), s .. " (a wardrobe tab) is a slot")
		end
	end)
end
