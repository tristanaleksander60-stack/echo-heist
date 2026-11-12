-- Frame-time meter for the clone bench: keeps the frame times of the current
-- measurement window and reports average FPS, the 1% low and the worst frame.

local BenchConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Bench"):WaitForChild("BenchConfig"))

local Meter = {}

export type Summary = {
	frames: number,
	seconds: number,
	avgFps: number,
	low1Fps: number, -- average FPS of the slowest 1% of frames
	worstMs: number,
}

local times: { number } = {} -- frame times (s) since sampling began
local stamps: { number } = {} -- clock at each frame
local phaseStart = os.clock()

-- Start a new measurement (call after every change to N, look or camera).
function Meter.reset()
	table.clear(times)
	table.clear(stamps)
	phaseStart = os.clock()
end

function Meter.isWarming(): boolean
	return os.clock() - phaseStart < BenchConfig.WARMUP_SECONDS
end

-- Seconds of samples collected so far (after the warm-up).
function Meter.sampledSeconds(): number
	return math.max(0, os.clock() - phaseStart - BenchConfig.WARMUP_SECONDS)
end

function Meter.isComplete(): boolean
	return Meter.sampledSeconds() >= BenchConfig.WINDOW_SECONDS
end

function Meter.addFrame(dt: number)
	if Meter.isWarming() then
		return
	end
	local now = os.clock()
	table.insert(times, dt)
	table.insert(stamps, now)
	-- Rolling window: drop frames older than WINDOW_SECONDS
	local cutoff = now - BenchConfig.WINDOW_SECONDS
	local drop = 0
	while drop < #stamps and stamps[drop + 1] < cutoff do
		drop += 1
	end
	if drop > 0 then
		table.move(times, drop + 1, #times, 1)
		table.move(stamps, drop + 1, #stamps, 1)
		for _ = 1, drop do
			table.remove(times)
			table.remove(stamps)
		end
	end
end

function Meter.summary(): Summary?
	local n = #times
	if n == 0 then
		return nil
	end
	local total = 0
	local sorted = table.clone(times)
	for _, dt in sorted do
		total += dt
	end
	table.sort(sorted, function(a, b)
		return a > b
	end)
	local worstCount = math.max(1, math.floor(n * 0.01))
	local worstTotal = 0
	for i = 1, worstCount do
		worstTotal += sorted[i]
	end
	return {
		frames = n,
		seconds = total,
		avgFps = if total > 0 then n / total else 0,
		low1Fps = if worstTotal > 0 then worstCount / worstTotal else 0,
		worstMs = sorted[1] * 1000,
	}
end

return Meter
