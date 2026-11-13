-- Audio engine check: runs INSIDE a real Roblox server through Open Cloud Luau Execution (docs/AUDIO.md
-- "Live load check"). Takedowns and permission problems are silent in Roblox, so this loads every Audio/Manifest
-- id into a throwaway AudioPlayer (Audio/LoadCheck), then checks, per cue and per music set of Audio/Cues:
--   - every cue or set with ids has at least one take that loads (so nothing that should sound is silent);
--   - every take and alternate loads, and the engine length agrees with the store's (warn only);
--   - a sample of ids answers MarketplaceService:GetProductInfoAsync with a licensed creator (Manifest).
-- Run: ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 \
--      --place 70772627070328 --script tests/audio_engine.luau --timeout 180   (add --version N to skip publishing)
-- Lines start with "ok", "FAIL", "warn" or "info"; tools/cloud_test.py exits 1 when any says FAIL.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Audio")
local Cues = require(Audio:WaitForChild("Cues"))
local Manifest = require(Audio:WaitForChild("Manifest"))
local LoadCheck = require(Audio:WaitForChild("LoadCheck"))

local LOAD_TIMEOUT = 45 -- seconds for the whole manifest (185 ids loaded 87/87 in under 10 s on Saved v76)
local INFO_SAMPLE = 12 -- GetProductInfoAsync calls (rate limited): the first take of this many cues

local results = {}
local failures = 0
local function check(cond: any, msg: string)
	if cond then
		table.insert(results, "ok    " .. msg)
	else
		failures += 1
		table.insert(results, "FAIL  " .. msg)
	end
end

local report = LoadCheck.run(LOAD_TIMEOUT)
local failed: { [number]: boolean } = {}
for _, id in report.failed do
	failed[id] = true
end
local total = 0
for _ in Manifest.assets do
	total += 1
end
table.insert(results, "info  " .. (string.split(report.text, "\n")[1] or ""))
check(#report.failed == 0, string.format("every manifest id loads (%d/%d)", report.ok, total))
for _, id in report.failed do
	local e = Manifest.assets[id]
	table.insert(results, string.format("FAIL  id %d not ready (%s)", id, if e then e.title else "?"))
end
for id, seconds in report.lengths do
	local want = Manifest.assets[id].seconds
	if math.abs(seconds - want) > 1.5 then
		table.insert(results, string.format("warn  id %d: store %d s, engine %.2f s", id, want, seconds))
	end
end

-- Per cue / set: at least one take loads, and say how many.
local function sortedKeys(t: { [string]: any }): { string }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	return keys
end

local withIds, silent = 0, {}
local function checkList(kind: string, name: string, ids: { number })
	if #ids == 0 then
		table.insert(silent, name)
		return
	end
	withIds += 1
	local loaded = 0
	for _, id in ids do
		if report.lengths[id] ~= nil and not failed[id] then
			loaded += 1
		end
	end
	check(loaded >= 1, string.format("%s %s: %d/%d takes load", kind, name, loaded, #ids))
end
for _, name in sortedKeys(Cues.cues) do
	checkList("cue", name, Cues.cues[name].ids)
end
for _, name in sortedKeys(Cues.sets) do
	checkList("set", name, Cues.sets[name].ids)
end
table.insert(
	results,
	string.format("info  %d cues/sets with ids; still empty: %s", withIds, table.concat(silent, ", "))
)

-- The store answers for a sample of first takes with the licensed creator the manifest names.
local asked = 0
for _, name in sortedKeys(Cues.cues) do
	local cue = Cues.cues[name]
	if asked >= INFO_SAMPLE then
		break
	end
	local id = cue.ids[1]
	if id ~= nil then
		asked += 1
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)
		end)
		local creatorId = if ok and info and info.Creator then info.Creator.CreatorTargetId else nil
		check(
			ok and Manifest.LICENSED_CREATORS[creatorId] ~= nil and creatorId == Manifest.assets[id].creatorId,
			string.format("cue %s take %d: store creator %s", name, id, tostring(creatorId))
		)
	end
end

table.insert(results, string.format("%d failure(s)", failures))
return table.concat(results, "\n")
