--!strict
-- Hud/Common: helpers the HUD modules share (gamepad selection, dates, run names, the
-- run-state questions every module asks, and placing a frame from a HudLayout box).

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local HeistShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Heist")
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local KeyHints = require(HeistShared:WaitForChild("KeyHints"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))

local Ui = require(script.Parent.Parent:WaitForChild("Ui"))

local Common = {}

Common.OBJECTIVE_SECONDS = 6 -- an objective line shows this long after it changes (§7.4)

-- Clone statuses that are flagged red (deck cards, strip, DELETE BUSTED).
Common.RED = table.freeze({ Busted = true, Caught = true, Zapped = true, Stuck = true })

-- L1 stuck hints at Config.Heist.HINT_SECONDS (§7.5): re-pulse the plate, a beam from
-- your feet, the Mentor ghost doing the step. Names are the analytics `hint` domain.
Common.HINTS = table.freeze({ "plate", "beam", "mentor" })

-- The gamepad selection outline only when a gamepad is in use (not on touch or PC).
function Common.usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return last == Enum.UserInputType.Gamepad1
		or last == Enum.UserInputType.Gamepad2
		or last == Enum.UserInputType.Gamepad3
		or last == Enum.UserInputType.Gamepad4
end

function Common.selectFor(obj: GuiObject?)
	if Common.usingGamepad() then
		GuiService.SelectedObject = obj
	end
end

-- The device the onboarding lines name buttons for (Strings.forDevice): "touch", "pad" or "key".
function Common.device(): string
	if Common.usingTouch() then
		return "touch"
	elseif Common.usingGamepad() then
		return "pad"
	end
	return "key"
end

-- Places a frame from a HudLayout box (anchor, position, offset size).
function Common.place(obj: GuiObject, box: HudLayout.Box)
	obj.AnchorPoint = Vector2.new(box.ax, box.ay)
	obj.Position = UDim2.new(box.sx, box.ox, box.sy, box.oy)
	obj.Size = UDim2.fromOffset(box.w, box.h)
end

-- Only a box's position (the size stays as it is).
function Common.position(box: HudLayout.Box): UDim2
	return UDim2.new(box.sx, box.ox, box.sy, box.oy)
end

function Common.dateText(day: number): string
	local ok, text = pcall(function()
		local dt = DateTime.fromUnixTimestamp(day * 86400):ToUniversalTime()
		return Strings.date(Strings.MONTHS[dt.Month], dt.Day)
	end)
	return if ok then text else ""
end

