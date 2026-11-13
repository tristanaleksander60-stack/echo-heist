-- L1: Shared/Heist/CutMath, the BIG buildings' camera-aware cut-away (Config.Big.CUT), on the real planned L1 and L6
-- buildings (Heist/TowerPlan) with the game's own diorama, classic and first-person camera maths (Heist/CameraMath):
-- the diorama above the shop with you inside opens the dollhouse (ceiling, roof and the faces on the camera's side
-- hide, the far faces stay); the diorama on the street at the spawn hides nothing (the tall front shows behind you);
-- a camera below the ceiling never opens it; a storey between the camera and you hides by the occlusion rule; the
-- first-person eye is never above the ceiling; the fade steps reach their target.

local Assert = require("./Assert")
local CameraMath = require("../../src/client/Heist/CameraMath")
local Catalog = require("../../src/shared/Levels/Catalog")
local Config = require("../../src/shared/Config")
local CutMath = require("../../src/shared/Heist/CutMath")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Strings = require("../../src/shared/Heist/Strings")
local TowerPlan = require("../../src/server/Heist/TowerPlan")

local BIG = Config.Big
local CUT = BIG.CUT
local D = Config.Heist.CAMERA.DIORAMA

local function building(level: any): (any, { any }, { string })
	local plan = TowerPlan.plan(
		level,
		(KitData :: any).parts,
		{ dressing = true },
		{ cfg = BIG, KP = KitPlan, signs = Strings.BIG_SIGN }
	)
	local b = {
		ceilY = plan.ceilY,
		minX = plan.outer.minX,
		maxX = plan.outer.maxX,
		minZ = plan.outer.minZ,
		maxZ = plan.outer.maxZ,
	}
	local groups, names = {}, {}
	for _, g in plan.groups do
		local gb = g.box
		table.insert(groups, {
			kind = g.kind,
			minX = gb.minX,
			minY = gb.minY,
			minZ = gb.minZ,
			maxX = gb.maxX,
			maxY = gb.maxY,
			maxZ = gb.maxZ,
			nx = if g.normal then g.normal[1] else 0,
			nz = if g.normal then g.normal[2] else 0,
			plane = g.plane or 0,
		})
		table.insert(names, g.name)
	end
	return b, groups, names
end

local function decide(b: any, groups: { any }, cam: { number }, you: { number }): { [string]: boolean }
	local subj = { you[1], you[2] + 1.5, you[3], you[1], you[2] - 2.2, you[3] }
	local out = {}
	CutMath.decide(b, groups, cam[1], cam[2], cam[3], subj, 2, CUT.MARGIN, CUT.INSIDE_PAD, out)
	return out
end

local function byName(names: { string }, out: { boolean }): { [string]: boolean }
	local m = {}
	for i, n in names do
		m[n] = out[i]
	end
	return m
end

local function diorama(you: { number }, yawDeg: number): { number }
	local focus = { you[1], you[2] + D.FOCUS_HEIGHT, you[3] }
	local lead = CameraMath.lead(D.FOV, D.PITCH, D.DISTANCE, D.SUBJECT_SCREEN_Y)
	local pos = CameraMath.orbit(CameraMath.ahead(focus, yawDeg, lead), yawDeg, D.PITCH, D.DISTANCE)
	return pos
end

