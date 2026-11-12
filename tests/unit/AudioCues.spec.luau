-- L1: Audio/Cues + Audio/Manifest + Audio/CueCheck (docs/AUDIO.md "Cue rules"): the shipped cue table is
-- valid, every id is a verified licensed upload, and broken copies are caught.

local Config = require("../../src/shared/Config")
local CueCheck = require("../../src/shared/Audio/CueCheck")
local Cues = require("../../src/shared/Audio/Cues")
local Manifest = require("../../src/shared/Audio/Manifest")
local Assert = require("./Assert")

local A = Config.Audio

-- A deep copy of the shipped cue module that a test may break.
local function copy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end

local function problemsOf(mutate: (c: any) -> ()): { string }
	local c = copy(Cues)
	mutate(c)
	return CueCheck.validate(c, Manifest, A)
end

local function hasProblem(list: { string }, needle: string): boolean
	for _, p in list do
		if string.find(p, needle, 1, true) then
			return true
		end
	end
	return false
end

return function(test)
	test("the shipped cue table is valid", function()
		local problems = CueCheck.validate(Cues, Manifest, A)
		Assert.eq(#problems, 0, "problems: " .. table.concat(problems, "; "))
	end)

	test("every manifest id is a licensed partner upload", function()
		local n = 0
		for id, e in Manifest.assets do
			n += 1
			Assert.truthy(type(id) == "number" and id > 0, "id")
			Assert.truthy(Manifest.LICENSED_CREATORS[e.creatorId] ~= nil, "licensed creator for " .. id)
			Assert.eq(Manifest.LICENSED_CREATORS[e.creatorId], e.creator, "creator name matches id for " .. id)
			Assert.truthy(e.seconds >= 0 and #e.title > 0, "title and duration for " .. id)
		end
		Assert.truthy(n >= 90, "manifest holds the verified ids")
	end)

	test("every manifest id is used by a cue or a set (no stale rows)", function()
		local used: { [number]: boolean } = {}
		for _, cue in Cues.cues do
			for _, id in cue.ids do
				used[id] = true
			end
			for _, id in cue.alt or {} do
				used[id] = true
			end
		end
		for _, set in Cues.sets do
			for _, id in set.ids do
				used[id] = true
			end
			for _, id in set.alt or {} do
				used[id] = true
			end
		end
		for id in Manifest.assets do
			Assert.truthy(used[id], "manifest id " .. id .. " is used")
		end
	end)

	test("the plan's cue list is covered", function()
		for _, name in
			{
				"RewindClack",
				"TapeStop",
				"RewindWhirr",
				"RewindStinger",
				"RewindClunk",
				"RunStamp",
				"CloneChime",
				"CloneBusted",
				"PlatePress",
				"PlateRelease",
				"DoorOpen",
				"DoorClose",
				"LaserHum",
				"LaserZap",
				"Grab",
				"BankKaching",
				"BankCoins",
				"GusStep",
				"GusHuh",
				"GusAlert",
				"Busted",
				"AlarmBell",
				"VanHorn",
				"VanEngine",
				"HeistFanfare",
				"UIClick",
				"SleighBells",
			}
		do
			Assert.truthy(Cues.cues[name] ~= nil, "cue " .. name)
		end
		for _, set in { "Garage", "Caper", "Xmas", "Chase", "Results" } do
			Assert.truthy(Cues.sets[set] ~= nil, "set " .. set)
		end
	end)

	test("summary counts cues with real ids and the empty ones", function()
		local s = CueCheck.summary(Cues)
		Assert.eq(s.cues, s.withIds + #s.empty, "every cue is counted once")
		Assert.truthy(s.withIds >= 40, "most cues have ids")
		Assert.truthy(table.find(s.empty, "GusStep") ~= nil, "GusStep waits for the owner")
		Assert.truthy(table.find(s.empty, "RewindStinger") ~= nil, "the reversed stinger is an owner upload")
		Assert.eq(s.sets, 7, "seven music sets")
		Assert.truthy(s.ids > 0 and s.alternates > 0, "ids and alternates")
	end)

	test("an invented id is rejected", function()
		local p = problemsOf(function(c)
			table.insert(c.cues.UIClick.ids, 123456789)
		end)
		Assert.truthy(hasProblem(p, "not in Audio/Manifest"), "unverified id")
	end)

	test("a community upload is rejected even when it is in the manifest", function()
		local m = copy(Manifest)
		m.assets[42] = { creator = "someone", creatorId = 99, title = "x", seconds = 1, kind = "SoundEffect" }
		local c = copy(Cues)
		table.insert(c.cues.UIClick.ids, 42)
		local p = CueCheck.validate(c, m, A)
		Assert.truthy(hasProblem(p, "community upload"), "not licensed")
	end)

	test("field rules: bus, volume, jitter, voices, priority, rolloff, typos", function()
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.Grab.bus = "Loud"
				end),
				"unknown bus"
			),
			"bus"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.Grab.volume = 0
				end),
				"volume"
			),
			"volume"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.Grab.pitchJitter = 0.5
				end),
				"pitchJitter"
			),
			"jitter"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.Grab.maxVoices = 0
				end),
				"maxVoices"
			),
			"voices"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.Grab.priority = 9
				end),
				"priority"
			),
			"priority"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.Grab.rolloff = "huge"
				end),
				"rolloff"
			),
			"rolloff"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.Grab.volumne = 1
				end),
				"unknown field 'volumne'"
			),
			"typo"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.Grab.ids = { c.cues.Grab.ids[1], c.cues.Grab.ids[1] }
				end),
				"listed twice"
			),
			"duplicate take"
		)
	end)

	test("an empty cue must still say what to search for", function()
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.GusStep.search = ""
				end),
				"search words"
			),
			"search"
		)
	end)

	test("tonal ladders cannot be pitch-jittered", function()
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.CloneChime.pitchJitter = 0.04
				end),
				"stepped"
			),
			"stepped jitter"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.cues.CloneChime.steps = {}
				end),
				"steps"
			),
			"empty ladder"
		)
	end)

	test("music sets: aligned mixes, a 5-step Crew Layers map that never steps down", function()
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.sets.Caper.tierToMix = { 1, 2, 3 }
				end),
				"tierToMix needs 5"
			),
			"map length"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.sets.Caper.tierToMix = { 1, 3, 2, 4, 5 }
				end),
				"steps down"
			),
			"monotonic"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.sets.Caper.tierToMix = { 1, 2, 3, 4, 9 }
				end),
				"not a mix index"
			),
			"index range"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					-- Agent X (100 s) does not line up with Sneaky Schemes (130 s)
					table.insert(c.sets.Caper.ids, 1845476443)
				end),
				"differ in length"
			),
			"length mismatch"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.sets.Garage.tierToMix = { 1, 1, 1, 1, 1 }
				end),
				"playlist has no tierToMix"
			),
			"playlist"
		)
	end)

	test("states and preloads reference what exists", function()
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.states.Heist.set = "Nope"
				end),
				"unknown set"
			),
			"state set"
		)
		Assert.truthy(
			hasProblem(
				problemsOf(function(c)
					c.states.Heist.xmas = "Nope"
				end),
				"Christmas set"
			),
			"xmas set"
		)
		local audio = table.clone(A)
		audio.PRELOAD = { "UIClick", "Nope" }
		local p = CueCheck.validate(Cues, Manifest, audio)
		Assert.truthy(hasProblem(p, "PRELOAD"), "preload")
	end)

	test("same-length mix sets in the shipped table really are the same length", function()
		for name, set in Cues.sets do
			if set.kind == "mixes" and #set.ids > 1 then
				local lo, hi = math.huge, -math.huge
				for _, id in set.ids do
					local s = Manifest.assets[id].seconds
					lo = math.min(lo, s)
					hi = math.max(hi, s)
				end
				Assert.le(hi - lo, 2, name .. " mix lengths")
			end
		end
	end)
end
