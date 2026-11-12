-- L1: Audio/EventCues, the sim event -> cue map that AudioDirector.event plays: every name it uses exists,
-- loops it stops are loops, positions and actor fields are well-formed, and the key moments sound.

local Cues = require("../../src/shared/Audio/Cues")
local EventCues = require("../../src/shared/Audio/EventCues")
local EventLog = require("../../src/shared/Sim/EventLog")
local Assert = require("./Assert")

local EV = EventLog.EV
local WHERE = { plate = true, door = true, laser = true, switch = true, loot = true, actor = true, van = true }
local FIELDS = { a = true, b = true, c = true }
local MINE = { only = true, ["not"] = true, ["2d"] = true }

local function cuesOf(kind: number): { string }
	local out = {}
	for _, act in EventCues.forKind(kind) do
		if act.cue then
			table.insert(out, act.cue)
		end
	end
	return out
end

return function(test)
	test("every action names a real cue, music state or loop", function()
		local known: { [number]: boolean } = {}
		for _, code in EV do
			known[code] = true
		end
		for kind, actions in EventCues.byKind do
			Assert.truthy(known[kind], "event kind " .. tostring(kind) .. " exists in EventLog.EV")
			Assert.truthy(#actions > 0, "kind " .. kind .. " has actions")
			for _, act in actions do
				if act.cue then
					Assert.truthy(Cues.cues[act.cue] ~= nil, "cue " .. act.cue)
				end
				if act.music then
					Assert.truthy(Cues.states[act.music] ~= nil, "music state " .. act.music)
				end
				if act.stop then
					Assert.truthy(Cues.cues[act.stop] and Cues.cues[act.stop].loop, "stop " .. act.stop .. " is a loop")
				end
				if act.loop then
					Assert.truthy(act.cue and Cues.cues[act.cue].loop, "loop action plays a loop cue")
				end
				if act.at then
					Assert.truthy(WHERE[act.at], "where " .. act.at)
					if act.at ~= "actor" and act.at ~= "van" then
						Assert.truthy(act.index and FIELDS[act.index], "device index field for " .. act.at)
					else
						Assert.truthy(act.at == "van" or (act.actor and FIELDS[act.actor]), "actor field for actor")
					end
				end
				if act.actor then
					Assert.truthy(FIELDS[act.actor], "actor field")
				end
				if act.mine then
					Assert.truthy(MINE[act.mine] and act.actor ~= nil, "mine rule needs an actor")
				end
				Assert.truthy(act.cue or act.music or act.stop, "action does something")
			end
		end
	end)

	test("the signature moments sound", function()
		Assert.truthy(table.find(cuesOf(EV.PlateDown), "PlatePress") ~= nil, "plate press")
		Assert.truthy(table.find(cuesOf(EV.Bank), "BankKaching") ~= nil, "ka-ching")
		Assert.truthy(table.find(cuesOf(EV.Busted), "CloneBusted") ~= nil, "clone busted")
		Assert.truthy(table.find(cuesOf(EV.Caught), "Busted") ~= nil, "you are caught")
		Assert.truthy(table.find(cuesOf(EV.Zap), "LaserZap") ~= nil, "zap")
		Assert.truthy(table.find(cuesOf(EV.HeistComplete), "HeistFanfare") ~= nil, "fanfare")
		local alarm = EventCues.forKind(EV.AlarmOn)
		Assert.eq(alarm[1].music, "Alarm", "the alarm switches to the chase music")
		Assert.eq(#EventCues.forKind(EV.RunStart), 0, "run start is the RewindDirector's job")
		Assert.eq(#EventCues.forKind(999), 0, "unknown kinds are silent")
	end)

	test("own catch is the wah-wah, someone else's is Gus's sting", function()
		local caught = EventCues.forKind(EV.Caught)
		Assert.eq(caught[1].cue, "Busted", "first")
		Assert.eq(caught[1].mine, "only", "only for me")
		Assert.eq(caught[2].cue, "GusAlert", "second")
		Assert.eq(caught[2].mine, "not", "for the others")
	end)
end
