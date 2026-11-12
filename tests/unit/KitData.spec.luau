-- L1: the generated src/server/Kit/KitData.luau (tools/kit_upload.py) agrees with its sources:
-- assets/fbx/kit_manifest.json (every piece, same numbers) and assets/kit_ids.json (every group has an id).
-- A stale KitData (art rebuilt, tool not re-run) fails here: run `python3 tools/kit_upload.py --gen`.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local KitLib = require("../../src/shared/Kit/KitLib")
local KitData = require("../../src/server/Kit/KitData")
local Assert = require("./Assert")

local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json"))
local ids = serde.decode("json", fs.readFile("assets/kit_ids.json"))

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

return function(test)
	test("KitData validates with every group's asset id present", function()
		local problems = KitLib.validate(KitData :: any, true)
		Assert.eq(#problems, 0, "problems:\n" .. table.concat(problems, "\n"))
	end)

	test("KitData has exactly the manifest's pieces with the same model, size, bounds and flags", function()
		Assert.eq(count(KitData.parts), count(manifest.parts), "piece count")
		for name, want in manifest.parts do
			local got = KitData.parts[name]
			Assert.truthy(got, name .. " in KitData")
			Assert.eq(got.model, want.model, name .. " model")
			Assert.eq(got.collision, want.collision, name .. " collision")
			Assert.eq(got.material, want.material, name .. " material")
			Assert.eq(got.canCollide, want.canCollide, name .. " canCollide")
			Assert.eq(got.castShadow, want.castShadow, name .. " castShadow")
			Assert.eq(got.atlas, want.atlas, name .. " atlas")
			for _, key in { "size", "boundsMin", "boundsMax", "origin" } do
				for i = 1, 3 do
					Assert.near(got[key][i], want[key][i], 1e-6, name .. " " .. key .. "[" .. i .. "]")
				end
			end
		end
	end)

	test("KitData asset ids match assets/kit_ids.json", function()
		Assert.eq(count(KitData.assets), count(ids.models), "group count")
		for model, rec in ids.models do
			Assert.eq(KitData.assets[model], rec.assetId, model .. " id")
		end
		for stem, rec in ids.images or {} do
			Assert.eq(KitData.images[stem] and KitData.images[stem].decal, rec.assetId, stem .. " decal id")
			Assert.eq(KitData.images[stem].image, rec.image, stem .. " image id")
		end
		local app = ids.appearances
		Assert.eq(KitData.appearances, if type(app) == "table" then app.assetId else nil, "appearances id")
	end)

	test("every hero piece (manifest texture) has its maps uploaded and is in the appearances asset", function()
		for name, p in manifest.parts do
			if p.texture then
				Assert.truthy(KitData.parts[name].texture, name .. " texture in KitData")
				local color = KitData.images[p.texture .. "_Color"]
				Assert.truthy(color and color.image, name .. " colour map image id")
				local app = ids.appearances
				Assert.truthy(
					type(app) == "table" and table.find(app.pieces, name),
					name .. " in the appearances asset"
				)
			end
		end
	end)

	test("every Neon and glass piece has an idle colour; atlas pieces carry none (white) unless tintable", function()
		for name, p in KitData.parts do
			if p.material == "Neon" or p.material == "Glass" then
				Assert.truthy(p.color and KitLib.hex(p.color), name .. " colour")
				Assert.falsy(p.atlas, name .. " has no atlas")
			elseif p.color then
				Assert.truthy(p.tintable, name .. " colour only on tintable ornaments")
			end
		end
	end)

	test("every manifest atlas maps to a texture file stem", function()
		for loc, file in manifest.atlases do
			local stem = string.match(file, "([^/]+)%.png$")
			Assert.eq(KitData.atlases[loc], stem, loc .. " atlas stem")
		end
	end)
end
