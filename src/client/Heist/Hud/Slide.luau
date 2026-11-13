--!strict
-- Hud/Slide: the SLIDE button (Config.Slide; the slide itself is Heist/Slide). Bottom row, left of Interact in a run
-- and of USE in the hideout (HudLayout.SLIDE), shown in first person whenever a slide may start (ctx.actions.
-- slideAllowed): press to slide; with the FAST pill held (touch) it is the fast slide. On a keyboard or a gamepad it
-- stays up as the hint, with its key cap (Ctrl / B; Hud/Common.keyCap).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Theme = require(script.Parent.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local U = Config.Ui

local Slide = {}

function Slide.build(ctx: any): any
	local actions = ctx.actions
	local state = ctx.state
	local ui = {}

	local btn = Ui.button(ctx.root, {
		Name = "Slide",
		BackgroundColor3 = Palette.steelHi,
		TextSize = Theme.TYPE.caption,
		TextWrapped = true,
		Text = Strings.SLIDE,
		Visible = false,
	}, function() end, "")
	Common.place(btn, HudLayout.SLIDE)
	Ui.iconWord(btn, "fast_forward", "top", U.ICON_SMALL)
	Common.keyCap(btn, "slide")
	btn.InputBegan:Connect(function(input: InputObject)
		local t = input.UserInputType
		if (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1) and actions.slide then
			actions.slide(ctx.ffHeld == true) -- FAST + SLIDE: the fast one
		end
	end)
	ui.button = btn

	local function update()
		local fp = actions.cameraMode ~= nil and actions.cameraMode() == "fp"
		local here = (state.where == "heist" and ctx.runHud.Visible)
			or (state.where == "garage" and state.lobbyRoam == true)
		local can = fp and here and ctx.gui.Enabled and actions.slideAllowed ~= nil and actions.slideAllowed()
		if btn.Visible ~= can then
			btn.Visible = can
		end
	end
	if RunService:IsClient() then -- a server builds the HUD only for an engine check (tests/client_engine.luau)
		RunService.RenderStepped:Connect(update)
	end

	return ui
end

return Slide
