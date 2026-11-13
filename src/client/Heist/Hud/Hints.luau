--!strict
-- Hud/Hints: what to do next, and help when stuck (MASTERPLAN §7.4-7.5; PLAN_STEAM_PLUS §5, §6;
-- WALKTHROUGH P0-2, P0-4, P1-10; premium G2, G4). The rules are pure in Shared/Heist/Help (the
-- sim bots check the same rules); this module draws them:
--   * the objective line (≤ 8 words): the L1 FTUE lines from the world state (§7.5), the level
--     line on run 1 and when stuck, the world-state lines from L2 on ("Stay here. Tap REWIND.",
--     REWIND then breathes through hud.setRewindRightMove), the first clone's "That's you. It
--     copies you.", the Party's first "That's Gus. Don't wake him.", the ghost's "Watch, then copy.";
--   * the L1 stuck hints in the world: the plate re-pulses, a beam from your feet, the Mentor
--     walks it (the stage carries across runs, Help.tutorialHintStage);
--   * stuck help after L1: the "SHOW ME?" chip after 2 runs with no progress; tapped, a dashed
--     chalk-outline ghost (Palette.ghostChalk, no reserved colour) walks only the next step of the
--     level's solution (Heist/GhostTapes, Help.nextStep), leaves a dashed chalk trail and fades;
--     the "TRY RELAXED?" card when the server offers it (3 catches) -> Heist.SelectLevel(i, true);
--   * the animated finger pointer on REWIND and on GRAB the first time each is the right move;
--   * every failure says why and what to try: one counterplay line per cause (Help.advice),
--     within ADVICE_DELAY s of the event (≤ 1 s);
--   * the bigger first-time beats (Heist/FirstTime): first plate press, rewind, clone, bank;
--   * first person (the default camera, PLAN_FIRST_PERSON wave C): lines that name a button name this
--     device's (Strings.forDevice: "Look at the cash. Press E." / X / "Tap GRAB."); the look cue (Hud/LookCue)
--     points at your L1 clone walking out of your own body, and at the chalk ghost, while out of view; the
--     ghost starts from the first point of its walk in front of your eyes, never inside the camera.
-- The chip and the card share HudLayout.HELP_CHIP (top right; checked by tests/hud_layout.luau).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Codec = require(Shared:WaitForChild("Rec"):WaitForChild("Codec"))
local Sampler = require(Shared:WaitForChild("Rec"):WaitForChild("Sampler"))
local EventLog = require(Shared:WaitForChild("Sim"):WaitForChild("EventLog"))
local HeistShared = Shared:WaitForChild("Heist")
local GhostTapes = require(HeistShared:WaitForChild("GhostTapes"))
local Help = require(HeistShared:WaitForChild("Help"))
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local FirstTime = require(script.Parent.Parent:WaitForChild("FirstTime"))
local Rigs = require(script.Parent.Parent:WaitForChild("Rigs"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))
local LookCue = require(script.Parent:WaitForChild("LookCue"))

local O = Config.Onboarding
local EV = EventLog.EV
local localPlayer = Players.LocalPlayer

local Hints = {}

