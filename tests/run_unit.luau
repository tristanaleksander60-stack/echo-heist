-- L1 unit test runner (MASTERPLAN §8.9). Runs every tests/unit/*.spec.luau.
-- Run from the repo root: lune run tests/run_unit.luau
-- Optional filter: lune run tests/run_unit.luau Codec   (only spec files containing "Codec")
-- Exits with code 1 if any test fails or a spec file fails to load.
--
-- A spec file returns a function that receives `test(name, fn)` and registers its
-- tests; a test fails when fn errors (use tests/unit/Assert.luau helpers).

local fs = require("@lune/fs")
local process = require("@lune/process")

local filter = process.args[1]
local passed, failed = 0, 0
local failures: { string } = {}

local names = fs.readDir("tests/unit")
table.sort(names)
for _, name in names do
	if string.sub(name, -10) ~= ".spec.luau" or (filter and not string.find(name, filter, 1, true)) then
		continue
	end
	local modName = string.sub(name, 1, -6)
	print("\n" .. name)
	local okLoad, spec = pcall(require, "./unit/" .. modName)
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

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then
	print("\nFailures:")
	for _, f in failures do
		print("  " .. f)
	end
end
process.exit(if failed > 0 then 1 else 0)
