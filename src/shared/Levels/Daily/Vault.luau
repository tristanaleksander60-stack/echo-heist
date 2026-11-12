--!strict
-- Levels/Daily/Vault: the shared frame of a daily mini-vault (MASTERPLAN §5.3,
-- §4.3 "Daily vault = advent calendar"). Every vault: 30 s runs, a fixed 5-clone
-- loadout, Dawn at run 6, one goal (first clear), bonus loot for the "biggest haul
-- today" board, and two free sweets by the door (the naive-kid guarantee: nobody
-- leaves empty-handed). Geometry reuses the Corner Shop and Bank kits.
--
-- Haul: a vault's `haul` is all its loot (goal + bonus + sweets), so banking the
-- goal item does NOT end the heist at once: the heist clears at the end of the run
-- that met the goal (END RUN, the timer or a catch), or the moment everything is
-- banked. A kid who grabs the goal first can still bank the bonus in that run; the
-- board ranks the haul (then fewer clones, then the time in result().daily.timeMs).
--
-- A vault spec carries a `daily` table (read by Levels/DailyVaults and the HUD,
-- ignored by the sim): order = its place in the advent sequence (1 = the launch-day
-- vault), modifiers = the vetted date-seeded modifiers CI proves it solvable with,
-- alt = {[lootId] = {B = {x, z}, C = {x, z}}} for the "loot position" modifiers
-- (bonus loot only: the goal item never moves, so one human-recorded solution.bin
-- and the Ghost Hint stay valid on every modified day), and, filled in here:
-- goalItems / bonus = loot ids of the goal and of the bonus (the HUD's "+ $40 bonus"),
-- bonusValue = the bonus's $.

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
	-- Goal item(s) = loot worth the goal on its own; bonus = everything else but the sweets.
	local total = 0
	local goalItems, bonus, bonusValue = {}, {}, 0
	for _, item in s.loot do
		total += item.value
		if s.goal and item.value >= s.goal then
			table.insert(goalItems, item.id)
		elseif item.id ~= "CandyJar" and item.id ~= "Gingerbread" then
			table.insert(bonus, item.id)
			bonusValue += item.value
		end
	end
	s.haul = s.haul or total
	s.daily.goalItems = goalItems
	s.daily.bonus = bonus
	s.daily.bonusValue = bonusValue
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
