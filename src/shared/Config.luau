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

return Config
