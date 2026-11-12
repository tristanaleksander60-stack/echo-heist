--!strict
-- Audio/CueCheck: validates the cue table (Audio/Cues) against the manifest (Audio/Manifest) and
-- Config.Audio. Pure: tests/unit/AudioCues.spec runs it on the shipped table and on broken copies, and the
-- AudioDirector warns once per problem at boot. Rules (docs/AUDIO.md "Cue rules"):
--   * every id is a positive integer that the manifest knows, uploaded by a licensed creator (no invented
--     or community ids); no take twice in one cue
--   * a known bus, a sane level, jitter, voice cap, cooldown, priority and rolloff preset; no unknown fields
--   * an empty cue still says what to search for
--   * a "mixes" set: every mix the same length (so they stay aligned when they loop) and a 5-entry
--     Crew Layers map that never steps down
--   * every music state names a set that exists, and every preload name is a cue

local CueCheck = {}

export type Summary = {
	cues: number,
	withIds: number,
	empty: { string },
	ids: number, -- distinct ids used by cues and sets (alternates excluded)
	alternates: number, -- distinct alternate ids
	sets: number,
}

local BUSES = { Music = true, SFX = true, Clone = true, UI = true, Ambience = true, Warnings = true }
local CUE_FIELDS = {
	ids = true,
	alt = true,
	search = true,
	bus = true,
	volume = true,
	pitch = true,
	pitchJitter = true,
	volumeJitter = true,
	maxVoices = true,
	cooldown = true,
	priority = true,
	rolloff = true,
	loop = true,
	choke = true,
	steps = true,
	cloneable = true,
	duck = true,
	caption = true,
	note = true,
}
local SET_FIELDS = {
	ids = true,
	alt = true,
	search = true,
	kind = true,
	volume = true,
	tierToMix = true,
	bpm = true,
	note = true,
}
local TIERS = 5 -- S0..S4
local MIX_LENGTH_TOLERANCE = 2 -- seconds (the store rounds durations)

local function isInt(v: any): boolean
	return type(v) == "number" and v == v and v % 1 == 0
end

