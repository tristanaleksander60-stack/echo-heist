--!strict
-- Dumps the experience-page video's motion (tools/blender/store_video.py) as JSON: every actor of every run of a
-- launch level's solution (tests/sim/Solutions, played by the sim harness exactly as the specs play it), sampled each
-- sim tick: you and your clones (the replayed recordings: the game's own echo paths), Gus, the doors and the loot.
-- Nothing is hand-animated: the video's figures walk where the server's sim puts them.
--   lune run tools/blender/video_paths.luau <levelNum 1-6> [runs] > paths.json

local process = require("@lune/process")
local serde = require("@lune/serde")

local Config = require("../../src/shared/Config")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Harness = require("../../tests/sim/Harness")
local Solutions = require("../../tests/sim/Solutions")

local num = tonumber(process.args[1]) or 1
local maxRuns = tonumber(process.args[2])
local level = Harness.level(num)
local plan = Solutions.planFor(level)
if maxRuns then
	local runs = {}
	for r = 1, math.min(maxRuns, #plan.runs) do
		runs[r] = plan.runs[r]
	end
	plan = { runs = runs, players = plan.players }
end

local runs = {}
local cur: any = nil
local lastRun = 0
local function r3(v: number): number
	return math.floor(v * 1000 + 0.5) / 1000
end
Harness.play(level, plan, {
	onTick = function(sim: any)
		if sim.runIndex ~= lastRun then
			lastRun = sim.runIndex
			cur = { index = sim.runIndex, ticks = {} }
			table.insert(runs, cur)
		end
		local snap = HeistSim.snapshot(sim)
		local actors = {}
		for _, a in snap.actors do
			table.insert(actors, {
				id = a.id,
				kind = a.kind,
				slot = a.slot,
				present = a.present,
				x = r3(a.x),
				y = r3(a.y),
				z = r3(a.z),
				yaw = r3(a.yaw),
				carrying = a.carrying,
			})
		end
		local guards = {}
		for _, g in snap.guards do
			table.insert(guards, { x = r3(g.x), z = r3(g.z), yaw = r3(g.yaw), mode = g.mode })
		end
		local doors = {}
		for _, d in snap.doors do
			table.insert(doors, d.open)
		end
		local loot = {}
		for _, l in snap.loot do
			table.insert(loot, { state = l.state, carrier = l.carrier })
		end
		table.insert(cur.ticks, { t = r3(snap.t), actors = actors, guards = guards, doors = doors, loot = loot })
	end,
})

print(serde.encode("json", { level = level.id, hz = Config.Rec.HZ, runs = runs }, false))
