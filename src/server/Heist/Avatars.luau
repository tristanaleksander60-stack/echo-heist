--!strict
-- Heist/Avatars: one stripped clone template per owner (MASTERPLAN §6.5 #1-2).
-- Clones are copies of YOUR Rookie (PLAN_FIRST_PERSON "CH"): the server builds the template from the Rookie
-- (Heist/Rookie) in the owner's outfit (the player attribute "Outfit") and puts it in
-- ReplicatedStorage.HeistAvatars/<userId>; clients clone and pool it (a mannequin stands in until it arrives).
-- An outfit change rebuilds it (Heist/Characters calls prepare again; the attribute EH_Outfit is the outfit key).
-- Strip: SmoothPlastic, no shadows, no collisions, no scripts, anchored invisible root; the joints, their
-- attachments, the rig attachments and the four faces (one shown) stay. The client tints only the crew pieces
-- (EH_Tint "crew": scarf, stripes) in the owner hue. The owner's animation pack stays as EH_Anim_<slot>
-- attributes (clones walk like their owner). Avatars.strip still handles any avatar rig (tests use real ones).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local RigJoints = require(Shared:WaitForChild("Heist"):WaitForChild("RigJoints"))
local Outfit = require(Shared:WaitForChild("Heist"):WaitForChild("Outfit"))
local Rookie = require(script.Parent:WaitForChild("Rookie"))

local Avatars = {}

local folder: Folder? = nil
local building: { [number]: boolean } = {}
local again: { [number]: boolean } = {} -- the outfit changed while its template was building

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

-- Builds an owner's clone template from the Rookie in an outfit (no player needed: the engine tests use it).
-- Returns the filed template, or nil when the rig would not hold together (the client keeps the mannequin).
function Avatars.buildRookie(ownerId: number, outfit: Outfit.Outfit, character: Model?): Model?
	local rig = Rookie.build(outfit)
	if character then
		Avatars.readPack(character, rig) -- the live character's Animate holds the pack the player really walks with
	end
	Avatars.strip(rig)
	local joints = RigJoints.whole(rig)
	if joints < Config.Heist.CLONE_MIN_JOINTS then
		warn("[Avatars] clone template for " .. tostring(ownerId) .. " has " .. joints .. " joints: mannequin")
		rig:Destroy()
		return nil
	end
	rig.Name = tostring(ownerId)
	local old = getFolder():FindFirstChild(rig.Name)
	if old then
		old:Destroy()
	end
	rig.Parent = getFolder()
	return rig
end

-- Builds (or rebuilds, when the outfit changed) the template for a player (yields; call in its own thread).
function Avatars.prepare(player: Player)
	local userId = player.UserId
	local key = Outfit.key(Outfit.fromKey(player:GetAttribute("Outfit")))
	local existing = getFolder():FindFirstChild(tostring(userId))
	if existing and existing:GetAttribute("EH_Outfit") == key then
		return
	end
	if building[userId] then
		again[userId] = true
		return
	end
	building[userId] = true
	Rookie.waitForKit(Config.Rookie.KIT_WAIT_SECONDS)
	building[userId] = nil
	if player.Parent ~= Players then
		again[userId] = nil
		return -- left while the kit was loading
	end
	local ok, err = pcall(Avatars.buildRookie, userId, Outfit.fromKey(player:GetAttribute("Outfit")), player.Character)
	if not ok then
		warn("[Avatars] no clone template for " .. tostring(userId) .. ": " .. tostring(err))
	end
	if again[userId] then
		again[userId] = nil
		Avatars.prepare(player)
	end
end

function Avatars.release(player: Player)
	again[player.UserId] = nil
	local t = getFolder():FindFirstChild(tostring(player.UserId))
	if t then
		t:Destroy()
	end
end

function Avatars.folder(): Folder
	return getFolder()
end

return Avatars