function Common.durationText(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return Strings.hoursMinutes(s // 3600, (s % 3600) // 60)
	end
	return Strings.minutes(math.max(1, s // 60))
end

function Common.isTutorial(state: any): boolean
	return state.level ~= nil and state.level.tutorial ~= nil
end

function Common.isParty(state: any): boolean
	return state.level ~= nil and state.level.kind == "party"
end

function Common.dawnRuns(state: any): number?
	local level = state.level
	return if level then level.dawnRuns else nil
end

-- "RUN 7" / "RUN 7/8" / "LAST RUN" for the button and the top bar.
function Common.runName(state: any, n: number): string
	local dawn = Common.dawnRuns(state)
	if dawn and n >= dawn then
		return Strings.LAST_RUN
	elseif dawn then
		return Strings.runOfDawn(n, dawn)
	end
	return Strings.run(n)
end

-- Rookie portraits (crew cards; PLAN_FIRST_PERSON "CH": the card shows YOUR Rookie in your outfit, not a Roblox
-- headshot): a ViewportFrame of the owner's clone template (ReplicatedStorage.HeistAvatars/<userId>, built by the
-- server in their outfit), head and shoulders from a 3/4 front view, the crew pieces in `hue`. No web fetch. Until
-- the template arrives (it is built at join) the CharacterKit Rookie (default outfit) stands in; with neither
-- the card keeps its plain crew-colour backdrop. Only the head, the torso, the upper arms and what is welded to
-- them are copied (a handful of parts per card).
local PORTRAIT_PARTS = { Head = true, UpperTorso = true, LeftUpperArm = true, RightUpperArm = true }

local function portraitSource(userId: number): Model?
	local avatars = ReplicatedStorage:FindFirstChild("HeistAvatars")
	local t = avatars and avatars:FindFirstChild(tostring(userId))
	if t and t:IsA("Model") and t:GetAttribute("EH_Rookie") == true then
		return t
	end
	local kit = ReplicatedStorage:FindFirstChild(Config.Rookie.KIT_FOLDER)
	local r = kit and kit:FindFirstChild("Rookie")
	return if r and r:IsA("Model") then r else nil
end

local function fillPortrait(vp: ViewportFrame, source: Model, hue: Color3?)
	local world = Instance.new("WorldModel")
	world.Name = "Rookie"
	local head: BasePart? = nil
	for _, d in source:GetChildren() do
		if d:IsA("BasePart") then
			local weld = d:FindFirstChild("EH_Weld")
			local host = if weld and weld:IsA("Weld") and weld.Part0 then weld.Part0.Name else d.Name
			if PORTRAIT_PARTS[host] and d.Transparency < 1 then
				local c = d:Clone()
				for _, j in c:GetChildren() do
					if j:IsA("JointInstance") or j:IsA("Attachment") then
						j:Destroy()
					end
				end
				c.Anchored = true
				if hue and c:GetAttribute("EH_Tint") == "crew" then
					c.Color = hue
				end
				c.Parent = world
				if d.Name == "Head" then
					head = c
				end
			end
		end
	end
	local P = Config.Rookie.PORTRAIT
	local cam = Instance.new("Camera")
	cam.FieldOfView = P.FOV
	local target = (if head then head.Position else Vector3.new(0, 3.8, 0)) + Vector3.new(0, P.LIFT, 0)
	local from = target + CFrame.Angles(0, math.rad(P.YAW), 0):VectorToWorldSpace(Vector3.new(0, 0.35, -P.DISTANCE))
	cam.CFrame = CFrame.lookAt(from, target)
	cam.Parent = vp
	vp.CurrentCamera = cam
	world.Parent = vp
end

function Common.portrait(parent: GuiObject, userId: number, hue: Color3?): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Portrait"
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(150, 150, 170)
	vp.LightColor = Color3.fromRGB(255, 236, 214)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Active = false
	vp.Parent = parent
	task.spawn(function()
		local src = portraitSource(userId)
		local waited = 0
		while vp.Parent and (src == nil or src.Name ~= tostring(userId)) and waited < 15 do
			if src and not vp:FindFirstChild("Rookie") then
				fillPortrait(vp, src, hue) -- the default Rookie while the owner's template is built
			end
			task.wait(0.5)
			waited += 0.5
			src = portraitSource(userId)
		end
		if vp.Parent and src then
			for _, c in vp:GetChildren() do
				c:Destroy()
			end
			fillPortrait(vp, src, hue)
		end
	end)
	return vp
end

-- Sheets that cover the screen (results, MENU, settings) switch Roblox's touch controls off while
-- they are up, so the thumbstick and jump button never sit on top of their buttons (tests/hud_layout:
-- HudLayout.SHEETS). Each sheet is one blocker; the controls come back when none is left.
local touchBlockers: { [string]: boolean } = {}
function Common.blockTouch(who: string, on: boolean)
	touchBlockers[who] = if on then true else nil
	local enabled = next(touchBlockers) == nil
	pcall(function()
		if GuiService.TouchControlsEnabled ~= enabled then
			GuiService.TouchControlsEnabled = enabled
		end
	end)
end

-- A sheet blocks touch controls while it is shown (Ui.show / Ui.hide, or a bare Visible = false).
function Common.sheetBlocksTouch(who: string, sheet: GuiObject)
	local function sync()
		Common.blockTouch(who, sheet.Visible and sheet:GetAttribute("UiShown") ~= false)
	end
	sheet:GetAttributeChangedSignal("UiShown"):Connect(sync)
	sheet:GetPropertyChangedSignal("Visible"):Connect(sync)
end

-- Is any sheet up (results, MENU, settings)? First person frees the cursor for it (Heist/CameraDirector).
function Common.sheetUp(): boolean
	return next(touchBlockers) ~= nil
end

-- Touch is the input in use (the last input was a touch, or the device has nothing else).
function Common.usingTouch(): boolean
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not Common.usingGamepad()
end

-- The onboarding finger (§6.2): a cartoon hand pointing right, the index finger, the palm and a thumb
-- (frames, no glyph), `size` px square, anchored at its fingertip's side (right, middle). Hidden.
function Common.finger(parent: Instance, size: number, z: number): Frame
	local f = Ui.frame(parent, {
		Name = "FingerPointer",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(1, 0.5),
		Visible = false,
		ZIndex = z,
		Active = false,
	})
	local function piece(name: string, x: number, y: number, w: number, h: number)
		local p = Ui.frame(f, {
			Name = name,
			BackgroundColor3 = Palette.white,
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			ZIndex = z,
			Active = false,
		})
		Ui.pill(p)
		Ui.stroke(p, Palette.ink, 2)
	end
	piece("Palm", 0.0, 0.3, 0.55, 0.55)
	piece("Thumb", 0.25, 0.12, 0.22, 0.3)
	piece("Finger", 0.38, 0.36, 0.62, 0.22)
	return f
end

function Common.myActor(a: any): boolean
	return a ~= nil and a.kind == "live" and a.owner == Players.LocalPlayer.UserId
end

---------------------------------------------------------------------------
-- Key caps (Shared/Heist/KeyHints): the prompt chip's key-cap style (a white rounded cap, an ink rim, ink letters) on
-- every button that has a key, for the device in use; none on touch. They follow the device live
-- (UserInputService.LastInputTypeChanged).
---------------------------------------------------------------------------
local CAP_H = 24
local CAP_TEXT = Config.Ui.TYPE_SCALE[1]

-- The Enum.KeyCodes bound to a KeyHints action (ContextActionService binds them all; Hud/Controls, Heist/Slide,
-- Heist/Hideout).
function Common.keyCodes(action: string): { Enum.KeyCode }
	local out = {}
	for _, name in KeyHints.codes(action) do
		local ok, code = pcall(function()
			return (Enum.KeyCode :: any)[name]
		end)
		if ok and code then
			table.insert(out, code)
		end
	end
	return out
end

-- A cap's width for its text: a letter is square, a word or a chord is wider.
function Common.keyCapWidth(text: string): number
	return math.max(CAP_H, 10 + 9 * #text)
end

-- The cap itself (Hud/Reticle's chip uses it too): a frame and its label, hidden until given text.
function Common.keyCapFrame(parent: Instance, props: { [string]: any }?): (Frame, TextLabel)
	local cap = Ui.frame(parent, {
		Name = "KeyCap",
		Size = UDim2.fromOffset(CAP_H, CAP_H),
		BackgroundColor3 = Palette.white,
		BackgroundTransparency = 0,
		Active = false,
		Visible = false,
	})
	for k, v in props or {} do
		(cap :: any)[k] = v
	end
	Ui.corner(cap)
	Ui.stroke(cap, Palette.ink, 2)
	local label = Ui.label(cap, {
		Name = "Key",
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextColor3 = Palette.ink,
		TextSize = CAP_TEXT,
		stroke = false,
		ZIndex = cap.ZIndex + 1,
		Active = false,
	})
	return cap, label
end

type CapEntry = { cap: Frame, label: TextLabel, text: () -> string }
local caps: { [Frame]: CapEntry } = {}
local capsHooked = false

local function renderCap(e: CapEntry)
	local ok, text = pcall(e.text)
	local t = if ok and type(text) == "string" then text else ""
	if e.label.Text ~= t then
		e.label.Text = t
		e.cap.Size = UDim2.fromOffset(Common.keyCapWidth(t), CAP_H)
	end
	e.cap.Visible = t ~= ""
end

-- Re-reads every cap (the device changed, or a cap's text source did).
function Common.refreshKeyCaps()
	for cap, e in caps do
		if cap.Parent == nil then
			caps[cap] = nil
		else
			renderCap(e)
		end
	end
end

-- A key cap on a button's top-right corner (or "tl"), straddling it by HudLayout.KEY_CAP_OUT (inside the gap every
-- HUD box keeps, so it never touches a neighbour). Top right by default: Ui.iconWord's UIPadding (left or bottom)
-- never moves that corner. `action` is a KeyHints action, or a function returning the cap's text ("" hides it).
-- Returns the cap.
function Common.keyCap(button: GuiObject, action: string | () -> string, corner: string?): Frame
	local right = corner ~= "tl"
	local out = HudLayout.KEY_CAP_OUT
	local cap, label = Common.keyCapFrame(button, {
		AnchorPoint = Vector2.new(if right then 1 else 0, 0),
		Position = UDim2.new(if right then 1 else 0, if right then out else -out, 0, -out),
		ZIndex = button.ZIndex + 2,
	})
	local text: () -> string
	if type(action) == "function" then
		text = action
	else
		local name: string = action :: any
		text = function(): string
			return KeyHints.label(name, Common.device())
		end
	end
	local e: CapEntry = { cap = cap, label = label, text = text }
	caps[cap] = e
	renderCap(e)
	if not capsHooked then
		capsHooked = true
		UserInputService.LastInputTypeChanged:Connect(Common.refreshKeyCaps)
	end
	return cap
end

-- The gamepad's selected button gets an "A" cap (KeyHints "confirm"): results, the garage, the MENU sheet, any
-- sheet the pad drives. Called once by the HUD.
function Common.selectionCap()
	local cap: Frame?, label: TextLabel? = nil, nil
	local function place()
		local obj = GuiService.SelectedObject
		local text = KeyHints.label("confirm", Common.device())
		local c = cap
		if c and not c:IsDescendantOf(game) then
			c:Destroy() -- it went with a button a sheet re-rendered
			cap, label = nil, nil
		end
		if obj and obj:IsA("GuiButton") and text ~= "" then
			if not cap then
				cap, label = Common.keyCapFrame(obj, { Name = "SelectionKeyCap" })
			end
			local cc, ll = cap :: Frame, label :: TextLabel
			local out = HudLayout.KEY_CAP_OUT
			cc.AnchorPoint = Vector2.new(1, 0)
			cc.Position = UDim2.new(1, out, 0, -out)
			cc.ZIndex = obj.ZIndex + 2
			ll.ZIndex = cc.ZIndex + 1
			ll.Text = text
			cc.Size = UDim2.fromOffset(Common.keyCapWidth(text), CAP_H)
			cc.Parent = obj
			cc.Visible = true
		elseif cap then
			(cap :: Frame).Visible = false
		end
	end
	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(place)
	UserInputService.LastInputTypeChanged:Connect(place)
	place()
end

return Common
