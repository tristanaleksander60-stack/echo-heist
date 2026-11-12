-- L1: Analytics/LiveFlagSpec (definitions, document parsing, layering, rollouts, arms).

local Config = require("../../src/shared/Config")
local LiveFlagSpec = require("../../src/shared/Analytics/LiveFlagSpec")
local Assert = require("./Assert")

local DEFS = LiveFlagSpec.defs()

return function(test)
	test("Config.LiveFlags definitions are valid and cover the plan's switches", function()
		local errors = LiveFlagSpec.validateDefs(DEFS)
		Assert.eq(#errors, 0, table.concat(errors, "; "))
		-- §8.7 / §8.12 / §9.3 / brief: store, Quick Crew, SAVE CLIP, daily vault, boards, dressing,
		-- clip upload, Alarm Run tuning
		for _, name in
			{ "store", "quickCrew", "saveClip", "dailyVault", "boards", "dressing", "clipUpload", "alarmRun" }
		do
			Assert.truthy(DEFS[name], "flag " .. name)
		end
		Assert.eq(DEFS.clipUpload.default, false, "UploadCaptureAsync stays behind a flag, off")
		Assert.eq(DEFS.store.kind, "kill", "store is a kill switch")
	end)

	test("tuning defaults shadow the Config numbers they override", function()
		Assert.eq(DEFS.alarmVanSeconds.default, Config.Sim.ALARM_VAN_SECONDS, "van seconds")
		Assert.eq(DEFS.alarmLockSeconds.default, Config.Sim.ALARM_LOCK_SECONDS, "lock seconds")
		Assert.eq(DEFS.alarmChaseSpeedMult.default, Config.Sim.GUARD_CHASE_SPEED_MULT, "chase speed")
		Assert.eq(DEFS.crewCloneBudget.default, Config.Sim.CREW_CLONE_BUDGET, "clone budget")
		Assert.eq(DEFS.maxInstances.default, Config.Heist.MAX_INSTANCES, "instances")
		Assert.eq(DEFS.perfIntervalSeconds.default, Config.Analytics.Perf.INTERVAL_SECONDS, "perf interval")
	end)

	test("validateDefs catches unsafe definitions", function()
		local bad: any = {
			killOff = { kind = "kill", default = false },
			releaseOn = { kind = "release", default = true },
			tuneOut = { kind = "tune", default = 50, min = 0, max = 10 },
			tuneNoRange = { kind = "tune", default = 1 },
			armsBad = { kind = "experiment", default = "zz:100" },
			["Bad-Name"] = { kind = "kill", default = true },
			weird = { kind = "maybe", default = true },
		}
		Assert.eq(#LiveFlagSpec.validateDefs(bad), 7, "every bad definition reported")
	end)

	test("coerce: strict types, refuse out of range (never clamp)", function()
		Assert.eq(LiveFlagSpec.coerce(DEFS.store, false), false, "kill off")
		Assert.eq((LiveFlagSpec.coerce(DEFS.store, "false")), nil, "string is not a boolean")
		Assert.eq((LiveFlagSpec.coerce(DEFS.store, 0)), nil, "number is not a boolean")
		Assert.eq(LiveFlagSpec.coerce(DEFS.clipUpload, 25), 25, "release percent")
		Assert.eq((LiveFlagSpec.coerce(DEFS.clipUpload, 101)), nil, "percent > 100")
		Assert.eq(LiveFlagSpec.coerce(DEFS.alarmVanSeconds, 25), 25, "tune in range")
		local v, why = LiveFlagSpec.coerce(DEFS.alarmVanSeconds, 250)
		Assert.eq(v, nil, "typo 250 refused")
		Assert.eq(why, "range", "reason")
		Assert.eq((LiveFlagSpec.coerce(DEFS.alarmVanSeconds, 0 / 0)), nil, "NaN")
		Assert.eq(LiveFlagSpec.coerce(DEFS.ftueVariant, "base:50,a:50"), "base:50,a:50", "arms")
		Assert.eq((LiveFlagSpec.coerce(DEFS.ftueVariant, "base:50,evil:50")), nil, "arm not in VARIANTS")
	end)

	test("parseDocument: versioned or flat, bad entries skipped, the rest apply", function()
		local o, errs = LiveFlagSpec.parseDocument(DEFS, {
			v = 1,
			note = "incident 2026-12-05 store prompt loop",
			flags = { store = false, alarmVanSeconds = 25, nope = true, quickCrew = "off" },
		})
		Assert.eq(o.store, false, "store off")
		Assert.eq(o.alarmVanSeconds, 25, "retuned")
		Assert.eq(o.quickCrew, nil, "bad value skipped")
		Assert.eq(#errs, 2, "unknown flag + bad value reported")
		local flat = LiveFlagSpec.parseDocument(DEFS, { saveClip = false, note = "x" })
		Assert.eq(flat.saveClip, false, "flat document")
		local _, vErr = LiveFlagSpec.parseDocument(DEFS, { v = 2, flags = { store = false } })
		Assert.eq(#vErr, 1, "future version refused whole")
		local none, nErr = LiveFlagSpec.parseDocument(DEFS, nil)
		Assert.eq(next(none), nil, "no document = no overrides")
		Assert.eq(#nErr, 0, "and no error")
		local _, sErr = LiveFlagSpec.parseDocument(DEFS, "store=false")
		Assert.eq(#sErr, 1, "not a table")
	end)

	test("resolve: default < config < store < test per flag; kill switches: off wins", function()
		local values, sources = LiveFlagSpec.resolve(DEFS, {
			{ name = "config", values = { store = false, saveClip = false, alarmVanSeconds = 30, boards = true } },
			{ name = "store", values = { store = true, alarmVanSeconds = 25, cashShop = false } },
			{ name = "test", values = { quickCrew = false, cashShop = true } },
		})
		Assert.eq(values.store, false, "a stale store = true never cancels EH_store = false")
		Assert.eq(sources.store, "config", "source: the layer that turned it off")
		Assert.eq(values.cashShop, false, "a test value cannot turn a killed switch back on")
		Assert.eq(sources.cashShop, "store", "source")
		Assert.eq(values.alarmVanSeconds, 25, "tune flags: the store layer still wins over config")
		Assert.eq(sources.alarmVanSeconds, "store", "source")
		Assert.eq(values.saveClip, false, "config only")
		Assert.eq(sources.saveClip, "config", "source")
		Assert.eq(values.quickCrew, false, "test layer")
		Assert.eq(values.boards, true, "explicitly on")
		Assert.eq(sources.boards, "config", "source of an explicit on")
		Assert.eq(sources.dressing, "default", "default source")
		local changed = LiveFlagSpec.changed(LiveFlagSpec.resolve(DEFS, {}), values)
		Assert.eq(table.concat(changed, ","), "alarmVanSeconds,cashShop,quickCrew,saveClip,store", "changed, sorted")
		local shadowed = LiveFlagSpec.shadowed(
			DEFS,
			{ alarmVanSeconds = 30, store = false, quickCrew = true, saveClip = false },
			{ alarmVanSeconds = 25, store = true, quickCrew = false }
		)
		Assert.eq(table.concat(shadowed, ","), "alarmVanSeconds,quickCrew", "stale overrides; an off is never shadowed")
	end)

	test("per-player values: sticky release percent and experiment arms", function()
		local def = DEFS.clipUpload
		Assert.falsy(LiveFlagSpec.isOn(def, 50), "50% is not on for the whole server")
		Assert.truthy(LiveFlagSpec.isOn(def, 100), "100% is")
		Assert.truthy(LiveFlagSpec.isOn(DEFS.store, true), "kill on")
		local on = 0
		for uid = 1, 4000 do
			local v = LiveFlagSpec.forUser("clipUpload", def, 25, uid)
			Assert.eq(v, LiveFlagSpec.forUser("clipUpload", def, 25, uid), "sticky")
			if v then
				on += 1
			end
		end
		Assert.near(on / 4000, 0.25, 0.03, "25% rollout")
		Assert.eq(LiveFlagSpec.forUser("ftueVariant", DEFS.ftueVariant, "base:100", 7), "base", "single arm")
		Assert.eq(LiveFlagSpec.forUser("ftueVariant", DEFS.ftueVariant, "junk", 7), "base", "bad arms fall back")
		Assert.eq(LiveFlagSpec.forUser("alarmVanSeconds", DEFS.alarmVanSeconds, 30, 7), 30, "tune as is")
		Assert.eq(LiveFlagSpec.configKey("saveClip"), "EH_saveClip", "ConfigService key")
	end)
end
