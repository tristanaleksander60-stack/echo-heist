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
-- First person (Hud/Reticle's prompt chip): the verb of what you look at, and the key cap beside it.
Strings.FP_VERB = table.freeze({ grab = "GRAB", open = "OPEN", press = "PRESS", bank = "BANK" } :: { [string]: string })
-- The van while you carry: banking is walking in (no key, no button).
Strings.FP_BANK = "WALK IN TO BANK"
-- The chip's key cap by device: E on a keyboard (a left click works too), X on a gamepad, TAP on touch (the
-- GRAB button below is the tap target there).
Strings.KEY_E = "E"
Strings.KEY_PAD = "X"
Strings.KEY_TAP = "TAP"
-- Key caps on the buttons (Shared/Heist/KeyHints, Hud/Common.keyCap), by Enum.KeyCode name: the gamepad's buttons
-- as text labels (ASCII: tests/glyph_check.luau). A key not listed shows its KeyCode name.
Strings.KEY_LABEL = table.freeze({
	LeftControl = "Ctrl",
	RightControl = "Ctrl",
	LeftShift = "Shift",
	RightShift = "Shift",
	Backspace = "Bksp",
	Return = "Enter",
	Space = "Space",
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonStart = "Menu",
} :: { [string]: string })
Strings.KEY_JOIN = "+" -- a chord: "Ctrl+Shift", "B+LB"
-- The slide's touch button (Hud/Slide; Ctrl / B on keys and pads)
Strings.SLIDE = "SLIDE"
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
-- BIG buildings (server Heist/TowerPlan): the sign on each location's building (glowing SurfaceGui text).
Strings.BIG_SIGN = table.freeze({
	CornerShop = "CORNER SHOP",
	ToyShop = "HOARDSWORTH'S TOYS",
	Bank = "HOARDSWORTH BANK",
} :: { [string]: string })
-- The warehouse garage's crew sign (server Heist/LobbyPlan, anchor CrewSign).
Strings.GARAGE_CREW_SIGN = "LOOKING FOR CREW"
Strings.GARAGE_LAPTOP = "DAILY VAULT" -- the laptop's screen (anchor LaptopSpot)
Strings.GARAGE_TV = "HEIST YOURSELF" -- the TV under the mezzanine (anchor TVSpot: the intro rewatch)
Strings.JOB_BOARD_NEXT = "NEXT JOB"
Strings.JOB_BOARD_ALL_DONE = "ANY JOB!"
-- The hideout lobby (LOBBY track, Config.Hideout): the prompt chip's words for each look target (Shared/Heist/
-- LobbyLook verbs), the van plates and seat cards, the lobby toasts and the first-visit hint.
Strings.LOBBY_VERB = table.freeze({
	jobs = "JOB BOARD",
	laptop = "DAILY VAULT",
	wardrobe = "WARDROBE",
	tv = "WATCH INTRO",
	invite = "INVITE FRIENDS",
	quickCrew = "QUICK CREW",
	pick = "PICK VAN",
	leaderPicks = "LEADER PICKS",
	solo = "SOLO · GO",
	go = "GO!",
	wait = "WAITING",
	crew = "CREW · OPEN UP",
	park = "CLOSE UP",
	paint = "PAINT",
	style = "STYLE",
	sit = "SIT",
	ready = "READY",
	unready = "NOT READY",
	taken = "TAKEN",
	busy = "ON A JOB",
	party = "YOUR VAN",
} :: { [string]: string })
function Strings.lobbyWaiting(n: number): string
	return string.format("WAITING · %d", n)
end
function Strings.lobbyPaint(name: string): string
	return "PAINT · " .. name
end
function Strings.lobbyStyle(name: string): string
	return "STYLE · " .. name
end
function Strings.vanPlate(name: string): string
	return string.upper(name) .. "'S CREW"
