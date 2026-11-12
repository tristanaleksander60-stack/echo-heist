--!strict
-- Sim/Guards: Gus. MASTERPLAN §3.1 (3-stage detection, hiding spots), §3.2 (busted
-- clones, "huh?" freeze), §3.6 (Alarm Run chase), §8.10 rules 1 and 5 (lag rewind).
--
--   * Guards.patrol(route, t) is a pure function of time: a guard who saw nothing
--     walks exactly the same route every loop, so routes are learnable. Stopping
--     ("?" turn, "huh?" freeze) adds to the guard's `offset`; he then resumes from
--     where he stopped (patrol(t - offset)), so a loop where nobody is seen is
--     identical to every other such loop.
--   * Vision: range, cone (half-angle) and line of sight from the eye to the actor's
--     chest against the level's occluder boxes plus doors that are shut. An actor in
--     a hide box is seen only within HIDE_REVEAL_RADIUS.
--   * Detection per (guard, actor): a meter fills while seen and drains while not.
--     > 0 amber, >= ALERT "?" (Gus stops and turns toward the actor), >= CATCH "!".
--     Same rule for players and clones (a clone repeats the player's exact path, so
--     a player who slipped past also has a clone that slips past). Stage times are
--     multiplied per heist (first-heist grace, Relaxed).
--   * Live players are checked against the guard pose and the door state at
--     LoopClock.hazardTime(t, latency), capped at 150 ms (§8.10).
--   * Chase (alarm): each tick Gus targets the nearest actor he can see (all round,
--     line of sight, range), ties by actor id, else the last-seen point; he moves at
--     GUARD_CHASE_SPEED_MULT x WalkSpeed, straight when the way is clear, otherwise
--     along the level's nav graph (A*, ties by node index), and catches on contact.

local Config = require("../Config")
local EventLog = require("./EventLog")
local Geom = require("./Geom")
local LevelSpec = require("./LevelSpec")
local LoopClock = require("../Rec/LoopClock")
local Mechanisms = require("./Mechanisms")

local EV = EventLog.EV
local EPS = 1e-7
local TAU = 2 * math.pi

export type Route = LevelSpec.Route

export type GuardState = {
	index: number,
	def: any,
	mode: string, -- "Patrol" | "Suspicious" | "Huh" | "Chase"
	x: number,
	y: number,
	z: number,
	yaw: number,
	offset: number, -- seconds the patrol clock has been held back
	huhUntil: number,
	focus: number, -- actor id Gus is turning toward ("?"), 0 = none
	meter: { [number]: number }, -- actor id -> seconds of detection
	stage: { [number]: number }, -- actor id -> 0 none, 1 amber, 2 "?"
	target: number, -- chase target actor id (0 = last-seen point / none)
	lastX: number?,
	lastZ: number?,
	tick: number,
	histTick: { number },
	histX: { number },
	histZ: { number },
	histYaw: { number },
}

local Guards = {}

