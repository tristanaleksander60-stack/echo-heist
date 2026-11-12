--!strict
-- Heist/Rigs: client rigs for clones and Gus (MASTERPLAN §6.5).
--   * Avatar rig: a clone of the owner's stripped template (server-built, §6.5 #1),
--     tinted in the owner hue, anchored root moved with BulkMoveTo, walk clip on its
--     Animator. Look B (opaque glow): the owner group's Highlight draws the outline.
--   * Mannequin: a few rigid parts posed by hand; the placeholder until the owner's
--     template arrives (and the fallback when it cannot be built).
--   * Gus: a rigid-part rig with R15 proportions (no skinning), posed like the
--     mannequin, holding a torch in Torch Amber; a Santa hat (Ribbon Burgundy, Snow)
--     instead of his cap when the Christmas dressing layer is on.
--   * Copy: a local copy of a live character (the player in the Crew Line-up), its
--     look untouched.
-- Poses append to (parts, cframes) so each view does one BulkMoveTo per frame; the
-- Line-up adds a cheer pose (arms up on rigid rigs, the cheer clip on avatars).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local Rigs = {}

type Limb = { part: BasePart, pivot: CFrame, offset: CFrame, swing: number }

export type Rig = {
	model: Model,
	kind: string, -- "avatar" | "mannequin" | "gus"
	root: BasePart?, -- avatar: the anchored HumanoidRootPart
	rootHeight: number, -- avatar: studs from the floor to the root
	animator: Animator?,
	track: AnimationTrack?,
	limbs: { Limb },
	tinted: { BasePart }, -- parts that take the owner hue
	head: BasePart?,
	parts: { BasePart }?, -- every BasePart, cached on first use (setFade)
	speedBucket: number?, -- last walk-speed bucket sent to AdjustSpeed
	fadeShown: number?, -- last alpha setFade wrote
}

local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = Config.ECHO_WALK_ANIM

local SWING = math.rad(32)

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

function Rigs.buildAvatar(template: Model): Rig?
	local model = template:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	local tinted = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Transparency = 0
			table.insert(tinted, d)
		end
	end
	root.Anchored = true
	local hum = model:FindFirstChildOfClass("Humanoid")
	local rootHeight = root.Size.Y / 2 + (if hum then hum.HipHeight else 2)
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local head = model:FindFirstChild("Head")
	return {
		model = model,
		kind = "avatar",
		root = root,
		rootHeight = rootHeight,
		animator = animator,
		track = nil,
		limbs = {},
		tinted = tinted,
		head = if head and head:IsA("BasePart") then head else nil,
	}
end

