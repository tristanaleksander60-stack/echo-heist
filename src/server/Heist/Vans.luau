--!strict
-- Heist/Vans: the hideout's vans in the world (PLAN_FIRST_PERSON "LB", Config.Hideout). Garage/Vans/Van<i> holds,
-- for each bay (Garage/Anchors/VanBay<i>: the van's spot, its LookVector the side door's facing):
--   * attributes the clients read (server-written only): Bay, Mode (Shared/Heist/VanRules.MODE), CrewId, LeaderId,
--     Paint, Seats (VanRules.encodeSeats), Waiting (seated members not READY), Style (Config.Hideout.VAN.STYLES
--     index), Open (open to Quick Crew), Held (seats held for matched Quick Crew players);
--   * the look points (invisible, non-colliding, never queried): Cab, Door, Paint, Style (EH_Kind "vanPoint");
--   * the crew's name plate over the side door (the leader's crew colour and name, a pip per seat), a lit name card
--     over each cargo seat (the member's crew colour and name; dim when free), the sliding side door leaf (shut
--     unless the van is in CREW mode);
--   * Seat parts (driver + cargo bench; never touched, the server seats players with Seat:Sit).
-- The van's paint goes on its greybox collider and on the kit's paint piece for the bay (Lobby.dress tags it EH_Bay
-- and EH_VanPaint: Van_Paint, or the style's <Group>_Paint after Lobby.setVanStyle). Everything here is visual or a
-- seat: the greybox van box stays the collider (Heist/Lobby). A style swap never moves a rig: the styles keep the
-- Van's footprint, side door, cab and seat anchors (assets/blender/van_styles.py).
-- The rules are VanRules; HeistService decides and calls render / seat / unseat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))
local VanRules = require(HeistShared:WaitForChild("VanRules"))

local Lobby = require(script.Parent:WaitForChild("Lobby"))

local HD = Config.Hideout
local V = HD.VAN

local Vans = {}

type Rig = {
	bay: number,
	model: Model,
	anchor: CFrame,
	plate: BasePart,
	plateName: TextLabel,
	plateStripe: Frame,
	pips: { Frame },
	cards: { [number]: { part: BasePart, name: TextLabel, state: TextLabel } },
	leaf: BasePart,
	leafOpen: boolean?,
	seats: { Seat },
	occupant: { [number]: number }, -- seat index -> userId the server seated there
}

local rigs: { [number]: Rig } = {}
local folder: Folder? = nil
local onStood: ((userId: number, bay: number) -> ())? = nil

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function at(anchor: CFrame, along: number, up: number, out: number): CFrame
	local p = VanRules.localPoint(along, up, out)
	return anchor * CFrame.new(p[1], p[2], p[3])
end

