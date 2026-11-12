--!strict
-- Heist/PlayerHalo: your live character's warm rim and ground ring (PLAN_STEAM_PLUS §3.1, GOLDEN_FRAMES
-- G1: "the player avatar with its warm rim light and ground ring, readable against the floor"), so a
-- dark outfit never sinks into a dark floor. Client-only, built once, never per frame:
--   * rim: one Highlight on your character, outline only (Bulb Warm, fill off, depth-occluded);
--   * light: one warm PointLight behind and above you, no shadows (perf tiers 1-2 only);
--   * ring: a flat disc under your feet (an unlit SurfaceGui: a soft warm disc with a ring rim),
--     put on the floor by one downward ray a frame.
-- Heist/EchoView drives it (update in a heist, hide in the garage).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Budget = require(Shared:WaitForChild("Heist"):WaitForChild("Budget"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local C = Config.Clone

local PlayerHalo = {}

-- A flat unlit disc (SurfaceGui on a thin invisible part): stepped soft discs plus a ring rim.
-- `rim`: the ring's share of the canvas. Returns the part, its gui and the ring frame.
function PlayerHalo.disc(
	name: string,
	size: number,
	color: Color3,
	alphas: { number },
	rimAlpha: number,
	rim: number
): (BasePart, SurfaceGui, Frame)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(size, 0.05, size)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Glow"
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = C.GLOW_BRIGHTNESS
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(128, 128)
	gui.ClipsDescendants = false
	gui.Adornee = part
	gui.Parent = part
	-- Soft falloff from stepped discs; `alphas` = { core, ..., outer }, drawn largest first.
	local steps = #alphas
	for i = steps, 1, -1 do
		local f = Instance.new("Frame")
		f.Name = "Disc" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		local share = rim * (0.45 + 0.55 * (i / steps))
		f.Size = UDim2.fromScale(share, share)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = alphas[i]
		f.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = gui
	end
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(rim, rim)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Rim"
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Transparency = rimAlpha
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = ring
	ring.Parent = gui
	return part, gui, ring
end

function PlayerHalo.new(folder: Instance): any
	local halo = {}
	local warm = Palette.bulbWarm
	local rimHl = Instance.new("Highlight")
	rimHl.Name = "YouRim"
	rimHl.FillTransparency = 1
	rimHl.OutlineColor = warm
	rimHl.OutlineTransparency = C.HALO_RIM_ALPHA
	rimHl.DepthMode = Enum.HighlightDepthMode.Occluded
	rimHl.Enabled = false
	rimHl.Parent = folder
	local ringPart, ringGui =
		PlayerHalo.disc("YouRing", C.HALO_RING_SIZE, warm, { 0.8, 0.88, 0.94 }, C.HALO_RING_ALPHA, C.GLOW_DISC)
	ringGui.Enabled = false
	ringPart.Parent = folder
	local light = Instance.new("PointLight")
	light.Name = "YouLight"
	light.Color = warm
	light.Range = C.HALO_LIGHT_RANGE
	light.Brightness = C.HALO_LIGHT_BRIGHTNESS
	light.Shadows = false
	light.Enabled = false
	local lightAt: Attachment? = nil
	local lightOk = true
	local character: Model? = nil
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local function bind(char: Model?)
		character = char
		rimHl.Adornee = char
		if lightAt then
			lightAt:Destroy()
			lightAt = nil
		end
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local a = Instance.new("Attachment")
			a.Name = "EH_YouLight"
			a.Position = Vector3.new(C.HALO_LIGHT_OFFSET[1], C.HALO_LIGHT_OFFSET[2], C.HALO_LIGHT_OFFSET[3])
			a.Parent = root
			light.Parent = a
			lightAt = a
		end
		params.FilterDescendantsInstances = { folder, char :: any }
	end

	-- Shows the halo on your live character (called every heist frame).
	function halo.update()
		local lp = Players.LocalPlayer
		local char = lp and lp.Character
		if char ~= character or (char and lightAt and not lightAt:IsDescendantOf(char)) then
			bind(char)
		end
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			rimHl.Enabled = false
			ringGui.Enabled = false
			light.Enabled = false
			return
		end
		rimHl.Enabled = true
		light.Enabled = lightOk
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -C.HALO_RAY, 0), params)
		if hit then
			ringPart.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.06, 0))
			ringGui.Enabled = true
		else
			ringGui.Enabled = false
		end
	end

	function halo.hide()
		rimHl.Enabled = false
		ringGui.Enabled = false
		light.Enabled = false
	end

	-- Perf tier (§6.3): the light only on tiers 1-2; the rim and ring stay (they are the readability).
	function halo.setTier(tier: number)
		lightOk = Budget.haloLight(tier)
		if not lightOk then
			light.Enabled = false
		end
	end

	return halo
end

return PlayerHalo
