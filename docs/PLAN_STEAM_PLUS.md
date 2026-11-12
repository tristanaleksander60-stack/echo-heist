# PLAN: "Steam quality++": from systems-complete to premium (v2, for owner approval)

Written 2026-11-12, after the owner played version 23 and said: "it looks like an MVP, 10 % done; I can't see my previous selves".
**Status: DRAFT, awaiting owner approval. No code changes until it is approved.**

This plan does not replace MASTERPLAN.md: the concept, pillars, levels, economy and architecture stay. It replaces the parts of MASTERPLAN §6-7 and §10 that turned out too thin, and it adds a quality system so "done" means "premium", not "wired".

Inputs (all in the repo):

| Input | What it gives |
|---|---|
| Owner screenshots of v23 (Nov 12) | The ground truth: invisible clones, near-black levels, void, "▯▯" glyphs, jargon, clone strip under the player list, "Couldn't save this one" in Studio |
| `docs/audit/WALKTHROUGH.md` | 35 comprehension issues ranked P0-P2, traced through the code, and a "wrong thing" matrix |
| `docs/audit/POLISH.md` | Inventory of every surface with % done. The first 10 minutes are about **38 %** finished; top 20 polish items, about 33 agent-days |
| `docs/audit/LEVELS.md` + `docs/audit/levels/*.png` | Blender renders from the player camera: what each level reads like |
| `docs/research/premium.md` | Teardown of 10 Steam and 8 Roblox games, 12 shared patterns, **60 testable criteria** |
| `docs/research/roblox_quality.md` | Why it is black (numbers), lighting recipes, killing the void, UI, animation and VFX techniques, a verification ladder |
| MASTERPLAN, STYLE_BIBLE, VIRAL_PLAYBOOK, LihFolk vault | Pillars, palette, clip formats, Roblox facts |

---

## 0. The honest verdict

**What is really done (keep it):**
- the deterministic sim, recording and replay;
- server authority, instances, data, receipts and analytics;
- the audio wiring (46 of 49 cues);
- the Rewind sequence (about 85 %);
- the Crew Line-up;
- HUD scaling and safe areas;
- captions and reduced motion;
- 6 levels, 12 daily vaults, a 50-piece art kit, Gus's mesh (uploaded, unused);
- 800+ automated checks.

**What the owner sees** is none of that. They see:
1. the core fantasy, "your past selves are your crew", is **invisible**;
2. the world is **black and floats in a void**;
3. the UI is **default Roblox with text symbols**;
4. after L1, the game **stops explaining itself**.

The game is systems-complete and roughly 10-40 % finished in presentation, depending on the surface. The owner's "10 %" is fair for what shows on screen.

