--!strict
-- Heist/Loading: the client half of the first frame (POLISH §4.6, PLAN_STEAM_PLUS §4.1 W7, premium G1).
-- ReplicatedFirst/Loading puts the branded ink card up on the very first frame; this module takes it
-- over (Brand.ATTR on the card's ScreenGui) and hands it off cleanly:
--   * a returning player: the card fades (0.3 s) on the garage's first built frame;
--   * a new account (the FTUE: intro -> L1): the server reads the profile (at most DATA_WAIT_SECONDS, the card's
--     "Finding your van") and puts the player in the hideout with a garage Sync marked `ftue`; there is no server
--     hold. The story intro (Heist/Cinematic, PresentPlan.introDue) replaces the card from its first frame and plays
--     over the hideout built behind it; it ends on the wordmark, which the title card (Heist/Title, at rest) takes
--     over in the same frame. Then the boot Heist.Ready starts L1 on the server and the van doors open onto it; if
--     L1 does not come within Config.Intro.FTUE_START_WAIT_SECONDS the title fades onto the hideout. With the intro
--     off (or seen), the title beat replaces the card in the same frame and the Ready goes at once (during the
--     server's wait: L1 straight away, as before the hideout). Nothing on the client ever delays first control
--     (PresentPlan.revealAt). If the intro cannot play (an error, a stalled frame: Cinematic.play's own watchdog),
--     it degrades to the title card at once, never to a frozen screen;
--   * the server's short wait ("preparing") is the card's reel and a "Finding your van" hint, or the title beat,
--     never a silent text card (WALKTHROUGH §2.0).
--
--   Loading.boot(doors, reduced, camera?, tier?) -> boot     HeistClient, once (camera: CameraDirector;
--                               tier: the perf tier getter, both handed to the intro)
--     boot.active()             still in the first hand-off
--     boot.preparing() -> bool  the server is reading the profile (false: no card left)
--     boot.arrive(kind)         the server's first answer, before the view is built: "garage", "garageFtue" (a new
--                               account in the hideout: L1 follows the boot Ready), "heist", "heistFtue" (L1 the
--                               server started itself); decides the title, closes the doors under the card for a heist
--     boot.awaitFtue(fallback)  garageFtue: keep the card / intro / title up for L1; fallback() (reveal the hideout)
--                               if it has not come FTUE_START_WAIT_SECONDS after the Ready
--     boot.awaiting() -> bool   waiting for that L1
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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local Scenario = require(Shared:WaitForChild("Heist"):WaitForChild("Scenario"))
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))
local Brand = require(ReplicatedFirst:WaitForChild("Brand"))
local LoadingCard = require(ReplicatedFirst:WaitForChild("LoadingCard"))

local IntroPlan = require(Shared:WaitForChild("Heist"):WaitForChild("IntroPlan"))
local Cinematic = require(script.Parent:WaitForChild("Cinematic"))
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

