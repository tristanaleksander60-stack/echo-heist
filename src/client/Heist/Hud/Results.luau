--!strict
-- Hud/Results: the job sheet (PLAN_STEAM_PLUS §3.2, §4.3 U5, §5 "Results"; POLISH §4.2 "Results v2
-- timeline"; premium F5: anticipation, reveal, payoff, settle). Timings are Config.Ui.SHEET:
--   0.00  the sheet slides in (Ui.show + a short slide; reduced motion: it appears)
--   0.25  the haul counts up (Quad Out, 0.35-1.0 s, Shared/Heist/CrewBoard.countValue) and pops
--   0.70  one line per goal, each struck through with a pencil line when it was met
--   0.90  three rubber stamps land with ink rings, MEDAL_STAMP_GAP apart (the pitch ladder); the first
--         time a star can be earned its stamp says why, with the level's real numbers ("HAUL: $1,000
--         stolen", "CREW: 2 clones or fewer", "CLEAN: never caught"; WALKTHROUGH S7). A star earned with
--         its reason showing is remembered (settings seenStar*, saved through Data.SetSetting)
--   1.60  "3 clones · 4 runs · 1:52"
--   1.90  the trophy flies to the van (heist complete)
--   2.10  the buttons slide up last and take input BUTTON_GUARD (0.3 s) later
-- What was saved stays under it (in a Studio play test without DataStores a neutral "not saved" chip,
-- PLAN S6), and the leader gets REPLAY / NEXT / GARAGE.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local Sound = require(Heist:WaitForChild("Sound"))
local Theme = require(Heist:WaitForChild("Theme"))
local Ui = require(Heist:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local AU = Config.Audio
local U = Config.Ui
local S = U.SHEET
local CU = U.COUNT_UP
local TAP = Ui.TAP
local localPlayer = Players.LocalPlayer
local IS_STUDIO = RunService:IsStudio()

local SHEET_W = HudLayout.RESULTS.w
local ROW_Y, ROW_H, ROW_GAP = 70, 26, 2
local LINE_X, LINE_W = 18, 270
local STAMP_X, STAMP_W = 296, 170
local PAPER = Palette.marbleHi
local INK = Palette.ink
local PENCIL = Color3.new(S.PENCIL[1], S.PENCIL[2], S.PENCIL[3])

local Results = {}

function Results.build(ctx: any): any
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local root = ctx.root
	local res = {}

	local results = Ui.panel(root, {
		Name = "Results",
		BackgroundColor3 = PAPER,
		Visible = false,
		ZIndex = 10,
	}, INK)
	Common.place(results, HudLayout.RESULTS)
	Common.sheetBlocksTouch("results", results)
	res.card = results
	local restPosition = results.Position

	-- Header: the job's name, and the van the trophy flies to.
	local kicker = Ui.label(results, {
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.new(1, -72, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = U.TYPE_SCALE[1],
		TextColor3 = Palette.steelLo,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = Strings.JOB_SHEET,
		ZIndex = 11,
	})
	local van = Ui.frame(results, {
		Name = "Van",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 4),
		Size = UDim2.fromOffset(U.ICON_SIZE, U.ICON_SIZE),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	Icons.attach(van, "van", { Size = UDim2.fromScale(1, 1), ImageColor3 = INK, ZIndex = 12 })

	local resTitle = Ui.display(results, {
		Position = UDim2.fromOffset(14, 24),
		Size = UDim2.fromOffset(280, 42),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = U.TYPE_SCALE[4],
		Text = Strings.HEIST_COMPLETE,
		ZIndex = 11,
	})
	Ui.fit(resTitle, U.TYPE_SCALE[4], U.TYPE_SCALE[2])
	local resHaul = Ui.label(results, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 24),
		Size = UDim2.fromOffset(160, 42),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = U.TYPE_SCALE[4],
		TextColor3 = Palette.gold,
		Text = Ui.money(0),
		ZIndex = 11,
	})

	-- One row per goal: the line (struck in pencil when met) and its stamp.
	type Row = { line: TextLabel, strike: Frame, stamp: TextLabel, ring: Frame }
	local rows: { Row } = {}
	for i = 1, 3 do
		local y = ROW_Y + (i - 1) * (ROW_H + ROW_GAP)
		local line = Ui.label(results, {
			Name = "Goal" .. i,
			Position = UDim2.fromOffset(LINE_X, y),
			Size = UDim2.fromOffset(LINE_W, ROW_H),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = U.TYPE_SCALE[2],
			TextColor3 = INK,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "",
			ZIndex = 11,
		})
		local strike = Ui.frame(line, {
			Name = "Pencil",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -2, 0.5, 1),
			Size = UDim2.fromOffset(0, 2),
			BackgroundColor3 = PENCIL,
			BackgroundTransparency = 0.1,
			Rotation = -1,
			ZIndex = 12,
			Active = false,
		})
		local ring = Ui.frame(results, {
			Name = "Ring" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(STAMP_X + STAMP_W / 2, y + ROW_H / 2),
			Size = UDim2.fromOffset(STAMP_W * 0.6, STAMP_W * 0.6),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 11,
			Active = false,
		})
		Ui.pill(ring)
		Ui.stroke(ring, Palette.gold, Theme.STROKE * 2)
		local stamp = Ui.label(results, {
			Name = "Stamp" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(STAMP_X + STAMP_W / 2, y + ROW_H / 2),
			Size = UDim2.fromOffset(STAMP_W, ROW_H),
			FontFace = Ui.FONT_DISPLAY,
			TextSize = U.TYPE_SCALE[2],
			RichText = true,
			Text = "",
			Visible = false,
			ZIndex = 13,
		})
		Ui.fit(stamp, U.TYPE_SCALE[2], U.TYPE_SCALE[1])
		stamp.BackgroundColor3 = PAPER
		stamp.BackgroundTransparency = 0
		Ui.corner(stamp)
		Ui.stroke(stamp, Palette.gold, Theme.STROKE)
		rows[i] = { line = line, strike = strike, stamp = stamp, ring = ring }
	end

	local resLine = Ui.label(results, {
		Position = UDim2.fromOffset(0, 160),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = U.TYPE_SCALE[2],
		TextColor3 = INK,
		Text = "",
		ZIndex = 11,
	})
	local resAward = Ui.label(results, {
		Position = UDim2.fromOffset(12, 186),
		Size = UDim2.new(1, -24, 0, 30),
		TextSize = U.TYPE_SCALE[1],
		TextWrapped = true,
		TextColor3 = Palette.goldLo,
		Text = "",
		ZIndex = 11,
	})
	Ui.fit(resAward, U.TYPE_SCALE[1], U.TYPE_SCALE[1])
	-- Studio play tests have no DataStores (DataService goes offline): a small neutral chip
	-- instead of "Couldn't save this one." Live servers never take this path.
	local studioChip = Ui.frame(results, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 188),
		Size = UDim2.fromOffset(300, 28),
		BackgroundColor3 = Palette.inkHi,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 11,
	})
	Ui.corner(studioChip, 14)
	Ui.stroke(studioChip, Palette.steel, 1)
	Ui.label(studioChip, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 16,
		TextColor3 = Palette.steelHi,
		Text = Strings.STUDIO_NOT_SAVED,
		ZIndex = 12,
	})

	-- Buttons last (F5): hidden until BUTTONS_AT, then live BUTTON_GUARD later.
	local resButtons = Ui.frame(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, TAP),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	local buttonsAt = resButtons.Position
	local buttonsLiveAt = math.huge
	local function live(): boolean
		return os.clock() >= buttonsLiveAt
	end
	local resLayout = Instance.new("UIListLayout")
	resLayout.FillDirection = Enum.FillDirection.Horizontal
	resLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	resLayout.Padding = UDim.new(0, 10)
	resLayout.SortOrder = Enum.SortOrder.LayoutOrder
	resLayout.Parent = resButtons
	local replayBtn = Ui.button(
		resButtons,
		{ Size = UDim2.fromOffset(136, TAP), Text = Strings.REPLAY, LayoutOrder = 1 },
		function()
			local over = state.over
			if not over or not live() then
				return
			end
			if over.kind == "daily" then
				actions.selectDaily(over.daily and over.daily.day or nil)
			else
				actions.selectLevel(over.levelIndex)
			end
		end,
		"UIConfirm"
	)
	Ui.iconWord(replayBtn, "replay", "left")
	local nextBtn = Ui.button(resButtons, {
		Size = UDim2.fromOffset(136, TAP),
		Text = Strings.NEXT,
		LayoutOrder = 2,
		BackgroundColor3 = Palette.CLONE_HUES[1],
	}, function()
		local over = state.over
		local nextIndex = over and tonumber(over.nextIndex) or 0
		if nextIndex > 0 and live() then
			actions.selectLevel(nextIndex)
		end
	end, "UIConfirm")
	local garageBtn = Ui.button(
		resButtons,
		{ Size = UDim2.fromOffset(136, TAP), Text = Strings.GARAGE, LayoutOrder = 3 },
		function()
			if live() then
				actions.leave()
			end
		end,
		"UIBack"
	)
	Ui.iconWord(nextBtn, "play", "left")
	Ui.iconWord(garageBtn, "van", "left")
	local resWait = Ui.label(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(TAP + 14)),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		TextColor3 = INK,
		Text = "",
		ZIndex = 11,
	})

	-- What the save says: medals, stars, unlocks, cash; or that it failed.
	local function awardText(kind: string, award: any): string
		if award and award.ok and type(award.data) == "table" then
			local d = award.data
			local parts = {}
			if kind == "daily" then
				if (tonumber(d.streak) or 0) > 0 then
					table.insert(parts, Strings.streak(d.streak))
				end
				if d.ornament then
					table.insert(parts, Strings.NEW_ORNAMENT)
				end
				if (tonumber(d.stars) or 0) > 0 then
					table.insert(parts, Strings.plusStars(d.stars))
				end
			else
				local medals = d.newMedals or {}
				if #medals > 0 then
					table.insert(parts, Strings.newMedals(table.concat(medals, ", ")))
				end
				if (tonumber(d.starsGained) or 0) > 0 then
					table.insert(parts, Strings.plusStars(d.starsGained))
				end
				if type(d.unlocked) == "table" and #d.unlocked > 0 then
					table.insert(parts, Strings.NEW_HEIST_UNLOCKED)
				end
			end
			if (tonumber(d.cash) or 0) > 0 then
				table.insert(parts, Strings.plusCash(Ui.money(d.cash)))
			end
			return table.concat(parts, Strings.SEP)
		elseif award and not award.ok then
			return Strings.SAVE_FAILED -- the code stays in the server log
		end
		return ""
	end

	-- Saving is unavailable because this is a Studio play test (DataService offline).
	local function studioUnsaved(award: any): boolean
		if not IS_STUDIO then
			return false
		end
		if ReplicatedStorage:GetAttribute("DataOffline") == true then
			return true
		end
		return type(award) == "table" and award.ok == false and award.code == "NotReady"
	end

	---------------------------------------------------------------------------
	-- The timeline
	---------------------------------------------------------------------------
	local sheetToken = 0
	local function at(seconds: number, fn: () -> ())
		local token = sheetToken
		task.delay(seconds, function()
			if token == sheetToken and Ui.isShown(results) then
				fn()
			end
		end)
	end

	-- The haul counts up from $0, ticking, and pops when it lands (premium D10).
	local function countHaul(to: number)
		local seconds = CrewBoard.countSeconds(0, to)
		local t0 = os.clock()
		local token = sheetToken
		local ticks = 0
		local conn: RBXScriptConnection? = nil
		conn = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - t0
			if token ~= sheetToken then
				if conn then
					conn:Disconnect()
				end
				return
			end
			resHaul.Text = Ui.money(CrewBoard.countValue(0, to, elapsed, seconds))
			local want = math.floor(elapsed / CU.TICK)
			if want > ticks and elapsed < seconds then
				ticks = want
				Sound.play("CountTick", { step = math.min(ticks - 1, #AU.COUNT_UP_STEPS - 1) })
			end
			if elapsed >= seconds then
				if conn then
					conn:Disconnect()
				end
				Sound.play("CountDone")
				Ui.pop(resHaul, CU.END_POP)
			end
		end)
	end

	local function strikeLine(row: Row)
		local w = math.min(LINE_W, row.line.TextBounds.X + 4)
		if Ui.reducedMotion() then
			row.strike.Size = UDim2.fromOffset(w, 2)
		else
			Motion.timed(row.strike, S.STRIKE_SECONDS, { Size = UDim2.fromOffset(w, 2) }, "feedback")
		end
	end

	-- Stamp land (POLISH §4.1): UIScale STAMP_FROM -> 0.92 -> 1, the tilt settles, an ink ring grows
	-- and fades behind it. Reduced motion: it appears.
	local function landStamp(row: Row, color: Color3, pitchStep: number)
		local stamp = row.stamp
		stamp.Visible = true
		Sound.play("RunStamp", { pitch = 1 + pitchStep * AU.MEDAL_PITCH_STEP })
		if Ui.reducedMotion() then
			stamp.Rotation = 0
			return
		end
		local scale = Ui.scaleOf(stamp)
		scale.Scale = S.STAMP_FROM
		stamp.Rotation = S.STAMP_ROTATION - 3
		local down = Motion.timed(scale, Motion.seconds("feedback"), { Scale = U.PRESS_SCALE }, "exit")
		down.Completed:Once(function()
			Motion.tween(scale, "pop", { Scale = 1 })
		end)
		Motion.tween(stamp, "emphasis", { Rotation = S.STAMP_ROTATION })
		local ring = row.ring
		local rim = ring:FindFirstChild("Rim")
		if rim and rim:IsA("UIStroke") then
			rim.Color = color
			rim.Transparency = 0
			Motion.timed(rim, S.RING_SECONDS, { Transparency = 1 }, "feedback")
		end
		local rs = Ui.scaleOf(ring)
		rs.Scale = S.RING_FROM
		ring.Visible = true
		local grow = Motion.timed(rs, S.RING_SECONDS, { Scale = S.RING_TO }, "feedback")
		grow.Completed:Once(function()
			ring.Visible = false
		end)
	end

	-- The trophy (a crown) flies from the title to the van icon on an arc, then the van pops.
	local function flyTrophy()
		local icon = Icons.make(results, "crown", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(U.ICON_SIZE + 8, U.ICON_SIZE + 8),
			ImageColor3 = Palette.gold,
			ZIndex = 20,
		})
		if not icon then
			Ui.pop(van)
			return
		end
		local ax, ay = 14 + resTitle.TextBounds.X / 2, 45
		local bx, by = SHEET_W - 14 - U.ICON_SIZE / 2, 4 + U.ICON_SIZE / 2
		icon.Position = UDim2.fromOffset(ax, ay)
		if Ui.reducedMotion() then
			icon:Destroy()
			Ui.pop(van)
			return
		end
		local u = Instance.new("NumberValue")
		u.Value = 0
		u.Changed:Connect(function(v: number)
			local x, y = CrewBoard.arc(ax, ay, bx, by, 40, v)
			icon.Position = UDim2.fromOffset(x, y)
		end)
		local tw = Motion.timed(u, S.TROPHY_SECONDS, { Value = 1 }, "exit")
		tw.Completed:Once(function()
			icon:Destroy()
			u:Destroy()
			Ui.pop(van, CU.END_POP)
			Sound.play("CountDone")
		end)
	end

	local function showButtons()
		resButtons.Visible = true
		if Ui.reducedMotion() then
			resButtons.Position = buttonsAt
		else
			resButtons.Position = buttonsAt + UDim2.fromOffset(0, 12)
			Motion.tween(resButtons, "enter", { Position = buttonsAt })
		end
		buttonsLiveAt = os.clock() + S.BUTTON_GUARD
		hud.refreshResults()
	end

	function hud.onOver(payload: any)
		local over = payload.result
		if type(over) ~= "table" then
			return
		end
		state.over = over
		state.overNext = payload.next
		ctx.setInHeist(true)
		ctx.msg.setSpectate("")
		sheetToken += 1
		buttonsLiveAt = math.huge
		resButtons.Visible = false
		Ui.show(results)
		-- The sheet slides in (on top of the kit's enter scale).
		if Ui.reducedMotion() then
			results.Position = restPosition
		else
			results.Position = restPosition + UDim2.fromOffset(0, S.SLIDE)
			Motion.tween(results, "enter", { Position = restPosition })
		end
		Ui.hide(ctx.deck.panel)
		Ui.hide(ctx.deck.readyWait)
		ctx.runHud.Visible = false
		ctx.msg.pauseChip.Visible = false
		Ui.hide(ctx.msg.menuSheet)
		ctx.msg.setHidden(false)
		local kind = over.kind or "story"
		local st = over.stars or {}
		kicker.Text = if over.name then Strings.jobSheet(tostring(over.name)) else Strings.JOB_SHEET
		resTitle.Rotation = if Ui.reducedMotion() then 0 else -3

		-- Title and stamps per kind (the haul is the big number; its goal is on the first line).
		local stampText: { string } = {}
		local stampOn: { boolean } = {}
		local stampColor: { Color3 } = {}
		local shown: { [string]: boolean } = {}
		if kind == "party" then
			-- A party cannot fail: Dawn is just its end (never a plain amber "DAWN").
			local tiersMet = tonumber(over.tierMet) or 0
			resTitle.Text = Strings.partyOver(tiersMet)
			resTitle.TextColor3 = if tiersMet > 0 then Palette.ok else Palette.gold
			local tiers = over.tiers or {}
			local met = st.tiers or {}
			for i = 1, 3 do
				stampText[i] = Strings.stamp(Ui.money(tonumber(tiers[i]) or 0), met[i] == true)
				stampOn[i] = met[i] == true and tiers[i] ~= nil
			end
		else
			if kind == "daily" then
				resTitle.Text = if over.complete
					then Strings.VAULT_CLEARED
					elseif over.reason == "Dawn" then Strings.DAWN
					else Strings.VAULT_OVER
			else
				resTitle.Text = if over.complete
					then Strings.HEIST_COMPLETE
					elseif over.reason == "Dawn" then Strings.DAWN
					else Strings.HEIST_OVER
			end
			resTitle.TextColor3 = if over.complete then Palette.ok else Palette.amber
			local seen = {}
			for _, key in CrewBoard.SEEN_KEY do
				seen[key] = Settings.get(key)
			end
			shown = CrewBoard.reasonsToShow(over, seen)
			local medal = { haul = Strings.MEDAL_HAUL, crew = Strings.MEDAL_CREW, clean = Strings.MEDAL_CLEAN }
			for i, star in CrewBoard.STARS do
				local on = st[star] == true
				stampOn[i] = on
				stampText[i] = if shown[star] then CrewBoard.stampReason(star, over) else Strings.stamp(medal[star], on)
			end
		end
		resHaul.Text = Ui.money(0)

		-- Goal lines and stamps, all hidden until their beat.
		local lines = CrewBoard.goalLines(over)
		for i, row in rows do
			local goalLine = lines[i]
			row.line.Text = if goalLine then goalLine.text else ""
			row.line.TextColor3 = if goalLine and goalLine.met then INK else Palette.steelLo
			row.strike.Size = UDim2.fromOffset(0, 2)
			row.stamp.Visible = false
			row.ring.Visible = false
			row.stamp.Text = stampText[i] or ""
			stampColor[i] = if stampOn[i] then Palette.goldLo else Palette.tapeGrey
			row.stamp.TextColor3 = stampColor[i]
			local rim = row.stamp:FindFirstChild("Rim")
			if rim and rim:IsA("UIStroke") then
				rim.Color = stampColor[i]
			end
		end

		local clones = over.clonesUsed or 0
		local bits = {}
		local ofMe = tonumber(over.ofMe) or 0
		if ofMe >= Config.Sim.SWARM_OF_ME then
			table.insert(bits, Strings.ofMe(ofMe))
		end
		table.insert(bits, Strings.clones(clones))
		table.insert(bits, Strings.runs(over.runs or 0))
		table.insert(bits, Ui.clock(over.totalTime or 0))
		resLine.Text = ""
		local summary = table.concat(bits, Strings.SEP)
		local unsaved = studioUnsaved(payload.award)
		studioChip.Visible = unsaved
		resAward.Text = if unsaved then "" else awardText(kind, payload.award)

		-- Beats.
		at(S.HAUL_AT, function()
			countHaul(tonumber(over.banked) or 0)
		end)
		for i, row in rows do
			local goalLine = lines[i]
			if goalLine and goalLine.met then
				at(S.LINE_AT + (i - 1) * S.LINE_GAP, function()
					strikeLine(row)
				end)
			end
			if stampText[i] and stampText[i] ~= "" then
				at(S.STAMP_AT + (i - 1) * AU.MEDAL_STAMP_GAP, function()
					landStamp(row, stampColor[i], i)
				end)
			end
		end
		at(S.LINE_AT_SUMMARY, function()
			resLine.Text = summary
		end)
		if over.complete then
			at(S.TROPHY_AT, flyTrophy)
		end
		at(S.BUTTONS_AT, showButtons)
		-- Stars earned with their reason showing are learnt: next time they just stamp.
		for _, key in CrewBoard.newlySeen(over, shown) do
			Settings.set(key, true)
		end
	end

	-- Leader buttons on the results card (also when the leader changes while it is up).
	-- NEXT only when the next heist is open for you; else why (§5.2: "2 more stars").
	function hud.refreshResults()
		local over = state.over
		if not over or not results.Visible then
			return
		end
		local kind = over.kind or "story"
		local leader = over.leader == localPlayer.UserId
		local nextIndex = tonumber(over.nextIndex) or 0
		local nx = state.overNext
		local nextOpen = nx == nil or nx.unlocked ~= false
		local wantsNext = nextIndex > 0 and (over.complete == true or kind == "party")
		replayBtn.Visible = leader
		nextBtn.Visible = leader and wantsNext and nextOpen
		if wantsNext and not nextOpen and type(nx) == "table" then
			local stars = tonumber(nx.starsNeeded) or 0
			resWait.Text = if stars > 0 then Strings.starsOpenNext(stars) else Strings.WIN_TO_OPEN_NEXT
		elseif not leader then
			resWait.Text = Strings.LEADER_PICKS_NEXT
		else
			resWait.Text = ""
		end
		resWait.Visible = resButtons.Visible
		garageBtn.Text = if leader then Strings.GARAGE else Strings.LEAVE
		if resButtons.Visible then
			Common.selectFor(if nextBtn.Visible then nextBtn else garageBtn)
		end
	end

	return res
end

return Results
