-- L1: FP HANDS v2, the skinned first-person gloves (docs/art/fp_hands_v2; Heist/FpRig skin maths, Heist/ViewmodelMath
-- armShift, RookieData.fpHands, Config.FirstPerson.VIEWMODEL). The kit data: one skinned glove a hand with its 23
-- Bones in one chain (parents first), the cuffs and sweater variants, the left watch, the triangle budget a worn arm.
-- The maths: the arm shift is the viewmodel FOV (the same picture as a VIEW_FOV camera, at any FOV); the Bone
-- transforms put every Bone on its posed hinge whatever axes the importer gave the Bones (rest = identity). And every
-- preview pose assembled as Viewmodel.placeArm does: a natural wrist, the sleeve runs back toward the eye, nothing
-- nearer than NEAR, every piece and every finger inside the screen-safe rect at 16:9 and 19.5:9, FOV 60 / 70 / 90;
-- the relaxed rest keeps the fingers together (never splayed) and the thumb along the index.

local roblox = require("@lune/roblox")

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local FpRig = require("../../src/client/Heist/FpRig")
local ViewmodelMath = require("../../src/client/Heist/ViewmodelMath")
local RookieData = require("../../src/shared/Heist/RookieData") :: any

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local VM = Config.FirstPerson.VIEWMODEL
local FOV = Config.Heist.CAMERA.FP.FOV
local ASPECTS = { 16 / 9, 19.5 / 9 }
local D = RookieData.fpHands
local FINGERS = { "Index", "Middle", "Ring", "Pinky", "Thumb" }

local function v3(t: { number }, k: number?): any
	local m = k or 1
	return Vector3.new(t[1] * m, t[2] * m, t[3] * m)
end

local function piece(side: string, joint: string): any
	for _, e in D[side] do
		if e.joint == joint then
			return e
		end
	end
	return nil
end

local function bone(side: string, joint: string): any
	for _, b in D.bones[side] do
		if b.joint == joint then
			return b
		end
	end
	return nil
end

local outfit = table.clone(Config.Rookie.DEFAULT_OUTFIT)
local s = D.scale

local function build(side: string, wear: any): any
	local list = table.clone(D[side])
	for _, b in D.bones[side] do
		table.insert(list, b)
	end
	return FpRig.build(CFrame, Vector3, side, list, s, wear or FpRig.wears(outfit))
end
local hands = { R = build("Right"), L = build("Left") }
local info: { [string]: any } = {}
for _, side in { "Right", "Left" } do
	for _, e in D[side] do
		info[e.piece] = e
	end
end

local function poseCf(p: { number }): any
	return CFrame.new(p[1] * s, p[2] * s, p[3] * s) * CFrame.Angles(math.rad(p[4]), math.rad(p[5]), math.rad(p[6]))
end

local function frame(spec: any): any
	return {
		t = 0,
		bobPhase = 0,
		bobAmp = 0,
		lagX = 0,
		lagY = 0,
		lagRoll = 0,
		carry = 0,
		hidden = 0,
		wall = spec.wall or 0,
		actions = {},
		reduced = false,
		raise = spec.raise or 0,
	}
end

-- A pose assembled as Viewmodel.placeArm does: { pieces = { piece, joint, cf, size }, bones = { [bone] = cf } } in
-- final camera space (each arm slid along the view axis), wrist bends by side.
local function assemble(f: any, fov: number): (any, { [string]: number })
	local R, L = ViewmodelMath.hands(VM, f)
	local fR, fL = ViewmodelMath.fingers(VM, f)
	local k = ViewmodelMath.viewK(fov, VM.VIEW_FOV)
	local out = { pieces = {}, bones = {} }
	local bends = {}
	for _, side in { { hands.R, poseCf(R), fR, "R", R }, { hands.L, poseCf(L), fL, "L", L } } do
		local elbow = v3(ViewmodelMath.elbow(VM, side[4], side[5]), s)
		local shift = CFrame.new(0, 0, ViewmodelMath.armShift((side[2] * side[1].wrist).Position.Z, k))
		for _, pc in FpRig.place(CFrame, Vector3, side[1], side[2], elbow, side[3], VM.ARMS.WRIST_ROLL) do
			local e = info[pc[1]]
			if e then
				table.insert(out.pieces, { piece = pc[1], joint = e.joint, cf = shift * pc[2], size = v3(e.size) })
			else
				out.bones[pc[1]] = shift * pc[2]
			end
		end
		bends[side[4]] = FpRig.wristBend(side[2], FpRig.armFrame(CFrame, Vector3, side[1], side[2], elbow, 0.6))
	end
	return out, bends
