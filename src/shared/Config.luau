-- Echo Heist: all tunable numbers in one place.

local Config = {}

-- Which game runs: "v01" = the v0.1 prototype (default, the Nov 16 fun gate),
-- "sim" = the HeistSim path (src/server/Heist, src/client/Heist; Config.Heist below).
-- Both entry scripts (src/server/init.server.luau, src/client/init.client.luau) read it.
Config.GAME_MODE = "v01"

-- Loop
Config.LOOP_SECONDS = 60
Config.RECORD_HZ = 15
Config.MAX_ECHOES_PER_PLAYER = 4
Config.MAX_ECHOES_TOTAL = 16
Config.REWIND_COOLDOWN = 0.5 -- seconds between rewind votes from one player
Config.MIN_LOOP_SECONDS = 2 -- a loop must last at least this long before a rewind

-- Mechanisms
Config.PLATE_GRACE = 0.4 -- a door stays open this long after its plate is released
Config.INTERACT_RANGE = 10 -- max studs between an actor and a prompt it uses
Config.CAUGHT_IMMUNITY = 2 -- seconds a caught player cannot be caught again

-- Guard
Config.GUARD_SPEED = 9
Config.GUARD_VISION_RANGE = 34
Config.GUARD_VISION_HALF_ANGLE = 50 -- degrees
Config.GUARD_SCAN_HZ = 6

-- Heist
Config.LOOT = {
	{ id = "Gold1", kind = "Gold", value = 100 },
	{ id = "Gold2", kind = "Gold", value = 100 },
	{ id = "Gold3", kind = "Gold", value = 100 },
	{ id = "Gold4", kind = "Gold", value = 100 },
	{ id = "Gold5", kind = "Gold", value = 100 },
	{ id = "Diamond", kind = "Diamond", value = 500 },
}
Config.HEIST_RESET_DELAY = 8

-- Default R15 animation used to make echoes walk instead of glide.
Config.ECHO_WALK_ANIM = "rbxassetid://507777826"
Config.ECHO_WALK_SPEED_THRESHOLD = 2 -- studs/s

-- Recording layer (shared/Rec), MASTERPLAN §3.1, §8.3, §8.8, §8.10.
-- Not used by the v0.1 server yet (it still reads RECORD_HZ / LOOP_SECONDS above).
-- Format constants (1/16 stud grid, u8 yaw, centisecond event times) are part of
-- the versioned buffer format and live in Rec/Codec, not here.
Config.Rec = {
	HZ = 20, -- samples per second, taken inside the fixed-step sim tick
	LOOP_MAX_SECONDS = 90, -- hard ceiling for any run length
	END_RUN_LOCK_SECONDS = 1.5, -- END RUN is disabled this long at the start of a run
	SKIP_SPEED = 3, -- fast-forward clock rate
	WAIT_SQUEEZE_SECONDS = 10, -- co-op: others' timers jump to min(remaining, this)
	RELAXED_LENGTH_MULT = 1.5, -- Relaxed makes runs +50% longer (never a slower clock)
	MAX_CATCHUP_TICKS = 12, -- sim ticks run at most per Heartbeat after a hitch
	LAG_REWIND_CAP = 0.15, -- seconds: max latency rewind for a live player's hazard checks (§8.10)
	MAX_EVENTS = 255, -- recorded intent events per run (typical < 30)

	-- Validator (anti-exploit on recorded movement)
	WALK_SPEED = 16, -- default Humanoid.WalkSpeed when the caller passes none
	SPEED_MULT = 1.35, -- allowed horizontal speed = WalkSpeed x this
	SPEED_BUCKET_STUDS = 3, -- leaky-bucket slack for lag bursts, in studs
	PING_ALLOWANCE_CAP = 0.3, -- seconds of ping that widen the bucket (x max speed)
	JUMP_HEIGHT = 7.2, -- Humanoid.JumpHeight default; vertical rise allowed above the last ground
	RISE_MARGIN = 1, -- extra studs above the jump apex before a rise is a violation
	MAX_RISE_SPEED = 60, -- studs/s upward per sample (a default jump launches at ~53)
	MAX_VIOLATIONS_LOGGED = 32, -- violation records kept per run (all are counted)

	-- Size budget: ~5 KB per delta-coded 60 s run (§8.3), so ~85 bytes per second of run.
	BUDGET_BYTES_PER_SECOND = 85,
}

