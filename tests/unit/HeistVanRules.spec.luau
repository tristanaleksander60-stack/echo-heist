-- L1: Shared/Heist/VanRules, the hideout's vans (PLAN_FIRST_PERSON "LB", Config.Hideout): the Heist.Ready lobby
-- action validator (the server's Net validator: shapes, ops, ranges, the old reduced-motion boolean), claim / paint /
-- mode / sit / ready / go rules, the crew size cap, departure and return, the seats' wire encoding; and the van
-- geometry against the garage layout (Heist/LobbyPlan + the kit van): the side door's points face the aisle outside
-- the van's collider, the seats sit inside its cargo bay, the step-out spot is clear inside the garage.

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local VanRules = require("../../src/shared/Heist/VanRules")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LobbyPlan = require("../../src/server/Heist/LobbyPlan")

local HD = Config.Hideout
local V = HD.VAN
local REACH = HD.SERVER_REACH
local MODE = VanRules.MODE

local function crew(id: number, members: { number }): VanRules.Crew
	return { id = id, leaderId = members[1], members = members }
end

return function(test: (string, () -> ()) -> ())
	test("validator: only exact lobby action tables (and the old boolean) pass Heist.Ready", function()
		local good = {
			{ op = "claim", bay = 2 },
			{ op = "paint", bay = 8, n = 3 },
			{ op = "crew", bay = 1 },
			{ op = "park", bay = 1 },
			{ op = "solo", bay = 3 },
			{ op = "go", bay = 3 },
			{ op = "sit", bay = 4 },
			{ op = "ready" },
			{ op = "unready" },
			{ op = "stand" },
		}
		for _, a in good do
			Assert.truthy(VanRules.validAction(a), "valid " .. a.op)
			Assert.truthy(VanRules.validReadyArg(a), "ready arg " .. a.op)
		end
		Assert.truthy(VanRules.validReadyArg(nil), "nil (RUN)")
		Assert.truthy(VanRules.validReadyArg(true), "reduced motion true")
		Assert.truthy(VanRules.validReadyArg(false), "reduced motion false")
		local bad: { any } = {
			{},
			{ op = "fly", bay = 1 },
			{ op = "claim" }, -- needs a bay
			{ op = "paint", bay = 1 }, -- needs n
			{ op = "claim", bay = 0 },
			{ op = "claim", bay = HD.BAYS + 1 },
			{ op = "claim", bay = 1.5 },
			{ op = "claim", bay = 0 / 0 },
			{ op = "claim", bay = math.huge },
			{ op = "paint", bay = 1, n = 65 },
			{ op = "paint", bay = 1, n = -1 },
			{ op = "claim", bay = 1, extra = true }, -- unknown key
			{ op = "claim", bay = 1, n = 1, x = 1 }, -- too many keys
			{ op = 3, bay = 1 },
			{ op = "claim", bay = "1" },
			{ "claim", 1 }, -- an array
			"claim",
			42,
		}
		for i, a in bad do
			Assert.falsy(VanRules.validAction(a), "invalid #" .. i)
			Assert.falsy(VanRules.validReadyArg(a), "invalid ready arg #" .. i)
		end
	end)

	test("claim: the leader near a free van; a taken van stays taken; a crew of two starts in CREW mode", function()
		local st = VanRules.new()
		local a = crew(1, { 101 })
		Assert.falsy(VanRules.claim(st, 2, a, 101, REACH + 1), "too far")
		local ok, code = VanRules.claim(st, 2, a, 101, 3)
		Assert.truthy(ok and code == "Ok", "claimed bay 2")
		local v = VanRules.van(st, 2) :: VanRules.Van
		Assert.eq(v.mode, MODE.Parked, "a solo crew's van is parked")
		Assert.eq(v.leaderId, 101, "the leader")
		Assert.eq(#v.seats, 1, "one seat in use")
		Assert.eq(VanRules.vanOfCrew(st, 1), v, "the crew's van")
		local okA, codeA = VanRules.claim(st, 2, a, 101, 3)
		Assert.truthy(okA and codeA == "Already", "claiming your own van again")
		-- a third player cannot claim a taken van
		local c = crew(3, { 303 })
		local okT, codeT = VanRules.claim(st, 2, c, 303, 1)
		Assert.falsy(okT, "taken")
		Assert.eq(codeT, "Taken", "code")
		-- only the leader claims
		local duo = crew(4, { 401, 402 })
		local okL, codeL = VanRules.claim(st, 5, duo, 402, 1)
		Assert.falsy(okL, "a member cannot claim")
		Assert.eq(codeL, "NotLeader", "code")
		Assert.truthy(VanRules.claim(st, 5, duo, 401, 1), "the duo's leader claims")
		Assert.eq((VanRules.van(st, 5) :: VanRules.Van).mode, MODE.Crew, "a crew of two: CREW mode")
		-- a crew on a heist cannot claim
		local away = { id = 5, leaderId = 501, members = { 501 }, inHeist = true }
		Assert.falsy(VanRules.claim(st, 6, away, 501, 1), "in a heist")
		-- moving to another van releases the old one
		local okM, codeM = VanRules.claim(st, 7, a, 101, 2)
		Assert.truthy(okM and codeM == "Moved", "moved")
		Assert.eq(VanRules.van(st, 2), nil, "bay 2 free again")
		Assert.falsy(VanRules.claim(st, 99, a, 101, 1), "no such bay")
	end)

	test("paint: the leader cycles the paints near the van; members and bad indices are refused", function()
		local st = VanRules.new()
		local a = crew(1, { 101, 102 })
		VanRules.claim(st, 3, a, 101, 1)
		local v = VanRules.van(st, 3) :: VanRules.Van
		Assert.eq(v.paint, 0, "the bay's own paint at first")
		Assert.truthy(#V.PAINTS >= 3, "at least 3 paints")
		Assert.truthy(VanRules.setPaint(st, 3, 101, VanRules.nextPaint(v), 2), "paint 1")
		Assert.eq(v.paint, 1, "paint 1")
		Assert.falsy(VanRules.setPaint(st, 3, 102, 2, 2), "a member does not paint")
		Assert.falsy(VanRules.setPaint(st, 3, 101, #V.PAINTS + 1, 2), "no such paint")
		Assert.falsy(VanRules.setPaint(st, 3, 101, 2, REACH + 0.5), "too far")
		v.paint = #V.PAINTS
		Assert.eq(VanRules.nextPaint(v), 1, "the cycle wraps")
		for i, p in V.PAINTS do
			local luma = (0.2126 * p.rgb[1] + 0.7152 * p.rgb[2] + 0.0722 * p.rgb[3]) / 255
			Assert.truthy(luma > 0.2 and luma < 0.6, "paint " .. i .. " is a mid value")
			Assert.truthy(#p.name > 0, "paint " .. i .. " has a name")
		end
	end)

	test(
		"solo / crew state machine: SOLO only alone and parked; CREW opens; GO waits for every seated READY",
		function()
			local st = VanRules.new()
			local a = crew(1, { 101 })
			VanRules.claim(st, 2, a, 101, 1)
			Assert.truthy(VanRules.canGo(st, 2, a, 101, 2, true), "SOLO alone")
			Assert.falsy(VanRules.canGo(st, 2, a, 101, REACH + 1, true), "SOLO from too far")
			Assert.falsy(VanRules.canGo(st, 2, a, 101, 2, false), "GO needs the side door open")
			Assert.truthy(VanRules.setMode(st, 2, a, 101, MODE.Crew, 2), "CREW")
			Assert.truthy(VanRules.setMode(st, 2, a, 101, MODE.Parked, 2), "close again while alone")
			VanRules.setMode(st, 2, a, 101, MODE.Crew, 2)
			-- a friend sits in: joins the crew (the server moves them), then is seated and READY
			local okS, codeS = VanRules.canSit(st, 2, { userId = 202, crewId = 9, friend = true }, 1, 3)
			Assert.truthy(okS and codeS == "Join", "a friend joins by sitting")
			local duo = crew(1, { 101, 202 })
			VanRules.syncSeats(VanRules.van(st, 2) :: VanRules.Van, duo)
			Assert.falsy(VanRules.setMode(st, 2, duo, 101, MODE.Parked, 2), "cannot close with a crewmate")
			Assert.truthy(VanRules.markSeated(st, 2, 202, true), "seated")
			local okW, codeW = VanRules.canGo(st, 2, duo, 101, 2, false)
			Assert.falsy(okW, "GO waits for READY")
			Assert.eq(codeW, "Waiting", "code")
			Assert.falsy(VanRules.canGo(st, 2, duo, 101, 2, true), "no SOLO with a crew")
			Assert.falsy(VanRules.setReady(st, 2, 101, true), "the driver has no READY")
			Assert.truthy(VanRules.setReady(st, 2, 202, true), "READY")
			Assert.eq(VanRules.waiting(VanRules.van(st, 2) :: VanRules.Van), 0, "nobody waiting")
			Assert.falsy(VanRules.canGo(st, 2, duo, 202, 2, false), "only the leader presses GO")
			Assert.truthy(VanRules.canGo(st, 2, duo, 101, 2, false), "GO")
			-- stepping out clears READY
			VanRules.markSeated(st, 2, 202, false)
			Assert.falsy(VanRules.seatOf(VanRules.van(st, 2) :: VanRules.Van, 202).ready, "out: not READY")
			Assert.falsy(VanRules.setReady(st, 2, 202, true), "READY needs a seat")
			VanRules.markSeated(st, 2, 202, true)
			VanRules.setReady(st, 2, 202, true)
			-- departure, away, return
			VanRules.depart(st, 2)
			local v = VanRules.van(st, 2) :: VanRules.Van
			Assert.eq(v.mode, MODE.Departing, "departing")
			Assert.falsy(VanRules.canGo(st, 2, duo, 101, 2, false), "no second GO")
			Assert.falsy(VanRules.setPaint(st, 2, 101, 1, 1), "no paint while leaving")
			VanRules.setAway(st, 2)
			Assert.eq(v.mode, MODE.Away, "away on the job")
			local away = { id = 1, leaderId = 101, members = { 101, 202 }, inHeist = true }
			Assert.falsy(VanRules.canGo(st, 2, away, 101, 2, false), "busy in a heist")
			VanRules.returned(st, 2, duo)
			Assert.eq(v.mode, MODE.Crew, "back: CREW again for a crew of two")
			Assert.eq(VanRules.waiting(v), 1, "every seat to be taken again")
			VanRules.returned(st, 2, crew(1, { 101 }))
			Assert.eq(v.mode, MODE.Parked, "back alone: parked")
		end
	)

	test("sit: friends only (no strangers), your own crew always, the seat cap, never the driver's seat", function()
		local st = VanRules.new()
		local a = crew(1, { 101 })
		VanRules.claim(st, 2, a, 101, 1)
		local okC, codeC = VanRules.canSit(st, 2, { userId = 202, crewId = 9, friend = true }, 1, 2)
		Assert.falsy(okC, "the side door is shut (parked)")
		Assert.eq(codeC, "Closed", "code")
		VanRules.setMode(st, 2, a, 101, MODE.Crew, 1)
		local okN, codeN = VanRules.canSit(st, 2, { userId = 202, crewId = 9, friend = false }, 1, 2)
		Assert.falsy(okN, "a stranger cannot sit in")
		Assert.eq(codeN, "NotFriend", "code")
		Assert.falsy(VanRules.canSit(st, 2, { userId = 202, crewId = 9, friend = true }, 1, REACH + 2), "too far")
		local okD, codeD = VanRules.canSit(st, 2, { userId = 101, crewId = 1, friend = false }, 1, 1)
		Assert.falsy(okD, "the leader drives")
		Assert.eq(codeD, "Driver", "code")
		local okB, codeB = VanRules.canSit(st, 2, { userId = 102, crewId = 1, friend = false }, 2, 1)
		Assert.truthy(okB and codeB == "Back", "your own crew's van takes you back (no friend check)")
		-- the cap: Config.Sim.MAX_CREW seats (driver + the bench)
		local cap = math.min(Config.Sim.MAX_CREW, #V.SEATS)
		Assert.eq(#V.SEATS, Config.Sim.MAX_CREW, "one seat per crew member")
		Assert.truthy(VanRules.canSit(st, 2, { userId = 205, crewId = 9, friend = true }, cap - 1, 1), "the last seat")
		local okF, codeF = VanRules.canSit(st, 2, { userId = 205, crewId = 9, friend = true }, cap, 1)
		Assert.falsy(okF, "full")
		Assert.eq(codeF, "Full", "code")
		-- seats never exceed the van's seats, even for a bigger crew
		local big = crew(1, { 101, 102, 103, 104, 105 })
		local v = VanRules.van(st, 2) :: VanRules.Van
		VanRules.syncSeats(v, big)
		Assert.eq(#v.seats, #V.SEATS, "seats capped")
		Assert.falsy(VanRules.canGo(st, 2, big, 101, 1, false), "a crew bigger than the van cannot GO")
	end)

	test("seats follow the crew: order, the leader in seat 1, kept flags, a new leader after one leaves", function()
		local st = VanRules.new()
		VanRules.claim(st, 4, crew(1, { 101, 102, 103 }), 101, 1)
		local v = VanRules.van(st, 4) :: VanRules.Van
		VanRules.markSeated(st, 4, 103, true)
		VanRules.setReady(st, 4, 103, true)
		VanRules.syncSeats(v, { id = 1, leaderId = 102, members = { 102, 103 } }) -- 101 left; 102 leads
		Assert.eq(v.leaderId, 102, "the new leader")
		Assert.eq(v.seats[1].userId, 102, "seat 1 = the leader")
		Assert.eq(v.seats[2].userId, 103, "seat 2")
		Assert.eq(v.seats[2].seat, 2, "crew colour order")
		Assert.truthy(v.seats[2].seated and v.seats[2].ready, "kept seated and READY")
		Assert.eq(VanRules.vanOfUser(st, 103), v, "the van 103 is in")
		Assert.eq(VanRules.vanOfUser(st, 101), nil, "101 is in no van")
		VanRules.release(st, 4)
		Assert.eq(VanRules.van(st, 4), nil, "released")
	end)

	test("the seats' wire encoding round-trips and never carries names", function()
		local st = VanRules.new()
		VanRules.claim(st, 1, crew(1, { 101, 202 }), 101, 1)
		VanRules.markSeated(st, 1, 202, true)
		VanRules.setReady(st, 1, 202, true)
		local v = VanRules.van(st, 1) :: VanRules.Van
		local text = VanRules.encodeSeats(v)
		Assert.eq(text, "101,1,0,0;202,2,1,1", "encoded")
		local back = VanRules.decodeSeats(text)
		Assert.eq(#back, 2, "two seats")
		Assert.truthy(back[2].userId == 202 and back[2].seated and back[2].ready, "seat 2")
		Assert.eq(#VanRules.decodeSeats(""), 0, "empty")
		Assert.eq(#VanRules.decodeSeats(nil), 0, "nil")
		Assert.eq(#VanRules.decodeSeats("x;1,2"), 0, "junk")
		Assert.eq(VanRules.encodeSeats(nil), "", "no van")
	end)

	test(
		"geometry: door points face the aisle outside the van, seats inside its cargo bay, the exit is clear",
		function()
			local plan = LobbyPlan.plan(Config.Lobby, Config.Lighting, (KitData :: any).parts, KitPlan)
			Assert.eq(#plan.bays, HD.BAYS, "bays")
			local function world(bay: any, p: { number }): (number, number, number)
				-- the anchor: (bay.x, 0, bay.z) at yaw bay.yaw (KitPlan.rotate = Roblox's CFrame.Angles(0, yaw, 0))
				local x, z = KitPlan.rotate(bay.yaw, p[1], p[3])
				return bay.x + x, p[2], bay.z + z
			end
			local C = Config.Lobby
			for _, bay in plan.bays do
				local c = bay.collider
				-- the door side's points sit on the aisle side of the van (toward z = 0), at most a little inside the box
				for name, p in V.POINTS do
					local x, _, z = world(bay, VanRules.localPoint(p[1], p[2], p[3]))
					Assert.truthy(
						math.abs(z) < math.abs(bay.z),
						string.format("bay %d %s faces the aisle", bay.index, name)
					)
					Assert.truthy(
						x > c.minX - 0.5 and x < c.maxX + 0.5,
						string.format("bay %d %s along the van", bay.index, name)
					)
					local depthIn = if bay.z < 0 then c.maxZ - z else z - c.minZ
					Assert.truthy(
						depthIn < 0.6,
						string.format("bay %d %s on the van's skin (%.2f in)", bay.index, name, depthIn)
					)
				end
				-- the cab point is at the cab end, the paint point at the rear
				local cx = world(bay, VanRules.localPoint(V.POINTS.cab[1], 0, 0))
				local px = world(bay, VanRules.localPoint(V.POINTS.paint[1], 0, 0))
				Assert.truthy(math.abs(cx - px) > 6, "cab and rear points apart")
				-- seats inside the box
				for k, s in V.SEATS do
					local x, y, z = world(bay, VanRules.localPoint(s[1], s[2], s[3]))
					Assert.truthy(
						x > c.minX + 0.5 and x < c.maxX - 0.5 and z > c.minZ + 0.5 and z < c.maxZ - 0.5,
						string.format("bay %d seat %d inside the van", bay.index, k)
					)
					Assert.truthy(y > 1.5 and y < c.maxY - 3.5, string.format("bay %d seat %d headroom", bay.index, k))
				end
				-- the step-out spot: outside the van, inside the garage
				local ex, _, ez = world(bay, VanRules.localPoint(V.EXIT[1], V.EXIT[2], V.EXIT[3]))
				Assert.truthy(
					not (ex > c.minX - 1 and ex < c.maxX + 1 and ez > c.minZ - 1 and ez < c.maxZ + 1),
					string.format("bay %d exit clear of its van", bay.index)
				)
				Assert.truthy(math.abs(ex) < C.HALF_X - 1 and math.abs(ez) < C.HALF_Z - 1, "exit inside the garage")
				for _, other in plan.bays do
					local o = other.collider
					Assert.falsy(
						ex > o.minX - 1 and ex < o.maxX + 1 and ez > o.minZ - 1 and ez < o.maxZ + 1,
						string.format("bay %d exit clear of van %d", bay.index, other.index)
					)
				end
			end
		end
	)
end
