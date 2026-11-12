--!strict
-- Hud/Common: helpers the HUD modules share (gamepad selection, dates, run names, the
-- run-state questions every module asks, and placing a frame from a HudLayout box).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local HeistShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Common = {}

Common.OBJECTIVE_SECONDS = 6 -- an objective line shows this long after it changes (§7.4)

-- Clone statuses that are flagged red (deck cards, strip, DELETE BUSTED).
Common.RED = table.freeze({ Busted = true, Caught = true, Zapped = true, Stuck = true })

-- L1 stuck hints at Config.Heist.HINT_SECONDS (§7.5): re-pulse the plate, a beam from
-- your feet, the Mentor ghost doing the step. Names are the analytics `hint` domain.
Common.HINTS = table.freeze({ "plate", "beam", "mentor" })

-- The gamepad selection outline only when a gamepad is in use (not on touch or PC).
function Common.usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Gamepad1
		or last == Enum.UserInputType.Gamepad2
		or last == Enum.UserInputType.Gamepad3
		or last == Enum.UserInputType.Gamepad4
end

function Common.selectFor(obj: GuiObject?)
	if Common.usingGamepad() then
		GuiService.SelectedObject = obj
	end
end

-- Places a frame from a HudLayout box (anchor, position, offset size).
function Common.place(obj: GuiObject, box: HudLayout.Box)
	obj.AnchorPoint = Vector2.new(box.ax, box.ay)
	obj.Position = UDim2.new(box.sx, box.ox, box.sy, box.oy)
	obj.Size = UDim2.fromOffset(box.w, box.h)
end

-- Only a box's position (the size stays as it is).
function Common.position(box: HudLayout.Box): UDim2
	return UDim2.new(box.sx, box.ox, box.sy, box.oy)
end

function Common.dateText(day: number): string
	local ok, text = pcall(function()
		local dt = DateTime.fromUnixTimestamp(day * 86400):ToUniversalTime()
		return Strings.date(Strings.MONTHS[dt.Month], dt.Day)
	end)
	return if ok then text else ""
end

function Common.durationText(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return Strings.hoursMinutes(s // 3600, (s % 3600) // 60)
	end
	return Strings.minutes(math.max(1, s // 60))
end

function Common.isTutorial(state: any): boolean
	return state.level ~= nil and state.level.tutorial ~= nil
end

function Common.isParty(state: any): boolean
	return state.level ~= nil and state.level.kind == "party"
end

function Common.dawnRuns(state: any): number?
	local level = state.level
	return if level then level.dawnRuns else nil
end

-- "RUN 7" / "RUN 7/8" / "LAST RUN" for the button and the top bar.
function Common.runName(state: any, n: number): string
	local dawn = Common.dawnRuns(state)
	if dawn and n >= dawn then
		return Strings.LAST_RUN
	elseif dawn then
		return Strings.runOfDawn(n, dawn)
	end
	return Strings.run(n)
end

-- Avatar headshots (crew cards, PLAN_STEAM_PLUS §3.2): Players:GetUserThumbnailAsync HeadShot, fetched
-- once per user and cached; fn(uri) runs when it is known (at once if cached). A failed fetch calls
-- nothing (the card keeps its plain crew-colour backdrop) and the next ask tries again.
local headshots: { [number]: string } = {}
local headshotWaiting: { [number]: { (string) -> () } } = {}
function Common.headshot(userId: number, fn: (uri: string) -> ())
	local known = headshots[userId]
	if known then
		fn(known)
		return
	end
	local list = headshotWaiting[userId]
	if list then
		table.insert(list, fn)
		return
	end
	headshotWaiting[userId] = { fn }
	task.spawn(function()
		local size = (Enum.ThumbnailSize :: any)[Config.Ui.CARD.HEADSHOT_SIZE] or Enum.ThumbnailSize.Size100x100
		local ok, uri = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, size)
		end)
		local waiting = headshotWaiting[userId] or {}
		headshotWaiting[userId] = nil
		if ok and type(uri) == "string" and uri ~= "" then
			headshots[userId] = uri
			for _, cb in waiting do
				task.spawn(cb, uri)
			end
		end
	end)
end

-- Sheets that cover the screen (results, MENU, settings) switch Roblox's touch controls off while
-- they are up, so the thumbstick and jump button never sit on top of their buttons (tests/hud_layout:
-- HudLayout.SHEETS). Each sheet is one blocker; the controls come back when none is left.
local touchBlockers: { [string]: boolean } = {}
function Common.blockTouch(who: string, on: boolean)
	touchBlockers[who] = if on then true else nil
	local enabled = next(touchBlockers) == nil
	pcall(function()
		if GuiService.TouchControlsEnabled ~= enabled then
			GuiService.TouchControlsEnabled = enabled
		end
	end)
end

-- A sheet blocks touch controls while it is shown (Ui.show / Ui.hide, or a bare Visible = false).
function Common.sheetBlocksTouch(who: string, sheet: GuiObject)
	local function sync()
		Common.blockTouch(who, sheet.Visible and sheet:GetAttribute("UiShown") ~= false)
	end
	sheet:GetAttributeChangedSignal("UiShown"):Connect(sync)
	sheet:GetPropertyChangedSignal("Visible"):Connect(sync)
end

function Common.myActor(a: any): boolean
	return a ~= nil and a.kind == "live" and a.owner == Players.LocalPlayer.UserId
end

return Common