-- Deterministic heist simulation (shared/Sim), MASTERPLAN §3, §8.2-8.5, §8.10.
-- Not used by the v0.1 server yet (it still reads the v0.1 keys above). The tick
-- rate is Config.Rec.HZ: the sim samples recordings inside its own tick.
Config.Sim = {
	-- Crew and clone caps (§0 C3, §3.2 rule 7)
	CREW_CLONE_BUDGET = 12, -- clones per heist instance; per-player cap = min(level.cap, floor(this / crewSize))
	MAX_CREW = 4,
	MAX_LEVEL_CAP = 8, -- Clone Party, Big Scores and the finale grant 8

	-- Run lifecycle (§3.1)
	L1_AUTO_END_SECONDS = 2.0, -- tutorial: run 1 auto-ends after this long on the plate (§7.5)
	STANDING_EPS = 0.05, -- studs per tick under which a live player counts as standing (fast-forward)

	-- Mechanisms (§3.1, §6.7, §8.10)
	PLATE_GRACE = 0.4, -- a plate counts as held this long after release (draining cable)
	PLATE_TOLERANCE = 0.5, -- studs added around a plate's trigger box (sim/visual desync margin)
	DOOR_CLOSE_SECONDS = 0.35, -- a door slides shut this long and is solid only when fully shut
	VISUAL_LEAD = 0.2, -- doors and lasers look shut/on this long before the server makes them so
	LASER_FLICKER_SECONDS = 0.3, -- 3 flickers before a laser re-enables (ends VISUAL_LEAD before it is on)
	SIMUL_WINDOW = 1.0, -- two actions within this many seconds count as together
	INTERACT_RANGE = 6, -- studs (horizontal) from an actor's sim position to a target it uses
	INTERACT_HEIGHT = 6, -- studs (vertical) for the same check
	INTERACT_COOLDOWN = 0.25, -- seconds between intents from one actor
	MAX_QUEUED_INTENTS = 8, -- live intents held for the next tick (extra ones are dropped)

	-- Gus (§3.1, §3.6, §0 smaller calls)
	GUARD_SPEED = 8, -- patrol walk speed, studs/s
	GUARD_TURN_SECONDS = 0.5, -- at the end of a dwell Gus turns toward the next leg over this long
	GUARD_VISION_RANGE = 30, -- studs
	GUARD_VISION_HALF_ANGLE = 45, -- degrees
	GUARD_EYE_HEIGHT = 1.5, -- studs above the guard's root for line of sight
	TARGET_HEIGHT = 1.0, -- studs above an actor's root that Gus must see
	GUARD_ALERT_SECONDS = 0.6, -- "?" stage: Gus stops and turns toward the actor
	GUARD_CATCH_SECONDS = 1.2, -- "!" stage: caught (live) or busted (clone)
	GUARD_METER_DECAY = 1.0, -- detection seconds lost per second out of sight
	GUARD_HUH_SECONDS = 2.0, -- "huh?" freeze after busting a clone
	FIRST_HEIST_GRACE_MULT = 2, -- first heist of a new account: all stage times x this
	RELAXED_DETECT_MULT = 2, -- Relaxed: detection times x this
	RELAXED_OFFER_BUSTS = 3, -- after this many busts in one heist, Relaxed is offered
	HIDE_REVEAL_RADIUS = 3, -- a hidden actor is seen only within this many studs
	CREW_VISION_BONUS = 0.1, -- +10% vision range per extra crew member
	GUARD_CHASE_SPEED_MULT = 0.9, -- Alarm Run chase speed = this x Config.Rec.WALK_SPEED
	GUARD_CATCH_RADIUS = 2.5, -- studs: during a chase Gus catches on contact
	GUARD_CATCH_HEIGHT = 4, -- studs: max height difference for a contact catch
	GUARD_SUSPECT_TURN = 2 * math.pi, -- radians/s Gus turns toward a "?" suspect
	GUARD_POINT_BLANK = 0.5, -- studs: closer than this an actor is seen whatever the facing
	GUARD_SEARCH_TURN = math.pi / 2, -- radians/s Gus turns while searching a last-seen point
	LAG_POSE_TICKS = 4, -- guard poses kept for the lag rewind (>= LAG_REWIND_CAP x HZ + 1)

	-- Alarm Run (§3.6)
	ALARM_VAN_SECONDS = 20, -- "VAN LEAVES 0:20"
	ALARM_LOCK_SECONDS = 10, -- doors marked alarmLock close this long after the alarm

	-- Dawn (§0 C8, §3.1)
	DAWN_RUNS_OVER_PAR = 4,
	DAWN_MIN_RUNS = 6,

	-- Heavy loot (§8.5; format only at launch, the sim rejects grips until Dec 11)
	HEAVY_SPEED = 8,
	HEAVY_LEASH = 5,

	-- Level format limits (LevelSpec)
	LEVEL_EXTENT = 2048, -- studs from the level origin (Codec i16 at 1/16 stud)
	REACH_GRID = 1, -- studs per cell of the LevelSpec reachability flood fill
	ACTOR_RADIUS = 1, -- studs: solids are grown by this for the reachability check
	REACH_MAX_CELLS = 250000,

	-- Swarm moment and Crew Line-up hooks (§3.2 rule 8, §4.2 "8 OF ME", §7.5 funnel)
	SWARM_SEEN_CLONES = 6, -- own (or crew) clones in a run that log a Swarm event (funnel SwarmSeen)
	SWARM_OF_ME = 8, -- copies of you (clones + you) that earn the "8 OF ME" stamp
	SWARM_FANOUT_SECONDS = 1.5, -- the Swarm event waits for the tape-print fan-out (copies spread out)
	LINEUP_STAGGER = 0.06, -- seconds between figures of the victory pose, in record order
	LINEUP_ROW = 8, -- figures per Line-up row
	LINEUP_SPACING = 2.5, -- studs between figures and between rows
	LINEUP_STREET_GAP = 4, -- default row: this many studs on the street side of the van

	-- Clone Deck hints (between runs, view only)
	ALARM_HINT_SECONDS = 10, -- a clone that trips the alarm this early earns "Clone #N sets off the alarm: Redo #N?"
}

