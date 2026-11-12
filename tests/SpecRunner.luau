-- Shared spec runner for tests/run_unit.luau (L1) and tests/run_sim.luau (L2).
-- A spec file returns a function that receives `test(name, fn)` and registers its
-- tests; a test fails when fn errors (use tests/unit/Assert.luau helpers).
-- Returns passed, failed, failure messages.

local fs = require("@lune/fs")

local SpecRunner = {}

function SpecRunner.run(dir: string, filter: string?): (number, number, { string })
	local passed, failed = 0, 0
	local failures: { string } = {}
	local names = fs.readDir("tests/" .. dir)
	table.sort(names)
	for _, name in names do
		if string.sub(name, -10) ~= ".spec.luau" or (filter and not string.find(name, filter, 1, true)) then
			continue
		end
		local modName = string.sub(name, 1, -6)
		print("\n" .. dir .. "/" .. name)
		local okLoad, spec = pcall(require, "./" .. dir .. "/" .. modName)
		if not okLoad or type(spec) ~= "function" then
			failed += 1
			local msg = name .. ": failed to load: " .. tostring(spec)
			table.insert(failures, msg)
			print("  FAIL  " .. msg)
			continue
		end
		spec(function(testName: string, fn: () -> ())
			local ok, err = pcall(fn)
			if ok then
				passed += 1
				print("  ok    " .. testName)
			else
				failed += 1
				table.insert(failures, name .. " > " .. testName .. ": " .. tostring(err))
				print("  FAIL  " .. testName .. "\n        " .. tostring(err))
			end
		end)
	end
	return passed, failed, failures
end

function SpecRunner.report(passed: number, failed: number, failures: { string }): number
	print(string.format("\n%d passed, %d failed", passed, failed))
	if failed > 0 then
		print("\nFailures:")
		for _, f in failures do
			print("  " .. f)
		end
	end
	return if failed > 0 then 1 else 0
end

return SpecRunner
