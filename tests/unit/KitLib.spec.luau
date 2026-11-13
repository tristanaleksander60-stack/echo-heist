-- L1: Kit/KitLib, the pure helpers of the automated kit path (KitService, docs/art/KIT_IMPORT.md
-- "Automated path"): MeshPart name map (never a same-named Model), group matching, size/pivot maths,
-- fidelity rebuild rule, atlas choice, data validation.

local KitLib = require("../../src/shared/Kit/KitLib")
local Assert = require("./Assert")

-- Instance-like stand-ins: Name + IsA.
local function inst(class: string, name: string): any
	return {
		Name = name,
		ClassName = class,
		IsA = function(self: any, c: string): boolean
			return self.ClassName == c
		end,
	}
end

local function spec(over: { [string]: any }?): KitLib.PartSpec
	local s: any = {
		model = "GoldBar",
		size = { 2, 0.6, 1 },
		boundsMin = { -1, 0, -0.5 },
		boundsMax = { 1, 0.6, 0.5 },
		origin = { 0, 0, 0 },
		collision = "Box",
		material = "SmoothPlastic",
		canCollide = true,
		castShadow = false,
		atlas = true,
		layer = "base",
	}
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

local function data(parts: { [string]: any }, assets: { [string]: any }): KitLib.KitData
	return { parts = parts, assets = assets, images = {}, atlases = { Bank = "EH_Palette_Bank" } }
end

