--!strict
-- Heist/Aurora: the northern lights over the town (PLAN_FIRST_PERSON "SKY"; STYLE_BIBLE §16; docs/PERF.md §4).
-- Built on the client from the pure Shared/Heist/AuroraPlan (numbers in Config.Aurora), so it costs the server
-- nothing, never replicates and never streams out (client-made instances stay; the Backdrop does the same).
--
-- Each layer is a chain of additive Beams (LightEmission 1, LightInfluence 0: unlit) along a curved spine high in
-- the sky, held by one invisible anchored Part that follows the camera horizontally (the layer's `follow` share, so
-- the bands slide a little against one another as you walk) and is turned toward the landmark. The spine's control
-- points are the Part's Attachments: they sway slowly, the Beams scroll their texture (the shimmer) and the
-- brightness and tint breathe. Nothing in it collides, is queried or casts a shadow, and the lowest ribbon stays
-- Config.Aurora.MIN_CLEARANCE studs over the anchor: it can never be reached.
--
-- Tiers (Shared/Heist/Budget): tiers 1-2 every layer, animated; tier 3 two layers; tier 4 one static layer.
-- Reduced motion: everything moves at Config.Aurora.REDUCED_MOTION speed, never off.
-- FaceCamera is on: the bands follow the camera, so the ribbon always faces the viewer and never shows its edge.
-- Textures: an unloaded Beam texture draws a solid bar, so every layer stays invisible until ContentProvider has
-- every tile, then fades in over REVEAL_SECONDS.
--
-- API (HeistClient; the story intro's Heist/Cinematic makes its own, anchored to its stage):
--   Aurora.new(parent?, opts?) -> director   parent defaults to workspace; opts.revealSeconds: the fade-in once the
--                                     textures load (default Config.Aurora.REVEAL_SECONDS; 0 = at once)
--   Aurora.solo(director) / Aurora.release(director)   while a director is solo, every other one draws nothing (the
--                                     intro's sky hides the session's; release hands it back)
--   director.setAnchor(origin, yaw?)  the site (heist instance origin or the garage); yaw = the landmark direction in
--                                     degrees (0 = toward -Z, + toward -X); nil reads it from Lighting.Sky
--   director.setTier(tier) / director.setReducedMotion(on) / director.setVisible(on)
--   director.step(now, camPos?)       one update by hand (RenderStepped calls it on a client; tests call it)
--   director.layerCount() / director.beams() / director.isRevealed() / director.destroy()

local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local AuroraPlan = require(HeistShared:WaitForChild("AuroraPlan"))
local Budget = require(HeistShared:WaitForChild("Budget"))

local A = Config.Aurora

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local TINT_A, TINT_B = rgb(A.TINT_A), rgb(A.TINT_B)

-- A plan point (x right, y up, z forward) in the holder Part's space (forward = the Part's -Z).
local function local3(p: AuroraPlan.Vec): Vector3
	return Vector3.new(p.x, p.y, -p.z)
end

type LayerRig = {
	spec: any,
	holder: Part,
	attachments: { Attachment },
	beams: { Beam },
}

local Aurora = {}

local live: { [any]: () -> () } = {} -- every director -> its applyTier (a solo switch re-applies them all)
local soloDirector: any = nil

local function reapply()
	for _, apply in live do
		apply()
	end
end

