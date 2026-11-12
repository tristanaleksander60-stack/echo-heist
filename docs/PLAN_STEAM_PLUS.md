# PLAN: "Steam quality++": from systems-complete to premium (v2, for owner approval)

Written 2026-11-12, after the owner played version 23 and said: "it looks like an MVP, 10 % done; I can't see my previous selves".

**Status: v2, revised after two independent critiques (`docs/audit/PLAN_CRITIQUE_A.md`, art and game direction; `docs/audit/PLAN_CRITIQUE_B.md`, engineering, kids and production). Awaiting owner approval. No code changes until it is approved.**

This plan does not replace MASTERPLAN.md: concept, pillars, levels, economy and architecture stay. It replaces the parts of MASTERPLAN §6-7 and §10 that turned out too thin, and adds a quality system so "done" means "premium", not "wired".

**Inputs (all in the repo):**
- Owner screenshots of v23
- `docs/audit/WALKTHROUGH.md` (35 comprehension issues)
- `docs/audit/POLISH.md` (inventory: the first 10 minutes are about 38 % finished)
- `docs/audit/levels/*.png` (Blender renders from the player camera)
- `docs/research/premium.md` (10 Steam and 8 Roblox teardowns, 60 criteria)
- `docs/research/roblox_quality.md` (lighting, backdrop, UI, animation, VFX, verification)
- the two critiques
- MASTERPLAN, STYLE_BIBLE, VIRAL_PLAYBOOK, the LihFolk vault

---

## 0. The honest verdict

**What is really done (keep it):**
- the deterministic sim, recording and replay;
- server authority, instances, data, receipts and analytics;
- the audio wiring (46 of 49 cues);
- the Rewind (about 85 %);
- the Crew Line-up;
- HUD scaling and safe areas;
- captions and reduced motion;
- 6 levels and 12 daily vaults;
- a 50-piece art kit, and Gus's mesh (uploaded, unused);
- 800+ automated checks.

**What the owner sees** is none of that. They see:
1. the core fantasy, "your past selves are your crew", is invisible;
2. the world is black and floats in a void;
3. the UI is default Roblox with text symbols;
4. after L1, the game stops explaining itself.

The game is systems-complete but only 10-40 % finished in presentation, depending on the surface. The owner's "10 %" is fair for what shows on screen.

**Why it happened:**
- **I verified logic, not pixels.** Every test asserts state; none asserts that a clone has a body on screen, that a floor can be seen, or that a glyph renders.
- **The art stopped at the kit.** It was approved under Blender lights, but the game has none, and nobody compared the two.
- **"Done" meant "wired".** There was no written bar for "finished" and no target image.

**What this plan adds:**
- a target image (golden frames, §3.3);
- a written, hard-to-game quality bar (§2);
- moment specs (§5);
- verification that ends in real pixels on a real screen (§8).

---

## 1. Diagnosis of the owner's screenshots

| # | Seen | Root cause | Fix |
|---|---|---|---|
| S1 | **No clones** | **Most likely (code-confirmed path, engine test pending): the clone's body falls apart and drops out of the world; only the invisible root moves.**<br>• `Avatars.strip` (`src/server/Heist/Avatars.luau:91-111`, added in the last perf round) deletes every body-scale value and every rig attachment no accessory uses, including all `*RigAttachment`s.<br>• When the copy enters `workspace`, the Humanoid can rescale or rebuild joints from those missing attachments. The Motor6Ds go, and the unanchored, massless, non-colliding limbs fall into the void with the badge on the Head.<br>• The root is anchored and transparent, so nothing visible remains.<br>• **Why every test stayed green:** the engine test only ever draws the mannequin (no avatar template), and it checks `positionOf`, which is maths on the recording, not a part.<br>**Second suspect:** rendered but black on black: SmoothPlastic, the hue dimmed to 35 %, an outline-only Highlight that the perf governor turns off at tier 4 and never back on.<br>**One question splits them:** did the owner see floating "●1" badges? | 1. **The strip keeps** rig attachments, scale values and joints. It strips only what is safe.<br>2. **A real engine test (R1, server-side, physics running):** build 3 real stripped templates (default, Rthro scales, layered clothing), run `EchoView` for 3 s of real Heartbeats on the L1 recording, and assert per clone:<br>&nbsp;&nbsp;• ≥ 15 Motor6Ds with both parts;<br>&nbsp;&nbsp;• every part within 5 studs of the root;<br>&nbsp;&nbsp;• Head and badge alive;<br>&nbsp;&nbsp;• transparency < 0.5;<br>&nbsp;&nbsp;• the Highlight on;<br>&nbsp;&nbsp;• the walk track plays;<br>&nbsp;&nbsp;• in frame by hand-done frustum maths, not occluded (raycast from the default camera).<br>3. **Never invisible by design:**<br>&nbsp;&nbsp;• a Highlight **fill** (about 0.55) that is never turned off for your own clones;<br>&nbsp;&nbsp;• a runtime `CloneHealth` check every second that swaps a broken rig for the hologram mannequin and reports it through the approved `Analytics.Ui` remote;<br>&nbsp;&nbsp;• a governor that can step back up.<br>4. A **Studio-only diagnostic chip** ("clones 3 drawn / 3 healthy / tier 1 / avatar"), so every owner screenshot carries the diagnosis |
| S2 | **Near-black levels** | No `Light` objects, no `Sky`, moon `Brightness 0.5`, Ambient (55,55,95): floors at about 1 % screen luminance, walls about 3 % (roblox_quality §0). Floors use `ink` albedo, which is black under any night light | Lighting recipe A "Moonlit Diorama", light pools per room, a new `floor` swatch. On-screen luminance targets, read at quality level 1 (§4.1) |
| S3 | **Void** | Nothing around the level instances; default night sky | Backdrop (§4.1 W4) |
| S4 | **"▯▯" boxes, emoji** | Text characters as icons (❚❚, ◐, ⏩, ⚡, and also ◀, which renders as emoji on phones) | **Phase 1:** replace every symbol with a word ("MENU", "FAST"). **Phase 2:** the icon sheet. **No exceptions:** "◀◀ REWIND" and "◀ YOU" become images. A CI grep bans non-ASCII in UI strings |
| S5 | **Jargon** ("REDO •2 + LATER", "Plate B", "tape", "Goal banked!") | Written by a developer | Words pass and glossary (§6.3) |
| S6 | **"Couldn't save this one" in Studio** | DataStores are offline in Studio | Studio-only "Studio test: progress not saved" chip |
| S7 | **Unexplained stars** | HAUL / CREW / CLEAN are never introduced | Each star is taught with a concrete reason the first time it can be earned (§5, results) |
| S8 | **Clone strip under the player list** | Collides with Roblox's player list (CoreGui) | Player list hidden during heists; clone chips under the timer |
| S9 | **MVP feel overall** | No target image, no motion, light, acting, transitions, music or title | Everything below |

