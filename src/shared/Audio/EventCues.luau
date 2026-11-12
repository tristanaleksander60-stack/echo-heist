--!strict
-- Audio/EventCues: which cue each replicated sim event plays (MASTERPLAN §7.3, feel.md D3/D4). Pure data and
-- one pure lookup; AudioDirector.event(e, resolve) plays it. One table keeps every client's sounds in step
-- with the same events that drive the views, for players and clones alike (CLAUDE.md: anything an echo can
-- do goes through recorded events).
--
-- Each event maps to a list of actions:
--   cue      the cue to play
--   at       where it sounds: "plate" | "door" | "laser" | "switch" | "loot" index from field `index`,
--            "actor" (the actor in field `actor`), "van", or nil (2D)
--   actor    the event field holding the actor ("a" or "b"): a clone's version goes through the Clone bus
--   mine     "only" = play only when the actor is the local player's live actor; "not" = only when it is not;
--            "2d" = the local player's own actor hears it 2D, everyone else at the source
--   music    a music state to switch to ("Alarm")
--   stop     a looping cue to stop
--   loop     the cue is a loop started here (stopped by a later `stop`)

local EventLog = require("../Sim/EventLog")

local EV = EventLog.EV

export type Action = {
	cue: string?,
	at: string?,
	index: string?, -- event field holding the device index for at = plate/door/laser/switch/loot
	actor: string?,
	mine: string?,
	music: string?,
	stop: string?,
	loop: boolean?,
	caption: boolean?,
}

local EventCues = {}

EventCues.byKind = table.freeze({
	[EV.Timeout] = { { cue = "TapeStop" } },
	[EV.PlateDown] = {
		{ cue = "PlatePress", at = "plate", index = "a", actor = "b" },
		{ cue = "CableWhum", at = "plate", index = "a", actor = "b" },
	},
	[EV.PlateUp] = { { cue = "PlateRelease", at = "plate", index = "a" } },
	[EV.DoorOpen] = { { cue = "DoorOpen", at = "door", index = "a" } },
	[EV.DoorClosing] = { { cue = "DoorClose", at = "door", index = "a" } },
	[EV.DoorShut] = { { cue = "DoorLock", at = "door", index = "a" } },
	[EV.LaserOff] = { { cue = "LaserOff", at = "laser", index = "a" } },
	[EV.LaserOn] = { { cue = "LaserFlicker", at = "laser", index = "a" } },
	[EV.SwitchOn] = { { cue = "PlateRelease", at = "switch", index = "a", actor = "b" } },
	[EV.SwitchOff] = { { cue = "PlateRelease", at = "switch", index = "a" } },
	[EV.Grab] = { { cue = "Grab", at = "actor", actor = "a" } },
	[EV.Release] = { { cue = "DropThud", at = "actor", actor = "a" } },
	[EV.Drop] = { { cue = "DropThud", at = "actor", actor = "a" } },
	[EV.Bank] = {
		{ cue = "BankKaching", at = "actor", actor = "a", mine = "2d" },
		{ cue = "BankCoins", at = "actor", actor = "a", mine = "2d" },
	},
	[EV.Zap] = { { cue = "LaserZap", at = "actor", actor = "a" } },
	-- You slip into a hide spot (L4's verb): a soft tuck, only for you (the HUD shows ◐ HIDDEN).
	[EV.Hidden] = { { cue = "HideTuck", actor = "a", mine = "only" } },
	[EV.Suspect] = { { cue = "GusHuh" } },
	[EV.GuardHuh] = { { cue = "GusHuh", caption = false } },
	[EV.Caught] = {
		{ cue = "Busted", actor = "b", mine = "only" },
		{ cue = "GusAlert", actor = "b", mine = "not" },
	},
	[EV.Busted] = { { cue = "CloneBusted", at = "actor", actor = "b" } },
	[EV.AlarmOn] = { { music = "Alarm" }, { cue = "AlarmBell", loop = true } },
	[EV.VanLeft] = { { stop = "AlarmBell" }, { cue = "VanEngine", at = "van" } },
	[EV.HeistComplete] = { { stop = "AlarmBell" }, { cue = "TrackResolve" }, { cue = "HeistFanfare" } },
	[EV.Dawn] = { { stop = "AlarmBell" }, { cue = "TrackResolve" } },
	[EV.GoalMet] = { { cue = "CountDone" } },
	[EV.Tier] = { { cue = "CountDone" } },
	[EV.Rejected] = { { cue = "UIError", actor = "a", mine = "only" } },
} :: { [number]: { Action } })

local NONE: { Action } = table.freeze({})

-- The actions for one event kind (empty when the event makes no sound of its own).
function EventCues.forKind(kind: number): { Action }
	return EventCues.byKind[kind] or NONE
end

return EventCues