end
Strings.VAN_FREE = "FREE VAN"
Strings.VAN_AWAY = "ON A JOB"
Strings.SEAT_FREE = "FREE SEAT"
Strings.SEAT_READY = "READY"
Strings.SEAT_OUT = "STEPPED OUT"
Strings.PICK_A_VAN = "PICK A VAN"
Strings.LOBBY_BACK = "BACK"
Strings.LOBBY_SKIP = "SKIP"
Strings.LOBBY_USE = "USE"
Strings.LOBBY_GET_OUT = "JUMP TO GET OUT"
Strings.WARDROBE = "WARDROBE"
Strings.LAPTOP = "LAPTOP · DAILY VAULT"
Strings.LAPTOP_NO_CATCH_UP = "No missed vaults. Nice work!"
Strings.WARDROBE_SLOT = table.freeze({
	cap = "CAP",
	scarf = "SCARF",
	sweater = "SWEATER",
	gloves = "GLOVES",
	mask = "MASK",
	tone = "KNIT COLOUR",
} :: { [string]: string })
Strings.WEARING = "WEARING"
Strings.WARDROBE_RANDOM = "RANDOM"
function Strings.unlockStars(n: number): string
	return if n == 1 then "1 STAR" else string.format("%d STARS", n)
end
function Strings.unlockTrophy(name: string): string
	return "CLEAR " .. string.upper(name)
end
Strings.WARDROBE_LOCKED = "Locked: earn it on a heist."
Strings.WARDROBE_SAVE_FAILED = "Could not change that right now."
Strings.JOB_PINNED_PICK = "Job picked! Now PICK A VAN."
function Strings.jobPinned(name: string): string
	return "Job picked: " .. name .. ". Go to your van!"
end
Strings.INVITE_NONE = "Invites are not open here."
-- Quick Crew (LOBBY 2, Config.Hideout.QUICK): the crew sign's sheet, the lobby chip, the toasts. No free text.
Strings.QUICK_CREW = "QUICK CREW"
Strings.QUICK_LOOK = "LOOK FOR A CREW"
Strings.QUICK_STOP = "STOP LOOKING"
Strings.QUICK_OPEN = "OPEN MY VAN"
Strings.QUICK_SHUT = "CLOSE MY VAN"
Strings.QUICK_INVITE = "INVITE FRIENDS"
Strings.QUICK_INFO = "Play with other players in this server. No chat needed: crews talk with pings."
Strings.QUICK_INFO_LEADER = "Open your van and players looking for a crew will join you."
Strings.QUICK_NEED_SOLO = "Leave your crew to look for a new one."
Strings.QUICK_SEEKING = "LOOKING FOR CREW"
Strings.QUICK_MATCHED = "FOLLOW THE ARROW"
Strings.QUICK_YOUR_VAN = "YOUR CREW"
Strings.QUICK_OPEN_PLATE = "OPEN"
function Strings.quickStatus(waiting: number, open: number): string
	return string.format("%d looking%s%d open van%s", waiting, " · ", open, if open == 1 then "" else "s")
end
Strings.QUICK_TOAST = table.freeze({
	looking = "Looking for a crew... we'll find you a van.",
	stopped = "You stopped looking for a crew.",
	matched = "A crew has a seat for you! Follow the arrow.",
	coming = "A Quick Crew player is on the way!",
	lapsed = "Your seat was given away. Still looking...",
	away = "Stopped looking: you missed your seat.",
	opened = "Your van is open to Quick Crew.",
	shut = "Your van is closed to Quick Crew.",
	joined = "Welcome to the crew!",
	paused = "Quick Crew is paused right now.",
	gone = "That van left. Still looking...",
} :: { [string]: string })
-- Why the server said no to a lobby action (VanRules codes).
Strings.LOBBY_REFUSED = table.freeze({
	Taken = "That van is taken.",
	TooFar = "Get closer to the van.",
	NotLeader = "Your crew leader picks the van.",
	NotFriend = "Only friends of that crew can sit in.",
	Full = "That van is full.",
	Waiting = "Wait for everyone to be READY.",
	NotSolo = "Your crew is with you: open the side door.",
	Closed = "That van's door is shut.",
	Busy = "That van is busy.",
	HasCrew = "Your crew is still inside.",
	Seats = "Too many for one van.",
	NoVan = "Pick a van first.",
	NotMatched = "Find a seat at the crew sign: LOOK FOR A CREW.",
	NeedSolo = "Leave your crew to look for a new one.",
	Hosting = "Close your van to Quick Crew first.",
	FarSign = "Go to the crew sign.",
	Slow = "One moment...",
	BadStyle = "That style is not here.",
	BadSize = "Pick a crew of 2 to 4.",
	BelowTaken = "More are in your crew than that.",
	BadPrivacy = "Pick who can join.",
	Kicked = "That crew left you out for now.",
	NotInvited = "That crew is invite only.",
	NoSeat = "Nobody sits there.",
} :: { [string]: string })
-- The PARTY sheet (PARTY track, Config.Hideout.PARTY; Hud/Party): the leader's one menu for their van, and the
-- read-only card everyone else sees at a claimed van. No free text.
Strings.PARTY_TITLE = "YOUR VAN"
Strings.PARTY_CREW = "CREW"
Strings.PARTY_SOLO = "SOLO"
Strings.PARTY_JOIN = "JOIN"
Strings.PARTY_READY_CHECK = "READY CHECK"
Strings.PARTY_PRIVACY = table.freeze({
	friends = "FRIENDS ONLY",
	open = "OPEN",
	invite = "INVITE ONLY",
} :: { [string]: string })
Strings.PARTY_PRIVACY_INFO = table.freeze({
	friends = "Your friends can walk in and SIT.",
	open = "Friends, and players looking for a crew (Quick Crew), can join.",
	invite = "Only friends you invited (or who joined you) can SIT.",
} :: { [string]: string })
Strings.PARTY_SOLO_INFO = "Just you. GO from the driver's seat."
Strings.PARTY_SEAT = table.freeze({
	driver = "DRIVER",
	ready = "READY",
	seated = "SEATED",
	out = "STEPPED OUT",
	held = "ON THE WAY",
	free = "FREE SEAT",
	closed = "",
} :: { [string]: string })
Strings.PARTY_KICK = "KICK"
Strings.PARTY_INVITE = "INVITE"
Strings.PARTY_PAINT = "PAINT"
Strings.PARTY_STYLE = "STYLE"
Strings.PARTY_GO = "GO!"
Strings.PARTY_SOLO_GO = "SOLO · GO"
function Strings.partyWait(n: number): string
	return string.format("WAITING · %d", n)
