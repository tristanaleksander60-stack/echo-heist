-- Stem alignment spike (S4), server side: only a floor and a spawn, so the
-- character has somewhere to stand. All audio runs on the client (music is
-- local to each client in the game as well).

local floor = Instance.new("Part")
floor.Name = "Floor"
floor.Anchored = true
floor.Size = Vector3.new(40, 1, 40)
floor.CFrame = CFrame.new(0, -0.5, 0)
floor.Color = Color3.fromRGB(58, 53, 96)
floor.Material = Enum.Material.SmoothPlastic
floor.TopSurface = Enum.SurfaceType.Smooth
floor.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Name = "StemsSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(6, 1, 6)
spawn.CFrame = CFrame.new(0, 0.01, 0)
spawn.Color = Color3.fromRGB(124, 134, 166)
spawn.Duration = 0
spawn.Parent = workspace
