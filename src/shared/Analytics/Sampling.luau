--!strict
-- Analytics/Sampling: sticky per-player sampling, experiment arms and token-bucket budgets
-- (pure; Lune-tested). Vault "Feature Flags and Staged Rollouts" §4: a percentage must be sticky
-- (same player, same answer on every server and session) and salted per flag, so the same few
-- players do not get every rollout first. Never math.random.

local Sampling = {}

Sampling.BUCKETS = 10000 -- bucket 0..9999: 0.01 % resolution

-- FNV-1a 32-bit over the bytes of s (same split multiply as Rec/Codec.hash, exact in doubles).
function Sampling.hash(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = ((h * 403) % 4294967296 + bit32.lshift(h, 24)) % 4294967296
	end
	return h
end

-- Sticky bucket 0..9999 for a player and a salt (the flag or sample name).
function Sampling.bucket(userId: number, salt: string): number
	return Sampling.hash(salt .. ":" .. tostring(math.floor(userId))) % Sampling.BUCKETS
end

-- True for `percent` % of players (0..100, decimals allowed). Raising the percent only adds players.
function Sampling.inPercent(userId: number, salt: string, percent: number): boolean
	if not (percent == percent) or percent <= 0 then
		return false
	end
	if percent >= 100 then
		return true
	end
	return Sampling.bucket(userId, salt) < math.floor(percent * Sampling.BUCKETS / 100 + 0.5)
end

export type Arm = { name: string, weight: number }

-- Parses "base:50,fast:50" (weights are relative, at least one > 0). Names must be in `allowed`
-- when given. Returns nil and a reason on any malformed part.
function Sampling.parseArms(spec: any, allowed: { string }?): ({ Arm }?, string?)
	if type(spec) ~= "string" or spec == "" or #spec > 200 then
		return nil, "empty"
	end
	local arms: { Arm } = {}
	local total = 0
	local seen = {}
	for _, part in string.split(spec, ",") do
		local name, w = string.match(part, "^%s*([%w_]+)%s*:%s*(%d+%.?%d*)%s*$")
		local weight = if w then tonumber(w) else nil
		if not name or not weight then
			return nil, "shape"
		end
		if seen[name] then
			return nil, "duplicate"
		end
		if allowed and table.find(allowed, name) == nil then
			return nil, "arm"
		end
		seen[name] = true
		total += weight
		table.insert(arms, { name = name, weight = weight })
	end
	if total <= 0 or #arms > 8 then
		return nil, "weights"
	end
	return arms, nil
end

-- The sticky arm for a player (weights relative). Changing weights moves the fewest players
-- possible only when arms are appended; document experiment changes as new salts.
function Sampling.arm(userId: number, salt: string, arms: { Arm }): string
	local total = 0
	for _, a in arms do
		total += a.weight
	end
	local point = Sampling.bucket(userId, salt) / Sampling.BUCKETS * total
	local acc = 0
	for _, a in arms do
		acc += a.weight
		if point < acc then
			return a.name
		end
	end
	return arms[#arms].name
end

---------------------------------------------------------------------------
-- Token bucket (clock injected: seconds from any monotonic source)
---------------------------------------------------------------------------

export type Budget = { capacity: number, perSecond: number, tokens: number, at: number }

function Sampling.newBudget(capacity: number, perSecond: number, now: number): Budget
	assert(capacity >= 1 and perSecond >= 0, "Sampling.newBudget: bad budget")
	return { capacity = capacity, perSecond = perSecond, tokens = capacity, at = now }
end

local function refill(b: Budget, now: number)
	if now > b.at then
		b.tokens = math.min(b.capacity, b.tokens + (now - b.at) * b.perSecond)
	end
	b.at = math.max(b.at, now)
end

-- Takes n tokens (default 1) if available. A clock that moves backwards never refills.
function Sampling.take(b: Budget, now: number, n: number?): boolean
	refill(b, now)
	local cost = n or 1
	if b.tokens >= cost then
		b.tokens -= cost
		return true
	end
	return false
end

function Sampling.tokens(b: Budget, now: number): number
	refill(b, now)
	return b.tokens
end

-- Changes the refill rate (the server budget grows with the player count).
function Sampling.setRate(b: Budget, now: number, perSecond: number)
	refill(b, now)
	b.perSecond = math.max(0, perSecond)
end

return table.freeze(Sampling)
