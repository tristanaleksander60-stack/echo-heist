-- L1: Heist/LobbyPlan, the garage v1 layout (PLAN_STEAM_PLUS §4.1 W6, docs/GOLDEN_FRAMES.md G3), and Heist/JobCard
-- (the NEXT card's words). Pure: the same plan the server builds and level_shots.py --garage renders.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LobbyPlan = require("../../src/server/Heist/LobbyPlan")
local BackdropPlan = require("../../src/shared/Heist/BackdropPlan")
local JobCard = require("../../src/shared/Heist/JobCard")
local Strings = require("../../src/shared/Heist/Strings")
local Catalog = require("../../src/shared/Levels/Catalog")

local C = Config.Lobby
local LIGHT = Config.Lighting
local specs: { [string]: any } = (KitData :: any).parts

local function overlapXZ(a: any, b: any, tol: number): boolean
	return a.minX < b.maxX - tol and a.maxX > b.minX + tol and a.minZ < b.maxZ - tol and a.maxZ > b.minZ + tol
end

return function(test: (string, () -> ()) -> ())
	local plan = LobbyPlan.plan(C, LIGHT, specs, KitPlan)
	local grey = LobbyPlan.plan(C, LIGHT, nil, KitPlan)

	test("8 van bays, bay 1 yours against the back wall beside the roll-up door, vans clear of each other", function()
		Assert.eq(#plan.bays, 8, "8 bays")
		Assert.eq(#grey.bays, 8, "8 bays without the kit too")
		Assert.truthy(plan.bays[1].yours and plan.bays[1].row == "back", "bay 1 is yours, in the back row")
		local yours = 0
		for i, a in plan.bays do
			yours += if a.yours then 1 else 0
			local c = a.collider
			Assert.truthy(
				c.minX >= -C.HALF_X and c.maxX <= C.HALF_X and c.minZ >= -C.HALF_Z and c.maxZ <= C.HALF_Z,
				"bay " .. i .. ": the van inside the garage"
			)
			Assert.truthy(c.maxY - c.minY > 6, "bay " .. i .. ": a van-sized collider")
			for j, b in plan.bays do
				if i < j then
					Assert.falsy(overlapXZ(c, b.collider, 0.01), "vans " .. i .. " and " .. j .. " overlap")
				end
			end
			-- the door gap in the back wall stays clear of every van
			local d0, d1 = C.DOOR_X - C.DOOR_W / 2, C.DOOR_X + C.DOOR_W / 2
			if a.row == "back" then
				Assert.truthy(c.maxX <= d0 or c.minX >= d1, "bay " .. i .. ": clear of the roll-up door")
			end
		end
		Assert.eq(yours, 1, "one bay is yours")
		-- every bay has its own paint: mid values, never Getaway White
		local seen = {}
		for i, b in plan.bays do
			local p = b.paint
			local luma = (0.2126 * p[1] + 0.7152 * p[2] + 0.0722 * p[3]) / 255
			Assert.truthy(luma > 0.25 and luma < 0.6, "bay " .. i .. ": mid-value paint (" .. luma .. ")")
			local key = table.concat(p, ",")
			Assert.falsy(seen[key], "bay " .. i .. ": its own paint")
			seen[key] = true
		end
	end)

	test("the spawn and the aisle stay clear; spawnFor spreads crews round the spawn", function()
		local sx, sz = plan.spawn[1], plan.spawn[2]
		Assert.truthy(math.abs(sx) < C.HALF_X - 8 and math.abs(sz) < C.HALF_Z - 8, "spawn inside, off the walls")
		for i, b in plan.bays do
			local c = b.collider
			-- the 4 x 2 spread of Lobby.spawnFor: x +-4.5, z 0..3 from the spawn, plus a character's 2-stud half
			local spread = KitPlan.box(sx - 6.5, 0, sz - 2, sx + 6.5, 6, sz + 5)
			Assert.falsy(overlapXZ(spread, c, 0), "bay " .. i .. ": a van on the spawn spread")
		end
		local board = KitPlan.box(plan.board.x - 3, 0, plan.board.z - 3, plan.board.x + 3, 8, plan.board.z + 3)
		Assert.falsy(overlapXZ(board, plan.bays[1].collider, 0), "the job board stands beside your van, not in it")
	end)

	test("lights: work lamp per bay, yours the brightest and shadowed; every view inside the light budget", function()
		local work, yoursLamp = 0, nil
		for _, l in plan.lamps do
			if l.kind == "work" then
				work += 1
			elseif l.kind == "yours" then
				yoursLamp = l
			end
		end
		Assert.eq(work, 8, "a work lamp at each bay")
		Assert.truthy(yoursLamp ~= nil and yoursLamp.shadows, "your bay's lamp is the shadowed key")
		for _, l in plan.lamps do
			if l ~= yoursLamp then
				Assert.truthy(l.brightness < (yoursLamp :: any).brightness, l.kind .. " dimmer than your bay")
			end
			local lit, shadowed = LobbyPlan.lightsNear(plan, l.x, l.z, LIGHT.VIEW_RADIUS)
			Assert.le(lit, LIGHT.MAX_LIGHTS_PER_VIEW, l.kind .. ": lights in one view")
			Assert.le(shadowed, LIGHT.MAX_SHADOWED_PER_VIEW, l.kind .. ": shadowed lights in one view")
		end
		local lit = LobbyPlan.lightsNear(plan, plan.spawn[1], plan.spawn[2], LIGHT.VIEW_RADIUS)
		Assert.le(lit, LIGHT.MAX_LIGHTS_PER_VIEW, "spawn view light budget")
	end)

	test("kit: walls, the roll-up door, floor tiles, 8 vans, lamps, the board, trophies; all inside the lot", function()
		local count: { [string]: number } = {}
		local b = plan.bounds
		for _, it in plan.items do
			count[it.role] = (count[it.role] or 0) + 1
			Assert.eq(it.mode, "visual", it.role .. ": visual only (the greybox collides)")
			local box = KitPlan.itemBox(it :: any, specs)
			Assert.truthy(
				box.minX >= b.minX - 0.5
					and box.maxX <= b.maxX + 0.5
					and box.minZ >= b.minZ - 0.5
					and box.maxZ <= b.maxZ + 0.5,
				it.role .. " " .. it.pieces[1] .. ": inside the lot"
			)
			for _, name in it.pieces do
				Assert.truthy(specs[name] ~= nil, name .. " is a kit piece")
			end
			if it.role == "van" then
				Assert.truthy(it.color ~= nil, "van " .. tostring(it.index) .. ": a paint colour")
				Assert.truthy(table.find(it.pieces, "Van_Paint") ~= nil, "van: the paint part")
			end
		end
		Assert.eq(count.van, 8, "8 kit vans")
		Assert.eq(count.door, 1, "one roll-up door")
		Assert.eq(count.board, 1, "one job board")
		Assert.eq(count.floor, (2 * C.HALF_X / 8) * (2 * C.HALF_Z / 8), "floor tiles fill the interior")
		Assert.truthy((count.wall or 0) >= 30, "brick wall tiles round the garage")
		Assert.truthy((count.trophy or 0) >= 1, "a trophy on your shelf")
		Assert.eq(count.lamp, 9 + #C.AISLE_LAMPS, "8 work-lamp fixtures, the aisle floods and the street lamp")
		for _, it in plan.items do
			if it.role == "lamp" and it.pieces[1] == "Lamp_Ceiling" then
				for i, bay in plan.bays do
					local c = bay.collider
					local inside = it.pivot.x > c.minX
						and it.pivot.x < c.maxX
						and it.pivot.z > c.minZ
						and it.pivot.z < c.maxZ
					Assert.falsy(inside, "a work lamp fixture hangs over van " .. i)
				end
			end
		end
		Assert.truthy((count.snow or 0) >= 2, "snow at the door")
		Assert.eq(#grey.items, 0, "no kit: no items (greybox only)")
	end)

	test("the wall colliders close the room except the roll-up door gap", function()
		local d0, d1 = C.DOOR_X - C.DOOR_W / 2, C.DOOR_X + C.DOOR_W / 2
		for _, w in plan.walls do
			Assert.eq(w.maxY, C.WALL_H, "walls are WALL_H tall")
			local onBack = w.maxZ <= -C.HALF_Z + 1e-6
			if onBack then
				Assert.truthy(w.maxX <= d0 + 1e-6 or w.minX >= d1 - 1e-6, "the door gap is open")
			end
		end
		Assert.eq(#plan.walls, 5, "back wall in two runs, front, left, right")
	end)

	test("the NEXT card sits on the board's slot (manifest card), in front of the board", function()
		local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json"))
		local card = manifest.parts.JobBoard.card
		Assert.truthy(card ~= nil, "the JobBoard manifest has a card")
		for k = 1, 3 do
			Assert.near(C.BOARD.card.centre[k], card.centre[k], 1e-3, "card centre " .. k .. " matches the manifest")
		end
		Assert.near(C.BOARD.card.size[1], card.size[1], 1e-3, "card width")
		Assert.near(C.BOARD.card.size[2], card.size[2], 1e-3, "card height")
		local c = plan.card.centre
		local dx, dz = c[1] - plan.board.x, c[3] - plan.board.z
		Assert.truthy(math.sqrt(dx * dx + dz * dz) < 2, "the card is on the board")
		Assert.truthy(c[2] > 3 and c[2] < 7, "at eye height")
	end)

	test("backdrop: the garage site is the lot with the street apron; no snow inside", function()
		local site = BackdropPlan.garageSite()
		Assert.near(site.bounds.minZ, plan.bounds.minZ, 1e-6, "the lot reaches across the street apron")
		Assert.near(site.bounds.maxX, plan.bounds.maxX, 1e-6, "lot width")
		local fp = site.footprint :: any
		Assert.truthy(fp ~= nil, "a footprint")
		Assert.truthy(BackdropPlan.inside(fp, plan.spawn[1], plan.spawn[2]), "the spawn is indoors")
		Assert.falsy(BackdropPlan.inside(fp, C.STREET_LAMP.x, C.STREET_LAMP.z), "the street lamp is outdoors")
	end)

	test("JobCard: the first unlocked level without a medal, else ALL DONE; the server's first card", function()
		Assert.eq(JobCard.title(nil), nil, "no sync: keep the server's card")
		local levels = {
			{ name = "Back Room", unlocked = true, medals = { "Clear" } },
			{ name = "Two Doors", unlocked = true, medals = {} },
			{ name = "Clone Party", unlocked = false, medals = {} },
		}
		Assert.eq(JobCard.title(levels), "TWO DOORS", "next job")
		levels[2].medals = { "Clear" }
		Assert.eq(JobCard.title(levels), Strings.JOB_BOARD_ALL_DONE, "all unlocked cleared")
		Assert.eq(JobCard.first(Catalog), string.upper(Catalog[1].name), "the first catalog level")
		for _, s in { Strings.JOB_BOARD_NEXT, Strings.JOB_BOARD_ALL_DONE } do
			Assert.truthy(string.match(s, "^[%w%s%p]+$") ~= nil, "ASCII card text")
		end
	end)

	-- The warehouse hideout (PLAN_FIRST_PERSON §5 "BIG", Config.Lobby.WAREHOUSE)
	test(
		"warehouse: a high roof on trusses with skylights, the shell's cut-away groups, a ceiling over the floor",
		function()
			local W = C.WAREHOUSE
			Assert.truthy(plan.topY >= 28, "a high roof (" .. plan.topY .. ")")
			Assert.truthy(plan.ceilY > C.WALL_H + 8, "the trusses well over the ground course")
			local names = {}
			for _, g in plan.groups do
				names[g.name] = g.kind
			end
			for _, n in { "front", "back", "left", "right" } do
				Assert.eq(names[n], "face", n .. ": a face group")
			end
			Assert.eq(names.roof, "roof", "the roof group")
			Assert.eq(names.trusses, "roof", "the trusses group")
			local trusses, skylights, deckArea = 0, 0, 0
			for _, it in plan.items do
				if it.pieces[1] == "Truss_8" then
					trusses += 1
				end
			end
			for _, p in plan.parts do
				if p.name == "Skylight" then
					skylights += 1
					Assert.truthy((p.alpha or 0) > 0.3, "skylight glass you can see the aurora through")
				elseif p.name == "RoofDeck" then
					deckArea += p.size[1] * p.size[3]
				end
			end
			Assert.truthy(trusses >= 40, "steel trusses across the depth (" .. trusses .. ")")
			Assert.eq(skylights, #W.SKYLIGHTS, "the skylights")
			local holes = 0
			for _, sk in W.SKYLIGHTS do
				holes += sk[3] * sk[4]
			end
			Assert.near(
				deckArea + holes,
				(2 * C.HALF_X) * (2 * C.HALF_Z),
				1,
				"the roof covers the floor but the skylights"
			)
		end
	)

	test("warehouse: the mezzanine over the front row, its stair rises from the floor to the deck, guards", function()
		local W = C.WAREHOUSE
		local M = W.MEZZANINE
		local deck, ramp, guards, posts = nil, nil, 0, 0
		for _, p in plan.parts do
			if p.name == "MezzanineDeck" then
				deck = p
			elseif p.name == "StairRamp" then
				ramp = p
			elseif p.name == "Guard" then
				guards += if p.collide then 1 else 0
			elseif p.name == "MezzaninePost" then
				posts += if p.collide then 1 else 0
			end
		end
		Assert.truthy(deck ~= nil and deck.collide, "a walkable deck")
		local top = deck.pos[2] + deck.size[2] / 2
		Assert.truthy(ramp ~= nil and ramp.collide and ramp.wedge, "a wedge stair collider")
		Assert.near(ramp.size[2], top, 1e-6, "the stair rises to the deck top")
		Assert.near(ramp.pos[3] + ramp.size[3] / 2, M.z0, 1e-6, "its high end at the deck's edge")
		Assert.eq(ramp.yaw or 0, 0, "a wedge rises toward +Z at yaw 0 (engine_smoke checks it)")
		Assert.truthy(guards >= 3 and posts >= 4, "guards on the walls, posts under the deck")
		-- the deck clears every van under it, and the spawn spread is not under the stair
		for i, b in plan.bays do
			Assert.truthy(b.collider.maxY < M.deckY - 1, "van " .. i .. " fits under the deck")
		end
		local st = W.STAIR
		local sx, sz = plan.spawn[1], plan.spawn[2]
		Assert.truthy(sx + 6.5 < st.x0 or sz + 5 < st.z0, "the stair is off the spawn spread")
	end)

	test("warehouse: anchors for the LOBBY track's stations, inside the garage, clear of the vans", function()
		local byName = {}
		for _, a in plan.anchors do
			byName[a.name] = a
			Assert.truthy(math.abs(a.x) <= C.HALF_X and math.abs(a.z) <= C.HALF_Z, a.name .. ": inside")
		end
		for _, n in { "JobBoardSpot", "LaptopSpot", "WardrobeSpot", "TVSpot", "CrewSign" } do
			Assert.truthy(byName[n] ~= nil, n)
		end
		for i = 1, 8 do
			local a = byName["VanBay" .. i]
			Assert.truthy(a ~= nil, "VanBay" .. i)
			Assert.near(a.x, plan.bays[i].x, 1e-6, "VanBay" .. i .. " at its bay")
		end
		for _, n in { "LaptopSpot", "WardrobeSpot", "CrewSign", "JobBoardSpot" } do
			local a = byName[n]
			for i, b in plan.bays do
				local c = b.collider
				Assert.falsy(a.x > c.minX and a.x < c.maxX and a.z > c.minZ and a.z < c.maxZ, n .. " inside van " .. i)
			end
		end
		-- the same anchors without the kit (the greybox garage)
		Assert.eq(#grey.anchors, #plan.anchors, "anchors in the greybox garage too")
	end)
end
