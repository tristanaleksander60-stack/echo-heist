-- L1: Shared/Heist/ScarfMath and Budget.scarfRigs (the Rookie's long scarf tail sways with movement; client
-- Heist/ScarfSway). It hangs at rest, streams out as modelled at running speed, swings away from a strafe and trails
-- a turn, a fall lifts it, it settles after a stop, it stays bounded at any frame time, and from a low tier it is off.

local Budget = require("../../src/shared/Heist/Budget")
local Config = require("../../src/shared/Config")
local ScarfMath = require("../../src/shared/Heist/ScarfMath")
local Assert = require("./Assert")

local S = Config.Rookie.SCARF

local function motion(forward: number, right: number, up: number, turn: number): ScarfMath.Motion
	return { forward = forward, right = right, up = up, turn = turn }
end

local function run(m: ScarfMath.Motion, seconds: number, dt: number, s: ScarfMath.State?): ScarfMath.State
	local st = s or ScarfMath.new()
	for _ = 1, math.floor(seconds / dt + 0.5) do
		ScarfMath.step(st, m, dt, S)
	end
	return st
end

return function(test)
	test("rest: it hangs (DROOP); running: it streams out as modelled; slow: in between", function()
		local idle = run(motion(0, 0, 0, 0), 4, 1 / 60)
		Assert.near(idle.p1, S.DROOP, 1, "standing: the root segment hangs")
		Assert.truthy(idle.p2 > 0, "and the end hangs a little more")
		Assert.near(idle.y1, 0, 1e-3, "no swing sideways")
		local fast = run(motion(S.RUN_SPEED * 1.5, 0, 0, 0), 4, 1 / 60)
		Assert.truthy(math.abs(fast.p1) < 4, "running: back to the modelled (streaming) pose: " .. fast.p1)
		local walk = run(motion(S.RUN_SPEED * 0.5, 0, 0, 0), 4, 1 / 60)
		Assert.truthy(walk.p1 > fast.p1 + 10 and walk.p1 < idle.p1 - 10, "a walk is in between")
	end)

	test("a strafe swings it the other way; a turn leaves it to the outside; a fall lifts it", function()
		local p1r, y1r = ScarfMath.target(motion(0, 8, 0, 0), 0, S)
		Assert.truthy(y1r < 0, "strafing right (+X) swings it toward -X")
		local _, y1l = ScarfMath.target(motion(0, -8, 0, 0), 0, S)
		Assert.near(y1l, -y1r, 1e-9, "mirror")
		local _, yTurn = ScarfMath.target(motion(0, 0, 0, 2), 0, S)
		Assert.truthy(yTurn < 0, "turning left (+): the tail trails out to the right of the turn (-X in the body)")
		local _, yMax = ScarfMath.target(motion(0, 500, 0, 50), 0, S)
		Assert.near(yMax, -S.YAW_MAX, 1e-9, "the swing is clamped")
		Assert.truthy(p1r < S.DROOP, "a strafe is movement too: the tail lifts")
		local pRest = ScarfMath.target(motion(0, 0, 0, 0), 0, S)
		local pFall = ScarfMath.target(motion(0, 0, -20, 0), 0, S)
		Assert.truthy(pFall < pRest, "a fall lifts it")
		local pJump = ScarfMath.target(motion(0, 0, 20, 0), 0, S)
		Assert.truthy(pJump <= S.PITCH_MAX and pJump > pRest, "a jump drops it (clamped)")
	end)

	test("a stop swings once and settles; the flutter only while moving", function()
		local st = run(motion(S.RUN_SPEED, 0, 0, 0), 3, 1 / 60)
		st = run(motion(0, 0, 0, 0), 0.5, 1 / 60, st)
		local peak = st.p1
		st = run(motion(0, 0, 0, 0), 5, 1 / 60, st)
		Assert.near(st.p1, S.DROOP, 0.5, "settled at the hang")
		Assert.truthy(math.abs(st.vp1) < 0.5, "at rest")
		Assert.truthy(peak > 10, "it was already falling half a second after the stop")
		local a = select(3, ScarfMath.target(motion(0, 0, 0, 0), 0.3, S))
		local b = select(3, ScarfMath.target(motion(0, 0, 0, 0), 0.9, S))
		Assert.near(a, b, 1e-9, "no flutter at rest")
		local c = select(3, ScarfMath.target(motion(S.RUN_SPEED, 0, 0, 0), 0.1, S))
		local d = select(3, ScarfMath.target(motion(S.RUN_SPEED, 0, 0, 0), 0.3, S))
		Assert.truthy(math.abs(c - d) > 1, "the end flutters while running")
	end)

	test("stable at any frame time: a hitch never flings it; rest and settled", function()
		for _, dt in { 1 / 240, 1 / 30, 0.25, 2 } do
			local st = run(motion(S.RUN_SPEED * 2, 9, -30, 4), 3, dt)
			for _, k in { "p1", "y1", "p2", "y2" } do
				local v = (st :: any)[k]
				Assert.truthy(v == v and math.abs(v) < 120, string.format("%s bounded at dt %.3f: %.2f", k, dt, v))
			end
		end
		local st = run(motion(S.RUN_SPEED, 5, 0, 1), 1, 1 / 60)
		ScarfMath.rest(st)
		Assert.truthy(
			st.p1 == 0 and st.y1 == 0 and st.p2 == 0 and st.y2 == 0 and st.vp1 == 0,
			"rest: the modelled pose"
		)
		local s0 = ScarfMath.settled(motion(0, 0, 0, 0), S)
		Assert.near(s0.p1, S.DROOP, 1e-9, "a character first seen standing already hangs")
	end)

	test("budget: the nearest MAX_RIGS sway below OFF_TIER, none from it", function()
		Assert.eq(Budget.scarfRigs(1), S.MAX_RIGS, "tier 1")
		Assert.eq(Budget.scarfRigs(2), S.MAX_RIGS, "tier 2")
		Assert.eq(S.OFF_TIER, 3, "off at tier >= 3")
		Assert.eq(Budget.scarfRigs(3), 0, "tier 3: off")
		Assert.eq(Budget.scarfRigs(4), 0, "tier 4: off")
		Assert.eq(Budget.scarfRigs(9), 0, "clamped")
		Assert.truthy(S.MAX_RIGS <= 8 and S.RANGE <= 90, "cheap: a few welds a frame")
		Assert.eq(#S.PIECES, 2, "two segments")
	end)
end
