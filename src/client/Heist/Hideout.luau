--!strict
-- Heist/Hideout: the hideout lobby on this client (PLAN_FIRST_PERSON "LB", the LOBBY track; Config.Hideout). You
-- walk the warehouse garage in first person; whatever you look at offers one thing (Shared/Heist/LobbyLook) on the
-- reticle's prompt chip, and E / X / a click (cursor locked) / the touch USE button does it:
--   * stations on the BIG track's anchors (Garage/Anchors): the JOB BOARD and the LAPTOP ease the camera to face
--     them (Phasmophobia's computer-screen pattern), then open the HUD's garage sheet as the job board (jobs, crew,
--     SETTINGS) or the laptop (the daily vault, the advent catch-up); the WARDROBE swings the camera round to look
--     at your Rookie and opens the outfit picker (Hud/Wardrobe, Data.Equip); the TV plays the story intro again
--     (Heist/Cinematic); the "LOOKING FOR CREW" sign opens the Quick Crew sheet (LOOK FOR A CREW / STOP, OPEN MY
--     VAN / CLOSE, INVITE FRIENDS: SocialService). BACK, E, B or Backspace, or walking away closes a station.
--   * the vans (Garage/Vans, server Heist/Vans; their state is attributes): PICK, SIT, READY. The leader's own van
--     offers YOUR VAN at every point: E opens the PARTY sheet (Hud/Party: SOLO / crew size / who can join / the ready
--     check with KICK / INVITE / PAINT / STYLE / GO; E, B, Backspace, Esc or walking away close it, ENTER / Y is
--     GO). Looking at anyone else's claimed van shows its read-only card (owner, mode, seats, who can join, SIT).
--     Each op is a Heist.Ready lobby action table (Shared/Heist/VanRules.validAction): the server decides.
--   * Quick Crew (Config.Hideout.QUICK): while you look for a crew the lobby shows a chip with STOP; once the server
--     holds a seat for you (player attributes QuickCrew = "matched", QuickBay) a floor arrow leads you to that van's
--     side door and a billboard marks it; SIT there joins the crew.
--   * GO (server Msg "Depart"): the side door shuts, the drive (Heist/Drive) plays, the van-door wipe closes over
--     its end and the heist's Sync opens onto run 1.
--   * first visit (FirstTime "hideout"): "PICK A VAN" floats over the nearest free van until you have one.
-- Nothing here decides anything; diorama / classic cameras pick what you face instead of the camera ray.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local HeistShared = Shared:WaitForChild("Heist")
local KeyHints = require(HeistShared:WaitForChild("KeyHints"))
local LobbyLook = require(HeistShared:WaitForChild("LobbyLook"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local Strings = require(HeistShared:WaitForChild("Strings"))
local VanRules = require(HeistShared:WaitForChild("VanRules"))

local Cinematic = require(script.Parent:WaitForChild("Cinematic"))
local Drive = require(script.Parent:WaitForChild("Drive"))
local FirstTime = require(script.Parent:WaitForChild("FirstTime"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Sound = require(script.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Hud"):WaitForChild("Common"))

local HD = Config.Hideout
local localPlayer = Players.LocalPlayer

local Hideout = {}

-- The dressing part a station's outline draws (Heist/LobbyPlan names).
local ADORNEE: { [string]: string } = {
	JobBoardSpot = "JobCard",
	LaptopSpot = "LaptopScreen",
	WardrobeSpot = "Wardrobe",
	TVSpot = "TV",
	CrewSign = "CrewSignBoard",
}
local POINTS = { "cab", "door", "paint", "style" }
local POINT_PART: { [string]: string } = { cab = "Cab", door = "Door", paint = "Paint", style = "Style" }

local function t3(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

-- deps: camera (CameraDirector), look (LookTarget), hud, doors (Transition), send (action table) -> (),
-- reduced () -> boolean, tier () -> number, hands (action) -> (), ui (kind, arg) -> () (Telemetry.ui)
function Hideout.new(state: any, deps: any): any
	local h = {}
	local camera = deps.camera
	local hud = deps.hud
	local items: { any } = {}
	local adornees: { [string]: BasePart? } = {}
	local focus: any = nil -- the open station
	local drive: any = nil -- the drive while it plays
	local departing = false
	local playingIntro = false
	local hint: BillboardGui? = nil
	local quickArrow: BasePart? = nil -- the Quick Crew waypoint arrow (client only)
	local quickMark: BillboardGui? = nil -- "YOUR CREW" over the matched van
	local lastPrompt: any = nil
	local lastItem: any = nil

	local function garage(): Model?
		local g = workspace:FindFirstChild("Garage")
		return if g and g:IsA("Model") then g else nil
	end

	local function root(): BasePart?
		local char = localPlayer.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		return if r and r:IsA("BasePart") then r else nil
	end

	local function adorneeFor(anchorName: string): BasePart?
		local cached = adornees[anchorName]
		if cached and cached.Parent then
			return cached
		end
		local g = garage()
		local name = ADORNEE[anchorName]
		local found = g and name and g:FindFirstChild(name, true)
		local p = if found and found:IsA("BasePart") then found else nil
		adornees[anchorName] = p
		return p
	end

	-- The van's outline part: the kit's paint piece for the bay (EH_VanPaint: Van_Paint or a style's), else its
	-- greybox box (cached; the kit dresses the garage a little after it is built, and a style swap replaces the
	-- pieces, so anything but a live kit paint piece is looked up again).
	local bodies: { [number]: BasePart } = {}
	local function vanBody(bay: number): BasePart?
		local known = bodies[bay]
		if known and known.Parent and known:GetAttribute("EH_VanPaint") == true then
			return known
		end
		local g = garage()
		if not g then
			return nil
		end
		local found: BasePart? = nil
		local kit = g:FindFirstChild("Kit")
		if kit then
			for _, d in kit:GetChildren() do
				if d:IsA("BasePart") and d:GetAttribute("EH_VanPaint") == true and d:GetAttribute("EH_Bay") == bay then
					found = d
					break
				end
			end
		end
		if not found then
			for _, d in g:GetChildren() do
				if
					d:IsA("BasePart")
					and d:GetAttribute("EH_Kind") == "garageVan"
					and d:GetAttribute("EH_Bay") == bay
				then
					found = d
					break
				end
			end
		end
		if found then
			bodies[bay] = found
		end
		return found
	end

	local function vanView(m: Instance): LobbyLook.VanView
		local seats = VanRules.decodeSeats(m:GetAttribute("Seats"))
		return {
			bay = tonumber(m:GetAttribute("Bay")) or 0,
			mode = tostring(m:GetAttribute("Mode") or "free"),
			crewId = tonumber(m:GetAttribute("CrewId")) or 0,
			leaderId = tonumber(m:GetAttribute("LeaderId")) or 0,
			waiting = tonumber(m:GetAttribute("Waiting")) or 0,
			size = #seats,
			cap = tonumber(m:GetAttribute("Size")),
			privacy = m:GetAttribute("Privacy") :: string?,
			held = tonumber(m:GetAttribute("Held")) or 0,
		}
	end

	-- Friends of yours in this server, as far as this client knows (the van card's SIT; the server checks again).
	local friendCache: { [number]: boolean } = {}
	local function isFriend(userId: number): boolean
		local known = friendCache[userId]
		if known ~= nil then
			return known
		end
		friendCache[userId] = false
		task.spawn(function()
			local ok, res = pcall(function()
				return localPlayer:IsFriendsWithAsync(userId)
			end)
			friendCache[userId] = ok and res == true
		end)
		return false
	end

	-- You, as the van rules see you: your crew from the garage sync, your seat from the vans' attributes.
	local function me(): LobbyLook.Me
		local g = state.garage or {}
		local m: LobbyLook.Me = {
			userId = localPlayer.UserId,
			crewId = tonumber(g.crewId) or 0,
			leader = g.leader == localPlayer.UserId,
			crewSize = #(g.members or {}),
			seatedBay = nil,
			ready = false,
		}
		local gm = garage()
		local vans = gm and gm:FindFirstChild("Vans")
		if vans then
			for _, van in vans:GetChildren() do
				for _, s in VanRules.decodeSeats(van:GetAttribute("Seats")) do
					if s.userId == localPlayer.UserId and s.seated and s.seat > 1 then
						m.seatedBay = tonumber(van:GetAttribute("Bay"))
						m.ready = s.ready
					end
				end
			end
		end
		return m
	end

	local function vanModel(bay: number): Instance?
		local g = garage()
		local vans = g and g:FindFirstChild("Vans")
		return vans and vans:FindFirstChild("Van" .. bay)
	end

	-- This frame's targets: the stations, then every van point that offers you something.
	local function collect(who: LobbyLook.Me)
		table.clear(items)
		local g = garage()
		local anchors = g and g:FindFirstChild("Anchors")
		if not anchors then
			return
		end
		for _, st in HD.STATIONS do
			local a = anchors:FindFirstChild(st.anchor)
			if a and a:IsA("BasePart") then
				local t = st.target
				local pos = (a.CFrame * CFrame.new(t[1], t[2], -t[3])).Position
				local ad = adorneeFor(st.anchor)
				table.insert(items, {
					id = "st:" .. st.anchor,
					kind = "station",
					station = st,
					verb = st.verb,
					pos = pos,
					radius = t[4],
					part = ad or a,
					adornee = ad,
					anchor = a,
				})
			end
		end
		local vans = g and g:FindFirstChild("Vans")
		if not vans then
			return
		end
		for _, m in vans:GetChildren() do
			local view = vanView(m)
			local body = vanBody(view.bay)
			for _, point in POINTS do
				local p = m:FindFirstChild(POINT_PART[point])
				local verb = LobbyLook.vanVerb(if view.mode == "free" then nil else view, point, who)
				if p and p:IsA("BasePart") and verb and body then
					table.insert(items, {
						id = "van:" .. view.bay .. ":" .. point,
						kind = "van",
						verb = verb,
						bay = view.bay,
						view = view,
						point = point,
						pos = p.Position,
						radius = tonumber(p:GetAttribute("Radius")) or 2,
						part = body,
						adornee = body,
					})
				end
			end
		end
	end

	local function keyCap(): string
		return KeyHints.prompt(Common.device())
	end

	local function promptFor(verb: string, it: any?): any
		local locked = LobbyLook.LOCKED[verb] == true
		local text = Strings.LOBBY_VERB[verb] or string.upper(verb)
		if verb == "wait" and it and it.view then
			text = Strings.lobbyWaiting(it.view.waiting)
		elseif verb == "paint" and it then
			local m = vanModel(it.bay)
			local nextN = VanRules.nextPaint({ paint = tonumber(m and m:GetAttribute("Paint")) or 0 } :: any)
			local p = HD.VAN.PAINTS[nextN]
			text = Strings.lobbyPaint(if p then p.name else "")
		elseif verb == "style" and it then
			local m = vanModel(it.bay)
			local nextN = VanRules.nextStyle({ style = tonumber(m and m:GetAttribute("Style")) or 1 })
			local s = HD.VAN.STYLES[nextN]
			text = Strings.lobbyStyle(if s then s.name else "")
		end
		local colour = if locked
			then Palette.steel
			elseif verb == "go" or verb == "solo" then Palette.exit
			else Palette.gold
		return { verb = verb, text = text, colour = colour, key = if locked then nil else keyCap(), locked = locked }
	end

	---------------------------------------------------------------- stations
	local function setRoam(on: boolean)
		state.lobbyRoam = on
		if not on then
			hud.lobby.set(false, nil, nil)
			hud.party.setCard(nil, nil)
			deps.look.updateLobby({})
		end
	end

	local function closeStation()
		local f = focus
		if not f then
			return
		end
		focus = nil
		camera.setShot(nil)
		hud.closeStation()
		hud.wardrobe.close()
		hud.party.close()
		Common.blockTouch("hideoutStation", false)
	end

	-- YOUR VAN: the PARTY sheet for your van (no camera move: you stand at your van; the sheet frees the cursor).
	local function openParty(bay: number)
		local r = root()
		if not r then
			return
		end
		local f = { verb = "party", bay = bay, startPos = r.Position, opened = true, t0 = os.clock() }
		focus = f
		setRoam(false)
		hud.party.open(bay, closeStation)
		Sound.play("UIToggle")
	end

	local function invite()
		local flags = ReplicatedStorage:FindFirstChild("LiveFlags")
		if flags and flags:GetAttribute("invites") == false then
			hud.toast(Strings.INVITE_NONE)
			return
		end
		task.spawn(function()
			local ok, can = pcall(function()
				return SocialService:CanSendGameInviteAsync(localPlayer)
			end)
			if not (ok and can) then
				hud.toast(Strings.INVITE_NONE)
				return
			end
			if deps.ui then
				deps.ui("InviteOpened", "invite")
			end
			pcall(function()
				SocialService:PromptGameInvite(localPlayer)
			end)
		end)
	end

	hud.invite = invite -- the Quick Crew sheet's INVITE FRIENDS (Hud/Garage)

	local function watchIntro()
		if playingIntro or Cinematic.isPlaying() then
			return
		end
		local pg = localPlayer:FindFirstChildOfClass("PlayerGui")
		playingIntro = true
		setRoam(false)
		local cine = Cinematic.play({
			gui = pg,
			director = camera,
			reduced = deps.reduced,
			tier = if deps.tier then deps.tier() else nil,
			onEnd = function()
				playingIntro = false
			end,
		})
		if cine == nil then
			playingIntro = false
		end
	end

	-- The crew's picked job as one key ("" = none; the daily vault is index 0 with its day).
	local function jobKey(): string
		local g = state.garage
		if not g or g.job == nil then
			return ""
		end
		return tostring(g.job) .. ":" .. tostring(g.jobDay or "")
	end

	local function openStation(it: any)
		local st = it.station
		local verb = st.verb
		if verb == "tv" then
			watchIntro()
			return
		elseif verb == "invite" then
			invite()
			return
		end
		local r = root()
		local cam = workspace.CurrentCamera
		if not (r and cam) then
			return
		end
		local face = it.anchor.CFrame.LookVector
		local eye, at = LobbyLook.focusFrame(t3(it.pos), face.X, face.Z, st.cam)
		local f = {
			verb = verb,
			t0 = os.clock(),
			from = cam.CFrame,
			fromFov = cam.FieldOfView,
			to = CFrame.lookAt(v3(eye), v3(at)),
			fov = st.cam.fov,
			startPos = r.Position,
			opened = false,
			job = jobKey(),
			yaw = math.deg(math.atan2(-r.CFrame.LookVector.X, -r.CFrame.LookVector.Z)),
		}
		focus = f
		setRoam(false)
		Common.blockTouch("hideoutStation", true)
		local reduced = deps.reduced and deps.reduced()
		camera.setShot(function(): (CFrame?, number?)
			if focus ~= f then
				return nil, nil
			end
			local elapsed = os.clock() - f.t0
			local u = LobbyLook.ease(elapsed, reduced)
			local to = f.to
			if verb == "wardrobe" then
				local rr = root()
				if rr then
					local e, a = LobbyLook.orbit(t3(rr.Position), f.yaw, elapsed, reduced)
					to = CFrame.lookAt(v3(e), v3(a))
				end
			end
			if u >= 1 and not f.opened then
				f.opened = true
				if verb == "jobs" then
					hud.openStation("board", closeStation)
				elseif verb == "laptop" then
					hud.openStation("laptop", closeStation)
				elseif verb == "quickCrew" then
					hud.openStation("crew", closeStation)
				elseif verb == "wardrobe" then
					hud.wardrobe.open(closeStation)
				end
			end
			local fov = f.fromFov + (f.fov - f.fromFov) * u
			return f.from:Lerp(to, u), fov
		end)
		Sound.play("UIToggle")
	end

	---------------------------------------------------------------- use
	local function use()
		if not state.lobbyRoam or departing then
			return
		end
		local p = lastPrompt
		local it = lastItem
		if not p or p.locked then
			if p and p.locked then
				Sound.play("UIError")
			end
			return
		end
		if it and it.kind == "station" then
			openStation(it)
			return
		end
		if p.verb == "party" and it then
			openParty(it.bay)
			return
		end
		local bay = if it then it.bay else 0
		local nextPaint = nil
		if p.verb == "paint" and it then
			local m = vanModel(it.bay)
			nextPaint = VanRules.nextPaint({ paint = tonumber(m and m:GetAttribute("Paint")) or 0 } :: any)
		elseif p.verb == "style" and it then
			local m = vanModel(it.bay)
			nextPaint = VanRules.nextStyle({ style = tonumber(m and m:GetAttribute("Style")) or 1 })
		end
		local action = LobbyLook.action(p.verb, bay, nextPaint)
		if action then
			deps.send(action)
			if deps.hands then
				deps.hands("press")
			end
			Sound.play("UIConfirm")
			if p.verb == "pick" then
				FirstTime.markSeen("hideout")
			end
		end
	end

	---------------------------------------------------------------- the first-visit hint
	local function hideHint()
		if hint then
			hint:Destroy()
			hint = nil
		end
	end

	local function updateHint(who: LobbyLook.Me, now: number)
		local g = state.garage
		local want = g ~= nil
			and (tonumber(g.van) or 0) == 0
			and who.leader
			and not FirstTime.seen("hideout")
			and FirstTime.status() ~= "pending"
		if not want then
			hideHint()
			return
		end
		local r = root()
		local gm = garage()
		local vans = gm and gm:FindFirstChild("Vans")
		if not (r and vans) then
			return
		end
		local list = {}
		for _, m in vans:GetChildren() do
			local door = m:FindFirstChild("Door")
			if door and door:IsA("BasePart") then
				table.insert(list, {
					bay = tonumber(m:GetAttribute("Bay")) or 0,
					x = door.Position.X,
					z = door.Position.Z,
					free = m:GetAttribute("Mode") == "free",
				})
			end
		end
		local bay = LobbyLook.nearestFree(list, r.Position.X, r.Position.Z)
		local m = bay and vanModel(bay)
		local door = m and m:FindFirstChild("Door")
		if not (door and door:IsA("BasePart")) then
			hideHint()
			return
		end
		local b = hint
		if not b then
			local made = Instance.new("BillboardGui")
			made.Name = "EH_PickAVan"
			made.AlwaysOnTop = true
			made.LightInfluence = 0
			made.Size = UDim2.fromOffset(HD.HINT.size[1], HD.HINT.size[2])
			local chip = Ui.panel(made, { Size = UDim2.fromScale(1, 1) }, Palette.gold)
			local label = Ui.label(chip, {
				Size = UDim2.new(1, -12, 1, -8),
				Position = UDim2.fromOffset(6, 4),
				TextSize = 28,
				TextColor3 = Palette.gold,
				Text = Strings.PICK_A_VAN,
			})
			Ui.iconWord(label, "van", "left", 32)
			made.Parent = localPlayer:FindFirstChildOfClass("PlayerGui")
			hint = made
			b = made
		end
		local hb = b :: BillboardGui
		hb.Adornee = door
		local bob = if Ui.reducedMotion() then 0 else math.sin(now * 2.4) * HD.HINT.bob
		hb.StudsOffsetWorldSpace = Vector3.new(0, HD.HINT.up - HD.VAN.POINTS.door[2] + bob, 0)
	end

	---------------------------------------------------------------- Quick Crew: the chip, the arrow, the mark
	local function hideQuickGuide()
		if quickArrow then
			quickArrow:Destroy()
			quickArrow = nil
		end
		if quickMark then
			quickMark:Destroy()
			quickMark = nil
		end
	end

	local function stopLooking()
		deps.send({ op = "unquick" })
		Sound.play("UIBack")
	end

	-- Every lobby frame: your Quick Crew state from the server's attributes (QuickCrew, QuickBay).
	local function updateQuick(now: number)
		local q = tostring(localPlayer:GetAttribute("QuickCrew") or "")
		local bay = tonumber(localPlayer:GetAttribute("QuickBay")) or 0
		hud.lobby.setQuick(q, stopLooking)
		local m = if q == "matched" and bay > 0 then vanModel(bay) else nil
		local door = m and m:FindFirstChild("Door")
		local r = root()
		if not (door and door:IsA("BasePart") and r) then
			hideQuickGuide()
			return
		end
		local A = HD.QUICK.ARROW
		local x, z, yaw, show = LobbyLook.arrow({ r.Position.X, r.Position.Z }, { door.Position.X, door.Position.Z })
		local arrow = quickArrow
		if not arrow then
			local made = Instance.new("WedgePart")
			made.Name = "EH_QuickArrow"
			made.Anchored = true
			made.CanCollide = false
			made.CanTouch = false
			made.CanQuery = false
			made.CastShadow = false
			made.Material = Enum.Material.Neon
			made.Color = Palette.gold
			made.Size = Vector3.new(A.size[1], A.size[2], A.size[3])
			made.Parent = workspace
			quickArrow = made
			arrow = made
		end
		local a = arrow :: BasePart
		local bob = if Ui.reducedMotion() then 0 else math.sin(now * 3) * A.bob
		local floorY = r.Position.Y - 3 + A.up + bob
		-- a wedge's slope rises toward its local -Z: laid flat, its thin edge points along the look direction
		a.CFrame = CFrame.new(x, floorY, z) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.Angles(math.rad(-90), 0, 0)
		a.Transparency = if show then 0.15 else 1
		local mark = quickMark
		if not mark then
			local made = Instance.new("BillboardGui")
			made.Name = "EH_QuickMark"
			made.AlwaysOnTop = true
			made.LightInfluence = 0
			made.Size = UDim2.fromOffset(HD.QUICK.BILLBOARD.size[1], HD.QUICK.BILLBOARD.size[2])
			local chip = Ui.panel(made, { Size = UDim2.fromScale(1, 1) }, Palette.gold)
			local label = Ui.label(chip, {
				Size = UDim2.new(1, -12, 1, -8),
				Position = UDim2.fromOffset(6, 4),
				TextSize = 26,
				TextColor3 = Palette.gold,
				Text = Strings.QUICK_YOUR_VAN,
			})
			Ui.iconWord(label, "van", "left", 30)
			made.Parent = localPlayer:FindFirstChildOfClass("PlayerGui")
			quickMark = made
			mark = made
		end
		local mb = mark :: BillboardGui
		mb.Adornee = door
		mb.StudsOffsetWorldSpace = Vector3.new(0, HD.QUICK.BILLBOARD.up - HD.VAN.POINTS.door[2] + bob, 0)
	end

	---------------------------------------------------------------- the drive
	local function stopDrive()
		local d = drive
		drive = nil
		if d then
			d.stop()
		end
		hud.lobby.setSkip(false, nil)
	end

	local function wipe()
		local doors = deps.doors
		if doors then
			doors.closeFor(Config.Presentation.DOORS.HOLD_MAX_SECONDS)
		end
	end

	-- Msg "Depart" { bay, seconds, paint }: GO was accepted for your crew.
	function h.depart(msg: any)
		if state.where ~= "garage" then
			return
		end
		closeStation()
		setRoam(false)
		hideHint()
		departing = true
		local bay = tonumber(msg and msg.bay) or 1
		local reduced = deps.reduced and deps.reduced()
		if reduced then
			wipe() -- reduced motion: the wipe at once, no drive
			return
		end
		task.delay(HD.VAN.DOOR_SECONDS, function()
			if not departing or state.where ~= "garage" or drive then
				return
			end
			local d
			d = Drive.play({
				bay = bay,
				director = camera,
				shake = Settings.get("shake") ~= false,
				onEnd = function()
					hud.lobby.setSkip(false, nil)
					wipe()
					task.delay(Config.Presentation.DOORS.CLOSE_SECONDS + 0.05, function()
						if drive == d then
							stopDrive()
						end
					end)
				end,
			})
			drive = d
			hud.lobby.setSkip(true, function()
				if drive then
					drive.skip()
				end
			end)
		end)
	end

	-- Entering the garage (a garage Sync); payload = state.garage.
	function h.enter()
		stopDrive()
		closeStation()
		departing = false
		if state.garage and state.garage.lobby == true then
			setRoam(true)
		end
	end

	-- Leaving for a heist (or the preparing card): everything lobby goes.
	function h.leave()
		stopDrive()
		closeStation()
		departing = false
		setRoam(false)
		hideHint()
		hideQuickGuide()
		hud.lobby.hide()
		hud.party.setCard(nil, nil)
	end

	-- A garage sync while you are in the garage (your crew, your van, the job changed).
	function h.refresh()
		local f = focus
		if f and f.verb == "party" then
			local g = state.garage
			if not (g and g.leader == localPlayer.UserId and (tonumber(g.van) or 0) == f.bay) then
				closeStation() -- no longer the leader of that van (it moved, the crew changed)
				setRoam(true)
			else
				hud.party.refresh()
			end
			return
		end
		if f and (f.verb == "jobs" or f.verb == "laptop") and jobKey() ~= f.job then
			-- a job was picked on the board (or the laptop's daily vault): back to the hideout, go to the van
			closeStation()
			setRoam(true)
		end
	end

	function h.isActive(): boolean
		return state.where == "garage" and state.garage ~= nil and state.garage.lobby == true
	end

	-- Every frame in the garage.
	function h.update(now: number)
		if not h.isActive() then
			return
		end
		if playingIntro and not Cinematic.isPlaying() then
			playingIntro = false
		end
		local who = me()
		if focus then
			local r = root()
			if r and (r.Position - focus.startPos).Magnitude > HD.FOCUS_LEAVE_STUDS then
				closeStation()
			else
				return
			end
		end
		if departing or playingIntro or drive then
			hideQuickGuide()
			return
		end
		if not state.lobbyRoam then
			setRoam(true)
		end
		updateHint(who, now)
		updateQuick(now)
		collect(who)
		-- diorama / classic: what you face from your head, not the camera's ray
		local idx = deps.look.updateLobby(items, function(it: any): boolean
			return LobbyLook.LOCKED[it.verb] == true
		end, state.fpView ~= true)
		local it = if idx then items[idx] else nil
		local verb = if it then it.verb else nil
		-- seated in a van (not the driver): READY / not ready wherever you look
		if who.seatedBay then
			local m = vanModel(who.seatedBay)
			local sv = m and LobbyLook.seatedVerb(who, vanView(m))
			if sv then
				verb, it = sv, { kind = "seat", bay = who.seatedBay }
			end
		end
		lastItem = it
		lastPrompt = if verb then promptFor(verb, it) else nil
		hud.lobby.set(true, lastPrompt, use)
		-- the read-only card of someone else's van (or your crew's, if you do not lead it)
		local card = nil
		if
			it
			and it.kind == "van"
			and it.view
			and it.view.mode ~= "free"
			and not (who.leader and it.view.crewId == who.crewId)
		then
			card = LobbyLook.vanCard(it.view, who, {
				friend = isFriend(it.view.leaderId),
				quick = (tonumber(localPlayer:GetAttribute("QuickBay")) or 0) == it.bay,
			})
		end
		local cardBay = if it then it.bay else 0
		hud.party.setCard(
			card,
			if card and card.sit
				then function()
					deps.send({ op = "sit", bay = cardBay })
					Sound.play("UIConfirm")
				end
				else nil
		)
	end

	---------------------------------------------------------------- input
	local function backPressed(): boolean
		if focus then
			closeStation()
			return true
		end
		return false
	end
	ContextActionService:BindAction("HideoutUse", function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin or not h.isActive() then
			return Enum.ContextActionResult.Pass
		end
		if drive then
			drive.skip()
			return Enum.ContextActionResult.Sink
		end
		if backPressed() then
			return Enum.ContextActionResult.Sink
		end
		if state.lobbyRoam then
			use()
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(Common.keyCodes("use")))
	ContextActionService:BindAction("HideoutBack", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin and h.isActive() and backPressed() then
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(Common.keyCodes("back")))
	ContextActionService:BindAction("HideoutPartyGo", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin and h.isActive() and hud.party.isOpen() then
			hud.party.go()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonY)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not h.isActive() then
			return
		end
		-- Esc closes a station or the PARTY sheet (Roblox may also open its menu: harmless)
		if input.KeyCode == Enum.KeyCode.Escape and focus then
			backPressed()
			return
		end
		if drive and not processed then
			local t = input.UserInputType
			if
				t == Enum.UserInputType.Keyboard
				or t == Enum.UserInputType.Touch
				or t == Enum.UserInputType.MouseButton1
			then
				drive.skip()
			end
			return
		end
		if
			not processed
			and input.UserInputType == Enum.UserInputType.MouseButton1
			and state.lobbyRoam
			and camera.cursorLocked()
		then
			use()
		end
	end)

	return h
end

return Hideout
