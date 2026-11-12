-- Video capture spike (S3, MASTERPLAN §8.11 and §9.3): every tuning number for
-- the spike lives here. The spike is a separate place (spikes/capture.project.json),
-- so it keeps its own config instead of the game's src/shared/Config.luau.

local CaptureConfig = {}

-- Clip lengths the LEN button cycles through. 12 s is the S3 pass bar; 30 s is
-- the documented CaptureService maximum (and the Roblox Moments limit); 35 s
-- checks that the engine stops on its own with TimeLimitReached.
CaptureConfig.CLIP_SECONDS = { 12, 30, 35 }

-- Launch data sent with PromptShareCapture, in the §9.3 format v1|reel|<levelId>.
-- A friend who joins through the shared invite should see it in their panel.
CaptureConfig.LAUNCH_DATA = "v1|reel|spike"

-- When CLEAN is on, the debug panel hides between CaptureBegan and CaptureEnded
-- (only the small REC badge stays), to check what a clip picks up from ScreenGuis.
CaptureConfig.CLEAN_DEFAULT = false

-- Moving scene: a few walking dummy clones on a ring, plus a spinning vault ring
CaptureConfig.DUMMY_COUNT = 4
CaptureConfig.WALK_SPEED = 8 -- studs/s along the ring
CaptureConfig.WALK_ANIM = "rbxassetid://507777826" -- default R15 walk (same clip as the game)
CaptureConfig.WALK_ANIM_BASE_SPEED = 8 -- studs/s at which the clip plays at speed 1
CaptureConfig.RING_RADIUS = 10
CaptureConfig.RING_CENTER = Vector3.new(0, 0, 0)
CaptureConfig.SPIN_RATE = math.rad(45) -- vault ring, radians per second
CaptureConfig.TEMPLATE_TIMEOUT = 20 -- s to wait for the server-built dummy rig

-- Fixed camera so clips from different devices compare
CaptureConfig.CAMERA_POSITION = Vector3.new(0, 14, 30)
CaptureConfig.CAMERA_FOV = 60

-- Burned-in caption test (§9.2: every clip shows "◀ ME, 20 SEC AGO" on a clone)
CaptureConfig.CAPTION_TEXT = "◀ ME, 20 SEC AGO"

-- Readout
CaptureConfig.READOUT_HZ = 4
CaptureConfig.FPS_WINDOW_SECONDS = 2
CaptureConfig.LOG_LINES = 14 -- lines of the event log shown in the panel

-- Owner hues (MASTERPLAN §6.2), one per dummy
CaptureConfig.HUES = {
	Color3.fromRGB(61, 232, 255), -- Clone Cyan
	Color3.fromRGB(255, 79, 216), -- Clone Magenta
	Color3.fromRGB(106, 92, 255), -- Clone Indigo
	Color3.fromRGB(244, 247, 255), -- Ghost White
}

return CaptureConfig
