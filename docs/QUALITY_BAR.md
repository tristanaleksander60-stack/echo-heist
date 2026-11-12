# Quality bar: tracked status (PLAN_STEAM_PLUS §2)

The 60 criteria from `docs/research/premium.md` §4 (full wording, tests and sources there), plus the six non-negotiables. **Status:** `open`, `pass`, `fail`, `n/a`.

**Evidence rung:** `R0` CI, `R1` engine, `R2` Blender, `R3` Studio pixels, `R4` phone, `P` playtest.

**Launch rule (§2):** groups A and G in full, plus I1, I3, I4, C3, C6, F1 and H3 (marked ★), the six non-negotiables, and ≥ 80 % of the rest. Phase gates in PLAN §9.2. Update this file at every gate.

## Non-negotiables

| # | Rule | Status | Evidence | Note |
|---|---|---|---|---|
| N1 | Never invisible | open | R1 clone_engine (v28) | Engine green; needs R3/R4 |
| N2 | Never dark by accident, never flat | open | R0 place_check, R2 renders | Recipe A + lamps in; grade on R3 |
| N3 | No text glyphs as icons, no default Roblox UI | open | R0 glyph_check | Words now; icons + kit v2 in progress |
| N4 | Never unexplained | open | — | Failure reason stays; stuck help in phase 3 |
| N5 | Never a pop | open | — | Motion tokens in progress (U1) |
| N6 | Three channels per interactable | open | — | FEEDBACK_TABLE.md |

## The 60 criteria


### A

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| A1 ★ | In a greyscale screenshot of any gameplay frame, players, clones, Gus, loot and danger each differ from their ground by ≥ 15% value | C/O | open | — | |
| A2 ★ | A 64 px thumbnail of the busiest view answers "which ones are past me?" in ≤ 0.5 s for 4 of 5 testers | P | open | — | |
| A3 ★ | Every frame has at most **one** element at 100% saturation that is not a clone, loot or danger | O | open | — | |
| A4 ★ | Nothing in the environment glows (STYLE_BIBLE rule 5). Glow pixels belong to clones, signals or runtime-tinted parts only | O | open | — | |
| A5 ★ | Gameplay reads with shadows off: same pass/fail on A1-A2 at quality 1 | O | open | — | |
| A6 ★ | **Minimum on-screen size** at default zoom (16 studs) on the phone: Gus ≥ 48 px tall, loot ≥ 20 px, a plate ring ≥ 36 px wide, a clone ba… | O | open | — | |
| A7 ★ | Each room has exactly one focal light pool and one storytelling prop (STYLE_BIBLE §5) | O | open | — | |
| A8 ★ | No two meanings share colour **and** shape: Oklab ≥ 0.15 for signals, ≥ 0.20 plus a shape for danger | C | open | — | |

