-- L1: first-person finger poses (fp_hands.md rule 17; Heist/ViewmodelMath.fingers / joints, Config.FirstPerson
-- .VIEWMODEL.HANDS). Every pose names every finger with sane angles; rest is the relaxed curl, a look target opens the
-- hand, carrying grips, each action asks for its own pose on the hands it moves, the look cue points, blends are
-- continuous and clamped (an anticipation never folds a finger the wrong way), the joints follow the chain, the old
-- 6-joint keys still come out (placeholder, Rookie_Hands fallback), the springs settle; and the old Rookie_Hands
-- data stays a valid fallback chain.

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local FpMath = require("../../src/client/Heist/FpMath")
local ViewmodelMath = require("../../src/client/Heist/ViewmodelMath")
local RookieData = require("../../src/shared/Heist/RookieData") :: any

local VM = Config.FirstPerson.VIEWMODEL
local H = VM.HANDS
local FINGERS = { "index", "middle", "ring", "pinky", "thumb" }
local JOINTS = {}
for _, f in { "Index", "Middle", "Ring", "Pinky", "Thumb" } do
	for i = 1, 3 do
		table.insert(JOINTS, f .. i)
	end
end
local LEGACY = { "Index1", "Index2", "Fingers1", "Fingers2", "Thumb1", "Thumb2" }

local function frame(carry: number, actions: { [string]: number }, point: number?, ready: number?): any
	return { carry = carry, actions = actions, point = point, ready = ready }
end

local function same(a: any, pose: string, what: string)
	local want = ViewmodelMath.joints(H, H.POSES[pose])
	for _, j in JOINTS do
		Assert.near(a[j][1], want[j][1], 1e-9, what .. " " .. j .. " curl")
		Assert.near(a[j][2], want[j][2], 1e-9, what .. " " .. j .. " spread")
	end
end

