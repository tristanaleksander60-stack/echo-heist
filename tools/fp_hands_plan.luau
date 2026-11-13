--!strict
-- Dumps the first-person hands of every preview pose as camera-space part frames, for the Blender preview
-- (tools/blender/fp_hands_preview.py, docs/art/fp_hands/). AFTER runs the game's own code: Heist/ViewmodelMath (the
-- pose layers, the finger poses, the viewmodel projection) and Heist/FpRig (the dedicated arms' assembly) on
-- RookieData.fpArms, exactly as Heist/Viewmodel's frame does (springs settled on their targets). BEFORE replays the
-- v101 rig (the body-piece arms of the old Viewmodel.fromOutfit at the old Config) from copies of the old modules
-- the preview extracts from git into build/fp_before/.
--
--   lune run tools/fp_hands_plan.luau v2 [fov] [outfit] > build/fp_hands_v2.json  (FP HANDS v2: the skinned gloves)
--   lune run tools/fp_hands_plan.luau after [fov] > build/fp_hands_after.json       (v125: the rigid FP arms)
--   lune run tools/fp_hands_plan.luau before [fov] > build/fp_hands_before.json
--
-- Each part: { piece, cf = 12 CFrame components (camera space: x right, y up, -z forward; world studs, the part's
-- CENTRE as a MeshPart has it), scale = per-axis factors on the authored kit size (MeshPart.Size / manifest size),
-- tint = "gloves" | "crew" | nil, material }; code parts (the old sleeve stripes) are { prim = "cylinder", cf, size }.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local mode = process.args[1] or "after"
local fov = tonumber(process.args[2]) or 70

local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json")).parts

local function v3(t: { number }, s: number?): any
	local k = s or 1
	return Vector3.new(t[1] * k, t[2] * k, t[3] * k)
end

local function comps(cf: any): { number }
	return { cf:GetComponents() }
end

-- BEFORE's poses (v101 had no ViewmodelMath.showcase): the same names and moments, the springs settled.
local PI = math.pi
local function poses(VM: any, VMath: any): { { any } }
	local function peak(name: string): number
		-- an action's weight at its most extended moment (the overshoot's top when it has one)
		local a = VM.ACTIONS[name]
		local best = 0
		for i = 0, 400 do
			local w = if a.anticipate
				then VMath.envelope(i / 400, a.time, false, a.anticipate, a.overshoot)
				else VMath.envelope(i / 400, a.time, false)
			if w > best then
				best = w
			end
		end
		return best
	end
	local walkLag = (VM.WALK and VM.WALK.LAG) or 0
	local tapTravel = (VM.ACTIONS.watch.tap or { 0 })[1]
	return {
		{ "idle", {} },
		{ "ready", { raise = 1, ready = 1 } },
		{ "walkUp", { bobPhase = PI / 2 + walkLag, bobAmp = 1 } },
		{ "walkDown", { bobPhase = PI + walkLag, bobAmp = 1 } },
		{ "reach", { raise = 1, actions = { reach = peak("reach") } } },
		{ "carry", { raise = 1, carry = 1 } },
		{ "push", { raise = 1, actions = { push = peak("push") } } },
		{ "point", { raise = 1, point = 1 } },
		{ "watch", { raise = 1, actions = { watch = 1 }, tap = tapTravel } },
		{ "handsUp", { raise = 1, actions = { handsUp = 1 } } },
	}
end

local function frameOf(spec: any): any
	return {
		t = 0,
		bobPhase = spec.bobPhase or 0,
		bobAmp = spec.bobAmp or 0,
		lagX = 0,
		lagY = 0,
		lagRoll = 0,
		carry = spec.carry or 0,
		hidden = 0,
		wall = 0,
		actions = spec.actions or {},
		tap = spec.tap,
		reduced = false,
		point = spec.point or 0,
		raise = spec.raise or 0,
		ready = spec.ready or 0,
	}
end

