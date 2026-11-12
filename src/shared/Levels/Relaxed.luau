--!strict
-- Levels/Relaxed: the Relaxed version of a story level (PLAN_STEAM_PLUS §6.1 item 5, MASTERPLAN
-- §3.1, WALKTHROUGH P0-2). It is a level modifier on the spec, the same path as the daily vault
-- modifiers (Levels/DailyVaults.apply): a fresh copy of the spec with
--   * `relaxed = true` (LevelSpec.compile keeps it; Sim/HeistSim then makes runs +50%,
--     Config.Rec.RELAXED_LENGTH_MULT, and detection x Config.Sim.RELAXED_DETECT_MULT),
--   * every guard slower (Config.Onboarding.RELAXED_GUARD_SPEED_MULT; HeistSim slows his Alarm Run
--     chase by the same share),
--   * no Diamond medal (Data/Progress.evaluate reads the result's `relaxed` flag).
-- Server and client compile the same relaxed spec (Heist/Protocol.levelSpec), so the sim stays a
-- pure function of the level: determinism holds. Relaxed runs earn every Star but stay off the
-- boards (Data/Progress, Data/DailyVault).
-- Only story levels: a party has no par to relax and its till is the getaway. The server offers
-- it after Config.Sim.RELAXED_OFFER_BUSTS catches in one heist (HeistSim.offerRelaxed).

local Config = require("../Config")

local Relaxed = {}

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

-- Can this spec be relaxed? (story levels only)
function Relaxed.canApply(spec: any): boolean
	return type(spec) == "table" and (spec.kind or "story") == "story" and spec.relaxed ~= true
end

-- A fresh relaxed copy of a story level's spec (the spec itself is never changed). A spec that
-- is already relaxed comes back as a copy, unchanged.
function Relaxed.apply(spec: any): any
	assert((spec.kind or "story") == "story", "Relaxed.apply: story levels only (" .. tostring(spec.id) .. ")")
	local s = deepCopy(spec)
	if spec.relaxed == true then
		return s
	end
	s.relaxed = true
	local mult = Config.Onboarding.RELAXED_GUARD_SPEED_MULT
	for _, g in s.guards or {} do
		g.speed = (g.speed or Config.Sim.GUARD_SPEED) * mult
	end
	return s
end

return table.freeze(Relaxed)
