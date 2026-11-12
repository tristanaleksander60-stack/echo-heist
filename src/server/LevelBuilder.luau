-- Builds the greybox "First National Bank" level from code, so the prototype
-- needs no hand-built map. Replace with an art pass later; keep the returned
-- table shape so the other services keep working.

local LevelBuilder = {}

local FLOOR_Y = 0
local WALL_H = 14

local COLORS = {
	floor = Color3.fromRGB(58, 62, 74),
	street = Color3.fromRGB(40, 42, 48),
	wall = Color3.fromRGB(196, 186, 168),
	vaultWall = Color3.fromRGB(120, 124, 132),
	door = Color3.fromRGB(150, 155, 165),
	plateA = Color3.fromRGB(60, 140, 255),
	plateB = Color3.fromRGB(255, 70, 70),
	laser = Color3.fromRGB(255, 30, 30),
	van = Color3.fromRGB(235, 235, 240),
	zone = Color3.fromRGB(60, 220, 120),
	table = Color3.fromRGB(110, 78, 52),
}

local function part(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- A wall between two XZ points (axis-aligned only), with a given thickness.
local function wall(parent: Instance, x1: number, z1: number, x2: number, z2: number, color: Color3?)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local sx = math.max(math.abs(x2 - x1), 1)
	local sz = math.max(math.abs(z2 - z1), 1)
	return part(parent, {
		Name = "Wall",
		Size = Vector3.new(sx, WALL_H, sz),
		CFrame = CFrame.new(cx, FLOOR_Y + WALL_H / 2, cz),
		Color = color or COLORS.wall,
	})
end

local function label(p: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 80
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.3
	t.Text = text
	t.Parent = gui
	gui.Parent = p
end

function LevelBuilder.build()
	local old = workspace:FindFirstChild("Level")
	if old then
		old:Destroy()
	end

	local level = Instance.new("Folder")
	level.Name = "Level"
	level.Parent = workspace

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = level

	-- Ground: street + bank floor
	part(level, {
		Name = "Street",
		Size = Vector3.new(80, 1, 80),
		CFrame = CFrame.new(10, FLOOR_Y - 0.5, 0),
		Color = COLORS.street,
		Material = Enum.Material.Asphalt,
	})
	part(level, {
		Name = "BankFloor",
		Size = Vector3.new(92, 1, 52),
		CFrame = CFrame.new(86, FLOOR_Y - 0.5, 0),
		Color = COLORS.floor,
		Material = Enum.Material.Marble,
	})

	-- Hideout spawn + getaway van
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HideoutSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, FLOOR_Y + 0.5, 6)
	spawn.Color = Color3.fromRGB(90, 90, 110)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = level

	part(level, {
		Name = "Van",
		Size = Vector3.new(14, 7, 7),
		CFrame = CFrame.new(0, FLOOR_Y + 3.5, -17),
		Color = COLORS.van,
	})
	local deliverZone = part(level, {
		Name = "DeliverZone",
		Size = Vector3.new(14, 0.2, 7),
		CFrame = CFrame.new(0, FLOOR_Y + 0.1, -10),
		Color = COLORS.zone,
		Material = Enum.Material.Neon,
		Transparency = 0.4,
		CanCollide = false,
	})
	label(deliverZone, "GETAWAY VAN: DROP LOOT HERE", COLORS.zone)

	-- Bank lobby walls: x 40..90, z -25..25, entrance gap at z -4..4 on x=40
	wall(walls, 40, -25, 40, -4)
	wall(walls, 40, 4, 40, 25)
	wall(walls, 40, 25, 132, 25)
	wall(walls, 40, -25, 132, -25)
	wall(walls, 132, -25, 132, 25, COLORS.vaultWall)
	-- Partition east of the blue plate: without it the guard's cone sweeps the
	-- plate on every patrol lap and busts the echo holding it.
	wall(walls, 56, 13, 56, 25)

	-- Vault wall at x=90 with a door gap z -5..5
	wall(walls, 90, -25, 90, -5, COLORS.vaultWall)
	wall(walls, 90, 5, 90, 25, COLORS.vaultWall)
	local doorClosed = CFrame.new(90, FLOOR_Y + WALL_H / 2, 0)
	local vaultDoor = part(walls, {
		Name = "VaultDoor",
		Size = Vector3.new(2.5, WALL_H, 10),
		CFrame = doorClosed,
		Color = COLORS.door,
		Material = Enum.Material.DiamondPlate,
	})
	label(vaultDoor, "VAULT", Color3.new(1, 1, 1))

	-- Plate A (blue): opens the vault door while someone stands on it.
	local plateA = part(level, {
		Name = "PlateA",
		Size = Vector3.new(6, 0.3, 6),
		CFrame = CFrame.new(52, FLOOR_Y + 0.15, 19),
		Color = COLORS.plateA,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	label(plateA, "HOLD TO OPEN VAULT", COLORS.plateA)

	-- Plate B (red): turns the lasers off while someone stands on it.
	local plateB = part(level, {
		Name = "PlateB",
		Size = Vector3.new(6, 0.3, 6),
		CFrame = CFrame.new(96, FLOOR_Y + 0.15, -19),
		Color = COLORS.plateB,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	label(plateB, "HOLD: LASERS OFF", COLORS.plateB)

	-- Laser grid at x=114 across the vault room
	local laserFolder = Instance.new("Folder")
	laserFolder.Name = "Lasers"
	laserFolder.Parent = level
	local laserParts = {}
	for i, y in { 1.2, 3.2, 5.2, 7.2, 9.2 } do
		local beam = part(laserFolder, {
			Name = "Laser" .. i,
			Size = Vector3.new(0.4, 0.4, 50),
			CFrame = CFrame.new(114, FLOOR_Y + y, 0),
			Color = COLORS.laser,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		})
		table.insert(laserParts, beam)
	end

	-- Loot tables behind the lasers
	local lootSpots = {}
	part(level, {
		Name = "GoldTable",
		Size = Vector3.new(4, 3, 30),
		CFrame = CFrame.new(124, FLOOR_Y + 1.5, 0),
		Color = COLORS.table,
		Material = Enum.Material.Wood,
	})
	local zs = { -12, -6, 0, 6, 12 }
	for i = 1, 5 do
		lootSpots["Gold" .. i] = CFrame.new(124, FLOOR_Y + 3.6, zs[i])
	end
	part(level, {
		Name = "DiamondPedestal",
		Size = Vector3.new(3, 4, 3),
		CFrame = CFrame.new(129, FLOOR_Y + 2, 0),
		Color = Color3.fromRGB(230, 230, 235),
		Material = Enum.Material.Marble,
	})
	lootSpots.Diamond = CFrame.new(129, FLOOR_Y + 5, 0)

	-- Lamps only. The Lighting service itself ("Heist Night" recipe v1) lives in
	-- default.project.json so the built place is the single source of truth.
	for _, pos in { Vector3.new(65, 12, 0), Vector3.new(110, 12, 0), Vector3.new(0, 10, -5) } do
		local holder = part(level, {
			Name = "Lamp",
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(pos),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 1.6
		light.Color = Color3.fromRGB(255, 236, 200)
		light.Parent = holder
	end

	return {
		folder = level,
		walls = walls,
		spawnCFrame = spawn.CFrame + Vector3.new(0, 3.5, 0),
		vaultDoor = vaultDoor,
		vaultDoorClosed = doorClosed,
		vaultDoorOpen = doorClosed + Vector3.new(0, WALL_H - 1, 0),
		plateA = plateA,
		plateB = plateB,
		laserParts = laserParts,
		-- Region an actor's root must be inside to be zapped (x band around the grid)
		-- 4 studs wide so a 16 stud/s runner can't slip between 10 Hz checks.
		laserRegion = { minX = 112, maxX = 116, minZ = -25, maxZ = 25, maxY = FLOOR_Y + 12 },
		lootSpots = lootSpots,
		deliverZone = deliverZone,
		guardWaypoints = {
			Vector3.new(58, FLOOR_Y + 3, -14),
			Vector3.new(82, FLOOR_Y + 3, -14),
			Vector3.new(82, FLOOR_Y + 3, 10),
			Vector3.new(58, FLOOR_Y + 3, 10),
		},
	}
end

return LevelBuilder
