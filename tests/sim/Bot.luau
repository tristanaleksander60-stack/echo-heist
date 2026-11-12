-- Scripted test player for the L2 sim specs (not a spec itself).
-- A bot is a client: it walks at WalkSpeed with "physics-lite" collisions (static
-- solids and doors that LOOK shut to it), sends its position every tick and its
-- intents as requests. With `delay` ticks of one-way latency its samples and
-- intents reach the sim `delay` ticks late, and it sees the server's door/laser
-- state `delay` ticks late (plus the one tick the server has not run yet), drawn
-- with the client's 0.2 s visual lead (Mechanisms.doorViewOf/laserViewOf).
--
-- Script steps (one runs at a time, in order):
--   {go = {x, z}, timeout = s?, giveUp = s?}   {goPlate = id} {goLoot = id} {goVan = true}
--   {goSwitch = id} {goHide = id} walk there (stop at the target)
--   {wait = s} {waitUntil = t}    stand (client loop time)
--   {waitFor = fn(bot, view, t) -> bool}
--   {grab = id} {press = id} {release = true} {hide = id} {emote = n}   send an intent
--   {endRun = true}               END RUN (as soon as the button unlocks)
--   {stay = true}                 stand for the rest of the run
--   {decide = fn(bot, sim, view, t) -> {steps}}  insert the returned steps next
--                                 (reactive bots such as the naive kid)
-- `timeout` ends a walk after that long; `giveUp` ends it once the bot has made no
-- progress (< 0.5 studs) for that long (bumping into a shut door).

local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local Geom = require("../../src/shared/Sim/Geom")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Mechanisms = require("../../src/shared/Sim/Mechanisms")

local KIND = Codec.EVENT
local Bot = {}
Bot.__index = Bot

local DT = 1 / Config.Rec.HZ

function Bot.new(level: any, playerId: number, steps: { any }, opts: any?)
	local o = opts or {}
	local self = setmetatable({}, Bot)
	self.level = level
	self.id = playerId
	self.steps = table.clone(steps)
	self.delay = o.delay or 0
	self.speed = o.speed or Config.Rec.WALK_SPEED
	self.i = 1
	self.stepStart = 0
	self.out = {}
	self.x, self.y, self.z, self.yaw = 0, level.rootY, 0, 0
	self.sent = 0
	self.log = {} -- {t, what} for test assertions
	self.trace = if o.trace then {} else nil -- per client tick: {t, x0, z0, x, z, view}
	return self
end

