--!strict
-- Heist/Outfit: the Rookie's outfit slots (PLAN_FIRST_PERSON "CH"). Pure: no engine calls (Lune-tested in
-- tests/unit/HeistOutfit.spec.luau). The profile keeps `outfit` = slot -> OUTFIT id (Config.Rookie.OUTFIT);
-- Schema.sanitize repairs it with Outfit.repair, Data.Equip validates a change with Outfit.canWear, and the
-- server (Heist/Rookie) turns an outfit into kit pieces with Outfit.pieces. Unlocks: free ids, or a star total
-- (medal + daily stars) or a trophy (Config.Rookie.OUTFIT[id].unlock). A new player gets a random outfit once
-- (Outfit.rollIfNew on load, Outfit.roll: every slot from the unlocked ids); "tone" is the knit colour (no piece).

local Config = require("../Config")
local RookieData = require("./RookieData")

local R = Config.Rookie

local Outfit = {}

export type Outfit = { [string]: string } -- slot -> OUTFIT id
export type Def = {
	slot: string,
	variant: string,
	name: string,
	free: boolean?,
	unlock: { [string]: any }?,
	hex: string?,
}

-- A NEW copy of the default outfit (every slot filled).
function Outfit.default(): Outfit
	return table.clone(R.DEFAULT_OUTFIT)
end

function Outfit.def(id: any): Def?
	if type(id) ~= "string" then
		return nil
	end
	return R.OUTFIT[id]
end

function Outfit.isSlot(slot: any): boolean
	return type(slot) == "string" and R.DEFAULT_OUTFIT[slot] ~= nil
end

-- The ids of one slot, sorted (free first, then by name).
function Outfit.idsFor(slot: string): { string }
	local out = {}
	for id, def in R.OUTFIT do
		if def.slot == slot then
			table.insert(out, id)
		end
	end
	table.sort(out, function(a: string, b: string): boolean
		local fa, fb = R.OUTFIT[a].free == true, R.OUTFIT[b].free == true
		if fa ~= fb then
			return fa
		end
		return a < b
	end)
	return out
end

-- Stars counted for unlocks: every medal except Diamond on every level, plus the daily-vault stars (the same
-- total Progress.totalStars gives; counted here so Schema can use this module without a require cycle).
function Outfit.stars(heist: any): number
	local total = 0
	local daily = type(heist) == "table" and heist.daily
	if type(daily) == "table" and type(daily.stars) == "number" and daily.stars == daily.stars then
		total += math.max(0, daily.stars)
	end
	local levels = type(heist) == "table" and heist.levels
	if type(levels) == "table" then
		for _, record in levels do
			local medals = type(record) == "table" and record.medals
			if type(medals) == "table" then
				for medal, has in medals do
					if has == true and medal ~= "Diamond" then
						total += 1
					end
				end
			end
		end
	end
	return total
end

-- Is `id` unlocked for this profile slice? (nil heist = a fresh player: free ids only)
function Outfit.isUnlocked(heist: any, id: string): boolean
	local def = R.OUTFIT[id]
	if def == nil then
		return false
	end
	if def.free == true then
		return true
	end
	local rule = def.unlock
	if type(rule) ~= "table" then
		return false
	end
	if rule.stars ~= nil and Outfit.stars(heist) >= rule.stars then
		return true
	end
	if rule.trophy ~= nil then
		local trophies = type(heist) == "table" and heist.trophies
		if type(trophies) == "table" and trophies[rule.trophy] ~= nil then
			return true
		end
	end
	return false
end

-- Can this profile wear `id` in `slot`? (ok, failure code): the Data.Equip rule.
function Outfit.canWear(heist: any, slot: any, id: any): (boolean, string)
	if not Outfit.isSlot(slot) then
		return false, "BadSlot"
	end
	local def = Outfit.def(id)
	if def == nil then
		return false, "UnknownItem"
	end
	if def.slot ~= slot then
		return false, "WrongSlot"
	end
	if not Outfit.isUnlocked(heist, id) then
		return false, "Locked"
	end
	return true, "Ok"
end

