--!strict
-- Heist/AuroraPlan: the northern lights as numbers (PLAN_FIRST_PERSON "SKY"; Config.Aurora; STYLE_BIBLE §16).
-- Pure: no engine calls, so tests/unit/AuroraPlan.spec.luau checks it in Lune, tools/blender/aurora_plan.luau
-- dumps it for the Blender previews, and the client Heist/Aurora turns it into Attachments and Beams.
--
-- A layer is a band of curtain along a spine of control points. The frame is the viewer's ground point turned to
-- the landmark: x to the right, y up, z forward (toward Hoardsworth's tower). The spine lies on a big circle whose
-- centre is behind the viewer, so the band passes `dist` studs ahead at its middle and curves back at its ends, the
-- way real aurora arcs cross the sky in parallel bands. Static folds and slow sway push the points along the
-- circle's radius (toward / away from the viewer) and up and down. One Beam joins two neighbouring points; its
-- curve comes from Catmull-Rom tangents (AuroraPlan.handles), so the chain is smooth through every shared point.

local Budget = require("./Budget")
local Config = require("../Config")

local A = Config.Aurora
local TAU = 2 * math.pi

export type Vec = { x: number, y: number, z: number }
export type Layer = typeof(A.LAYERS[1])
export type Handles = {
	tangents: { Vec }, -- unit tangent at each point (the Attachment's X axis)
	out: { number }, -- Beam k's CurveSize0 (from point k)
	into: { number }, -- Beam k's CurveSize1 (into point k + 1)
}
export type Cost = { layers: number, beams: number, attachments: number, triangles: number, writesPerSecond: number }

local AuroraPlan = {}

local function vec(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function len(v: Vec): number
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

-- The layers drawn at `tier`, in priority order (Budget.auroraLayers).
function AuroraPlan.layers(tier: number): { Layer }
	local out = {}
	for i = 1, Budget.auroraLayers(tier) do
		out[i] = A.LAYERS[i]
	end
	return out
end

-- A point's share along the band (0 at the left end, 1 at the right end).
local function share(layer: Layer, k: number): number
	return (k - 1) / (layer.points - 1)
end

-- A point's sway phase (radians): neighbours drift a little out of step, so the band undulates.
local function phaseOf(layer: Layer, k: number): number
	return TAU * (0.37 * k + layer.foldPhase)
end

-- The spine at time `t` (seconds of motion: the caller scales real time by the reduced-motion factor and holds it
-- at 0 when the tier is static). Points left to right; with `reverse`, right to left (Config.Aurora.REVERSE_SPINE).
function AuroraPlan.spine(layer: Layer, t: number, reverse: boolean?): { Vec }
	local pts = table.create(layer.points)
	local sz, sy, period = layer.sway[1], layer.sway[2], layer.sway[3]
	for k = 1, layer.points do
		local u = share(layer, k)
		local s = (2 * u - 1) * layer.span
		local phi = s / layer.radius
		local ph = phaseOf(layer, k)
		local push = layer.fold * math.sin(TAU * (layer.foldWaves * u + layer.foldPhase))
			+ sz * math.sin(TAU * t / period + ph)
		local r = layer.radius + push
		local y = layer.height
			+ layer.lift * math.sin(TAU * (0.7 * layer.foldWaves * u + layer.foldPhase + 0.3))
			+ sy * math.sin(TAU * t / (period * 1.37) + 1.7 * ph)
		pts[k] = vec(r * math.sin(phi), y, layer.dist - layer.radius + r * math.cos(phi))
	end
	if reverse then
		local n = #pts
		for i = 1, n // 2 do
			pts[i], pts[n + 1 - i] = pts[n + 1 - i], pts[i]
		end
	end
	return pts
end

-- Catmull-Rom handles for a chain through `pts`: the tangent at each point and each Beam's two CurveSizes. A Beam's
-- curve is the Bezier P0, P0 + CurveSize0 * X0, P3 - CurveSize1 * X1, P3 (X = the Attachment's X axis).
function AuroraPlan.handles(pts: { Vec }): Handles
	local n = #pts
	local tangents, mags = table.create(n), table.create(n, 0)
	for k = 1, n do
		local a, b = pts[math.max(k - 1, 1)], pts[math.min(k + 1, n)]
		local scale = if k == 1 or k == n then 1 else 0.5
		local m = vec((b.x - a.x) * scale, (b.y - a.y) * scale, (b.z - a.z) * scale)
		local l = len(m)
		mags[k] = l
		tangents[k] = if l > 1e-9 then vec(m.x / l, m.y / l, m.z / l) else vec(1, 0, 0)
	end
	local out, into = table.create(n - 1, 0), table.create(n - 1, 0)
	for k = 1, n - 1 do
		out[k] = mags[k] / 3
		into[k] = mags[k + 1] / 3
	end
	return { tangents = tangents, out = out, into = into }
end

-- The point on Beam k's curve at s (0..1), from the same Bezier the engine draws (specs, previews).
function AuroraPlan.curvePoint(pts: { Vec }, h: Handles, k: number, s: number): Vec
	local p0, p3 = pts[k], pts[k + 1]
	local t0, t1 = h.tangents[k], h.tangents[k + 1]
	local p1 = vec(p0.x + t0.x * h.out[k], p0.y + t0.y * h.out[k], p0.z + t0.z * h.out[k])
	local p2 = vec(p3.x - t1.x * h.into[k], p3.y - t1.y * h.into[k], p3.z - t1.z * h.into[k])
	local a, b, c, d = (1 - s) ^ 3, 3 * (1 - s) ^ 2 * s, 3 * (1 - s) * s * s, s ^ 3
	return vec(
		a * p0.x + b * p1.x + c * p2.x + d * p3.x,
		a * p0.y + b * p1.y + c * p2.y + d * p3.y,
		a * p0.z + b * p1.z + c * p2.z + d * p3.z
	)
end

-- The layer's Brightness at time t (breathing; the caller holds t at 0 on a static tier).
function AuroraPlan.brightness(layer: Layer, t: number): number
	local amount, period = layer.breathe[1], layer.breathe[2]
	return A.BRIGHTNESS * layer.brightness * (1 + amount * math.sin(TAU * t / period + TAU * layer.foldPhase))
end

-- The tint mix (0 = TINT_A, 1 = TINT_B) at share u along the band at time t: a slow wave that travels along it.
function AuroraPlan.tintMix(layer: Layer, u: number, t: number): number
	local period = layer.breathe[2] * 1.9
	return 0.5 + 0.5 * math.sin(TAU * (A.TINT_WAVE * u - t / period + layer.foldPhase))
end

-- How visible point k is (0..1): the band fades out at both ends, so it never stops with a hard edge.
function AuroraPlan.endFade(layer: Layer, k: number): number
	return if k == 1 or k == layer.points then 0 else 1
end

-- Which Config.Aurora.TEXTURES tile Beam k of a layer shows (the tiles alternate; they share their edge columns).
function AuroraPlan.texture(layer: Layer, k: number): number
	return (layer.texture + k - 2) % #A.TEXTURES + 1
end

-- The lowest a layer's ribbon can reach over every sway phase, as (height over the anchor in studs, elevation over
-- the viewer's horizon in degrees). A bound, not a sample: every displacement at its worst at once, and the
-- ribbon's half width taken straight down.
function AuroraPlan.lowest(layer: Layer): (number, number)
	local low = layer.height - math.abs(layer.lift) - layer.sway[2] - layer.width / 2
	local minElev = math.huge
	for k = 1, layer.points do
		local phi = (2 * share(layer, k) - 1) * layer.span / layer.radius
		local far = 0
		for _, push in { -1, 1 } do
			local r = layer.radius + push * (math.abs(layer.fold) + layer.sway[1])
			local x, z = r * math.sin(phi), layer.dist - layer.radius + r * math.cos(phi)
			far = math.max(far, math.sqrt(x * x + z * z))
		end
		minElev = math.min(minElev, math.deg(math.atan2(low, far)))
	end
	return low, minElev
end

-- The elevation (degrees over the horizon) and bearing (degrees, + to the right of the landmark) of a layer's
-- middle at rest: where it sits on screen.
function AuroraPlan.middle(layer: Layer): (number, number)
	local p = AuroraPlan.spine(layer, 0)[(layer.points + 1) // 2]
	return math.deg(math.atan2(p.y, math.sqrt(p.x * p.x + p.z * p.z))), math.deg(math.atan2(p.x, p.z))
end

-- A local point (x right, y up, z forward) as a world offset for a landmark yaw (degrees; 0 = toward -Z, positive
-- toward -X, Config.Backdrop.SKY_LANDMARK_YAW's convention): CFrame.Angles(0, yaw, 0) * (x, y, -z).
function AuroraPlan.toWorld(p: Vec, yaw: number): Vec
	local c, s = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	local lz = -p.z
	return vec(p.x * c + lz * s, p.y, -p.x * s + lz * c)
end

-- The cost at `tier`: layers, Beams, Attachments, triangles (2 per Beam segment) and property writes a second
-- (static tiers write once: 0; animated tiers write each point's CFrame and each Beam's two CurveSizes, Brightness
-- and Color UPDATE_HZ times a second).
function AuroraPlan.cost(tier: number): Cost
	local layers = AuroraPlan.layers(tier)
	local beams, attachments = 0, 0
	for _, layer in layers do
		beams += layer.points - 1
		attachments += layer.points
	end
	local writes = if Budget.auroraAnimated(tier) then (attachments + 4 * beams) * A.UPDATE_HZ else 0
	return {
		layers = #layers,
		beams = beams,
		attachments = attachments,
		triangles = beams * A.SEGMENTS * 2,
		writesPerSecond = writes,
	}
end

return table.freeze(AuroraPlan)
