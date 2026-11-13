-- L1: Quick Crew (LOBBY 2; MASTERPLAN §3.3 strangers only through the opt-in; Config.Hideout.QUICK): the pure
-- matching (Shared/Heist/QuickCrew: the oldest open van, the longest-waiting seeker, the seat cap, held seats lapse
-- and requeue, MAX_MISSES opts out, a closed van gives its seats back), the new Heist.Ready ops in the validator
-- (VanRules.validAction: quick / unquick / open / shut / style), the van rules for strangers (VanRules.setOpen,
-- canSit: never into a van that is not open, never past MAX_CREW) and the client's pure bits (LobbyLook.quickButtons,
-- quickAction, arrow).

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local QuickCrew = require("../../src/shared/Heist/QuickCrew")
local VanRules = require("../../src/shared/Heist/VanRules")
local LobbyLook = require("../../src/shared/Heist/LobbyLook")

local HD = Config.Hideout
local Q = HD.QUICK
local MODE = VanRules.MODE
local CAP = math.min(Config.Sim.MAX_CREW, #HD.VAN.SEATS)

local function openVan(bay: number, size: number, at: number, leader: number?): QuickCrew.OpenVan
	return { bay = bay, crewSize = size, openedAt = at, leaderId = leader or -bay }
end

return function(test: (string, () -> ()) -> ())
	test("validator: the LOBBY 2 ops pass with exactly their keys, and nothing else does", function()
		local good = {
			{ op = "quick" },
			{ op = "unquick" },
			{ op = "open", bay = 3 },
			{ op = "shut", bay = 3 },
			{ op = "style", bay = 3, n = 2 },
		}
		for _, a in good do
			Assert.truthy(VanRules.validAction(a), "valid " .. a.op)
			Assert.truthy(VanRules.validReadyArg(a), "ready arg " .. a.op)
		end
		local bad: { any } = {
			{ op = "quick", bay = 1 }, -- quick takes no bay
			{ op = "unquick", n = 1 },
			{ op = "open" }, -- needs the bay
			{ op = "shut" },
			{ op = "style", bay = 3 }, -- needs n
			{ op = "style", bay = 3, n = 0 },
			{ op = "style", bay = 3, n = 1.5 },
			{ op = "style", bay = 3, n = 0 / 0 },
			{ op = "open", bay = HD.BAYS + 1 },
			{ op = "claim", bay = 1, n = 1 }, -- n only where an op takes it
			{ op = "ready", bay = 2 }, -- a bay only where an op takes it
			{ op = "quick", who = 5 },
			{ op = "match", bay = 1 },
		}
		for i, a in bad do
			Assert.falsy(VanRules.validAction(a), "invalid #" .. i)
			Assert.falsy(VanRules.validReadyArg(a), "invalid ready arg #" .. i)
		end
	end)

	test("matching: oldest open van first, longest-waiting seeker first, never past the seat cap", function()
		local st = QuickCrew.new()
		QuickCrew.optIn(st, 11, 10)
		QuickCrew.optIn(st, 12, 11)
		QuickCrew.optIn(st, 13, 12)
		QuickCrew.optIn(st, 14, 13)
		QuickCrew.optIn(st, 15, 14)
		local ok, code = QuickCrew.optIn(st, 11, 99)
		Assert.truthy(ok and code == "Already", "opting in twice keeps your place")
		-- bay 5 opened first with 2 in its crew (room for 2), bay 2 later alone (room for 3)
		local vans = { openVan(2, 1, 50), openVan(5, 2, 40) }
		local res = QuickCrew.pass(st, vans, 60)
		Assert.eq(#res.matched, 5, "five seats for five seekers")
		Assert.eq(QuickCrew.holdOf(st, 11), 5, "the first seeker into the oldest van")
		Assert.eq(QuickCrew.holdOf(st, 12), 5, "the second too")
		Assert.eq(QuickCrew.holdOf(st, 13), 2, "then the next van")
		Assert.eq(QuickCrew.heldIn(st, 5), CAP - 2, "bay 5 full")
		Assert.eq(QuickCrew.heldIn(st, 2), 3, "bay 2 full")
		for _, v in vans do
			Assert.le(v.crewSize + QuickCrew.heldIn(st, v.bay), CAP, "crew + held <= MAX_CREW in bay " .. v.bay)
		end
		-- a sixth seeker waits: no room anywhere
		QuickCrew.optIn(st, 16, 61)
		local res2 = QuickCrew.pass(st, vans, 62)
		Assert.eq(#res2.matched, 0, "no room: waiting")
		Assert.eq(QuickCrew.holdOf(st, 16), nil, "still waiting")
		local waiting, open = QuickCrew.counts(st, vans)
		Assert.eq(waiting, 1, "one waiting")
		Assert.eq(open, 0, "no van with room")
	end)

	test("a van leader is never matched into their own van; a full van gets nobody", function()
		local st = QuickCrew.new()
		QuickCrew.optIn(st, 7, 1)
		local res = QuickCrew.pass(st, { openVan(3, 1, 0, 7) }, 2)
		Assert.eq(#res.matched, 0, "not into your own van")
		local res2 = QuickCrew.pass(st, { openVan(3, 1, 0, 7), openVan(4, CAP, 0) }, 3)
		Assert.eq(#res2.matched, 0, "a full van takes nobody")
		local res3 = QuickCrew.pass(st, { openVan(3, 1, 0, 7), openVan(6, 1, 5) }, 4)
		Assert.eq(#res3.matched, 1, "the next open van with room")
		Assert.eq(QuickCrew.holdOf(st, 7), 6, "bay 6")
	end)

	test("holds: lapse after RESERVE_SECONDS and requeue at the back; MAX_MISSES lapses opt you out", function()
		local st = QuickCrew.new()
		QuickCrew.optIn(st, 21, 0)
		QuickCrew.optIn(st, 22, 1)
		local vans = { openVan(1, 3, 0) } -- one free seat
		QuickCrew.pass(st, vans, 2)
		Assert.eq(QuickCrew.holdOf(st, 21), 1, "21 holds the seat")
		local early = QuickCrew.pass(st, vans, 2 + Q.RESERVE_SECONDS - 1)
		Assert.eq(#early.requeued, 0, "still held before RESERVE_SECONDS")
		local late = QuickCrew.pass(st, vans, 2 + Q.RESERVE_SECONDS)
		Assert.truthy(table.find(late.requeued, 21) ~= nil, "21's hold lapsed")
		Assert.eq(QuickCrew.holdOf(st, 22), 1, "22, now first in line, gets the seat")
		Assert.eq(QuickCrew.holdOf(st, 21), nil, "21 waits at the back")
		-- 22 lapses MAX_MISSES times in a row: opted out
		local t = 2 + Q.RESERVE_SECONDS
		local dropped = false
		for _ = 1, Q.MAX_MISSES * 2 do
			t += Q.RESERVE_SECONDS
			local r = QuickCrew.pass(st, vans, t)
			if table.find(r.dropped, 22) then
				dropped = true
				break
			end
		end
		Assert.truthy(dropped, "away from the keyboard: opted out")
		Assert.falsy(QuickCrew.isSeeking(st, 22), "22 is out")
	end)

	test("a van that closes or leaves gives its held seats back at once, keeping the seekers' place", function()
		local st = QuickCrew.new()
		QuickCrew.optIn(st, 31, 0)
		QuickCrew.optIn(st, 32, 1)
		QuickCrew.pass(st, { openVan(4, 1, 0) }, 2)
		Assert.eq(QuickCrew.heldIn(st, 4), 2, "two held")
		local back = QuickCrew.release(st, 4)
		Assert.eq(#back, 2, "both back")
		Assert.eq(QuickCrew.heldIn(st, 4), 0, "none held")
		-- the van is simply gone from the next pass: its holds requeue
		QuickCrew.pass(st, { openVan(4, 1, 0) }, 3)
		local r = QuickCrew.pass(st, {}, 4)
		Assert.eq(#r.requeued, 2, "a van that went: its holds requeue")
		Assert.truthy(QuickCrew.isSeeking(st, 31) and QuickCrew.isSeeking(st, 32), "still seeking")
		-- the crew grew another way (a friend joined): the overflow hold goes back
		QuickCrew.pass(st, { openVan(5, CAP - 2, 0) }, 5)
		Assert.eq(QuickCrew.heldIn(st, 5), 2, "two held in bay 5")
		local r2 = QuickCrew.pass(st, { openVan(5, CAP - 1, 0) }, 6)
		Assert.eq(#r2.requeued, 1, "overflow: only the newest hold goes back")
		Assert.eq(QuickCrew.holdOf(st, 31), 5, "the older seeker keeps the seat")
		Assert.le(QuickCrew.heldIn(st, 5), 1, "never past the cap")
		-- opt out any time
		Assert.truthy(QuickCrew.drop(st, 31), "opted out")
		Assert.falsy(QuickCrew.drop(st, 31), "already out")
	end)

	test("van rules: a stranger sits only in an OPEN van, only with a held seat, and the cap holds", function()
		local st = VanRules.new()
		local host: VanRules.Crew = { id = 1, leaderId = 101, members = { 101 } }
		VanRules.claim(st, 2, host, 101, 1)
		local v = VanRules.van(st, 2) :: VanRules.Van
		Assert.falsy(v.open, "a claimed van is not open")
		-- not open: no stranger, held seat or not
		VanRules.setMode(st, 2, host, 101, MODE.Crew, 1)
		local okA, codeA = VanRules.canSit(st, 2, { userId = 501, crewId = 50, friend = false, quick = true }, 1, 1)
		Assert.falsy(okA, "never into a van that is not open")
		Assert.eq(codeA, "NotFriend", "code")
		-- the leader opens it (from the sign: dist 0); a member cannot
		local member: VanRules.Crew = { id = 1, leaderId = 101, members = { 101 } }
		Assert.falsy(VanRules.setOpen(st, 2, member, 102, true, 5, 0), "only the leader opens")
		Assert.falsy(VanRules.setOpen(st, 2, host, 101, true, 5, HD.SERVER_REACH + 1), "too far")
		local okO, codeO = VanRules.setOpen(st, 2, host, 101, true, 5, 0)
		Assert.truthy(okO and codeO == "Ok" and v.open and v.openedAt == 5, "open")
		-- open: a stranger with no held seat is still refused; with one, joins
		local okB, codeB = VanRules.canSit(st, 2, { userId = 502, crewId = 51, friend = false }, 1, 1)
		Assert.falsy(okB, "no held seat")
		Assert.eq(codeB, "NotMatched", "code")
		local okC, codeC = VanRules.canSit(st, 2, { userId = 501, crewId = 50, friend = false, quick = true }, 1, 1)
		Assert.truthy(okC and codeC == "Join", "a held seat joins the crew")
		-- the cap: crew + held seats of others at MAX_CREW: full
		local okD, codeD = VanRules.canSit(st, 2, { userId = 503, crewId = 52, friend = false, quick = true }, CAP, 1)
		Assert.falsy(okD, "full")
		Assert.eq(codeD, "Full", "code")
		-- parking closes it to Quick Crew; opening a parked van opens its side door
		Assert.truthy(VanRules.setMode(st, 2, host, 101, MODE.Parked, 1), "park")
		Assert.falsy(v.open, "a parked van is closed to Quick Crew")
		Assert.truthy(VanRules.setOpen(st, 2, host, 101, true, 9, 0), "open a parked van")
		Assert.eq(v.mode, MODE.Crew, "its side door opens")
		Assert.truthy(VanRules.setOpen(st, 2, host, 101, false, 9, nil), "closing works from anywhere")
		Assert.falsy(v.open, "closed")
		-- a full crew cannot open; a van on a job cannot
		local full: VanRules.Crew = { id = 3, leaderId = 301, members = { 301, 302, 303, 304 } }
		VanRules.claim(st, 4, full, 301, 1)
		local okF, codeF = VanRules.setOpen(st, 4, full, 301, true, 1, 0)
		Assert.falsy(okF, "a full crew")
		Assert.eq(codeF, "Full", "code")
		VanRules.setAway(st, 2)
		Assert.falsy(VanRules.setOpen(st, 2, host, 101, true, 1, 0), "a van on a job")
		-- a moved crew stays open
		local mover: VanRules.Crew = { id = 6, leaderId = 601, members = { 601 } }
		VanRules.claim(st, 6, mover, 601, 1)
		VanRules.setOpen(st, 6, mover, 601, true, 3, 0)
		VanRules.claim(st, 7, mover, 601, 1)
		local moved = VanRules.van(st, 7) :: VanRules.Van
		Assert.truthy(moved.open and moved.mode == MODE.Crew and moved.openedAt == 3, "open after a move")
	end)

	test("the sheet: your buttons, their actions pass the validator, the waypoint arrow", function()
		local flags = { quick = true, invites = true }
		local b1 = LobbyLook.quickButtons({ leader = true, crewSize = 1, seeking = false, vanBay = 0 }, flags)
		Assert.eq(b1[1], "look", "alone: LOOK FOR A CREW")
		Assert.eq(b1[#b1], "invite", "INVITE FRIENDS last")
		local b2 = LobbyLook.quickButtons({ leader = true, crewSize = 1, seeking = true, vanBay = 0 }, flags)
		Assert.eq(b2[1], "stop", "looking: STOP")
		local b3, info3 = LobbyLook.quickButtons(
			{ leader = true, crewSize = 2, seeking = false, vanBay = 4, vanOpen = false, vanMode = "crew" },
			flags
		)
		Assert.eq(b3[1], "open", "a leader with a van: OPEN MY VAN")
		Assert.eq(info3, "leader", "the leader's info")
		Assert.falsy(table.find(b3, "look"), "a crew of two does not look for another")
		local b4 = LobbyLook.quickButtons(
			{ leader = true, crewSize = 2, seeking = false, vanBay = 4, vanOpen = true, vanMode = "crew" },
			flags
		)
		Assert.eq(b4[1], "shut", "open: CLOSE MY VAN")
		local b5, info5 = LobbyLook.quickButtons({ leader = false, crewSize = 2, seeking = false, vanBay = 4 }, flags)
		Assert.eq(info5, "needSolo", "a member is told to leave first")
		Assert.falsy(table.find(b5, "look"), "no LOOK in a crew")
		local b6, info6 = LobbyLook.quickButtons(
			{ leader = true, crewSize = 1, seeking = false, vanBay = 0 },
			{ quick = false, invites = false }
		)
		Assert.eq(#b6, 0, "Quick Crew off: no buttons")
		Assert.eq(info6, "paused", "paused")
		for _, b in { "look", "stop", "open", "shut" } do
			local a = LobbyLook.quickAction(b, 4)
			Assert.truthy(a ~= nil and VanRules.validReadyArg(a), b .. " passes Heist.Ready's validator")
		end
		Assert.eq(LobbyLook.quickAction("invite", 4), nil, "INVITE is the Roblox prompt, not a server op")
		Assert.eq(LobbyLook.quickAction("open", 0), nil, "no van: no OPEN")
		-- the arrow: ahead of you toward the van, pointing at it, hidden when you are close
		local x, z, yaw, show = LobbyLook.arrow({ 0, 0 }, { 0, -20 })
		Assert.near(x, 0, 1e-6, "x")
		Assert.near(z, -Q.ARROW.ahead, 1e-6, "ahead toward the van")
		Assert.near(yaw, 0, 1e-6, "yaw 0 looks along -Z")
		Assert.truthy(show, "shown far away")
		local _, _, yaw2 = LobbyLook.arrow({ 0, 0 }, { 10, 0 })
		local r = math.rad(yaw2)
		Assert.near(-math.sin(r), 1, 1e-6, "its look vector points at the van (+X)")
		local _, _, _, near = LobbyLook.arrow({ 0, 0 }, { Q.ARROW.hideWithin - 1, 0 })
		Assert.falsy(near, "hidden at the door")
	end)
end
