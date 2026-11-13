--!strict
-- Data/HaulBoardService: "today's biggest haul" on this server (LOBBY 2; MASTERPLAN §5.3 D1 "server board at
-- launch", §8.7; docs/DATA.md "Boards"). The rules are Shared/Data/HaulBoard (pure, Lune-tested); this keeps one
-- board for the server day and publishes it for the hideout laptop.
--
--   HaulBoardService.submit(userId, name, vaultDay, result) -> (boolean, number?)   a daily result from the heist
--       server (the sim's result().daily: haul, clones, timeMs, tainted, relaxed). Only HaulBoard.eligible runs
--       count: today's vault, untainted (Validator, §8.8), not Relaxed, a haul. Returns changed, rank.
--   HaulBoardService.seed(userId, name, daily)        a joining player's saved entry for today (profile `daily`:
--       haulDay / haulBest / haulClones / haulTimeMs, written only for untainted, non-Relaxed runs of today's vault)
--   HaulBoardService.top(n?) -> { Entry }, rankOf(userId) -> (rank?, entry?), day() -> number
--
-- Backend: server-local memory (the data layer has no MemoryStore yet; the per-server board is MASTERPLAN's launch
-- scope). A global board (LiveFlag globalBoard, Dec 11) plugs in behind the same calls (a MemoryStore sorted map
-- cache over a daily OrderedDataStore); the laptop reads only what is published here.
-- Published: ReplicatedStorage.EH_HaulBoard (a Folder; server-written attributes): Day, Rows (HaulBoard.encode of the
-- top Config.Data.Board.KEEP), Count. Every call is pcall-safe for the caller and never yields: the lobby never waits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local DataShared = Shared:WaitForChild("Data")
local Calendar = require(DataShared:WaitForChild("Calendar"))
local HaulBoard = require(DataShared:WaitForChild("HaulBoard"))

local B = Config.Data.Board

local HaulBoardService = {}

HaulBoardService.FOLDER = "EH_HaulBoard"

local function today(): number
	return Calendar.dayIndex(os.time(), Config.Data.Daily.RESET_OFFSET_HOURS)
end

local board = HaulBoard.new(today())
local lastPublish = -math.huge
local publishQueued = false

local function folder(): Folder
	local f = ReplicatedStorage:FindFirstChild(HaulBoardService.FOLDER)
	if f and f:IsA("Folder") then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = HaulBoardService.FOLDER
	made.Parent = ReplicatedStorage
	return made
end

local function publishNow()
	publishQueued = false
	lastPublish = os.clock()
	local f = folder()
	f:SetAttribute("Day", board.day)
	f:SetAttribute("Rows", HaulBoard.encode(HaulBoard.top(board, B.KEEP)))
	f:SetAttribute("Count", #board.entries)
end

-- At most one write per PUBLISH_MIN_SECONDS (a burst of results is one write).
local function publish()
	if publishQueued then
		return
	end
	local wait = B.PUBLISH_MIN_SECONDS - (os.clock() - lastPublish)
	if wait <= 0 then
		publishNow()
		return
	end
	publishQueued = true
	task.delay(wait, publishNow)
end

-- A new server day empties the board (checked on every call).
local function roll()
	local d = today()
	if d ~= board.day then
		board = HaulBoard.new(d)
		publish()
	end
end

function HaulBoardService.submit(userId: number, name: string, vaultDay: number, result: any): (boolean, number?)
	roll()
	if not HaulBoard.eligible(result, vaultDay, board.day) then
		return false, (HaulBoard.rankOf(board, userId))
	end
	local changed, rank = HaulBoard.submit(board, board.day, userId, name, result)
	if changed then
		publish()
	end
	return changed, rank
end

function HaulBoardService.seed(userId: number, name: string, daily: any)
	roll()
	if type(daily) ~= "table" or daily.haulDay ~= board.day then
		return
	end
	local run = {
		cleared = true,
		haul = daily.haulBest,
		clones = daily.haulClones,
		timeMs = daily.haulTimeMs,
		tainted = false, -- the profile keeps only untainted, non-Relaxed runs of today's vault (DailyVault.apply)
		relaxed = false,
	}
	HaulBoardService.submit(userId, name, board.day, run)
end

function HaulBoardService.top(n: number?): { HaulBoard.Entry }
	roll()
	return HaulBoard.top(board, n)
end

function HaulBoardService.rankOf(userId: number): (number?, HaulBoard.Entry?)
	roll()
	return HaulBoard.rankOf(board, userId)
end

function HaulBoardService.day(): number
	return board.day
end

-- Tests only: an empty board for `day` (default today), published at once.
function HaulBoardService.resetForTest(day: number?)
	board = HaulBoard.new(day or today())
	publishNow()
end

-- Publishes the (empty) board so the laptop finds the folder.
function HaulBoardService.start()
	publishNow()
end

return HaulBoardService
