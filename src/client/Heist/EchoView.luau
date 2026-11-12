--!strict
-- Heist/EchoView: draws every clone of the run on this client (MASTERPLAN §6.5, §8.2,
-- §8.5 "clone rig"). Clones are pure data on the server; here each one is a pooled
-- rig posed from its recording with Rec/Sampler on the replicated loop clock.
--
--   * Pools per owner, never destroyed on rewind; an owner's pool switches from
--     mannequins to their avatar template once it arrives in ReplicatedStorage.
--   * Identity: owner hue + glyph + number badge (§0 C5), hidden beyond 40 studs;
--     one Highlight per owner group (look B: opaque glow, outline only).
--   * Age ramp: each older run 12% dimmer; solo: older runs drift toward violet.
--     Other players' clones at 70% brightness; orphan tapes in Tape Grey.
--   * "Tape print": clones form 60 ms apart in record order with a floor ring.
--   * Server-decided outcomes arrive as events: Busted (glitch + tape burst), Zapped
--     (soot), Stuck ("..." and hold), Shrug ("?").
--   * One BulkMoveTo per frame for every rig part.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Sampler = require(Shared:WaitForChild("Rec"):WaitForChild("Sampler"))
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))

local Rigs = require(script.Parent:WaitForChild("Rigs"))
local Ui = require(script.Parent:WaitForChild("Ui"))

local H = Config.Heist
-- The viewer (nil when the engine smoke test runs these views on the server).
local function myId(): number
	local lp = Players.LocalPlayer
	return if lp then lp.UserId else 0
end

local EchoView = {}

type Pool = { kind: string, free: { any }, group: Model, highlight: Highlight }

local function badgeGui(parent: BasePart, text: string, color: Color3): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Badge"
	gui.Size = UDim2.fromOffset(44, 28)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = H.CLONE_BADGE_DISTANCE
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundColor3 = Palette.ink
	label.BackgroundTransparency = 0.25
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	label.TextSize = 20
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = label
	gui.Adornee = parent
	gui.Parent = parent
	return gui, label
end

