--!strict
-- Shared/Heist/MomentPlan: the pure maths of the signature moments (PLAN_STEAM_PLUS §4.4 F1-F5,
-- §4.2 C3, §5; client Heist/MomentDirector, Heist/RewindDirector, Heist/LineupDirector). No engine
-- calls and no requires, so tests/unit/HeistMoments.spec.luau runs it in Lune; callers pass the
-- Config.Moments numbers in. Vectors are plain { x, y, z }; angles are degrees.
--   * rollCall / choirAt: the 8 OF ME roll call, one beat per copy, `stagger` apart in record order.
--   * frame: the camera distance and focus that put every point inside the central `share` of the
--     frame width (9:16-safe, premium H3) for a yaw, pitch, FOV and aspect, in closed form.
--   * trailTimes / sampleTrail / trailHead: a clone's path sampled from its recording, and how much
--     of it is still drawn while the rewind reels it back.
--   * pickBlooper / blooperWindow: the blooper cut's clone (MASTERPLAN §9.2 #2) and its window.
--   * flashAllowed / grantParticles / rainCount: the juice governor.
--   * podium: the Line-up with busted clones on a separate podium (premium §6.7).
--   * ease / blend: the moments' eases (Sine InOut in and out, premium H1).

local MomentPlan = {}

export type V3 = { number }

local rad = math.rad

---------------------------------------------------------------------------
-- Eases
---------------------------------------------------------------------------

-- Sine InOut, clamped to 0..1.
function MomentPlan.ease(u: number): number
	u = math.clamp(u, 0, 1)
	return -(math.cos(math.pi * u) - 1) / 2
end

-- A take-over's weight at `e` seconds: eases 0 -> 1 over `inS`, holds for `hold`, eases back to 0
-- over `outS`; 0 before and after. `done` is true once it is over.
function MomentPlan.blend(e: number, inS: number, hold: number, outS: number): (number, boolean)
	if e < 0 then
		return 0, false
	end
	if e < inS then
		return MomentPlan.ease(e / math.max(inS, 1e-6)), false
	end
	if e < inS + hold then
		return 1, false
	end
	local o = e - inS - hold
	if o < outS then
		return 1 - MomentPlan.ease(o / math.max(outS, 1e-6)), false
	end
	return 0, true
end

---------------------------------------------------------------------------
-- Roll call (8 OF ME): one pose beat per copy, `stagger` apart in record order
---------------------------------------------------------------------------

-- The beat time (seconds after the event) of each of `n` copies, in record order.
function MomentPlan.rollCall(n: number, stagger: number, start: number): { number }
	local out = {}
	for i = 1, math.max(0, math.floor(n)) do
		out[i] = start + (i - 1) * stagger
	end
	return out
end

-- When the choir hit lands: `gap` after the last beat (or at `start` with no copies).
function MomentPlan.choirAt(n: number, stagger: number, start: number, gap: number): number
	local k = math.max(0, math.floor(n))
	if k == 0 then
		return start
	end
	return start + (k - 1) * stagger + gap
end

---------------------------------------------------------------------------
-- Framing: every point inside the central `share` of the width
---------------------------------------------------------------------------

-- Camera basis for a yaw (about +Y, 0 looks down -Z) and a downward pitch (Heist/CameraMath's
-- conventions): forward, right, up.
function MomentPlan.basis(yawDeg: number, pitchDeg: number): (V3, V3, V3)
	local y, p = rad(yawDeg), rad(pitchDeg)
	local c = math.cos(p)
	local f = { -math.sin(y) * c, -math.sin(p), -math.cos(y) * c }
	local r = { math.cos(y), 0, -math.sin(y) }
	local u = {
		r[2] * f[3] - r[3] * f[2],
		r[3] * f[1] - r[1] * f[3],
		r[1] * f[2] - r[2] * f[1],
	}
	return f, r, u
end

local function dot(a: V3, b: V3): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

