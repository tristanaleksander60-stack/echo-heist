-- L1: Heist/LineupPlan, the pure maths of the Crew Line-up cut (MASTERPLAN §3.2 rule 8,
-- §6.6) and the "◀ ME, N SEC AGO" label (docs/marketing/CLIPS.md §1.2). On every launch
-- level and daily vault, solo at the level's clone cap and as a crew of 4, the row
-- HeistSim.lineup sends must end up on the floor, clear of the parked van body and of
-- every wall, after LineupPlan.arrange.

local LineupPlan = require("../../src/client/Heist/LineupPlan")
local Strings = require("../../src/shared/Heist/Strings")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Catalog = require("../../src/shared/Levels/Catalog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local Config = require("../../src/shared/Config")
local Assert = require("./Assert")

local H = Config.Heist

local function levels(): { any }
	local out = {}
	for _, spec in Catalog do
		table.insert(out, LevelSpec.compile(spec))
	end
	for _, spec in DailyVaults.designs do
		table.insert(out, LevelSpec.compile(spec))
	end
	return out
end

-- The van body as src/server/Heist/LevelBuilder (and KitPlan's kit van) parks it: centred
-- on the van zone in X, at zone.maxZ + 4.5 in Z, zone width + 1 by 8 studs; grown by the
-- Line-up clearance like Heist/LineupDirector does.
local function vanBody(level: any): LineupPlan.Box
	local v = level.van
	return {
		cx = (v.minX + v.maxX) / 2,
		cz = v.maxZ + 4.5,
		hx = (v.maxX - v.minX + 1) / 2 + H.LINEUP_VAN_CLEARANCE,
		hz = 4 + H.LINEUP_VAN_CLEARANCE,
	}
end

-- A fake sim with `crew` players of `clones` deck slots each, for HeistSim.lineup.
local function lineupOf(level: any, crew: number, clones: number): { any }
	local players = {}
	for seat = 1, crew do
		local slots = {}
		for k = 1, clones do
			slots[k] = { run = k }
		end
		players[seat] = { id = 1000 + seat, seat = seat, orphan = false, deck = { slots = slots } }
	end
	return HeistSim.lineup({ level = level, players = players, runIndex = clones + 1 })
end

local function insideBox(x: number, z: number, b: any, grow: number): boolean
	return x > b.minX - grow and x < b.maxX + grow and z > b.minZ - grow and z < b.maxZ + grow
end

return function(test)
	test("ago: always the true number, nearest 10 s, minutes from 55 s (CLIPS §1.2)", function()
		-- the label as Ui.ago builds it: LineupPlan's number, Strings' words
		local function ago(seconds: number): string
			return Strings.ago(LineupPlan.agoRound(seconds))
		end
		Assert.eq(ago(19.8), Strings.ago(20, false), "18 s run + 1.8 s rewind")
		Assert.eq(ago(13.1), Strings.ago(10, false), "13 s")
		Assert.eq(ago(23.9), Strings.ago(20, false), "23.9 s")
		Assert.eq(ago(25), Strings.ago(30, false), "25 s rounds up")
		Assert.eq(ago(2), Strings.ago(10, false), "never 0 SEC AGO")
		Assert.eq(ago(54), Strings.ago(50, false), "54 s")
		Assert.eq(ago(55), Strings.ago(1, true), "55 s")
		Assert.eq(ago(95), Strings.ago(2, true), "95 s")
	end)

	test("arrange: a row already clear of the van is left alone", function()
		local spots = { { x = 0, z = 12 }, { x = 2.5, z = 12 } }
		local out, yaw, moved = LineupPlan.arrange(spots, math.pi, { cx = 0, cz = 28.5, hx = 7, hz = 5.5 }, 0.5, 60)
		Assert.falsy(moved, "not moved")
		Assert.eq(out, spots, "same spots")
		Assert.near(yaw, math.pi, 1e-9, "same yaw")
		local _, _, none = LineupPlan.arrange(spots, 0, nil, 0.5, 60)
		Assert.falsy(none, "no van body: nothing to clear")
	end)

	test("every level: the Line-up row stands on the floor, clear of the van body and the walls", function()
		for _, level in levels() do
			local body = vanBody(level)
			for _, shape in { { crew = 1, clones = math.max(level.cap, 1) }, { crew = 4, clones = 3 } } do
				local entries = lineupOf(level, shape.crew, shape.clones)
				Assert.eq(#entries, shape.crew * shape.clones + shape.crew, level.id .. " figures")
				local spots = {}
				for i, e in entries do
					spots[i] = { x = e.x, z = e.z }
				end
				local out, yaw, moved = LineupPlan.arrange(spots, entries[1].yaw, body, 0.5, 60)
				local where = string.format("%s crew %d", level.id, shape.crew)
				if moved then
					Assert.near(
						(yaw - entries[1].yaw) % (2 * math.pi),
						math.pi,
						1e-6,
						where .. ": a moved row turns round"
					)
				end
				local b = level.bounds
				for i, p in out do
					local at = string.format("%s figure %d (%.1f, %.1f)", where, i, p.x, p.z)
					Assert.falsy(
						math.abs(p.x - body.cx) < body.hx and math.abs(p.z - body.cz) < body.hz,
						at .. " clear of the van body"
					)
					Assert.truthy(
						p.x >= b.minX + 1 and p.x <= b.maxX - 1 and p.z >= b.minZ + 1 and p.z <= b.maxZ - 1,
						at .. " on the floor"
					)
					for k, s in level.solids do
						Assert.falsy(insideBox(p.x, p.z, s, 0.5), at .. " not in solid " .. k)
					end
				end
			end
		end
	end)

	test("fit: a wider row stands the camera further back; a wider lens brings it closer", function()
		local near = LineupPlan.fitDistance(5, 16 / 9, 50, 0.6, 5.6, 0.45)
		local far = LineupPlan.fitDistance(20, 16 / 9, 50, 0.6, 5.6, 0.45)
		Assert.truthy(far > near, "8 figures need more room than 2")
		Assert.truthy(LineupPlan.fitDistance(20, 16 / 9, 80, 0.6, 5.6, 0.45) < far, "a wider lens is closer")
		local f = LineupPlan.fovFor(12, 20, 16 / 9, 50, 80, 0.6, 5.6, 0.45)
		Assert.truthy(f >= 50 and f <= 80, "fov in range")
		Assert.le(LineupPlan.fitDistance(20, 16 / 9, f, 0.6, 5.6, 0.45), 12, "the chosen lens fits at 12 studs")
	end)

	test("timeline: walks in record order, poses after the last arrival, ripple 60 ms", function()
		local figures = {}
		for k = 0, 7 do
			table.insert(figures, { delay = k * Config.Sim.LINEUP_STAGGER, dist = 5 + 10 * k })
		end
		local starts, walks, poseAt, endAt = LineupPlan.timeline(
			figures,
			H.LINEUP_START_DELAY,
			H.LINEUP_WALK_SPEED,
			H.LINEUP_WALK_MAX_SECONDS,
			H.LINEUP_TURN_SECONDS,
			H.LINEUP_POSE_GAP,
			H.LINEUP_HOLD_SECONDS
		)
		for i = 2, #figures do
			Assert.truthy(starts[i] > starts[i - 1], "record order")
		end
		for i, w in walks do
			Assert.le(w, H.LINEUP_WALK_MAX_SECONDS + 1e-9, "walk capped " .. i)
			Assert.le(starts[i] + w + H.LINEUP_TURN_SECONDS, poseAt, "arrived before the pose " .. i)
		end
		Assert.near(endAt - poseAt, 7 * Config.Sim.LINEUP_STAGGER + H.LINEUP_HOLD_SECONDS, 1e-9, "ripple + hold")
		Assert.le(endAt, 10, "the cut stays short (< 10 s)")
	end)
end
