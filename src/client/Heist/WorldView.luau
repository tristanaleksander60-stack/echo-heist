--!strict
-- Heist/WorldView: doors, lasers, plates, loot and the van as this client sees them
-- (MASTERPLAN §7.3, §8.2, §8.10 rule 2). The server built the parts once and never
-- touches them again; this view moves and colours them locally from the replicated
-- state attributes:
--   * Doors: Mechanisms.doorViewOf on the loop clock. Slide up in 0.35 s when open,
--     amber lamp blink (and DoorBeep) while closing; solid in this client's own physics
--     from VISUAL_LEAD before the server makes it solid (what you see is never more
--     generous than the server). A kit vault door (Protocol "doorSkin") hides its
--     greybox leaf locally and swings its skin about the hinge instead, the dial
--     turning as it opens; the leaf keeps the collision.
--   * Lasers: Mechanisms.laserViewOf: on, off, or the 3-flicker telegraph; a LaserHum
--     loop per laser near the camera, sparks when it retracts.
--   * Plates: sink 0.15 studs, the rim and cable take the presser's hue and the plate
--     shows the presser's glyph (colour is never the only signal, §0 C5); the cable
--     drains over the 0.4 s grace.
--   * Loot: at home, in its carrier's hands, dropped, or gone (banked). A time-locked
--     item (the Clone Party till, attribute K<i>OpensAt) shows "LOCKED 0:07".
--   * Alarm Run: rotating red beacons (emissive parts, no lights) on the van roof and
--     over the alarm's loot while AlarmOn; door lamps blink red.
-- Every blink is at most Config.Heist.BLINK_HZ_MAX flashes a second (§7.3) and holds
-- steady under reduced motion. Binding follows DescendantAdded too (StreamingEnabled-
-- ready: parts that arrive late are bound when they arrive). Per frame: attribute names
-- are built once at bind, view inputs reuse their tables, and a door or plate that did
-- not move is not moved again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Mechanisms = require(Shared:WaitForChild("Sim"):WaitForChild("Mechanisms"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local Sound = require(script.Parent:WaitForChild("Sound"))

local H = Config.Heist
local A = Config.Audio
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)

local WorldView = {}

local function num(v: any, default: number): number
	return if type(v) == "number" then v else default
end

local function billboard(adornee: BasePart, size: Vector2, offset: Vector3, distance: number): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "EH_Label"
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = distance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Palette.ink
	label.BackgroundTransparency = 0.2
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = FONT
	label.TextSize = 22
	label.TextColor3 = Palette.white
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	gui.Adornee = adornee
	gui.Parent = adornee
	return gui, label
end

local function emissive(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.Parent = parent
	return p
end

-- A rotating beacon: a red dome and two light fins that turn about Y (no Light objects).
local function newBeacon(parent: Instance): any
	local model = Instance.new("Model")
	model.Name = "EH_AlarmBeacon"
	local dome = emissive("Dome", Vector3.new(1.1, 0.8, 1.1), Palette.alarm, model)
	dome.Shape = Enum.PartType.Ball
	dome.Transparency = 1
	local fins = {}
	for k = 1, 2 do
		local fin = emissive("Fin", Vector3.new(0.12, 0.5, 5), Palette.alarm, model)
		fin.Transparency = 1
		fins[k] = fin
	end
	model.Parent = parent
	return { model = model, dome = dome, fins = fins, at = CFrame.identity, shown = false }
end

function WorldView.new(state: any, positionOf: (actorId: number) -> Vector3?): any
	local view = {}
	local doors: { any } = {}
	local lasers: { any } = {}
	local plates: { any } = {}
	local loot: { any } = {}
	local chevrons: { BasePart } = {}
	local lamps: { [number]: BasePart } = {}
	local skins: { [number]: any } = {}
	local tagged: { [string]: { [number]: Instance } } = {}
	local beacons: { any } = {}
	local fxFolder: Folder? = nil
	local vanBody: BasePart? = nil
	local addedConn: RBXScriptConnection? = nil
	local timeLockList: { { index: number, opensAt: number } } = {}
	local doorIn = { open = false, solid = true, solidAt = nil :: number? }
	local laserIn = { on = true, onAt = nil :: number? }
	local blinkRate = 2 * H.BLINK_HZ_MAX -- toggles per second (on + off = one flash)

	local function stopHums()
		for _, l in lasers do
			if l.humStop then
				l.humStop()
				l.humStop = nil
			end
		end
	end

	function view.clear()
		stopHums()
		if addedConn then
			addedConn:Disconnect()
			addedConn = nil
		end
		table.clear(timeLockList)
		table.clear(doors)
		table.clear(lasers)
		table.clear(plates)
		table.clear(loot)
		table.clear(chevrons)
		table.clear(lamps)
		table.clear(skins)
		table.clear(tagged)
		table.clear(beacons)
		vanBody = nil
		if fxFolder then
			fxFolder:Destroy()
			fxFolder = nil
		end
	end

	local function tag(kind: string, index: number?, inst: Instance)
		if type(index) ~= "number" then
			return
		end
		local map = tagged[kind]
		if not map then
			map = {}
			tagged[kind] = map
		end
		if map[index] == nil then
			map[index] = inst
		end
	end

	-- Hides a skinned door's greybox leaf locally (the leaf keeps the collision).
	local function hideSkinnedLeaf(i: number)
		local d = doors[i]
		local skin = skins[i]
		if d and skin and not d.skin then
			d.skin = skin
			d.part.LocalTransparencyModifier = 1
			for _, c in d.part:GetDescendants() do
				if c:IsA("BasePart") then
					c.LocalTransparencyModifier = 1
				end
			end
		end
	end

	-- One level instance (by EH_Kind / EH_Index); bind() walks the model, DescendantAdded
	-- brings in anything that arrives later.
	local function bindOne(d: Instance)
		local kind = d:GetAttribute("EH_Kind")
		local index = d:GetAttribute("EH_Index")
		do
			if kind == "door" and d:IsA("BasePart") then
				local k = "D" .. tostring(index)
				doors[index] = {
					part = d,
					base = d.CFrame,
					height = d.Size.Y,
					lift = 0,
					shownLift = -1,
					view = "shut",
					beat = -1,
					index = index,
					kOpen = k .. "Open",
					kSolid = k .. "Solid",
					kSolidAt = k .. "SolidAt",
				}
				tag("door", index, d)
				hideSkinnedLeaf(index)
			elseif kind == "lamp" and d:IsA("BasePart") then
				lamps[index] = d
			elseif kind == "laser" and d:IsA("Model") then
				local beams = {}
				for _, b in d:GetDescendants() do
					if b:IsA("BasePart") and b:GetAttribute("EH_Kind") == "beam" then
						table.insert(beams, { part = b, base = b.Transparency })
					end
				end
				local first = beams[1] and beams[1].part
				local sparks: ParticleEmitter? = nil
				if first then
					tag("laser", index, first)
					local at = Instance.new("Attachment")
					at.Name = "EH_Sparks"
					at.Parent = first
					local e = Instance.new("ParticleEmitter")
					e.Rate = 0
					e.Lifetime = NumberRange.new(0.2, 0.45)
					e.Speed = NumberRange.new(6, 14)
					e.SpreadAngle = Vector2.new(70, 70)
					e.Size =
						NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
					e.Color = ColorSequence.new(Palette.amber, Palette.alarm)
					e.LightEmission = 1
					e.Acceleration = Vector3.new(0, -30, 0)
					e.Parent = at
					sparks = e
				end
				local k = "L" .. tostring(index)
				lasers[index] = {
					beams = beams,
					view = "on",
					first = first,
					sparks = sparks,
					humStop = nil,
					kOn = k .. "On",
					kOnAt = k .. "OnAt",
				}
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
				local glyphGui, glyph =
					billboard(d, Vector2.new(40, 40), Vector3.new(0, 1.6, 0), H.PLATE_GLYPH_DISTANCE)
				glyph.TextSize = 26
				local k = "P" .. tostring(index)
				plates[index] = {
					part = d,
					base = d.CFrame,
					rim = rim,
					rimBase = if rim then rim.CFrame else nil,
					cables = cables,
					sink = 0,
					shownSink = -1,
					hue = Palette.steelLo,
					drain = 0,
					held = false,
					glyphGui = glyphGui,
					glyph = glyph,
					shownColour = nil :: Color3?,
					shownLit = nil :: boolean?,
					kHeld = k .. "Held",
					kBy = k .. "By",
				}
				tag("plate", index, d)
			elseif kind == "loot" and d:IsA("BasePart") then
				local k = "K" .. tostring(index)
				local entry: any = {
					part = d,
					home = d.CFrame,
					spin = 0,
					kState = k .. "State",
					kCarrier = k .. "Carrier",
					kPos = k .. "Pos",
				}
				local folderInst: Instance? = state.folder
				local opensAt = folderInst and folderInst:GetAttribute(k .. "OpensAt")
				if type(opensAt) == "number" then
					entry.opensAt = opensAt
					entry.lockGui, entry.lockLabel =
						billboard(d, Vector2.new(150, 36), Vector3.new(0, 2.6, 0), H.TILL_LABEL_DISTANCE)
					entry.lockLabel.TextColor3 = Palette.amber
					table.insert(timeLockList, { index = index, opensAt = opensAt })
				end
				loot[index] = entry
				tag("loot", index, d)
			elseif kind == "chevron" and d:IsA("BasePart") then
				table.insert(chevrons, d)
			elseif kind == "switch" then
				tag("switch", index, d)
			elseif kind == "van" and d:IsA("BasePart") then
				tag("van", 1, d)
			elseif kind == "vanBody" and d:IsA("BasePart") then
				vanBody = d
			elseif kind == "doorSkin" and d:IsA("Model") then
				local parts = {}
				local pivot = d.WorldPivot
				for _, p in d:GetDescendants() do
					if p:IsA("BasePart") then
						local alpha = p:GetAttribute("EH_Alpha")
						p.Transparency = if type(alpha) == "number" then alpha else 0
						local isDial = string.find(p.Name, "Dial", 1, true) ~= nil
						table.insert(parts, { part = p, rel = pivot:ToObjectSpace(p.CFrame), dial = isDial })
					end
				end
				local yaw = num(d:GetAttribute("EH_OpenYaw"), -175)
				skins[index] = { model = d, pivot = pivot, parts = parts, openYaw = math.rad(yaw), u = -1 }
				hideSkinnedLeaf(index)
			end
		end
	end

	-- Binds to the level parts of the current instance (by EH_Kind / EH_Index).
	function view.bind(levelModel: Instance)
		view.clear()
		local folder = Instance.new("Folder")
		folder.Name = "EH_WorldFx"
		folder.Parent = workspace
		fxFolder = folder
		local origin: Vector3 = state.origin or Vector3.zero
		for _, d in levelModel:GetDescendants() do
			bindOne(d)
		end
		addedConn = levelModel.DescendantAdded:Connect(function(d: Instance)
			-- a tagged part may get its attributes in the same frame: bind on the next one
			task.defer(function()
				if d.Parent ~= nil and fxFolder == folder then
					bindOne(d)
				end
			end)
		end)
		-- Alarm beacons: the van roof and over the alarm's loot (hidden until AlarmOn).
		local level = state.level
		if level and level.alarm then
			local floorY = level.floorY or 0
			local body = vanBody
			if body then
				local b = newBeacon(folder)
				b.at = CFrame.new(body.Position + Vector3.new(0, body.Size.Y / 2 + 0.5, 0))
				table.insert(beacons, b)
			end
			local def = level.loot[level.alarm.trigger]
			if def then
				local b = newBeacon(folder)
				b.at = CFrame.new(origin + Vector3.new(def.x, floorY + H.ALARM_BEACON_HEIGHT, def.z))
				table.insert(beacons, b)
			end
			for _, b in beacons do
				b.model:PivotTo(b.at)
			end
		end
	end

	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}

	local function actorOf(actorId: number): any
		local run = state.run
		return run and run.actorById and run.actorById[actorId]
	end

	local function actorHue(actorId: number): Color3
		local a = actorOf(actorId)
		if not a then
			return Palette.white
		end
		if a.orphan then
			return Palette.tapeGrey
		end
		return Palette.hueFor(a.seat)
	end

	local function carrierPos(actorId: number): Vector3?
		local a = actorOf(actorId)
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

	local function cameraPos(): Vector3?
		local cam = workspace.CurrentCamera
		return if cam then cam.CFrame.Position else nil
	end

	-- Laser hum: a loop per laser while it is on and near the camera (hysteresis, so a
	-- far laser never holds a voice and a near one restarts when you walk back).
	local function updateHum(l: any, on: boolean, camPos: Vector3?)
		local first: BasePart? = l.first
		if not first or not camPos then
			return
		end
		local max = A.ROLLOFF.near.max
		local d = (first.Position - camPos).Magnitude
		local want = on and d <= max
		if want and not l.humStop then
			l.humStop = Sound.play("LaserHum", { at = first })
		elseif l.humStop and (not on or d > max + 5) then
			l.humStop()
			l.humStop = nil
		end
	end

	local function updateSkin(d: any)
		local skin = d.skin
		local span = math.max(d.height - 0.4, 0.01)
		local u = math.clamp(d.lift / span, 0, 1)
		if math.abs(u - skin.u) < 1e-4 then
			return
		end
		skin.u = u
		local eased = 1 - (1 - u) * (1 - u)
		local swing = skin.pivot * CFrame.Angles(0, skin.openYaw * eased, 0)
		local dialTurn = u * H.DOOR_SKIN_DIAL_TURNS * 2 * math.pi
		for _, p in skin.parts do
			local cf = swing * p.rel
			if p.dial then
				cf *= CFrame.Angles(0, 0, dialTurn)
			end
			table.insert(parts, p.part)
			table.insert(cfs, cf)
		end
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
		local camPos = cameraPos()
		local alarmOn = folder:GetAttribute("AlarmOn") == true

		local reduced = state.reduced == true
		local blink = math.floor(now * blinkRate) % 2 == 0
		for _, d in doors do
			local solidAt = num(folder:GetAttribute(d.kSolidAt), -1)
			doorIn.open = folder:GetAttribute(d.kOpen) == true
			doorIn.solid = folder:GetAttribute(d.kSolid) ~= false
			doorIn.solidAt = if solidAt >= 0 then solidAt else nil
			local v = Mechanisms.doorViewOf(doorIn, tView)
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
			if d.lift ~= d.shownLift then
				d.shownLift = d.lift
				table.insert(parts, d.part)
				table.insert(cfs, d.base + Vector3.new(0, d.lift, 0))
			end
			if d.skin then
				updateSkin(d)
			end
			-- DoorBeep on every other amber blink while closing (docs/AUDIO.md §9 item 14).
			if v == "closing" then
				local beat = math.floor(now * 4)
				if beat ~= d.beat then
					d.beat = beat
					if beat % 2 == 0 then
						Sound.play("DoorBeep", { at = d.part })
					end
				end
			end
			local lamp = lamps[d.index]
			if lamp then
				-- Alarm Run: every lamp blinks red; otherwise green open, amber blink closing, red
				-- shut. <= BLINK_HZ_MAX flashes/s; reduced motion: steady colours.
				local blinkRed = alarmOn and (reduced or blink)
				local want: Color3
				if v == "open" and not blinkRed then
					want = Palette.ok
				elseif v == "closing" and not blinkRed then
					want = if reduced or blink then Palette.amber else Palette.ink
				else
					want = Palette.alarm
				end
				if lamp.Color ~= want then
					lamp.Color = want
				end
			end
		end

		for _, l in lasers do
			local onAt = num(folder:GetAttribute(l.kOnAt), -1)
			laserIn.on = folder:GetAttribute(l.kOn) ~= false
			laserIn.onAt = if onAt >= 0 then onAt else nil
			local v = Mechanisms.laserViewOf(laserIn, tView)
			-- The telegraph flickers at <= BLINK_HZ_MAX; reduced motion: half-visible, steady.
			local visible = v == "on" or (v == "flicker" and (reduced or blink))
			for _, b in l.beams do
				local want = if visible then (if v == "flicker" and reduced then 0.5 + 0.5 * b.base else b.base) else 1
				if b.part.Transparency ~= want then
					b.part.Transparency = want
				end
			end
			if v == "off" and l.view ~= "off" and l.sparks and state.phase == "Run" then
				l.sparks:Emit(math.max(2, math.floor(H.LASER_SPARKS * (state.particleScale or 1))))
			end
			l.view = v
			updateHum(l, v ~= "off" and state.phase == "Run", camPos)
		end

		for _, p in plates do
			local held = folder:GetAttribute(p.kHeld) == true
			local by = num(folder:GetAttribute(p.kBy), 0)
			if held then
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
			if math.abs(p.sink - sinkTarget) < 1e-3 then
				p.sink = sinkTarget
			end
			local moved = p.sink ~= p.shownSink
			if moved then
				p.shownSink = p.sink
				table.insert(parts, p.part)
				table.insert(cfs, p.base - Vector3.new(0, p.sink, 0))
			end
			local lit = p.drain > 0
			local colour = if lit then p.hue:Lerp(Palette.steelLo, 1 - p.drain) else Palette.steelLo
			local recolour = colour ~= p.shownColour or lit ~= p.shownLit
			p.shownColour, p.shownLit = colour, lit
			local material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
			if p.rim then
				if recolour then
					p.rim.Color = colour
					p.rim.Material = material
				end
				if moved then
					table.insert(parts, p.rim)
					table.insert(cfs, (p.rimBase :: CFrame) - Vector3.new(0, p.sink, 0))
				end
			end
			if recolour then
				for _, c in p.cables do
					c.Color = colour
					c.Material = material
				end
			end
			-- The presser's glyph (●1 ■2 ▲3 ◆4 seat glyphs) while held.
			local presser: any = if held and by > 0 then actorOf(by) else nil
			if presser then
				p.glyph.Text = Palette.glyphFor(presser.seat)
				p.glyph.TextColor3 = if presser.orphan then Palette.tapeGrey else Palette.hueFor(presser.seat)
			end
			p.glyphGui.Enabled = presser ~= nil
		end

		local carryingMine = false
		local carryCount = 0
		local lp = Players.LocalPlayer
		for _, k in loot do
			local st = folder:GetAttribute(k.kState) or "Home"
			local cf: CFrame? = nil
			if st == "Home" then
				k.spin = (k.spin + dt * 1.2) % (2 * math.pi)
				cf = k.home * CFrame.Angles(0, k.spin, 0)
			elseif st == "Carried" then
				local carrier = num(folder:GetAttribute(k.kCarrier), 0)
				local pos = carrierPos(carrier)
				if pos then
					cf = CFrame.new(pos + Vector3.new(0, 2.6, 0))
				end
				local a = actorOf(carrier)
				if a and a.kind == "live" and lp and a.owner == lp.UserId then
					carryingMine = true
					carryCount += 1
				end
			elseif st == "Dropped" then
				local pos = folder:GetAttribute(k.kPos)
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
			-- Time lock (the Clone Party till): "LOCKED 0:07" until its loop time.
			if k.lockGui then
				local left = (k.opensAt :: number) - tView
				local show = st == "Home" and state.phase == "Run" and left > 0
				k.lockGui.Enabled = show
				if show then
					local s = math.max(0, math.ceil(left - 1e-6))
					k.lockLabel.Text = string.format("LOCKED %d:%02d", s // 60, s % 60)
				end
			end
		end
		state.carrying = carryingMine
		state.carryCount = carryCount

		-- Van chevrons pulse while you carry loot (the way to bank it).
		for _, c in chevrons do
			local want = if not carryingMine
				then 0.6
				elseif reduced then 0.25
				else 0.1 + 0.5 * (0.5 + 0.5 * math.sin(now * 6))
			if c.Transparency ~= want then
				c.Transparency = want
			end
		end

		-- Alarm beacons: shown while AlarmOn, turning unless reduced motion is on.
		local turn = if state.reduced then 0 else (now / H.ALARM_BEACON_TURN_SECONDS) * 2 * math.pi
		for _, b in beacons do
			if b.shown ~= alarmOn then
				b.shown = alarmOn
				local alpha = if alarmOn then 0 else 1
				b.dome.Transparency = alpha
				for _, fin in b.fins do
					fin.Transparency = if alarmOn then 0.55 else 1
				end
			end
			if alarmOn then
				table.insert(parts, b.dome)
				table.insert(cfs, b.at)
				for k, fin in b.fins do
					local yaw = turn + (k - 1) * math.pi
					table.insert(parts, fin)
					table.insert(cfs, b.at * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -2.5))
				end
			end
		end

		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	-- What the local player could use right now (contextual Interact): nearest loot.
	-- Returns index, value and the item's opensAt (time lock) if it has one.
	function view.nearestLoot(pos: Vector3, range: number): (number?, number, number?)
		local f: Instance? = state.folder
		if not f then
			return nil, 0, nil
		end
		local best, bestD, value, opensAt = nil, range, 0, nil
		for i, k in loot do
			local st = f:GetAttribute(k.kState)
			if st == "Home" or st == "Dropped" then
				local p = k.part.Position
				local d = Vector3.new(p.X - pos.X, 0, p.Z - pos.Z).Magnitude
				if d <= bestD and math.abs(p.Y - pos.Y) <= Config.Sim.INTERACT_HEIGHT then
					best, bestD = i, d
					value = num(k.part:GetAttribute("EH_Value"), 0)
					opensAt = k.opensAt
				end
			end
		end
		return best, value, opensAt
	end

	-- Time-locked items: { index, opensAt } (the HUD's "Locked" toast). Built at bind;
	-- callers must not change it.
	function view.timeLocks(): { { index: number, opensAt: number } }
		return timeLockList
	end

	function view.doorView(i: number): string
		local d = doors[i]
		return if d then d.view else "shut"
	end

	-- The tagged level part for a sound source (AudioDirector resolver): "plate",
	-- "door", "laser" (its first beam), "loot", "switch", "van".
	function view.partFor(what: string, index: number): Instance?
		local map = tagged[what]
		local inst = map and map[index]
		if inst and inst.Parent ~= nil then
			return inst
		end
		return nil
	end

	-- The van body (level part), for the Crew Line-up's clearance.
	function view.vanBody(): BasePart?
		return vanBody
	end

	-- Stops looping sounds (between runs, at heist end).
	function view.quiet()
		stopHums()
	end

	return view
end

return WorldView
