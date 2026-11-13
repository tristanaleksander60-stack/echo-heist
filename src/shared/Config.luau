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
	-- run 1 on someone's FIRST visit to a story / party level (never L1, never a daily vault, Help.firstRunIntro):
	-- this much longer, so Heist/LevelIntro shows every plate -> door pair (L2's five stops at full hops). Wall
	-- clock only: the run clock starts later, the sim's ticks are the same (tests/sim/FirstVisitIntro.spec.luau).
	FIRST_VISIT_INTRO_EXTRA = 2.0,
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
	-- Clone visibility (PLAN_STEAM_PLUS §1 S1, §4.4 A1): never invisible by design.
	CLONE_FILL_TRANSPARENCY = 0.55, -- owner Highlight fill in the crew hue (your own clones keep it at every tier)
	CLONE_MIN_JOINTS = 15, -- an avatar template with fewer whole joints (R15 has 15) draws as the mannequin
	CLONE_HEALTH_INTERVAL = 1, -- s between CloneHealth checks of the drawn avatar rigs
	CLONE_HEALTH_MAX_LIMB = 10, -- a part farther than this from its root (studs, x rig scale) = broken rig
	CLONE_KEEP_TEXTURES = true, -- keep face decals and mesh textures (shared per asset: cheap)
	CLONE_KEEP_CLOTHING = true, -- keep classic Shirt / Pants / T-shirt (composited once per rig)
	CLONE_KEEP_SURFACE_APPEARANCE = false, -- PBR maps: per-pixel cost x 28 figures on phones; hides the tint
	DEBUG_CHIP_HZ = 2, -- Studio-only clone diagnostic chip refresh rate
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
	UI_TEXT_MIN = 16, -- px at 1x: text that shrinks to fit stops here (16 x 0.9 = 14.4 px, §7.4 ">= 14 px")
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
	LINEUP_CAM_FIT_WIDTH = 0.32, -- the row fills at most this share of the frame width (9:16-safe, CAMERA.LINEUP)
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

-- Camera track (PLAN_STEAM_PLUS §4.2 C0, C1, C5; docs/audit/POLISH.md §4.5; docs/GOLDEN_FRAMES.md).
-- Client Heist/CameraDirector (engine) + Heist/CameraMath (pure, Lune-tested). Angles in degrees,
-- distances in studs, times in seconds. The player's pick persists as the choice setting `cameraMode`
-- ("fp" | "diorama" | "classic", Data.SetSetting); an old profile's boolean `classicCamera` = true reads
-- as "classic" (PLAN_FIRST_PERSON FP).
Config.Heist.CAMERA = {
	DEFAULT_MODE = "fp", -- PLAN_FIRST_PERSON: first person by default; "diorama" | "classic" stay as options
	-- First person (PLAN_FIRST_PERSON FP; Heist/CameraDirector "fp", maths in Heist/FpMath): head-locked at the
	-- character's eyes, never rolls. Look: mouse lock on PC during play (free in menus and panels, where a
	-- right-drag looks), touch drag outside the thumbstick, the right stick. Bob and dip: off under reduced motion.
	FP = {
		FOV = 70, -- vertical degrees; the comfort slider (setting fpFov, Config.Data.SETTING_NUMBERS) wins
		PITCH_MIN = -80, -- degrees down (negative = looking up)
		PITCH_MAX = 80,
		START_PITCH = 6, -- degrees down at a run start (a slight look at the floor ahead)
		EYE_UP = 0.15, -- studs above the head's centre
		EYE_FORWARD = 0.25, -- studs ahead of it (the face, not the middle of the skull)
		EYE_FOLLOW_RATE = 18, -- 1/s: exponential follow of the head height (smooths the walk clip's head bob)
		HEAD_DY_FALLBACK = 1.5, -- studs from the root to the head's centre when there is no Head
		MOUSE_DEG_PER_PX = 0.22, -- degrees per mouse pixel at Roblox's mouse sensitivity 1
		TOUCH_YAW_PER_SCREEN = 200, -- degrees for a drag across the whole screen width
		TOUCH_PITCH_PER_SCREEN = 110,
		PAD_YAW_RATE = 190, -- degrees a second at full right stick
		PAD_PITCH_RATE = 120,
		PAD_DEADZONE = 0.15,
		PAD_EXPONENT = 1.6, -- stick response curve (precise near the centre, fast at the edge)
		FACE_EPS = 0.5, -- degrees: the character turns to the look yaw when it differs by more
		HIDE_BODY_WITHIN = 1.6, -- studs: your own body is hidden while the camera is this close to your eyes
		HIDE_RESCAN_SECONDS = 0.5, -- the hidden body is rescanned this often (late accessories)
		-- Head bob (one cycle = two steps) and the landing dip (FpMath.bobStep / FpMath.spring).
		BOB = {
			STRIDE = 2.4, -- studs per step
			FULL_SPEED = 16, -- studs/s that count as a full walk (the default WalkSpeed)
			Y = 0.08, -- studs up and down at full speed
			X = 0.045, -- studs side to side (half the rate)
			SETTLE_RATE = 8, -- 1/s: the amplitude follows the speed
		},
		LAND = {
			MIN_FALL = 12, -- studs/s: a landing slower than this does not dip
			PER_SPEED = 0.025, -- studs of dip per stud/s of fall beyond MIN_FALL (about: FpMath.landKick)
			MAX = 0.4, -- studs: the deepest dip (about)
			FREQ = 6, -- spring frequency (Hz)
			DAMPING = 0.75, -- spring damping ratio (< 1: one soft overshoot)
		},
		-- C1 in first person: hold on the objective from above (this orbit), then ease into your eyes.
		BEAT_PITCH = 40,
		BEAT_DISTANCE = 22,
		BEAT_FOV = 50,
		GLANCE_DOWN = 9, -- degrees: the plate "stomp" glance (eases in and back; reduced motion: none)
		GLANCE_SECONDS = 0.45,
	},
	-- C0 "diorama": the long lens that makes the town read as a miniature and shows your crew.
	DIORAMA = {
		-- Tuned inside the plan's bands on the L1 spawn (tests/unit/HeistCamera.spec.luau): at 52 / 30 / 45
		-- the shop front's top clears plate A's near edge by about 2 studs and the clone on it stays in frame
		-- (50 / 28 / 42 left the plate's near half behind the wall top).
		PITCH = 52, -- degrees down (design band 45-55)
		PITCH_MIN = 35, -- never flatter: the walls must not hide the room
		PITCH_MAX = 65,
		DISTANCE = 30, -- studs from the focus (design band 26-32)
		ZOOM_MIN = 20, -- zoom limits (wheel, pinch, I / O keys)
		ZOOM_MAX = 40,
		FOV = 45, -- vertical, degrees (design band 40-45)
		SUBJECT_SCREEN_Y = -0.35, -- you sit in the lower third: normalised height below the centre (-1..1)
		FOCUS_HEIGHT = 1.5, -- studs above the HumanoidRootPart
		FOLLOW_RATE = 14, -- 1/s: exponential follow of the focus (frame-rate independent)
		SNAP_DISTANCE = 20, -- studs: a teleport this far snaps instead of gliding
		YAW_PER_SCREEN = 240, -- degrees of yaw for a drag across the whole screen width (touch, right mouse)
		PITCH_PER_SCREEN = 90, -- degrees of pitch for a drag over the whole screen height
		WHEEL_STEP = 0.12, -- share of the distance per wheel notch
		KEY_ZOOM_RATE = 1.2, -- share of the distance per second while I / O is held
		PAD_YAW_RATE = 150, -- degrees a second at full right stick
		PAD_PITCH_RATE = 70,
		PAD_DEADZONE = 0.2,
		THUMBSTICK_MARGIN = 24, -- px around the touch thumbstick frame that never rotates the camera
	},
	-- "classic": today's Roblox follow cam, constrained (POLISH §4.5 rule 1).
	CLASSIC = {
		FOV = 70,
		ZOOM_MIN = 8,
		ZOOM = 16,
		ZOOM_MAX = 28,
		PITCH = 25, -- the run-start beat ends behind you at this pitch, then the default camera takes over
	},
	-- Both modes: walls between the camera and you fade (POLISH §4.5 rule 1, vault "Camera Obstruction").
	FADE = {
		HZ = 10, -- obstruction checks a second (Camera:GetPartsObscuringTarget)
		ALPHA = 0.7, -- LocalTransparencyModifier of a faded wall
		IN_SECONDS = 0.1, -- fade out of the way within this
		OUT_SECONDS = 0.25, -- and come back over this once clear
		INVISIBLE = 0.95, -- parts at least this transparent are colliders, never faded
		POINTS = { 2.4, 0, -1.8 }, -- studs above the root: head, root, feet (three cast points: no flicker)
	},
	-- C1: the run-start framing beat (eases from the objective to you; any input skips it). It
	-- always ends when the transition ends (control returns), so it never delays first control.
	BEAT_SECONDS = 0.8,
	FOV_KICK_MAX = 6, -- POLISH §4.5 rule 8: FOV kicks stay within +-6 degrees
	-- C5: the Line-up shot keeps every figure inside the central 32 % of the frame width
	-- (9:16-safe, premium H3) and searches for a clear lane: straight on first, then higher.
	LINEUP = {
		CENTRAL_SHARE = 0.32,
		ROW_GAP = 7, -- studs: a row inside the van body slides this far clear of it, onto the pavement by the shop front
		HEIGHTS = { 2.4, 6, 10, 14, 18, 22, 26, 30, 34, 38 }, -- camera heights tried, lowest first (high = over the van)
		YAWS = { 0, 18, -18 }, -- degrees off the row's facing tried at each height
		MAX_DISTANCE = 60, -- studs
		MAX_PITCH = 42, -- degrees down at most (a crane over the van stands back rather than looking straight down)
		FIGURE_HALF_WIDTH = 1.25,
	},
	-- Golden-frame staging (Studio only, workspace attribute EH_Scenario; docs/GOLDEN_FRAMES.md "Capture";
	-- re-specced for first person and the Rookie, REVIEW_STEAM_PLUS #4). G1 / G3 are first person: Heist/GoldenShots
	-- turns your look (yaw toward the target, PITCH degrees down: negative looks up) once the camera is in your eyes.
	GOLDEN = {
		-- L1 from the street: spawn 1 stands 3.5 studs from the shop's door (the doorway fills the eyes), so the
		-- staging walks you back past the van onto the street (STAND x, z, level space), turns you toward the cash
		-- glinting through the shop's windows and tilts you up for the tall tenement and a strip of aurora
		G1 = { STAND = { -10, 28 }, LOOT = "Cash", PITCH = -18, YAW_OFFSET = 0, FOV = 70 },
		G2 = { PITCH = 45, FOV = 45, YAW = 0, MAX_DISTANCE = 70 },
		-- the hideout: you stand in the aisle at the vans (STAND x, z) and look between the job board and your van
		G3 = { STAND = { 22, -10 }, LOOK_AT = { 19, 4.2, -21 }, PITCH = -4, FOV = 70 },
	},
}

-- First person: hands, look-to-interact, the reduced HUD and Gus's screen-edge warning (PLAN_FIRST_PERSON FP).
-- Client only, nothing here decides gameplay (the server and the sim still do). The camera's own numbers are
-- Config.Heist.CAMERA.FP. Hand poses are camera space at full size (x right, y up, z forward is negative),
-- studs and degrees (rx pitch, ry yaw, rz roll), before VIEWMODEL.SCALE.
Config.FirstPerson = {
	VIEWMODEL = {
		-- Drawn at this size and this much closer to the eye: it looks the same, but sticks out only this share as
		-- far, so it stays inside the character's own collision (vault "First-Person Viewmodels" §3, rule 1).
		SCALE = 0.4,
		FOV_REF = 70, -- the poses are authored at this FOV; x / y follow tan(fov / 2) so hands keep their screen spot
		KIT = "CharacterKit", -- ReplicatedStorage folder the CHARACTER track publishes
		KIT_MODEL = "Rookie_Viewmodel", -- forearms + gloved hands with GripR / GripL attachments
		KIT_CHECK_SECONDS = 2, -- the placeholder hands are swapped for the kit model once it arrives
		-- Kit arms in your outfit (Viewmodel.fromOutfit): Breton stripes down the sleeve, as shares of the elbow ->
		-- wrist line, their width and radii (just over the sleeve's 0.27 -> 0.25 studs).
		SLEEVE_STRIPES = { 0.3, 0.56 },
		STRIPE_WIDTH = 0.09,
		STRIPE_RADIUS = { 0.29, 0.283 },
		-- The placeholder hands (until the kit model lands): Palette keys; the stripe is your crew hue.
		COLOURS = {
			glove = "plumHi",
			knuckle = "steel",
			cuff = "ink",
			sleeve = "plum",
			watch = "goldHi",
			band = "goldLo",
		},
		REST = {
			R = { 0.6, -0.62, -1.2, 10, -12, -8 },
			L = { -0.6, -0.62, -1.2, 10, 12, 8 },
		},
		-- One pose per action; `hands` = which hands it moves. Envelope (s): rise, hold, fall (ViewmodelMath.envelope).
		ACTIONS = {
			reach = {
				R = { 0.22, -0.32, -1.85, -12, -4, -18 },
				L = { -0.62, -0.7, -1.15, 14, 12, 8 },
				time = { 0.12, 0.1, 0.28 },
			},
			push = { R = { 0.32, -0.22, -1.7, -78, -6, 0 }, time = { 0.1, 0.18, 0.32 } },
			press = { R = { 0.18, -0.24, -1.75, -24, -2, -6 }, time = { 0.1, 0.12, 0.25 } },
			stomp = {
				R = { 0.78, -0.74, -1.1, 4, -24, -26 },
				L = { -0.78, -0.74, -1.1, 4, 24, 26 },
				time = { 0.08, 0.12, 0.3 },
			},
			-- REWIND: the left wrist comes up into view and the right index taps the watch.
			watch = {
				R = { 0.08, -0.36, -1.08, 14, -34, -22 },
				L = { -0.14, -0.44, -1.04, 42, 58, 78 },
				time = { 0.14, 0.4, 0.3 },
				tap = { 0.05, 6, 0.5 }, -- studs of tap travel, taps a second, share of the travel that goes down
			},
			handsUp = {
				R = { 0.72, 0.22, -1.1, 78, -6, -12 },
				L = { -0.72, 0.22, -1.1, 78, 6, 12 },
				time = { 0.15, 1.3, 0.45 },
			},
		},
		CARRY = {
			R = { 0.4, -0.5, -1.3, 0, 22, -72 },
			L = { -0.4, -0.5, -1.3, 0, -22, 72 },
			LOOT = { 0, -0.36, -1.45 }, -- where the held loot sits (full size, camera space)
			LOOT_SIZE = 0.95, -- full-size studs the held loot's longest side is scaled to
			BLEND_SECONDS = 0.18,
		},
		HIDDEN = { 0, -0.2, 0.12 }, -- added to both hands while you hide (a crouch-like lower)
		HIDDEN_SECONDS = 0.25,
		-- Motion.
		IDLE = { x = 0.008, y = 0.012, hzX = 0.13, hzY = 0.25 }, -- breathing sway (studs, Hz)
		WALK = { x = 0.03, y = 0.035, rz = 2.5 }, -- walk bob at full speed (studs, degrees), synced to the head bob
		LAG = {
			PER_DEG_S = 0.0011, -- studs of lag per degree a second of look speed
			ROLL_PER_DEG_S = 0.018, -- degrees of roll per degree a second
			MAX = 0.16, -- studs
			MAX_ROLL = 7, -- degrees
			FREQ = 4.5, -- spring (Hz)
			DAMPING = 0.55, -- < 1: a small overshoot when you stop turning
		},
		-- Wall push: a ray from the eye; a wall closer than RANGE pulls the hands back and down (studs at
		-- world size, i.e. already scaled; PULL is full-size camera space at a wall touching the eye).
		WALL = { RANGE = 1.4, PULL = { 0, -0.22, 0.4 }, RATE = 14 },
		-- The push and the plate glance: a door this close in front (studs), and a cooldown (s).
		PUSH_RANGE = 3.2,
		PUSH_CONE = 50, -- degrees off the look
		PUSH_COOLDOWN = 1.5,
		REACH_DEDUPE = 0.4, -- s: your Grab event does not replay the reach the GRAB press just played
		-- Finger poses (REVIEW_STEAM_PLUS #10): the kit gloves (Rookie_Hands: palm + index, finger block and thumb in
		-- two hinged segments each) or the placeholder's fingers turn about their hinges. Per joint { curl, across }
		-- in degrees: curl folds toward the palm (- bends back), across swings the thumb over the palm. The hands
		-- blend like the arms (rest, carry, then each action by its envelope, then the look-cue point) and every
		-- joint follows its target through a spring (ViewmodelMath.fingers, Heist/Viewmodel).
		HANDS = {
			FREQ = 9, -- spring Hz
			DAMPING = 0.8,
			POSES = {
				open = { -- relaxed: a soft curl, the thumb loose
					Index1 = { 14, 0 },
					Index2 = { 12, 0 },
					Fingers1 = { 22, 0 },
					Fingers2 = { 18, 0 },
					Thumb1 = { 8, 12 },
					Thumb2 = { 8, 0 },
				},
				reach = { -- spread wide as the hand goes for the loot
					Index1 = { -6, 0 },
					Index2 = { 2, 0 },
					Fingers1 = { -4, 0 },
					Fingers2 = { 4, 0 },
					Thumb1 = { -10, -20 },
					Thumb2 = { 0, 0 },
				},
				grip = { -- holding the loot: wrapped round it
					Index1 = { 74, 0 },
					Index2 = { 66, 0 },
					Fingers1 = { 80, 0 },
					Fingers2 = { 72, 0 },
					Thumb1 = { 30, 40 },
					Thumb2 = { 30, 0 },
				},
				push = { -- a flat palm on the door, fingers a touch bent back
					Index1 = { -8, 0 },
					Index2 = { -4, 0 },
					Fingers1 = { -8, 0 },
					Fingers2 = { -4, 0 },
					Thumb1 = { 0, -8 },
					Thumb2 = { 0, 0 },
				},
				point = { -- the index straight out, the rest folded, the thumb over them
					Index1 = { -4, 0 },
					Index2 = { 0, 0 },
					Fingers1 = { 86, 0 },
					Fingers2 = { 82, 0 },
					Thumb1 = { 32, 44 },
					Thumb2 = { 30, 0 },
				},
				press = { -- the index presses (the REWIND watch tap, a switch): its tip bent onto the button
					Index1 = { 16, 0 },
					Index2 = { 24, 0 },
					Fingers1 = { 86, 0 },
					Fingers2 = { 82, 0 },
					Thumb1 = { 32, 44 },
					Thumb2 = { 30, 0 },
				},
				handsUp = { -- caught: fingers splayed
					Index1 = { -10, 0 },
					Index2 = { -4, 0 },
					Fingers1 = { -10, 0 },
					Fingers2 = { -6, 0 },
					Thumb1 = { -14, -26 },
					Thumb2 = { -4, 0 },
				},
			},
			ORDER = { "open", "reach", "grip", "push", "point", "press", "handsUp" }, -- renders and tests
			REST = "open",
			CARRY = "grip",
			-- What each arm action does with the fingers, per hand (R / L).
			ACTIONS = {
				reach = { R = "reach" },
				push = { R = "push" },
				press = { R = "press" },
				stomp = { R = "open", L = "open" },
				watch = { R = "press", L = "push" }, -- the left wrist flat to show the watch, the right index taps
				handsUp = { R = "handsUp", L = "handsUp" },
			},
			POINT = "point", -- while the onboarding look cue shows (state.fpPointing), the right hand points
			POINT_BLEND = 0.25, -- s
		},
	},
	LOOK = {
		-- A ray from the camera centre picks what you look at (FpMath.pick). REACH: studs from the eye to the
		-- target; the server's own range (Config.Sim.INTERACT_RANGE from your sim position) is checked too, less
		-- RANGE_MARGIN, so a target shown is a target the server accepts.
		REACH = 8,
		RANGE_MARGIN = 0.3,
		-- Aim assist: degrees beyond the target's own size that still count (touch most, the mouse least).
		ASSIST = { mouse = 2.5, gamepad = 6, touch = 8 },
		STICKY = 0.35, -- score bonus that keeps the current target against a near tie (no flicker)
		DISTANCE_WEIGHT = 0.25, -- score per REACH of distance (nearer wins a tie)
		LOS_CANDIDATES = 3, -- line-of-sight rays a frame, for the best few only
		RADIUS = { loot = 0.9, switch = 0.8, van = 3.5 }, -- studs; loot uses its part's size when bigger
		LOS_SLACK = 0.6, -- studs: a hit this close to the target's surface is the target
		BANK_REACH = 16, -- the van shows BANK (walk in) from this far while you carry
		HIGHLIGHT = { FILL = 0.85, OUTLINE = 0, COLOUR = "gold", LOCKED = "steel" },
		CLICK_GUARD = 0.25, -- s: a mouse click this soon after the cursor locks is not a grab
	},
	HUD = {
		RETICLE = 8, -- px: the dot
		RETICLE_RING = 26, -- px: the ring round it while a target is under it
		RETICLE_ALPHA = 0.25,
		LOOT_PEEK_SECONDS = 4, -- the loot meter shows this long after it changes (and while you carry)
		KEY_CAP_WIDE = 44, -- px: the prompt chip's key cap for a word ("TAP" on touch); a letter's is square
	},
	-- Gus in first person: a screen-edge tint while his cone is on you ("?", stage 1) or he is sure ("!",
	-- stage 2), strongest on the side he is on. A steady tint, not a flash: only its "!" pulse asks the flash
	-- limiter (Heist/FlashLimit). Reduced motion: the tint without the pulse.
	WARN = {
		EDGE = 0.2, -- share of the screen width / height each edge gradient covers
		SEEN = 0.55, -- edge strength 0..1 at "?"
		SURE = 0.9, -- ... at "!"
		SIDE_MIN = 0.35, -- the far side keeps this share (a cone on you is always felt)
		IN_SECONDS = 0.2,
		OUT_SECONDS = 0.45,
		PULSE = 0.35, -- extra strength of the "!" pulse
		PULSE_SECONDS = 0.35,
		COLOURS = { seen = "amber", sure = "alarm" },
	},
}

-- Gus on his mesh (PLAN_STEAM_PLUS §4.4 A4-A5, STYLE_BIBLE §12, roblox_quality §4.2-4.3, POLISH §4.3,
-- premium C1/C3/C4/C5/C6). Client only: the rig (Heist/GusRig), the acting beats (Shared/Heist/GusBeats)
-- and his intention cues (boot prints, cone flicker, nameplate) in Heist/GusView. Angles in degrees.
Config.Gus = {
	-- The kit's Gus model replicated by the server (Heist/GusTemplate) for the client rig; the box rig
	-- stands in until it arrives (checked again every UPGRADE_CHECK_SECONDS).
	TEMPLATE_FOLDER = "HeistGusKit",
	UPGRADE_CHECK_SECONDS = 1,
	MAX_MESH = 2, -- mesh rigs per view (MASTERPLAN §6.8: <= 2 Gus per view); extra guards use the box rig
	-- Walk (FK, phase by distance walked): cycle = two strides.
	WALK_STRIDE = 2.6, -- studs per step (POLISH §4.3)
	WALK_SPEED = 8, -- studs/s that count as a full walk (Config.Sim.GUARD_SPEED)
	HIP_SWING = 28,
	KNEE_LIFT = 40,
	ARM_SWING = 18,
	ELBOW = 18,
	BOB = 0.12, -- studs, two dips per cycle
	TWIST = 4, -- torso counter-yaw
	LEAN = 4,
	TORCH_ARM_SWING = 6, -- the torch arm stays forward
	-- The funny sprint (chase): high knees, pumping arms, a waddle roll, a big lean.
	RUN_STRIDE = 3.5,
	RUN_SPEED = 14,
	RUN_HIP_SWING = 42,
	RUN_KNEE_LIFT = 85,
	RUN_ARM_SWING = 55,
	RUN_ELBOW = 80,
	RUN_BOB = 0.3,
	RUN_LEAN = 18,
	RUN_WADDLE = 7, -- side-to-side roll
	RUN_HEAD_BOB = 8, -- neck pitch per step
	-- Secondary motion (C5): torch sway, head/moustache and cap lag behind the step bob.
	TORCH_SWAY = 4,
	TORCH_SWAY_HZ = 0.5,
	MOUSTACHE_BOUNCE = 3, -- neck pitch, lagging the bob (the moustache is part of Gus_Head)
	MOUSTACHE_LAG = 0.9, -- radians of phase lag behind the step
	CAP_BOUNCE = 0.06, -- studs
	BREATH = 0.03, -- studs of chest rise when he stands
	BREATH_HZ = 0.25,
	IDLE_LOOK = 6, -- head yaw drift while he stands
	-- Look (C4, roblox_quality §4.3): the head leads the body; clamped, loses interest behind.
	HEAD_LEAD = 0.2, -- seconds (0.15-0.25)
	LOOK_YAW_MAX = 70,
	LOOK_PITCH_MAX = 40,
	LOOK_LOSE = 30, -- hysteresis past LOOK_YAW_MAX before the head gives up
	NECK_SHARE = 0.7, -- of the look on the neck (the rest on the waist)
	HEAD_SMOOTH = 0.06, -- seconds, head yaw time constant
	BODY_SMOOTH = 0.1, -- seconds, body yaw time constant off patrol
	BLEND = 0.12, -- seconds between beats (per-joint blend)
	-- Beats (C1: every change starts with >= 66 ms of anticipation).
	ANTICIPATION = 0.1,
	DOZE_NOD_SECONDS = 4,
	WAKE_SECONDS = 0.7,
	DOUBLE_TAKE_FOLLOW = 0.75, -- the body starts to follow the head this long into the "?"
	POINT_SECONDS = 0.5, -- "!" point before the sprint
	CATCH_SECONDS = 0.8,
	WRONG_ONE_SECONDS = 2.0, -- the "huh?" freeze (Config.Sim.GUARD_HUH_SECONDS)
	SCRATCH_SECONDS = 1.0, -- lost sight: a short head scratch, then back to the round
	BANG_SECONDS = 1.2, -- the "!" bubble after a catch or the chase start
	-- Boot prints (A5, premium §6.3): his next HORIZON seconds of patrol, one print per stride.
	PRINT_HORIZON = 2,
	PRINT_STRIDE = 2.6,
	PRINT_MAX = 5,
	PRINT_HZ = 10,
	PRINT_SPREAD = 0.35, -- studs left/right of the path
	PRINT_SIZE = { 0.55, 1.0 }, -- studs (width, length)
	PRINT_RIM = 0.12, -- studs of ink rim around the light print (reads on lit and dark floors)
	PRINT_TRANSPARENCY = { 0.15, 0.8 }, -- nearest, farthest
	-- The cone flickers before he turns (A5).
	FLICKER_LEAD = 0.5,
	FLICKER_TURN_DEG = 20,
	FLICKER_HZ = 10,
	FLICKER_DEPTH = 0.18, -- extra transparency on the off beats
	-- "GUS" nameplate the first time he is on screen.
	NAMEPLATE_SECONDS = 3,
	NAMEPLATE_DISTANCE = 90,
	BUBBLE_POP = 1.3,
	-- Sound (docs/AUDIO.md "Gus"): key ring every KEYS_STEPS steps while he walks.
	KEYS_STEPS = 2,
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

	-- Number settings (Schema settings, Data.SetSetting): key -> { min, max }. Every other setting is a boolean
	-- or a choice (SETTING_CHOICES).
	-- A stored value outside its range (or of the wrong type) is repaired to the default (Schema.sanitize).
	SETTING_NUMBERS = {
		musicVolume = { 0, 1 }, -- U7 settings: the Music bus slider
		sfxVolume = { 0, 1 }, -- ... and the SFX slider (SFX, UI and Ambience buses)
		fpFov = { 60, 90 }, -- first-person field of view, degrees (the comfort slider; default FP_FOV_DEFAULT)
	},
	-- Defaults of number settings that are not 1 (Schema.defaultSettings).
	SETTING_NUMBER_DEFAULTS = { fpFov = 70 },
	-- Choice settings: key -> the allowed strings, the first is the default. cameraMode (PLAN_FIRST_PERSON FP)
	-- replaces the old boolean classicCamera additively: Schema.sanitize reads classicCamera = true as "classic"
	-- when a profile has no cameraMode yet.
	SETTING_CHOICES = {
		cameraMode = { "fp", "diorama", "classic" },
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
		-- step back up (hysteresis): this many good seconds in a row (at most STEP_UP_SHARE slow frames
		-- each) raise the tier one step; each step up doubles the wait for the next (no oscillation)
		STEP_UP_SECONDS = 60,
		STEP_UP_SHARE = 0.01,
		STEP_UP_BACKOFF = 2,
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
-- Sky uses the plain night faces (assets/sky/EH_SkyNight_*.png from tools/blender/sky_faces.py, uploaded
-- as Decals 2026-11-12, image ids in every project file's Sky node); the city cubemap is phase 2.
-- Lamps: Heist/KitPlan.lamps (one over each plate, a hero over the goal, room centres from Heist/LevelDress),
-- built by Heist/LevelBuilder (light + unlit floor pool) and dressed with Lamp_Ceiling by Heist/KitDresser.
Config.Lighting = {
	-- Per lamp kind: PointLight (room, plate) or a downward SpotLight (hero, the only shadowed one).
	LAMP = {
		-- room: the warm interior flood (golden-frame pass: brighter, wider, a bigger softer pool than the signals')
		room = {
			range = 24,
			brightness = 1.6,
			color = { 255, 205, 150 },
			shadows = false,
			pool = 20,
			poolRings = {
				{ size = 1, alpha = 0.88 },
				{ size = 0.8, alpha = 0.84 },
				{ size = 0.6, alpha = 0.8 },
				{ size = 0.4, alpha = 0.76 },
			},
		},
		plate = { range = 18, brightness = 1.3, color = { 255, 205, 150 }, shadows = false },
		-- accent: a warm gold flood that ignores the location colour (LevelDress `accents`: the L6 vault, so the gold
		-- room reads warm and lit from the scale room, LEVELS L6 "lit vault and gold")
		accent = {
			range = 20,
			brightness = 1.5,
			color = { 255, 206, 128 },
			shadows = false,
			pool = 14,
			poolColor = { 246, 204, 132 },
			poolRings = { { size = 1, alpha = 0.86 }, { size = 0.66, alpha = 0.8 }, { size = 0.36, alpha = 0.76 } },
		},
		hero = { range = 36, brightness = 3, angle = 60, color = { 255, 214, 160 }, shadows = true },
		-- wash (INTERIORS, KitPlan.lamps): a warm SpotLight near the ceiling aimed down a wall, so the walls carry
		-- the room's light in first person instead of the ceiling (no shadows, no pool, no fixture; tier 1 only)
		wash = {
			range = 20,
			brightness = 1.8,
			angle = 100,
			color = { 255, 200, 150 },
			shadows = false,
			pool = 0,
			lightY = 10.6, -- over the floor, under the ceiling (12)
			off = 1.6, -- studs out from the kit wall face
			tilt = 40, -- degrees below horizontal, toward the wall
		},
		-- Golden-frame warm pass (GOLDEN_FRAMES G1, PLAN_STEAM_PLUS §3.1): street lamps (LevelDress `street`) on the
		-- pavement: a warm PointLight at the StreetLamp lantern (lightY / bulbY: the manifest light point) that
		-- washes the shop front and the snow, and a bigger, denser warm pool (pool / poolRings / poolColor).
		street = {
			range = 22,
			brightness = 1.6,
			color = { 255, 182, 110 },
			shadows = false,
			lightY = 9.43,
			bulbY = 9.43,
			pool = 24,
			poolColor = { 246, 186, 120 },
			poolRings = { -- five soft steps (three read as a bullseye at this size)
				{ size = 1, alpha = 0.86 },
				{ size = 0.84, alpha = 0.84 },
				{ size = 0.68, alpha = 0.82 },
				{ size = 0.52, alpha = 0.8 },
				{ size = 0.36, alpha = 0.8 },
			},
		},
	},
	RUG_LIFT = 0.021, -- studs: rugs (0.036 thick) sit over the kit floor tiles (+0.02) and under the lamp pools (+0.06)
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
	-- Each location's dominant light colour (PLAN_STEAM_PLUS §3.1, W5): ROOM lamps take it, in turn when a
	-- location has two (KitPlan.lampLook), and their floor pools take `pool`. Plate lamps (signals) and the hero
	-- lamp (the focal pool) keep LAMP's warm white everywhere, so a signal never changes colour by location.
	-- No new lights: the per-view budget below is unchanged.
	LOCATION = {
		CornerShop = { -- warm amber
			room = { { 255, 186, 112 } },
			pool = { 236, 196, 150 },
		},
		ToyShop = { -- candy pink and gold, alternating lamp by lamp
			room = { { 255, 168, 204 }, { 255, 206, 120 } },
			pool = { 240, 196, 210 },
		},
		Bank = { -- green banker's lamps: warm light through green glass
			room = { { 196, 236, 158 } },
			pool = { 206, 222, 176 },
		},
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

	-- The van (golden-frame pass: a Getaway White van was the brightest thing in G1 and filled the bottom of the
	-- classic frame): the kit body's Van_Paint takes this mid value (caramel, warm, far from loot gold and Alarm
	-- Red); the roof is the kit's dark Vault Steel shade; the Getaway White chevrons on its band stay the signal.
	VAN = {
		paint = { 140, 100, 72 }, -- #8C6448 (eh_palette.TINT_IDLE Van_Paint)
	},
	-- Van zone (LEVELS P0-6): dim until you carry loot, then lit with arrows that point at the van.
	VAN_IDLE_ALPHA = 0.92, -- golden-frame pass: dimmer than 0.85 (the zone was the frame bottom's brightest slab in G1a)
	VAN_CARRY_ALPHA = 0.6,
	ARROW_IDLE_ALPHA = 0.75,
	ARROW_COUNT = 3,
	ARROW_STEP = 2.4, -- studs between arrows along the zone
	ARROW_HEAD = { 2.4, 1.2 }, -- studs: head width, length
	ARROW_SHAFT = { 0.7, 1.0 }, -- studs: shaft width, length

	-- Soft light pools (levels-and-world-feedback track): the pools were drawn as 3-5 hard stepped discs. Now a
	-- smooth radial falloff: opacity(r) = peak * (1 - (r / R)^2)^exponent. In the engine an uploaded radial
	-- gradient image (assets/ui/EH_FX_Pool.png, alpha = (1 - u^2)^exponent; resolved at boot by Heist/UiImages)
	-- draws it in one ImageLabel; until the image resolves, `rings` thin discs approximate the same curve
	-- (KitPlan.poolRings). The peak is each kind's old area-weighted brightness x `gain`: peak = old mean opacity x
	-- (exponent + 1) x gain, capped at peakMax. A smooth edge alone lost warm share (G1a 47 -> 36 % with 1.5 and no
	-- gain), so the curve is gentler (exponent 1), a bit brighter (gain 1.2) and the room / street pools wider
	-- (LAMP.room / street `pool` 20 / 24): G1a 45 % with no stepped rings and no light through the shop front.
	POOL_SOFT = {
		image = "EH_FX_Pool", -- UiAssets stem; tools/ui/make_pool_fx.py EXPONENT must match `exponent`
		exponent = 1.0,
		gain = 1.2,
		rings = 10, -- fallback discs per pool
		peakMax = 0.85,
	},

	-- Hide spots (FEEDBACK_TABLE "Hide spot", LEVELS P1-2): a soft Warm Marble outline of the hide's footprint
	-- that fades in while your character is within `near` studs of it (WorldView), and the letter of a plate
	-- hidden inside a hide on a disc over the hide (L4 coat rack, L6 teller desk / fern / deposit stacks).
	HIDE_OUTLINE = {
		width = 0.22,
		lift = 0.07, -- over the pools (+0.06)
		near = 6,
		alpha = 0.25, -- shown transparency (1 = hidden)
		fadeSeconds = 0.25,
		color = { 216, 200, 168 }, -- Warm Marble #D8C8A8
	},
	HIDE_PLAQUE_Y = 1.1, -- studs over the hide's top: the letter disc of a plate inside it

	-- "Need all 4" (LEVELS P1-3, PLAN §7 "VAULT 2/4"): a row of lettered lamps on the face of every need-all door,
	-- toward its plates; each takes its presser's hue while its plate is held (WorldView, from the plate
	-- attributes), and a "VAULT n/4" count rides over the row. KitPlan.vaultRows places them.
	VAULT_ROW = {
		gap = 1.8, -- studs between lamp centres (the single door lamp keeps the middle)
		y = 11.1, -- above the floor (the door is 10 tall, the wall 12)
		size = 0.95, -- lamp disc diameter
		depth = 0.3,
		face = 0.35, -- studs proud of the wall band
		idleAlpha = 0.55, -- unheld: a dim Bulb Warm disc with its letter
		labelOffset = 1.7, -- the count's height over the row
		labelDistance = 90,
	},
}

-- World-side feedback (docs/FEEDBACK_TABLE.md, PLAN_STEAM_PLUS §4.5): what the client's Heist/WorldView adds on top
-- of the server's state (no sim changes; everything here is cosmetic and local). Springs are exact
-- (Shared/Heist/WorldFx.spring): `hz` is the natural frequency, `damping` the ratio (under 1 overshoots). Reduced
-- motion: no overshoot, no bounce, no squash, no shake; the state change itself always shows.
Config.WorldFx = {
	-- Plate: sinks Config.Heist.PLATE_SINK (0.15 studs) and settles with a ~0.1 s overshoot.
	PLATE_SPRING = { hz = 11, damping = 0.45 },
	-- Door: pocket leaves slide with a small overshoot (shutters and the vault skin keep their exact ease);
	-- a dust puff at the sill as it opens.
	DOOR_SPRING = { hz = 2.2, damping = 0.6 },
	DOOR_DUST = 10, -- particles per puff (x the tier's particle scale)
	DOOR_DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds",
	-- Laser: an ink sleeve around the red body and the white-hot core (LevelBuilder), so the beam reads on light
	-- floors too; the re-arm whine starts with the flicker (Config.Sim LASER_FLICKER_SECONDS + VISUAL_LEAD = 0.5 s).
	LASER_INK = { width = 0.42, alpha = 0.55 },
	-- Loot: a glint every 2 s (staggered per item), a tinkle within 8 studs, squash on grab, bounce on drop.
	GLINT_PERIOD = 2,
	GLINT_SIZE = 1.1,
	TINKLE_RANGE = 8,
	SQUASH = { amount = 0.32, hz = 5, damping = 0.4 }, -- scale Y down by `amount`, X/Z up by half of it
	BOUNCE = { height = 0.9, seconds = 0.55, hops = 2 }, -- a dropped item hops in place
	-- Your live character carries loot in both hands, in front of the chest (Config.Clone.CARRY_HANDS in your
	-- root's frame, the clones' carry point), playing the clones' uploaded carry clip on its arms.
	LIVE_CARRY_CLIP = true,
	-- The van bank moment (visual only; the HUD's "+$100 flies to the meter" hooks world.onBank)
	COINS = 24, -- the burst's particles (never more; x the tier's particle scale)
	COIN_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds",
	VAN_BOUNCE = { height = 0.5, hz = 3.2, damping = 0.35 },
	BANK_POP_SECONDS = 1.1,
	BANK_POP_RISE = 3.5, -- studs
	BANK_POP_SIZE = { 170, 56 }, -- px
	-- Haptics on the three key verbs (plate, grab, bank): phones only, off under reduced motion and when the
	-- player turned them off (player attribute Setting_Haptics == false; the Settings panel's Vibration toggle).
	HAPTICS = true,
	HAPTIC_TYPES = { plate = "GameplayCollision", grab = "UIClick", bank = "UINotification" },
	HAPTIC_MIN_GAP = 0.12, -- s between two pulses (<= 8 a second, vault "Haptics")
}

-- Garage v1 (PLAN_STEAM_PLUS §4.1 W6, docs/GOLDEN_FRAMES.md G3): the shared lobby every crew starts in, built from
-- the kit by server Heist/Lobby from the pure plan Heist/LobbyPlan (Lune-tested). Local space at
-- Config.Heist.LOBBY_ORIGIN, floor y = 0, -Z = the back wall with the roll-up door onto the snowy street. Visual
-- only: the garage's colliders are its own greybox walls, floor and van boxes (the kit pieces never collide).
Config.Lobby = {
	HALF_X = 44, -- interior half width (studs): 11 floor tiles of 8
	HALF_Z = 28, -- interior half depth: 7 floor tiles
	WALL_H = 12,
	WALL_T = 2, -- the wall band outside the interior (the kit wall body is 2 deep)
	STREET_DEPTH = 26, -- the street apron behind the back wall, under the half-open roll-up door
	DOOR_X = 0, -- the GarageDoor_16x12 in the back wall
	DOOR_W = 20, -- the big roll-up door onto the snowy yard (the warehouse: 20 wide, DOOR_H tall)
	DOOR_H = 18,
	-- 8 van bays, bay 1 first (GoldenShots G3 frames the part named "Van": bay 1's collider). Back row against the
	-- back wall (doors face +Z, the aisle), front row against the front wall (doors face -Z). x of each van. Your bay
	-- (1) stands right of the roll-up door with the trophy shelf and the job board between them, so the G3 camera
	-- (yaw 35: it looks left past your van) frames van, board, trophies and the door; the back right corner is free.
	BAYS = {
		{ row = "back", x = 26 },
		{ row = "front", x = 17.6 },
		{ row = "back", x = -18.5 },
		{ row = "back", x = -34 },
		{ row = "front", x = -17.6 },
		{ row = "front", x = 35.2 },
		{ row = "front", x = 0 },
		{ row = "front", x = -35.2 },
	},
	VAN_GAP = 1.5, -- studs between a van's back and its wall
	-- Each bay's van paint (Van_Paint): mid values. Bays 1-4 are the crew seats' families (P1 Cyan, P2 Magenta,
	-- P3 Indigo, P4 Ghost White, toned to a mid value: a van is never a glowing clone hue), 5 the heist van's caramel.
	BAY_PAINTS = {
		{ 62, 138, 150 },
		{ 168, 84, 140 },
		{ 100, 92, 176 },
		{ 128, 128, 150 },
		{ 140, 100, 72 },
		{ 104, 120, 70 },
		{ 120, 76, 110 },
		{ 84, 110, 140 },
	},
	-- Work lamps: one Lamp_Ceiling over each bay's door side; bay 1 (yours) is the shadowed key and the brightest,
	-- the neighbouring bays dimmer (GOLDEN G3). Pools: unlit SurfaceGui discs like the heist lamps.
	-- Work lamps: a Lamp_Ceiling between each van's back and its wall (a warm wash on the brick; from the aisle it never
	-- hangs over an open door). Your bay (1) adds the key: a shadowed SpotLight over the aisle in front of your van
	-- (y up, `out` toward the aisle, `along` the van), the brightest light in the garage; the other bays stay dimmer.
	LAMP_OFFSET = 4.6, -- studs from the van's centre toward its wall
	WORK_LAMP = { range = 20, brightness = 1.1, color = { 255, 192, 128 }, pool = 15, poolColor = { 236, 190, 140 } },
	YOUR_LAMP = {
		y = 10.5,
		out = 7,
		along = 1,
		range = 30,
		brightness = 1.7,
		angle = 80,
		color = { 255, 200, 140 },
		shadows = true,
		pool = 17,
		poolColor = { 226, 168, 112 },
	},
	-- the shelf lamp: over your first trophy, reaching the job board in front of the shelf (they share the light)
	TROPHY_LIGHT = { range = 13, brightness = 1.4, color = { 255, 210, 150 } },
	-- warm floods down the aisle between the rows (Lamp_Ceiling + pool): the garage reads lit from inside
	AISLE_LAMPS = { { -22, -6 }, { 0, -6 }, { 22, -6 } },
	AISLE_LAMP = { range = 28, brightness = 1.1, color = { 255, 190, 125 }, pool = 20, poolColor = { 232, 176, 116 } },
	-- Outside the door: a StreetLamp on the street apron (its warm pool on the snow, seen under the curtain).
	STREET_LAMP = { x = 6, z = -38 },
	-- The job board beside your van (bay 1), turned toward the aisle; the NEXT card on its slot. card = the JobBoard
	-- manifest `card` (centre in the board's local Roblox axes, size; the unit spec checks it against the manifest).
	BOARD = {
		x = 13.5,
		z = -19,
		yaw = -116,
		card = { centre = { -1.175, 4.525, -0.26 }, size = { 2.35, 1.95 } },
		cardDepth = 0.06,
		cardColor = { 30, 33, 62 },
		textColor = { 255, 226, 150 },
		glowBrightness = 1.6, -- SurfaceGui Brightness (LightInfluence 0): the board's one glowing thing
	},
	-- The trophy shelf: a Counter_8x2 against the back wall between the roll-up door and your van, with ornament
	-- stands on top (Ornament_Stand; the ornament hangs from the arm tip, TROPHY_HANG in the stand's local axes). The
	-- first trophy is lit (TROPHY_LIGHT over it); an empty stand waits for the next one.
	TROPHY_SHELF = { x = 14, z = -26.8, yaw = 180 },
	TROPHY_HANG = { -0.45, 1.98, 0 },
	TROPHIES = {
		{ x = 11.6, ornament = "Ornament_VaultDoor" },
		{ x = 14, ornament = "Ornament_Star" },
		{ x = 16.4 },
	},
	TROPHY_LIGHT_AT = { 13.5, 8.5, -21 }, -- between the board and the shelf behind it
	-- Snow drifting in at the door, and on the street (Xmas_SnowPile: x, z, yaw).
	SNOW_PILES = { { -5, -25.2, 160 }, { 5.5, -25.6, 20 }, { -14, -36, 0 }, { 20, -47, 90 } },
	BAY_LINE = { width = 0.3, color = { 168, 152, 122 } }, -- painted bay lines (Warm Marble shade)
	BAY_NUMBER = { size = 3, color = { 216, 200, 168 } }, -- the bay number painted on the floor at the aisle
	FLOOR_COLOR = { 58, 54, 92 }, -- greybox floor (Heist/Palette.floor)
	WALL_COLOR = { 87, 52, 41 }, -- greybox walls: the Corner Shop brick (#573429), never default grey
	LOCATION = "CornerShop", -- kit atlas: warm brick walls, pine, the warm checker floor
	SPAWN = { 0, 10 }, -- the GarageSpawn centre (Lobby.spawnFor spreads crews round it)
	KIT_WAIT_SECONDS = 90, -- the garage waits this long for the kit in the background (greybox until then)
	-- The warehouse hideout (PLAN_FIRST_PERSON §5 "BIG": a big first-person lobby). Over the 12-stud brick ground
	-- course: a band, a clerestory of Facade_8x10 bays (dark night panes), a frieze up to the roof; steel roof trusses
	-- (Truss_8) across the depth every TRUSS_EVERY studs; a roof deck with skylights (the aurora above); a mezzanine
	-- over the front row of vans with a stair up the right wall; dressing for the LOBBY track's stations, which are
	-- exposed as named anchors (Garage/Anchors). Everything over the ground course is visual only and in the garage's
	-- "Overhead" model (Heist/CutAway: the diorama sees in; first person never cuts). The mezzanine deck, its posts,
	-- its rail and the stair collide (greybox colliders, the kit never collides).
	WAREHOUSE = {
		BAND = 2, -- 12 - 14
		CLERESTORY = 10, -- 14 - 24: one storey of window bays
		ROOF_Y = 28.6, -- the roof deck's underside (the trusses hang under it)
		TRUSS_H = 4, -- Truss_8 depth: bottom chord at ROOF_Y - 0.6 - TRUSS_H
		TRUSS_EVERY = 11, -- studs between trusses along X (8 trusses)
		DECK = 0.6, -- roof deck thickness
		SKYLIGHTS = { { -22, 0, 12, 16 }, { 0, 0, 12, 16 }, { 22, 0, 12, 16 } }, -- x, z, width, depth
		SKYLIGHT_GLASS = { 150, 190, 220 },
		SKYLIGHT_ALPHA = 0.55,
		BODY = { 132, 70, 56 }, -- the upper brick (a value step over the ground course)
		BAND_COLOR = { 104, 60, 50 },
		ROOF_SNOW = { 196, 200, 226 },
		ROOF_UNDER = { 92, 74, 70 }, -- the deck's underside: warm timber boards (seen from the floor in first person)
		STEEL = { 78, 86, 117 }, -- posts, rails, stair stringers (Vault Steel shade)
		TIMBER = { 123, 82, 68 }, -- the mezzanine deck and stair treads (Wood)
		CABLE = { 42, 45, 82 }, -- the work lamps' drop cables to the trusses
		MEZZANINE = { z0 = 16, deckY = 12, thick = 0.6, guard = 8 }, -- over the front row (z0 .. the front wall)
		POSTS = { -43, -26.4, -8.8, 8.8, 26.4, 43 }, -- mezzanine posts along its aisle edge (between the vans)
		STAIR = { x0 = 40, x1 = 44, z0 = -4, z1 = 16, steps = 16 }, -- up the right wall onto the deck
		-- the stations (dressing; the LOBBY track builds the interaction on the anchors)
		LAPTOP = { x = 39, z = -26.8, yaw = 180 }, -- a desk (Counter_8x2) in the back right corner
		WARDROBE = { x = -41.6, z = 6, yaw = -90 }, -- the wardrobe and mirror corner on the left wall
		TV = { x = 0, y = 9.2, z = 15.75, w = 10, h = 5.4 }, -- a big screen hung under the mezzanine's edge
		CREW_SIGN = { x = 43.6, y = 9, z = -12, w = 10, h = 3 }, -- "THE CREW" on the right wall
		CRATES = { { -36, 24, 0 }, { -30, 25, 20 }, { 30, 24.5, -10 }, { -12, 25.5, 0 } }, -- on the deck: x, z, yaw
		SHELVES = { { -43, -6, -90 }, { -43, -14, -90 } }, -- Shelf_8x2 against the left wall
		TREE = { -40, 13 }, -- a Christmas tree beside the wardrobe corner
	},
}

-- The hideout lobby (PLAN_FIRST_PERSON "LB", the LOBBY track; MASTERPLAN §3.3): first person in the warehouse garage,
-- look-to-interact stations on the BIG track's anchors (Garage/Anchors) and the vans: PICK a free van (your crew's,
-- claimed by the leader), its paint, then SOLO (climb in, GO) or CREW (the side door opens, friends walk in and SIT,
-- the leader presses GO when every seated member is READY). Pure rules: Shared/Heist/VanRules (server state machine
-- and the Heist.Ready action validator) and Shared/Heist/LobbyLook (what each target offers you, the station camera).
-- Server: Heist/Vans (the van rigs in Garage/Vans) and HeistService; client: Heist/Hideout, Hud/Lobby, Hud/Wardrobe.
Config.Hideout = {
	ENABLED = true, -- false: the old flow (the HUD job board opens in the garage, a pick starts the heist at once)
	BAYS = 8, -- van bays (Config.Lobby.BAYS)
	-- Look-to-interact (client): reach from the eye, and the server's own check from your root (a little longer, so
	-- a prompt shown is an action the server takes).
	REACH = 10,
	SERVER_REACH = 13,
	-- Stations: an anchor of Garage/Anchors, the verb it offers, the look target (local offset from the anchor in
	-- studs: right, up, toward the facing; radius) and the station camera (where the eye eases to: `back` studs out
	-- along the anchor's facing, `up` above the target, FOV). The HUD panel opens once the ease is done.
	STATIONS = {
		{
			anchor = "JobBoardSpot",
			verb = "jobs",
			target = { 0, 4.5, 0, 2.2 },
			cam = { back = 5.5, up = 0.2, fov = 52 },
		},
		{
			anchor = "LaptopSpot",
			verb = "laptop",
			target = { 0, 0.7, 0, 1.4 },
			cam = { back = 3.2, up = 0.4, fov = 50 },
		},
		{
			anchor = "WardrobeSpot",
			verb = "wardrobe",
			target = { 0, 4.5, 0, 2.6 },
			cam = { back = 7, up = 0, fov = 50 },
		},
		{ anchor = "TVSpot", verb = "tv", target = { 0, 0, 0, 3.2 }, cam = { back = 9, up = 0, fov = 50 } },
		{ anchor = "CrewSign", verb = "invite", target = { 0, 0, 0, 2.8 }, cam = { back = 6, up = 0, fov = 50 } },
	},
	FOCUS_SECONDS = 0.45, -- the eye's ease into a station view (reduced motion: a cut)
	FOCUS_LEAVE_STUDS = 4, -- a station closes when you walk this far from where you opened it
	-- The wardrobe's view of yourself: a third-person orbit round your Rookie (the mirror is dressing).
	-- spin: deg/s; shift: studs the look point slides left, so you stand right of the sheet (HudLayout.WARDROBE)
	WARDROBE_ORBIT = { distance = 7.5, height = 1.2, yaw = 25, fov = 48, look = 0.4, spin = 18, shift = 1.8 },
	-- Vans. Geometry in van space: `along` toward the cab, `up` from the floor, `out` toward the open side door. The
	-- kit van (assets/blender/van.py) puts the cab at its local -X and the side door at its local -Z (engine-checked:
	-- tests/engine_smoke.luau section 12), so a bay anchor's LookVector (yaw = the bay's) is the door's facing.
	VAN = {
		CAB_X = -1, -- sign of the van's local X toward the cab
		DOOR_Z = -1, -- sign of the van's local Z toward the side door
		-- paints you pick from at your van (mid values, never Getaway White: GOLDEN G1); a claimed van starts in its
		-- bay's own paint (Config.Lobby.BAY_PAINTS) until the leader picks one. No van styles in the kit: paints only.
		PAINTS = {
			{ name = "TEAL", rgb = { 62, 138, 150 } },
			{ name = "BERRY", rgb = { 168, 84, 140 } },
			{ name = "INDIGO", rgb = { 100, 92, 176 } },
			{ name = "CARAMEL", rgb = { 140, 100, 72 } },
			{ name = "PINE", rgb = { 70, 120, 84 } },
			{ name = "BRICK", rgb = { 160, 74, 62 } },
		},
		-- look targets on the door side (along, up, out, radius): the cab door (SOLO / GO), the side door (CREW / SIT /
		-- READY), the rear panel (PAINT)
		POINTS = {
			cab = { 4.6, 4.4, 3.4, 1.7 },
			door = { 0.1, 4.2, 3.4, 2.4 },
			paint = { -5, 4.2, 3.4, 1.8 },
		},
		EXIT = { 0.1, 0, 6.5 }, -- where you step out (floor level, outside the side door)
		-- seats (along, up, out, yaw toward: "cab" | "door"); seat 1 is the driver (the leader), 2.. the cargo bench
		-- (crew seat order, Config.Sim.MAX_CREW in all)
		SEATS = {
			{ 4.3, 2.3, -1.2, "cab" },
			{ -5.4, 2.4, -2.1, "door" },
			{ -3.4, 2.4, -2.1, "door" },
			{ -1.4, 2.4, -2.1, "door" },
		},
		SEAT_LIGHT = { up = 6.1, out = -2.86, size = { 1.6, 0.9 } }, -- the lit name card over each cargo seat
		PLATE = { along = 0.1, up = 8.0, out = 3.05, size = { 6.4, 1.1 } }, -- the crew name plate over the side door
		DOOR_LEAF = { along = 0.1, up = 4.25, out = 3.3, size = { 5, 4.9, 0.2 }, openAlong = -4.7, openOut = 3.72 },
		DOOR_SECONDS = 0.45, -- the side door slides
		FREE_LIGHT = 0.55, -- seat card transparency while empty
	},
	-- GO -> the doors shut -> a short drive (the van in your paint down a snowy street, the town passing; skippable)
	-- -> the van-door wipe -> the heist. The server starts the heist SERVER_SECONDS after GO.
	DRIVE = {
		SERVER_SECONDS = 2.4,
		SECONDS = 2.6, -- the client's shot (the wipe closes over its end; reduced motion: the wipe at once)
		STAGE_ORIGIN = { 0, 600, -3600 }, -- client-only stage, far from the garage and every instance slot
		SPEED = 46, -- studs/s the street scrolls past
		BLOCK = { length = 18, gap = 6, depth = 12, minH = 16, maxH = 34 }, -- the passing town
		STREET_W = 26,
		LAMP_EVERY = 24,
		CAM = { along = 9, up = 3.2, out = 13, lookAlong = -1, lookUp = 3, fov = 55 }, -- a tracking 3/4 of the van
		SHAKE = 0.05, -- studs of engine rumble (off with shake / reduced motion)
		CUE = "VanDrive", -- engine rumble (Audio cue; an empty id until the owner's lands)
	},
	-- the first hideout visit: a world hint over the nearest free van ("PICK A VAN") until you have one
	HINT = { up = 10.5, size = { 220, 64 }, bob = 0.4 },
	-- the drive's SKIP and the touch USE button reuse HudLayout boxes (LOBBY_SKIP, LOBBY_USE)
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

-- UI kit v2, "the Crew Board" (docs/PLAN_STEAM_PLUS.md §3.2, §4.3 U1-U3; docs/audit/POLISH.md §4.1;
-- docs/research/premium.md D1-D12). Client Heist/Theme turns these into tokens, Heist/Motion into
-- TweenInfos (the only place one is made in src/client/Heist: tests/ui_kit_check.luau).
Config.Ui = {
	-- D8: the display face for stamps of <= 3 words and the wordmark, picked from the type specimen
	-- (Studio: workspace attribute EH_Scenario = "TYPE"). "LuckiestGuy" | "FredokaOne" (both built-in
	-- Enum.Font families, so Font.fromName works). Builder Sans stays the UI face (D1: two families).
	DISPLAY_FACE = "LuckiestGuy",
	-- D2: the type scale, design px at 720 x 330 (<= 5 sizes): caption, body / button, title, display,
	-- hero. The smallest is 16 so text never draws under 14 px at UI_SCALE_MIN (0.9). Ui.label snaps
	-- any TextSize to the nearest step (ties round up below the body size, down above it).
	TYPE_SCALE = { 16, 20, 24, 36, 64 },
	SPECIMEN_SIZES = { 14, 24, 36, 64 }, -- the D8 specimen shows these (14 only there)
	WORDMARK_OFFSET = { 5, 4 }, -- px: the cyan double exposure behind the wordmark

	-- D11: one skin
	RADIUS = 12, -- the one corner radius (chips and pills are fully round)
	STROKE = 2, -- the ink stroke (buttons, cards) and the panel rim
	TEXT_STROKE = 2, -- ink text stroke (UIStroke Contextual) on light text >= TEXT_STROKE_BIG px
	TEXT_STROKE_SMALL = 1.5, -- ... and below it
	TEXT_STROKE_BIG = 24,
	DISPLAY_STROKE = 0.06, -- display text: stroke = 6 % of its size, round joins
	SHADOW_OFFSET = 4, -- px: the one drop shadow (9-slice EH_UI_Shadow, ink)
	SHADOW_TRANSPARENCY = 0.45,
	SHADOW_SPREAD = 8, -- px the shadow image extends past the panel (its blur margin)
	PANEL_TRANSPARENCY = 0.06,
	PANEL_BODY_VALUE = 0.8, -- EH_UI_Panel's body grey (tools/ui/make_ui_kit.py BODY_VALUE): the tint is divided by it
	SLICE_CENTER = { 26, 26, 70, 60 }, -- EH_UI_Panel / EH_UI_Shadow 9-slice centre (96 px images)
	SLICE_SCALE = 0.5, -- 24 px image corners draw as RADIUS
	BUTTON_LIP = 5, -- px: a raised button's lip (a darker band at its bottom)
	BUTTON_LIP_SHADE = 0.58, -- the lip's value relative to the face
	BUTTON_FACE_SHADE = 0.9, -- the face's bottom edge (a gentle top-to-bottom shade)
	ICON_SIZE = 28, -- px: icon in an icon + word button
	ICON_SMALL = 20, -- px: icon in pills, chips and run-bar markers
	ICON_GAP = 6,

	-- D3, D4, D10: motion tokens (seconds, easing style, direction). Enter 0.18-0.30 Out / Back Out;
	-- Exit 0.10-0.18 Quad In; Feedback 0.06-0.12; Emphasis 0.25-0.45.
	MOTION = {
		enter = { 0.24, "Back", "Out" },
		exit = { 0.12, "Quad", "In" },
		feedback = { 0.08, "Quad", "Out" },
		emphasis = { 0.35, "Back", "Out" },
		fade = { 0.15, "Quad", "Out" }, -- reduced motion: crossfades and colour instead of scale
		pressDown = { 0.04, "Quad", "Out" }, -- 0.92 "instantly" (<= 60 ms)
		pressUp = { 0.09, "Quad", "Out" }, -- release: up to the overshoot ...
		pressSettle = { 0.17, "Sine", "InOut" }, -- ... and settle to 1.0 (0.26 s in all)
		pop = { 0.2, "Back", "Out" },
	},
	PRESS_SCALE = 0.92,
	PRESS_OVERSHOOT = 1.04,
	ENTER_FROM = 0.86, -- panel enter: UIScale from this to 1
	EXIT_TO = 0.92, -- panel exit: UIScale to this, then hidden
	POP_SCALE = 1.12, -- feedback pops (timer digits in the last 10 s, the loot meter)
	FLASH_RED_SECONDS = 0.5, -- the red vignette fades out over this (caught, zapped)
	CHIP_STAGGER = 0.06, -- s between new clone chips (the tape-print rhythm) ...
	STAGGER_CAP = 0.4, -- ... never wider than this in all (D5)

	-- U3 HUD
	REWIND_SIZE = 96, -- px: REWIND, large, lower right (above the touch jump button)
	REWIND_RIGHT = 10, -- px from the right edge
	REWIND_BOTTOM = 136, -- px from the bottom edge to REWIND's bottom (clears the jump button: tests/hud_layout)
	LOCK_SEGMENTS = 20, -- REWIND's ring lock: dots that go out over Config.Rec.END_RUN_LOCK_SECONDS
	BREATH_HZ = 0.5, -- REWIND breathes with the plate pulse when it is the right move (own clock if the world gives none)
	BREATH_SCALE = 0.06, -- 1.0 <-> 1.06
	CHIP_W = 28, -- clone chips: numbered pills (8 x 28 + 7 x 4 = the strip's 252)
	TIMER_DIGIT_W = 15, -- px per fixed-width timer digit slot ...
	TIMER_COLON_W = 8, -- ... and the colon's
	TIMER_SIZE = 24, -- the timer's type step
	-- Run bar next-event markers (premium §6.4, MASTERPLAN §7.4 #1): Gus's turn points as amber ticks,
	-- laser on-spans as red segments (only lasers your clones switch off: the gaps are the windows).
	MARKER_SAMPLE_HZ = 10, -- clone recordings are sampled this often to forecast the lasers
	GUS_TURN_DEG = 35, -- a route corner counts as a turn above this
	MAX_GUS_TICKS = 24,

	-- D10 number count-up (POLISH §4.1): BASE s + PER_DIGIT s per digit of the change, capped at MAX,
	-- Quad Out, then a 1.0 -> END_POP -> 1.0 pop (Shared/Heist/CrewBoard.countSeconds / countValue).
	COUNT_UP = { BASE = 0.35, PER_DIGIT = 0.08, MAX = 1.0, END_POP = 1.15, TICK = 0.08 },
	BREATH_SECONDS = 0.8, -- breathing outline half period (Sine InOut; NEXT job, the card to delete)
	BREATH_TRANSPARENCY = { 0.35, 0.85 }, -- ... the outline's transparency swings between these

	-- U4 crew cards: the Clone Deck as polaroids of your own avatar (PLAN_STEAM_PLUS §3.2, WALKTHROUGH P0-3).
	CARD = {
		W = 96, -- px: a card (the paper); 4 cards fit the deck without scrolling
		H = 88,
		PAD = 5, -- paper border round the photo
		PHOTO_H = 56, -- the photo (your Rookie's portrait on a crew-colour backdrop; Config.Rookie.PORTRAIT)
		CAPTION_H = 22, -- the caption strip under it: the last action's word
		BADGE = 22, -- the last action's icon, a round badge on the photo's corner
		PILL = { 28, 22 }, -- the stamped number pill (wider with the seat shape: + PILL_GLYPH)
		PILL_GLYPH = 16,
		GAP = 8,
		TILT = 2, -- degrees, alternating per card (pinned, not ruled); 0 under reduced motion
		BACKDROP_DIM = 0.55, -- the photo backdrop is the crew hue at this value
		PILL_TILT = -8, -- the stamped number
		STAMP_TILT = -12, -- the BUSTED / REDO stamp across the photo
		TAPE = { 26, 9, 0.35 }, -- the tape strip at the top (w, h, transparency): dressing only
	},
	START_OVER_RUNS = 2, -- full deck: after this many runs with no progress, offer START OVER (P0-3)
	DECK_FULL_TOAST_SECONDS = 3,

	-- U5 the job sheet (results). Seconds from the sheet's enter (POLISH §4.2 "Results v2 timeline", premium F5:
	-- anticipation, reveal, payoff, settle; the buttons last, with a 0.3 s guard).
	SHEET = {
		SLIDE = 40, -- px: the sheet slides up this far as it enters
		HAUL_AT = 0.25, -- the haul starts counting up
		LINE_AT = 0.7, -- first goal line struck (pencil), then one per LINE_GAP
		LINE_GAP = 0.25,
		STRIKE_SECONDS = 0.18, -- a pencil stroke across a line
		STAMP_AT = 0.9, -- stamps land (Config.Audio.MEDAL_STAMP_GAP apart)
		STAMP_FROM = 1.6, -- stamp land: UIScale from this ...
		STAMP_ROTATION = -5, -- ... settling at this tilt (from -8)
		RING_FROM = 0.8, -- the ink ring behind a stamp grows RING_FROM -> RING_TO, fading over RING_SECONDS
		RING_TO = 1.6,
		RING_SECONDS = 0.3,
		LINE_AT_SUMMARY = 1.6, -- "3 clones · 4 runs · 1:52"
		TROPHY_AT = 1.9, -- the trophy flies to the van icon
		TROPHY_SECONDS = 0.45,
		BUTTONS_AT = 2.1, -- buttons slide up and fade in ...
		BUTTON_GUARD = 0.3, -- ... and take input this much later
		PENCIL = { 0.2, 0.2, 0.25 }, -- pencil graphite (RGB 0..1)
	},

	-- U6 the job board (level select in the garage): pinned job photos on cork, string between the pins in
	-- play order, medal stickers, the NEXT job glowing like the 3D board's NEXT card (Config.Lobby.BOARD).
	BOARD = {
		CORK = { 154, 119, 85 }, -- Corner Shop pine (POLISH §4.2 "label band" colours)
		CELL = { 142, 88 }, -- 3 columns fill the board's 462 px: GAP + 3 x (CELL + GAP)
		GAP = { 8, 12 },
		COLUMNS = 3,
		PIN = 10, -- px pushpin
		TILT = { -2.5, 1.5, -1, 2.5, -1.5, 1 }, -- degrees per card, by position (0 under reduced motion)
		STRING = { 140, 34, 52 }, -- the red string
		STRING_W = 2,
		LOCATION = { cs = { 154, 119, 85 }, bk = { 77, 71, 120 }, party = { 31, 63, 95 } }, -- photo bands
		STICKER = 18, -- px medal sticker
	},

	-- U7 settings (Hud/Settings). Rows in order; `key` is the Schema settings key, `kind` "toggle" | "slider" |
	-- "camera". Sliders step by `step` (a share of the key's SETTING_NUMBERS range; default SLIDER_STEP) and save
	-- when released; `text` "degrees" shows the value as a number (the FOV), else a percent.
	SETTINGS_ROWS = {
		{ key = "musicVolume", kind = "slider" },
		{ key = "sfxVolume", kind = "slider" },
		{ key = "cameraMode", kind = "camera" },
		{ key = "fpFov", kind = "slider", step = 1 / 30, text = "degrees" },
		{ key = "shake", kind = "toggle" },
		{ key = "reducedMotion", kind = "toggle" },
		{ key = "captions", kind = "toggle" },
		{ key = "colourBlindGlyphs", kind = "toggle" },
		{ key = "guardPath", kind = "toggle" },
		{ key = "haptics", kind = "toggle" },
	},
	SETTINGS_COLUMNS = 4, -- 10 cells on a 4 x 3 grid (HudLayout.SETTINGS keeps 3 rows: it fits a phone's height)
	SLIDER_STEP = 0.05,
	SFX_BUSES = { "SFX", "UI", "Ambience" }, -- the SFX slider drives these AudioDirector buses (Warnings keep their floor)

	-- Bank moment, HUD half (PLAN §5 "First bank"): "+$100" flies from the van to the loot meter.
	BANK_FLY = { SECONDS = 0.55, ARC = 90, MAX = 12, MAX_LOW_TIER = 6 }, -- arc px above the straight line; F7 caps
}

-- World backdrop (PLAN_STEAM_PLUS §4.1 W4, roblox_quality §2): the town around the active heist instance and
-- around the garage, built on the client by src/client/Heist/Backdrop.luau from the pure plan in
-- src/shared/Heist/BackdropPlan.luau. Static decoration only: every part is Anchored with
-- CanCollide / CanQuery / CanTouch / CastShadow off, so the sim, Poppercam and Gus's fan never see it.
-- Budget for the whole backdrop (§2.2): about 30 draw calls and 25k triangles (BackdropPlan.budget).
Config.Backdrop = {
	ENABLED = true,
	-- WORLD 2.0 (owner, Nov 2026: "all maps must look better and must NOT be black in the background"; LEVELS.md
	-- §10): every lot sits in a bright snowy neighbourhood that fills the frame to its edges in both cameras. Snow
	-- is a high-value surface (it reads bright even at night: hue says night, not darkness); warmth comes from the
	-- windows, the unlit lamp pools and the warm house bodies; cool only in shadow (PLAN_STEAM_PLUS §3.1).
	-- L0, the snowfield: one ground Part under the whole town (its far edge is lost in the light haze).
	GROUND_SIZE = 2048, -- studs (the Part size limit)
	GROUND_DROP = 0.3, -- studs: its top under the level floor (the town's streets sit at the lot's own height)
	GROUND_COLOR = { 176, 182, 214 }, -- open snow (V 84 %): the brightest big field, never a dark table
	-- L1, the town (Shared/Heist/TownPlan): the street the lot stands on (pavements, kerbs, a snowy road with tyre
	-- tracks), the neighbours on both sides, behind and across the street (lit windows, snow on every roof,
	-- garlands and wreaths), lamp posts with unlit warm pools (no Light objects), parked cars with snow on the
	-- roof, decorated trees, snowmen; and the client's snow over the lot's outdoor floor. Each map has its own
	-- street (THEMES, PLAN_STEAM_PLUS §3.1 signature silhouettes) and each level its own arrangement (seed).
	TOWN = {
		SPAN = 150, -- studs: the street runs this far either side of the lot's centre
		PAVEMENT = 5, -- studs: each pavement's depth
		ROAD = 22, -- studs: the road's depth (the lot's own street part is the near side of it)
		ROAD_PAST_LOT = 4.5, -- studs: the far kerb is at least this far past the lot's street edge
		KERB = { width = 0.6, height = 0.22 },
		ALLEY = 3, -- studs between the lot's side and its first neighbour
		BACK_GAP = 4, -- studs between the lot's back and the row behind it
		LIFT = 0.015, -- studs: the top of the lot snow and the town's streets above the level floor (under the kit
		-- floor tiles' +0.02, the cables' +0.03 and the pools' +0.06)
		TRACK_LIFT = 0.03,
		TRACKS = { width = 0.9, gauge = 4.2, lanes = { -5, 5 } }, -- tyre tracks: across the road's centre line
		COLORS = {
			roofSnow = { 196, 200, 226 }, -- fresh snow on roofs and cornices (the diorama sees roofs from above)
			yard = { 160, 136, 128 }, -- the lot's outdoor floor: warm cobbles under a dusting (V 63 %; the snow is outside)
			pave = { 180, 144, 126 }, -- swept warm sandstone paving (V 71 %: warm under the lamps)
			road = { 164, 158, 180 }, -- packed snow on the road, warmed by the windows (V 71 %)
			track = { 116, 96, 94 }, -- slushy tyre tracks (V 45 %)
			kerb = { 172, 164, 152 }, -- warm kerb stone
			plaza = { 170, 164, 176 }, -- the Bank plaza's snow-dusted paving
			trim = { 226, 214, 190 }, -- cornices and sills (Warm Marble light)
			door = { { 140, 47, 75 }, { 36, 112, 74 }, { 44, 58, 104 }, { 120, 78, 52 } },
		},
		-- maxPerFace: lit windows on one face at most (tall civic fronts would cost 30+ instances each). BIG: the window
		-- grid itself is a Texture on one "Skin" part per face (SKIN); the lit panes (Neon) sit on its cells, so w / h /
		-- SKIN.winTop must match tools/ui/make_window_fx.py (WIN_W, WIN_H, WIN_TOP).
		WINDOW = {
			w = 2.4,
			h = 4.6,
			colPitch = 4.5, -- one window bay
			lit = 0.75,
			depth = 0.2,
			out = 0.14,
			maxPerFace = 6,
		},
		-- BIG (PLAN_FIRST_PERSON §5): the town scales up to 4-8 storey blocks with varied rooflines, a deeper street and
		-- landmark towers either side of Hoardsworth's. A storey is STOREY studs over a GROUND-stud ground floor.
		GROUND = 12,
		STOREY = 9,
		SKIN = {
			image = "EH_FX_Windows", -- assets/ui/EH_FX_Windows.png (tools/ui/make_window_fx.py), uploaded with the UI kit
			cols = 4, -- the image is 4 bays x 4 storeys
			rows = 4,
			inset = 1.2, -- studs of plain wall either side of the grid
			out = 0.03, -- studs in front of the body
			winTop = 0.2, -- a window's top under its storey's top (share of a storey)
			color = { 255, 255, 255 },
		},
		ROOFTOP = { setback = 0.3, setbackH = 7, tank = 0.3, chimney = 0.35, antenna = 0.3, spire = 14 },
		DEPTH = { back = 26, across = 26, overhang = 30, kinds = { "townhouse", "civic", "townhouse", "shop" } },
		TOWERS = { { x = -58, back = 34, w = 24, d = 22 }, { x = 64, back = 46, w = 22, d = 22 } },
		TOWER_STOREYS = { 11, 14 },
		SHOP = { paneH = 4.2, paneSill = 1.3, awningY = 6.4, awningDepth = 2.6, doorW = 2.8, doorH = 5.2 },
		HOUSE = { doorW = 2.4, doorH = 4.6 },
		ROOF = { rise = 0.42, overhang = 0.6 }, -- gable height per stud of depth; eaves past the walls
		-- The street lamps: kit StreetLamp + bulb, and an unlit warm pool (SurfaceGui, LightInfluence 0) on the snow.
		LAMP = { spacing = 28, pool = 20, poolColor = { 255, 196, 140 }, poolAlpha = 0.6, poolLift = 0.05 },
		CAR = { spacing = 30, colors = { { 150, 52, 64 }, { 46, 92, 140 }, { 214, 188, 120 }, { 60, 112, 84 } } },
		-- Per map: the kinds of building along each row (picked in turn, shuffled by the level's seed), their
		-- body colours, awnings, heights, and the signature piece (PLAN_STEAM_PLUS §3.1).
		THEMES = {
			CornerShop = { -- "Corner Shop street": brick terraces, corner shops and gabled houses
				near = { "shop", "house", "townhouse", "house" },
				across = { "house", "house", "shop", "house", "townhouse" },
				back = { "house", "townhouse", "house" },
				bodies = {
					{ 156, 78, 62 },
					{ 182, 102, 72 },
					{ 198, 156, 92 },
					{ 214, 196, 160 },
					{ 132, 70, 82 },
					{ 168, 118, 96 },
				},
				awnings = { { 140, 47, 75 }, { 36, 112, 74 }, { 44, 58, 104 } },
				storeys = { shop = { 4, 6 }, house = { 3, 4 }, townhouse = { 4, 7 }, civic = { 5, 7 } }, -- upper storeys
				widths = { 16, 20, 18, 24 },
				signature = "tree", -- a decorated tree on the far pavement
			},
			ToyShop = { -- "Toy Shop high street": candy-coloured shops under strings of fairy lights
				near = { "shop", "shop", "townhouse", "shop" },
				across = { "shop", "shop", "shop", "townhouse", "shop" },
				back = { "townhouse", "house", "townhouse" },
				bodies = {
					{ 222, 130, 160 },
					{ 232, 128, 112 }, -- coral (every Toy Shop body is a warm candy: the shop front is storybook navy)
					{ 232, 200, 112 },
					{ 200, 92, 132 }, -- raspberry
					{ 236, 162, 122 },
					{ 238, 214, 168 }, -- vanilla
				},
				awnings = { { 236, 96, 140 }, { 64, 170, 140 }, { 236, 190, 70 }, { 130, 100, 200 } },
				storeys = { shop = { 4, 6 }, house = { 3, 4 }, townhouse = { 5, 7 }, civic = { 5, 7 } },
				widths = { 16, 18, 20, 16 },
				signature = "lights", -- fairy-light strings on every front, two trees
				pave = { 192, 142, 128 }, -- rose sandstone paving (the lot and the pavements: warm under the pink lamps)
				yard = { 172, 136, 138 },
			},
			Bank = { -- "Bank plaza": stone fronts and a plaza with a big Christmas tree across the street
				near = { "townhouse", "civic", "townhouse" },
				across = { "civic", "townhouse", "civic" },
				back = { "townhouse", "civic", "townhouse" },
				bodies = {
					{ 210, 190, 152 },
					{ 198, 194, 180 },
					{ 160, 98, 84 },
					{ 186, 168, 140 },
					{ 222, 206, 172 },
				},
				awnings = { { 36, 112, 74 }, { 140, 47, 75 } },
				storeys = { shop = { 4, 5 }, house = { 3, 4 }, townhouse = { 5, 7 }, civic = { 6, 8 } },
				widths = { 22, 26, 20 },
				signature = "plaza", -- PLAZA: the paving, the big tree, its lamps
				PLAZA = { width = 64, depth = 40, treeScale = 4.4, lamps = 4 },
			},
			Garage = { -- "garage yard": workshops and warehouses round the yard behind the roll-up door
				near = { "warehouse", "house", "warehouse" },
				across = { "house", "warehouse", "house", "house" },
				back = { "warehouse", "house", "warehouse" },
				bodies = {
					{ 148, 76, 60 },
					{ 112, 122, 146 },
					{ 96, 124, 100 },
					{ 160, 100, 70 },
					{ 206, 186, 146 },
				},
				awnings = { { 44, 58, 104 }, { 140, 47, 75 } },
				storeys = { shop = { 3, 4 }, house = { 3, 4 }, townhouse = { 4, 6 }, warehouse = { 2, 3 } },
				widths = { 22, 18, 26 },
				signature = "yard", -- cars and a tree round the yard
			},
		},
		-- The Christmas pieces of the town (garlands, wreaths, tree lights, light strings): "always" (the town is
		-- on Christmas Eve, PLAN_STEAM_PLUS §3.1) or "dressing" (only with the levels' Christmas layer).
		XMAS_DECOR = "always",
		PROPS_OFF_TIER = 3, -- cars, snowmen, snow piles, garlands, wreaths, light strings
		POOLS_OFF_TIER = 3, -- the unlit lamp pools (SurfaceGuis: one draw each)
		-- The lot's edge: a client-only invisible collider (CanQuery off) so nobody walks off the lot into the town
		-- (the town never collides).
		LOT_FENCE = { height = 24, thickness = 2 },
		-- The whole backdrop at tier 1 (unit spec on every site; engine_smoke / perf_engine count the real build).
		-- BIG: 4-8 storey blocks, a deeper street and two towers (the window grids are one Texture per face; rooftop
		-- props are the "props" layer, gone from tier 3, which keeps the town near 12k triangles there)
		BUDGET = { instances = 950, draws = 45, tris = 100000, lights = 0 },
	},
	WINDOW_COLOR = { 246, 192, 162 }, -- Bulb Warm #F6C0A2 (eh_palette.NEON, rule N1): the only glow allowed
	SNOW_COLOR = { 192, 195, 213 }, -- Snow #C0C3D5 (small areas only, STYLE_BIBLE §1.3)
	-- The warm window spill on the pavement in front of each kit display window (unlit SurfaceGui, the room
	-- lamps' location colour): opacity at the wall, fading to nothing SPILL_DEPTH studs out toward the kerb.
	SPILL_ALPHA = 0.18,
	SPILL_DEPTH = 5,
	-- L2 / L3, the skyline rings: four copies of one quarter-arc kit mesh each (body + Neon windows; kit pieces
	-- built by assets/blender/backdrop.py, published to ReplicatedStorage by server Heist/BackdropKit).
	-- `color`: the body is drawn flat in this colour (TextureID cleared on the client): a light haze silhouette, not
	-- the atlas's dark Ink faces (WORLD 2.0: the rings read black under the old recipe).
	RINGS = {
		{
			name = "near",
			piece = "Skyline_Near",
			windows = "Skyline_Near_Windows",
			yaw0 = 0,
			color = { 112, 114, 166 },
		},
		{ name = "far", piece = "Skyline_Far", windows = "Skyline_Far_Windows", yaw0 = 45, color = { 134, 136, 186 } },
	},
	KIT_FOLDER = "BackdropKit", -- ReplicatedStorage/<KIT_FOLDER>: the ring and town kit templates
	KIT_WAIT_SECONDS = 60, -- the client builds the rest at once and adds the kit pieces when they arrive
	-- The town's kit pieces Heist/BackdropKit publishes besides the rings (KitService templates, Bank atlas).
	KIT_PIECES = {
		"StreetLamp",
		"StreetLamp_Bulb",
		"Roof_Gable",
		"Car_Parked",
		"Car_Parked_Paint",
		"Snowman",
		"Xmas_Tree",
		"Xmas_Tree_Lights",
		"Xmas_Garland_8",
		"Xmas_Wreath",
		"Xmas_Lights_8",
		"Xmas_Lights_8_Bulbs",
		"Xmas_SnowPile",
		"Roof_WaterTank", -- BIG: the town's rooflines
		"Roof_Chimney",
		"Roof_Antenna",
	},
	-- Performance tiers (Config.Heist.PERF_TIERS): roblox_quality §6.4. Low phones keep the snowfield, the
	-- streets, every building and its lit windows, the near ring and the sky: the frame is never black.
	FAR_RING_OFF_TIER = 2, -- BIG: the taller town and its towers hide most of the far ring; phones (tier 2+) skip it
	-- The sky: the Heist City cubemap (tools/blender/sky_city.py) has Hoardsworth's tower at this yaw (degrees,
	-- Roblox -Z = 0, turning toward -X). The client turns Lighting.Sky so the tower stands behind the building
	-- the spawn faces (Sky.SkyboxOrientation), so every level and the garage get it in the first view.
	SKY_LANDMARK_YAW = 0,
	SKY_TURN = true,
	-- Falling snow (MASTERPLAN §6.8: <= 360 live particles on touch; roblox_quality §2.1 / §5.6): one emitter on
	-- a box that follows the camera. Exterior views only: inside a building footprint the rate is INTERIOR_SCALE.
	SNOW = {
		rate = 40, -- particles / s
		lifetime = { 4.5, 6 },
		size = { 0.16, 0.26 },
		speed = { 2.4, 3.4 },
		spread = 18, -- degrees off straight down
		drift = { 0.6, 0, 0.3 }, -- studs / s^2 of wind (Acceleration)
		rotSpeed = { -40, 40 },
		lightInfluence = 0.3,
		lightEmission = 0.15,
		transparency = 0.15,
		box = { 48, 22, 48 }, -- studs: the emitter volume around the camera focus (the camera sits inside it)
		above = 6, -- studs: the volume's centre above the camera focus
		maxAlive = 240, -- rate x lifetime stays under this (unit spec)
		lowTierScale = 0.5, -- tier >= LOW_TIER: half the rate (120 alive, roblox_quality §2.1 "Q1")
		LOW_TIER = 3,
		reducedRate = 0.5, -- reduced motion: sparser ...
		reducedSpeed = 0.45, -- ... and slower, never off
		interiorScale = 0, -- inside the building footprint (the levels have no roofs)
		texture = "rbxassetid://117922085753809", -- assets/sky/EH_SnowFlake.png (sky_ids.json); "" = the default
		color = { 236, 240, 255 },
	},
	-- Snow caps on the street side of the kit fronts (client, thin parts; the Christmas layer's Xmas_SnowCap_8
	-- covers the wall tops). Studs, in each front's local frame (STYLE_BIBLE §5.1: X along the front, -Z street).
	SNOW_CAPS = {
		thickness = 0.14,
		awningShare = 0.38, -- the upper share of each awning slope (the stripes below stay visible)
	},
}

-- Northern lights (PLAN_FIRST_PERSON "SKY"; STYLE_BIBLE §16 sky exception; docs/PERF.md §4). Client only: Heist/Aurora
-- builds chains of additive Beams along curved spines from the pure Shared/Heist/AuroraPlan; tier counts in
-- Shared/Heist/Budget. Every layer is a band of the sky seen from the camera's ground point: a spine on a big circle
-- whose centre lies behind the viewer (real aurora arcs run in parallel bands), so a band passes `dist` studs ahead
-- of the viewer at its middle and curves back at its ends. Local frame: x to the right, z forward = toward the
-- landmark (the site's first view, Hoardsworth's tower in the sky), y up; studs.
Config.Aurora = {
	ENABLED = true,
	-- assets/sky/EH_Aurora_{A,B,C}.png (tools/blender/aurora_textures.py), uploaded with kit_upload.py --sky and
	-- resolved to image ids with --resolve-sky (assets/sky/sky_ids.json). The three tiles share their edge columns,
	-- so a chain may mix them without a seam.
	TEXTURES = {
		"rbxassetid://110364872208024",
		"rbxassetid://112410864664438",
		"rbxassetid://80686493108095",
	},
	-- The tiles are authored with image x along the beam and image top = the curtain's top. If Studio shows the
	-- violet tips at the bottom, set this: the chains are built from the other end, which flips the image.
	REVERSE_SPINE = false,
	SEGMENTS = 20, -- Beam.Segments per spine piece (a smooth curve, 40 triangles a piece)
	UPDATE_HZ = 15, -- sway and breathing writes a second (the shimmer is the engine's TextureSpeed)
	REVEAL_SECONDS = 3, -- the fade-in once every texture has loaded (an unloaded Beam texture draws a solid bar)
	PRELOAD_RETRY_SECONDS = 30, -- one more preload after a failure; until then nothing is shown
	BRIGHTNESS = 1.4, -- Beam.Brightness before each layer's own factor (LightInfluence 0: unlit)
	REDUCED_MOTION = 0.35, -- sway, scroll and breathing speed under reduced motion (slower, never off)
	-- Never reachable, never in a room (unit spec over every sway phase): every ribbon's lower edge stays at least
	-- MIN_CLEARANCE studs over the anchor and MIN_ELEVATION degrees over the viewer's horizon.
	MIN_CLEARANCE = 40,
	MIN_ELEVATION = 3,
	-- Colour breathing: each Beam's Color runs between these two tints (multiplied onto the texture), as a slow wave
	-- along the band; white keeps the texture's own green.
	TINT_A = { 255, 255, 255 },
	TINT_B = { 190, 255, 238 }, -- a teal lean
	TINT_WAVE = 2, -- tint waves along a whole band
	END_FADE = 0.55, -- a band's second point from each end shows this much (its end points: nothing)
	-- The layers in priority order: a tier keeps the first Budget.auroraLayers(tier). Fields:
	--   dist / side / height: the band's middle, studs ahead of, right of and above the viewer; radius: its circle
	--   (bigger = straighter); span: studs of band left and right of the middle; turn: degrees the band swings about
	--   its middle (+ brings the right end nearer); tilt: studs the right end rises over the left; points: spine
	--   control points (points - 1 Beams);
	--   width: the ribbon's width (the curtain's height on screen); fold / foldWaves / foldPhase: the band's static
	--   folds toward and away from the viewer; lift: a static height wave;
	--   sway = { z, y, period }: the control points' slow drift (studs, studs, seconds per cycle);
	--   breathe = { amount, period }: Brightness x (1 +- amount); scroll: TextureSpeed (tiles a second, sign = way);
	--   transparency: the ribbon's base Transparency; brightness: x BRIGHTNESS; follow: the share of the camera's
	--   horizontal moves the band follows (1 = a sky element; less = slight parallax between the bands).
	LAYERS = {
		{
			name = "Veil", -- the hero band: rises from low on the left to high on the right, over the landmark (every tier)
			dist = 360,
			side = 0,
			height = 320,
			radius = 1600,
			span = 950,
			turn = 14,
			tilt = 150,
			points = 8,
			width = 230,
			fold = 70,
			foldWaves = 1.6,
			foldPhase = 0.2,
			lift = 26,
			sway = { 34, 18, 31 },
			breathe = { 0.18, 13 },
			scroll = 0.012,
			transparency = 0.18,
			brightness = 1,
			texture = 1,
			follow = 0.95,
		},
		{
			name = "Crown", -- crosses the zenith the other way: first person looking up
			dist = 40,
			side = 0,
			height = 480,
			radius = 2200,
			span = 1000,
			turn = -55,
			tilt = -90,
			points = 7,
			width = 260,
			fold = 90,
			foldWaves = 1.2,
			foldPhase = 0.65,
			lift = 34,
			sway = { 40, 22, 37 },
			breathe = { 0.22, 17 },
			scroll = -0.009,
			transparency = 0.5,
			brightness = 0.85,
			texture = 2,
			follow = 0.9,
		},
		{
			name = "Drape", -- a shorter curtain far off to the right: depth behind the Veil
			dist = 620,
			side = 260,
			height = 255,
			radius = 1700,
			span = 700,
			turn = 35,
			tilt = 60,
			points = 7,
			width = 200,
			fold = 60,
			foldWaves = 2,
			foldPhase = 0.45,
			lift = 22,
			sway = { 30, 14, 27 },
			breathe = { 0.24, 11 },
			scroll = 0.015,
			transparency = 0.45,
			brightness = 0.9,
			texture = 3,
			follow = 0.97,
		},
		{
			name = "Glow", -- low and wide over the horizon: the soft glow at the top of the classic frame
			dist = 850,
			side = -60,
			height = 190,
			radius = 2000,
			span = 1300,
			turn = -10,
			tilt = -40,
			points = 8,
			width = 180,
			fold = 50,
			foldWaves = 2.5,
			foldPhase = 0.1,
			lift = 16,
			sway = { 26, 10, 23 },
			breathe = { 0.25, 9 },
			scroll = -0.011,
			transparency = 0.38,
			brightness = 0.8,
			texture = 2,
			follow = 1,
		},
	},
	-- Per runtime tier (Config.Heist.PERF_TIERS; Shared/Heist/Budget): tier 1-2 everything, tier 3 two layers,
	-- tier 4 one static layer (no sway, scroll or breathing).
	TIERS = {
		{ layers = 4, animated = true },
		{ layers = 4, animated = true },
		{ layers = 2, animated = true },
		{ layers = 1, animated = false },
	},
	-- The aurora's light on the snow: added to Lighting.OutdoorAmbient (0-255 per channel) through LightDirector's
	-- setExteriorTint (it owns Lighting). Only adds, so Ambient <= OutdoorAmbient still holds. Very low.
	OUTDOOR_ADD = { 0, 7, 4 },
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
	-- The world muffle (premium §6.2 "muffle first"): SFX + Ambience (the Clone bus feeds SFX) through one
	-- low-pass that sweeps 20 kHz -> 800 Hz with the tape-stop and opens on the snap. UI, Warnings and the
	-- music (it dives on its own) stay clear. AudioDirector.muffle(on, seconds?).
	MUFFLE_HZ = 800,
	MUFFLE_OPEN_HZ = 20000,
	MUFFLE_IN = 0.1,
	MUFFLE_OUT = 0.25,

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

-- Clone look and acting (PLAN_STEAM_PLUS §3.1, §4.4 A2 "that's me" and A3 "clones act"; client views
-- Heist/EchoView, Heist/Rigs, Heist/PlayerHalo; pure Shared/Heist/CloneState, ClonePose, CloneGait).
Config.Clone = {
	-- Per-frame state from the recording (CloneState). Speeds are horizontal, studs per recording second.
	MOVE_SPEED = 0.75, -- above this a clone walks (the R15 Animate threshold) ...
	STOP_SPEED = 0.5, -- ... and it stands again under this (hysteresis)
	AIR_RISE = 2.5, -- |vertical speed| above this without the GROUNDED flag = jumping / falling

	-- Locomotion clips: the Rookie's own (Shared/Heist/RookieClips, Config.Rookie.ANIM), the same your character
	-- plays; a template attribute EH_Anim_<slot> overrides a slot, and these default R15 ids are the last fallback.
	-- Slots: idle, walk, run, jump, fall, land (land: Rigs.land, as a clone touches down).
	ANIM_SLOTS = { "idle", "walk", "run", "jump", "fall", "land" },
	ANIM = {
		idle = "rbxassetid://507766666",
		walk = "rbxassetid://507777826",
		run = "rbxassetid://507767714",
		jump = "rbxassetid://507765000",
		fall = "rbxassetid://507767968",
	},
	-- Gait (CloneGait): the R15 Animate's walk / run blend and rates (numbers in Config.Rookie.ANIM), ground
	-- speed = recorded speed x the view's clock rate (1x, 3x fast-forward): no foot sliding.
	GAIT_SPEED_EPS = 0.01, -- relative clip-speed change before AdjustSpeed is called again
	GAIT_WEIGHT_STEP = 0.1, -- walk/run weights are sent in steps of this
	MAX_VIEW_RATE = 4, -- clamp of the view's measured clock rate (a seek is not a rate)
	ANIM_FADE = 0.2, -- cross-fade between locomotion clips
	ANIM_DISTANCE = 90, -- beyond this many studs from the camera, clips stop (the root still moves)
	POSE_DISTANCE = 60, -- custom Lua poses (plate, carry, stuck, busted) only nearer than this

	-- Custom poses (ClonePose; radians and seconds). Avatars play them as Animation clips baked from
	-- ClonePose (tools/clone_clips.luau -> Shared/Heist/CloneClips); mannequins pose their arms in Lua.
	-- Re-bake and re-upload after changing a pose number: lune run tools/clone_clips.luau build/clips,
	-- then python3 tools/anim_upload.py --clips build/clips.
	POSE_BLEND = 0.18, -- into and out of a custom pose
	BUSTED_FADE_IN = 0.05, -- the busted clip raises the hands itself
	LOOK_SMOOTH = 0.15, -- IKControl SmoothTime of the plate glance
	LOOK_REACH = 6, -- studs from the head to the glance's IK target (the clamped direction)
	CARRY_SHOULDER = 1.0, -- arms forward
	CARRY_INWARD = 0.32, -- hands toward the middle
	CARRY_ELBOW = 1.05, -- forearms up: the loot sits between both hands
	CARRY_BOB = 0.07, -- studs of loot bob (two per walk cycle; slow breath when standing)
	CARRY_BOB_IDLE_HZ = 0.9,
	CARRY_HANDS = { 0, 0.2, -1.1 }, -- loot centre from the root in the clone's frame (x, y, z; -z is forward)
	PLATE_SHIFT_HZ = 0.22, -- weight shift from foot to foot
	PLATE_SHIFT = 0.07, -- waist sway (rad)
	GLANCE_AT = 0.8, -- s on the plate before the one glance back at you
	GLANCE_IN = 0.25,
	GLANCE_HOLD = 0.9,
	GLANCE_OUT = 0.3,
	LOOK_YAW = math.rad(70), -- head look-at limits (elliptical), roblox_quality §4.3
	LOOK_PITCH = math.rad(40),
	STUCK_CYCLE = 4.0, -- s: tap the wall, then shrug, again
	STUCK_TAP = 1.3, -- s of tapping at the start of each cycle
	STUCK_TAP_HZ = 3,
	STUCK_SHRUG = 1.2, -- s of shrug after the taps
	BUSTED_HANDS_UP = 0.3, -- s: hands go up (they stay up through the glitch)
	BUSTED_GLITCH = 0.3, -- s of glitch after the hands are up; then the tape-ribbon burst and gone
	GLITCH_SLICES = 3, -- 2-frame slices, offset sideways
	GLITCH_OFFSET = 0.3, -- studs
	GLITCH_FRAME = 1 / 30, -- one slice lasts two of these
	ZAP_FADE = 0.35, -- s: a zapped clone flickers out
	MANNEQUIN_STRIDE = 3, -- studs per leg-swing cycle of the rigid mannequin

	-- Look (A2)
	DRIFT_DEGREES = 25, -- solo only: older runs drift this far toward violet (MASTERPLAN §6.5 #4)
	GLOW_SIZE = 4.4, -- studs across the floor-glow canvas (the disc fills GLOW_DISC of it)
	GLOW_DISC = 0.72,
	GLOW_BRIGHTNESS = 1.6, -- SurfaceGui Brightness (LightInfluence 0: unlit, no light object)
	GLOW_ALPHA = { 0.55, 0.72, 0.84 }, -- inner core, middle, outer disc
	GLOW_RING_ALPHA = 0.45, -- the disc's rim at rest
	PRINT_SECONDS = 0.35, -- "tape print": the clone builds up from the feet
	PRINT_RING_FROM = 0.35, -- the floor ring grows from this share of the canvas to all of it
	PRINT_BAND_ALPHA = 0.25, -- the scan band at the start of the print (fades to 1 at the top)
	PILL_SIZE = { 50, 26 }, -- px: the numbered pill over the head
	PILL_OFFSET = 2.4, -- studs above the head
	-- Busted: tape-ribbon burst + sparks, <= 30 particles in all (roblox_quality §5.6)
	RIBBON_COUNT = 22,
	SPARK_COUNT = 8,
	ZAP_SPARKS = 16,
	RIBBON_FALLBACK = "rbxasset://textures/particles/sparkles_main.dds", -- until EH_FX_Ribbon resolves

	-- Carried loot (Heist/WorldView): studs above the carrier point. A live player's point is the root
	-- (loot rides on the head); a clone's is its hands minus this (EchoView.carryPointOf).
	CARRY_LIFT = 2.6,

	-- Your live character (G1): client-only warm rim and ground ring, so dark outfits read on dark floors.
	HALO_RIM_ALPHA = 0.35, -- Highlight outline (fill off)
	HALO_LIGHT_RANGE = 7, -- one warm PointLight behind and above you (tiers 1-2 only)
	HALO_LIGHT_BRIGHTNESS = 0.8,
	HALO_LIGHT_OFFSET = { 0, 2.5, 2 },
	HALO_RING_SIZE = 4.2,
	HALO_RING_ALPHA = 0.35,
	HALO_RAY = 12, -- studs down to find the floor under you
}

-- Presentation shell (PLAN_STEAM_PLUS §3.4, §4.1 W7, §4.2 C2 + C4, §5; premium G1, H1, H4; POLISH §4.6):
-- the branded loading card (ReplicatedFirst), the first-join title beat, the van-door wipe between
-- garage, heist and results, and the first-visit level intro. Pure timing in Heist/PresentPlan
-- (tests/unit/HeistPresent.spec.luau). The loading card runs before ReplicatedStorage arrives, so
-- its own numbers live in ReplicatedFirst/Brand; LOADING mirrors them and the spec asserts they match.
Config.Presentation = {
	LOADING = {
		REEL_PERIOD = 1.2, -- s per turn of the reel (static under reduced motion)
		FADE_SECONDS = 0.3, -- the card fades out over this on the first built frame (garage)
		MAX_SECONDS = 12, -- watchdog: the card goes after this unless the client holds it ...
		HOLD_MAX_SECONDS = 30, -- ... and after this even when held (a stuck server never traps anyone)
		ORDER = 200, -- ScreenGui.DisplayOrder (above every game gui)
	},
	PRELOAD_MAX_SECONDS = 1.5, -- the client preloads the HUD's first-frame images and fonts for this long at most
	CONTROL_LIMIT_SECONDS = 10, -- premium G1 / MASTERPLAN §7.5: control within 10 s of the first frame
	-- Heist/FirstTime asks Data.Snapshot again while the profile is still loading (the remote allows 1/s).
	SNAPSHOT_TRIES = 8,
	SNAPSHOT_RETRY_SECONDS = 1,
	-- §3.4 title beat (first join only, any input skips it): the wordmark splits into three offset
	-- copies on the clone arpeggio, then the van doors open onto L1. It never delays control: the
	-- doors are open when the run's transition ends, cutting the beat short if the server is fast.
	TITLE = {
		SECONDS = 3, -- the whole beat
		SPLITS = { 0.45, 0.8, 1.15 }, -- s: copy k leaves the stack (one arpeggio note each)
		SPLIT_SECONDS = 0.35, -- each copy's slide (the emphasis curve)
		STEP = { 11, 8 }, -- design px per copy: copy k rests at k * STEP behind the white mark
		NOTES = { 0, 2, 3 }, -- the arpeggio steps (Config.Audio.ARPEGGIO_STEPS, 0-based) per split: C, E, G
		FADE_SECONDS = 0.15, -- the title fades off the closed doors, then they open
		ORDER = 201, -- just above the loading card it replaces
	},
	-- §4.1 W7 / C4 van-door wipe: two ink panels. Close + open = 0.55 s (<= 0.6, premium H4).
	DOORS = {
		OPEN_SECONDS = 0.3,
		CLOSE_SECONDS = 0.25,
		FADE_SECONDS = 0.15, -- reduced motion: a crossfade instead of the slide
		HOLD_MAX_SECONDS = 6, -- closed doors waiting for a heist that never came open again by themselves
		ZINDEX = 30, -- in the HUD's fx layer: above the HUD, under the Line-up caption (40) and the stamps (54)
		SEAM = 4, -- px: the lighter seam where the two panels meet
		HANDLE = { 10, 64 }, -- px: each panel's handle bar (width, height)
	},
	-- §4.2 C2 level intro (first entry to each level, once per account; never on L1): the camera
	-- glides plates -> doors -> loot (the Party: Gus dozing) inside the run's transition, then the
	-- run-start beat eases back to you. Budget-driven: with a short transition it keeps fewer stops.
	INTRO = {
		HOLD = 0.15, -- s on the first stop while the doors part
		HOP = 0.6, -- s per hop when the transition has room
		HOP_MIN = 0.3, -- a hop is never faster than this (stops are dropped instead)
		EASE_BACK = 0.4, -- the run-start beat's ease from the last stop to you
		MAX_STOPS = 6,
		FOCUS_LIFT = 1.5, -- studs above a plate or door base the camera looks at
	},
}

-- Onboarding and help (PLAN_STEAM_PLUS §6, §8.4; WALKTHROUGH P0-2, P0-4, P1-6, P1-7; premium
-- G2, G4). The rules live in Shared/Heist/Help (pure, so the sim bots check them); the client
-- side in Hud/Hints and Heist/FirstTime; Relaxed in Levels/Relaxed + Sim/HeistSim.
Config.Onboarding = {
	-- Stuck help after L1: "Show me?" after this many runs in a row with no progress (no new
	-- plate held by a clone, no goal banked).
	SHOW_ME_RUNS = 2,
	LEVEL_LINE_STUCK_RUNS = 2, -- runs without a bank before the level line comes back
	-- A deck clone counts for a ghost step's plate when it reaches it at most this many seconds
	-- after the solution's clone did (later: "redo it like this").
	GHOST_LATE_SLACK = 3,
	GHOST_FADE_SECONDS = 0.6, -- the chalk ghost fades out after its step
	GHOST_HOLD_SECONDS = 1.2, -- and stands at the end of its step this long first
	GHOST_DASH_SPACING = 1.2, -- studs between the dashes of its chalk trail
	GHOST_DASH_MAX = 60, -- trail dashes kept at once (the oldest is reused)
	GHOST_ALPHA = 0.82, -- the figure's fill transparency (the chalk outline carries it)
	-- Relaxed (§6.1 item 5): Gus walks at this share of his speed (runs +50% and detection x2
	-- are Config.Rec.RELAXED_LENGTH_MULT and Config.Sim.RELAXED_DETECT_MULT; no Diamond medal).
	RELAXED_GUARD_SPEED_MULT = 0.75,
	-- The free first catch (Config.Sim.FIRST_HEIST_GRACE_MULT detection x2) goes to the first
	-- heists that have a guard (WALKTHROUGH P1-6), not to L1: plays of guarded launch levels below
	-- this count get it.
	GRACE_GUARD_HEISTS = 2,
	-- The daily vault opens once this launch level is cleared (PLAN D4, WALKTHROUGH P1-7).
	DAILY_UNLOCK_LEVEL = "cs4_night_clerk",
	-- First-time beats (premium G2): callers within this many seconds of a kind's first call all
	-- get `true`, so the world and the HUD can both play the bigger version of one moment.
	FIRST_TIME_WINDOW = 1.5,
	FIRST_CLONE_LINE_SECONDS = 4, -- "That's you. It copies you." at the first run with a clone
	GUS_INTRO_SECONDS = 4, -- "That's Gus. Don't wake him." at the first party run
	FIRST_PLATE_POP = 1.35, -- the objective line pops from this scale on the first plate press
	FIRST_REWIND_POP = 1.5, -- REWIND pops from this scale on the first rewind
	FIRST_BANK_STAMP_SECONDS = 1.4, -- "+$100!" stamp on the first bank (later banks: a toast)
	-- The finger pointer (§6.2) on REWIND and GRAB the first time each is the right move.
	POINTER_SIZE = 46, -- px at 1x
	POINTER_PERIOD = 0.9, -- s per tap
	POINTER_TRAVEL = 14, -- px it moves in toward the button on each tap
	ADVICE_DELAY = 0.15, -- s after the failure event before its counterplay line (<= 1 s, G4)
	-- First person (PLAN_FIRST_PERSON wave C). The look cue: while your L1 clone ("YOU, 10 SEC AGO") or the chalk
	-- ghost is out of view, a finger at the screen edge points the way (behind you: at the bottom, on its side).
	LOOK_CUE_INSET = 0.12, -- share of the half-screen kept clear at the edges (the finger stays inside it)
	LOOK_CUE_MARGIN = 0.06, -- a target this far inside the frame's edge (share of the half-screen) still cues
	LOOK_CUE_SECONDS = 6, -- the L1 clone cue's longest stretch after control returns (it also ends on the plate)
	-- The chalk ghost never starts inside your camera: in first person it starts from the first point of its
	-- walk at least this far in front of your eyes (studs, along your look), within the first GHOST_FP_SKIP_MAX s.
	GHOST_FP_AHEAD = 3,
	GHOST_FP_SKIP_MAX = 2.5,
	-- The L1 clone's "YOU, 10 SEC AGO" label in first person: studs over its head anchor (3.6 in the other
	-- cameras), so it is in frame from a few studs behind the clone as it walks out of you.
	YOU_LABEL_FP_LIFT = 1.5,
}

-- Performance track (PLAN_STEAM_PLUS §4.7, MASTERPLAN §6.8 / §8.6, roblox_quality §1.4 / §6.4; docs/PERF.md).
-- Budgets per runtime tier (Config.Heist.PERF_TIERS: the PerfSample governor in Heist/Telemetry steps it down
-- when frames stay slow and back up after a sustained good stretch). A client starts where its device suggests
-- (START below: device class, quality level, screen, a loading-card frame probe); the phone class a tier is written
-- for: 1 quality = high phone 6 GB+ / PC, 2 balanced = mid Android ~4 GB, 3 performance = low
-- Android 2-3 GB at 30 fps, 4 minimum = a phone still over 33 ms at tier 3. Read through the pure
-- Shared/Heist/Budget (tests/unit/HeistBudget.spec.luau checks the numbers against each other).
Config.Perf = {
	TIERS = {
		{ -- 1 quality
			drawCalls = 450, -- busiest view (Big Score, 4 players, 12 clones, 2 guards)
			tris = 450000,
			lights = 10, -- local lights in one view (Config.Lighting.VIEW_RADIUS): the level's 9 + your halo (PC: 12)
			shadowed = 2,
			liveParticles = 360, -- MASTERPLAN §6.8 (touch)
			highlights = 10, -- 4 clone groups + your rim + 5 others
			cloneGlows = 12, -- clone floor glows drawn at once (your own first, then the nearest)
			pillDistance = 40, -- studs: the clone pill's BillboardGui.MaxDistance
			lineupLabels = 1, -- Line-up BillboardGuis (LineupDirector's "◀ ME" label)
			trails = true,
			haloLight = true, -- Heist/PlayerHalo's warm PointLight on your character (no shadows)
			particleScale = 1, -- bursts (ribbons, sparks, coins, gold rain, dust) x this
			snowAlive = 240, -- falling snow alive at once (rate x lifetime)
			lightKindsOff = {}, -- KitPlan lamp kinds switched off (LightDirector)
		},
		{ -- 2 balanced
			drawCalls = 350,
			tris = 300000,
			lights = 9,
			shadowed = 2,
			liveParticles = 360,
			highlights = 10,
			cloneGlows = 12,
			pillDistance = 40,
			lineupLabels = 1,
			trails = false,
			haloLight = true,
			particleScale = 1,
			snowAlive = 240,
			lightKindsOff = { "street", "wash" }, -- the Big Score's busiest view: 8 + your halo = 9
		},
		{ -- 3 performance: recipe C "Soft Toybox"
			drawCalls = 250,
			tris = 150000,
			-- roblox_quality §6.4 asks 6; recipe C (§1.4) allows 6-8. The plate signals and the hero stay, so the
			-- Big Score's vault hall keeps 8 (every other level <= 4); tier 4 reaches 6.
			lights = 8,
			shadowed = 0,
			liveParticles = 150,
			highlights = 5, -- 4 clone groups + your rim, others off
			cloneGlows = 6,
			pillDistance = 28,
			lineupLabels = 1,
			trails = false,
			haloLight = false,
			particleScale = 0.5,
			snowAlive = 60,
			lightKindsOff = { "street", "accent", "wash" }, -- their bulbs and floor pools stay (unlit, no light object)
		},
		{ -- 4 minimum
			drawCalls = 200,
			tris = 120000,
			lights = 6,
			shadowed = 0,
			liveParticles = 100,
			highlights = 2, -- your own clones' group + your rim
			cloneGlows = 3,
			pillDistance = 20,
			lineupLabels = 1,
			trails = false,
			haloLight = false,
			particleScale = 0.35,
			snowAlive = 40,
			lightKindsOff = { "street", "accent", "room", "wash" },
		},
	},
	-- Recipe C "Soft Toybox" (roblox_quality §1.4): LightDirector switches the Lighting service to it from this
	-- tier and restores the project file's recipe A when the governor steps back up. LightingStyle is set in a
	-- pcall (a script may not be allowed to; docs/PERF.md has what the engine said); the rest is scriptable.
	SOFT_TOYBOX_TIER = 3,
	SOFT_TOYBOX = {
		Lighting = {
			LightingStyle = "Soft",
			PrioritizeLightingQuality = true,
			Brightness = 1.8, -- recipe A + 0.2 (BIG: A is 1.6)
			ColorShift_Top = { 170, 190, 255 },
			Ambient = { 128, 132, 162 }, -- BIG: recipe A's bluer, less pink fill (+10)
			OutdoorAmbient = { 160, 170, 204 },
			EnvironmentDiffuseScale = 0.3,
			EnvironmentSpecularScale = 0,
			ExposureCompensation = 0.35, -- WORLD 2.0: recipe A's 0.4 less the Soft style's flatter fill
			GlobalShadows = false, -- no sun shadow pass on low phones (was HeistClient's tier >= 3 rule)
		},
		Bloom = { Intensity = 0.9, Size = 24, Threshold = 1.0 }, -- Lighting.Bloom (the project file's)
		ColorCorrection = { Contrast = 0.22, Saturation = 0.12 }, -- Lighting.ColorCorrection (BIG: A + 0.02)
		-- Lighting.Atmosphere: thinner haze on low phones (a "black fog" is reported at the lowest quality levels,
		-- roblox_quality §1.1; WORLD 2.0 keeps the distance a light haze there too)
		Atmosphere = { Density = 0.2, Haze = 1.4 },
		LIGHT_RANGE_MAX = 24, -- studs: every level light's Range is clamped to this ("Range 16-24")
	},
	BLOOM_OFF_TIER = 4, -- roblox_quality §6.4: Bloom off on the lowest phones (ColorCorrection stays)
	-- Bursts: base counts live with their effect (Config.Clone.RIBBON_COUNT / SPARK_COUNT / ZAP_SPARKS,
	-- Config.WorldFx.COINS / DOOR_DUST, Config.Heist.LASER_SPARKS); this is the gold rain's (MomentDirector).
	GOLD_RAIN = 40,
	BURST_MIN = 2, -- a scaled burst never drops below this (it must still read)
	GLOW_RECHECK_SECONDS = 0.5, -- EchoView re-picks which clones keep their floor glow (Budget.glowSet)
	GARAGE_WAIT_SECONDS = 15, -- JobBoard waits this long for a garage that has not streamed in yet
	-- The worst moment the particle budget is checked against (Budget.worstParticles): snow + these at once.
	WORST_MOMENT = { "ribbons", "sparks", "coins", "goldRain", "doorDust", "laserSparks" },
	-- Measured / estimated costs (docs/PERF.md; tests/perf_engine.luau prints the measured ones).
	AVATAR_TRIS_EST = 7000, -- a catalog R15 avatar with hair and 2-3 accessories (not readable from Luau)
	MANNEQUIN_TRIS = 216, -- 18 box parts

	-- Clone LOD (roblox_quality §6.4; Budget.cloneFar / Budget.lineupLight): from TIER, a clone drawn from an
	-- avatar template is the textured avatar within NEAR studs of the camera and the 216-tri mannequin in its crew
	-- hue beyond FAR (same pill, glow and owner Highlight); between the two it keeps what it was (hysteresis), so
	-- a clone walking along the edge never flickers. Never your newest clone in the L1 tutorial ("YOU, 10 SEC
	-- AGO"). Line-up figures past the front row use the same distance from the shot's camera (picked once per cut).
	CLONE_LOD = {
		TIER = 3,
		NEAR = 15,
		FAR = 18,
		MANNEQUIN_DRAWS = 3, -- estimate: every mannequin in view batches into a few primitive draws (perf_engine)
	},

	-- The start tier (Budget.startTier / Budget.probeTier, Heist/Telemetry): picked at boot from what a client
	-- script can know, so a low phone is at recipe C before its first run instead of ~70 s of slow frames later.
	-- The governor keeps its hysteresis from there (it may step back up to tier 1: PerfSample.seed).
	START = {
		-- by PerfSample.deviceClass: touch-only devices start balanced, keyboards / pads / headsets at quality
		DEVICE = { desktop = 1, console = 1, vr = 1, tablet = 2, phone = 2, other = 2 },
		-- the player's manual graphics level (UserGameSettings.SavedQualityLevel 1..10; 0 = Automatic says
		-- nothing): <= LOW_MAX starts at least at tier 3, <= MID_MAX at least at tier 2, >= HIGH_MIN at tier 1
		QUALITY_LOW_MAX = 3,
		QUALITY_MID_MAX = 6,
		QUALITY_HIGH_MIN = 8,
		RENDER_LEVELS = 21, -- RenderSettings.QualityLevel's scale (Level01..Level21), mapped to 1..10 when read
		-- a phone whose viewport's short side is under this (px) is an old / cheap screen: one tier lower when
		-- the quality level says nothing
		SMALL_SCREEN_MIN = 340,
		MAX = 3, -- never start below this tier (tier 4 is only for a phone still slow at tier 3)
		-- The frame-time probe while the loading card / title beat is up (cheap frames: a slow card says a lot).
		PROBE_SKIP_SECONDS = 0.5, -- the first frames after boot are load hitches, not the device
		PROBE_SECONDS = 2.5, -- then this long is measured
		PROBE_MIN_FRAMES = 20, -- fewer frames than this (a backgrounded app) and the probe says nothing
		-- judged by the median (boot hitches and texture loads spike a few frames, they do not move it): slower
		-- than 30 fps (Analytics.Perf SLOW_MS: an OS 30 fps cap is not slow) one tier lower, under 20 fps two
		PROBE_SLOW_MEDIAN_MS = 36,
		PROBE_VERY_SLOW_MEDIAN_MS = 50,
	},
}

-- Signature moments (PLAN_STEAM_PLUS §4.4 F1-F5, §4.2 C3, §5; premium F3-F7, H1, H4; POLISH items 12-15
-- and 19; MASTERPLAN §6.6, §7.1, §9.2). Client only: Heist/MomentDirector (8 OF ME, busted view, heist
-- complete, blooper cut, hit-stop, the juice governor), Heist/RewindDirector (the rewind finish),
-- Heist/LineupDirector (snare roll, busted podium); pure maths in Shared/Heist/MomentPlan.
-- Tier numbers are Config.Heist.PERF_TIERS indices (1 = quality .. 4 = minimum).
Config.Moments = {
	-- Hit-stop (premium F3): ONLY these four heavy beats, each this long; none under reduced motion.
	HIT_STOP_SECONDS = 0.066,
	HIT_STOP_BEATS = { rewind = true, busted = true, diamond = true, complete = true },
	-- The juice governor: every effect has a low-tier substitute from LOW_TIER; live particles stay
	-- under the cap (touch: phones and tablets without a keyboard); <= FLASH_MAX full-screen flashes
	-- in any FLASH_WINDOW seconds (MASTERPLAN §7.3 photosensitivity).
	LOW_TIER = 3,
	PARTICLE_CAP_TOUCH = 360,
	PARTICLE_CAP = 900,
	FLASH_MAX = 3,
	FLASH_WINDOW = 1,

	-- The rewind finish (§7.1 picture; roblox_quality §5.2; POLISH §4.4 "Rewind"). Inside the existing
	-- 1.8 / 1.0 / 0.8 s windows: the 66 ms freeze opens it, the path trails reel with the scrub.
	REWIND = {
		FLASH_ALPHA = 0.75, -- the opening white flash (25 %), held for HIT_STOP_SECONDS
		TRAIL_POINTS = 13, -- samples per clone path (12 segments) ...
		TRAIL_POINTS_LOW = 7, -- ... from LOW_TIER (the substitute: a coarser path)
		TRAIL_MAX_CLONES = 12, -- paths drawn (the newest runs when there are more)
		TRAIL_WIDTH = 0.45, -- studs
		TRAIL_LIFT = 0.3, -- studs above the recorded feet
		TRAIL_TRANSPARENCY = 0.2,
		TRAIL_LIGHT_EMISSION = 0.8,
		SCAN_BANDS = 9, -- dark scanline bands across the screen (one gradient, no image)
		SCAN_ALPHA = 0.86, -- the darkest band's transparency
		SCAN_SPEED = 0.35, -- screens per second the bands roll down
		TRACKING_HEIGHT = 5, -- px: the VHS tracking line
		TRACKING_SECONDS = 0.55, -- one sweep down the screen
		TRACKING_JITTER = 6, -- px of sideways tear
		MUFFLE = true, -- the world through an 800 Hz low-pass (Config.Audio.MUFFLE_HZ) while it reels
	},

	-- "8 OF ME" and the swarm moment (§5 row "8 OF ME"; POLISH §4.4; MASTERPLAN §9.2 #5).
	SWARM = {
		DIM = 0.15, -- the world dims 15 % ...
		DIM_IN = 0.1, -- ... in this, and is back by DIM_SECONDS
		DIM_SECONDS = 0.6,
		ROLL_START = 0.15, -- s after the event: the first clone's beat
		ROLL_STAGGER = 0.06, -- 60 ms apart in record order, with the arpeggio's notes
		BEAT_SECONDS = 0.3, -- one pose beat: a hop and a pill flash
		BEAT_HOP = 0.7, -- studs
		CHOIR_GAP = 0.06, -- the choir hit lands this long after the last note
		OUTLINE_FILL = 0.15, -- the owner outline's fill flashes to this and back
		CAM_IN = 0.6, -- the pull-back eases out over this ...
		CAM_HOLD = 1.6, -- ... holds ...
		CAM_OUT = 0.5, -- ... and eases back to play (H1: >= 0.2 s, Sine InOut)
		CAM_PITCH = 45,
		CAM_FOV = 45,
		CAM_SHARE_Y = 0.8, -- every copy also inside 80 % of the half height
		CAM_DISTANCE = { 12, 90 }, -- studs: min, max
		FIGURE_UP = 2.5, -- studs above / below the root used for the fit (head, feet)
		FIGURE_DOWN = 2.8,
		PILL = 34, -- px: the stamp's numbered pills
		PILL_GAP = 6,
		PILLS_MAX = 16,
		PILL_ROW_Y = 0.55, -- the pill row's centre (under the stamp at 0.42)
	},

	-- C3 the busted view (you caught): freeze, the camera eases to Gus, his catch beat, a stamp, one line.
	BUSTED = {
		CAM_IN = 0.6,
		HOLD = 1.3,
		CAM_OUT = 0.4,
		DISTANCE = 16,
		PITCH = 38,
		FOV = 45,
		FOCUS_HEIGHT = 3,
		STAMP_AT = 0.5, -- s after the catch: the BUSTED stamp (then the advice line, Hud/Hints)
	},

	-- Heist complete: the slam, gold rain, the trophy fly-in, then the blooper / Line-up / job sheet.
	COMPLETE = {
		RAIN = 60, -- gold particles in all (pooled emitter; <= 60) ...
		RAIN_LOW = 24, -- ... from LOW_TIER
		RAIN_SECONDS = 1.2, -- emitted over this, in RAIN_BURSTS bursts
		RAIN_BURSTS = 6,
		RAIN_HEIGHT = 14, -- studs above the camera focus
		RAIN_SPREAD = 10, -- studs: the emitter box's half size
		RAIN_LIFETIME = { 1.8, 2.4 },
		RAIN_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds",
		SLAM_DOOR_SECONDS = 0.18, -- every door slams shut this fast (WorldView.slamDoors)
		SLAM_FOV = -2.5, -- degrees: the slam's FOV punch (behind the shake setting) ...
		SLAM_SECONDS = 0.2, -- ... and back over this
		SLAM_FLASH = 0.85, -- a dust-white flash card (transparency), through the flash limit
		TROPHY_DELAY = 0.45, -- s after the slam
		TROPHY_SECONDS = 0.9, -- the flight to the van (screen arc)
		TROPHY_SIZE = 96, -- px at the start
		TROPHY_END = 0.35, -- scale at the van
		TROPHY_ARC = 120, -- px above the straight line
	},

	-- The Line-up (§5 row "Line-up"; premium §6.7): a snare roll landing on the pose, busted clones slumped
	-- on a separate busted podium (never hidden).
	LINEUP = {
		SNARE_SECONDS = 0.6,
		PODIUM_GAP = 2.5, -- studs between the crew and the busted podium
		PODIUM_HEIGHT = 0.6,
		PODIUM_DEPTH = 2.6,
		SLUMP_TILT = 14, -- degrees forward
		SLUMP_SINK = 0.15, -- studs
		SHRUG_HOP = 0.2, -- studs: the sheepish shrug on the beat
	},

	-- The blooper cut (MASTERPLAN §9.2 #2 "MY CLONE BETRAYED ME"): the final run's best clone failure
	-- replays first, from the recordings the client holds.
	BLOOPER = {
		LEAD = 3, -- s of the clone's run before the failure
		TAIL = 0.8, -- s after it
		MAX = 4, -- the whole cut never runs longer (skippable)
		START_DELAY = 0.9, -- s after Over: the HEIST COMPLETE stamp reads first
		SKIP_AFTER = 0.5,
		WEIGHTS = { Busted = 3, Zapped = 2, Stuck = 1 },
		CAM_DISTANCE = 20,
		CAM_PITCH = 40,
		CAM_FOV = 45,
		CAM_FOLLOW = 6,
		CAPTION_SIZE = 64, -- px (the display face)
	},
}

-- The Rookie (PLAN_FIRST_PERSON "CH"; CH track): the player character. Every player spawns as a Rookie in their
-- crew colour and outfit (server Heist/Characters + Heist/Rookie); clones are copies of your Rookie (Heist/Avatars).
-- Art: assets/blender/rookie.py (kit groups Rookie, Rookie_Faces, Rookie_Outfits, Rookie_Viewmodel), data in
-- Shared/Heist/RookieData (generated). Outfit data: the profile's `outfit` (Schema), validated by Shared/Heist/Outfit
-- and changed through the existing Data.Equip remote (an outfit slot + an OUTFIT id).
Config.Rookie = {
	KIT_FOLDER = "CharacterKit", -- ReplicatedStorage folder: Rookie (template), Rookie_Viewmodel, Outfits, Faces
	HIP_HEIGHT = 2, -- Humanoid.HipHeight: the root part's centre 3 studs up (the sim's rootHeight); legs are art
	ROOT_SIZE = { 2, 2, 1 }, -- HumanoidRootPart
	KIT_WAIT_SECONDS = 20, -- the first spawn waits this long for the kit, then spawns a block Rookie
	RESPAWN_SECONDS = 3, -- after a death (CharacterAutoLoads is off: the server spawns everyone)
	SPAWN_RETRIES = 3, -- LoadCharacterAsync attempts per spawn
	-- Faces (one shows): what a moment shows and for how long (s); clones follow their pose (POSE_FACE).
	FACE_SECONDS = { smug = 2.5, shocked = 1.6, busted = 3 },
	POSE_FACE = { carry = "smug", busted = "busted", stuck = "shocked" },
	-- Outfit slots (Data: heist.outfit slot -> id). DEFAULT is what a new profile and every repair falls back to.
	SLOTS = { "cap", "scarf", "sweater", "gloves", "mask" },
	DEFAULT_OUTFIT = {
		cap = "Cap_Flat",
		scarf = "Scarf_Long",
		sweater = "Sweater_Stripes",
		gloves = "Gloves_Knit",
		mask = "Mask_None",
	},
	-- id -> slot, variant (RookieData.outfit key; "" = nothing), name, and how it unlocks: free, or
	-- unlock = { stars = n } (total medal + daily stars, Progress.totalStars) or { trophy = id } (Config.Data.Trophies).
	OUTFIT = {
		Cap_Flat = { slot = "cap", variant = "Flat", name = "Flat Cap", free = true },
		Cap_Beanie = { slot = "cap", variant = "Beanie", name = "Beanie", free = true },
		Cap_Bobble = { slot = "cap", variant = "Bobble", name = "Bobble Hat", unlock = { stars = 6 } },
		Cap_Trapper = {
			slot = "cap",
			variant = "Trapper",
			name = "Trapper Hat",
			unlock = { trophy = "Trophy_NightClerk" },
		},
		Scarf_Long = { slot = "scarf", variant = "Long", name = "Long Scarf", free = true },
		Scarf_Chunky = { slot = "scarf", variant = "Chunky", name = "Chunky Scarf", free = true },
		Scarf_Bandana = { slot = "scarf", variant = "Bandana", name = "Bandana", unlock = { stars = 3 } },
		Scarf_Knot = {
			slot = "scarf",
			variant = "Knot",
			name = "Knotted Scarf",
			unlock = { trophy = "Trophy_TwoDoors" },
		},
		Sweater_Stripes = { slot = "sweater", variant = "Stripes", name = "Breton Stripes", free = true },
		Sweater_Block = { slot = "sweater", variant = "Block", name = "Colour Block", unlock = { stars = 9 } },
		Gloves_Knit = { slot = "gloves", variant = "Knit", name = "Knit Gloves", free = true },
		Gloves_Leather = {
			slot = "gloves",
			variant = "Leather",
			name = "Leather Gloves",
			unlock = { trophy = "Trophy_BackRoom" },
		},
		Mask_None = { slot = "mask", variant = "", name = "No Mask", free = true },
		Mask_Eye = { slot = "mask", variant = "Eye", name = "Eye Mask", unlock = { stars = 1 } },
	},
	GLOVES = { Gloves_Knit = "#2A2D52", Gloves_Leather = "#6E4B3A" }, -- glove colours (hands + cuffs)
	BLOCK_COLOURS = { -- the block Rookie (no kit): body part kind -> colour
		Head = "#D09673",
		UpperTorso = "#D8C8A8",
		LowerTorso = "#4E5675",
		Arm = "#D8C8A8",
		Hand = "#2A2D52",
		Leg = "#4E5675",
		Foot = "#5A493E",
	},
	-- The long scarf's swaying tail (Shared/Heist/ScarfMath, client Heist/ScarfSway): a cheap Lua secondary motion
	-- on your character and your clones' rigs (welds of Rookie_Scarf_Long_Tail1 / _Tail2), off from OFF_TIER.
	SCARF = {
		PIECES = { "Rookie_Scarf_Long_Tail1", "Rookie_Scarf_Long_Tail2" }, -- hinge order (root first)
		OFF_TIER = 3, -- perf tiers >= this: the tail holds the modelled pose (no Lua per frame)
		MAX_RIGS = 8, -- characters swayed a frame at most (the nearest to the camera)
		RANGE = 70, -- studs from the camera
		RUN_SPEED = 14, -- studs/s at which the tail streams out as modelled
		DROOP = 62, -- degrees the root segment hangs at rest (+ = down)
		DROOP2 = 28, -- the end segment's extra hang at rest
		VERTICAL = 2.2, -- degrees per stud/s of vertical speed (a fall lifts it, a jump drops it)
		VERTICAL_MAX = 30,
		LATERAL = 2.4, -- degrees per stud/s of strafe (it swings the other way)
		TURN = 9, -- degrees per rad/s of turn (it trails to the outside)
		YAW_MAX = 40,
		PITCH_MIN = -20,
		PITCH_MAX = 75,
		FOLLOW = 0.6, -- the end segment's share of the root's swing
		FLUTTER = 7, -- degrees of flutter on the end segment at full speed
		FLUTTER_HZ = 2.3,
		STIFFNESS = 70, -- spring k (1/s^2): about 1.3 Hz
		DAMPING = 9, -- spring c (1/s): a little under critical, so a stop swings once
		END_STIFFNESS = 1.6, -- the end segment is lighter: stiffer, quicker
		MAX_DT = 0.1, -- s of motion integrated a frame at most (a hitch never flings it)
		SUBSTEP = 1 / 60,
	},
	-- The Rookie's own locomotion (REVIEW_STEAM_PLUS #6): clips authored for his proportions by the pure
	-- Shared/Heist/RookieMoves (legs by 2-bone IK on planted feet), baked by tools/rookie_clips.luau and uploaded
	-- as Animation assets (python3 tools/anim_upload.py --rookie build/rookie_clips; ids in Shared/Heist/RookieClips).
	-- The player's Animate plays them (server Heist/Characters + client Heist/RookieAnim) and the clones play the
	-- same clips (Heist/Rigs, CloneGait mirrors the Animate's speed blend), so a clone walks exactly like you.
	-- Re-bake and re-upload (new ids) after changing a number here.
	ANIM = {
		-- The R15 Animate's speed maths (vault "The Default Animate Script"): runSpeed = speed / SCALE x ROOT_MOTION;
		-- walk alone at runSpeed <= 0.5 (walk rate = runSpeed / 0.5), blend to run alone at 1 (run rate = runSpeed).
		-- So the walk clip covers WALK_BASE = 6.4 studs/s at rate 1 and the run RUN_BASE = 12.8: the strides below.
		SCALE = 16,
		ROOT_MOTION = 1.25,
		WALK_NORM = 0.5,
		RUN_NORM = 1,
		SMALL = 1e-4, -- the Animate's "small but not zero" weight
		CYCLE = 0.4, -- s per walk and per run cycle at rate 1 (equal, so the Animate's blend stays in step)
		KEYS_PER_SECOND = 60, -- bake density (linear keys)
		KEYS_PER_SECOND_SLOW = 20, -- idle and look (slow motion)
		MAX_REACH = 0.965, -- studs hip to ankle (thigh 0.5 + shin 0.48): a planted leg never straightens past this
		FOOT_TOE = { 0, -0.5, -0.9 }, -- the boot's toe tip from the ankle (rest, Roblox axes)
		FOOT_HEEL = { 0, -0.5, 0.4 }, -- the heel
		WALK = {
			duty = 0.56, -- share of the cycle a foot is on the floor (> 0.5: both feet down at the switch)
			front = 0.42, -- studs ahead of the hip where the boot lands (flat)
			peelAt = 0.24, -- share of the cycle the boot rolls onto its toe
			peel = 0.75, -- rad of toe roll at lift-off
			lift = 0.3, -- studs the ankle rises in the swing (a bouncy step)
			swingToe = 0.35, -- rad toes up mid-swing
			drop = 0.17, -- studs of crouch (sneaky)
			bob = 0.07, -- bounce: lowest as a foot lands
			sway = 0.05, -- studs over the planted foot
			roll = 0.06,
			yaw = 0.16, -- pelvis turn with the legs; the chest turns back (cocky swagger)
			chestYaw = -0.26,
			lean = 0.16,
			armSwing = 0.62, -- rad fore-aft
			armOut = 0.46, -- arms wide
			elbow = 0.45,
			elbowSwing = 0.3,
			headUp = 0.1, -- chin up (smug)
			headTilt = 0.07,
		},
		RUN = {
			duty = 0.27,
			front = 0.34,
			peelAt = 0.1,
			peel = 1.1,
			lift = 0.78, -- high knees and a heel kick: the funny sprint
			kick = 0.42, -- studs the foot flicks back early in the swing
			swingToe = 0.2,
			drop = 0.16,
			bob = 0.1,
			yaw = 0.18,
			chestYaw = -0.3,
			lean = 0.44, -- root + waist share it
			armSwing = 1.35, -- big pumps
			armOut = 0.2,
			elbow = 1.45,
			elbowSwing = 0.35,
			headUp = 0.14, -- world chin-up: the head keeps the eyes forward over the lean
		},
		IDLE = { length = 3.2, breath = 0.03, sway = 0.06, roll = 0.04, headTilt = 0.09, headUp = 0.06 },
		LOOK = { length = 4.0, yaw = 0.85, chest = 0.22 },
		JUMP = { length = 0.36, tuck = 0.14 },
		FALL = { length = 0.5, flail = 0.35 },
		-- minFall: s in the air before a land plays; at fullSpeed studs/s and over, its weight drops by runShare
		LAND = { length = 0.42, squash = 0.3, minFall = 0.32, fade = 0.05, fullSpeed = 12.8, runShare = 0.7 },
		FADE = 0.15, -- cross-fade into a clone's land / idle variant
		IDLE_WEIGHTS = { idle = 9, look = 1 }, -- the Animate's idle set: the look-around about one loop in ten
		ANIMATE_WAIT = 5, -- s to wait for a spawned character's Animate script
	},
	PORTRAIT = { -- crew cards: a ViewportFrame of your clone template's head (Hud/Deck)
		FOV = 30,
		DISTANCE = 4.6, -- studs from the head centre
		LIFT = 0.15, -- studs: aim a little above the head centre (the cap)
		YAW = 18, -- degrees: a 3/4 turn
	},
}

-- BIG buildings (PLAN_FIRST_PERSON §5 "BIG", 2026-11-13; docs/audit/LEVELS.md §11): every heist building is a 3-5
-- storey block over its playable ground floor, with a real ceiling over the playable rooms and a roof, and a
-- camera-aware cut-away (client Heist/CutAway) so the diorama, classic and presentation shots still see in. The plan
-- is the pure server Heist/TowerPlan; server Heist/Overhead builds it into the level's "Overhead" model. Visual only:
-- CanCollide, CanTouch, CanQuery and CastShadow off (the sim, the server's collisions, the cameras' raycasts and the
-- ground floor's light stay exactly as they were). The playable footprint, walls, doors and plates never change.
Config.Big = {
	ENABLED = true,
	CEIL_Y = 12, -- studs above the floor: the ceiling plane = the kit walls' top = Lamp_Ceiling's pivot (LAMP_HANG_Y)
	CEIL_DEPTH = 0.55, -- Ceiling_8x8's depth (its coffered underside is the ceiling plane)
	BAND = 2, -- the band over the wall tops (12 - 14) between the shop and the flats (covers BankFront's 13.9 top)
	STOREY = 10, -- one upper storey (Facade_8x10); storey 10-12 with a ~5-stud character (worldbuilding brief)
	WALL_DEPTH = 1.3, -- Facade_8x10_Body: its outer face 0.3 in from the module's front plane, 1.0 thick
	PARAPET = 1.4, -- studs of parapet over the crown cornice (the roof's snow sits behind it)
	ROOF_LIFT = 0.9, -- the roof's snow over the top storey's line (inside the parapet)
	CORNICE_H = 1.98, -- Cornice_8 with its snow
	GLASS = {
		lit = { 246, 192, 162 }, -- Bulb Warm Neon (eh_palette.NEON): a lit flat behind its curtains
		dark = { 74, 84, 130 }, -- an unlit window: a blue-night pane (V 51 %: dark, never near-black)
		litShare = 0.58, -- of the windows (seeded per building)
		curtainShare = 0.55, -- of the lit windows
		inset = 1.0, -- studs from the module's front plane to the pane (behind the mullions)
	},
	SNOW = { 196, 200, 226 }, -- roof snow (Config.Backdrop.TOWN.COLORS.roofSnow)
	TRIM = { 226, 214, 190 }, -- parapet coping (Warm Marble light)
	-- Per location (KitPlan.location: Clone Party builds as the Toy Shop in its Christmas dressing). body: the facade
	-- slab colours (one per level, seeded), mid-to-high values: a 40-stud face must never fall into the filmic toe.
	-- roof: rooftop pieces at fractions of the roof's half extents (x, z; +z = the street side).
	STYLES = {
		CornerShop = { -- a brick tenement: fire escapes, a water tank, chimneys and an antenna on the roof
			kind = "tenement",
			storeys = 4,
			body = { { 150, 76, 60 }, { 164, 92, 70 }, { 140, 70, 66 } },
			band = { 120, 62, 54 },
			fireEscape = true,
			roof = {
				{ piece = "Roof_WaterTank", at = { 0.35, -0.35 }, yaw = 0 },
				{ piece = "Roof_Chimney", at = { -0.62, -0.25 }, yaw = 0 },
				{ piece = "Roof_Chimney", at = { 0.62, 0.45 }, yaw = 90 },
				{ piece = "Roof_Antenna", at = { -0.3, 0.55 }, yaw = 30 },
			},
			sign = { kind = "blade", w = 3.2, h = 11, color = { 140, 47, 75 }, text = { 255, 226, 150 } },
		},
		ToyShop = { -- a grand department store: cream and raspberry, a big lit sign, the giant toy soldier on its roof
			kind = "store",
			storeys = 4,
			body = { { 236, 210, 168 } },
			band = { 200, 92, 132 },
			soldier = { scale = 2.4, at = { 0.7, 0.75 }, yaw = 180 }, -- ToySoldier on the roof edge (street side)
			roof = { { piece = "Roof_Chimney", at = { -0.6, -0.5 }, yaw = 0 } },
			sign = { kind = "board", w = 30, h = 6, color = { 140, 47, 75 }, text = { 255, 226, 150 } },
		},
		Bank = { -- a stone neoclassical block: a giant order of columns, a pediment with a clock
			kind = "bank",
			storeys = 3,
			body = { { 214, 196, 160 } },
			band = { 186, 168, 140 },
			columns = 6, -- Column_2x12 scaled into a giant order over the street front's centre
			columnScale = { 1.5, 2.5, 1.5 },
			roof = { { piece = "Roof_Chimney", at = { 0.6, -0.6 }, yaw = 0 } },
			sign = { kind = "frieze", w = 24, h = 2.2, color = { 186, 168, 140 }, text = { 60, 50, 70 } },
		},
	},
	-- Client Heist/CutAway: roofs, ceilings and upper floors between the camera and its subject hide locally
	-- (LocalTransparencyModifier) in diorama, classic and presentation shots once the camera is above the ceiling.
	-- First person never hides them.
	CUT = {
		MARGIN = 0.5, -- studs: the camera counts as above the ceiling past CEIL_Y + MARGIN
		INSIDE_PAD = 1.5, -- studs: a subject this close outside the footprint still counts as inside
		SECONDS = 0.18, -- fade time (in and out)
		HZ = 30, -- decisions a second (the fades step every frame)
		EYE_WITHIN = 1.5, -- studs: the camera this close to the first-person eye is "in your eyes" (never cut)
		LOOK_HEIGHT = 3, -- studs above the floor: a presentation shot's subject = its look ray at this height
		LOOK_MAX = 400, -- studs along the look ray
		SUBJECT_HEIGHTS = { 0.5, 4.5 }, -- studs above the subject's floor: the occluder test casts to feet and head
	},
	-- Per building at tier 1 (unit spec on every level; perf_engine counts the real build). Tier >= DETAIL_OFF_TIER
	-- hides the "detail" layer (the back and side faces' trims and crowns, the curtains: a phone starts at tier 2) and
	-- from FINE_OFF_TIER the "fine" and "xmas" layers (coffered ceiling tiles: a flat slab takes over; fire escapes,
	-- rooftop props, light strings) on the client (Heist/CutAway).
	BUDGET = { instances = 560, draws = 26, tris = 72000, lights = 0 },
	DETAIL_OFF_TIER = 2,
	FINE_OFF_TIER = 3,
}

-- Interiors (INTERIORS track, docs/audit/REVIEW_STEAM_PLUS.md gaps 8, 9 and 12; STYLE_BIBLE §19): eye-level props in every
-- room (server Heist/DecorPlan, pure; kit assets/blender/interior.py), each level its own shop (a theme: the shop's
-- name on the fascia and the blade sign, a hero window display, a wall frieze, the ceiling colour and the room light),
-- and the first-person light look (the floor pools fade at grazing angles, client LightDirector; a dimmer tintable
-- ceiling; warm wall washes). Visual only: every prop is CanCollide / CanQuery / CanTouch off and planned clear of every
-- plate, door, loot point, hide, laser, switch, spawn, nav point, Gus's route, the van zone, the floor cables and the
-- sightlines from the crew seats (tests/unit/HeistInterior.spec.luau, incl. a walk-grid route check).
Config.Interior = {
	ENABLED = true,
	-- Client (Heist/LightDirector): parts with EH_Layer "decor" (the props, the teller brass and the frieze) hide from
	-- this tier; the hero display, the ceiling colour, the room light and the fascia stay at every tier.
	DECOR_OFF_TIER = 3,
	-- First-person pools (client LightDirector): a pool's strength x a share from `min` (the camera looks across it at
	-- an elevation of `from` degrees or less over its centre, e.g. a pool 10+ studs ahead of the 3.8-stud eye) to `max`
	-- (`to` degrees or more: standing in it), smoothstep between. `max` is 1 once the camera is `high` studs or more
	-- over the floor (diorama, classic, presentation shots keep the pools as they were); `hz` updates a second.
	POOL_FADE = { from = 12, to = 40, min = 0.3, max = 0.62, high = 7, hz = 15 },
	-- Per level at tier 1 (unit spec; perf_engine counts the real build): props, hero, frieze and brass together.
	BUDGET = { tris = 22000, instances = 90 },
	-- Placement (studs). WALL_GAP: a prop's back to the kit wall face (the kit wall is 2 thick, centred on the sim
	-- line). STEP: candidate spacing along a wall. SPREAD: props of one room prefer slots far from each other.
	WALL_GAP = 0.12,
	KIT_WALL_HALF = 1.0,
	WALL_PAD = 0.6, -- every wall's sim box grows this much for the overlap test (the kit wall's extra half)
	STEP = 1.0,
	PROP_GAP = 0.6, -- between two props
	MAX_DEPTH = 3.4, -- floor props deeper than this never stand on a wall (keeps the room's middle open)
	-- Keep-outs (2D, studs). door: along the door's normal (both sides) / across it (its frame).
	CLEAR = {
		plate = 1.5,
		doorNormal = 5,
		doorAcross = 1.5,
		doorAcrossWall = 5, -- wall props and the frieze keep this far from a door's centre line ends (frames, lamps)
		loot = 2.2,
		hide = 3.5, -- a hide is walked into: its whole front stays open
		laser = 2,
		switch = 2.5,
		spawn = 3,
		nav = 1.5,
		guard = 2.2, -- Gus's route legs and posts
		van = 1,
		cable = 0.7,
		sight = 1.1, -- the line from crew seat 1 to every plate, door and the goal
		rug = 0.2,
		windowLow = 4.5, -- on a LevelDress window line only props under this height (the sill is 4.85)
	},
	-- Wall props: the height of the piece's bottom over the floor.
	MOUNT = {
		Decor_Poster_A = 5.3,
		Decor_Poster_B = 5.3,
		Decor_WallClock = 8.0,
		Decor_Corkboard_4 = 5.2,
		Decor_CardString_8 = 7.9,
		Decor_CoatHooks_4 = 0, -- the coats hang to 2.6: planned like a floor prop (its footprint is checked)
		Decor_DepositWall_8 = 0,
	},
	FRIEZE = { piece = "Decor_Frieze_8", y = 10.05 }, -- under the crown cove (10.95)
	-- Room kinds per location: floor props in priority order, then wall props. A theme may swap pieces. "front" is the
	-- band behind the street front, "goal" the band holding the goal loot, "back" any other.
	ROOMS = {
		CornerShop = {
			front = {
				floor = {
					"Decor_StockShelf_8",
					"Decor_Fridge_4",
					"Decor_StockShelf_8",
					"Decor_CandyCounter_6",
					"Decor_MagRack_3",
					"Decor_CatBed",
				},
				wall = { "Decor_Poster_A", "Decor_WallClock", "Decor_Poster_B", "Decor_CardString_8" },
			},
			back = {
				floor = { "Decor_Boxes", "Decor_StockShelf_8", "Decor_MopBucket", "Decor_Boxes" },
				wall = { "Decor_CoatHooks_4", "Decor_Corkboard_4", "Decor_WallClock" },
			},
			goal = {
				floor = { "Decor_Desk_6", "Decor_Boxes", "Decor_MopBucket" },
				wall = { "Decor_Corkboard_4", "Decor_CoatHooks_4", "Decor_Poster_B" },
			},
		},
		ToyShop = {
			front = {
				floor = {
					"Decor_ToyShelf_8",
					"Decor_GiftWrap_6",
					"Decor_TrainLoop_6",
					"Decor_ToyShelf_8",
					"Decor_CandyCane_Giant",
					"Decor_CandyCane_Giant",
				},
				wall = { "Decor_Poster_A", "Decor_WallClock", "Decor_CardString_8" },
			},
			back = {
				floor = { "Decor_Boxes", "Decor_ToyShelf_8", "Decor_Boxes" },
				wall = { "Decor_CoatHooks_4", "Decor_Corkboard_4" },
			},
			goal = {
				floor = { "Decor_Desk_6", "Decor_Boxes" },
				wall = { "Decor_Corkboard_4", "Decor_WallClock" },
			},
		},
		Bank = {
			front = {
				floor = { "Decor_Palm", "Decor_Bench_6", "Decor_QueueRope_8", "Decor_Palm", "Decor_Bench_6" },
				wall = { "Decor_WallClock", "Decor_Poster_B" },
			},
			back = {
				floor = { "Decor_DepositWall_8", "Decor_Desk_6", "Decor_Palm", "Decor_Boxes" },
				wall = { "Decor_CoatHooks_4", "Decor_Corkboard_4", "Decor_WallClock" },
			},
			goal = {
				floor = { "Decor_DepositWall_8", "Decor_DepositWall_8", "Decor_Boxes" },
				wall = { "Decor_WallClock" },
			},
		},
	},
	-- Christmas pieces (planned only with the dressing layer).
	XMAS = { Decor_CardString_8 = true, Decor_CandyCane_Giant = true, Xmas_Tree = true },
	-- Bank teller counters carry the brass rail (Decor_BrassRail_8) along their top.
	TELLER_BRASS = "Decor_BrassRail_8",
	-- Each level's own shop. name: the fascia over the entrance and the BIG blade sign. hero: the window display (in
	-- the front room against the street front, beside the entrance). swap: room pieces replaced. frieze / ceiling:
	-- runtime colours of Decor_Frieze_8 and Ceiling_8x8_Tin (the ceiling about 0.6x the wall value in first person).
	-- light: the room lamps' colour(s), pool and brightness (Config.Lighting.LOCATION's role, per level; nil brightness:
	-- LAMP.room's). board / text: the fascia colours.
	THEMES = {
		grocer = {
			name = "PIP'S GROCERY",
			hero = "Decor_Grocer_Fruit",
			frieze = { 58, 118, 82 },
			ceiling = { 70, 54, 48 },
			light = { room = { { 255, 186, 112 } }, pool = { 236, 196, 150 } },
			board = { 36, 74, 54 },
			text = { 255, 226, 150 },
		},
		bakery = {
			name = "SUGAR & CRUMB BAKERY",
			hero = "Decor_Bakery_Cakes",
			swap = { Decor_MagRack_3 = "Decor_Bakery_Cakes" },
			frieze = { 214, 150, 160 },
			ceiling = { 68, 50, 54 },
			light = { room = { { 255, 196, 160 } }, pool = { 242, 206, 184 } },
			board = { 132, 58, 82 },
			text = { 255, 232, 214 },
		},
		toyrepair = {
			name = "TICK-TOCK TOY REPAIR",
			hero = "Decor_Repair_Bench",
			swap = { Decor_Fridge_4 = "Decor_ToyShelf_8", Decor_CandyCounter_6 = "Decor_RockingHorse" },
			frieze = { 52, 100, 86 },
			ceiling = { 48, 42, 48 },
			-- Lights Out: deeper amber, a little dimmer; never near-black (LEVELS §13)
			light = { room = { { 255, 168, 96 } }, pool = { 230, 176, 120 }, brightness = 1.35 },
			board = { 32, 62, 58 },
			text = { 250, 214, 140 },
		},
		pharmacy = {
			name = "NIGHT OWL PHARMACY",
			hero = "Decor_Pharmacy_Counter",
			swap = { Decor_CandyCounter_6 = "Decor_StockShelf_8", Decor_CatBed = "Decor_Boxes" },
			frieze = { 118, 170, 146 },
			ceiling = { 52, 56, 60 },
			light = { room = { { 236, 232, 204 } }, pool = { 216, 222, 196 } },
			board = { 44, 92, 76 },
			text = { 236, 250, 236 },
		},
		deli = {
			name = "BIG CHEESE DELI",
			hero = "Decor_Deli_Case",
			swap = { Decor_MagRack_3 = "Decor_Boxes" },
			frieze = { 150, 60, 66 },
			ceiling = { 64, 50, 44 },
			light = { room = { { 255, 196, 126 } }, pool = { 240, 204, 156 } },
			board = { 120, 40, 52 },
			text = { 255, 236, 200 },
		},
		jeweller = {
			name = "GLINT & CO. JEWELLERS",
			hero = "Decor_Jeweller_Case",
			swap = { Decor_Fridge_4 = "Decor_Jeweller_Case", Decor_MopBucket = "Decor_Boxes" },
			frieze = { 104, 84, 126 },
			ceiling = { 56, 48, 64 },
			light = { room = { { 255, 214, 172 } }, pool = { 236, 214, 196 } },
			board = { 40, 34, 60 },
			text = { 236, 226, 200 },
		},
		toystore = {
			name = "HOARDSWORTH'S TOYS",
			hero = "Decor_RockingHorse", -- in the window beside the door (the train loop needs more room than L5 has)
			frieze = { 226, 172, 188 }, -- candy pink (the store's raspberry band is too near Alarm Red at eye level)
			ceiling = { 70, 42, 54 },
			board = { 140, 47, 75 },
			text = { 255, 226, 150 },
		},
		bank = {
			name = "HOARDSWORTH & CO.",
			hero = "Xmas_Tree", -- the waiting-room tree beside the doors (dressing layer only)
			frieze = { 176, 160, 128 },
			ceiling = { 54, 52, 74 },
			board = { 42, 45, 82 },
			text = { 236, 226, 200 },
		},
	},
	-- Which theme each level is. A Corner Shop daily vault takes DAILY_SHOPS[(num - 300 - 1) % #DAILY_SHOPS + 1]
	-- (DV01 = the deli); the Toy Shop always toystore, the Bank always bank.
	LEVELS = {
		cs1_back_room = "grocer",
		cs2_two_doors = "bakery",
		cs3_lights_out = "toyrepair",
		cs4_night_clerk = "pharmacy",
	},
	DAILY_SHOPS = { "deli", "jeweller", "grocer", "bakery", "pharmacy", "toyrepair" },
}

-- The story intro (docs/PLAN_FIRST_PERSON.md §5 "INTRO", docs/art/intro/STORYBOARD.md; MASTERPLAN §4.3): a
-- 30-40 s cinematic on first join only, before L1 or the lobby, with SKIP from the first frame. The shot list
-- is data in Shared/Heist/IntroPlan (pure, unit-tested); the client Heist/Cinematic builds the stage locally
-- (never replicated, never collides, never queried) and plays it. Numbers here; story and framing there.
Config.Intro = {
	ENABLED = true, -- replaces the 3 s title beat for new players (Heist/Loading)
	-- Where the client builds its stage: far from every heist slot (Heist.INSTANCE_SPACING grid) and their
	-- backdrop rings, so nothing of a level is ever in a shot. Client-made parts are never streamed.
	STAGE_ORIGIN = { 0, 0, 7500 },
	KIT_FOLDER = "EH_IntroKit", -- ReplicatedStorage folder the server fills (Heist/IntroKit)
	KIT_WAIT_SECONDS = 4, -- the loading card holds this long at most for the meshes; then stand-ins
	-- The CHARACTER track's folder; its "Rookie" model replaces the stand-in as soon as it exists.
	CHARACTER_KIT = "CharacterKit",
	ROOKIE_TEMPLATE = "Rookie",
	-- The server holds a new account's first heist until the client says the intro is over (Heist.Ready
	-- while preparing) or this long (a client that never answers never traps anyone).
	SERVER_HOLD_SECONDS = 48,
	-- Studio without data (offline) plays it only when staged (EH_Scenario = "INTRO"): every Play would
	-- otherwise open on 34 s of cinematic.
	STUDIO_AUTOPLAY = false,
	-- Caption cards (big, short, sound-off readable: the MASTERPLAN §9.2 clip rules).
	CAPTION = {
		SIZE = 72, -- design px at UI scale 1
		MIN_SIZE = 34, -- never smaller on a phone
		IN = 0.22, -- s fade + punch in
		OUT = 0.25, -- s fade out
		PUNCH = 1.18, -- scale at the first frame, settling to 1
		Y = 0.8, -- screen fraction of the card's centre (lower third, clear of the SKIP button)
		WORDS_MAX = 6, -- unit-tested on every caption
		BAR = 0.16, -- letterbox bars, screen-height fraction each (0 under reduced motion: no slide)
	},
	SKIP = {
		ANY_KEY = true, -- any keyboard key skips too (PC); touch and gamepad use the button (or ButtonB)
		HOLD_OFF = 0.35, -- s after the start in which a key is ignored (the press that started the game)
		SIZE = { 150, 52 }, -- design px
		MARGIN = 24, -- px from the top-right safe corner
	},
	FADE_IN = 0.6, -- s from ink at the start
	WHIP_SECONDS = 0.32, -- a whip-pan between shots (reduced motion: a cut)
	WHIP_BLUR = 18, -- BlurEffect size at the middle of a whip
	FLASH_SECONDS = 0.18, -- white flashes (vacuum switch, title smash); FlashLimit applies
	SHAKE = { AMP = 0.35, FREQ = 13 }, -- studs, Hz (Settings "shake" off or reduced motion: none)
	PRESENTS = { 30, 20, 12, 6 }, -- flying presents per perf tier 1..4
	PRESENT_SPIN = 2.2, -- rad/s tumble
	SWIRL_PARTICLES = 60, -- asked of Heist/Particles per sparkle burst (the budget may grant fewer)
	TOWN_LIGHTS = { 8, 6, 3, 0 }, -- PointLights in the town per tier (windows are Neon either way)
	-- The sky: the game's own Heist/Aurora (its layers per tier: Budget.auroraLayers), anchored to the stage with its
	-- landmark direction toward the tower (degrees, 0 = -Z).
	AURORA_YAW = 0,
	-- Hoardsworth Tower's giant H (Neon, eh_palette.NEON Intro_Tower_Sign) and its warm floodlight (tiers 1-2).
	SIGN_COLOUR = "#FFB85C",
	SIGN_LIGHT = { RANGE = 34, BRIGHTNESS = 1.6 },
	-- The suction vortex at the vacuum's mouth while it runs: spiral arms of additive Beams on a funnel along the
	-- mouth's aim (IntroPlan.STAGE.aim), spun about it. ARMS per perf tier (0 = none); radii and length in studs.
	VORTEX = {
		ARMS = { 8, 6, 4, 0 },
		POINTS = 6, -- control points per arm (POINTS - 1 Beams)
		MOUTH_RADIUS = 3.5, -- where the arms pour into the throat
		FAR_RADIUS = 17, -- the funnel's wide end, LENGTH studs out toward the town
		LENGTH = 32,
		FLARE = 1.4, -- radius growth exponent (> 1: a trumpet)
		TURNS = 0.85, -- turns of an arm from the far end to the mouth
		CURVE = 0.35, -- Beam curve size per stud of radius (round spirals between the points)
		WIDTH = { 0.7, 2.4 }, -- Beam width at the mouth, at the far end
		ALPHA = { 0.5, 0.97 }, -- Beam transparency at the mouth, at the far end
		COLOURS = { "#FFF1D8", "#C9C2FF" }, -- warm white into a pale violet
		SPIN = 2.6, -- rad/s (x Config.Aurora.REDUCED_MOTION under reduced motion)
	},
	-- The villain close-up's gold ring on Hoardsworth's right glove: a signet on top of the knuckles (a Neon-gold
	-- Cylinder, its axis along the hand's Z, its top as he grips the knob; built by Heist/Cinematic as a rig
	-- decoration), flashing when he grips the lever (the "ring" event). SIZE studs (thickness, diameter, diameter);
	-- OFFSET from the hand's centre in the hand's own space.
	RING = {
		SIZE = { 0.06, 0.22, 0.22 },
		OFFSET = { 0, -0.12, -0.24 },
		COLOUR = "#FFC24A",
		GLINT = { SIZE = 0.8, COUNT = 2 },
	},
	MONOCLE_GLINT = { SIZE = 0.9, COUNT = 2 }, -- studs: the close-up frames his face about 5 studs away
	-- His open laughing mouth over the kit face's closed one (rig decorations on the head, shown while
	-- IntroPlan.laughing): a dark mouth and a teeth strip; SIZE studs, OFFSET from the head's joint in its own space.
	LAUGH_MOUTH = {
		MOUTH = { SIZE = { 0.42, 0.2, 0.08 }, OFFSET = { 0.02, 0.33, -0.39 }, COLOUR = "#3A1020" },
		TEETH = { SIZE = { 0.34, 0.06, 0.04 }, OFFSET = { 0.02, 0.39, -0.42 }, COLOUR = "#FFF4E0" },
	},
	-- His light on the terrace (IntroPlan.STAGE.villainLights; SpotLights, no shadows, while he is on stage).
	VILLAIN_LIGHTS = {
		under = { BRIGHTNESS = 2.4, RANGE = 20, ANGLE = 40, COLOUR = "#FF9C6A" },
		key = { BRIGHTNESS = 1.6, RANGE = 20, ANGLE = 30, COLOUR = "#FFE2C0" },
		rim = { BRIGHTNESS = 3, RANGE = 26, ANGLE = 30, COLOUR = "#9C8CFF" },
		hand = { BRIGHTNESS = 1.8, RANGE = 8, ANGLE = 30, COLOUR = "#FFC24A" },
	},
	-- The garage's motivated light (IntroPlan.STAGE: workLamp, doorLamp, doorGlow, windows, rim, strings). Warm
	-- practicals inside, the aurora's cool light from outside (REVIEW_STEAM_PLUS #7: shots 6-8 were near-black).
	-- Brightness / range / angle as the Light instances take them; colours hex.
	GARAGE = {
		HEADLIGHT = { BRIGHTNESS = 7, RANGE = 44, ANGLE = 52, COLOUR = "#FFF1D8" },
		-- the headlight beams (additive Beams from each lens out of the door, dropping to the floor): per layer
		-- { width at the lens, width at the end, transparency at the lens }, fading to clear at the end
		BEAM = { LENGTH = 24, DROP = 2.0, LAYERS = { { 0.8, 4.5, 0.62 }, { 2.0, 11, 0.86 } }, TIERS = 3 },
		WORK_LAMP = { BRIGHTNESS = 3.2, RANGE = 22, ANGLE = 80, COLOUR = "#FFC890", CONE_TRANSPARENCY = 0.88 },
		DOOR_LAMP = { BRIGHTNESS = 2.6, RANGE = 14, ANGLE = 70, COLOUR = "#FFD2A0" },
		BENCH_LAMP = { BRIGHTNESS = 1.6, RANGE = 12, COLOUR = "#FFB870" }, -- a PointLight over the workbench
		-- the aurora through the open door (a SurfaceLight facing in) and the high windows (Neon panes, shafts)
		DOOR_GLOW = { BRIGHTNESS = 1.6, RANGE = 30, ANGLE = 85, COLOUR = "#9CBCFF" },
		WINDOW_COLOURS = { "#5BE0C2", "#8A7BFF" }, -- the pane's bottom, top (the aurora's green into violet)
		SHAFT = { LENGTH = 22, WIDTH = { 5, 9 }, TRANSPARENCY = 0.9, TIERS = 2 },
		RIM = { BRIGHTNESS = 3.0, RANGE = 30, ANGLE = 26, COLOUR = "#9DB4FF" },
		STRING = { SPACING = 2.2, SAG = 0.5, COLOUR = "#FFC680", TIERS = 3 }, -- bulbs along both side walls
		SHADOWS_TIER = 2, -- shadows from the headlights and the work lamp up to this tier
	},
	TITLE_VEIL = 0.45, -- the ink veil under the wordmark (transparency): the lit garage and the crew show through
	SNOW_RATE = 60, -- flakes/s in the stage snow (x0.5 under reduced motion)
	SNOW_MAX = 240, -- alive at most (rate x lifetime is reported to Heist/Particles as steady)
	HANDOFF_SECONDS = 0.35, -- the wordmark rests this long before the title card takes over
}

return Config
