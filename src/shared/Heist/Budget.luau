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
