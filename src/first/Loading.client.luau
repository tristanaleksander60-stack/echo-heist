--!strict
-- ReplicatedFirst/Loading: replaces Roblox's default loading screen with the branded ink card
-- (ReplicatedFirst/LoadingCard; POLISH §4.6, PLAN_STEAM_PLUS §4.1 W7) on the very first frame.
--
-- Preload: only the card itself (its two built-in font faces), before the default screen goes, so
-- the first frame is never a blank ink rectangle. The HUD's own images are preloaded by the client
-- (Heist/Loading) while the card is still up; everything else streams in later.
--
-- Hand-off (attributes on the card's ScreenGui, Brand.ATTR): the client (Heist/Loading) sets HOLD when
-- it takes over, STAGE as the boot moves on, REDUCED for the reel, and DISMISS = "fade" on the first
-- built frame of the garage, or "handoff" when it has drawn the same frame one layer up (the title
-- beat, the van doors). Teardown is one idempotent function; a watchdog removes the card after
-- MAX_SECONDS (HOLD_MAX_SECONDS while held) and says why, so a stuck dependency never traps anyone.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Brand = require(script.Parent:WaitForChild("Brand"))
local LoadingCard = require(script.Parent:WaitForChild("LoadingCard"))

local A = Brand.ATTR
local L = Brand.LOADING
local FONT_WAIT = 0.5 -- s the default screen may stay while the card's fonts arrive (built-in: near instant)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local card = LoadingCard.build(playerGui)
local gui = card.gui

-- The card's fonts first (tiny, local), then the default screen goes.
local fontsReady = false
task.spawn(function()
	pcall(ContentProvider.PreloadAsync, ContentProvider, { gui })
	fontsReady = true
end)
local waitFrom = os.clock()
while not fontsReady and os.clock() - waitFrom < FONT_WAIT do
	task.wait()
end
ReplicatedFirst:RemoveDefaultLoadingScreen()
local shownAt = os.clock()
gui:SetAttribute(A.SHOWN_AT, shownAt)

local closed = false
local spinConn: RBXScriptConnection? = nil
local function close(how: string?, why: string?)
	if closed then
		return
	end
	closed = true
	if spinConn then
		spinConn:Disconnect()
	end
	if why then
		warn("[Loading] card removed by the watchdog: " .. why)
	end
	if how == "handoff" or gui.Parent == nil then
		gui:Destroy()
		return
	end
	local info = TweenInfo.new(L.FADE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local last: Tween? = nil
	for _, pair in LoadingCard.fadeGoals(gui) do
		local tw = TweenService:Create(pair[1], info, pair[2])
		tw:Play()
		last = tw
	end
	if last then
		last.Completed:Once(function()
			gui:Destroy()
		end)
	else
		gui:Destroy()
	end
end

spinConn = RunService.RenderStepped:Connect(function()
	local reduced = GuiService.ReducedMotionEnabled or gui:GetAttribute(A.REDUCED) == true
	LoadingCard.spin(card.reel, os.clock(), reduced)
end)
gui:GetAttributeChangedSignal(A.STAGE):Connect(function()
	local stage = gui:GetAttribute(A.STAGE)
	if type(stage) == "string" then
		LoadingCard.setStage(card, stage)
	end
end)
gui:GetAttributeChangedSignal(A.DISMISS):Connect(function()
	local how = gui:GetAttribute(A.DISMISS)
	close(if type(how) == "string" then how else "fade")
end)
gui.AncestryChanged:Connect(function()
	if gui.Parent == nil then
		close("handoff")
	end
end)

-- Watchdog: every wait has a timeout.
task.spawn(function()
	while not closed do
		task.wait(0.25)
		local held = gui:GetAttribute(A.HOLD) == true
		local limit = if held then L.HOLD_MAX_SECONDS else L.MAX_SECONDS
		if not closed and os.clock() - shownAt > limit then
			close("fade", string.format("%s after %d s", if held then "held" else "never claimed", limit))
		end
	end
end)

if not game:IsLoaded() then
	game.Loaded:Wait()
end
if not closed and gui:GetAttribute(A.STAGE) == nil then
	LoadingCard.setStage(card, "client")
end
