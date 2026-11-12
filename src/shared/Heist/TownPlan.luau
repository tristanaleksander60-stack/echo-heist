--!strict
-- Heist/TownPlan: the snowy neighbourhood round every lot (WORLD 2.0, docs/audit/LEVELS.md §10; PLAN_STEAM_PLUS
-- §3.1). Pure: no engine calls and no math.random (a seeded Park-Miller stream), so tests/unit/HeistBackdrop.spec
-- checks the layout and the budget in Lune, tools/blender/level_shots.py draws the same plan and the client
-- Heist/Backdrop turns it into parts. Called by Heist/BackdropPlan.plan with the site.
--
-- What it lays out (site space: level space for a heist, world space for the garage):
--   * the street the lot stands on: pavements, kerbs, a snowy road with tyre tracks, all at the lot's own height,
--     running SPAN studs either side; the Bank's plaza across the street;
--   * snow over the lot's outdoor floor (layer "lot": the pavement and road in front of the building, the yards);
--   * the neighbours: a row either side of the lot along the street (the first one long, its side lit toward the
--     lot), a row behind it facing it, a row across the street; flat roofs with a cornice under thick snow or gabled
--     roofs (kit Roof_Gable), lit warm windows, shop fronts with awnings, doors;
--   * the Christmas pieces (layer "decor"): garlands under the cornices, wreaths on the doors, fairy-light strings;
--   * the props (layer "props"): street lamps (kit, no Light) with unlit warm pools, parked cars with snow on the
--     roof, decorated trees, snowmen, snow piles;
--   * the lot fence (layer "fence"): invisible colliders on the lot's edge (the town never collides).
-- The plan is built in a canonical frame (the street toward +Z of the lot) and mirrored for the garage, whose yard
-- and street are toward -Z.

local Config = require("../Config")

local TownPlan = {}

