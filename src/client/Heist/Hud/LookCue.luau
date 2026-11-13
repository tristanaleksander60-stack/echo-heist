--!strict
-- Hud/LookCue: the first-person look cue (PLAN_FIRST_PERSON wave C, §4 "First person changes onboarding").
-- While something the kid must see is out of view (the L1 clone walking out of your own body: "YOU, 10 SEC
-- AGO"; the "Show me?" chalk ghost), the onboarding finger sits at the screen edge, pointing the way, with a
-- short word chip ("YOUR CLONE"). Behind you it sits on the bottom edge, leaning to the target's side: a look
-- back. Where it goes is FpMath.edgeCue (pure, tests/unit/HeistFirstPerson.spec.luau). On the edge-to-edge fx
-- layer under the HUD's device scale, like Hud/Reticle; never interactive. The camera is never taken.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Palette = require(Shared:WaitForChild("Heist"):WaitForChild("Palette"))

local FpMath = require(script.Parent.Parent:WaitForChild("FpMath"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local O = Config.Onboarding
local U = Config.Ui

local LookCue = {}

function LookCue.build(ctx: any): any
	local cue = {}
	local layer = Ui.frame(ctx.fxGui, {
		Name = "LookCue",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 3,
		Active = false,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = layer
	local function rescale()
		local s = if ctx.deviceScale then ctx.deviceScale.Scale else 1
		s = if s > 0 then s else 1
		scale.Scale = s
		layer.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	if ctx.deviceScale then
		ctx.deviceScale:GetPropertyChangedSignal("Scale"):Connect(rescale)
	end

	-- The finger (Common.finger points right, anchored at its tip) in a holder that turns toward the target.
	local holder = Ui.frame(layer, {
		Name = "Pointer",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(O.POINTER_SIZE * 2, O.POINTER_SIZE * 2),
		Active = false,
		ZIndex = 3,
	})
	local finger = Common.finger(holder, O.POINTER_SIZE, 4)
	finger.AnchorPoint = Vector2.new(1, 0.5)
	finger.Position = UDim2.fromScale(1, 0.5)
	finger.Visible = true
	local chip = Ui.panel(layer, {
		Name = "Word",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(150, 34),
		Active = false,
		ZIndex = 4,
	})
	local word = Ui.label(chip, {
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		TextSize = U.TYPE_SCALE[2],
		TextColor3 = Palette.white,
		Text = "",
		Active = false,
		ZIndex = 5,
	})

	-- your first-person right hand points along while the cue shows (Heist/Viewmodel, state.fpPointing)
	local function pointing(on: boolean)
		local st = ctx.state
		if st and st.fpPointing ~= on then
			st.fpPointing = on
		end
	end

	local shownText = ""
	-- `target` (a world position) and its word; nil hides the cue. Call every frame while it applies.
	function cue.set(target: Vector3?, text: string?, now: number)
		local cam = workspace.CurrentCamera
		if not (target and cam) then
			layer.Visible = false
			pointing(false)
			return
		end
		local vp = cam.ViewportSize
		local rel = cam.CFrame:PointToObjectSpace(target)
		local tanV = math.tan(math.rad(cam.FieldOfView) / 2)
		local u, v, angle =
			FpMath.edgeCue({ rel.X, rel.Y, rel.Z }, tanV, vp.X / math.max(vp.Y, 1), O.LOOK_CUE_INSET, O.LOOK_CUE_MARGIN)
		if not (u and v and angle) then
			layer.Visible = false
			pointing(false)
			return
		end
		layer.Visible = true
		pointing(true)
		-- The finger taps toward the target (held still under reduced motion).
		local tap = if Ui.reducedMotion() then 0 else (0.5 - 0.5 * math.cos(now * 2 * math.pi / O.POINTER_PERIOD))
		local r = math.rad(angle)
		local push = O.POINTER_TRAVEL * tap
		holder.Position = UDim2.new(u, math.cos(r) * push, v, math.sin(r) * push)
		holder.Rotation = angle
		-- The word sits inward from the finger (toward the screen's centre), never over the edge.
		local back = O.POINTER_SIZE * 1.4
		chip.Position = UDim2.new(u, -math.cos(r) * back, v, -math.sin(r) * back)
		local t = text or ""
		if t ~= shownText then
			shownText = t
			word.Text = t
			chip.Visible = t ~= ""
		end
	end

	function cue.hide()
		layer.Visible = false
		pointing(false)
	end

	return cue
end

return LookCue
