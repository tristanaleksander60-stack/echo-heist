--!strict
-- Data/Schema: the "Heist" profile slice, schema v1 (pure; Lune-tested).
--
-- The profile (one DataStore key per player, written only by PlayerData) holds the
-- library slices Currency (Cash, Stars, CandyCanes), Purchases and ShopBought, plus
-- this slice. The record-level Schema number (PlayerData) is the schema version.
--
-- Migration policy (docs/DATA.md): never edit a released migration; add
-- MIGRATIONS[n] (it upgrades a version n-1 document to n, mutating the whole Data
-- table synchronously), bump VERSION, add a fixture test with the old shape.
-- PlayerData refuses to load a document newer than VERSION. Additive fields need no
-- migration: PlayerData reconciles missing keys from defaultHeist() on load, and
-- sanitize() then repairs anything of the wrong type.

local Config = require("../Config")
local Outfit = require("../Heist/Outfit")

local Schema = {}

Schema.VERSION = 1
Schema.SLICE = "Heist"

export type Migration = (data: { [string]: any }) -> ()

-- [n] = function(data) ... end   upgrades version n-1 to n.
Schema.MIGRATIONS = {} :: { [number]: Migration }

export type BestRun = {
	stars: number,
	clones: number,
	timeMs: number,
	haul: number,
	at: number, -- unix time
	recHash: string?, -- hash of the personal-best recording (ghost key, §8.7)
}

export type LevelRecord = {
	medals: { [string]: boolean }, -- story: Haul, Crew, Clean, Diamond; party: Haul1-3
	best: BestRun?, -- best cleared, untainted run (Progress.isBetterRun)
	haulBest: number, -- biggest untainted haul, cleared or not
	plays: number,
	clears: number,
	firstClearAt: number, -- unix time, 0 = never cleared
}

