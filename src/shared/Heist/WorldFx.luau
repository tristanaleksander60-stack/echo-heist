--!strict
-- Heist/WorldFx: the maths behind the world-side feedback (docs/FEEDBACK_TABLE.md, PLAN_STEAM_PLUS §4.5) that the
-- client's Heist/WorldView draws: springs for the plate sink and the door slide, the loot squash, glint and drop
-- bounce, the van bounce and coin count, the "+$100!" words, the "VAULT n/4" count, the hide-spot outline's
-- distance and the haptics gate. Pure (no engine calls, numbers only): Lune specs run it
-- (tests/unit/HeistWorldFx.spec.luau). Every tuning number comes in from Config.WorldFx / Config.Lighting.

local WorldFx = {}

export type Spring = { hz: number, damping: number }

-- One exact step of a damped spring from (x, v) toward `target` over dt (any dt is stable: the closed form, not
-- an integrator). damping < 1 overshoots once and rings down; >= 1 never overshoots. Returns the new x, v.
function WorldFx.spring(x: number, v: number, target: number, dt: number, s: Spring): (number, number)
	if dt <= 0 then
		return x, v
	end
	local w = 2 * math.pi * math.max(s.hz, 1e-3)
	local z = s.damping
	local e = x - target
	if z < 1 then
		local wd = w * math.sqrt(1 - z * z)
		local decay = math.exp(-z * w * dt)
		local c, sn = math.cos(wd * dt), math.sin(wd * dt)
		local b = (v + z * w * e) / wd
		local e1 = decay * (e * c + b * sn)
		local v1 = decay * (v * c - ((z * w * v + w * w * e) / wd) * sn)
		return target + e1, v1
	end
	-- critically damped (z >= 1 is treated as critical: no overshoot)
	local decay = math.exp(-w * dt)
	local b = v + w * e
	local e1 = decay * (e + b * dt)
	local v1 = decay * (v - w * b * dt)
	return target + e1, v1
end

-- The same spring, but settled: snaps to the target once both the offset and the speed are negligible (so a
-- part that stopped moving is not moved again every frame).
function WorldFx.settle(x: number, v: number, target: number, dt: number, s: Spring, eps: number?): (number, number)
	local x1, v1 = WorldFx.spring(x, v, target, dt, s)
	local tol = eps or 1e-3
	if math.abs(x1 - target) < tol and math.abs(v1) < tol * 10 then
		return target, 0
	end
	return x1, v1
end

-- The overshoot a spring gives a step (share of the step), and when it peaks (s): the specs check the Config.
function WorldFx.overshoot(s: Spring): (number, number)
	local z = s.damping
	if z >= 1 then
		return 0, math.huge
	end
	local w = 2 * math.pi * s.hz
	local root = math.sqrt(1 - z * z)
	return math.exp(-math.pi * z / root), math.pi / (w * root)
end

-- A dropped item's hop: height above its rest after t seconds (cfg = Config.WorldFx.BOUNCE): `hops` arcs, each
-- half as high as the one before, inside `seconds`; 0 before and after.
function WorldFx.bounce(t: number, cfg: { height: number, seconds: number, hops: number }): number
	if t <= 0 or t >= cfg.seconds then
		return 0
	end
	local hops = math.max(1, math.floor(cfg.hops))
	-- arc k lasts in proportion to sqrt(height): durations 1, 1/sqrt2, 1/2 ... normalised to `seconds`
	local total = 0
	for k = 0, hops - 1 do
		total += (0.5 ^ k) ^ 0.5
	end
	local unit = cfg.seconds / total
	local at = t
	for k = 0, hops - 1 do
		local len = unit * (0.5 ^ k) ^ 0.5
		if at < len then
			local u = at / len
			return cfg.height * (0.5 ^ k) * 4 * u * (1 - u)
		end
		at -= len
	end
	return 0
end

-- Squash scale from a spring offset s (s < 0 squashes): Y = 1 + s, X/Z = 1 - s / 2 (volume roughly kept).
function WorldFx.squashScale(s: number): (number, number)
	return math.max(0.2, 1 + s), math.max(0.2, 1 - s / 2)
end

-- The glint beat of loot item `index` at time `now`: one glint per `period`, items staggered by the golden
-- ratio so a row of loot never flashes together. A new beat number = glint now.
function WorldFx.glintBeat(now: number, index: number, period: number): number
	local phase = (index * 0.6180339887) % 1
	return math.floor(now / period + phase)
end

-- Coins in the bank burst: Config.WorldFx.COINS (<= 24) times the tier's particle scale, at least 4.
function WorldFx.coinCount(max: number, particleScale: number?): number
	local n = math.floor(math.min(max, 24) * math.clamp(particleScale or 1, 0, 1) + 0.5)
	return math.clamp(n, math.min(4, max), math.min(max, 24))
end

-- The world pop's words: "+$100!".
function WorldFx.bankText(amount: number): string
	return string.format("+$%d!", math.max(0, math.floor(amount + 0.5)))
end

-- The vault row's count: "VAULT 2/4".
function WorldFx.vaultText(held: number, total: number): string
	return string.format("VAULT %d/%d", math.clamp(held, 0, total), total)
end

-- Distance on the floor (XZ) from a point to a box's footprint (0 inside).
function WorldFx.footprintDistance(x: number, z: number, box: { [string]: number }): number
	local dx = math.max(box.minX - x, 0, x - box.maxX)
	local dz = math.max(box.minZ - z, 0, z - box.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

export type HapticIn = {
	enabled: boolean, -- Config.WorldFx.HAPTICS
	touch: boolean, -- UserInputService.TouchEnabled
	keyboard: boolean, -- UserInputService.KeyboardEnabled (a touch laptop is not a phone)
	reduced: boolean, -- reduced motion
	setting: any, -- player attribute Setting_Haptics (nil = not set yet: on)
	sinceLast: number, -- s since the last pulse
	minGap: number,
}

-- Haptics only on phones (touch, no keyboard), on by Config, off under reduced motion, off when the player turned
-- them off, and never more often than minGap.
function WorldFx.hapticAllowed(i: HapticIn): boolean
	return i.enabled and i.touch and not i.keyboard and not i.reduced and i.setting ~= false and i.sinceLast >= i.minGap
end

return table.freeze(WorldFx)
