-- L1: Shared/Heist/IntroPlan, the story intro as data (docs/art/intro/STORYBOARD.md, PLAN_FIRST_PERSON §5):
-- the length rule (30-40 s), short sound-off captions, ASCII, a camera that never jumps inside a shot, a whip
-- that is a cut under reduced motion, no shake under reduced motion, and the stepper's promise: a SKIP at any
-- time lands in the same end state as watching to the end.

local IntroPlan = require("../../src/shared/Heist/IntroPlan")
local Strings = require("../../src/shared/Heist/Strings")
local Config = require("../../src/shared/Config")
local Cues = require("../../src/shared/Audio/Cues")
local Assert = require("./Assert")

local I = Config.Intro

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

local function play(skipAt: number?, dt: number): (any, { any })
	local st = IntroPlan.new()
	local log = {}
	while not st.done do
		if skipAt and st.t >= skipAt then
			for _, e in IntroPlan.skip(st) do
				table.insert(log, e)
			end
			break
		end
		for _, e in IntroPlan.advance(st, dt) do
			table.insert(log, e)
		end
	end
	return st, log
end

return function(test)
	test("shot timings sum to 30-40 s, about six shots plus the title", function()
		local total = 0
		for _, shot in IntroPlan.SHOTS do
			Assert.truthy(shot.seconds > 0, shot.id .. " has a length")
			total += shot.seconds
		end
		Assert.near(IntroPlan.total(), total, 1e-9, "total")
		Assert.truthy(total >= 30 and total <= 40, "30-40 s, got " .. total)
		Assert.truthy(#IntroPlan.SHOTS >= 6 and #IntroPlan.SHOTS <= 8, "about 6 shots")
	end)

	test("every shot has a caption of at most six words, ASCII, in Strings", function()
		for _, shot in IntroPlan.SHOTS do
			local text = Strings.INTRO[shot.caption]
			Assert.truthy(type(text) == "string" and #text > 0, shot.id .. ": caption in Strings.INTRO")
			local words = IntroPlan.words(text)
			Assert.truthy(words >= 1, shot.id .. ": a real word")
			Assert.le(words, I.CAPTION.WORDS_MAX, shot.id .. ": <= 6 words (" .. text .. ")")
			Assert.truthy(not string.find(text, "[\128-\255]"), shot.id .. ": ASCII only")
			Assert.eq(text, string.upper(text), shot.id .. ": capitals (sound-off cards)")
			Assert.truthy(shot.captionAt >= 0 and shot.captionAt < shot.seconds - 0.9, shot.id .. ": readable >= 0.9 s")
		end
		Assert.eq(IntroPlan.words("...GONE."), 1, "dots are not words")
		Assert.eq(IntroPlan.words("IT'LL TAKE MORE OF ME."), 5, "apostrophes stay in the word")
		Assert.eq(Strings.INTRO.TITLE, Strings.WORDMARK, "the title card is the wordmark")
	end)

	test("the arc: town -> Hoardsworth -> vacuum -> gone -> letter and Rookie -> clones -> title", function()
		local ids = {}
		for _, shot in IntroPlan.SHOTS do
			table.insert(ids, shot.id)
		end
		Assert.eq(table.concat(ids, ","), "eve,hoard,every,gone,one,more,title", "shot order")
		Assert.truthy(IntroPlan.SHOTS[#IntroPlan.SHOTS].wordmark, "ends on the wordmark smash")
		local moves = {}
		for _, shot in IntroPlan.SHOTS do
			moves[shot.move] = true
			Assert.truthy(IntroPlan.MOODS[shot.mood] ~= nil, shot.id .. ": a lighting mood")
		end
		for _, m in { "crane", "low", "whip", "push" } do
			Assert.truthy(moves[m], "a " .. m .. " move")
		end
	end)

	test("the camera never jumps inside a shot and never leaves a sane FOV", function()
		local dt = 1 / 60
		local total = IntroPlan.total()
		local t = 0
		local prevPos, prevShot = nil, 0
		while t < total do
			local i = IntroPlan.locate(t)
			local pos, look, fov, whip = IntroPlan.camera(t, true)
			Assert.truthy(fov >= 30 and fov <= 70, "fov at " .. t)
			Assert.truthy(whip == 0, "reduced motion: never a whip")
			Assert.truthy(dist(pos, look) > 1, "look point away from the eye")
			if prevPos and i == prevShot then
				Assert.truthy(dist(prevPos, pos) < 120 * dt, string.format("smooth move at %.2f", t))
			end
			prevPos, prevShot = pos, i
			t += dt
		end
	end)

	test("the whip-pan is a whip with motion and a cut under reduced motion", function()
		local i = 0
		for k, shot in IntroPlan.SHOTS do
			if shot.enter == "whip" then
				i = k
			end
		end
		Assert.truthy(i > 1, "a whip shot")
		local mid = IntroPlan.startOf(i) + I.WHIP_SECONDS / 2
		local _, lookFull, _, whip = IntroPlan.camera(mid, false)
		local pos, lookCut, _, whipCut = IntroPlan.camera(mid, true)
		Assert.truthy(whip > 0.9, "blur peaks mid-whip")
		Assert.eq(whipCut, 0, "reduced: no whip")
		Assert.truthy(dist(lookFull, lookCut) > 1, "the whip looks elsewhere mid-sweep")
		Assert.truthy(pos ~= nil, "pos")
		local _, _, _, after = IntroPlan.camera(IntroPlan.startOf(i) + I.WHIP_SECONDS + 0.01, false)
		Assert.eq(after, 0, "the whip ends")
	end)

	test("shake only with motion, and it decays to zero", function()
		local any = false
		for t = 0, IntroPlan.total(), 0.05 do
			Assert.eq(IntroPlan.shake(t, true), 0, "reduced motion: no shake")
			local a = IntroPlan.shake(t, false)
			Assert.truthy(a <= I.SHAKE.AMP + 1e-9, "bounded")
			any = any or a > 0
		end
		Assert.truthy(any, "the vacuum shakes the screen")
		Assert.eq(IntroPlan.shake(IntroPlan.total(), false), 0, "calm at the end")
	end)

	test("captions fade in on their shot and show the wordmark last", function()
		for i, shot in IntroPlan.SHOTS do
			local key, a = IntroPlan.caption(IntroPlan.startOf(i) + shot.captionAt + I.CAPTION.IN + 0.01)
			Assert.eq(key, shot.caption, shot.id .. ": its caption")
			Assert.truthy(a > 0.9, shot.id .. ": fully in after IN")
			local before = IntroPlan.caption(IntroPlan.startOf(i) + shot.captionAt - 0.01)
			Assert.truthy(before ~= shot.caption, shot.id .. ": not before captionAt")
		end
		local _, _, _, wordmark = IntroPlan.caption(IntroPlan.total() - 0.1)
		Assert.truthy(wordmark, "the title shot draws the wordmark")
		Assert.eq((IntroPlan.caption(IntroPlan.total())), nil, "nothing after the end")
	end)

	test("props: presents fly into the vacuum mouth, the globe fills, the letter lands, clones print in", function()
		local n = I.PRESENTS[1]
		local alive = 0
		for t = IntroPlan.SWIRL.start, IntroPlan.SWIRL.finish, 0.1 do
			for k = 1, n do
				local p, _, live = IntroPlan.present(k, n, t)
				if live then
					alive += 1
					Assert.truthy(p[2] > -1, "above ground")
				end
			end
		end
		Assert.truthy(alive > n, "presents in the air")
		for k = 1, n do
			local _, _, live = IntroPlan.present(k, n, IntroPlan.SWIRL.finish + 0.01)
			Assert.falsy(live, "every present swallowed by the end of the swirl")
		end
		Assert.near(IntroPlan.globeFill(0), IntroPlan.GLOBE.min, 1e-9, "globe nearly empty at first")
		Assert.near(IntroPlan.globeFill(IntroPlan.total()), 1, 1e-9, "globe full")
		local L = IntroPlan.LETTER
		local _, _, hidden = IntroPlan.letter(L[1][1] - 0.1)
		Assert.falsy(hidden, "the letter appears with its shot")
		local p = IntroPlan.letter(L[#L][1] + 1)
		Assert.truthy(dist(p, L[#L][2]) < 1e-6, "lands in the Rookie's hand")
		for k = 1, 4 do
			Assert.eq(IntroPlan.clonePrint(k, 0), 0, "clone " .. k .. " absent at first")
			Assert.eq(IntroPlan.clonePrint(k, IntroPlan.total()), 1, "clone " .. k .. " solid at the end")
		end
	end)

	test("pose tracks blend between known poses", function()
		for name, track in IntroPlan.TRACKS do
			for _, key in track do
				Assert.truthy(IntroPlan.POSES[key[2]] ~= nil, name .. ": pose " .. tostring(key[2]))
			end
			for t = 0, IntroPlan.total(), 0.25 do
				local a, b, w = IntroPlan.pose(name, t)
				Assert.truthy(IntroPlan.POSES[a] and IntroPlan.POSES[b], name .. " poses")
				Assert.truthy(w >= 0 and w <= 1, "weight")
			end
		end
		local x = IntroPlan.joint("rest", "lever", 1, "RightShoulder")
		Assert.eq(x, IntroPlan.POSES.lever.RightShoulder[1], "full weight = the target pose")
	end)

	test("every cue the plan plays exists in the audio cue table", function()
		for _, e in IntroPlan.TIMELINE do
			if e.kind == "cue" then
				Assert.truthy(Cues.cues[e.cue] ~= nil, "cue " .. tostring(e.cue))
			end
		end
		for cue in IntroPlan.LOOPS do
			Assert.truthy(Cues.cues[cue] and Cues.cues[cue].loop, cue .. " loops")
		end
	end)

	test("a skip at any time lands in the same end state as watching to the end", function()
		local full, log = play(nil, 1 / 30)
		local want = IntroPlan.summary(full)
		Assert.truthy(want.done and want.ends == 1, "watched: done with one end")
		Assert.eq(want.live + want.loops + want.fx, 0, "watched: nothing left on")
		local ends = 0
		for _, e in log do
			if e.kind == "end" then
				ends += 1
			end
		end
		Assert.eq(ends, 1, "one end event")
		Assert.eq(log[#log].kind, "end", "the end is last")
		for skipAt = 0, IntroPlan.total() + 0.5, 0.37 do
			local st, slog = play(skipAt, 1 / 30)
			local got = IntroPlan.summary(st)
			for k, v in want do
				Assert.eq(got[k], v, string.format("skip at %.2f: %s", skipAt, k))
			end
			Assert.eq(slog[#slog].kind, "end", "skip ends with the end event")
			Assert.eq(#IntroPlan.skip(st), 0, "a second skip does nothing")
			Assert.eq(#IntroPlan.advance(st, 1), 0, "nothing after the end")
		end
		-- every spawn is matched by a despawn in either path
		local spawned, gone = {}, {}
		for _, e in select(2, play(12.3, 1 / 30)) do
			if e.kind == "spawn" then
				spawned[e.id] = true
			elseif e.kind == "despawn" then
				gone[e.id] = true
			end
		end
		for id in spawned do
			Assert.truthy(gone[id], id .. " despawned on skip")
		end
	end)

	test("the stage sits far from every heist slot and its backdrop", function()
		local o = I.STAGE_ORIGIN
		local H = Config.Heist
		for _, slot in H.INSTANCE_SLOTS do
			local sx, sz = slot[1] * H.INSTANCE_SPACING, slot[2] * H.INSTANCE_SPACING
			local d = math.sqrt((o[1] - sx) ^ 2 + (o[3] - sz) ^ 2)
			Assert.truthy(d > 1500, "far from slot " .. slot[1] .. "," .. slot[2])
		end
		Assert.truthy(math.sqrt(o[1] ^ 2 + o[3] ^ 2) > 1500, "far from the lobby")
		Assert.truthy(math.abs(o[1]) + math.abs(o[3]) < 20000, "float precision stays fine")
	end)
end
