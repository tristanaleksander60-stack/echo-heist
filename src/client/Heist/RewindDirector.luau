--!strict
-- Heist/RewindDirector: the Rewind, the signature moment (MASTERPLAN §7.1, §0 C4).
-- The server waits the chosen length before the run clock starts; this plays the
-- picture inside that window, driven by one RenderStepped timeline (interruption-safe:
-- a new play() simply restarts it).
--
-- Standard (1.8 s):  0.00 clack + the 25 % white flash, held through the 66 ms freeze
--                    0.10-1.35 tape scrub: saturation -0.8, cyan tint, Blur 6, VHS bands,
--                    scanlines + tracking line, "REWIND", every clone's path reels backwards
--                    (onReel + the path trails), FOV 70 -> 64, the world muffled
--                    1.35-1.55 grade snaps back, clones "tape print" in; clunk + arpeggio
--                    1.55-1.80 "RUN n" stamps in (scale 1.25 -> 1.0, Back Out)
-- Quick (1.0 s):     the same scaled, without the path reel (from the 4th rewind, and L1).
-- Reduced (0.8 s):   a crossfade and the stamp, no motion, no blur, no FOV change.
-- Intro (run 1):     the stamp only.
-- Effects live under CurrentCamera, not Lighting (§7.1).
-- The finish (PLAN_STEAM_PLUS §4.5, POLISH item 19, roblox_quality §5.2; numbers in
-- Config.Moments.REWIND), all inside the same windows:
--   * a 66 ms freeze opens it (the heavy beat: the flash holds while Heist/MomentDirector freezes the
--     views; premium F3); the flash goes through the juice governor's flash limit;
--   * Standard: each clone's path, sampled from its recording (Shared/Heist/MomentPlan), is drawn as a
--     crew-colour Beam trail that reels back with the scrub, eaten from its end as the clone rewinds
--     (pooled attachments and beams on Terrain, no particles; a coarser path from
--     Config.Moments.LOW_TIER: the low-tier substitute);
--   * scanline bands (one gradient frame, no image) rolling down, plus a VHS tracking line that tears;
--   * the world muffled: Sound.muffle (an 800 Hz low-pass on SFX + Ambience) from the start to the snap.
-- Reduced motion stays the plain crossfade (no trails, bands, tracking line or FOV).
-- Sound (docs/AUDIO.md §4, §9 items 8-12): the clack plays on input (HeistClient);
-- here AudioDirector.rewind() (tape-stop dive) at the start, RewindWhirr + the
-- pre-reversed RewindStinger with the scrub, RewindClunk + the clone arpeggio on the
-- snap, RunStamp with the stamp, and AudioDirector.go(clones) when control returns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Strings = require(Shared:WaitForChild("Heist"):WaitForChild("Strings"))
local MomentPlan = require(Shared:WaitForChild("Heist"):WaitForChild("MomentPlan"))
local Sampler = require(Shared:WaitForChild("Rec"):WaitForChild("Sampler"))

