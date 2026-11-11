-- Compile-checks every .luau file under src/ with Lune's Luau compiler.
-- Run from the repo root: lune run tests/compile_check.luau
-- Exits with code 1 if any file fails to compile.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures = 0
local checked = 0

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			checked += 1
			local source = fs.readFile(path)
			local ok, err = pcall(luau.compile, source)
			if ok then
				print("ok    " .. path)
			else
				failures += 1
				print("FAIL  " .. path .. "\n      " .. tostring(err))
			end
		end
	end
end

walk("src")
print(string.format("\n%d file(s) checked, %d failure(s)", checked, failures))
process.exit(if failures > 0 then 1 else 0)
