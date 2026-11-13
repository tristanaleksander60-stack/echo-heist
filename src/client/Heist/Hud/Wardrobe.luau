--!strict
-- Hud/Wardrobe: the hideout's outfit picker (LOBBY track; PLAN_FIRST_PERSON "CH" outfit slots, Config.Rookie). A
-- sheet on the left (HudLayout.WARDROBE) while the camera orbits your Rookie on the right (Heist/Hideout,
-- LobbyLook.orbit): five slot tabs (cap, scarf, sweater, gloves, mask), the slot's items as chips (the one you wear
-- outlined gold; a locked one veiled with a lock), a line saying what the selected item needs ("6 STARS",
-- "CLEAR NIGHT CLERK") or WEARING, and BACK. A pick goes through the existing Data.Equip(slot, id) (the server checks
-- the unlock with Outfit.canWear; Heist/Characters re-dresses you live from the "Outfit" attribute). What is unlocked
-- comes from Data.Snapshot (Shared/Heist/Outfit.isUnlocked, the server's own rule). Touch controls are off while it
-- is up (a sheet), so the cursor is free and BACK / E / B / Esc close it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Outfit = require(HeistShared:WaitForChild("Outfit"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))

local Heist = script.Parent.Parent
local Sound = require(Heist:WaitForChild("Sound"))
local Theme = require(Heist:WaitForChild("Theme"))
local Ui = require(Heist:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local R = Config.Rookie
local U = Config.Ui
local TAP = Ui.TAP
local localPlayer = Players.LocalPlayer

local Wardrobe = {}

-- The unlock rule of a locked item in kid words ("6 STARS", "CLEAR NIGHT CLERK").
function Wardrobe.ruleText(id: string): string
	local def = R.OUTFIT[id]
	local rule = def and def.unlock
	if type(rule) ~= "table" then
		return Strings.WARDROBE_LOCKED
	end
	if rule.stars then
		return Strings.unlockStars(rule.stars)
	end
	if rule.trophy then
		-- a level's trophy: name the level to clear (Trophy_NightClerk -> NIGHT CLERK); other trophies by name
		local trophy = Config.Data.Trophies and Config.Data.Trophies[rule.trophy]
		local key = string.gsub(tostring(rule.trophy), "^Trophy_", "")
		local name = if type(trophy) == "table"
				and trophy.kind ~= "level"
				and type(trophy.name) == "string"
			then trophy.name
			else (string.gsub(key, "(%l)(%u)", "%1 %2"))
		return Strings.unlockTrophy(name)
	end
	return Strings.WARDROBE_LOCKED
end

function Wardrobe.build(ctx: any): any
	local hud = ctx.hud
	local w = {}
	local sheet = Ui.panel(ctx.root, { Name = "Wardrobe", Visible = false })
	Common.place(sheet, HudLayout.WARDROBE)
	Common.sheetBlocksTouch("wardrobe", sheet)
	w.sheet = sheet
	local title = Ui.label(sheet, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 22,
		Text = Strings.WARDROBE,
	})
	local tabs: { [string]: TextButton } = {}
	local chips = Ui.frame(sheet, {
		Name = "Items",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 120),
		Size = UDim2.new(1, -12, 0, TAP),
	})
	local info = Ui.label(sheet, {
		Name = "Info",
		Position = UDim2.fromOffset(12, 198),
		Size = UDim2.new(1, -24, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextSize = U.TYPE_SCALE[2],
		TextColor3 = Palette.steelHi,
		Text = "",
	})
	local onClose: (() -> ())? = nil
	local back = Ui.button(sheet, {
		Name = "Back",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(200, TAP),
		TextSize = 22,
		Text = Strings.LOBBY_BACK,
	}, function()
		local fn = onClose
		if fn then
			fn()
		end
	end, "UIBack")
	Ui.iconWord(back, "close", "left", U.ICON_SMALL)

	local slot = R.SLOTS[1]
	local heist: any = nil -- the profile slice (Data.Snapshot), nil until it answers (free items only then)
	local wearing: { [string]: string } = Outfit.fromKey(localPlayer:GetAttribute("Outfit"))
	local selected: string? = nil
	local busy = false

	local render: () -> ()
	local function equip(id: string)
		if busy then
			return
		end
		if not Outfit.isUnlocked(heist, id) then
			Sound.play("UIError")
			selected = id
			render()
			return
		end
		busy = true
		selected = id
		local s = slot
		wearing[s] = id -- shown at once; the server's answer (and the Outfit attribute) settles it
		render()
		task.spawn(function()
			local res = Net.Request("Data.Equip", s, id)
			busy = false
			if not res.ok then
				hud.toast(Strings.WARDROBE_SAVE_FAILED)
				wearing = Outfit.fromKey(localPlayer:GetAttribute("Outfit"))
			end
			render()
		end)
	end

	render = function()
		title.Text = Strings.WARDROBE .. " · " .. (Strings.WARDROBE_SLOT[slot] or string.upper(slot))
		for name, tab in tabs do
			local on = name == slot
			tab.BackgroundColor3 = if on then Palette.gold else Theme.COLOR.neutral
		end
		for _, c in chips:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local ids = Outfit.idsFor(slot)
		local n = math.max(#ids, 1)
		local gap = 6
		local cw = math.clamp(math.floor((324 - gap * (n - 1)) / n), 60, 160)
		local selInfo = ""
		for k, id in ids do
			local def = R.OUTFIT[id]
			local unlocked = Outfit.isUnlocked(heist, id)
			local worn = wearing[slot] == id
			local chip = Ui.button(chips, {
				Name = id,
				Position = UDim2.fromOffset((k - 1) * (cw + gap), 0),
				Size = UDim2.fromOffset(cw, TAP),
				BackgroundColor3 = if unlocked then Palette.exit else Palette.steelLo,
				TextColor3 = Palette.ink,
				TextSize = U.TYPE_SCALE[1],
				TextWrapped = true,
				Text = string.upper(def.name),
			}, function()
				equip(id)
			end, if unlocked then "UIConfirm" else "")
			local outline = chip:FindFirstChild("Outline")
			if worn and outline and outline:IsA("UIStroke") then
				outline.Color = Palette.gold
				outline.Thickness = 4
			end
			if not unlocked then
				local veil = Ui.frame(chip, {
					Name = "Locked",
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = Palette.ink,
					BackgroundTransparency = 0.45,
					Active = false,
					ZIndex = 3,
				})
				Ui.corner(veil)
				local lock = Ui.label(veil, {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -4),
					Size = UDim2.new(1, -8, 0, 20),
					TextSize = U.TYPE_SCALE[1],
					TextColor3 = Palette.steelHi,
					Text = "",
					ZIndex = 4,
				})
				Ui.iconWord(lock, "lock", "left", U.ICON_SMALL - 4)
			end
			if id == selected or (selected == nil and worn) then
				selInfo = if worn
					then Strings.WEARING .. " · " .. string.upper(def.name)
					elseif unlocked then string.upper(def.name)
					else string.upper(def.name) .. " · " .. Wardrobe.ruleText(id)
			end
		end
		info.Text = selInfo
	end

	local x = 6
	for _, s in R.SLOTS do
		local tab = Ui.button(sheet, {
			Name = "Tab_" .. s,
			Position = UDim2.fromOffset(x, 42),
			Size = UDim2.fromOffset(60, TAP),
			TextSize = U.TYPE_SCALE[1],
			TextWrapped = true,
			Text = Strings.WARDROBE_SLOT[s] or string.upper(s),
		}, function()
			slot = s
			selected = nil
			render()
		end, "UIToggle")
		tabs[s] = tab
		x += 66
	end

	localPlayer:GetAttributeChangedSignal("Outfit"):Connect(function()
		if not busy then
			wearing = Outfit.fromKey(localPlayer:GetAttribute("Outfit"))
			if Ui.isShown(sheet) then
				render()
			end
		end
	end)

	-- Opens the sheet (closeFn: what BACK does: Heist/Hideout leaves the station).
	function w.open(closeFn: () -> ())
		onClose = closeFn
		slot = R.SLOTS[1]
		selected = nil
		wearing = Outfit.fromKey(localPlayer:GetAttribute("Outfit"))
		Ui.show(sheet)
		render()
		Common.selectFor(tabs[slot])
		task.spawn(function()
			local res = Net.Request("Data.Snapshot")
			if res.ok and type(res.data) == "table" then
				heist = res.data.heist
				if Ui.isShown(sheet) then
					render()
				end
			end
		end)
	end

	function w.close()
		onClose = nil
		Ui.hide(sheet)
	end

	function w.isOpen(): boolean
		return Ui.isShown(sheet)
	end

	return w
end

return Wardrobe
