# Review: how far "Heist Yourself" is from "Steam quality++" (2026-11-13)

An independent, harsh review by an art and game director. It was a read-only pass over the plans, PROJECT_STATE (through the AUDIO track), LEVELS §10-12, every contact sheet and golden frame, and the client FP, moment and intro code. **No Studio or phone capture exists.** Everything here judges Blender approximations and code, and that is finding #1.

## 1. Verdict: about 45 %

The plan's own diagnosis (§0) still holds: "I verified logic, not pixels." All 66 rows of `docs/QUALITY_BAR.md` are `open`, and none is `pass`. The self-scores (Bank 8.5, Corner Shop 8) grade proxy renders, which breaks the plan's own anti-gaming rules (random frames, blind pairs, kids first).

| Area | % | What I saw |
|---|---|---|
| Visuals | 60 | **Exteriors are good.** `big/L1_fp_street.png` (tenement, fire escape, awning, lamps, snow, light strings) is the best image in the repo. **Interiors are empty painted boxes:** `big/L1_fp_inside.png` holds a counter, a door, two pendants and a plate, and a white coffered ceiling is the brightest plane (L1_fp_ceiling median 0.59). The lamp pools are cream ellipses that dominate the diorama frames. **L1-L4 + DV01 share one shell** (`world2/contact_sheet.png`). |
| Characters | 55 | **The Rookie** (`rookie_sheet.png`) is original and reads at 48 px. But the sweater sits at the skin's value under warm light (`intro/shot_5.png`), and the FP arms are rigid closed fists. **Gus** (`gus_beats.png`) is strong. **Locomotion is the default R15 walk** (`Config.ECHO_WALK_ANIM`, the engine Animate), and the clones, the star of the game, walk in it. `golden/G2_party_wide.png` still shows blank pre-Rookie clones. |
| FP feel | 30 | The code is careful (assist cone, sim-range parity, line of sight, wall pull). But no human has held it, every number is a "first guess", and no frame shows hands + reticle + HUD + a clone together. |
| UI | 40 | The kit and tokens are in code but have never been seen on a screen. The display face, Luckiest Guy, is the most common Roblox-sim face (`type_specimen.png`; "JoB / SToLEN" reads as typos). In `golden/L6_vault.png` "VAULT 4/4" collides with the lamp dots and a railing hides a third of the frame. |
| Audio | 45 | 76/77 cues have ids, and none has been heard in context. Library music, no sound logo, no Gus voice, `GusStep` empty, RewindStinger a stand-in. |
| Moments | 50 | Spec and directors exist. Intro shots 1-4 are strong. **Shots 5-7 are near-black.** Hoardsworth is tiny in shot 2, and shot 3 is abstract streaks. The moments were authored for a top-down camera. |
| Onboarding | 35 | Pacing is proven by simulated kids only, with **0 real kid tests**. On first join, a 36.5 s intro comes before control, against G1 ★ "control ≤ 10 s". Two-thumb FP on a phone is new friction for 8-12 year olds. |
| Lobby / meta | 20 | LB is not merged. `big/GA_fp_spawn.png` is a hangar: one van, flat blue window squares, an empty floor, fog-blob pools. No wardrobe, no van choice. |
| Performance | high risk | ~333k tris in the busiest tier-1 view, tier 4 over its estimate, additive aurora when looking up, Future lighting, no mid-Android bench (I2). |

## 2. Top 15 gaps (ranked by player impact per effort)

### Needs the owner

**1. Capture real pixels before more art.**
- *Wrong:* the tone-map proxy is uncalibrated, and recipe A has been retuned three times blind.
- *Done:* six frames (L1 fp spawn, L1 diorama, 8 OF ME, L6 vault, garage spawn, intro shot 5) captured in Studio and on the phone, side by side with the renders. The proxy is refit and QUALITY_BAR graded for the first time.
- *Effort:* owner 2 h; agent 0.5 day.

**2. Kid test: FP vs diorama, on phones (Nov 15-16).**
- *Wrong:* FP shipped without a child holding it.
- *Done:* 5 kids split between the two cameras. Measure the first-clone and first-bank medians and "point to your clone".
- *Effort:* owner, 2 sessions; agent 0.5 day for a camera-split analytics flag.

**3. Audio audition and music identity.**
- *Wrong:* nobody has heard the mix, and library music has no ownable motif.
- *Done:* the AUDIO.md §13 audition and loudness (E7) are done. A 4-note clone-arpeggio sound logo plays at the title, the first clone, 8 OF ME and the Line-up.
- *Effort:* owner 2 h plus the commission (`docs/marketing/MUSIC_BRIEF.md`); agent 0.5 day.

### Fix in code or art now

**4. Re-shoot the golden frames for the game as it now plays.**
- *Wrong:* G1 is a diorama spawn, but fp is the default. G2 has pre-Rookie clones. A Nov 18 sign-off would approve the wrong target.
- *Done:* G1 = the FP L1 spawn with gloves, reticle, prompt chip, the cash in the window and the HUD. G2 = 8 OF ME with Rookies.
- *Effort:* 1 day.

**5. A "Crew View" peek.**
- *Wrong:* the fantasy is choreography, and from the eyes you see walls. Monaco works because you see everyone.
- *Done:* hold Tab / RB / an eye button to ease into the diorama with the cut-away while time runs and clone trails show; release to return to the eyes.
- *Effort:* 1.5 days (CameraDirector `diorama`, `presenting()` and CutAway already exist). Needs the owner's nod.

