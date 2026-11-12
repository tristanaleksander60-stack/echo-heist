-- Clone phone bench (spike S1, MASTERPLAN §8.11): every tuning number for the
-- bench lives here. The bench is a separate place (bench.project.json), so it
-- keeps its own config instead of the game's src/shared/Config.luau.

local BenchConfig = {}

-- Clone counts the N button cycles through (0 = baseline room cost).
BenchConfig.COUNTS = { 0, 4, 8, 12, 16 }
BenchConfig.START_COUNT = 12
BenchConfig.CLONES_PER_GROUP = 4 -- one owner group (and one Highlight) per 4 clones, like 4 players x 4 clones

-- Measurement window
BenchConfig.WARMUP_SECONDS = 2 -- ignored after every change (rig rebuilds, first Highlight cost)
BenchConfig.WINDOW_SECONDS = 10 -- FPS average and 1% low are taken over this window
BenchConfig.READOUT_HZ = 4

-- Clone movement (client-drawn, like the planned EchoView)
BenchConfig.WALK_SPEED = 8 -- studs/s along each path
BenchConfig.WALK_ANIM = "rbxassetid://507777826" -- default R15 walk (same clip as the game)
BenchConfig.WALK_ANIM_BASE_SPEED = 8 -- studs/s at which the clip plays at speed 1 (cosmetic, tune by eye)
BenchConfig.PATH_CENTER = Vector3.new(0, 0, 0)
BenchConfig.PATH_RADII = { 6, 10, 14, 18 } -- one ring per group
BenchConfig.MANNEQUIN_SWING = math.rad(35) -- leg/arm swing of the hologram rig
BenchConfig.MANNEQUIN_STRIDE = 1.6 -- swing cycles per second at WALK_SPEED

-- Fixed bench camera, so numbers from different phones compare
BenchConfig.CAMERA_POSITION = Vector3.new(0, 22, 40)
BenchConfig.CAMERA_FOV = 70

-- Owner hues (MASTERPLAN §6.2), one per group
BenchConfig.HUES = {
	Color3.fromRGB(61, 232, 255), -- Clone Cyan (P1 / solo)
	Color3.fromRGB(255, 79, 216), -- Clone Magenta (P2)
	Color3.fromRGB(106, 92, 255), -- Clone Indigo (P3)
	Color3.fromRGB(244, 247, 255), -- Ghost White (P4)
}

-- Clone looks (MASTERPLAN §6.5 #3)
BenchConfig.LOOKS = {
	{
		id = "A",
		name = "A translucent + group Highlight",
		rig = "avatar",
		transparency = 0.45,
		highlight = true,
		fillTransparency = 0.85,
		outlineTransparency = 0,
	},
	{
		id = "B",
		name = "B opaque glow + outline Highlight",
		rig = "avatar",
		transparency = 0,
		highlight = true,
		fillTransparency = 1,
		outlineTransparency = 0,
	},
	{
		id = "C",
		name = "C hologram mannequin + hair/hat",
		rig = "mannequin",
		transparency = 0.35,
		highlight = false,
		fillTransparency = 1,
		outlineTransparency = 1,
	},
}

-- Stripped silhouette (MASTERPLAN §6.5 #2)
BenchConfig.MAX_ACCESSORIES = 2

-- How long a client waits for its avatar template before using the fallback rig
BenchConfig.TEMPLATE_TIMEOUT = 25

-- Room (built by the bench server)
BenchConfig.ROOM_SIZE = 84
BenchConfig.WALL_HEIGHT = 16
BenchConfig.LAMP_RANGE = 36
BenchConfig.LAMP_BRIGHTNESS = 1.6
BenchConfig.HERO_SHADOW_LIGHTS = 1 -- shadow-casting lights in the room (plan budget: <= 4 per view)

return BenchConfig
