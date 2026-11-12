-- L1: Analytics/Events (the dashboard schema) and Analytics/Kpi (the §9.7 bars).

local fs = require("@lune/fs")

local Config = require("../../src/shared/Config")
local Events = require("../../src/shared/Analytics/Events")
local Kpi = require("../../src/shared/Analytics/Kpi")
local Validator = require("../../src/shared/Rec/Validator")
local Assert = require("./Assert")

return function(test)
	test("catalog obeys every Roblox dashboard limit", function()
		local errors = Events.validateCatalog()
		Assert.eq(#errors, 0, "catalog errors: " .. table.concat(errors, "; "))
		local names = 0
		for name, def in Events.CUSTOM do
			names += 1
			Assert.le(#def.fields, 3, name .. " fields")
			Assert.le(Events.cardinality(def.fields), 8000, name .. " combinations")
		end
		Assert.le(names, 100, "custom event names")
		local funnels = 0
		for name, f in Events.FUNNELS do
			funnels += 1
			Assert.le(Events.cardinality(f.fields), 8000, name .. " step-1 field combinations")
		end
		Assert.le(funnels, 10, "funnels on the dashboard")
	end)

	test("every event the plan names (§9.7) exists", function()
		for _, name in
			{
				"CloneFailed",
				"RedoUsed",
				"UndoUsed",
				"AlarmTripped",
				"AlarmEscaped",
				"ClipSaveTapped",
				"InviteJoined",
				"JoinSource",
				"QuickCrewJoined",
				"TaintedRun",
				"PerfSample",
			}
		do
			Assert.truthy(Events.CUSTOM[name], "missing custom event " .. name)
		end
		Assert.eq(Events.CUSTOM.CloneFailed.fields[1], "cause", "CloneFailed{cause}")
		Assert.eq(Events.CUSTOM.TaintedRun.fields[1], "taint", "TaintedRun{reason}")
		Assert.eq(Events.CUSTOM.PerfSample.fields[1], "device", "PerfSample{tier}")
		Assert.truthy(Events.FUNNELS.heist_v1 and not Events.FUNNELS.heist_v1.onboarding, "per-heist funnel")
	end)

	test("onb_v2 is the §7.5 funnel in order, with Minute10 held for SwarmSeen", function()
		local f = Events.FUNNELS.onb_v2
		Assert.eq(Events.ONBOARDING, "onb_v2", "funnel name")
		Assert.truthy(f.onboarding, "one-time funnel")
		local plan = {
			"Joined",
			"FirstMove",
			"FirstPlate",
			"FirstRewind",
			"FirstCloneSeen",
			"FirstBank",
			"L1Complete",
			"ReelShown",
			"L2Started",
			"FirstCloneBusted",
			"SwarmSeen",
			"Minute10",
		}
		Assert.eq(#f.steps, #plan, "step count")
		for i, s in plan do
			Assert.eq(f.steps[i], s, "step " .. i)
		end
		Assert.eq((f.requires :: any).Minute10[1], "SwarmSeen", "Minute10 requires SwarmSeen")
		Assert.eq(f.fields[1], "source", "step-1 field 1 is the JoinSource")
	end)

	test("onb_v2 matches Protocol.FTUE_STEPS (HeistService's saved ftueStep index)", function()
		local Protocol = require("../../src/shared/Heist/Protocol")
		local steps = Protocol.FTUE_STEPS
		local f = Events.FUNNELS.onb_v2
		Assert.eq(#steps, #f.steps, "step count")
		for i, s in steps do
			Assert.eq(f.steps[i], s, "step " .. i)
		end
		local text = fs.readFile("src/server/Heist/HeistService.luau")
		Assert.truthy(
			string.find(text, "HeistService.FTUE_STEPS = Protocol.FTUE_STEPS", 1, true) ~= nil,
			"server uses it"
		)
	end)

	test("domains: unknown values map to other, numbers bucket on the §9.7 bars", function()
		Assert.eq(Events.canon("level", "BackRoom"), "BackRoom", "known level")
		Assert.eq(Events.canon("level", "cs1_back_room"), "Other", "spec ids are mapped by the Tracker, not here")
		Assert.eq(Events.canon("level", 12), "Other", "a number in a list domain")
		Assert.eq(Events.canon("source", "hacker"), "organic", "unknown source")
		Assert.eq(Events.canon("tag", string.rep("x", 300)), "invalid", "crafted tag")
		Assert.eq(Events.bucket("len", 59.9), "30-60s", "bounce bucket")
		Assert.eq(Events.bucket("len", 60), "1-3m", "60 s is not a bounce")
		Assert.eq(Events.bucket("len", 719), "10-12m", "10-12 min")
		Assert.eq(Events.bucket("len", 99999), "60m+", "top bucket")
		Assert.eq(Events.bucket("ftueTime", 44.9), "30-45s", "first clone within 45 s")
		Assert.eq(Events.bucket("ftueTime", 45), "45-60s", "45 s is over the bar")
		Assert.eq(Events.bucket("load", 10), "10-15s", "join -> control > 10 s")
		-- a PerfSample p95 is the upper edge of its 0.5 ms bin, rounded to 0.1 ms
		Assert.eq(Events.bucket("ms", 16.7), "14-18", "steady 60 fps")
		Assert.eq(Events.bucket("ms", 17.5), "14-18", "60 fps with jitter")
		Assert.eq(Events.bucket("ms", 22.2), "18-28", "45 fps is not the 60 fps class")
		Assert.eq(Events.bucket("ms", 33.3), "28-36", "steady 30 fps")
		Assert.eq(Events.bucket("ms", 34), "28-36", "30 fps with jitter is at the ceiling, not over it")
		Assert.eq(Events.bucket("ms", 36.5), "36-50", "over the ceiling")
		Assert.eq(Events.DOMAINS.ms.edges[4], Config.Analytics.Perf.SLOW_MS, "36+ = the governor's slow line")
		Assert.eq(Events.bucket("clones", 0), "0", "no clones")
		Assert.eq(Events.bucket("clones", 12), "9-12", "12 clones")
		Assert.eq(Events.bucket("stars", 6), "s6-13", "Big Score gate")
		Assert.eq(Events.canon("len", 0 / 0), "<30s", "NaN falls back to other")
		local f = Events.fields({ "crew", "yesno", "level" }, { "trio", nil, "BigScoreBank" })
		Assert.eq(f[1], "trio", "crew")
		Assert.eq(f[2], "no", "missing value")
		Assert.eq(f[3], "BigScoreBank", "level")
	end)

	test("domains cover the game's own ids", function()
		for _, key in Config.Data.LEVEL_ORDER do
			Assert.truthy(Events.DOMAINS.level.set[key], "level " .. key)
		end
		for _, key in Config.Heist.LEVEL_DATA_KEYS do
			Assert.truthy(Events.DOMAINS.level.set[key], "heist data key " .. key)
		end
		for key in Config.Data.Products do
			Assert.truthy(Events.DOMAINS.product.set[key], "product " .. key)
		end
		for name in Validator.FLAG do
			Assert.truthy(Events.DOMAINS.taint.set[string.lower(name)], "taint " .. name)
		end
		for _, v in Config.Analytics.VARIANTS do
			Assert.truthy(Events.DOMAINS.variant.set[v], "variant " .. v)
		end
		Assert.truthy(Events.DOMAINS.build.set["b" .. Config.Analytics.BUILD], "fallback build is a value")
		Assert.truthy(Events.DOMAINS.build.set.pv00 and Events.DOMAINS.build.set.pv99, "PlaceVersion buckets")
		for _, c in Events.ECONOMY.CURRENCIES do
			Assert.truthy(Config.Data.Currencies[c], "currency " .. c)
		end
	end)

	test("economy reasons map to stable transaction types and SKUs", function()
		local e = Events.economyEntry("heist:BackRoom") :: any
		Assert.eq(e.transactionType, "Gameplay", "heist award")
		Assert.eq(e.sku, "Heist_BackRoom", "heist sku")
		Assert.eq((Events.economyEntry("heist:Nope") :: any).sku, "Heist_Other", "unknown level")
		Assert.eq((Events.economyEntry("buy:Paint_MidnightBlue") :: any).sku, "Paint_MidnightBlue", "cash shop")
		Assert.eq((Events.economyEntry("buy:Paint_MidnightBlue") :: any).transactionType, "Shop", "shop")
		Assert.eq((Events.economyEntry("buy:Trophy_SnowGlobe") :: any).sku, "Trophy_SnowGlobe", "trophy buy")
		Assert.eq((Events.economyEntry("buy:made_up") :: any).sku, "Other", "unknown item")
		Assert.eq((Events.economyEntry("daily") :: any).sku, "DailyVault", "daily")
		Assert.eq((Events.economyEntry("bag") :: any).sku, "BagLevel", "bag")
		Assert.eq((Events.economyEntry("medals") :: any).sku, "Medals", "stars mirror")
		Assert.eq((Events.economyEntry("??") :: any).sku, "Other", "unknown reason")
		Assert.eq(Events.economyEntry("load"), nil, "initial load is not a flow")
	end)

	test("values clamp to their spec", function()
		Assert.eq(Events.value(Events.CUSTOM.CloneFailed, nil), 1, "count default")
		Assert.eq(Events.value(Events.CUSTOM.CloneFailed, 3.7), 3, "whole count")
		Assert.eq(Events.value(Events.CUSTOM.CloneFailed, -5), 1, "count at least 1")
		Assert.eq(Events.value(Events.CUSTOM.SessionEnd, 99999), 1440, "minutes cap")
		Assert.eq(Events.value(Events.CUSTOM.PerfSample, 16.66), 16.7, "one decimal")
		Assert.eq(Events.value(Events.CUSTOM.PerfSample, 0 / 0), 1, "NaN")
	end)

	test("KPI bars (§9.7): status, ad cohorts, minimum cohort", function()
		Assert.eq(Kpi.evaluate("d1", 7.9, { n = 400 }), "kill", "D1 < 8%")
		Assert.eq(Kpi.evaluate("d1", 8, { n = 400 }), "fix", "D1 8%")
		Assert.eq(Kpi.evaluate("d1", 15, { n = 400 }), "healthy", "D1 15%")
		Assert.eq(Kpi.evaluate("d1", 22, { n = 400 }), "double", "D1 22%")
		Assert.eq(Kpi.evaluate("d1", 30, { n = 299 }), "insufficient", "cohort < 300")
		Assert.eq(Kpi.evaluate("d1", 11.5, { n = 400, cohort = "ad" }), "healthy", "ad bars 4 points lower")
		Assert.eq(Kpi.evaluate("d1", 2, { n = 400, cohort = "ad" }), "fix", "kill never fires on ad cohorts")
		Assert.eq(Kpi.evaluate("bounce60", 36), "kill", "bounce > 35%")
		Assert.eq(Kpi.evaluate("bounce60", 20), "healthy", "bounce <= 20%")
		Assert.eq(Kpi.evaluate("bounce60", 12), "double", "bounce <= 12%")
		Assert.eq(Kpi.evaluate("bounce60", 25), "fix", "between")
		Assert.eq(Kpi.evaluate("swarmSeen10", 60), "healthy", "SwarmSeen 60%")
		Assert.eq(Kpi.evaluate("swarmSeen10", 34), "kill", "SwarmSeen < 35%")
		Assert.eq(Kpi.evaluate("joinToControl", 21), "kill", "> 20 s")
		Assert.eq(Kpi.evaluate("joinToControl", 10), "healthy", "<= 10 s")
		Assert.eq(Kpi.evaluate("medianFirstSession", 11), "fix", "10-12 min")
		Assert.eq(Kpi.evaluate("medianFirstBank", 60), "healthy", "Nov 30 gate")
		Assert.truthy(#Kpi.ids() >= 10, "every bar is listed")
	end)
end
