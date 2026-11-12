-- L1: Heist/PresentPlan, the pure timing of the presentation shell (PLAN_STEAM_PLUS §3.4, §4.1 W7,
-- §4.2 C2 + C4; premium G1, H1, H4; POLISH §4.6): the title beat schedule, the "control within 10 s of
-- the first frame" rule, the van-door times, the first-join and once-per-level gates, the level intro's
-- stops and shot path; and ReplicatedFirst/Brand, the first frame's copy of Config / Palette / Strings.

local fs = require("@lune/fs")

local PresentPlan = require("../../src/client/Heist/PresentPlan")
local CameraMath = require("../../src/client/Heist/CameraMath")
local Brand = require("../../src/first/Brand")
local Config = require("../../src/shared/Config")
local Strings = require("../../src/shared/Heist/Strings")
local Protocol = require("../../src/shared/Heist/Protocol")
local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local Catalog = require("../../src/shared/Levels/Catalog")
local Help = require("../../src/shared/Heist/Help")
local Assert = require("./Assert")

local P = Config.Presentation
local T = P.TITLE
local D = P.DOORS
local I = P.INTRO
local H = Config.Heist

local function level(id: string): any
	for _, spec in Catalog do
		if spec.id == id then
			return LevelSpec.compile(spec)
		end
	end
	error("no level " .. id)
end

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- The hex a Palette token is built from (Palette needs Color3, so read its source).
local paletteSrc = fs.readFile("src/shared/Heist/Palette.luau")
local function paletteHex(name: string): string?
	return string.match(paletteSrc, "Palette%." .. name .. ' = hex%("(#%x+)"%)')
end

