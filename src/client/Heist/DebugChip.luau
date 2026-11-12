--!strict
-- Heist/DebugChip: Studio-only clone diagnostic chip (PLAN_STEAM_PLUS §1 S1 item 4), so every
-- owner screenshot carries the diagnosis: "clones 3 drawn / 3 healthy / tier 1 / avatar".
--   drawn    clones visible right now (EchoView.visibleCount)
--   healthy  clones that passed the last CloneHealth check (about once a second)
--   tier     the runtime performance tier (Telemetry; 1 = quality, 4 = minimum)
--   avatar | mannequin | -   what your own clones draw as (- before your first clone)
-- Never built outside Studio (RunService:IsStudio), never on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local Palette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heist"):WaitForChild("Palette"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local DebugChip = {}

-- The chip's text (pure; the engine tests read it).
function DebugChip.text(drawn: number, healthy: number, tier: number, kind: string): string
	return string.format("clones %d drawn / %d healthy / tier %d / %s", drawn, healthy, tier, kind)
end

-- echo: an EchoView (stats); tierOf: the current performance tier.
function DebugChip.start(echo: any, tierOf: () -> number)
	if not RunService:IsStudio() or not RunService:IsClient() then
		return
	end
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "EH_DebugChip"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = false
	local label = Ui.label(gui, {
		Name = "Chip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(330, 22),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.3,
		TextColor3 = Palette.white,
		TextSize = 14,
		FontFace = Ui.FONT_BODY,
		Text = "",
	})
	Ui.corner(label, 6)
	gui.Parent = player:WaitForChild("PlayerGui")
	local period = 1 / math.max(Config.Heist.DEBUG_CHIP_HZ, 0.1)
	task.spawn(function()
		while gui.Parent do
			local ok, drawn, healthy, kind = pcall(echo.stats)
			if ok then
				label.Text = DebugChip.text(drawn, healthy, tierOf(), kind)
			end
			task.wait(period)
		end
	end)
end

return DebugChip
