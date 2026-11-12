-- L1: Analytics/Tracker (the pure analytics core): gate, onboarding, retention, heist/clip/store
-- funnels, batching, budgets, kill switches, economy, session KPIs, perf.

local Config = require("../../src/shared/Config")
local JoinSource = require("../../src/shared/Analytics/JoinSource")
local PerfSample = require("../../src/shared/Analytics/PerfSample")
local Tracker = require("../../src/shared/Analytics/Tracker")
local Assert = require("./Assert")

local A = Config.Analytics
local DAY = 20790 -- some UTC day number

type Env = { t: Tracker.Tracker, now: number, flags: { [string]: any } }

local function env(flags: { [string]: any }?): Env
	local e: any = { now = 1000, flags = flags or {} }
	e.t = Tracker.new({
		clock = function()
			return e.now
		end,
		flag = function(name: string): any
			local v = e.flags[name]
			if v ~= nil then
				return v
			end
			return Config.LiveFlags.Flags[name].default
		end,
	})
	return e
end

local function join(e: Env, pid: number, facts: Tracker.Facts?, launch: string?)
	Tracker.playerJoined(e.t, pid, 1796000000)
	Tracker.setJoin(e.t, pid, JoinSource.classify({ launchData = launch } :: any), "base")
	if facts then
		Tracker.setFacts(e.t, pid, facts)
	end
end

local function newFacts(): Tracker.Facts
	return { isNew = true, ftueStep = 0, firstSeenDay = DAY, today = DAY }
end

local function calls(e: Env): { Tracker.Call }
	return Tracker.drainAll(e.t)
end

local function find(list: { Tracker.Call }, kind: string, name: string?, stepName: string?): { Tracker.Call }
	local out = {}
	for _, c in list do
		if c.kind == kind and (name == nil or c.name == name) and (stepName == nil or c.stepName == stepName) then
			table.insert(out, c)
		end
	end
	return out
end

local function onbSteps(list: { Tracker.Call }): string
	local out = {}
	for _, c in find(list, "onboarding") do
		table.insert(out, tostring(c.step))
	end
	return table.concat(out, ",")
end