-- The focus and distance of a camera (yaw, pitch, vertical FOV, aspect = width / height) that fits
-- every point inside `share` of the half width and `shareY` of the half height (normalised screen
-- space, -1..1), clamped to [minD, maxD]. The focus is the centre of the points' box across the
-- view, so the crowd sits in the middle of the frame. `fits` is false when even maxD cannot hold
-- them (the caller still gets maxD). Closed form: for a point at (r, u, f) from the focus, the
-- camera at distance d sees it at depth d + f, so |r| <= share * tan(fov / 2) * aspect * (d + f).
function MomentPlan.frame(
	points: { V3 },
	yawDeg: number,
	pitchDeg: number,
	fovDeg: number,
	aspect: number,
	share: number,
	shareY: number,
	minD: number,
	maxD: number
): (V3, number, boolean)
	if #points == 0 then
		return { 0, 0, 0 }, minD, true
	end
	local f, r, u = MomentPlan.basis(yawDeg, pitchDeg)
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, p in points do
		local c = { dot(p, r), dot(p, u), dot(p, f) }
		for k = 1, 3 do
			lo[k] = math.min(lo[k], c[k])
			hi[k] = math.max(hi[k], c[k])
		end
	end
	-- Focus: the centre of the box in camera coordinates, back in world space.
	local cr, cu, cf = (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2
	local focus = {
		r[1] * cr + u[1] * cu + f[1] * cf,
		r[2] * cr + u[2] * cu + f[2] * cf,
		r[3] * cr + u[3] * cu + f[3] * cf,
	}
	local tv = math.tan(rad(fovDeg) / 2)
	local sx = math.max(share * tv * aspect, 1e-6)
	local sy = math.max(shareY * tv, 1e-6)
	local need = minD
	for _, p in points do
		local dr = dot(p, r) - cr
		local du = dot(p, u) - cu
		local df = dot(p, f) - cf
		need = math.max(need, math.abs(dr) / sx - df, math.abs(du) / sy - df, 0.5 - df)
	end
	if need > maxD then
		return focus, maxD, false
	end
	return focus, need, true
end

-- Where a point lands in normalised screen space (-1..1 both ways, +y up) for a camera orbiting
-- `focus` at `distance` (the frame's own projection, for checks); depth <= 0 is behind the camera.
function MomentPlan.project(
	focus: V3,
	distance: number,
	yawDeg: number,
	pitchDeg: number,
	fovDeg: number,
	aspect: number,
	point: V3
): (number, number, number)
	local f, r, u = MomentPlan.basis(yawDeg, pitchDeg)
	local d = { point[1] - focus[1], point[2] - focus[2], point[3] - focus[3] }
	local depth = distance + dot(d, f)
	if depth <= 1e-6 then
		return 0, 0, depth
	end
	local tv = math.tan(rad(fovDeg) / 2)
	return dot(d, r) / (depth * tv * aspect), dot(d, u) / (depth * tv), depth
end

---------------------------------------------------------------------------
-- Path trails (the rewind): sampled from a recording, reeled back with the scrub
---------------------------------------------------------------------------

-- `count` sample times spread evenly over [0, duration] (one point when the run is empty).
function MomentPlan.trailTimes(duration: number, count: number): { number }
	local n = math.max(1, math.floor(count))
	local out = {}
	if duration <= 0 or n == 1 then
		out[1] = 0
		return out
	end
	for i = 1, n do
		out[i] = duration * (i - 1) / (n - 1)
	end
	return out
end

export type TrailPoint = { t: number, x: number, y: number, z: number }

-- The path through `at(t) -> (x?, y, z)` (Rec/Sampler.at) at trailTimes; samples `at` returns nil
-- for are skipped.
function MomentPlan.sampleTrail(
	at: (t: number) -> (number?, number, number),
	duration: number,
	count: number
): { TrailPoint }
	local out: { TrailPoint } = {}
	for _, t in MomentPlan.trailTimes(duration, count) do
		local x, y, z = at(t)
		if x then
			table.insert(out, { t = t, x = x, y = y, z = z })
		end
	end
	return out
end

-- While the rewind reels a clone back to time `head`, the drawn path is its start up to `head`:
-- returns the last whole point index k (points[k].t <= head) and the share (0..1) of the segment
-- k -> k + 1 still drawn. 0 when the head is before the first point.
function MomentPlan.trailHead(points: { TrailPoint }, head: number): (number, number)
	local n = #points
	if n == 0 or head < points[1].t then
		return 0, 0
	end
	for k = 1, n - 1 do
		local a, b = points[k].t, points[k + 1].t
		if head < b then
			return k, if b > a then (head - a) / (b - a) else 0
		end
	end
	return n, 0
end

---------------------------------------------------------------------------
-- The blooper cut (MASTERPLAN §9.2 #2 "MY CLONE BETRAYED ME")
---------------------------------------------------------------------------

export type Failure = { id: number, owner: number, kind: string, t: number, run: number? }

-- The clone failure to replay: your own clones first, then the heavier kind (weights, e.g.
-- Busted 3 > Zapped 2 > Stuck 1; unknown kinds never), then the latest. nil when there is none.
function MomentPlan.pickBlooper(fails: { Failure }, myId: number, weights: { [string]: number }): Failure?
	local best: Failure? = nil
	local bestKey = { -1, -1, -math.huge }
	for _, f in fails do
		local w = weights[f.kind]
		if w and w > 0 then
			local key = { if f.owner == myId then 1 else 0, w, f.t }
			local better = false
			for k = 1, 3 do
				if key[k] ~= bestKey[k] then
					better = key[k] > bestKey[k]
					break
				end
			end
			if better then
				best, bestKey = f, key
			end
		end
	end
	return best
end

-- The replay window for a failure at `t`: `lead` seconds before it (never before 0) to `tail`
-- after, never longer than `max` in all (the tail gives way first).
function MomentPlan.blooperWindow(t: number, lead: number, tail: number, max: number): (number, number)
	local from = math.max(0, t - lead)
	local to = t + tail
	if to - from > max then
		to = from + max
		if to < t then
			from = t - max
			to = t
		end
	end
	return from, to
end

---------------------------------------------------------------------------
-- The juice governor
---------------------------------------------------------------------------

-- Full-screen flashes: at most `max` in any `window` seconds. `log` holds the times of the
-- flashes allowed so far (pruned here); returns true (and logs it) when this one may play.
function MomentPlan.flashAllowed(log: { number }, now: number, max: number, window: number): boolean
	local i = 1
	while i <= #log do
		if now - log[i] >= window then
			table.remove(log, i)
		else
			i += 1
		end
	end
	if #log >= max then
		return false
	end
	table.insert(log, now)
	return true
end

export type Burst = { n: number, ends: number }

-- Particles: `ledger` holds the live bursts (count, when the last of them dies). Grants up to
-- `want` so the live total stays <= cap, logs the grant (alive for `lifetime` s) and returns it.
function MomentPlan.grantParticles(ledger: { Burst }, now: number, want: number, cap: number, lifetime: number): number
	local live = 0
	local i = 1
	while i <= #ledger do
		if ledger[i].ends <= now then
			table.remove(ledger, i)
		else
			live += ledger[i].n
			i += 1
		end
	end
	local n = math.clamp(math.floor(want), 0, math.max(0, cap - live))
	if n > 0 then
		table.insert(ledger, { n = n, ends = now + lifetime })
	end
	return n
end

-- Gold rain particles in all for a performance tier: `full` below `lowTier`, `low` from it, both
-- times the tier's particle scale (Config.Heist / HeistClient state.particleScale), at least 1.
function MomentPlan.rainCount(full: number, low: number, tier: number, lowTier: number, scale: number): number
	local base = if tier >= lowTier then low else full
	return math.max(1, math.floor(base * math.clamp(scale, 0, 1) + 0.5))
end

-- Burst sizes that add up to `total` over `bursts` bursts (the earlier ones take the remainder).
function MomentPlan.split(total: number, bursts: number): { number }
	local k = math.max(1, math.floor(bursts))
	local each = math.floor(total / k)
	local rest = total - each * k
	local out = {}
	for i = 1, k do
		out[i] = each + (if i <= rest then 1 else 0)
	end
	return out
end

---------------------------------------------------------------------------
-- The Line-up's busted podium (premium §6.7)
---------------------------------------------------------------------------

export type Slot = { across: number, back: number, podium: boolean }

-- Row-local places for the Line-up's figures (record order kept): the crew (busted[i] false) in rows
-- of `rowLen`, `spacing` apart; the busted ones in a row of their own `gap` past the crew's right end
-- (across +), on the podium. The whole group is centred on across = 0; rows go back from back = 0.
function MomentPlan.podium(busted: { boolean }, rowLen: number, spacing: number, gap: number): { Slot }
	local kept, out = 0, {}
	local nKept, nBusted = 0, 0
	for _, b in busted do
		if b then
			nBusted += 1
		else
			nKept += 1
		end
	end
	local row = math.max(1, math.floor(rowLen))
	local keptWidth = (math.min(nKept, row) - 1) * spacing
	local bustedWidth = (math.min(nBusted, row) - 1) * spacing
	local left = -keptWidth / 2
	local podiumLeft = keptWidth / 2 + gap
	if nKept == 0 then
		podiumLeft = -bustedWidth / 2
	end
	-- Centre the whole group (crew + gap + podium) on 0.
	local total = if nKept > 0 and nBusted > 0
		then keptWidth + gap + bustedWidth
		else if nKept > 0 then keptWidth else bustedWidth
	local shift = if nKept > 0 and nBusted > 0 then -(left + total / 2) else 0
	local bi = 0
	for i, b in busted do
		if b then
			local k = bi
			bi += 1
			local col, line = k % row, math.floor(k / row)
			out[i] = { across = podiumLeft + col * spacing + shift, back = line * spacing, podium = true }
		else
			local k = kept
			kept += 1
			local col, line = k % row, math.floor(k / row)
			local inRow = math.min(nKept - line * row, row)
			local rowLeft = -((inRow - 1) * spacing) / 2
			out[i] = { across = rowLeft + col * spacing + shift, back = line * spacing, podium = false }
		end
	end
	return out
end

return table.freeze(MomentPlan)
