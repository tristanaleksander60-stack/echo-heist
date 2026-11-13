--!strict
-- Kit/KitService: the art kit as a template library, loaded at server boot without Studio
-- (spike S2, automated path; docs/art/KIT_IMPORT.md "Automated path").
--
-- tools/kit_upload.py uploads each kit model group (assets/fbx/<Model>.fbx) as an Open Cloud Model asset
-- owned by the experience owner and generates KitData (ids + kit_manifest.json). At boot this service:
--   1. loads every group with InsertService:LoadAsset (pcall, retries with backoff, bounded concurrency);
--      a Rojo-mapped ServerStorage/Kit (the manual Kit.rbxm path) is used instead when it exists;
--   2. finds the pieces through a MeshPart name map (never FindFirstChild(name, true): uploaded groups nest
--      Model > Model > MeshPart and many pieces share their Model's name);
--   3. rebuilds a piece with AssetService:CreateMeshPartAsync when its CollisionFidelity differs from the
--      manifest (uploads arrive with Default; fidelity cannot be changed on a loaded part). Chosen over an
--      invisible Box collider: it gives Hull and PreciseConvexDecomposition too (vault frame, door frames,
--      street fronts, van) and a single part stays a single part for part:PivotTo (leaves, safe door, Gus);
--   4. applies what runtime can set: Anchored, CanCollide/CanTouch, CastShadow, Material, Color, Transparency,
--      the one shared atlas texture, and PivotOffset from the manifest bounds (uploads arrive with a rotated
--      pivot basis), and clones the pre-built hero SurfaceAppearance (VaultDoor_DialFace) from its uploaded
--      Model asset (scripts cannot write SurfaceAppearance maps at runtime);
--   5. checks every size (and centre position) against the manifest and keeps a report.
-- Templates live in ServerStorage/<Config.Kit.FOLDER>/<Model>. Place clones with PivotTo / GetPivot only.
--
-- API (server only; not wired into the heist server yet):
--   KitService.start()                      begin loading (idempotent; ready() calls it)
--   KitService.ready(timeout?) -> boolean    yield until loaded; true when every piece is in the library
--   KitService.isReady() -> boolean          loaded (no yield)
--   KitService.has(name) -> boolean
--   KitService.clone(name, opts?) -> MeshPart?   one piece, at its scene position (part:PivotTo it)
--   KitService.cloneModel(model, opts?) -> Model? a whole group, pivot = the group's scene origin
--   KitService.spec(name) -> PartSpec?       the manifest entry (size, bounds, origin, flags)
--   KitService.names() -> { string }         every piece in the library, sorted
--   KitService.atlas(location?) -> string    the atlas texture URI for "Bank" / "CornerShop" / "ToyShop"
--   KitService.report() -> Report            what happened at boot (missing, size errors, fidelity, timing)
--   KitService.summary() -> string           one line for logs
-- opts: { atlas: string? (location atlas swap on atlas pieces), color: Color3? }

local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local KitLib = require(Shared:WaitForChild("Kit"):WaitForChild("KitLib"))
local KitData = require(script.Parent:WaitForChild("KitData")) :: any

local KitService = {}

export type CloneOptions = { atlas: string?, color: Color3? }
export type Report = {
	done: boolean,
	ok: boolean,
	source: string, -- "cloud" (LoadAsset) | "rojo" (ServerStorage/Kit was already there)
	expected: number,
	loaded: number,
	groups: number,
	groupsFailed: { string },
	missing: { string },
	extra: { string },
	duplicates: { string },
	sizeErrors: { string },
	positionErrors: { string },
	importedFidelity: { [string]: number }, -- fidelity name -> pieces that arrived with it
	rebuilt: number,
	fidelityKept: { string }, -- pieces still not on their manifest fidelity
	problems: { string }, -- KitData validation
	atlas: string,
	atlasSource: string,
	hero: string, -- how VaultDoor_DialFace is textured
	seconds: number,
}

type Spec = KitLib.PartSpec

local cfg = Config.Kit
local data = KitData :: KitLib.KitData
local specs: { [string]: Spec } = data.parts

local state: "idle" | "loading" | "done" = "idle"
local waiters: { thread } = {}
local templates: { [string]: MeshPart } = {}
local models: { [string]: Model } = {}
local atlasUris: { [string]: string } = {}
local warnedAtlas: { [string]: boolean } = {}
local found: { [string]: MeshPart } = {}

local function newReport(): Report
	return {
		done = false,
		ok = false,
		source = "cloud",
		expected = 0,
		loaded = 0,
		groups = 0,
		groupsFailed = {},
		missing = {},
		extra = {},
		duplicates = {},
		sizeErrors = {},
		positionErrors = {},
		importedFidelity = {},
		rebuilt = 0,
		fidelityKept = {},
		problems = {},
		atlas = "",
		atlasSource = "",
		hero = "",
		seconds = 0,
	}
end

local report: Report = newReport()

-- Runs fn over items with at most n threads; returns when every item is done.
local function pool<T>(items: { T }, n: number, fn: (T) -> ())
	local queue = table.clone(items)
	local running = math.min(math.max(1, n), #queue)
	if running == 0 then
		return
	end
	local finished = Instance.new("BindableEvent")
	local function worker()
		while #queue > 0 do
			local item = table.remove(queue, 1) :: T
			local ok, err = pcall(fn, item)
			if not ok then
				warn("[Kit] " .. tostring(err))
			end
		end
		running -= 1
		if running == 0 then
			finished:Fire()
		end
	end
	for _ = 1, running do
		task.spawn(worker)
	end
	if running > 0 then
		finished.Event:Wait()
	end
	finished:Destroy()
end

local function backoff(attempt: number)
	task.wait(cfg.RETRY_BASE_SECONDS * 2 ^ (attempt - 1))
end

local function loadAsset(id: number): Instance?
	for attempt = 1, cfg.LOAD_ATTEMPTS do
		local ok, result = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		if ok and typeof(result) == "Instance" then
			return result
		end
		if attempt < cfg.LOAD_ATTEMPTS then
			backoff(attempt)
		else
			warn(string.format("[Kit] LoadAsset(%d) failed after %d tries: %s", id, attempt, tostring(result)))
		end
	end
	return nil
end

local function color3(hex: string?): Color3
	if hex then
		local r, g, b = KitLib.hex(hex)
		if r and g and b then
			return Color3.new(r, g, b)
		end
	end
	return Color3.new(1, 1, 1)
end

local function folder(): Folder
	local existing = ServerStorage:FindFirstChild(cfg.FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = cfg.FOLDER
	f.Parent = ServerStorage
	return f
end

local function modelFor(name: string, parent: Folder): Model
	local m = models[name]
	if m then
		return m
	end
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Model") then
		m = existing
	else
		m = Instance.new("Model")
		m.Name = name
		m.Parent = parent
	end
	models[name] = m :: Model
	return m :: Model
end

-- Phase 1: one group's MeshParts into `found` (cloud path).
local function loadGroup(model: string, pieces: { string })
	local id = data.assets[model]
	local container = if id then loadAsset(id) else nil
	if container == nil then
		table.insert(
			report.groupsFailed,
			if id then string.format("%s (LoadAsset %d)", model, id) else model .. " (no asset id)"
		)
		for _, name in pieces do
			table.insert(report.missing, name)
		end
		return
	end
	local map, dups = KitLib.nameMap(container:GetDescendants())
	local missing, extra = KitLib.matchGroup(pieces, map)
	for _, name in dups do
		table.insert(report.duplicates, model .. "/" .. name)
	end
	for _, name in missing do
		table.insert(report.missing, name)
	end
	for _, name in extra do
		table.insert(report.extra, model .. "/" .. name)
	end
	for _, name in pieces do
		local mesh = map[name]
		if mesh then
			mesh.Parent = nil
			found[name] = mesh
		end
	end
	report.groups += 1
	container:Destroy()
end

-- Phase 1 (rojo path): pieces that are already under ServerStorage/Kit.
local function indexExisting(kit: Folder): boolean
	local map, dups = KitLib.nameMap(kit:GetDescendants())
	if next(map) == nil then
		return false
	end
	report.source = "rojo"
	for _, name in dups do
		table.insert(report.duplicates, name)
	end
	local groups = KitLib.groups(specs)
	for model, pieces in groups do
		local missing = KitLib.matchGroup(pieces, map)
		for _, name in missing do
			table.insert(report.missing, name)
		end
		if #missing < #pieces then
			report.groups += 1
		end
		for _, name in pieces do
			if map[name] then
				found[name] = map[name]
			end
		end
		local m = kit:FindFirstChild(model)
		if m and m:IsA("Model") then
			models[model] = m
		end
	end
	for name in map do
		if specs[name] == nil then
			table.insert(report.extra, name)
		end
	end
	return true
end

-- A Decal's image id: the recorded one, else resolved once at boot (LoadAsset of the Decal).
local function imageUri(stem: string): string
	local img = data.images[stem]
	if img == nil then
		return ""
	end
	if img.image then
		return KitLib.uri(img.image)
	end
	local loaded = loadAsset(img.decal)
	if loaded == nil then
		return ""
	end
	local decal = if loaded:IsA("Decal") then loaded else loaded:FindFirstChildWhichIsA("Decal", true)
	local uri = ""
	if decal and decal:IsA("Decal") then
		local digits = string.match(decal.Texture, "(%d+)%s*$")
		uri = if digits then KitLib.uri(digits) else decal.Texture
	end
	loaded:Destroy()
	return uri
end

local function resolveAtlases()
	-- Fallback for Bank: the atlas texture the FBX import made (every atlas piece embeds the same image).
	local fallback = ""
	local names = {}
	for name in found do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		if specs[name].atlas and found[name].TextureID ~= "" then
			fallback = found[name].TextureID
			break
		end
	end
	-- Resolve uploaded images first (a LoadAsset per Decal without a recorded image id), then pick per location.
	local resolved: { [string]: string } = {}
	local stems = {}
	for stem in data.images do
		table.insert(stems, stem)
	end
	pool(stems, cfg.LOAD_CONCURRENCY, function(stem: string)
		resolved[stem] = imageUri(stem)
	end)
	local images: { [string]: { decal: number, image: number? } } = {}
	for stem, img in data.images do
		local digits = string.match(resolved[stem] or "", "(%d+)$")
		images[stem] = { decal = img.decal, image = if digits then tonumber(digits) else nil }
	end
	local view: KitLib.KitData = { parts = specs, assets = data.assets, images = images, atlases = data.atlases }
	local locations = {}
	for loc in data.atlases do
		table.insert(locations, loc)
	end
	table.sort(locations)
	for _, loc in locations do
		local uri, source = KitLib.atlasUri(loc, cfg.Atlas, view, if loc == "Bank" then fallback else "")
		if uri ~= "" then
			atlasUris[loc] = uri
		end
		if loc == "Bank" then
			report.atlas = uri
			report.atlasSource = source
		end
	end
end

-- Hero SurfaceAppearances (pieces with a manifest `texture`, e.g. VaultDoor_DialFace). Runtime scripts cannot
-- write SurfaceAppearance maps (ColorMapContent needs Plugin capability, measured Nov 12), so tools/kit_upload.py
-- --appearances uploads them pre-built as one Model asset; loading, cloning and parenting them is allowed.
local appearances: { [string]: SurfaceAppearance } = {}

local function loadAppearances()
	local id = data.appearances
	if id == nil then
		return
	end
	local loaded = loadAsset(id)
	if loaded == nil then
		return
	end
	for _, d in loaded:GetDescendants() do
		if d:IsA("SurfaceAppearance") and appearances[d.Name] == nil then
			appearances[d.Name] = d
		end
	end
	for _, sa in appearances do
		sa.Parent = nil
	end
	loaded:Destroy()
end

local function rebuild(mesh: MeshPart, spec: Spec): MeshPart?
	local fidelity = (Enum.CollisionFidelity :: any)[spec.collision]
	for attempt = 1, cfg.REBUILD_ATTEMPTS do
		local ok, made = pcall(function()
			return AssetService:CreateMeshPartAsync(mesh.MeshContent, {
				CollisionFidelity = fidelity,
				RenderFidelity = mesh.RenderFidelity,
			})
		end)
		if ok and typeof(made) == "Instance" and made:IsA("MeshPart") then
			made.Name = mesh.Name
			made.Size = mesh.Size
			made.CFrame = mesh.CFrame
			made.TextureID = mesh.TextureID
			for _, child in mesh:GetChildren() do
				child.Parent = made
			end
			return made
		end
		if attempt < cfg.REBUILD_ATTEMPTS then
			backoff(attempt)
		else
			warn(
				string.format("[Kit] CreateMeshPartAsync(%s, %s) failed: %s", mesh.Name, spec.collision, tostring(made))
			)
		end
	end
	return nil
end

-- Phase 2: one piece to a finished template.
local function prepare(name: string, kit: Folder)
	local spec = specs[name]
	local fidelityWanted = KitLib.gameCollision(name, spec, cfg.COLLIDER_PIECES)
	if fidelityWanted ~= spec.collision then
		spec = table.clone(spec)
		spec.collision = fidelityWanted -- visual-only piece: Box data, not a precise decomposition
	end
	local part = found[name]
	local fid = part.CollisionFidelity.Name
	report.importedFidelity[fid] = (report.importedFidelity[fid] or 0) + 1
	if KitLib.needsRebuild(fid, spec, cfg.REBUILD_FIDELITY) then
		local made = rebuild(part, spec)
		if made then
			part:Destroy()
			part = made
			report.rebuilt += 1
		end
	end
	if part.CollisionFidelity.Name ~= spec.collision then
		table.insert(
			report.fidelityKept,
			name .. " " .. part.CollisionFidelity.Name .. " (want " .. spec.collision .. ")"
		)
	end

	part.Anchored = true
	part.CanCollide = spec.canCollide
	part.CanTouch = spec.canCollide
	part.CastShadow = spec.castShadow
	part.Material = (Enum.Material :: any)[spec.material]
	part.Color = color3(spec.color)
	part.Transparency = spec.transparency or 0
	if spec.atlas then
		part.TextureID = atlasUris.Bank or part.TextureID
	elseif spec.texture then
		-- The hero face: SurfaceAppearance from the uploaded maps, else the colour map the import made.
		local sa = appearances[name]
		if sa then
			for _, old in part:GetChildren() do
				if old:IsA("SurfaceAppearance") then
					old:Destroy()
				end
			end
			sa:Clone().Parent = part
			part.TextureID = ""
			report.hero = "SurfaceAppearance"
		else
			report.hero = if part.TextureID ~= "" then "imported texture (no appearances asset)" else "none"
		end
	else
		part.TextureID = "" -- runtime-tinted Neon and glass parts carry no texture
	end
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") and not spec.texture then
			child:Destroy()
		end
	end
	local po = KitLib.pivotOffset(spec)
	part.PivotOffset = CFrame.new(po[1], po[2], po[3])
	part:SetAttribute("KitPiece", name)

	local s = part.Size
	local sizeErr = KitLib.sizeError(s.X, s.Y, s.Z, spec.size)
	if sizeErr > cfg.SIZE_TOLERANCE then
		table.insert(
			report.sizeErrors,
			string.format(
				"%s %.3f x %.3f x %.3f (want %g x %g x %g)",
				name,
				s.X,
				s.Y,
				s.Z,
				spec.size[1],
				spec.size[2],
				spec.size[3]
			)
		)
		-- Resilience: an asset re-uploaded under the same id with new proportions (LoadAsset always gets the
		-- latest version) must not turn the whole game back to greybox. Scale the piece to the size this
		-- build's KitData expects, so placement stays right; the size error stays in the report, so
		-- tests/kit_engine still fails until KitData is regenerated (kit_upload.py --gen).
		part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
	end
	if report.source == "cloud" then
		local want = KitLib.scenePosition(spec)
		local p = part.Position
		local posErr = KitLib.sizeError(p.X, p.Y, p.Z, want)
		if posErr > cfg.POSITION_TOLERANCE then
			table.insert(
				report.positionErrors,
				string.format("%s centre %s (want %g, %g, %g)", name, tostring(p), want[1], want[2], want[3])
			)
		end
	end
	part.Parent = modelFor(spec.model, kit)
	templates[name] = part
end

local function finish()
	state = "done"
	report.done = true
	local list = waiters
	waiters = {}
	for _, thread in list do
		task.spawn(thread)
	end
end

local function boot()
	local t0 = os.clock()
	report.problems = KitLib.validate(data, false)
	for _, p in report.problems do
		warn("[Kit] data: " .. p)
	end
	local groups, order = KitLib.groups(specs)
	for _ in specs do
		report.expected += 1
	end

	local kit = folder()
	if not indexExisting(kit) then
		pool(order, cfg.LOAD_CONCURRENCY, function(model: string)
			loadGroup(model, groups[model])
		end)
	end
	resolveAtlases()
	loadAppearances()

	local names = {}
	for name in found do
		table.insert(names, name)
	end
	table.sort(names)
	pool(names, cfg.REBUILD_CONCURRENCY, function(name: string)
		prepare(name, kit)
	end)
	for _, m in models do
		m.WorldPivot = CFrame.identity
	end
	found = {}

	for _ in templates do
		report.loaded += 1
	end
	table.sort(report.missing)
	table.sort(report.sizeErrors)
	table.sort(report.positionErrors)
	table.sort(report.fidelityKept)
	report.seconds = os.clock() - t0
	-- Every piece loaded is enough to dress levels: size errors were scaled to spec above (logged, and
	-- failed by tests/kit_engine), so one re-uploaded asset never sends the live game back to greybox.
	report.ok = report.loaded == report.expected
	print("[Kit] " .. KitService.summary())
	finish()
end

function KitService.start()
	if state ~= "idle" then
		return
	end
	state = "loading"
	task.spawn(function()
		local ok, err = pcall(boot)
		if not ok then
			warn("[Kit] boot failed: " .. tostring(err))
			report.seconds = 0
			finish()
		end
	end)
end

function KitService.isReady(): boolean
	return state == "done"
end

function KitService.ready(timeout: number?): boolean
	KitService.start()
	if state ~= "done" then
		local thread = coroutine.running()
		table.insert(waiters, thread)
		local limit = timeout or cfg.READY_TIMEOUT
		task.delay(limit, function()
			local i = table.find(waiters, thread)
			if i then
				table.remove(waiters, i)
				task.spawn(thread)
			end
		end)
		coroutine.yield()
	end
	return state == "done" and report.ok
end

function KitService.has(name: string): boolean
	return templates[name] ~= nil
end

function KitService.spec(name: string): Spec?
	return specs[name]
end

function KitService.names(): { string }
	local out = {}
	for name in templates do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

function KitService.atlas(location: string?): string
	local loc = location or "Bank"
	local uri = atlasUris[loc]
	if uri == nil then
		if not warnedAtlas[loc] then
			warnedAtlas[loc] = true
			warn(
				"[Kit] no atlas for "
					.. loc
					.. " (upload assets/textures with tools/kit_upload.py --images); using Bank"
			)
		end
		return atlasUris.Bank or ""
	end
	return uri
end

local function dress(part: MeshPart, opts: CloneOptions?)
	if opts == nil then
		return
	end
	local spec = specs[part.Name]
	if opts.atlas and spec and spec.atlas then
		local uri = KitService.atlas(opts.atlas)
		if uri ~= "" then
			part.TextureID = uri
		end
	end
	if opts.color then
		part.Color = opts.color
	end
end

function KitService.clone(name: string, opts: CloneOptions?): MeshPart?
	local template = templates[name]
	if template == nil then
		return nil
	end
	local part = template:Clone()
	dress(part, opts)
	return part
end

function KitService.cloneModel(model: string, opts: CloneOptions?): Model?
	local template = models[model]
	if template == nil or state ~= "done" then
		return nil
	end
	local copy = template:Clone()
	if opts and opts.atlas then
		for _, d in copy:GetDescendants() do
			if d:IsA("MeshPart") then
				dress(d, { atlas = opts.atlas })
			end
		end
	end
	return copy
end

function KitService.report(): Report
	return report
end

function KitService.summary(): string
	local r = report
	return string.format(
		"%d/%d pieces (%s, %d groups) in %.1f s; rebuilt %d for collision; %d missing, %d size errors, "
			.. "%d position errors, %d off-fidelity; atlas %s (%s); hero %s",
		r.loaded,
		r.expected,
		r.source,
		r.groups,
		r.seconds,
		r.rebuilt,
		#r.missing,
		#r.sizeErrors,
		#r.positionErrors,
		#r.fidelityKept,
		if r.atlas ~= "" then r.atlas else "none",
		r.atlasSource,
		if r.hero ~= "" then r.hero else "-"
	)
end

return KitService
