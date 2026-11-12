--!strict
-- Heist/Hud: HUD v1 for the sim path (MASTERPLAN §7.4, §3.4 controls, §7.5 L1 FTUE).
-- Four elements during a run, everything else contextual:
--   1. Top centre: "RUN 3" + tape counter "0:27" + a thin run bar with icons for your
--      clones' recorded events and red failure markers; last 10 s pulse, last 5 s red.
--   2. Top left: loot meter "$400 / $1,000".
--   3. Top right: clone strip (glyph, digit, hue per clone; red-flagged = ✕).
--   4. Right edge, ~45% height: 72 px END RUN ("◀◀ END RUN", co-op "· 2/3"), with a
--      ring that fills during the 1.5 s lock.
-- Contextual: Interact (≥ 64 px, near loot), ⏩ HOLD pill, one objective line (≤ 8
-- words), the Clone Deck between runs (from L2), the results card, the garage
-- (level select tapes, crew, join friend). Mobile first: during a run a phone shows
-- only the stick, jump, END RUN and the contextual prompt.
-- Keys: R / ButtonY END RUN (between runs: RUN n), E / ButtonX Interact,
-- Q / ButtonL1 Clone Deck, hold F / ButtonB fast-forward.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Codec = require(Shared:WaitForChild("Rec"):WaitForChild("Codec"))
local EventLog = require(Shared:WaitForChild("Sim"):WaitForChild("EventLog"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local Ui = require(script.Parent:WaitForChild("Ui"))

local H = Config.Heist
local EV = EventLog.EV
local KIND = Codec.EVENT
local localPlayer = Players.LocalPlayer

local Hud = {}

local STATUS_TEXT = {
	New = "NEW",
	OK = "OK",
	Busted = "BUSTED",
	Caught = "CAUGHT",
	Zapped = "ZAPPED",
	Stuck = "STUCK",
	Shrug = "?",
}
local RED = { Busted = true, Caught = true, Zapped = true, Stuck = true }

-- Level lines shown for the first seconds of a run (≤ 8 words each).
local LEVEL_LINES: { [number]: string } = {
	[2] = "Two plates. You need two clones.",
	[3] = "Plate B turns the lasers off.",
	[4] = "Hide from Gus. Cross while he looks away.",
}

export type Actions = {
	endRun: () -> (),
	interact: (kind: number, index: number) -> (),
	deck: (op: string, n: number?) -> (),
	ready: () -> (),
	fastForward: (on: boolean) -> (),
	selectLevel: (index: number) -> (),
	joinFriend: (userId: number) -> (),
	leave: () -> (),
}

function Hud.new(state: any, actions: Actions): any
	local hud = {}
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "HeistHUD"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Edge-to-edge layer (rewind overlay, vignette): no insets, nothing interactive.
	local fxGui = Instance.new("ScreenGui")
	fxGui.Name = "HeistFX"
	fxGui.ResetOnSpawn = false
	fxGui.DisplayOrder = 6
	fxGui.ScreenInsets = Enum.ScreenInsets.None
	fxGui.IgnoreGuiInset = true
	fxGui.Parent = playerGui
	hud.fxGui = fxGui

	local root = Ui.frame(gui, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local deviceScale = Instance.new("UIScale")
	deviceScale.Parent = root
	local function rescale()
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		deviceScale.Scale = math.clamp(math.min(vp.Y / 420, vp.X / 900), 0.9, 1.5)
	end
	rescale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	local vignette = Ui.frame(fxGui, {
		Name = "Vignette",
		BackgroundColor3 = Palette.alarm,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = false,
	})

	---------------------------------------------------------------------------
	-- Run HUD
	---------------------------------------------------------------------------
	local runHud =
		Ui.frame(root, { Name = "Run", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })

	local top = Ui.frame(runHud, {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(300, 62),
	})
	Ui.corner(top, 14)
	local runLabel = Ui.label(top, {
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.fromOffset(130, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 26,
		TextColor3 = Palette.CLONE_HUES[1],
		Text = "RUN 1",
	})
	local timerLabel = Ui.label(top, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 4),
		Size = UDim2.fromOffset(130, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 30,
		Text = "0:30",
	})
	local timerScale = Instance.new("UIScale")
	timerScale.Parent = timerLabel
	local bar = Ui.frame(top, {
		Name = "RunBar",
		Position = UDim2.new(0, 14, 1, -16),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundColor3 = Palette.plumHi,
		BackgroundTransparency = 0,
	})
	Ui.corner(bar, 3)
	local barFill = Ui.frame(bar, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0,
	})
	Ui.corner(barFill, 3)
	local markers = Ui.frame(bar, { Name = "Markers", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })

	local ffPill = Ui.button(runHud, {
		Name = "FastForward",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(150, 48),
		Text = "⏩ HOLD",
		BackgroundColor3 = Palette.exit,
		Visible = false,
	}, function() end)

	local objective = Ui.label(runHud, {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(460, 34),
		TextSize = 22,
		TextStrokeTransparency = 0.2,
		Text = "",
	})

	local lootBox = Ui.frame(runHud, {
		Name = "Loot",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(190, 44),
	})
	Ui.corner(lootBox, 12)
	local lootLabel = Ui.label(lootBox, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		TextColor3 = Palette.gold,
		Text = "$0 / $100",
	})

	local strip = Ui.frame(runHud, {
		Name = "CloneStrip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(220, 44),
		BackgroundTransparency = 0.4,
	})
	Ui.corner(strip, 12)
	local stripLayout = Instance.new("UIListLayout")
	stripLayout.FillDirection = Enum.FillDirection.Horizontal
	stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stripLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	stripLayout.Padding = UDim.new(0, 4)
	stripLayout.Parent = strip
	local stripPad = Instance.new("UIPadding")
	stripPad.PaddingRight = UDim.new(0, 6)
	stripPad.Parent = strip

	local endBtn = Ui.button(runHud, {
		Name = "EndRun",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.45, 0),
		Size = UDim2.fromOffset(H.END_RUN_BUTTON + 24, H.END_RUN_BUTTON),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 18,
		TextWrapped = true,
		Text = "◀◀\nEND RUN",
	}, function()
		actions.endRun()
	end)
	local lockRing = Ui.frame(endBtn, {
		Name = "Lock",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.ink,
		BackgroundTransparency = 0.45,
		ZIndex = 3,
		Active = false,
	})
	Ui.corner(lockRing, 12)

	local interactBtn = Ui.button(runHud, {
		Name = "Interact",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.45, -(H.END_RUN_BUTTON + 20)),
		Size = UDim2.fromOffset(H.INTERACT_BUTTON + 40, H.INTERACT_BUTTON),
		BackgroundColor3 = Palette.gold,
		TextSize = 20,
		TextWrapped = true,
		Text = "GRAB",
		Visible = false,
	}, function()
		hud.interact()
	end)

	local spectate = Ui.label(runHud, {
		Name = "Spectate",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(420, 30),
		TextSize = 20,
		Text = "",
	})

	local toastLabel = Ui.label(root, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.fromOffset(460, 34),
		TextSize = 20,
		TextStrokeTransparency = 0.2,
		Text = "",
		ZIndex = 20,
	})
	local toastToken = 0
	function hud.toast(text: string)
		toastToken += 1
		local token = toastToken
		toastLabel.Text = text
		task.delay(3, function()
			if toastToken == token then
				toastLabel.Text = ""
			end
		end)
	end

	---------------------------------------------------------------------------
	-- Clone Deck (between runs, §3.2 rule 6)
	---------------------------------------------------------------------------
	local deckPanel = Ui.frame(root, {
		Name = "Deck",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(560, 210),
		Visible = false,
	})
	Ui.corner(deckPanel, 16)
	Ui.label(deckPanel, {
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.fromOffset(200, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "CLONE DECK",
	})
	local cards = Ui.frame(deckPanel, {
		Name = "Cards",
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 80),
		BackgroundTransparency = 1,
	})
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.Padding = UDim.new(0, 8)
	cardLayout.Parent = cards
	local cardActions = Ui.frame(deckPanel, {
		Name = "CardActions",
		Position = UDim2.fromOffset(12, 120),
		Size = UDim2.new(1, -24, 0, 36),
		BackgroundTransparency = 1,
	})
	local actLayout = Instance.new("UIListLayout")
	actLayout.FillDirection = Enum.FillDirection.Horizontal
	actLayout.Padding = UDim.new(0, 8)
	actLayout.Parent = cardActions
	local selected = 0
	local redoBtn = Ui.button(cardActions, { Size = UDim2.fromOffset(110, 44), Text = "REDO #?" }, function()
		if selected > 0 then
			actions.deck("Redo", selected)
		end
	end)
	local fromBtn = Ui.button(cardActions, { Size = UDim2.fromOffset(150, 44), Text = "REDO FROM #?" }, function()
		if selected > 0 then
			actions.deck("RedoFrom", selected)
		end
	end)
	local delBtn = Ui.button(cardActions, { Size = UDim2.fromOffset(110, 44), Text = "DELETE #?" }, function()
		if selected > 0 then
			actions.deck("Delete", selected)
			selected = 0
		end
	end)
	local undoBtn = Ui.button(deckPanel, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -10),
		Size = UDim2.fromOffset(150, 44),
		Text = "UNDO LAST RUN",
	}, function()
		actions.deck("Undo")
	end)
	local bustedBtn = Ui.button(deckPanel, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 170, 1, -10),
		Size = UDim2.fromOffset(150, 44),
		Text = "DELETE BUSTED",
	}, function()
		actions.deck("DeleteBusted")
	end)
	local readyBtn = Ui.button(deckPanel, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(190, 56),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 24,
		Text = "▶ RUN 2",
	}, function()
		hud.ready()
	end)

	local readyWait = Ui.button(root, {
		Name = "ReadySolo",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.45, 0),
		Size = UDim2.fromOffset(150, 64),
		BackgroundColor3 = Palette.CLONE_HUES[1],
		TextSize = 22,
		Text = "▶ RUN 2",
		Visible = false,
	}, function()
		hud.ready()
	end)

	local deckOpen = true
	local function selectCard(n: number)
		selected = n
		redoBtn.Text = "REDO #" .. n
		fromBtn.Text = "REDO FROM #" .. n
		delBtn.Text = "DELETE #" .. n
		cardActions.Visible = n > 0
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

	local function renderDeck()
		for _, c in cards:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
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
			local card = Ui.button(cards, {
				Size = UDim2.fromOffset(72, 76),
				BackgroundColor3 = Palette.inkHi,
				TextColor3 = if red then Palette.tapeGrey else hue,
				TextSize = 24,
				Text = Palette.badge(seat, i) .. "\n" .. (if deck.redo == i
					then "REDO"
					else (STATUS_TEXT[s.status] or s.status)),
			}, function()
				selectCard(if selected == i then 0 else i)
			end)
			card:SetAttribute("Slot", i)
			card.LayoutOrder = i
			local chip = Ui.label(strip, {
				Size = UDim2.fromOffset(34, 34),
				TextSize = 18,
				TextColor3 = if red then Palette.tapeGrey else hue,
				Text = if red then Palette.glyphFor(seat) .. "✕" else Palette.badge(seat, i),
				LayoutOrder = i,
			})
			chip.BackgroundTransparency = 1
		end
		undoBtn.Visible = deck.canUndo == true
		local anyRed = false
		for _, s in deck.slots do
			anyRed = anyRed or RED[s.status] == true
		end
		bustedBtn.Visible = anyRed
		if selected > #deck.slots then
			selected = 0
		end
		selectCard(selected)
	end

	function hud.onDeck()
		renderDeck()
	end

	function hud.ready()
		actions.ready()
		readyBtn.Text = "WAITING..."
		readyWait.Text = "WAITING..."
	end

	---------------------------------------------------------------------------
	-- Results card (§7.3 "heist complete", §6.6)
	---------------------------------------------------------------------------
	local results = Ui.frame(root, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(440, 300),
		Visible = false,
		ZIndex = 10,
	})
	Ui.corner(results, 18)
	local resTitle = Ui.label(results, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 34,
		Text = "HEIST COMPLETE",
		ZIndex = 11,
	})
	local resHaul = Ui.label(results, {
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 28,
		TextColor3 = Palette.gold,
		Text = "$0",
		ZIndex = 11,
	})
	local stampRow = Ui.frame(results, {
		Position = UDim2.fromOffset(20, 98),
		Size = UDim2.new(1, -40, 0, 50),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	local stampLayout = Instance.new("UIListLayout")
	stampLayout.FillDirection = Enum.FillDirection.Horizontal
	stampLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stampLayout.Padding = UDim.new(0, 10)
	stampLayout.Parent = stampRow
	local stamps: { TextLabel } = {}
	for i, name in { "HAUL", "CREW", "CLEAN" } do
		local s = Ui.label(stampRow, {
			Size = UDim2.fromOffset(120, 46),
			TextSize = 22,
			Text = "☆ " .. name,
			LayoutOrder = i,
			ZIndex = 12,
		})
		s.BackgroundColor3 = Palette.inkHi
		s.BackgroundTransparency = 0
		Ui.corner(s, 10)
		local sc = Instance.new("UIScale")
		sc.Name = "Pop"
		sc.Parent = s
		stamps[i] = s
	end
	local resLine = Ui.label(results, {
		Position = UDim2.fromOffset(0, 154),
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 20,
		Text = "",
		ZIndex = 11,
	})
	local resAward = Ui.label(results, {
		Position = UDim2.fromOffset(0, 184),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 18,
		TextColor3 = Palette.goldHi,
		Text = "",
		ZIndex = 11,
	})
	local resButtons = Ui.frame(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -30, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	local resLayout = Instance.new("UIListLayout")
	resLayout.FillDirection = Enum.FillDirection.Horizontal
	resLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	resLayout.Padding = UDim.new(0, 10)
	resLayout.Parent = resButtons
	local replayBtn = Ui.button(
		resButtons,
		{ Size = UDim2.fromOffset(120, 50), Text = "REPLAY", LayoutOrder = 1 },
		function()
			local over = state.over
			if over then
				actions.selectLevel(over.levelIndex)
			end
		end
	)
	local nextBtn = Ui.button(resButtons, {
		Size = UDim2.fromOffset(120, 50),
		Text = "NEXT ▶",
		LayoutOrder = 2,
		BackgroundColor3 = Palette.CLONE_HUES[1],
	}, function()
		local over = state.over
		if over then
			actions.selectLevel(over.levelIndex + 1)
		end
	end)
	local garageBtn = Ui.button(
		resButtons,
		{ Size = UDim2.fromOffset(120, 50), Text = "GARAGE", LayoutOrder = 3 },
		function()
			actions.leave()
		end
	)
	local resWait = Ui.label(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -70),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		Text = "",
		ZIndex = 11,
	})

	function hud.onOver(payload: any)
		local over = payload.result
		state.over = over
		results.Visible = true
		deckPanel.Visible = false
		readyWait.Visible = false
		runHud.Visible = false
		resTitle.Text = if over.complete then "HEIST COMPLETE" elseif over.reason == "Dawn" then "DAWN" else "HEIST OVER"
		resTitle.TextColor3 = if over.complete then Palette.ok else Palette.amber
		resHaul.Text = Ui.money(over.banked) .. " / " .. Ui.money(over.goal)
		local st = over.stars or {}
		local got = { st.haul == true, st.crew == true, st.clean == true }
		for i, s in stamps do
			s.Text = (if got[i] then "★ " else "☆ ") .. ({ "HAUL", "CREW", "CLEAN" })[i]
			s.TextColor3 = if got[i] then Palette.gold else Palette.tapeGrey
			s.Visible = false
			task.delay(0.25 * i, function()
				s.Visible = true
				Ui.pop(s)
			end)
		end
		local clones = over.clonesUsed or 0
		resLine.Text = string.format(
			"%d clone%s · %d run%s · %s",
			clones,
			if clones == 1 then "" else "s",
			over.runs,
			if over.runs == 1 then "" else "s",
			Ui.clock(over.totalTime or 0)
		)
		local award = payload.award
		if award and award.ok and award.data then
			local d = award.data
			local medals = d.newMedals or {}
			resAward.Text = if #medals > 0 then "NEW: " .. table.concat(medals, ", ") else ""
		elseif award and not award.ok then
			resAward.Text = "(not saved: " .. tostring(award.code) .. ")"
		else
			resAward.Text = ""
		end
		local leader = over.leader == localPlayer.UserId
		replayBtn.Visible = leader
		nextBtn.Visible = leader and over.hasNext == true and over.complete == true
		resWait.Text = if leader then "" else "Your crew leader picks what's next"
		garageBtn.Text = if leader then "GARAGE" else "LEAVE"
		GuiService.SelectedObject = if nextBtn.Visible then nextBtn else garageBtn
	end

	---------------------------------------------------------------------------
	-- Garage: level select (tapes), crew, join friend (§3.3, §7.4)
	---------------------------------------------------------------------------
	local garage = Ui.frame(root, {
		Name = "Garage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 320),
		Visible = false,
	})
	Ui.corner(garage, 18)
	Ui.label(garage, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.fromOffset(300, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 26,
		Text = "PICK A TAPE",
	})
	local tapes = Ui.frame(garage, {
		Position = UDim2.fromOffset(14, 48),
		Size = UDim2.fromOffset(380, 260),
		BackgroundTransparency = 1,
	})
	local tapeGrid = Instance.new("UIGridLayout")
	tapeGrid.CellSize = UDim2.fromOffset(184, 122)
	tapeGrid.CellPadding = UDim2.fromOffset(10, 10)
	tapeGrid.Parent = tapes
	local crewBox = Ui.frame(garage, {
		Position = UDim2.fromOffset(406, 48),
		Size = UDim2.fromOffset(200, 260),
		BackgroundColor3 = Palette.inkHi,
		BackgroundTransparency = 0,
	})
	Ui.corner(crewBox, 12)
	local crewList = Ui.frame(crewBox, {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1,
	})
	local crewLayout = Instance.new("UIListLayout")
	crewLayout.Padding = UDim.new(0, 6)
	crewLayout.SortOrder = Enum.SortOrder.LayoutOrder
	crewLayout.Parent = crewList

	local friendCache: { [number]: boolean } = {}
	local function isFriend(userId: number): boolean
		local known = friendCache[userId]
		if known ~= nil then
			return known
		end
		friendCache[userId] = false
		task.spawn(function()
			local ok, res = pcall(function()
				return localPlayer:IsFriendsWithAsync(userId)
			end)
			friendCache[userId] = ok and res == true
			if friendCache[userId] and state.where == "garage" then
				hud.showGarage()
			end
		end)
		return false
	end

	function hud.showGarage()
		local g = state.garage
		if not g then
			return
		end
		garage.Visible = true
		runHud.Visible = false
		deckPanel.Visible = false
		results.Visible = false
		readyWait.Visible = false
		for _, c in tapes:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local leader = g.leader == localPlayer.UserId
		local first: TextButton? = nil
		for _, lv in g.levels or {} do
			local medals = string.rep("★", #(lv.medals or {}))
			local text = string.format(
				"L%d  %s\npar %d · %ds\n%s",
				lv.index,
				lv.name,
				lv.par,
				lv.runSeconds,
				if lv.unlocked then (if medals ~= "" then medals else "☆☆☆") else "LOCKED"
			)
			local b = Ui.button(tapes, {
				BackgroundColor3 = if lv.unlocked then Palette.steelHi else Palette.plumHi,
				TextColor3 = Palette.ink,
				TextSize = 18,
				TextWrapped = true,
				Text = text,
				LayoutOrder = lv.index,
			}, function()
				if not leader then
					hud.toast("Your crew leader picks the tape.")
				elseif not lv.unlocked then
					hud.toast("Clear the tape before it first.")
				else
					actions.selectLevel(lv.index)
				end
			end)
			first = first or b
		end
		for _, c in crewList:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		Ui.label(crewList, { Size = UDim2.new(1, 0, 0, 24), Text = "CREW", LayoutOrder = 0 })
		local inCrew: { [number]: boolean } = {}
		for _, m in g.members or {} do
			inCrew[m.userId] = true
			Ui.label(crewList, {
				Size = UDim2.new(1, 0, 0, 24),
				TextSize = 16,
				TextColor3 = Palette.hueFor(m.seat),
				Text = Palette.glyphFor(m.seat) .. " " .. m.name .. (if m.userId == g.leader then " (leader)" else ""),
				LayoutOrder = m.seat,
			})
		end
		if g.pending then
			Ui.label(crewList, {
				Size = UDim2.new(1, 0, 0, 40),
				TextSize = 14,
				TextWrapped = true,
				Text = "You join at their next heist.",
				LayoutOrder = 10,
			})
		end
		if #(g.members or {}) > 1 then
			Ui.button(crewList, { Size = UDim2.new(1, 0, 0, 44), Text = "LEAVE CREW", LayoutOrder = 20 }, function()
				actions.leave()
			end)
		end
		local order = 30
		for _, p in Players:GetPlayers() do
			if p ~= localPlayer and not inCrew[p.UserId] and isFriend(p.UserId) then
				order += 1
				Ui.button(crewList, {
					Size = UDim2.new(1, 0, 0, 44),
					TextSize = 16,
					Text = "JOIN " .. p.DisplayName,
					LayoutOrder = order,
				}, function()
					actions.joinFriend(p.UserId)
				end)
			end
		end
		if first then
			GuiService.SelectedObject = first
		end
	end

	function hud.hideGarage()
		garage.Visible = false
	end

	---------------------------------------------------------------------------
	-- Run state
	---------------------------------------------------------------------------
	local endedCount = 0
	local runStartAt = 0
	local myEnded = false
	local hintBeam: Beam? = nil
	local hintStage = 0

	local function clearMarkers()
		for _, c in markers:GetChildren() do
			c:Destroy()
		end
	end

	local function marker(t: number, length: number, color: Color3, text: string)
		local m = Ui.label(markers, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.clamp(t / math.max(length, 0.01), 0, 1), 0.5),
			Size = UDim2.fromOffset(16, 16),
			TextSize = 14,
			TextColor3 = color,
			Text = text,
		})
		m.TextStrokeTransparency = 0.2
	end

	function hud.onRun(msg: any)
		garage.Visible = false
		results.Visible = false
		deckPanel.Visible = false
		readyWait.Visible = false
		runHud.Visible = true
		endedCount = 0
		myEnded = false
		spectate.Text = ""
		runLabel.Text = "RUN " .. tostring(msg.run)
		runLabel.TextColor3 = Palette.hueFor(state.mySeat or 1)
		runStartAt = os.clock() + (msg.transition or 0)
		hintStage = 0
		clearMarkers()
		-- Your clones' recorded events on the run bar (grabs), so you can time against them.
		local length = if state.clock then state.clock.length else 30
		for _, a in msg.actors do
			local rec = a.kind == "clone" and a.owner == localPlayer.UserId and state.recs[a.key]
			if rec then
				for _, e in rec.events do
					if e.kind == KIND.Grab then
						marker(e.t, length, Palette.gold, "$")
					end
				end
			end
		end
		GuiService.SelectedObject = nil
	end

	function hud.onRunEnd(_msg: any)
		interactBtn.Visible = false
		ffPill.Visible = false
		if hintBeam then
			hintBeam:Destroy()
			hintBeam = nil
		end
		local nextRun = (state.run and state.run.run or 0) + 1
		readyBtn.Text = "▶ RUN " .. nextRun
		readyWait.Text = "▶ RUN " .. nextRun
	end

	-- Between runs: show the deck (from L2) or a plain RUN button.
	function hud.showBetween()
		runHud.Visible = true
		endBtn.Visible = false
		interactBtn.Visible = false
		local deck = state.deck
		local locked = deck == nil or deck.locked == true
		deckPanel.Visible = not locked and deckOpen
		readyWait.Visible = state.levelIndex ~= 1 and (locked or not deckOpen)
		objective.Text = if locked then "" else "Tap a card to redo it"
		if deckPanel.Visible then
			GuiService.SelectedObject = readyBtn
		end
		renderDeck()
	end

	function hud.toggleDeck()
		if state.phase == "Between" and state.deck and not state.deck.locked then
			deckOpen = not deckOpen
			deckPanel.Visible = deckOpen
			readyWait.Visible = not deckOpen
		end
	end

	-- Event-log entries (already decoded) for HUD reactions.
	function hud.onEvent(e: any, live: boolean)
		local run = state.run
		if not run then
			return
		end
		local a = run.actorById[e.a]
		local hz = Config.Rec.HZ
		local length = if state.clock then state.clock.length else 30
		if e.kind == EV.EndRun or e.kind == EV.Timeout or e.kind == EV.Left then
			endedCount += 1
			if a and a.kind == "live" and a.owner == localPlayer.UserId then
				myEnded = true
				spectate.Text = if e.kind == EV.Timeout then "The tape ran out." else "Run over. Watch your clones."
			end
		elseif e.kind == EV.Caught then
			local target = run.actorById[e.b]
			endedCount += 1
			if target and target.kind == "live" and target.owner == localPlayer.UserId then
				myEnded = true
				spectate.Text = "[Guard spotted you]"
				if live then
					hud.flashRed()
					hud.bigStamp("BUSTED", Palette.alarm)
				end
			end
		elseif e.kind == EV.Zap then
			if a and a.kind == "live" then
				endedCount += 1
				if a.owner == localPlayer.UserId then
					myEnded = true
					spectate.Text = "Zapped by a laser."
					if live then
						hud.flashRed()
						hud.bigStamp("ZAPPED", Palette.alarm)
					end
				end
			elseif a and a.owner == localPlayer.UserId then
				marker(e.tick / hz, length, Palette.alarm, "⚡")
			end
		elseif e.kind == EV.Busted then
			local target = run.actorById[e.b]
			if target and target.owner == localPlayer.UserId then
				marker(e.tick / hz, length, Palette.alarm, "✕")
			end
		elseif e.kind == EV.Stuck then
			if a and a.owner == localPlayer.UserId then
				marker(e.tick / hz, length, Palette.alarm, "✕")
			end
		elseif e.kind == EV.Bank and live then
			local value = 0
			local level = state.level
			local def = level and level.loot[e.b]
			if def then
				value = def.value
			end
			local who = if a and a.kind == "clone" then Palette.badge(a.seat, a.slot) .. " " else ""
			hud.toast(who .. "+" .. Ui.money(value))
			Ui.pop(lootBox)
		elseif e.kind == EV.Squeeze and live then
			hud.toast("Crew is waiting")
		elseif e.kind == EV.GoalMet and live then
			hud.toast("Goal banked! Finish the run.")
		end
	end

	function hud.flashRed()
		if state.reduced then
			return
		end
		vignette.BackgroundTransparency = 0.7
		TweenService:Create(vignette, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end

	hud.bigStamp = function(_text: string, _color: Color3) end -- set by HeistClient (RewindDirector)

	---------------------------------------------------------------------------
	-- Per frame
	---------------------------------------------------------------------------
	local function myRootLevelPos(): Vector3?
		local char = localPlayer.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") and state.origin then
			return r.Position - state.origin
		end
		return nil
	end

	local function onPlate(pos: Vector3, plateIndex: number): boolean
		local level = state.level
		local def = level and level.plates[plateIndex]
		if not def then
			return false
		end
		local b = def.box
		return pos.X >= b.minX and pos.X <= b.maxX and pos.Z >= b.minZ and pos.Z <= b.maxZ and pos.Y <= b.maxY
	end

	local function setHintBeam(on: boolean)
		if on and not hintBeam then
			local char = localPlayer.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			local folder = state.folder
			local plate = folder and folder:FindFirstChild("Plate_A", true)
			if r and plate and plate:IsA("BasePart") then
				local a0 = Instance.new("Attachment")
				a0.Name = "HintA0"
				a0.Parent = r
				local a1 = Instance.new("Attachment")
				a1.Name = "HintA1"
				a1.Position = Vector3.new(0, 0.3, 0)
				a1.Parent = plate
				local beam = Instance.new("Beam")
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Color = ColorSequence.new(Palette.white)
				beam.Width0 = 0.4
				beam.Width1 = 0.4
				beam.LightEmission = 1
				beam.FaceCamera = true
				beam.Parent = plate
				hintBeam = beam
			end
		elseif not on and hintBeam then
			local a0 = hintBeam.Attachment0
			local a1 = hintBeam.Attachment1
			hintBeam:Destroy()
			if a0 then
				a0:Destroy()
			end
			if a1 then
				a1:Destroy()
			end
			hintBeam = nil
		end
	end

	-- L1 FTUE lines (§7.5, ≤ 30 words in all) and the generic objective.
	local function objectiveText(tView: number, pos: Vector3?): (string, boolean)
		local run = state.run
		local runIndex = if run then run.run else 1
		local carrying = state.carrying == true
		if state.levelIndex == 1 then
			if runIndex == 1 then
				local on = pos ~= nil and onPlate(pos, 1)
				if on then
					return "Stay on it. Tap END RUN.", true
				end
				return "Step on the plate", false
			end
			if tView < 4 and runIndex == 2 then
				return "Your clone stops where you stop.", false
			end
			return if carrying then "Bank it at the van" else "Grab the cash", false
		end
		if carrying then
			return "Bank it at the van", false
		end
		if tView < 6 and runIndex == 1 and LEVEL_LINES[state.levelIndex] then
			return LEVEL_LINES[state.levelIndex], false
		end
		return "Grab the loot", false
	end

	local nearLoot: number? = nil

	function hud.interact()
		if nearLoot then
			actions.interact(KIND.Grab, nearLoot)
			Ui.pop(interactBtn)
		end
	end

	function hud.update(tView: number, now: number, _dt: number, world: any)
		if state.where ~= "heist" or state.phase ~= "Run" or not state.clock then
			return
		end
		local clock = state.clock
		local length = clock.length
		local remaining = math.max(0, length - tView)
		timerLabel.Text = Ui.clock(remaining)
		local red = remaining <= H.TIMER_RED_SECONDS
		timerLabel.TextColor3 = if red then Palette.alarm else Palette.white
		timerLabel.Text = (if red then "◎ " else "") .. Ui.clock(remaining)
		timerScale.Scale = if remaining <= H.TIMER_PULSE_SECONDS and not state.reduced
			then 1 + 0.08 * math.max(0, math.sin(now * 2 * math.pi))
			else 1
		barFill.Size = UDim2.fromScale(math.clamp(tView / math.max(length, 0.01), 0, 1), 1)
		local banked = state.folder and state.folder:GetAttribute("Banked") or 0
		local goal = if state.level then state.level.goal else 0
		lootLabel.Text = Ui.money(banked) .. " / " .. Ui.money(goal)

		-- END RUN: locked ring for the first 1.5 s; co-op count; spectators lose it.
		local started = os.clock() >= runStartAt
		endBtn.Visible = not myEnded and started
		local lockFrac = math.clamp(1 - tView / Config.Rec.END_RUN_LOCK_SECONDS, 0, 1)
		lockRing.Size = UDim2.fromScale(1, lockFrac)
		lockRing.Visible = lockFrac > 0
		local crew = state.liveCount or 1
		endBtn.Text = if crew > 1
			then string.format("◀◀\nEND RUN · %d/%d", endedCount, crew)
			else "◀◀\nEND RUN"

		local pos = myRootLevelPos()
		local text, pulseEnd = objectiveText(tView, pos)
		objective.Text = text
		-- L1: END RUN pulses only while you stand on the plate (§7.5).
		if state.levelIndex == 1 and state.run and state.run.run == 1 then
			endBtn.BackgroundColor3 = if pulseEnd and math.floor(now * 3) % 2 == 0
				then Palette.white
				else Palette.CLONE_HUES[1]
			-- Stuck hints at 8 / 16 / 24 s: beam from your feet to the plate.
			if not pulseEnd and not myEnded then
				local hs = H.HINT_SECONDS
				if hintStage < #hs and tView >= hs[hintStage + 1] then
					hintStage += 1
					setHintBeam(true)
				end
			else
				setHintBeam(false)
			end
		else
			endBtn.BackgroundColor3 = Palette.hueFor(state.mySeat or 1)
			setHintBeam(false)
		end

		-- Contextual Interact (nearest loot in range, not while carrying or spectating).
		nearLoot = nil
		if pos and not myEnded and started and not state.carrying then
			local worldPos = state.origin + pos
			local index, value = world.nearestLoot(worldPos, Config.Sim.INTERACT_RANGE)
			if index then
				nearLoot = index
				interactBtn.Text = "GRAB " .. Ui.money(value)
			end
		end
		interactBtn.Visible = nearLoot ~= nil
		ffPill.Visible = state.folder ~= nil and state.folder:GetAttribute("CanFF") == true and not myEnded
		if myEnded then
			spectate.Visible = true
		end
	end

	-- Fast-forward pill: hold to skip.
	ffPill.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			actions.fastForward(true)
		end
	end)
	ffPill.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			actions.fastForward(false)
		end
	end)

	---------------------------------------------------------------------------
	-- Keys and gamepad (one verb per button)
	---------------------------------------------------------------------------
	ContextActionService:BindAction("HeistEndRun", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			if state.phase == "Between" then
				hud.ready()
			elseif endBtn.Visible then
				Ui.pop(endBtn)
				actions.endRun()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("HeistInteract", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			hud.interact()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("HeistDeck", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			hud.toggleDeck()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
	ContextActionService:BindAction("HeistFastForward", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			actions.fastForward(true)
		elseif inputState == Enum.UserInputState.End then
			actions.fastForward(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonB)

	function hud.setLiveCount(n: number)
		state.liveCount = n
	end

	function hud.hideAll()
		runHud.Visible = false
		deckPanel.Visible = false
		results.Visible = false
		readyWait.Visible = false
	end

	return hud
end

return Hud
