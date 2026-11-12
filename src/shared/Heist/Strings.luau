--!strict
-- Heist/Strings: every player-facing string of the client Heist UI (HUD, deck, results,
-- garage, rewind, Line-up, Gus), so the words pass is one diff and tests assert keys,
-- not text (docs/PLAN_STEAM_PLUS.md §4.0, §6.3). Keys are UPPER_SNAKE text; functions
-- build the strings that carry numbers. Pure: no engine calls and no requires, so Lune
-- tests read it too. Money and clock values arrive already formatted (Ui.money,
-- Ui.clock) as strings.
-- Server-sent toasts (Heist.Msg "Toast") and sound captions (Shared/Audio/Cues) live
-- with their senders.

local Strings = {}

local function plural(n: number, word: string): string
	return string.format("%d %s%s", n, word, if n == 1 then "" else "s")
end

-- Joins short parts on one line ("RUN 6 · 8 OF ME · $1,000").
Strings.SEP = " · "

---------------------------------------------------------------------------
-- Runs and the top bar
---------------------------------------------------------------------------
Strings.LAST_RUN = "LAST RUN"
function Strings.run(n: number): string
	return "RUN " .. tostring(n)
end
function Strings.runOfDawn(n: number, dawn: number): string
	return string.format("RUN %d/%d", n, dawn)
end
-- A redo run's label: "REDO ●3".
function Strings.redoRun(badge: string): string
	return "REDO " .. badge
end
-- The timer in its last seconds: "◎ 0:04".
function Strings.timerRed(clock: string): string
	return "◎ " .. clock
end
-- The loot meter: "$400 / $1,000"; party levels "$2,350 / $2,500 ★2", then "$3,100 ★★★".
function Strings.lootOfGoal(have: string, goal: string): string
	return have .. " / " .. goal
end
function Strings.lootOfTier(have: string, nextTier: string, tier: number): string
	return string.format("%s / %s ★%d", have, nextTier, tier)
end
function Strings.lootAllTiers(have: string, tiers: number): string
	return have .. " " .. string.rep("★", tiers)
end
-- The Alarm Run counter: "◎ VAN LEAVES 0:14 · SHUTTER 0:04".
function Strings.alarmVan(clock: string): string
	return "◎ VAN LEAVES " .. clock
end
function Strings.alarmShutter(clock: string): string
	return " · SHUTTER " .. clock
end
-- Run-bar markers: your clones' grabs, zaps and busts.
Strings.MARK_GRAB = "$"
Strings.MARK_ZAP = "⚡"
Strings.MARK_BUST = "✕"

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
Strings.END_RUN = "◀◀\nEND RUN"
function Strings.endRunCrew(ended: number, crew: number): string
	return string.format("◀◀\nEND RUN · %d/%d", ended, crew)
end
Strings.GRAB = "GRAB"
function Strings.grab(value: string): string
	return "GRAB " .. value
end
function Strings.lockedFor(clock: string): string
	return "LOCKED " .. clock
end
Strings.FAST_FORWARD = "⏩ HOLD"

---------------------------------------------------------------------------
-- Menu, hidden, preparing
---------------------------------------------------------------------------
Strings.MENU = "❚❚"
Strings.MENU_TITLE = "Leave this heist?"
Strings.KEEP_PLAYING = "KEEP PLAYING"
Strings.BACK_TO_GARAGE = "BACK TO GARAGE"
Strings.HIDDEN = "◐ HIDDEN"
Strings.PREPARING = "The van door opens..."

---------------------------------------------------------------------------
-- Clone Deck (between runs)
---------------------------------------------------------------------------
Strings.STATUS = table.freeze({
	New = "NEW",
	OK = "OK",
	Busted = "BUSTED",
	Caught = "CAUGHT",
	Zapped = "ZAPPED",
	Stuck = "STUCK",
	Shrug = "?",
})
Strings.STATUS_REDO = "REDO"
Strings.STATUS_ALARM = "◎ ALARM"
Strings.DECK_TITLE = "CLONES"
function Strings.deckTitle(n: number, cap: number): string
	return string.format("CLONES %d/%d · tap a card to redo it", n, cap)
