-- L2: the 12 launch daily vaults (MASTERPLAN §5.3, §4.3): which vault plays on which
-- UTC day (consistent with Data/DailyVault and Data/Calendar), the vetted
-- date-seeded modifiers, and every (vault, modifier) pair solvable at par from its
-- PLACEHOLDER scripted solution, deterministic, and replayable from buffers.

local Assert = require("../unit/Assert")
local Calendar = require("../../src/shared/Data/Calendar")
local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local DailyVault = require("../../src/shared/Data/DailyVault")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local EventLog = require("../../src/shared/Sim/EventLog")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Schema = require("../../src/shared/Data/Schema")
local Bot = require("./Bot")
local Harness = require("./Harness")
local Solutions = require("./Solutions")
local Tape = require("./Tape")

local EV = EventLog.EV
local L = Config.Levels
local YEAR = Config.Data.Advent.YEAR

local function dec(d: number): number
	return Calendar.daysFromCivil(YEAR, 12, d)
end

local function variants(spec: any): { string }
	local out = { "None" }
	for _, m in spec.daily.modifiers do
		if m ~= "None" then
			table.insert(out, m)
		end
	end
	return out
end

return function(test)
	test("12 designs, one per advent day Dec 3-14, in the data layer's rotation", function()
		Assert.eq(DailyVaults.COUNT, 12, "12 hand-authored vaults at launch (§5.3)")
		Assert.eq(DailyVaults.COUNT, Config.Data.Daily.VAULT_COUNT, "same count as Config.Data.Daily")
		Assert.eq(DailyVaults.FIRST_DAY, Calendar.dayOf(Config.Data.Event.FIRST), "design 1 on launch day")
		local seen = {}
		for d = 3, 14 do
			local spec, n, mod = DailyVaults.forDay(dec(d))
			Assert.eq(spec.daily.order, d - 2, "Dec " .. d .. " plays design " .. (d - 2))
			Assert.eq(n, DailyVault.vaultFor(dec(d)), "rotation slot = DailyVault.vaultFor")
			Assert.eq(n, spec.daily.order, "slot n = design n (Orn_VaultNN is design NN's ornament)")
			Assert.eq(mod, "None", "first pass through the advent is unmodified")
			Assert.eq(DailyVaults.adventDayOf(spec), d, "advent day")
			Assert.falsy(seen[spec.id], "each design once")
			seen[spec.id] = true
		end
		-- byNumber is a bijection over 1..12.
		for n = 1, 12 do
			local spec = DailyVaults.byNumber[n]
			Assert.truthy(spec, "slot " .. n)
			Assert.eq(DailyVaults.numberOf[spec.id], n, "numberOf inverts byNumber")
		end
	end)

	test("every day Nov 2026 - Feb 2027 maps to the data layer's vault and ornament", function()
		local from = Calendar.daysFromCivil(YEAR, 11, 1)
		local to = Calendar.daysFromCivil(YEAR + 1, 2, 28)
		for day = from, to do
			local spec, n, mod = DailyVaults.forDay(day)
			Assert.eq(n, DailyVault.vaultFor(day), "slot")
			Assert.eq(DailyVaults.byNumber[n].id, spec.id, "design in that slot")
			Assert.truthy(mod == "None" or table.find(spec.daily.modifiers, mod), "vetted modifier")
			local ornament = DailyVault.ornamentFor(day)
			if DailyVault.adventDay(day) then
				Assert.truthy(string.match(ornament, "^Orn_Advent"), "advent ornament")
			else
				Assert.eq(ornament, string.format("Orn_Vault%02d", n), "vault ornament matches the slot")
			end
			Assert.truthy(Config.Data.Trophies[ornament], "ornament exists: " .. ornament)
		end
		-- Dec 15-24 repeat the designs, now with a date-seeded modifier.
		local modded = 0
		for d = 15, 24 do
			local spec, _, mod = DailyVaults.forDay(dec(d))
			Assert.eq(spec.daily.order, (d - 3) % 12 + 1, "rotation repeats")
			modded += if mod ~= "None" then 1 else 0
			local _, _, again = DailyVaults.forDay(dec(d))
			Assert.eq(again, mod, "same day, same modifier")
		end
		Assert.truthy(modded >= 5, "most second-cycle days carry a modifier (" .. modded .. "/10)")
	end)

	test("every design: 30 s, fixed 5-clone loadout, Dawn at run 6, par 1-3, free sweets", function()
		local nums = {}
		for k, spec in DailyVaults.designs do
			Assert.eq(spec.daily.order, k, spec.id .. " order")
			Assert.eq(spec.num, 300 + k, spec.id .. " num")
			Assert.falsy(nums[spec.num], "unique num")
			nums[spec.num] = true
			local level = LevelSpec.compile(spec)
			Assert.eq(level.runSeconds, L.DAILY_RUN_SECONDS, spec.id .. " 30 s")
			Assert.eq(level.cap, L.DAILY_CAP, spec.id .. " 5 clones")
			Assert.eq(level.dawnRuns, L.DAILY_DAWN_RUNS, spec.id .. " Dawn at run 6")
			Assert.truthy(level.par >= 1 and level.par <= 3, spec.id .. " par 1-3")
			Assert.truthy(level.location == nil or spec.location == "CornerShop" or spec.location == "Bank", "kit")
			Assert.truthy(string.find(spec.solution, "PLACEHOLDER", 1, true), "placeholder solution label")
			local free = 0
			for _, item in spec.loot do
				free += if item.id == "CandyJar" or item.id == "Gingerbread" then 1 else 0
				Assert.eq(item.heavy, nil, "no heavy loot at launch")
			end
			Assert.eq(free, 2, spec.id .. " two free sweets by the door")
			-- Haul = all the loot, so the goal item never ends the vault at once.
			local total = 0
			for _, item in spec.loot do
				total += item.value
			end
			Assert.eq(level.haul, total, spec.id .. " haul = all the loot")
			Assert.truthy(level.haul > level.goal, spec.id .. " haul above the goal")
			Assert.eq(#spec.daily.goalItems, 1, spec.id .. " one goal item")
			Assert.truthy(#spec.daily.bonus >= 1 and spec.daily.bonusValue > 0, spec.id .. " a bonus for the board")
		end
	end)

	test("a kid who banks the goal first can still bank the bonus in that run", function()
		local level = LevelSpec.compile(DailyVaults.designs[1])
		local sim, runs = Harness.play(level, {
			runs = {
				{ [1] = { { goPlate = "A" }, { endRun = true } } },
				{
					[1] = {
						{ go = { 0, -10 } },
						{ goLoot = "Stocking" },
						{ grab = "Stocking" },
						{ go = { 0, -10 } },
						{ goVan = true },
						{ go = { 0, -10 } },
						{ go = { 0, -24 } },
						{ goLoot = "Bauble" },
						{ grab = "Bauble" },
						{ go = { 0, -24 } },
						{ go = { 0, -10 } },
						{ goVan = true },
						{ endRun = true },
					},
				},
			},
		})
		local r = HeistSim.result(sim)
		Assert.eq(EventLog.count(runs[2].log, EV.GoalMet), 1, "the goal is met mid-run (the run goes on)")
		Assert.eq(EventLog.count(runs[2].log, EV.Bank), 2, "both banked")
		Assert.truthy(r.daily.cleared, "cleared at the end of that run")
		Assert.eq(r.runs, 2, "no extra run")
		Assert.eq(r.daily.haul, 150 + 40, "goal + bonus on the board")
		Assert.truthy(r.daily.timeMs > 0, "time for the board tie-break")
	end)

	test("modifiers: copies only, vetted only, and they do what they say", function()
		for _, spec in DailyVaults.designs do
			for _, m in variants(spec) do
				local s = DailyVaults.apply(spec, m)
				local ok, errs = LevelSpec.validate(s)
				Assert.truthy(ok, spec.id .. " " .. m .. ": " .. table.concat(errs, "; "))
				Assert.eq(s.daily.modifier, m, "tagged")
			end
			Assert.eq(spec.daily.modifier, nil, spec.id .. " design untouched")
		end
		local gus = DailyVaults.designs[4]
		local fast = LevelSpec.compile(DailyVaults.apply(gus, "GuardFast"))
		Assert.near(fast.guards[1].speed, Config.Sim.GUARD_SPEED * L.MOD_GUARD_FAST, 1e-9, "+10%")
		local slow = LevelSpec.compile(DailyVaults.apply(gus, "GuardSlow"))
		Assert.near(slow.guards[1].speed, Config.Sim.GUARD_SPEED * L.MOD_GUARD_SLOW, 1e-9, "-10%")
		local dark = LevelSpec.compile(DailyVaults.apply(gus, "LightsOff"))
		Assert.eq(dark.visionMult, L.MOD_LIGHTS_OFF_VISION, "lights off")
		local sim = HeistSim.new(dark, { players = { 1 } })
		HeistSim.startRun(sim)
		Assert.near(sim.ctx.coneVision.range, Config.Sim.GUARD_VISION_RANGE * L.MOD_LIGHTS_OFF_VISION, 1e-9, "range")
		local moved = LevelSpec.compile(DailyVaults.apply(DailyVaults.designs[1], "LootB"))
		local alt = DailyVaults.designs[1].daily.alt.Bauble.B
		local i = LevelSpec.indexOf(moved, "loot", "Bauble")
		Assert.truthy(moved.loot[i].x == alt.x and moved.loot[i].z == alt.z, "loot position B")
		Assert.falsy((pcall(DailyVaults.apply, DailyVaults.designs[1], "GuardFast")), "unvetted modifier refused")
		Assert.falsy((pcall(DailyVaults.apply, gus, "Chaos")), "unknown modifier refused")
	end)

	-- §5.3 D1 / §8.9: one human-recorded solution.bin per vault (and the Ghost Hint
	-- that replays it) must survive every modified day, and every vetted modifier
	-- must change something the sim reads.
	test("vetted modifiers: never move the goal item, never a no-op", function()
		local modded = 0
		for _, spec in DailyVaults.designs do
			local goal = {}
			for _, id in spec.daily.goalItems do
				goal[id] = true
			end
			local patrols = false
			for _, g in spec.guards or {} do
				local route = LevelSpec.compileRoute(g.route, Config.Sim.GUARD_SPEED)
				for _, leg in route.legs do
					patrols = patrols or leg.len > 0
				end
			end
			for id, alt in spec.daily.alt or {} do
				Assert.falsy(goal[id], spec.id .. ": loot modifiers move bonus loot only, not " .. id)
				Assert.truthy(table.find(spec.daily.bonus, id) ~= nil, spec.id .. ": " .. id .. " is bonus loot")
				Assert.truthy(alt.B ~= nil or alt.C ~= nil, spec.id .. ": " .. id .. " has a B or C spot")
			end
			for _, m in spec.daily.modifiers do
				if m ~= "None" then
					modded += 1
				end
				if m == "LightsOff" then
					Assert.truthy(#(spec.guards or {}) > 0, spec.id .. ": LightsOff needs a Gus to dim")
				elseif m == "GuardFast" or m == "GuardSlow" then
					Assert.truthy(patrols, spec.id .. ": " .. m .. " needs a Gus who walks a patrol")
				elseif m == "LootB" or m == "LootC" then
					local key = if m == "LootB" then "B" else "C"
					local changed = false
					for _, item in DailyVaults.apply(spec, m).loot do
						local a = spec.daily.alt and spec.daily.alt[item.id]
						changed = changed or (a ~= nil and a[key] ~= nil)
					end
					Assert.truthy(changed, spec.id .. ": " .. m .. " moves something")
				end
			end
		end
		print(
			string.format(
				"        [daily] %d vaults, %d modified (vault, modifier) pairs",
				#DailyVaults.designs,
				modded
			)
		)
	end)

	for _, design in DailyVaults.designs do
		test(design.id .. ": the unmodified solution, frozen as tapes, clears every vetted modifier", function()
			local base = LevelSpec.compile(design)
			local simA, runsA = Harness.play(base, Solutions.planFor(base))
			Assert.truthy(HeistSim.result(simA).complete, "base clear")
			-- The heist as a solution.bin: every run's buffer through the wire format.
			local function decode(rec: any): any
				local out = Codec.decode(Codec.encode(rec))
				Assert.truthy(out, "decodes")
				return out
			end
			local clones = {}
			for _, slot in simA.players[1].deck.slots do
				table.insert(clones, decode(slot.rec))
			end
			local final = decode(simA.finalRecordings[1].rec)
			local function replay(level: any): (any, any)
				local sim = HeistSim.new(level, { players = { 1 } })
				HeistSim.seedDeck(sim, 1, clones)
				sim.runIndex = #clones
				HeistSim.startRun(sim)
				return sim, Harness.runOnce(sim, { Tape.new(1, final) }, Harness.history())
			end
			local _, same = replay(base)
			Assert.eq(same.hash, runsA[#runsA].hash, "the tapes replay the base heist bit-identically")
			for _, mod in variants(design) do
				if mod ~= "None" then
					local sim, run = replay(LevelSpec.compile(DailyVaults.apply(design, mod)))
					local r = HeistSim.result(sim)
					Assert.truthy(
						r.complete,
						string.format("%s: cleared from the base tapes\n%s", mod, table.concat(run.lines, "\n"))
					)
					for _, k in { "Caught", "Busted", "Zap", "Stuck" } do
						Assert.eq(EventLog.count(run.log, EV[k]), 0, mod .. ": no " .. k)
					end
				end
			end
		end)
	end

	test("dv06: a solo try misses the 2 s bell clearly, even at the Validator's speed limit", function()
		local spec = DailyVaults.designs[6]
		local bell = spec.switches[1]
		local level = LevelSpec.compile(spec)
		local closeAt = bell.duration + Config.Sim.DOOR_CLOSE_SECONDS -- solid this long after the ring
		-- Ring from the edge of press range, then the shortest way to the vault door.
		local function race(mult: number): number
			local s = table.clone(spec)
			s.switches = { table.clone(bell) }
			s.switches[1].duration = 25 -- held open: measure the run only
			local open = LevelSpec.compile(s)
			local sim = HeistSim.new(open, { players = { 1 } })
			HeistSim.startRun(sim)
			local steps = {
				{ go = { 0, 9 } },
				{ go = { bell.x + Config.Sim.INTERACT_RANGE, bell.z } },
				{ press = "Bell" },
				{ go = { 15, -12 } },
				{ go = { 3, -42.5 } },
				{ go = { 0, -46 } },
				{ stay = true },
			}
			local pressed, reached = nil, nil
			Harness.runOnce(
				sim,
				{ Bot.new(open, 1, steps, { speed = Config.Rec.WALK_SPEED * mult }) },
				Harness.history(),
				function(sm: any)
					pressed = pressed or (if sm.mech.switches[1].on then sm.t else nil)
					local a = HeistSim.liveActor(sm, 1)
					if a and not reached and a.z <= -44.5 then
						reached = sm.t
					end
					if reached then
						HeistSim.endRun(sm, 1)
					end
				end
			)
			return (reached :: number) - (pressed :: number)
		end
		local walk, fast = race(1), race(Config.Rec.SPEED_MULT)
		print(
			string.format(
				"        [dv06] bell to vault %.2f s (x%.2f: %.2f s) vs door shut %.2f s after the ring",
				walk,
				Config.Rec.SPEED_MULT,
				fast,
				closeAt
			)
		)
		Assert.truthy(walk - closeAt >= 1, "a solo try misses by a second or more")
		Assert.truthy(fast > closeAt, "even at the speed a client may claim")
		Assert.truthy(level.switches[1].duration == 2, "2 s bell")
	end)

	for _, design in DailyVaults.designs do
		for _, mod in variants(design) do
			test(string.format("%s [%s]: solvable at par, a clean first clear", design.id, mod), function()
				local level = LevelSpec.compile(DailyVaults.apply(design, mod))
				local plan = Solutions.planFor(level)
				Assert.truthy(plan, "solution exists")
				local sim, runs = Harness.play(level, plan)
				local r = HeistSim.result(sim)
				local dump = Harness.dump(runs)
				Assert.truthy(r.complete, "cleared\n" .. dump)
				Assert.eq(r.runs, level.par + 1, "par clones + the final run")
				Assert.eq(r.clonesUsed, level.par, "par clones")
				Assert.falsy(r.tainted, "no recording was clamped")
				Assert.le(r.totalTime, level.par * level.runSeconds * 1.5, "par execution time (§4.1)")
				for i, run in runs do
					for _, k in { "Rejected", "Stuck", "Zap", "Busted", "Caught", "Shrug" } do
						Assert.eq(EventLog.count(run.log, EV[k]), 0, string.format("run %d: no %s", i, k))
					end
				end
				-- The data layer accepts the result and gives the first clear.
				Assert.truthy((DailyVault.validateResult(r.daily)), "DailyVault.DailyResult")
				local heist = Schema.defaultHeist()
				local day = DailyVaults.FIRST_DAY + design.daily.order - 1
				local summary = DailyVault.apply(heist, day, day, r.daily, 1796000000)
				Assert.truthy(summary and summary.firstClear, "first clear")
				Assert.eq(summary and summary.ornament, DailyVault.ornamentFor(day), "advent ornament")
			end)
		end

		test(design.id .. ": deterministic and replayable from buffers", function()
			local level = LevelSpec.compile(design)
			local simA, runsA = Harness.play(level, Solutions.planFor(level))
			local simB = Harness.play(level, Solutions.planFor(level))
			Assert.eq(simA.heistHash, simB.heistHash, "same inputs, same heist hash")
			local recs = {}
			for _, slot in simA.players[1].deck.slots do
				local buf = Codec.encode(slot.rec)
				Assert.le(buffer.len(buf), Config.Rec.BUDGET_BYTES_PER_SECOND * level.runSeconds + 64, "size budget")
				local rec = Codec.decode(buf)
				Assert.truthy(rec, "decodes")
				table.insert(recs, rec)
			end
			local sim2 = HeistSim.new(level, { players = { 1 } })
			HeistSim.seedDeck(sim2, 1, recs)
			sim2.runIndex = level.par
			sim2.phase = "Lobby"
			HeistSim.startRun(sim2)
			local plan = Solutions.planFor(level)
			local run2 = Harness.runOnce(sim2, { Bot.new(level, 1, plan.runs[#plan.runs][1]) }, Harness.history())
			Assert.eq(run2.hash, runsA[#runsA].hash, "final run from decoded clones")
		end)
	end

	test("an idle crew meets Dawn at run 6 with nothing banked and no clear", function()
		local level = LevelSpec.compile(DailyVaults.designs[1])
		local runs = {}
		for _ = 1, 6 do
			table.insert(runs, { [1] = { { stay = true } } })
		end
		local sim = Harness.play(level, { runs = runs })
		local r = HeistSim.result(sim)
		Assert.eq(r.reason, "Dawn", "Dawn")
		Assert.eq(r.runs, 6, "at run 6")
		Assert.falsy(r.daily.cleared, "not cleared")
	end)
end
