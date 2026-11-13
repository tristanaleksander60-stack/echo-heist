-- Wait check (INTRO LOAD FIX): no unbounded client wait on the boot path. Every :WaitForChild in src/client and
-- src/first either names an instance Rojo ships with the place (a module, a folder of modules: it is there before
-- the script runs) or passes a timeout. Anything the server makes at runtime (EH_IntroKit, CharacterKit, the
-- LihFolk remotes, the Garage, the heist folders) or that StreamingEnabled delivers late must have a timeout and a
-- fallback, or one missing instance freezes the loading card for good ("Infinite yield possible").
-- Also: no :Wait() on game.Loaded / a signal outside ReplicatedFirst's own card script, no PreloadAsync that the
-- boot waits on without a cap (checked by name: the two preload sites are listed below with their caps).
-- Run from the repo root: lune run tests/wait_check.luau

local fs = require("@lune/fs")
local process = require("@lune/process")

local ROOTS = { "src/client", "src/first" }

-- Names that always exist when a client script runs: Rojo nodes (default.project.json) and engine children.
local SHIPPED: { [string]: boolean } = {
	Shared = true,
	LihFolk = true,
	Client = true,
	PlayerGui = true, -- the engine makes it for the local player before scripts run
}

-- Allowed one-argument waits on runtime instances, per file, each with its reason.
local ALLOWED_IN: { [string]: { [string]: string } } = {
	["src/client/init.client.luau"] = {
		Remotes = "the v0.1 path only (GAME_MODE v01): its server makes them before any client exists",
		Notify = "the v0.1 path only",
		RequestRewind = "the v0.1 path only",
	},
}

-- Every name Rojo ships under src (files without extensions, folders).
local function collect(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			SHIPPED[name] = true
			collect(path)
		else
			local base = string.match(name, "^(.-)%.server%.luau$")
				or string.match(name, "^(.-)%.client%.luau$")
				or string.match(name, "^(.-)%.luau$")
				or string.match(name, "^(.-)%.json$")
			if base and base ~= "init" then
				SHIPPED[base] = true
			end
		end
	end
end
collect("src")

local function stripComments(text: string): string
	text = string.gsub(text, "%-%-%[(=*)%[.-%]%1%]", "")
	return (string.gsub(text, "%-%-[^\n]*", ""))
end

-- The argument list of a call starting at `open` (the index of "("): top-level comma count and the text.
local function args(text: string, open: number): (string, number)
	local depth, commas, i = 0, 0, open
	while i <= #text do
		local c = string.sub(text, i, i)
		if c == "(" or c == "{" or c == "[" then
			depth += 1
		elseif c == ")" or c == "}" or c == "]" then
			depth -= 1
			if depth == 0 then
				return string.sub(text, open + 1, i - 1), commas
			end
		elseif c == "," and depth == 1 then
			commas += 1
		elseif c == '"' then
			local close = string.find(text, '"', i + 1, true)
			i = close or #text
		end
		i += 1
	end
	return string.sub(text, open + 1), commas
end

local problems: { string } = {}
local checked = 0

local function scan(path: string)
	local raw = fs.readFile(path)
	local text = stripComments(raw)
	local from = 1
	while true do
		local s, e = string.find(text, ":WaitForChild%(", from)
		if not s then
			break
		end
		from = e + 1
		checked += 1
		local inner, commas = args(text, e)
		if commas == 0 then
			local name = string.match(inner, '^%s*"([^"]+)"%s*$')
			local allowed = ALLOWED_IN[path]
			if not name then
				table.insert(
					problems,
					string.format("%s: WaitForChild(%s) without a timeout (name not a literal)", path, inner)
				)
			elseif not SHIPPED[name] and not (allowed and allowed[name]) then
				table.insert(
					problems,
					string.format(
						'%s: WaitForChild("%s") without a timeout: a runtime instance, not shipped by Rojo',
						path,
						name
					)
				)
			end
		end
	end
	-- a bare signal wait on the boot path: only the card script may wait for game.Loaded (it has its watchdog)
	for line in string.gmatch(text, "[^\n]+") do
		if string.find(line, "Loaded:Wait%(") and path ~= "src/first/Loading.client.luau" then
			table.insert(problems, path .. ": game.Loaded:Wait() outside the loading card script")
		end
	end
end

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.luau$") then
			scan(path)
		end
	end
end
for _, root in ROOTS do
	walk(root)
end

-- The two boot preloads are capped where the boot waits on them (Heist/Loading reveal: PRELOAD_MAX_SECONDS;
-- the card: FONT_WAIT). A new PreloadAsync on the client must say how the boot is protected from it.
local PRELOADS: { [string]: string } = {
	["src/first/Loading.client.luau"] = "FONT_WAIT",
	["src/client/Heist/Loading.luau"] = "PRELOAD_MAX_SECONDS",
	["src/client/Heist/Cinematic.luau"] = "KIT_PRELOAD_SECONDS", -- the intro kit's textures (waitForKit)
	["src/client/Heist/Aurora.luau"] = "async (task.spawn), nothing waits on it",
	["src/client/Audio/AudioDirector.luau"] = "async (task.spawn), nothing waits on it",
}
local function preloads(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			preloads(path)
		elseif string.match(name, "%.luau$") then
			local text = stripComments(fs.readFile(path))
			if string.find(text, "PreloadAsync") then
				local cap = PRELOADS[path]
				if not cap then
					table.insert(
						problems,
						path .. ": PreloadAsync on the client without a listed cap (tests/wait_check)"
					)
				elseif not string.find(cap, " ") and not string.find(text, cap, 1, true) then
					table.insert(problems, path .. ": its PreloadAsync cap " .. cap .. " is gone")
				end
			end
		end
	end
end
for _, root in ROOTS do
	preloads(root)
end

for _, p in problems do
	print("FAIL  " .. p)
end
print(string.format("%d WaitForChild call(s) checked, %d problem(s)", checked, #problems))
if #problems > 0 then
	process.exit(1)
end
