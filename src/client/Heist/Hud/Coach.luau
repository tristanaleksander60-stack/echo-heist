--!strict
-- Hud/Coach: the run coach's picture (RUN2 CLARITY track; the rules are pure in Shared/Heist/RunCoach, and the sim's
-- coached kid obeys the same rules). On a coached level (L1, the mandatory tutorial, and L2):
--   * the coach card (HudLayout.COACH_CARD): one big line while the run's transition holds you: run 1 its plan
--     ("Step on the plate" / "Stand on plate A. Then REWIND."), runs 2-3 the beat on your newest clone ("Clone holds
--     the plate!", "That run missed the plate."); control hides it, the objective line carries on (Hud/Hints);
--   * the beat's camera focus: where your newest clone's walk ends (HeistClient hands it to CameraDirector's run-start
--     beat, so the camera holds on it, then eases into your eyes); "YOU, 10 SEC AGO" over the clone is EchoView's;
--   * the clone's path: dashes in its colour along its recording and a ring where it stops, from the beat until
--     it has stopped (Config.Onboarding.COACH.PATH_*), so you see where it will go before it goes;
--   * one world arrow (a chevron in Palette.exit) over YOUR next target: the plate, the door, the goal loot, the van.
--     None while REWIND is the move (the finger points at REWIND then): one pointer at a time.
-- Everything lives in workspace.EH_Coach (client only; no remote, no server state).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Sampler = require(Shared:WaitForChild("Rec"):WaitForChild("Sampler"))
local HeistShared = Shared:WaitForChild("Heist")
local Help = require(HeistShared:WaitForChild("Help"))
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local RunCoach = require(HeistShared:WaitForChild("RunCoach"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Theme = require(script.Parent.Parent:WaitForChild("Theme"))
local Common = require(script.Parent:WaitForChild("Common"))

local C = Config.Onboarding.COACH
local H = Config.Heist

local Coach = {}

function Coach.build(ctx: any): any
	local state = ctx.state
	local coach = {}

	---------------------------------------------------------------------------
	-- The card
	---------------------------------------------------------------------------
	local card = Ui.label(ctx.runHud, {
		Name = "CoachCard",
		Text = "",
		Visible = false,
		TextColor3 = Palette.white,
		ZIndex = 4,
	})
	card.BackgroundColor3 = Palette.ink
	card.BackgroundTransparency = 0.15
	Common.place(card, HudLayout.COACH_CARD)
	Ui.fit(card, C.CARD_TEXT, H.UI_TEXT_MIN)
	Ui.pill(card)
	Ui.stroke(card, Palette.goldHi, Theme.STROKE)
	local cardUntil = 0 -- os.clock(): control (the card goes)
	local cardLine: RunCoach.Line? = nil

	---------------------------------------------------------------------------
	-- World pieces (workspace.EH_Coach)
	---------------------------------------------------------------------------
	local folder: Folder? = nil
	local function folderOf(): Folder
		local f = folder
		if f and f.Parent then
			return f
		end
		local nf = Instance.new("Folder")
		nf.Name = "EH_Coach"
		nf.Parent = workspace
		folder = nf
		return nf
	end

	local function part(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Parent = folderOf()
		return p
	end

	-- The arrow: a downward chevron (two arms) and its shaft, turned to face the camera.
	local arrow: { BasePart }? = nil
	local arrowTarget: RunCoach.Target? = nil
	local function arrowParts(): { BasePart }
		local a = arrow
		if a and a[1].Parent then
			return a
		end
		local w = 0.42
		local s = C.ARROW_SIZE
		local made = {
			part("ArrowL", Vector3.new(w, s, w), Palette.exit),
			part("ArrowR", Vector3.new(w, s, w), Palette.exit),
			part("ArrowShaft", Vector3.new(w, s * 1.3, w), Palette.exit),
		}
		arrow = made
		return made
	end
	local function hideArrow()
		local a = arrow
		if a then
			for _, p in a do
				p:Destroy()
			end
			arrow = nil
		end
		arrowTarget = nil
	end

	-- The clone's path: dashes + an end ring, until `pathUntil`.
	local pathParts: { BasePart } = {}
	local pathUntil = 0
	local function clearPath()
		for _, p in pathParts do
			p:Destroy()
		end
		table.clear(pathParts)
		pathUntil = 0
	end
	local function drawPath(rec: any, hue: Color3, untilAt: number)
		clearPath()
		local origin: Vector3 = state.origin or Vector3.zero
		local floor = (state.level and state.level.floorY or 0) + 0.08
		local length = Sampler.duration(rec)
		local last: Vector3? = nil
		local t = 0
		while t <= length and #pathParts < C.PATH_DASH_MAX do
			local x, _, z = Sampler.at(rec, t)
			if x then
				local at = origin + Vector3.new(x, floor, z)
				if not last then
					last = at
				elseif (at - (last :: Vector3)).Magnitude >= C.PATH_DASH_SPACING then
					local d = part("PathDash", Vector3.new(0.22, 0.06, C.PATH_DASH_SPACING * 0.55), hue)
					d.CFrame = CFrame.lookAt(((last :: Vector3) + at) / 2, at)
					d.Transparency = 0.1
					table.insert(pathParts, d)
					last = at
				end
			end
			t += 0.05
		end
		local x, _, z = Sampler.at(rec, length)
		if x then
			local ring =
				part("PathEnd", Vector3.new(0.06, C.PATH_RING_SIZE, C.PATH_RING_SIZE), hue, Enum.PartType.Cylinder)
			ring.CFrame = CFrame.new(origin + Vector3.new(x, floor, z)) * CFrame.Angles(0, 0, math.pi / 2)
			ring.Transparency = 0.35
			table.insert(pathParts, ring)
		end
		pathUntil = untilAt
	end

	---------------------------------------------------------------------------
	-- Run flow
	---------------------------------------------------------------------------
	local focus: Vector3? = nil -- level space: the camera's beat focus

	function coach.active(): boolean
		return RunCoach.coached(state.level)
	end

	-- A run starts (Hud/Hints.onRun, after its clone plates are known). `held` = the plates every clone of this run
	-- ends on (Help.deckPlates); `myId` the local player's UserId.
	function coach.onRun(m: any, held: { [number]: any }, myId: number)
		coach.clear()
		focus = nil
		local level = state.level
		if not RunCoach.coached(level) then
			return
		end
		-- Your newest clone: the one recorded last (its `run`), and the plates the others hold.
		local newest: any = nil
		for _, a in m.actors or {} do
			if a.kind == "clone" and a.owner == myId and not a.helper and state.recs[a.key] then
				if not newest or (tonumber(a.run) or 0) > (tonumber(newest.run) or 0) then
					newest = a
				end
			end
		end
		local beat: RunCoach.Line? = nil
		local transition = tonumber(m.transition) or 0
		local beatSeconds = tonumber(m.beat) or 0
		local now = os.clock()
		cardUntil = now + transition
		if newest and beatSeconds > 0 then
			local rec = state.recs[newest.key]
			local others = {}
			for _, a in m.actors or {} do
				if a.kind == "clone" and a ~= newest and state.recs[a.key] then
					table.insert(others, { rec = state.recs[a.key], status = "OK" })
				end
			end
			local plate = Help.endPlate(level, rec)
			beat = RunCoach.beat(level, { plate = plate }, Help.deckPlates(level, others))
			-- The camera holds on where it goes (3/5 of the way from its start to its stop: both in the frame).
			local x0, y0, z0 = Sampler.at(rec, 0)
			local x1, y1, z1 = Sampler.at(rec, Sampler.duration(rec))
			if x0 and x1 then
				local k = 0.6
				focus = Vector3.new(x0 + (x1 - x0) * k, y0 + (y1 - y0) * k, z0 + (z1 - z0) * k)
			end
			local walk = math.min(Sampler.duration(rec), C.PATH_MAX_SECONDS)
			drawPath(rec, Palette.hueFor(newest.seat or state.mySeat or 1), cardUntil + walk + C.PATH_HOLD_SECONDS)
		end
		cardLine = RunCoach.card(level, beat, { carrying = false, held = held, doorOpen = {} })
		card.Text = Strings.coachLine(cardLine, Common.device(), state.fpView == true)
		Ui.setShown(card, transition > 0)
		ctx.coachCardUp = transition > 0
	end

	-- The beat's camera focus (level space) for this run, or nil (the default run-start framing).
	function coach.focus(): Vector3?
		return focus
	end

	-- The world arrow's target this frame (nil: no arrow).
	function coach.point(target: RunCoach.Target?)
		if not target then
			hideArrow()
			return
		end
		arrowTarget = target
	end

	function coach.update(now: number)
		if ctx.coachCardUp and now >= cardUntil then
			ctx.coachCardUp = false
			Ui.setShown(card, false)
		end
		if pathUntil > 0 and now >= pathUntil then
			clearPath()
		end
		local level = state.level
		local t = arrowTarget
		local cam = workspace.CurrentCamera
		if not (t and level and cam) or state.phase ~= "Run" or now < cardUntil then
			if arrow then
				for _, p in arrow do
					p.Transparency = 1
				end
			end
			return
		end
		local x, y, z = RunCoach.targetPos(level, t)
		local origin: Vector3 = state.origin or Vector3.zero
		local floor = level.floorY or 0
		local base = math.max(y, floor) + C.ARROW_HEIGHT
		local bob = if state.reduced then 0 else C.ARROW_BOB * math.sin(now * 2 * math.pi * C.ARROW_BOB_HZ)
		local tip = origin + Vector3.new(x, base + bob, z)
		local to = cam.CFrame.Position - tip
		local yaw = math.atan2(to.X, to.Z)
		local face = CFrame.new(tip) * CFrame.Angles(0, yaw, 0)
		local s = C.ARROW_SIZE
		local parts = arrowParts()
		parts[1].CFrame = face * CFrame.Angles(0, 0, math.rad(40)) * CFrame.new(0, s / 2, 0)
		parts[2].CFrame = face * CFrame.Angles(0, 0, math.rad(-40)) * CFrame.new(0, s / 2, 0)
		parts[3].CFrame = face * CFrame.new(0, s * 0.65, 0)
		for _, p in parts do
			p.Transparency = 0
		end
	end

	-- Off the run (run end, garage, cut-scenes): the card, the path and the arrow go.
	function coach.clear()
		clearPath()
		hideArrow()
		ctx.coachCardUp = false
		card.Visible = false
	end

	-- For tests and the debug chip.
	function coach.state(): any
		return {
			card = if card.Visible then card.Text else nil,
			arrow = if arrowTarget then arrowTarget.kind else nil,
			path = #pathParts,
			focus = focus,
		}
	end

	return coach
end

return Coach
