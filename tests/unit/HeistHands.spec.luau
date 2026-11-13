-- L1: first-person finger poses (REVIEW_STEAM_PLUS #10; Heist/ViewmodelMath.fingers, Config.FirstPerson.VIEWMODEL
-- .HANDS) and the Rookie_Hands data (RookieData.hands). Every pose names every joint; rest is open, carrying grips,
-- each action asks for its own pose on the hands it moves, the look cue points, blends are continuous, the springs
-- settle, and the glove segments form one chain per side with parents first.

local Assert = require("./Assert")
local Config = require("../../src/shared/Config")
local FpMath = require("../../src/client/Heist/FpMath")
local ViewmodelMath = require("../../src/client/Heist/ViewmodelMath")
local RookieData = require("../../src/shared/Heist/RookieData") :: any

local VM = Config.FirstPerson.VIEWMODEL
local H = VM.HANDS
local JOINTS = { "Index1", "Index2", "Fingers1", "Fingers2", "Thumb1", "Thumb2" }

local function frame(carry: number, actions: { [string]: number }, point: number?): any
	return { carry = carry, actions = actions, point = point }
end

local function same(a: any, pose: string, what: string)
	for _, j in JOINTS do
		Assert.near(a[j][1], H.POSES[pose][j][1], 1e-9, what .. " " .. j .. " curl")
		Assert.near(a[j][2], H.POSES[pose][j][2], 1e-9, what .. " " .. j .. " across")
	end
end

return function(test)
	test("every pose names every joint with sane angles; the brief's poses all exist", function()
		for _, name in { "open", "grip", "push", "point", "press", "handsUp", "reach" } do
			Assert.truthy(H.POSES[name] ~= nil, "pose " .. name)
			Assert.truthy(table.find(H.ORDER, name) ~= nil, name .. " in ORDER")
		end
		for name, p in H.POSES do
			for _, j in JOINTS do
				local v = p[j]
				Assert.truthy(v ~= nil, name .. " has " .. j)
				Assert.truthy(v[1] >= -30 and v[1] <= 100, name .. " " .. j .. " curl in range")
				Assert.truthy(v[2] >= -45 and v[2] <= 60, name .. " " .. j .. " across in range")
			end
		end
		for action, hands in H.ACTIONS do
			Assert.truthy(VM.ACTIONS[action] ~= nil, "hand action " .. action .. " is an arm action")
			for _, pose in hands do
				Assert.truthy(H.POSES[pose] ~= nil, action .. " -> " .. pose)
			end
		end
	end)

	test("rest is open, carrying grips, actions take their pose, the look cue points", function()
		local R, L = ViewmodelMath.fingers(VM, frame(0, {}))
		same(R, "open", "rest R")
		same(L, "open", "rest L")
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
		same(L, "open", "the left stays open")
	end)

	test("point and grip read: index straight with the rest folded; every finger folded round the loot", function()
		local P, G = H.POSES.point, H.POSES.grip
		Assert.truthy(math.abs(P.Index1[1]) + math.abs(P.Index2[1]) < 15, "point: index straight")
		Assert.truthy(P.Fingers1[1] > 70 and P.Fingers2[1] > 70, "point: the others folded")
		Assert.truthy(G.Index1[1] > 60 and G.Fingers1[1] > 60 and G.Thumb1[2] > 20, "grip: wrapped, thumb across")
		Assert.truthy(H.POSES.push.Fingers1[1] <= 0, "push: flat or bent back")
		Assert.truthy(H.POSES.press.Index2[1] > H.POSES.point.Index2[1], "press: the tip bends onto the button")
	end)

	test("blends are continuous: half the carry is half way to the grip", function()
		local R = ViewmodelMath.fingers(VM, frame(0.5, {}))
		for _, j in JOINTS do
			local want = (H.POSES.open[j][1] + H.POSES.grip[j][1]) / 2
			Assert.near(R[j][1], want, 1e-9, "half carry " .. j)
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

	test(
		"Rookie_Hands: per side a palm and six segments in one chain, parents first, hinges below the wrist",
		function()
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
				for _, j in JOINTS do
					Assert.truthy(seen[j], side .. " has " .. j)
				end
			end
			-- the thumb and index sit on the inner side (toward the body: -X for the right hand)
			local function find(side: string, joint: string): any
				for _, h in RookieData.hands[side] do
					if h.joint == joint then
						return h
					end
				end
				return nil
			end
			Assert.truthy(
				find("Right", "Thumb1").offset[1] < 0 and find("Left", "Thumb1").offset[1] > 0,
				"thumbs inside"
			)
		end
	)
end
