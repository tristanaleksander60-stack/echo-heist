--!strict
-- Heist/LobbyLook: what each thing in the hideout offers YOU when you look at it (PLAN_FIRST_PERSON "LB"), and the
-- station camera's ease. Pure (Lune-tested in tests/unit/HeistLobbyLook.spec.luau): the client (Heist/Hideout)
-- turns the verb into the reticle's prompt chip and, on E / X / tap, into a station view or a Heist.Ready lobby
-- action. Nothing here decides anything: the server re-checks every action (Shared/Heist/VanRules).
--
-- Targets: the five stations (Config.Hideout.STATIONS: jobs, laptop, wardrobe, tv, invite) and three points on each
-- van's door side (Config.Hideout.VAN.POINTS: cab, door, paint). Van verbs:
--   free van      the leader of a crew: "pick" (anywhere on it); a member: "leaderPicks" (locked)
--   your van      leader: cab "solo" (parked) / "go" or "wait" (crew: every seated member READY?); door "crew"
--                 (parked) / "park" (crew, nobody else in it); paint "paint"
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
	if v.crewId == me.crewId then
		if me.leader then
			if point == "cab" then
				if v.mode == "parked" then
					return "solo"
				end
				return if v.waiting > 0 then "wait" else "go"
			elseif point == "door" then
				if v.mode == "parked" then
					return "crew"
				end
				return if me.crewSize <= 1 then "park" else nil
			elseif point == "paint" then
				return "paint"
			end
			return nil
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

-- The Heist.Ready lobby action a van verb sends (nil: none, or a locked verb).
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
	elseif verb == "sit" then
		return { op = "sit", bay = bay }
	elseif verb == "ready" then
		return { op = "ready" }
	elseif verb == "unready" then
		return { op = "unready" }
	end
	return nil
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
