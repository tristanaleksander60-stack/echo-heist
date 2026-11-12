--!strict
-- Heist/BackdropKit: hands the client the backdrop's kit meshes (PLAN_STEAM_PLUS §4.1 W4). The skyline rings are
-- uploaded kit pieces (assets/blender/backdrop.py) that only the server can load (InsertService); once KitService
-- is ready, one prepared template of each ring piece is copied to ReplicatedStorage/<Config.Backdrop.KIT_FOLDER>.
-- The client Heist/Backdrop clones four rotated copies per ring around the active heist instance or the garage.
-- Static decoration: nothing here is simulated, collides or is queried, so it never touches the sim or a
-- recording. Without the kit (Studio offline, a failed load) the folder stays empty and the client keeps its
-- facade ring, ground and sky.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local B = Config.Backdrop

local BackdropKit = {}

local started = false

local function folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(B.KIT_FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = B.KIT_FOLDER
	f.Parent = ReplicatedStorage
	return f
end

-- Copies the ring templates (pure side effects on ReplicatedStorage). Returns how many pieces were published.
function BackdropKit.publish(kit: any): number
	local f = folder()
	local n = 0
	for _, ring in B.RINGS do
		for _, name in { ring.piece, ring.windows } do
			if f:FindFirstChild(name) then
				n += 1
				continue
			end
			local part = kit.clone(name)
			if part then
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.CastShadow = false
				part.Name = name
				part.Parent = f
				n += 1
			end
		end
	end
	f:SetAttribute("Ready", true)
	f:SetAttribute("Pieces", n)
	return n
end

-- Waits for KitService in the background, then publishes (idempotent).
function BackdropKit.start(kit: any)
	if started or not B.ENABLED then
		return
	end
	started = true
	folder()
	task.spawn(function()
		local ok, ready = pcall(kit.ready, B.KIT_WAIT_SECONDS)
		if ok and (ready or kit.isReady()) then
			local okPub, err = pcall(BackdropKit.publish, kit)
			if not okPub then
				warn("[BackdropKit] publish failed: " .. tostring(err))
			end
		else
			warn("[BackdropKit] kit not ready; the backdrop keeps its facades, ground and sky")
		end
	end)
end

return BackdropKit
