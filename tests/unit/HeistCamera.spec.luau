-- L1: Heist/CameraMath, the pure maths of Heist/CameraDirector (PLAN_STEAM_PLUS §4.2 C0, C1),
-- the camera numbers in Config.Heist.CAMERA, and the L1 plate-A check (PROJECT_STATE
-- "Level finding": from the street spawn plate A and the clone on it were behind the shop's
-- front wall). The diorama camera at the L1 spawn must have plate A and a clone standing on it
-- inside the frame (16:9, a 19.5:9 phone, 4:3) and on a lane no level box blocks: the sim's
-- solids, the greybox van and every kit piece (Christmas layer and lamps included) as their
-- bounding boxes, so a clear lane here is clear on the real meshes.

local CameraMath = require("../../src/client/Heist/CameraMath")
local Config = require("../../src/shared/Config")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Catalog = require("../../src/shared/Levels/Catalog")
local Assert = require("./Assert")
local LevelBoxes = require("./LevelBoxes")

local C = Config.Heist.CAMERA
local D = C.DIORAMA
local ASPECTS = { ["16:9"] = 16 / 9, ["19.5:9 phone"] = 19.5 / 9, ["4:3 tablet"] = 4 / 3 }

local function level(id: string): any
	for _, spec in Catalog do
		if spec.id == id then
			return LevelSpec.compile(spec)
		end
	end
	error("no level " .. id)
end

-- The diorama camera behind a player at a spawn (CameraDirector.step with the beat over).
local function dioramaAt(spawn: any): ({ number }, number, number)
	local yaw = math.deg(spawn.yaw)
	local you = { spawn.x, spawn.y + D.FOCUS_HEIGHT, spawn.z }
	local lead = CameraMath.lead(D.FOV, D.PITCH, D.DISTANCE, D.SUBJECT_SCREEN_Y)
	local pos = CameraMath.orbit(CameraMath.ahead(you, yaw, lead), yaw, D.PITCH, D.DISTANCE)
	return pos, yaw, D.PITCH
end

local function classicAt(spawn: any): ({ number }, number, number)
	local focus = { spawn.x, spawn.y + D.FOCUS_HEIGHT, spawn.z }
	local pos = CameraMath.orbit(focus, math.deg(spawn.yaw), C.CLASSIC.PITCH, C.CLASSIC.ZOOM)
	return pos, math.deg(spawn.yaw), C.CLASSIC.PITCH
end

