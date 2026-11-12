--!strict
-- Sim/LevelSpec: the level data format, its validator and its compiler.
-- MASTERPLAN §4.2, §8.4 ("Level/LevelSpec: layout + kit metadata -> LevelData +
-- sim boxes, asserts"), §8.5. Pure Luau. Today the specs are authored directly as
-- sim data (src/shared/Levels/*.luau); when the kit lands (spike S2), the layout
-- reader produces the same table from `levels/<id>.layout.luau` + kit metadata and
-- runs this validator on it.
--
-- Coordinates: level space (studs, relative to the level origin, Y up), within
-- +-Config.Sim.LEVEL_EXTENT so the recording format can hold them. Actors are
-- points at their HumanoidRootPart (floorY + rootHeight on flat floor). Boxes are
-- axis aligned {minX, minY, minZ, maxX, maxY, maxZ}; author them with
-- LevelSpec.box(cx, cy, cz, sx, sy, sz). Yaw/face angles in the spec are degrees.
--
-- Spec (authoring) format, version 1:
--   format = 1, version = n        format version; level content version (bump when
--                                  indices change: recorded event args use them)
--   id = "cs1_back_room"           string id;  num = 101  u16 id in recordings
--   name, location                 display strings
--   dataId = "BackRoom"            optional key of this level in Config.Data.Levels
--                                  (medals, unlocks, trophies; DataService)
--   kind = "story"|"party"         default "story". A party level (Clone Party) never
--                                  completes: the crew steals until Dawn and the haul
--                                  is scored against `tiers` (Haul1..3); it needs a
--                                  Dawn (dawnRuns) and has no `haul`
--   tiers = {1000, 2500, 5000}     party only: ascending $ thresholds; goal defaults
--                                  to tiers[1]
--   runSeconds = 30                run length (<= Config.Rec.LOOP_MAX_SECONDS)
--   par = 1, cap = 3               par clones; level clone cap (teaching: par + 2;
--                                  party 0 / 8; daily vaults a fixed 5)
--   bags = true                    bag levels count here: an actor carries 1 + its
--                                  owner's bag level small items (Clone Party)
--   guardVision = 1                multiplier on every guard's vision range (the
--                                  daily "lights off" modifier), in (0, 2]
--   goal = 100                     banked value that completes the heist (Haul star)
--   haul = nil                     optional higher target; the heist then completes
--                                  at the end of the run that met `goal`, or at once
--                                  when `haul` is banked
--   deadline = "None"|"Dawn"|"Alarm"
--   dawnRuns = nil                 Dawn after this many runs (default for "Dawn":
--                                  max(DAWN_MIN_RUNS, par + DAWN_RUNS_OVER_PAR));
--                                  allowed with "Alarm" too (Clone Party: 8)
--   seed = n                       level seed; run k uses newRandom(seed + k)
--   floorY = 0, rootHeight = 3
--   bounds = box                   the level's extent
--   spawns = {{x, y, z, yaw}}      one per crew seat (wraps if fewer)
--   van = box                      bank zone (entering it with loot banks it)
--   solids = {{id?, box, sight?}}  static movement blockers (walls, counters);
--                                  sight = false for ones Gus sees over (low counters)
--   occluders = {box}              sight-only blockers (glass is neither: leave it out)
--   noGo = {box}                   extra volumes no recording may enter
--   plates = {{id, box}}           trigger volume (include a standing actor's height)
--   switches = {{id, x, y, z, duration?}}  Press toggles; with duration, on for that long
--   doors = {{id, box, openBy = {sourceId}, need = "any"|"all", alarmLock?}}
--                                  box = the solid leaf when shut; sources are plate
--                                  or switch ids
--   lasers = {{id, box, offBy = {sourceId}, need}}  box = the beam volume
--   loot = {{id, x, y, z, value, kind?, top?, heavy?, respawn?, spots?}}
--                                  top = trips the Alarm Run when grabbed;
--                                  heavy = {grips, maxGrips} (format only until Dec 11);
--                                  respawn = seconds after banking (Clone Party), spots =
--                                  {{x, y, z}} chosen with the run's Random
--   hides = {{id, box}}            EH_Hide volumes
--   guards = {{id, speed?, route = {{x, z, wait?, face?}}}}  closed patrol loop; t = 0 at
--                                  route[1]; `wait` = dwell at that point; `face` = dwell yaw
--   nav = {{x, z}}                 chase waypoints (A* graph built here)
--   alarm = {trigger = lootId, vanSeconds?, lockSeconds?, onCatch?}
--   tutorial = {autoEnd = {runs = {1}, plate = id, seconds?}}   L1 forced quick rewind
--   lineup = {x, z, yaw?}          Crew Line-up row centre (default: in front of the van)
--   hooks = {...}                  free-form presentation data for the view (swarm
--                                  stamp, boards); never read by the sim
--   solution = "PLACEHOLDER..."    note about where the golden solution comes from
--
-- Recorded event args are 1-based indices in spec order (loot index for Grab,
-- switch index for Press, hide index for Hide). Reordering a published level's
-- arrays breaks its recordings: append, or bump `version`.

local Config = require("../Config")
local Geom = require("./Geom")

type Box = Geom.Box

export type Source = { kind: string, index: number } -- kind "plate" | "switch"

export type Leg = {
	x0: number,
	z0: number,
	x1: number,
	z1: number,
	len: number,
	tStart: number,
	tArrive: number,
	tEnd: number,
	yawWalk: number,
	yawDwell: number,
	yawNext: number,
}

export type Route = { legs: { Leg }, period: number, speed: number }

export type LevelData = {
	spec: any,
	id: string,
	num: number,
	name: string,
	version: number,
	runSeconds: number,
	par: number,
	cap: number,
	goal: number,
	haul: number,
	deadline: string,
	dawnRuns: number?,
	seed: number,
	floorY: number,
	rootY: number,
	bounds: Box,
	spawns: { { x: number, y: number, z: number, yaw: number } },
	van: Box,
	solids: { Box },
	occluders: { Box },
	noGo: { Box },
	plates: { { id: string, index: number, box: Box } },
	switches: { { id: string, index: number, x: number, y: number, z: number, duration: number? } },
	doors: { { id: string, index: number, box: Box, openBy: { Source }, need: string, alarmLock: boolean } },
	lasers: { { id: string, index: number, box: Box, offBy: { Source }, need: string } },
	loot: { any },
	hides: { { id: string, index: number, box: Box } },
	guards: { { id: string, index: number, route: Route, speed: number } },
	nav: { nodes: { { x: number, z: number } }, edges: { { { to: number, cost: number, doors: { number } } } } },
	alarm: { trigger: number, vanSeconds: number, lockSeconds: number, onCatch: boolean }?,
	kind: string,
	tiers: { number }?,
	bags: boolean,
	visionMult: number,
	dataId: string?,
	lineup: { x: number, z: number, yaw: number, dx: number, dz: number, fx: number, fz: number },
	hooks: any,
	tutorial: { autoEnd: { runs: { [number]: boolean }, plate: number, seconds: number }? }?,
	index: { [string]: { [string]: number } },
}

local LevelSpec = {}

LevelSpec.FORMAT = 1
LevelSpec.box = Geom.box
LevelSpec.span = Geom.span

local DEG = math.pi / 180
local EPS = 1e-6

local function isNum(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function isInt(v: any): boolean
	return isNum(v) and v == math.floor(v)
end

-- Dawn run count for a story level with this par (§3.1: par + 4, minimum 6).
function LevelSpec.dawnRunsFor(par: number): number
	return math.max(Config.Sim.DAWN_MIN_RUNS, par + Config.Sim.DAWN_RUNS_OVER_PAR)
end

-- Compiles a guard route into timed legs (pure; also used by unit tests).
function LevelSpec.compileRoute(points: { any }, speed: number): Route
	local legs: { Leg } = {}
	local t = 0
	local n = #points
	for i = 1, n do
		local p0, p1 = points[i], points[i % n + 1]
		local len = math.sqrt(Geom.dist2(p0.x, p0.z, p1.x, p1.z))
		local yawWalk = Geom.yawTo(p0.x, p0.z, p1.x, p1.z, if p0.face then p0.face * DEG else 0)
		local walk = len / speed
		local dwell = p1.wait or 0
		local leg: Leg = {
			x0 = p0.x,
			z0 = p0.z,
			x1 = p1.x,
			z1 = p1.z,
			len = len,
			tStart = t,
			tArrive = t + walk,
			tEnd = t + walk + dwell,
			yawWalk = yawWalk,
			yawDwell = if p1.face then (p1.face * DEG) % (2 * math.pi) else yawWalk,
			yawNext = 0,
		}
		table.insert(legs, leg)
		t += walk + dwell
	end
	for i, leg in legs do
		leg.yawNext = legs[i % n + 1].yawWalk
	end
	return { legs = legs, period = t, speed = speed }
end

local function blockedBySolids(solids: { Box }, x0: number, y: number, z0: number, x1: number, z1: number): boolean
	for _, b in solids do
		if Geom.moveBlocked(b, x0, y, z0, x1, y, z1) then
			return true
		end
	end
	return false
end

local function insideAny(solids: { Box }, x: number, y: number, z: number): boolean
	for _, b in solids do
		if Geom.inside(b, x, y, z) then
			return true
		end
	end
	return false
end

-- Flood fill on the XZ grid at root height, doors and lasers open. Returns a
-- function that says whether a point is reachable from spawn 1.
local function reachability(bounds: Box, thin: { Box }, y: number, sx: number, sz: number): (number, number) -> boolean
	-- Cells are walked with solids grown by an actor's radius (a point would slip
	-- through zero-width seams); the last step to a target uses the real solids.
	local solids: { Box } = {}
	for _, b in thin do
		table.insert(solids, Geom.expand(b, Config.Sim.ACTOR_RADIUS, 0))
	end
	local cell = Config.Sim.REACH_GRID
	local w = math.ceil((bounds.maxX - bounds.minX) / cell)
	local h = math.ceil((bounds.maxZ - bounds.minZ) / cell)
	while w * h > Config.Sim.REACH_MAX_CELLS do
		cell *= 2
		w = math.ceil((bounds.maxX - bounds.minX) / cell)
		h = math.ceil((bounds.maxZ - bounds.minZ) / cell)
	end
	local function cx(i: number): number
		return bounds.minX + (i + 0.5) * cell
	end
	local function cz(j: number): number
		return bounds.minZ + (j + 0.5) * cell
	end
	local function cellOf(x: number, z: number): (number, number)
		return math.clamp(math.floor((x - bounds.minX) / cell), 0, w - 1),
			math.clamp(math.floor((z - bounds.minZ) / cell), 0, h - 1)
	end
	local seen: { [number]: boolean } = {}
	local queue: { number } = {}
	local si, sj = cellOf(sx, sz)
	local start = sj * w + si
	seen[start] = true
	table.insert(queue, start)
	local head = 1
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	while head <= #queue do
		local id = queue[head]
		head += 1
		local i, j = id % w, math.floor(id / w)
		local x0, z0 = cx(i), cz(j)
		for _, d in DIRS do
			local ni, nj = i + d[1], j + d[2]
			if ni >= 0 and ni < w and nj >= 0 and nj < h then
				local nid = nj * w + ni
				if not seen[nid] then
					local x1, z1 = cx(ni), cz(nj)
					if not insideAny(solids, x1, y, z1) and not blockedBySolids(solids, x0, y, z0, x1, z1) then
						seen[nid] = true
						table.insert(queue, nid)
					end
				end
			end
		end
	end
	return function(x: number, z: number): boolean
		-- A target counts as reachable when a free cell within one cell of it is.
		local i, j = cellOf(x, z)
		for dj = -1, 1 do
			for di = -1, 1 do
				local ni, nj = i + di, j + dj
				if ni >= 0 and ni < w and nj >= 0 and nj < h and seen[nj * w + ni] then
					if not blockedBySolids(thin, cx(ni), y, cz(nj), x, z) then
						return true
					end
				end
			end
		end
		return false
	end
end

-- Validates a spec. Returns ok and a list of readable problems.
function LevelSpec.validate(spec: any): (boolean, { string })
	local errs: { string } = {}
	local function err(fmt: string, ...: any)
		table.insert(errs, string.format(fmt, ...))
	end
	if type(spec) ~= "table" then
		return false, { "spec is not a table" }
	end
	local extent = Config.Sim.LEVEL_EXTENT

	if spec.format ~= LevelSpec.FORMAT then
		err("format must be %d", LevelSpec.FORMAT)
	end
	if type(spec.id) ~= "string" or spec.id == "" then
		err("id must be a non-empty string")
	end
	if not isInt(spec.num) or spec.num < 1 or spec.num > 65535 then
		err("num must be an integer in 1..65535 (u16 level id in recordings)")
	end
	if not isInt(spec.version) or spec.version < 1 then
		err("version must be a positive integer")
	end
	if type(spec.name) ~= "string" then
		err("name must be a string")
	end
	if not isNum(spec.runSeconds) or spec.runSeconds <= 0 or spec.runSeconds > Config.Rec.LOOP_MAX_SECONDS then
		err("runSeconds must be in (0, %d]", Config.Rec.LOOP_MAX_SECONDS)
	end
	if not isInt(spec.par) or spec.par < 0 then
		err("par must be a non-negative integer")
	end
	if not isInt(spec.cap) or spec.cap < 1 or spec.cap > Config.Sim.MAX_LEVEL_CAP then
		err("cap must be an integer in 1..%d", Config.Sim.MAX_LEVEL_CAP)
	elseif isInt(spec.par) and spec.par > spec.cap then
		err("par (%d) exceeds cap (%d)", spec.par, spec.cap)
	end
	if not isInt(spec.seed) then
		err("seed must be an integer")
	end
	local kind = spec.kind or "story"
	local party = kind == "party"
	if kind ~= "story" and kind ~= "party" then
		err("kind must be story or party")
	end
	local goal = spec.goal
	if party then
		local tiers = spec.tiers
		if type(tiers) ~= "table" or #tiers == 0 then
			err("a party level needs tiers (ascending $ thresholds)")
		else
			local last = 0
			for i, v in tiers do
				if not isNum(v) or v <= last then
					err("tiers[%d] must be a number above the previous tier", i)
					break
				end
				last = v
			end
			if goal == nil then
				goal = tiers[1]
			end
		end
		if spec.haul ~= nil then
			err("a party level has tiers, not haul")
		end
		if spec.dawnRuns == nil then
			err("a party level needs dawnRuns (it only ends at Dawn)")
		end
	elseif spec.tiers ~= nil then
		err("tiers are only for party levels")
	end
	if not isNum(goal) or goal <= 0 then
		err("goal must be a positive number")
	end
	if spec.haul ~= nil and (not isNum(spec.haul) or (isNum(goal) and spec.haul < goal)) then
		err("haul must be a number >= goal")
	end
	if spec.bags ~= nil and type(spec.bags) ~= "boolean" then
		err("bags must be a boolean")
	end
	if spec.guardVision ~= nil and (not isNum(spec.guardVision) or spec.guardVision <= 0 or spec.guardVision > 2) then
		err("guardVision must be a multiplier in (0, 2]")
	end
	if spec.dataId ~= nil and (type(spec.dataId) ~= "string" or spec.dataId == "") then
		err("dataId must be a non-empty string")
	end
	if spec.lineup ~= nil then
		local l = spec.lineup
		if type(l) ~= "table" or not isNum(l.x) or not isNum(l.z) or (l.yaw ~= nil and not isNum(l.yaw)) then
			err("lineup must be {x, z, yaw?}")
		end
	end
	if spec.hooks ~= nil and type(spec.hooks) ~= "table" then
		err("hooks must be a table")
	end

	-- Deadline
	local deadline = spec.deadline
	if deadline ~= "None" and deadline ~= "Dawn" and deadline ~= "Alarm" then
		err("deadline must be None, Dawn or Alarm")
	end
	if spec.dawnRuns ~= nil then
		if not isInt(spec.dawnRuns) or spec.dawnRuns < 1 then
			err("dawnRuns must be a positive integer")
		elseif deadline == "None" then
			err("dawnRuns is set but deadline is None")
		end
	end
	if deadline == "Alarm" and type(spec.alarm) ~= "table" then
		err("deadline Alarm needs an alarm table")
	end
	if spec.alarm ~= nil and deadline ~= "Alarm" then
		err("alarm is set but deadline is not Alarm")
	end

	-- Geometry
	local bounds = spec.bounds
	if not Geom.isValidBox(bounds) then
		err("bounds must be a valid box")
		bounds = nil
	elseif
		bounds.minX < -extent
		or bounds.minY < -extent
		or bounds.minZ < -extent
		or bounds.maxX > extent
		or bounds.maxY > extent
		or bounds.maxZ > extent
	then
		err("bounds exceed +-%d studs of the level origin", extent)
	end
	local function checkBox(b: any, what: string): boolean
		if not Geom.isValidBox(b) then
			err("%s: not a valid box", what)
			return false
		end
		if bounds and not Geom.boxesOverlap(b, bounds) then
			err("%s: outside the level bounds", what)
			return false
		end
		return true
	end
	local function checkPoint(p: any, what: string): boolean
		if type(p) ~= "table" or not isNum(p.x) or not isNum(p.y) or not isNum(p.z) then
			err("%s: needs numeric x, y, z", what)
			return false
		end
		if bounds and not Geom.contains(bounds, p.x, p.y, p.z) then
			err("%s: outside the level bounds", what)
			return false
		end
		return true
	end

	local solids: { Box } = {}
	for i, s in (if type(spec.solids) == "table" then spec.solids else {}) :: { any } do
		if type(s) ~= "table" or not checkBox(s.box, "solids[" .. i .. "]") then
			continue
		end
		table.insert(solids, s.box)
	end
	for i, b in (if type(spec.occluders) == "table" then spec.occluders else {}) :: { any } do
		checkBox(b, "occluders[" .. i .. "]")
	end
	for i, b in (if type(spec.noGo) == "table" then spec.noGo else {}) :: { any } do
		checkBox(b, "noGo[" .. i .. "]")
	end

	local rootY = (spec.floorY or 0) + (spec.rootHeight or 3)
	local spawns = spec.spawns
	if type(spawns) ~= "table" or #spawns < 1 then
		err("spawns needs at least one point")
		spawns = {}
	end
	for i, p in spawns :: { any } do
		if checkPoint(p, "spawns[" .. i .. "]") and insideAny(solids, p.x, p.y, p.z) then
			err("spawns[%d] is inside a solid", i)
		end
	end
	checkBox(spec.van, "van")

	-- Ids
	local ids: { [string]: { [string]: boolean } } = {}
	local function list(field: string): { any }
		local v = spec[field]
		if v == nil then
			return {}
		end
		if type(v) ~= "table" then
			err("%s must be an array", field)
			return {}
		end
		return v
	end
	local function checkIds(field: string, ns: string)
		ids[ns] = ids[ns] or {}
		for i, item in list(field) do
			if type(item) ~= "table" or type(item.id) ~= "string" or item.id == "" then
				err("%s[%d]: needs a string id", field, i)
			elseif ids[ns][item.id] then
				err("%s[%d]: duplicate id %q", field, i, item.id)
			else
				ids[ns][item.id] = true
			end
		end
	end
	checkIds("plates", "source")
	checkIds("switches", "source")
	checkIds("doors", "door")
	checkIds("lasers", "laser")
	checkIds("loot", "loot")
	checkIds("hides", "hide")
	checkIds("guards", "guard")

	local used: { [string]: boolean } = {}
	local function checkLinks(item: any, field: string, what: string, optional: boolean)
		local links = item[field]
		if type(links) ~= "table" or #links == 0 then
			if not optional then
				err("%s: %s needs at least one plate or switch id", what, field)
			end
			return
		end
		for _, sid in links do
			if type(sid) ~= "string" or not ids.source[sid] then
				err("%s: %s refers to unknown source %q", what, field, tostring(sid))
			else
				used[sid] = true
			end
		end
		if item.need ~= nil and item.need ~= "any" and item.need ~= "all" then
			err("%s: need must be any or all", what)
		end
	end
	for i, p in list("plates") do
		checkBox(p.box, "plates[" .. i .. "].box")
	end
	for i, s in list("switches") do
		checkPoint(s, "switches[" .. i .. "]")
		if s.duration ~= nil and (not isNum(s.duration) or s.duration <= 0) then
			err("switches[%d]: duration must be positive", i)
		end
	end
	for i, d in list("doors") do
		checkBox(d.box, "doors[" .. i .. "].box")
		checkLinks(d, "openBy", "doors[" .. i .. "]", d.alarmLock == true)
	end
	for i, l in list("lasers") do
		checkBox(l.box, "lasers[" .. i .. "].box")
		checkLinks(l, "offBy", "lasers[" .. i .. "]", false)
	end
	for _, field in { "plates", "switches" } do
		for i, s in list(field) do
			if type(s.id) == "string" and not used[s.id] then
				err("%s[%d] (%q) opens nothing", field, i, s.id)
			end
		end
	end

	local total = 0
	for i, item in list("loot") do
		local what = "loot[" .. i .. "]"
		if checkPoint(item, what) and insideAny(solids, item.x, item.y, item.z) then
			err("%s is inside a solid", what)
		end
		if not isNum(item.value) or item.value <= 0 then
			err("%s: value must be positive", what)
		else
			total += item.value
		end
		if item.heavy ~= nil then
			local hv = item.heavy
			if type(hv) ~= "table" or not isInt(hv.grips) or hv.grips < 2 then
				err("%s: heavy.grips must be an integer >= 2", what)
			elseif hv.maxGrips ~= nil and (not isInt(hv.maxGrips) or hv.maxGrips < hv.grips) then
				err("%s: heavy.maxGrips must be >= grips", what)
			end
		end
		if item.respawn ~= nil and (not isNum(item.respawn) or item.respawn <= 0) then
			err("%s: respawn must be positive seconds", what)
		end
		if item.spots ~= nil then
			for k, p in item.spots do
				checkPoint(p, what .. ".spots[" .. k .. "]")
			end
		end
	end
	if isNum(goal) and total > 0 and total < goal then
		local respawns = false
		for _, item in list("loot") do
			respawns = respawns or item.respawn ~= nil
		end
		if not respawns then
			err("goal %s is more than all the loot (%s)", tostring(goal), tostring(total))
		end
	end
	if #list("loot") == 0 then
		err("loot needs at least one item")
	end
	for i, h in list("hides") do
		checkBox(h.box, "hides[" .. i .. "].box")
	end

	-- Guards
	for i, g in list("guards") do
		local what = "guards[" .. i .. "]"
		if g.speed ~= nil and (not isNum(g.speed) or g.speed <= 0) then
			err("%s: speed must be positive", what)
		end
		local route = g.route
		if type(route) ~= "table" or #route < 2 then
			err("%s: route needs at least 2 points", what)
			continue
		end
		local ok = true
		for k, p in route do
			if type(p) ~= "table" or not isNum(p.x) or not isNum(p.z) then
				err("%s.route[%d]: needs numeric x, z", what, k)
				ok = false
			elseif p.wait ~= nil and (not isNum(p.wait) or p.wait < 0) then
				err("%s.route[%d]: wait must be >= 0", what, k)
				ok = false
			end
		end
		if ok then
			for k = 1, #route do
				local p0, p1 = route[k], route[k % #route + 1]
				if blockedBySolids(solids, p0.x, rootY, p0.z, p1.x, p1.z) then
					err("%s: leg %d crosses a solid", what, k)
				end
				for _, d in list("doors") do
					if Geom.isValidBox(d.box) and Geom.moveBlocked(d.box, p0.x, rootY, p0.z, p1.x, rootY, p1.z) then
						err("%s: leg %d walks through door %q", what, k, tostring(d.id))
					end
				end
			end
			local r = LevelSpec.compileRoute(route, g.speed or Config.Sim.GUARD_SPEED)
			if r.period <= EPS then
				err("%s: route has zero length and no waits", what)
			end
		end
	end
	for i, p in list("nav") do
		if type(p) ~= "table" or not isNum(p.x) or not isNum(p.z) then
			err("nav[%d]: needs numeric x, z", i)
		end
	end

	-- Alarm and tutorial
	if type(spec.alarm) == "table" then
		local a = spec.alarm
		if type(a.trigger) ~= "string" or not (ids.loot and ids.loot[a.trigger]) then
			err("alarm.trigger must name a loot id")
		end
		for _, k in { "vanSeconds", "lockSeconds" } do
			if a[k] ~= nil and (not isNum(a[k]) or a[k] <= 0) then
				err("alarm.%s must be positive", k)
			end
		end
		if #list("guards") == 0 then
			err("an Alarm level needs a guard to chase")
		end
	end
	if spec.tutorial ~= nil then
		local ae = type(spec.tutorial) == "table" and spec.tutorial.autoEnd
		if ae then
			local isPlate = false
			for _, p in list("plates") do
				isPlate = isPlate or p.id == ae.plate
			end
			if not isPlate then
				err("tutorial.autoEnd.plate must name a plate id")
			end
			if type(ae.runs) ~= "table" or #ae.runs == 0 then
				err("tutorial.autoEnd.runs must list run numbers")
			end
		end
	end

	-- Reachability (doors open, lasers off): spawn -> plates, switches, loot, van.
	if #errs == 0 and bounds and #spawns > 0 then
		local s1 = spawns[1]
		local reach = reachability(bounds, solids, rootY, s1.x, s1.z)
		local function need(x: number, z: number, what: string)
			if not reach(x, z) then
				err("%s is not reachable from spawn 1 (doors open)", what)
			end
		end
		local vx, _, vz = Geom.center(spec.van)
		need(vx, vz, "van")
		for _, p in list("plates") do
			local x, _, z = Geom.center(p.box)
			need(x, z, "plate " .. p.id)
		end
		for _, s in list("switches") do
			need(s.x, s.z, "switch " .. s.id)
		end
		for _, item in list("loot") do
			need(item.x, item.z, "loot " .. item.id)
		end
		for k = 2, #spawns do
			need(spawns[k].x, spawns[k].z, "spawn " .. k)
		end
	end

	return #errs == 0, errs
end

-- Validates (erroring with every problem) and compiles a spec into LevelData.
function LevelSpec.compile(spec: any): LevelData
	local ok, errs = LevelSpec.validate(spec)
	if not ok then
		error("LevelSpec " .. tostring(spec and spec.id) .. ":\n  " .. table.concat(errs, "\n  "), 2)
	end
	local S = Config.Sim
	local floorY = spec.floorY or 0
	local rootY = floorY + (spec.rootHeight or 3)
	local index: { [string]: { [string]: number } } =
		{ plate = {}, switch = {}, door = {}, laser = {}, loot = {}, hide = {}, guard = {} }

	local solids, occluders, noGo = {}, {}, {}
	for _, s in spec.solids or {} do
		table.insert(solids, s.box)
		table.insert(noGo, s.box)
		if s.sight ~= false then
			table.insert(occluders, s.box)
		end
	end
	for _, b in spec.occluders or {} do
		table.insert(occluders, b)
	end
	for _, b in spec.noGo or {} do
		table.insert(noGo, b)
	end

	local plates = {}
	for i, p in spec.plates or {} do
		index.plate[p.id] = i
		plates[i] = { id = p.id, index = i, box = Geom.expand(p.box, S.PLATE_TOLERANCE, 0) }
	end
	local switches = {}
	for i, s in spec.switches or {} do
		index.switch[s.id] = i
		switches[i] = { id = s.id, index = i, x = s.x, y = s.y, z = s.z, duration = s.duration }
	end
	local function sources(ids: { string }?): { Source }
		local out = {}
		for _, sid in ids or {} do
			if index.plate[sid] then
				table.insert(out, { kind = "plate", index = index.plate[sid] })
			else
				table.insert(out, { kind = "switch", index = index.switch[sid] })
			end
		end
		return out
	end
	local doors = {}
	for i, d in spec.doors or {} do
		index.door[d.id] = i
		doors[i] = {
			id = d.id,
			index = i,
			box = d.box,
			openBy = sources(d.openBy),
			need = d.need or "any",
			alarmLock = d.alarmLock == true,
		}
	end
	local lasers = {}
	for i, l in spec.lasers or {} do
		index.laser[l.id] = i
		lasers[i] = { id = l.id, index = i, box = l.box, offBy = sources(l.offBy), need = l.need or "any" }
	end
	local loot = {}
	for i, item in spec.loot do
		index.loot[item.id] = i
		local spots = {}
		for _, p in item.spots or {} do
			table.insert(spots, { x = p.x, y = p.y, z = p.z })
		end
		loot[i] = {
			id = item.id,
			index = i,
			x = item.x,
			y = item.y,
			z = item.z,
			value = item.value,
			kind = item.kind or "Cash",
			top = item.top == true,
			heavy = item.heavy,
			respawn = item.respawn,
			spots = spots,
		}
	end
	local hides = {}
	for i, h in spec.hides or {} do
		index.hide[h.id] = i
		hides[i] = { id = h.id, index = i, box = h.box }
	end
	local guards = {}
	for i, g in spec.guards or {} do
		index.guard[g.id] = i
		local speed = g.speed or S.GUARD_SPEED
		guards[i] = { id = g.id, index = i, speed = speed, route = LevelSpec.compileRoute(g.route, speed) }
	end

	-- Chase graph: an edge joins two nav points with no static solid between them;
	-- doors on the edge are listed so the sim skips it while they are shut.
	local nodes = {}
	for i, p in spec.nav or {} do
		nodes[i] = { x = p.x, z = p.z }
	end
	local edges = {}
	for i = 1, #nodes do
		edges[i] = {}
	end
	for i = 1, #nodes do
		for j = i + 1, #nodes do
			local a, b = nodes[i], nodes[j]
			if not blockedBySolids(solids, a.x, rootY, a.z, b.x, b.z) then
				local ds = {}
				for k, d in doors do
					if Geom.moveBlocked(d.box, a.x, rootY, a.z, b.x, rootY, b.z) then
						table.insert(ds, k)
					end
				end
				local cost = math.sqrt(Geom.dist2(a.x, a.z, b.x, b.z))
				table.insert(edges[i], { to = j, cost = cost, doors = ds })
				table.insert(edges[j], { to = i, cost = cost, doors = ds })
			end
		end
	end

	local spawns = {}
	for i, p in spec.spawns do
		spawns[i] = { x = p.x, y = p.y, z = p.z, yaw = ((p.yaw or 0) * DEG) % (2 * math.pi) }
	end

	local dawnRuns: number? = spec.dawnRuns
	if spec.deadline == "Dawn" and dawnRuns == nil then
		dawnRuns = LevelSpec.dawnRunsFor(spec.par)
	end
	local kind = spec.kind or "story"
	local tiers = nil
	if kind == "party" then
		tiers = table.clone(spec.tiers)
	end
	local goal = spec.goal or (tiers and tiers[1])

	-- Crew Line-up row: centre, facing (yaw), across (dx, dz) and forward (fx, fz).
	local lx, _, _ = Geom.center(spec.van)
	local lz = spec.van.minZ - 2 - S.LINEUP_SPACING
	local lyaw = 0
	if spec.lineup then
		lx, lz = spec.lineup.x, spec.lineup.z
		lyaw = ((spec.lineup.yaw or 0) * DEG) % (2 * math.pi)
	end
	local fx, fz = Geom.forward(lyaw)
	local lineup = { x = lx, z = lz, yaw = lyaw, dx = -fz, dz = fx, fx = fx, fz = fz }

	local alarm = nil
	if spec.alarm then
		alarm = {
			trigger = index.loot[spec.alarm.trigger],
			vanSeconds = spec.alarm.vanSeconds or S.ALARM_VAN_SECONDS,
			lockSeconds = spec.alarm.lockSeconds or S.ALARM_LOCK_SECONDS,
			onCatch = spec.alarm.onCatch == true,
		}
	end
	local tutorial = nil
	if spec.tutorial and spec.tutorial.autoEnd then
		local ae = spec.tutorial.autoEnd
		local runs = {}
		for _, r in ae.runs do
			runs[r] = true
		end
		tutorial = {
			autoEnd = { runs = runs, plate = index.plate[ae.plate], seconds = ae.seconds or S.L1_AUTO_END_SECONDS },
		}
	end

	return {
		spec = spec,
		id = spec.id,
		num = spec.num,
		name = spec.name,
		version = spec.version,
		runSeconds = spec.runSeconds,
		par = spec.par,
		cap = spec.cap,
		goal = goal,
		haul = spec.haul or goal,
		deadline = spec.deadline,
		dawnRuns = dawnRuns,
		seed = spec.seed,
		floorY = floorY,
		rootY = rootY,
		bounds = spec.bounds,
		spawns = spawns,
		van = spec.van,
		solids = solids,
		occluders = occluders,
		noGo = noGo,
		plates = plates,
		switches = switches,
		doors = doors,
		lasers = lasers,
		loot = loot,
		hides = hides,
		guards = guards,
		nav = { nodes = nodes, edges = edges },
		alarm = alarm,
		tutorial = tutorial,
		index = index,
		kind = kind,
		tiers = tiers,
		bags = spec.bags == true,
		visionMult = spec.guardVision or 1,
		dataId = spec.dataId,
		lineup = lineup,
		hooks = spec.hooks or {},
	}
end

-- 1-based index of an id of one kind ("plate", "switch", "door", "laser", "loot",
-- "hide", "guard"); errors on an unknown id (server prompt -> recorded event arg).
function LevelSpec.indexOf(level: LevelData, kind: string, id: string): number
	local map = level.index[kind]
	local i = map and map[id]
	if not i then
		error(string.format("LevelSpec.indexOf: no %s %q in %s", kind, id, level.id), 2)
	end
	return i
end

return table.freeze(LevelSpec)
