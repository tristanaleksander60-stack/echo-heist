--!strict
-- Heist/ScarfSway: the long scarf's tail sways with your movement (PLAN_FIRST_PERSON "CH"; Shared/Heist/ScarfMath,
-- numbers in Config.Rookie.SCARF). A cheap Lua secondary motion: the tail is two kit pieces
-- (Rookie_Scarf_Long_Tail1 / _Tail2) welded to the UpperTorso by Heist/Rookie (server) with their pivots at their
-- hinges; this module only rewrites those two welds' C0 on THIS client (nothing replicates, the server never sees
-- it). Your character and your clones' avatar rigs (EchoView.swayModels) are the candidates; the nearest
-- Budget.scarfRigs(tier) within RANGE of the camera sway each frame, the rest hold the modelled pose (it streams
-- out behind, the running pose). Tiers >= OFF_TIER: none (every tail back to the modelled pose, no work a frame).
-- A hidden character (first person, a faded clone) is skipped.
--
--   ScarfSway.new(deps) -> sway       deps.models: () -> { Model } (the candidates this frame)
--     sway.setTier(tier)
--     sway.step(dt, camPos)           RenderStepped calls it on a client; tests call it by hand
--     sway.count() -> number          tails swayed in the last step
--     sway.destroy()
--   ScarfSway.bind(model) -> rig?     the tail of one character (nil without a long scarf)
--   ScarfSway.pose(rig, p1, y1, p2, y2)  writes the two welds for these angles (degrees)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local Budget = require(HeistShared:WaitForChild("Budget"))
local ScarfMath = require(HeistShared:WaitForChild("ScarfMath"))

local S = Config.Rookie.SCARF

local ScarfSway = {}

export type Rig = {
	model: Model,
	root: BasePart,
	welds: { Weld },
	rest: { CFrame }, -- each weld's C0 as the server made it (the modelled pose)
	hinge: { CFrame }, -- each hinge in the host's CFrame space, axes = the torso's
	piece: BasePart,
	state: ScarfMath.State,
	lastPos: Vector3?,
	lastLook: Vector3?,
	posed: boolean, -- the welds hold a swayed pose (false = the rest pose)
}

local function weldOf(piece: Instance?): (BasePart?, Weld?)
	if not piece or not piece:IsA("BasePart") then
		return nil, nil
	end
	for _, d in piece:GetChildren() do
		if d:IsA("Weld") and d.Part1 == piece and d.Part0 then
			return piece, d
		end
	end
	return nil, nil
end

-- The tail of one character: both pieces welded to the same host, or nil.
function ScarfSway.bind(model: Model): Rig?
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local welds, rest, hinge = {}, {}, {}
	local first: BasePart? = nil
	local host: BasePart? = nil
	for i, name in S.PIECES do
		local piece, w = weldOf(model:FindFirstChild(name))
		if not piece or not w or (host and w.Part0 ~= host) then
			return nil
		end
		host = w.Part0
		first = first or piece
		welds[i] = w
		rest[i] = w.C0
		-- the piece's pivot (its hinge) in the host's CFrame space; axes = the host's pivot (the torso's)
		local pivot = w.C0 * w.C1:Inverse() * piece.PivotOffset
		local axes = (host :: BasePart).PivotOffset.Rotation
		hinge[i] = CFrame.new(pivot.Position) * axes
	end
	if not first then
		return nil
	end
	return {
		model = model,
		root = root,
		welds = welds,
		rest = rest,
		hinge = hinge,
		piece = first,
		state = ScarfMath.new(),
		lastPos = nil,
		lastLook = nil,
		posed = false,
	}
end

local function bend(h: CFrame, pitch: number, yaw: number): CFrame
	return h * CFrame.fromEulerAnglesYXZ(math.rad(pitch), math.rad(yaw), 0) * h:Inverse()
end

