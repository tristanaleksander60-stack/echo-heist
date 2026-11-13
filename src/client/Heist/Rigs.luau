--!strict
-- Heist/Rigs: client rigs for clones and Gus (MASTERPLAN §6.5).
--   * Avatar rig: a clone of the owner's stripped template (server-built, §6.5 #1),
--     tinted in the owner hue, anchored root moved with BulkMoveTo, walk clip on its
--     Animator; its joints (AnimationConstraints or Motor6Ds) carry the limbs. The owner
--     group's Highlight draws a crew-hue fill and outline. A template without its joints
--     never builds (mannequin instead); Rigs.health finds a rig that broke at runtime.
--   * Mannequin: a few rigid parts posed by hand; the placeholder until the owner's
--     template arrives (and the fallback when it cannot be built).
--   * Gus: a rigid-part rig with R15 proportions (no skinning), posed like the
--     mannequin, holding a torch in Torch Amber; a Santa hat (Ribbon Burgundy, Snow)
--     instead of his cap when the Christmas dressing layer is on.
--   * Copy: a local copy of a live character (the player in the Crew Line-up), its
--     look untouched.
-- Poses append to (parts, cframes) so each view does one BulkMoveTo per frame; the
-- Line-up adds a cheer pose (arms up on rigid rigs, the cheer clip on avatars).
-- Clones act (PLAN_STEAM_PLUS §4.4 A3): avatar rigs load the owner's catalog pack (idle, walk,
-- run, jump, fall: Rigs.loadPack / Rigs.locomote, speeds from Shared/Heist/CloneGait) and the custom
-- pose clips (Shared/Heist/ClonePose baked into Animation assets, Shared/Heist/CloneClips: Rigs.setPose
-- at Action priority), plus an IKControl for the plate glance (Rigs.lookAt). All of it goes through
-- the Animator, never Lua joint writes (engine finding 2026-11-12: Transform writes are not a
-- dependable path on the 2026 AnimationConstraint rigs, and the Animator path is the one the engine
-- tests can step). Mannequins take the same arm angles on their rigid limbs. Rigs.setPrint builds a rig
-- up from the feet (the tape print) by hiding parts above a height.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local RigJoints = require(Shared:WaitForChild("Heist"):WaitForChild("RigJoints"))
local CloneClips = require(Shared:WaitForChild("Heist"):WaitForChild("CloneClips"))

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
	joints: number?, -- avatar: whole joints when built (CloneHealth compares against it)
	scale: number?, -- avatar: rig size relative to a default R15 (CloneHealth limb distance)
	tracks: { [string]: AnimationTrack }?, -- catalog pack by slot (idle, walk, run, jump, fall)
	loco: string?, -- the locomotion clip set playing ("idle" | "move" | "jump" | "fall" | "none")
	poseTracks: { [string]: AnimationTrack }?, -- custom pose clips by name (carry, plate, stuck, busted)
	poseName: string?, -- the pose clip playing (nil = none)
	ik: IKControl?, -- head look-at (plate glance), built on first use
	lookTarget: Attachment?,
	heights: { number }?, -- per partsOf entry: rest height of the part's bottom above the feet
	printShown: number?, -- last print height written (setPrint)
	faces: { BasePart }?, -- Rookie: the four face pieces (EH_Face = mood), one shown (Rigs.setFace)
	face: string?, -- Rookie: the face shown
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
	local joints = RigJoints.whole(model)
	if not root or not root:IsA("BasePart") or joints < Config.Heist.CLONE_MIN_JOINTS then
		model:Destroy()
		return nil
	end
	-- A Rookie template (PLAN_FIRST_PERSON "CH": clones are copies of your Rookie) keeps its outfit colours: only
	-- the crew pieces (EH_Tint "crew": scarf, stripes) take the owner hue, and the hidden faces stay hidden.
	local rookie = model:GetAttribute("EH_Rookie") == true
	local tinted = {}
	local faces: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			if d:GetAttribute("EH_Face") ~= nil then
				table.insert(faces, d)
			elseif d:GetAttribute("EH_Hidden") ~= true then
				d.Transparency = 0
			end
			if not rookie or d:GetAttribute("EH_Tint") == "crew" then
				table.insert(tinted, d)
			end
		end
	end
	root.Anchored = true
	local hum = model:FindFirstChildOfClass("Humanoid")
	local rootHeight = root.Size.Y / 2 + (if hum then hum.HipHeight else 2)
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local head = model:FindFirstChild("Head")
	local rig: Rig = {
		model = model,
		kind = "avatar",
		root = root,
		rootHeight = rootHeight,
		animator = animator,
		track = nil,
		limbs = {},
		tinted = tinted,
		head = if head and head:IsA("BasePart") then head else nil,
		joints = joints,
		scale = math.max(1, rootHeight / 3),
		faces = if #faces > 0 then faces else nil,
	}
	-- Rest heights for the tape print, measured in the template's own pose (before any move).
	local feetY = root.Position.Y - rootHeight
	local heights = {}
	for i, p in Rigs.partsOf(rig) do
		heights[i] = p.Position.Y - p.Size.Y / 2 - feetY
	end
	rig.heights = heights
	return rig
