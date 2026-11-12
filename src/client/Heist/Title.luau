--!strict
-- Heist/Title: the first-join title beat (PLAN_STEAM_PLUS §3.4, §5 "Title beat"; MASTERPLAN §2.2). The
-- loading card's own frame, built again one layer up (ReplicatedFirst/LoadingCard with three wordmark
-- copies), so the hand-off from the card is invisible; then the wordmark splits into three offset
-- copies, cyan, magenta and indigo, one clone-arpeggio note each (the sound logo: CloneChime on the
-- pentatonic ladder), and holds with the reel turning until the first heist is ready. Heist/Loading
-- then fades it off the closed van doors (Heist/Transition) and the doors open onto L1.
--
--   Title.play(playerGui, reduced) -> beat
--     beat.beatEnd()   when the beat is over (now, once skipped)
--     beat.skip()      any input: every copy jumps to its resting place (the beat is over)
--     beat.fadeOut(s)  fades the whole title away, then destroys it
-- Any input skips it (keys, clicks, touches, gamepad); reduced motion fades the copies in place.
-- Numbers: Config.Presentation.TITLE. It never decides when control arrives (the server does).

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local LoadingCard = require(ReplicatedFirst:WaitForChild("LoadingCard"))

local Motion = require(script.Parent:WaitForChild("Motion"))
local PresentPlan = require(script.Parent:WaitForChild("PresentPlan"))
local Sound = require(script.Parent:WaitForChild("Sound"))

local T = Config.Presentation.TITLE

local Title = {}

local SKIP_INPUTS: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.Touch] = true,
	[Enum.UserInputType.Gamepad1] = true,
}

function Title.play(playerGui: Instance, reduced: () -> boolean): any
	local beat = {}
	local card = LoadingCard.build(playerGui, { name = "EH_Title", order = T.ORDER, copies = #T.SPLITS })
	LoadingCard.setStage(card, "server")
	local copies = card.mark.copies
	local start = os.clock()
	local splits, endAt = PresentPlan.titleSchedule(start, T)
	local done: { [number]: boolean } = {}
	local gone = false

	local function rest(k: number): UDim2
		local x, y = PresentPlan.copyRest(k, T.STEP)
		return UDim2.fromOffset(x, y)
	end

	local function split(k: number, animate: boolean)
		if done[k] or gone then
			return
		end
		done[k] = true
		local c = copies[k]
		local s = c:FindFirstChildOfClass("UIStroke")
		if animate and not reduced() then
			Motion.timed(c, T.SPLIT_SECONDS, { Position = rest(k), TextTransparency = 0 }, "emphasis")
			if s then
				Motion.timed(s, T.SPLIT_SECONDS, { Transparency = 0 }, "emphasis")
			end
		elseif animate then
			c.Position = rest(k) -- reduced motion: in place, a crossfade
			Motion.tween(c, "fade", { TextTransparency = 0 })
			if s then
				Motion.tween(s, "fade", { Transparency = 0 })
			end
		else
			c.Position = rest(k)
			c.TextTransparency = 0
			if s then
				s.Transparency = 0
			end
		end
		if animate then
			Sound.play("CloneChime", { step = T.NOTES[k] or (k - 1) })
		end
	end

	local spin = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		LoadingCard.spin(card.reel, now, reduced())
		for k, at in splits do
			if now >= at then
				split(k, true)
			end
		end
	end)
	local input = UserInputService.InputBegan:Connect(function(io: InputObject)
		if SKIP_INPUTS[io.UserInputType] then
			beat.skip()
		end
	end)

	function beat.beatEnd(): number
		return endAt
	end

	function beat.skip()
		for k in splits do
			split(k, false)
		end
		endAt = math.min(endAt, os.clock())
	end

	function beat.fadeOut(seconds: number)
		if gone then
			return
		end
		beat.skip()
		gone = true
		input:Disconnect()
		local last: Tween? = nil
		for _, pair in LoadingCard.fadeGoals(card.gui) do
			last = Motion.timed(pair[1], seconds, pair[2], "fade")
		end
		local function destroy()
			spin:Disconnect()
			card.gui:Destroy()
		end
		if last then
			last.Completed:Once(destroy)
		else
			destroy()
		end
	end

	return beat
end

return Title
