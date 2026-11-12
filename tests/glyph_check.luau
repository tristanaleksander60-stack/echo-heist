-- Glyph check (docs/PLAN_STEAM_PLUS.md §1 S4): no non-ASCII characters in UI strings.
-- Text glyphs used as icons (❚❚ ◐ ⏩ ⚡ ▶ ◀ ★ ✕ ● ...) render as empty boxes or as emoji
-- on phones; phase 1 uses words, phase 2 images. Scans every string literal (comments
-- are ignored) in src/client, src/first and in src/shared/Heist/Strings.luau.
-- Run from the repo root: lune run tests/glyph_check.luau

local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS = { "src/client", "src/first" } -- src/first: the loading card (ReplicatedFirst)
local FILES = { "src/shared/Heist/Strings.luau" }

-- Allowed anywhere: U+00B7 MIDDLE DOT, Strings.SEP (" · "). It is Latin-1, in every UI
-- font Roblox ships, and never an icon.
local ALLOWED: { [number]: boolean } = { [0xB7] = true }

-- Allowed in one file only, each with its reason.
-- (Empty: the clone track's bubble moved to Strings.CLONE_BUBBLE and a cross icon.)
local ALLOWED_IN: { [string]: { [number]: string } } = {}

type Lit = { line: number, text: string }

-- String literals of a Luau source, with the line each starts on. Skips comments
-- (-- and --[[ ]] / --[=[ ]=]); reads "..", '..', `..` (escapes skipped) and [[ ]].
local function literals(text: string): { Lit }
	local out: { Lit } = {}
	local i, n, line = 1, #text, 1
	local function advanceTo(stop: number)
		local _, newlines = string.gsub(string.sub(text, i, stop), "\n", "")
		line += newlines
		i = stop + 1
	end
	while i <= n do
		local c = string.sub(text, i, i)
		if c == "\n" then
			line += 1
			i += 1
		elseif string.sub(text, i, i + 1) == "--" then
			local eqs = string.match(text, "^%[(=*)%[", i + 2)
			local stop
			if eqs then
				local _, e = string.find(text, "]" .. eqs .. "]", i, true)
				stop = e or n
			else
				stop = (string.find(text, "\n", i, true) or (n + 1)) - 1
			end
			advanceTo(stop)
		elseif c == "[" and string.match(text, "^%[=*%[", i) then
			local eqs = string.match(text, "^%[(=*)%[", i) :: string
			local _, e = string.find(text, "]" .. eqs .. "]", i, true)
			local stop = e or n
			table.insert(out, { line = line, text = string.sub(text, i, stop) })
			advanceTo(stop)
		elseif c == '"' or c == "'" or c == "`" then
			local j = i + 1
			while j <= n do
				local d = string.sub(text, j, j)
				if d == "\\" then
					j += 2
				elseif d == c or (d == "\n" and c ~= "`") then
					break
				else
					j += 1
				end
			end
			local stop = math.min(j, n)
			table.insert(out, { line = line, text = string.sub(text, i, stop) })
			advanceTo(stop)
		else
			i += 1
		end
	end
	return out
end

local failures = 0
local scanned = 0

local function check(path: string)
	scanned += 1
	local allowedHere = ALLOWED_IN[path] or {}
	for _, lit in literals(fs.readFile(path)) do
		if string.find(lit.text, "[\128-\255]") then
			for _, cp in utf8.codes(lit.text) do
				if cp > 127 and not ALLOWED[cp] and not allowedHere[cp] then
					failures += 1
					print(string.format("FAIL  %s:%d  U+%04X %q in %s", path, lit.line, cp, utf8.char(cp), lit.text))
				end
			end
		end
	end
end

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			check(path)
		end
	end
end

-- With paths as arguments, only those files are checked.
if #process.args > 0 then
	ROOTS, FILES = {}, process.args
end
for _, root in ROOTS do
	walk(root)
end
for _, path in FILES do
	check(path)
end

print(string.format("glyph check: %d file(s), %d non-ASCII character(s) in UI strings", scanned, failures))
process.exit(if failures > 0 then 1 else 0)