function Loading.boot(doors: any, reduced: () -> boolean, camera: any?, tier: (() -> number)?): any
	local boot = {}
	local pg = playerGui()
	local gui = card()
	local shownAt: number = if gui then tonumber(gui:GetAttribute(A.SHOWN_AT)) or os.clock() else os.clock()
	local active = pg ~= nil
	local title: any = nil
	local intro: any = nil -- the story intro (Heist/Cinematic) while it plays
	local introOver = false
	local released = false
	local releasedAt: number? = nil
	local awaitFallback: (() -> ())? = nil -- garageFtue: reveal the hideout if L1 never comes
	local first: string? = nil -- the server's first answer
	local controlNoted = false

	local function introPlaying(): boolean
		return intro ~= nil and not introOver
	end

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

	-- The boot Ready, once: the intro (or the title) is over, or none is due. For a new account it starts L1 on
	-- the server (HeistService: during its short profile wait, or from the hideout); otherwise it is ignored.
	local function release()
		if not released then
			released = true
			releasedAt = os.clock()
			pcall(Net.Send, Protocol.REMOTE.Ready, reduced())
		end
	end

	local function startTitle(atRest: boolean?)
		if title or not pg then
			return
		end
		FirstTime.markSeen(PresentPlan.TITLE_KIND)
		doors.cover() -- ink under ink: the doors wait closed under the title
		title = Title.play(pg, reduced)
		if atRest then
			title.skip() -- the intro ended on the split wordmark: the card takes over at rest
		end
		setAttr(A.DISMISS, "handoff") -- the title drew the card's frame one layer up
	end

	-- The intro could not play (or stopped advancing): the title card at rest at once, then the server may go.
	local function introFailed(why: string)
		warn("[Loading] intro: " .. why .. " (the title card instead)")
		introOver = true
		startTitle(true)
		release()
	end

	local function startIntro()
		if intro or title or not pg then
			return
		end
		FirstTime.markSeen(PresentPlan.TITLE_KIND)
		doors.cover()
		intro = true -- reserved while the kit arrives (the card stays up meanwhile, at most KIT_WAIT_SECONDS)
		task.spawn(function()
			-- Every step is guarded: an error here used to leave `intro` reserved for good (no Ready, the card on
			-- "Finding your van" until its watchdog, then closed doors that never opened).
			local ok, res = pcall(function()
				Cinematic.waitForKit()
				return Cinematic.play({
					gui = pg,
					director = camera,
					reduced = reduced,
					tier = if tier then tier() else nil,
					onEnd = function(how: string)
						if how == "stalled" then
							warn("[Loading] intro stalled: its frames stopped advancing")
						end
						introOver = true
						startTitle(true)
						release()
					end,
				})
			end)
			if not ok then
				introFailed(tostring(res))
				return
			end
			if res == nil then -- could not play (another one running): straight to the title
				introFailed("not started")
				return
			end
			intro = res
			setAttr(A.DISMISS, "handoff") -- the intro's ink frame is up: the card can go
		end)
	end

	local function decide(kind: string)
		if title or intro or not active then
			return
		end
		local status = FirstTime.status()
		local staged = Scenario.resolve(RunService:IsStudio(), workspace:GetAttribute(Scenario.ATTRIBUTE)) == "INTRO"
		if not staged and kind == "preparing" and status == "pending" then
			return -- the profile decides (onStatus asks again); the server keeps holding meanwhile
		end
		if
			PresentPlan.introDue({
				enabled = Config.Intro.ENABLED,
				status = status,
				seen = FirstTime.seen(PresentPlan.TITLE_KIND),
				boot = kind,
				studio = RunService:IsStudio(),
				staged = staged,
				studioAutoplay = Config.Intro.STUDIO_AUTOPLAY,
			})
		then
			startIntro()
			return
		end
		if PresentPlan.titleDue(status, FirstTime.seen(PresentPlan.TITLE_KIND), kind) then
			startTitle()
		end
		release()
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
		if kind ~= "garageFtue" then
			awaitFallback = nil -- the L1 that garageFtue waited for (or a plain hideout) is here
		end
		decide(kind)
		if kind == "heist" or kind == "heistFtue" then
			doors.cover() -- the heist binds behind closed doors, under the card or the title
		end
	end

	function boot.awaitFtue(fallback: () -> ())
		if not active then
			return
		end
		awaitFallback = fallback
		task.spawn(function()
			-- the intro (or the title) first, then the Ready, then the server's L1 within FTUE_START_WAIT_SECONDS
			while active and awaitFallback == fallback do
				local at = releasedAt
				if at and not introPlaying() and os.clock() - at >= Config.Intro.FTUE_START_WAIT_SECONDS then
					break
				end
				task.wait(0.1)
			end
			if active and awaitFallback == fallback then
				awaitFallback = nil
				fallback()
			end
		end)
	end

	function boot.awaiting(): boolean
		return active and awaitFallback ~= nil
	end

	local function reveal(controlAt: number?)
		-- the intro plays to its end (or SKIP) first; bounded: Cinematic.play has its own watchdog, this is the last
		local introUntil = os.clock() + IntroPlan.total() + Config.Intro.START_WATCHDOG_SECONDS + 10
		while introPlaying() and os.clock() < introUntil do
			task.wait()
		end
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

	-- Safety: a first heist that never binds still lets the player see the game (not while the intro plays or a
	-- garageFtue start is still inside its own window: those end by themselves).
	task.spawn(function()
		local deadline = os.clock() + P.LOADING.HOLD_MAX_SECONDS
		while active and (os.clock() < deadline or introPlaying() or awaitFallback ~= nil) do
			task.wait(0.25)
		end
		if active then
			warn("[Loading] no first frame after " .. P.LOADING.HOLD_MAX_SECONDS .. " s: revealing")
			boot.landed(nil)
		end
	end)

	return boot
end

return Loading
