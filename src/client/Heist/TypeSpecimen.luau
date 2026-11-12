--!strict
-- Heist/TypeSpecimen: the D8 type specimen (docs/GOLDEN_FRAMES.md "Typography specimen",
-- PLAN_STEAM_PLUS §3.2). Studio only: set the workspace attribute EH_Scenario = "TYPE" (before or
-- during Play) and this screen covers the view. It shows the wordmark "HEIST YOURSELF" (chunky rounded
-- capitals with a cyan double-exposure offset) and both candidate display faces, Luckiest Guy and
-- Fredoka One, at 14 / 24 / 36 / 64 px on a stamp, a button and a results line. The owner picks one:
-- Config.Ui.DISPLAY_FACE. Never shown in a live game (RunService:IsStudio()); a dev screen, so its
-- sample words live here and not in Strings.

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Wordmark = require(ReplicatedFirst:WaitForChild("Wordmark"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Scenario = require(Shared:WaitForChild("Heist"):WaitForChild("Scenario"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local U = Config.Ui

local TypeSpecimen = {}

local FACES = { "LuckiestGuy", "FredokaOne" }
local STAMP = "BUSTED!"
local BUTTON = "NEXT JOB"
local RESULT = "HAUL: $1,000 STOLEN"
local DESIGN_H = 940 -- the specimen is laid out for this height and scaled to the screen

local function text(parent: Instance, props: { [string]: any }, face: string, size: number): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = Theme.displayFont(face)
	t.TextSize = size
	t.TextColor3 = Palette.white
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.AutomaticSize = Enum.AutomaticSize.XY
	for k, v in props do
		(t :: any)[k] = v
	end
	Ui.textStroke(t, math.max(1, math.floor(size * U.DISPLAY_STROKE + 0.5)))
	t.Parent = parent
	return t
end

local function build(playerGui: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "EH_TypeSpecimen"
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local bg = Ui.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.25 })
	local page = Ui.frame(bg, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(1500, DESIGN_H),
		BackgroundTransparency = 1,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = page
	local function fit()
		local h = gui.AbsoluteSize.Y
		scale.Scale = if h > 0 then math.min(1, h / DESIGN_H, gui.AbsoluteSize.X / 1500) else 1
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)

	-- The wordmark: a cyan copy offset behind the white one (the double exposure), drawn by the one
	-- builder the loading card and the title beat use (ReplicatedFirst/Wordmark).
	local mark = Wordmark.build(page, { size = 110, width = 1400, face = U.DISPLAY_FACE, align = "Left" })
	mark.root.Position = UDim2.fromOffset(40, 24)
	Ui.label(page, {
		Position = UDim2.fromOffset(40, 160),
		Size = UDim2.fromOffset(1400, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.steelHi,
		Text = "Config.Ui.DISPLAY_FACE = "
			.. U.DISPLAY_FACE
			.. "  ·  UI face: Builder Sans  ·  pick one face for stamps of 3 words or fewer",
	})

	for row, face in FACES do
		local y = 210 + (row - 1) * 360
		Ui.label(page, {
			Position = UDim2.fromOffset(40, y),
			Size = UDim2.fromOffset(600, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 24,
			TextColor3 = Palette.gold,
			Text = face,
		})
		local x = 40
		for _, size in U.SPECIMEN_SIZES do
			local t = text(
				page,
				{ Position = UDim2.fromOffset(x, y + 40 + (64 - size)), Text = tostring(size) .. " PX" },
				face,
				size
			)
			x += math.max(60, t.TextBounds.X) + 40 + size
		end
		-- the stamp: an ink plate with an Alarm Red rim, rotated
		local plate = Ui.panel(page, {
			Position = UDim2.fromOffset(40, y + 140),
			Size = UDim2.fromOffset(420, 110),
			Rotation = -6,
		}, Palette.alarm)
		text(plate, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Palette.alarm,
			Text = STAMP,
		}, face, 64)
		-- a primary button with the face
		Ui.button(page, {
			Position = UDim2.fromOffset(540, y + 150),
			Size = UDim2.fromOffset(280, 80),
			BackgroundColor3 = Palette.CLONE_HUES[1],
			FontFace = Theme.displayFont(face),
			TextSize = 36,
			Text = BUTTON,
		}, function() end)
		-- a results line
		text(page, { Position = UDim2.fromOffset(880, y + 168), TextColor3 = Palette.gold, Text = RESULT }, face, 36)
	end
	gui.Parent = playerGui
	fit()
	return gui
end

-- Shows the specimen while EH_Scenario == "TYPE" in Studio (Hud.new calls this once).
function TypeSpecimen.watch(playerGui: Instance)
	if not RunService:IsStudio() then
		return
	end
	local gui: ScreenGui? = nil
	local function refresh()
		local on = Scenario.resolve(RunService:IsStudio(), workspace:GetAttribute(Scenario.ATTRIBUTE)) == "TYPE"
		if on and not gui then
			gui = build(playerGui)
		elseif not on and gui then
			gui:Destroy()
			gui = nil
		end
	end
	workspace:GetAttributeChangedSignal(Scenario.ATTRIBUTE):Connect(refresh)
	refresh()
end

return TypeSpecimen
