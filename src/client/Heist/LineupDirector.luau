--!strict
-- Heist/LineupDirector: the Crew Line-up and the end-of-heist cut (MASTERPLAN §3.2 rule
-- 8, §6.6, §9.2 format 5 "8 OF ME"; docs/marketing/CLIPS.md §1.2-1.3). Scripted, never
-- simulated, so it can never desync: the server sends HeistSim.lineup's spots with the
-- Over message; every client plays the same cut from them.
--
--   0.0 s   the camera eases from play to a low street shot of the row (a cut under
--           reduced motion); HUD, CoreGui, nameplates and the real characters hide;
--           the run's clones are replaced by Line-up figures where they stood
--   0.8 s   figures walk to their spots in record order, LINEUP_STAGGER apart; the
--           burned caption "RUN 6 · 8 OF ME · $1,000" pops in; "ME, 20 SEC AGO" sits
--           on your newest clone for 1.5 s (always the true number, CLIPS §1.2)
--   arrive  each figure turns to the camera; after the last arrival they pose (cheer
--           clip on avatars, arms up on mannequins, one hop) rippling 60 ms apart
--   +2.4 s  done: the results card shows over the held shot. A SKIP chip skips from 1 s;
--           a tap anywhere (or a key) skips once the crew has posed (the first cut of a
--           session; later cuts from 1 s), so a kid still mashing GRAB keeps the payoff.
-- Cost on low-end phones: figure rigs are built a few per frame during the start delay
-- (the run's clones stay up until every figure exists, then swap in one frame); the
-- crew's character part lists are collected once; after the cut only the camera holds.
-- Framing: the row centred, low camera (2.4 studs) looking up, the row fitted in
-- LINEUP_CAM_FIT_WIDTH of the frame; a wall between the row and the camera pulls the
-- camera in and widens the lens. A row spot inside the van body moves to clear it (the
-- default row is LINEUP_STREET_GAP behind the van zone, where the parked van stands).
-- Every exit restores camera, HUD, CoreGui, controls and characters (vault "Cameras
-- and Cutscenes": restore on every path, with a watchdog).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local Strings = require(Shared:WaitForChild("Heist"):WaitForChild("Strings"))

local LineupPlan = require(script.Parent:WaitForChild("LineupPlan"))
local Motion = require(script.Parent:WaitForChild("Motion"))
local Rigs = require(script.Parent:WaitForChild("Rigs"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local H = Config.Heist
local FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Heavy)

local LineupDirector = {}

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeInOut(x: number): number
	x = math.clamp(x, 0, 1)
	return if x < 0.5 then 16 * x ^ 5 else 1 - (-2 * x + 2) ^ 5 / 2
end

-- The facing (look) vector of a yaw, as CFrame.Angles(0, yaw, 0).LookVector.
local function look(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function yawOf(dir: Vector3): number
	return math.atan2(-dir.X, -dir.Z)
end

local function lerpAngle(a: number, b: number, u: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * u
end

local BUILD_PER_FRAME = 2 -- Line-up figure rigs built per frame (spreads the clone/LoadAnimation hitch)

local function templateOf(ownerId: number): Model?
	local f = ReplicatedStorage:FindFirstChild(Protocol.AVATARS)
	local t = f and f:FindFirstChild(tostring(ownerId))
	return if t and t:IsA("Model") then t else nil
end

function LineupDirector.new(state: any, fxGui: ScreenGui, echo: any, world: any, hud: any): any
	local director = {}
	local folder: Folder? = nil
	local figures: { any } = {}
	local groups: { [number]: Model } = {}
	local playing = false
	local finished = false
	local t0 = 0
	local tPose = math.huge
	local tEnd = math.huge
	local skippable = 0
	local onDone: (() -> ())? = nil
	local renderName = "EH_Lineup"
	local saved: any = nil
	local shot: any = nil
	local inputConn: RBXScriptConnection? = nil
	local skipConn: RBXScriptConnection? = nil
	local labelGui: BillboardGui? = nil
	local labelText: TextLabel? = nil
	local labelScale: UIScale? = nil
	local cutsSeen = 0 -- Line-ups played this session (the first one skips only after the pose)
	local hiddenParts: { Instance } = {} -- the crew's character parts and decals, collected once
	local hiddenConns: { RBXScriptConnection } = {}
	local tierNow = 1

	-- Burned caption (top band, 12-28 % of the height: CLIPS §1.3)
	local caption = Instance.new("TextLabel")
	caption.Name = "LineupCaption"
	caption.BackgroundTransparency = 1
	caption.AnchorPoint = Vector2.new(0.5, 0.5)
	caption.Position = UDim2.fromScale(0.5, 0.2)
	caption.Size = UDim2.fromScale(0.9, 0.09)
	caption.FontFace = FONT
	caption.TextScaled = true
	caption.TextColor3 = Palette.exit
	Ui.textStroke(caption)
	caption.RichText = true
	caption.Text = ""
	caption.Visible = false
	caption.ZIndex = 40
	caption.Parent = fxGui
	local captionMax = Instance.new("UITextSizeConstraint")
	captionMax.MaxTextSize = 64
	captionMax.Parent = caption
	local captionScale = Instance.new("UIScale")
	captionScale.Parent = caption

	-- SKIP: a deliberate skip (a tap anywhere skips only once the crew has posed).
	local skipChip = Instance.new("TextButton")
	skipChip.Name = "LineupSkip"
	skipChip.AnchorPoint = Vector2.new(1, 1)
	skipChip.Position = UDim2.new(1, -24, 1, -24)
	skipChip.Size = UDim2.fromOffset(132, 64)
	skipChip.BackgroundColor3 = Palette.ink
	skipChip.BackgroundTransparency = 0.25
	skipChip.FontFace = FONT
	skipChip.TextSize = 24
	skipChip.TextColor3 = Palette.white
	skipChip.Text = Strings.SKIP
	skipChip.Visible = false
	skipChip.ZIndex = 41
	skipChip.Parent = fxGui
	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 14)
	skipCorner.Parent = skipChip

	local function controls(on: boolean)
		local lp = Players.LocalPlayer
		local ps = lp and lp:FindFirstChildOfClass("PlayerScripts")
		local pm = ps and ps:FindFirstChild("PlayerModule")
		if not pm or not pm:IsA("ModuleScript") then
			return
		end
		pcall(function()
			local c = (require(pm) :: any):GetControls()
			if on then
				c:Enable()
			else
				c:Disable()
			end
		end)
	end

	local function hideable(d: Instance): boolean
		return d:IsA("BasePart") or d:IsA("Decal")
	end

	-- The crew's character parts, collected once per cut (plus any added later, such as an
	-- accessory that finishes loading); re-applied each frame because the camera scripts
	-- may reset LocalTransparencyModifier.
	local function collectCharacters()
		table.clear(hiddenParts)
		for _, c in hiddenConns do
			c:Disconnect()
		end
		table.clear(hiddenConns)
		for _, m in state.crew or {} do
			local p = Players:GetPlayerByUserId(m.userId)
			local char = p and p.Character
			if char then
				for _, d in char:GetDescendants() do
					if hideable(d) then
						table.insert(hiddenParts, d)
					end
				end
				table.insert(
					hiddenConns,
					char.DescendantAdded:Connect(function(d: Instance)
						if hideable(d) then
							table.insert(hiddenParts, d)
						end
					end)
				)
			end
		end
	end

	local function setCharactersHidden(hidden: boolean)
		local alpha = if hidden then 1 else 0
		for _, d in hiddenParts do
			(d :: any).LocalTransparencyModifier = alpha
		end
	end

	local function restore()
		local s = saved
		saved = nil
		pcall(function()
			RunService:UnbindFromRenderStep(renderName)
		end)
		if inputConn then
			inputConn:Disconnect()
			inputConn = nil
		end
		if not s then
			return
		end
		local cam = workspace.CurrentCamera
		if cam then
			cam.FieldOfView = s.fov
			cam.CameraType = Enum.CameraType.Custom
			local lp = Players.LocalPlayer
			local hum = lp and lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
		setCharactersHidden(false)
		for _, c in hiddenConns do
			c:Disconnect()
		end
		table.clear(hiddenConns)
		table.clear(hiddenParts)
		controls(true)
		hud.setCutscene(false)
	end

	local function destroyFigures()
		for _, fig in figures do
			if fig.rig then
				fig.rig.model:Destroy()
			end
		end
		table.clear(figures)
		for _, g in groups do
			g:Destroy()
		end
		table.clear(groups)
		if folder then
			folder:Destroy()
			folder = nil
		end
		labelGui = nil
		labelText = nil
		labelScale = nil
	end

	-- Ends everything (a new Sync, the garage): camera, HUD, characters back; figures gone.
	function director.stop()
		playing = false
		finished = false
		onDone = nil
		caption.Visible = false
		skipChip.Visible = false
		restore()
		destroyFigures()
	end

	function director.isPlaying(): boolean
		return playing
	end

	-- The cut is over: the shot and the figures hold behind the results card (the HUD and
	-- CoreGui come back for it) until stop().
	local function finish()
		if finished then
			return
		end
		finished = true
		caption.Visible = false
		skipChip.Visible = false
		if skipConn then
			skipConn:Disconnect()
			skipConn = nil
		end
		if labelGui then
			labelGui.Enabled = false
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
		hud.setCutscene(false)
		local cb = onDone
		onDone = nil
		if cb then
			task.spawn(cb)
		end
	end

	-- A figure's rig: the player's own character copy (their look), else the owner's
	-- stripped template, else a mannequin (orphan tapes: Tape Grey).
	local function rigFor(e: any, hue: Color3): any
		local rig: any = nil
		if e.kind == "player" then
			local p = Players:GetPlayerByUserId(e.ownerId)
			local char = p and p.Character
			if char then
				rig = Rigs.buildCopy(char)
			end
			if not rig then
				local t = templateOf(e.ownerId)
				rig = t and Rigs.buildAvatar(t)
			end
			rig = rig or Rigs.buildMannequin()
			if rig.kind == "mannequin" then
				Rigs.tint(rig, hue)
			end
			return rig
		end
		local t = templateOf(e.ownerId)
		rig = t and Rigs.buildAvatar(t)
		rig = rig or Rigs.buildMannequin()
		Rigs.tint(rig, hue)
		return rig
	end

	local function groupFor(ownerId: number, hue: Color3, parent: Instance): Model
		local g = groups[ownerId]
		if not g then
			local m = Instance.new("Model")
			m.Name = "Owner_" .. tostring(ownerId)
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 1
			hl.OutlineTransparency = 0
			hl.OutlineColor = hue
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Enabled = tierNow < 4 -- the performance tier drops Highlights at 4 (§6.8)
			hl.Adornee = m
			hl.Parent = m
			m.Parent = parent
			groups[ownerId] = m
			g = m
		end
		return g :: Model
	end

	-- The row must not stand inside the parked van (LineupPlan.arrange). Returns the spots
	-- (level space) and the row's yaw.
	local function arrange(spots: { Vector3 }, yaw: number): ({ Vector3 }, number)
		local body: BasePart? = world.vanBody()
		if not body then
			return spots, yaw
		end
		local origin: Vector3 = state.origin
		local c = body.Position - origin
		-- The kit van is drawn over the greybox body (same centre) and may be larger.
		local visual = body:GetAttribute("EH_VisualSize")
		local size = if typeof(visual) == "Vector3" then body.Size:Max(visual) else body.Size
		local box = {
			cx = c.X,
			cz = c.Z,
			hx = size.X / 2 + H.LINEUP_VAN_CLEARANCE,
			hz = size.Z / 2 + H.LINEUP_VAN_CLEARANCE,
		}
		local plain = {}
		for i, p in spots do
			plain[i] = { x = p.X, z = p.Z }
		end
		local out, newYaw = LineupPlan.arrange(plain, yaw, box, 0.5, 60)
		local moved: { Vector3 } = {}
		for i, p in out do
			moved[i] = Vector3.new(p.x, spots[i].Y, p.z)
		end
		return moved, newYaw
	end

	-- The newest clone of the local player in the line-up (the "ME" label).
	local function newestMine(entries: { any }): any
		local lp = Players.LocalPlayer
		local best: any = nil
		for _, e in entries do
			if e.kind == "clone" and lp and e.ownerId == lp.UserId then
				if not best or e.run > best.run or (e.run == best.run and e.slot > best.slot) then
					best = e
				end
			end
		end
		return best
	end

	local function captionText(over: any): string
		local parts = { Strings.run(over.runs or 0) }
		local ofMe = tonumber(over.ofMe) or 0
		if ofMe >= Config.Sim.SWARM_OF_ME then
			table.insert(parts, Strings.ofMe(ofMe))
		end
		table.insert(parts, Ui.money(tonumber(over.banked) or 0))
		return table.concat(parts, Strings.SEP)
	end

	-- Camera shot for a row (world): centre, the way it faces, its width. The camera
	-- stands on the row's facing side, as far as the fit wants; if a wall is in the way
	-- (between the row and the camera, or inside the frame's sides) it comes closer and
	-- the lens widens to keep the row in frame (up to LINEUP_CAM_FOV_MAX).
	local function frameShot(centre: Vector3, fwd: Vector3, width: number): any
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local aspect = math.max(vp.X, 1) / math.max(vp.Y, 1)
		local up = Vector3.new(0, H.LINEUP_CAM_HEIGHT, 0)
		local across = Vector3.new(fwd.Z, 0, -fwd.X)
		local function distFor(f: number): number
			return LineupPlan.fitDistance(
				width,
				aspect,
				f,
				H.LINEUP_CAM_FIT_WIDTH,
				H.LINEUP_FIGURE_HEIGHT,
				H.LINEUP_CAM_FIT_HEIGHT
			)
		end
		local function fovFor(d: number): number
			return LineupPlan.fovFor(
				d,
				width,
				aspect,
				H.LINEUP_CAM_FOV,
				H.LINEUP_CAM_FOV_MAX,
				H.LINEUP_CAM_FIT_WIDTH,
				H.LINEUP_FIGURE_HEIGHT,
				H.LINEUP_CAM_FIT_HEIGHT
			)
		end
		local level = state.folder and state.folder:FindFirstChild("Level")
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = if level then { level } else {}
		local function clear(d: number, f: number): boolean
			if not level then
				return true
			end
			local camPos = centre + fwd * d + up
			if workspace:Raycast(centre + up, camPos - (centre + up), params) then
				return false
			end
			local hw = d * math.tan(math.rad(f) / 2) * aspect * 0.95
			for _, k in { -1, -0.5, 0.5, 1 } do
				local target = centre + across * (hw * k) + up
				if workspace:Raycast(camPos, target - camPos, params) then
					return false
				end
			end
			return true
		end
		local range = H.LINEUP_CAM_DISTANCE
		local want = math.clamp(distFor(H.LINEUP_CAM_FOV), range[1], range[2])
		local d, fov = range[1], fovFor(range[1])
		local k = want
		while k >= range[1] do
			local f = fovFor(k)
			if clear(k * (1 + H.LINEUP_CAM_PUSH), f) then
				d, fov = k, f
				break
			end
			k -= 0.5
		end
		local lookAt = centre + Vector3.new(0, H.LINEUP_CAM_LOOK_HEIGHT, 0)
		local function at(dist: number, lift: number): CFrame
			return CFrame.lookAt(centre + fwd * dist + up + Vector3.new(0, lift, 0), lookAt)
		end
		return {
			fov = fov,
			start = at(d * (1 + H.LINEUP_CAM_PUSH), 0.6),
			final = at(d, 0),
		}
	end

	-- Plays the cut for an Over result (result.lineup). `done` runs when the results
	-- card should show (after the cut, or at once when there is nothing to line up).
	-- `ageOf(entry)` gives a clone's true age in seconds at the start of the walk (the
	-- "ME, N SEC AGO" label), or nil when it is not known (no label then).
	function director.play(over: any, done: () -> (), ageOf: ((entry: any) -> number?)?)
		director.stop()
		local entries = over.lineup
		local cam = workspace.CurrentCamera
		if type(entries) ~= "table" or #entries == 0 or not cam or not state.folder then
			task.spawn(done)
			return
		end
		onDone = done
		playing = true
		finished = false
		local origin: Vector3 = state.origin
		local floorY = if state.level then state.level.floorY else 0
		local reduced = state.reduced == true

		-- Spots (level space) and the row's facing, clear of the van body.
		local raw: { Vector3 } = {}
		for i, e in entries do
			raw[i] = Vector3.new(e.x, floorY, e.z)
		end
		local spots, rowYaw = arrange(raw, entries[1].yaw or math.pi)
		local fwd = look(rowYaw)
		local minC, maxC = math.huge, -math.huge
		local across = Vector3.new(fwd.Z, 0, -fwd.X)
		local centreSum = Vector3.zero
		for i in spots do
			centreSum += spots[i]
			local a = spots[i]:Dot(across)
			minC = math.min(minC, a)
			maxC = math.max(maxC, a)
		end
		local centre = origin + centreSum / #spots
		local width = (maxC - minC) + 2.5

		-- Start positions: the clones where the run left them, players where they stand.
		local clonePos: { [string]: CFrame } = {}
		for _, f in echo.figures() do
			local a = f.actor
			if not f.gone then
				clonePos[tostring(a.owner) .. ":" .. tostring(a.slot)] = f.feet
			end
		end
		local f = Instance.new("Folder")
		f.Name = "HeistLineup"
		f.Parent = workspace
		folder = f

		-- Age ramp per owner (newest = full hue), like the run's clones.
		local newestRun: { [number]: number } = {}
		for _, e in entries do
			if e.kind == "clone" then
				newestRun[e.ownerId] = math.max(newestRun[e.ownerId] or 0, e.run)
			end
		end
		local mine = newestMine(entries)
		for i, e in entries do
			local orphan = Players:GetPlayerByUserId(e.ownerId) == nil
			local hue = Palette.hueFor(e.seat)
			if e.kind == "clone" then
				local age = math.max(0, (newestRun[e.ownerId] or e.run) - e.run)
				hue = Palette.dim(hue, math.max(1 - H.CLONE_AGE_DIM * age, 0.35))
				if orphan then
					hue = Palette.tapeGrey
				end
			end
			local target = CFrame.new(origin + spots[i]) * CFrame.Angles(0, rowYaw, 0)
			local from: CFrame = target
			if e.kind == "clone" then
				from = clonePos[tostring(e.ownerId) .. ":" .. tostring(e.slot)] or target
			else
				local p = Players:GetPlayerByUserId(e.ownerId)
				local char = p and p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local pos = root.Position
					from = CFrame.new(Vector3.new(pos.X, origin.Y + floorY, pos.Z))
						* CFrame.Angles(0, yawOf(root.CFrame.LookVector), 0)
				end
			end
			local _, fromYaw = from:ToEulerAnglesYXZ()
			local dir = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
			local dist = dir.Magnitude
			local fig = {
				entry = e,
				rig = nil :: any, -- built a few per frame (buildSome)
				hue = hue,
				mine = mine ~= nil and e == mine,
				from = from,
				target = target,
				dist = dist,
				delay = e.delay or 0,
				start = 0,
				walk = 0,
				walkYaw = if dist > 0.05 then yawOf(dir) else fromYaw,
				fromYaw = fromYaw,
				endYaw = rowYaw,
				posed = false,
				phase = 0,
			}
			table.insert(figures, fig)
			fig.age = if fig.mine and ageOf then ageOf(e) else nil
		end

		-- One figure's rig (hidden until every figure exists; then they swap in together).
		local function buildFigure(fig: any)
			local e = fig.entry
			local rig = rigFor(e, fig.hue)
			if e.kind == "clone" then
				rig.model.Parent = groupFor(e.ownerId, Palette.hueFor(e.seat), f)
			else
				rig.model.Parent = f
			end
			Rigs.setFade(rig, 1)
			Rigs.startWalk(rig)
			fig.rig = rig
			local age = fig.age
			if age then
				local gui = Instance.new("BillboardGui")
				gui.Name = "MeLabel"
				gui.Size = UDim2.fromOffset(240, 40)
				gui.StudsOffset = Vector3.new(0, 3.4, 0)
				gui.LightInfluence = 0
				gui.AlwaysOnTop = true
				gui.MaxDistance = 200
				local t = Instance.new("TextLabel")
				t.BackgroundTransparency = 1
				t.Size = UDim2.fromScale(1, 1)
				t.FontFace = FONT
				t.TextScaled = true
				t.TextColor3 = Palette.exit
				Ui.textStroke(t)
				t.RichText = true
				-- True age at the walk-off (CLIPS §1.2), from HeistClient.
				t.Text = Ui.agoLabel(Strings.ME, age, Palette.CLONE_HUES[1])
				t.Parent = gui
				local scale = Instance.new("UIScale")
				scale.Parent = t
				gui.Adornee = Rigs.anchorPart(rig)
				gui.Parent = rig.model
				labelGui = gui
				labelText = t
				labelScale = scale
			end
		end
		local built = 0
		local swapped = false
		-- Builds up to BUILD_PER_FRAME figures; when all exist, swaps them for the run's
		-- clones and the real characters in one frame.
		local function buildSome()
			local n = 0
			while built < #figures and n < BUILD_PER_FRAME do
				built += 1
				n += 1
				buildFigure(figures[built])
			end
			if built >= #figures and not swapped then
				swapped = true
				echo.hideAll()
				setCharactersHidden(true)
				for _, fig in figures do
					Rigs.setFade(fig.rig, 0)
				end
			end
		end
		local starts, walks, poseAt, endAt = LineupPlan.timeline(
			figures,
			H.LINEUP_START_DELAY,
			H.LINEUP_WALK_SPEED,
			H.LINEUP_WALK_MAX_SECONDS,
			H.LINEUP_TURN_SECONDS,
			H.LINEUP_POSE_GAP,
			H.LINEUP_HOLD_SECONDS
		)
		for i, fig in figures do
			fig.start = starts[i]
			fig.walk = walks[i]
		end
		tPose = poseAt
		tEnd = endAt

		-- The HUD and CoreGui go now; the run's clones and the real characters stay until the
		-- figures are built (buildSome swaps them in one frame).
		collectCharacters()
		saved = { fov = cam.FieldOfView, cf = cam.CFrame }
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
		controls(false)
		hud.setCutscene(true)
		shot = frameShot(centre, fwd, width)
		cam.CameraType = Enum.CameraType.Scriptable
		if reduced then
			cam.CFrame = shot.final
			cam.FieldOfView = shot.fov
		end
		caption.Text = captionText(over)
		caption.Visible = false

		t0 = os.clock()
		cutsSeen += 1
		-- A tap anywhere skips after the pose on the first cut of the session (the payoff),
		-- after LINEUP_SKIP_AFTER on later ones; the SKIP chip works from LINEUP_SKIP_AFTER.
		skippable = if cutsSeen <= 1 then t0 + tPose + H.LINEUP_SKIP_AFTER_POSE else t0 + H.LINEUP_SKIP_AFTER
		local chipAt = t0 + H.LINEUP_SKIP_AFTER
		local lastFrame = t0
		if skipConn then
			skipConn:Disconnect()
		end
		skipConn = skipChip.Activated:Connect(function()
			if playing and not finished and os.clock() >= chipAt then
				finish()
			end
		end)
		inputConn = UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed or not playing or finished or os.clock() < skippable then
				return
			end
			local t = input.UserInputType
			if
				t == Enum.UserInputType.Touch
				or t == Enum.UserInputType.MouseButton1
				or input.KeyCode == Enum.KeyCode.Space
				or input.KeyCode == Enum.KeyCode.Return
				or input.KeyCode == Enum.KeyCode.ButtonA
			then
				finish()
			end
		end)

		local parts: { BasePart } = {}
		local cfs: { CFrame } = {}
		local startCf = cam.CFrame
		local startFov = cam.FieldOfView
		local hopSeen = false
		RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
			debug.profilebegin("EH.Lineup")
			local now = os.clock()
			local e = now - t0
			-- Watchdog: a lost frame budget or an overlong cut ends it cleanly.
			if now - lastFrame > 2 or e > tEnd + 4 then
				finish()
			end
			lastFrame = now
			local c = workspace.CurrentCamera
			if c and saved then
				if c.CameraType ~= Enum.CameraType.Scriptable then
					c.CameraType = Enum.CameraType.Scriptable
				end
				if not reduced then
					local move = easeInOut(e / H.LINEUP_CAM_MOVE_SECONDS)
					local push = smooth(e / math.max(tEnd, 0.1))
					local framed = shot.start:Lerp(shot.final, push)
					c.CFrame = startCf:Lerp(framed, move)
					c.FieldOfView = startFov + (shot.fov - startFov) * move
				else
					c.CFrame = shot.final
					c.FieldOfView = shot.fov
				end
			end
			if swapped then
				setCharactersHidden(true)
			end
			if finished then
				debug.profileend()
				return -- the shot holds behind the results card: nothing else moves
			end
			buildSome()
			skipChip.Visible = now >= chipAt
			-- Caption: pops in with the walk-off.
			if e >= H.LINEUP_START_DELAY and not caption.Visible and not finished then
				caption.Visible = true
				captionScale.Scale = if reduced then 1 else 1.15
				if not reduced then
					Motion.tween(captionScale, "feedback", { Scale = 1 })
				end
			end
			-- "ME, N SEC AGO": in at 0.0, hold to 1.5 s, fade out by 1.8 s (CLIPS §1.2).
			if labelText and labelGui then
				local hold, out = H.LINEUP_LABEL_SECONDS[1], H.LINEUP_LABEL_SECONDS[2]
				local le = e - H.LINEUP_START_DELAY
				labelGui.Enabled = le >= 0 and le < out
				local a = if le <= hold then 0 else math.clamp((le - hold) / (out - hold), 0, 1)
				labelText.TextTransparency = a
				local labelStroke = labelText:FindFirstChild("TextStroke")
				if labelStroke and labelStroke:IsA("UIStroke") then
					labelStroke.Transparency = a
				end
				if labelScale then
					-- pop 115 % -> 100 % over 0.10 s
					labelScale.Scale = if reduced then 1 else 1 + 0.15 * (1 - math.clamp(le / 0.1, 0, 1))
				end
			end
			-- Figures: walk, turn, pose.
			table.clear(parts)
			table.clear(cfs)
			for _, fig in figures do
				local rig = fig.rig
				if not rig then
					continue
				end
				local cf: CFrame
				local speed = 0
				if e < fig.start then
					cf = fig.from
				elseif e < fig.start + fig.walk then
					local u = (e - fig.start) / math.max(fig.walk, 1e-3)
					local p0, p1 = fig.from.Position, fig.target.Position
					cf = CFrame.new(p0:Lerp(p1, u)) * CFrame.Angles(0, fig.walkYaw, 0)
					speed = (p1 - p0).Magnitude / math.max(fig.walk, 1e-3)
				else
					local u = smooth((e - fig.start - fig.walk) / H.LINEUP_TURN_SECONDS)
					local fromYaw = if fig.walk > 0 then fig.walkYaw else fig.fromYaw
					cf = CFrame.new(fig.target.Position) * CFrame.Angles(0, lerpAngle(fromYaw, fig.endYaw, u), 0)
				end
				fig.phase += speed * 0.35 * dt * 2 * math.pi
				local myPose = tPose + fig.delay
				if e >= myPose then
					if not fig.posed then
						fig.posed = true
						Rigs.setSpeed(rig, 0)
						if rig.kind == "avatar" then
							Rigs.playCheer(rig, H.LINEUP_POSE_ANIM)
						end
						if not hopSeen then
							-- the clone arpeggio (the sound logo) rides the pose ripple
							hopSeen = true
							Sound.arpeggio(math.min(#figures, #Config.Audio.ARPEGGIO_STEPS))
						end
					end
					local pe = e - myPose
					local amount = smooth(pe / 0.25)
					local hop = if reduced
						then 0
						else H.LINEUP_HOP * math.max(0, math.sin(math.clamp(pe / 0.45, 0, 1) * math.pi))
					Rigs.poseCheer(rig, cf, amount, hop, parts, cfs)
				else
					Rigs.setSpeed(rig, speed)
					Rigs.pose(rig, cf, fig.phase, math.clamp(speed / 10, 0, 1), parts, cfs)
				end
			end
			if #parts > 0 then
				workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			end
			if e >= tEnd then
				finish()
			end
			debug.profileend()
		end)
	end

	-- Runtime performance tier (§6.3): Line-up groups drop their Highlights at tier 4.
	function director.setTier(tier: number)
		tierNow = tier
		for _, g in groups do
			local hl = g:FindFirstChildOfClass("Highlight")
			if hl then
				hl.Enabled = tier < 4
			end
		end
	end

	-- Results are up: the cut is over but the shot holds behind the card until stop().
	function director.isHolding(): boolean
		return playing and finished
	end

	return director
end

return LineupDirector
