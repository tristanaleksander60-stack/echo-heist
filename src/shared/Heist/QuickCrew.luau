--!strict
-- Heist/QuickCrew: Quick Crew matching as pure rules (LOBBY 2; MASTERPLAN §3.3: strangers only through this opt-in;
-- Config.Hideout.QUICK). Lune-tested (tests/unit/HeistQuickCrew.spec.luau); no engine calls: the server
-- (Heist/HeistService) owns one State, tells it who is eligible and which vans are open, and acts on what it returns.
--
--   * A solo player opts in at the crew sign (a "seeker"); they can opt out any time.
--   * A crew leader opens their CREW van to Quick Crew (VanRules.setOpen). Open vans with free seats receive seekers:
--     the oldest open van first, the longest-waiting seeker first (ties by user id), never past the seat cap
--     (Config.Sim.MAX_CREW: the crew's members + seats already held for matched seekers).
--   * A match HOLDS a seat for RESERVE_SECONDS: the seeker walks in (a waypoint arrow, client) and SITs at the side
--     door, which joins the crew (the server's sit path; QuickCrew.drop). A lapsed hold puts them at the back of the
--     queue; MAX_MISSES lapses in a row opt them out (away from the keyboard).
--   * A van that closes, departs, fills up or goes away gives its held seats back: those seekers queue again at once,
--     keeping their place (it was not their fault).
-- Same server only: nobody is teleported anywhere.

local Config = require("../Config")

local Q = Config.Hideout.QUICK

local QuickCrew = {}

export type Seeker = {
	userId: number,
	since: number, -- queue order: when they opted in (or queued again after a lapse)
	bay: number?, -- the van holding a seat for them (nil = waiting)
	holdUntil: number?, -- when that hold lapses
	misses: number, -- lapsed holds in a row
}
export type State = { seekers: { [number]: Seeker } }
-- An open van as the server sees it this pass: its bay, its crew's size now (members + waiting), when it opened, its
-- leader (never matched into their own van).
export type OpenVan = { bay: number, crewSize: number, openedAt: number, leaderId: number }
export type Pass = {
	matched: { { userId: number, bay: number } }, -- new holds this pass
	requeued: { number }, -- holds that lapsed or whose van went: waiting again
	dropped: { number }, -- opted out after MAX_MISSES lapses
}

function QuickCrew.new(): State
	return { seekers = {} }
end

-- The seat cap of a van crew (the driver + the cargo bench).
function QuickCrew.cap(): number
	return math.min(Config.Sim.MAX_CREW, #Config.Hideout.VAN.SEATS)
end

function QuickCrew.isSeeking(st: State, userId: number): boolean
	return st.seekers[userId] ~= nil
end

-- The bay holding a seat for this user (nil = none).
function QuickCrew.holdOf(st: State, userId: number): number?
	local s = st.seekers[userId]
	return if s then s.bay else nil
end

-- Seats held in a van for matched seekers (except `except`, e.g. the one now sitting down).
function QuickCrew.heldIn(st: State, bay: number, except: number?): number
	local n = 0
	for uid, s in st.seekers do
		if s.bay == bay and uid ~= except then
			n += 1
		end
	end
	return n
end

-- Opt in (the server checked the player is a solo crew at the sign). Returns ok, code ("Ok" | "Already").
function QuickCrew.optIn(st: State, userId: number, now: number): (boolean, string)
	if st.seekers[userId] then
		return true, "Already"
	end
	st.seekers[userId] = { userId = userId, since = now, bay = nil, holdUntil = nil, misses = 0 }
	return true, "Ok"
end

-- Opt out (any time, from anywhere), or the seeker sat down / left / is no longer solo. True when they were in.
function QuickCrew.drop(st: State, userId: number): boolean
	if st.seekers[userId] == nil then
		return false
	end
	st.seekers[userId] = nil
	return true
end

-- The van stopped taking strangers (closed, departed, released): its holds go back to waiting, keeping their place.
-- Returns the user ids that were waiting on it.
function QuickCrew.release(st: State, bay: number): { number }
	local out = {}
	for uid, s in st.seekers do
		if s.bay == bay then
			s.bay = nil
			s.holdUntil = nil
			table.insert(out, uid)
		end
	end
	table.sort(out)
	return out
end

local function queue(st: State): { Seeker }
	local list = {}
	for _, s in st.seekers do
		table.insert(list, s)
	end
	table.sort(list, function(a, b)
		if a.since ~= b.since then
			return a.since < b.since
		end
		return a.userId < b.userId
	end)
	return list
end

-- One matching pass at time `now` over the vans open to Quick Crew right now. Lapsed holds queue again (or opt the
-- seeker out after MAX_MISSES), holds in vans that are no longer open (or no longer have room) are given back, then
-- waiting seekers fill the free seats: oldest open van first, longest-waiting seeker first.
function QuickCrew.pass(st: State, vans: { OpenVan }, now: number): Pass
	local out: Pass = { matched = {}, requeued = {}, dropped = {} }
	local byBay: { [number]: OpenVan } = {}
	for _, v in vans do
		byBay[v.bay] = v
	end
	-- lapsed holds
	for _, s in queue(st) do
		local bay = s.bay
		if bay ~= nil and s.holdUntil ~= nil and now >= s.holdUntil then
			s.bay, s.holdUntil = nil, nil
			s.misses += 1
			if s.misses >= Q.MAX_MISSES then
				st.seekers[s.userId] = nil
				table.insert(out.dropped, s.userId)
			else
				s.since = now -- the back of the queue
				table.insert(out.requeued, s.userId)
			end
		end
	end
	-- holds in vans that went (closed, left, released) or overflow (the crew grew some other way: the newest holds
	-- go back first)
	local cap = QuickCrew.cap()
	local q = queue(st)
	for i = #q, 1, -1 do
		local s = q[i]
		local bay = s.bay
		if bay ~= nil then
			local v = byBay[bay]
			local room = if v then cap - v.crewSize else 0
			if v == nil or QuickCrew.heldIn(st, bay) > room then
				s.bay, s.holdUntil = nil, nil
				table.insert(out.requeued, s.userId)
			end
		end
	end
	-- fill: the oldest open van first
	local order = table.clone(vans)
	table.sort(order, function(a, b)
		if a.openedAt ~= b.openedAt then
			return a.openedAt < b.openedAt
		end
		return a.bay < b.bay
	end)
	local waiting = {}
	for _, s in queue(st) do
		if s.bay == nil then
			table.insert(waiting, s)
		end
	end
	for _, v in order do
		local free = cap - v.crewSize - QuickCrew.heldIn(st, v.bay)
		for _, s in waiting do
			if free <= 0 then
				break
			end
			if s.bay == nil and s.userId ~= v.leaderId then
				s.bay = v.bay
				s.holdUntil = now + Q.RESERVE_SECONDS
				free -= 1
				table.insert(out.matched, { userId = s.userId, bay = v.bay })
			end
		end
	end
	table.sort(out.requeued)
	return out
end

-- How many are waiting (not matched yet) and how many vans are open with room: the sheet's status line.
function QuickCrew.counts(st: State, vans: { OpenVan }): (number, number)
	local waiting = 0
	for _, s in st.seekers do
		if s.bay == nil then
			waiting += 1
		end
	end
	local cap = QuickCrew.cap()
	local open = 0
	for _, v in vans do
		if cap - v.crewSize - QuickCrew.heldIn(st, v.bay) > 0 then
			open += 1
		end
	end
	return waiting, open
end

return table.freeze(QuickCrew)
