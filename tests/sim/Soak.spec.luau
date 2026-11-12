-- L2: soak (MASTERPLAN §8.9): 500 loops on a level with Gus, doors and a full
-- clone deck. Nothing the sim keeps grows from loop to loop, and the loop stays
-- deterministic all the way.

local Assert = require("../unit/Assert")
local Catalog = require("../../src/shared/Levels/Catalog")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Bot = require("./Bot")
local Harness = require("./Harness")

local LOOPS = 500

-- Number of table slots reachable from v (the static level data excluded).
local function deepCount(v: any, seen: { [any]: boolean }, skip: any): number
	if type(v) ~= "table" or seen[v] or v == skip then
		return 0
	end
	seen[v] = true
	local n = 0
	for k, x in v do
		n += 1 + deepCount(k, seen, skip) + deepCount(x, seen, skip)
	end
	return n
end

return function(test)
	test(string.format("%d loops: no growth, same log every loop", LOOPS), function()
		-- Night Clerk without its Dawn, so the heist never ends.
		local spec = table.clone(Catalog[4])
		spec.deadline = "None"
		local level = LevelSpec.compile(spec)
		local sim = HeistSim.new(level, { players = { 1 } })
		local hist = Harness.history()
		local script = {
			{ goPlate = "A" },
			{ go = { 0, -24 } },
			{ goLoot = "TipJar" },
			{ grab = "TipJar" },
			{ go = { 0, -15 } },
			{ release = true },
			{ endRun = true },
		}
		local sizes, hashes, ticks = {}, {}, {}
		for loop = 1, LOOPS do
			if loop > level.cap then
				assert(HeistSim.deckAction(sim, 1, "Redo", level.cap), "redo the last slot")
			end
			assert(HeistSim.startRun(sim), "run starts")
			local run = Harness.runOnce(sim, { Bot.new(level, 1, script) }, hist)
			table.insert(hashes, EventLog.hash(run.log, 2)) -- entry 1 (RunStart) carries the run index
			table.insert(ticks, run.ticks)
			if loop == 20 or loop == 100 or loop == LOOPS then
				sizes[loop] = deepCount(sim, {}, level)
			end
		end
		Assert.eq(sizes[100], sizes[20], "sim tables: loop 100 vs 20")
		Assert.eq(sizes[LOOPS], sizes[20], "sim tables: loop 500 vs 20")
		-- From the first full-deck loop on, every loop is the same loop.
		for loop = level.cap + 2, LOOPS do
			Assert.eq(hashes[loop], hashes[level.cap + 1], "loop " .. loop .. " log")
			Assert.eq(ticks[loop], ticks[level.cap + 1], "loop " .. loop .. " ticks")
		end
		Assert.eq(sim.runIndex, LOOPS, "run index")
		Assert.eq(#sim.players[1].deck.slots, level.cap, "deck stays at its cap")
	end)
end
