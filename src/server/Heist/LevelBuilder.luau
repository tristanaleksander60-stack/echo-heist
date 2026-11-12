--!strict
-- Heist/LevelBuilder: builds a greybox copy of a compiled level (Sim/LevelSpec
-- LevelData) at an instance origin. MASTERPLAN §3.3 (one copy per heist instance,
-- 3,000 studs apart), §8.5 (levels are data; the sim boxes ARE the layout here until
-- the Blender kit is imported, spike S2), docs/STYLE_BIBLE.md (palette).
--
-- Every gameplay part carries attributes EH_Kind ("plate", "door", "laser", "loot",
-- "switch", "hide", "van") and EH_Index (the LevelSpec index), so clients bind by
-- attribute, never by guessing names. The server builds the parts once and never
-- moves or re-colours them again: doors, lasers, plates and loot are drawn by each
-- client from the replicated state (§8.2, the server never tweens), so a client's
-- local CanCollide on a door is never overwritten by replication.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local LevelBuilder = {}

export type Built = {
	model: Model,
	origin: Vector3,
	floor: BasePart,
	solids: { BasePart },
	plates: { BasePart },
	doors: { BasePart },
	lasers: { Model },
	loot: { BasePart },
	switches: { BasePart },
	hides: { Model },
	van: BasePart,
}

