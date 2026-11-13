--!strict
-- Heist/LevelBuilder: builds a copy of a compiled level (Sim/LevelSpec LevelData) at an
-- instance origin. MASTERPLAN §3.3 (one copy per heist instance, 3,000 studs apart),
-- §8.5 (levels are data), docs/STYLE_BIBLE.md (palette), docs/art/KIT_IMPORT.md (kit).
--
-- The greybox is always built first: the sim boxes ARE the collision. When opts.kit
-- (src/server/Kit/KitService) is loaded, Heist/KitDresser dresses it with the art kit
-- (Heist/KitPlan): static pieces are visual only and the greybox parts they cover turn
-- into invisible colliders; door leaves, plates and loot are swapped for kit MeshParts
-- sized to the same boxes. If the kit is not ready, or dressing fails, the greybox stays
-- as it is (the clean switch: Config.Heist.KIT_LEVELS).
--
-- Every gameplay part carries attributes EH_Kind ("plate", "door", "laser", "loot",
-- "switch", "hide", "van") and EH_Index (the LevelSpec index), so clients bind by
-- attribute, never by guessing names. Greybox helpers carry EH_Kind too ("stand",
-- "post", "hideTop", "hideFrame", "vanBody", "vanWheel"), so the dresser can find them.
-- The server builds the parts once and never moves or re-colours them again: doors,
-- lasers, plates and loot are drawn by each client from the replicated state (§8.2, the
-- server never tweens), so a client's local CanCollide on a door is never overwritten.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local DecorPlan = require(script.Parent:WaitForChild("DecorPlan"))
local KitDresser = require(script.Parent:WaitForChild("KitDresser"))
local KitPlan = require(script.Parent:WaitForChild("KitPlan"))
local LevelDress = require(script.Parent:WaitForChild("LevelDress"))
local Overhead = require(script.Parent:WaitForChild("Overhead"))

local LIGHT = Config.Lighting
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)

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
	vanBody: BasePart,
	lamps: { BasePart }, -- greybox bulbs (EH_Kind "ceilingLamp"), each holding its Light; KitPlan.lamps order
	pools: { BasePart }, -- unlit floor pools (EH_Kind "lightPool")
	kit: boolean, -- dressed with the art kit
	dressing: boolean, -- Christmas layer placed
	kitResult: any?, -- KitDresser.Result (pieces, failures, why)
}

