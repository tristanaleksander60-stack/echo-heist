--!strict
-- Heist/Transition: the van-door wipe (PLAN_STEAM_PLUS §4.1 W7, §4.2 C4, §5 "Van door -> L1"; premium
-- H4; POLISH §4.6 item 6). Two ink door panels close from the sides (0.25 s) when you leave for the
-- heist, the results or the garage, hold while the server builds and the views bind, and slide apart
-- (0.3 s) on the new place: close + open = 0.55 s, never a pop to black. Reduced motion: a 0.15 s ink
-- crossfade each way instead of the slide. Numbers: Config.Presentation.DOORS.
--
--   Transition.new(layer, reduced) -> doors   layer: the HUD's edge-to-edge fx gui (the doors sit at
--                                             DOORS.ZINDEX: over the HUD, under the stamps and the
--                                             Line-up caption, so "HEIST COMPLETE" reads over them)
--   doors.close()      closes and yields until closed (returns at once when already closed)
--   doors.closeFor(s)  starts closing for a pick the server may refuse: opens again after s unless
--                      a close() / cover() claimed the doors meanwhile (garage pick -> heist)
--   doors.cover()      closed at once, no motion (under the loading card or the title beat)
--   doors.open()       starts opening (does not yield)
--   doors.clear()      open at once, no motion (the story intro's 3D stage must never sit behind them)
--   doors.isClosed()   closed or closing
--   doors.openSeconds() how long the reveal takes (the slide, or the crossfade)
-- Purely visual: nothing waits on the doors except the client's own hand-off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local Palette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heist"):WaitForChild("Palette"))

local Motion = require(script.Parent:WaitForChild("Motion"))
local Sound = require(script.Parent:WaitForChild("Sound"))

local D = Config.Presentation.DOORS

local Transition = {}

local function panel(layer: Instance, name: string, left: boolean): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Palette.ink
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(if left then 1 else 0, 0)
	f.Size = UDim2.new(0.5, D.SEAM, 1, 0) -- a little wider than half: the outer edge stays off-screen while it slides
	f.ZIndex = D.ZINDEX
	f.Visible = false
	f.Parent = layer
	-- the seam: a lighter edge where the two doors meet, and a handle bar beside it
	local seam = Instance.new("Frame")
	seam.Name = "Seam"
	seam.BackgroundColor3 = Palette.inkHi
	seam.BorderSizePixel = 0
	seam.AnchorPoint = Vector2.new(if left then 1 else 0, 0)
	seam.Position = UDim2.fromScale(if left then 1 else 0, 0)
	seam.Size = UDim2.new(0, D.SEAM, 1, 0)
	seam.ZIndex = D.ZINDEX + 1
	seam.Parent = f
	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.BackgroundColor3 = Palette.steelLo
	handle.BorderSizePixel = 0
	handle.AnchorPoint = Vector2.new(if left then 1 else 0, 0.5)
	handle.Position = UDim2.new(if left then 1 else 0, if left then -D.SEAM * 4 else D.SEAM * 4, 0.5, 0)
	handle.Size = UDim2.fromOffset(D.HANDLE[1], D.HANDLE[2])
	handle.ZIndex = D.ZINDEX + 1
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = handle
	handle.Parent = f
	return f
end

function Transition.new(layer: Instance, reduced: () -> boolean): any
	local doors = {}
	local left = panel(layer, "VanDoorLeft", true)
	local right = panel(layer, "VanDoorRight", false)
	local veil = Instance.new("Frame") -- the reduced-motion crossfade
	veil.Name = "VanDoorVeil"
	veil.BackgroundColor3 = Palette.ink
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = D.ZINDEX
	veil.Visible = false
	veil.Parent = layer

	-- Positions: closed = both panels meet in the middle; open = each just past its edge.
	local CLOSED_L, OPEN_L = UDim2.fromScale(0.5, 0), UDim2.fromOffset(-D.SEAM, 0)
	local CLOSED_R, OPEN_R = UDim2.fromScale(0.5, 0), UDim2.new(1, D.SEAM, 0, 0)
	left.Position, right.Position = OPEN_L, OPEN_R

	local closed = false
	local token = 0 -- each move bumps it; a finished tween only applies its end state if still current
	local tweens: { Tween } = {}

	local function cancel()
		for _, tw in tweens do
			tw:Cancel()
		end
		table.clear(tweens)
	end

	local function settleOpen()
		left.Visible, right.Visible, veil.Visible = false, false, false
		left.Position, right.Position = OPEN_L, OPEN_R
		veil.BackgroundTransparency = 1
	end

	function doors.isClosed(): boolean
		return closed
	end

	function doors.clear()
		token += 1
		cancel()
		closed = false
		settleOpen()
	end

	function doors.cover()
		token += 1
		cancel()
		closed = true
		if reduced() then
			left.Visible, right.Visible = false, false
			veil.Visible = true
			veil.BackgroundTransparency = 0
		else
			veil.Visible = false
			left.Position, right.Position = CLOSED_L, CLOSED_R
			left.Visible, right.Visible = true, true
		end
	end

	-- Starts closing; returns the seconds until it is closed (0 when it already is).
	local function startClose(): number
		if closed then
			return 0
		end
		token += 1
		cancel()
		closed = true
		Sound.play("VanDoor")
		if reduced() then
			left.Visible, right.Visible = false, false
			veil.Visible = true
			table.insert(tweens, Motion.timed(veil, D.FADE_SECONDS, { BackgroundTransparency = 0 }, "fade"))
			return D.FADE_SECONDS
		end
		veil.Visible = false
		left.Visible, right.Visible = true, true
		table.insert(tweens, Motion.timed(left, D.CLOSE_SECONDS, { Position = CLOSED_L }, "exit"))
		table.insert(tweens, Motion.timed(right, D.CLOSE_SECONDS, { Position = CLOSED_R }, "exit"))
		return D.CLOSE_SECONDS
	end

	local closingUntil = 0
	-- close() and cover() bump the token, so a pending closeFor never reopens doors they claimed.
	function doors.close()
		local wait = startClose()
		token += 1
		if wait > 0 then
			closingUntil = os.clock() + wait
		end
		local remaining = closingUntil - os.clock()
		if remaining > 0 then
			task.wait(remaining)
		end
	end

	function doors.closeFor(seconds: number)
		local wait = startClose()
		if wait > 0 then
			closingUntil = os.clock() + wait
		end
		local mine = token
		task.delay(seconds, function()
			if token == mine and closed then
				doors.open()
			end
		end)
	end

	function doors.open()
		if not closed then
			return
		end
		token += 1
		cancel()
		closed = false
		local mine = token
		local last: Tween
		if veil.Visible then
			last = Motion.timed(veil, D.FADE_SECONDS, { BackgroundTransparency = 1 }, "fade")
			table.insert(tweens, last)
		else
			table.insert(tweens, Motion.timed(left, D.OPEN_SECONDS, { Position = OPEN_L }, "fade"))
			last = Motion.timed(right, D.OPEN_SECONDS, { Position = OPEN_R }, "fade")
			table.insert(tweens, last)
		end
		last.Completed:Once(function(state: Enum.PlaybackState)
			if state == Enum.PlaybackState.Completed and token == mine then
				settleOpen()
			end
		end)
	end

	-- Seconds the reveal takes (the open slide, or the crossfade under reduced motion).
	function doors.openSeconds(): number
		return if reduced() then D.FADE_SECONDS else D.OPEN_SECONDS
	end

	return doors
end

return Transition
