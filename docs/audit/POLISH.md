# POLISH AUDIT: how "finished" Heist Yourself feels

_2026-11-12, premium-polish director pass. Scope: every player-facing element of the sim path (`Config.GAME_MODE = "sim"`, place v23). Sources read: CLAUDE.md, PROJECT_STATE.md, MASTERPLAN §3.4-3.5, §6.5-6.6, §7.1-7.5, STYLE_BIBLE, AUDIO.md, all of `src/client/Heist/*`, `src/client/Audio/AudioDirector.luau` (interface), `src/server/Heist/{Lobby,LevelBuilder,KitDresser,KitPlan}.luau`, the kit turntables in `docs/art/turntables/`. Compared against the LihFolk skills lihfolk-ui, roblox-ui-builder, lihfolk-vfx, lihfolk-sfx, lihfolk-tutorial and vault notes 47 (Game Feel and Juice: Hit-Stop and Screen Shake Tuning, Reward Moments, Squash Stretch and Anticipation, Juice on a Budget), 05 (UI Motion Language and Timing, Text Fonts and Rich Text) and 60 (What Craft Looks Like on Roblox). No game code was changed._

**Classes.** FINISHED: ships as is at a premium bar. FUNCTIONAL-BUT-PLAIN: correct, readable and wired, but looks or feels like a prototype. PLACEHOLDER: stands in for something the plan names (greybox, primitive rig, default sprite). MISSING: the plan or the genre needs it and nothing exists.

---

## 0. Verdict in one paragraph

The game is **systems-complete and feel-thin**. Everything is wired, server-authoritative, mobile-scaled, reduced-motion aware and captioned. That is rare and valuable, and most of it does not need to change. But nearly every surface stops at "correct": flat ink rectangles with white text, unicode glyphs as icons, panels that snap on with `Visible = true`, rewards that are a toast, a guard built from 10 grey boxes that swings his legs on a sine wave, a garage lobby made of white blocks, and no camera work at all outside the rewind and the Line-up. The two signature moments are the exception: the **Rewind** and the **Crew Line-up** are close to finished. **First 10 minutes: about 38 % finished** against a premium bar (table §2). The fastest route to "premium" is not more systems; it is one UI kit, one icon atlas, one motion pass, five reward moments and the Gus mesh that already exists but is not used.

---

## 1. Inventory

### 1.1 HUD during a run (`src/client/Heist/Hud.luau`, `Ui.luau`)

| Element | Class | Evidence (what makes it plain) |
|---|---|---|
| Font | FUNCTIONAL-BUT-PLAIN | Good choice, not Gotham: `Ui.FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)` (Ui.luau:25). But one family, one weight, everywhere: titles, stamps, numbers and captions are all Builder Sans ExtraBold. No display face for stamps, no tabular face for the timer (proportional digits make "0:11" and "0:10" change width every second). |
| Text outline | PLACEHOLDER | Legacy 1 px stroke on every label: `t.TextStrokeTransparency = 0.6` (Ui.luau:70). No `UIStroke` on text anywhere, so white text over bright scenes (Warm Marble pools, bloom) has no ink edge. |
| Panels (top bar, loot box, clone strip, pills) | FUNCTIONAL-BUT-PLAIN | Every panel is `Ui.frame`: `BackgroundColor3 = Palette.ink`, `BackgroundTransparency = 0.15`, `BorderSizePixel = 0` (Ui.luau:52-56) plus a `UICorner`. No stroke, no gradient, no shadow, no header, no inner highlight. The look is "dark rounded rectangle", not "Neon-Noir". |
| Buttons | FUNCTIONAL-BUT-PLAIN | `Ui.button`: flat `Palette.steel` face, `UICorner` 12, a 2 px ink `UIStroke`, press `Scale = 0.92` over 0.08 s and Back release 0.14 s (Ui.luau:83-133). Good bones (child `UIScale`, `Activated`, click sound, reduced motion). Missing: a lip/raised edge (roblox-ui-builder: "buttons look pressable, never flat rectangles"), a face gradient, a hover visual (hover only plays a sound), a disabled state. |
| Icons | PLACEHOLDER | No image icons exist. Every icon is a text glyph: `"◀◀\nEND RUN"`, `"⏩ HOLD"` (Hud.luau:274), `"❚❚"` (Hud.luau:461), `"☾ DAWN"`, `"◎ VAN LEAVES"`, `"◐ HIDDEN"`, `"⚡"` run-bar marker, `"✓"`, `"★/☆"`, seat glyphs `●■▲◆`. `⏩` (U+23E9) and `⚡` (U+26A1) have emoji presentation and render as colour emoji, the rest fall back to whatever font has the glyph, so weights and baselines differ per platform. |
| Layout / safe area / scale | FINISHED | One device `UIScale` on the root, clamped 0.9-1.5 against a 720 x 330 design (Hud.luau:166-181, Config.Heist.UI_DESIGN_SIZE); `CoreUISafeInsets`; edge art in a separate `None` gui; 72 px taps (64.8 px at the floor). This matches roblox-ui-builder exactly. Keep. |
| Top centre: RUN n + tape counter + run bar | FUNCTIONAL-BUT-PLAIN | 330 x 62 ink plate, a 6 px bar `BackgroundColor3 = Palette.plumHi` with a white fill, event markers as 16 px text glyphs. Last 10 s: `timerScale.Scale = 1 + 0.08 * sin(...)` (a continuous wobble, not a tick); last 5 s red text + "◎". Reads, but does not look like a tape counter. |
| Loot meter (top left) | FUNCTIONAL-BUT-PLAIN | Text-only `"$0 / $100"` in Heist Gold in a 230 x 44 ink box. The count-up (0.35-1.0 s, ticks, ding) is real and good; there is no bar, no coin icon, nothing flies into it. |
| Clone strip (top right) | FUNCTIONAL-BUT-PLAIN | `TextLabel`s with `"●3"` in the seat hue; red flags become `"●✕"`. No chip shape, no enter pop when a clone joins, no busted shake. |
| END RUN | FUNCTIONAL-BUT-PLAIN | Correct size and placement (96 x 72 at `END_RUN_Y = 0.35`, GRAB guard 0.3 s). The 1.5 s lock is an ink frame that shrinks vertically (`lockRing.Size = UDim2.fromScale(1, lockFrac)`), not the ring the plan specifies. L1 pulse is a hard white/cyan blink at 3 Hz. |
| Interact (GRAB $100) | FUNCTIONAL-BUT-PLAIN | Gold slab with text; appears and disappears by `Visible`, no pop-in, no coin icon. |
| Objective line | FUNCTIONAL-BUT-PLAIN | Bare text with stroke 0.2, swaps instantly, hides after `OBJECTIVE_SECONDS`. No slide/fade. |
| Alarm pill, HIDDEN pill, FF pill | FUNCTIONAL-BUT-PLAIN | Correct glyph + word + colour; static. The HIDDEN edge vignette uses `UIGradient` (the only gradient in the HUD). |
| Message rail (toast, caption, spectate) | FUNCTIONAL-BUT-PLAIN | Fixed slots, no overlap, captions on by default (good accessibility). Text appears and disappears with no motion. |
| ❚❚ menu sheet | FUNCTIONAL-BUT-PLAIN | 420 x 190 ink frame, "Leave this heist?", two buttons. No backdrop dimmer, no entrance. |
| Stamps (RUN n, BUSTED, 8 OF ME, ALARM, HEIST COMPLETE...) | FUNCTIONAL-BUT-PLAIN | One 88 px white `TextLabel` with ink stroke that scales 1.25 → 1.0 Back Out (RewindDirector.luau:117-133, 280-318). Every stamp, from "RUN 2" to the "8 OF ME" TikTok moment, is the same label in a different colour. |
| Motion tokens | PLACEHOLDER | `Ui.MOTION.enter` and `.exit` are defined (Ui.luau:33-34) and **used nowhere**. Every panel in Hud.luau (10 places) opens with `Visible = true`. |