return function(test)
	test("config: diorama and classic numbers inside the plan's bands (C0, POLISH §4.5)", function()
		Assert.eq(C.DEFAULT_MODE, "diorama", "diorama is the default mode")
		Assert.truthy(D.PITCH >= 45 and D.PITCH <= 55, "pitch 45-55")
		Assert.truthy(D.PITCH_MIN >= 35 and D.PITCH_MIN <= D.PITCH and D.PITCH <= D.PITCH_MAX, "pitch clamp >= 35")
		Assert.truthy(D.DISTANCE >= 26 and D.DISTANCE <= 32, "distance 26-32")
		Assert.truthy(D.ZOOM_MIN < D.DISTANCE and D.DISTANCE < D.ZOOM_MAX, "zoom limits around the distance")
		Assert.truthy(D.FOV >= 40 and D.FOV <= 45, "FOV 40-45")
		Assert.eq(C.CLASSIC.FOV, 70, "classic FOV 70")
		Assert.eq(C.CLASSIC.ZOOM_MIN, 8, "classic zoom min 8")
		Assert.eq(C.CLASSIC.ZOOM, 16, "classic zoom 16")
		Assert.eq(C.CLASSIC.ZOOM_MAX, 28, "classic zoom max 28")
		Assert.le(C.FADE.IN_SECONDS, 0.1, "walls fade within 0.1 s")
		Assert.truthy(C.FADE.HZ >= 10, "about 10 Hz checks")
		Assert.le(C.FOV_KICK_MAX, 6, "FOV kicks within +-6 degrees")
	end)

	test("orbit: the camera stands up and back at the pitch, never rolls, you sit in the lower third", function()
		local you = { 0, 4.5, 14 }
		local plain, at = CameraMath.orbit(you, 0, D.PITCH, D.DISTANCE)
		Assert.near(plain[2] - you[2], D.DISTANCE * math.sin(math.rad(D.PITCH)), 1e-6, "height")
		Assert.near(plain[3] - you[3], D.DISTANCE * math.cos(math.rad(D.PITCH)), 1e-6, "behind (+Z for yaw 0)")
		Assert.eq(at[3], you[3], "looks at the focus")
		local yaw, pitch = CameraMath.angles({ at[1] - plain[1], at[2] - plain[2], at[3] - plain[3] })
		Assert.near(yaw, 0, 1e-6, "view yaw")
		Assert.near(pitch, D.PITCH, 1e-6, "view pitch")
		-- The lead puts you at SUBJECT_SCREEN_Y (the lower third) at every pitch and zoom.
		for _, p in { D.PITCH_MIN, D.PITCH, D.PITCH_MAX } do
			for _, d in { D.ZOOM_MIN, D.DISTANCE, D.ZOOM_MAX } do
				local lead = CameraMath.lead(D.FOV, p, d, D.SUBJECT_SCREEN_Y)
				Assert.truthy(lead > 0, "leads ahead")
				local pos = CameraMath.orbit(CameraMath.ahead(you, 0, lead), 0, p, d)
				local nx, ny, depth = CameraMath.project(pos, 0, p, you, D.FOV, 16 / 9)
				Assert.near(nx, 0, 1e-6, "centred across")
				Assert.near(ny, D.SUBJECT_SCREEN_Y, 1e-6, string.format("lower third at pitch %d, zoom %d", p, d))
				Assert.truthy(depth > 0, "in front")
			end
		end
		-- No roll at any yaw: a point beside you at the same height projects level with you.
		for _, y in { 0, 37, 90, 181, -120 } do
			local lead = CameraMath.lead(D.FOV, D.PITCH, D.DISTANCE, D.SUBJECT_SCREEN_Y)
			local pos = CameraMath.orbit(CameraMath.ahead(you, y, lead), y, D.PITCH, D.DISTANCE)
			local r = math.rad(y)
			local side = { you[1] + math.cos(r) * 3, you[2], you[3] - math.sin(r) * 3 }
			local _, a = CameraMath.project(pos, y, D.PITCH, you, D.FOV, 16 / 9)
			local _, b = CameraMath.project(pos, y, D.PITCH, side, D.FOV, 16 / 9)
			Assert.near(a, b, 1e-6, "level horizon at yaw " .. y)
		end
	end)

	test("input maths: drag, pinch, wrap, clamp", function()
		Assert.near(CameraMath.dragDegrees(640, 1280, D.YAW_PER_SCREEN), D.YAW_PER_SCREEN / 2, 1e-9, "half a screen")
		Assert.near(CameraMath.pinch(28, 100, 200, D.ZOOM_MIN, D.ZOOM_MAX), D.ZOOM_MIN, 1e-9, "spread: in, clamped")
		Assert.near(CameraMath.pinch(28, 200, 175, D.ZOOM_MIN, D.ZOOM_MAX), 32, 1e-9, "pinch: out")
		Assert.near(CameraMath.pinch(28, 100, 10, D.ZOOM_MIN, D.ZOOM_MAX), D.ZOOM_MAX, 1e-9, "clamped out")
		Assert.near(CameraMath.wrap(190), -170, 1e-9, "wrap")
		Assert.near(CameraMath.wrap(-180), 180, 1e-9, "wrap -180")
		Assert.near(
			CameraMath.clamp(10, D.PITCH_MIN, D.PITCH_MAX),
			D.PITCH_MIN,
			1e-9,
			"pitch never flatter than the min"
		)
	end)

	test("fade: a wall fades fully within IN_SECONDS at 30 and 60 fps, and comes back", function()
		for _, fps in { 30, 60 } do
			local a, t = 0, 0
			while a < C.FADE.ALPHA do
				a = CameraMath.approach(a, C.FADE.ALPHA, 1 / fps, C.FADE.ALPHA, C.FADE.IN_SECONDS)
				t += 1 / fps
			end
			Assert.le(t, C.FADE.IN_SECONDS + 1 / fps + 1e-9, fps .. " fps fade-out time")
			local back = 0
			while a > 0 do
				a = CameraMath.approach(a, 0, 1 / fps, C.FADE.ALPHA, C.FADE.OUT_SECONDS)
				back += 1 / fps
			end
			Assert.le(back, C.FADE.OUT_SECONDS + 1 / fps + 1e-9, fps .. " fps restore time")
		end
	end)

	test("C1 beat: always ends when the transition ends, so first control is never delayed", function()
		local H = Config.Heist
		local transitions =
			{ H.FIRST_RUN_INTRO, H.REWIND_TRANSITION[1], H.REWIND_TRANSITION[2], H.REWIND_TRANSITION[3] }
		for _, t in transitions do
			local hold, ease = CameraMath.beatWindow(t, C.BEAT_SECONDS)
			Assert.near(hold + ease, t, 1e-9, "ends with the transition " .. t)
			Assert.le(ease, C.BEAT_SECONDS + 1e-9, "eases at most BEAT_SECONDS")
			Assert.truthy(hold >= 0, "never starts before the transition")
			Assert.near(CameraMath.beatBlend(0, hold, ease), 0, 1e-9, "starts on the objective")
			Assert.near(CameraMath.beatBlend(t, hold, ease), 1, 1e-9, "on you when control returns")
		end
		-- L1 run 1 (the FTUE's first control): the intro is long enough for the full beat.
		local hold, ease = CameraMath.beatWindow(H.FIRST_RUN_INTRO, C.BEAT_SECONDS)
		Assert.near(ease, C.BEAT_SECONDS, 1e-9, "L1 intro: the whole 0.8 s ease")
		Assert.near(hold + ease, H.FIRST_RUN_INTRO, 1e-9, "L1 intro: done at first control")
		local h2, e2 = CameraMath.beatWindow(0.5, C.BEAT_SECONDS)
		Assert.near(h2, 0, 1e-9, "a short transition only eases")
		Assert.near(e2, 0.5, 1e-9, "... inside it")
	end)

	test("rayBox: hits, misses and a segment that stops short", function()
		local b = { minX = -1, minY = 0, minZ = -1, maxX = 1, maxY = 2, maxZ = 1 }
		Assert.near(CameraMath.rayBox({ -5, 1, 0 }, { 5, 1, 0 }, b) :: number, 0.4, 1e-9, "enters at 0.4")
		Assert.falsy(CameraMath.rayBox({ -5, 3, 0 }, { 5, 3, 0 }, b), "passes over")
		Assert.falsy(CameraMath.rayBox({ -5, 1, 0 }, { -2, 1, 0 }, b), "stops short")
	end)

	test("L1 plate A: in frame and unblocked from the street spawn in the diorama camera", function()
		local l1 = level("cs1_back_room")
		local spawn = l1.spawns[1]
		local plate = l1.plates[1]
		Assert.eq(plate.id, "A", "plate A")
		local pb = plate.box
		local px, pz = (pb.minX + pb.maxX) / 2, (pb.minZ + pb.maxZ) / 2
		-- the plate's top, and a clone standing on it (feet, chest, head)
		local targets = {
			plate = { px, l1.floorY + 0.3, pz },
			["plate near edge"] = { px, l1.floorY + 0.3, pb.maxZ - 0.3 },
			["clone feet"] = { px, l1.floorY + 0.5, pz },
			["clone chest"] = { px, l1.floorY + 3, pz },
			["clone head"] = { px, l1.floorY + 5.2, pz },
		}
		-- Co-op seats 2-4 stand beside and in front of seat 1: the lanes hold for them too.
		for seat = 2, #l1.spawns do
			local p2 = dioramaAt(l1.spawns[seat])
			local boxes = LevelBoxes.of(l1, true)
			local hidden = {}
			for what, p in targets do
				if
					LevelBoxes.blocked(boxes, p2, p, function(e: any): boolean
						return e.role == "plate" and e.index == 1
					end)
				then
					table.insert(hidden, what)
				end
			end
			table.sort(hidden)
			Assert.eq(#hidden, 0, string.format("seat %d hides %s", seat, table.concat(hidden, ", ")))
		end
		local pos, yaw, viewPitch = dioramaAt(spawn)
		for name, aspect in ASPECTS do
			for what, p in targets do
				local nx, ny, depth = CameraMath.project(pos, yaw, viewPitch, p, D.FOV, aspect)
				Assert.truthy(
					CameraMath.inFrame(nx, ny, depth, 0.05),
					string.format("%s: %s in frame (%.2f, %.2f)", name, what, nx, ny)
				)
			end
		end
		-- The plate sits in the upper half: the objective above, you below (composition rule).
		local _, plateY = CameraMath.project(pos, yaw, viewPitch, targets.plate, D.FOV, 16 / 9)
		Assert.truthy(plateY > 0, string.format("plate A above the centre (%.2f)", plateY))
		for _, dressing in { true, false } do
			local boxes = LevelBoxes.of(l1, dressing)
			for what, p in targets do
				local by = LevelBoxes.blocked(boxes, pos, p, function(e: any): boolean
					-- the plate's own kit piece holds the target point
					return e.role == "plate" and e.index == 1
				end)
				Assert.falsy(
					by,
					string.format("%s: %s hidden by %s", if dressing then "xmas" else "plain", what, tostring(by))
				)
			end
		end
	end)

	test(
		"L1 plate A from the classic camera at spawn: still behind the shop front (why diorama is the default)",
		function()
			local l1 = level("cs1_back_room")
			local spawn = l1.spawns[1]
			local pb = l1.plates[1].box
			local head = { (pb.minX + pb.maxX) / 2, l1.floorY + 5.2, (pb.minZ + pb.maxZ) / 2 }
			local pos = classicAt(spawn)
			local by = LevelBoxes.blocked(LevelBoxes.of(l1, true), pos, head)
			Assert.truthy(by ~= nil, "the classic follow cam does not see the clone on plate A from the street")
			print("        classic camera at the L1 spawn: the clone on plate A is behind " .. tostring(by))
		end
	)

	test("objective: the run-start beat looks at the top loot, else the most valuable item", function()
		local l1 = level("cs1_back_room")
		local cash = l1.loot[1]
		local o = CameraMath.objective(l1) :: { number }
		Assert.eq(cash.id, "Cash", "L1 loot")
		Assert.near(o[1], cash.x, 1e-9, "L1: the cash (x)")
		Assert.near(o[3], cash.z, 1e-9, "L1: the cash (z)")
		local party = level("cs5_clone_party")
		local p = CameraMath.objective(party) :: { number }
		local till = nil
		for _, item in party.loot do
			if item.top then
				till = item
			end
		end
		Assert.truthy(till ~= nil and p[1] == till.x and p[3] == till.z, "Clone Party: the till (top loot)")
		Assert.falsy(CameraMath.objective(nil), "no level, no beat")
	end)
end
