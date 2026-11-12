--!strict
-- Heist/Avatars: one stripped clone template per owner (MASTERPLAN §6.5 #1-2).
-- The server builds it from the player's avatar with
-- Players:CreateHumanoidModelFromDescriptionAsync and puts it in
-- ReplicatedStorage.HeistAvatars/<userId>; clients clone and pool it (a mannequin
-- stands in until it arrives). Stripped silhouette: no SurfaceAppearance, textures,
-- decals, face or layered clothing, at most MAX_CLONE_ACCESSORIES hair/hat pieces,
-- SmoothPlastic, no shadows, no collisions, no scripts; the client tints it. The owner's
-- animation pack stays as EH_Anim_<slot> attributes (clones walk like their owner).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local RigJoints = require(Shared:WaitForChild("Heist"):WaitForChild("RigJoints"))

local Avatars = {}

local folder: Folder? = nil
local building: { [number]: boolean } = {}

local KEEP_ACCESSORY = {
	[Enum.AccessoryType.Hair] = true,
	[Enum.AccessoryType.Hat] = true,
}

local function getFolder(): Folder
	local f = folder
	if f then
		return f
	end
	local existing = ReplicatedStorage:FindFirstChild(Protocol.AVATARS)
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local nf = Instance.new("Folder")
	nf.Name = Protocol.AVATARS
	nf.Parent = ReplicatedStorage
	folder = nf
	return nf
end

-- The owner's catalog animation pack (PLAN_STEAM_PLUS §4.4 A3): the Animate script's slots
-- (walk, run, idle, jump, fall; its first Animation each) as template attributes EH_Anim_<slot>,
-- so clones play the owner's own walk. Keeps attributes already set (a live character's pack wins).
function Avatars.readPack(from: Instance, into: Instance)
	local animate = from:FindFirstChild("Animate")
	if not animate then
		return
	end
	for _, slot in Config.Clone.ANIM_SLOTS do
		local holder = animate:FindFirstChild(slot)
		local anim = holder and holder:FindFirstChildWhichIsA("Animation")
		if anim and anim.AnimationId ~= "" and into:GetAttribute("EH_Anim_" .. slot) == nil then
			into:SetAttribute("EH_Anim_" .. slot, anim.AnimationId)
		end
	end
end

-- Strips a rig in place (also used by the engine tests on real rigs).
-- Safe strip only (PLAN_STEAM_PLUS §1 S1): the joints, every attachment a joint uses, the rig
-- attachments and the scale values all stay, and the Humanoid never rescales or rebuilds the
-- rig in a client's workspace (AutomaticScalingEnabled off). Stripping the rig attachments is
-- what made every v23 clone fall apart: the joints lost their ends, only the invisible
-- anchored root moved. Removed: scripts, layered clothing (and the cages it needs), ragdoll
-- sockets and no-collision pairs (physics work a posed, non-colliding clone never needs), the
-- HumanoidDescription, attachments nothing hangs from, and the looks Config turns off.
function Avatars.strip(rig: Model)
	local H = Config.Heist
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutomaticScalingEnabled = false
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
		hum.EvaluateStateMachine = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		if not hum:FindFirstChildOfClass("Animator") then
			local animator = Instance.new("Animator")
			animator.Parent = hum
		end
	end
	Avatars.readPack(rig, rig) -- before the scripts go
	local kept = 0
	for _, child in rig:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			local layered = handle ~= nil and handle:FindFirstChildOfClass("WrapLayer") ~= nil
			if layered or not KEEP_ACCESSORY[child.AccessoryType] or kept >= H.MAX_CLONE_ACCESSORIES then
				child:Destroy()
			else
				kept += 1
			end
		elseif child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			if not H.CLONE_KEEP_CLOTHING then
				child:Destroy()
			end
		elseif child:IsA("BodyColors") or child:IsA("BaseScript") then
			child:Destroy() -- the client tints the body in the crew hue
		end
	end
	for _, d in rig:GetDescendants() do
		if
			d:IsA("BaseScript")
			or d:IsA("WrapLayer")
			or d:IsA("WrapTarget")
			or d:IsA("NoCollisionConstraint")
			or d:IsA("BallSocketConstraint")
			or d:IsA("HumanoidDescription")
			or (d:IsA("SurfaceAppearance") and not H.CLONE_KEEP_SURFACE_APPEARANCE)
			or ((d:IsA("Decal") or d:IsA("Texture")) and not H.CLONE_KEEP_TEXTURES)
		then
			d:Destroy()
		elseif d:IsA("SpecialMesh") then
			if not H.CLONE_KEEP_TEXTURES then
				d.TextureId = ""
			end
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.CastShadow = false
			d.Material = Enum.Material.SmoothPlastic
			if d:IsA("MeshPart") and not H.CLONE_KEEP_TEXTURES then
				d.TextureID = ""
			end
		end
	end
	-- Attachments: keep every one a remaining joint or constraint uses, every rig attachment
	-- (by name) and the ones a kept accessory hangs from; drop the rest (with their
	-- OriginalPosition values). Scale values (BodyHeightScale..., OriginalSize) stay.
	local keep: { [Instance]: boolean } = {}
	local usedName: { [string]: boolean } = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Constraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			if a0 then
				keep[a0] = true
			end
			if a1 then
				keep[a1] = true
			end
		elseif d:IsA("Attachment") and d:FindFirstAncestorOfClass("Accessory") ~= nil then
			usedName[d.Name] = true
		end
	end
	for _, d in rig:GetDescendants() do
		if
			d:IsA("Attachment")
			and not keep[d]
			and not usedName[d.Name]
			and not string.find(d.Name, "RigAttachment", 1, true)
			and d.Name ~= "RootAttachment"
			and d:FindFirstAncestorOfClass("Accessory") == nil
		then
			d:Destroy()
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.Transparency = 1
	end
end

-- Builds the template for a player once (yields; call in its own thread).
function Avatars.prepare(player: Player)
	local userId = player.UserId
	if building[userId] or getFolder():FindFirstChild(tostring(userId)) then
		return
	end
	building[userId] = true
	local okDesc, desc = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(math.max(userId, 1))
	end)
	local description: HumanoidDescription = if okDesc and desc then desc else Instance.new("HumanoidDescription")
	local okRig, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	building[userId] = nil
	if not okRig or not rig then
		warn("[Avatars] no clone template for " .. tostring(userId) .. ": " .. tostring(rig))
		return
	end
	if player.Parent ~= Players then
		rig:Destroy() -- left while the avatar was loading
		return
	end
	-- The live character's Animate holds the pack the player really walks with.
	local character = player.Character
	if character then
		Avatars.readPack(character, rig)
	end
	Avatars.strip(rig)
	local joints = RigJoints.whole(rig)
	if joints < Config.Heist.CLONE_MIN_JOINTS then
		-- a rig that cannot hold together never ships: the client keeps the mannequin
		warn("[Avatars] clone template for " .. tostring(userId) .. " has " .. joints .. " joints: mannequin")
		rig:Destroy()
		return
	end
	rig.Name = tostring(userId)
	rig.Parent = getFolder()
end

function Avatars.release(player: Player)
	local t = getFolder():FindFirstChild(tostring(player.UserId))
	if t then
		t:Destroy()
	end
end

function Avatars.folder(): Folder
	return getFolder()
end

return Avatars
