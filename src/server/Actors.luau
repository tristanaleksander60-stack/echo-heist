-- Registry of everything that can stand on plates, carry loot, trip lasers and
-- be seen by the guard: real player characters AND echoes. Mechanisms only
-- look at actors, so echoes automatically work everywhere a player does.

export type Actor = {
	kind: "player" | "echo",
	model: Model,
	root: BasePart,
	owner: Player,
	carrying: string?, -- loot id
	alive: boolean,
	immuneUntil: number,
	echoIndex: number?,
}

local Actors = {}

local byPlayer: { [Player]: Actor } = {}
local echoes: { Actor } = {}

function Actors.setPlayerCharacter(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local actor: Actor = {
		kind = "player",
		model = character,
		root = root,
		owner = player,
		carrying = nil,
		alive = true,
		immuneUntil = 0,
	}
	byPlayer[player] = actor
	return actor
end

function Actors.forPlayer(player: Player): Actor?
	local a = byPlayer[player]
	if a and a.alive and a.model.Parent then
		return a
	end
	return nil
end

function Actors.removePlayer(player: Player)
	local a = byPlayer[player]
	if a then
		a.alive = false
	end
	byPlayer[player] = nil
end

function Actors.addEcho(owner: Player, model: Model, root: BasePart, echoIndex: number): Actor
	local actor: Actor = {
		kind = "echo",
		model = model,
		root = root,
		owner = owner,
		carrying = nil,
		alive = true,
		immuneUntil = 0,
		echoIndex = echoIndex,
	}
	table.insert(echoes, actor)
	return actor
end

function Actors.removeEcho(actor: Actor)
	actor.alive = false
	local i = table.find(echoes, actor)
	if i then
		table.remove(echoes, i)
	end
	if actor.model.Parent then
		actor.model:Destroy()
	end
end

function Actors.clearEchoes(owner: Player?)
	for i = #echoes, 1, -1 do
		local a = echoes[i]
		if owner == nil or a.owner == owner then
			Actors.removeEcho(a)
		end
	end
end

function Actors.echoCount(): number
	return #echoes
end

-- Every live actor (players first, then echoes).
function Actors.all(): { Actor }
	local out = {}
	for _, a in byPlayer do
		if a.alive and a.model.Parent and a.root.Parent then
			table.insert(out, a)
		end
	end
	for _, a in echoes do
		if a.alive and a.root.Parent then
			table.insert(out, a)
		end
	end
	return out
end

-- Every model belonging to an actor (used to exclude them from guard raycasts).
function Actors.models(): { Instance }
	local out = {}
	for _, a in Actors.all() do
		table.insert(out, a.model)
	end
	return out
end

return Actors