return function(test)
	---------------------------------------------------------------------------
	-- Brand: the first frame draws with copies; they must not drift
	---------------------------------------------------------------------------
	test("Brand mirrors Palette, Config.Ui, Config.Presentation.LOADING and Strings", function()
		Assert.eq(Brand.COLOR.ink, paletteHex("ink"), "ink")
		Assert.eq(Brand.COLOR.inkHi, paletteHex("inkHi"), "inkHi")
		Assert.eq(Brand.COLOR.white, paletteHex("white"), "white")
		Assert.eq(Brand.COLOR.steelHi, paletteHex("steelHi"), "steelHi")
		local hues = string.match(paletteSrc, "Palette%.CLONE_HUES = table%.freeze%(%{(.-)%}%)") or ""
		local k = 0
		for h in string.gmatch(hues, 'hex%("(#%x+)"%)') do
			k += 1
			if k <= #Brand.COLOR.hues then
				Assert.eq(Brand.COLOR.hues[k], h, "clone hue " .. k)
			end
		end
		Assert.truthy(k >= #Brand.COLOR.hues, "Palette has the three wordmark hues")
		Assert.eq(Brand.FACE, Config.Ui.DISPLAY_FACE, "display face")
		Assert.eq(Brand.WORDMARK_OFFSET[1], Config.Ui.WORDMARK_OFFSET[1], "offset x")
		Assert.eq(Brand.WORDMARK_OFFSET[2], Config.Ui.WORDMARK_OFFSET[2], "offset y")
		Assert.eq(Brand.DISPLAY_STROKE, Config.Ui.DISPLAY_STROKE, "display stroke")
		for key, v in P.LOADING do
			Assert.eq(Brand.LOADING[key], v, "LOADING." .. key)
		end
		for key, v in Brand.LOADING do
			Assert.eq(P.LOADING[key], v, "Brand.LOADING." .. key .. " is in Config")
		end
		Assert.eq(Brand.WORDMARK, Strings.WORDMARK, "wordmark")
		Assert.eq(Brand.STRAP, Strings.WORDMARK_STRAP, "strap")
		for _, stage in Brand.STAGES do
			Assert.eq(Brand.HINTS[stage], Strings.LOADING_HINTS[stage], "hint " .. stage)
		end
	end)

	test("the loading hint is never a bare 'Loading' and each line is short", function()
		for stage, line in Brand.HINTS do
			Assert.truthy(not string.find(string.lower(line), "loading", 1, true), stage .. ": no 'Loading'")
			local words = 0
			for _ in string.gmatch(line, "%S+") do
				words += 1
			end
			Assert.le(words, 4, stage .. " hint words")
		end
		Assert.eq(#Brand.STAGES, 3, "three real stages")
	end)

	test("the title sits above the loading card, the card above every game gui", function()
		Assert.truthy(T.ORDER > P.LOADING.ORDER, "title over the card it replaces")
		Assert.truthy(P.LOADING.ORDER > 100, "card over the Studio-only screens (100) and the HUD")
		Assert.truthy(D.ZINDEX < 40, "doors under the Line-up caption (40) and the stamps (54)")
	end)

	---------------------------------------------------------------------------
	-- Title beat
	---------------------------------------------------------------------------
	test("title beat: three splits in order, all inside the 3 s beat, one arpeggio note each", function()
		Assert.eq(T.SECONDS, 3, "a 3 s beat")
		Assert.eq(#T.SPLITS, 3, "three copies")
		Assert.eq(#T.NOTES, #T.SPLITS, "one note per copy")
		local splits, endAt = PresentPlan.titleSchedule(10, T)
		Assert.near(endAt, 13, 1e-9, "beat end")
		for k = 1, #splits do
			Assert.truthy(splits[k] >= 10, "split " .. k .. " after the start")
			if k > 1 then
				Assert.truthy(splits[k] > splits[k - 1], "split " .. k .. " after split " .. (k - 1))
			end
			Assert.le(splits[k] + T.SPLIT_SECONDS, endAt, "split " .. k .. " lands inside the beat")
			local note = T.NOTES[k]
			Assert.truthy(note >= 0 and note < #Config.Audio.ARPEGGIO_STEPS, "note " .. k .. " on the ladder")
			if k > 1 then
				Assert.truthy(T.NOTES[k] > T.NOTES[k - 1], "the arpeggio climbs")
			end
		end
		local x1, y1 = PresentPlan.copyRest(1, T.STEP)
		local x3, y3 = PresentPlan.copyRest(3, T.STEP)
		Assert.truthy(x3 > x1 and y3 > y1, "copies fan out down-right")
		Assert.eq(x1, T.STEP[1], "copy 1 one step out")
	end)

	test("revealAt: no deadline waits for the beat; a deadline cuts it so the doors are open by control", function()
		local start, cut = PresentPlan.revealAt(0, 3, nil, 0.15, 0.3)
		Assert.eq(start, 3, "waits for the beat")
		Assert.falsy(cut, "not cut")
		start, cut = PresentPlan.revealAt(0, 3, 10, 0.15, 0.3)
		Assert.eq(start, 3, "a late control leaves the beat whole")
		Assert.falsy(cut, "not cut")
		start, cut = PresentPlan.revealAt(1, 3, 2, 0.15, 0.3)
		Assert.near(start + 0.15 + 0.3, 2, 1e-9, "open exactly at control")
		Assert.truthy(cut, "the beat is cut short")
		start = PresentPlan.revealAt(5, nil, 4, 0, 0.3)
		Assert.eq(start, 5, "a passed deadline reveals now")
		start, cut = PresentPlan.revealAt(2, nil, 9, 0.3, 0.3)
		Assert.eq(start, 2, "no title: the card goes at once")
		Assert.falsy(cut, "no title: nothing to cut")
	end)

	---------------------------------------------------------------------------
	-- The 10-second rule (premium G1)
	---------------------------------------------------------------------------
	test("the client never delays control: the title and the doors overlap the server's wait", function()
		for _, ready in { 0.5, 1, 2, 3, 4, 6, 8 } do
			for _, titleStart in { -1, 0, 0.5, 1, 2, 3, 5 } do
				local ts: number? = if titleStart < 0 then nil else math.min(titleStart, ready)
				local control, open, _ = PresentPlan.bootControl({
					serverReady = ready,
					transition = H.FIRST_RUN_INTRO,
					titleStart = ts,
					titleSeconds = T.SECONDS,
					fade = T.FADE_SECONDS,
					open = D.OPEN_SECONDS,
				})
				Assert.near(control, ready + H.FIRST_RUN_INTRO, 1e-9, "control is the server's")
				Assert.le(
					open,
					control + 1e-9,
					string.format("doors open by control (ready %g, title %s)", ready, tostring(ts))
				)
			end
		end
		Assert.le(T.FADE_SECONDS + D.OPEN_SECONDS, H.FIRST_RUN_INTRO, "the reveal fits in run 1's intro")
	end)

	test("control within 10 s of the first frame, cold server included (waits side by side)", function()
		-- Assumptions (from the first frame, the card): a phone loads the place and starts the client
		-- in ~5 s; the instance builds in ~1 s; the server's waits run while the client loads.
		local CLIENT_READY, BUILD = 5, 1
		local cold = PresentPlan.serverWait(H.DATA_WAIT_SECONDS, H.FLAGS_WAIT_SECONDS, H.KIT_WAIT_SECONDS)
		Assert.eq(cold, math.max(H.DATA_WAIT_SECONDS, H.FLAGS_WAIT_SECONDS, H.KIT_WAIT_SECONDS), "longest wait")
		local ready = math.max(cold + BUILD, CLIENT_READY)
		local control = PresentPlan.bootControl({
			serverReady = ready,
			transition = H.FIRST_RUN_INTRO,
			titleStart = 1,
			titleSeconds = T.SECONDS,
			fade = T.FADE_SECONDS,
			open = D.OPEN_SECONDS,
		})
		local ok, s = PresentPlan.controlWithin(0, control, P.CONTROL_LIMIT_SECONDS)
		Assert.truthy(ok, string.format("cold first frame -> control %.1f s", s))
		-- The old sequential waits (data, then flags, then kit) would not have made it.
		local sequential = H.DATA_WAIT_SECONDS + H.FLAGS_WAIT_SECONDS + H.KIT_WAIT_SECONDS + BUILD
		Assert.truthy(sequential + H.FIRST_RUN_INTRO > P.CONTROL_LIMIT_SECONDS, "why the waits run side by side")
		Assert.eq(P.CONTROL_LIMIT_SECONDS, 10, "premium G1")
	end)

	test("van doors: close + open <= 0.6 s, reduced motion a 0.15 s crossfade (premium H4, C4)", function()
		Assert.le(D.CLOSE_SECONDS + D.OPEN_SECONDS, 0.6, "authored in/out <= 0.6 s")
		Assert.eq(D.OPEN_SECONDS, 0.3, "doors slide apart in 0.3 s")
		Assert.eq(D.CLOSE_SECONDS, 0.25, "and close in 0.25 s")
		Assert.eq(D.FADE_SECONDS, 0.15, "reduced motion crossfade")
		Assert.eq(D.FADE_SECONDS, Config.Ui.MOTION.fade[1], "the kit's fade token")
		Assert.truthy(
			D.HOLD_MAX_SECONDS < P.LOADING.HOLD_MAX_SECONDS,
			"a refused pick reopens long before the watchdog"
		)
	end)

	---------------------------------------------------------------------------
	-- Gates
	---------------------------------------------------------------------------
	test("first-join gate: the title plays for a new account only, never for someone joining a heist", function()
		Assert.truthy(PresentPlan.titleDue("pending", false, "heistFtue"), "the server autostarted L1")
		Assert.truthy(PresentPlan.titleDue("seeded", false, "preparing"), "a new profile while the server prepares")
		Assert.truthy(PresentPlan.titleDue("seeded", false, "garage"), "a new profile in a full server")
		Assert.truthy(PresentPlan.titleDue("none", false, "preparing"), "no data: the server treats it as new")
		Assert.falsy(PresentPlan.titleDue("pending", false, "preparing"), "unknown yet: wait")
		Assert.falsy(PresentPlan.titleDue("none", false, "garage"), "no data, garage: a returning player")
		Assert.falsy(PresentPlan.titleDue("seeded", false, "heist"), "joining a heist in progress")
		for _, status in { "pending", "seeded", "none" } do
			for _, boot in { "preparing", "garage", "heistFtue", "heist" } do
				Assert.falsy(
					PresentPlan.titleDue(status, true, boot),
					"seen: never again (" .. status .. ", " .. boot .. ")"
				)
			end
		end
	end)

	test("seenKinds: the title after the first move in L1, each level's intro after its first play", function()
		local steps = Protocol.FTUE_STEPS
		local function snap(step: number, levels: any): any
			return { heist = { ftueStep = step, levels = levels } }
		end
		Assert.falsy(PresentPlan.seenKinds(snap(0, {}), steps, "FirstMove").title, "brand new")
		Assert.falsy(
			PresentPlan.seenKinds(snap(table.find(steps, "Joined") :: number, {}), steps, "FirstMove").title,
			"'Joined' is saved at join: not enough"
		)
		Assert.truthy(
			PresentPlan.seenKinds(snap(table.find(steps, "FirstMove") :: number, {}), steps, "FirstMove").title,
			"moved in L1: seen"
		)
		local seen = PresentPlan.seenKinds(
			snap(7, { TwoDoors = { plays = 1 }, CloneParty = { plays = 0 }, LightsOut = "bad" }),
			steps,
			"FirstMove"
		)
		Assert.truthy(seen["intro:TwoDoors"], "played Two Doors")
		Assert.falsy(seen["intro:CloneParty"], "never played the party")
		Assert.falsy(seen["intro:LightsOut"], "a malformed record is ignored")
		Assert.truthy(
			PresentPlan.seenKinds(snap(0, { BackRoom = { plays = 2 } }), steps, "FirstMove").title,
			"a profile from before the FTUE steps that has played: no title"
		)
		Assert.eq(next(PresentPlan.seenKinds(nil, steps, "FirstMove")), nil, "no snapshot: nothing seen")
	end)

	test("once per level per account: never on L1 or a daily vault; data key from the info or Config", function()
		local keys = H.LEVEL_DATA_KEYS
		Assert.eq(
			PresentPlan.introKind({ id = H.FTUE_L1_LEVEL, dataKey = "BackRoom" }, H.FTUE_L1_LEVEL, keys),
			nil,
			"L1"
		)
		Assert.eq(PresentPlan.introKind({ id = "dv03_candy_cane_lasers" }, H.FTUE_L1_LEVEL, keys), nil, "daily")
		Assert.eq(
			PresentPlan.introKind({ id = "cs2_two_doors" }, H.FTUE_L1_LEVEL, keys),
			"intro:TwoDoors",
			"Config key"
		)
		Assert.eq(
			PresentPlan.introKind({ id = "cs5_clone_party", dataKey = "CloneParty" }, H.FTUE_L1_LEVEL, keys),
			"intro:CloneParty",
			"info key"
		)
		Assert.eq(PresentPlan.introKind(nil, H.FTUE_L1_LEVEL, keys), nil, "no info")
		-- The gate closes once played: the kind a play records is the kind the intro asks for.
		local kind = PresentPlan.introKind({ id = "cs3_lights_out" }, H.FTUE_L1_LEVEL, keys) :: string
		local seen = PresentPlan.seenKinds(
			{ heist = { ftueStep = 9, levels = { LightsOut = { plays = 1 } } } },
			Protocol.FTUE_STEPS,
			"FirstMove"
		)
		Assert.truthy(seen[kind], "a played level's intro is seen")
	end)

	---------------------------------------------------------------------------
	-- Level intro (C2)
	---------------------------------------------------------------------------
	test("L2 first look: plate A -> door A -> plate B -> door B -> the safe", function()
		local l2 = level("cs2_two_doors")
		local stops = PresentPlan.introStops(l2, false, I.FOCUS_LIFT, I.MAX_STOPS)
		Assert.eq(#stops, 5, "five stops")
		Assert.near(stops[1][1], -10, 0.6, "plate A first")
		Assert.near(stops[2][3], -20, 1, "then the back-room door")
		Assert.near(stops[3][1], 10, 0.6, "then plate B")
		Assert.near(stops[4][3], -32, 1, "then the stockroom door")
		Assert.near(stops[5][3], -40, 1e-6, "the safe last")
	end)

	test("Party opening: the shot is Gus at his post (he dozes there)", function()
		local l5 = level("cs5_clone_party")
		local stops = PresentPlan.introStops(l5, true, I.FOCUS_LIFT, I.MAX_STOPS)
		Assert.eq(#stops, 1, "one stop")
		local leg = l5.guards[1].route.legs[1]
		Assert.near(stops[1][1], leg.x0, 1e-6, "Gus x")
		Assert.near(stops[1][3], leg.z0, 1e-6, "Gus z")
		local plan = PresentPlan.introPlan(stops, H.FIRST_RUN_INTRO, I) :: any
		Assert.truthy(plan ~= nil, "fits in run 1's intro")
		Assert.near(plan.glide + plan.rest, H.FIRST_RUN_INTRO, 1e-9, "inside the transition")
		Assert.truthy(plan.rest >= I.EASE_BACK - 1e-9, "time to ease back to you")
	end)

	test("every launch level has a first look inside its bounds", function()
		for _, spec in Catalog do
			local l = LevelSpec.compile(spec)
			local stops = PresentPlan.introStops(l, spec.kind == "party", I.FOCUS_LIFT, I.MAX_STOPS)
			Assert.truthy(#stops >= 1 and #stops <= I.MAX_STOPS, spec.id .. ": 1.." .. I.MAX_STOPS .. " stops")
			local b = l.bounds
			for k, s in stops do
				Assert.truthy(
					s[1] >= b.minX - 1e-6 and s[1] <= b.maxX + 1e-6 and s[3] >= b.minZ - 1e-6 and s[3] <= b.maxZ + 1e-6,
					spec.id .. " stop " .. k .. " inside the level"
				)
			end
		end
	end)

	test("introPlan fits the transition: drops stops rather than whip-pan, never runs past control", function()
		local stops = PresentPlan.introStops(level("cs2_two_doors"), false, I.FOCUS_LIFT, I.MAX_STOPS)
		for _, budget in { H.FIRST_RUN_INTRO, 1.5, 2, 3, 6 } do
			local plan = PresentPlan.introPlan(stops, budget, I) :: any
			Assert.truthy(plan ~= nil, "a plan at " .. budget .. " s")
			Assert.near(plan.glide + plan.rest, budget, 1e-9, "uses the budget exactly")
			Assert.truthy(plan.rest >= I.EASE_BACK - 1e-9, "leaves the ease back")
			Assert.truthy(#plan.stops >= 2, "at least first -> last")
			Assert.eq(plan.stops[1], stops[1], "starts on the first plate")
			Assert.eq(plan.stops[#plan.stops], stops[#stops], "ends on the loot")
			if #plan.stops > 1 then
				Assert.truthy(plan.hop >= I.HOP_MIN - 1e-9, "no hop faster than HOP_MIN")
				Assert.le(plan.hop, I.HOP + 1e-9, "no hop slower than HOP")
			end
		end
		local short = PresentPlan.introPlan(stops, H.FIRST_RUN_INTRO, I) :: any
		local long = PresentPlan.introPlan(stops, 3, I) :: any
		Assert.truthy(#long.stops > #short.stops, "more time, more stops")
		Assert.eq(#(PresentPlan.introPlan(stops, 6, I) :: any).stops, 5, "all five with room")
		Assert.eq(PresentPlan.introPlan(stops, I.EASE_BACK, I), nil, "no room: no intro")
		Assert.eq(PresentPlan.introPlan({}, 3, I), nil, "no stops: no intro")
	end)

	test("introFocus: holds, then eases stop to stop with no jump, ending on the last stop", function()
		local stops = PresentPlan.introStops(level("cs2_two_doors"), false, I.FOCUS_LIFT, I.MAX_STOPS)
		local plan = PresentPlan.introPlan(stops, 3, I) :: any
		Assert.eq(PresentPlan.introFocus(plan, 0), plan.stops[1], "starts on the first stop")
		Assert.eq(PresentPlan.introFocus(plan, plan.hold), plan.stops[1], "holds there")
		Assert.truthy(
			dist(PresentPlan.introFocus(plan, plan.glide), plan.stops[#plan.stops]) < 1e-6,
			"ends on the last"
		)
		local prev = PresentPlan.introFocus(plan, 0)
		local dt = 1 / 60
		local t = dt
		while t <= plan.glide do
			local f = PresentPlan.introFocus(plan, t)
			Assert.truthy(dist(f, prev) < 3, string.format("no jump at %.2f s", t))
			prev = f
			t += dt
		end
		Assert.near(PresentPlan.ease(0), 0, 1e-9, "ease 0")
		Assert.near(PresentPlan.ease(0.5), 0.5, 1e-9, "ease mid")
		Assert.near(PresentPlan.ease(1), 1, 1e-9, "ease 1")
	end)

	test("hand-off: the intro's last frame is the run-start beat's first frame (no cut, H1)", function()
		local D2 = H.CAMERA.DIORAMA
		local last = { 0, 3, -40 }
		local yaw = 180
		-- LevelIntro: orbit(focus); CameraDirector's beat at u = 0: orbit(ahead(objective, yaw, lead * 0)).
		local aPos, aLook = CameraMath.orbit(last, yaw, D2.PITCH, D2.DISTANCE)
		local lead = CameraMath.lead(D2.FOV, D2.PITCH, D2.DISTANCE, D2.SUBJECT_SCREEN_Y)
		local bPos, bLook = CameraMath.orbit(CameraMath.ahead(last, yaw, lead * 0), yaw, D2.PITCH, D2.DISTANCE)
		Assert.truthy(dist(aPos, bPos) < 1e-9 and dist(aLook, bLook) < 1e-9, "same camera")
	end)

	test("pickStops keeps the first and the last and spreads the rest", function()
		local s = { { 1, 0, 0 }, { 2, 0, 0 }, { 3, 0, 0 }, { 4, 0, 0 }, { 5, 0, 0 } }
		local two = PresentPlan.pickStops(s, 2)
		Assert.eq(two[1][1], 1, "first")
		Assert.eq(two[2][1], 5, "last")
		local three = PresentPlan.pickStops(s, 3)
		Assert.eq(three[2][1], 3, "middle")
		Assert.eq(#PresentPlan.pickStops(s, 9), 5, "never more than there are")
		Assert.eq(#PresentPlan.pickStops(s, 1), 1, "one")
	end)
	test("first visit: run 1's intro grows so L2 shows every plate -> door pair; never L1 or a daily", function()
		local l2 = level("cs2_two_doors")
		local key = H.LEVEL_DATA_KEYS[l2.id]
		Assert.truthy(Help.firstVisit(key, {}), "a new profile: first visit")
		Assert.truthy(Help.firstVisit(key, { [key] = { plays = 0 } }), "a record without a play: first visit")
		Assert.falsy(Help.firstVisit(key, { [key] = { plays = 1 } }), "played once: not any more")
		Assert.falsy(Help.firstVisit(nil, {}), "a daily vault has no level key")
		Assert.falsy(Help.firstVisit(key, nil), "no profile: no extra wait")
		-- the server's gate and the client's ("intro:<key>" seen) read the same level records
		local seen = PresentPlan.seenKinds({ heist = { levels = { [key] = { plays = 1 } } } }, {}, "x")
		Assert.truthy(seen[PresentPlan.INTRO_PREFIX .. key], "the client's seen set agrees")

		local long = Help.firstRunIntro(l2, false, 1)
		Assert.near(long, H.FIRST_RUN_INTRO + H.FIRST_VISIT_INTRO_EXTRA, 1e-9, "first visit: longer")
		Assert.le(H.FIRST_VISIT_INTRO_EXTRA, 2 + 1e-9, "by at most about 2 s")
		Assert.eq(Help.firstRunIntro(l2, false, 0), H.FIRST_RUN_INTRO, "repeat visit: unchanged")
		Assert.eq(Help.firstRunIntro(l2, true, 1), H.FIRST_RUN_INTRO, "daily vault: unchanged")
		Assert.eq(Help.firstRunIntro(level(H.FTUE_L1_LEVEL), false, 1), H.FIRST_RUN_INTRO, "L1: unchanged")

		local stops = PresentPlan.introStops(l2, false, I.FOCUS_LIFT, I.MAX_STOPS)
		local short = PresentPlan.introPlan(stops, H.FIRST_RUN_INTRO, I) :: any
		local plan = PresentPlan.introPlan(stops, long, I) :: any
		Assert.truthy(#short.stops < #stops, "today's 1 s drops stops")
		Assert.eq(#plan.stops, #stops, "with the first-visit intro: all " .. #stops .. " stops")
		Assert.truthy(plan.hop >= I.HOP - 0.05, string.format("at (nearly) full hops (%.2f s)", plan.hop))
		-- every story / party level's first look fits its first-visit intro without dropping a stop
		for _, spec in Catalog do
			local l = LevelSpec.compile(spec)
			if l.id ~= H.FTUE_L1_LEVEL then
				local st = PresentPlan.introStops(l, spec.kind == "party", I.FOCUS_LIFT, I.MAX_STOPS)
				local p = PresentPlan.introPlan(st, Help.firstRunIntro(l, false, 1), I) :: any
				Assert.truthy(p ~= nil and #p.stops == #st, spec.id .. ": every stop fits")
			end
		end
	end)
end
