--!strict
-- Heist/IntroHud: what the story intro hides (owner on v125: "PICK A VAN gets in the way in the intro"). Pure
-- (Lune-tested in tests/unit/HeistIntroHud.spec.luau); the client's Heist/HudHide applies it to the instances and
-- Heist/Cinematic holds it for the whole intro, on every start path (first join from Heist/Loading, the hideout TV).
--
-- While the intro plays only its own captions, letterbox and SKIP show:
--   * every ScreenGui / BillboardGui / SurfaceGui in PlayerGui is hidden (the HUD, the lobby chips, the PICK A VAN
--     hint, the touch controls), except the KEEP names (the intro, the title card that takes over at its end, the
--     loading card under it) and any gui marked with KEEP_ATTRIBUTE;
--   * in the world, every BillboardGui drawn on top of 3D (AlwaysOnTop) outside the intro's own stage;
--   * the Roblox CoreGui pieces in Config.Intro.HUD.CORE (player list, chat, backpack, emotes).
-- Each one goes back to exactly what it was when the intro ends (one that was already hidden stays hidden), and a
-- layer the game turned on again meanwhile is hidden again (enforced every intro frame).

local Config = require("../Config")

local H = Config.Intro.HUD

local IntroHud = {}

local LAYERS: { [string]: boolean } = { ScreenGui = true, BillboardGui = true, SurfaceGui = true }

export type GuiView = {
	className: string,
	name: string,
	enabled: boolean,
	keep: boolean?, -- the KEEP_ATTRIBUTE is set
	alwaysOnTop: boolean?, -- a BillboardGui's AlwaysOnTop
	inStage: boolean?, -- part of the intro's own stage
}

local keepNames: { [string]: boolean } = {}
for _, n in H.KEEP do
	keepNames[n] = true
end

-- A PlayerGui child: hide it for the intro?
function IntroHud.hideInPlayerGui(g: GuiView): boolean
	if not LAYERS[g.className] or not g.enabled then
		return false
	end
	return not (keepNames[g.name] or g.keep == true)
end

-- A gui anywhere in the world (Workspace): hide it for the intro? Only what draws over the 3D stage.
function IntroHud.hideInWorld(g: GuiView): boolean
	if g.className ~= "BillboardGui" or not g.enabled or g.inStage == true or g.keep == true then
		return false
	end
	return g.alwaysOnTop == true
end

-- The CoreGui pieces to turn off: { name } (Enum.CoreGuiType names) with the state each had, so restore puts back
-- only what the intro changed. `current(name)` reads one (nil when unknown: left alone).
function IntroHud.corePlan(current: (string) -> boolean?): { { name: string, was: boolean } }
	local out = {}
	for _, name in H.CORE do
		local was = current(name)
		if was == true then
			table.insert(out, { name = name, was = true })
		end
	end
	return out
end

-- On restore: the state to give back to a layer the intro hid (it was enabled), unless the game already turned it
-- on again itself, or destroyed it. Returns nil when there is nothing to write.
function IntroHud.restoreValue(wasEnabled: boolean, nowEnabled: boolean, alive: boolean): boolean?
	if not alive or nowEnabled == wasEnabled then
		return nil
	end
	return wasEnabled
end

return IntroHud