**6. Custom locomotion.**
- *Wrong:* the default R15 walk on a 4.6-stud chunky body, and every clone repeats it (C7 foot slide).
- *Done:* idle, walk, run, jump, fall and land authored for these proportions, shared by the clones.
- *Effort:* 2-3 days (keys uploaded like `CloneClips`).

**7. Fix the intro.**
- *Wrong:* shots 5-7 near-black (the first 30 s a new player sees), a tiny villain, an unreadable shot 3, 36.5 s long.
- *Done:* a lit garage (headlight key, cool rim), a medium close-up on Hoardsworth, readable presents into the vacuum, ≤ 22 s.
- *Effort:* 1.5 days (IntroPlan keys plus stage lights).

**8. Eye-level interiors.**
- *Wrong:* `L1_fp_inside.png` is empty. "One prop per room" (A7) was a diorama rule; in FP the mid-ground is what you stare at.
- *Done:* 6-10 visual-only props per room plus one hero prop, with sightlines to plates and loot unit-checked.
- *Effort:* 3-4 days (kit plus `LevelDress`, CanQuery off).

**9. Light pools and ceilings in FP.**
- *Wrong:* the unlit SurfaceGui pools read as painted fog at eye level (`GA_fp_spawn.png`) and don't light the actors in them. The ceiling outshines the walls.
- *Done:* pools fade with the view angle in fp, the real SpotLight carries the light, and the ceiling is ~0.6x the wall value.
- *Effort:* 1 day.

**10. FP hand poses.**
- *Wrong:* two rigid fists (`rookie_sheet.png` row 4), so you grab cash with a closed fist.
- *Done:* palm + finger block + thumb, with reach-open, grip, push-flat, point and a watch tap.
- *Effort:* 1.5 days (`rookie.py`, `--new`, the `Viewmodel` pose table).

**11. Finish the lobby.**
- *Wrong:* an empty warehouse, and the stations exist only as anchors.
- *Done:* filled van bays, a walk-up job board/laptop, a wardrobe mirror, the intro on the TV, and glazed windows.
- *Effort:* 3-5 days (LB). Panes and dressing first (0.5 day).

**12. A face per level.**
- *Wrong:* four levels plus a daily vault look identical in thumbnails.
- *Done:* each level gets one exterior signature (awning, sign, window display, roof prop) and one interior hero prop.
- *Effort:* 1.5 days.

**13. A drawn wordmark.**
- *Wrong:* typed Luckiest Guy fails I1 identity.
- *Done:* a vector logo with the cyan double exposure on the title, icon and thumbnails. Fix the glyph-case bug.
- *Effort:* 1 day; owner approves.

**14. Rookie value separation.**
- *Wrong:* the sweater ≈ the skin, so the head merges at 48 px.
- *Done:* a ≥ 15 % value step (A1).
- *Effort:* 0.5 day (palette cell, `--new`).

**15. Phone frame budget.**
- *Wrong:* tier 4 is over its estimate, there is no clone LOD, and the cost of looking up is unknown.
- *Done:* 16.6 ms in L6's busiest view and in the yard on a mid Android.
- *Effort:* 1 day for the LOD, plus an owner MicroProfiler run.

**Also cheap (0.5 day):** the `L6_vault` composition, and `big/L5_diorama_mid.png`, where the player is hidden behind a shelf (H2: CutAway should treat tall shelves as occluders).

## 3. Five things NOT to touch

1. **The sim, replay and server authority.** They are deterministic and the whole game. Nothing above needs `src/shared/Sim` or `src/shared/Levels`.
2. **The exteriors and the BIG cut-away.** They are the strongest visuals. Stop adding storeys and town; the effort belongs indoors.
3. **The aurora.** It is done. Only the Studio orientation check remains.
4. **Gus's beats.** Twelve read at 48 px. Add voice and steps, not geometry.
5. **Lighting recipe A.** Freeze it until #1 calibrates the proxy. Three blind retunes in two days is churn.

## 4. Risks: live worse than the renders

- **The tone-map proxy.** The ACES fit is assumed. A harder toe brings the black interiors back. The SpotLights point down, so the coffered ceilings that render bright will sit in shadow in the engine: FP "black from above". The unlit pools and Neon windows bypass lighting and may blow out. *Mitigation:* #1, and keep one capture per site beside each render.
- **StreamingEnabled.** `PauseOutsideLoadedArea` on the garage-to-heist teleport can flash the engine's pause UI during the van-door wipe. The `PersistentPerPlayer` level models now carry the Overhead (~400 instances per building), which grows the replicated set PERF measured before BIG. Facades outside the model can pop in storey by storey. *Mitigation:* a throttled join test on a phone; confirm the Overhead is parented in the level model.
- **First person on phones.** Drag-look can fight the thumbstick and buttons on 19.5:9. The prompt chip can sit under a notch. Head bob is on by default (kid motion sickness unknown). The 0.4-scale viewmodel risks near-plane clipping at wide FOV. The 2x/s own-body rescan can flicker after a respawn. Highlights plus additive Beams cost fill rate. *Mitigation:* #2 and #15; consider bob off by default on touch.
- **LoadAsset size drift.** In-place re-uploads already greyboxed a published build (v60). The fix now **scales a mismatched piece and keeps `report.ok`**: a loud failure became a silently stretched mesh. Re-uploads can re-enter moderation, and a failed load turns a level to greybox live. *Mitigation:* enforce `--new` in `kit_upload.py`, send live telemetry on size errors, and pin KitData per published build.