-- Position (x, z) and yaw on a compiled route at patrol time t (any real t; periodic).
function Guards.patrol(route: Route, t: number): (number, number, number)
	local legs = route.legs
	local u = if route.period > 0 then t % route.period else 0
	for _, leg in legs do
		if u < leg.tEnd - EPS or leg == legs[#legs] then
			if u < leg.tArrive then
				local f = if leg.tArrive > leg.tStart then (u - leg.tStart) / (leg.tArrive - leg.tStart) else 1
				f = math.clamp(f, 0, 1)
				return leg.x0 + (leg.x1 - leg.x0) * f, leg.z0 + (leg.z1 - leg.z0) * f, leg.yawWalk
			end
			-- Dwelling at the leg's end: face yawDwell, turning toward the next leg
			-- over the last GUARD_TURN_SECONDS of the dwell.
			local dwell = leg.tEnd - leg.tArrive
			local turn = math.min(Config.Sim.GUARD_TURN_SECONDS, dwell)
			local into = u - (leg.tEnd - turn)
			local yaw = leg.yawDwell
			if turn > 0 and into > 0 then
				local d = Geom.angleDelta(leg.yawDwell, leg.yawNext)
				yaw = (leg.yawDwell + d * math.clamp(into / turn, 0, 1)) % TAU
			end
			return leg.x1, leg.z1, yaw
		end
	end
	local leg = legs[1]
	return leg.x0, leg.z0, leg.yawWalk
end

-- Line of sight between two points against static occluders and doors shut at T.
function Guards.lineOfSight(
	level: any,
	mech: Mechanisms.State?,
	T: number,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number
): boolean
	for _, b in level.occluders do
		if Geom.segmentHitsBox(b, x0, y0, z0, x1, y1, z1) then
			return false
		end
	end
	if mech then
		for i, d in level.doors do
			if Mechanisms.doorSolidAt(mech, i, T) and Geom.segmentHitsBox(d.box, x0, y0, z0, x1, y1, z1) then
				return false
			end
		end
	end
	return true
end

export type Vision = { range: number, cosHalf: number, allRound: boolean }

-- Can a guard at (gx, gz) facing gyaw see an actor root at (ax, ay, az)?
function Guards.canSee(
	level: any,
	mech: Mechanisms.State?,
	T: number,
	vision: Vision,
	gx: number,
	gz: number,
	gyaw: number,
	ax: number,
	ay: number,
	az: number,
	hidden: boolean
): boolean
	local S = Config.Sim
	local dx, dz = ax - gx, az - gz
	local d2 = dx * dx + dz * dz
	if d2 > vision.range * vision.range then
		return false
	end
	if hidden and d2 > S.HIDE_REVEAL_RADIUS * S.HIDE_REVEAL_RADIUS then
		return false
	end
	if not vision.allRound and d2 > 0.25 then
		local fx, fz = Geom.forward(gyaw)
		if (fx * dx + fz * dz) / math.sqrt(d2) < vision.cosHalf - EPS then
			return false
		end
	end
	local gy = level.rootY
	return Guards.lineOfSight(level, mech, T, gx, gy + S.GUARD_EYE_HEIGHT, gz, ax, ay + S.TARGET_HEIGHT, az)
end

function Guards.new(def: any, rootY: number): GuardState
	local H = Config.Sim.LAG_POSE_TICKS
	local g: GuardState = {
		index = def.index,
		def = def,
		mode = "Patrol",
		x = 0,
		y = rootY,
		z = 0,
		yaw = 0,
		offset = 0,
		huhUntil = -1,
		focus = 0,
		meter = {},
		stage = {},
		target = 0,
		lastX = nil,
		lastZ = nil,
		tick = -1,
		histTick = table.create(H, -1),
		histX = table.create(H, 0),
		histZ = table.create(H, 0),
		histYaw = table.create(H, 0),
	}
	Guards.reset(g)
	return g
end

-- Loop start: back on the route at t = 0 (guards reset every loop, §3.1).
function Guards.reset(g: GuardState)
	g.mode = "Patrol"
	g.offset = 0
	g.huhUntil = -1
	g.focus = 0
	table.clear(g.meter)
	table.clear(g.stage)
	g.target = 0
	g.lastX, g.lastZ = nil, nil
	g.tick = -1
	for i = 1, #g.histTick do
		g.histTick[i] = -1
	end
	g.x, g.z, g.yaw = Guards.patrol(g.def.route, 0)
end

local function record(g: GuardState, tick: number)
	local H = #g.histTick
	local slot = tick % H + 1
	g.tick = tick
	g.histTick[slot] = tick
	g.histX[slot] = g.x
	g.histZ[slot] = g.z
	g.histYaw[slot] = g.yaw
end

-- Guard pose at an earlier tick (lag rewind); the oldest kept pose if further back.
function Guards.poseAt(g: GuardState, tick: number): (number, number, number)
	if tick >= g.tick then
		return g.x, g.z, g.yaw
	end
	local H = #g.histTick
	local want = math.max(tick, g.tick - H + 1, 0)
	for k = want, g.tick do
		local slot = k % H + 1
		if g.histTick[slot] == k then
			return g.histX[slot], g.histZ[slot], g.histYaw[slot]
		end
	end
	return g.x, g.z, g.yaw
end

-- Is the straight move clear of static solids and doors shut at T?
local function clear(level: any, mech: Mechanisms.State, T: number, x0: number, z0: number, x1: number, z1: number): boolean
	local y = level.rootY
	for _, b in level.solids do
		if Geom.moveBlocked(b, x0, y, z0, x1, y, z1) then
			return false
		end
	end
	return Mechanisms.doorBlocking(mech, T, x0, y, z0, x1, y, z1) == 0
end

local function nearestNode(level: any, mech: Mechanisms.State, T: number, x: number, z: number): number
	local best, bestD = 0, math.huge
	for i, n in level.nav.nodes do
		local d = Geom.dist2(x, z, n.x, n.z)
		if d < bestD - EPS and clear(level, mech, T, x, z, n.x, n.z) then
			best, bestD = i, d
		end
	end
	return best
end

-- A* over the nav graph; edges through shut doors are skipped. Returns node indices.
function Guards.astar(level: any, mech: Mechanisms.State, T: number, from: number, to: number): { number }?
	local nodes, edges = level.nav.nodes, level.nav.edges
	if from == 0 or to == 0 then
		return nil
	end
	local g: { [number]: number } = { [from] = 0 }
	local came: { [number]: number } = {}
	local closed: { [number]: boolean } = {}
	local goal = nodes[to]
	local function h(i: number): number
		return math.sqrt(Geom.dist2(nodes[i].x, nodes[i].z, goal.x, goal.z))
	end
	for _ = 1, #nodes do
		-- Pick the open node with the lowest f (ties: lowest index), deterministically.
		local cur, curF = 0, math.huge
		for i = 1, #nodes do
			local gi = g[i]
			if gi and not closed[i] then
				local f = gi + h(i)
				if f < curF - EPS then
					cur, curF = i, f
				end
			end
		end
		if cur == 0 then
			return nil
		end
		if cur == to then
			local path = { cur }
			while came[path[1]] do
				table.insert(path, 1, came[path[1]])
			end
			return path
		end
		closed[cur] = true
		for _, e in edges[cur] do
			local blocked = false
			for _, di in e.doors do
				blocked = blocked or Mechanisms.doorSolidAt(mech, di, T)
			end
			if not blocked and not closed[e.to] then
				local ng = g[cur] + e.cost
				if g[e.to] == nil or ng < g[e.to] - EPS then
					g[e.to] = ng
					came[e.to] = cur
				end
			end
		end
	end
	return nil
end

-- One chase step from (x, z) toward (tx, tz) of at most `step` studs.
function Guards.steer(
	level: any,
	mech: Mechanisms.State,
	T: number,
	x: number,
	z: number,
	tx: number,
	tz: number,
	step: number
): (number, number)
	local wx, wz = tx, tz
	if not clear(level, mech, T, x, z, tx, tz) then
		local path = Guards.astar(
			level,
			mech,
			T,
			nearestNode(level, mech, T, x, z),
			nearestNode(level, mech, T, tx, tz)
		)
		if path then
			-- String pulling: the furthest path node in plain sight.
			wx, wz = level.nav.nodes[path[1]].x, level.nav.nodes[path[1]].z
			for k = #path, 1, -1 do
				local n = level.nav.nodes[path[k]]
				if clear(level, mech, T, x, z, n.x, n.z) and Geom.dist2(x, z, n.x, n.z) > 0.01 then
					wx, wz = n.x, n.z
					break
				end
			end
		else
			wx, wz = x, z
		end
	end
	local dx, dz = wx - x, wz - z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < EPS then
		return x, z
	end
	local s = math.min(step, d)
	local nx, nz = x + dx / d * s, z + dz / d * s
	if clear(level, mech, T, x, z, nx, nz) then
		return nx, nz
	end
	-- Slide along whichever axis is free.
	if clear(level, mech, T, x, z, nx, z) then
		return nx, z
	elseif clear(level, mech, T, x, z, x, nz) then
		return x, nz
	end
	return x, z
end

-- Context the sim passes in each tick.
export type Ctx = {
	level: any,
	mech: Mechanisms.State,
	actors: { any },
	log: EventLog.Log,
	tick: number,
	t: number,
	dt: number,
	hz: number,
	alertT: number,
	catchT: number,
	vision: Vision,
	chase: boolean,
	chaseSpeed: number,
	onCatch: (g: GuardState, actor: any) -> (),
}

local function lagged(g: GuardState, ctx: Ctx, a: any): (number, number, number, number)
	if a.kind ~= "live" or (a.latency or 0) <= 0 then
		return g.x, g.z, g.yaw, ctx.t
	end
	local T = LoopClock.hazardTime(ctx.t, a.latency)
	local x, z, yaw = Guards.poseAt(g, LoopClock.tickAt(T, ctx.hz))
	return x, z, yaw, T
end

local function patrolStep(g: GuardState, ctx: Ctx)
	local t, dt = ctx.t, ctx.dt
	if g.mode == "Huh" then
		if t < g.huhUntil - EPS then
			g.offset += dt
			return
		end
		g.mode = "Patrol"
		EventLog.append(ctx.log, ctx.tick, EV.GuardResume, g.index)
	end
	if g.focus ~= 0 then
		local a = ctx.actors[g.focus]
		g.offset += dt
		if a then
			g.yaw = Geom.turnToward(g.yaw, Geom.yawTo(g.x, g.z, a.x, a.z, g.yaw), TAU * dt)
		end
		return
	end
	g.x, g.z, g.yaw = Guards.patrol(g.def.route, t - g.offset)
end

local function detect(g: GuardState, ctx: Ctx)
	if g.mode == "Huh" then
		-- Confused: vision paused, meters drain.
		for _, a in ctx.actors do
			local m = g.meter[a.id]
			if m and m > 0 then
				g.meter[a.id] = math.max(0, m - ctx.dt * Config.Sim.GUARD_METER_DECAY)
			end
		end
		return
	end
	local caught: any = nil
	for _, a in ctx.actors do
		local id = a.id
		local m = g.meter[id] or 0
		local seen = false
		if a.present then
			local gx, gz, gyaw, T = lagged(g, ctx, a)
			seen = Guards.canSee(ctx.level, ctx.mech, T, ctx.vision, gx, gz, gyaw, a.x, a.y, a.z, a.hidden)
		end
		local before = m
		if seen then
			m += ctx.dt
		else
			m = math.max(0, m - ctx.dt * Config.Sim.GUARD_METER_DECAY)
		end
		g.meter[id] = m
		local stage = g.stage[id] or 0
		if before <= 0 and m > 0 then
			EventLog.append(ctx.log, ctx.tick, EV.Spotted, g.index, id)
			stage = 1
		end
		if stage < 2 and m >= ctx.alertT - EPS then
			EventLog.append(ctx.log, ctx.tick, EV.Suspect, g.index, id)
			stage = 2
		end
		if m <= 0 and stage > 0 then
			EventLog.append(ctx.log, ctx.tick, EV.Lost, g.index, id)
			stage = 0
		end
		g.stage[id] = stage
		if caught == nil and a.present and m >= ctx.catchT - EPS then
			caught = a
		end
	end
	if caught then
		g.meter[caught.id] = 0
		g.stage[caught.id] = 0
		if g.focus == caught.id then
			g.focus = 0
		end
		ctx.onCatch(g, caught)
	end
	-- Focus: the most-seen actor at "?" or above (ties: lowest id).
	local focus, best = 0, -1
	for _, a in ctx.actors do
		local m = g.meter[a.id] or 0
		if a.present and m >= ctx.alertT - EPS and m > best + EPS then
			focus, best = a.id, m
		end
	end
	if g.mode ~= "Huh" then
		if focus ~= 0 and g.focus == 0 then
			g.mode = "Suspicious"
		elseif focus == 0 and g.focus ~= 0 then
			g.mode = "Patrol"
			EventLog.append(ctx.log, ctx.tick, EV.GuardResume, g.index)
		end
		g.focus = focus
	end
end

local function chaseStep(g: GuardState, ctx: Ctx)
	local best, bestD = nil, math.huge
	for _, a in ctx.actors do
		if a.present then
			local gx, gz, _, T = lagged(g, ctx, a)
			if Guards.canSee(ctx.level, ctx.mech, T, ctx.vision, gx, gz, 0, a.x, a.y, a.z, a.hidden) then
				local d = Geom.dist2(g.x, g.z, a.x, a.z)
				if d < bestD - EPS then
					best, bestD = a, d
				end
			end
		end
	end
	local targetId = if best then best.id else 0
	if targetId ~= g.target then
		g.target = targetId
		EventLog.append(ctx.log, ctx.tick, EV.Chase, g.index, targetId)
	end
	if best then
		g.lastX, g.lastZ = best.x, best.z
	end
	local step = ctx.chaseSpeed * ctx.dt
	if g.lastX then
		local tx, tz = g.lastX :: number, g.lastZ :: number
		if Geom.dist2(g.x, g.z, tx, tz) <= 0.04 and not best then
			g.lastX, g.lastZ = nil, nil
		else
			local nx, nz = Guards.steer(ctx.level, ctx.mech, ctx.t, g.x, g.z, tx, tz, step)
			if Geom.dist2(nx, nz, g.x, g.z) > EPS then
				g.yaw = Geom.yawTo(g.x, g.z, nx, nz, g.yaw)
			end
			g.x, g.z = nx, nz
		end
	end
	if not g.lastX then
		g.yaw = (g.yaw + Config.Sim.GUARD_SEARCH_TURN * ctx.dt) % TAU
	end
	-- Contact catch (live players against the lag-rewound pose).
	local r2 = Config.Sim.GUARD_CATCH_RADIUS * Config.Sim.GUARD_CATCH_RADIUS
	for _, a in ctx.actors do
		if a.present then
			local gx, gz = lagged(g, ctx, a)
			if Geom.dist2(gx, gz, a.x, a.z) <= r2 and math.abs(a.y - g.y) <= 4 then
				ctx.onCatch(g, a)
			end
		end
	end
end

-- Starts the chase toward a point (the alarm, or a catch in a Big Score).
function Guards.startChase(g: GuardState, x: number, z: number, log: EventLog.Log, tick: number)
	if g.mode == "Chase" then
		return
	end
	g.mode = "Chase"
	g.focus = 0
	g.target = 0
	g.lastX, g.lastZ = x, z
	EventLog.append(log, tick, EV.Chase, g.index, 0)
end

-- "huh?" freeze (after busting a clone).
function Guards.huh(g: GuardState, ctx: Ctx)
	if g.mode == "Chase" then
		return
	end
	g.mode = "Huh"
	g.focus = 0
	g.huhUntil = ctx.t + Config.Sim.GUARD_HUH_SECONDS
	EventLog.append(ctx.log, ctx.tick, EV.GuardHuh, g.index)
end

-- One sim tick for one guard: move, record the pose, then look.
function Guards.update(g: GuardState, ctx: Ctx)
	if g.mode == "Chase" then
		chaseStep(g, ctx)
		record(g, ctx.tick)
		return
	end
	patrolStep(g, ctx)
	record(g, ctx.tick)
	detect(g, ctx)
end

-- Detection stage of one actor for the client meter: 0 none, 1 amber, 2 "?".
function Guards.stageOf(g: GuardState, actorId: number): number
	return g.stage[actorId] or 0
end

return table.freeze(Guards)
