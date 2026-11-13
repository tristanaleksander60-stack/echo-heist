-- L1: the lighting numbers stay inside sane bounds (Config.Lighting.LIMITS; owner, live v125: "the light is WAY too
-- sharp": walls washed to white in first person). Recipe A lives in the four project files (Rojo writes the Lighting
-- service; LightingStyle is not scriptable), recipe C in Config.Perf.SOFT_TOYBOX, the lamps in Config.Lighting /
-- Config.Lobby / Config.Interior.THEMES, the unlit glows in Config.Lighting.POOL / Config.Clone / Config.Lobby.BOARD.
-- Asserted: exposure near neutral, Bloom subtle with a high threshold, Contrast low, every lamp under its cap (and the
-- per-level theme lamps too), every unlit glow under the Bloom threshold (so only bulbs, Neon and the signals bloom),
-- Ambient <= OutdoorAmbient, and the four project files agree.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Config = require("../../src/shared/Config")
local Assert = require("./Assert")

local LIM = Config.Lighting.LIMITS
local FILES =
	{ "default.project.json", "bench.project.json", "spikes/capture.project.json", "spikes/stems.project.json" }

local function lightingOf(path: string): any
	local project = serde.decode("json", fs.readFile(path))
	return project.tree.Lighting
end

local function sum(c: { number }): number
	return c[1] + c[2] + c[3]
end

-- Every light spec { brightness, angle?, shadows? } in the levels and the hideout, with a name.
local function lamps(): { { name: string, brightness: number, spot: boolean } }
	local out = {}
	for kind, l in Config.Lighting.LAMP do
		table.insert(out, { name = "Lighting.LAMP." .. kind, brightness = l.brightness, spot = l.shadows == true })
	end
	local LB = Config.Lobby
	for _, key in { "WORK_LAMP", "YOUR_LAMP", "TROPHY_LIGHT", "AISLE_LAMP" } do
		local l = LB[key]
		table.insert(out, { name = "Lobby." .. key, brightness = l.brightness, spot = l.shadows == true })
	end
	for theme, t in Config.Interior.THEMES do
		if t.light and t.light.brightness then
			table.insert(out, { name = "Interior.THEMES." .. theme, brightness = t.light.brightness, spot = false })
		end
	end
	return out
end

return function(test)
	test("lighting: recipe A (the project files) is neutral, its Bloom subtle with a high threshold", function()
		local A = lightingOf(FILES[1])
		local p = A["$properties"]
		Assert.le(math.abs(p.ExposureCompensation), LIM.EXPOSURE, "ExposureCompensation near 0")
		Assert.le(sum(p.Ambient), LIM.AMBIENT_SUM, "Ambient fill")
		for i = 1, 3 do
			Assert.le(p.Ambient[i], p.OutdoorAmbient[i], "Ambient <= OutdoorAmbient")
		end
		local bloom = A.Bloom["$properties"]
		Assert.le(bloom.Intensity, LIM.BLOOM_INTENSITY, "Bloom.Intensity")
		Assert.truthy(bloom.Threshold >= LIM.BLOOM_THRESHOLD, "Bloom.Threshold >= " .. LIM.BLOOM_THRESHOLD)
		Assert.le(A.ColorCorrection["$properties"].Contrast, LIM.CONTRAST, "ColorCorrection.Contrast")
		Assert.le(A.ColorCorrection["$properties"].Brightness, 0.05, "ColorCorrection.Brightness")
	end)

	test("lighting: the four project files carry the same recipe A", function()
		local want = serde.encode("json", lightingOf(FILES[1]))
		for i = 2, #FILES do
			Assert.eq(serde.encode("json", lightingOf(FILES[i])), want, FILES[i] .. " Lighting = default's")
		end
	end)

	test("lighting: recipe C (the low tiers) is neutral and its Bloom subtle too", function()
		local C = Config.Perf.SOFT_TOYBOX
		Assert.le(math.abs(C.Lighting.ExposureCompensation), LIM.EXPOSURE, "recipe C exposure")
		Assert.le(C.Bloom.Intensity, LIM.BLOOM_INTENSITY, "recipe C Bloom.Intensity")
		Assert.truthy(C.Bloom.Threshold >= LIM.BLOOM_THRESHOLD, "recipe C Bloom.Threshold")
		Assert.le(C.ColorCorrection.Contrast, LIM.CONTRAST, "recipe C Contrast")
		Assert.le(sum(C.Lighting.Ambient) / 255, LIM.AMBIENT_SUM, "recipe C Ambient")
		for i = 1, 3 do
			Assert.le(C.Lighting.Ambient[i], C.Lighting.OutdoorAmbient[i], "recipe C Ambient <= OutdoorAmbient")
		end
	end)

	test("lighting: every level and hideout lamp is under its cap", function()
		local n = 0
		for _, l in lamps() do
			local cap = if l.spot then LIM.SPOT_BRIGHTNESS else LIM.POINT_BRIGHTNESS
			Assert.le(l.brightness, cap, l.name .. " brightness")
			Assert.truthy(l.brightness > 0.5, l.name .. " still lights the room")
			n += 1
		end
		Assert.truthy(n >= 10, "every lamp kind checked")
		Assert.le(Config.Clone.HALO_LIGHT_BRIGHTNESS, LIM.HALO_BRIGHTNESS, "your halo light")
	end)

	test("lighting: unlit glows stay under the Bloom threshold (only light sources bloom)", function()
		local threshold = lightingOf(FILES[1]).Bloom["$properties"].Threshold
		Assert.truthy(LIM.UNLIT_GLOW < threshold, "the glow cap is under the threshold")
		local glows = {
			["Lighting.POOL"] = Config.Lighting.POOL.brightness,
			["Clone.GLOW_BRIGHTNESS"] = Config.Clone.GLOW_BRIGHTNESS,
			["Lobby.BOARD.glowBrightness"] = Config.Lobby.BOARD.glowBrightness,
		}
		for name, b in glows do
			Assert.le(b, LIM.UNLIT_GLOW, name)
		end
	end)
end
