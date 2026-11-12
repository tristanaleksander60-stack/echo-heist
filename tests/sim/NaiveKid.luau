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
-- These are synthetic stand-ins; real "naive" recordings from kid wave 1 replace
-- them (levels/<id>.naive/*.bin, §8.4).

local Geom = require("../../src/shared/Sim/Geom")
local HeistSim = require("../../src/shared/Sim/HeistSim")

local NaiveKid = {}

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
	decide = function(bot: any, sim: any, _view: any, t: number): { any }
		local a = HeistSim.liveActor(sim, bot.id)
		if first then
			first = false
			local top = topLoot(level)
			return { { go = { top.x, top.z }, timeout = 6, giveUp = 1 }, { grab = top.id }, { decide = decide } }
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
				return { { go = { x, z } }, { stay = true } }
			end
			local cash = level.loot[1]
			return { { go = { cash.x, cash.z } }, { grab = cash.id }, { decide = decide } }
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
		local steps: { any } = { { go = { tx, tz }, timeout = rnd(2, 5), giveUp = 1 } }
		if lootId then
			table.insert(steps, { grab = lootId })
		end
		table.insert(steps, { wait = rnd(0.2, 2.5) })
		table.insert(steps, { decide = decide })
		return steps
	end
	return { decide = decide }
end

-- A Harness plan of `runs` naive runs for player 1 (opts: see NaiveKid.brain).
function NaiveKid.plan(level: any, seed: number, runs: number, opts: any?): any
	local plan = { runs = {} }
	for r = 1, runs do
		table.insert(plan.runs, { [1] = { NaiveKid.brain(level, seed, r, opts) } })
	end
	return plan
end

return NaiveKid
