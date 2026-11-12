--!strict
-- Heist/Strings: every player-facing string of the client Heist UI (HUD, deck, results,
-- garage, rewind, Line-up, Gus), so the words pass is one diff and tests assert keys,
-- not text (docs/PLAN_STEAM_PLUS.md §4.0, §6.3). Keys are UPPER_SNAKE text; functions
-- build the strings that carry numbers. Pure: no engine calls and no requires, so Lune
-- tests read it too. Money and clock values arrive already formatted (Ui.money,
-- Ui.clock) as strings.
-- Glossary (§6.3): clone (never echo or tape), REWIND, door, laser, cash / loot, van,
-- Gus, caught / BUSTED, crew, sunrise (DAWN only as a stamp). Lines stay at 8 words or
-- fewer. ASCII only (tests/glyph_check.luau, S4: text glyphs render as boxes or emoji
-- on phones; icons come as images in phase 2); the one allowed symbol is SEP's middle
-- dot, which every UI font has.
-- Server-sent toasts (Heist.Msg "Toast") and sound captions (Shared/Audio/Cues) live
-- with their senders.

local Strings = {}

local function plural(n: number, word: string): string
	return string.format("%d %s%s", n, word, if n == 1 then "" else "s")
end

local function s(n: number): string
	return if n == 1 then "" else "s"
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
-- A redo run's label: "REDO 3" (clone 3 is being redone).
function Strings.redoRun(slot: number): string
	return "REDO " .. tostring(slot)
end
-- The loot meter: "$400 / $1,000"; party levels "$2,350 / $2,500 STAR 2", then
-- "$3,100 ALL STARS".
function Strings.lootOfGoal(have: string, goal: string): string
	return have .. " / " .. goal
end
function Strings.lootOfTier(have: string, nextTier: string, tier: number): string
	return string.format("%s / %s STAR %d", have, nextTier, tier)
end
function Strings.lootAllTiers(have: string): string
	return have .. " ALL STARS"
end
-- The Alarm Run counter: "VAN LEAVES 0:14 · DOORS LOCK 0:04".
function Strings.alarmVan(clock: string): string
	return "VAN LEAVES " .. clock
end
function Strings.alarmDoorsLock(clock: string): string
	return " · DOORS LOCK " .. clock
end
-- Run-bar markers: your clones' grabs, zaps and busts.
Strings.MARK_GRAB = "$"
Strings.MARK_ZAP = "!"
Strings.MARK_BUST = "X"

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------
-- The signature verb (§6.1 item 1): the button that ends your run and rewinds time.
-- The remote stays Heist.EndRun.
Strings.REWIND = "REWIND"
function Strings.rewindCrew(ended: number, crew: number): string
	return string.format("REWIND\n%d/%d", ended, crew)
end
Strings.GRAB = "GRAB"
function Strings.grab(value: string): string
	return "GRAB " .. value
end
function Strings.lockedFor(clock: string): string
	return "LOCKED " .. clock
end
Strings.FAST_FORWARD = "HOLD\nFAST"

---------------------------------------------------------------------------
-- Menu, hidden, preparing
---------------------------------------------------------------------------
Strings.MENU = "MENU"
Strings.MENU_TITLE = "Leave this heist?"
Strings.KEEP_PLAYING = "KEEP PLAYING"
Strings.BACK_TO_GARAGE = "BACK TO GARAGE"
Strings.HIDDEN = "HIDDEN"
-- The MENU's camera A/B button (Heist/CameraDirector modes); the label names the mode in use.
Strings.CAMERA_MODE = table.freeze({
	diorama = "CAMERA: DIORAMA",
	classic = "CAMERA: CLASSIC",
})
function Strings.cameraMode(mode: string?): string
	return Strings.CAMERA_MODE[mode or "diorama"] or Strings.CAMERA_MODE.diorama
end
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
-- A clone's speech bubble over its head (EchoView) when the server decides its outcome; Stuck
-- also shows the cross icon.
Strings.CLONE_BUBBLE = table.freeze({
	Busted = "BUSTED",
	Zapped = "ZAP!",
	Stuck = "STUCK",
	Shrug = "?",
})
Strings.STATUS_REDO = "REDO"
Strings.STATUS_ALARM = "ALARM"
Strings.DECK_TITLE = "CLONES"
-- The deck title; after a failed run it leads with why ("Gus caught you. · CLONES 2/4").
function Strings.deckTitle(n: number, cap: number, reason: string?): string
	if reason and reason ~= "" then
		return string.format("%s · CLONES %d/%d", reason, n, cap)
	end
	return string.format("CLONES %d/%d · tap a card to redo it", n, cap)
end
-- The RedoAlarm hint in the deck title.
function Strings.redoAlarmHint(slot: number): string
	return string.format("Clone %d sets off the alarm. Redo it?", slot)
end
Strings.REDO = "REDO"
Strings.REDO_FROM = "REDO FROM"
Strings.DELETE = "DELETE"
Strings.UNDO = "UNDO"
Strings.DELETE_BUSTED = "DELETE BUSTED"
function Strings.redo(slot: number): string
	return "REDO " .. tostring(slot)
