-- Recording and replaying "echoes": every loop, each player's movement and
-- actions are recorded; on the next loops those recordings are replayed by
-- ghost copies of the player's avatar. When a recording ends, the echo holds
-- its final position (so "stand on the plate, then rewind" works).

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Actors = require(script.Parent:WaitForChild("Actors"))

local Echoes = {}

type Frame = { t: number, pos: Vector3, yaw: number }
type Event = { t: number, kind: string, data: string? }
type Recording = { frames: { Frame }, events: { Event } }
type Replay = {
	actor: any,
	rec: Recording,
	frameIdx: number,
	eventIdx: number,
	track: AnimationTrack?,
	lastPos: Vector3,
}

local recordings: { [Player]: { Recording } } = {}
local current: { [Player]: Recording } = {}
local templates: { [Player]: Model } = {}
local replays: { Replay } = {}
local echoFolder: Folder
local walkAnim: Animation

-- Set by the coordinator: an echo reached a recorded event (grab, vanish, ...).
Echoes.onEvent = nil :: ((actor: any, event: Event) -> ())?

function Echoes.init()
	echoFolder = Instance.new("Folder")
	echoFolder.Name = "Echoes"
	echoFolder.Parent = workspace
	walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = Config.ECHO_WALK_ANIM
end

-- Build (once per player) the ghost template from their avatar.
function Echoes.prepareTemplate(player: Player)
	if templates[player] then
		return
	end
	local desc: HumanoidDescription
	local ok, result = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(math.max(player.UserId, 1))
	end)
	if ok and result then
		desc = result
	else
		desc = Instance.new("HumanoidDescription")
	end
	local ok2, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok2 or not rig then
		warn("[Echoes] could not build template for", player.Name, rig)
		return
	end
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			d.CastShadow = false
			if d.Name ~= "HumanoidRootPart" then
				d.Transparency = math.max(d.Transparency, 0.3)
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.EvaluateStateMachine = false
		hum.BreakJointsOnDeath = false
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.Transparency = 1
	end
	if not player.Parent then
		rig:Destroy() -- left while the avatar was loading
		return
	end
	templates[player] = rig
end

function Echoes.count(player: Player): number
	local list = recordings[player]
	return list and #list or 0
end

function Echoes.startRecording(player: Player)
	current[player] = { frames = {}, events = {} }
end

function Echoes.recordFrame(player: Player, t: number, cf: CFrame)
	local rec = current[player]
	if not rec then
		return
	end
	local _, yaw, _ = cf:ToEulerAnglesYXZ()
	table.insert(rec.frames, { t = t, pos = cf.Position, yaw = yaw })
end

function Echoes.recordEvent(player: Player, t: number, kind: string, data: string?)
	local rec = current[player]
	if rec then
		table.insert(rec.events, { t = t, kind = kind, data = data })
	end
end

-- End of loop: keep the recording. At the per-player cap the newest run
-- replaces the LAST slot, so early echoes (the one holding the vault plate)
-- stay stable while you keep retrying the final part of the plan.
function Echoes.finishRecording(player: Player)
	local rec = current[player]
	current[player] = nil
	if not rec or #rec.frames < 2 then
		return
	end
	local list = recordings[player] or {}
	if #list >= Config.MAX_ECHOES_PER_PLAYER then
		list[#list] = rec
	else
		table.insert(list, rec)
	end
	recordings[player] = list
end

local function makeEcho(owner: Player, index: number): (Model?, BasePart?)
	local template = templates[owner]
	if not template then
		return nil, nil
	end
	local m = template:Clone()
	m.Name = string.format("Echo_%s_%d", owner.Name, index)
	local root = m:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		m:Destroy()
		return nil, nil
	end

	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(80, 200, 255)
	hl.OutlineColor = Color3.fromRGB(170, 240, 255)
	hl.FillTransparency = 0.55
	hl.OutlineTransparency = 0.1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(120, 28)
	tag.StudsOffset = Vector3.new(0, 3.2, 0)
	tag.MaxDistance = 60
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(170, 240, 255)
	text.TextStrokeTransparency = 0.4
	text.Text = "ECHO " .. index
	text.Parent = tag
	tag.Parent = root

	m.Parent = echoFolder
	return m, root
end

-- Start of loop: spawn one echo per stored recording.
function Echoes.spawnAll()
	table.clear(replays)
	local total = 0
	for _, player in Players:GetPlayers() do
		local list = recordings[player]
		if list then
			for i, rec in list do
				if total >= Config.MAX_ECHOES_TOTAL then
					break
				end
				local model, root = makeEcho(player, i)
				if model and root then
					total += 1
					local first = rec.frames[1]
					root.CFrame = CFrame.new(first.pos) * CFrame.Angles(0, first.yaw, 0)
					local actor = Actors.addEcho(player, model, root, i)
					local track: AnimationTrack? = nil
					local hum = model:FindFirstChildOfClass("Humanoid")
					if hum then
						local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
						animator.Parent = hum
						local okLoad, loaded = pcall(function()
							return animator:LoadAnimation(walkAnim)
						end)
						if okLoad then
							track = loaded
							loaded.Looped = true
						end
					end
					table.insert(replays, {
						actor = actor,
						rec = rec,
						frameIdx = 1,
						eventIdx = 1,
						track = track,
						lastPos = first.pos,
					})
				end
			end
		end
	end
	return total
end

local function lerpAngle(a: number, b: number, alpha: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * alpha
end

-- Every frame: move echoes along their recordings and fire due events.
function Echoes.step(t: number, dt: number)
	for _, r in replays do
		local actor = r.actor
		if actor.alive then
			local frames = r.rec.frames
			while r.frameIdx < #frames and frames[r.frameIdx + 1].t <= t do
				r.frameIdx += 1
			end
			local a = frames[r.frameIdx]
			local b = frames[math.min(r.frameIdx + 1, #frames)]
			local alpha = 0
			if b.t > a.t then
				alpha = math.clamp((t - a.t) / (b.t - a.t), 0, 1)
			end
			local pos = a.pos:Lerp(b.pos, alpha)
			local yaw = lerpAngle(a.yaw, b.yaw, alpha)
			actor.root.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)

			if r.track and dt > 0 then
				local flat = (pos - r.lastPos) * Vector3.new(1, 0, 1)
				local moving = flat.Magnitude / dt > Config.ECHO_WALK_SPEED_THRESHOLD
				if moving and not r.track.IsPlaying then
					r.track:Play(0.15)
				elseif not moving and r.track.IsPlaying then
					r.track:Stop(0.2)
				end
			end
			r.lastPos = pos

			local events = r.rec.events
			while r.eventIdx <= #events and events[r.eventIdx].t <= t do
				local ev = events[r.eventIdx]
				r.eventIdx += 1
				if Echoes.onEvent then
					Echoes.onEvent(actor, ev)
				end
			end
		end
	end
end

-- End of loop: remove all echo models (recordings are kept).
function Echoes.despawnAll()
	table.clear(replays)
	Actors.clearEchoes()
end

function Echoes.clearPlayer(player: Player)
	recordings[player] = nil
	current[player] = nil
	Actors.clearEchoes(player)
	local tpl = templates[player]
	if tpl then
		tpl:Destroy()
		templates[player] = nil
	end
end

-- New heist: forget all recordings.
function Echoes.clearAll()
	table.clear(recordings)
	table.clear(current)
	Echoes.despawnAll()
end

return Echoes
