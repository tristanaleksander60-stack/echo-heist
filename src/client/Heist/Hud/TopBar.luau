--!strict
-- Hud/TopBar: the run HUD's top row (MASTERPLAN §7.4): "RUN 3" + the timer + the run
-- bar with event markers (top centre), the loot meter with its count-up (top left), the
-- clone strip centred under the timer, and the line under it (objective, or the Alarm
-- Run counter while it runs). Boxes come from Shared/Heist/HudLayout.

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
local H = Config.Heist
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
		Position = UDim2.fromOffset(14, 3),
		Size = UDim2.fromOffset(150, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 24,
		TextColor3 = Palette.CLONE_HUES[1],
		Text = Strings.run(1),
	})
	local timerLabel = Ui.label(top, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 3),
		Size = UDim2.fromOffset(110, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 28,
		Text = Ui.clock(30),
	})
	bar.timerLabel = timerLabel
	local timerScale = Instance.new("UIScale")
	timerScale.Parent = timerLabel
	bar.timerScale = timerScale
	local runBar = Ui.frame(top, {
		Name = "RunBar",
		Position = UDim2.new(0, 14, 1, -12),
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

	-- Alarm Run counter (§7.3): "VAN LEAVES 0:14 · DOORS LOCK 0:04" in Alarm Red; it
	-- takes the objective line's place while it runs.
	local alarmPill = Ui.frame(runHud, { Name = "Alarm", Visible = false })
	Common.place(alarmPill, HudLayout.ALARM)
	Ui.corner(alarmPill, 12)
	Ui.stroke(alarmPill, Palette.alarm, 2)
	bar.alarmPill = alarmPill
	local alarmLabel = Ui.label(alarmPill, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextColor3 = Palette.alarm,
		Text = "",
	})
	Ui.fit(alarmLabel, 22, H.UI_TEXT_MIN)
	bar.alarmLabel = alarmLabel

	local objective = Ui.label(runHud, {
		Name = "Objective",
		TextStrokeTransparency = 0.2,
		Text = "",
	})
	Common.place(objective, HudLayout.OBJECTIVE)
	Ui.fit(objective, 22, H.UI_TEXT_MIN)
	bar.objective = objective

	local lootBox = Ui.frame(runHud, { Name = "Loot" })
	Common.place(lootBox, HudLayout.LOOT)
	Ui.corner(lootBox, 12)
	local lootLabel = Ui.label(lootBox, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextColor3 = Palette.gold,
		Text = Strings.lootOfGoal(Ui.money(0), Ui.money(100)),
	})
	Ui.fit(lootLabel, 22, H.UI_TEXT_MIN)
	local lootPop = Instance.new("UIScale")
	lootPop.Name = "Pop"
	lootPop.Parent = lootBox
	bar.lootBox = lootBox

	-- Clone strip, centred under the timer (PLAN S8: never under the top-right CoreGui).
	local strip = Ui.frame(runHud, { Name = "CloneStrip", BackgroundTransparency = 1 })
	Common.place(strip, HudLayout.STRIP)
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stripLayout.Padding = UDim.new(0, 4)
	stripLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stripLayout.Parent = strip

	-- The run box and strip step aside while the Clone Deck is open (it shows the clones,
	-- and the message rail sits there between runs).
	local runBoxShown = true
	function bar.setRunBoxShown(on: boolean)
		runBoxShown = on
		top.Visible = on
		strip.Visible = on
	end

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
	-- Clone strip: one pill per clone of yours, in your seat's colour with its number
	-- (PLAN S4: the seat glyphs were text glyphs). Red-flagged: grey, number struck out.
	---------------------------------------------------------------------------
	local function chip(text: string, color: Color3, order: number)
		local size = HudLayout.STRIP_CHIP
		local c = Ui.label(strip, {
			Size = UDim2.fromOffset(size, size),
			TextSize = 16,
			TextColor3 = Palette.ink,
			TextStrokeTransparency = 1,
			RichText = true,
			Text = text,
			LayoutOrder = order,
		})
		c.BackgroundColor3 = color
		c.BackgroundTransparency = 0
		Ui.corner(c, size // 2)
	end

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
		local hue = Palette.hueFor(state.mySeat or 1)
		local n = #deck.slots
		local max = HudLayout.STRIP_MAX_CHIPS
		local shown = if n > max then max - 1 else n
		for i = 1, shown do
			local red = RED[deck.slots[i].status] == true
			chip(
				if red then Strings.cloneNumberBusted(i) else Strings.cloneNumber(i),
				if red then Palette.tapeGrey else hue,
				i
			)
		end
		if n > shown then
			chip(Strings.moreClones(n - shown), Palette.steelHi, max)
		end
		strip.Visible = runBoxShown
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
			return Strings.lootAllTiers(Ui.money(shown))
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
