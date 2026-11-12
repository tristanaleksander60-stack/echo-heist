--!strict
-- Heist/Icons: the icon sheet (PLAN_STEAM_PLUS §4.3 U2, premium D8): one 24-unit grid, a 2.5-unit
-- stroke, round caps, white glyphs with a thin ink outline so ImageColor3 tints them. Drawn by
-- tools/ui/make_ui_kit.py into assets/ui/EH_UI_Icons.png; the cells are in IconsData (generated).
--
-- Icons never render broken: an ImageLabel is made only once the sheet's image id is known
-- (Theme.onImage). Until then (and for good if the sheet is missing) callers show their word.
-- Names: rewind, fast_forward, play, pause, menu, clone, you, plate, door, laser, loot, van, gus,
-- star, star_empty, star_half, hidden, alarm, sunrise, delete, undo, replay, invite, settings,
-- close, cross, check, lock, crown, camera, gift, coin, bolt, seat_circle, seat_square,
-- seat_triangle, seat_diamond, gus_eye.

local Theme = require(script.Parent:WaitForChild("Theme"))
local IconsData = require(script.Parent:WaitForChild("IconsData"))

local Icons = {}

Icons.CELL = IconsData.CELL

-- The seat shapes (●■▲◆) as icons, so identity glyphs render the same on every platform.
Icons.SEATS = table.freeze({ "seat_circle", "seat_square", "seat_triangle", "seat_diamond" })

function Icons.has(name: string): boolean
	return IconsData.cells[name] ~= nil
end

function Icons.seat(seat: number): string
	return Icons.SEATS[(seat - 1) % #Icons.SEATS + 1]
end

-- The sheet's image URI now, or nil while it is not resolved.
function Icons.ready(): boolean
	return Theme.image(Theme.IMAGE_ICONS) ~= nil
end

-- Makes the icon ImageLabel under `parent` (props applied), or nil when the sheet is not known yet.
function Icons.make(parent: Instance, name: string, props: { [string]: any }?): ImageLabel?
	local cell = IconsData.cells[name]
	local uri = Theme.image(Theme.IMAGE_ICONS)
	if cell == nil or uri == nil then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.BackgroundTransparency = 1
	img.Image = uri
	img.ImageRectOffset = cell
	img.ImageRectSize = Vector2.new(IconsData.CELL, IconsData.CELL)
	img.ScaleType = Enum.ScaleType.Fit
	img.Active = false
	if props then
		for k, v in props do
			(img :: any)[k] = v
		end
	end
	img.Parent = parent
	return img
end

-- Like make, but also later: `onReady(icon)` runs once the icon exists (at once if the sheet is known).
-- Returns nothing; the caller keeps showing its word until then.
function Icons.attach(parent: Instance, name: string, props: { [string]: any }?, onReady: ((ImageLabel) -> ())?)
	if IconsData.cells[name] == nil then
		return
	end
	Theme.onImage(Theme.IMAGE_ICONS, function()
		if parent.Parent == nil then
			return -- destroyed while waiting
		end
		local old = parent:FindFirstChild("Icon")
		if old then
			old:Destroy()
		end
		local icon = Icons.make(parent, name, props)
		if icon and onReady then
			onReady(icon)
		end
	end)
end

-- Swaps an existing icon's cell (same label, new glyph). No-op when it is not there yet.
function Icons.set(icon: ImageLabel?, name: string)
	local cell = IconsData.cells[name]
	if icon and cell then
		icon.ImageRectOffset = cell
	end
end

return Icons