local function inRange(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and v >= lo and v <= hi
end

local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

-- Checks one id list (takes or alternates); returns the manifest entries it found.
local function checkIds(where: string, list: any, manifest: any, problems: { string }, allowEmpty: boolean): { any }
	local found = {}
	if type(list) ~= "table" then
		table.insert(problems, where .. ": must be a list of asset ids")
		return found
	end
	if #list == 0 and not allowEmpty then
		table.insert(problems, where .. ": needs at least one id")
	end
	local seen: { [number]: boolean } = {}
	for i, id in list do
		if not isInt(id) or id <= 0 then
			table.insert(problems, string.format("%s[%s]: %s is not an asset id", where, tostring(i), tostring(id)))
			continue
		end
		if seen[id] then
			table.insert(problems, string.format("%s: id %d is listed twice", where, id))
		end
		seen[id] = true
		local entry = manifest.assets[id]
		if entry == nil then
			table.insert(problems, string.format("%s: id %d is not in Audio/Manifest (unverified id)", where, id))
		elseif manifest.LICENSED_CREATORS[entry.creatorId] == nil then
			table.insert(
				problems,
				string.format("%s: id %d is a community upload by %s, not licensed", where, id, tostring(entry.creator))
			)
		else
			table.insert(found, entry)
		end
	end
	return found
end

local function checkCue(name: string, cue: any, manifest: any, audio: any, problems: { string })
	local where = "cue " .. name
	if type(cue) ~= "table" then
		table.insert(problems, where .. ": not a table")
		return
	end
	for k in cue do
		if not CUE_FIELDS[k] then
			table.insert(problems, string.format("%s: unknown field '%s'", where, tostring(k)))
		end
	end
	checkIds(where .. ".ids", cue.ids, manifest, problems, true)
	if cue.alt ~= nil then
		checkIds(where .. ".alt", cue.alt, manifest, problems, false)
	end
	if type(cue.search) ~= "string" or #cue.search < 3 then
		table.insert(problems, where .. ": needs search words (what to look for in the Creator Store)")
	end
	if not BUSES[cue.bus] then
		table.insert(problems, string.format("%s: unknown bus '%s'", where, tostring(cue.bus)))
	end
	if not inRange(cue.volume, 0.01, 4) then
		table.insert(problems, where .. ": volume must be in 0.01..4")
	end
	if cue.pitch ~= nil and not inRange(cue.pitch, 0.5, 2) then
		table.insert(problems, where .. ": pitch must be in 0.5..2")
	end
	if cue.pitchJitter ~= nil and not inRange(cue.pitchJitter, 0, 0.2) then
		table.insert(problems, where .. ": pitchJitter must be in 0..0.2")
	end
	if cue.volumeJitter ~= nil and not inRange(cue.volumeJitter, 0, 0.3) then
		table.insert(problems, where .. ": volumeJitter must be in 0..0.3")
	end
	if cue.maxVoices ~= nil and not (isInt(cue.maxVoices) and cue.maxVoices >= 1 and cue.maxVoices <= 16) then
		table.insert(problems, where .. ": maxVoices must be an integer 1..16")
	end
	if cue.cooldown ~= nil and not inRange(cue.cooldown, 0, 30) then
		table.insert(problems, where .. ": cooldown must be in 0..30 s")
	end
	if cue.priority ~= nil and not (isInt(cue.priority) and cue.priority >= 1 and cue.priority <= 5) then
		table.insert(problems, where .. ": priority must be an integer 1..5")
	end
	if cue.rolloff ~= nil and (type(cue.rolloff) ~= "string" or audio.ROLLOFF[cue.rolloff] == nil) then
		table.insert(problems, string.format("%s: unknown rolloff preset '%s'", where, tostring(cue.rolloff)))
	end
	if cue.steps ~= nil then
		if type(cue.steps) ~= "table" or #cue.steps == 0 then
			table.insert(problems, where .. ": steps must be a non-empty semitone list")
		else
			for _, st in cue.steps do
				if not inRange(st, -24, 24) then
					table.insert(problems, where .. ": steps must be semitones in -24..24")
					break
				end
			end
		end
		if (cue.pitchJitter or audio.DEFAULT_PITCH_JITTER) ~= 0 then
			table.insert(problems, where .. ": a stepped (tonal) cue must have pitchJitter = 0")
		end
	end
	if cue.caption ~= nil and (type(cue.caption) ~= "string" or #cue.caption == 0) then
		table.insert(problems, where .. ": caption must be a non-empty string")
	end
	for _, flag in { "loop", "choke", "cloneable", "duck" } do
		if cue[flag] ~= nil and type(cue[flag]) ~= "boolean" then
			table.insert(problems, string.format("%s: %s must be a boolean", where, flag))
		end
	end
	if cue.loop == true and cue.choke == true then
		table.insert(problems, where .. ": a loop cannot also choke (stop loops by handle)")
	end
end

local function checkSet(name: string, set: any, manifest: any, problems: { string })
	local where = "set " .. name
	if type(set) ~= "table" then
		table.insert(problems, where .. ": not a table")
		return
	end
	for k in set do
		if not SET_FIELDS[k] then
			table.insert(problems, string.format("%s: unknown field '%s'", where, tostring(k)))
		end
	end
	local entries = checkIds(where .. ".ids", set.ids, manifest, problems, false)
	if set.alt ~= nil then
		checkIds(where .. ".alt", set.alt, manifest, problems, false)
	end
	if type(set.search) ~= "string" or #set.search < 3 then
		table.insert(problems, where .. ": needs search words")
	end
	if not inRange(set.volume, 0.01, 4) then
		table.insert(problems, where .. ": volume must be in 0.01..4")
	end
	if set.bpm ~= nil and not inRange(set.bpm, 40, 240) then
		table.insert(problems, where .. ": bpm must be in 40..240 (or nil = unknown)")
	end
	if set.kind == "mixes" then
		local map = set.tierToMix
		local n = if type(set.ids) == "table" then #set.ids else 0
		if type(map) ~= "table" or #map ~= TIERS then
			table.insert(problems, string.format("%s: tierToMix needs %d entries (S0..S4)", where, TIERS))
		else
			local last = 0
			for i, m in map do
				if not (isInt(m) and m >= 1 and m <= n) then
					table.insert(
						problems,
						string.format("%s: tierToMix[%d] = %s is not a mix index", where, i, tostring(m))
					)
				elseif m < last then
					table.insert(problems, string.format("%s: tierToMix steps down at S%d", where, i - 1))
				else
					last = m
				end
			end
		end
		local lo, hi = math.huge, -math.huge
		for _, e in entries do
			lo = math.min(lo, e.seconds)
			hi = math.max(hi, e.seconds)
		end
		if #entries > 1 and hi - lo > MIX_LENGTH_TOLERANCE then
			table.insert(
				problems,
				string.format("%s: mixes differ in length (%d..%d s) and would drift apart on loop", where, lo, hi)
			)
		end
	elseif set.kind == "playlist" then
		if set.tierToMix ~= nil then
			table.insert(problems, where .. ": a playlist has no tierToMix")
		end
	else
		table.insert(
			problems,
			string.format("%s: kind must be 'mixes' or 'playlist', got %s", where, tostring(set.kind))
		)
	end
end

-- Returns every problem found (empty = valid), in a stable order.
function CueCheck.validate(cues: any, manifest: any, audio: any): { string }
	local problems: { string } = {}
	if type(cues) ~= "table" or type(cues.cues) ~= "table" or type(cues.sets) ~= "table" then
		return { "cue module must have cues and sets tables" }
	end
	for _, name in sortedKeys(cues.cues) do
		checkCue(name, cues.cues[name], manifest, audio, problems)
	end
	for _, name in sortedKeys(cues.sets) do
		checkSet(name, cues.sets[name], manifest, problems)
	end
	if type(cues.states) == "table" then
		for _, name in sortedKeys(cues.states) do
			local st = cues.states[name]
			if type(st) ~= "table" or cues.sets[st.set] == nil then
				table.insert(problems, string.format("state %s: unknown set '%s'", name, tostring(st and st.set)))
			elseif st.xmas ~= nil and cues.sets[st.xmas] == nil then
				table.insert(problems, string.format("state %s: unknown Christmas set '%s'", name, tostring(st.xmas)))
			end
		end
	else
		table.insert(problems, "cue module must have a states table")
	end
	for _, name in audio.PRELOAD or {} do
		if cues.cues[name] == nil then
			table.insert(problems, string.format("Config.Audio.PRELOAD: unknown cue '%s'", tostring(name)))
		end
	end
	return problems
end

-- Counts for docs/AUDIO.md and the boot log.
function CueCheck.summary(cues: any): Summary
	local s: Summary = { cues = 0, withIds = 0, empty = {}, ids = 0, alternates = 0, sets = 0 }
	local used: { [number]: boolean } = {}
	local alts: { [number]: boolean } = {}
	local function add(list: any, into: { [number]: boolean })
		for _, id in list or {} do
			into[id] = true
		end
	end
	for _, name in sortedKeys(cues.cues) do
		local cue = cues.cues[name]
		s.cues += 1
		if #cue.ids > 0 then
			s.withIds += 1
		else
			table.insert(s.empty, name)
		end
		add(cue.ids, used)
		add(cue.alt, alts)
	end
	for _, name in sortedKeys(cues.sets) do
		s.sets += 1
		add(cues.sets[name].ids, used)
		add(cues.sets[name].alt, alts)
	end
	for _ in used do
		s.ids += 1
	end
	for id in alts do
		if not used[id] then
			s.alternates += 1
		end
	end
	return s
end

return CueCheck
