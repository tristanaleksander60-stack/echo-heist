-- L1: Heist/CrewView, the Crew View peek (docs/audit/REVIEW_STEAM_PLUS.md gap 5; Config.Heist.CAMERA.CREW). The
-- input gating (only a run in first person, never in the lobby or during a presentation moment, the rewind, a
-- sheet), the hold (0.25 s up, 0.2 s down at 30 and 60 fps; reduced motion: a cut under a quick veil), the shot
-- (centred on you, every clone and the objective within RADIUS in frame on 16:9, a 19.5:9 phone and 4:3, from above
-- the ceiling, never rolling) and the one-time hint.

local Config = require("../../src/shared/Config")
local CrewView = require("../../src/shared/Heist/CrewView")
local Assert = require("./Assert")

local CR = Config.Heist.CAMERA.CREW
local ASPECTS = { ["16:9"] = 16 / 9, ["19.5:9 phone"] = 19.5 / 9, ["4:3 tablet"] = 4 / 3 }

local function run(fields: { [string]: any }?): CrewView.Gate
	local g: { [string]: any } = { where = "heist", phase = "Run", mode = "fp", alive = true }
	for k, v in fields or {} do
		g[k] = v
	end
	return g :: any
end

-- Seconds of holding (or releasing) until the hold reaches `goal`.
local function timeTo(h: CrewView.Hold, held: boolean, goal: number, fps: number, reduced: boolean): number
	local t = 0
	while h.w ~= goal and t < 5 do
		CrewView.step(h, held, 1 / fps, reduced, CR)
		t += 1 / fps
	end
	return t
end