local function boxCenter(b: any): Vector3
	return Vector3.new((b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2, (b.minZ + b.maxZ) / 2)
end

local function boxSize(b: any): Vector3
	return Vector3.new(
		math.max(b.maxX - b.minX, 0.05),
		math.max(b.maxY - b.minY, 0.05),
		math.max(b.maxZ - b.minZ, 0.05)
	)
end

local function part(props: { [string]: any }, parent: Instance): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		if k ~= "ClassName" then
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function tag(inst: Instance, kind: string, index: number, id: string?)
	inst:SetAttribute("EH_Kind", kind)
	inst:SetAttribute("EH_Index", index)
	if id then
		inst:SetAttribute("EH_Id", id)
	end
end

-- An L-shaped floor cable from a plate to the device it drives (§7.3).
local function cable(
	parent: Instance,
	origin: Vector3,
	y: number,
	from: Vector3,
	to: Vector3,
	plate: number
): { BasePart }
	local out = {}
	local corner = Vector3.new(to.X, y, from.Z)
	local legs = { { Vector3.new(from.X, y, from.Z), corner }, { corner, Vector3.new(to.X, y, to.Z) } }
	for _, leg in legs do
		local a, b = leg[1], leg[2]
		local len = (b - a).Magnitude
		if len > 0.1 then
			local c = part({
				Name = "Cable",
				Size = Vector3.new(0.3, 0.06, len + 0.3),
				CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b),
				Color = Palette.steelLo,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, parent)
			c:SetAttribute("EH_Kind", "cable")
			c:SetAttribute("EH_Plate", plate)
			table.insert(out, c)
		end
	end
	return out
end

local function deviceCenters(level: any, plateIndex: number): { Vector3 }
	local out = {}
	for _, d in level.doors do
		for _, src in d.openBy do
			if src.kind == "plate" and src.index == plateIndex then
				local c = boxCenter(d.box)
				table.insert(out, Vector3.new(c.X, 0, c.Z))
			end
		end
	end
	for _, l in level.lasers do
		for _, src in l.offBy do
			if src.kind == "plate" and src.index == plateIndex then
				local c = boxCenter(l.box)
				table.insert(out, Vector3.new(l.box.maxX + 0.5, 0, c.Z))
			end
		end
	end
	return out
end

-- Builds `level` (LevelData) under `parent` with its level-space origin at `origin`.
function LevelBuilder.build(level: any, origin: Vector3, parent: Instance): Built
	local model = Instance.new("Model")
	model.Name = "Level"
	model:SetAttribute("LevelId", level.id)
	local floorY = level.floorY
	local b = level.bounds

	-- Floor: street side in Ink Indigo light, shop side in Plum Slate deep.
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(b.maxX - b.minX, 2, b.maxZ - b.minZ),
		CFrame = CFrame.new(origin + Vector3.new((b.minX + b.maxX) / 2, floorY - 1, (b.minZ + b.maxZ) / 2)),
		Color = Palette.plumDeep,
	}, model)

	local solids: { BasePart } = {}
	for i, s in level.spec.solids or {} do
		local low = s.sight == false
		local p = part({
			Name = if low then "Counter" else "Wall",
			Size = boxSize(s.box),
			CFrame = CFrame.new(origin + boxCenter(s.box)),
			Color = if low then Palette.marble else Palette.plum,
		}, model)
		p:SetAttribute("EH_Kind", "solid")
		p:SetAttribute("EH_Index", i)
		table.insert(solids, p)
	end
	for _, o in level.spec.occluders or {} do
		part({
			Name = "Occluder",
			Size = boxSize(o),
			CFrame = CFrame.new(origin + boxCenter(o)),
			Color = Palette.plumHi,
			Transparency = 0.3,
			CanCollide = false,
		}, model)
	end
	for _, n in level.spec.noGo or {} do
		part(
			{ Name = "NoGo", Size = boxSize(n), CFrame = CFrame.new(origin + boxCenter(n)), Color = Palette.ink },
			model
		)
	end

	-- Plates: steel pad with a white icon; the rim takes the presser's hue (client).
	local plates: { BasePart } = {}
	for i, def in level.plates do
		local c = boxCenter(def.box)
		local pad = part({
			Name = "Plate_" .. def.id,
			Size = Vector3.new(4, 0.2, 4),
			CFrame = CFrame.new(origin + Vector3.new(c.X, floorY + 0.1, c.Z)),
			Color = Palette.steel,
			Material = Enum.Material.Metal,
		}, model)
		tag(pad, "plate", i, def.id)
		local rim = part({
			Name = "Rim",
			Size = Vector3.new(4.6, 0.14, 4.6),
			CFrame = CFrame.new(origin + Vector3.new(c.X, floorY + 0.07, c.Z)),
			Color = Palette.steelLo,
			CanCollide = false,
			CastShadow = false,
		}, pad)
		rim:SetAttribute("EH_Kind", "rim")
		part({
			Name = "Icon",
			Size = Vector3.new(1.2, 0.05, 1.2),
			CFrame = CFrame.new(origin + Vector3.new(c.X, floorY + 0.22, c.Z)),
			Color = Palette.white,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		}, pad)
		for _, target in deviceCenters(level, i) do
			cable(pad, origin, floorY + 0.03, Vector3.new(c.X, 0, c.Z), target, i)
		end
		table.insert(plates, pad)
	end

	local switches: { BasePart } = {}
	for i, def in level.switches do
		local p = part({
			Name = "Switch_" .. def.id,
			Size = Vector3.new(1, 1, 0.4),
			CFrame = CFrame.new(origin + Vector3.new(def.x, def.y, def.z)),
			Color = Palette.steel,
			CanCollide = false,
		}, model)
		tag(p, "switch", i, def.id)
		table.insert(switches, p)
	end

	-- Doors: the solid leaf when shut + a lamp above it (red shut, green open).
	local doors: { BasePart } = {}
	for i, def in level.doors do
		local leaf = part({
			Name = "Door_" .. def.id,
			Size = boxSize(def.box),
			CFrame = CFrame.new(origin + boxCenter(def.box)),
			Color = Palette.steel,
			Material = Enum.Material.Metal,
		}, model)
		tag(leaf, "door", i, def.id)
		local c = boxCenter(def.box)
		local lamp = part({
			Name = "Lamp",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.8, 0.8, 0.8),
			CFrame = CFrame.new(origin + Vector3.new(c.X, def.box.maxY + 0.8, def.box.maxZ + 0.2)),
			Color = Palette.alarm,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		}, model)
		lamp:SetAttribute("EH_Kind", "lamp")
		lamp:SetAttribute("EH_Index", i)
		table.insert(doors, leaf)
	end

	-- Lasers: a grid of thin beams (dark ink posts, red body, white-hot core, §6.5).
	local lasers: { Model } = {}
	for i, def in level.lasers do
		local grid = Instance.new("Model")
		grid.Name = "Laser_" .. def.id
		tag(grid, "laser", i, def.id)
		local box = def.box
		local cz = (box.minZ + box.maxZ) / 2
		local width = box.maxX - box.minX
		local rows = math.max(2, math.floor((box.maxY - box.minY) / 2))
		for r = 1, rows do
			local y = box.minY + (r - 0.5) * (box.maxY - box.minY) / rows
			local beam = part({
				Name = "Beam",
				Size = Vector3.new(width, 0.25, 0.25),
				CFrame = CFrame.new(origin + Vector3.new((box.minX + box.maxX) / 2, y, cz)),
				Color = Palette.alarm,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, grid)
			beam:SetAttribute("EH_Kind", "beam")
			local core = part({
				Name = "Core",
				Size = Vector3.new(width, 0.08, 0.08),
				CFrame = beam.CFrame,
				Color = Palette.white,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, grid)
			core:SetAttribute("EH_Kind", "beam")
		end
		for _, x in { box.minX - 0.4, box.maxX + 0.4 } do
			part({
				Name = "Post",
				Size = Vector3.new(0.6, box.maxY - box.minY, 0.6),
				CFrame = CFrame.new(origin + Vector3.new(x, (box.minY + box.maxY) / 2, cz)),
				Color = Palette.ink,
				CanCollide = false,
			}, grid)
		end
		grid.Parent = model
		table.insert(lasers, grid)
	end

	-- Loot on dark display stands (gold vanishes on warm marble, STYLE_BIBLE).
	local loot: { BasePart } = {}
	for i, def in level.loot do
		local floorAt = floorY
		part({
			Name = "Stand",
			Size = Vector3.new(1.8, math.max(def.y - floorAt - 1, 0.2), 1.8),
			CFrame = CFrame.new(origin + Vector3.new(def.x, floorAt + math.max(def.y - floorAt - 1, 0.2) / 2, def.z)),
			Color = Palette.ink,
			CanCollide = false,
		}, model)
		local item = part({
			Name = "Loot_" .. def.id,
			Size = if def.value >= 100 then Vector3.new(1.6, 0.9, 1.1) else Vector3.new(0.8, 1, 0.8),
			CFrame = CFrame.new(origin + Vector3.new(def.x, def.y - 0.5, def.z)),
			Color = Palette.gold,
			Material = Enum.Material.Metal,
			CanCollide = false,
			CanTouch = false,
		}, model)
		tag(item, "loot", i, def.id)
		item:SetAttribute("EH_Value", def.value)
		table.insert(loot, item)
	end

	-- Hide spots: an open frame you can stand inside (EH_Hide volume).
	local hides: { Model } = {}
	for i, def in level.hides do
		local m = Instance.new("Model")
		m.Name = "Hide_" .. def.id
		tag(m, "hide", i, def.id)
		local hb = def.box
		local top = part({
			Name = "Top",
			Size = Vector3.new(hb.maxX - hb.minX, 0.3, hb.maxZ - hb.minZ),
			CFrame = CFrame.new(origin + Vector3.new((hb.minX + hb.maxX) / 2, hb.maxY - 0.15, (hb.minZ + hb.maxZ) / 2)),
			Color = Palette.plumHi,
			CanCollide = false,
		}, m)
		top:SetAttribute("EH_Kind", "hideTop")
		for _, cx in { hb.minX + 0.2, hb.maxX - 0.2 } do
			for _, cz in { hb.minZ + 0.2, hb.maxZ - 0.2 } do
				part({
					Name = "Post",
					Size = Vector3.new(0.3, hb.maxY - hb.minY, 0.3),
					CFrame = CFrame.new(origin + Vector3.new(cx, (hb.minY + hb.maxY) / 2, cz)),
					Color = Palette.plumHi,
					CanCollide = false,
				}, m)
			end
		end
		-- Hanging coats / crate slats: translucent sheets so the hider stays readable.
		part({
			Name = "Cover",
			Size = Vector3.new(hb.maxX - hb.minX - 0.4, (hb.maxY - hb.minY) * 0.7, 0.2),
			CFrame = CFrame.new(
				origin + Vector3.new((hb.minX + hb.maxX) / 2, hb.minY + (hb.maxY - hb.minY) * 0.55, hb.maxZ - 0.2)
			),
			Color = Palette.plumHi,
			Transparency = 0.45,
			CanCollide = false,
			CastShadow = false,
		}, m)
		m.Parent = model
		table.insert(hides, m)
	end

	-- The van: a bank zone in Getaway White with chevrons, the body parked behind it.
	local v = level.van
	local zone = part({
		Name = "VanZone",
		Size = Vector3.new(v.maxX - v.minX, 0.1, v.maxZ - v.minZ),
		CFrame = CFrame.new(origin + Vector3.new((v.minX + v.maxX) / 2, floorY + 0.05, (v.minZ + v.maxZ) / 2)),
		Color = Palette.exit,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
		CanCollide = false,
		CastShadow = false,
	}, model)
	zone:SetAttribute("EH_Kind", "van")
	for k = 0, 2 do
		local z = v.minZ + 1.5 + k * 2.2
		local chevron = part({
			ClassName = "WedgePart",
			Name = "Chevron",
			Size = Vector3.new(2.4, 0.08, 1.2),
			CFrame = CFrame.new(origin + Vector3.new((v.minX + v.maxX) / 2, floorY + 0.12, z))
				* CFrame.Angles(0, math.pi, 0),
			Color = Palette.exit,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		}, zone)
		chevron:SetAttribute("EH_Kind", "chevron")
	end
	local body = part({
		Name = "VanBody",
		Size = Vector3.new(v.maxX - v.minX + 1, 7, 8),
		CFrame = CFrame.new(origin + Vector3.new((v.minX + v.maxX) / 2, floorY + 4, v.maxZ + 4.5)),
		Color = Palette.exit,
	}, model)
	for _, wx in { v.minX - 0.2, v.maxX + 0.2 } do
		for _, wz in { v.maxZ + 2, v.maxZ + 7 } do
			part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 2.2, 2.2),
				CFrame = CFrame.new(origin + Vector3.new(wx, floorY + 1.1, wz)),
				Color = Palette.ink,
			}, body)
		end
	end

	model:SetAttribute("OriginX", origin.X)
	model:SetAttribute("OriginY", origin.Y)
	model:SetAttribute("OriginZ", origin.Z)
	model.Parent = parent
	return {
		model = model,
		origin = origin,
		floor = floor,
		solids = solids,
		plates = plates,
		doors = doors,
		lasers = lasers,
		loot = loot,
		switches = switches,
		hides = hides,
		van = zone,
	}
end

-- World position of a level-space point.
function LevelBuilder.toWorld(origin: Vector3, x: number, y: number, z: number): Vector3
	return origin + Vector3.new(x, y, z)
end

return LevelBuilder
