--!strict
-- Heist/Cinematic: the story intro (docs/art/intro/STORYBOARD.md; PLAN_FIRST_PERSON §5 "INTRO"; MASTERPLAN §4.3).
-- The shot list is data in Shared/Heist/IntroPlan; this module builds the stage on this client only and plays it:
--   * the stage: a toy town under the northern lights (the game's own Heist/Aurora, anchored to the stage; the
--     session's aurora hides meanwhile), Hoardsworth Tower (the kit's art-deco landmark: setbacks, gold crown, lit
--     windows, the giant H) with the giant vacuum on its gantry and the Snow Globe Vault on its terrace, the crew's
--     garage with the van. Built locally at Config.Intro.STAGE_ORIGIN (far from every heist slot)
--     from ReplicatedStorage/<Config.Intro.KIT_FOLDER> (the server's Heist/IntroKit), with Part stand-ins for any
--     mesh that has not arrived. Client-made parts are never streamed, never collide, are never queried.
--   * the Rookie: ReplicatedStorage/<Config.Intro.CHARACTER_KIT>/<ROOKIE_TEMPLATE> (the CHARACTER track's R15
--     template, read when the garage is built), posed through its Motor6D.Transform with the IntroPlan joint angles
--     (the same R15 joint names), smug face on the grin; the clones are copies of it drawn as EchoView draws your
--     clones (outfit kept, crew pieces in your hue with the solo age ramp, one crew-hue Highlight, floor glows,
--     the tape print from the feet up under a scan band), striking his pose. A Part stand-in only when the kit
--     never arrived.
--   * the camera: CameraDirector is suspended ("intro"); the camera is Scriptable on IntroPlan.camera (Catmull-Rom
--     keys, eased, whip-pans as a fast yaw with a blur), restored on every exit path (end, SKIP, destroy, watchdog).
--   * caption cards (Ui/Theme/Motion kit, Strings.INTRO), letterbox bars, a SKIP button from the first frame (any
--     key on a keyboard too), the HEIST YOURSELF wordmark smash (ReplicatedFirst/Wordmark) as the last shot.
--   * effects: present swirl (sparkles through the Heist/Particles budget), suction beams and the suction vortex
--     (spiral Beam arms spun about the mouth, Config.Intro.VORTEX), snow, monocle glint, headlights, the H sign's
--     floodlight, the clones' tape print, flashes (Heist/FlashLimit), screen shake (Settings
--     "shake" and reduced motion turn it off). Reduced motion: cuts instead of whip-pans, no shake, no flashes.
--   * audio: IntroPlan cues through Heist/Sound (empty cues until the owner's ids land: docs/AUDIO.md).
--
--   Cinematic.new(opts) -> cine        build without playing (tests step it by hand)
--     cine.step(dt)                    advance the plan and draw the frame
--     cine.skip()                      SKIP: the same end state as watching to the end
--     cine.isDone() / cine.t()         state
--     cine.destroy()                   tear down and restore everything (idempotent)
--   Cinematic.play(opts?) -> cine      first join and the lobby TV: build, play in real time, hand back
--   Cinematic.isPlaying() -> boolean
-- opts: { parent: Instance? (workspace), gui: Instance? (PlayerGui), camera: Camera?, director: any? (CameraDirector),
--         reduced: (() -> boolean)?, tier: number?, onEnd: ((how: string) -> ())? ("finished" | "skipped") }

local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local CloneState = require(HeistShared:WaitForChild("CloneState"))
local IntroPlan = require(HeistShared:WaitForChild("IntroPlan"))
local IntroRig = require(HeistShared:WaitForChild("IntroRig"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Aurora = require(script.Parent:WaitForChild("Aurora"))
local FlashLimit = require(script.Parent:WaitForChild("FlashLimit"))
local Particles = require(script.Parent:WaitForChild("Particles"))
local PlayerHalo = require(script.Parent:WaitForChild("PlayerHalo"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local HudCommon = require(script.Parent:WaitForChild("Hud"):WaitForChild("Common"))

local I = Config.Intro
local C = Config.Clone
local ST = IntroPlan.STAGE

local Cinematic = {}

local RENDER_NAME = "EH_Cinematic"
local WARM = Color3.fromHex("#F6C0A2") -- Bulb Warm (eh_palette.WARM_BULB)
local OFF = Palette.steelLo
local SIGN = Color3.fromHex(I.SIGN_COLOUR) -- the giant H on Hoardsworth Tower (eh_palette.NEON Intro_Tower_Sign)

local playing: any = nil

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function rad(d: number): number
	return math.rad(d)
end

local function quiet(p: BasePart, shadow: boolean?)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = shadow == true
	p.Massless = true
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	quiet(p, mat ~= Enum.Material.Neon)
	p.Parent = parent
	return p
end

local function boxLH(
	parent: Instance,
	name: string,
	base: CFrame,
	lo: Vector3,
	hi: Vector3,
	color: Color3,
	mat: Enum.Material?
): Part
	return part(parent, name, hi - lo, base * CFrame.new((lo + hi) / 2), color, mat)
end

-- A kit group from the intro kit folder, or nil.
local function kitModel(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild(I.KIT_FOLDER)
	local m = folder and folder:FindFirstChild(name)
	if m and m:IsA("Model") then
		local c = m:Clone()
		for _, d in c:GetDescendants() do
			if d:IsA("BasePart") then
				quiet(d, d.CastShadow)
			end
		end
		return c
	end
	return nil
end

local function partsByName(root: Instance): { [string]: BasePart }
	local out: { [string]: BasePart } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			out[d.Name] = d
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Rigs: rigid parts posed by FK (world[i] = world[parent] * C0 * pose), Gus's method (Heist/GusRig)
---------------------------------------------------------------------------
type Rig = {
	model: Model,
	parts: { BasePart },
	inv: { CFrame },
	c0: { CFrame },
	parentIx: { number },
	joints: { string },
	world: { CFrame },
	deco: { { part: BasePart, joint: number, offset: CFrame } },
	kind: string,
}

local function newRig(model: Model, kind: string): Rig
	return {
		model = model,
		parts = {},
		inv = {},
		c0 = {},
		parentIx = {},
		joints = {},
		world = {},
		deco = {},
		kind = kind,
	}
end

local function addJoint(rig: Rig, p: BasePart, joint: string, parentIx: number, c0: CFrame)
	table.insert(rig.parts, p)
	table.insert(rig.inv, p.PivotOffset:Inverse())
	table.insert(rig.c0, c0)
	table.insert(rig.parentIx, parentIx)
	table.insert(rig.joints, joint)
	table.insert(rig.world, CFrame.identity)
end

local function poseRig(rig: Rig, feet: CFrame, a: string, b: string, w: number, parts: { BasePart }, cfs: { CFrame })
	for i, joint in rig.joints do
		local x, y, z = IntroPlan.joint(a, b, w, joint)
		local pi = rig.parentIx[i]
		local base = if pi == 0 then feet * rig.c0[i] else rig.world[pi] * rig.c0[i]
		local wcf = base * CFrame.fromEulerAnglesYXZ(rad(x), rad(y), rad(z))
		rig.world[i] = wcf
		table.insert(parts, rig.parts[i])
		table.insert(cfs, wcf * rig.inv[i])
	end
	for _, d in rig.deco do
		table.insert(parts, d.part)
		table.insert(cfs, rig.world[d.joint] * d.offset)
	end
end

-- Hoardsworth: the kit's 17 meshes, or boxes sized from the manifest bounds (IntroRig), plus the gold ring on his
-- right glove (Config.Intro.RING: a thin Neon-gold disc that rides the hand as a rig decoration) and his open
-- laughing mouth (Config.Intro.LAUGH_MOUTH, hidden until IntroPlan.laughing). Returns the rig, the monocle (its
-- glint), the ring (its flash on the lever) and the mouth parts.
local function buildHoardsworth(parent: Instance): (Rig, BasePart, BasePart, { BasePart })
	local kit = kitModel("Hoardsworth")
	local map = if kit then partsByName(kit) else nil
	if map then
		for _, spec in IntroRig.PARTS do
			if not map[spec.name] then
				map = nil
				break
			end
		end
	end
	local model = Instance.new("Model")
	model.Name = "Hoardsworth"
	local rig = newRig(model, if map then "mesh" else "box")
	local index: { [string]: number } = {}
	for i, spec in IntroRig.PARTS do
		local p: BasePart
		if map then
			p = map[spec.name]
		else
			local mn, mx = spec.min, spec.max
			local bp = Instance.new("Part")
			bp.Size = Vector3.new(mx[1] - mn[1], mx[2] - mn[2], mx[3] - mn[3])
			bp.PivotOffset = CFrame.new(-(mn[1] + mx[1]) / 2, -(mn[2] + mx[2]) / 2, -(mn[3] + mx[3]) / 2)
			bp.Color = Color3.fromHex(IntroRig.ROLE_HEX[spec.role] or "#8C2F4B")
			bp.Material = Enum.Material.SmoothPlastic
			p = bp
		end
		quiet(p, true)
		p.Name = spec.name
		p.Parent = model
		index[spec.name] = i
		local o = spec.origin
		local par = spec.parent
		if par then
			local po = IntroRig.PARTS[index[par]].origin
			addJoint(rig, p, spec.joint, index[par], CFrame.new(o[1] - po[1], o[2] - po[2], o[3] - po[3]))
		else
			addJoint(rig, p, spec.joint, 0, CFrame.new(o[1], o[2], o[3]))
		end
	end
	if kit then
		kit:Destroy()
	end
	local R = I.RING
	local ring = Instance.new("Part")
	ring.Name = "Hoardsworth_Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(R.SIZE[1], R.SIZE[2], R.SIZE[3])
	ring.Color = Color3.fromHex(R.COLOUR)
	ring.Material = Enum.Material.Neon
	quiet(ring, false)
	ring.Parent = model
	local function onJoint(partName: string, spec: any, name: string, shape: Enum.PartType): BasePart?
		local ix = index[partName]
		if not ix then
			return nil
		end
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = Vector3.new(spec.SIZE[1], spec.SIZE[2], spec.SIZE[3])
		p.Color = Color3.fromHex(spec.COLOUR)
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 1
		quiet(p, false)
		p.Parent = model
		table.insert(rig.deco, {
			part = p,
			joint = ix,
			offset = CFrame.new(spec.OFFSET[1], spec.OFFSET[2], spec.OFFSET[3]),
		})
		return p
	end
	local mouth: { BasePart } = {}
	for _, key in { "MOUTH", "TEETH" } do
		local p = onJoint("Hoardsworth_Head", I.LAUGH_MOUTH[key], "Hoardsworth_Laugh" .. key, Enum.PartType.Block)
		if p then
			table.insert(mouth, p)
		end
	end
	local hand = index["Hoardsworth_RightHand"]
	if hand then
		local spec = IntroRig.PARTS[hand]
		local centre = Vector3.new(
			(spec.min[1] + spec.max[1]) / 2,
			(spec.min[2] + spec.max[2]) / 2,
			(spec.min[3] + spec.max[3]) / 2
		)
		table.insert(rig.deco, {
			part = ring,
			joint = hand,
			-- the cylinder's axis (X) turned onto the hand's Z: the signet faces up off the knuckles
			offset = CFrame.new(centre + Vector3.new(R.OFFSET[1], R.OFFSET[2], R.OFFSET[3]))
				* CFrame.Angles(0, math.pi / 2, 0),
		})
	end
	model.Parent = parent
	return rig, rig.parts[index[IntroRig.MONOCLE]], ring, mouth
end

-- The Rookie stand-in (only when CharacterKit's Rookie never arrived): an R15-proportioned figure with a flat
-- cap, a long scarf and a smug side-eye, in the stand-in colours of docs/marketing (no reserved clone hue).
local ROOKIE = {
	skin = Color3.fromHex("#D69A78"),
	jacket = Color3.fromHex("#4F8A5B"),
	pants = Color3.fromHex("#4A5374"),
	shoe = Color3.fromHex("#2A2D3F"),
	cap = Color3.fromHex("#6E5A4A"),
	scarf = Color3.fromHex("#963A3A"),
	scarf2 = Color3.fromHex("#EDE2C8"),
	eye = Color3.fromHex("#1C1F3B"),
}
-- { name, joint, parent joint, joint origin, size, centre offset from the joint, colour key }
local STANDIN = {
	{ "LowerTorso", "Root", nil, { 0, 2.0, 0 }, { 2.0, 0.6, 1.0 }, { 0, 0.3, 0 }, "pants" },
	{ "UpperTorso", "Waist", "Root", { 0, 2.3, 0 }, { 2.0, 1.75, 1.0 }, { 0, 0.875, 0 }, "jacket" },
	{ "Head", "Neck", "Waist", { 0, 4.05, 0 }, { 1.25, 1.2, 1.25 }, { 0, 0.62, 0 }, "skin" },
	{ "RightUpperArm", "RightShoulder", "Waist", { 1.5, 3.85, 0 }, { 0.92, 1.0, 0.92 }, { 0, -0.43, 0 }, "jacket" },
	{ "RightLowerArm", "RightElbow", "RightShoulder", { 1.5, 2.92, 0 }, { 0.9, 0.82, 0.9 }, { 0, -0.36, 0 }, "jacket" },
	{ "RightHand", "RightWrist", "RightElbow", { 1.5, 2.22, 0 }, { 0.78, 0.38, 0.78 }, { 0, -0.2, 0 }, "skin" },
	{ "LeftUpperArm", "LeftShoulder", "Waist", { -1.5, 3.85, 0 }, { 0.92, 1.0, 0.92 }, { 0, -0.43, 0 }, "jacket" },
	{ "LeftLowerArm", "LeftElbow", "LeftShoulder", { -1.5, 2.92, 0 }, { 0.9, 0.82, 0.9 }, { 0, -0.36, 0 }, "jacket" },
	{ "LeftHand", "LeftWrist", "LeftElbow", { -1.5, 2.22, 0 }, { 0.78, 0.38, 0.78 }, { 0, -0.2, 0 }, "skin" },
	{ "RightUpperLeg", "RightHip", "Root", { 0.5, 2.0, 0 }, { 0.96, 1.02, 0.96 }, { 0, -0.5, 0 }, "pants" },
	{ "RightLowerLeg", "RightKnee", "RightHip", { 0.5, 1.0, 0 }, { 0.94, 0.74, 0.94 }, { 0, -0.4, 0 }, "pants" },
	{ "LeftUpperLeg", "LeftHip", "Root", { -0.5, 2.0, 0 }, { 0.96, 1.02, 0.96 }, { 0, -0.5, 0 }, "pants" },
	{ "LeftLowerLeg", "LeftKnee", "LeftHip", { -0.5, 1.0, 0 }, { 0.94, 0.74, 0.94 }, { 0, -0.4, 0 }, "pants" },
}

local function buildStandIn(parent: Instance, name: string, hue: Color3?): Rig
	local model = Instance.new("Model")
	model.Name = name
	local rig = newRig(model, "standin")
	local index: { [string]: number } = {}
	local origins: { [string]: { number } } = {}
	local function col(key: string): Color3
		return hue or (ROOKIE :: any)[key]
	end
	for i, s in STANDIN do
		local nm, joint, par, o, size, off, key = s[1], s[2], s[3], s[4], s[5], s[6], s[7]
		local p = Instance.new("Part")
		p.Name = nm :: string
		p.Size = v3(size :: any)
		p.PivotOffset = CFrame.new(-v3(off :: any))
		p.Color = col(key :: string)
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		quiet(p, hue == nil)
		p.Parent = model
		index[joint :: string] = i
		origins[joint :: string] = o :: any
		local oo = o :: { number }
		if par then
			local po = origins[par :: string]
			addJoint(
				rig,
				p,
				joint :: string,
				index[par :: string],
				CFrame.new(oo[1] - po[1], oo[2] - po[2], oo[3] - po[3])
			)
		else
			addJoint(rig, p, joint :: string, 0, CFrame.new(oo[1], oo[2], oo[3]))
		end
	end
	-- head decorations: flat cap + brim, eyes (smug side-eye), scarf ring + tail (not on clones)
	local head = index.Neck
	local function deco(nm: string, size: Vector3, offset: CFrame, color: Color3, jointIx: number)
		local p = Instance.new("Part")
		p.Name = nm
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		quiet(p, hue == nil)
		p.Parent = model
		table.insert(rig.deco, { part = p, joint = jointIx, offset = offset })
	end
	deco("Cap", Vector3.new(1.42, 0.32, 1.5), CFrame.new(0, 1.3, 0.04), col("cap"), head)
	deco("Brim", Vector3.new(1.1, 0.1, 0.5), CFrame.new(0, 1.15, -0.7) * CFrame.Angles(rad(12), 0, 0), col("cap"), head)
	if hue == nil then
		for _, sx in { -1, 1 } do
			deco("Eye", Vector3.new(0.2, 0.2, 0.06), CFrame.new(0.24 * sx + 0.06, 0.66, -0.64), ROOKIE.eye, head)
			deco("Lid", Vector3.new(0.34, 0.08, 0.08), CFrame.new(0.24 * sx, 0.78, -0.64), ROOKIE.eye, head)
		end
		deco(
			"Smirk",
			Vector3.new(0.36, 0.07, 0.06),
			CFrame.new(-0.05, 0.3, -0.64) * CFrame.Angles(0, 0, rad(8)),
			ROOKIE.eye,
			head
		)
		local waist = index.Waist
		deco("Scarf", Vector3.new(1.5, 0.4, 1.3), CFrame.new(0, 1.8, 0), ROOKIE.scarf, waist)
		for k = 0, 3 do
			deco(
				"ScarfTail",
				Vector3.new(0.44, 0.36, 0.16),
				CFrame.new(-0.42, 1.55 - 0.37 * k, -0.6),
				if k % 2 == 0 then ROOKIE.scarf else ROOKIE.scarf2,
				waist
			)
		end
	end
	model.Parent = parent
	return rig
end

---------------------------------------------------------------------------
-- The cinematic
---------------------------------------------------------------------------
function Cinematic.new(opts: any?): any
	local o = opts or {}
	local cine: any = {}
	local reducedFn: () -> boolean = o.reduced or function()
		return GuiService.ReducedMotionEnabled
	end
	local tier = math.clamp(tonumber(o.tier) or 1, 1, 4)
	local origin = v3(I.STAGE_ORIGIN)
	local stageCF = CFrame.new(origin)
	local st = IntroPlan.new()
	local destroyed = false
	local onEnd: ((string) -> ())? = o.onEnd
	local ended = false

	local stage = Instance.new("Model")
	stage.Name = "EH_IntroStage"
	local function at(p: { number }, yawDeg: number?): CFrame
		return stageCF * CFrame.new(p[1], p[2], p[3]) * CFrame.Angles(0, rad(yawDeg or 0), 0)
	end

	-- saved state, restored on every exit path
	local camera: Camera? = o.camera or workspace.CurrentCamera
	local saved: any = {}
	if camera then
		saved.type = camera.CameraType
		saved.subject = camera.CameraSubject
		saved.fov = camera.FieldOfView
		saved.cf = camera.CFrame
	end
	saved.lighting = {
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		Brightness = Lighting.Brightness,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		saved.skyYaw = sky.SkyboxOrientation
		sky.SkyboxOrientation = Vector3.new(0, 180, 0) -- the painted landmark turns away from the 3D tower
	end
	if o.director then
		o.director.suspend("intro")
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "EH_IntroGrade"
	grade.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "EH_IntroBlur"
	blur.Size = 0
	blur.Parent = Lighting

	---------------------------------------------------------------- the town and the tower (built now)
	local windows: { BasePart } = {}
	local townLights: { PointLight } = {}
	-- The Part stand-in of Hoardsworth Tower (the kit never arrived): burgundy tiers, gold cornices and corner fins,
	-- lit windows on the front and a side, the roof deck.
	local function towerStandIn(f: Instance)
		local T = ST.tower
		local y = 0
		local base = T.base
		local gold, body = Palette.marbleLo, Color3.fromHex("#8C2F4B")
		for ti, tierSpec in T.tiers do
			local w, hgt = tierSpec[1], tierSpec[2]
			part(f, "Tier" .. ti, Vector3.new(w, hgt, w), at({ base[1], y + hgt / 2, base[3] }), body)
			part(f, "Cornice" .. ti, Vector3.new(w + 2, 1.6, w + 2), at({ base[1], y + hgt - 0.8, base[3] }), gold)
			for _, sx in { -1, 1 } do
				part(
					f,
					"Fin",
					Vector3.new(2.4, hgt - 1.6, 2.4),
					at({ base[1] + sx * w / 2, y + (hgt - 1.6) / 2, base[3] + w / 2 }),
					gold
				)
			end
			local rows = math.floor((hgt - 6) / 7)
			local cols = math.floor((w - 6) / 6)
			for r = 0, rows - 1 do
				for c = 0, cols - 1 do
					local x = base[1] - (cols - 1) * 3 + c * 6
					local yy = y + 6 + r * 7
					table.insert(
						windows,
						part(
							f,
							"TowerWin",
							Vector3.new(2.6, 4, 0.4),
							at({ x, yy, base[3] + w / 2 }),
							WARM,
							Enum.Material.Neon
						)
					)
					table.insert(
						windows,
						part(
							f,
							"TowerWin",
							Vector3.new(0.4, 4, 2.6),
							at({ base[1] + w / 2, yy, base[3] - (cols - 1) * 3 + c * 6 }),
							WARM,
							Enum.Material.Neon
						)
					)
				end
			end
			y += hgt
		end
		local d = T.deck
		part(f, "Deck", v3(d), at({ base[1], ST.deckY - d[2] / 2, base[3] }), Palette.inkHi)
		part(
			f,
			"DeckTrim",
			Vector3.new(d[1] + 0.8, 1, d[3] + 0.8),
			at({ base[1], ST.deckY - d[2] - 0.1, base[3] }),
			gold
		)
		part(f, "SignH", Vector3.new(10, 12, 0.6), at(T.sign), SIGN, Enum.Material.Neon)
	end

	local function townBuild()
		local f = Instance.new("Folder")
		f.Name = "Town"
		local g = ST.ground
		part(f, "Ground", v3(g.size), at(g.centre), Color3.fromHex("#8E92AC"))
		part(f, "Road", v3(ST.road.size), at(ST.road.centre), Palette.inkHi)
		local lights = I.TOWN_LIGHTS[tier] or 0
		for i, h in ST.houses do
			local name = if h[4] == 1 then "Intro_House_A" else "Intro_House_B"
			local m = kitModel(name)
			local cf = at({ h[1], 0, h[2] }, h[3])
			if m then
				m:PivotTo(cf)
				m.Parent = f
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") and string.find(d.Name, "_Windows", 1, true) then
						d.Color = if h[5] == 1 then WARM else OFF
						table.insert(windows, d)
					end
				end
			else -- stand-in: walls, roof, lit panes
				local w = if h[4] == 1 then 12 else 15
				boxLH(
					f,
					"HouseStandIn",
					cf,
					Vector3.new(-w / 2, 0, -5.5),
					Vector3.new(w / 2, 10, 5.5),
					Palette.marbleLo
				)
				local roof = Instance.new("WedgePart")
				quiet(roof, true)
				roof.Size = Vector3.new(w + 1.6, 4.5, 6.3)
				roof.CFrame = cf * CFrame.new(0, 12.25, -3.15)
				roof.Color = Palette.inkHi
				roof.Parent = f
				local back = roof:Clone()
				back.CFrame = cf * CFrame.new(0, 12.25, 3.15) * CFrame.Angles(0, math.pi, 0)
				back.Parent = f
				for _, x in { -w * 0.3, w * 0.3 } do
					local pane = part(
						f,
						"Pane",
						Vector3.new(1.8, 1.9, 0.15),
						cf * CFrame.new(x, 6.5, -5.55),
						if h[5] == 1 then WARM else OFF,
						Enum.Material.Neon
					)
					table.insert(windows, pane)
				end
			end
			if h[5] == 1 and #townLights < lights and i % 2 == 0 then
				local holder = part(f, "Glow", Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 4, -8), WARM)
				holder.Transparency = 1
				local l = Instance.new("PointLight")
				l.Color = WARM
				l.Range = 18
				l.Brightness = 1.4
				l.Parent = holder
				table.insert(townLights, l)
			end
		end
		for _, l in ST.lamps do
			local m = kitModel("StreetLamp")
			if m then
				m:PivotTo(at({ l[1], 0, l[2] }))
				m.Parent = f
			else
				part(f, "LampPost", Vector3.new(0.6, 11, 0.6), at({ l[1], 5.5, l[2] }), Palette.steelLo)
				part(f, "LampBulb", Vector3.new(1, 1, 1), at({ l[1], 10.6, l[2] }), WARM, Enum.Material.Neon)
			end
		end
		local tree = kitModel("Xmas_Tree")
		if tree then
			tree:PivotTo(at(ST.tree))
			tree:ScaleTo(2.6)
			tree.Parent = f
		end
		-- Hoardsworth Tower: the kit's art-deco landmark (setbacks, gold crown, lit windows, the giant H), turned to
		-- face the town; the Part stand-in (burgundy tiers, gold cornices, lit windows) only without the kit
		local T = ST.tower
		local tower = kitModel("Intro_Tower")
		if tower then
			tower:PivotTo(at(T.base, T.yaw))
			for _, d in tower:GetDescendants() do
				if d:IsA("BasePart") then
					if d.Name == "Intro_Tower_Windows" then
						d.Color = WARM
						table.insert(windows, d)
					elseif d.Name == "Intro_Tower_Sign" then
						d.Color = SIGN
					end
				end
			end
			tower.Parent = f
		else
			towerStandIn(f)
		end
		-- the H sign's floodlight (warm gold; it stays on when the town goes dark): from tier 2 down only
		if tier <= 2 then
			local holder = part(f, "SignLight", Vector3.new(0.2, 0.2, 0.2), at(T.sign) * CFrame.new(0, 0, 8), SIGN)
			holder.Transparency = 1
			local l = Instance.new("PointLight")
			l.Color = SIGN
			l.Range = I.SIGN_LIGHT.RANGE
			l.Brightness = I.SIGN_LIGHT.BRIGHTNESS
			l.Parent = holder
		end
		f.Parent = stage
	end

	---------------------------------------------------------------- the tower top: globe, vacuum, lever
	local pile: BasePart? = nil
	local pileSize: Vector3 = Vector3.one
	local pileOffset: CFrame = CFrame.identity
	local pilePivot: CFrame = CFrame.identity
	local vacuumLights: BasePart? = nil
	local suction: { Beam } = {}
	local vortex: { Beam } = {}
	local vortexHolder: BasePart? = nil
	local vortexBase: CFrame = CFrame.identity
	local vortexSpin = 0
	local swirlEmitter: ParticleEmitter? = nil
	local leverHandle: BasePart? = nil
	local leverRest: CFrame = CFrame.identity
	local globeLight: PointLight? = nil
	local function topBuild()
		local f = Instance.new("Folder")
		f.Name = "Top"
		local gc = ST.globe.centre
		local globe = kitModel("Intro_SnowGlobe")
		local gcf = at({ gc[1], ST.deckY, gc[3] })
		if globe then
			globe:PivotTo(gcf)
			globe.Parent = f
			local map = partsByName(globe)
			local p = map.Intro_SnowGlobe_Presents
			if p then
				pile = p
				pileSize = p.Size
				pileOffset = p.PivotOffset
				pilePivot = p:GetPivot()
			end
		else
			local glass = part(f, "GlobeGlass", Vector3.new(32, 32, 32), at(gc), Palette.steelHi, Enum.Material.Glass)
			glass.Shape = Enum.PartType.Ball
			glass.Transparency = 0.6
			part(f, "GlobePlinth", Vector3.new(25, 6.6, 25), gcf * CFrame.new(0, 3.3, 0), Color3.fromHex("#8C2F4B"))
			local p =
				part(f, "GlobePile", Vector3.new(18, 12, 18), gcf * CFrame.new(0, 11.4, 0), Color3.fromHex("#2FBF71"))
			p.PivotOffset = CFrame.new(0, -6, 0)
			pile, pileSize, pileOffset, pilePivot = p, p.Size, p.PivotOffset, p:GetPivot()
		end
		local holder = part(f, "GlobeLight", Vector3.new(0.2, 0.2, 0.2), at({ gc[1], gc[2] - 4, gc[3] }), WARM)
		holder.Transparency = 1
		local gl = Instance.new("PointLight")
		gl.Color = Color3.fromHex("#FFD9B0")
		gl.Range = 40
		gl.Brightness = 1.5
		gl.Parent = holder
		globeLight = gl
		-- the vacuum (authored 1.4x: it reads as GIANT next to Hoardsworth), on the tower's gantry
		local vac = kitModel("Intro_Vacuum")
		local vcf = at(ST.vacuum.at, ST.vacuum.yaw)
		if vac then
			vac:PivotTo(vcf)
			vac.Parent = f
			vacuumLights = partsByName(vac).Intro_Vacuum_Lights
			if vacuumLights then
				vacuumLights.Color = OFF
			end
		else
			local k = ST.vacuum.scale
			part(
				f,
				"VacuumStandIn",
				Vector3.new(18.8, 14, 14) * k,
				vcf * CFrame.new(0, 7.6 * k, 0),
				Color3.fromHex("#8C2F4B")
			)
			local mouth = part(f, "Mouth", Vector3.new(2, 13, 13) * k, at(ST.nozzle), Palette.steel)
			mouth.Shape = Enum.PartType.Cylinder
			mouth.CFrame = CFrame.lookAt(mouth.Position, mouth.Position + v3(ST.aim))
				* CFrame.Angles(0, math.rad(90), 0)
			vacuumLights = part(
				f,
				"VacuumLamp",
				Vector3.new(1.4, 1.4, 1.4) * k,
				vcf * CFrame.new(0, 14.6 * k, 0),
				OFF,
				Enum.Material.Neon
			)
		end
		-- the suction vortex: spiral arms of additive Beams on a funnel that narrows into the mouth (along the aim),
		-- spun about the aim each frame while the vacuum runs; arms per tier (Config.Intro.VORTEX)
		local V = I.VORTEX
		local nArms = V.ARMS[tier] or 0
		local aim = v3(ST.aim).Unit
		local mouthCF = CFrame.lookAt(v3(ST.nozzle), v3(ST.nozzle) + aim) -- -Z (look) = out of the mouth
		vortexBase = stageCF * mouthCF
		local vh = part(f, "Vortex", Vector3.new(1, 1, 1), vortexBase, OFF)
		vh.Transparency = 1
		vortexHolder = vh
		for arm = 1, nArms do
			local prev: Attachment? = nil
			local a0 = 2 * math.pi * (arm - 1) / nArms
			for j = 0, V.POINTS - 1 do
				local s = j / (V.POINTS - 1) -- 0 at the mouth, 1 at the funnel's far end
				local r = V.MOUTH_RADIUS + (V.FAR_RADIUS - V.MOUTH_RADIUS) * s ^ V.FLARE
				local ang = a0 + V.TURNS * 2 * math.pi * (1 - s)
				local a = Instance.new("Attachment")
				a.Position = Vector3.new(r * math.cos(ang), r * math.sin(ang), -V.LENGTH * s)
				a.Parent = vh
				if prev then
					local b = Instance.new("Beam")
					b.Attachment0 = a
					b.Attachment1 = prev
					b.FaceCamera = true
					b.Segments = 10
					b.Width0 = V.WIDTH[1] + (V.WIDTH[2] - V.WIDTH[1]) * s
					b.Width1 = V.WIDTH[1] + (V.WIDTH[2] - V.WIDTH[1]) * (s - 1 / (V.POINTS - 1))
					b.CurveSize0 = V.CURVE * r
					b.CurveSize1 = -V.CURVE * r
					b.LightEmission = 1
					b.LightInfluence = 0
					b.Color = ColorSequence.new(Color3.fromHex(V.COLOURS[1]), Color3.fromHex(V.COLOURS[2]))
					-- faint at the far end, brightest where it pours into the mouth
					local sNear = s - 1 / (V.POINTS - 1)
					b.Transparency = NumberSequence.new(
						V.ALPHA[1] + (V.ALPHA[2] - V.ALPHA[1]) * s,
						V.ALPHA[1] + (V.ALPHA[2] - V.ALPHA[1]) * sNear
					)
					b.Enabled = false
					b.Parent = vh
					table.insert(vortex, b)
				end
				prev = a
			end
		end
		-- suction beams from the mouth down to the town (off until the switch)
		local mouthA = Instance.new("Attachment")
		local anchor = part(f, "BeamAnchor", Vector3.new(1, 1, 1), stageCF, OFF)
		anchor.Transparency = 1
		mouthA.WorldPosition = (stageCF * CFrame.new(v3(ST.nozzle))).Position
		mouthA.Parent = anchor
		for k, tgt in { { 0, 4, 0 }, { -40, 6, 10 }, { 40, 6, -10 } } do
			local a1 = Instance.new("Attachment")
			a1.WorldPosition = (stageCF * CFrame.new(v3(tgt))).Position
			a1.Parent = anchor
			local b = Instance.new("Beam")
			b.Attachment0 = mouthA
			b.Attachment1 = a1
			b.FaceCamera = true
			b.Width0 = 6
			b.Width1 = 14 + 4 * k
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Color = ColorSequence.new(WARM, Color3.fromHex("#E8ECFF"))
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.6, 0.88),
				NumberSequenceKeypoint.new(1, 1),
			})
			b.Segments = 12
			b.Enabled = false
			b.Parent = anchor
			table.insert(suction, b)
		end
		local sw = Instance.new("ParticleEmitter")
		sw.Name = "Swirl"
		sw.Rate = 0
		sw.Lifetime = NumberRange.new(1.4, 2.2)
		sw.Speed = NumberRange.new(14, 22)
		sw.SpreadAngle = Vector2.new(35, 35)
		sw.Acceleration = Vector3.new(0, 18, 0)
		sw.Size = NumberSequence.new(0.8, 0.2)
		sw.Color = ColorSequence.new(WARM)
		sw.LightEmission = 1
		sw.Texture = Config.WorldFx.COIN_TEXTURE
		sw.Enabled = false
		sw.Parent = anchor
		swirlEmitter = sw
		-- the lever
		local lever = kitModel("Intro_Lever")
		local lcf = at(ST.lever.at, ST.lever.yaw)
		if lever then
			lever:PivotTo(lcf)
			lever.Parent = f
			leverHandle = partsByName(lever).Intro_Lever_Handle
		else
			part(f, "LeverStandIn", Vector3.new(1.8, 2.8, 1.2), lcf * CFrame.new(0, 1.4, 0), Color3.fromHex("#8C2F4B"))
			local h = part(f, "Handle", Vector3.new(0.2, 2.2, 0.2), lcf * CFrame.new(0, 3.95, 0), Palette.steelHi)
			h.PivotOffset = CFrame.new(0, -1.1, 0)
			leverHandle = h
		end
		if leverHandle then
			leverRest = leverHandle:GetPivot()
		end
		f.Parent = stage
	end

	---------------------------------------------------------------- the aurora (the game's Heist/Aurora, anchored here)
	-- The same northern lights as the town in the game (textured Beam curtains, sway and shimmer, per-tier layers),
	-- anchored to the stage with its landmark direction toward the tower (-Z); the session's own aurora hides while
	-- this one plays (Aurora.solo), and the curtains show at once (no fade-in: the shot opens on them).
	local auroraFolder = Instance.new("Folder")
	auroraFolder.Name = "Aurora"
	auroraFolder.Parent = stage
	local aurora = Aurora.new(auroraFolder, { revealSeconds = 0 })
	aurora.setAnchor(origin, I.AURORA_YAW)
	aurora.setTier(tier)
	aurora.setReducedMotion(reducedFn())
	Aurora.solo(aurora)

	---------------------------------------------------------------- snow (one emitter that follows the camera)
	local snowPart = part(stage, "SnowVolume", Vector3.new(80, 30, 80), stageCF, OFF)
	snowPart.Transparency = 1
	local snow = Instance.new("ParticleEmitter")
	snow.Name = "Snow"
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.Lifetime = NumberRange.new(4, 5)
	snow.Speed = NumberRange.new(2.4, 3.4)
	snow.Size = NumberSequence.new(0.22, 0.3)
	snow.Color = ColorSequence.new(Color3.fromRGB(236, 240, 255))
	snow.LightEmission = 0.2
	snow.LightInfluence = 0.3
	snow.Texture = Config.Backdrop.SNOW.texture
	snow.Enabled = false
	snow.Parent = snowPart
	local snowRate = math.min(I.SNOW_RATE, I.SNOW_MAX / 5)
	Particles.setSteady("introSnow", function(): number
		return if snow.Enabled and snow.Parent then snow.Rate * snow.Lifetime.Max else 0
	end)

	---------------------------------------------------------------- props: Hoardsworth, presents, letter
	local hoard: Rig? = nil
	local monocle: BasePart? = nil
	local ringPart: BasePart? = nil
	local mouthParts: { BasePart } = {}
	local laughShown = false
	local villainLights: Folder? = nil

	-- His light on the terrace (STAGE.villainLights, Config.Intro.VILLAIN_LIGHTS): built with him, gone with him.
	local function buildVillainLights()
		local f = Instance.new("Folder")
		f.Name = "VillainLights"
		for _, l in ST.villainLights do
			local spec = I.VILLAIN_LIGHTS[l.kind]
			local host =
				part(f, "VillainLight", Vector3.new(0.3, 0.3, 0.3), stageCF * CFrame.lookAt(v3(l.from), v3(l.to)), OFF)
			host.Transparency = 1
			host.CastShadow = false
			local sp = Instance.new("SpotLight")
			sp.Face = Enum.NormalId.Front
			sp.Brightness = spec.BRIGHTNESS
			sp.Range = spec.RANGE
			sp.Angle = spec.ANGLE
			sp.Color = Color3.fromHex(spec.COLOUR)
			sp.Shadows = false
			sp.Parent = host
		end
		f.Parent = stage
		villainLights = f
	end
	local presents: { BasePart } = {}
	local letter: BasePart? = nil
	local nPresents = I.PRESENTS[tier] or 6

	local function presentPart(k: number): BasePart
		local name = "Intro_Present_" .. string.sub("ABC", (k - 1) % 3 + 1, (k - 1) % 3 + 1)
		local m = kitModel(name)
		local mp = if m then m:FindFirstChildWhichIsA("BasePart", true) else nil
		local p: BasePart
		if m and mp then
			mp.Parent = nil
			m:Destroy()
			mp.Size *= 2.2
			p = mp
		else
			local colors = { Color3.fromHex("#8C2F4B"), Color3.fromHex("#2FBF71"), Color3.fromHex("#C0C3D5") }
			p = part(stage, "Present", Vector3.new(5, 5, 5), stageCF, colors[(k - 1) % 3 + 1])
		end
		quiet(p, false)
		p.Name = "FlyingPresent"
		return p
	end

	---------------------------------------------------------------- the garage, the van, the Rookie, the clones
	local headlightParts: { BasePart } = {}
	local headlightLights: { Light } = {}
	local headBeams: { Beam } = {}
	local rookie: Rig? = nil
	local rookieModel: Model? = nil
	local rookieMotors: { Motor6D } = {}
	local cloneMotors: { { Motor6D } } = {}
	local rookieFace = ""
	type Clone = {
		rig: Rig?,
		model: Model,
		parts: { BasePart },
		heights: { number },
		height: number,
		shown: number,
		band: BasePart,
		glow: SurfaceGui,
		ring: Frame,
	}
	local clones: { Clone } = {}
	local crewHighlight: Highlight? = nil
	local cloneFace = ""
	local garageFolder: Folder? = nil

	-- A clone's crew hue as EchoView picks it for your own solo runs: older runs drift toward violet and are dimmer.
	local function cloneHue(rank: number, count: number): Color3
		local hue = Palette.hueFor(1)
		local h, sat, val = hue:ToHSV()
		hue = Color3.fromHSV(CloneState.driftHue(h, rank, count, true), sat, val)
		return Palette.dim(hue, math.max(1 - Config.Heist.CLONE_AGE_DIM * rank, 0.35))
	end

	local function rookieTemplate(): Model?
		local kitFolder = ReplicatedStorage:FindFirstChild(I.CHARACTER_KIT)
		local m = kitFolder and kitFolder:FindFirstChild(I.ROOKIE_TEMPLATE)
		return if m and m:IsA("Model") then m else nil
	end

	-- A copy of the CharacterKit Rookie for the stage: the root anchored, the body parts held by their R15 Motor6Ds
	-- (so Motor6D.Transform poses them with the IntroPlan joint angles), nothing collides, is queried or scripted,
	-- no name tag. hue: a clone's crew hue (only the crew pieces, EH_Tint "crew", take it, as Heist/Rigs tints
	-- clone rigs; clones cast no shadow), else the template's own look. Returns its motors.
	local function prepRookie(m: Model, hue: Color3?): { Motor6D }
		local motors: { Motor6D } = {}
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				quiet(d, hue == nil)
				d.Anchored = d.Name == "HumanoidRootPart"
				if hue and d:GetAttribute("EH_Tint") == "crew" then
					d.Color = hue
				end
			elseif d:IsA("Motor6D") then
				table.insert(motors, d)
			elseif d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			elseif d:IsA("Humanoid") then
				d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				d.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
			end
		end
		return motors
	end

	-- The kit Rookie's face (the CH track's EH_Face pieces: one mood shows), as server Heist/Rookie.setFace does.
	local function setRookieFace(m: Model, mood: string)
		local has = false
		for _, d in m:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("EH_Face") == mood then
				has = true
			end
		end
		local show = if has then mood else "idle"
		for _, d in m:GetChildren() do
			local fm = d:GetAttribute("EH_Face")
			if fm ~= nil and d:IsA("BasePart") then
				d.Transparency = if fm == show then 0 else 1
			end
		end
	end

	local function poseMotors(motors: { Motor6D }, a: string, b: string, w: number)
		for _, mo in motors do
			local x, y, z = IntroPlan.joint(a, b, w, mo.Name)
			mo.Transform = CFrame.fromEulerAnglesYXZ(rad(x), rad(y), rad(z))
		end
	end

	local function placeOnFloor(m: Model, cf: CFrame)
		m:PivotTo(cf)
		local bb, size = m:GetBoundingBox()
		local bottom = bb.Position.Y - size.Y / 2
		m:PivotTo(cf * CFrame.new(0, cf.Position.Y - bottom, 0))
	end

	local function garageBuild()
		if garageFolder then
			return
		end
		local f = Instance.new("Folder")
		f.Name = "Garage"
		garageFolder = f
		local g = ST.garage
		local c, size = g.centre, g.size
		local gcf = stageCF * CFrame.new(c[1], 0, c[3])
		local w, h, dep = size[1], size[2], size[3]
		local brick, brickHi = Color3.fromHex("#573429"), Color3.fromHex("#704B3E")
		boxLH(
			f,
			"Floor",
			gcf,
			Vector3.new(-w / 2, -0.1, -dep / 2),
			Vector3.new(w / 2, 0.05, dep / 2 + 2),
			Palette.floor
		)
		boxLH(f, "Back", gcf, Vector3.new(-w / 2, 0, -dep / 2 - 1), Vector3.new(w / 2, h, -dep / 2), brick)
		boxLH(f, "Left", gcf, Vector3.new(-w / 2 - 1, 0, -dep / 2 - 1), Vector3.new(-w / 2, h, dep / 2), brick)
		boxLH(f, "Right", gcf, Vector3.new(w / 2, 0, -dep / 2 - 1), Vector3.new(w / 2 + 1, h, dep / 2), brick)
		boxLH(
			f,
			"Roof",
			gcf,
			Vector3.new(-w / 2 - 1.5, h, -dep / 2 - 1.5),
			Vector3.new(w / 2 + 1.5, h + 1.2, dep / 2 + 1.5),
			Palette.inkHi
		)
		boxLH(
			f,
			"Header",
			gcf,
			Vector3.new(-w / 2 - 1, h - 2.5, dep / 2 - 1),
			Vector3.new(w / 2 + 1, h, dep / 2),
			brickHi
		)
		boxLH(
			f,
			"RoofSnow",
			gcf,
			Vector3.new(-w / 2 - 1.6, h + 1.2, -dep / 2 - 1.6),
			Vector3.new(w / 2 + 1.6, h + 1.7, dep / 2 + 1.6),
			Palette.snow
		)
		boxLH(
			f,
			"Bench",
			gcf,
			Vector3.new(-w / 2 + 2, 0, -dep / 2),
			Vector3.new(-w / 2 + 10, 3.2, -dep / 2 + 2.4),
			Color3.fromHex("#7B5244")
		)
		boxLH(
			f,
			"Peg",
			gcf,
			Vector3.new(-w / 2 + 2, 4.5, -dep / 2),
			Vector3.new(-w / 2 + 10, 9, -dep / 2 + 0.3),
			Color3.fromHex("#633F32")
		)
		local van = kitModel("Van")
		local vcf = at(ST.van.at, ST.van.yaw)
		if van then
			van:PivotTo(vcf)
			for _, p in van:GetDescendants() do
				if p:IsA("BasePart") and p.Name == "Van_Paint" then
					p.Color = Color3.fromHex("#8C6448")
				end
			end
			van.Parent = f
		else
			part(f, "VanStandIn", Vector3.new(6.8, 7.6, 14.9), vcf * CFrame.new(0, 3.9, 0), Color3.fromHex("#8C6448"))
		end
		local anchor = part(f, "LightAnchor", Vector3.new(1, 1, 1), stageCF, OFF)
		anchor.Transparency = 1
		-- The motivated light (REVIEW_STEAM_PLUS #7; IntroPlan.STAGE + Config.Intro.GARAGE): warm practicals inside,
		-- the aurora's cool light from outside. The aurora and the string lights are on from the first frame (the
		-- garage is never black); the headlights, the work lamp and the cage lamp snap on with IntroHeadlights.
		local GL = I.GARAGE
		local shadows = tier <= GL.SHADOWS_TIER
		local function beam(
			name: string,
			p0: { number },
			p1: { number },
			w0: number,
			w1: number,
			alpha: number,
			colour: string
		): Beam
			local a0 = Instance.new("Attachment")
			a0.Name = name .. "0"
			a0.WorldPosition = (stageCF * CFrame.new(p0[1], p0[2], p0[3])).Position
			a0.Parent = anchor
			local a1 = Instance.new("Attachment")
			a1.Name = name .. "1"
			a1.WorldPosition = (stageCF * CFrame.new(p1[1], p1[2], p1[3])).Position
			a1.Parent = anchor
			local b = Instance.new("Beam")
			b.Name = name
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.FaceCamera = true
			b.Width0 = w0
			b.Width1 = w1
			b.Segments = 1
			b.LightEmission = 1
			b.LightInfluence = 0
			b.Color = ColorSequence.new(Color3.fromHex(colour))
			b.Transparency = NumberSequence.new(alpha, 1)
			b.Parent = anchor
			return b
		end
		local function light(className: string, host: BasePart, spec: any, face: Enum.NormalId?, on: boolean): Light
			local l = Instance.new(className) :: any
			l.Brightness = spec.BRIGHTNESS
			l.Range = spec.RANGE
			l.Color = Color3.fromHex(spec.COLOUR)
			if spec.ANGLE and className ~= "PointLight" then
				l.Angle = spec.ANGLE
			end
			if face then
				l.Face = face
			end
			l.Shadows = false
			l.Enabled = on
			l.Parent = host
			return l
		end
		-- the aurora through the open roll-up door: a SurfaceLight on an invisible panel, facing in (-Z)
		local dg = ST.doorGlow
		local glowPanel = part(f, "DoorGlow", Vector3.new(dg.size[1], dg.size[2], 0.2), at(dg.centre), OFF)
		glowPanel.Transparency = 1
		light("SurfaceLight", glowPanel, GL.DOOR_GLOW, Enum.NormalId.Front, true)
		-- three high windows in the back wall, glowing with the aurora (green below, violet above), their shafts
		-- falling over the van; the first one also throws the cool rim at the Rookie's cap and shoulder
		local ww, wh = ST.windowSize[1], ST.windowSize[2]
		for k, wp in ST.windows do
			local low = part(
				f,
				"WindowPane",
				Vector3.new(ww, wh / 2, 0.12),
				at({ wp[1], wp[2] - wh / 4, wp[3] }),
				Color3.fromHex(GL.WINDOW_COLOURS[1]),
				Enum.Material.Neon
			)
			low.Transparency = 0.15
			local high = part(
				f,
				"WindowPane",
				Vector3.new(ww, wh / 2, 0.12),
				at({ wp[1], wp[2] + wh / 4, wp[3] }),
				Color3.fromHex(GL.WINDOW_COLOURS[2]),
				Enum.Material.Neon
			)
			high.Transparency = 0.15
			part(f, "WindowBar", Vector3.new(0.3, wh + 0.4, 0.3), at({ wp[1], wp[2], wp[3] + 0.1 }), Palette.inkHi)
			if tier <= GL.SHAFT.TIERS then
				local S = GL.SHAFT
				local d = S.LENGTH / math.sqrt(2)
				beam(
					"Shaft" .. k,
					{ wp[1], wp[2], wp[3] + 0.3 },
					{ wp[1], wp[2] - d, wp[3] + d },
					S.WIDTH[1],
					S.WIDTH[2],
					S.TRANSPARENCY,
					GL.WINDOW_COLOURS[1]
				)
			end
		end
		local rimHost = part(
			f,
			"RimLight",
			Vector3.new(0.4, 0.4, 0.4),
			stageCF * CFrame.lookAt(v3(ST.rim.from), v3(ST.rim.to)),
			OFF
		)
		rimHost.Transparency = 1
		light("SpotLight", rimHost, GL.RIM, Enum.NormalId.Front, true)
		-- warm string lights along both side walls (tiers 1-3), sagging between the hooks
		if tier <= GL.STRING.TIERS then
			local SL = GL.STRING
			for run = 1, #ST.strings, 2 do
				local p0, p1 = ST.strings[run], ST.strings[run + 1]
				local len = math.abs(p1[3] - p0[3])
				local n = math.max(2, math.floor(len / SL.SPACING) + 1)
				for k = 0, n - 1 do
					local u = k / (n - 1)
					local sag = SL.SAG * 4 * u * (1 - u)
					local bulb = part(
						f,
						"StringBulb",
						Vector3.new(0.3, 0.3, 0.3),
						at({ p0[1], p0[2] - sag, p0[3] + (p1[3] - p0[3]) * u }),
						Color3.fromHex(SL.COLOUR),
						Enum.Material.Neon
					)
					bulb.Shape = Enum.PartType.Ball
				end
			end
		end
		-- the work lamp over the van's roof: a shade, the bulb, a SpotLight down and its faint light cone
		local wl = ST.workLamp
		part(f, "LampCord", Vector3.new(0.08, 14 - wl[2], 0.08), at({ wl[1], (14 + wl[2]) / 2, wl[3] }), Palette.inkHi)
		local shade =
			part(f, "LampShade", Vector3.new(0.5, 2.2, 2.2), at(wl) * CFrame.Angles(0, 0, math.pi / 2), Palette.steel)
		shade.Shape = Enum.PartType.Cylinder
		local bulb =
			part(f, "WorkLamp", Vector3.new(0.6, 0.6, 0.6), at({ wl[1], wl[2] - 0.35, wl[3] }), OFF, Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		local workLight = light("SpotLight", bulb, GL.WORK_LAMP, Enum.NormalId.Bottom, false)
		workLight.Shadows = shadows
		table.insert(headlightLights, workLight)
		table.insert(headlightParts, bulb)
		if tier <= GL.BEAM.TIERS then
			local cone = beam(
				"LampCone",
				{ wl[1], wl[2] - 0.5, wl[3] },
				{ wl[1], 7.8, wl[3] },
				1.6,
				7,
				GL.WORK_LAMP.CONE_TRANSPARENCY,
				GL.WORK_LAMP.COLOUR
			)
			cone.Enabled = false
			table.insert(headBeams, cone)
		end
		-- a warm lamp over the workbench (always on: the crew's practical)
		local bench = part(
			f,
			"BenchLamp",
			Vector3.new(0.4, 0.4, 0.4),
			at(ST.benchLamp),
			Color3.fromHex(GL.BENCH_LAMP.COLOUR),
			Enum.Material.Neon
		)
		bench.Shape = Enum.PartType.Ball
		light("PointLight", bench, GL.BENCH_LAMP, nil, true)
		-- the cage lamp under the door header: tops the Rookie (comes on with the headlights)
		local dl = ST.doorLamp
		local cage = part(f, "DoorLamp", Vector3.new(0.5, 0.5, 0.5), at(dl), OFF, Enum.Material.Neon)
		cage.Shape = Enum.PartType.Ball
		table.insert(headlightParts, cage)
		table.insert(headlightLights, light("SpotLight", cage, GL.DOOR_LAMP, Enum.NormalId.Bottom, false))
		-- the headlights: lenses, SpotLights out of the door, and their layered beams dropping to the floor
		local HL, BM = GL.HEADLIGHT, GL.BEAM
		for _, hp in ST.headlights do
			local lens = part(
				f,
				"Headlight",
				Vector3.new(0.25, 1.1, 1.1),
				at(hp) * CFrame.Angles(0, rad(90), 0),
				OFF,
				Enum.Material.Neon
			)
			lens.Shape = Enum.PartType.Cylinder
			table.insert(headlightParts, lens)
			-- the cylinder's axis is X; turned 90 deg: -X faces +Z (out of the garage)
			local sp = light("SpotLight", lens, HL, Enum.NormalId.Left, false)
			sp.Shadows = shadows
			table.insert(headlightLights, sp)
			if tier <= BM.TIERS then
				for k, layer in BM.LAYERS do
					local b = beam(
						"HeadBeam" .. k,
						{ hp[1], hp[2], hp[3] + 0.3 },
						{ hp[1], hp[2] - BM.DROP, hp[3] + BM.LENGTH },
						layer[1],
						layer[2],
						layer[3],
						HL.COLOUR
					)
					b.Enabled = false
					table.insert(headBeams, b)
				end
			end
		end
		-- the Rookie: the CHARACTER track's template (ReplicatedStorage.CharacterKit.Rookie, R15, posed through its
		-- Motor6Ds); the Part stand-in only if the kit never arrived
		local rk = ST.rookie
		local tpl = rookieTemplate()
		if tpl then
			local m = tpl:Clone()
			m.Name = "Rookie"
			rookieMotors = prepRookie(m, nil)
			placeOnFloor(m, at(rk.at, rk.yaw))
			m.Parent = f
			rookieModel = m
			setRookieFace(m, "idle")
		else
			rookie = buildStandIn(f, "RookieStandIn", nil)
		end
		-- The clones: copies of the Rookie drawn the way EchoView draws your clones (PLAN_STEAM_PLUS §4.4 A2): the
		-- outfit kept, only the crew pieces in your hue (older runs dimmer and drifting toward violet, as solo
		-- runs do), one crew-hue Highlight over the group (fill + outline), a floor glow under each, and the tape
		-- print: each builds up from the feet under a rising scan band while its floor ring settles.
		local crew = Instance.new("Model")
		crew.Name = "Crew"
		local seatHue = Palette.hueFor(1)
		local hl = Instance.new("Highlight")
		hl.FillColor = seatHue
		hl.OutlineColor = seatHue
		hl.FillTransparency = Config.Heist.CLONE_FILL_TRANSPARENCY
		hl.OutlineTransparency = 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Enabled = false
		hl.Adornee = crew
		hl.Parent = crew
		crewHighlight = hl
		local n = #ST.clones
		for k, cp in ST.clones do
			local hue = cloneHue(n - k, n) -- clone 1 is the oldest run
			local m: Model
			local rig: Rig? = nil
			if tpl then
				m = tpl:Clone()
				m.Name = "Clone" .. k
				cloneMotors[k] = prepRookie(m, hue)
				placeOnFloor(m, at(cp, rk.yaw + (if cp[1] < 130 then 8 else -8)))
				m.Parent = crew
				setRookieFace(m, "idle")
			else
				rig = buildStandIn(crew, "Clone" .. k, hue)
				m = (rig :: Rig).model
			end
			-- rest heights over the feet (the print shows a part once the band passes its bottom)
			local feetY = at(cp).Position.Y
			local parts, heights, top = {}, {}, 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(parts, d)
					local bottom = d.Position.Y - d.Size.Y / 2 - feetY
					heights[#parts] = bottom
					if d.Transparency < 1 then
						top = math.max(top, bottom + d.Size.Y)
					end
					d.LocalTransparencyModifier = 1
				end
			end
			local band = part(f, "PrintBand", Vector3.new(0.12, 3.2, 3.2), at(cp), hue, Enum.Material.Neon)
			band.Shape = Enum.PartType.Cylinder
			band.Transparency = 1
			local glowPart, glowGui, glowRing =
				PlayerHalo.disc("FloorGlow", C.GLOW_SIZE, hue, C.GLOW_ALPHA, C.GLOW_RING_ALPHA, C.GLOW_DISC)
			glowPart.Massless = true
			glowPart.CFrame = at(cp) * CFrame.new(0, 0.06, 0)
			glowGui.Enabled = false
			glowPart.Parent = f
			table.insert(clones, {
				rig = rig,
				model = m,
				parts = parts,
				heights = heights,
				height = if top > 0 then top else 4.6,
				shown = -2,
				band = band,
				glow = glowGui,
				ring = glowRing,
			})
		end
		crew.Parent = f
		f.Parent = stage
	end

	---------------------------------------------------------------- the UI: fade, bars, caption, flash, wordmark, SKIP
	local gui = Instance.new("ScreenGui")
	gui.Name = "EH_Intro"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = Config.Presentation.TITLE.ORDER + 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local function frame(name: string, color: Color3, z: number): Frame
		local fr = Instance.new("Frame")
		fr.Name = name
		fr.BorderSizePixel = 0
		fr.BackgroundColor3 = color
		fr.ZIndex = z
		fr.Parent = gui
		return fr
	end
	local barH = if reducedFn() then 0 else I.CAPTION.BAR
	local barTop = frame("BarTop", Palette.ink, 2)
	barTop.Size = UDim2.fromScale(1, barH)
	local barBottom = frame("BarBottom", Palette.ink, 2)
	barBottom.AnchorPoint = Vector2.new(0, 1)
	barBottom.Position = UDim2.fromScale(0, 1)
	barBottom.Size = UDim2.fromScale(1, barH)
	local fade = frame("Fade", Palette.ink, 6)
	fade.Size = UDim2.fromScale(1, 1)
	local flash = frame("Flash", Palette.white, 5)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1
	local caption = Ui.display(gui, {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, I.CAPTION.Y),
		Size = UDim2.fromScale(0.9, 0.13),
		Text = "",
		TextTransparency = 1,
		ZIndex = 4,
	})
	Ui.fit(caption, I.CAPTION.SIZE, I.CAPTION.MIN_SIZE)
	local capScale = Instance.new("UIScale")
	capScale.Parent = caption
	local capStroke = caption:FindFirstChildOfClass("UIStroke")
	local wordmark: any = nil
	local markScale: UIScale? = nil
	local skipBtn = Ui.button(gui, {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -I.SKIP.MARGIN, 0, I.SKIP.MARGIN),
		Size = UDim2.fromOffset(I.SKIP.SIZE[1], I.SKIP.SIZE[2]),
		Text = Strings.SKIP,
		BackgroundColor3 = Theme.COLOR.panelTop,
		TextColor3 = Palette.white,
		ZIndex = 8,
	}, function()
		cine.skip()
	end)
	HudCommon.keyCap(skipBtn, "skipIntro") -- any key (Space shown) or B / Start
	gui.Parent = o.gui or (Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")) or stage

	local function showWordmark()
		if wordmark then
			return
		end
		local Wordmark = require(ReplicatedFirst:WaitForChild("Wordmark")) :: any
		local holder = Instance.new("Frame")
		holder.Name = "Title"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromOffset(900, 220)
		holder.ZIndex = 7
		holder.Parent = gui
		local sc = Instance.new("UIScale")
		sc.Parent = holder
		markScale = sc
		wordmark = Wordmark.build(holder, { size = 110, width = 900, copies = 3, strap = true })
		local veil = frame("TitleVeil", Palette.ink, 3)
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundTransparency = I.TITLE_VEIL
	end

	---------------------------------------------------------------- events
	local loops: { [string]: () -> () } = {}
	local flashAt = -math.huge
	local function applyMood(name: string)
		local m = IntroPlan.MOODS[name]
		if not m then
			return
		end
		Lighting.Ambient = Color3.fromRGB(m.ambient[1], m.ambient[2], m.ambient[3])
		Lighting.OutdoorAmbient = Color3.fromRGB(m.outdoor[1], m.outdoor[2], m.outdoor[3])
		Lighting.Brightness = m.brightness
		Lighting.ExposureCompensation = m.exposure
		grade.TintColor = Color3.fromRGB(m.tint[1], m.tint[2], m.tint[3])
	end

	local function setVacuum(on: boolean)
		if vacuumLights then
			vacuumLights.Color = if on then WARM else OFF
		end
		for _, b in suction do
			b.Enabled = on
		end
		for _, b in vortex do
			b.Enabled = on
		end
		if swirlEmitter then
			swirlEmitter.Enabled = false -- bursts only (Particles budget)
		end
	end

	local function setHeadlights(on: boolean)
		for _, p in headlightParts do
			p.Color = if on then Color3.fromHex("#FFF4E0") else OFF
		end
		for _, l in headlightLights do
			l.Enabled = on
		end
		for _, b in headBeams do
			b.Enabled = on
		end
	end

	-- A star glint on a part (the monocle, the ring): a burst through Heist/Particles (its budget may grant fewer).
	local function glint(p: BasePart, size: number, n: number)
		pcall(function()
			local em = Instance.new("ParticleEmitter")
			em.Texture = Config.WorldFx.COIN_TEXTURE
			em.Lifetime = NumberRange.new(0.4)
			em.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.3, size),
				NumberSequenceKeypoint.new(1, 0),
			})
			em.Speed = NumberRange.new(0)
			em.LightEmission = 1
			em.Rate = 0
			em.Parent = p
			Particles.emit(em, n)
		end)
	end

	local function apply(e: any)
		local kind = e.kind
		if kind == "shot" then
			local shot = IntroPlan.SHOTS[e.arg]
			applyMood(shot.mood)
		elseif kind == "spawn" then
			if e.id == "hoardsworth" and not hoard then
				local r, mono, ring, mouth = buildHoardsworth(stage)
				hoard, monocle, ringPart, mouthParts = r, mono, ring, mouth
				laughShown = false
				buildVillainLights()
			elseif e.id == "presents" then
				for k = 1, nPresents do
					local p = presentPart(k)
					p.Parent = stage
					presents[k] = p
				end
			elseif e.id == "letter" then
				local m = kitModel("Intro_Letter")
				local lp = if m then m:FindFirstChildWhichIsA("BasePart", true) else nil
				local p: BasePart
				if m and lp then
					p = lp
					p.Parent = stage
					p.Size *= IntroPlan.LETTER_SCALE
					m:Destroy()
				else
					p = part(stage, "Letter", Vector3.new(2.4, 1.6, 0.1), stageCF, Palette.marbleHi)
				end
				letter = p
			elseif e.id == "garage" then
				garageBuild()
			end
		elseif kind == "despawn" then
			if e.id == "hoardsworth" and hoard then
				hoard.model:Destroy()
				hoard = nil
				mouthParts = {}
				if villainLights then
					villainLights:Destroy()
					villainLights = nil
				end
			elseif e.id == "presents" then
				for _, p in presents do
					p:Destroy()
				end
				table.clear(presents)
			elseif e.id == "letter" and letter then
				letter:Destroy()
				letter = nil
			elseif e.id == "garage" and garageFolder then
				garageFolder:Destroy()
				garageFolder = nil
			elseif e.id == "town" then
				local town = stage:FindFirstChild("Town")
				if town then
					town:Destroy()
				end
			end
		elseif kind == "fx" then
			local on = not e.stop
			if e.id == "aurora" then
				aurora.setVisible(on)
			elseif e.id == "snow" then
				snow.Enabled = on
				snow.Rate = snowRate * (if reducedFn() then 0.5 else 1)
			elseif e.id == "vacuum" then
				setVacuum(on)
			elseif e.id == "windowsOut" and on then
				for _, w in windows do
					if w.Parent then
						w.Color = OFF
					end
				end
				for _, l in townLights do
					l.Enabled = false
				end
			elseif e.id == "headlights" then
				setHeadlights(on)
			elseif e.id == "flash" and on then
				if not reducedFn() and FlashLimit.allow(os.clock()) then
					flashAt = st.t
				end
			elseif e.id == "title" then
				if on then
					showWordmark()
				end
			elseif e.id == "glint" and monocle then
				glint(monocle, I.MONOCLE_GLINT.SIZE, I.MONOCLE_GLINT.COUNT)
			elseif e.id == "ring" and ringPart then
				glint(ringPart, I.RING.GLINT.SIZE, I.RING.GLINT.COUNT)
			end
		elseif kind == "cue" then
			if e.stop then
				local stop = loops[e.cue]
				if stop then
					stop()
					loops[e.cue] = nil
				end
				Sound.stopCue(e.cue)
			else
				local stop = Sound.play(e.cue, if e.step then { step = e.step } else nil)
				if IntroPlan.LOOPS[e.cue] then
					loops[e.cue] = stop
				end
			end
		end -- "end": run() calls finish()
	end

	---------------------------------------------------------------- per frame
	local partsBuf: { BasePart } = {}
	local cfBuf: { CFrame } = {}
	local nextSwirl = 0
	local lastDrawT = 0
	local function draw()
		local t = st.t
		local reduced = reducedFn()
		-- camera
		local pos, look, fov, whip = IntroPlan.camera(t, reduced)
		local cf = stageCF * CFrame.lookAt(v3(pos), v3(look))
		local shakeOn = Settings.get("shake") ~= false
		local amp = if shakeOn then IntroPlan.shake(t, reduced) else 0
		if amp > 0 then
			local f = I.SHAKE.FREQ
			cf *= CFrame.new(math.noise(t * f, 0.3) * amp, math.noise(0.7, t * f) * amp, 0)
		end
		if camera then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cf
			camera.FieldOfView = fov
		end
		blur.Size = if reduced then 0 else I.WHIP_BLUR * whip
		aurora.step(os.clock(), cf.Position)
		-- the suction vortex turns while the vacuum runs (slower under reduced motion)
		local dt = math.clamp(t - lastDrawT, 0, 0.1)
		lastDrawT = t
		if vortexHolder and st.fx.vacuum then
			vortexSpin += dt * I.VORTEX.SPIN * (if reduced then Config.Aurora.REDUCED_MOTION else 1)
			vortexHolder.CFrame = vortexBase * CFrame.Angles(0, 0, vortexSpin)
		end
		snowPart.CFrame = cf * CFrame.new(0, 6, -30)
		-- fade in, flash
		fade.BackgroundTransparency = math.clamp(t / I.FADE_IN, 0, 1)
		local fs = (t - flashAt) / I.FLASH_SECONDS
		flash.BackgroundTransparency = if fs >= 0 and fs < 1 then 0.25 + 0.75 * fs else 1
		-- caption
		local key, alpha, punch, isMark = IntroPlan.caption(t)
		if key and not isMark then
			caption.Text = Strings.INTRO[key] or ""
			caption.TextTransparency = 1 - alpha
			if capStroke then
				capStroke.Transparency = 1 - alpha
			end
			capScale.Scale = if reduced then 1 else punch
		else
			caption.TextTransparency = 1
			if capStroke then
				capStroke.Transparency = 1
			end
		end
		if isMark and wordmark then
			local sc = markScale :: UIScale
			sc.Scale = if reduced then 1 else 0.75 + 0.25 * punch * punch
			local since = t - IntroPlan.startOf(#IntroPlan.SHOTS)
			for k, c in wordmark.copies do
				local s = math.clamp((since - 0.35 - 0.12 * k) / 0.3, 0, 1)
				local step = Config.Presentation.TITLE.STEP
				c.Position = UDim2.fromOffset(wordmark.offset.X + k * step[1] * s, wordmark.offset.Y + k * step[2] * s)
				c.TextTransparency = if k == 1 then 0 else 1 - s
				local cs = c:FindFirstChildOfClass("UIStroke")
				if cs then
					cs.Transparency = c.TextTransparency
				end
			end
		end
		local showBars = not isMark
		barTop.Visible = showBars
		barBottom.Visible = showBars
		-- actors
		table.clear(partsBuf)
		table.clear(cfBuf)
		if hoard then
			local a, b, w = IntroPlan.pose("hoardsworth", t)
			poseRig(hoard, at(ST.hoardsworth.at, ST.hoardsworth.yaw), a, b, w, partsBuf, cfBuf)
			local laughing = IntroPlan.laughing(t)
			if laughing ~= laughShown then
				laughShown = laughing
				for _, p in mouthParts do
					p.Transparency = if laughing then 0 else 1
				end
			end
			if leverHandle then
				local ang = IntroPlan.leverAngle(t)
				table.insert(partsBuf, leverHandle)
				table.insert(cfBuf, leverRest * CFrame.Angles(rad(ang), 0, 0) * leverHandle.PivotOffset:Inverse())
			end
		end
		if rookie then
			local a, b, w = IntroPlan.pose("rookie", t)
			poseRig(rookie, at(ST.rookie.at, ST.rookie.yaw), a, b, w, partsBuf, cfBuf)
		elseif rookieModel then
			local a, b, w = IntroPlan.pose("rookie", t)
			poseMotors(rookieMotors, a, b, w)
			local mood = IntroPlan.rookieFace(t)
			if mood ~= rookieFace then
				rookieFace = mood
				setRookieFace(rookieModel, mood)
			end
		end
		local anyPrinted = false
		local ra, rb, rw = IntroPlan.pose("rookie", t)
		local face = IntroPlan.rookieFace(t)
		for k, c in clones do
			local pr = IntroPlan.clonePrint(k, t)
			if c.rig then
				local cp = ST.clones[k]
				poseRig(
					c.rig,
					at(cp, ST.rookie.yaw + (if cp[1] < 130 then 8 else -8)),
					"stand",
					"stand",
					0,
					partsBuf,
					cfBuf
				)
			elseif cloneMotors[k] then -- copies of me: they strike the Rookie's pose and pull his face
				poseMotors(cloneMotors[k], ra, rb, rw)
				if face ~= cloneFace then
					setRookieFace(c.model, face)
				end
			end
			-- the tape print (EchoView): parts appear from the feet up; reduced motion shows the whole clone at once
			local printing = pr > 0 and pr < 1 and not reduced
			local h = if pr <= 0 then -1 elseif printing then pr * c.height else math.huge
			if h ~= c.shown then
				local last = c.shown
				c.shown = h
				for i, p in c.parts do
					local show = c.heights[i] <= h
					if last == -2 or (c.heights[i] <= last) ~= show then
						p.LocalTransparencyModifier = if show then 0 else 1
					end
				end
			end
			anyPrinted = anyPrinted or pr > 0
			c.band.Transparency = if printing then C.PRINT_BAND_ALPHA + (1 - C.PRINT_BAND_ALPHA) * pr else 1
			c.band.CFrame = at(ST.clones[k])
				* CFrame.new(0, math.min(h, c.height), 0)
				* CFrame.Angles(0, 0, math.pi / 2)
			c.glow.Enabled = pr > 0
			local ring = if printing then C.PRINT_RING_FROM + (1 - C.PRINT_RING_FROM) * pr else C.GLOW_DISC
			c.ring.Size = UDim2.fromScale(ring, ring)
			local stroke = c.ring:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = if printing then pr else C.GLOW_RING_ALPHA
			end
		end
		cloneFace = face
		if crewHighlight then
			crewHighlight.Enabled = anyPrinted
		end
		for k, p in presents do
			local pp, spin, alive = IntroPlan.present(k, #presents, t)
			p.Transparency = if alive then 0 else 1
			table.insert(partsBuf, p)
			table.insert(cfBuf, stageCF * CFrame.new(v3(pp)) * CFrame.Angles(spin, spin * 0.7, 0))
		end
		if letter then
			local lp, tilt, vis = IntroPlan.letter(t)
			letter.Transparency = if vis then 0 else 1
			table.insert(partsBuf, letter)
			table.insert(cfBuf, stageCF * CFrame.new(v3(lp)) * CFrame.Angles(0.5 + tilt, rad(200), tilt * 0.5))
		end
		if #partsBuf > 0 then
			workspace:BulkMoveTo(partsBuf, cfBuf, Enum.BulkMoveMode.FireCFrameChanged)
		end
		-- the globe fills
		if pile then
			local fill = IntroPlan.globeFill(t)
			pile.Size = Vector3.new(pileSize.X, pileSize.Y * fill, pileSize.Z)
			pile.PivotOffset = CFrame.new(pileOffset.X, pileOffset.Y * fill, pileOffset.Z)
			pile:PivotTo(pilePivot)
			if globeLight then
				globeLight.Brightness = 1 + 2 * fill
			end
		end
		-- sparkle bursts along the swirl while the vacuum runs
		if st.fx.vacuum and swirlEmitter and t >= nextSwirl then
			nextSwirl = t + 0.3
			local L = ST.launch
			local spot = L[math.floor(t * 3) % #L + 1]
			local holder = swirlEmitter.Parent :: BasePart
			holder.CFrame = stageCF * CFrame.new(v3(spot))
			Particles.emit(swirlEmitter, math.floor(I.SWIRL_PARTICLES / 4))
		end
	end

	---------------------------------------------------------------- lifecycle
	local function restore()
		if camera then
			camera.CameraType = saved.type
			camera.CameraSubject = saved.subject
			camera.FieldOfView = saved.fov
			if saved.type == Enum.CameraType.Scriptable then
				camera.CFrame = saved.cf
			end
		end
		for k, v in saved.lighting do
			(Lighting :: any)[k] = v
		end
		if sky and saved.skyYaw then
			sky.SkyboxOrientation = saved.skyYaw
		end
		grade:Destroy()
		blur:Destroy()
		Aurora.release(aurora) -- the session's aurora shows again
		aurora.destroy()
		Particles.setSteady("introSnow", nil)
		if o.director then
			o.director.resume("intro")
		end
	end

	local function finish(how: string)
		if ended then
			return
		end
		ended = true
		for cue, stop in loops do
			stop()
			Sound.stopCue(cue)
		end
		table.clear(loops)
		if onEnd then
			task.spawn(onEnd, how)
		end
	end

	local function run(events: { any })
		for _, e in events do
			apply(e)
			if e.kind == "end" then
				finish(if st.skipped then "skipped" else "finished")
			end
		end
	end

	function cine.step(dt: number)
		if destroyed or st.done then
			return
		end
		run(IntroPlan.advance(st, dt))
		if not st.done then
			draw()
		end
	end

	function cine.skip()
		if destroyed or st.done then
			return
		end
		run(IntroPlan.skip(st))
	end

	function cine.isDone(): boolean
		return st.done
	end

	function cine.t(): number
		return st.t
	end

	function cine.state(): any
		return IntroPlan.summary(st)
	end

	function cine.stage(): Model
		return stage
	end

	function cine.gui(): ScreenGui
		return gui
	end

	function cine.rookieKind(): string
		return if rookieModel then "characterKit" elseif rookie then "standin" else "none"
	end

	function cine.hoardKind(): string
		return if hoard then hoard.kind else "none"
	end

	function cine.counts(): any
		return { presents = #presents, windows = #windows, clones = #clones, letter = letter ~= nil }
	end

	function cine.destroy()
		if destroyed then
			return
		end
		if not st.done then
			cine.skip()
		end
		destroyed = true
		restore()
		gui:Destroy()
		stage:Destroy()
		if playing == cine then
			playing = nil
		end
	end

	townBuild()
	topBuild()
	stage.Parent = o.parent or workspace
	applyMood(IntroPlan.SHOTS[1].mood)
	cine.skipButton = skipBtn
	return cine
end

---------------------------------------------------------------------------
-- Real-time play (first join, the lobby TV)
---------------------------------------------------------------------------
local SKIP_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.ButtonB] = true,
	[Enum.KeyCode.ButtonStart] = true,
}

-- Waits up to Config.Intro.KIT_WAIT_SECONDS for the intro kit (the server publishes it once the art kit loads).
function Cinematic.waitForKit(): boolean
	local untilAt = os.clock() + I.KIT_WAIT_SECONDS
	while os.clock() < untilAt do
		local f = ReplicatedStorage:FindFirstChild(I.KIT_FOLDER)
		if f then
			return true
		end
		task.wait(0.1)
	end
	return false
end

function Cinematic.isPlaying(): boolean
	return playing ~= nil
end

-- Builds and plays the intro now; opts.onEnd(how) once it is over ("finished" | "skipped"), after the camera,
-- lighting and HUD are restored. Returns the cinematic (nil when one is already playing or on the server).
function Cinematic.play(opts: any?): any
	if playing or not RunService:IsClient() then
		return nil
	end
	local o = table.clone(opts or {})
	local userEnd = o.onEnd
	local cine: any
	local conns: { RBXScriptConnection } = {}
	local startedAt = os.clock()
	o.onEnd = function(how: string)
		task.wait(I.HANDOFF_SECONDS)
		RunService:UnbindFromRenderStep(RENDER_NAME)
		for _, c in conns do
			c:Disconnect()
		end
		-- the caller's next frame first (the title card sits one layer under the intro), then the intro goes:
		-- no frame of bare game between them
		if userEnd then
			local ok, err = pcall(userEnd, how)
			if not ok then
				warn("[Cinematic] onEnd: " .. tostring(err))
			end
		end
		if cine then
			cine.destroy()
		end
	end
	cine = Cinematic.new(o)
	playing = cine
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		local ok, err = pcall(cine.step, math.min(dt, 0.1))
		if not ok then
			warn("[Cinematic] " .. tostring(err))
			cine.skip()
		end
	end)
	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(io: InputObject)
			if os.clock() - startedAt < I.SKIP.HOLD_OFF then
				return
			end
			if (I.SKIP.ANY_KEY and io.UserInputType == Enum.UserInputType.Keyboard) or SKIP_KEYS[io.KeyCode] then
				cine.skip()
			end
		end)
	)
	-- watchdog: whatever happens, the player gets the game back
	task.delay(IntroPlan.total() + 10, function()
		if playing == cine and not cine.isDone() then
			warn("[Cinematic] watchdog: ending the intro")
			cine.skip()
		end
	end)
	return cine
end

return Cinematic
