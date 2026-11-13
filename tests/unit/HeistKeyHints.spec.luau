-- L1: Shared/Heist/KeyHints, the key caps every on-screen action wears: the label per device (keyboard key, gamepad
-- button as a text label, nothing on touch), chords, the prompt chip's cap, and that the bindings themselves come from
-- the same table (Hud/Controls and Heist/Slide name no KeyCode of their own).

local fs = require("@lune/fs")

local KeyHints = require("../../src/shared/Heist/KeyHints")
local Strings = require("../../src/shared/Heist/Strings")
local Assert = require("./Assert")

return function(test)
	test("key hints: keyboard keys, gamepad labels, nothing on touch", function()
		local want: { { string } } = {
			{ "rewind", "R", "Y" },
			{ "use", "E", "X" },
			{ "menu", "M", "" },
			{ "fast", "F", "RB" },
			{ "crew", "Q", "LB" },
			{ "deck", "Q", "LB" },
			{ "ready", "R", "Y" },
			{ "slide", "Ctrl", "B" },
			{ "back", "Bksp", "B" },
			{ "skip", "Space", "A" },
			{ "confirm", "", "A" },
		}
		for _, w in want do
			Assert.eq(KeyHints.label(w[1], "key"), w[2], w[1] .. " on a keyboard")
			Assert.eq(KeyHints.label(w[1], "pad"), w[3], w[1] .. " on a gamepad")
			Assert.eq(KeyHints.label(w[1], "touch"), "", w[1] .. " on touch")
		end
		Assert.eq(KeyHints.label("nothing", "key"), "", "unknown action")
	end)

	test("key hints: chords and the prompt chip's cap", function()
		Assert.eq(KeyHints.chord("slide", "slideFast", "key"), "Ctrl+Shift", "fast slide on keys")
		Assert.eq(KeyHints.chord("slide", "slideFast", "pad"), "B+LB", "fast slide on a pad")
		Assert.eq(KeyHints.chord("slide", "slideFast", "touch"), "", "touch: no label")
		Assert.eq(KeyHints.prompt("key"), Strings.KEY_E, "keyboard prompt")
		Assert.eq(KeyHints.prompt("pad"), Strings.KEY_PAD, "gamepad prompt")
		Assert.eq(KeyHints.prompt("touch"), Strings.KEY_TAP, "touch prompt")
	end)

	test("key hints: labels are short ASCII, every binding a KeyCode-shaped name", function()
		for action, b in KeyHints.BINDINGS do
			for _, list in { b.key, b.pad } do
				for _, code in list do
					Assert.truthy(string.match(code, "^%u%w*$"), action .. ": KeyCode name " .. code)
					local label = KeyHints.keyLabel(code)
					Assert.truthy(#label > 0 and #label <= 5, action .. ": short label " .. label)
					Assert.falsy(string.find(label, "[\128-\255]"), action .. ": ASCII label " .. label)
				end
			end
			for _, code in b.pad do
				Assert.eq(string.sub(code, 1, 6), "Button", action .. ": a gamepad button")
			end
		end
	end)

	test("key hints: in a run the slide and the fast-forward never share a button", function()
		local inRun = { "rewind", "use", "menu", "fast", "crew", "slide" }
		for _, device in { "key", "pad" } do
			local seen: { [string]: string } = {}
			for _, action in inRun do
				local list = if device == "pad" then KeyHints.BINDINGS[action].pad else KeyHints.BINDINGS[action].key
				for _, code in list do
					Assert.eq(seen[code], nil, `{device}: {code} bound to {seen[code]} and {action}`)
					seen[code] = action
				end
			end
		end
	end)

	test("key hints: the run's controls and the slide bind from KeyHints only", function()
		for _, path in { "src/client/Heist/Hud/Controls.luau", "src/client/Heist/Slide.luau" } do
			local src = fs.readFile(path)
			Assert.falsy(string.find(src, "BindAction[^\n]*Enum%.KeyCode%."), path .. ": a KeyCode bound by hand")
			Assert.falsy(string.find(src, "end, false, Enum%.KeyCode%."), path .. ": a KeyCode bound by hand")
		end
	end)
end
