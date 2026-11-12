-- L1: Shared/Heist/CrewBoard, the pure rules of the Crew Board UI (PLAN_STEAM_PLUS §3.2, §4.3 U4-U6;
-- WALKTHROUGH P0-3 full deck, S7 stars; premium D10 count-ups).

local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local CrewBoard = require("../../src/shared/Heist/CrewBoard")
local JobCard = require("../../src/shared/Heist/JobCard")
local Strings = require("../../src/shared/Heist/Strings")
local Assert = require("./Assert")

local CU = Config.Ui.COUNT_UP

-- A recording that ends at (x, y, z), with optional events.
local function rec(x: number, y: number, z: number, events: { any }?): any
	return { n = 2, px = { 0, x }, py = { 0, y }, pz = { 0, z }, events = events or {} }
end

local function box(cx: number, cz: number): any
	return { minX = cx - 2.5, maxX = cx + 2.5, minY = -1, maxY = 6, minZ = cz - 2.5, maxZ = cz + 2.5 }
end

local LEVEL = { plates = { { id = "A", box = box(-10, -8) }, { id = "B", box = box(10, -8) } } }

return function(test)
	test("count-up: 0.35 s + 0.08 s per digit, capped at 1.0 s", function()
		Assert.near(CrewBoard.countSeconds(0, 0), CU.BASE, 1e-9, "no change")
		Assert.near(CrewBoard.countSeconds(0, 100), CU.BASE + 3 * CU.PER_DIGIT, 1e-9, "$100")
		Assert.near(CrewBoard.countSeconds(400, 1000), CU.BASE + 3 * CU.PER_DIGIT, 1e-9, "+600")
		Assert.near(CrewBoard.countSeconds(0, 1e12), CU.MAX, 1e-9, "capped")
		Assert.eq(CrewBoard.digits(0), 0, "0 digits")
		Assert.eq(CrewBoard.digits(7), 1, "1 digit")
		Assert.eq(CrewBoard.digits(-900), 3, "negative change")
	end)

	test("count-up: Quad Out, whole numbers, lands exactly on the target", function()
		local d = CrewBoard.countSeconds(0, 1000)
		Assert.eq(CrewBoard.countValue(0, 1000, 0, d), 0, "starts at from")
		Assert.eq(CrewBoard.countValue(0, 1000, d, d), 1000, "ends at to")
		Assert.eq(CrewBoard.countValue(0, 1000, d + 5, d), 1000, "holds after")
		local half = CrewBoard.countValue(0, 1000, d / 2, d)
		Assert.eq(half, 750, "Quad Out is 75 % at half time")
		local last = -1
		for i = 0, 20 do
			local v = CrewBoard.countValue(0, 1000, d * i / 20, d)
			Assert.truthy(v >= last, "never goes back")
			Assert.eq(v, math.floor(v), "whole")
			last = v
		end
		Assert.eq(CrewBoard.countValue(500, 100, 0, 0.5), 500, "counting down starts high")
		Assert.eq(CrewBoard.countValue(5, 9, 1, 0), 9, "zero duration snaps")
	end)

	test("money matches Ui.money", function()
		Assert.eq(CrewBoard.money(0), "$0", "zero")
		Assert.eq(CrewBoard.money(100), "$100", "hundred")
		Assert.eq(CrewBoard.money(1000), "$1,000", "thousand")
		Assert.eq(CrewBoard.money(1234567), "$1,234,567", "million")
	end)

	test("last action: outcomes first, then the plate it holds, then cash", function()
		local onA = rec(-10, 0, -8)
		local off = rec(0, 0, 10)
		local grab = rec(0, 0, 10, { { t = 3, kind = Codec.EVENT.Grab, arg = 1 } })
		local a = CrewBoard.lastAction("OK", onA, LEVEL)
		Assert.eq(a.kind, "plate", "on plate A")
		Assert.eq(a.plate, "A", "letter")
		Assert.eq(a.word, Strings.cardPlate("A"), "PLATE A")
		Assert.eq(a.icon, "plate", "icon")
		Assert.falsy(a.red, "not red")
		Assert.eq(CrewBoard.lastAction("New", grab, LEVEL).kind, "cash", "carried cash")
		Assert.eq(CrewBoard.lastAction("OK", off, LEVEL).kind, "walk", "walked")
		local busted = CrewBoard.lastAction("Busted", onA, LEVEL)
		Assert.eq(busted.kind, "busted", "busted beats the plate")
		Assert.truthy(busted.red, "busted is red")
		Assert.eq(busted.word, "BUSTED", "word")
		Assert.eq(CrewBoard.lastAction("Caught", off, LEVEL).kind, "busted", "caught reads busted")
		Assert.eq(CrewBoard.lastAction("Zapped", grab, LEVEL).kind, "zapped", "zapped")
		Assert.eq(CrewBoard.lastAction("Stuck", off, LEVEL).kind, "stuck", "stuck")
		Assert.eq(CrewBoard.lastAction("OK", nil, LEVEL).kind, "walk", "no recording yet")
		Assert.eq(CrewBoard.lastAction("OK", onA, nil).kind, "walk", "no level")
	end)

	test("plate letters: short ids, else by index", function()
		Assert.eq(CrewBoard.plateLetter({ id = "b" }, 2), "B", "id")
		Assert.eq(CrewBoard.plateLetter({ id = "VaultWest" }, 3), "C", "long id: index")
	end)

	test("full deck: the first card that ended off every plate pulses", function()
		local recs = { k1 = rec(-10, 0, -8), k2 = rec(0, 0, 0), k3 = rec(10, 0, -8), k4 = rec(5, 0, 5) }
		local deck = {
			cap = 4,
			slots = { { key = "k1" }, { key = "k2" }, { key = "k3" }, { key = "k4" } },
			redo = 0,
		}
		Assert.truthy(CrewBoard.isFull(deck), "full")
		Assert.eq(CrewBoard.pulseSlot(deck, recs, LEVEL), 2, "clone 2 holds nothing")
		local notFull = { cap = 5, slots = deck.slots }
		Assert.eq(CrewBoard.pulseSlot(notFull, recs, LEVEL), nil, "room left: no pulse")
		local locked = { cap = 4, slots = deck.slots, locked = true }
		Assert.falsy(CrewBoard.isFull(locked), "L1 / party decks are never full")
		local allOn = { k1 = rec(-10, 0, -8), k3 = rec(10, 0, -8) }
		Assert.eq(
			CrewBoard.pulseSlot({ cap = 2, slots = { { key = "k1" }, { key = "k3" } } }, allOn, LEVEL),
			nil,
			"all hold"
		)
		Assert.eq(CrewBoard.platesHeld(deck, recs, LEVEL), 2, "two plates held")
		local redoA = { cap = 4, slots = deck.slots, redo = 1 }
		Assert.eq(CrewBoard.platesHeld(redoA, recs, LEVEL), 1, "the REDO clone does not count")
	end)

	test("full deck: a run replaces the newest clone unless a REDO is armed", function()
		local slots = { {}, {}, {}, {} }
		Assert.eq(CrewBoard.replacedSlot({ cap = 4, slots = slots, redo = 0 }), 4, "newest replaced")
		Assert.eq(CrewBoard.replacedSlot({ cap = 4, slots = slots, redo = 2 }), nil, "redo: nothing replaced")
		Assert.eq(CrewBoard.replacedSlot({ cap = 5, slots = slots }), nil, "not full")
		Assert.eq(CrewBoard.replacedSlot(nil), nil, "no deck")
		Assert.eq(Strings.deckFullReplaced(4), "Deck full: your new clone replaced clone 4", "toast")
	end)

	test("START OVER after 2 full-deck runs with no progress", function()
		local deck = { cap = 2, slots = { {}, {} } }
		local p = CrewBoard.newProgress()
		Assert.eq(CrewBoard.noteRun(p, false, 0, 1), 0, "deck not full: no count")
		Assert.eq(CrewBoard.noteRun(p, true, 0, 1), 1, "full, nothing new")
		Assert.falsy(CrewBoard.offerStartOver(p, deck), "one run is not enough")
		Assert.eq(CrewBoard.noteRun(p, true, 0, 1), 2, "second idle run")
		Assert.truthy(CrewBoard.offerStartOver(p, deck), "offered")
		Assert.falsy(CrewBoard.offerStartOver(p, { cap = 3, slots = { {}, {} } }), "only on a full deck")
		Assert.eq(CrewBoard.noteRun(p, true, 0, 2), 0, "a new plate held resets it")
		CrewBoard.noteRun(p, true, 0, 2)
		Assert.eq(CrewBoard.noteRun(p, true, 100, 2), 0, "a bank resets it")
		Assert.eq(Config.Ui.START_OVER_RUNS, 2, "WALKTHROUGH P0-3: after 2 runs")
	end)

	test("stamp reasons use the level's real numbers", function()
		local over = { goal = 1000, par = 2 }
		Assert.eq(CrewBoard.stampReason("haul", over), "HAUL: $1,000 stolen", "haul")
		Assert.eq(CrewBoard.stampReason("crew", over), "CREW: 2 clones or fewer", "crew")
		Assert.eq(CrewBoard.stampReason("clean", over), "CLEAN: never caught", "clean")
		Assert.eq(CrewBoard.stampReason("crew", { goal = 100, par = 1 }), "CREW: 1 clone or fewer", "one clone")
	end)

	test("stamp reasons show until that star is earned once", function()
		local over = { kind = "story", stars = { haul = true, crew = false, clean = true } }
		local shown = CrewBoard.reasonsToShow(over, { seenStarHaul = true })
		Assert.falsy(shown.haul, "haul already learnt")
		Assert.truthy(shown.crew and shown.clean, "the others explain themselves")
		local seen = CrewBoard.newlySeen(over, shown)
		Assert.eq(#seen, 1, "only clean is newly learnt (crew was missed)")
		Assert.eq(seen[1], "seenStarClean", "key")
		local party = CrewBoard.reasonsToShow({ kind = "party" }, {})
		Assert.eq(next(party), nil, "party tiers need no reasons")
	end)

	test("goal lines: one per goal, met ones struck", function()
		local lines = CrewBoard.goalLines({
			kind = "story",
			banked = 600,
			goal = 1000,
			clonesUsed = 3,
			stars = { haul = false, crew = false, clean = true },
		})
		Assert.eq(#lines, 3, "three goals")
		Assert.eq(lines[1].text, "$600 of $1,000 stolen", "haul line")
		Assert.falsy(lines[1].met, "haul missed")
		Assert.eq(lines[2].text, "3 clones used", "crew line")
		Assert.eq(lines[3].text, Strings.LINE_CLEAN, "clean line")
		Assert.truthy(lines[3].met, "clean met")
		local party = CrewBoard.goalLines({ kind = "party", tiers = { 1000, 2500 }, stars = { tiers = { true } } })
		Assert.eq(#party, 2, "one per tier")
		Assert.truthy(party[1].met and not party[2].met, "tier 1 met")
	end)

	test("job board: NEXT follows the 3D board's card", function()
		local levels = {
			{ index = 1, name = "Back Room", unlocked = true, medals = { "Haul" } },
			{ index = 2, name = "Two Doors", unlocked = true, medals = {} },
			{ index = 3, name = "Clone Party", unlocked = false, medals = {} },
		}
		Assert.eq(CrewBoard.nextJob(levels), 2, "first open job without a medal")
		Assert.eq(JobCard.title(levels), "TWO DOORS", "the 3D card agrees")
		levels[2].medals = { "Haul" }
		Assert.eq(CrewBoard.nextJob(levels), nil, "all done")
		Assert.eq(CrewBoard.location({ kind = "party" }), "party", "party band")
		Assert.eq(CrewBoard.location({ kind = "story", id = "bk1_big_score" }), "bk", "bank band")
		Assert.eq(CrewBoard.location({ kind = "story", id = "cs2_two_doors" }), "cs", "shop band")
	end)

	test("job board: photos on a grid, string segments, the arc", function()
		local B = Config.Ui.BOARD
		local x1, y1 = CrewBoard.boardSlot(1)
		local x4, y4 = CrewBoard.boardSlot(B.COLUMNS + 1)
		Assert.eq(x1, x4, "same column")
		Assert.eq(y4 - y1, B.CELL[2] + B.GAP[2], "next row")
		Assert.eq(CrewBoard.boardHeight(6), B.GAP[2] + 2 * (B.CELL[2] + B.GAP[2]), "two rows")
		local cx, cy, len, rot = CrewBoard.segment(0, 0, 30, 40)
		Assert.near(cx, 15, 1e-9, "cx")
		Assert.near(cy, 20, 1e-9, "cy")
		Assert.near(len, 50, 1e-9, "length")
		Assert.near(rot, math.deg(math.atan2(40, 30)), 1e-9, "angle")
		local ax, ay = CrewBoard.arc(0, 100, 200, 0, 50, 0)
		Assert.near(ax + ay, 100, 1e-9, "starts at a")
		local bx, by = CrewBoard.arc(0, 100, 200, 0, 50, 1)
		Assert.near(bx, 200, 1e-9, "ends at b")
		Assert.near(by, 0, 1e-9, "ends at b (y)")
		local _, my = CrewBoard.arc(0, 100, 200, 100, 50, 0.5)
		Assert.truthy(my < 100, "bulges up")
	end)
end
