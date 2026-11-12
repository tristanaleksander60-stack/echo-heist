-- L0 purity check (MASTERPLAN §8.4): the deterministic layers (src/shared/Sim,
-- src/shared/Rec until it moves there, and the level data in src/shared/Levels
-- that the sim requires) must not read clocks, unseeded
-- randomness, the task scheduler or the DataModel. This is the Lune twin of the
-- second Selene config (src/shared/Sim/selene.toml), so the rule also holds
-- where selene is not installed. Comments and string literals are ignored.
-- Run from the repo root: lune run tests/pure_check.luau

local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS = { "src/shared/Sim", "src/shared/Rec", "src/shared/Levels" }

-- Lua patterns matched against code with comments and strings blanked out. Each
-- line is padded with a space, and "[^%w_%.:]" in front of a name means "a bare
-- global, not a field or method such as rec.time(".
local BANNED: { { pattern: string, why: string } } = {
	{ pattern = "[^%w_%.:]task%s*%.", why = "task scheduler" },
	{ pattern = "[^%w_%.:]os%s*%.", why = "os clock/date" },
	{ pattern = "[^%w_%.:]math%s*%.%s*random", why = "unseeded math.random" },
	{ pattern = "[^%w_%.:]Random%s*%.%s*new%s*%(%s*%)", why = "Random.new() without a seed" },
	{ pattern = "[^%w_%.:]DateTime%s*%.%s*now%f[^%w_]", why = "wall clock" },
	{ pattern = "[^%w_%.:]tick%s*%(", why = "wall clock" },
	{ pattern = "[^%w_%.:]time%s*%(", why = "wall clock" },
	{ pattern = "[^%w_%.:]elapsedTime%s*%(", why = "wall clock" },
	{ pattern = "[^%w_%.:]wait%s*%(", why = "yield" },
	{ pattern = "[^%w_%.:]delay%s*%(", why = "scheduler" },
	{ pattern = "[^%w_%.:]spawn%s*%(", why = "scheduler" },
	{ pattern = "[^%w_%.:]game%f[^%w_]", why = "DataModel" },
	{ pattern = "[^%w_%.:]workspace%f[^%w_]", why = "DataModel" },
	{ pattern = "[^%w_%.:]script%f[^%w_]", why = "DataModel" },
	{ pattern = "[^%w_%.:]Instance%s*%.", why = "engine instances" },
	{ pattern = "[^%w_%.:]getfenv%f[^%w_]", why = "environment access" },
	{ pattern = "[^%w_%.:]setfenv%f[^%w_]", why = "environment access" },
}

-- Replace comments and string contents with spaces, keeping newlines so line
-- numbers stay right. Handles --[[ ]], --[==[ ]==], "..", '..', `..` and [[ ]].
local function blank(text: string): string
	local out = table.create(#text)
	local i = 1
	local n = #text
	local function keepNewlines(s: string)
		for c in string.gmatch(s, ".") do
			table.insert(out, if c == "\n" then "\n" else " ")
		end
	end
	while i <= n do
		local c = string.sub(text, i, i)
		if string.sub(text, i, i + 1) == "--" then
			local eqs = string.match(text, "^%[(=*)%[", i + 2)
			local stop
			if eqs then
				local _, e = string.find(text, "]" .. eqs .. "]", i, true)
				stop = e or n
			else
				stop = (string.find(text, "\n", i, true) or (n + 1)) - 1
			end
			keepNewlines(string.sub(text, i, stop))
			i = stop + 1
		elseif c == "[" and string.match(text, "^%[=*%[", i) then
			local eqs = string.match(text, "^%[(=*)%[", i)
			local _, e = string.find(text, "]" .. eqs .. "]", i, true)
			local stop = e or n
			keepNewlines(string.sub(text, i, stop))
			i = stop + 1
		elseif c == '"' or c == "'" or c == "`" then
			local j = i + 1
			while j <= n do
				local d = string.sub(text, j, j)
				if d == "\\" then
					j += 2
				elseif d == c or d == "\n" then
					break
				else
					j += 1
				end
			end
			keepNewlines(string.sub(text, i, math.min(j, n)))
			i = j + 1
		else
			table.insert(out, c)
			i += 1
		end
	end
	return table.concat(out)
end

local problems = 0
local checked = 0

local function checkFile(path: string)
	checked += 1
	local code = blank(fs.readFile(path))
	local lineNo = 0
	for line in string.gmatch(code .. "\n", "([^\n]*)\n") do
		lineNo += 1
		for _, rule in BANNED do
			if string.find(" " .. line, rule.pattern) then
				problems += 1
				print(string.format("FAIL  %s:%d  %s  (%s)", path, lineNo, rule.pattern, rule.why))
			end
		end
	end
end

local function walk(dir: string)
	if not fs.isDir(dir) then
		return
	end
	local names = fs.readDir(dir)
	table.sort(names)
	for _, name in names do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			checkFile(path)
		end
	end
end

for _, root in ROOTS do
	walk(root)
end
print(string.format("pure check: %d file(s), %d problem(s)", checked, problems))
process.exit(if problems > 0 then 1 else 0)