### 1.2 Menus (garage, level select, Clone Deck, results, store, settings)

| Element | Class | Evidence |
|---|---|---|
| Garage panel / level select ("PICK A TAPE") | FUNCTIONAL-BUT-PLAIN | A 700 x 326 ink frame with a `UIGridLayout` of 146 x 88 `TextButton`s whose whole content is one string: `"%d  %s\n%s\n%s"` (Hud.luau:1297) e.g. "1  BACK ROOM / 30 SEC RUNS / ★☆☆". Unlocked tapes are flat `steelHi`, the party tape flat `goldHi`, locked flat `plumHi`. No tape art, no medal stickers, no "next" highlight, no header, no backdrop. MASTERPLAN §7.4: "tapes on a shelf in the van with medal stickers". |
| Daily vault card | FUNCTIONAL-BUT-PLAIN | Ink card with a 2 px gold stroke, text and two buttons. Hidden until L1 is cleared, so outside the FTUE. |
| Crew list / JOIN friend | FUNCTIONAL-BUT-PLAIN | Text rows in seat hue; no avatar headshots. |
| "The van door opens..." card | PLACEHOLDER | `Text = "The van door opens..."` in a 440 x 120 ink frame (Hud.luau:577). This is the first thing a new player reads. |
| Clone Deck | FUNCTIONAL-BUT-PLAIN | Cards are 72 x 80 `TextButton`s with `Palette.badge(seat, i) .. "\n" .. status`; selection = white 3 px stroke. Actions are five grey text buttons. Works and teaches; does not show the clone (no mini path, no thumbnail). |
| Results card | FUNCTIONAL-BUT-PLAIN | 480 x 326 frame; medal stamps land 0.25 s apart with pitch-stepped RunStamp (good). But the haul is set at once (`resHaul.Text = Ui.money(over.banked)`, Hud.luau:1003/1022), no count-up, no trophy fly, no money rain (§7.3 "≤ 120 money-rain particles", "the new trophy flying to the van shelf"), buttons appear with the card (no 0.3 s input guard, vault Reward Moments). No Save Clip. |
| Store (Robux, dev products) | MISSING | Server `Data/Shop.luau` exists; no client UI anywhere (`grep "Shop\." src/client` is empty). Not needed in the first 10 minutes (FTUE: no offers). |
| Settings / Comfort module | MISSING | §7.4 launch accessibility: reduced motion, shake slider, flash cap, FOV-kick toggle, clone opacity, volume sliders. Only the OS `ReducedMotionEnabled` is followed. AudioDirector already exposes `setBusVolume` / `setMuted`. |

### 1.3 Character animation (`Rigs.luau`, `EchoView.luau`, `GusView.luau`)

| Element | Class | Evidence |
|---|---|---|
| Player | FINISHED (by Roblox) | Default character and `Animate`. Missing only the shared carry pose (below). |
| Clone (avatar rig) walk | FUNCTIONAL-BUT-PLAIN | Default R15 walk `rbxassetid://507777826`, speed-scaled in half-stud buckets, `Play(0.15)` / `Stop(0.2)`. Good. |
| Clone idle / jump / fall / run | MISSING | Under 1 stud/s the track stops and the rig stands in bind pose; a recorded jump rises with no jump pose; no run clip above 14 studs/s. A clone holding a plate for 25 s is a statue. |
| Clone carry pose | MISSING | Loot floats over any carrier: `cf = CFrame.new(pos + Vector3.new(0, 2.6, 0))` (WorldView.luau:607): no arms, no bob, no lag, no tilt. MASTERPLAN §6.7 lists a "heavy carry" clip. |
| Clone stuck / shrug | PLACEHOLDER | A text bubble only (`"...  ✕"`, `"?"`), the body keeps its last pose. |
| Mannequin (placeholder rig until the avatar template arrives) | PLACEHOLDER | 8 box `Part`s with a Neon belt and visor, limbs swung by `math.sin(phase) * SWING` (SWING = 32°, Rigs.luau:44). Seen by every player for the first seconds and by anyone whose template fails. |
| Gus | PLACEHOLDER | Client Gus is 10 box Parts (`local GUS = { { "Torso", Vector3.new(2.2, 2.1, 1.1) ...` Rigs.luau:139) in `steelLo` with a Neon torch. The only motion is the same sine leg/arm swing (`Rigs.pose`, GusView.luau:330). **The real Gus v0 exists**: an 18-piece rigid R15 mesh rig, 3,488 tris, uploaded (`KitData.luau`: `Gus = 90023245039286`, `Gus_Head`, `Gus_Flashlight`...), turntable `docs/art/turntables/Gus.png`, joint pivots designed for "the code pose player" (STYLE_BIBLE §12). Nothing on the client uses it. |
| Gus idle / suspicious / double-take / alert / chase / catch / doze | MISSING | Gus slides along his patrol with legs swinging; when he stops, he freezes. "?" and "!" are a 44 px label that changes text instantly. In L5 he "dozes in the back office" with no doze pose. The three authored clips of §6.7 (double-take, shrug, heavy carry) do not exist. |
| Line-up cheer + hop | FINISHED | Default R15 cheer `507770677` on avatars, arms-up on rigid rigs, one hop rippling 60 ms apart. |

### 1.4 VFX

