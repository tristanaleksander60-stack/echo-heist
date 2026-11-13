--!strict
-- Heist/IntroKit: hands the client the story intro's meshes (docs/art/intro/STORYBOARD.md, Heist/Cinematic).
-- KitService keeps its templates in ServerStorage, which clients cannot see. Once the kit is loaded this copies
-- the intro groups (assets/blender/intro.py: Hoardsworth, the lever, the vacuum, the Snow Globe Vault, three
-- presents, the letter, two houses) and the launch-kit pieces the stage reuses (the van, street lamps, the tree)
-- into ReplicatedStorage/<Config.Intro.KIT_FOLDER>, like Heist/GusTemplate. The folder is filled before it is
-- parented, so a client never sees half a kit. Clients build the stage from it (stand-ins until it arrives).
-- Cosmetic only: nothing here decides anything; nothing is in Workspace.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local IntroKit = {}

IntroKit.MODELS = table.freeze({
	"Hoardsworth",
	"Intro_Lever",
	"Intro_Vacuum",
	"Intro_SnowGlobe",
	"Intro_Present_A",
	"Intro_Present_B",
	"Intro_Present_C",
	"Intro_Letter",
	"Intro_House_A",
	"Intro_House_B",
	"Van",
	"StreetLamp",
	"Xmas_Tree",
})

local started = false

function IntroKit.folder(): Folder?
	local f = ReplicatedStorage:FindFirstChild(Config.Intro.KIT_FOLDER)
	return if f and f:IsA("Folder") then f else nil
end

-- Copies the groups now (the kit must be loaded). Returns how many groups were published.
function IntroKit.publishNow(kit: any): number
	local existing = IntroKit.folder()
	if existing then
		return #existing:GetChildren()
	end
	if kit == nil or not kit.isReady() then
		return 0
	end
	local folder = Instance.new("Folder")
	folder.Name = Config.Intro.KIT_FOLDER
	local n = 0
	for _, name in IntroKit.MODELS do
		local model = kit.cloneModel(name)
		if model then
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanTouch = false
					d.CanQuery = false
				end
			end
			model.Name = name
			model.Parent = folder
			n += 1
		end
	end
	folder:SetAttribute("Groups", n)
	folder.Parent = ReplicatedStorage
	return n
end

-- Waits for the kit in the background, then publishes (idempotent).
function IntroKit.publish(kit: any)
	if started or kit == nil or not Config.Intro.ENABLED then
		return
	end
	started = true
	task.spawn(function()
		local ok, err = pcall(function()
			kit.ready()
			if IntroKit.publishNow(kit) == 0 then
				warn("[IntroKit] no intro models in the kit: the intro uses stand-ins")
			end
		end)
		if not ok then
			warn("[IntroKit] " .. tostring(err))
		end
	end)
end

return IntroKit
