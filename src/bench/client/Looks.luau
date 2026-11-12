-- Builds one bench clone in a given look (MASTERPLAN §6.5 #3) and poses it
-- each frame. Avatar looks (A, B) clone the stripped template the server put
-- in ReplicatedStorage and play the walk clip on its Animator. The hologram
-- mannequin (C) is a few rigid parts moved with BulkMoveTo, plus the owner's
-- hair/hat copied from the template. The mannequin is also the fallback rig
-- when no avatar template could be built.

local BenchConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Bench"):WaitForChild("BenchConfig"))

local Looks = {}

export type Look = {
	id: string,
	name: string,
	rig: string,
	transparency: number,
	highlight: boolean,
	fillTransparency: number,
	outlineTransparency: number,
}

type Limb = { part: BasePart, pivot: CFrame, offset: CFrame, swing: number }

export type Rig = {
	model: Model,
	kind: string, -- "avatar" or "mannequin"
	root: BasePart?, -- avatar: anchored HumanoidRootPart
	rootHeight: number, -- studs from the floor to the root (avatar) or 0 (mannequin)
	animator: Animator?,
	track: AnimationTrack?,
	limbs: { Limb }, -- mannequin parts, posed relative to the feet
}

local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = BenchConfig.WALK_ANIM

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

function Looks.buildAvatar(template: Model, hue: Color3, look: Look): Rig?
	local model = template:Clone()
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			d.Color = hue
			d.Transparency = look.transparency
		end
	end
	root.Anchored = true
	local hum = model:FindFirstChildOfClass("Humanoid")
	local rootHeight = root.Size.Y / 2 + (if hum then hum.HipHeight else 2)
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	return {
		model = model,
		kind = "avatar",
		root = root,
		rootHeight = rootHeight,
		animator = animator,
		track = nil,
		limbs = {},
	}
end

-- Mannequin layout: name, size, pivot (feet space), offset from pivot, swing sign, neon trim?
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

-- Copy up to MAX_ACCESSORIES hair/hat handles from the template and place them
-- on the mannequin head through the matching head attachment.
local function addAccessories(
	model: Model,
	limbs: { Limb },
	template: Model?,
	hue: Color3,
	look: Look,
	headPivot: CFrame
)
	if not template then
		return
	end
	local head = template:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local added = 0
	for _, acc in template:GetChildren() do
		if added >= BenchConfig.MAX_ACCESSORIES then
			break
		end
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			for _, att in handle:GetChildren() do
				local headAtt = att:IsA("Attachment") and head:FindFirstChild(att.Name)
				if headAtt and headAtt:IsA("Attachment") then
					local copy = handle:Clone()
					for _, child in copy:GetChildren() do
						if not child:IsA("DataModelMesh") then
							child:Destroy() -- welds and attachments; SpecialMesh stays
						end
					end
					quiet(copy)
					copy.Color = hue
					copy.Transparency = look.transparency
					copy.Parent = model
					-- Head-relative offset (our head is close to the R15 head size)
					local offset = headAtt.CFrame * att.CFrame:Inverse()
					table.insert(limbs, { part = copy, pivot = headPivot, offset = offset, swing = 0 })
					added += 1
					break
				end
			end
		end
	end
end

function Looks.buildMannequin(template: Model?, hue: Color3, look: Look): Rig
	local model = Instance.new("Model")
	model.Name = "Mannequin"
	local limbs: { Limb } = {}
	local headPivot = CFrame.new(0, 4.65, 0)
	for _, spec in MANNEQUIN do
		local name, size, pivot, offset, swing, trim = spec[1], spec[2], spec[3], spec[4], spec[5], spec[6]
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		quiet(p)
		if name == "Head" then
			p.Shape = Enum.PartType.Ball
		end
		p.Color = hue
		if trim then
			p.Material = Enum.Material.Neon
			p.Transparency = 0
		else
			p.Transparency = look.transparency
		end
		p.Parent = model
		table.insert(limbs, { part = p, pivot = CFrame.new(pivot), offset = CFrame.new(offset), swing = swing })
	end
	addAccessories(model, limbs, template, hue, look, headPivot)
	return { model = model, kind = "mannequin", root = nil, rootHeight = 0, animator = nil, track = nil, limbs = limbs }
end

function Looks.build(look: Look, template: Model?, hue: Color3): Rig
	if look.rig == "avatar" and template then
		local rig = Looks.buildAvatar(template, hue, look)
		if rig then
			return rig
		end
	end
	return Looks.buildMannequin(template, hue, look)
end

-- Load and start the walk clip once the rig is in the workspace (an Animator
-- outside the DataModel cannot load clips).
function Looks.start(rig: Rig)
	local animator = rig.animator
	if not animator or rig.track then
		return
	end
	local ok, result = pcall(function()
		local track = animator:LoadAnimation(walkAnim)
		track.Looped = true
		track:Play(0)
		track:AdjustSpeed(BenchConfig.WALK_SPEED / BenchConfig.WALK_ANIM_BASE_SPEED)
		return track
	end)
	if ok then
		rig.track = result
	else
		warn("[Bench] walk clip failed:", result)
	end
end

-- Append this rig's parts and target CFrames for one BulkMoveTo call.
-- `feet` is the floor point under the rig, already facing the walk direction.
function Looks.pose(rig: Rig, feet: CFrame, phase: number, parts: { BasePart }, cframes: { CFrame })
	local root = rig.root
	if root then
		table.insert(parts, root)
		table.insert(cframes, feet * CFrame.new(0, rig.rootHeight, 0))
		return
	end
	local swing = math.sin(phase) * BenchConfig.MANNEQUIN_SWING
	for _, limb in rig.limbs do
		table.insert(parts, limb.part)
		if limb.swing ~= 0 then
			table.insert(cframes, feet * limb.pivot * CFrame.Angles(swing * limb.swing, 0, 0) * limb.offset)
		else
			table.insert(cframes, feet * limb.pivot * limb.offset)
		end
	end
end

return Looks
