--!strict
-- Heist/Overhead: builds the BIG building (Heist/TowerPlan, Config.Big; PLAN_FIRST_PERSON §5 "BIG") into a level
-- copy: the ceiling over the playable rooms, the upper storeys, the roof and their details, as one Model named
-- "Overhead" under the level, with one child Model per cut-away group ("ceiling", "roof", "front", "back", "left",
-- "right"). Client Heist/CutAway reads the groups' attributes (EH_CutKind, EH_CutMin / EH_CutMax: world box,
-- EH_CutNormal: a face's outward normal) and fades them out of the camera's way; first person never hides them.
--
-- Visual only, always: every part is Anchored with CanCollide, CanTouch, CanQuery and CastShadow off, so the sim,
-- the server's collisions, Gus, the cameras' raycasts and the ground floor's light are exactly what they were. With
-- the kit ready the pieces are kit MeshParts (KitService.clone, the location's atlas; the facade bodies take their
-- runtime colour); without it (greybox levels, the kit still loading) every piece falls back to a plain Part, so a
-- greybox level still has its ceiling and its storeys. Parts of the "detail" / "xmas" layers carry EH_Layer (the
-- client hides them from Config.Big.DETAIL_OFF_TIER).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Strings = require(Shared:WaitForChild("Heist"):WaitForChild("Strings"))

local KitPlan = require(script.Parent:WaitForChild("KitPlan"))
local TowerPlan = require(script.Parent:WaitForChild("TowerPlan"))

local Overhead = {}

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
end

-- A glowing sign: SurfaceGui text with LightInfluence 0 on the named faces of its board.
local function signGui(p: BasePart, s: any)
	local faces = if s.face == "sides" then { Enum.NormalId.Left, Enum.NormalId.Right } else { Enum.NormalId.Front }
	local text = s.text
	if s.vertical then
		local letters = {}
		for ch in string.gmatch(text, "%S") do
			table.insert(letters, ch)
		end
		text = table.concat(letters, "\n")
	end
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Sign"
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 1.4
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 24
		gui.MaxDistance = 400
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.9, 0.86)
		t.Position = UDim2.fromScale(0.05, 0.07)
		t.FontFace = FONT
		t.TextScaled = true
		t.TextColor3 = rgb(s.color)
		t.Text = text
		t.Parent = gui
		gui.Parent = p
	end
end

-- Builds the plan into a Model under `parent` (the level), offset by `origin`. kit: KitService when ready (nil:
-- Parts only). Returns the model and the plan (nil when the level has no building or Big is off).
function Overhead.build(level: any, origin: Vector3, parent: Instance, kit: any?, opts: any?): (Model?, any)
	local o = opts or {}
	local specs: { [string]: any } = {}
	local useKit = kit ~= nil and kit.isReady and kit.isReady() and kit.report and kit.report().ok
	if useKit then
		for _, name in kit.names() do
			local spec = kit.spec(name)
			if spec then
				specs[name] = spec
			end
		end
	end
	local plan = TowerPlan.plan(level, specs, {
		location = o.location,
		dressing = o.dressing,
	}, { cfg = Config.Big, KP = KitPlan, signs = Strings.BIG_SIGN })
	if plan == nil then
		return nil, nil
	end
	local model = Instance.new("Model")
	model.Name = "Overhead"
	model:SetAttribute("EH_Kind", "overhead")
	model:SetAttribute("Style", plan.style)
	model:SetAttribute("FloorY", origin.Y + plan.floorY)
	model:SetAttribute("CeilY", origin.Y + plan.ceilY)
	model:SetAttribute("TopY", origin.Y + plan.topY)
	model:SetAttribute("OuterMin", origin + Vector3.new(plan.outer.minX, plan.floorY, plan.outer.minZ))
	model:SetAttribute("OuterMax", origin + Vector3.new(plan.outer.maxX, plan.topY, plan.outer.maxZ))
	local groups: { [string]: Model } = {}
	for _, g in plan.groups do
		local m = Instance.new("Model")
		m.Name = g.name
		m:SetAttribute("EH_CutKind", g.kind)
		local b = g.box
		m:SetAttribute("EH_CutMin", origin + Vector3.new(b.minX, b.minY, b.minZ))
		m:SetAttribute("EH_CutMax", origin + Vector3.new(b.maxX, b.maxY, b.maxZ))
		if g.normal then
			m:SetAttribute("EH_CutNormal", Vector3.new(g.normal[1], 0, g.normal[2]))
			m:SetAttribute("EH_CutPlane", (g.plane :: number) + (if g.normal[1] ~= 0 then origin.X else origin.Z))
		end
		m.Parent = model
		groups[g.name] = m
	end
	local function layer(p: Instance, l: string)
		if l ~= "base" then
			p:SetAttribute("EH_Layer", l)
		end
	end
	for _, ps in plan.parts do
		local p = Instance.new("Part")
		p.Name = ps.name
		p.Size = Vector3.new(ps.size[1], ps.size[2], ps.size[3])
		p.CFrame = CFrame.new(origin + Vector3.new(ps.pos[1], ps.pos[2], ps.pos[3]))
			* CFrame.Angles(0, math.rad(ps.yaw), 0)
		p.Color = rgb(ps.color)
		p.Material = if ps.material == "Neon" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		quiet(p)
		layer(p, ps.layer)
		if ps.sign then
			signGui(p, ps.sign)
		end
		p.Parent = groups[ps.group] or model
	end
	if useKit then
		for _, it in plan.items do
			for _, name in it.pieces do
				local color = if it.color then rgb(it.color) else nil
				local p = kit.clone(name, { atlas = plan.location, color = color })
				if p then
					local c, size = KitPlan.partFrame(specs[name], it.pivot, it.scale)
					p.Size = Vector3.new(size[1], size[2], size[3])
					p.CFrame = CFrame.new(origin + Vector3.new(c[1], c[2], c[3]))
						* CFrame.Angles(0, math.rad(it.pivot.yaw), 0)
					quiet(p)
					layer(p, it.layer)
					p.Parent = groups[it.group] or model
				end
			end
		end
	end
	model:SetAttribute("Kit", useKit == true)
	model.Parent = parent
	return model, plan
end

return Overhead
