--!strict
-- Heist/GusRig: Gus on his 18-part mesh (PLAN_STEAM_PLUS §4.4 A4, STYLE_BIBLE §12, KIT_IMPORT "Gus").
--   * Mesh rig: a clone of the kit's Gus, which the server copies into
--     ReplicatedStorage/<Config.Gus.TEMPLATE_FOLDER> once the kit has loaded (Heist/GusTemplate). Rigid
--     parts, no skinning; each part's pivot is its joint. The Santa hat replaces the cap on the
--     Christmas layer (same joint).
--   * Box rig: the same 18 joints as boxes sized from the kit bounds (Shared/Heist/GusBeats.PARTS), in
--     Gus's colours. It stands in until the mesh arrives, when the kit never loads, and if a mesh rig
--     breaks (never invisible, PLAN §2 non-negotiable 1).
-- Both pose the same way: FK from the feet, world[joint] = world[parent] * C0 * pose, with
-- C0 = CFrame.new(origin[child] - origin[parent]); the part goes to world[joint] * PivotOffset^-1
-- (the CFrame form of part:PivotTo). Poses append to (parts, cframes) so GusView does one BulkMoveTo
-- per frame. No per-frame tables.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local GusBeats = require(HeistShared:WaitForChild("GusBeats"))
local Palette = require(HeistShared:WaitForChild("Palette"))

local GC = Config.Gus

local GusRig = {}

export type Rig = {
	model: Model,
	kind: string, -- "mesh" | "box"
	parts: { BasePart }, -- GusBeats.PARTS order (the hat in the cap's slot on the Christmas layer)
	inv: { CFrame }, -- PivotOffset:Inverse() per part
	c0: { CFrame }, -- joint frame in the parent joint's frame (the root: in the feet frame)
	parentIx: { number }, -- 0 = the root
	joints: { string },
	world: { CFrame }, -- scratch: each joint's world frame this frame
	neckIx: number,
	waistIx: number,
	head: BasePart,
	root: BasePart,
	foot: BasePart,
	lens: BasePart,
	lensOn: boolean?,
}

local ROLE_COLOUR: { [string]: Color3 } = {
	belt = Palette.ink,
	shirt = Palette.steel,
	skin = Palette.marble,
	cap = Palette.steelLo,
	legs = Palette.inkHi,
	shoe = Palette.ink,
	torch = Palette.steelLo,
	lens = Palette.steelLo,
	hat = Palette.ribbon,
}

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
end

-- The replicated kit folder's parts by name (every BasePart under it; uploaded groups nest Models,
-- so never FindFirstChild(name, true)). nil until the whole 18-part rig is there.
function GusRig.template(): { [string]: BasePart }?
	local folder = ReplicatedStorage:FindFirstChild(GC.TEMPLATE_FOLDER)
	if folder == nil then
		return nil
	end
	local map: { [string]: BasePart } = {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			map[d.Name] = d
		end
	end
	for _, spec in GusBeats.PARTS do
		if map[spec.name] == nil then
			return nil
		end
	end
	return map
end

local function boxPart(spec: GusBeats.Part): BasePart
	local p = Instance.new("Part")
	p.Name = spec.name
	local mn, mx = spec.min, spec.max
	p.Size = Vector3.new(mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3])
	-- The pivot (joint) relative to the box centre.
	p.PivotOffset = CFrame.new(-(mn[1] + mx[1]) / 2, -(mn[2] + mx[2]) / 2, -(mn[3] + mx[3]) / 2)
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = ROLE_COLOUR[spec.role] or Palette.steel
	if spec.role == "lens" then
		p.Material = Enum.Material.Neon
	end
	return p
end