-- Repairs an outfit in place against a profile slice: unknown slots go, every slot holds a known, unlocked id of
-- that slot (else the default). Returns the outfit (a new default table when `outfit` is not a table) and the
-- repaired slot names.
function Outfit.repair(outfit: any, heist: any): (Outfit, { string })
	local fixed: { string } = {}
	if type(outfit) ~= "table" then
		return Outfit.default(), { "outfit" }
	end
	for slot in outfit do
		if not Outfit.isSlot(slot) then
			outfit[slot] = nil
			table.insert(fixed, tostring(slot))
		end
	end
	for _, slot in R.SLOTS do
		local ok = Outfit.canWear(heist, slot, outfit[slot])
		if not ok then
			outfit[slot] = R.DEFAULT_OUTFIT[slot]
			table.insert(fixed, slot)
		end
	end
	return outfit, fixed
end

-- A clean copy for building a character (never trusts its input: unknown or mismatched ids fall back).
-- No unlock check: the profile was repaired on load and every change went through canWear.
function Outfit.clean(outfit: any): Outfit
	local out = Outfit.default()
	if type(outfit) == "table" then
		for _, slot in R.SLOTS do
			local def = Outfit.def(outfit[slot])
			if def and def.slot == slot then
				out[slot] = outfit[slot]
			end
		end
	end
	return out
end

-- The kit pieces an outfit adds to the body (RookieData.outfit), in slot order.
function Outfit.pieces(outfit: Outfit): { string }
	local out = {}
	local o = Outfit.clean(outfit)
	for _, slot in R.SLOTS do
		local def = R.OUTFIT[o[slot]]
		local bySlot = RookieData.outfit[slot]
		local list = def and def.variant ~= "" and bySlot and bySlot[def.variant]
		if list then
			for _, piece in list do
				table.insert(out, piece)
			end
		end
	end
	return out
end

-- The glove colour of an outfit (hex): a toned glove (Config.Rookie.TONED) takes the outfit's knit tone.
function Outfit.gloveHex(outfit: Outfit): string
	local o = Outfit.clean(outfit)
	local tone = R.OUTFIT[o.tone]
	if R.TONED[o.gloves] and tone and type(tone.hex) == "string" then
		return tone.hex
	end
	return R.GLOVES[o.gloves] or R.GLOVES[R.DEFAULT_OUTFIT.gloves]
end

-- A random outfit from what this profile slice has unlocked (nil heist: free ids only), every slot rolled.
-- pick(n) returns an integer 1..n (the server passes a Random; tests a seeded one); a bad pick clamps.
function Outfit.roll(heist: any, pick: (number) -> number): Outfit
	local out = Outfit.default()
	local unlocked = Outfit.unlocked(heist)
	for _, slot in R.SLOTS do
		local list = unlocked[slot]
		if #list > 0 then
			local i = pick(#list)
			i = if type(i) == "number" and i == i then math.clamp(math.floor(i), 1, #list) else 1
			out[slot] = list[i]
		end
	end
	return out
end

-- First join: a profile that never got its random outfit (outfitRolled not true) gets one now, unless it already
-- wears something other than the default (an older profile that chose before this existed keeps its pick). The
-- flag is set either way, so this happens once a profile. Returns true when the slice changed.
function Outfit.rollIfNew(heist: any, pick: (number) -> number): boolean
	if type(heist) ~= "table" or heist.outfitRolled == true then
		return false
	end
	heist.outfitRolled = true
	if Outfit.key(heist.outfit) == Outfit.key(Outfit.default()) then
		heist.outfit = Outfit.roll(heist, pick)
	end
	return true
end

-- A short, stable key of an outfit ("Cap_Flat|Scarf_Long|..."): clone templates are rebuilt when it changes.
function Outfit.key(outfit: Outfit): string
	local o = Outfit.clean(outfit)
	local parts = {}
	for _, slot in R.SLOTS do
		table.insert(parts, o[slot])
	end
	return table.concat(parts, "|")
end

-- The outfit a key stands for (the player attribute "Outfit" DataService publishes); anything unknown falls back.
function Outfit.fromKey(key: any): Outfit
	local out = {}
	if type(key) == "string" then
		local ids = string.split(key, "|")
		for i, slot in R.SLOTS do
			out[slot] = ids[i]
		end
	end
	return Outfit.clean(out)
end

-- Every slot's unlocked ids for a profile (the wardrobe).
function Outfit.unlocked(heist: any): { [string]: { string } }
	local out = {}
	for _, slot in R.SLOTS do
		local list = {}
		for _, id in Outfit.idsFor(slot) do
			if Outfit.isUnlocked(heist, id) then
				table.insert(list, id)
			end
		end
		out[slot] = list
	end
	return out
end

return Outfit
