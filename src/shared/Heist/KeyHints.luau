--!strict
-- Heist/KeyHints: which key does what, as data, and the label a key cap shows for it on this device. The one source
-- for both: Hud/Controls, Heist/Slide, Heist/Sprint and Heist/Hideout bind their actions from KeyHints.codes, and every on-screen
-- button that has a key shows KeyHints.label in the prompt chip's key-cap style (Hud/Common.keyCap), updated live when
-- the input device changes. Pure (Lune reads it: tests/unit/HeistKeyHints.spec.luau).
--   label(action, device)            "R" / "Y" / "" (touch, or no binding on that device)
--   chord(action, modifier, device)  "Shift+Ctrl" / "LS+B" (a held modifier with the action)
--   codes(action)                    every Enum.KeyCode name bound to it (keyboard first, then gamepad)
--   prompt(device)                   the prompt chip's cap: the USE key, "TAP" on touch
-- Devices are Strings.forDevice's: "key" | "pad" | "touch". Gamepad labels are text ("Y", "LB"; ASCII only).

local Strings = require("./Strings")

local KeyHints = {}

export type Binding = { key: { string }, pad: { string } }

-- Enum.KeyCode names per action; the first of each list is the one a cap shows.
KeyHints.BINDINGS = table.freeze({
	rewind = { key = { "R" }, pad = { "ButtonY" } }, -- REWIND in a run; the next run between runs (ready)
	ready = { key = { "R" }, pad = { "ButtonY" } },
	use = { key = { "E" }, pad = { "ButtonX" } }, -- GRAB / OPEN / the hideout's USE
	menu = { key = { "M" }, pad = {} },
	view = { key = { "V" }, pad = { "ButtonSelect" } }, -- switch camera view (first person -> diorama -> classic)
	fast = { key = { "F" }, pad = { "ButtonR1" } }, -- hold to fast-forward (B is the slide's)
	crew = { key = { "Q" }, pad = { "ButtonL1" } }, -- hold for Crew View (first-person run)
	deck = { key = { "Q" }, pad = { "ButtonL1" } }, -- the Clone Deck between runs
	slide = { key = { "LeftControl", "RightControl" }, pad = { "ButtonB" } }, -- no touch slide (owner, live v125)
	-- hold Shift to sprint; L3 (the left stick pressed) toggles it on a pad; touch: the stick at its edge (no button)
	sprint = { key = { "LeftShift", "RightShift" }, pad = { "ButtonL3" } },
	back = { key = { "Backspace" }, pad = { "ButtonB" } }, -- close a station, the settings, the MENU sheet
	skip = { key = { "Space", "Return" }, pad = { "ButtonA" } }, -- the Line-up's SKIP
	skipIntro = { key = { "Space" }, pad = { "ButtonB" } }, -- the story intro (any key skips it)
	confirm = { key = {}, pad = { "ButtonA" } }, -- the gamepad's selected button
} :: { [string]: Binding })

function KeyHints.keyLabel(code: string): string
	return Strings.KEY_LABEL[code] or code
end

-- The cap for `action` on `device`: "" on touch, for an unknown action, or with no binding on that device.
function KeyHints.label(action: string, device: string): string
	local b = KeyHints.BINDINGS[action]
	if not b or device == "touch" then
		return ""
	end
	local list = if device == "pad" then b.pad else b.key
	local first = list[1]
	return if first then KeyHints.keyLabel(first) else ""
end

-- A chord: the action with a modifier held ("Ctrl+Shift", "B+LB"); "" when either has no key on that device.
function KeyHints.chord(action: string, modifier: string, device: string): string
	local a, m = KeyHints.label(action, device), KeyHints.label(modifier, device)
	if a == "" or m == "" then
		return ""
	end
	return a .. Strings.KEY_JOIN .. m
end

-- Every KeyCode name bound to `action` (keyboard, then gamepad), for ContextActionService.
function KeyHints.codes(action: string): { string }
	local b = KeyHints.BINDINGS[action]
	local out = {}
	if b then
		for _, c in b.key do
			table.insert(out, c)
		end
		for _, c in b.pad do
			table.insert(out, c)
		end
	end
	return out
end

-- The prompt chip's key cap: the USE key on keys and pads, TAP on touch (the button below is the tap target).
function KeyHints.prompt(device: string): string
	if device == "touch" then
		return Strings.KEY_TAP
	end
	return KeyHints.label("use", device)
end

return table.freeze(KeyHints)