end
-- The RedoAlarm hint in the deck title.
function Strings.redoAlarmHint(badge: string): string
	return string.format("◎ Clone %s sets off the alarm. Redo %s?", badge, badge)
end
Strings.REDO = "REDO"
Strings.REDO_FROM = "REDO + LATER"
Strings.DELETE = "DELETE"
Strings.UNDO = "UNDO"
Strings.DELETE_BUSTED = "DELETE BUSTED ✕"
function Strings.redo(badge: string): string
	return "REDO " .. badge
end
function Strings.redoFrom(badge: string): string
	return "REDO " .. badge .. " + LATER"
end
function Strings.delete(badge: string): string
	return "DELETE " .. badge
end
-- A deck card: the clone's badge over its status.
function Strings.card(badge: string, status: string): string
	return badge .. "\n" .. status
end
-- A red-flagged clone in the strip: its seat glyph and a cross.
function Strings.stripBusted(glyph: string): string
	return glyph .. "✕"
end
Strings.WAITING = "WAITING..."
-- The RUN button: "▶ RUN 3"; between runs "▶ RUN 3 · 2/3 READY · 0:08".
function Strings.startRun(runName: string): string
	return "▶ " .. runName
end
function Strings.readyCount(ready: number, crew: number): string
	return string.format(" · %d/%d READY", ready, crew)
end
function Strings.autoStartIn(clock: string): string
	return " · " .. clock
end
function Strings.partyKeepsAll(clones: number): string
	return string.format("Every clone stays for the party: %d", clones)
end

---------------------------------------------------------------------------
-- Results card
---------------------------------------------------------------------------
Strings.HEIST_COMPLETE = "HEIST COMPLETE"
Strings.HEIST_OVER = "HEIST OVER"
Strings.VAULT_CLEARED = "VAULT CLEARED"
Strings.VAULT_OVER = "VAULT OVER"
Strings.DAWN = "DAWN"
function Strings.partyOver(tiers: number): string
	return string.format("PARTY OVER · ★%d", tiers)
end
Strings.MEDAL_HAUL = "HAUL"
Strings.MEDAL_CREW = "CREW"
Strings.MEDAL_CLEAN = "CLEAN"
-- A results stamp: "★ HAUL" when earned, "☆ HAUL" when not.
function Strings.stamp(text: string, on: boolean): string
	return (if on then "★ " else "☆ ") .. text
end
function Strings.ofMe(n: number): string
	return string.format("%d OF ME", n)
end
function Strings.robbers(n: number): string
	return string.format("%d ROBBERS", n)
end
function Strings.clones(n: number): string
	return plural(n, "clone")
end
function Strings.runs(n: number): string
	return plural(n, "run")
end
function Strings.streak(n: number): string
	return string.format("STREAK %d", n)
end
Strings.NEW_ORNAMENT = "NEW ORNAMENT"
function Strings.plusStars(n: number): string
	return string.format("+%d ★", n)
end
function Strings.newMedals(list: string): string
	return "NEW: " .. string.upper(list)
end
Strings.NEW_TAPE_UNLOCKED = "NEW TAPE UNLOCKED"
function Strings.plusCash(money: string): string
	return "+" .. money
end
Strings.SAVE_FAILED = "Couldn't save this one."
function Strings.starsOpenNext(n: number): string
	return string.format("%d more ★ opens the next tape", n)
end
Strings.CLEAR_TO_OPEN_NEXT = "Clear this tape to open the next one"
Strings.LEADER_PICKS_NEXT = "Your crew leader picks what's next"
Strings.REPLAY = "REPLAY"
Strings.NEXT = "NEXT ▶"
Strings.GARAGE = "GARAGE"
Strings.LEAVE = "LEAVE"

