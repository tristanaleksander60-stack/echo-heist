-- L1: the van's PARTY sheet (PARTY track, Config.Hideout.PARTY): the new Heist.Ready ops in the validator
-- (VanRules.validAction: size / privacy / kick with their own n ranges), the rules (VanRules.setSize never below the
-- seats taken and opens a parked van; setPrivacy FRIENDS ONLY / OPEN / INVITE ONLY with the Quick Crew open and
-- close; kick frees the seat and blocks the player for KICK_BLOCK_SECONDS), canSit respecting the size and the
-- privacy, Quick Crew matching only open vans with free seats under the size and never a kicked player, and the
-- client's pure bits (LobbyLook.partySheet, partyAction, vanCard).

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local LobbyLook = require("../../src/shared/Heist/LobbyLook")
local QuickCrew = require("../../src/shared/Heist/QuickCrew")
local Strings = require("../../src/shared/Heist/Strings")
local VanRules = require("../../src/shared/Heist/VanRules")

local HD = Config.Hideout
local P = HD.PARTY
local MODE = VanRules.MODE
local CAP = math.min(Config.Sim.MAX_CREW, #HD.VAN.SEATS)
local FRIENDS = table.find(P.PRIVACY, "friends") :: number
local OPEN = table.find(P.PRIVACY, "open") :: number
local INVITE = table.find(P.PRIVACY, "invite") :: number

local function crew(id: number, members: { number }): VanRules.Crew
	return { id = id, leaderId = members[1], members = members }
end

return function(test: (string, () -> ()) -> ())
	test("validator: size / privacy / kick need a bay and an n in their own range", function()
		local good = {
			{ op = "size", bay = 2, n = P.MIN_SIZE },
			{ op = "size", bay = 2, n = CAP },
			{ op = "privacy", bay = 2, n = 1 },
			{ op = "privacy", bay = 2, n = #P.PRIVACY },
			{ op = "kick", bay = 2, n = 2 },
			{ op = "kick", bay = 2, n = #HD.VAN.SEATS },
		}
		for _, a in good do
			Assert.truthy(VanRules.validReadyArg(a), "valid " .. a.op .. " " .. a.n)
		end
		local bad: { any } = {
			{ op = "size", bay = 2 },
			{ op = "size", n = 3 },
			{ op = "size", bay = 2, n = 1 }, -- SOLO is park, not size 1
			{ op = "size", bay = 2, n = CAP + 1 },
			{ op = "privacy", bay = 2, n = 0 },
			{ op = "privacy", bay = 2, n = #P.PRIVACY + 1 },
			{ op = "privacy", bay = 2, n = 1.5 },
			{ op = "kick", bay = 2, n = 1 }, -- never the driver
			{ op = "kick", bay = 2, n = #HD.VAN.SEATS + 1 },
			{ op = "kick", bay = 2, n = 0 / 0 },
			{ op = "kick", bay = 2, n = 2, who = 5 },
		}
		for i, a in bad do
			Assert.falsy(VanRules.validReadyArg(a), "invalid #" .. i)
		end
	end)

	test("size: the leader near the van, MIN_SIZE..cap, never below the seats taken; a parked van opens", function()
		local st = VanRules.new()
		local a = crew(1, { 101 })
		VanRules.claim(st, 2, a, 101, 1)
		local v = VanRules.van(st, 2) :: VanRules.Van
		Assert.eq(v.size, CAP, "a claimed van takes every seat")
		Assert.eq(v.privacy, P.PRIVACY[P.DEFAULT_PRIVACY], "and starts friends only")
		local ok, code = VanRules.setSize(st, 2, a, 101, 2, 1, 1)
		Assert.truthy(ok and code == "Ok" and v.size == 2 and v.mode == MODE.Crew, "size 2 opens the side door")
		Assert.eq(VanRules.capOf(v), 2, "capOf")
		Assert.falsy(VanRules.setSize(st, 2, a, 202, 3, 1, 1), "a member cannot")
		Assert.falsy(VanRules.setSize(st, 2, a, 101, 3, 1, HD.SERVER_REACH + 1), "too far")
		local okB, codeB = VanRules.setSize(st, 2, a, 101, 1, 1, 1)
		Assert.truthy(not okB and codeB == "BadSize", "below MIN_SIZE")
		local okC, codeC = VanRules.setSize(st, 2, a, 101, CAP + 1, 1, 1)
		Assert.truthy(not okC and codeC == "BadSize", "past the seats")
		local three = crew(1, { 101, 102, 103 })
		local okT, codeT = VanRules.setSize(st, 2, three, 101, 2, 3, 1)
		Assert.truthy(not okT and codeT == "BelowTaken", "never below the members")
		local okH, codeH = VanRules.setSize(st, 2, a, 101, 2, 3, 1)
		Assert.truthy(not okH and codeH == "BelowTaken", "never below members + held seats")
		-- moving vans keeps the party settings
		VanRules.setSize(st, 2, a, 101, 3, 1, 1)
		VanRules.claim(st, 5, a, 101, 1)
		local moved = VanRules.van(st, 5) :: VanRules.Van
		Assert.truthy(moved.size == 3 and VanRules.van(st, 2) == nil, "the size moves with the crew")
	end)

	test("privacy: FRIENDS ONLY / OPEN / INVITE ONLY; OPEN is the Quick Crew open", function()
		local st = VanRules.new()
		local a = crew(1, { 101 })
		VanRules.claim(st, 2, a, 101, 1)
		local v = VanRules.van(st, 2) :: VanRules.Van
		local okO = VanRules.setPrivacy(st, 2, a, 101, OPEN, 5, 1)
		Assert.truthy(okO and v.open and v.privacy == "open" and v.mode == MODE.Crew, "OPEN opens to Quick Crew")
		Assert.eq(v.openedAt, 5, "opened at")
		local okI = VanRules.setPrivacy(st, 2, a, 101, INVITE, 6, 1)
		Assert.truthy(okI and not v.open and v.privacy == "invite", "INVITE ONLY closes it to strangers")
		local okF = VanRules.setPrivacy(st, 2, a, 101, FRIENDS, 7, 1)
		Assert.truthy(okF and not v.open and v.privacy == "friends", "FRIENDS ONLY")
		Assert.falsy(VanRules.setPrivacy(st, 2, a, 202, OPEN, 8, 1), "a member cannot")
		local okX, codeX = VanRules.setPrivacy(st, 2, a, 101, 9, 8, 1)
		Assert.truthy(not okX and codeX == "BadPrivacy", "unknown privacy")
		-- the Quick Crew sheet's CLOSE MY VAN goes back to friends only
		VanRules.setPrivacy(st, 2, a, 101, OPEN, 9, 1)
		VanRules.setOpen(st, 2, a, 101, false, 10, nil)
		Assert.truthy(not v.open and v.privacy == "friends", "closing = friends only")
		-- OPEN when the size is already full is refused (nobody could come)
		local two = crew(1, { 101, 102 })
		VanRules.setSize(st, 2, two, 101, 2, 2, 1)
		local okFull, codeFull = VanRules.setPrivacy(st, 2, two, 101, OPEN, 11, 1)
		Assert.truthy(not okFull and codeFull == "Full", "a full crew is not opened")
	end)

	test("canSit: the size caps the seats, the privacy picks who walks in", function()
		local st = VanRules.new()
		local a = crew(1, { 101 })
		VanRules.claim(st, 2, a, 101, 1)
		VanRules.setSize(st, 2, a, 101, 2, 1, 1)
		local friend = { userId = 202, crewId = 9, friend = true }
		local stranger = { userId = 303, crewId = 8, friend = false }
		Assert.truthy(VanRules.canSit(st, 2, friend, 1, 1), "size 2, friends only: a friend sits")
		local okS, codeS = VanRules.canSit(st, 2, stranger, 1, 1)
		Assert.truthy(not okS and codeS == "NotFriend", "a stranger cannot")
		local okCap, codeCap = VanRules.canSit(st, 2, { userId = 204, crewId = 7, friend = true }, 2, 1)
		Assert.truthy(not okCap and codeCap == "Full", "the size cap holds (2 of 2)")
		-- INVITE ONLY: a friend who was invited (or followed / came in the party); a friend alone is not enough
		VanRules.setSize(st, 2, a, 101, CAP, 1, 1)
		VanRules.setPrivacy(st, 2, a, 101, INVITE, 1, 1)
		local okN, codeN = VanRules.canSit(st, 2, friend, 1, 1)
		Assert.truthy(not okN and codeN == "NotInvited", "a friend without the invite")
		Assert.truthy(
			VanRules.canSit(st, 2, { userId = 202, crewId = 9, friend = true, invited = true }, 1, 1),
			"an invited friend"
		)
		Assert.falsy(
			VanRules.canSit(st, 2, { userId = 303, crewId = 8, friend = false, invited = true }, 1, 1),
			"invited but not a friend"
		)
		Assert.falsy(
			VanRules.canSit(st, 2, { userId = 303, crewId = 8, friend = false, quick = true }, 1, 1),
			"Quick Crew never into an invite-only van"
		)
		-- OPEN: a held Quick Crew seat; the crew's own members always come back
		VanRules.setPrivacy(st, 2, a, 101, OPEN, 2, 1)
		Assert.truthy(
			VanRules.canSit(st, 2, { userId = 303, crewId = 8, friend = false, quick = true }, 1, 1),
			"OPEN: the matched stranger"
		)
		Assert.truthy(VanRules.canSit(st, 2, { userId = 102, crewId = 1, friend = false }, 2, 1), "own crew: back")
		-- kicked: not back in for KICK_BLOCK_SECONDS, even as a friend
		Assert.truthy(
			not VanRules.canSit(st, 2, { userId = 202, crewId = 9, friend = true, kicked = true }, 1, 1),
			"a kicked friend stays out"
		)
	end)

	test("kick: the leader frees a cargo seat; the player is blocked for a while; never the driver", function()
		local st = VanRules.new()
		local a = crew(1, { 101, 102, 103 })
		VanRules.claim(st, 2, a, 101, 1)
		local v = VanRules.van(st, 2) :: VanRules.Van
		Assert.eq(#v.seats, 3, "three seats taken")
		local okD, codeD = VanRules.kick(st, 2, a, 101, 1, 10, 1)
		Assert.truthy(not okD and codeD == "Driver", "never the driver")
		Assert.falsy(VanRules.kick(st, 2, a, 102, 3, 10, 1), "a member cannot kick")
		Assert.falsy(VanRules.kick(st, 2, a, 101, 3, 10, HD.SERVER_REACH + 1), "too far")
		local okE, codeE = VanRules.kick(st, 2, a, 101, 4, 10, 1)
		Assert.truthy(not okE and codeE == "NoSeat", "an empty seat")
		local ok, code, uid = VanRules.kick(st, 2, a, 101, 3, 10, 1)
		Assert.truthy(ok and code == "Ok" and uid == 103, "seat 3's member is out")
		Assert.eq(#v.seats, 2, "the seat is free")
		Assert.truthy(VanRules.isKicked(v, 103, 10 + P.KICK_BLOCK_SECONDS - 1), "blocked for a while")
		Assert.falsy(VanRules.isKicked(v, 103, 10 + P.KICK_BLOCK_SECONDS), "then free to come back")
		-- the server takes them out of the crew; the seats follow it
		VanRules.syncSeats(v, crew(1, { 101, 102 }))
		Assert.truthy(VanRules.canSit(st, 2, { userId = 205, crewId = 9, friend = true }, 2, 1), "a friend takes it")
		VanRules.setAway(st, 2)
		Assert.falsy(VanRules.kick(st, 2, a, 101, 2, 11, 1), "not while away")
	end)

	test("Quick Crew: only open vans, never past the size, never a kicked player", function()
		local q = QuickCrew.new()
		for i, uid in { 11, 12, 13 } do
			QuickCrew.optIn(q, uid, i)
		end
		-- an open van of 1 with size 2: one seat
		local res = QuickCrew.pass(q, { { bay = 4, crewSize = 1, openedAt = 1, leaderId = 1, size = 2 } }, 10)
		Assert.eq(#res.matched, 1, "one seat under the size")
		Assert.eq(QuickCrew.holdOf(q, 11), 4, "the longest waiting")
		-- the size drops to what is taken: no more holds; a hold over the size goes back
		local res2 = QuickCrew.pass(q, { { bay = 4, crewSize = 2, openedAt = 1, leaderId = 1, size = 2 } }, 11)
		Assert.eq(#res2.matched, 0, "full under the size")
		Assert.eq(QuickCrew.holdOf(q, 11), nil, "the held seat over the size goes back")
		-- a kicked seeker is never matched back into that van
		local q2 = QuickCrew.new()
		QuickCrew.optIn(q2, 21, 1)
		QuickCrew.optIn(q2, 22, 2)
		local blocked = { [21] = true }
		local res3 = QuickCrew.pass(
			q2,
			{ { bay = 6, crewSize = 1, openedAt = 1, leaderId = 1, size = 4, blocked = blocked } },
			5
		)
		Assert.eq(QuickCrew.holdOf(q2, 21), nil, "the kicked one waits")
		Assert.eq(QuickCrew.holdOf(q2, 22), 6, "the next one gets the seat")
		Assert.eq(#res3.matched, 1, "one match")
		-- counts know the size
		local w, open = QuickCrew.counts(q2, { { bay = 6, crewSize = 1, openedAt = 1, leaderId = 1, size = 2 } })
		Assert.truthy(w == 1 and open == 0, "status line: 1 waiting, the size-2 van is full with its hold")
	end)

	test("the sheet (LobbyLook.partySheet): sizes, seats, READY marks, KICK, GO", function()
		local base = { bay = 3, crewId = 1, leaderId = 101, waiting = 1, cap = 3, privacy = "open", held = 1 }
		local seats = {
			{ userId = 101, seat = 1, seated = false, ready = false },
			{ userId = 102, seat = 2, seated = true, ready = false },
		}
		local view = table.clone(base) :: any
		view.mode, view.size = "crew", #seats
		local s = LobbyLook.partySheet(view, seats)
		Assert.truthy(not s.solo and not s.canSolo and s.cap == 3 and s.taken == 3, "crew of 2 + 1 held, size 3")
		Assert.truthy(s.sizes[1].n == 2 and not s.sizes[1].enabled, "2 is under the seats taken")
		Assert.truthy(s.sizes[2].on and s.sizes[2].enabled and s.sizes[3].enabled, "3 on, 4 possible")
		Assert.eq(s.privacy, OPEN, "privacy index")
		Assert.eq(s.seats[1].state, "driver", "seat 1: the driver")
		Assert.truthy(s.seats[2].state == "seated" and s.seats[2].kick, "seat 2: seated, kickable")
		Assert.eq(s.seats[3].state, "held", "seat 3: held for Quick Crew")
		Assert.eq(s.seats[4].state, "closed", "seat 4: past the size")
		Assert.falsy(s.seats[1].kick, "never the driver")
		Assert.eq(s.go, "wait", "GO waits for READY")
		seats[2].ready = true
		view.waiting = 0
		local s2 = LobbyLook.partySheet(view, seats)
		Assert.truthy(s2.seats[2].state == "ready" and s2.go == "go", "everyone READY: GO")
		local solo = LobbyLook.partySheet(
			{ bay = 3, mode = "parked", crewId = 1, leaderId = 101, waiting = 0, size = 1 },
			{ { userId = 101, seat = 1, seated = false, ready = false } }
		)
		Assert.truthy(solo.solo and solo.canSolo and solo.go == "solo", "parked: SOLO · GO")
		for _, seat in solo.seats do
			if seat.seat > 1 then
				Assert.eq(seat.state, "closed", "a solo van's bench is closed")
			end
		end
		-- every button's action passes the validator
		for _, b in
			{
				{ "solo" },
				{ "size", 3 },
				{ "privacy", INVITE },
				{ "kick", 2 },
				{ "go" },
				{ "go", 1 },
				{ "paint", 2 },
				{ "style", 2 },
			}
		do
			local a = LobbyLook.partyAction(b[1], 3, b[2])
			Assert.truthy(a ~= nil and VanRules.validReadyArg(a), "PARTY " .. b[1] .. " passes Heist.Ready")
		end
		Assert.eq((LobbyLook.partyAction("go", 3, 1) :: any).op, "solo", "SOLO · GO")
		Assert.eq((LobbyLook.partyAction("solo", 3) :: any).op, "park", "SOLO parks")
		Assert.eq(LobbyLook.partyAction("invite", 3), nil, "INVITE is the Roblox prompt")
	end)

	test("the van card (LobbyLook.vanCard): owner, mode, seats, who can join, SIT when allowed", function()
		local me = { userId = 500, crewId = 50, leader = true, crewSize = 1, seatedBay = nil, ready = false }
		local function v(mode: string, privacy: string, size: number, cap: number, held: number?): any
			return {
				bay = 2,
				mode = mode,
				crewId = 1,
				leaderId = 101,
				waiting = 0,
				size = size,
				cap = cap,
				privacy = privacy,
				held = held or 0,
			}
		end
		local c = LobbyLook.vanCard(v("crew", "friends", 1, 2), me, { friend = true })
		Assert.truthy(c.sit and c.seated == 1 and c.cap == 2 and c.mode == "crew", "friends only: a friend may SIT")
		local c2 = LobbyLook.vanCard(v("crew", "friends", 1, 2), me, { friend = false })
		Assert.truthy(not c2.sit and c2.why == "NotFriend", "a stranger may not")
		local c3 = LobbyLook.vanCard(v("crew", "friends", 2, 2), me, { friend = true })
		Assert.truthy(not c3.sit and c3.why == "Full", "full at its size")
		local c4 = LobbyLook.vanCard(v("crew", "open", 1, 3, 1), me, { friend = false, quick = true })
		Assert.truthy(c4.sit, "OPEN: your held seat")
		local c5 = LobbyLook.vanCard(v("crew", "open", 1, 3), me, { friend = false })
		Assert.truthy(not c5.sit and c5.why == "NotMatched", "OPEN: strangers go through the crew sign")
		local c6 = LobbyLook.vanCard(v("parked", "friends", 1, 4), me, { friend = true })
		Assert.truthy(not c6.sit and c6.mode == "solo" and c6.cap == 1, "a solo van")
		for why in { Closed = 1, Full = 1, NotFriend = 1, NotMatched = 1, Seated = 1, Busy = 1 } do
			Assert.truthy(Strings.PARTY_CARD_WHY[why] ~= nil, "card words: " .. why)
		end
		for _, name in P.PRIVACY do
			Assert.truthy(Strings.PARTY_PRIVACY[name] ~= nil and Strings.PARTY_PRIVACY_INFO[name] ~= nil, name)
		end
		for _, code in { "BadSize", "BelowTaken", "BadPrivacy", "Kicked", "NotInvited", "NoSeat" } do
			Assert.truthy(Strings.LOBBY_REFUSED[code] ~= nil, "refusal words: " .. code)
		end
	end)
end
