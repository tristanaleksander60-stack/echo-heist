-- Plates, the vault door and the laser grid. Everything is driven by actor
-- positions, so players and echoes trigger them the same way.

local TweenService = game:GetService("TweenService")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Mechanisms = {}

local level: any
local doorOpen = false
local lasersOn = true
local plateAUntil = 0
local plateBUntil = 0
local doorTween: Tween? = nil

local DOOR_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function onPlate(plate: BasePart, pos: Vector3): boolean
	local rel = plate.CFrame:PointToObjectSpace(pos)
	local half = plate.Size / 2
	return math.abs(rel.X) <= half.X + 0.5 and math.abs(rel.Z) <= half.Z + 0.5 and rel.Y >= -1 and rel.Y <= 8
end

local function setPlateGlow(plate: BasePart, pressed: boolean)
	plate.Transparency = pressed and 0 or 0.45
end

local function setDoor(open: boolean)
	if open == doorOpen then
		return
	end
	doorOpen = open
	if doorTween then
		doorTween:Cancel()
	end
	local target = open and level.vaultDoorOpen or level.vaultDoorClosed
	level.vaultDoor.CanCollide = not open
	doorTween = TweenService:Create(level.vaultDoor, DOOR_TWEEN, { CFrame = target })
	doorTween:Play()
end

local function setLasers(on: boolean)
	if on == lasersOn then
		return
	end
	lasersOn = on
	for _, beam in level.laserParts do
		beam.Transparency = on and 0.15 or 0.9
	end
end

function Mechanisms.init(levelInfo: any)
	level = levelInfo
	Mechanisms.reset()
end

function Mechanisms.reset()
	plateAUntil, plateBUntil = 0, 0
	doorOpen = true -- force setDoor to apply
	setDoor(false)
	lasersOn = false
	setLasers(true)
	setPlateGlow(level.plateA, false)
	setPlateGlow(level.plateB, false)
end

function Mechanisms.isDoorOpen(): boolean
	return doorOpen
end

-- Called ~10 times per second. Returns the actors zapped by lasers this tick.
function Mechanisms.tick(actors: { any }, now: number): { any }
	local pressedA, pressedB = false, false
	for _, a in actors do
		local pos = a.root.Position
		if onPlate(level.plateA, pos) then
			pressedA = true
		end
		if onPlate(level.plateB, pos) then
			pressedB = true
		end
	end
	if pressedA then
		plateAUntil = now + Config.PLATE_GRACE
	end
	if pressedB then
		plateBUntil = now + Config.PLATE_GRACE
	end
	setPlateGlow(level.plateA, pressedA)
	setPlateGlow(level.plateB, pressedB)
	setDoor(now < plateAUntil)
	setLasers(not (now < plateBUntil))

	local zapped = {}
	if lasersOn then
		local r = level.laserRegion
		for _, a in actors do
			local p = a.root.Position
			if p.X >= r.minX and p.X <= r.maxX and p.Z >= r.minZ and p.Z <= r.maxZ and p.Y <= r.maxY then
				table.insert(zapped, a)
			end
		end
	end
	return zapped
end

-- True if the actor's root is inside the getaway zone.
function Mechanisms.inDeliverZone(actor: any): boolean
	local zone: BasePart = level.deliverZone
	local rel = zone.CFrame:PointToObjectSpace(actor.root.Position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X + 1 and math.abs(rel.Z) <= half.Z + 1 and rel.Y <= 9
end

return Mechanisms
