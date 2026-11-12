--!strict
-- Heist/MomentDirector: the signature moments between the rewinds (PLAN_STEAM_PLUS §4.4 F1-F5, §4.2 C3,
-- §5; premium F3-F7, H1, H4; POLISH items 12-15; MASTERPLAN §6.6, §9.2). Client only and cosmetic:
-- every moment starts from a replicated sim event or from the recordings the client already holds,
-- and decides nothing (CLAUDE.md: the server is authoritative). Numbers in Config.Moments; the pure
-- maths in Shared/Heist/MomentPlan (tests/unit/HeistMoments.spec.luau).
--
--   8 OF ME / swarm (Swarm event, your seat): the world dims 15 % for 0.6 s; the roll call: each copy
--       takes one pose beat (a hop and a white pill flash, EchoView.beat) 60 ms apart in record order
--       while the clone arpeggio climbs (one CloneChime per beat), landing on the ChoirHit; the owner
--       outline flashes; the camera pulls back until every copy sits inside the central 32 % of the
--       width (CameraDirector.setMomentShot, eased in and out); under the "8 OF ME" stamp
--       (RewindDirector.stamp via the HUD) a row of numbered pills lights in the same order. In the G2
--       staging (EH_Scenario = G2) the golden shot stays under the pull-back.
--   Busted view (you caught, C3): a 66 ms freeze, the camera eases to Gus over 0.6 s (he plays his
--       catch beat, GusView.bang from HeistClient), the BUSTED stamp, then the cause's advice line: the
--       HUD hands both to catchView (Hud/Run -> Hud/Hints), which runs them at STAMP_AT.
--   Heist complete (HeistComplete event): a 66 ms freeze, every door slams shut (WorldView.slamDoors:
--       the L6 vault door or the shop door) with a FOV punch (behind the shake setting) and a dust
--       flash; gold rain (<= 60, one pooled emitter); the crown flies to the van on screen. Then
--       HeistClient's Over: the blooper cut, the Line-up, the job sheet.
--   Blooper cut (Over; MASTERPLAN §9.2 #2): if a clone of the final run was BUSTED, ZAPPED or got
--       STUCK, its last 3 s replay first (the whole run's view time goes back: clones, Gus, the world)
--       under "MY CLONE BETRAYED ME", skippable, <= 4 s; then the Line-up.
--   Hit-stop (premium F3): only the four heavy beats (rewind start, your catch, the diamond, heist
--       complete), HIT_STOP_SECONDS each: filter() holds the view time and the local character's
--       animation tracks pause (AdjustSpeed 0, restored). None under reduced motion.
--   Juice governor: MomentDirector.allowFlash (<= 3 full-screen flashes a second, RewindDirector too),
--       MomentDirector.particles (Heist/Particles: the one live particle budget every effect shares, the
--       tier's cap, 360 on touch at tiers 1-2), a low-tier substitute for every
--       effect from Config.Moments.LOW_TIER (fewer rain particles, no outline flash, a coarse rewind
--       path), camera shake only through the shake setting (HeistClient's fovKick wrapper).
-- Reduced motion: no hit-stop, no camera moves, no hops or flights; dims, stamps, pills and the replay stay.
-- On a server (tests/client_engine.luau) nothing connects to RenderStepped: call step(now, dt) by hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local CrewBoard = require(HeistShared:WaitForChild("CrewBoard"))
local MomentPlan = require(HeistShared:WaitForChild("MomentPlan"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))
local EventLog = require(Shared:WaitForChild("Sim"):WaitForChild("EventLog"))

local Icons = require(script.Parent:WaitForChild("Icons"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Particles = require(script.Parent:WaitForChild("Particles"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Theme = require(script.Parent:WaitForChild("Theme"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local EV = EventLog.EV
local M = Config.Moments
local SW, BU, CO, BL = M.SWARM, M.BUSTED, M.COMPLETE, M.BLOOPER

local MomentDirector = {}

---------------------------------------------------------------------------
-- The juice governor (module-wide: every director shares one flash limit and one particle budget)
---------------------------------------------------------------------------
local flashLog: { number } = {}

-- May a full-screen flash play now? (<= Config.Moments.FLASH_MAX per FLASH_WINDOW s; logs it if so.)
function MomentDirector.allowFlash(now: number?): boolean
	return MomentPlan.flashAllowed(flashLog, now or os.clock(), M.FLASH_MAX, M.FLASH_WINDOW)
end

-- Particles granted for a burst of `want` living `lifetime` s, under the one shared live budget (Heist/Particles:
-- the snow, the world's and the clones' bursts count against the same cap).
function MomentDirector.particles(want: number, lifetime: number, now: number?): number
	return Particles.grant(want, lifetime, now)
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function t3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

-- The camera yaw (degrees, CameraMath convention: 0 looks down -Z) of a look vector.
local function yawOf(look: Vector3): number
	return math.deg(math.atan2(-look.X, -look.Z))
end

-- Camera position for a focus, yaw, downward pitch and distance (CameraMath.orbit).
local function orbit(focus: Vector3, yawDeg: number, pitchDeg: number, distance: number): CFrame
	local f = MomentPlan.basis(yawDeg, pitchDeg)
	local pos = focus - v3(f) * distance
	return CFrame.lookAt(pos, focus)
end

export type Deps = {
	gui: ScreenGui, -- the edge-to-edge fx layer (Hud.fxGui)
	hud: any, -- setCutscene
	echo: any, -- EchoView: paths, positionOf, beat, highlightOf, effect
	gus: any?, -- GusView: poseOf
	world: any?, -- WorldView: slamDoors, partFor
	camera: any?, -- CameraDirector: setMomentShot, isSuspended
	stamp: ((text: string, color: Color3, hold: number) -> ())?, -- the HUD's big stamp
	fovKick: ((deg: number) -> ())?, -- the FOV owner (HeistClient: 0 when shake is off)
	myId: number?, -- the local player (tests on a server pass one)
	character: (() -> Model?)?, -- your character (tests pass a stand-in)
	aspect: (() -> number)?, -- the frame's width / height (default: the camera's viewport; tests pass one)
}

function MomentDirector.new(state: any, deps: Deps): any
	local moments = {}
	local echo = deps.echo
	local gui = deps.gui
	local tierNow = 1
	local function myId(): number
		if deps.myId then
			return deps.myId
		end
		local p = Players.LocalPlayer
		return if p then p.UserId else 0
	end
	local function character(): Model?
		if deps.character then
			return deps.character()
		end
		local p = Players.LocalPlayer
		return p and p.Character
	end
	local function rootPos(): Vector3?
		local char = character()
		local root = char and char:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root.Position else nil
	end
	local function reduced(): boolean
		return state.reduced == true
	end
	local function low(): boolean
		return tierNow >= M.LOW_TIER
	end
	local function aspect(): number
		if deps.aspect then
			return deps.aspect()
		end
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(16, 9)
		return math.max(vp.X, 1) / math.max(vp.Y, 1)
	end
	local function camYaw(): number
		local cam = workspace.CurrentCamera
		return if cam then yawOf(cam.CFrame.LookVector) else 0
	end

	---------------------------------------------------------------------------
	-- Hit-stop
	---------------------------------------------------------------------------
	local hitStopUntil = 0
	local heldT = 0
	local paused: { [AnimationTrack]: number } = {}

	local function releaseTracks()
		for track, speed in paused do
			pcall(track.AdjustSpeed, track, speed)
		end
		table.clear(paused)
	end

	-- A heavy beat (Config.Moments.HIT_STOP_BEATS only): the views hold for HIT_STOP_SECONDS.
	function moments.hitStop(beat: string, now: number?): boolean
		if not M.HIT_STOP_BEATS[beat] or reduced() then
			return false
		end
		local t = now or os.clock()
		hitStopUntil = math.max(hitStopUntil, t + M.HIT_STOP_SECONDS)
		local char = character()
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				if paused[track] == nil then
					paused[track] = track.Speed
					track:AdjustSpeed(0)
				end
			end
		end
		return true
	end

	function moments.frozen(now: number): boolean
		return now < hitStopUntil
	end

	---------------------------------------------------------------------------
	-- Shared UI: the dim, the pill row, the caption, the trophy, the flash card
	---------------------------------------------------------------------------
	local dim: ColorCorrectionEffect? = nil
	local function dimEffect(): ColorCorrectionEffect?
		local cam = workspace.CurrentCamera
		if not cam then
			return nil
		end
		local d = dim
		if not d then
			local made = Instance.new("ColorCorrectionEffect")
			made.Name = "EH_MomentDim"
			made.Enabled = false
			d = made
			dim = made
		end
		local effect = d :: ColorCorrectionEffect
		if effect.Parent ~= cam then
			effect.Parent = cam
		end
		return effect
	end

	local pillRow = Ui.frame(gui, {
		Name = "RollCall",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, SW.PILL_ROW_Y),
		Size = UDim2.fromOffset(SW.PILLS_MAX * (SW.PILL + SW.PILL_GAP), SW.PILL + 8),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 55,
	})
	local pillLayout = Instance.new("UIListLayout")
	pillLayout.FillDirection = Enum.FillDirection.Horizontal
	pillLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pillLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pillLayout.Padding = UDim.new(0, SW.PILL_GAP)
	pillLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pillLayout.Parent = pillRow
	local pills: { { frame: Frame, label: TextLabel, hue: Color3, lit: boolean } } = {}
	for i = 1, SW.PILLS_MAX do
		local f = Ui.frame(pillRow, {
			Name = "Pill" .. i,
			Size = UDim2.fromOffset(SW.PILL, SW.PILL),
			BackgroundColor3 = Palette.ink,
			BackgroundTransparency = 0,
			LayoutOrder = i,
			Visible = false,
			ZIndex = 55,
		})
		Ui.pill(f)
		Ui.stroke(f, Palette.ink, Theme.STROKE)
		local label = Ui.label(f, {
			Name = "Number",
			Size = UDim2.fromScale(1, 1),
			Text = tostring(i),
			TextColor3 = Palette.white,
			TextSize = Theme.TYPE.body,
			FontFace = Theme.FONT_DISPLAY,
			ZIndex = 56,
		})
		pills[i] = { frame = f, label = label, hue = Palette.white, lit = false }
	end

	local flashCard = Ui.frame(gui, {
		Name = "MomentFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 49,
	})
	local function flash(alpha: number, seconds: number)
		if reduced() or not MomentDirector.allowFlash() then
			return
		end
		flashCard.Visible = true
		flashCard.BackgroundTransparency = alpha
		Motion.timed(flashCard, seconds, { BackgroundTransparency = 1 })
	end

	local caption = Ui.display(gui, {
		Name = "BlooperCaption",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 28),
		Size = UDim2.new(0.9, 0, 0, BL.CAPTION_SIZE + 12),
		TextSize = BL.CAPTION_SIZE,
		TextScaled = true,
		TextColor3 = Palette.gold,
		Text = Strings.BLOOPER_CAPTION,
		Visible = false,
		ZIndex = 57,
	})
	local captionMax = Instance.new("UITextSizeConstraint")
	captionMax.MaxTextSize = BL.CAPTION_SIZE
	captionMax.Parent = caption
	local skipChip = Ui.button(gui, {
		Name = "BlooperSkip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(120, Ui.TAP),
		Text = Strings.SKIP,
		Visible = false,
		ZIndex = 57,
	}, function() end)

	---------------------------------------------------------------------------
	-- The camera take-over (one moment shot at a time; eased in and out)
	---------------------------------------------------------------------------
	local shotOwner: string? = nil
	local function takeCamera(owner: string, fn: () -> (CFrame?, number?, number)): boolean
		local cam = deps.camera
		if not cam or reduced() or cam.isSuspended() then
			return false
		end
		shotOwner = owner
		cam.setMomentShot(fn)
		return true
	end
	local function releaseCamera(owner: string)
		local cam = deps.camera
		if cam and shotOwner == owner then
			shotOwner = nil
			cam.setMomentShot(nil)
		end
	end

	---------------------------------------------------------------------------
	-- 8 OF ME / the swarm moment
	---------------------------------------------------------------------------
	local swarm: any = nil -- { t0, beats = { { id?, at, pill } }, choir, dimOn, pillsOn, stampUntil, ... }

	-- The roll call's members in record order: own clones (or the crew's in a co-op swarm), then the
	-- live player(s). Each: actor id (nil for a live player) and hue.
	local function members(crew: boolean): { { id: number?, hue: Color3, owner: number } }
		local out = {}
		local me = myId()
		for _, p in echo.paths() do
			local a = p.actor
			if a and (crew or a.owner == me) then
				table.insert(out, { id = a.id, hue = Palette.hueFor(a.seat or 1), owner = a.owner })
			end
		end
		if crew then
			for _, m in state.crew or {} do
				table.insert(out, { id = nil, hue = Palette.hueFor(m.seat or 1), owner = m.userId })
			end
		else
			table.insert(out, { id = nil, hue = Palette.hueFor(state.mySeat or 1), owner = me })
		end
		return out
	end

	-- The swarm's shot: every copy (head and feet) inside the central 32 % of the width.
	local function swarmPoints(s: any): { { number } }
		local pts = {}
		local function add(p: Vector3)
			table.insert(pts, t3(p + Vector3.new(0, SW.FIGURE_UP, 0)))
			table.insert(pts, t3(p - Vector3.new(0, SW.FIGURE_DOWN, 0)))
		end
		for _, m in s.members do
			if m.id then
				local p = echo.positionOf(m.id)
				if p then
					add(p)
				end
			elseif m.owner == myId() then
				local p = rootPos()
				if p then
					add(p)
				end
			end
		end
		return pts
	end

	-- The swarm shot this frame (tests read it too): CFrame, FOV, weight, and whether it fits.
	local function swarmShot(s: any, now: number): (CFrame?, number?, number, boolean)
		local e = now - s.t0
		local w, done = MomentPlan.blend(e, SW.CAM_IN, SW.CAM_HOLD + s.span, SW.CAM_OUT)
		if done then
			return nil, nil, 0, true
		end
		local pts = swarmPoints(s)
		if #pts < 4 then
			return nil, nil, 0, false
		end
		local focus, dist, fits = MomentPlan.frame(
			pts,
			s.yaw,
			SW.CAM_PITCH,
			SW.CAM_FOV,
			aspect(),
			Config.Heist.CAMERA.LINEUP.CENTRAL_SHARE,
			SW.CAM_SHARE_Y,
			SW.CAM_DISTANCE[1],
			SW.CAM_DISTANCE[2]
		)
		-- Exact every frame (the copies move smoothly, so the fit does too): the frame's own focus and
		-- distance, so nobody ever leaves the central 32 %. The weight eases it in and out of play.
		s.focus, s.dist, s.fits = v3(focus), dist, fits
		return orbit(s.focus, s.yaw, SW.CAM_PITCH, dist), SW.CAM_FOV, w, fits
	end

	local function endSwarm()
		local s = swarm
		if not s then
			return
		end
		swarm = nil
		releaseCamera("swarm")
		local d = dim
		if d then
			d.Enabled = false
		end
		pillRow.Visible = false
		local hl = s.highlight
		if hl and s.fill then
			hl.FillTransparency = s.fill
			hl.OutlineTransparency = s.outline
		end
	end

	-- The swarm moment for the Swarm event (a = seat, b = your copies, c = the crew's).
	function moments.swarm(e: any, now: number?)
		local t0 = now or os.clock()
		endSwarm()
		local need = Config.Sim.SWARM_OF_ME
		local crew = e.b < need and e.c >= need and #(state.crew or {}) > 1
		local list = members(crew)
		if #list < 2 then
			return
		end
		local times = MomentPlan.rollCall(#list, SW.ROLL_STAGGER, SW.ROLL_START)
		local span = times[#times] - times[1]
		local s: any = {
			t0 = t0,
			members = list,
			times = times,
			span = span,
			choir = MomentPlan.choirAt(#list, SW.ROLL_STAGGER, SW.ROLL_START, SW.CHOIR_GAP),
			yaw = camYaw(),
			stampWorthy = e.b >= need or crew,
			pillsUntil = t0 + math.max(Config.Heist.SWARM_STAMP_SECONDS, span + SW.ROLL_START + SW.BEAT_SECONDS),
		}
		swarm = s
		-- the roll call: clone beats + notes; the choir hit after the last
		for i, m in list do
			if m.id then
				echo.beat(m.id, t0 + times[i])
			end
			Sound.play("CloneChime", { step = (i - 1) % #Config.Audio.ARPEGGIO_STEPS, delay = times[i] })
		end
		Sound.play("ChoirHit", { delay = s.choir })
		-- the outline flash (owner group; the per-clone flash is each pill)
		if not low() then
			local hl = echo.highlightOf(myId())
			if hl then
				s.highlight, s.fill, s.outline = hl, hl.FillTransparency, hl.OutlineTransparency
			end
		end
		-- the stamp's numbered pills
		if s.stampWorthy then
			for i, p in pills do
				local m = list[i]
				p.frame.Visible = m ~= nil
				p.lit = false
				if m then
					p.hue = m.hue
					p.frame.BackgroundColor3 = Palette.ink
					p.label.Text = tostring(i)
				end
			end
			pillRow.Visible = true
		end
		takeCamera("swarm", function(): (CFrame?, number?, number)
			local cur = swarm
			if not cur then
				return nil, nil, 0
			end
			local cf, fov, w = swarmShot(cur, os.clock())
			return cf, fov, w
		end)
	end

	local function stepSwarm(now: number)
		local s = swarm
		if not s then
			return
		end
		local e = now - s.t0
		-- the dim: 15 % in DIM_IN, back by DIM_SECONDS
		local d = dimEffect()
		if d then
			local a = if e < SW.DIM_IN
				then e / SW.DIM_IN
				elseif e < SW.DIM_SECONDS then 1 - (e - SW.DIM_IN) / (SW.DIM_SECONDS - SW.DIM_IN)
				else 0
			d.Enabled = a > 0
			local g = 1 - SW.DIM * math.clamp(a, 0, 1)
			d.TintColor = Color3.new(g, g, g)
		end
		-- pills light in record order
		if pillRow.Visible then
			for i, p in pills do
				local at = s.times[i]
				if at and not p.lit and e >= at then
					p.lit = true
					p.frame.BackgroundColor3 = p.hue
					Ui.pop(p.frame)
				end
			end
			if now >= s.pillsUntil then
				pillRow.Visible = false
			end
		end
		-- the owner outline flashes over the roll call
		local hl = s.highlight
		if hl and s.fill then
			local first, last = s.times[1], s.times[#s.times] + SW.BEAT_SECONDS
			local on = e >= first and e < last
			hl.FillTransparency = if on then SW.OUTLINE_FILL else s.fill
			hl.OutlineTransparency = if on then 0 else s.outline
		end
		local _, over = MomentPlan.blend(e, SW.CAM_IN, SW.CAM_HOLD + s.span, SW.CAM_OUT)
		if over and now >= s.pillsUntil then
			endSwarm()
		end
	end

	-- Tests: the running swarm moment's plan and its shot this frame.
	function moments.swarmPlan(): any
		return swarm
	end
	function moments.swarmShot(now: number): (CFrame?, number?, number, boolean)
		local s = swarm
		if not s then
			return nil, nil, 0, false
		end
		return swarmShot(s, now)
	end

	---------------------------------------------------------------------------
	-- The busted view (you caught)
	---------------------------------------------------------------------------
	local busted: any = nil -- { t0, gus = Vector3, yaw, stampAt, pending = { fn } }

	local function gusAt(index: number): Vector3?
		local g = deps.gus
		if not g then
			return nil
		end
		local x, z = g.poseOf(index)
		local floorY = if state.level then state.level.floorY or 0 else 0
		local origin: Vector3 = state.origin or Vector3.zero
		return origin + Vector3.new(x, floorY + BU.FOCUS_HEIGHT, z)
	end

	function moments.busted(gusIndex: number, now: number?)
		local t0 = now or os.clock()
		moments.hitStop("busted", t0)
		local at = gusAt(gusIndex)
		busted = { t0 = t0, gus = at, yaw = camYaw(), stampAt = t0 + BU.STAMP_AT, pending = {} }
		if at then
			takeCamera("busted", function(): (CFrame?, number?, number)
				local b = busted
				if not b then
					return nil, nil, 0
				end
				local w, done = MomentPlan.blend(os.clock() - b.t0, BU.CAM_IN, BU.HOLD, BU.CAM_OUT)
				if done then
					return nil, nil, 0
				end
				return orbit(b.gus, b.yaw, BU.PITCH, BU.DISTANCE), BU.FOV, w
			end)
		end
	end

	-- The HUD's catch reaction (the BUSTED stamp, then the advice line): at STAMP_AT into the busted
	-- view, or now when there is none.
	function moments.catchView(fn: () -> ())
		local b = busted
		if b and os.clock() < b.stampAt then
			table.insert(b.pending, fn)
		else
			fn()
		end
	end

	local function stepBusted(now: number)
		local b = busted
		if not b then
			return
		end
		if now >= b.stampAt and #b.pending > 0 then
			local list = b.pending
			b.pending = {}
			for _, fn in list do
				local ok, err = pcall(fn)
				if not ok then
					warn("[MomentDirector] catch view: " .. tostring(err))
				end
			end
		end
		local _, done = MomentPlan.blend(now - b.t0, BU.CAM_IN, BU.HOLD, BU.CAM_OUT)
		if done and #b.pending == 0 then
			busted = nil
			releaseCamera("busted")
		end
	end

	---------------------------------------------------------------------------
	-- Heist complete: slam, gold rain, the trophy
	---------------------------------------------------------------------------
	local rainPart: BasePart? = nil
	local rainEmitter: ParticleEmitter? = nil
	local rain: any = nil -- { t0, bursts = { n }, next }
	local slamKick: any = nil -- { t0 }
	local trophy: ImageLabel? = nil

	local function rainHost(): (BasePart, ParticleEmitter)
		local p = rainPart
		local em = rainEmitter
		if p and em and p.Parent then
			return p, em
		end
		local part = Instance.new("Part")
		part.Name = "EH_GoldRain"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(CO.RAIN_SPREAD * 2, 0.2, CO.RAIN_SPREAD * 2)
		part.Parent = workspace
		local e = Instance.new("ParticleEmitter")
		e.Name = "Gold"
		e.Enabled = false
		e.Rate = 0
		e.Texture = CO.RAIN_TEXTURE
		e.Color = ColorSequence.new(Palette.gold)
		e.LightEmission = 0.6
		e.LightInfluence = 0
		e.Size = NumberSequence.new(0.6, 0.3)
		e.Lifetime = NumberRange.new(CO.RAIN_LIFETIME[1], CO.RAIN_LIFETIME[2])
		e.Speed = NumberRange.new(2, 4)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Acceleration = Vector3.new(0, -8, 0)
		e.RotSpeed = NumberRange.new(-120, 120)
		e.Rotation = NumberRange.new(0, 360)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.Parent = part
		rainPart, rainEmitter = part, e
		return part, e
	end

	local function vanScreen(): Vector2?
		local w = deps.world
		local cam = workspace.CurrentCamera
		local van = w and w.partFor("van", 1)
		if not cam or not van then
			return nil
		end
		local pos = if van:IsA("BasePart")
			then van.Position
			elseif van:IsA("Model") then van:GetPivot().Position
			else nil
		if not pos then
			return nil
		end
		local sp, on = cam:WorldToViewportPoint(pos)
		if not on then
			return nil
		end
		return Vector2.new(sp.X, sp.Y)
	end

	local function flyTrophy()
		local old = trophy
		if old then
			old:Destroy()
			trophy = nil
		end
		local icon = Icons.make(gui, "crown", {
			Name = "MomentTrophy",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, SW.PILL_ROW_Y),
			Size = UDim2.fromOffset(CO.TROPHY_SIZE, CO.TROPHY_SIZE),
			ImageColor3 = Palette.gold,
			ZIndex = 56,
		})
		if not icon then
			return
		end
		trophy = icon
		local size = gui.AbsoluteSize
		local ax, ay = size.X * 0.5, size.Y * SW.PILL_ROW_Y
		local target = vanScreen() or Vector2.new(size.X * 0.5, size.Y * 0.85)
		if reduced() then
			icon.Position = UDim2.fromOffset(target.X, target.Y)
			icon.Size = UDim2.fromOffset(CO.TROPHY_SIZE * CO.TROPHY_END, CO.TROPHY_SIZE * CO.TROPHY_END)
			task.delay(CO.TROPHY_SECONDS, function()
				icon:Destroy()
			end)
			return
		end
		local u = Instance.new("NumberValue")
		u.Value = 0
		u.Changed:Connect(function(v: number)
			local x, y = CrewBoard.arc(ax, ay, target.X, target.Y, CO.TROPHY_ARC, v)
			icon.Position = UDim2.fromOffset(x, y)
			local sz = CO.TROPHY_SIZE * (1 - (1 - CO.TROPHY_END) * v)
			icon.Size = UDim2.fromOffset(sz, sz)
		end)
		local tw = Motion.timed(u, CO.TROPHY_SECONDS, { Value = 1 }, "exit")
		tw.Completed:Once(function()
			icon:Destroy()
			u:Destroy()
			if trophy == icon then
				trophy = nil
			end
			Sound.play("CountDone")
		end)
	end

	function moments.complete(now: number?)
		local t0 = now or os.clock()
		moments.hitStop("complete", t0)
		local w = deps.world
		local door: BasePart? = nil
		if w and w.slamDoors then
			door = w.slamDoors()
		end
		Sound.play("VaultSlam", if door then { at = door } else nil)
		flash(CO.SLAM_FLASH, CO.SLAM_SECONDS)
		if deps.fovKick and not reduced() then
			slamKick = { t0 = t0 }
		end
		-- gold rain over the camera's focus, pooled, under the particle cap
		local cam = workspace.CurrentCamera
		if cam then
			local part = rainHost()
			part.Position = cam.Focus.Position + Vector3.new(0, CO.RAIN_HEIGHT, 0)
			local total = MomentPlan.rainCount(CO.RAIN, CO.RAIN_LOW, tierNow, M.LOW_TIER, state.particleScale or 1)
			rain = { t0 = t0, bursts = MomentPlan.split(total, CO.RAIN_BURSTS), next = 1 }
		end
		task.delay(CO.TROPHY_DELAY, function()
			if state.where == nil or state.where == "heist" then
				flyTrophy()
			end
		end)
	end

	local function stepComplete(now: number)
		local r = rain
		local em = rainEmitter
		if r and em then
			local every = CO.RAIN_SECONDS / math.max(#r.bursts, 1)
			while r.next <= #r.bursts and now - r.t0 >= (r.next - 1) * every do
				local n = MomentDirector.particles(r.bursts[r.next], CO.RAIN_LIFETIME[2], now)
				if n > 0 then
					em:Emit(n)
				end
				r.next += 1
			end
			if r.next > #r.bursts then
				rain = nil
			end
		end
		local k = slamKick
		if k and deps.fovKick then
			local e = now - k.t0
			if e >= CO.SLAM_SECONDS then
				deps.fovKick(0)
				slamKick = nil
			else
				deps.fovKick(CO.SLAM_FOV * (1 - MomentPlan.ease(e / CO.SLAM_SECONDS)))
			end
		end
	end

	---------------------------------------------------------------------------
	-- The run's clone failures (the blooper log) and the blooper cut
	---------------------------------------------------------------------------
	local fails: { MomentPlan.Failure } = {}
	local replay: any = nil -- { fail, from, to, t, saved, refire = { failure }, conn, next }

	local function note(id: number, kind: string, tick: number)
		local run = state.run
		local a = run and run.actorById and run.actorById[id]
		if not a or a.kind ~= "clone" then
			return
		end
		for _, f in fails do
			if f.id == id and f.kind == kind then
				return
			end
		end
		table.insert(fails, { id = id, owner = a.owner, kind = kind, t = math.max(0, (tick - 1) / Config.Rec.HZ) })
	end

	-- The run's failures so far (tests).
	function moments.failures(): { MomentPlan.Failure }
		return fails
	end

	-- The fx entry the view expects for a failure (HeistClient.applyEvent's shape).
	local function applyFail(fx: { [number]: any }, f: MomentPlan.Failure, atLocal: number)
		local entry = fx[f.id] or {}
		fx[f.id] = entry
		if f.kind == "Stuck" then
			entry.stuckT = f.t
		else
			entry.gone = f.kind
			entry.goneAtLocal = atLocal
		end
	end

	local function endReplay(skipped: boolean)
		local r = replay
		if not r then
			return
		end
		replay = nil
		state.replayT = nil
		state.actorFx = r.saved
		caption.Visible = false
		skipChip.Visible = false
		if r.input then
			r.input:Disconnect()
		end
		if r.skip then
			r.skip:Disconnect()
		end
		if deps.hud and deps.hud.setCutscene then
			deps.hud.setCutscene(false)
		end
		local nextFn = r.nextFn
		local ok, err = pcall(nextFn)
		if not ok then
			warn("[MomentDirector] after the blooper: " .. tostring(err))
		end
		releaseCamera("blooper") -- after the Line-up took the camera (no snap back to play)
		if skipped then
			Sound.play("UIClick")
		end
	end

	-- At heist end: the final run's best clone failure replays first, then `nextFn` (the Line-up).
	-- Returns true when a blooper plays.
	function moments.blooper(_over: any, nextFn: () -> (), now: number?): boolean
		local pick = MomentPlan.pickBlooper(fails, myId(), BL.WEIGHTS)
		if not pick or not state.run or replay then
			nextFn()
			return false
		end
		local from, to = MomentPlan.blooperWindow(pick.t, BL.LEAD, BL.TAIL, BL.MAX)
		local t0 = (now or os.clock()) + BL.START_DELAY
		local r: any = { fail = pick, from = from, to = to, t0 = t0, started = false, nextFn = nextFn, refire = {} }
		replay = r
		return true
	end

	local function startReplay(r: any, now: number)
		r.started = true
		r.saved = state.actorFx
		local fx: { [number]: any } = {}
		for _, f in fails do
			if f.t <= r.from then
				applyFail(fx, f, -math.huge) -- gone before the window: stays gone
			else
				table.insert(r.refire, f)
			end
		end
		table.sort(r.refire, function(a: any, b: any): boolean
			return a.t < b.t
		end)
		state.actorFx = fx
		state.replayT = r.from
		caption.Visible = true
		Ui.pop(caption)
		skipChip.Visible = true
		if deps.hud and deps.hud.setCutscene then
			deps.hud.setCutscene(true)
		end
		local skipFrom = now + BL.SKIP_AFTER
		r.skip = skipChip.Activated:Connect(function()
			if replay == r and os.clock() >= skipFrom then
				endReplay(true)
			end
		end)
		r.input = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or replay ~= r or os.clock() < skipFrom then
				return
			end
			local t = input.UserInputType
			if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
				endReplay(true)
			end
		end)
		local id = r.fail.id
		r.yaw = camYaw()
		r.camT0 = now
		takeCamera("blooper", function(): (CFrame?, number?, number)
			local cur = replay
			if cur ~= r then
				return nil, nil, 0
			end
			local p = echo.positionOf(id)
			if not p then
				return nil, nil, 0
			end
			local tNow = os.clock()
			local f = cur.focus
			local dt = math.max(tNow - (cur.lastCam or tNow), 0)
			cur.lastCam = tNow
			cur.focus = if f then f:Lerp(p, 1 - math.exp(-BL.CAM_FOLLOW * dt)) else p
			local w = MomentPlan.ease((tNow - cur.camT0) / SW.CAM_IN)
			return orbit(cur.focus, cur.yaw, BL.CAM_PITCH, BL.CAM_DISTANCE), BL.CAM_FOV, w
		end)
	end

	local function stepReplay(now: number, dt: number)
		local r = replay
		if not r then
			return
		end
		if not r.started then
			if now >= r.t0 then
				startReplay(r, now)
			end
			return
		end
		local t = math.min(r.to, (state.replayT or r.from) + dt)
		state.replayT = t
		while #r.refire > 0 and r.refire[1].t <= t do
			local f = table.remove(r.refire, 1) :: MomentPlan.Failure
			applyFail(state.actorFx, f, now)
			echo.effect(f.id, f.kind, now)
		end
		if t >= r.to then
			endReplay(false)
		end
	end

	-- Tests and HeistClient: the blooper in progress (or queued).
	function moments.replaying(): boolean
		return replay ~= nil
	end

	---------------------------------------------------------------------------
	-- Wiring: runs, events, the per-frame filter and step
	---------------------------------------------------------------------------

	-- A new run (HeistClient.applyRun): the failure log starts over; a live rewind opens with the
	-- heavy beat's freeze.
	function moments.onRun(msg: any, live: boolean)
		table.clear(fails)
		endSwarm()
		if live and (msg.kind or "Standard") ~= "Intro" then
			moments.hitStop("rewind")
		end
	end

	-- Every applied event (HeistClient.applyEvent; live = happening now, not a Sync catch-up).
	function moments.onEvent(e: any, live: boolean)
		local kind = e.kind
		if kind == EV.Busted then
			note(e.b, "Busted", e.tick)
		elseif kind == EV.Zap then
			note(e.a, "Zapped", e.tick)
		elseif kind == EV.Stuck then
			note(e.a, "Stuck", e.tick)
		end
		if not live then
			return
		end
		local run = state.run
		local byId = run and run.actorById
		if kind == EV.Swarm and e.a == (state.mySeat or 1) then
			moments.swarm(e)
		elseif kind == EV.Caught then
			local target = byId and byId[e.b]
			if target and target.kind == "live" and target.owner == myId() then
				moments.busted(e.a)
			end
		elseif kind == EV.Grab then
			local actor = byId and byId[e.a]
			local def = state.level and state.level.loot and state.level.loot[e.b]
			if def and def.kind == "Diamond" and actor and actor.kind == "live" and actor.owner == myId() then
				moments.hitStop("diamond")
			end
		elseif kind == EV.HeistComplete then
			moments.complete()
		end
	end

	-- The view time and frame step the views draw with this frame: held through a hit-stop, and the
	-- blooper's replay time while it plays.
	function moments.filter(tView: number, now: number, dt: number): (number, number)
		if replay and replay.started and state.replayT then
			return state.replayT, dt
		end
		if now < hitStopUntil then
			return heldT, 0
		end
		heldT = tView
		return tView, dt
	end

	function moments.step(now: number, dt: number)
		if next(paused) ~= nil and now >= hitStopUntil then
			releaseTracks()
		end
		stepSwarm(now)
		stepBusted(now)
		stepComplete(now)
		stepReplay(now, dt)
	end

	function moments.setTier(tier: number)
		tierNow = tier
	end

	-- Back to the garage (or a fresh heist): everything stops and restores.
	function moments.stop()
		endSwarm()
		if busted then
			busted = nil
			releaseCamera("busted")
		end
		local r = replay
		if r then
			replay = nil
			state.replayT = nil
			if r.saved then
				state.actorFx = r.saved
			end
			if r.input then
				r.input:Disconnect()
			end
			if r.skip then
				r.skip:Disconnect()
			end
			caption.Visible = false
			skipChip.Visible = false
			releaseCamera("blooper")
		end
		rain = nil
		if slamKick and deps.fovKick then
			deps.fovKick(0)
		end
		slamKick = nil
		hitStopUntil = 0
		releaseTracks()
		table.clear(fails)
		local t = trophy
		if t then
			t:Destroy()
			trophy = nil
		end
	end

	if RunService:IsClient() then
		RunService.RenderStepped:Connect(function(dt: number)
			debug.profilebegin("EH.Moments")
			moments.step(os.clock(), dt)
			debug.profileend()
		end)
	end

	return moments
end

return MomentDirector