return function(test)
	test("every pose names every finger with sane angles; the brief's poses all exist", function()
		for _, name in { "open", "ready", "grip", "push", "point", "press", "handsUp", "reach" } do
			Assert.truthy(H.POSES[name] ~= nil, "pose " .. name)
			Assert.truthy(table.find(H.ORDER, name) ~= nil, name .. " in ORDER")
		end
		for name, p in H.POSES do
			for _, f in FINGERS do
				local v = p[f]
				Assert.truthy(v ~= nil, name .. " has " .. f)
				Assert.truthy(v[1] >= -20 and v[1] <= 90, name .. " " .. f .. " curl in range")
				Assert.truthy(v[2] >= -45 and v[2] <= 60, name .. " " .. f .. " spread in range")
				Assert.truthy((v[3] or 0) >= -15 and (v[3] or 0) <= 30, name .. " " .. f .. " bend in range")
			end
		end
		for action, hands in H.ACTIONS do
			Assert.truthy(VM.ACTIONS[action] ~= nil, "hand action " .. action .. " is an arm action")
			for _, pose in hands do
				Assert.truthy(H.POSES[pose] ~= nil, action .. " -> " .. pose)
			end
		end
	end)

	test(
		"joints: 3 per finger by the chain, the bend on the 2nd and 3rd, spread at the base; old keys derived",
		function()
			local j = ViewmodelMath.joints(H, { index = { 20, 6, 10 }, middle = { 10, 0, 0 }, thumb = { 30, 12 } })
			Assert.near(j.Index1[1], 20 * H.CHAIN[1], 1e-9, "MCP")
			Assert.near(j.Index2[1], 20 * H.CHAIN[2] + 10, 1e-9, "PIP + bend")
			Assert.near(j.Index3[1], 20 * H.CHAIN[3] + 10, 1e-9, "DIP + bend")
			Assert.near(j.Index1[2], 6, 1e-9, "spread on the base")
			Assert.near(j.Index2[2], 0, 1e-9, "no spread further out")
			Assert.near(j.Thumb1[1], 30 * H.THUMB_CHAIN[1], 1e-9, "thumb chain")
			Assert.near(j.Thumb1[2], 12, 1e-9, "the thumb's across on its base")
			Assert.near(j.Fingers1[1], j.Middle1[1], 1e-9, "old Fingers1 = the middle finger")
			Assert.near(j.Fingers2[1], j.Middle2[1], 1e-9, "old Fingers2")
			local all = ViewmodelMath.joints(H, H.POSES.open)
			for _, k in JOINTS do
				Assert.truthy(all[k] ~= nil, "joint " .. k)
			end
			for _, k in LEGACY do
				Assert.truthy(all[k] ~= nil, "old joint " .. k)
			end
		end
	)

	test(
		"rest is the relaxed curl, a look target opens it, carrying grips, actions take their pose, the cue points",
		function()
			local R, L = ViewmodelMath.fingers(VM, frame(0, {}))
			same(R, "open", "rest R")
			same(L, "open", "rest L")
			R = ViewmodelMath.fingers(VM, frame(0, {}, 0, 1))
			same(R, "ready", "look target R")
			R, L = ViewmodelMath.fingers(VM, frame(1, {}))
			same(R, "grip", "carry R")
			same(L, "grip", "carry L")
			R = ViewmodelMath.fingers(VM, frame(0, { push = 1 }))
			same(R, "push", "push: flat palm")
			R, L = ViewmodelMath.fingers(VM, frame(0, { watch = 1 }))
			same(R, "press", "watch: the right index presses")
			same(L, "push", "watch: the left hand flat")
			R, L = ViewmodelMath.fingers(VM, frame(0, { handsUp = 1 }))
			same(R, "handsUp", "caught R")
			same(L, "handsUp", "caught L")
			R = ViewmodelMath.fingers(VM, frame(0, {}, 1))
			same(R, "point", "look cue")
			R, L = ViewmodelMath.fingers(VM, frame(0, { reach = 1 }))
			same(R, "reach", "reach spreads the right hand")
			same(L, "open", "the left stays relaxed")
			-- an anticipation dip (weight < 0) or an overshoot (> 1) never pushes a finger past either pose
			R = ViewmodelMath.fingers(VM, frame(0, { reach = -0.3 }))
			same(R, "open", "anticipation: fingers stay relaxed")
			R = ViewmodelMath.fingers(VM, frame(0, { reach = 1.08 }))
			same(R, "reach", "overshoot: fingers stop at the pose")
		end
	)

	test("the relaxed curl cascades; point and grip read", function()
		local O = H.POSES.open
		Assert.truthy(O.index[1] < O.middle[1] and O.middle[1] < O.ring[1] and O.ring[1] < O.pinky[1], "cascade")
		Assert.truthy(O.index[1] > 5, "relaxed: never ruler-straight")
		local P, G = H.POSES.point, H.POSES.grip
		Assert.truthy(math.abs(P.index[1]) + math.abs(P.index[3]) < 15, "point: index straight")
		Assert.truthy(P.middle[1] > 60 and P.ring[1] > 60 and P.pinky[1] > 60, "point: the others folded")
		Assert.truthy(G.index[1] > 40 and G.middle[1] > 40 and G.thumb[2] > 20, "grip: wrapped, thumb across")
		Assert.truthy(H.POSES.push.middle[1] <= 0, "push: flat or bent back")
		Assert.truthy(H.POSES.press.index[3] > H.POSES.point.index[3], "press: the tip bends onto the button")
		Assert.truthy(H.POSES.ready.middle[1] < O.middle[1], "ready opens the hand")
	end)

	test("blends are continuous: half the carry is half way to the grip", function()
		local R = ViewmodelMath.fingers(VM, frame(0.5, {}))
		local a, b = ViewmodelMath.joints(H, H.POSES.open), ViewmodelMath.joints(H, H.POSES.grip)
		for _, j in JOINTS do
			Assert.near(R[j][1], (a[j][1] + b[j][1]) / 2, 1e-9, "half carry " .. j)
		end
	end)

	test("the finger springs settle on the target without blowing up at any frame time", function()
		for _, dt in { 1 / 240, 1 / 60, 1 / 20, 0.1 } do
			local x, v = 0, 0
			for _ = 1, math.floor(1.5 / dt) do
				x, v = FpMath.spring(x, v, 80, dt, H.FREQ, H.DAMPING)
				Assert.truthy(x == x and math.abs(x) < 200, "bounded at dt " .. dt)
			end
			Assert.near(x, 80, 1, "settled at dt " .. dt)
		end
	end)

	test("Rookie_Hands (the fallback gloves): a palm and six segments a side in one chain, parents first", function()
		Assert.truthy(RookieData.hands ~= nil, "RookieData.hands")
		for _, side in { "Right", "Left" } do
			local segs = RookieData.hands[side]
			Assert.eq(#segs, 7, side .. " segments")
			local seen = {}
			for _, h in segs do
				if h.parent then
					Assert.truthy(seen[h.parent], side .. " " .. h.joint .. " after its parent " .. h.parent)
				end
				Assert.truthy(h.offset[2] <= 0, side .. " " .. h.joint .. " at or below the wrist")
				Assert.truthy(RookieData.tint[h.piece] == "gloves", h.piece .. " takes the glove colour")
				seen[h.joint] = true
			end
			for _, j in LEGACY do
				Assert.truthy(seen[j], side .. " has " .. j)
			end
		end
	end)
end
