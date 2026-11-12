--!strict
-- Heist/Palette: the docs/STYLE_BIBLE.md v0 colours as Color3 tokens, plus the clone
-- identity set (MASTERPLAN §0 C5, §6.2): hue + glyph + number per crew seat.
-- Greybox only: the Blender kit (assets/Kit.rbxm) replaces the level look later.

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local Palette = {}

Palette.ink = hex("#1C1F3B")
Palette.inkHi = hex("#2A2D52")
Palette.plumDeep = hex("#2E2A50")
Palette.plum = hex("#3A3560")
Palette.plumHi = hex("#4D4778")
-- Floor (W3, roblox_quality §0): floors are lit at night, so they sit a value step above Ink (Ink stays
-- for the table edge, stands and the outer void). Audited in tools/blender/eh_palette.py (RUNTIME).
Palette.floor = hex("#3A365C")
Palette.marbleLo = hex("#A8987A")
Palette.marble = hex("#D8C8A8")
Palette.marbleHi = hex("#EDE2C8")
Palette.steelLo = hex("#4E5675")
Palette.steel = hex("#7C86A6")
Palette.steelHi = hex("#A9B2CC")
Palette.goldLo = hex("#B87A0A")
Palette.gold = hex("#FFC21F")
Palette.goldHi = hex("#FFE69C")
Palette.white = hex("#FFFFFF")
Palette.alarm = hex("#FF3838") -- Alarm Red (owner-confirmed 2026-11-12; the plan's #FF3348 was too close to Magenta)
Palette.amber = hex("#FFD27A")
Palette.exit = hex("#F4F7FF")
Palette.bulbWarm = hex("#F6C0A2") -- Bulb Warm: lamps, idle plate rims, fairy lights (rule N1 vs every clone hue)
Palette.tapeGrey = hex("#8A8FA8")
Palette.ok = hex("#2FBF71") -- Holly Green, used only as a UI "done" state with a word
-- Boot Chalk: Gus's boot prints (his next 2 s of patrol, PLAN A5), a light value step on every floor
-- with an Ink rim for lit pools; never Torch Amber (the cone's). Audited in tools/blender/eh_palette.py
-- (RUNTIME_SIGNALS: Oklab >= 0.15 from every clone hue, Torch Amber and Alarm Red).
Palette.bootPrint = hex("#9098C0")
-- Chalk Lime: the "Show me?" chalk-outline ghost and its dashed trail (Hud/Hints, PLAN_STEAM_PLUS §5
-- "Stuck"). Not white, not gold, not a clone hue: Oklab >= 0.15 from every clone hue, white, Gold,
-- Gold Hi, Torch Amber, Alarm Red and Boot Chalk (tools/blender/eh_palette.py RUNTIME_SIGNALS).
Palette.ghostChalk = hex("#98F060")
-- Christmas layer (STYLE_BIBLE: Santa hats and berries are Ribbon Burgundy, never Alarm Red)
Palette.ribbon = hex("#8C2F4B")
Palette.snow = hex("#C0C3D5")

-- Clone identity per seat: P1/solo Cyan ●1, P2 Magenta ■2, P3 Indigo ▲3, P4 Ghost White ◆4.
Palette.CLONE_HUES = table.freeze({
	hex("#3DE8FF"),
	hex("#FF4FD8"),
	hex("#6A5CFF"),
	hex("#F4F7FF"),
})
Palette.GLYPHS = table.freeze({ "●", "■", "▲", "◆" })

function Palette.hueFor(seat: number): Color3
	return Palette.CLONE_HUES[(seat - 1) % #Palette.CLONE_HUES + 1]
end

function Palette.glyphFor(seat: number): string
	return Palette.GLYPHS[(seat - 1) % #Palette.GLYPHS + 1]
end

-- Badge text for clone slot n of a seat: "●3".
function Palette.badge(seat: number, slot: number): string
	return Palette.glyphFor(seat) .. tostring(slot)
end

-- Darker version of a colour (age ramp, other players' clones).
function Palette.dim(c: Color3, factor: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * factor, 0, 1))
end

return table.freeze(Palette)