return function(test)
	test("gate: nothing leaves until join source and facts are known; Joined carries the source", function()
		local e = env()
		Tracker.playerJoined(e.t, 1, 1796000000)
		Tracker.onboarding(e.t, 1, "FirstPlate")
		Tracker.cloneFailed(e.t, 1, "zapped", "BackRoom")
		Assert.eq(#calls(e), 0, "held before the join source")
		Tracker.setJoin(e.t, 1, JoinSource.classify({ launchData = "v1|src|tt" } :: any), "a")
		Assert.eq(#calls(e), 0, "still waiting for the profile")
		Tracker.setFacts(e.t, 1, newFacts())
		local out = calls(e)
		local joined = find(out, "onboarding", "onb_v2", "Joined")[1]
		Assert.truthy(joined, "Joined sent")
		Assert.eq(joined.step, 1, "step 1")
		local f = joined.fields :: { string }
		Assert.eq(f[1], "share", "source field")
		Assert.eq(f[2], "tt", "tag field")
		Assert.eq(f[3], "a", "variant field")
		Assert.eq(onbSteps(out), "1,3", "Joined then the held FirstPlate")
		Assert.eq(find(out, "onboarding", nil, "FirstPlate")[1].fields, nil, "fields only on step 1")
		local js = find(out, "custom", "JoinSource")[1]
		Assert.eq((js.fields :: any)[3], "new", "JoinSource cohort")
		Assert.eq(#find(out, "custom", "ServerBuild"), 1, "ServerBuild once")
		Assert.eq((find(out, "custom", "ServerBuild")[1].fields :: any)[1], "b" .. A.BUILD, "fallback build")
		Assert.eq(Tracker.buildName(207), "pv07", "PlaceVersion bucket")
		Assert.eq(Tracker.buildName(0), "b" .. A.BUILD, "Studio: PlaceVersion 0")
		Assert.eq(Tracker.cohort(e.t, 1), "new", "cohort")
	end)

	test("facts timeout: logs with cohort unknown after FACTS_WAIT_SECONDS", function()
		local e = env()
		join(e, 2, nil)
		Tracker.tick(e.t)
		Assert.eq(#calls(e), 0, "waiting")
		e.now += A.FACTS_WAIT_SECONDS
		Tracker.tick(e.t)
		local out = calls(e)
		Assert.eq(#find(out, "onboarding", nil, "Joined"), 1, "Joined after the timeout")
		Assert.eq((find(out, "custom", "JoinSource")[1].fields :: any)[3], "unknown", "cohort unknown")
		Tracker.setFacts(e.t, 2, { isNew = false, ftueStep = 5 })
		Assert.eq(Tracker.cohort(e.t, 2), "returning", "late facts still set the cohort")
		-- a join whose GetJoinData poll never reported still resolves, as organic
		Tracker.playerJoined(e.t, 22, 0)
		e.now += A.JOIN_DATA_POLLS * A.JOIN_DATA_POLL_SECONDS + A.FACTS_WAIT_SECONDS
		Tracker.tick(e.t)
		local late = calls(e)
		local joined = find(late, "onboarding", nil, "Joined")
		Assert.eq(#joined, 1, "hard deadline")
		Assert.eq((joined[1].fields :: any)[1], "organic", "organic")
	end)

	test("new player FTUE: timings, Minute10 held for SwarmSeen, FtueMinute10 KPI", function()
		local e = env()
		join(e, 3, newFacts())
		calls(e)
		e.now += 8
		Tracker.onboarding(e.t, 3, "FirstPlate")
		e.now += 4
		Tracker.onboarding(e.t, 3, "FirstRewind")
		e.now += 2
		Tracker.onboarding(e.t, 3, "FirstCloneSeen") -- 14 s after join
		e.now += 28
		Tracker.onboarding(e.t, 3, "FirstBank") -- 42 s
		local out = calls(e)
		Assert.eq(onbSteps(out), "3,4,5,6", "steps in order")
		local timing = {}
		for _, c in find(out, "custom", "FtueTiming") do
			timing[(c.fields :: any)[1]] = c
		end
		Assert.eq((timing.FirstCloneSeen.fields :: any)[2], "<15s", "first clone within 15 s")
		Assert.eq(timing.FirstCloneSeen.value, 14, "seconds")
		Assert.eq((timing.FirstBank.fields :: any)[2], "30-45s", "first bank within 45 s")
		Assert.eq((timing.FirstBank.fields :: any)[3], "organic", "source field")
		e.now = 1000 + A.MINUTE10_SECONDS
		Tracker.tick(e.t)
		out = calls(e)
		Assert.eq(onbSteps(out), "", "Minute10 is held: no SwarmSeen")
		local m10 = find(out, "custom", "FtueMinute10")[1]
		Assert.eq((m10.fields :: any)[1], "no", "no swarm by minute 10")
		Assert.eq((m10.fields :: any)[2], "no", "no L1 complete")
		Tracker.tick(e.t)
		Assert.eq(#calls(e), 0, "Minute10 only once")
		Tracker.onboarding(e.t, 3, "SwarmSeen")
		out = calls(e)
		Assert.eq(onbSteps(out), "11,12", "SwarmSeen releases Minute10")
		Assert.eq(#find(out, "custom", "FtueTiming"), 1, "SwarmSeen timing")
	end)

	test("returning players: seeded from ftueStep, no FTUE timings, no FtueMinute10", function()
		local e = env()
		join(e, 4, { isNew = false, ftueStep = 7, firstSeenDay = DAY - 3, today = DAY })
		local out = calls(e)
		Assert.eq(onbSteps(out), "", "Joined was sent in an earlier session")
		Tracker.onboarding(e.t, 4, "FirstBank")
		Tracker.onboarding(e.t, 4, "ReelShown")
		out = calls(e)
		Assert.eq(onbSteps(out), "8", "resumes after the saved step")
		Assert.eq(#find(out, "custom", "FtueTiming"), 0, "timings only for new players")
		e.now += A.MINUTE10_SECONDS
		Tracker.tick(e.t)
		Assert.eq(#find(calls(e), "custom", "FtueMinute10"), 0, "KPI only for first sessions")
	end)

	test("retention funnels: FirstDay on day 0, ReturnedD1 on day 1, ReturnedD7 on day 7", function()
		local e = env()
		join(e, 5, newFacts(), "v1|src|ad_plays")
		local out = calls(e)
		local d1 = find(out, "funnel", "ret_d1")
		Assert.eq(#d1, 1, "ret_d1 step 1")
		Assert.eq(d1[1].session, "r5", "stable session id")
		Assert.eq((d1[1].fields :: any)[1], "ad", "source on step 1")
		Assert.eq(#find(out, "funnel", "ret_d7"), 1, "ret_d7 step 1")
		local e1 = env()
		join(e1, 5, { isNew = false, ftueStep = 12, firstSeenDay = DAY - 1, today = DAY })
		out = calls(e1)
		local r = find(out, "funnel", "ret_d1")[1]
		Assert.eq(r.stepName, "ReturnedD1", "day 1")
		Assert.eq(r.fields, nil, "no fields after step 1")
		Assert.eq(#find(out, "funnel", "ret_d7"), 0, "not day 7")
		local e7 = env()
		join(e7, 5, { isNew = false, ftueStep = 12, firstSeenDay = DAY - 7, today = DAY })
		Assert.eq(find(calls(e7), "funnel", "ret_d7")[1].stepName, "ReturnedD7", "day 7")
		local e3 = env()
		join(e3, 5, { isNew = false, ftueStep = 12, firstSeenDay = DAY - 3, today = DAY })
		Assert.eq(#find(calls(e3), "funnel"), 0, "day 3 logs nothing")
	end)

	test("heist funnel, progression, clip funnel, ReelShown and NextHeist", function()
		local e = env()
		join(e, 6, newFacts())
		calls(e)
		local sid = Tracker.heistStarted(e.t, 6, { heistId = "H-A", level = "cs1_back_room", crew = 2, friends = 1 })
		Assert.eq(sid, "H-A", "session id = heist id")
		Tracker.heistStep(e.t, 6, "H-A", "FirstRewind")
		Tracker.heistStep(e.t, 6, "H-A", "FirstBank")
		Tracker.heistStep(e.t, 6, "H-A", "FirstBank")
		Tracker.heistStep(e.t, 6, "H-A", "HeistComplete")
		Tracker.heistEnded(e.t, 6, "H-A", "complete", 3)
		Tracker.heistStep(e.t, 6, "H-A", "ResultsShown")
		local out = calls(e)
		local steps = {}
		for _, c in find(out, "funnel", "heist_v1") do
			table.insert(steps, c.stepName)
		end
		Assert.eq(table.concat(steps, ","), "HeistStarted,FirstRewind,FirstBank,HeistComplete,ResultsShown", "steps")
		local start = find(out, "funnel", "heist_v1", "HeistStarted")[1]
		Assert.eq((start.fields :: any)[1], "BackRoom", "LevelSpec id mapped to the data key")
		Assert.eq((start.fields :: any)[2], "duo", "crew")
		local prog = find(out, "progression", "Heist")
		Assert.eq(#prog, 2, "start + complete")
		Assert.eq(prog[1].status, "Start", "start")
		Assert.eq(prog[1].step, 1, "level index")
		Assert.eq(prog[2].status, "Complete", "complete")
		Assert.eq(#find(out, "funnel", "clip_v1", "ResultsShown"), 1, "clip funnel opens")
		Assert.eq(onbSteps(out), "8", "L1 results card = onboarding ReelShown")
		local ended = find(out, "custom", "HeistEnded")[1]
		Assert.eq((ended.fields :: any)[2], "complete", "outcome")
		Assert.eq((ended.fields :: any)[3], "3", "runs bucket")
		Tracker.clip(e.t, 6, "tap", "video")
		Tracker.clip(e.t, 6, "captured", "video")
		Tracker.clip(e.t, 6, "shared", "video")
		out = calls(e)
		Assert.eq(#find(out, "funnel", "clip_v1"), 3, "ClipTapped, ClipCaptured, ClipKept")
		Assert.eq((find(out, "custom", "ClipSaveTapped")[1].fields :: any)[2], "BackRoom", "tap level")
		Assert.eq((find(out, "custom", "ClipShareResult")[1].fields :: any)[1], "shared", "share result")
		Tracker.heistStarted(e.t, 6, { heistId = "H-B", level = "TwoDoors", crew = 1 })
		out = calls(e)
		local nextH = find(out, "funnel", "heist_v1", "NextHeist")[1]
		Assert.eq(nextH.session, "H-A", "NextHeist on the previous heist")
		Tracker.heistEnded(e.t, 6, "H-B", "dawn", 9)
		out = calls(e)
		local fail = find(out, "progression", "Heist")[1]
		Assert.eq(fail.status, "Fail", "Dawn is a progression fail")
		Assert.eq(fail.step, 2, "level 2")
		Tracker.heistStep(e.t, 6, "nope", "FirstBank")
		Tracker.heistStep(e.t, 6, "H-B", "NoSuchStep")
		Assert.eq(Tracker.stats(e.t).invalid, 2, "unknown heist and step counted")
	end)

	test("daily vault heists use the Daily progression path", function()
		local e = env()
		join(e, 7, newFacts())
		calls(e)
		Tracker.heistStarted(e.t, 7, { heistId = "D-1", level = "Daily", daily = 3 })
		local p = find(calls(e), "progression", "Daily")[1]
		Assert.eq(p.step, 3, "vault design number")
		Assert.eq(p.stepName, "v03", "vault name")
	end)

	test("batched events sum per field combination and flush every minute and on leave", function()
		local e = env()
		join(e, 8, newFacts())
		calls(e)
		for _ = 1, 5 do
			Tracker.cloneFailed(e.t, 8, "busted", "LightsOut")
		end
		Tracker.cloneFailed(e.t, 8, "zapped", "LightsOut")
		Tracker.deck(e.t, 8, "redo", "LightsOut")
		Tracker.deck(e.t, 8, "undo", "LightsOut")
		Tracker.deck(e.t, 8, "deleteBusted", "LightsOut")
		Tracker.deck(e.t, 8, "explode", "LightsOut")
		Assert.eq(#calls(e), 0, "nothing before the flush")
		e.now += A.BATCH_FLUSH_SECONDS
		Tracker.tick(e.t)
		local out = calls(e)
		local failed = find(out, "custom", "CloneFailed")
		Assert.eq(#failed, 2, "one call per cause")
		local byCause = {}
		for _, c in failed do
			byCause[(c.fields :: any)[1]] = c.value
		end
		Assert.eq(byCause.busted, 5, "summed")
		Assert.eq(byCause.zapped, 1, "own combination")
		Assert.eq(#find(out, "custom", "RedoUsed"), 1, "redo")
		Assert.eq(#find(out, "custom", "UndoUsed"), 1, "undo")
		Assert.eq(#find(out, "custom", "DeleteUsed"), 1, "delete busted")
		Assert.eq(Tracker.stats(e.t).invalid, 1, "unknown deck op")
		Tracker.taintedRun(e.t, 8, 1 + 2, "LightsOut")
		Tracker.taintedRun(e.t, 8, 0, "LightsOut")
		Tracker.playerLeft(e.t, 8)
		out = calls(e)
		local taint = find(out, "custom", "TaintedRun")
		Assert.eq(#taint, 1, "flushed on leave; clean runs are not logged")
		Assert.eq((taint[1].fields :: any)[1], "multi", "two flags = multi")
		Assert.eq(Tracker.taintName(4), "rise", "single flag")
	end)

	test("per-player budget drops a flood of unbatched events; server budget orders funnels first", function()
		local e = env()
		join(e, 9, newFacts())
		calls(e)
		for _ = 1, A.PLAYER_BURST + 10 do
			Tracker.medal(e.t, 9, "Haul", "BackRoom")
		end
		Assert.eq(#find(calls(e), "custom", "MedalEarned"), A.PLAYER_BURST, "burst passes")
		Assert.eq(Tracker.stats(e.t).dropBudget, 10, "the rest dropped")
		local e2 = env()
		join(e2, 10, newFacts())
		local first = Tracker.drain(e2.t)
		Assert.truthy(#first >= 3, "join calls drained")
		for pid = 100, 100 + A.SERVER_BURST do
			join(e2, pid, newFacts())
		end
		local burst = Tracker.drain(e2.t)
		Assert.le(#burst, A.SERVER_BURST, "server burst")
		Assert.eq(burst[1].kind, "onboarding", "funnels drain before customs")
		Assert.truthy(Tracker.backlog(e2.t) > 0, "the rest waits")
		e2.now += 60
		local later = Tracker.drain(e2.t)
		Assert.truthy(#later > 0, "refilled")
	end)

	test("backlog overflow drops custom events before funnel steps", function()
		local e = env()
		for pid = 1, A.BACKLOG_MAX do
			join(e, pid, { isNew = true, ftueStep = 0 }) -- no retention days: one funnel call each
		end
		Assert.le(Tracker.backlog(e.t), A.BACKLOG_MAX, "bounded")
		Assert.truthy(Tracker.stats(e.t).dropBacklog > 0, "dropped")
		local out = calls(e)
		Assert.eq(#find(out, "onboarding"), A.BACKLOG_MAX, "every Joined kept")
	end)

	test("kill switches: analytics off sends nothing; analyticsCustom off keeps funnels", function()
		local e = env({ analytics = false })
		join(e, 11, newFacts())
		Assert.eq(#calls(e), 0, "analytics off")
		Assert.truthy(Tracker.stats(e.t).dropKilled > 0, "counted")
		local c = env({ analyticsCustom = false })
		join(c, 12, newFacts())
		local out = calls(c)
		Assert.eq(#find(out, "custom"), 0, "no custom events")
		Assert.eq(#find(out, "onboarding"), 1, "funnel kept")
		local broken = Tracker.new({
			clock = function()
				return 0
			end,
			flag = function(_name: string): any
				error("flags exploded")
			end,
		})
		Tracker.playerJoined(broken, 13, 0)
		Tracker.setJoin(broken, 13, { source = "organic", tag = "none" })
		Tracker.setFacts(broken, 13, newFacts())
		Assert.truthy(#Tracker.drainAll(broken) > 0, "a failing flag reader falls back to defaults")
		-- a switch thrown while calls are queued stops them too (AnalyticsService misbehaving)
		local q = env()
		join(q, 25, newFacts())
		Assert.truthy(Tracker.backlog(q.t) > 0, "calls queued")
		q.flags.analyticsCustom = false
		local kept = Tracker.drain(q.t)
		Assert.eq(#find(kept, "custom"), 0, "queued custom events dropped")
		Assert.truthy(#find(kept, "onboarding") > 0, "funnel calls still drain")
		join(q, 26, newFacts())
		q.flags.analytics = false
		Assert.eq(#Tracker.drain(q.t), 0, "drain sends nothing")
		Assert.eq(#Tracker.drainAll(q.t), 0, "nor does the shutdown drain")
		Assert.eq(Tracker.backlog(q.t), 0, "the backlog is cleared")
	end)

	test("economy: sources, sinks, Stars mirror, ignored reasons, fields", function()
		local e = env()
		join(e, 14, newFacts())
		calls(e)
		Tracker.economy(e.t, 14, "Cash", 300, 300, "heist:BackRoom", 3)
		Tracker.economy(e.t, 14, "Cash", -2500, 1000, "buy:Paint_MidnightBlue", 7)
		Tracker.economy(e.t, 14, "Stars", -1, 2, "medals", 2)
		Tracker.economy(e.t, 14, "Cash", 0, 1000, "load", 2)
		Tracker.economy(e.t, 14, "Cash", 500, 1500, "load", 2)
		Tracker.economy(e.t, 14, "Robux", 5, 5, "heist:BackRoom", 2)
		local out = find(calls(e), "economy")
		Assert.eq(#out, 2, "two flows")
		Assert.eq(out[1].flow, "Source", "source")
		Assert.eq(out[1].amount, 300, "amount")
		Assert.eq(out[1].transactionType, "Gameplay", "tx")
		Assert.eq(out[1].sku, "Heist_BackRoom", "sku")
		Assert.eq((out[1].fields :: any)[1], "s1-5", "progress band")
		Assert.eq(out[2].flow, "Sink", "sink")
		Assert.eq(out[2].amount, 2500, "positive amount")
		Assert.eq(out[2].balance, 1000, "ending balance")
		Assert.eq((out[2].fields :: any)[1], "s6-13", "progress band")
		Assert.eq(Tracker.stats(e.t).invalid, 1, "unknown currency")
	end)

	test("session end: length bucket, minutes, friend sessions; invite arrivals", function()
		local e = env()
		join(e, 15, newFacts())
		e.now += 45
		Tracker.playerLeft(e.t, 15)
		local out = calls(e)
		local s = find(out, "custom", "SessionEnd")[1]
		Assert.eq((s.fields :: any)[1], "30-60s", "a bounce")
		Assert.eq(s.value, 0.8, "minutes (one decimal)")
		Assert.eq((find(out, "custom", "SessionSocial")[1].fields :: any)[1], "no", "solo session")
		local f = env()
		Tracker.playerJoined(f.t, 16, 0)
		Tracker.setJoin(f.t, 16, JoinSource.classify({ referredBy = 77 } :: any))
		Tracker.setFacts(f.t, 16, newFacts())
		Tracker.heistStarted(f.t, 16, { level = "BackRoom", crew = 3, friends = 2 })
		f.now += 20 * 60
		Tracker.playerLeft(f.t, 16)
		out = calls(f)
		Assert.eq((find(out, "custom", "InviteJoined")[1].fields :: any)[1], "referral", "invite arrival")
		local social = find(out, "custom", "SessionSocial")[1].fields :: any
		Assert.eq(social[1], "yes", "played with a friend")
		Assert.eq(social[2], "trio", "biggest crew")
		Assert.eq((find(out, "custom", "SessionEnd")[1].fields :: any)[1], "18-30m", "20 minutes")
		Assert.eq(Tracker.cohort(f.t, 16), "unknown", "player forgotten after leaving")
		local g = env()
		Tracker.playerJoined(g.t, 17, 0)
		e.now += 3
		Tracker.playerLeft(g.t, 17)
		out = calls(g)
		Assert.eq(#find(out, "onboarding", nil, "Joined"), 1, "an instant bounce still counts as Joined")
		Assert.eq((find(out, "custom", "JoinSource")[1].fields :: any)[1], "organic", "with what is known")
	end)

	test("client reports: JoinToControl once, perf sampling, interval, step-down device", function()
		local e = env()
		join(e, 18, newFacts())
		calls(e)
		e.now += 12
		Tracker.clientReady(e.t, 18, "phone")
		Tracker.clientReady(e.t, 18, "phone")
		local out = calls(e)
		local ready = find(out, "custom", "JoinToControl")
		Assert.eq(#ready, 1, "once per session")
		Assert.eq((ready[1].fields :: any)[1], "10-15s", "load bucket")
		Assert.eq((ready[1].fields :: any)[2], "phone", "device")
		local sample: PerfSample.Sample = {
			medianMs = 16.6,
			p95Ms = 30,
			worstMs = 60,
			frames = 3000,
			seconds = 60,
			device = "phone",
			quality = 0,
			memMb = 700,
			clones = 8,
			perfTier = "balanced",
		}
		Tracker.perf(e.t, 18, sample)
		e.now += 10
		Tracker.perf(e.t, 18, sample)
		out = calls(e)
		Assert.eq(#find(out, "custom", "PerfSample"), 1, "second sample too soon")
		Assert.eq((find(out, "custom", "PerfSample")[1].fields :: any)[2], "28-36", "p95 bucket (30 fps class)")
		Assert.eq(#find(out, "custom", "PerfDetail"), 1, "detail")
		Tracker.perfStepDown(e.t, 18, "performance")
		Assert.eq((find(calls(e), "custom", "PerfStepDown")[1].fields :: any)[1], "phone", "device kept")
		local off = env({ perfSampleRate = 0 })
		join(off, 19, newFacts())
		calls(off)
		Tracker.perf(off.t, 19, sample)
		Assert.eq(#find(calls(off), "custom", "PerfSample"), 0, "sample rate 0")
	end)

	test("store funnel: per-open sessions; prompts and receipts outside the store open none", function()
		local e = env()
		join(e, 20, newFacts())
		calls(e)
		Tracker.store(e.t, 20, "StoreOpened", "van")
		Tracker.store(e.t, 20, "ItemViewed", "style")
		Tracker.store(e.t, 20, "PromptShown", "StyleNoir")
		Tracker.store(e.t, 20, "PurchaseGranted", "StyleNoir")
		Tracker.store(e.t, 20, "PromptShown", "StyleNoir") -- the closing prompt after the receipt
		local out = find(calls(e), "funnel", "store_v1")
		Assert.eq(#out, 4, "four steps, the late PromptShown dropped as a backwards step")
		Assert.eq((out[1].fields :: any)[1], "van", "entry")
		Assert.eq(out[4].session, out[1].session, "one session")
		e.now += A.STORE_SESSION_SECONDS + 1
		Tracker.store(e.t, 20, "PromptShown", "StyleNoir")
		Tracker.store(e.t, 20, "PurchaseGranted", "StyleNoir")
		Tracker.store(e.t, 20, "ItemViewed", "style")
		out = calls(e)
		Assert.eq(#find(out, "funnel", "store_v1"), 0, "no session starts at step 3 or 4")
		local outside = find(out, "custom", "OutOfStorePurchase")
		Assert.eq(#outside, 2, "logged as out-of-store events instead")
		Assert.eq((outside[1].fields :: any)[1], "PromptShown", "step")
		Assert.eq((outside[2].fields :: any)[2], "StyleNoir", "product")
		Assert.eq(Tracker.stats(e.t).invalid, 1, "an item card with no open store")
	end)

	test("store funnel: a spamming client cannot inflate StoreOpened or flood the server", function()
		local e = env()
		join(e, 23, newFacts())
		calls(e)
		for _ = 1, 50 do
			Tracker.store(e.t, 23, "StoreOpened", "van", true)
			Tracker.store(e.t, 23, "ItemViewed", "hat", true)
		end
		local opened = find(calls(e), "funnel", "store_v1", "StoreOpened")
		Assert.eq(#opened, 1, "reopens within STORE_REOPEN_SECONDS share one session")
		Assert.truthy(Tracker.stats(e.t).dropBudget > 0, "client reports spend the player's budget")
		local sessions = 1
		for _ = 1, A.STORE_SESSIONS_MAX * 2 do
			e.now += A.STORE_REOPEN_SECONDS
			Tracker.store(e.t, 23, "StoreOpened", "van", true)
			sessions += #find(calls(e), "funnel", "store_v1", "StoreOpened")
		end
		Assert.eq(sessions, A.STORE_SESSIONS_MAX, "capped per player session")
		-- server-reported steps (Receipts.Granted) are never metered
		local s = env()
		join(s, 24, newFacts())
		calls(s)
		Tracker.store(s.t, 24, "StoreOpened", "van", true)
		for _ = 1, A.PLAYER_BURST + 5 do
			Tracker.medal(s.t, 24, "Haul", "BackRoom") -- empties the player's budget
		end
		Tracker.store(s.t, 24, "PurchaseGranted", "StyleNoir")
		Assert.eq(#find(calls(s), "funnel", "store_v1", "PurchaseGranted"), 1, "the server's own report passes")
	end)

	test("unknown players and steps are counted, never thrown", function()
		local e = env()
		Tracker.onboarding(e.t, 999, "Joined")
		Tracker.cloneFailed(e.t, 999, "busted", "BackRoom")
		Tracker.economy(e.t, 999, "Cash", 1, 1, "daily")
		Tracker.playerLeft(e.t, 999)
		join(e, 21, newFacts())
		Tracker.onboarding(e.t, 21, "NotAStep")
		Tracker.custom(e.t, 21, "NotAnEvent", {})
		Tracker.clip(e.t, 21, "explode", "video")
		Assert.eq(Tracker.stats(e.t).invalid, 6, "all counted")
	end)
end
