--!strict
-- Heist/Telemetry: the client side of analytics (docs/ANALYTICS.md "Client", MASTERPLAN
-- §8.6, §6.3). Clients never log: they report a few facts through three rate-limited,
-- validated LihFolk Net remotes (Ready and Ui owner-approved 2026-11-12; Perf awaits the
-- owner's sign-off, docs/ANALYTICS.md) and the server re-validates and decides what to log.
--   * Analytics.Ready(device)   once, at first control (JoinToControl)
--   * Analytics.Perf(...)       PerfSample.pack every perfIntervalSeconds (LiveFlag) while
--                               the perfSampling kill switch is on
--   * Analytics.Ui(kind, arg)   UI facts only the client sees: stuck hints, PerfStepDown
-- The runtime performance tier starts where the device suggests (Budget.startTier: device class,
-- the saved / render quality level, screen size), a 2.5 s frame probe while the loading card is
-- up may lower it once (Budget.probeTier), then the PerfSample governor steps it down (quality ->
-- balanced -> performance -> minimum) when frames stay slow, and back up one step after a
-- sustained good stretch (PerfSample.stepUp, with hysteresis, seeded with the start tier);
-- `onTier` listeners apply it. Works in both GAME_MODEs. Never in the way: if the remotes do
-- not arrive, every analytics call is a no-op (the tier governor still runs).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local PerfSample = require(Shared:WaitForChild("Analytics"):WaitForChild("PerfSample"))
local Budget = require(Shared:WaitForChild("Heist"):WaitForChild("Budget"))

local H = Config.Heist
local P = Config.Analytics.Perf
local REMOTES = "LihFolkRemotes"
local NAMES = { "Analytics.Ready", "Analytics.Perf", "Analytics.Ui" }

local Telemetry = {}

local started = false
local remotesOk = false
local readySent = false
local readyWanted = false
local device = "other"
local tier = 1
local tierListeners: { (tier: number, name: string) -> () } = {}
local clonesOnScreen: () -> number = function()
	return 0
end
local Net: any = nil

local function send(name: string, ...: any)
	if not remotesOk or not Net then
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		pcall(Net.Send, name, table.unpack(args, 1, args.n))
	end)
end

local function viewportMin(): number
	local cam = workspace.CurrentCamera
	if not cam then
		return 0
	end
	return math.min(cam.ViewportSize.X, cam.ViewportSize.Y)
end

local function deviceClass(): string
	local ok, class = pcall(function()
		return PerfSample.deviceClass({
			touch = UserInputService.TouchEnabled,
			keyboard = UserInputService.KeyboardEnabled,
			gamepad = UserInputService.GamepadEnabled,
			vr = VRService.VREnabled,
			tenFoot = GuiService:IsTenFootInterface(),
			viewportMin = viewportMin(),
		})
	end)
	return if ok and type(class) == "string" then class else "other"
end

local flagFolder: Instance? = nil -- ReplicatedStorage.LiveFlags, found once (read every frame)
local function flag(name: string): any
	local f = flagFolder
	if not (f and f.Parent) then
		f = ReplicatedStorage:FindFirstChild("LiveFlags")
		flagFolder = f
	end
	return if f then f:GetAttribute(name) else nil
end

local function quality(): number
	local ok, q = pcall(function()
		return (UserSettings() :: any).GameSettings.SavedQualityLevel.Value
	end)
	return if ok and type(q) == "number" then q else 0
end

local function memMb(): number
	local ok, m = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)
	return if ok and type(m) == "number" then m else 0
end

function Telemetry.tierName(): string
	return H.PERF_TIERS[tier] or "other"
end

function Telemetry.tier(): number
	return tier
end

-- Runtime tier listeners (the views drop trails, blur, highlights...). Called at once.
function Telemetry.onTier(fn: (tier: number, name: string) -> ())
	table.insert(tierListeners, fn)
	pcall(fn, tier, Telemetry.tierName())
end