### B

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| B1 | Every VFX has an ink layer, a body, a white-hot core and ≤ 1 accent hue ([V] *VFX Readability and Value*) | O | open | — | |
| B2 | ≤ 3 full-screen flashes per second, always (Comfort) | C | open | — | |
| B3 | Every effect has a low-tier substitute rather than being deleted (blur → 2-frame Frame at 0.85; confetti → UIGradient shine; [V] *Juice o… | C | open | — | |
| B4 | Only the top two reward tiers dim the world: the diamond (15%, 0.6 s) and Heist Complete | C | open | — | |
| B5 | Lasers and cones show their **next state** ≥ 0.5 s before it happens (3 flickers before re-arm; cone sweep preview) | O | open | — | |
| B6 | Particle budget ≤ 360 live on touch, and no emitter is created per event (emit only) | C | open | — | |

### C

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| C1 | Every state change of a character has an **anticipation of ≥ 2 frames at 30 fps (≥ 66 ms)** before the main move: Gus turns, clone forms,… | O | open | — | |
| C2 | Every landing or stop has a settle: squash 0.9 / stretch 1.08 recovering in 0.12-0.2 s, pivot at the feet (rigid parts: a root dip of 0.0… | O | open | — | |
| C3 ★ | Gus has ≥ 6 readable acting beats at 64 px: idle (donut), patrol, "?" double-take, "!" point, chase, confused "WRONG ONE" | O | open | — | |
| C4 | Characters **look** before they act: Gus's head leads his body by 0.15-0.25 s on turns; clones face their next target 0.2 s before grabbi… | O | open | — | |
| C5 | Secondary motion on at least 2 elements per character: Gus's torch beam sway and moustache bounce; the clone's 0.5 s owner-hue trail | O | open | — | |
| C6 ★ | Failure states are funnier than success: each of Bonk, Zap, Busted and Shrug has a distinct silhouette in its first 0.3 s | O | open | — | |
| C7 | No foot sliding ≥ 0.3 studs per stride on clones at replay speed 1x and 3x | C/O | open | — | |

### D

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| D1 | **Two font families at most** ([V] *Text Fonts and Rich Text*): Builder Sans for UI, plus one display face for stamps and titles. The tap… | C | open | — | |
| D2 | A written **type scale** with ≤ 5 sizes (e.g. 14 / 18 / 24 / 36 / 64 at 720×330 design size), with no text below 14 px on the phone | C | open | — | |
| D3 | **Button press:** the art layer goes to 0.92 instantly (or ≤ 60 ms), then on release overshoots to 1.04 and settles to 1.0 in 0.2-0.3 s (… | C/O | open | — | |
| D4 | Motion tokens only: Enter 0.18-0.30 s Out/Back Out; Exit 0.10-0.18 s Quad In (never Back In); Feedback 0.06-0.12 s; Emphasis 0.25-0.45 s… | C | open | — | |
| D5 | Lists stagger at 0.03-0.07 s per item with a 0.4 s cap | C | open | — | |
| D6 | Input is accepted on the first visible frame of any panel; exit is 0.55-0.75× the enter time | C/P | open | — | |
| D7 | Every HUD element shows a meaningful state change by **motion** as well as colour (pulse, slide, stamp), and keeps a colour-only version… | C/O | open | — | |
| D8 | Icons share one grid and one stroke weight: a 24 px grid, 2.5 px stroke at design size, rounded caps; each glyph (●■▲◆, ✕, ⚡, ↻) reads at… | O | open | — | |
| D9 | Tap targets ≥ 48 px with ≥ 8 px gaps; END RUN 72 px; nothing interactive in the inset area | C | open | — | |
| D10 | Numbers that change **count** (Quad Out, 0.35-1.0 s, text updates at 10-30 Hz) and end on a 1.0 → 1.15 → 1.0 pop | C | open | — | |
| D11 | **One UI skin**: one corner radius (e.g. 10 px at design size), one stroke (2 px ink `#1C1F3B`), one drop shadow; no default Roblox grey… | O | open | — | |
| D12 | Every panel has an empty state, a loading state (skeleton or anticipation, never blank) and an error state | C | open | — | |

### E

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| E1 | Every input sounds within 100 ms, and the sound is never ahead of the picture; same-frame starts for local actions | C/O | open | — | |
| E2 | **The meaning-to-sound table:** each reserved meaning (clone, loot, danger, exit, Gus, mechanism) owns a timbre family, and no sound is u… | C | open | — | |
| E3 | UI sounds follow a hierarchy: hover/scroll near-silent or none, tap soft, confirm present, reward loud () | O | open | — | |
| E4 | ≥ 3 variations or ±5% pitch randomisation on anything that repeats more than once per 10 s | C | open | — | |
| E5 | Every danger has a pre-warning sound ≥ 0.5 s ahead (laser re-arm whine, Gus "?" heartbeat) | O | open | — | |
| E6 | The world muffles (low-pass about 800 Hz) during rewind, planning and menus over a running heist | O | open | — | |
| E7 | Loudness: music −18 LUFS short-term, SFX peaks about 6 dB over music, warnings never ducked below 25% | O | open | — | |

### F

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| F1 ★ | **Every interactable has 3 feedback channels on use**: visual (state change plus effect), audio, motion (a squash, a sink or a shake). Ph… | C/O | open | — | |
| F2 | Every interactable has an **idle affordance** visible from ≥ 12 studs: a pulse, a glint or a tinkle (Sly) | O | open | — | |
| F3 | Hit-stop only on the 4 heavy beats (rewind start, busted, diamond, heist complete), each ≥ 66 ms, never on routine actions | C | open | — | |
| F4 | Camera shake: off by default except on the Alarm trigger, scaled by the shake slider, never rolling | C | open | — | |
| F5 | Every reward has the four beats (anticipation, reveal, payoff, settle), and the button appears last with a 0.3 s guard ([V] *Reward Momen… | O | open | — | |
| F6 | Reward animation stays < 10% of play time across a 10-minute session | C | open | — | |
| F7 | Floating numbers merge within 0.55 s; ≤ 12 on screen (6 on low tier) | C | open | — | |

### G

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| G1 ★ | Control within 10 s of the first frame; first clone ≤ 30 s; first bank ≤ 45 s; ≤ 30 words (MASTERPLAN 7.5) | C/P | open | — | |
| G2 ★ | The first 5 actions get extra care: first step, first plate press, first rewind, first clone and first bank each have a unique, slightly… | O | open | — | |
| G3 ★ | The store description teaches the 3 verbs in ≤ 3 lines (the Fisch pattern) | O | open | — | |
| G4 ★ | Every failure shows **one sentence of counterplay** keyed by cause, within 1 s (the DOORS pattern) | C | open | — | |
| G5 ★ | No modal, offer or shop before L1Complete | C | open | — | |

### H

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| H1 | No camera cut or FOV change without a motivated ease (≥ 0.2 s Sine InOut), except the rewind snap | O | open | — | |
| H2 | Walls between the camera and the player fade within 0.1 s; the player is never fully occluded for > 0.3 s | C/O | open | — | |
| H3 ★ | The end-of-heist cut keeps its subject in the central 32% of frame width (9:16-safe) with the HUD hidden | C | open | — | |
| H4 | Every transition between game states (garage → heist → results → garage) has an authored in/out of ≤ 0.6 s, with no pop to black | O | open | — | |

### I

| # | Criterion (short) | Owner | Status | Evidence | Note |
|---|---|---|---|---|---|
| I1 ★ | A sound-off, 1-second clip from any heist is recognisably ours (clone glow plus badge plus diorama) for 4 of 5 testers who saw the icon once | P | open | — | |
| I2 | The 16.6 ms frame budget holds in the busiest view on the mid Android (MASTERPLAN 6.8) | O | open | — | |
| I3 ★ | No visible placeholder ships: no grey default parts, no "Label" text, no Studio default sky | C | open | — | |
| I4 ★ | No UI or effect waits on the server to start its first frame: the latency-mask pattern on every remote-driven animation ([V] *Squash Stre… | C/O | open | — | |