-- Called after HeistSim.startRun: the client is at its seat's spawn.
function Bot:start(sim: any)
	local p = sim.playerById[self.id]
	local spawn = self.level.spawns[(p.seat - 1) % #self.level.spawns + 1]
	self.x, self.y, self.z, self.yaw = spawn.x, spawn.y, spawn.z, spawn.yaw
	self.i = 1
	self.stepStart = 0
	table.clear(self.out)
	table.clear(self.log)
	if self.trace then
		table.clear(self.trace)
	end
end

local function target(level: any, step: any): (number?, number?)
	if step.go then
		return step.go[1], step.go[2]
	elseif step.goPlate then
		local x, _, z = Geom.center(level.plates[LevelSpec.indexOf(level, "plate", step.goPlate)].box)
		return x, z
	elseif step.goLoot then
		local d = level.loot[LevelSpec.indexOf(level, "loot", step.goLoot)]
		return d.x, d.z
	elseif step.goSwitch then
		local d = level.switches[LevelSpec.indexOf(level, "switch", step.goSwitch)]
		return d.x, d.z
	elseif step.goHide then
		local x, _, z = Geom.center(level.hides[LevelSpec.indexOf(level, "hide", step.goHide)].box)
		return x, z
	elseif step.goVan then
		local x, _, z = Geom.center(level.van)
		return x, z
	end
	return nil, nil
end

-- A character is not a point: its body keeps the root ACTOR_RADIUS from walls and
-- doors (so the server's thin-box checks on 1/16-stud samples never fire on a legit
-- move). Grown boxes are cached per level.
local fat: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any

local function grown(level: any): any
	local g = fat[level]
	if not g then
		local r = Config.Sim.ACTOR_RADIUS
		g = { solids = {}, doors = {} }
		for i, b in level.solids do
			g.solids[i] = { Geom.expand(b, r, 0), b }
		end
		for i, d in level.doors do
			g.doors[i] = { Geom.expand(d.box, r, 0), d.box }
		end
		fat[level] = g
	end
	return g
end

-- Does the client's own physics stop the move? (static solids + doors it sees shut)
function Bot.blocked(level: any, view: any, tView: number, x0: number, z0: number, x1: number, z1: number): boolean
	local y = level.rootY
	local g = grown(level)
	-- Grown box: the body keeps its distance. Thin box: a body caught inside the grown
	-- box (a door shut on it) can only back out, never push further in.
	local function hits(pair: any): boolean
		return Geom.moveBlocked(pair[1], x0, y, z0, x1, y, z1) or Geom.moveBlocked(pair[2], x0, y, z0, x1, y, z1)
	end
	for _, pair in g.solids do
		if hits(pair) then
			return true
		end
	end
	if view then
		for i, pair in g.doors do
			if Mechanisms.doorViewOf(view.doors[i], tView) == "shut" and hits(pair) then
				return true
			end
		end
	end
	return false
end

function Bot:walk(view: any, tView: number, tx: number, tz: number): boolean
	local dx, dz = tx - self.x, tz - self.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-3 then
		return true
	end
	local s = math.min(d, self.speed * DT)
	-- Stay on the recording grid (1/16 stud), so the bot's collision checks start
	-- from exactly the sample the server records.
	local nx, nz = Codec.snapPos(self.x + dx / d * s), Codec.snapPos(self.z + dz / d * s)
	local level = self.level
	if not Bot.blocked(level, view, tView, self.x, self.z, nx, nz) then
		self.x, self.z = nx, nz
	elseif not Bot.blocked(level, view, tView, self.x, self.z, nx, self.z) and math.abs(nx - self.x) > 1e-4 then
		self.x = nx
	elseif not Bot.blocked(level, view, tView, self.x, self.z, self.x, nz) and math.abs(nz - self.z) > 1e-4 then
		self.z = nz
	end
	self.yaw = Geom.yawTo(0, 0, dx, dz, self.yaw)
	return d <= s + 1 / 32
end

function Bot:send(deliver: number, item: any)
	table.insert(self.out, { at = deliver, item = item })
end

local function intent(level: any, step: any): (number?, number?)
	if step.grab then
		return KIND.Grab, LevelSpec.indexOf(level, "loot", step.grab)
	elseif step.press then
		return KIND.Press, LevelSpec.indexOf(level, "switch", step.press)
	elseif step.release then
		return KIND.Release, 0
	elseif step.hide then
		return KIND.Hide, LevelSpec.indexOf(level, "hide", step.hide)
	elseif step.emote then
		return KIND.Emote, step.emote
	end
	return nil, nil
end

-- One client tick, before the sim runs tick `sim.nextTick`. `view` is the server
-- state this client has received (Harness history), or nil.
function Bot:tick(sim: any, view: any)
	local k = sim.nextTick
	local t = k * DT
	local step = self.steps[self.i]
	local x0, z0 = self.x, self.z
	if step then
		local done = false
		local tx, tz = target(self.level, step)
		if tx then
			done = self:walk(view, t, tx :: number, tz :: number)
			if step.timeout and t - self.stepStart >= step.timeout then
				done = true
			end
			if step.giveUp then
				local px, pz = self.progressX or self.x, self.progressZ or self.z
				if (self.x - px) ^ 2 + (self.z - pz) ^ 2 > 0.25 or self.progressT == nil then
					self.progressX, self.progressZ, self.progressT = self.x, self.z, t
				elseif t - self.progressT >= step.giveUp then
					done = true
				end
			end
		elseif step.wait then
			done = t - self.stepStart >= step.wait - 1e-9
		elseif step.waitUntil then
			done = t >= step.waitUntil - 1e-9
		elseif step.waitFor then
			done = step.waitFor(self, view, t)
		elseif step.endRun then
			if t >= Config.Rec.END_RUN_LOCK_SECONDS then
				self:send(k + self.delay, { endRun = true })
				done = true
			end
		elseif step.stay then
			done = false
		elseif step.decide then
			local more = step.decide(self, sim, view, t)
			for j = #more, 1, -1 do
				table.insert(self.steps, self.i + 1, more[j])
			end
			done = true
		else
			local kind, arg = intent(self.level, step)
			if kind then
				self:send(k + self.delay, { kind = kind, arg = arg })
				table.insert(self.log, { t = t, what = "intent" })
			end
			done = true
		end
		if done then
			self.i += 1
			self.stepStart = t
			self.progressT = nil
		end
	end
	if self.trace then
		table.insert(self.trace, { t = t, x0 = x0, z0 = z0, x = self.x, z = self.z, view = view })
	end
	self:send(k + self.delay, { x = self.x, y = self.y, z = self.z, yaw = self.yaw })
	-- Deliver what has arrived by now (FIFO).
	local keep = {}
	for _, m in self.out do
		if m.at <= k then
			local it = m.item
			if it.x then
				HeistSim.setInput(sim, self.id, it.x, it.y, it.z, it.yaw, Codec.FLAG.GROUNDED)
			elseif it.endRun then
				HeistSim.endRun(sim, self.id)
			else
				HeistSim.request(sim, self.id, it.kind, it.arg)
			end
		else
			table.insert(keep, m)
		end
	end
	self.out = keep
end

function Bot:finished(): boolean
	return self.steps[self.i] == nil or self.steps[self.i].stay == true
end

return Bot
