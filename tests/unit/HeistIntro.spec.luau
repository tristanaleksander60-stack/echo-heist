-- L1: Shared/Heist/IntroPlan, the story intro as data (docs/art/intro/STORYBOARD.md, PLAN_FIRST_PERSON §5):
-- the length rule (30-40 s), short sound-off captions, ASCII, a camera that never jumps inside a shot, a whip
-- that is a cut under reduced motion, no shake under reduced motion, and the stepper's promise: a SKIP at any
-- time lands in the same end state as watching to the end.

local IntroPlan = require("../../src/shared/Heist/IntroPlan")
local Strings = require("../../src/shared/Heist/Strings")
local Config = require("../../src/shared/Config")
local Cues = require("../../src/shared/Audio/Cues")
local IntroRig = require("../../src/shared/Heist/IntroRig")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
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
	test("shot timings sum to 30-40 s (tightened to <= 34 s, still dramatic), seven shots plus the title", function()
		local total = 0
		for _, shot in IntroPlan.SHOTS do
			Assert.truthy(shot.seconds > 0, shot.id .. " has a length")
			total += shot.seconds
		end
		Assert.near(IntroPlan.total(), total, 1e-9, "total")
		Assert.truthy(total >= 30 and total <= 40, "30-40 s, got " .. total)
		Assert.truthy(total <= 34, "tightened (REVIEW_STEAM_PLUS #7): <= 34 s, got " .. total)
		Assert.truthy(#IntroPlan.SHOTS >= 6 and #IntroPlan.SHOTS <= 8, "about 6 shots")
		Assert.eq(I.SERVER_HOLD_SECONDS, nil, "no server hold (the intro plays over the hideout)")
		for i, shot in IntroPlan.SHOTS do
			Assert.near(IntroPlan.at(shot.id, 0), IntroPlan.startOf(i), 1e-9, "at(" .. shot.id .. ", 0) is its start")
		end
	end)

	test("play() never freezes: liveness watchdog, explicit SKIP keys (INTRO LOAD FIX)", function()
		Assert.truthy(I.START_WATCHDOG_SECONDS > 0 and I.START_WATCHDOG_SECONDS <= 5, "a dead intro ends within 5 s")
		Assert.truthy(I.MIN_ADVANCE > 0 and I.MIN_ADVANCE < I.START_WATCHDOG_SECONDS, "advance within the window")
		Assert.truthy(I.STALL_SECONDS > 0 and I.STALL_SECONDS <= 5, "a frozen intro ends within 5 s")
		Assert.truthy(I.FTUE_START_WAIT_SECONDS > 0 and I.FTUE_START_WAIT_SECONDS <= 10, "L1 or the hideout soon")
		Assert.falsy(I.SKIP.ANY_KEY, "not any key: W, a click or a chat key must not skip it")
		local keys: { [string]: boolean } = {}
		for _, k in I.SKIP.KEYS do
			keys[k] = true
		end
		Assert.truthy(keys.Space and keys.ButtonB, "Space (the cap shows it) and B skip")
		for _, k in { "W", "A", "S", "D", "Up", "Down", "Left", "Right", "LeftShift", "E", "Thumbstick1" } do
			Assert.falsy(keys[k], "a movement or use key never skips: " .. k)
		end
		-- the card waits a few seconds for the real meshes (never block stand-ins; no kit: the title card instead)
		Assert.truthy(
			I.KIT_WAIT_SECONDS + I.KIT_PRELOAD_SECONDS <= 6,
			"the card waits at most 6 s for the intro meshes"
		)
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
		Assert.eq(table.concat(ids, ","), "eve,hoard,laugh,every,gone,one,more,title", "shot order")
		Assert.truthy(IntroPlan.SHOTS[#IntroPlan.SHOTS].wordmark, "ends on the wordmark smash")
		local moves = {}
		for _, shot in IntroPlan.SHOTS do
			moves[shot.move] = true
			Assert.truthy(IntroPlan.MOODS[shot.mood] ~= nil, shot.id .. ": a lighting mood")
		end
		for _, m in { "crane", "low", "close", "whip", "push" } do
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
		local x = IntroPlan.joint("rest", "laugh", 1, "RightShoulder")
		Assert.eq(x, IntroPlan.POSES.laugh.RightShoulder[1], "full weight = the target pose")
		Assert.eq(IntroPlan.rookieFace(0), "idle", "the Rookie starts idle")
		Assert.eq(IntroPlan.rookieFace(IntroPlan.total()), "smug", "and ends on the smug grin")
		Assert.eq(IntroPlan.leverAngle(IntroPlan.LEVER.at - 0.01), 0, "the lever is up until the yank")
		Assert.near(
			IntroPlan.leverAngle(IntroPlan.LEVER.at + IntroPlan.LEVER.swing),
			IntroPlan.LEVER.degrees,
			1e-9,
			"then down"
		)
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

	test("Hoardsworth's rig data matches the kit manifest (joints, parents, origins, bounds)", function()
		local manifest = serde.decode("json", fs.readFile("assets/fbx/kit_manifest.json")).parts
		local seen = {}
		for i, p in IntroRig.PARTS do
			local m = manifest[p.name]
			Assert.truthy(m ~= nil, p.name .. " is in the manifest")
			Assert.eq(m.model, "Hoardsworth", p.name .. ": model")
			Assert.eq(m.joint.name, p.joint, p.name .. ": joint")
			Assert.eq(m.joint.parent, p.parent, p.name .. ": parent")
			for k = 1, 3 do
				Assert.near(m.origin[k], p.origin[k], 1e-3, p.name .. ": origin")
				Assert.near(m.boundsMin[k], p.min[k], 1e-3, p.name .. ": min")
				Assert.near(m.boundsMax[k], p.max[k], 1e-3, p.name .. ": max")
			end
			if p.parent then
				Assert.truthy(seen[p.parent], p.name .. ": parent listed first")
			end
			seen[p.name] = i
		end
		local n = 0
		for _, m in manifest do
			if m.model == "Hoardsworth" then
				n += 1
			end
		end
		Assert.eq(n, #IntroRig.PARTS, "every Hoardsworth part in the rig")
		Assert.truthy(seen[IntroRig.MONOCLE], "the monocle (glint) is a rig part")
		for _, p in IntroRig.PARTS do
			Assert.truthy(IntroRig.ROLE_HEX[p.role] ~= nil, p.name .. ": a box-rig colour")
		end
	end)

	test("framing: the vacuum reads big in shot 3, shot 2 is not crowded by the globe", function()
		local ST = IntroPlan.STAGE
		local function shotNamed(id: string): any
			for _, sh in IntroPlan.SHOTS do
				if sh.id == id then
					return sh
				end
			end
			error("no shot " .. id)
		end
		local function angle(from: { number }, look: { number }, p: { number }): number
			local a = { look[1] - from[1], look[2] - from[2], look[3] - from[3] }
			local b = { p[1] - from[1], p[2] - from[2], p[3] - from[3] }
			local la, lb = dist(look, from), dist(p, from)
			return math.deg(math.acos(math.clamp((a[1] * b[1] + a[2] * b[2] + a[3] * b[3]) / (la * lb), -1, 1)))
		end
		-- the giant vacuum: its mouth hangs out over the town past the terrace, above the deck
		Assert.truthy(ST.nozzle[2] > ST.deckY + 10 and ST.nozzle[3] > ST.tower.base[3] + 24, "the mouth over the town")
		Assert.truthy(dist(ST.nozzle, ST.globe.centre) > ST.globe.radius + 30, "clear of the Snow Globe")
		local aim = ST.aim
		Assert.near(math.sqrt(aim[1] ^ 2 + aim[2] ^ 2 + aim[3] ^ 2), 1, 1e-3, "the aim is a unit vector")
		Assert.truthy(aim[2] < -0.5 and aim[3] > 0.5, "the mouth looks down at the town")
		local every = shotNamed("every")
		local k0 = every.keys[1]
		local mouthDeg = 2 * math.deg(math.atan(9.7 / dist(k0.pos, ST.nozzle))) -- the kit mouth's radius x VAC_S
		Assert.truthy(
			mouthDeg > 0.6 * k0.fov,
			string.format("shot 3 opens on the mouth: %.0f deg of %d", mouthDeg, k0.fov)
		)
		Assert.truthy(angle(k0.pos, k0.look, ST.nozzle) < 5, "looking into it")
		for _, k in every.keys do
			Assert.truthy(dist(k.pos, ST.vacuum.at) < 120, "the machine never shrinks to a speck")
		end
		-- shot 2: Hoardsworth framed close, the Snow Globe off his shoulder (not a dark disc filling the frame)
		local hoard = shotNamed("hoard")
		local head = { ST.hoardsworth.at[1], ST.hoardsworth.at[2] + 7, ST.hoardsworth.at[3] }
		for _, k in hoard.keys do
			Assert.truthy(dist(k.pos, head) < 18.5, "close on Hoardsworth")
			Assert.truthy(angle(k.pos, k.look, ST.globe.centre) > 40, "the globe is not behind him filling the frame")
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

	-- Forward kinematics of Hoardsworth's rig (IntroRig: world = parent * C0 * R(pose), C0 = origin - parent origin),
	-- as Heist/Cinematic and the key frames pose it: a point given in a part's space -> stage studs.
	local function rot(rx: number, ry: number, rz: number): { { number } }
		local cx, sx = math.cos(math.rad(rx)), math.sin(math.rad(rx))
		local cy, sy = math.cos(math.rad(ry)), math.sin(math.rad(ry))
		local cz, sz = math.cos(math.rad(rz)), math.sin(math.rad(rz))
		local X = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
		local Y = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
		local Z = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
		local function mul(a: { { number } }, b: { { number } }): { { number } }
			local o = {}
			for r = 1, 3 do
				o[r] = {}
				for c = 1, 3 do
					o[r][c] = a[r][1] * b[1][c] + a[r][2] * b[2][c] + a[r][3] * b[3][c]
				end
			end
			return o
		end
		return mul(mul(Y, X), Z)
	end
	local function partPoint(pose: string, name: string, localP: { number }): { number }
		local frames: { [string]: { r: { { number } }, p: { number } } } = {}
		local byName = {}
		for _, p in IntroRig.PARTS do
			byName[p.name] = p
		end
		local function frame(n: string): { r: { { number } }, p: { number } }
			if frames[n] then
				return frames[n]
			end
			local spec = byName[n]
			local e = IntroPlan.POSES[pose][spec.joint] or { 0, 0, 0 }
			local R = rot(e[1], e[2], e[3])
			local out
			if spec.parent then
				local pf = frame(spec.parent)
				local po = byName[spec.parent].origin
				local d = { spec.origin[1] - po[1], spec.origin[2] - po[2], spec.origin[3] - po[3] }
				local pr = pf.r
				local p = {}
				local r = {}
				for i = 1, 3 do
					p[i] = pf.p[i] + pr[i][1] * d[1] + pr[i][2] * d[2] + pr[i][3] * d[3]
					r[i] = {}
					for c = 1, 3 do
						r[i][c] = pr[i][1] * R[1][c] + pr[i][2] * R[2][c] + pr[i][3] * R[3][c]
					end
				end
				out = { r = r, p = p }
			else
				out = { r = R, p = { spec.origin[1], spec.origin[2], spec.origin[3] } }
			end
			frames[n] = out
			return out
		end
		local f = frame(name)
		local m = {}
		for i = 1, 3 do
			m[i] = f.p[i] + f.r[i][1] * localP[1] + f.r[i][2] * localP[2] + f.r[i][3] * localP[3]
		end
		-- model -> stage: his feet at STAGE.hoardsworth.at, turned by its yaw about Y
		local H = IntroPlan.STAGE.hoardsworth
		local c, s = math.cos(math.rad(H.yaw)), math.sin(math.rad(H.yaw))
		return { H.at[1] + m[1] * c + m[3] * s, H.at[2] + m[2], H.at[3] - m[1] * s + m[3] * c }
	end
	local function partCentre(pose: string, name: string): { number }
		for _, p in IntroRig.PARTS do
			if p.name == name then
				return partPoint(pose, name, {
					(p.min[1] + p.max[1]) / 2,
					(p.min[2] + p.max[2]) / 2,
					(p.min[3] + p.max[3]) / 2,
				})
			end
		end
		error("no part " .. name)
	end
	local function angleTo(from: { number }, look: { number }, p: { number }): number
		local a = { look[1] - from[1], look[2] - from[2], look[3] - from[3] }
		local b = { p[1] - from[1], p[2] - from[2], p[3] - from[3] }
		local la, lb = dist(look, from), dist(p, from)
		return math.deg(math.acos(math.clamp((a[1] * b[1] + a[2] * b[2] + a[3] * b[3]) / (la * lb), -1, 1)))
	end

	test("the villain close-up: his laughing face, the monocle glint, the gold-ringed hand on the lever", function()
		local ST = IntroPlan.STAGE
		local i = 0
		for k, sh in IntroPlan.SHOTS do
			if sh.id == "laugh" then
				i = k
			end
		end
		Assert.truthy(i == 3, "the close-up follows his introduction")
		local shot = IntroPlan.SHOTS[i]
		Assert.truthy(shot.seconds >= 3 and shot.seconds <= 4.5, "a beat, not a scene")
		-- the hand: in the laugh poses the right glove grips the knob
		for _, pose in { "laugh", "laughB" } do
			local hand = partCentre(pose, "Hoardsworth_RightHand")
			Assert.truthy(
				dist(hand, ST.knob) < 0.35,
				string.format("%s: the glove on the knob (%.2f studs)", pose, dist(hand, ST.knob))
			)
		end
		-- the knob is the lever's handle top (the kit's Intro_Lever: hinge 2.85 up, the handle 2.43 above it, leaning
		-- toward his front)
		Assert.truthy(math.abs(ST.knob[2] - (ST.lever.at[2] + 2.85 + 2.2)) < 0.3, "the knob is the handle's top")
		Assert.truthy(math.abs(ST.knob[1] - ST.lever.at[1]) < 0.2, "over the lever")
		-- the camera: opens close on his face (the monocle in the middle), ends on the knob, and stays close
		local face = partCentre("laugh", IntroRig.MONOCLE)
		local k0, kn = shot.keys[1], shot.keys[#shot.keys]
		Assert.truthy(dist(k0.pos, face) < 6.5 and k0.fov <= 40, "a medium close-up on his face")
		Assert.truthy(angleTo(k0.pos, k0.look, face) < 4, "the monocle near the frame centre")
		Assert.truthy(angleTo(kn.pos, kn.look, ST.knob) < 4, "it ends on the gold-ringed hand on the lever")
		for _, k in shot.keys do
			Assert.truthy(dist(k.pos, ST.hoardsworth.at) < 12, "the camera stays in on him")
		end
		-- the beats inside the shot: monocle glint, ring flash, then the yank
		local seen = {}
		for _, e in shot.events do
			seen[(e.id or e.cue) :: string] = e.at
		end
		Assert.truthy(seen.glint and seen.glint < 1, "the monocle glints early")
		Assert.truthy(seen.ring and seen.ring > seen.glint, "then the ring flashes on the knob")
		Assert.truthy(seen.IntroLever and seen.IntroLever > seen.ring, "then he yanks it")
		Assert.near(IntroPlan.LEVER.at, IntroPlan.startOf(i) + seen.IntroLever, 1e-9, "the handle swings on the cue")
		for s = 0, 2.6, 0.1 do
			Assert.truthy(IntroPlan.laughing(IntroPlan.startOf(i) + s), string.format("laughing at %.1f s", s))
		end
		Assert.falsy(IntroPlan.laughing(IntroPlan.startOf(i) - 1), "not before the close-up")
		Assert.falsy(IntroPlan.laughing(IntroPlan.LEVER.at + 0.4), "the yank is effort, not a laugh")
		local kinds = {}
		for _, l in ST.villainLights do
			kinds[l.kind] = true
			Assert.truthy(I.VILLAIN_LIGHTS[l.kind] ~= nil, "Config.Intro.VILLAIN_LIGHTS." .. l.kind)
			Assert.truthy(dist(l.from, l.to) < 25, l.kind .. ": in range of him")
		end
		Assert.truthy(kinds.under and kinds.key and kinds.rim and kinds.hand, "under, key, rim and the hand kicker")
		Assert.truthy(I.RING and #I.RING.SIZE == 3, "the ring's numbers in Config.Intro")
	end)

	test(
		"the garage is lit: practicals inside, the aurora's light from outside, nothing near-black by design",
		function()
			local ST = IntroPlan.STAGE
			local g = ST.garage
			local x0, x1 = g.centre[1] - g.size[1] / 2, g.centre[1] + g.size[1] / 2
			local z0, z1 = g.centre[3] - g.size[3] / 2, g.centre[3] + g.size[3] / 2
			local function inside(p: { number }, pad: number): boolean
				return p[1] > x0 - pad and p[1] < x1 + pad and p[3] > z0 - pad and p[3] < z1 + pad and p[2] < g.size[2]
			end
			Assert.truthy(inside(ST.workLamp, 0) and ST.workLamp[2] > 7.8, "the work lamp hangs over the van's roof")
			Assert.truthy(
				math.abs(ST.workLamp[1] - ST.van.at[1]) < 1 and math.abs(ST.workLamp[3] - ST.van.at[3]) < 3,
				"right over the van"
			)
			Assert.truthy(inside(ST.doorLamp, 0) and ST.doorLamp[3] > ST.rookie.at[3], "the cage lamp tops the Rookie")
			Assert.truthy(math.abs(ST.doorGlow.centre[3] - z1) < 1, "the aurora pours in at the open door")
			for _, w in ST.windows do
				Assert.truthy(
					math.abs(w[3] - z0) < 0.2 and w[2] - ST.windowSize[2] / 2 > 7.8,
					"a high back window over the van"
				)
			end
			-- the rim: from behind the Rookie, aimed at his head and cap
			local head = { ST.rookie.at[1], 4.4, ST.rookie.at[3] }
			Assert.truthy(dist(ST.rim.to, head) < 0.5, "the cool rim aims at his head")
			Assert.truthy(ST.rim.from[3] < ST.rookie.at[3] - 10, "from behind him")
			-- the moods: the garage is not the old near-dark (ambient sum >= 150 of 765)
			local m = IntroPlan.MOODS.garage
			Assert.truthy(m.ambient[1] + m.ambient[2] + m.ambient[3] >= 150, "a cool fill, never black")
			Assert.truthy(m.ambient[3] > m.ambient[1], "the fill is cool (the warm practicals are the contrast)")
			local G = I.GARAGE
			for _, key in { "HEADLIGHT", "WORK_LAMP", "DOOR_LAMP", "DOOR_GLOW", "RIM", "STRING", "BEAM", "SHAFT" } do
				Assert.truthy(G[key] ~= nil, "Config.Intro.GARAGE." .. key)
			end
			-- the reveal's last frame sits right of his axis, so the beams fan out past him rather than into the lens
			local one
			for _, sh in IntroPlan.SHOTS do
				if sh.id == "one" then
					one = sh
				end
			end
			local k = one.keys[#one.keys]
			Assert.truthy(k.pos[1] - ST.rookie.at[1] > 1.5, "a three-quarter push-in")
			Assert.truthy(I.TITLE_VEIL >= 0.4, "the title's veil lets the lit crew through")
		end
	)
end
