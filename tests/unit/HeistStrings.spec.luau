-- L1: Shared/Heist/Strings, the words of the client UI (docs/PLAN_STEAM_PLUS.md §6.3
-- glossary, §6.1 item 1 REWIND, S5 words pass).

local Strings = require("../../src/shared/Heist/Strings")
local Assert = require("./Assert")

-- Every plain string value in Strings, nested tables included.
local function values(): { [string]: string }
	local out: { [string]: string } = {}
	for k, v in Strings :: any do
		if type(v) == "string" then
			out[k] = v
		elseif type(v) == "table" then
			for k2, v2 in v do
				if type(v2) == "string" then
					out[k .. "." .. tostring(k2)] = v2
				end
			end
		end
	end
	return out
end

local function words(text: string): number
	local n = 0
	for _ in string.gmatch(text, "%S+") do
		n += 1
	end
	return n
end

return function(test)
	test("glossary: no tape, echo, END RUN or SHUTTER in player text", function()
		for key, text in values() do
			local lower = string.lower(text)
			Assert.truthy(not string.find(lower, "tape", 1, true), key .. ": 'tape' (say clone or heist)")
			Assert.truthy(not string.find(lower, "echo", 1, true), key .. ": 'echo' (say clone)")
			Assert.truthy(not string.find(lower, "end run", 1, true), key .. ": 'END RUN' (say REWIND)")
			Assert.truthy(not string.find(lower, "shutter", 1, true), key .. ": 'SHUTTER' (say doors lock)")
		end
		Assert.truthy(not string.find(Strings.redoFrom(2), "LATER", 1, true), "no 'REDO + LATER'")
		Assert.truthy(not string.find(Strings.rewindCrew(1, 3), "END", 1, true), "co-op REWIND")
	end)

	test("REWIND is the verb: the button, the L1 line and the goal toast say it", function()
		Assert.eq(Strings.REWIND, "REWIND", "the button")
		Assert.truthy(string.find(Strings.OBJ_STAY_ON_PLATE, "REWIND", 1, true) ~= nil, "L1 line")
		Assert.truthy(string.find(Strings.GOAL_BANKED, "REWIND", 1, true) ~= nil, "goal toast")
	end)

	test("objective and level lines are 8 words or fewer (§6.2)", function()
		for key, text in values() do
			if string.sub(key, 1, 4) == "OBJ_" or string.sub(key, 1, 12) == "LEVEL_LINES." then
				Assert.le(words(text), 8, key)
			end
		end
		for _, text in { Strings.TIME_UP, Strings.CAUGHT_BY_GUS, Strings.ZAPPED_BY_LASER } do
			Assert.le(words(text), 8, text)
		end
	end)

	test("clones are named by number, the seat only for a crewmate's", function()
		Assert.eq(Strings.cloneName(1, 3, 1), "Clone 3", "yours")
		Assert.eq(Strings.cloneName(2, 3, 1), "P2 clone 3", "a crewmate's")
		Assert.eq(Strings.redoAlarmHint(3), "Clone 3 sets off the alarm. Redo it?", "RedoAlarm hint")
	end)

	test("plurals", function()
		Assert.eq(Strings.starsOpenNext(1), "1 more star opens the next heist", "one")
		Assert.eq(Strings.starsOpenNext(2), "2 more stars open the next heist", "two")
		Assert.eq(Strings.plusStars(1), "+1 STAR", "+1")
		Assert.eq(Strings.sunriseAfter(2), "Sunrise after 2 more runs", "sunrise")
	end)
end
