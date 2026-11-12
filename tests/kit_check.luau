--!strict
-- Spike S2 check (MASTERPLAN §8.11): the owner-imported kit (assets/Kit.rbxm, mapped by Rojo into
-- ServerStorage/Kit) must come out of `rojo build` with the sizes, collision and flags that the Blender
-- pipeline expects (assets/fbx/kit_manifest.json, written by tools/blender/build_asset.py).
--   rojo build -o build/EchoHeist.rbxlx
--   lune run tests/kit_check.luau build/EchoHeist.rbxlx
-- Before the kit is mapped (no ServerStorage/Kit yet) it prints "skip" and exits 0, so CI stays green.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

type Part = {
	model: string,
	size: { number },
	collision: string,
	material: string,
	canCollide: boolean,
	castShadow: boolean,
	atlas: boolean,
}

local SIZE_TOLERANCE = 0.05 -- studs

local path = process.args[1] or "build/EchoHeist.rbxlx"
local game = roblox.deserializePlace(fs.readFile(path))
local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json"))
local parts = manifest.parts :: { [string]: Part }

local kit = game:GetService("ServerStorage"):FindFirstChild("Kit")
if kit == nil then
	print("skip  ServerStorage/Kit is not in the place yet (S2 pending: see docs/art/KIT_IMPORT.md)")
	process.exit(0)
end

local problems = 0
local function expect(cond: boolean, msg: string)
	if cond then
		print("ok    " .. msg)
	else
		problems += 1
		print("FAIL  " .. msg)
	end
end

local function prop(inst: any, name: string): any
	local ok, value = pcall(function()
		return inst[name]
	end)
	return if ok then value else nil
end

local function contentUri(inst: any, idName: string, contentName: string): string
	local id = prop(inst, idName)
	if type(id) == "string" and id ~= "" then
		return id
	end
	local content = prop(inst, contentName)
	local uri = if content ~= nil then prop(content, "Uri") else nil
	return if type(uri) == "string" then uri else ""
end

local textures: { [string]: boolean } = {}
for name, want in parts do
	local mesh = kit:FindFirstChild(name, true)
	expect(mesh ~= nil and mesh:IsA("MeshPart"), name .. " is a MeshPart in ServerStorage/Kit")
	if mesh == nil or not mesh:IsA("MeshPart") then
		continue
	end
	local size = prop(mesh, "Size")
	local sizeOk = typeof(size) == "Vector3"
		and math.abs(size.X - want.size[1]) <= SIZE_TOLERANCE
		and math.abs(size.Y - want.size[2]) <= SIZE_TOLERANCE
		and math.abs(size.Z - want.size[3]) <= SIZE_TOLERANCE
	expect(
		sizeOk,
		string.format(
			"%s Size %s (want %.2f, %.2f, %.2f)",
			name,
			tostring(size),
			want.size[1],
			want.size[2],
			want.size[3]
		)
	)
	-- Lune 0.11 cannot read CollisionFidelity back from a file ("malformed property info"), so an
	-- unreadable value is a warning and the owner confirms it in Studio (KIT_IMPORT step 6).
	local fidelity = prop(mesh, "CollisionFidelity")
	if typeof(fidelity) == "EnumItem" then
		expect(
			fidelity.Name == want.collision,
			name .. " CollisionFidelity " .. fidelity.Name .. " (want " .. want.collision .. ")"
		)
	else
		print(
			"warn  " .. name .. " CollisionFidelity unreadable in Lune; check in Studio (want " .. want.collision .. ")"
		)
	end
	local material = prop(mesh, "Material")
	expect(
		typeof(material) == "EnumItem" and material.Name == want.material,
		name .. " Material " .. tostring(material) .. " (want " .. want.material .. ")"
	)
	expect(prop(mesh, "CanCollide") == want.canCollide, name .. " CanCollide " .. tostring(want.canCollide))
	expect(prop(mesh, "CastShadow") == want.castShadow, name .. " CastShadow " .. tostring(want.castShadow))
	expect(contentUri(mesh, "MeshId", "MeshContent") ~= "", name .. " has a mesh asset (survived rojo build)")
	local texture = contentUri(mesh, "TextureID", "TextureContent")
	if want.atlas then
		expect(texture ~= "", name .. " uses the kit atlas texture")
		if texture ~= "" then
			textures[texture] = true
		end
	else
		expect(texture == "", name .. " has no texture (Neon, tinted by code)")
	end
end

local distinct = 0
for _ in textures do
	distinct += 1
end
expect(distinct <= 1, string.format("one shared atlas texture for the whole kit (found %d)", distinct))

if problems > 0 then
	print(string.format("\n%d kit problem(s)", problems))
	process.exit(1)
end
print("\nkit check passed")
