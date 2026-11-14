--!strict
-- Heist/GusTemplate: gives clients the art kit's Gus (PLAN_STEAM_PLUS §4.4 A4, POLISH §4.3).
-- KitService keeps its templates in ServerStorage, which clients cannot see. Once the kit is loaded
-- this copies the Gus groups (the 18-part rig, the Santa hat, the donut box) into
-- ReplicatedStorage/<Config.Gus.TEMPLATE_FOLDER>, like the stripped avatar templates (Heist/Avatars).
-- The folder is filled before it is parented, so a client never sees half a rig. Clients clone it in
-- Heist/GusRig and keep the box rig until it arrives (or for good if the kit never loads).
-- Cosmetic only: nothing here decides anything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any

local GusTemplate = {}

GusTemplate.MODELS = table.freeze({ "Gus", "Gus_SantaHat", "Gus_DonutBox" })

local started = false

-- The published folder, or nil.
function GusTemplate.folder(): Folder?
	local f = ReplicatedStorage:FindFirstChild(Config.Gus.TEMPLATE_FOLDER)
	return if f and f:IsA("Folder") then f else nil
end

-- Copies the groups now (the kit must be loaded). True when Gus is published.
function GusTemplate.publishNow(kit: any): boolean
	if GusTemplate.folder() ~= nil then
		return true
	end
	if kit == nil or not kit.isReady() then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.Gus.TEMPLATE_FOLDER
	for _, name in GusTemplate.MODELS do
		local model = kit.cloneModel(name)
		if model then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("EH_OutlineOf") == nil then -- hulls ride their piece's Weld
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				end
			end
			model.Name = name
			model.Parent = folder
		end
	end
	if folder:FindFirstChild("Gus") == nil then
		folder:Destroy()
		return false
	end
	folder.Parent = ReplicatedStorage
	return true
end

-- Waits for the kit in the background, then publishes (idempotent).
function GusTemplate.publish(kit: any)
	if started or kit == nil then
		return
	end
	started = true
	task.spawn(function()
		local ok, err = pcall(function()
			kit.ready()
			if not GusTemplate.publishNow(kit) then
				warn("[GusTemplate] the kit has no Gus model: clients keep the box Gus")
			end
		end)
		if not ok then
			warn("[GusTemplate] " .. tostring(err))
		end
	end)
end

return GusTemplate
