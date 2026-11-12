-- L1: Analytics/Funnel (forward-only steps, held steps, seeding, recurring sessions).

local Funnel = require("../../src/shared/Analytics/Funnel")
local Assert = require("./Assert")

local function same(a: { number }, b: { number }, what: string)
	Assert.eq(#a, #b, what .. " length (" .. table.concat(a, ",") .. ")")
	for i = 1, #b do
		Assert.eq(a[i], b[i], what .. " [" .. i .. "]")
	end
end

return function(test)
	test("one-time: in order, repeats dropped, forward only", function()
		local f = Funnel.oneTime("onb_v2")
		same(Funnel.reach(f, "Joined"), { 1 }, "Joined")
		same(Funnel.reach(f, "Joined"), {}, "repeat")
		same(Funnel.reach(f, "FirstPlate"), { 3 }, "skip FirstMove (Roblox counts it complete)")
		same(Funnel.reach(f, "FirstMove"), {}, "late FirstMove is below the cursor")
		same(Funnel.reach(f, 4), { 4 }, "by number")
		Assert.truthy(Funnel.isReached(f, "FirstMove"), "still remembered as reached")
	end)

	test("Minute10 waits for SwarmSeen, then both go in order", function()
		local f = Funnel.oneTime("onb_v2")
		for _, s in { "Joined", "FirstMove", "FirstPlate", "FirstRewind", "FirstCloneSeen", "FirstBank" } do
			Funnel.reach(f, s)
		end
		same(Funnel.reach(f, "Minute10"), {}, "held: no SwarmSeen yet")
		Assert.eq(Funnel.held(f)[1], "Minute10", "listed as held")
		same(Funnel.reach(f, "L1Complete"), { 7 }, "earlier steps still flow")
		same(Funnel.reach(f, "SwarmSeen"), { 11, 12 }, "SwarmSeen releases Minute10")
		Assert.eq(#Funnel.held(f), 0, "nothing held")
		same(Funnel.reach(f, "FirstCloneBusted"), {}, "implied by SwarmSeen")
	end)

	test("Minute10 never fires without SwarmSeen", function()
		local f = Funnel.oneTime("onb_v2")
		Funnel.reach(f, "Joined")
		same(Funnel.reach(f, "Minute10"), {}, "held")
		same(Funnel.reach(f, "L2Started"), { 9 }, "other steps unaffected")
		Assert.eq(f.maxLogged, 9, "cursor")
	end)

	test("seed: a returning player resumes after the saved step", function()
		local f = Funnel.oneTime("onb_v2")
		same(Funnel.seed(f, 7), {}, "nothing held to release")
		same(Funnel.reach(f, "Joined"), {}, "already sent in an earlier session")
		same(Funnel.reach(f, "FirstBank"), {}, "already sent")
		same(Funnel.reach(f, "ReelShown"), { 8 }, "next step")
		Funnel.seed(f, 3)
		Assert.eq(f.maxLogged, 8, "seed never moves back")
		Funnel.seed(f, 999)
		Assert.eq(f.maxLogged, 12, "clamped to the funnel")
	end)

	test("seed releases a held step whose requirement an earlier session met", function()
		local f = Funnel.oneTime("onb_v2")
		same(Funnel.reach(f, "Joined"), { 1 }, "Joined")
		same(Funnel.reach(f, "Minute10"), {}, "held")
		same(Funnel.seed(f, 11), { 12 }, "profile says SwarmSeen was reached")
	end)

	test("recurring sessions: forward-only per session id", function()
		local s = Funnel.session("heist_v1", "H-1", 0)
		Assert.eq(Funnel.advance(s, "HeistStarted"), 1, "start")
		Assert.eq(Funnel.advance(s, "FirstBank"), 3, "skip")
		Assert.eq(Funnel.advance(s, "FirstRewind"), nil, "backwards")
		Assert.eq(Funnel.advance(s, "FirstBank"), nil, "repeat")
		local other = Funnel.session("heist_v1", "H-2", 0)
		Assert.eq(Funnel.advance(other, "HeistStarted"), 1, "own cursor")
		Assert.falsy(pcall(Funnel.advance, s, "NoSuchStep"), "unknown step errors")
		Assert.falsy(pcall(Funnel.session, "heist_v1", "", 0), "empty id")
		Assert.falsy(pcall(Funnel.session, "nope", "x", 0), "unknown funnel")
	end)
end
