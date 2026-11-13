# Story intro: storyboard (track INTRO)

_2026-11-13, revised the same day for REVIEW_STEAM_PLUS gap #7 (the INTRO AND GOLDEN FRAMES track). Source:
docs/PLAN_FIRST_PERSON.md §5 "INTRO" (owner-approved), MASTERPLAN §2.2 (Sir Hoardsworth, the wordmark) and §4.3
("Steal Back Christmas"). The shot list below is data in `src/shared/Heist/IntroPlan.luau`; the key frames
`shot_N.png` are rendered from that same data (`python3 tools/blender/intro_shots.py`, one shot per process:
`--only N`; `--sheet` rebuilds the contact sheet and `grades.json`), so the numbers here and in the game cannot drift.
Captions: `Strings.INTRO`. Cues: `Shared/Audio/Cues` (docs/AUDIO.md "Intro")._

**Length: 33.7 s** (was 36.5 s), 7 shots + the title smash. The owner asked for a **"very dramatic"** intro, so it
stays in the 30-34 s band (unit-tested: 30-40 s overall and <= 34 s). The review (REVIEW_STEAM_PLUS #7) suggested
**<= 22 s**; we did not cut that far: at 22 s the villain gets one shot again and the garage reveal loses its build.
What we cut instead is the drag: the crane over the town (6.0 → 4.8 s), the low push-in (6.0 → 4.2 s), the vacuum
(6.5 → 5.4 s), "...GONE." (4.0 → 3.4 s), the letter's fall (7.0 → 6.0 s) and the clones (4.5 → 4.0 s); the time saved
pays for the new villain close-up (3.4 s). If the kid tests (REVIEW #2) show players skipping before the title, the
next cut is shot 1 to 3.5 s and the letter's fall to 4.5 s (about 31 s).

**Rules:** first join only (the FirstTime "title" kind, so a player sees the intro or the old title beat once, never
both), SKIP visible from the first frame (Space / Enter on a keyboard, ButtonB / Start on a gamepad:
`Config.Intro.SKIP.KEYS`; not any key, so a player pressing W while it loads still sees it), reduced motion = cuts
instead of the whip-pan, no shake, no flashes, no letterbox slide. No server hold (INTRO LOAD FIX, 2026-11-13): a new
account is in the hideout as soon as its profile is read, the intro plays over it, and the client's boot `Heist.Ready`
(intro or title over) starts L1. `Cinematic.play` watches its own frames: if the plan stops advancing it ends at once
("stalled") and the title card shows, never a frozen frame. Rewatchable:
`Cinematic.play()` (the lobby TV). The beats are authored per shot (`IntroPlan.at(shot, seconds)`), so a retimed shot
never strands a pose, the letter or the swirl in the wrong shot.

**Arc:** the cosy snowy toy town under the northern lights → Hoardsworth Tower → **Hoardsworth, close: he laughs, the
monocle glints, his gold-ringed glove on the lever** → the giant vacuum switches on → every present swirls up into
the Snow Globe → the town goes dark → a kid's letter to Santa drifts down to a lit garage → van headlights, the Rookie
catches the letter, tugs the cap, smug grin → clones tape-print in behind → HEIST YOURSELF → the title card takes over
at rest and the van doors open onto L1 (or the lobby).

| # | Time | Caption card | Camera | Lighting / mood | Action | Effects | Sound |
|---|---|---|---|---|---|---|---|
| 1 | 0.0-4.8 | CHRISTMAS EVE. | **Crane down**: from the aurora high over the town (FOV 56) down to roof height, ending on the tower over the roofs, the globe in frame (FOV 48); ease in-out | `town`: cool moon, warm lit windows, street lamps, the tree | snow falls on a toy town of gabled houses; Hoardsworth Tower (art deco, gold crown, the giant H) stands over it with the Snow Globe on its terrace | fade from ink (0.6 s), the game's own northern lights, snow | IntroMusic (music box), IntroBells |
| 2 | 4.8-9.0 | SIR HOARDSWORTH WANTS IT ALL. | **Low angle push-in** from the terrace edge at his front-left, up at him against the sky (FOV 50 → 40); ease out | `tower` + his terrace lights (`STAGE.villainLights`: hot gold underlight, warm face key, cool violet rim) | he twirls his moustache (gloat), then flings an arm at the town ("ALL of it") | | IntroHoardSting |
| 3 | 9.0-12.4 | MINE. ALL MINE. | **The villain close-up** (new): a medium close-up on his face (FOV 34, the monocle near the centre), then the camera slides down his arm to the **gold-ringed glove on the lever's knob** (FOV 32); ease in-out | `tower` + the terrace lights + a small gold kicker on the hand | head thrown back in a smug laugh (`laugh` / `laughB` poses alternate: the chuckle; his open mouth shows over the kit face, `Config.Intro.LAUGH_MOUTH`), the monocle glints (0.45 s), the signet ring flashes on the knob (2.2 s), he yanks the lever (2.75 s, the handle swings -70 deg over 0.25 s) | monocle glint, ring glint (Heist/Particles) | IntroMonocle, IntroLever |
| 4 | 12.4-17.8 | EVERY PRESENT IN TOWN... | **Whip-pan** (0.32 s yaw sweep with blur; a cut under reduced motion) to right under the giant vacuum's mouth (it fills the frame), then a **crane back and down the stream** | `tower` | the vacuum roars on; presents lift off roofs and doorsteps and corkscrew up into the mouth; the globe starts to fill | white flash (FlashLimit), screen shake (Settings "shake"), suction beams, the suction vortex (`Config.Intro.VORTEX`, per tier), sparkle bursts | IntroWhoosh, IntroVacuumOn, IntroSuction (loop) |
| 5 | 17.8-21.2 | ...GONE. | **Slow push** from behind the globe over the town (FOV 52 → 48) | `gone`: everything a step colder | the last present thunks in, the globe is full; the town's windows go dark | windows out | suction stops, IntroGlobeThunk, then silence |
| 6 | 21.2-27.2 | ONE ROBBER. ONE NIGHT. | **Follow + crane down** with the letter from over the town to the garage, then a **low three-quarter push-in** on the Rookie (FOV 50 → 38), ending right of his axis so the headlight beams fan out past him | `garage` (a cool aurora fill, never black) + the garage's light rig (below); the headlights, the work lamp and the cage lamp snap on at 3.3 s | a kid's letter to Santa flutters down into the garage; the van's headlights flick on behind the Rookie; he catches the letter, tugs the flat cap, smug side-eye grin | layered headlight beams, the work lamp's cone, window shafts, letterbox | IntroLetter, IntroHeadlights |
| 7 | 27.2-31.2 | IT'LL TAKE MORE OF ME. | **Pull back** and up (FOV 40 → 52) to reveal the crew and the whole lit garage | `garage` | four clones tape-print in behind him, one by one: copies of the Rookie drawn as EchoView draws yours (the outfit kept, crew pieces in your hue, older runs dimmer and drifting violet), striking his pose with his grin | the tape print, one crew-hue Highlight | IntroTapePrint, CloneChime x4 (the sound logo) |
| 8 | 31.2-33.7 | HEIST YOURSELF (the wordmark) | hold | `garage` under an ink veil (`Config.Intro.TITLE_VEIL` 0.45: the lit crew shows through) | the title smash: the wordmark punches in and splits into its cyan / magenta / indigo copies | white flash | IntroTitleSmash |

Captions are big (72 design px, never under 34), white Heist display face with an ink stroke, in the lower third over
the letterbox, punch in (1.18 → 1) and fade with each shot; six words at most (unit-tested). All ASCII.

## The garage's light (REVIEW_STEAM_PLUS #7: shots 5-7 were near-black)

Motivated light only, warm practicals inside against the aurora's cool light from outside. Positions are
`IntroPlan.STAGE` (unit-checked: inside the garage, the work lamp over the van's roof, the rim from behind the Rookie
aimed at his head), numbers `Config.Intro.GARAGE`; Heist/Cinematic and the key frames build the same rig.

| Light | Where | On | Game | Tier |
|---|---|---|---|---|
| The aurora through the open roll-up door | a panel the size of the opening, facing in | always | SurfaceLight, cool blue `#9CBCFF` | all |
| Three high windows in the back wall | over the van, green below / violet above (the aurora) | always | Neon panes + a mullion; a shaft Beam each, falling over the van | panes all, shafts 1-2 |
| The cool rim on the Rookie | from the first window, aimed at his cap and shoulder | always | SpotLight 26 deg | all |
| Warm string lights | both side walls, sagging between hooks | always | Neon bulbs | 1-3 |
| The bench lamp | clamped over the workbench (back left) | always | PointLight, warm | all |
| The headlights | the van's lenses, out of the door | with IntroHeadlights | SpotLights + 2 layered FaceCamera Beams each (a core and a halo), dropping to the floor | lights all, beams 1-3, shadows 1-2 |
| The work lamp over the van | a shade and bulb on a cord over the roof | with IntroHeadlights | SpotLight down + a faint light-cone Beam | light all, cone 1-3, shadows 1-2 |
| The cage lamp | under the door header, over the Rookie | with IntroHeadlights | SpotLight down: the warm top on his cap | all |

Hoardsworth's terrace (shots 2-3) gets its own light while he is on stage (`STAGE.villainLights`,
`Config.Intro.VILLAIN_LIGHTS`): a hot gold underlight (the H sign's floodlight), a warm face key, a cool violet rim from
behind and a small gold kicker on the ringed hand. The ring (`Config.Intro.RING`) is a Neon-gold signet on top of his
right glove's knuckles; the laughing mouth is two small parts over the kit face's closed one, shown only while he
laughs (no new mesh, no re-upload).

## Key frames and grades (`docs/art/intro/shot_1..8.png`, `contact_sheet.png`, `grades.json`)

`frame_grade.py` on the picture between the letterbox bars (the bars are framing; the title shot has none). Near-black
= luma < 0.05. These are Blender approximations, not captures (REVIEW #1: the tone-map proxy is uncalibrated).

| Shot | Near-black | Dark (< 0.10) | Median luma | Value spread (p90-p10) | RMS contrast | Warm share |
|---|---|---|---|---|---|---|
| 1 eve | 0.5 % | 2.4 % | 0.51 | 0.53 | 0.20 | 1 % |
| 2 hoard | 1.3 % | 2.7 % | 0.43 | 0.32 | 0.16 | 4 % |
| 3 laugh (new) | 7.3 % | 15.1 % | 0.52 | 0.71 | 0.28 | 26 % |
| 4 every | 5.1 % | 5.6 % | 0.55 | 0.63 | 0.24 | 1 % |
| 5 gone | 2.9 % | 10.2 % | 0.25 | 0.49 | 0.18 | 4 % |
| **6 one** (was shot 5) | **0.1 %** (was 60.7 %) | 10.2 % | 0.33 (was 0.01) | 0.78 (was 0.29) | 0.28 | 25 % |
| **7 more** (was 6) | **0.3 %** (was 50.0 %) | 8.7 % | 0.20 (was 0.05) | 0.56 (was 0.43) | 0.23 | 18 % |
| **8 title** (was 7) | **4.3 %** (was 49.5 %) | 25 % | 0.14 (was 0.06) | 0.31 (was 0.34) | 0.21 | 2 % |

The "was" numbers are the old whole frames (their bars are not near-black: luma 0.054). Where the near-black is now:
shot 3, his black top hat, the open mouth (both meant) and the plinth's shadow side behind him; shot 4, the vacuum's
dark throat (meant); shot 8, the roof and the floor's front edge under the 0.45 veil.

**Honest scores (render only, never seen in Studio):** shot 6 the garage reveal 4 → **7.5** (warm/cool reads, the
Rookie's face has a key, the bench lamp and string lights fill the back; the left beam reads as haze more than a
beam in the still, and the 256-colour export bands the haze); shot 7 the crew 5.5 → **8** (the whole lit garage, the
clones are the most saturated things, the windows carry the aurora); shot 8 the title 4 → **7** (the crew shows
through the veil; the top third is still dark roof); shot 3 the villain close-up, new: **7.5** (the face, the monocle
glint and the ringed glove on the knob read in one frame; the open mouth is a box over the kit face and reads more
"shout" than "laugh" at full size, a mesh face would be better); intro overall 6.5 → **7.5**.

## Assets (assets/blender/intro.py, all gates pass; uploaded with tools/kit_upload.py)

| Asset | What | Tris |
|---|---|---|
| Hoardsworth | 17-part rigid rig like Gus (R15 joint names, pivots at the joints, `Shared/Heist/IntroRig`): 8.76 studs, burgundy velvet tailcoat with antique-gold trim (Warm Marble shade, never Heist Gold), cream waistcoat, white gloves, top hat, curled moustache, monocle (glint at its pivot), high collar, long tails | 3,684 |
| Intro_Lever | the switch: burgundy pillar, gold top, steel hinge + a separate handle (pivot = hinge) | 388 |
| Intro_Vacuum | the giant vacuum (authored 1.4x, on the tower's gantry): canister drum on wheels, gauges, ribbed hose, a flared intake hanging out over the town, an outlet into the globe; Neon rim + lamps (off / Bulb Warm) | 4,336 |
| Intro_Tower | Hoardsworth Tower (133572245411117): an art-deco toy-tycoon landmark, 130 studs to the roof terrace: a podium with a gold portal, two setbacks with gold cornices, corner piers with stepped gold caps, pilasters, a flared crown of corbels and sunburst fins, a balustrade, the vacuum's steel gantry; lit windows (Neon, out on "...GONE.") and the giant "H" (Neon, Sign Gold #FFB85C, floodlit) | 10,364 |
| Intro_SnowGlobe | the hero Snow Globe Vault: burgundy and gold plinth with fins and an "H" crest, glass dome (r 16), inlet cap, a heap of stolen presents (grown by code as it fills) | 6,252 |
| Intro_Present_A/B/C | three flying presents (tall burgundy, wide holly + gold ribbon, snow cube) | 196 each |
| Intro_Letter | the kid's letter: cream envelope, burgundy seal, crayon star | 160 |
| Intro_House_A/B | toy-town houses with snow roofs, wreaths, sills; lit windows are Neon (out on "...GONE.") | 1,092 each |

The Rookie: `ReplicatedStorage.CharacterKit.Rookie` (the CHARACTER track, R15, posed through its Motor6Ds; read when the garage is
built); a Part stand-in only if the kit never arrived. The van, street lamps and the tree are launch-kit pieces.
The ground and the garage walls are built by code (the Part tower only when the kit never arrived); the sky is the
game's own Heist/Aurora (the session's aurora hides while the intro plays: Aurora.solo / release).
