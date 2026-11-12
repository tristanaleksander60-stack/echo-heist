--!strict
-- Heist/Budget: the performance budgets per runtime tier (Config.Perf; docs/PERF.md, MASTERPLAN §6.8,
-- roblox_quality §6.4). Pure: no engine calls, so tests/unit/HeistBudget.spec.luau checks it in Lune and the
-- client views (EchoView, Backdrop, LightDirector, WorldView, HeistClient) and tests/perf_engine.luau read the
-- same numbers. Tiers are Config.Heist.PERF_TIERS indices (1 quality ... 4 minimum); out-of-range tiers clamp.

local Config = require("../Config")

local P = Config.Perf

local Budget = {}

export type Tier = {
	drawCalls: number,
	tris: number,
	lights: number,
	shadowed: number,
	liveParticles: number,
	highlights: number,
	cloneGlows: number,
	pillDistance: number,
	lineupLabels: number,
	trails: boolean,
	haloLight: boolean,
	particleScale: number,
	snowAlive: number,
	lightKindsOff: { string },
}

-- A view's candidate for a floor glow: your own clone (`own`) or not, and its distance to the camera.
export type GlowCandidate = { own: boolean, dist: number }

local function clampTier(tier: number): number
	return math.clamp(math.floor(tier), 1, #P.TIERS)
end

-- The budget table of a tier.
function Budget.forTier(tier: number): Tier
	return P.TIERS[clampTier(tier)]
end

-- Recipe C "Soft Toybox" from this tier (LightDirector).
function Budget.softToybox(tier: number): boolean
	return clampTier(tier) >= P.SOFT_TOYBOX_TIER
end

function Budget.bloomOn(tier: number): boolean
	return clampTier(tier) < P.BLOOM_OFF_TIER
end

-- Whether a level lamp of KitPlan kind `kind` stays lit at `tier`.
function Budget.lampOn(tier: number, kind: string?): boolean
	if kind == nil then
		return true
	end
	return table.find(Budget.forTier(tier).lightKindsOff, kind) == nil
end

-- Whether your live character's halo PointLight (Heist/PlayerHalo) is on at `tier`; it counts in every view.
function Budget.haloLight(tier: number): boolean
	return Budget.forTier(tier).haloLight
end

-- A level light's Range at `tier` (recipe C clamps every range).
function Budget.lightRange(tier: number, range: number): number
	if Budget.softToybox(tier) then
		return math.min(range, P.SOFT_TOYBOX.LIGHT_RANGE_MAX)
	end
	return range
end

-- A burst's particle count at `tier`: the base count x the tier's scale, never below BURST_MIN (or the base,
-- when the base itself is smaller).
function Budget.burst(tier: number, base: number): number
	local n = math.floor(base * Budget.forTier(tier).particleScale + 0.5)
	return math.max(n, math.min(base, P.BURST_MIN))
end

-- The tier's particle scale (HeistClient puts it in state.particleScale for WorldView and the HUD).
function Budget.particleScale(tier: number): number
	return Budget.forTier(tier).particleScale
end

-- Falling snow: the emitter rate (particles / s) and the lifetime cap (s) so rate x lifetime stays under the
-- tier's snowAlive. `rate` is the rate the backdrop wants (BackdropPlan.snowRate), `lifeMax` the longest
-- lifetime it wants (reduced motion: longer, slower flakes).
function Budget.snow(tier: number, rate: number, lifeMax: number): (number, number)
	local alive = Budget.forTier(tier).snowAlive
	local r = math.min(rate, alive / math.max(lifeMax, 1e-3))
	local life = if r > 0 then math.min(lifeMax, alive / r) else lifeMax
	return r, life
end

-- The clone pill's BillboardGui.MaxDistance at `tier`.
function Budget.pillDistance(tier: number): number
	return Budget.forTier(tier).pillDistance
end

-- Which candidates keep their floor glow at `tier`: your own clones first (nearest first), then everyone
-- else's by distance, up to the tier's cloneGlows. Returns one boolean per candidate, in input order.
function Budget.glowSet(tier: number, candidates: { GlowCandidate }): { boolean }
	local cap = Budget.forTier(tier).cloneGlows
	local out = table.create(#candidates, false)
	if #candidates <= cap then
		for i = 1, #candidates do
			out[i] = true
		end
		return out
	end
	local order = table.create(#candidates, 0)
	for i = 1, #candidates do
		order[i] = i
	end
	table.sort(order, function(a: number, b: number): boolean
		local ca, cb = candidates[a], candidates[b]
		if ca.own ~= cb.own then
			return ca.own
		end
		if ca.dist ~= cb.dist then
			return ca.dist < cb.dist
		end
		return a < b
	end)
	for k = 1, cap do
		out[order[k]] = true
	end
	return out
end

-- Whether another player's clone group keeps its Highlight at `tier` (yours always does: never invisible).
function Budget.othersHighlight(tier: number): boolean
	return Budget.forTier(tier).highlights > 2
end

-- The base count of each burst named in Config.Perf.WORST_MOMENT.
function Budget.burstBases(): { [string]: number }
	return {
		ribbons = Config.Clone.RIBBON_COUNT,
		sparks = Config.Clone.SPARK_COUNT,
		zap = Config.Clone.ZAP_SPARKS,
		coins = Config.WorldFx.COINS,
		goldRain = P.GOLD_RAIN,
		doorDust = Config.WorldFx.DOOR_DUST,
		laserSparks = Config.Heist.LASER_SPARKS,
	}
end

-- Live particles at the worst moment (snow + every burst in WORST_MOMENT at once, each counted whole).
function Budget.worstParticles(tier: number): number
	local bases = Budget.burstBases()
	local n = Budget.forTier(tier).snowAlive
	for _, name in P.WORST_MOMENT do
		n += Budget.burst(tier, bases[name] or 0)
	end
	return n
end

---------------------------------------------------------------------------
-- Clone LOD (Config.Perf.CLONE_LOD): the textured avatar near the camera, the crew-hue mannequin beyond.
---------------------------------------------------------------------------

-- Whether the clone LOD is on at `tier` (EchoView builds the light rigs from here).
function Budget.cloneLod(tier: number): boolean
	return clampTier(tier) >= P.CLONE_LOD.TIER
end

-- Whether a clone draws as the light version this frame. `wasFar` is what it drew last frame (hysteresis: it
-- turns light beyond FAR and textured again inside NEAR); `exempt` is your newest clone in the L1 tutorial.
function Budget.cloneFar(tier: number, dist: number, wasFar: boolean, exempt: boolean): boolean
	local L = P.CLONE_LOD
	if exempt or clampTier(tier) < L.TIER then
		return false
	end
	if wasFar then
		return dist >= L.NEAR
	end
	return dist > L.FAR
end

-- Whether a Line-up figure is built as the light version: from TIER, never in the front row (`row` 0, the
-- figures nearest the camera) and never `exempt` (you and your newest clone), beyond FAR from the shot's camera.
-- Picked once when the figure is built (the cut is a few seconds: no swaps on screen).
function Budget.lineupLight(tier: number, row: number, dist: number, exempt: boolean): boolean
	local L = P.CLONE_LOD
	return not exempt and clampTier(tier) >= L.TIER and row >= 1 and dist > L.FAR
end

---------------------------------------------------------------------------
-- Start tier (Config.Perf.START): what a client knows at boot, then a short frame-time probe.
---------------------------------------------------------------------------

-- What Heist/Telemetry reads at boot. Quality levels are 0 when Automatic or unreadable.
export type BootFacts = {
	device: string, -- PerfSample.deviceClass: phone | tablet | desktop | console | vr | other
	savedQuality: number, -- UserGameSettings.SavedQualityLevel: 0 Automatic, 1..10 manual
	renderQuality: number, -- RenderSettings.QualityLevel: 0 Automatic / unreadable, 1..RENDER_LEVELS
	viewportMin: number, -- px, the viewport's short side (0 = not known yet)
}

-- The probe's frame times (PerfSample.percentile over the probe window).
export type Probe = { frames: number, medianMs: number, p95Ms: number }

-- The player's quality level on a 1..10 scale, or nil when it says nothing (Automatic or unreadable).
function Budget.qualityLevel(f: BootFacts): number?
	local S = P.START
	if f.savedQuality >= 1 and f.savedQuality <= 10 then
		return math.floor(f.savedQuality)
	end
	if f.renderQuality >= 1 and f.renderQuality <= S.RENDER_LEVELS then
		return math.clamp(math.ceil(f.renderQuality * 10 / S.RENDER_LEVELS), 1, 10)
	end
	return nil
end

-- The tier a client starts at from its boot facts (1 .. START.MAX).
function Budget.startTier(f: BootFacts): number
	local S = P.START
	local tier = S.DEVICE[f.device] or S.DEVICE.other
	local q = Budget.qualityLevel(f)
	if q then
		if q <= S.QUALITY_LOW_MAX then
			tier = math.max(tier, 3)
		elseif q <= S.QUALITY_MID_MAX then
			tier = math.max(tier, 2)
		elseif q >= S.QUALITY_HIGH_MIN then
			tier = 1 -- a player who set high quality by hand has the device for it
		end
	elseif f.device == "phone" and f.viewportMin > 0 and f.viewportMin < S.SMALL_SCREEN_MIN then
		tier += 1
	end
	return math.clamp(tier, 1, S.MAX)
end

-- The start tier after the loading-card probe. It only ever lowers quality (cheap card frames that are slow
-- say a lot; fast ones say little about a heist view) and never past START.MAX.
function Budget.probeTier(tier: number, probe: Probe?): number
	local S = P.START
	local start = clampTier(tier)
	if not probe or probe.frames < S.PROBE_MIN_FRAMES then
		return start
	end
	local lower = 0
	if probe.medianMs > S.PROBE_VERY_SLOW_MEDIAN_MS then
		lower = 2
	elseif probe.p95Ms > S.PROBE_SLOW_P95_MS then
		lower = 1
	end
	return math.max(start, math.min(start + lower, S.MAX))
end

-- Measured view counts against a tier: a list of "what: measured > budget" lines (empty = within budget).
-- `m` holds any of: drawCalls, tris, lights, shadowed, liveParticles, highlights.
function Budget.over(tier: number, m: { [string]: number }): { string }
	local t: any = Budget.forTier(tier)
	local out = {}
	for _, key in { "drawCalls", "tris", "lights", "shadowed", "liveParticles", "highlights" } do
		local v = m[key]
		if v ~= nil and v > t[key] then
			table.insert(out, string.format("%s: %d > %d", key, v, t[key]))
		end
	end
	return out
end

return table.freeze(Budget)
