--!strict
-- Sim/Divergence: when a clone's recorded path no longer fits the world.
-- MASTERPLAN §3.2 rule 2 and docs/research/tech.md D3 ("the sim checks the echo
-- against dynamic blockers only; static geometry has not changed"). If the next
-- recorded sample crosses a shut door, the clone goes Stuck: it stops where it was,
-- fires no more events and holds that pose until the loop ends. The cause tells the
-- client which failure to play: Door -> Bonk (flatten, stars, shrug), Blocker ->
-- the "..." bubble. Failed intents are Shrugs (Interact), lasers are Zaps (HeistSim).

local Mechanisms = require("./Mechanisms")

local Divergence = {}

Divergence.CAUSE = table.freeze({
	Door = 1, -- shown as Bonk
	Blocker = 2, -- other dynamic blockers (heavy loot, shutters added later)
})

-- Returns cause, blocker index for the clone move p0 -> p1 at loop time T, or nil.
function Divergence.check(
	mech: Mechanisms.State,
	T: number,
	x0: number,
	y0: number,
	z0: number,
	x1: number,
	y1: number,
	z1: number
): (number?, number)
	local door = Mechanisms.doorBlocking(mech, T, x0, y0, z0, x1, y1, z1)
	if door ~= 0 then
		return Divergence.CAUSE.Door, door
	end
	return nil, 0
end

return table.freeze(Divergence)
