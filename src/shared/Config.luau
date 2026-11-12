-- Echo Heist: all tunable numbers in one place.

local Config = {}

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
	REACH_MAX_CELLS = 250000,
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

return Config
