--!strict
-- Sim/Loot: loot items as sim data (no physics, §8.5). MASTERPLAN §3.1 ("banked
-- loot persists inside a heist; carried, unbanked loot resets every loop"), §3.2
-- rule 4 (physical items are single), §3.6 (caught: carried loot drops).
--
-- Item states per run: Home (at its spot), Carried (follows its carrier's sim
-- position), Dropped (where the carrier was taken out or let go), Banked (gone for
-- the rest of the heist, or until `respawn` seconds pass for Clone Party shelves).
-- Heavy loot (grips) is in the format; the sim rejects grips until it ships.
--
-- Bag levels (§4.2 Clone Party, §5.1): in a level with `bags`, an actor carries up
-- to 1 + its owner's bag level small items. `actor.carrying` is the first item (0 =
-- hands free) and `actor.bag` the extra ones in grab order, so a one-item actor is
-- exactly the pre-bag format. Dropping or banking always moves everything carried,
-- first item first (one event per item).

local EventLog = require("./EventLog")

local EV = EventLog.EV
local EPS = 1e-7

export type Item = {
	state: string, -- "Home" | "Carried" | "Dropped" | "Banked"
	x: number,
	y: number,
	z: number,
	carrier: number, -- actor id
	respawnAt: number?, -- loop time a respawning item comes back this run
	spot: number, -- 0 = the item's own position, else index into def.spots
}

export type State = {
	level: any,
	items: { Item },
	gone: { [number]: boolean }, -- banked for the rest of the heist
}

local Loot = {}

function Loot.new(level: any): State
	local state: State = { level = level, items = {}, gone = {} }
	for i, def in level.loot do
		state.items[i] = { state = "Home", x = def.x, y = def.y, z = def.z, carrier = 0, respawnAt = nil, spot = 0 }
	end
	return state
end

local function place(item: Item, def: any, spot: number)
	item.spot = spot
	if spot > 0 then
		local p = def.spots[spot]
		item.x, item.y, item.z = p.x, p.y, p.z
	else
		item.x, item.y, item.z = def.x, def.y, def.z
	end
end

-- Loop start: unbanked loot goes home; respawning items pick a spot with the run's Random.
function Loot.reset(state: State, rng: any)
	for i, def in state.level.loot do
		local item = state.items[i]
		item.carrier = 0
		item.respawnAt = nil
		if state.gone[i] then
			item.state = "Banked"
		else
			item.state = "Home"
			local spot = 0
			if def.respawn and #def.spots > 0 then
				spot = rng:NextInteger(0, #def.spots)
			end
			place(item, def, spot)
		end
	end
end

function Loot.available(state: State, i: number): boolean
	local item = state.items[i]
	return item ~= nil and (item.state == "Home" or item.state == "Dropped")
end

-- Number of items an actor carries.
function Loot.count(actor: any): number
	if actor.carrying == 0 then
		return 0
	end
	local bag = actor.bag
	return 1 + (if bag then #bag else 0)
end

-- The items an actor carries, first item first (a new array).
function Loot.carried(actor: any): { number }
	local out = {}
	if actor.carrying ~= 0 then
		table.insert(out, actor.carrying)
		for _, i in actor.bag or {} do
			table.insert(out, i)
		end
	end
	return out
end

function Loot.take(state: State, i: number, actor: any)
	local item = state.items[i]
	item.state = "Carried"
	item.carrier = actor.id
	if actor.carrying == 0 then
		actor.carrying = i
	else
		actor.bag = actor.bag or {}
		table.insert(actor.bag, i)
	end
end

local function clearCarry(actor: any)
	actor.carrying = 0
	if actor.bag then
		table.clear(actor.bag)
	end
end

-- Puts everything the actor carries down at its position (one event per item).
function Loot.drop(state: State, actor: any, log: EventLog.Log, tick: number, kind: number?)
	if actor.carrying == 0 then
		return
	end
	local items = Loot.carried(actor)
	clearCarry(actor)
	for _, i in items do
		local item = state.items[i]
		item.state = "Dropped"
		item.carrier = 0
		item.x, item.y, item.z = actor.x, actor.y, actor.z
		EventLog.append(log, tick, kind or EV.Drop, actor.id, i)
	end
end

-- Carried loot follows its carrier.
function Loot.follow(state: State, actors: { any })
	for _, a in actors do
		local i = a.carrying
		if i ~= 0 then
			local item = state.items[i]
			item.x, item.y, item.z = a.x, a.y, a.z
			for _, j in a.bag or {} do
				local extra = state.items[j]
				extra.x, extra.y, extra.z = a.x, a.y, a.z
			end
		end
	end
end

-- Banks one item (the caller has taken it off its carrier). Returns its value.
function Loot.bankItem(state: State, i: number, t: number): number
	local def = state.level.loot[i]
	local item = state.items[i]
	item.carrier = 0
	item.state = "Banked"
	if def.respawn then
		item.respawnAt = t + def.respawn
	else
		state.gone[i] = true
	end
	return def.value
end

-- Takes everything off the actor for banking: returns the item indices, first first.
function Loot.unload(actor: any): { number }
	local items = Loot.carried(actor)
	clearCarry(actor)
	return items
end

-- Banks everything the actor carries. Returns the total value.
function Loot.bank(state: State, actor: any, t: number): number
	local total = 0
	for _, i in Loot.unload(actor) do
		total += Loot.bankItem(state, i, t)
	end
	return total
end

-- Respawning items come back on their shelf (Clone Party).
function Loot.tick(state: State, t: number, rng: any, log: EventLog.Log, tick: number)
	for i, item in state.items do
		local at = item.respawnAt
		if at and t >= at - EPS then
			local def = state.level.loot[i]
			item.respawnAt = nil
			item.state = "Home"
			local spot = if #def.spots > 0 then rng:NextInteger(0, #def.spots) else 0
			place(item, def, spot)
			EventLog.append(log, tick, EV.Respawn, i, spot)
		end
	end
end

return table.freeze(Loot)
