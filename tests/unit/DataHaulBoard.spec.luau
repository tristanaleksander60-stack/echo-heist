-- L1: Data/HaulBoard, "today's biggest haul" (LOBBY 2; MASTERPLAN §5.3 D1, §8.7; docs/DATA.md "Boards"): who may
-- board (untainted, not Relaxed, today's vault, a haul), the ranking (haul, then fewer clones, then less time; an exact
-- tie keeps the earlier entry), one entry per player (replaced only by a better run), the day reset, the KEEP cap,
-- your own rank, and the wire format (kid-safe: numbers and a cleaned display name only).

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local HaulBoard = require("../../src/shared/Data/HaulBoard")

local B = Config.Data.Board

local function run(haul: number, clones: number, timeMs: number, tainted: boolean?, relaxed: boolean?): any
	return {
		cleared = true,
		haul = haul,
		clones = clones,
		timeMs = timeMs,
		tainted = tainted == true,
		relaxed = relaxed == true,
	}
end

return function(test: (string, () -> ()) -> ())
	test("eligible: only untainted, non-Relaxed runs of today's vault with a haul", function()
		Assert.truthy(HaulBoard.eligible(run(500, 3, 20000), 10, 10), "a clean run today")
		Assert.falsy(HaulBoard.eligible(run(500, 3, 20000, true), 10, 10), "tainted (Validator)")
		Assert.falsy(HaulBoard.eligible(run(500, 3, 20000, false, true), 10, 10), "Relaxed")
		Assert.falsy(HaulBoard.eligible(run(500, 3, 20000), 9, 10), "a catch-up day")
		Assert.falsy(HaulBoard.eligible(run(0, 3, 20000), 10, 10), "an empty haul")
		local noFlag = run(500, 3, 20000)
		noFlag.tainted = nil
		Assert.falsy(HaulBoard.eligible(noFlag, 10, 10), "a missing taint flag is not trusted")
		Assert.falsy(HaulBoard.eligible(run(500.5, 3, 20000), 10, 10), "fractions")
		Assert.falsy(HaulBoard.eligible(run(0 / 0, 3, 20000), 10, 10), "NaN")
		Assert.falsy(HaulBoard.eligible(run(500, 3, -1), 10, 10), "negative time")
		Assert.falsy(HaulBoard.eligible(nil, 10, 10), "nil")
	end)

	test("ranking: bigger haul, then fewer clones, then less time; an exact tie keeps the earlier entry", function()
		local b = HaulBoard.new(10)
		HaulBoard.submit(b, 10, 1, "Ada", run(400, 3, 30000))
		HaulBoard.submit(b, 10, 2, "Bo", run(600, 5, 40000))
		HaulBoard.submit(b, 10, 3, "Cy", run(600, 4, 50000))
		HaulBoard.submit(b, 10, 4, "Di", run(600, 4, 45000))
		HaulBoard.submit(b, 10, 5, "Ed", run(600, 4, 45000)) -- an exact tie with Di, later
		local order = {}
		for _, e in HaulBoard.top(b, 10) do
			table.insert(order, e.userId)
		end
		Assert.eq(table.concat(order, ","), "4,5,3,2,1", "the order")
		local rank, e = HaulBoard.rankOf(b, 3)
		Assert.eq(rank, 3, "Cy is third")
		Assert.eq((e :: any).haul, 600, "Cy's entry")
		Assert.eq(HaulBoard.rankOf(b, 99), nil, "not on the board")
	end)

	test("one entry per player: a worse run changes nothing, a better one replaces it", function()
		local b = HaulBoard.new(10)
		HaulBoard.submit(b, 10, 1, "Ada", run(400, 3, 30000))
		HaulBoard.submit(b, 10, 2, "Bo", run(500, 3, 30000))
		local changed, rank = HaulBoard.submit(b, 10, 1, "Ada", run(300, 1, 1000))
		Assert.falsy(changed, "a smaller haul does not replace")
		Assert.eq(rank, 2, "still second")
		local changed2, rank2 = HaulBoard.submit(b, 10, 1, "Ada", run(700, 6, 50000))
		Assert.truthy(changed2, "a bigger haul replaces")
		Assert.eq(rank2, 1, "first now")
		Assert.eq(#b.entries, 2, "one entry each")
	end)

	test("a new day empties the board; KEEP caps it; the top shows SHOW rows", function()
		local b = HaulBoard.new(10)
		for i = 1, B.KEEP + 5 do
			HaulBoard.submit(b, 10, i, "P" .. i, run(1000 + i, 3, 30000))
		end
		Assert.eq(#b.entries, B.KEEP, "kept to KEEP")
		Assert.eq(b.entries[1].userId, B.KEEP + 5, "the biggest first")
		Assert.eq(HaulBoard.rankOf(b, 1), nil, "the smallest fell off")
		Assert.eq(#HaulBoard.top(b), B.SHOW, "the laptop shows SHOW rows")
		local changed, rank = HaulBoard.submit(b, 11, 7, "P7", run(50, 3, 30000))
		Assert.truthy(changed, "a new day")
		Assert.eq(rank, 1, "the only entry of the new day")
		Assert.eq(#b.entries, 1, "yesterday is gone")
		Assert.eq(b.day, 11, "the board's day")
	end)

	test("wire format: rank order round-trips; names are cleaned; junk rows are skipped", function()
		local b = HaulBoard.new(10)
		HaulBoard.submit(b, 10, 1, "Ada;evil,|name", run(400, 3, 30000))
		HaulBoard.submit(b, 10, 2, "Bo", run(500, 2, 20000))
		local text = HaulBoard.encode(HaulBoard.top(b))
		local rows = HaulBoard.decode(text)
		Assert.eq(#rows, 2, "two rows")
		Assert.eq(rows[1].userId, 2, "rank order kept")
		Assert.eq(rows[2].name, "Adaevilname", "separators stripped")
		Assert.eq(rows[1].clones, 2, "clones")
		Assert.eq(rows[1].timeMs, 20000, "time")
		Assert.eq(#HaulBoard.decode(text .. ";x,y;1,2,3"), 2, "junk rows skipped")
		Assert.eq(#HaulBoard.decode(nil), 0, "nothing")
		Assert.eq(HaulBoard.cleanName(""), "?", "never empty")
		local long = HaulBoard.cleanName(string.rep("A", 40))
		Assert.eq(#long, B.NAME_MAX, "capped")
	end)
end
