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
-- First person (PLAN_FIRST_PERSON FP): the reduced run HUD. The reticle sits at the centre of the WHOLE
-- screen (where the camera ray goes), not of the safe area: SCREEN_CENTRED boxes are placed on an edge-to-
-- edge layer and are relative to the screen's centre (HudLayout.centreShift moves them onto the HUD canvas
-- for the overlap check). On a phone the top bar puts that centre high, level with the objective line, so
-- in first person the objective (or the alarm counter) moves below the reticle, the prompt chip ("GRAB
-- $100", "OPEN", "BANK") sits just right of it, and the message rail goes to the bottom, left of centre so
-- it clears Interact (which stays the touch fallback, lower right) on the narrowest canvas.
HudLayout.RETICLE = box(0.5, 0.5, 0.5, 0, 0.5, 0, 28, 28)
HudLayout.PROMPT = box(0, 0.5, 0.5, 26, 0.5, 0, 196, 40)
HudLayout.SCREEN_CENTRED = table.freeze({ RETICLE = true, PROMPT = true })
-- (Left of centre by FP_SHIFT: the touch SLIDE button sits between them and Interact.)
local FP_SHIFT = -148
HudLayout.RAIL_FP = box(0.5, 1, 0.5, FP_SHIFT, 1, -8, 336, 98)
HudLayout.OBJECTIVE_FP = box(0.5, 1, 0.5, FP_SHIFT, 1, -114, 360, 28)
HudLayout.ALARM_FP = box(0.5, 1, 0.5, FP_SHIFT, 1, -114, 360, 30)
-- Crew View (first person; Hud/CrewView, REVIEW_STEAM_PLUS gap 5): the touch CREW button (hold) sits above Interact,
-- left of REWIND, clear of the jump button (on the right, under your right thumb: the left one keeps moving you);
-- while held, "CREW VIEW" sits under the clone strip (where the diorama's objective line goes: in first person that
-- line is at the bottom) and the reticle and its prompt chip hide. On the narrowest notched phones the prompt chip
-- (right of the screen centre) reaches the button's corner: there the button steps aside while the chip is up
-- (HudLayout.crewYields; you are looking at something to use, not peeking).
HudLayout.CREW = box(1, 1, 1, -124, 1, -(16 + H.INTERACT_BUTTON + 10), 80, TAP)
HudLayout.CREW_LABEL = box(0.5, 0, 0.5, 0, 0, 98, 168, 28)
-- The slide (Config.Slide, Heist/Slide): the SLIDE button, bottom row, left of Interact (in the hideout, of USE), under
-- your right thumb. Shown in a first-person run and in the hideout whenever a slide may start; hold FAST with it on
-- touch for the fast slide.
HudLayout.SLIDE = box(1, 1, 1, -(124 + H.INTERACT_BUTTON + 56 + 8), 1, -16, TAP, H.INTERACT_BUTTON)
-- Key caps (Hud/Common.keyCap) straddle a button's corner by this much: less than GAP, so a cap never reaches a
-- neighbouring box.
HudLayout.KEY_CAP_OUT = 6

-- Centred sheets (they cover the run HUD, so each is a scene of its own): the job sheet (results),
-- the garage with its job board, the MENU sheet and the settings panel (PLAN_STEAM_PLUS §4.3 U5-U7).
-- The results, MENU and settings sheets turn Roblox's touch controls off while they are up
-- (Hud/Common.blockTouch), so the jump button is no reserved box for them (SHEETS).
HudLayout.RESULTS = box(0.5, 0.5, 0.5, 0, 0.5, 0, 480, 326)
HudLayout.GARAGE = box(0.5, 0.5, 0.5, 0, 0.5, 0, 700, 326)
HudLayout.MENU_SHEET = box(0.5, 0.5, 0.5, 0, 0.5, 0, 420, 200 + TAP)
HudLayout.SETTINGS = box(0.5, 0.5, 0.5, 0, 0.5, 0, 700, 12 + TAP + 3 * TAP + 2 * 6 + 12)
-- The garage keeps touch controls (you walk in the garage): its SETTINGS button sits at the top of the
-- right column (garage-local (486, 44)), clear of the jump button on every phone.
HudLayout.GARAGE_SETTINGS = box(0, 0, 0.5, -350 + 486, 0.5, -163 + 44, 200, TAP)
-- The hideout lobby (Config.Hideout, Hud/Lobby): walking about in first person the reticle and its prompt chip
-- show, the toast rail sits low (RAIL_FP) and touch gets a USE button where Interact sits in a run. At a station
-- (the job board, the laptop) the garage sheet opens with its own BACK button inside; the wardrobe is a sheet on
-- the left (your Rookie stands on the right). Both stations switch touch controls off while up. The drive to the
-- heist shows a SKIP chip top right (the player list is hidden then).
HudLayout.LOBBY_USE = box(1, 1, 1, -124, 1, -16, H.INTERACT_BUTTON + 56, H.INTERACT_BUTTON)
HudLayout.WARDROBE = box(0, 0.5, 0, 8, 0.5, 0, 336, 326)
HudLayout.LOBBY_SKIP = box(1, 0, 1, -8, 0, 6, 140, TAP)
-- Quick Crew (LOBBY 2): "LOOKING FOR CREW" / "FOLLOW THE ARROW" with STOP, top left while you look for a crew (the
-- run's LOOT box place: nothing else is there in the lobby).
HudLayout.LOBBY_QUICK = box(0, 0, 0, 8, 0, 6, 300, TAP)
HudLayout.SHEETS =
	table.freeze({ results = true, garage = true, menu = true, settings = true, station = true, wardrobe = true })

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
	-- First person: no loot meter (it peeks in after a change; Hud/Run), the reticle and the prompt chip, the
	-- rail at the bottom. LOOT is listed: when it peeks it must still fit.
	fpRun = {
		"LOOT",
		"TOP",
		"STRIP",
		"MENU",
		"FAST_FORWARD",
		"OBJECTIVE_FP",
		"HIDDEN",
		"END_RUN",
		"INTERACT",
		"CREW",
		"SLIDE",
		"RETICLE",
		"PROMPT",
		"RAIL_FP",
		"HELP_CHIP",
	},
	fpRunAlarm = {
		"LOOT",
		"TOP",
		"STRIP",
		"MENU",
		"FAST_FORWARD",
		"ALARM_FP",
		"HIDDEN",
		"END_RUN",
		"INTERACT",
		"CREW",
		"SLIDE",
		"RETICLE",
		"PROMPT",
		"RAIL_FP",
		"HELP_CHIP",
	},
	-- Crew View held: the first-person HUD without the reticle and its chip, with the CREW VIEW label.
	fpCrew = {
		"LOOT",
		"TOP",
		"STRIP",
		"MENU",
		"FAST_FORWARD",
		"OBJECTIVE_FP",
		"HIDDEN",
		"END_RUN",
		"INTERACT",
		"CREW",
		"SLIDE",
		"CREW_LABEL",
		"RAIL_FP",
		"HELP_CHIP",
	},
	fpCrewAlarm = {
		"LOOT",
		"TOP",
		"STRIP",
		"MENU",
		"FAST_FORWARD",
		"ALARM_FP",
		"HIDDEN",
		"END_RUN",
		"INTERACT",
		"CREW",
		"SLIDE",
		"CREW_LABEL",
		"RAIL_FP",
		"HELP_CHIP",
	},
	betweenDeck = { "LOOT", "MENU", "DECK", "RAIL_DECK", "HELP_CHIP" },
	betweenLocked = { "LOOT", "TOP", "STRIP", "MENU", "OBJECTIVE", "READY_WAIT", "RAIL" },
	results = { "RESULTS" },
	garage = { "GARAGE" },
	menu = { "MENU_SHEET" },
	settings = { "SETTINGS" },
	garageButtons = { "GARAGE_SETTINGS" },
	lobby = { "RETICLE", "PROMPT", "RAIL_FP", "LOBBY_USE", "LOBBY_QUICK", "SLIDE" },
	station = { "GARAGE" },
	wardrobe = { "WARDROBE" },
	drive = { "LOBBY_SKIP" },
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

-- Where the whole screen's centre lands on the HUD canvas, as a shift from the canvas centre (design px), for a
-- screen of w x h px with safe-area insets (left, top, right, bottom). SCREEN_CENTRED boxes move by it.
function HudLayout.centreShift(
	w: number,
	h: number,
	left: number,
	top: number,
	right: number,
	bottom: number
): (number, number)
	local cw, ch, s = HudLayout.canvas(w - left - right, h - top - bottom)
	return (w / 2 - left) / s - cw / 2, (h / 2 - top) / s - ch / 2
end

-- A box's edges on a W x H canvas: left, top, right, bottom.
function HudLayout.rect(b: Box, w: number, h: number): (number, number, number, number)
	local x0 = b.sx * w + b.ox - b.ax * b.w
	local y0 = b.sy * h + b.oy - b.ay * b.h
	return x0, y0, x0 + b.w, y0 + b.h
end

-- The least gap between two HUD boxes (design px; tests/hud_layout.luau checks every scene against it).
HudLayout.GAP = 8

-- Whether the touch CREW button steps aside while the prompt chip is up, on a screen of w x h px with safe-area
-- insets (left, top, right, bottom): true when the two come closer than GAP (Hud/CrewView and the layout check both
-- ask this, so they agree).
function HudLayout.crewYields(w: number, h: number, left: number, top: number, right: number, bottom: number): boolean
	local cw, ch = HudLayout.canvas(w - left - right, h - top - bottom)
	local dx, dy = HudLayout.centreShift(w, h, left, top, right, bottom)
	local a0, b0, a1, b1 = HudLayout.rect(HudLayout.CREW, cw, ch)
	local p0, q0, p1, q1 = HudLayout.rect(HudLayout.PROMPT, cw, ch)
	p0, p1, q0, q1 = p0 + dx, p1 + dx, q0 + dy, q1 + dy
	local gx = math.max(p0 - a1, a0 - p1)
	local gy = math.max(q0 - b1, b0 - q1)
	return math.max(gx, gy) < HudLayout.GAP
end

return table.freeze(HudLayout)
