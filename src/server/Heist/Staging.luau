--!strict
-- Heist/Staging: golden-frame staging on the server (docs/GOLDEN_FRAMES.md "Capture",
-- Shared/Heist/Scenario). Studio only: Staging.active() is nil unless RunService:IsStudio()
-- and the Workspace attribute EH_Scenario names a scenario, so a live server never stages.
-- HeistService asks it once at start and, for the first player, starts the scenario's level
-- instead of the FTUE or the garage. The camera framing and the hidden debug chip are the
-- client's (Heist/HeistClient reads the same attribute behind the same gate).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Codec = require(Shared:WaitForChild("Rec"):WaitForChild("Codec"))
local HeistSim = require(Shared:WaitForChild("Sim"):WaitForChild("HeistSim"))
local Scenario = require(Shared:WaitForChild("Heist"):WaitForChild("Scenario"))

local StagingTapes = require(script.Parent:WaitForChild("StagingTapes"))

local Staging = {}

-- The scenario to stage on this server, or nil (always nil outside Studio).
function Staging.active(): string?
	return Scenario.resolve(RunService:IsStudio(), workspace:GetAttribute(Scenario.ATTRIBUTE))
end

-- At server start, before any avatar template is built: CLONE_AB variant B is the stripped
-- hologram arm (no textures, no classic clothing on the clone templates).
function Staging.prepare(name: string)
	local spec = Scenario.spec(name)
	if not spec then
		return
	end
	local variant = if spec.variant then Scenario.variant(workspace:GetAttribute(Scenario.VARIANT_ATTRIBUTE)) else nil
	if variant == "B" then
		Config.Heist.CLONE_KEEP_TEXTURES = false
		Config.Heist.CLONE_KEEP_CLOTHING = false
	end
	print(string.format("[Staging] golden frame %s%s (Studio only)", name, if variant then " " .. variant else ""))
end

-- The solution recordings for G2 / CLONE_AB, decoded.
function Staging.tapes(): { any }
	local recs = {}
	for _, buf in StagingTapes.buffers() do
		local rec = Codec.decode(buf)
		if rec then
			table.insert(recs, rec)
		end
	end
	return recs
end

-- Seeds the tapes into the player's deck of a heist that has not started its first run.
function Staging.seed(inst: any, userId: number): boolean
	if inst.level.id ~= StagingTapes.LEVEL then
		warn("[Staging] the tapes are for " .. StagingTapes.LEVEL .. ", not " .. tostring(inst.level.id))
		return false
	end
	local ok = HeistSim.seedDeck(inst.sim, userId, Staging.tapes())
	if not ok then
		warn("[Staging] could not seed the deck (the first run already started?)")
	end
	return ok
end

return Staging