export type Heist = {
	levels: { [string]: LevelRecord },
	unlocked: { [string]: boolean },
	trophies: { [string]: number }, -- trophy or ornament id -> unix time earned
	shelf: { string }, -- trophy ids shown on the van shelf, in order
	bagLevel: number,
	cosmetics: {
		owned: { [string]: boolean },
		equipped: { [string]: string }, -- slot -> cosmetic id
	},
	daily: {
		lastClearDay: number, -- UTC day of the last first clear of "today's" vault, -1 = never
		streak: number,
		bestStreak: number,
		stars: number, -- Stars earned from daily vaults (first clears)
		haulDay: number, -- day of the "biggest haul today" board entry (haulBest, haulClones, haulTimeMs)
		haulBest: number,
		haulClones: number, -- tie-break 1: fewer clones (DailyVault.beatsBoard)
		haulTimeMs: number, -- tie-break 2: less time
	},
	settings: {
		reducedMotion: boolean, -- true = reduced motion on (the client also follows the device setting)
		relaxed: boolean,
		colourBlindGlyphs: boolean, -- seat shapes beside clone numbers (crew cards, results)
		classicCamera: boolean, -- legacy (before first person): true = the classic follow cam; read once into cameraMode
		cameraMode: string, -- Heist/CameraDirector: "fp" (default) | "diorama" | "classic" (Config.Data.SETTING_CHOICES)
		fpFov: number, -- first-person field of view, degrees (Config.Data.SETTING_NUMBERS)
		-- U7 settings (client Heist/Hud/Settings, additive: no migration; sanitize fills them in):
		musicVolume: number, -- 0..1 (Config.Data.SETTING_NUMBERS)
		sfxVolume: number, -- 0..1
		shake: boolean, -- camera kicks (the rewind FOV dip) on
		captions: boolean, -- sound captions on the message rail
		guardPath: boolean, -- Gus's boot prints (his next steps) on the floor
		haptics: boolean, -- phone vibration on plate, grab and bank (WorldView, Config.WorldFx)
		-- The job sheet explains each star the first time it is earned ("HAUL: $1,000 stolen"), then
		-- just stamps it (WALKTHROUGH S7). Stored here so the reasons stop on every device.
		seenStarHaul: boolean,
		seenStarCrew: boolean,
		seenStarClean: boolean,
	},
	-- The Rookie's outfit (additive, no migration; sanitize repairs it with Heist/Outfit): slot -> Config.Rookie.OUTFIT id.
	outfit: { [string]: string },
	-- The first-join random outfit was given (additive; sanitize's type check repairs it to false): DataService rolls
	-- one with Outfit.rollIfNew on load while this is false, then sets it, so it happens once a profile.
	outfitRolled: boolean,
	-- The hideout van style (LOBBY 2; additive, no migration; sanitize repairs it): a Config.Hideout.VAN.STYLES id.
	-- The crew leader's pick at their van, saved per player; the van they claim next wears it.
	vanStyle: string,
	ftueStep: number,
	firstHeistDone: boolean,
	stats: { heists: number, clears: number },
}

local function defaultEquipped(): { [string]: string }
	return table.clone(Config.Data.DEFAULT_EQUIPPED)
end

-- A NEW default settings table every call. Booleans, the numbers in Config.Data.SETTING_NUMBERS and the
-- choices in Config.Data.SETTING_CHOICES (their first entry).
function Schema.defaultSettings(): any
	return {
		reducedMotion = false,
		relaxed = false,
		colourBlindGlyphs = false,
		classicCamera = false,
		cameraMode = Config.Data.SETTING_CHOICES.cameraMode[1],
		fpFov = Config.Data.SETTING_NUMBER_DEFAULTS.fpFov,
		musicVolume = 1,
		sfxVolume = 1,
		shake = true,
		captions = true,
		guardPath = true,
		haptics = true,
		seenStarHaul = false,
		seenStarCrew = false,
		seenStarClean = false,
	}
end

-- Is `value` a valid value for settings key `key`? (Data.SetSetting and sanitize use the same rule.)
-- A number setting takes a finite number inside its Config.Data.SETTING_NUMBERS range, a choice setting one of
-- its Config.Data.SETTING_CHOICES strings; any other known key takes a boolean. Unknown keys are never valid.
function Schema.validSetting(key: any, value: any): boolean
	if type(key) ~= "string" then
		return false
	end
	local range = Config.Data.SETTING_NUMBERS[key]
	if range then
		return type(value) == "number" and value == value and value >= range[1] and value <= range[2]
	end
	local choices = Config.Data.SETTING_CHOICES[key]
	if choices then
		return type(value) == "string" and table.find(choices, value) ~= nil
	end
	local default = Schema.defaultSettings()[key]
	return default ~= nil and type(value) == "boolean"
end

-- The player attribute DataService publishes a setting as ("classicCamera" -> "Setting_ClassicCamera").
-- Is `id` a van style id? (Config.Hideout.VAN.STYLES; the server's style op and sanitize use the same rule.)
function Schema.validVanStyle(id: any): boolean
	if type(id) ~= "string" then
		return false
	end
	for _, s in Config.Hideout.VAN.STYLES do
		if s.id == id then
			return true
		end
	end
	return false
end

function Schema.settingAttribute(key: string): string
	return "Setting_" .. string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)
end

-- A NEW default slice every call (PlayerData.RegisterSlice asserts this).
function Schema.defaultHeist(): Heist
	local first = Config.Data.LEVEL_ORDER[1]
	return {
		levels = {},
		unlocked = { [first] = true },
		trophies = {},
		shelf = {},
		bagLevel = 0,
		cosmetics = { owned = {}, equipped = defaultEquipped() },
		daily = {
			lastClearDay = -1,
			streak = 0,
			bestStreak = 0,
			stars = 0,
			haulDay = -1,
			haulBest = 0,
			haulClones = 0,
			haulTimeMs = 0,
		},
		settings = Schema.defaultSettings(),
		outfit = Outfit.default(),
		outfitRolled = false,
		vanStyle = Config.Hideout.VAN.STYLES[1].id,
		ftueStep = 0,
		firstHeistDone = false,
		stats = { heists = 0, clears = 0 },
	}
end

function Schema.newLevelRecord(): LevelRecord
	return { medals = {}, best = nil, haulBest = 0, plays = 0, clears = 0, firstClearAt = 0 }
end

-- Runs MIGRATIONS (fromVersion, toVersion] on a whole Data table, in order. This is
-- the same loop PlayerData.prepare runs; tests use it to replay fixtures of old shapes.
function Schema.migrate(data: { [string]: any }, fromVersion: number, toVersion: number?)
	for version = fromVersion + 1, toVersion or Schema.VERSION do
		local step = Schema.MIGRATIONS[version]
		if step then
			step(data)
		end
	end
end

---------------------------------------------------------------------------
-- Repair after load: wrong types become defaults, numbers are clamped, the shelf
-- and equipped slots only reference things the player owns. Returns what changed.
---------------------------------------------------------------------------

local function isWhole(n: any, min: number, max: number): boolean
	return type(n) == "number" and n == n and n >= min and n <= max and math.floor(n) == n
end

local function wholeOr(n: any, min: number, max: number, fallback: number): number
	if type(n) ~= "number" or n ~= n then
		return fallback
	end
	return math.clamp(math.floor(n), min, max)
end

local BIG = 2 ^ 52

function Schema.isOwnedCosmetic(heist: Heist, id: string): boolean
	local def = Config.Data.Cosmetics[id]
	return def ~= nil and (def.default == true or heist.cosmetics.owned[id] == true)
end

local function repairLevel(record: any): (LevelRecord, boolean)
	if type(record) ~= "table" then
		return Schema.newLevelRecord(), true
	end
	local changed = false
	if type(record.medals) ~= "table" then
		record.medals = {}
		changed = true
	end
	for medal, value in record.medals do
		if type(medal) ~= "string" or value ~= true then
			record.medals[medal] = nil
			changed = true
		end
	end
	for _, field in { "haulBest", "plays", "clears", "firstClearAt" } do
		if not isWhole(record[field], 0, BIG) then
			record[field] = wholeOr(record[field], 0, BIG, 0)
			changed = true
		end
	end
	local best = record.best
	if best ~= nil then
		local ok = type(best) == "table"
			and isWhole(best.stars, 0, 10)
			and isWhole(best.clones, 0, 1000)
			and isWhole(best.timeMs, 0, BIG)
			and isWhole(best.haul, 0, BIG)
			and (best.recHash == nil or type(best.recHash) == "string")
		if not ok then
			record.best = nil
			changed = true
		end
	end
	return record :: LevelRecord, changed
end

function Schema.sanitize(heist: Heist): { string }
	local repairs: { string } = {}
	local h = heist :: any
	local defaults = Schema.defaultHeist() :: any
	for key, default in defaults do
		if type(h[key]) ~= type(default) then
			h[key] = default
			table.insert(repairs, key)
		end
	end
	for _, key in { "owned", "equipped" } do
		if type(h.cosmetics[key]) ~= "table" then
			h.cosmetics[key] = defaults.cosmetics[key]
			table.insert(repairs, "cosmetics." .. key)
		end
	end

	for levelId, record in h.levels do
		local fixed, changed = repairLevel(record)
		if type(levelId) ~= "string" then
			h.levels[levelId] = nil
			table.insert(repairs, "levels key")
		elseif changed then
			h.levels[levelId] = fixed
			table.insert(repairs, "levels." .. levelId)
		end
	end
	for levelId, value in h.unlocked do
		if value ~= true then
			h.unlocked[levelId] = nil
			table.insert(repairs, "unlocked." .. tostring(levelId))
		end
	end
	h.unlocked[Config.Data.LEVEL_ORDER[1]] = true
	for id, at in h.trophies do
		if type(id) ~= "string" or not isWhole(at, 0, BIG) then
			h.trophies[id] = nil
			table.insert(repairs, "trophies." .. tostring(id))
		end
	end

	-- Shelf: dense, unique, owned, at most SHELF_SLOTS.
	local shelf: { string } = {}
	local seen: { [string]: boolean } = {}
	local shelfChanged = false
	for _, id in h.shelf do
		if type(id) == "string" and h.trophies[id] ~= nil and not seen[id] and #shelf < Config.Data.SHELF_SLOTS then
			seen[id] = true
			table.insert(shelf, id)
		else
			shelfChanged = true
		end
	end
	if shelfChanged or #shelf ~= #h.shelf then
		h.shelf = shelf
		table.insert(repairs, "shelf")
	end

	if not isWhole(h.bagLevel, 0, Config.Data.Bag.MAX_LEVEL) then
		h.bagLevel = wholeOr(h.bagLevel, 0, Config.Data.Bag.MAX_LEVEL, 0)
		table.insert(repairs, "bagLevel")
	end
	-- Unknown cosmetic ids are kept (a rollback must never delete purchases); junk values go.
	for id, value in h.cosmetics.owned do
		if type(id) ~= "string" or value ~= true then
			h.cosmetics.owned[id] = nil
			table.insert(repairs, "cosmetics.owned." .. tostring(id))
		end
	end
	for slot, id in h.cosmetics.equipped do
		local def = Config.Data.Cosmetics[id]
		local fallback = Config.Data.DEFAULT_EQUIPPED[slot]
		if fallback == nil then
			h.cosmetics.equipped[slot] = nil
			table.insert(repairs, "cosmetics.equipped." .. tostring(slot))
		elseif type(id) ~= "string" or def == nil or def.slot ~= slot or not Schema.isOwnedCosmetic(heist, id) then
			h.cosmetics.equipped[slot] = fallback
			table.insert(repairs, "cosmetics.equipped." .. slot)
		end
	end
	for slot, id in Config.Data.DEFAULT_EQUIPPED do
		if h.cosmetics.equipped[slot] == nil then
			h.cosmetics.equipped[slot] = id
		end
	end

	for key, default in defaults.daily do
		if not isWhole(h.daily[key], -1, BIG) then
			h.daily[key] = default
			table.insert(repairs, "daily." .. key)
		end
	end
	-- cameraMode (first person) replaces the boolean classicCamera additively: an old pick of the classic
	-- camera carries over once; everyone else gets the new default (first person).
	if h.settings.cameraMode == nil and h.settings.classicCamera == true then
		h.settings.cameraMode = "classic"
		table.insert(repairs, "settings.cameraMode")
	end
	for key, default in defaults.settings do
		if not Schema.validSetting(key, h.settings[key]) then
			h.settings[key] = default
			table.insert(repairs, "settings." .. key)
		end
	end
	for key, default in defaults.stats do
		if not isWhole(h.stats[key], 0, BIG) then
			h.stats[key] = default
			table.insert(repairs, "stats." .. key)
		end
	end
	-- Outfit: known slots only, each a known and unlocked id of its slot (else the default).
	if not Schema.validVanStyle(h.vanStyle) then
		h.vanStyle = defaults.vanStyle
		table.insert(repairs, "vanStyle")
	end
	local _, outfitFixed = Outfit.repair(h.outfit, h)
	for _, slot in outfitFixed do
		table.insert(repairs, "outfit." .. slot)
	end
	if not isWhole(h.ftueStep, 0, Config.Data.MAX_FTUE_STEP) then
		h.ftueStep = wholeOr(h.ftueStep, 0, Config.Data.MAX_FTUE_STEP, 0)
		table.insert(repairs, "ftueStep")
	end
	return repairs
end

return Schema