---------------------------------------------------------------------------
-- Garage
---------------------------------------------------------------------------
Strings.PICK_A_TAPE = "PICK A TAPE"
Strings.ADVENT_CATCH_UP = "ADVENT CATCH-UP"
Strings.DAILY_VAULT = "DAILY VAULT"
function Strings.dailyVaultOn(when: string): string
	return "DAILY VAULT · " .. when
end
Strings.CATCH_UP = "CATCH UP"
function Strings.catchUpCount(n: number): string
	return string.format("CATCH UP (%d)", n)
end
Strings.BACK_TO_TAPES = "◀ TAPES"
Strings.PLAY = "PLAY"
Strings.CLOSED = "CLOSED"
Strings.REPLAY_CLEARED = "REPLAY ✓"
Strings.DAILY_CLOSED = "The daily vault is closed right now."
Strings.LEADER_PICKS_TAPE = "Your crew leader picks the tape."
function Strings.partyTag(cap: number): string
	return string.format("PARTY · %d CLONES", cap)
end
function Strings.runSeconds(seconds: number): string
	return string.format("%d SEC RUNS", seconds)
end
function Strings.lockClear(name: string): string
	return "CLEAR " .. string.upper(name)
end
function Strings.lockStars(n: number): string
	return string.format("★ %d MORE", n)
end
Strings.LOCKED = "LOCKED"
-- A tape on the shelf: "3  LIGHTS OUT\n30 SEC RUNS\n★★☆".
function Strings.tape(index: number, name: string, tag: string, status: string): string
	return string.format("%d  %s\n%s\n%s", index, string.upper(name), tag, status)
end
-- Medal count on a tape: "★★☆".
function Strings.tapeStars(n: number): string
	local got = math.min(n, 3)
	return string.rep("★", got) .. string.rep("☆", math.max(0, 3 - n))
end
function Strings.clearFirst(name: string): string
	return "Clear " .. name .. " first."
end
function Strings.starsToOpen(n: number): string
	return string.format("%d more ★ to open it.", n)
end
Strings.TAPE_LOCKED = "That tape is locked."
function Strings.advent(day: number): string
	return "DEC " .. tostring(day)
end
function Strings.catchUpTape(when: string, name: string): string
	return string.format("%s\n%s\nCATCH UP", when, string.upper(name))
end
function Strings.newIn(duration: string): string
	return "new in " .. duration
end
-- Daily vault modifiers (Levels/DailyVaults.MODIFIERS) as the garage card shows them.
Strings.MODIFIER = table.freeze({
	None = "",
	GuardFast = "FAST GUS",
	GuardSlow = "SLEEPY GUS",
	LootB = "LOOT MOVED",
	LootC = "LOOT MOVED",
	LightsOff = "LIGHTS OUT",
})
Strings.MONTHS = table.freeze({ "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" })
function Strings.date(month: string, day: number): string
	return string.format("%s %d", month, day)
end
function Strings.hoursMinutes(h: number, m: number): string
	return string.format("%dh %02dm", h, m)
end
function Strings.minutes(m: number): string
	return string.format("%dm", m)
end
Strings.CREW = "CREW"
-- A crew row: "● Ana (leader)".
function Strings.crewMember(glyph: string, name: string, leader: boolean): string
	return glyph .. " " .. name .. (if leader then " (leader)" else "")
end
Strings.JOIN_NEXT_HEIST = "You join at their next heist."
Strings.LEAVE_CREW = "LEAVE CREW"
function Strings.join(name: string): string
	return "JOIN " .. name
end

---------------------------------------------------------------------------
-- During a run: toasts, spectate lines, stamps
---------------------------------------------------------------------------
Strings.LAST_RUN_BEFORE_DAWN = "☾ Last run before Dawn!"
function Strings.dawnAfter(runs: number): string
	return string.format("☾ Dawn after %d more run%s", runs, if runs == 1 then "" else "s")
end
Strings.GUS_RAISED_ALARM = "Gus raised the alarm."
function Strings.cloneSetOffAlarm(badge: string): string
	return string.format("Clone %s set off the alarm.", badge)
