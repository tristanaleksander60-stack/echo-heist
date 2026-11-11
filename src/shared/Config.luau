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

return Config
