--!strict
-- Heist/FlashLimit: the one full-screen flash limiter for this client (MASTERPLAN §7.3 photosensitivity: at most
-- Config.Moments.FLASH_MAX full-screen flashes in any FLASH_WINDOW seconds, everywhere). Every flash asks here
-- first: the rewind flash (RewindDirector), the heist-complete slam flash (MomentDirector), the HUD's red
-- vignette (caught, zapped: Hud/Messages flashRed) and the Alarm Run's red pulse. A refused flash simply does
-- not play (its sound and words still do). The rule itself is Shared/Heist/MomentPlan.flashAllowed (pure).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local MomentPlan = require(Shared:WaitForChild("Heist"):WaitForChild("MomentPlan"))

local M = Config.Moments

local FlashLimit = {}

local log: { number } = {}

-- May a full-screen flash play now? Logs it when it may.
function FlashLimit.allow(now: number?): boolean
	return MomentPlan.flashAllowed(log, now or os.clock(), M.FLASH_MAX, M.FLASH_WINDOW)
end

-- Forgets the log (tests).
function FlashLimit.reset()
	table.clear(log)
end

return FlashLimit
