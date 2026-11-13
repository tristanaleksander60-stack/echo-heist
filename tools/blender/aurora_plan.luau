--!strict
-- Dumps the northern lights as Heist/Aurora draws them (Shared/Heist/AuroraPlan, Config.Aurora) as JSON, for
-- tools/blender/aurora_shots.py: every layer's Beams sampled along the same Bezier the engine draws (Segments + 1
-- points, in the layer's local frame: x right, y up, z toward the landmark), with each Beam's tile, end fades,
-- tint mix and the layer's width, transparency and brightness at motion time t.
--   lune run tools/blender/aurora_plan.luau [t] > aurora_plan.json

local process = require("@lune/process")
local serde = require("@lune/serde")

local AuroraPlan = require("../../src/shared/Heist/AuroraPlan")
local Config = require("../../src/shared/Config")

local A = Config.Aurora
local t = tonumber(process.args[1]) or 0

local layers = {}
for i, layer in A.LAYERS do
	local pts = AuroraPlan.spine(layer, t, A.REVERSE_SPINE)
	local h = AuroraPlan.handles(pts)
	local beams = {}
	for k = 1, layer.points - 1 do
		local samples = {}
		for j = 0, A.SEGMENTS do
			local p = AuroraPlan.curvePoint(pts, h, k, j / A.SEGMENTS)
			table.insert(samples, { p.x, p.y, p.z })
		end
		local n = layer.points - 1
		table.insert(beams, {
			texture = AuroraPlan.texture(layer, k),
			fade = { AuroraPlan.endFade(layer, k), AuroraPlan.endFade(layer, k + 1) },
			tint = { AuroraPlan.tintMix(layer, (k - 1) / n, t), AuroraPlan.tintMix(layer, k / n, t) },
			samples = samples,
		})
	end
	table.insert(layers, {
		index = i,
		name = layer.name,
		width = layer.width,
		transparency = layer.transparency,
		brightness = AuroraPlan.brightness(layer, t),
		beams = beams,
	})
end

local tiers = {}
for tier = 1, #A.TIERS do
	local c = AuroraPlan.cost(tier)
	tiers[tier] = { layers = c.layers, beams = c.beams, triangles = c.triangles, writes = c.writesPerSecond }
end

print(serde.encode("json", {
	t = t,
	textures = { "EH_Aurora_A", "EH_Aurora_B", "EH_Aurora_C" },
	tintA = A.TINT_A,
	tintB = A.TINT_B,
	layers = layers,
	tiers = tiers,
}))
