--!strict
-- Heist/Outlines: the ink outlines on THIS client (BLENDER LOOK track; docs/audit/BLENDER_LOOK.md, Config.Outline,
-- pure rules in Shared/Heist/OutlinePlan). KitService (server) welds an inverted hull onto every character / hero /
-- loot piece that has one (tag Kit.KitLib.OUTLINE_TAG); this module only writes each hull's
-- LocalTransparencyModifier (client-only, nothing replicates):
--   * every RECHECK_SECONDS it picks, per class, the tier's nearest few units inside the radius (OutlinePlan.pick):
--     a unit is a character model (all its hulls) or one hero / loot piece; a hidden unit takes no slot;
--   * at once, whenever a piece's Transparency or LocalTransparencyModifier changes, its hull follows
--     (OutlinePlan.visibility): a fading clone, the clone LOD swap, first person, a cut-away wall, picked-up loot.
-- Rigs never write a hull (Rigs.partsOf skips them), so there is one writer.
--
--   Outlines.new(deps?) -> view       deps.camera: Camera? (default: Workspace.CurrentCamera)
--     view.setTier(tier)
--     view.step(camPos?)              re-pick now (RenderStepped's clock calls it every RECHECK_SECONDS)
--     view.count() -> number          hulls drawn after the last pick
--     view.units() -> number          units seen in the last pick
--     view.destroy()

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local KitLib = require(Shared:WaitForChild("Kit"):WaitForChild("KitLib"))
local OutlinePlan = require(Shared:WaitForChild("Heist"):WaitForChild("OutlinePlan"))

local O = Config.Outline

local Outlines = {}

type Entry = { hull: BasePart, piece: BasePart, class: string, conns: { RBXScriptConnection } }

-- The unit a hull belongs to: a character's model (its outfit and body hulls go together), else the piece.
local function unitOf(piece: BasePart, class: string): Instance
	if class == "char" then
		local m = piece:FindFirstAncestorOfClass("Model")
		if m and m ~= Workspace then
			return m
		end
	end
	return piece
end

local function positionOf(u: Instance): Vector3
	if u:IsA("Model") then
		return u:GetPivot().Position
	end
	return (u :: BasePart).Position
end

function Outlines.new(deps: { camera: Camera? }?)
	local tier = 1
	local entries: { [BasePart]: Entry } = {}
	local picked: { [Instance]: boolean } = {}
	local drawn, seen = 0, 0
	local conns: { RBXScriptConnection } = {}

	local function apply(e: Entry)
		local unit = unitOf(e.piece, e.class)
		e.hull.LocalTransparencyModifier =
			OutlinePlan.visibility(picked[unit] == true, e.piece.Transparency, e.piece.LocalTransparencyModifier)
	end

	local function drop(hull: BasePart)
		local e = entries[hull]
		if e then
			for _, c in e.conns do
				c:Disconnect()
			end
			entries[hull] = nil
		end
	end

	local function track(inst: Instance)
		if not inst:IsA("BasePart") or entries[inst] then
			return
		end
		local hull = inst :: BasePart
		local piece = hull.Parent
		if not piece or not piece:IsA("BasePart") then
			return
		end
		local e: Entry = {
			hull = hull,
			piece = piece,
			class = tostring(hull:GetAttribute("EH_OutlineClass") or "char"),
			conns = {},
		}
		entries[hull] = e
		local function changed()
			apply(e)
		end
		table.insert(e.conns, piece:GetPropertyChangedSignal("Transparency"):Connect(changed))
		table.insert(e.conns, piece:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(changed))
		table.insert(
			e.conns,
			hull.AncestryChanged:Connect(function()
				if hull.Parent ~= piece then
					drop(hull)
				end
			end)
		)
		hull.LocalTransparencyModifier = 1 -- until the next pick says otherwise
	end

	local view = {}

	function view.step(camPos: Vector3?)
		local cam = (deps and deps.camera) or Workspace.CurrentCamera
		local at = camPos or (cam and cam.CFrame.Position) or Vector3.zero
		local lp = Players.LocalPlayer
		local me: Instance? = lp and lp.Character
		local units: { OutlinePlan.Unit } = {}
		local seenUnit: { [Instance]: boolean } = {}
		for _, e in entries do
			if not e.hull:IsDescendantOf(Workspace) then
				continue
			end
			local u = unitOf(e.piece, e.class)
			if not seenUnit[u] then
				seenUnit[u] = true
				local shown = OutlinePlan.visibility(true, e.piece.Transparency, e.piece.LocalTransparencyModifier) < 1
				table.insert(units, {
					key = u,
					class = e.class,
					dist = (positionOf(u) - at).Magnitude,
					shown = shown,
					own = me ~= nil and u == me,
				})
			end
		end
		seen = #units
		picked = OutlinePlan.pick(units, tier)
		drawn = 0
		for _, e in entries do
			apply(e)
			if e.hull.LocalTransparencyModifier < 1 then
				drawn += 1
			end
		end
	end

	function view.setTier(t: number)
		tier = t
		view.step()
	end

	function view.count(): number
		return drawn
	end

	function view.units(): number
		return seen
	end

	function view.destroy()
		for _, c in conns do
			c:Disconnect()
		end
		for hull in entries do
			drop(hull)
		end
	end

	for _, inst in CollectionService:GetTagged(KitLib.OUTLINE_TAG) do
		track(inst)
	end
	table.insert(conns, CollectionService:GetInstanceAddedSignal(KitLib.OUTLINE_TAG):Connect(track))
	table.insert(
		conns,
		CollectionService:GetInstanceRemovedSignal(KitLib.OUTLINE_TAG):Connect(function(inst: Instance)
			if inst:IsA("BasePart") then
				drop(inst)
			end
		end)
	)
	if RunService:IsClient() then
		local acc = 0
		table.insert(
			conns,
			RunService.Heartbeat:Connect(function(dt: number)
				acc += dt
				if acc >= O.RECHECK_SECONDS then
					acc = 0
					view.step()
				end
			end)
		)
	end
	return view
end

return Outlines
