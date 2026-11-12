--!strict
-- Levels/Daily/Vault: the shared frame of a daily mini-vault (MASTERPLAN §5.3,
-- §4.3 "Daily vault = advent calendar"). Every vault: 30 s runs, a fixed 5-clone
-- loadout, Dawn at run 6, one goal (first clear), bonus loot for the "biggest haul
-- today" board, and two free sweets by the door (the naive-kid guarantee: nobody
-- leaves empty-handed). Geometry reuses the Corner Shop and Bank kits.
--
-- A vault spec carries a `daily` table (read by Levels/DailyVaults, ignored by the
-- sim): order = its place in the advent sequence (1 = the launch-day vault),
-- modifiers = the vetted date-seeded modifiers CI proves it solvable with,
-- alt = {[lootId] = {B = {x, z}, C = {x, z}}} for the "loot position" modifiers.

local Config = require("../../Config")
local LevelSpec = require("../../Sim/LevelSpec")
local Shop = require("../Shop")

local Vault = {}

local L = Config.Levels

-- The common fields. `extra` (geometry, mechanisms, loot...) is merged over them.
function Vault.spec(order: number, id: string, name: string, location: string, par: number, extra: any): any
	local s: any = {
		format = 1,
		version = 1,
		id = id,
		num = 300 + order,
		name = name,
		location = location,
		runSeconds = L.DAILY_RUN_SECONDS,
		par = par,
		cap = L.DAILY_CAP,
		deadline = "Dawn",
		dawnRuns = L.DAILY_DAWN_RUNS,
		seed = 300 + order,
		spawns = Shop.SPAWNS,
		van = Shop.VAN,
		solution = "PLACEHOLDER scripted (tests/sim/Solutions.luau); human-recorded solution.bin pending",
	}
	for k, v in extra do
		s[k] = v
	end
	s.daily = s.daily or {}
	s.daily.order = order
	return s
end

-- The free sweets by the door (inside the front, either side of the entrance).
function Vault.candyJar(): any
	return { id = "CandyJar", x = 8, y = 3, z = 4, value = 10, kind = "Candy" }
end

function Vault.cookieTin(): any
	return { id = "Gingerbread", x = -8, y = 3, z = 4, value = 10, kind = "Candy" }
end

Vault.span = LevelSpec.span

return table.freeze(Vault)
