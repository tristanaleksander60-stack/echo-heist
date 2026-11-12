-- L1: shared/Sim small pieces: Geom conventions, Rng, EventLog hash, Deck, Scoring.

local Assert = require("./Assert")
local Deck = require("../../src/shared/Sim/Deck")
local EventLog = require("../../src/shared/Sim/EventLog")
local Geom = require("../../src/shared/Sim/Geom")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Rng = require("../../src/shared/Sim/Rng")
local Scoring = require("../../src/shared/Sim/Scoring")

return function(test)
	test("yaw convention matches the recordings: yaw 0 faces -Z", function()
		local fx, fz = Geom.forward(0)
		Assert.near(fx, 0, 1e-12, "fx")
		Assert.near(fz, -1, 1e-12, "fz")
		Assert.near(Geom.yawTo(0, 0, 1, 0), 3 * math.pi / 2, 1e-12, "east is 270 deg")
		Assert.near(Geom.yawTo(0, 0, -1, 0), math.pi / 2, 1e-12, "west is 90 deg")
		Assert.near(Geom.angleDelta(math.rad(350), math.rad(10)), math.rad(20), 1e-12, "wraps")
		Assert.near(Geom.turnToward(0, math.pi / 2, 0.1), 0.1, 1e-12, "turn capped")
	end)

	test("segment-vs-box: crossing, starting inside, grazing", function()
		local b = Geom.box(0, 5, 0, 2, 10, 2)
		Assert.truthy(Geom.moveBlocked(b, -5, 3, 0, 5, 3, 0), "crosses")
		Assert.falsy(Geom.moveBlocked(b, 0, 3, 0, 5, 3, 0), "starts inside: can walk out")
		Assert.falsy(Geom.moveBlocked(b, -5, 3, 3, 5, 3, 3), "misses")
		Assert.truthy(Geom.touches(b, 0, 3, 0, 0.5, 3, 0), "touch from inside")
	end)

	test("Rng: same seed, same sequence; Roblox Random method shape", function()
		local a, b = Rng.new(42), Rng.new(42)
		for _ = 1, 100 do
			Assert.eq(a:NextInteger(1, 1000), b:NextInteger(1, 1000), "integers")
			Assert.eq(a:NextNumber(), b:NextNumber(), "numbers")
		end
		local c, d = Rng.new(1), Rng.new(2)
		local same = 0
		for _ = 1, 50 do
			if c:NextInteger(1, 1000) == d:NextInteger(1, 1000) then
				same += 1
			end
		end
		Assert.le(same, 3, "seeds 1 and 2 diverge")
		local r = Rng.new(7)
		for _ = 1, 500 do
			local v = r:NextInteger(0, 3)
			Assert.truthy(v >= 0 and v <= 3 and v == math.floor(v), "NextInteger in range")
			local f = r:NextNumber(2, 5)
			Assert.truthy(f >= 2 and f < 5, "NextNumber in range")
		end
	end)

	test("EventLog hash is stable and order sensitive", function()
		local a = EventLog.new()
		EventLog.append(a, 0, EventLog.EV.RunStart, 1, 0, 1)
		EventLog.append(a, 26, EventLog.EV.PlateDown, 1, 1)
		local b = EventLog.copy(a)
		Assert.eq(EventLog.hash(a), EventLog.hash(b), "copy hashes the same")
		-- Pinned value: the encoding (u32 tick, u8 kind, 3 x i32) and FNV-1a must not drift.
		Assert.eq(EventLog.hash(a), 1771266489, "pinned hash")
		local c = EventLog.new()
		EventLog.append(c, 26, EventLog.EV.PlateDown, 1, 1)
		EventLog.append(c, 0, EventLog.EV.RunStart, 1, 0, 1)
		Assert.truthy(EventLog.hash(a) ~= EventLog.hash(c), "order matters")
		EventLog.clear(a)
		Assert.eq(a.n, 0, "cleared")
		Assert.eq(EventLog.hash(a), 2166136261, "empty log is the FNV offset basis")
		Assert.truthy(EventLog.fold(1, 2) ~= EventLog.fold(2, 1), "fold is order sensitive")
	end)

	test("Deck: append, full deck replaces the newest, redo, redo-from, delete, undo", function()
		local d = Deck.new(3)
		for r = 1, 3 do
			Assert.eq(Deck.commit(d, { r = r }, r, "New"), r, "append " .. r)
		end
		Assert.eq(Deck.commit(d, { r = 4 }, 4, "New"), 3, "full: replaces the newest")
		Assert.eq(d.slots[3].rec.r, 4, "slot 3 is run 4")
		Assert.truthy(Deck.undoLast(d), "undo")
		Assert.eq(d.slots[3].rec.r, 3, "run 3 back")
		Assert.falsy(Deck.undoLast(d), "only one level of undo")
		Assert.truthy(Deck.redo(d, 2), "redo #2")
		Assert.falsy(Deck.replays(d, 2), "slot 2 not replayed")
		Assert.truthy(Deck.replays(d, 1), "slot 1 replayed")
		Assert.eq(Deck.commit(d, { r = 5 }, 5, "New"), 2, "redo lands in slot 2")
		Assert.eq(#d.slots, 3, "still 3")
		Assert.truthy(Deck.redoFrom(d, 1), "redo from #1")
		Assert.eq(#d.slots, 1, "slots after 1 deleted")
		Assert.eq(Deck.commit(d, { r = 6 }, 6, "New"), 1, "re-records #1")
		Assert.truthy(Deck.delete(d, 1), "delete")
		Assert.eq(#d.slots, 0, "empty")
		Assert.falsy(Deck.delete(d, 1), "nothing to delete")
		Assert.falsy(Deck.redo(d, 1), "nothing to redo")
	end)

	test("Deck: delete busted removes every red-flagged slot and is undoable", function()
		local d = Deck.new(4)
		Deck.commit(d, {}, 1, "OK")
		Deck.commit(d, {}, 2, "Busted")
		Deck.commit(d, {}, 3, "Zapped")
		Deck.commit(d, {}, 4, "Shrug")
		Assert.eq(Deck.deleteBusted(d), 2, "two red")
		Assert.eq(#d.slots, 2, "two left")
		Assert.eq(d.slots[2].status, "Shrug", "shrug is not red")
		Assert.truthy(Deck.undoLast(d), "undo")
		Assert.eq(#d.slots, 4, "restored")
	end)

	test("crew cap = min(level.cap, floor(12 / crewSize)) (§0 C3)", function()
		Assert.eq(HeistSim.capFor(8, 1), 8, "8/1")
		Assert.eq(HeistSim.capFor(8, 2), 6, "8/2")
		Assert.eq(HeistSim.capFor(8, 3), 4, "8/3")
		Assert.eq(HeistSim.capFor(8, 4), 3, "8/4")
		Assert.eq(HeistSim.capFor(4, 2), 4, "teaching level 4/2")
		Assert.eq(HeistSim.capFor(3, 1), 3, "L1 solo")
	end)

	test("Scoring: Haul, Crew, Clean; taint earns nothing", function()
		local base = {
			complete = true,
			banked = 200,
			goal = 200,
			clonesUsed = 2,
			par = 2,
			catchesFinal = 0,
			bustedFinal = 0,
			tainted = false,
		}
		Assert.eq(Scoring.stars(base).count, 3, "3 stars")
		local over = table.clone(base)
		over.clonesUsed = 3
		local s = Scoring.stars(over)
		Assert.falsy(s.crew, "over par")
		Assert.eq(s.count, 2, "2 stars")
		local dirty = table.clone(base)
		dirty.bustedFinal = 1
		Assert.falsy(Scoring.stars(dirty).clean, "busted clone in the final run")
		local dawn = table.clone(base)
		dawn.complete = false
		dawn.banked = 100
		Assert.eq(Scoring.stars(dawn).count, 0, "Dawn without the goal")
		local tainted = table.clone(base)
		tainted.tainted = true
		Assert.eq(Scoring.stars(tainted).count, 0, "tainted")
	end)
end
