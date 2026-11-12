--!strict
-- Heist/WorldView: doors, lasers, plates, loot and the van as this client sees them
-- (MASTERPLAN §7.3, §8.2, §8.10 rule 2). The server built the parts once and never
-- touches them again; this view moves and colours them locally from the replicated
-- state attributes:
--   * Doors: Mechanisms.doorViewOf on the loop clock. Slide up in 0.35 s when open,
--     amber lamp blink while closing; solid in this client's own physics from
--     VISUAL_LEAD before the server makes it solid (what you see is never more
--     generous than the server).
--   * Lasers: Mechanisms.laserViewOf: on, off, or the 3-flicker telegraph.
--   * Plates: sink 0.15 studs, the rim and cable take the presser's hue; the cable
--     drains over the 0.4 s grace.
--   * Loot: at home, in its carrier's hands, dropped, or gone (banked).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Mechanisms = require(Shared:WaitForChild("Sim"):WaitForChild("Mechanisms"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local H = Config.Heist

local WorldView = {}

local function num(v: any, default: number): number
	return if type(v) == "number" then v else default
end

function WorldView.new(state: any, positionOf: (actorId: number) -> Vector3?): any
	local view = {}
	local doors: { any } = {}
	local lasers: { any } = {}
	local plates: { any } = {}
	local loot: { any } = {}
	local chevrons: { BasePart } = {}
	local lamps: { [number]: BasePart } = {}

	function view.clear()
		table.clear(doors)
		table.clear(lasers)
		table.clear(plates)
		table.clear(loot)
		table.clear(chevrons)
		table.clear(lamps)
	end

	-- Binds to the level parts of the current instance (by EH_Kind / EH_Index).
	function view.bind(levelModel: Instance)
		view.clear()
		for _, d in levelModel:GetDescendants() do
			local kind = d:GetAttribute("EH_Kind")
			local index = d:GetAttribute("EH_Index")
			if kind == "door" and d:IsA("BasePart") then
				doors[index] = { part = d, base = d.CFrame, height = d.Size.Y, lift = 0, view = "shut" }
			elseif kind == "lamp" and d:IsA("BasePart") then
				lamps[index] = d
			elseif kind == "laser" and d:IsA("Model") then
				local beams = {}
				for _, b in d:GetDescendants() do
					if b:IsA("BasePart") and b:GetAttribute("EH_Kind") == "beam" then
						table.insert(beams, { part = b, base = b.Transparency })
					end
				end
				lasers[index] = { beams = beams, view = "on" }
			elseif kind == "plate" and d:IsA("BasePart") then
				local rim, cables = nil, {}
				for _, c in d:GetDescendants() do
					local k = c:GetAttribute("EH_Kind")
					if k == "rim" and c:IsA("BasePart") then
						rim = c
					elseif k == "cable" and c:IsA("BasePart") then
						table.insert(cables, c)
					end
				end
				plates[index] = {
					part = d,
					base = d.CFrame,
					rim = rim,
					rimBase = if rim then rim.CFrame else nil,
					cables = cables,
					sink = 0,
					hue = Palette.steelLo,
					drain = 0,
					held = false,
				}
			elseif kind == "loot" and d:IsA("BasePart") then
				loot[index] = { part = d, home = d.CFrame, spin = 0 }
			elseif kind == "chevron" and d:IsA("BasePart") then
				table.insert(chevrons, d)
			end
		end
	end

	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}

	local function actorHue(actorId: number): Color3
		local run = state.run
		local a = run and run.actorById[actorId]
		if not a then
			return Palette.white
		end
		if a.orphan then
			return Palette.tapeGrey
		end
		return Palette.hueFor(a.seat)
	end

	local function carrierPos(actorId: number): Vector3?
		local run = state.run
		local a = run and run.actorById[actorId]
		if not a then
			return nil
		end
		if a.kind == "clone" then
			return positionOf(actorId)
		end
		local player = Players:GetPlayerByUserId(a.owner)
		local char = player and player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root.Position
		end
		return nil
	end

	function view.update(tView: number, now: number, dt: number)
		local f: Instance? = state.folder
		if not f then
			return
		end
		local folder = f :: Instance
		table.clear(parts)
		table.clear(cfs)
		local origin: Vector3 = state.origin

		for i, d in doors do
			local solidAt = num(folder:GetAttribute("D" .. i .. "SolidAt"), -1)
			local v = Mechanisms.doorViewOf({
				open = folder:GetAttribute("D" .. i .. "Open") == true,
				solid = folder:GetAttribute("D" .. i .. "Solid") ~= false,
				solidAt = if solidAt >= 0 then solidAt else nil,
			}, tView)
			d.view = v
			local target = if v == "open" then d.height - 0.4 else 0
			local rate = d.height / H.DOOR_SLIDE_SECONDS
			if d.lift < target then
				d.lift = math.min(target, d.lift + rate * dt)
			elseif d.lift > target then
				d.lift = math.max(target, d.lift - rate * dt)
			end
			local shut = v == "shut"
			if d.part.CanCollide ~= shut then
				d.part.CanCollide = shut
			end
			table.insert(parts, d.part)
			table.insert(cfs, d.base + Vector3.new(0, d.lift, 0))
			local lamp = lamps[i]
			if lamp then
				if v == "open" then
					lamp.Color = Palette.ok
				elseif v == "closing" then
					lamp.Color = if math.floor(now * 8) % 2 == 0 then Palette.amber else Palette.ink
				else
					lamp.Color = Palette.alarm
				end
			end
		end

		for i, l in lasers do
			local onAt = num(folder:GetAttribute("L" .. i .. "OnAt"), -1)
			local v = Mechanisms.laserViewOf({
				on = folder:GetAttribute("L" .. i .. "On") ~= false,
				onAt = if onAt >= 0 then onAt else nil,
			}, tView)
			local visible = v == "on" or (v == "flicker" and math.floor(now * 10) % 2 == 0)
			for _, b in l.beams do
				local want = if visible then b.base else 1
				if b.part.Transparency ~= want then
					b.part.Transparency = want
				end
			end
			l.view = v
		end

		for i, p in plates do
			local held = folder:GetAttribute("P" .. i .. "Held") == true
			if held then
				local by = num(folder:GetAttribute("P" .. i .. "By"), 0)
				if by > 0 then
					p.hue = actorHue(by)
				end
				p.drain = 1
			elseif p.held then
				p.drain = 1
			end
			p.held = held
			if not held then
				p.drain = math.max(0, p.drain - dt / Config.Sim.PLATE_GRACE)
			end
			local sinkTarget = if held then H.PLATE_SINK else 0
			p.sink += (sinkTarget - p.sink) * math.clamp(dt / 0.06, 0, 1)
			table.insert(parts, p.part)
			table.insert(cfs, p.base - Vector3.new(0, p.sink, 0))
			local lit = p.drain > 0
			local colour = if lit then p.hue:Lerp(Palette.steelLo, 1 - p.drain) else Palette.steelLo
			if p.rim then
				p.rim.Color = colour
				p.rim.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
				table.insert(parts, p.rim)
				table.insert(cfs, (p.rimBase :: CFrame) - Vector3.new(0, p.sink, 0))
			end
			for _, c in p.cables do
				c.Color = colour
				c.Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
		end

		local carryingMine = false
		for i, k in loot do
			local st = folder:GetAttribute("K" .. i .. "State") or "Home"
			local cf: CFrame? = nil
			if st == "Home" then
				k.spin = (k.spin + dt * 1.2) % (2 * math.pi)
				cf = k.home * CFrame.Angles(0, k.spin, 0)
			elseif st == "Carried" then
				local carrier = num(folder:GetAttribute("K" .. i .. "Carrier"), 0)
				local pos = carrierPos(carrier)
				if pos then
					cf = CFrame.new(pos + Vector3.new(0, 2.6, 0))
				end
				local run = state.run
				local a = run and run.actorById[carrier]
				local lp = Players.LocalPlayer
				if a and a.kind == "live" and lp and a.owner == lp.UserId then
					carryingMine = true
				end
			elseif st == "Dropped" then
				local pos = folder:GetAttribute("K" .. i .. "Pos")
				if typeof(pos) == "Vector3" then
					cf = CFrame.new(origin + pos - Vector3.new(0, 2.4, 0))
				end
			end
			local hidden = st == "Banked" or cf == nil
			local want = if hidden then 1 else 0
			if k.part.Transparency ~= want then
				k.part.Transparency = want
			end
			if cf then
				table.insert(parts, k.part)
				table.insert(cfs, cf)
			end
		end
		state.carrying = carryingMine

		-- Van chevrons pulse while you carry loot (the way to bank it).
		for _, c in chevrons do
			c.Transparency = if carryingMine then 0.1 + 0.5 * (0.5 + 0.5 * math.sin(now * 6)) else 0.6
		end

		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	-- What the local player could use right now (contextual Interact): nearest loot.
	function view.nearestLoot(pos: Vector3, range: number): (number?, number)
		local f: Instance? = state.folder
		if not f then
			return nil, 0
		end
		local best, bestD, value = nil, range, 0
		for i, k in loot do
			local st = f:GetAttribute("K" .. i .. "State")
			if st == "Home" or st == "Dropped" then
				local p = k.part.Position
				local d = Vector3.new(p.X - pos.X, 0, p.Z - pos.Z).Magnitude
				if d <= bestD and math.abs(p.Y - pos.Y) <= Config.Sim.INTERACT_HEIGHT then
					best, bestD = i, d
					value = num(k.part:GetAttribute("EH_Value"), 0)
				end
			end
		end
		return best, value
	end

	function view.doorView(i: number): string
		local d = doors[i]
		return if d then d.view else "shut"
	end

	return view
end

return WorldView
