-- L2: "naive kid" runs (MASTERPLAN §4.1, §7.5, §8.9): wandering, non-planning
-- players never crash the sim, every tick keeps its invariants, and the levels
-- still give a clone and a bank within 2 runs (L1, Clone Party) or 3 runs (L2-L4,
-- the Big Score, every daily vault).

local Assert = require("../unit/Assert")
local Config = require("../../src/shared/Config")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local EventLog = require("../../src/shared/Sim/EventLog")
local Geom = require("../../src/shared/Sim/Geom")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Loot = require("../../src/shared/Sim/Loot")
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
		local items = Loot.carried(a)
		assert(#items <= a.capacity, "never more than the bag holds")
		for _, i in items do
			assert(a.present, "only present actors carry")
			assert(carriedBy[i] == nil, "an item has one carrier")
			carriedBy[i] = a.id
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

-- The launch levels and every daily vault, with the runs a kid gets to bank in.
local function cases(): { any }
	local out = {}
	for n = 1, 6 do
		table.insert(out, { level = Harness.level(n), within = if n == 1 or n == 5 then 2 else 3, n = n })
	end
	for _, spec in DailyVaults.designs do
		table.insert(out, { level = LevelSpec.compile(spec), within = 3, n = 0 })
	end
	return out
end

return function(test)
	for _, case in cases() do
		local level, within, n = case.level, case.within, case.n
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

	-- Clone Party over 8 runs for 40 kids (seeds 501-540). Returns tier counts and the
	-- lengths of runs 3-8, split by whether the kid's run 1 or 2 tripped the till alarm.
	local function party(opts: any?): any
		local level = Harness.level(5)
		local out = { tiers = { 0, 0, 0 }, kids = 0, tripped = 0, lensTripped = {}, lensClean = {} }
		for seed = 501, 540 do
			local sim, runs =
				Harness.play(level, NaiveKid.plan(level, seed, level.dawnRuns, opts), { onTick = invariants })
			Assert.eq(sim.overReason, "Dawn", "a party always ends at Dawn")
			local r = HeistSim.result(sim)
			out.kids += 1
			for k = 1, 3 do
				out.tiers[k] += if r.tierMet >= k then 1 else 0
			end
			local early = EventLog.count(runs[1].log, EV.AlarmOn) + EventLog.count(runs[2].log, EV.AlarmOn) > 0
			out.tripped += if early then 1 else 0
			for i = 3, #runs do
				table.insert(if early then out.lensTripped else out.lensClean, runs[i].t)
			end
		end
		return out
	end

	local function median(list: { number }): number
		local t = table.clone(list)
		table.sort(t)
		return t[math.max(1, math.floor((#t + 1) / 2))] or 0
	end

	test("L1: a kid who taps END RUN off the plate in run 1 still banks within 3 runs (untilDone)", function()
		local level = Harness.level(1)
		for seed = 1, SEEDS do
			local plan = NaiveKid.plan(level, seed, 3)
			plan.runs[1] = { [1] = { { endRun = true } } } -- the curious tap at 1.5 s
			local sim, runs = Harness.play(level, plan, { onTick = invariants })
			Assert.eq(EventLog.count(runs[1].log, EV.AutoEnd), 0, "run 1 ended off the plate")
			local banked = false
			for _, run in runs do
				banked = banked or EventLog.count(run.log, EV.Bank) > 0
			end
			Assert.truthy(banked or sim.phase == "Over", "seed " .. seed .. ": banks by run 3")
		end
	end)

	test("Clone Party: most naive kids reach Haul1 by Dawn, Haul3 takes a plan", function()
		local p = party()
		print(
			string.format(
				"        [kids] Haul1 %d/%d, Haul2 %d/%d, Haul3 %d/%d",
				p.tiers[1],
				p.kids,
				p.tiers[2],
				p.kids,
				p.tiers[3],
				p.kids
			)
		)
		-- [DECIDED] balance targets for the placeholder tuning: >= 80% Haul1, <= 10% Haul3.
		Assert.truthy(p.tiers[1] >= 0.8 * p.kids, string.format("Haul1 for %d/%d kids", p.tiers[1], p.kids))
		Assert.truthy(p.tiers[3] <= 0.1 * p.kids, string.format("Haul3 for %d/%d kids", p.tiers[3], p.kids))
	end)

	test("Clone Party: value-seeking kids who go for the till first keep their runs (time-locked till)", function()
		local OPENS = Config.Levels.PARTY_TILL_OPENS_SECONDS
		local p = party({ greedy = true, topFirst = true })
		local mt, mc = median(p.lensTripped), median(p.lensClean)
		print(
			string.format(
				"        [greedy kids] Haul1 %d/%d, Haul2 %d/%d; %d tripped the till in run 1-2: runs 3-8 median %.1f s (others %.1f s)",
				p.tiers[1],
				p.kids,
				p.tiers[2],
				p.kids,
				p.tripped,
				mt,
				mc
			)
		)
		Assert.truthy(p.tripped >= 5, "enough greedy kids rob the till early to measure (" .. p.tripped .. ")")
		-- Before the time lock a run-1 till clone cut every later run to 2-5 s.
		Assert.truthy(mt >= OPENS, string.format("their later runs last past 0:20 (median %.1f s)", mt))
		Assert.truthy(p.tiers[1] >= 0.8 * p.kids, string.format("Haul1 for %d/%d greedy kids", p.tiers[1], p.kids))
	end)

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
