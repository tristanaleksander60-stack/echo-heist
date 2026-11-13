--!strict
-- Heist/LookTarget: look-to-interact in first person (PLAN_FIRST_PERSON FP). Every frame of a run, while the
-- camera is at your eyes (state.fpView), a ray from the camera centre plus a small aim-assist cone (widest on
-- touch: Config.FirstPerson.LOOK.ASSIST) picks the looked-at interactable within reach (FpMath.pick, pure and
-- deterministic): loot at home or dropped (GRAB, or LOCKED 0:07 for the till before its time), a switch (OPEN
-- when it opens a door, else PRESS) and, while you carry, the van (BANK: walk in, banking stays positional).
-- The target gets one outline (a single Highlight, depth-occluded, re-pointed, never one per item: budgeted)
-- and the HUD shows its prompt chip (Hud/Reticle).
--
-- Nothing here decides anything. The client sends the EXISTING Heist.Interact(kind, index) with the target it
-- looked at (Codec.EVENT Grab / Press + the LevelSpec index); the server's validator and Sim/Interact
-- re-check range from your sim position, the item's state, the cooldown and the time lock, and record the
-- event so clones replay it. To never offer what the server refuses, a target must also pass the sim's own
-- range rule from your root (FpMath.inSimRange, less LOOK.RANGE_MARGIN), and nothing solid may stand between
-- your eyes and it (raycasts for the best few candidates only: no grabbing through walls).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local FpMath = require(script.Parent:WaitForChild("FpMath"))

local LK = Config.FirstPerson.LOOK
local SIM = Config.Sim

local LookTarget = {}

export type Target = {
	kind: string, -- "loot" | "switch" | "van"
	index: number,
	part: BasePart,
	verb: string, -- "grab" | "locked" | "open" | "press" | "bank"
	value: number?,
	opensAt: number?,
}

local function t3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

-- Does switch `i` of a compiled level open a door? (OPEN rather than PRESS.)
function LookTarget.switchOpensDoor(level: any, i: number): boolean
	for _, d in (level and level.doors) or {} do
		for _, src in d.openBy or {} do
			if src.kind == "switch" and src.index == i then
				return true
			end
		end
	end
	return false
end

-- The candidate list for FpMath.pick from WorldView.lookables entries. `root`: your character's root (world),
-- for the sim's range rule; `carrying` / `bagFull` / `tView` decide what is on offer.
function LookTarget.candidates(entries: { any }, root: Vector3, ctx: any): { FpMath.Candidate }
	local out: { FpMath.Candidate } = {}
	for _, e in entries do
		local part: BasePart = e.part
		local pos = part.Position
		local ok = true
		local radius = LK.RADIUS[e.kind] or 1
		if e.kind == "loot" then
			ok = not ctx.bagFull
			radius = math.max(radius, math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2)
		elseif e.kind == "van" then
			ok = ctx.carrying == true
			radius = math.max(radius, math.min(part.Size.X, part.Size.Z) / 2)
		end
		if ok and e.kind ~= "van" then
			ok = FpMath.inSimRange(t3(root), t3(pos), SIM.INTERACT_RANGE, SIM.INTERACT_HEIGHT, LK.RANGE_MARGIN)
		end
		table.insert(out, { id = e.kind .. ":" .. tostring(e.index), pos = t3(pos), radius = radius, ok = ok })
	end
	return out
end

