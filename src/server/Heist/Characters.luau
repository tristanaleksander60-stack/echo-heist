--!strict
-- Heist/Characters: every player is a Rookie (PLAN_FIRST_PERSON "CH"); the Roblox avatar is never shown.
--
-- Approach (2026 engine; LihFolk vault "Custom Characters and StarterCharacter", "Character Select and Class
-- Systems with Different Rigs"): one R15-compatible StarterCharacter, set ONCE at boot, and the normal spawn path.
--   * The kit meshes cannot ride in the Rojo-built place file (MeshPart mesh data only arrives with the uploaded
--     asset), so the server builds the StarterCharacter at runtime from the art kit (Heist/Rookie) and puts it in
--     StarterPlayer before anyone spawns: Players.CharacterAutoLoads is off until then, and this service spawns
--     everyone (first spawn and respawns) with Player:LoadCharacterAsync.
--   * LoadCharacterAsync keeps everything the engine does on a normal spawn: the default R15 Animate (so walk,
--     emotes and our clips work; its walk, run, idle, jump and fall ids become the Rookie's own clips on spawn,
--     Shared/Heist/RookieAnimate), Health, camera subject, network ownership. A manual `player.Character = model`
--     would lose the Animate insertion (vault: "belongs to the normal spawn path").
--   * StarterPlayer.LoadCharacterAppearance is off, so no avatar accessory, clothing or body colour is put on it.
--   * The StarterCharacter is never swapped per player (the vault warns runtime swaps cause odd spawn bugs): each
--     character is dressed on CharacterAdded (synchronously, before it replicates further) in the player's outfit
--     (the player attribute "Outfit" DataService publishes) and crew colour (Palette seat hue; HeistService calls
--     Characters.setSeat), and re-dressed live when either changes.
-- A character that is not a Rookie (an avatar that loaded before this service started) is respawned as one.
-- If the kit never loads, the StarterCharacter is the block Rookie (same rig and joints, no meshes).
-- Faces: Characters.flashFace(userId, mood) shows a face for Config.Rookie.FACE_SECONDS (banked, zapped, busted).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local Outfit = require(HeistShared:WaitForChild("Outfit"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Rookie = require(script.Parent:WaitForChild("Rookie"))
local RookieAnimate = require(HeistShared:WaitForChild("RookieAnimate"))

local R = Config.Rookie

local Characters = {}

local started = false
local starterState: "idle" | "waiting" | "ready" = "idle"
local seatOf: { [Player]: number } = {}
local faceToken: { [Player]: number } = {}
local spawning: { [Player]: boolean } = {}
local onOutfitChanged: ((Player) -> ())? = nil

-- The outfit a player wears: the attribute DataService publishes (defaults while there is no profile).
function Characters.outfitOf(player: Player): Outfit.Outfit
	return Outfit.fromKey(player:GetAttribute("Outfit"))
end

function Characters.hueOf(player: Player): Color3
	return Palette.hueFor(seatOf[player] or 1)
end

-- Dresses a Rookie character model in an outfit and a seat's hue (also what the engine test calls on its fake
-- player's character). Returns false when the model is not a Rookie.
function Characters.dressModel(char: Model, outfit: Outfit.Outfit, seat: number): boolean
	if char:GetAttribute("EH_Rookie") ~= true then
		return false
	end
	Rookie.apply(char, outfit, Palette.hueFor(seat))
	return true
end

function Characters.dress(player: Player)
	local char = player.Character
	if char then
		Characters.dressModel(char, Characters.outfitOf(player), seatOf[player] or 1)
	end
end

-- The StarterCharacter: the kit Rookie (or the block Rookie if the kit is not there in KIT_WAIT_SECONDS).
local function makeStarter()
	Rookie.waitForKit(R.KIT_WAIT_SECONDS)
	local model = Rookie.build()
	model.Name = "StarterCharacter"
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	model.Parent = StarterPlayer
	if model:GetAttribute("EH_Blocks") then
		warn("[Characters] the Rookie kit is not loaded: players spawn as block Rookies")
	end
end

-- Yields until the StarterCharacter is a Rookie (builds it on the first call).
function Characters.ensureStarter()
	if starterState == "ready" then
		return
	end
	if starterState == "idle" then
		starterState = "waiting"
		local ok, err = pcall(makeStarter)
		if not ok then
			warn("[Characters] StarterCharacter: " .. tostring(err))
		end
		starterState = "ready"
		return
	end
	while starterState ~= "ready" do
		task.wait(0.1)
	end
end

function Characters.starter(): Model?
	local s = StarterPlayer:FindFirstChild("StarterCharacter")
	return if s and s:IsA("Model") then s else nil
end

-- Spawns (or respawns) a player as a Rookie.
function Characters.spawn(player: Player)
	if spawning[player] then
		return
	end
	spawning[player] = true
	Characters.ensureStarter()
	for attempt = 1, R.SPAWN_RETRIES do
		if player.Parent ~= Players then
			break
		end
		local ok, err = pcall(function()
			(player :: any):LoadCharacterAsync()
		end)
		if ok then
			break
		end
		warn("[Characters] spawn " .. player.Name .. " (try " .. attempt .. "): " .. tostring(err))
		task.wait(1)
	end
	spawning[player] = nil
end

local function onCharacter(player: Player, char: Model)
	if char:GetAttribute("EH_Rookie") ~= true then
		-- an avatar that loaded before this service took over: respawn as a Rookie once the StarterCharacter is one
		task.spawn(function()
			Characters.ensureStarter()
			local starter = Characters.starter()
			if starter and starter:GetAttribute("EH_Rookie") == true and player.Character == char then
				Characters.spawn(player)
			end
		end)
		return
	end
	Characters.dress(player)
	-- the Rookie's own walk, run, idle, jump and fall in the engine's Animate (REVIEW_STEAM_PLUS #6)
	task.spawn(function()
		local animate = RookieAnimate.find(char, Config.Rookie.ANIM.ANIMATE_WAIT)
		if animate and char.Parent then
			RookieAnimate.apply(animate)
		end
	end)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Once(function()
			task.wait(R.RESPAWN_SECONDS)
			if player.Parent == Players and player.Character == char then
				Characters.spawn(player)
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(char: Model)
		onCharacter(player, char)
	end)
	player:GetAttributeChangedSignal("Outfit"):Connect(function()
		Characters.dress(player)
		local fn = onOutfitChanged
		if fn then
			fn(player)
		end
	end)
	local char = player.Character
	if char then
		onCharacter(player, char)
	else
		task.spawn(Characters.spawn, player)
	end
end

-- The crew seat decides the crew colour (scarf, stripes); HeistService calls this whenever seats change.
function Characters.setSeat(player: Player, seat: number)
	if seatOf[player] == seat then
		return
	end
	seatOf[player] = seat
	player:SetAttribute("Seat", seat)
	Characters.dress(player)
end

-- Shows a face on a player's character for Config.Rookie.FACE_SECONDS[mood], then the idle face again.
function Characters.flashFace(userId: number, mood: string)
	local player = Players:GetPlayerByUserId(userId)
	local char = player and player.Character
	if not player or not char or char:GetAttribute("EH_Rookie") ~= true then
		return
	end
	local token = (faceToken[player] or 0) + 1
	faceToken[player] = token
	Rookie.setFace(char, mood)
	task.delay(R.FACE_SECONDS[mood] or 2, function()
		if faceToken[player] == token and player.Character == char then
			Rookie.setFace(char, "idle")
		end
	end)
end

-- Starts the service (idempotent). onOutfit(player) runs after a player's outfit changed (clone templates).
function Characters.start(onOutfit: ((Player) -> ())?)
	onOutfitChanged = onOutfit
	if started then
		return
	end
	started = true
	Players.CharacterAutoLoads = false
	StarterPlayer.LoadCharacterAppearance = false
	task.spawn(Characters.ensureStarter)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		seatOf[player] = nil
		faceToken[player] = nil
		spawning[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return Characters
