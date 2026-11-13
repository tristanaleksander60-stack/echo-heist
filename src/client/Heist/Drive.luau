--!strict
-- Heist/Drive: the short drive from the hideout to the heist (LOBBY track, Config.Hideout.DRIVE). After GO the van's
-- side door shuts (server), then this client cuts to a tracking three-quarter shot of YOUR van (a copy of its kit
-- pieces in its paint, with its crew plate) rolling down a snowy night street while the town slides past: brick
-- blocks with lit windows, street lamps, kerb snow; an engine rumble cue and a light shake (both off with camera
-- shake off / reduced motion). 2-3 s, skippable (SKIP, any key, a tap); at its end the van-door wipe closes over it
-- and the heist's Sync opens the doors onto run 1.
-- Everything is built on this client only, at DRIVE.STAGE_ORIGIN (far from the garage and every instance slot):
-- never replicated, never collides, never queried. CameraDirector is suspended ("drive") while it plays and resumed
-- on every exit path (end, skip, stop, a watchdog).
--   Drive.play(opts) -> drive    opts: { bay, director (CameraDirector), shake: boolean, onEnd: (how) -> () }
--     drive.skip() / drive.stop() / drive.isDone()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local VanRules = require(Shared:WaitForChild("Heist"):WaitForChild("VanRules"))

local Sound = require(script.Parent:WaitForChild("Sound"))

local D = Config.Hideout.DRIVE
local RENDER_NAME = "EH_HideoutDrive"

local Drive = {}

-- Facade colours of the passing town (Corner Shop brick family) and its lit windows.
local FACADES = { Color3.fromRGB(110, 62, 52), Color3.fromRGB(92, 56, 60), Color3.fromRGB(78, 70, 96) }
local WINDOW = Color3.fromRGB(255, 214, 140)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A small deterministic hash in [0, 1) (block heights, lit windows).
local function hash(i: number, salt: number): number
	local x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453
	return x - math.floor(x)
end

