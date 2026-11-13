--!strict
-- Heist/Badges: the launch set of Roblox badges (BADGES track; docs/marketing/BADGES.md) and their conditions as
-- pure rules (Lune-tested in tests/unit/HeistBadges.spec.luau). The server (src/server/Data/Awards) feeds them
-- server-decided facts (the sim's results and events, the profile, who is in the server) and awards the badges.
-- Nothing here reads the engine, so the client (the BADGE UNLOCKED card) and Lune read it too.
--
-- Ids: Badges.IDS[key] is the Roblox badge id; 0 = not created yet (the server skips the award quietly and keeps
-- the player's progress, so the badge is sent on a later join once it exists). Badges.ICONS[key] is the badge's
-- icon image id (0 = the toast draws the tier ring and the badge's short mark instead). tools/badge_upload.py
-- creates the badges with Open Cloud and rewrites the block between the BEGIN / END lines.
-- Icons: docs/marketing/badges/<key>.png (512 x 512, cropped to a circle by Roblox).

local Config = require("../Config")

local Badges = {}

export type Tier = "bronze" | "silver" | "gold" | "boss"

export type Def = {
	key: string, -- the stable id: profile flags, the icon file name, the upload tool
	tier: Tier,
	name: string, -- the badge name on Roblox and on the in-game card
	description: string, -- what the player must do (Roblox shows it on the game page)
	mark: string, -- 1-3 ASCII characters: the toast's fallback icon while ICONS[key] is 0
}

-- The launch set, in game-page order (Roblox lists badges in creation order; the tool creates them in this order).
Badges.LIST = table.freeze({
	{
		key = "welcome",
		tier = "bronze",
		name = "Welcome to the Hideout",
		description = "Join Heist Yourself and step into the hideout.",
		mark = "HI",
	},
	{
		key = "first_heist",
		tier = "bronze",
		name = "First Score",
		description = "Clear your first heist.",
		mark = "$",
	},
	{
		key = "first_clone",
		tier = "bronze",
		name = "Meet Yourself",
		description = "Rewind and see your first clone replay your run.",
		mark = "x2",
	},
	{
		key = "eight_of_me",
		tier = "silver",
		name = "8 OF ME",
		description = "Have 8 copies of yourself in one run: 7 clones and you.",
		mark = "8",
	},
	{
		key = "crew_up",
		tier = "silver",
		name = "Crew Up",
		description = "Clear a heist with a crew of 2 or more players.",
		mark = "2+",
	},
	{
		key = "daily_streak_3",
		tier = "silver",
		name = "Hot Streak",
		description = "Reach a daily vault streak of 3.",
		mark = "3",
	},
	{
		key = "ghost",
		tier = "gold",
		name = "Ghost",
		description = "Clear a heist that Gus guards without him spotting you on the winning run.",
		mark = "G",
	},
	{
		key = "met_the_boss",
		tier = "boss",
		name = "Met the Boss",
		description = "Play in the same server as the creator of Heist Yourself for a minute.",
		mark = "B",
	},
} :: { Def })

-- BEGIN BADGE IDS (tools/badge_upload.py rewrites this block; 0 = not created yet)
Badges.IDS = table.freeze({
	welcome = 3214798741459120,
	first_heist = 1080509505629504,
	first_clone = 747296253511609,
	eight_of_me = 2180491198746315,
	crew_up = 0,
	daily_streak_3 = 0,
	ghost = 0,
	met_the_boss = 1036280259639840,
} :: { [string]: number })
Badges.ICONS = table.freeze({
	welcome = 0,
	first_heist = 0,
	first_clone = 0,
	eight_of_me = 0,
	crew_up = 0,
	daily_streak_3 = 0,
	ghost = 0,
	met_the_boss = 0,
} :: { [string]: number })
-- END BADGE IDS

local byKey: { [string]: Def } = {}
for _, def in Badges.LIST do
	byKey[def.key] = def
end

-- The player attribute the server writes when a badge is newly earned (the in-game card); the boss's marks.
Badges.ATTR_TOAST = "BadgeToast" -- Player: "<key>#<n>" (n counts up, so the same key twice still changes it)
Badges.ATTR_EARNED = "BadgesEarned" -- Player: how many launch badges the profile has earned (whole number)
Badges.ATTR_BOSS = "Boss" -- Player: true on the owner / staff while they are in the server
Badges.ATTR_BOSS_HERE = "BossUserId" -- ReplicatedStorage: a boss's userId while one is here, else 0

function Badges.def(key: any): Def?
	return if type(key) == "string" then byKey[key] else nil
end

function Badges.isKey(key: any): boolean
	return type(key) == "string" and byKey[key] ~= nil
end

-- A key the profile may store: any short [a-z0-9_] id (a rollback build that does not know a newer badge keeps it).
function Badges.validStoredKey(key: any): boolean
	return type(key) == "string" and #key >= 1 and #key <= 32 and string.match(key, "^[%l%d_]+$") ~= nil
end

function Badges.idOf(key: string): number
	local id = Badges.IDS[key]
	return if type(id) == "number" and id > 0 and math.floor(id) == id then id else 0
end

function Badges.iconOf(key: string): number
	local id = Badges.ICONS[key]
	return if type(id) == "number" and id > 0 and math.floor(id) == id then id else 0
end

-- Errors on a malformed set (startup and the unit spec): unique keys, a known tier, Roblox-safe text lengths,
-- ASCII text, a short mark, ids whole and >= 0.
function Badges.validate()
	local seen = {}
	local B = Config.Badges
	for _, def in Badges.LIST do
		assert(Badges.validStoredKey(def.key), `badge key {def.key}`)
		assert(not seen[def.key], `duplicate badge {def.key}`)
		seen[def.key] = true
		assert(B.TIERS[def.tier] ~= nil, `badge {def.key}: unknown tier {def.tier}`)
		assert(#def.name >= 3 and #def.name <= B.NAME_MAX, `badge {def.key}: name length`)
		assert(#def.description >= 10 and #def.description <= B.DESCRIPTION_MAX, `badge {def.key}: description length`)
		for _, text in { def.name, def.description, def.mark } do
			assert(not string.find(text, "[^\32-\126]"), `badge {def.key}: ASCII text only`)
		end
		assert(#def.mark >= 1 and #def.mark <= 3, `badge {def.key}: mark is 1-3 characters`)
		for _, ids in { Badges.IDS, Badges.ICONS } do
			local id = ids[def.key]
			assert(type(id) == "number" and id >= 0 and math.floor(id) == id, `badge {def.key}: id must be whole, >= 0`)
		end
	end
	for key in Badges.IDS do
		assert(seen[key], `IDS has unknown badge {key}`)
	end
	for key in Badges.ICONS do
		assert(seen[key], `ICONS has unknown badge {key}`)
	end
end

---------------------------------------------------------------------------
-- Conditions (server-decided facts in, badge keys out)
---------------------------------------------------------------------------

-- One member's facts at the end of a heist (Heist/HeistInstance onOver).
export type HeistFacts = {
	complete: boolean, -- the heist was cleared (story: the goal banked; party: the first tier by sunrise)
	tainted: boolean, -- a recording failed validation (Rec/Validator): no badges from this heist
	relaxed: boolean, -- the Relaxed version (Gus sees slower): no Ghost
	guarded: boolean, -- the level has at least one Gus
	spottedFinal: boolean, -- Gus spotted this member's live run in the final run (sim EV.Spotted)
	inFinal: boolean, -- this member had a live run in the final run
	crewPlayers: number, -- real players in the crew who were still in it at the end
}

function Badges.heistBadges(f: HeistFacts): { string }
	local out: { string } = {}
	if not f.complete or f.tainted then
		return out
	end
	table.insert(out, "first_heist")
	if f.crewPlayers >= Config.Badges.CREW_UP_MIN then
		table.insert(out, "crew_up")
	end
	if f.guarded and f.inFinal and not f.spottedFinal and not f.relaxed then
		table.insert(out, "ghost")
	end
	return out
end

-- "8 OF ME": copies = that player's clones in the world plus their live run (sim EV.Swarm b).
function Badges.swarmEarned(copies: number): boolean
	return type(copies) == "number" and copies >= Config.Sim.SWARM_OF_ME
end

-- From the saved profile (a join, or after a daily vault): progress made before badges existed counts too.
export type ProfileFacts = { bestStreak: number, clears: number }

function Badges.profileBadges(p: ProfileFacts): { string }
	local out: { string } = {}
	if (tonumber(p.clears) or 0) > 0 then
		table.insert(out, "first_heist")
	end
	if (tonumber(p.bestStreak) or 0) >= Config.Badges.STREAK_DAYS then
		table.insert(out, "daily_streak_3")
	end
	return out
end

-- Earned but not sent to Roblox yet, in LIST order (the award queue on a join).
function Badges.pending(earned: { [string]: number }, sent: { [string]: boolean }): { string }
	local out: { string } = {}
	for _, def in Badges.LIST do
		if earned[def.key] ~= nil and sent[def.key] ~= true then
			table.insert(out, def.key)
		end
	end
	return out
end

-- How many launch badges a profile has earned (the BadgesEarned attribute).
function Badges.countEarned(earned: { [string]: number }): number
	local n = 0
	for _, def in Badges.LIST do
		if earned[def.key] ~= nil then
			n += 1
		end
	end
	return n
end

---------------------------------------------------------------------------
-- The boss (Played with the Owner)
---------------------------------------------------------------------------

-- The boss ids: the experience owner (a user, or the owning group's owner; 0 / nil while unknown) plus staff ids.
function Badges.bossIds(ownerId: number?, staff: { number }?): { [number]: boolean }
	local ids: { [number]: boolean } = {}
	if type(ownerId) == "number" and ownerId > 0 then
		ids[ownerId] = true
	end
	for _, id in staff or {} do
		if type(id) == "number" and id > 0 and math.floor(id) == id then
			ids[id] = true
		end
	end
	return ids
end

-- One tick of time together: (seconds after, earned now). `bossHere` = some boss other than this player is in the
-- server; a boss earns nothing from their own presence. Time only adds up while a boss is here and is never reset
-- (two short visits add up), and it stops counting once earned.
function Badges.bossTick(seconds: number, dt: number, bossHere: boolean, isBoss: boolean): (number, boolean)
	if isBoss or not bossHere or dt <= 0 or dt ~= dt then
		return seconds, false
	end
	local need = Config.Badges.BOSS_TOGETHER_SECONDS
	if seconds >= need then
		return seconds, false
	end
	local after = seconds + math.min(dt, Config.Badges.BOSS_TICK_SECONDS * 2) -- a long server hitch adds at most 2 ticks
	return after, after >= need
end

---------------------------------------------------------------------------
-- The toast attribute
---------------------------------------------------------------------------

function Badges.toastValue(key: string, n: number): string
	return key .. "#" .. tostring(math.floor(n))
end

-- The badge key in a BadgeToast value (nil for junk or an unknown key).
function Badges.parseToast(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local key = string.match(value, "^([%l%d_]+)#%d+$")
	return if key and byKey[key] then key else nil
end

return table.freeze(Badges)