end

local function corners(cf: any, size: any): { any }
	local h = size / 2
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
			end
		end
	end
	return out
end

-- Every point of the arms the camera could see: the rigid pieces' boxes, and the glove as its posed bones with a
-- finger's radius round each (the glove's own box is its bind pose, not the posed shape).
local FINGER_R = 0.06 * s
local function points(a: any): { { any } }
	local out = {}
	for _, p in a.pieces do
		if p.joint ~= "Glove" then
			-- every forearm piece is a ring about its z: its outline at both ends (a box's corners overstate it)
			local h = p.size / 2
			for _, z in { -h.Z, h.Z } do
				for i = 0, 11 do
					local t = i * math.pi / 6
					table.insert(out, { p.piece, p.cf * Vector3.new(h.X * math.cos(t), h.Y * math.sin(t), z) })
				end
			end
		end
	end
	for name, cf in a.bones do
		if name ~= "R_Root" and name ~= "L_Root" and not string.find(name, "Forearm", 1, true) then
			for _, q in corners(cf, Vector3.new(1, 1, 1) * FINGER_R * 2) do
				table.insert(out, { name, q })
			end
		end
	end
	return out
end

return function(test)
	test("fpHands: one skinned glove a hand, 23 Bones in one chain (parents first), the forearm pieces", function()
		Assert.truthy(D ~= nil and D.scale ~= nil, "RookieData.fpHands (run tools/rookie_data.py)")
		Assert.truthy(D.scale > 0.1 and D.scale < 0.3, "exported at the in-game size (" .. D.scale .. ")")
		for _, side in { "Right", "Left" } do
			local g = piece(side, "Glove")
			Assert.truthy(g ~= nil and g.skinned == true, side .. " glove is skinned")
			Assert.eq(g.tint, "gloves", "the glove takes the glove colour")
			Assert.eq(g.frame, "arm", "the glove MeshPart rides the forearm frame (the Bones bend the rest)")
			Assert.eq(#D.bones[side], 23, side .. ": Root, Forearm, Hand, 4 fingers x (3 + a tip), the thumb 3 + a tip")
			local seen: { [string]: boolean } = {}
			for _, b in D.bones[side] do
				if b.boneParent then
					Assert.truthy(seen[b.boneParent], side .. " " .. b.joint .. " after " .. b.boneParent)
				end
				seen[b.joint] = true
				Assert.eq(string.sub(b.piece, 1, 2), if side == "Right" then "R_" else "L_", "side-unique bone names")
			end
			for _, f in FINGERS do
				Assert.eq(bone(side, f .. "1").boneParent, "Hand", f .. "1 hangs on the hand")
				Assert.eq(bone(side, f .. "2").boneParent, f .. "1", f .. "2 on " .. f .. "1")
				Assert.eq(bone(side, f .. "3").boneParent, f .. "2", f .. "3 on " .. f .. "2")
				Assert.eq(bone(side, f .. "Tip").boneParent, f .. "3", "a tip on " .. f .. "3")
			end
			for _, j in { "Sleeve", "CuffKnit", "CuffLeather", "Stripes", "Block" } do
				Assert.truthy(piece(side, j) ~= nil, side .. " has " .. j)
				Assert.eq(piece(side, j).frame, "arm", j .. " rides the forearm frame")
			end
			Assert.eq(piece(side, "Stripes").tint, "crew", "stripes: crew colour")
			Assert.eq(piece(side, "Block").tint, "crew", "block: crew colour")
			Assert.eq(piece(side, "CuffKnit").tint, "gloves", "knit cuff: glove colour")
			Assert.eq(piece(side, "CuffLeather").tint, "gloves", "leather cuff: glove colour")
		end
		Assert.truthy(piece("Left", "Watch") ~= nil and piece("Right", "Watch") == nil, "the watch on the left wrist")
	end)

	test("fpHands: mirrored hands, the thumb inside, smooth and within the triangle budget a worn arm", function()
		for _, j in { "Index1", "Pinky3", "Thumb2", "ThumbTip" } do
			local r, l = bone("Right", j), bone("Left", j)
			Assert.near(r.hinge[1], -l.hinge[1], 1e-3, j .. " mirrored x")
			Assert.near(r.hinge[2], l.hinge[2], 1e-3, j .. " same y")
			Assert.near(r.hinge[3], l.hinge[3], 1e-3, j .. " same z")
		end
		Assert.truthy(bone("Right", "Thumb1").hinge[1] < 0 and bone("Left", "Thumb1").hinge[1] > 0, "thumbs inside")
		for _, side in { "Right", "Left" } do
			-- rounded fingers need polygons: a 2,000-4,000 triangle glove (v125's capsules were 96 a segment)
			local g = piece(side, "Glove")
			Assert.truthy(g.tris >= 2000 and g.tris <= 4000, side .. " glove tris " .. g.tris)
			for _, wear in
				{
					FpRig.wears(outfit),
					FpRig.wears({ gloves = "Gloves_Leather", sweater = "Sweater_Block" }),
				}
			do
				local n = 0
				for _, e in D[side] do
					if wear(e) then
						n += e.tris
					end
				end
				Assert.le(n, VM.ARMS.TRI_BUDGET_V2, side .. " worn arm tris")
			end
		end
	end)

	test("arm shift: the same picture as a VIEW_FOV camera, the same at every FOV", function()
		Assert.near(ViewmodelMath.armShift(-0.5, 1), 0, 1e-12, "k = 1: no shift")
		local p = Vector3.new(0.21, -0.17, -0.5)
		local x0, y0 = ViewmodelMath.ndc(p.X, p.Y, p.Z, VM.VIEW_FOV, 16 / 9)
		for _, fov in { 60, FOV, 90 } do
			local k = ViewmodelMath.viewK(fov, VM.VIEW_FOV)
			local q = p + Vector3.new(0, 0, ViewmodelMath.armShift(p.Z, k))
			local x1, y1 = ViewmodelMath.ndc(q.X, q.Y, q.Z, fov, 16 / 9)
			Assert.near(x1 :: number, x0 :: number, 1e-5, "screen x at fov " .. fov)
			Assert.near(y1 :: number, y0 :: number, 1e-5, "screen y at fov " .. fov)
			-- and the arm's size on screen is the projected (k-scaled) size of the per-part method
			Assert.near(-q.Z, -p.Z / k, 1e-5, "depth z / k")
		end
	end)

	test("skin: Bone transforms put every Bone on its posed hinge whatever its rest axes; rest is identity", function()
		for _, key in { "R", "L" } do
			local hand = hands[key]
			local side = if key == "R" then "Right" else "Left"
			local glove = piece(side, "Glove").piece
			-- fake importer Bones: each at its hinge, its axes turned by an arbitrary rotation (the FBX bone roll)
			local frames = FpRig.restFrames(CFrame, Vector3, hand)
			local g = frames[glove]
			local order, parent, rest, world = {}, {}, {}, {}
			for i, b in D.bones[side] do
				local q = CFrame.Angles(0.3 * i, -0.2 * i, 0.11 * i)
				world[b.piece] = g:Inverse() * frames[b.piece] * q
				local par = if b.boneParent then (if key == "R" then "R_" else "L_") .. b.boneParent else nil
				table.insert(order, b.piece)
				parent[b.piece] = par
				rest[b.piece] = (if par then world[par] else CFrame.new()):Inverse() * world[b.piece]
			end
			local skin = FpRig.skin(CFrame, Vector3, hand, glove, order, parent, rest)
			-- at the rest pose every Transform is the identity
			local placed0 = FpRig.place(CFrame, Vector3, hand, CFrame.new(), hand.wrist.Position + Vector3.zAxis, {}, 0)
			for name, t in FpRig.boneTransforms(CFrame, skin, placed0) do
				Assert.near(t.Position.Magnitude, 0, 1e-5, name .. " rest: no move")
				Assert.near(t.LookVector:Dot(Vector3.new(0, 0, -1)), 1, 1e-5, name .. " rest: no turn")
			end
			-- posed (the grip pose, the hand turned): each Bone lands on its posed hinge
			local handCf = CFrame.new(0.2, -0.1, -0.5) * CFrame.Angles(0.5, 0.3, -0.2)
			local angles = ViewmodelMath.joints(VM.HANDS, VM.HANDS.POSES.grip)
			local placed = FpRig.place(CFrame, Vector3, hand, handCf, Vector3.new(0.4, -0.5, -0.2), angles, 0.6)
			local at = {}
			for _, pc in placed do
				at[pc[1]] = pc[2]
			end
			local T = FpRig.boneTransforms(CFrame, skin, placed)
			local W = {}
			for _, name in order do
				local par = parent[name]
				W[name] = (if par then W[par] else CFrame.new()) * rest[name] * T[name]
				local want = at[glove]:Inverse() * at[name]
				Assert.near((W[name].Position - want.Position).Magnitude, 0, 1e-5, name .. " on its hinge")
			end
			-- the curl closes the fingers toward the palm (the hand's -Y)
			local tip = at[(if key == "R" then "R_" else "L_") .. "MiddleTip"]
			local base = at[(if key == "R" then "R_" else "L_") .. "Middle1"]
			Assert.truthy(
				handCf:PointToObjectSpace(tip.Position).Y < handCf:PointToObjectSpace(base.Position).Y,
				"curl"
			)
		end
	end)

	test("every pose: a natural wrist, the sleeve runs back toward the eye, nothing nearer than NEAR", function()
		for _, entry in ViewmodelMath.showcase(VM) do
			local a, bends = assemble(entry[2], FOV)
			for side, b in bends do
				Assert.le(b, 60, entry[1] .. " " .. side .. " wrist bend")
			end
			local handAt: { [string]: any } = { R = a.bones.R_Hand, L = a.bones.L_Hand }
			for _, p in a.pieces do
				if p.joint == "Sleeve" then
					local h = handAt[if string.find(p.piece, "Right", 1, true) then "R" else "L"]
					Assert.truthy(p.cf.Position.Z > h.Position.Z, entry[1] .. " " .. p.piece .. " runs back")
					Assert.truthy(p.cf.Position.Y < h.Position.Y, entry[1] .. " " .. p.piece .. " comes from below")
				end
			end
			for _, fov in { 60, FOV, 90 } do
				local b = assemble(entry[2], fov)
				for _, pt in points(b) do
					local q = pt[2]
					-- on screen (in front of the bottom edge's ray) nothing may come nearer than NEAR
					local _, y = ViewmodelMath.ndc(q.X, q.Y, q.Z, fov, 16 / 9)
					if y and y > -1 then
						Assert.truthy(q.Magnitude >= VM.NEAR, entry[1] .. " " .. pt[1] .. " beyond NEAR at " .. fov)
					end
				end
			end
		end
	end)

	test(
		"every pose: every piece and finger inside the screen-safe rect at 16:9 and 19.5:9 (FOV 60, 70, 90)",
		function()
			local S = VM.SAFE
			for _, fov in { 60, FOV, 90 } do
				for _, aspect in ASPECTS do
					for _, entry in ViewmodelMath.showcase(VM) do
						local a = assemble(entry[2], fov)
						for _, pt in points(a) do
							local q = pt[2]
							local x, y = ViewmodelMath.ndc(q.X, q.Y, q.Z, fov, aspect)
							-- the forearm (sleeve, stripes, block) may leave through the bottom edge and the lower corners
							-- (arms raised at FOV 90); the gloves, cuffs and watch stay fully inside
							local sleeve = string.find(pt[1], "Sleeve", 1, true) ~= nil
								or string.find(pt[1], "Stripes", 1, true) ~= nil
								or string.find(pt[1], "Block", 1, true) ~= nil
							if x and y and y > -1 and not (sleeve and y < -0.3) then
								local where = string.format("%s %s fov %d aspect %.2f", entry[1], pt[1], fov, aspect)
								Assert.le(math.abs(x), S.X, where .. " |x|")
								Assert.le(y, S.Y_TOP, where .. " top")
							end
						end
						if (entry[2].raise or 0) > 0 then
							local palms = 0
							for _, key in { "R_Middle1", "L_Middle1" } do -- the knuckles in view
								local c = a.bones[key].Position
								local _, y = ViewmodelMath.ndc(c.X, c.Y, c.Z, fov, aspect)
								if y and y > S.PALM_MIN_Y then
									palms += 1
								end
							end
							Assert.truthy(
								palms >= (if entry[1] == "watch" then 1 else 2),
								entry[1] .. ": palms in view"
							)
						end
					end
				end
			end
		end
	)

	test("the relaxed rest: lower corners, fingers together and softly curled, the thumb along the index", function()
		local a = assemble(frame({ raise = 1 }), FOV)
		for _, pre in { "R_", "L_" } do
			local hand = a.bones[pre .. "Hand"]
			local palm = (hand * CFrame.new(0, 0, -0.2 * s)).Position
			local x, y = ViewmodelMath.ndc(palm.X, palm.Y, palm.Z, FOV, 16 / 9)
			Assert.truthy(math.abs(x :: number) > 0.35 and math.abs(x :: number) < 0.75, pre .. " palm x " .. x)
			Assert.truthy((y :: number) < -0.4 and (y :: number) > -0.85, pre .. " palm y " .. y)
			local function loc(name: string): any
				return hand:PointToObjectSpace(a.bones[pre .. name].Position) / s
			end
			-- never splayed: across the hand the tips sit no further apart than the knuckles (+10 %)
			for _, pair in { { "Index", "Middle" }, { "Middle", "Ring" }, { "Ring", "Pinky" } } do
				local base = math.abs(loc(pair[1] .. "1").X - loc(pair[2] .. "1").X)
				local tip = math.abs(loc(pair[1] .. "Tip").X - loc(pair[2] .. "Tip").X)
				Assert.le(tip, base * 1.1, pre .. pair[1] .. "-" .. pair[2] .. " tips together")
			end
			-- softly curled: every tip below its knuckle (toward the palm), none folded under the hand
			for _, f in { "Index", "Middle", "Ring", "Pinky" } do
				local k, t = loc(f .. "1"), loc(f .. "Tip")
				Assert.truthy(t.Y < k.Y, pre .. f .. " tip curls toward the palm")
				Assert.truthy(t.Z < k.Z - 0.06, pre .. f .. " still reaches forward (not a fist)")
			end
			-- the thumb: on the index side, under the hand's back, its tip level with the index's first knuckle
			local th, ix = loc("ThumbTip"), loc("Index1")
			local sideSign = if pre == "R_" then -1 else 1
			Assert.truthy(th.X * sideSign > 0.1, pre .. " thumb on the index side")
			Assert.truthy(th.Y < ix.Y, pre .. " thumb under the back of the hand")
			Assert.truthy(math.abs(th.Z - ix.Z) < 0.2, pre .. " thumb tip near the index knuckle line (" .. th.Z .. ")")
		end
	end)
end
