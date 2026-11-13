--!strict
-- Heist/LookSync: the server side of look up / down (Config.Rookie.LOOK, Shared/Heist/LookPitch). A client's
-- Heist.Ready { op = "look", n } (shape and range already checked by the Net validator, VanRules.validReadyArg)
-- comes here: n is checked again, at most one look a player per MIN_INTERVAL is kept (the rest are dropped), and
-- the pitch in degrees goes on the player's character as the attribute LOOK.ATTRIBUTE, which replicates; every
-- client tilts the other characters' Neck and Waist by it (client Heist/LookTilt). Cosmetic only: nothing in the
-- sim reads it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local LookPitch = require(Shared:WaitForChild("Heist"):WaitForChild("LookPitch"))

local L = Config.Rookie.LOOK

local LookSync = {}

local lastAt: { [any]: number } = {}

-- One look from `key` (a Player; tests pass any key) for `character` at time `now`. Returns true when it was kept
-- and written, false when refused (a bad n, too soon, no character).
function LookSync.accept(key: any, character: Instance?, n: any, now: number): boolean
	if not LookPitch.validN(n) then
		return false
	end
	local last = lastAt[key]
	if last ~= nil and now - last < L.MIN_INTERVAL then
		return false
	end
	if character == nil or not character:IsA("Model") then
		return false
	end
	lastAt[key] = now
	local deg = LookPitch.degrees(n)
	if character:GetAttribute(L.ATTRIBUTE) ~= deg then
		character:SetAttribute(L.ATTRIBUTE, deg)
	end
	return true
end

-- A player left (or a test is done): forget the throttle.
function LookSync.forget(key: any)
	lastAt[key] = nil
end

return LookSync
