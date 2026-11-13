-- L1: Heist/AuroraPlan and the aurora's tier counts in Heist/Budget (PLAN_FIRST_PERSON "SKY", Config.Aurora,
-- STYLE_BIBLE §16). The tiers only get cheaper (tiers 1-2 every layer, tier 3 two, tier 4 one static layer), no
-- ribbon can come low enough to be reached or to stand in a room, the bands sit where the cameras see them (over
-- the landmark, near the zenith, a glow at the top of the classic frame), the Beam chains are smooth through every
-- shared point, and the cost stays a sliver of each tier's budget.

local AuroraPlan = require("../../src/shared/Heist/AuroraPlan")
local Budget = require("../../src/shared/Heist/Budget")
local Config = require("../../src/shared/Config")
local Assert = require("./Assert")

local A = Config.Aurora
local CAM = Config.Heist.CAMERA

local function dist(a: any, b: any): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function layerNamed(name: string): any
	for _, l in A.LAYERS do
		if l.name == name then
			return l
		end
	end
	error("no aurora layer " .. name)
end

return function(test)
	test("tiers: 1-2 every layer and animated, 3 two layers, 4 one static layer; never more, never none", function()
		Assert.truthy(#A.LAYERS >= 3 and #A.LAYERS <= 5, "3-5 curtain layers")
		Assert.eq(#A.TIERS, #Config.Heist.PERF_TIERS, "an aurora row per PERF_TIERS entry")
		Assert.eq(Budget.auroraLayers(1), #A.LAYERS, "tier 1: every layer")
		Assert.eq(Budget.auroraLayers(2), #A.LAYERS, "tier 2: every layer")
		Assert.eq(Budget.auroraLayers(3), 2, "tier 3: two layers")
		Assert.eq(Budget.auroraLayers(4), 1, "tier 4: one layer")
		Assert.truthy(Budget.auroraAnimated(1) and Budget.auroraAnimated(2), "tiers 1-2 animated")
		Assert.truthy(Budget.auroraAnimated(3), "tier 3 animated")
		Assert.falsy(Budget.auroraAnimated(4), "tier 4 static")
		Assert.eq(Budget.auroraLayers(0), Budget.auroraLayers(1), "below 1 clamps")
		Assert.eq(Budget.auroraLayers(9), Budget.auroraLayers(4), "above the last clamps")
		for tier = 2, #A.TIERS do
			Assert.le(Budget.auroraLayers(tier), Budget.auroraLayers(tier - 1), "tier " .. tier .. " no dearer")
			Assert.le(Budget.auroraBeams(tier), Budget.auroraBeams(tier - 1), "tier " .. tier .. " Beams")
		end
		Assert.eq(#AuroraPlan.layers(3), 2, "the plan keeps the tier's count")
		Assert.eq(AuroraPlan.layers(4)[1], A.LAYERS[1], "the static layer is the first in priority (the Veil)")
	end)

	test("cost: Beams, triangles and writes per tier; a static tier writes nothing after its pose", function()
		local beams = 0
		for _, l in A.LAYERS do
			beams += l.points - 1
		end
		local c1, c3, c4 = AuroraPlan.cost(1), AuroraPlan.cost(3), AuroraPlan.cost(4)
		Assert.eq(c1.beams, beams, "tier 1 draws every Beam")
		Assert.eq(c1.beams, Budget.auroraBeams(1), "Budget and plan agree")
		Assert.eq(c1.triangles, beams * A.SEGMENTS * 2, "2 triangles per Beam segment")
		Assert.eq(c4.writesPerSecond, 0, "tier 4: posed once")
		Assert.truthy(c3.writesPerSecond < c1.writesPerSecond, "tier 3 writes less")
		for tier = 1, #A.TIERS do
			local c = AuroraPlan.cost(tier)
			-- a sliver of the tier's view budget: under 1 % of its triangles; the draws are a few Beam batches
			Assert.le(c.triangles, Budget.forTier(tier).tris * 0.01, "tier " .. tier .. " triangles")
			Assert.le(c.writesPerSecond, 2500, "tier " .. tier .. " property writes a second")
		end
	end)

	test("never reachable, never in a room: every ribbon over the clearance and the elevation floor", function()
		for _, l in A.LAYERS do
			local h, elev = AuroraPlan.lowest(l)
			Assert.truthy(h >= A.MIN_CLEARANCE, l.name .. " lowest " .. math.floor(h) .. " studs")
			Assert.truthy(elev >= A.MIN_ELEVATION, string.format("%s lowest %.1f deg", l.name, elev))
			Assert.truthy(l.follow > 0 and l.follow <= 1, l.name .. " follows the camera")
			-- the bound holds over a sampled hour of sway
			for t = 0, 3600, 7.3 do
				for _, p in AuroraPlan.spine(l, t) do
					Assert.truthy(p.y - l.width / 2 >= h - 1e-6, l.name .. " sample under the bound")
				end
			end
		end
	end)

	test("where the bands sit: over the landmark, near the zenith, a glow at the top of the classic frame", function()
		local veilElev, veilBearing = AuroraPlan.middle(layerNamed("Veil"))
		Assert.near(veilBearing, 0, 1, "the Veil's middle is straight over the landmark")
		Assert.truthy(veilElev >= 35 and veilElev <= 65, "the Veil fills a first-person look up (" .. veilElev .. ")")
		local crownElev = AuroraPlan.middle(layerNamed("Crown"))
		Assert.truthy(crownElev >= 60, "the Crown passes near the zenith (" .. crownElev .. ")")
		-- the first-person look up reaches it: FP pitches up to PITCH_MIN, plus half the FOV
		Assert.truthy(-CAM.FP.PITCH_MIN + CAM.FP.FOV / 2 >= crownElev, "first person can look at the Crown")
		-- the classic camera's frame top (pitch down, half its vertical FOV up) is over the Glow's hem
		local glow = layerNamed("Glow")
		local p = AuroraPlan.spine(glow, 0)[(glow.points + 1) // 2]
		local hem = math.deg(math.atan2(p.y - glow.width / 2, math.sqrt(p.x * p.x + p.z * p.z)))
		local classicTop = CAM.CLASSIC.FOV / 2 - CAM.CLASSIC.PITCH
		Assert.truthy(hem < classicTop, string.format("the Glow's hem (%.1f deg) under the frame top", hem))
		-- the Snow Globe (13-19.5 deg, STYLE_BIBLE §14) stays under the Veil's hem
		local v = layerNamed("Veil")
		local vp = AuroraPlan.spine(v, 0)[(v.points + 1) // 2]
		local vHem = math.deg(math.atan2(vp.y - v.width / 2, math.sqrt(vp.x * vp.x + vp.z * vp.z)))
		Assert.truthy(vHem > 19.5, string.format("the Veil's hem (%.1f deg) over the globe", vHem))
	end)

	test("the chains are smooth: each Beam's curve starts and ends on its points, tangents shared", function()
		for _, l in A.LAYERS do
			for _, t in { 0, 11.5, 300 } do
				local pts = AuroraPlan.spine(l, t)
				Assert.eq(#pts, l.points, l.name .. " points")
				local h = AuroraPlan.handles(pts)
				for k = 1, l.points - 1 do
					Assert.near(dist(AuroraPlan.curvePoint(pts, h, k, 0), pts[k]), 0, 1e-6, "start on point")
					Assert.near(dist(AuroraPlan.curvePoint(pts, h, k, 1), pts[k + 1]), 0, 1e-6, "end on point")
					Assert.truthy(h.out[k] > 0 and h.into[k] > 0, "handles have length")
					-- no handle longer than its piece: the curve never loops
					local piece = dist(pts[k], pts[k + 1])
					Assert.le(h.out[k], piece, l.name .. " out handle")
					Assert.le(h.into[k], piece, l.name .. " in handle")
				end
				for k = 2, l.points - 1 do
					-- the curve's direction leaving beam k-1 equals the one entering beam k
					local a = AuroraPlan.curvePoint(pts, h, k - 1, 0.999)
					local b = AuroraPlan.curvePoint(pts, h, k, 0.001)
					local da = { x = pts[k].x - a.x, y = pts[k].y - a.y, z = pts[k].z - a.z }
					local db = { x = b.x - pts[k].x, y = b.y - pts[k].y, z = b.z - pts[k].z }
					local la, lb = dist(da, { x = 0, y = 0, z = 0 }), dist(db, { x = 0, y = 0, z = 0 })
					local cos = (da.x * db.x + da.y * db.y + da.z * db.z) / (la * lb)
					Assert.truthy(cos > 0.999, l.name .. " smooth through point " .. k)
				end
			end
		end
	end)

	test("motion: slow sway inside its amplitude, a still rest pose, reverse flips the chain", function()
		local l = layerNamed("Veil")
		local rest = AuroraPlan.spine(l, 0)
		local later = AuroraPlan.spine(l, l.sway[3] / 4)
		local moved, worst = 0, 0
		for k = 1, l.points do
			local d = dist(rest[k], later[k])
			moved = math.max(moved, d)
			worst = math.max(worst, d)
		end
		Assert.truthy(moved > 1, "the spine sways")
		Assert.le(worst, 2 * (l.sway[1] + l.sway[2]), "within twice the amplitudes")
		local again = AuroraPlan.spine(l, 0)
		Assert.near(dist(again[1], rest[1]), 0, 1e-9, "deterministic")
		local rev = AuroraPlan.spine(l, 0, true)
		Assert.near(dist(rev[1], rest[l.points]), 0, 1e-9, "reverse: first is last")
		-- brightness breathes around the base, never off; the tint mix stays in 0..1
		local base = A.BRIGHTNESS * l.brightness
		for t = 0, 60, 0.7 do
			local b = AuroraPlan.brightness(l, t)
			Assert.truthy(b > 0 and math.abs(b - base) <= base * l.breathe[1] + 1e-9, "brightness breathes")
			local m = AuroraPlan.tintMix(l, (t % 10) / 10, t)
			Assert.truthy(m >= 0 and m <= 1, "tint mix in range")
		end
		Assert.truthy(A.REDUCED_MOTION > 0 and A.REDUCED_MOTION < 1, "reduced motion: slower, never off")
	end)

	test("textures: valid ids, neighbours differ, the ends fade, the frame turns like the sky", function()
		Assert.truthy(#A.TEXTURES >= 2, "two or more tiles")
		for _, id in A.TEXTURES do
			Assert.truthy(string.match(id, "^rbxassetid://%d+$") ~= nil, "an image id: " .. id)
		end
		for _, l in A.LAYERS do
			for k = 1, l.points - 1 do
				local i = AuroraPlan.texture(l, k)
				Assert.truthy(i >= 1 and i <= #A.TEXTURES, "a tile index")
				if k > 1 then
					Assert.truthy(i ~= AuroraPlan.texture(l, k - 1), l.name .. ": neighbours show different tiles")
				end
			end
			Assert.eq(AuroraPlan.endFade(l, 1), 0, "left end fades")
			Assert.eq(AuroraPlan.endFade(l, l.points), 0, "right end fades")
			Assert.eq(AuroraPlan.endFade(l, 2), 1, "inside is whole")
			Assert.truthy(l.transparency >= 0 and l.transparency < 1, "a visible base")
		end
		local f0 = AuroraPlan.toWorld({ x = 0, y = 0, z = 10 }, 0)
		Assert.near(f0.z, -10, 1e-9, "yaw 0: forward is -Z")
		local f90 = AuroraPlan.toWorld({ x = 0, y = 0, z = 10 }, 90)
		Assert.near(f90.x, -10, 1e-9, "yaw 90: forward is -X (the sky's turn)")
		local r0 = AuroraPlan.toWorld({ x = 10, y = 5, z = 0 }, 0)
		Assert.truthy(r0.x == 10 and r0.y == 5, "x is to the right, y up")
	end)

	test("the exterior tint only adds (Ambient <= OutdoorAmbient stays true) and is very low", function()
		for _, v in A.OUTDOOR_ADD do
			Assert.truthy(v >= 0 and v <= 12, "a faint, additive tint")
		end
		Assert.truthy(A.OUTDOOR_ADD[2] >= A.OUTDOOR_ADD[1], "green leads")
	end)
end
