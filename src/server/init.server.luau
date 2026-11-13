-- Echo Heist server entry point. All logic lives in modules (so tests can boot them too).
-- The data layer starts first and never blocks the game: if it fails to start, the
-- heist still runs (it only stops saving), because solo must always be playable.
-- Analytics (and LiveFlags with it) starts next, also in a pcall: measuring never
-- breaks play. Config.GAME_MODE picks the game: "v01" (default, the v0.1 prototype) or
-- "sim" (the HeistSim path in Heist/; it supplies the medal rules before data starts,
-- loads the art kit in the background and dresses levels with it once it is ready).
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Data = script:WaitForChild("Data")

local function startAnalytics(dataService: any, heistService: any)
	-- LiveFlags first and on its own: kill switches must work even if analytics cannot start.
	local okFlags, flagsErr = pcall(function()
		require(script:WaitForChild("Analytics"):WaitForChild("LiveFlags")).start()
	end)
	if not okFlags then
		warn("[Server] LiveFlags failed to start; defaults apply: " .. tostring(flagsErr))
	end
	local ok, err = pcall(function()
		local Analytics = require(script:WaitForChild("Analytics"):WaitForChild("Analytics"))
		Analytics.start({
			dataService = dataService, -- Loaded -> cohort, ftueStep, first-seen day
			playerData = require(Data:WaitForChild("PlayerData")), -- read-only Meta.Created
			currency = require(Data:WaitForChild("Currency")), -- Currency.Changed -> economy events
			receipts = require(Data:WaitForChild("Receipts")), -- Receipts.Granted -> store_v1 PurchaseGranted
			shop = require(Data:WaitForChild("Shop")), -- Shop.ProductPrompted -> PromptShown (once it exists)
			heistService = heistService, -- sim path: HeistService.FtueStep -> onb_v2
		})
		if heistService then
			heistService.configureAnalytics(Analytics)
		end
	end)
	if not ok then
		warn("[Server] analytics failed to start: " .. tostring(err))
	end
end

if Config.GAME_MODE == "sim" then
	-- Clones never collide with anything (players walk through their clones): one collision group, client rigs
	-- join it through Heist/Rigs.ghost.
	pcall(function()
		local PhysicsService = game:GetService("PhysicsService")
		local group = Config.Heist.CLONE_COLLISION_GROUP
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
		PhysicsService:CollisionGroupSetCollidable(group, "Default", false)
		PhysicsService:CollisionGroupSetCollidable(group, group, false)
	end)
	-- Every player is a Rookie (Heist/Characters): no avatar spawns before the Rookie StarterCharacter exists.
	game:GetService("Players").CharacterAutoLoads = false
	local HeistService = require(script:WaitForChild("Heist"):WaitForChild("HeistService"))
	local DataService = nil
	local okSimData, simDataErr = pcall(function()
		DataService = require(Data:WaitForChild("DataService"))
		HeistService.configureData(DataService)
		DataService.start()
	end)
	if not okSimData then
		warn("[Server] data layer failed to start; progress is not saved: " .. tostring(simDataErr))
	end
	startAnalytics(DataService, HeistService)
	-- Roblox badges (Data/Awards): server-decided facts only, never in the way of play.
	local okBadges, badgesErr = pcall(function()
		local Awards = require(Data:WaitForChild("Awards"))
		Awards.start({ data = DataService })
		HeistService.configureAwards(Awards)
	end)
	if not okBadges then
		warn("[Server] badges unavailable: " .. tostring(badgesErr))
	end
	local okKit, kitErr = pcall(function()
		local KitService = require(script:WaitForChild("Kit"):WaitForChild("KitService"))
		HeistService.configureKit(KitService)
		if Config.Heist.KIT_LEVELS then
			KitService.start() -- background load (~2.5 s); levels stay greybox until it is ready
			-- the skyline ring meshes for the client backdrop (W4), once the kit is loaded
			require(script:WaitForChild("Heist"):WaitForChild("BackdropKit")).start(KitService)
			-- Gus's mesh for the client rig (box Gus until it arrives)
			require(script:WaitForChild("Heist"):WaitForChild("GusTemplate")).publish(KitService)
			-- the Rookie (player character, clone templates, first-person arms): ReplicatedStorage.CharacterKit
			require(script:WaitForChild("Heist"):WaitForChild("Rookie")).publish(KitService)
			-- the story intro's meshes for the client stage (stand-ins until they arrive)
			require(script:WaitForChild("Heist"):WaitForChild("IntroKit")).publish(KitService)
		end
	end)
	if not okKit then
		warn("[Server] art kit unavailable; levels stay greybox: " .. tostring(kitErr))
	end
	-- UI kit images (Decal -> image id): cosmetic, the HUD renders without them until they arrive.
	pcall(function()
		require(script:WaitForChild("Heist"):WaitForChild("UiImages")).start()
	end)
	HeistService.start()
	return
end

local DataService = nil
local okData, dataErr = pcall(function()
	DataService = require(Data:WaitForChild("DataService"))
	DataService.start()
end)
if not okData then
	warn("[Server] data layer failed to start; progress is not saved: " .. tostring(dataErr))
end
startAnalytics(DataService, nil)
require(script:WaitForChild("Main")).start()