return function(test)
	test("uri: numbers and numeric strings become rbxassetid, URIs stay, empty stays empty", function()
		Assert.eq(KitLib.uri(123), "rbxassetid://123", "number")
		Assert.eq(KitLib.uri(88506285657272), "rbxassetid://88506285657272", "14-digit id keeps every digit")
		Assert.eq(KitLib.uri(" 456 "), "rbxassetid://456", "string")
		Assert.eq(KitLib.uri("rbxassetid://7"), "rbxassetid://7", "uri")
		Assert.eq(KitLib.uri(""), "", "empty")
		Assert.eq(KitLib.uri(nil), "", "nil")
		Assert.eq(KitLib.uri(0), "", "zero")
	end)

	test("hex: #RRGGBB to 0..1, junk to nil", function()
		local r, g, b = KitLib.hex("#FF3838")
		Assert.near(r :: number, 1, 1e-9, "r")
		Assert.near(g :: number, 0x38 / 255, 1e-9, "g")
		Assert.near(b :: number, 0x38 / 255, 1e-9, "b")
		Assert.eq((KitLib.hex("red")), nil, "junk")
	end)

	test("nameMap: finds MeshParts by name and ignores a Model of the same name", function()
		local items = {
			inst("Model", "CashBag"),
			inst("Model", "EH Kit CashBag"),
			inst("MeshPart", "CashBag"),
			inst("Decal", "CashBag"),
		}
		local map, dups = KitLib.nameMap(items)
		Assert.eq(map.CashBag, items[3], "the MeshPart, not the Model")
		Assert.eq(#dups, 0, "no dups")
	end)

	test("nameMap: duplicates keep the first and are listed", function()
		local a, b = inst("MeshPart", "Safe"), inst("MeshPart", "Safe")
		local map, dups = KitLib.nameMap({ a, b })
		Assert.eq(map.Safe, a, "first kept")
		Assert.eq(#dups, 1, "one dup")
		Assert.eq(dups[1], "Safe", "dup name")
	end)

	test("matchGroup: missing and extra pieces", function()
		local found = { Safe = true, Safe_Lid = true }
		local missing, extra = KitLib.matchGroup({ "Safe", "Safe_Door" }, found)
		Assert.eq(#missing, 1, "missing count")
		Assert.eq(missing[1], "Safe_Door", "missing")
		Assert.eq(#extra, 1, "extra count")
		Assert.eq(extra[1], "Safe_Lid", "extra")
	end)

	test("groups: pieces grouped by model, both sorted", function()
		local groups, order = KitLib.groups({
			VaultDoor_Frame = spec({ model = "VaultDoor" }),
			VaultDoor_Door = spec({ model = "VaultDoor" }),
			Candy = spec({ model = "Candy" }),
		})
		Assert.eq(#order, 2, "two groups")
		Assert.eq(order[1], "Candy", "sorted groups")
		Assert.eq(groups.VaultDoor[1], "VaultDoor_Door", "sorted pieces")
		Assert.eq(groups.VaultDoor[2], "VaultDoor_Frame", "sorted pieces 2")
	end)

	test("sizeError: largest axis difference", function()
		Assert.near(KitLib.sizeError(2, 0.6000002, 1, { 2, 0.6, 1 }), 0, 1e-6, "measured GoldBar")
		Assert.near(KitLib.sizeError(200, 60, 100, { 2, 0.6, 1 }), 198, 1e-9, "100x too big")
	end)

	test("pivotOffset and scenePosition from the manifest bounds (GoldBar: pivot on the floor)", function()
		local s = spec()
		local po = KitLib.pivotOffset(s)
		Assert.near(po[1], 0, 1e-9, "x")
		Assert.near(po[2], -0.3, 1e-9, "y: the measured upload put it at -0.3 too")
		Assert.near(po[3], 0, 1e-9, "z")
		local gus =
			spec({ boundsMin = { -1.04, -0.1, -1.145 }, boundsMax = { 1.04, 1.5, 0.8 }, origin = { 0, 4.5, 0 } })
		local p = KitLib.scenePosition(gus)
		Assert.near(p[2], 4.5 + 0.7, 1e-9, "Gus_Head centre 0.7 above the Neck pivot")
		Assert.near(p[3], -0.1725, 1e-9, "z")
	end)

	test("needsRebuild: only when the fidelity differs; modes all / colliding / none", function()
		local box = spec()
		Assert.falsy(KitLib.needsRebuild("Box", box, "all"), "already Box")
		Assert.truthy(KitLib.needsRebuild("Default", box, "all"), "all")
		Assert.falsy(KitLib.needsRebuild("Default", box, "none"), "none")
		Assert.truthy(KitLib.needsRebuild("Default", box, "colliding"), "colliding piece")
		Assert.falsy(KitLib.needsRebuild("Default", spec({ canCollide = false }), "colliding"), "walk-in hide")
	end)

	test("renderFidelity: Precise only for the hero prefixes (STUDIO_FIDELITY)", function()
		local pre = { "Rookie_", "Gus_", "VaultDoor_" }
		Assert.eq(KitLib.renderFidelity("Rookie_Head", pre), "Precise", "Rookie")
		Assert.eq(KitLib.renderFidelity("Gus_LeftHand", pre), "Precise", "Gus")
		Assert.eq(KitLib.renderFidelity("VaultDoor_Door", pre), "Precise", "vault")
		Assert.eq(KitLib.renderFidelity("Wall_8x12", pre), "Automatic", "a wall")
		Assert.eq(KitLib.renderFidelity("Gus", pre), "Automatic", "the prefix needs the underscore")
		Assert.eq(KitLib.renderFidelity("Rookie_Head", nil), "Automatic", "no list")
	end)

	test("atlasUri: override, then the uploaded image, then the imported fallback", function()
		local d = data({}, {})
		d.images = { EH_Palette_Bank = { decal = 5, image = 6 } }
		local uri, source = KitLib.atlasUri("Bank", { Bank = "99" }, d, "rbxassetid://1")
		Assert.eq(uri, "rbxassetid://99", "override")
		Assert.truthy(string.find(source, "Config", 1, true), "override source")
		uri = KitLib.atlasUri("Bank", { Bank = "" }, d, "rbxassetid://1")
		Assert.eq(uri, "rbxassetid://6", "uploaded image")
		d.images = { EH_Palette_Bank = { decal = 5 } }
		uri, source = KitLib.atlasUri("Bank", {}, d, "rbxassetid://1")
		Assert.eq(uri, "rbxassetid://1", "fallback")
		Assert.eq(source, "imported FBX texture", "fallback source")
		uri = KitLib.atlasUri("ToyShop", {}, d, "")
		Assert.eq(uri, "", "unknown location: nothing")
	end)

	test("validate: a good kit passes; ids optional unless required", function()
		local d = data({ GoldBar = spec() }, { GoldBar = 88506285657272 })
		Assert.eq(#KitLib.validate(d, true), 0, "good")
		Assert.eq(#KitLib.validate(data({ GoldBar = spec() }, {}), false), 0, "no ids, not required")
		Assert.eq(#KitLib.validate(data({ GoldBar = spec() }, {}), true), 1, "no ids, required")
	end)

	test("validate: catches bad sizes, bounds, collision, material, colour, ids", function()
		local bad = data({
			A = spec({ size = { 0, 1, 1 }, boundsMin = { 0, 0, 0 }, boundsMax = { 0, 1, 1 } }),
			B = spec({ collision = "Mesh" }),
			C = spec({ material = "Wood" }),
			D = spec({ color = "red" }),
			E = spec({ size = { 2, 2, 1 } }),
			F = spec({ transparency = 1 }),
		}, { GoldBar = -4, Ghost = 12 })
		bad.appearances = 1.5
		local problems = KitLib.validate(bad, true)
		local text = table.concat(problems, "\n")
		for _, want in
			{
				"A: size must be positive",
				"B: unknown collision",
				"C: unknown material",
				"D: color",
				"E: bounds axis 2",
				"F: transparency",
				"GoldBar: bad asset id",
				"appearances: bad asset id",
				"Ghost: asset id for a group",
			}
		do
			Assert.truthy(string.find(text, want, 1, true), "reports " .. want .. " in\n" .. text)
		end
	end)
end
