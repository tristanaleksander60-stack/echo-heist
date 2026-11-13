--!strict
-- Heist/Protocol: the wire contract between src/server/Heist and src/client/Heist
-- (MASTERPLAN §8.2, §8.6). One file so both sides agree on every name.
--
-- Client -> server (LihFolk Net remotes: rate limit + per-argument validation):
--   Heist.EndRun()                     END RUN (sim refuses it for the first 1.5 s)
--   Heist.Interact(kind, index)        intent: Codec.EVENT kind + LevelSpec index. A refused
--                                      live intent comes back as an Ev `Rejected` entry
--                                      (a = actor, b = kind, c = Interact.FAIL code), e.g.
--                                      FAIL.Locked (10) for the Clone Party till before 0:20
--   Heist.Deck(op, n?)                 Clone Deck card, between runs, own clones only (refused on
--                                      L1 and party levels: every party clone stays for "8 OF ME")
--   Heist.Ready(arg?)                  "▶ RUN n" between runs (arg = reduced motion, a boolean), or in the
--                                      hideout a lobby action table { op, bay?, n? } (Shared/Heist/VanRules:
--                                      claim, paint, crew, park, solo, go, sit, ready, unready, stand, and (LOBBY 2)
--                                      style (bay, n), quick, unquick, open (bay), shut (bay), and (PARTY)
--                                      size (bay, n = 2..4), privacy (bay, n = Config.Hideout.PARTY.PRIVACY),
--                                      kick (bay, n = seat 2..); the
--                                      validator is VanRules.validReadyArg, the server re-checks every rule)
--   Heist.FastForward(on)              hold-to-skip pill
--   Heist.SelectLevel(index, relaxed?) crew leader picks a tape (garage or results card);
--                                      index = Levels/Catalog index (PLAY order, not design n).
--                                      relaxed = true: the "Try Relaxed?" card. Accepted only
--                                      mid-heist on the level being played, from the leader the
--                                      server offers it to (HeistSim.offerRelaxed: 3 catches);
--                                      the heist restarts as Levels/Relaxed (story levels only)
--   Heist.SelectDaily(day?)            crew leader starts the daily vault: nil = today, else an
--                                      advent day to catch up (UTC day number from the garage);
--                                      refused until Night Clerk is cleared (PLAN D4,
--                                      Config.Onboarding.DAILY_UNLOCK_LEVEL)
--   (SelectLevel / SelectDaily: one new heist per player pick per INSTANCE_COOLDOWN_SECONDS; in the hideout
--    (Config.Hideout) a garage pick pins the crew's job instead, and the van's SOLO / GO starts it)
--   Heist.JoinFriend(userId)           join a friend's crew in this server
--   Heist.Leave()                      back to the garage (or out of a crew); mid-heist from the
--                                      HUD's ❚❚ menu: solo ends the heist, co-op leaves it
--   Heist.Sync() -> Result             full state for this client (boot, late join)
-- Server -> client: one reliable push, Heist.Msg(type, payload), so order is kept:
--   Sync     the whole state (garage or instance; recordings included). Heist sync adds
--            levelIndex (0 = daily vault), level = LevelInfo, daily = DailyInfo?, tuning,
--            dressing (Christmas layer on), kit (built from the art kit). where = "preparing"
--            (a new account while the server starts its first heist: show the van door, not
--            the garage). Garage sync: levels[i] adds needsClear (data key) / starsNeeded for
--            a locked tape; daily.locked until Night Clerk is cleared (daily.needsClear = its
--            name); heist sync adds relaxed (the level is Levels/Relaxed)
--   Rec      { key, owner, buf }       one new recording, sent once per client
--   Run      { run, clock, actors, transition, kind, cap, keys }   a run starts (each actor:
--            id, kind, owner, seat, slot, key, run, orphan, helper, capacity = bag size)
--   Ev       { run, from, buf }        event-log slice (EventLog.encode layout); carries Swarm
--            (a = seat, b = copies of that player, c = the crew's), Tier, AlarmOn,
--            AlarmLock, VanLeft, Dawn, Rejected/Shrug with Interact.FAIL codes
--   Clock    { run, clock }            fast-forward / squeeze re-anchor
--   RunEnd   { run, summary }          the run is over; the deck follows. summary adds
--            alarm = AlarmInfo? (who tripped it, when, hint), tierMet, swarm (most copies
--            of one player this run), escaped (the crew banked after the alarm and got away)
--   Deck     { cap, slots, redo, canUndo, locked, party, hint?, relaxedOffer, relaxed }   this
--            player's Clone Deck; relaxedOffer = the server offers this player Relaxed (the
--            "Try Relaxed?" card: HeistSim.offerRelaxed, and they lead the crew);
--            hint = { kind = "RedoAlarm", slot, t } when one of YOUR clones set the alarm
--            off in its first ALARM_HINT_SECONDS ("Clone #N sets off the alarm: Redo #N?")
--   Over     { result, award, daily? } heist over: results card. result adds kind
--            ("story" | "party" | "daily"), levelId, name, haul, tiers, tierMet, ofMe,
--            nextIndex (Catalog index of NEXT, 0 = none), lineup = { LineupEntry }
--            (HeistSim.lineup: the scripted Crew Line-up), tuning. award = this player's
--            DataService result ({ ok, code, data = AwardSummary | DailySummary }); next =
--            this player's { unlocked, starsNeeded, needsClear } for nextIndex (after the award)
--   Garage   { crew }                  lobby state (crew, leader, pending)
--   Depart   { bay, seconds, paint }   the hideout: your crew's van left (GO); the client plays the drive and
--            the heist's Sync follows `seconds` later. Garage sync adds lobby (vans on), van (your crew's bay,
--            0 = none), job / jobDay (the pinned job; 0 + a day = the daily vault)
--   Leader   { leader }                the crew leader changed while the results card is up
--   Toast    { text }                  short message
-- State (attributes on workspace.Heists.<name>, written only when they change):
--   Phase, RunIndex, Banked, Goal, LevelIndex, LevelId, Kind, Origin, HeistId, CanFF,
--   Ready, Crew, Leader, Daily (UTC day, daily vaults only), Dressing, Kit, Tuning,
--   AutoEndArmed (L1: the tutorial auto-end applies this run), AutoStartAt (server time the
--   next run starts by itself, between runs), Relaxed (the level is Levels/Relaxed)
--   D<i>Open, D<i>Solid, D<i>SolidAt         doors (SolidAt -1 = none)
--   L<i>On, L<i>OnAt                         lasers (OnAt -1 = none)
--   P<i>Held, P<i>By                         plates (By = first actor id)
--   K<i>State, K<i>Carrier, K<i>Pos          loot (Pos in level space)
--   K<i>OpensAt                              static: a time-locked item's loop time (the till)
--   G<i>Mode, G<i>Offset, G<i>X, G<i>Z, G<i>Yaw, G<i>Focus, G<i>Meter, G<i>Stage
--   AlarmOn, AlarmVanAt, AlarmLockAt, AlarmBy (actor id, 0 = a catch), TierMet
-- Level parts (workspace.Heists.<name>.Level): EH_Kind / EH_Index as before. When the art
-- kit is used (attribute Kit = true) the tagged door leaves, plates and loot are kit
-- MeshParts sized to the sim boxes; static kit dressing carries EH_Kind = "kit". A door
-- with a code-driven kit skin (the vault door) keeps its greybox leaf as the tagged part
-- (EH_HasSkin = true) and gets a Model EH_Kind = "doorSkin", EH_Index = i, EH_Mode
-- ("swing"), EH_OpenYaw (degrees, about the Model's pivot = the hinge). Its parts are
-- built invisible with their real transparency in EH_Alpha: a client that draws skins
-- hides the leaf locally and shows the skin; an older client keeps the greybox leaf.

local Catalog = require("../Levels/Catalog")
local DailyVaults = require("../Levels/DailyVaults")
local Relaxed = require("../Levels/Relaxed")

local Protocol = {}

Protocol.FOLDER = "Heists" -- workspace folder holding every instance
Protocol.AVATARS = "HeistAvatars" -- ReplicatedStorage folder of stripped owner templates (§6.5)
Protocol.PLAYER_ATTR = "HeistInstance" -- Player attribute: name of the player's instance ("" = garage)
Protocol.DAILY_INDEX = 0 -- levelIndex of a daily vault instance (its spec comes from the day)

Protocol.REMOTE = table.freeze({
	EndRun = "Heist.EndRun",
	Interact = "Heist.Interact",
	Deck = "Heist.Deck",
	Ready = "Heist.Ready",
	FastForward = "Heist.FastForward",
	SelectLevel = "Heist.SelectLevel",
	SelectDaily = "Heist.SelectDaily",
	JoinFriend = "Heist.JoinFriend",
	Leave = "Heist.Leave",
	Sync = "Heist.Sync",
	Msg = "Heist.Msg",
})

Protocol.DECK_OPS = table.freeze({ "Redo", "RedoFrom", "Delete", "DeleteBusted", "Undo" })

-- FTUE funnel order (§7.5 onb_v2): DataService.setFtueStep saves the highest index reached
-- (profile heist.ftueStep). Server: HeistService.FTUE_STEPS; client: Heist/FirstTime seeds the
-- first-time beats from it. Append only (saved indices must keep their meaning).
Protocol.FTUE_STEPS = table.freeze({
	"Joined",
	"FirstMove",
	"FirstPlate",
	"FirstRewind",
	"FirstCloneSeen",
	"FirstBank",
	"L1Complete",
	"ReelShown",
	"L2Started",
	"FirstCloneBusted",
	"SwarmSeen",
	"Minute10",
})

-- Run kinds for the transition the client plays (§7.1).
Protocol.TRANSITION = table.freeze({ Intro = "Intro", Standard = "Standard", Quick = "Quick", Reduced = "Reduced" })

-- Level kinds on the wire (results card, garage list).
Protocol.KIND = table.freeze({ Story = "story", Party = "party", Daily = "daily" })

export type LevelInfo = {
	id: string, -- LevelSpec id (cs1_back_room, dv03_candy_cane_lasers, ...)
	name: string,
	kind: string, -- Protocol.KIND
	num: number, -- design number (spec.num)
	dataKey: string?, -- Config.Data.Levels key (story / party levels)
	location: string?,
}

export type DailyInfo = {
	day: number, -- UTC day number the vault belongs to (Data/Calendar.dayIndex)
	slot: number, -- rotation slot (= design number, DailyVaults.byNumber)
	modifier: string, -- DailyVaults.MODIFIERS
	mode: string, -- "today" | "catchUp" (Data/DailyVault.playMode)
	advent: number?, -- December day in the advent window
}

export type AlarmInfo = {
	t: number, -- loop seconds into the run
	kind: string, -- "live" | "clone" | "catch"
	ownerId: number, -- 0 for a catch
	slot: number, -- the clone's deck slot (0 = not a clone)
	hint: string?, -- "RedoAlarm": a clone tripped it in its first ALARM_HINT_SECONDS
}

export type LineupEntry = {
	kind: string, -- "clone" | "player"
	ownerId: number,
	seat: number,
	slot: number, -- 0 = the player
	run: number,
	delay: number, -- seconds after the line-up starts (record order)
	x: number, -- level space
	z: number,
	yaw: number,
}

function Protocol.instanceName(id: number): string
	return "H" .. tostring(id)
end

-- The LevelSpec an instance plays: a Catalog index, or the daily vault of a UTC day
-- (levelIndex = DAILY_INDEX). Client and server compile the same spec with
-- Sim/LevelSpec.compile, so the daily modifier (DailyVaults.forDay) is never sent. relaxed =
-- the Relaxed modifier (Levels/Relaxed; story levels of the Catalog only, else nil).
function Protocol.levelSpec(levelIndex: number, dailyDay: number?, relaxed: boolean?): any
	if levelIndex == Protocol.DAILY_INDEX then
		if relaxed or type(dailyDay) ~= "number" or dailyDay ~= dailyDay then
			return nil
		end
		local spec = DailyVaults.forDay(math.floor(dailyDay))
		return spec
	end
	local spec = Catalog[levelIndex]
	if relaxed and spec then
		return if Relaxed.canApply(spec) then Relaxed.apply(spec) else nil
	end
	return spec
end

-- Catalog index of a LevelSpec id (nil if it is not a launch level). Never hard-code
-- indices: the Catalog is in play order (Clone Party is played third).
function Protocol.catalogIndex(specId: string): number?
	for i, spec in Catalog do
		if spec.id == specId then
			return i
		end
	end
	return nil
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
