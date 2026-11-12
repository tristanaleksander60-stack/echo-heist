--!strict
-- Audio/Voices: the pure voice-allocation rules behind AudioDirector.play (lihfolk-sfx "Voice limits",
-- MASTERPLAN §7.2 clone bus). No clocks, no engine: the caller passes `now`, the voice length and, for the
-- round-robin bag, a random function. tests/unit/AudioVoices.spec covers every rule.
--
-- request() decides, in this order:
--   1. cooldown      a cue cannot start again within its cooldown ("cooldown")
--   2. clone rate    at most CLONE_MAX_PER_SECOND clone sounds start per rolling second ("cloneRate")
--   3. clone nearest at most CLONE_VOICED_NEAREST clone voices live; a nearer clone steals the farthest,
--                    a farther one is dropped ("cloneFar")
--   4. choke         a choking cue stops its own live voices first
--   5. per-cue cap   beyond maxVoices the oldest voices of the cue are cut
--   6. global cap    beyond maxVoices in total, the lowest priority (oldest first) voice at or below the new
--                    one's priority is stolen; if none, the new sound is dropped ("full")
-- The decision lists the voices to stop; the caller stops them and calls release() for each.

export type Voice = {
	serial: number,
	cue: string,
	priority: number,
	startedAt: number,
	endsAt: number, -- math.huge for loops
	clone: boolean,
	distance: number,
}

export type Bag = { queue: { number }, last: number? }

export type State = {
	maxVoices: number,
	cloneMaxPerSecond: number,
	cloneNearest: number,
	voices: { Voice },
	lastStart: { [string]: number },
	cloneStarts: { number },
	bags: { [string]: Bag },
	serial: number,
}

export type Request = {
	cue: string,
	now: number,
	length: number, -- seconds the voice will be busy (math.huge for loops)
	cooldown: number,
	maxPerCue: number,
	priority: number,
	choke: boolean?,
	clone: boolean?,
	distance: number?, -- studs from the listener (clones only; nil = treat as near)
}

export type Decision = {
	ok: boolean,
	reason: string?, -- "cooldown" | "cloneRate" | "cloneFar" | "full"
	stop: { Voice }, -- voices the caller must stop (and release) before starting
	voice: Voice?, -- the new voice (already registered as live)
}

local Voices = {}

function Voices.new(maxVoices: number, cloneMaxPerSecond: number, cloneNearest: number): State
	return {
		maxVoices = math.max(1, maxVoices),
		cloneMaxPerSecond = cloneMaxPerSecond,
		cloneNearest = cloneNearest,
		voices = {},
		lastStart = {},
		cloneStarts = {},
		bags = {},
		serial = 0,
	}
end

-- Drop voices whose one-shot has finished. Call before request() (request also calls it).
function Voices.expire(state: State, now: number)
	local kept = {}
	for _, v in state.voices do
		if v.endsAt > now then
			table.insert(kept, v)
		end
	end
	state.voices = kept
end

-- Forget one voice (it ended, or the caller stopped it). Unknown serials are ignored.
function Voices.release(state: State, serial: number)
	for i, v in state.voices do
		if v.serial == serial then
			table.remove(state.voices, i)
			return
		end
	end
end

-- Move a live voice's end (its asset loaded and turned out longer than the estimate). Returns false when
-- the voice is no longer tracked.
function Voices.extend(state: State, serial: number, endsAt: number): boolean
	for _, v in state.voices do
		if v.serial == serial then
			v.endsAt = endsAt
			return true
		end
	end
	return false
end

function Voices.live(state: State, cue: string?): number
	local n = 0
	for _, v in state.voices do
		if cue == nil or v.cue == cue then
			n += 1
		end
	end
	return n
end

local function contains(list: { Voice }, v: Voice): boolean
	return table.find(list, v) ~= nil
end

