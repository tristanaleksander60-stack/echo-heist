--!strict
-- Hud/Deck: between runs (§3.2 rule 6). The Clone Deck (from L2; read-only on L1 and
-- party levels) with REDO / REDO + LATER / DELETE / UNDO / DELETE BUSTED and the RedoAlarm
-- hint in its title, or a plain RUN button; both count down to the auto-start
-- ("▶ RUN 3 · 0:08", co-op "2/3 READY").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Sound = require(script.Parent.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local TAP = Ui.TAP
local RED = Common.RED

local Deck = {}

function Deck.build(ctx: any): any
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local root = ctx.root
	local deckUi = {}

	local deckPanel = Ui.frame(root, { Name = "Deck", Visible = false })
	Common.place(deckPanel, HudLayout.DECK)
	Ui.corner(deckPanel, 16)
	deckUi.panel = deckPanel
	local deckTitle = Ui.label(deckPanel, {
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = Strings.DECK_TITLE,
	})
	local cards = Instance.new("ScrollingFrame")
	cards.Name = "Cards"
	cards.Position = UDim2.fromOffset(12, 34)
	cards.Size = UDim2.new(1, -24, 0, 86)
	cards.BackgroundTransparency = 1
	cards.BorderSizePixel = 0
	cards.ScrollingDirection = Enum.ScrollingDirection.X
	cards.AutomaticCanvasSize = Enum.AutomaticSize.X
	cards.CanvasSize = UDim2.fromScale(0, 0)
	cards.ScrollBarThickness = 4
	cards.Parent = deckPanel
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.Padding = UDim.new(0, 8)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = cards
	local actionRow = Ui.frame(deckPanel, {
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(420, TAP),
		BackgroundTransparency = 1,
	})
	local actLayout = Instance.new("UIListLayout")
	actLayout.FillDirection = Enum.FillDirection.Horizontal
	actLayout.Padding = UDim.new(0, 8)
	actLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actLayout.Parent = actionRow
	local selected = 0
	local redoBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(118, TAP), TextSize = 16, Text = Strings.REDO, LayoutOrder = 1 },
		function()
			if selected > 0 then
				actions.deck("Redo", selected)
			end
		end
	)
	local fromBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(150, TAP), TextSize = 16, Text = Strings.REDO_FROM, LayoutOrder = 2 },
		function()
			if selected > 0 then
				actions.deck("RedoFrom", selected)
			end
		end
	)
	local delBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(118, TAP), TextSize = 16, Text = Strings.DELETE, LayoutOrder = 3 },
		function()
			if selected > 0 then
				actions.deck("Delete", selected)
				selected = 0
			end
		end,
		"UIBack"
	)
	local undoBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(118, TAP), TextSize = 16, Text = Strings.UNDO, LayoutOrder = 4 },
		function()
			actions.deck("Undo")
		end,
		"UIBack"
	)
	local bustedBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(150, TAP), TextSize = 16, Text = Strings.DELETE_BUSTED, LayoutOrder = 5 },
		function()
			actions.deck("DeleteBusted")
		end,
		"UIBack"
	)
	local readyBtn = Ui.button(deckPanel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(164, TAP),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 22,
		Text = Strings.startRun(Strings.run(2)),
	}, function()
		hud.ready()
	end, "UIConfirm")

	-- RedoAlarm hint (§3.6): the deck's title says "◎ Clone ●3 sets off the alarm. Redo
	-- ●3?", that card is picked and REDO turns Alarm Red (no extra banner: small phones).
	local hintSlot = 0
	local hintShownFor = 0

	local readyWait = Ui.button(root, {
		Name = "ReadySolo",
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 22,
		Text = Strings.startRun(Strings.run(2)),
		Visible = false,
	}, function()
		hud.ready()
	end, "UIConfirm")
	Common.place(readyWait, HudLayout.READY_WAIT)
	deckUi.readyWait = readyWait

	local deckOpen = true
	local function selectCard(n: number)
		selected = n
		local seat = state.mySeat or 1
		local badge = if n > 0 then Palette.badge(seat, n) else ""
		redoBtn.Text = Strings.redo(badge)
		fromBtn.Text = Strings.redoFrom(badge)
		delBtn.Text = Strings.delete(badge)
		redoBtn.Visible = n > 0
		fromBtn.Visible = n > 0
		delBtn.Visible = n > 0
		-- The RedoAlarm hint's card: REDO in Alarm Red.
		redoBtn.BackgroundColor3 = if n > 0 and n == hintSlot then Palette.alarm else Palette.steel
		redoBtn.TextColor3 = if n > 0 and n == hintSlot then Palette.white else Palette.ink
		local deck = state.deck
		undoBtn.Visible = n == 0 and deck ~= nil and deck.canUndo == true
		local anyRed = false
		for _, s in if deck then deck.slots else {} do
			anyRed = anyRed or RED[s.status] == true
		end
		bustedBtn.Visible = n == 0 and anyRed
		for _, c in cards:GetChildren() do
			if c:IsA("TextButton") then
				local stroke = c:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if c:GetAttribute("Slot") == n then Palette.white else Palette.ink
					stroke.Thickness = if c:GetAttribute("Slot") == n then 3 else 2
				end
			end
		end
	end

	local function renderHint()
		local deck = state.deck
		local hint = deck and deck.hint
		local slot = if hint and hint.kind == "RedoAlarm" then tonumber(hint.slot) or 0 else 0
		hintSlot = if deck and slot > 0 and slot <= #deck.slots then slot else 0
		if hintSlot > 0 then
			local badge = Palette.badge(state.mySeat or 1, hintSlot)
			deckTitle.Text = Strings.redoAlarmHint(badge)
			deckTitle.TextColor3 = Palette.alarm
			if hintShownFor ~= hintSlot then
				hintShownFor = hintSlot
				selectCard(hintSlot) -- the card is picked: one tap on REDO
			end
		else
			hintShownFor = 0
			deckTitle.TextColor3 = Palette.white
		end
	end

	local function renderDeck()
		for _, c in cards:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		ctx.top.renderStrip()
		local deck = state.deck
		if not deck then
			return
		end
		local seat = state.mySeat or 1
		local hue = Palette.hueFor(seat)
		deckTitle.Text = Strings.deckTitle(#deck.slots, tonumber(deck.cap) or #deck.slots)
		local hint = deck.hint
		local alarmSlot = if hint and hint.kind == "RedoAlarm" then tonumber(hint.slot) or 0 else 0
		for i, s in deck.slots do
			local red = RED[s.status] == true
			local status = if deck.redo == i then Strings.STATUS_REDO else (Strings.STATUS[s.status] or s.status)
			if i == alarmSlot then
				status = Strings.STATUS_ALARM
			end
			local card = Ui.button(cards, {
				Size = UDim2.fromOffset(TAP, 80),
				BackgroundColor3 = Palette.inkHi,
				TextColor3 = if red then Palette.tapeGrey else hue,
				TextSize = 20,
				TextWrapped = true,
				Text = Strings.card(Palette.badge(seat, i), status),
				LayoutOrder = i,
			}, function()
				selectCard(if selected == i then 0 else i)
			end, "UIToggle")
			card:SetAttribute("Slot", i)
		end
		if selected > #deck.slots then
			selected = 0
		end
		renderHint()
		selectCard(selected)
	end
	deckUi.render = renderDeck

	function hud.onDeck()
		renderDeck()
	end

	function hud.ready()
		actions.ready()
		ctx.waiting = true
		readyBtn.Text = Strings.WAITING
		readyWait.Text = Strings.WAITING
	end

	-- The RUN button's label for the next run ("▶ RUN 3").
	function deckUi.setNextRun(nextRun: number)
		local text = Strings.startRun(Common.runName(state, nextRun))
		readyBtn.Text = text
		readyWait.Text = text
	end

	-- Between runs: show the deck (from L2) or a plain RUN button with its countdown.
	-- Party levels keep every clone ("8 OF ME"): no deck actions, a short auto-start.
	function hud.showBetween()
		local top = ctx.top
		local controls = ctx.controls
		local msg = ctx.msg
		ctx.runHud.Visible = true
		msg.pauseChip.Visible = true
		controls.endBtn.Visible = false
		controls.interactBtn.Visible = false
		top.alarmPill.Visible = false
		msg.setSpectate("")
		msg.setHidden(false)
		local deck = state.deck
		local locked = deck == nil or deck.locked == true
		deckPanel.Visible = not locked and deckOpen
		readyWait.Visible = not Common.isTutorial(state) and (locked or not deckOpen)
		hud.placeRail(deckPanel.Visible)
		top.objective.Position = Common.position(HudLayout.OBJECTIVE)
		top.objective.Text = if Common.isParty(state) and deck then Strings.partyKeepsAll(#deck.slots) else ""
		if deckPanel.Visible then
			Common.selectFor(readyBtn)
		elseif readyWait.Visible then
			Common.selectFor(readyWait)
		end
		renderDeck()
	end

	function hud.toggleDeck()
		if state.phase == "Between" and state.deck and not state.deck.locked then
			deckOpen = not deckOpen
			deckPanel.Visible = deckOpen
			readyWait.Visible = not deckOpen
			hud.placeRail(deckOpen)
			renderHint()
			Sound.play("UIToggle")
		end
	end

	-- Between runs: "▶ RUN 3 · 0:08" counts down to the auto-start; co-op adds "2/3 READY".
	function deckUi.updateBetween()
		local folder = state.folder
		if state.phase ~= "Between" or not folder then
			return
		end
		local at = folder:GetAttribute("AutoStartAt")
		local left = if type(at) == "number" then at - workspace:GetServerTimeNow() else nil
		local nextRun = (state.run and state.run.run or 0) + 1
		local crew = tonumber(folder:GetAttribute("Crew")) or 1
		local ready = tonumber(folder:GetAttribute("Ready")) or 0
		local text = if ctx.waiting then Strings.WAITING else Strings.startRun(Common.runName(state, nextRun))
		if crew > 1 then
			text ..= Strings.readyCount(ready, crew)
		end
		if left and left > 0 and not Common.isTutorial(state) then
			text ..= Strings.autoStartIn(Ui.clock(left))
		end
		if readyBtn.Text ~= text then
			readyBtn.Text = text
			readyWait.Text = text
		end
	end

	return deckUi
end

return Deck