end

-- CloneHealth (PLAN_STEAM_PLUS §1 S1): nil while an avatar rig is whole, else what broke:
-- "head" (gone), "limbs" (a part left the rig or drifted from its root), "joints" (a joint
-- lost an end). Rigid rigs (mannequin, Gus) are always whole.
function Rigs.health(rig: Rig): string?
	local root = rig.root
	if rig.kind ~= "avatar" or not root then
		return nil
	end
	local model = rig.model
	local head = rig.head
	if not head or not head:IsDescendantOf(model) then
		return "head"
	end
	if not root:IsDescendantOf(model) then
		return "limbs"
	end
	local maxD = Config.Heist.CLONE_HEALTH_MAX_LIMB * (rig.scale or 1)
	local rp = root.Position
	for _, p in Rigs.partsOf(rig) do
		if p ~= root and (not p:IsDescendantOf(model) or (p.Position - rp).Magnitude > maxD) then
			return "limbs"
		end
	end
	if RigJoints.whole(model) < (rig.joints or 0) then
		return "joints"
	end
	return nil
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

local MANNEQUIN_BY_NAME: { [string]: { any } } = {}
for _, spec in MANNEQUIN do
	MANNEQUIN_BY_NAME[spec[1]] = spec
end

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
	local rig: Rig = {
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
	local heights = {}
	for i, p in Rigs.partsOf(rig) do
		local spec = MANNEQUIN_BY_NAME[p.Name]
		heights[i] = if spec then spec[3].Y + spec[4].Y - spec[2].Y / 2 else 0
	end
	rig.heights = heights
	return rig
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
	rig.printShown = nil
	for _, p in Rigs.partsOf(rig) do
		p.LocalTransparencyModifier = alpha
	end
end

-- Tape print (PLAN_STEAM_PLUS §4.4 A2): shows the parts whose bottom is under `height` studs above
-- the feet and hides the rest, so the rig builds up from the feet as the height rises. Writes only
-- the parts that change; the next setFade takes over again.
function Rigs.setPrint(rig: Rig, height: number)
	local heights = rig.heights
	if not heights then
		Rigs.setFade(rig, if height > 0 then 0 else 1)
		return
	end
	local last = rig.printShown
	rig.fadeShown = nil
	rig.printShown = height
	for i, p in Rigs.partsOf(rig) do
		local h = heights[i] or 0
		local show = h <= height
		if last == nil or (h <= last) ~= show then
			p.LocalTransparencyModifier = if show then 0 else 1
		end
	end
end

-- The rig's height from the feet to the top of its tallest part (the print band's travel).
function Rigs.heightOf(rig: Rig): number
	local top = 0
	local heights = rig.heights
	for i, p in Rigs.partsOf(rig) do
		top = math.max(top, (if heights then heights[i] else 0) + p.Size.Y)
	end
	return if top > 0 then top else rig.rootHeight * 2
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

-- Mannequin limbs that take a custom pose's joint angles (ClonePose keys by R15 part name). Arms
-- only: the visor is its own part, so a turned head would leave it behind.
local MANNEQUIN_JOINT = { LeftArm = "LeftUpperArm", RightArm = "RightUpperArm" }