**Why it happened (so it doesn't happen again):**
- **I verified logic, not pixels.** Every test asserts state; none asserts that a clone *appears on screen*, that a floor *can be seen*, or that a glyph *renders*.
- **The art pipeline stopped at the kit.** The kit was rendered and approved in Blender, under Blender lights. The game uses different lights (none). Nobody compared the two.
- **"Done" meant "wired".** There was no written bar for "finished" per surface.

This plan fixes all three:
- a **verification ladder that ends in real Studio pixels** (§8);
- a **written premium bar** with 60 criteria, gated per phase (§2);
- **specs per moment** that say exactly what finished looks like (§5).

---

## 1. Diagnosis of the owner's screenshots

| # | What the owner saw | Root cause (confirmed or suspected) | Fix (phase 1 unless noted) |
|---|---|---|---|
| S1 | **No clones visible** | **Not yet pinned.** The code path (server `Avatars` builds a template → client `EchoView` clones it, falls back to a mannequin) reads as correct, and the engine tests only check state, never rendering. Suspects, in test order: (a) the clone rig is placed somewhere other than where the player recorded (origin or `rootHeight` mismatch in kit-built levels); (b) the avatar template from `CreateHumanoidModelFromDescriptionAsync` arrives in Studio with transparent or detached parts, or no Motor6Ds after `Avatars.strip`; (c) the fade logic leaves `fade = 1` (`visibleAt`, near-camera fade, `goneShown`); (d) the recording reaches the client after `setRun`, so the clone is skipped for the whole run (`if not rec then continue`) | A **client engine test** that plays L1 twice and asserts, per clone: a rig exists in `workspace.HeistClones`, ≥ 10 visible parts with `Transparency + LocalTransparencyModifier < 0.5`, its root within 2 studs of the server's actor position, and on screen from the default camera (`WorldToViewportPoint`). Then fix the real cause. **Also, whatever the cause:** a rig that fails any check is swapped for the hologram mannequin at once, so "never invisible" is a property, not a hope. A late recording re-binds the clone instead of skipping it |
| S2 | **Near-black levels** | No `Light` objects, no `Sky`, moon `Brightness 0.5`, Ambient (55,55,95): floors render at about 1 % screen luminance, walls about 3 % (roblox_quality §0). Floors use `ink` albedo, which is black under any night light | Lighting recipe A "Moonlit Diorama", local light pools per room, floors moved to a new `floor` swatch. On-screen luminance targets: floors ≥ 12 %, walls 15-30 %, hero props ≥ 35 % (§4.1) |
| S3 | **Void around every level and the garage** | The levels sit at instance offsets with nothing around them; default night sky | Backdrop layers: ground plane fading into haze, a near ring of kit façades, two skyline rings with lit windows, and a custom city skybox (§4.1) |
| S4 | **"▯▯" boxes and odd symbols** | Text-character icons (❚❚, ◐, ⏩, ⚡) missing from Builder Sans; some render as colour emoji | **No icon is a text character, ever.** One icon sheet (27 icons) rendered in Blender, uploaded as images. A CI grep fails on any non-ASCII symbol in a UI string except "◀◀" in display text (§4.2) |
| S5 | Jargon: "REDO •2 + LATER", "Plate B", "tape", "SHUTTER", "Goal banked!" | Written by a developer, not for an 8-year-old | Words pass (§6.3): a glossary of 12 player words, ≤ 30 words per level intro, each line read aloud to a kid |
| S6 | "Couldn't save this one" in Studio | DataStores in Studio are offline, so the message is true but alarming | In Studio only: a small "Studio test: progress not saved" chip. Live: the message keeps a retry, never shown for an offline Studio |
| S7 | **Unexplained stars** | HAUL / CREW / CLEAN are never introduced, yet they gate L6 | Results card teaches each star the first time it can be earned, with an icon and a 4-word reason ("Used 2 clones or fewer") (§5, results) |
| S8 | Clone strip under the Roblox player list | Top-right collision with CoreGui | Player list hidden during heists (`SetCoreGuiEnabled(PlayerList, false)`), shown in the garage. Clone strip moved to top centre under the timer |
| S9 | "MVP feel" overall | No motion, no light, no acting, flat panels, no transitions (POLISH §0) | Phases 2-4 |

---

## 2. The quality bar ("Steam quality++", written down)

Adopted in full: **the 60 criteria in `docs/research/premium.md` §4** (groups A-I: readability, lighting and VFX, animation, UI, audio, juice, onboarding, camera, robustness). They become a tracked checklist, `docs/QUALITY_BAR.md`, with a status per criterion and the rung of evidence that proves it (§8).

On top of them, **six non-negotiables** that cover what the owner hit:

1. **Never invisible.** Every actor (player, clone, Gus, loot) is visible on screen from the default camera in the engine test, at every quality level. A rig that fails falls back; it never silently disappears.
2. **Never dark by accident.** Measured on a real Studio frame (the PhotoBooth, §8), every gameplay surface meets the luminance targets in §4.1, and the grading script passes.
3. **Never a text glyph as an icon. Never default Roblox UI.** No grey, no Gotham, no `TextStrokeTransparency` outline, no emoji.
4. **Never unexplained.** Every verb, object and score is introduced by showing it before it matters. Every failure says why and what to try, in one line, within 1 s.
5. **Never a pop.** Every panel, state change and screen transition has authored motion (enter ≤ 0.3 s, exit ≤ 0.18 s), with a reduced-motion version.
6. **Every interactable answers on three channels**: a visual state change plus an effect, a sound, and motion. Phones also get haptics on plate, grab and bank.

**Gates per phase** (details in §9):
- **Phase 1:** non-negotiables 1-3 plus S1-S8.
- **Phase 3 (vertical slice):** all of groups A, F, G and H4, plus non-negotiables 1-6 on the first 10 minutes.
- **Launch go/no-go:** ≥ 54 of the 60 criteria, all six non-negotiables on every level, and the kid-test bars (§8.5).

---

## 3. Identity: what makes this look like *ours* in one second

Premium games have a signature you can read in a single frame (premium.md §3: Monaco's colour plan, Hitman GO's board, Superhot's red/white). Ours is decided, and everything below serves it.

**"Neon-Noir Diorama, recorded on tape."**
- **The world** is a miniature night diorama:
  - a city block on a dark table;
  - warm pools of light on cool walls;
  - one storytelling prop per room;
  - a hazy skyline behind;
  - nothing in the world glows except signals.
- **Your clones** are the only saturated, glowing things in that world: holographic **prints of your own avatar**, each with your crew colour, a soft outline, a floor glow and a scanline band.
- **Time is a VHS tape.** The UI is the tape deck:
  - the run timer is a tape counter;
  - the rewind is a real rewind;
  - the Clone Deck holds cassettes;
  - the level select is a shelf of tapes;
  - the results are a job sheet stamped by hand.
  This replaces the generic dark panels.
- **Gus** is the funny, readable antagonist. He has a torch, a donut and a moustache, and every state has a pose you can read at 48 px.

The rule from now on: if a new element would look the same in any other Roblox game, it isn't finished.

---

## 4. Workstreams (what gets built; the specs live in the source docs, named per item)

Effort: **S** ≤ ½ day, **M** 1-2 days, **L** 3-5 days, in agent-days. Tracks run in parallel; the critical path is in §9.

### 4.1 World: light, materials, backdrop, garage (track W)

| Item | Spec | Effort |
|---|---|---|
| W1 Lighting recipe A "Moonlit Diorama" | roblox_quality §1.2: ClockTime 15 sun recoloured as moonlight (a real key light at every quality level), city `Sky`, OutdoorAmbient about (115,110,165), Ambient about (95,90,140), EV 0.3, Atmosphere 0.28, Bloom threshold 1.15. Values in `default.project.json`, asserted by `place_check` | S |
| W2 Light pools as kit attachments | Each lamp, sign, till and vault in the kit carries a `PointLight`/`SpotLight` plus an additive Beam floor pool; 6-9 lights per room, ≤ 2 shadowed; `Config.Lighting`; a client `LightDirector` drops shadows and pools by performance tier | M |
| W3 Floor and wall albedo lift | A new `floor` swatch near `#3A365C`, warm rugs inside pools, contact-shadow atlas cells; STYLE_BIBLE §2 changed to **on-screen** luminance bands | S |
| W4 Backdrop | roblox_quality §2: a hazed ground plane, a near ring of reused kit façades, skyline rings at 300 and 600 studs with emissive windows, a Blender-rendered night-city cubemap with one landmark (a clock tower), slow searchlights. Client-built, about 30 draw calls and 25k triangles | M |
| W5 Level dressing pass | Per level (`LEVELS.md` findings): one focal light pool and one storytelling prop per room; plates, doors and loot readable from the spawn camera; Christmas dressing on top | L |
| W6 The garage, rebuilt | Not white blocks: a warm, lit **garage interior** from the kit. 8 van bays; your van glows in your crew colour; your trophy shelf; a TV on the wall playing the daily vault's "best haul"; a tape shelf at the van for level select; a jukebox. On first join, a Line-up of 8 copies of you (MASTERPLAN §6.6) | L |
| W7 Loading and transitions | A branded loading card (tape reel spinning, logo) that replaces the default; a van-door wipe between garage and heist; no cut to black anywhere | M |

### 4.2 UI: the "Tape Deck" kit (track U)

| Item | Spec | Effort |
|---|---|---|
| U1 UI kit v2 | POLISH §4.1 plus roblox_quality §3, made into one decision:<br>• **Fonts:** Builder Sans (UI) + **Oswald** (stamps and titles: caper-film posters); the timer uses fixed-width digit slots.<br>• **Theme:** one radius, a 2 px ink stroke, one shadow, script-generated 9-slice panels with a lip and an inner highlight, raised buttons with a press state.<br>• **Motion:** tokens from premium D4 and the vault; no raw `TweenInfo` outside the motion module.<br>• CI greps enforce it | M |
| U2 Icon sheet | 27 icons on one grid (24 px, 2.5 px stroke, rounded caps), rendered in Blender as 4×4 sheets at 2×, uploaded with Open Cloud. Covers: rewind, clone, plate, door, laser, loot, bank, Gus, star ×3, pause/menu, fast-forward, hide, alarm, dawn, delete, undo, invite, settings, close, lock, check, cross, crown, camera, gift, coin | M |
| U3 HUD restyle | POLISH #7 plus the phone fix from WALKTHROUGH #15:<br>• **top row:** tape counter (timer) in the centre, clone chips under it, loot meter left;<br>• **REWIND:** big at lower right, with a ring lock and a breathing pulse when it is the right move;<br>• **GRAB:** left of jump;<br>• fits 720×330 with ≥ 8 px gaps (currently it overflows by 33-43 px) | M |
| U4 Clone Deck as cassettes | Each clone is a cassette card in your crew colour, showing its last action as an icon (pressed plate A, carried cash, got busted). DELETE and REDO are icons with words; a full deck says so and offers "Start over" (WALKTHROUGH P0-3) | M |
| U5 Results as a "job sheet" | premium §6.6: the haul counts up; one line per goal gets a pencil strike-through; three medal stamps land with ink rings, each with its reason the first time; the trophy flies to the van; the buttons come last with a 0.3 s guard | M |
| U6 Tape shelf (level select) | POLISH #16: tapes on a shelf with hand-drawn labels, medal stickers, and a "▶ NEXT" tape that glows | M |
| U7 Settings and comfort | Music, SFX, shake, reduced motion, captions, colour-blind glyphs; reached from the menu chip | S |

### 4.3 Characters and animation (track A)

| Item | Spec | Effort |
|---|---|---|
| A1 Clones always visible (phase 1) | §1 S1: engine test, root cause, mannequin fallback, late-recording re-bind | M |
| A2 The hologram clone look | roblox_quality §5.1 on top of MASTERPLAN §6.5 look B:<br>• a crew-colour `Highlight` per owner;<br>• a floor glow disc;<br>• a scanline band;<br>• a 0.5 s trail;<br>• older runs drift toward violet.<br>A clone builds up from the feet over 0.35 s when it spawns ("tape print") and glitches into tape ribbon when busted | M |
| A3 Clones act, not slide | Clones play the owner's own animation pack (idle, walk, run, jump, fall), driven by a state derived from the recording. They also get:<br>• a **plate stance** (planted feet, weight shift, one glance back at you);<br>• a **carry pose** (loot held in both hands, bobbing; not floating 2.6 studs up);<br>• **stuck** (taps a wall, shrugs);<br>• **busted** (hands up, glitch).<br>Code-authored KeyframeSequences uploaded as Animation assets (roblox_quality §4.1; one spike first), with the Lua pose player as fallback | L |
| A4 Gus on his real mesh | The uploaded 18-part mesh replaces the grey boxes. Ten beats readable at 48 px:<br>• doze (Zz, head nod);<br>• wake startle;<br>• patrol (torch sway, key-ring jingle);<br>• "?" double-take (head turns before body);<br>• "!" point;<br>• chase (lean, pumping arms);<br>• catch (grab);<br>• "WRONG ONE!" confusion when he catches a clone;<br>• lose sight (scratches head);<br>• donut idle.<br>Procedural FK walk plus look-at IK (roblox_quality §4.2-4.3) | L |
| A5 Gus's intention is readable | premium §6.3: boot prints show his next 2 s of patrol (not in Torch Amber; cleared by the palette check); the cone flickers before it turns; a "GUS" nameplate the first time you see him | M |

### 4.4 Feedback, VFX and juice (track F)

Each interactable gets a row in `docs/FEEDBACK_TABLE.md` (premium F1/F2):

| Object | Idle affordance | Use | Sound | Motion |
|---|---|---|---|---|
| Plate | soft breathing ring, letter decal | the presser's colour floods in, a cable pulse runs to its door | clunk + hum | the plate sinks 0.15 studs |
| Door | its lamp shows which plate | dust puff, lamp turns green | rumble | rises with overshoot |
| Laser | a 3-layer beam with a flicker before re-arm | sparks, soot on the zapped clone | crackle, whine 0.5 s before re-arm | — |
| Loot | glint every 2 s, tinkle in range | pops up into the hands | grab chime (3 variations) | squash on grab, bob while carried, bounce on drop |
| Bank / van | glows when you carry loot | 24-coin burst, "+$100" flies to the meter, the meter counts up | cha-ching + coin rain | the van bounces |
| Gus | — | "?" or "!" bubble pops | heartbeat on "?", whistle on "!" | head-first turns |

Also:
- **F1 Rewind finishing** (POLISH #19): a 66 ms freeze; coloured path trails rewinding along each clone's route; scanline bands; muffled world audio.
- **F2 "8 OF ME"** (POLISH #14): the world dims, every copy flashes its outline in record order, the camera pulls back, a stamp with eight glyphs, a choir hit. This is clip format #1, so it gets the most care of any moment.
- **F3 Busted and zapped** (POLISH #13): glitch, a burst of tape ribbon, soot, a 66 ms hit-stop on the player's own catch only.
- **F4 Heist complete**: the vault-door slam, a gold rain at the Line-up, trophy fly-in.
- **F5 Juice governor**: every effect has a low-tier substitute; ≤ 360 live particles on touch; floating numbers merge (premium B3, B6, F7).

### 4.5 Camera and presentation (track C)

- **C1 CameraDirector** (POLISH §4.5): zoom limits 8/16/28; walls between the camera and the player fade within 0.1 s; a framing shot at the start of every run (the camera eases from the objective to you, 0.8 s, skippable); shake only on the alarm, scaled by the setting; hit-stop only on the four heavy beats.
- **C2 Level intro "flyover"** on first entry to each level (≤ 3 s, skippable): the camera glides over the plate, the door and the loot while the one-line goal appears. This is "show, don't tell" for the objective.
- **C3 Busted view**: the camera eases to Gus for 0.6 s, a "BUSTED" stamp, then one line of advice.
- **C4 State transitions**: garage → heist → results → garage, each with an authored in/out of ≤ 0.6 s (premium H4).

### 4.6 Audio additions (track F, small)

The three missing ids, plus:
- Gus's key-ring jingle;
- the boot-print step;
- the laser re-arm whine;
- the coin-burst layer;
- the 8 OF ME choir hit;
- the garage jukebox loop;
- a muffle (800 Hz low-pass) during rewind, deck and menus.

All from the licensed partners (AUDIO.md rules), ≥ 3 variations on anything that repeats. The owner listens through the full set once (owner task).

---

## 5. Moment-by-moment spec (what "finished" looks like on screen)

Each row is a contract for one screen or moment. The PhotoBooth bookmark is the shot that proves it (§8).

| Moment | Light / world | Layout | Animation | VFX | Sound | Words (exact) |
|---|---|---|---|---|---|---|
| **Loading (0-5 s)** | — | ink card, logo, spinning reel | reel spins, logo breathes | — | tape whirr | none |
| **Van door → L1 street** | the shop lit warm from inside, street lamp pool | HUD slides in after the doors | door panels slide apart 0.3 s; camera eases down to the shop | dust motes in the lamp | door slam, night ambience | none |
| **L1 objective flyover** | plate pool, cash on the counter glinting | goal chip top centre | camera glides plate → door → cash → you (2.5 s) | plate ring pulses | soft "ding" on each | **"Hold the door open. Get the cash."** |
| **First plate press** | plate floods in your colour | — | plate sinks, cable pulse to the door, door rises | dust puff, door lamp → green | clunk + rumble | "Stay on it." |
| **First REWIND** (L1) | REWIND button breathes | REWIND 72 px, lower right | — | — | — | "Tap ◀◀ REWIND." |
| **Rewind** | world desaturates, scanlines | HUD fades | 66 ms freeze; reel spins back; your path trail rewinds | scanline bands, VHS tracking line | tape rewind whine, world muffled | none |
| **First clone appears** | clone glows in your colour | "◀ YOU, 10 SEC AGO" tag | the clone prints from the feet up, walks out of you to the plate, stands with weight shift, glances back at you | tape-print scan, floor glow | print chirp | "That's you. It does what you did." |
| **Run with loot** | cash sparkles | loot meter fills | cash held in hands, bobbing | — | grab chime | "Bring it to the van." |
| **First bank** | van glows | meter counts up | van bounces | 24-coin burst, "+$100" flies to the meter | cha-ching + coin rain | "Banked!" |
| **Line-up** | spotlight on the crew | skip after 2 s | every clone of you poses in record order | gold rain | crowd whoop | "Your crew." |
| **Results (job sheet)** | — | sheet slides in, stamps land | haul counts up, goal lines struck through, stamps land | ink ring per stamp | stamp thunk ×3, count-up tick | first time per star: "HAUL: got the goal", "CREW: 2 clones or fewer", "CLEAN: never caught" |
| **Garage** | warm pool on your van, lit trophy shelf | tape shelf at the van | your van idles; your L1 trophy flies in | dust in the light | jukebox | "▶ NEXT" glowing on tape 2 |
| **L2 first look** | two plate pools, two door lamps | — | flyover: plate A → door A, plate B → door B | lamps pulse in pairs | — | **"Two doors. You need two clones."** |
| **Stuck (2 runs, no progress)** | — | — | a white Mentor ghost walks the solution once | ghost trail | soft chime | "Watch the ghost. Copy it." |
| **First Gus** (L4) | his torch cone, warm | "GUS" nameplate | flyover ends on Gus dozing; he wakes, stretches, starts patrol | — | yawn, key jingle | "That's Gus. Stay out of his light." |
| **Caught** | cone flashes red | — | 66 ms freeze, camera to Gus, Gus grabs, "BUSTED" stamp | stamp burst | whistle + stamp | one line by cause, e.g. "He saw you. Wait behind the shelf." |
| **8 OF ME** (Party) | world dims to 60 % | stamp centre | 7 clones print in a fan; outlines flash in record order; camera pulls back | 8 glyphs | choir hit | "8 OF ME!" |
| **Dawn** | sky warms toward sunrise over the last run | sun icon on the counter | — | — | rooster, distant | before: "Sunrise after run 6." After: "OUT OF TIME. Try: [cause-specific tip]" |
| **Big Score vault** | vault lamps row "VAULT 2/4" | — | each plate lights its lamp; at 4/4 the door swings | sparks | heavy clank per lamp | "Four plates. Four of you." → "LOCKDOWN! Out the back door!" |

---

## 6. Comprehension and onboarding (track O)

### 6.1 Design changes (decisions for the owner in §10)

1. **END RUN becomes "◀◀ REWIND"** everywhere (WALKTHROUGH P1-6). It is the signature verb; "END RUN" reads as "quit".
2. **Play order: Gus before the Party.** Today the Clone Party (third) is the first place a kid meets Gus, chasing them, before L4 teaches him. New order: L1 → L2 → L4 Night Clerk (meet Gus) → L5 Clone Party → L3 Lights Out → L6 Bank. If the owner wants Party early for virality, then Party gets its own 3 s Gus intro instead.
3. **The daily vault unlocks after Night Clerk**, not after L1 (P1-12). Each daily gets its own objective line.
4. **Plates get letters and lamps.** The door it opens shows the same letter and lamp, and a cable runs between them.
5. **Stuck help after L1** (P0-2): 2 runs without progress → Mentor ghost; 3 catches → "Try Relaxed mode?" card (Gus reacts 50 % slower; no Diamond).
6. **Full deck** (P0-3): "DECK FULL: tap a clone, then ✕" plus a toast naming which clone was replaced, plus "Start over".
7. **L1 tutorial bug** (P0-1): fixed, with a sim test.
8. **Every failure says why**, within 1 s, in one line from a cause → advice table (premium G4). The reason stays on screen until the deck opens (today it is wiped in the same frame).

### 6.2 "Show, don't tell" rules

- Every new object gets a **flyover** (C2) on first sight. The goal line names it with an icon chip, not a word only.
- Every new verb is taught with **one** line at the moment it is the right move, and the button **breathes** at that moment.
- **No line over 8 words. No intro over 30 words per level.** A CI script counts them.
- The first five actions (step, plate, rewind, clone, bank) each get a **bigger first-time version** of their feedback (premium G2).

### 6.3 Words pass (glossary)

Player words, used consistently. Anything not in this list is rewritten.
- **clone**, never echo or tape;
- **◀◀ REWIND**;
- **button**, never plate, if the kid test shows "plate" confuses (decision §10);
- **door**, **laser**, **cash**/**loot**, **van**;
- **Gus**;
- **caught**/**BUSTED**;
- **crew**;
- **sunrise**, never Dawn in body text; the DAWN stamp can stay as a stamp.

Every string lives in one `Strings.luau`, so the words pass is one file and translation is possible later.

---

## 7. Levels (from LEVELS.md and the renders)

Each level gets a pass with this checklist:
- The spawn camera sees the objective (or the flyover shows it).
- One focal light pool per room.
- Every plate, door, laser and loot reads at 48 px on a 360-dp phone.
- One storytelling prop per room (Gus's donut box, the crooked Santa, the kid's letter to Santa on the counter).
- Christmas dressing that never hides a signal.
- No dead ends where a clone can get stuck invisibly.
- A Studio PhotoBooth shot of bookmarks B1-B4 passes grading.

The specific per-level findings and fixes are in `docs/audit/LEVELS.md` §fixes; this plan schedules them in phase 4.

---

## 8. The quality system: how we know it's actually good

### 8.1 The verification ladder (roblox_quality §6.2)

Every visual change records the highest rung it reached:

| Rung | What it proves | Who |
|---|---|---|
| R0 | Maths and CI: palette, luminance model, word counts, greps (no glyph icons, no raw tweens, no default fonts) | Claude, automatic |
| R1 | Engine audit with Open Cloud Luau Execution: light counts, budgets, **clone visibility test**, every actor on screen | Claude, automatic |
| R2 | Blender preview, calibrated once against a Studio board | Claude |
| R3 | **Real Studio pixels**: the PhotoBooth plugin captures B1-B4 per level in one click and pushes PNGs to a `shots` branch; Claude reads them and grades them | Owner clicks once; Claude reviews |
| R4 | Phone screenshots: a dev Photo mode, or gallery files dropped in `docs/art/shots/inbox/` | Owner |
| R5 | Telemetry after launch | Automatic |

**No visual item counts as done below R3.** This is the change that would have caught every screenshot problem.

### 8.2 Automatic grading (Python, every R2-R4 shot)

Each shot is checked for:
- crushed blacks (< 2 % of pixels under 3 % luminance);
- floor and wall luminance against the targets;
- greyscale contrast between actors and ground (≥ 15 %, premium A1);
- glow share (only signals glow).

A failing shot blocks the item.

### 8.3 Blind reviews

Before each gate, two independent reviewer agents get only the screenshots and clips, not my explanation. They score them on the LihFolk `quality-score` rubrics (UI, VFX, world, animation; ≥ 8.5 to pass) and against the 60 criteria.

### 8.4 Automated "first-time player"

The existing NaiveKid bots are extended. A scripted greedy kid and a confused kid (ignores plates, spams REWIND, walks into Gus) play every level in the engine. The run fails if any bot soft-locks, or goes 3 runs without a line of help.

### 8.5 Kid tests (owner task, the real bar)

- **When:** two rounds, 3-5 kids aged 8-13, each playing cold for 10 minutes while being filmed. Round 1 is the end of phase 3, round 2 the end of phase 4.
- **What is measured:**
  - first clone ≤ 30 s and first bank ≤ 45 s for ≥ 4 of 5 kids;
  - each kid can say "what the glowing people are" after L1;
  - zero "what do I do?" stalls over 20 s in L1-L2;
  - ≥ 3 of 5 ask to keep playing.
- **Script:** I write a one-page script for the owner.

---

## 9. Timeline (honest)

Today is Thu Nov 12. MASTERPLAN's launch date is Thu Dec 3, with a Dec 10 fallback.

**Effort:**

| Work | Agent-days |
|---|---|
| POLISH top 20 | about 33 |
| World and lighting research items | about 8 |
| Comprehension fixes | about 5 |
| Garage | about 3 |
| Level pass | about 4 |
| **Total** | **about 53** |

With 4-5 parallel tracks this is about 13-15 working days, plus gates and owner tests.

**Recommendation: launch Thu Dec 10** (the existing fallback), with **go/no-go on Mon Dec 7**.
- Dec 3 would mean cutting the garage, Gus's animation set and half the moment specs. That is exactly the "10 % finished" feeling again.
- Dec 10 still gives 3+ weeks of Christmas, and the Dec 18 school break, which is the real peak, is untouched.

| Phase | Dates | Delivers | Gate (must pass to continue) |
|---|---|---|---|
| **1. Make it visible** | Fri Nov 13 - Sun Nov 15 | **v24 published Sun Nov 15**:<br>• clones visible (root cause plus fallback plus test);<br>• lighting recipe A and pools in L1/L2;<br>• floor albedo;<br>• backdrop v1;<br>• all text glyphs replaced;<br>• player list fix;<br>• Studio save chip;<br>• L1 bug P0-1;<br>• ◀◀ REWIND label;<br>• PhotoBooth plugin | Owner plays v24: sees clones, sees the world. PhotoBooth shots pass grading. Clone visibility test green |
| **2. Foundations** | Mon Nov 16 - Sat Nov 21 | UI kit v2, icon sheet, HUD restyle, motion pass, CameraDirector, Gus on his mesh with 4 core beats, clone animation spike plus states, lighting on all 6 levels, garage rebuild v1, Strings.luau plus words pass | R3 shots of HUD, garage and 3 levels; blind UI review ≥ 8.5 |
| **3. Moments: the first 10 minutes** | Sun Nov 22 - Sat Nov 28 | Loading card and van wipe; flyovers; tape print; bank moment; rewind finish; 8 OF ME; busted; results job sheet; tape shelf; Line-up polish; stuck help; full deck; Gus's full set; feedback table done; video thumbnail from real footage (moved from Nov 22) | **Vertical slice gate:** groups A, F, G, H4 and the six non-negotiables on the first 10 minutes. **Kid test round 1** (Sat-Sun Nov 28-29) |
| **4. Whole game to the bar** | Mon Nov 30 - Sat Dec 5 | Kid-test fixes; L3, L4 and L6 plus the 12 daily vaults to the same bar; settings; phone pass (7 viewports plus a real phone at 30 fps); performance bench; audio listen-through; store page, icon and thumbnails remade from real shots; the 8 clip formats captured from the game | **Kid test round 2** (Sat Dec 5). Blind reviews. ≥ 54/60 criteria |
| **Go/no-go** | **Mon Dec 7** | The decision on the measured bars | If no-go: Dec 17 launch, the eve of the school break |
| **Launch** | **Thu Dec 10, 15:00 CET** | Public plus expedited review the same hour → all ages about Sat Dec 12 | — |
| Live | Dec 18 | Drop 1 "Wrapping Room" moves to the school-break start (MASTERPLAN calendar shifts one week; the finale moves to Dec 23) | — |

**Critical path:**
1. clone visibility;
2. lighting;
3. UI kit;
4. the moments that depend on the UI kit and the clone animation;
5. kid test 1.

The garage, Gus and backdrop run beside it.

**What stays cut** (MASTERPLAN §10.4 stands): no new levels, no new mechanics, no store expansion before launch. The whole budget goes into making what exists feel finished.

---

## 10. Decisions the owner approves with this plan

| # | Decision | My recommendation |
|---|---|---|
| D1 | Launch date | **Thu Dec 10** (go/no-go Mon Dec 7), drop 1 on Dec 18 |
| D2 | Rename END RUN → **◀◀ REWIND** | Yes |
| D3 | Play order with Gus before the Clone Party | Yes (L1, L2, L4, Party, L3, L6) |
| D4 | Daily vault unlocks after Night Clerk | Yes |
| D5 | Lighting recipe A "Moonlit Diorama" (bright, readable night) instead of a dark, realistic night | Yes. Darkness doesn't read on phones, and it's not the vibe |
| D6 | A 4th hand-authored clip (clone sneak walk near Gus) on top of MASTERPLAN 6.7's three | Yes, if the animation spike works on day 1 |
| D7 | "Plate" vs "button" in the words | Decide from kid test 1; ship "button" if any kid hesitates |
| D8 | Display font Oswald (caper poster) over a cartoon face | Yes; I'll show a type specimen shot in phase 2 |

## 11. What the owner does (about 2-3 hours over 4 weeks)

| When | Task | Time |
|---|---|---|
| Fri Nov 13 | Install the PhotoBooth plugin in Studio (I give one link and a token step through the secure form) | 10 min |
| Phase 1-4 | One click in Studio after each publish ("PhotoBooth → Capture all"); play the new build for 10 min, send 3 notes | 15 min/build |
| Nov 28-29, Dec 5 | Kid tests (script from me), with phone video | 1 h each |
| Before Nov 27 | Still open from before: Max Players = 8, ID verification/2SV, the @heistyourself handles, dev products, Robux for expedited review (by Dec 7) | 30 min |
| Phase 4 | Listen through the audio set once | 20 min |

## 12. Risks

| Risk | Plan |
|---|---|
| The clone visibility root cause is in engine behaviour we can't see headlessly | The fallback makes clones visible regardless; the PhotoBooth confirms with pixels; the owner check on Sun Nov 15 |
| Code-authored animation uploads don't play | One 2-hour spike on day 1 of phase 2. Fallback: the Lua pose player (already works) plus the owner's own avatar animation pack |
| `StudioCaptureService` doesn't work from a plugin | Fallback: the owner takes 4 screenshots with Studio's camera bookmarks (a 2-minute ritual) and drops them in the inbox folder |
| Lighting recipe A is too slow on low phones | Recipe C "Soft Toybox" is pre-specified. The `LightDirector` tiers drop shadows and pools; benchmark in phase 4 |
| Scope creep | Each phase has a fixed list. Anything new goes to the post-launch list unless it fixes a gate failure |
| Kid tests show a deeper design problem | Round 1 is at the end of phase 3, leaving a full week to react, and Dec 17 as the no-go fallback |

## 13. What happens right after approval

1. Write `docs/QUALITY_BAR.md` (the 60 + 6, with status) and `docs/FEEDBACK_TABLE.md`.
2. Phase 1 starts with the clone visibility test, because nothing else matters if you can't see your crew.
3. Status in PROJECT_STATE.md after every working block; a v24 link for the owner on Sun Nov 15.
