-- PLACEHOLDER solutions for the launch levels (not a spec itself).
-- MASTERPLAN §8.9: golden solutions are HUMAN-RECORDED in Studio and pulled into
-- levels/<id>.solution.bin. Until the owner records them, these hand-scripted bot
-- runs prove each level is solvable at par. Replace, do not extend, once the
-- recorded buffers exist (the spec then decodes them with Rec/Codec and feeds the
-- first N runs as clones).
--
-- Each entry is a Harness plan: runs[r][playerId] = Bot steps.

local Solutions = {}

Solutions.PLACEHOLDER = true

-- L1 Back Room: run 1 stands on the plate (auto-ends after 2 s); run 2 walks
-- through the held door, grabs the cash and banks it.
Solutions.cs1_back_room = {
	runs = {
		{ [1] = { { goPlate = "A" }, { stay = true } } },
		{ [1] = { { goLoot = "Cash" }, { grab = "Cash" }, { goVan = true }, { stay = true } } },
	},
}

-- L2 Two Doors: clone 1 holds A, clone 2 holds B, run 3 takes the safe.
Solutions.cs2_two_doors = {
	runs = {
		{ [1] = { { goPlate = "A" }, { endRun = true } } },
		{ [1] = { { goPlate = "B" }, { endRun = true } } },
		{ [1] = { { goLoot = "Safe" }, { grab = "Safe" }, { goVan = true }, { stay = true } } },
	},
}

-- L3 Lights Out: clone 1 holds A (door), clone 2 walks in and holds B (grid off);
-- run 3 waits a beat for the grid, then takes the register.
Solutions.cs3_lights_out = {
	runs = {
		{ [1] = { { goPlate = "A" }, { endRun = true } } },
		{ [1] = { { go = { 0, -23 } }, { goPlate = "B" }, { endRun = true } } },
		{ [1] = { { wait = 1 }, { goLoot = "Register" }, { grab = "Register" }, { goVan = true }, { stay = true } } },
	},
}

-- L4 Night Clerk: clone 1 holds A; clone 2 slips to the coat rack (plate B, hidden)
-- while Gus faces east; run 3 crosses for the deposit during his next east turn.
-- Timings are tuned against Gus's patrol(t) (period 8.75 s).
Solutions.cs4_night_clerk = {
	runs = {
		{ [1] = { { goPlate = "A" }, { endRun = true } } },
		{
			[1] = {
				{ go = { 0, -10 } },
				{ waitUntil = 4.2 },
				{ go = { 0, -21.5 } },
				{ goPlate = "B" },
				{ endRun = true },
			},
		},
		{
			[1] = {
				{ go = { 0, -10 } },
				{ waitUntil = 6.0 },
				{ goLoot = "NightDeposit" },
				{ grab = "NightDeposit" },
				{ go = { 0, -10 } },
				{ goVan = true },
				{ stay = true },
			},
		},
	},
}

return Solutions
