--!strict
-- Sim/Interact: the ONLY intent entry point, for players and replaying clones alike.
-- MASTERPLAN §8.5 ("Interact.request(actor, kind, targetId) validates range from
-- the actor's sim position, target state and cooldown, then records the event;
-- replaying clones call the same function"), CLAUDE.md ("anything an echo can do
-- must go through Actors + recorded events").
--
-- Kinds are Rec/Codec EVENT ids; args are 1-based LevelSpec indices.
--   Grab (loot)    within INTERACT_RANGE of the item, item at home or dropped, hands free
--   Release        drop what you carry where you stand
--   Press (switch) within range; toggles (or starts a timed switch)
--   Hide (hide)    you are inside that hide box (hiding itself is positional)
--   Emote (id)     always
-- HoldStart/HoldEnd/Gadget and heavy-loot grips are reserved (Unsupported) until
-- those mechanics ship. On success a live actor's event is appended to its
-- recording at the tick time; a clone's failure is a Shrug (§3.2 rule 2).

local Codec = require("../Rec/Codec")
local Config = require("../Config")
local EventLog = require("./EventLog")
local Geom = require("./Geom")
local Loot = require("./Loot")
local Mechanisms = require("./Mechanisms")
local Sampler = require("../Rec/Sampler")

local EV = EventLog.EV
local KIND = Codec.EVENT
local EPS = 1e-7

local Interact = {}

Interact.FAIL = table.freeze({
	Cooldown = 1,
	Range = 2,
	Gone = 3, -- loot already taken or banked
	Busy = 4, -- hands full
	Unknown = 5, -- bad kind or target index
	NotCarrying = 6,
	Unsupported = 7,
	NotInside = 8,
	NotActive = 9, -- the actor is out of the run
})

local FAIL = Interact.FAIL

local function inRange(actor: any, x: number, y: number, z: number): boolean
	local S = Config.Sim
	return Geom.dist2(actor.x, actor.z, x, z) <= S.INTERACT_RANGE * S.INTERACT_RANGE + EPS
		and math.abs(actor.y - y) <= S.INTERACT_HEIGHT
end

-- Checks and applies an intent. Returns ok, failure code (Interact.FAIL) on refusal.
function Interact.request(sim: any, actor: any, kind: number, arg: number): (boolean, number?)
	local level = sim.level
	local t, tick = sim.t, sim.tick
	if not actor.present then
		return false, FAIL.NotActive
	end
	if t < actor.nextInteractT - EPS then
		return false, FAIL.Cooldown
	end

	local ok, reason = false, FAIL.Unknown
	if kind == KIND.Grab then
		local def = level.loot[arg]
		if not def then
			reason = FAIL.Unknown
		elseif def.heavy then
			reason = FAIL.Unsupported
		elseif actor.carrying ~= 0 then
			reason = FAIL.Busy
		elseif not Loot.available(sim.loot, arg) then
			reason = FAIL.Gone
		else
			local item = sim.loot.items[arg]
			if not inRange(actor, item.x, item.y, item.z) then
				reason = FAIL.Range
			else
				Loot.take(sim.loot, arg, actor)
				EventLog.append(sim.log, tick, EV.Grab, actor.id, arg)
				ok = true
				if level.alarm and level.alarm.trigger == arg then
					sim.tripAlarm(sim, actor.id, actor.x, actor.z)
				end
			end
		end
	elseif kind == KIND.Release then
		if actor.carrying == 0 then
			reason = FAIL.NotCarrying
		else
			Loot.drop(sim.loot, actor, sim.log, tick, EV.Release)
			ok = true
		end
	elseif kind == KIND.Press then
		local def = level.switches[arg]
		if not def then
			reason = FAIL.Unknown
		elseif not inRange(actor, def.x, def.y, def.z) then
			reason = FAIL.Range
		else
			Mechanisms.press(sim.mech, arg, t, actor.id, sim.log, tick)
			ok = true
		end
	elseif kind == KIND.Hide then
		local def = level.hides[arg]
		if not def then
			reason = FAIL.Unknown
		elseif not Geom.contains(def.box, actor.x, actor.y, actor.z) then
			reason = FAIL.NotInside
		else
			ok = true
		end
	elseif kind == KIND.Emote then
		ok = true
	elseif
		kind == KIND.HoldStart
		or kind == KIND.HoldEnd
		or kind == KIND.Gadget
	then
		reason = FAIL.Unsupported
	end

	if not ok then
		return false, reason
	end
	actor.nextInteractT = t + Config.Sim.INTERACT_COOLDOWN
	if actor.kind == "live" then
		Sampler.addEvent(actor.rec, t, kind, arg)
	end
	return true, nil
end

-- Intent kinds a client may request (the server maps prompts to these).
Interact.REQUESTABLE = table.freeze({
	[KIND.Grab] = true,
	[KIND.Release] = true,
	[KIND.Press] = true,
	[KIND.Hide] = true,
	[KIND.Emote] = true,
})

return table.freeze(Interact)
