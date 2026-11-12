-- Echo Heist server entry point. All logic lives in modules (so tests can boot them too).
-- The data layer starts first and never blocks the game: if it fails to start, the
-- heist still runs (it only stops saving), because solo must always be playable.
-- Config.GAME_MODE picks the game: "v01" (default, the v0.1 prototype) or "sim"
-- (the HeistSim path in Heist/; it supplies the medal rules before data starts).
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

if Config.GAME_MODE == "sim" then
	local HeistService = require(script:WaitForChild("Heist"):WaitForChild("HeistService"))
	local okSimData, simDataErr = pcall(function()
		local DataService = require(script:WaitForChild("Data"):WaitForChild("DataService"))
		HeistService.configureData(DataService)
		DataService.start()
	end)
	if not okSimData then
		warn("[Server] data layer failed to start; progress is not saved: " .. tostring(simDataErr))
	end
	HeistService.start()
	return
end

local okData, dataErr = pcall(function()
	require(script:WaitForChild("Data"):WaitForChild("DataService")).start()
end)
if not okData then
	warn("[Server] data layer failed to start; progress is not saved: " .. tostring(dataErr))
end
require(script:WaitForChild("Main")).start()
