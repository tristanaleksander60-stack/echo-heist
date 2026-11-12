--!strict
-- ReplicatedFirst/Wordmark: the one builder of the "HEIST YOURSELF" wordmark (MASTERPLAN §2.2: chunky
-- rounded capitals with a cyan double-exposure offset copy behind, "Rob With Your Clones" in a small
-- strap under it). Used by the loading card and the title beat (frame 0, before ReplicatedStorage) and
-- by the D8 type specimen (Heist/TypeSpecimen), so the mark is drawn one way everywhere.
--
--   Wordmark.build(parent, opts) -> Mark
--     opts.size     type size in px (the display face; stroke = Brand.DISPLAY_STROKE of it)
--     opts.width    box width in px (the mark is centred in it, or left-aligned with align = "Left")
--     opts.copies   tinted copies behind the white mark (default 1: the cyan double exposure). The
--                   title beat asks for 3: copies 2 and 3 start hidden in copy 1's place and split out.
--     opts.strap    draw the strap line under the mark
--     opts.face     display face name (default Brand.FACE)
--   Wordmark.offset(size) -> Vector2   the double-exposure offset for a type size
--
-- Copies are siblings drawn under the white mark (ZIndex), never its children (a child always draws
-- over its parent under Sibling ZIndexBehavior).

local Brand = require(script.Parent:WaitForChild("Brand"))

export type Mark = {
	root: Frame,
	main: TextLabel,
	copies: { TextLabel },
	strap: TextLabel?,
	size: number,
	offset: Vector2,
}

export type Opts = {
	size: number,
	width: number,
	copies: number?,
	strap: boolean?,
	face: string?,
	align: string?,
}

local Wordmark = {}

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

function Wordmark.offset(size: number): Vector2
	local k = size / Brand.OFFSET_AT
	return Vector2.new(Brand.WORDMARK_OFFSET[1] * k, Brand.WORDMARK_OFFSET[2] * k)
end

local function stroke(obj: TextLabel, size: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = hex(Brand.COLOR.ink)
	s.Thickness = math.max(1, math.floor(size * Brand.DISPLAY_STROKE + 0.5))
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = obj
	return s
end

local function line(parent: Instance, name: string, font: Font, size: number, width: number, align: string): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.FontFace = font
	t.TextSize = size
	t.Size = UDim2.fromOffset(width, math.ceil(size * 1.15))
	t.TextXAlignment = if align == "Left" then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.Parent = parent
	return t
end

function Wordmark.build(parent: Instance, opts: Opts): Mark
	local size = opts.size
	local width = opts.width
	local align = opts.align or "Center"
	local n = math.max(1, opts.copies or 1)
	local face = Font.fromName(opts.face or Brand.FACE)
	local markH = math.ceil(size * 1.15)
	local strapSize = math.max(12, math.floor(size * 0.25 + 0.5))
	local height = markH + (if opts.strap then math.ceil(strapSize * 1.6) else 0)

	local root = Instance.new("Frame")
	root.Name = "Wordmark"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(width, height)

	local off = Wordmark.offset(size)
	local copies: { TextLabel } = {}
	for k = 1, n do
		local c = line(root, "Copy" .. k, face, size, width, align)
		c.Text = Brand.WORDMARK
		c.TextColor3 = hex(Brand.COLOR.hues[(k - 1) % #Brand.COLOR.hues + 1])
		c.Position = UDim2.fromOffset(off.X, off.Y)
		c.ZIndex = n - k + 1 -- copy 1 nearest the white mark
		c.TextTransparency = if k == 1 then 0 else 1
		local s = stroke(c, size)
		s.Transparency = if k == 1 then 0 else 1
		copies[k] = c
	end
	local main = line(root, "Mark", face, size, width, align)
	main.Text = Brand.WORDMARK
	main.TextColor3 = hex(Brand.COLOR.white)
	main.ZIndex = n + 1
	stroke(main, size)

	local strap: TextLabel? = nil
	if opts.strap then
		local s = line(root, "Strap", Font.new(Brand.BODY_FONT, Enum.FontWeight.Bold), strapSize, width, align)
		s.Text = Brand.STRAP
		s.TextColor3 = hex(Brand.COLOR.steelHi)
		s.Position = UDim2.fromOffset(0, markH + math.floor(strapSize * 0.3))
		s.ZIndex = n + 1
		strap = s
	end
	root.Parent = parent
	return { root = root, main = main, copies = copies, strap = strap, size = size, offset = off }
end

return Wordmark
