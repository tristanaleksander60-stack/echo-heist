--!strict
-- Hud/TopBar: the run HUD's top row (MASTERPLAN §7.4): "RUN 3" + the timer + the run
-- bar with event markers (top centre), the loot meter with its count-up (top left), the
-- clone strip, and the lines under the bar (Alarm Run counter, objective line).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Sound = require(script.Parent.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local AU = Config.Audio
local RED = Common.RED

local TopBar = {}

function TopBar.build(ctx: any): any
	local state = ctx.state
	local runHud = ctx.runHud
	local bar = {}

	local top = Ui.frame(runHud, { Name = "Top" })
	Common.place(top, HudLayout.TOP)
	Ui.corner(top, 14)
	bar.runLabel = Ui.label(top, {
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.fromOffset(170, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 24,
		TextColor3 = Palette.CLONE_HUES[1],
		Text = Strings.run(1),
	})
	local timerLabel = Ui.label(top, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 4),
		Size = UDim2.fromOffset(130, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 30,
		Text = Ui.clock(30),
	})
	bar.timerLabel = timerLabel
	local timerScale = Instance.new("UIScale")
	timerScale.Parent = timerLabel
	bar.timerScale = timerScale
	local runBar = Ui.frame(top, {
		Name = "RunBar",
		Position = UDim2.new(0, 14, 1, -16),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = Palette.plumHi,
		BackgroundTransparency = 0,
	})
	Ui.corner(runBar, 3)
	local barFill = Ui.frame(runBar, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0,
	})
	Ui.corner(barFill, 3)
	bar.barFill = barFill
	local markers = Ui.frame(runBar, { Name = "Markers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	-- Alarm Run counter (§7.3): "◎ VAN LEAVES 0:14 · SHUTTER 0:04" in Alarm Red.
	local alarmPill = Ui.frame(runHud, { Name = "Alarm", Visible = false })
	Common.place(alarmPill, HudLayout.ALARM)
	Ui.corner(alarmPill, 12)
	Ui.stroke(alarmPill, Palette.alarm, 2)
	bar.alarmPill = alarmPill
	bar.alarmLabel = Ui.label(alarmPill, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		TextColor3 = Palette.alarm,
		Text = "",
	})

	local objective = Ui.label(runHud, {
		Name = "Objective",
		TextSize = 22,
		TextStrokeTransparency = 0.2,
		Text = "",
	})
	Common.place(objective, HudLayout.OBJECTIVE)
	bar.objective = objective

	local lootBox = Ui.frame(runHud, { Name = "Loot" })
	Common.place(lootBox, HudLayout.LOOT)
	Ui.corner(lootBox, 12)
	local lootLabel = Ui.label(lootBox, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		TextColor3 = Palette.gold,
		Text = Strings.lootOfGoal(Ui.money(0), Ui.money(100)),
	})
	local lootPop = Instance.new("UIScale")
	lootPop.Name = "Pop"
	lootPop.Parent = lootBox
	bar.lootBox = lootBox

	local strip = Ui.frame(runHud, { Name = "CloneStrip", BackgroundTransparency = 0.4 })
	Common.place(strip, HudLayout.STRIP)
	Ui.corner(strip, 12)
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stripLayout.Padding = UDim.new(0, 4)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip
	local stripPad = Instance.new("UIPadding")
	stripPad.PaddingRight = UDim.new(0, 6)
	stripPad.Parent = strip

	---------------------------------------------------------------------------
	-- Run-bar markers
	---------------------------------------------------------------------------
	function bar.clearMarkers()
		for _, c in markers:GetChildren() do
			c:Destroy()
		end
	end

	function bar.marker(t: number, length: number, color: Color3, text: string)
		local m = Ui.label(markers, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.clamp(t / math.max(length, 0.01), 0, 1), 0.5),
			Size = UDim2.fromOffset(16, 16),
			TextSize = 16,
			TextColor3 = color,
			Text = text,
		})
		m.TextStrokeTransparency = 0.2
	end

	---------------------------------------------------------------------------
	-- Clone strip: one chip per clone of yours (glyph + digit, red-flagged = ✕)
	---------------------------------------------------------------------------
	function bar.renderStrip()
		for _, c in strip:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local deck = state.deck
		if not deck then
			return
		end
		local seat = state.mySeat or 1
		local hue = Palette.hueFor(seat)
		for i, s in deck.slots do
			local red = RED[s.status] == true
			local chip = Ui.label(strip, {
				Size = UDim2.fromOffset(34, 34),
				TextSize = 18,
				TextColor3 = if red then Palette.tapeGrey else hue,
				Text = if red then Strings.stripBusted(Palette.glyphFor(seat)) else Palette.badge(seat, i),
				LayoutOrder = i,
			})
			chip.BackgroundTransparency = 1
		end
	end

	---------------------------------------------------------------------------
	-- Loot meter count-up (§7.3: 0.35-1.0 s, a rising tick, a landing ding)
	---------------------------------------------------------------------------
	local shown, countFrom, countTo, countT0, countDur, countTicks, counting = 0, 0, 0, 0, 0, 0, false

	function bar.resetCount()
		shown, countFrom, countTo, counting = 0, 0, 0, false
	end

	local function updateCount(now: number)
		local banked = (state.folder and state.folder:GetAttribute("Banked")) or 0
		if type(banked) ~= "number" then
			banked = 0
		end
		if banked ~= countTo then
			if banked > countTo then
				countFrom = shown
				countDur = math.clamp(0.35 + (banked - shown) / 1000 * 0.3, 0.35, 1.0)
				countT0 = now
				countTicks = 0
				counting = true
			else
				shown = banked
				counting = false
			end
			countTo = banked
		end
		if counting then
			local u = math.clamp((now - countT0) / countDur, 0, 1)
			shown = countFrom + (countTo - countFrom) * u
			local want = math.floor((now - countT0) / 0.08)
			if want > countTicks and u < 1 then
				countTicks = want
				Sound.play("CountTick", { step = math.min(countTicks - 1, #AU.COUNT_UP_STEPS - 1) })
			end
			if u >= 1 then
				counting = false
				Sound.play("CountDone")
			end
		end
	end

	local function lootText(): string
		local level = state.level
		local tiers = level and level.tiers
		if tiers then
			local met = (state.folder and state.folder:GetAttribute("TierMet")) or 0
			met = if type(met) == "number" then met else 0
			local nextTier = tiers[met + 1]
			if nextTier then
				return Strings.lootOfTier(Ui.money(shown), Ui.money(nextTier), met + 1)
			end
			return Strings.lootAllTiers(Ui.money(shown), #tiers)
		end
		local goal = if level then level.goal else 0
		return Strings.lootOfGoal(Ui.money(shown), Ui.money(goal))
	end

	-- The meter lands every frame, in a run and between runs.
	function bar.updateLoot(now: number)
		updateCount(now)
		lootLabel.Text = lootText()
	end

	return bar
end

return TopBar
