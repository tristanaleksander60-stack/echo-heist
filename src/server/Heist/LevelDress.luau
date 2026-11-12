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
--   props    = { { piece, x, z, y?, yaw? } }: the location's signature silhouette (PLAN_STEAM_PLUS §3.1, W5):
--              the kit piece's own pivot at (x, floor + y, z), yaw in degrees (0 = its front toward -Z, 180 =
--              toward the street). Visual only; tests/unit/HeistKitPlan.spec keeps each clear of every sim box,
--              plate, door, loot point, nav point and spawn.
--   street   = { { x, z } }: street lamps on the pavement (KitPlan lamp kind "street": a StreetLamp post, a warm
--              PointLight at its lantern and a big warm pool; Config.Lighting.LAMP.street). Golden-frame warm pass:
--              warm pools outside the shop front and the facade washed warm (GOLDEN_FRAMES G1).
--   rugs     = { { x, z, yaw?, sx?, sz? } }: Rug_8x6 laid flat inside the light pools (sx / sz stretch it: a
--              doormat). The unit spec keeps them off plates, doors, lasers, hides, the van zone and low solids.

export type Dress = {
	rooms: { { number } }?,
	windows: { { axis: string, line: number } }?,
	displays: { [string]: string }?,
	hero: { number }?,
	props: { { piece: string, x: number, z: number, y: number?, yaw: number? } }?,
	street: { { number } }?,
	rugs: { { x: number, z: number, yaw: number?, sx: number?, sz: number? } }?,
}

-- The Corner Shop street front (Levels/Shop: front wall at z = 10, the entrance x -4..4, the crew seats at
-- z 12.5..14, the van zone x -5..5, z 16..24): a lamp just past each end of the 24-wide storefront, on the
-- pavement, and a doormat between the door and the seats.
local SHOP_STREET = { { -12.5, 12.5 }, { 12.5, 12.5 } }
local DOORMAT = { x = 0, z = 11.4, sx = 0.5, sz = 0.3 }

local LevelDress: { [string]: Dress } = {
	-- L1: plate (10, -8), hero over the cash (0, -28), the counter (-10, -2); windows either side of the
	-- back-room door.
	cs1_back_room = {
		rooms = { { -10, -2 } },
		windows = { { axis = "X", line = -20 } },
		street = SHOP_STREET,
		-- the entrance rug (front room), the back-room rug under the cash's hero pool, the doormat
		rugs = { { x = 0, z = 5.5 }, { x = 0, z = -27 }, DOORMAT },
	},
	-- L2: plates (-10, -8) and (10, -8), the middle room (0, -26), hero over the safe (0, -40).
	cs2_two_doors = {
		rooms = { { -10, 2 }, { 0, -26 } },
		displays = { Safe = "Safe" },
		street = SHOP_STREET,
		-- the entrance (clear of the tip jar at (-8, 4)), the middle room's pool, under the safe's hero pool
		rugs = { { x = 0, z = 5 }, { x = 0, z = -26 }, { x = 0, z = -39 }, DOORMAT },
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
		-- The Toy Shop's giant toy drummer in the east front corner, turned a little toward the door: seen from
		-- the street through the entrance and in the 8 OF ME wide shot (GOLDEN_FRAMES G2).
		props = { { piece = "ToySoldier", x = 13.2, z = 1.4, yaw = 160 } },
		street = SHOP_STREET,
		-- the front area where the crew gathers (G2 wide shot), the back office under the desk lamp, the doormat,
		-- and a runner down each inner aisle (x -7..-1 and 1..7 between the shelves, z -22..-6) under the aisle lamps
		rugs = {
			{ x = 0, z = 2 },
			{ x = 0, z = -34 },
			DOORMAT,
			{ x = -4, z = -10, yaw = 90, sx = 0.9, sz = 0.9 },
			{ x = -4, z = -18, yaw = 90, sx = 0.9, sz = 0.9 },
			{ x = 4, z = -10, yaw = 90, sx = 0.9, sz = 0.9 },
			{ x = 4, z = -18, yaw = 90, sx = 0.9, sz = 0.9 },
		},
	},
	-- L6: plates (-12, -10), (-16, -18), (-13, -42), (13, -42); lobby (0, -6), hall (0, -24), scale room
	-- (0, -42); the gold hero (0, -55).
	bk1_big_score = {
		rooms = { { 0, -6 }, { 0, -24 }, { 0, -42 } },
		-- The Bank: marble columns flanking the staff door (lobby side) and in the scale room's corners (clear of
		-- the open vault door, which lies along the vault wall west of the frame), green banker's lamps on both
		-- teller counters (top at y 3.5). The room lamps carry the green (Config.Lighting.LOCATION.Bank).
		props = {
			{ piece = "Column_2x12", x = -5.5, z = -12.5 },
			{ piece = "Column_2x12", x = 5.5, z = -12.5 },
			{ piece = "Column_2x12", x = -18.5, z = -37.5 },
			{ piece = "Column_2x12", x = 18.5, z = -37.5 },
			{ piece = "Column_2x12", x = -18.5, z = -46.5 },
			{ piece = "Column_2x12", x = 18.5, z = -46.5 },
			{ piece = "BankersLamp", x = -15, z = -5, y = 3.5, yaw = 180 },
			{ piece = "BankersLamp", x = 15, z = -5, y = 3.5, yaw = 180 },
		},
	},
}

return table.freeze(LevelDress)
