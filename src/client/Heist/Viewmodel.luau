--!strict
-- Heist/Viewmodel: your first-person hands (PLAN_FIRST_PERSON FP; vault "First-Person Viewmodels"). A
-- local-only arms rig bound to the camera after the camera has moved (RenderPriority Camera + 2), shown only
-- while the camera is at your eyes (state.fpView, Heist/CameraDirector). Numbers in Config.FirstPerson
-- .VIEWMODEL, pose maths in Heist/ViewmodelMath (pure, Lune-tested).
--
-- The rig: ReplicatedStorage.CharacterKit.Rookie_Viewmodel (forearms + gloved hands with GripR / GripL
-- attachments) when the CHARACTER track publishes it (checked every KIT_CHECK_SECONDS; each part follows the
-- grip it is nearest to; a grip's -Z points along the fingers, +Y out of the back of the hand). Until then
-- the placeholder: chunky gloved hands built from rounded parts in palette colours (a padded glove, four
-- fingers and a thumb with round tips, a cuff, the sweater sleeve with a stripe in your crew hue, a gold
-- watch on the left wrist), never grey blocks.
--
-- Never clips: the whole rig is drawn at SCALE (0.4) and that much nearer the eye, so it looks the same but
-- stays inside your character's own collision; a ray from the eye pulls the hands back and down when a wall
-- is closer than WALL.RANGE (both rules from the vault note, §3: Roblox has no "draw on top" for 3D parts).
-- Every part is Anchored, CanCollide / CanQuery / CanTouch off, CastShadow off; they move with one
-- workspace:BulkMoveTo a frame.
--
-- Motion: idle breathing, a walk bob in step with the camera's head bob, look lag (a spring that trails how
-- fast you turn, from the camera's own rotation, so mouse, touch and gamepad all sway), a crouch-like lower
-- while you hide, the wall pull. Actions (play): reach (a grab), push (a door opening in front of you), press
-- (a switch), stomp (your plate press; the camera glances down), watch (REWIND: the left wrist comes up and
-- the right index taps the watch), handsUp (caught). Carry: the loot you hold rides between your hands in
-- view (a local copy of the loot model, scaled with the rig; WorldView hides the world one for you).
-- Reduced motion: no breathing or bob, a quarter of the lag; actions still play (they are the feedback).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Outfit = require(Shared:WaitForChild("Heist"):WaitForChild("Outfit"))
local RookieData = require(Shared:WaitForChild("Heist"):WaitForChild("RookieData")) :: any

local FpMath = require(script.Parent:WaitForChild("FpMath"))
local ViewmodelMath = require(script.Parent:WaitForChild("ViewmodelMath"))

local VM = Config.FirstPerson.VIEWMODEL

local Viewmodel = {}

local RENDER_NAME = "EH_Viewmodel"
Viewmodel.MODEL_NAME = "EH_Viewmodel"

export type Hand = { parts: { BasePart }, offsets: { CFrame } } -- offsets: part relative to the grip (scaled)
export type Rig = { model: Model, R: Hand, L: Hand, kit: boolean }

local function colour(key: string): Color3
	return (Palette :: any)[key] or Palette.plumHi
end

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
end

-- One placeholder piece in the hand's frame (full size; the rig is scaled after).
local function piece(
	model: Model,
	name: string,
	shape: string,
	size: Vector3,
	at: CFrame,
	color: Color3,
	material: Enum.Material?
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	if shape == "cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.Size = size
	p.CFrame = at
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "ellipsoid" then
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = p
	end
	quiet(p)
	p.Parent = model
	return p
end

local ALONG_Z = CFrame.Angles(0, math.rad(90), 0) -- a Cylinder's axis is X: turn it along the arm
local ALONG_Y = CFrame.Angles(0, 0, math.rad(90))

-- A placeholder hand (side 1 = right, -1 = left) built at the origin in its grip frame: -Z along the
-- fingers, +Y the back of the hand. Returns its parts.
local function buildHand(model: Model, side: number, hue: Color3, withWatch: boolean): { BasePart }
	local C = VM.COLOURS
	local glove, knuckle, cuff, sleeve = colour(C.glove), colour(C.knuckle), colour(C.cuff), colour(C.sleeve)
	local tag = if side > 0 then "R" else "L"
	local out: { BasePart } = {}
	local function add(p: BasePart)
		table.insert(out, p)
	end
	local s = side
	add(piece(model, "Palm" .. tag, "ellipsoid", Vector3.new(0.8, 0.42, 0.86), CFrame.new(0, 0, -0.42), glove))
	add(piece(model, "Knuckles" .. tag, "cylinder", Vector3.new(0.68, 0.22, 0.22), CFrame.new(0, 0.12, -0.74), knuckle))
	for k, x in { -0.27, -0.09, 0.09, 0.27 } do
		local len = if k == 1 or k == 4 then 0.4 else 0.46
		local z0 = -0.8 - len / 2
		add(
			piece(
				model,
				"Finger" .. k .. tag,
				"cylinder",
				Vector3.new(len, 0.19, 0.19),
				CFrame.new(x * s, 0.0, z0) * CFrame.Angles(math.rad(-10), 0, 0) * ALONG_Z,
				glove
			)
		)
		add(
			piece(
				model,
				"Tip" .. k .. tag,
				"ball",
				Vector3.new(0.2, 0.2, 0.2),
				CFrame.new(x * s, -0.04, z0 - len / 2),
				glove
			)
		)
	end
	-- The thumb, on the inside (left of a right hand palm down), angled out and forward.
	local thumbAt = CFrame.new(-0.42 * s, -0.06, -0.46) * CFrame.Angles(0, math.rad(35 * s), 0)
	add(piece(model, "Thumb" .. tag, "cylinder", Vector3.new(0.36, 0.21, 0.21), thumbAt * ALONG_Z, glove))
	add(
		piece(model, "ThumbTip" .. tag, "ball", Vector3.new(0.22, 0.22, 0.22), thumbAt * CFrame.new(0, 0, -0.18), glove)
	)
	add(piece(model, "Cuff" .. tag, "cylinder", Vector3.new(0.26, 0.86, 0.86), CFrame.new(0, 0, 0.02) * ALONG_Z, cuff))
	add(
		piece(
			model,
			"Sleeve" .. tag,
			"cylinder",
			Vector3.new(1.7, 0.8, 0.8),
			CFrame.new(0, 0, 1.0) * ALONG_Z,
			sleeve,
			Enum.Material.Fabric
		)
	)
	add(
		piece(
			model,
			"Stripe" .. tag,
			"cylinder",
			Vector3.new(0.2, 0.83, 0.83),
			CFrame.new(0, 0, 0.62) * ALONG_Z,
			hue,
			Enum.Material.Fabric
		)
	)
	if withWatch then
		add(
			piece(
				model,
				"WatchBand",
				"cylinder",
				Vector3.new(0.16, 0.85, 0.85),
				CFrame.new(0, 0, 0.26) * ALONG_Z,
				colour(C.band),
				Enum.Material.Metal
			)
		)
		add(
			piece(
				model,
				"WatchFace",
				"cylinder",
				Vector3.new(0.08, 0.38, 0.38),
				CFrame.new(0, 0.43, 0.26) * ALONG_Y,
				colour(C.watch),
				Enum.Material.Metal
			)
		)
		add(
			piece(
				model,
				"WatchHand",
				"block",
				Vector3.new(0.04, 0.02, 0.15),
				CFrame.new(0.02, 0.48, 0.22) * CFrame.Angles(0, math.rad(30), 0),
				Palette.ink
			)
		)
	end
	return out
end

-- Offsets of parts relative to a grip frame, after the rig has been scaled.
local function handOf(parts: { BasePart }, grip: CFrame): Hand
	local offsets = {}
	for i, p in parts do
		offsets[i] = grip:ToObjectSpace(p.CFrame)
	end
	return { parts = parts, offsets = offsets }
end

-- The placeholder rig (both hands, scaled by VIEWMODEL.SCALE), not parented. `hue`: the sleeve stripe.
function Viewmodel.buildPlaceholder(hue: Color3?): Rig
	local model = Instance.new("Model")
	model.Name = Viewmodel.MODEL_NAME
	local h = hue or Palette.CLONE_HUES[1]
	local rParts = buildHand(model, 1, h, false)
	-- The left hand is built in its own frame, then moved off so the two never share a spot while scaling.
	local lParts = buildHand(model, -1, h, true)
	local s = VM.SCALE
	-- Scale every part about the origin (both hands' grips are the origin).
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Size *= s
			p.CFrame = CFrame.new(p.Position * s) * p.CFrame.Rotation
		end
	end
	return { model = model, R = handOf(rParts, CFrame.identity), L = handOf(lParts, CFrame.identity), kit = false }
end

-- The kit rig (CharacterKit.Rookie_Viewmodel): a scaled copy; each part follows the grip it is nearest to
-- (by name first: "Right" / "Left", "_R" / "_L"). nil when the model has no GripR / GripL.
function Viewmodel.fromKit(source: Model): Rig?
	local model = source:Clone()
	model.Name = Viewmodel.MODEL_NAME
	local okScale = pcall(function()
		model:ScaleTo(VM.SCALE)
	end)
	if not okScale then
		model:Destroy()
		return nil
	end
	local gripR = model:FindFirstChild("GripR", true)
	local gripL = model:FindFirstChild("GripL", true)
	if not (gripR and gripR:IsA("Attachment") and gripL and gripL:IsA("Attachment")) then
		model:Destroy()
		return nil
	end
	local wr, wl = gripR.WorldCFrame, gripL.WorldCFrame
	local r, l = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			quiet(d)
			local n = string.lower(d.Name)
			local right: boolean
			if string.find(n, "right", 1, true) or string.sub(n, -2) == "_r" then
				right = true
			elseif string.find(n, "left", 1, true) or string.sub(n, -2) == "_l" then
				right = false
			else
				right = (d.Position - wr.Position).Magnitude <= (d.Position - wl.Position).Magnitude
			end
			table.insert(if right then r else l, d)
		end
	end
	return { model = model, R = handOf(r, wr), L = handOf(l, wl), kit = true }
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function bodyOrigin(part: string): Vector3?
	for _, b in RookieData.body do
		if b.part == part then
			return v3(b.origin)
		end
	end
	return nil
end

-- Your arms in your outfit (CH polish): built from CharacterKit.Pieces like Heist/Rookie dresses a character, so
-- the hands in first person match your body: the sleeve (the R15 lower arm), the glove (the hand) and the gloves
-- slot's cuff in your glove colour (Config.Rookie.GLOVES), the colour-block cuff or two Breton stripes down the
-- sleeve in your crew hue. Grips at the palms (RookieData.viewmodel, offsets from the elbow). Scaled and bound
-- like any kit viewmodel (Viewmodel.fromKit). nil when a piece is missing (the plain Rookie_Viewmodel then).
-- outfitKey: the player attribute "Outfit" (Outfit.key); nil = the default outfit.
function Viewmodel.fromOutfit(folder: Instance, outfitKey: string?, hue: Color3): Rig?
	local pieces = folder:FindFirstChild("Pieces")
	if not pieces then
		return nil
	end
	local outfit = Outfit.fromKey(outfitKey)
	local glove = Color3.fromHex(Outfit.gloveHex(outfit))
	local names = Outfit.pieces(outfit)
	local model = Instance.new("Model")
	model.Name = "Rookie_Viewmodel"
	local ok = true
	for armName, d in RookieData.viewmodel do
		local s = if armName == "RightArm" then "Right" else "Left"
		local function add(name: string, at: CFrame, color: Color3?): BasePart?
			local src = pieces:FindFirstChild(name)
			if not src or not src:IsA("BasePart") then
				ok = false
				return nil
			end
			local p = src:Clone()
			p.Name = s .. "_" .. name -- the side in the name: Viewmodel.fromKit binds it to that hand's grip
			for _, c in p:GetChildren() do
				if not (c:IsA("DataModelMesh") or c:IsA("SurfaceAppearance")) then
					c:Destroy()
				end
			end
			p:PivotTo(at)
			if color then
				p.Color = color
			end
			p.Parent = model
			return p
		end
		local elbowAt, wristAt = bodyOrigin(s .. "LowerArm"), bodyOrigin(s .. "Hand")
		if not elbowAt or not wristAt then
			ok = false
			break
		end
		local elbow = CFrame.new(elbowAt)
		add("Rookie_" .. s .. "LowerArm", elbow)
		local hand = add("Rookie_" .. s .. "Hand", CFrame.new(wristAt), glove)
		-- the outfit's pieces on the forearm and the hand: the glove cuff, the colour-block cuff
		for _, n in names do
			local a = RookieData.attach[n]
			local host = a and bodyOrigin(a.part)
			if a and host and (a.part == s .. "Hand" or a.part == s .. "LowerArm") then
				local tint = RookieData.tint[n]
				add(
					n,
					CFrame.new(host + v3(a.offset)),
					if tint == "crew" then hue elseif tint == "gloves" then glove else nil
				)
			end
		end
		-- Breton stripes: two crew bands round the sleeve (the body shows them on the upper arm, out of view here)
		if outfit.sweater == "Sweater_Stripes" then
			local axis = (wristAt - elbowAt).Unit
			local side = axis:Cross(Vector3.zAxis).Unit
			for i, t in VM.SLEEVE_STRIPES do
				local band = Instance.new("Part")
				band.Name = s .. "_Stripe" .. i
				band.Shape = Enum.PartType.Cylinder
				band.Material = Enum.Material.SmoothPlastic
				band.Size = Vector3.new(VM.STRIPE_WIDTH, VM.STRIPE_RADIUS[i] * 2, VM.STRIPE_RADIUS[i] * 2)
				band.CFrame = CFrame.fromMatrix(elbowAt:Lerp(wristAt, t), axis, side)
				band.Color = hue
				band.Parent = model
			end
		end
		if hand then
			local grip = Instance.new("Attachment")
			grip.Name = d.grip
			grip.CFrame = hand.CFrame:ToObjectSpace(elbow * CFrame.new(v3(d.gripOffset)))
			grip.Parent = hand
		end
	end
	if not ok then
		model:Destroy()
		return nil
	end
	local rig = Viewmodel.fromKit(model)
	model:Destroy()
	return rig
end

local function poseFrame(cam: CFrame, pose: { number }, fit: number): CFrame
	local s = VM.SCALE
	return cam
		* CFrame.new(pose[1] * s * fit, pose[2] * s * fit, pose[3] * s)
		* CFrame.Angles(math.rad(pose[4]), math.rad(pose[5]), math.rad(pose[6]))
end

-- A local copy of a loot part to hold in view: visuals only, scaled to CARRY.LOOT_SIZE at the rig's scale.
-- `size`: the part's own size (WorldView squashes it for a moment on a grab), default its current size.
function Viewmodel.heldCopy(part: BasePart, size: Vector3?): BasePart
	local base = size or part.Size
	local copy = part:Clone()
	for _, d in copy:GetDescendants() do
		local keep = d:IsA("DataModelMesh")
			or d:IsA("SurfaceAppearance")
			or d:IsA("Decal")
			or d:IsA("Texture")
			or d:IsA("BasePart")
		if not keep then
			d:Destroy()
		end
	end
	for name in copy:GetAttributes() do
		copy:SetAttribute(name, nil)
	end
	local longest = math.max(base.X, base.Y, base.Z)
	local k = ViewmodelMath.lootScale(longest, VM.CARRY.LOOT_SIZE, VM.SCALE)
	copy.Size = base * k
	for _, d in copy:GetDescendants() do
		if d:IsA("SpecialMesh") then
			d.Scale *= k
		elseif d:IsA("BasePart") then
			d.Size *= k
			quiet(d)
		end
	end
	copy.Transparency = 0
	copy.LocalTransparencyModifier = 0
	quiet(copy)
	return copy
end

-- deps: camera (Heist/CameraDirector), world (Heist/WorldView: heldPart, partFor), hue () -> Color3.
function Viewmodel.new(state: any, deps: any): any
	local vm = {}
	local player = Players.LocalPlayer
	local camera = deps.camera
	local rig: Rig = Viewmodel.buildPlaceholder(if deps.hue then deps.hue() else nil)
	local shownHue: Color3? = nil
	local kitChecked = -math.huge
	local actions: { [string]: number } = {} -- name -> os.clock() it started
	local held: { [string]: boolean } = {}
	local carry, hidden, wall = 0, 0, 0
	local lagX, lagVX, lagY, lagVY, lagR, lagVR = 0, 0, 0, 0, 0, 0
	local lastLook: CFrame? = nil
	local heldSource: BasePart? = nil
	local heldCopy: BasePart? = nil
	local lastPush = -math.huge
	local shown = false
	local frozen: (() -> boolean)? = deps.frozen
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local function setShown(on: boolean)
		if on == shown then
			return
		end
		shown = on
		local cam = workspace.CurrentCamera
		rig.model.Parent = if on and cam then cam else nil
	end

	local function swapRig(new: Rig)
		local wasShown = shown
		setShown(false)
		if heldCopy then
			heldCopy.Parent = nil
		end
		rig.model:Destroy()
		rig = new
		if heldCopy then
			heldCopy.Parent = rig.model
		end
		setShown(wasShown)
	end

	-- The placeholder's stripe follows your crew hue.
	local function recolour()
		local hue = if deps.hue then deps.hue() else Palette.CLONE_HUES[1]
		if hue == shownHue or rig.kit then
			return
		end
		shownHue = hue
		for _, p in rig.model:GetDescendants() do
			if p:IsA("BasePart") and string.sub(p.Name, 1, 6) == "Stripe" then
				p.Color = hue
			end
		end
	end

	-- The kit arms in your outfit (gloves, glove colour, crew stripes): rebuilt when your outfit or crew hue changes.
	local builtKey: string? = nil
	local function checkKit(now: number)
		if now - kitChecked < VM.KIT_CHECK_SECONDS then
			return
		end
		kitChecked = now
		local key = if player then player:GetAttribute("Outfit") else nil
		local hue = if deps.hue then deps.hue() else Palette.CLONE_HUES[1]
		local want = tostring(key) .. "#" .. hue:ToHex()
		if rig.kit and builtKey == want then
			return
		end
		local kit = ReplicatedStorage:FindFirstChild(VM.KIT)
		if not kit then
			return
		end
		local made = Viewmodel.fromOutfit(kit, if type(key) == "string" then key else nil, hue)
		if not made then
			local src = kit:FindFirstChild(VM.KIT_MODEL)
			made = if src and src:IsA("Model") then Viewmodel.fromKit(src) else nil
		end
		if made then
			builtKey = want
			swapRig(made)
		end
	end

	-- Plays an action (Config.FirstPerson.VIEWMODEL.ACTIONS); `hold` keeps it up until release(name).
	function vm.play(name: string, hold: boolean?)
		if not VM.ACTIONS[name] then
			return
		end
		actions[name] = os.clock()
		held[name] = if hold then true else nil
	end

	function vm.release(name: string)
		if held[name] then
			held[name] = nil
			local a = VM.ACTIONS[name]
			-- fall from now: restart the clock at the end of the hold
			actions[name] = os.clock() - a.time[1] - a.time[2]
		end
	end

	-- A run starts: no action carries over, you are not hiding.
	function vm.onRun()
		table.clear(actions)
		table.clear(held)
		state.fpHidden = false
	end

	-- Sim events of this client (HeistClient.applyEvent, live only). mine(id): is that actor you?
	function vm.onEvent(e: any, mine: (number) -> boolean, EV: any)
		if e.kind == EV.Hidden and mine(e.a) then
			state.fpHidden = true
		elseif e.kind == EV.Unhidden and mine(e.a) then
			state.fpHidden = false
		elseif e.kind == EV.Caught and mine(e.b) then
			vm.play("handsUp")
		elseif e.kind == EV.Grab and mine(e.a) then
			local t = actions.reach
			if not t or os.clock() - t > VM.REACH_DEDUPE then
				vm.play("reach") -- (the press already played it, unless the grab came from elsewhere)
			end
		elseif e.kind == EV.SwitchOn and mine(e.b) then
			vm.play("press")
		elseif e.kind == EV.PlateDown and mine(e.b) then
			vm.play("stomp")
			camera.glance()
		elseif e.kind == EV.DoorOpen then
			local w = deps.world
			local door = w and w.partFor("door", e.a)
			local cam = workspace.CurrentCamera
			local now = os.clock()
			if door and door:IsA("BasePart") and cam and shown and now - lastPush >= VM.PUSH_COOLDOWN then
				local to = door.Position - cam.CFrame.Position
				local flat = Vector3.new(to.X, 0, to.Z)
				local look = cam.CFrame.LookVector
				local fl = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude <= VM.PUSH_RANGE and fl.Magnitude > 1e-3 and flat.Magnitude > 1e-3 then
					local ang = math.deg(math.acos(math.clamp(flat.Unit:Dot(fl.Unit), -1, 1)))
					if ang <= VM.PUSH_CONE then
						lastPush = now
						vm.play("push")
					end
				end
			end
		end
	end

	local function weights(now: number): { [string]: number }
		local w = {}
		for name, t0 in actions do
			local a = VM.ACTIONS[name]
			local e = now - t0
			local v = ViewmodelMath.envelope(e, a.time, held[name])
			if v <= 0 and e > ViewmodelMath.duration(a.time) and not held[name] then
				actions[name] = nil
			else
				w[name] = v
			end
		end
		return w
	end

	-- The held loot: a scaled local copy of your first carried item (WorldView.heldPart).
	local function updateHeld(): BasePart?
		local w = deps.world
		local src: BasePart?, size: Vector3? = nil, nil
		if w and w.heldPart then
			src, size = w.heldPart()
		end
		if src ~= heldSource then
			if heldCopy then
				heldCopy:Destroy()
				heldCopy = nil
			end
			heldSource = src
			if src then
				local made = Viewmodel.heldCopy(src, size)
				made.Parent = rig.model
				heldCopy = made
			end
		end
		return heldCopy
	end

	local function step(dt: number)
		local cam = workspace.CurrentCamera
		local char = player and player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local on = state.fpView == true and cam ~= nil and hum ~= nil and hum.Health > 0
		setShown(on)
		if not on or not cam then
			lastLook = nil
			return
		end
		if frozen and frozen() then
			return -- hit-stop: the hands hold too
		end
		local now = os.clock()
		checkKit(now)
		recolour()
		local reducedMotion = state.reduced == true
		local camCf = cam.CFrame
		-- Look lag from the camera's own rotation since last frame (works for every input).
		local yawSpeed, pitchSpeed = 0, 0
		if lastLook and dt > 1e-4 then
			local y0, p0 = FpMath.angles({ lastLook.LookVector.X, lastLook.LookVector.Y, lastLook.LookVector.Z })
			local y1, p1 = FpMath.angles({ camCf.LookVector.X, camCf.LookVector.Y, camCf.LookVector.Z })
			yawSpeed = FpMath.wrap(y1 - y0) / dt
			pitchSpeed = (p1 - p0) / dt
		end
		lastLook = camCf
		local L = VM.LAG
		local tx, ty, tr = ViewmodelMath.lagTarget(yawSpeed, pitchSpeed, L)
		lagX, lagVX = FpMath.spring(lagX, lagVX, tx, dt, L.FREQ, L.DAMPING)
		lagY, lagVY = FpMath.spring(lagY, lagVY, ty, dt, L.FREQ, L.DAMPING)
		lagR, lagVR = FpMath.spring(lagR, lagVR, tr, dt, L.FREQ, L.DAMPING)
		-- Carry, hide and wall blends.
		local loot = updateHeld()
		local k = FpMath.damp(1 / math.max(VM.CARRY.BLEND_SECONDS, 1e-3) * 3, dt)
		carry += ((if loot then 1 else 0) - carry) * k
		local kh = FpMath.damp(1 / math.max(VM.HIDDEN_SECONDS, 1e-3) * 3, dt)
		hidden += ((if state.fpHidden then 1 else 0) - hidden) * kh
		rayParams.FilterDescendantsInstances = { rig.model, char :: Instance }
		local hit = workspace:Raycast(camCf.Position, camCf.LookVector * VM.WALL.RANGE, rayParams)
		local pull = ViewmodelMath.wallPull(if hit then hit.Distance else nil, VM.WALL.RANGE)
		wall += (pull - wall) * FpMath.damp(VM.WALL.RATE, dt)
		local phase, amp = camera.bob()
		local w = weights(now)
		local tap: number? = nil
		local watchW = w.watch
		if watchW and watchW > 0 then
			local spec = VM.ACTIONS.watch.tap
			tap = math.max(0, math.sin((now - actions.watch) * 2 * math.pi * spec[2])) * spec[1] * watchW
		end
		local R, Lh = ViewmodelMath.hands(VM, {
			t = now,
			bobPhase = phase,
			bobAmp = amp,
			lagX = lagX,
			lagY = lagY,
			lagRoll = lagR,
			carry = carry,
			hidden = hidden,
			wall = wall,
			actions = w,
			tap = tap,
			reduced = reducedMotion,
		})
		local fit = ViewmodelMath.fovFit(cam.FieldOfView, VM.FOV_REF)
		local rCf = poseFrame(camCf, R, fit)
		local lCf = poseFrame(camCf, Lh, fit)
		local parts: { BasePart } = {}
		local cfs: { CFrame } = {}
		for i, p in rig.R.parts do
			table.insert(parts, p)
			table.insert(cfs, rCf * rig.R.offsets[i])
		end
		for i, p in rig.L.parts do
			table.insert(parts, p)
			table.insert(cfs, lCf * rig.L.offsets[i])
		end
		if loot then
			-- between the hands: the carry pose's loot point, moved with the hands' midpoint
			local C = VM.CARRY
			local mid = { (R[1] + Lh[1]) / 2, (R[2] + Lh[2]) / 2, (R[3] + Lh[3]) / 2 }
			local rest = { (C.R[1] + C.L[1]) / 2, (C.R[2] + C.L[2]) / 2, (C.R[3] + C.L[3]) / 2 }
			local s = VM.SCALE
			local at = {
				(C.LOOT[1] + mid[1] - rest[1]) * s * fit,
				(C.LOOT[2] + mid[2] - rest[2]) * s * fit,
				(C.LOOT[3] + mid[3] - rest[3]) * s,
			}
			table.insert(parts, loot)
			table.insert(cfs, camCf * CFrame.new(at[1], at[2], at[3]) * CFrame.Angles(0, 0, math.rad(lagR)))
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end

	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		debug.profilebegin("EH.Viewmodel")
		step(dt)
		debug.profileend()
	end)

	if player then
		player.CharacterRemoving:Connect(function()
			table.clear(actions)
			table.clear(held)
			setShown(false)
		end)
	end

	-- Tests and the debug chip.
	function vm.debugState(): any
		local n = 0
		for _ in actions do
			n += 1
		end
		return { shown = shown, kit = rig.kit, carry = carry, actions = n, holding = heldCopy ~= nil }
	end

	function vm.rig(): Rig
		return rig
	end

	return vm
end

return Viewmodel