export type BuildOpts = {
	kit: any?, -- KitService (dress with the art kit when it is ready)
	dressing: boolean?, -- Christmas dressing layer
	location: string?, -- atlas / street front override (default: the spec's location)
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

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- A floor cable from a plate to the device it drives (§7.3): KitPlan.cables' polyline, legs overlapping
-- by half a width so the corners close. Idle in Vault Steel (LEVELS P0-2); WorldView lights it.
local function cable(parent: Instance, origin: Vector3, y: number, points: { { number } }, plate: number): { BasePart }
	local out = {}
	local w = LIGHT.CABLE_WIDTH
	for k = 1, #points - 1 do
		local a = Vector3.new(points[k][1], y, points[k][2])
		local b = Vector3.new(points[k + 1][1], y, points[k + 1][2])
		local len = (b - a).Magnitude
		if len > 0.1 then
			local c = part({
				Name = "Cable",
				Size = Vector3.new(w, 0.06, len + w),
				CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b),
				Color = Palette.steel,
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

-- Unlit letter on one face of a part (LightInfluence 0: readable at night without a light).
local function letterGui(host: BasePart, face: Enum.NormalId, text: string, textColor: Color3, disc: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Letter" .. face.Name
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.FontFace = FONT
	label.TextColor3 = textColor
	if disc then
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = disc
		f.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = gui
		label.Parent = f
	else
		label.Parent = gui
	end
	gui.Parent = host
end

-- A letter disc on a device (LEVELS P0-1): readable from both sides of its wall line.
local function plaque(parent: Instance, at: Vector3, alongX: boolean, depth: number, letters: string): BasePart
	local h = LIGHT.PLAQUE_SIZE
	local w = h * math.max(1, 0.55 * #letters + 0.45)
	local p = part({
		Name = "Plaque",
		Size = Vector3.new(w, h, depth),
		CFrame = CFrame.new(at) * (if alongX then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, parent)
	p:SetAttribute("EH_Kind", "plaque")
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		letterGui(p, face, letters, Palette.ink, Palette.steel)
	end
	return p
end

-- A ceiling lamp's light and its unlit floor pool (roblox_quality §1.2: one light per lamp, a SurfaceGui pool
-- with LightInfluence 0, never a plain Decal). The bulb is the greybox look; KitDresser hangs Lamp_Ceiling
-- over it and hides it. Only the hero lamp casts shadows (tagged EH_HeroShadow for LightDirector).
local function ceilingLamp(
	parent: Instance,
	origin: Vector3,
	floorY: number,
	l: any,
	index: number,
	look: any,
	poolRect: any?
): (BasePart, BasePart?)
	local spec = LIGHT.LAMP[l.kind] or LIGHT.LAMP.room
	if l.kind == "wash" then
		-- a warm wall wash (INTERIORS, KitPlan.lamps): a SpotLight near the ceiling aimed down the wall it faces, held by
		-- an invisible, visual-only part; no fixture, no floor pool
		local at = origin + Vector3.new(l.x, floorY + spec.lightY, l.z)
		local t = math.rad(spec.tilt)
		local aim = Vector3.new(l.dx or 0, 0, l.dz or 0) * math.cos(t) - Vector3.yAxis * math.sin(t)
		local holder = part({
			Name = "WallWash",
			Size = Vector3.one * 0.2,
			CFrame = CFrame.lookAt(at, at + aim),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, parent)
		holder:SetAttribute("EH_Kind", "wallWash")
		holder:SetAttribute("EH_Index", index)
		holder:SetAttribute("EH_LampKind", "wash")
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Angle = spec.angle
		spot.Range = spec.range
		spot.Brightness = spec.brightness
		spot.Color = rgb(look.color)
		spot.Shadows = false
		spot.Parent = holder
		return holder, nil
	end
	-- street lamps hang their light at the StreetLamp lantern (spec.bulbY / lightY), ceiling lamps under the shade
	local bulbY = spec.bulbY or LIGHT.BULB_Y
	local lightY = spec.lightY or LIGHT.LIGHT_Y
	local bulb = part({
		Name = if l.kind == "street" then "StreetLamp" else "CeilingLamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * LIGHT.BULB_SIZE,
		CFrame = CFrame.new(origin + Vector3.new(l.x, floorY + bulbY, l.z)),
		Color = rgb(LIGHT.BULB_COLOR),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, parent)
	bulb:SetAttribute("EH_Kind", "ceilingLamp")
	bulb:SetAttribute("EH_Index", index)
	bulb:SetAttribute("EH_LampKind", l.kind)
	if l.kind == "street" then
		-- greybox post under the bulb (the kit StreetLamp replaces both; KitDresser hides the greybox)
		part({
			Name = "Post",
			Size = Vector3.new(0.35, bulbY, 0.35),
			CFrame = CFrame.new(origin + Vector3.new(l.x, floorY + bulbY / 2 - LIGHT.BULB_SIZE / 2, l.z)),
			Color = Palette.steelLo,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		}, bulb)
	end
	local at = Instance.new("Attachment")
	at.Name = "LightAt"
	at.Position = Vector3.new(0, lightY - bulbY, 0)
	at.Parent = bulb
	local light: Light
	if l.kind == "hero" then
		local spot = Instance.new("SpotLight")
		spot.Angle = spec.angle
		spot.Face = Enum.NormalId.Bottom
		light = spot
	else
		light = Instance.new("PointLight")
	end
	light.Range = spec.range
	light.Brightness = look.brightness or spec.brightness -- a level theme may dim its room lamps (L3 Lights Out)
	light.Color = rgb(look.color) -- KitPlan.lampLooks: the location (or the level theme's) colour on room lamps
	light.Shadows = spec.shadows == true
	if spec.shadows then
		light:SetAttribute("EH_HeroShadow", true)
	end
	light.Parent = at

	local pc = LIGHT.POOL
	local d = spec.pool or (if l.kind == "hero" then pc.heroDiameter else pc.diameter)
	-- The pool part covers KitPlan.poolRect (a street pool stops at the building's wall face, so it never shines
	-- through the shop front onto the roofless interior). Its SurfaceGui is on the part's Front face turned to look
	-- up, so the canvas is a map of the floor: canvas right = world +X, canvas up = world -Z (Front face: up is the
	-- part's UpVector; right is its -X as you face it). The discs stay centred on the lamp; the canvas clips them.
	local rect = poolRect or { minX = l.x - d / 2, maxX = l.x + d / 2, minZ = l.z - d / 2, maxZ = l.z + d / 2 }
	local w, h = rect.maxX - rect.minX, rect.maxZ - rect.minZ
	local centre = origin + Vector3.new((rect.minX + rect.maxX) / 2, floorY + pc.lift, (rect.minZ + rect.maxZ) / 2)
	local pool = part({
		Name = "LightPool",
		Size = Vector3.new(w, h, 0.05),
		CFrame = CFrame.fromMatrix(centre, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, parent)
	pool:SetAttribute("EH_Kind", "lightPool")
	pool:SetAttribute("EH_Index", index)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Pool"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = pc.brightness
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pc.pixelsPerStud
	gui.MaxDistance = 250
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.Size = UDim2.fromScale(1, 1)
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Parent = gui
	local cu, cv = (l.x - rect.minX) / w, (l.z - rect.minZ) / h
	local function disc(inst: GuiObject, share: number)
		inst.AnchorPoint = Vector2.new(0.5, 0.5)
		inst.Position = UDim2.fromScale(cu, cv)
		inst.Size = UDim2.fromScale(share * d / w, share * d / h)
	end
	-- A smooth radial falloff (Config.Lighting.POOL_SOFT): the uploaded gradient image in one ImageLabel once its
	-- id is known (Heist/UiImages publishes it at boot; the client's LightDirector swaps late pools over), and
	-- until then thin discs that follow the same curve (KitPlan.poolRings), never the old hard steps.
	local soft = LIGHT.POOL_SOFT
	local stepped = spec.poolRings or pc.rings
	local uri = ReplicatedStorage:GetAttribute("EH_UiImage_" .. soft.image)
	local hasImage = type(uri) == "string" and uri ~= ""
	for _, ring in KitPlan.poolRings(stepped, soft) do
		local f = Instance.new("Frame")
		f.Name = "Ring"
		disc(f, ring.size)
		f.BackgroundColor3 = rgb(look.pool)
		f.BackgroundTransparency = ring.alpha
		f.BorderSizePixel = 0
		f.Visible = not hasImage
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = clip
	end
	local img = Instance.new("ImageLabel")
	img.Name = "Soft"
	disc(img, 1)
	img.BackgroundTransparency = 1
	img.Image = if hasImage then uri :: string else ""
	img.ImageColor3 = rgb(look.pool)
	img.ImageTransparency = 1 - KitPlan.poolPeak(stepped, soft)
	img.Visible = hasImage
	img.Parent = clip
	gui.Parent = pool
	return bulb, pool
end

-- Getaway arrows pointing at the van (+Z), flat on the zone (LEVELS P0-6): a shaft and a triangle head made
-- of two flat WedgeParts (each wedge's right-angled section laid in the floor plane by CFrame.fromMatrix:
-- local Y, its base leg, runs to world +-X; local -Z, its other leg, runs to world +Z, the van).
local function arrow(parent: Instance, origin: Vector3, y: number, cx: number, z0: number): { BasePart }
	local headW, headL = LIGHT.ARROW_HEAD[1], LIGHT.ARROW_HEAD[2]
	local shaftW, shaftL = LIGHT.ARROW_SHAFT[1], LIGHT.ARROW_SHAFT[2]
	local zBase = z0 + shaftL
	local t = 0.08
	local out = {}
	local shaft = part({
		Name = "ArrowShaft",
		Size = Vector3.new(shaftW, t, shaftL),
		CFrame = CFrame.new(origin + Vector3.new(cx, y, z0 + shaftL / 2)),
		Color = Palette.exit,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	}, parent)
	table.insert(out, shaft)
	for _, side in { 1, -1 } do
		local vy = Vector3.new(side, 0, 0)
		local vz = Vector3.new(0, 0, -1)
		local vx = vy:Cross(vz)
		local pos = origin + Vector3.new(cx + side * headW / 4, y, zBase + headL / 2)
		local w = part({
			ClassName = "WedgePart",
			Name = "ArrowHead",
			Size = Vector3.new(t, headW / 2, headL),
			CFrame = CFrame.fromMatrix(pos, vx, vy, vz),
			Color = Palette.exit,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, parent)
		table.insert(out, w)
	end
	return out
end

-- Builds `level` (LevelData) under `parent` with its level-space origin at `origin`.
function LevelBuilder.build(level: any, origin: Vector3, parent: Instance, opts: BuildOpts?): Built
	local model = Instance.new("Model")
	model.Name = "Level"
	-- StreamingEnabled readiness (§3.3/§8.6): only the crew receives this level, whatever
	-- the distance (HeistInstance adds each member with AddPersistentPlayer). A no-op
	-- while the place has streaming off.
	model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	model:SetAttribute("LevelId", level.id)
	-- the location it is built as (the client Backdrop and views read it; KitPlan.location)
	model:SetAttribute("Location", KitPlan.location(level, (opts or {}).dressing == true, (opts or {}).location))
	local floorY = level.floorY
	local b = level.bounds

	-- Floor: the lit `floor` swatch (W3: floors sit a value step above Ink, which is black under any night
	-- light); the kit's checker tiles cover it inside the building.
	local floor = part({
		Name = "Floor",
		Size = Vector3.new(b.maxX - b.minX, 2, b.maxZ - b.minZ),
		CFrame = CFrame.new(origin + Vector3.new((b.minX + b.maxX) / 2, floorY - 1, (b.minZ + b.maxZ) / 2)),
		Color = Palette.floor,
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

	-- Plates: steel pad with its letter on top; the rim glows Bulb Warm idle and takes the presser's hue
	-- (client, WorldView). The letter moves onto the kit plate when KitDresser swaps the pad.
	local cables = KitPlan.cables(level, LIGHT)
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
			Color = Palette.bulbWarm,
			Material = Enum.Material.Neon,
			Transparency = LIGHT.PLATE_IDLE_ALPHA,
			CanCollide = false,
			CastShadow = false,
		}, pad)
		rim:SetAttribute("EH_Kind", "rim")
		local ls = LIGHT.PLATE_LETTER_SIZE
		local letter = part({
			Name = "Letter",
			Size = Vector3.new(ls, 0.05, ls),
			CFrame = CFrame.new(origin + Vector3.new(c.X, floorY + 0.2 + 0.035, c.Z))
				* CFrame.Angles(0, math.rad(LIGHT.PLATE_LETTER_YAW), 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, pad)
		letter:SetAttribute("EH_Kind", "plateLetter")
		letterGui(letter, Enum.NormalId.Top, KitPlan.letter(level, i), Palette.exit, nil)
		for _, cb in cables do
			if cb.plate == i then
				cable(pad, origin, floorY + 0.03, cb.points, i)
			end
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
	local vaultRows = KitPlan.vaultRows(level, LIGHT)
	local rowDoor: { [number]: boolean } = {}
	for _, row in vaultRows do
		rowDoor[row.door] = true
	end
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
		-- The letter of every plate that opens it, beside the lamp on both faces of the header.
		local letters = KitPlan.deviceLetters(level, def.openBy)
		if letters ~= "" and not rowDoor[i] then -- a need-all door's letters are on its lamp row
			local bx = def.box
			local alongX = (bx.maxX - bx.minX) >= (bx.maxZ - bx.minZ)
			local thick = if alongX then bx.maxZ - bx.minZ else bx.maxX - bx.minX
			local off = if alongX
				then Vector3.new(LIGHT.PLAQUE_DOOR_DX, 0, 0)
				else Vector3.new(0, 0, LIGHT.PLAQUE_DOOR_DX)
			plaque(
				model,
				origin + Vector3.new(c.X, floorY + LIGHT.PLAQUE_DOOR_Y, c.Z) + off,
				alongX,
				thick + 0.2,
				letters
			)
		end
		table.insert(doors, leaf)
	end
	-- "Need all n" rows (LEVELS P1-3): a lettered lamp per plate on the door's face toward its plates, dim Bulb Warm
	-- until its plate is held (WorldView colours it), and the "VAULT n/4" count over the row.
	local vr = LIGHT.VAULT_ROW
	for _, row in vaultRows do
		local normal = Vector3.new(row.nx, 0, row.nz)
		local sx, sy, sz = 0, 0, 0
		for _, rl in row.lamps do
			local at = origin + Vector3.new(rl.x, rl.y, rl.z)
			sx, sy, sz = sx + at.X, sy + at.Y, sz + at.Z
			local lampPart = part({
				Name = "RowLamp_" .. rl.letter,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(vr.depth, vr.size, vr.size),
				CFrame = CFrame.fromMatrix(at, normal, Vector3.yAxis),
				Color = Palette.bulbWarm,
				Material = Enum.Material.Neon,
				Transparency = vr.idleAlpha,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, model)
			lampPart:SetAttribute("EH_Kind", "vaultLamp")
			lampPart:SetAttribute("EH_Index", rl.plate)
			lampPart:SetAttribute("EH_Door", row.door)
			letterGui(lampPart, Enum.NormalId.Right, rl.letter, Palette.ink, nil)
		end
		local n = #row.lamps
		local anchor = part({
			Name = "VaultCount",
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = CFrame.new(Vector3.new(sx / n, sy / n + vr.labelOffset, sz / n)),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, model)
		anchor:SetAttribute("EH_Kind", "vaultCount")
		anchor:SetAttribute("EH_Index", row.door)
		anchor:SetAttribute("EH_Total", n)
		local gui = Instance.new("BillboardGui")
		gui.Name = "Count"
		gui.Size = UDim2.fromOffset(150, 40)
		gui.LightInfluence = 0
		gui.MaxDistance = vr.labelDistance
		gui.Adornee = anchor
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = FONT
		label.TextScaled = true
		label.TextColor3 = Palette.bulbWarm
		label.Text = string.format("VAULT 0/%d", n)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Palette.ink
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = gui
		gui.Parent = anchor
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
		local ink = Config.WorldFx.LASER_INK
		for r = 1, rows do
			local y = box.minY + (r - 0.5) * (box.maxY - box.minY) / rows
			-- three layers (FEEDBACK_TABLE "Laser"): a dark ink sleeve, the red body, the white-hot core
			local sleeve = part({
				Name = "Ink",
				Size = Vector3.new(width, ink.width, ink.width),
				CFrame = CFrame.new(origin + Vector3.new((box.minX + box.maxX) / 2, y, cz)),
				Color = Palette.ink,
				Material = Enum.Material.SmoothPlastic,
				Transparency = ink.alpha,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, grid)
			sleeve:SetAttribute("EH_Kind", "beam")
			sleeve:SetAttribute("EH_Layer", "ink")
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
			beam:SetAttribute("EH_Layer", "body")
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
			core:SetAttribute("EH_Layer", "core")
		end
		for _, x in { box.minX - 0.4, box.maxX + 0.4 } do
			local post = part({
				Name = "Post",
				Size = Vector3.new(0.6, box.maxY - box.minY, 0.6),
				CFrame = CFrame.new(origin + Vector3.new(x, (box.minY + box.maxY) / 2, cz)),
				Color = Palette.ink,
				CanCollide = false,
			}, grid)
			post:SetAttribute("EH_Kind", "post")
		end
		-- The letter of the plate that turns it off, on the post nearer that plate.
		local letters = KitPlan.deviceLetters(level, def.offBy)
		local first = nil
		for _, src in def.offBy or {} do
			if src.kind == "plate" and level.plates[src.index] then
				first = level.plates[src.index]
				break
			end
		end
		if letters ~= "" and first then
			local pc = boxCenter(first.box)
			local alongX = (box.maxX - box.minX) >= (box.maxZ - box.minZ)
			local cx = (box.minX + box.maxX) / 2
			local at = if alongX
				then Vector3.new(if pc.X < cx then box.minX else box.maxX, floorY + LIGHT.PLAQUE_LASER_Y, cz)
				else Vector3.new(cx, floorY + LIGHT.PLAQUE_LASER_Y, if pc.Z < cz then box.minZ else box.maxZ)
			plaque(grid, origin + at, alongX, 1, letters)
		end
		grid.Parent = model
		table.insert(lasers, grid)
	end

	-- Loot on dark display stands (gold vanishes on warm marble, STYLE_BIBLE).
	local loot: { BasePart } = {}
	for i, def in level.loot do
		local floorAt = floorY
		local stand = part({
			Name = "Stand",
			Size = Vector3.new(1.8, math.max(def.y - floorAt - 1, 0.2), 1.8),
			CFrame = CFrame.new(origin + Vector3.new(def.x, floorAt + math.max(def.y - floorAt - 1, 0.2) / 2, def.z)),
			Color = Palette.ink,
			CanCollide = false,
		}, model)
		stand:SetAttribute("EH_Kind", "stand")
		stand:SetAttribute("EH_Index", i)
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
				local post = part({
					Name = "Post",
					Size = Vector3.new(0.3, hb.maxY - hb.minY, 0.3),
					CFrame = CFrame.new(origin + Vector3.new(cx, (hb.minY + hb.maxY) / 2, cz)),
					Color = Palette.plumHi,
					CanCollide = false,
				}, m)
				post:SetAttribute("EH_Kind", "hideFrame")
			end
		end
		-- Hanging coats / crate slats: translucent sheets so the hider stays readable.
		local cover = part({
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
		cover:SetAttribute("EH_Kind", "hideFrame")
		-- The soft outline of the hide's footprint (FEEDBACK_TABLE "Hide spot"): hidden until your character is
		-- within HIDE_OUTLINE.near studs (WorldView fades it in); kept when the kit dresses the hide.
		local ho = LIGHT.HIDE_OUTLINE
		local w = ho.width
		local sx, sz = hb.maxX - hb.minX, hb.maxZ - hb.minZ
		local cx, cz = (hb.minX + hb.maxX) / 2, (hb.minZ + hb.maxZ) / 2
		local y = level.floorY + ho.lift
		for _, e in
			{
				{ cx, hb.minZ + w / 2, sx, w },
				{ cx, hb.maxZ - w / 2, sx, w },
				{ hb.minX + w / 2, cz, w, sz - 2 * w },
				{ hb.maxX - w / 2, cz, w, sz - 2 * w },
			}
		do
			local edge = part({
				Name = "Outline",
				Size = Vector3.new(e[3], 0.04, e[4]),
				CFrame = CFrame.new(origin + Vector3.new(e[1], y, e[2])),
				Color = rgb(ho.color),
				Material = Enum.Material.Neon,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
			}, m)
			edge:SetAttribute("EH_Kind", "hideOutline")
			edge:SetAttribute("EH_Hide", i)
		end
		m.Parent = model
		table.insert(hides, m)
	end
	-- The letter of a plate inside a hide, on a disc over the hide (L4's coat rack, L6's desk / fern / stacks):
	-- "the plate is in there" reads from the room (LEVELS P1-2).
	for _, hp in KitPlan.hidePlates(level) do
		local host = hides[hp.hide]
		if host then
			plaque(host, origin + Vector3.new(hp.x, hp.top + LIGHT.HIDE_PLAQUE_Y, hp.z), true, 0.2, hp.letters)
		end
	end

	-- Lamps (W2): one over each plate, a hero over the goal, room centres (KitPlan.lamps, Heist/LevelDress).
	local lamps: { BasePart } = {}
	local pools: { BasePart } = {}
	-- Room lamps take the location's light colour (Config.Lighting.LOCATION, PLAN_STEAM_PLUS §3.1).
	local lampList = KitPlan.lamps(level, LevelDress[level.id], LIGHT)
	local buildOpts: BuildOpts = opts or {}
	local buildLocation = KitPlan.location(level, buildOpts.dressing == true, buildOpts.location)
	-- each level's own room light (Config.Interior.THEMES: the bakery's peach, the pharmacy's cool white ...)
	local themeLight = if Config.Interior.ENABLED then DecorPlan.light(level, buildLocation, Config.Interior) else nil
	local looks = KitPlan.lampLooks(lampList, buildLocation, LIGHT, themeLight)
	for k, l in lampList do
		local spec = LIGHT.LAMP[l.kind] or LIGHT.LAMP.room
		local d = spec.pool or (if l.kind == "hero" then LIGHT.POOL.heroDiameter else LIGHT.POOL.diameter)
		local bulb, pool = ceilingLamp(model, origin, floorY, l, k, looks[k], KitPlan.poolRect(level, l.x, l.z, d))
		lamps[k] = bulb
		if pool then
			pools[k] = pool
		end
	end
	-- The shop's name over the entrance (Config.Interior.THEMES: each level its own shop; DecorPlan.fascia): a thin
	-- board on the kit front's sign board, its SurfaceGui toward the street. Visual only.
	local fascia = if Config.Interior.ENABLED
		then DecorPlan.fascia(
			level,
			buildLocation,
			{ KP = KitPlan, cfg = Config.Interior }
		)
		else nil
	if fascia then
		local board = part({
			Name = "Fascia",
			Size = Vector3.new(fascia.w, fascia.h, 0.05),
			CFrame = CFrame.new(origin + Vector3.new(fascia.x, fascia.y, fascia.z)),
			Color = rgb(fascia.board),
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		}, model)
		board:SetAttribute("EH_Kind", "fascia")
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Name"
		gui.Face = Enum.NormalId.Back -- +Z: the street
		gui.LightInfluence = 0.4
		gui.Brightness = 1.3
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.MaxDistance = 220
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.94, 0.8)
		t.Position = UDim2.fromScale(0.03, 0.1)
		t.FontFace = FONT
		t.TextScaled = true
		t.TextColor3 = rgb(fascia.color)
		t.Text = fascia.text
		t.Parent = gui
		gui.Parent = board
	end

	-- The van: a bank zone in Getaway White, dim until you carry loot (WorldView lights it then), with
	-- arrows pointing at the van; the body parked behind it.
	local v = level.van
	local zone = part({
		Name = "VanZone",
		Size = Vector3.new(v.maxX - v.minX, 0.1, v.maxZ - v.minZ),
		CFrame = CFrame.new(origin + Vector3.new((v.minX + v.maxX) / 2, floorY + 0.05, (v.minZ + v.maxZ) / 2)),
		Color = Palette.exit,
		Transparency = LIGHT.VAN_IDLE_ALPHA,
		CanCollide = false,
		CastShadow = false,
	}, model)
	zone:SetAttribute("EH_Kind", "van")
	do
		local n = LIGHT.ARROW_COUNT
		local length = LIGHT.ARROW_SHAFT[2] + LIGHT.ARROW_HEAD[2]
		local z0 = v.minZ + ((v.maxZ - v.minZ) - ((n - 1) * LIGHT.ARROW_STEP + length)) / 2
		for k = 0, n - 1 do
			for _, p in arrow(zone, origin, floorY + 0.12, (v.minX + v.maxX) / 2, z0 + k * LIGHT.ARROW_STEP) do
				p.Transparency = LIGHT.ARROW_IDLE_ALPHA
				p:SetAttribute("EH_Kind", "chevron")
			end
		end
	end
	local body = part({
		Name = "VanBody",
		Size = Vector3.new(v.maxX - v.minX + 1, 7, 8),
		CFrame = CFrame.new(origin + Vector3.new((v.minX + v.maxX) / 2, floorY + 4, v.maxZ + 4.5)),
		Color = Palette.exit,
	}, model)
	body:SetAttribute("EH_Kind", "vanBody")
	for _, wx in { v.minX - 0.2, v.maxX + 0.2 } do
		for _, wz in { v.maxZ + 2, v.maxZ + 7 } do
			local wheel = part({
				Name = "Wheel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.8, 2.2, 2.2),
				CFrame = CFrame.new(origin + Vector3.new(wx, floorY + 1.1, wz)),
				Color = Palette.ink,
			}, body)
			wheel:SetAttribute("EH_Kind", "vanWheel")
		end
	end

	model:SetAttribute("OriginX", origin.X)
	model:SetAttribute("OriginY", origin.Y)
	model:SetAttribute("OriginZ", origin.Z)
	local built: Built = {
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
		vanBody = body,
		lamps = lamps,
		pools = pools,
		kit = false,
		dressing = false,
		kitResult = nil,
	}
	local o: BuildOpts = opts or {}
	if o.kit ~= nil and Config.Heist.KIT_LEVELS then
		-- Clone Party is the Toy Shop in Christmas dressing (§4.2)
		local location = KitPlan.location(level, o.dressing == true, o.location)
		local ok, res = pcall(KitDresser.dress, level, built, origin, o.kit, {
			dressing = o.dressing == true,
			location = location,
			floor = Config.Heist.KIT_FLOOR,
			floorLift = Config.Heist.KIT_FLOOR_LIFT,
		})
		if ok then
			built.kitResult = res
			built.kit = res.ok
			built.dressing = res.ok and o.dressing == true
			if not res.ok and res.why ~= "kit not ready" then
				warn("[LevelBuilder] kit dressing skipped for " .. tostring(level.id) .. ": " .. tostring(res.why))
			end
		else
			warn("[LevelBuilder] kit dressing failed for " .. tostring(level.id) .. ": " .. tostring(res))
		end
	end
	model:SetAttribute("Kit", built.kit)
	-- BIG buildings (Config.Big): the ceiling, the upper storeys and the roof over the playable ground floor (visual
	-- only; kit pieces when the level was dressed, plain Parts otherwise). A failure never costs the level.
	do
		local bigLocation = KitPlan.location(level, o.dressing == true, o.location)
		local _, theme = DecorPlan.theme(level, bigLocation, Config.Interior)
		local useTheme = Config.Interior.ENABLED and theme ~= nil
		local okBig, err = pcall(Overhead.build, level, origin, model, if built.kit then o.kit else nil, {
			location = bigLocation,
			dressing = o.dressing == true,
			-- the level's ceiling colour (Ceiling_8x8_Tin, ~0.6x the wall value in first person) and its blade sign
			ceiling = if useTheme then theme.ceiling else nil,
			sign = if useTheme and bigLocation == "CornerShop" then theme.name else nil,
		})
		if not okBig then
			warn("[LevelBuilder] the BIG building failed for " .. tostring(level.id) .. ": " .. tostring(err))
		end
	end
	model.Parent = parent
	return built
end

-- World position of a level-space point.
function LevelBuilder.toWorld(origin: Vector3, x: number, y: number, z: number): Vector3
	return origin + Vector3.new(x, y, z)
end

return LevelBuilder
