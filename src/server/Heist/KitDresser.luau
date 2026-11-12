--!strict
-- Heist/KitDresser: dresses a greybox level copy (Heist/LevelBuilder) with art kit pieces
-- from src/server/Kit/KitService, following Heist/KitPlan. docs/art/KIT_IMPORT.md, spike S2.
--
-- Collision never changes: every static kit piece is visual only (CanCollide, CanTouch and
-- CanQuery off), and the greybox solid it dresses stays where it is as an invisible
-- collider (Transparency 1, the sim's exact box). The swapped door leaves and plates are
-- kit MeshParts scaled to the very same boxes with Box collision; a piece that did not get
-- its Box fidelity at boot (KitService report().fidelityKept) is never swapped in.
--
-- Two phases: every kit part is created first (inside pcall: any error destroys what was
-- made and the greybox stays untouched), then committed (greybox solids hidden, tagged
-- parts swapped, greybox laser posts / hide frames removed). Tagged parts keep their
-- EH_Kind / EH_Index / EH_Id, so clients bind to kit parts exactly as to greybox ones.
--
-- Vault doors get a client-drawn swing skin (Heist/Protocol "doorSkin"): built invisible,
-- the real transparency in EH_Alpha; the greybox leaf stays the tagged, colliding part.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local KitPlan = require(script.Parent:WaitForChild("KitPlan"))
local LevelDress = require(script.Parent:WaitForChild("LevelDress"))

local KitDresser = {}

export type DressOpts = {
	dressing: boolean?, -- Christmas layer
	location: string?, -- atlas and street front ("CornerShop" | "ToyShop" | "Bank")
	floor: boolean?,
	floorLift: number?,
}

export type Result = {
	ok: boolean,
	pieces: number, -- kit parts placed
	items: number,
	failed: number, -- plan items that could not be built (their greybox stays visible)
	swapped: number,
	why: string?,
}

-- Pieces that collide when swapped in: only used with their manifest (Box) fidelity.
local COLLIDING = Config.Kit.COLLIDER_PIECES

-- Plan roles a level must not lose half-way: if one of these fails, the result is not ok
-- (the Kit attribute stays false: a mixed kit/greybox shell is reported as greybox).
local STRUCTURAL = { wall = true, door = true, plate = true }

local warnedIncomplete = false

local function cframeOf(origin: Vector3, c: { number }, yaw: number): CFrame
	return CFrame.new(origin + Vector3.new(c[1], c[2], c[3])) * CFrame.Angles(0, math.rad(yaw), 0)
end

local function visualOnly(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

local function copyTags(from: Instance, to: Instance)
	for _, key in { "EH_Kind", "EH_Index", "EH_Id", "EH_Value" } do
		local v = from:GetAttribute(key)
		if v ~= nil then
			to:SetAttribute(key, v)
		end
	end
end

local function childrenOfKind(parent: Instance, kinds: { string }): { Instance }
	local out = {}
	for _, d in parent:GetDescendants() do
		local k = d:GetAttribute("EH_Kind")
		if k and table.find(kinds, k) then
			table.insert(out, d)
		end
	end
	return out
end

local function hideGreybox(part: Instance)
	for _, d in part:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CastShadow = false
		end
	end
	if part:IsA("BasePart") then
		part.Transparency = 1
		part.CastShadow = false
	end
end

-- Builds the plan's kit parts on top of `built` (LevelBuilder.Built) for `level`.
function KitDresser.dress(level: any, built: any, origin: Vector3, kit: any, opts: DressOpts?): Result
	local o: DressOpts = opts or {}
	local result: Result = { ok = false, pieces = 0, items = 0, failed = 0, swapped = 0, why = nil }
	if not (kit and kit.isReady and kit.isReady()) then
		result.why = "kit not ready"
		return result
	end
	-- A failed or partial kit boot (missing pieces, size errors) keeps the whole level greybox.
	local bootReport = kit.report and kit.report()
	if not (bootReport and bootReport.ok) then
		result.why = "kit incomplete"
		if not warnedIncomplete then
			warnedIncomplete = true
			warn(
				"[KitDresser] the kit did not load completely: levels stay greybox ("
					.. tostring(kit.summary and kit.summary() or "no report")
					.. ")"
			)
		end
		return result
	end
	local specs: { [string]: any } = {}
	for _, name in kit.names() do
		local spec = kit.spec(name)
		if spec then
			specs[name] = spec
		end
	end
	local avoid: { [string]: boolean } = {}
	for _, line in bootReport.fidelityKept or {} do
		local name = string.match(line, "^(%S+)")
		if name and COLLIDING[name] then
			avoid[name] = true
		end
	end
	local plan = KitPlan.plan(level, specs, {
		dressing = o.dressing,
		location = o.location,
		floor = o.floor,
		floorLift = o.floorLift,
		avoid = avoid,
		dress = LevelDress[level.id],
		lighting = Config.Lighting,
	})
	result.items = #plan.items
	local atlas = o.location
	-- the van's runtime paint (Van_Paint is a tintable, atlas-free piece): a mid value, never Getaway White
	local vp = Config.Lighting.VAN.paint
	local vanPaint = Color3.fromRGB(vp[1], vp[2], vp[3])

	local container = Instance.new("Model")
	container.Name = "Kit"
	container:SetAttribute("EH_Kind", "kit")
	local made: { { Instance } } = {} -- per item: its parts (or skin model), in plan order
	local itemOk: { boolean } = {}

	local okBuild, err = pcall(function()
		for idx, item in plan.items do
			local parts: { Instance } = {}
			local good = true
			for _, name in item.pieces do
				local part = kit.clone(name, { atlas = atlas, color = if name == "Van_Paint" then vanPaint else nil })
				if part == nil then
					good = false
					break
				end
				local c, size = KitPlan.partFrame(specs[name], item.pivot, item.scale)
				part.Size = Vector3.new(size[1], size[2], size[3])
				part.CFrame = cframeOf(origin, c, item.pivot.yaw)
				if
					item.mode == "swap"
					and (item.role == "door" or item.role == "plate")
					and name ~= "Plate_4x4_Ring"
				then
					part.Anchored = true
					part.CanCollide = true
					part.CanTouch = true
					part.CanQuery = true
				else
					visualOnly(part)
				end
				if item.mode == "skin" then
					part:SetAttribute("EH_Alpha", part.Transparency)
					part.Transparency = 1
				end
				table.insert(parts, part)
			end
			if not good then
				for _, p in parts do
					p:Destroy()
				end
				table.clear(parts)
			end
			made[idx] = parts
			itemOk[idx] = good
		end
	end)
	if not okBuild then
		for _, parts in made do
			for _, p in parts do
				p:Destroy()
			end
		end
		container:Destroy()
		result.why = "build: " .. tostring(err)
		return result
	end

	-- Commit: parent the kit, hide what it covers, swap tagged parts.
	local structuralFailed = 0
	local okCommit, commitErr = pcall(function()
		local model: Model = built.model
		local postsDone: { [number]: boolean } = {}
		local hidesDone: { [number]: boolean } = {}
		for idx, item in plan.items do
			local parts = made[idx]
			if not itemOk[idx] then
				result.failed += 1
				if STRUCTURAL[item.role] then
					structuralFailed += 1
				end
				continue
			end
			result.pieces += #parts
			local ref, index = item.ref, item.index
			if item.mode == "swap" and index then
				local first = parts[1] :: BasePart
				local old: BasePart? = nil
				if ref == "door" then
					old = built.doors[index]
				elseif ref == "plate" then
					old = built.plates[index]
				elseif ref == "loot" then
					old = built.loot[index]
				end
				if old then
					first.Name = old.Name
					copyTags(old, first)
					first:SetAttribute("KitPiece", item.pieces[1])
					if ref == "plate" then
						for k = 2, #parts do
							local ring = parts[k] :: BasePart
							ring:SetAttribute("EH_Kind", "rim")
							ring.Color = Palette.bulbWarm -- idle glow (WorldView breathes it, LEVELS P0-1)
							ring.Parent = first
						end
						for _, cable in childrenOfKind(old, { "cable" }) do
							cable.Parent = first
						end
						-- The plate's letter moves onto the kit plate's top face (the greybox pad and
						-- its icon go; LEVELS P0-1).
						local top = first.Position.Y + first.Size.Y / 2
						for _, letter in childrenOfKind(old, { "plateLetter" }) do
							if letter:IsA("BasePart") then
								local p = letter.Position
								letter.CFrame = letter.CFrame
									+ Vector3.new(0, top + 0.01 - (p.Y - letter.Size.Y / 2), 0)
							end
							letter.Parent = first
						end
						built.plates[index] = first
					elseif ref == "door" then
						built.doors[index] = first
					elseif ref == "loot" then
						first.CanTouch = false
						built.loot[index] = first
					end
					first.Parent = old.Parent
					old:Destroy()
					result.swapped += 1
				else
					for _, p in parts do
						p:Destroy()
					end
				end
			elseif item.mode == "dress" and index then
				local host: Instance? = if ref == "laser" then built.lasers[index] else built.hides[index]
				if host then
					for _, p in parts do
						p.Parent = host
					end
					if ref == "laser" then
						postsDone[index] = true
					else
						hidesDone[index] = true
					end
				end
			elseif item.mode == "skin" and index then
				local skin = Instance.new("Model")
				skin.Name = "DoorSkin_" .. index
				skin:SetAttribute("EH_Kind", "doorSkin")
				skin:SetAttribute("EH_Index", index)
				skin:SetAttribute("EH_Mode", "swing")
				skin:SetAttribute("EH_OpenYaw", item.openYaw or -175)
				for _, p in parts do
					p.Parent = skin
				end
				local hinge = item.hinge and specs[item.hinge]
				local pivotCf = cframeOf(origin, { item.pivot.x, item.pivot.y, item.pivot.z }, item.pivot.yaw)
				if hinge then
					local ho = hinge.origin
					pivotCf = pivotCf * CFrame.new(ho[1] * item.scale[1], ho[2] * item.scale[2], ho[3] * item.scale[3])
				end
				skin.WorldPivot = pivotCf
				skin.Parent = model
				local leaf = built.doors[index]
				if leaf then
					leaf:SetAttribute("EH_HasSkin", true)
				end
			else
				for _, p in parts do
					p.Parent = container
				end
				if (item.role == "till" or item.role == "display") and index then
					for _, stand in childrenOfKind(model, { "stand" }) do
						if stand:GetAttribute("EH_Index") == index then
							stand:Destroy()
						end
					end
				elseif item.role == "lamp" and index and built.lamps and built.lamps[index] then
					-- the kit lamp has its own Neon bulb; the greybox bulb keeps the light, unseen
					hideGreybox(built.lamps[index])
				elseif item.role == "switch" and index and built.switches[index] then
					hideGreybox(built.switches[index])
				elseif item.role == "van" then
					-- The kit van is visual only; the greybox van body keeps its size and
					-- place as the collider (collision never changes, HeistKitPlan spec).
					-- Tagged so the client can bounce it when loot is banked (WorldView, FEEDBACK_TABLE "Van").
					for _, p in parts do
						p:SetAttribute("EH_Kind", "vanKit")
					end
					local body = built.vanBody
					local vb = plan.vanBox
					if body then
						hideGreybox(body)
						if vb then
							-- the drawn van's footprint (the Line-up keeps its row clear of it)
							body:SetAttribute(
								"EH_VisualSize",
								Vector3.new(vb.maxX - vb.minX, vb.maxY - vb.minY, vb.maxZ - vb.minZ)
							)
						end
					end
				end
			end
		end
		-- Greybox solids fully covered by kit pieces become invisible colliders.
		for solidIndex, list in plan.solids do
			local all = true
			for _, idx in list do
				all = all and itemOk[idx] == true
			end
			local part = built.solids[solidIndex]
			if all and part then
				hideGreybox(part)
			end
		end
		for index in postsDone do
			local laser = built.lasers[index]
			if laser then
				for _, post in childrenOfKind(laser, { "post" }) do
					post:Destroy()
				end
			end
		end
		for index in hidesDone do
			local hide = built.hides[index]
			if hide then
				for _, frame in childrenOfKind(hide, { "hideTop", "hideFrame" }) do
					frame:Destroy()
				end
			end
		end
		container.Parent = model
	end)
	if not okCommit then
		warn("[KitDresser] commit stopped part-way (greybox kept where it was not swapped): " .. tostring(commitErr))
		container.Parent = built.model
		result.why = "commit: " .. tostring(commitErr)
	end
	-- Kit = true only for a level actually dressed with nothing structural missing.
	result.ok = okCommit and result.pieces > 0 and structuralFailed == 0
	if okCommit and not result.ok then
		result.why = string.format("%d piece(s), %d structural item(s) failed", result.pieces, structuralFailed)
	end
	return result
end

return KitDresser
