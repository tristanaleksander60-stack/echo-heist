--!strict
-- Heist/LeavePlan: the pure half of leaving a heist (garage-exit-fix), free of engine calls and requires so Lune
-- tests it (tests/unit/HeistLeave.spec.luau). HeistClient runs it; numbers come in from Config.Heist.LEAVE.
--   * The server's lobby state ("Lobby" on Heist.Msg, or any garage Sync) is authoritative: lobbyAction says
--     whether this client must tear the heist down ("enter") or is already clean in the hideout ("refresh").
--     Whatever state the heist was in (a run, caught, a rewind, the results card), "enter" ends in the same
--     clean hideout, and applying it twice changes nothing.
--   * STEPS: the teardown, in order. The heist HUD goes first, so no later step can leave it on screen, and
--     HeistClient runs every step in its own pcall (one failing step never skips the others).
--   * reset: the client state after the lobby (no run, no clock, no deck, no results).
--   * watch: the watchdog. In the hideout zone with no heist instance on the server (the server-written
--     HeistInstance attribute is "") for `hold` seconds, the heist view may not stay up.

local LeavePlan = {}

-- The teardown, in order (HeistClient.enterLobby maps each name to its calls).
LeavePlan.STEPS = table.freeze({
	"hud", -- every heist HUD element hidden and reset (Hud.hideHeist: run bar, timer, reason, stamps, pills, sheets)
	"binds", -- the run's key binds off (REWIND / END RUN, USE, CREW, DECK, FAST)
	"moments", -- busted view, 8 OF ME, blooper, hit-stop
	"lineup", -- the Crew Line-up cut
	"intro", -- the level intro's camera shot
	"rewind", -- the rewind overlay and its RUN / BUSTED stamp
	"camera", -- moment shot, Crew View, wall fades, FOV kick, slide dip, fast-forward off
	"hands", -- first-person hands: no held pose (hands up), not hiding
	"echoes", -- every clone rig released
	"gus",
	"world", -- doors, lasers, plates, loot views unbound from the old level
	"lights",
	"scene", -- cut-away, backdrop, northern lights, job board: the garage
	"hideout", -- the lobby's own entry (its first-person roam camera)
	"sound", -- alarm and laser loops off, garage music and ambience
})

-- The heist HUD's top-level elements (Hud.heistVisible names the ones on screen): none may show in the hideout.
LeavePlan.HEIST_UI = table.freeze({
	"run", -- the run HUD: "RUN 3/8", timer, run bar, loot meter, clone strip, REWIND, GRAB, FAST pill, CREW
	"deck", -- the Clone Deck between runs
	"readyWait", -- the RUN button / waiting line
	"results", -- the results card
	"menu", -- the MENU chip
	"menuSheet", -- "Leave this heist?"
	"reason", -- the rail's reason / spectate line ("Gus caught you.")
	"hidden", -- the HIDDEN pill's screen-edge dim
	"cutscene", -- the HUD switched off for a cut (the Line-up)
})

-- What a lobby state does on this client. where = state.where; heistUp = any heist HUD element is on screen.
function LeavePlan.lobbyAction(where: string, heistUp: boolean): string
	if where == "garage" and not heistUp then
		return "refresh"
	end
	return "enter"
end

-- The client state once back in the hideout (the fields every heist view reads to decide it is in a heist).
function LeavePlan.reset(state: any, garage: any?)
	state.where = "garage"
	state.garage = garage
	state.folder = nil
	state.run = nil
	state.clock = nil
	state.phase = ""
	state.deck = nil
	state.over = nil
	state.frozenT = 0
	state.lastRunT = 0
	state.reelT = nil
	state.replayT = nil
	state.carrying = false
	state.liveCount = 1
	if type(state.actorFx) == "table" then
		table.clear(state.actorFx)
	end
	if type(state.recs) == "table" then
		table.clear(state.recs)
	end
	if type(state.runEndedAtByRun) == "table" then
		table.clear(state.runEndedAtByRun)
	end
end

-- Is this client clean for the hideout? (the unit spec's and the watchdog's definition)
function LeavePlan.isClean(state: any, visible: { string }): boolean
	return state.where == "garage"
		and state.run == nil
		and state.clock == nil
		and state.phase == ""
		and state.deck == nil
		and state.over == nil
		and #visible == 0
end

-- Inside the hideout zone: within radius (XZ) of the lobby origin. Heist instances sit INSTANCE_SPACING away.
function LeavePlan.inHideout(x: number, z: number, origin: { number }, radius: number): boolean
	local dx, dz = x - origin[1], z - origin[3]
	return dx * dx + dz * dz <= radius * radius
end

export type Watch = { since: number? }

function LeavePlan.newWatch(): Watch
	return { since = nil }
end

-- The watchdog, once per check: true when the heist view must come down now. instanceAttr is the server-written
-- Player attribute (Protocol.PLAYER_ATTR; "" = no instance); heistUp = state.where == "heist" or any heist HUD on.
function LeavePlan.watch(
	w: Watch,
	now: number,
	instanceAttr: any,
	inHideout: boolean,
	heistUp: boolean,
	hold: number
): boolean
	if instanceAttr == "" and inHideout and heistUp then
		local since = w.since or now
		w.since = since
		return now - since >= hold
	end
	w.since = nil
	return false
end

-- After BACK TO GARAGE: ask the server for its state again when no lobby state came within retry seconds.
function LeavePlan.retryDue(leftAt: number?, now: number, where: string, retry: number): boolean
	return leftAt ~= nil and where ~= "garage" and now - leftAt >= retry
end

return LeavePlan
