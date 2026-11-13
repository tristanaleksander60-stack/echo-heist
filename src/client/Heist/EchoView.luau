--!strict
-- Heist/EchoView: draws every clone of the run on this client (MASTERPLAN §6.5, §8.2,
-- §8.5 "clone rig"; PLAN_STEAM_PLUS §3.1, §4.4 A1-A3). Clones are pure data on the server; here
-- each one is a pooled rig posed from its recording with Rec/Sampler on the replicated loop clock.
--
--   * Pools per owner, never destroyed on rewind; an owner's pool switches from
--     mannequins to their avatar template once it arrives in ReplicatedStorage.
--   * "That's me" (A2): your textured avatar under one Highlight per owner group (crew-hue fill +
--     outline; your own clones keep it at every performance tier: never invisible by design), a
--     floor glow disc in the crew hue (unlit SurfaceGui, no light object) and a numbered pill over
--     the head (seat icon + number, Icons.seat), hidden beyond CLONE_BADGE_DISTANCE.
--   * Age ramp: each older run 12% dimmer; solo only: older runs drift toward violet
--     (CloneState.driftHue). Other players' clones at 70% brightness; orphan tapes in Tape Grey.
--   * "Tape print": each clone builds up from the feet in Config.Clone.PRINT_SECONDS (parts appear
--     by height under a rising scan band), 60 ms apart in record order, with a floor ring.
--   * Clones act (A3): a per-frame state from the recording (Shared/Heist/CloneState: moving, idle,
--     on-plate, carry, stuck, busted, jump, fall) drives the owner's catalog pack (idle, walk, run,
--     jump, fall; clip speeds locked to the recording by Shared/Heist/CloneGait, so feet do not
--     slide at 1x or 3x) and the custom poses (Shared/Heist/ClonePose: plate stance with one
--     glance back at you, carry, stuck, busted), played as Animation clips baked from ClonePose
--     (Shared/Heist/CloneClips) with an IKControl for the glance; mannequins pose their arms in Lua.
--   * Server-decided outcomes arrive as events: Busted (hands up, glitch slices, then a tape-ribbon
--     burst), Zapped (sparks), Stuck (taps the wall, shrugs), Shrug ("?").
--   * CloneHealth: about once a second every drawn avatar rig is checked (head alive,
--     limbs near the root, joints whole); a broken one is swapped for the mannequin in
--     place and reported once per owner (Telemetry.ui "CloneBroken").
--   * Your live character gets a warm rim and ground ring (Heist/PlayerHalo).
--   * Clone LOD (Config.Perf.CLONE_LOD, Budget.cloneFar): from tier 3 an avatar clone beyond FAR studs
--     of the camera draws as a mannequin in its crew hue (same pill, glow and owner Highlight; the hidden
--     avatar's root still carries the pill, bubble and emitters), back to the textured avatar inside
--     NEAR (hysteresis). The mannequin is built once per pooled entry when the tier first asks for it.
--     Never on your newest clone in the L1 tutorial ("YOU, 10 SEC AGO").
--   * One BulkMoveTo per frame for every rig part, glow and band. Nothing is created per frame:
--     rigs, pills, bubbles, glows, bands and emitters are pooled with the rig. Every burst asks the one
--     shared particle budget first (Heist/Particles).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeistShared = Shared:WaitForChild("Heist")
local Config = require(Shared:WaitForChild("Config")) :: any
local Sampler = require(Shared:WaitForChild("Rec"):WaitForChild("Sampler"))
local Budget = require(HeistShared:WaitForChild("Budget"))
local CloneGait = require(HeistShared:WaitForChild("CloneGait"))
local ClonePose = require(HeistShared:WaitForChild("ClonePose"))
local CloneState = require(HeistShared:WaitForChild("CloneState"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Protocol = require(HeistShared:WaitForChild("Protocol"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Icons = require(script.Parent:WaitForChild("Icons"))
local Particles = require(script.Parent:WaitForChild("Particles"))
local PlayerHalo = require(script.Parent:WaitForChild("PlayerHalo"))
local Rigs = require(script.Parent:WaitForChild("Rigs"))
local Telemetry = require(script.Parent:WaitForChild("Telemetry"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local H = Config.Heist
local C = Config.Clone
local MS = Config.Moments.SWARM
local TAU = 2 * math.pi
local RIBBON_IMAGE = "EH_FX_Ribbon"
-- Clone state -> its custom pose clip (Shared/Heist/CloneClips).
local CLIP_OF = { carry = "carry", ["on-plate"] = "plate", stuck = "stuck", busted = "busted" }

local EchoView = {}

-- template: the owner's template the pool's rigs were built from (a new one, e.g. an outfit change, retires it)
type Pool = { kind: string, free: { any }, group: Model, highlight: Highlight, fx: Folder, template: Model? }

-- The numbered pill over a clone's head: seat icon + number on the seat colour, ink rim.
local function pillGui(anchor: BasePart): (BillboardGui, Frame, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Badge"
	gui.Size = UDim2.fromOffset(C.PILL_SIZE[1], C.PILL_SIZE[2])
	gui.StudsOffset = Vector3.new(0, C.PILL_OFFSET, 0)
	gui.MaxDistance = H.CLONE_BADGE_DISTANCE
	gui.LightInfluence = 0
	local pill = Ui.frame(gui, {
		Name = "Pill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0,
	})
	Ui.pill(pill)
	Ui.stroke(pill, Palette.ink, Theme.STROKE)
	local number = Ui.label(pill, {
		Name = "Number",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -4, 0.5, 0),
		Size = UDim2.fromScale(0.6, 1),
		TextColor3 = Palette.ink,
		TextSize = Theme.TYPE.body,
		Text = "",
	})
	gui.Adornee = anchor
	gui.Parent = anchor
	return gui, pill, number
end

-- The speech bubble (BUSTED, ZAP!, STUCK + cross icon, ?): Strings.CLONE_BUBBLE.
local function bubbleGui(anchor: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(120, 32)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Enabled = false
	local label = Ui.label(gui, {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.TYPE.title,
		TextColor3 = Palette.white,
		Text = "",
	})
	gui.Adornee = anchor
	gui.Parent = anchor
	return gui, label
end

local function emitter(parent: BasePart, name: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	e.Rate = 0
	e.LightInfluence = 0
	e.Parent = parent
	return e
end

local function sparks(parent: BasePart): ParticleEmitter
	local e = emitter(parent, "Burst")
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(Palette.white)
	e.LightEmission = 0.6
	return e
end

-- Tape-ribbon burst (roblox_quality §5.1 "Busted"): curled strips of tape, Tape Grey + the clone hue.
local function ribbons(parent: BasePart): ParticleEmitter
	local e = emitter(parent, "Ribbons")
	e.Texture = C.RIBBON_FALLBACK
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Speed = NumberRange.new(10, 16)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Acceleration = Vector3.new(0, -14, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-240, 240)
	e.Squash = NumberSequence.new(-0.6)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.35) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = 0.2
	e.Brightness = 1.2
	return e
end

-- The scan band of the tape print: a thin neon disc that rises from the feet to the head.
local function band(parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = "PrintBand"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.12, 3.2, 3.2)
	p.Material = Enum.Material.Neon
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Recolours a glow disc (PlayerHalo.disc): every disc frame and the ring's stroke.
local function tintGlow(gui: SurfaceGui, hue: Color3)
	for _, f in gui:GetChildren() do
		if f:IsA("Frame") then
			if f.Name == "Ring" then
				local s = f:FindFirstChildOfClass("UIStroke")
				if s then
					s.Color = hue
				end
			else
				f.BackgroundColor3 = hue
			end
		end
	end
end

-- Ribbon emitters waiting for the ribbon texture (shared by every view; set once it resolves).
local ribbonList: { ParticleEmitter } = {}
local ribbonUri: string? = nil
local function useRibbon(e: ParticleEmitter)
	if ribbonUri then
		e.Texture = ribbonUri
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid2x2
		e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
		e.FlipbookFramerate = NumberRange.new(4, 8)
		e.FlipbookStartRandom = true
	else
		table.insert(ribbonList, e)
	end
end
Theme.onImage(RIBBON_IMAGE, function(uri: string)
	ribbonUri = uri
	local waiting = table.clone(ribbonList)
	table.clear(ribbonList)
	for _, e in waiting do
		if e.Parent then
			useRibbon(e)
		end
	end
end)

-- Path lengths per recording (CloneGait.distances), computed once per recording.
local distCache: { [any]: { number } } = setmetatable({} :: any, { __mode = "k" })
local function distancesOf(rec: any): { number }
	local d = distCache[rec]
	if not d then
		d = CloneGait.distances(rec)
		distCache[rec] = d
	end
	return d
end

function EchoView.new(state: any): any
	-- The viewer: the local player (the engine tests run these views on the server and name
	-- the viewer in state.viewerId).
	local function myId(): number
		if type(state.viewerId) == "number" then
			return state.viewerId
		end
		local lp = Players.LocalPlayer
		return if lp then lp.UserId else 0
	end

	local folder = Instance.new("Folder")
	folder.Name = "HeistClones"
	folder.Parent = workspace

	local pools: { [number]: Pool } = {}
	-- Pools replaced (mannequin -> avatar) while their rigs may still be on screen: destroyed
	-- at the next setRun / clear, once every rig in them has been released.
	local retiring: { Pool } = {}
	local active: { [number]: any } = {} -- actorId -> entry
	local order: { any } = {}
	local run: any = nil
	local view = {}
	local trailsOn = true
	local tierNow = 1
	local newestOwnId = 0
	-- Owners whose avatar rig broke at runtime: their clones draw as mannequins from then on.
	local brokenOwners: { [number]: string } = {}
	local healthAt = 0
	local lastHealthy = 0
	local halo = PlayerHalo.new(folder)
	-- The view's clock rate (1x, 3x fast-forward, the reel's), measured per frame.
	local lastT: number? = nil
	local rate = 1
	-- Loot carriers this frame (server attributes K<i>State / K<i>Carrier), actor id -> true.
	local carriedBy: { [number]: boolean } = {}
	local lootKeys: { { string } } = {}
	local ctx: any = { gone = nil, stuck = nil, carrying = nil, plates = nil, prevLoco = nil }

	-- "◀ YOU, 10 SEC AGO" (§6.5 #5): one label for the view, moved to the newest own clone.
	local youGui: BillboardGui? = nil
	local youText: TextLabel? = nil
	local function youLabel(anchor: BasePart, text: string)
		local gui = youGui
		local label = youText
		if not gui or not label then
			local g = Instance.new("BillboardGui")
			g.Name = "YouLabel"
			g.Size = UDim2.fromOffset(190, 30)
			g.StudsOffset = Vector3.new(0, 3.6, 0)
			g.MaxDistance = 120
			g.LightInfluence = 0
			local l = Ui.label(g, {
				Name = "Text",
				Size = UDim2.fromScale(1, 1),
				RichText = true,
				TextColor3 = Palette.exit,
				TextSize = Theme.TYPE.body,
				Text = "",
			})
			l.BackgroundColor3 = Palette.ink
			l.BackgroundTransparency = 0.25
			Ui.pill(l)
			g.Parent = folder
			gui, label = g, l
			youGui, youText = g, l
		end
		local g, l = gui :: BillboardGui, label :: TextLabel
		l.Text = text
		g.Adornee = anchor
		g.Enabled = true
	end
	-- First person (wave C): the clone walks out of your own body at your eye height, so its label sits just
	-- over its head, in frame from a few studs behind it, not 3.6 studs up and above the frame.
	local function placeYouLabel()
		local gui = youGui
		if gui then
			local lift = if state.fpView == true then Config.Onboarding.YOU_LABEL_FP_LIFT else 3.6
			if gui.StudsOffset.Y ~= lift then
				gui.StudsOffset = Vector3.new(0, lift, 0)
			end
		end
	end
	local function hideYouLabel()
		if youGui then
			youGui.Enabled = false
			youGui.Adornee = nil
		end
	end

	local function templateOf(ownerId: number): Model?
		local f = ReplicatedStorage:FindFirstChild(Protocol.AVATARS)
		local t = f and f:FindFirstChild(tostring(ownerId))
		if t and t:IsA("Model") then
			return t
		end
		return nil
	end

	-- §6.8: tier 4 drops the Highlights, except on your own clones (never invisible by design).
	local function highlightOn(ownerId: number): boolean
		return Budget.othersHighlight(tierNow) or ownerId == myId()
	end

	local function poolFor(ownerId: number, hue: Color3): Pool
		local template = templateOf(ownerId)
		local want = if template and not brokenOwners[ownerId] then "avatar" else "mannequin"
		local pool = pools[ownerId]
		if pool and (pool.kind ~= want or (want == "avatar" and pool.template ~= template)) then
			pool.group.Name = "Retired_" .. tostring(ownerId)
			table.insert(retiring, pool)
			pools[ownerId] = nil
			pool = nil
		end
		if not pool then
			local group = Instance.new("Model")
			group.Name = "Owner_" .. tostring(ownerId)
			local hl = Instance.new("Highlight")
			hl.FillTransparency = H.CLONE_FILL_TRANSPARENCY
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Enabled = highlightOn(ownerId)
			hl.Adornee = group
			hl.Parent = group
			group.Parent = folder
			-- Glows and print bands sit outside the group, so the Highlight never outlines them.
			local fx = Instance.new("Folder")
			fx.Name = "Fx_" .. tostring(ownerId)
			fx.Parent = folder
			pool = {
				kind = want,
				free = {},
				group = group,
				highlight = hl,
				fx = fx,
				template = if want == "avatar" then template else nil,
			}
			pools[ownerId] = pool
		end
		local p = pool :: Pool
		p.highlight.OutlineColor = hue
		p.highlight.FillColor = hue
		return p
	end

	local function destroyPool(pool: Pool)
		pool.group:Destroy()
		pool.fx:Destroy()
	end

	-- Clone LOD: an avatar entry's light rig, a crew-hue mannequin in the owner group (so the owner Highlight
	-- outlines it too), built once and kept with the pooled entry.
	local function ensureLod(entry: any)
		if entry.lodRig or entry.rig.kind ~= "avatar" then
			return
		end
		local m = Rigs.buildMannequin()
		m.model.Name = "Lod"
		Rigs.setFade(m, 1)
		if entry.hue then
			Rigs.tint(m, entry.hue)
		end
		m.model.Parent = entry.pool.group
		entry.lodRig = m
	end

	-- Swaps which rig draws the clone (no allocation): the other one hides; the fade carries over.
	local function setFar(entry: any, far: boolean)
		local lod = entry.lodRig
		if entry.far == far or (far and not lod) then
			return
		end
		entry.far = far
		local from = entry.drawn
		local to = if far then lod else entry.rig
		entry.drawn = to
		Rigs.setFade(from, 1)
		Rigs.setFade(to, if entry.fade >= 0 then entry.fade else 0)
		if far then
			Rigs.setPose(entry.rig, nil) -- the hidden avatar stops its clips; its root keeps carrying the fx
			Rigs.lookAt(entry.rig, nil, 0)
		end
	end

	-- Hides both rigs of an entry and puts the textured one back in charge.
	local function hideRigs(entry: any)
		Rigs.setFade(entry.rig, 1)
		if entry.lodRig then
			Rigs.setFade(entry.lodRig, 1)
		end
		entry.far = false
		entry.drawn = entry.rig
	end

	local function newEntry(pool: Pool, ownerId: number): any
		local rig: any = nil
		local t = if pool.kind == "avatar" then templateOf(ownerId) else nil
		if t then
			rig = Rigs.buildAvatar(t)
		end
		rig = rig or Rigs.buildMannequin()
		rig.model.Parent = pool.group
		Rigs.loadPack(rig, Rigs.packOf(t))
		local anchor = Rigs.anchorPart(rig)
		local badge, pill, number = pillGui(anchor)
		badge.MaxDistance = Budget.pillDistance(tierNow)
		local bubble, bubbleText = bubbleGui(anchor)
		local trailA0 = Instance.new("Attachment")
		trailA0.Position = Vector3.new(0, 0.6, 0)
		trailA0.Parent = anchor
		local trailA1 = Instance.new("Attachment")
		trailA1.Position = Vector3.new(0, -1.2, 0)
		trailA1.Parent = anchor
		local trail = Instance.new("Trail")
		trail.Attachment0 = trailA0
		trail.Attachment1 = trailA1
		trail.Lifetime = 0.5
		trail.LightEmission = 0.5
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.Enabled = false
		trail.Parent = anchor
		local glowPart, glowGui, glowRing =
			PlayerHalo.disc("FloorGlow", C.GLOW_SIZE, Palette.white, C.GLOW_ALPHA, C.GLOW_RING_ALPHA, C.GLOW_DISC)
		glowGui.Enabled = false
		glowPart.Parent = pool.fx
		local ribbon = ribbons(anchor)
		useRibbon(ribbon)
		local entry: any = {
			rig = rig,
			pool = pool,
			badge = badge,
			pill = pill,
			number = number,
			pillIcon = nil :: ImageLabel?,
			pillIconName = "seat_circle",
			bubble = bubble,
			bubbleText = bubbleText,
			bubbleIcon = nil :: ImageLabel?,
			bubbleUntil = 0,
			trail = trail,
			emitter = sparks(anchor),
			ribbons = ribbon,
			glowPart = glowPart,
			glowGui = glowGui,
			glowRing = glowRing,
			band = band(pool.fx),
			height = Rigs.heightOf(rig),
			frame = CloneState.newFrame(),
			pose = ClonePose.new(),
			gait = CloneGait.new(),
			airFrom = nil :: number?, -- recording time the clone left the floor (the land clip)
			phase = 0,
			fade = -1,
			near = false,
			glowOk = true, -- the tier's glow budget (Budget.glowSet) lets this clone draw its floor glow
			camDist = 0,
			drawn = rig, -- the rig on screen: `rig`, or `lodRig` while the clone LOD draws it light
			lodRig = nil :: any, -- avatar entries: the crew-hue mannequin (ensureLod, from CLONE_LOD.TIER)
			far = false,
			lodExempt = false,
		}
		if Budget.cloneLod(tierNow) then
			ensureLod(entry)
		end
		Icons.attach(pill, "seat_circle", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 5, 0.5, 0),
			Size = UDim2.fromOffset(C.PILL_SIZE[2] - 8, C.PILL_SIZE[2] - 8),
			ImageColor3 = Palette.ink,
		}, function(img: ImageLabel)
			entry.pillIcon = img
			Icons.set(img, entry.pillIconName)
		end)
		Icons.attach(bubbleText, "cross", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			ImageColor3 = Palette.alarm,
			Visible = false,
		}, function(img: ImageLabel)
			entry.bubbleIcon = img
		end)
		return entry
	end

	-- Drops the rig pools of owners who are no longer in the crew (each pool holds
	-- hidden avatar rigs and an enabled Highlight for the whole session otherwise).
	local function prunePools(keep: { [number]: boolean })
		for ownerId, pool in pools do
			if not keep[ownerId] and ownerId ~= myId() then
				destroyPool(pool)
				pools[ownerId] = nil
			end
		end
	end

	local function crewSet(): { [number]: boolean }
		local keep: { [number]: boolean } = {}
		for _, m in state.crew or {} do
			keep[m.userId] = true
		end
		return keep
	end

	local function hideFx(entry: any)
		entry.glowGui.Enabled = false
		entry.band.Transparency = 1
		entry.badge.Enabled = false
		entry.trail.Enabled = false
		entry.bubble.Enabled = false
		if entry.youLabel then
			entry.youLabel = false
			hideYouLabel()
		end
	end

	local function release(entry: any)
		local rig = entry.rig
		hideRigs(entry)
		Rigs.locomote(rig, "none", 0, 0, 1, 0, false, false)
		Rigs.setPose(rig, nil)
		Rigs.lookAt(rig, nil, 0)
		entry.pose.busy = false
		hideFx(entry)
		entry.fade = 1
		entry.burstAt = nil
		table.insert(entry.pool.free, entry)
	end

	local function hueFor(a: any, rank: number, ownCount: number, solo: boolean): Color3
		if a.orphan then
			return Palette.tapeGrey
		end
		local hue = Palette.hueFor(a.seat)
		if solo then
			-- Older runs drift toward violet, solo only (§6.5 #4): co-op seat hues must stay apart.
			local h, s, v = hue:ToHSV()
			hue = Color3.fromHSV(CloneState.driftHue(h, rank, ownCount, true), s, v)
		end
		local dim = 1 - H.CLONE_AGE_DIM * rank
		if a.owner ~= myId() then
			dim *= H.OTHER_CLONE_BRIGHTNESS
		end
		return Palette.dim(hue, math.max(dim, 0.35))
	end

	local function flushRetiring()
		for _, pool in retiring do
			destroyPool(pool)
		end
		table.clear(retiring)
	end

	-- The clone's look: hue (rig tint, glow, trail, sparks), pill (seat colour, icon, number).
	local function dress(entry: any, a: any, hue: Color3)
		Rigs.tint(entry.rig, hue)
		if entry.lodRig then
			Rigs.tint(entry.lodRig, hue)
		end
		entry.hue = hue
		local seatHue = if a.orphan then Palette.tapeGrey else Palette.hueFor(a.seat)
		entry.pill.BackgroundColor3 = seatHue
		entry.seatHue = seatHue
		entry.number.Text = Strings.cloneNumber(a.slot)
		entry.pillIconName = Icons.seat(a.seat)
		Icons.set(entry.pillIcon, entry.pillIconName)
		entry.trail.Color = ColorSequence.new(hue)
		entry.emitter.Color = ColorSequence.new(hue)
		entry.ribbons.Color = ColorSequence.new(Palette.tapeGrey, hue)
		tintGlow(entry.glowGui, hue)
		entry.band.Color = hue
	end

	-- Fresh per-run state of an entry.
	local function restart(entry: any)
		hideRigs(entry) -- a fresh rig is visible until it prints
		entry.lodExempt = false
		entry.fade = 1
		entry.goneShown = false
		entry.phase = 0
		entry.near = false
		entry.printed = false
		entry.printDone = nil
		entry.stateName = nil
		entry.stateSince = 0
		entry.outName = nil
		entry.burstAt = nil
		entry.beatAt = nil
		entry.beatLit = false
		entry.hop = 0
		entry.carrying = false
		entry.glowY = nil
		entry.frame.loco = "idle"
		entry.printing = false
		entry.band.Transparency = 1
		entry.glowRing.Size = UDim2.fromScale(C.GLOW_DISC, C.GLOW_DISC)
		local stroke = entry.glowRing:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = C.GLOW_RING_ALPHA
		end
		CloneGait.reset(entry.gait)
	end

	-- A new run: hand every clone actor a rig from its owner's pool.
	function view.setRun(msg: any, recs: { [number]: any }, startLocal: number)
		for _, entry in active do
			release(entry)
		end
		flushRetiring()
		table.clear(active)
		table.clear(order)
		run = msg
		newestOwnId = 0
		lastT = nil
		local keep = crewSet()
		for _, a in msg.actors do
			keep[a.owner] = true -- orphan tapes of a player who left still draw
		end
		prunePools(keep)
		local solo = #(state.crew or {}) <= 1
		-- Loot attribute names, built once per run (no string building per frame).
		table.clear(lootKeys)
		local level = state.level
		for i = 1, #(level and level.loot or {}) do
			lootKeys[i] = { "K" .. i .. "State", "K" .. i .. "Carrier" }
		end
		-- Rank own clones by age (newest = 0) per owner.
		local byOwner: { [number]: { any } } = {}
		for _, a in msg.actors do
			if a.kind == "clone" then
				byOwner[a.owner] = byOwner[a.owner] or {}
				table.insert(byOwner[a.owner], a)
			end
		end
		local rankOf: { [number]: number } = {}
		local newestOwn: any = nil
		for owner, list in byOwner do
			table.sort(list, function(x, y)
				return x.run > y.run or (x.run == y.run and x.slot > y.slot)
			end)
			for r, a in list do
				rankOf[a.id] = r - 1
			end
			if owner == myId() then
				newestOwn = list[1]
			end
		end
		local k = 0
		for _, a in msg.actors do
			local rec = recs[a.key]
			if a.kind ~= "clone" or not rec then
				continue
			end
			local list = byOwner[a.owner]
			local hue = hueFor(a, rankOf[a.id] or 0, #list, solo)
			local pool = poolFor(a.owner, Palette.hueFor(a.seat))
			local entry = table.remove(pool.free) or newEntry(pool, a.owner)
			restart(entry)
			dress(entry, a, hue)
			entry.actor = a
			entry.rec = rec
			entry.dist = distancesOf(rec)
			entry.visibleAt = startLocal + k * H.CLONE_SPAWN_STAGGER
			k += 1
			if a == newestOwn then
				newestOwnId = a.id
			end
			if a == newestOwn and state.level and state.level.tutorial ~= nil then
				entry.lodExempt = true -- the "YOU, 10 SEC AGO" moment is always your own avatar
				-- "◀ YOU, 10 SEC AGO" (§6.5 #5, §7.5): the number is always true (CLIPS §1.2).
				local duration = Sampler.duration(rec)
				local secs = duration + (msg.transition or 0)
				-- §7.5 (13-22 s): the clone forms a beat after control returns, so it visibly
				-- walks out of you, and its label stays until it has stopped on the plate.
				local controlAt = startLocal + (msg.transition or 0) * 0.25
				entry.visibleAt = controlAt + H.TUTORIAL_CLONE_FADE_IN
				youLabel(Rigs.anchorPart(entry.rig), Ui.agoLabel("YOU", secs, Palette.hueFor(a.seat)))
				entry.youLabel = true
				entry.labelUntil = controlAt
					+ math.min(duration, H.CLONE_LABEL_MAX_SECONDS)
					+ H.CLONE_LABEL_HOLD_AFTER_STOP
			end
			active[a.id] = entry
			table.insert(order, entry)
		end
		flushRetiring()
	end

	local function say(entry: any, text: string, color: Color3, seconds: number, now: number, cross: boolean?)
		entry.bubbleText.Text = text
		entry.bubbleText.TextColor3 = color
		if entry.bubbleIcon then
			entry.bubbleIcon.Visible = cross == true
		end
		entry.bubble.Enabled = true
		entry.bubbleUntil = now + seconds
	end

	-- A server-decided outcome for a clone (from the event log).
	function view.effect(actorId: number, kind: string, now: number)
		local entry = active[actorId]
		if not entry then
			return
		end
		local words = Strings.CLONE_BUBBLE
		if kind == "Busted" then
			-- Hands up and the glitch first (ClonePose); the tape-ribbon burst when it vanishes.
			entry.burstAt = now + ClonePose.bustedSeconds()
			say(entry, words.Busted, Palette.alarm, 1.2, now)
		elseif kind == "Zapped" then
			entry.emitter.Color = ColorSequence.new(Palette.ink)
			Particles.emit(entry.emitter, Budget.burst(tierNow, C.ZAP_SPARKS))
			entry.emitter.Color = ColorSequence.new(entry.hue)
			say(entry, words.Zapped, Palette.alarm, 1.0, now)
		elseif kind == "Stuck" then
			say(entry, words.Stuck, Palette.alarm, 3.0, now, true)
		elseif kind == "Shrug" then
			say(entry, words.Shrug, Palette.white, 1.2, now)
		end
	end

	function view.positionOf(actorId: number): Vector3?
		local entry = active[actorId]
		if entry and entry.lastPos then
			return entry.lastPos
		end
		return nil
	end

	-- Where a clone's carried loot hangs, minus Config.Clone.CARRY_LIFT (WorldView adds the lift to
	-- every carrier point): between its hands, bobbing, while it carries (also while it is stuck or in
	-- the air); positionOf otherwise.
	function view.carryPointOf(actorId: number): Vector3?
		local entry = active[actorId]
		if not entry or not entry.lastFeet then
			return view.positionOf(actorId)
		end
		if not entry.carrying then
			return entry.lastPos
		end
		local s = entry.rig.scale or 1
		local hands = C.CARRY_HANDS
		local at = entry.lastFeet
			* CFrame.new(hands[1] * s, entry.rig.rootHeight + hands[2] * s + (entry.bob or 0), hands[3] * s)
		return at.Position - Vector3.new(0, C.CARRY_LIFT, 0)
	end

	-- Loot carriers from the instance folder's attributes (the server decides who carries).
	local function readCarriers()
		table.clear(carriedBy)
		local f: Instance? = state.folder
		if not f then
			return
		end
		for _, k in lootKeys do
			if f:GetAttribute(k[1]) == "Carried" then
				local by = f:GetAttribute(k[2])
				if type(by) == "number" and by > 0 then
					carriedBy[by] = true
				end
			end
		end
	end

	-- Your live character's head (the plate glance looks back at you).
	local function ownerHead(ownerId: number): Vector3?
		local p = Players:GetPlayerByUserId(ownerId)
		local char = p and p.Character
		local head = char and char:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position
		end
		return nil
	end

	-- Seconds after a clone is gone until it has fully vanished.
	local function goneSeconds(kind: string): number
		return if kind == "Busted" then ClonePose.bustedSeconds() else C.ZAP_FADE
	end

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}

	-- The tier's floor-glow budget (Budget.glowSet: your own clones first, then the nearest). Rechecked every
	-- Config.Perf.GLOW_RECHECK_SECONDS and on a tier change; a clone over the budget keeps its pill and Highlight.
	local glowCheckAt = -math.huge
	local glowCandidates: { Budget.GlowCandidate } = {}
	local function applyGlowBudget()
		local me = myId()
		table.clear(glowCandidates)
		for i, entry in order do
			glowCandidates[i] = { own = entry.actor ~= nil and entry.actor.owner == me, dist = entry.camDist or 0 }
		end
		local allowed = Budget.glowSet(tierNow, glowCandidates)
		for i, entry in order do
			local ok = allowed[i] == true
			if entry.glowOk ~= ok then
				entry.glowOk = ok
				entry.glowGui.Enabled = ok and (entry.printing == true or entry.fade < 1)
			end
		end
	end

	-- Poses every clone at view time tView (or along the reel when `reelT` is set:
	-- the rewind plays each path backwards from the end of the last run, §7.1).
	function view.update(tView: number, now: number, dt: number, reelT: number?)
		halo.update(state.fpView == true) -- first person: no rim on your own (hidden) body
		if not run then
			return
		end
		table.clear(parts)
		table.clear(cframes)
		local origin: Vector3 = state.origin
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		-- Clock rate: the run clock's, or measured from the view time (reel, tests).
		local tNow = reelT or tView
		local clock = state.clock
		if clock and state.phase == "Run" and not reelT then
			rate = clock.rate
		elseif lastT and dt > 0 then
			local raw = math.abs(tNow - (lastT :: number)) / dt
			if raw <= C.MAX_VIEW_RATE then
				rate = raw
			end
		end
		lastT = tNow
		readCarriers()
		local level = state.level
		ctx.plates = level and level.plates
		for _, entry in order do
			local a = entry.actor
			local fx = state.actorFx[a.id]
			local rig = entry.rig
			if entry.burstAt and now >= entry.burstAt then
				entry.burstAt = nil
				if not state.reduced then
					Particles.emit(entry.ribbons, Budget.burst(tierNow, C.RIBBON_COUNT))
				end
				Particles.emit(entry.emitter, Budget.burst(tierNow, C.SPARK_COUNT))
			end
			-- Gone (busted / zapped, vanished): nothing to sample or pose until the reel.
			local goneFor = if fx and fx.gone and not reelT then now - (fx.goneAtLocal or now) else -1
			if goneFor > goneSeconds(fx and fx.gone or "") and entry.fade >= 1 then
				continue
			end
			local rec = entry.rec
			local t = reelT or tView
			if fx and fx.stuckT and not reelT then
				t = math.min(t, fx.stuckT)
			end
			ctx.gone = if fx and not reelT then fx.gone else nil
			ctx.stuck = fx ~= nil and fx.stuckT ~= nil and not reelT
			ctx.carrying = carriedBy[a.id] == true and not reelT
			entry.carrying = ctx.carrying
			ctx.prevLoco = entry.frame.loco
			local f = CloneState.derive(rec, t, ctx, entry.frame)
			if not f then
				continue
			end
			if f.state ~= entry.stateName then
				if entry.stateName and ClonePose.CUSTOM[entry.stateName] then
					entry.outName, entry.outAt, entry.outFrom = entry.stateName, now, entry.stateSince
				end
				entry.stateName, entry.stateSince = f.state, now
			end
			local feet = CFrame.new(origin + Vector3.new(f.x, f.y - rig.rootHeight, f.z)) * CFrame.Angles(0, f.yaw, 0)
			local pos = feet.Position + Vector3.new(0, 3, 0)
			local camDist = (pos - camPos).Magnitude
			entry.camDist = camDist
			-- Clone LOD (hysteresis in Budget.cloneFar): the light rig beyond FAR, the avatar again inside NEAR.
			if entry.lodRig then
				local wantFar = Budget.cloneFar(tierNow, camDist, entry.far, entry.lodExempt)
				if wantFar ~= entry.far then
					setFar(entry, wantFar)
				end
			end
			local far = entry.far

			-- Walk cycle locked to the recording: distance travelled, not wall time.
			local distance = CloneGait.distanceAt(rec, entry.dist, t)
			entry.phase = distance / C.MANNEQUIN_STRIDE * TAU
			local walkPhase = distance / CloneGait.RUN_STRIDE * TAU

			-- Custom pose (blend in, or out of the last custom state).
			local pose = entry.pose
			local poseName: string? = nil
			local since, weight = 0, 0
			local zapped = f.state == CloneState.BUSTED and not (fx and fx.gone == "Busted")
			if ClonePose.CUSTOM[f.state] and not zapped then
				poseName = f.state
				since = now - entry.stateSince
				if f.state == CloneState.BUSTED and fx and fx.goneAtLocal then
					since = now - fx.goneAtLocal
				end
				weight = if f.state == CloneState.BUSTED then 1 else math.min(1, since / C.POSE_BLEND)
			elseif entry.outName and now - entry.outAt < C.POSE_BLEND then
				poseName = entry.outName
				since = now - entry.outFrom
				weight = 1 - (now - entry.outAt) / C.POSE_BLEND
			end
			local near = camDist < C.POSE_DISTANCE
			local lookPoint: Vector3? = nil
			local lookWeight = 0
			if poseName and near then
				local yawL, pitchL = 0, 0
				local g = if poseName == CloneState.PLATE then ClonePose.glance(since) else 0
				if g > 0 then
					local target = ownerHead(a.owner)
					if target then
						local head = feet.Position + Vector3.new(0, rig.rootHeight * 1.5, 0)
						local d = target - head
						local y, p, ok = ClonePose.look(d.X, d.Y, d.Z, f.yaw)
						if ok then
							yawL, pitchL = y, p
							-- the IK target sits along the clamped direction, so the limits hold
							local dir = feet:VectorToWorldSpace(
								Vector3.new(-math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))
							)
							lookPoint = head + dir * C.LOOK_REACH
							lookWeight = g * weight
						end
					end
				end
				ClonePose.compute(pose, poseName, since, now, walkPhase, f.loco == "move", yawL, pitchL, weight)
			else
				ClonePose.compute(pose, "", 0, now, 0, false, 0, 0, 0)
			end
			-- Avatars: the pose clip (Animator, Action priority) and the glance IK; the clip's own fade
			-- blends in and out. Mannequins: the Lua arm angles below.
			if rig.kind == "avatar" and not far then
				local clip = if ClonePose.CUSTOM[f.state]
						and not zapped
						and near
						and entry.fade < 1
					then CLIP_OF[f.state]
					else nil
				Rigs.setPose(rig, clip)
				Rigs.lookAt(rig, lookPoint, lookWeight)
				if clip == "carry" then
					local tp = Rigs.poseTime(rig)
					entry.bob = math.sin(tp * TAU * C.CARRY_BOB_IDLE_HZ) * C.CARRY_BOB * 0.5
				else
					entry.bob = 0
				end
			else
				entry.bob = pose.bob
			end
			if pose.glitchX ~= 0 and not state.reduced then
				feet *= CFrame.new(pose.glitchX, 0, 0)
			end
			-- A roll-call beat (Heist/MomentDirector, 8 OF ME): one hop and a white pill flash.
			local hop = 0
			local beatAt = entry.beatAt
			if beatAt and now >= beatAt then
				local pe = now - beatAt
				if pe < MS.BEAT_SECONDS then
					hop = if state.reduced then 0 else MS.BEAT_HOP * math.sin(pe / MS.BEAT_SECONDS * math.pi)
					if not entry.beatLit then
						entry.beatLit = true
						entry.pill.BackgroundColor3 = Palette.white
					end
				else
					entry.beatAt = nil
					entry.beatLit = false
					entry.pill.BackgroundColor3 = entry.seatHue or Palette.white
				end
			end
			entry.hop = hop
			Rigs.pose(
				rig,
				if hop ~= 0 then feet * CFrame.new(0, hop, 0) else feet,
				entry.phase,
				math.clamp(f.speed / 10, 0, 1),
				parts,
				cframes,
				if pose.busy then pose.joints else nil
			)
			if far then
				-- the light rig poses like a mannequin; the avatar's root above still carries the pill and fx
				Rigs.pose(
					entry.lodRig,
					if hop ~= 0 then feet * CFrame.new(0, hop, 0) else feet,
					entry.phase,
					math.clamp(f.speed / 10, 0, 1),
					parts,
					cframes,
					if pose.busy then pose.joints else nil
				)
			end
			entry.lastPos = pos
			entry.lastFeet = feet

			-- Visibility: tape print, gone after an outcome, near-camera fade.
			local fade = 0
			local printing = false
			if now < entry.visibleAt and not reelT then
				fade = 1
			elseif not entry.printed and not reelT then
				entry.printed = true
				printing = not state.reduced and now - entry.visibleAt < C.PRINT_SECONDS
				if not printing then
					entry.printDone = now
				end
			elseif not entry.printDone and not reelT then
				printing = now - entry.visibleAt < C.PRINT_SECONDS
				if not printing then
					entry.printDone = now
				end
			end
			if goneFor >= 0 then
				local total = goneSeconds(fx.gone)
				if goneFor > total then
					fade = 1
				elseif fx.gone == "Busted" then
					-- hands up first (visible), then the glitch slices; reduced motion: one smooth fade
					local g = goneFor - C.BUSTED_HANDS_UP
					fade = if g < 0
						then 0
						elseif state.reduced then g / C.BUSTED_GLITCH
						elseif pose.glitchX ~= 0 then 0.5
						else 0
				else
					-- zapped: flicker out at <= BLINK_HZ_MAX flashes a second (§7.3)
					fade = if state.reduced
						then goneFor / total
						elseif math.floor(goneFor * 2 * H.BLINK_HZ_MAX) % 2 == 0 then 0.6
						else 0
				end
			end
			-- Near-camera fade with hysteresis (a crowd of clones around you must not flip).
			if entry.near then
				entry.near = camDist < H.CLONE_NEAR_UNFADE
			else
				entry.near = camDist < H.CLONE_NEAR_FADE
			end
			if fade < 1 and entry.near and not printing then
				fade = math.max(fade, 0.7)
			end

			-- Floor glow: on the floor under the clone (it stays down while the clone is airborne).
			if f.loco ~= "jump" and f.loco ~= "fall" or not entry.glowY then
				entry.glowY = feet.Position.Y
			end
			local glowAt = Vector3.new(feet.Position.X, entry.glowY + 0.06, feet.Position.Z)
			table.insert(parts, entry.glowPart)
			table.insert(cframes, CFrame.new(glowAt))

			if printing then
				local p = math.clamp((now - entry.visibleAt) / C.PRINT_SECONDS, 0, 1)
				local h = p * entry.height
				Rigs.setPrint(entry.drawn, h)
				entry.fade = 0
				entry.badge.Enabled = true
				entry.glowGui.Enabled = entry.glowOk
				entry.band.Transparency = C.PRINT_BAND_ALPHA + (1 - C.PRINT_BAND_ALPHA) * p
				table.insert(parts, entry.band)
				table.insert(cframes, CFrame.new(glowAt + Vector3.new(0, h, 0)) * CFrame.Angles(0, 0, math.pi / 2))
				local ring = C.PRINT_RING_FROM + (1 - C.PRINT_RING_FROM) * p
				entry.glowRing.Size = UDim2.fromScale(ring, ring)
				local stroke = entry.glowRing:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Transparency = p
				end
				entry.printing = true
			else
				if entry.printing then
					-- print over: the band goes, the ring settles at the disc's rim
					entry.printing = false
					entry.band.Transparency = 1
					entry.glowRing.Size = UDim2.fromScale(C.GLOW_DISC, C.GLOW_DISC)
					local stroke = entry.glowRing:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke.Transparency = C.GLOW_RING_ALPHA
					end
					entry.fade = -1
				end
				if fade ~= entry.fade then
					entry.fade = fade
					Rigs.setFade(entry.drawn, fade)
					entry.badge.Enabled = fade < 1
					entry.glowGui.Enabled = fade < 1 and entry.glowOk
				end
			end

			-- Catalog animations: off when hidden or far (the root still moves).
			local loco = if entry.fade >= 1 or camDist > C.ANIM_DISTANCE or far then "none" else f.loco
			local sendSpeed, sendWeights = false, false
			if loco == "move" then
				sendSpeed, sendWeights = CloneGait.step(entry.gait, f.speed, rate)
			end
			local g = entry.gait
			local walkPhase0, runPhase0 = CloneGait.phase(distance)
			Rigs.locomote(
				rig,
				loco,
				math.max(g.speed, 0),
				math.max(g.runSpeed, 0),
				g.walkW,
				g.runW,
				sendSpeed,
				sendWeights,
				walkPhase0,
				runPhase0,
				rate
			)
			-- the landing squash after a real fall (recording time in the air, so 3x lands like 1x)
			local airborne = f.loco == "jump" or f.loco == "fall"
			if airborne then
				entry.airFrom = entry.airFrom or t
			elseif entry.airFrom then
				if loco ~= "none" and math.abs(t - entry.airFrom) >= Config.Rookie.ANIM.LAND.minFall then
					Rigs.land(rig, f.speed)
				end
				entry.airFrom = nil
			end

			entry.trail.Enabled = trailsOn and entry.fade < 1 and (reelT ~= nil or f.speed > Config.Rec.WALK_SPEED + 1)
			if entry.bubble.Enabled and now > entry.bubbleUntil then
				entry.bubble.Enabled = false
			end
			if entry.youLabel and now > (entry.labelUntil or 0) then
				entry.youLabel = false
				hideYouLabel()
			elseif entry.youLabel then
				placeYouLabel()
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
		if now - glowCheckAt >= Config.Perf.GLOW_RECHECK_SECONDS then
			glowCheckAt = now
			applyGlowBudget()
		end
		if now - healthAt >= H.CLONE_HEALTH_INTERVAL then
			healthAt = now
			view.checkHealth()
		end
	end

	-- Swaps one drawn clone's rig for a fresh entry from the owner's (now mannequin) pool,
	-- keeping its actor, recording, timing and look; the old rig hides until its pool retires.
	local function swapEntry(old: any, ownerId: number)
		local a = old.actor
		local pool = poolFor(ownerId, Palette.hueFor(a.seat))
		local entry = table.remove(pool.free) or newEntry(pool, ownerId)
		hideRigs(old)
		Rigs.locomote(old.rig, "none", 0, 0, 1, 0, false, false)
		Rigs.setPose(old.rig, nil)
		Rigs.lookAt(old.rig, nil, 0)
		old.pose.busy = false
		local hadLabel = old.youLabel
		hideFx(old)
		restart(entry)
		dress(entry, a, old.hue)
		entry.actor = a
		entry.rec = old.rec
		entry.dist = old.dist
		entry.visibleAt = old.visibleAt
		entry.printed = true
		entry.printDone = old.printDone or old.visibleAt
		entry.fade = -1 -- the next update writes the fade
		entry.goneShown = old.goneShown
		entry.near = old.near
		entry.lastPos = old.lastPos
		entry.lastFeet = old.lastFeet
		entry.burstAt = old.burstAt
		if hadLabel then
			youLabel(Rigs.anchorPart(entry.rig), if youText then youText.Text else "")
			entry.youLabel = true
			entry.labelUntil = old.labelUntil
		end
		active[a.id] = entry
		local i = table.find(order, old)
		if i then
			order[i] = entry
		end
	end

	-- CloneHealth: every drawn avatar rig whole? A broken owner's clones become mannequins
	-- (reported once per owner and session). Returns "healthy/drawn" (tests, DebugChip).
	function view.checkHealth(): string
		local drawn, healthy = 0, 0
		local broken: { [number]: string } = {}
		for _, entry in order do
			if entry.fade >= 1 then
				continue
			end
			drawn += 1
			local fault = Rigs.health(entry.rig)
			if fault then
				broken[entry.actor.owner] = fault
			else
				healthy += 1
			end
		end
		for ownerId, fault in broken do
			if not brokenOwners[ownerId] then
				brokenOwners[ownerId] = fault
				Telemetry.ui("CloneBroken", fault)
				warn("[EchoView] clone rig of " .. tostring(ownerId) .. " broke (" .. fault .. "): mannequin")
			end
			for _, entry in table.clone(order) do
				if entry.actor.owner == ownerId and entry.rig.kind == "avatar" then
					swapEntry(entry, ownerId)
				end
			end
		end
		lastHealthy = healthy
		return string.format("%d/%d", healthy, drawn)
	end

	function view.clear()
		for _, entry in active do
			release(entry)
		end
		table.clear(active)
		table.clear(order)
		flushRetiring()
		-- Garage: only your own pool stays (crewmates' rigs come back with the next heist).
		prunePools({})
		run = nil
		newestOwnId = 0
		halo.hide()
	end

	-- Every clone drawn this run (the Crew Line-up takes over from them): actor, last
	-- feet position (world), yaw, hue, recording.
	function view.figures(): { any }
		local out = {}
		for _, entry in order do
			if entry.lastFeet then
				table.insert(out, {
					actor = entry.actor,
					feet = entry.lastFeet,
					hue = entry.hue,
					rec = entry.rec,
					gone = entry.fade >= 1,
				})
			end
		end
		return out
	end

	-- Every clone of this run in record order (the tape-print order) with its recording and hue,
	-- drawn or not yet: the rewind's path trails and the 8 OF ME roll call (Heist/MomentDirector).
	function view.paths(): { { actor: any, rec: any, hue: Color3 } }
		local out = {}
		for _, entry in order do
			table.insert(out, { actor = entry.actor, rec = entry.rec, hue = entry.hue })
		end
		return out
	end

	-- A roll-call beat for one clone at os.clock() time `at`: it hops once and its pill flashes white
	-- (Config.Moments.SWARM BEAT_*; no hop under reduced motion).
	function view.beat(actorId: number, at: number)
		local entry = active[actorId]
		if entry then
			entry.beatAt = at
			entry.beatLit = false
		end
	end

	-- The roll-call hop a clone shows this frame (studs; tests).
	function view.hopOf(actorId: number): number
		local entry = active[actorId]
		return if entry then entry.hop or 0 else 0
	end

	-- The owner group's Highlight (one per owner; the 8 OF ME outline flash), or nil.
	function view.highlightOf(ownerId: number): Highlight?
		local pool = pools[ownerId]
		return if pool then pool.highlight else nil
	end

	-- The local player's newest clone this run (actor id, 0 = none).
	function view.newestOwn(): number
		return newestOwnId
	end

	-- Clones visible right now (PerfSample "clones on screen").
	function view.visibleCount(): number
		local n = 0
		for _, entry in order do
			if entry.fade < 1 then
				n += 1
			end
		end
		return n
	end

	-- Hides every clone at once (the Line-up figures replace them) without a new run.
	function view.hideAll()
		for _, entry in order do
			entry.fade = 1
			hideRigs(entry)
			Rigs.locomote(entry.rig, "none", 0, 0, 1, 0, false, false)
			Rigs.setPose(entry.rig, nil)
			Rigs.lookAt(entry.rig, nil, 0)
			entry.pose.busy = false
			hideFx(entry)
		end
		table.clear(order)
	end

	-- Runtime performance tier (§6.3; budgets in Shared/Heist/Budget, docs/PERF.md): trails only at tier 1 (and
	-- your halo light at 1-2), the pill's draw distance, the floor-glow cap (your own clones first), smaller
	-- bursts; tier 4 drops the owner Highlights of other players' clones (yours keep theirs).
	function view.setTier(tier: number)
		tierNow = tier
		trailsOn = Budget.forTier(tier).trails
		halo.setTier(tier)
		for ownerId, pool in pools do
			pool.highlight.Enabled = highlightOn(ownerId)
		end
		local pillMax = Budget.pillDistance(tier)
		for _, pool in pools do
			for _, entry in pool.free do
				entry.badge.MaxDistance = pillMax
			end
		end
		for _, entry in active do
			entry.badge.MaxDistance = pillMax
		end
		-- Clone LOD from CLONE_LOD.TIER: every pooled avatar entry gets its light rig now (between frames, once),
		-- so the frame loop only swaps. Below it, the next update swaps every light rig back (Budget.cloneFar).
		if Budget.cloneLod(tier) then
			for _, pool in pools do
				for _, entry in pool.free do
					ensureLod(entry)
				end
			end
			for _, entry in active do
				ensureLod(entry)
			end
		end
		applyGlowBudget()
	end

	-- Clones drawn as the light rig right now (Clone LOD; tests, perf_engine).
	function view.lodCount(): number
		local n = 0
		for _, entry in order do
			if entry.far and entry.fade < 1 then
				n += 1
			end
		end
		return n
	end

	-- The avatar rigs on screen now (Heist/ScarfSway sways their scarf tails): appended to `out`, which is returned.
	function view.swayModels(out: { Model }): { Model }
		for _, entry in order do
			if entry.drawn == entry.rig and entry.rig.kind == "avatar" and entry.fade < 1 then
				table.insert(out, entry.rig.model)
			end
		end
		return out
	end

	-- The rig on screen for an actor: its avatar / mannequin rig, or the light rig while the LOD draws it far.
	function view.drawnRigOf(actorId: number): any
		local entry = active[actorId]
		return entry and entry.drawn
	end

	-- Floor glows drawn right now (tests, perf_engine).
	function view.glowCount(): number
		local n = 0
		for _, entry in order do
			if entry.glowGui.Enabled then
				n += 1
			end
		end
		return n
	end

	-- The rig drawing an actor (tests, diagnostics).
	function view.rigOf(actorId: number): any
		local entry = active[actorId]
		return entry and entry.rig
	end

	-- What a clone is doing this frame (CloneState: "moving", "on-plate", "carry", ...; tests).
	function view.stateOf(actorId: number): string?
		local entry = active[actorId]
		return if entry and entry.stateName then entry.frame.state else nil
	end

	-- When a clone's tape print started and finished (os.clock seconds; nil while not done).
	function view.printTimes(actorId: number): (number?, number?)
		local entry = active[actorId]
		if not entry then
			return nil, nil
		end
		return entry.visibleAt, entry.printDone
	end

	-- The fx a clone draws with (tests): its floor glow gui, its pill gui and its ribbon emitter.
	function view.fxOf(actorId: number): any
		local entry = active[actorId]
		if not entry then
			return nil
		end
		return { glow = entry.glowGui, glowPart = entry.glowPart, pill = entry.badge, ribbons = entry.ribbons }
	end

	-- Studio diagnostic chip: clones drawn, healthy at the last check, and what your own
	-- clones draw as ("avatar" | "mannequin" | "-" before your first clone).
	function view.stats(): (number, number, string)
		local own = pools[myId()]
		return view.visibleCount(), lastHealthy, if own then own.kind else "-"
	end

	-- Between runs: makes sure each crew member's pool has a rig for every clone the next
	-- run can show (this run's + 1), building at most one per frame, so an avatar template
	-- that arrived mid-heist never rebuilds a whole set inside setRun during the rewind.
	local warming = false
	function view.prewarm()
		if warming or not run then
			return
		end
		warming = true
		local need: { [number]: number } = {}
		for _, a in run.actors do
			if a.kind == "clone" or a.kind == "live" then
				need[a.owner] = (need[a.owner] or 0) + 1
			end
		end
		local cap = tonumber(run.cap) or 12
		task.spawn(function()
			for ownerId, n in need do
				local inUse = 0
				for _, entry in active do
					if entry.actor and entry.actor.owner == ownerId then
						inUse += 1
					end
				end
				local hue = Palette.CLONE_HUES[1]
				for _, m in state.crew or {} do
					if m.userId == ownerId then
						hue = Palette.hueFor(m.seat)
					end
				end
				local pool = poolFor(ownerId, hue)
				while #pool.free + inUse < math.min(n, cap) and state.phase == "Between" do
					local entry = newEntry(pool, ownerId)
					release(entry)
					task.wait()
				end
			end
			warming = false
		end)
	end

	return view
end

return EchoView