-- The bay's van as it stands in the garage (its kit pieces, else its greybox box) and its plate, copied onto the
-- stage at `at` (the van's own frame: cab toward local CAB_X).
local function copyVan(stage: Instance, bay: number, at: CFrame): number
	local garage = workspace:FindFirstChild("Garage")
	local anchors = garage and garage:FindFirstChild("Anchors")
	local anchor = anchors and anchors:FindFirstChild("VanBay" .. bay)
	if not (garage and anchor and anchor:IsA("BasePart")) then
		return 0
	end
	local base = anchor.CFrame
	local copied = 0
	local function put(src: BasePart, visible: boolean)
		local c = src:Clone()
		for _, ch in c:GetChildren() do
			if not (ch:IsA("SurfaceGui") or ch:IsA("SurfaceAppearance") or ch:IsA("Decal") or ch:IsA("Texture")) then
				ch:Destroy()
			end
		end
		c.Anchored = true
		c.CanCollide = false
		c.CanTouch = false
		c.CanQuery = false
		if visible then
			c.Transparency = 0
		end
		c.CFrame = at * base:ToObjectSpace(src.CFrame)
		c.Parent = stage
		copied += 1
	end
	local kit = garage:FindFirstChild("Kit")
	if kit then
		for _, d in kit:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("EH_Bay") == bay then
				put(d, false)
			end
		end
	end
	if copied == 0 then
		for _, d in garage:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("EH_Kind") == "garageVan" and d:GetAttribute("EH_Bay") == bay then
				put(d, true)
			end
		end
	end
	local vans = garage:FindFirstChild("Vans")
	local rig = vans and vans:FindFirstChild("Van" .. bay)
	if rig then
		for _, name in { "Plate", "DoorLeaf" } do
			local p = rig:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				put(p, false)
			end
		end
	end
	return copied
end

-- Builds the stage (not parented): the copy of the bay's van at the origin, the road and kerbs, the moving town.
-- Returns { model, movers, loop, origin, copied } (tests/client_engine.luau section M builds it on the real garage).
function Drive.build(bay: number): any
	local o = D.STAGE_ORIGIN
	local origin = CFrame.new(o[1], o[2], o[3])
	local stage = Instance.new("Model")
	stage.Name = "EH_Drive"
	-- the van, still, at the stage origin; the street runs along the van's length (local X) and scrolls past it
	local cabX = Config.Hideout.VAN.CAB_X
	local copied = copyVan(stage, bay, origin)
	local W = D.STREET_W
	local len = 520
	part(stage, "Road", Vector3.new(len, 1, W), origin * CFrame.new(0, -0.5, 0), Color3.fromRGB(40, 42, 64))
	for _, side in { -1, 1 } do
		part(
			stage,
			"Kerb",
			Vector3.new(len, 1.2, 4),
			origin * CFrame.new(0, -0.4, side * (W / 2 + 2)),
			Color3.fromRGB(196, 200, 226),
			Enum.Material.Snow
		)
	end
	-- the moving set: blocks (both sides), lamps, road dashes; each is { part, along0 } and wraps every loop
	local B = D.BLOCK
	local movers: { { p: BasePart, x: number, rest: CFrame } } = {}
	local loop = 0
	local n = 0
	while loop < len do
		n += 1
		for _, side in { -1, 1 } do
			local h = B.minH + (B.maxH - B.minH) * hash(n, side)
			local z = side * (W / 2 + 4 + B.depth / 2)
			local block = part(
				stage,
				"Block",
				Vector3.new(B.length, h, B.depth),
				CFrame.new(0, h / 2 - 0.5, z),
				FACADES[(n + (if side > 0 then 1 else 0)) % #FACADES + 1],
				Enum.Material.Brick
			)
			table.insert(movers, { p = block, x = loop + B.length / 2, rest = block.CFrame })
			-- lit window rows on the street face
			for row = 1, math.floor((h - 4) / 5) do
				if hash(n * 7 + row, side) > 0.3 then
					local face = z - side * (B.depth / 2 + 0.05)
					local win = part(
						stage,
						"Windows",
						Vector3.new(B.length - 4, 1.6, 0.1),
						CFrame.new(0, 2 + row * 5, face),
						WINDOW,
						Enum.Material.Neon
					)
					table.insert(movers, { p = win, x = loop + B.length / 2, rest = win.CFrame })
				end
			end
		end
		loop += B.length + B.gap
	end
	for x = 0, loop - 1, D.LAMP_EVERY do
		for _, side in { -1, 1 } do
			local z = side * (W / 2 + 1.2)
			local pole = part(stage, "LampPole", Vector3.new(0.4, 10, 0.4), CFrame.new(0, 4.5, z), Palette.inkHi)
			local bulb =
				part(stage, "LampBulb", Vector3.new(1.2, 0.8, 1.2), CFrame.new(0, 9.6, z), WINDOW, Enum.Material.Neon)
			table.insert(movers, { p = pole, x = x, rest = pole.CFrame })
			table.insert(movers, { p = bulb, x = x, rest = bulb.CFrame })
		end
		local dash = part(stage, "Dash", Vector3.new(5, 0.05, 0.4), CFrame.new(0, 0.03, 0), Palette.steelHi)
		table.insert(movers, { p = dash, x = x, rest = dash.CFrame })
	end
	-- the headlights' glow ahead of the cab
	local glow = part(
		stage,
		"Headlights",
		Vector3.new(0.4, 0.4, 0.4),
		origin * CFrame.new(cabX * 8, 3, 0),
		WINDOW,
		Enum.Material.Neon
	)
	glow.Transparency = 1
	local light = Instance.new("SpotLight")
	light.Face = if cabX < 0 then Enum.NormalId.Left else Enum.NormalId.Right
	light.Range = 40
	light.Angle = 70
	light.Brightness = 3
	light.Color = WINDOW
	light.Parent = glow
	return { model = stage, movers = movers, loop = loop, origin = origin, copied = copied }
end

-- Poses the moving town for t seconds into the drive and returns the camera's frame (shake in studs).
function Drive.pose(st: any, t: number, shake: number): CFrame
	local C = D.CAM
	local dirX = -Config.Hideout.VAN.CAB_X -- the van drives toward its cab: the world slides the other way
	local loop = st.loop
	local shift = (t * D.SPEED) % loop
	for _, m in st.movers do
		local x = ((m.x + shift * dirX) % loop) - loop / 2
		m.p.CFrame = st.origin * CFrame.new(x, 0, 0) * m.rest
	end
	local sx = math.sin(t * 37) * shake
	local sy = math.sin(t * 53 + 1) * shake
	local eye = VanRules.localPoint(C.along, C.up, C.out)
	local at = VanRules.localPoint(C.lookAlong, C.lookUp, 0)
	local eyeW = st.origin * Vector3.new(eye[1] + sx, eye[2] + sy, eye[3])
	local atW = st.origin * Vector3.new(at[1], at[2], at[3])
	return CFrame.lookAt(eyeW, atW)
end

function Drive.play(opts: any): any
	local drive = {}
	local st = Drive.build(opts.bay or 1)
	local stage = st.model
	stage.Parent = workspace

	local director = opts.director
	if director then
		director.suspend("drive")
	end
	local cam = workspace.CurrentCamera
	local oldType = cam.CameraType
	local oldFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local stopCue = Sound.play(D.CUE)
	local t0 = os.clock()
	local done = false
	local function frame(t: number)
		cam.CFrame = Drive.pose(st, t, if opts.shake then D.SHAKE else 0)
		cam.FieldOfView = D.CAM.fov
	end
	local function finish(how: string)
		if done then
			return
		end
		done = true
		RunService:UnbindFromRenderStep(RENDER_NAME)
		pcall(stopCue)
		local fn = opts.onEnd
		if fn then
			task.spawn(fn, how)
		end
	end
	frame(0)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - t0
		frame(t)
		if t >= D.SECONDS then
			finish("finished")
		end
	end)
	task.delay(D.SECONDS + 8, function()
		drive.stop() -- watchdog: the player always gets the camera back
	end)

	function drive.skip()
		finish("skipped")
	end

	function drive.isDone(): boolean
		return done
	end

	-- Tears the stage down and gives the camera back (idempotent).
	local stopped = false
	function drive.stop()
		finish("stopped")
		if stopped then
			return
		end
		stopped = true
		stage:Destroy()
		cam.FieldOfView = oldFov
		cam.CameraType = oldType
		if director then
			director.resume("drive")
		end
	end

	return drive
end

return Drive