-- Level content rules shared by the authored levels (src/shared/Levels), MASTERPLAN
-- §3.1, §4.2, §4.3, §5.3. Per-level numbers (par, cap, goal, geometry) live in each
-- level's spec; these are the numbers every level of a kind shares.
Config.Levels = {
	-- Clone Party (L5, §4.2): 8 slots, Dawn at run 8, Haul tiers = Config.Data.Levels.CloneParty
	PARTY_CAP = 8,
	PARTY_DAWN_RUNS = 8,
	PARTY_RESPAWN_SECONDS = 3, -- a banked shelf item is back on its shelf this long after
	PARTY_REGISTER_RESPAWN = 600, -- the register (alarm) is robbed once per run (back next loop)
	PARTY_TILL_OPENS_SECONDS = 20, -- the till is time-locked until 0:20 of every run (robbing it is the last act)
	PARTY_SHUTTER_SECONDS = 6, -- the shutter drops this long after the till alarm (the getaway beat)

	-- Big Scores (L6, §4.2): 8 slots granted, Alarm Run, Dawn at par + DAWN_RUNS_OVER_PAR
	BIG_SCORE_CAP = 8,
	BANK_RUN_SECONDS = 45,

	-- Daily vaults (§5.3): one 30 s mini-vault per UTC day, fixed 5-clone loadout, Dawn at run 6
	DAILY_RUN_SECONDS = 30,
	DAILY_CAP = 5,
	DAILY_DAWN_RUNS = 6,
	DAILY_FIRST_DAY = { 2026, 12, 3 }, -- design 1 is the launch-day vault (advent order from here)

	-- Daily date-seeded modifiers (§5.3 "vetted set"); each vault lists the ones CI proves
	MOD_GUARD_FAST = 1.1, -- guard speed +10%
	MOD_GUARD_SLOW = 0.9, -- guard speed -10%
	MOD_LIGHTS_OFF_VISION = 0.75, -- lights off: guards see this much of their range
}

-- Sim game path (Config.GAME_MODE = "sim"): heist instances, replication, client view.
-- MASTERPLAN §3.3, §6.5, §7.1-7.5, §8.2, §8.6. Sim rules themselves stay in Config.Sim.
Config.Heist = {
	-- Instances (§3.3): one per party, each a copy of the level at its own offset.
	INSTANCE_SPACING = 3000, -- studs between instance origins along +X (lobby at the world origin)
	INSTANCE_Y = 0, -- floor height of every instance
	MAX_INSTANCES = 8, -- plan says 4 per 8-player server; 8 keeps solo always playable (owner decision)
	LOBBY_ORIGIN = { 0, 0, 0 },

	-- Run flow (§3.1, §7.1): { standard, quick, reduced motion } seconds; the server waits
	-- the chosen length before the run clock starts (control returns at its end).
	REWIND_TRANSITION = { 1.8, 1.0, 0.8 },
	QUICK_REWIND_FROM_RUN = 4, -- quick rewinds automatically from the 4th rewind (run 5 starts)
	FIRST_RUN_INTRO = 1.0, -- run 1: "RUN 1" stamp, teleport settles
	TUTORIAL_BETWEEN_SECONDS = 0.4, -- L1 (deck locked): the next run starts by itself
	BETWEEN_MAX_SECONDS = 25, -- between runs: the next run starts when all are ready, or after this
	RESULTS_SECONDS = 45, -- results card; then the crew goes back to the garage
	OFF_MAP_DROP = 25, -- studs below the floor: a fallen character is put back at its sim position

	-- Replication (§8.2, §8.6): state lives in attributes on the instance folder; events
	-- and recordings go over one reliable push. Guard pose attributes only while he is off
	-- his patrol (clients run Guards.patrol themselves otherwise).
	GUARD_POSE_HZ = 10,
	METER_STEP = 0.1, -- detection meter attribute resolution (seconds)

	-- FTUE (§7.5): a new account starts L1 straight away (no level select).
	FTUE_AUTOSTART = true,
	DATA_WAIT_SECONDS = 4, -- how long the garage waits for the profile before deciding

	-- Remote rate limits (roblox-secure-remotes: 1.5-2x the fastest legitimate use)
	RATE = {
		EndRun = { burst = 3, perSecond = 2 },
		Interact = { burst = 6, perSecond = 6 },
		Deck = { burst = 4, perSecond = 3 },
		Ready = { burst = 3, perSecond = 2 },
		FastForward = { burst = 6, perSecond = 4 },
		SelectLevel = { burst = 3, perSecond = 1 },
		JoinFriend = { burst = 2, perSecond = 0.5 },
		Leave = { burst = 2, perSecond = 1 },
		Sync = { burst = 3, perSecond = 1 },
	},

	-- Data keys (Config.Data.Levels) of the sim levels, by LevelSpec id.
	LEVEL_DATA_KEYS = {
		cs1_back_room = "BackRoom",
		cs2_two_doors = "TwoDoors",
		cs3_lights_out = "LightsOut",
		cs4_night_clerk = "NightClerk",
		cs5_clone_party = "CloneParty",
		bk1_big_score = "BigScoreBank",
	},

	-- Client view (§6.5, §7.3, §7.4)
	CLONE_AGE_DIM = 0.12, -- each older run of yours is this much dimmer
	OTHER_CLONE_BRIGHTNESS = 0.7, -- other players' clones on your screen
	CLONE_BADGE_DISTANCE = 40, -- the glyph badge hides beyond this many studs
	CLONE_SPAWN_STAGGER = 0.06, -- "tape print": clones form 60 ms apart in record order
	CLONE_LABEL_SECONDS = 1.0, -- "◀ YOU, 10 SEC AGO" on the newest clone
	CLONE_NEAR_FADE = 6, -- clones this close to the camera fade
	MAX_CLONE_ACCESSORIES = 2,
	WALK_ANIM_BASE_SPEED = 16, -- studs/s at which the walk clip plays at speed 1
	EVENT_BLEND = 0.15, -- server-decided clone changes blend in over this long
	DOOR_SLIDE_SECONDS = 0.35,
	PLATE_SINK = 0.15,
	CONE_RAYS = 12, -- Gus's vision cone fan
	CONE_HZ = 10,
	END_RUN_BUTTON = 72, -- px
	INTERACT_BUTTON = 72, -- px (>= 64)
	HINT_SECONDS = { 8, 16, 24 }, -- L1 stuck hints (§7.5)
	TIMER_PULSE_SECONDS = 10,
	TIMER_RED_SECONDS = 5,

	-- Sound placeholders (§7.1, §7.2): empty ids are skipped; paste licensed ids here.
	SOUNDS = {
		Clack = "",
		Stinger = "",
		Clunk = "",
		Arpeggio = "",
		KaChing = "",
		Busted = "",
		Zap = "",
		Heartbeat = "",
	},
}

