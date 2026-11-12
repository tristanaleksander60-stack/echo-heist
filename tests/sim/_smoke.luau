local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local B = LevelSpec.box
local spec = {
	format = 1, version = 1, id = "t", num = 1, name = "T", runSeconds = 10, par = 1, cap = 3, goal = 100,
	deadline = "None", seed = 1,
	bounds = B(0, 5, 0, 80, 20, 80),
	spawns = { { x = 0, y = 3, z = 14 } },
	van = B(0, 3, 20, 10, 6, 6),
	solids = {},
	plates = { { id = "A", box = B(10, 2, 0, 4, 4, 4) } },
	doors = { { id = "A", box = B(0, 5, -10, 6, 10, 1), openBy = { "A" } } },
	loot = { { id = "cash", x = 0, y = 3, z = -20, value = 100 } },
}
local level = LevelSpec.compile(spec)
local sim = HeistSim.new(level, { players = { 1 } })
HeistSim.startRun(sim)
for i = 1, 300 do
	HeistSim.setInput(sim, 1, 0, 3, 14 - i * 0.1)
	if HeistSim.step(sim) ~= "Run" then break end
end
print(sim.phase, sim.tick, sim.log.n)
local EventLog = require("../../src/shared/Sim/EventLog")
for _, l in EventLog.lines(sim.log) do print(l) end
