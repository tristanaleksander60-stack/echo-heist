--!strict
-- Heist/Rookie: builds the Rookie, the player character (PLAN_FIRST_PERSON "CH"), from the art kit.
--
-- Publishes ReplicatedStorage/<Config.Rookie.KIT_FOLDER> ("CharacterKit") once the kit is loaded:
--   Pieces            every Rookie kit piece (body, faces, outfit pieces, viewmodel arms), as KitService prepared them
--   Rookie            the template character: default outfit, seat-1 hue (a whole R15 character Model)
--   Rookie_Viewmodel  the first-person arms for the FP track: LeftArm, RightArm (anchored, no collisions, no
--                     shadows), each with its grip attachment (GripL / GripR at the palm) and an Elbow attachment
-- The folder is filled before it is parented, so a client never sees half of it.
--
-- A character is R15: the 15 body parts carry the R15 names, Motor6Ds named as R15 joints (Root, Waist, Neck,
-- LeftShoulder ... RightAnkle) join them at the art's joint pivots, with the R15 rig attachments
-- (<Joint>RigAttachment) at the same points and the accessory attachments (HatAttachment, NeckAttachment,
-- RightGripAttachment ...), so the default Animate clips, the uploaded CloneClips and Roblox emotes play. The
-- HumanoidRootPart is 2 x 2 x 1 with its centre 3 studs up (HipHeight Config.Rookie.HIP_HEIGHT: the sim's
-- rootHeight), joined to the hip centre below it. Faces and outfit pieces are welded to their body part by pivot
-- (RookieData.attach). Crew pieces take the seat hue, gloves the glove colour (attribute EH_Tint).
-- Without the kit (it failed to load) the same rig is built from blocks (sizes from RookieData), so a player is
-- always a Rookie-shaped character with the default animations.
-- Cosmetic only: nothing here decides anything (the sim reads actor positions).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local Outfit = require(HeistShared:WaitForChild("Outfit"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local RookieData = require(HeistShared:WaitForChild("RookieData")) :: any

local R = Config.Rookie

local Rookie = {}

local GROUPS = { "Rookie", "Rookie_Faces", "Rookie_Outfits", "Rookie_Viewmodel" }
local MOODS = { "idle", "smug", "shocked", "busted" }

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- Accessory attachments of an R15 rig, as rest-pose points (feet at the origin, facing -Z; the art's numbers in
-- assets/blender/rookie.py). Grips point the R15 way (tools held forward).
local GRIP = CFrame.Angles(-math.pi / 2, 0, 0)
local ACCESSORY: { { any } } = {
	{ "Head", "HatAttachment", Vector3.new(0, 4.2, 0) },
	{ "Head", "HairAttachment", Vector3.new(0, 4.2, 0) },
	{ "Head", "FaceFrontAttachment", Vector3.new(0, 3.72, -0.84) },
	{ "Head", "FaceCenterAttachment", Vector3.new(0, 3.72, 0) },
	{ "UpperTorso", "NeckAttachment", Vector3.new(0, 3.0, 0) },
	{ "UpperTorso", "BodyFrontAttachment", Vector3.new(0, 2.4, -0.74) },
	{ "UpperTorso", "BodyBackAttachment", Vector3.new(0, 2.4, 0.74) },
	{ "UpperTorso", "LeftCollarAttachment", Vector3.new(-0.7, 2.95, 0) },
	{ "UpperTorso", "RightCollarAttachment", Vector3.new(0.7, 2.95, 0) },
	{ "LowerTorso", "WaistCenterAttachment", Vector3.new(0, 1.62, 0) },
	{ "LowerTorso", "WaistFrontAttachment", Vector3.new(0, 1.62, -0.6) },
	{ "LowerTorso", "WaistBackAttachment", Vector3.new(0, 1.62, 0.6) },
	{ "LeftUpperArm", "LeftShoulderAttachment", Vector3.new(-1.0, 3.06, 0) },
	{ "RightUpperArm", "RightShoulderAttachment", Vector3.new(1.0, 3.06, 0) },
	{ "LeftHand", "LeftGripAttachment", Vector3.new(-1.17, 1.3, -0.06), GRIP },
	{ "RightHand", "RightGripAttachment", Vector3.new(1.17, 1.3, -0.06), GRIP },
	{ "LeftFoot", "LeftFootAttachment", Vector3.new(-0.44, 0, -0.25) },
	{ "RightFoot", "RightFootAttachment", Vector3.new(0.44, 0, -0.25) },
}

-- The published kit folder, or nil.
function Rookie.kitFolder(): Folder?
	local f = ReplicatedStorage:FindFirstChild(R.KIT_FOLDER)
	return if f and f:IsA("Folder") then f else nil
end

-- Yields until the kit folder is published, at most `timeout` seconds. True when it is there.
function Rookie.waitForKit(timeout: number): boolean
	local deadline = os.clock() + timeout
	while Rookie.kitFolder() == nil and os.clock() < deadline do
		task.wait(0.25)
	end
	return Rookie.kitFolder() ~= nil
end

local function piecesFolder(): Instance?
	local f = Rookie.kitFolder()
	return f and f:FindFirstChild("Pieces")
end

-- A fresh copy of a kit piece from the published folder (or the given one), or nil.
local function pieceFrom(pieces: Instance?, name: string): BasePart?
	local t = pieces and pieces:FindFirstChild(name)
	if t and t:IsA("BasePart") then
		return t:Clone()
	end
	return nil
end

local function blockColour(part: string): Color3
	local c = R.BLOCK_COLOURS
	local key = if part == "Head"
			or part == "UpperTorso"
			or part == "LowerTorso"
		then part
		elseif string.find(part, "Hand", 1, true) then "Hand"
		elseif string.find(part, "Foot", 1, true) then "Foot"
		elseif string.find(part, "Arm", 1, true) then "Arm"
		else "Leg"
	return Color3.fromHex(c[key])
end

-- The block stand-in for a body part (no kit): its size at its centre, pivot at its joint.
local function blockPart(b: any): BasePart
	local p = Instance.new("Part")
	p.Size = v3(b.size)
	p.CFrame = CFrame.new(v3(b.centre))
	p.PivotOffset = CFrame.new(v3(b.origin) - v3(b.centre))
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = blockColour(b.part)
	if b.part == "UpperTorso" then
		p:SetAttribute("EH_Tint", "crew") -- the block Rookie keeps the crew colour on its sweater
	end
	return p
end

local function quietPiece(p: BasePart)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
end

-- Welds a face or outfit piece to its body part, its pivot at the part's pivot + the attach offset (any pose).
local function attachPiece(model: Model, p: BasePart, name: string): boolean
	local a = RookieData.attach[name]
	local host = a and model:FindFirstChild(a.part)
	if not host or not host:IsA("BasePart") then
		p:Destroy()
		return false
	end
	quietPiece(p)
	p:PivotTo(host:GetPivot() * CFrame.new(v3(a.offset)))
	local w = Instance.new("Weld")
	w.Name = "EH_Weld"
	w.Part0 = host
	w.Part1 = p
	w.C0 = host.CFrame:ToObjectSpace(p.CFrame)
	w.C1 = CFrame.identity
	w.Parent = p
	p.Parent = model
	return true
end

export type Joints = "motor" | "constraint"

-- Assembles a whole character from a piece source (the published Pieces folder, or nil for blocks). The default
-- outfit and seat-1 hue are applied; Rookie.apply changes them. joints: "motor" (Motor6Ds: the StarterCharacter;
-- the engine's Avatar Joint Upgrade may turn them into AnimationConstraints at spawn) or "constraint" (kinematic
-- AnimationConstraints on the rig attachments, as 2026 avatar rigs: the clone templates, which the engine tests
-- animate by stepping the Animator).
function Rookie.assemble(pieces: Instance?, joints: Joints?): Model
	local model = Instance.new("Model")
	model.Name = "Rookie"
	model:SetAttribute("EH_Rookie", true)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = v3(R.ROOT_SIZE)
	root.Transparency = 1
	root.CanCollide = true
	root.Material = Enum.Material.SmoothPlastic
	root.CFrame = CFrame.new(0, R.HIP_HEIGHT + root.Size.Y / 2, 0)
	root.Parent = model
	model.PrimaryPart = root
	local rootAtt = Instance.new("Attachment")
	rootAtt.Name = "RootAttachment"
	rootAtt.Parent = root

	local parts: { [string]: BasePart } = {}
	local fromKit = 0
	for _, b in RookieData.body do
		local p = pieceFrom(pieces, b.piece)
		if p then
			fromKit += 1
		else
			p = blockPart(b)
		end
		local part = p :: BasePart
		part.Name = b.part
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = true
		part.CanTouch = true
		part.Massless = false
		part:PivotTo(CFrame.new(v3(b.origin)))
		local tint = RookieData.tint[b.part]
		if tint then
			part:SetAttribute("EH_Tint", tint)
		end
		part.Parent = model
		parts[b.part] = part
	end
	model:SetAttribute("EH_Blocks", fromKit < #RookieData.body)

	-- Joints: named as the R15 joint, in the child part, with the two rig attachments at the art's pivot.
	for _, b in RookieData.body do
		local part = parts[b.part]
		local parent: BasePart = if b.parent then parts[b.parent] else root
		local at = CFrame.new(v3(b.origin))
		local attName = (if b.joint == "Root" then "Root" else b.joint) .. "RigAttachment"
		local a0 = Instance.new("Attachment")
		a0.Name = attName
		a0.CFrame = parent.CFrame:ToObjectSpace(at)
		a0.Parent = parent
		local a1 = Instance.new("Attachment")
		a1.Name = attName
		a1.CFrame = part.CFrame:ToObjectSpace(at)
		a1.Parent = part
		if joints == "constraint" then
			local c = Instance.new("AnimationConstraint")
			c.Name = b.joint
			c.Attachment0 = a0
			c.Attachment1 = a1
			c.IsKinematic = true
			c.Parent = part
		else
			local m = Instance.new("Motor6D")
			m.Name = b.joint
			m.Part0 = parent
			m.Part1 = part
			m.C0 = a0.CFrame
			m.C1 = a1.CFrame
			m.Parent = part
		end
	end
	for _, spec in ACCESSORY do
		local part = parts[spec[1]]
		if part then
			local a = Instance.new("Attachment")
			a.Name = spec[2]
			a.CFrame = part.CFrame:ToObjectSpace(CFrame.new(spec[3])) * (spec[4] or CFrame.identity)
			a.Parent = part
		end
	end

	-- Faces: all four welded to the head, one shown.
	for _, mood in MOODS do
		local name = RookieData.faces[mood]
		local p = pieceFrom(pieces, name)
		if p then
			p.CastShadow = false
			p:SetAttribute("EH_Face", mood)
			attachPiece(model, p, name)
		end
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.AutomaticScalingEnabled = false
	hum.HipHeight = R.HIP_HEIGHT
	local animator = Instance.new("Animator")
	animator.Parent = hum
	hum.Parent = model
	Rookie.setFace(model, "idle")
	-- the same piece source as the body: while publishNow builds the template, the kit folder is not parented yet
	Rookie.apply(model, Outfit.default(), Palette.hueFor(1), pieces)
	return model
end

-- Shows one face (idle, smug, shocked, busted) and hides the others. Safe on any model.
function Rookie.setFace(model: Model, mood: string)
	local any = false
	for _, d in model:GetChildren() do
		local m = d:GetAttribute("EH_Face")
		if m ~= nil and d:IsA("BasePart") then
			local show = m == mood
			any = any or show
			d.Transparency = if show then 0 else 1
			d:SetAttribute("EH_Hidden", not show)
		end
	end
	if not any and mood ~= "idle" then
		Rookie.setFace(model, "idle")
		return
	end
	model:SetAttribute("EH_FaceShown", if any then mood else "idle")
end

-- Dresses a Rookie in an outfit and a crew hue (idempotent: the previous outfit pieces go). Works on a live
-- character in any pose (pieces weld by pivot), on templates and on the StarterCharacter. source: where the
-- pieces come from (default: the published kit folder's Pieces).
function Rookie.apply(model: Model, outfit: Outfit.Outfit, hue: Color3, source: Instance?)
	local clean = Outfit.clean(outfit)
	local key = Outfit.key(clean)
	if model:GetAttribute("EH_Outfit") ~= key then
		for _, d in model:GetChildren() do
			if d:GetAttribute("EH_Slot") ~= nil then
				d:Destroy()
			end
		end
		local pieces = source or piecesFolder()
		for _, name in Outfit.pieces(clean) do
			local p = pieceFrom(pieces, name)
			if p then
				local def = RookieData.tint[name]
				p:SetAttribute("EH_Slot", true)
				if def then
					p:SetAttribute("EH_Tint", def)
				end
				attachPiece(model, p, name)
			end
		end
		model:SetAttribute("EH_Outfit", key)
	end
	local glove = Color3.fromHex(Outfit.gloveHex(clean))
	for _, d in model:GetChildren() do
		local tint = d:GetAttribute("EH_Tint")
		if d:IsA("BasePart") and tint ~= nil then
			d.Color = if tint == "crew" then hue else glove
		end
	end
	model:SetAttribute("EH_Hue", hue:ToHex())
end

-- A whole character in an outfit and hue: from the published kit, or blocks when the kit is not there.
function Rookie.build(outfit: Outfit.Outfit?, hue: Color3?, joints: Joints?): Model
	local model = Rookie.assemble(piecesFolder(), joints)
	Rookie.apply(model, outfit or Outfit.default(), hue or Palette.hueFor(1))
	return model
end

-- The first-person arms (FP track): LeftArm and RightArm with their grips, at their rest places.
local function viewmodel(pieces: Instance): Model?
	local vm = Instance.new("Model")
	vm.Name = "Rookie_Viewmodel"
	for side, d in RookieData.viewmodel do
		local p = pieceFrom(pieces, d.piece)
		if p == nil then
			vm:Destroy()
			return nil
		end
		local part = p :: BasePart
		part.Name = side
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Massless = true
		local pivot = part:GetPivot()
		local elbow = Instance.new("Attachment")
		elbow.Name = "Elbow"
		elbow.CFrame = part.CFrame:ToObjectSpace(pivot)
		elbow.Parent = part
		local grip = Instance.new("Attachment")
		grip.Name = d.grip
		grip.CFrame = part.CFrame:ToObjectSpace(pivot * CFrame.new(v3(d.gripOffset)))
		grip.Parent = part
		part.Parent = vm
		if side == "RightArm" then
			vm.PrimaryPart = part
		end
	end
	return vm
end

-- Publishes the kit folder now (the kit must be loaded). True when it is published.
function Rookie.publishNow(kit: any): boolean
	if Rookie.kitFolder() ~= nil then
		return true
	end
	if kit == nil or not kit.isReady() then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = R.KIT_FOLDER
	local pieces = Instance.new("Folder")
	pieces.Name = "Pieces"
	for _, group in GROUPS do
		for _, name in RookieData.groups[group] or {} do
			local p = kit.clone(name)
			if p then
				p.Anchored = true
				p.Parent = pieces
			end
		end
	end
	if pieces:FindFirstChild("Rookie_Head") == nil then
		folder:Destroy()
		return false
	end
	pieces.Parent = folder
	local template = Rookie.assemble(pieces)
	template.Name = "Rookie"
	template.Parent = folder
	local vm = viewmodel(pieces)
	if vm then
		vm.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	return true
end

local publishing = false

-- Waits for the kit in the background, then publishes (idempotent).
function Rookie.publish(kit: any)
	if publishing or kit == nil then
		return
	end
	publishing = true
	task.spawn(function()
		local ok, err = pcall(function()
			kit.ready()
			if not Rookie.publishNow(kit) then
				warn("[Rookie] the kit has no Rookie pieces: players are block Rookies")
			end
		end)
		if not ok then
			warn("[Rookie] " .. tostring(err))
		end
	end)
end

return Rookie