-- Can the eye see `part` (centre `to`, radius `radius`)? A workspace ray, excluding `exclude` (your character,
-- the camera's viewmodel): clear when it reaches the part, or hits within radius + LOS_SLACK of its centre
-- (its own counter top, its glow). See-through parts that do not collide (zones, glows) are looked through,
-- up to three; anything else in the way blocks. The engine test runs this on the built L1 (client_engine J).
function LookTarget.lineOfSight(
	from: Vector3,
	to: Vector3,
	radius: number,
	part: BasePart,
	exclude: { Instance },
	params: RaycastParams?
): boolean
	local p = params or RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local excl = table.clone(exclude)
	local at = from
	for _ = 1, 4 do
		p.FilterDescendantsInstances = excl
		local hit = workspace:Raycast(at, to - at, p)
		if not hit then
			return true
		end
		local inst = hit.Instance
		if inst == part or inst:IsDescendantOf(part) or part:IsDescendantOf(inst) then
			return true
		end
		if (hit.Position - to).Magnitude <= radius + LK.LOS_SLACK then
			return true -- the target's own surface (its pad, its glow)
		end
		if inst:IsA("BasePart") and inst.Transparency >= 0.95 and not inst.CanCollide then
			table.insert(excl, inst) -- a zone or a glow: look through it
			at = hit.Position
		else
			return false
		end
	end
	return false
end

-- deps: world (Heist/WorldView), isTouch () -> boolean, usingGamepad () -> boolean.
function LookTarget.new(state: any, deps: any): any
	local look = {}
	local player = Players.LocalPlayer
	local entries: { any } = {}
	local current: Target? = nil
	local currentId: string? = nil
	local highlight: Highlight? = nil
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local function hl(): Highlight
		local h = highlight
		if h and h.Parent then
			return h
		end
		local made = Instance.new("Highlight")
		made.Name = "EH_LookTarget"
		made.DepthMode = Enum.HighlightDepthMode.Occluded
		made.FillTransparency = LK.HIGHLIGHT.FILL
		made.OutlineTransparency = LK.HIGHLIGHT.OUTLINE
		made.Enabled = false
		made.Parent = workspace.CurrentCamera
		highlight = made
		return made
	end

	local function showOutline(t: Target?)
		local h = highlight
		if not t then
			if h then
				h.Enabled = false
				h.Adornee = nil
			end
			return
		end
		local made = hl()
		local key = if t.verb == "locked" then LK.HIGHLIGHT.LOCKED else LK.HIGHLIGHT.COLOUR
		local c = (Palette :: any)[key] or Palette.gold
		made.OutlineColor = c
		made.FillColor = c
		if made.Adornee ~= t.part then
			made.Adornee = t.part
		end
		made.Enabled = true
	end

	local function assist(): number
		if deps.usingGamepad and deps.usingGamepad() then
			return LK.ASSIST.gamepad
		elseif deps.isTouch and deps.isTouch() then
			return LK.ASSIST.touch
		end
		return LK.ASSIST.mouse
	end

	local function blocked(eye: { number }, c: FpMath.Candidate, part: BasePart): boolean
		local excl: { Instance } = { workspace.CurrentCamera :: Instance }
		local char = player and player.Character
		if char then
			table.insert(excl, char)
		end
		local from = Vector3.new(eye[1], eye[2], eye[3])
		local to = Vector3.new(c.pos[1], c.pos[2], c.pos[3])
		return not LookTarget.lineOfSight(from, to, c.radius, part, excl, params)
	end

	-- Picks this frame's target (or none) at loop time tView; allowed = false (your run ended, the run has
	-- not started) clears it. Returns it.
	function look.update(tView: number, allowed: boolean): Target?
		local cam = workspace.CurrentCamera
		local char = player and player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local w = deps.world
		local active = allowed
			and state.fpView == true
			and state.where == "heist"
			and state.phase == "Run"
			and cam ~= nil
			and root ~= nil
			and root:IsA("BasePart")
			and w ~= nil
		if not active or not cam or not root or not root:IsA("BasePart") then
			current, currentId = nil, nil
			showOutline(nil)
			return nil
		end
		w.lookables(entries)
		local list = LookTarget.candidates(entries, root.Position, {
			carrying = state.carrying == true,
			bagFull = (state.carryCount or 0) >= (state.myCapacity or 1),
		})
		local eye = t3(cam.CFrame.Position)
		local dir = t3(cam.CFrame.LookVector)
		local reachFor = function(c: FpMath.Candidate): boolean
			return string.sub(tostring(c.id), 1, 4) == "van:"
		end
		-- The van has its own (longer) reach: pick it separately, loot and switches first.
		local near, far = {}, {}
		local nearAt, farAt = {}, {}
		for i, c in list do
			if reachFor(c) then
				table.insert(far, c)
				table.insert(farAt, i)
			else
				table.insert(near, c)
				table.insert(nearAt, i)
			end
		end
		local function pickFrom(sub: { FpMath.Candidate }, at: { number }, reach: number): number?
			local k = FpMath.pick(eye, dir, sub, {
				reach = reach,
				assist = assist(),
				distanceWeight = LK.DISTANCE_WEIGHT,
				sticky = LK.STICKY,
				current = currentId,
				losCandidates = LK.LOS_CANDIDATES,
				blocked = function(e: { number }, c: FpMath.Candidate): boolean
					local idx = table.find(sub, c)
					return blocked(e, c, entries[at[idx :: number]].part)
				end,
			})
			return if k then at[k] else nil
		end
		local i = pickFrom(near, nearAt, LK.REACH) or pickFrom(far, farAt, LK.BANK_REACH)
		if not i then
			current, currentId = nil, nil
			showOutline(nil)
			return nil
		end
		local e = entries[i]
		local verb = "grab"
		if e.kind == "loot" then
			local opensAt = e.opensAt
			verb = if opensAt and tView < opensAt then "locked" else "grab"
		elseif e.kind == "switch" then
			verb = if LookTarget.switchOpensDoor(state.level, e.index) then "open" else "press"
		elseif e.kind == "van" then
			verb = "bank"
		end
		current = {
			kind = e.kind,
			index = e.index,
			part = e.part,
			verb = verb,
			value = e.value,
			opensAt = e.opensAt,
		}
		currentId = list[i].id
		showOutline(current)
		return current
	end

	function look.current(): Target?
		return current
	end

	function look.clear()
		current, currentId = nil, nil
		showOutline(nil)
	end

	return look
end

return LookTarget