function Voices.request(state: State, req: Request): Decision
	local now = req.now
	Voices.expire(state, now)
	local stop: { Voice } = {}

	-- 1. cooldown
	local last = state.lastStart[req.cue]
	if last ~= nil and now - last < req.cooldown then
		return { ok = false, reason = "cooldown", stop = stop }
	end

	local isClone = req.clone == true
	local distance = req.distance or 0
	if isClone then
		-- 2. clone rate (rolling one second)
		local recent = {}
		for _, t in state.cloneStarts do
			if now - t < 1 then
				table.insert(recent, t)
			end
		end
		state.cloneStarts = recent
		if #recent >= state.cloneMaxPerSecond then
			return { ok = false, reason = "cloneRate", stop = stop }
		end
		-- 3. nearest N clone voices
		local cloneVoices = {}
		for _, v in state.voices do
			if v.clone then
				table.insert(cloneVoices, v)
			end
		end
		if #cloneVoices >= state.cloneNearest then
			local farthest: Voice? = nil
			for _, v in cloneVoices do
				if farthest == nil or v.distance > farthest.distance then
					farthest = v
				end
			end
			if farthest and farthest.distance > distance then
				table.insert(stop, farthest)
			else
				return { ok = false, reason = "cloneFar", stop = {} }
			end
		end
	end

	-- 4. choke / 5. per-cue cap (oldest first)
	local own = {}
	for _, v in state.voices do
		if v.cue == req.cue and not contains(stop, v) then
			table.insert(own, v)
		end
	end
	table.sort(own, function(a: Voice, b: Voice): boolean
		return a.startedAt < b.startedAt or (a.startedAt == b.startedAt and a.serial < b.serial)
	end)
	if req.choke then
		for _, v in own do
			table.insert(stop, v)
		end
	else
		local extra = #own + 1 - math.max(1, req.maxPerCue)
		for i = 1, math.min(extra, #own) do
			table.insert(stop, own[i])
		end
	end

	-- 6. global cap with priority stealing
	local liveAfter = #state.voices - #stop
	if liveAfter >= state.maxVoices then
		local victim: Voice? = nil
		for _, v in state.voices do
			if v.priority <= req.priority and not contains(stop, v) then
				if
					victim == nil
					or v.priority < victim.priority
					or (v.priority == victim.priority and v.startedAt < victim.startedAt)
				then
					victim = v
				end
			end
		end
		if victim == nil then
			return { ok = false, reason = "full", stop = {} }
		end
		table.insert(stop, victim)
	end

	for _, v in stop do
		Voices.release(state, v.serial)
	end
	state.serial += 1
	local voice: Voice = {
		serial = state.serial,
		cue = req.cue,
		priority = req.priority,
		startedAt = now,
		endsAt = now + math.max(0.05, req.length),
		clone = isClone,
		distance = distance,
	}
	table.insert(state.voices, voice)
	state.lastStart[req.cue] = now
	if isClone then
		table.insert(state.cloneStarts, now)
	end
	return { ok = true, stop = stop, voice = voice }
end

-- Round-robin bag over n takes: shuffled, drawn without replacement, never the same take twice in a row.
-- random(m) returns an integer in 1..m (Random:NextInteger in the client, a seeded stub in tests).
function Voices.nextTake(state: State, key: string, n: number, random: (m: number) -> number): number
	if n <= 1 then
		return 1
	end
	local bag = state.bags[key]
	if bag == nil or #bag.queue > n then
		bag = { queue = {}, last = nil }
		state.bags[key] = bag
	end
	local b = bag :: Bag
	if #b.queue == 0 then
		local q = table.create(n)
		for i = 1, n do
			q[i] = i
		end
		for i = n, 2, -1 do
			local j = random(i)
			q[i], q[j] = q[j], q[i]
		end
		-- the queue is drawn from its end: never repeat the previous bag's last draw
		if q[n] == b.last then
			q[1], q[n] = q[n], q[1]
		end
		b.queue = q
	end
	local take = table.remove(b.queue) :: number
	b.last = take
	return take
end

return Voices
