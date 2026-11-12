-- UI kit check (docs/PLAN_STEAM_PLUS.md §2 non-negotiables 3 and 5, §4.3 U1-U3; premium D1-D4, D8,
-- D11). Greps the client code (comments ignored) and checks the kit's data:
--   1. no TextStrokeTransparency in src/client/Heist (real strokes are UIStroke: Ui.textStroke);
--   2. no TweenInfo.new in src/client/Heist outside Heist/Motion (motion tokens only, D4);
--   3. no Gotham or SourceSans anywhere in src/client and src/shared/Heist (D1, "no default UI");
--   4. no top-level panel made visible without the enter helper: `<panel>.Visible = <anything but
--      false>` or `Visible = true` in the props of a panel, in src/client/Heist/Hud (Ui.show /
--      Ui.setShown animate it; an instant hide stays allowed);
--   5. Config.Ui: <= 5 type sizes, none drawn under 14 px at UI_SCALE_MIN; motion tokens in the D4
--      ranges; the press is 0.92 -> 1.04 -> 1.0 in 0.2-0.3 s;
--   6. the icon sheet has every icon the plan lists (27+) and every icon name the code asks for;
--   7. every uploaded UI image has its PNG in assets/ui and the other way round.
-- Run from the repo root: lune run tests/ui_kit_check.luau

local fs = require("@lune/fs")
local process = require("@lune/process")

local Config = require("../src/shared/Config")

local failures = 0
local checks = 0
local function check(ok: boolean, msg: string)
	checks += 1
	if not ok then
		failures += 1
		print("FAIL  " .. msg)
	end
end

-- Files owned by other tracks (not edited by the UI track), each with its reason.
local ALLOW_STROKE: { [string]: string } = {
	["src/client/Heist/GusView.luau"] = "Gus track (GusView): moves to Ui.textStroke with its next change",
	["src/client/Heist/WorldView.luau"] = "world track (WorldView): moves to Ui.textStroke with its next change",
}
local ALLOW_TWEEN: { [string]: string } = {
	["src/client/Heist/Motion.luau"] = "the motion module",
}

