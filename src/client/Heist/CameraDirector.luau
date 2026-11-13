--!strict
-- Heist/CameraDirector: the gameplay camera (PLAN_STEAM_PLUS §4.2 C0 + C1, decision D5; PLAN_FIRST_PERSON FP;
-- docs/audit/POLISH.md §4.5; numbers in Config.Heist.CAMERA, maths in Heist/CameraMath and Heist/FpMath).
--
-- Three modes, the player's pick (SETTINGS > CAMERA: FIRST PERSON / DIORAMA / CLASSIC), saved as the choice
-- setting `cameraMode` through Data.SetSetting (Heist/Settings; an old profile's classicCamera = true is read
-- as "classic" by Schema.sanitize):
--   "fp"       (default) head-locked at your eyes, FOV 70 (the fpFov comfort slider, 60-90), never rolls.
--              Mouse lock on PC while you play (MouseBehavior LockCenter; the cursor is free whenever a panel
--              or sheet is up, between runs, in the garage, in a presentation shot, or while Left Alt is held:
--              then a right-drag looks); touch drag outside the thumbstick looks; the right stick looks (with
--              a response curve). Your character turns to the look yaw (AutoRotate off while fp drives it, so
--              clones record where you looked). Subtle head bob and a landing dip, both off under reduced
--              motion; the plate "stomp" glance (glance()). Your own body is hidden (LocalTransparencyModifier
--              1) whenever the camera is at your eyes, so a moment that pulls the camera out shows you again.
--   "diorama"  pitch 52 (35..65), distance 30 (20..40), FOV 45, free yaw, you in the lower third (the
--              focus leads you by CameraMath.lead); drag (touch outside the thumbstick, right mouse) turns,
--              pinch / wheel / I O zoom, right stick turns.
--   "classic"  the Roblox follow cam, constrained: zoom 8 / 16 / 28, FOV 70.
-- Diorama and classic: walls between the camera and you fade to CAMERA.FADE.ALPHA within 0.1 s (a 10 Hz
-- Camera:GetPartsObscuringTarget scan, LocalTransparencyModifier, restored when clear, on suspend and on
-- every mode change). Every mode: the camera never rolls (every frame is a yaw and a pitch with world up);
-- reduced motion cuts the run-start beat.
--
-- Why "fp" and "diorama" are Scriptable and not the default camera constrained: the shots they need (a
-- lower-third offset, a pitch clamp, the run-start ease from the objective, the head bob, golden-frame
-- staging) cannot be layered on the default camera without undoing the offset every frame at Camera-1 (vault
-- "Camera Systems": an additive offset that is not undone drifts, because the default camera reads its next
-- look vector back from the current CFrame), and its Popper would pull the camera in front of the greybox
-- colliders. Movement stays camera-relative under Scriptable: the PlayerModule's ControlModule moves the
-- character with Player:Move(v, true), relative to CurrentCamera, whatever its CameraType; the touch
-- thumbstick and jump button are untouched, and a touch that starts on the thumbstick frame or on any GUI
-- never turns the camera. "classic" IS the default camera (CameraType Custom) with zoom limits.
--
-- Hand-over: other directors call suspend(who) before they take the camera and resume(who) when they give it
-- back (LineupDirector: "lineup"); while anything holds it, this module writes nothing (no CFrame, FOV or
-- CameraType), its fades are restored, your body shows and the cursor is free. RewindDirector never takes the
-- camera: its FOV dip arrives through setFovKick (one FOV owner). Short signature moments (Heist/
-- MomentDirector: the 8 OF ME pull-back, the busted view) do not take it either: setMomentShot blends their
-- shot over the frame by a weight, so they ease in and out of play (premium H1) while you keep control; the
-- golden staging and the level intro (setShot) replace the frame, then hand back to the run-start beat,
-- which in first person holds on the objective from above and eases into your eyes.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any

