-- L1: golden-frame staging is Studio-only (docs/GOLDEN_FRAMES.md "Capture", Shared/Heist/Scenario).
-- The gate itself (Scenario.resolve is nil unless isStudio is true), and a source scan: every
-- file under src/ that reads the EH_Scenario attribute does so only inside
-- Scenario.resolve(RunService:IsStudio(), ...), so no code path stages on a live server.

local fs = require("@lune/fs")

local Scenario = require("../../src/shared/Heist/Scenario")
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
end
