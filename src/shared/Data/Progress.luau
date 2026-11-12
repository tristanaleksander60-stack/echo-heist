--!strict
-- Data/Progress: medals, personal bests, Stars, unlocks and Cash maths (pure;
-- Lune-tested). MASTERPLAN §5.1-5.2, §8.8. The heist server decides the facts of a
-- heist (haul, clones, catches...) from actor positions; this module only turns
-- those facts into progress. DataService wraps it with currency changes and saving.
--
-- Rules:
--   story level  cleared = haul >= haulTarget and beforeDawn
--                Haul = cleared; Crew = cleared and clones <= par;
--                Clean = cleared, no catches and no busted clones in the final run;
--                Diamond = cleared and clones < devClones (only when devClones is set).
--   party level  Haul1..3 = haul >= haulTiers[i]; cleared = Haul1.
--   Every medal except Diamond is one Star. Medals are kept forever (union of runs).
--   Tainted runs (Validator, §8.8) earn Cash but no medals, bests, clears or trophies.
--   Relaxed runs earn everything but are not board-eligible.

local Config = require("../Config")
local Schema = require("./Schema")

local Progress = {}

export type LevelRules = {
	kind: string, -- "story" | "party"
	haulTarget: number?,
	haulTiers: { number }?,
	maxHaul: number,
	parClones: number?,
	cap: number,
	trophy: string?,
	firstClearCash: number?,
	unlockAfter: string?,
	starsRequired: number?,
	devClones: number?,
}

export type HeistResult = {
	haul: number, -- banked $ value at heist end
	clones: number, -- clones used (Helper-mode clones excluded by the heist server)
	timeMs: number, -- heist duration in loop milliseconds
	catches: number, -- live players caught in the final run
	busted: number, -- clones busted in the final run
	beforeDawn: boolean, -- the haul target was banked before Dawn
	tainted: boolean, -- a recording failed validation
	relaxed: boolean,
	friends: number?, -- friends in the crew (co-op Cash bonus)
	recHash: string?, -- hash of this run's recordings (board / ghost)
	heistId: string?, -- unique per heist instance; a repeat is refused
}

export type Evaluation = { cleared: boolean, medals: { [string]: boolean }, stars: number }

export type AwardSummary = {
	levelId: string,
	cleared: boolean,
	firstClear: boolean,
	newMedals: { string },
	levelStars: number,
	starsGained: number,
	totalStars: number,
	newBest: boolean,
	newHaulBest: boolean,
	cash: number,
	trophy: string?,
	unlocked: { string },
	boardEligible: boolean,
}

export type RulesLookup = (levelId: string) -> LevelRules?

local DIAMOND = "Diamond"
local MAX_ID_BYTES = 64

local function isWhole(n: any, min: number, max: number): boolean
	return type(n) == "number" and n == n and n >= min and n <= max and math.floor(n) == n
end
Progress.isWhole = isWhole

---------------------------------------------------------------------------
-- Rules and input validation
---------------------------------------------------------------------------

