--!strict
-- Heist/Avatars: one stripped clone template per owner (MASTERPLAN §6.5 #1-2).
-- The server builds it from the player's avatar with
-- Players:CreateHumanoidModelFromDescriptionAsync and puts it in
-- ReplicatedStorage.HeistAvatars/<userId>; clients clone and pool it (a mannequin
-- stands in until it arrives). Stripped silhouette: no SurfaceAppearance, textures,
-- decals, face or layered clothing, at most MAX_CLONE_ACCESSORIES hair/hat pieces,
-- SmoothPlastic, no shadows, no collisions, no scripts; the client tints it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))

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

-- Strips a rig in place (also used by the engine smoke test on a default rig).
function Avatars.strip(rig: Model)
	local kept = 0
	for _, child in rig:GetChildren() do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			local layered = handle ~= nil and handle:FindFirstChildOfClass("WrapLayer") ~= nil
			if layered or not KEEP_ACCESSORY[child.AccessoryType] or kept >= Config.Heist.MAX_CLONE_ACCESSORIES then
				child:Destroy()
			else
				kept += 1
			end
		elseif
			child:IsA("Shirt")
			or child:IsA("Pants")
			or child:IsA("ShirtGraphic")
			or child:IsA("BodyColors")
			or child:IsA("Script")
			or child:IsA("LocalScript")
		then
			child:Destroy()
		end
	end
	for _, d in rig:GetDescendants() do
		if
			d:IsA("SurfaceAppearance")
			or d:IsA("Decal")
			or d:IsA("Texture")
			or d:IsA("WrapLayer")
			or d:IsA("Script")
			or d:IsA("LocalScript")
		then
			d:Destroy()
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.CastShadow = false
			d.Material = Enum.Material.SmoothPlastic
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		end
	end
	-- Instances that never render on a posed clone (every rig copies them: 12 active, the
	-- pool, up to 16 Line-up figures): body-scale and OriginalSize values, the
	-- HumanoidDescription, and rig attachments no kept accessory hangs from. Motor6Ds stay.
	local used: { [string]: boolean } = {}
	for _, child in rig:GetChildren() do
		if child:IsA("Accessory") then
			for _, a in child:GetDescendants() do
				if a:IsA("Attachment") then
					used[a.Name] = true
				end
			end
		end
	end
	for _, d in rig:GetDescendants() do
		local unusedAttachment = d:IsA("Attachment")
			and not used[d.Name]
			and d:FindFirstAncestorOfClass("Accessory") == nil
		if d:IsA("ValueBase") or d:IsA("HumanoidDescription") or unusedAttachment then
			d:Destroy()
		end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.EvaluateStateMachine = false
		hum.BreakJointsOnDeath = false
		if not hum:FindFirstChildOfClass("Animator") then
			local animator = Instance.new("Animator")
			animator.Parent = hum
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
	Avatars.strip(rig)
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
