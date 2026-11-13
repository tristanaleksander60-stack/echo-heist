-- L1: the story intro hides the HUD and loads first (owner on v125: "PICK A VAN gets in the way in the intro"; "the
-- characters are just blocks in the intro"). Shared/Heist/IntroHud: which layers hide and how they come back;
-- Kit/KitLib.phases: the Rookie, then the intro's groups, then the rest; the client's kit wait fits the card.

local Config = require("../../src/shared/Config") :: any
local IntroHud = require("../../src/shared/Heist/IntroHud")
local KitLib = require("../../src/shared/Kit/KitLib")
local KitData = require("../../src/server/Kit/KitData") :: any
local Assert = require("./Assert")

local function gui(className: string, name: string, over: { [string]: any }?): any
	local g: any = { className = className, name = name, enabled = true }
	for k, v in over or {} do
		g[k] = v
	end
	return g
end

return function(test)
	test(
		"PlayerGui: the HUD, PICK A VAN, lobby chips and touch controls hide; the intro, title and card stay",
		function()
			Assert.truthy(IntroHud.hideInPlayerGui(gui("ScreenGui", "HeistHUD")), "the HUD")
			Assert.truthy(IntroHud.hideInPlayerGui(gui("ScreenGui", "HeistFX")), "the HUD's fx layer")
			Assert.truthy(IntroHud.hideInPlayerGui(gui("BillboardGui", "EH_PickAVan")), "PICK A VAN")
			Assert.truthy(IntroHud.hideInPlayerGui(gui("BillboardGui", "EH_QuickMark")), "the Quick Crew mark")
			Assert.truthy(IntroHud.hideInPlayerGui(gui("ScreenGui", "TouchGui")), "the touch controls")
			Assert.truthy(IntroHud.hideInPlayerGui(gui("SurfaceGui", "Anything")), "a SurfaceGui")
			Assert.eq(IntroHud.hideInPlayerGui(gui("ScreenGui", "EH_Intro")), false, "the intro itself")
			Assert.eq(IntroHud.hideInPlayerGui(gui("ScreenGui", "EH_Title")), false, "the title card after it")
			Assert.eq(IntroHud.hideInPlayerGui(gui("ScreenGui", "EH_Loading")), false, "the loading card")
			Assert.eq(IntroHud.hideInPlayerGui(gui("ScreenGui", "X", { keep = true })), false, "the keep attribute")
			Assert.eq(
				IntroHud.hideInPlayerGui(gui("ScreenGui", "Off", { enabled = false })),
				false,
				"already off: untouched"
			)
			Assert.eq(IntroHud.hideInPlayerGui(gui("Folder", "Stuff")), false, "not a gui layer")
		end
	)

	test("world: only billboards drawn on top hide, never the intro's own stage", function()
		Assert.truthy(IntroHud.hideInWorld(gui("BillboardGui", "Tag", { alwaysOnTop = true })), "on top")
		Assert.eq(IntroHud.hideInWorld(gui("BillboardGui", "Tag", { alwaysOnTop = false })), false, "depth-tested")
		Assert.eq(
			IntroHud.hideInWorld(gui("BillboardGui", "Glow", { alwaysOnTop = true, inStage = true })),
			false,
			"the stage's own"
		)
		Assert.eq(IntroHud.hideInWorld(gui("SurfaceGui", "Sign", { alwaysOnTop = true })), false, "surface guis stay")
	end)

	test("CoreGui: the player list, chat and backpack go off; only what was on is restored", function()
		local names = {}
		for _, n in Config.Intro.HUD.CORE do
			names[n] = true
		end
		Assert.truthy(names.PlayerList and names.Chat and names.Backpack, "the owner's three")
		local state = { PlayerList = true, Chat = false, Backpack = true }
		local plan = IntroHud.corePlan(function(n: string): boolean?
			return (state :: any)[n]
		end)
		local planned = {}
		for _, item in plan do
			planned[item.name] = item.was
		end
		Assert.eq(planned.PlayerList, true, "player list")
		Assert.eq(planned.Backpack, true, "backpack")
		Assert.eq(planned.Chat, nil, "chat was already off: left alone")
		Assert.eq(planned.EmotesMenu, nil, "unknown state: left alone")
	end)

	test("restore: back to what it was, never over the game's own change or a destroyed layer", function()
		Assert.eq(IntroHud.restoreValue(true, false, true), true, "hidden by the intro: back on")
		Assert.eq(IntroHud.restoreValue(true, true, true), nil, "already on again: nothing to write")
		Assert.eq(IntroHud.restoreValue(true, false, false), nil, "destroyed meanwhile")
	end)

	test("kit phases: the Rookie first, the intro's groups second, the rest last", function()
		local _, order = KitLib.groups(KitData.parts)
		local first, second, rest = KitLib.phases(order, Config.Kit.PRIORITY_PREFIXES, Config.Kit.INTRO_GROUPS)
		Assert.eq(#first + #second + #rest, #order, "every group once")
		local where: { [string]: string } = {}
		for _, m in first do
			where[m] = "first"
			Assert.eq(string.sub(m, 1, 6), "Rookie", m .. " in the Rookie phase")
		end
		for _, m in second do
			where[m] = "second"
		end
		for _, m in rest do
			where[m] = "rest"
		end
		for _, m in Config.Kit.INTRO_GROUPS do
			Assert.eq(where[m], "second", m .. " is a kit group loaded in the intro phase")
		end
		Assert.eq(where.Gus, "rest", "level art waits")
		local a, b, c = KitLib.phases({ "Rookie_X", "Van", "Gus", "Rookie" }, { "Rookie" }, { "Van", "Rookie" })
		Assert.eq(table.concat(a, ","), "Rookie_X,Rookie", "prefix match, order kept")
		Assert.eq(table.concat(b, ","), "Van", "an intro group already in the first phase stays there")
		Assert.eq(table.concat(c, ","), "Gus", "the rest")
	end)

	test("the client's kit wait fits under the loading card's hold, and the boot budgets are ordered", function()
		local I = Config.Intro
		Assert.truthy(
			I.KIT_WAIT_SECONDS + I.KIT_PRELOAD_SECONDS < Config.Presentation.LOADING.HOLD_MAX_SECONDS,
			"wait + preload under the card's watchdog"
		)
		local B = Config.Boot
		Assert.truthy(B.KIT_PRIORITY_SECONDS <= B.KIT_INTRO_SECONDS, "the Rookie before the intro")
		Assert.truthy(B.KIT_INTRO_SECONDS <= B.INTRO_KIT_PUBLISHED_SECONDS, "published after its phase")
		Assert.truthy(B.INTRO_KIT_PUBLISHED_SECONDS < B.KIT_READY_SECONDS, "published before the whole kit's budget")
	end)
end