local function poseCf(pose: { number }, s: number): any
	return CFrame.new(pose[1] * s, pose[2] * s, pose[3] * s)
		* CFrame.Angles(math.rad(pose[4]), math.rad(pose[5]), math.rad(pose[6]))
end

-- the loot copy between the hands (Heist/Viewmodel: the carry pose's loot point moved with the hands' midpoint)
local function lootCf(VM: any, R: { number }, L: { number }, s: number): any
	local C = VM.CARRY
	local mid = { (R[1] + L[1]) / 2, (R[2] + L[2]) / 2, (R[3] + L[3]) / 2 }
	local rest = { (C.R[1] + C.L[1]) / 2, (C.R[2] + C.L[2]) / 2, (C.R[3] + C.L[3]) / 2 }
	return CFrame.new(
		(C.LOOT[1] + mid[1] - rest[1]) * s,
		(C.LOOT[2] + mid[2] - rest[2]) * s,
		(C.LOOT[3] + mid[3] - rest[3]) * s
	)
end

local out: { [string]: any } = { mode = mode, fov = fov, poses = {}, order = {} }

if mode == "v2" then
	-- FP HANDS v2: the skinned gloves (RookieData.fpHands) exactly as Heist/Viewmodel.placeArm places them. Each
	-- part's cf is final (the arm already slid along the view axis for the viewmodel FOV; never resized: scale 1).
	-- Per glove: `skins[glove]` = { bone -> its hinge frame in the glove part's space, posed } and `rest[side]` = the
	-- same at the rest pose; the preview poses the FBX armature from them.
	local Config = require("../src/shared/Config") :: any
	local VMath = require("../src/client/Heist/ViewmodelMath") :: any
	local FpRig = require("../src/client/Heist/FpRig") :: any
	local RookieData = require("../src/shared/Heist/RookieData") :: any
	local VM = Config.FirstPerson.VIEWMODEL
	local data = RookieData.fpHands
	local s = data.scale
	local outfit = table.clone(Config.Rookie.DEFAULT_OUTFIT)
	if process.args[3] then
		for kv in string.gmatch(process.args[3], "[^,]+") do
			local slot, id = string.match(kv, "^(%w+)=([%w_]+)$")
			if slot and id then
				outfit[slot] = id
			end
		end
	end
	local keep = FpRig.wears(outfit)
	local hands, gloves, rests = {}, {}, {}
	for _, side in { "Right", "Left" } do
		local list = table.clone(data[side])
		for _, b in data.bones[side] do
			table.insert(list, b)
		end
		local hand = FpRig.build(CFrame, Vector3, side, list, s, keep)
		hands[side] = hand
		for _, e in data[side] do
			if e.skinned then
				gloves[side] = e.piece
			end
		end
		local frames = FpRig.restFrames(CFrame, Vector3, hand)
		local g = frames[gloves[side]]
		local rest = {}
		for _, b in data.bones[side] do
			rest[b.piece] = comps(g:Inverse() * frames[b.piece])
		end
		rests[side] = rest
	end
	local info: { [string]: any } = {}
	for _, side in { "Right", "Left" } do
		for _, e in data[side] do
			info[e.piece] = e
		end
	end
	local k = VMath.viewK(fov, VM.VIEW_FOV)
	out.viewK = k
	out.scale = s
	out.v2 = true
	out.glove = Config.Rookie.GLOVES[outfit.gloves]
	out.gloveLift = { VM.ARMS.GLOVE_LIFT, VM.ARMS.GLOVE_LIFT_TO }
	out.materials = VM.ARMS.MATERIALS
	out.sleeveColour = VM.ARMS.SLEEVE_COLOUR
	out.outfit = outfit
	out.fill = VM.FILL
	out.lootSize = VM.CARRY.LOOT_SIZE * VM.SCALE
	out.rest = rests
	out.gloves = gloves
	for _, entry in VMath.showcase(VM) do
		local name, f = entry[1], entry[2]
		local R, L = VMath.hands(VM, f)
		local fR, fL = VMath.fingers(VM, f)
		local parts, skins, bends, shifts = {}, {}, {}, {}
		for _, side in { { "Right", R, fR, "R" }, { "Left", L, fL, "L" } } do
			local handCf = poseCf(side[2], s)
			local elbow = v3(VMath.elbow(VM, side[4], side[2]), s)
			local placed = FpRig.place(CFrame, Vector3, hands[side[1]], handCf, elbow, side[3], VM.ARMS.WRIST_ROLL)
			local dz = VMath.armShift((handCf * hands[side[1]].wrist).Position.Z, k)
			local shift = CFrame.new(0, 0, dz)
			local at = {}
			for _, pc in placed do
				at[pc[1]] = pc[2]
				local e = info[pc[1]]
				if e then
					table.insert(parts, {
						piece = pc[1],
						cf = comps(shift * pc[2]),
						scale = { 1, 1, 1 },
						tint = e.tint,
						joint = e.joint,
						skinned = e.skinned,
					})
				end
			end
			local P = at[gloves[side[1]]]
			local bones = {}
			for _, b in data.bones[side[1]] do
				bones[b.piece] = comps(P:Inverse() * at[b.piece])
			end
			skins[gloves[side[1]]] = bones
			local armCf = FpRig.armFrame(CFrame, Vector3, hands[side[1]], handCf, elbow, VM.ARMS.WRIST_ROLL)
			bends[side[4]] = FpRig.wristBend(handCf, armCf)
			shifts[side[4]] = dz
		end
		local pose: { [string]: any } = { parts = parts, skins = skins, R = R, L = L, wristBend = bends, shift = shifts }
		if f.carry > 0 then
			local lc, lf = VMath.project(comps(lootCf(VM, R, L, VM.SCALE)), { 1, 1, 1 }, k)
			pose.loot = { cf = lc, scale = lf }
		end
		out.poses[name] = pose
		table.insert(out.order, name)
	end
elseif mode == "after" then
	local Config = require("../src/shared/Config") :: any
	local VMath = require("../src/client/Heist/ViewmodelMath") :: any
	local FpRig = require("../src/client/Heist/FpRig") :: any
	local RookieData = require("../src/shared/Heist/RookieData") :: any
	local VM = Config.FirstPerson.VIEWMODEL
	local s = VM.SCALE
	local outfit = table.clone(Config.Rookie.DEFAULT_OUTFIT)
	if process.args[3] then
		for kv in string.gmatch(process.args[3], "[^,]+") do
			local slot, id = string.match(kv, "^(%w+)=([%w_]+)$")
			if slot and id then
				outfit[slot] = id
			end
		end
	end
	local keep = FpRig.wears(outfit)
	local hands = {
		R = FpRig.build(CFrame, Vector3, "Right", RookieData.fpArms.Right, s, keep),
		L = FpRig.build(CFrame, Vector3, "Left", RookieData.fpArms.Left, s, keep),
	}
	local info: { [string]: any } = {}
	for _, side in { "Right", "Left" } do
		for _, e in RookieData.fpArms[side] do
			info[e.piece] = e
		end
	end
	local k = VMath.viewK(fov, VM.VIEW_FOV)
	out.viewK = k
	out.scale = s
	out.glove = Config.Rookie.GLOVES[outfit.gloves]
	out.gloveLift = { VM.ARMS.GLOVE_LIFT, VM.ARMS.GLOVE_LIFT_TO }
	out.materials = VM.ARMS.MATERIALS
	out.outfit = outfit
	out.fill = VM.FILL
	out.lootSize = VM.CARRY.LOOT_SIZE * s
	for _, entry in VMath.showcase(VM) do
		local name, f = entry[1], entry[2]
		local R, L = VMath.hands(VM, f)
		local fR, fL = VMath.fingers(VM, f)
		local rCf, lCf = poseCf(R, s), poseCf(L, s)
		local parts = {}
		local bends = {}
		for _, side in { { hands.R, rCf, fR, "R", R }, { hands.L, lCf, fL, "L", L } } do
			local elbow = v3(VMath.elbow(VM, side[4], side[5]), s)
			for _, pc in FpRig.place(CFrame, Vector3, side[1], side[2], elbow, side[3], VM.ARMS.WRIST_ROLL) do
				local e = info[pc[1]]
				local c, fac = VMath.project(comps(pc[2]), e.size, k)
				table.insert(parts, {
					piece = pc[1],
					cf = c,
					scale = { fac[1] * s, fac[2] * s, fac[3] * s },
					tint = e.tint,
					joint = e.joint,
				})
			end
			local armCf = FpRig.armFrame(CFrame, Vector3, side[1], side[2], elbow, VM.ARMS.WRIST_ROLL)
			bends[side[4]] = FpRig.wristBend(side[2], armCf)
		end
		local pose: { [string]: any } = { parts = parts, R = R, L = L, wristBend = bends }
		if f.carry > 0 then
			local lc, lf = VMath.project(comps(lootCf(VM, R, L, s)), { 1, 1, 1 }, k)
			pose.loot = { cf = lc, scale = lf }
		end
		out.poses[name] = pose
		table.insert(out.order, name)
	end
else
	-- v101: the body-piece arms of the old Viewmodel.fromOutfit (default outfit: knit gloves, Breton stripes)
	local Config = require("../build/fp_before/shared/Config") :: any
	local VMath = require("../build/fp_before/client/Heist/ViewmodelMath") :: any
	local RookieData = require("../build/fp_before/shared/Heist/RookieData") :: any
	local VM = Config.FirstPerson.VIEWMODEL
	local s = VM.SCALE
	out.scale = s
	out.viewK = 1
	out.glove = Config.Rookie.GLOVES.Gloves_Knit
	local function bodyOrigin(part: string): any
		for _, b in RookieData.body do
			if b.part == part then
				return v3(b.origin)
			end
		end
		error("no body part " .. part)
	end
	local function centreOf(piece: string): any
		local m = manifest[piece]
		local lo, hi = m.boundsMin, m.boundsMax
		return Vector3.new((lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2, (lo[3] + hi[3]) / 2)
	end
	-- per side: rigid parts (piece, grip-relative CFrame scaled) + finger segments (old addFingers)
	local rigs = {}
	for _, side in { "Right", "Left" } do
		local d = RookieData.viewmodel[side .. "Arm"]
		local elbowAt, wristAt = bodyOrigin(side .. "LowerArm"), bodyOrigin(side .. "Hand")
		local elbow = CFrame.new(elbowAt)
		local axis = (wristAt - elbowAt).Unit
		local gripPos = (elbow * CFrame.new(v3(d.gripOffset))).Position
		local grip = CFrame.lookAt(gripPos, gripPos + axis, Vector3.new(0, 0, 1))
		local function rel(cf: any): any
			local o = grip:ToObjectSpace(cf)
			return CFrame.new(o.Position * s) * (o - o.Position)
		end
		local rigid = {}
		local function addPiece(piece: string, pivot: any, tint: string?)
			table.insert(rigid, { piece = piece, rest = rel(CFrame.new(pivot + centreOf(piece))), tint = tint })
		end
		addPiece("Rookie_" .. side .. "LowerArm", elbowAt)
		local segs = {}
		local hinges = {}
		local index = {}
		for _, h in RookieData.hands[side] do
			local at = wristAt + v3(h.offset)
			if h.joint == "Palm" then
				addPiece(h.piece, at, "gloves")
			else
				local hinge = rel(CFrame.new(at))
				local parent = if h.parent ~= "Palm" then index[h.parent] else nil
				local link = if parent then hinges[h.parent]:Inverse() * hinge else hinge
				table.insert(segs, {
					piece = h.piece,
					joint = h.joint,
					parent = parent,
					link = link,
					rest = hinge:Inverse() * rel(CFrame.new(at + centreOf(h.piece))),
				})
				index[h.joint] = #segs
				hinges[h.joint] = hinge
			end
		end
		local cuff = "Rookie_Gloves_Knit_" .. side
		local a = RookieData.attach[cuff]
		addPiece(cuff, bodyOrigin(a.part) + v3(a.offset), "gloves")
		local prims = {}
		local sideV = axis:Cross(Vector3.new(0, 0, 1)).Unit
		for i, t in VM.SLEEVE_STRIPES do
			local cf = CFrame.fromMatrix(elbowAt:Lerp(wristAt, t), axis, sideV)
			table.insert(prims, {
				rest = rel(cf),
				size = { VM.STRIPE_WIDTH * s, VM.STRIPE_RADIUS[i] * 2 * s, VM.STRIPE_RADIUS[i] * 2 * s },
			})
		end
		rigs[side] = {
			rigid = rigid,
			segs = segs,
			prims = prims,
			across = Vector3.new(0, 0, if side == "Right" then 1 else -1),
		}
	end
	for _, entry in poses(VM, VMath) do
		local name, spec = entry[1], entry[2]
		local f = frameOf(spec)
		local R, L = VMath.hands(VM, f)
		local fR, fL = VMath.fingers(VM, f)
		local fit = VMath.fovFit(fov, VM.FOV_REF)
		local function poseFit(p: { number }): any
			return CFrame.new(p[1] * s * fit, p[2] * s * fit, p[3] * s)
				* CFrame.Angles(math.rad(p[4]), math.rad(p[5]), math.rad(p[6]))
		end
		local parts, prims = {}, {}
		for _, side in { { "Right", poseFit(R), fR }, { "Left", poseFit(L), fL } } do
			local rig = rigs[side[1]]
			local handCf = side[2]
			for _, p in rig.rigid do
				table.insert(
					parts,
					{ piece = p.piece, cf = comps(handCf * p.rest), scale = { s, s, s }, tint = p.tint }
				)
			end
			local frames = {}
			for i, sg in rig.segs do
				local a = side[3][sg.joint] or { 0, 0 }
				local base = if sg.parent then frames[sg.parent] else CFrame.new()
				frames[i] = base
					* sg.link
					* CFrame.fromAxisAngle(Vector3.new(1, 0, 0), math.rad(a[1]))
					* CFrame.fromAxisAngle(rig.across, math.rad(a[2]))
				table.insert(parts, {
					piece = sg.piece,
					cf = comps(handCf * frames[i] * sg.rest),
					scale = { s, s, s },
					tint = "gloves",
				})
			end
			for _, pr in rig.prims do
				table.insert(prims, { prim = "cylinder", cf = comps(handCf * pr.rest), size = pr.size, tint = "crew" })
			end
		end
		local pose: { [string]: any } = { parts = parts, prims = prims, R = R, L = L }
		if spec.carry then
			pose.loot = { cf = comps(lootCf(VM, R, L, s) * CFrame.new()), scale = { 1, 1, 1 } }
			local C = VM.CARRY
			local mid = { (R[1] + L[1]) / 2, (R[2] + L[2]) / 2, (R[3] + L[3]) / 2 }
			local rest = { (C.R[1] + C.L[1]) / 2, (C.R[2] + C.L[2]) / 2, (C.R[3] + C.L[3]) / 2 }
			pose.loot.cf = comps(
				CFrame.new(
					(C.LOOT[1] + mid[1] - rest[1]) * s * fit,
					(C.LOOT[2] + mid[2] - rest[2]) * s * fit,
					(C.LOOT[3] + mid[3] - rest[3]) * s
				)
			)
		end
		out.poses[name] = pose
		table.insert(out.order, name)
	end
	out.lootSize = VM.CARRY.LOOT_SIZE * s
end

print(serde.encode("json", out))
