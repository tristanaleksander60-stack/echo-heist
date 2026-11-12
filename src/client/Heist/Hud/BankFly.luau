--!strict
-- Hud/BankFly: the HUD half of the bank moment (PLAN_STEAM_PLUS §5 "First bank"; premium F5, F7).
-- hud.onBank(amount, worldPos): "+$100!" leaves the van's spot on screen, arcs to the loot meter
-- (Config.Ui.BANK_FLY), and the meter's count-up waits for it (TopBar.holdCount), then counts up
-- and pops. Reduced motion: no flight, the meter just counts. At most MAX flights at once (MAX_LOW_TIER
-- on a low performance tier); more banks only count up. HeistClient calls it from the live Bank event,
-- next to the world half (world.onBank, WorldView: the van glows and bounces), when that exists.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local CrewBoard = require(HeistShared:WaitForChild("CrewBoard"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Heist = script.Parent.Parent
local Motion = require(Heist:WaitForChild("Motion"))
local Ui = require(Heist:WaitForChild("Ui"))

local U = Config.Ui
local BF = U.BANK_FLY

local BankFly = {}

function BankFly.build(ctx: any)
	local hud = ctx.hud
	local state = ctx.state
	local fxGui: ScreenGui = ctx.fxGui
	local gui: ScreenGui = ctx.gui
	local flying = 0

	-- A HUD object's centre (the HUD gui is CoreUISafeInsets) in the fx layer's space (ScreenInsets None,
	-- the same space as Camera:WorldToViewportPoint): GuiService:GetInsetArea(None) is the fullscreen
	-- rect relative to the core UI safe area (vault "Safe Areas and Insets" §5).
	local function centreOf(obj: GuiObject): Vector2
		local p = obj.AbsolutePosition + obj.AbsoluteSize / 2
		local ok, area = pcall(function()
			return GuiService:GetInsetArea(Enum.ScreenInsets.None)
		end)
		if ok and typeof(area) == "Rect" then
			return p - area.Min
		end
		return p + gui.AbsolutePosition - fxGui.AbsolutePosition
	end

	local function deviceScale(): number
		local s = ctx.root:FindFirstChildOfClass("UIScale")
		return if s then s.Scale else 1
	end

	function hud.onBank(amount: number, worldPos: Vector3?)
		local lootBox: GuiObject? = ctx.top and ctx.top.lootBox
		if not lootBox or not ctx.runHud.Visible or amount <= 0 then
			return
		end
		local cap = if (state.particleScale or 1) < 1 then BF.MAX_LOW_TIER else BF.MAX
		if Ui.reducedMotion() or flying >= cap then
			return -- the meter counts up on its own
		end
		local target = centreOf(lootBox)
		local from = target + Vector2.new(0, 160)
		local cam = workspace.CurrentCamera
		if worldPos and cam then
			local v = cam:WorldToViewportPoint(worldPos)
			if v.Z > 0 then
				from = Vector2.new(v.X, v.Y) - fxGui.AbsolutePosition
			end
		end
		flying += 1
		if ctx.top.holdCount then
			ctx.top.holdCount(BF.SECONDS)
		end
		local label = Ui.display(fxGui, {
			Name = "BankFly",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(from.X, from.Y),
			Size = UDim2.fromOffset(180, 48),
			TextSize = U.TYPE_SCALE[4],
			TextColor3 = Palette.gold,
			Text = Strings.bankFly(Ui.money(amount)),
		})
		local scale = Ui.scaleOf(label)
		scale.Scale = deviceScale()
		local u = Instance.new("NumberValue")
		u.Changed:Connect(function(t: number)
			local x, y = CrewBoard.arc(from.X, from.Y, target.X, target.Y, BF.ARC, t)
			label.Position = UDim2.fromOffset(x, y)
		end)
		Motion.timed(scale, BF.SECONDS, { Scale = deviceScale() * 0.6 }, "exit")
		local tw = Motion.timed(u, BF.SECONDS, { Value = 1 }, "exit")
		tw.Completed:Once(function()
			flying -= 1
			label:Destroy()
			u:Destroy()
		end)
	end
end

return BankFly