end
-- A key hint on a button ("GO!  [ENTER]"). Kept in one place so the shared key-hint helper can replace it.
function Strings.partyKey(text: string, key: string?): string
	if key == nil or key == "" then
		return text
	end
	return text .. "  [" .. key .. "]"
end
Strings.KEY_ENTER = "ENTER"
Strings.KEY_ESC = "ESC"
Strings.KEY_PAD_BACK = "B"
Strings.KEY_PAD_GO = "Y"
function Strings.partyCardTitle(name: string): string
	return string.upper(name) .. "'S VAN"
end
function Strings.partySeats(seated: number, cap: number): string
	return string.format("SEATS %d / %d", seated, cap)
end
Strings.PARTY_CARD_WHY = table.freeze({
	Closed = "Door shut: going solo.",
	Full = "Full.",
	NotFriend = "Friends of the leader only.",
	NotMatched = "Open to Quick Crew: use the crew sign.",
	Seated = "You are in this crew.",
	Busy = "On a job.",
} :: { [string]: string })
Strings.PARTY_KICKED = "You were left out of that crew. You are on your own again."
function Strings.partyKickedLeader(name: string): string
	return name .. " is out of your van."
end
-- The laptop's board (LOBBY 2): today's biggest haul on this server, the top 10 and your row.
Strings.BOARD_TITLE = "TODAY'S BIGGEST HAUL"
Strings.BOARD_EMPTY = "No hauls yet today. Be the first!"
Strings.BOARD_YOU = "YOU"
Strings.BOARD_NOT_ON = "Clear today's vault to get on the board."
Strings.BOARD_OFF = "The board is resting right now."
Strings.BOARD_TAB = "BOARD"
function Strings.boardRank(rank: number): string
	return "#" .. tostring(rank)
end
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
-- P2-1: the L1 intro fits 30 words, its longest device line counted (tests/unit/HeistHelp.spec.luau). In first
-- person the clone walks out of your own body, so the line does not say "watch": the look cue (Hud/Hints)
-- points at it whenever it is off screen.
Strings.OBJ_WAIT_FOR_CLONE = "Your clone opens the door!"
Strings.OBJ_BANK_IT = "Back to the van!"
Strings.OBJ_GRAB_CASH = "Grab the cash"
Strings.OBJ_GRAB_LOOT = "Grab the loot"

