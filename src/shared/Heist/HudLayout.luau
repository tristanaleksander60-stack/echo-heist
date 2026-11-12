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
local TAP = H.TAP_MIN

export type Box = { ax: number, ay: number, sx: number, ox: number, sy: number, oy: number, w: number, h: number }

local function box(ax: number, ay: number, sx: number, ox: number, sy: number, oy: number, w: number, h: number): Box
	return table.freeze({ ax = ax, ay = ay, sx = sx, ox = ox, sy = sy, oy = oy, w = w, h = h })
end

local HudLayout = {}

-- Top row
HudLayout.LOOT = box(0, 0, 0, 8, 0, 6, 230, 44)
HudLayout.TOP = box(0.5, 0, 0.5, 0, 0, 6, 330, 62)
HudLayout.STRIP = box(1, 0, 1, -8, 0, 6, 220, 44)
HudLayout.MENU = box(0, 0, 0, 8, 0, 56, TAP, TAP)
-- Under the top bar: the alarm counter, the objective line, the HIDDEN pill (the last two
-- move down while the alarm counter shows).
HudLayout.ALARM = box(0.5, 0, 0.5, 0, 0, 74, 380, 40)
HudLayout.OBJECTIVE = box(0.5, 0, 0.5, 0, 0, 74, 460, 34)
HudLayout.OBJECTIVE_ALARM = box(0.5, 0, 0.5, 0, 0, 120, 460, 34)
HudLayout.HIDDEN = box(0.5, 0, 0.5, 0, 0, 112, 150, 36)
HudLayout.HIDDEN_ALARM = box(0.5, 0, 0.5, 0, 0, 158, 150, 36)
-- Edges
HudLayout.FAST_FORWARD = box(0, 0.5, 0, 10, 0.42, 0, 150, TAP)
HudLayout.END_RUN = box(1, 0.5, 1, -10, H.END_RUN_Y, 0, H.END_RUN_BUTTON + 24, H.END_RUN_BUTTON)
HudLayout.READY_WAIT = box(1, 0.5, 1, -10, H.END_RUN_Y, 0, 170, TAP)
-- Bottom row: Interact left of the jump button; the message rail above it (or above the
-- Clone Deck between runs).
HudLayout.INTERACT = box(1, 1, 1, -120, 1, -16, H.INTERACT_BUTTON + 56, H.INTERACT_BUTTON)
HudLayout.DECK = box(0.5, 1, 0.5, 0, 1, -8, 620, 212)
HudLayout.RAIL = box(0.5, 1, 0.5, 0, 1, -96, 440, 96)
HudLayout.RAIL_DECK = box(0.5, 1, 0.5, 0, 1, -(212 + 16), 440, 96)

-- What shows together (tests/hud_layout.luau checks each scene for overlaps).
HudLayout.SCENES = table.freeze({
	run = { "LOOT", "TOP", "STRIP", "MENU", "OBJECTIVE", "HIDDEN", "FAST_FORWARD", "END_RUN", "INTERACT", "RAIL" },
	runAlarm = {
		"LOOT",
		"TOP",
		"STRIP",
		"MENU",
		"ALARM",
		"OBJECTIVE_ALARM",
		"HIDDEN_ALARM",
		"FAST_FORWARD",
		"END_RUN",
		"INTERACT",
		"RAIL",
	},
	betweenDeck = { "LOOT", "TOP", "STRIP", "MENU", "DECK", "RAIL_DECK" },
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
