--!strict
-- Heist/CameraDirector: the gameplay camera (PLAN_STEAM_PLUS §4.2 C0 + C1, decision D5;
-- docs/audit/POLISH.md §4.5; numbers in Config.Heist.CAMERA, maths in Heist/CameraMath).
--
-- Two modes, the player's pick (MENU > CAMERA: DIORAMA / CLASSIC), saved as the boolean
-- setting `classicCamera` through Data.SetSetting (DataService publishes it back as the
-- player attribute Setting_ClassicCamera):
--   "diorama"  pitch 52 (35..65), distance 30 (20..40), FOV 45, free yaw, you in the lower
--              third (the focus leads you by CameraMath.lead); drag (touch outside the
--              thumbstick, right mouse) turns, pinch / wheel / I O zoom, right stick turns.
--   "classic"  the Roblox follow cam, constrained: zoom 8 / 16 / 28, FOV 70.
-- Both: walls between the camera and you fade to CAMERA.FADE.ALPHA within 0.1 s (a 10 Hz
-- Camera:GetPartsObscuringTarget scan, LocalTransparencyModifier, restored when clear, on
-- suspend and on every mode change); the camera never rolls (every frame is a lookAt with
-- world up); reduced motion cuts the run-start beat.
--
-- Why "diorama" is Scriptable and not the default camera constrained: the shot it needs
-- (a fixed lower-third offset, a pitch clamp of 35-65 degrees, a 42-degree lens, the
-- run-start ease from the objective, golden-frame staging) cannot be layered on the default
-- camera without undoing the offset every frame at Camera-1 (vault "Camera Systems": an
-- additive offset that is not undone drifts, because the default camera reads its next look
-- vector back from the current CFrame), and its Popper would pull the camera in front of the
-- greybox colliders. Movement stays camera-relative under Scriptable: the PlayerModule's
-- ControlModule moves the character with Player:Move(v, true), relative to CurrentCamera,
-- whatever its CameraType; the touch thumbstick and jump button are untouched, and a touch
-- that starts on the thumbstick frame or on any GUI never turns the camera. "classic" IS the
-- default camera (CameraType Custom) with zoom limits, so nothing about it changes.
--
-- Hand-over: other directors call suspend(who) before they take the camera and resume(who)
-- when they give it back (LineupDirector: "lineup"); while anything holds it, this module
-- writes nothing (no CFrame, FOV or CameraType) and its fades are restored. RewindDirector
-- never takes the camera: its FOV dip arrives through setFovKick (one FOV owner).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))

local CameraMath = require(script.Parent:WaitForChild("CameraMath"))

local CameraDirector = {}

CameraDirector.SETTING = "classicCamera" -- Schema settings key (true = classic)
CameraDirector.ATTRIBUTE = "Setting_ClassicCamera" -- DataService.publishAttributes

local RENDER_NAME = "EH_CameraDirector"
local REMOTES = "LihFolkRemotes"
local SET_SETTING = "Data.SetSetting"

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function t3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

-- The objective of a level for the run-start beat (CameraMath.objective), level space.
CameraDirector.objectiveOf = CameraMath.objective