---

## 2. The quality bar (written down, hard to game)

**The 60 criteria in `docs/research/premium.md` §4** become a tracked checklist, `docs/QUALITY_BAR.md`. Each criterion records its status and its evidence rung (§8).

**Six non-negotiables:**
1. **Never invisible.** Every actor is visible and whole in the R1 engine test, and in real-screen shots at quality 1 and 10. A broken rig falls back; nothing silently disappears.
2. **Never dark by accident, never flat.**
   - **Luminance floors:** floors ≥ 12 %, walls 15-30 %, hero props ≥ 35 %.
   - **Caps and ratios:** lit faces 1.5-2.5× shadow faces; the focal prop is the brightest thing that isn't a signal; glow covers 1-16 % of the frame.
   - Flat over-lighting fails, exactly like darkness does.
3. **No text glyphs as icons, no default Roblox UI** (no grey, no Gotham, no 1 px text outline, no emoji).
4. **Never unexplained.** Every verb, object and score is shown before it matters. Every failure says why and what to try, in one line, within 1 s.
5. **Never a pop.** Every panel, state change and screen transition has authored motion, with a reduced-motion version.
6. **Three channels per interactable**: visual change plus effect, sound, and motion. On phones, haptics too on plate, grab and bank.

**Anti-gaming rules:**
- **Random frames, not staged ones.** Each level is graded on its 4 bookmarks **plus 20 random-time frames** from an unedited playthrough capture.
- **Blind comparison, not self-grading.** Reviewers get unlabelled pairs: our frame and a reference frame (Monaco 2, Hitman GO, a top Roblox game). A pass is "comparable" in ≥ 2 of 3 pairings. Kid evidence outranks rubric scores.
- **Named must-pass criteria at launch.** All of groups A (readability) and G (onboarding), plus:
  - I1 (one-second identity), I3 (no placeholders), I4 (latency masking);
  - C3 (Gus acts), C6 (failures are funny);
  - F1 (three channels), H3 (9:16-safe framing);
  - the six non-negotiables;
  - and ≥ 80 % of the rest.
- **The owner's own number.** At every gate the owner re-scores the "% finished" table (POLISH §2). Launch needs ≥ 80 % weighted on *the owner's* score.

**Cut order, declared now** (what drops first if time runs out):
1. dailies at the full bar (they keep the readability bar);
2. L3 per-room dressing;
3. the garage jukebox and TV;
4. Gus beats 8-10;
5. the garage first-join line-up of 8 of you.

Nothing in the first 10 minutes is on the cut list.

---

## 3. Identity and target image

### 3.1 The look, in one sentence

**"A Christmas Eve caper in a toy-sized town, and the whole crew is you."** "Neon-noir diorama" stays as the internal art name only.

- **The world** is a miniature night diorama:
  - warm interiors dominate (about 60 % warm area); cool light only outside and in shadow;
  - one focal light pool and one storytelling prop per room;
  - **falling snow** in every exterior shot;
  - a skyline behind, with **Hoardsworth's tower and the Snow Globe Vault** as the landmark, so the event story is in every frame.
  - **Nothing glows** except signals, plus one written exception: small, static, warm-white fairy lights and windows away from the play floor.
- **Your clones are clearly *you*.** Your own avatar, textured, under a crew-colour Highlight fill, with a floor glow, the ●1 glyph badge and a scanline band when spawning. They are not a stripped silhouette. **Gate: 4 of 5 testers find their own clone among 4 avatars in a 64 px crop.** Your live character gets a client-side warm rim light and ground ring, so dark outfits never sink into the floor.
- **Each location has one signature silhouette and one dominant light colour.** No two levels share a spawn view.

  | Location | Signature silhouette | Light colour |
  |---|---|---|
  | Corner Shop | the striped awning | warm amber |
  | Toy Shop | one giant toy soldier | candy pink and gold |
  | Bank | columns | green banker's lamps |

- **Gus** is the funny threat. Every state is a pose you can read at 48 px, and he has his own voice barks.

### 3.2 UI identity: "the Crew Board" (tape only as dressing, per MASTERPLAN §2.2)

