--!strict
-- Hud/Deck: between runs (§3.2 rule 6). The Clone Deck as crew cards (PLAN_STEAM_PLUS §3.2, §4.3 U4;
-- read-only on L1 and party levels), or a plain RUN button; both count down to the auto-start
-- ("GO: RUN 3 · 0:08", co-op "2/3 READY"). After a failed run the deck title leads with why it ended
-- (§6.1 item 8).
-- Each clone is a polaroid: a portrait of YOUR Rookie on a crew-colour backdrop (Common.portrait), a
-- stamped number pill (the seat shape beside it with colour-blind shapes on), and what it did last as
-- an icon badge and a word (pressed plate A, carried cash, BUSTED, zapped, stuck: Shared/Heist/CrewBoard).
-- REDO / REDO FROM / DELETE / UNDO / DELETE BUSTED are icon + word. A full deck (WALKTHROUGH P0-3) says
-- so in the title, pulses the first card that holds no plate, names the clone a run replaced (toast at
-- RunEnd) and, after START_OVER_RUNS runs that got nowhere, offers START OVER: one tap is the existing
-- "RedoFrom 1" deck action (every clone after 1 goes, clone 1 is re-recorded), then RUN once the server's
-- new deck confirms it (never before: a Ready could start the run first). No new remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local CrewBoard = require(HeistShared:WaitForChild("CrewBoard"))
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Heist = script.Parent.Parent
local Icons = require(Heist:WaitForChild("Icons"))
local Motion = require(Heist:WaitForChild("Motion"))
local Settings = require(Heist:WaitForChild("Settings"))
local Theme = require(Heist:WaitForChild("Theme"))
local Sound = require(Heist:WaitForChild("Sound"))
local Ui = require(Heist:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local H = Config.Heist
local U = Config.Ui
local C = U.CARD
local TAP = Ui.TAP
local RED = Common.RED
local localPlayer = Players.LocalPlayer

local Deck = {}

function Deck.build(ctx: any): any
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local root = ctx.root
	local deckUi = {}

	local deckPanel = Ui.panel(root, { Name = "Deck", Visible = false })
	Common.place(deckPanel, HudLayout.DECK)
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
	cards.Position = UDim2.fromOffset(10, 32)
	cards.Size = UDim2.new(1, -20, 0, C.H + 8)
	cards.BackgroundTransparency = 1
	cards.BorderSizePixel = 0
	cards.ScrollingDirection = Enum.ScrollingDirection.X
	cards.AutomaticCanvasSize = Enum.AutomaticSize.X
	cards.CanvasSize = UDim2.fromScale(0, 0)
	cards.ScrollBarThickness = 3
	cards.Parent = deckPanel
	local cardPad = Instance.new("UIPadding")
	cardPad.PaddingLeft = UDim.new(0, 4)
	cardPad.PaddingTop = UDim.new(0, 4)
	cardPad.Parent = cards
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.Padding = UDim.new(0, C.GAP)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = cards
	local actionRow = Ui.frame(deckPanel, {
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(340, TAP),
		BackgroundTransparency = 1,
	})
	local actLayout = Instance.new("UIListLayout")
	actLayout.FillDirection = Enum.FillDirection.Horizontal
	actLayout.Padding = UDim.new(0, 8)
	actLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actLayout.Parent = actionRow
	local selected = 0
	local progress = CrewBoard.newProgress() -- START OVER: full-deck runs that got nowhere
	local pendingRun: { full: boolean, banked: number }? = nil
	local runAfterStartOver = false -- START OVER: RUN once the server's new deck (redo = 1) arrives
	local redoBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(96, TAP), TextSize = 16, Text = Strings.REDO, LayoutOrder = 1 },
		function()
			if selected > 0 then
				actions.deck("Redo", selected)
			end
		end
	)
	local fromBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(124, TAP), TextSize = 16, Text = Strings.REDO_FROM, LayoutOrder = 2 },
		function()
			if selected > 0 then
				actions.deck("RedoFrom", selected)
			end
		end
	)
	local delBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(96, TAP), TextSize = 16, Text = Strings.DELETE, LayoutOrder = 3 },
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
		{ Size = UDim2.fromOffset(96, TAP), TextSize = 16, Text = Strings.UNDO, LayoutOrder = 4 },
		function()
			actions.deck("Undo")
		end,
		"UIBack"
	)
	local bustedBtn = Ui.button(
		actionRow,
		{ Size = UDim2.fromOffset(140, TAP), TextSize = 16, Text = Strings.DELETE_BUSTED, LayoutOrder = 5 },
		function()
			actions.deck("DeleteBusted")
		end,
		"UIBack"
	)
	-- START OVER (P0-3): the existing RedoFrom 1 (only clone 1 is left, and it is re-recorded: the next
	-- run replays nobody), then RUN.
	local startOverBtn = Ui.button(actionRow, {
		Size = UDim2.fromOffset(132, TAP),
		TextSize = 16,
		BackgroundColor3 = Palette.amber,
		Text = Strings.START_OVER,
		LayoutOrder = 6,
		Visible = false,
	}, function()
		local deck = state.deck
		if deck and #deck.slots > 0 and not deck.locked then
			actions.deck("RedoFrom", 1)
			progress = CrewBoard.newProgress()
			selected = 0
			runAfterStartOver = true
		end
	end, "UIConfirm")
	local readyBtn = Ui.button(deckPanel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(150, TAP),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextWrapped = true,
		Text = Strings.startRun(Strings.run(2)),
	}, function()
		hud.ready()
	end, "UIConfirm")
	Ui.fit(readyBtn, 22, H.UI_TEXT_MIN)
	-- Icon + word (U2): the words stay; the icons join once the sheet is known.
	Ui.iconWord(redoBtn, "replay", "top", U.ICON_SMALL)
	Ui.iconWord(fromBtn, "replay", "top", U.ICON_SMALL)
	Ui.iconWord(delBtn, "delete", "top", U.ICON_SMALL)
	Ui.iconWord(undoBtn, "undo", "top", U.ICON_SMALL)
	Ui.iconWord(bustedBtn, "delete", "top", U.ICON_SMALL)
	Ui.iconWord(startOverBtn, "replay", "top", U.ICON_SMALL)
	Ui.iconWord(readyBtn, "play", "left", U.ICON_SMALL)
	Common.keyCap(readyBtn, "ready")

	-- RedoAlarm hint (§3.6): the deck's title says "Clone 3 sets off the alarm. Redo it?",
	-- that card is picked and REDO turns Alarm Red (no extra banner: small phones).
	local hintSlot = 0
	local hintShownFor = 0

	local readyWait = Ui.button(root, {
		Name = "ReadySolo",
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextWrapped = true,
		Text = Strings.startRun(Strings.run(2)),
		Visible = false,
	}, function()
		hud.ready()
	end, "UIConfirm")
	Common.place(readyWait, HudLayout.READY_WAIT)
	Ui.fit(readyWait, 22, H.UI_TEXT_MIN)
	Ui.iconWord(readyWait, "play", "left", U.ICON_SMALL)
	Common.keyCap(readyWait, "ready")
	deckUi.readyWait = readyWait

	local function deckFull(): boolean
		return CrewBoard.isFull(state.deck)
	end

	---------------------------------------------------------------------------
	-- Crew cards
	---------------------------------------------------------------------------
	local pulseSlot = 0
	local breaths: { Tween } = {}

	local function stopBreaths()
		for _, tw in breaths do
			tw:Cancel()
		end
		table.clear(breaths)
	end

	-- The card's outline: picked (gold), the one to delete on a full deck (breathing red), else ink.
	local function styleOutline(card: GuiObject, n: number)
		local stroke = card:FindFirstChild("Outline")
		if not stroke or not stroke:IsA("UIStroke") then
			return
		end
		local slot = card:GetAttribute("Slot")
		if slot == n and n > 0 then
			stroke.Color = Palette.gold
			stroke.Thickness = 3
			stroke.Transparency = 0
		elseif slot == pulseSlot and pulseSlot > 0 then
			stroke.Color = Palette.alarm
			stroke.Thickness = 3
			stroke.Transparency = U.BREATH_TRANSPARENCY[1]
			if not Ui.reducedMotion() then
				table.insert(breaths, Motion.breathe(stroke, { Transparency = U.BREATH_TRANSPARENCY[2] }))
			end
		else
			stroke.Color = Palette.ink
			stroke.Thickness = Theme.STROKE
			stroke.Transparency = 0
		end
	end

	local function selectCard(n: number)
		selected = n
		redoBtn.Text = if n > 0 then Strings.redo(n) else Strings.REDO
		fromBtn.Text = if n > 0 then Strings.redoFrom(n) else Strings.REDO_FROM
		delBtn.Text = if n > 0 then Strings.delete(n) else Strings.DELETE
		redoBtn.Visible = n > 0
		fromBtn.Visible = n > 0
		delBtn.Visible = n > 0
		-- The RedoAlarm hint's card: REDO in Alarm Red. On a full deck DELETE is the move.
		redoBtn.BackgroundColor3 = if n > 0 and n == hintSlot then Palette.alarm else Palette.steel
		redoBtn.TextColor3 = if n > 0 and n == hintSlot then Palette.white else Palette.ink
		delBtn.BackgroundColor3 = if n > 0 and deckFull() and n ~= hintSlot then Palette.amber else Palette.steel
		local deck = state.deck
		undoBtn.Visible = n == 0 and deck ~= nil and deck.canUndo == true
		local offer = n == 0 and CrewBoard.offerStartOver(progress, deck)
		startOverBtn.Visible = offer
		local anyRed = false
		for _, s in if deck then deck.slots else {} do
			anyRed = anyRed or RED[s.status] == true
		end
		bustedBtn.Visible = n == 0 and anyRed and not offer
		stopBreaths()
		for _, c in cards:GetChildren() do
			if c:IsA("TextButton") then
				styleOutline(c, n)
			end
		end
	end

	-- A small stamp across the photo ("BUSTED", "REDO", "ALARM").
	local function photoStamp(photo: Frame, text: string, color: Color3)
		local stamp = Ui.label(photo, {
			Name = "Stamp",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(C.W - 2 * C.PAD - 6, 24),
			FontFace = Ui.FONT_DISPLAY,
			TextSize = U.TYPE_SCALE[2],
			TextColor3 = color,
			Rotation = if Ui.reducedMotion() then 0 else C.STAMP_TILT,
			Text = text,
			ZIndex = 4,
			Active = false,
		})
		Ui.stroke(stamp, color, Theme.STROKE)
	end

	local function buildCard(i: number, s: any, hue: Color3, alarmSlot: number)
		local deck = state.deck
		local action = CrewBoard.lastAction(s.status, state.recs[s.key], state.level)
		local red = RED[s.status] == true or action.red
		local tilt = if Ui.reducedMotion() then 0 else (if i % 2 == 0 then C.TILT else -C.TILT)
		local card = Ui.button(cards, {
			Name = "Card" .. i,
			Size = UDim2.fromOffset(C.W, C.H),
			BackgroundColor3 = Palette.exit, -- photo paper
			Text = "",
			Rotation = tilt,
			LayoutOrder = i,
		}, function()
			selectCard(if selected == i then 0 else i)
		end, "UIToggle")
		card:SetAttribute("Slot", i)

		-- The photo: your Rookie on a crew-colour backdrop, framed in the crew colour.
		local backdrop = if red then Palette.dim(Palette.tapeGrey, C.BACKDROP_DIM) else Palette.dim(hue, C.BACKDROP_DIM)
		local photo = Ui.frame(card, {
			Name = "Photo",
			Position = UDim2.fromOffset(C.PAD, C.PAD),
			Size = UDim2.fromOffset(C.W - 2 * C.PAD, C.PHOTO_H),
			BackgroundColor3 = backdrop,
			BackgroundTransparency = 0,
			ClipsDescendants = true,
			Active = false,
		})
		Ui.stroke(photo, if red then Palette.tapeGrey else hue, Theme.STROKE)
		local head = Common.portrait(photo, localPlayer.UserId, if red then Palette.tapeGrey else hue)
		head.AnchorPoint = Vector2.new(0.5, 1)
		head.Position = UDim2.fromScale(0.5, 1)
		head.Size = UDim2.fromOffset(C.PHOTO_H, C.PHOTO_H)
		head.ImageColor3 = if red then Palette.tapeGrey else Color3.new(1, 1, 1)

		-- The stamped number (and the seat shape with colour-blind shapes on).
		local glyphs = Settings.get("colourBlindGlyphs") == true
		local pillW = C.PILL[1] + (if glyphs then C.PILL_GLYPH else 0)
		local pill = Ui.label(card, {
			Name = "Number",
			Position = UDim2.fromOffset(1, 1),
			Size = UDim2.fromOffset(pillW, C.PILL[2]),
			TextSize = U.TYPE_SCALE[1],
			TextColor3 = Palette.ink,
			RichText = true,
			Rotation = if Ui.reducedMotion() then 0 else C.PILL_TILT,
			Text = if red then Strings.cloneNumberBusted(i) else Strings.cloneNumber(i),
			ZIndex = 5,
			Active = false,
		})
		pill.BackgroundColor3 = if red then Palette.tapeGrey else hue
		pill.BackgroundTransparency = 0
		Ui.pill(pill)
		Ui.stroke(pill, Palette.ink, Theme.STROKE)
		if glyphs then
			Ui.iconWord(pill, Icons.seat(state.mySeat or 1), "left", C.PILL_GLYPH - 4)
		end

		-- What it did last: an icon badge on the photo's corner and a word under the photo.
		local badge = Ui.frame(card, {
			Name = "Action",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromOffset(C.W - C.PAD + 3, C.PAD + C.PHOTO_H + 3),
			Size = UDim2.fromOffset(C.BADGE, C.BADGE),
			BackgroundColor3 = if red then Palette.alarm else Palette.exit,
			BackgroundTransparency = 0,
			ZIndex = 5,
			Active = false,
		})
		Ui.pill(badge)
		Ui.stroke(badge, Palette.ink, Theme.STROKE)
		Icons.attach(badge, action.icon, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(C.BADGE - 6, C.BADGE - 6),
			ImageColor3 = if red then Palette.white else Palette.ink,
			ZIndex = 6,
		})
		Ui.label(card, {
			Name = "Caption",
			Position = UDim2.fromOffset(C.PAD, C.PAD + C.PHOTO_H + 2),
			Size = UDim2.fromOffset(C.W - 2 * C.PAD, C.CAPTION_H),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = U.TYPE_SCALE[1],
			TextColor3 = if red then Palette.alarm else Palette.ink,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = action.word,
			ZIndex = 4,
			Active = false,
		})

		-- Stamps across the photo: busted / zapped / stuck, the clone being redone, the one that set
		-- the alarm off.
		if deck and deck.redo == i then
			photoStamp(photo, Strings.STATUS_REDO, Palette.gold)
		elseif i == alarmSlot then
			photoStamp(photo, Strings.STATUS_ALARM, Palette.alarm)
		elseif red then
			photoStamp(photo, Strings.STATUS[s.status] or action.word, Palette.alarm)
		end

		-- Tape at the top: dressing only (MASTERPLAN §2.2).
		local tape = Ui.frame(card, {
			Name = "Tape",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 6, 0, 1),
			Size = UDim2.fromOffset(C.TAPE[1], C.TAPE[2]),
			BackgroundColor3 = Palette.marbleHi,
			BackgroundTransparency = C.TAPE[3],
			Rotation = -4,
			ZIndex = 6,
			Active = false,
		})
		tape.BorderSizePixel = 0
	end

	local function renderHint()
		local deck = state.deck
		local hint = deck and deck.hint
		local slot = if hint and hint.kind == "RedoAlarm" then tonumber(hint.slot) or 0 else 0
		hintSlot = if deck and slot > 0 and slot <= #deck.slots then slot else 0
		if hintSlot > 0 then
			deckTitle.Text = Strings.redoAlarmHint(hintSlot)
			deckTitle.TextColor3 = Palette.alarm
			if hintShownFor ~= hintSlot then
				hintShownFor = hintSlot
				selectCard(hintSlot) -- the card is picked: one tap on REDO
			end
		else
			hintShownFor = 0
			deckTitle.TextColor3 = if deckFull() then Palette.amber else Palette.white
		end
	end

	local function renderDeck()
		stopBreaths()
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
		local hue = Palette.hueFor(state.mySeat or 1)
		deckTitle.Text = if deckFull()
			then Strings.DECK_FULL
			else Strings.deckTitle(#deck.slots, tonumber(deck.cap) or #deck.slots, ctx.msg.reason)
		local hint = deck.hint
		local alarmSlot = if hint and hint.kind == "RedoAlarm" then tonumber(hint.slot) or 0 else 0
		pulseSlot = CrewBoard.pulseSlot(deck, state.recs, state.level) or 0
		for i, s in deck.slots do
			buildCard(i, s, hue, alarmSlot)
		end
		if selected > #deck.slots then
			selected = 0
		end
		renderHint()
		selectCard(selected)
	end
	deckUi.render = renderDeck

	function hud.onDeck()
		-- The first deck after a run: did that run get anywhere (START OVER)?
		local run = pendingRun
		if run then
			pendingRun = nil
			local held = CrewBoard.platesHeld(state.deck, state.recs, state.level)
			CrewBoard.noteRun(progress, run.full, run.banked, held)
		end
		renderDeck()
		local deck = state.deck
		if runAfterStartOver and deck and tonumber(deck.redo) == 1 and #deck.slots <= 1 then
			runAfterStartOver = false
			if state.phase == "Between" and not ctx.waiting then
				hud.ready()
			end
		end
	end

	-- A run ended (before its deck arrives): state.deck is still the deck that run started with.
	-- A full deck with no REDO armed: the run replaced the newest clone, and the toast says which.
	function deckUi.noteRunEnd(p: any)
		local runIndex = if type(p) == "table" then tonumber(p.run) or 0 else 0
		if runIndex <= 1 then
			progress = CrewBoard.newProgress()
		end
		runAfterStartOver = false
		local before = state.deck
		local summary = if type(p) == "table" then p.summary else nil
		local banked = if type(summary) == "table" then tonumber(summary.banked) or 0 else 0
		pendingRun = { full = CrewBoard.isFull(before), banked = banked }
		local replaced = CrewBoard.replacedSlot(before)
		if replaced then
			hud.toast(Strings.deckFullReplaced(replaced))
		end
	end

	function hud.ready()
		actions.ready()
		ctx.waiting = true
		readyBtn.Text = Strings.WAITING
		readyWait.Text = Strings.WAITING
	end

	-- The RUN button's label for the next run ("GO: RUN 3").
	function deckUi.setNextRun(nextRun: number)
		local text = Strings.startRun(Common.runName(state, nextRun))
		readyBtn.Text = text
		readyWait.Text = text
	end

	-- The reason the run ended: on the rail until the deck opens, then in its title. A full deck's
	-- title says DECK FULL, so the reason stays on the rail above it.
	local function placeReason(deckShown: boolean)
		if deckShown and not deckFull() then
			ctx.msg.reasonToDeck()
		else
			ctx.msg.keepReason()
		end
	end

	local deckOpen = true
	-- Between runs: show the deck (from L2) or a plain RUN button with its countdown.
	-- Party levels keep every clone ("8 OF ME"): no deck actions, a short auto-start.
	function hud.showBetween()
		local top = ctx.top
		local controls = ctx.controls
		local msg = ctx.msg
		ctx.runHud.Visible = true
		ctx.setInHeist(true)
		msg.pauseChip.Visible = true
		controls.endBtn.Visible = false
		controls.interactBtn.Visible = false
		top.alarmPill.Visible = false
		msg.setHidden(false)
		local deck = state.deck
		local locked = deck == nil or deck.locked == true
		local deckShown = not locked and deckOpen
		local waitShown = not Common.isTutorial(state) and (locked or not deckOpen)
		Ui.setShown(deckPanel, deckShown)
		Ui.setShown(readyWait, waitShown)
		hud.placeRail(deckShown)
		top.setRunBoxShown(not deckShown)
		placeReason(deckShown)
		top.objective.Visible = true
		top.objective.Text = if Common.isParty(state) and deck then Strings.partyKeepsAll(#deck.slots) else ""
		if deckShown then
			Common.selectFor(readyBtn)
		elseif waitShown then
			Common.selectFor(readyWait)
		end
		renderDeck()
	end

	function hud.toggleDeck()
		if state.phase == "Between" and state.deck and not state.deck.locked then
			deckOpen = not deckOpen
			Ui.setShown(deckPanel, deckOpen)
			Ui.setShown(readyWait, not deckOpen)
			hud.placeRail(deckOpen)
			ctx.top.setRunBoxShown(not deckOpen)
			placeReason(deckOpen)
			renderDeck()
			Sound.play("UIToggle")
		end
	end

	-- Settings that change how cards draw (colour-blind shapes, reduced motion).
	Settings.onChanged(function(key: string)
		if (key == "colourBlindGlyphs" or key == "reducedMotion") and Ui.isShown(deckPanel) then
			renderDeck()
		end
	end)

	-- Between runs: "GO: RUN 3 · 0:08" counts down to the auto-start; co-op adds "2/3 READY".
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
