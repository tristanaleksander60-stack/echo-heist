--!strict
-- Heist/FirstTime: "is this the first time?" for the first actions (premium G2, PLAN_STEAM_PLUS
-- §6.2: the first plate press, rewind, clone and bank each get a bigger first-time version) and
-- for one-off guidance (the finger pointer on REWIND / GRAB, the Party's dozing-Gus line).
--
--   FirstTime.firstTime(kind) -> boolean   true the first time a kind happens for this player,
--                                          and for every caller within FIRST_TIME_WINDOW s of
--                                          that first call (the world and the HUD both play the
--                                          bigger version of the same moment); false after
--   FirstTime.seen(kind) -> boolean        already happened (does not mark it)
--   FirstTime.markSeen(kind)               mark without playing (e.g. the kid did it unguided)
--   FirstTime.init()                       once, from HeistClient: seeds from the profile
--
-- Kinds: "step", "plate", "rewind", "clone", "bank" (the first five actions), "pointRewind",
-- "pointGrab" (the finger pointer), "gusDoze" (the Party intro line), "hideout" (the lobby's PICK A VAN hint);
-- the presentation shell's
-- "title" (the first-join title beat) and "intro:<data key>" (each level's first-look camera,
-- Heist/LevelIntro), both seeded by Heist/PresentPlan.seenKinds.
--   FirstTime.status() -> "pending" | "seeded" | "none"   the profile seeding (none: no data)
--   FirstTime.onStatus(fn)                                fn(status) when it leaves "pending"
-- Data.Snapshot answers NotReady while the profile loads: it is asked again
-- (Config.Presentation.SNAPSHOT_TRIES, 1/s: the remote's rate) before giving up.
-- Persistence: no new data. The profile's existing FTUE funnel index (heist.ftueStep, saved by the
-- server as each step happens: Heist/Protocol.FTUE_STEPS) and level records (heist.levels) seed it
-- through the existing Data.Snapshot remote: a returning player never sees a first-time beat
-- again. Without data (offline Studio, a failed request) it is per session.
-- TODO(onboarding): "pointRewind" is seeded from a Two Doors clear (the first level where the
-- player must tap REWIND); a real "tapped REWIND" flag needs a profile field if kids replay L2
-- without clearing it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Protocol = require(Shared:WaitForChild("Heist"):WaitForChild("Protocol"))
local Scenario = require(Shared:WaitForChild("Heist"):WaitForChild("Scenario"))
local Net = require(ReplicatedStorage:WaitForChild("LihFolk"):WaitForChild("Net"))
local PresentPlan = require(script.Parent:WaitForChild("PresentPlan"))

local O = Config.Onboarding
local P = Config.Presentation
local TITLE_STEP = "FirstMove" -- the title beat plays before the first move in L1
local REMOTES = "LihFolkRemotes"
local SNAPSHOT = "Data.Snapshot"

local FirstTime = {}

-- What seeds each kind from the profile: an FTUE step reached, or a level played / cleared.
local SEED: { [string]: { step: string?, level: string?, field: string? } } = {
	step = { step = "FirstMove" },
	plate = { step = "FirstPlate" },
	rewind = { step = "FirstRewind" },
	clone = { step = "FirstCloneSeen" },
	bank = { step = "FirstBank" },
	pointGrab = { step = "FirstBank" },
	pointRewind = { level = "TwoDoors", field = "clears" },
	gusDoze = { level = "CloneParty", field = "plays" },
	-- the hideout's first visit ("PICK A VAN" over a free van, Heist/Hideout): a player who has played Two Doors
	-- has been through the hideout before
	hideout = { level = "TwoDoors", field = "plays" },
}
FirstTime.KINDS = table.freeze((function()
	local out = {}
	for kind in SEED do
		table.insert(out, kind)
	end
	table.sort(out)
	return out
end)())

local seenSet: { [string]: boolean } = {}
local firstAt: { [string]: number } = {}
local started = false
local status = "pending"
local statusListeners: { (string) -> () } = {}

local function setStatus(s: string)
	if status ~= "pending" then
		return
	end
	status = s
	for _, fn in statusListeners do
		task.spawn(fn, s)
	end
	table.clear(statusListeners)
end

-- Seeds from a Data snapshot ({ heist = { ftueStep, levels } }); pure apart from the tables above.
function FirstTime.seed(snapshot: any)
	local heist = type(snapshot) == "table" and snapshot.heist or nil
	if type(heist) ~= "table" then
		return
	end
	local reached = tonumber(heist.ftueStep) or 0
	local levels = if type(heist.levels) == "table" then heist.levels else {}
	for kind, rule in SEED do
		local done = false
		if rule.step then
			local index = table.find(Protocol.FTUE_STEPS, rule.step)
			done = index ~= nil and reached >= index
		elseif rule.level then
			local rec = levels[rule.level]
			done = type(rec) == "table" and (tonumber(rec[rule.field or "plays"]) or 0) > 0
		end
		if done and firstAt[kind] == nil then
			seenSet[kind] = true
		end
	end
	for kind in PresentPlan.seenKinds(snapshot, Protocol.FTUE_STEPS, TITLE_STEP) do
		if firstAt[kind] == nil then
			seenSet[kind] = true
		end
	end
end

function FirstTime.init()
	if started then
		return
	end
	started = true
	if Scenario.resolve(RunService:IsStudio(), workspace:GetAttribute(Scenario.ATTRIBUTE)) == "TUTORIAL" then
		setStatus("none") -- Studio replay of the tutorial: every first-time beat again, whatever the profile says
		return
	end
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(REMOTES, 10)
		if not folder or not folder:WaitForChild(SNAPSHOT, 10) then
			setStatus("none")
			return -- no data service (offline Studio): per session
		end
		-- Studio without API access answers NotReady for good: one try there.
		local tries = if RunService:IsStudio() then 1 else P.SNAPSHOT_TRIES
		for try = 1, tries do
			local ok, res = pcall(Net.Request, SNAPSHOT)
			if ok and type(res) == "table" and res.ok then
				FirstTime.seed(res.data)
				setStatus("seeded")
				return
			end
			if try < tries then
				task.wait(P.SNAPSHOT_RETRY_SECONDS)
			end
		end
		setStatus("none")
	end)
end

function FirstTime.status(): string
	return status
end

function FirstTime.onStatus(fn: (string) -> ())
	if status ~= "pending" then
		task.spawn(fn, status)
	else
		table.insert(statusListeners, fn)
	end
end

function FirstTime.seen(kind: string): boolean
	return seenSet[kind] == true
end

function FirstTime.markSeen(kind: string)
	seenSet[kind] = true
end

function FirstTime.firstTime(kind: string): boolean
	local at = firstAt[kind]
	if at then
		return os.clock() - at <= O.FIRST_TIME_WINDOW
	end
	if seenSet[kind] then
		return false
	end
	firstAt[kind] = os.clock()
	seenSet[kind] = true
	return true
end

return FirstTime