-- Only `director` draws until Aurora.release(director) (the story intro over the session's sky).
function Aurora.solo(director: any)
	soloDirector = director
	reapply()
end

function Aurora.release(director: any)
	if soloDirector == director then
		soloDirector = nil
		reapply()
	end
end

function Aurora.new(parent: Instance?, opts: any?): any
	local director = {}
	local revealSeconds = if opts and opts.revealSeconds ~= nil then opts.revealSeconds else A.REVEAL_SECONDS
	local folder = Instance.new("Folder")
	folder.Name = "EH_Aurora"
	local rigs: { LayerRig } = {}
	local tierNow = 1
	local reduced = false
	local visible = A.ENABLED == true
	local anchor = Vector3.zero
	local yawFixed: number? = nil
	local motionT = 0 -- seconds of motion (real time x the reduced-motion factor)
	local lastNow: number? = nil
	local lastUpdate = -math.huge
	local reveal = 0 -- 0 hidden .. 1 shown (the fade-in after the textures load)
	local loaded = false
	local stepConn: RBXScriptConnection? = nil
	local destroyed = false

	local function yaw(): number
		if yawFixed then
			return yawFixed
		end
		local sky = Lighting:FindFirstChildOfClass("Sky")
		local turn = if sky then sky.SkyboxOrientation.Y else 0
		return (Config.Backdrop.SKY_LANDMARK_YAW + turn) % 360
	end

	-- Build every layer once (a tier only switches Beams on and off; nothing is rebuilt or destroyed).
	for i, spec in A.LAYERS do
		local holder = Instance.new("Part")
		holder.Name = "Aurora_" .. spec.name
		holder.Size = Vector3.one
		holder.Transparency = 1
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.CastShadow = false
		holder.Locked = true
		local atts = table.create(spec.points)
		for k = 1, spec.points do
			local a = Instance.new("Attachment")
			a.Name = "P" .. k
			a.Parent = holder
			atts[k] = a
		end
		local beams = table.create(spec.points - 1)
		for k = 1, spec.points - 1 do
			local b = Instance.new("Beam")
			b.Name = "Curtain" .. k
			b.Attachment0 = atts[k]
			b.Attachment1 = atts[k + 1]
			b.Texture = A.TEXTURES[AuroraPlan.texture(spec, k)]
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureLength = 1
			b.TextureSpeed = 0
			b.Segments = A.SEGMENTS
			b.Width0 = spec.width
			b.Width1 = spec.width
			b.FaceCamera = true
			b.LightEmission = 1
			b.LightInfluence = 0
			b.ZOffset = 0 -- additive: the draw order between layers does not matter
			b.Transparency = NumberSequence.new(1)
			b.Enabled = false
			b.Parent = holder
			beams[k] = b
		end
		holder.Parent = folder
		rigs[i] = { spec = spec, holder = holder, attachments = atts, beams = beams }
	end

	local function shownLayers(): number
		if soloDirector ~= nil and soloDirector ~= director then
			return 0
		end
		return if visible then Budget.auroraLayers(tierNow) else 0
	end

	local function motion(): number
		return if reduced then A.REDUCED_MOTION else 1
	end

	-- The spine, curves, brightness, tint and transparency of one layer at motion time t.
	local function pose(rig: LayerRig, t: number)
		local spec = rig.spec
		local pts = AuroraPlan.spine(spec, t, A.REVERSE_SPINE)
		local h = AuroraPlan.handles(pts)
		local up = Vector3.yAxis
		for k, a in rig.attachments do
			local p = local3(pts[k])
			local tg = h.tangents[k]
			local x = Vector3.new(tg.x, tg.y, -tg.z)
			local y = (up - x * up:Dot(x)).Unit
			a.CFrame = CFrame.fromMatrix(p, x, y)
		end
		local bright = AuroraPlan.brightness(spec, t)
		local n = spec.points
		local alpha = (1 - spec.transparency) * reveal
		for k, b in rig.beams do
			b.CurveSize0 = h.out[k]
			b.CurveSize1 = h.into[k]
			b.Brightness = bright
			local u0, u1 = (k - 1) / (n - 1), k / (n - 1)
			b.Color = ColorSequence.new(
				TINT_A:Lerp(TINT_B, AuroraPlan.tintMix(spec, u0, t)),
				TINT_A:Lerp(TINT_B, AuroraPlan.tintMix(spec, u1, t))
			)
			-- the chain index runs left to right in the plan; a reversed spine fades the same ends
			local f0 = AuroraPlan.endFade(spec, k)
			local f1 = AuroraPlan.endFade(spec, k + 1)
			b.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1 - alpha * f0),
				NumberSequenceKeypoint.new(1, 1 - alpha * f1),
			})
		end
	end

	local function applyTier()
		local shown = shownLayers()
		local animated = Budget.auroraAnimated(tierNow)
		local scroll = if animated then motion() else 0
		for i, rig in rigs do
			local on = i <= shown and loaded
			for _, b in rig.beams do
				b.Enabled = on
				b.TextureSpeed = rig.spec.scroll * scroll
			end
		end
		lastUpdate = -math.huge -- pose on the next step (a static tier holds the rest pose)
	end

	-- Follow the camera horizontally; pose the layers at UPDATE_HZ (once, at rest, on a static tier).
	function director.step(now: number, camPos: Vector3?)
		if destroyed then
			return
		end
		local dt = if lastNow then math.clamp(now - (lastNow :: number), 0, 0.25) else 0
		lastNow = now
		local animated = Budget.auroraAnimated(tierNow)
		if animated then
			motionT += dt * motion()
		end
		if loaded and reveal < 1 then
			reveal = if revealSeconds <= 0 then 1 else math.min(1, reveal + dt / revealSeconds)
			lastUpdate = -math.huge
		end
		local cam = camPos
		if cam == nil then
			local c = workspace.CurrentCamera
			cam = if c then c.CFrame.Position else anchor
		end
		local turn = CFrame.Angles(0, math.rad(yaw()), 0)
		local shown = shownLayers()
		for i, rig in rigs do
			if i > shown then
				continue
			end
			local f = rig.spec.follow
			local c = cam :: Vector3
			local pos = Vector3.new(anchor.X + (c.X - anchor.X) * f, anchor.Y, anchor.Z + (c.Z - anchor.Z) * f)
			rig.holder.CFrame = CFrame.new(pos) * turn
		end
		local due = now - lastUpdate >= 1 / A.UPDATE_HZ
		if due and (animated or lastUpdate == -math.huge) then
			lastUpdate = now
			local t = if animated then motionT else 0
			for i, rig in rigs do
				if i <= shown then
					pose(rig, t)
				end
			end
		end
	end

	function director.setAnchor(origin: Vector3, landmarkYaw: number?)
		anchor = origin
		yawFixed = landmarkYaw
	end

	-- Hooked to Telemetry.onTier by the caller (1 = quality ... 4 = minimum).
	function director.setTier(tier: number)
		tierNow = tier
		applyTier()
	end

	function director.setReducedMotion(on: boolean)
		reduced = on
		applyTier()
	end

	function director.setVisible(on: boolean)
		visible = on and A.ENABLED == true
		applyTier()
	end

	-- Layers drawn now (0 until the textures are loaded or while hidden).
	function director.layerCount(): number
		return if loaded then shownLayers() else 0
	end

	-- Every Beam, in layer order (diagnostics and tests).
	function director.beams(): { Beam }
		local out = {}
		for _, rig in rigs do
			for _, b in rig.beams do
				table.insert(out, b)
			end
		end
		return out
	end

	-- Layers built (whatever the tier) and whether the fade-in has started.
	function director.layersBuilt(): number
		return #rigs
	end

	function director.isRevealed(): boolean
		return loaded
	end

	-- Mark the textures as loaded without ContentProvider (tests on a server, where nothing renders).
	function director.markLoaded()
		loaded = true
		applyTier()
	end

	function director.destroy()
		destroyed = true
		live[director] = nil
		Aurora.release(director)
		if stepConn then
			stepConn:Disconnect()
			stepConn = nil
		end
		folder:Destroy()
	end

	-- Preload every tile; show nothing until all of them arrive (one retry after a failure).
	local function preload(attempt: number)
		local list: { any } = {}
		for _, id in A.TEXTURES do
			table.insert(list, id)
		end
		local failed = false
		local ok = pcall(function()
			ContentProvider:PreloadAsync(list, function(_id: string, status: Enum.AssetFetchStatus)
				if status ~= Enum.AssetFetchStatus.Success then
					failed = true
				end
			end)
		end)
		if destroyed then
			return
		end
		if ok and not failed then
			loaded = true
			applyTier()
		elseif attempt < 2 then
			task.delay(A.PRELOAD_RETRY_SECONDS, preload, attempt + 1)
		end
	end

	folder.Parent = parent or workspace
	live[director] = applyTier
	applyTier()
	if RunService:IsClient() and A.ENABLED then
		task.spawn(preload, 1)
		stepConn = RunService.RenderStepped:Connect(function()
			director.step(os.clock())
		end)
	end
	return director
end

return Aurora
