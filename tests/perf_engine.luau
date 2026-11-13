-- Performance measurement in a real Roblox server (Open Cloud Luau Execution; PLAN_STEAM_PLUS §4.7, §8.1 R1;
-- MASTERPLAN §3.3, §6.8, §8.6; docs/PERF.md has the numbers this prints and what they decided).
-- Run: ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 \
--      --place 70772627070328 --script tests/perf_engine.luau --timeout 300   (add --version N to skip publishing)
--
-- Luau Execution servers do not simulate (RunService:IsRunning() is false): this counts instances, memory, guis,
-- lights and particles, and builds what a client would; it cannot measure frame time (docs/PERF.md "Needs a phone").
-- A. Server: the garage + 8 kit-dressed heist instances at once (L1, L2, L5, L3, L4, L6, L6, L6: the Big Score is
--    the heaviest), counts per instance, Stats memory by tag, and what every client receives with streaming off
--    against what one client receives with it on.
-- B. One client view, built on the server at the L6 instance the way the client builds it: 12 clones (4 owners on
--    real avatar templates, EchoView: rigs, Highlights, floor glows, pills, emitters) + your halo, 16 Line-up
--    figures, 2 Gus, the backdrop + snow, WorldView's level extras, LightDirector's lamps; per tier (Shared/Heist/
--    Budget) the drawn glows, Highlights, lights in view, shadowed lights, snow and the worst particle moment.
-- C. Recipe C "Soft Toybox" at tier 3 and back to recipe A (LightDirector), streaming settings and model modes.
-- Lines start with "ok", "FAIL", "warn" or "info"; tools/cloud_test.py exits 1 when any says FAIL.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")

local results = {}
local failures = 0
local function check(cond: any, msg: string)
	if cond then
		table.insert(results, "ok    " .. msg)
	else
		failures += 1
		table.insert(results, "FAIL  " .. msg)
	end
end
local function info(msg: string)
	table.insert(results, "info  " .. msg)
end
local function warnLine(msg: string)
	table.insert(results, "warn  " .. msg)
end

local shared = ReplicatedStorage:WaitForChild("Shared")
local server = ServerScriptService:WaitForChild("Server")
local heistServer = server:WaitForChild("Heist")
local clientHeist =
	game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client"):WaitForChild("Heist")