local function visual(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function surface(part: BasePart, ppm: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppm
	gui.MaxDistance = 90
	gui.Parent = part
	return gui
end

local function text(parent: Instance, name: string, pos: UDim2, size: UDim2, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = pos
	t.Size = size
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = color
	t.Text = ""
	t.Parent = parent
	return t
end

-- The anchor CFrame of a bay (Garage/Anchors/VanBay<i>), nil before Lobby.build.
function Vans.anchor(bay: number): CFrame?
	local a = Lobby.anchor("VanBay" .. bay)
	return if a then a.CFrame else nil
end

-- A van point in the world: "cab" | "door" | "paint" (Config.Hideout.VAN.POINTS) or "exit".
function Vans.point(bay: number, name: string): Vector3?
	local anchor = Vans.anchor(bay)
	if not anchor then
		return nil
	end
	if name == "exit" then
		local e = V.EXIT
		return at(anchor, e[1], e[2], e[3]).Position
	end
	local p = V.POINTS[name]
	return if p then at(anchor, p[1], p[2], p[3]).Position else nil
end

-- Where crew member i stands when the crew comes back to the hideout: a row on the floor outside the side door.
function Vans.besideVan(bay: number, i: number): CFrame?
	local anchor = Vans.anchor(bay)
	if not anchor then
		return nil
	end
	local e = V.EXIT
	local along = e[1] + ((i - 1) % 4 - 1.5) * 2.6
	local cf = at(anchor, along, 3, e[3] + math.floor((i - 1) / 4) * 2.6)
	-- facing the van
	local look = at(anchor, along, 3, 0).Position
	return CFrame.lookAt(cf.Position, Vector3.new(look.X, cf.Position.Y, look.Z))
end

-- Builds the rigs (once, after Lobby.build). onStoodUp(userId, bay): a seated player left their seat themselves.
function Vans.build(onStoodUp: ((number, number) -> ())?): Folder?
	onStood = onStoodUp
	if folder then
		return folder
	end
	local garage = Lobby.model()
	if not garage then
		return nil
	end
	local f = Instance.new("Folder")
	f.Name = "Vans"
	for bay = 1, HD.BAYS do
		local anchor = Vans.anchor(bay)
		if anchor then
			local m = Instance.new("Model")
			m.Name = "Van" .. bay
			m:SetAttribute("EH_Kind", "lobbyVan")
			m:SetAttribute("Bay", bay)
			m:SetAttribute("Mode", VanRules.MODE.Free)
			m:SetAttribute("CrewId", 0)
			m:SetAttribute("LeaderId", 0)
			m:SetAttribute("Paint", 0)
			m:SetAttribute("Seats", "")
			m:SetAttribute("Waiting", 0)
			m:SetAttribute("Style", 1)
			m:SetAttribute("Open", false)
			m:SetAttribute("Held", 0)
			for name, p in V.POINTS do
				local pt = visual(
					m,
					string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2),
					Vector3.one * 0.5,
					at(anchor, p[1], p[2], p[3]),
					Palette.ink
				)
				pt.Transparency = 1
				pt:SetAttribute("EH_Kind", "vanPoint")
				pt:SetAttribute("EH_Point", name)
				pt:SetAttribute("EH_Bay", bay)
				pt:SetAttribute("Radius", p[4])
			end
			-- the name plate over the side door
			local P = V.PLATE
			local plate = visual(
				m,
				"Plate",
				Vector3.new(P.size[1], P.size[2], 0.12),
				at(anchor, P.along, P.up, P.out),
				Palette.ink
			)
			local pg = surface(plate, 40)
			local stripe = Instance.new("Frame")
			stripe.Name = "Stripe"
			stripe.BorderSizePixel = 0
			stripe.Size = UDim2.fromScale(1, 0.14)
			stripe.Position = UDim2.fromScale(0, 0.86)
			stripe.BackgroundColor3 = Palette.steel
			stripe.Parent = pg
			local plateName = text(pg, "Name", UDim2.fromScale(0.04, 0.06), UDim2.fromScale(0.62, 0.74), Palette.exit)
			plateName.TextXAlignment = Enum.TextXAlignment.Left
			local pips: { Frame } = {}
			for k = 1, #V.SEATS do
				local pip = Instance.new("Frame")
				pip.Name = "Pip" .. k
				pip.BorderSizePixel = 0
				pip.AnchorPoint = Vector2.new(0.5, 0.5)
				pip.Size = UDim2.fromScale(0.06, 0.4)
				pip.Position = UDim2.fromScale(0.7 + (k - 1) * 0.08, 0.43)
				pip.BackgroundColor3 = Palette.steelLo
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = pip
				pip.Parent = pg
				table.insert(pips, pip)
			end
			-- a lit card over each cargo seat (seat 2..)
			local cards = {}
			local L = V.SEAT_LIGHT
			for k = 2, #V.SEATS do
				local s = V.SEATS[k]
				local card = visual(
					m,
					"SeatCard" .. k,
					Vector3.new(L.size[1], L.size[2], 0.06),
					at(anchor, s[1], L.up, L.out),
					Palette.inkHi
				)
				card.Material = Enum.Material.Neon
				card.Transparency = V.FREE_LIGHT
				local cg = surface(card, 50)
				local nm = text(cg, "Name", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.56), Palette.exit)
				local st = text(cg, "State", UDim2.fromScale(0.05, 0.6), UDim2.fromScale(0.9, 0.36), Palette.exit)
				cards[k] = { part = card, name = nm, state = st }
			end
			-- the side door leaf (shut unless the van is in CREW mode)
			local D = V.DOOR_LEAF
			local leaf = visual(
				m,
				"DoorLeaf",
				Vector3.new(D.size[1], D.size[2], D.size[3]),
				at(anchor, D.along, D.up, D.out),
				rgb(Config.Lobby.BAY_PAINTS[(bay - 1) % #Config.Lobby.BAY_PAINTS + 1])
			)
			-- the seats
			local seats: { Seat } = {}
			for k, s in V.SEATS do
				local seat = Instance.new("Seat")
				seat.Name = "Seat" .. k
				seat.Anchored = true
				seat.CanCollide = false
				seat.CanTouch = false -- nobody sits by bumping into it: the server seats you (Seat:Sit)
				seat.CanQuery = false
				seat.Transparency = 1
				seat.Size = Vector3.new(2, 0.4, 2)
				local face = if s[4] == "cab" then CFrame.Angles(0, math.rad(-V.CAB_X * 90), 0) else CFrame.new()
				seat.CFrame = at(anchor, s[1], s[2], s[3]) * face
				seat.Parent = m
				seats[k] = seat
			end
			local rig: Rig = {
				bay = bay,
				model = m,
				anchor = anchor,
				plate = plate,
				plateName = plateName,
				plateStripe = stripe,
				pips = pips,
				cards = cards,
				leaf = leaf,
				leafOpen = nil,
				seats = seats,
				occupant = {},
			}
			rigs[bay] = rig
			for k, seat in seats do
				seat:GetPropertyChangedSignal("Occupant"):Connect(function()
					local uid = rig.occupant[k]
					if seat.Occupant == nil and uid ~= nil then
						rig.occupant[k] = nil
						local fn = onStood
						if fn then
							task.spawn(fn, uid, bay)
						end
					end
				end)
			end
			m.Parent = f
		end
	end
	f.Parent = garage
	folder = f
	-- the kit dresses the garage later (Lobby.dress): the claimed vans' styles and paints go on its pieces then
	garage:GetAttributeChangedSignal("Kit"):Connect(function()
		for bay, rig in rigs do
			Vans.style(bay, tonumber(rig.model:GetAttribute("Style")) or 1)
			Vans.paint(bay, rig.model:GetAttribute("Paint") :: number?)
		end
	end)
	for bay = 1, HD.BAYS do
		Vans.render(bay, nil, {})
	end
	return f
end

function Vans.folder(): Folder?
	return folder
end

-- The paint index's colour (0 or nil = the bay's own paint).
function Vans.paintColour(bay: number, n: number?): Color3
	local p = n and V.PAINTS[n]
	if p then
		return rgb(p.rgb)
	end
	return rgb(Config.Lobby.BAY_PAINTS[(bay - 1) % #Config.Lobby.BAY_PAINTS + 1])
end

-- Puts a style's body on the bay's kit van (Lobby.setVanStyle; a no-op before the kit dressed the garage or when the
-- kit lacks the group). True when the bay wears it.
function Vans.style(bay: number, n: number): boolean
	local ok, done = pcall(Lobby.setVanStyle, bay, n)
	if not ok then
		warn("[Vans] style swap failed: " .. tostring(done))
		return false
	end
	return done == true
end

-- Paints the bay's van: its greybox collider, the kit's paint piece (EH_VanPaint) and the door leaf.
function Vans.paint(bay: number, n: number?)
	local garage = Lobby.model()
	if not garage then
		return
	end
	local colour = Vans.paintColour(bay, n)
	for _, d in garage:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("EH_Kind") == "garageVan" and d:GetAttribute("EH_Bay") == bay then
			d.Color = colour
		end
	end
	local kit = garage:FindFirstChild("Kit")
	if kit then
		for _, d in kit:GetChildren() do
			if d:IsA("BasePart") and d:GetAttribute("EH_VanPaint") == true and d:GetAttribute("EH_Bay") == bay then
				d.Color = colour
			end
		end
	end
	local rig = rigs[bay]
	if rig then
		rig.leaf.Color = colour
	end
end

local function setLeaf(rig: Rig, open: boolean)
	if rig.leafOpen == open then
		return
	end
	local first = rig.leafOpen == nil
	rig.leafOpen = open
	local D = V.DOOR_LEAF
	local goal = if open then at(rig.anchor, D.openAlong, D.up, D.openOut) else at(rig.anchor, D.along, D.up, D.out)
	if first then
		rig.leaf.CFrame = goal
		rig.leaf.Transparency = 0
		return
	end
	TweenService:Create(
		rig.leaf,
		TweenInfo.new(V.DOOR_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ CFrame = goal }
	):Play()
end

-- Writes a bay's van state: attributes, plate, seat cards, door, style, paint. names: userId -> display name;
-- held: seats held for matched Quick Crew players (Shared/Heist/QuickCrew).
function Vans.render(bay: number, van: VanRules.Van?, names: { [number]: string }, held: number?)
	local rig = rigs[bay]
	if not rig then
		return
	end
	local m = rig.model
	local mode = if van then van.mode else VanRules.MODE.Free
	local style = if van and VanRules.validStyle(van.style) then van.style else 1
	m:SetAttribute("Mode", mode)
	m:SetAttribute("CrewId", if van then van.crewId else 0)
	m:SetAttribute("LeaderId", if van then van.leaderId else 0)
	m:SetAttribute("Paint", if van then van.paint else 0)
	m:SetAttribute("Seats", VanRules.encodeSeats(van))
	m:SetAttribute("Waiting", if van then VanRules.waiting(van) else 0)
	m:SetAttribute("Style", style)
	m:SetAttribute("Open", van ~= nil and van.open == true)
	m:SetAttribute("Held", if van then held or 0 else 0)
	Vans.style(bay, style)
	Vans.paint(bay, if van then van.paint else 0)
	-- the plate: the leader's crew colour (seat 1) and name
	local leaderName = van and names[van.leaderId]
	if not van then
		rig.plateName.Text = Strings.VAN_FREE
		rig.plateName.TextColor3 = Palette.steelHi
		rig.plateStripe.BackgroundColor3 = Palette.steelLo
	elseif mode == VanRules.MODE.Away then
		rig.plateName.Text = Strings.VAN_AWAY
		rig.plateName.TextColor3 = Palette.steelHi
		rig.plateStripe.BackgroundColor3 = Palette.hueFor(1)
	else
		rig.plateName.Text = Strings.vanPlate(leaderName or "?")
		rig.plateName.TextColor3 = Palette.exit
		-- a van open to Quick Crew wears a gold stripe (its free seats card says FREE SEAT as before)
		rig.plateStripe.BackgroundColor3 = if van.open then Palette.gold else Palette.hueFor(1)
	end
	local bySeat: { [number]: VanRules.Seat } = {}
	for _, s in (if van then van.seats else {}) do
		bySeat[s.seat] = s
	end
	for k, pip in rig.pips do
		local s = bySeat[k]
		pip.BackgroundColor3 = if s then Palette.hueFor(k) else Palette.steelLo
		pip.BackgroundTransparency = if s and (s.seated or k == 1) then 0 else 0.5
	end
	for k, card in rig.cards do
		local s = bySeat[k]
		if s then
			card.part.Color = Palette.hueFor(k)
			card.part.Transparency = if s.seated then 0.05 else 0.35
			card.name.Text = string.upper(names[s.userId] or "?")
			card.state.Text = if s.ready then Strings.SEAT_READY elseif s.seated then "" else Strings.SEAT_OUT
		else
			card.part.Color = Palette.inkHi
			card.part.Transparency = V.FREE_LIGHT
			card.name.Text = if mode == VanRules.MODE.Crew then Strings.SEAT_FREE else ""
			card.state.Text = ""
		end
	end
	setLeaf(rig, mode == VanRules.MODE.Crew)
end

-- Seats a player's character in a seat of the bay's van (Seat:Sit: the engine's weld and sit pose). False when the
-- character is not there.
function Vans.seat(player: Player, bay: number, seatIndex: number): boolean
	local rig = rigs[bay]
	local seat = rig and rig.seats[seatIndex]
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (rig and seat and hum and hum.Health > 0) then
		return false
	end
	-- leave any other van seat first
	Vans.unseat(player, false)
	rig.occupant[seatIndex] = player.UserId
	local ok = pcall(function()
		seat:Sit(hum)
	end)
	if not ok then
		rig.occupant[seatIndex] = nil
	end
	return ok
end

-- Takes a player out of any van seat; stepOut = put the character outside that van's side door.
function Vans.unseat(player: Player, stepOut: boolean)
	for bay, rig in rigs do
		for k, uid in rig.occupant do
			if uid == player.UserId then
				rig.occupant[k] = nil -- before the weld goes, so the Occupant watcher stays quiet
				local seat = rig.seats[k]
				local weld = seat:FindFirstChild("SeatWeld")
				if weld then
					weld:Destroy()
				end
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.Sit = false
				end
				if stepOut and char then
					local cf = Vans.besideVan(bay, 1)
					if cf then
						char:PivotTo(cf)
					end
				end
			end
		end
	end
end

-- The bay and seat a player is seated in by the server (nil = none).
function Vans.seatedIn(userId: number): (number?, number?)
	for bay, rig in rigs do
		for k, uid in rig.occupant do
			if uid == userId then
				return bay, k
			end
		end
	end
	return nil, nil
end

return Vans
