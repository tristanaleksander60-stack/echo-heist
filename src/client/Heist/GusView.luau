--!strict
-- Heist/GusView: draws Gus and his vision cone on this client (MASTERPLAN §6.5 "Gus
-- and threats", §7.3 detection). While he patrols, his pose is Sim/Guards.patrol on
-- the replicated loop clock (minus the replicated offset), the same pure function the
-- server runs; when he stops ("?", "huh?") or chases, the client eases toward the
-- pose attributes the server sends at 10 Hz.
--
-- Cone: a flat floor fan in Torch Amber (Transparency 0.75, Neon edge), clipped by a
-- 12-ray fan at 10 Hz against the level's sight boxes and the doors that look shut.
-- Stages: amber fill while his meter rises, "?" at 0.6 s, "!" when he catches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Sim = Shared:WaitForChild("Sim")
local Guards = require(Sim:WaitForChild("Guards"))
local Mechanisms = require(Sim:WaitForChild("Mechanisms"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local Rigs = require(script.Parent:WaitForChild("Rigs"))

local H = Config.Heist
local S = Config.Sim
local TAU = 2 * math.pi

local GusView = {}

local function flat(name: string, className: string, parent: Instance): BasePart
	local p = Instance.new(className) :: BasePart
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Palette.amber
	p.Transparency = 0.75
	p.Parent = parent
	return p
end

-- Places two wedges so they fill triangle a-b-c (all points on one plane).
local function triangle(
	w1: BasePart,
	w2: BasePart,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	parts: { BasePart },
	cfs: { CFrame }
)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-4 or bc.Magnitude < 1e-4 then
		w1.Size = Vector3.new(0.05, 0.05, 0.05)
		w2.Size = w1.Size
		table.insert(parts, w1)
		table.insert(cfs, CFrame.new(a))
		table.insert(parts, w2)
		table.insert(cfs, CFrame.new(a))
		return
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	w1.Size = Vector3.new(0.05, height, math.abs(ab:Dot(back)))
	w2.Size = Vector3.new(0.05, height, math.abs(ac:Dot(back)))
	table.insert(parts, w1)
	table.insert(cfs, CFrame.fromMatrix((a + b) / 2, right, up, back))
	table.insert(parts, w2)
	table.insert(cfs, CFrame.fromMatrix((a + c) / 2, -right, up, -back))
end

-- Distance along a 2D ray to the first box, or `range`.
local function rayBoxes(boxes: { any }, ox: number, oz: number, dx: number, dz: number, range: number): number
	local best = range
	for _, b in boxes do
		local tmin, tmax = 0, best
		local ok = true
		for axis = 1, 2 do
			local o = if axis == 1 then ox else oz
			local d = if axis == 1 then dx else dz
			local lo = if axis == 1 then b.minX else b.minZ
			local hi = if axis == 1 then b.maxX else b.maxZ
			if math.abs(d) < 1e-9 then
				if o < lo or o > hi then
					ok = false
					break
				end
			else
				local t1, t2 = (lo - o) / d, (hi - o) / d
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				tmin = math.max(tmin, t1)
				tmax = math.min(tmax, t2)
				if tmin > tmax then
					ok = false
					break
				end
			end
		end
		if ok and tmin < best then
			best = tmin
		end
	end
	return best
end

function GusView.new(state: any): any
	local folder = Instance.new("Folder")
	folder.Name = "HeistGus"
	folder.Parent = workspace
	local guards: { any } = {}
	local view = {}

	function view.clear()
		folder:ClearAllChildren()
		table.clear(guards)
	end

	function view.setLevel(level: any)
		view.clear()
		for i, def in level.guards do
			local rig = Rigs.buildGus()
			rig.model.Parent = folder
			local head = Rigs.anchorPart(rig)
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(80, 60)
			gui.StudsOffset = Vector3.new(0, 2.6, 0)
			gui.LightInfluence = 0
			gui.AlwaysOnTop = true
			gui.MaxDistance = 120
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
			label.TextSize = 44
			label.TextStrokeTransparency = 0
			label.Text = ""
			label.Parent = gui
			gui.Adornee = head
			gui.Parent = head
			local cone = Instance.new("Model")
			cone.Name = "Cone"
			local wedges, edges = {}, {}
			for k = 1, H.CONE_RAYS - 1 do
				wedges[k] = { flat("W", "WedgePart", cone), flat("W", "WedgePart", cone) }
				local e = flat("Edge", "Part", cone)
				e.Material = Enum.Material.Neon
				e.Transparency = 0.2
				edges[k] = e
			end
			cone.Parent = folder
			guards[i] = {
				def = def,
				rig = rig,
				label = label,
				cone = cone,
				wedges = wedges,
				edges = edges,
				rays = table.create(H.CONE_RAYS, 0),
				nextRays = 0,
				x = 0,
				z = 0,
				yaw = 0,
				lastX = 0,
				lastZ = 0,
				phase = 0,
				bangUntil = 0,
				huhUntil = 0,
			}
		end
	end

	-- Gus caught someone ("!") or busted a clone.
	function view.bang(index: number, now: number)
		local g = guards[index]
		if g then
			g.bangUntil = now + 1.2
		end
	end

	-- Where Gus is drawn (level space), for the HUD and tests.
	function view.poseOf(index: number): (number, number, number)
		local g = guards[index]
		if not g then
			return 0, 0, 0
		end
		return g.x, g.z, g.yaw
	end

	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}

	function view.update(tView: number, now: number, dt: number)
		local folderInst: Instance? = state.folder
		local level = state.level
		if not folderInst or not level or #guards == 0 then
			return
		end
		table.clear(parts)
		table.clear(cfs)
		local origin: Vector3 = state.origin
		local floorY = level.floorY
		local crew = math.max(#(state.crew or {}), 1)
		local range = S.GUARD_VISION_RANGE * (1 + S.CREW_VISION_BONUS * (crew - 1))
		local half = math.rad(S.GUARD_VISION_HALF_ANGLE)
		for i, g in guards do
			local p = "G" .. i
			local mode = folderInst:GetAttribute(p .. "Mode") or "Patrol"
			local tx, tz, tyaw
			if mode == "Patrol" then
				tx, tz, tyaw = Guards.patrol(g.def.route, tView - (folderInst:GetAttribute(p .. "Offset") or 0))
				g.x, g.z, g.yaw = tx, tz, tyaw
			else
				tx = folderInst:GetAttribute(p .. "X") or g.x
				tz = folderInst:GetAttribute(p .. "Z") or g.z
				tyaw = folderInst:GetAttribute(p .. "Yaw") or g.yaw
				local k = math.clamp(dt * 10, 0, 1)
				g.x += (tx - g.x) * k
				g.z += (tz - g.z) * k
				local d = (tyaw - g.yaw + math.pi) % TAU - math.pi
				g.yaw = (g.yaw + d * k) % TAU
			end
			local moved = math.sqrt((g.x - g.lastX) ^ 2 + (g.z - g.lastZ) ^ 2)
			g.lastX, g.lastZ = g.x, g.z
			local speed = if dt > 0 then moved / dt else 0
			g.phase += speed * 0.35 * dt * TAU
			local feet = CFrame.new(origin + Vector3.new(g.x, floorY, g.z)) * CFrame.Angles(0, g.yaw, 0)
			Rigs.pose(g.rig, feet, g.phase, math.clamp(speed / 8, 0, 1), parts, cfs)

			-- Rays (10 Hz): sight boxes plus doors that look shut.
			if now >= g.nextRays then
				g.nextRays = now + 1 / H.CONE_HZ
				local boxes = table.clone(level.occluders)
				for di, door in level.doors do
					local dv = Mechanisms.doorViewOf({
						open = folderInst:GetAttribute("D" .. di .. "Open") == true,
						solid = folderInst:GetAttribute("D" .. di .. "Solid") ~= false,
						solidAt = (function()
							local v = folderInst:GetAttribute("D" .. di .. "SolidAt")
							return if type(v) == "number" and v >= 0 then v else nil
						end)(),
					}, tView)
					if dv == "shut" then
						table.insert(boxes, door.box)
					end
				end
				for r = 1, H.CONE_RAYS do
					local a = g.yaw + half - (r - 1) * (2 * half) / (H.CONE_RAYS - 1)
					local dx, dz = -math.sin(a), -math.cos(a)
					g.rays[r] = rayBoxes(boxes, g.x, g.z, dx, dz, range)
				end
			end
			local apex = origin + Vector3.new(g.x, floorY + 0.12, g.z)
			local pts = {}
			for r = 1, H.CONE_RAYS do
				local a = g.yaw + half - (r - 1) * (2 * half) / (H.CONE_RAYS - 1)
				local len = g.rays[r]
				pts[r] = apex + Vector3.new(-math.sin(a) * len, 0, -math.cos(a) * len)
			end
			local meter = folderInst:GetAttribute(p .. "Meter") or 0
			local stage = folderInst:GetAttribute(p .. "Stage") or 0
			local banging = now < g.bangUntil
			local colour = if banging then Palette.alarm else Palette.amber
			local fill = if banging then 0.45 elseif stage >= 2 then 0.5 elseif meter > 0 then 0.62 else 0.75
			for k = 1, H.CONE_RAYS - 1 do
				local w = g.wedges[k]
				triangle(w[1], w[2], apex, pts[k], pts[k + 1], parts, cfs)
				w[1].Color, w[2].Color = colour, colour
				w[1].Transparency, w[2].Transparency = fill, fill
				local e = g.edges[k]
				local a, b = pts[k], pts[k + 1]
				local len = (b - a).Magnitude
				e.Size = Vector3.new(0.15, 0.05, math.max(len, 0.05))
				e.Color = colour
				table.insert(parts, e)
				table.insert(cfs, if len > 1e-3 then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a))
			end
			-- Bubble: "!" on a catch, "?" while suspicious, "huh?" when confused.
			if banging then
				g.label.Text = "!"
				g.label.TextColor3 = Palette.alarm
			elseif mode == "Huh" then
				g.label.Text = "huh?"
				g.label.TextColor3 = Palette.white
			elseif stage >= 2 or mode == "Suspicious" then
				g.label.Text = "?"
				g.label.TextColor3 = Palette.amber
			else
				g.label.Text = ""
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	return view
end

return GusView
