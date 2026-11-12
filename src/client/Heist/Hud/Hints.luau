--!strict
-- Hud/Hints: what to do next. The objective line (≤ 8 words, shown when it changes or
-- when stuck, §7.4), the L1 FTUE lines from the world state (§7.5: a kid who ended run 1
-- off the plate is led back to it), and the L1 stuck hints in the world: the plate
-- re-pulses, then a beam from your feet, then the Mentor ghost does the step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HeistShared = Shared:WaitForChild("Heist")
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Rigs = require(script.Parent.Parent:WaitForChild("Rigs"))
local Common = require(script.Parent:WaitForChild("Common"))

local localPlayer = Players.LocalPlayer

local Hints = {}

function Hints.build(ctx: any): any
	local state = ctx.state
	local hints = {}

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

	-- Is the L1 auto-end armed this run (run 1, or later until a clone stood on the plate)?
	function hints.autoEndArmed(): boolean
		local folder = state.folder
		return folder ~= nil and folder:GetAttribute("AutoEndArmed") == true
	end

	-- L1 FTUE lines and the generic objective. Returns the line, whether REWIND should
	-- pulse, and whether the line stays up (else it shows for OBJECTIVE_SECONDS after it
	-- changes, §7.4).
	function hints.objectiveText(_tView: number, pos: Vector3?): (string, boolean, boolean)
		local run = state.run
		local runIndex = if run then run.run else 1
		local carrying = state.carrying == true
		if Common.isTutorial(state) then
			if hints.autoEndArmed() then
				local on = pos ~= nil and onPlate(pos, 1)
				if on then
					return Strings.OBJ_STAY_ON_PLATE, true, true
				end
				return Strings.OBJ_STEP_ON_PLATE, false, true
			end
			if os.clock() < ctx.stopsLineUntil then
				return Strings.OBJ_CLONE_STOPS, false, true
			end
			local folder = state.folder
			local plateHeld = folder ~= nil and folder:GetAttribute("P1Held") == true
			if not plateHeld and not carrying then
				return Strings.OBJ_WAIT_FOR_CLONE, false, true
			end
			return if carrying then Strings.OBJ_BANK_IT else Strings.OBJ_GRAB_CASH, false, true
		end
		if carrying then
			return Strings.OBJ_BANK_IT, false, false
		end
		local id = state.level and state.level.id
		local line = id and Strings.LEVEL_LINES[id]
		if line and (runIndex == 1 or ctx.noBankRuns >= Common.LEVEL_LINE_STUCK_RUNS) then
			return line, false, false
		end
		return Strings.OBJ_GRAB_LOOT, false, false
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
		-- 3: the Mentor ghost walks from your spawn to the plate and stands on it
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
			local from = origin + Vector3.new(sp.x, state.level.floorY, sp.z)
			local to = Vector3.new(plate.Position.X, from.Y, plate.Position.Z)
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

	return hints
end

return Hints
