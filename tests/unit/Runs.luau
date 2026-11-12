-- Synthetic run fixtures for the L1 specs (not a spec itself). These are logic
-- fixtures only; golden level solutions are human-recorded (MASTERPLAN §8.9).

local Codec = require("../../src/shared/Rec/Codec")
local Sampler = require("../../src/shared/Rec/Sampler")

local Runs = {}

local GROUND_Y = 3 -- HumanoidRootPart height on a flat floor
local GRAVITY = 196.2
local G = Codec.FLAG.GROUNDED

export type Step =
	{ walk: { number }, speed: number? } -- walk to {x, z}
	| { wait: number } -- stand still for seconds
	| { jump: true } -- jump in place while moving on (uses current heading)
	| { teleport: { number }, event: number? } -- server move to {x, y, z}, recorded as a cut

-- Deterministic small jitter, like a real server view of a walking character.
local function lcg(seed: number): () -> number
	local s = seed
	return function()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648 - 0.5
	end
end

-- Builds a recording from steps at hz. Returns the recording.
function Runs.build(steps: { any }, opts: { hz: number?, jitter: number?, seed: number?, start: { number }? }?): Codec.Recording
	local o = opts or {}
	local hz = o.hz or 20
	local dt = 1 / hz
	local rec = Sampler.new(1, 1, hz)
	local rnd = lcg(o.seed or 7)
	local jitter = o.jitter or 0
	local start = o.start or { 0, 0 }
	local x, y, z = start[1], GROUND_Y, start[2]
	local yaw = 0
	local tick = 0
	local jumpT: number? = nil
	local v0 = math.sqrt(2 * GRAVITY * 7.2)

	local function emit(cut: boolean?)
		local fy = y
		local flags = G
		if jumpT then
			local jt = jumpT :: number
			fy = GROUND_Y + v0 * jt - 0.5 * GRAVITY * jt * jt
			if fy <= GROUND_Y then
				fy = GROUND_Y
				jumpT = nil
			else
				flags = Codec.FLAG.JUMPING
				jumpT = jt + dt
			end
		end
		Sampler.record(
			rec,
			tick,
			x + rnd() * jitter,
			fy + rnd() * jitter * 0.25,
			z + rnd() * jitter,
			yaw,
			flags,
			cut
		)
		tick += 1
	end

	emit()
	for _, step in steps do
		if step.walk then
			local speed = step.speed or 16
			local tx, tz = step.walk[1], step.walk[2]
			while true do
				local dx, dz = tx - x, tz - z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < 1e-6 then
					break
				end
				yaw = math.atan2(-dx, -dz) -- Roblox: facing -Z at yaw 0
				local stepLen = math.min(d, speed * dt)
				x += dx / d * stepLen
				z += dz / d * stepLen
				emit()
			end
		elseif step.wait then
			for _ = 1, math.floor(step.wait * hz + 0.5) do
				emit()
			end
		elseif step.jump then
			jumpT = dt
		elseif step.teleport then
			Sampler.addEvent(rec, tick / hz, step.event or Codec.EVENT.Respawn, 0)
			x, y, z = step.teleport[1], step.teleport[2], step.teleport[3]
			emit(true)
		end
	end
	return rec
end

-- A plausible 45 s Bank run: walk to the plate, hold it, wander, jump, carry loot back.
function Runs.heist45(jitter: number?): Codec.Recording
	local steps = {
		{ walk = { 0, -40 } },
		{ walk = { 12, -52 } },
		{ wait = 3 },
		{ walk = { 30, -52 } },
		{ jump = true },
		{ walk = { 30, -90 } },
		{ walk = { 10, -110 } },
		{ wait = 1.5 },
		{ walk = { -20, -100 } },
		{ jump = true },
		{ walk = { -20, -60 }, speed = 12 },
		{ walk = { 0, 0 } },
		{ wait = 2 },
		{ walk = { 40, 20 } },
		{ jump = true },
		{ walk = { 60, -30 } },
		{ walk = { 60, -80 } },
		{ walk = { 20, -120 } },
		{ jump = true },
		{ walk = { -30, -120 } },
		{ walk = { -30, -20 }, speed = 12 },
		{ walk = { 0, 0 } },
		{ walk = { 50, 0 } },
		{ walk = { 50, -60 } },
	}
	local rec = Runs.build(steps, { jitter = jitter, seed = 42 })
	-- Pad or trim to exactly 45 s (901 samples) by standing still.
	local n = 45 * 20 + 1
	while rec.n < n do
		Sampler.push(rec, rec.px[rec.n], rec.py[rec.n], rec.pz[rec.n], rec.yaw[rec.n], rec.flags[rec.n])
	end
	if rec.n > n then
		for i = n + 1, rec.n do
			rec.px[i], rec.py[i], rec.pz[i], rec.yaw[i], rec.flags[i] = nil, nil, nil, nil, nil
		end
		rec.n = n
	end
	Sampler.addEvent(rec, 3.2, Codec.EVENT.Press, 1)
	Sampler.addEvent(rec, 12.0, Codec.EVENT.Grab, 2)
	Sampler.addEvent(rec, 30.0, Codec.EVENT.Release, 2)
	Sampler.addEvent(rec, 31.5, Codec.EVENT.Emote, 3)
	Sampler.finish(rec, Codec.END.Timeout)
	return rec
end

return Runs
