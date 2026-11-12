--!strict
-- Levels/Catalog: the launch level specs in play order (MASTERPLAN §4.2). Each
-- entry is a LevelSpec table; compile with Sim/LevelSpec.compile. The order matches
-- Config.Data.LEVEL_ORDER through each spec's `dataId` (tests). The daily vaults
-- are a separate rotation: Levels/DailyVaults.

return table.freeze({
	require("./L1_BackRoom"),
	require("./L2_TwoDoors"),
	require("./L3_LightsOut"),
	require("./L4_NightClerk"),
	require("./L5_CloneParty"),
	require("./L6_BigScoreBank"),
})
