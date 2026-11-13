--!strict
-- Hud/Party: the van's PARTY sheet and the read-only van card (PARTY track; Config.Hideout.PARTY). The leader uses
-- their van (E on any of its points, Heist/Hideout) and gets one menu (HudLayout.PARTY):
--   CREW   SOLO | 2 | 3 | 4      (SOLO parks the van; a size opens its side door; sizes under the seats taken are off)
--   JOIN   FRIENDS ONLY | OPEN | INVITE ONLY   (OPEN = Quick Crew strangers may be matched in)
--   READY CHECK   the seats with names, crew colours and READY marks; KICK on a seated member (leader only)
--   INVITE  PAINT  STYLE  BACK                  GO (on when every seated member is READY)
-- Every button is a Heist.Ready lobby action table (Shared/Heist/LobbyLook.partyAction; VanRules.validAction) and the
-- server decides; the sheet redraws from the van's server-written attributes (Garage/Vans/Van<i>: Mode, Seats,
-- Waiting, Size, Privacy, Held, Paint, Style). Touch controls are off while it is up (a sheet), so the cursor is free;
-- E, B, Backspace or Esc close it, ENTER / Y is GO. Key hints sit on the buttons (Strings.partyKey: one place to swap
-- for the shared key-hint helper).
-- Everyone else looking at a claimed van sees a small card (HudLayout.PARTY_CARD, LobbyLook.vanCard): the owner,
-- SOLO / CREW, SEATS x / y, who can join, and SIT when they may (the server checks the invite and the hold).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local LobbyLook = require(HeistShared:WaitForChild("LobbyLook"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))
local VanRules = require(HeistShared:WaitForChild("VanRules"))

local Heist = script.Parent.Parent
local Theme = require(Heist:WaitForChild("Theme"))
local Ui = require(Heist:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local HD = Config.Hideout
local U = Config.Ui
local TAP = Ui.TAP

local Party = {}

-- The sheet's inner layout (design px inside HudLayout.PARTY; the blocks are HudLayout.PARTY_INNER, which
-- tests/hud_layout checks).
local IN = HudLayout.PARTY_INNER
local LEFT, LABEL_W, SEG_X = IN.tools[1], IN.crew[1] - IN.tools[1] - 4, IN.crew[1]
local RIGHT_X, RIGHT_W = IN.seats[1], IN.seats[3]
local ROW_SIZE, ROW_JOIN, INFO_Y = IN.crew[2], IN.join[2], IN.info[2]
local BOTTOM_Y = IN.tools[2]
local SEAT_Y, SEAT_H, SEAT_GAP = IN.seats[2] + 28, 38, 4
local SEG_W = math.floor((IN.crew[3] - 18) / 4) -- SOLO 2 3 4
local JOIN_W = math.floor((IN.join[3] - 12) / 3)
local TOOL_W = math.floor((IN.tools[3] - 18) / 4)