local function setTier(n: number)
	n = math.clamp(n, 1, #H.PERF_TIERS)
	if n == tier then
		return
	end
	tier = n
	for _, fn in tierListeners do
		pcall(fn, tier, Telemetry.tierName())
	end
end

-- Where PerfSample reads "clones on screen" from (EchoView).
function Telemetry.setCloneCounter(fn: () -> number)
	clonesOnScreen = fn
end

-- First control: once per session (the sim path calls it on the first Run, the v0.1
-- path on the first character). Queued until the remotes arrive.
function Telemetry.ready()
	readyWanted = true
	if readySent or not remotesOk then
		return
	end
	readySent = true
	send("Analytics.Ready", device)
end

-- Analytics.Ui facts: ("Hint", "plate" | "beam" | "mentor"), ("PerfStepDown", tier), ...
function Telemetry.ui(kind: string, arg: string?)
	send("Analytics.Ui", kind, arg)
end

-- The render quality as a number (RenderSettings.QualityLevel: 0 Automatic / unreadable, else 1..21).
local function renderQuality(): number
	local ok, q = pcall(function()
		return (settings() :: any).Rendering.QualityLevel.Value
	end)
	return if ok and type(q) == "number" then q else 0
end

-- The tier this client starts at, from what it can read at boot (Budget.startTier, Config.Perf.START).
local function bootTier(): number
	local ok, t = pcall(Budget.startTier, {
		device = device,
		savedQuality = quality(),
		renderQuality = renderQuality(),
		viewportMin = viewportMin(),
	})
	return if ok and type(t) == "number" then t else 1
end

-- The frame loop: first the loading-card probe (START.PROBE_*: it may lower the start tier once), then the
-- governor, seeded with the start tier so it can still step back up (PerfSample.seed), and the samples
-- (sent only once the remotes are there; `send` checks).
local function startPerf()
	local S = Config.Perf.START
	local window = PerfSample.new()
	local probe: PerfSample.Window? = PerfSample.new()
	local gov = PerfSample.governor()
	local clock = 0
	local since = 0
	RunService.RenderStepped:Connect(function(dt: number)
		local pw = probe
		if pw then
			clock += dt
			if clock > S.PROBE_SKIP_SECONDS then
				PerfSample.add(pw, dt)
			end
			if clock < S.PROBE_SKIP_SECONDS + S.PROBE_SECONDS then
				return
			end
			probe = nil
			local ok, t = pcall(Budget.probeTier, tier, {
				frames = pw.frames,
				medianMs = PerfSample.percentile(pw, 0.5),
				p95Ms = PerfSample.percentile(pw, 0.95),
			})
			if ok and type(t) == "number" then
				setTier(t)
			end
			PerfSample.seed(gov, tier)
			return
		end
		PerfSample.add(window, dt)
		if PerfSample.govern(gov, dt) and tier < #H.PERF_TIERS then
			setTier(tier + 1)
			Telemetry.ui("PerfStepDown", Telemetry.tierName())
		elseif tier > 1 and PerfSample.stepUp(gov) then
			setTier(tier - 1) -- a sustained good stretch: back up one step (hysteresis in PerfSample)
		end
		since += dt
		local interval = flag("perfIntervalSeconds")
		if type(interval) ~= "number" or interval <= 0 then
			interval = P.INTERVAL_SECONDS
		end
		if since < interval then
			return
		end
		since = 0
		local summary = PerfSample.summary(window)
		PerfSample.reset(window)
		if not summary or not remotesOk or flag("perfSampling") == false or flag("perfSampleRate") == 0 then
			return
		end
		local okClones, clones = pcall(clonesOnScreen)
		send(
			"Analytics.Perf",
			PerfSample.pack(
				summary,
				device,
				quality(),
				memMb(),
				if okClones and type(clones) == "number" then clones else 0,
				Telemetry.tierName()
			)
		)
	end)
end

-- Boots once per client: finds the remotes (with a timeout), then starts the sampler.
function Telemetry.start()
	if started or not RunService:IsClient() then
		return
	end
	started = true
	device = deviceClass()
	-- The start tier first (before any view hooks onTier), then the frame loop: the governor runs whether or not
	-- the analytics remotes ever arrive (only the samples need them).
	tier = math.clamp(bootTier(), 1, #H.PERF_TIERS)
	startPerf()
	local okNet, mod = pcall(function()
		return require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net")) :: any
	end)
	if not okNet then
		return
	end
	Net = mod
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(REMOTES, H.PERF_READY_TIMEOUT)
		if not folder then
			return
		end
		for _, name in NAMES do
			if not folder:WaitForChild(name, H.PERF_READY_TIMEOUT) then
				return -- the server's Analytics did not start: stay silent
			end
		end
		remotesOk = true
		device = deviceClass() -- the viewport is settled by now
		if readyWanted then
			Telemetry.ready()
		end
	end)
	-- v0.1 path and garage: the first character counts as first control unless the sim
	-- client calls ready() sooner.
	local lp = Players.LocalPlayer
	if lp then
		lp.CharacterAdded:Once(function()
			task.defer(Telemetry.ready)
		end)
		if lp.Character then
			task.defer(Telemetry.ready)
		end
	end
end

return Telemetry
