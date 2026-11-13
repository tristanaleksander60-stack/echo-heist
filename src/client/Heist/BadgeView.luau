--!strict
-- Heist/BadgeView: the client half of the badges (BADGES track; Shared/Heist/Badges, server Data/Awards).
--   * BADGE UNLOCKED: a card under the top bar with the badge's icon (its uploaded image, or the tier ring with the
--     badge's short mark while the icon id is 0), the name and "3 OF 8 BADGES". The server writes the player
--     attribute BadgeToast ("<key>#<n>") when it decides you earned a badge; cards queue, one at a time.
--   * The boss: ReplicatedStorage.BossUserId (non-zero while the owner or a staff member is in the server) shows
--     THE BOSS IS HERE! on the message rail on every screen (not the boss's own), and every Player with the
--     attribute Boss gets a gold THE BOSS pill over their Rookie's head (not over your own: first person).
-- No remotes: everything comes from attributes the server writes. Numbers in Config.Badges, words in Strings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local Badges = require(HeistShared:WaitForChild("Badges"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Motion = require(script.Parent:WaitForChild("Motion"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local B = Config.Badges

local BadgeView = {}

export type Opts = {
	localPlayer: Instance?, -- default Players.LocalPlayer (tests pass a stand-in with attributes)
	store: Instance?, -- where BossUserId lives (default ReplicatedStorage)
	players: (() -> { any })?, -- default Players:GetPlayers()
	reduced: (() -> boolean)?, -- reduced motion: no slide, just show
}

local function tierColour(tier: string): Color3
	return Color3.fromHex(B.TIERS[tier] or B.TIERS.bronze)
end

-- The icon: the uploaded badge image, or the tier ring with the badge's mark (the fallback while the id is 0).
local function buildIcon(parent: Instance, def: Badges.Def, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "BadgeIcon"
	holder.Size = UDim2.fromOffset(size, size)
	holder.BackgroundColor3 = tierColour(def.tier)
	holder.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = holder
	local inner = Instance.new("Frame")
	inner.Name = "Face"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.84, 0.84)
	inner.BackgroundColor3 = Palette.ink
	inner.BorderSizePixel = 0
	local innerRound = Instance.new("UICorner")
	innerRound.CornerRadius = UDim.new(0.5, 0)
	innerRound.Parent = inner
	inner.Parent = holder
	local icon = Badges.iconOf(def.key)
	if icon > 0 then
		local img = Instance.new("ImageLabel")
		img.Name = "Image"
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = "rbxassetid://" .. tostring(icon)
		local imgRound = Instance.new("UICorner")
		imgRound.CornerRadius = UDim.new(0.5, 0)
		imgRound.Parent = img
		img.Parent = inner
	else
		Ui.label(inner, {
			Name = "Mark",
			Size = UDim2.fromScale(1, 1),
			Text = def.mark,
			TextScaled = true,
			FontFace = Ui.FONT_DISPLAY,
			TextColor3 = if def.tier == "boss" then Palette.gold else tierColour(def.tier),
		})
	end
	holder.Parent = parent
	return holder
end

-- A gold pill over a boss's Rookie (any character model with a Head or a root part).
function BadgeView.pill(character: Instance): BillboardGui?
	local anchor = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not (anchor and anchor:IsA("BasePart")) then
		return nil
	end
	local old = anchor:FindFirstChild("BossPill")
	if old and old:IsA("BillboardGui") then
		return old
	end
	local P = B.BOSS_PILL
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossPill"
	gui.Size = UDim2.fromOffset(P.WIDTH, P.HEIGHT)
	gui.StudsOffsetWorldSpace = Vector3.new(0, P.OFFSET_Y, 0)
	gui.MaxDistance = P.MAX_DISTANCE
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = Palette.gold
	body.BorderSizePixel = 0
	Ui.pill(body)
	Ui.stroke(body, tierColour("boss"), 2)
	Ui.label(body, {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Text = Strings.BOSS_PILL,
		TextScaled = true,
		FontFace = Ui.FONT_DISPLAY,
		TextColor3 = Palette.ink,
		stroke = false,
	})
	body.Parent = gui
	gui.Adornee = anchor
	gui.Parent = anchor
	return gui
end

function BadgeView.new(gui: Instance, toast: (text: string) -> (), opts: Opts?)
	local o: Opts = opts or {}
	local me: Instance? = o.localPlayer or Players.LocalPlayer
	local store: Instance = o.store or ReplicatedStorage
	local reduced = o.reduced or function(): boolean
		return Ui.reducedMotion()
	end
	local view = {}
	local conns: { RBXScriptConnection } = {}

	-- The card (hidden until a badge is earned)
	local w, h = B.TOAST_SIZE[1], B.TOAST_SIZE[2]
	local card = Ui.panel(gui, {
		Name = "BadgeCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, B.TOAST_Y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = Palette.plumDeep,
		Visible = false,
		ZIndex = 30,
	}, Palette.gold)
	local scale = Instance.new("UIScale")
	scale.Name = "Fit"
	scale.Parent = card
	local iconSlot = Instance.new("Frame")
	iconSlot.Name = "IconSlot"
	iconSlot.BackgroundTransparency = 1
	iconSlot.Position = UDim2.fromOffset(10, (h - B.TOAST_ICON) / 2)
	iconSlot.Size = UDim2.fromOffset(B.TOAST_ICON, B.TOAST_ICON)
	iconSlot.Parent = card
	local textX = 10 + B.TOAST_ICON + 12
	local title = Ui.label(card, {
		Name = "Title",
		Position = UDim2.fromOffset(textX, 10),
		Size = UDim2.fromOffset(w - textX - 10, 22),
		Text = Strings.BADGE_UNLOCKED,
		TextColor3 = Palette.gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 18,
	})
	local nameLabel = Ui.label(card, {
		Name = "BadgeName",
		Position = UDim2.fromOffset(textX, 34),
		Size = UDim2.fromOffset(w - textX - 10, 30),
		Text = "",
		FontFace = Ui.FONT_DISPLAY,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 26,
	})
	Ui.fit(nameLabel, 26, Config.Heist.UI_TEXT_MIN)
	local countLabel = Ui.label(card, {
		Name = "Count",
		Position = UDim2.fromOffset(textX, 66),
		Size = UDim2.fromOffset(w - textX - 10, 20),
		Text = "",
		TextColor3 = Palette.steelHi,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
	})
	view.card = card
	view.title = title

	local function fitScale()
		local cam = workspace.CurrentCamera
		local vw = if cam then cam.ViewportSize.X else w
		scale.Scale = math.clamp((vw - 32) / w, 0.5, 1)
	end

	local pending: { string } = {}
	local showing = false
	local token = 0

	local function showNext()
		local key = table.remove(pending, 1)
		local def = key and Badges.def(key)
		if not def then
			showing = false
			return
		end
		showing = true
		token += 1
		local mine = token
		for _, c in iconSlot:GetChildren() do
			c:Destroy()
		end
		buildIcon(iconSlot, def, B.TOAST_ICON)
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = tierColour(def.tier)
		end
		nameLabel.Text = def.name
		local earned = if me then tonumber(me:GetAttribute(Badges.ATTR_EARNED)) else nil
		countLabel.Text = if earned and earned > 0 then Strings.badgeCount(earned, #Badges.LIST) else ""
		fitScale()
		card.Visible = true
		if not reduced() then
			card.Position = UDim2.fromScale(0.5, B.TOAST_Y - 0.08)
			Motion.timed(card, B.TOAST_IN_SECONDS, { Position = UDim2.fromScale(0.5, B.TOAST_Y) }, "enter")
		else
			card.Position = UDim2.fromScale(0.5, B.TOAST_Y)
		end
		task.delay(B.TOAST_SECONDS, function()
			if token ~= mine then
				return
			end
			card.Visible = false
			task.delay(B.TOAST_GAP_SECONDS, function()
				if token == mine then
					showNext()
				end
			end)
		end)
	end

	-- Queues a card for a badge key (unknown keys are ignored).
	function view.show(key: string)
		if not Badges.def(key) then
			return
		end
		table.insert(pending, key)
		if not showing then
			showNext()
		end
	end

	function view.pending(): number
		return #pending
	end

	if me then
		local function onToast()
			local key = Badges.parseToast(me:GetAttribute(Badges.ATTR_TOAST))
			if key then
				view.show(key)
			end
		end
		table.insert(conns, me:GetAttributeChangedSignal(Badges.ATTR_TOAST):Connect(onToast))
		onToast() -- earned before this view existed (Welcome, at join)
	end

	-- The boss
	local myId = if me and me:IsA("Player") then (me :: Player).UserId else tonumber(me and me:GetAttribute("UserId"))
	local lastBoss = 0
	local function onBossHere()
		local id = tonumber(store:GetAttribute(Badges.ATTR_BOSS_HERE)) or 0
		if id ~= 0 and id ~= lastBoss and id ~= myId then
			toast(Strings.BOSS_HERE)
		end
		lastBoss = id
	end
	table.insert(conns, store:GetAttributeChangedSignal(Badges.ATTR_BOSS_HERE):Connect(onBossHere))
	onBossHere()

	local watched: { [any]: { RBXScriptConnection } } = {}
	local function dressBoss(p: any)
		if p == me then
			return
		end
		local char = p.Character
		local isBoss = p:GetAttribute(Badges.ATTR_BOSS) == true
		if char then
			local pill = BadgeView.pill(char)
			if pill then
				pill.Enabled = isBoss
				if not isBoss then
					pill:Destroy()
				end
			end
		end
	end
	local function watch(p: any)
		if watched[p] or p == me then
			return
		end
		watched[p] = {
			p:GetAttributeChangedSignal(Badges.ATTR_BOSS):Connect(function()
				dressBoss(p)
			end),
			p.CharacterAdded:Connect(function()
				task.defer(dressBoss, p) -- the Rookie's parts arrive with the model
			end),
		}
		if p:GetAttribute(Badges.ATTR_BOSS) == true then
			dressBoss(p)
		end
	end
	local function unwatch(p: any)
		for _, c in watched[p] or {} do
			c:Disconnect()
		end
		watched[p] = nil
	end
	if o.players == nil then
		for _, p in Players:GetPlayers() do
			watch(p)
		end
		table.insert(conns, Players.PlayerAdded:Connect(watch))
		table.insert(conns, Players.PlayerRemoving:Connect(unwatch))
	else
		for _, p in o.players() do
			watch(p)
		end
	end

	function view.destroy()
		for _, c in conns do
			c:Disconnect()
		end
		for p in watched do
			unwatch(p)
		end
		card:Destroy()
	end

	return view
end

return BadgeView