local Config = require(shared:WaitForChild("Config")) :: any
local Budget = require(shared:WaitForChild("Heist"):WaitForChild("Budget"))
local Protocol = require(shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local Codec = require(shared:WaitForChild("Rec"):WaitForChild("Codec"))
local HeistService = require(heistServer:WaitForChild("HeistService"))
local HeistInstance = require(heistServer:WaitForChild("HeistInstance"))
local Avatars = require(heistServer:WaitForChild("Avatars"))
local Lobby = require(heistServer:WaitForChild("Lobby"))
local KitService = require(server:WaitForChild("Kit"):WaitForChild("KitService"))

local P = Config.Perf
local LIGHT = Config.Lighting
local TIERS = #P.TIERS
local OWNER_ID = 10346200733 -- the game owner's account (a real avatar with layered clothing)
local SECOND_ID = 156 -- a second real catalog avatar
local MB = 1 -- Stats reports MB already

-- kit tris (from assets/fbx/kit_manifest.json "tris"; regenerate when the kit changes)
local TRIS: { [string]: number } = {
	BankFront_24x12 = 2244,
	BankersLamp = 328,
	-- BIG buildings (assets/blender/tower.py)
	Ceiling_8x8 = 168,
	Clock_6 = 400,
	Cornice_8 = 152,
	Facade_8x10 = 360,
	Facade_8x10_Body = 48,
	Facade_Curtain = 132,
	FireEscape_8x10 = 296,
	Pediment_24 = 228,
	Railing_8 = 60,
	Roof_Antenna = 72,
	Roof_Chimney = 204,
	Roof_WaterTank = 412,
	Truss_8 = 60,
	Candy = 336,
	CashBag = 600,
	CashRegister = 1032,
	CashRegister_Drawer = 488,
	Column_2x12 = 600,
	Counter_4x4 = 208,
	Counter_8x2 = 244,
	Counter_8x4 = 316,
	Diamond = 94,
	Floor_8x8 = 144,
	GarageDoor_16x12 = 364,
	GiantPresent = 1380,
	GoldBar = 52,
	GoldStack = 312,
	Gus_Cap = 184,
	Gus_DonutBox = 596,
	Gus_Flashlight = 336,
	Gus_FlashlightLens = 48,
	Gus_Head = 560,
	Gus_LeftFoot = 80,
	Gus_LeftHand = 116,
	Gus_LeftLowerArm = 120,
	Gus_LeftLowerLeg = 80,
	Gus_LeftUpperArm = 180,
	Gus_LeftUpperLeg = 80,
	Gus_LowerTorso = 424,
	Gus_RightFoot = 80,
	Gus_RightHand = 116,
	Gus_RightLowerArm = 120,
	Gus_RightLowerLeg = 80,
	Gus_RightUpperArm = 180,
	Gus_RightUpperLeg = 80,
	Gus_SantaHat = 360,
	Gus_UpperTorso = 624,
	Hide_CoatRack = 544,
	Hide_CoatStand = 572,
	Hide_Crate = 552,
	Hide_Curtain = 468,
	Hide_DepositStack = 696,
	Hide_Plant = 568,
	JobBoard = 844,
	Lamp_Ceiling = 568,
	Lamp_Ceiling_Bulb = 120,
	LaserEmitter = 428,
	LaserEmitter_CandyCane = 888,
	LaserEmitter_Lens = 200,
	Ornament_Bauble = 288,
	Ornament_Bell = 328,
	Ornament_Donut = 400,
	Ornament_Stand = 180,
	Ornament_Star = 164,
	Ornament_Van = 280,
	Ornament_VaultDoor = 472,
	Pedestal_Diamond = 528,
	Pedestal_Diamond_Case = 60,
	Pillar_2x12 = 324,
	Plate_4x4 = 484,
	Plate_4x4_Ring = 288,
	Present = 388,
	Rug_8x6 = 264,
	Safe = 452,
	Safe_Door = 548,
	Shelf_8x2 = 776,
	Shelf_Gondola_8x2 = 744,
	Shutter_8x10 = 556,
	Skyline_Far = 352,
	Skyline_Far_Windows = 1236,
	Skyline_Near = 292,
	Skyline_Near_Windows = 996,
	Storefront_24x12 = 1980,
	Storefront_24x12_Glass = 24,
	StreetLamp = 468,
	StreetLamp_Bulb = 80,
	Switch_Wall = 224,
	Switch_Wall_Lamp = 58,
	Switch_Wall_Lever = 172,
	Teddy = 596,
	TellerCounter_8x4 = 412,
	TellerCounter_8x4_Glass = 24,
	Toy = 580,
	ToySoldier = 2736,
	Van = 1704,
	Van_Paint = 164,
	Van_Shelf = 124,
	VaultDoor_Dial = 1104,
	VaultDoor_DialFace = 384,
	VaultDoor_DialRing = 384,
	VaultDoor_Door = 3832,
	VaultDoor_Frame = 2452,
	Wall_4x12 = 196,
	Wall_8x12 = 284,
	Wall_Door_8x12 = 664,
	Wall_Door_8x12_Leaf = 508,
	Wall_Window_8x12 = 768,
	Wall_Window_8x12_Glass = 12,
	Xmas_Garland_8 = 736,
	Xmas_Lights_8 = 286,
	Xmas_Lights_8_Bulbs = 400,
	Xmas_SnowCap_8 = 512,
	Xmas_SnowPile = 576,
	Xmas_Tree = 312,
	Xmas_Tree_Lights = 400,
	Xmas_Wreath = 548,
}
local SHAPE_TRIS = { Block = 12, Wedge = 8, CornerWedge = 6, Cylinder = 96, Ball = 400 } -- engine primitives, approx.

---------------------------------------------------------------------------
-- Counting
---------------------------------------------------------------------------
type Tally = { [string]: any }

local function newTally(): Tally
	return {
		instances = 0,
		parts = 0,
		visibleParts = 0,
		meshParts = 0,
		kitTris = 0,
		primTris = 0,
		avatarMeshes = 0,
		lights = 0,
		lightsOn = 0,
		shadowed = 0,
		surfaceGuis = 0,
		surfaceGuisOn = 0,
		billboards = 0,
		billboardsOn = 0,
		highlights = 0,
		highlightsOn = 0,
		emitters = 0,
		particlesMax = 0,
		beams = 0,
		trails = 0,
		trailsOn = 0,
		batches = {} :: { [string]: boolean },
	}
end

local function enabled(d: Instance): boolean
	local ok, v = pcall(function()
		return (d :: any).Enabled
	end)
	return ok and v ~= false
end

local function add(t: Tally, root: Instance, includeRoot: boolean?)
	local list = root:GetDescendants()
	if includeRoot then
		table.insert(list, root)
	end
	for _, d in list do
		t.instances += 1
		if d:IsA("BasePart") then
			t.parts += 1
			if d.Transparency < 1 then
				t.visibleParts += 1
				if d:IsA("MeshPart") then
					t.meshParts += 1
					local piece = d:GetAttribute("KitPiece") or d.Name
					local tri = TRIS[piece]
					if tri then
						t.kitTris += tri
					else
						t.avatarMeshes += 1
					end
					local okId, key = pcall(function()
						return d.MeshId .. "|" .. d.TextureID .. "|" .. d.Material.Name
					end)
					t.batches["m" .. (if okId then key else d.Name)] = true
				else
					local shape = if d:IsA("Part") then d.Shape.Name else "Block"
					t.primTris += SHAPE_TRIS[shape] or 12
					t.batches["p" .. d.Material.Name] = true
				end
			end
		elseif d:IsA("Light") then
			t.lights += 1
			if d.Enabled then
				t.lightsOn += 1
				if d.Shadows then
					t.shadowed += 1
				end
			end
		elseif d:IsA("SurfaceGui") then
			t.surfaceGuis += 1
			t.surfaceGuisOn += if d.Enabled then 1 else 0
		elseif d:IsA("BillboardGui") then
			t.billboards += 1
			t.billboardsOn += if d.Enabled then 1 else 0
		elseif d:IsA("Highlight") then
			t.highlights += 1
			t.highlightsOn += if d.Enabled then 1 else 0
		elseif d:IsA("ParticleEmitter") then
			t.emitters += 1
			if d.Enabled then
				t.particlesMax += d.Rate * d.Lifetime.Max
			end
		elseif d:IsA("Beam") then
			t.beams += 1
		elseif d:IsA("Trail") then
			t.trails += 1
			t.trailsOn += if enabled(d) then 1 else 0
		end
	end
end

local function tallyOf(root: Instance?): Tally
	local t = newTally()
	if root then
		add(t, root, true)
	end
	return t
end

-- BIG: the triangles of a level's Overhead detail layer (curtains, fire escapes, rooftop props, light strings):
-- what the client hides from Config.Big.DETAIL_OFF_TIER.
local function bigDetailTris(model: Instance): number
	local over = model:FindFirstChild("Overhead")
	local n = 0
	for _, d in (over and over:GetDescendants()) or {} do
		if d:IsA("BasePart") and d:GetAttribute("EH_Layer") ~= nil then
			n += if d:IsA("MeshPart") then TRIS[d:GetAttribute("KitPiece") or d.Name] or 0 else 12
		end
	end
	return n
end

local function batchCount(t: Tally): number
	local n = 0
	for _ in t.batches do
		n += 1
	end
	return n
end

local function line(name: string, t: Tally): string
	return string.format(
		"%s: %d instances, %d parts (%d visible, %d meshes), ~%dk tris (kit %d + primitives %d%s), %d lights "
			.. "(%d on, %d shadowed), %d SurfaceGuis (%d on), %d Billboards (%d on), %d Highlights (%d on), "
			.. "%d emitters (%d particles max), %d beams, %d trails, ~%d batches",
		name,
		t.instances,
		t.parts,
		t.visibleParts,
		t.meshParts,
		math.floor((t.kitTris + t.primTris) / 1000 + 0.5),
		t.kitTris,
		t.primTris,
		if t.avatarMeshes > 0 then ", " .. t.avatarMeshes .. " avatar meshes" else "",
		t.lights,
		t.lightsOn,
		t.shadowed,
		t.surfaceGuis,
		t.surfaceGuisOn,
		t.billboards,
		t.billboardsOn,
		t.highlights,
		t.highlightsOn,
		t.emitters,
		math.floor(t.particlesMax + 0.5),
		t.beams,
		t.trails,
		batchCount(t)
	)
end

-- Memory by DeveloperMemoryTag (MB) + the total.
local function memory(): { [string]: number }
	local out: { [string]: number } = {}
	for _, tag in Enum.DeveloperMemoryTag:GetEnumItems() do
		local ok, mb = pcall(function()
			return Stats:GetMemoryUsageMbForTag(tag)
		end)
		if ok and type(mb) == "number" then
			out[tag.Name] = mb * MB
		end
	end
	out.Total = Stats:GetTotalMemoryUsageMb()
	return out
end

local function memDelta(a: { [string]: number }, b: { [string]: number }, label: string, over: number?)
	local per = over or 1
	local rows = {}
	for k, v in b do
		local d = v - (a[k] or 0)
		if k ~= "Total" and math.abs(d) >= 0.05 then
			table.insert(rows, { k = k, d = d })
		end
	end
	table.sort(rows, function(x, y)
		return x.d > y.d
	end)
	local parts = {}
	for i = 1, math.min(#rows, 8) do
		table.insert(parts, string.format("%s %+.1f", rows[i].k, rows[i].d / per))
	end
	info(
		string.format(
			"memory %s: total %+.1f MB%s (%s)",
			label,
			((b.Total or 0) - (a.Total or 0)) / per,
			if per > 1 then " each" else "",
			table.concat(parts, ", ")
		)
	)
	return ((b.Total or 0) - (a.Total or 0)) / per
end

-- Enabled lights with a world position (an attachment's or a part's).
local function lightsOf(root: Instance): { { pos: Vector3, shadows: boolean } }
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Light") and d.Enabled then
			local p = d.Parent
			local pos = if p and p:IsA("Attachment")
				then p.WorldPosition
				elseif p and p:IsA("BasePart") then p.Position
				else nil
			if pos then
				table.insert(out, { pos = pos, shadows = d.Shadows })
			end
		end
	end
	return out
end

-- The busiest view: the most enabled lights within VIEW_RADIUS (flat) of any one of them, and the shadowed.
local function busiestView(list: { { pos: Vector3, shadows: boolean } }): (number, number)
	local lit, shadowed = 0, 0
	for _, a in list do
		local n, s = 0, 0
		for _, b in list do
			local d = Vector3.new(a.pos.X - b.pos.X, 0, a.pos.Z - b.pos.Z).Magnitude
			if d <= LIGHT.VIEW_RADIUS then
				n += 1
				s += if b.shadows then 1 else 0
			end
		end
		lit = math.max(lit, n)
		shadowed = math.max(shadowed, s)
	end
	return lit, shadowed
end

---------------------------------------------------------------------------
-- A. Server: garage + 8 heist instances
---------------------------------------------------------------------------
info("RunService:IsRunning() = " .. tostring(RunService:IsRunning()) .. " (no frame times here)")
local function styleNow(): string
	local ok, v = pcall(function()
		return Lighting.LightingStyle
	end)
	return if ok then tostring(v) else "unreadable"
end
local styleAtBoot = styleNow()
info("Lighting.LightingStyle at boot (the project file's recipe A): " .. styleAtBoot)
-- The project's pair must survive the load: LightingStyle Realistic + PrioritizeLightingQuality on. A file without
-- Lighting.Technology loads it as Voxel, which the engine maps to Soft + off (tests/place_check.luau, PERF.md §4);
-- this fails until default.project.json's Lighting lists "Technology": "Future".
do
	local okP, prio = pcall(function()
		return Lighting.PrioritizeLightingQuality
	end)
	check(
		styleAtBoot == "Enum.LightingStyle.Realistic" and okP and prio == true,
		string.format(
			"Lighting at boot is the project's: LightingStyle %s, PrioritizeLightingQuality %s (want Realistic, true)",
			styleAtBoot,
			if okP then tostring(prio) else "unreadable"
		)
	)
end
pcall(function()
	Config.Heist.XMAS_DRESSING = "on" -- the launch edition is the Christmas one: measure with its layer
end)
local okHs, hsErr = pcall(HeistService.start, { lobby = false, players = false })
check(okHs, "HeistService starts" .. (if okHs then "" else ": " .. tostring(hsErr)))
local mem0 = memory()
KitService.start()
local kitOk = KitService.ready(60)
check(kitOk, "kit ready (" .. KitService.summary() .. ")")
HeistService.configureKit(KitService)
local kitFolder = ServerStorage:FindFirstChild(Config.Kit.FOLDER)
info(
	string.format(
		"kit templates (ServerStorage, never replicated): %d instances",
		if kitFolder then #kitFolder:GetDescendants() else 0
	)
)
local mem1 = memory()
memDelta(mem0, mem1, "kit load (server only)")

local garage = Lobby.build(KitService)
Lobby.dress(KitService)
local deadline = os.clock() + 10
while not Lobby.isDressed() and os.clock() < deadline do
	task.wait(0.2)
end
local garageT = tallyOf(garage)
table.insert(results, "      " .. line("garage", garageT))
local mem2 = memory()
memDelta(mem1, mem2, "garage")

local LEVELS = {
	"cs1_back_room",
	"cs2_two_doors",
	"cs5_clone_party",
	"cs3_lights_out",
	"cs4_night_clerk",
	"bk1_big_score",
	"bk1_big_score",
	"bk1_big_score",
}
local instances = {}
local memBefore6 = mem2
for i, id in LEVELS do
	local index = Protocol.catalogIndex(id)
	local fakeId = -500 - i
	if i == 6 then
		memBefore6 = memory()
	end
	local inst = index
		and HeistService.createInstance(index, {
			{ userId = fakeId, name = "Perf" .. i, fake = { x = 0, y = 3, z = 14, yaw = 0 } },
		}, fakeId, false)
	check(inst ~= nil, "instance " .. i .. " (" .. id .. ") built")
	if inst then
		table.insert(instances, { id = id, inst = inst, fake = fakeId })
	end
end
task.wait(1)
local mem3 = memory()
memDelta(mem2, mem3, "8 heist instances")
local l6Mem = memDelta(memBefore6, mem3, "per Big Score instance (the last three)", 3)

local perLevel: { [string]: Tally } = {}
local all = newTally()
local worstLevel = 0
for i, e in instances do
	local t = tallyOf(e.inst.folder)
	perLevel[e.id] = perLevel[e.id] or t
	add(all, e.inst.folder, true)
	worstLevel = math.max(worstLevel, t.instances)
	if i <= 6 then
		table.insert(results, "      " .. line(string.format("instance %d %s", i, e.id), t))
		check(e.inst.built.kit == true, e.id .. " is kit-dressed")
	end
end
local l6T = perLevel.bk1_big_score
check(
	worstLevel <= 6000,
	string.format("MASTERPLAN §6.8: level art instances per heist instance <= 6k (worst %d, L6)", worstLevel)
)

-- What every client receives with streaming off: all of Workspace and ReplicatedStorage.
local wsCount, rsCount = 0, 0
for _, c in workspace:GetChildren() do
	if not c:IsA("Terrain") and not c:IsA("Camera") then
		wsCount += 1 + #c:GetDescendants()
	end
end
rsCount = #ReplicatedStorage:GetDescendants()
local rsParts = {}
for _, c in ReplicatedStorage:GetChildren() do
	table.insert(rsParts, string.format("%s %d", c.Name, #c:GetDescendants()))
end
info("ReplicatedStorage: " .. rsCount .. " instances (" .. table.concat(rsParts, ", ") .. ")")
info(
	string.format(
		"streaming OFF, every client receives: Workspace %d (garage %d + 8 instances %d) + ReplicatedStorage %d = %d instances; ~%dk tris of level art; server memory for the 8 instances %+.1f MB",
		wsCount,
		garageT.instances,
		all.instances,
		rsCount,
		wsCount + rsCount,
		math.floor((all.kitTris + all.primTris) / 1000 + 0.5),
		(mem3.Total or 0) - (mem2.Total or 0)
	)
)
local folderOnly = 0
for _, e in instances do
	-- the instance folder's own non-level content (attributes, scripts-free values) reaches every client either way
	folderOnly += #e.inst.folder:GetDescendants() - #e.inst.built.model:GetDescendants() - 1
end
local oneClientOn = garageT.instances + l6T.instances + folderOnly + rsCount
info(
	string.format(
		"streaming ON, one client in a Big Score receives: garage %d (Persistent) + its own level %d + 8 instance folders' rest %d + ReplicatedStorage %d = %d (vs %d off: %.0f%% less)",
		garageT.instances,
		l6T.instances,
		folderOnly,
		rsCount,
		oneClientOn,
		wsCount + rsCount,
		100 * (1 - oneClientOn / math.max(1, wsCount + rsCount))
	)
)
info(
	string.format(
		"8 x Big Score worst case (streaming off): %d level instances, ~%dk tris, ~%.0f MB server-side (%.1f MB each)",
		8 * l6T.instances,
		math.floor(8 * (l6T.kitTris + l6T.primTris) / 1000 + 0.5),
		8 * l6Mem,
		l6Mem
	)
)

-- Streaming setup (MASTERPLAN §3.3 / §8.6) in the published place. The Workspace streaming properties may not be
-- readable by scripts; tests/place_check.luau asserts them in the built file either way.
local okSe, se = pcall(function()
	return (workspace :: any).StreamingEnabled
end)
if okSe then
	check(se == true, "Workspace.StreamingEnabled is on (" .. tostring(se) .. ")")
else
	info("Workspace.StreamingEnabled is not readable here (" .. tostring(se) .. "); place_check asserts the file")
end
local okR, minR, targetR = pcall(function()
	return (workspace :: any).StreamingMinRadius, (workspace :: any).StreamingTargetRadius
end)
if okR then
	check(
		minR == 128 and targetR == 512,
		string.format("streaming radii 128 / 512 (%s / %s)", tostring(minR), tostring(targetR))
	)
else
	targetR = 512
end
local okMode, outMode, modelMode = pcall(function()
	return tostring((workspace :: any).StreamOutBehavior), tostring((workspace :: any).ModelStreamingBehavior)
end)
if okMode then
	check(
		string.find(outMode, "Opportunistic", 1, true) ~= nil and string.find(modelMode, "Improved", 1, true) ~= nil,
		"StreamOutBehavior " .. outMode .. ", ModelStreamingBehavior " .. modelMode
	)
end
local modesOk = true
for _, e in instances do
	modesOk = modesOk and e.inst.built.model.ModelStreamingMode == Enum.ModelStreamingMode.PersistentPerPlayer
end
check(modesOk, "every heist level model is PersistentPerPlayer (its crew only)")
check(
	garage.ModelStreamingMode == Enum.ModelStreamingMode.Persistent,
	"the garage is Persistent (every player returns to it; " .. garage.ModelStreamingMode.Name .. ")"
)
-- The nearest other instance (or the garage) must stay out of a client's target radius from anywhere in its level.
local origins = { garage:GetPivot().Position }
local reach = 0
for _, e in instances do
	table.insert(origins, e.inst.origin)
	local _, size = e.inst.built.model:GetBoundingBox()
	reach = math.max(reach, Vector3.new(size.X, 0, size.Z).Magnitude / 2)
end
local nearest = math.huge
for i = 1, #origins do
	for j = i + 1, #origins do
		nearest = math.min(nearest, Vector3.new(origins[i].X - origins[j].X, 0, origins[i].Z - origins[j].Z).Magnitude)
	end
end
check(
	nearest - 2 * reach > (targetR or 512),
	string.format(
		"no other instance within the target radius of a level's edge (nearest origins %d studs, level reach %d)",
		nearest,
		reach
	)
)

---------------------------------------------------------------------------
-- B. One client view at the L6 instance
---------------------------------------------------------------------------
-- A recording: the L1 instance (instance 1) plays run 1 to plate A; run 2 carries its clone (clone_engine's way).
local l1 = instances[1].inst
local fakeIn = l1.byId[instances[1].fake].fake
local simNow = 90000
local function step(dt: number)
	simNow += dt
	HeistInstance.update(l1, simNow)
end
local function walkTo(x: number, z: number)
	for _ = 1, 400 do
		local dx, dz = x - fakeIn.x, z - fakeIn.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 0.05 then
			break
		end
		local s = math.min(d, 14 * 0.05)
		HeistInstance.setFakeInput(
			l1,
			instances[1].fake,
			fakeIn.x + dx / d * s,
			3,
			fakeIn.z + dz / d * s,
			math.atan2(-dx, -dz)
		)
		step(0.05)
	end
end
for _ = 1, 23 do
	step(0.05)
end
walkTo(0, 4)
walkTo(10, -8)
for _ = 1, 72 do
	step(0.05)
end
local cloneActor = nil
for _, a in l1.runMsg and l1.runMsg.actors or {} do
	if a.kind == "clone" then
		cloneActor = a
	end
end
check(cloneActor ~= nil, "a recorded clone to replay (L1 run " .. tostring(l1.sim.runIndex) .. ")")

local six = instances[6] and instances[6].inst
local Rigs = require(clientHeist:WaitForChild("Rigs"))
local Particles = require(clientHeist:WaitForChild("Particles"))
local EchoView = require(clientHeist:WaitForChild("EchoView"))
local GusView = require(clientHeist:WaitForChild("GusView"))
local WorldView = require(clientHeist:WaitForChild("WorldView"))
local LightDirector = require(clientHeist:WaitForChild("LightDirector"))
local Backdrop = require(clientHeist:WaitForChild("Backdrop"))
local Palette = require(shared:WaitForChild("Heist"):WaitForChild("Palette"))

if cloneActor and six then
	local memV0 = memory()
	-- four crew members on real templates (the owner's layered avatar, a catalog avatar, default, Rthro)
	local owners = { -601, -602, -603, -604 }
	local descs: { any } = {}
	for i, uid in { OWNER_ID, SECOND_ID } do
		local ok, d = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(uid)
		end)
		descs[i] = if ok then d else Instance.new("HumanoidDescription")
	end
	descs[3] = Instance.new("HumanoidDescription")
	local rthro = Instance.new("HumanoidDescription")
	rthro.HeightScale = 1.05
	rthro.BodyTypeScale = 1
	rthro.ProportionScale = 1
	descs[4] = rthro
	local folder = Avatars.folder()
	local templates = {}
	for i, uid in owners do
		local ok, rig = pcall(function()
			return Players:CreateHumanoidModelFromDescriptionAsync(descs[i], Enum.HumanoidRigType.R15)
		end)
		if ok and rig then
			Avatars.strip(rig)
			rig.Name = tostring(uid)
			rig.Parent = folder
			templates[i] = rig
		end
	end
	local tplSizes = {}
	for i, t in templates do
		tplSizes[i] = #t:GetDescendants()
	end
	info("avatar templates (ReplicatedStorage, one per player): " .. table.concat(tplSizes, ", ") .. " instances")

	local rec = Codec.decode(l1.recBufs[cloneActor.key])
	local msg = table.clone(l1.runMsg)
	msg.actors = {}
	local crew = {}
	local id = 0
	for o, uid in owners do
		table.insert(crew, { userId = uid, seat = o })
		for slot = 1, 3 do
			id += 1
			local a = table.clone(cloneActor)
			a.id = id
			a.owner = uid
			a.seat = o
			a.slot = slot
			table.insert(msg.actors, a)
		end
	end
	local vstate = {
		origin = six.origin + Vector3.new((id % 3) * 0, 0, 0),
		folder = six.folder,
		level = six.level,
		levelIndex = Protocol.catalogIndex("bk1_big_score"),
		crew = crew,
		actorFx = {},
		run = msg,
		viewerId = owners[1],
	}
	local cam = workspace.CurrentCamera
	if not cam then
		local c = Instance.new("Camera")
		c.Parent = workspace
		local ws: any = workspace
		ws.CurrentCamera = c
		cam = c
	end
	local camera = cam :: Camera
	camera.CameraType = Enum.CameraType.Scriptable
	local focus = six.origin + Vector3.new(4, 3, 0)
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 9, 14), focus)

	local echo = EchoView.new(vstate)
	local okRun, runErr = pcall(echo.setRun, msg, { [cloneActor.key] = rec }, os.clock() - 1)
	check(okRun, "EchoView: 12 clones of 4 owners" .. (if okRun then "" else ": " .. tostring(runErr)))
	local t0 = os.clock()
	local frames = 0
	while os.clock() - t0 < 2.2 do
		local dt = task.wait()
		frames += 1
		pcall(echo.update, 0.8 + (os.clock() - t0), os.clock(), dt, nil)
	end
	local clonesFolder = workspace:FindFirstChild("HeistClones")
	local memV1 = memory()
	memDelta(memV0, memV1, "12 clones + templates (client side)")

	-- Line-up: 16 figures (4 per owner) under one Highlight per owner + the "◀ ME" label, as LineupDirector builds
	local lineup = Instance.new("Folder")
	lineup.Name = "PerfLineup"
	lineup.Parent = workspace
	for o, uid in owners do
		local g = Instance.new("Model")
		g.Name = "Owner_" .. uid
		local hl = Instance.new("Highlight")
		hl.FillTransparency = 1
		hl.Adornee = g
		hl.Parent = g
		g.Parent = lineup
		for k = 1, 4 do
			local t = templates[o]
			local rig = (t and Rigs.buildAvatar(t)) or Rigs.buildMannequin()
			Rigs.tint(rig, Palette.hueFor(o))
			rig.model:PivotTo(CFrame.new(six.origin + Vector3.new(o * 3, 3, k * 3 - 40)))
			rig.model.Parent = g
			if o == 1 and k == 1 then
				local label = Instance.new("BillboardGui")
				label.Name = "MeLabel"
				label.Parent = rig.model
				Instance.new("TextLabel").Parent = label
			end
		end
	end
	local lineupT = tallyOf(lineup)

	-- Gus x2 (L6 has two guards) on the kit mesh
	local GusTemplate = require(heistServer:WaitForChild("GusTemplate"))
	pcall(GusTemplate.publishNow, KitService)
	local gus = GusView.new({
		origin = six.origin,
		folder = six.folder,
		level = six.level,
		crew = {},
		dressing = true,
		phase = "Run",
		run = { actors = {}, actorById = {} },
	})
	pcall(gus.setLevel, six.level)
	for _ = 1, 3 do
		pcall(gus.update, 1, os.clock(), 1 / 30)
	end
	local gusT = tallyOf(workspace:FindFirstChild("HeistGus"))
	local gusTris = 0
	for name, n in TRIS do
		if string.sub(name, 1, 4) == "Gus_" and name ~= "Gus_Cap" and name ~= "Gus_DonutBox" then
			gusTris += n
		end
	end

	-- WorldView's client-side extras on the level (labels, sparks, coins, glints) + LightDirector
	local levelModel = six.built.model
	local before = #levelModel:GetDescendants()
	local world = WorldView.new({
		folder = six.folder,
		level = six.level,
		origin = six.origin,
		phase = "Run",
		run = { actors = {}, actorById = {} },
		crew = {},
		particleScale = 1,
		perfTier = 1,
	}, function()
		return nil
	end)
	local okW, wErr = pcall(world.bind, levelModel)
	check(okW, "WorldView binds L6" .. (if okW then "" else ": " .. tostring(wErr)))
	for _ = 1, 3 do
		pcall(world.update, 5, os.clock(), 1 / 30)
	end
	local worldAdded = #levelModel:GetDescendants() - before

	-- Backdrop round the L6 instance (the server publishes the ring kit; the client builds the rest)
	local BackdropKit = require(heistServer:WaitForChild("BackdropKit"))
	pcall(BackdropKit.publish, KitService)
	local backdrop = Backdrop.new()
	local okBd, bdErr = pcall(backdrop.showHeist, levelModel, six.level, six.origin)
	info("Backdrop.showHeist on the server: " .. (if okBd then "ok" else tostring(bdErr) .. " (no RenderStepped here)"))
	local bdFolder = workspace:FindFirstChild("EH_Backdrop")
	check(bdFolder ~= nil, "the backdrop builds round the L6 instance")

	local lights = LightDirector.new()
	lights.bind(levelModel)

	-- Per tier: everything a client in this view draws.
	local snowOf = function(): number
		local n = 0
		for _, e in (bdFolder and bdFolder:GetDescendants()) or {} do
			if e:IsA("ParticleEmitter") and e.Name == "Snow" then
				n += e.Rate * e.Lifetime.Max
			end
		end
		return n
	end
	local playerChars = 4 * (tplSizes[1] or 0) -- the 4 live characters (about one template each)
	for tier = 1, TIERS do
		echo.setTier(tier)
		lights.setTier(tier)
		backdrop.setTier(tier)
		for _ = 1, 2 do
			pcall(echo.update, 3.2, os.clock(), 1 / 30, nil)
		end
		-- Clone LOD (Config.Perf.CLONE_LOD): from its tier, with the camera ~40 studs from the crowd every avatar
		-- clone draws as the light rig; inside NEAR they are textured again (hysteresis); the view is then measured
		-- from the far camera (the Big Score crowd fills a hall well past FAR).
		local lodFar = 0
		local LOD = P.CLONE_LOD
		local crowdAt = echo.positionOf(1)
		local camWas = camera.CFrame
		local function settle()
			for _ = 1, 2 do
				pcall(echo.update, 3.2, os.clock(), 1 / 30, nil)
			end
		end
		if crowdAt and Budget.cloneLod(tier) then
			camera.CFrame = CFrame.lookAt(crowdAt + Vector3.new(0, 12, 38), crowdAt)
			settle()
			lodFar = echo.lodCount()
			local drawn = echo.drawnRigOf(1)
			check(
				lodFar == 12 and drawn ~= nil and drawn.kind == "mannequin",
				string.format("tier %d: clone LOD, camera ~40 studs away: %d of 12 clones light", tier, lodFar)
			)
			camera.CFrame = CFrame.lookAt(crowdAt + Vector3.new(0, 4, LOD.NEAR - 4), crowdAt)
			settle()
			check(echo.lodCount() == 0, string.format("tier %d: inside NEAR the clones are textured again", tier))
			camera.CFrame = CFrame.lookAt(crowdAt + Vector3.new(0, 12, 38), crowdAt)
			settle()
			lodFar = echo.lodCount()
		elseif crowdAt then
			camera.CFrame = CFrame.lookAt(crowdAt + Vector3.new(0, 12, 38), crowdAt)
			settle()
			check(echo.lodCount() == 0, string.format("tier %d: no clone LOD below tier %d", tier, LOD.TIER))
			camera.CFrame = camWas
			settle()
		end
		local b = Budget.forTier(tier)
		local clonesT = tallyOf(clonesFolder)
		local levelLights = lightsOf(levelModel)
		local lit, shadowed = busiestView(levelLights)
		-- your halo's PointLight (tiers 1-2) sits on your character: count it in the view
		local haloLight = if Budget.haloLight(tier) and Config.Clone.HALO_LIGHT_BRIGHTNESS > 0 then 1 else 0
		local snow = snowOf()
		local bursts = Budget.worstParticles(tier) - b.snowAlive
		local bdT = tallyOf(bdFolder)
		local glows = echo.glowCount()
		local hl = clonesT.highlightsOn
		-- BIG: from Config.Big.DETAIL_OFF_TIER the client (Heist/CutAway) hides the Overhead's detail layer
		local levelTris = l6T.kitTris
			+ l6T.primTris
			- (if tier >= Config.Big.DETAIL_OFF_TIER then bigDetailTris(levelModel) else 0)
		local avatarTris = (12 - lodFar + 4) * P.AVATAR_TRIS_EST + lodFar * P.MANNEQUIN_TRIS
		local tris = levelTris + bdT.kitTris + bdT.primTris + avatarTris + 2 * gusTris
		local draws = batchCount(l6T)
			+ batchCount(bdT)
			+ (if lodFar >= 12 then 0 else 4 * 17) -- 12 clones of 4 avatars instance together: ~17 meshes per avatar
			+ (if lodFar > 0 then LOD.MANNEQUIN_DRAWS else 0) -- the light rigs: primitive boxes and balls
			+ 4 * 17 -- the 4 live characters
			+ 2 * 18 -- Gus
			+ clonesT.surfaceGuisOn
			+ clonesT.billboardsOn
			+ l6T.surfaceGuisOn
			+ gusT.billboardsOn
		local instTotal = garageT.instances
			+ l6T.instances
			+ worldAdded
			+ folderOnly
			+ rsCount
			+ clonesT.instances
			+ gusT.instances
			+ bdT.instances
			+ playerChars
		table.insert(results, "      " .. line(string.format("tier %d clones (12) + halo", tier), clonesT))
		info(
			string.format(
				"tier %d view: lights %d (+%d halo) / shadowed %d, glows %d, Highlights %d, snow %.0f + worst bursts %d = %d particles, ~%dk tris (level %dk, backdrop %dk, avatars %dk est. with %d of 12 clones light, Gus %dk), ~%d draws (estimate), %d live instances (streaming on)",
				tier,
				lit,
				haloLight,
				shadowed,
				glows,
				hl + 1,
				snow,
				bursts,
				math.floor(snow + bursts + 0.5),
				math.floor(tris / 1000 + 0.5),
				math.floor(levelTris / 1000 + 0.5),
				math.floor((bdT.kitTris + bdT.primTris) / 1000 + 0.5),
				math.floor(avatarTris / 1000 + 0.5),
				lodFar,
				math.floor(2 * gusTris / 1000 + 0.5),
				draws,
				instTotal
			)
		)
		check(
			lit + haloLight <= b.lights,
			string.format("tier %d: lights in the busiest view %d <= %d", tier, lit + haloLight, b.lights)
		)
		check(shadowed <= b.shadowed, string.format("tier %d: shadowed lights %d <= %d", tier, shadowed, b.shadowed))
		check(glows <= b.cloneGlows, string.format("tier %d: floor glows %d <= %d", tier, glows, b.cloneGlows))
		check(
			hl + 1 <= b.highlights,
			string.format("tier %d: Highlights %d (+ your rim) <= %d", tier, hl + 1, b.highlights)
		)
		check(snow <= b.snowAlive + 0.5, string.format("tier %d: snow alive %.0f <= %d", tier, snow, b.snowAlive))
		check(
			snow + bursts <= b.liveParticles,
			string.format("tier %d: worst particle moment %.0f <= %d", tier, snow + bursts, b.liveParticles)
		)
		-- The one shared budget (Heist/Particles): the measured snow reports in, then the worst moment fires twice
		-- through it (two crews' busts at once); steady + live bursts never pass the tier's cap.
		do
			Particles.setTier(tier)
			Particles.reset()
			Particles.setSteady("snow", snowOf)
			local bases = Budget.burstBases()
			local tNow = os.clock()
			for _ = 1, 2 do
				for _, name in P.WORST_MOMENT do
					Particles.grant(Budget.burst(tier, bases[name] or 0), 1.5, tNow)
				end
			end
			local live = Particles.live(tNow) + Particles.steadyCount()
			check(
				live <= Particles.cap() + 0.5,
				string.format("tier %d: one particle budget, worst moment x2: %.0f <= %d", tier, live, Particles.cap())
			)
			Particles.reset()
			Particles.setSteady("snow", nil)
		end
		check(instTotal <= 25000, string.format("tier %d: live client instances %d <= 25k (§6.8)", tier, instTotal))
		if tris > b.tris then
			warnLine(
				string.format("tier %d: ~%dk tris (estimate) over the %dk budget", tier, tris // 1000, b.tris // 1000)
			)
		end
		if draws > b.drawCalls then
			warnLine(string.format("tier %d: ~%d draws (estimate) over the %d budget", tier, draws, b.drawCalls))
		end
		camera.CFrame = camWas
	end
	do
		-- Line-up at tier 3 (LineupDirector, Budget.lineupLight): past the front row and beyond FAR from the shot's
		-- camera the figures are built light; never you or your newest clone. 16 figures = 2 rows of LINEUP_ROW.
		local backRow = math.max(0, 16 - Config.Sim.LINEUP_ROW)
		local light = 0
		for k = 0, 15 do
			if Budget.lineupLight(3, k // Config.Sim.LINEUP_ROW, P.CLONE_LOD.FAR + 10, k == 15) then
				light += 1
			end
		end
		check(light == backRow - 1, string.format("Line-up tier 3: %d of 16 figures light (back row, not you)", light))
		info(
			string.format(
				"Line-up tier 3: ~%dk tris saved (%d figures light at ~%d tris instead of ~%dk)",
				light * (P.AVATAR_TRIS_EST - P.MANNEQUIN_TRIS) // 1000,
				light,
				P.MANNEQUIN_TRIS,
				P.AVATAR_TRIS_EST // 1000
			)
		)
	end
	table.insert(results, "      " .. line("Line-up (16 figures)", lineupT))
	table.insert(results, "      " .. line("Gus x2", gusT))
	table.insert(results, "      " .. line("backdrop (tier 4)", tallyOf(bdFolder)))
	info(string.format("WorldView adds %d instances to the L6 level on the client", worldAdded))
	check(lineupT.billboards <= Budget.forTier(3).lineupLabels, "Line-up billboards within the tier 3 budget")
	check(lineupT.highlights <= 4, "Line-up: one Highlight per owner (4)")

	---------------------------------------------------------------------------
	-- C. Recipe C "Soft Toybox" and back
	---------------------------------------------------------------------------
	lights.setTier(1)
	local wasBrightness, wasShadows = Lighting.Brightness, Lighting.GlobalShadows
	local okStyle, styleWas = pcall(function()
		return Lighting.LightingStyle
	end)
	lights.setTier(3)
	local recipe, styleOk = lights.recipe()
	local S = P.SOFT_TOYBOX.Lighting
	local bloomInst = Lighting:FindFirstChild("Bloom")
	local bloom: BloomEffect? = if bloomInst and bloomInst:IsA("BloomEffect") then bloomInst else nil
	check(
		recipe == "C"
			and math.abs(Lighting.Brightness - S.Brightness) < 1e-3
			and Lighting.GlobalShadows == false
			and math.abs(Lighting.ExposureCompensation - S.ExposureCompensation) < 1e-3
			and (bloom == nil or math.abs(bloom.Intensity - P.SOFT_TOYBOX.Bloom.Intensity) < 1e-3),
		string.format(
			"tier 3: recipe C Soft Toybox (Brightness %.2f, GlobalShadows %s, Bloom %.2f)",
			Lighting.Brightness,
			tostring(Lighting.GlobalShadows),
			if bloom then bloom.Intensity else -1
		)
	)
	local styleSoft = styleNow()
	info(
		string.format(
			"Lighting.LightingStyle by script: write %s (boot %s, tier 1 %s, tier 3 %s)",
			if styleOk then "accepted" else "refused",
			styleAtBoot,
			if okStyle then tostring(styleWas) else "?",
			styleSoft
		)
	)
	lights.setTier(4)
	check(bloom == nil or bloom.Enabled == false, "tier 4: Bloom off")
	lights.setTier(2)
	lights.setTier(1)
	recipe = lights.recipe()
	check(
		recipe == "A"
			and math.abs(Lighting.Brightness - wasBrightness) < 1e-3
			and Lighting.GlobalShadows == wasShadows
			and (bloom == nil or bloom.Enabled == true)
			and styleNow() == styleAtBoot,
		string.format(
			"back at tier 1: recipe A restored (Brightness %.2f, LightingStyle %s)",
			Lighting.Brightness,
			styleNow()
		)
	)
	local mem4 = memory()
	memDelta(memV0, mem4, "the whole client view built here (clones, Line-up, Gus, backdrop, WorldView)")

	echo.clear()
	gus.clear()
	lights.clear()
	backdrop.clear()
	lineup:Destroy()
end

-- D. WORLD 2.0 (docs/audit/LEVELS.md §10): the snowy neighbourhood the client builds round every level instance and
-- the garage, counted against Config.Backdrop.TOWN.BUDGET: instances, no Light at all, the kit pieces really placed
-- (BackdropKit published them), every building there, the lot fence colliding, nothing else colliding.
do
	local TB = Config.Backdrop.TOWN.BUDGET
	local BackdropKitD = require(heistServer:WaitForChild("BackdropKit"))
	local okPub, published = pcall(BackdropKitD.publish, KitService)
	check(
		okPub and published == #BackdropKitD.pieces(),
		string.format(
			"world 2.0: BackdropKit published %s of %d kit pieces",
			tostring(published),
			#BackdropKitD.pieces()
		)
	)
	local BackdropPlanD = require(shared:WaitForChild("Heist"):WaitForChild("BackdropPlan"))
	local town = Backdrop.new()
	local sitesD = {}
	for i = 1, math.min(6, #instances) do
		local e = instances[i]
		table.insert(sitesD, {
			name = string.format("instance %d %s", i, e.id),
			show = function()
				return town.showHeist(e.inst.built.model, e.inst.level, e.inst.origin, true)
			end,
			plan = function()
				local loc = e.inst.built.model:GetAttribute("Location")
				return BackdropPlanD.plan(BackdropPlanD.levelSite(e.inst.level, loc), true)
			end,
		})
	end
	table.insert(sitesD, {
		name = "garage",
		show = town.showGarage,
		plan = function()
			return BackdropPlanD.plan(BackdropPlanD.garageSite(), nil)
		end,
	})
	for _, sd in sitesD do
		local okShow, showErr = pcall(sd.show)
		local f = workspace:FindFirstChild("EH_Backdrop")
		local plan = sd.plan()
		local n, lightsN, kitN, fallbacks, bodies, fenceOk, colliders = 0, 0, 0, 0, 0, 0, 0
		for _, d in (f and f:GetDescendants()) or {} do
			n += 1
			if d:IsA("Light") then
				lightsN += 1
			elseif d:IsA("MeshPart") then
				kitN += 1
			elseif d:IsA("BasePart") then
				if d.Name == "Body" then
					bodies += 1
				elseif d.Name == "LotFence" then
					fenceOk += if d.CanCollide and not d.CanQuery and d.Transparency >= 1 then 1 else 0
				elseif d.Name == "LampPost" or d.Name == "RoofFallback" then
					fallbacks += 1
				end
				if d.CanCollide and d.Name ~= "LotFence" then
					colliders += 1
				end
			end
		end
		n += 1 -- the folder
		check(
			okShow and f ~= nil and n <= TB.instances and lightsN == 0,
			string.format(
				"world 2.0: %s surroundings built: %d instances (budget %d), %d lights%s",
				sd.name,
				n,
				TB.instances,
				lightsN,
				if okShow then "" else " (" .. tostring(showErr) .. ")"
			)
		)
		local ringPieces = 0
		for _, r in plan.rings do
			ringPieces += 2 * #r.yaws
		end
		check(
			kitN >= #plan.kit + ringPieces and fallbacks == 0,
			string.format(
				"world 2.0: %s kit pieces placed %d / %d (+ %d ring), %d box fallbacks left",
				sd.name,
				kitN,
				#plan.kit,
				ringPieces,
				fallbacks
			)
		)
		check(
			bodies == plan.facades and bodies >= 14 and fenceOk == 4 and colliders == 0,
			string.format(
				"world 2.0: %s %d buildings, lot fence %d / 4, %d other colliders",
				sd.name,
				bodies,
				fenceOk,
				colliders
			)
		)
		town.clear()
	end
end

-- E. BIG buildings (PLAN_FIRST_PERSON §5, Config.Big.BUDGET): each kit-built instance's Overhead (ceiling, storeys,
-- roof) counted on the real build: instances, triangles and batches at tier 1 and from the detail tier, no Light,
-- nothing colliding, queried, touched or casting a shadow; and the warehouse garage's Overhead.
do
	local BB = Config.Big.BUDGET
	for i = 1, math.min(6, #instances) do
		local e = instances[i]
		local over = e.inst.built.model:FindFirstChild("Overhead")
		local t = tallyOf(over)
		local detail = bigDetailTris(e.inst.built.model)
		local loud = 0
		for _, d in (over and over:GetDescendants()) or {} do
			if d:IsA("BasePart") and (d.CanCollide or d.CanQuery or d.CanTouch or d.CastShadow) then
				loud += 1
			end
		end
		local tris = t.kitTris + t.primTris
		check(
			over ~= nil
				and t.instances <= BB.instances
				and tris <= BB.tris
				and batchCount(t) <= BB.draws
				and t.lights == 0
				and loud == 0,
			string.format(
				"big: instance %d %s building (%s): %d instances / %d, ~%dk tris / %dk (tier %d+: ~%dk), ~%d batches / %d, %d lights, %d loud parts",
				i,
				e.id,
				tostring(over and over:GetAttribute("Style")),
				t.instances,
				BB.instances,
				tris // 1000,
				BB.tris // 1000,
				Config.Big.DETAIL_OFF_TIER,
				(tris - detail) // 1000,
				batchCount(t),
				BB.draws,
				t.lights,
				loud
			)
		)
	end
	local gOver = garage:FindFirstChild("Overhead")
	local gt = tallyOf(gOver)
	check(
		gOver ~= nil and gt.lights == 0,
		string.format(
			"big: the warehouse garage's Overhead: %d instances, ~%dk tris, ~%d batches, %d lights",
			gt.instances,
			(gt.kitTris + gt.primTris) // 1000,
			batchCount(gt),
			gt.lights
		)
	)
end

for _, e in instances do
	pcall(HeistService.destroyInstance, e.inst)
end

table.insert(results, string.format("%d failure(s)", failures))
return table.concat(results, "\n")
