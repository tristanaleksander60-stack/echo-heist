--!strict
-- Sim/Rng: a seeded, portable random source with Roblox Random's method shape
-- (rng:NextNumber(min, max), rng:NextInteger(min, max)). MASTERPLAN §3.2 rule 3:
-- randomness is `Random.new(levelSeed + loopIndex)` inside the sim only, injected,
-- never global. The server may pass `function(seed) return Random.new(seed) end`
-- as HeistSim's `newRandom`; Lune has no Random, so tests and the default use this
-- 32-bit LCG (Numerical Recipes constants). Every product stays below 2^53, so the
-- sequence is bit-identical on every machine.

export type RandomLike = {
	NextNumber: (self: any, min: number?, max: number?) -> number,
	NextInteger: (self: any, min: number, max: number) -> number,
}

local Rng = {}

local MOD = 4294967296 -- 2^32
local A, C = 1664525, 1013904223

function Rng.new(seed: number): RandomLike
	local s = math.floor(seed) % MOD
	-- Warm up so nearby seeds diverge quickly.
	for _ = 1, 4 do
		s = (s * A + C) % MOD
	end
	local function nextUnit(): number
		s = (s * A + C) % MOD
		return s / MOD
	end
	local rng = {}
	function rng.NextNumber(_self: any, min: number?, max: number?): number
		local lo, hi = min or 0, max or 1
		return lo + (hi - lo) * nextUnit()
	end
	function rng.NextInteger(_self: any, min: number, max: number): number
		local lo, hi = math.floor(min), math.floor(max)
		if hi < lo then
			lo, hi = hi, lo
		end
		return lo + math.floor(nextUnit() * (hi - lo + 1))
	end
	return rng :: any
end

return table.freeze(Rng)