-- First person (the default camera, PLAN_FIRST_PERSON wave C): a line that names a button names the one this
-- device presses. In first person on a keyboard the cursor is locked, so REWIND is a key (R) and GRAB is "look
-- at it, press E" (or a left click); a gamepad has Y and X; touch keeps its buttons. Keyed by device
-- ("key" | "pad" | "touch"); Strings.forDevice picks one, other cameras keep the plain line.
Strings.OBJ_STAY_ON_PLATE_BY = table.freeze({
	key = "Stay. Press R to REWIND.",
	pad = "Stay. Press Y to REWIND.",
	touch = "Stay on it. Tap REWIND.",
} :: { [string]: string })
Strings.OBJ_GRAB_CASH_BY = table.freeze({
	key = "Look at the cash. Press E.",
	pad = "Look at the cash. Press X.",
	touch = "Look at the cash. Tap GRAB.",
} :: { [string]: string })
Strings.OBJ_GRAB_LOOT_BY = table.freeze({
	key = "Look at the loot. Press E.",
	pad = "Look at the loot. Press X.",
	touch = "Look at the loot. Tap GRAB.",
} :: { [string]: string })
Strings.OBJ_STAY_TAP_REWIND_BY = table.freeze({
	key = "Stay here. Press R to REWIND.",
	pad = "Stay here. Press Y to REWIND.",
	touch = "Stay here. Tap REWIND.",
} :: { [string]: string })
Strings.GOAL_BANKED_BY = table.freeze({
	key = "You got it! R to REWIND, or grab more.",
	pad = "You got it! Y to REWIND, or grab more.",
	touch = "You got it! Tap REWIND to finish, or grab more.",
} :: { [string]: string })
Strings.FAIL_TIMEOUT_BY = table.freeze({
	key = "Press R to REWIND when you're done.",
	pad = "Press Y to REWIND when you're done.",
	touch = "Tap REWIND when you're done.",
} :: { [string]: string })
-- Crew View (first person, Hud/CrewView): the touch button, the label over the lifted view and the one-time hint
-- (the first run with 2+ clones).
Strings.CREW = "CREW"
Strings.CREW_VIEW = "CREW VIEW"
Strings.CREW_VIEW_HINT = "Hold Q to see your crew."
Strings.CREW_VIEW_HINT_BY = table.freeze({
	key = "Hold Q to see your crew.",
	pad = "Hold LB to see your crew.",
	touch = "Tap and hold CREW to see your crew.",
} :: { [string]: string })
-- The plain line `key` (a Strings key) for a device in first person; other cameras get the plain line.
function Strings.forDevice(key: string, device: string, firstPerson: boolean): string
	local plain = (Strings :: any)[key]
	if firstPerson then
		local by = (Strings :: any)[key .. "_BY"]
		local line = type(by) == "table" and by[device]
		if type(line) == "string" then
			return line
		end
	end
	return if type(plain) == "string" then plain else ""
end
-- The look cue (Hud/Hints, first person): a finger at the screen edge toward your clone or the chalk ghost
-- while it is out of view.
Strings.LOOK_CUE = table.freeze({ clone = "YOUR CLONE", ghost = "LOOK" } :: { [string]: string })
---------------------------------------------------------------------------
-- The run coach (Shared/Heist/RunCoach, Hud/Coach; RUN2 CLARITY track): the coached levels (L1, L2) say one
-- thing to do at a time, computed from the level and what your clones hold. Every line is 6 words or fewer;
-- L1's (the mandatory tutorial) 4 or fewer (tests/unit/HeistRunCoach.spec.luau counts them, device lines too).
---------------------------------------------------------------------------
Strings.COACH = table.freeze({
	-- Your own next move (the world arrow points at its target).
	STEP_ON_PLATE = "Step on the plate", -- L1 (one plate)
	STAY_REWIND = "Tap REWIND now", -- on the plate your next clone must hold (plain: touch / classic camera)
	GO_DOOR = "YOU: through the door!", -- every plate is held: you walk in
	GO_DOORS = "YOU: through the doors!",
	BANK = "Back to the van!",
	-- The run-start beat (the camera on your newest clone, "YOU, 10 SEC AGO" over it).
	CLONE_HOLDS = "Clone holds the plate!", -- L1
	RUN_MISSED = "That run missed the plate.", -- the run before ended off every plate (L1)
	RUN_MISSED_PLATES = "That run missed the plates.", -- (L2: more plates)
} :: { [string]: string })
-- On the plate: the REWIND key for this device in first person (Strings.coachLine picks one).
Strings.COACH_STAY_REWIND_BY = table.freeze({
	key = "Now press R",
	pad = "Now press Y",
	touch = "Tap REWIND now",
} :: { [string]: string })
-- Grab the goal: "Grab the cash!" (a camera with the GRAB button), "Grab it: press E" (first person).
Strings.COACH_GRAB_BY = table.freeze({
	key = "Grab it: press E",
	pad = "Grab it: press X",
	touch = "Tap GRAB on it!",
} :: { [string]: string })
-- What a goal loot is called in a line, by loot id (anything else: "loot").
Strings.COACH_LOOT_NAMES = table.freeze({ Cash = "cash", Safe = "safe" } :: { [string]: string })
function Strings.coachGrab(lootId: string?): string
	local name = lootId and Strings.COACH_LOOT_NAMES[lootId] or "loot"
	return "Grab the " .. name .. "!"
