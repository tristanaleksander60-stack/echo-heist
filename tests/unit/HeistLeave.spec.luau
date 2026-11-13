-- L1: leaving a heist (garage-exit-fix; Heist/LeavePlan). The owner's v125 bug: BACK TO GARAGE mid-heist put you in
-- the hideout with "Gus caught you." and "RUN 3/8" still on screen. The client state machine, driven here with a
-- stand-in HUD and the real LeavePlan: from every heist state (a run, caught, the MENU sheet, a rewind, the deck, the
-- Line-up cut, the results card, hiding, a stale heist HUD over the hideout), the server's lobby state ends in the
-- same clean hideout, applying it again changes nothing, and a failing teardown step never leaves the HUD up. The
-- real client is checked to implement every step (HeistClient's teardown map, Hud.heistVisible / hideHeist), and the
-- watchdog, the Leave retry and the hideout zone are checked against Config.

local fs = require("@lune/fs")

local LeavePlan = require("../../src/client/Heist/LeavePlan")
local Config = require("../../src/shared/Config")
local Assert = require("./Assert")

local H = Config.Heist
local LV = H.LEAVE

-- A stand-in client: the state HeistClient keeps, a HUD of LeavePlan.HEIST_UI flags, and the teardown steps.
local function newClient(failing: string?): any
	local c: any = {
		state = {
			where = "garage",
			garage = nil,
			folder = nil,
			run = nil,
			clock = nil,
			phase = "",
			deck = nil,
			over = nil,
			frozenT = 0,
			lastRunT = 0,
			actorFx = {},
			recs = {},
			runEndedAtByRun = {},
		},
		ui = {},
		ran = {},
		binds = false,
		cameraShot = nil,
		ffOn = false,
		handsHeld = nil,
		echoes = 0,
	}
	function c.visible(): { string }
		local out = {}
		for _, name in LeavePlan.HEIST_UI do
			if c.ui[name] then
				table.insert(out, name)
			end
		end
		return out
	end
	local steps = {
		hud = function()
			table.clear(c.ui)
		end,
		binds = function()
			c.binds = false
		end,
		moments = function()
			c.cameraShot = nil
		end,
		camera = function()
			c.cameraShot = nil
			c.ffOn = false
		end,
		hands = function()
			c.handsHeld = nil
		end,
		echoes = function()
			c.echoes = 0
		end,
	}
	-- HeistClient.enterLobby's shape: reset, every step in its own pcall, reset again.
	function c.enterLobby(p: any)
		LeavePlan.reset(c.state, p)
		for _, name in LeavePlan.STEPS do
			table.insert(c.ran, name)
			local fn = steps[name]
			if name == failing then
				fn = function()
					error("injected failure in " .. name)
				end
			end
			if fn then
				pcall(fn)
			end
		end
		LeavePlan.reset(c.state, p)
	end
	-- HeistClient.handle for "Lobby" / a garage Sync.
	function c.lobby(p: any): string
		local action = LeavePlan.lobbyAction(c.state.where, c.state.where == "heist" or #c.visible() > 0)
		if action == "refresh" then
			c.state.garage = p
		else
			c.enterLobby(p)
		end
		return action
	end
	return c
end

-- Puts a client into a heist state (what HeistClient + the HUD would be showing then).
local STATES: { [string]: (c: any) -> () } = {}
STATES = {
	run = function(c)
		c.state.where, c.state.phase = "heist", "Run"
		c.state.run, c.state.clock = { run = 3 }, { length = 60 }
		c.ui.run, c.ui.menu = true, true
		c.binds, c.echoes = true, 2
	end,
	caught = function(c) -- the owner's screen: run 3 of 8, Gus caught you, between runs
		c.state.where, c.state.phase = "heist", "Between"
		c.state.run, c.state.frozenT, c.state.lastRunT = { run = 3 }, 21.4, 21.4
		c.state.deck = { locked = true }
		c.ui.run, c.ui.menu, c.ui.reason, c.ui.readyWait = true, true, true, true
		c.binds, c.cameraShot, c.handsHeld, c.echoes = true, "busted", "handsUp", 2
	end,
	menuOpen = function(c)
		STATES.run(c)
		c.ui.menuSheet = true
	end,
	rewind = function(c)
		STATES.run(c)
		c.state.reelT = 12
		c.state.actorFx[7] = { gone = "Busted" }
	end,
	deck = function(c)
		STATES.caught(c)
		c.ui.reason = nil
		c.ui.deck = true
		c.state.deck = { locked = false, slots = { {}, {} } }
	end,
	fastForward = function(c)
		STATES.run(c)
		c.ffOn = true
	end,
	hiding = function(c)
		STATES.run(c)
		c.ui.hidden = true
	end,
	lineup = function(c)
		c.state.where, c.state.phase = "heist", "Over"
		c.state.over = { leader = 1 }
		c.ui.cutscene = true
		c.cameraShot = "lineup"
	end,
	results = function(c)
		STATES.lineup(c)
		c.ui.cutscene = nil
		c.ui.results = true
	end,
	staleHud = function(c) -- the bug's end state: already "garage", the heist HUD still up
		c.state.where = "garage"
		c.ui.run, c.ui.reason = true, true
	end,
	preparing = function(c)
		c.state.where = "preparing"
	end,
}

local GARAGE = { where = "garage", lobby = true, crewId = 4, leader = 1, members = {} }

return function(test)
	test("STEPS: the heist HUD first, every view torn down, the hideout last but sound", function()
		Assert.eq(LeavePlan.STEPS[1], "hud", "the HUD goes first")
		local seen = {}
		for _, name in LeavePlan.STEPS do
			Assert.falsy(seen[name], "step listed once: " .. name)
			seen[name] = true
		end
		for _, name in
			{ "binds", "moments", "lineup", "rewind", "camera", "hands", "echoes", "gus", "world", "hideout" }
		do
			Assert.truthy(seen[name], "a teardown step: " .. name)
		end
	end)

	test("from every heist state, the lobby state ends in a clean hideout (and again changes nothing)", function()
		for name, enter in STATES do
			local c = newClient()
			enter(c)
			local action = c.lobby(GARAGE)
			if name ~= "preparing" then
				Assert.eq(action, "enter", name .. ": a heist view up -> full teardown")
			end
			Assert.truthy(LeavePlan.isClean(c.state, c.visible()), name .. ": clean hideout")
			Assert.eq(#c.visible(), 0, name .. ": no heist HUD element visible")
			Assert.eq(c.state.garage, GARAGE, name .. ": the garage state is the server's")
			Assert.falsy(c.binds, name .. ": run binds off")
			Assert.eq(c.cameraShot, nil, name .. ": no moment / Line-up camera shot")
			Assert.falsy(c.ffOn, name .. ": fast-forward off")
			Assert.eq(c.handsHeld, nil, name .. ": no held hands pose")
			Assert.eq(c.echoes, 0, name .. ": echo views destroyed")
			Assert.eq(c.state.reelT, nil, name .. ": no rewind reel")
			Assert.eq(next(c.state.actorFx), nil, name .. ": no clone effects")
			-- idempotent: the same state again is a refresh and stays clean
			Assert.eq(c.lobby(GARAGE), "refresh", name .. ": twice -> refresh")
			Assert.truthy(LeavePlan.isClean(c.state, c.visible()), name .. ": still clean")
		end
	end)

	test("a failing teardown step never leaves the heist HUD up or skips a later step", function()
		for _, failing in LeavePlan.STEPS do
			local c = newClient(failing)
			STATES.caught(c)
			c.lobby(GARAGE)
			Assert.eq(#c.ran, #LeavePlan.STEPS, failing .. " failing: every step still ran")
			if failing ~= "hud" then
				Assert.eq(#c.visible(), 0, failing .. " failing: HUD clean")
			end
			Assert.eq(c.state.where, "garage", failing .. " failing: in the hideout")
			Assert.eq(c.state.run, nil, failing .. " failing: no run")
		end
	end)

	test("lobbyAction: only a clean hideout is a refresh", function()
		Assert.eq(LeavePlan.lobbyAction("garage", false), "refresh")
		Assert.eq(LeavePlan.lobbyAction("garage", true), "enter", "a stale heist HUD in the hideout")
		Assert.eq(LeavePlan.lobbyAction("heist", false), "enter")
		Assert.eq(LeavePlan.lobbyAction("heist", true), "enter")
		Assert.eq(LeavePlan.lobbyAction("preparing", false), "enter")
		Assert.eq(LeavePlan.lobbyAction("boot", false), "enter")
	end)

	test("watchdog: no instance + the hideout + a heist view for WATCHDOG_SECONDS, never sooner", function()
		local w = LeavePlan.newWatch()
		local hold = LV.WATCHDOG_SECONDS
		Assert.falsy(LeavePlan.watch(w, 100, "", true, true, hold), "first sight")
		Assert.falsy(LeavePlan.watch(w, 100 + hold - 0.1, "", true, true, hold), "not before the hold")
		Assert.truthy(LeavePlan.watch(w, 100 + hold, "", true, true, hold), "after the hold")
		-- any other answer resets it
		for _, case in
			{
				{ "Heist_3", true, true, "in an instance (the server says so)" },
				{ "", false, true, "outside the hideout (driving, a heist far away)" },
				{ "", true, false, "nothing heist on screen" },
				{ nil, true, true, "attribute not replicated yet" },
			}
		do
			local w2 = LeavePlan.newWatch()
			LeavePlan.watch(w2, 0, "", true, true, hold)
			Assert.falsy(LeavePlan.watch(w2, hold + 1, case[1], case[2], case[3], hold), case[4])
			Assert.eq(w2.since, nil, case[4] .. ": reset")
		end
		Assert.truthy(LV.WATCHDOG_STEP < LV.WATCHDOG_SECONDS, "checked several times per hold")
	end)

	test("the hideout zone holds the lobby and none of the instance slots", function()
		local o = H.LOBBY_ORIGIN
		Assert.truthy(LeavePlan.inHideout(o[1], o[3], o, LV.HIDEOUT_RADIUS), "the lobby origin")
		Assert.truthy(LeavePlan.inHideout(o[1] + 120, o[3] - 80, o, LV.HIDEOUT_RADIUS), "the warehouse floor")
		Assert.truthy(LV.HIDEOUT_RADIUS <= H.INSTANCE_SPACING / 2, "half way to the nearest instance at most")
		for _, slot in H.INSTANCE_SLOTS do
			local x = o[1] + slot[1] * H.INSTANCE_SPACING
			local z = o[3] + slot[2] * H.INSTANCE_SPACING
			Assert.falsy(LeavePlan.inHideout(x, z, o, LV.HIDEOUT_RADIUS), "slot origin outside the hideout zone")
			-- a level reaches a few hundred studs from its origin: still outside
			Assert.falsy(
				LeavePlan.inHideout(x - slot[1] * 400, z - slot[2] * 400, o, LV.HIDEOUT_RADIUS),
				"a level's near edge"
			)
		end
	end)

	test("Leave retry: asks the server again only while still not in the hideout", function()
		Assert.falsy(LeavePlan.retryDue(nil, 50, "heist", LV.RETRY_SECONDS), "no leave pending")
		Assert.falsy(LeavePlan.retryDue(10, 10 + LV.RETRY_SECONDS - 0.1, "heist", LV.RETRY_SECONDS), "too soon")
		Assert.truthy(LeavePlan.retryDue(10, 10 + LV.RETRY_SECONDS, "heist", LV.RETRY_SECONDS), "due")
		Assert.falsy(LeavePlan.retryDue(10, 99, "garage", LV.RETRY_SECONDS), "already in the hideout")
	end)

	test("the real client implements every step and the HUD names every heist element", function()
		local client = fs.readFile("src/client/Heist/HeistClient.luau")
		for _, name in LeavePlan.STEPS do
			Assert.truthy(
				string.find(client, "\n\t\t" .. name .. " = function()", 1, true),
				"HeistClient step: " .. name
			)
		end
		Assert.truthy(string.find(client, 'kind == "Lobby"', 1, true), "HeistClient handles the Lobby state")
		Assert.truthy(string.find(client, "LeavePlan.lobbyAction(", 1, true), "through LeavePlan.lobbyAction")
		Assert.truthy(string.find(client, "LeavePlan.watch(", 1, true), "the watchdog runs")
		Assert.falsy(string.find(client, "toGarage(", 1, true), "the old one-chain teardown is gone")
		local hud = fs.readFile("src/client/Heist/Hud/init.luau")
		for _, name in LeavePlan.HEIST_UI do
			Assert.truthy(string.find(hud, 'add("' .. name .. '",', 1, true), "Hud.heistVisible names " .. name)
		end
		Assert.truthy(string.find(hud, "function hud.hideHeist()", 1, true), "Hud.hideHeist")
		local server = fs.readFile("src/server/Heist/HeistService.luau")
		Assert.truthy(string.find(server, 'push(player, "Lobby", garageState(player))', 1, true), "server sends Lobby")
		Assert.truthy(string.find(server, 'pushGarage(crew, "Lobby")', 1, true), "results timeout sends Lobby")
	end)
end
