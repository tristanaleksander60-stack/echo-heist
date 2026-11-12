--!strict
-- L1 "Back Room" (Corner Shop, FTUE). MASTERPLAN §4.2 row 1, §7.5.
-- Teaches: a plate holds a door; rewind; "your clone stops where you stop".
-- Run 1 auto-ends after 2.0 s on the plate (forced quick rewind), so the first
-- clone always stands on it; if run 1 ends off the plate, the next runs auto-end the
-- same way until one has (untilDone). Par 1 clone, cap 3 (par + 2), 30 s runs, no deadline.
-- Golden solution: PLACEHOLDER scripted run in tests/sim/Solutions.luau until the
-- owner records levels/cs1_back_room.solution.bin in Studio (§8.9).

local LevelSpec = require("../Sim/LevelSpec")
local Shop = require("./Shop")

local Z_BACK = -34
local solids = Shop.shell(Z_BACK)
Shop.wallZGap(solids, -20, -16.5, 16.5, -3, 3) -- back-room partition with the door gap
-- Shop counter: blocks walking, Gus would see over it (no guard here).
table.insert(solids, { box = LevelSpec.span(-13, 0, -4, -7, 3.5, 0), sight = false })

return {
	format = 1,
	version = 1,
	id = "cs1_back_room",
	num = 101,
	dataId = "BackRoom",
	name = "Back Room",
	location = "CornerShop",
	runSeconds = 30,
	par = 1,
	cap = 3,
	goal = 100,
	deadline = "None",
	seed = 101,
	bounds = Shop.bounds(Z_BACK),
	spawns = Shop.SPAWNS,
	van = Shop.VAN,
	solids = solids,
	plates = {
		{ id = "A", box = Shop.plate(10, -8) },
	},
	doors = {
		{ id = "BackRoom", box = Shop.doorAt(-20, -3, 3), openBy = { "A" } },
	},
	loot = {
		{ id = "Cash", x = 0, y = 3, z = -28, value = 100, kind = "Cash" },
	},
	-- untilDone: a kid who taps END RUN off the plate (or lets run 1 time out) gets the
	-- auto-end again in the next run, until a clone stands on the plate.
	tutorial = { autoEnd = { runs = { 1 }, plate = "A", untilDone = true } },
	solution = "PLACEHOLDER scripted (tests/sim/Solutions.luau); human-recorded solution.bin pending",
}
