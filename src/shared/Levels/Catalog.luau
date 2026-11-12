--!strict
-- Levels/Catalog: the launch level specs in PLAY ORDER (MASTERPLAN §4.2 and the owner
-- decision of 2026-11-12, "party break"): L1 Back Room, L2 Two Doors, L5 Clone Party,
-- L3 Lights Out, L4 Night Clerk, L6 The Big Score: Bank. Clone Party comes right
-- after L2 so "8 OF ME" lands around minute 10 of a first session instead of after
-- L4 (tests/sim/Pacing.spec.luau prints the model).
--
-- A level's design number (L1..L6) is its spec's `num` (100 + n, written into every
-- recording); its place here is the play order the garage shows and "NEXT" follows,
-- so a Catalog index is NOT the design number from 3 on. Look levels up by spec `id`
-- (or `num`), never by a hard-coded index. The order matches Config.Data.LEVEL_ORDER
-- through each spec's `dataId` (tests). Each entry is a LevelSpec table; compile with
-- Sim/LevelSpec.compile. The daily vaults are a separate rotation: Levels/DailyVaults.

return table.freeze({
	require("./L1_BackRoom"),
	require("./L2_TwoDoors"),
	require("./L5_CloneParty"), -- the party break: 8 slots, no planning, the swarm
	require("./L3_LightsOut"),
	require("./L4_NightClerk"),
	require("./L6_BigScoreBank"),
})
