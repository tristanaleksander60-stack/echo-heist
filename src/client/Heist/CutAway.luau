--!strict
-- Heist/CutAway: the camera-aware cut-away for the BIG buildings (PLAN_FIRST_PERSON §5 "BIG"; Config.Big.CUT; the
-- rule is Shared/Heist/CutMath). In diorama, classic and every presentation shot (the run-start beat from above, the
-- level intro and golden staging through CameraDirector.setShot, the 8 OF ME pull-back and the busted view through
-- setMomentShot, the Line-up while LineupDirector holds the camera), roofs, ceilings and upper floors between the
-- camera and its subject fade out locally (LocalTransparencyModifier), and the whole top of the building you stand in
-- opens like a dollhouse once the camera rises above its ceiling. First person never hides them: while the camera is
-- at your eyes everything is shown, so you always have a ceiling over you indoors and the storeys over the street.
-- Crew View (CameraDirector.crewShot) is the exception: while it is held the cut is decided from the crew shot (the
-- full overhead, not the camera half way up), so the ceilings open as the camera starts to rise.
--
-- What it binds: the "Overhead" models of the heist level (server Heist/Overhead) or of the garage (Heist/Lobby), each
-- child Model a group with EH_CutKind / EH_CutMin / EH_CutMax (+ EH_CutNormal / EH_CutPlane for faces), and the town's
-- tall buildings (Heist/Backdrop.addOccluders: occlusion rule only). Batched: one decision pass at CUT.HZ, then each
-- group's parts are written only while its fade moves; no per-frame allocation (the subject buffer and the decision
-- table are reused). It also hides the "detail" layer from Config.Big.DETAIL_OFF_TIER and the "fine" / "xmas" layers
-- from FINE_OFF_TIER (Transparency 1,
-- restored when the tier steps back up). Binds after the camera (RenderPriority.Camera + 10), so it sees the frame
-- every camera writer produced this frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local CutMath = require(Shared:WaitForChild("Heist"):WaitForChild("CutMath"))

local CutAway = {}

local BIG = Config.Big
local CUT = BIG.CUT
local RENDER_NAME = "EH_CutAway"
local MAX_SUBJECTS = 4

