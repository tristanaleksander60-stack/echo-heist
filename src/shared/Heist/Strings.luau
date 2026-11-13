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
-- The brand (MASTERPLAN §2.2) and the loading card's quiet progress hint, one line per real stage
-- (never a bare "Loading"). ReplicatedFirst/Brand draws the first frame with copies of these
-- (tests/unit/HeistPresent.spec.luau keeps them equal); the HUD's wait card uses LOADING_HINTS.server.
Strings.WORDMARK = "HEIST YOURSELF"
Strings.WORDMARK_STRAP = "Rob With Your Clones"
Strings.LOADING_HINTS = table.freeze({
	boot = "Packing the van",
	client = "Waking up the crew",
	server = "Finding your van",
})
-- Settings (U7): the panel from MENU and the garage. Labels by Schema settings key.
Strings.SETTINGS_TITLE = "SETTINGS"
Strings.DONE = "DONE"
Strings.ON = "ON"
Strings.OFF = "OFF"
Strings.SETTING_LABEL = table.freeze({
	musicVolume = "Music",
	sfxVolume = "Sound effects",
	shake = "Camera shake",
	reducedMotion = "Reduced motion",
	captions = "Captions",
	colourBlindGlyphs = "Colour-blind",
	cameraMode = "Camera",
	fpFov = "Field of view",
	guardPath = "Show guard path",
	haptics = "Vibration",
} :: { [string]: string })
Strings.SETTING_CAMERA =
	table.freeze({ fp = "FIRST PERSON", diorama = "DIORAMA", classic = "CLASSIC" } :: { [string]: string })
-- The first-person field of view on its slider (degrees, a bare number: "70").
function Strings.fovValue(v: number): string
	return string.format("%d", math.floor(v + 0.5))
end
function Strings.percent(v: number): string
	return string.format("%d%%", math.floor(v * 100 + 0.5))
end
-- The bank moment: "+$100!" flies from the van to the loot meter.
function Strings.bankFly(money: string): string
	return "+" .. money .. "!"
end

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

-- Crew cards (U4, PLAN_STEAM_PLUS §3.2; WALKTHROUGH P0-3): a full deck says so, names the clone a new
-- run replaced, and offers a one-tap start over after runs that got nowhere.
Strings.DECK_FULL = "DECK FULL: tap a clone, then DELETE"
function Strings.deckFullReplaced(slot: number): string
	return string.format("Deck full: your new clone replaced clone %d", slot)
end
Strings.START_OVER = "START OVER"
-- A card's caption: what that clone did last (Shared/Heist/CrewBoard.lastAction).
function Strings.cardPlate(letter: string): string
	return "PLATE " .. letter
end
Strings.CARD_ACTION = table.freeze({
	cash = "CASH",
	busted = "BUSTED",
	zapped = "ZAPPED",
	stuck = "STUCK",
	walk = "WALKS",
})

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
-- The job sheet (U5): one line per goal (struck through in pencil when met), and the first time a star
-- can be earned its stamp says why (WALKTHROUGH S7), with the level's real numbers.
Strings.JOB_SHEET = "JOB SHEET"
function Strings.jobSheet(name: string): string
	return "JOB SHEET · " .. string.upper(name)
end
function Strings.lineHaul(have: string, goal: string): string
	return string.format("%s of %s stolen", have, goal)
end
function Strings.lineCrew(clones: number): string
	return plural(clones, "clone") .. " used"
end
Strings.LINE_CLEAN = "Never caught"
Strings.LINE_CAUGHT = "Got caught"
function Strings.lineTier(tier: number, money: string): string
	return string.format("STAR %d: bank %s", tier, money)
end
function Strings.reasonHaul(goal: string): string
	return "HAUL: " .. goal .. " stolen"
end
function Strings.reasonCrew(par: number): string
	return string.format("CREW: %s or fewer", plural(par, "clone"))
end
Strings.REASON_CLEAN = "CLEAN: never caught"
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
-- The 3D job board at your van (garage v1, Heist/Lobby + client Heist/JobBoard): the NEXT card.
Strings.JOB_BOARD_NEXT = "NEXT JOB"
Strings.JOB_BOARD_ALL_DONE = "ANY JOB!"
-- The job board (U6, level select): pinned job photos; the NEXT one glows (Strings.JOB_BOARD_NEXT).
Strings.JOB_BOARD = "JOB BOARD"
function Strings.jobPhoto(index: number, name: string): string
	return string.format("%d  %s", index, string.upper(name))
