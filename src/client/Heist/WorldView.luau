--!strict
-- Heist/WorldView: doors, lasers, plates, loot and the van as this client sees them
-- (MASTERPLAN §7.3, §8.2, §8.10 rule 2). The server built the parts once and never
-- touches them again; this view moves and colours them locally from the replicated
-- state attributes:
--   * Doors: Mechanisms.doorViewOf on the loop clock. Leaves pocket-slide sideways into the wall
--     (hidden once fully in, so nothing pokes above the cut-away walls) and street shutters roll up
--     into their header (Size.Y to Config.Lighting.SHUTTER_ROLLED, top pinned) in 0.35 s when open,
--     amber lamp blink (and DoorBeep) while closing; solid in this client's own physics
--     from VISUAL_LEAD before the server makes it solid (what you see is never more
--     generous than the server). A kit vault door (Protocol "doorSkin") hides its
--     greybox leaf locally and swings its skin about the hinge instead, the dial
--     turning as it opens; the leaf keeps the collision.
--   * Lasers: Mechanisms.laserViewOf: on, off, or the 3-flicker telegraph; a LaserHum
--     loop per laser near the camera, sparks when it retracts.
--   * Plates: idle, the rim glows Bulb Warm and breathes slowly and the plate shows its letter
--     (LEVELS P0-1); held, it sinks 0.15 studs on a spring (a ~0.1 s overshoot), the rim and cable
--     take the presser's hue and the plate shows the presser's glyph (colour is never the only
--     signal, §0 C5); the cable drains over the 0.4 s grace back to idle Vault Steel. A need-all
--     door's lamp row (LEVELS P1-3) takes each presser's hue and counts "VAULT n/4".
--   * Loot: at home, in its carrier's hands (a clone's between its hands, your own in front of
--     your chest, facing where you face, with the clones' carry clip on your arms), dropped, or
--     gone (banked). A time-locked item (the Clone Party till, attribute K<i>OpensAt) shows
--     "LOCKED 0:07". The goal and every item worth Config.Lighting.SPARKLE_MIN_VALUE sparkle while
--     at home (LEVELS P0-4); every item glints every 2 s (a tinkle within 8 studs), squashes on
--     a grab and hops when dropped.
--   * Van zone: dim until you carry loot, then lit, its arrows pulsing toward the van (P0-6).
--     A bank: a coin burst (<= 24), the van bounces, a "+$100!" pop rises over it, and every
--     view.onBank listener gets (amount, world position) (the HUD's fly-to-meter hooks it).
--   * Hide spots: a soft outline fades in while your character is within 6 studs.
--   * Feedback (docs/FEEDBACK_TABLE.md, numbers in Config.WorldFx, maths in Shared/Heist/WorldFx):
--     door dust and slide overshoot, three-layer lasers with the re-arm whine as the flicker
--     starts, haptics on plate / grab / bank (phones only, behind reduced motion and the setting).
--   * Alarm Run: rotating red beacons (emissive parts, no lights) on the van roof and
--     over the alarm's loot while AlarmOn; door lamps blink red.
-- Every blink is at most Config.Heist.BLINK_HZ_MAX flashes a second (§7.3) and holds
-- steady under reduced motion. Binding follows DescendantAdded too (StreamingEnabled-
-- ready: parts that arrive late are bound when they arrive). Per frame: attribute names
-- are built once at bind, view inputs reuse their tables, and a door or plate that did
-- not move is not moved again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Mechanisms = require(Shared:WaitForChild("Sim"):WaitForChild("Mechanisms"))
local SharedHeist = Shared:WaitForChild("Heist")
local Palette = require(SharedHeist:WaitForChild("Palette"))
local WorldFx = require(SharedHeist:WaitForChild("WorldFx"))
local CloneClips = require(SharedHeist:WaitForChild("CloneClips"))

local Particles = require(script.Parent:WaitForChild("Particles"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local H = Config.Heist
local A = Config.Audio
local LIGHT = Config.Lighting
local FX = Config.WorldFx
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
	label.Text = ""
	Ui.textStroke(label)
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

-- A burst emitter (Rate 0: only Emit) on an attachment of the view's invisible fx host part.
local function burst(host: BasePart, name: string, props: { [string]: any }): (Attachment, ParticleEmitter)
	local at = Instance.new("Attachment")
	at.Name = name
	at.Parent = host
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Rate = 0
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = at
	return at, e
end

local function rgb3(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
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
	-- The loot sparkles are steady emitters: they report what they keep alive to the shared budget.
	Particles.setSteady("sparkles", function(): number
		local n = 0
		for _, k in loot do
			local e = k.sparkle
			if e and e.Enabled and e.Parent then
				n += e.Rate * e.Lifetime.Max
			end
		end
		return n
	end)
	local slamming = false -- heist complete (Heist/MomentDirector): every door slams shut, visual only
	local fxFolder: Folder? = nil
	local vanBody: BasePart? = nil
	local vanZone: BasePart? = nil
	local vanLit: boolean? = nil
	local addedConn: RBXScriptConnection? = nil
	local timeLockList: { { index: number, opensAt: number } } = {}
	local doorIn = { open = false, solid = true, solidAt = nil :: number? }
	local laserIn = { on = true, onAt = nil :: number? }
	local blinkRate = 2 * H.BLINK_HZ_MAX -- toggles per second (on + off = one flash)
	-- feedback (Config.WorldFx)
	local hideOutlines: { [number]: any } = {}
	local vaultLamps: { any } = {}
	local vaultCounts: { [number]: any } = {}
	local vanKit: { any } = {}
	local vanY, vanV, vanShown = 0, 0, 0
	local pops: { any } = {}
	local bankFns: { (amount: number, worldPos: Vector3) -> () } = {}
	local fxHost: BasePart? = nil
	local dustAt: Attachment?, dust: ParticleEmitter? = nil, nil
	local coinAt: Attachment?, coins: ParticleEmitter? = nil, nil
	local hapticFx: { [string]: Instance } = {}
	local lastPulse = -math.huge
	local carryTrack: AnimationTrack? = nil
	local carryChar: Model? = nil
	local liveCarry = false
	local heldPart: BasePart? = nil -- your first carried item (first person draws it in your hands)

	local function stopHums()
		for _, l in lasers do
			if l.humStop then
				l.humStop()
				l.humStop = nil
			end
		end
	end

	local function stopCarryClip()
		if carryTrack then
			pcall(function()
				(carryTrack :: AnimationTrack):Stop(Config.Clone.POSE_BLEND)
			end)
			carryTrack = nil
			carryChar = nil
		end
	end

	function view.clear()
		stopHums()
		for _, p in plates do
			if p.humStop then
				p.humStop()
			end
		end
		stopCarryClip()
		liveCarry = false
		heldPart = nil
		table.clear(hideOutlines)
		table.clear(vaultLamps)
		table.clear(vaultCounts)
		table.clear(vanKit)
		table.clear(pops)
		table.clear(hapticFx)
		vanY, vanV, vanShown = 0, 0, 0
		fxHost, dustAt, dust, coinAt, coins = nil, nil, nil, nil, nil
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
		slamming = false
		vanBody = nil
		vanZone = nil
		vanLit = nil
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
				local size = d.Size
				local piece = d:GetAttribute("KitPiece")
				local shutter = piece == "Shutter_8x10" or (piece == nil and math.max(size.X, size.Z) >= 7.9)
				-- Pocket door: slides its own width along its run (the kit leaf's local -X, STYLE_BIBLE §5.2).
				local alongX = size.X >= size.Z
				local slide = if alongX then -d.CFrame.RightVector else -d.CFrame.LookVector
				doors[index] = {
					part = d,
					base = d.CFrame,
					size = size,
					height = size.Y,
					shutter = shutter,
					slide = slide,
					travel = if shutter
						then math.max(size.Y - LIGHT.SHUTTER_ROLLED, 0.01)
						else (if alongX then size.X else size.Z),
					hiddenOpen = false,
					lift = 0,
					pos = 0, -- the pocket leaf's shown slide (a spring on `lift`'s target)
					seen = false, -- updated once (no dust for a door that starts open)
					vel = 0,
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
				local rim, letter, cables = nil, nil, {}
				for _, c in d:GetDescendants() do
					local k = c:GetAttribute("EH_Kind")
					if k == "rim" and c:IsA("BasePart") then
						rim = c
					elseif k == "plateLetter" and c:IsA("BasePart") then
						letter = c
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
					letter = letter,
					letterBase = if letter then letter.CFrame else nil,
					cables = cables,
					sink = 0,
					sinkV = 0,
					shownSink = -1,
					humStop = nil :: (() -> ())?,
					shownAlpha = -1,
					hue = Palette.bulbWarm,
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
				-- one glint every GLINT_PERIOD (FEEDBACK_TABLE "Loot": idle affordance)
				local glint = Instance.new("ParticleEmitter")
				glint.Name = "EH_Glint"
				glint.Rate = 0
				glint.Lifetime = NumberRange.new(0.32)
				glint.Speed = NumberRange.new(0)
				glint.Rotation = NumberRange.new(0, 45)
				glint.RotSpeed = NumberRange.new(90)
				glint.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.35, FX.GLINT_SIZE),
					NumberSequenceKeypoint.new(1, 0),
				})
				glint.Color = ColorSequence.new(Palette.white, rgb3(LIGHT.SPARKLE_COLOR))
				glint.LightEmission = 1
				glint.LightInfluence = 0
				glint.ZOffset = 1
				glint.Parent = d
				local entry: any = {
					part = d,
					home = d.CFrame,
					baseSize = d.Size,
					spin = 0,
					squash = 0,
					squashV = 0,
					shownSquash = 0,
					lastState = nil :: string?,
					carrier = 0,
					dropAt = nil :: number?,
					glint = glint,
					glintBeat = WorldFx.glintBeat(0, index, FX.GLINT_PERIOD),
					index = index,
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
				-- Goal sparkle: Heist Gold glints (<= BLINK_HZ_MAX a second) while the item is at home.
				local level = state.level
				local def = level and level.loot and level.loot[index]
				local value = num(d:GetAttribute("EH_Value"), 0)
				if value >= LIGHT.SPARKLE_MIN_VALUE or (def and def.top) then
					local e = Instance.new("ParticleEmitter")
					e.Name = "EH_Sparkle"
					e.Rate = LIGHT.SPARKLE_RATE
					e.Lifetime = NumberRange.new(0.35, 0.5)
					e.Speed = NumberRange.new(0)
					e.Rotation = NumberRange.new(0, 90)
					e.Size = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.4, 0.55),
						NumberSequenceKeypoint.new(1, 0),
					})
					e.Color = ColorSequence.new(
						Color3.fromRGB(LIGHT.SPARKLE_COLOR[1], LIGHT.SPARKLE_COLOR[2], LIGHT.SPARKLE_COLOR[3])
					)
					e.LightEmission = 1
					e.LightInfluence = 0
					e.Parent = d
					entry.sparkle = e
				end
				loot[index] = entry
				tag("loot", index, d)
			elseif kind == "chevron" and d:IsA("BasePart") then
				table.insert(chevrons, d)
			elseif kind == "switch" then
				tag("switch", index, d)
			elseif kind == "van" and d:IsA("BasePart") then
				tag("van", 1, d)
				vanZone = d
			elseif kind == "vanBody" and d:IsA("BasePart") then
				vanBody = d
			elseif kind == "vanKit" and d:IsA("BasePart") then
				table.insert(vanKit, { part = d, base = d.CFrame })
			elseif kind == "hideOutline" and d:IsA("BasePart") then
				local hi = d:GetAttribute("EH_Hide")
				if type(hi) == "number" then
					local entry = hideOutlines[hi]
					if not entry then
						local level = state.level
						local def = level and level.hides and level.hides[hi]
						entry = { parts = {}, box = def and def.box, alpha = 1, shown = 1 }
						hideOutlines[hi] = entry
					end
					table.insert(entry.parts, d)
				end
			elseif kind == "vaultLamp" and d:IsA("BasePart") then
				table.insert(vaultLamps, {
					part = d,
					kHeld = "P" .. tostring(index) .. "Held",
					kBy = "P" .. tostring(index) .. "By",
					shownColour = nil :: Color3?,
					shownAlpha = -1,
				})
			elseif kind == "vaultCount" and d:IsA("BasePart") then
				local gui = d:FindFirstChildOfClass("BillboardGui")
				local label = gui and gui:FindFirstChildOfClass("TextLabel")
				if label then
					vaultCounts[index] = {
						label = label,
						total = num(d:GetAttribute("EH_Total"), 4),
						door = index,
						shown = "",
					}
				end
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
		-- the bursts' invisible host (door dust, the bank's coins, the "+$100!" pops)
		local host = Instance.new("Part")
		host.Name = "EH_FxHost"
		host.Anchored = true
		host.CanCollide = false
		host.CanQuery = false
		host.CanTouch = false
		host.CastShadow = false
		host.Transparency = 1
		host.Size = Vector3.one * 0.2
		host.CFrame = CFrame.new(origin)
		host.Parent = folder
		fxHost = host
		dustAt, dust = burst(host, "EH_Dust", {
			Texture = FX.DOOR_DUST_TEXTURE,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(80, 20),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 1.5, 0),
			Drag = 3,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.8) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Palette.marble),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
		})
		coinAt, coins = burst(host, "EH_Coins", {
			Texture = FX.COIN_TEXTURE,
			Lifetime = NumberRange.new(0.7, 1.1),
			Speed = NumberRange.new(12, 20),
			SpreadAngle = Vector2.new(35, 35),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, -42, 0),
			Size = NumberSequence.new(0.35),
			Color = ColorSequence.new(Palette.gold, rgb3(LIGHT.SPARKLE_COLOR)),
			LightEmission = 0.6,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-300, 300),
		})
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

	-- Where carried loot rides. A clone: between its hands (EchoView.carryPointOf, minus CARRY_LIFT). A live
	-- character: in both hands in front of the chest, facing where it faces (the clones' Config.Clone.CARRY_HANDS
	-- in its root's frame, scaled with the avatar), not on the head.
	local function carrierCf(actorId: number): CFrame?
		local a = actorOf(actorId)
		if not a then
			return nil
		end
		if a.kind == "clone" then
			local p = positionOf(actorId)
			return if p then CFrame.new(p + Vector3.new(0, Config.Clone.CARRY_LIFT, 0)) else nil
		end
		local player = Players:GetPlayerByUserId(a.owner)
		local char = player and player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and char then
			local scale = 1
			local ok, got = pcall(function()
				return (char :: Model):GetScale()
			end)
			if ok and type(got) == "number" then
				scale = got
			end
			local h = Config.Clone.CARRY_HANDS
			local look = root.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude < 1e-3 then
				flatLook = Vector3.new(0, 0, -1)
			end
			local flat = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
			return flat * CFrame.new(h[1] * scale, h[2] * scale, h[3] * scale)
		end
		return nil
	end

	-- Is this actor the local player's live character?
	local function isMine(actorId: number): boolean
		local a = actorOf(actorId)
		local lp = Players.LocalPlayer
		return a ~= nil and a.kind == "live" and lp ~= nil and a.owner == lp.UserId
	end

	local function localRoot(): BasePart?
		local lp = Players.LocalPlayer
		local char = lp and lp.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function reducedNow(): boolean
		local lp = Players.LocalPlayer
		return state.reduced == true or (lp ~= nil and lp:GetAttribute("Setting_ReducedMotion") == true)
	end

	-- Haptics on the three key verbs (plate, grab, bank): phones only (HapticEffect, the 2026 haptics API),
	-- behind Config.WorldFx.HAPTICS, reduced motion and the player's Setting_Haptics.
	local function haptic(verb: string)
		local lp = Players.LocalPlayer
		local now = os.clock()
		local allowed = WorldFx.hapticAllowed({
			enabled = FX.HAPTICS == true,
			touch = UserInputService.TouchEnabled,
			keyboard = UserInputService.KeyboardEnabled,
			reduced = reducedNow(),
			setting = if lp then lp:GetAttribute("Setting_Haptics") else nil,
			sinceLast = now - lastPulse,
			minGap = FX.HAPTIC_MIN_GAP,
		})
		if not allowed or not fxFolder then
			return
		end
		lastPulse = now
		local e = hapticFx[verb]
		if not e then
			local ok, made = pcall(function(): Instance
				local h = Instance.new("HapticEffect")
				h.Type = (Enum.HapticEffectType :: any)[FX.HAPTIC_TYPES[verb] or "UIClick"]
				h.Parent = fxFolder
				return h
			end)
			if not ok then
				return
			end
			e = made
			hapticFx[verb] = made
		end
		pcall(function()
			(e :: any):Play()
		end)
	end

	-- The clones' carry clip on your own arms while you carry (R15 only; your client's animation replicates).
	local function setLiveCarry(on: boolean)
		if not FX.LIVE_CARRY_CLIP then
			return
		end
		local lp = Players.LocalPlayer
		local char = lp and lp.Character
		if not on or char ~= carryChar then
			stopCarryClip()
		end
		if not on or carryTrack or not char then
			return
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if not hum or not animator or hum.RigType ~= Enum.HumanoidRigType.R15 then
			return
		end
		local ok, track = pcall(function(): AnimationTrack
			local anim = Instance.new("Animation")
			anim.AnimationId = CloneClips.carry
			local t = (animator :: Animator):LoadAnimation(anim)
			t.Priority = Enum.AnimationPriority.Action
			t.Looped = true
			t:Play(Config.Clone.POSE_BLEND)
			return t
		end)
		if ok then
			carryTrack = track
			carryChar = char
		end
	end

	-- Where the van is (the kit van's middle, else the greybox body).
	local function vanTop(): Vector3?
		if #vanKit > 0 then
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, v in vanKit do
				local p, sz = v.base.Position, v.part.Size
				lo, hi = lo:Min(p - sz / 2), hi:Max(p + sz / 2)
			end
			return Vector3.new((lo.X + hi.X) / 2, hi.Y, (lo.Z + hi.Z) / 2)
		end
		local body = vanBody
		if body then
			return body.Position + Vector3.new(0, body.Size.Y / 2, 0)
		end
		return nil
	end

	-- The bank moment (visual only; FEEDBACK_TABLE "Van / bank"): coins, the van bounce, the "+$100!" pop, the
	-- toot, your haptic, then every onBank listener (the HUD's fly-to-meter).
	local function bankMoment(amount: number, mine: boolean, now: number)
		local at = vanTop()
		if not at then
			return
		end
		local reduced = reducedNow()
		if coins and coinAt then
			coinAt.WorldPosition = at + Vector3.new(0, 0.5, 0)
			Particles.emit(coins, WorldFx.coinCount(FX.COINS, state.particleScale))
		end
		if not reduced then
			vanY, vanV = -FX.VAN_BOUNCE.height, 0
		end
		Sound.play("VanToot", { at = vanBody or fxHost })
		if mine then
			haptic("bank")
		end
		local host = fxHost
		if host and amount > 0 then
			local anchor = Instance.new("Attachment")
			anchor.Name = "EH_BankPop"
			anchor.Parent = host
			anchor.WorldPosition = at + Vector3.new(0, 1, 0)
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(FX.BANK_POP_SIZE[1], FX.BANK_POP_SIZE[2])
			gui.LightInfluence = 0
			gui.AlwaysOnTop = true
			gui.MaxDistance = 160
			gui.Adornee = anchor
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.FontFace = Ui.FONT_DISPLAY or FONT
			label.TextScaled = true
			label.TextColor3 = Palette.gold
			label.Text = WorldFx.bankText(amount)
			Ui.textStroke(label, 3)
			label.Parent = gui
			gui.Parent = anchor
			table.insert(pops, { anchor = anchor, gui = gui, label = label, born = now, base = anchor.Position })
		end
		for _, fn in bankFns do
			task.spawn(fn, amount, at)
		end
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
		local u = math.clamp(d.lift / d.travel, 0, 1)
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

		local reduced = reducedNow()
		local blink = math.floor(now * blinkRate) % 2 == 0
		for _, d in doors do
			local solidAt = num(folder:GetAttribute(d.kSolidAt), -1)
			doorIn.open = folder:GetAttribute(d.kOpen) == true
			doorIn.solid = folder:GetAttribute(d.kSolid) ~= false
			doorIn.solidAt = if solidAt >= 0 then solidAt else nil
			local v = Mechanisms.doorViewOf(doorIn, tView)
			local opened = v == "open" and d.view ~= "open" and d.seen
			d.view = v
			d.seen = true
			local target = if v == "open" then d.travel else 0
			local rate = d.travel / H.DOOR_SLIDE_SECONDS
			if slamming then
				-- heist complete: the vault door (L6) or the shop door slams shut (the run is over)
				target = 0
				rate = d.travel / Config.Moments.COMPLETE.SLAM_DOOR_SECONDS
			end
			if d.lift < target then
				d.lift = math.min(target, d.lift + rate * dt)
			elseif d.lift > target then
				d.lift = math.max(target, d.lift - rate * dt)
			end
			-- A pocket leaf slides on a spring (a small overshoot, FEEDBACK_TABLE "Door"); shutters and the vault
			-- skin keep their exact ease. Reduced motion: the plain slide.
			local shown = d.lift
			if d.skin == nil and not d.shutter then
				if reduced then
					d.pos, d.vel = d.lift, 0
				else
					d.pos, d.vel = WorldFx.settle(d.pos, d.vel, target, dt, FX.DOOR_SPRING)
				end
				shown = d.pos
			end
			-- dust puff at the sill as it opens
			if opened and dust and dustAt and state.phase == "Run" then
				local base: CFrame = d.base
				dustAt.WorldPosition = base.Position - Vector3.new(0, d.size.Y / 2 - 0.4, 0)
				Particles.emit(dust, math.max(2, math.floor(FX.DOOR_DUST * (state.particleScale or 1))))
			end
			local shut = v == "shut"
			if d.part.CanCollide ~= shut then
				d.part.CanCollide = shut
			end
			if shown ~= d.shownLift then
				d.shownLift = shown
				-- a skinned (vault) leaf stays put and hidden; its skin swings (updateSkin)
				if d.skin == nil and d.shutter then
					-- roll up into the header: the top stays pinned, the size shrinks
					local h = d.size.Y - d.lift
					d.part.Size = Vector3.new(d.size.X, h, d.size.Z)
					table.insert(parts, d.part)
					table.insert(cfs, d.base * CFrame.new(0, (d.size.Y - h) / 2, 0))
				elseif d.skin == nil then
					table.insert(parts, d.part)
					table.insert(cfs, d.base + d.slide * shown)
					-- fully in the pocket: hidden, so it never shows through the wall it slid into
					local inside = shown >= d.travel - 1e-3
					if inside ~= d.hiddenOpen then
						d.hiddenOpen = inside
						d.part.LocalTransparencyModifier = if inside then 1 else 0
					end
				end
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
				Particles.emit(l.sparks, math.max(2, math.floor(H.LASER_SPARKS * (state.particleScale or 1))))
			end
			-- the re-arm whine starts with the flicker, 0.5 s before the beam is back (FEEDBACK_TABLE "Laser")
			if v == "flicker" and l.view == "off" and state.phase == "Run" then
				Sound.play("LaserWhine", { at = l.first })
			end
			l.view = v
			updateHum(l, v ~= "off" and state.phase == "Run", camPos)
		end

		local breathe = if reduced
			then 0
			else LIGHT.PLATE_BREATHE * math.sin(now * 2 * math.pi * LIGHT.PLATE_BREATHE_HZ)
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
			if held and not p.held then
				if by > 0 and isMine(by) then
					haptic("plate")
				end
				if not p.humStop then
					p.humStop = Sound.play("PlateHum", { at = p.part })
				end
			elseif not held and p.humStop then
				p.humStop()
				p.humStop = nil
			end
			p.held = held
			if not held then
				p.drain = math.max(0, p.drain - dt / Config.Sim.PLATE_GRACE)
			end
			-- sinks 0.15 studs and settles with a ~0.1 s overshoot (Config.WorldFx.PLATE_SPRING)
			local sinkTarget = if held then H.PLATE_SINK else 0
			if reduced then
				p.sink, p.sinkV = sinkTarget, 0
			else
				p.sink, p.sinkV = WorldFx.settle(p.sink, p.sinkV, sinkTarget, dt, FX.PLATE_SPRING, 1e-4)
			end
			local moved = p.sink ~= p.shownSink
			if moved then
				p.shownSink = p.sink
				table.insert(parts, p.part)
				table.insert(cfs, p.base - Vector3.new(0, p.sink, 0))
				if p.letter then
					table.insert(parts, p.letter)
					table.insert(cfs, (p.letterBase :: CFrame) - Vector3.new(0, p.sink, 0))
				end
			end
			-- Idle: rim in Bulb Warm (breathing), cable in Vault Steel; lit: the presser's hue, draining back.
			local lit = p.drain > 0
			local rimColour = if lit then p.hue:Lerp(Palette.bulbWarm, 1 - p.drain) else Palette.bulbWarm
			local cableColour = if lit then p.hue:Lerp(Palette.steel, 1 - p.drain) else Palette.steel
			local recolour = rimColour ~= p.shownColour or lit ~= p.shownLit
			p.shownColour, p.shownLit = rimColour, lit
			if p.rim then
				if recolour then
					p.rim.Color = rimColour
					p.rim.Material = Enum.Material.Neon
				end
				local alpha = if held then 0 else (LIGHT.PLATE_IDLE_ALPHA + breathe) * (1 - p.drain)
				if math.abs(alpha - p.shownAlpha) > 0.01 then
					p.shownAlpha = alpha
					p.rim.Transparency = alpha
				end
				if moved then
					table.insert(parts, p.rim)
					table.insert(cfs, (p.rimBase :: CFrame) - Vector3.new(0, p.sink, 0))
				end
			end
			if recolour then
				local material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
				for _, c in p.cables do
					c.Color = cableColour
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
		local heldNow: BasePart? = nil
		local root = localRoot()
		for _, k in loot do
			local st = folder:GetAttribute(k.kState) or "Home"
			local carrier = if st == "Carried" then num(folder:GetAttribute(k.kCarrier), 0) else 0
			-- state changes (FEEDBACK_TABLE "Loot", "Van / bank"); nothing on the first frame after a bind
			local prev = k.lastState
			if prev ~= nil and st ~= prev then
				if st == "Carried" and (prev == "Home" or prev == "Dropped") then
					if not reduced then
						k.squash, k.squashV = -FX.SQUASH.amount, 0
					end
					if isMine(carrier) then
						haptic("grab")
					end
				elseif st == "Dropped" and prev == "Carried" then
					k.dropAt = now
				elseif st == "Banked" and prev == "Carried" then
					bankMoment(num(k.part:GetAttribute("EH_Value"), 0), isMine(k.carrier), now)
				end
			end
			k.lastState = st
			if st == "Carried" then
				k.carrier = carrier
			end
			local cf: CFrame? = nil
			if st == "Home" then
				k.spin = (k.spin + dt * 1.2) % (2 * math.pi)
				cf = k.home * CFrame.Angles(0, k.spin, 0)
			elseif st == "Carried" then
				cf = carrierCf(carrier)
				if isMine(carrier) then
					carryingMine = true
					carryCount += 1
					if not heldNow then
						heldNow = k.part
					end
				end
			elseif st == "Dropped" then
				local pos = folder:GetAttribute(k.kPos)
				if typeof(pos) == "Vector3" then
					local hop = if k.dropAt and not reduced then WorldFx.bounce(now - k.dropAt, FX.BOUNCE) else 0
					cf = CFrame.new(origin + pos - Vector3.new(0, 2.4 - hop, 0))
				end
			end
			-- squash on grab, springing back (a size change: kit loot is a MeshPart, its mesh scales with it)
			if k.squash ~= 0 or k.squashV ~= 0 then
				k.squash, k.squashV = WorldFx.settle(k.squash, k.squashV, 0, dt, FX.SQUASH)
			end
			if k.squash ~= k.shownSquash then
				k.shownSquash = k.squash
				local sy, sxz = WorldFx.squashScale(k.squash)
				local b: Vector3 = k.baseSize
				k.part.Size = Vector3.new(b.X * sxz, b.Y * sy, b.Z * sxz)
			end
			-- a glint every GLINT_PERIOD while it waits (at home or dropped), a tinkle when you are near
			local beat = WorldFx.glintBeat(now, k.index, FX.GLINT_PERIOD)
			if beat ~= k.glintBeat then
				k.glintBeat = beat
				if (st == "Home" or st == "Dropped") and cf ~= nil and state.phase == "Run" then
					Particles.emit(k.glint, 1)
					local at = cf.Position
					if
						root
						and Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z).Magnitude
							<= FX.TINKLE_RANGE
					then
						Sound.play("LootTinkle", { at = k.part })
					end
				end
			end
			local hidden = st == "Banked" or cf == nil
			local want = if hidden then 1 else 0
			if k.part.Transparency ~= want then
				k.part.Transparency = want
			end
			-- First person: the loot you hold is drawn in your hands (Heist/Viewmodel), so the world copy at your
			-- chest is hidden for you only (LocalTransparencyModifier, written only when it changes hands).
			local fpHeld = st == "Carried" and isMine(carrier) and state.fpView == true
			if fpHeld ~= (k.fpHeld == true) then
				k.fpHeld = fpHeld
				k.part.LocalTransparencyModifier = if fpHeld then 1 else 0
			end
			if k.sparkle then
				local on = st == "Home"
				if k.sparkle.Enabled ~= on then
					k.sparkle.Enabled = on
				end
				local rate = LIGHT.SPARKLE_RATE * (state.particleScale or 1)
				if k.sparkle.Rate ~= rate then
					k.sparkle.Rate = rate
				end
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
		heldPart = heldNow
		if carryingMine ~= liveCarry then
			liveCarry = carryingMine
			setLiveCarry(carryingMine)
		end

		-- The van zone is dim until you carry loot; then it lights up and its arrows pulse toward the van.
		if vanLit ~= carryingMine then
			vanLit = carryingMine
			local material = if carryingMine then Enum.Material.Neon else Enum.Material.SmoothPlastic
			if vanZone then
				vanZone.Transparency = if carryingMine then LIGHT.VAN_CARRY_ALPHA else LIGHT.VAN_IDLE_ALPHA
				vanZone.Material = material
			end
			for _, c in chevrons do
				c.Material = material
			end
		end
		for _, c in chevrons do
			local want = if not carryingMine
				then LIGHT.ARROW_IDLE_ALPHA
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

		-- The van bounces after a bank (a spring from a squat; reduced motion: no bounce).
		if vanY ~= 0 or vanV ~= 0 then
			vanY, vanV = WorldFx.settle(vanY, vanV, 0, dt, FX.VAN_BOUNCE, 1e-3)
		end
		if vanY ~= vanShown then
			vanShown = vanY
			local lift = Vector3.new(0, vanY, 0)
			for _, v in vanKit do
				table.insert(parts, v.part)
				table.insert(cfs, v.base + lift)
			end
		end

		-- Hide spots: the outline fades in within HIDE_OUTLINE.near studs of your character.
		local ho = LIGHT.HIDE_OUTLINE
		local fade = math.clamp(dt / ho.fadeSeconds, 0, 1)
		for _, h in hideOutlines do
			local want = 1
			local box = h.box
			if root and box and state.phase == "Run" then
				local rel = root.Position - origin
				if WorldFx.footprintDistance(rel.X, rel.Z, box) <= ho.near then
					want = ho.alpha
				end
			end
			h.alpha = if reduced then want else h.alpha + (want - h.alpha) * fade
			if math.abs(h.alpha - want) < 0.01 then
				h.alpha = want
			end
			if h.alpha ~= h.shown then
				h.shown = h.alpha
				for _, part in h.parts do
					part.Transparency = h.alpha
				end
			end
		end

		-- Need-all rows: each lamp in its presser's hue while its plate is held; the "VAULT n/4" count.
		local heldBy: { [number]: number } = {}
		for _, vl in vaultLamps do
			local held = folder:GetAttribute(vl.kHeld) == true
			local by = num(folder:GetAttribute(vl.kBy), 0)
			local colour = if held then (if by > 0 then actorHue(by) else Palette.white) else Palette.bulbWarm
			local alpha = if held then 0 else LIGHT.VAULT_ROW.idleAlpha
			if colour ~= vl.shownColour then
				vl.shownColour = colour
				vl.part.Color = colour
			end
			if alpha ~= vl.shownAlpha then
				vl.shownAlpha = alpha
				vl.part.Transparency = alpha
			end
			local door = num(vl.part:GetAttribute("EH_Door"), 0)
			heldBy[door] = (heldBy[door] or 0) + (if held then 1 else 0)
		end
		for door, c in vaultCounts do
			local n = heldBy[door] or 0
			local text = WorldFx.vaultText(n, c.total)
			if text ~= c.shown then
				c.shown = text
				c.label.Text = text
				c.label.TextColor3 = if n >= c.total then Palette.ok else Palette.bulbWarm
			end
		end

		-- "+$100!" pops rise and fade (reduced motion: they only fade).
		for i = #pops, 1, -1 do
			local pop = pops[i]
			local u = (now - pop.born) / FX.BANK_POP_SECONDS
			if u >= 1 then
				pop.anchor:Destroy()
				table.remove(pops, i)
			else
				local rise = if reduced then 0 else FX.BANK_POP_RISE * (1 - (1 - u) * (1 - u))
				pop.anchor.Position = pop.base + Vector3.new(0, rise, 0)
				pop.label.TextTransparency = math.clamp((u - 0.6) / 0.4, 0, 1)
			end
		end

		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	-- The HUD's hook for the bank moment (FEEDBACK_TABLE "Van / bank": "+$100 flies to the meter"): fn(amount,
	-- worldPos) on every bank, yours and your clones'. Returns a function that removes it.
	function view.onBank(fn: (amount: number, worldPos: Vector3) -> ()): () -> ()
		table.insert(bankFns, fn)
		return function()
			local i = table.find(bankFns, fn)
			if i then
				table.remove(bankFns, i)
			end
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

	-- First person (Heist/Viewmodel): the loot part you carry first, or nil.
	function view.heldPart(): BasePart?
		return heldPart
	end

	-- First person (Heist/LookTarget): what you could look at and use, written into `out` (cleared first):
	-- loot at home or dropped ({ kind = "loot", index, part, value, opensAt? }), every switch
	-- ({ kind = "switch", index, part }) and the van zone ({ kind = "van", index = 1, part }).
	function view.lookables(out: { any }): { any }
		table.clear(out)
		local f: Instance? = state.folder
		if not f then
			return out
		end
		for i, k in loot do
			local st = f:GetAttribute(k.kState)
			if (st == "Home" or st == "Dropped") and k.part.Parent ~= nil then
				table.insert(out, {
					kind = "loot",
					index = i,
					part = k.part,
					value = num(k.part:GetAttribute("EH_Value"), 0),
					opensAt = k.opensAt,
				})
			end
		end
		local sw = tagged.switch
		if sw then
			for i, inst in sw do
				if inst.Parent ~= nil and inst:IsA("BasePart") then
					table.insert(out, { kind = "switch", index = i, part = inst })
				end
			end
		end
		if vanZone and vanZone.Parent ~= nil then
			table.insert(out, { kind = "van", index = 1, part = vanZone })
		end
		return out
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

	-- Heist complete (Heist/MomentDirector): every door slams shut in Config.Moments.COMPLETE.SLAM_DOOR_SECONDS
	-- and stays shut until the next level binds. Visual only: the heist is already over on the server.
	-- Returns the door part that was open the widest (where the slam sounds), or nil.
	function view.slamDoors(): BasePart?
		slamming = true
		local best, open = nil, 0
		for _, d in doors do
			if d.lift > open then
				best, open = d.part, d.lift
			end
		end
		return best
	end

	return view
end

return WorldView
