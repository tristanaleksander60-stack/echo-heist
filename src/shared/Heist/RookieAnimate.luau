--!strict
-- Heist/RookieAnimate: puts the Rookie's locomotion clips (Shared/Heist/RookieClips) into a character's default R15
-- Animate script (REVIEW_STEAM_PLUS #6). LihFolk vault "The Default Animate Script": the script rebuilds a set when
-- an Animation in it changes, so the ids are swapped in place (the engine's Animate keeps emotes, tools, climbing,
-- swimming, the walk/run speed blend); a track already playing keeps playing until the set is chosen again, so the
-- local client also stops the old tracks once (Heist/RookieAnim). LoadCharacterAppearance is off, so no avatar pack
-- overwrites the ids later. The server (Heist/Characters) and the owning client both apply it: whichever runs first
-- wins and the second is a no-op.
--   idle: Animation1 = idle (weight IDLE_WEIGHT), Animation2 = look, the occasional suspicious look around
--   walk / run / jump / fall: every Animation in the set

local Config = require(script.Parent.Parent:WaitForChild("Config")) :: any
local RookieClips = require(script.Parent:WaitForChild("RookieClips")) :: { [string]: string }

local RookieAnimate = {}

RookieAnimate.SLOTS = table.freeze({ "walk", "run", "jump", "fall" })

local function setId(anim: Animation, id: string): boolean
	if anim.AnimationId == id then
		return false
	end
	anim.AnimationId = id
	return true
end

local function setWeight(anim: Animation, w: number)
	local v = anim:FindFirstChild("Weight")
	if not v then
		local made = Instance.new("NumberValue")
		made.Name = "Weight"
		made.Value = w
		made.Parent = anim
	elseif v:IsA("NumberValue") and v.Value ~= w then
		v.Value = w
	end
end

-- Writes the ids into `animate` (the character's Animate script). Returns how many Animations changed.
function RookieAnimate.apply(animate: Instance): number
	local changed = 0
	for _, slot in RookieAnimate.SLOTS do
		local id = RookieClips[slot]
		local set = animate:FindFirstChild(slot)
		if id and set then
			for _, a in set:GetChildren() do
				if a:IsA("Animation") and setId(a, id) then
					changed += 1
				end
			end
		end
	end
	local idle = animate:FindFirstChild("idle")
	if idle and RookieClips.idle then
		local anims: { Animation } = {}
		for _, a in idle:GetChildren() do
			if a:IsA("Animation") then
				table.insert(anims, a)
			end
		end
		table.sort(anims, function(a: Animation, b: Animation): boolean
			return a.Name < b.Name
		end)
		local W = Config.Rookie.ANIM.IDLE_WEIGHTS
		for i, a in anims do
			local look = i == 2 and RookieClips.look ~= nil
			if setId(a, if look then RookieClips.look else RookieClips.idle) then
				changed += 1
			end
			setWeight(a, if look then W.look else W.idle)
		end
	end
	return changed
end

-- Is this id one of the Rookie's clips?
function RookieAnimate.isRookie(id: string): boolean
	for _, v in RookieClips do
		if v == id then
			return true
		end
	end
	return false
end

-- The character's Animate script (waits up to `timeout` seconds), or nil.
function RookieAnimate.find(char: Model, timeout: number): Instance?
	return char:FindFirstChild("Animate") or char:WaitForChild("Animate", timeout)
end

return RookieAnimate
