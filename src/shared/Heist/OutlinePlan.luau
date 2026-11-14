--!strict
-- Heist/OutlinePlan: which ink outlines draw (BLENDER LOOK track; docs/audit/BLENDER_LOOK.md, numbers in
-- Config.Outline). Pure: no services, no clocks. Client Heist/Outlines feeds it the units in view; the Lune specs
-- and tests/perf_engine.luau run it headless.
--
-- A unit is one character (all its hulls) or one hero / loot piece. Per tier, the nearest `cap` units of each class
-- inside `radius` studs of the camera draw their outline; a unit that is hidden (faded clone, first person, cut
-- away) never takes a slot, and your own character (third person) comes after everyone else's. A drawn hull mirrors its piece's own visibility, so it fades, prints and hides with it.
--
--   OutlinePlan.caps(tier) -> { char, loot, hero, radius }
--   OutlinePlan.pick(units, tier) -> { [key]: true }        units: { { key, class, dist, shown } }
--   OutlinePlan.visibility(on, transparency, ltm) -> number  the hull's LocalTransparencyModifier
--   OutlinePlan.worstTris(tier, heaviest) -> number          the most triangles the tier's caps can draw
--   OutlinePlan.worstUnits(tier) -> { char, loot, hero }

local Config = require("../Config") :: any

local OutlinePlan = {}

export type Caps = { char: number, loot: number, hero: number, radius: number }
-- own: your own character (it already wears its rim Highlight, Config.Clone.HALO_RIM_ALPHA): it takes a slot only
-- when every other unit of its class in range has one
export type Unit = { key: any, class: string, dist: number, shown: boolean, own: boolean? }

OutlinePlan.CLASSES = table.freeze({ "char", "loot", "hero" })

function OutlinePlan.caps(tier: number): Caps
	local O = Config.Outline
	local tiers = O.TIERS
	local t = tiers[math.clamp(math.floor(tier), 1, #tiers)]
	if not O.ENABLED then
		return { char = 0, loot = 0, hero = 0, radius = 0 }
	end
	return { char = t.char, loot = t.loot, hero = t.hero, radius = t.radius }
end

-- The units that draw an outline at this tier: per class the nearest `cap` shown units inside the radius.
function OutlinePlan.pick(units: { Unit }, tier: number): { [any]: boolean }
	local caps = OutlinePlan.caps(tier) :: any
	local byClass: { [string]: { Unit } } = {}
	for _, u in units do
		if u.shown and u.dist <= caps.radius and (caps[u.class] or 0) > 0 then
			local list = byClass[u.class]
			if not list then
				list = {}
				byClass[u.class] = list
			end
			table.insert(list, u)
		end
	end
	local out: { [any]: boolean } = {}
	for class, list in byClass do
		table.sort(list, function(a: Unit, b: Unit): boolean
			if (a.own == true) ~= (b.own == true) then
				return b.own == true
			end
			return a.dist < b.dist
		end)
		for i = 1, math.min(#list, caps[class]) do
			out[list[i].key] = true
		end
	end
	return out
end

-- A hull's LocalTransparencyModifier: hidden when it is not picked or its piece is (near) invisible, else as
-- transparent as its piece (a ghosted clone's line ghosts with it).
function OutlinePlan.visibility(on: boolean, transparency: number, ltm: number): number
	if not on then
		return 1
	end
	local shown = (1 - math.clamp(transparency, 0, 1)) * (1 - math.clamp(ltm, 0, 1))
	if shown <= 0.01 then
		return 1
	end
	return 1 - shown
end

function OutlinePlan.worstUnits(tier: number): { char: number, loot: number, hero: number }
	local c = OutlinePlan.caps(tier)
	return { char = c.char, loot = c.loot, hero = c.hero }
end

-- The most triangles the tier's caps can draw, given the heaviest unit of each class ({ char, loot, hero }:
-- triangles of one unit's hulls; a unit count larger than the scene has is still charged in full: worst case).
function OutlinePlan.worstTris(tier: number, heaviest: { [string]: number }): number
	local c = OutlinePlan.caps(tier) :: any
	local n = 0
	for _, class in OutlinePlan.CLASSES do
		n += (c[class] or 0) * (heaviest[class] or 0)
	end
	return n
end

return OutlinePlan