end
-- Redo this clone and drop every later one.
function Strings.redoFrom(slot: number): string
	return "REDO FROM " .. tostring(slot)
end
function Strings.delete(slot: number): string
	return "DELETE " .. tostring(slot)
end
-- A clone's number in its coloured pill (strip chips, deck cards).
function Strings.cloneNumber(slot: number): string
	return tostring(slot)
end
-- A red-flagged clone's number, struck through (RichText).
function Strings.cloneNumberBusted(slot: number): string
	return "<s>" .. tostring(slot) .. "</s>"
end
-- More clones than the strip shows: "+3".
function Strings.moreClones(n: number): string
	return "+" .. tostring(n)
end
-- A clone named in a line: "Clone 3" (yours) or "P2 clone 3" (a crewmate's).
function Strings.cloneName(seat: number, slot: number, mySeat: number): string
	if seat == mySeat then
		return "Clone " .. tostring(slot)
	end
	return string.format("P%d clone %d", seat, slot)
end
Strings.WAITING = "WAITING..."
-- The RUN button: "GO: RUN 3"; between runs "GO: RUN 3 · 2/3 READY · 0:08".
function Strings.startRun(runName: string): string
	return "GO: " .. runName
end
function Strings.readyCount(ready: number, crew: number): string
	return string.format(" · %d/%d READY", ready, crew)
end
function Strings.autoStartIn(clock: string): string
	return " · " .. clock
end
function Strings.partyKeepsAll(clones: number): string
	return string.format("Party! All %d clones come back.", clones)
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
	return string.format("PARTY OVER · %d STAR%s", tiers, if tiers == 1 then "" else "S")
end
Strings.MEDAL_HAUL = "HAUL"
Strings.MEDAL_CREW = "CREW"
Strings.MEDAL_CLEAN = "CLEAN"
-- A results stamp (RichText): "HAUL STAR" when earned, "HAUL" struck through when not.
function Strings.stamp(text: string, on: boolean): string
	return if on then text .. " STAR" else "<s>" .. text .. "</s>"
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
	return string.format("+%d STAR%s", n, if n == 1 then "" else "S")
end
function Strings.newMedals(list: string): string
	return "NEW: " .. string.upper(list)
end
Strings.NEW_HEIST_UNLOCKED = "NEW HEIST UNLOCKED"
function Strings.plusCash(money: string): string
	return "+" .. money
end
Strings.SAVE_FAILED = "Couldn't save this one."
-- Studio play tests have no DataStores (S6): a neutral chip, not a failure.
Strings.STUDIO_NOT_SAVED = "Studio test: progress not saved"
function Strings.starsOpenNext(n: number): string
	return string.format("%d more star%s open%s the next heist", n, s(n), if n == 1 then "s" else "")
end
Strings.WIN_TO_OPEN_NEXT = "Win this to open the next one"
Strings.LEADER_PICKS_NEXT = "Your crew leader picks what's next"
Strings.REPLAY = "REPLAY"
Strings.NEXT = "NEXT"
Strings.GARAGE = "GARAGE"
Strings.LEAVE = "LEAVE"

---------------------------------------------------------------------------
-- Garage
---------------------------------------------------------------------------
Strings.PICK_A_HEIST = "PICK A HEIST"
Strings.ADVENT_CATCH_UP = "ADVENT CATCH-UP"
Strings.DAILY_VAULT = "DAILY VAULT"
function Strings.dailyVaultOn(when: string): string
	return "DAILY VAULT · " .. when
end
Strings.CATCH_UP = "CATCH UP"
function Strings.catchUpCount(n: number): string
	return string.format("CATCH UP (%d)", n)
end
Strings.BACK = "BACK"
Strings.PLAY = "PLAY"
Strings.CLOSED = "CLOSED"
Strings.DONE_TODAY = "DONE TODAY"
Strings.DAILY_CLOSED = "The daily vault is closed right now."
Strings.LEADER_PICKS_HEIST = "Your crew leader picks the heist."
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
	return string.format("%d MORE STAR%s", n, if n == 1 then "" else "S")
end
Strings.LOCKED = "LOCKED"
-- A heist on the shelf: "3  LIGHTS OUT\n30 SEC RUNS\nSTARS 2/3".
function Strings.heistCard(index: number, name: string, tag: string, status: string): string
	return string.format("%d  %s\n%s\n%s", index, string.upper(name), tag, status)
end
-- Medal count on a heist card: "STARS 2/3".
function Strings.heistStars(n: number): string
	return string.format("STARS %d/3", math.min(n, 3))
end
function Strings.clearFirst(name: string): string
	return "Clear " .. name .. " first."
end
function Strings.starsToOpen(n: number): string
	return string.format("%d more star%s to open it.", n, s(n))
end
Strings.HEIST_LOCKED = "That heist is locked."
function Strings.advent(day: number): string
	return "DEC " .. tostring(day)
end
function Strings.catchUpCard(when: string, name: string): string
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
-- A crew row: "P1 Ana (leader)" (the seat number, in the seat's colour).
function Strings.crewMember(seat: number, name: string, leader: boolean): string
	return string.format("P%d %s", seat, name) .. (if leader then " (leader)" else "")
end
Strings.JOIN_NEXT_HEIST = "You join at their next heist."
Strings.LEAVE_CREW = "LEAVE CREW"
function Strings.join(name: string): string
	return "JOIN " .. name
end

---------------------------------------------------------------------------
-- During a run: toasts, reason lines, stamps
---------------------------------------------------------------------------
Strings.LAST_RUN_BEFORE_SUNRISE = "Last run before sunrise!"
function Strings.sunriseAfter(runs: number): string
	return string.format("Sunrise after %d more run%s", runs, s(runs))
end
Strings.GUS_RAISED_ALARM = "Gus raised the alarm."
function Strings.cloneSetOffAlarm(cloneName: string): string
	return cloneName .. " set off the alarm."
end
Strings.YOU_SET_OFF_ALARM = "You set off the alarm."
Strings.LOCKED_WAIT = "Locked. Wait for the timer."
function Strings.lockedOpensIn(clock: string): string
	return "Locked: opens in " .. clock
end
-- Why your run ended (§6.1 item 8): it stays up until the deck opens, then leads the
-- deck title (with no deck it stays on the rail until the next run).
Strings.TIME_UP = "Time's up! Your clone stops there."
Strings.CAUGHT_BY_GUS = "Gus caught you."
Strings.ZAPPED_BY_LASER = "Zapped by a laser."
Strings.WAIT_FOR_CREW = "Wait for your crew"
-- Sound captions (Shared/Audio/Cues) that a reason line already says: not shown twice.
Strings.CAPTION_CAUGHT = "[Guard spotted you]"
Strings.CAPTION_ZAPPED = "[Zapped]"
-- A bank toast: "Clone 3 +$100" for a clone, "+$100" for a player.
function Strings.banked(who: string?, money: string): string
	return (if who then who .. " " else "") .. "+" .. money
end
Strings.CREW_WAITING = "Crew is waiting"
Strings.GOAL_BANKED = "You got it! Tap REWIND to finish, or grab more."
Strings.TILL_ALARM = "Till alarm: everyone to the van!"
function Strings.cloneSetOffAlarmNow(cloneName: string): string
	return cloneName .. " set off the alarm!"
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
Strings.STAMP_DAWN = "DAWN"
Strings.STAMP_HEIST_COMPLETE = "HEIST COMPLETE"
function Strings.stampTier(n: number): string
	return string.format("STAR %d!", n)
end

-- Objective lines (≤ 8 words, MASTERPLAN §7.4; L1 FTUE §7.5)
Strings.OBJ_STAY_ON_PLATE = "Stay on it. Tap REWIND."
Strings.OBJ_STEP_ON_PLATE = "Step on the plate"
Strings.OBJ_CLONE_STOPS = "Your clone stops where you stop."
Strings.OBJ_WAIT_FOR_CLONE = "Wait for your clone to open the door"
Strings.OBJ_BANK_IT = "Bank it at the van"
Strings.OBJ_GRAB_CASH = "Grab the cash"
Strings.OBJ_GRAB_LOOT = "Grab the loot"
-- Level lines for the first seconds of run 1, and again when stuck, by LevelSpec id.
Strings.LEVEL_LINES = table.freeze({
	cs2_two_doors = "Two plates. You need two clones.",
	cs5_clone_party = "Rob it all. Bank it before sunrise.",
	cs3_lights_out = "Plate B turns the lasers off.",
	cs4_night_clerk = "Hide from Gus. Cross while he looks away.",
	bk1_big_score = "The vault. Every clone counts.",
} :: { [string]: string })

---------------------------------------------------------------------------
-- Rewind, Line-up, Gus, clone labels
---------------------------------------------------------------------------
Strings.REWIND_BANNER = "REWIND"
Strings.SKIP = "SKIP"
Strings.ME = "ME"
Strings.YOU = "YOU"
-- Gus's head label by vision stage.
Strings.GUS_SPOTTED = "!"
Strings.GUS_HUH = "huh?"
Strings.GUS_SUSPICIOUS = "?"
Strings.GUS_ZZ = "zz" -- dozing (L5's back office)
-- The nameplate the first time Gus is on screen (PLAN A5).
Strings.GUS_NAME = "GUS"
-- "20 SEC AGO" / "1 MIN AGO" (LineupPlan.agoRound gives the number, CLIPS §1.2).
function Strings.ago(n: number, minutes: boolean): string
	return string.format(if minutes then "%d MIN AGO" else "%d SEC AGO", n)
end
-- The burned-in clone label: "ME, 20 SEC AGO" (hueHex colours the name, RichText).
function Strings.agoLabel(who: string, ago: string, hueHex: string): string
	return string.format('<font color="#%s">%s</font>, %s', hueHex, who, ago)
end

return table.freeze(Strings)