local function bubbleGui(parent: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Size = UDim2.fromOffset(120, 32)
	gui.StudsOffset = Vector3.new(0, 4.2, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
	label.TextSize = 22
	label.TextColor3 = Palette.white
	label.TextStrokeTransparency = 0.2
	label.Text = ""
	label.Parent = gui
	gui.Adornee = parent
	gui.Parent = parent
	return gui, label
end

local function burst(parent: BasePart, color: Color3): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Burst"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.6
	e.Parent = parent
	return e
end

function EchoView.new(state: any): any
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

	local function templateOf(ownerId: number): Model?
		local f = ReplicatedStorage:FindFirstChild(Protocol.AVATARS)
		local t = f and f:FindFirstChild(tostring(ownerId))
		if t and t:IsA("Model") then
			return t
		end
		return nil
	end

	local function poolFor(ownerId: number, hue: Color3): Pool
		local want = if templateOf(ownerId) then "avatar" else "mannequin"
		local pool = pools[ownerId]
		if pool and pool.kind ~= want then
			table.insert(retiring, pool)
			pools[ownerId] = nil
			pool = nil
		end
		if not pool then
			local group = Instance.new("Model")
			group.Name = "Owner_" .. tostring(ownerId)
			local hl = Instance.new("Highlight")
			hl.FillTransparency = 1
			hl.OutlineTransparency = 0
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Enabled = tierNow < 4 -- the current performance tier (§6.8: 4 drops Highlights)
			hl.Adornee = group
			hl.Parent = group
			group.Parent = folder
			pool = { kind = want, free = {}, group = group, highlight = hl }
			pools[ownerId] = pool
		end
		local p = pool :: Pool
		p.highlight.OutlineColor = hue
		return p
	end

	local function newEntry(pool: Pool, ownerId: number): any
		local rig: any = nil
		if pool.kind == "avatar" then
			local t = templateOf(ownerId)
			rig = t and Rigs.buildAvatar(t)
		end
		rig = rig or Rigs.buildMannequin()
		rig.model.Parent = pool.group
		Rigs.startWalk(rig)
		local anchor = Rigs.anchorPart(rig)
		local badge, badgeText = badgeGui(anchor, "", Palette.white)
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
		return {
			rig = rig,
			pool = pool,
			badge = badge,
			badgeText = badgeText,
			bubble = bubble,
			bubbleText = bubbleText,
			bubbleUntil = 0,
			trail = trail,
			emitter = burst(anchor, Palette.white),
			label = nil :: BillboardGui?,
			phase = 0,
			fade = -1,
			near = false,
		}
	end

	-- Drops the rig pools of owners who are no longer in the crew (each pool holds
	-- hidden avatar rigs and an enabled Highlight for the whole session otherwise).
	local function prunePools(keep: { [number]: boolean })
		for ownerId, pool in pools do
			if not keep[ownerId] and ownerId ~= myId() then
				pool.group:Destroy()
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

	local function release(entry: any)
		local rig = entry.rig
		Rigs.setFade(rig, 1)
		Rigs.setSpeed(rig, 0)
		entry.trail.Enabled = false
		entry.bubble.Enabled = false
		if entry.label then
			entry.label:Destroy()
			entry.label = nil
		end
		entry.fade = 1
		table.insert(entry.pool.free, entry)
	end

	local function hueFor(a: any, rank: number, ownCount: number, solo: boolean): Color3
		if a.orphan then
			return Palette.tapeGrey
		end
		local hue = Palette.hueFor(a.seat)
		if solo and ownCount > 1 then
			-- Older runs drift up to 25 degrees toward violet (§6.5 #4)
			local h, s, v = hue:ToHSV()
			local f = rank / (ownCount - 1)
			hue = Color3.fromHSV((h + f * 25 / 360) % 1, s, v)
		end
		local dim = 1 - H.CLONE_AGE_DIM * rank
		if a.owner ~= myId() then
			dim *= H.OTHER_CLONE_BRIGHTNESS
		end
		return Palette.dim(hue, math.max(dim, 0.35))
	end

	local function flushRetiring()
		for _, pool in retiring do
			pool.group:Destroy()
		end
		table.clear(retiring)
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
		local keep = crewSet()
		for _, a in msg.actors do
			keep[a.owner] = true -- orphan tapes of a player who left still draw
		end
		prunePools(keep)
		local solo = #(state.crew or {}) <= 1
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
			Rigs.tint(entry.rig, hue)
			entry.actor = a
			entry.rec = rec
			entry.hue = hue
			entry.badgeText.Text = Palette.badge(a.seat, a.slot)
			entry.badgeText.TextColor3 = if a.orphan then Palette.tapeGrey else Palette.hueFor(a.seat)
			entry.trail.Color = ColorSequence.new(hue)
			entry.emitter.Color = ColorSequence.new(hue)
			entry.visibleAt = startLocal + k * H.CLONE_SPAWN_STAGGER
			entry.printed = false
			entry.fade = 1
			entry.goneShown = false
			entry.phase = 0
			entry.near = false
			k += 1
			if a == newestOwn then
				newestOwnId = a.id
			end
			if a == newestOwn and state.level and state.level.tutorial ~= nil then
				-- "◀ YOU, 10 SEC AGO" (§6.5 #5, §7.5): the number is always true (CLIPS §1.2).
				local duration = Sampler.duration(rec)
				local secs = duration + (msg.transition or 0)
				-- §7.5 (13-22 s): the clone forms a beat after control returns, so it visibly
				-- walks out of you, and its label stays until it has stopped on the plate.
				local controlAt = startLocal + (msg.transition or 0) * 0.25
				entry.visibleAt = controlAt + H.TUTORIAL_CLONE_FADE_IN
				local label, text = badgeGui(Rigs.anchorPart(entry.rig), "", hue)
				text.RichText = true
				text.TextColor3 = Palette.exit
				text.Text = Ui.agoLabel("YOU", secs, Palette.hueFor(a.seat))
				label.Name = "YouLabel"
				label.Size = UDim2.fromOffset(190, 30)
				label.StudsOffset = Vector3.new(0, 3.6, 0)
				label.MaxDistance = 120
				entry.label = label
				entry.labelUntil = controlAt
					+ math.min(duration, H.CLONE_LABEL_MAX_SECONDS)
					+ H.CLONE_LABEL_HOLD_AFTER_STOP
			end
			active[a.id] = entry
			table.insert(order, entry)
		end
		flushRetiring()
	end

	-- "Tape print": a ring on the floor where a clone forms (none under reduced motion).
	local function printRing(at: Vector3, hue: Color3)
		if state.reduced then
			return
		end
		local ring = Instance.new("Part")
		ring.Name = "PrintRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = hue
		ring.Transparency = 0.2
		ring.Size = Vector3.new(0.1, 1, 1)
		ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
		ring.Parent = folder
		local tw = TweenService:Create(
			ring,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.1, 5, 5), Transparency = 1 }
		)
		tw.Completed:Once(function()
			ring:Destroy()
		end)
		tw:Play()
	end

	local function say(entry: any, text: string, color: Color3, seconds: number, now: number)
		entry.bubbleText.Text = text
		entry.bubbleText.TextColor3 = color
		entry.bubble.Enabled = true
		entry.bubbleUntil = now + seconds
	end

	-- A server-decided outcome for a clone (from the event log).
	function view.effect(actorId: number, kind: string, now: number)
		local entry = active[actorId]
		if not entry then
			return
		end
		if kind == "Busted" then
			entry.emitter:Emit(24)
			say(entry, "BUSTED", Palette.alarm, 1.2, now)
		elseif kind == "Zapped" then
			entry.emitter.Color = ColorSequence.new(Palette.ink)
			entry.emitter:Emit(16)
			say(entry, "ZAP!", Palette.alarm, 1.0, now)
		elseif kind == "Stuck" then
			say(entry, "...  ✕", Palette.alarm, 3.0, now)
		elseif kind == "Shrug" then
			say(entry, "?", Palette.white, 1.2, now)
		end
	end

	function view.positionOf(actorId: number): Vector3?
		local entry = active[actorId]
		if entry and entry.lastPos then
			return entry.lastPos
		end
		return nil
	end

	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}

	-- Poses every clone at view time tView (or along the reel when `reelT` is set:
	-- the rewind plays each path backwards from the end of the last run, §7.1).
	function view.update(tView: number, now: number, dt: number, reelT: number?)
		if not run then
			return
		end
		table.clear(parts)
		table.clear(cframes)
		local origin: Vector3 = state.origin
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		for _, entry in order do
			local a = entry.actor
			local fx = state.actorFx[a.id]
			-- Gone (busted / zapped, faded out): nothing to sample or pose until the reel.
			if not reelT and entry.fade >= 1 and fx and fx.gone and now - (fx.goneAtLocal or now) > 0.35 then
				continue
			end
			local rec = entry.rec
			local t = reelT or tView
			if fx and fx.stuckT and not reelT then
				t = math.min(t, fx.stuckT)
			end
			local x, y, z, yaw = Sampler.at(rec, t)
			if x == nil then
				continue
			end
			local vx, _, vz = Sampler.velocity(rec, t)
			local speed = math.sqrt(vx * vx + vz * vz)
			if (fx and fx.stuckT and not reelT) or (fx and fx.gone and not reelT) then
				speed = 0
			end
			local rig = entry.rig
			local feet = CFrame.new(origin + Vector3.new(x :: number, y - rig.rootHeight, z)) * CFrame.Angles(0, yaw, 0)
			entry.phase += speed * 0.35 * dt
			Rigs.pose(rig, feet, entry.phase * 2 * math.pi, math.clamp(speed / 10, 0, 1), parts, cframes)
			Rigs.setSpeed(rig, speed)
			local pos = feet.Position + Vector3.new(0, 3, 0)
			entry.lastPos = pos
			entry.lastFeet = feet

			-- Visibility: tape print stagger, gone after an outcome, near-camera fade.
			local fade = 0
			if now < entry.visibleAt and not reelT then
				fade = 1
			elseif not entry.printed and not reelT then
				entry.printed = true
				printRing(feet.Position + Vector3.new(0, 0.1, 0), entry.hue)
			end
			if fx and fx.gone and not reelT then
				local since = now - (fx.goneAtLocal or now)
				if since > 0.35 then
					fade = 1
				elseif fx.gone == "Busted" then
					-- glitch at <= 3 flashes/s (§7.3); reduced motion: one smooth fade
					fade = if state.reduced
						then since / 0.35
						elseif math.floor(since * 2 * H.BLINK_HZ_MAX) % 2 == 0 then 0.6
						else 0
				end
			end
			-- Near-camera fade with hysteresis (a crowd of clones around you must not flip).
			local dist = (pos - camPos).Magnitude
			if entry.near then
				entry.near = dist < H.CLONE_NEAR_UNFADE
			else
				entry.near = dist < H.CLONE_NEAR_FADE
			end
			if fade < 1 and entry.near then
				fade = math.max(fade, 0.7)
			end
			if fade ~= entry.fade then
				entry.fade = fade
				Rigs.setFade(rig, fade)
				entry.badge.Enabled = fade < 1
			end
			entry.trail.Enabled = trailsOn and (reelT ~= nil or speed > Config.Rec.WALK_SPEED + 1)
			if entry.bubble.Enabled and now > entry.bubbleUntil then
				entry.bubble.Enabled = false
			end
			if entry.label and now > (entry.labelUntil or 0) then
				entry.label:Destroy()
				entry.label = nil
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
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
			Rigs.setFade(entry.rig, 1)
			entry.badge.Enabled = false
			entry.trail.Enabled = false
			entry.bubble.Enabled = false
			if entry.label then
				entry.label:Destroy()
				entry.label = nil
			end
		end
		table.clear(order)
	end

	-- Runtime performance tier (§6.3): 2+ drops trails, 4 drops the owner Highlights.
	function view.setTier(tier: number)
		tierNow = tier
		trailsOn = tier < 2
		for _, pool in pools do
			pool.highlight.Enabled = tier < 4
		end
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
