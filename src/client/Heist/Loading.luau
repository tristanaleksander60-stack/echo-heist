--!strict
-- Heist/Loading: the client half of the first frame (POLISH §4.6, PLAN_STEAM_PLUS §4.1 W7, premium G1).
-- ReplicatedFirst/Loading puts the branded ink card up on the very first frame; this module takes it
-- over (Brand.ATTR on the card's ScreenGui) and hands it off cleanly:
--   * a returning player: the card fades (0.3 s) on the garage's first built frame;
--   * a new account (the FTUE autostarts L1): the title beat (Heist/Title) replaces the card in the
--     same frame, overlaps the server's wait, and the van doors (Heist/Transition) open onto L1 by the
--     time the first run's transition ends. If the server is quick, the beat is cut short: nothing on
--     the client ever delays first control (PresentPlan.revealAt);
--   * the server's cold wait ("preparing") is the card's reel and a "Finding your van" hint, or the
--     title beat, never a silent text card (WALKTHROUGH §2.0).
--
--   Loading.boot(doors, reduced) -> boot     HeistClient, once
--     boot.active()             still in the first hand-off
--     boot.preparing() -> bool  the server is getting the first heist ready (false: no card left)
--     boot.arrive(kind)         the server's first answer, before the view is built: "garage", "heist",
--                               "heistFtue" (L1 the server started itself); decides the title, closes
--                               the doors under the card for a heist
--     boot.landed(controlAt?)   the first built frame (controlAt: os.clock() when control returns)
--     boot.noteControl(at)      Studio: prints first frame -> control against the 10 s rule
--   Loading.reel(parent, size) -> Frame      the card's turning reel, for the HUD's wait card
--   Loading.dismiss(how?)                    the v0.1 path: fade the card once its HUD is up

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local Brand = require(ReplicatedFirst:WaitForChild("Brand"))
local LoadingCard = require(ReplicatedFirst:WaitForChild("LoadingCard"))

local FirstTime = require(script.Parent:WaitForChild("FirstTime"))
local PresentPlan = require(script.Parent:WaitForChild("PresentPlan"))
local Title = require(script.Parent:WaitForChild("Title"))

local P = Config.Presentation
local A = Brand.ATTR

local Loading = {}

local function playerGui(): Instance?
	local player = Players.LocalPlayer
	return if player then player:FindFirstChildOfClass("PlayerGui") else nil
end

local function card(): ScreenGui?
	local pg = playerGui()
	local gui = pg and pg:FindFirstChild(Brand.GUI_NAME)
	return if gui and gui:IsA("ScreenGui") then gui else nil
end

function Loading.dismiss(how: string?)
	local gui = card()
	if gui then
		gui:SetAttribute(A.DISMISS, how or "fade")
	end
end

function Loading.reel(parent: Instance, size: number): Frame
	local reel = LoadingCard.reel(parent, size)
	if not RunService:IsClient() then
		return reel -- RenderStepped is client-only (engine tests build views on a server)
	end
	local conn = RunService.RenderStepped:Connect(function()
		LoadingCard.spin(reel, os.clock(), GuiService.ReducedMotionEnabled)
	end)
	reel.Destroying:Once(function()
		conn:Disconnect()
	end)
	return reel
end

function Loading.boot(doors: any, reduced: () -> boolean): any
	local boot = {}
	local pg = playerGui()
	local gui = card()
	local shownAt: number = if gui then tonumber(gui:GetAttribute(A.SHOWN_AT)) or os.clock() else os.clock()
	local active = pg ~= nil
	local title: any = nil
	local first: string? = nil -- the server's first answer
	local controlNoted = false

	local function setAttr(name: string, value: any)
		if gui and gui.Parent then
			gui:SetAttribute(name, value)
		end
	end
	setAttr(A.HOLD, true)
	setAttr(A.STAGE, "client")
	setAttr(A.REDUCED, reduced())

	-- The first frame's UI images and fonts (the HUD guis) while the card is up; nothing waits on it
	-- for longer than PRELOAD_MAX_SECONDS.
	local preloaded = false
	if pg then
		task.spawn(function()
			local roots = {}
			for _, g in pg:GetChildren() do
				if g:IsA("ScreenGui") and g ~= gui then
					table.insert(roots, g)
				end
			end
			pcall(ContentProvider.PreloadAsync, ContentProvider, roots)
			preloaded = true
		end)
	end

	local function startTitle()
		if title or not active or not pg then
			return
		end
		FirstTime.markSeen(PresentPlan.TITLE_KIND)
		doors.cover() -- ink under ink: the doors wait closed under the title
		title = Title.play(pg, reduced)
		setAttr(A.DISMISS, "handoff") -- the title drew the card's frame one layer up
	end

	local function decide(kind: string)
		if title or not active then
			return
		end
		if PresentPlan.titleDue(FirstTime.status(), FirstTime.seen(PresentPlan.TITLE_KIND), kind) then
			startTitle()
		end
	end

	function boot.active(): boolean
		return active
	end

	function boot.preparing(): boolean
		if not active then
			return false
		end
		first = first or "preparing"
		setAttr(A.STAGE, "server")
		decide("preparing")
		FirstTime.onStatus(function()
			if active and first == "preparing" then
				decide("preparing")
			end
		end)
		return (gui ~= nil and gui.Parent ~= nil) or title ~= nil
	end

	function boot.arrive(kind: string)
		if not active then
			return
		end
		first = first or kind
		decide(kind)
		if kind ~= "garage" then
			doors.cover() -- the heist binds behind closed doors, under the card or the title
		end
	end

	local function reveal(controlAt: number?)
		local fade = if title then P.TITLE.FADE_SECONDS elseif gui and gui.Parent then P.LOADING.FADE_SECONDS else 0
		local function startAt(): number
			local s = PresentPlan.revealAt(
				os.clock(),
				if title then title.beatEnd() else nil,
				controlAt,
				fade,
				if doors.isClosed() then doors.openSeconds() else 0
			)
			return s
		end
		-- The garage has no deadline: give the HUD's images a moment to arrive first.
		local preloadUntil = if controlAt == nil then os.clock() + P.PRELOAD_MAX_SECONDS else 0
		while os.clock() < startAt() or (not preloaded and os.clock() < preloadUntil) do
			task.wait()
		end
		if title then
			title.fadeOut(fade)
		else
			setAttr(A.DISMISS, "fade")
		end
		if doors.isClosed() then
			if fade > 0 then
				task.wait(fade)
			end
			doors.open()
		end
	end

	function boot.landed(controlAt: number?)
		if not active then
			return
		end
		active = false
		task.spawn(reveal, controlAt)
	end

	function boot.noteControl(controlAt: number)
		if controlNoted then
			return
		end
		controlNoted = true
		local ok, s = PresentPlan.controlWithin(shownAt, controlAt, P.CONTROL_LIMIT_SECONDS)
		if RunService:IsStudio() then
			print(
				string.format(
					"[Loading] first frame -> control %.1f s (limit %d s)%s",
					s,
					P.CONTROL_LIMIT_SECONDS,
					if ok then "" else " OVER"
				)
			)
		end
	end

	-- Safety: a first heist that never binds still lets the player see the game.
	task.delay(P.LOADING.HOLD_MAX_SECONDS, function()
		if active then
			warn("[Loading] no first frame after " .. P.LOADING.HOLD_MAX_SECONDS .. " s: revealing")
			boot.landed(nil)
		end
	end)

	return boot
end

return Loading