-- Appends this rig's parts and target CFrames for one BulkMoveTo call.
-- `feet` is the floor point under the rig facing its yaw; `phase` drives the limb swing.
-- `custom` (optional, ClonePose joints): rigid rigs pose their arms with it; avatar rigs
-- play it as an Animation clip instead (Rigs.setPose).
function Rigs.pose(
	rig: Rig,
	feet: CFrame,
	phase: number,
	amount: number,
	parts: { BasePart },
	cframes: { CFrame },
	custom: { [string]: { number } }?
)
	local root = rig.root
	if root then
		table.insert(parts, root)
		table.insert(cframes, feet * CFrame.new(0, rig.rootHeight, 0))
		return
	end
	local swing = math.sin(phase) * SWING * amount
	for _, limb in rig.limbs do
		table.insert(parts, limb.part)
		local key = if custom then MANNEQUIN_JOINT[limb.part.Name] else nil
		local a = if key and custom then custom[key] else nil
		if a then
			table.insert(cframes, feet * limb.pivot * CFrame.fromEulerAnglesYXZ(a[1], a[2], a[3]) * limb.offset)
		elseif limb.swing ~= 0 then
			table.insert(cframes, feet * limb.pivot * CFrame.Angles(swing * limb.swing, 0, 0) * limb.offset)
		else
			table.insert(cframes, feet * limb.pivot * limb.offset)
		end
	end
end

---------------------------------------------------------------------------
-- Clones act (A3): the catalog pack and custom poses on avatar rigs
---------------------------------------------------------------------------

local animCache: { [string]: Animation } = {}
local function animation(id: string): Animation
	local a = animCache[id]
	if not a then
		a = Instance.new("Animation")
		a.AnimationId = id
		animCache[id] = a
	end
	return a
end

-- The animation ids for a template: its EH_Anim_<slot> attributes (the owner's Animate pack, read
-- by the server strip), else the default R15 ids in Config.Clone.ANIM.
function Rigs.packOf(template: Instance?): { [string]: string }
	local C = Config.Clone
	local ids: { [string]: string } = {}
	for _, slot in C.ANIM_SLOTS do
		local v = if template then template:GetAttribute("EH_Anim_" .. slot) else nil
		ids[slot] = if type(v) == "string" and string.find(v, "%d") then v else C.ANIM[slot]
	end
	return ids
end

-- Loads the pack's tracks on the rig's Animator once (the rig must be in the DataModel). A slot
-- that does not load is skipped; with no Animator nothing loads and the rig just glides.
function Rigs.loadPack(rig: Rig, ids: { [string]: string })
	local animator = rig.animator
	if not animator or rig.tracks then
		return
	end
	local tracks: { [string]: AnimationTrack } = {}
	for slot, id in ids do
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation(id))
		end)
		if ok and track then
			track.Looped = slot ~= "jump"
			track.Priority = if slot == "idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
			tracks[slot] = track
		end
	end
	rig.tracks = tracks
	rig.loco = "none"
	local poses: { [string]: AnimationTrack } = {}
	for name, id in CloneClips do
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation(id))
		end)
		if ok and track then
			track.Looped = name ~= "busted"
			track.Priority = Enum.AnimationPriority.Action
			poses[name] = track
		end
	end
	rig.poseTracks = poses
end

local LOCO_SLOTS: { [string]: { string } } = {
	none = {},
	idle = { "idle" },
	move = { "walk", "run" },
	jump = { "jump" },
	fall = { "fall" },
}

-- Plays the clip set for `loco` ("idle" | "move" | "jump" | "fall" | "none"), cross-fading from the
-- last one. For "move": clip speed and walk/run weights (Shared/Heist/CloneGait), sent only when
-- `sendSpeed` / `sendWeights` say they changed; `phase` (0..1) starts fresh walk clips in step.
function Rigs.locomote(
	rig: Rig,
	loco: string,
	speed: number,
	walkW: number,
	runW: number,
	sendSpeed: boolean,
	sendWeights: boolean,
	phase: number?
)
	local tracks = rig.tracks
	if not tracks then
		return
	end
	local fade = Config.Clone.ANIM_FADE
	local started = false
	if loco ~= rig.loco then
		local want = LOCO_SLOTS[loco] or LOCO_SLOTS.none
		for _, slot in LOCO_SLOTS[rig.loco or "none"] or {} do
			local t = tracks[slot]
			if t and not table.find(want, slot) then
				t:Stop(fade)
			end
		end
		for _, slot in want do
			local t = tracks[slot]
			if t then
				local w = if slot == "walk" then walkW elseif slot == "run" then runW else 1
				t:Play(fade, math.max(w, 1e-3), if loco == "move" then speed else 1)
				if phase and loco == "move" and t.Length > 0 then
					t.TimePosition = phase * t.Length
				end
			end
		end
		rig.loco = loco
		started = true
	end
	if loco ~= "move" or started then
		return
	end
	local walk, run = tracks.walk, tracks.run
	if sendSpeed then
		if walk then
			walk:AdjustSpeed(speed)
		end
		if run then
			run:AdjustSpeed(speed)
		end
	end
	if sendWeights then
		if walk then
			walk:AdjustWeight(math.max(walkW, 1e-3), fade)
		end
		if run then
			run:AdjustWeight(math.max(runW, 1e-3), fade)
		end
	end
