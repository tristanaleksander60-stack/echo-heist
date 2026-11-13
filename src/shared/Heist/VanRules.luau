--!strict
-- Heist/VanRules: the hideout's vans as a pure state machine (PLAN_FIRST_PERSON "LB"; Config.Hideout). The server
-- (Heist/HeistService through Heist/Vans) keeps one State and asks these rules before it acts; the crews stay
-- HeistService's (crewOf, PartyId, Join friend): a van mirrors its crew's members as seats. Lune-tested
-- (tests/unit/HeistVanRules.spec.luau); no engine calls, positions are plain distances the caller measured.
--
-- A van: free -> PICK (the crew leader claims it; a crew of more than one starts in CREW mode) -> "parked" (a solo
-- crew; SOLO climbs in and departs) or "crew" (the side door is open: friends SIT, which seats them in the crew;
-- every seated member taps READY; the leader's GO departs) -> "departing" (the doors shut, the drive) -> "away"
-- (the crew is on its heist; the van stays theirs) -> back to parked / crew when the crew returns. Released when its
-- crew is gone. Seat 1 is the driver (the leader); the others are the crew's members in seat (crew colour) order.
--
-- The client's lobby intents ride on the EXISTING remote Heist.Ready as one table argument (no new remote names,
-- CLAUDE.md): { op = <OPS>, bay = 1..BAYS?, n = 1..64? }. VanRules.validReadyArg is that remote's validator (the old
-- boolean "reduced motion" argument still passes); the server then checks everything here again.
-- LOBBY 2 ops: "style" (bay, n = a Config.Hideout.VAN.STYLES index: the leader cycles the van's body), "quick" /
-- "unquick" (Quick Crew: a solo player opts in at the crew sign / opts out anywhere), "open" / "shut" (bay: the leader
-- opens their CREW van to Quick Crew strangers, or closes it). A van never takes a stranger unless it is open
-- (canSit: a friend of the leader, or a Quick Crew seat the server reserved in an open van; Shared/Heist/QuickCrew).
-- "look" (n = Shared/Heist/LookPitch's 1..STEPS) is not a van op: your first-person camera pitch, anywhere, at most
-- 10 Hz (HeistService hands it to Heist/LookSync before the lobby).
-- PARTY ops (the leader's PARTY sheet, Config.Hideout.PARTY): "size" (bay, n = MIN_SIZE..cap: how many may come
-- along; never below the seats already taken; picking a size opens a parked van's side door), "privacy" (bay, n = a
-- PARTY.PRIVACY index: FRIENDS ONLY / OPEN to Quick Crew / INVITE ONLY), "kick" (bay, n = a cargo seat 2..: the
-- member is put back in the lobby as a solo crew and cannot sit in again for KICK_BLOCK_SECONDS). canSit respects
-- the size and the privacy; Quick Crew only matches OPEN vans with free seats under the size.

local Config = require("../Config")
local LookPitch = require("./LookPitch")

local HD = Config.Hideout
local PARTY = HD.PARTY

local VanRules = {}

VanRules.MODE = table.freeze({
	Free = "free",
	Parked = "parked",
	Crew = "crew",
	Departing = "departing",
	Away = "away",
})

-- The lobby ops (Heist.Ready action table).
VanRules.OPS = table.freeze({
	"claim",
	"paint",
	"crew",
	"park",
	"solo",
	"go",
	"sit",
	"ready",
	"unready",
	"stand",
	"style",
	"quick",
	"unquick",
	"open",
	"shut",
	"look",
	"size",
	"privacy",
	"kick",
})
local NEEDS_BAY: { [string]: boolean } = {
	claim = true,
	paint = true,
	crew = true,
	park = true,
	solo = true,
	go = true,
	sit = true,
	style = true,
	open = true,
	shut = true,
	size = true,
	privacy = true,
	kick = true,
}
-- ops that take n (and need it)
local NEEDS_N: { [string]: boolean } =
	{ paint = true, style = true, size = true, privacy = true, kick = true, look = true }
-- the PARTY ops' own n ranges (the validator refuses anything outside them; the rules check again)
local N_RANGE: { [string]: { number } } = {
	size = { PARTY.MIN_SIZE, math.min(Config.Sim.MAX_CREW, #HD.VAN.SEATS) },
	privacy = { 1, #PARTY.PRIVACY },
	kick = { 2, #HD.VAN.SEATS },
}

export type Seat = { userId: number, seat: number, seated: boolean, ready: boolean }
export type Van = {
	bay: number,
	crewId: number,
	leaderId: number,
	mode: string,
	paint: number, -- Config.Hideout.VAN.PAINTS index, 0 = the bay's own paint
	style: number, -- Config.Hideout.VAN.STYLES index (1 = the step van)
	open: boolean, -- open to Quick Crew strangers (only ever true in CREW mode; = privacy "open")
	size: number, -- how many may come along, the driver included (PARTY: MIN_SIZE..cap)
	privacy: string, -- who can join: Config.Hideout.PARTY.PRIVACY ("friends" | "open" | "invite")
	kicked: { [number]: number }, -- userId -> until when (the rules' clock) a kicked player cannot sit in
	openedAt: number, -- when it was opened (Quick Crew fills the oldest open van first)
	seats: { Seat }, -- seats[1] = the leader (driver)
}
export type State = { vans: { [number]: Van } }
-- What the server tells the rules about a crew: its id, its leader and its members in seat order.
export type Crew = { id: number, leaderId: number, members: { number }, inHeist: boolean? }

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and v % 1 == 0 and v >= lo and v <= hi
end

-- The Heist.Ready action table: exactly the known keys, an op from OPS, a bay where the op needs one.
function VanRules.validAction(v: any): boolean
	if type(v) ~= "table" then
		return false
	end
	local count = 0
	for k, x in v do
		count += 1
		if count > 3 then
			return false
		end
		if k == "op" then
			if type(x) ~= "string" or table.find(VanRules.OPS, x) == nil then
				return false
			end
		elseif k == "bay" then
			if not isInt(x, 1, HD.BAYS) then
				return false
			end
		elseif k == "n" then
			if not isInt(x, 1, 64) then
				return false
			end
		else
			return false
		end
	end
	local op = v.op
	if type(op) ~= "string" then
		return false
	end
	if NEEDS_BAY[op] and v.bay == nil then
		return false
	end
	if NEEDS_N[op] and v.n == nil then
		return false
	end
	if v.n ~= nil and not NEEDS_N[op] then
		return false
	end
	if v.bay ~= nil and not NEEDS_BAY[op] then
		return false
	end
	if op == "look" and not LookPitch.validN(v.n) then
		return false
	end
	local range = N_RANGE[op]
	if range and not isInt(v.n, range[1], range[2]) then
		return false
	end
	return true
end

-- Heist.Ready's one argument: nil, the old reduced-motion boolean, or a lobby action.
function VanRules.validReadyArg(v: any): boolean
	return v == nil or type(v) == "boolean" or VanRules.validAction(v)
end

function VanRules.new(): State
	return { vans = {} }
end

function VanRules.van(st: State, bay: number): Van?
	return st.vans[bay]
end

function VanRules.vanOfCrew(st: State, crewId: number): Van?
	for _, v in st.vans do
		if v.crewId == crewId then
			return v
		end
	end
	return nil
end

-- The van a user sits in or drives (nil = none).
function VanRules.vanOfUser(st: State, userId: number): Van?
	for _, v in st.vans do
		for _, s in v.seats do
			if s.userId == userId then
				return v
			end
		end
	end
	return nil
end

function VanRules.seatOf(v: Van, userId: number): Seat?
	for _, s in v.seats do
		if s.userId == userId then
			return s
		end
	end
	return nil
end

-- Seats follow the crew (seat order = crew colour order); a kept member keeps its seated / ready flags.
function VanRules.syncSeats(v: Van, crew: Crew)
	local old: { [number]: Seat } = {}
	for _, s in v.seats do
		old[s.userId] = s
	end
	local seats: { Seat } = {}
	local cap = #HD.VAN.SEATS
	for i, uid in crew.members do
		if i > cap then
			break
		end
		local o = old[uid]
		local isLeader = uid == crew.leaderId
		table.insert(seats, {
			userId = uid,
			seat = i,
			seated = if o then o.seated else false,
			ready = if o and not isLeader then o.ready else false,
		})
	end
	v.seats = seats
	v.leaderId = crew.leaderId
end

local function within(dist: number?): boolean
	return type(dist) == "number" and dist == dist and dist <= HD.SERVER_REACH
end

-- Is n a style index? (Config.Hideout.VAN.STYLES)
function VanRules.validStyle(n: any): boolean
	return isInt(n, 1, #HD.VAN.STYLES)
end

-- A saved style id (profile `vanStyle`) to its index; an unknown id is the default style 1.
function VanRules.styleIndex(id: any): number
	for i, s in HD.VAN.STYLES do
		if s.id == id then
			return i
		end
	end
	return 1
end

-- The most a van ever seats: the driver + the cargo bench, never past Config.Sim.MAX_CREW.
function VanRules.cap(): number
	return math.min(Config.Sim.MAX_CREW, #HD.VAN.SEATS)
end

-- How many this van takes now: its party size (PARTY), never past the seats.
function VanRules.capOf(v: Van): number
	local n = if isInt(v.size, 1, VanRules.cap()) then v.size else VanRules.cap()
	return math.min(n, VanRules.cap())
end

-- A PARTY.PRIVACY index to its name (nil = not one).
function VanRules.privacyName(n: any): string?
	return if isInt(n, 1, #PARTY.PRIVACY) then PARTY.PRIVACY[n] else nil
end

-- A privacy name to its index (unknown = the default).
function VanRules.privacyIndex(name: any): number
	return table.find(PARTY.PRIVACY, name) or PARTY.DEFAULT_PRIVACY
end

-- Is this user blocked from the van after a kick (at `now` on the rules' clock)?
function VanRules.isKicked(v: Van, userId: number, now: number): boolean
	local untilT = v.kicked and v.kicked[userId]
	return untilT ~= nil and now < untilT
end

-- PICK: the crew leader claims a free van standing near it. A leader who already has a van moves to this one (the
-- old one is released). style: the leader's saved style (an index; default 1). Returns ok, code ("Ok" | "Moved" |
-- "Already" | "NoBay" | "NotLeader" | "InHeist" | "Taken" | "TooFar" | "Busy").
function VanRules.claim(
	st: State,
	bay: number,
	crew: Crew,
	actorId: number,
	dist: number?,
	style: number?
): (boolean, string)
	if not isInt(bay, 1, HD.BAYS) then
		return false, "NoBay"
	end
	if crew.leaderId ~= actorId then
		return false, "NotLeader"
	end
	if crew.inHeist then
		return false, "InHeist"
	end
	local v = st.vans[bay]
	if v and v.crewId == crew.id then
		return true, "Already"
	end
	if v then
		return false, "Taken"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	local mine = VanRules.vanOfCrew(st, crew.id)
	local code = "Ok"
	local open, openedAt = false, 0
	local size, privacy, kicked = VanRules.cap(), PARTY.PRIVACY[PARTY.DEFAULT_PRIVACY], {}
	if mine then
		if mine.mode == VanRules.MODE.Departing or mine.mode == VanRules.MODE.Away then
			return false, "Busy"
		end
		st.vans[mine.bay] = nil
		code = "Moved"
		open, openedAt = mine.open, mine.openedAt -- a moved crew stays open to Quick Crew
		size, privacy, kicked = mine.size, mine.privacy, mine.kicked -- and keeps its party settings
	end
	local nv: Van = {
		bay = bay,
		crewId = crew.id,
		leaderId = crew.leaderId,
		mode = if #crew.members > 1 or open then VanRules.MODE.Crew else VanRules.MODE.Parked,
		paint = 0,
		style = if VanRules.validStyle(style) then style :: number else 1,
		open = open,
		openedAt = openedAt,
		size = size,
		privacy = privacy,
		kicked = kicked,
		seats = {},
	}
	VanRules.syncSeats(nv, crew)
	st.vans[bay] = nv
	return true, code
end

function VanRules.release(st: State, bay: number)
	st.vans[bay] = nil
end

-- The leader paints the van (a Config.Hideout.VAN.PAINTS index) from near it.
function VanRules.setPaint(st: State, bay: number, actorId: number, n: number, dist: number?): (boolean, string)
	local v = st.vans[bay]
	if not v then
		return false, "NoVan"
	end
	if v.leaderId ~= actorId then
		return false, "NotLeader"
	end
	if not isInt(n, 1, #HD.VAN.PAINTS) then
		return false, "BadPaint"
	end
	if v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away then
		return false, "Busy"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	v.paint = n
	return true, "Ok"
end

-- The next paint after the current one (PAINT cycles; the bay's own paint counts as 0).
function VanRules.nextPaint(v: Van): number
	return v.paint % #HD.VAN.PAINTS + 1
end

-- The leader restyles the van (a Config.Hideout.VAN.STYLES index) from near its rear wheel (the STYLE point).
function VanRules.setStyle(st: State, bay: number, actorId: number, n: number, dist: number?): (boolean, string)
	local v = st.vans[bay]
	if not v then
		return false, "NoVan"
	end
	if v.leaderId ~= actorId then
		return false, "NotLeader"
	end
	if not VanRules.validStyle(n) then
		return false, "BadStyle"
	end
	if v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away then
		return false, "Busy"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	v.style = n
	return true, "Ok"
end

-- The next style after the current one (STYLE cycles 1..#STYLES).
function VanRules.nextStyle(v: { style: number }): number
	local n = if VanRules.validStyle(v.style) then v.style else 1
	return n % #HD.VAN.STYLES + 1
end

-- Quick Crew: the leader opens (on) or closes their van to strangers. Opening a parked van opens its side door too
-- (CREW mode). dist: from the crew sign or the van, whichever is nearer (the caller measures; closing works from
-- anywhere). Returns ok, code ("Ok" | "Already" | "NotYours" | "NotLeader" | "Busy" | "TooFar" | "Full").
function VanRules.setOpen(
	st: State,
	bay: number,
	crew: Crew,
	actorId: number,
	on: boolean,
	now: number,
	dist: number?
): (boolean, string)
	local v = st.vans[bay]
	if not v or v.crewId ~= crew.id then
		return false, "NotYours"
	end
	if crew.leaderId ~= actorId then
		return false, "NotLeader"
	end
	if not on then
		if not v.open then
			return true, "Already"
		end
		v.open = false
		v.privacy = PARTY.PRIVACY[PARTY.DEFAULT_PRIVACY] -- closed to strangers: back to friends only
		return true, "Ok"
	end
	if v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away or crew.inHeist then
		return false, "Busy"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	if #crew.members >= VanRules.capOf(v) then
		return false, "Full"
	end
	if v.open then
		return true, "Already"
	end
	v.open = true
	v.privacy = "open"
	v.openedAt = now
	v.mode = VanRules.MODE.Crew
	return true, "Ok"
end

-- PARTY: how many may come along (n = MIN_SIZE..cap, the driver included). Never below the seats already taken
-- (taken = the crew's members + those waiting + Quick Crew seats held for this van: the caller counts). A parked van
-- opens its side door (picking a crew size means you want a crew). Returns ok, code ("Ok" | "NotYours" |
-- "NotLeader" | "Busy" | "TooFar" | "BadSize" | "BelowTaken").
function VanRules.setSize(
	st: State,
	bay: number,
	crew: Crew,
	actorId: number,
	n: number,
	taken: number,
	dist: number?
): (boolean, string)
	local v = st.vans[bay]
	if not v or v.crewId ~= crew.id then
		return false, "NotYours"
	end
	if crew.leaderId ~= actorId then
		return false, "NotLeader"
	end
	if v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away or crew.inHeist then
		return false, "Busy"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	if not isInt(n, PARTY.MIN_SIZE, VanRules.cap()) then
		return false, "BadSize"
	end
	if n < math.max(taken, #crew.members) then
		return false, "BelowTaken"
	end
	v.size = n
	v.mode = VanRules.MODE.Crew
	return true, "Ok"
end

-- PARTY: who can join (n = a PARTY.PRIVACY index). OPEN is the Quick Crew open (VanRules.setOpen: CREW mode, the
-- seat cap); FRIENDS ONLY and INVITE ONLY close the van to strangers (the caller gives held seats back). Returns ok,
-- code ("Ok" | "Already" | "NotYours" | "NotLeader" | "Busy" | "TooFar" | "Full" | "BadPrivacy").
function VanRules.setPrivacy(
	st: State,
	bay: number,
	crew: Crew,
	actorId: number,
	n: number,
	now: number,
	dist: number?
): (boolean, string)
	local name = VanRules.privacyName(n)
	if name == nil then
		return false, "BadPrivacy"
	end
	local v = st.vans[bay]
	if not v or v.crewId ~= crew.id then
		return false, "NotYours"
	end
	if crew.leaderId ~= actorId then
		return false, "NotLeader"
	end
	if v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away or crew.inHeist then
		return false, "Busy"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	if name == "open" then
		return VanRules.setOpen(st, bay, crew, actorId, true, now, dist)
	end
	if v.privacy == name and not v.open then
		return true, "Already"
	end
	v.open = false
	v.privacy = name
	return true, "Ok"
end

-- PARTY: the leader kicks the member in cargo seat `seatN` (2..). The member's seat goes (the caller takes them out
-- of the crew, back to the lobby as a solo crew) and they cannot sit in this van until now + KICK_BLOCK_SECONDS.
-- Returns ok, code, the kicked user id ("Ok" | "NotYours" | "NotLeader" | "Busy" | "TooFar" | "NoSeat" | "Driver").
function VanRules.kick(
	st: State,
	bay: number,
	crew: Crew,
	actorId: number,
	seatN: number,
	now: number,
	dist: number?
): (boolean, string, number?)
	local v = st.vans[bay]
	if not v or v.crewId ~= crew.id then
		return false, "NotYours", nil
	end
	if crew.leaderId ~= actorId then
		return false, "NotLeader", nil
	end
	if v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away or crew.inHeist then
		return false, "Busy", nil
	end
	if not within(dist) then
		return false, "TooFar", nil
	end
	if seatN == 1 then
		return false, "Driver", nil
	end
	local target: Seat? = nil
	for _, s in v.seats do
		if s.seat == seatN then
			target = s
		end
	end
	if target == nil or target.userId == crew.leaderId then
		return false, "NoSeat", nil
	end
	local uid = target.userId
	local i = table.find(v.seats, target)
	if i then
		table.remove(v.seats, i)
	end
	v.kicked = v.kicked or {}
	v.kicked[uid] = now + PARTY.KICK_BLOCK_SECONDS
	return true, "Ok", uid
end

-- CREW (open the side door) or PARK (close it again: only while nobody else is in the crew).
function VanRules.setMode(
	st: State,
	bay: number,
	crew: Crew,
	actorId: number,
	mode: string,
	dist: number?
): (boolean, string)
	local v = st.vans[bay]
	if not v or v.crewId ~= crew.id then
		return false, "NotYours"
	end
	if crew.leaderId ~= actorId then
		return false, "NotLeader"
	end
	if v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away then
		return false, "Busy"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	if mode == VanRules.MODE.Crew then
		v.mode = mode
		return true, "Ok"
	elseif mode == VanRules.MODE.Parked then
		if #crew.members > 1 then
			return false, "HasCrew"
		end
		v.mode = mode
		v.open = false -- a parked van takes nobody: shutting the side door closes it to Quick Crew too
		return true, "Ok"
	end
	return false, "BadMode"
end

-- SIT: walk in at a CREW van's side door. Your own crew's van always takes you back; another crew's only when you
-- are friends with its leader, or hold the Quick Crew seat the server reserved for you in this van while it is open
-- to Quick Crew (strangers: only through the opt-in Quick Crew, MASTERPLAN §3.3), and it has a free seat.
-- who = { userId, crewId, friend (with the van's leader), quick (your Quick Crew reservation is this bay), invited
-- (you came in on the leader's invite or followed them: the server reads the join data), kicked (the leader kicked
-- you from this van a moment ago: VanRules.isKicked) }; vanCrewSize = the van crew's size now (members + those
-- waiting + seats held for OTHER Quick Crew players). PARTY: the van's size caps the seats and its privacy picks who
-- may walk in (FRIENDS ONLY: friends; OPEN: friends and held Quick Crew seats; INVITE ONLY: invited friends).
function VanRules.canSit(
	st: State,
	bay: number,
	who: {
		userId: number,
		crewId: number,
		friend: boolean,
		quick: boolean?,
		invited: boolean?,
		kicked: boolean?,
	},
	vanCrewSize: number,
	dist: number?
): (boolean, string)
	local v = st.vans[bay]
	if not v then
		return false, "NoVan"
	end
	if v.mode ~= VanRules.MODE.Crew then
		return false, if v.mode == VanRules.MODE.Parked then "Closed" else "Busy"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	if v.crewId == who.crewId then
		if v.leaderId == who.userId then
			return false, "Driver" -- the leader drives: GO from the cab
		end
		return true, "Back"
	end
	if who.kicked == true then
		return false, "Kicked"
	end
	if v.privacy == "invite" and not v.open then
		if not (who.friend and who.invited == true) then
			return false, if who.friend then "NotInvited" else "NotFriend"
		end
	elseif not who.friend and not (who.quick == true and v.open) then
		return false, if v.open then "NotMatched" else "NotFriend"
	end
	if vanCrewSize >= VanRules.capOf(v) then
		return false, "Full"
	end
	return true, "Join"
end

-- A member's seat is taken (on) or left (off: stood up, jumped out). Leaving clears READY.
function VanRules.markSeated(st: State, bay: number, userId: number, on: boolean): boolean
	local v = st.vans[bay]
	local s = v and VanRules.seatOf(v, userId)
	if not s then
		return false
	end
	s.seated = on
	if not on then
		s.ready = false
	end
	return true
end

-- READY / not ready: a seated member who is not the driver.
function VanRules.setReady(st: State, bay: number, userId: number, on: boolean): (boolean, string)
	local v = st.vans[bay]
	local s = v and VanRules.seatOf(v, userId)
	if not v or not s then
		return false, "NotSeated"
	end
	if v.leaderId == userId then
		return false, "Driver"
	end
	if v.mode ~= VanRules.MODE.Crew then
		return false, "Busy"
	end
	if not s.seated then
		return false, "NotSeated"
	end
	s.ready = on
	return true, "Ok"
end

-- Members (not the driver) who are not seated and ready yet.
function VanRules.waiting(v: Van): number
	local n = 0
	for _, s in v.seats do
		if s.userId ~= v.leaderId and not (s.seated and s.ready) then
			n += 1
		end
	end
	return n
end

-- SOLO (solo = true: a one-player crew's parked van) or GO (a CREW van whose seated members are all READY), from
-- near the cab. Returns ok, code ("Ok" | "NotYours" | "NotLeader" | "Busy" | "TooFar" | "NotSolo" | "Closed" |
-- "Waiting" | "Seats").
function VanRules.canGo(
	st: State,
	bay: number,
	crew: Crew,
	actorId: number,
	dist: number?,
	solo: boolean
): (boolean, string)
	local v = st.vans[bay]
	if not v or v.crewId ~= crew.id then
		return false, "NotYours"
	end
	if crew.leaderId ~= actorId then
		return false, "NotLeader"
	end
	if crew.inHeist or v.mode == VanRules.MODE.Departing or v.mode == VanRules.MODE.Away then
		return false, "Busy"
	end
	if not within(dist) then
		return false, "TooFar"
	end
	if #crew.members > #HD.VAN.SEATS then
		return false, "Seats"
	end
	if solo then
		if #crew.members ~= 1 then
			return false, "NotSolo"
		end
		return true, "Ok"
	end
	if v.mode ~= VanRules.MODE.Crew then
		return false, "Closed"
	end
	VanRules.syncSeats(v, crew)
	if VanRules.waiting(v) > 0 then
		return false, "Waiting"
	end
	return true, "Ok"
end

-- The doors shut and the van leaves: every seat counts as taken (the driver too).
function VanRules.depart(st: State, bay: number)
	local v = st.vans[bay]
	if v then
		v.mode = VanRules.MODE.Departing
		for _, s in v.seats do
			s.seated = true
		end
	end
end

-- The heist started (away) or did not (back to the hideout state it left).
function VanRules.setAway(st: State, bay: number)
	local v = st.vans[bay]
	if v then
		v.mode = VanRules.MODE.Away
	end
end

-- The crew is back in the hideout (or its departure was called off): parked for a solo crew, else CREW with every
-- seat to be taken again.
function VanRules.returned(st: State, bay: number, crew: Crew)
	local v = st.vans[bay]
	if not v then
		return
	end
	VanRules.syncSeats(v, crew)
	v.mode = if #crew.members > 1 then VanRules.MODE.Crew else VanRules.MODE.Parked
	for _, s in v.seats do
		s.seated = false
		s.ready = false
	end
end

-- Seats as a short attribute string for the clients ("userId,seat,seated,ready;..."): no names (clients look
-- players up), no client data.
function VanRules.encodeSeats(v: Van?): string
	if not v then
		return ""
	end
	local parts = {}
	for _, s in v.seats do
		table.insert(
			parts,
			string.format("%d,%d,%d,%d", s.userId, s.seat, if s.seated then 1 else 0, if s.ready then 1 else 0)
		)
	end
	return table.concat(parts, ";")
end

function VanRules.decodeSeats(text: any): { Seat }
	local out: { Seat } = {}
	if type(text) ~= "string" or text == "" then
		return out
	end
	for _, chunk in string.split(text, ";") do
		local f = string.split(chunk, ",")
		local uid, seat = tonumber(f[1]), tonumber(f[2])
		if uid and seat and #f == 4 then
			table.insert(out, { userId = uid, seat = seat, seated = f[3] == "1", ready = f[4] == "1" })
		end
	end
	return out
end

-- Van space (Config.Hideout.VAN: along toward the cab, up, out toward the side door) to the van's local axes (its
-- anchor's CFrame): { x, y, z }.
function VanRules.localPoint(along: number, up: number, out: number): { number }
	return { along * HD.VAN.CAB_X, up, out * HD.VAN.DOOR_Z }
end

return table.freeze(VanRules)