| Moment | Class | Evidence |
|---|---|---|
| Rewind (§7.1) | FUNCTIONAL, near FINISHED | RewindDirector: 0.06 s white flash at 25 %, `ColorCorrectionEffect` sat -0.8 + cyan tint, `BlurEffect` 6, three VHS bands (flat white frames, `BackgroundTransparency = 0.85`), "◀◀", FOV 70 → 64 → 70, clones reel backwards along their recordings with trails, clunk + arpeggio, RUN stamp Back Out, Quick / Reduced / Intro variants, blur dropped by perf tier. Missing: the 66 ms freeze, owner-coloured path Beams (§7.1 "every actor's path reels backwards as owner-coloured Beams"), a scanline texture on the bands. |
| Clone spawn "tape print" (§6.5 #6) | FUNCTIONAL-BUT-PLAIN | 60 ms stagger + a Neon floor ring 1 → 5 studs in 0.4 s (EchoView `printRing`). Missing: the scanline sweep, any build-up of the body (it pops from invisible to opaque), dust. |
| Clone busted (§6.5 #6) | PLACEHOLDER | `entry.emitter:Emit(24)` of an emitter with no `Texture` (default sprite), `Lifetime 0.3-0.6`, 180° spread (EchoView.luau:88-99, 392) plus a "BUSTED" bubble and a 3 Hz blink. No glitch slices, no tape-ribbon. |
| Clone zapped | PLACEHOLDER | Same emitter recoloured ink, `Emit(16)`, "ZAP!" bubble. |
| Plate (§7.3) | FUNCTIONAL, near FINISHED | Sinks 0.15 studs, rim and cable take the presser's hue (Neon), presser glyph billboard, cable drains over the 0.4 s grace. Missing: the pulse that runs along the cable to the device. |
| Door | FUNCTIONAL, near FINISHED | 0.35 s slide, amber lamp blink while closing (≤ 3 Hz), DoorBeep, vault skin swings on its hinge with a turning dial. Missing: sill dust, a settle bump at the end of travel. |
| Laser | FUNCTIONAL-BUT-PLAIN | Ink/red/white-hot beam parts, hum loop by distance, 14 sparks on retract, 3-flicker telegraph. The beam hides instantly instead of collapsing. |
| Bank (§7.3) | PLACEHOLDER | `hud.toast(who .. "+" .. Ui.money(value))` + `Ui.pop(lootBox)` (Hud.luau:1911-1912). No 24-coin burst, no "+$100" flying to the meter (both specified in §7.3). The loot part just goes `Transparency = 1` (WorldView.luau:623). The bank is the most repeated reward in the game. |
| Loot at rest | FUNCTIONAL-BUT-PLAIN | Spins at 1.2 rad/s. STYLE_BIBLE: gold vs amber fails colour-blind, so "gold = sparkle" carries it; there is no sparkle anywhere. |
| Grab / drop | MISSING | No squash, no burst, no bounce. |
| Diamond dim | FUNCTIONAL | World dims 15 % for 0.6 s + DiamondShimmer. (Not in the first 10 minutes.) |
| Alarm Run | FUNCTIONAL-BUT-PLAIN | Rotating Neon beacons on the van and the loot, red edge pulse every `ALARM_PULSE_SECONDS`, "◎ VAN LEAVES 0:14", Gus dust puffs (default sprite). Reads; not exciting. |
| Player caught / BUSTED (§7.3) | FUNCTIONAL-BUT-PLAIN | Red flash 0.7 → 1 over 0.5 s + "BUSTED" stamp + wah-wah. Missing: the 66 ms freeze, the camera ease toward Gus, the 2 s busted-cam. |
| Swarm "8 OF ME" (§9.2 format 5, the T1 thumbnail moment) | PLACEHOLDER | `hud.bigStamp(string.format("%d OF ME", e.b), ...)` (Hud.luau:1926): the same white text stamp as "RUN 2". Nothing happens in the world. |
| Crew Line-up (§6.6) | FUNCTIONAL, near FINISHED | Scripted cut, low camera, figures walk to spots in record order, turn, cheer ripple, burned caption, SKIP chip, restores everything on every exit path. Missing: money rain / confetti, a lit spot under the row, the blooper half of the cut, the 9:16 decision (§6.6 OPEN). |
| Heist complete | FUNCTIONAL-BUT-PLAIN | Stamp + fanfare + results card. No particles. |
| Lighting / light pools | MISSING in game | "Heist Night" recipe is in `default.project.json` (good). But no level places `Lamp_Ceiling` or a light-pool disc (no `PointLight` and no pool part in `src/server/Heist`), although the kit previews (`KitPreview_CornerShop.png`) show the warm pools that make the look. §6.1: "deep indigo with warm pools of light" is half of the art direction. |

### 1.5 Camera

| Element | Class | Evidence |
|---|---|---|
| Gameplay camera (§3.5: zoom 16, min 8, max 28, FOV 70, downward bias) | MISSING | No `CameraMinZoomDistance` / `CameraMaxZoomDistance` / occlusion mode anywhere in `src` or `default.project.json` (Roblox defaults: 0.5-128, Zoom popper). |
| Wall fade (§3.5) | MISSING | Not built. |
| Run-start framing | MISSING | After each rewind the camera stays where it was. |
| Screen shake | MISSING | No shake code in the client. (The plan says none on caught; alarm, slam and zap still want a small one.) |
| Hit-stop | MISSING | §7.1 and §7.3 both specify a 66 ms freeze; none exists. |
| Caught camera / busted-cam | MISSING | |
| Transitions garage ↔ heist | MISSING | Hard cut by teleport. |
| Rewind FOV dip | FINISHED | 70 → 64 → 70 on a sine during the scrub; off under reduced motion. |
| Line-up camera | FINISHED | Eased street shot, fit width, wall pull-in, restore watchdog. |
| Planning camera | MISSING | Outside the first 10 minutes (L5 unlock is "planning camera" per §3.4; ships simple at launch). |

### 1.6 Audio

| Element | Class | Evidence |
|---|---|---|
| Coverage | FUNCTIONAL, near FINISHED | AudioDirector is wired through `Heist/Sound` everywhere: every live sim event plays its cues, music follows garage / heist / alarm / results with Crew Layers, ambience per room, UI clicks per button role, countdown ticks, count-up ticks, medal pitch ladder, captions on the rail. 46 / 49 cues have licensed ids; 100 / 100 load. |
| Missing sounds | PLACEHOLDER (silent) | GusStep, Heartbeat, RewindStinger (owner, AUDIO.md §12). Heartbeat is in the L1 countdown and on "?" ; the stinger is the rewind's signature layer. |
| Mix | FUNCTIONAL | Loudness pass to -18 LUFS families not done (owner). |
| Missing cues for new juice | MISSING | No panel open/close whoosh, no coin-fly arrival, no stamp "ink slap" separate from RunStamp, no Gus voice barks ("Hey!", "Huh?"). |

### 1.7 World feedback, juice, first frame, mobile, environment

| Element | Class | Evidence |
|---|---|---|
| L1 stuck hints (ring, beam, Mentor ghost) | FUNCTIONAL-BUT-PLAIN | All three exist (Hud.luau ~1600-1690). The ring is a breathing Neon cylinder, the beam a 0.4-wide white `Beam`, the Mentor a white box mannequin at 0.55 fade. Correct; reads as debug art. |
| "◀ YOU, 10 SEC AGO" label | FUNCTIONAL | RichText billboard with a cyan ◀; correct timing (§7.5). Plain ink pill. |
| Van chevrons | FUNCTIONAL | Pulse while you carry loot. |
| Juice: squash/stretch | MISSING | No squash anywhere (0 matches for squash/stretch in `src`). |
| Juice: hit-stop | MISSING | See camera. |
| Juice: particles | PLACEHOLDER | 4 emitters in the whole client (clone burst, laser sparks, Gus dust, none with a texture). |
| Juice: number pops | FUNCTIONAL-BUT-PLAIN | The loot count-up is good; there is no world-space "+$100", no floating gains, no "+1 clone" chip pop. 10 `TweenService:Create` calls in the whole client. |
| Loading screen / first frame | MISSING | No `ReplicatedFirst`, so the default Roblox loading screen, then the player spawns in the greybox garage behind the "The van door opens..." card. No preload of UI images (there are none yet). |
| Garage lobby (3D) | PLACEHOLDER | `src/server/Heist/Lobby.luau`: a 120 x 80 room of SmoothPlastic blocks; vans are `block(model, "Van", Vector3.new(9, 7, 14), ..., Palette.exit)` (white boxes); a steel slab "shelf". The kit `Van` mesh (`KitData` `Van = 140548604204136`) dresses heist levels but not the garage. No trophy shelf, no first-join line-up loop of 8 copies of you (§6.6). |
| Level art (L1, L2, L5) | FUNCTIONAL | Kit-dressed at boot (92 / 92 pieces), Corner Shop and Toy Shop atlases, Christmas layer. Missing the light pools (above). |
| Mobile: sizes and safe area | FINISHED | 72 px taps at 1x, 64.8 px floor, END RUN at 35 % height, GRAB away from END RUN, CoreUISafeInsets. |
| Mobile: unverified | FUNCTIONAL | Not played on a phone yet. Interact sits at `UDim2.new(1, -120, 1, -16)`: on screens whose short side is ≥ 500 px Roblox's jump button grows to ~120 px and can overlap it. PlayerList CoreGui stays on during a heist and sits over the clone strip on PC. Emoji glyphs (above). |
| Accessibility | FUNCTIONAL | Glyph + number + colour everywhere, captions on, ≤ 3 flashes/s, reduced motion from the OS. Missing the Comfort module UI. |

---

## 2. How finished, per area (first-10-minutes weighting)

| Area | % finished | Weight in the first 10 min | Why |
|---|---|---|---|
| HUD in-run (layout, scale, contextual logic) | 45 % | high | Logic and layout are launch-grade; visuals are prototype |
| Garage UI + level select | 25 % | high | One text string per tape, no backdrop, no motion |
| Clone Deck | 40 % | medium (L2) | Works; text-only cards |
| Results card | 35 % | high (after every heist) | Stamps land; no count-up, rain, trophy, input guard |
| Store | 0 % | none (FTUE has no offers) | Missing, not in slice |
| Settings / Comfort | 5 % | low (but a launch must) | OS reduced motion only |
| Player animation | 70 % | high | Roblox default; no carry pose |
| Clone animation | 50 % | very high (the product) | Walk only; statues on plates; floating loot |
| Gus animation | 15 % | medium (L5) | Box rig, sine swing; the real mesh sits unused |
| VFX overall | 45 % | very high | Rewind and plates good; bank, busted, swarm, spawn thin |
| Camera | 20 % | high | Only rewind FOV and Line-up |
| Audio | 75 % | very high | Wired end to end; 3 cues and the loudness pass missing |
| World feedback | 60 % | high | Plates, doors, lasers, chevrons good; loot dead |
| Juice (squash, hit-stop, particles, pops) | 15 % | very high | Almost none |
| Loading / first frame | 10 % | very high (the first impression) | Default screen, greybox garage, one text card |
| Mobile ergonomics | 65 % | very high (most players) | Sizes right; not device-tested; emoji |
| Environment art: levels | 65 % | high | Kit in; no light pools |
| Environment art: garage lobby | 10 % | high (minutes 0, 3, 6) | White boxes |
| **Weighted total, first 10 minutes** | **≈ 38 %** | | |

What is already premium and must not regress: the rewind timeline and its three variants, the Line-up cut and its restore logic, the audio graph and event routing, the plate/door/laser telegraphs, the HUD's scale/safe-area system, reduced-motion handling, caption rail, and the "glyph + number + hue" identity rule.

---

## 3. The vertical slice: the first 10 minutes, as they should feel

| Minute | Beat | Target feel (what this plan adds) |
|---|---|---|
| 0:00 | Join | Branded loading card (ink, tape reel spinning, "HEIST YOURSELF"), not the Roblox default; fades on the first built frame |
| 0:05 | Van doors open | Two ink door panels slide apart (0.3 s) on the L1 street, camera framed down at the shop; no text card |
| 0:10-0:45 | L1 run 1-2 | Plate clunk + cable pulse; END RUN slab breathing; rewind (exists); clone **prints in** with a scanline and walks out of you; door rises with dust; cash sparkles; GRAB pops the loot; you run with it bobbing overhead; bank = coin burst + "+$100" flies into a filling gold meter |
| 0:45-3:00 | L1 room 2, first Line-up, results | Line-up with a lit spot and gold rain; results count the haul up, stamp three medals with ink rings, trophy flies; buttons arrive last |
| 3:00 | Garage | Real kit van under a warm pool, your trophy on its shelf; tape shelf UI slides in with L2 tape glowing "▶ NEXT" |
| 3:30-6:00 | L2 Two Doors | Clone Deck cards with your hue and the clone's last action icon; second clone prints; busted clone glitches and bursts into tape ribbon |
| 6:00-10:00 | L5 Clone Party (Toy Shop) | Gus dozes in the back office (head nod, "Zz"); till alarm wakes him with a cap-popping startle; he chases with a lean and pumping arms; run 8 starts with 7 clones printing in a fan → **8 OF ME**: world dims, every copy flashes its outline in record order, camera pulls back, stamp with eight glyphs; Dawn → Line-up of 8 of you with gold rain |

---

## 4. Specs

All tuning numbers below go to `src/shared/Config.luau` (CLAUDE.md), e.g. `Config.Heist.UI`, `Config.Heist.FX`, `Config.Heist.CAMERA`. Everything here is client-side and cosmetic: no view decides an outcome, and every effect is driven by an existing replicated event or attribute (CLAUDE.md "server is authoritative"). Every effect has a reduced-motion form (fade or colour, not "nothing"; roblox-ui-builder §6) and respects the perf tier governor (`particleScale`, tier ≥ 2 drops decoration).

### 4.1 UI component kit v2 ("Tape Deck"), extending `Heist/Ui.luau`

Style: Neon-Noir, not LihFolk "Ink and Candy". We take the kit's structure (slabs with a lip, ink text strokes, one focal action, motion tokens, invisible hit pads) and the STYLE_BIBLE palette.

**Type**

| Role | Face | Design size | Text stroke (`UIStroke`, `ApplyStrokeMode.Contextual`, ink `#1C1F3B`) |
|---|---|---|---|
| Stamp / display | `Font.fromName("LuckiestGuy")` (verify it is a built-in family in the Studio font picker; fallback `FredokaOne`) | 64-88 | 6 % of size (88 → 5 px), LineJoinMode Round |
| Title | Builder Sans Heavy | 24-26 | 2 px |
| Button | Builder Sans ExtraBold, uppercase | 18-20 | none on bright slabs (ink text), 1.5 px on dark slabs (white text) |
| Numbers (timer, meter, haul) | `Font.fromName("RobotoMono", Bold)` (tabular, the timer stops jittering) | 22-30 | 2 px |
| Body / caption | Builder Sans Bold / SemiBold | 16 / 14 (never < 14: 12.6 px drawn at 0.9) | 1 px |

Two families plus a mono for numbers is the cap (vault *Text Fonts and Rich Text*). Delete every `TextStrokeTransparency` use.

**Colour tokens (STYLE_BIBLE §1, `Heist/Palette`)**

| Token | Value | Use |
|---|---|---|
| panel | `ink #1C1F3B`, transparency 0.06, `UIGradient` 90° from `inkHi #2A2D52` (top) to `ink` (bottom) | every panel body |
| panelRim | `plumHi #4D4778`, 2 px `UIStroke` Border | panel edge ("bevels catch light", STYLE_BIBLE §2) |
| panelSunken | `plumDeep #2E2A50` | tracks, wells, the tape counter window |
| header | 40 px strip, `plum #3A3560` → `plumDeep`, 4 px accent bar under it in the panel's role colour | garage, results, deck, menu |
| primary slab | your **seat hue** (solo: Clone Cyan `#3DE8FF`): face gradient hue +10 % value → hue, lip hue × 0.55 value, ink text | END RUN, READY ▶, NEXT ▶, KEEP PLAYING (the one focal action per screen) |
| loot slab | Heist Gold `#FFC21F` → `goldLo #B87A0A` 35 %, lip `#7A5106`, ink text + coin icon | GRAB, PLAY daily, party tape |
| neutral slab | `steelHi #A9B2CC` → `steel #7C86A6`, lip `steelLo #4E5675`, ink text | REPLAY, GARAGE, deck actions |
| danger slab | Alarm Red `#FF3838` → `#D92424`, lip `#8C1414`, white text + 1.5 px ink stroke + ring icon | RedoAlarm REDO, LEAVE confirm |
| locked slab | `plumHi` → `plum`, lip `plumDeep`, `steelHi` text + lock icon + reason | locked tapes |
| done chip | Holly Green `#2FBF71` + ✓ icon + word | cleared, saved |

Clone hues stay identity only: primary slabs use **your** hue, never another seat's.

**Shape**

| Item | Number |
|---|---|
| Radii | panel 18, header 12 (18 minus the 6 px inset), card 12, slab 12, chip/pill/badge full (`UDim.new(0.5, 0)`) |
| Strokes | panel rim 2, slab outline 2.5 ink, card 2 ink (selected 3 white), divider 1 `plumHi` |
| Slab anatomy | face + 5 px lip below (a sibling frame in the lip colour, same corner), outline on the outer frame; pressed: face moves down 3 px and the lip shows 2 px |
| Shadow | one ink copy of the panel offset (0, 4) at transparency 0.55 (no asset) |
| Spacing | 4 / 8 / 12 / 16 / 24 |
| Hit pads | invisible 72 px pads around any visual smaller than 72 (chips, deck cards) |

**Motion tokens** (extend `Ui.MOTION`; numbers in Config)

| Token | Value |
|---|---|
| press | child `UIScale` 0.94 + face down 3 px, 0.06 s Quad Out |
| release | Back Out 0.18 s |
| hover / gamepad select | scale 1.04, face +8 % value, 0.10 s Quad Out |
| panel enter | `Motion` UIScale 0.86 → 1, 0.24 s Back Out; ink backdrop (in `fxGui`) 1 → 0.55 in 0.18 s; children stagger 30 ms, total ≤ 0.24 s |
| panel exit | scale → 0.92, 0.12 s Quad In, then `Visible = false` only if the intent is still "closed" |
| toast / objective in | slide 8 px + fade, 0.2 s Quad Out; out 0.15 s |
| stamp land | `UIScale` 1.6 → 0.92 (0.10 s Quad In) → 1.0 (0.14 s Back Out), `Rotation` −8° → −5°, an ink ring behind it 0.8 → 1.6 scale fading over 0.3 s |
| number count-up | 0.35 s + 0.08 s per digit, cap 1.0 s, Quad Out (the existing ticks) |
| meter pop | 1.12 → 1, 0.2 s Back Out on arrival |
| error shake | 8, −8, 5, −5, 2, 0 px, 0.04 s steps + UIError |
| breathing outline ("next", claimable) | stroke transparency 0.35 ↔ 0.85, Sine InOut, 0.8 s half period; paused when hidden |
| reduced motion | no scale, rotation, shake or breathing; 0.15 s crossfades and colour changes instead |

**Icon atlas.** One 512 x 512 sheet (8 x 8 cells of 64 px), white glyph with a 6 % ink outline so `ImageColor3` tints it; built by a script in `tools/` (PIL or bpy), uploaded with `tools/kit_upload.py` like the kit images, id in Config. `ImageLabel` + `UIAspectRatioConstraint` 1. Icons: rewind ◀◀, play ▶, pause, fast-forward, lock, star, star-empty, check, cross, alarm ring, hidden, bolt, moon, van, cassette, coin, cash bag, crew, gear, back, clock, Gus head, clone silhouette, and the four seat shapes ● ■ ▲ ◆ (so identity glyphs render identically on every platform). Text keeps the glyph characters only where RichText needs them inline ("◀ ME, 20 SEC AGO").

### 4.2 Screen specs

**HUD (720 x 330 design, positions unchanged)**
- Tape counter (330 x 62): panel body; an inner `panelSunken` window (radius 8) holding "RUN 3" (Title 22, seat hue) left and the timer (mono 30) right; run bar 6 px sunken track, fill gradient white → seat hue; event markers as 14 px atlas icons. Last 10 s: each whole second the digits pop 1.12 → 1 (0.12 s Back Out) with the existing tick, replacing the sine wobble. Last 5 s: Alarm Red + ring icon + panel rim red, pulsing at 1 Hz.
- Loot meter (230 x 44): coin icon 28 px + mono 22 "$400 / $1,000" + a 4 px gold fill bar under the text that fills with the count-up; meter pops when a flying "+$100" arrives.
- Clone strip: 30 px round chips (seat hue at 0.2 fill, 2 px hue stroke, shape icon + digit). A new run's chips enter scale 0 → 1, 0.2 s Back Out, 60 ms apart (the tape-print rhythm). Busted: chip greys, ✕ icon, one error shake.
- END RUN 96 x 72 primary slab: ◀◀ icon 28 px over "END RUN" 14. The 1.5 s lock is a ring sprite around the icon with a `UIGradient` transparency sweep (0 → 360° over the lock). L1 pulse: breathing outline + face brightness (not a hard 3 Hz white blink).
- Interact 128 x 72 loot slab, coin icon + "GRAB $100"; enters 0.7 → 1 (0.16 s Back Out). Keep it ≥ 12 px from the touch jump button, measured at runtime from `PlayerGui.TouchGui.TouchControlFrame.JumpButton.AbsolutePosition`.
- Objective: an ink pill (0.35) behind the line; slides in on change.
- Stamps: §4.1 stamp land on an ink plate (radius 16, 4 px stroke in the stamp colour). Colour by meaning: RUN n white; BUSTED / ZAPPED / ALARM Alarm Red + ring icon; HEIST COMPLETE / GETAWAY / ★ HAUL Heist Gold; DAWN Torch Amber + moon; 8 OF ME seat hue with a row of eight shape icons under it.

**Garage tape shelf** (same 700 x 326 slot)
- Header "THE VAN" + crew headshots (`GetUserThumbnailAsync`, 32 px circles with seat-hue strokes).
- Tape card 146 x 88 = a cassette: label band in the location colour (Corner Shop pine `#9A7755`, Toy Shop navy `#1F3F5F`, Bank plum), number badge, name (Title 16), tag line (caption 13), three star stickers (earned = gold, tilted ±8°, a 0.2 s pop the first time they show), locked = ink veil 0.35 + lock icon + reason line. Party tape: gold rim + "PARTY" ribbon corner.
- The next tape to play gets a breathing outline and a "▶ NEXT" chip; it is the default gamepad selection.
- Behind the panel: the 3D garage, with `DepthOfFieldEffect` (menus only, §6.3).

**Results v2 timeline** (input to buttons only from 2.4 s, vault *Reward Moments*)

| t (s) | Beat |
|---|---|
| 0.00 | panel enter; title stamp (HEIST COMPLETE gold / DAWN amber) |
| 0.25 | haul counts up (existing CountTick / CountDone) to "$1,000" |
| 0.9 / 1.15 / 1.4 | HAUL / CREW / CLEAN stamps land with ink rings (existing pitch ladder) |
| 1.6 | "3 clones · 4 runs · 1:52" types in at 40 chars/s |
| 1.9 | new trophy icon flies (bezier, 0.45 s Quad In) to a van icon in the header; NEW TAPE UNLOCKED chip pops |
| 0.2-1.6 | money rain if complete: ≤ 120 (touch 60) cash-bill particles |
| 2.1 | buttons slide up 12 px + fade; active at 2.4 s; NEXT ▶ is the primary slab |

**❚❚ menu** gains a Comfort tab (§7.4): reduced motion (Follow / On / Off), shake 0-100 %, flashes (3/s cap on / off), FOV kicks on / off, clone opacity 50-100 %, Music / SFX / UI / Alerts volume (AudioDirector `setBusVolume`), captions. Values persist once Schema v2 adds them (AUDIO.md §10); per session until then.

### 4.3 Animation list

**Gus** (switch `Rigs.buildGus` to clone the kit `Gus` model from `ServerStorage/Kit` via a replicated template, like the avatar templates; pose each of the 18 parts with `part:PivotTo(parent:GetPivot() * C0 * pose)` per STYLE_BIBLE §12; clips are code data in a pure `GusClips` module; 0.15 s per-joint slerp between clips; Santa hat swaps on `HatAttach`).

| Clip | Trigger (existing data) | Keys and timing |
|---|---|---|
| Patrol walk | `Patrol`, speed > 1 | 1.0 s cycle at 8 studs/s, phase by distance (stride 2.6 studs); hip bob 0.12 studs at 2x; legs ±28°, arms ±18° opposite; torch arm stays forward ±6°; torso counter-yaw 4° |
| Idle | speed < 1 on patrol | 2.4 s loop: chest rise 0.04 studs, head yaw ±6°, torch sway 3° |
| Suspicious "?" | `Stage >= 2` or `Suspicious` | 0.35 s ease into a 8° forward lean, head tilt 12°, torch raised 25°; head sweeps ±20° at 0.5 Hz while held |
| Double-take | stage 1 → 2 on a target | head snaps to the focus in 0.12 s, overshoots 10° (0.08 s), body follows 0.15 s later |
| Alert "!" | `bang` (Caught / Busted) | 0.18 s: root up 0.6 studs, arms out 40°, **cap pops 0.3 studs and lands 0.1 s later**, land with knees 15° (0.1 s) |
| Chase run | `Chase` | 0.6 s cycle, 14° lean, arms ±45°, stride 3.5, torch swinging; existing dust every `GUS_DUST_SECONDS` |
| Catch | `Caught` on a live player | 0.25 s lunge (25° lean, arm toward the target), 0.4 s hold, then a point |
| Huh / lost | `Huh` | 0.6 s shrug (shoulders +0.2, palms up 30°), head shake ±15° twice |
| Doze (L5 back office) | L5, `Patrol` with no route speed, alarm off | lean on the wall 10°, head nod on a 4 s cycle, "Zz" billboard; on AlarmOn: 0.25 s startle (cap pop) then Chase |

Bubble: "?" / "!" labels pop 0 → 1.3 → 1 (0.18 s Back Out); "!" adds three short ink motion lines (atlas sprite) for 0.3 s.

**Clones (avatar rigs)**

| Clip | Rule |
|---|---|
| Walk | existing 507777826 |
| Run | default R15 run 507767714 above 14 studs/s (verify it loads, like the walk; MASTERPLAN §6.7) |
| Idle | default R15 idle 507766666 at weight 0.6 when speed < 1 (verify), so a plate clone breathes |
| Jump / fall | `Sampler.velocity` y > 4 → jump 507765000; y < −4 → fall 507767968 (verify ids) |
| Carry | while the clone carries loot: both shoulders raised to hold it over the head (avatar: shoulder joint `Transform` written after the Animator step; mannequin: limb pose). Loot sits between the hands, not 2.6 studs over the root |
| Stuck | head shake ±12°, two cycles, then hold; "..." bubble |
| Shrug | the Gus shrug keys, scaled to R15 |
| Busted | 0.1 s hold, then the VFX in §4.4 |
| Line-up | existing cheer + hop |

The mannequin placeholder becomes the MASTERPLAN §6.5 option C hologram mannequin (one chamfered kit mesh set, owner hue), so even the fallback looks authored.

**Player**: Roblox default plus the same carry pose (local only) and the loot grab squash.

**Loot props** (`MeshPart.Size` is real squash for single-mesh props, vault *Squash Stretch*): grab: Size x1.25 → 1 (0.12 s Back Out) + 8 sparkles; carry: bob 0.15 studs at 2 Hz, yaw lags the carrier by 0.15 s, tilt with acceleration up to 10°; drop: falls to the floor with one 0.4-stud bounce (0.25 s) + existing DropThud; bank: shrinks into the van in 0.18 s, then §4.4 coin burst.

### 4.4 VFX list (particle settings)

Textures: 6 white/greyscale PNGs built by script and uploaded with `kit_upload.py` (no Toolbox, STYLE_BIBLE §9): `fx_sparkle4` (4-point star), `fx_coin` (2 x 2 flipbook of a spinning coin, ink outline), `fx_ribbon` (tape strip, dark core, light edge), `fx_square`, `fx_smoke` (lighter top, darker core, vault lihfolk-vfx "Smoke"), `fx_scan` (horizontal scanline gradient). Value rule for all: dark ink, hue body, thin white core (§7.3). Live cap 360 on touch, `particleScale` applied to every count.

| Effect | Trigger | Settings |
|---|---|---|
| Loot sparkle | loot `Home` | `fx_sparkle4`, Color gold → goldHi, Size 0.5 → 0, Lifetime 0.4-0.7, Rate 3 (touch 2, tier ≥ 2: 1), Speed 0.3, Spread 180, LightEmission 1, Rotation 0-360, Box shape = loot size |
| Grab burst | Grab event | `fx_sparkle4`, Emit 8, Speed 6-10, Drag 6, Lifetime 0.25-0.4, Size 0.35 → 0 |
| Bank coins | Bank event at the van | `fx_coin` flipbook Grid2x2 Loop 12 fps, Emit 24 (touch 16), cone up (SpreadAngle 35), Speed 12-18, Acceleration (0, −60, 0), Lifetime 0.6-0.9, Size 0.6, RotSpeed ±180; plus a world "+$100" billboard pop (clone banks: "◆2 +$100" in its hue), which then becomes a screen label flying on a bezier to the loot meter (0.45 s Quad In, `WorldToViewportPoint`); the count-up starts on arrival |
| Tape print (clone spawn) | per clone at `visibleAt` | existing floor ring; **plus** a Neon scan slab (3 x 0.08 x 1.6 studs, hue, transparency 0.2 → 1) rising feet → head in 0.18 s while the rig's parts reveal bottom-up (`LocalTransparencyModifier` by part height, 20 ms steps); `fx_square` dust Emit 8, Size 0.15, Speed 2, Lifetime 0.3, hue. Whole batch ≤ 0.4 s |
| Clone busted | Busted event | 0.1 s hold; glitch: the rig offsets ±0.25 studs on its right axis on alternating frames, ≤ 3 changes/s (BLINK_HZ_MAX); then `fx_ribbon` Emit 20 (touch 12), Speed 5-9, Lifetime 0.6-1.0, RotSpeed ±360, Acceleration (0, −20, 0), Drag 3, Size 0.4, Squash 1 → −1 (curl), Color ink → hue; ≤ 30 total (§6.5) |
| Clone zapped | Zap event | 1-frame white flash of the rig (frame-counted, vault *Hit-Stop* §1); `fx_smoke` Emit 10, Color ink → steelLo, Size 0.8 → 1.6, Lifetime 0.5; 6 white-hot `fx_square` sparks |
| Plate press | PlateDown | existing sink/hue; **plus** a `Beam` along each cable, `fx_scan` texture, TextureSpeed 4, TextureLength 2, presser hue, LightEmission 1, for 0.4 s; a flat ring Emit 1 (Size 1 → 5, 0.25 s) |
| Door open | DoorOpen | `fx_smoke` sill dust Emit 6, Size 0.6 → 1.2, Lifetime 0.4, steelHi; 0.04-stud settle bump at the end of travel |
| Laser off | LaserOff | existing 14 sparks; beam collapses to its centre over 0.12 s instead of hiding |
| Gus "!" | bang | 3 ink motion lines + the cone sweeps Alarm Red from apex outward in 0.2 s |
| Alarm on | AlarmOn | existing beacons + edge pulse; the HUD alarm pill enters with one error shake |
| 8 OF ME | Swarm event, your seat | world dim 15 % for 0.6 s (reuse `EH_Dim`); each own clone's owner-group `Highlight` `FillTransparency` 1 → 0.6 → 1 over 0.4 s, 40 ms apart in record order (one Highlight per owner group, so animate the group once and add a per-clone Neon flash on the badge instead if per-clone timing is required); arpeggio replay; FOV kick +4° over 0.3 s; the 8-icon stamp |
| Line-up / heist complete | Over | gold `fx_coin` + cash-bill rain, ≤ 120 (touch 60), from a part 12 studs above the row, Speed 2-4, Acceleration (0, −8, 0), Lifetime 2.5, RotSpeed ±120; a Warm Marble transparent disc (0.75) under the row as the "spot" |
| Rewind | play() | 66 ms freeze at start (§7.1); owner-hue `Beam` trails of each clone's last-run path sampled every 0.5 s, drawn during the scrub and wiped with it; `fx_scan` texture on the VHS bands; a 2 px cyan/magenta offset copy of "◀◀" |

### 4.5 Camera rules (new `Heist/CameraDirector`, numbers in `Config.Heist.CAMERA`)

1. Gameplay: `CameraMinZoomDistance 8`, `CameraMaxZoomDistance 28`, start at 16 (§3.5), FOV 70, never roll. Try `DevCameraOcclusionMode = Invisicam` first for the wall fade (zero code); build the 10 Hz raycast fade to 0.7 only if Invisicam looks wrong on the kit walls.
2. Run start (after the rewind stamp) and heist start: ease the camera behind the player looking at the room's objective with a 30-35° downward pitch over 0.4 s (cut under reduced motion). Never move the camera during a run otherwise.
3. Shake: one trauma module (vault *Hit-Stop and Screen Shake Tuning*): offset = trauma² x max, max rotation 1.2°, max offset 0.15 studs, noise frequency ≤ 0.4 x smoothed fps, decay 1.6 / s, scaled by the Comfort slider, off under reduced motion. Values: AlarmOn 0.35; Gus "!" within 20 studs of you 0.25; you are zapped 0.3; vault door slam 0.15; caught 0 (§7.3 says no shake); bank 0 (use the pop).
4. Hit-stop (local view only: freeze clone sampling time and `AdjustSpeed(0)` on local animators; never the server clock): caught 66 ms, zapped 50 ms, clone busted within 20 studs 40 ms. Nothing under 66 ms carries meaning on a 30 fps phone (vault §1).
5. Caught: 66 ms freeze → Scriptable ease toward Gus framing Gus and you (0.35 s Quad Out, FOV 60) → 2.0 s busted-cam hold → spectate the crew or the next rewind. Reduced motion: cut, no ease.
6. Transitions: garage ↔ heist is a **van-door wipe**: two ink panels (fxGui) slide in from the sides in 0.25 s, hold while the teleport and level bind happen, slide out in 0.3 s. This also replaces "The van door opens..." for a new account.
7. Line-up keeps its camera; decide the 9:16 "clip mode" (§6.6 OPEN) before marketing capture.
8. FOV kicks ≤ ±6°, off with the FOV-kick toggle.

### 4.6 First frame and loading

- `ReplicatedFirst/Loading.client.luau`: `RemoveDefaultLoadingScreen()`, an ink `#1C1F3B` screen with "HEIST YOURSELF" (display face, Getaway White, 6 % ink stroke), a cassette reel icon turning once per 1.2 s (static under reduced motion), and one tip line. `ContentProvider:PreloadAsync` the icon atlas, the six FX textures and `Config.Audio.PRELOAD`. Fade out (0.3 s) when HeistClient reports its first built frame (garage or L1), at most 12 s.
- A new account goes loading card → van-door wipe → L1, never a text card over the greybox garage.

### 4.7 Garage lobby (server `Heist/Lobby`)

Dress it with the kit like a level (KitService is loaded at boot; greybox stays the fallback): kit `Van` per bay instead of the white box, `Wall_8x12` walls in the Bank atlas, `Floor_8x8`, a `Lamp_Ceiling` with a Warm Marble pool disc over each bay, a physical tape shelf (cassette meshes are not in the kit: add one small `Tape` kit piece) and a trophy shelf whose slots fill from `Progress` medals. On first join, a looping Line-up of 8 copies of the player's own avatar beside their van (§6.6), built by the existing LineupDirector figures from Mentor-tape paths. Light pools in L1, L2 and L5 the same way: one lamp + one pool disc per room, loot inside a pool on a dark display (STYLE_BIBLE §1.3 display rule).

### 4.8 Audio additions (cue rules unchanged, ids from the licensed partners only)

UIOpen / UIClose (soft whoosh, UI bus), CoinArrive (short coin chink at the meter), StampSlap (ink stamp on paper, separate from RunStamp so RUN n and BUSTED differ), GusBark "Hey!" / "Huh?" (APM / ProSoundEffects vocal one-shots if licensed; else a whistle). Plus the owner's three missing cues (GusStep, Heartbeat, RewindStinger) and the loudness pass (AUDIO.md §12).

---

## 5. Prioritized plan: top 20 (first 10 minutes first)

Effort: S ≤ 0.5 day, M 1-2 days, L 3-5 days of one Claude agent including Lune/engine checks; owner review is the daily 15-minute screenshot slot (MASTERPLAN §6.7). Four tracks can run in parallel (UI, VFX/juice, animation, world/camera); total ≈ 33 agent-days, ≈ 9-10 calendar days on four tracks, which fits before the Nov 30 gate.

| # | Item | Area | Effort | Why this rank |
|---|---|---|---|---|
| 1 | **UI kit v2** in `Ui.luau`: tokens, `Ui.panel` / `Ui.slab(role)` / `Ui.chip` / `Ui.text(role)` with `UIStroke` text, gradients, lip, shadow, hit pads; swap every call site | UI | M (2 d) | Every screen inherits it; the single biggest "prototype" tell |
| 2 | **Icon atlas** (27 icons, script-built, uploaded) and removal of every emoji / unicode icon | UI | M (1.5 d) | Fixes cross-platform glyph mismatch; required by 1 |
| 3 | **Motion pass**: panel enter/exit with backdrop, toast/objective slides, the stamp component (ink plate, tilt, land squash, ring, colour by meaning) | UI | M (1.5 d) | Turns snapping panels into a product; stamps are the clip moments |
| 4 | **Bank moment**: coin burst, world "+$100", fly-to-meter, meter bar, count-up on arrival, CoinArrive cue | Juice | M (1.5 d) | The most repeated reward; first payoff at 0:40 |
| 5 | **Loot life**: sparkle at rest, grab squash + burst, carry bob/lag/tilt held in the hands, drop bounce, bank shrink | Juice / anim | M (1 d) | Gold = sparkle is a colour-blind rule; loot is dead today |
| 6 | **Tape-print spawn**: scan slab, bottom-up reveal, dust | VFX | M (1 d) | "The clone walks out of you" is the hook at 0:15 |
| 7 | **HUD restyle**: tape counter window, mono timer with second pops, loot bar, clone chips with enter pop, END RUN slab with radial lock, Interact pop | UI | M (2 d) | On screen for 90 % of the session |
| 8 | **Camera baseline**: zoom 8/16/28, Invisicam, run-start framing; trauma shake + local hit-stop module with Comfort scale | Camera | M (1.5 d) | Defaults (zoom to 128, no framing) undercut every room |
| 9 | **First frame**: ReplicatedFirst loading card, preloads, van-door wipe for garage ↔ heist and the new-account start | Flow | M (1.5 d) | The first 5 seconds; replaces the text card |
| 10 | **Light pools** in L1, L2, L5 (lamp + Warm Marble disc per room, loot in a pool) | World | S (1 d) | Half of the art direction; previews already show it |
| 11 | **Gus on the kit mesh + pose player** with the 9 clips and bubble pops | Anim | L (4 d) | The mesh exists; box Gus is the most visible placeholder in L5 |
| 12 | **Caught / BUSTED sequence**: 66 ms freeze, red vignette, camera ease to Gus, busted-cam, StampSlap | Juice / camera | M (1.5 d) | Failure must read and feel fair (vault *Pressure*: death cause in-world) |
| 13 | **Clone busted / zapped VFX**: glitch, tape-ribbon, soot, frame-counted flash | VFX | M (1 d) | Busted clones are the blooper clips (§6.6) |
| 14 | **"8 OF ME" hero moment**: dim, outline cascade, FOV kick, 8-icon stamp | VFX | M (1 d) | The T1 thumbnail and swarm KPI moment at ~minute 8 |
| 15 | **Results v2 + Line-up rain**: timeline in §4.2, money rain, trophy fly, 2.4 s input guard, lit spot under the row | UI / VFX | M (2 d) | End of every heist; the Line-up is already strong, finish it |
| 16 | **Garage tape shelf UI**: cassette cards, stickers, NEXT breathing, crew headshots, DoF backdrop | UI | M (2 d) | Seen at minutes 3 and 6; today it is one string per button |
| 17 | **Garage lobby 3D**: kit van, walls, lamps, trophy shelf, first-join 8-copy line-up loop | World | L (3 d) | White boxes are the "home" of the game |
| 18 | **Clone animation completeness**: run, idle (plate clones breathe), jump/fall, carry, stuck, shrug; hologram mannequin fallback | Anim | M (1.5 d) | Clones are the product; statues and floating loot look broken |
| 19 | **Rewind finishing**: 66 ms freeze, owner-hue path beams, scanline bands, chromatic ◀◀ | VFX | M (1 d) | Takes the signature moment from 85 % to done |
| 20 | **Comfort sheet + device pass**: Comfort tab in the ❚❚ menu, PlayerList off in heists, jump-button clearance, 7 viewports + a 30 fps phone, glyph check | UI / mobile | M (2 d) | Launch accessibility (§7.4) and the phone majority |

Below the line (after the slice): Clone Deck cards with a mini path and last-action icon; Alarm Run escalation (siren light sweep on walls through emissive strips); Gus barks; plate cable pulse and door dust (cheap, can ride with 6 or 10); store UI (post-FTUE only, lihfolk-ui shop archetype rules re-skinned to §4.1); planning camera; Save Clip / Heist Reel.

## 6. Exit criteria for "premium first 10 minutes"

- No `TextStrokeTransparency`, no emoji, no `Visible = true` without an enter token, no untextured `ParticleEmitter` in `src/client/Heist` (a grep check in CI, like `pure_check`).
- Every input answers within 100 ms with a pop and a sound (already true for buttons; extend to GRAB, plate, END RUN lock-out taps).
- Every reward has motion, a number and a payoff pop (vault *Game Feel and Juice*): bank, medal, unlock, swarm, heist complete.
- 7 viewports + notched phone pass (roblox-ui-builder §7); one real phone at 30 fps: no effect below 66 ms carries meaning, no frame spike > 33 ms on a bank or swarm (governor tier respected).
- Reduced motion on: every moment above still reads through fades, colour and sound.
- Owner screenshot slot signs off: loading card, garage, L1 bank, L5 8 OF ME, results, Gus chase.
- Blind UI review ≥ 8.5 on `quality-score/rubrics/ui.md` for the HUD, garage and results; VFX review on `rubrics/vfx.md` for bank, tape print, busted and 8 OF ME.
