--!strict
-- Heist/HudLayout: where the run HUD's boxes sit, as data (design px at 1x on the
-- Config.Heist.UI_DESIGN_SIZE canvas, MASTERPLAN §7.4). The client HUD places its
-- frames from these boxes (Hud/Common.place) and tests/hud_layout.luau checks the same
-- boxes for overlaps at 7 viewports, so the check can never drift from the game.
-- Pure: no engine calls (Lune reads it).
--
-- A box is an AnchorPoint (ax, ay), a Position (sx, ox, sy, oy) and an offset Size (w, h):
-- on a canvas W x H its left edge is sx * W + ox - ax * w, and so on.

local Config = require("../Config")

local H = Config.Heist
local U = Config.Ui
local TAP = H.TAP_MIN

export type Box = { ax: number, ay: number, sx: number, ox: number, sy: number, oy: number, w: number, h: number }

local function box(ax: number, ay: number, sx: number, ox: number, sy: number, oy: number, w: number, h: number): Box
	return table.freeze({ ax = ax, ay = ay, sx = sx, ox = ox, sy = sy, oy = oy, w = w, h = h })
end

local HudLayout = {}

-- Top row (WALKTHROUGH P1-13: it used to be 796 design px on a 720 canvas). The loot
-- meter top left, the run box (RUN n + timer + run bar) top centre, the clone strip
-- centred under the timer. Nothing top right: that is where Roblox's player list sits
-- (hidden during heists, PLAN S8).
HudLayout.LOOT = box(0, 0, 0, 8, 0, 6, 176, 44)
HudLayout.TOP = box(0.5, 0, 0.5, 0, 0, 6, 300, 48)
HudLayout.STRIP = box(0.5, 0, 0.5, 0, 0, 62, 252, 28)
HudLayout.STRIP_CHIP = 24 -- a clone chip's height and width
HudLayout.STRIP_MAX_CHIPS = 8 -- more clones: the first 7 and "+n"
-- Second row, left: MENU and the hold-to-skip pill.
HudLayout.MENU = box(0, 0, 0, 8, 0, 58, TAP, TAP)
HudLayout.FAST_FORWARD = box(0, 0, 0, 88, 0, 58, 74, TAP)
-- Under the strip: the objective line, or the alarm counter while it runs (the alarm
-- counter is the objective then). HIDDEN sits left, under MENU.
HudLayout.OBJECTIVE = box(0.5, 0, 0.5, 0, 0, 98, 360, 28)
HudLayout.ALARM = box(0.5, 0, 0.5, 0, 0, 98, 360, 30)
HudLayout.HIDDEN = box(0, 0, 0, 8, 0, 138, 150, 30)
-- Right edge. REWIND (the END RUN action) is large, lower right, above the touch jump button
-- (PLAN_STEAM_PLUS §4.3 U3; Config.Ui.REWIND_*).
HudLayout.END_RUN = box(1, 1, 1, -U.REWIND_RIGHT, 1, -U.REWIND_BOTTOM, U.REWIND_SIZE, U.REWIND_SIZE)
HudLayout.READY_WAIT = box(1, 0.5, 1, -10, H.END_RUN_Y, 0, 160, TAP)
-- Bottom row: Interact left of the jump button; the message rail above it (or above the
-- Clone Deck between runs, when the run box and strip step aside).
HudLayout.INTERACT = box(1, 1, 1, -124, 1, -16, H.INTERACT_BUTTON + 56, H.INTERACT_BUTTON)
HudLayout.DECK = box(0.5, 1, 0.5, -12, 1, -8, 520, 212) -- a little left of centre: clear of the jump button
-- The rail's slots, bottom up: spectate / reason line, sound caption, toast (two lines).
HudLayout.RAIL_SLOTS = table.freeze({ toast = 44, caption = 24, spectate = 26, pad = 2 })
HudLayout.RAIL = box(0.5, 1, 0.5, 0, 1, -96, 336, 98)
HudLayout.RAIL_DECK = box(0.5, 1, 0.5, 0, 1, -(8 + 212 + 8), 336, 98)
-- Top right (nothing else lives there in a heist): the help chip, "SHOW ME?" after 2 stuck runs
-- or the "TRY RELAXED?" card (Hud/Hints, WALKTHROUGH P0-2). Not with the locked deck (L1 and the
-- party have no ghost and no Relaxed).
HudLayout.HELP_CHIP = box(1, 0, 1, -8, 0, 6, 168, TAP)

-- What shows together (tests/hud_layout.luau checks each scene for overlaps).
HudLayout.SCENES = table.freeze({
	run = {
		"LOOT",
		"TOP",
		"STRIP",
		"MENU",
		"FAST_FORWARD",
		"OBJECTIVE",
		"HIDDEN",
		"END_RUN",
		"INTERACT",
		"RAIL",
		"HELP_CHIP",
	},
	runAlarm = {
		"LOOT",
		"TOP",
		"STRIP",
		"MENU",
		"FAST_FORWARD",
		"ALARM",
		"HIDDEN",
		"END_RUN",
		"INTERACT",
		"RAIL",
		"HELP_CHIP",
	},
	betweenDeck = { "LOOT", "MENU", "DECK", "RAIL_DECK", "HELP_CHIP" },
	betweenLocked = { "LOOT", "TOP", "STRIP", "MENU", "OBJECTIVE", "READY_WAIT", "RAIL" },
} :: { [string]: { string } })

-- The HUD's device scale for a safe area of w x h px (one UIScale on the HUD root).
function HudLayout.scale(w: number, h: number): number
	local d = H.UI_DESIGN_SIZE
	return math.clamp(math.min(w / d[1], h / d[2]), H.UI_SCALE_MIN, H.UI_SCALE_MAX)
end

-- The design canvas (W, H) a safe area of w x h px gets, and its scale.
function HudLayout.canvas(w: number, h: number): (number, number, number)
	local s = HudLayout.scale(w, h)
	return w / s, h / s, s
end

-- A box's edges on a W x H canvas: left, top, right, bottom.
function HudLayout.rect(b: Box, w: number, h: number): (number, number, number, number)
	local x0 = b.sx * w + b.ox - b.ax * b.w
	local y0 = b.sy * h + b.oy - b.ay * b.h
	return x0, y0, x0 + b.w, y0 + b.h
end

return table.freeze(HudLayout)
