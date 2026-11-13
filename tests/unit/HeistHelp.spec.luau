-- L1: Shared/Heist/Help + Heist/GhostTapes (PLAN_STEAM_PLUS §5 "Stuck", §6.1 items 3, 5, 8;
-- WALKTHROUGH P0-2, P0-4, P1-6, P1-7; premium G4): the stuck tracker, the ghost's next step, the
-- world-state lines, the failure counterplay table and the unlock rules.

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")
local Catalog = require("../../src/shared/Levels/Catalog")
local DailyVaults = require("../../src/shared/Levels/DailyVaults")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local GhostTapes = require("../../src/shared/Heist/GhostTapes")
local Help = require("../../src/shared/Heist/Help")
local Strings = require("../../src/shared/Heist/Strings")

local O = Config.Onboarding

local function level(id: string): any
	for _, spec in Catalog do
		if spec.id == id then
			return LevelSpec.compile(spec)
		end
	end
	error("no level " .. id)
end

local function words(text: string): number
	local n = 0
	for _ in string.gmatch(text, "%S+") do
		n += 1
	end
	return n
end

-- A clone that walks from the street to (x, z), arriving at `arrive`, and stands there until `len`.
local function cloneTo(lv: any, x: number, z: number, arrive: number, len: number): any
	local rec = Sampler.new(nil, nil, 20)
	local s = lv.spawns[1]
	for i = 0, math.floor(len * 20) do
		local t = i / 20
		local u = math.clamp(t / arrive, 0, 1)
		Sampler.push(rec, s.x + (x - s.x) * u, lv.rootY, s.z + (z - s.z) * u, 0, 0)
	end
	Sampler.finish(rec, Codec.END.EndRun)
	return rec
end