-- Builds Gus. `santa`: the Christmas hat instead of the cap. `mesh`: false forces the box rig;
-- otherwise the mesh rig when the template is there.
function GusRig.build(santa: boolean?, mesh: boolean?): Rig
	local map = if mesh == false then nil else GusRig.template()
	local model = Instance.new("Model")
	model.Name = "Gus"
	local parts: { BasePart } = {}
	local inv: { CFrame } = {}
	local c0: { CFrame } = {}
	local parentIx: { number } = {}
	local joints: { string } = {}
	local index: { [string]: number } = {}
	for i, spec in GusBeats.PARTS do
		local use = spec
		if spec.name == "Gus_Cap" and santa then
			use = GusBeats.HAT
		end
		local source = map and map[use.name]
		local p: BasePart
		if source then
			p = source:Clone()
		else
			p = boxPart(use)
		end
		quiet(p)
		p.CastShadow = use.role ~= "lens"
		p.Name = use.name
		p.Parent = model
		parts[i] = p
		inv[i] = p.PivotOffset:Inverse()
		index[spec.name] = i
		joints[i] = spec.joint
		local o = spec.origin
		local parent = spec.parent
		if parent then
			local pi = index[parent]
			local po = GusBeats.PARTS[pi].origin
			parentIx[i] = pi
			c0[i] = CFrame.new(o[1] - po[1], o[2] - po[2], o[3] - po[3])
		else
			parentIx[i] = 0
			c0[i] = CFrame.new(o[1], o[2], o[3])
		end
	end
	model.PrimaryPart = parts[1]
	return {
		model = model,
		kind = if map then "mesh" else "box",
		parts = parts,
		inv = inv,
		c0 = c0,
		parentIx = parentIx,
		joints = joints,
		world = table.create(#parts, CFrame.identity),
		neckIx = index.Gus_Head,
		waistIx = index.Gus_UpperTorso,
		head = parts[index.Gus_Head],
		root = parts[1],
		foot = parts[index.Gus_RightFoot],
		lens = parts[index.Gus_FlashlightLens],
		lensOn = nil,
	}
end

-- Appends every part and its target CFrame. `feet`: the floor point under Gus facing his body yaw.
-- lookYaw / lookPitch (radians, already clamped): the head's look on top of the pose, shared between
-- the neck (NECK_SHARE) and the waist.
function GusRig.pose(
	rig: Rig,
	feet: CFrame,
	pose: GusBeats.Pose,
	lookYaw: number,
	lookPitch: number,
	parts: { BasePart },
	cframes: { CFrame }
)
	local J = pose.joints
	local world, c0, parentIx, inv, rigParts = rig.world, rig.c0, rig.parentIx, rig.inv, rig.parts
	local neckIx, waistIx = rig.neckIx, rig.waistIx
	local share = GC.NECK_SHARE
	for i, joint in rig.joints do
		local jp = J[joint]
		local rx, ry = jp[4], jp[5]
		if i == neckIx then
			ry += lookYaw * share
			rx += lookPitch
		elseif i == waistIx then
			ry += lookYaw * (1 - share)
		end
		local pi = parentIx[i]
		local base = if pi == 0 then feet * c0[i] else world[pi] * c0[i]
		local w = base * CFrame.new(jp[1], jp[2], jp[3]) * CFrame.fromEulerAnglesYXZ(rx, ry, jp[6])
		world[i] = w
		table.insert(parts, rigParts[i])
		table.insert(cframes, w * inv[i])
	end
end

-- The torch lens: Torch Amber while the torch is on, Vault Steel shade off (KitData note).
function GusRig.setLens(rig: Rig, on: boolean)
	if rig.lensOn ~= on then
		rig.lensOn = on
		rig.lens.Color = if on then Palette.amber else Palette.steelLo
	end
end

-- Every part still in the rig (a streamed-out or destroyed part breaks it).
function GusRig.whole(rig: Rig): boolean
	for _, p in rig.parts do
		if p.Parent ~= rig.model then
			return false
		end
	end
	return rig.model.Parent ~= nil
end

-- The farthest part centre from the root (studs): a whole, posed Gus stays within his own size.
function GusRig.spread(rig: Rig): number
	local r = rig.root.Position
	local far = 0
	for _, p in rig.parts do
		far = math.max(far, (p.Position - r).Magnitude)
	end
	return far
end

return GusRig
