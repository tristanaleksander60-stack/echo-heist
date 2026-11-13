--!strict
-- Heist/RookieAnim: your character moves in the Rookie's own clips (REVIEW_STEAM_PLUS #6). The server already
-- writes them into the engine's Animate on spawn (Heist/Characters); this client side makes it immediate and whole:
--   * applies the same ids locally the moment the Animate script arrives (Shared/Heist/RookieAnimate) and stops,
--     once, any track still playing an older id (vault: a playing track keeps going until its set is chosen
--     again), so the first idle is already the Rookie's;
--   * plays the land clip (squash, Action priority) when you touch down after LAND.minFall seconds in the air (a
--     jump counts): the Animate has no landing. Lighter at speed (CloneGait.landWeight). Played on your own Animator, so it replicates like the rest.
-- Clones play the same clips from their recording (Heist/Rigs, Heist/EchoView), so they walk exactly like you.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local CloneGait = require(HeistShared:WaitForChild("CloneGait"))
local RookieAnimate = require(HeistShared:WaitForChild("RookieAnimate"))
local RookieClips = require(HeistShared:WaitForChild("RookieClips")) :: { [string]: string }

local A = Config.Rookie.ANIM

local RookieAnim = {}

local landAnim: Animation? = nil
local function landAnimation(): Animation?
	if not landAnim and RookieClips.land then
		local a = Instance.new("Animation")
		a.AnimationId = RookieClips.land
		landAnim = a
	end
	return landAnim
end

-- Sets up one character (yours). Returns a cleanup function. Exposed for the engine tests.
function RookieAnim.attach(char: Model): () -> ()
	local conns: { RBXScriptConnection } = {}
	local alive = true
	task.spawn(function()
		local animate = RookieAnimate.find(char, A.ANIMATE_WAIT)
		if not alive or not animate then
			return
		end
		RookieAnimate.apply(animate)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local animator = hum and hum:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in animator:GetPlayingAnimationTracks() do
				local anim = track.Animation
				local id = if anim then anim.AnimationId else ""
				if
					string.find(id, "%d")
					and not RookieAnimate.isRookie(id)
					and track.Priority == Enum.AnimationPriority.Core
				then
					track:Stop(0) -- the engine's own idle / walk, started before the ids arrived
				end
			end
		end
	end)
	local hum = char:WaitForChild("Humanoid", A.ANIMATE_WAIT)
	if hum and hum:IsA("Humanoid") then
		local airFrom: number? = nil
		local track: AnimationTrack? = nil
		table.insert(
			conns,
			hum.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
				if new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping then
					airFrom = airFrom or os.clock()
				elseif new == Enum.HumanoidStateType.Landed then
					local from = airFrom
					airFrom = nil
					if from and os.clock() - from >= A.LAND.minFall then
						if not track then
							local animator = hum:FindFirstChildOfClass("Animator")
							local anim = landAnimation()
							if animator and anim then
								local ok, made = pcall(function(): AnimationTrack
									local t = animator:LoadAnimation(anim)
									t.Priority = Enum.AnimationPriority.Action
									t.Looped = false
									return t
								end)
								track = if ok then made else nil
							end
						end
						if track then
							local root = char:FindFirstChild("HumanoidRootPart")
							local v = if root and root:IsA("BasePart")
								then root.AssemblyLinearVelocity
								else Vector3.zero
							track:Play(A.LAND.fade, CloneGait.landWeight(Vector3.new(v.X, 0, v.Z).Magnitude), 1)
						end
					end
				elseif new ~= Enum.HumanoidStateType.Freefall then
					airFrom = nil
				end
			end)
		)
	end
	return function()
		alive = false
		for _, c in conns do
			c:Disconnect()
		end
	end
end

-- Follows the local player's characters (call once).
function RookieAnim.start()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local cleanup: (() -> ())? = nil
	local function on(char: Model)
		if cleanup then
			cleanup()
		end
		cleanup = RookieAnim.attach(char)
	end
	player.CharacterAdded:Connect(on)
	if player.Character then
		task.spawn(on, player.Character)
	end
end

return RookieAnim