local function nameOf(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	return if p then p.DisplayName else "?"
end

local function vanModel(bay: number): Instance?
	local g = workspace:FindFirstChild("Garage")
	local vans = g and g:FindFirstChild("Vans")
	return vans and vans:FindFirstChild("Van" .. bay)
end

-- The van as LobbyLook sees it, from its server-written attributes.
function Party.view(m: Instance): (LobbyLook.VanView, { any })
	local seats = VanRules.decodeSeats(m:GetAttribute("Seats"))
	return {
		bay = tonumber(m:GetAttribute("Bay")) or 0,
		mode = tostring(m:GetAttribute("Mode") or "free"),
		crewId = tonumber(m:GetAttribute("CrewId")) or 0,
		leaderId = tonumber(m:GetAttribute("LeaderId")) or 0,
		waiting = tonumber(m:GetAttribute("Waiting")) or 0,
		size = #seats,
		cap = tonumber(m:GetAttribute("Size")),
		privacy = m:GetAttribute("Privacy") :: string?,
		held = tonumber(m:GetAttribute("Held")) or 0,
	},
		seats
end

-- The key hint for a button on this device ("" on touch).
local function key(board: string, pad: string): string?
	if Common.usingTouch() then
		return nil
	end
	return if Common.usingGamepad() then pad else board
end

function Party.build(ctx: any): any
	local hud = ctx.hud
	local actions = ctx.actions
	local party = {}

	---------------------------------------------------------------- the sheet
	local sheet = Ui.panel(ctx.root, { Name = "Party", Visible = false })
	Common.place(sheet, HudLayout.PARTY)
	Common.sheetBlocksTouch("party", sheet)
	party.sheet = sheet
	local title = Ui.label(sheet, {
		Position = UDim2.fromOffset(LEFT, 6),
		Size = UDim2.fromOffset(440, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 24,
		Text = Strings.PARTY_TITLE,
	})
	Ui.iconWord(title, "van", "left", U.ICON_SMALL)
	local function caption(text: string, x: number, y: number, w: number, h: number): TextLabel
		return Ui.label(sheet, {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 16,
			TextColor3 = Palette.steelHi,
			Text = text,
		})
	end
	caption(Strings.PARTY_CREW, LEFT, ROW_SIZE, LABEL_W, TAP)
	caption(Strings.PARTY_JOIN, LEFT, ROW_JOIN, LABEL_W, TAP)
	caption(Strings.PARTY_READY_CHECK, RIGHT_X, IN.seats[2], RIGHT_W, 24)
	local info = Ui.label(sheet, {
		Name = "Info",
		Position = UDim2.fromOffset(LEFT, INFO_Y),
		Size = UDim2.fromOffset(IN.info[3], IN.info[4]),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextSize = 16,
		TextColor3 = Palette.steelHi,
		Text = "",
	})

	local bay = 0
	local onBack: (() -> ())? = nil
	local model: Instance? = nil
	local conns: { RBXScriptConnection } = {}
	local current: LobbyLook.PartySheet? = nil
	local render: () -> ()

	local function send(kind: string, n: number?)
		local a = LobbyLook.partyAction(kind, bay, n)
		if a and actions.lobbyAction then
			actions.lobbyAction(a)
		end
	end

	local function setOn(b: TextButton, on: boolean, enabled: boolean)
		b.BackgroundColor3 = if not enabled then Palette.steelLo elseif on then Palette.gold else Theme.COLOR.neutral
		b.TextColor3 = if enabled then Palette.ink else Palette.steelHi
		b.Active = enabled
	end

	-- CREW: SOLO | 2 | 3 | 4
	local sizeBtns: { [number]: TextButton } = {}
	local all = VanRules.cap()
	local segW = SEG_W
	local soloBtn = Ui.button(sheet, {
		Name = "Solo",
		Position = UDim2.fromOffset(SEG_X, ROW_SIZE),
		Size = UDim2.fromOffset(segW, TAP),
		TextSize = 20,
		Text = Strings.PARTY_SOLO,
	}, function()
		local c = current
		if c and c.canSolo and not c.solo then
			send("solo")
		end
	end, "UIToggle")
	for n = HD.PARTY.MIN_SIZE, all do
		local i = n - HD.PARTY.MIN_SIZE + 1
		sizeBtns[n] = Ui.button(sheet, {
			Name = "Size" .. n,
			Position = UDim2.fromOffset(SEG_X + i * (segW + 6), ROW_SIZE),
			Size = UDim2.fromOffset(segW, TAP),
			TextSize = 24,
			Text = tostring(n),
		}, function()
			local c = current
			if c and n >= c.taken and not (n == c.cap and not c.solo) then
				send("size", n)
			end
		end, "UIToggle")
	end

	-- JOIN: FRIENDS ONLY | OPEN | INVITE ONLY
	local privacyBtns: { [number]: TextButton } = {}
	local joinW = JOIN_W
	for i, name in HD.PARTY.PRIVACY do
		privacyBtns[i] = Ui.button(sheet, {
			Name = "Privacy_" .. name,
			Position = UDim2.fromOffset(SEG_X + (i - 1) * (joinW + 6), ROW_JOIN),
			Size = UDim2.fromOffset(joinW, TAP),
			TextSize = 16,
			TextWrapped = true,
			Text = Strings.PARTY_PRIVACY[name] or string.upper(name),
		}, function()
			local c = current
			if c and not c.solo and c.privacy ~= i then
				send("privacy", i)
			end
		end, "UIToggle")
	end

	-- READY CHECK: one row per seat
	type Row = { frame: Frame, pip: Frame, name: TextLabel, state: TextLabel, kick: TextButton }
	local rows: { Row } = {}
	for k = 1, all do
		local row = Ui.frame(sheet, {
			Name = "Seat" .. k,
			Position = UDim2.fromOffset(RIGHT_X, SEAT_Y + (k - 1) * (SEAT_H + SEAT_GAP)),
			Size = UDim2.fromOffset(RIGHT_W, SEAT_H),
			BackgroundColor3 = Palette.inkHi,
			BackgroundTransparency = 0,
		})
		Ui.corner(row, 8)
		local pip = Ui.frame(row, {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(8, SEAT_H - 12),
			BackgroundColor3 = Palette.hueFor(k),
			BackgroundTransparency = 0,
		})
		Ui.pill(pip)
		local nm = Ui.label(row, {
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.fromOffset(100, SEAT_H),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextSize = 16,
			Text = "",
		})
		local stateText = Ui.label(row, {
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.fromOffset(RIGHT_W - 26, SEAT_H),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 16,
			Text = "",
		})
		local kick = Ui.button(row, {
			Name = "Kick",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(60, SEAT_H - 6),
			BackgroundColor3 = Palette.exit,
			TextSize = 16,
			Text = Strings.PARTY_KICK,
			Visible = false,
		}, function()
			local c = current
			local s = c and c.seats[k]
			if s and s.kick then
				send("kick", k)
			end
		end, "UIBack")
		table.insert(rows, { frame = row, pip = pip, name = nm, state = stateText, kick = kick })
	end

	-- INVITE  PAINT  STYLE  BACK   |   GO
	local bw = TOOL_W
	local inviteBtn = Ui.button(sheet, {
		Name = "Invite",
		Position = UDim2.fromOffset(LEFT, BOTTOM_Y),
		Size = UDim2.fromOffset(bw, TAP),
		BackgroundColor3 = Palette.marbleHi,
		TextSize = 16,
		TextWrapped = true,
		Text = Strings.PARTY_INVITE,
	}, function()
		if hud.invite then
			hud.invite()
		end
	end, "UIToggle")
	local paintBtn = Ui.button(sheet, {
		Name = "Paint",
		Position = UDim2.fromOffset(LEFT + (bw + 6), BOTTOM_Y),
		Size = UDim2.fromOffset(bw, TAP),
		TextSize = 16,
		TextWrapped = true,
		Text = Strings.PARTY_PAINT,
	}, function()
		local m = model
		if m then
			send("paint", VanRules.nextPaint({ paint = tonumber(m:GetAttribute("Paint")) or 0 } :: any))
		end
	end, "UIToggle")
	local styleBtn = Ui.button(sheet, {
		Name = "Style",
		Position = UDim2.fromOffset(LEFT + 2 * (bw + 6), BOTTOM_Y),
		Size = UDim2.fromOffset(bw, TAP),
		TextSize = 16,
		TextWrapped = true,
		Text = Strings.PARTY_STYLE,
	}, function()
		local m = model
		if m then
			send("style", VanRules.nextStyle({ style = tonumber(m:GetAttribute("Style")) or 1 }))
		end
	end, "UIToggle")
	local backBtn = Ui.button(sheet, {
		Name = "Back",
		Position = UDim2.fromOffset(LEFT + 3 * (bw + 6), BOTTOM_Y),
		Size = UDim2.fromOffset(bw, TAP),
		TextSize = 16,
		TextWrapped = true,
		Text = Strings.LOBBY_BACK,
	}, function()
		local fn = onBack
		if fn then
			fn()
		end
	end, "UIBack")
	local goBtn = Ui.button(sheet, {
		Name = "Go",
		Position = UDim2.fromOffset(IN.go[1], IN.go[2]),
		Size = UDim2.fromOffset(IN.go[3], IN.go[4]),
		BackgroundColor3 = Palette.exit,
		TextSize = 20,
		TextWrapped = true,
		Text = Strings.PARTY_GO,
	}, function()
		party.go()
	end, "UIConfirm")
	Ui.iconWord(goBtn, "play", "left", U.ICON_SMALL)

	render = function()
		local m = model
		if not (m and m.Parent) then
			return
		end
		local view, seats = Party.view(m)
		local c = LobbyLook.partySheet(view, seats)
		current = c
		local style = HD.VAN.STYLES[tonumber(m:GetAttribute("Style")) or 1]
		local paint = HD.VAN.PAINTS[VanRules.nextPaint({ paint = tonumber(m:GetAttribute("Paint")) or 0 } :: any)]
		local nextStyle = HD.VAN.STYLES[VanRules.nextStyle({ style = tonumber(m:GetAttribute("Style")) or 1 })]
		title.Text = Strings.PARTY_TITLE .. (if style then Strings.SEP .. style.name else "")
		setOn(soloBtn, c.solo, c.canSolo or c.solo)
		for n, b in sizeBtns do
			local sz = c.sizes[n - HD.PARTY.MIN_SIZE + 1]
			setOn(b, sz ~= nil and sz.on, sz ~= nil and sz.enabled)
		end
		for i, b in privacyBtns do
			setOn(b, not c.solo and c.privacy == i, not c.solo)
		end
		local privacyName = HD.PARTY.PRIVACY[c.privacy]
		info.Text = if c.solo then Strings.PARTY_SOLO_INFO else Strings.PARTY_PRIVACY_INFO[privacyName] or ""
		for k, r in rows do
			local s = c.seats[k]
			local closed = s.state == "closed"
			r.frame.BackgroundTransparency = if closed then 0.7 else 0
			r.pip.BackgroundColor3 = if s.userId ~= 0 then Palette.hueFor(k) else Palette.steelLo
			r.name.Text = if s.userId ~= 0 then string.upper(nameOf(s.userId)) else ""
			r.name.TextColor3 = if s.userId ~= 0 then Palette.hueFor(k) else Palette.steelHi
			r.state.Text = Strings.PARTY_SEAT[s.state] or ""
			r.state.TextColor3 = if s.state == "ready" or s.state == "driver" then Palette.exit else Palette.steelHi
			r.state.Visible = not s.kick
			r.kick.Visible = s.kick
		end
		paintBtn.Text = Strings.PARTY_PAINT .. (if paint then Strings.SEP .. paint.name else "")
		styleBtn.Text = Strings.PARTY_STYLE .. (if nextStyle then Strings.SEP .. nextStyle.name else "")
		local goText = if c.go == "solo"
			then Strings.PARTY_SOLO_GO
			elseif c.go == "go" then Strings.PARTY_GO
			else Strings.partyWait(math.max(c.waiting, 1))
		goBtn.Text =
			Strings.partyKey(goText, if c.go == "wait" then nil else key(Strings.KEY_ENTER, Strings.KEY_PAD_GO))
		goBtn.BackgroundColor3 = if c.go == "wait" then Palette.steelLo else Palette.exit
		goBtn.Active = c.go ~= "wait"
		backBtn.Text = Strings.partyKey(Strings.LOBBY_BACK, key(Strings.KEY_ESC, Strings.KEY_PAD_BACK))
		local flags = ReplicatedStorage:FindFirstChild("LiveFlags")
		inviteBtn.Visible = not (flags and flags:GetAttribute("invites") == false)
	end

	local function unwatch()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
	end

	-- Opens the sheet for your van at `bay`; back() is what BACK / Esc / B do (Heist/Hideout leaves it).
	function party.open(b: number, back: () -> ())
		unwatch()
		bay = b
		onBack = back
		model = vanModel(b)
		local m = model
		if m then
			for _, attr in { "Mode", "Seats", "Waiting", "Size", "Privacy", "Held", "Paint", "Style", "LeaderId" } do
				table.insert(
					conns,
					m:GetAttributeChangedSignal(attr):Connect(function()
						if Ui.isShown(sheet) then
							render()
						end
					end)
				)
			end
		end
		Ui.show(sheet)
		render()
		Common.selectFor(goBtn)
	end

	function party.close()
		unwatch()
		onBack = nil
		model = nil
		current = nil
		Ui.hide(sheet)
	end

	function party.isOpen(): boolean
		return Ui.isShown(sheet)
	end

	-- A garage sync (names, the crew) while it is open.
	function party.refresh()
		if Ui.isShown(sheet) then
			render()
		end
	end

	-- GO (the button, ENTER, Y): SOLO · GO from a parked van, GO when every seated member is READY.
	function party.go()
		local c = current
		if not (c and Ui.isShown(sheet)) or c.go == "wait" then
			return
		end
		send("go", if c.go == "solo" then 1 else nil)
	end

	-- The bay the sheet is open for (0 = closed).
	function party.bay(): number
		return if Ui.isShown(sheet) then bay else 0
	end

	---------------------------------------------------------------- the read-only card
	local card = Ui.panel(ctx.root, { Name = "VanCard", Visible = false }, Palette.steel)
	Common.place(card, HudLayout.PARTY_CARD)
	local CW = HudLayout.PARTY_CARD.w
	local cardTitle = Ui.label(card, {
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.fromOffset(CW - 20, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextSize = 20,
		Text = "",
	})
	local cardInfo = Ui.label(card, {
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.fromOffset(CW - 20, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		TextColor3 = Palette.steelHi,
		Text = "",
	})
	local cardWhy = Ui.label(card, {
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.fromOffset(CW - 20, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextSize = 16,
		TextColor3 = Palette.steelHi,
		Text = "",
	})
	local onSit: (() -> ())? = nil
	local sitBtn = Ui.button(card, {
		Name = "Sit",
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.fromOffset(140, 40),
		BackgroundColor3 = Palette.gold,
		TextSize = 16,
		Text = Strings.LOBBY_VERB.sit,
		Visible = false,
	}, function()
		local fn = onSit
		if fn then
			fn()
		end
	end, "UIConfirm")
	local cardKey = ""
	-- The card for the van you look at (nil = none); sitFn = SIT (Heist/Hideout's use).
	function party.setCard(c: LobbyLook.VanCard?, sitFn: (() -> ())?)
		onSit = sitFn
		if c == nil then
			if card.Visible then
				Ui.hide(card)
			end
			cardKey = ""
			return
		end
		local mode = if c.mode == "solo" then Strings.PARTY_SOLO else Strings.PARTY_CREW
		local k = table.concat({
			c.bay,
			c.leaderId,
			mode,
			c.seated,
			c.cap,
			c.privacy,
			tostring(c.sit),
			c.why or "",
			tostring(Common.usingTouch()),
		}, ":")
		if k ~= cardKey then
			cardKey = k
			cardTitle.Text = Strings.partyCardTitle(nameOf(c.leaderId))
			cardInfo.Text = table.concat({
				mode,
				Strings.partySeats(c.seated, c.cap),
				Strings.PARTY_PRIVACY[c.privacy] or "",
			}, Strings.SEP)
			cardWhy.Text = if c.sit then "" else Strings.PARTY_CARD_WHY[c.why or ""] or ""
			sitBtn.Visible = c.sit
			sitBtn.Text = Strings.partyKey(Strings.LOBBY_VERB.sit, key(Strings.KEY_E, Strings.KEY_PAD))
		end
		if not card.Visible then
			Ui.show(card)
		end
	end

	return party
end

return Party
