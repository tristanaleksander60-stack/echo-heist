-- Read-only funnel over every live profile (aggregates only, no user ids printed).
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("EH_Player_v1")
local function retry(fn)
	for i = 1, 8 do
		local ok, r = pcall(fn)
		if ok then
			return r
		end
		task.wait(8 * i)
	end
	error("gave up")
end
local pages = retry(function()
	return store:ListKeysAsync("", 50)
end)
local keys = {}
while true do
	for _, k in pages:GetCurrentPage() do
		table.insert(keys, k.KeyName)
	end
	if pages.IsFinished or #keys >= 200 then
		break
	end
	task.wait(1.5)
	retry(function()
		pages:AdvanceToNextPageAsync()
	end)
end
local n = 0
local ftue = {}
local levelPlays, levelClears = {}, {}
local badges = {}
local heists, clears = {}, {}
local created = {}
local topKeys = {}
local sample: any = nil
local t0 = os.clock()
for i, key in keys do
	if os.clock() - t0 > 200 then
		break
	end
	task.wait(0.9)
	local ok, rec = pcall(function()
		return store:GetAsync(key)
	end)
	if ok and type(rec) == "table" then
		n += 1
		local d = rec.Data or {}
		sample = sample or d
		for k in d do
			topKeys[k] = true
		end
		local h = d.Heist or d.heist or {}
		local step = h.ftueStep or -1
		ftue[step] = (ftue[step] or 0) + 1
		local st = h.stats or {}
		local hs = math.min(st.heists or 0, 10)
		heists[hs] = (heists[hs] or 0) + 1
		local cs = math.min(st.clears or 0, 10)
		clears[cs] = (clears[cs] or 0) + 1
		for lv, r in (h.levels or {}) do
			if type(r) == "table" then
				if (r.plays or 0) > 0 then
					levelPlays[lv] = (levelPlays[lv] or 0) + 1
				end
				if (r.clears or 0) > 0 then
					levelClears[lv] = (levelClears[lv] or 0) + 1
				end
			end
		end
		for b in (h.badges or {}) do
			badges[b] = (badges[b] or 0) + 1
		end
		local c = rec.Meta and rec.Meta.Created
		if c then
			local day = os.date("!%m-%d", c)
			created[day] = (created[day] or 0) + 1
		end
	end
end
local function dump(t)
	local out = {}
	for k, v in t do
		table.insert(out, tostring(k) .. "=" .. tostring(v))
	end
	table.sort(out)
	return table.concat(out, " ")
end
local hk = {}
if sample then
	local h = sample.Heist or sample.heist
	if type(h) == "table" then
		for k in h do
			table.insert(hk, k)
		end
	end
end
table.sort(hk)
return table.concat({
	"keys " .. #keys .. " profiles " .. n,
	"top: " .. dump(topKeys),
	"heist fields: " .. table.concat(hk, ","),
	"ftueStep: " .. dump(ftue),
	"stats.heists: " .. dump(heists),
	"stats.clears: " .. dump(clears),
	"level plays: " .. dump(levelPlays),
	"level clears: " .. dump(levelClears),
	"badges: " .. dump(badges),
	"created (UTC day): " .. dump(created),
}, "\n")
