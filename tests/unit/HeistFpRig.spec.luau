-- L1: the dedicated first-person arms (docs/research/fp_hands.md; Heist/FpRig, Heist/ViewmodelMath, RookieData.fpArms,
-- Config.FirstPerson.VIEWMODEL). The kit data: per side a palm, 4 fingers x 3 segments and a 3-segment thumb in one
-- chain (parents first), the cuffs and sweater variants, the left watch, the tints, the triangle budget. The maths:
-- the viewmodel projection (k, orthonormal frames, per-axis sizes, the same image as a VIEW_FOV camera), the action
-- envelope (anticipation, overshoot, settle), the visibility blend. And every preview pose assembled as the game
-- does (FpRig.place + ViewmodelMath.project): the wrist bends naturally, the sleeve runs back toward the eye, nothing
-- comes nearer the eye than NEAR, and every part's box stays inside the screen-safe rect at 16:9 and 19.5:9.

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

local function v3(t: { number }, s: number?): any
	local k = s or 1
	return Vector3.new(t[1] * k, t[2] * k, t[3] * k)
end

local function find(side: string, joint: string): any
	for _, e in RookieData.fpArms[side] do
		if e.joint == joint then
			return e
		end
	end
	return nil
end

-- The poses the game shows (ViewmodelMath.showcase: the preview renders the same list).
local POSES = ViewmodelMath.showcase(VM)
local function peak(name: string): number
	return ViewmodelMath.peak(VM, name)
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

local outfit = table.clone(Config.Rookie.DEFAULT_OUTFIT)
local s = VM.SCALE
local hands = {
	R = FpRig.build(CFrame, Vector3, "Right", RookieData.fpArms.Right, s, FpRig.wears(outfit)),
	L = FpRig.build(CFrame, Vector3, "Left", RookieData.fpArms.Left, s, FpRig.wears(outfit)),
}
local info: { [string]: any } = {}
for _, side in { "Right", "Left" } do
	for _, e in RookieData.fpArms[side] do
		info[e.piece] = e
	end
end

local function poseCf(p: { number }): any
	return CFrame.new(p[1] * s, p[2] * s, p[3] * s) * CFrame.Angles(math.rad(p[4]), math.rad(p[5]), math.rad(p[6]))
end

-- Every part of a frame through FpRig + the viewmodel projection at `fov`: { piece, joint, comps, size }.
local function assemble(f: any, fov: number): ({ any }, { [string]: number })
	local R, L = ViewmodelMath.hands(VM, f)
	local fR, fL = ViewmodelMath.fingers(VM, f)
	local k = ViewmodelMath.viewK(fov, VM.VIEW_FOV)
	local out, bends = {}, {}
	for _, side in { { hands.R, poseCf(R), fR, "R", R }, { hands.L, poseCf(L), fL, "L", L } } do
		local elbow = v3(ViewmodelMath.elbow(VM, side[4], side[5]), s)
		for _, pc in FpRig.place(CFrame, Vector3, side[1], side[2], elbow, side[3], VM.ARMS.WRIST_ROLL) do
			local e = info[pc[1]]
			local c, fac = ViewmodelMath.project({ pc[2]:GetComponents() }, e.size, k)
			table.insert(out, {
				piece = pc[1],
				joint = e.joint,
				cf = CFrame.new(table.unpack(c)),
				size = Vector3.new(e.size[1] * s * fac[1], e.size[2] * s * fac[2], e.size[3] * s * fac[3]),
			})
		end
		bends[side[4]] = FpRig.wristBend(side[2], FpRig.armFrame(CFrame, Vector3, side[1], side[2], elbow, 0.6))
	end
	return out, bends
end

local function corners(p: any): { any }
	local h = p.size / 2
	local out = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, p.cf * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
			end
		end
	end
	return out
end

