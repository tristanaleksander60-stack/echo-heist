--!strict
-- Sim/Deck: one player's Clone Deck (between-runs card actions). MASTERPLAN §0 C6,
-- §3.1 ("Undo last run"), §3.2 rules 6-7.
--
--   * Slots are the player's clones in record order (slot 1 = ●1). The cap is fixed
--     when the heist starts: min(level.cap, floor(12 / crewSize)).
--   * A run's recording lands in the redo slot if one is armed, else is appended;
--     when the deck is full it replaces the newest slot (the v0.1 rule), so a kid
--     can never be blocked from playing.
--   * Redo #N: the next run replays everything but slot N and re-records slot N.
--   * Redo from #N: deletes the slots after N and re-records N.
--   * Delete #N, Delete busted (every red-flagged slot), Undo last run (restores
--     the deck as it was before the last change: a run's commit or a delete).
-- Only between runs, only your own clones (HeistSim enforces both).

export type Slot = {
	rec: any, -- Codec.Recording
	status: string, -- "New" | "OK" | "Busted" | "Caught" | "Zapped" | "Stuck" | "Shrug"
	run: number, -- run that recorded it
}

export type Deck = {
	cap: number,
	slots: { Slot },
	redo: number?, -- slot re-recorded by the next run
	undo: { Slot }?, -- deck before the last change
}

local Deck = {}

-- Statuses with a red flag in the deck ("Delete busted" removes these).
Deck.RED = table.freeze({ Busted = true, Caught = true, Zapped = true, Stuck = true })

function Deck.new(cap: number): Deck
	return { cap = cap, slots = {}, redo = nil, undo = nil }
end

local function snapshot(deck: Deck)
	deck.undo = table.clone(deck.slots)
end

-- Is slot i replayed in the next run?
function Deck.replays(deck: Deck, i: number): boolean
	return deck.redo ~= i
end

-- Stores a finished run. Returns the slot it went into.
function Deck.commit(deck: Deck, rec: any, run: number, status: string): number
	snapshot(deck)
	local slot: Slot = { rec = rec, status = status, run = run }
	local i: number
	if deck.redo and deck.redo <= #deck.slots then
		i = deck.redo :: number
		deck.slots[i] = slot
	elseif #deck.slots < deck.cap then
		table.insert(deck.slots, slot)
		i = #deck.slots
	else
		i = #deck.slots
		deck.slots[i] = slot
	end
	deck.redo = nil
	return i
end

function Deck.redo(deck: Deck, n: number): boolean
	if n < 1 or n > #deck.slots then
		return false
	end
	deck.redo = n
	return true
end

function Deck.redoFrom(deck: Deck, n: number): boolean
	if n < 1 or n > #deck.slots then
		return false
	end
	snapshot(deck)
	for i = #deck.slots, n + 1, -1 do
		table.remove(deck.slots, i)
	end
	deck.redo = n
	return true
end

function Deck.delete(deck: Deck, n: number): boolean
	if n < 1 or n > #deck.slots then
		return false
	end
	snapshot(deck)
	table.remove(deck.slots, n)
	if deck.redo then
		if deck.redo == n then
			deck.redo = nil
		elseif (deck.redo :: number) > n then
			deck.redo = (deck.redo :: number) - 1
		end
	end
	return true
end

function Deck.deleteBusted(deck: Deck): number
	local removed = 0
	local before = table.clone(deck.slots)
	for i = #deck.slots, 1, -1 do
		if Deck.RED[deck.slots[i].status] then
			table.remove(deck.slots, i)
			removed += 1
		end
	end
	if removed > 0 then
		deck.undo = before
		deck.redo = nil
	end
	return removed
end

function Deck.undoLast(deck: Deck): boolean
	if not deck.undo then
		return false
	end
	deck.slots = deck.undo :: { Slot }
	deck.undo = nil
	deck.redo = nil
	return true
end

function Deck.count(deck: Deck): number
	return #deck.slots
end

return table.freeze(Deck)
