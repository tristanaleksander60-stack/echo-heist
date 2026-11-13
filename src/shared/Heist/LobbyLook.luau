--!strict
-- Heist/LobbyLook: what each thing in the hideout offers YOU when you look at it (PLAN_FIRST_PERSON "LB"), and the
-- station camera's ease. Pure (Lune-tested in tests/unit/HeistLobbyLook.spec.luau): the client (Heist/Hideout)
-- turns the verb into the reticle's prompt chip and, on E / X / tap, into a station view or a Heist.Ready lobby
-- action. Nothing here decides anything: the server re-checks every action (Shared/Heist/VanRules).
--
-- Targets: the five stations (Config.Hideout.STATIONS: jobs, laptop, wardrobe, tv, crew: the Quick Crew sheet at the
-- "LOOKING FOR CREW" sign) and four points on each van's door side (Config.Hideout.VAN.POINTS: cab, door, paint,
-- style). Van verbs:
--   free van      the leader of a crew: "pick" (anywhere on it); a member: "leaderPicks" (locked)
--   your van      leader: "party" at every point (PARTY track: one sheet for SOLO / crew size / who can join / the
--                 ready check / KICK / INVITE / PAINT / STYLE / GO, Hud/Party)
--                 member: door "sit" (not seated); seated members get "ready" / "unready" wherever they look
--   another's van door "sit" while its side door is open (crew mode), else "taken" (locked)
-- A van away on a heist or leaving is "busy" (locked).

local Config = require("../Config")

local HD = Config.Hideout

local LobbyLook = {}

