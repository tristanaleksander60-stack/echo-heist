--!strict
-- Heist/Lobby: the garage lobby greybox (MASTERPLAN §3.3, §6.6): a shared room where
-- every crew's van is parked and new players spawn. Level select and crews are UI
-- (src/client/Heist/Hud); heist instances are built far away along +X.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local Lobby = {}

local built: Model? = nil
local spawnCFrame = CFrame.new()

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function Lobby.build(): Model
	if built then
		return built
	end
	local o = Config.Heist.LOBBY_ORIGIN
	local origin = Vector3.new(o[1], o[2], o[3])
	local model = Instance.new("Model")
	model.Name = "Garage"
	block(model, "Floor", Vector3.new(120, 2, 80), CFrame.new(origin + Vector3.new(0, -1, 0)), Palette.inkHi)
	block(model, "BackWall", Vector3.new(120, 16, 1), CFrame.new(origin + Vector3.new(0, 8, -40)), Palette.plum)
	block(model, "LeftWall", Vector3.new(1, 16, 80), CFrame.new(origin + Vector3.new(-60, 8, 0)), Palette.plum)
	block(model, "RightWall", Vector3.new(1, 16, 80), CFrame.new(origin + Vector3.new(60, 8, 0)), Palette.plum)
	block(model, "FrontWall", Vector3.new(120, 16, 1), CFrame.new(origin + Vector3.new(0, 8, 40)), Palette.plum)
	-- Parked vans (one bay per crew), each with a tape shelf behind it.
	for i = 1, 4 do
		local x = -45 + (i - 1) * 30
		block(model, "Van", Vector3.new(9, 7, 14), CFrame.new(origin + Vector3.new(x, 3.5, -28)), Palette.exit)
		block(model, "Shelf", Vector3.new(10, 0.6, 2), CFrame.new(origin + Vector3.new(x, 5, -38.5)), Palette.steel)
		local stripe = block(
			model,
			"Bay",
			Vector3.new(11, 0.05, 18),
			CFrame.new(origin + Vector3.new(x, 0.03, -27)),
			Palette.steelLo
		)
		stripe.CanCollide = false
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GarageSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(origin + Vector3.new(0, 0.5, 10))
	spawn.Color = Palette.steel
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = model
	spawnCFrame = CFrame.new(origin + Vector3.new(0, 4, 10)) * CFrame.Angles(0, 0, 0)
	model.Parent = workspace
	built = model
	return model
end

-- Where a player is put back when they return to the garage (spread around the spawn).
function Lobby.spawnFor(i: number): CFrame
	local col = (i - 1) % 4
	local row = math.floor((i - 1) / 4)
	return spawnCFrame * CFrame.new((col - 1.5) * 3, 0, row * 3)
end

return Lobby
