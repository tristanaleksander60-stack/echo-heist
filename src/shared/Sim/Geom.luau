--!strict
-- Sim/Geom: pure geometry for the heist sim. MASTERPLAN §8.2 ("plates use
-- point-in-box, lasers segment tests, Gus raycasts against sim boxes").
-- Level space, studs, Y up, axis-aligned boxes. Yaw follows Roblox: yaw 0 faces
-- -Z, forward(yaw) = (-sin yaw, -cos yaw) (the same convention the recordings use).
-- The segment-vs-box slab test is Rec/Validator's, so the validator, the sim and
-- every client agree on what "crosses a box" means.

local Validator = require("../Rec/Validator")

export type Box = Validator.Box

local Geom = {}

local TAU = 2 * math.pi
local EPS = 1e-9

-- A box from its centre and size.
function Geom.box(cx: number, cy: number, cz: number, sx: number, sy: number, sz: number): Box
	return {
		minX = cx - sx / 2,
		minY = cy - sy / 2,
		minZ = cz - sz / 2,
		maxX = cx + sx / 2,
		maxY = cy + sy / 2,
		maxZ = cz + sz / 2,
	}
end

-- A box from two corners (any order).
function Geom.span(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): Box
	return {
		minX = math.min(x0, x1),
		minY = math.min(y0, y1),
		minZ = math.min(z0, z1),
		maxX = math.max(x0, x1),
		maxY = math.max(y0, y1),
		maxZ = math.max(z0, z1),
	}
end

-- The box grown by `h` studs horizontally and `v` studs vertically.
function Geom.expand(b: Box, h: number, v: number?): Box
	local vv = v or 0
	return {
		minX = b.minX - h,
		minY = b.minY - vv,
		minZ = b.minZ - h,
		maxX = b.maxX + h,
		maxY = b.maxY + vv,
		maxZ = b.maxZ + h,
	}
end

function Geom.isValidBox(b: any): boolean
	if type(b) ~= "table" then
		return false
	end
	for _, k in { "minX", "minY", "minZ", "maxX", "maxY", "maxZ" } do
		local v = b[k]
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
			return false
		end
	end
	return b.minX < b.maxX and b.minY < b.maxY and b.minZ < b.maxZ
end

-- Closed point-in-box (edges count as inside).
function Geom.contains(b: Box, x: number, y: number, z: number): boolean
	return x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY and z >= b.minZ and z <= b.maxZ
end

-- Open point-in-box (edges are outside), as the validator uses for "starts inside".
function Geom.inside(b: Box, x: number, y: number, z: number): boolean
	return x > b.minX and x < b.maxX and y > b.minY and y < b.maxY and z > b.minZ and z < b.maxZ
end

-- Does the segment p0 -> p1 enter box b? (Validator's slab test.)
Geom.segmentHitsBox = Validator.segmentHitsBox

-- A move p0 -> p1 is blocked by b when it enters b without starting inside it
-- (an actor standing in a doorway when the door shuts can walk out).
function Geom.moveBlocked(b: Box, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): boolean
	return not Geom.inside(b, x0, y0, z0) and Validator.segmentHitsBox(b, x0, y0, z0, x1, y1, z1)
end

-- The segment touches b at all (starts inside, ends inside, or crosses).
function Geom.touches(b: Box, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): boolean
	return Geom.contains(b, x0, y0, z0)
		or Geom.contains(b, x1, y1, z1)
		or Validator.segmentHitsBox(b, x0, y0, z0, x1, y1, z1)
end

function Geom.boxesOverlap(a: Box, b: Box): boolean
	return a.minX < b.maxX
		and a.maxX > b.minX
		and a.minY < b.maxY
		and a.maxY > b.minY
		and a.minZ < b.maxZ
		and a.maxZ > b.minZ
end

function Geom.center(b: Box): (number, number, number)
	return (b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2, (b.minZ + b.maxZ) / 2
end

function Geom.dist2(x0: number, z0: number, x1: number, z1: number): number
	local dx, dz = x1 - x0, z1 - z0
	return dx * dx + dz * dz
end

-- Yaw that faces from (x0, z0) toward (x1, z1); `fallback` when they coincide.
function Geom.yawTo(x0: number, z0: number, x1: number, z1: number, fallback: number?): number
	local dx, dz = x1 - x0, z1 - z0
	if dx * dx + dz * dz < EPS then
		return fallback or 0
	end
	return math.atan2(-dx, -dz) % TAU
end

function Geom.forward(yaw: number): (number, number)
	return -math.sin(yaw), -math.cos(yaw)
end

-- Signed shortest angle from a to b, in (-pi, pi].
function Geom.angleDelta(a: number, b: number): number
	local d = (b - a + math.pi) % TAU - math.pi
	if d <= -math.pi then
		d += TAU
	end
	return d
end

-- Turn `from` toward `to` by at most `maxStep` radians; result in [0, 2pi).
function Geom.turnToward(from: number, to: number, maxStep: number): number
	local d = Geom.angleDelta(from, to)
	if math.abs(d) <= maxStep then
		return to % TAU
	end
	return (from + (if d > 0 then maxStep else -maxStep)) % TAU
end

-- Grid integer for hashing and logs (1/16 stud, like the recording format).
function Geom.q(v: number): number
	if v ~= v then
		return 0
	end
	return math.floor(v * 16 + 0.5)
end

return table.freeze(Geom)
