-- Stem alignment spike (S4, MASTERPLAN §8.11 and §7.2 "Crew Layers"), client side.
-- Two stems on the new Audio API (AudioPlayer -> Wire -> AudioFader -> Wire ->
-- AudioDeviceOutput), played for 8 loops in three modes, measuring the drift
-- between the two players' TimePosition every frame (on screen and in Output):
--   SCHEDULED   each loop restarts on "GO" with AudioPlayer:Play(atTime) on
--               SoundService:GetMixerTime() (the plan's primary method)
--   CONTINUOUS  both start once with Play(atTime) and run 8 loops without a
--               restart (does drift build up over time?)
--   FALLBACK    each loop both start with plain Play() in the same frame, stem B
--               at volume 0 on GO and faded in over one bar from loop 2 (§7.2)
-- Music is local to each client in the game too, so the spike runs only here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local StemsConfig = require(ReplicatedStorage:WaitForChild("StemsSpike"):WaitForChild("StemsConfig"))

local player = Players.LocalPlayer

type Mode = "SCHEDULED" | "CONTINUOUS" | "FALLBACK"
local MODES: { Mode } = { "SCHEDULED", "CONTINUOUS", "FALLBACK" }

local BAR_SECONDS = StemsConfig.BEATS_PER_BAR * 60 / StemsConfig.TRACK_BPM
local LOOP_SECONDS = StemsConfig.LOOP_BARS * BAR_SECONDS

local modeIndex = 1
local offsetIndex = 1
local running = false
local abort = false
local status = "loading stems"
local results: { string } = {}
local summaries: { string } = {}

local function addResult(line: string)
	table.insert(results, line)
	print("[S4] " .. line)
end

local function errText(err: any): string
	local s = tostring(err)
	return if #s > 140 then string.sub(s, 1, 140) .. "..." else s
end

-- Mixer clock ---------------------------------------------------------------------------

local mixerOk = pcall(function()
	return SoundService:GetMixerTime()
end)

local function mixer(): number
	if mixerOk then
		return SoundService:GetMixerTime()
	end
	return os.clock()
end

-- Audio graph ---------------------------------------------------------------------------

local graph = Instance.new("Folder")
graph.Name = "StemsGraph"
graph.Parent = SoundService

local output = Instance.new("AudioDeviceOutput")
output.Name = "Output"
output.Parent = graph

local function wire(source: Instance, target: Instance, name: string)
	local w = Instance.new("Wire")
	w.Name = name
	w.SourceInstance = source
	w.TargetInstance = target
	w.Parent = graph
end

local function makeStem(name: string, asset: string, volume: number): (AudioPlayer, AudioFader)
	local stem = Instance.new("AudioPlayer")
	stem.Name = name
	stem.Looping = true -- short assets keep playing for the whole loop
	stem.Volume = volume
	stem.Parent = graph
	local fader = Instance.new("AudioFader")
	fader.Name = name .. "Fader"
	fader.Volume = 1
	fader.Parent = graph
	wire(stem, fader, name .. "ToFader")
	wire(fader, output, name .. "FaderToOutput")
	stem.Asset = asset
	return stem, fader
end

local stemA, faderA = makeStem("StemA", StemsConfig.STEM_A, StemsConfig.VOLUME_A)
local stemB, faderB = makeStem("StemB", StemsConfig.STEM_B, StemsConfig.VOLUME_B)

local loadState = "loading"
local lenA, lenB = 0, 0
local comparable = true

-- In asset seconds, the unit of TimePosition (so also the wrap period of a loop)
local function lengthOf(stem: AudioPlayer): number
	return stem.TimeLength
end

local function waitReady(): boolean
	local deadline = os.clock() + StemsConfig.LOAD_TIMEOUT
	while os.clock() < deadline do
		if stemA.IsReady and stemB.IsReady then
			return true
		end
		task.wait(0.1)
	end
	return false
end

-- Drift meter ---------------------------------------------------------------------------

type LoopStats = {
	n: number,
	sum: number,
	min: number,
	max: number,
	maxErr: number, -- max |drift - expected|, ms
	sumA: number, -- A vs mixer-predicted position, ms
	maxA: number,
	nA: number,
	last: number,
}

local function newStats(): LoopStats
	return { n = 0, sum = 0, min = math.huge, max = -math.huge, maxErr = 0, sumA = 0, maxA = 0, nA = 0, last = 0 }
end

-- Measurement window, in mixer time
local window = { from = math.huge, to = -math.huge, startA = 0, expectedMs = 0, predictA = false }
local stats = newStats()

local function wrap(d: number, period: number): number
	if period <= 0 then
		return d
	end
	while d > period / 2 do
		d -= period
	end
	while d < -period / 2 do
		d += period
	end
	return d
end

RunService.Heartbeat:Connect(function()
	local now = mixer()
	if now < window.from or now > window.to then
		return
	end
	-- Both positions read in the same frame; the asset loops with its own length
	local posA = stemA.TimePosition
	local posB = stemB.TimePosition
	local period = if comparable then lenA else 0
	local drift = wrap(posA - posB, period) * 1000
	stats.n += 1
	stats.sum += drift
	stats.min = math.min(stats.min, drift)
	stats.max = math.max(stats.max, drift)
	stats.maxErr = math.max(stats.maxErr, math.abs(drift - window.expectedMs))
	stats.last = drift
	if window.predictA and lenA > 0 then
		local expectedA = ((now - window.startA) * stemA.PlaybackSpeed) % lenA
		local errA = wrap(posA - expectedA, lenA) * 1000
		stats.nA += 1
		stats.sumA += errA
		stats.maxA = math.max(stats.maxA, math.abs(errA))
	end
end)

local function openWindow(from: number, to: number, startA: number, expectedMs: number, predictA: boolean)
	stats = newStats()
	window.from = from
	window.to = to
	window.startA = startA
	window.expectedMs = expectedMs
	window.predictA = predictA
end

local function closeWindow(): LoopStats
	window.from = math.huge
	window.to = -math.huge
	return stats
end

-- Runner --------------------------------------------------------------------------------

local function waitUntil(t: number)
	while mixer() < t and not abort do
		RunService.Heartbeat:Wait()
	end
end

local function call(what: string, fn: () -> ()): boolean
	local ok, err = pcall(fn)
	if not ok then
		addResult("ERROR " .. what .. ": " .. errText(err))
	end
	return ok
end

local fadeTween: Tween? = nil

local function rewind()
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
	call("Stop/reset", function()
		stemA:Stop()
		stemB:Stop()
		stemA.TimePosition = 0
		stemB.TimePosition = 0
	end)
end

local function fmtLoop(mode: Mode, offsetMs: number, k: number, s: LoopStats): string
	local mean = if s.n > 0 then s.sum / s.n else 0
	return string.format(
		"%-10s off%3d  loop %d  n%4d  drift %+6.1f ms (%+.1f..%+.1f)  |err| %5.1f  A-vs-mixer %s",
		mode,
		offsetMs,
		k,
		s.n,
		mean,
		if s.n > 0 then s.min else 0,
		if s.n > 0 then s.max else 0,
		s.maxErr,
		if s.nA > 0 then string.format("%+.1f/%.1f ms", s.sumA / s.nA, s.maxA) else "n/a"
	)
end

local function runMode(mode: Mode, offsetMs: number)
	local offset = offsetMs / 1000
	local scheduled = mode ~= "FALLBACK"
	if scheduled and not mixerOk then
		addResult(mode .. ": GetMixerTime() unavailable on this client, mode skipped")
		return
	end
	if mode == "FALLBACK" then
		offsetMs = 0
		offset = 0
	end
	local worst = 0
	local loopsDone = 0
	faderA.Volume = 1
	faderB.Volume = 1
	rewind()

	if mode == "CONTINUOUS" then
		local t0 = mixer() + StemsConfig.LEAD_SECONDS
		local tEnd = t0 + StemsConfig.LOOPS * LOOP_SECONDS
		local ok = call("Play(atTime)", function()
			stemA:Play(t0)
			stemB:Play(t0 + offset)
			stemA:Stop(tEnd)
			stemB:Stop(tEnd)
		end)
		for k = 1, StemsConfig.LOOPS do
			if abort or not ok then
				break
			end
			local from = t0 + (k - 1) * LOOP_SECONDS
			status = string.format("%s loop %d/%d", mode, k, StemsConfig.LOOPS)
			openWindow(from + StemsConfig.SETTLE_SECONDS + offset, from + LOOP_SECONDS - 0.05, t0, offsetMs, true)
			waitUntil(from + LOOP_SECONDS)
			local s = closeWindow()
			worst = math.max(worst, s.maxErr)
			loopsDone = k
			addResult(fmtLoop(mode, offsetMs, k, s))
		end
		waitUntil(tEnd)
	else
		for k = 1, StemsConfig.LOOPS do
			if abort then
				break
			end
			rewind()
			status = string.format("%s loop %d/%d", mode, k, StemsConfig.LOOPS)
			local t0
			local ok
			if scheduled then
				t0 = mixer() + StemsConfig.LEAD_SECONDS
				ok = call("Play(atTime)", function()
					stemA:Play(t0)
					stemB:Play(t0 + offset)
					stemA:Stop(t0 + LOOP_SECONDS)
					stemB:Stop(t0 + LOOP_SECONDS)
				end)
			else
				-- Fallback: start together at GO, layer B silent, then fade it in
				faderB.Volume = 0
				t0 = mixer()
				ok = call("Play()", function()
					stemA:Play()
					stemB:Play()
				end)
				if ok and k >= 2 then
					fadeTween = TweenService:Create(
						faderB,
						TweenInfo.new(StemsConfig.FADE_BARS * BAR_SECONDS, Enum.EasingStyle.Linear),
						{ Volume = 1 }
					)
					fadeTween:Play()
				end
			end
			if not ok then
				break
			end
			openWindow(t0 + StemsConfig.SETTLE_SECONDS + offset, t0 + LOOP_SECONDS - 0.05, t0, offsetMs, scheduled)
			waitUntil(t0 + LOOP_SECONDS)
			local s = closeWindow()
			if not scheduled then
				rewind()
			end
			worst = math.max(worst, s.maxErr)
			loopsDone = k
			addResult(fmtLoop(mode, offsetMs, k, s))
			waitUntil(mixer() + StemsConfig.GAP_SECONDS)
		end
	end
	rewind()
	faderB.Volume = 1

	local verdict
	if loopsDone < StemsConfig.LOOPS then
		verdict = string.format("INCOMPLETE (%d/%d loops)", loopsDone, StemsConfig.LOOPS)
	elseif offsetMs ~= 0 then
		verdict = string.format("CALIBRATION: meter should read about %+d ms", offsetMs)
	elseif worst <= StemsConfig.PASS_DRIFT_MS then
		verdict = string.format("PASS (<= %d ms)", StemsConfig.PASS_DRIFT_MS)
	else
		verdict = string.format("FAIL (> %d ms)", StemsConfig.PASS_DRIFT_MS)
	end
	local summary = string.format(
		"== %s offset %d ms: worst |drift - offset| %.1f ms over %d loops -> %s",
		mode,
		offsetMs,
		worst,
		loopsDone,
		verdict
	)
	table.insert(summaries, summary)
	addResult(summary)
end

local function startRun(plan: { { mode: Mode, offset: number } })
	if running then
		return
	end
	if loadState ~= "ready" then
		addResult("RUN ignored: stems not ready (" .. loadState .. ")")
		return
	end
	running = true
	abort = false
	task.spawn(function()
		for _, step in plan do
			if abort then
				break
			end
			runMode(step.mode, step.offset)
		end
		running = false
		status = if abort then "stopped" else "done (press RESULTS)"
	end)
end

-- UI ------------------------------------------------------------------------------------

local INK = Color3.fromRGB(28, 31, 59)
local MONO = Font.fromEnum(Enum.Font.RobotoMono)

local gui = Instance.new("ScreenGui")
gui.Name = "StemsGui"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

local panel = Instance.new("TextLabel")
panel.Name = "Panel"
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Size = UDim2.new(1, -230, 0, 0)
panel.Position = UDim2.fromOffset(8, 8)
panel.BackgroundColor3 = INK
panel.BackgroundTransparency = 0.25
panel.TextColor3 = Color3.new(1, 1, 1)
panel.FontFace = MONO
panel.TextSize = 12
panel.TextXAlignment = Enum.TextXAlignment.Left
panel.TextYAlignment = Enum.TextYAlignment.Top
panel.TextWrapped = true
panel.Text = "Stem spike starting..."
local panelPad = Instance.new("UIPadding")
panelPad.PaddingLeft = UDim.new(0, 6)
panelPad.PaddingRight = UDim.new(0, 6)
panelPad.PaddingTop = UDim.new(0, 4)
panelPad.PaddingBottom = UDim.new(0, 4)
panelPad.Parent = panel
local panelMax = Instance.new("UISizeConstraint")
panelMax.MaxSize = Vector2.new(560, math.huge)
panelMax.Parent = panel
panel.Parent = gui

local grid = Instance.new("Frame")
grid.Name = "Buttons"
grid.AnchorPoint = Vector2.new(1, 0)
grid.Position = UDim2.new(1, -8, 0, 8)
grid.Size = UDim2.fromOffset(206, 0)
grid.AutomaticSize = Enum.AutomaticSize.Y
grid.BackgroundTransparency = 1
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(100, 40)
gridLayout.CellPadding = UDim2.fromOffset(6, 6)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
grid.Parent = gui

local function makeButton(order: number, text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.BackgroundColor3 = Color3.fromRGB(58, 53, 96)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	b.TextSize = 14
	b.Text = text
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = grid
	return b
end

local function overlayBox(name: string, editable: boolean): TextBox
	local box = Instance.new("TextBox")
	box.Name = name
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.42, 0.55)
	box.Size = UDim2.new(0.8, -200, 0.72, 0)
	box.BackgroundColor3 = INK
	box.BackgroundTransparency = 0.05
	box.TextColor3 = Color3.new(1, 1, 1)
	box.FontFace = MONO
	box.TextSize = 11
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.MultiLine = true
	box.ClearTextOnFocus = false
	box.TextEditable = editable -- editable so a phone can long-press, Select All, Copy
	box.TextWrapped = false
	box.ClipsDescendants = true
	box.Visible = false
	box.Parent = gui
	return box
end

local resultsBox = overlayBox("Results", true)
local helpBox = overlayBox("Help", false)
helpBox.TextWrapped = true
helpBox.Text = table.concat({
	"S4 STEMS: HOW TO LISTEN AND WHAT TO REPORT",
	"Wear headphones. Both players play the same sound by default:",
	"  aligned = ONE sound, a bit louder;  1-10 ms off = hollow, phasey 'jet';",
	"  20+ ms = doubled click / flam;  40 ms = a clear echo.",
	"Ear test first: OFFSET 20, MODE SCHEDULED, RUN. The meter should read",
	"about +20 ms and you should hear the doubling. Then set OFFSET 0.",
	"",
	"Report back (one block per device):",
	"1. Device, OS version, Roblox app version (PC: Windows/macOS).",
	"2. Press RUN ALL (about 3 min), then RESULTS: copy or screenshot it.",
	"3. For each mode: did it sound like one sound in all 8 loops? Any",
	"   loop where it started to flam or echo? Clicks at loop starts?",
	"4. OFFSET 20 test: meter reading, and could you hear it?",
	"5. FALLBACK: was the fade-in of stem B smooth (no clicks or jumps)?",
	"6. Any ERROR lines, or stems that never got ready.",
	"7. If you pasted Creator Store ids in StemsConfig: which ids, did",
	"   they load, did the two tracks sound in time with each other?",
	"Pass (MASTERPLAN S4): no audible drift over 8 loops with Play(atTime).",
}, "\n")

local function resultsText(): string
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.zero
	local lines = {
		"HEIST YOURSELF stem spike (S4)  " .. DateTime.now():FormatUniversalTime("YYYY-MM-DD HH:mm", "en-us") .. " UTC",
		string.format(
			"screen %dx%d  touch %s  mixer clock %s  loop %.3f s (%d bars @ %d BPM)",
			math.floor(size.X),
			math.floor(size.Y),
			if UserInputService.TouchEnabled then "yes" else "no",
			if mixerOk then "GetMixerTime" else "os.clock FALLBACK",
			LOOP_SECONDS,
			StemsConfig.LOOP_BARS,
			StemsConfig.TRACK_BPM
		),
		string.format("A %s (%.3f s)  B %s (%.3f s)", StemsConfig.STEM_A, lenA, StemsConfig.STEM_B, lenB),
		"drift = A.TimePosition - B.TimePosition, |err| = |drift - offset|, A-vs-mixer = mean/max",
		"--- summaries ---",
	}
	for _, s in summaries do
		table.insert(lines, s)
	end
	table.insert(lines, "--- every loop ---")
	for _, r in results do
		table.insert(lines, r)
	end
	return table.concat(lines, "\n")
end

local modeButton: TextButton
local offsetButton: TextButton

local function refreshButtons()
	modeButton.Text = MODES[modeIndex]
	offsetButton.Text = "OFFSET " .. StemsConfig.OFFSETS_MS[offsetIndex] .. " ms"
end

makeButton(1, "RUN", function()
	startRun({ { mode = MODES[modeIndex], offset = StemsConfig.OFFSETS_MS[offsetIndex] } })
end)
makeButton(2, "STOP", function()
	abort = true
end)
modeButton = makeButton(3, "MODE", function()
	modeIndex = modeIndex % #MODES + 1
	refreshButtons()
end)
offsetButton = makeButton(4, "OFFSET", function()
	offsetIndex = offsetIndex % #StemsConfig.OFFSETS_MS + 1
	refreshButtons()
end)
makeButton(5, "RUN ALL", function()
	startRun({
		{ mode = "SCHEDULED", offset = 0 },
		{ mode = "CONTINUOUS", offset = 0 },
		{ mode = "FALLBACK", offset = 0 },
	})
end)
makeButton(6, "HELP", function()
	resultsBox.Visible = false
	helpBox.Visible = not helpBox.Visible
end)
makeButton(7, "RESULTS", function()
	helpBox.Visible = false
	resultsBox.Text = resultsText()
	resultsBox.Visible = not resultsBox.Visible
end)
refreshButtons()

gui.Parent = player:WaitForChild("PlayerGui")

local function updatePanel()
	local lines = {
		"S4 STEM ALIGNMENT SPIKE  (HELP = how to listen, what to report)",
		string.format(
			"stems %s  A %s %.2f s  B %s %.2f s%s",
			loadState,
			if stemA.IsReady then "ready" else "...",
			lenA,
			if stemB.IsReady then "ready" else "...",
			lenB,
			if comparable then "" else "  (LENGTHS DIFFER: drift only valid before a wrap)"
		),
		string.format(
			"mixer %s  loop %.2f s = %d bars @ %d BPM  x%d",
			if mixerOk then string.format("%.2f", mixer()) else "UNAVAILABLE (os.clock)",
			LOOP_SECONDS,
			StemsConfig.LOOP_BARS,
			StemsConfig.TRACK_BPM,
			StemsConfig.LOOPS
		),
		string.format(
			"mode %s  offset %d ms  status: %s",
			MODES[modeIndex],
			StemsConfig.OFFSETS_MS[offsetIndex],
			status
		),
		string.format(
			"live: drift %+.1f ms  A %.3f  B %.3f  faderB %.2f  playing %s/%s",
			stats.last,
			stemA.TimePosition,
			stemB.TimePosition,
			faderB.Volume,
			tostring(stemA.IsPlaying),
			tostring(stemB.IsPlaying)
		),
		"--- recent ---",
	}
	local first = math.max(1, #results - 9)
	for i = first, #results do
		table.insert(lines, results[i])
	end
	panel.Text = table.concat(lines, "\n")
end

-- Boot ----------------------------------------------------------------------------------

task.spawn(function()
	if waitReady() then
		lenA = lengthOf(stemA)
		lenB = lengthOf(stemB)
		comparable = math.abs(lenA - lenB) <= StemsConfig.LENGTH_TOLERANCE
		loadState = "ready"
		status = "idle: press RUN ALL (or HELP first)"
		addResult(string.format("stems ready: A %.3f s, B %.3f s, mixer clock %s", lenA, lenB, tostring(mixerOk)))
	else
		loadState = "NOT READY"
		status = "stems did not load: check the asset ids in StemsConfig and their permissions"
		addResult(
			string.format(
				"ERROR stems not ready after %d s (A ready %s, B ready %s)",
				StemsConfig.LOAD_TIMEOUT,
				tostring(stemA.IsReady),
				tostring(stemB.IsReady)
			)
		)
	end
end)

while true do
	task.wait(1 / StemsConfig.READOUT_HZ)
	updatePanel()
end
