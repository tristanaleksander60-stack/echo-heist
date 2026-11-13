--!strict
-- Hud/Run: the run's state and flow. A run starts (onRun), events react (onEvent:
-- busted / zapped / bank / alarm / swarm / tiers / hide...), the run ends (onRunEnd:
-- the reason it ended stays up until the deck opens), and every frame (update) drives
-- the timer, the loot meter, the Alarm Run counter, REWIND's lock and pulse, the
-- objective line, the L1 stuck hints and Interact.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Codec = require(Shared:WaitForChild("Rec"):WaitForChild("Codec"))
local Sim = Shared:WaitForChild("Sim")
local EventLog = require(Sim:WaitForChild("EventLog"))
local Interact = require(Sim:WaitForChild("Interact"))
local HeistShared = Shared:WaitForChild("Heist")
local Help = require(HeistShared:WaitForChild("Help"))
local HudLayout = require(HeistShared:WaitForChild("HudLayout"))
local Palette = require(HeistShared:WaitForChild("Palette"))
local RunMarkers = require(HeistShared:WaitForChild("RunMarkers"))
local Strings = require(HeistShared:WaitForChild("Strings"))
local Mix = require(Shared:WaitForChild("Audio"):WaitForChild("Mix"))

local Icons = require(script.Parent.Parent:WaitForChild("Icons"))
local Sound = require(script.Parent.Parent:WaitForChild("Sound"))
local Ui = require(script.Parent.Parent:WaitForChild("Ui"))
local Common = require(script.Parent:WaitForChild("Common"))

local H = Config.Heist
local U = Config.Ui
local AU = Config.Audio
local EV = EventLog.EV
local KIND = Codec.EVENT
local FAIL = Interact.FAIL
local FH = Config.FirstPerson.HUD
local localPlayer = Players.LocalPlayer

local Run = {}

