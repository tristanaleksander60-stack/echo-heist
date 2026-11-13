--!strict
-- Heist/FpRig: the assembly maths of the dedicated first-person arms (Rookie_FPArms, RookieData.fpArms;
-- docs/research/fp_hands.md). Pure: the CFrame and Vector3 libraries are passed in, so the game (Heist/Viewmodel)
-- and the Blender preview's Lune dump (tools/fp_hands_plan.luau) run the very same code. Lune-tested
-- (tests/unit/HeistFpRig.spec.luau).
--
-- A hand is three groups of pieces, all authored in its GRIP space (fingers -Z, the back of the hand +Y, the right
-- thumb on -X; full size, scaled here):
--   rigid  the palm and the glove cuff: follow the grip frame
--   segs   the 15 finger segments (4 fingers x 3 + the thumb x 3): each turns about its hinge frame (look = the
--          segment's direction, up = the back of the finger) after its parent: the spread about the hinge's up
--          (mirrored per side), then the curl about its right axis (toward the palm)
--   arm    the forearm pieces (sleeve, crew stripes or block, the watch): a frame at the wrist hinge whose +Z aims
--          at an off-screen elbow, rolled part of the way with the hand (so the sleeve always enters from the
--          bottom of the screen and the wrist bends, rule 6)

local FpRig = {}

export type Seg = { piece: string, joint: string, parent: number?, link: any, rest: any }
export type Piece = { piece: string, joint: string, rest: any }
export type Hand = {
	side: string, -- "Right" / "Left"
	sign: number, -- +1 right, -1 left (mirrors spread and across)
	rigid: { Piece },
	segs: { Seg },
	arm: { Piece },
	wrist: any, -- CFrame: the wrist hinge in grip space (scaled)
	entries: { any }, -- the RookieData entries kept (chain order)
}

local function v3(V3: any, t: { number }, s: number): any
	return V3.new(t[1] * s, t[2] * s, t[3] * s)
end

-- One hand from RookieData.fpArms[side] at `scale`; keep(entry) picks the outfit's variant pieces (cuff, sweater).
function FpRig.build(CF: any, V3: any, side: string, list: { any }, scale: number, keep: ((any) -> boolean)?): Hand
	local hand: Hand = {
		side = side,
		sign = if side == "Right" then 1 else -1,
		rigid = {},
		segs = {},
		arm = {},
		wrist = CF.new(0, 0, 0.2 * scale),
		entries = {},
	}
	local hinges: { [string]: any } = {}
	local index: { [string]: number } = {}
	for _, e in list do
		if keep == nil or keep(e) then
			table.insert(hand.entries, e)
			local hinge = v3(V3, e.hinge, scale)
			local part = CF.new(hinge + v3(V3, e.centre, scale))
			if e.frame == "arm" then
				hand.wrist = CF.new(hinge)
				table.insert(hand.arm, { piece = e.piece, joint = e.joint, rest = CF.new(hinge):Inverse() * part })
			elseif e.look and e.parent ~= nil then
				local look = V3.new(e.look[1], e.look[2], e.look[3])
				local up = V3.new(e.up[1], e.up[2], e.up[3])
				local h = CF.lookAt(hinge, hinge + look, up)
				local parent = if e.parent and e.parent ~= "Palm" then index[e.parent] else nil
				local link = if parent and e.parent then hinges[e.parent]:Inverse() * h else h
				table.insert(hand.segs, {
					piece = e.piece,
					joint = e.joint,
					parent = parent,
					link = link,
					rest = h:Inverse() * part,
				})
				index[e.joint] = #hand.segs
				hinges[e.joint] = h
			else
				table.insert(hand.rigid, { piece = e.piece, joint = e.joint, rest = part })
			end
		end
	end
	return hand
end

-- The pieces of RookieData.fpArms an outfit wears (Outfit: slot -> id): everything but the other glove cuff and the
-- other sweater variant's stripes / block.
function FpRig.wears(outfit: { [string]: string }): (any) -> boolean
	local gloves = string.gsub(outfit.gloves or "", "^Gloves_", "")
	local sweater = string.gsub(outfit.sweater or "", "^Sweater_", "")
	return function(e: any): boolean
		if e.slot == "gloves" then
			return e.variant == gloves
		elseif e.slot == "sweater" then
			return e.variant == sweater
		end
		return true
	end
end

-- The forearm frame: at the wrist (handCf * wrist), its +Z toward `elbow` (camera space, scaled), its up the camera's
-- up turned `roll` (0..1) of the way to the hand's up.
function FpRig.armFrame(CF: any, V3: any, hand: Hand, handCf: any, elbow: any, roll: number): any
	local w = (handCf * hand.wrist).Position
	local back = elbow - w
	if back.Magnitude < 1e-6 then
		return handCf * hand.wrist
	end
	back = back.Unit
	local up = V3.new(0, 1, 0):Lerp(handCf.UpVector, math.clamp(roll, 0, 1))
	if math.abs(up.Unit:Dot(back)) > 0.98 then
		up = handCf.UpVector
	end
	return CF.lookAt(w, w - back, up)
end

-- The wrist's bend (degrees): the angle between the hand's +Z (the back of the grip, toward the wrist) and the
-- forearm's +Z. A natural first-person wrist stays under ~55 (the tests check every pose).
function FpRig.wristBend(handCf: any, armCf: any): number
	local a = handCf.LookVector * -1
	local b = armCf.LookVector * -1
	return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
end

-- Every piece of a hand placed: { { piece, cf } } (camera space when handCf / elbow are), for joint angles
-- (ViewmodelMath.fingers: joint -> { curl, spread }).
function FpRig.place(
	CF: any,
	V3: any,
	hand: Hand,
	handCf: any,
	elbow: any,
	angles: { [string]: { number } },
	roll: number
): { { any } }
	local out: { { any } } = {}
	for _, p in hand.rigid do
		table.insert(out, { p.piece, handCf * p.rest })
	end
	local X, Y = V3.new(1, 0, 0), V3.new(0, 1, 0)
	local frames: { any } = {}
	for i, s in hand.segs do
		local a = angles[s.joint] or { 0, 0 }
		local base = if s.parent then frames[s.parent] else handCf
		local f = base * s.link * CF.fromAxisAngle(Y, math.rad(a[2] * hand.sign)) * CF.fromAxisAngle(X, -math.rad(a[1]))
		frames[i] = f
		table.insert(out, { s.piece, f * s.rest })
	end
	if #hand.arm > 0 then
		local armCf = FpRig.armFrame(CF, V3, hand, handCf, elbow, roll)
		for _, p in hand.arm do
			table.insert(out, { p.piece, armCf * p.rest })
		end
	end
	return out
end

-- FP HANDS v2 (Rookie_FPHands, RookieData.fpHands): ONE skinned glove MeshPart a hand. Its Bones are FpRig entries
-- too (piece = the Bone's name): Root / Forearm ride the forearm frame like the glove MeshPart, Hand the hand frame,
-- the finger and thumb bones are hinged segments. FpRig.place gives every bone's wanted frame; the Bone.Transform that
-- puts it there is worked out against the Bone's real rest CFrame (read from the mesh), so the bone axes the importer
-- chose never matter: offset O = (the hinge frame at rest)^-1 * (the Bone's rest), both in the glove part's space.
export type Skin = {
	glove: string, -- the glove's piece name
	order: { string }, -- Bone names, parents first
	parent: { [string]: string? }, -- Bone name -> its parent Bone's name (nil: the MeshPart)
	rest: { [string]: any }, -- Bone name -> Bone.CFrame (relative to its parent)
	base: { [string]: any }, -- Bone name -> rest in the glove part's space
	offset: { [string]: any }, -- Bone name -> O
}

-- The rest pose's frames in grip space (handCf = the grip, the forearm straight back): { piece -> CFrame }.
function FpRig.restFrames(CF: any, V3: any, hand: Hand): { [string]: any }
	local w = hand.wrist.Position
	local out: { [string]: any } = {}
	for _, pc in FpRig.place(CF, V3, hand, CF.new(), w + V3.new(0, 0, 1), {}, 0) do
		out[pc[1]] = pc[2]
	end
	return out
end

-- order: the glove's Bone names, parents first; parent: Bone -> parent Bone (nil = the MeshPart); rest: Bone ->
-- Bone.CFrame. Bones the hand has no entry for keep their rest.
function FpRig.skin(
	CF: any,
	V3: any,
	hand: Hand,
	glove: string,
	order: { string },
	parent: { [string]: string? },
	rest: { [string]: any }
): Skin
	local frames = FpRig.restFrames(CF, V3, hand)
	local g = frames[glove] or CF.new()
	local base: { [string]: any } = {}
	local offset: { [string]: any } = {}
	for _, name in order do
		local p = parent[name]
		base[name] = (if p then base[p] else CF.new()) * rest[name]
		local h = frames[name]
		offset[name] = if h then (g:Inverse() * h):Inverse() * base[name] else CF.new()
	end
	return { glove = glove, order = order, parent = parent, rest = rest, base = base, offset = offset }
end

-- Each Bone's Transform for this frame from FpRig.place's output ({ piece, cf } with the glove and every bone).
function FpRig.boneTransforms(CF: any, skin: Skin, placed: { { any } }): { [string]: any }
	local at: { [string]: any } = {}
	for _, pc in placed do
		at[pc[1]] = pc[2]
	end
	local P = at[skin.glove]
	local want: { [string]: any } = {}
	local out: { [string]: any } = {}
	for _, name in skin.order do
		local h = at[name]
		local d = if P and h then P:Inverse() * h * skin.offset[name] else skin.base[name]
		want[name] = d
		local p = skin.parent[name]
		local from = (if p then want[p] else CF.new()) * skin.rest[name]
		out[name] = from:Inverse() * d
	end
	return out
end

return table.freeze(FpRig)