return function(test: (string, () -> ()) -> ())
	for _, spec in { Catalog[1], Catalog[6] } do
		local level = LevelSpec.compile(spec)
		local b, groups, names = building(level)

		test(level.id .. ": the diorama above you inside opens the dollhouse on the camera's side", function()
			local o = { minX = b.minX, maxX = b.maxX, minZ = b.minZ, maxZ = b.maxZ }
			-- in the middle of the shop the camera hangs over the footprint: everything over the rooms opens
			local you = { 0, 3, -20 }
			for _, yaw in { 0, 90, 180, -90, 35 } do
				local cam = diorama(you, yaw)
				Assert.truthy(cam[2] > b.ceilY + CUT.MARGIN, "the diorama is above the ceiling")
				local h = byName(names, decide(b, groups, cam, you) :: any)
				Assert.truthy(h.ceiling and h.roof, "yaw " .. yaw .. ": ceiling and roof hide")
				local over = cam[1] > o.minX and cam[1] < o.maxX and cam[3] > o.minZ and cam[3] < o.maxZ
				if over then
					Assert.truthy(
						h.front and h.back and h.left and h.right,
						"yaw " .. yaw .. ": over the shell, all open"
					)
				end
			end
			-- near a wall the camera is outside: the face on its side hides, the opposite one stays
			local function near(p: { number }, yaw: number, mine: string, far: string)
				local h = byName(names, decide(b, groups, diorama(p, yaw), p) :: any)
				Assert.truthy(h.ceiling and h[mine] and not h[far], mine .. " hides, " .. far .. " stays")
			end
			near({ 0, 3, o.maxZ - 4 }, 0, "front", "back")
			near({ 0, 3, o.minZ + 4 }, 180, "back", "front")
			near({ o.minX + 4, 3, -20 }, -90, "left", "right")
			near({ o.maxX - 4, 3, -20 }, 90, "right", "left")
		end)

		test(
			level.id .. ": at the street spawn: you alone open nothing; the diorama's focus in the shop opens it",
			function()
				local sp = level.spawns[1]
				local you = { sp.x, sp.y, sp.z }
				local cam = diorama(you, 0)
				local h = byName(names, decide(b, groups, cam, you) :: any)
				for _, n in names do
					Assert.falsy(h[n], "you on the street: " .. n .. " shown")
				end
				-- Heist/CutAway adds the look ray's floor point (the focus leads you into the shop's door): the L1 spawn
				-- view must see plate A inside, so the ceiling, the roof and the street front open; the back stays
				local focus = CameraMath.ahead(
					{ sp.x, sp.y + D.FOCUS_HEIGHT, sp.z },
					0,
					CameraMath.lead(D.FOV, D.PITCH, D.DISTANCE, D.SUBJECT_SCREEN_Y)
				)
				local dx, dy, dz = focus[1] - cam[1], focus[2] - cam[2], focus[3] - cam[3]
				local m = math.sqrt(dx * dx + dy * dy + dz * dz)
				local lx, ly, lz =
					CutMath.lookPoint(cam[1], cam[2], cam[3], dx / m, dy / m, dz / m, CUT.LOOK_HEIGHT, CUT.LOOK_MAX)
				local subj = { you[1], you[2] + 1.5, you[3], you[1], you[2] - 2.2, you[3], lx, ly, lz }
				local out = {}
				CutMath.decide(b, groups, cam[1], cam[2], cam[3], subj, 3, CUT.MARGIN, CUT.INSIDE_PAD, out)
				local hf = byName(names, out)
				Assert.truthy(hf.ceiling and hf.roof and hf.front and not hf.back, "the shop opens toward the street")
			end
		)

		test(level.id .. ": below the ceiling nothing opens; a storey in the way hides by occlusion", function()
			local you = { 0, 3, -20 }
			-- a classic camera inside the room, under the ceiling
			local h = byName(names, decide(b, groups, { 0, 9, -8 }, you) :: any)
			Assert.falsy(h.ceiling or h.roof or h.front or h.back, "under the ceiling: nothing hides")
			-- you on the street, a camera high over the roof behind the building: the storeys between hide
			local street = { 0, 3, 16 }
			local hb = byName(names, decide(b, groups, { 0, 80, b.minZ - 40 }, street) :: any)
			Assert.truthy(hb.roof or hb.back or hb.front, "a storey between the camera and you hides")
			Assert.falsy(hb.ceiling and not (hb.roof or hb.back), "the ceiling never hides alone")
		end)

		test(level.id .. ": the first-person eye is never above the ceiling", function()
			local eyeHeight = Config.FirstPerson and Config.FirstPerson.EYE_HEIGHT or 3.8
			Assert.truthy(level.floorY + 6 + eyeHeight < b.ceilY + CUT.MARGIN, "even jumping, the eye is under it")
		end)
	end

	test("the look ray meets the floor; fades reach their targets", function()
		local x, y, z = CutMath.lookPoint(0, 30, 30, 0, -0.6, -0.8, 3, 400)
		Assert.near(y :: number, 3, 1e-9, "on the floor plane")
		Assert.near(z :: number, 30 - 36, 1e-6, "along the ray")
		Assert.eq(x, 0, "x")
		local nx = CutMath.lookPoint(0, 30, 30, 0, 0.2, -1, 3, 400)
		Assert.eq(nx, nil, "a ray looking up has no floor point")
		local a = 0
		for _ = 1, 20 do
			a = CutMath.step(a, 1, 1 / 60, CUT.SECONDS)
		end
		Assert.eq(a, 1, "faded out within " .. CUT.SECONDS .. " s")
		Assert.truthy(CutMath.segmentHitsBox(0, 0, 0, 10, 0, 0, 4, -1, -1, 6, 1, 1), "segment through a box")
		Assert.falsy(CutMath.segmentHitsBox(0, 0, 0, 3, 0, 0, 4, -1, -1, 6, 1, 1), "segment short of a box")
	end)
end
