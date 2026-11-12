--!strict
-- Heist/Particles: the one live-particle budget for every client effect (docs/PERF.md §4-5, MASTERPLAN §6.8).
-- Bursts ask here before they emit: the moments (MomentDirector: gold rain), WorldView (coins, door dust, laser
-- sparks, loot glints), EchoView (tape ribbons, sparks, zaps) and GusView (chase dust). Steady emitters report
-- what they keep alive (the backdrop's snow, the loot sparkles), and that comes off the room the bursts get.
-- So the tier's cap (Budget.particleCap: Config.Perf.TIERS liveParticles on touch, Config.Moments PARTICLE_CAP
-- scaled for keyboards) holds at the worst moment (Config.Perf.WORST_MOMENT, Budget.worstParticles), whichever
-- effects fire together. The ledger is Shared/Heist/MomentPlan.grantParticles (pure, unit-tested); no
-- allocation besides one small ledger row per granted burst.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Budget = require(Shared:WaitForChild("Heist"):WaitForChild("Budget"))
local MomentPlan = require(Shared:WaitForChild("Heist"):WaitForChild("MomentPlan"))

local Particles = {}

local ledger: { MomentPlan.Burst } = {}
local steady: { [string]: () -> number } = {}
local tierNow = 1
local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- The runtime performance tier (HeistClient's Telemetry.onTier).
function Particles.setTier(tier: number)
	tierNow = tier
end

-- The live cap at this tier on this device.
function Particles.cap(): number
	return Budget.particleCap(tierNow, touch)
end

-- A steady emitter's report: `fn` returns how many of its particles are alive at most right now (rate x
-- lifetime of the enabled ones); nil removes it. Read only when a burst asks (bursts are events, not frames).
function Particles.setSteady(name: string, fn: (() -> number)?)
	steady[name] = fn
end

-- Particles the steady emitters keep alive.
function Particles.steadyCount(): number
	local n = 0
	for _, fn in steady do
		local ok, v = pcall(fn)
		if ok and type(v) == "number" and v > 0 then
			n += v
		end
	end
	return n
end

-- Grants up to `want` particles living `lifetime` s, so steady + live bursts stay <= the cap; logs the grant.
function Particles.grant(want: number, lifetime: number, now: number?): number
	local room = math.max(0, Particles.cap() - Particles.steadyCount())
	return MomentPlan.grantParticles(ledger, now or os.clock(), want, room, lifetime)
end

-- Emits up to `want` from `e` under the budget (its lifetime: the emitter's longest). Returns what it emitted.
function Particles.emit(e: ParticleEmitter, want: number, now: number?): number
	local n = Particles.grant(want, e.Lifetime.Max, now)
	if n > 0 then
		e:Emit(n)
	end
	return n
end

-- Burst particles alive right now (tests, perf_engine).
function Particles.live(now: number?): number
	local t = now or os.clock()
	local n = 0
	for _, b in ledger do
		if b.ends > t then
			n += b.n
		end
	end
	return n
end

-- Forgets every live burst (tests).
function Particles.reset()
	table.clear(ledger)
end

return Particles
