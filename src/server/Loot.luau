-- Loot items: gold bars and the diamond. One item per carrier.
-- States: "idle" (on its table), "carried" (welded above a carrier's head),
-- "banked" (delivered to the van; stays banked across loops until the heist resets).

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Loot = {}

type Item = {
	id: string,
	value: number,
	part: BasePart,
	prompt: ProximityPrompt,
	origin: CFrame,
	state: "idle" | "carried" | "banked",
	weld: WeldConstraint?,
	carrier: any?, -- Actor
}

local items: { [string]: Item } = {}
local order: { string } = {}
local folder: Folder
local bankedCount = 0

-- Set by the coordinator: called when a real player triggers a loot prompt.
Loot.onPromptTriggered = nil :: ((player: Player, id: string) -> ())?

local function makePart(kind: string): BasePart
	local p = Instance.new("Part")
	p.Name = kind
	p.Anchored = true
	p.CanCollide = false
	p.Massless = true
	p.Material = Enum.Material.Neon
	if kind == "Diamond" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(2.2, 2.2, 2.2)
		p.Color = Color3.fromRGB(120, 230, 255)
	else
		p.Size = Vector3.new(2.6, 1, 1.3)
		p.Color = Color3.fromRGB(255, 200, 40)
	end
	return p
end

function Loot.init(levelFolder: Instance, spots: { [string]: CFrame })
	folder = Instance.new("Folder")
	folder.Name = "Loot"
	folder.Parent = levelFolder

	for _, def in Config.LOOT do
		local part = makePart(def.kind)
		part.CFrame = spots[def.id]
		part.Parent = folder

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Grab"
		prompt.ObjectText = def.kind == "Diamond" and "Diamond ($" .. def.value .. ")" or "Gold ($" .. def.value .. ")"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = def.kind == "Diamond" and 10 or 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = part

		local item: Item = {
			id = def.id,
			value = def.value,
			part = part,
			prompt = prompt,
			origin = spots[def.id],
			state = "idle",
			weld = nil,
			carrier = nil,
		}
		items[def.id] = item
		table.insert(order, def.id)

		prompt.Triggered:Connect(function(player)
			if Loot.onPromptTriggered then
				Loot.onPromptTriggered(player, def.id)
			end
		end)
	end
end

function Loot.position(id: string): Vector3?
	local item = items[id]
	return item and item.part.Position
end

local function park(item: Item, cf: CFrame)
	if item.weld then
		item.weld:Destroy()
		item.weld = nil
	end
	item.part.Anchored = true
	item.part.CFrame = cf
	item.part.Parent = folder
	item.carrier = nil
end

-- Attach an idle item to an actor. Returns true on success.
function Loot.grab(actor: any, id: string): boolean
	local item = items[id]
	if not item or item.state ~= "idle" or actor.carrying ~= nil then
		return false
	end
	if (actor.root.Position - item.part.Position).Magnitude > Config.INTERACT_RANGE then
		return false
	end
	item.state = "carried"
	item.carrier = actor
	item.prompt.Enabled = false
	item.part.Anchored = false
	item.part.CFrame = actor.root.CFrame * CFrame.new(0, 3.4, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = actor.root
	weld.Part1 = item.part
	weld.Parent = item.part
	item.weld = weld
	actor.carrying = id
	return true
end

-- Return whatever the actor carries to its table.
function Loot.drop(actor: any)
	local id = actor.carrying
	actor.carrying = nil
	if not id then
		return
	end
	local item = items[id]
	if item and item.state == "carried" then
		park(item, item.origin)
		item.state = "idle"
		item.prompt.Enabled = true
	end
end

-- Deliver the carried item. Returns its value (0 if nothing).
function Loot.bank(actor: any): number
	local id = actor.carrying
	actor.carrying = nil
	if not id then
		return 0
	end
	local item = items[id]
	if not item or item.state ~= "carried" then
		return 0
	end
	bankedCount += 1
	item.state = "banked"
	item.prompt.Enabled = false
	-- Stack banked loot in front of the van so progress is visible in the world.
	park(item, CFrame.new(-6 + (bankedCount - 1) * 2.4, 0.6, -12.5))
	return item.value
end

-- New loop: everything not banked goes back to its table.
function Loot.resetUnbanked()
	for _, id in order do
		local item = items[id]
		if item.state == "carried" then
			if item.carrier then
				item.carrier.carrying = nil
			end
			park(item, item.origin)
			item.state = "idle"
			item.prompt.Enabled = true
		end
	end
end

-- New heist: everything back, banked included.
function Loot.resetAll()
	bankedCount = 0
	for _, id in order do
		local item = items[id]
		if item.carrier then
			item.carrier.carrying = nil
		end
		park(item, item.origin)
		item.state = "idle"
		item.prompt.Enabled = true
	end
end

function Loot.bankedValue(): number
	local v = 0
	for _, item in items do
		if item.state == "banked" then
			v += item.value
		end
	end
	return v
end

function Loot.totalValue(): number
	local v = 0
	for _, item in items do
		v += item.value
	end
	return v
end

function Loot.models(): Instance
	return folder
end

return Loot
