--!strict
-- Hud/Garage: heists in play order (the party break tagged, why a heist is locked), the
-- daily vault card with streak and modifier once the first heist is cleared, advent
-- catch-up, the crew and JOIN for friends in the server (§3.3, §5.3, §7.4). Roblox's
-- player list comes back here (it is hidden during heists, PLAN S8).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeistShared = Shared:WaitForChild("Heist")
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Sound = require(script.Parent.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local TAP = Ui.TAP
local localPlayer = Players.LocalPlayer

local Garage = {}

function Garage.build(ctx: any): any
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local root = ctx.root
	local garageUi = {}

	local garage = Ui.frame(root, {
		Name = "Garage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(700, 326),
		Visible = false,
	})
	Ui.corner(garage, 18)
	garageUi.frame = garage
	local garageTitle = Ui.label(garage, {
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.fromOffset(440, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 26,
		Text = Strings.PICK_A_HEIST,
	})
	local tapes = Instance.new("ScrollingFrame")
	tapes.Name = "Tapes"
	tapes.Position = UDim2.fromOffset(14, 44)
	tapes.Size = UDim2.fromOffset(462, 156)
	tapes.BackgroundTransparency = 1
	tapes.BorderSizePixel = 0
	tapes.ScrollingDirection = Enum.ScrollingDirection.Y
	tapes.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tapes.CanvasSize = UDim2.fromScale(0, 0)
	tapes.ScrollBarThickness = 4
	tapes.Parent = garage
	local tapeGrid = Instance.new("UIGridLayout")
	tapeGrid.CellSize = UDim2.fromOffset(146, 88)
	tapeGrid.CellPadding = UDim2.fromOffset(8, 8)
	tapeGrid.SortOrder = Enum.SortOrder.LayoutOrder
	tapeGrid.Parent = tapes

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

	local crewBox = Ui.frame(garage, {
		Position = UDim2.fromOffset(486, 44),
		Size = UDim2.fromOffset(200, 270),
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

	local function clearTapes()
		for _, c in tapes:GetChildren() do
			if c:IsA("TextButton") then
				c:Destroy()
			end
		end
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

	local function renderTapes(leader: boolean): TextButton?
		local g = state.garage
		local first: TextButton? = nil
		for _, lv in g.levels or {} do
			local party = lv.kind == "party"
			local tag = if party
				then Strings.partyTag(tonumber(lv.cap) or 8)
				else Strings.runSeconds(tonumber(lv.runSeconds) or 0)
			local stars = tonumber(lv.starsNeeded) or 0
			local lockText = if lv.needsClear ~= nil
				then Strings.lockClear(tapeName(lv.needsClear))
				elseif stars > 0 then Strings.lockStars(stars)
				else Strings.LOCKED
			-- A party level's medals are its haul tiers; a story level's are Haul / Crew / Clean.
			local status = if lv.unlocked then Strings.heistStars(#(lv.medals or {})) else lockText
			local b = Ui.button(tapes, {
				BackgroundColor3 = if not lv.unlocked
					then Palette.plumHi
					elseif party then Palette.goldHi
					else Palette.steelHi,
				TextColor3 = Palette.ink,
				TextSize = 16,
				TextWrapped = true,
				Text = Strings.heistCard(lv.index, tostring(lv.name), tag, status),
				LayoutOrder = lv.index,
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
			first = first or b
		end
		return first
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
		for i, c in d.catchUp or {} do
			Ui.button(tapes, {
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
		end
		return back
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
		local wasOpen = garageOpen
		garageOpen = true
		garage.Visible = true
		ctx.setInHeist(false)
		ctx.runHud.Visible = false
		ctx.deck.panel.Visible = false
		ctx.results.card.Visible = false
		ctx.deck.readyWait.Visible = false
		ctx.msg.pauseChip.Visible = false
		ctx.msg.menuSheet.Visible = false
		ctx.msg.preparing.Visible = false
		clearTapes()
		local leader = g.leader == localPlayer.UserId
		local catchUps = g.daily and g.daily.catchUp and #g.daily.catchUp or 0
		if catchUpMode and catchUps == 0 then
			catchUpMode = false
		end
		garageTitle.Text = if catchUpMode then Strings.ADVENT_CATCH_UP else Strings.PICK_A_HEIST
		local first = if catchUpMode then renderCatchUp(leader) else renderTapes(leader)
		renderDaily()
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
		garage.Visible = false
		garageOpen = false
	end

	-- A run starts: the garage closes (it opens fresh, with its sleigh bells, next time).
	function garageUi.close()
		garage.Visible = false
		garageOpen = false
	end

	return garageUi
end

return Garage