-- Source without comments (-- and --[[ ]]); string contents are kept.
local function stripComments(text: string): string
	text = string.gsub(text, "%-%-%[(=*)%[.-%]%1%]", "")
	local out = {}
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		local i = 1
		local cut = nil
		local quote: string? = nil
		while i <= #line do
			local c = string.sub(line, i, i)
			if quote then
				if c == "\\" then
					i += 1
				elseif c == quote then
					quote = nil
				end
			elseif c == '"' or c == "'" or c == "`" then
				quote = c
			elseif string.sub(line, i, i + 1) == "--" then
				cut = i
				break
			end
			i += 1
		end
		table.insert(out, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(out, "\n")
end

local function walk(dir: string, into: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path, into)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(into, path)
		end
	end
	table.sort(into)
	return into
end

local function eachLine(path: string, fn: (n: number, line: string) -> ())
	local n = 0
	for line in string.gmatch(stripComments(fs.readFile(path)) .. "\n", "(.-)\n") do
		n += 1
		fn(n, line)
	end
end

local heist = walk("src/client/Heist", {})

-- 1, 2
for _, path in heist do
	eachLine(path, function(n, line)
		if string.find(line, "TextStrokeTransparency", 1, true) and not ALLOW_STROKE[path] then
			check(false, string.format("%s:%d TextStrokeTransparency (use Ui.textStroke, a UIStroke)", path, n))
		end
		if string.find(line, "TweenInfo.new", 1, true) and not ALLOW_TWEEN[path] then
			check(false, string.format("%s:%d TweenInfo.new outside Heist/Motion (name a motion token)", path, n))
		end
	end)
end
checks += 2

-- 3
local fontFiles = walk("src/client", {})
for _, p in walk("src/shared/Heist", {}) do
	table.insert(fontFiles, p)
end
for _, path in fontFiles do
	eachLine(path, function(n, line)
		if string.find(line, "Gotham", 1, true) or string.find(line, "SourceSans", 1, true) then
			check(false, string.format("%s:%d Gotham / SourceSans (Builder Sans + the display face only)", path, n))
		end
	end)
end
checks += 1

-- 4: top-level panels (names as the Hud modules hold them).
local PANELS = {
	"deckPanel",
	"results",
	"garage",
	"menuSheet",
	"preparing",
	"hiddenPill",
	"readyWait",
	"panel", -- ctx.deck.panel
	"card", -- ctx.results.card
}
local isPanel: { [string]: boolean } = {}
for _, name in PANELS do
	isPanel[name] = true
end
for _, path in walk("src/client/Heist/Hud", {}) do
	local text = stripComments(fs.readFile(path))
	local n = 0
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		n += 1
		for name, value in string.gmatch(line, "([%w_]+)%.Visible%s*=%s*([^=][^\n]*)") do
			if isPanel[name] and not string.match(value, "^false%s*$") then
				check(false, string.format("%s:%d %s.Visible = %s (use Ui.show / Ui.setShown)", path, n, name, value))
			end
		end
		-- `local <panel> = Ui.xxx(..., { ... Visible = true` within the next lines
		local name = string.match(line, "local%s+([%w_]+)%s*=%s*Ui%.")
		if name and isPanel[name] then
			local rest = string.sub(text, (string.find(text, line, 1, true) or 1), -1)
			local props = string.match(rest, "^[^{]*(%b{})") or ""
			if string.find(props, "Visible%s*=%s*true") then
				check(
					false,
					string.format("%s:%d %s is built with Visible = true (start hidden, then Ui.show)", path, n, name)
				)
			end
		end
	end
end
checks += 1

-- 5: Config.Ui tokens
local U = Config.Ui
check(#U.TYPE_SCALE <= 5, "D2: at most 5 type sizes")
for _, size in U.TYPE_SCALE do
	check(
		size * Config.Heist.UI_SCALE_MIN >= 14,
		string.format("D2: type step %d draws under 14 px at the smallest scale", size)
	)
end
local function within(token: string, lo: number, hi: number, styles: { string }, dir: string?)
	local spec = U.MOTION[token]
	check(spec ~= nil, "motion token " .. token)
	if spec then
		check(spec[1] >= lo and spec[1] <= hi, string.format("D4: %s %.2f s outside %.2f-%.2f", token, spec[1], lo, hi))
		check(table.find(styles, spec[2]) ~= nil, string.format("D4: %s easing %s", token, spec[2]))
		if dir then
			check(spec[3] == dir, string.format("D4: %s direction %s (want %s)", token, spec[3], dir))
		end
	end
end
within("enter", 0.18, 0.30, { "Back", "Quad", "Quart", "Quint", "Cubic", "Sine" }, "Out")
within("exit", 0.10, 0.18, { "Quad" }, "In")
within("feedback", 0.06, 0.12, { "Quad", "Sine", "Linear" })
within("emphasis", 0.25, 0.45, { "Back", "Quad", "Quint", "Cubic" }, "Out")
check(U.MOTION.pressDown[1] <= 0.06, "D3: the press reaches 0.92 within 60 ms")
local release = U.MOTION.pressUp[1] + U.MOTION.pressSettle[1]
check(release >= 0.2 and release <= 0.3, string.format("D3: the release settles in %.2f s (want 0.2-0.3)", release))
check(U.PRESS_SCALE == 0.92 and U.PRESS_OVERSHOOT == 1.04, "D3: 0.92 -> 1.04 -> 1.0")
check(U.DISPLAY_FACE == "LuckiestGuy" or U.DISPLAY_FACE == "FredokaOne", "D8: DISPLAY_FACE is a built-in candidate")

-- 6: icons
local iconsData = fs.readFile("src/client/Heist/IconsData.luau")
local have: { [string]: boolean } = {}
local count = 0
for name in string.gmatch(iconsData, "\n%s*([%w_]+) = Vector2%.new") do
	have[name] = true
	count += 1
end
check(count >= 27, string.format("U2: %d icons on the sheet (want 27+)", count))
local REQUIRED = {
	"rewind",
	"clone",
	"plate",
	"door",
	"laser",
	"loot",
	"van",
	"gus",
	"star",
	"star_empty",
	"star_half",
	"menu",
	"fast_forward",
	"hidden",
	"alarm",
	"sunrise",
	"delete",
	"undo",
	"invite",
	"settings",
	"close",
	"lock",
	"check",
	"cross",
	"crown",
	"camera",
	"gift",
	"coin",
	"you",
}
for _, name in REQUIRED do
	check(have[name] == true, "U2: the icon sheet has no " .. name)
end
for _, path in heist do
	eachLine(path, function(n, line)
		for _, pat in
			{
				'iconWord%([^,]+,%s*"([%w_]+)"',
				'Icons%.attach%([^,]+,%s*"([%w_]+)"',
				'Icons%.make%([^,]+,%s*"([%w_]+)"',
				'marker%(.-,%s*"([%w_]+)"%)',
			}
		do
			for name in string.gmatch(line, pat) do
				check(
					have[name] == true,
					string.format("%s:%d asks for icon %q, which is not on the sheet", path, n, name)
				)
			end
		end
	end)
end

-- 7: uploads vs files
local uiAssets = fs.readFile("src/shared/Heist/UiAssets.luau")
local uploaded: { [string]: boolean } = {}
for stem in string.gmatch(uiAssets, "\n%s*([%w_]+) = { decal = %d+") do
	uploaded[stem] = true
	check(fs.isFile("assets/ui/" .. stem .. ".png"), "UiAssets has " .. stem .. " but assets/ui has no PNG")
end
for _, name in fs.readDir("assets/ui") do
	local stem = string.match(name, "^(.+)%.png$")
	if stem then
		check(uploaded[stem] == true, "assets/ui/" .. name .. " is not uploaded (python3 tools/kit_upload.py --ui)")
	end
end

print(string.format("ui kit check: %d check(s), %d failure(s)", checks, failures))
process.exit(if failures > 0 then 1 else 0)