return function(test)
	test("config: the lift and the drop, a steep overhead, a sane fit range", function()
		Assert.near(CR.IN_SECONDS, 0.25, 1e-9, "eases up in 0.25 s")
		Assert.near(CR.OUT_SECONDS, 0.2, 1e-9, "eases back in 0.2 s")
		Assert.truthy(CR.PITCH >= Config.Heist.CAMERA.DIORAMA.PITCH and CR.PITCH <= 75, "steeper than the diorama")
		Assert.truthy(CR.DIST_MIN > 0 and CR.DIST_MIN < CR.DIST_MAX, "distance range")
		Assert.truthy(CR.SHARE > 0 and CR.SHARE < 1 and CR.SHARE_Y > 0 and CR.SHARE_Y < 1, "frame shares")
		Assert.truthy(CR.HINT_MIN_CLONES == 2, "the hint waits for 2 clones")
	end)

	test("gating: only a run in first person; never the lobby, a moment, the rewind, a sheet or a dead body", function()
		local ok, why = CrewView.allowed(run())
		Assert.truthy(ok, "a first-person run")
		Assert.eq(why, "ok")
		local cases = {
			{ run({ where = "garage" }), "lobby" },
			{ run({ where = "boot" }), "lobby" },
			{ run({ phase = "Between" }), "phase" },
			{ run({ phase = "Over" }), "phase" },
			{ run({ mode = "diorama" }), "mode" },
			{ run({ mode = "classic" }), "mode" },
			{ run({ presenting = true }), "presenting" },
			{ run({ rewinding = true }), "rewind" },
			{ run({ sheet = true }), "sheet" },
			{ run({ alive = false }), "dead" },
			{ run({ where = "garage", phase = "Between", presenting = true }), "lobby" },
		}
		for i, c in cases do
			local allowed, reason = CrewView.allowed(c[1])
			Assert.falsy(allowed, "case " .. i)
			Assert.eq(reason, c[2], "case " .. i .. " reason")
		end
		Assert.truthy((CrewView.allowed(run({ alive = nil }))), "alive unknown counts as alive")
	end)

	test("hold: lifts in IN_SECONDS, drops in OUT_SECONDS, at 30 and 60 fps; eased ends", function()
		for _, fps in { 30, 60 } do
			local h = CrewView.newHold()
			Assert.falsy(CrewView.active(h), "rest")
			local up = timeTo(h, true, 1, fps, false)
			Assert.near(up, CR.IN_SECONDS, 1 / fps + 1e-9, fps .. " fps lift")
			Assert.truthy(CrewView.active(h), "held")
			Assert.near(CrewView.weight(h), 1, 1e-9, "full shot")
			local down = timeTo(h, false, 0, fps, false)
			Assert.near(down, CR.OUT_SECONDS, 1 / fps + 1e-9, fps .. " fps drop")
			Assert.falsy(CrewView.active(h), "back at your eyes")
		end
		-- the ease starts and lands gently and is monotonic
		Assert.near(CrewView.ease(0), 0, 1e-12, "ease 0")
		Assert.near(CrewView.ease(1), 1, 1e-12, "ease 1")
		Assert.truthy(CrewView.ease(0.05) < 0.05 and CrewView.ease(0.95) > 0.95, "gentle at both ends")
		local last = -1
		for k = 0, 20 do
			local e = CrewView.ease(k / 20)
			Assert.truthy(e >= last, "monotonic")
			last = e
		end
		-- a release half way drops from where it was (no jump)
		local h = CrewView.newHold()
		for _ = 1, 4 do
			CrewView.step(h, true, 1 / 60, false, CR)
		end
		local mid = h.w
		CrewView.step(h, false, 1 / 60, false, CR)
		Assert.truthy(h.w < mid and h.w > mid - 2 / 60 / CR.OUT_SECONDS, "release mid-lift eases from there")
		-- no veil without reduced motion
		Assert.eq(CrewView.veil(h, false, CR), 0, "no veil")
	end)

	test("reduced motion: no flight; the view holds, cuts at CUT_AT under the veil, the veil clears", function()
		local R = CR.REDUCED
		local h = CrewView.newHold()
		Assert.eq(CrewView.veil(h, true, CR), 0, "no veil at rest")
		local peak, t = 0, 0
		local cutAt: number? = nil
		while t < R.CUT_AT + R.OUT + 0.1 do
			CrewView.step(h, true, 1 / 60, true, CR)
			t += 1 / 60
			Assert.truthy(h.w == 0 or h.w == 1, "never in between (no flight)")
			if h.w == 1 and not cutAt then
				cutAt = t
			end
			peak = math.max(peak, CrewView.veil(h, true, CR))
		end
		Assert.truthy(cutAt ~= nil, "it cuts")
		Assert.near(cutAt :: number, R.CUT_AT, 1 / 60 + 1e-9, "at CUT_AT")
		Assert.truthy(peak > R.PEAK * 0.8 and peak <= R.PEAK + 1e-9, "the veil peaks at the cut")
		Assert.eq(CrewView.veil(h, true, CR), 0, "the veil clears")
		-- and back
		local back = timeTo(h, false, 0, 60, true)
		Assert.near(back, R.CUT_AT, 1 / 60 + 1e-9, "the way back cuts too")
		-- a tap shorter than the cut never moves the camera and never veils after the release
		local tap = CrewView.newHold()
		CrewView.step(tap, true, 0.03, true, CR)
		CrewView.step(tap, false, 1 / 60, true, CR)
		Assert.eq(tap.w, 0, "a short tap: no cut")
		Assert.eq(CrewView.veil(tap, true, CR), 0, "and no veil")
	end)

	test("cancel: a presentation moment drops it at once, with no veil", function()
		for _, reduced in { false, true } do
			local h = CrewView.newHold()
			timeTo(h, true, 1, 60, reduced)
			CrewView.cancel(h)
			Assert.eq(h.w, 0, "at your eyes")
			Assert.falsy(CrewView.active(h), "inactive")
			Assert.eq(CrewView.veil(h, reduced, CR), 0, "no veil")
			CrewView.step(h, false, 1 / 60, reduced, CR)
			Assert.eq(h.w, 0, "stays down")
			-- a new hold works again
			timeTo(h, true, 1, 60, reduced)
			Assert.eq(h.w, 1, "a new hold lifts again")
		end
	end)

	test("shot: centred on you, frames clones and the objective, from above, never rolling", function()
		local you = { 10, 4.5, -6 }
		-- clones round you and the objective ahead, all within RADIUS
		local crew = { { 22, 3, -6 }, { -2, 3, -14 }, { 14, 3, 6 }, { 6, 3, -30 } }
		for name, aspect in ASPECTS do
			for _, yaw in { 0, 35, 90, 180, -120 } do
				local focus, d, framed = CrewView.frame(you, crew, yaw, aspect, CR)
				Assert.eq(framed, #crew, name .. " frames every point")
				Assert.truthy(d >= CR.DIST_MIN and d <= CR.DIST_MAX, "distance in range")
				local pos, look = CrewView.orbit(focus, yaw, CR.PITCH, d)
				Assert.near(look[1], focus[1], 1e-9, "looks at the focus")
				Assert.truthy(pos[2] - you[2] >= d * math.sin(math.rad(CR.PITCH)) - 1e-6, "from above")
				Assert.truthy(pos[2] > you[2] + Config.Big.CEIL_Y, "above a ceiling over you")
				for _, p in { you, table.unpack(crew) } do
					local nx, ny, depth = CrewView.project(pos, yaw, CR.PITCH, p, CR.FOV, aspect)
					Assert.truthy(depth > 0, "in front")
					Assert.truthy(math.abs(nx) <= CR.SHARE + 1e-6, string.format("%s yaw %d: x %.2f", name, yaw, nx))
					Assert.truthy(math.abs(ny) <= CR.SHARE_Y + 1e-6, string.format("%s yaw %d: y %.2f", name, yaw, ny))
				end
				-- you stay near the middle (the focus moves only PULL of the way to the crew's middle)
				local nx, ny = CrewView.project(pos, yaw, CR.PITCH, you, CR.FOV, aspect)
				Assert.truthy(math.abs(nx) <= 0.5 and math.abs(ny) <= 0.5, "you near the centre")
				-- no roll: a point beside you at your height projects level with you
				local r = math.rad(yaw)
				local side = { you[1] + math.cos(r) * 3, you[2], you[3] - math.sin(r) * 3 }
				local _, a = CrewView.project(pos, yaw, CR.PITCH, you, CR.FOV, aspect)
				local _, b = CrewView.project(pos, yaw, CR.PITCH, side, CR.FOV, aspect)
				Assert.near(a, b, 1e-6, "level horizon")
			end
		end
	end)

	test("shot: alone it is the closest; a far point is ignored; a spread crew widens, capped", function()
		local you = { 0, 4.5, 0 }
		local focus, d, framed = CrewView.frame(you, {}, 0, 16 / 9, CR)
		Assert.eq(framed, 0, "nothing to frame")
		Assert.eq(d, CR.DIST_MIN, "alone: the closest shot")
		Assert.near(focus[1], 0, 1e-9, "centred on you")
		Assert.near(focus[3], 0, 1e-9, "centred on you")
		local far = { { CR.RADIUS + 30, 3, 0 } }
		local _, dFar, nFar = CrewView.frame(you, far, 0, 16 / 9, CR)
		Assert.eq(nFar, 0, "a clone across the map is not framed")
		Assert.eq(dFar, CR.DIST_MIN, "and does not widen the shot")
		local near = { { 8, 3, 0 } }
		local wide = { { 30, 3, 0 }, { -30, 3, 0 } }
		local _, dNear = CrewView.frame(you, near, 0, 16 / 9, CR)
		local _, dWide = CrewView.frame(you, wide, 0, 16 / 9, CR)
		Assert.truthy(dWide > dNear, "a wider crew pulls back")
		Assert.le(dWide, CR.DIST_MAX, "never past DIST_MAX")
		-- the objective right behind the camera still fits: the shot is a frame, not a lens trick
		local _, dBack, nBack = CrewView.frame(you, { { 0, 3, 20 } }, 0, 16 / 9, CR)
		Assert.eq(nBack, 1, "framed")
		Assert.truthy(dBack >= CR.DIST_MIN, "fits")
	end)

	test("hint: the first first-person run with 2+ clones, once", function()
		Assert.truthy(CrewView.hintDue(2, "fp", false, CR), "2 clones")
		Assert.truthy(CrewView.hintDue(7, "fp", false, CR), "7 clones")
		Assert.falsy(CrewView.hintDue(1, "fp", false, CR), "1 clone")
		Assert.falsy(CrewView.hintDue(3, "diorama", false, CR), "diorama sees them anyway")
		Assert.falsy(CrewView.hintDue(3, "fp", true, CR), "seen")
	end)
end