-- Data layer (src/server/Data, src/shared/Data), MASTERPLAN §5 and §8.7; docs/DATA.md.
-- Display-safe: this module replicates, so it holds no secrets. The server reads its
-- own copy to decide every outcome. Dates are UTC calendar days { year, month, day }.
-- Level medal numbers are placeholders until the level layouts (src/shared/Levels)
-- land; DataService.setLevelResolver lets the heist server supply them from there.
Config.Data = {
	-- Storage. Never rename STORE_NAME or KEY_PREFIX after launch (old saves would vanish).
	STORE_NAME = "EH_Player_v1",
	KEY_PREFIX = "U_", -- profile key: U_<userId>
	GHOST_PREFIX = "G_", -- personal-best recording key: G_<levelId>_<userId> (§8.7, not written yet)
	TEST_PREFIX = "_TEST_", -- prepended to every key in Studio and in TEST_UNIVERSE_IDS
	TEST_UNIVERSE_IDS = { 10776026960 }, -- the Open Cloud test experience (PROJECT_STATE)
	LEASE_SECONDS = 90, -- session lock lease (PlayerData); never under 30
	AUTOSAVE_SECONDS = 30, -- dirty-gated autosave and lease heartbeat (clamped to lease / 3)
	CLAIM_ATTEMPTS = 6, -- load attempts against a locked or failing key
	LOCKED_RETRY_SECONDS = 1.5, -- wait between claims while another server holds the lease
	SAVE_ATTEMPTS = 4, -- write attempts per save (exponential backoff with jitter)
	RECEIPTS_KEPT = 500, -- PurchaseIds remembered per player (idempotency window)
	PURCHASE_LOG_KEPT = 100, -- purchase log entries kept per player
	HEIST_SLICE_MAX_BYTES = 16000, -- budget for the Heist slice as JSON (§8.7: < 16 KB)
	SHELF_SLOTS = 8, -- trophies shown on the van shelf
	MAX_FTUE_STEP = 32,
	MIN_SECONDS_BETWEEN_AWARDS = 10, -- per player; no real heist is shorter than one 30 s run
	RECENT_HEIST_IDS = 8, -- heist ids remembered per player to refuse a double award
	MAX_HEIST_MS = 3600000, -- longest heist duration accepted (1 h)
	MAX_FRIENDS = 7, -- friends in a crew that count for the co-op bonus
	MAX_COUNT = 1000, -- cap on catches / busted counts in a result

	-- Currencies (lihfolk-systems Currency). None can be bought with Robux, ever (§5.1).
	Currencies = {
		Cash = { start = 0, max = 1e12, paid = false }, -- soft currency from banked loot
		Stars = { start = 0, max = 100000, paid = false }, -- mirror of medal + daily stars, never spent
		CandyCanes = { start = 0, max = 100000, paid = false }, -- event-only, earned only
	},

	-- Reward maths (Progress.cashFor)
	Economy = {
		CASH_PER_HAUL = 1, -- Cash per $1 of banked loot
		FRIEND_BONUS = 0.10, -- +10% Cash per friend in the crew (§3.3)
		FRIEND_BONUS_CAP = 0.30, -- capped at +30%
		TAINTED_CASH_MULT = 1, -- tainted runs still earn Cash; they lose medals and bests (§8.8)
		MAX_CASH_PER_HEIST = 100000, -- sanity cap per award
	},

	-- Clone Party bag levels (Cash only, §5.1). Level n costs COSTS[n].
	Bag = {
		MAX_LEVEL = 3,
		COSTS = { 2000, 5000, 12000 },
		EXTRA_CARRY_PER_LEVEL = 1, -- small items an actor can carry per bag level
	},

	-- Medal rules per level (§4.2, §5.2). kind "story": Haul / Crew / Clean (+ Diamond when
	-- devClones is set). kind "party": Haul1-3 tiers. haulTarget/haulTiers/maxHaul are $.
	LEVEL_ORDER = { "BackRoom", "TwoDoors", "LightsOut", "NightClerk", "CloneParty", "BigScoreBank" },
	Levels = {
		BackRoom = {
			kind = "story",
			haulTarget = 300,
			maxHaul = 5000,
			parClones = 1,
			cap = 3,
			trophy = "Trophy_BackRoom",
			firstClearCash = 100,
		},
		TwoDoors = {
			kind = "story",
			haulTarget = 400,
			maxHaul = 5000,
			parClones = 2,
			cap = 4,
			trophy = "Trophy_TwoDoors",
			firstClearCash = 150,
			unlockAfter = "BackRoom",
		},
		LightsOut = {
			kind = "story",
			haulTarget = 500,
			maxHaul = 5000,
			parClones = 2,
			cap = 4,
			trophy = "Trophy_LightsOut",
			firstClearCash = 200,
			unlockAfter = "TwoDoors",
		},
		NightClerk = {
			kind = "story",
			haulTarget = 600,
			maxHaul = 5000,
			parClones = 2,
			cap = 4,
			trophy = "Trophy_NightClerk",
			firstClearCash = 250,
			unlockAfter = "LightsOut",
			devClones = nil, -- Diamond (§5.2): set to the developer's clone count when recorded
		},
		CloneParty = {
			kind = "party",
			haulTiers = { 1000, 2500, 5000 },
			maxHaul = 100000,
			cap = 8,
			trophy = "Trophy_CloneParty",
			firstClearCash = 300,
			unlockAfter = "NightClerk",
		},
		BigScoreBank = {
			kind = "story",
			haulTarget = 2000,
			maxHaul = 20000,
			parClones = 4,
			cap = 8,
			trophy = "Trophy_BigScoreBank",
			firstClearCash = 500,
			unlockAfter = "NightClerk",
			starsRequired = 6, -- §4.2 gate: 6 of the 15 Stars from L1-L5
			devClones = nil,
		},
	},

	-- Daily vault = advent calendar in December (§5.3, §4.3). Day = UTC date.
	Daily = {
		RESET_OFFSET_HOURS = 0, -- 00:00 UTC
		GRACE_DAYS = 1, -- one missed day keeps the streak
		VAULT_COUNT = 12, -- hand-authored mini-vaults in rotation (14 from Dec 11)
		FIRST_CLEAR_STARS = 1,
		FIRST_CLEAR_CASH = 250,
		FIRST_CLEAR_CANDY_CANES = 5, -- only while the event runs
	},
	Advent = {
		YEAR = 2026,
		FIRST_DAY = 3, -- Dec 3 (launch) .. LAST_DAY: one ornament slot per December day
		LAST_DAY = 24,
		CATCH_UP_UNTIL = { 2026, 12, 31 }, -- missed advent days can be played until this day
	},
	Event = {
		NAME = "StealBackChristmas",
		FIRST = { 2026, 12, 3 },
		LAST = { 2027, 1, 4 }, -- Candy Canes are earned and spent until this day; items stay owned
	},

	-- Cosmetics (§5.1, §5.4). slot -> the default item every player owns.
	DEFAULT_EQUIPPED = {
		cloneStyle = "Style_Default",
		cloneHat = "Hat_None",
		vanPaint = "Paint_Default",
		trail = "Trail_None",
	},
	-- price = earned currency (Data.Buy); product = Robux developer product (Shop.PromptProduct);
	-- neither = a default or a free grant. lastDay = last UTC day it can be bought.
	Cosmetics = {
		Style_Default = { slot = "cloneStyle", name = "Classic Clone", default = true },
		Style_GoldGhost = { slot = "cloneStyle", name = "Gold Ghost", product = "StyleGoldGhost" },
		Style_Noir = { slot = "cloneStyle", name = "Noir", product = "StyleNoir" },
		Style_NeonOutline = { slot = "cloneStyle", name = "Neon Outline", product = "StyleNeonOutline" },
		Style_Santa = { slot = "cloneStyle", name = "Santa Clone", product = "ChristmasCrew" },
		Hat_None = { slot = "cloneHat", name = "No Hat", default = true },
		Hat_Santa = {
			slot = "cloneHat",
			name = "Santa Hat",
			price = { currency = "CandyCanes", amount = 25 },
			lastDay = { 2027, 1, 4 },
		},
		Paint_Default = { slot = "vanPaint", name = "Getaway White", default = true },
		Paint_MidnightBlue = { slot = "vanPaint", name = "Midnight Blue", price = { currency = "Cash", amount = 2500 } },
		Paint_GetawayGreen = { slot = "vanPaint", name = "Getaway Green", price = { currency = "Cash", amount = 6000 } },
		Paint_Chrome = { slot = "vanPaint", name = "Chrome", product = "PaintChrome" },
		Paint_GoldRush = { slot = "vanPaint", name = "Gold Rush", product = "PaintGoldRush" },
		Paint_Sleigh = { slot = "vanPaint", name = "Sleigh Red", product = "ChristmasCrew" },
		Paint_CandyStripe = {
			slot = "vanPaint",
			name = "Candy Stripe",
			price = { currency = "CandyCanes", amount = 40 },
			lastDay = { 2027, 1, 4 },
		},
		Trail_None = { slot = "trail", name = "No Trail", default = true },
		Trail_Mint = { slot = "trail", name = "Mint Trail", price = { currency = "Cash", amount = 1500 } },
		Trail_Sunset = { slot = "trail", name = "Sunset Trail", price = { currency = "Cash", amount = 4000 } },
		Trail_Snow = { slot = "trail", name = "Snow Trail", product = "ChristmasCrew" },
	},

	-- Robux developer products (one ProcessReceipt: lihfolk-systems Receipts). id = 0 until the
	-- owner creates them on the Creator Dashboard (0 is never prompted). Prices are NOT here:
	-- clients show MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product).PriceInRobux.
	-- The planned dashboard prices (§5.4) are in docs/DATA.md. Fixed contents, no randomness.
	Products = {
		StyleGoldGhost = { id = 0, grants = { "Style_GoldGhost" } },
		StyleNoir = { id = 0, grants = { "Style_Noir" } },
		StyleNeonOutline = { id = 0, grants = { "Style_NeonOutline" } },
		ChristmasCrew = { id = 0, grants = { "Style_Santa", "Paint_Sleigh", "Trail_Snow" }, lastDay = { 2027, 1, 4 } },
		PaintChrome = { id = 0, grants = { "Paint_Chrome" } },
		PaintGoldRush = { id = 0, grants = { "Paint_GoldRush" } },
	},

	-- Trophies (van shelf) and ornaments (advent tree). Level trophies are listed here;
	-- ornaments are generated below. kind: "level" | "ornament" | "event".
	Trophies = {
		Trophy_BackRoom = { kind = "level", name = "Back Room Bell" },
		Trophy_TwoDoors = { kind = "level", name = "Twin Door Knobs" },
		Trophy_LightsOut = { kind = "level", name = "Burnt-Out Bulb" },
		Trophy_NightClerk = { kind = "level", name = "Night Clerk's Torch" },
		Trophy_CloneParty = { kind = "level", name = "Party Popper Bag" },
		Trophy_BigScoreBank = { kind = "level", name = "Hoardsworth Vault Wheel" },
		Trophy_SnowGlobe = {
			kind = "event",
			name = "Snow Globe",
			price = { currency = "CandyCanes", amount = 60 },
			lastDay = { 2027, 1, 4 },
		},
	},
}

