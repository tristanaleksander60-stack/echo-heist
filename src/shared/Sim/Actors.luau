--!strict
-- Sim/Actors: everything that stands on plates, carries loot, trips lasers and can
-- be seen by Gus: live players and clones, as plain data. MASTERPLAN §8.2 ("clones
-- are pure data on the server: {ownerId, slot, rec, alive, state, carrying, orphan}").
--
-- Stable order (§3.2 rule 3): each run's actor array is the clones in (seat, slot)
-- order, then the live players in seat order. An actor's id is its index in that
-- array, so ties anywhere in the sim break by id the same way on every machine.
--
-- States: clones Active -> Holding (recording over: holds its last pose, still
-- presses plates), or Stuck / Busted / Zapped. Live players Active -> Ended (END
-- RUN or the tape ran out), Caught, Zapped or Left. `present` = in the world.

local Sampler = require("../Rec/Sampler")

export type Actor = {
	id: number,
	kind: string, -- "live" | "clone"
	ownerId: number,
	seat: number, -- the owner's seat (crew order)
	slot: number, -- deck slot (0 for a live player)
	rec: any, -- Codec.Recording (being recorded for live, replayed for clones)
	state: string,
	present: boolean,
	x: number,
	y: number,
	z: number,
	yaw: number,
	flags: number,
	px: number,
	py: number,
	pz: number,
	carrying: number, -- loot index, 0 = none
	hidden: boolean,
	cursor: number, -- clone event cursor (Sampler.eventsDue)
	nextInteractT: number,
	shrugs: number,
	plateTicks: number, -- tutorial auto-end counter
	latency: number, -- live: measured one-way latency (seconds)
	validator: any, -- live: Rec/Validator state
	player: any, -- the owning crew member
	helper: boolean, -- owner in Helper mode (not counted for the Crew medal)
}

local Actors = {}

local function base(id: number, kind: string, player: any, slot: number, rec: any): Actor
	return {
		id = id,
		kind = kind,
		ownerId = player.id,
		seat = player.seat,
		slot = slot,
		rec = rec,
		state = "Active",
		present = true,
		x = 0,
		y = 0,
		z = 0,
		yaw = 0,
		flags = 0,
		px = 0,
		py = 0,
		pz = 0,
		carrying = 0,
		hidden = false,
		cursor = 0,
		nextInteractT = 0,
		shrugs = 0,
		plateTicks = 0,
		latency = 0,
		validator = nil,
		player = player,
		helper = player.helper == true,
	}
end

function Actors.newClone(id: number, player: any, slot: number, rec: any): Actor
	local a = base(id, "clone", player, slot, rec)
	local x, y, z, yaw, flags = Sampler.at(rec, 0)
	if x then
		a.x, a.y, a.z, a.yaw, a.flags = x, y, z, yaw, flags
	else
		a.present = false
		a.state = "Holding"
	end
	a.px, a.py, a.pz = a.x, a.y, a.z
	return a
end

function Actors.newLive(id: number, player: any, spawn: any, rec: any): Actor
	local a = base(id, "live", player, 0, rec)
	a.x, a.y, a.z, a.yaw = spawn.x, spawn.y, spawn.z, spawn.yaw
	a.px, a.py, a.pz = a.x, a.y, a.z
	a.latency = player.latency or 0
	return a
end

-- True while the actor's run/replay still matters to the world.
function Actors.inWorld(a: Actor): boolean
	return a.present
end

-- Deck status of a clone after a run (§3.2 rule 6 status dot).
function Actors.cloneStatus(a: Actor): string
	if a.state == "Busted" or a.state == "Zapped" or a.state == "Stuck" then
		return a.state
	elseif a.shrugs > 0 then
		return "Shrug"
	end
	return "OK"
end

-- Deck status of a new clone from a live run.
function Actors.liveStatus(a: Actor): string
	if a.state == "Caught" or a.state == "Zapped" then
		return a.state
	end
	return "New"
end

return table.freeze(Actors)