The tape motif already belongs to a competitor (Rewind Robbers), and kids of 8-13 have never held a cassette. So:

- **Clone Deck = polaroid crew cards.** Each is a headshot of *your own avatar* in its crew colour, with a stamped number and its last action as an icon (pressed plate A, carried cash, BUSTED).
- **Level select = a job board** in the van: pinned photos, string, medal stickers, and a glowing "NEXT" job.
- **Results = the job sheet:** the haul counts up, goal lines get struck through, and rubber stamps land.
- **Tape stays as dressing only:** the rewind effect and the counter-style timer digits.
- **Fonts:** Builder Sans for UI, plus **one chunky rounded display face that matches the MASTERPLAN wordmark** (Luckiest Guy or Fredoka One). It is chosen from a type specimen shot in phase 1.5 and used for stamps of ≤ 3 words.

### 3.3 Golden frames (the target image, before any breadth)

Three frames are built to final quality in the engine, captured on the owner's phone, and **signed off by the owner**:
- **G1:** the L1 spawn;
- **G2:** the Clone Party wide shot at "8 OF ME";
- **G3:** the garage with your van.

They become the style reference. Every later shot is graded **side by side** against them, and no multi-level art work starts before the sign-off.

### 3.4 Authorship package (track B, brand)

| Item | Spec |
|---|---|
| Wordmark | Chunky rounded capitals "HEIST YOURSELF" with a cyan double-exposure offset (MASTERPLAN §2.2) |
| **Title beat** (3 s, first join; skippable) | The wordmark splits into three offset copies on the clone arpeggio, then the van doors open onto L1 |
| **Sound logo** | The clone arpeggio. Used on the title, every clone print, 8 OF ME and the Line-up |
| **Music** | Decision D9: commission 2 stemmed tracks (the theme, plus a Christmas mix with sleigh bells and celesta) with trailer and TikTok rights, delivered by Dec 7. Library music stays in the game until then. Library music can't be used in our own TikToks |
| **Gus's voice** | Gibberish barks ("Hm?", "Hey!", "Wrong one?!", a yawn, a donut munch), ≥ 3 variations each |
| **Toy sounds** | Plates, doors and loot sound like toys (wind-up clicks, tin, felt), not realistic |
| **Icon** | The Rookie mascot (MASTERPLAN §9.4), drawn by a human illustrator from the freelance budget |

---

## 4. Workstreams

Effort is in agent-days: **S** ≤ ½, **M** 1-2, **L** 3-5. Phase per item is in §9.

### 4.0 Day 0: make parallel work safe (1 agent-day, before tracks fork)

- **Split `Hud.luau`** (2,382 lines) into `TopBar`, `Deck`, `Results`, `Garage` and `Hints`. Extract every player-facing string into **`Strings.luau`**, so tests assert keys, not text. Split `Config.Heist.UI/FX/CAMERA` into their own files.
- **One owner per file.** A single integrator merges daily with full CI plus the three engine suites, and publishes are serial (the 409 rule).
- A Lune **HUD layout check**: boxes as data, no overlap at 7 viewports. UI has almost no automated coverage today.

### 4.1 World (track W)

| Item | Spec | Effort |
|---|---|---|
| W1 Lighting recipe A | roblox_quality §1.2:<br>• a ClockTime 15 sun recoloured as moonlight (a real key light at every quality level);<br>• a city `Sky`;<br>• OutdoorAmbient about (115,110,165), Ambient about (95,90,140), EV 0.3;<br>• Atmosphere 0.28, Bloom threshold 1.15.<br>`place_check` asserts it | S |
| W2 Light pools in the kit | Lamps, signs, tills and vaults carry a light and an additive Beam floor pool. 6-9 lights per room, ≤ 2 shadowed. A `LightDirector` switches to **recipe C "Soft Toybox" by itself at tier ≥ 3** and can step back up | M |
| W3 Albedo | New `floor` swatch near `#3A365C`, warm rugs inside pools, contact-shadow cells. STYLE_BIBLE §2 changes to **on-screen** luminance bands | S |
| W4 Backdrop | A hazed ground plane, a near ring of kit façades, skyline rings at 300 and 600 studs with lit windows, a city cubemap with Hoardsworth's tower and the Snow Globe, falling snow. No searchlights. Client-built, about 30 draw calls | M |
| W5 Level pass | Per level: the signature silhouette, focal pool, storytelling prop (Gus's donut box, a crooked Santa, a kid's letter to Santa), signals readable at 48 px, Christmas dressing that never hides a signal. The renders show today's spawn camera hides the objective and that L6's spawn is L1's storefront | L |
| W6 Garage v1 | A warm, lit garage interior from the kit; 8 van bays; your van in your crew colour; a trophy shelf; the job board at the van. v2 adds the TV with the daily "best haul", the jukebox, and the first-join line-up of 8 of you | L |
| W7 Loading and transitions | A branded loading card; the title beat (§3.4); a van-door wipe between garage and heist; no cut to black anywhere | M |

### 4.2 Camera (track C)

- **C0 Diorama camera (decision D5).** A/B on the owner's phone during phase 1.5:
  - **Diorama:** pitch 45-55° down, distance 26-32 studs, FOV 40-45, free yaw, pitch clamped ≥ 35°;
  - **Classic:** today's follow cam (16 studs, FOV 70).

  The long lens is what makes a miniature read, and it shows your crew. The other option stays in Settings.
