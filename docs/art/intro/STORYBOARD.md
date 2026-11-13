# Story intro: storyboard (track INTRO)

_2026-11-13. Source: docs/PLAN_FIRST_PERSON.md §5 "INTRO" (owner-approved), MASTERPLAN §2.2 (Sir Hoardsworth, the
wordmark) and §4.3 ("Steal Back Christmas"). The shot list below is data in `src/shared/Heist/IntroPlan.luau`; the
key frames `shot_N.png` are rendered from that same data (`python3 tools/blender/intro_shots.py`), so the numbers here
and in the game cannot drift. Captions: `Strings.INTRO`. Cues: `Shared/Audio/Cues` (docs/AUDIO.md "Missing (intro)")._

**Length:** 36.5 s, 6 shots + the title smash. **Rules:** first join only (the FirstTime "title" kind, so a player sees
the intro or the old title beat once, never both), SKIP visible from the first frame (any key on a keyboard, ButtonB on
a gamepad), reduced motion = cuts instead of the whip-pan, no shake, no flashes, no letterbox slide. The owner waived
the "control within 10 s" bar for the intro; the server holds the first heist until the intro ends
(`Heist.Ready` while preparing, at most `Config.Intro.SERVER_HOLD_SECONDS`). Rewatchable: `Cinematic.play()` (the lobby
TV, wired by the lobby track).

**Arc:** the cosy snowy toy town under the northern lights → Hoardsworth Tower → the giant vacuum switches on → every
present swirls up into the Snow Globe → the town goes dark → a kid's letter to Santa drifts down to a garage → van
headlights, the Rookie catches the letter, tugs the cap, smug grin → clones tape-print in behind → HEIST YOURSELF →
the title card takes over at rest and the van doors open onto L1 (or the lobby).

| # | Time | Caption card | Camera | Lighting / mood | Action | Effects | Sound |
|---|---|---|---|---|---|---|---|
| 1 | 0.0-6.0 | CHRISTMAS EVE. | **Crane down**: from the aurora high over the town (FOV 56) down to roof height, ending on the tower over the roofs, the globe in frame (FOV 48); ease in-out | `town`: cool moon, warm lit windows, street lamps, the tree | snow falls on a toy town of gabled houses; Hoardsworth Tower (art deco: setbacks, a gold crown, lit windows, the giant H) stands over it with the Snow Globe on its terrace | fade from ink (0.6 s), the game's own northern lights (Heist/Aurora anchored to the stage), snow | IntroMusic (music box), IntroBells |
| 2 | 6.0-12.0 | SIR HOARDSWORTH WANTS IT ALL. | **Low angle push-in** from the terrace edge at his front-left, up at Hoardsworth against the sky, the Snow Globe off his shoulder (FOV 50 → 40); ease out | `tower`: hot burgundy-gold underlight, a cool violet rim from behind, the globe's glow | he twirls his moustache (gloat), the monocle glints, he grabs the lever and yanks it, then flings an arm at the town | monocle glint (7.3 s) | IntroHoardSting, IntroMonocle, IntroLever |
| 3 | 12.0-18.5 | EVERY PRESENT IN TOWN... | **Whip-pan** (0.32 s yaw sweep with blur; a cut under reduced motion) to right under the giant vacuum's mouth (it fills the frame), then a **crane back and down the stream**: the machine stays big over the presents pouring up into it | `tower` | the vacuum (1.4x, on its gantry off the terrace, the mouth hanging out over the town) roars on; presents lift off roofs and doorsteps and corkscrew up into the mouth; the globe starts to fill | white flash (FlashLimit), screen shake (Settings "shake"), suction beams, **the suction vortex** (spiral Beam arms spun about the mouth, Config.Intro.VORTEX, per tier), sparkle bursts (Heist/Particles budget), the vacuum's lamps | IntroWhoosh, IntroVacuumOn, IntroSuction (loop) |
| 4 | 18.5-22.5 | ...GONE. | **Slow push** from behind the globe over the town (FOV 52 → 48) | `gone`: everything a step colder | the last present thunks in, the globe is full; one by one the town's windows go dark | windows out, a smaller shake | suction stops, IntroGlobeThunk, then silence |
| 5 | 22.5-29.5 | ONE ROBBER. ONE NIGHT. | **Follow + crane down** with the letter from over the town to a dark garage, then a **low push-in** on the Rookie (FOV 50 → 36) | `garage`: near dark, then the headlights and the work lamp | a kid's letter to Santa flutters down into the garage; the van's headlights flick on behind the Rookie; he catches the letter, tugs the flat cap, smug side-eye grin | headlight beams, letterbox | IntroLetter, IntroHeadlights |
| 6 | 29.5-34.0 | IT'LL TAKE MORE OF ME. | **Pull back** and up (FOV 40 → 52) to reveal the crew | `garage` | four clones tape-print in behind him, one by one: copies of the Rookie drawn as EchoView draws yours (the outfit kept, crew pieces in your hue, older runs dimmer and drifting violet), striking his pose with his grin | the tape print (built up from the feet under a scan band, floor glows), one crew-hue Highlight (fill + outline) | IntroTapePrint, CloneChime x4 (the sound logo) |
| 7 | 34.0-36.5 | HEIST YOURSELF (the wordmark) | hold | `garage`, an ink veil | the title smash: the wordmark punches in and splits into its cyan / magenta / indigo copies | white flash | IntroTitleSmash |

Captions are big (72 design px, never under 34), white Heist display face with an ink stroke, in the lower third over
the letterbox, punch in (1.18 → 1) and fade with each shot; six words at most (unit-tested). All ASCII.

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