function CameraDirector.new(state: any): any
	local C = Config.Heist.CAMERA
	local D, CL, F = C.DIORAMA, C.CLASSIC, C.FADE
	local player = Players.LocalPlayer
	local director = {}

	local mode: string = if C.DEFAULT_MODE == "classic" then "classic" else "diorama"
	local holds: { [string]: boolean } = {}
	local yaw, pitch, distance = 0, D.PITCH, D.DISTANCE
	local focus: Vector3? = nil
	local kick = 0
	local beat: any = nil -- { t0, hold, ease, objective: Vector3 }
	local shotFn: (() -> (CFrame?, number?))? = nil -- golden-frame staging
	local customReady = false -- classic: Custom + subject + zoom limits applied
	local listeners: { (string) -> () } = {}

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
	-- Wall fade (both modes)
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

	local function persist()
		local folder = ReplicatedStorage:FindFirstChild(REMOTES)
		if not folder or not folder:FindFirstChild(SET_SETTING) then
			return -- no data service (offline Studio): the pick lasts for this session
		end
		local classic = mode == "classic"
		task.spawn(function()
			Net.Request(SET_SETTING, CameraDirector.SETTING, classic)
		end)
	end

	function director.mode(): string
		return mode
	end

	function director.onModeChanged(fn: (string) -> ())
		table.insert(listeners, fn)
	end

	function director.setMode(m: string, save: boolean?)
		if m ~= "diorama" and m ~= "classic" then
			return
		end
		if m == mode then
			return
		end
		mode = m
		local cam = workspace.CurrentCamera
		if mode == "diorama" and cam then
			local y = CameraMath.angles(t3(cam.CFrame.LookVector))
			yaw = y -- keep looking the same way
			pitch, distance = D.PITCH, D.DISTANCE
		end
		customReady = false
		restoreFades()
		if save then
			persist()
		end
		notify()
	end

	function director.toggle(): string
		director.setMode(if mode == "diorama" then "classic" else "diorama", true)
		return mode
	end

	-- Another director takes the camera (LineupDirector "lineup"): this one writes nothing
	-- until every holder resumes.
	function director.suspend(who: string)
		holds[who] = true
		beat = nil
		restoreFades()
	end

	function director.resume(who: string)
		holds[who] = nil
		if suspended() then
			return
		end
		customReady = false
		focus = nil -- snap back onto you
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
		end
		focus = nil
		beat = nil
		if state.reduced or not objective or suspended() then
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

	-- Golden-frame staging (Studio only, Heist/Scenario): fn returns the shot's CFrame and FOV
	-- every frame (nil = the gameplay camera this frame); nil fn clears it.
	function director.setShot(fn: (() -> (CFrame?, number?))?)
		shotFn = fn
		customReady = false
	end

	---------------------------------------------------------------------------
	-- Input (diorama): touch drag / pinch, right mouse, wheel, I / O, right stick
	---------------------------------------------------------------------------
	local fingers: { [InputObject]: Vector2 } = {}
	local pinchFrom: { spread: number, zoom: number }? = nil
	local mouseTurning = false
	local pad = Vector2.zero

	local function controlling(): boolean
		return mode == "diorama" and not suspended() and shotFn == nil
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

	local function turn(dx: number, dy: number)
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
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
		elseif t == Enum.UserInputType.MouseButton2 then
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
			if n == 1 then
				turn(pos.X - prev.X, pos.Y - prev.Y)
			elseif n >= 2 and a and b then
				local spread = (a - b).Magnitude
				local from = pinchFrom
				if not from then
					pinchFrom = { spread = spread, zoom = distance }
				else
					distance = CameraMath.pinch(from.zoom, from.spread, spread, D.ZOOM_MIN, D.ZOOM_MAX)
				end
			end
		elseif t == Enum.UserInputType.MouseMovement and mouseTurning then
			turn(input.Delta.X, input.Delta.Y)
		elseif t == Enum.UserInputType.MouseWheel and not processed then
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
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif t == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			pad = Vector2.zero
		end
	end)

	local function keysAndPad(dt: number)
		if not controlling() then
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

	local function step(dt: number)
		local cam = workspace.CurrentCamera
		if not cam or suspended() then
			return
		end
		-- Wall fade, both modes.
		fadeClock += dt
		if fadeClock >= 1 / math.max(F.HZ, 1) then
			fadeClock = 0
			scanFades(cam)
		end
		stepFades(dt)

		if shotFn then
			local cf, fov = shotFn()
			if cf then
				cam.CameraType = Enum.CameraType.Scriptable
				cam.CFrame = cf
				cam.Focus = cf
				cam.FieldOfView = fov or D.FOV
				return
			end
		end

		keysAndPad(dt)
		local f = followFocus(dt)
		local classic = mode == "classic"
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
		cam.CFrame = cf
		cam.Focus = CFrame.new(target)
		cam.FieldOfView = fov + kick
	end

	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		debug.profilebegin("EH.Camera")
		step(dt)
		debug.profileend()
	end)

	-- The saved pick (DataService publishes Setting_ClassicCamera when the profile loads and
	-- after every change).
	local function fromAttribute()
		local v = player and player:GetAttribute(CameraDirector.ATTRIBUTE)
		if type(v) == "boolean" then
			director.setMode(if v then "classic" else "diorama", false)
		end
	end
	if player then
		player:GetAttributeChangedSignal(CameraDirector.ATTRIBUTE):Connect(fromAttribute)
		fromAttribute()
		player.CharacterAdded:Connect(function()
			focus = nil
			customReady = false
			restoreFades()
		end)
	end

	-- Leaving the heist or the garage: faded walls of a folder about to go are forgotten.
	function director.clearFades()
		restoreFades()
	end

	-- Tests and the engine checks: the current orbit state.
	function director.debugState(): any
		return {
			mode = mode,
			yaw = yaw,
			pitch = pitch,
			distance = distance,
			kick = kick,
			suspended = suspended(),
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