- **Composition rules**, graded per bookmark: you in the lower third and the objective in the upper third; the brightest thing in frame is the focal prop; nothing in the foreground outshines the subject; ≥ 3 clones visible in B2 once they exist.
- **C1 CameraDirector:**
  - zoom limits;
  - walls between the camera and you fade within 0.1 s;
  - a framing beat at the start of each run;
  - shake only on the alarm (scaled by the setting);
  - hit-stop only on the 4 heavy beats (rewind start, your own catch, diamond, heist complete).
- **C2 Level intro.** It plays **only inside time that already exists** (the van door, the rewind transition), and only once per level per account. Any touch skips it. **Never before first control on L1.** The camera glides from the plate to the door to the loot while the goal chip appears.
- **C3 Busted view:** 66 ms freeze, the camera eases to Gus, a stamp, then one line of advice.
- **C4 Transitions:** garage → heist → results → garage, each with authored motion of ≤ 0.6 s.
- **C5 Line-up framing:** the open 9:16 issue (`LINEUP_CAM_FIT_WIDTH`; the L5/L6 spots sit inside the van body) is fixed. Subjects stay inside the central 32 % (H3).

### 4.3 UI: the Crew Board kit (track U)

| Item | Spec | Effort |
|---|---|---|
| U1 Kit v2 | POLISH §4.1 plus roblox_quality §3:<br>• one radius, a 2 px ink stroke, one shadow;<br>• script-generated 9-slice panels with a lip and an inner highlight;<br>• raised buttons with a press state (0.92 → 1.04 → 1.0);<br>• motion tokens only.<br>CI greps enforce it | M |
| U2 Icon sheet | 27+ icons on one grid (24 px, 2.5 px stroke, rounded caps), rendered in Blender at 2× and uploaded with Open Cloud. Includes REWIND (◀◀) and YOU-arrow images. Upload and moderation lag is scheduled | M |
| U3 HUD | • **Run bar** with next-event markers for Gus and lasers (MASTERPLAN §7.4 #1, restored).<br>• **Timer** with fixed-width digits; **clone chips** under it; **loot meter** on the left.<br>• **REWIND** large, lower right, with a ring lock; it **breathes in sync with the plate pulse** when it's the right move.<br>• **GRAB** left of jump.<br>• Fits 720×330 with ≥ 8 px gaps (today it overflows by 33-43 px) | M |
| U4 Crew cards (deck) | Polaroid cards (§3.2). DELETE and REDO as icons with words. A full deck says so, names the clone it replaced, and offers "Start over" | M |
| U5 Job sheet (results) | The haul counts up; goal lines struck through; three stamps with concrete reasons the first time ("HAUL: $1,000 stolen", "CREW: 2 clones or fewer", "CLEAN: never caught"); the trophy flies to the van; buttons last, with a 0.3 s guard | M |
| U6 Job board (level select) | Pinned job photos, medal stickers, a glowing NEXT | M |
| U7 Settings and comfort | Music, SFX, shake, reduced motion, captions, colour-blind glyphs, camera (diorama/classic) | S |

### 4.4 Characters (track A)

| Item | Spec | Effort |
|---|---|---|
| A1 Clones visible and whole | §1 S1 in full. **Phase 1, first task** | M |
| A2 "That's me" look | A textured avatar with a crew-colour Highlight fill (0.5-0.6) and outline, a floor glow, the ●1 badge, and a feet-up "print" when it spawns (0.35 s). Older runs drift toward violet in **solo only** (MASTERPLAN §6.5). Recognition A/B and the 4-of-5 gate in phase 1.5 | M |
| A3 Clones act | **Default:** your own animation pack (catalog walk, run, idle, jump, fall), driven by a state derived from the recording, plus the existing Lua pose player for the custom states:<br>• plate stance (weight shift, one glance back at you);<br>• carry (loot in both hands, bobbing);<br>• stuck (taps the wall, shrugs);<br>• busted (hands up, glitch).<br>**Uploaded custom clips only if** a 2-hour headless spike passes (Lune writes the clip, Open Cloud uploads it, a server Animator plays it, `Motor6D.Transform` changes) | L |
| A4 Gus on his mesh | The uploaded 18-part mesh. **6 core beats at launch:** doze, wake-startle, patrol (torch sway, key jingle), "?" double-take (head first), "!" point plus chase (lean, pumping arms), catch. **Beats 7-10** (WRONG ONE confusion, lose-sight head-scratch, donut idle, yawn) are on the cut order. Procedural FK walk plus look-at IK | L |
| A5 Gus's intention | Boot prints of his next 2 s (not in Torch Amber); the cone flickers before it turns; a "GUS" nameplate on first sight | M |

### 4.5 Feedback, VFX, juice (track F)

`docs/FEEDBACK_TABLE.md` gives every interactable an idle affordance and three channels:

| Object | Idle | Use | Sound | Motion |
|---|---|---|---|---|
| Plate (lettered) | breathing ring, letter decal | floods in the presser's colour, a cable pulse runs to its door | toy click + hum | sinks 0.15 studs |
| Door | a lamp shows its letter | dust puff, lamp turns green | tin rumble | rises with overshoot |
| Laser | 3-layer beam, flicker before re-arm | sparks, soot on the zapped clone | crackle, whine 0.5 s before re-arm | — |
| Loot | glint every 2 s, tinkle in range | pops into the hands | grab chime (3 variations) | squash, bob while carried, bounce on drop |
| Van | glows when you carry loot | 24-coin burst, "+$100!" flies to the meter | cha-ching, the van honks | the van bounces |
| Gus | — | "?" / "!" bubble pops | barks, heartbeat on "?" | head-first turns |

**Forgiveness** (premium pattern 12; in the sim, recorded so clones stay deterministic): plate tolerance at the edge, and a GRAB input buffer (the window is a tuning number in Config).

**Big moments:**
- **rewind finish:** a 66 ms freeze, coloured path trails rewinding along each route, scanline bands, the world muffled;
- **8 OF ME** (§5);
- **busted and zapped:** glitch, a burst of tape ribbon, soot; hit-stop on your own catch only;
- **heist complete:** the vault-door slam, gold rain;
- **juice governor:** every effect has a low-tier version; ≤ 360 particles on touch; floating numbers merge.

### 4.6 Audio (track F, small)

- The three missing ids.
- **New sounds:** Gus barks; key-ring jingle; boot steps; laser re-arm whine; coin-burst layer; 8 OF ME choir hit; toy material sounds.
- **Mix:** an 800 Hz muffle during rewind, deck and menus; ≥ 3 variations on anything that repeats.
- **Owner listen-through:** an **audio audition page**, built by me, with keep/replace checkboxes.

### 4.7 Performance (track P, moved forward from phase 4)

- **Clone bench:** run the still-open S1 phone bench in phase 1.
- **8-player budget:** a Highlight per owner (up to 8); 2-3 BillboardGuis per clone across 12 clones plus 16 Line-up figures. Measure them in R1 and merge where possible.
- **StreamingEnabled is off,** so all 8 instances' levels replicate to every phone. R1 measures this with 8 live instances. Then either turn streaming on, or accept it in writing with a memory number (decision in phase 2).
- **Luminance at quality 1.** The targets are read at quality 1, where voxel light leaks, fog goes black and Bloom is off.

---

## 5. Moment-by-moment spec

Each row is a contract. It is proved by a real-screen shot or clip at a gate.

| Moment | Light / world | Animation | VFX | Sound | Words (exact) |
|---|---|---|---|---|---|
| **Title beat (first join)** | ink | wordmark splits into 3 offset copies | double exposure | clone arpeggio (sound logo) | none |
| **Van door → L1** | the shop lit warm from inside, a street lamp pool, snow | door panels slide apart in 0.3 s; the camera settles on the shop | snow, dust in the lamp | door slam, night ambience | none |
| **L1 goal** | plate pool; cash on the counter glinting | (no flyover on L1, per C2) | plate ring breathes | soft tick | **"Hold the door open. Get the cash."** |
| **First plate press** | plate floods in your colour | plate sinks, cable pulse, door rises | dust, door lamp turns green | toy click + rumble | "Stay on it." |
| **First REWIND** | REWIND breathes in sync with the plate pulse | animated finger pointer on REWIND | VHS wobble preview at the screen edge | soft tick per breath | "Tap REWIND." |
| **Rewind** | world desaturates | 66 ms freeze, then your path trail reels back | scanline bands, tracking line | rewind whine, world muffled | none |
| **First clone** | the clone carries your colour fill | prints feet-up, walks out of you to the plate, shifts its weight, glances back at you | print scan, floor glow | arpeggio | "◀ YOU, 10 SEC AGO" tag, then "That's you. It copies you." |
| **Carrying loot** | cash sparkles | cash in your hands, bobbing; finger pointer on GRAB the first time | — | grab chime | "Bring it to the van." |
| **First bank** | van glows | the van bounces | 24-coin burst, "+$100!" flies to the meter | cha-ching, the van honks | "+$100!" |
| **Line-up** | spotlight | every copy poses in record order; busted clones slump on a **busted podium** | gold rain | 0.6 s snare roll landing on the pose | "Your crew." |
| **Results** | — | sheet slides in; haul counts up; lines struck through | ink ring per stamp | stamp thunk ×3 | "HAUL: $1,000 stolen", "CREW: 2 clones or fewer", "CLEAN: never caught" (the first time each) |
| **Garage** | warm pool on your van, lit trophy shelf | your van idles; your trophy flies in | dust in the light | garage ambience | "NEXT" glows on the job board |
| **L2 first look** | two pools, two door lamps | intro inside the van-door time: plate A → door A, plate B → door B | lamps pulse in pairs | tick per pair | **"Two doors. You need two clones."** |
| **L2 run 1, on plate A** | — | REWIND breathes; finger pointer | — | — | "Stay here. Tap REWIND." |
| **Stuck (2 runs, no progress)** | — | a "Show me?" chip; if tapped, a **dashed chalk-outline ghost** (no reserved colour) shows **the next step only** | ghost trail | chime | "Watch, then copy." |
| **Party opening (3rd level)** | Toy Shop: pink and gold, one giant toy | 3 s intro: **Gus dozing** in the back office, "Zz"; "GUS" nameplate | — | snore | "That's Gus. Don't wake him." |
| **Alarm Run** (till alarm wakes Gus) | cone flashes red | Gus wake-startle (cap pops), chase with a lean | red edge pulse | bark "Hey!", alarm | "Gus woke up! Run to the van!" |
| **WRONG ONE** (Gus catches a clone) | — | Gus freezes for 2 s, "?" over the clone, scratches his head | "?" pop | bark "Wrong one?!" | none (auto-bookmarked for clips, MASTERPLAN §9.2 #4) |
| **Caught (you)** | cone flashes red | 66 ms freeze, the camera eases to Gus, he grabs you | BUSTED stamp | bark plus stamp | one line by cause, e.g. "He saw you. Wait behind the shelf." |
| **First zap** (L3) | laser flares | the clone shudders, soot | sparks | crackle | "Zapped! Wait for the flicker." |
| **8 OF ME** | world dims **15 %** for 0.6 s | 7 clones print in a fan; **roll call:** each clone takes one pose beat 60 ms apart as the arpeggio climbs; the camera pulls back until all 8 fit inside the central 32 % (9:16-safe) | 8 glyphs, outline flash in record order | arpeggio to a choir hit | "8 OF ME!" |
| **Party end (sunrise)** | the sky warms to sunrise | the crew runs to the van | — | rooster | "SUNRISE! Count the loot." (not a failure) |
| **Dawn as failure** (L4, L6) | sunrise | — | — | — | "OUT OF TIME." + a cause tip ("Try: hide under the coat rack.") |
| **Big Score vault** | lamp row "VAULT 2/4" over the door | each plate lights its lamp; at 4/4 the door swings | sparks | heavy clank per lamp | "Four plates. Four of you." (or "buttons", per D7) → "LOCKDOWN! Out the back door!" |
| **Blooper cut** (end of heist) | — | the clone's best failure replays first (clip #2) | "MY CLONE BETRAYED ME" caption option | — | — |
| **Advent ornament** (daily vault) | tree lights up | the ornament flies to the van's tree | sparkle | bell | "Day 7 ornament!" |
| **A friend joins** | — | their van rolls into the next bay; their clone card appears | colour flash | horn | "[Name] joined your crew!" |

---

## 6. Comprehension and onboarding (track O)

### 6.1 Changes

1. **END RUN → REWIND** (as an image plus the word). It is the signature verb; "END RUN" reads as "quit".
2. **Play order stays as the owner decided** (L1 → L2 → Party → L3 → L4 → L6). The Party introduces a **dozing Gus** (§5); he covers only the back office until the Alarm Run, and the free first catch carries over from L1. This keeps the "8 OF ME" moment before minute 10, a go/no-go KPI.
3. **The daily vault unlocks after Night Clerk**, and each daily gets its own goal line.
4. **Plates get letters and lamps**, matching their door, joined by a cable.
5. **Stuck help after L1:**
   - explicit world-state lines for L2-L4 ("Stay here. Tap REWIND.");
   - after 2 runs without progress, a "Show me?" chip that shows the next step;
   - after 3 catches, a "Try Relaxed?" card (Gus slower, no Diamond).
6. **Full deck:** it says so, names the clone it replaced, and offers "Start over".
7. **L1 tutorial bug** (REWIND tapped while on the plate re-arms the tutorial) is fixed, with a sim test.
8. **Every failure says why** within 1 s, from a cause → advice table. The line stays until the deck opens; today it is wiped in the same frame.

### 6.2 Show, don't tell

- **Kids follow motion, not text.** An animated finger pointer marks REWIND and GRAB the first time each is the right move, and the button breathes at that moment.
- **Text limits:** no line over 8 words; no intro over 30 words per level (counted in CI).
- **The first five actions** (step, plate, rewind, clone, bank) each get a bigger first-time version of their feedback.

### 6.3 Words (glossary, in `Strings.luau`)

These words, used consistently:
- **clone** (never echo or tape);
- **REWIND**;
- **button**, if the kid test shows "plate" confuses (D7);
- **door**, **laser**, **cash**/**loot**, **van**, **Gus**;
- **caught**/**BUSTED**;
- **crew**;
- **sunrise** (DAWN stays as a stamp only).

Every string goes through one file, so the words pass is one diff.

---

## 7. Levels

Each level gets the W5 pass and must pass the composition rules (C0) and grading on bookmarks plus random frames.

Specific findings so far, from the renders:
- the spawn camera looks at the player's back, which hides the objective;
- a blown-out white slab fills the bottom fifth of the frame;
- dark-clothed avatars sink into the indigo floor;
- L6's spawn view repeats L1's storefront.

The full per-level fix list goes into `docs/audit/LEVELS.md` when the render audit finishes, and is scheduled in phases 2-4 per the cut order.

---

## 8. Verification

### 8.1 The ladder (record the rung reached for every visual item)

| Rung | Proves | How |
|---|---|---|
| R0 | Maths and CI | Palette, luminance model, word counts, greps (no glyphs, no raw tweens, no default fonts), HUD layout check |
| R1 | Engine truth | Open Cloud Luau Execution with physics running: **clone visibility test (§1)**, light counts, budgets, 8-instance memory, the animation spike, bot playthroughs |
| R2 | Previews | Blender, calibrated once against a matching Studio board |
| R3 | **Real Studio pixels in Play mode** | Step 1: a pinned GitHub issue, **"Shots inbox"**. The owner drops screenshots from any device; I pull them with `gh` (zero code, day 1). Step 2: a 2-hour spike on Remote Control plus Studio MCP on the owner's PC, so I can press Play and capture myself. Step 3: a Play-mode PhotoBooth plugin, only if step 2 fails and a capture spike passes |
| R4 | Real phone | Owner phone shots into the same inbox (Photo mode via DataStore is dropped before launch) |
| R5 | Telemetry | After launch, by device tier |

**Real-screen evidence (R3/R4) is required at every phase gate, batched.** Items don't wait for it one at a time, so the owner's clicks don't become a serial bottleneck.

### 8.2 Grading

A Python script grades every shot for:
- crushed blacks;
- the luminance floors **and caps**;
- the lit/shadow ratio;
- glow share;
- greyscale actor-vs-ground contrast (≥ 15 %).

Every shot is compared side by side with its golden frame.

### 8.3 Reviews

- **Blind pairs:** ours vs a reference (§2).
- **Rubrics:** the LihFolk `quality-score` rubrics (≥ 8.5), weighted below kid evidence.
- **Owner:** the owner re-scores the "% finished" table at every gate.

### 8.4 Bots

The NaiveKid bots are extended with a greedy kid and a confused kid (ignores plates, spams REWIND, walks into Gus). A run fails if a bot soft-locks, or goes 3 runs without a help line.

### 8.5 Kid tests (protocol)

| Item | Detail |
|---|---|
| Rounds | **0:** Sun Nov 15-16 on v24, 1-2 kids, 15 min. **1:** Sat-Sun Nov 28-29, 4-5 kids. **2:** Sat Dec 5, 4-5 kids |
| Who | 8-13 years old. Include one co-op pair of friends and one weak or non-native reader. Half the kids start at L2 |
| Setup | The kid's **own avatar** (early-tester invite to their account [verify under-13 invites], or a spare account they restyle first). Their own phone, plus one low Android. 20-25 min |
| Ethics | Written parental consent; film the **screen only** |
| Method | No helping; count help requests on a timestamp sheet; neutral questions only ("What happened when you pressed that?") |
| Pass bars (written before the test) | • First clone ≤ 30 s and first bank ≤ 45 s for ≥ 4 of 5.<br>• Each kid can explain the clones in their own words after L1.<br>• No stall over 20 s in L1-L2.<br>• 4 of 5 find their own clone.<br>• ≥ 3 of 5 ask to keep playing.<br>• Premium question: our 10 s clip next to 2 top Roblox games, "which looks best?" |

I write the one-page script and the sheet.

---

## 9. Timeline

### 9.1 The real critical path: the Kids & Select review

Until Roblox's review passes, a new game reaches only 16+ users; 8-13-year-olds can't see it. Review takes about 48 h and has stalled for 8+ days for some developers. Polish alone does not get kids in by the Dec 18 school break; **the review clock has to start early.** So the plan splits "public" from "launch":

- **Soft public, Thu Dec 3** (go/no-go **Mon Nov 30**, on the vertical slice and kid round 1). The game goes public on its live place, 16+ only, with **no marketing**. Expedited review is submitted that hour.
- **Polish ships as updates** until Dec 10 [verify that updates don't restart the review].
- **Marketing launch, Thu Dec 10** (go/no-go **Mon Dec 7**, on kid round 2 and the bar): creators, TikTok and ads start once all ages are open **and** the Dec 10 build is in. **Fallback: Thu Dec 17**, the eve of the school break.
- **Drop 1 "Wrapping Room": Fri Dec 18** (school break). The finale moves to Wed Dec 23. MASTERPLAN's calendar shifts one week.

### 9.2 Phases

**Effort:**

| Work | Agent-days |
|---|---|
| The work in this plan | about 53 |
| 25 % integration tax | about 13 |
| **Total** | **about 66** |

That is about 66 agent-days in 4-5 parallel tracks. It fits Nov 13 to Dec 9 **only with the cut order and the soft-public split**. Without them, the full scope lands around Dec 17-21 (critic B's estimate, which I accept).

| Phase | Dates | Delivers | Gate |
|---|---|---|---|
| **0. Day 0** | Fri Nov 13 | Hud split, `Strings.luau`, Config split; shots-inbox issue; the clone visibility engine test (red first) | CI green after the refactor |
| **1. Make it visible** | Fri Nov 13 - Sun Nov 15 | **v24 on Sun Nov 15**:<br>• clones visible and whole (strip fix, test green, CloneHealth, Highlight fill, diagnostic chip);<br>• recipe A plus pools in L1/L2/Party;<br>• floor swatch;<br>• symbols replaced by words;<br>• REWIND (word plus image);<br>• player list hidden;<br>• Studio save chip;<br>• L1 bug fixed;<br>• clone phone bench run | Owner session 1 (Sun Nov 15): plays v24, drops 4 shots in the inbox, sees clones and the world. **Kid round 0.** The test passes on 3 real avatar types |
| **1.5 Target image** | Mon Nov 16 - Wed Nov 18 | Diorama vs classic camera A/B; golden frames G1-G3 at final quality; clone recognisability A/B; type specimen; Crew Board mock-up; music decision D9 (Mon); the animation spike | **Owner signs off G1-G3 and the camera** (remote, via the inbox, Wed Nov 18) |
| **2. Foundations** | Wed Nov 18 - Mon Nov 23 | UI kit v2, icon sheet, HUD (with the run bar), motion; CameraDirector; Gus mesh and 6 beats; clone acting; lighting on all 6 levels; backdrop; garage v1; words pass; streaming decision | Owner session 2 (Sun Nov 22). Real-screen shots of HUD, garage and 3 levels graded against the golden frames; blind UI pairs |
| **3. Moments: the first 10 minutes** | Mon Nov 23 - Sat Nov 28 | **Marketing slice by Tue Nov 24:** the Party at final quality (8 OF ME, WRONG ONE, Line-up), a capture kit with a hero outfit and "◀ ME, 20 SEC AGO" burned in. Then every §5 moment; title beat; loading; stuck help; job sheet; job board; first-time feedback; audio page | **Vertical slice gate (Fri Nov 27):** groups A and G, H3, H4, I1 (1-second clip), A2 (64 px thumbnail), the six non-negotiables on the first 10 minutes. Owner session 3 plus **kid round 1** (Sat-Sun Nov 28-29) |
| **Go/no-go 1** | **Mon Nov 30** | Soft public on Dec 3? | Vertical slice gate plus kid round 1 bars |
| **4. Whole game** | Mon Nov 30 - Wed Dec 9 | Kid-test fixes; L3, L4, L6 and the 12 dailies to the bar (per the cut order); settings; phone pass at 7 viewports plus a low Android; store page and thumbnails from real shots; the illustrated icon; clips; Gus beats 7-10 if time allows. **Thu Dec 3:** soft public + review | **Kid round 2** (Sat Dec 5); blind reviews; the named must-pass criteria; the owner's % ≥ 80 |
| **Go/no-go 2** | **Mon Dec 7** | Marketing launch on Dec 10? | The above. If no-go: Dec 17 |
| **Marketing launch** | **Thu Dec 10** | Creators, TikTok, ads | — |

---

## 10. Decisions for the owner

| # | Decision | My recommendation |
|---|---|---|
| D1 | Soft public Thu Dec 3 (16+, no marketing, review starts) + marketing launch Thu Dec 10, fallback Dec 17 | **Yes** |
| D2 | END RUN → **REWIND** | Yes |
| D3 | Keep your play order (L1, L2, Party, L3, L4, L6); the Party introduces a dozing Gus | Yes |
| D4 | Daily vault unlocks after Night Clerk | Yes |
| D5 | Camera: A/B the **diorama** view (high, long lens) against today's follow cam on your phone, Nov 16-18; the other stays in Settings | Yes, decide from the A/B |
| D6 | UI identity: the **Crew Board** (polaroid crew cards of your avatar, a job board, stamps) instead of a tape-deck UI | Yes |
| D7 | "Plate" or "button" in the words | Decide from kid round 0/1 |
| D8 | Display font: chunky rounded, matching the wordmark (Luckiest Guy / Fredoka One), from a specimen | Yes |
| D9 | **Commission original music** (2 stemmed tracks with trailer and TikTok rights, by Dec 7) | Yes. Cost is set by the freelance budget; you approve the quote |
| D10 | The mascot icon drawn by a human illustrator (MASTERPLAN §9.4) | Yes |
| D11 | Lighting recipe A (a bright, readable night) | Yes |

---

## 11. What the owner does (honest: about 8-12 hours over 4 weeks, in 3 fixed sessions)

| When | Task | Time |
|---|---|---|
| **Now** | One question: in v23, did you see floating "●1" badges where the clones should be? | 1 min |
| This week | Maturity questionnaire on Creator Hub ("heist", "robbery" and BUSTED chases must still come out Mild); still open: Max Players = 8, ID/2SV, handles, DataStore scope on the key (I'll try to automate Max Players and dev products through Open Cloud first [verify]) | 45 min |
| **Session 1, Sun Nov 15** | Play v24 for 15 min, drop 4 screenshots in the inbox issue, kid round 0 (1-2 kids) | 1.5 h |
| Wed Nov 18 | Sign off the golden frames and the camera from your phone | 20 min |
| **Session 2, Sun Nov 22** | Play the build, drop shots, the audio audition page | 1.5 h |
| By Nov 27 | Recruit kids plus parental consent for rounds 1-2 | 1 h |
| **Session 3, Sat-Sun Nov 28-29** | Kid round 1 (script from me), re-score the % table | 2.5 h |
| Sat Dec 5 | Kid round 2 | 2 h |
| By Dec 3 | Robux for expedited review; music quote approval | 15 min |
| Optional, phase 1.5 | Turn on Remote Control on your PC for 2 hours, so I can drive Studio myself (removes most screenshot work for you) | 15 min |

---

## 12. Risks

| Risk | Plan |
|---|---|
| The strip fix doesn't explain S1 | The engine test decides. The CloneHealth fallback plus the Highlight fill make clones visible regardless; the diagnostic chip shows the cause in your first screenshot |
| Review stalls for 8+ days | Review starts Dec 3, a week before marketing; Dec 17 fallback; ads to 16+ as the backup path |
| An update restarts the review | Check before Dec 3 [verify]. If it does: freeze the build from Dec 3 until review passes, and ship polish after |
| Animation uploads don't play | Catalog packs plus the Lua pose player are the default; uploads are a bonus |
| Real-screen capture is slow | The inbox works from day 1; Remote Control as an upgrade; shots batched per gate |
| Recipe A too slow on low phones | The LightDirector switches to recipe C at tier ≥ 3 by itself; the bench in phase 1 |
| 8 instances overload phone memory | The R1 measurement in phase 2; streaming decision |
| Parallel tracks collide | Day-0 split, one owner per file, a daily integrator, serial publishes |
| Self-grading bias | Blind pairs against references, kid evidence, and the owner's own % |
| Kid tests show a deeper design problem | Round 0 on Nov 15 catches it early; round 1 leaves a week before go/no-go 2 |
| Scope creep | Fixed phase lists, the declared cut order; anything new goes post-launch unless it fixes a gate failure |

---

## 13. Right after approval

1. Day 0: the refactor, the shots inbox, the clone visibility test written so it fails first.
2. `docs/QUALITY_BAR.md` and `docs/FEEDBACK_TABLE.md`.
3. v24 for owner session 1 on Sun Nov 15, with the diagnostic chip on.
4. PROJECT_STATE.md updated after every block.
