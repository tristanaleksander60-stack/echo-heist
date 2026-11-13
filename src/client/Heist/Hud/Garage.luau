--!strict
-- Hud/Garage: the job board (PLAN_STEAM_PLUS §3.2, §4.3 U6): heists in play order as job photos
-- pinned to cork, a red string from pin to pin, medal stickers, the NEXT job glowing like the 3D
-- board's NEXT card in the garage (Heist/JobBoard, Config.Lobby.BOARD; the same rule:
-- Shared/Heist/CrewBoard.nextJob = Heist/JobCard.title), locked jobs veiled with what unlocks them.
-- Then the daily vault card with streak and modifier once the first heist is cleared, advent
-- catch-up, the crew and JOIN for friends in the server (§3.3, §5.3, §7.4), and SETTINGS (U7).
-- Roblox's player list comes back here (it is hidden during heists, PLAN S8).
-- The hideout lobby (Config.Hideout, garage sync `lobby`): the sheet never opens by itself; a station opens it
-- (Heist/Hideout: openStation) as the job board ("board": the jobs, the crew, SETTINGS), the laptop ("laptop": today's
-- biggest haul on this server, the daily vault, the advent catch-up list behind CATCH-UP) or the Quick Crew sheet
-- ("crew", the "LOOKING FOR CREW" sign: LOOK FOR A CREW / STOP, OPEN MY VAN / CLOSE, INVITE FRIENDS; Shared/Heist/
-- LobbyLook.quickButtons), with a BACK button in the right column. A job pick there pins the job for the crew's van
-- (the server's Heist.SelectLevel), it no longer starts the heist from the garage.
-- The laptop's board (LOBBY 2, MASTERPLAN §5.3 D1): the server's published rows (ReplicatedStorage.EH_HaulBoard,
-- Shared/Data/HaulBoard.decode): the top Config.Data.Board.SHOW in two columns, each a rank, a Rookie portrait
-- (Common.portrait), the display name and the haul, and your own row on top. Numbers and display names only (no free
-- text); hidden with the LiveFlag `boards`; an empty or missing board says so and never waits on anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local CrewBoard = require(HeistShared:WaitForChild("CrewBoard"))
local LobbyLook = require(HeistShared:WaitForChild("LobbyLook"))
local HaulBoard = require(Shared:WaitForChild("Data"):WaitForChild("HaulBoard"))
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Heist = script.Parent.Parent
local Icons = require(Heist:WaitForChild("Icons"))
local Motion = require(Heist:WaitForChild("Motion"))
local Sound = require(Heist:WaitForChild("Sound"))
local Theme = require(Heist:WaitForChild("Theme"))
local Ui = require(Heist:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local U = Config.Ui
local B = U.BOARD
local LB = Config.Lobby.BOARD
local TAP = Ui.TAP

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end
local NEXT_CARD = rgb(LB.cardColor) -- the 3D NEXT card's plate and its glowing text
local NEXT_TEXT = rgb(LB.textColor)
local localPlayer = Players.LocalPlayer

local Garage = {}

function Garage.build(ctx: any): any
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local root = ctx.root
	local garageUi = {}

	local garage = Ui.panel(root, { Name = "Garage", Visible = false })
	Common.place(garage, HudLayout.GARAGE)
	garageUi.frame = garage
	local garageTitle = Ui.label(garage, {
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.fromOffset(440, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 26,
		Text = Strings.JOB_BOARD,
	})
	-- The cork board: job photos placed by CrewBoard.boardSlot (no grid layout: the string needs
	-- each pin's position).
	local tapes = Instance.new("ScrollingFrame")
	tapes.Name = "JobBoard"
	tapes.Position = UDim2.fromOffset(14, 44)
	tapes.Size = UDim2.fromOffset(462, 156)
	tapes.BackgroundColor3 = rgb(B.CORK)
	tapes.BackgroundTransparency = 0
	tapes.BorderSizePixel = 0
	tapes.ScrollingDirection = Enum.ScrollingDirection.Y
	tapes.AutomaticCanvasSize = Enum.AutomaticSize.None
	tapes.CanvasSize = UDim2.fromScale(0, 0)
	tapes.ScrollBarThickness = 4
	tapes.Parent = garage
	Ui.corner(tapes)
	Ui.stroke(tapes, Palette.ink, Theme.STROKE)

	local daily = Ui.frame(garage, {
		Name = "Daily",
		Position = UDim2.fromOffset(14, 208),
		Size = UDim2.fromOffset(462, 106),
		BackgroundColor3 = Palette.inkHi,
		BackgroundTransparency = 0,
	})
	Ui.corner(daily, 12)
	Ui.stroke(daily, Palette.gold, 2)
	local dailyTitle = Ui.label(daily, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(200, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		TextColor3 = Palette.gold,
		Text = Strings.DAILY_VAULT,
	})
	local dailyName = Ui.label(daily, {
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.fromOffset(200, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		TextSize = 18,
		Text = "",
	})
	local dailyInfo = Ui.label(daily, {
		Position = UDim2.fromOffset(12, 70),
		Size = UDim2.fromOffset(200, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextSize = 16,
		TextColor3 = Palette.steelHi,
		Text = "",
	})
	local catchUpMode = false
	local catchBtn = Ui.button(daily, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -136, 0.5, 0),
		Size = UDim2.fromOffset(116, TAP),
		TextSize = 16,
		TextWrapped = true,
		Text = Strings.CATCH_UP,
	}, function()
		catchUpMode = not catchUpMode
		hud.showGarage()
	end, "UIToggle")
	local playDailyBtn = Ui.button(daily, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(116, TAP),
		BackgroundColor3 = Palette.gold,
		TextSize = 20,
		Text = Strings.PLAY,
	}, function()
		local g = state.garage
		local d = g and g.daily
		if not d or d.enabled == false then
			hud.toast(Strings.DAILY_CLOSED)
		elseif g.leader ~= localPlayer.UserId then
			hud.toast(Strings.LEADER_PICKS_HEIST)
		else
			actions.selectDaily(nil)
		end
	end, "UIConfirm")

	local CREW_FULL = 270 - TAP - 8
	local crewBox = Ui.frame(garage, {
		Position = UDim2.fromOffset(486, 44 + TAP + 8),
		Size = UDim2.fromOffset(200, CREW_FULL),
		BackgroundColor3 = Palette.inkHi,
		BackgroundTransparency = 0,
	})
	Ui.corner(crewBox, 12)
	local crewList = Instance.new("ScrollingFrame")
	crewList.Position = UDim2.fromOffset(8, 8)
	crewList.Size = UDim2.new(1, -16, 1, -16)
	crewList.BackgroundTransparency = 1
	crewList.BorderSizePixel = 0
	crewList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	crewList.CanvasSize = UDim2.fromScale(0, 0)
	crewList.ScrollBarThickness = 4
	crewList.Parent = crewBox
	local crewLayout = Instance.new("UIListLayout")
	crewLayout.Padding = UDim.new(0, 6)
	crewLayout.SortOrder = Enum.SortOrder.LayoutOrder
	crewLayout.Parent = crewList
	-- U7: settings from the garage too (in a heist they open from MENU).
	local settingsBtn = Ui.button(garage, {
		Name = "Settings",
		Position = UDim2.fromOffset(486, 44), -- HudLayout.GARAGE_SETTINGS: clear of the touch jump button
		Size = UDim2.fromOffset(200, TAP),
		TextSize = 20,
		Text = Strings.SETTINGS,
	}, function()
		if hud.openSettings then
			hud.openSettings(false)
		end
	end, "UIToggle")
	Ui.iconWord(settingsBtn, "settings", "left", U.ICON_SMALL)
	-- The hideout's stations: BACK (bottom of the right column; the crew list shrinks above it).
	local station: string? = nil -- "board" | "laptop" while a station holds the sheet open
	local onBack: (() -> ())? = nil
	local backBtn = Ui.button(garage, {
		Name = "StationBack",
		Position = UDim2.fromOffset(486, 314 - TAP),
		Size = UDim2.fromOffset(200, TAP),
		TextSize = 20,
		Text = Strings.LOBBY_BACK,
		Visible = false,
	}, function()
		local fn = onBack
		if fn then
			fn()
		end
	end, "UIBack")
	Ui.iconWord(backBtn, "close", "left", U.ICON_SMALL)
	Common.keyCap(backBtn, "back")

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

	local garageOpen = false

	local breath: Tween? = nil
	local function clearTapes()
		if breath then
			breath:Cancel()
			breath = nil
		end
		for _, c in tapes:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
	end

	-- A pinned card's frame at board position k (and the board's canvas for n cards).
	local function pinAt(card: GuiObject, k: number)
		local x, y = CrewBoard.boardSlot(k)
		card.Position = UDim2.fromOffset(x, y)
		card.Size = UDim2.fromOffset(B.CELL[1], B.CELL[2])
		card.Rotation = if Ui.reducedMotion() then 0 else B.TILT[(k - 1) % #B.TILT + 1]
	end
	local function pinPoint(k: number): (number, number)
		local x, y = CrewBoard.boardSlot(k)
		return x + B.CELL[1] / 2, y + B.PIN / 2 + 1
	end
	local function pin(k: number)
		local px, py = pinPoint(k)
		local p = Ui.frame(tapes, {
			Name = "Pin" .. k,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(px, py),
			Size = UDim2.fromOffset(B.PIN, B.PIN),
			BackgroundColor3 = Palette.alarm,
			BackgroundTransparency = 0,
			ZIndex = 6,
			Active = false,
		})
		Ui.pill(p)
		Ui.stroke(p, Palette.ink, 1.5)
	end
	-- The red string from pin k to pin k + 1 (play order).
	local function redString(k: number)
		local x0, y0 = pinPoint(k)
		local x1, y1 = pinPoint(k + 1)
		local cx, cy, len, rot = CrewBoard.segment(x0, y0, x1, y1)
		Ui.frame(tapes, {
			Name = "String" .. k,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cx, cy),
			Size = UDim2.fromOffset(len, B.STRING_W),
			Rotation = rot,
			BackgroundColor3 = rgb(B.STRING),
			BackgroundTransparency = 0,
			ZIndex = 5,
			Active = false,
		})
	end
	local function setCanvas(n: number)
		tapes.CanvasSize = UDim2.fromOffset(0, CrewBoard.boardHeight(n))
	end

	-- A tape's name from its data key (the garage list carries both).
	local function tapeName(dataKey: string): string
		local g = state.garage
		for _, other in (g and g.levels) or {} do
			if other.dataKey == dataKey then
				return tostring(other.name)
			end
		end
		return dataKey
	end

	-- Medal stickers: earned ones gold (story: Haul / Crew / Clean; party: its haul tiers).
	local STORY_MEDALS = { "Haul", "Crew", "Clean" }
	local function earned(lv: any, i: number): boolean
		local want = if lv.kind == "party" then "Haul" .. i else STORY_MEDALS[i]
		for _, m in lv.medals or {} do
			if m == want then
				return true
			end
		end
		return false
	end

	local function renderTapes(leader: boolean): TextButton?
		local g = state.garage
		local levels = g.levels or {}
		local nextIndex = CrewBoard.nextJob(levels)
		local first: TextButton? = nil
		local nextCard: TextButton? = nil
		for k, lv in levels do
			local party = lv.kind == "party"
			local tag = if party
				then Strings.partyTag(tonumber(lv.cap) or 8)
				else Strings.runSeconds(tonumber(lv.runSeconds) or 0)
			local stars = tonumber(lv.starsNeeded) or 0
			local lockText = if lv.needsClear ~= nil
				then Strings.lockClear(tapeName(lv.needsClear))
				elseif stars > 0 then Strings.lockStars(stars)
				else Strings.LOCKED
			local isNext = lv.unlocked and lv.index == nextIndex
			-- The job photo: paper, a colour band by location with the job's number and name.
			local b = Ui.button(tapes, {
				Name = "Job" .. tostring(lv.index),
				BackgroundColor3 = Palette.exit,
				Text = "",
				LayoutOrder = lv.index,
				ZIndex = 2,
			}, function()
				if not leader then
					hud.toast(Strings.LEADER_PICKS_HEIST)
				elseif not lv.unlocked then
					Sound.play("UIError")
					hud.toast(
						if lv.needsClear ~= nil
							then Strings.clearFirst(tapeName(lv.needsClear))
							elseif stars > 0 then Strings.starsToOpen(stars)
							else Strings.HEIST_LOCKED
					)
				else
					actions.selectLevel(lv.index)
				end
			end)
			pinAt(b, k)
			local band = Ui.frame(b, {
				Name = "Photo",
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.new(1, -8, 0, 30),
				BackgroundColor3 = rgb(B.LOCATION[CrewBoard.location(lv)]),
				BackgroundTransparency = 0,
				ZIndex = 3,
				Active = false,
			})
			if party then
				Ui.stroke(band, Palette.gold, Theme.STROKE)
			end
			local title = Ui.label(band, {
				Position = UDim2.fromOffset(6, 0),
				Size = UDim2.new(1, -12, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = U.TYPE_SCALE[1],
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = Strings.jobPhoto(lv.index, tostring(lv.name)),
				ZIndex = 4,
			})
			title.Active = false
			Ui.label(b, {
				Position = UDim2.fromOffset(8, 36),
				Size = UDim2.new(1, -16, 0, 20),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = U.TYPE_SCALE[1],
				TextColor3 = Palette.ink,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Text = tag,
				ZIndex = 3,
				Active = false,
			})
			if lv.unlocked then
				-- Three medal stickers, a little crooked.
				for i = 1, 3 do
					local on = earned(lv, i)
					local sticker = Ui.frame(b, {
						Name = "Sticker" .. i,
						Position = UDim2.fromOffset(8 + (i - 1) * (B.STICKER + 6), 60),
						Size = UDim2.fromOffset(B.STICKER, B.STICKER),
						BackgroundColor3 = if on then Palette.gold else Palette.steelHi,
						BackgroundTransparency = 0,
						Rotation = if Ui.reducedMotion() then 0 else (i - 2) * 6,
						ZIndex = 3,
						Active = false,
					})
					Ui.pill(sticker)
					Ui.stroke(sticker, Palette.ink, 1.5)
					Icons.attach(sticker, if on then "star" else "star_empty", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(B.STICKER - 4, B.STICKER - 4),
						ImageColor3 = Palette.ink,
						ZIndex = 4,
					})
				end
			else
				-- Locked: an ink veil, a lock and what opens it.
				local veil = Ui.frame(b, {
					Name = "Locked",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.ink,
					BackgroundTransparency = 0.35,
					ZIndex = 5,
					Active = false,
				})
				Ui.corner(veil)
				local why = Ui.label(veil, {
					Position = UDim2.fromOffset(8, 56),
					Size = UDim2.new(1, -16, 0, 24),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextSize = U.TYPE_SCALE[1],
					TextColor3 = Palette.steelHi,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Text = lockText,
					ZIndex = 6,
					Active = false,
				})
				Ui.iconWord(why, "lock", "left", U.ICON_SMALL - 4)
			end
			if isNext then
				-- NEXT: the 3D board's NEXT card in 2D (its ink plate and warm glowing text), a gold
				-- outline that breathes.
				local chip = Ui.label(b, {
					Name = "Next",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -6, 0, 56),
					Size = UDim2.fromOffset(74, 24),
					TextSize = U.TYPE_SCALE[1],
					TextColor3 = NEXT_TEXT,
					Text = Strings.JOB_BOARD_NEXT,
					ZIndex = 4,
					Active = false,
				})
				chip.BackgroundColor3 = NEXT_CARD
				chip.BackgroundTransparency = 0
				Ui.pill(chip)
				local outline = b:FindFirstChild("Outline")
				if outline and outline:IsA("UIStroke") then
					outline.Color = Palette.gold
					outline.Thickness = 3
					outline.Transparency = U.BREATH_TRANSPARENCY[1]
					if not Ui.reducedMotion() then
						breath = Motion.breathe(outline, { Transparency = U.BREATH_TRANSPARENCY[2] })
					end
				end
				nextCard = b
			end
			pin(k)
			if k < #levels then
				redString(k)
			end
			first = first or b
		end
		setCanvas(#levels)
		return nextCard or first
	end

	local function renderCatchUp(leader: boolean): TextButton?
		local g = state.garage
		local d = g and g.daily or {}
		local back = Ui.button(tapes, {
			BackgroundColor3 = Palette.steel,
			TextSize = 18,
			Text = Strings.BACK,
			LayoutOrder = 0,
		}, function()
			catchUpMode = false
			hud.showGarage()
		end, "UIBack")
		pinAt(back, 1)
		local catchUps = d.catchUp or {}
		setCanvas(#catchUps + 1)
		for i, c in catchUps do
			local card = Ui.button(tapes, {
				BackgroundColor3 = Palette.goldHi,
				TextColor3 = Palette.ink,
				TextSize = 16,
				TextWrapped = true,
				Text = Strings.catchUpCard(
					if c.advent then Strings.advent(c.advent) else Common.dateText(c.day),
					tostring(c.name)
				),
				LayoutOrder = i,
			}, function()
				if not leader then
					hud.toast(Strings.LEADER_PICKS_HEIST)
				else
					actions.selectDaily(c.day)
				end
			end, "UIConfirm")
			pinAt(card, i + 1)
			pin(i + 1)
		end
		return back
	end

	-- A note on the cork (the board's rows, the Quick Crew info): ink text, no stroke.
	local function corkText(text: string, x: number, y: number, w: number, h: number, size: number?): TextLabel
		local l = Ui.label(tapes, {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			TextSize = size or 16,
			TextColor3 = Palette.ink,
			stroke = false,
			Text = text,
		})
		l.Active = false
		return l
	end

	-- One board row: a paper strip with the rank, a Rookie portrait, the name and the haul.
	local function boardRow(e: any, rank: number, x: number, y: number, w: number, h: number, mine: boolean)
		local row = Ui.frame(tapes, {
			Name = "Row" .. rank,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = if mine then Palette.goldHi elseif rank == 1 then Palette.marbleHi else Palette.marble,
			BackgroundTransparency = 0,
			Active = false,
		})
		Ui.corner(row, 4)
		local rankText = Ui.label(row, {
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.fromOffset(30, h),
			TextSize = 14,
			TextColor3 = Palette.ink,
			stroke = false,
			Text = Strings.boardRank(rank),
		})
		rankText.Active = false
		local face = Ui.frame(row, {
			Position = UDim2.fromOffset(34, 1),
			Size = UDim2.fromOffset(h - 2, h - 2),
			BackgroundColor3 = Palette.hueFor((rank - 1) % 4 + 1),
			BackgroundTransparency = 0,
			Active = false,
		})
		Ui.corner(face, 4)
		local vp = Common.portrait(face, e.userId, Palette.hueFor((rank - 1) % 4 + 1))
		vp.Size = UDim2.fromScale(1, 1)
		local haul = Ui.label(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 0),
			Size = UDim2.fromOffset(64, h),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextSize = 14,
			TextColor3 = Palette.ink,
			stroke = false,
			Text = CrewBoard.money(e.haul),
		})
		haul.Active = false
		local name = Ui.label(row, {
			Position = UDim2.fromOffset(34 + h + 2, 0),
			Size = UDim2.new(1, -(34 + h + 2 + 72), 0, h),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextSize = 14,
			TextColor3 = Palette.ink,
			stroke = false,
			Text = if mine then Strings.BOARD_YOU else e.name,
		})
		name.Active = false
	end

	-- The laptop's board: today's biggest haul on this server (top SHOW in two columns) and your row on top.
	local function renderBoard()
		setCanvas(0)
		local flags = ReplicatedStorage:FindFirstChild("LiveFlags")
		if flags and flags:GetAttribute("boards") == false then
			corkText(Strings.BOARD_OFF, 12, 12, 430, 40, 18)
			return
		end
		local f = ReplicatedStorage:FindFirstChild("EH_HaulBoard")
		local g = state.garage
		local day = g and g.daily and tonumber(g.daily.day)
		local rows = {}
		if f and (day == nil or f:GetAttribute("Day") == day) then
			rows = HaulBoard.decode(f:GetAttribute("Rows"))
		end
		local W = 462 - 16
		local rh = 22
		-- your row first
		local myRank: number? = nil
		for i, e in rows do
			if e.userId == localPlayer.UserId then
				myRank = i
				boardRow(e, i, 8, 6, W, rh, true)
				break
			end
		end
		if not myRank then
			corkText(if #rows == 0 then Strings.BOARD_EMPTY else Strings.BOARD_NOT_ON, 10, 6, W, rh, 15)
		end
		local col = (W - 8) / 2
		for i = 1, math.min(Config.Data.Board.SHOW, #rows) do
			local c = math.floor((i - 1) / 5)
			local r = (i - 1) % 5
			boardRow(rows[i], i, 8 + c * (col + 8), 6 + rh + 6 + r * (rh + 2), col, rh, i == myRank)
		end
	end

	-- The Quick Crew sheet (the crew sign): your buttons (LobbyLook.quickButtons), an info line and the status.
	local function renderQuick(): TextButton?
		setCanvas(0)
		local g = state.garage or {}
		local bay = tonumber(g.van) or 0
		local gm = workspace:FindFirstChild("Garage")
		local vans = gm and gm:FindFirstChild("Vans")
		local van = if bay > 0 and vans then vans:FindFirstChild("Van" .. bay) else nil
		local flags = ReplicatedStorage:FindFirstChild("LiveFlags")
		local q = tostring(localPlayer:GetAttribute("QuickCrew") or "")
		local buttons, info = LobbyLook.quickButtons({
			leader = g.leader == localPlayer.UserId,
			crewSize = #(g.members or {}),
			seeking = q == "seek" or q == "matched",
			vanBay = bay,
			vanOpen = van ~= nil and van:GetAttribute("Open") == true,
			vanMode = if van then van:GetAttribute("Mode") else nil,
		}, {
			quick = not (flags and flags:GetAttribute("quickCrew") == false),
			invites = not (flags and flags:GetAttribute("invites") == false),
		})
		local infoText = if info == "paused"
			then Strings.QUICK_TOAST.paused
			elseif info == "leader" then Strings.QUICK_INFO_LEADER
			elseif info == "needSolo" then Strings.QUICK_NEED_SOLO
			elseif q == "matched" then Strings.QUICK_TOAST.matched
			else Strings.QUICK_INFO
		corkText(infoText, 12, 6, 438, 44, 16)
		local waiting = tonumber(vans and vans:GetAttribute("QuickWaiting")) or 0
		local open = tonumber(vans and vans:GetAttribute("QuickOpen")) or 0
		corkText(Strings.quickStatus(waiting, open), 12, 128, 438, 22, 14)
		local first: TextButton? = nil
		local LABEL: { [string]: string } = {
			look = Strings.QUICK_LOOK,
			stop = Strings.QUICK_STOP,
			open = Strings.QUICK_OPEN,
			shut = Strings.QUICK_SHUT,
			invite = Strings.QUICK_INVITE,
		}
		local w = 140
		for i, b in buttons do
			local main = b ~= "invite"
			local btn = Ui.button(tapes, {
				Name = "Quick_" .. b,
				Position = UDim2.fromOffset(12 + (i - 1) * (w + 8), 58),
				Size = UDim2.fromOffset(w, TAP + 8),
				BackgroundColor3 = if main then Palette.gold else Palette.marbleHi,
				TextColor3 = Palette.ink,
				TextSize = 16,
				TextWrapped = true,
				Text = LABEL[b] or b,
			}, function()
				if b == "invite" then
					if hud.invite then
						hud.invite()
					end
					return
				end
				local action = LobbyLook.quickAction(b, bay)
				if action and actions.lobbyAction then
					actions.lobbyAction(action)
				end
				-- the server answers with attributes and a toast: redraw when they land
				task.delay(0.5, function()
					if station == "crew" then
						hud.showGarage()
					end
				end)
			end, if main then "UIConfirm" else "UIToggle")
			first = first or btn
		end
		return first
	end

	-- The laptop's advent catch-up list (behind CATCH-UP; the daily card below plays today's vault).
	local function renderLaptop(leader: boolean): TextButton?
		local g = state.garage
		local d = g and g.daily or {}
		local catchUps = d.catchUp or {}
		local first: TextButton? = nil
		if #catchUps == 0 then
			local none = Ui.label(tapes, {
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.new(1, -24, 0, 40),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				TextSize = 18,
				TextColor3 = Palette.ink,
				stroke = false,
				Text = Strings.LAPTOP_NO_CATCH_UP,
			})
			none.Active = false
		end
		setCanvas(#catchUps)
		for i, c in catchUps do
			local card = Ui.button(tapes, {
				BackgroundColor3 = Palette.goldHi,
				TextColor3 = Palette.ink,
				TextSize = 16,
				TextWrapped = true,
				Text = Strings.catchUpCard(
					if c.advent then Strings.advent(c.advent) else Common.dateText(c.day),
					tostring(c.name)
				),
				LayoutOrder = i,
			}, function()
				if not leader then
					hud.toast(Strings.LEADER_PICKS_HEIST)
				else
					actions.selectDaily(c.day)
				end
			end, "UIConfirm")
			pinAt(card, i)
			pin(i)
			first = first or card
		end
		return first
	end

	local function renderDaily()
		local g = state.garage
		local d = g and g.daily
		-- Hidden until the first heist is cleared (the server refuses it too, §7.5).
		if type(d) ~= "table" or d.locked == true then
			daily.Visible = false
			return
		end
		daily.Visible = true
		local when = if d.advent then Strings.advent(d.advent) else Common.dateText(tonumber(d.day) or 0)
		dailyTitle.Text = Strings.dailyVaultOn(when)
		dailyName.Text = string.upper(tostring(d.name or ""))
		local info = {}
		local mod = Strings.MODIFIER[d.modifier or "None"] or ""
		if mod ~= "" then
			table.insert(info, mod)
		end
		if d.clearedToday and d.enabled ~= false then
			table.insert(info, Strings.DONE_TODAY)
		end
		if (tonumber(d.streak) or 0) > 0 then
			table.insert(info, Strings.streak(d.streak))
		end
		if type(d.secondsUntilReset) == "number" then
			table.insert(info, Strings.newIn(Common.durationText(d.secondsUntilReset)))
		end
		dailyInfo.Text = table.concat(info, Strings.SEP)
		local catchUps = #(d.catchUp or {})
		catchBtn.Visible = catchUps > 0
		catchBtn.Text = if catchUpMode then Strings.BACK else Strings.catchUpCount(catchUps)
		if d.enabled == false then
			playDailyBtn.Text = Strings.CLOSED
			playDailyBtn.BackgroundColor3 = Palette.steelLo
		else
			playDailyBtn.Text = if d.clearedToday then Strings.REPLAY else Strings.PLAY
			playDailyBtn.BackgroundColor3 = Palette.gold
		end
	end

	local function renderCrew(g: any)
		for _, c in crewList:GetChildren() do
			if not c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		Ui.label(crewList, { Size = UDim2.new(1, 0, 0, 24), Text = Strings.CREW, LayoutOrder = 0 })
		local inCrew: { [number]: boolean } = {}
		for _, m in g.members or {} do
			inCrew[m.userId] = true
			Ui.label(crewList, {
				Size = UDim2.new(1, 0, 0, 24),
				TextSize = 16,
				TextColor3 = Palette.hueFor(m.seat),
				Text = Strings.crewMember(m.seat, m.name, m.userId == g.leader),
				LayoutOrder = m.seat,
			})
		end
		if g.pending then
			Ui.label(crewList, {
				Size = UDim2.new(1, 0, 0, 40),
				TextSize = 16,
				TextWrapped = true,
				Text = Strings.JOIN_NEXT_HEIST,
				LayoutOrder = 10,
			})
		end
		if #(g.members or {}) > 1 then
			Ui.button(
				crewList,
				{ Size = UDim2.new(1, 0, 0, TAP), Text = Strings.LEAVE_CREW, LayoutOrder = 20 },
				function()
					actions.leave()
				end,
				"UIBack"
			)
		end
		-- LiveFlag kill switch `joinFriend` (ReplicatedStorage.LiveFlags, docs/ANALYTICS.md) hides JOIN.
		local flags = ReplicatedStorage:FindFirstChild("LiveFlags")
		local joinOn = not (flags and flags:GetAttribute("joinFriend") == false)
		local order = 30
		for _, p in Players:GetPlayers() do
			if joinOn and p ~= localPlayer and not inCrew[p.UserId] and isFriend(p.UserId) then
				order += 1
				Ui.button(crewList, {
					Size = UDim2.new(1, 0, 0, TAP),
					TextSize = 16,
					TextWrapped = true,
					Text = Strings.join(p.DisplayName),
					LayoutOrder = order,
				}, function()
					actions.joinFriend(p.UserId)
				end, "UIConfirm")
			end
		end
	end

	function hud.showGarage()
		local g = state.garage
		if not g then
			return
		end
		if g.lobby == true and station == nil then
			-- the hideout: the sheet opens only at a station (Heist/Hideout)
			if garageOpen then
				Ui.hide(garage)
				garageOpen = false
			end
			return
		end
		local wasOpen = garageOpen
		garageOpen = true
		Ui.show(garage)
		ctx.setInHeist(false)
		ctx.runHud.Visible = false
		Ui.hide(ctx.deck.panel)
		Ui.hide(ctx.results.card)
		Ui.hide(ctx.deck.readyWait)
		ctx.msg.pauseChip.Visible = false
		Ui.hide(ctx.msg.menuSheet)
		Ui.hide(ctx.msg.preparing)
		clearTapes()
		local leader = g.leader == localPlayer.UserId
		local catchUps = g.daily and g.daily.catchUp and #g.daily.catchUp or 0
		if catchUpMode and catchUps == 0 then
			catchUpMode = false
		end
		local first: TextButton?
		if station == "laptop" then
			-- the board by default; CATCH-UP (the daily card) swaps in the advent catch-up list
			garageTitle.Text = if catchUpMode then Strings.LAPTOP else Strings.BOARD_TITLE
			if catchUpMode then
				first = renderLaptop(leader)
			else
				renderBoard()
			end
		elseif station == "crew" then
			catchUpMode = false
			garageTitle.Text = Strings.QUICK_CREW
			first = renderQuick()
		else
			if station == "board" then
				catchUpMode = false
			end
			garageTitle.Text = if catchUpMode then Strings.ADVENT_CATCH_UP else Strings.JOB_BOARD
			first = if catchUpMode then renderCatchUp(leader) else renderTapes(leader)
		end
		renderDaily()
		if station == "board" or station == "crew" then
			daily.Visible = false -- the daily vault lives on the laptop
		end
		backBtn.Visible = station ~= nil
		crewBox.Size = UDim2.fromOffset(200, if station ~= nil then CREW_FULL - TAP - 8 else CREW_FULL)
		renderCrew(g)
		if first then
			Common.selectFor(first)
		end
		-- Advent window: sleigh bells once per garage visit (docs/AUDIO.md §9 item 23).
		if not wasOpen and g.daily and g.daily.advent and not g.daily.clearedToday then
			Sound.play("SleighBells")
		end
	end

	function hud.hideGarage()
		Ui.hide(garage)
		garageOpen = false
		station = nil
		onBack = nil
	end

	-- The hideout: a station opens the sheet as the job board ("board") or the laptop ("laptop"); back() is BACK.
	function garageUi.openStation(mode: string, back: () -> ())
		station = mode
		onBack = back
		catchUpMode = false -- the laptop opens on its board
		garageOpen = false -- a fresh open (its sleigh bells)
		hud.showGarage()
	end

	-- Live redraws while a station shows server state: the board's rows (laptop) and your Quick Crew state (sign).
	local function redrawIf(mode: string)
		if station == mode and garageOpen and not (mode == "laptop" and catchUpMode) then
			hud.showGarage()
		end
	end
	if localPlayer then -- none when the HUD is built for an engine check on a server (tests/client_engine.luau)
		localPlayer:GetAttributeChangedSignal("QuickCrew"):Connect(function()
			redrawIf("crew")
		end)
	end
	task.spawn(function()
		local f = ReplicatedStorage:WaitForChild("EH_HaulBoard", 60)
		if f then
			f:GetAttributeChangedSignal("Rows"):Connect(function()
				redrawIf("laptop")
			end)
		end
	end)

	function garageUi.closeStation()
		station = nil
		onBack = nil
		Ui.hide(garage)
		garageOpen = false
	end

	function garageUi.isOpen(): boolean
		return garageOpen
	end

	-- A run starts: the garage closes (it opens fresh, with its sleigh bells, next time).
	function garageUi.close()
		Ui.hide(garage)
		garageOpen = false
	end

	return garageUi
end

return Garage