export type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Part = {
	name: string,
	size: { number },
	pos: { number }, -- centre
	color: { number },
	neon: boolean?,
	layer: string, -- ground | lot | building | windows | decor | props | fence
	src: string, -- the source-mask layer for tools/blender (ground | lot | building | props | none)
	collide: boolean?, -- the lot fence only
}
export type Kit = {
	piece: string, -- a kit piece published by server Heist/BackdropKit
	pos: { number }, -- the model's pivot (its origin)
	yaw: number, -- degrees about +Y (0: the piece's front looks toward -Z)
	scale: number?, -- uniform scale about the pivot
	size: { number }?, -- or: the piece's bounding-box size (per axis, in its own frame)
	color: { number }?, -- MeshPart.Color (runtime-coloured pieces: Car_Parked_Paint)
	layer: string,
	src: string,
	fallback: Part?, -- drawn instead while (or if) the kit piece is missing
}
export type Pool = { pos: { number }, size: number, color: { number }, alpha: number, layer: string }
export type Town = {
	parts: { Part },
	kit: { Kit },
	pools: { Pool },
	buildings: number,
	street: { near: number, kerb: number, roadEnd: number, across: number },
}
export type Input = {
	theme: string, -- a key of Config.Backdrop.TOWN.THEMES
	seed: number,
	lot: Rect, -- the playable lot (canonical frame)
	footprint: Rect?, -- the building inside it
	front: number, -- the street front's line (canonical Z); the street is toward +Z
	floorY: number,
	mirror: boolean, -- true: flip Z on the way out (the garage)
	xmas: boolean,
}

local B = Config.Backdrop
local T = B.TOWN
local C = T.COLORS

-- Park-Miller "minimal standard": exact in doubles (16807 * 2^31 < 2^53).
local function stream(seed: number): () -> number
	local s = math.floor(math.abs(seed)) % 2147483646 + 1
	return function(): number
		s = (s * 16807) % 2147483647
		return (s - 1) / 2147483646
	end
end

local function pick<V>(list: { V }, k: number): V
	return list[(k - 1) % #list + 1]
end

function TownPlan.build(input: Input): Town
	local theme = T.THEMES[input.theme] or T.THEMES.CornerShop
	local rnd = stream(input.seed * 7919 + #input.theme)
	local lot = input.lot
	local fp = input.footprint
	local y0 = input.floorY
	local top = y0 + T.LIFT
	local parts: { Part } = {}
	local kit: { Kit } = {}
	local pools: { Pool } = {}
	local buildings = 0
	local colourTurn = math.floor(rnd() * #theme.bodies)

	local function part(name: string, size: { number }, pos: { number }, color: { number }, layer: string, src: string)
		local p: Part = { name = name, size = size, pos = pos, color = color, layer = layer, src = src }
		table.insert(parts, p)
		return p
	end
	-- an axis-aligned slab whose top is at `y`
	local function slab(name: string, x0: number, x1: number, z0: number, z1: number, y: number, h: number, color, layer, src)
		if x1 - x0 < 0.05 or z1 - z0 < 0.05 then
			return
		end
		part(name, { x1 - x0, h, z1 - z0 }, { (x0 + x1) / 2, y - h / 2, (z0 + z1) / 2 }, color, layer, src)
	end
	local function addKit(k: Kit)
		table.insert(kit, k)
	end

	-- The street ----------------------------------------------------------------------------------------------
	local P, R = T.PAVEMENT, T.ROAD
	local F = input.front
	local kerbZ = F + P
	local roadEnd = math.max(kerbZ + R, lot.maxZ + T.ROAD_PAST_LOT)
	local acrossZ = roadEnd + P
	local X0, X1 = (lot.minX + lot.maxX) / 2 - T.SPAN, (lot.minX + lot.maxX) / 2 + T.SPAN
	-- outside the lot: the near pavement and the road beside it, the road past the lot's street edge, the far
	-- pavement; inside the lot the same bands are the "lot" layer (the client's snow over the level floor)
	slab("Pavement", X0, lot.minX, F, kerbZ, top, 0.4, C.pave, "ground", "ground")
	slab("Pavement", lot.maxX, X1, F, kerbZ, top, 0.4, C.pave, "ground", "ground")
	slab("Road", X0, lot.minX, kerbZ, roadEnd, top, 0.4, C.road, "ground", "ground")
	slab("Road", lot.maxX, X1, kerbZ, roadEnd, top, 0.4, C.road, "ground", "ground")
	slab("Road", lot.minX, lot.maxX, math.max(lot.maxZ, kerbZ), roadEnd, top, 0.4, C.road, "ground", "ground")
	slab("Pavement", X0, X1, roadEnd, acrossZ, top, 0.4, C.pave, "ground", "ground")
	-- kerbs: a raised stone line where each pavement meets the road (the near one only outside the lot)
	local kw, kh = T.KERB.width, T.KERB.height
	slab("Kerb", X0, lot.minX, kerbZ - kw, kerbZ, top + kh, kh + 0.4, C.kerb, "ground", "ground")
	slab("Kerb", lot.maxX, X1, kerbZ - kw, kerbZ, top + kh, kh + 0.4, C.kerb, "ground", "ground")
	slab("Kerb", X0, X1, roadEnd, roadEnd + kw, top + kh, kh + 0.4, C.kerb, "ground", "ground")
	-- tyre tracks: two lanes of two ruts along the road, cut where they cross the lot (lot layer there)
	local mid = (kerbZ + roadEnd) / 2
	for _, lane in T.TRACKS.lanes do
		for _, side in { -1, 1 } do
			local z = mid + lane * (R / 22) + side * T.TRACKS.gauge / 2
			local z0, z1 = z - T.TRACKS.width / 2, z + T.TRACKS.width / 2
			local y = y0 + T.TRACK_LIFT
			local inLot = z1 < lot.maxZ
			if inLot then
				slab("Track", X0, lot.minX, z0, z1, y, 0.2, C.track, "ground", "ground")
				slab("Track", lot.minX, lot.maxX, z0, z1, y, 0.2, C.track, "lot", "lot")
				slab("Track", lot.maxX, X1, z0, z1, y, 0.2, C.track, "ground", "ground")
			else
				slab("Track", X0, X1, z0, z1, y, 0.2, C.track, "ground", "ground")
			end
		end
	end
	-- The lot's outdoor floor: the pavement and road bands in front of the building, the yards round it
	slab("LotPavement", lot.minX, lot.maxX, F, math.min(kerbZ, lot.maxZ), top, 0.2, C.pave, "lot", "lot")
	slab("LotRoad", lot.minX, lot.maxX, kerbZ, lot.maxZ, top, 0.2, C.road, "lot", "lot")
	if fp then
		local f = fp :: Rect
		slab("LotYard", lot.minX, f.minX, lot.minZ, F, top, 0.2, C.yard, "lot", "lot")
		slab("LotYard", f.maxX, lot.maxX, lot.minZ, F, top, 0.2, C.yard, "lot", "lot")
		slab("LotYard", f.minX, f.maxX, lot.minZ, f.minZ, top, 0.2, C.yard, "lot", "lot")
		slab("LotYard", f.minX, f.maxX, f.maxZ, F, top, 0.2, C.yard, "lot", "lot")
	end
	-- the lot fence (client-only, invisible, CanQuery off)
	do
		local LF = T.LOT_FENCE
		local t, h = LF.thickness, LF.height
		for _, f in
			{
				{ lot.minX - t, lot.maxX + t, lot.minZ - t, lot.minZ },
				{ lot.minX - t, lot.maxX + t, lot.maxZ, lot.maxZ + t },
				{ lot.minX - t, lot.minX, lot.minZ, lot.maxZ },
				{ lot.maxX, lot.maxX + t, lot.minZ, lot.maxZ },
			}
		do
			local p = part(
				"LotFence",
				{ f[2] - f[1], h, f[4] - f[3] },
				{ (f[1] + f[2]) / 2, y0 + h / 2 - 2, (f[3] + f[4]) / 2 },
				{ 0, 0, 0 },
				"fence",
				"none"
			)
			p.collide = true
		end
	end

	-- Buildings -----------------------------------------------------------------------------------------------
	local W = T.WINDOW
	local SH = T.SHOP
	-- facade frame: front centre (fx, fz) on the ground, outward normal (nx, nz) along an axis; u to the right of
	-- someone facing the front, n out of it, v up
	local function frame(fx: number, fz: number, nx: number, nz: number)
		local rx, rz = nz, -nx
		local function at(u: number, v: number, n: number): { number }
			return { fx + rx * u + nx * n, y0 + v, fz + rz * u + nz * n }
		end
		local function size(su: number, sv: number, sn: number): { number }
			if math.abs(nx) > 0.5 then
				return { sn, sv, su }
			end
			return { su, sv, sn }
		end
		local yaw = math.deg(math.atan2(-nx, -nz))
		return at, size, yaw
	end

	-- lit windows on one face (floors from `fromV`, columns across `width`, a door gap at u = doorU)
	local function windows(fx: number, fz: number, nx: number, nz: number, width: number, height: number, fromV: number, doorU: number?, doorW: number?)
		local at, size = frame(fx, fz, nx, nz)
		local cols = math.max(1, math.floor((width - 2) / W.colPitch))
		local v = fromV
		while v + W.h + 0.8 <= height do
			for c = 0, cols - 1 do
				local u = (c - (cols - 1) / 2) * W.colPitch
				local blocked = doorU ~= nil and v < 5 and math.abs(u - doorU) < ((doorW or 0) / 2 + W.w / 2 + 0.3)
				if not blocked and rnd() < W.lit then
					part("Window", size(W.w, W.h, W.depth), at(u, v + W.h / 2, W.out), B.WINDOW_COLOR, "windows", "building").neon =
						true
				end
			end
			v += W.floorH
		end
	end

	local function door(at: any, size: any, u: number, w: number, h: number, colour: { number })
		part("Door", size(w, h, 0.3), at(u, h / 2, 0.1), colour, "building", "building")
	end

	-- One building. kind: shop | house | townhouse | civic | warehouse. sides: extra lit faces ("left" / "right").
	local function building(kind: string, fx: number, fz: number, nx: number, nz: number, w: number, d: number, sides: { string }?)
		buildings += 1
		colourTurn += 1
		local body = pick(theme.bodies, colourTurn)
		local hr = theme.heights[kind] or theme.heights.house
		local h = hr[1] + rnd() * (hr[2] - hr[1])
		h = math.floor(h * 2 + 0.5) / 2
		local at, size, yaw = frame(fx, fz, nx, nz)
		part("Body", size(w, h, d), at(0, h / 2, -d / 2), body, "building", "building")
		local doorColour = pick(C.door, buildings + input.seed)
		local gable = kind == "house" or kind == "warehouse"
		if gable then
			local RF = T.ROOF
			local rise = RF.rise * (d + 2 * RF.overhang) / 2
			addKit({
				piece = "Roof_Gable",
				pos = at(0, h, -d / 2),
				yaw = yaw,
				size = { w + 2 * RF.overhang, rise, d + 2 * RF.overhang },
				layer = "building",
				src = "building",
				fallback = {
					name = "RoofSnow",
					size = size(w + 1, 0.5, d + 1),
					pos = at(0, h + 0.25, -d / 2),
					color = C.roofSnow,
					layer = "building",
					src = "building",
				},
			})
		else
			part("Cornice", size(w + 0.6, 0.9, 1.3), at(0, h - 0.45, 0.25), C.trim, "building", "building")
			part("RoofSnow", size(w + 0.5, 0.45, d + 0.9), at(0, h + 0.22, -d / 2 + 0.45), C.roofSnow, "building", "building")
		end
		local topV = if gable then h - 0.3 else h - 0.9
		if kind == "shop" then
			local awning = pick(theme.awnings, buildings + input.seed)
			local paneW = math.min(7, (w - SH.doorW - 3) / 2)
			for _, s in { -1, 1 } do
				part(
					"Window",
					size(paneW, SH.paneH, W.depth),
					at(s * (SH.doorW / 2 + 0.75 + paneW / 2), SH.paneSill + SH.paneH / 2, W.out),
					B.WINDOW_COLOR,
					"windows",
					"building"
				).neon =
					true
			end
			door(at, size, 0, SH.doorW, SH.doorH, doorColour)
			local ad = SH.awningDepth
			part("Awning", size(w - 1, 0.35, ad), at(0, SH.awningY, ad / 2), awning, "building", "building")
			part("AwningSnow", size(w - 1.3, 0.25, ad - 0.3), at(0, SH.awningY + 0.3, ad / 2 - 0.1), C.roofSnow, "building", "building")
			windows(fx, fz, nx, nz, w, topV, SH.awningY + 1.4, nil, nil)
			if input.xmas and theme.signature == "lights" then
				for k = 0, math.floor((w - 1) / 8) - 1 do
					local mu = -w / 2 + 0.5 + (k + 1) * 8 -- module's right end
					addKit({ piece = "Xmas_Lights_8", pos = at(mu, SH.awningY - 9.2, -0.3), yaw = yaw, layer = "decor", src = "building" })
					addKit({ piece = "Xmas_Lights_8_Bulbs", pos = at(mu, SH.awningY - 9.2, -0.3), yaw = yaw, layer = "decor", src = "building" })
				end
			end
		elseif kind == "civic" then
			-- a portico: four columns and a lintel with snow, lit tall windows behind
			local cw = math.min(w - 2, 16)
			for k = 0, 3 do
				local u = -cw / 2 + k * cw / 3
				part("Column", size(1.3, 9, 1.3), at(u, 4.5, 1.6), C.trim, "building", "building")
			end
			part("Lintel", size(cw + 2, 1.2, 2.6), at(0, 9.6, 1.4), C.trim, "building", "building")
			part("LintelSnow", size(cw + 1.6, 0.35, 2.3), at(0, 10.35, 1.4), C.roofSnow, "building", "building")
			door(at, size, 0, 3.2, 6, doorColour)
			windows(fx, fz, nx, nz, w, topV, 11.6, nil, nil)
			for _, s in { -1, 1 } do
				part("Window", size(1.6, 4.5, W.depth), at(s * cw / 3 * 1.0, 4.2, W.out), B.WINDOW_COLOR, "windows", "building").neon =
					true
			end
		else
			local du = if kind == "warehouse" then 0 else (if rnd() < 0.5 then -1 else 1) * (w / 2 - 3)
			local dw = if kind == "warehouse" then math.min(10, w - 6) else T.HOUSE.doorW
			local dh = if kind == "warehouse" then 7.5 else T.HOUSE.doorH
			door(at, size, du, dw, dh, if kind == "warehouse" then C.trim else doorColour)
			windows(fx, fz, nx, nz, w, topV, if kind == "warehouse" then 8.4 else W.sill - 2, du, dw)
			if input.xmas and kind ~= "warehouse" then
				-- the wreath's origin is its back centre: on the door leaf's face
				addKit({ piece = "Xmas_Wreath", pos = at(du, dh - 1.3, 0.26), yaw = yaw, layer = "decor", src = "building" })
			end
		end
		if input.xmas and (kind == "shop" or kind == "townhouse" or kind == "civic") and theme.signature ~= "lights" then
			-- a garland run under the cornice (wall-module coordinates: the module's right end, its face at -0.3)
			local n = math.min(3, math.floor((w - 1) / 8))
			for k = 0, n - 1 do
				local mu = -n * 4 + (k + 1) * 8
				addKit({ piece = "Xmas_Garland_8", pos = at(mu, topV - 11.0, -0.3), yaw = yaw, layer = "decor", src = "building" })
			end
		end
		for _, side in sides or {} do
			local s = if side == "right" then 1 else -1
			local rx, rz = nz, -nx
			local sx, sz = fx + rx * s * w / 2 + nx * (-d / 2), fz + rz * s * w / 2 + nz * (-d / 2)
			windows(sx, sz, rx * s, rz * s, d, topV, W.sill, nil, nil)
		end
		return h
	end

	-- A row of buildings along X (fronts on z = line, facing nz) from x = start toward dir until `stop`.
	local function row(kinds: { string }, line: number, nz: number, start: number, dir: number, stop: number, depth: { number }, k0: number)
		local x = start
		local k = k0
		while (stop - x) * dir > 8 do
			k += 1
			local w = pick(theme.widths, k + input.seed)
			if (stop - (x + dir * w)) * dir < -1e-6 then
				w = math.abs(stop - x)
				if w < 10 then
					break
				end
			end
			local d = depth[1] + rnd() * (depth[2] - depth[1])
			local kind = pick(kinds, k + input.seed)
			building(kind, x + dir * w / 2, line, 0, nz, w, d, nil)
			x += dir * (w + 1.5 + math.floor(rnd() * 3))
		end
	end

	-- the near row: the long neighbour beside the lot (its side lit toward the lot), then along the street
	local adjW = 18
	local backZ = lot.minZ - T.BACK_GAP
	for _, s in { -1, 1 } do
		local edge = if s > 0 then lot.maxX + T.ALLEY else lot.minX - T.ALLEY
		local depth = F - (lot.minZ - 2)
		local kind = pick(theme.near, input.seed + (if s > 0 then 1 else 2))
		if kind == "house" then
			kind = "townhouse" -- a long house reads as a barn: the long neighbour is a terrace
		end
		building(kind, edge + s * adjW / 2, F, 0, 1, adjW, depth, { if s > 0 then "left" else "right" })
		row(theme.near, F, 1, edge + s * (adjW + 2), s, (lot.minX + lot.maxX) / 2 + s * T.SPAN * 0.75, { 14, 20 }, 2)
	end
	-- the row behind the lot, facing it (+Z)
	do
		local x0 = lot.minX - T.ALLEY - adjW
		local x1 = lot.maxX + T.ALLEY + adjW
		row(theme.back, backZ, 1, x0, 1, x1, { 14, 18 }, 5)
	end
	-- the row across the street (facing -Z); the Bank keeps a plaza in the middle
	local cx = (lot.minX + lot.maxX) / 2
	local plaza = theme.signature == "plaza" and theme.PLAZA
	local gapHalf = if plaza then plaza.width / 2 else 0
	if plaza then
		slab("Plaza", cx - gapHalf, cx + gapHalf, acrossZ, acrossZ + plaza.depth, top, 0.4, C.plaza, "ground", "ground")
		-- civic fronts at the plaza's back
		local backLine = acrossZ + plaza.depth
		row({ "civic", "townhouse" }, backLine, -1, cx - gapHalf, 1, cx + gapHalf, { 16, 22 }, 9)
	end
	row(theme.across, acrossZ, -1, cx - gapHalf - 1, -1, cx - T.SPAN * 0.85, { 14, 20 }, 11)
	row(theme.across, acrossZ, -1, cx + gapHalf + 1, 1, cx + T.SPAN * 0.85, { 14, 20 }, 17)

	-- Props --------------------------------------------------------------------------------------------------
	local LP = T.LAMP
	local function lamp(x: number, z: number, faceZ: number)
		local yaw = if faceZ > 0 then 180 else 0
		addKit({
			piece = "StreetLamp",
			pos = { x, top, z },
			yaw = yaw,
			layer = "props",
			src = "props",
			fallback = {
				name = "LampPost",
				size = { 0.5, 10, 0.5 },
				pos = { x, top + 5, z },
				color = { 60, 62, 96 },
				layer = "props",
				src = "props",
			},
		})
		addKit({ piece = "StreetLamp_Bulb", pos = { x, top, z }, yaw = yaw, layer = "props", src = "props" })
		table.insert(pools, {
			pos = { x, y0 + LP.poolLift, z + faceZ * 1.5 },
			size = LP.pool,
			color = LP.poolColor,
			alpha = LP.poolAlpha,
			layer = "props",
		})
	end
	-- near pavement, outside the lot (the level's own lamps light the lot's front)
	for _, s in { -1, 1 } do
		local edge = if s > 0 then lot.maxX else lot.minX
		for k = 0, 2 do
			lamp(edge + s * (6 + k * LP.spacing), kerbZ - 0.9, 1)
		end
	end
	-- far pavement
	for k = -2, 2 do
		local x = cx + k * LP.spacing + (if plaza then (if k < 0 then -1 else 1) * 6 else 0)
		if not (plaza and math.abs(x - cx) < gapHalf - 4) then
			lamp(x, roadEnd + 0.9, -1)
		end
	end
	-- parked cars along both kerbs (never in front of the lot on its own side)
	local CA = T.CAR
	local function car(x: number, z: number, faceX: number, k: number)
		local yaw = if faceX > 0 then -90 else 90
		addKit({ piece = "Car_Parked", pos = { x, top, z }, yaw = yaw, layer = "props", src = "props" })
		addKit({
			piece = "Car_Parked_Paint",
			pos = { x, top, z },
			yaw = yaw,
			color = pick(CA.colors, k + input.seed),
			layer = "props",
			src = "props",
		})
	end
	local nCar = 0
	for _, s in { -1, 1 } do
		local edge = if s > 0 then lot.maxX else lot.minX
		for k = 0, 1 do
			nCar += 1
			car(edge + s * (20 + k * CA.spacing + rnd() * 6), kerbZ + 1.9, s, nCar)
		end
	end
	for k = 0, 2 do
		nCar += 1
		local x = cx + (k - 1) * (CA.spacing + 6) + (rnd() - 0.5) * 8
		if not (plaza and math.abs(x - cx) < gapHalf) then
			car(x, roadEnd - 1.9, if k % 2 == 0 then 1 else -1, nCar)
		end
	end
	-- trees and snowmen: the theme's signature first
	local function tree(x: number, z: number, scale: number)
		addKit({ piece = "Xmas_Tree", pos = { x, top, z }, yaw = 0, scale = scale, layer = "building", src = "props" })
		if input.xmas then
			addKit({ piece = "Xmas_Tree_Lights", pos = { x, top, z }, yaw = 0, scale = scale, layer = "decor", src = "props" })
		end
	end
	local function snowman(x: number, z: number, yaw: number)
		addKit({ piece = "Snowman", pos = { x, top, z }, yaw = yaw, layer = "props", src = "props" })
	end
	local side = if rnd() < 0.5 then -1 else 1
	if plaza then
		local pz = acrossZ + plaza.depth * 0.45
		tree(cx, pz, plaza.treeScale)
		table.insert(pools, {
			pos = { cx, y0 + LP.poolLift, pz },
			size = 30,
			color = LP.poolColor,
			alpha = LP.poolAlpha,
			layer = "props",
		})
		for k = 0, plaza.lamps - 1 do
			local a = math.rad(45 + 90 * k)
			lamp(cx + math.cos(a) * 15, pz + math.sin(a) * 12, if math.sin(a) > 0 then -1 else 1)
		end
		snowman(cx + side * 22, acrossZ + 6, 180)
	else
		local tx = cx + side * (lot.maxX - cx + 12 + rnd() * 10)
		tree(tx, roadEnd + P * 0.55, 1.9)
		if theme.signature == "lights" then
			tree(cx - side * (lot.maxX - cx + 16), roadEnd + P * 0.55, 1.7)
		end
		snowman(cx - side * (8 + rnd() * 14), roadEnd + P * 0.5, 180)
		-- a tree in the yard behind the long neighbour on the other side
		tree(cx - side * (lot.maxX - cx + T.ALLEY + adjW + 8), F - 6, 1.5)
		if theme.signature == "yard" then
			snowman(cx + side * (lot.maxX - cx + 30), kerbZ - 2.2, 0)
		end
	end
	-- snow piles where the kerbs end at the lot, and by the lamps
	for _, s in { -1, 1 } do
		local edge = if s > 0 then lot.maxX else lot.minX
		addKit({ piece = "Xmas_SnowPile", pos = { edge + s * 2.6, top, kerbZ - 1.6 }, yaw = 0, layer = "props", src = "props" })
	end
	addKit({ piece = "Xmas_SnowPile", pos = { cx + side * 30, top, roadEnd + 1.5 }, yaw = 180, layer = "props", src = "props" })

	-- Out of the canonical frame -------------------------------------------------------------------------------
	if input.mirror then
		for _, p in parts do
			p.pos[3] = -p.pos[3]
		end
		for _, k in kit do
			k.pos[3] = -k.pos[3]
			k.yaw = (180 - k.yaw) % 360
			local fb = k.fallback
			if fb then
				fb.pos[3] = -fb.pos[3]
			end
		end
		for _, pl in pools do
			pl.pos[3] = -pl.pos[3]
		end
	end
	return {
		parts = parts,
		kit = kit,
		pools = pools,
		buildings = buildings,
		street = { near = F, kerb = kerbZ, roadEnd = roadEnd, across = acrossZ },
	}
end

return table.freeze(TownPlan)
