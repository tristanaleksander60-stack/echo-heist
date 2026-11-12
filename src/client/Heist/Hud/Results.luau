--!strict
-- Hud/Results: the results card (§7.3 "heist complete", §6.6): title, haul, three
-- stamps landing 0.25 s apart, the run line, what was saved, and the leader's
-- REPLAY / NEXT / GARAGE.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Sound = require(script.Parent.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local AU = Config.Audio
local TAP = Ui.TAP
local localPlayer = Players.LocalPlayer

local Results = {}

function Results.build(ctx: any): any
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local root = ctx.root
	local res = {}

	local results = Ui.frame(root, {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 326),
		Visible = false,
		ZIndex = 10,
	})
	Ui.corner(results, 18)
	res.card = results
	local resTitle = Ui.label(results, {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 34,
		Text = Strings.HEIST_COMPLETE,
		ZIndex = 11,
	})
	local resHaul = Ui.label(results, {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 28,
		TextColor3 = Palette.gold,
		Text = Ui.money(0),
		ZIndex = 11,
	})
	local stampRow = Ui.frame(results, {
		Position = UDim2.fromOffset(16, 94),
		Size = UDim2.new(1, -32, 0, 50),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
	local stampLayout = Instance.new("UIListLayout")
	stampLayout.FillDirection = Enum.FillDirection.Horizontal
	stampLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stampLayout.Padding = UDim.new(0, 10)
	stampLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stampLayout.Parent = stampRow
	local stamps: { TextLabel } = {}
	for i = 1, 3 do
		local s = Ui.label(stampRow, {
			Size = UDim2.fromOffset(136, 46),
			TextSize = 20,
			Text = "",
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
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 20,
		Text = "",
		ZIndex = 11,
	})
	local resAward = Ui.label(results, {
		Position = UDim2.fromOffset(10, 174),
		Size = UDim2.new(1, -20, 0, 40),
		TextSize = 18,
		TextWrapped = true,
		TextColor3 = Palette.goldHi,
		Text = "",
		ZIndex = 11,
	})
	local resButtons = Ui.frame(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -24, 0, TAP),
		BackgroundTransparency = 1,
		ZIndex = 11,
	})
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
			if not over then
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
	local nextBtn = Ui.button(resButtons, {
		Size = UDim2.fromOffset(136, TAP),
		Text = Strings.NEXT,
		LayoutOrder = 2,
		BackgroundColor3 = Palette.CLONE_HUES[1],
	}, function()
		local over = state.over
		local nextIndex = over and tonumber(over.nextIndex) or 0
		if nextIndex > 0 then
			actions.selectLevel(nextIndex)
		end
	end, "UIConfirm")
	local garageBtn = Ui.button(
		resButtons,
		{ Size = UDim2.fromOffset(136, TAP), Text = Strings.GARAGE, LayoutOrder = 3 },
		function()
			actions.leave()
		end,
		"UIBack"
	)
	local resWait = Ui.label(results, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(TAP + 14)),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		Text = "",
		ZIndex = 11,
	})

	local function setStamp(i: number, text: string, on: boolean)
		local s = stamps[i]
		s.Text = Strings.stamp(text, on)
		s.TextColor3 = if on then Palette.gold else Palette.tapeGrey
		s.Visible = false
	end

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
					table.insert(parts, Strings.NEW_TAPE_UNLOCKED)
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

	function hud.onOver(payload: any)
		local over = payload.result
		if type(over) ~= "table" then
			return
		end
		state.over = over
		state.overNext = payload.next
		results.Visible = true
		ctx.deck.panel.Visible = false
		ctx.deck.readyWait.Visible = false
		ctx.runHud.Visible = false
		ctx.msg.pauseChip.Visible = false
		ctx.msg.menuSheet.Visible = false
		ctx.msg.setHidden(false)
		local kind = over.kind or "story"
		local st = over.stars or {}
		if kind == "party" then
			-- A party cannot fail: Dawn is just its end (never a plain amber "DAWN").
			local tiersMet = tonumber(over.tierMet) or 0
			resTitle.Text = Strings.partyOver(tiersMet)
			resTitle.TextColor3 = if tiersMet > 0 then Palette.ok else Palette.gold
			resHaul.Text = Ui.money(over.banked)
			local tiers = over.tiers or {}
			local met = st.tiers or {}
			for i = 1, 3 do
				setStamp(i, Ui.money(tonumber(tiers[i]) or 0), met[i] == true)
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
			resHaul.Text = Strings.lootOfGoal(Ui.money(over.banked), Ui.money(over.goal))
			setStamp(1, Strings.MEDAL_HAUL, st.haul == true)
			setStamp(2, Strings.MEDAL_CREW, st.crew == true)
			setStamp(3, Strings.MEDAL_CLEAN, st.clean == true)
		end
		-- Stamps land 0.25 s apart, each a little higher (docs/AUDIO.md §9 item 21).
		for i, s in stamps do
			local show = kind ~= "party" or (over.tiers and over.tiers[i] ~= nil)
			task.delay(AU.MEDAL_STAMP_GAP * i, function()
				if results.Visible and show then
					s.Visible = true
					Ui.pop(s)
					Sound.play("RunStamp", { pitch = 1 + i * AU.MEDAL_PITCH_STEP })
				end
			end)
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
		resLine.Text = table.concat(bits, Strings.SEP)
		resAward.Text = awardText(kind, payload.award)
		hud.refreshResults()
	end

	-- Leader buttons on the results card (also when the leader changes while it is up).
	-- NEXT only when the next tape is open for you; else why (§5.2: "2 more ★ opens it").
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
			resWait.Text = if stars > 0 then Strings.starsOpenNext(stars) else Strings.CLEAR_TO_OPEN_NEXT
		elseif not leader then
			resWait.Text = Strings.LEADER_PICKS_NEXT
		else
			resWait.Text = ""
		end
		garageBtn.Text = if leader then Strings.GARAGE else Strings.LEAVE
		Common.selectFor(if nextBtn.Visible then nextBtn else garageBtn)
	end

	return res
end

return Results
