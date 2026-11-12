local LevelSpec = require("../../src/shared/Sim/LevelSpec")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local EventLog = require("../../src/shared/Sim/EventLog")
local Mechanisms = require("../../src/shared/Sim/Mechanisms")
local Harness = require("./Harness")
local spec = require("../../src/shared/Levels/L6_BigScoreBank")
local ok, errs = LevelSpec.validate(spec)
print("valid", ok, table.concat(errs, "\n"))
local level = LevelSpec.compile(spec)
local EV = EventLog.EV
local process = require("@lune/process")
local T0 = tonumber(process.args[1]) or 5.8
local vault = LevelSpec.indexOf(level, "door", "VaultDoor")
local function inLobby() return { { go = { 0, 9 } }, { go = { 0, -7 } }, { go = { -4, -11 } } } end
local function cat(...) local out = {} for _, t in { ... } do for _, s in t do table.insert(out, s) end end return out end
local plan = { runs = {
	{ [1] = { { go = { 0, 9 } }, { go = { 0, -7 } }, { goPlate = "A" }, { endRun = true } } },
	{ [1] = cat(inLobby(), { { waitUntil = 5.3 }, { go = { 0, -13 } }, { go = { 0, -16 } }, { goPlate = "B" }, { endRun = true } }) },
	{ [1] = cat(inLobby(), { { waitUntil = T0 }, { go = { 0, -13 } }, { go = { 0, -38 } }, { goPlate = "C" }, { endRun = true } }) },
	{ [1] = cat(inLobby(), { { waitUntil = T0 }, { go = { 0, -13 } }, { go = { 0, -38 } }, { goPlate = "D" }, { endRun = true } }) },
	{ [1] = cat(inLobby(), { { waitUntil = T0 }, { go = { 0, -13 } }, { go = { 0, -38 } }, { go = { 0, -46 } },
		{ waitFor = function(bot, view, t) return view ~= nil and Mechanisms.doorViewOf(view.doors[vault], t) == "open" end },
		{ goLoot = "Gold" }, { grab = "Gold" }, { go = { 0, -64 } }, { go = { 25, -64 } }, { go = { 25, 12 } }, { go = { 3, 18 } }, { stay = true } }) },
} }
local sim, runs = Harness.play(level, plan)
local r = HeistSim.result(sim)
for i, run in runs do
	print(i, "t", run.t, "banked", run.banked, "rej", EventLog.count(run.log, EV.Rejected), "stuck", run.stuck, "zap", run.zapped, "busted", run.busted, "caught", run.catches, "spotted", EventLog.count(run.log, EV.Spotted), "suspect", EventLog.count(run.log, EV.Suspect))
end
print(r.phase, r.reason, r.banked, "stars", r.stars.count, "clones", r.clonesUsed, "time", r.totalTime)
if process.args[1] == nil then print(Harness.dump({ runs[#runs] })) end
