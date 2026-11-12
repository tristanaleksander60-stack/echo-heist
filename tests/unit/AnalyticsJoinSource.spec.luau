-- L1: Analytics/JoinSource (launch data parsing, join classification) and Analytics/Sampling.

local Config = require("../../src/shared/Config")
local Events = require("../../src/shared/Analytics/Events")
local JoinSource = require("../../src/shared/Analytics/JoinSource")
local Sampling = require("../../src/shared/Analytics/Sampling")
local Assert = require("./Assert")

local function classify(facts: { [string]: any }): JoinSource.Result
	return JoinSource.classify(facts :: any)
end

return function(test)
	test("launch data: our v1 format parses, everything else is refused", function()
		local l = JoinSource.parseLaunchData("v1|reel|cs1_back_room") :: any
		Assert.eq(l.verb, "reel", "verb")
		Assert.eq(l.arg, "cs1_back_room", "arg")
		Assert.eq(l.tag, nil, "no tag")
		local t = JoinSource.parseLaunchData("v1|share|BackRoom|tt") :: any
		Assert.eq(t.tag, "tt", "tag")
		local e = JoinSource.parseLaunchData("v1%7Csrc%7Cyt") :: any
		Assert.eq(e and e.arg, "yt", "URL-escaped separators")
		local cases = {
			{ nil, "empty" },
			{ "", "empty" },
			{ 42, "empty" },
			{ string.rep("a", 201), "long" },
			{ "v2|src|tt", "version" },
			{ '{"src":"ads"}', "version" },
			{ "v1|src", "shape" },
			{ "v1|src|tt|x|y", "shape" },
			{ "v1|grant|500", "verb" },
			{ "v1|src|tt;drop", "arg" },
			{ "v1|src|" .. string.rep("a", 33), "arg" },
			{ "v1|reel|BackRoom|bad tag", "tag" },
		}
		for _, c in cases do
			local parsed, why = JoinSource.parseLaunchData(c[1])
			Assert.eq(parsed, nil, "refused " .. tostring(c[1]))
			Assert.eq(why, c[2], "reason for " .. tostring(c[1]))
		end
	end)

	test("build makes strings that parse back, and refuses bad parts", function()
		local s = JoinSource.build("reel", "cs4_night_clerk") :: string
		Assert.eq(s, "v1|reel|cs4_night_clerk", "reel link")
		local back = JoinSource.parseLaunchData(s) :: any
		Assert.eq(back.arg, "cs4_night_clerk", "round trip")
		Assert.eq(JoinSource.build("share", "BackRoom", "tt"), "v1|share|BackRoom|tt", "with tag")
		Assert.eq((JoinSource.build("grant", "x")), nil, "verb")
		Assert.eq((JoinSource.build("src", "a|b")), nil, "separator in arg")
		Assert.eq((JoinSource.build("src", "tt", "x y")), nil, "bad tag")
	end)

	test("classify: launch data first, then referral, follow, teleport, hint, party, organic", function()
		Assert.eq(classify({ launchData = "v1|src|ad_plays" }).source, "ad", "ad join option")
		Assert.eq(classify({ launchData = "v1|src|cr07" }).source, "creator", "creator link")
		Assert.eq(classify({ launchData = "v1|src|cr07" }).tag, "cr07", "creator tag kept")
		local beyond = string.format("v1|src|cr%02d", Config.Analytics.CREATOR_SLOTS + 1)
		Assert.eq(classify({ launchData = beyond }).tag, "invalid", "creator slot beyond the list")
		Assert.eq(classify({ launchData = "v1|src|tt" }).source, "share", "channel share link")
		Assert.eq(classify({ launchData = "v1|reel|cs1_back_room" }).source, "clip", "SAVE CLIP share")
		Assert.eq(classify({ launchData = "v1|share|BackRoom" }).tag, "player", "player share link")
		local inv = classify({ launchData = "v1|inv|BackRoom", referredBy = 99 })
		Assert.eq(inv.source, "friend", "invite")
		Assert.eq(inv.tag, "invite", "invite tag wins over referral")
		Assert.eq(classify({ referredBy = 5 }).tag, "referral", "referral link")
		Assert.eq(classify({ followUserId = 5 }).tag, "follow", "joined a friend")
		Assert.eq(classify({ sourceGameId = 7, gameId = 7 }).source, "teleport", "own teleport")
		Assert.eq(classify({ sourceGameId = 7, gameId = 8 }).source, "organic", "another game's teleport")
		Assert.eq(classify({ hint = "search" }).source, "search", "ConfigService hint")
		Assert.eq(classify({ hint = "rfy", partyId = "p" }).source, "rfy", "hint beats party")
		Assert.eq(classify({ hint = "nonsense" }).source, "organic", "unknown hint")
		Assert.eq(classify({ partyId = "abc" }).tag, "party", "party")
		Assert.eq(classify({ partyId = "" }).tag, "none", "empty party id")
		local crafted = classify({ launchData = "v1|src|free_robux" })
		Assert.eq(crafted.source, "organic", "unknown tag is not a source")
		Assert.eq(crafted.tag, "invalid", "but is visible as invalid")
		Assert.eq(classify({ launchData = "garbage", followUserId = 3 }).tag, "follow", "junk falls through")
		Assert.eq(classify({}).tag, "none", "nothing")
		for _, r in { classify({ launchData = "v1|src|ad_eng" }), classify({ referredBy = 1 }), classify({}) } do
			Assert.truthy(Events.DOMAINS.source.set[r.source], "source in domain")
			Assert.truthy(Events.DOMAINS.tag.set[r.tag], "tag in domain")
		end
	end)

	test("requested level and invite kind", function()
		local r = classify({ launchData = "v1|reel|cs2_two_doors" })
		Assert.eq(JoinSource.requestedLevel(r.launch), "cs2_two_doors", "reel opens a level")
		Assert.eq(JoinSource.requestedLevel(classify({ launchData = "v1|src|tt" }).launch), nil, "src does not")
		Assert.eq(JoinSource.inviteKind(classify({ referredBy = 1 })), "referral", "referral")
		Assert.eq(JoinSource.inviteKind(classify({ launchData = "v1|share|BackRoom" })), "share", "share")
		Assert.eq(JoinSource.inviteKind(classify({})), nil, "organic")
	end)

	test("sampling is sticky, salted and close to the asked percent", function()
		Assert.eq(Sampling.hash(""), 2166136261, "FNV offset basis")
		Assert.eq(Sampling.hash("a"), 0xE40C292C, "FNV-1a('a')")
		Assert.eq(Sampling.hash("foobar"), 0xBF9CF968, "FNV-1a('foobar')")
		local inA, inB, overlap = 0, 0, 0
		local N = 20000
		for uid = 1, N do
			local a = Sampling.inPercent(uid, "flagA", 10)
			local b = Sampling.inPercent(uid, "flagB", 10)
			Assert.eq(a, Sampling.inPercent(uid, "flagA", 10), "sticky")
			if a then
				inA += 1
				Assert.truthy(Sampling.inPercent(uid, "flagA", 25), "raising the percent keeps players in")
			end
			if b then
				inB += 1
			end
			if a and b then
				overlap += 1
			end
		end
		Assert.near(inA / N, 0.10, 0.01, "10% of players")
		Assert.near(inB / N, 0.10, 0.01, "10% for the other flag")
		Assert.near(overlap / N, 0.01, 0.005, "salts are independent")
		Assert.falsy(Sampling.inPercent(1, "x", 0), "0%")
		Assert.truthy(Sampling.inPercent(1, "x", 100), "100%")
		Assert.falsy(Sampling.inPercent(1, "x", 0 / 0), "NaN")
	end)

	test("experiment arms parse strictly and split by weight", function()
		local arms = Sampling.parseArms("base:50, a:50", Config.Analytics.VARIANTS) :: any
		Assert.eq(#arms, 2, "two arms")
		for _, bad in { "", "base", "base:x", "base:50,base:50", "zz:100", "base:0", 7 } do
			Assert.eq((Sampling.parseArms(bad, Config.Analytics.VARIANTS)), nil, "refused " .. tostring(bad))
		end
		local counts = { base = 0, a = 0 }
		local skewed = Sampling.parseArms("base:75,a:25") :: any
		for uid = 1, 8000 do
			local arm = Sampling.arm(uid, "ftueVariant", skewed)
			counts[arm] += 1
			Assert.eq(arm, Sampling.arm(uid, "ftueVariant", skewed), "sticky arm")
		end
		Assert.near(counts.base / 8000, 0.75, 0.02, "75 / 25 split")
	end)

	test("token bucket: burst, refill, no refill backwards", function()
		local b = Sampling.newBudget(3, 1, 0)
		Assert.truthy(Sampling.take(b, 0), "1")
		Assert.truthy(Sampling.take(b, 0), "2")
		Assert.truthy(Sampling.take(b, 0), "3")
		Assert.falsy(Sampling.take(b, 0), "burst used")
		Assert.falsy(Sampling.take(b, 0.5), "half a token")
		Assert.truthy(Sampling.take(b, 1), "refilled one")
		Assert.falsy(Sampling.take(b, -10), "clock moved back")
		Assert.near(Sampling.tokens(b, 100), 3, 1e-9, "capped at capacity")
		Sampling.setRate(b, 100, 0)
		Sampling.take(b, 100, 3)
		Assert.falsy(Sampling.take(b, 1000), "rate 0 never refills")
	end)
end