-- name, size, pivot (feet space), offset from pivot, swing sign, trim (neon), colour role
local MANNEQUIN = {
	{ "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), Vector3.zero, 0, false },
	{ "Belt", Vector3.new(2.06, 0.25, 1.06), Vector3.new(0, 2.1, 0), Vector3.zero, 0, true },
	{ "Head", Vector3.new(1.25, 1.25, 1.25), Vector3.new(0, 4.65, 0), Vector3.zero, 0, false },
	{ "Visor", Vector3.new(1.0, 0.22, 0.1), Vector3.new(0, 4.75, -0.6), Vector3.zero, 0, true },
	{ "LeftArm", Vector3.new(0.9, 2, 0.9), Vector3.new(-1.45, 3.9, 0), Vector3.new(0, -0.9, 0), 1, false },
	{ "RightArm", Vector3.new(0.9, 2, 0.9), Vector3.new(1.45, 3.9, 0), Vector3.new(0, -0.9, 0), -1, false },
	{ "LeftLeg", Vector3.new(0.95, 2, 0.95), Vector3.new(-0.5, 2, 0), Vector3.new(0, -1, 0), -1, false },
	{ "RightLeg", Vector3.new(0.95, 2, 0.95), Vector3.new(0.5, 2, 0), Vector3.new(0, -1, 0), 1, false },
}

function Rigs.buildMannequin(): Rig
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local limbs: { Limb } = {}
	local tinted = {}
	local head: BasePart? = nil
	for _, spec in MANNEQUIN do
		local name, size, pivot, offset, swing, trim = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		quiet(p)
		if name == "Head" then
			p.Shape = Enum.PartType.Ball
			head = p
		end
		if trim then
			p.Material = Enum.Material.Neon
		end
		p.Parent = model
		table.insert(tinted, p)
		table.insert(limbs, { part = p, pivot = CFrame.new(pivot), offset = CFrame.new(offset), swing = swing })
	end
	return {
		model = model,
		kind = "mannequin",
		root = nil,
		rootHeight = 3,
		animator = nil,
		track = nil,
		limbs = limbs,
		tinted = tinted,
		head = head,
	}
end

-- Gus: navy uniform, marble face, cap, a torch in Torch Amber (the cone's colour).
-- The 7th field marks the cap pieces the Santa hat replaces.
local GUS = {
	{ "Torso", Vector3.new(2.2, 2.1, 1.1), Vector3.new(0, 3.05, 0), Vector3.zero, 0, "uniform" },
	{ "Badge", Vector3.new(0.4, 0.4, 0.1), Vector3.new(0.55, 3.5, -0.58), Vector3.zero, 0, "gold" },
	{ "Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 4.8, 0), Vector3.zero, 0, "skin" },
	{ "Cap", Vector3.new(1.45, 0.45, 1.45), Vector3.new(0, 5.55, 0), Vector3.zero, 0, "uniform", true },
	{ "Brim", Vector3.new(1.4, 0.12, 0.7), Vector3.new(0, 5.35, -0.9), Vector3.zero, 0, "ink", true },
	{ "LeftArm", Vector3.new(0.95, 2.1, 0.95), Vector3.new(-1.6, 4.0, 0), Vector3.new(0, -0.95, 0), 1, "uniform" },
	{ "RightArm", Vector3.new(0.95, 2.1, 0.95), Vector3.new(1.6, 4.0, 0), Vector3.new(0, -0.95, 0), 0, "uniform" },
	{ "Torch", Vector3.new(0.4, 0.4, 1.2), Vector3.new(1.6, 3.0, -0.8), Vector3.zero, 0, "amber" },
	{ "LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.55, 2, 0), Vector3.new(0, -1, 0), -1, "ink" },
	{ "RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.55, 2, 0), Vector3.new(0, -1, 0), 1, "ink" },
}

-- Santa hat (name, shape, size, pivot CFrame in feet space, colour role); a vertical
-- cylinder is an X-axis cylinder turned 90 degrees about Z.
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)
local SANTA = {
	{ "HatBand", Enum.PartType.Cylinder, Vector3.new(0.35, 1.6, 1.6), CFrame.new(0, 5.42, 0) * UPRIGHT, "snow" },
	{
		"HatCrown",
		Enum.PartType.Cylinder,
		Vector3.new(0.8, 1.25, 1.25),
		CFrame.new(0, 5.92, 0.12) * CFrame.Angles(math.rad(-20), 0, 0) * UPRIGHT,
		"ribbon",
	},
	{ "HatTip", Enum.PartType.Ball, Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, 6.32, 0.42), "ribbon" },
	{ "HatPom", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 6.42, 0.86), "snow" },
}

function Rigs.buildGus(santa: boolean?): Rig
	local model = Instance.new("Model")
	model.Name = "Gus"
	local colours = {
		uniform = Palette.steelLo,
		skin = Palette.marble,
		ink = Palette.ink,
		gold = Palette.gold,
		amber = Palette.amber,
		ribbon = Palette.ribbon,
		snow = Palette.snow,
	}
	local limbs: { Limb } = {}
	local head: BasePart? = nil
	if santa then
		for _, spec in SANTA do
			local p = Instance.new("Part")
			p.Name = spec[1]
			p.Shape = spec[2]
			p.Size = spec[3]
			quiet(p)
			p.CastShadow = true
			p.Color = colours[spec[5]]
			p.Parent = model
			table.insert(limbs, { part = p, pivot = spec[4], offset = CFrame.identity, swing = 0 })
		end
	end
	for _, spec in GUS do
		local name, size, pivot, offset, swing, role, cap =
			spec[1], spec[2], spec[3], spec[4], spec[5], spec[6], spec[7]
		if cap and santa then
			continue
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		quiet(p)
		p.CastShadow = true
		p.Color = colours[role]
		if role == "amber" then
			p.Material = Enum.Material.Neon
		end
		if name == "Head" then
			head = p
		end
		p.Parent = model
		table.insert(limbs, { part = p, pivot = CFrame.new(pivot), offset = CFrame.new(offset), swing = swing })
	end
	return {
		model = model,
		kind = "gus",
		root = nil,
		rootHeight = 3,
		animator = nil,
		track = nil,
		limbs = limbs,
		tinted = {},
		head = head,
	}
end

function Rigs.tint(rig: Rig, hue: Color3)
	for _, p in rig.tinted do
		p.Color = hue
	end
end

-- Every BasePart of a rig, collected once (rigs never gain parts after they are built).
function Rigs.partsOf(rig: Rig): { BasePart }
	local list = rig.parts
	if list then
		return list
	end
	local out: { BasePart } = {}
	for _, d in rig.model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	rig.parts = out
	return out
end

-- Hide or show a whole rig locally (LocalTransparencyModifier: client-only).
function Rigs.setFade(rig: Rig, alpha: number)
	if rig.fadeShown == alpha then
		return
	end
	rig.fadeShown = alpha
	for _, p in Rigs.partsOf(rig) do
		p.LocalTransparencyModifier = alpha
	end
end

-- Starts the walk clip once the rig is in the DataModel.
function Rigs.startWalk(rig: Rig)
	local animator = rig.animator
	if not animator or rig.track then
		return
	end
	local ok, result = pcall(function()
		local track = animator:LoadAnimation(walkAnim)
		track.Looped = true
		return track
	end)
	if ok then
		rig.track = result
	end
end

-- Walk speed (studs/s) drives the clip; under 1 stud/s the rig stands.
function Rigs.setSpeed(rig: Rig, speed: number)
	local track = rig.track
	if not track then
		return
	end
	if speed > 1 then
		if not track.IsPlaying then
			track:Play(0.15)
			rig.speedBucket = nil
		end
		-- AdjustSpeed only when the speed moves by half a stud/s (not every frame).
		local bucket = math.floor(speed * 2 + 0.5)
		if bucket ~= rig.speedBucket then
			rig.speedBucket = bucket
			track:AdjustSpeed(bucket / 2 / Config.Heist.WALK_ANIM_BASE_SPEED)
		end
	elseif track.IsPlaying then
		track:Stop(0.2)
		rig.speedBucket = nil
	end
end

-- Appends this rig's parts and target CFrames for one BulkMoveTo call.
-- `feet` is the floor point under the rig facing its yaw; `phase` drives the limb swing.
function Rigs.pose(rig: Rig, feet: CFrame, phase: number, amount: number, parts: { BasePart }, cframes: { CFrame })
	local root = rig.root
	if root then
		table.insert(parts, root)
		table.insert(cframes, feet * CFrame.new(0, rig.rootHeight, 0))
		return
	end
	local swing = math.sin(phase) * SWING * amount
	for _, limb in rig.limbs do
		table.insert(parts, limb.part)
		if limb.swing ~= 0 then
			table.insert(cframes, feet * limb.pivot * CFrame.Angles(swing * limb.swing, 0, 0) * limb.offset)
		else
			table.insert(cframes, feet * limb.pivot * limb.offset)
		end
	end
end

-- The part a badge or bubble hangs from.
function Rigs.anchorPart(rig: Rig): BasePart
	return rig.head or rig.root or rig.limbs[1].part
end

-- A local copy of a live character, its look untouched (the player in the Crew Line-up).
-- Scripts removed, every part anchored-free but non-colliding, the root anchored.
function Rigs.buildCopy(character: Model): Rig?
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function()
		return character:Clone()
	end)
	character.Archivable = was
	if not ok or not copy then
		return nil
	end
	local model = copy :: Model
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Anchored = false
			d.LocalTransparencyModifier = 0
		end
	end
	root.Anchored = true
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.EvaluateStateMachine = false -- a posed copy: no physics states (the Animator still plays)
	end
	local rootHeight = root.Size.Y / 2 + (if hum then hum.HipHeight else 2)
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local head = model:FindFirstChild("Head")
	return {
		model = model,
		kind = "avatar",
		root = root,
		rootHeight = rootHeight,
		animator = animator,
		track = nil,
		limbs = {},
		tinted = {},
		head = if head and head:IsA("BasePart") then head else nil,
	}
end

-- Plays a one-shot clip on an avatar rig (the Line-up cheer). Returns false when the rig
-- has no Animator or the clip does not load (rigid rigs pose with poseCheer instead).
local cheerAnim: Animation? = nil
function Rigs.playCheer(rig: Rig, animId: string): boolean
	local animator = rig.animator
	if not animator then
		return false
	end
	if not cheerAnim then
		local a = Instance.new("Animation")
		a.AnimationId = animId
		cheerAnim = a
	end
	local ok = pcall(function()
		local track = animator:LoadAnimation(cheerAnim :: Animation)
		track.Looped = false
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.1)
	end)
	return ok
end

-- Rigid rigs (mannequin, Gus): arms raised by `amount` (0 = down, 1 = up), plus `lift`
-- studs (the victory hop). Avatars move their root only (the cheer clip does the arms).
function Rigs.poseCheer(rig: Rig, feet: CFrame, amount: number, lift: number, parts: { BasePart }, cframes: { CFrame })
	local at = feet * CFrame.new(0, lift, 0)
	local root = rig.root
	if root then
		table.insert(parts, root)
		table.insert(cframes, at * CFrame.new(0, rig.rootHeight, 0))
		return
	end
	local raise = math.rad(165) * math.clamp(amount, 0, 1)
	for _, limb in rig.limbs do
		local name = limb.part.Name
		table.insert(parts, limb.part)
		if name == "LeftArm" or name == "RightArm" then
			local side = if name == "LeftArm" then 1 else -1
			table.insert(cframes, at * limb.pivot * CFrame.Angles(raise, 0, side * math.rad(12) * amount) * limb.offset)
		else
			table.insert(cframes, at * limb.pivot * limb.offset)
		end
	end
end

return Rigs
