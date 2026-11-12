--!strict
-- Heist/CrewBoard: the pure rules behind the Crew Board UI (PLAN_STEAM_PLUS §3.2, §4.3 U4-U6;
-- WALKTHROUGH P0-3 full deck and S7 stars; premium D10 count-ups). No engine calls (Lune reads it:
-- tests/unit/HeistCrewBoard.spec.luau); the client HUD (Hud/Deck, Hud/Results, Hud/Garage, Hud/TopBar)
-- draws what these return.
--   * count-up maths: 0.35 s + 0.08 s per digit, cap 1.0 s, Quad Out (Config.Ui.COUNT_UP);
--   * a crew card's last action, from its deck status and its recording (pressed plate A, carried
--     cash, BUSTED, zapped, stuck);
--   * the full deck: which card pulses (the first that ended off every plate), which clone a run
--     replaced, and the no-progress counter that offers START OVER;
--   * the job sheet's stamp reasons with the level's real numbers, and which are still unseen;
--   * the job board: the NEXT job (the same rule as the 3D board's card, Heist/JobCard) and where each
--     pinned photo sits.

local Config = require("../Config")
local Codec = require("../Rec/Codec")
local Strings = require("./Strings")

local CU = Config.Ui.COUNT_UP

local CrewBoard = {}

---------------------------------------------------------------------------
-- Numbers
---------------------------------------------------------------------------

-- "$1,000" (the same text as the client's Ui.money).
function CrewBoard.money(n: number): string
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (if n < -0.5 then "-$" else "$") .. out
end

-- Digits of a whole change (0 -> 0, 7 -> 1, 900 -> 3).
function CrewBoard.digits(n: number): number
	local whole = math.floor(math.abs(n) + 0.5)
	return if whole == 0 then 0 else #tostring(whole)
end

-- How long a count from `from` to `to` runs (premium D10: 0.35-1.0 s).
function CrewBoard.countSeconds(from: number, to: number): number
	return math.clamp(CU.BASE + CU.PER_DIGIT * CrewBoard.digits(to - from), CU.BASE, CU.MAX)
end

-- The whole number shown `elapsed` s into a count (Quad Out; exactly `to` from `seconds` on).
function CrewBoard.countValue(from: number, to: number, elapsed: number, seconds: number): number
	if seconds <= 0 or elapsed >= seconds then
		return to
	end
	local u = math.clamp(elapsed / seconds, 0, 1)
	local eased = 1 - (1 - u) * (1 - u)
	local v = from + (to - from) * eased
	return if to >= from then math.floor(v) else math.ceil(v)
end

---------------------------------------------------------------------------
-- Crew cards
---------------------------------------------------------------------------

export type Action = {
	kind: string, -- "busted" | "zapped" | "stuck" | "plate" | "cash" | "walk"
	icon: string, -- Heist/Icons name
	word: string, -- the card's caption (Strings)
	plate: string?, -- the plate's letter ("plate" only)
	red: boolean, -- a red-flagged clone (grey frame, stamp across the photo)
}

local ICON = table.freeze({
	busted = "gus",
	zapped = "bolt",
	stuck = "cross",
	plate = "plate",
	cash = "loot",
	walk = "clone",
})

-- The letter a plate shows (its id when that is a short label, else A, B, C... by index).
function CrewBoard.plateLetter(plate: any, index: number): string
	local id = plate and plate.id
	if type(id) == "string" and #id >= 1 and #id <= 2 then
		return string.upper(id)
	end
	return string.char(64 + math.clamp(index, 1, 26))
end

-- The plate a recording ends on (its last sample inside a plate's trigger box): index, letter.
-- rec = Codec.Recording (level-local positions), level = a compiled LevelSpec (plates[i].box).
function CrewBoard.endPlate(rec: any, level: any): (number?, string?)
	if type(rec) ~= "table" or type(level) ~= "table" or (rec.n or 0) < 1 then
		return nil, nil
	end
	local i = rec.n
	local x, y, z = rec.px[i], rec.py[i], rec.pz[i]
	for k, p in level.plates or {} do
		local b = p.box
		if b and x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY and z >= b.minZ and z <= b.maxZ then
			return k, CrewBoard.plateLetter(p, k)
		end
	end
	return nil, nil
end

-- Did the recording pick loot up?
function CrewBoard.grabbed(rec: any): boolean
	if type(rec) ~= "table" then
		return false
	end
	for _, e in rec.events or {} do
		if e.kind == Codec.EVENT.Grab then
			return true
		end
	end
	return false
end

-- What a clone did last, for its card. Outcomes first (the deck status the server decided), then
-- where its run ended: on a plate (it holds a door), else whether it carried cash, else it walked.
function CrewBoard.lastAction(status: string?, rec: any, level: any): Action
	local kind: string
	local plate: string? = nil
	if status == "Busted" or status == "Caught" then
		kind = "busted"
	elseif status == "Zapped" then
		kind = "zapped"
	elseif status == "Stuck" then
		kind = "stuck"
	else
		local _, letter = CrewBoard.endPlate(rec, level)
		if letter then
			kind, plate = "plate", letter
		elseif CrewBoard.grabbed(rec) then
			kind = "cash"
		else
			kind = "walk"
		end
	end
	local word = if plate then Strings.cardPlate(plate) else Strings.CARD_ACTION[kind]
	return {
		kind = kind,
		icon = ICON[kind],
		word = word,
		plate = plate,
		red = kind == "busted" or kind == "zapped" or kind == "stuck",
	}
end

-- Is the deck full (a new run replaces a clone)? Locked decks (L1, party) never are.
function CrewBoard.isFull(deck: any): boolean
	if type(deck) ~= "table" or deck.locked or deck.party then
		return false
	end
	local cap = tonumber(deck.cap) or 0
	return cap > 0 and #(deck.slots or {}) >= cap
end

-- The card to pulse on a full deck: the first clone whose run ended off every plate (it holds no
-- door, so it is the one to DELETE). nil when the deck is not full or every clone holds a plate.
-- recs = key -> Codec.Recording.
function CrewBoard.pulseSlot(deck: any, recs: { [any]: any }, level: any): number?
	if not CrewBoard.isFull(deck) then
		return nil
	end
	for i, s in deck.slots do
		local rec = recs[s.key]
		if rec and CrewBoard.endPlate(rec, level) == nil then
			return i
		end
	end
	return nil
end

-- The clone a run replaced: on a full deck with no REDO armed, the run's recording replaces the
-- newest slot (Sim/Deck.commit). `before` = the deck as it was when the run started.
function CrewBoard.replacedSlot(before: any): number?
	if not CrewBoard.isFull(before) then
		return nil
	end
	if (tonumber(before.redo) or 0) > 0 then
		return nil
	end
	return #before.slots
end

-- How many plates the deck's clones hold at the end of their runs (the REDO slot is re-recorded,
-- so it does not count).
function CrewBoard.platesHeld(deck: any, recs: { [any]: any }, level: any): number
	if type(deck) ~= "table" then
		return 0
	end
	local held: { [number]: boolean } = {}
	local n = 0
	for i, s in deck.slots or {} do
		if (tonumber(deck.redo) or 0) ~= i then
			local k = CrewBoard.endPlate(recs[s.key], level)
			if k and not held[k] then
				held[k] = true
				n += 1
			end
		end
	end
	return n
end

-- START OVER: runs in a row that got nowhere while the deck was full (no bank, no new plate held).
export type Progress = { best: number, idle: number }

function CrewBoard.newProgress(): Progress
	return { best = 0, idle = 0 }
end

-- One finished run. full = the deck was full when it ran; banked = $ banked in it; held = plates the
-- deck holds after it. Returns the no-progress run count.
function CrewBoard.noteRun(p: Progress, full: boolean, banked: number, held: number): number
	local progressed = banked > 0 or held > p.best
	p.best = math.max(p.best, held)
	if not full or progressed then
		p.idle = 0
	else
		p.idle += 1
	end
	return p.idle
end

function CrewBoard.offerStartOver(p: Progress, deck: any): boolean
	return CrewBoard.isFull(deck) and p.idle >= Config.Ui.START_OVER_RUNS
end

---------------------------------------------------------------------------
-- The job sheet
---------------------------------------------------------------------------

CrewBoard.STARS = table.freeze({ "haul", "crew", "clean" })
-- The settings key that remembers a star's reason was shown (Schema settings).
CrewBoard.SEEN_KEY = table.freeze({ haul = "seenStarHaul", crew = "seenStarCrew", clean = "seenStarClean" })

-- A star's rule with the level's real numbers: "HAUL: $1,000 stolen", "CREW: 2 clones or fewer",
-- "CLEAN: never caught". over = the results payload (goal, par).
function CrewBoard.stampReason(star: string, over: any): string
	if star == "haul" then
		return Strings.reasonHaul(CrewBoard.money(tonumber(over.goal) or 0))
	elseif star == "crew" then
		return Strings.reasonCrew(tonumber(over.par) or 0)
	end
	return Strings.REASON_CLEAN
end

-- Which stamps carry their reason: a story heist's stars until each has been earned once
-- (the reason is how to earn it). seen = settings-like table (seenStarHaul...).
function CrewBoard.reasonsToShow(over: any, seen: { [string]: any }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local kind = over.kind or "story"
	if kind == "party" then
		return out
	end
	for _, star in CrewBoard.STARS do
		out[star] = seen[CrewBoard.SEEN_KEY[star]] ~= true
	end
	return out
end

-- The seen flags to save after this sheet: a star earned with its reason showing is learnt.
function CrewBoard.newlySeen(over: any, shown: { [string]: boolean }): { string }
	local out = {}
	local stars = over.stars or {}
	for _, star in CrewBoard.STARS do
		if shown[star] and stars[star] == true then
			table.insert(out, CrewBoard.SEEN_KEY[star])
		end
	end
	return out
end

-- The goal lines of the sheet: { text, met } per star (story) or tier (party).
function CrewBoard.goalLines(over: any): { { text: string, met: boolean } }
	local lines = {}
	local stars = over.stars or {}
	if (over.kind or "story") == "party" then
		local met = stars.tiers or {}
		for i, tier in over.tiers or {} do
			table.insert(
				lines,
				{ text = Strings.lineTier(i, CrewBoard.money(tonumber(tier) or 0)), met = met[i] == true }
			)
		end
		return lines
	end
	local banked = tonumber(over.banked) or 0
	table.insert(lines, {
		text = Strings.lineHaul(CrewBoard.money(banked), CrewBoard.money(tonumber(over.goal) or 0)),
		met = stars.haul == true,
	})
	table.insert(lines, { text = Strings.lineCrew(tonumber(over.clonesUsed) or 0), met = stars.crew == true })
	table.insert(lines, {
		text = if stars.clean == true then Strings.LINE_CLEAN else Strings.LINE_CAUGHT,
		met = stars.clean == true,
	})
	return lines
end

---------------------------------------------------------------------------
-- The job board
---------------------------------------------------------------------------

-- The NEXT job's Catalog index: the first unlocked level without a medal (Heist/JobCard.title's rule),
-- else nil (everything open is cleared).
function CrewBoard.nextJob(levels: { any }?): number?
	for _, lv in levels or {} do
		if lv.unlocked and #(lv.medals or {}) == 0 then
			return tonumber(lv.index)
		end
	end
	return nil
end

-- A job photo's colour band key: "party", "bk" (bank) or "cs" (corner shop).
function CrewBoard.location(lv: any): string
	if lv.kind == "party" then
		return "party"
	end
	local id = tostring(lv.id or "")
	return if string.sub(id, 1, 2) == "bk" then "bk" else "cs"
end

-- Where the k-th pinned photo sits on the board (top-left, design px) and the board's height.
function CrewBoard.boardSlot(k: number): (number, number)
	local B = Config.Ui.BOARD
	local col = (k - 1) % B.COLUMNS
	local row = (k - 1) // B.COLUMNS
	return B.GAP[1] + col * (B.CELL[1] + B.GAP[1]), B.GAP[2] + row * (B.CELL[2] + B.GAP[2])
end

function CrewBoard.boardHeight(n: number): number
	local B = Config.Ui.BOARD
	local rows = math.max(1, math.ceil(n / B.COLUMNS))
	return B.GAP[2] + rows * (B.CELL[2] + B.GAP[2])
end

-- The string between two pins: centre, length and rotation (degrees) of a straight segment.
function CrewBoard.segment(x0: number, y0: number, x1: number, y1: number): (number, number, number, number)
	local dx, dy = x1 - x0, y1 - y0
	return (x0 + x1) / 2, (y0 + y1) / 2, math.sqrt(dx * dx + dy * dy), math.deg(math.atan2(dy, dx))
end

---------------------------------------------------------------------------
-- Bank fly
---------------------------------------------------------------------------

-- A point on the quadratic arc from a to b that bulges `arc` px upwards, at u in 0..1.
function CrewBoard.arc(ax: number, ay: number, bx: number, by: number, arc: number, u: number): (number, number)
	local cx, cy = (ax + bx) / 2, math.min(ay, by) - arc
	local v = 1 - u
	return v * v * ax + 2 * v * u * cx + u * u * bx, v * v * ay + 2 * v * u * cy + u * u * by
end

return table.freeze(CrewBoard)
