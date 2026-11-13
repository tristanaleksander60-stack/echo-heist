-- L1: golden-frame staging is Studio-only (docs/GOLDEN_FRAMES.md "Capture", Shared/Heist/Scenario).
-- The gate itself (Scenario.resolve is nil unless isStudio is true), and a source scan: every
-- file under src/ that reads the EH_Scenario attribute does so only inside
-- Scenario.resolve(RunService:IsStudio(), ...), so no code path stages on a live server.

local fs = require("@lune/fs")

local Scenario = require("../../src/shared/Heist/Scenario")
local Config = require("../../src/shared/Config")
local KitData = require("../../src/server/Kit/KitData")
local KitPlan = require("../../src/server/Heist/KitPlan")
local LobbyPlan = require("../../src/server/Heist/LobbyPlan")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local L1 = require("../../src/shared/Levels/L1_BackRoom")
local Assert = require("./Assert")

local function luauFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
end

return function(test)
	test("resolve: nil on a live server, whatever the attribute says", function()
		for _, v in { "G1", "G2", "G3", "TYPE", "CLONE_AB", "g2", " G1 " } do
			Assert.falsy(Scenario.resolve(false, v), "live server ignores " .. v)
		end
		Assert.falsy(Scenario.resolve((nil :: any) :: boolean, "G1"), "no Studio flag, no staging")
	end)

	test("resolve: the five scenarios in Studio, any case; unknown names and non-strings are nil", function()
		Assert.eq(Scenario.resolve(true, "G1"), "G1", "G1")
		Assert.eq(Scenario.resolve(true, "g2"), "G2", "lower case")
		Assert.eq(Scenario.resolve(true, " G3 "), "G3", "spaces")
		Assert.eq(Scenario.resolve(true, "TYPE"), "TYPE", "TYPE")
		Assert.eq(Scenario.resolve(true, "clone_ab"), "CLONE_AB", "CLONE_AB")
		Assert.falsy(Scenario.resolve(true, "G4"), "unknown")
		Assert.falsy(Scenario.resolve(true, ""), "empty")
		Assert.falsy(Scenario.resolve(true, 1), "number")
		Assert.falsy(Scenario.resolve(true, nil), "unset")
	end)

	test("specs: G1 / TYPE start L1, G2 / CLONE_AB the Clone Party with 7 tapes (8 OF ME), G3 the garage", function()
		Assert.eq(Scenario.spec("G1").level, "cs1_back_room", "G1 level")
		Assert.eq(Scenario.spec("TYPE").level, "cs1_back_room", "TYPE level")
		Assert.truthy(Scenario.spec("TYPE").specimen, "TYPE specimen")
		for _, name in { "G2", "CLONE_AB" } do
			local s = Scenario.spec(name)
			Assert.eq(s.level, "cs5_clone_party", name .. " level")
			Assert.eq((s.tapes or 0) + 1, 8, name .. ": you + the tapes = 8 OF ME")
		end
		Assert.falsy(Scenario.spec("G3").level, "G3 stays in the garage")
		Assert.falsy(Scenario.spec("INTRO").level, "INTRO: the garage under the story intro")
		Assert.eq(Scenario.resolve(true, " intro "), "INTRO", "INTRO resolves in Studio")
		Assert.eq(Scenario.resolve(false, "INTRO"), nil, "never on a live server")
		Assert.eq(Scenario.variant("b"), "B", "variant B")
		Assert.eq(Scenario.variant(nil), "A", "variant A by default")
	end)

	test("source scan: EH_Scenario is read only behind RunService:IsStudio()", function()
		local files = {}
		luauFiles("src", files)
		local readers = 0
		for _, path in files do
			local text = fs.readFile(path)
			local isModule = path == "src/shared/Heist/Scenario.luau"
			Assert.falsy(
				not isModule and string.find(text, '"EH_Scenario"', 1, true) ~= nil,
				path .. " names the attribute directly (use Scenario.ATTRIBUTE behind Scenario.resolve)"
			)
			for line in string.gmatch(text, "[^\n]+") do
				local code = string.gsub(line, "%-%-.*$", "")
				if not isModule and string.find(code, "Scenario.ATTRIBUTE", 1, true) then
					readers += 1
					local gated = string.find(code, "Scenario.resolve(RunService:IsStudio(),", 1, true) ~= nil
					local signal = string.find(code, "GetAttributeChangedSignal(Scenario.ATTRIBUTE)", 1, true) ~= nil
					Assert.truthy(gated or signal, path .. ": ungated read of the scenario attribute: " .. line)
				end
				if string.find(code, "Scenario.resolve(", 1, true) and not isModule then
					Assert.truthy(
						string.find(code, "Scenario.resolve(RunService:IsStudio(),", 1, true) ~= nil,
						path .. ": Scenario.resolve must be passed RunService:IsStudio(): " .. line
					)
				end
			end
		end
		Assert.truthy(readers >= 3, "the server, the client shots and the debug chip read it (" .. readers .. ")")
		-- The server only stages through Staging.active(), set once at start.
		local service = fs.readFile("src/server/Heist/HeistService.luau")
		local _, assigns = string.gsub(service, "staging = ", "")
		Assert.eq(assigns, 1, "HeistService assigns `staging` once")
		Assert.truthy(string.find(service, "staging = Staging.active()", 1, true) ~= nil, "... from Staging.active()")
	end)

	-- The first-person golden frames (REVIEW_STEAM_PLUS #4): G1 / G3 stage your look in your own eyes.
	local G = Config.Heist.CAMERA.GOLDEN
	local function within(
		eye: { number },
		yaw: number,
		pitch: number,
		p: { number },
		vfov: number,
		aspect: number
	): boolean
		-- the point in the camera's frame (CameraDirector.lookFrame: yaw about Y, then pitch down)
		local dx, dy, dz = p[1] - eye[1], p[2] - eye[2], p[3] - eye[3]
		local cy, sy = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
		local x = dx * cy - dz * sy
		local z = dx * sy + dz * cy
		local cp, sp = math.cos(math.rad(-pitch)), math.sin(math.rad(-pitch))
		local y2 = dy * cp - z * sp
		local z2 = dy * sp + z * cp
		if z2 >= -0.1 then
			return false
		end
		local th = math.tan(math.rad(vfov / 2))
		return math.abs(y2 / -z2) <= th and math.abs(x / -z2) <= th * aspect
	end

	test("lookAt: the camera director's yaw / pitch-down conventions", function()
		local yaw, pitch = Scenario.lookAt({ 0, 0, 0 }, { 0, 0, -10 })
		Assert.near(yaw, 0, 1e-9, "-Z is yaw 0")
		Assert.near(pitch, 0, 1e-9, "level")
		yaw = Scenario.lookAt({ 0, 0, 0 }, { -10, 0, 0 })
		Assert.near(yaw, 90, 1e-9, "-X is +90 (CFrame.Angles about Y)")
		local _, down = Scenario.lookAt({ 0, 5, 0 }, { 0, 0, -5 })
		Assert.near(down, 45, 1e-9, "a target below is a positive (down) pitch")
	end)

	test("G1: L1 in first person from the street spawn, the cash through the window, tilted up", function()
		Assert.truthy(Scenario.spec("G1").fp and Scenario.spec("TYPE").fp, "G1 / TYPE are first person")
		Assert.falsy(Scenario.spec("G2").fp, "G2 is the moment's pull-back")
		local level = LevelSpec.compile(L1)
		local sp = level.spawns[1]
		local st = G.G1.STAND
		Assert.truthy(st ~= nil, "G1 stands back on the street")
		local eye = { st[1], (level.floorY or 0) + 3.8, st[2] }
		-- on the street in front of the shop, behind the van, a few steps from spawn 1
		Assert.truthy(st[2] > level.van.maxZ, "behind the van, on the street")
		Assert.truthy(math.abs(st[2] - sp.z) < 25 and math.abs(st[1] - sp.x) < 15, "a few steps from spawn 1")
		local cash
		for _, item in level.loot do
			if item.id == G.G1.LOOT then
				cash = { item.x, item.y, item.z }
			end
		end
		Assert.truthy(cash ~= nil, "L1 has the golden frame's loot")
		local yaw, pitch = Scenario.fpLook(G.G1, eye, cash)
		Assert.eq(pitch, G.G1.PITCH, "the staged pitch")
		Assert.truthy(pitch < 0, "tilted up: the tenement and the aurora over the shop front")
		Assert.truthy(within(eye, yaw, pitch, cash, G.G1.FOV, 16 / 9), "the cash stays in a 16:9 frame")
		Assert.truthy(within(eye, yaw, pitch, cash, G.G1.FOV, 4 / 3), "and in a 4:3 one")
		-- the top of the frame reaches well over the shop's 12-stud storey
		local topDeg = -pitch + G.G1.FOV / 2
		Assert.truthy(topDeg > 45, string.format("the frame's top looks %.0f deg up", topDeg))
	end)

	test("G3: the hideout in first person, at the vans with the job board", function()
		local plan = LobbyPlan.plan(Config.Lobby, Config.Lighting, (KitData :: any).parts, KitPlan)
		local s = G.G3.STAND
		local eye = { s[1], 3.8, s[2] }
		local L = Config.Lobby
		Assert.truthy(math.abs(s[1]) < L.HALF_X - 2 and math.abs(s[2]) < L.HALF_Z - 2, "you stand inside the warehouse")
		for _, b in plan.bays do
			local c = b.collider
			Assert.falsy(
				s[1] > c.minX - 1 and s[1] < c.maxX + 1 and s[2] > c.minZ - 1 and s[2] < c.maxZ + 1,
				"not inside a van"
			)
		end
		local yaw, pitch = Scenario.fpLook(G.G3, eye, nil)
		Assert.eq(pitch, G.G3.PITCH, "the staged pitch")
		Assert.truthy(within(eye, yaw, pitch, plan.card.centre, G.G3.FOV, 16 / 9), "the job board's NEXT card in frame")
		local bay1
		for _, b in plan.bays do
			if b.index == 1 then
				bay1 = b
			end
		end
		local c1 = bay1.collider
		local van = { (c1.minX + c1.maxX) / 2, 3.5, (c1.minZ + c1.maxZ) / 2 }
		Assert.truthy(within(eye, yaw, pitch, van, G.G3.FOV, 16 / 9), "your van (bay 1) in frame")
		local d = math.sqrt((plan.card.centre[1] - eye[1]) ^ 2 + (plan.card.centre[3] - eye[3]) ^ 2)
		Assert.truthy(d < 26, string.format("the board is near enough to read (%.1f studs)", d))
	end)
end