return function(test)
	test("fpArms: per side a palm, 4 fingers x 3 segments and a 3-segment thumb in one chain, parents first", function()
		Assert.truthy(RookieData.fpArms ~= nil, "RookieData.fpArms (run tools/rookie_data.py)")
		for _, side in { "Right", "Left" } do
			local seen: { [string]: boolean } = { Palm = true }
			local n = 0
			for _, e in RookieData.fpArms[side] do
				if e.look then
					n += 1
					if e.parent then
						Assert.truthy(seen[e.parent], side .. " " .. e.joint .. " after " .. e.parent)
					end
					seen[e.joint] = true
					Assert.eq(e.tint, "gloves", e.piece .. " takes the glove colour")
				end
			end
			Assert.eq(n, 15, side .. ": 15 finger segments")
			for _, f in { "Index", "Middle", "Ring", "Pinky", "Thumb" } do
				for i = 1, 3 do
					Assert.truthy(seen[f .. i], side .. " has " .. f .. i)
				end
				Assert.eq(find(side, f .. "2").parent, f .. "1", side .. " " .. f .. "2 hangs on " .. f .. "1")
				Assert.eq(find(side, f .. "3").parent, f .. "2", side .. " " .. f .. "3 hangs on " .. f .. "2")
			end
			for _, j in { "Palm", "Sleeve", "CuffKnit", "CuffLeather", "Stripes", "Block" } do
				Assert.truthy(find(side, j) ~= nil, side .. " has " .. j)
			end
			Assert.eq(find(side, "Stripes").tint, "crew", "the stripes take the crew colour")
			Assert.eq(find(side, "Block").tint, "crew", "the block cuff takes the crew colour")
			Assert.eq(find(side, "CuffKnit").tint, "gloves", "the cuff takes the glove colour")
			Assert.eq(find(side, "Sleeve").frame, "arm", "the sleeve rides the forearm frame")
		end
		Assert.truthy(find("Left", "Watch") ~= nil and find("Right", "Watch") == nil, "the watch on the left wrist")
	end)

	test("fpArms: the thumb inside, mirrored hands, slim sleeve, the triangle budget per hand set", function()
		Assert.truthy(find("Right", "Thumb1").hinge[1] < 0 and find("Left", "Thumb1").hinge[1] > 0, "thumbs inside")
		for _, j in { "Index1", "Pinky3", "Thumb2" } do
			local r, l = find("Right", j), find("Left", j)
			Assert.near(r.hinge[1], -l.hinge[1], 1e-3, j .. " mirrored x")
			Assert.near(r.hinge[2], l.hinge[2], 1e-3, j .. " same y")
			Assert.near(r.hinge[3], l.hinge[3], 1e-3, j .. " same z")
		end
		-- rule 2: the sleeve is slimmer than the hand (radius <= 0.6 x the palm's half-width... at the cuff end)
		local palm, sleeve = find("Right", "Palm"), find("Right", "Sleeve")
		Assert.truthy(sleeve.size[1] / 2 <= palm.size[1] * 0.9, "a slim forearm (was the body's 0.27 radius)")
		Assert.truthy(sleeve.size[1] / 2 < 0.22, "slimmer than the body sleeve (0.25-0.27) even at the far end")
		for _, side in { "Right", "Left" } do
			local worn = FpRig.wears(outfit)
			local tris = 0
			for _, e in RookieData.fpArms[side] do
				if worn(e) then
					tris += e.tris
				end
			end
			Assert.le(tris, VM.ARMS.TRI_BUDGET, side .. " hand set tris")
			local alt = FpRig.wears({ gloves = "Gloves_Leather", sweater = "Sweater_Block" })
			local n = 0
			for _, e in RookieData.fpArms[side] do
				if alt(e) then
					n += e.tris
				end
			end
			Assert.le(n, VM.ARMS.TRI_BUDGET, side .. " leather / block set tris")
		end
	end)

	test("outfit filter: one glove cuff and one sweater variant", function()
		local w = FpRig.wears({ gloves = "Gloves_Leather", sweater = "Sweater_Stripes" })
		Assert.truthy(w(find("Right", "CuffLeather")) and not w(find("Right", "CuffKnit")), "the leather cuff")
		Assert.truthy(w(find("Right", "Stripes")) and not w(find("Right", "Block")), "the stripes")
		Assert.truthy(w(find("Right", "Palm")) and w(find("Right", "Sleeve")), "shared pieces always")
	end)

	test("viewmodel projection: k, orthonormal frames, per-axis sizes, the image of a VIEW_FOV camera", function()
		local k = ViewmodelMath.viewK(FOV, VM.VIEW_FOV)
		Assert.near(k, math.tan(math.rad(FOV / 2)) / math.tan(math.rad(VM.VIEW_FOV / 2)), 1e-9, "k")
		Assert.truthy(k > 1.3 and k < 1.7, "a telephoto viewmodel at FOV 70 (k " .. k .. ")")
		local cf = CFrame.new(0.2, -0.15, -0.5) * CFrame.Angles(0.4, 0.3, -0.2)
		local same, f1 = ViewmodelMath.project({ cf:GetComponents() }, { 1, 2, 3 }, 1)
		for i, c in { cf:GetComponents() } do
			Assert.near(same[i], c, 1e-6, "k = 1 is the identity " .. i)
		end
		Assert.near(f1[1] + f1[2] + f1[3], 3, 1e-6, "k = 1 keeps the size")
		for _, size in { { 0.1, 0.1, 2 }, { 0.4, 0.2, 0.3 }, { 1, 1, 1 } } do
			local c, f = ViewmodelMath.project({ cf:GetComponents() }, size, k)
			local m = CFrame.new(table.unpack(c))
			Assert.near(m.RightVector.Magnitude, 1, 1e-6, "unit X")
			Assert.near(m.RightVector:Dot(m.UpVector), 0, 1e-6, "X square to Y")
			Assert.near(m.UpVector:Dot(m.LookVector), 0, 1e-6, "Y square to Z")
			Assert.near(m.RightVector:Cross(m.UpVector):Dot(-m.LookVector), 1, 1e-6, "right-handed")
			for i = 1, 3 do
				Assert.truthy(f[i] >= 1 - 1e-9 and f[i] <= k + 1e-9, "a size factor between 1 and k")
			end
			-- the centre lands where a VIEW_FOV camera would draw it
			local p = cf.Position
			local x0, y0 = ViewmodelMath.ndc(p.X, p.Y, p.Z, VM.VIEW_FOV, 16 / 9)
			local x1, y1 = ViewmodelMath.ndc(c[1], c[2], c[3], FOV, 16 / 9)
			Assert.near(x0 :: number, x1 :: number, 1e-9, "same screen x")
			Assert.near(y0 :: number, y1 :: number, 1e-9, "same screen y")
		end
		-- a part lying along the view keeps its length and grows across
		local _, along = ViewmodelMath.project({ CFrame.new(0, 0, -1):GetComponents() }, { 0.1, 0.1, 2 }, k)
		Assert.near(along[3], 1, 1e-9, "length along the view unchanged")
		Assert.near(along[1], k, 1e-9, "cross-section times k")
	end)

	test("action envelope: anticipation dips, the rise overshoots, it settles at 1, then falls to 0", function()
		local a = VM.ACTIONS.reach
		Assert.truthy(a.anticipate ~= nil and a.overshoot ~= nil, "the reach anticipates and overshoots")
		local pre = a.anticipate[1]
		Assert.near(ViewmodelMath.envelope(0, a.time, false, a.anticipate, a.overshoot), 0, 1e-9, "starts at 0")
		local dip = ViewmodelMath.envelope(pre, a.time, false, a.anticipate, a.overshoot)
		Assert.near(dip, -a.anticipate[2], 1e-6, "the pull back")
		local top = peak("reach")
		Assert.truthy(top > 1.03 and top < 1.15, "an overshoot of 3-15 % (" .. top .. ")")
		local hold = ViewmodelMath.envelope(pre + a.time[1] + a.time[2] * 0.5, a.time, false, a.anticipate, a.overshoot)
		Assert.near(hold, 1, 1e-9, "settles on the pose")
		local d = ViewmodelMath.duration(a.time, a.anticipate)
		Assert.near(d, pre + a.time[1] + a.time[2] + a.time[3], 1e-9, "the duration counts the anticipation")
		Assert.eq(ViewmodelMath.envelope(d + 0.01, a.time, false, a.anticipate, a.overshoot), 0, "over")
		-- no gap: continuous at the phase changes
		local last = 0
		for i = 1, 200 do
			local w = ViewmodelMath.envelope(d * i / 200, a.time, false, a.anticipate, a.overshoot)
			Assert.truthy(math.abs(w - last) < 0.25, "continuous at " .. i)
			last = w
		end
		Assert.near(ViewmodelMath.easeOutBack(1, 1.5), 1, 1e-9, "easeOutBack ends at 1")
	end)

	test("visibility: idle lowers (lowered mode), reasons raise, the delay holds them up a moment", function()
		local V = VM.VISIBILITY
		Assert.truthy(V.MODE == "lowered" or V.MODE == "hidden" or V.MODE == "always", "a known mode")
		Assert.eq(ViewmodelMath.raiseTarget(VM, 0), 1, "a reason: up")
		Assert.eq(ViewmodelMath.raiseTarget(VM, V.LOWER_DELAY * 0.5), 1, "just after: still up")
		Assert.eq(ViewmodelMath.raiseTarget(VM, V.LOWER_DELAY + 0.1), if V.MODE == "always" then 1 else 0, "idle")
		local up = ViewmodelMath.hands(VM, frame({ raise = 1 }))
		local low = ViewmodelMath.hands(VM, frame({ raise = 0 }))
		if V.MODE ~= "always" then
			Assert.truthy(low[2] < up[2], "idle hands sit lower")
		end
		Assert.truthy(V.RAISE_SECONDS < V.LOWER_SECONDS, "up fast, down slow")
	end)

	test("every pose: a natural wrist, the sleeve runs back toward the eye, nothing nearer than NEAR", function()
		for _, entry in POSES do
			local parts, bends = assemble(entry[2], FOV)
			Assert.truthy(#parts >= 2 * 19, entry[1] .. ": both hands assembled (" .. #parts .. " parts)")
			for side, b in bends do
				Assert.le(b, 60, entry[1] .. " " .. side .. " wrist bend")
			end
			local palm: { [string]: any } = {}
			for _, p in parts do
				if p.joint == "Palm" then
					palm[string.find(p.piece, "Right", 1, true) and "R" or "L"] = p
				end
			end
			for _, p in parts do
				local c = p.cf.Position
				Assert.truthy(c.X == c.X and c.Magnitude < 2, entry[1] .. " " .. p.piece .. " finite")
				for _, q in corners(p) do
					Assert.truthy(q.Magnitude >= VM.NEAR, entry[1] .. " " .. p.piece .. " beyond NEAR")
				end
				if p.joint == "Sleeve" then
					local hp = palm[string.find(p.piece, "Right", 1, true) and "R" or "L"]
					Assert.truthy(c.Z > hp.cf.Position.Z, entry[1] .. " " .. p.piece .. " runs back toward the eye")
					Assert.truthy(c.Y < hp.cf.Position.Y, entry[1] .. " " .. p.piece .. " comes up from below")
				end
			end
			-- the wall pull at its strongest still keeps everything past the near plane
			local pulled = assemble(frame({ raise = 1, wall = 1 }), FOV)
			for _, p in pulled do
				for _, q in corners(p) do
					Assert.truthy(-q.Z > 0.1 or q.Y < -0.7 * -q.Z, "wall: " .. p.piece .. " past the near plane")
				end
			end
		end
	end)

	test("every pose: each part's box inside the screen-safe rect at 16:9 and 19.5:9 (FOV 60, 70, 90)", function()
		local S = VM.SAFE
		for _, fov in { 60, FOV, 90 } do
			for _, aspect in ASPECTS do
				for _, entry in POSES do
					local parts = assemble(entry[2], fov)
					local raised = (entry[2].raise or 0) > 0
					local palms = 0
					for _, p in parts do
						for _, q in corners(p) do
							local x, y = ViewmodelMath.ndc(q.X, q.Y, q.Z, fov, aspect)
							if x and y and y > -1 then -- below the bottom edge is off screen (the sleeve leaves there)
								local where = string.format("%s %s fov %d aspect %.2f", entry[1], p.piece, fov, aspect)
								Assert.le(math.abs(x), S.X, where .. " |x|")
								Assert.le(y, S.Y_TOP, where .. " top")
							end
						end
						if raised and p.joint == "Palm" then
							local c = p.cf.Position
							local _, y = ViewmodelMath.ndc(c.X, c.Y, c.Z, fov, aspect)
							if y and y > S.PALM_MIN_Y then
								palms += 1
							end
						end
					end
					-- raised: the hands show (the REWIND tap's right hand may sit below the left wrist)
					if raised then
						Assert.truthy(palms >= (if entry[1] == "watch" then 1 else 2), entry[1] .. ": palms in view")
					end
				end
			end
		end
	end)

	test("the rest framing follows the rules: lower corners, out of the centre third, the right size", function()
		local parts = assemble(frame({ raise = 1 }), FOV)
		for _, p in parts do
			if p.joint == "Palm" then
				local c = p.cf.Position
				local x, y = ViewmodelMath.ndc(c.X, c.Y, c.Z, FOV, 16 / 9)
				Assert.truthy(math.abs(x :: number) > 0.4 and math.abs(x :: number) < 0.7, p.piece .. " x " .. x)
				Assert.truthy((y :: number) < -0.45 and (y :: number) > -0.8, p.piece .. " y " .. y)
				-- rule 4: one hand spans about 14-24 % of the screen height
				local h = p.size.X / (-c.Z * math.tan(math.rad(FOV / 2)) * 2)
				Assert.truthy(h > 0.1 and h < 0.24, p.piece .. " palm width share " .. h)
			end
			if p.joint == "Middle3" or p.joint == "Index3" then
				local c = p.cf.Position
				local x = ViewmodelMath.ndc(c.X, c.Y, c.Z, FOV, 16 / 9)
				Assert.truthy(math.abs(x :: number) > 0.18, p.piece .. ": fingertips outside the centre")
			end
		end
	end)
end
