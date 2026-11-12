--!strict
-- ReplicatedFirst/Brand: the brand tokens the first frame needs (PLAN_STEAM_PLUS §3.4, MASTERPLAN §2.2,
-- POLISH §4.6). ReplicatedFirst runs before ReplicatedStorage has arrived, so the loading card cannot
-- wait for Shared/Config, Palette or Strings: the few values it draws with live here. Each mirrors its
-- source of truth and tests/unit/HeistPresent.spec.luau asserts they match:
--   colours   Shared/Heist/Palette (ink, inkHi, white, steelHi, CLONE_HUES 1-3)
--   face      Config.Ui.DISPLAY_FACE, Config.Ui.WORDMARK_OFFSET, Config.Ui.DISPLAY_STROKE
--   LOADING   Config.Presentation.LOADING
--   words     Shared/Heist/Strings (WORDMARK, WORDMARK_STRAP, LOADING_HINTS)
-- Pure data: no requires, no engine calls (Lune reads it).

local Brand = {}

Brand.COLOR = table.freeze({
	ink = "#1C1F3B",
	inkHi = "#2A2D52",
	white = "#FFFFFF",
	steelHi = "#A9B2CC",
	-- the clone hues: copy k of the wordmark wears hue k (seat 1 cyan, 2 magenta, 3 indigo)
	hues = table.freeze({ "#3DE8FF", "#FF4FD8", "#6A5CFF" }),
})

Brand.FACE = "LuckiestGuy" -- Config.Ui.DISPLAY_FACE
Brand.BODY_FONT = "rbxasset://fonts/families/BuilderSans.json"
Brand.WORDMARK_OFFSET = table.freeze({ 5, 4 }) -- Config.Ui.WORDMARK_OFFSET, px at OFFSET_AT px type
Brand.OFFSET_AT = 55 -- the offset above is for 55 px type; it scales with the size (the specimen's 110 px: x2)
Brand.DISPLAY_STROKE = 0.06 -- Config.Ui.DISPLAY_STROKE: stroke = 6 % of the type size

Brand.WORDMARK = "HEIST YOURSELF"
Brand.STRAP = "Rob With Your Clones"
-- The quiet progress hint, one line per real stage (never a bare "Loading").
Brand.HINTS = table.freeze({
	boot = "Packing the van", -- the place is still arriving
	client = "Waking up the crew", -- the game's scripts are starting
	server = "Finding your van", -- the server is getting your first heist ready
})
Brand.STAGES = table.freeze({ "boot", "client", "server" })

Brand.LOADING = table.freeze({
	REEL_PERIOD = 1.2,
	FADE_SECONDS = 0.3,
	MAX_SECONDS = 12,
	HOLD_MAX_SECONDS = 30,
	ORDER = 200,
})

-- Card layout, design px at a 720 x 330 canvas (scaled to the screen by one UIScale).
Brand.CARD = table.freeze({
	DESIGN = table.freeze({ 720, 330 }),
	MARK_SIZE = 72, -- wordmark type size
	MARK_Y = 0.4, -- wordmark centre, share of the height
	STRAP_SIZE = 18,
	REEL = 34, -- reel diameter
	REEL_Y = 0.8, -- reel centre, share of the height
	HINT_SIZE = 16,
	PIP = 6, -- progress pip diameter
})

-- Attributes on the card's ScreenGui: how the client talks to the ReplicatedFirst script.
Brand.ATTR = table.freeze({
	SHOWN_AT = "EH_ShownAt", -- os.clock() of the first frame (the card)
	HOLD = "EH_Hold", -- true: the client owns the dismissal (the watchdog waits HOLD_MAX_SECONDS)
	STAGE = "EH_Stage", -- a Brand.STAGES name
	REDUCED = "EH_Reduced", -- true: the reel stands still
	DISMISS = "EH_Dismiss", -- "fade" (0.3 s) | "handoff" (gone at once: the client drew the same frame on top)
})
Brand.GUI_NAME = "EH_Loading"

return table.freeze(Brand)
