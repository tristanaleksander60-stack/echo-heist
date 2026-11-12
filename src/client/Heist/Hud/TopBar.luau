--!strict
-- Hud/TopBar: the run HUD's top row (MASTERPLAN §7.4): "RUN 3" + the timer + the run
-- bar with event markers (top centre), the loot meter with its count-up (top left), the
-- clone strip centred under the timer, and the line under it (objective, or the Alarm
-- Run counter while it runs). Boxes come from Shared/Heist/HudLayout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local CrewBoard = require(HeistShared:WaitForChild("CrewBoard"))
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Icons = require(script.Parent.Parent:WaitForChild("Icons"))
local Sound = require(script.Parent.Parent:WaitForChild("Sound"))
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local AU = Config.Audio
local H = Config.Heist
local U = Config.Ui
local RED = Common.RED

local TopBar = {}

function TopBar.build(ctx: any): any
	local state = ctx.state
	local runHud = ctx.runHud
	local bar = {}

	local top = Ui.panel(runHud, { Name = "Top" })
	Common.place(top, HudLayout.TOP)
	bar.runLabel = Ui.label(top, {
		Position = UDim2.fromOffset(14, 3),
		Size = UDim2.fromOffset(150, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 24,
		TextColor3 = Palette.CLONE_HUES[1],
		Text = Strings.run(1),
	})
	-- The tape counter: fixed-width digit slots (D1), so the digits never jitter.
	local timer = Ui.digits(top, {
		Name = "Timer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 3),
		Size = UDim2.fromOffset(110, 30),
	}, U.TIMER_SIZE)
	timer.set(Ui.clock(30))
	bar.timer = timer
	local timerColor = Palette.white
	-- "0:27" in white, Alarm Red in the last seconds; pops 1.12 -> 1 on each whole second near the end.
	function bar.setTimer(text: string, color: Color3)
		timer.set(text)
		if color ~= timerColor then
			timerColor = color
			timer.setColor(color)
		end
	end
	function bar.popTimer()
		Ui.pop(timer.frame)
	end
	local runBar = Ui.frame(top, {
		Name = "RunBar",
		Position = UDim2.new(0, 14, 1, -13),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = Palette.plumDeep,
		BackgroundTransparency = 0,
	})
	Ui.pill(runBar)
	local barFill = Ui.frame(runBar, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0,
	})
	Ui.pill(barFill)
	local fillShade = Instance.new("UIGradient")
	fillShade.Color = ColorSequence.new(Palette.white, Palette.CLONE_HUES[1])
	fillShade.Parent = barFill
	bar.barFill = barFill
	function bar.setSeatHue(hue: Color3)
		fillShade.Color = ColorSequence.new(Palette.white, hue)
	end
	-- World events under the bar (Gus's turns, laser on-spans), your clones' events on it.
	local world = Ui.frame(runBar, {
		Name = "World",
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundTransparency = 1,
	})
	local markers = Ui.frame(runBar, { Name = "Markers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	-- Alarm Run counter (§7.3): "VAN LEAVES 0:14 · DOORS LOCK 0:04" in Alarm Red; it
	-- takes the objective line's place while it runs.
	local alarmPill = Ui.panel(runHud, { Name = "Alarm", Visible = false }, Palette.alarm)
	Common.place(alarmPill, HudLayout.ALARM)
	bar.alarmPill = alarmPill
	local alarmLabel = Ui.label(alarmPill, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextColor3 = Palette.alarm,
		Text = "",
	})
	Ui.fit(alarmLabel, 22, H.UI_TEXT_MIN)
	Ui.iconWord(alarmLabel, "alarm", "left", U.ICON_SMALL)
	bar.alarmLabel = alarmLabel

	local objective = Ui.label(runHud, {
		Name = "Objective",
		Text = "",
	})
	Common.place(objective, HudLayout.OBJECTIVE)
	Ui.fit(objective, 22, H.UI_TEXT_MIN)
	bar.objective = objective

	local lootBox = Ui.panel(runHud, { Name = "Loot" })
	Common.place(lootBox, HudLayout.LOOT)
	local lootLabel = Ui.label(lootBox, {
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextColor3 = Palette.gold,
		Text = Strings.lootOfGoal(Ui.money(0), Ui.money(100)),
	})
	Ui.fit(lootLabel, 22, H.UI_TEXT_MIN)
	Ui.iconWord(lootLabel, "coin", "left", U.ICON_SMALL)
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
		for _, c in world:GetChildren() do
			c:Destroy()
		end
	end

	-- A clone event on the bar: its icon (coin, bolt, cross), or the word until the sheet is known.
	function bar.marker(t: number, length: number, color: Color3, text: string, icon: string?)
		local m = Ui.label(markers, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.clamp(t / math.max(length, 0.01), 0, 1), 0.5),
			Size = UDim2.fromOffset(16, 16),
			TextSize = 16,
			TextColor3 = color,
			Text = text,
		})
		if icon then
			Icons.attach(m, icon, { Size = UDim2.fromScale(1, 1), ImageColor3 = color }, function()
				m.Text = ""
			end)
		end
	end

	-- Next-event markers (Shared/Heist/RunMarkers): Gus's turn points as amber ticks, the lasers'
	-- on-spans as red segments under the bar (the gaps are the windows your clones open).
	function bar.worldMarkers(m: any, length: number)
		for _, c in world:GetChildren() do
			c:Destroy()
		end
		local len = math.max(length, 0.01)
		for _, laser in m.lasers do
			for _, span in laser.on do
				local seg = Ui.frame(world, {
					Position = UDim2.new(math.clamp(span.t0 / len, 0, 1), 0, 0, 1),
					Size = UDim2.new(math.clamp((span.t1 - span.t0) / len, 0, 1), 0, 0, 3),
					BackgroundColor3 = Palette.alarm,
					BackgroundTransparency = 0.1,
				})
				Ui.pill(seg)
			end
		end
		for _, t in m.gus do
			Ui.frame(world, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(math.clamp(t / len, 0, 1), 0, 0, -4),
				Size = UDim2.fromOffset(2, 14),
				BackgroundColor3 = Palette.amber,
				BackgroundTransparency = 0,
				ZIndex = 2,
			})
		end
	end

	---------------------------------------------------------------------------
	-- Clone strip: one pill per clone of yours, in your seat's colour with its number
	-- (PLAN S4: the seat glyphs were text glyphs). Red-flagged: grey, number struck out.
	---------------------------------------------------------------------------
	-- Numbered pills; a new one enters with the tape-print stagger (Ui.show), a busted one greys
	-- with a cross icon over its struck-out number.
	local shownChips = 0
	local function chip(text: string, color: Color3, order: number, busted: boolean, fresh: boolean)
		local size = HudLayout.STRIP_CHIP
		local c = Ui.label(strip, {
			Size = UDim2.fromOffset(U.CHIP_W, size),
			TextSize = 16,
			TextColor3 = Palette.ink,
			RichText = true,
			Text = text,
			LayoutOrder = order,
			Visible = not fresh,
		})
		c.BackgroundColor3 = color
		c.BackgroundTransparency = 0
		Ui.pill(c)
		Ui.stroke(c, Palette.ink, Theme.STROKE)
		if busted then
			Icons.attach(c, "cross", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(size - 4, size - 4),
				ImageColor3 = Palette.alarm,
				ImageTransparency = 0.15,
			})
		end
		if fresh then
			local wait = math.min((order - 1 - shownChips) * U.CHIP_STAGGER, U.STAGGER_CAP)
			task.delay(math.max(0, wait), function()
				if c.Parent then
					Ui.show(c)
				end
			end)
		end
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
				i,
				red,
				i > shownChips
			)
		end
		if n > shown then
			chip(Strings.moreClones(n - shown), Palette.steelHi, max, false, false)
		end
		shownChips = shown
		strip.Visible = runBoxShown
	end

	---------------------------------------------------------------------------
	-- Loot meter count-up (§7.3, premium D10: 0.35 s + 0.08 s per digit, cap 1.0 s, Quad Out, a rising
	-- tick, a landing ding and a pop; Shared/Heist/CrewBoard). A bank's "+$100!" flight (Hud/BankFly)
	-- holds the next count until it lands.
	---------------------------------------------------------------------------
	local shown, countFrom, countTo, countT0, countDur, countTicks, counting = 0, 0, 0, 0, 0, 0, false
	local holdUntil = 0

	function bar.resetCount()
		shown, countFrom, countTo, counting = 0, 0, 0, false
		holdUntil = 0
	end

	-- The meter waits `seconds` before it counts a new bank (the flight lands first).
	function bar.holdCount(seconds: number)
		holdUntil = math.max(holdUntil, os.clock() + seconds)
	end

	local function updateCount(now: number)
		local banked = (state.folder and state.folder:GetAttribute("Banked")) or 0
		if type(banked) ~= "number" then
			banked = 0
		end
		if banked ~= countTo and (banked < countTo or now >= holdUntil) then
			if banked > countTo then
				countFrom = shown
				countDur = CrewBoard.countSeconds(shown, banked)
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
			local elapsed = now - countT0
			local u = math.clamp(elapsed / countDur, 0, 1)
			shown = CrewBoard.countValue(countFrom, countTo, elapsed, countDur)
			local want = math.floor(elapsed / U.COUNT_UP.TICK)
			if want > countTicks and u < 1 then
				countTicks = want
				Sound.play("CountTick", { step = math.min(countTicks - 1, #AU.COUNT_UP_STEPS - 1) })
			end
			if u >= 1 then
				counting = false
				Sound.play("CountDone")
				Ui.pop(lootBox, U.COUNT_UP.END_POP)
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
