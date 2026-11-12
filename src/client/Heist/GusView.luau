--!strict
-- Heist/GusView: draws Gus, his vision cone and his intention cues on this client (MASTERPLAN §6.5
-- "Gus and threats", §7.3 detection; PLAN_STEAM_PLUS §4.4 A4-A5, §5). While he patrols, his pose is
-- Sim/Guards.patrol on the replicated loop clock (minus the replicated offset), the same pure function
-- the server runs; when he stops ("?", "huh?") or chases, the client eases toward the pose attributes
-- the server sends at 10 Hz. Nothing here decides anything (the server owns detection and catches).
--
-- Gus (Heist/GusRig): the kit's 18-part mesh once the server has replicated it (box rig until then,
-- and for good if the kit never loads), posed every frame by Shared/Heist/GusBeats:
--   * beats from the guard state: Doze (a posted guard in a level with an alarm, until AlarmOn),
--     Wake (cap pops, jump), Patrol (FK walk, torch sway, key jingle), DoubleTake ("?": head first,
--     then the body), Chase ("!" point, then the funny sprint), Catch (a grab lunge on a Caught event),
--     WrongOne (busted a clone: head scratch, "?" over the clone), Scratch (lost sight);
--   * look-at with limits: on patrol the head looks where the route goes HEAD_LEAD from now; off
--     patrol the body follows the head a HEAD_LEAD later.
-- Intention (A5): boot prints of his next 2 s of patrol (Boot Chalk with an Ink rim, never Torch
-- Amber), the cone flickers in the FLICKER_LEAD before a patrol turn, a "GUS" nameplate the first
-- time he is on screen this session.
-- Cone: a flat floor fan in Torch Amber (Transparency 0.75, Neon edge), a 12-ray fan at 10 Hz against
-- the level's sight boxes and the doors that look shut; each wedge reaches only its shorter ray so it
-- never paints through a wall (docs/audit/LEVELS.md G10). Amber fill while his meter rises, red on a
-- catch.
-- Sound (docs/AUDIO.md "Gus"): GusStep every GUS_STEP_STRIDE studs, GusKeys every KEYS_STEPS steps,
-- GusRadio now and then on patrol, Heartbeat while his "?" is on you, the barks on beat changes (the
-- "?" and "!" stings come from the Suspect / Caught events). Sprint dust while he chases.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Sim = Shared:WaitForChild("Sim")
local Guards = require(Sim:WaitForChild("Guards"))
local Mechanisms = require(Sim:WaitForChild("Mechanisms"))
local HeistShared = Shared:WaitForChild("Heist")
local GusBeats = require(HeistShared:WaitForChild("GusBeats"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local GusRig = require(script.Parent:WaitForChild("GusRig"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local H = Config.Heist
local S = Config.Sim
local AU = Config.Audio
local GC = Config.Gus
local B = GusBeats.BEAT
local TAU = 2 * math.pi

local GusView = {}

-- The nameplate shows once per session (the first time Gus is on screen).
local nameplateSeen = false

local BUBBLE_COLOUR: { [string]: Color3 } = {
	GUS_SPOTTED = Palette.alarm,
	GUS_SUSPICIOUS = Palette.amber,
	GUS_HUH = Palette.white,
	GUS_ZZ = Palette.steelHi,
}

-- Barks when a beat starts (the DoubleTake "hm?" waits for the snap).
local BARK: { [string]: string } = {
	[B.Wake] = "GusBarkHey",
	[B.Chase] = "GusBarkHey",
	[B.Catch] = "GusBarkGotcha",
	[B.WrongOne] = "GusBarkWrongOne",
}

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

-- A world-space bubble ("?", "!", "zz") on the type scale with a real ink stroke (Ui kit).
local function bubbleGui(name: string): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(96, 64)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local label = Ui.label(gui, {
		Name = "Bubble",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.FONT_HEAVY,
		TextSize = Theme.TYPE.display,
		Text = "",
		stroke = 3,
	})
	Ui.scaleOf(label)
	return gui, label
end

-- "GUS" on a Crew Board pill (Ui kit panel, 2 px rim, UIStroke text), hidden until first sight.
local function nameplateGui(): (BillboardGui, Frame)
	local gui = Instance.new("BillboardGui")
	gui.Name = "GusNameplate"
	gui.Size = UDim2.fromOffset(112, 44)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.MaxDistance = GC.NAMEPLATE_DISTANCE * 1.5
	local panel = Ui.panel(gui, {
		Name = "Plate",
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})
	Ui.pill(panel)
	Ui.label(panel, {
		Name = "Name",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.TYPE.title,
		Text = Strings.GUS_NAME,
	})
	return gui, panel
end

local function newBeatSet(): any
	return {
		cur = GusBeats.newPose(),
		prev = GusBeats.newPose(),
		out = GusBeats.newPose(),
		walk = { phase = 0, amount = 0, run = 0, clock = 0 } :: GusBeats.Walk,
	}
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

	local function meshRigs(): number
		local n = 0
		for _, g in guards do
			if g.rig.kind == "mesh" then
				n += 1
			end
		end
		return n
	end

	-- Puts a (new) rig in place: parents it and moves the bubble, nameplate and dust onto it.
	local function attachRig(g: any, rig: GusRig.Rig)
		local old = g.rig
		g.rig = rig
		rig.model.Parent = folder
		g.head = rig.head
		g.gui.Adornee = rig.head
		g.gui.Parent = rig.head
		g.plate.Adornee = rig.head
		g.plate.Parent = rig.head
		g.dustAt.Parent = rig.foot
		if old and old ~= rig then
			old.model:Destroy()
		end
	end

	function view.setLevel(level: any)
		view.clear()
		local now = os.clock()
		for i, def in level.guards do
			local mesh = if meshRigs() < GC.MAX_MESH then nil else false
			local rig = GusRig.build(state.dressing == true, mesh)
			local dustAt = Instance.new("Attachment")
			dustAt.Name = "EH_Dust"
			dustAt.Position = Vector3.new(0, -0.2, 0)
			local dust = Instance.new("ParticleEmitter")
			dust.Rate = 0
			dust.Lifetime = NumberRange.new(0.3, 0.5)
			dust.Speed = NumberRange.new(1, 3)
			dust.SpreadAngle = Vector2.new(60, 20)
			dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.2) })
			dust.Transparency = NumberSequence.new(0.4, 1)
			dust.Color = ColorSequence.new(Palette.steelHi)
			dust.Parent = dustAt
			local gui, label = bubbleGui("GusBubble")
			gui.StudsOffset = Vector3.new(0, 3.6, 0)
			local plate, plateFrame = nameplateGui()
			-- "?" over a clone he just busted (WRONG ONE).
			local wrongAt = flat("WrongOneAnchor", "Part", folder)
			wrongAt.Size = Vector3.new(0.2, 0.2, 0.2)
			wrongAt.Transparency = 1
			local wrongGui, wrongLabel = bubbleGui("WrongOne")
			wrongGui.Adornee = wrongAt
			wrongGui.Enabled = false
			wrongLabel.Text = Strings.GUS_SUSPICIOUS
			wrongLabel.TextColor3 = Palette.white
			wrongGui.Parent = wrongAt
			-- Cone
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
			-- Boot prints: an Ink rim under a Boot Chalk sole, one pair per print.
			local prints = Instance.new("Model")
			prints.Name = "BootPrints"
			local rims, soles = {}, {}
			local sz = GC.PRINT_SIZE
			for k = 1, GC.PRINT_MAX do
				local rim = flat("PrintRim", "Part", prints)
				rim.Size = Vector3.new(sz[1] + 2 * GC.PRINT_RIM, 0.04, sz[2] + 2 * GC.PRINT_RIM)
				rim.Color = Palette.ink
				rim.Transparency = 1
				local sole = flat("Print", "Part", prints)
				sole.Size = Vector3.new(sz[1], 0.05, sz[2])
				sole.Color = Palette.bootPrint
				sole.Transparency = 1
				rims[k], soles[k] = rim, sole
			end
			prints.Parent = folder
			local key = "G" .. tostring(i)
			local g = {
				index = i,
				def = def,
				rig = nil :: any,
				dozer = GusBeats.isDozer(level, def),
				gui = gui,
				label = label,
				bubbleKey = nil :: string?,
				plate = plate,
				plateFrame = plateFrame,
				plateUntil = 0,
				nextPlateCheck = 0,
				wrongAt = wrongAt,
				wrongGui = wrongGui,
				wrongLabel = wrongLabel,
				wrongUntil = 0,
				cone = cone,
				wedges = wedges,
				edges = edges,
				coneParts = conePartList, -- wedge, wedge, edge per segment
				coneLocal = {} :: { CFrame }, -- their CFrames in Gus's apex frame (rebuilt at CONE_HZ)
				clipped = table.create(H.CONE_RAYS, 0),
				shownColour = nil :: Color3?,
				shownFill = -1,
				shownEdge = -1,
				rims = rims,
				soles = soles,
				printOut = GusBeats.newPrints(),
				printShown = 0,
				printFade = table.create(GC.PRINT_MAX, -1),
				nextPrints = 0,
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
				-- Acting
				st = GusBeats.newState(now),
				beat = B.Patrol,
				beatSet = newBeatSet(),
				pendingBang = nil :: string?,
				bodyYaw = 0,
				heldYaw = 0,
				headRel = 0,
				lookLost = false,
				delay = GusBeats.newDelay(48),
				nextDelayPush = 0,
				barkAt = math.huge,
				nod = -1,
				posed = false,
				-- Sound and dust
				bangUntil = 0,
				stepDist = 0,
				steps = 0,
				nextRadio = now + radioGap(),
				nextBeat = 0,
				nextDust = 0,
				nextUpgrade = now + GC.UPGRADE_CHECK_SECONDS,
				meshBroken = false,
				dust = dust,
				dustAt = dustAt,
				head = nil :: any,
			}
			guards[i] = g
			attachRig(g, rig)
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

	-- Gus caught someone ("!", kind "catch": the grab lunge) or busted a clone (kind "bust": the
	-- cone flashes and a "?" pops over the clone; the WRONG ONE beat comes from his "Huh" mode).
	-- `at`: where the actor was (Vector3 or its root part), if known.
	function view.bang(index: number, now: number, kind: string?, at: any?)
		local g = guards[index]
		if not g then
			return
		end
		g.bangUntil = now + GC.BANG_SECONDS
		if kind == "catch" then
			g.pendingBang = "catch"
		elseif kind == "bust" then
			local pos: Vector3? = if typeof(at) == "Vector3"
				then at
				elseif typeof(at) == "Instance" and at:IsA("BasePart") then at.Position
				else nil
			if pos then
				g.wrongAt.CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0))
				g.wrongGui.Enabled = true
				g.wrongUntil = now + GC.WRONG_ONE_SECONDS
				Ui.pop(g.wrongLabel, GC.BUBBLE_POP)
			end
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

	-- Tests and tools: the guard's acting beat, rig, and head yaw relative to the body (radians).
	function view.beatOf(index: number): string?
		local g = guards[index]
		return if g then g.beat else nil
	end
	function view.rigOf(index: number): GusRig.Rig?
		local g = guards[index]
		return if g then g.rig else nil
	end
	function view.lookOf(index: number): number
		local g = guards[index]
		return if g then g.headRel else 0
	end

	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	local boxes: { any } = {} -- reused every ray pass
	local doorIn = { open = false, solid = true, solidAt = nil :: number? }
	local doorKeys: { { string } } = {}
	local beatInput: GusBeats.Input = { mode = "Patrol", alarmOn = false, dozer = false, bang = nil }

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

	-- Swaps a box Gus for the mesh once the template arrives, and a broken mesh Gus for a box one.
	local function upkeep(g: any, now: number)
		if now < g.nextUpgrade then
			return
		end
		g.nextUpgrade = now + GC.UPGRADE_CHECK_SECONDS
		local rig = g.rig
		if rig.kind == "mesh" and not GusRig.whole(rig) then
			attachRig(g, GusRig.build(state.dressing == true, false))
		elseif rig.kind == "box" and not g.meshBroken and meshRigs() < GC.MAX_MESH and GusRig.template() then
			attachRig(g, GusRig.build(state.dressing == true))
		end
		if rig.kind == "mesh" and g.rig.kind == "box" then
			g.meshBroken = true
		end
	end

	-- "GUS" the first time he is on screen this session.
	local function nameplate(g: any, now: number, running: boolean)
		if g.plateUntil > 0 then
			if now >= g.plateUntil then
				g.plateUntil = 0
				Ui.hide(g.plateFrame)
			end
			return
		end
		if nameplateSeen or not running or now < g.nextPlateCheck then
			return
		end
		g.nextPlateCheck = now + 0.2
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local p, onScreen = cam:WorldToViewportPoint(g.head.Position)
		if onScreen and p.Z > 0 and p.Z < GC.NAMEPLATE_DISTANCE then
			nameplateSeen = true
			g.plateUntil = now + GC.NAMEPLATE_SECONDS
			Ui.show(g.plateFrame)
		end
	end

	-- Head bubble from the beat; pops when it changes.
	local function bubble(g: any, beat: string, age: number, mode: string, stage: number, banging: boolean)
		local keyName = GusBeats.bubble(beat, age)
		if keyName == nil then
			if banging then
				keyName = "GUS_SPOTTED"
			elseif stage >= 2 or mode == "Suspicious" then
				keyName = "GUS_SUSPICIOUS"
			end
		end
		if keyName ~= g.bubbleKey then
			g.bubbleKey = keyName
			if keyName then
				g.label.Text = (Strings :: any)[keyName]
				g.label.TextColor3 = BUBBLE_COLOUR[keyName] or Palette.white
				Ui.pop(g.label, GC.BUBBLE_POP)
			else
				g.label.Text = ""
			end
		end
	end

	-- Boot prints at PRINT_HZ: his next PRINT_HORIZON s of patrol (hidden off patrol).
	local function bootPrints(g: any, show: boolean, tPatrol: number, origin: Vector3, floorY: number)
		local n = 0
		-- "Show guard path" (settings, U7): HeistClient keeps state.guardPath.
		if show and GC.PRINTS ~= false and state.guardPath ~= false then
			n = GusBeats.bootPrints(g.def.route, tPatrol, g.printOut)
		end
		local out = g.printOut
		local tr = GC.PRINT_TRANSPARENCY
		for k = 1, GC.PRINT_MAX do
			local fade = if k <= n then out.fade[k] else -1
			local rim, sole = g.rims[k], g.soles[k]
			if k <= n then
				local cf = CFrame.new(origin + Vector3.new(out.x[k], floorY + 0.03, out.z[k]))
					* CFrame.Angles(0, out.yaw[k], 0)
				table.insert(parts, rim)
				table.insert(cfs, cf)
				table.insert(parts, sole)
				table.insert(cfs, cf * CFrame.new(0, 0.02, 0))
			end
			-- Transparency only when it changes (quantised to 1/20).
			local q = if fade < 0 then -1 else math.floor(fade * 20 + 0.5) / 20
			if q ~= g.printFade[k] then
				g.printFade[k] = q
				if q < 0 then
					rim.Transparency, sole.Transparency = 1, 1
				else
					local t = tr[1] + (tr[2] - tr[1]) * q
					sole.Transparency = t
					rim.Transparency = math.min(1, t + 0.1)
				end
			end
		end
		g.printShown = n
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
		local alarmOn = folderInst:GetAttribute("AlarmOn") == true
		for _, g in guards do
			upkeep(g, now)
			local mode = folderInst:GetAttribute(g.kMode) or "Patrol"
			local tPatrol = tView - (folderInst:GetAttribute(g.kOffset) or 0)
			local patrolling = mode == "Patrol"
			if patrolling then
				g.x, g.z, g.yaw = Guards.patrol(g.def.route, tPatrol)
			else
				local tx = folderInst:GetAttribute(g.kX) or g.x
				local tz = folderInst:GetAttribute(g.kZ) or g.z
				local tyaw = folderInst:GetAttribute(g.kYaw) or g.yaw
				local k = math.clamp(dt * 10, 0, 1)
				g.x += (tx - g.x) * k
				g.z += (tz - g.z) * k
				local d = GusBeats.angleDelta(g.yaw, tyaw)
				g.yaw = (g.yaw + d * k) % TAU
			end
			local moved = math.sqrt((g.x - g.lastX) ^ 2 + (g.z - g.lastZ) ^ 2)
			g.lastX, g.lastZ = g.x, g.z
			local speed = if dt > 0 then moved / dt else 0

			-- Beat
			beatInput.mode = mode
			beatInput.alarmOn = alarmOn
			beatInput.dozer = g.dozer
			beatInput.bang = g.pendingBang
			g.pendingBang = nil
			local st = g.st
			local beat = GusBeats.select(st, beatInput, now)
			if beat ~= g.beat then
				g.beat = beat
				g.heldYaw = g.bodyYaw
				g.barkAt = math.huge
				if running then
					local bark = BARK[beat]
					if bark and not (beat == B.Chase and st.prev == B.Wake) then
						Sound.play(bark, { at = g.head })
					elseif beat == B.DoubleTake then
						g.barkAt = now + GC.ANTICIPATION + 0.4
					end
				end
			end
			if running and now >= g.barkAt then
				g.barkAt = math.huge
				Sound.play("GusBarkHm", { at = g.head })
			end

			-- Walk state (phase by distance; a teleport-sized jump is not a step)
			local chasing = beat == B.Chase
			local bs = g.beatSet
			local w: GusBeats.Walk = bs.walk
			local run = if chasing then math.clamp((speed - 1) / (GC.RUN_SPEED * 0.5), 0, 1) else 0
			w.run = run
			w.amount = math.clamp(speed / GC.WALK_SPEED, 0, 1)
			w.clock = now
			if moved < 3 then
				local stride = GC.WALK_STRIDE + (GC.RUN_STRIDE - GC.WALK_STRIDE) * run
				w.phase = (w.phase + moved / (2 * stride)) % 1
			end

			-- Footsteps and keys by distance walked
			if running and moved < 3 then
				g.stepDist += moved
				if g.stepDist >= AU.GUS_STEP_STRIDE then
					g.stepDist = 0
					g.steps += 1
					Sound.play("GusStep", { at = g.head })
					if patrolling and g.steps % GC.KEYS_STEPS == 0 then
						Sound.play("GusKeys", { at = g.head })
					end
				end
			end
			if running and patrolling and beat ~= B.Doze and now >= g.nextRadio then
				g.nextRadio = now + radioGap()
				Sound.play("GusRadio", { at = g.head })
			end
			if beat == B.Doze then
				local nod = math.floor(now / GC.DOZE_NOD_SECONDS)
				if nod ~= g.nod then
					g.nod = nod
					if running then
						Sound.play("GusSnore", { at = g.head })
					end
				end
			end
			if running and chasing and speed > 1 and now >= g.nextDust then
				g.nextDust = now + H.GUS_DUST_SECONDS
				g.dust:Emit(3)
			end

			-- Pose: the beat (blended from the last one for BLEND seconds)
			local age = now - st.since
			GusBeats.pose(beat, age, w, bs.cur)
			local pose = bs.cur
			if age < GC.BLEND and st.prev ~= beat then
				GusBeats.pose(st.prev, now - st.prevSince, w, bs.prev)
				GusBeats.blend(bs.prev, bs.cur, age / GC.BLEND, bs.out)
				pose = bs.out
			end

			-- Look (C4): head target and body yaw
			if now >= g.nextDelayPush then
				g.nextDelayPush = now + 1 / 60
				GusBeats.delayPush(g.delay, now, g.yaw)
			end
			local headTarget, bodyTarget
			if patrolling then
				local _, _, ahead = Guards.patrol(g.def.route, tPatrol + GC.HEAD_LEAD)
				headTarget, bodyTarget = ahead, g.yaw
			else
				headTarget = g.yaw
				bodyTarget = GusBeats.delaySample(g.delay, now - GC.HEAD_LEAD) or g.yaw
			end
			if not g.posed then
				g.posed = true
				g.bodyYaw, g.heldYaw = bodyTarget, bodyTarget
			end
			-- follow 0 holds the body where it stood when the beat began (the double-take's head-first
			-- look); 1 turns it with the guard. On patrol the body is the route yaw exactly (after a short
			-- settle from another beat), so the head leads it by exactly HEAD_LEAD.
			local follow = math.clamp(pose.follow, 0, 1)
			local want = (g.heldYaw + GusBeats.angleDelta(g.heldYaw, bodyTarget) * follow) % TAU
			if patrolling and follow >= 1 and age >= GC.BLEND * 2.5 then
				g.bodyYaw = want
			else
				local kb = 1 - math.exp(-dt / GC.BODY_SMOOTH)
				g.bodyYaw = (g.bodyYaw + GusBeats.angleDelta(g.bodyYaw, want) * kb) % TAU
			end
			if follow < 1 then
				g.heldYaw = g.bodyYaw
			end
			local rel, lost = GusBeats.look(GusBeats.angleDelta(g.bodyYaw, headTarget), g.lookLost)
			g.lookLost = lost
			local kh = 1 - math.exp(-dt / GC.HEAD_SMOOTH)
			g.headRel += (rel * pose.look - g.headRel) * kh

			local feet = CFrame.new(origin + Vector3.new(g.x, floorY, g.z)) * CFrame.Angles(0, g.bodyYaw, 0)
			GusRig.pose(g.rig, feet, pose, g.headRel, 0, parts, cfs)
			GusRig.setLens(g.rig, pose.lens)

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
					local rr = half - (r - 1) * (2 * half) / (H.CONE_RAYS - 1)
					local a = g.yaw + rr
					g.rays[r] = rayBoxes(boxes, g.x, g.z, -math.sin(a), -math.cos(a), range)
				end
				-- Each wedge only as far as its shorter ray: never through a wall (G10).
				GusBeats.clipFan(g.rays, H.CONE_RAYS, g.clipped)
				local out = g.coneLocal
				table.clear(out)
				for k = 1, H.CONE_RAYS - 1 do
					local len = g.clipped[k]
					local ra = half - (k - 1) * (2 * half) / (H.CONE_RAYS - 1)
					local rb = half - k * (2 * half) / (H.CONE_RAYS - 1)
					local a = Vector3.new(-math.sin(ra) * len, 0, -math.cos(ra) * len)
					local b = Vector3.new(-math.sin(rb) * len, 0, -math.cos(rb) * len)
					local w2 = g.wedges[k]
					triangle(w2[1], w2[2], Vector3.zero, a, b, out)
					local elen = (b - a).Magnitude
					g.edges[k].Size = Vector3.new(0.15, 0.05, math.max(elen, 0.05))
					table.insert(out, if elen > 1e-3 then CFrame.lookAt((a + b) / 2, b) else CFrame.new(a))
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
			local edge = 0.2
			-- The cone flickers in the half second before a patrol turn (A5).
			if patrolling and not banging and GusBeats.turnSoon(g.def.route, tPatrol) then
				local off = 1 - GusBeats.flicker(now)
				fill = math.min(0.95, fill + GC.FLICKER_DEPTH * off)
				edge = math.min(0.95, edge + GC.FLICKER_DEPTH * 2 * off)
			end
			-- Colour and fill only when they change.
			if colour ~= g.shownColour or fill ~= g.shownFill or edge ~= g.shownEdge then
				g.shownColour, g.shownFill, g.shownEdge = colour, fill, edge
				for k = 1, H.CONE_RAYS - 1 do
					local wp = g.wedges[k]
					wp[1].Color, wp[2].Color = colour, colour
					wp[1].Transparency, wp[2].Transparency = fill, fill
					g.edges[k].Color = colour
					g.edges[k].Transparency = edge
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

			-- Boot prints (PRINT_HZ), bubble, nameplate, the WRONG ONE "?"
			if now >= g.nextPrints then
				g.nextPrints = now + 1 / GC.PRINT_HZ
				bootPrints(g, patrolling and beat == B.Patrol and not g.dozer, tPatrol, origin, floorY)
			end
			bubble(g, beat, age, mode, stage, banging)
			nameplate(g, now, running)
			if g.wrongUntil > 0 and now >= g.wrongUntil then
				g.wrongUntil = 0
				g.wrongGui.Enabled = false
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	return view
end

return GusView