function Run.build(ctx: any)
	local hud = ctx.hud
	local state = ctx.state
	local actions = ctx.actions
	local top = ctx.top
	local controls = ctx.controls
	local msg = ctx.msg
	local hints = ctx.hints
	local endBtn = controls.endBtn
	local interactBtn = controls.interactBtn

	local breath: (now: number) -> number
	local endedCount = 0
	local runStartAt = 0
	local myEnded = false
	local hintStage = 0
	local lastWhole = -1
	local lastPulse = -1
	local lastTView = 0
	local worldLocks: { any } = {} -- WorldView.timeLocks() (a cached array)
	-- objective line (§7.4): shown when it changes, then hidden after OBJECTIVE_SECONDS
	local objText = ""
	local objSince = 0
	local lastLockToast = -math.huge
	local alarmSeenHeist = false -- party levels: the first till alarm is the GETAWAY stamp
	local alarmToastRun = -1 -- the run whose alarm already had its in-run toast
	local l1Counted = false -- this run's armed L1 auto-end is counted (ctx.l1ArmedRuns)
	local function isParty(): boolean
		return Common.isParty(state)
	end
	local function isTutorial(): boolean
		return Common.isTutorial(state)
	end

	function hud.onRun(m: any)
		ctx.garage.close()
		Ui.hide(ctx.results.card)
		Ui.hide(ctx.deck.panel)
		Ui.hide(ctx.deck.readyWait)
		Ui.hide(msg.preparing)
		ctx.runHud.Visible = true
		ctx.setInHeist(true)
		top.setRunBoxShown(true)
		msg.pauseChip.Visible = true
		ctx.waiting = false
		endedCount = 0
		myEnded = false
		msg.setSpectate("")
		msg.setHidden(false)
		hud.placeRail(false)
		objText, objSince = "", 0
		local n = tonumber(m.run) or 1
		if n <= 1 then
			alarmSeenHeist = false
			ctx.stopsLineUntil = 0
			ctx.l1ArmedRuns = 0
		end
		l1Counted = false
		-- A redo run says so (§7.4): "REDO 3" in the run label colour.
		local deck = state.deck
		local redo = if deck and not deck.locked then tonumber(deck.redo) or 0 else 0
		top.runLabel.Text = if redo > 0 then Strings.redoRun(redo) else Common.runName(state, n)
		local dawn = Common.dawnRuns(state)
		top.runLabel.TextColor3 = if dawn and n >= dawn then Palette.amber else Palette.hueFor(state.mySeat or 1)
		top.setSeatHue(Palette.hueFor(state.mySeat or 1))
		runStartAt = os.clock() + (m.transition or 0)
		hintStage = 0
		lastWhole = -1
		hints.clear()
		top.clearMarkers()
		-- Your clones' recorded events on the run bar (grabs), so you can time against them.
		local length = if state.clock then state.clock.length else 30
		local cloneRecs = {}
		for _, a in m.actors do
			local any = a.kind == "clone" and state.recs[a.key]
			if any then
				table.insert(cloneRecs, any)
			end
			local rec = a.kind == "clone" and a.owner == localPlayer.UserId and state.recs[a.key]
			if rec then
				for _, e in rec.events do
					if e.kind == KIND.Grab then
						top.marker(e.t, length, Palette.gold, Strings.MARK_GRAB, "coin")
					end
				end
			end
		end
		-- Next-event markers: Gus's turns and the laser windows every clone in this run opens.
		if state.level then
			local ok, markers = pcall(RunMarkers.compute, state.level, cloneRecs, length)
			if ok then
				top.worldMarkers(markers, length)
			end
		end
		-- Redo: the replaced clone's old grabs in grey, so you can see what you are redoing.
		local old = if redo > 0 and deck and deck.slots[redo] then state.recs[deck.slots[redo].key] else nil
		if old then
			for _, e in old.events do
				if e.kind == KIND.Grab then
					top.marker(e.t, length, Palette.tapeGrey, Strings.MARK_GRAB, "coin")
				end
			end
		end
		hints.onRun(m, n)
		GuiService.SelectedObject = nil
	end

	-- Dawn warnings at the start of a run (party and daily levels, §4.2, §5.3).
	function hud.dawnWarning(n: number)
		local dawn = Common.dawnRuns(state)
		if not dawn then
			return
		end
		local left = dawn - n
		if left <= 0 then
			hud.toast(Strings.LAST_RUN_BEFORE_SUNRISE)
		elseif left < H.DAWN_WARN_RUNS then
			hud.toast(Strings.sunriseAfter(left))
		end
	end

	function hud.onRunEnd(p: any)
		interactBtn.Visible = false
		controls.ffPill.Visible = false
		top.alarmPill.Visible = false
		top.objective.Visible = true
		-- Passing lines go; why the run ended stays until the deck opens (WALKTHROUGH
		-- P1-10: it used to be wiped in the same frame in solo).
		msg.keepReason()
		msg.setHidden(false)
		hints.clear()
		local nextRun = (state.run and state.run.run or 0) + 1
		ctx.deck.setNextRun(nextRun)
		local summary = p and p.summary
		if type(summary) ~= "table" then
			return
		end
		if summary.escaped and not isParty() then
			hud.bigStamp(Strings.STAMP_ESCAPED, Palette.gold)
		end
		local alarm = summary.alarm
		-- One alarm message per run: no repeat when the in-run toast already said it, and
		-- none on party levels, where the till alarm is the getaway, not a mistake.
		local runIndex = tonumber(p.run) or -1
		if type(alarm) == "table" and not summary.escaped and not isParty() and alarmToastRun ~= runIndex then
			local hint = state.deck and state.deck.hint
			if alarm.kind == "catch" then
				hud.toast(Strings.GUS_RAISED_ALARM)
			elseif alarm.kind == "clone" and alarm.ownerId == localPlayer.UserId and not hint then
				local seat = state.mySeat or 1
				hud.toast(Strings.cloneSetOffAlarm(Strings.cloneName(seat, tonumber(alarm.slot) or 0, seat)))
			elseif alarm.kind == "live" and alarm.ownerId == localPlayer.UserId then
				hud.toast(Strings.YOU_SET_OFF_ALARM)
			end
		end
	end

	-- "Locked: opens in 0:14" (the same countdown the button and the till label show),
	-- at most once per TOAST_SECONDS while a kid mashes the till.
	local function lockedToast(opensAt: number?)
		local now = os.clock()
		if now - lastLockToast < H.TOAST_SECONDS then
			return
		end
		lastLockToast = now
		local at = opensAt
		if not at then
			for _, l in worldLocks do
				at = if at then math.min(at, l.opensAt) else l.opensAt
			end
		end
		Sound.play("UIError")
		hud.toast(if at then Strings.lockedOpensIn(Ui.clock(math.max(0, at - lastTView))) else Strings.LOCKED_WAIT)
	end

	-- Event-log entries (already decoded) for HUD reactions.
	function hud.onEvent(e: any, live: boolean)
		local run = state.run
		if not run then
			return
		end
		local a = run.actorById[e.a]
		local hz = Config.Rec.HZ
		local length = if state.clock then state.clock.length else 30
		hints.onEvent(e, live)
		if e.kind == EV.EndRun or e.kind == EV.Timeout or e.kind == EV.Left then
			endedCount += 1
			if Common.myActor(a) then
				myEnded = true
				-- Only when others are still running (solo: the run is already over).
				local othersRunning = (state.liveCount or 1) > endedCount
				if e.kind == EV.Timeout then
					msg.setReason(Strings.TIME_UP)
					if live then
						hints.fail(Help.CAUSE.Timeout)
					end
				elseif othersRunning and not isTutorial() then
					msg.setSpectate(Strings.WAIT_FOR_CREW)
				end
			end
		elseif e.kind == EV.Caught then
			local target = run.actorById[e.b]
			endedCount += 1
			if Common.myActor(target) then
				myEnded = true
				msg.setReason(Strings.CAUGHT_BY_GUS, Strings.CAPTION_CAUGHT)
				if live then
					hud.flashRed()
					-- the stamp, then the cause's advice line, after the busted view's ease to Gus
					hud.catchView(function()
						hud.bigStamp(Strings.STAMP_BUSTED, Palette.alarm)
						hints.fail(Help.CAUSE.Caught)
					end)
				end
			end
		elseif e.kind == EV.Zap then
			if a and a.kind == "live" then
				endedCount += 1
				if a.owner == localPlayer.UserId then
					myEnded = true
					msg.setReason(Strings.ZAPPED_BY_LASER, Strings.CAPTION_ZAPPED)
					if live then
						hud.flashRed()
						hud.bigStamp(Strings.STAMP_ZAPPED, Palette.alarm)
						hints.fail(Help.CAUSE.Zapped)
					end
				end
			elseif a and a.owner == localPlayer.UserId then
				top.marker(e.tick / hz, length, Palette.alarm, Strings.MARK_ZAP, "bolt")
			end
		elseif e.kind == EV.Busted then
			local target = run.actorById[e.b]
			if target and target.owner == localPlayer.UserId then
				top.marker(e.tick / hz, length, Palette.alarm, Strings.MARK_BUST, "cross")
			end
		elseif e.kind == EV.Stuck then
			if a and a.owner == localPlayer.UserId then
				top.marker(e.tick / hz, length, Palette.alarm, Strings.MARK_BUST, "cross")
			end
		elseif e.kind == EV.Bank and live then
			local value = 0
			local level = state.level
			local def = level and level.loot[e.b]
			if def then
				value = def.value
			end
			local who = if a and a.kind == "clone" then Strings.cloneName(a.seat, a.slot, state.mySeat or 1) else nil
			hud.toast(Strings.banked(who, Ui.money(value)))
			-- The meter pops when its count-up lands (TopBar), after the "+$100!" flight (Hud/BankFly).
		elseif e.kind == EV.Grab and live then
			local level = state.level
			local def = level and level.loot[e.b]
			if def and def.kind == "Diamond" then
				msg.diamondMoment()
			end
		elseif e.kind == EV.Squeeze and live then
			hud.toast(Strings.CREW_WAITING)
		elseif e.kind == EV.GoalMet and live then
			hud.toast(Strings.forDevice("GOAL_BANKED", Common.device(), state.fpView == true))
		elseif e.kind == EV.Swarm and live then
			-- "8 OF ME" (count-correct): copies of you; in co-op "16 ROBBERS" for the crew.
			if e.a == (state.mySeat or 1) then
				local need = Config.Sim.SWARM_OF_ME
				if e.b >= need then
					hud.bigStamp(Strings.ofMe(e.b), Palette.hueFor(state.mySeat or 1), H.SWARM_STAMP_SECONDS)
				elseif e.c >= need and #(state.crew or {}) > 1 then
					hud.bigStamp(Strings.robbers(e.c), Palette.gold, H.SWARM_STAMP_SECONDS)
				end
			end
		elseif e.kind == EV.Tier and live then
			hud.bigStamp(Strings.stampTier(e.a), Palette.gold, H.TIER_STAMP_SECONDS)
		elseif e.kind == EV.AlarmOn and live then
			alarmToastRun = run.run
			if isParty() then
				-- The party's till is the getaway, not a mistake: one stamp per heist, then
				-- only the counter (no blame, no repeat).
				if not alarmSeenHeist then
					alarmSeenHeist = true
					hud.bigStamp(Strings.STAMP_GETAWAY, Palette.gold)
					hud.toast(Strings.TILL_ALARM)
				end
			else
				hud.bigStamp(Strings.STAMP_ALARM, Palette.alarm)
				hud.flashRed()
				if a and a.kind == "clone" then
					hud.toast(Strings.cloneSetOffAlarmNow(Strings.cloneName(a.seat, a.slot, state.mySeat or 1)))
				elseif e.a == 0 then
					hud.toast(Strings.GUS_RAISED_ALARM_RUN)
				else
					hud.toast(Strings.RUN_FOR_VAN)
				end
			end
		elseif e.kind == EV.VanLeft and live then
			hud.bigStamp(Strings.STAMP_VAN_LEFT, Palette.alarm)
			hints.fail(Help.CAUSE.Alarm)
		elseif e.kind == EV.Dawn and live then
			-- A party's sunrise is the celebration; a story level's is OUT OF TIME + a tip (PLAN §5).
			hints.onDawn()
		elseif e.kind == EV.HeistComplete and live then
			hud.bigStamp(Strings.STAMP_HEIST_COMPLETE, Palette.gold)
		elseif e.kind == EV.Rejected and live then
			if Common.myActor(a) and e.c == FAIL.Locked then
				lockedToast(nil)
			end
		elseif e.kind == EV.Hidden then
			if Common.myActor(a) then
				msg.setHidden(true) -- the tuck sound comes from EventCues (Hidden)
			end
		elseif e.kind == EV.Unhidden then
			if Common.myActor(a) then
				msg.setHidden(false)
			end
		elseif e.kind == EV.PlateDown and live then
			-- L1: the clone's first press is the moment "your clone stops where you stop" lands
			-- (PlateDown: a = plate, b = actor).
			local presser = run.actorById[e.b]
			if
				isTutorial()
				and presser
				and presser.kind == "clone"
				and presser.owner == localPlayer.UserId
				and ctx.stopsLineUntil == 0
			then
				ctx.stopsLineUntil = os.clock() + H.STOPS_LINE_SECONDS
			end
		end
	end

	---------------------------------------------------------------------------
	-- Per frame
	---------------------------------------------------------------------------
	local function myRootLevelPos(): Vector3?
		local char = localPlayer.Character
		local r = char and char:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") and state.origin then
			return r.Position - state.origin
		end
		return nil
	end

	local nearLoot: number? = nil
	local nearLock: number? = nil
	local nearSwitch: number? = nil -- first person: a looked-at switch (Press)
	local lookVerb: string? = nil -- first person: the looked-at target's verb (Heist/LookTarget)
	local shownBtnIcon = "coin"

	-- E / ButtonX / a click with the cursor locked / the GRAB button. The target is the one you look at in
	-- first person (Heist/LookTarget), else the nearest loot; the server re-checks everything (Sim/Interact).
	function hud.interact()
		if nearSwitch then
			ctx.lastGrabTap = os.clock()
			actions.interact(KIND.Press, nearSwitch)
			if actions.hands then
				actions.hands("press")
			end
			Ui.pop(interactBtn)
			if ctx.reticle then
				Ui.pop(ctx.reticle.chip)
			end
			return
		end
		if not nearLoot then
			return
		end
		ctx.lastGrabTap = os.clock()
		local opensAt = nearLock
		if opensAt and lastTView < opensAt - H.LOCKED_SLACK then
			lockedToast(opensAt)
			return
		end
		actions.interact(KIND.Grab, nearLoot)
		if actions.hands then
			actions.hands("reach") -- the hands reach before the server answers (latency masking)
		end
		Ui.pop(interactBtn)
		if ctx.reticle then
			Ui.pop(ctx.reticle.chip)
		end
	end

	-- The onboarding finger's GRAB target (Hud/Hints): the button when it shows GRAB, else in first person
	-- the prompt chip while it shows GRAB.
	function ctx.grabPointTarget(): GuiObject?
		local grabbing = lookVerb == nil or lookVerb == "grab"
		if interactBtn.Visible and interactBtn.BackgroundColor3 == Palette.gold and grabbing then
			return interactBtn
		end
		local r = ctx.reticle
		if r and lookVerb == "grab" and Ui.isShown(r.chip) then
			return r.chip
		end
		return nil
	end

	-- REWIND's breath, 0..1: the world's plate pulse when it gives one (hud.setPlatePulse), else its
	-- own clock at Config.Ui.BREATH_HZ. Reduced motion: a steady half glow.
	breath = function(now: number): number
		if state.reduced then
			return 0.5
		end
		local pulse = ctx.platePulse
		if pulse then
			local ok, v = pcall(pulse)
			if ok and type(v) == "number" then
				return math.clamp(v, 0, 1)
			end
		end
		return 0.5 - 0.5 * math.cos(now * 2 * math.pi * U.BREATH_HZ)
	end

	-- Hooks for the world track (PLAN_STEAM_PLUS §4.3 U3): REWIND breathes in sync with the plate
	-- pulse when it is the right move. `level` returns the plate pulse's level 0..1 (nil: the HUD's
	-- own clock); setRewindRightMove marks REWIND as the right move outside the L1 rule.
	function hud.setPlatePulse(level: (() -> number)?)
		ctx.platePulse = level
	end
	function hud.setRewindRightMove(on: boolean)
		ctx.rewindRightMove = on
	end

	-- First person's reduced run HUD (HudLayout fpRun): the objective / alarm line moves under the reticle,
	-- the rail to the bottom, and the loot meter only peeks in for LOOT_PEEK_SECONDS after it changes (and
	-- while you carry). Off: everything back where the other cameras have it.
	local fpPlaced: boolean? = nil
	local lootPeekUntil = 0
	local lastBanked: any = nil
	function ctx.fpLayout(fp: boolean)
		if fp ~= fpPlaced then
			fpPlaced = fp
			Common.place(top.objective, if fp then HudLayout.OBJECTIVE_FP else HudLayout.OBJECTIVE)
			Common.place(top.alarmPill, if fp then HudLayout.ALARM_FP else HudLayout.ALARM)
			ctx.fpRail = fp
			hud.placeRail(false)
			if not fp then
				Ui.show(top.lootBox)
				if ctx.reticle then
					ctx.reticle.set(false, nil)
				end
			end
		end
		if fp then
			local f = state.folder
			local banked = f and f:GetAttribute("Banked")
			local now = os.clock()
			if banked ~= lastBanked then
				lastBanked = banked
				lootPeekUntil = now + FH.LOOT_PEEK_SECONDS
			end
			Ui.setShown(top.lootBox, state.carrying == true or now < lootPeekUntil)
		end
	end

	function hud.update(tView: number, now: number, dt: number, world: any)
		if state.where ~= "heist" then
			return
		end
		if state.phase ~= "Run" or not state.clock then
			-- between runs and after: the meter still lands
			ctx.fpLayout(false)
			top.updateLoot(now)
			ctx.deck.updateBetween()
			hints.update(now, dt)
			return
		end
		lastTView = tView
		local clock = state.clock
		local length = clock.length
		local remaining = math.max(0, length - tView)
		local red = remaining <= H.TIMER_RED_SECONDS
		top.setTimer(Ui.clock(remaining), if red then Palette.alarm else Palette.white)
		-- Countdown ticks for the last COUNTDOWN_FROM seconds (docs/AUDIO.md §9 item 19); in the
		-- last TIMER_PULSE_SECONDS the digits pop 1.12 -> 1 on each whole second (POLISH §4.2).
		local whole = math.ceil(remaining - 1e-6)
		if whole ~= lastWhole and lastWhole >= 0 and whole <= H.TIMER_PULSE_SECONDS then
			top.popTimer()
		end
		if whole ~= lastWhole and os.clock() >= runStartAt then
			if lastWhole >= 0 then
				local step = Mix.countdownStep(remaining, AU.COUNTDOWN_FROM)
				if step then
					Sound.play("CountdownTick", { step = step, caption = step == 0 })
				end
				if whole >= 1 and whole <= AU.HEARTBEAT_FROM then
					Sound.play("Heartbeat")
				end
			end
			lastWhole = whole
		end
		top.barFill.Size = UDim2.fromScale(math.clamp(tView / math.max(length, 0.01), 0, 1), 1)
		top.updateLoot(now)

		-- Alarm Run counter and the red pulse (once per ALARM_PULSE_SECONDS, ≤ 3 flashes/s).
		-- While it runs it is the objective (the line takes its place).
		local folder = state.folder
		local alarmOn = folder ~= nil and folder:GetAttribute("AlarmOn") == true
		top.alarmPill.Visible = alarmOn
		top.objective.Visible = not alarmOn
		if alarmOn and folder then
			local vanAt = folder:GetAttribute("AlarmVanAt")
			local lockAt = folder:GetAttribute("AlarmLockAt")
			local text = Strings.alarmVan(Ui.clock(math.max(0, (if type(vanAt) == "number" then vanAt else 0) - tView)))
			if type(lockAt) == "number" and lockAt >= 0 and lockAt > tView then
				text ..= Strings.alarmDoorsLock(Ui.clock(lockAt - tView))
			end
			top.alarmLabel.Text = text
			local beat = math.floor(now / H.ALARM_PULSE_SECONDS)
			if beat ~= lastPulse then
				lastPulse = beat
				-- party levels: the getaway is a beat, not a warning (no red pulse)
				if not state.reduced and not isParty() then
					msg.alarmPulse()
				end
			end
		end

		-- REWIND: locked ring for the first 1.5 s; co-op count; spectators lose it.
		local started = os.clock() >= runStartAt
		endBtn.Visible = not myEnded and started
		local lockFrac = math.clamp(1 - tView / Config.Rec.END_RUN_LOCK_SECONDS, 0, 1)
		controls.lock.set(lockFrac)
		local crew = state.liveCount or 1
		endBtn.Text = if crew > 1 then Strings.rewindCrew(endedCount, crew) else Strings.REWIND

		local pos = myRootLevelPos()
		local text, pulseEnd, sticky = hints.objectiveText(tView, pos)
		if text ~= objText then
			objText, objSince = text, now
		end
		top.objective.Text = if sticky or now - objSince < Common.OBJECTIVE_SECONDS then text else ""
		-- L1 while the auto-end is armed: REWIND pulses only while you stand on the plate
		-- (a steady glow under reduced motion) and is dimmed off it; stuck hints run in any
		-- such run, so a kid who ended run 1 off the plate is led back (§7.5).
		local hue = Palette.hueFor(state.mySeat or 1)
		local armed = isTutorial() and hints.autoEndArmed()
		ctx.l1PulseEnd = armed and pulseEnd
		if armed and not l1Counted then
			l1Counted = true
			ctx.l1ArmedRuns = (ctx.l1ArmedRuns or 0) + 1
		end
		if armed then
			-- REWIND breathes with the plate pulse (hud.setPlatePulse; a steady glow under reduced motion).
			endBtn.BackgroundColor3 = if pulseEnd then hue:Lerp(Palette.white, 0.6 * breath(now)) else hue
			endBtn.BackgroundTransparency = if pulseEnd then 0 else 0.55
			if not pulseEnd and not myEnded then
				-- The stage carries across runs: a kid who ended earlier armed runs off the plate
				-- starts this one further along (Help.tutorialHintStage; the bots check it).
				local stage = Help.tutorialHintStage(tView, math.max(0, (ctx.l1ArmedRuns or 1) - 1))
				while hintStage < stage do
					hintStage += 1
					actions.hint(Common.HINTS[hintStage] or "other")
				end
				if hintStage > 0 then
					hints.show(world, now, hintStage)
				end
			else
				hints.clear()
			end
		else
			endBtn.BackgroundColor3 = if ctx.rewindRightMove then hue:Lerp(Palette.white, 0.6 * breath(now)) else hue
			endBtn.BackgroundTransparency = 0
			if hintStage > 0 then
				hintStage = 0
				hints.clear()
			end
		end

		-- Contextual Interact. First person: what you look at (Heist/LookTarget: loot, a switch, the van while
		-- you carry), shown by the reticle's prompt chip; the GRAB button stays as the touch fallback and is
		-- labelled for that target (on touch it also falls back to the nearest loot). Other cameras: the nearest
		-- loot in range, as before. Never while your bag is full or you are spectating.
		worldLocks = world.timeLocks()
		nearLoot = nil
		nearLock = nil
		nearSwitch = nil
		lookVerb = nil
		local bagFull = (state.carryCount or 0) >= (state.myCapacity or 1)
		local can = pos ~= nil and not myEnded and started
		local fp = state.fpView == true
		local touch = Common.usingTouch()
		local look = actions.look
		local target = if look then look.update(tView, fp and can) else nil
		local prompt: any = nil
		local showButton = false
		local function lootLabel(value: number, opensAt: number?): (string, Color3, boolean)
			if opensAt and tView < opensAt then
				return Strings.lockedFor(Ui.clock(opensAt - tView)), Palette.steel, true
			end
			return Strings.grab(Ui.money(value)), Palette.gold, false
		end
		if target then
			lookVerb = target.verb
			local key = if touch
				then Strings.KEY_TAP
				elseif Common.usingGamepad() then Strings.KEY_PAD
				else Strings.KEY_E
			if target.kind == "loot" then
				nearLoot, nearLock = target.index, target.opensAt
				local word, colour, locked = lootLabel(target.value or 0, target.opensAt)
				interactBtn.Text, interactBtn.BackgroundColor3 = word, colour
				prompt = { verb = if locked then "locked" else "grab", text = word, colour = colour, key = key }
				showButton = touch
			elseif target.kind == "switch" then
				nearSwitch = target.index
				local word = Strings.FP_VERB[target.verb] or Strings.FP_VERB.press
				interactBtn.Text, interactBtn.BackgroundColor3 = word, Palette.gold
				prompt = { verb = target.verb, text = word, colour = Palette.gold, key = key }
				showButton = touch
			else
				-- the van: banking is walking in (positional), so no key and no button
				prompt = { verb = "bank", text = Strings.FP_BANK, colour = Palette.exit }
			end
		elseif can and not bagFull and (not fp or touch) then
			local worldPos = state.origin + (pos :: Vector3)
			local index, value, opensAt = world.nearestLoot(worldPos, Config.Sim.INTERACT_RANGE)
			if index then
				nearLoot = index
				nearLock = opensAt
				local word, colour = lootLabel(value, opensAt)
				interactBtn.Text, interactBtn.BackgroundColor3 = word, colour
				showButton = true
			end
		end
		interactBtn.Visible = showButton
		local btnIcon = if nearSwitch then "door" else "coin"
		if btnIcon ~= shownBtnIcon and controls.interactIcon then
			local img = controls.interactIcon()
			if img then
				shownBtnIcon = btnIcon
				Icons.set(img, btnIcon)
			end
		end
		if ctx.reticle then
			ctx.reticle.set(fp and can, prompt)
		end
		ctx.fpLayout(fp or state.crewView == true) -- Crew View keeps the first-person layout (nothing jumps)
		controls.ffPill.Visible = folder ~= nil and folder:GetAttribute("CanFF") == true and not myEnded
		hints.update(now, dt)
	end

	function hud.setLiveCount(n: number)
		state.liveCount = n
	end
end

return Run
