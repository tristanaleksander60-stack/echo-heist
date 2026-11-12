--!strict
-- Heist/LevelDress: visual-only dressing per level (LevelSpec id), read by Heist/KitPlan. The sim never
-- reads this: nothing here moves a plate, door, loot point or collider, so recordings stay valid
-- (docs/audit/LEVELS.md §4 P0-3 / P0-4, PLAN_STEAM_PLUS §4.1 W2 and §7). Positions are level space.
--
--   rooms    = { { x, z } }: room-centre lamps. Plate lamps (one over each plate) and the hero lamp over
--              the goal loot are automatic (KitPlan.lamps); a level without an entry gets automatic room
--              lamps (one per band between X-axis walls), so no daily vault stays black.
--   windows  = { { axis, line } }: wall runs on that line tile Wall_Window_8x12 on their 8-wide modules,
--              nearest the doorway first (L1: the cash glitters through glass, MASTERPLAN §7.5).
--   displays = { [loot id] = "Safe" | "CashRegister" }: the kit display the goal sits on (the till is
--              automatic: a top Cash item sits on a CashRegister).
--   hero     = { x, z }: overrides the hero lamp's spot (default: over the goal loot).

export type Dress = {
	rooms: { { number } }?,
	windows: { { axis: string, line: number } }?,
	displays: { [string]: string }?,
	hero: { number }?,
}

local LevelDress: { [string]: Dress } = {
	-- L1: plate (10, -8), hero over the cash (0, -28), the counter (-10, -2); windows either side of the
	-- back-room door.
	cs1_back_room = {
		rooms = { { -10, -2 } },
		windows = { { axis = "X", line = -20 } },
	},
	-- L2: plates (-10, -8) and (10, -8), the middle room (0, -26), hero over the safe (0, -40).
	cs2_two_doors = {
		rooms = { { -10, 2 }, { 0, -26 } },
		displays = { Safe = "Safe" },
	},
	-- L3: plates (10, -8) and (12, -26), hero (0, -40); the grid keeps its own glow.
	cs3_lights_out = {
		rooms = { { -8, -2 } },
		displays = { Register = "CashRegister" },
	},
	-- L4: plates (10, -8) and (-12, -23), Gus's post (13, -30), hero (0, -42).
	cs4_night_clerk = {
		rooms = { { -8, -2 }, { 13, -30 } },
		displays = { NightDeposit = "Safe" },
	},
	-- L5 Clone Party: the two aisles (-4, -14) and (4, -14), the till hero (over the till at (-8.5, -1)), the
	-- office desk lamp (0, -34).
	cs5_clone_party = {
		rooms = { { -4, -14 }, { 4, -14 }, { 0, -34 } },
	},
	-- L6: plates (-12, -10), (-16, -18), (-13, -42), (13, -42); lobby (0, -6), hall (0, -24), scale room
	-- (0, -42); the gold hero (0, -55).
	bk1_big_score = {
		rooms = { { 0, -6 }, { 0, -24 }, { 0, -42 } },
	},
}

return table.freeze(LevelDress)
