-- L1: hideout van styles (LOBBY 2; Config.Hideout.VAN.STYLES, assets/blender/van_styles.py): every style is a kit
-- group with a runtime-coloured paint piece and the Van's footprint (inside the Van's bounds, the same origin), its
-- cargo bay around the seat anchors and its side door open where the door points are; the style rules
-- (VanRules.setStyle / nextStyle / styleIndex, the claim takes the leader's saved style), the saved field
-- (Schema.vanStyle: default, repair, validVanStyle) and the STYLE verb (LobbyLook).

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local VanRules = require("../../src/shared/Heist/VanRules")
local LobbyLook = require("../../src/shared/Heist/LobbyLook")
local Schema = require("../../src/shared/Data/Schema")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")

local HD = Config.Hideout
local V = HD.VAN
local REACH = HD.SERVER_REACH
local parts = (KitData :: any).parts

-- the scene box of a kit group (Roblox axes, origin-relative)
local function scene(names: { string }): ({ number }, { number })
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, n in names do
		local s = parts[n]
		for k = 1, 3 do
			lo[k] = math.min(lo[k], s.origin[k] + s.boundsMin[k])
			hi[k] = math.max(hi[k], s.origin[k] + s.boundsMax[k])
		end
	end
	return lo, hi
end

return function(test: (string, () -> ()) -> ())
	test("styles: at least 4, unique ids and names, each a kit group with its tintable paint piece", function()
		Assert.truthy(#V.STYLES >= 4, "the step van + 3 styles")
		Assert.eq(V.STYLES[1].group, "Van", "style 1 is the kit Van")
		local groups = KitPlan.groups(parts)
		local ids = {}
		for i, s in V.STYLES do
			Assert.falsy(ids[s.id], "unique id " .. s.id)
			ids[s.id] = true
			Assert.truthy(#s.name > 0 and #s.name <= 14, "a short name " .. s.id)
			local g = groups[s.group]
			Assert.truthy(g ~= nil and #g >= 2, "kit group " .. s.group)
			local paint = parts[s.paint]
			Assert.truthy(paint ~= nil and paint.model == s.group, "paint piece " .. s.paint .. " in its group")
			Assert.truthy(
				paint.tintable == true and paint.atlas == false,
				"paint piece " .. i .. " is runtime-coloured"
			)
			for _, n in g do
				Assert.eq(parts[n].canCollide, n == "Van", "visual only (the greybox box collides): " .. n)
			end
		end
	end)

	test("every style keeps the Van's footprint, cab side, door side and seat anchors", function()
		local vlo, vhi = scene(KitPlan.groups(parts).Van)
		for _, s in V.STYLES do
			local lo, hi = scene(KitPlan.groups(parts)[s.group])
			-- the footprint: inside the Van's X / Z bounds (a hair of tolerance), on the floor
			Assert.truthy(lo[1] >= vlo[1] - 0.01 and hi[1] <= vhi[1] + 0.01, s.id .. " length within the Van's")
			Assert.truthy(lo[3] >= vlo[3] - 0.01 and hi[3] <= vhi[3] + 0.01, s.id .. " width within the Van's")
			Assert.truthy(lo[2] >= -0.01 and lo[2] < 0.5, s.id .. " stands on the floor")
			Assert.truthy(hi[2] <= vhi[2] + 0.6, s.id .. " no taller than the Van + a roof prop")
			-- the seat anchors (van space -> local) sit inside the body's box, the door points just outside it
			for k, seat in V.SEATS do
				local p = VanRules.localPoint(seat[1], seat[2], seat[3])
				Assert.truthy(
					p[1] > lo[1] and p[1] < hi[1] and p[2] > lo[2] and p[2] < hi[2] and p[3] > lo[3] and p[3] < hi[3],
					s.id .. " seat " .. k .. " inside"
				)
			end
			for name, pt in V.POINTS do
				local p = VanRules.localPoint(pt[1], pt[2], pt[3])
				Assert.truthy(p[3] * V.DOOR_Z > 0, s.id .. " point " .. name .. " on the door side")
				Assert.truthy(p[1] > lo[1] and p[1] < hi[1], s.id .. " point " .. name .. " along the body")
			end
		end
		-- the paint pieces: each style's body panels span the cargo bay on the door side and the far side
		for _, s in V.STYLES do
			local p = parts[s.paint]
			local lo, hi = scene({ s.paint })
			Assert.truthy(hi[1] - lo[1] > 12, s.id .. " paint runs the length")
			Assert.truthy(p.size[2] > 4, s.id .. " paint is the body's height")
		end
	end)

	test("rules: the leader cycles styles near the rear wheel; members, far players and bad ids are refused", function()
		local st = VanRules.new()
		local a: VanRules.Crew = { id = 1, leaderId = 101, members = { 101, 102 } }
		Assert.truthy(VanRules.claim(st, 3, a, 101, 1, 3), "claimed in the leader's saved style")
		local v = VanRules.van(st, 3) :: VanRules.Van
		Assert.eq(v.style, 3, "the saved style")
		Assert.eq(VanRules.nextStyle(v), 4, "next")
		Assert.truthy(VanRules.setStyle(st, 3, 101, VanRules.nextStyle(v), 2), "STYLE")
		Assert.eq(v.style, 4, "style 4")
		Assert.eq(VanRules.nextStyle(v), 1, "the cycle wraps")
		Assert.falsy(VanRules.setStyle(st, 3, 102, 2, 2), "a member does not restyle")
		Assert.falsy(VanRules.setStyle(st, 3, 101, #V.STYLES + 1, 2), "no such style")
		Assert.falsy(VanRules.setStyle(st, 3, 101, 0, 2), "no style 0")
		Assert.falsy(VanRules.setStyle(st, 3, 101, 2, REACH + 0.5), "too far")
		Assert.falsy(VanRules.setStyle(st, 9, 101, 2, 1), "no van")
		VanRules.setAway(st, 3)
		Assert.falsy(VanRules.setStyle(st, 3, 101, 2, 1), "not while it is on a job")
		-- a bad saved style claims the default
		local b: VanRules.Crew = { id = 2, leaderId = 201, members = { 201 } }
		VanRules.claim(st, 5, b, 201, 1, 99)
		Assert.eq((VanRules.van(st, 5) :: VanRules.Van).style, 1, "a bad style is the step van")
		Assert.eq(VanRules.styleIndex("camper"), 3, "id -> index")
		Assert.eq(VanRules.styleIndex("nope"), 1, "an unknown id is the default")
		Assert.eq(VanRules.styleIndex(nil), 1, "no id is the default")
		Assert.truthy(VanRules.validStyle(#V.STYLES) and not VanRules.validStyle(1.5), "validStyle")
	end)

	test("the saved field: additive, defaulted, repaired, validated", function()
		local h = Schema.defaultHeist() :: any
		Assert.eq(h.vanStyle, V.STYLES[1].id, "default: the step van")
		Assert.truthy(Schema.validVanStyle("bakery"), "a style id")
		Assert.falsy(Schema.validVanStyle("hovercraft"), "an unknown id")
		Assert.falsy(Schema.validVanStyle(2), "an index is not an id")
		h.vanStyle = "hovercraft"
		local repairs = Schema.sanitize(h)
		Assert.eq(h.vanStyle, V.STYLES[1].id, "repaired to the default")
		Assert.truthy(table.find(repairs, "vanStyle") ~= nil, "logged")
		h.vanStyle = nil
		Schema.sanitize(h)
		Assert.eq(h.vanStyle, V.STYLES[1].id, "a missing field is filled in")
		h.vanStyle = "security"
		Assert.eq(#Schema.sanitize(h), 0, "a good style stays")
	end)

	test("the STYLE verb: only your own van's leader, at the rear wheel; its action passes the validator", function()
		local mine = { bay = 2, mode = "parked", crewId = 1, leaderId = 101, waiting = 0, size = 1 }
		local leader = { userId = 101, crewId = 1, leader = true, crewSize = 1, seatedBay = nil, ready = false }
		Assert.eq(LobbyLook.vanVerb(mine, "style", leader), "style", "the leader restyles")
		local member = { userId = 102, crewId = 1, leader = false, crewSize = 2, seatedBay = nil, ready = false }
		Assert.eq(LobbyLook.vanVerb(mine, "style", member), nil, "a member: nothing")
		local stranger = { userId = 301, crewId = 3, leader = true, crewSize = 1, seatedBay = nil, ready = false }
		Assert.eq(LobbyLook.vanVerb(mine, "style", stranger), nil, "someone else's van: nothing")
		Assert.eq(LobbyLook.vanVerb(nil, "style", leader), "pick", "a free van: PICK")
		local a = LobbyLook.action("style", 2, 3) :: any
		Assert.truthy(a.op == "style" and a.n == 3 and VanRules.validReadyArg(a), "STYLE sends { style, bay, n }")
		-- the paint and style points do not overlap on the rear panel
		local P, S = V.POINTS.paint, V.POINTS.style
		local d = math.sqrt((P[1] - S[1]) ^ 2 + (P[2] - S[2]) ^ 2 + (P[3] - S[3]) ^ 2)
		Assert.truthy(d >= P[4] + S[4] - 0.01, "PAINT and STYLE targets apart")
	end)
end
