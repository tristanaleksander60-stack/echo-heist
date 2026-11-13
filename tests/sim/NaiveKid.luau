-- "Naive kid" bots for the L2 specs (not a spec itself). MASTERPLAN §4.1, §7.5:
-- a wandering, non-planning player must still get a clone, a bank and a laugh
-- within 2 runs on L1 and within 3 runs on L2-L4.
--
-- The kid wanders between things that catch the eye (glittering loot x3, glowing
-- plates x2, doors, random spots), lingers, grabs whatever is in reach, heads for
-- the van when carrying (the gold chevrons), gives up on a walk once it stops
-- making progress (a shut door), and sometimes taps END RUN. On L1 it obeys the
-- stuck hint at 16 s (§7.5: re-pulse, beam, Mentor tape): while the auto-end is armed
-- (run 1, or later if run 1 ended off the plate) it goes to stand on the plate, after
-- that it goes for the cash. Seeded, so every kid is
-- reproducible.
-- Value-seeking variant (opts.greedy): loot catches the eye in proportion to its value
-- (the till over a candy bar), and with opts.topFirst the kid's first act of run 1 is
-- to go for the top loot (the till / gold) and try to grab it.
-- PLAN_STEAM_PLUS §8.4 adds two more kids (opts.kind):
--   "greedy"    goes straight for the most valuable loot left, every decision, and tries the
--               next one when a shut door stops it; never stands on a plate on purpose.
--   "confused"  ignores plates, spams REWIND (a few seconds into every run) and walks into Gus.
-- tests/sim/HelpBots.spec.luau plays all three against the help rules (Shared/Heist/Help).
-- These are synthetic stand-ins; real "naive" recordings from kid wave 1 replace
-- them (levels/<id>.naive/*.bin, §8.4).

local Bot = require("./Bot")
local Config = require("../../src/shared/Config")
local Geom = require("../../src/shared/Sim/Geom")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Mechanisms = require("../../src/shared/Sim/Mechanisms")

local NaiveKid = {}

-- A kid walks to what it sees, around walls: when a wall stands between it and the spot (seen
-- through a window, L1's cash), it takes the shortest way round on a 1-stud grid (BFS over the
-- level's solids grown by the body's radius; a shut door in `view` at `t` is a wall, `view` nil
-- counts every doorway as open), then cuts the corners it can see past. Waypoints { {x, z} }, the
-- spot last; just the spot when the way is clear or there is no way round.
local CELL = 1
local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

function NaiveKid.route(
	level: any,
	view: any,
	t: number,
	x0: number,
	z0: number,
	tx: number,
	tz: number
): { { number } }
	local function clear(ax: number, az: number, bx: number, bz: number): boolean
		return not Bot.blocked(level, view, t, ax, az, bx, bz)
	end
	if clear(x0, z0, tx, tz) then
		return { { tx, tz } }
	end
	local r = Config.Sim.ACTOR_RADIUS
	local walls = {}
	for _, b in level.solids do
		table.insert(walls, Geom.expand(b, r, 0))
	end
	for i, d in level.doors do
		if view and Mechanisms.doorViewOf(view.doors[i], t) == "shut" then
			table.insert(walls, Geom.expand(d.box, r, 0))
		end
	end
	local b = level.bounds
	local w = math.ceil((b.maxX - b.minX) / CELL)
	local h = math.ceil((b.maxZ - b.minZ) / CELL)
	local y = level.rootY
	local function cellOf(x: number, z: number): number
		local i = math.clamp(math.floor((x - b.minX) / CELL), 0, w - 1)
		local j = math.clamp(math.floor((z - b.minZ) / CELL), 0, h - 1)
		return j * w + i
	end
	local function centre(id: number): (number, number)
		return b.minX + (id % w + 0.5) * CELL, b.minZ + (math.floor(id / w) + 0.5) * CELL
	end
	local function free(x: number, z: number): boolean
		for _, box in walls do
			if Geom.inside(box, x, y, z) then
				return false
			end
		end
		return true
	end
	-- Distances from the spot outward, until the kid's cell is reached.
	local goal, start = cellOf(tx, tz), cellOf(x0, z0)
	local dist: { [number]: number } = { [goal] = 0 }
	local queue, head = { goal }, 1
	while head <= #queue and dist[start] == nil do
		local id = queue[head]
		head += 1
		local i, j = id % w, math.floor(id / w)
		for _, d in DIRS do
			local ni, nj = i + d[1], j + d[2]
			local nid = nj * w + ni
			if ni >= 0 and ni < w and nj >= 0 and nj < h and dist[nid] == nil then
				local cx, cz = centre(nid)
				if nid == start or free(cx, cz) then
					dist[nid] = dist[id] + 1
					table.insert(queue, nid)
				end
			end
		end
	end
	if dist[start] == nil then
		return { { tx, tz } }
	end
	-- Downhill to the spot, then keep only the corners (each waypoint is the farthest path point in sight).
	local path: { { number } } = {}
	local id = start
	while id ~= goal do
		local i, j = id % w, math.floor(id / w)
		for _, d in DIRS do
			local ni, nj = i + d[1], j + d[2]
			local nid = nj * w + ni
			if ni >= 0 and ni < w and nj >= 0 and nj < h and dist[nid] == dist[id] - 1 then
				id = nid
				break
			end
		end
		local cx, cz = centre(id)
		table.insert(path, { cx, cz })
	end
	path[#path] = { tx, tz }
	local out: { { number } } = {}
	local px, pz = x0, z0
	local k = 1
	while k <= #path do
		local far = k
		for m = #path, k, -1 do
			if clear(px, pz, path[m][1], path[m][2]) then
				far = m
				break
			end
		end
		table.insert(out, path[far])
		px, pz = path[far][1], path[far][2]
		k = far + 1
	end
	return out
end

-- `go` steps along NaiveKid.route; timeout and giveUp apply to each leg.
local function walkTo(
	level: any,
	bot: any,
	view: any,
	t: number,
	tx: number,
	tz: number,
	timeout: number?,
	giveUp: number?
): { any }
	local steps = {}
	for _, p in NaiveKid.route(level, view, t, bot.x, bot.z, tx, tz) do
		table.insert(steps, { go = p, timeout = timeout, giveUp = giveUp })
	end
	return steps
end

-- Where a kid's random "let's look over there" spots fall, per location (x0, x1, z0, z1).
NaiveKid.AREAS = {
	CornerShop = { -15, 15, -40, 12 },
	Bank = { -19, 19, -58, 12 },
}

local HINT_AT = 16 -- seconds (the second stuck hint)
local END_TAP = 0.015 -- chance per decision of tapping END RUN for no reason

local function lcg(seed: number): (number, number) -> number
	local s = seed % 2147483648
	return function(lo: number, hi: number): number
		s = (s * 1103515245 + 12345) % 2147483648
		return lo + (hi - lo) * (s / 2147483648)
	end
end

local function interests(level: any, greedy: boolean): { any }
	local out = {}
	for _, d in level.loot do
		-- Greedy: a $15 candy bar weighs 1.5, the $300 till 30 (plates stay at 2).
		local w = if greedy then math.max(1, d.value / 10) else 3
		table.insert(out, { x = d.x, z = d.z, w = w, loot = d.id })
	end
	for _, p in level.plates do
		local x, _, z = Geom.center(p.box)
		table.insert(out, { x = x, z = z, w = 2 })
	end
	for _, d in level.doors do
		local x, _, z = Geom.center(d.box)
		table.insert(out, { x = x, z = z + 2, w = 1 })
	end
	return out
end

-- The top loot (the alarm trigger, else the most valuable item).
local function topLoot(level: any): any
	local best = level.loot[1]
	for _, d in level.loot do
		if d.top or (not best.top and d.value > best.value) then
			best = d
		end
	end
	return best
end

-- The brain for one run: returns a `decide` step. opts = {greedy?, topFirst?}.
function NaiveKid.brain(level: any, seed: number, run: number, opts: any?): any
	local o = opts or {}
	local rnd = lcg(seed * 7919 + run * 104729 + 17)
	local spots = interests(level, o.greedy == true)
	local first = o.topFirst == true and run == 1
	local total = 0
	for _, s in spots do
		total += s.w
	end
	local hinted = false
	local area = NaiveKid.AREAS[level.spec.location] or NaiveKid.AREAS.CornerShop
	local decide
	decide = function(bot: any, sim: any, view: any, t: number): { any }
		local a = HeistSim.liveActor(sim, bot.id)
		if first then
			first = false
			local top = topLoot(level)
			local steps = walkTo(level, bot, view, t, top.x, top.z, 6, 1)
			table.insert(steps, { grab = top.id })
			table.insert(steps, { decide = decide })
			return steps
		end
		if a and a.carrying ~= 0 then
			return { { goVan = true, timeout = 8 }, { wait = rnd(0.2, 1) }, { decide = decide } }
		end
		-- L1's stuck hints (§7.5): run 1 the beam leads to the plate; later runs the
		-- glitter and the gold chevrons lead to the cash.
		local hint = level.tutorial and level.tutorial.autoEnd
		if hint and t >= HINT_AT and not hinted then
			hinted = true
			-- The plate hints run while the auto-end is armed (run 1, and any later run
			-- until a clone stands on the plate: LevelSpec untilDone).
			if HeistSim.autoEndArmed(sim) then
				local x, _, z = Geom.center(level.plates[hint.plate].box)
				local steps = walkTo(level, bot, view, t, x, z)
				table.insert(steps, { stay = true })
				return steps
			end
			-- The way to the cash leads through the back-room door, shut or not: the kid waits at it
			-- until its clone opens it (view nil: every doorway counts).
			local cash = level.loot[1]
			local steps = walkTo(level, bot, nil, t, cash.x, cash.z)
			table.insert(steps, { grab = cash.id })
			table.insert(steps, { decide = decide })
			return steps
		end
		-- Random END RUN taps (not on L1, where END RUN only pulses on the plate).
		if not hint and t > 3 and rnd(0, 1) < END_TAP then
			return { { endRun = true } }
		end
		-- Pick something interesting (or a random spot near the shop).
		local tx, tz, lootId
		if rnd(0, 1) < 0.2 then
			tx, tz = rnd(area[1], area[2]), rnd(area[3], area[4])
		else
			local pick = rnd(0, total)
			for _, s in spots do
				pick -= s.w
				if pick <= 0 then
					tx, tz, lootId = s.x + rnd(-1, 1), s.z + rnd(-1, 1), s.loot
					break
				end
			end
			tx = tx or spots[1].x
			tz = tz or spots[1].z
		end
		-- L1 shows its cash through the partition window: the kid walks round to it through an open
		-- doorway. Elsewhere (and to other spots) it walks in a line, as the specs were tuned.
		local timeout = rnd(2, 5)
		local steps: { any } = if lootId and level.tutorial
			then walkTo(level, bot, view, t, tx, tz, timeout, 1)
			else { { go = { tx, tz }, timeout = timeout, giveUp = 1 } }
		if lootId then
			table.insert(steps, { grab = lootId })
		end
		table.insert(steps, { wait = rnd(0.2, 2.5) })
		table.insert(steps, { decide = decide })
		return steps
	end
	return { decide = decide }
end

-- Loot still worth going for (at home or dropped), most valuable first.
local function lootByValue(level: any, sim: any): { any }
	local out = {}
	for i, d in level.loot do
		local item = sim.loot.items[i]
		if item and (item.state == "Home" or item.state == "Dropped") then
			table.insert(out, { def = d, x = item.x, z = item.z })
		end
	end
	table.sort(out, function(a: any, b: any): boolean
		return a.def.value > b.def.value
	end)
	return out
end

-- The greedy kid (opts.kind = "greedy"): the most valuable loot first, the next one when a door
-- stops it, the van when carrying; plates only by accident.
function NaiveKid.greedyBrain(level: any, seed: number, run: number): any
	local rnd = lcg(seed * 7349 + run * 50021 + 3)
	local tried: { [string]: boolean } = {}
	local area = NaiveKid.AREAS[level.spec.location] or NaiveKid.AREAS.CornerShop
	local decide
	decide = function(bot: any, sim: any, _view: any, t: number): { any }
		local a = HeistSim.liveActor(sim, bot.id)
		if a and a.carrying ~= 0 then
			return { { goVan = true, timeout = 10 }, { decide = decide } }
		end
		if t > 2 and rnd(0, 1) < END_TAP then
			return { { endRun = true } }
		end
		for _, l in lootByValue(level, sim) do
			if not tried[l.def.id] then
				tried[l.def.id] = true
				return {
					{ go = { l.x, l.z }, timeout = 7, giveUp = 1.5 },
					{ grab = l.def.id },
					{ wait = 0.3 },
					{ decide = decide },
				}
			end
		end
		table.clear(tried) -- everything tried once: wander a bit, then try again
		return {
			{ go = { rnd(area[1], area[2]), rnd(area[3], area[4]) }, timeout = rnd(2, 4), giveUp = 1 },
			{ decide = decide },
		}
	end
	return { decide = decide }
end

-- The confused kid (opts.kind = "confused"): ignores plates, spams REWIND, walks into Gus.
-- `after` (s, default 0): the REWIND spam starts this much later (a kid who first walked in).
function NaiveKid.confusedBrain(level: any, seed: number, run: number, after: number?): any
	local rnd = lcg(seed * 6151 + run * 7919 + 11)
	local area = NaiveKid.AREAS[level.spec.location] or NaiveKid.AREAS.CornerShop
	local rewindAt = (after or 0) + rnd(2, 6)
	local decide
	decide = function(_bot: any, sim: any, _view: any, t: number): { any }
		if t >= rewindAt then
			return { { endRun = true }, { decide = decide } }
		end
		local g = sim.guards[1]
		if g and rnd(0, 1) < 0.7 then
			return { { go = { g.x, g.z }, timeout = 1, giveUp = 0.5 }, { decide = decide } }
		end
		return {
			{ go = { rnd(area[1], area[2]), rnd(area[3], area[4]) }, timeout = rnd(1, 2.5), giveUp = 0.5 },
			{ decide = decide },
		}
	end
	return { decide = decide }
end

-- One run's brain for any kid (opts.kind: nil = naive, "greedy", "confused").
function NaiveKid.brainFor(level: any, seed: number, run: number, opts: any?): any
	local kind = opts and opts.kind
	if kind == "greedy" then
		return NaiveKid.greedyBrain(level, seed, run)
	elseif kind == "confused" then
		return NaiveKid.confusedBrain(level, seed, run)
	end
	return NaiveKid.brain(level, seed, run, opts)
end

-- A Harness plan of `runs` naive runs for player 1 (opts: see NaiveKid.brain).
function NaiveKid.plan(level: any, seed: number, runs: number, opts: any?): any
	local plan = { runs = {} }
	for r = 1, runs do
		table.insert(plan.runs, { [1] = { NaiveKid.brainFor(level, seed, r, opts) } })
	end
	return plan
end

return NaiveKid