-- One ornament per daily-vault design and one per advent day (Orn_Vault01, Orn_Advent2026_03).
do
	local data = Config.Data
	for i = 1, 14 do
		data.Trophies[string.format("Orn_Vault%02d", i)] =
			{ kind = "ornament", name = string.format("Vault %d Ornament", i) }
	end
	for day = data.Advent.FIRST_DAY, data.Advent.LAST_DAY do
		data.Trophies[string.format("Orn_Advent%d_%02d", data.Advent.YEAR, day)] =
			{ kind = "ornament", name = string.format("Advent Ornament %d", day) }
	end
end

-- Analytics (pure catalog + Tracker in src/shared/Analytics, AnalyticsService adapter in
-- src/server/Analytics/Analytics), MASTERPLAN §7.5, §9.3, §9.7, §8.6, §8.12; docs/ANALYTICS.md.
-- Event names, funnel steps, custom fields and bucket edges are the dashboard schema and live in
-- Analytics/Events (like a file format); the numbers that steer sending and budgets live here.
Config.Analytics = {
	-- ServerBuild (§8.12 rollout check) sends game.PlaceVersion as "pv" .. PlaceVersion % 100; BUILD is
	-- only the fallback where PlaceVersion is 0 (Studio, an unpublished place).
	BUILD = 1,

	-- Environments (Data/Keys.isTestEnvironment). Studio never reaches the dashboard, so calls are
	-- only recorded in memory there. The test experience has its own dashboard (early testers, §9.5).
	SEND_IN_TEST = true,
	STUDIO_PRINT = false, -- print every recorded call to the Output in Studio (call-site debugging)
	RECENT_KEPT = 200, -- last calls kept for Analytics.recent() (Studio, test, engine smoke)
	WARN_EVERY_SECONDS = 10, -- at most one analytics warning in the Output this often
	LEFT_KEEP_SECONDS = 60, -- a departed player's queued calls still find their Player this long

	-- Our own budgets: Roblox does not publish AnalyticsService limits (vault: batch, never flood).
	SERVER_BURST = 120, -- calls the server may send at once
	SERVER_PER_MINUTE = 120, -- refill per minute for the whole server ...
	SERVER_PER_MINUTE_PER_PLAYER = 20, -- ... plus this per player present (we expect ~8)
	PLAYER_BURST = 30, -- unbatched custom events one player can send at once (a buggy call site)
	PLAYER_PER_MINUTE = 30,
	BACKLOG_MAX = 400, -- calls waiting for budget; custom events are dropped first beyond this
	PENDING_PER_PLAYER = 64, -- calls held per player until the join source is known
	BATCH_FLUSH_SECONDS = 60, -- batched counts flush this often, on leave and in BindToClose
	TICK_SECONDS = 1, -- timers (Minute10, flush, budget) are checked this often
	SHUTDOWN_SECONDS = 3, -- BindToClose share for the final flush

	-- Join source (§9.3, §9.7). Launch data "v1|<verb>|<arg>[|<tag>]" can arrive a few seconds
	-- after join (Roblox docs), so the server polls GetJoinData.
	JOIN_DATA_POLLS = 10,
	JOIN_DATA_POLL_SECONDS = 1,
	FACTS_WAIT_SECONDS = 12, -- wait this long for the profile (cohort, ftueStep) before logging without it
	LAUNCH_DATA_MAX_BYTES = 200,
	ACQ_HINT_KEY = "EH_AcqSource", -- optional ConfigService string the owner targets by acquisition source
	CHANNEL_TAGS = { "tt", "yt", "ig", "dc", "web", "devlog", "event" }, -- Creator Hub share link per channel
	AD_TAGS = { "ad_plays", "ad_eng", "ad_test" }, -- Ads Manager join-option launch data (§9.5)
	CREATOR_SLOTS = 30, -- personal creator links cr01..cr30 (20 micro + 10 mid, §9.6)
	VARIANTS = { "base", "a", "b", "c" }, -- experiment arms that may appear in custom fields

	-- Session KPIs (§7.5, §9.7)
	MINUTE10_SECONDS = 600,
	-- A profile created at most this long before the join is "new". The profile is created after
	-- PlayerAdded on the same server, so this only covers clock skew; a crash rejoin minutes later
	-- must not count as a second first session.
	NEW_PLAYER_GRACE_SECONDS = 30,
	HEIST_SESSIONS_KEPT = 4, -- open heist funnel sessions kept per player
	STORE_SESSION_SECONDS = 600, -- a store funnel session stays open this long after StoreOpened
	STORE_REOPEN_SECONDS = 10, -- a StoreOpened sooner than this after the last one reuses its session
	STORE_SESSIONS_MAX = 20, -- store funnel sessions per player session (a spamming client)

	-- Client remotes (LihFolk Net). Analytics.Ui carries clip and store UI steps only the client sees.
	RATE = {
		Ready = { burst = 2, perSecond = 0.1 },
		Perf = { burst = 2, perSecond = 0.05 },
		Ui = { burst = 8, perSecond = 1 },
	},

	-- Client frame-time telemetry (§8.6, §6.3, §6.8), shared/Analytics/PerfSample.
	Perf = {
		INTERVAL_SECONDS = 60, -- one sample per client per minute (LiveFlag perfIntervalSeconds raises it)
		MIN_FRAMES = 300, -- a window with fewer frames is not sent (paused, backgrounded)
		BIN_MS = 0.5, -- histogram resolution
		MAX_MS = 100, -- slower frames land in the overflow bin (exact worst frame kept)
		MAX_FRAME_SECONDS = 2, -- longer gaps are pauses (app in background), not frames
		-- A frame is slow when it is clearly slower than 30 fps: the 33.3 ms low-phone ceiling (§6.8)
		-- plus a vsync jitter margin. A device held at 30 fps by the OS (Low Power Mode, battery saver)
		-- or a 60 fps device that misses a vsync (33.3 ms frames) is at the ceiling, not over it.
		SLOW_MS = 36,
		STEP_DOWN_SECONDS = 20, -- p95 > SLOW_MS for this long steps the performance tier down (§8.6)
		STEP_DOWN_SHARE = 0.05, -- p95 > SLOW_MS means more than 5% of a second's frames are slow
		-- after a step, the next slow streak must cut the slow share by this much (relative), else the
		-- governor stops (lowering quality cannot beat an OS frame cap or a CPU-bound device)
		STEP_MIN_GAIN = 0.1,
		STEP_COOLDOWN_SECONDS = 30, -- after a step down, wait this long before judging again
		MIN_FRAMES_PER_SECOND = 10, -- a second with fewer frames is not judged (loading hitch)
		TABLET_MIN_SIDE = 600, -- viewport short side (px) from which a touch device counts as a tablet
	},

	-- KPI bars (§9.7), read by Analytics/Kpi for reports. pct = percent, s = seconds, min = minutes.
	-- higher = true: bigger is better. Below kill = kill/rework; >= healthy = healthy; >= double =
	-- double down; anything between kill and healthy = fix before scaling (lower-is-better mirrored).
	KPI = {
		AD_SHIFT_POINTS = 4, -- ad cohorts: retention bars 4 points lower; kill never fires on them
		joinToControl = { unit = "s", higher = false, kill = 20, healthy = 10 },
		firstCloneSeen45 = { unit = "pct", higher = true, kill = 60, healthy = 85 },
		l1Complete = { unit = "pct", higher = true, kill = 50, healthy = 70, double = 80 },
		swarmSeen10 = { unit = "pct", higher = true, kill = 35, healthy = 60, double = 75 },
		bounce60 = { unit = "pct", higher = false, kill = 35, healthy = 20, double = 12 },
		medianFirstSession = { unit = "min", higher = true, kill = 5, healthy = 12, double = 18 },
		d1 = { unit = "pct", higher = true, kill = 8, healthy = 15, double = 22, minCohort = 300, retention = true },
		d7 = { unit = "pct", higher = true, kill = 1.5, healthy = 4, double = 6, minCohort = 300, retention = true },
		friendSessions = { unit = "pct", higher = true, kill = 8, healthy = 20, double = 30 },
		clipTaps = { unit = "pct", higher = true, kill = 1, healthy = 5, double = 10 },
		medianFirstBank = { unit = "s", higher = false, kill = 90, healthy = 60 }, -- Nov 30 gate: <= 60 s
	},
}

