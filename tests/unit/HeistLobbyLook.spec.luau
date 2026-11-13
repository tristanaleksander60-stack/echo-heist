-- L1: Shared/Heist/LobbyLook, station and van targeting in the hideout (PLAN_FIRST_PERSON "LB", Config.Hideout): what
-- each van point offers you in every van state (free / parked / crew / away; leader, member, seated, stranger), the
-- Heist.Ready action each verb sends (and that it passes the server's validator), the stations on the BIG track's
-- anchors, the station camera's frame and ease, the wardrobe orbit, the first-visit hint's van; plus FpMath.pick over
-- a hideout-like target set (the look picks the station in front, not the one behind).

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local LobbyLook = require("../../src/shared/Heist/LobbyLook")
local VanRules = require("../../src/shared/Heist/VanRules")
local Strings = require("../../src/shared/Heist/Strings")
local FpMath = require("../../src/client/Heist/FpMath")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LobbyPlan = require("../../src/server/Heist/LobbyPlan")

local HD = Config.Hideout

local function van(mode: string, crewId: number, leaderId: number, waiting: number?): LobbyLook.VanView
	return { bay = 2, mode = mode, crewId = crewId, leaderId = leaderId, waiting = waiting or 0, size = 1 }
end

local function me(crewId: number, leader: boolean, crewSize: number, seated: number?, ready: boolean?): LobbyLook.Me
	return {
		userId = 101,
		crewId = crewId,
		leader = leader,
		crewSize = crewSize,
		seatedBay = seated,
		ready = ready == true,
	}
end

return function(test: (string, () -> ()) -> ())
	test("van verbs: free, your parked van, your crew van, someone else's", function()
		local soloLeader = me(1, true, 1)
		-- a free van: the leader picks; a member is told the leader picks
		for _, point in { "cab", "door", "paint" } do
			Assert.eq(LobbyLook.vanVerb(nil, point, soloLeader), "pick", "free " .. point)
			Assert.eq(LobbyLook.vanVerb(nil, point, me(1, false, 2)), "leaderPicks", "free, member")
		end
		-- your parked van (alone): every point opens the PARTY sheet (SOLO / CREW / PAINT / STYLE / GO are in it)
		local parked = van("parked", 1, 101)
		for _, point in { "cab", "door", "paint", "style" } do
			Assert.eq(LobbyLook.vanVerb(parked, point, soloLeader), "party", "YOUR VAN at the " .. point)
		end
		-- your van with its side door open
		local open = van("crew", 1, 101, 1)
		local leaderOfTwo = me(1, true, 2)
		Assert.eq(LobbyLook.vanVerb(open, "cab", leaderOfTwo), "party", "the leader's GO is in the sheet")
		Assert.eq(LobbyLook.vanVerb(open, "door", leaderOfTwo), "party", "the sheet at the door too")
		Assert.eq(LobbyLook.action("party", 2), nil, "YOUR VAN sends nothing: it opens the sheet")
		-- a member of that crew
		local member = { userId = 202, crewId = 1, leader = false, crewSize = 2, seatedBay = nil, ready = false }
		Assert.eq(LobbyLook.vanVerb(open, "door", member), "sit", "a member walks in")
		Assert.eq(LobbyLook.vanVerb(open, "cab", member), nil, "a member has no GO")
		member.seatedBay = 2
		Assert.eq(LobbyLook.vanVerb(open, "cab", member), "ready", "seated: READY")
		member.ready = true
		Assert.eq(LobbyLook.vanVerb(open, "door", member), "unready", "seated and ready")
		Assert.eq(LobbyLook.seatedVerb(member, open), "unready", "the seat prompt wherever you look")
		Assert.eq(LobbyLook.seatedVerb(me(1, true, 2, 2), open), nil, "the driver has no seat prompt")
		-- someone else's van
		local stranger = me(7, true, 1)
		Assert.eq(LobbyLook.vanVerb(open, "door", stranger), "sit", "an open van invites you in")
		Assert.eq(LobbyLook.vanVerb(open, "cab", stranger), "taken", "but its cab is theirs")
		Assert.eq(LobbyLook.vanVerb(parked, "door", stranger), "taken", "a shut van is taken")
		-- away and leaving
		Assert.eq(LobbyLook.vanVerb(van("away", 1, 101), "cab", soloLeader), "busy", "away")
		Assert.eq(LobbyLook.vanVerb(van("departing", 1, 101), "door", stranger), "busy", "leaving")
		for verb in LobbyLook.LOCKED do
			Assert.eq(LobbyLook.action(verb, 2), nil, "locked " .. verb .. " sends nothing")
		end
	end)

	test("every verb's action passes the server's validator and has its words", function()
		for _, verb in { "pick", "solo", "go", "crew", "park", "paint", "style", "sit", "ready", "unready" } do
			local a = LobbyLook.action(verb, 3, 2)
			Assert.truthy(a ~= nil, verb .. " sends an action")
			Assert.truthy(VanRules.validAction(a), verb .. " passes VanRules.validAction")
			Assert.truthy(VanRules.validReadyArg(a), verb .. " passes Heist.Ready's validator")
		end
		Assert.eq((LobbyLook.action("pick", 3) :: any).op, "claim", "PICK claims")
		Assert.eq((LobbyLook.action("paint", 3, 4) :: any).n, 4, "PAINT carries the paint")
		for verb, text in Strings.LOBBY_VERB do
			Assert.truthy(#text > 0 and #text <= 16, "chip words fit: " .. verb)
		end
		for _, st in HD.STATIONS do
			Assert.truthy(Strings.LOBBY_VERB[st.verb] ~= nil, "station words: " .. st.verb)
		end
	end)

	test("stations: one per BIG anchor, each with a target and a camera", function()
		local plan = LobbyPlan.plan(Config.Lobby, Config.Lighting, (KitData :: any).parts, KitPlan)
		local anchors = {}
		for _, a in plan.anchors do
			anchors[a.name] = a
		end
		local verbs = {}
		for _, st in HD.STATIONS do
			Assert.truthy(anchors[st.anchor] ~= nil, "anchor " .. st.anchor .. " exists")
			Assert.truthy(LobbyLook.station(st.anchor) == st, "station lookup")
			Assert.truthy(#st.target == 4 and st.target[4] > 0, "a target with a radius")
			Assert.truthy(st.cam.back > 1 and st.cam.fov >= 40 and st.cam.fov <= 70, "a camera")
			verbs[st.verb] = true
		end
		for _, v in { "jobs", "laptop", "wardrobe", "tv", "quickCrew" } do
			Assert.truthy(verbs[v], "station " .. v)
		end
		Assert.eq(LobbyLook.station("Nope"), nil, "unknown anchor")
	end)

	test("the station camera faces the target from in front, eased; the wardrobe orbit looks at you", function()
		local eye, at = LobbyLook.focusFrame({ 10, 4, 0 }, 0, -2, { back = 5, up = 0.5, fov = 50 })
		Assert.near(eye[1], 10, 1e-6, "eye x")
		Assert.near(eye[3], -5, 1e-6, "eye 5 studs out along the facing")
		Assert.near(eye[2], 4.5, 1e-6, "a little above")
		Assert.near(at[3], 0, 1e-6, "looks at the target")
		Assert.eq(LobbyLook.ease(0), 0, "starts at the eye")
		Assert.eq(LobbyLook.ease(HD.FOCUS_SECONDS), 1, "arrives")
		Assert.eq(LobbyLook.ease(0, true), 1, "reduced motion: a cut")
		local mid = LobbyLook.ease(HD.FOCUS_SECONDS / 2)
		Assert.truthy(mid > 0.4 and mid < 0.6, "smooth")
		local oe, oa = LobbyLook.orbit({ 0, 3, 0 }, 0, 0, true)
		local d = math.sqrt(oe[1] ^ 2 + oe[3] ^ 2)
		Assert.near(d, HD.WARDROBE_ORBIT.distance, 1e-6, "orbit distance")
		Assert.truthy(oe[3] < 0, "in front of a character facing -Z")
		local off = math.sqrt(oa[1] ^ 2 + oa[3] ^ 2)
		Assert.near(off, HD.WARDROBE_ORBIT.shift, 1e-6, "looks just beside you")
		-- you stand right of centre: the root is on the camera's right (lookAt's right = look x up = (-fz, fx))
		local fx, fz = oa[1] - oe[1], oa[3] - oe[3]
		Assert.truthy((0 - oe[1]) * -fz + (0 - oe[3]) * fx > 0, "you stand right of centre")
		local oe2 = LobbyLook.orbit({ 0, 3, 0 }, 0, 2, true)
		Assert.near(oe2[1], oe[1], 1e-6, "reduced motion: no spin")
		local oe3 = LobbyLook.orbit({ 0, 3, 0 }, 0, 2, false)
		Assert.truthy(math.abs(oe3[1] - oe[1]) > 0.1, "a slow spin")
	end)

	test("targeting: the look picks the station in front of you within reach, not one behind or too far", function()
		local candidates: { FpMath.Candidate } = {
			{ id = "st:JobBoardSpot", pos = { 0, 4.5, -6 }, radius = 2.2, ok = true },
			{ id = "st:TVSpot", pos = { 0, 9, 8 }, radius = 3.2, ok = true }, -- behind
			{ id = "van:2:door", pos = { 30, 4.2, -2 }, radius = 2.4, ok = true }, -- far
		}
		local opts = {
			reach = HD.REACH,
			assist = 2.5,
			distanceWeight = 0.25,
			sticky = 0.35,
			current = nil,
			losCandidates = 3,
			blocked = function()
				return false
			end,
		}
		local k = FpMath.pick({ 0, 5, 0 }, FpMath.look(0, 0), candidates, opts)
		Assert.eq(k, 1, "the board in front")
		local k2 = FpMath.pick({ 0, 5, 0 }, FpMath.look(180, 0), candidates, opts)
		Assert.eq(k2, nil, "behind you: the TV is too far up and out of reach")
		local k3 = FpMath.pick({ 26, 5, -2 }, FpMath.look(-90, 0), candidates, opts)
		Assert.eq(k3, 3, "the van's side door when you face it")
	end)

	test("first visit: the hint goes to the nearest free van", function()
		local bays = {
			{ bay = 1, x = 26, z = -18, free = false },
			{ bay = 2, x = 17, z = 18, free = true },
			{ bay = 3, x = -18, z = -18, free = true },
		}
		Assert.eq(LobbyLook.nearestFree(bays, 20, -10), 2, "nearest free (1 is taken)")
		Assert.eq(LobbyLook.nearestFree(bays, -20, -10), 3, "the other side")
		Assert.eq(LobbyLook.nearestFree({}, 0, 0), nil, "none free")
	end)
end
