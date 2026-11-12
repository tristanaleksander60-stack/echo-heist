--!strict
-- Levels/DailyVaults: the 12 launch daily vaults (= the advent calendar in December)
-- and which one plays on a UTC day. MASTERPLAN §5.3 (D1 hook), §4.3, §10.4.
--
--   * designs[k] is the k-th vault of the advent sequence: design 1 plays on
--     Config.Levels.DAILY_FIRST_DAY (Dec 3, launch), design 12 on Dec 14, and then
--     the rotation repeats (Dec 15 = design 1 again, with a modifier).
--   * Which vault plays on a day is Data/DailyVault.vaultFor(day) (the same rule the
--     data layer uses for ornaments and the board). `number` = that rotation slot;
--     byNumber[number] is the design that slot holds. It is derived from the advent
--     order at load, so whatever the data layer's rotation is, Dec 3 + k - 1 plays
--     design k (tests/sim/Daily.spec.luau checks the whole window and the bijection).
--   * One date-seeded modifier per day from the vault's vetted list (§5.3: guard
--     speed +-10%, loot position A/B/C, lights on/off). A design's first run through
--     the advent (Dec 3-14) and any day before it play unmodified ("None").
--   * Vetted = survives ONE recording (§5.3 D1, §8.9: one human-recorded solution.bin
--     per vault, replayed by CI and by the Ghost Hint after 2 failed runs): loot
--     positions move bonus loot only, never the goal item; guard speed only where
--     Gus walks a patrol; lights off only where there is a Gus. Every (vault,
--     modifier) pair is validated, solvable at par, and cleared by the unmodified
--     solution replayed as frozen tapes (tests/sim/Daily.spec.luau). When the owner's
--     recordings land, a pair they do not survive is dropped from the list (or
--     re-recorded), not patched.
--   * Ornament naming outside the advent follows Data/DailyVault (Orn_Vault<slot>);
--     vaultFor is anchored at Dec 3 there, so slot n = design n.
--
-- Pure: day numbers come from the server (Data/Calendar.dayIndex(os.time())).

local Calendar = require("../Data/Calendar")
local Config = require("../Config")
local DailyVault = require("../Data/DailyVault")

local DailyVaults = {}

DailyVaults.designs = table.freeze({
	require("./Daily/DV01_StockingStuffer"),
	require("./Daily/DV02_TwinChimneys"),
	require("./Daily/DV03_CandyCaneLasers"),
	require("./Daily/DV04_MistletoePatrol"),
	require("./Daily/DV05_TinselCorridor"),
	require("./Daily/DV06_SnowDaySwitch"),
	require("./Daily/DV07_OrnamentScale"),
	require("./Daily/DV08_FrostyWindow"),
	require("./Daily/DV09_SleighBellAlarm"),
	require("./Daily/DV10_GingerbreadLobby"),
	require("./Daily/DV11_JingleVault"),
	require("./Daily/DV12_NightBefore"),
})

-- The vetted modifier set (§5.3). "None" = loot position A, lights on, normal Gus.
DailyVaults.MODIFIERS = table.freeze({ "None", "GuardFast", "GuardSlow", "LootB", "LootC", "LightsOff" })

local COUNT = #DailyVaults.designs
local FIRST_DAY = Calendar.dayOf(Config.Levels.DAILY_FIRST_DAY)

-- Rotation slot -> design (and back), from the data layer's own rule.
local byNumber: { [number]: any } = {}
local numberOf: { [string]: number } = {}
for k, spec in DailyVaults.designs do
	local n = DailyVault.vaultFor(FIRST_DAY + k - 1, COUNT)
	assert(byNumber[n] == nil, "DailyVaults: two designs share rotation slot " .. n)
	byNumber[n] = spec
	numberOf[spec.id] = n
end
DailyVaults.byNumber = table.freeze(byNumber)
DailyVaults.numberOf = table.freeze(numberOf)
DailyVaults.FIRST_DAY = FIRST_DAY
DailyVaults.COUNT = COUNT

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

local function has(list: { string }, name: string): boolean
	for _, v in list do
		if v == name then
			return true
		end
	end
	return false
end

-- A fresh copy of a design with one modifier applied (the design itself is never
-- changed). Errors on a modifier the design has not been vetted for.
function DailyVaults.apply(spec: any, modifier: string): any
	assert(has(DailyVaults.MODIFIERS, modifier), "DailyVaults.apply: unknown modifier " .. tostring(modifier))
	assert(
		modifier == "None" or has(spec.daily.modifiers, modifier),
		string.format("DailyVaults.apply: %s is not vetted for %s", modifier, spec.id)
	)
	local s = deepCopy(spec)
	s.daily.modifier = modifier
	local L = Config.Levels
	if modifier == "GuardFast" or modifier == "GuardSlow" then
		local mult = if modifier == "GuardFast" then L.MOD_GUARD_FAST else L.MOD_GUARD_SLOW
		for _, g in s.guards or {} do
			g.speed = (g.speed or Config.Sim.GUARD_SPEED) * mult
		end
	elseif modifier == "LightsOff" then
		s.guardVision = (s.guardVision or 1) * L.MOD_LIGHTS_OFF_VISION
	elseif modifier == "LootB" or modifier == "LootC" then
		local key = if modifier == "LootB" then "B" else "C"
		for _, item in s.loot do
			local alt = s.daily.alt and s.daily.alt[item.id]
			local p = alt and alt[key]
			if p then
				item.x, item.z = p.x, p.z
			end
		end
	end
	return s
end

-- The date-seeded modifier for a design on a day. The first pass through the
-- advent (and any day before it) is unmodified.
function DailyVaults.modifierFor(day: number, spec: any): string
	if day < FIRST_DAY + COUNT then
		return "None"
	end
	local list = spec.daily.modifiers
	-- A small integer mix of the day (LCG step), so neighbouring cycles differ.
	local h = (day * 1103515245 + 12345) % 2147483648
	return list[math.floor(h / 65536) % #list + 1]
end

-- The vault for a UTC day: (spec with the day's modifier applied, rotation slot,
-- modifier). The spec compiles with Sim/LevelSpec.compile.
function DailyVaults.forDay(day: number): (any, number, string)
	local n = DailyVault.vaultFor(day, COUNT)
	local design = byNumber[n]
	local modifier = DailyVaults.modifierFor(day, design)
	return DailyVaults.apply(design, modifier), n, modifier
end

-- The advent day (December date) a design first plays on.
function DailyVaults.adventDayOf(spec: any): number
	local _, _, d = Calendar.civilFromDays(FIRST_DAY + spec.daily.order - 1)
	return d
end

return table.freeze(DailyVaults)