local MomentDirector = require(script.Parent:WaitForChild("MomentDirector"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local RewindDirector = {}

local CYAN = Color3.fromRGB(150, 225, 255)
local BASE_FOV = 70
local REEL_FOV = 64
local R = Config.Moments.REWIND

local function easeBackOut(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- What the trails are drawn from (HeistClient): the instance origin, the level floor, the time the
-- last run ended (where the reel starts) and the coming run's clones (EchoView.paths).
export type TrailSource = () -> (Vector3, number, number, { { actor: any, rec: any, hue: Color3 } })

type Trail = { points: { MomentPlan.TrailPoint }, atts: { Attachment }, beams: { Beam } }

-- fovKick: the camera's FOV owner (Heist/CameraDirector.setFovKick, vault "one FOV owner
-- summing effects"); the reel's FOV dip goes through it as an offset. Without one the
-- director writes the FOV itself around BASE_FOV. trails: the path trails' source (none = no trails).
function RewindDirector.new(gui: ScreenGui, fovKick: ((deg: number) -> ())?, trails: TrailSource?): any
	local director = {}
	local playing = false
	local t0 = 0
	local length = 1.8
	local kind = "Standard"
	local onReel: ((u: number) -> ())? = nil
	local onDone: (() -> ())? = nil
	local stage = 0
	local clones = 0
	local flashOn = false
	local blurAllowed = true
	local tierNow = 1
	local muffled = false
	local camera = workspace.CurrentCamera

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "EH_Rewind"
	cc.Enabled = false
	local blur = Instance.new("BlurEffect")
	blur.Name = "EH_RewindBlur"
	blur.Size = 0
	blur.Enabled = false
	if camera then
		cc.Parent = camera
		blur.Parent = camera
	end

	local overlay = Instance.new("Frame")
	overlay.Name = "Rewind"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.ZIndex = 50
	overlay.Active = false
	overlay.Parent = gui

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Palette.white
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 51
	flash.Parent = overlay

	local fade = Instance.new("Frame")
	fade.Name = "Fade"
	fade.BackgroundColor3 = Palette.ink
	fade.BackgroundTransparency = 1
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 51
	fade.Parent = overlay

	local bands: { Frame } = {}
	for i = 1, 3 do
		local b = Instance.new("Frame")
		b.Name = "Band"
		b.BackgroundColor3 = Palette.white
		b.BackgroundTransparency = 0.85
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, 0, 0, 10 + i * 6)
		b.ZIndex = 52
		b.Visible = false
		b.Parent = overlay
		bands[i] = b
	end

	-- Scanline bands: one ink frame (1 + period) screens tall whose gradient holds SCAN_BANDS soft dark
	-- bands; it rolls down one band period and wraps, so the loop is seamless.
	local period = 1 / (R.SCAN_BANDS - 1)
	local scan = Instance.new("Frame")
	scan.Name = "Scanlines"
	scan.BackgroundColor3 = Palette.ink
	scan.BackgroundTransparency = 0
	scan.BorderSizePixel = 0
	scan.Size = UDim2.fromScale(1, 1 + period)
	scan.ZIndex = 52
	scan.Visible = false
	scan.Parent = overlay
	local scanGrad = Instance.new("UIGradient")
	scanGrad.Rotation = 90
	local keys = {}
	for i = 0, 2 * R.SCAN_BANDS do
		table.insert(keys, NumberSequenceKeypoint.new(i / (2 * R.SCAN_BANDS), if i % 2 == 0 then 1 else R.SCAN_ALPHA))
	end
	scanGrad.Transparency = NumberSequence.new(keys)
	scanGrad.Parent = scan

	-- The VHS tracking line: a thin torn bright strip sweeping down, a dark shadow under it.
	local tracking = Instance.new("Frame")
	tracking.Name = "Tracking"
	tracking.BackgroundColor3 = Palette.white
	tracking.BackgroundTransparency = 0.45
	tracking.BorderSizePixel = 0
	tracking.Size = UDim2.new(1, R.TRACKING_JITTER * 2, 0, R.TRACKING_HEIGHT)
	tracking.ZIndex = 53
	tracking.Visible = false
	tracking.Parent = overlay
	local tear = Instance.new("UIGradient")
	tear.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.17, 0.75),
		NumberSequenceKeypoint.new(0.31, 0.1),
		NumberSequenceKeypoint.new(0.48, 0.6),
		NumberSequenceKeypoint.new(0.63, 0),
		NumberSequenceKeypoint.new(0.8, 0.7),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	tear.Parent = tracking
	local trackShadow = Instance.new("Frame")
	trackShadow.Name = "Shadow"
	trackShadow.BackgroundColor3 = Palette.ink
	trackShadow.BackgroundTransparency = 0.6
	trackShadow.BorderSizePixel = 0
	trackShadow.Position = UDim2.fromScale(0, 1)
	trackShadow.Size = UDim2.new(1, 0, 0, R.TRACKING_HEIGHT * 2)
	trackShadow.ZIndex = 53
	trackShadow.Parent = tracking

	-- Path trails: pooled attachments + Beams on Terrain (built on the first Standard rewind).
	local trailPool: { Trail } = {}
	local trailsLive: { Trail } = {}
	local trailOrigin = Vector3.zero
	local trailEnd = 0

	local function newTrail(n: number): Trail
		local host = workspace.Terrain
		local t: Trail = { points = {}, atts = {}, beams = {} }
		for i = 1, n do
			local a = Instance.new("Attachment")
			a.Name = "EH_RewindTrail"
			a.Parent = host
			t.atts[i] = a
		end
		for i = 1, n - 1 do
			local b = Instance.new("Beam")
			b.Name = "EH_RewindTrail"
			b.Attachment0 = t.atts[i]
			b.Attachment1 = t.atts[i + 1]
			b.FaceCamera = true
			b.Segments = 1
			b.Width0 = R.TRAIL_WIDTH
			b.Width1 = R.TRAIL_WIDTH
			b.LightEmission = R.TRAIL_LIGHT_EMISSION
			b.LightInfluence = 0
			b.Transparency = NumberSequence.new(R.TRAIL_TRANSPARENCY)
			b.Enabled = false
			b.Parent = host
			t.beams[i] = b
		end
		return t
	end

	local function hideTrails()
		for _, t in trailsLive do
			for _, b in t.beams do
				b.Enabled = false
			end
			table.insert(trailPool, t)
		end
		table.clear(trailsLive)
	end

	local function trailPoints(): number
		return if tierNow >= Config.Moments.LOW_TIER then R.TRAIL_POINTS_LOW else R.TRAIL_POINTS
	end

	-- Samples every clone's path over the last run (0 .. reelEnd) into a pooled trail.
	local function buildTrails()
		hideTrails()
		if not trails then
			return
		end
		local ok, origin, floorY, reelEnd, paths = pcall(trails)
		if not ok or type(paths) ~= "table" or type(reelEnd) ~= "number" or reelEnd <= 0 then
			return
		end
		trailOrigin, trailEnd = origin, reelEnd
		local n = trailPoints()
		local first = math.max(1, #paths - R.TRAIL_MAX_CLONES + 1) -- the newest runs when there are more
		for i = first, #paths do
			local p = paths[i]
			local rec = p.rec
			if not rec then
				continue
			end
			local pts = MomentPlan.sampleTrail(function(t: number): (number?, number, number)
				local x, _, z = Sampler.at(rec, t)
				return x, floorY + R.TRAIL_LIFT, z
			end, math.min(reelEnd, Sampler.duration(rec)), n)
			if #pts < 2 then
				continue
			end
			local t = table.remove(trailPool)
			if not t or #t.atts ~= n then
				t = newTrail(n)
			end
			t.points = pts
			for k, a in t.atts do
				local q = pts[math.min(k, #pts)]
				a.WorldPosition = origin + Vector3.new(q.x, q.y, q.z)
			end
			local color = ColorSequence.new(p.hue)
			for k, b in t.beams do
				b.Color = color
				b.Enabled = k < #pts
			end
			table.insert(trailsLive, t)
		end
	end

	-- The reel at head time `head`: each trail is drawn from its start to the head (MomentPlan.trailHead).
	local function reelTrails(head: number)
		for _, t in trailsLive do
			local pts = t.points
			local k, frac = MomentPlan.trailHead(pts, head)
			for j, b in t.beams do
				local on = j < k or (j == k and frac > 0)
				if b.Enabled ~= on then
					b.Enabled = on
				end
			end
			if k >= 1 and k < #pts then
				local a, b = pts[k], pts[k + 1]
				t.atts[k + 1].WorldPosition = trailOrigin
					+ Vector3.new(a.x + (b.x - a.x) * frac, a.y + (b.y - a.y) * frac, a.z + (b.z - a.z) * frac)
			end
		end
	end

	local function setMuffle(on: boolean)
		if on ~= muffled then
			muffled = on
			Sound.muffle(on)
		end
	end

	local font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	local arrows = Instance.new("TextLabel")
	arrows.Name = "Arrows"
	arrows.BackgroundTransparency = 1
	arrows.AnchorPoint = Vector2.new(0, 0)
	arrows.Position = UDim2.fromOffset(24, 24)
	arrows.Size = UDim2.fromOffset(280, 64)
	arrows.FontFace = font
	arrows.TextSize = 48
	arrows.TextXAlignment = Enum.TextXAlignment.Left
	arrows.TextColor3 = Palette.white
	Ui.textStroke(arrows, 3)
	arrows.Text = Strings.REWIND_BANNER
	arrows.ZIndex = 53
	arrows.Visible = false
	arrows.Parent = overlay
	Ui.iconWord(arrows, "rewind", "left", 48)

	local stamp = Instance.new("TextLabel")
	stamp.Name = "Stamp"
	stamp.BackgroundTransparency = 1
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Position = UDim2.fromScale(0.5, 0.42)
	stamp.Size = UDim2.fromOffset(420, 110)
	stamp.FontFace = Theme.FONT_DISPLAY -- stamps of <= 3 words: the display face (PLAN §3.2, Config.Ui.DISPLAY_FACE)
	stamp.TextSize = 88
	stamp.TextColor3 = Palette.white
	Ui.textStroke(stamp, math.floor(88 * Config.Ui.DISPLAY_STROKE + 0.5))
	stamp.Text = ""
	stamp.ZIndex = 54
	stamp.Visible = false
	stamp.Parent = overlay
	local stampScale = Instance.new("UIScale")
	stampScale.Parent = stamp

	local function setFov(kick: number)
		if fovKick then
			fovKick(kick)
			return
		end
		local cam = workspace.CurrentCamera
		if cam then
			cam.FieldOfView = BASE_FOV + kick
		end
	end

	local function hideScrub()
		for _, b in bands do
			b.Visible = false
		end
		scan.Visible = false
		tracking.Visible = false
	end

	local function reset()
		cc.Enabled = false
		blur.Enabled = false
		blur.Size = 0
		flash.BackgroundTransparency = 1
		fade.BackgroundTransparency = 1
		arrows.Visible = false
		hideScrub()
		hideTrails()
		setMuffle(false)
		stamp.Visible = false
		overlay.Visible = false
		if kind ~= "Reduced" then
			setFov(0)
		end
	end

	-- kind: "Standard" | "Quick" | "Reduced" | "Intro"; length in seconds; reel(u) is
	-- called with u in [0, 1] while the paths reel back (Standard only); cloneCount is
	-- the clones of the coming run (arpeggio notes, Crew Layers tier on GO).
	function director.play(
		k: string,
		len: number,
		runIndex: number,
		reel: ((u: number) -> ())?,
		done: (() -> ())?,
		cloneCount: number?
	)
		kind = k
		length = math.max(len, 0.3)
		onReel = reel
		onDone = done
		clones = math.max(0, math.floor(cloneCount or 0))
		t0 = os.clock()
		stage = 0
		playing = true
		overlay.Visible = true
		stamp.Text = Strings.run(runIndex)
		stamp.TextColor3 = Palette.white
		stamp.Visible = false
		local cam = workspace.CurrentCamera
		if cam and (cc.Parent ~= cam) then
			cc.Parent = cam
			blur.Parent = cam
		end
		hideTrails()
		if k ~= "Intro" then
			Sound.rewind()
			if R.MUFFLE then
				setMuffle(true)
			end
		end
		flashOn = k ~= "Intro" and k ~= "Reduced" and MomentDirector.allowFlash(t0)
		if k == "Standard" then
			buildTrails()
		end
	end

	-- The runtime performance tier turns the rewind blur off (§6.3: blur is the costly part).
	function director.setBlurAllowed(on: boolean)
		blurAllowed = on
		if not on then
			blur.Enabled = false
		end
	end

	-- The runtime performance tier: from Config.Moments.LOW_TIER the trails take the coarse path.
	function director.setTier(tier: number)
		tierNow = tier
	end

	function director.isPlaying(): boolean
		return playing
	end

	-- Path trails drawn right now (tests, diagnostics): trails and enabled beams.
	function director.trailStats(): (number, number)
		local beams = 0
		for _, t in trailsLive do
			for _, b in t.beams do
				if b.Enabled then
					beams += 1
				end
			end
		end
		return #trailsLive, beams
	end

	local function step()
		if not playing then
			return
		end
		local e = os.clock() - t0
		local u = e / length -- 0..1 over the whole transition
		local scrubFrom, scrubTo, snapTo = 0.10 / 1.8, 1.35 / 1.8, 1.55 / 1.8
		if kind == "Intro" then
			scrubFrom, scrubTo, snapTo = 0, 0, 0.35
		end
		if kind == "Reduced" then
			-- Crossfade: fade to ink and back, then the stamp (no motion, no blur).
			local f = if u < 0.5 then u / 0.5 else 1 - (u - 0.5) / 0.5
			fade.BackgroundTransparency = 1 - 0.6 * math.clamp(f, 0, 1)
			if u >= 0.5 and stage < 2 then
				stage = 2
				setMuffle(false)
				Sound.play("RewindClunk")
				Sound.arpeggio(clones)
			end
		elseif kind ~= "Intro" then
			-- The heavy beat: the 25 % white flash holds through the 66 ms freeze.
			flash.BackgroundTransparency = if flashOn and e < Config.Moments.HIT_STOP_SECONDS then R.FLASH_ALPHA else 1
			local scrub = u >= scrubFrom and u < scrubTo
			cc.Enabled = scrub
			blur.Enabled = scrub and blurAllowed
			arrows.Visible = scrub
			if scrub then
				if stage < 1 then
					stage = 1
					Sound.play("RewindWhirr")
					Sound.play("RewindStinger")
				end
				local s = (u - scrubFrom) / (scrubTo - scrubFrom)
				cc.Saturation = -0.8
				cc.TintColor = CYAN
				cc.Contrast = 0.15
				blur.Size = 6
				for i, b in bands do
					b.Visible = true
					local y = (s * (1.3 + i * 0.4) + i * 0.27) % 1
					b.Position = UDim2.fromScale(0, y)
				end
				-- scanlines roll down one period and wrap; the tracking line sweeps and tears sideways
				scan.Visible = true
				scan.Position = UDim2.fromScale(0, ((e * R.SCAN_SPEED) % period) - period)
				tracking.Visible = true
				local sweep = (e / R.TRACKING_SECONDS) % 1
				local jitter = math.floor(math.sin(e * 53) * math.sin(e * 31) * R.TRACKING_JITTER + 0.5)
				tracking.Position = UDim2.new(0, jitter - R.TRACKING_JITTER, sweep, 0)
				setFov((REEL_FOV - BASE_FOV) * math.sin(math.min(s, 1) * math.pi))
				if onReel and kind == "Standard" then
					onReel(math.clamp(s, 0, 1))
				end
				if #trailsLive > 0 then
					reelTrails(trailEnd * (1 - math.clamp(s, 0, 1)))
				end
			else
				hideScrub()
				if u >= scrubTo then
					setFov(0)
					hideTrails()
				end
			end
			if u >= scrubTo and stage < 2 then
				stage = 2
				setMuffle(false) -- the snap: the world comes back
				Sound.play("RewindClunk")
				Sound.arpeggio(clones)
			end
		end
		-- "RUN n" stamp in the last part (Back Out scale, no motion under Reduced).
		if u >= snapTo then
			if not stamp.Visible then
				Sound.play("RunStamp")
			end
			stamp.Visible = true
			local s = math.clamp((u - snapTo) / math.max(1 - snapTo, 0.01), 0, 1)
			stampScale.Scale = if kind == "Reduced" then 1 else 1.25 - 0.25 * easeBackOut(s)
			stamp.TextTransparency = 0
		end
		if u >= 1 then
			-- Control returns now (the run clock starts): release the reel at once,
			-- then hold the stamp briefly and clear.
			local cb = onDone
			onDone = nil
			onReel = nil
			if cb then
				cb()
			end
			if stage < 3 then
				stage = 3
				setMuffle(false)
				Sound.go(clones)
			end
			if e >= length + 0.35 then
				playing = false
				reset()
			else
				cc.Enabled = false
				blur.Enabled = false
				arrows.Visible = false
				fade.BackgroundTransparency = 1
				stamp.TextTransparency = (e - length) / 0.35
			end
		end
	end
	if RunService:IsClient() then
		RunService.RenderStepped:Connect(step)
	end
	-- Tests on a server (no RenderStepped) step it by hand.
	director.step = step

	-- Text stamps outside the rewind ("BUSTED", "8 OF ME", "HEIST COMPLETE"). `pop`
	-- lands it from 125 % (Back Out); callers pass false under reduced motion.
	function director.stamp(text: string, color: Color3, hold: number, pop: boolean?)
		if playing then
			return
		end
		overlay.Visible = true
		stamp.Visible = true
		stamp.Text = text
		stamp.TextColor3 = color
		stamp.TextTransparency = 0
		stampScale.Scale = 1
		Sound.play("RunStamp")
		if pop then
			stampScale.Scale = 1.25
			local started = os.clock()
			local conn: RBXScriptConnection? = nil
			conn = RunService.RenderStepped:Connect(function()
				local s = math.clamp((os.clock() - started) / 0.25, 0, 1)
				stampScale.Scale = if playing then 1 else 1.25 - 0.25 * easeBackOut(s)
				if s >= 1 and conn then
					conn:Disconnect()
				end
			end)
		end
		local token = os.clock()
		director._stampToken = token
		task.delay(hold, function()
			if director._stampToken == token and not playing then
				stamp.Visible = false
				stamp.TextColor3 = Palette.white
				overlay.Visible = false
			end
		end)
	end

	function director.stop()
		playing = false
		reset()
	end

	return director
end

return RewindDirector
