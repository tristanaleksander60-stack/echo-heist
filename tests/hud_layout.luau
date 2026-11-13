-- HUD layout check (docs/PLAN_STEAM_PLUS.md §4.0, MASTERPLAN §7.4): the run HUD's
-- boxes (Shared/Heist/HudLayout, the same data the client places its frames from) must
-- not overlap, with at least GAP design px between any two, and must stay on the
-- canvas, in every scene (HudLayout.SCENES) at 7 viewports. On touch devices Roblox's
-- jump button is a reserved box too (PlayerModule TouchJump: 70 px at (W-95, H-90) when
-- the screen's short side is <= 500 px, else 120 px at (W-170, H-210), below the top bar).
-- Viewports are screen px with their safe-area insets (the Roblox top bar is 58 px);
-- the HUD canvas is the safe area divided by HudLayout.scale (design px at 720 x 330).
-- Centred sheets (results, garage, MENU, settings: HudLayout.SHEETS) must stay on the canvas; the
-- garage's own buttons that sit near the jump button are boxes of their own (GARAGE_SETTINGS).
-- First person (fpRun, fpRunAlarm): the reticle and its prompt chip are centred on the WHOLE screen (the
-- camera ray), so they are moved by HudLayout.centreShift before the check; the reticle must also land on
-- the screen centre within 0.5 px.
-- Run from the repo root: lune run tests/hud_layout.luau

local process = require("@lune/process")

local HudLayout = require("../src/shared/Heist/HudLayout")

local GAP = 8
local TOP_BAR = 58

type Viewport = {
	name: string,
	w: number,
	h: number,
	left: number,
	top: number,
	right: number,
	bottom: number,
	touch: boolean,
}

local VIEWPORTS: { Viewport } = {
	{
		name = "Android 360 dp landscape",
		w = 800,
		h = 360,
		left = 0,
		top = TOP_BAR,
		right = 0,
		bottom = 0,
		touch = true,
	},
	{ name = "iPhone SE landscape", w = 667, h = 375, left = 0, top = TOP_BAR, right = 0, bottom = 0, touch = true },
	{
		name = "notched phone (iPhone 14) landscape",
		w = 844,
		h = 390,
		left = 47,
		top = TOP_BAR,
		right = 47,
		bottom = 21,
		touch = true,
	},
	{
		name = "iPhone Pro Max landscape",
		w = 932,
		h = 430,
		left = 59,
		top = TOP_BAR,
		right = 59,
		bottom = 21,
		touch = true,
	},
	{ name = "iPad mini landscape", w = 1133, h = 744, left = 0, top = TOP_BAR, right = 0, bottom = 20, touch = true },
	{ name = "PC 1366 x 768", w = 1366, h = 768, left = 0, top = TOP_BAR, right = 0, bottom = 0, touch = false },
	{ name = "PC 1920 x 1080", w = 1920, h = 1080, left = 0, top = TOP_BAR, right = 0, bottom = 0, touch = false },
}

type Rect = { name: string, x0: number, y0: number, x1: number, y1: number }

-- The jump button in canvas design px.
local function jumpRect(vp: Viewport, s: number): Rect
	local small = math.min(vp.w, vp.h) <= 500
	local size = if small then 70 else 120
	local sx = vp.w - (if small then 95 else 170)
	local sy = vp.h - (if small then 90 else 210)
	local x0 = (sx - vp.left) / s
	local y0 = (sy - vp.top) / s
	return { name = "JUMP (Roblox)", x0 = x0, y0 = y0, x1 = x0 + size / s, y1 = y0 + size / s }
end

local function gapBetween(a: Rect, b: Rect): number
	local gx = math.max(b.x0 - a.x1, a.x0 - b.x1)
	local gy = math.max(b.y0 - a.y1, a.y0 - b.y1)
	return math.max(gx, gy)
end

local failures = 0
local checks = 0
local function fail(msg: string)
	failures += 1
	print("FAIL  " .. msg)
end

local sceneNames = {}
for name in HudLayout.SCENES do
	table.insert(sceneNames, name)
end
table.sort(sceneNames)

for _, vp in VIEWPORTS do
	local safeW = vp.w - vp.left - vp.right
	local safeH = vp.h - vp.top - vp.bottom
	local W, H, s = HudLayout.canvas(safeW, safeH)
	local shiftX, shiftY = HudLayout.centreShift(vp.w, vp.h, vp.left, vp.top, vp.right, vp.bottom)
	print(string.format("%s: safe %dx%d px, scale %.3f, canvas %.0fx%.0f", vp.name, safeW, safeH, s, W, H))
	do
		checks += 1
		local x0, y0, x1, y1 = HudLayout.rect(HudLayout.RETICLE, W, H)
		local cx = ((x0 + x1) / 2 + shiftX) * s + vp.left
		local cy = ((y0 + y1) / 2 + shiftY) * s + vp.top
		if math.abs(cx - vp.w / 2) > 0.5 or math.abs(cy - vp.h / 2) > 0.5 then
			fail(string.format("%s: the reticle is not at the screen centre (%.1f, %.1f)", vp.name, cx, cy))
		end
	end
	for _, scene in sceneNames do
		local rects: { Rect } = {}
		for _, name in HudLayout.SCENES[scene] do
			local box = (HudLayout :: any)[name]
			assert(box, "HudLayout has no box " .. name)
			local x0, y0, x1, y1 = HudLayout.rect(box, W, H)
			if HudLayout.SCREEN_CENTRED[name] then
				x0, x1, y0, y1 = x0 + shiftX, x1 + shiftX, y0 + shiftY, y1 + shiftY
			end
			table.insert(rects, { name = name, x0 = x0, y0 = y0, x1 = x1, y1 = y1 })
		end
		for _, r in rects do
			checks += 1
			if r.x0 < 0 or r.y0 < 0 or r.x1 > W + 1e-6 or r.y1 > H + 1e-6 then
				fail(
					string.format(
						"%s / %s: %s leaves the canvas (%.0f,%.0f)-(%.0f,%.0f)",
						vp.name,
						scene,
						r.name,
						r.x0,
						r.y0,
						r.x1,
						r.y1
					)
				)
			end
		end
		-- Sheets that switch touch controls off while up have no jump button to clear.
		if vp.touch and not HudLayout.SHEETS[scene] then
			table.insert(rects, jumpRect(vp, s))
		end
		for i = 1, #rects do
			for j = i + 1, #rects do
				checks += 1
				local g = gapBetween(rects[i], rects[j])
				if g < GAP then
					fail(
						string.format(
							"%s / %s: %s and %s %s (%.1f px)",
							vp.name,
							scene,
							rects[i].name,
							rects[j].name,
							if g < 0 then "overlap" else "are too close",
							g
						)
					)
				end
			end
		end
	end
end

print(string.format("\nhud layout: %d check(s), %d failure(s)", checks, failures))
process.exit(if failures > 0 then 1 else 0)
