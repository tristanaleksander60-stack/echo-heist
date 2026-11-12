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
-- Sound (docs/AUDIO.md §9 items 15-17): a GusStep every GUS_STEP_STRIDE studs, a
-- GusRadio blip now and then on patrol, a Heartbeat tick while his "?" is on you (the
-- "?" and "!" stings come from the Suspect / Caught events). Sprint dust puffs while
-- he chases (Alarm Run, §7.3). A Santa hat when the Christmas dressing layer is on.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Sim = Shared:WaitForChild("Sim")
local Guards = require(Sim:WaitForChild("Guards"))
local Mechanisms = require(Sim:WaitForChild("Mechanisms"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Strings = require(Shared:WaitForChild("Heist"):WaitForChild("Strings"))

local Rigs = require(script.Parent:WaitForChild("Rigs"))
local Sound = require(script.Parent:WaitForChild("Sound"))

local H = Config.Heist
local S = Config.Sim
local AU = Config.Audio
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

-- Sizes two wedges to fill triangle a-b-c (all points on one plane) and appends their
-- CFrames (in the frame a, b, c are given in) to `cfs`.
local function triangle(w1: BasePart, w2: BasePart, a: Vector3, b: Vector3, c: Vector3, cfs: { CFrame })
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
		table.insert(cfs, CFrame.new(a))
		table.insert(cfs, CFrame.new(a))
		return
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	w1.Size = Vector3.new(0.05, height, math.abs(ab:Dot(back)))
	w2.Size = Vector3.new(0.05, height, math.abs(ac:Dot(back)))
	table.insert(cfs, CFrame.fromMatrix((a + b) / 2, right, up, back))
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

	local rng = Random.new()
	local function radioGap(): number
		local r = AU.GUS_RADIO_SECONDS
		return rng:NextNumber(r[1], r[2])
	end

	function view.setLevel(level: any)
		view.clear()
		for i, def in level.guards do
			local rig = Rigs.buildGus(state.dressing == true)
			rig.model.Parent = folder
			local head = Rigs.anchorPart(rig)
			local feetPart = rig.limbs[#rig.limbs].part
			local dustAt = Instance.new("Attachment")
			dustAt.Name = "EH_Dust"
			dustAt.Position = Vector3.new(0, -1, 0)
			dustAt.Parent = feetPart
			local dust = Instance.new("ParticleEmitter")
			dust.Rate = 0
			dust.Lifetime = NumberRange.new(0.3, 0.5)
			dust.Speed = NumberRange.new(1, 3)
			dust.SpreadAngle = Vector2.new(60, 20)
			dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.2) })
			dust.Transparency = NumberSequence.new(0.4, 1)
			dust.Color = ColorSequence.new(Palette.steelHi)
			dust.Parent = dustAt
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
			local conePartList: { BasePart } = {}
			for k = 1, H.CONE_RAYS - 1 do
				table.insert(conePartList, wedges[k][1])
				table.insert(conePartList, wedges[k][2])
				table.insert(conePartList, edges[k])
			end
			local key = "G" .. tostring(i)
			guards[i] = {
				def = def,
				rig = rig,
				label = label,
				cone = cone,
				wedges = wedges,
				edges = edges,
				coneParts = conePartList, -- wedge, wedge, edge per segment
				coneLocal = {} :: { CFrame }, -- their CFrames in Gus's apex frame (rebuilt at CONE_HZ)
				shownColour = nil :: Color3?,
				shownFill = -1,
				kMode = key .. "Mode",
				kOffset = key .. "Offset",
				kX = key .. "X",
				kZ = key .. "Z",
				kYaw = key .. "Yaw",
				kMeter = key .. "Meter",
				kStage = key .. "Stage",
				kFocus = key .. "Focus",
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
				stepDist = 0,
				nextRadio = os.clock() + radioGap(),
				nextBeat = 0,
				nextDust = 0,
				dust = dust,
				head = head,
			}
		end
	end

	-- The local player's live actor this run (for the heartbeat while "?" is on you).
	local function myActor(): number
		local run = state.run
		local lp = Players.LocalPlayer
		if not run or not lp then
			return -1
		end
		for _, a in run.actors do
			if a.kind == "live" and a.owner == lp.UserId then
				return a.id
			end
		end
		return -1
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
	local boxes: { any } = {} -- reused every ray pass
	local doorIn = { open = false, solid = true, solidAt = nil :: number? }
	local localPts: { Vector3 } = {}
	local doorKeys: { { string } } = {}

	local function doorKeysFor(level: any): { { string } }
		if #doorKeys ~= #level.doors then
			table.clear(doorKeys)
			for di = 1, #level.doors do
				local k = "D" .. tostring(di)
				doorKeys[di] = { k .. "Open", k .. "Solid", k .. "SolidAt" }
			end
		end
		return doorKeys
	end

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
		local running = state.phase == "Run"
		local me = myActor()
		local dKeys = doorKeysFor(level)
		for _, g in guards do
			local mode = folderInst:GetAttribute(g.kMode) or "Patrol"
			local tx, tz, tyaw
			if mode == "Patrol" then
				tx, tz, tyaw = Guards.patrol(g.def.route, tView - (folderInst:GetAttribute(g.kOffset) or 0))
				g.x, g.z, g.yaw = tx, tz, tyaw
			else
				tx = folderInst:GetAttribute(g.kX) or g.x
				tz = folderInst:GetAttribute(g.kZ) or g.z
				tyaw = folderInst:GetAttribute(g.kYaw) or g.yaw
				local k = math.clamp(dt * 10, 0, 1)
				g.x += (tx - g.x) * k
				g.z += (tz - g.z) * k
				local d = (tyaw - g.yaw + math.pi) % TAU - math.pi
				g.yaw = (g.yaw + d * k) % TAU
			end
			local moved = math.sqrt((g.x - g.lastX) ^ 2 + (g.z - g.lastZ) ^ 2)
			g.lastX, g.lastZ = g.x, g.z
			local speed = if dt > 0 then moved / dt else 0
			-- Footsteps by distance walked (a teleport-sized jump is not a step).
			if running and moved < 3 then
				g.stepDist += moved
				if g.stepDist >= AU.GUS_STEP_STRIDE then
					g.stepDist = 0
					Sound.play("GusStep", { at = g.head })
				end
			end
			if running and mode == "Patrol" and now >= g.nextRadio then
				g.nextRadio = now + radioGap()
				Sound.play("GusRadio", { at = g.head })
			end
			if running and mode == "Chase" and speed > 1 and now >= g.nextDust then
				g.nextDust = now + H.GUS_DUST_SECONDS
				g.dust:Emit(3)
			end
			g.phase += speed * 0.35 * dt * TAU
			local feet = CFrame.new(origin + Vector3.new(g.x, floorY, g.z)) * CFrame.Angles(0, g.yaw, 0)
			Rigs.pose(g.rig, feet, g.phase, math.clamp(speed / 8, 0, 1), parts, cfs)

			-- Rays (CONE_HZ): sight boxes plus doors that look shut. The cone's shape (wedge
			-- and edge sizes, their CFrames in Gus's apex frame) only changes here; every
			-- frame in between just moves the parts with Gus.
			if now >= g.nextRays then
				g.nextRays = now + 1 / H.CONE_HZ
				table.clear(boxes)
				table.move(level.occluders, 1, #level.occluders, 1, boxes)
				for di, door in level.doors do
					local k = dKeys[di]
					local solidAt = folderInst:GetAttribute(k[3])
					doorIn.open = folderInst:GetAttribute(k[1]) == true
					doorIn.solid = folderInst:GetAttribute(k[2]) ~= false
					doorIn.solidAt = if type(solidAt) == "number" and solidAt >= 0 then solidAt else nil
					if Mechanisms.doorViewOf(doorIn, tView) == "shut" then
						table.insert(boxes, door.box)
					end
				end
				for r = 1, H.CONE_RAYS do
					local rel = half - (r - 1) * (2 * half) / (H.CONE_RAYS - 1)
					local a = g.yaw + rel
					local len = rayBoxes(boxes, g.x, g.z, -math.sin(a), -math.cos(a), range)
					g.rays[r] = len
					localPts[r] = Vector3.new(-math.sin(rel) * len, 0, -math.cos(rel) * len)
				end
				local out = g.coneLocal
				table.clear(out)
				for k = 1, H.CONE_RAYS - 1 do
					local w = g.wedges[k]
					local a, b = localPts[k], localPts[k + 1]
					triangle(w[1], w[2], Vector3.zero, a, b, out)
					local len = (b - a).Magnitude
					g.edges[k].Size = Vector3.new(0.15, 0.05, math.max(len, 0.05))
					table.insert(out, if len > 1e-3 then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a))
				end
			end
			local apexFrame = CFrame.new(origin + Vector3.new(g.x, floorY + 0.12, g.z)) * CFrame.Angles(0, g.yaw, 0)
			local meter = folderInst:GetAttribute(g.kMeter) or 0
			local stage = folderInst:GetAttribute(g.kStage) or 0
			-- Heartbeat while his "?" is on you (Warnings bus, §7.3).
			local focus = folderInst:GetAttribute(g.kFocus)
			if running and stage >= 2 and focus == me and me > 0 and now >= g.nextBeat then
				g.nextBeat = now + H.GUS_HEARTBEAT_SECONDS
				Sound.play("Heartbeat")
			end
			local banging = now < g.bangUntil
			local colour = if banging then Palette.alarm else Palette.amber
			local fill = if banging then 0.45 elseif stage >= 2 then 0.5 elseif meter > 0 then 0.62 else 0.75
			-- Colour and fill only when they change (wedges fill, edges keep their glow).
			if colour ~= g.shownColour or fill ~= g.shownFill then
				g.shownColour, g.shownFill = colour, fill
				for k = 1, H.CONE_RAYS - 1 do
					local w = g.wedges[k]
					w[1].Color, w[2].Color = colour, colour
					w[1].Transparency, w[2].Transparency = fill, fill
					g.edges[k].Color = colour
				end
			end
			local coneLocal = g.coneLocal
			for j, part in g.coneParts do
				local lcf = coneLocal[j]
				if lcf then
					table.insert(parts, part)
					table.insert(cfs, apexFrame * lcf)
				end
			end
			-- Bubble: "!" on a catch, "?" while suspicious, "huh?" when confused.
			if banging then
				g.label.Text = Strings.GUS_SPOTTED
				g.label.TextColor3 = Palette.alarm
			elseif mode == "Huh" then
				g.label.Text = Strings.GUS_HUH
				g.label.TextColor3 = Palette.white
			elseif stage >= 2 or mode == "Suspicious" then
				g.label.Text = Strings.GUS_SUSPICIOUS
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
