-- Replays a recording as a live player's input (not a spec itself): the path a
-- human-recorded levels/<id>.solution.bin run takes in CI and in the Ghost Hint.
-- Every tick it sends the recorded position, every recorded intent at its time,
-- and END RUN where the recording ended with it. Same interface as Bot (start,
-- tick, delay), so Harness.runOnce drives it. A tape never adapts: it is the
-- frozen solution the daily modifiers must survive (Daily.spec.luau).

local Codec = require("../../src/shared/Rec/Codec")
local Config = require("../../src/shared/Config")
local HeistSim = require("../../src/shared/Sim/HeistSim")
local Interact = require("../../src/shared/Sim/Interact")
local Sampler = require("../../src/shared/Rec/Sampler")

local DT = 1 / Config.Rec.HZ

local Tape = {}
Tape.__index = Tape

function Tape.new(playerId: number, rec: any)
	local self = setmetatable({}, Tape)
	self.id = playerId
	self.rec = rec
	self.delay = 0
	self.cursor = 0
	self.ended = false
	return self
end

function Tape:start(_sim: any)
	self.cursor = 0
	self.ended = false
end

function Tape:tick(sim: any, _view: any)
	local rec = self.rec
	local t = sim.nextTick * DT
	local x, y, z, yaw = Sampler.at(rec, t)
	if x then
		HeistSim.setInput(sim, self.id, x, y, z, yaw, Codec.FLAG.GROUNDED)
	end
	local last = Sampler.eventsDue(rec, self.cursor, t)
	for k = self.cursor + 1, last do
		local e = rec.events[k]
		if Interact.REQUESTABLE[e.kind] then
			HeistSim.request(sim, self.id, e.kind, e.arg)
		end
	end
	self.cursor = last
	if not self.ended and rec.endReason == Codec.END.EndRun and Sampler.isHolding(rec, t) then
		self.ended = true
		HeistSim.endRun(sim, self.id)
	end
end

function Tape:finished(): boolean
	return self.ended
end

return Tape
