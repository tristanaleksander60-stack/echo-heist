-- L1: Shared/Heist/RookieMoves (the Rookie's locomotion clips, REVIEW_STEAM_PLUS #6). The walk and run plant their
-- boots: while a foot is down its sole moves back under the body at exactly the clip's ground speed (no slide), the
-- legs stay in reach, no sole goes through the floor, loops close, and the speeds are the R15 Animate's.

local Config = require("../../src/shared/Config")
local RookieMoves = require("../../src/shared/Heist/RookieMoves")
local Assert = require("./Assert")

local A = Config.Rookie.ANIM

local function finite(x: number): boolean
	return x == x and x > -1e6 and x < 1e6
end

-- Worst sole slide (studs) of planted feet over one cycle of a gait clip, sampled `n` times.
local function slide(clip: string, n: number): (number, number, number)
	local S = if clip == "run" then RookieMoves.RUN_STRIDE else RookieMoves.WALK_STRIDE
	local L = RookieMoves.CLIPS[clip].length
	local worst, worstY, planted = 0, 0, 0
	for _, side in { "Right", "Left" } do
		local anchor: { number }? = nil
		local anchorQ = 0
		local mode = ""
		for i = 0, n - 1 do
			local p = i / n
			local feet = RookieMoves.feet(clip, p)
			local f = feet[side]
			local pose = RookieMoves.sample(clip, p * L)
			local toe, heel = RookieMoves.sole(pose, side)
			if f.planted then
				planted += 1
				-- the contact point: the heel while flat, then the toe (the roll)
				local flat = f.pitch == 0
				local pt = if flat then heel else toe
				local m = if flat then "flat" else "toe"
				if mode ~= m then
					anchor, anchorQ, mode = pt, p, m
				end
				local a = anchor :: { number }
				-- the floor moved back S x (cycles since the anchor)
				local dq = (p - anchorQ) % 1
				local want = a[3] + S * dq
				worst = math.max(worst, math.abs(pt[3] - want), math.abs(pt[1] - a[1]))
				worstY = math.max(worstY, math.abs(pt[2]))
			else
				mode = ""
			end
		end
	end
	return worst, worstY, planted
end

return function(test)
	test("speeds: the R15 Animate's walk 6.4 and run 12.8 studs/s at rate 1, equal cycles", function()
		Assert.near(RookieMoves.WALK_BASE, 6.4, 1e-9, "walk base")
		Assert.near(RookieMoves.RUN_BASE, 12.8, 1e-9, "run base")
		Assert.eq(RookieMoves.CLIPS.walk.length, RookieMoves.CLIPS.run.length, "same cycle: the blend stays in step")
		Assert.near(RookieMoves.WALK_STRIDE, RookieMoves.WALK_BASE * A.CYCLE, 1e-9, "stride")
	end)

	test("every clip: every joint keyed and finite at every key", function()
		for _, clip in RookieMoves.ORDER do
			for _, t in RookieMoves.keyTimes(clip) do
				local pose = RookieMoves.sample(clip, t)
				for _, part in RookieMoves.PARTS do
					local j = pose[part]
					Assert.truthy(j ~= nil, clip .. " keys " .. part)
					for k = 1, 6 do
						Assert.truthy(finite(j[k] or 0), clip .. " " .. part .. " finite")
					end
				end
			end
		end
	end)

	test("walk and run: planted soles never slide (< 0.02 studs a cycle) and stay on the floor", function()
		for _, clip in { "walk", "run" } do
			local worst, worstY, planted = slide(clip, 240)
			Assert.truthy(planted > 40, clip .. " has planted frames (" .. planted .. ")")
			Assert.le(worst, 0.02, string.format("%s sole slide %.4f studs", clip, worst))
			Assert.le(worstY, 0.02, string.format("%s planted sole height %.4f", clip, worstY))
		end
	end)

	test("walk and run: feet swap (one lands at 0, the other at 0.5); walk has double support, run a flight", function()
		local both, none = 0, 0
		for i = 0, 99 do
			local f = RookieMoves.feet("walk", i / 100)
			if f.Right.planted and f.Left.planted then
				both += 1
			end
			local r = RookieMoves.feet("run", i / 100)
			if not r.Right.planted and not r.Left.planted then
				none += 1
			end
		end
		Assert.truthy(both > 0, "walk: both feet down at the switch")
		Assert.truthy(none > 20, "run: both feet up (flight) " .. none .. " %")
		Assert.truthy(RookieMoves.feet("walk", 0).Right.planted, "right lands at 0")
		Assert.truthy(RookieMoves.feet("walk", 0.5).Left.planted, "left lands at 0.5")
	end)

	test("no sole goes through the floor in any standing clip", function()
		for _, clip in { "idle", "look", "walk", "run", "land" } do
			for _, t in RookieMoves.keyTimes(clip) do
				local pose = RookieMoves.sample(clip, t)
				for _, side in { "Right", "Left" } do
					local toe, heel = RookieMoves.sole(pose, side)
					Assert.truthy(
						toe[2] > -0.03 and heel[2] > -0.03,
						string.format("%s %s sole at t %.2f: toe %.3f heel %.3f", clip, side, t, toe[2], heel[2])
					)
				end
			end
		end
	end)

	test("standing clips keep the boots planted where they stand", function()
		for _, clip in { "idle", "look", "land" } do
			local ref = RookieMoves.sample(clip, 0)
			local rt = RookieMoves.sole(ref, "Right")
			for _, t in RookieMoves.keyTimes(clip) do
				local toe = RookieMoves.sole(RookieMoves.sample(clip, t), "Right")
				local d = math.sqrt((toe[1] - rt[1]) ^ 2 + (toe[2] - rt[2]) ^ 2 + (toe[3] - rt[3]) ^ 2)
				Assert.le(d, 0.02, string.format("%s right boot moved %.3f at %.2f", clip, d, t))
			end
		end
	end)

	test("loops close: the last key is the first", function()
		for _, clip in { "idle", "look", "walk", "run", "fall" } do
			local spec = RookieMoves.CLIPS[clip]
			Assert.truthy(spec.looped, clip .. " loops")
			local a, b = RookieMoves.sample(clip, 0), RookieMoves.sample(clip, spec.length - 1e-9)
			for _, part in RookieMoves.PARTS do
				for k = 1, 6 do
					Assert.near(a[part][k] or 0, b[part][k] or 0, 0.02, clip .. " seam " .. part)
				end
			end
		end
	end)

	test("acting reads: the run leans and pumps more than the walk; the walk's arms swing wide", function()
		local walkLean, runLean, walkArm, runArm, walkOut = 0, 0, 0, 0, 0
		for i = 0, 19 do
			local w = RookieMoves.sample("walk", A.CYCLE * i / 20)
			local r = RookieMoves.sample("run", A.CYCLE * i / 20)
			walkLean = math.min(walkLean, w.LowerTorso[1] + w.UpperTorso[1])
			runLean = math.min(runLean, r.LowerTorso[1] + r.UpperTorso[1])
			walkArm = math.max(walkArm, math.abs(w.RightUpperArm[1]))
			runArm = math.max(runArm, math.abs(r.RightUpperArm[1]))
			walkOut = math.max(walkOut, w.RightUpperArm[3])
		end
		Assert.truthy(runLean < walkLean - 0.1, "run leans further")
		Assert.truthy(runArm > walkArm + 0.3, "run pumps")
		Assert.truthy(walkOut >= 0.3, "walk arms wide")
		local idle = RookieMoves.sample("look", 1.2)
		Assert.truthy(idle.Head[2] > 0.4, "the look variant turns the head")
		local land = RookieMoves.sample("land", 0.08)
		Assert.truthy(land.LowerTorso[5] < -0.25, "land squashes")
	end)
end
