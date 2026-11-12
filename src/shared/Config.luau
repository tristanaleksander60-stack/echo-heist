-- Echo Heist: all tunable numbers in one place.

local Config = {}

-- Which game runs: "v01" = the v0.1 prototype (kept for reference),
-- "sim" = the HeistSim path (src/server/Heist, src/client/Heist; Config.Heist below),
-- the default since the owner finished the fun test on 2026-11-12.
-- Both entry scripts (src/server/init.server.luau, src/client/init.client.luau) read it.
Config.GAME_MODE = "sim"

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
	INSTANCE_SPACING = 3000, -- studs between neighbouring instance origins (lobby at the world origin)
	INSTANCE_Y = 0, -- floor height of every instance
	MAX_INSTANCES = 8, -- per server (owner decision 2026-11-12; the plan had 4): 8 solo crews always fit
	-- Slot origins on a grid around the lobby, in units of INSTANCE_SPACING: the four axis
	-- cells first, then the diagonals (at most ~4,243 studs out; float precision stays fine).
	INSTANCE_SLOTS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } },
	INSTANCE_COOLDOWN_SECONDS = 5, -- one new heist per player pick in this long (SelectLevel / Leave churn)
	LOBBY_ORIGIN = { 0, 0, 0 },

	-- Run flow (§3.1, §7.1): { standard, quick, reduced motion } seconds; the server waits
	-- the chosen length before the run clock starts (control returns at its end).
	REWIND_TRANSITION = { 1.8, 1.0, 0.8 },
	QUICK_REWIND_FROM_RUN = 4, -- quick rewinds automatically from the 4th rewind (run 5 starts)
	FIRST_RUN_INTRO = 1.0, -- run 1: "RUN 1" stamp, teleport settles
	TUTORIAL_BETWEEN_SECONDS = 0.4, -- L1 (deck locked): the next run starts by itself
	BETWEEN_MAX_SECONDS = 25, -- between runs: the next run starts when all are ready, or after this
	PARTY_BETWEEN_SECONDS = 10, -- party levels (deck locked: every clone stays for "8 OF ME"): auto-start
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
	FLAGS_WAIT_SECONDS = 3, -- ... and for the first LiveFlags DataStore/ConfigService read
	FTUE_L1_LEVEL = "cs1_back_room", -- LevelSpec id of the FTUE level (autostart, L1Complete, daily gate)
	FTUE_L2_LEVEL = "cs2_two_doors", -- LevelSpec id whose start is the funnel step L2Started
	FTUE_RETRY_TRIES = 6, -- a new player's FTUE start that found every van out retries this often
	FTUE_RETRY_SECONDS = 10,
	FIRST_MOVE_STUDS = 2, -- funnel FirstMove: a live player this far from their run-1 spawn

	-- Daily vault (§5.3): today's vault from Levels/DailyVaults; missed advent days are offered
	-- for catch-up (Data/DailyVault.playMode) up to this many at a time in the garage list.
	DAILY_CATCH_UP_LIST = 8,

	-- Art kit (spike S2, docs/art/KIT_IMPORT.md): levels are dressed with kit pieces when
	-- src/server/Kit/KitService is ready; collision stays the sim's boxes (invisible greybox
	-- colliders), so gameplay never depends on the art. false = greybox only.
	KIT_LEVELS = true,
	KIT_WAIT_SECONDS = 4, -- a heist the server starts itself (FTUE) waits this long for the kit
	KIT_FLOOR = true, -- floor tiles inside the building footprint
	KIT_FLOOR_LIFT = 0.02, -- studs the visual floor tiles sit above the collision floor
	-- Christmas dressing layer (§4.3): "auto" = on while Config.Data.Event runs (server date)
	-- and the LiveFlag `dressing` is on; "on" / "off" force it (tests, captures).
	XMAS_DRESSING = "auto",

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
		SelectDaily = { burst = 3, perSecond = 1 },
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
	CLONE_LABEL_SECONDS = 1.0, -- "◀ YOU, 10 SEC AGO" on the newest clone (story levels after L1)
	-- L1 (§7.5, 13-22 s): the label stays until the clone's recorded path ends (it stops on
	-- the plate) plus this; the clone fades in this late so it visibly walks out of you.
	CLONE_LABEL_HOLD_AFTER_STOP = 1.5,
	CLONE_LABEL_MAX_SECONDS = 12,
	TUTORIAL_CLONE_FADE_IN = 0.5,
	STOPS_LINE_SECONDS = 4, -- "Your clone stops where you stop." from the clone's first plate press
	CLONE_NEAR_UNFADE = 7.5, -- near-camera fade hysteresis: fade under CLONE_NEAR_FADE, back over this
	CLONE_NEAR_FADE = 6, -- clones this close to the camera fade
	MAX_CLONE_ACCESSORIES = 2,
	WALK_ANIM_BASE_SPEED = 16, -- studs/s at which the walk clip plays at speed 1
	EVENT_BLEND = 0.15, -- server-decided clone changes blend in over this long
	DOOR_SLIDE_SECONDS = 0.35,
	PLATE_SINK = 0.15,
	CONE_RAYS = 12, -- Gus's vision cone fan
	CONE_HZ = 10,
	END_RUN_BUTTON = 72, -- px
	END_RUN_Y = 0.35, -- share of the HUD height: END RUN's centre (§3.4: >= 140 px above the jump button)
	INTERACT_BUTTON = 72, -- px (>= 64)
	HINT_SECONDS = { 8, 16, 24 }, -- L1 stuck hints (§7.5)
	TIMER_PULSE_SECONDS = 10,
	TIMER_RED_SECONDS = 5,

	-- Sounds: Config.Audio and Shared/Audio (the client AudioDirector); docs/AUDIO.md.

	-- HUD layout and touch (§7.4, §0 C5, roblox-ui-builder): the HUD is designed at 1x and scaled
	-- by the safe area to fit UI_DESIGN_SIZE, clamped to [UI_SCALE_MIN, UI_SCALE_MAX]. Every button is
	-- at least TAP_MIN design px tall, so a tap target stays >= 64 px at the smallest scale.
	-- 330 tall: a 360-dp Android phone or an iPhone SE in landscape (safe height ~300 px under
	-- the Roblox top bar) still gets the whole canvas at UI_SCALE_MIN (panels are <= 326 tall).
	UI_DESIGN_SIZE = { 720, 330 }, -- px: the largest panel (garage, results) fits this at 1x
	UI_SCALE_MIN = 0.9,
	UI_SCALE_MAX = 1.5,
	TAP_MIN = 72, -- px at 1x (72 x 0.9 = 64.8 px on the smallest phone)
	TOAST_SECONDS = 3,
	END_RUN_GRAB_GUARD = 0.3, -- s: an END RUN tap this soon after a GRAB tap is ignored (thumb slip)
	BLINK_HZ_MAX = 3, -- §7.3: nothing on screen flashes faster than 3 times a second
	CAPTION_SECONDS = 2.5, -- sound captions ("[Alarm!]"), on by default (§7.4)

	-- New-state views (§3.6, §4.2, §5.3, §7.3)
	SWARM_STAMP_SECONDS = 1.6, -- "8 OF ME" stamp hold (Config.Sim.SWARM_OF_ME copies earn it)
	TIER_STAMP_SECONDS = 1.0, -- party haul tier ("★ HAUL 2")
	DIAMOND_DIM = 0.15, -- the diamond grab dims the world 15 % for DIAMOND_DIM_SECONDS (§7.3)
	DIAMOND_DIM_SECONDS = 0.6,
	ALARM_BEACON_TURN_SECONDS = 0.8, -- one turn of the rotating red alarm beacons (emissive, no lights)
	ALARM_PULSE_SECONDS = 1.0, -- the red vignette pulses once per second on the Alarm Run (<= 3 flashes/s)
	ALARM_BEACON_HEIGHT = 9, -- studs above the floor: the beacon over the alarm's loot
	TILL_LABEL_DISTANCE = 70, -- studs: the time-locked till's "LOCKED 0:07" label hides beyond this
	LOCKED_SLACK = 0.25, -- s: a grab this close to a till's opensAt is sent anyway (the server decides)
	DAWN_WARN_RUNS = 2, -- party / daily levels: "☾ n RUNS TO DAWN" from this many runs left
	DOOR_SKIN_DIAL_TURNS = 1.5, -- vault door skin: dial turns while the door swings open
	PLATE_GLYPH_DISTANCE = 60, -- studs: the presser's glyph over a held plate (colour is never alone)
	LASER_SPARKS = 14, -- sparks when a laser retracts (§7.3)
	GUS_HEARTBEAT_SECONDS = 1.0, -- heartbeat tick while Gus's "?" is on you (§7.3)
	GUS_DUST_SECONDS = 0.18, -- sprint dust puffs while Gus chases (Alarm Run)

	-- Crew Line-up and the end-of-heist cut (§3.2 rule 8, §6.6, docs/marketing/CLIPS.md §1.2): the
	-- player and every clone walk to HeistSim.lineup's spots, then pose in record order 60 ms apart
	-- (Config.Sim.LINEUP_STAGGER). Never simulated, so it cannot desync. Skippable after SKIP_AFTER.
	LINEUP_START_DELAY = 0.8, -- s after Over: the HEIST COMPLETE / DAWN stamp reads first
	LINEUP_WALK_SPEED = 14, -- studs/s (faster when far: no walk takes longer than WALK_MAX_SECONDS)
	LINEUP_WALK_MAX_SECONDS = 2.6,
	LINEUP_TURN_SECONDS = 0.25, -- turn to face the camera on the spot
	LINEUP_POSE_GAP = 0.35, -- s between the last arrival and the first pose
	LINEUP_HOLD_SECONDS = 2.4, -- pose hold before the results card
	LINEUP_SKIP_AFTER = 1.0, -- the SKIP chip (and a tap anywhere on later cuts of the session)
	LINEUP_SKIP_AFTER_POSE = 0.5, -- first cut of a session: a tap anywhere skips only this long after the pose
	LINEUP_HOP = 0.9, -- studs: the synchronized victory hop
	LINEUP_POSE_ANIM = "rbxassetid://507770677", -- the default R15 cheer, on avatar figures
	LINEUP_VAN_CLEARANCE = 1.5, -- studs: a row spot inside the van body moves to clear it
	LINEUP_CAM_FOV = 50, -- STYLE_BIBLE B4 / CLIPS CAM_F5B
	LINEUP_CAM_FOV_MAX = 80, -- a wall in the way pulls the camera in and widens the lens up to this
	LINEUP_CAM_HEIGHT = 2.4, -- studs above the floor: a low camera looking up at the crew
	LINEUP_CAM_LOOK_HEIGHT = 3.4,
	LINEUP_CAM_FIT_WIDTH = 0.6, -- the row fills at most this share of the frame width (landscape)
	LINEUP_CAM_FIT_HEIGHT = 0.45, -- a figure fills at most this share of the frame height
	LINEUP_CAM_DISTANCE = { 7, 40 }, -- studs: min, max
	LINEUP_CAM_MOVE_SECONDS = 1.4, -- ease from the play camera to the line-up shot
	LINEUP_CAM_PUSH = 0.15, -- slow push-in during the walk and pose (share of the distance)
	LINEUP_LABEL_SECONDS = { 1.5, 1.8 }, -- "◀ ME, N SEC AGO": hold, then fade out by (CLIPS §1.2)
	LINEUP_FIGURE_HEIGHT = 5.6, -- studs, for the camera fit

	-- Runtime performance tier (§6.3, §8.6): the PerfSample governor steps it down; names are
	-- Analytics Events.DOMAINS.perfTier. 1 = quality ... 4 = minimum.
	PERF_TIERS = { "quality", "balanced", "performance", "minimum" },
	PERF_READY_TIMEOUT = 15, -- s to wait for the Analytics remotes before telemetry gives up
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

	-- Play order (= Levels/Catalog, owner decision 2026-11-12 "party break"): Clone Party
	-- (L5) comes right after Two Doors (L2), so "8 OF ME" lands around minute 10 of a first
	-- session. Unlocks: Clone Party AND Lights Out open when Two Doors is cleared (the party
	-- is a break, never a wall: a kid who leaves it keeps the story); "NEXT" and the garage
	-- follow this order. Progression analytics number levels by their place here.
	LEVEL_ORDER = { "BackRoom", "TwoDoors", "CloneParty", "LightsOut", "NightClerk", "BigScoreBank" },
	-- Medal rules per level (§4.2, §5.2). kind "story": Haul / Crew / Clean (+ Diamond when
	-- devClones is set). kind "party": Haul1-3 tiers. haulTarget/haulTiers/maxHaul are $.
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
			unlockAfter = "TwoDoors", -- the party break (played third, design number L5)
		},
		BigScoreBank = {
			kind = "story",
			haulTarget = 2000,
			maxHaul = 20000,
			parClones = 4,
			cap = 8,
			trophy = "Trophy_BigScoreBank",
			firstClearCash = 500,
			unlockAfter = "NightClerk", -- the last story level in play order
			starsRequired = 6, -- §4.2 gate: 6 of the 15 Stars from L1-L5 (all played by then)
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

-- Light and levels (PLAN_STEAM_PLUS §4.1 W1-W3, docs/research/roblox_quality.md §1.2, docs/audit/LEVELS.md
-- §4 P0). The global recipe A "Moonlit Diorama" lives in default.project.json (place_check asserts it); the
-- Sky keeps Roblox's faces until the plain night faces (assets/textures/EH_SkyNight_*.png,
-- tools/blender/sky_faces.py) are uploaded and pasted into the project's Sky node; the city cubemap is phase 2.
-- Lamps: Heist/KitPlan.lamps (one over each plate, a hero over the goal, room centres from Heist/LevelDress),
-- built by Heist/LevelBuilder (light + unlit floor pool) and dressed with Lamp_Ceiling by Heist/KitDresser.
Config.Lighting = {
	-- Per lamp kind: PointLight (room, plate) or a downward SpotLight (hero, the only shadowed one).
	LAMP = {
		room = { range = 20, brightness = 1.2, color = { 255, 205, 150 }, shadows = false },
		plate = { range = 18, brightness = 1.3, color = { 255, 205, 150 }, shadows = false },
		hero = { range = 36, brightness = 3, angle = 60, color = { 255, 214, 160 }, shadows = true },
	},
	LAMP_HANG_Y = 12, -- studs above the floor: Lamp_Ceiling hangs from the wall tops (its pivot)
	LIGHT_Y = 8.2, -- the light's attachment, under the shade (a shadowed light inside its lamp is shadowed by it)
	BULB_Y = 8.95, -- the greybox bulb (Lamp_Ceiling_Bulb's centre)
	BULB_SIZE = 0.84,
	BULB_COLOR = { 246, 192, 162 }, -- Bulb Warm #F6C0A2 (eh_palette.NEON, rule N1)
	-- Unlit floor pool under every lamp (SurfaceGui, LightInfluence 0: decals are lit and darken at night):
	-- concentric discs, outermost first; size = share of the diameter, alpha = transparency.
	POOL = {
		diameter = 14,
		heroDiameter = 11,
		lift = 0.06, -- studs above the floor (kit floor tiles sit at +0.02, cables at +0.03..0.06)
		brightness = 1.2,
		color = { 216, 200, 168 }, -- Warm Marble #D8C8A8
		rings = { { size = 1, alpha = 0.88 }, { size = 0.7, alpha = 0.8 }, { size = 0.42, alpha = 0.72 } },
		pixelsPerStud = 8,
	},
	MIN_LAMP_GAP = 7, -- studs: a room lamp this close to a plate or hero lamp is skipped
	AUTO_ROOM_WIDE = 24, -- studs: an auto room wider than this gets two lamps (daily vaults without LevelDress)
	VIEW_RADIUS = 24, -- studs: "one view" for the light budget (a 32 x 24 room)
	MAX_LIGHTS_PER_VIEW = 9, -- roblox_quality §1.2 / §6.4: 6-9 lights per view ...
	MAX_SHADOWED_PER_VIEW = 2, -- ... at most 2 shadowed
	-- Client LightDirector by performance tier (Config.Heist.PERF_TIERS): shadows off from this tier, pools
	-- off from this tier (roblox_quality §6.4: T3 phones get 6 lights, 0 shadowed).
	SHADOWS_OFF_TIER = 3,
	POOLS_OFF_TIER = 4,

	-- Plates (LEVELS P0-1): the idle rim glows in Bulb Warm and breathes; the letter sits on the top face.
	PLATE_IDLE_ALPHA = 0.5,
	PLATE_BREATHE = 0.15, -- +- transparency
	PLATE_BREATHE_HZ = 0.5, -- far under Config.Heist.BLINK_HZ_MAX; steady under reduced motion
	PLATE_LETTER_SIZE = 2.6, -- studs: the letter's square on the plate
	PLATE_LETTER_YAW = 0, -- degrees: turns the top-face letter (180 if it reads upside down from the street)
	PLAQUE_SIZE = 1.6, -- studs: the letter disc on each device a plate drives
	PLAQUE_DOOR_DX = 2, -- studs beside the door lamp on the header
	PLAQUE_DOOR_Y = 10.8,
	PLAQUE_LASER_Y = 7, -- on the laser's near post
	CABLE_WIDTH = 0.5, -- idle cables in Vault Steel, 0.5 wide (LEVELS P0-2)
	CABLE_JAMB_INSET = 0.5, -- a door cable ends this far inside its near jamb
	CABLE_TRUNK_GAP = 1, -- several plates into one device: parallel trunks this far apart

	-- Doors (LEVELS P0-5, STYLE_BIBLE §5.2): leaves pocket-slide sideways, shutters roll up into the header.
	SHUTTER_ROLLED = 0.35, -- Size.Y of a rolled-up shutter (top pinned)

	-- Goal sparkle (LEVELS P0-4): items worth at least this, and top items, sparkle while at home.
	SPARKLE_MIN_VALUE = 100,
	SPARKLE_RATE = 2.5, -- particles a second (<= BLINK_HZ_MAX flashes)
	SPARKLE_COLOR = { 255, 230, 156 }, -- Heist Gold light

	-- Van zone (LEVELS P0-6): dim until you carry loot, then lit with arrows that point at the van.
	VAN_IDLE_ALPHA = 0.85,
	VAN_CARRY_ALPHA = 0.6,
	ARROW_IDLE_ALPHA = 0.75,
	ARROW_COUNT = 3,
	ARROW_STEP = 2.4, -- studs between arrows along the zone
	ARROW_HEAD = { 2.4, 1.2 }, -- studs: head width, length
	ARROW_SHAFT = { 0.7, 1.0 }, -- studs: shaft width, length
}

-- Art kit (spike S2, automated path: docs/art/KIT_IMPORT.md "Automated path"). The asset ids and the
-- manifest live in the generated src/server/Kit/KitData.luau (python3 tools/kit_upload.py); these are
-- the boot knobs of src/server/Kit/KitService.luau.
Config.Kit = {
	FOLDER = "Kit", -- ServerStorage/<FOLDER>: one Model per kit group (a Rojo-mapped assets/Kit.rbxm is used as is)
	-- Pieces the game swaps in as colliders (Heist/KitDresser): they keep their manifest
	-- CollisionFidelity; every other piece is visual only and is built with Box (KitLib.gameCollision).
	COLLIDER_PIECES = { Wall_Door_8x12_Leaf = true, Shutter_8x10 = true, Plate_4x4 = true },
	SIZE_TOLERANCE = 0.05, -- studs per axis, MeshPart.Size vs kit_manifest.json
	POSITION_TOLERANCE = 0.05, -- studs: a piece's centre vs origin + bounds centre (catches an FBX axis change)
	LOAD_CONCURRENCY = 6, -- parallel InsertService:LoadAsset calls at boot
	REBUILD_CONCURRENCY = 8, -- parallel AssetService:CreateMeshPartAsync calls at boot
	LOAD_ATTEMPTS = 4, -- per asset; backoff RETRY_BASE_SECONDS x 1, 2, 4
	REBUILD_ATTEMPTS = 2,
	RETRY_BASE_SECONDS = 1,
	-- Uploaded MeshParts get CollisionFidelity Default (measured). It cannot be changed at runtime, so a part
	-- whose manifest collision differs is rebuilt with CreateMeshPartAsync: "all" | "colliding" (CanCollide
	-- pieces only) | "none" (keep Default everywhere).
	REBUILD_FIDELITY = "all",
	READY_TIMEOUT = 90, -- seconds KitService.ready() waits by default
	-- Atlas image overrides per location (a number or rbxassetid://...). Empty: the uploaded Decal's image
	-- (KitData.images), else for Bank the atlas texture the FBX import made.
	Atlas = {
		Bank = "",
		CornerShop = "",
		ToyShop = "",
	},
}

-- Audio: cue table and pure rules in src/shared/Audio (Cues, Manifest, CueCheck, Voices, Mix), the client
-- player in src/client/Audio/AudioDirector (Audio API graph). MASTERPLAN §7.1-7.3, docs/research/feel.md D5,
-- docs/AUDIO.md. Per-cue data (asset ids, level, jitter, voices, cooldown) lives in Audio/Cues like level data;
-- the mix and timing numbers every cue shares live here.
Config.Audio = {
	-- Buses (§7.2): dB at a 100 % slider. Starting points from feel.md D5 (SFX -18 LUFS, Clone -22, UI -24,
	-- Music -22 in play, Warnings -16), to be re-levelled once the files are measured.
	BUS_DB = { Master = 0, Music = -6, SFX = 0, Clone = -4, UI = -6, Ambience = -10, Warnings = 2 },
	SLIDER_EXPONENT = 2, -- slider 0..1 -> gain = slider ^ 2 (a squared curve feels even)
	WARNINGS_FLOOR = 0.25, -- the Alerts slider never goes below 25 %; Warnings ignore the Music slider
	MUTE_KEEPS_WARNINGS = false, -- "mute all" also silences Warnings (captions still show)

	-- Clone bus (§7.2, feel.md D2): clone sounds are memories. Lowpass, then a short slap echo, 4 dB under
	-- the player's version (BUS_DB.Clone). No clone footsteps.
	CLONE_LOWPASS_HZ = 5000,
	CLONE_ECHO_DELAY = 0.09, -- seconds
	CLONE_ECHO_FEEDBACK = 0.15,
	CLONE_ECHO_WET_DB = -12,
	CLONE_MAX_PER_SECOND = 6, -- clone sounds started per rolling second
	CLONE_VOICED_NEAREST = 4, -- live clone voices at once; a nearer one steals the farthest

	-- Master chain (vault: The Audio API §6): starting values, not a mastered chain.
	COMPRESSOR = { threshold = -18, ratio = 3, attack = 0.01, release = 0.15 },
	LIMITER_DB = -1,

	-- Voices (lihfolk-sfx "Voice limits")
	MAX_VOICES = 24, -- live one-shot voices; beyond it a higher (or equal) priority steals the oldest lowest
	MAX_VOICES_TOUCH = 16, -- phones and tablets without a keyboard
	DEFAULT_COOLDOWN = 0.03, -- per cue: twenty plates in one frame are one sound, not a phasey stack
	DEFAULT_MAX_PER_CUE = 4,
	DEFAULT_PRIORITY = 2, -- 1 (far ambience spot) .. 5 (busted, alarm)
	DEFAULT_PITCH_JITTER = 0.04, -- +-4 % PlaybackSpeed on repeated sounds; tonal stings set 0
	DEFAULT_VOLUME_JITTER = 0.08, -- +-8 % (about +-0.7 dB)
	UNLOADED_SECONDS = 2, -- a voice whose asset has not loaded counts as busy this long
	-- Positional rolloff presets (studs): full volume inside min, silent at max.
	ROLLOFF = {
		near = { min = 4, max = 45 }, -- steps, beeps, laser hum
		mid = { min = 8, max = 90 }, -- plates, doors, grabs, zaps
		far = { min = 20, max = 250 }, -- van horn and engine
	},

	-- Music (§7.2 "Crew Layers")
	-- "mixes": library tracks with same-length alternate mixes (the S4 fallback, applied to mixes): every mix of
	--   the set starts together and the tier picks which one is heard (crossfade).
	-- "stems": commissioned stems (D10): S0 always on, each tier adds its stem on top (additive).
	MUSIC_MODE = "mixes",
	-- "scheduled": every player of a set starts on the same sample with AudioPlayer:Play(atTime) on
	--   SoundService:GetMixerTime() (the S4 primary method). "together": plain Play() in one frame (the S4
	--   fallback; also used automatically when GetMixerTime is unavailable).
	STEM_START = "scheduled",
	SCHEDULE_LEAD = 0.1, -- seconds ahead of the mixer clock that a scheduled start is placed
	LAYER_THRESHOLDS = { 1, 3, 6, 10 }, -- clones for tiers S1..S4 (S0 = none)
	LAYER_FADE = 1.875, -- one bar at 128 BPM
	STATE_FADE = 2.0, -- crossfade between music states (garage -> heist, heist -> results)
	ALARM_FADE = 0.4, -- heist -> chase when the alarm goes off: it goes loud, fast
	JOIN_FADE_IN = 2.5, -- the first sound of a session is never a full-volume downbeat
	MUSIC_BPM = 128, -- the commissioned grid (30 s = 16 bars); library sets carry their own bpm or none
	CHRISTMAS = { from = { 2026, 12, 3 }, to = { 2027, 1, 4 } }, -- UTC days, inclusive: Christmas mixes

	-- Rewind (§7.1)
	TAPE_STOP_SPEED = 0.25, -- music PlaybackSpeed dive 1.0 -> 0.25 ...
	TAPE_STOP_SECONDS = 0.3, -- ... over 0.3 s, then the music stops until GO
	REWIND_DUCK_DB = -9, -- Ambience and Clone buses under the rewind transition
	REWIND_DUCK_RELEASE = 0.4,

	-- Ducking (feel.md D5): music ducks 4 dB for 0.6 s on caught, "!", diamond and complete.
	DUCK_DB = -4,
	DUCK_SECONDS = 0.6,
	DUCK_ATTACK = 0.05,
	DUCK_RELEASE = 0.25,

	-- Tonal ladders (semitones) for cues played with opts.step
	ARPEGGIO_STEPS = { 0, 2, 4, 7, 9, 12, 14, 16 }, -- C D E G A c d e: the clone arpeggio, the sound logo
	ARPEGGIO_STAGGER = Config.Heist.CLONE_SPAWN_STAGGER, -- 60 ms apart, like the tape print
	ARPEGGIO_MAX_STAGGER = 0.4, -- the whole arpeggio never spreads wider than this
	COUNTDOWN_STEPS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10 }, -- last 10 s: ticks rise; the last one jumps
	COUNT_UP_STEPS = { 0, 1, 2, 3, 4, 5, 7 }, -- bank count-up ticks rise 4-7 semitones

	-- View-driven timing (docs/AUDIO.md "Call sites")
	COUNTDOWN_FROM = 10, -- seconds left when the countdown ticks start (one per second)
	HEARTBEAT_FROM = 3, -- seconds left when the heartbeat joins
	GUS_STEP_STRIDE = 3.2, -- studs Gus walks per footstep (chase strides are longer: same stride, faster)
	GUS_RADIO_SECONDS = { 6, 14 }, -- random gap between radio blips while he patrols
	MEDAL_STAMP_GAP = 0.25, -- results card: Haul, Crew, Clean stamp 0.25 s apart ...
	MEDAL_PITCH_STEP = 0.06, -- ... each stamp a little higher

	-- First-impression cues preloaded at boot (lihfolk-sfx: the first hit must not be late)
	PRELOAD = { "RewindClack", "TapeStop", "RewindWhirr", "RewindClunk", "RunStamp", "CloneChime", "UIClick" },
}

return Config
