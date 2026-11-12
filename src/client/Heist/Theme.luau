--!strict
-- Heist/Theme: the Crew Board UI tokens (PLAN_STEAM_PLUS §3.2, §4.3 U1; POLISH §4.1; premium D1, D2,
-- D11). Colours come from Shared/Heist/Palette (STYLE_BIBLE), numbers from Config.Ui; this module
-- only turns them into engine values (Font, Color3, image URIs). Heist/Motion holds the motion tokens.
--
-- Images: the UI kit's 9-slice panel, shadow and icon sheet (tools/ui/make_ui_kit.py) are uploaded as
-- Decals (Shared/Heist/UiAssets). A Decal id is not an image id: a recorded image id is used as is,
-- otherwise the server resolves it at boot (Heist/UiImages) and publishes it as the ReplicatedStorage
-- attribute EH_UiImage_<stem>. Until then Theme.onImage waits and every caller renders without the
-- image (plain frames, words instead of icons): never a broken image.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local Palette = require(HeistShared:WaitForChild("Palette"))
local UiAssets = require(HeistShared:WaitForChild("UiAssets"))

local U = Config.Ui

local Theme = {}

-- Fonts (D1: two families). Builder Sans for UI; one display face (Config switch, D8).
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
Theme.FONT = Font.new(BUILDER, Enum.FontWeight.ExtraBold)
Theme.FONT_BODY = Font.new(BUILDER, Enum.FontWeight.Bold)
Theme.FONT_HEAVY = Font.new(BUILDER, Enum.FontWeight.Heavy)

-- A display face by name ("LuckiestGuy" | "FredokaOne"); both are built-in Enum.Font families.
function Theme.displayFont(name: string?): Font
	return Font.fromName(name or U.DISPLAY_FACE)
end
Theme.FONT_DISPLAY = Theme.displayFont()

-- D2 type scale (design px): caption, body, title, display, hero.
Theme.TYPE = table.freeze({
	caption = U.TYPE_SCALE[1],
	body = U.TYPE_SCALE[2],
	title = U.TYPE_SCALE[3],
	display = U.TYPE_SCALE[4],
	hero = U.TYPE_SCALE[5],
})

-- The nearest type step to a size (ties: up below the body size, down from it).
function Theme.snapSize(size: number): number
	local scale = U.TYPE_SCALE
	local best, bestD = scale[1], math.huge
	for _, s in scale do
		local d = math.abs(s - size)
		if d < bestD or (d == bestD and s > best and size < Theme.TYPE.body) then
			best, bestD = s, d
		end
	end
	return best
end

-- D11: one radius, one stroke, one shadow.
Theme.RADIUS = U.RADIUS
Theme.STROKE = U.STROKE

-- Colour roles (POLISH §4.1 colour tokens).
Theme.COLOR = table.freeze({
	ink = Palette.ink,
	panel = Palette.ink,
	panelTop = Palette.inkHi,
	panelRim = Palette.plumHi,
	sunken = Palette.plumDeep,
	card = Palette.plum,
	text = Palette.white,
	textDim = Palette.steelHi,
	primary = Palette.CLONE_HUES[1], -- your seat hue (solo: Clone Cyan); callers pass the seat's hue
	loot = Palette.gold,
	neutral = Palette.steel,
	danger = Palette.alarm,
	done = Palette.ok,
	gusTick = Palette.amber,
	laser = Palette.alarm,
})

-- Is a colour light (ink text and no text stroke) or dark (white text with an ink stroke)?
function Theme.isLight(c: Color3): boolean
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B > 0.45
end

-- The ImageColor3 that makes EH_UI_Panel's body come out as `c` (the image body is grey PANEL_BODY_VALUE).
function Theme.panelTint(c: Color3): Color3
	local k = 1 / U.PANEL_BODY_VALUE
	return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
end

---------------------------------------------------------------------------
-- Images
---------------------------------------------------------------------------
local function attrName(stem: string): string
	return "EH_UiImage_" .. stem
end

-- The image URI of a UI kit stem, or nil while it is not known.
function Theme.image(stem: string): string?
	local entry = UiAssets[stem]
	if entry and entry.image > 0 then
		return "rbxassetid://" .. tostring(entry.image)
	end
	local v = ReplicatedStorage:GetAttribute(attrName(stem))
	if type(v) == "string" and v ~= "" then
		return v
	end
	return nil
end

-- Calls fn(uri) once the image is known (now, or when the server publishes it). Never with a broken id.
function Theme.onImage(stem: string, fn: (uri: string) -> ())
	local now = Theme.image(stem)
	if now then
		fn(now)
		return
	end
	if UiAssets[stem] == nil then
		return -- not uploaded: callers keep their fallback for good
	end
	local conn: RBXScriptConnection? = nil
	conn = ReplicatedStorage:GetAttributeChangedSignal(attrName(stem)):Connect(function()
		local uri = Theme.image(stem)
		if uri then
			if conn then
				conn:Disconnect()
			end
			fn(uri)
		end
	end)
end

Theme.IMAGE_PANEL = "EH_UI_Panel"
Theme.IMAGE_SHADOW = "EH_UI_Shadow"
Theme.IMAGE_ICONS = "EH_UI_Icons"

return Theme
