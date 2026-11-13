--!strict
-- Heist/Sprint: the sprint on this client (Config.Sprint; the pure maths in Shared/Heist/SprintMath). Hold Shift on a
-- keyboard; on a gamepad press the left stick (L3) to sprint until you stop or press it again; on touch push the
-- thumbstick to its edge (auto-sprint, no button). Keys come from Shared/Heist/KeyHints ("sprint").
--   * the speed: your Humanoid.WalkSpeed eases from Config.Rec.WALK_SPEED to WALK_SPEED x MULT over RAMP_SECONDS and
--     back; written only while the sprint runs or eases back (nothing else is touched);
--   * the camera: first person gains a small FOV kick (CameraDirector.setSprint; off under reduced motion or with
--     camera shake off);
--   * the server: nothing is sent. Your recording is positions, so your clones replay the sprint tick for tick, and
--     Rec/Validator's normal limit (Config.Rec.SPEED_MULT) sits above sprint speed (tests/sim/Sprint.spec.luau);
--   * the hint: once, after walking HINT_WALK_SECONDS in a run without sprinting (not on the first level, not on
--     touch), a toast says "Hold Shift to sprint." (Heist/FirstTime kind "sprint", per session).
-- The same gate as the slide (SlideMath.allowed, without its cooldown and floor checks; Crew View keeps the sprint).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local SlideMath = require(HeistShared:WaitForChild("SlideMath"))
local SprintMath = require(HeistShared:WaitForChild("SprintMath"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Common = require(script.Parent:WaitForChild("Hud"):WaitForChild("Common"))
local FirstTime = require(script.Parent:WaitForChild("FirstTime"))
local Settings = require(script.Parent:WaitForChild("Settings"))

local Sprint = {}

local ACTION = "EH_Sprint"
local RENDER_NAME = "EH_Sprint"
local HINT_KIND = "sprint" -- Heist/FirstTime kind (per session: no profile field)

-- deps: camera (CameraDirector), sheetOpen(), rewinding(), toast(text)
function Sprint.new(state: any, deps: any): any
	local SP = Config.Sprint
	local BASE = Config.Rec.WALK_SPEED
	local player = Players.LocalPlayer
	local sprint = {}
	local share = 0
	local padOn = false
	local padPressed = false
	local written: number? = nil -- the WalkSpeed this module last wrote (nil: not touching it)
	local walked = 0
	local controls: any = nil
	local controlsTried = false

	local keyCodes: { Enum.KeyCode } = {}
	for _, code in Common.keyCodes("sprint") do
		if string.sub(code.Name, 1, 6) ~= "Button" then
			table.insert(keyCodes, code)
		end
	end

	local function call(fn: any, ...): any
		if type(fn) ~= "function" then
			return nil
		end
		local ok, v = pcall(fn, ...)
		return if ok then v else nil
	end

	-- The PlayerModule's move vector (its length is the stick's push); nil until the module answers.
	local function moveVector(): Vector3?
		if not controlsTried then
			controlsTried = true
			local ps = player and player:FindFirstChildOfClass("PlayerScripts")
			local pm = ps and ps:FindFirstChild("PlayerModule")
			if pm and pm:IsA("ModuleScript") then
				pcall(function()
					controls = (require(pm) :: any):GetControls()
				end)
			end
		end
		if controls then
			local ok, v = pcall(function()
				return controls:GetMoveVector()
			end)
			if ok and typeof(v) == "Vector3" then
				return v
			end
		end
		return nil
	end

	local function shiftDown(): boolean
		if UserInputService:GetFocusedTextBox() ~= nil then
			return false
		end
		for _, code in keyCodes do
			if UserInputService:IsKeyDown(code) then
				return true
			end
		end
		return false
	end

	local function gate(hum: Humanoid, root: BasePart): boolean
		local cam = deps.camera
		return (
			SlideMath.allowed({
				where = state.where,
				phase = state.phase,
				lobbyRoam = state.lobbyRoam == true,
				presenting = cam ~= nil and cam.presenting() == true,
				rewinding = call(deps.rewinding) == true,
				sheet = call(deps.sheetOpen) == true,
				alive = hum.Health > 0,
				seated = hum.Sit or hum.PlatformStand,
				frozen = root.Anchored,
			})
		)
	end

	function sprint.share(): number
		return share
	end

	local function step(dt: number)
		local char = player and player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local pressed = padPressed
		padPressed = false
		if not hum or not root or not root:IsA("BasePart") then
			share, padOn, written = 0, false, nil
			return
		end
		local mv = moveVector()
		local stick = if mv then math.min(1, mv.Magnitude) else math.min(1, hum.MoveDirection.Magnitude)
		local moving = stick >= SP.MIN_MOVE
		local device = Common.device()
		padOn = SprintMath.padToggle(padOn, pressed, moving)
		local open = gate(hum, root)
		if not open then
			padOn = false
		end
		local want = open
			and SprintMath.wants({ device = device, shift = shiftDown(), padOn = padOn, stick = stick }, SP)
		share = SprintMath.ease(share, want, dt, SP)
		-- the WalkSpeed: only while sprinting or easing back (then once more to the base, then hands off)
		if share > 0 or written ~= nil then
			local target = SprintMath.walkSpeed(BASE, share, SP)
			if hum.WalkSpeed ~= target then
				hum.WalkSpeed = target
			end
			written = if share > 0 then target else nil
		end
		local cam = deps.camera
		if cam and cam.setSprint then
			local comfort = { reduced = state.reduced == true, shake = Settings.get("shake") ~= false }
			cam.setSprint(SprintMath.fovKick(share, comfort, SP))
		end
		-- the one-time hint
		if want then
			FirstTime.markSeen(HINT_KIND)
			walked = 0
		elseif moving and state.where == "heist" and state.phase == "Run" then
			walked += dt
			local levelId = state.level and state.level.id
			if SprintMath.hintDue(FirstTime.seen(HINT_KIND), levelId, walked, device, SP) then
				if FirstTime.firstTime(HINT_KIND) then
					call(deps.toast, Strings.SPRINT_HINTS[device] or Strings.SPRINT_HINTS.key)
				end
			end
		end
	end
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Input.Value + 2, step)

	-- L3 (the gamepad's sprint toggle); Shift is read every frame (held).
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState: Enum.UserInputState, input: InputObject)
		if inputState == Enum.UserInputState.Begin and string.sub(input.KeyCode.Name, 1, 6) == "Button" then
			padPressed = true
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.Low.Value, table.unpack(Common.keyCodes("sprint")))

	if player then
		player.CharacterRemoving:Connect(function()
			share, padOn, written = 0, false, nil
		end)
	end

	return sprint
end

return Sprint