end
Strings.YOU_SET_OFF_ALARM = "You set off the alarm."
Strings.LOCKED_WAIT = "Locked. Wait for the timer."
function Strings.lockedOpensIn(clock: string): string
	return "Locked: opens in " .. clock
end
Strings.TAPE_RAN_OUT = "The tape ran out."
Strings.WAIT_FOR_CREW = "Wait for your crew"
Strings.GUARD_SPOTTED_YOU = "[Guard spotted you]"
Strings.ZAPPED_BY_LASER = "Zapped by a laser."
-- A bank toast: "●3 +$100" for a clone, "+$100" for a player.
function Strings.banked(who: string?, money: string): string
	return (if who then who .. " " else "") .. "+" .. money
end
Strings.CREW_WAITING = "Crew is waiting"
Strings.GOAL_BANKED = "Goal banked! Finish the run."
Strings.TILL_ALARM = "Till alarm: everyone to the van!"
function Strings.cloneSetOffAlarmNow(badge: string): string
	return string.format("Clone %s set off the alarm!", badge)
end
Strings.GUS_RAISED_ALARM_RUN = "Gus raised the alarm! Run for the van!"
Strings.RUN_FOR_VAN = "Run for the van!"

-- Big stamps
Strings.STAMP_BUSTED = "BUSTED"
Strings.STAMP_ZAPPED = "ZAPPED"
Strings.STAMP_ESCAPED = "ESCAPED!"
Strings.STAMP_GETAWAY = "GETAWAY!"
Strings.STAMP_ALARM = "ALARM!"
Strings.STAMP_VAN_LEFT = "THE VAN LEFT"
Strings.STAMP_DAWN = "☾ DAWN"
Strings.STAMP_HEIST_COMPLETE = "HEIST COMPLETE"
function Strings.stampTier(n: number): string
	return string.format("★ HAUL %d", n)
end

-- Objective lines (≤ 8 words, MASTERPLAN §7.4; L1 FTUE §7.5)
Strings.OBJ_STAY_ON_PLATE = "Stay on it. Tap END RUN."
Strings.OBJ_STEP_ON_PLATE = "Step on the plate"
Strings.OBJ_CLONE_STOPS = "Your clone stops where you stop."
Strings.OBJ_WAIT_FOR_CLONE = "Wait for your clone to open the door"
Strings.OBJ_BANK_IT = "Bank it at the van"
Strings.OBJ_GRAB_CASH = "Grab the cash"
Strings.OBJ_GRAB_LOOT = "Grab the loot"
-- Level lines for the first seconds of run 1, and again when stuck, by LevelSpec id.
Strings.LEVEL_LINES = table.freeze({
	cs2_two_doors = "Two plates. You need two clones.",
	cs5_clone_party = "Rob it all. Bank it before Dawn.",
	cs3_lights_out = "Plate B turns the lasers off.",
	cs4_night_clerk = "Hide from Gus. Cross while he looks away.",
	bk1_big_score = "The vault. Every clone counts.",
} :: { [string]: string })

---------------------------------------------------------------------------
-- Rewind, Line-up, Gus, clone labels
---------------------------------------------------------------------------
Strings.REWIND_ARROWS = "◀◀"
Strings.SKIP = "SKIP ▶▶"
Strings.ME = "ME"
Strings.YOU = "YOU"
-- Gus's head label by vision stage.
Strings.GUS_SPOTTED = "!"
Strings.GUS_HUH = "huh?"
Strings.GUS_SUSPICIOUS = "?"
-- "20 SEC AGO" / "1 MIN AGO" (LineupPlan.agoRound gives the number, CLIPS §1.2).
function Strings.ago(n: number, minutes: boolean): string
	return string.format(if minutes then "%d MIN AGO" else "%d SEC AGO", n)
end
-- The burned-in clone label: "◀ ME, 20 SEC AGO" (arrowHex colours the arrow, RichText).
function Strings.agoLabel(who: string, ago: string, arrowHex: string): string
	return string.format('<font color="#%s">◀</font> %s, %s', arrowHex, who, ago)
end

return table.freeze(Strings)