-- LiveFlags (src/server/Analytics/LiveFlags, pure rules in src/shared/Analytics/LiveFlagSpec),
-- MASTERPLAN §8.7, §8.12; docs/ANALYTICS.md "LiveFlags". Turns features off or retunes them
-- without a publish. Layers, lowest first: these defaults < ConfigService key "EH_<name>"
-- (Creator Hub, about a minute, per-switch history) < the DataStore document (polled, Open Cloud
-- writable for incidents) < a Studio/test-only testing value. A failed read keeps the last good one.
-- Kill switches: off wins (a switch is off when any layer sets it false).
-- kind: kill (boolean, default true, the system works) | release (boolean or 0-100 percent of
-- players, default off) | tune (number in [min, max]) | experiment ("arm:weight,..." sticky arms).
-- client = true: mirrored as an attribute on ReplicatedStorage.LiveFlags for the UI.
Config.LiveFlags = {
	POLL_SECONDS = 60, -- §8.7: the DataStore document is re-read this often (one read per server)
	STORE_NAME = "EH_Live_v1",
	KEY = "LiveFlags", -- "_TEST_LiveFlags" in Studio and the test experience (Config.Data.TEST_PREFIX)
	CONFIG_PREFIX = "EH_", -- ConfigService keys: EH_saveClip, EH_alarmVanSeconds, ...
	ATTRIBUTE_FOLDER = "LiveFlags",
	MAX_DOC_BYTES = 20000, -- a document bigger than this as JSON is refused
	Flags = {
		-- Kill switches (default true)
		analytics = { kind = "kill", default = true, desc = "every AnalyticsService call" },
		analyticsCustom = { kind = "kill", default = true, desc = "custom events (funnels and economy stay)" },
		perfSampling = { kind = "kill", default = true, client = true, desc = "client PerfSample telemetry" },
		store = { kind = "kill", default = true, client = true, desc = "Robux store prompts and store UI" },
		cashShop = { kind = "kill", default = true, client = true, desc = "Cash and Candy Cane purchases" },
		quickCrew = { kind = "kill", default = true, client = true, desc = "Quick Crew board (strangers)" },
		joinFriend = { kind = "kill", default = true, client = true, desc = "Join friend crew moves" },
		saveClip = { kind = "kill", default = true, client = true, desc = "SAVE CLIP button" },
		saveClipVideo = { kind = "kill", default = true, client = true, desc = "video capture (off = screenshot)" },
		shareLinks = { kind = "kill", default = true, client = true, desc = "PromptLinkSharingAsync share" },
		invites = { kind = "kill", default = true, client = true, desc = "PromptGameInvite button" },
		rsvpPrompt = { kind = "kill", default = true, desc = "event RSVP prompt after the first heist" },
		dailyVault = { kind = "kill", default = true, client = true, desc = "daily vault / advent entry" },
		boards = { kind = "kill", default = true, client = true, desc = "daily biggest-haul board" },
		dressing = { kind = "kill", default = true, client = true, desc = "Christmas dressing layer" },
		giftBeat = { kind = "kill", default = true, client = true, desc = "Dec 25-26 gift beat" },
		alarmRun = { kind = "kill", default = true, desc = "Alarm Run (off: alarms do not start a chase)" },
		ghostHint = { kind = "kill", default = true, client = true, desc = "Ghost Hint after 2 failed runs" },
		-- Release flags (default off)
		clipUpload = { kind = "release", default = false, client = true, desc = "UploadCaptureAsync (§9.3)" },
		referralReward = { kind = "release", default = false, desc = "referral cosmetic after 10 min (§9.3)" },
		rewardedVideo = { kind = "release", default = false, client = true, desc = "13+ rewarded video" },
		globalBoard = { kind = "release", default = false, client = true, desc = "global daily board (Dec 11)" },
		-- Tuning (read at heist start, never mid-run; the value goes into the heist record)
		alarmVanSeconds = { kind = "tune", default = Config.Sim.ALARM_VAN_SECONDS, min = 10, max = 40 },
		alarmLockSeconds = { kind = "tune", default = Config.Sim.ALARM_LOCK_SECONDS, min = 3, max = 20 },
		alarmChaseSpeedMult = { kind = "tune", default = Config.Sim.GUARD_CHASE_SPEED_MULT, min = 0.5, max = 1.1 },
		crewCloneBudget = { kind = "tune", default = Config.Sim.CREW_CLONE_BUDGET, min = 4, max = 16 },
		maxInstances = { kind = "tune", default = Config.Heist.MAX_INSTANCES, min = 1, max = 8 },
		perfSampleRate = { kind = "tune", default = 1, min = 0, max = 1, client = true },
		perfIntervalSeconds = {
			kind = "tune",
			default = Config.Analytics.Perf.INTERVAL_SECONDS,
			min = 30,
			max = 600,
			client = true,
		},
		-- Experiments (sticky per player; arms must be in Config.Analytics.VARIANTS)
		ftueVariant = { kind = "experiment", default = "base:100", desc = "onboarding A/B (from Jan 8)" },
	},
}

return Config
