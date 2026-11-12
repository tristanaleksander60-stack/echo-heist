--!strict
-- Heist/PresentPlan: the pure timing of the presentation shell (PLAN_STEAM_PLUS §3.4, §4.1 W7, §4.2 C2
-- + C4; premium G1, H1, H4), kept free of engine calls and requires so Lune tests it
-- (tests/unit/HeistPresent.spec.luau). Numbers come in as arguments (Config.Presentation at the call
-- sites). Times are seconds on one clock (os.clock() in the game); positions are level space { x, y, z }.
--   * Title beat: when each wordmark copy splits off and where it rests.
--   * revealAt: when the title fades off the closed van doors and the doors open. Control is the
--     server's (the run's transition ends): the doors are always open by then, so the title can cut
--     itself short but never delays control.
--   * controlWithin / bootControl: the "control within 10 s of the first frame" rule (G1).
--   * Gates: titleDue (first join), introKind (once per level per account, never L1), seenKinds (what a
--     saved profile has already seen).
--   * Level intro (C2): introStops (plates -> doors -> loot, the Party: Gus), introPlan (fits them
--     into the transition: drops stops rather than whip-pan) and introFocus (where the camera looks).

local PresentPlan = {}

export type V3 = { number }
export type IntroPlan = {
	stops: { V3 },
	hold: number, -- on the first stop
	hop: number, -- per hop between stops
	glide: number, -- hold + every hop: the camera is on the shot this long
	rest: number, -- what is left of the budget: the run-start beat holds on the last stop, then eases to you
}

PresentPlan.TITLE_KIND = "title"
PresentPlan.INTRO_PREFIX = "intro:"

---------------------------------------------------------------------------
-- Title beat
---------------------------------------------------------------------------

-- Copy k's resting offset (design px) behind the white mark: k steps down and right.
function PresentPlan.copyRest(k: number, step: { number }): (number, number)
	return k * step[1], k * step[2]
end

-- The split schedule from the beat's start: { [k] = start time of copy k's slide }, and the end of the beat.
function PresentPlan.titleSchedule(startAt: number, T: { SPLITS: { number }, SECONDS: number }): ({ number }, number)
	local out = {}
	for k, at in T.SPLITS do
		out[k] = startAt + at
	end
	return out, startAt + T.SECONDS
end

-- When the reveal starts (the title fades for `fade` s, then the doors open for `open` s), and whether
-- the beat is cut short. beatEnd nil = no title (fade should then be 0). controlAt nil = no deadline.
-- The doors are fully open at controlAt whenever that is still possible.
function PresentPlan.revealAt(
	now: number,
	beatEnd: number?,
	controlAt: number?,
	fade: number,
	open: number
): (number, boolean)
	local want = math.max(now, beatEnd or now)
	if controlAt then
		local latest = math.max(now, controlAt - fade - open)
		if want > latest then
			return latest, beatEnd ~= nil and latest < beatEnd
		end
	end
	return want, false
end

---------------------------------------------------------------------------
-- The 10-second rule (premium G1, MASTERPLAN §7.5)
---------------------------------------------------------------------------

-- Seconds from the first frame to control, and whether that is within the limit.
function PresentPlan.controlWithin(firstFrameAt: number, controlAt: number, limit: number): (boolean, number)
	local s = controlAt - firstFrameAt
	return s <= limit, s
end

-- A new account's boot, from the first frame (t = 0): the server's FTUE heist is ready at
-- `serverReady` and its first run gives control `transition` s later. The client's title beat (from
-- `titleStart`, nil = none) and the van doors overlap that wait. Returns control, when the doors are
-- fully open, and whether the title was cut short.
function PresentPlan.bootControl(o: {
	serverReady: number,
	transition: number,
	titleStart: number?,
	titleSeconds: number,
	fade: number,
	open: number,
}): (number, number, boolean)
	local control = o.serverReady + o.transition
	local beatEnd = if o.titleStart then o.titleStart + o.titleSeconds else nil
	local fade = if beatEnd then o.fade else 0
	local start, cut = PresentPlan.revealAt(o.serverReady, beatEnd, control, fade, o.open)
	return control, start + fade + o.open, cut
end

-- How long the server makes a new account wait before its first heist (HeistService.onPlayerAdded):
-- the profile, the first LiveFlags read and the art kit are awaited side by side, so a cold server
-- costs the longest of the three, not their sum.
function PresentPlan.serverWait(data: number, flags: number, kit: number): number
	return math.max(data, flags, kit)
end

---------------------------------------------------------------------------
-- Gates
---------------------------------------------------------------------------

-- Does this boot play the title beat? status: Heist/FirstTime's seeding ("pending" | "seeded" | "none");
-- seen: FirstTime.seen("title"); boot: what the server said first ("preparing", "garage", "heistFtue" =
-- the server started the FTUE level itself, "heist" = joining a crew's heist).
function PresentPlan.titleDue(status: string, seen: boolean, boot: string): boolean
	if seen then
		return false
	end
	if boot == "heistFtue" then
		return true -- the server autostarts L1 for a new account only
	end
	if boot == "heist" then
		return false -- never hold back someone joining a heist in progress
	end
	if status == "seeded" then
		return true -- a new account (the preparing wait, or the garage when every van was out)
	end
	-- No data at all: the server treats the player as new (HeistService.isNewAccount), so does the title.
	return status == "none" and boot == "preparing"
end

-- The once-per-account kind of a level's intro, or nil: never on the FTUE level (C2: never before first
-- control on L1; its first look is the title beat and the doors), never on a daily vault (no data key).
function PresentPlan.introKind(info: any, ftueLevelId: string, dataKeys: { [string]: string }): string?
	if type(info) ~= "table" or type(info.id) ~= "string" or info.id == ftueLevelId then
		return nil
	end
	local key = if type(info.dataKey) == "string" then info.dataKey else dataKeys[info.id]
	if type(key) ~= "string" then
		return nil
	end
	return PresentPlan.INTRO_PREFIX .. key