type GroupState = {
	math: CutMath.Group,
	parts: { any }, -- BaseParts (and the town skins' Textures): whatever carries a LocalTransparencyModifier
	guis: { SurfaceGui },
	alpha: number,
	target: number,
	written: number,
}
type Building = {
	math: CutMath.Building,
	floorY: number,
	groups: { GroupState },
	maths: { CutMath.Group },
	hide: { boolean },
	occluder: boolean,
}

local function groupMath(m: Instance): CutMath.Group?
	local kind = m:GetAttribute("EH_CutKind")
	local lo, hi = m:GetAttribute("EH_CutMin"), m:GetAttribute("EH_CutMax")
	if type(kind) ~= "string" or typeof(lo) ~= "Vector3" or typeof(hi) ~= "Vector3" then
		return nil
	end
	local n = m:GetAttribute("EH_CutNormal")
	local plane = m:GetAttribute("EH_CutPlane")
	return {
		kind = kind,
		minX = lo.X,
		minY = lo.Y,
		minZ = lo.Z,
		maxX = hi.X,
		maxY = hi.Y,
		maxZ = hi.Z,
		nx = if typeof(n) == "Vector3" then n.X else 0,
		nz = if typeof(n) == "Vector3" then n.Z else 0,
		plane = if type(plane) == "number" then plane else 0,
	}
end

-- director: Heist/CameraDirector (mode(), eye(), presenting(), crewShot()); nil in tests.
function CutAway.new(director: any?): any
	local self = {}
	local buildings: { Building } = {}
	local stateOf: { [Instance]: GroupState } = {} -- group Model -> its state (parts added late find it)
	local detail: { { part: BasePart, base: number, off: number } } = {} -- off: the tier the layer hides from
	local conns: { RBXScriptConnection } = {}
	local tier = 1
	local subj: { number } = table.create(MAX_SUBJECTS * 3, 0)
	local clock = 0
	local player = Players.LocalPlayer

	local function offTier(layer: any): number?
		if layer == "detail" then
			return BIG.DETAIL_OFF_TIER
		elseif layer == "fine" or layer == "xmas" then
			return BIG.FINE_OFF_TIER
		end
		return nil
	end

	local function addPart(st: GroupState, p: Instance)
		if p:IsA("BasePart") then
			table.insert(st.parts, p)
			if st.written > 0 then
				p.LocalTransparencyModifier = st.written
			end
			local off = offTier(p:GetAttribute("EH_Layer"))
			if off then
				table.insert(detail, { part = p, base = p.Transparency, off = off })
				if tier >= off then
					p.Transparency = 1
				end
			end
		elseif p:IsA("SurfaceGui") then
			table.insert(st.guis, p)
		end
	end

	local function addOverhead(model: Instance)
		local ceil = model:GetAttribute("CeilY")
		local lo, hi = model:GetAttribute("OuterMin"), model:GetAttribute("OuterMax")
		if type(ceil) ~= "number" or typeof(lo) ~= "Vector3" or typeof(hi) ~= "Vector3" then
			return
		end
		local b: Building = {
			math = { ceilY = ceil, minX = lo.X, maxX = hi.X, minZ = lo.Z, maxZ = hi.Z },
			floorY = (model:GetAttribute("FloorY") :: number?) or lo.Y,
			groups = {},
			maths = {},
			hide = {},
			occluder = false,
		}
		for _, g in model:GetChildren() do
			local gm = if g:IsA("Model") then groupMath(g) else nil
			if gm then
				local st: GroupState = { math = gm, parts = {}, guis = {}, alpha = 0, target = 0, written = 0 }
				for _, d in g:GetDescendants() do
					addPart(st, d)
				end
				stateOf[g] = st
				table.insert(b.groups, st)
				table.insert(b.maths, gm)
				table.insert(b.hide, false)
			end
		end
		table.insert(buildings, b)
	end

	local function write(st: GroupState, alpha: number)
		if alpha == st.written then
			return
		end
		st.written = alpha
		for _, p in st.parts do
			p.LocalTransparencyModifier = alpha
		end
		local on = alpha < 0.98
		for _, gui in st.guis do
			gui.Enabled = on
		end
	end

	-- Stops: every faded part shown again, every detail part back to its own transparency.
	function self.clear()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		for _, b in buildings do
			for _, st in b.groups do
				st.alpha, st.target = 0, 0
				write(st, 0)
			end
		end
		for _, d in detail do
			if d.part.Parent then
				d.part.Transparency = d.base
			end
		end
		table.clear(buildings)
		table.clear(stateOf)
		table.clear(detail)
	end

	-- Binds a level model or the garage: its Overhead models now and any that arrive later (the garage's kit).
	function self.bind(root: Instance?)
		self.clear()
		if root == nil then
			return
		end
		for _, d in root:GetDescendants() do
			if d.Name == "Overhead" and d:GetAttribute("EH_Kind") == "overhead" then
				addOverhead(d)
			end
		end
		table.insert(
			conns,
			root.DescendantAdded:Connect(function(d: Instance)
				if d.Name == "Overhead" and d:GetAttribute("EH_Kind") == "overhead" then
					task.defer(function()
						if d.Parent then
							addOverhead(d)
						end
					end)
					return
				end
				local g = d.Parent
				while g and g ~= root do
					local st = stateOf[g]
					if st then
						addPart(st, d)
						return
					end
					g = g.Parent
				end
			end)
		)
	end

	-- The town's tall buildings (Heist/Backdrop): each { parts, min, max } hides by the occlusion rule only.
	function self.addOccluders(list: { { parts: { any }, min: Vector3, max: Vector3 } })
		if #list == 0 then
			return
		end
		local b: Building = {
			math = { ceilY = math.huge, minX = 0, maxX = 0, minZ = 0, maxZ = 0 },
			floorY = 0,
			groups = {},
			maths = {},
			hide = {},
			occluder = true,
		}
		for _, o in list do
			local gm: CutMath.Group = {
				kind = "occluder",
				minX = o.min.X,
				minY = o.min.Y,
				minZ = o.min.Z,
				maxX = o.max.X,
				maxY = o.max.Y,
				maxZ = o.max.Z,
				nx = 0,
				nz = 0,
				plane = 0,
			}
			table.insert(b.groups, { math = gm, parts = o.parts, guis = {}, alpha = 0, target = 0, written = 0 })
			table.insert(b.maths, gm)
			table.insert(b.hide, false)
		end
		table.insert(buildings, b)
	end

	-- Drops the town's occluders (the backdrop is rebuilt): their parts are gone with it.
	function self.clearOccluders()
		for i = #buildings, 1, -1 do
			if buildings[i].occluder then
				for _, st in buildings[i].groups do
					write(st, 0)
				end
				table.remove(buildings, i)
			end
		end
	end

	function self.setTier(t: number)
		if t == tier then
			return
		end
		tier = t
		for _, d in detail do
			if d.part.Parent then
				d.part.Transparency = if tier < d.off then d.base else 1
			end
		end
	end

	-- The subjects this frame (into `subj`): your feet and head, and where the camera's look ray meets the floor (the
	-- diorama's focus, a shot's subject). Returns how many points, and whether the camera is at your eyes (first
	-- person: nothing hides).
	local function subjects(view: CFrame): (number, boolean)
		local presenting = director ~= nil and director.presenting()
		local crew = director ~= nil and director.crewShot ~= nil and director.crewShot() ~= nil
		local cp = view.Position
		if director ~= nil and director.mode() == "fp" and not presenting and not crew then
			return 0, true
		end
		local eye = director and director.eye()
		if not crew and eye and (eye.Position - cp).Magnitude <= CUT.EYE_WITHIN then
			return 0, true
		end
		local n = 0
		local char = player and player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local p = root.Position
			subj[1], subj[2], subj[3] = p.X, p.Y + 1.5, p.Z
			subj[4], subj[5], subj[6] = p.X, p.Y - 2.2, p.Z
			n = 2
		end
		do
			local floorY = if #buildings > 0 then buildings[1].floorY else 0
			local lv = view.LookVector
			local x, y, z =
				CutMath.lookPoint(cp.X, cp.Y, cp.Z, lv.X, lv.Y, lv.Z, floorY + CUT.LOOK_HEIGHT, CUT.LOOK_MAX)
			if x and y and z then
				subj[3 * n + 1], subj[3 * n + 2], subj[3 * n + 3] = x, y, z
				n += 1
			end
		end
		return n, false
	end

	local function step(dt: number)
		if #buildings == 0 then
			return
		end
		-- Crew View decides from its full overhead shot; everything else from the camera itself.
		local cam = workspace.CurrentCamera
		local crewShot: CFrame? = if director ~= nil and director.crewShot ~= nil then director.crewShot() else nil
		local view: CFrame? = crewShot or (cam and cam.CFrame)
		if not view then
			return
		end
		clock += dt
		if clock >= 1 / CUT.HZ then
			clock = 0
			local n, eyes = subjects(view)
			local cp = view.Position
			for _, b in buildings do
				if eyes or n == 0 then
					for _, st in b.groups do
						st.target = 0
					end
				else
					CutMath.decide(b.math, b.maths, cp.X, cp.Y, cp.Z, subj, n, CUT.MARGIN, CUT.INSIDE_PAD, b.hide)
					for i, st in b.groups do
						st.target = if b.hide[i] then 1 else 0
					end
				end
			end
		end
		for _, b in buildings do
			for _, st in b.groups do
				if st.alpha ~= st.target then
					st.alpha = CutMath.step(st.alpha, st.target, dt, CUT.SECONDS)
					write(st, st.alpha)
				end
			end
		end
	end

	if RunService:IsClient() then
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 10, function(dt: number)
			debug.profilebegin("EH.CutAway")
			step(dt)
			debug.profileend()
		end)
	end

	-- Tests (tests/client_engine.luau, a server with no render loop): one frame of the cut-away by hand.
	function self.tick(dt: number)
		step(dt)
	end

	-- Tests and the debug chip: what is bound and what is hidden now.
	function self.debugState(): any
		local groups, hidden = 0, 0
		for _, b in buildings do
			for _, st in b.groups do
				groups += 1
				hidden += if st.written > 0.5 then 1 else 0
			end
		end
		return { buildings = #buildings, groups = groups, hidden = hidden, detail = #detail, tier = tier }
	end

	return self
end

return CutAway