-- Writes the welds for these angles (degrees; 0, 0, 0, 0 = the modelled pose).
function ScarfSway.pose(rig: Rig, p1: number, y1: number, p2: number, y2: number)
	local t1 = bend(rig.hinge[1], p1, y1)
	rig.welds[1].C0 = t1 * rig.rest[1]
	if rig.welds[2] then
		rig.welds[2].C0 = t1 * bend(rig.hinge[2], p2, y2) * rig.rest[2]
	end
	rig.posed = true
end

local function restPose(rig: Rig)
	if rig.posed then
		for i, w in rig.welds do
			if w.Parent then
				w.C0 = rig.rest[i]
			end
		end
		rig.posed = false
	end
	ScarfMath.rest(rig.state)
	rig.lastPos, rig.lastLook = nil, nil
end

function ScarfSway.new(deps: any): any
	local sway = {}
	local rigs: { [Model]: Rig | false } = setmetatable({}, { __mode = "k" }) :: any
	local live: { Rig } = {}
	local tier = 1
	local swayed = 0
	local conn: RBXScriptConnection? = nil
	local cands: { { rig: Rig, dist: number } } = {}

	local function rigOf(m: Model): Rig?
		local r = rigs[m]
		-- first sight, or the outfit changed (the pieces were rebuilt): bind again
		if r == nil or (r and (r.piece.Parent ~= m or r.welds[1].Parent == nil)) then
			r = ScarfSway.bind(m) or false
			rigs[m] = r
		end
		return if r then r else nil
	end

	local function stopAll()
		for _, r in live do
			restPose(r)
		end
		table.clear(live)
	end

	function sway.setTier(t: number)
		tier = t
		if Budget.scarfRigs(tier) <= 0 then
			stopAll()
		end
	end

	function sway.step(dt: number, camPos: Vector3?)
		swayed = 0
		local budget = Budget.scarfRigs(tier)
		if budget <= 0 or dt <= 0 then
			return
		end
		local cam = camPos
		if cam == nil then
			local c = workspace.CurrentCamera
			cam = if c then c.CFrame.Position else Vector3.zero
		end
		table.clear(cands)
		for _, m in deps.models() do
			local r = rigOf(m)
			if r and r.piece.LocalTransparencyModifier < 0.99 and r.piece.Transparency < 1 then
				local d = (r.root.Position - (cam :: Vector3)).Magnitude
				if d <= S.RANGE then
					table.insert(cands, { rig = r, dist = d })
				end
			end
		end
		table.sort(cands, function(a, b)
			return a.dist < b.dist
		end)
		local keep: { [Rig]: boolean } = {}
		for i = 1, math.min(budget, #cands) do
			keep[cands[i].rig] = true
		end
		-- tails that dropped out of the budget go back to the modelled pose
		for i = #live, 1, -1 do
			local r = live[i]
			if not keep[r] then
				restPose(r)
				table.remove(live, i)
			end
		end
		for r in keep do
			if not table.find(live, r) then
				table.insert(live, r)
			end
			local cf = r.root.CFrame
			local pos, look = cf.Position, cf.LookVector
			local motion: ScarfMath.Motion = { forward = 0, right = 0, up = 0, turn = 0 }
			if r.lastPos and r.lastLook then
				local v = cf:VectorToObjectSpace((pos - (r.lastPos :: Vector3)) / dt)
				if v.Magnitude < 120 then -- a teleport is not a speed
					motion.forward, motion.right, motion.up = -v.Z, v.X, v.Y
				end
				local cross = (r.lastLook :: Vector3):Cross(look).Y
				motion.turn = math.asin(math.clamp(cross, -1, 1)) / dt
				ScarfMath.step(r.state, motion, dt, S)
			else
				r.state = ScarfMath.settled(motion, S)
			end
			r.lastPos, r.lastLook = pos, look
			local st = r.state
			ScarfSway.pose(r, st.p1, st.y1, st.p2, st.y2)
			swayed += 1
		end
	end

	function sway.count(): number
		return swayed
	end

	function sway.destroy()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		stopAll()
	end

	if RunService:IsClient() and deps.autoStep ~= false then
		conn = RunService.RenderStepped:Connect(function(dt: number)
			sway.step(math.min(dt, 0.25))
		end)
	end
	return sway
end

return ScarfSway
