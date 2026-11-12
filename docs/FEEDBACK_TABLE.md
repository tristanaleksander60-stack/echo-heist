# Feedback table (PLAN_STEAM_PLUS §4.5, non-negotiable N6, premium F1/F2)

Every interactable has an **idle affordance**, visible from ≥ 12 studs, and **three channels on use**: a visual state change plus an effect, a sound, and motion. Phones add haptics on the three key verbs (plate, grab, bank). All tuning lives in `Config`.

The **First time** column is the bigger first-time version of the feedback (premium G2), shown once per account.

**Status** says what is in the game today (2026-11-12, place v28; the levels and world feedback track's WorldView pass is marked "world track": client only, numbers in `Config.WorldFx`, maths in `Shared/Heist/WorldFx`):
- **in:** exists in the game.
- **part:** some channels exist.
- **todo:** not built.

| Object | Idle affordance | Visual on use | Sound (cue, ≥ 3 variations if repeated) | Motion | Haptic | First time | Status |
|---|---|---|---|---|---|---|---|
| **Plate** (lettered) | Bulb Warm glow at 50 %, slow breathe; letter on top; floor light pool | Floods in the presser's crew colour; a cable pulse runs to its door or laser | toy click + low hum while held | Sinks 0.15 studs, settles with a 0.1 s overshoot | yes | Plate ring flash + "Stay on it." | part (glow, letter, cable in; world track: sink 0.15 on a spring with a ~0.1 s overshoot, haptic, hum cue `PlateHum` (empty id) in; toy click = PlatePress, a metal clunk until the owner's audio pass) |
| **Door** | Lamp in the plate's letter; red when shut | Lamp turns green; dust puff | tin rumble | Pocket-slides sideways with overshoot | — | Camera eases 0.3 s toward the door | part (slide, lamp in; world track: dust puff at the sill and the slide overshoot in; tin rumble = DoorOpen; the first-time camera ease todo) |
| **Laser** | Three-layer beam (ink, body, white-hot core); flicker 0.5 s before re-arm | Sparks; soot decal on the zapped clone | crackle; whine 0.5 s before re-arm | Clone shudders | — | "Zapped! Wait for the flicker." | part (sparks, flicker in; world track: three layers (ink sleeve, red body, white-hot core), whine cue `LaserWhine` (empty id) as the flicker starts in; soot on the zapped clone todo (clone track)) |
| **Loot** (cash, gold, gift) | Glint every 2 s; tinkle within 8 studs; goal sparkle | Pops into both hands | grab chime | Squash on grab; bob while carried; bounce on drop | yes | Finger pointer on GRAB | part (goal sparkle in; clones: carry pose with the loot between the hands, bobbing; world track: your live character carries it in both hands in front of the chest, facing where you face, with the clones' carry clip; glint every 2 s, squash on grab, bounce on drop, haptic in; grab chime = Grab; tinkle cue `LootTinkle` (empty id)) |
| **Van / bank** | Glows when you carry loot; arrows point to it | 24-coin burst; "+$100!" flies to the loot meter; meter counts up | cha-ching + coin rain; the van honks | Van bounces | yes | Bigger burst, louder honk | part (glow and arrows in; world track: 24-coin burst, van bounce, a "+$100!" world pop, haptic, `VanToot` cue (empty id) and `world.onBank(amount, worldPos)` in; the HUD's fly-to-meter is the UI track's) |
| **REWIND button** | Breathes in sync with the plate pulse when it is the right move | Ring lock fills; press 0.92 → 1.04 → 1.0 | soft tick per breath; clunk on press | Screen-edge VHS wobble preview | yes | Finger pointer | part (label in; breathe, ring, pointer todo) |
| **Rewind** | — | 66 ms freeze; path trails reel back; scanline bands | rewind whine; world muffled (800 Hz) | Camera holds, then snaps | yes | — | part (rewind 85 %; freeze, trails, muffle todo) |
| **Clone print** | — | Builds up from the feet in 0.35 s; floor ring | clone arpeggio (sound logo) | — | — | "YOU, 10 SEC AGO" tag | in (feet-up build under a scan band, floor ring, 60 ms stagger) |
| **Gus** | Boot prints of his next 2 s; key-ring jingle | "?" or "!" bubble pops | barks ("Hm?", "Hey!"); heartbeat on "?" | Head turns before body; lean in chase | yes on "!" | "That's Gus. Don't wake him." | part (mesh, beats, boot prints, flicker, nameplate, ?/! in; bark audio ids todo) |
| **Hide spot** | Soft outline when within 6 studs | "HIDDEN" chip; you dim 30 % | felt rustle | Curtain or coat sways | — | "Hide here when Gus comes." | part (chip in; world track: soft outline within 6 studs and the letter of a plate hidden inside over the hide in; sway todo) |
| **Till** (L5, time-locked) | Countdown on its face | Pops open; alarm light spins | till ding → alarm | Drawer slides out | yes | — | part (lock and countdown in) |
| **Busted (you)** | — | Cone flashes red; BUSTED stamp | whistle + stamp | 66 ms freeze; camera eases to Gus | yes | One line of advice | part (stamp in; freeze, camera todo) |
| **Busted (clone)** | — | Glitch slices; tape-ribbon burst (≤ 30 particles) | glitch crunch | Hands up | — | — | part (hands up, 3 glitch slices, ribbon burst 22 + 8 sparks in; glitch crunch todo) |
| **Buttons (all UI)** | — | Press 0.92 → 1.04 → 1.0 | soft tap; confirm present | — | — | — | part (0.92 pop in; overshoot in U1) |

**Forgiveness** (premium pattern 12, in the sim so clones stay deterministic): plate edge tolerance and a GRAB input buffer. Status: todo, phase 2. The numbers go in `Config.Sim`.