end

-- Custom poses (ClonePose baked into Animation clips by tools/clone_clips.luau, ids in
-- Shared/Heist/CloneClips): "carry", "plate", "stuck", "busted" at Action priority. They key only the
-- joints the pose sets, so the walk or idle clip keeps the rest of the body. Plays `name` (nil = none),
-- cross-fading from the last one; a no-op when nothing changes.
function Rigs.setPose(rig: Rig, name: string?)
	local tracks = rig.poseTracks
	if not tracks or name == rig.poseName then
		return
	end
	local C = Config.Clone
	local old = rig.poseName and tracks[rig.poseName]
	if old then
		old:Stop(C.POSE_BLEND)
	end
	local new = name and tracks[name]
	if new then
		new:Play(if name == "busted" then C.BUSTED_FADE_IN else C.POSE_BLEND)
	end
	rig.poseName = name
	-- the Rookie's face follows the pose: carry -> smug, busted -> busted, stuck -> shocked (Config.Rookie.POSE_FACE)
	Rigs.setFace(rig, name and Config.Rookie.POSE_FACE[name] or "idle")
end

-- Shows one of a Rookie rig's faces (idle, smug, shocked, busted); a no-op on other rigs or when unchanged.
function Rigs.setFace(rig: Rig, mood: string)
	local faces = rig.faces
	if not faces or rig.face == mood then
		return
	end
	rig.face = mood
	local shown = false
	for _, p in faces do
		local show = p:GetAttribute("EH_Face") == mood
		shown = shown or show
		p.Transparency = if show then 0 else 1
	end
	if not shown and mood ~= "idle" then
		rig.face = nil
		Rigs.setFace(rig, "idle")
	end
end

-- Seconds into the custom pose clip playing now (0 when none): the carried loot bobs with the arms.
function Rigs.poseTime(rig: Rig): number
	local tracks = rig.poseTracks
	local t = tracks and rig.poseName and tracks[rig.poseName]
	return if t then t.TimePosition else 0
end

-- Head look-at (roblox_quality §4.3): an IKControl (LookAt, Head from UpperTorso) toward `point` with
-- `weight` (0 = off; the weight fades, Enabled never toggles). Built on first use; the target is an
-- Attachment on Terrain that goes with the rig.
function Rigs.lookAt(rig: Rig, point: Vector3?, weight: number)
	local ik = rig.ik
	if not ik then
		if weight <= 0 or not point then
			return
		end
		local model = rig.model
		local hum = model:FindFirstChildOfClass("Humanoid")
		local head = model:FindFirstChild("Head")
		local torso = model:FindFirstChild("UpperTorso")
		if not hum or not head or not torso then
			return
		end
		local target = Instance.new("Attachment")
		target.Name = "EH_LookTarget"
		target.Parent = workspace.Terrain
		model.Destroying:Once(function()
			target:Destroy()
		end)
		local made = Instance.new("IKControl")
		made.Name = "EH_Look"
		made.Type = Enum.IKControlType.LookAt
		made.EndEffector = head
		made.ChainRoot = torso
		made.Target = target
		made.SmoothTime = Config.Clone.LOOK_SMOOTH
		made.Weight = 0
		made.Parent = hum
		rig.ik = made
		rig.lookTarget = target
		ik = made
	end
	local w = if point then math.clamp(weight, 0, 1) else 0
	if point and rig.lookTarget then
		rig.lookTarget.WorldPosition = point
	end
	if (ik :: IKControl).Weight ~= w then
		(ik :: IKControl).Weight = w
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
