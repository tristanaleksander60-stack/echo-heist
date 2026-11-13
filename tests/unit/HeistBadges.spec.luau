-- L1: Shared/Heist/Badges, the launch set of Roblox badges (BADGES track; docs/marketing/BADGES.md): the set is
-- well formed (8 badges, tiers, Roblox-safe text, ids, an icon file per badge), every condition (heist end, 8 OF ME,
-- the profile, the boss's time together), the ledger helpers and the toast attribute; the profile's badge fields
-- are additive and sanitize repairs them.

local fs = require("@lune/fs")

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local Badges = require("../../src/shared/Heist/Badges")
local Schema = require("../../src/shared/Data/Schema")
local Strings = require("../../src/shared/Heist/Strings")

local B = Config.Badges

local function facts(over: { [string]: any }?): Badges.HeistFacts
	local f = {
		complete = true,
		tainted = false,
		relaxed = false,
		guarded = true,
		spottedFinal = false,
		inFinal = true,
		crewPlayers = 1,
	}
	for k, v in over or {} do
		(f :: any)[k] = v
	end
	return f
end

local function has(list: { string }, key: string): boolean
	return table.find(list, key) ~= nil
end

return function(test: (string, () -> ()) -> ())
	test("the launch set: exactly 8 badges, valid, incl. Met the Boss, one boss tier", function()
		Badges.validate()
		Assert.eq(#Badges.LIST, 8, "launch set size (owner: start with 8)")
		local tiers = {}
		for _, def in Badges.LIST do
			tiers[def.tier] = (tiers[def.tier] or 0) + 1
			Assert.truthy(#def.name <= B.NAME_MAX, def.key .. " name")
			Assert.truthy(#def.description <= B.DESCRIPTION_MAX, def.key .. " description")
			local id = Badges.idOf(def.key)
			Assert.truthy(
				id == 0 or (math.floor(id) == id and id > 0),
				def.key .. " id is 0 (not created yet) or a real badge id"
			)
		end
		Assert.truthy(Badges.def("met_the_boss") ~= nil, "Met the Boss is in the set")
		Assert.eq(tiers.boss, 1, "one boss badge")
		Assert.truthy((tiers.bronze or 0) > 0 and (tiers.silver or 0) > 0 and (tiers.gold or 0) > 0, "every tier used")
		for _, key in { "welcome", "first_heist", "first_clone", "eight_of_me", "ghost", "crew_up", "daily_streak_3" } do
			Assert.truthy(Badges.isKey(key), key)
		end
	end)

	test("every badge has its 512 x 512 icon and the contact sheet exists", function()
		for _, def in Badges.LIST do
			local path = "docs/marketing/badges/" .. def.key .. ".png"
			Assert.truthy(fs.isFile(path), path)
			local png = fs.readFile(path)
			Assert.eq(string.sub(png, 2, 4), "PNG", path .. " is a PNG")
			Assert.eq(string.unpack(">I4", png, 17), 512, path .. " width")
			Assert.eq(string.unpack(">I4", png, 21), 512, path .. " height")
		end
		Assert.truthy(fs.isFile("docs/marketing/badges/contact_sheet.png"), "contact sheet")
	end)

	test("heist end: First Score, Crew Up, Ghost", function()
		local solo = Badges.heistBadges(facts())
		Assert.truthy(has(solo, "first_heist"), "a clear is First Score")
		Assert.falsy(has(solo, "crew_up"), "solo is not Crew Up")
		Assert.truthy(has(solo, "ghost"), "unseen on the winning run in a guarded level is Ghost")
		Assert.truthy(has(Badges.heistBadges(facts({ crewPlayers = B.CREW_UP_MIN })), "crew_up"), "a crew of 2")
		Assert.eq(#Badges.heistBadges(facts({ complete = false })), 0, "no clear, no badges")
		Assert.eq(#Badges.heistBadges(facts({ tainted = true })), 0, "a tainted heist earns nothing")
		Assert.falsy(has(Badges.heistBadges(facts({ spottedFinal = true })), "ghost"), "spotted: no Ghost")
		Assert.falsy(has(Badges.heistBadges(facts({ guarded = false })), "ghost"), "no Gus: no Ghost")
		Assert.falsy(has(Badges.heistBadges(facts({ relaxed = true })), "ghost"), "Relaxed: no Ghost")
		Assert.falsy(has(Badges.heistBadges(facts({ inFinal = false })), "ghost"), "watched the win: no Ghost")
		Assert.truthy(has(Badges.heistBadges(facts({ relaxed = true })), "first_heist"), "Relaxed still clears")
	end)

	test("8 OF ME needs Config.Sim.SWARM_OF_ME copies", function()
		Assert.eq(Config.Sim.SWARM_OF_ME, 8, "the stamp's number")
		Assert.truthy(Badges.swarmEarned(8), "8 copies")
		Assert.truthy(Badges.swarmEarned(9), "9 copies")
		Assert.falsy(Badges.swarmEarned(7), "7 copies")
		Assert.falsy(Badges.swarmEarned(nil :: any), "junk")
	end)

	test("profile: earlier clears and the daily streak count", function()
		Assert.eq(#Badges.profileBadges({ bestStreak = 0, clears = 0 }), 0, "new profile")
		local old = Badges.profileBadges({ bestStreak = B.STREAK_DAYS, clears = 2 })
		Assert.truthy(has(old, "first_heist") and has(old, "daily_streak_3"), "both")
		Assert.falsy(has(Badges.profileBadges({ bestStreak = B.STREAK_DAYS - 1, clears = 0 }), "daily_streak_3"), "2")
	end)

	test("the boss: owner + staff ids, time together adds up, never for the boss", function()
		local ids = Badges.bossIds(42, { 7, -1, 2.5 })
		Assert.truthy(ids[42] and ids[7], "owner and staff")
		Assert.falsy(ids[-1] or ids[2.5], "junk staff ids")
		Assert.eq(next(Badges.bossIds(0, {})), nil, "unknown owner, no staff: no boss")
		local need = B.BOSS_TOGETHER_SECONDS
		local tick = B.BOSS_TICK_SECONDS
		local s, earned = 0, false
		local ticks = 0
		while not earned and ticks < 1000 do
			s, earned = Badges.bossTick(s, tick, true, false)
			ticks += 1
		end
		Assert.eq(ticks, math.ceil(need / tick), "earned after BOSS_TOGETHER_SECONDS")
		local _, again = Badges.bossTick(s, tick, true, false)
		Assert.falsy(again, "earned once")
		local s2, e2 = Badges.bossTick(0, need * 10, true, false)
		Assert.falsy(e2, "a server hitch does not earn it in one tick")
		Assert.le(s2, tick * 2, "a hitch adds at most two ticks")
		Assert.eq(select(1, Badges.bossTick(10, tick, false, false)), 10, "no boss here: no time")
		local sb, eb = Badges.bossTick(0, need, true, true)
		Assert.truthy(sb == 0 and not eb, "the boss never earns it")
	end)

	test("ledger: pending in set order, counts, the toast attribute round-trips", function()
		local earned = { ghost = 1, welcome = 2, retired_key = 3 }
		local pending = Badges.pending(earned, { welcome = true })
		Assert.eq(#pending, 1, "one unsent known badge")
		Assert.eq(pending[1], "ghost", "ghost")
		Assert.eq(Badges.countEarned(earned), 2, "unknown keys are not counted")
		Assert.eq(Badges.parseToast(Badges.toastValue("eight_of_me", 3)), "eight_of_me", "round trip")
		Assert.eq(Badges.parseToast("nope#1"), nil, "unknown key")
		Assert.eq(Badges.parseToast("eight_of_me"), nil, "no counter")
		Assert.eq(Badges.parseToast(5), nil, "junk")
		Assert.eq(Strings.badgeCount(3, 8), "3 OF 8 BADGES", "count line")
	end)

	test("profile fields: additive defaults, sanitize repairs junk, keeps unknown keys", function()
		local h = Schema.defaultHeist() :: any
		Assert.eq(next(h.badges), nil, "no badges by default")
		Assert.eq(next(h.badgesSent), nil, "none sent by default")
		h.badges = { welcome = 100, ghost = "x", ["BAD KEY"] = 1, future_badge = 5 }
		h.badgesSent = { welcome = true, future_badge = "yes", first_clone = true }
		local repairs = Schema.sanitize(h)
		Assert.eq(h.badges.welcome, 100, "kept")
		Assert.eq(h.badges.future_badge, 5, "an unknown (newer) badge is kept")
		Assert.eq(h.badges.ghost, nil, "junk time dropped")
		Assert.eq(h.badges["BAD KEY"], nil, "bad key dropped")
		Assert.truthy(h.badgesSent.welcome, "sent kept")
		Assert.eq(h.badgesSent.future_badge, nil, "junk sent flag dropped")
		Assert.eq(h.badgesSent.first_clone, nil, "sent without earned dropped")
		Assert.truthy(#repairs >= 4, "repairs reported")
		local old = Schema.defaultHeist() :: any
		old.badges = nil
		old.badgesSent = 7
		Schema.sanitize(old)
		Assert.truthy(type(old.badges) == "table" and type(old.badgesSent) == "table", "missing / wrong type filled")
		Assert.eq(#Schema.sanitize(old), 0, "clean after repair")
	end)
end