local CameraMath = require(script.Parent:WaitForChild("CameraMath"))
local FpMath = require(script.Parent:WaitForChild("FpMath"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local CameraDirector = {}

CameraDirector.SETTING = "cameraMode" -- Schema settings key ("fp" | "diorama" | "classic")
CameraDirector.FOV_SETTING = "fpFov"
CameraDirector.MODES = table.freeze({ "fp", "diorama", "classic" })

local RENDER_NAME = "EH_CameraDirector"

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function t3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

-- The objective of a level for the run-start beat (CameraMath.objective), level space.
CameraDirector.objectiveOf = CameraMath.objective

-- A yaw / downward-pitch camera frame at `pos` (never rolls).
function CameraDirector.lookFrame(pos: Vector3, yawDeg: number, pitchDeg: number): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0) * CFrame.Angles(-math.rad(pitchDeg), 0, 0)
end

local function validMode(m: any): boolean
	return type(m) == "string" and table.find(CameraDirector.MODES, m) ~= nil
end

function CameraDirector.new(state: any): any
	local C = Config.Heist.CAMERA
	local D, CL, F, FP = C.DIORAMA, C.CLASSIC, C.FADE, C.FP
	local player = Players.LocalPlayer
	local director = {}

	local mode: string = if validMode(C.DEFAULT_MODE) then C.DEFAULT_MODE else "fp"
	local holds: { [string]: boolean } = {}
	local yaw, pitch, distance = 0, D.PITCH, D.DISTANCE
	local focus: Vector3? = nil
	local kick = 0
	local beat: any = nil -- { t0, hold, ease, objective: Vector3 }
	local shotFn: (() -> (CFrame?, number?))? = nil -- golden-frame staging, the level intro
	-- A signature moment's shot (Heist/MomentDirector): CFrame, FOV and a weight 0..1 blended over
	-- whatever the camera would show (gameplay or the golden shot), so it eases in and out (H1).
	local momentFn: (() -> (CFrame?, number?, number))? = nil
	local classicHold: CFrame? = nil -- classic mode: where the default camera stood when a moment began
	local customReady = false -- classic: Custom + subject + zoom limits applied
	local listeners: { (string) -> () } = {}

	-- First person.
	local fpYaw, fpPitch = 0, FP.START_PITCH
	local headDy: number? = nil
	local bobPhase, bobAmp = 0, 0
	local dipX, dipV = 0, 0
	local wasAir = false
	local lastVy = 0
	local glanceT0 = -math.huge
	local cursorProbe: (() -> boolean)? = nil -- true while a HUD sheet or panel is up (Hud.sheetOpen)
	local freeHolds: { [string]: boolean } = {}
	local cursorLocked = false
	local autoRotateOff: Humanoid? = nil -- the humanoid whose AutoRotate fp turned off
	local bodyHidden = false
	local hiddenParts: { [Instance]: boolean } = {}
	local eyeCf: CFrame? = nil -- the fp eye this frame (before a moment's blend)

	---------------------------------------------------------------------------
	-- Helpers
	---------------------------------------------------------------------------
	local function rootOf(): BasePart?
		local char = player and player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function humanoidOf(): Humanoid?
		local char = player and player.Character
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	local function suspended(): boolean
		return next(holds) ~= nil
	end

	local function reduced(): boolean
		return state.reduced == true
	end

	local function fpFov(): number
		local v = tonumber(Settings.get(CameraDirector.FOV_SETTING))
		local range = Config.Data.SETTING_NUMBERS.fpFov
		return if v then math.clamp(v, range[1], range[2]) else FP.FOV
	end

	local function setZoomLimits(initial: boolean)
		if not player then
			return
		end
		if initial then
			-- The default camera starts at the zoom both limits pin, then the limits open up.
			player.CameraMinZoomDistance = CL.ZOOM
			player.CameraMaxZoomDistance = CL.ZOOM
			task.delay(0.1, function()
				player.CameraMaxZoomDistance = CL.ZOOM_MAX
				player.CameraMinZoomDistance = CL.ZOOM_MIN
			end)
		else
			player.CameraMaxZoomDistance = CL.ZOOM_MAX
			player.CameraMinZoomDistance = CL.ZOOM_MIN
		end
	end

	local function toCustom(cam: Camera)
		cam.CameraType = Enum.CameraType.Custom
		local hum = humanoidOf()
		if hum then
			cam.CameraSubject = hum
		end
	end

	---------------------------------------------------------------------------
	-- First person: your body, your facing, the cursor
	---------------------------------------------------------------------------
	local lastHideScan = -math.huge
	local function setBodyHidden(on: boolean)
		local char = player and player.Character
		local now = os.clock()
		-- A full scan when hiding starts, then twice a second (an accessory that loads late, the default
		-- camera's TransparencyController writing it back).
		if on and char and (not bodyHidden or now - lastHideScan >= FP.HIDE_RESCAN_SECONDS) then
			lastHideScan = now
			for _, d in char:GetDescendants() do
				if (d:IsA("BasePart") or d:IsA("Decal")) and (d :: any).LocalTransparencyModifier < 1 then
					(d :: any).LocalTransparencyModifier = 1
					hiddenParts[d] = true
				end
			end
		elseif not on then
			for inst in hiddenParts do
				if inst.Parent then
					(inst :: any).LocalTransparencyModifier = 0
				end
			end
			table.clear(hiddenParts)
		end
		if on ~= bodyHidden then
			bodyHidden = on
		end
		state.fpView = on -- Heist/Viewmodel, LookTarget, the HUD and WorldView read it
	end

	local function restoreAutoRotate()
		local hum = autoRotateOff
		if hum and hum.Parent then
			hum.AutoRotate = true
		end
		autoRotateOff = nil
	end

	local function setCursorLocked(on: boolean)
		if on then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		elseif cursorLocked then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
		cursorLocked = on
	end

	-- The cursor is locked only while you play a run in first person on a mouse, with nothing up.
	local function wantCursorLocked(): boolean
		if mode ~= "fp" or suspended() or shotFn ~= nil or next(freeHolds) ~= nil then
			return false
		end
		if not UserInputService.MouseEnabled or state.where ~= "heist" or state.phase ~= "Run" then
			return false
		end
		if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil then
			return false
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
			return false -- hold Left Alt for the cursor (the help chip, MENU)
		end
		local probe = cursorProbe
		if probe then
			local ok, open = pcall(probe)
			if ok and open then
				return false
			end
		end
		return true
	end

	-- Leaving first person (another mode, a suspend): body back, cursor free, AutoRotate back.
	local function leaveFp()
		setBodyHidden(false)
		restoreAutoRotate()
		setCursorLocked(false)
		eyeCf = nil
	end

	---------------------------------------------------------------------------
	-- Wall fade (diorama and classic)
	---------------------------------------------------------------------------
	type Fade = { alpha: number, target: number, written: number }
	local faded: { [BasePart]: Fade } = {}
	local fadeClock = 0

	local function fadeRoot(): Instance?
		if state.where == "heist" and state.folder then
			return state.folder
		end
		return workspace:FindFirstChild("Garage")
	end

	local function restoreFades()
		for part, f in faded do
			if math.abs(part.LocalTransparencyModifier - f.written) < 1e-3 then
				part.LocalTransparencyModifier = 0
			end
		end
		table.clear(faded)
	end

	local function scanFades(cam: Camera)
		local root = rootOf()
		local levelRoot = fadeRoot()
		local seen: { [BasePart]: boolean } = {}
		if root and levelRoot and player.Character then
			local points = {}
			for _, dy in F.POINTS do
				table.insert(points, root.Position + Vector3.new(0, dy, 0))
			end
			local ok, hits = pcall(cam.GetPartsObscuringTarget, cam, points, { player.Character })
			if ok then
				for _, inst in hits :: { Instance } do
					if
						inst:IsA("BasePart")
						and inst:IsDescendantOf(levelRoot)
						and inst.Transparency < F.INVISIBLE
						and (faded[inst] ~= nil or inst.LocalTransparencyModifier < 0.99)
					then
						seen[inst] = true
						local f = faded[inst]
						if f then
							f.target = F.ALPHA
						else
							faded[inst] = { alpha = inst.LocalTransparencyModifier, target = F.ALPHA, written = -1 }
						end
					end
				end
			end
		end
		for part, f in faded do
			if not seen[part] then
				f.target = 0
			end
		end
	end

	local function stepFades(dt: number)
		for part, f in faded do
			if not part.Parent then
				faded[part] = nil
				continue
			end
			if f.written >= 0 and math.abs(part.LocalTransparencyModifier - f.written) > 1e-3 then
				faded[part] = nil -- someone else owns it now (a pocketed door): hands off
				continue
			end
			local seconds = if f.target > f.alpha then F.IN_SECONDS else F.OUT_SECONDS
			local alpha = CameraMath.approach(f.alpha, f.target, dt, F.ALPHA, seconds)
			if alpha ~= f.written then
				part.LocalTransparencyModifier = alpha
				f.written = alpha
			end
			f.alpha = alpha
			if f.target == 0 and f.alpha <= 0 then
				faded[part] = nil
			end
		end
	end

	---------------------------------------------------------------------------
	-- Mode
	---------------------------------------------------------------------------
	local function notify()
		for _, fn in listeners do
			task.spawn(fn, mode)
		end
	end

	function director.mode(): string
		return mode
	end

	function director.onModeChanged(fn: (string) -> ())
		table.insert(listeners, fn)
	end

	function director.setMode(m: string, save: boolean?)
		if not validMode(m) or m == mode then
			return
		end
		local was = mode
		mode = m
		local cam = workspace.CurrentCamera
		local lookYaw = if cam then CameraMath.angles(t3(cam.CFrame.LookVector)) else yaw
		if mode == "diorama" then
			yaw = lookYaw -- keep looking the same way
			pitch, distance = D.PITCH, D.DISTANCE
		elseif mode == "fp" then
			fpYaw, fpPitch = lookYaw, FP.START_PITCH
			headDy = nil
		end
		if was == "fp" then
			leaveFp()
		end
		customReady = false
		restoreFades()
		if save then
			Settings.set(CameraDirector.SETTING, mode)
		end
		notify()
	end

	-- Steps to the next mode (fp -> diorama -> classic -> fp), saves it, returns it.
	function director.toggle(): string
		local i = table.find(CameraDirector.MODES, mode) or 1
		director.setMode(CameraDirector.MODES[i % #CameraDirector.MODES + 1], true)
		return mode
	end

	-- Another director takes the camera (LineupDirector "lineup"): this one writes nothing
	-- until every holder resumes.
	function director.suspend(who: string)
		holds[who] = true
		beat = nil
		restoreFades()
		leaveFp()
	end

	function director.resume(who: string)
		holds[who] = nil
		if suspended() then
			return
		end
		customReady = false
		focus = nil -- snap back onto you
		headDy = nil
		local cam = workspace.CurrentCamera
		if cam and mode == "classic" and not shotFn then
			toCustom(cam)
		end
	end

	function director.isSuspended(): boolean
		return suspended()
	end

	-- Additive FOV effect in degrees (RewindDirector's reel dip), clamped to FOV_KICK_MAX.
	function director.setFovKick(deg: number)
		kick = math.clamp(deg, -C.FOV_KICK_MAX, C.FOV_KICK_MAX)
	end

	-- C1: at a run start, ease from the objective (level space) to you inside the transition
	-- (it ends exactly when control returns); any input skips it; reduced motion cuts it.
	-- yawRad: the spawn's facing (the camera goes behind you, looking where you look).
	function director.frameRunStart(objective: { number }?, transition: number, yawRad: number?)
		if yawRad then
			yaw = math.deg(yawRad)
			pitch = math.clamp(pitch, D.PITCH_MIN, D.PITCH_MAX)
			fpYaw, fpPitch = math.deg(yawRad), FP.START_PITCH
		end
		focus = nil
		beat = nil
		if reduced() or not objective or suspended() then
			return
		end
		local hold, ease = CameraMath.beatWindow(transition, C.BEAT_SECONDS)
		if ease <= 0 then
			return
		end
		local origin: Vector3 = state.origin or Vector3.zero
		beat = { t0 = os.clock(), hold = hold, ease = ease, objective = origin + v3(objective) }
	end

	function director.beatActive(): boolean
		return beat ~= nil
	end

	-- The framing in use (yaw and pitch in degrees, distance, FOV), so a shot that hands back to the
	-- run-start beat (Heist/LevelIntro) frames its last stop exactly as the beat's first frame does. In first
	-- person that is the beat's view from above (FP.BEAT_*), which then eases into your eyes.
	function director.framing(): (number, number, number, number)
		if mode == "classic" then
			return yaw, CL.PITCH, CL.ZOOM, CL.FOV
		elseif mode == "fp" then
			return fpYaw, FP.BEAT_PITCH, FP.BEAT_DISTANCE, FP.BEAT_FOV
		end
		return yaw, pitch, distance, D.FOV
	end

	-- Golden-frame staging (Studio only, Heist/Scenario) and the level intro: fn returns the shot's CFrame and
	-- FOV every frame (nil = the gameplay camera this frame); nil fn clears it.
	function director.setShot(fn: (() -> (CFrame?, number?))?)
		shotFn = fn
		customReady = false
	end

	-- A signature moment (Heist/MomentDirector: 8 OF ME pull-back, the busted view): fn returns the
	-- moment's CFrame, FOV and weight (0 = the camera as it would be, 1 = the moment's shot) every
	-- frame; nil fn (or a nil CFrame) ends it. The golden shot, if any, stays underneath. Movement
	-- stays camera-relative; the moment never rolls (its CFrame is the caller's lookAt).
	function director.setMomentShot(fn: (() -> (CFrame?, number?, number))?)
		momentFn = fn -- step() hands the classic camera back to Custom once the moment is over
	end

	function director.momentActive(): boolean
		return momentFn ~= nil
	end

	-- First person: the plate "stomp" glance (a short look down and back; reduced motion: none).
	function director.glance()
		if mode == "fp" and not reduced() then
			glanceT0 = os.clock()
		end
	end

	-- First person: a HUD probe that says a sheet or panel is up (the cursor is freed for it).
	function director.setCursorProbe(fn: (() -> boolean)?)
		cursorProbe = fn
	end

	-- First person: free the cursor while `who` holds it (on = free).
	function director.freeCursor(who: string, on: boolean)
		freeHolds[who] = if on then true else nil
	end

	function director.cursorLocked(): boolean
		return cursorLocked
	end

	-- First person: true while the camera is at your eyes (your body hidden; the hands and the reticle show).
	function director.inEyes(): boolean
		return bodyHidden
	end

	-- First person: the look (yaw, downward pitch, degrees) and the head bob (phase, amplitude 0..1), so the
	-- viewmodel's walk bob stays in step with the camera's.
	function director.fpLook(): (number, number)
		return fpYaw, fpPitch
	end
	function director.bob(): (number, number)
		return bobPhase, if reduced() then 0 else bobAmp
	end

	---------------------------------------------------------------------------
	-- Input: touch drag / pinch, right mouse, mouse lock, wheel, I / O, right stick
	---------------------------------------------------------------------------
	local fingers: { [InputObject]: Vector2 } = {}
	local pinchFrom: { spread: number, zoom: number }? = nil
	local mouseTurning = false
	local pad = Vector2.zero

	local function controlling(): boolean
		return mode ~= "classic" and not suspended() and shotFn == nil
	end

	local function inThumbstick(pos: Vector2): boolean
		local pg = player and player:FindFirstChildOfClass("PlayerGui")
		local touchGui = pg and pg:FindFirstChild("TouchGui")
		local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
		if not frame then
			return false
		end
		local m = D.THUMBSTICK_MARGIN
		local inset = GuiService:GetGuiInset()
		for _, name in { "DynamicThumbstickFrame", "ThumbstickFrame" } do
			local f = frame:FindFirstChild(name)
			if f and f:IsA("GuiObject") and f.Visible then
				local p, s = f.AbsolutePosition, f.AbsoluteSize
				-- Touch positions and AbsolutePosition can differ by the top inset: test both.
				for _, dy in { 0, inset.Y } do
					local q = pos + Vector2.new(0, dy)
					if q.X >= p.X - m and q.X <= p.X + s.X + m and q.Y >= p.Y - m and q.Y <= p.Y + s.Y + m then
						return true
					end
				end
			end
		end
		return false
	end

	local function viewport(): Vector2
		local cam = workspace.CurrentCamera
		return if cam then cam.ViewportSize else Vector2.new(1280, 720)
	end

	local function mouseScale(): number
		local ok, s = pcall(function(): number
			return (UserSettings():GetService("UserGameSettings") :: any).MouseSensitivity
		end)
		return if ok and type(s) == "number" and s > 0 then s else 1
	end

	-- A drag (touch or right mouse) of dx / dy pixels.
	local function turn(dx: number, dy: number)
		local vp = viewport()
		if mode == "fp" then
			fpYaw, fpPitch = FpMath.turn(
				fpYaw,
				fpPitch,
				dx,
				dy,
				FP.TOUCH_YAW_PER_SCREEN / math.max(vp.X, 1),
				FP.TOUCH_PITCH_PER_SCREEN / math.max(vp.Y, 1),
				FP.PITCH_MIN,
				FP.PITCH_MAX
			)
			return
		end
		yaw = CameraMath.wrap(yaw - CameraMath.dragDegrees(dx, vp.X, D.YAW_PER_SCREEN))
		pitch = CameraMath.clamp(pitch + CameraMath.dragDegrees(dy, vp.Y, D.PITCH_PER_SCREEN), D.PITCH_MIN, D.PITCH_MAX)
	end

	local function skipBeat()
		if beat then
			beat = nil
			local cam = workspace.CurrentCamera
			if cam and mode == "classic" and not suspended() and not shotFn then
				toCustom(cam)
			end
		end
	end

	local function countFingers(): (number, Vector2?, Vector2?)
		local n, a, b = 0, nil, nil
		for _, p in fingers do
			n += 1
			if n == 1 then
				a = p
			elseif n == 2 then
				b = p
			end
		end
		return n, a, b
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Focus then
			skipBeat() -- C1: any input skips the run-start beat
		end
		if not controlling() or processed then
			return
		end
		if t == Enum.UserInputType.Touch then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if not inThumbstick(pos) then
				fingers[input] = pos
				pinchFrom = nil
			end
		elseif t == Enum.UserInputType.MouseButton2 and not cursorLocked then
			mouseTurning = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		local t = input.UserInputType
		if t == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			pad = Vector2.new(input.Position.X, input.Position.Y)
			return
		end
		if not controlling() then
			return
		end
		if t == Enum.UserInputType.Touch then
			local prev = fingers[input]
			if not prev then
				return
			end
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			fingers[input] = pos
			local n, a, b = countFingers()
			if n == 1 or mode == "fp" then
				turn(pos.X - prev.X, pos.Y - prev.Y) -- first person: no pinch; each finger looks
			elseif n >= 2 and a and b then
				local spread = (a - b).Magnitude
				local from = pinchFrom
				if not from then
					pinchFrom = { spread = spread, zoom = distance }
				else
					distance = CameraMath.pinch(from.zoom, from.spread, spread, D.ZOOM_MIN, D.ZOOM_MAX)
				end
			end
		elseif t == Enum.UserInputType.MouseMovement and mode == "fp" and cursorLocked then
			local per = FP.MOUSE_DEG_PER_PX * mouseScale()
			fpYaw, fpPitch =
				FpMath.turn(fpYaw, fpPitch, input.Delta.X, input.Delta.Y, per, per, FP.PITCH_MIN, FP.PITCH_MAX)
		elseif t == Enum.UserInputType.MouseMovement and mouseTurning then
			if mode == "fp" then
				local per = FP.MOUSE_DEG_PER_PX * mouseScale()
				fpYaw, fpPitch =
					FpMath.turn(fpYaw, fpPitch, input.Delta.X, input.Delta.Y, per, per, FP.PITCH_MIN, FP.PITCH_MAX)
			else
				turn(input.Delta.X, input.Delta.Y)
			end
		elseif t == Enum.UserInputType.MouseWheel and not processed and mode == "diorama" then
			local notches = input.Position.Z
			distance = CameraMath.clamp(distance * (1 - D.WHEEL_STEP * notches), D.ZOOM_MIN, D.ZOOM_MAX)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			fingers[input] = nil
			pinchFrom = nil
		elseif t == Enum.UserInputType.MouseButton2 and mouseTurning then
			mouseTurning = false
			if not cursorLocked then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		elseif t == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			pad = Vector2.zero
		end
	end)

	local function keysAndPad(dt: number)
		if not controlling() then
			return
		end
		if mode == "fp" then
			local sx = FpMath.stick(pad.X, FP.PAD_DEADZONE, FP.PAD_EXPONENT)
			local sy = FpMath.stick(pad.Y, FP.PAD_DEADZONE, FP.PAD_EXPONENT)
			if sx ~= 0 or sy ~= 0 then
				-- stick up looks up (pitch is degrees down)
				fpYaw, fpPitch = FpMath.turn(
					fpYaw,
					fpPitch,
					sx * dt,
					-sy * dt,
					FP.PAD_YAW_RATE,
					FP.PAD_PITCH_RATE,
					FP.PITCH_MIN,
					FP.PITCH_MAX
				)
			end
			return
		end
		local typing = UserInputService:GetFocusedTextBox() ~= nil
		if not typing then
			local zoom = 0
			if UserInputService:IsKeyDown(Enum.KeyCode.I) then
				zoom -= 1
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.O) then
				zoom += 1
			end
			if zoom ~= 0 then
				distance = CameraMath.clamp(distance * (1 + zoom * D.KEY_ZOOM_RATE * dt), D.ZOOM_MIN, D.ZOOM_MAX)
			end
		end
		local dz = D.PAD_DEADZONE
		if pad.Magnitude > dz then
			yaw = CameraMath.wrap(yaw - pad.X * D.PAD_YAW_RATE * dt)
			pitch = CameraMath.clamp(pitch - pad.Y * D.PAD_PITCH_RATE * dt, D.PITCH_MIN, D.PITCH_MAX)
		end
	end

	---------------------------------------------------------------------------
	-- Frame
	---------------------------------------------------------------------------
	local function followFocus(dt: number): Vector3?
		local root = rootOf()
		if not root then
			return focus
		end
		local want = root.Position + Vector3.new(0, D.FOCUS_HEIGHT, 0)
		local f = focus
		if not f or (want - f).Magnitude > D.SNAP_DISTANCE then
			focus = want
		else
			focus = f:Lerp(want, CameraMath.damp(D.FOLLOW_RATE, dt))
		end
		return focus
	end

	-- Turns your character to the look yaw (AutoRotate off while first person drives it).
	local function faceLook(root: BasePart, hum: Humanoid?)
		if not hum or hum.Health <= 0 or hum.Sit or hum.PlatformStand then
			restoreAutoRotate()
			return
		end
		if autoRotateOff ~= hum then
			restoreAutoRotate()
			hum.AutoRotate = false
			autoRotateOff = hum
		end
		local cur = CameraMath.angles(t3(root.CFrame.LookVector))
		if math.abs(FpMath.wrap(cur - fpYaw)) > FP.FACE_EPS then
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(fpYaw), 0)
		end
	end

	-- The first-person eye frame for this frame (bob, dip and glance included), or nil without a character.
	local function fpFrame(dt: number): CFrame?
		local root = rootOf()
		if not root then
			return nil
		end
		local char = player.Character
		local hum = humanoidOf()
		local head = char and char:FindFirstChild("Head")
		local wantDy = if head and head:IsA("BasePart") then head.Position.Y - root.Position.Y else FP.HEAD_DY_FALLBACK
		local dy = headDy
		headDy = if dy == nil then wantDy else dy + (wantDy - dy) * FpMath.damp(FP.EYE_FOLLOW_RATE, dt)
		faceLook(root, hum)
		-- Bob from the walking speed on the ground; the dip when you land.
		local vel = root.AssemblyLinearVelocity
		local grounded = hum ~= nil and hum.FloorMaterial ~= Enum.Material.Air
		local speed = if grounded then Vector3.new(vel.X, 0, vel.Z).Magnitude else 0
		bobPhase, bobAmp = FpMath.bobStep(bobPhase, bobAmp, dt, speed, FP.BOB)
		if grounded and wasAir and not reduced() then
			dipV += FpMath.landKick(-lastVy, FP.LAND)
		end
		wasAir = not grounded
		lastVy = vel.Y
		dipX, dipV = FpMath.spring(dipX, dipV, 0, dt, FP.LAND.FREQ, FP.LAND.DAMPING)
		local bx, by = 0, 0
		if not reduced() then
			bx, by = FpMath.bobOffset(bobPhase, bobAmp, FP.BOB)
		else
			dipX, dipV = 0, 0
		end
		local glance = FP.GLANCE_DOWN * FpMath.glance(os.clock() - glanceT0, FP.GLANCE_SECONDS)
		local eye = v3(FpMath.eye(t3(root.Position), headDy :: number, fpYaw, FP))
		local p = math.clamp(fpPitch + glance, FP.PITCH_MIN, FP.PITCH_MAX)
		return CameraDirector.lookFrame(eye, fpYaw, p) * CFrame.new(bx, by + dipX, 0)
	end

	local function step(dt: number)
		local cam = workspace.CurrentCamera
		if not cam or suspended() then
			return
		end
		-- Wall fade: diorama and classic (in first person the camera is at your eyes).
		if mode ~= "fp" then
			fadeClock += dt
			if fadeClock >= 1 / math.max(F.HZ, 1) then
				fadeClock = 0
				scanFades(cam)
			end
			stepFades(dt)
		end

		-- A moment's shot blended over the frame below (weight 0..1).
		local mCf: CFrame?, mFov, mW = nil, D.FOV, 0
		if momentFn then
			local cf, fov, w = momentFn()
			if cf then
				mCf, mFov, mW = cf, fov or D.FOV, math.clamp(w, 0, 1)
			end
		end
		local function write(cf: CFrame, fov: number)
			if mCf then
				cf = cf:Lerp(mCf, mW)
				fov += (mFov - fov) * mW
			end
			cam.CFrame = cf
			cam.FieldOfView = fov
		end

		if shotFn then
			local cf, fov = shotFn()
			if cf then
				if mode == "fp" then
					leaveFp()
				end
				cam.CameraType = Enum.CameraType.Scriptable
				write(cf, fov or D.FOV)
				cam.Focus = cf
				return
			end
		end

		keysAndPad(dt)
		if mode == "fp" then
			setCursorLocked(wantCursorLocked())
			local eye = fpFrame(dt)
			eyeCf = eye
			if not eye then
				setBodyHidden(false)
				return
			end
			if cam.CameraType ~= Enum.CameraType.Scriptable then
				cam.CameraType = Enum.CameraType.Scriptable
			end
			local fov = fpFov()
			local cf = eye
			local b = beat
			if b then
				-- C1: hold on the objective from above, then ease into your eyes.
				local e = os.clock() - b.t0
				local u = CameraMath.beatBlend(e, b.hold, b.ease)
				local pos, look = CameraMath.orbit(t3(b.objective), fpYaw, FP.BEAT_PITCH, FP.BEAT_DISTANCE)
				cf = CFrame.lookAt(v3(pos), v3(look)):Lerp(eye, u)
				fov = FP.BEAT_FOV + (fov - FP.BEAT_FOV) * u
				if e >= b.hold + b.ease then
					skipBeat()
				end
			end
			write(cf, fov + kick)
			cam.Focus = CFrame.new(eye.Position)
			setBodyHidden((cam.CFrame.Position - eye.Position).Magnitude <= FP.HIDE_BODY_WITHIN)
			return
		end

		local f = followFocus(dt)
		local classic = mode == "classic"
		if classic and mCf then
			-- The default camera is paused under the moment: blend from where it stood.
			local hold = classicHold or cam.CFrame
			classicHold = hold
			cam.CameraType = Enum.CameraType.Scriptable
			write(hold, CL.FOV + kick)
			return
		elseif classicHold then
			classicHold = nil
			toCustom(cam) -- the moment is over: the default camera carries on from here
		end
		if classic and not beat then
			if not customReady then
				customReady = true
				toCustom(cam)
				setZoomLimits(true)
			elseif cam.CameraType == Enum.CameraType.Scriptable then
				toCustom(cam) -- after a run-start beat: the default camera carries on from here
			end
			cam.FieldOfView = CL.FOV + kick
			return
		end
		if not f then
			return
		end
		if cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable
		end
		local p, dist, fov, lead
		if classic then
			p, dist, fov, lead = CL.PITCH, CL.ZOOM, CL.FOV, 0
		else
			p, dist, fov = pitch, distance, D.FOV
			lead = CameraMath.lead(fov, p, dist, D.SUBJECT_SCREEN_Y)
		end
		local target = f
		local b = beat
		if b then
			local e = os.clock() - b.t0
			local u = CameraMath.beatBlend(e, b.hold, b.ease)
			target = b.objective:Lerp(f, u)
			lead *= u -- the objective centred, then you in the lower third
			if e >= b.hold + b.ease then
				skipBeat()
			end
		end
		local pos, lookAt = CameraMath.orbit(CameraMath.ahead(t3(target), yaw, lead), yaw, p, dist)
		local cf = CFrame.lookAt(v3(pos), v3(lookAt))
		write(cf, fov + kick)
		cam.Focus = CFrame.new(target)
	end

	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		debug.profilebegin("EH.Camera")
		step(dt)
		debug.profileend()
	end)

	-- The saved pick (Heist/Settings: the session override, else the Setting_CameraMode attribute DataService
	-- publishes when the profile loads and after every change, else the default).
	local function fromSetting()
		local v = Settings.get(CameraDirector.SETTING)
		if validMode(v) then
			director.setMode(v, false)
		end
	end
	Settings.onChanged(function(key: string)
		if key == CameraDirector.SETTING then
			fromSetting()
		end
	end)
	fromSetting()
	if player then
		player.CharacterAdded:Connect(function()
			focus = nil
			customReady = false
			headDy = nil
			table.clear(hiddenParts)
			bodyHidden = false
			autoRotateOff = nil
			restoreFades()
		end)
	end

	-- Leaving the heist or the garage: faded walls of a folder about to go are forgotten.
	function director.clearFades()
		restoreFades()
	end

	-- The first-person eye this frame (before a moment's blend), or nil outside first person.
	function director.eye(): CFrame?
		return eyeCf
	end

	-- Tests and the engine checks: the current orbit state.
	function director.debugState(): any
		return {
			mode = mode,
			yaw = yaw,
			pitch = pitch,
			distance = distance,
			fpYaw = fpYaw,
			fpPitch = fpPitch,
			kick = kick,
			suspended = suspended(),
			cursorLocked = cursorLocked,
			bodyHidden = bodyHidden,
			faded = (function(): number
				local n = 0
				for _ in faded do
					n += 1
				end
				return n
			end)(),
		}
	end

	return director
end

return CameraDirector
