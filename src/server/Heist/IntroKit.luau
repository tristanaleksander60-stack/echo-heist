--!strict
-- Heist/IntroKit: hands the client the story intro's meshes (docs/art/intro/STORYBOARD.md, Heist/Cinematic).
-- KitService keeps its templates in ServerStorage, which clients cannot see. Once the kit is loaded this copies
-- the intro groups (assets/blender/intro.py: Hoardsworth, the lever, the vacuum, the Snow Globe Vault, the tower, three
-- presents, the letter, two houses) and the launch-kit pieces the stage reuses (the van, street lamps, the tree)
-- into ReplicatedStorage/<Config.Intro.KIT_FOLDER>, like Heist/GusTemplate. The folder is filled before it is
-- parented, so a client never sees half a kit. It is published as soon as the kit's intro phase is ready
-- (KitService.introReady: Config.Kit.INTRO_GROUPS load right after the Rookie, before the rest of the kit), so a new
-- player's intro has its meshes; the client never plays it on stand-ins (Heist/Cinematic.waitForKit).
-- ReplicatedStorage, never Workspace: instance streaming never holds it back or streams it out.
-- Cosmetic only: nothing here decides anything.
--   IntroKit.publish(kit)          at boot (background)
--   IntroKit.publishNow(kit) -> n  now (the intro phase must be ready); the groups published
--   IntroKit.timing() -> { published: boolean, sinceKitStart: number?, serverTime: number? }   when it was published:
--                                  seconds after KitService.start (the server's boot) and the server's time()

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local IntroKit = {}

-- The groups (one list with the kit's intro phase: Config.Kit.INTRO_GROUPS).
IntroKit.MODELS = table.freeze(table.clone(Config.Kit.INTRO_GROUPS)) :: { string }

local started = false
local timing: { published: boolean, sinceKitStart: number?, serverTime: number? } = { published = false }

local function ready(kit: any): boolean
	return kit.isReady() or (kit.isIntroReady ~= nil and kit.isIntroReady())
end

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
	if kit == nil or not ready(kit) then
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
	folder:SetAttribute("Expected", #IntroKit.MODELS)
	folder.Parent = ReplicatedStorage
	local t0 = if kit.startedAt then kit.startedAt() else nil
	timing = {
		published = true,
		sinceKitStart = if t0 then os.clock() - t0 else nil,
		serverTime = time(),
	}
	return n
end

function IntroKit.timing(): { published: boolean, sinceKitStart: number?, serverTime: number? }
	return table.clone(timing)
end

-- Waits for the kit in the background, then publishes (idempotent).
function IntroKit.publish(kit: any)
	if started or kit == nil or not Config.Intro.ENABLED then
		return
	end
	started = true
	task.spawn(function()
		local ok, err = pcall(function()
			if kit.introReady then
				kit.introReady() -- the intro's groups load right after the Rookie (Config.Kit.INTRO_GROUPS)
			else
				kit.ready()
			end
			local n = IntroKit.publishNow(kit)
			if n == 0 then
				warn("[IntroKit] no intro models in the kit: new players get the title card, not the intro")
			else
				print(
					string.format(
						"[IntroKit] %d/%d groups published %.2f s after the kit started (server time %.1f s)",
						n,
						#IntroKit.MODELS,
						timing.sinceKitStart or -1,
						timing.serverTime or -1
					)
				)
			end
		end)
		if not ok then
			warn("[IntroKit] " .. tostring(err))
		end
	end)
end

return IntroKit