end

-- What a saved profile has already seen: "title" once the FTUE reached `titleStep` (the first move in
-- L1: the beat played before it) or any level was played, "intro:<key>" for every level record with a play.
function PresentPlan.seenKinds(snapshot: any, steps: { string }, titleStep: string): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local heist = if type(snapshot) == "table" then snapshot.heist else nil
	if type(heist) ~= "table" then
		return out
	end
	local index = table.find(steps, titleStep)
	if index and (tonumber(heist.ftueStep) or 0) >= index then
		out[PresentPlan.TITLE_KIND] = true
	end
	if type(heist.levels) == "table" then
		for key, rec in heist.levels do
			if type(key) == "string" and type(rec) == "table" and (tonumber(rec.plays) or 0) > 0 then
				out[PresentPlan.INTRO_PREFIX .. key] = true
				out[PresentPlan.TITLE_KIND] = true -- anyone who has played a level has joined before
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Level intro (C2)
---------------------------------------------------------------------------

local function centre(box: any, lift: number, top: boolean): V3
	local y = if top then box.maxY + lift else (box.minY + box.maxY) / 2
	return { (box.minX + box.maxX) / 2, y, (box.minZ + box.maxZ) / 2 }
end

-- The level's key objects in teaching order. Story levels: each door's plates, then the door (L2:
-- plate A -> door A -> plate B -> door B), then the top loot (CameraMath.objective's pick: top-flagged,
-- else the most valuable). The Party (`party`): Gus at his post (he dozes there), nothing else.
function PresentPlan.introStops(level: any, party: boolean, lift: number, maxStops: number): { V3 }
	local out: { V3 } = {}
	if type(level) ~= "table" then
		return out
	end
	if party then
		local g = level.guards and level.guards[1]
		local leg = g and g.route and g.route.legs and g.route.legs[1]
		if leg then
			table.insert(out, { leg.x0, (level.floorY or 0) + (level.rootHeight or 3), leg.z0 })
		end
		return out
	end
	local platesSeen: { [number]: boolean } = {}
	for _, door in level.doors or {} do
		for _, src in door.openBy or {} do
			local plate = src.kind == "plate" and level.plates and level.plates[src.index]
			if plate and not platesSeen[src.index] then
				platesSeen[src.index] = true
				table.insert(out, centre(plate.box, lift, true))
			end
		end
		table.insert(out, centre(door.box, lift, false))
	end
	local best: any = nil
	for _, item in level.loot or {} do
		local top, bestTop = item.top == true, best ~= nil and best.top == true
		if best == nil or (top and not bestTop) or (top == bestTop and (item.value or 0) > (best.value or 0)) then
			best = item
		end
	end
	if best then
		table.insert(out, { best.x, best.y or 3, best.z })
	end
	while #out > maxStops do
		table.remove(out, #out - 1) -- keep the loot last
	end
	return out
end

-- n stops of `stops`, the first and the last always among them, the rest evenly spread.
function PresentPlan.pickStops(stops: { V3 }, n: number): { V3 }
	local total = #stops
	if n >= total then
		return table.clone(stops)
	end
	if n <= 1 then
		return if total > 0 then { stops[1] } else {}
	end
	local out = {}
	for j = 1, n do
		local i = 1 + math.floor((j - 1) * (total - 1) / (n - 1) + 0.5)
		out[j] = stops[i]
	end
	return out
end

-- Fits the stops into `budget` s (the run's transition): the camera holds on the first stop, hops
-- stop to stop, and leaves at least I.EASE_BACK for the run-start beat back to you. Drops middle stops
-- before any hop gets shorter than I.HOP_MIN. nil when not even one stop fits.
function PresentPlan.introPlan(
	stops: { V3 },
	budget: number,
	I: { HOLD: number, HOP: number, HOP_MIN: number, EASE_BACK: number, MAX_STOPS: number }
): IntroPlan?
	if #stops == 0 then
		return nil
	end
	local room = budget - I.EASE_BACK
	if room < I.HOLD then
		return nil
	end
	local n = math.min(#stops, I.MAX_STOPS)
	while n > 1 and (room - I.HOLD) / (n - 1) < I.HOP_MIN do
		n -= 1
	end
	local picked = PresentPlan.pickStops(stops, n)
	if n == 1 then
		return { stops = picked, hold = room, hop = 0, glide = room, rest = budget - room }
	end
	local hop = math.min(I.HOP, (room - I.HOLD) / (n - 1))
	local glide = I.HOLD + hop * (n - 1)
	return { stops = picked, hold = I.HOLD, hop = hop, glide = glide, rest = budget - glide }
end

-- Sine InOut, 0..1 (premium H1: every camera move is a motivated ease).
function PresentPlan.ease(u: number): number
	local x = math.clamp(u, 0, 1)
	return 0.5 - 0.5 * math.cos(math.pi * x)
end

-- Where the intro camera looks `t` s into the plan.
function PresentPlan.introFocus(plan: IntroPlan, t: number): V3
	local stops = plan.stops
	local n = #stops
	if n == 1 or t <= plan.hold or plan.hop <= 0 then
		return stops[1]
	end
	local u = (t - plan.hold) / plan.hop
	local i = math.floor(u)
	if i >= n - 1 then
		return stops[n]
	end
	local a, b = stops[i + 1], stops[i + 2]
	local s = PresentPlan.ease(u - i)
	return { a[1] + (b[1] - a[1]) * s, a[2] + (b[2] - a[2]) * s, a[3] + (b[3] - a[3]) * s }
end

return table.freeze(PresentPlan)
