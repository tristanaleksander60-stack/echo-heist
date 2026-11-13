--!strict
-- Data/HaulBoard: "today's biggest haul" for the daily vault as pure rules (LOBBY 2; MASTERPLAN §5.3 D1, §8.7;
-- docs/DATA.md "Boards"). Lune-tested (tests/unit/DataHaulBoard.spec.luau). The server's Data/HaulBoardService keeps
-- one board per server day and publishes its rows; the hideout laptop (client Hud/Garage) decodes and shows them.
--
--   * Only untainted, non-Relaxed runs of TODAY's vault with a haul board (HaulBoard.eligible): the Validator's taint
--     (§8.8) keeps a clamped run off the board, as it keeps it off medals.
--   * Order (DailyVault.beatsBoard): the bigger haul, then fewer clones, then less time; an exact tie keeps the
--     earlier entry. One entry per player, replaced only when the new run beats it.
--   * A new server day starts an empty board.
--   * Kid-safe: an entry is numbers plus the player's Roblox display name (no free text anywhere); the wire format
--     strips the separators out of names.

local Config = require("../Config")
local DailyVault = require("./DailyVault")

local B = Config.Data.Board

local HaulBoard = {}

export type Entry = {
	userId: number,
	name: string,
	haul: number,
	clones: number,
	timeMs: number,
	seq: number, -- submit order (an exact tie keeps the earlier entry)
}
export type Board = { day: number, entries: { Entry }, seq: number }

function HaulBoard.new(day: number): Board
	return { day = day, entries = {}, seq = 0 }
end

-- Does a daily result go on today's board? result = the sim's result().daily ({ haul, clones, timeMs, tainted,
-- relaxed, ... }); vaultDay = the vault played; today = the server day.
function HaulBoard.eligible(result: any, vaultDay: number, today: number): boolean
	if type(result) ~= "table" or vaultDay ~= today then
		return false
	end
	if not DailyVault.validateResult(result) then
		return false -- the daily award's own shape check: flags are booleans, numbers whole and in range
	end
	return result.tainted == false and result.relaxed == false and result.haul >= 1
end

-- A display name as the board shows it: no separators, at most NAME_MAX characters, never empty.
function HaulBoard.cleanName(name: any): string
	local s = if type(name) == "string" then name else ""
	s = string.gsub(s, "[;|,%c]", "")
	if utf8.len(s) == nil then
		s = string.gsub(s, "[\128-\255]", "")
	end
	local n = utf8.len(s) or #s
	if n > B.NAME_MAX then
		local cut = utf8.offset(s, B.NAME_MAX + 1)
		s = if cut then string.sub(s, 1, cut - 1) else string.sub(s, 1, B.NAME_MAX)
	end
	return if s == "" then "?" else s
end

-- Does a come before b on the board?
function HaulBoard.before(a: Entry, b: Entry): boolean
	if DailyVault.beatsBoard(a, b) then
		return true
	end
	if DailyVault.beatsBoard(b, a) then
		return false
	end
	return a.seq < b.seq
end

-- 1-based rank of a user (nil = not on the board) and their entry.
function HaulBoard.rankOf(board: Board, userId: number): (number?, Entry?)
	for i, e in board.entries do
		if e.userId == userId then
			return i, e
		end
	end
	return nil, nil
end

-- Submits a run (call HaulBoard.eligible first). day = the server day now: a new day empties the board first.
-- Returns changed (the board moved), rank (the player's rank after it; nil = below KEEP).
function HaulBoard.submit(
	board: Board,
	day: number,
	userId: number,
	name: any,
	run: { haul: number, clones: number, timeMs: number }
): (boolean, number?)
	if day ~= board.day then
		board.day = day
		table.clear(board.entries)
	end
	local _, mine = HaulBoard.rankOf(board, userId)
	board.seq += 1
	local entry: Entry = {
		userId = userId,
		name = HaulBoard.cleanName(name),
		haul = run.haul,
		clones = run.clones,
		timeMs = run.timeMs,
		seq = board.seq,
	}
	if mine then
		if not DailyVault.beatsBoard(entry, mine) then
			if mine.name ~= entry.name then
				mine.name = entry.name -- a renamed player keeps their entry
				return true, (HaulBoard.rankOf(board, userId))
			end
			return false, (HaulBoard.rankOf(board, userId))
		end
		local i = table.find(board.entries, mine)
		if i then
			table.remove(board.entries, i)
		end
	end
	table.insert(board.entries, entry)
	table.sort(board.entries, HaulBoard.before)
	while #board.entries > B.KEEP do
		table.remove(board.entries)
	end
	return true, (HaulBoard.rankOf(board, userId))
end

-- The first n entries (default Config.Data.Board.SHOW).
function HaulBoard.top(board: Board, n: number?): { Entry }
	local out = {}
	for i = 1, math.min(n or B.SHOW, #board.entries) do
		table.insert(out, board.entries[i])
	end
	return out
end

-- Wire format for the published rows (a string attribute): "userId,haul,clones,timeMs,name;..." in rank order.
function HaulBoard.encode(entries: { Entry }): string
	local parts = {}
	for _, e in entries do
		table.insert(
			parts,
			string.format("%d,%d,%d,%d,%s", e.userId, e.haul, e.clones, e.timeMs, HaulBoard.cleanName(e.name))
		)
	end
	return table.concat(parts, ";")
end

-- The rows back (rank order kept; a malformed row is skipped). seq = the row's rank.
function HaulBoard.decode(text: any): { Entry }
	local out: { Entry } = {}
	if type(text) ~= "string" or text == "" then
		return out
	end
	for _, row in string.split(text, ";") do
		local f = string.split(row, ",")
		local uid, haul, clones, ms = tonumber(f[1]), tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
		if #f == 5 and uid and haul and clones and ms then
			table.insert(out, {
				userId = uid,
				name = HaulBoard.cleanName(f[5]),
				haul = haul,
				clones = clones,
				timeMs = ms,
				seq = #out + 1,
			})
		end
	end
	return out
end

return table.freeze(HaulBoard)
