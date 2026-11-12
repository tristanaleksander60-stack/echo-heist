--!strict
-- Levels/Catalog: the launch level specs in play order (MASTERPLAN §4.2).
-- Each entry is a LevelSpec table; compile with Sim/LevelSpec.compile.
-- L5 Clone Party and L6 The Big Score: Bank are not authored yet.

return table.freeze({
	require("./L1_BackRoom"),
	require("./L2_TwoDoors"),
	require("./L3_LightsOut"),
	require("./L4_NightClerk"),
})