function Hints.build(ctx: any): any
	local state = ctx.state
	local hud = ctx.hud
	local hints = {}

	---------------------------------------------------------------------------
	-- Per heist / per run state
	---------------------------------------------------------------------------
	local tracker = Help.newTracker()
	local due: Help.Due = { showMe = false, relaxed = false, levelLine = false, any = false }
	local countedRun = 0 -- the last run fed to the tracker
	local runFacts = { goalBanked = false, banked = false, caught = false }
	local runDeckHeld: Help.Held = {} -- plates the clones in this run end on (all owners)
	local runStart = 0 -- os.clock() when the run's control starts
	local firstCloneUntil = 0
	local cloneCueUntil = 0 -- L1, first person: the look cue follows your clone until then
	local gusIntroUntil = 0
	local relaxedSent = false
	local rewindRight = false
	local needed: { [number]: boolean } = {}
	local neededFor: any = nil

	local function neededPlates(): { [number]: boolean }
		local level = state.level
		if level ~= neededFor then
			neededFor = level
			needed = if level then Help.neededPlates(level) else {}
		end
		return needed
	end

	-- The deck as Help reads it: { {rec, status} } in slot order.
	local function deckSlots(): ({ any }, number)
		local deck = state.deck
		local out = {}
		if deck and type(deck.slots) == "table" then
			for i, s in deck.slots do
				out[i] = { rec = state.recs[s.key], status = s.status }
			end
		end
		return out, if deck then tonumber(deck.cap) or 4 else 4
	end

	---------------------------------------------------------------------------
	-- Objective line
	---------------------------------------------------------------------------
	local function onPlate(pos: Vector3, plateIndex: number): boolean
		local level = state.level
		local def = level and level.plates[plateIndex]
		if not def then
			return false
		end
		local b = def.box
		return pos.X >= b.minX and pos.X <= b.maxX and pos.Z >= b.minZ and pos.Z <= b.maxZ and pos.Y <= b.maxY
	end

	local function plateUnder(pos: Vector3?): number?
		local level = state.level
		if not (pos and level) then
			return nil
		end
		for i in level.plates do
			if onPlate(pos, i) then
				return i
			end
		end
		return nil
	end

	-- Is the L1 auto-end armed this run (run 1, or later until a clone stood on the plate)?
	function hints.autoEndArmed(): boolean
		local folder = state.folder
		return folder ~= nil and folder:GetAttribute("AutoEndArmed") == true
	end

	local ghost: any = nil -- the chalk ghost while it plays (below)

	-- A line that names a button, for this device in first person (Strings.forDevice); the plain line otherwise.
	local function say(key: string): string
		return Strings.forDevice(key, Common.device(), state.fpView == true)
	end

	-- L1 FTUE lines, the help lines and the generic objective. Returns the line, whether REWIND
	-- should pulse (L1 rule), and whether the line stays up (else it shows for OBJECTIVE_SECONDS
	-- after it changes, §7.4).
	function hints.objectiveText(_tView: number, pos: Vector3?): (string, boolean, boolean)
		local run = state.run
		local runIndex = if run then run.run else 1
		local carrying = state.carrying == true
		local now = os.clock()
		rewindRight = false
		if ghost then
			return if ghost.line then ghost.line else Strings.OBJ_WATCH_GHOST, false, true
		end
		if now < gusIntroUntil then
			return Strings.GUS_INTRO, false, true
		end
		if Common.isTutorial(state) then
			if hints.autoEndArmed() then
				local on = pos ~= nil and onPlate(pos, 1)
				if on then
					return say("OBJ_STAY_ON_PLATE"), true, true
				end
				return Strings.OBJ_STEP_ON_PLATE, false, true
			end
			if now < firstCloneUntil then
				return Strings.FIRST_CLONE, false, true
			end
			if now < ctx.stopsLineUntil then
				return Strings.OBJ_CLONE_STOPS, false, true
			end
			local folder = state.folder
			local plateHeld = folder ~= nil and folder:GetAttribute("P1Held") == true
			if not plateHeld and not carrying then
				return Strings.OBJ_WAIT_FOR_CLONE, false, true
			end
			return if carrying then Strings.OBJ_BANK_IT else say("OBJ_GRAB_CASH"), false, true
		end
		if now < firstCloneUntil then
			return Strings.FIRST_CLONE, false, true
		end
		local level = state.level
		local id = level and level.id
		local line = id and Strings.LEVEL_LINES[id]
		local fresh = runIndex == 1 and now - runStart < Common.OBJECTIVE_SECONDS
		if line and (fresh or (due.levelLine and now - runStart < Common.OBJECTIVE_SECONDS)) then
			return line, false, true
		end
		if level and Help.applies(level) then
			-- World-state lines (WALKTHROUGH P0-4): they stay up while they are true.
			local key, right = Help.worldLine(
				level,
				neededPlates(),
				{ onPlate = plateUnder(pos), carrying = carrying, deckHeld = runDeckHeld }
			)
			rewindRight = right
			local text = if key then say(key) else nil
			if text and text ~= "" then
				return text, false, true
			end
		end
		if carrying then
			return Strings.OBJ_BANK_IT, false, false
		end
		if line and runIndex == 1 then
			return line, false, false
		end
		return say("OBJ_GRAB_LOOT"), false, false
	end

	---------------------------------------------------------------------------
	-- L1 stuck hints (§7.5): plate re-pulse -> beam from your feet -> Mentor ghost
	---------------------------------------------------------------------------
	local hintFolder: Folder? = nil
	local hintRing: BasePart? = nil
	local hintBeam: Beam? = nil
	local mentor: any = nil
	local mentorParts: { BasePart } = {}
	local mentorCfs: { CFrame } = {}
	local mentorT0 = 0
	local mentorFrom: Vector3? = nil -- where this cycle of the walk starts
	local mentorCycle = -1

	local function hintFolderOf(): Folder
		local f = hintFolder
		if f and f.Parent then
			return f
		end
		local nf = Instance.new("Folder")
		nf.Name = "EH_Hints"
		nf.Parent = workspace
		hintFolder = nf
		return nf
	end

	function hints.clear()
		if hintBeam then
			local a0, a1 = hintBeam.Attachment0, hintBeam.Attachment1
			hintBeam:Destroy()
			if a0 then
				a0:Destroy()
			end
			if a1 then
				a1:Destroy()
			end
			hintBeam = nil
		end
		if hintRing then
			hintRing:Destroy()
			hintRing = nil
		end
		if mentor then
			mentor.model:Destroy()
			mentor = nil
			mentorFrom = nil
			mentorCycle = -1
		end
	end

	local function platePart(world: any): BasePart?
		local p = world and world.partFor("plate", 1)
		return if p and p:IsA("BasePart") then p else nil
	end

	function hints.show(world: any, now: number, hintStage: number)
		local plate = platePart(world)
		if not plate then
			return
		end
		-- 1: the plate re-pulses (a neon ring breathing on it)
		if hintStage >= 1 and not hintRing then
			local ring = Instance.new("Part")
			ring.Name = "HintRing"
			ring.Shape = Enum.PartType.Cylinder
			ring.Anchored = true
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.CastShadow = false
			ring.Material = Enum.Material.Neon
			ring.Color = Palette.CLONE_HUES[1]
			ring.Parent = hintFolderOf()
			hintRing = ring
		end
		local ring = hintRing
		if ring then
			local k = if state.reduced then 0.5 else 0.5 + 0.5 * math.sin(now * 5)
			ring.Size = Vector3.new(0.08, 4.6 + k, 4.6 + k)
			ring.Transparency = 0.25 + 0.5 * (1 - k)
			ring.CFrame = CFrame.new(plate.Position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		end
		-- 2: a beam from your feet to the plate
		if hintStage >= 2 and not hintBeam then
			local char = localPlayer.Character
			local r = char and char:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				local a0 = Instance.new("Attachment")
				a0.Name = "HintA0"
				a0.Parent = r
				local a1 = Instance.new("Attachment")
				a1.Name = "HintA1"
				a1.Position = Vector3.new(0, 0.3, 0)
				a1.Parent = plate
				local beam = Instance.new("Beam")
				beam.Attachment0 = a0
				beam.Attachment1 = a1
				beam.Color = ColorSequence.new(Palette.white)
				beam.Width0 = 0.4
				beam.Width1 = 0.4
				beam.LightEmission = 1
				beam.FaceCamera = true
				beam.Parent = plate
				hintBeam = beam
			end
		end
		-- 3: the Mentor ghost walks from your spawn to the plate and stands on it. First person: each walk
		-- starts GHOST_FP_AHEAD studs from you toward the plate, so it never starts inside your camera.
		if hintStage >= 3 and state.level then
			if not mentor then
				local rig = Rigs.buildMannequin()
				Rigs.tint(rig, Palette.white)
				Rigs.setFade(rig, 0.55)
				rig.model.Parent = hintFolderOf()
				mentor = rig
				mentorT0 = now
			end
			local spawns = state.level.spawns
			local sp = spawns[((state.mySeat or 1) - 1) % #spawns + 1]
			local origin: Vector3 = state.origin
			local spawnAt = origin + Vector3.new(sp.x, state.level.floorY, sp.z)
			local to = Vector3.new(plate.Position.X, spawnAt.Y, plate.Position.Z)
			local index = math.floor((now - mentorT0) / 5)
			if index ~= mentorCycle or not mentorFrom then
				mentorCycle = index
				mentorFrom = spawnAt
				local char = localPlayer.Character
				local r = char and char:FindFirstChild("HumanoidRootPart")
				if state.fpView == true and r and r:IsA("BasePart") then
					local me = Vector3.new(r.Position.X, spawnAt.Y, r.Position.Z)
					local way = to - me
					if way.Magnitude > O.GHOST_FP_AHEAD + 1 then
						mentorFrom = me + way.Unit * O.GHOST_FP_AHEAD
					end
				end
			end
			local from = mentorFrom :: Vector3
			local cycle = (now - mentorT0) % 5
			local u = math.clamp(cycle / 2.5, 0, 1)
			local dir = to - from
			local yaw = if dir.Magnitude > 0.1 then math.atan2(-dir.X, -dir.Z) else 0
			local feet = CFrame.new(from:Lerp(to, u)) * CFrame.Angles(0, yaw, 0)
			table.clear(mentorParts)
			table.clear(mentorCfs)
			local walking = u < 1
			Rigs.pose(mentor, feet, now * 7, if walking then 1 else 0, mentorParts, mentorCfs)
			workspace:BulkMoveTo(mentorParts, mentorCfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end

	---------------------------------------------------------------------------
	-- The chalk ghost ("Show me?"): one step of the level's solution, then it fades
	---------------------------------------------------------------------------
	local ghostParts: { BasePart } = {}
	local ghostCfs: { CFrame } = {}
	local dashPool: { BasePart } = {}

	local function stopGhost()
		local g = ghost
		ghost = nil
		if g then
			g.rig.model:Destroy()
		end
		for _, d in dashPool do
			d:Destroy()
		end
		table.clear(dashPool)
	end

	local function dash(): BasePart
		local d: BasePart
		if #dashPool >= O.GHOST_DASH_MAX then
			d = table.remove(dashPool, 1) :: BasePart
		else
			local p = Instance.new("Part")
			p.Name = "GhostDash"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = Palette.ghostChalk
			p.Size = Vector3.new(0.18, 0.05, O.GHOST_DASH_SPACING * 0.5)
			p.Parent = hintFolderOf()
			d = p
		end
		table.insert(dashPool, d)
		return d
	end

	local function startGhost()
		local level = state.level
		if ghost or not level then
			return
		end
		local slots, cap = deckSlots()
		local step = Help.nextStep(level, slots, cap)
		local buf = step and GhostTapes.buffer(level.id, step.run)
		local rec = buf and Codec.decode(buf)
		if not (step and rec) then
			return
		end
		local rig = Rigs.buildMannequin()
		Rigs.tint(rig, Palette.ghostChalk)
		Rigs.setFade(rig, O.GHOST_ALPHA)
		-- The chalk outline: a line box round every part (no reserved colour, never white).
		for _, p in Rigs.partsOf(rig) do
			local box = Instance.new("SelectionBox")
			box.Adornee = p
			box.Color3 = Palette.ghostChalk
			box.LineThickness = 0.05
			box.SurfaceTransparency = 1
			box.Parent = p
		end
		rig.model.Name = "EH_ChalkGhost"
		rig.model.Parent = hintFolderOf()
		local line = Strings.OBJ_WATCH_GHOST
		if step.redo then
			line = Strings.ghostRedo(step.redo)
			-- Between runs, the redo is armed for the kid (the deck shows REDO n; they can change it).
			local deck = state.deck
			if state.phase == "Between" and deck and not deck.locked and (tonumber(deck.redo) or 0) ~= step.redo then
				ctx.actions.deck("Redo", step.redo)
			end
		elseif step.full then
			line = Strings.DECK_FULL_HELP
		end
		-- First person: never start inside your camera (the walk starts where you stand after a rewind); begin
		-- from its first point GHOST_FP_AHEAD studs in front of your eyes, within the first GHOST_FP_SKIP_MAX s.
		local skip = 0
		local cam = workspace.CurrentCamera
		if state.fpView == true and cam then
			local origin: Vector3 = state.origin or Vector3.zero
			local eye, look = cam.CFrame.Position, cam.CFrame.LookVector
			local length = Sampler.duration(rec)
			local t = 0
			while t <= math.min(O.GHOST_FP_SKIP_MAX, length) do
				local x, y, z = Sampler.at(rec, t)
				if x and (origin + Vector3.new(x, y, z) - eye):Dot(look) >= O.GHOST_FP_AHEAD then
					skip = t
					break
				end
				t += 0.05
			end
		end
		ghost = {
			rig = rig,
			rec = rec,
			t0 = os.clock() - skip,
			length = Sampler.duration(rec),
			phase = 0,
			lastDash = nil :: Vector3?,
			line = line,
			fade = 0,
		}
		ctx.actions.hint("ghost")
	end

	local function updateGhost(now: number, dt: number)
		local g = ghost
		if not g then
			return
		end
		local t = now - g.t0
		local endAt = g.length + O.GHOST_HOLD_SECONDS
		if t > endAt + O.GHOST_FADE_SECONDS then
			stopGhost()
			return
		end
		local origin: Vector3 = state.origin or Vector3.zero
		local x, y, z, yaw = Sampler.at(g.rec, math.min(t, g.length))
		if not x then
			stopGhost()
			return
		end
		local vx, _, vz = Sampler.velocity(g.rec, math.min(t, g.length))
		local speed = math.sqrt(vx * vx + vz * vz)
		g.phase += speed * dt * 0.9
		local feet = CFrame.new(origin + Vector3.new(x, y - g.rig.rootHeight, z)) * CFrame.Angles(0, yaw, 0)
		table.clear(ghostParts)
		table.clear(ghostCfs)
		Rigs.pose(g.rig, feet, g.phase, if speed > 0.5 then 1 else 0, ghostParts, ghostCfs)
		workspace:BulkMoveTo(ghostParts, ghostCfs, Enum.BulkMoveMode.FireCFrameChanged)
		-- The dashed chalk trail: one dash every GHOST_DASH_SPACING studs it walks.
		local at = feet.Position + Vector3.new(0, 0.06, 0)
		local last = g.lastDash
		if not last then
			g.lastDash = at
		elseif (at - last).Magnitude >= O.GHOST_DASH_SPACING then
			local d = dash()
			d.CFrame = CFrame.lookAt((at + last) / 2, at)
			d.Transparency = 0.15
			g.lastDash = at
		end
		-- Hold at the end of the step, then fade out (figure, outline and trail together).
		if t > endAt then
			local k = math.clamp((t - endAt) / O.GHOST_FADE_SECONDS, 0, 1)
			Rigs.setFade(g.rig, O.GHOST_ALPHA + (1 - O.GHOST_ALPHA) * k)
			for _, p in Rigs.partsOf(g.rig) do
				local box = p:FindFirstChildOfClass("SelectionBox")
				if box then
					box.Transparency = k
				end
			end
			for _, d in dashPool do
				d.Transparency = 0.15 + 0.85 * k
			end
		end
	end

	---------------------------------------------------------------------------
	-- The help chip / Relaxed card (HudLayout.HELP_CHIP, top right)
	---------------------------------------------------------------------------
	local chip = Ui.button(ctx.runHud.Parent, {
		Name = "HelpChip",
		Visible = false,
		BackgroundColor3 = Palette.ghostChalk,
		TextColor3 = Palette.ink,
		TextSize = 20,
		TextWrapped = true,
		RichText = false,
		ZIndex = 5,
		Text = Strings.SHOW_ME,
	}, function()
		hints.onChip()
	end, "UIConfirm")
	Common.place(chip, HudLayout.HELP_CHIP)
	Ui.fit(chip, 20, 14)
	local chipMode = "" -- "showMe" | "relaxed" | ""

	local function isLeader(): boolean
		local folder = state.folder
		local leader = folder and folder:GetAttribute("Leader")
		return leader == nil or leader == localPlayer.UserId
	end

	function hints.onChip()
		if chipMode == "relaxed" then
			if not relaxedSent and type(state.levelIndex) == "number" then
				relaxedSent = true -- the server tracks RelaxedChosen when it restarts the heist
				ctx.actions.selectLevel(state.levelIndex, true)
			end
		elseif chipMode == "showMe" then
			startGhost()
		end
	end

	local function chipWanted(): string
		if state.where ~= "heist" or state.phase == "Over" then
			return ""
		end
		local deck = state.deck
		if state.phase == "Between" and deck and deck.relaxedOffer == true and not relaxedSent and isLeader() then
			return "relaxed"
		end
		if due.showMe and not ghost and (state.phase == "Between" or state.phase == "Run") then
			return "showMe"
		end
		return ""
	end

	local function updateChip()
		local want = chipWanted()
		if want ~= chipMode then
			chipMode = want
			if want == "relaxed" then
				chip.Text = Strings.TRY_RELAXED .. "\n" .. Strings.RELAXED_SUB
				chip.BackgroundColor3 = Palette.goldHi
			elseif want == "showMe" then
				chip.Text = Strings.SHOW_ME
				chip.BackgroundColor3 = Palette.ghostChalk
			end
		end
		Ui.setShown(chip, want ~= "")
	end

	---------------------------------------------------------------------------
	-- The finger pointer (§6.2): REWIND and GRAB, the first time each is the right move
	---------------------------------------------------------------------------
	local finger = Common.finger(ctx.root, O.POINTER_SIZE, 20)
	local fingerOn: GuiObject? = nil

	local function pointAt(target: GuiObject?, now: number)
		fingerOn = target
		-- First person on a keyboard: the prompt chip by the reticle (on the fx layer) has its own finger,
		-- pointing up at it from below so it never covers the reticle (Hud/Reticle.point).
		local fpChip = ctx.reticle ~= nil and target ~= nil and target == ctx.reticle.chip
		if ctx.reticle then
			ctx.reticle.point(fpChip, now)
		end
		if fpChip or not target or not target.Visible then
			finger.Visible = false
			return
		end
		-- In the HUD root's design space (the root carries the device UIScale).
		local s = ctx.root:FindFirstChildOfClass("UIScale")
		local k = if s and s.Scale > 0 then s.Scale else 1
		local p = (target.AbsolutePosition - ctx.root.AbsolutePosition) / k
		local h = target.AbsoluteSize.Y / k
		local tap = if state.reduced then 0 else (0.5 - 0.5 * math.cos(now * 2 * math.pi / O.POINTER_PERIOD))
		finger.Position = UDim2.fromOffset(p.X + 4 - O.POINTER_TRAVEL * (1 - tap), p.Y + h / 2)
		finger.Visible = true
	end

	---------------------------------------------------------------------------
	-- Run flow hooks (Hud/Run)
	---------------------------------------------------------------------------
	local function feedTracker()
		local run = state.run
		local n = run and tonumber(run.run) or 0
		local level = state.level
		if n <= countedRun or not level then
			return
		end
		countedRun = n
		local slots = deckSlots()
		Help.afterRun(tracker, {
			held = Help.deckPlates(level, slots),
			goalBanked = runFacts.goalBanked,
			banked = runFacts.banked,
			caught = runFacts.caught,
		})
		due = Help.due(tracker, level)
	end

	function hints.onRun(m: any, n: number)
		if n <= 1 then
			tracker = Help.newTracker()
			due = Help.due(tracker, state.level or { kind = "" })
			countedRun = 0
			relaxedSent = false
			stopGhost()
		else
			feedTracker() -- the previous run, if no deck arrived for it
		end
		runFacts = { goalBanked = false, banked = false, caught = false }
		runStart = os.clock() + (tonumber(m.transition) or 0)
		firstCloneUntil = 0
		gusIntroUntil = 0
		-- What this run's clones hold (any owner: crewmates' clones open doors too).
		local level = state.level
		local slots = {}
		local mine = false
		for _, a in m.actors or {} do
			if a.kind == "clone" then
				table.insert(slots, { rec = state.recs[a.key], status = "OK" })
				mine = mine or a.owner == localPlayer.UserId
			end
		end
		runDeckHeld = if level then Help.deckPlates(level, slots) else {}
		if mine and FirstTime.firstTime("clone") then
			firstCloneUntil = runStart + O.FIRST_CLONE_LINE_SECONDS
		end
		-- L1: your clone walks out of your own body ("YOU, 10 SEC AGO"); in first person the look cue points
		-- at it whenever it is out of view, until it has had time to reach the plate.
		cloneCueUntil = if mine and Common.isTutorial(state) then runStart + O.LOOK_CUE_SECONDS else 0
		if Common.isParty(state) and n <= 1 and level and #level.guards > 0 and FirstTime.firstTime("gusDoze") then
			gusIntroUntil = runStart + O.GUS_INTRO_SECONDS
		end
	end

	function hints.onDeck()
		if state.phase == "Between" then
			feedTracker()
		end
	end

	-- A failure (Help.CAUSE): its counterplay line, within ADVICE_DELAY s (premium G4).
	function hints.fail(cause: string)
		local level = state.level
		local line = Help.advice(cause, level and level.id)
		if line == Strings.FAIL_ADVICE.Timeout and state.fpView == true then
			line = Strings.FAIL_TIMEOUT_BY[Common.device()] or line -- REWIND is a key in first person
		end
		if line then
			task.delay(O.ADVICE_DELAY, function()
				hud.toast(line :: string)
			end)
		end
	end

	local function mine(a: any): boolean
		return a ~= nil and a.owner == localPlayer.UserId
	end

	-- Event-log entries (decoded): the first-time beats and the tracker's facts.
	function hints.onEvent(e: any, live: boolean)
		local run = state.run
		if not run then
			return
		end
		local a = run.actorById[e.a]
		if e.kind == EV.GoalMet then
			runFacts.goalBanked = true
		elseif e.kind == EV.Bank then
			runFacts.banked = true
			if live and mine(a) and FirstTime.firstTime("bank") then
				local def = state.level and state.level.loot[e.b]
				hud.bigStamp(
					Strings.firstBank(Ui.money(def and def.value or 0)),
					Palette.gold,
					O.FIRST_BANK_STAMP_SECONDS
				)
			end
		elseif e.kind == EV.Caught then
			if Common.myActor(run.actorById[e.b]) then
				runFacts.caught = true
			end
		elseif e.kind == EV.PlateDown then
			local presser = run.actorById[e.b]
			if live and Common.myActor(presser) and FirstTime.firstTime("plate") then
				hud.toast(Strings.FIRST_PLATE)
				Ui.pop(ctx.top.objective, O.FIRST_PLATE_POP)
			end
		elseif e.kind == EV.EndRun or e.kind == EV.AutoEnd then
			if Common.myActor(a) then
				FirstTime.markSeen("pointRewind")
				if live and FirstTime.firstTime("rewind") then
					Ui.pop(ctx.controls.endBtn, O.FIRST_REWIND_POP)
				end
			end
		elseif e.kind == EV.Grab then
			if Common.myActor(a) then
				FirstTime.markSeen("pointGrab")
			end
		end
	end

	-- The look cue (first person): the chalk ghost while it plays, else your L1 clone in its window.
	local lookCue = LookCue.build(ctx)
	local function updateLookCue(now: number)
		if state.fpView ~= true or state.phase ~= "Run" then
			lookCue.hide()
			return
		end
		if ghost then
			lookCue.set(Rigs.anchorPart(ghost.rig).Position, Strings.LOOK_CUE.ghost, now)
			return
		end
		if mentor then -- the L1 stuck hint's walk to the plate
			lookCue.set(Rigs.anchorPart(mentor).Position, Strings.LOOK_CUE.ghost, now)
			return
		end
		local own = ctx.actions.ownClone
		if now < cloneCueUntil and own then
			lookCue.set(own(), Strings.LOOK_CUE.clone, now)
			return
		end
		lookCue.hide()
	end

	-- Per frame (Hud/Run.update, after the objective line).
	function hints.update(now: number, dt: number)
		updateGhost(now, dt)
		updateLookCue(now)
		updateChip()
		if ctx.rewindRightMoveFromHelp ~= rewindRight then
			ctx.rewindRightMoveFromHelp = rewindRight
			hud.setRewindRightMove(rewindRight)
		end
		-- The finger: REWIND first (it is the signature verb), then GRAB.
		local controls = ctx.controls
		local wantRewind = (rewindRight or ctx.l1PulseEnd == true) and not FirstTime.seen("pointRewind")
		-- GRAB: the button (touch, and every non-first-person camera), or in first person on a keyboard or a
		-- gamepad the prompt chip by the reticle (Hud/Run.grabPointTarget).
		local grabTarget: GuiObject? = if ctx.grabPointTarget then ctx.grabPointTarget() else nil
		local wantGrab = not wantRewind and grabTarget ~= nil and not FirstTime.seen("pointGrab")
		local target: GuiObject? = nil
		if state.phase == "Run" then
			target = if wantRewind then controls.endBtn elseif wantGrab then grabTarget else nil
		end
		pointAt(target, now)
	end

	-- Off the run HUD (garage, cut-scenes): drop the chip, the finger and the ghost.
	function hints.hideHelp()
		stopGhost()
		lookCue.hide()
		chipMode = ""
		chip.Visible = false
		finger.Visible = false
		fingerOn = nil
	end

	-- For tests and the debug chip.
	function hints.state(): any
		return { tracker = tracker, due = due, ghost = ghost ~= nil, chip = chipMode, finger = fingerOn ~= nil }
	end

	-- A party's Dawn is the celebration; a story level's is OUT OF TIME with a tip (PLAN §5).
	function hints.onDawn()
		if Common.isParty(state) then
			hud.bigStamp(Strings.STAMP_SUNRISE, Palette.gold)
			hud.toast(Strings.SUNRISE_COUNT)
		else
			hud.bigStamp(Strings.STAMP_OUT_OF_TIME, Palette.amber)
			hints.fail(Help.CAUSE.Dawn)
		end
	end

	return hints
end

return Hints
