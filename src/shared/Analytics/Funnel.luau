--!strict
-- Analytics/Funnel: funnel step ordering (pure; Lune-tested). MASTERPLAN §7.5; vault
-- "Measuring Onboarding" and "Analytics and Funnels" §5.
--
-- Roblox rules this has to respect: only the first instance of a step counts, and when a later
-- step is logged every skipped earlier step counts as complete. So:
--   * forward-only: a step at or below the highest logged step is never sent;
--   * a step listed in `requires` waits (is held) until the steps it needs were reached, then it
--     is sent right after them (Minute10 waits for SwarmSeen, so a slow player's 10-minute mark
--     cannot mark the SwarmSeen KPI as done);
--   * a returning player is seeded from the saved profile step (HeistService saves the funnel
--     index with DataService.setFtueStep), so earlier sessions are not re-sent.
-- Recurring funnels (heist_v1, store_v1, clip_v1, ret_*) keep one forward-only cursor per session id.

local Events = require("./Events")

export type OneTime = {
	name: string,
	steps: { string },
	requires: { [number]: { number } },
	reached: { [number]: boolean },
	maxLogged: number,
	pending: { number }, -- reached, not yet sent (held), ascending
}

export type Session = { funnel: string, id: string, maxLogged: number, opened: number }

local Funnel = {}

local function def(name: string): Events.FunnelDef
	local f = Events.FUNNELS[name]
	assert(f ~= nil, "Funnel: unknown funnel " .. tostring(name))
	return f
end

function Funnel.oneTime(name: string): OneTime
	local f = def(name)
	local requires: { [number]: { number } } = {}
	for step, reqs in f.requires or {} do
		local n = table.find(f.steps, step) :: number
		local list = {}
		for _, r in reqs do
			table.insert(list, table.find(f.steps, r) :: number)
		end
		requires[n] = list
	end
	return { name = name, steps = f.steps, requires = requires, reached = {}, maxLogged = 0, pending = {} }
end

local function ready(t: OneTime, n: number): boolean
	for _, r in t.requires[n] or {} do
		if not t.reached[r] then
			return false
		end
	end
	return true
end

-- Sends what can be sent from the pending list (ascending), keeps held steps above the cursor.
local function process(t: OneTime): { number }
	local out: { number } = {}
	local keep: { number } = {}
	table.sort(t.pending)
	for _, p in t.pending do
		if p <= t.maxLogged then
			continue -- already implied by a later step
		elseif ready(t, p) then
			table.insert(out, p)
			t.maxLogged = p
		else
			table.insert(keep, p)
		end
	end
	-- a held step below the new cursor can no longer be sent (implied complete)
	local still: { number } = {}
	for _, p in keep do
		if p > t.maxLogged then
			table.insert(still, p)
		end
	end
	t.pending = still
	return out
end

-- Marks steps 1..upTo as reached and sent (an earlier session got there). Never moves back.
-- Returns held steps this releases (a late profile can satisfy a requirement).
function Funnel.seed(t: OneTime, upTo: number): { number }
	local n = math.clamp(math.floor(upTo), 0, #t.steps)
	for i = 1, n do
		t.reached[i] = true
	end
	if n > t.maxLogged then
		t.maxLogged = n
	end
	return process(t)
end

-- Records that the player reached `step` (a name or a number). Returns the step numbers to send
-- now, in order (empty when it is a repeat, below the cursor, or held). Errors on unknown names.
function Funnel.reach(t: OneTime, step: string | number): { number }
	local n = if type(step) == "number" then step else table.find(t.steps, step)
	assert(type(n) == "number" and t.steps[n] ~= nil, `Funnel.reach: {t.name} has no step {step}`)
	if t.reached[n] then
		return {}
	end
	t.reached[n] = true
	table.insert(t.pending, n)
	return process(t)
end

function Funnel.isReached(t: OneTime, step: string): boolean
	local n = table.find(t.steps, step)
	return n ~= nil and t.reached[n] == true
end

function Funnel.held(t: OneTime): { string }
	local out = {}
	for _, p in t.pending do
		table.insert(out, t.steps[p])
	end
	return out
end

---------------------------------------------------------------------------
-- Recurring funnels
---------------------------------------------------------------------------

function Funnel.session(funnelName: string, id: string, opened: number): Session
	def(funnelName)
	assert(type(id) == "string" and #id > 0 and #id <= 64, "Funnel.session: id must be 1-64 chars")
	return { funnel = funnelName, id = id, maxLogged = 0, opened = opened }
end

-- The step number to send for this session, or nil (repeat or backwards). Errors on unknown steps.
function Funnel.advance(s: Session, step: string): number?
	local n = Events.stepNumber(s.funnel, step)
	assert(n ~= nil, `Funnel.advance: {s.funnel} has no step {step}`)
	if n <= s.maxLogged then
		return nil
	end
	s.maxLogged = n
	return n
end

return table.freeze(Funnel)
