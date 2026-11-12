-- Echo Heist server entry point. All logic lives in modules (so tests can boot them too).
-- The data layer starts first and never blocks the game: if it fails to start, the
-- heist still runs (it only stops saving), because solo must always be playable.
local okData, dataErr = pcall(function()
	require(script:WaitForChild("Data"):WaitForChild("DataService")).start()
end)
if not okData then
	warn("[Server] data layer failed to start; progress is not saved: " .. tostring(dataErr))
end
require(script:WaitForChild("Main")).start()
