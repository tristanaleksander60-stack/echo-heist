--!strict
-- Heist/Slide: the slide on this client (Config.Slide; the pure maths in Shared/Heist/SlideMath). Ctrl slides; on a
-- gamepad B. No touch slide and no on-screen button (owner, live v125). Keys come from Shared/Heist/KeyHints
-- ("slide"). The burst rides on the speed you already move at, so a slide out of a sprint (Heist/Sprint) starts
-- from sprint speed.
--   * the push: a LinearVelocity in Plane mode (X and Z constrained, Y free, so you still fall off ledges and jump)
--     on your root, its target WalkSpeed + BURST x SlideMath.envelope along the direction you moved (or looked, from a
--     standstill), with Humanoid:Move kept on that direction every frame so the Humanoid agrees with the mover (vault
--     "Mover Constraints and Physics Controllers"); it ends after SECONDS, on death, or when the gate closes;
--   * the camera: first person dips low and kicks the FOV a little (CameraDirector.setSlide; the kick is off under
--     reduced motion or with camera shake off);
--   * the sound: the story intro's whoosh (IntroWhoosh, docs/AUDIO.md);
--   * in a heist run the server is told first (Heist.Interact(EVENT.Slide, 0)): it records the Slide event and
--     Rec/Validator raises your allowed speed for that window only, so the run never taints or rubber-bands. Your
--     clones replay the slide from their recorded positions. In the hideout nothing is sent (nothing is recorded).
-- Never during a presentation moment, Crew View, the rewind, a sheet, a station or the drive (SlideMath.allowed).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local SlideMath = require(HeistShared:WaitForChild("SlideMath"))

local Common = require(script.Parent:WaitForChild("Hud"):WaitForChild("Common"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Sound = require(script.Parent:WaitForChild("Sound"))

local Slide = {}

local ACTION = "EH_Slide"
local RENDER_NAME = "EH_Slide"

-- deps: camera (CameraDirector), send(arg) the Heist.Interact Slide, fastForwardOff(), sheetOpen(), rewinding().
function Slide.new(state: any, deps: any): any
	local SL = Config.Slide
	local player = Players.LocalPlayer
	local slide = {}

	type Active = {
		t0: number,
		dx: number,
		dz: number,
		hum: Humanoid,
		root: BasePart,
		att: Attachment,
		lv: LinearVelocity,
	}
	local active: Active? = nil
	local camT0 = -math.huge
	local lastStart = -math.huge

	local function parts(): (Humanoid?, BasePart?)
		local char = player and player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		return hum, if root and root:IsA("BasePart") then root else nil
	end

	local function call(fn: any, ...): any
		if type(fn) ~= "function" then
			return nil
		end
		local ok, v = pcall(fn, ...)
		return if ok then v else nil
	end

	local function gate(now: number, ignoreCooldown: boolean?): (boolean, string)
		local hum, root = parts()
		if not hum or not root then
			return false, "dead"
		end
		local cam = deps.camera
		return SlideMath.allowed({
			where = state.where,
			phase = state.phase,
			lobbyRoam = state.lobbyRoam == true,
			presenting = cam ~= nil and cam.presenting() == true,
			crewView = state.crewView == true,
			rewinding = call(deps.rewinding) == true,
			sheet = call(deps.sheetOpen) == true,
			alive = hum.Health > 0,
			grounded = hum.FloorMaterial ~= Enum.Material.Air,
			seated = hum.Sit or hum.PlatformStand,
			frozen = root.Anchored,
			cooling = not ignoreCooldown and now - lastStart < SL.COOLDOWN,
		})
	end

	local function stop()
		local a = active
		if not a then
			return
		end
		active = nil
		a.lv:Destroy()
		a.att:Destroy()
	end

	function slide.active(): boolean
		return active ~= nil
	end

	-- Starts a slide. Returns whether it started.
	function slide.start(): boolean
		local now = os.clock()
		if not gate(now) then
			return false
		end
		local hum, root = parts()
		if not hum or not root then
			return false
		end
		local move = hum.MoveDirection
		local look = root.CFrame.LookVector
		local cam = workspace.CurrentCamera
		if cam then
			look = cam.CFrame.LookVector
		end
		local dx, dz = SlideMath.direction(move.X, move.Z, look.X, look.Z, SL.MIN_MOVE)
		if dx == 0 and dz == 0 then
			return false
		end
		stop()
		lastStart = now
		-- The server first (the request opens the validator's window), and no fast-forward under a slide.
		call(deps.fastForwardOff)
		if state.where == "heist" then
			call(deps.send, 0)
		end
		local att = Instance.new("Attachment")
		att.Name = "EH_SlideAttachment"
		att.Parent = root
		local lv = Instance.new("LinearVelocity")
		lv.Name = "EH_Slide"
		lv.Attachment0 = att
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.ForceLimitsEnabled = true
		lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
		lv.MaxForce = root.AssemblyMass * SL.FORCE_PER_MASS
		local v = SlideMath.speed(hum.WalkSpeed, 0, SL)
		lv.PlaneVelocity = Vector2.new(dx, dz) * v
		lv.Parent = root
		active = { t0 = now, dx = dx, dz = dz, hum = hum, root = root, att = att, lv = lv }
		camT0 = now
		Sound.play("IntroWhoosh")
		return true
	end

	-- Every frame after the PlayerModule's input step: the push follows the envelope and the Humanoid agrees with it.
	local function step()
		local now = os.clock()
		local a = active
		if a then
			local age = now - a.t0
			local okGate = gate(now, true)
			if
				not SlideMath.active(age, SL)
				or not okGate
				or a.hum.Health <= 0
				or not a.root:IsDescendantOf(workspace)
			then
				stop()
			else
				local v = SlideMath.speed(a.hum.WalkSpeed, age, SL)
				a.lv.PlaneVelocity = Vector2.new(a.dx, a.dz) * v
				a.hum:Move(Vector3.new(a.dx, 0, a.dz), false)
			end
		end
		-- The camera: the dip and the FOV kick until the dip is back up (a gate that closes drops them at once).
		local cam = deps.camera
		if cam and cam.setSlide then
			local age = now - camT0
			if SlideMath.cameraActive(age, SL) and (active ~= nil or (gate(now, true))) then
				local comfort = { reduced = state.reduced == true, shake = Settings.get("shake") ~= false }
				cam.setSlide(SlideMath.dip(age, SL), SlideMath.fovKick(age, comfort, SL))
			else
				camT0 = -math.huge
				cam.setSlide(0, 0)
			end
		end
	end
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Input.Value + 1, step)

	-- Keys: Ctrl / B slides. Bound low so a station's BACK (B) and the settings' close (B) take B first while they
	-- are up.
	local function onSlide(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
		if inputState ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		slide.start()
		return Enum.ContextActionResult.Pass
	end
	ContextActionService:BindActionAtPriority(
		ACTION,
		onSlide,
		false,
		Enum.ContextActionPriority.Low.Value,
		table.unpack(Common.keyCodes("slide"))
	)

	if player then
		player.CharacterRemoving:Connect(stop)
	end

	return slide
end

return Slide