-- Errors with a clear message if a level's rules are malformed (startup and tests).
function Progress.validateRules(levelId: string, rules: LevelRules)
	assert(string.match(levelId, "^%w+$") and #levelId <= 32, `Level '{levelId}': id must be alphanumeric`)
	assert(rules.kind == "story" or rules.kind == "party", `Level {levelId}: kind must be story or party`)
	assert(isWhole(rules.maxHaul, 1, 2 ^ 40), `Level {levelId}: maxHaul must be a whole number >= 1`)
	assert(isWhole(rules.cap, 1, 16), `Level {levelId}: cap 1..16`)
	if rules.kind == "story" then
		assert(isWhole(rules.haulTarget, 1, rules.maxHaul), `Level {levelId}: haulTarget 1..maxHaul`)
		assert(isWhole(rules.parClones, 0, rules.cap), `Level {levelId}: parClones 0..cap`)
		assert(rules.devClones == nil or isWhole(rules.devClones, 1, rules.cap), `Level {levelId}: devClones 1..cap`)
	else
		local tiers = rules.haulTiers
		assert(type(tiers) == "table" and #tiers >= 1, `Level {levelId}: party levels need haulTiers`)
		local last = 0
		for i, tier in tiers :: { number } do
			assert(isWhole(tier, last + 1, rules.maxHaul), `Level {levelId}: haulTiers[{i}] must rise, <= maxHaul`)
			last = tier
		end
	end
	assert(rules.firstClearCash == nil or isWhole(rules.firstClearCash, 0, 1e9), `Level {levelId}: bad firstClearCash`)
	assert(rules.starsRequired == nil or isWhole(rules.starsRequired, 0, 1e5), `Level {levelId}: bad starsRequired`)
	assert(rules.trophy == nil or Config.Data.Trophies[rules.trophy], `Level {levelId}: unknown trophy`)
	assert(rules.unlockAfter == nil or rules.unlockAfter ~= levelId, `Level {levelId}: cannot unlock after itself`)
end

-- (ok, reason). Every field is checked before anything is awarded; the heist server
-- is trusted code, but a bug there must not mint Cash or medals.
function Progress.validateResult(rules: LevelRules, result: any): (boolean, string?)
	if type(result) ~= "table" then
		return false, "result must be a table"
	end
	if not isWhole(result.haul, 0, rules.maxHaul) then
		return false, "haul out of range"
	end
	if not isWhole(result.clones, 0, rules.cap) then
		return false, "clones out of range"
	end
	if not isWhole(result.timeMs, 0, Config.Data.MAX_HEIST_MS) then
		return false, "timeMs out of range"
	end
	if
		not isWhole(result.catches, 0, Config.Data.MAX_COUNT) or not isWhole(result.busted, 0, Config.Data.MAX_COUNT)
	then
		return false, "catches/busted out of range"
	end
	for _, flag in { "beforeDawn", "tainted", "relaxed" } do
		if type(result[flag]) ~= "boolean" then
			return false, `{flag} must be a boolean`
		end
	end
	if result.friends ~= nil and not isWhole(result.friends, 0, Config.Data.MAX_FRIENDS) then
		return false, "friends out of range"
	end
	for _, field in { "recHash", "heistId" } do
		local v = result[field]
		if v ~= nil and (type(v) ~= "string" or #v == 0 or #v > MAX_ID_BYTES or not string.match(v, "^[%w%-_]+$")) then
			return false, `{field} must be a short id string`
		end
	end
	return true, nil
end

---------------------------------------------------------------------------
-- Medals and comparison
---------------------------------------------------------------------------

function Progress.evaluate(rules: LevelRules, result: HeistResult): Evaluation
	local medals: { [string]: boolean } = {}
	local cleared = false
	if result.tainted then
		return { cleared = false, medals = medals, stars = 0 }
	end
	if rules.kind == "story" then
		cleared = result.beforeDawn and result.haul >= (rules.haulTarget :: number)
		if cleared then
			medals.Haul = true
			if result.clones <= (rules.parClones :: number) then
				medals.Crew = true
			end
			if result.catches == 0 and result.busted == 0 then
				medals.Clean = true
			end
			if rules.devClones ~= nil and result.clones < rules.devClones then
				medals[DIAMOND] = true
			end
		end
	else
		for i, tier in rules.haulTiers :: { number } do
			if result.haul >= tier then
				medals[`Haul{i}`] = true
			end
		end
		cleared = medals.Haul1 == true
	end
	return { cleared = cleared, medals = medals, stars = Progress.starCount(medals) }
end

-- Stars in a medal set: every medal except Diamond.
function Progress.starCount(medals: { [string]: boolean }): number
	local n = 0
	for medal, has in medals do
		if has == true and medal ~= DIAMOND then
			n += 1
		end
	end
	return n
end

-- Union of medal sets; returns the medals in `new` that `old` lacked (sorted).
function Progress.mergeMedals(old: { [string]: boolean }, new: { [string]: boolean }): { string }
	local gained: { string } = {}
	for medal, has in new do
		if has == true and old[medal] ~= true then
			old[medal] = true
			table.insert(gained, medal)
		end
	end
	table.sort(gained)
	return gained
end

-- True if run a beats run b: more Stars, then fewer clones, then faster, then bigger haul.
function Progress.isBetterRun(a: Schema.BestRun, b: Schema.BestRun?): boolean
	if b == nil then
		return true
	end
	local best = b :: Schema.BestRun
	if a.stars ~= best.stars then
		return a.stars > best.stars
	end
	if a.clones ~= best.clones then
		return a.clones < best.clones
	end
	if a.timeMs ~= best.timeMs then
		return a.timeMs < best.timeMs
	end
	return a.haul > best.haul
end

---------------------------------------------------------------------------
-- Cash
---------------------------------------------------------------------------

-- Cash for one heist: haul x rate x (1 + friend bonus, capped), x tainted multiplier,
-- plus the first-clear bonus, capped per heist. Always a whole number >= 0.
function Progress.cashFor(rules: LevelRules, result: HeistResult, firstClear: boolean): number
	local econ = Config.Data.Economy
	local friends = math.clamp(result.friends or 0, 0, Config.Data.MAX_FRIENDS)
	local bonus = math.min(friends * econ.FRIEND_BONUS, econ.FRIEND_BONUS_CAP)
	local mult = 1 + bonus
	if result.tainted then
		mult *= econ.TAINTED_CASH_MULT
	end
	-- Round the multiplier to 1/1000 first so 1 + 3 x 0.1 is exactly 1.3, not 1.2999...
	mult = math.floor(mult * 1000 + 0.5) / 1000
	local cash = math.floor(result.haul * econ.CASH_PER_HAUL * mult + 1e-9)
	if firstClear then
		cash += rules.firstClearCash or 0
	end
	return math.clamp(cash, 0, econ.MAX_CASH_PER_HEIST)
end

---------------------------------------------------------------------------
-- Stars, unlocks and trophies on a Heist slice
---------------------------------------------------------------------------

function Progress.totalStars(heist: Schema.Heist): number
	local total = heist.daily.stars
	for _, record in heist.levels do
		total += Progress.starCount(record.medals)
	end
	return total
end

-- Adds every level whose gate is now met to heist.unlocked. Returns the new ones, in
-- LEVEL_ORDER. Unlocks are never taken away.
function Progress.computeUnlocks(heist: Schema.Heist, order: { string }, lookup: RulesLookup): { string }
	local stars = Progress.totalStars(heist)
	local added: { string } = {}
	for _, levelId in order do
		local rules = lookup(levelId)
		if rules and not heist.unlocked[levelId] then
			local after = rules.unlockAfter
			local cleared = after == nil or (heist.levels[after] ~= nil and heist.levels[after].firstClearAt > 0)
			if cleared and stars >= (rules.starsRequired or 0) then
				heist.unlocked[levelId] = true
				table.insert(added, levelId)
			end
		end
	end
	return added
end

-- Gives a trophy once; puts it on the shelf if there is room. Returns true if new.
function Progress.grantTrophy(heist: Schema.Heist, trophyId: string, now: number): boolean
	if Config.Data.Trophies[trophyId] == nil or heist.trophies[trophyId] ~= nil then
		return false
	end
	heist.trophies[trophyId] = now
	local def = Config.Data.Trophies[trophyId]
	if def.kind ~= "ornament" and #heist.shelf < Config.Data.SHELF_SLOTS then
		table.insert(heist.shelf, trophyId)
	end
	return true
end

-- Applies one validated heist result to the slice and returns what changed. Pure:
-- the caller grants summary.cash and mirrors summary.totalStars into the Stars balance.
function Progress.applyHeistResult(
	heist: Schema.Heist,
	levelId: string,
	rules: LevelRules,
	result: HeistResult,
	now: number,
	order: { string },
	lookup: RulesLookup
): AwardSummary
	local record = heist.levels[levelId]
	if record == nil then
		record = Schema.newLevelRecord()
		heist.levels[levelId] = record
	end
	local levelStarsBefore = Progress.starCount(record.medals)
	local eval = Progress.evaluate(rules, result)

	record.plays += 1
	heist.stats.heists += 1
	heist.firstHeistDone = true

	local firstClear = eval.cleared and record.firstClearAt == 0
	local newMedals = Progress.mergeMedals(record.medals, eval.medals)
	local newBest, newHaulBest = false, false
	local trophy: string? = nil

	if not result.tainted and result.haul > record.haulBest then
		record.haulBest = result.haul
		newHaulBest = true
	end
	if eval.cleared then
		record.clears += 1
		heist.stats.clears += 1
		if firstClear then
			record.firstClearAt = now
			if rules.trophy and Progress.grantTrophy(heist, rules.trophy, now) then
				trophy = rules.trophy
			end
		end
		local run: Schema.BestRun = {
			stars = eval.stars,
			clones = result.clones,
			timeMs = result.timeMs,
			haul = result.haul,
			at = now,
			recHash = result.recHash,
		}
		if Progress.isBetterRun(run, record.best) then
			record.best = run
			newBest = true
		end
	end

	local unlocked = Progress.computeUnlocks(heist, order, lookup)
	local totalStars = Progress.totalStars(heist)
	return {
		levelId = levelId,
		cleared = eval.cleared,
		firstClear = firstClear,
		newMedals = newMedals,
		levelStars = Progress.starCount(record.medals),
		starsGained = Progress.starCount(record.medals) - levelStarsBefore,
		totalStars = totalStars,
		newBest = newBest,
		newHaulBest = newHaulBest,
		cash = Progress.cashFor(rules, result, firstClear),
		trophy = trophy,
		unlocked = unlocked,
		boardEligible = not result.tainted and not result.relaxed,
	}
end

return Progress