end
-- More than one plate (L2): "Stand on plate A. Then REWIND."
function Strings.coachStandPlate(plate: string): string
	return "Stand on plate " .. plate .. ". Then REWIND."
end
-- The beat on a level with more plates: "Clone holds plate A!" / "Plate A already has one."
function Strings.coachCloneHolds(plate: string): string
	return "Clone holds plate " .. plate .. "!"
end
function Strings.coachAlreadyHeld(plate: string): string
	return "Plate " .. plate .. " already has one."
end
-- A coach line (RunCoach.Line = {key, plate?, loot?}) for a device; `firstPerson` picks the device's key wording.
function Strings.coachLine(line: any, device: string, firstPerson: boolean): string
	local key = line and line.key
	if key == "STAND_PLATE" then
		return Strings.coachStandPlate(tostring(line.plate))
	elseif key == "CLONE_HOLDS_PLATE" then
		return Strings.coachCloneHolds(tostring(line.plate))
	elseif key == "ALREADY_HELD" then
		return Strings.coachAlreadyHeld(tostring(line.plate))
	elseif key == "STAY_REWIND" then
		return if firstPerson or device == "touch"
			then Strings.COACH_STAY_REWIND_BY[device] or Strings.COACH.STAY_REWIND
			else Strings.COACH.STAY_REWIND
	elseif key == "GRAB" then
		return if firstPerson
			then Strings.COACH_GRAB_BY[device] or Strings.coachGrab(line.loot)
			else Strings.coachGrab(line.loot)
	end
	return if type(key) == "string" then Strings.COACH[key] or "" else ""
end

-- Level lines for the first seconds of run 1, and again when stuck, by LevelSpec id. (The coached levels, L1 and
-- L2, show the coach's staged plan instead on run 1: "Stand on plate A. Then REWIND.")
Strings.LEVEL_LINES = table.freeze({
	cs2_two_doors = "Clones on both plates. Then go!",
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
-- The story intro's caption cards (Heist/Cinematic, Shared/Heist/IntroPlan; docs/art/intro/STORYBOARD.md):
-- six words at most each (Config.Intro.CAPTION.WORDS_MAX, unit-tested), readable with the sound off.
Strings.INTRO = table.freeze({
	EVE = "CHRISTMAS EVE.",
	HOARD = "SIR HOARDSWORTH WANTS IT ALL.",
	MINE = "MINE. ALL MINE.",
	EVERY = "EVERY PRESENT IN TOWN...",
	GONE = "...GONE.",
	ONE = "ONE ROBBER. ONE NIGHT.",
	MORE = "IT'LL TAKE MORE OF ME.",
	TITLE = "HEIST YOURSELF",
} :: { [string]: string })
Strings.INTRO_SKIP_HINT = "ANY KEY"
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

---------------------------------------------------------------------------
-- Badges (BADGES track; Heist/BadgeView): the BADGE UNLOCKED card and the boss's marks. Badge names and
-- descriptions live in Shared/Heist/Badges (they are the Roblox badge's own text).
---------------------------------------------------------------------------
Strings.BADGE_UNLOCKED = "BADGE UNLOCKED"
-- "3 OF 8 BADGES" under the badge name
function Strings.badgeCount(n: number, total: number): string
	return string.format("%d OF %d BADGES", n, total)
end
Strings.BOSS_HERE = "THE BOSS IS HERE!" -- the message rail, on every screen, when the owner joins
Strings.BOSS_PILL = "THE BOSS" -- the gold pill over the owner's Rookie

return table.freeze(Strings)
