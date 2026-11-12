--!strict
-- Heist/RewindDirector: the Rewind, the signature moment (MASTERPLAN §7.1, §0 C4).
-- The server waits the chosen length before the run clock starts; this plays the
-- picture inside that window, driven by one RenderStepped timeline (interruption-safe:
-- a new play() simply restarts it).
--
-- Standard (1.8 s):  0.00 clack + 0.06 s white flash at 25%
--                    0.10-1.35 tape scrub: saturation -0.8, cyan tint, Blur 6, VHS bands,
--                    "REWIND", every clone's path reels backwards (onReel), FOV 70 -> 64
--                    1.35-1.55 grade snaps back, clones "tape print" in; clunk + arpeggio
--                    1.55-1.80 "RUN n" stamps in (scale 1.25 -> 1.0, Back Out)
-- Quick (1.0 s):     the same scaled, without the path reel (from the 4th rewind, and L1).
-- Reduced (0.8 s):   a crossfade and the stamp, no motion, no blur, no FOV change.
-- Intro (run 1):     the stamp only.
-- Effects live under CurrentCamera, not Lighting (§7.1).
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

local Sound = require(script.Parent:WaitForChild("Sound"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local RewindDirector = {}

local CYAN = Color3.fromRGB(150, 225, 255)
local BASE_FOV = 70
local REEL_FOV = 64

local function easeBackOut(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- fovKick: the camera's FOV owner (Heist/CameraDirector.setFovKick, vault "one FOV owner
-- summing effects"); the reel's FOV dip goes through it as an offset. Without one the
-- director writes the FOV itself around BASE_FOV.
function RewindDirector.new(gui: ScreenGui, fovKick: ((deg: number) -> ())?): any
	local director = {}
	local playing = false
	local t0 = 0
	local length = 1.8
	local kind = "Standard"
	local onReel: ((u: number) -> ())? = nil
	local onDone: (() -> ())? = nil
	local stage = 0
	local clones = 0
	local blurAllowed = true
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

	local function reset()
		cc.Enabled = false
		blur.Enabled = false
		blur.Size = 0
		flash.BackgroundTransparency = 1
		fade.BackgroundTransparency = 1
		arrows.Visible = false
		for _, b in bands do
			b.Visible = false
		end
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
		if k ~= "Intro" then
			Sound.rewind()
		end
	end

	-- The runtime performance tier turns the rewind blur off (§6.3: blur is the costly part).
	function director.setBlurAllowed(on: boolean)
		blurAllowed = on
		if not on then
			blur.Enabled = false
		end
	end

	function director.isPlaying(): boolean
		return playing
	end

	RunService.RenderStepped:Connect(function()
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
				Sound.play("RewindClunk")
				Sound.arpeggio(clones)
			end
		elseif kind ~= "Intro" then
			-- White flash for the first 0.06 s at 25%
			flash.BackgroundTransparency = if e < 0.06 then 0.75 else 1
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
				setFov((REEL_FOV - BASE_FOV) * math.sin(math.min(s, 1) * math.pi))
				if onReel and kind == "Standard" then
					onReel(math.clamp(s, 0, 1))
				end
			else
				for _, b in bands do
					b.Visible = false
				end
				if u >= scrubTo then
					setFov(0)
				end
			end
			if u >= scrubTo and stage < 2 then
				stage = 2
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
	end)

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
