--!strict
-- Heist/Protocol: the wire contract between src/server/Heist and src/client/Heist
-- (MASTERPLAN §8.2, §8.6). One file so both sides agree on every name.
--
-- Client -> server (LihFolk Net remotes: rate limit + per-argument validation):
--   Heist.EndRun()                     END RUN (sim refuses it for the first 1.5 s)
--   Heist.Interact(kind, index)        intent: Codec.EVENT kind + LevelSpec index
--   Heist.Deck(op, n?)                 Clone Deck card, between runs, own clones only
--   Heist.Ready(reduced?)              "▶ RUN n" between runs (reduced = reduced motion)
--   Heist.FastForward(on)              hold-to-skip pill
--   Heist.SelectLevel(index)           crew leader picks a tape (garage or results card)
--   Heist.JoinFriend(userId)           join a friend's crew in this server
--   Heist.Leave()                      back to the garage (or out of a crew)
--   Heist.Sync() -> Result             full state for this client (boot, late join)
-- Server -> client: one reliable push, Heist.Msg(type, payload), so order is kept:
--   Sync     the whole state (garage or instance; recordings included)
--   Rec      { key, owner, buf }       one new recording, sent once per client
--   Run      { run, clock, actors, transition, kind }   a run starts (after the rewind)
--   Ev       { run, from, buf }        event-log slice (EventLog.encode layout)
--   Clock    { run, clock }            fast-forward / squeeze re-anchor
--   RunEnd   { run, summary }          the run is over; the deck follows
--   Deck     { cap, slots, redo, canUndo, ready }   this player's Clone Deck
--   Over     { result, award }         heist over: results card
--   Garage   { crew }                  lobby state (crew, leader, pending)
--   Toast    { text }                  short message
-- State (attributes on workspace.Heists.<name>, written only when they change):
--   Phase, RunIndex, Banked, Goal, LevelIndex, Origin, HeistId, CanFF, Ready, Live
--   D<i>Open, D<i>Solid, D<i>SolidAt         doors (SolidAt -1 = none)
--   L<i>On, L<i>OnAt                         lasers (OnAt -1 = none)
--   P<i>Held, P<i>By                         plates (By = first actor id)
--   K<i>State, K<i>Carrier, K<i>Pos          loot (Pos in level space)
--   G<i>Mode, G<i>Offset, G<i>X, G<i>Z, G<i>Yaw, G<i>Focus, G<i>Meter, G<i>Stage
--   AlarmOn, AlarmVanAt

local Protocol = {}

Protocol.FOLDER = "Heists" -- workspace folder holding every instance
Protocol.AVATARS = "HeistAvatars" -- ReplicatedStorage folder of stripped owner templates (§6.5)
Protocol.PLAYER_ATTR = "HeistInstance" -- Player attribute: name of the player's instance ("" = garage)

Protocol.REMOTE = table.freeze({
	EndRun = "Heist.EndRun",
	Interact = "Heist.Interact",
	Deck = "Heist.Deck",
	Ready = "Heist.Ready",
	FastForward = "Heist.FastForward",
	SelectLevel = "Heist.SelectLevel",
	JoinFriend = "Heist.JoinFriend",
	Leave = "Heist.Leave",
	Sync = "Heist.Sync",
	Msg = "Heist.Msg",
})

Protocol.DECK_OPS = table.freeze({ "Redo", "RedoFrom", "Delete", "DeleteBusted", "Undo" })

-- Run kinds for the transition the client plays (§7.1).
Protocol.TRANSITION = table.freeze({ Intro = "Intro", Standard = "Standard", Quick = "Quick", Reduced = "Reduced" })

function Protocol.instanceName(id: number): string
	return "H" .. tostring(id)
end

-- Event-log slice decoding (EventLog.encode: u32 tick, u8 kind, i32 a, i32 b, i32 c).
Protocol.ENTRY_BYTES = 17

export type Entry = { tick: number, kind: number, a: number, b: number, c: number }

function Protocol.decodeEvents(buf: buffer): { Entry }
	local out: { Entry } = {}
	local len = buffer.len(buf)
	local n = len // Protocol.ENTRY_BYTES
	for i = 0, n - 1 do
		local o = i * Protocol.ENTRY_BYTES
		table.insert(out, {
			tick = buffer.readu32(buf, o),
			kind = buffer.readu8(buf, o + 4),
			a = buffer.readi32(buf, o + 5),
			b = buffer.readi32(buf, o + 9),
			c = buffer.readi32(buf, o + 13),
		})
	end
	return out
end

-- Clock as plain data (Rec/LoopClock.Clock).
function Protocol.clockData(clock: any): { [string]: number }
	return {
		anchorServerTime = clock.anchorServerTime,
		anchorLoopT = clock.anchorLoopT,
		rate = clock.rate,
		length = clock.length,
	}
end

-- Safe clock from a payload (never trust shape blindly, even from the server).
function Protocol.readClock(v: any): any
	if type(v) ~= "table" then
		return nil
	end
	for _, k in { "anchorServerTime", "anchorLoopT", "rate", "length" } do
		local x = v[k]
		if type(x) ~= "number" or x ~= x then
			return nil
		end
	end
	if v.rate <= 0 or v.length <= 0 then
		return nil
	end
	return table.freeze({
		anchorServerTime = v.anchorServerTime,
		anchorLoopT = v.anchorLoopT,
		rate = v.rate,
		length = v.length,
	})
end

return table.freeze(Protocol)