export type VanView = {
	bay: number,
	mode: string, -- VanRules.MODE
	crewId: number,
	leaderId: number,
	waiting: number, -- seated members not READY yet (VanRules.waiting)
	size: number, -- seats in use
	cap: number?, -- PARTY: how many may come along (the van's Size attribute; nil = every seat)
	privacy: string?, -- PARTY: who can join (Config.Hideout.PARTY.PRIVACY; nil = friends)
	held: number?, -- seats held for matched Quick Crew players
}
export type Me = {
	userId: number,
	crewId: number,
	leader: boolean,
	crewSize: number,
	seatedBay: number?, -- the van you sit in (nil = standing)
	ready: boolean,
}

-- Locked verbs show a steel chip and do nothing on E.
LobbyLook.LOCKED = table.freeze({ leaderPicks = true, taken = true, busy = true, wait = true })

-- The verb a van point offers you (nil = nothing).
function LobbyLook.vanVerb(v: VanView?, point: string, me: Me): string?
	if v == nil or v.mode == "free" then
		return if me.leader then "pick" else "leaderPicks"
	end
	if v.mode == "departing" or v.mode == "away" then
		return "busy"
	end
	if point == "style" then
		-- only your own van's leader uses the wheel (its PARTY sheet); it offers nothing to anyone else
		return if v.crewId == me.crewId and me.leader then "party" else nil
	end
	if v.crewId == me.crewId then
		if me.leader then
			return "party" -- one menu for the whole van (Hud/Party)
		end
		if me.seatedBay == v.bay then
			return if me.ready then "unready" else "ready"
		end
		return if point == "door" then "sit" else nil
	end
	if v.mode == "crew" and point == "door" then
		return "sit"
	end
	return "taken"
end

-- While you sit in a van (not the driver) the prompt is READY / not ready wherever you look.
function LobbyLook.seatedVerb(me: Me, v: VanView?): string?
	if me.seatedBay == nil or v == nil or v.bay ~= me.seatedBay or me.leader then
		return nil
	end
	if v.mode ~= "crew" then
		return nil
	end
	return if me.ready then "unready" else "ready"
end

-- The Heist.Ready lobby action a van verb sends (nil: none, or a locked verb). paintNext: the next paint (PAINT) or
-- the next style (STYLE).
function LobbyLook.action(verb: string, bay: number, paintNext: number?): { [string]: any }?
	if LobbyLook.LOCKED[verb] then
		return nil
	end
	if verb == "pick" then
		return { op = "claim", bay = bay }
	elseif verb == "solo" then
		return { op = "solo", bay = bay }
	elseif verb == "go" then
		return { op = "go", bay = bay }
	elseif verb == "crew" then
		return { op = "crew", bay = bay }
	elseif verb == "park" then
		return { op = "park", bay = bay }
	elseif verb == "paint" then
		return { op = "paint", bay = bay, n = paintNext or 1 }
	elseif verb == "style" then
		return { op = "style", bay = bay, n = paintNext or 1 }
	elseif verb == "sit" then
		return { op = "sit", bay = bay }
	elseif verb == "ready" then
		return { op = "ready" }
	elseif verb == "unready" then
		return { op = "unready" }
	end
	return nil -- "party" opens the sheet on the client (no server op)
end

---------------------------------------------------------------------------
-- The PARTY sheet (PARTY track, Config.Hideout.PARTY; Hud/Party draws it, the server decides every op)
---------------------------------------------------------------------------

export type PartySeat = {
	seat: number,
	userId: number, -- 0 = nobody
	state: string, -- "driver" | "ready" | "seated" | "out" | "held" | "free" | "closed" (beyond the crew size)
	kick: boolean, -- the leader may kick this seat's member
}
export type PartySheet = {
	bay: number,
	solo: boolean, -- the van is parked (SOLO)
	canSolo: boolean, -- SOLO is possible (nobody else in the crew)
	cap: number, -- the crew size (MIN_SIZE..), the driver included
	taken: number, -- seats in use + held: the smallest size you can pick
	sizes: { { n: number, on: boolean, enabled: boolean } },
	privacy: number, -- a PARTY.PRIVACY index
	seats: { PartySeat },
	waiting: number,
	go: string, -- "solo" (SOLO · GO) | "go" (everyone READY) | "wait"
}

local function capNow(v: VanView): number
	local all = math.min(Config.Sim.MAX_CREW, #HD.VAN.SEATS)
	local n = tonumber(v.cap) or all
	return math.clamp(math.floor(n), 1, all)
end

-- What the leader's PARTY sheet shows for their van. seats: VanRules.decodeSeats of the van's Seats attribute.
function LobbyLook.partySheet(v: VanView, seats: { any }): PartySheet
	local all = math.min(Config.Sim.MAX_CREW, #HD.VAN.SEATS)
	local held = math.max(0, math.floor(tonumber(v.held) or 0))
	local solo = v.mode == "parked"
	local cap = capNow(v)
	local taken = #seats + held
	local sizes = {}
	for n = HD.PARTY.MIN_SIZE, all do
		table.insert(sizes, { n = n, on = not solo and n == cap, enabled = n >= taken })
	end
	local bySeat: { [number]: any } = {}
	for _, s in seats do
		bySeat[s.seat] = s
	end
	local out: { PartySeat } = {}
	local heldLeft = held
	for k = 1, all do
		local s = bySeat[k]
		local state
		if s then
			state = if k == 1 or s.userId == v.leaderId
				then "driver"
				elseif s.ready then "ready"
				elseif s.seated then "seated"
				else "out"
		elseif solo or k > cap then
			state = "closed"
		elseif heldLeft > 0 then
			heldLeft -= 1
			state = "held"
		else
			state = "free"
		end
		table.insert(out, {
			seat = k,
			userId = if s then s.userId else 0,
			state = state,
			kick = s ~= nil and k > 1 and s.userId ~= v.leaderId,
		})
	end
	local go = if solo then (if #seats <= 1 then "solo" else "wait") elseif v.waiting > 0 then "wait" else "go"
	return {
		bay = v.bay,
		solo = solo,
		canSolo = #seats <= 1,
		cap = cap,
		taken = taken,
		sizes = sizes,
		privacy = table.find(HD.PARTY.PRIVACY, v.privacy or "") or HD.PARTY.DEFAULT_PRIVACY,
		seats = out,
		waiting = v.waiting,
		go = go,
	}
end

-- The Heist.Ready action a PARTY sheet button sends (nil: "invite" is the Roblox prompt, "back" closes the sheet).
-- kind: "solo" (park the van) | "size" (n) | "privacy" (n) | "kick" (n = seat) | "go" (n = 1: SOLO · GO from a
-- parked van) | "paint" (n = the next paint) | "style" (n = the next style).
function LobbyLook.partyAction(kind: string, bay: number, n: number?): { [string]: any }?
	if kind == "solo" then
		return { op = "park", bay = bay }
	elseif kind == "size" or kind == "privacy" or kind == "kick" or kind == "paint" or kind == "style" then
		return if n then { op = kind, bay = bay, n = n } else nil
	elseif kind == "go" then
		return { op = if n == 1 then "solo" else "go", bay = bay }
	end
	return nil
end

export type VanCard = {
	bay: number,
	leaderId: number,
	mode: string, -- "solo" (parked) | "crew"
	seated: number, -- seats in use
	cap: number,
	privacy: string,
	sit: boolean, -- show SIT (the server checks everything again: the invite, the hold, the size)
	why: string?, -- else why not: "Closed" | "Full" | "NotFriend" | "NotMatched" | "Seated" | "Busy"
}

-- The read-only card someone who is not the leader sees while looking at a claimed van. facts = { friend (you are
-- friends with its leader, as far as this client knows), quick (your Quick Crew seat is held in this van) }.
-- INVITE ONLY shows SIT to friends: whether you came in on the leader's invite is the server's to check.
function LobbyLook.vanCard(v: VanView, me: Me, facts: { friend: boolean?, quick: boolean? }): VanCard
	local cap = capNow(v)
	local privacy = v.privacy or HD.PARTY.PRIVACY[HD.PARTY.DEFAULT_PRIVACY]
	local card: VanCard = {
		bay = v.bay,
		leaderId = v.leaderId,
		mode = if v.mode == "parked" then "solo" else "crew",
		seated = v.size,
		cap = if v.mode == "parked" then 1 else cap,
		privacy = privacy,
		sit = false,
		why = nil,
	}
	local function no(why: string): VanCard
		card.why = why
		return card
	end
	if v.mode == "departing" or v.mode == "away" then
		return no("Busy")
	end
	if v.mode ~= "crew" then
		return no("Closed")
	end
	if v.crewId == me.crewId then
		if me.seatedBay == v.bay or me.leader then
			return no("Seated")
		end
		card.sit = true -- your own crew's van takes you back
		return card
	end
	local held = math.max(0, math.floor(tonumber(v.held) or 0))
	local quick = facts.quick == true and privacy == "open"
	-- your own held seat is one of the held ones
	if v.size + held - (if quick then 1 else 0) >= cap then
		return no("Full")
	end
	if privacy == "invite" then
		if facts.friend ~= true then
			return no("NotFriend")
		end
	elseif facts.friend ~= true and not quick then
		return no(if privacy == "open" then "NotMatched" else "NotFriend")
	end
	card.sit = true
	return card
end

-- The station definition for an anchor name (Config.Hideout.STATIONS), or nil.
function LobbyLook.station(anchor: string): any?
	for _, s in HD.STATIONS do
		if s.anchor == anchor then
			return s
		end
	end
	return nil
end

-- Station camera: the eye `back` studs out along the anchor's facing (fx, fz: its LookVector on the floor plane,
-- normalised here) from the target point, `up` above it, looking at the target. Returns eye, at ({x, y, z}).
function LobbyLook.focusFrame(target: { number }, fx: number, fz: number, cam: any): ({ number }, { number })
	local l = math.sqrt(fx * fx + fz * fz)
	local nx, nz = if l > 1e-6 then fx / l else 0, if l > 1e-6 then fz / l else 1
	local eye = { target[1] + nx * cam.back, target[2] + (cam.up or 0), target[3] + nz * cam.back }
	return eye, { target[1], target[2], target[3] }
end

-- The ease into a station view: 0..1 smoothstep over FOCUS_SECONDS (reduced motion: 1 at once).
function LobbyLook.ease(elapsed: number, reduced: boolean?): number
	if reduced then
		return 1
	end
	local u = math.clamp(elapsed / math.max(HD.FOCUS_SECONDS, 1e-6), 0, 1)
	return u * u * (3 - 2 * u)
end

-- The wardrobe orbit round your Rookie: eye and look point from the root (x, y, z), its facing yaw (degrees) and the
-- seconds since it opened (a slow spin; reduced motion: none).
function LobbyLook.orbit(root: { number }, facingYaw: number, t: number, reduced: boolean?): ({ number }, { number })
	local O = HD.WARDROBE_ORBIT
	local yaw = math.rad(facingYaw + O.yaw + (if reduced then 0 else O.spin * t))
	-- in front of you: a yaw-0 Roblox character faces -Z, so "in front" is (-sin, -cos)
	local eye = {
		root[1] - math.sin(yaw) * O.distance,
		root[2] + O.height,
		root[3] - math.cos(yaw) * O.distance,
	}
	-- the look point slides to the camera's left so you stand right of centre, clear of the sheet on the left
	local c, s = math.cos(yaw), math.sin(yaw)
	return eye, { root[1] + c * O.shift, root[2] + O.look, root[3] - s * O.shift }
end

-- The Quick Crew sheet (the crew sign, Config.Hideout.QUICK): the buttons you get and the info line's key.
-- who = { leader, crewSize, seeking (QuickCrew "seek" or "matched"), vanBay (your crew's van, 0 = none), vanOpen,
-- vanMode }; flags = { quick (LiveFlag quickCrew), invites (LiveFlag invites) }.
--   looking for a crew        STOP
--   leader of a van           OPEN MY VAN / CLOSE MY VAN (+ LOOK FOR A CREW while alone and closed)
--   alone, no van             LOOK FOR A CREW
--   in someone's crew         (nothing: "leave your crew first")
-- then INVITE FRIENDS when invites are on. Buttons: "look" | "stop" | "open" | "shut" | "invite".
function LobbyLook.quickButtons(who: any, flags: any): ({ string }, string)
	local out: { string } = {}
	local info = "info"
	if flags.quick ~= true then
		info = "paused"
	elseif who.seeking then
		table.insert(out, "stop")
	elseif who.leader and (tonumber(who.vanBay) or 0) > 0 and (who.vanMode == "crew" or who.vanMode == "parked") then
		table.insert(out, if who.vanOpen then "shut" else "open")
		if who.crewSize <= 1 and not who.vanOpen then
			table.insert(out, "look")
		end
		info = "leader"
	elseif who.crewSize <= 1 then
		table.insert(out, "look")
	else
		info = "needSolo"
	end
	if flags.invites == true then
		table.insert(out, "invite")
	end
	return out, info
end

-- The Heist.Ready action a Quick Crew button sends (nil: "invite" is the Roblox prompt, not a server op).
function LobbyLook.quickAction(button: string, vanBay: number?): { [string]: any }?
	if button == "look" then
		return { op = "quick" }
	elseif button == "stop" then
		return { op = "unquick" }
	elseif button == "open" and vanBay and vanBay > 0 then
		return { op = "open", bay = vanBay }
	elseif button == "shut" and vanBay and vanBay > 0 then
		return { op = "shut", bay = vanBay }
	end
	return nil
end

-- The waypoint arrow to a matched van (Config.Hideout.QUICK.ARROW): on the floor `ahead` studs from you toward the
-- target (x, z), pointing at it. Returns the arrow's point (x, z), its yaw (degrees, Roblox CFrame.Angles about +Y:
-- the arrow's local -Z points at the target) and whether to show it (hidden within hideWithin studs).
function LobbyLook.arrow(from: { number }, to: { number }): (number, number, number, boolean)
	local A = HD.QUICK.ARROW
	local dx, dz = to[1] - from[1], to[2] - from[2]
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1e-6 then
		return from[1], from[2], 0, false
	end
	local ux, uz = dx / d, dz / d
	local k = math.min(A.ahead, d)
	local yaw = math.deg(math.atan2(-ux, -uz))
	return from[1] + ux * k, from[2] + uz * k, yaw, d > A.hideWithin
end

-- The free van nearest to (x, z) from a list of { bay, x, z, free } (the first-visit "PICK A VAN" hint).
function LobbyLook.nearestFree(bays: { any }, x: number, z: number): number?
	local best, bestD = nil, math.huge
	for _, b in bays do
		if b.free then
			local d = (b.x - x) ^ 2 + (b.z - z) ^ 2
			if d < bestD then
				best, bestD = b.bay, d
			end
		end
	end
	return best
end

return table.freeze(LobbyLook)