local function plateCentre(lv: any, i: number): (number, number)
	local b = lv.plates[i].box
	return (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
end

local function slot(rec: any, status: string?): any
	return { rec = rec, status = status or "OK" }
end

return function(test)
	test("ghost tapes: every story level after L1 has steps; plates, then the bank run", function()
		for _, spec in Catalog do
			local lv = LevelSpec.compile(spec)
			local steps = GhostTapes.steps(lv.id)
			if Help.applies(lv) then
				Assert.truthy(steps ~= nil, lv.id .. " has ghost steps")
				local goals = assert(Help.ghostGoals(lv))
				Assert.eq(#goals, #(steps :: any), "one goal per step")
				for k, g in goals do
					local rec = Codec.decode(assert(GhostTapes.buffer(lv.id, k)))
					Assert.truthy(rec ~= nil, "decodes")
					if k < #goals then
						Assert.truthy(g.plate ~= nil, lv.id .. " step " .. k .. " holds a plate")
						local p, at = Help.endPlate(lv, rec)
						Assert.eq(p, g.plate, "the tape ends on its plate")
						Assert.near(at :: number, g.at :: number, 0.01, "arrival")
					else
						Assert.truthy(g.bank, "the last step banks")
					end
				end
			else
				Assert.eq(steps, nil, lv.id .. ": no ghost on the tutorial or the party")
			end
		end
	end)

	test("next step: the first plate no clone holds, then the bank; late or full decks redo", function()
		local lv = level("cs2_two_doors")
		local ax, az = plateCentre(lv, 1)
		local bx, bz = plateCentre(lv, 2)
		local goals = assert(Help.ghostGoals(lv))
		local onA = cloneTo(lv, ax, az, goals[1].at :: number, 6)
		local onB = cloneTo(lv, bx, bz, goals[2].at :: number, 6)
		local wander = cloneTo(lv, 0, 4, 2, 6)
		Assert.eq(assert(Help.nextStep(lv, {}, 4)).run, 1, "empty deck: step 1")
		Assert.eq(assert(Help.nextStep(lv, { slot(onA) }, 4)).run, 2, "A held: step 2")
		Assert.eq(assert(Help.nextStep(lv, { slot(onB) }, 4)).run, 1, "only B: step 1 (A)")
		local s = assert(Help.nextStep(lv, { slot(onA), slot(onB) }, 4))
		Assert.eq(s.run, 3, "both held: the bank run")
		Assert.eq(s.redo, nil, "nothing to redo")
		Assert.eq(assert(Help.nextStep(lv, { slot(onA, "Busted") }, 4)).run, 1, "a busted clone holds nothing")
		local late = cloneTo(lv, ax, az, (goals[1].at :: number) + O.GHOST_LATE_SLACK + 2, 12)
		local l = assert(Help.nextStep(lv, { slot(wander), slot(late) }, 4))
		Assert.eq(l.run, 1, "late on A: show step 1")
		Assert.eq(l.redo, 2, "and redo the late clone")
		local full = assert(Help.nextStep(lv, { slot(onA), slot(wander), slot(wander), slot(wander) }, 4))
		Assert.eq(full.run, 2, "full deck: step 2")
		Assert.truthy(full.full, "full")
		Assert.eq(full.redo, 2, "into the first clone the plan does not need")
		Assert.eq(#full.junk, 3, "three clones hold nothing needed")
		Assert.eq(Help.nextStep(level("cs1_back_room"), {}, 4), nil, "no ghost on L1")
	end)

	test("stuck tracker: Show me after 2 runs with no progress; Relaxed after 3 catches", function()
		local lv = level("cs4_night_clerk")
		local tr = Help.newTracker()
		local none = { held = {}, goalBanked = false, banked = false, caught = false }
		Help.afterRun(tr, none)
		Assert.falsy(Help.due(tr, lv).showMe, "one run is not stuck")
		Help.afterRun(tr, none)
		Assert.truthy(Help.due(tr, lv).showMe, "two runs: Show me?")
		Assert.truthy(Help.due(tr, lv).levelLine, "and the level line again")
		Assert.truthy(Help.afterRun(tr, { held = { [1] = true }, goalBanked = false, banked = false, caught = false }))
		Assert.falsy(Help.due(tr, lv).showMe, "a new plate is progress")
		Assert.falsy(Help.afterRun(tr, { held = { [1] = true }, goalBanked = false, banked = true, caught = true }))
		Assert.falsy(Help.due(tr, lv).levelLine, "a bank resets the level line")
		Help.afterRun(tr, { held = {}, goalBanked = false, banked = false, caught = true })
		Assert.falsy(Help.due(tr, lv).relaxed, "two catches")
		Help.afterRun(tr, { held = {}, goalBanked = false, banked = false, caught = true })
		Assert.truthy(Help.due(tr, lv).relaxed, "three catches: Try Relaxed?")
		Assert.eq(Config.Sim.RELAXED_OFFER_BUSTS, 3, "the server's offer rule matches")
		local relaxed = table.clone(lv)
		relaxed.relaxed = true
		Assert.falsy(Help.due(tr, relaxed).relaxed, "never on a relaxed level")
		local l1 = Help.newTracker()
		Help.afterRun(l1, none)
		Help.afterRun(l1, none)
		Assert.falsy(Help.due(l1, level("cs1_back_room")).showMe, "L1 has its own hints")
		Assert.falsy(Help.due(l1, level("cs5_clone_party")).showMe, "no ghost at the party")
		Assert.truthy(Help.due(l1, level("cs5_clone_party")).levelLine, "the party's level line comes back")
	end)

	test("world-state lines: stay on an unheld plate and REWIND; next plate; grab; bank", function()
		local lv = level("cs2_two_doors")
		local needed = Help.neededPlates(lv)
		Assert.truthy(needed[1] and needed[2], "both plates needed")
		local key, rewind = Help.worldLine(lv, needed, { onPlate = 1, carrying = false, deckHeld = {} })
		Assert.eq(key, "OBJ_STAY_TAP_REWIND", "on an unheld plate")
		Assert.truthy(rewind, "REWIND is the right move")
		key, rewind = Help.worldLine(lv, needed, { onPlate = 1, carrying = false, deckHeld = { [1] = true } })
		Assert.eq(key, "OBJ_NEXT_PLATE", "your clone has this one: find the next")
		Assert.falsy(rewind, "not REWIND")
		key = Help.worldLine(lv, needed, { carrying = false, deckHeld = { [1] = true, [2] = true } })
		Assert.eq(key, "OBJ_CLONES_OPEN_WAY", "every plate held")
		key = Help.worldLine(lv, needed, { carrying = true, deckHeld = {} })
		Assert.eq(key, "OBJ_BANK_IT", "carrying")
		for _, k in { "OBJ_STAY_TAP_REWIND", "OBJ_NEXT_PLATE", "OBJ_CLONES_OPEN_WAY", "OBJ_BANK_IT", "OBJ_GRAB_LOOT" } do
			Assert.truthy(type((Strings :: any)[k]) == "string", k .. " is a string")
		end
	end)

	test("every failure has one line of counterplay, 8 words or fewer (premium G4)", function()
		for _, cause in Help.CAUSE do
			local line = Help.advice(cause, nil)
			Assert.truthy(line ~= nil, cause .. " has a line")
			Assert.le(words(line :: string), 8, cause)
		end
		for id, lines in Strings.FAIL_ADVICE_LEVEL do
			for cause, line in lines do
				Assert.truthy(Help.CAUSE[cause] ~= nil, id .. ": known cause " .. cause)
				Assert.le(words(line), 8, id .. " " .. cause)
				Assert.eq(Help.advice(cause, id), line, "the level's own line wins")
			end
		end
		Assert.eq(Help.advice("Dawn", "cs4_night_clerk"), "Try: hide under the coat rack.", "L4 Dawn (PLAN §5)")
		Assert.eq(Strings.SUNRISE_COUNT, "SUNRISE! Count the loot.", "the party's ending")
	end)

	test("unlocks: the daily vault after Night Clerk; the free first catch for guarded heists", function()
		Assert.falsy((Help.dailyOpen({ BackRoom = { clears = 1, plays = 1 } })), "not after L1")
		local open, name = Help.dailyOpen({ NightClerk = { clears = 1, plays = 2 } })
		Assert.truthy(open, "after Night Clerk")
		Assert.eq(name, "Night Clerk", "the garage names it")
		Assert.falsy((Help.dailyOpen(nil)), "a new profile")
		local function spec(id: string): any
			for _, s in Catalog do
				if s.id == id then
					return s
				end
			end
			return nil
		end
		Assert.falsy(Help.graceFor(spec("cs1_back_room"), {}), "L1 has no guard: no grace spent there")
		Assert.truthy(Help.graceFor(spec("cs5_clone_party"), { BackRoom = { plays = 3 } }), "the party gets it")
		Assert.truthy(
			Help.graceFor(spec("cs4_night_clerk"), { CloneParty = { plays = 1 } }),
			"and the next guard heist"
		)
		Assert.falsy(Help.graceFor(spec("cs4_night_clerk"), { CloneParty = { plays = 2 } }), "then it is spent")
		Assert.truthy(Help.graceFor(DailyVaults.designs[4], {}), "a guarded daily too")
	end)

	test("Protocol: client and server compile the same Relaxed spec; story Catalog levels only", function()
		local Protocol = require("../../src/shared/Heist/Protocol")
		for i, spec in Catalog do
			local r = Protocol.levelSpec(i, nil, true)
			if spec.kind == "party" then
				Assert.eq(r, nil, "no Relaxed party")
			else
				Assert.truthy(r and r.relaxed == true, spec.id .. " relaxed")
				Assert.truthy(LevelSpec.compile(r).relaxed, "compiles relaxed")
				Assert.falsy(Protocol.levelSpec(i, nil, false).relaxed, "plain unless asked")
			end
		end
		Assert.eq(Protocol.levelSpec(Protocol.DAILY_INDEX, DailyVaults.FIRST_DAY, true), nil, "no Relaxed daily")
		Assert.eq(#Protocol.FTUE_STEPS, 12, "the FTUE funnel list (append only)")
	end)

	test("words: every daily vault has its own goal line; level intros stay within 30 words", function()
		for _, spec in DailyVaults.designs do
			local line = Strings.LEVEL_LINES[spec.id]
			Assert.truthy(line ~= nil, spec.id .. " has a goal line")
			Assert.le(words(line), 8, spec.id)
		end
		local l1 = 0
		for _, key in
			{
				"OBJ_STEP_ON_PLATE",
				"OBJ_STAY_ON_PLATE",
				"OBJ_CLONE_STOPS",
				"OBJ_WAIT_FOR_CLONE",
				"OBJ_GRAB_CASH",
				"OBJ_BANK_IT",
			}
		do
			-- the longest wording a kid can see: the plain line or a first-person device line (Strings.forDevice)
			local n = words((Strings :: any)[key])
			for _, device in { "key", "pad", "touch" } do
				n = math.max(n, words(Strings.forDevice(key, device, true)))
			end
			l1 += n
		end
		Assert.le(l1, 30, "L1 intro")
		for _, spec in Catalog do
			local n = words(Strings.LEVEL_LINES[spec.id] or "")
			if spec.kind == "party" then
				n += words(Strings.GUS_INTRO)
			end
			Assert.le(n, 30, spec.id .. " intro")
		end
		for _, text in
			{
				Strings.SHOW_ME,
				Strings.OBJ_WATCH_GHOST,
				Strings.ghostRedo(3),
				Strings.DECK_FULL_HELP,
				Strings.FIRST_CLONE,
				Strings.GUS_INTRO,
				Strings.RELAXED_SUB,
			}
		do
			Assert.le(words(text), 8, text)
		end
	end)
end