end
Strings.SETTINGS = "SETTINGS"
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
Strings.OBJ_WAIT_FOR_CLONE = "Watch your clone open the door." -- P2-1: the L1 intro fits 30 words
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
	-- Daily vaults (open after Night Clerk; WALKTHROUGH P1-7: each has its own goal line)
	dv01_stocking_stuffer = "One plate holds the door. Make a clone.",
	dv02_twin_chimneys = "Both plates at once open the door.",
	dv03_candy_cane_lasers = "Hold the plate. The lasers switch off.",
	dv04_mistletoe_patrol = "Hold the door. Sneak past Gus.",
	dv05_tinsel_corridor = "Two doors. Plate A first, then plate B.",
	dv06_snow_day_switch = "A clone rings the bell. You run in.",
	dv07_ornament_scale = "Three plates at once open the vault.",
	dv08_frosty_window = "Lasers off first, then the pantry door.",
	dv09_sleigh_bell_alarm = "Grab the bell, then run to the van!",
	dv10_gingerbread_lobby = "Hold two plates. Cross while Gus looks away.",
	dv11_jingle_vault = "The vault needs both plates at once.",
	dv12_night_before = "Every plate does two jobs. Watch Gus.",
} :: { [string]: string })

---------------------------------------------------------------------------
-- Onboarding and help (Hud/Hints, Shared/Heist/Help; PLAN_STEAM_PLUS §5, §6, premium G2/G4)
---------------------------------------------------------------------------
-- World-state lines from L2 on (WALKTHROUGH P0-4), picked by Help.worldLine.
Strings.OBJ_STAY_TAP_REWIND = "Stay here. Tap REWIND."
Strings.OBJ_NEXT_PLATE = "Find the next plate. Make a clone."
Strings.OBJ_CLONES_OPEN_WAY = "Your clones open the way. Grab it!"
-- Stuck help (P0-2): the chip, the chalk ghost's line, the Relaxed card.
Strings.SHOW_ME = "SHOW ME?"
Strings.OBJ_WATCH_GHOST = "Watch, then copy."
function Strings.ghostRedo(slot: number): string
	return string.format("Redo clone %d like this.", slot)
end
Strings.DECK_FULL_HELP = "Deck full. DELETE a clone you don't need."
Strings.TRY_RELAXED = "TRY RELAXED?"
Strings.RELAXED_SUB = "Slower Gus, longer runs"
-- First-time beats (premium G2): the bigger first version of each moment.
Strings.FIRST_PLATE = "Stay on it."
Strings.FIRST_CLONE = "That's you. It copies you."
function Strings.firstBank(money: string): string
	return "+" .. money .. "!"
end
-- The Party's first entry: Gus dozes in the back office (PLAN §5, §6.1 item 2).
Strings.GUS_INTRO = "That's Gus. Don't wake him."
-- Endings by Dawn: the party's is a celebration, a story level's is a failure with a tip.
Strings.STAMP_SUNRISE = "SUNRISE!"
Strings.SUNRISE_COUNT = "SUNRISE! Count the loot."
Strings.STAMP_OUT_OF_TIME = "OUT OF TIME"
Strings.STAMP_DOORS_LOCKED = "TOO LATE"
-- Every failure says why and what to try (premium G4): one line of counterplay per cause
-- (Shared/Heist/Help.CAUSE), a level's own line where it has one (Help.advice).
Strings.FAIL_ADVICE = table.freeze({
	Caught = "Wait till Gus looks away.",
	Zapped = "A clone on a plate stops the lasers.",
	Timeout = "Tap REWIND when you're done.",
	Alarm = "When it rings, run to the van!",
	Dawn = "Try: make every clone count.",
} :: { [string]: string })
Strings.FAIL_ADVICE_LEVEL = table.freeze({
	cs3_lights_out = table.freeze({ Zapped = "Hold plate B. The lasers switch off." }),
	cs4_night_clerk = table.freeze({
		Caught = "Hide under the coat rack. Then cross.",
		Dawn = "Try: hide under the coat rack.",
	}),
	bk1_big_score = table.freeze({ Caught = "Cross the hall while Gus looks away." }),
} :: { [string]: { [string]: string } })
-- The garage's daily vault card before Night Clerk is cleared (PLAN D4).
function Strings.dailyLockedClear(name: string): string
	return Strings.DAILY_VAULT .. Strings.SEP .. "Clear " .. name
end
function Strings.dailyLockedToast(name: string): string
	return "Clear " .. name .. " to open the daily vault."
end

---------------------------------------------------------------------------
-- Rewind, Line-up, Gus, clone labels
---------------------------------------------------------------------------
Strings.REWIND_BANNER = "REWIND"
Strings.SKIP = "SKIP"
-- The blooper cut at heist end (MASTERPLAN §9.2 #2): the caption over the clone's failure replay.
Strings.BLOOPER_CAPTION = "MY CLONE BETRAYED ME"
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
