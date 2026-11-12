-- L2: "naive kid" runs (MASTERPLAN §4.1, §7.5, §8.9): wandering, non-planning
-- players never crash the sim, every tick keeps its invariants, and the levels
-- still give a clone and a bank within 2 runs (L1) or 3 runs (L2-L4).

local Assert = require("../unit/Assert")
local EventLog = require("../../src/shared/Sim/EventLog")
local Geom = require("../../src/shared/Sim/Geom")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Harness = require("./Harness")
local NaiveKid = require("./NaiveKid")

local EV = EventLog.EV
local SEEDS = 40
local RATE = 0.95 -- synthetic kids; real kid-wave recordings replace them

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

-- Checked after every tick.
local function invariants(sim: any)
	local level = sim.level
	local carriedBy = {}
	for _, a in sim.actors do
		assert(finite(a.x) and finite(a.y) and finite(a.z), "finite actor position")
		assert(Geom.contains(level.bounds, a.x, a.y, a.z), "actor inside the level bounds")
		if a.carrying ~= 0 then
			assert(a.present, "only present actors carry")
			assert(carriedBy[a.carrying] == nil, "an item has one carrier")
			carriedBy[a.carrying] = a.id
		end
	end
	for i, item in sim.loot.items do
		if item.state == "Carried" then
			assert(carriedBy[i] == item.carrier, "carried item and carrier agree")
		else
			assert(carriedBy[i] == nil, "uncarried item has no carrier")
			assert(item.state == "Home" or item.state == "Dropped" or item.state == "Banked", "known state")
		end
	end
	assert(sim.banked >= (sim._lastBanked or 0), "banked never goes down")
	sim._lastBanked = sim.banked
end

return function(test)
	for n = 1, 4 do
		local level = Harness.level(n)
		local within = if n == 1 then 2 else 3
		test(
			string.format(
				"%s: %d naive kids keep every invariant; >= %d%% bank within %d runs",
				level.id,
				SEEDS,
				RATE * 100,
				within
			),
			function()
				local misses = {}
				for seed = 1, SEEDS do
					local sim, runs = Harness.play(level, NaiveKid.plan(level, seed, within), { onTick = invariants })
					Assert.truthy(#sim.players[1].deck.slots >= 1 or sim.phase == "Over", "a clone after run 1")
					local banked = false
					for r, run in runs do
						banked = banked or EventLog.count(run.log, EV.Bank) > 0
						if r >= 2 then
							Assert.truthy(run.log.b[1] >= 1, "run " .. r .. " replays a clone")
						end
						Assert.falsy(run.tainted, "seed " .. seed .. ": physics-respecting bots are never clamped")
					end
					if not banked then
						table.insert(misses, seed)
					end
					local r = HeistSim.result(sim)
					Assert.truthy(r.banked >= 0 and r.runs <= within, "sensible result")
				end
				local rate = 1 - #misses / SEEDS
				Assert.truthy(
					rate >= RATE,
					string.format("bank rate %.0f%%, misses: %s", rate * 100, table.concat(misses, ","))
				)
				if n == 1 then
					Assert.eq(#misses, 0, "L1 FirstBank within 2 runs for every kid (with the §7.5 hints)")
				end
			end
		)
	end

	test("a naive kid on L4 keeps playing through catches and busted clones", function()
		local level = Harness.level(4)
		local outcomes = 0
		for seed = 1, SEEDS do
			local sim, runs = Harness.play(level, NaiveKid.plan(level, 100 + seed, 6), { onTick = invariants })
			for _, run in runs do
				outcomes += run.catches + run.busted
			end
			Assert.truthy(sim.phase == "Over" or sim.phase == "Between", "heist still going or ended cleanly")
			if sim.phase == "Over" then
				Assert.truthy(sim.overReason == "Complete" or sim.overReason == "Dawn", "ends by completion or Dawn")
			end
		end
		Assert.truthy(outcomes > 0, "Gus caught somebody (a laugh)")
	end)
end
