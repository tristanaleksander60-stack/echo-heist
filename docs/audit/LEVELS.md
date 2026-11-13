# Level readability and visual quality audit (L1-L6)

_2026-11-12. Read-only audit of what the sim path (`Config.GAME_MODE = "sim"`, `Config.Heist.KIT_LEVELS = true`) builds for the six launch levels in Christmas dressing (the launch state). No game code was changed. The images are Blender reconstructions, not Studio captures. Anything that depends on the real Roblox renderer or camera is marked **[verify in Studio]**._

**How the images were made.** `python3 tools/blender/level_shots.py` (new) calls `lune run tools/blender/level_plan.luau` (new). That script compiles each level with `Sim/LevelSpec` and runs the server's own pure `Heist/KitPlan.plan` on `Kit/KitData`, with the same options `LevelBuilder`/`KitDresser` pass (dressing on; Clone Party becomes the Toy Shop). Every kit piece is placed from `assets/fbx` at KitPlan's pivot, yaw and per-axis scale. The script checks each piece against `KitPlan.partFrame`, and the maximum error is **0.0005 studs** on every level. The script also redraws the greybox the kit leaves visible (`LevelBuilder`: floor, cables, door lamps, loot stands, laser beams, van zone and WedgePart chevrons). It draws the client state as `WorldView`/`GusView`/`EchoView` would: idle plate rings in Vault Steel shade plastic, held plates and cables in the presser's hue, open doors slid up by `height - 0.4`, the vault skin swung -175°, and lasers off while their plate is held. Gus is the kit rig at `Guards.patrol(t = 0)` with his amber floor cone, clipped by a 12-ray fan. The player is the Rookie stand-in at spawn 1. Clones are cyan with the solo age ramp and a `●n` badge, standing where `tests/sim/Solutions.luau` leaves them.

The lighting is the `default.project.json` "Heist Night" recipe, approximated in Eevee: OutdoorAmbient (75,80,130) as the world, because the levels have no roofs, plus a dim moon with ColorShift_Top. There are **no local lights**, because the sim path places none. Bloom and ColorCorrection are applied in 2D afterwards.

The camera is Roblox's default (src/client sets no zoom): 12.5 studs, FOV 70, pitch 15°. The renders pull the camera in where the greybox colliders block it. Exact Roblox tone, AO and moon direction are not reproduced, so treat absolute brightness as ±30 %. The relative reads (what is brightest, what is visible, what links to what) are reliable, because positions come from the game's own code.

Per level there are seven images in `docs/audit/levels/`:

| Suffix | What it shows |
|---|---|
| `_1_spawn` | Third-person view at spawn, run 1 (nothing held, lasers on) |
| `_1b_spawn_clones` | The same camera, with the solution's clones on their spots |
| `_2_objective` | The player 5 studs inside the entrance, turned toward the goal loot (solved state) |
| `_3_plan` | Top-down planning view (B3: FOV 30), run 1 |
| `_3b_plan_solved` | The same view, solved |
| `_4_thumb` | View 1 at 160x90 |
| `_5_street` | The building from the street |

Overview: [`levels/contact_sheet.png`](levels/contact_sheet.png).

Re-run all of it with `python3 tools/blender/level_shots.py` (about 25 min on 4 CPU cores). Add `--daily` for the 12 vaults and `--only L3` for one level.

---

## 0. Verdict in one screen

**The kit is better than the levels.** Taken one at a time, the pieces are coherent, chunky, bevelled and on-palette (STYLE_BIBLE), and above typical Roblox quality. The levels built from them read as **a kit-dressed greybox**: shells, a floor, the gameplay boxes and the Christmas layer, and nothing else. There are no lights, no storytelling props and no street. Nothing tells a new player where to look.

At 160x90, **L1, L2, L3 and L4 are the same picture** ([thumbs](levels/contact_sheet.png), last column). Every spawn view puts the same storefront in front of you and the van's Neon zone under you. In all six spawn views, **73-85 % of the brightest 2 % of pixels are the van zone** at the bottom of the frame and the rest are fairy lights. The objective is never among them.

| | Goal visible / obvious from spawn | Plate → device link reads | Exit / van reads | Gus's gaze reads | Interactive vs decoration | Density / premium | Score /10 |
|---|---|---|---|---|---|---|---|
| L1 Back Room | No (behind a shut door, no window, no glint) | Only when held (idle cable invisible) | Too much (white slab under the camera) | n/a | Plate looks like floor trim; cash is a brown sack | Empty: 4 gameplay props in 1,485 sq studs | **3** |
| L2 Two Doors | No | **Misleading:** both cables merge into one line at x 0 | Same | n/a | Same; "Safe" is a sack on a stand | Empty | **2.5** |
| L5 Clone Party | **Yes** (gold candy and toys through the door) | n/a | Same | Partly (tiny cone in the office) | Loot reads; the till does not | Busiest, but the loot stands block the aisles | **5.5** |
| L3 Lights Out | No | **No:** plate B's cable vanishes into the east wall | Same | n/a | The laser reads (brightest thing in the plan) | Empty | **3** |
| L4 Night Clerk | No | Partly (A yes; B is under a coat rack) | Same | **Yes:** the cone is the strongest read; it leaks through walls | Hides look like furniture | Empty | **4** |
| L6 Big Score | No (vault about 70 studs in, 3 walls deep) | **No:** 4 cables share one spine; nothing says "need all 4" | Same | Yes, plus leaks | Lobby counters and hides read as furniture | Better shapes, same emptiness | **4** |

Reference bar: Monaco, Hitman GO and Sly Cooper all **light the objective and every interactive node** and keep decoration dimmer than signals. Roblox's best readable-at-a-glance games do the same: Doors (light is the path, and the door you need is lit and numbered), Piggy (colour-paired key → door) and Entry Point (lit objectives, outlined interactives). Our levels do the opposite. The brightest things are the van zone, the fairy lights and the laser. The plates, cables and loot are the darkest, flattest things in the room (LihFolk vault, *Level Design Principles*: "Avoid: the brightest object is decoration → light the objective").

---

## 1. Global findings (all levels)

**G1. There are no local lights at all, and the sim path regressed from v0.1.**
- `grep PointLight src` finds lights only in the v0.1 `src/server/LevelBuilder.luau` (Range 40, warm) and `src/server/Guard.luau`. `Heist/LevelBuilder`, `KitPlan` and `KitDresser` create none.
- `Lamp_Ceiling` is in the kit, with a manifest note "PointLight here, same colour, Shadows off", but KitPlan never places it.
- With Brightness 0.5 at ClockTime 0, the spawn views have a median luminance of **0.03-0.09** (0-1 scale) and a mean of 0.12-0.13. MASTERPLAN §6.1 promises "deep indigo with warm pools of light", and STYLE_BIBLE §3 says to fake pools "with a floor decal or a transparent Warm Marble disc". Neither exists.
- The LihFolk vault (*Lighting Untextured Art*) targets lit faces at 1.5-2.5x shadow faces. Here everything sits in the same ambient. That is why every image looks flat and the same.

**G2. Plates do not look like anything until someone stands on them.**
- `KitDresser` swaps the greybox pad for `Plate_4x4` and **destroys the greybox pad with its white Neon icon** (`old:Destroy()`), so the kit plate has no icon.
- `WorldView` draws the idle rim as Vault Steel shade `#4E5675` SmoothPlastic.
- The result is a dark steel square on a dark checker floor ([L1 plan](levels/L1_cs1_back_room_3_plan.png), [L2 spawn](levels/L2_cs2_two_doors_1_spawn.png): two grey specks at the doorway edges).
- MASTERPLAN §7.5 promises a "glowing plate with a cable to it" at 0-8 s. The plate does not glow, there is no letter, and the HUD text "Plate B turns the lasers off." (Hud `LEVEL_LINES`) refers to a letter the world never shows. This is also in WALKTHROUGH P0.

**G3. Cables only read when lit, and their routing lies.**
- Idle cables are 0.3 x 0.06, `#4E5675`, not Neon: invisible from the player camera and faint from above.
- Routing is always "along X at the plate's Z, then along Z" (`LevelBuilder.cable`), ending at the door centre or at `laser.maxX + 0.5`.
- The consequences: L2's two cables share x = 0 from z -8 to -20, so both plates appear to feed the first door ([L2 objective](levels/L2_cs2_two_doors_2_objective.png): a T junction). L3 and L6 laser cables run into the east wall and disappear ([L3 plan solved](levels/L3_cs3_lights_out_3b_plan_solved.png): a 2-stud stub). L6's four vault cables merge into one spine ([L6 plan solved](levels/L6_bk1_big_score_3b_plan_solved.png)).

**G4. The goal is never lit, framed or glinting.**
- Loot is the kit mesh on a 1.8-stud ink stand, with no sparkle, light or label. STYLE_BIBLE §6.2 says "Heist Gold = sparkle". MASTERPLAN §7.5 says "cash glittering through glass".
- In L1-L4 the goal is a **brown CashBag** on a dark stand, behind a shut door. "Safe" (L2), "Register" (L3) and "NightDeposit" (L4) are all the same sack, while the kit has `Safe` and `CashRegister` unused for them.
- Only L5's gold candy reads as loot from the door.

**G5. The spawn camera is jammed into the van, and the van zone dominates the frame.**
- The spawn is z 14 with the van zone at z 16..24 and the kit van at z 24.96..32.04 (top y 7.69).
- No zoom is set, so the default camera (12.5 studs, about 15° down) sits at z 26.1, y 7.7: on the van's roof line. The renders, which pop on the greybox van body, put it at 10.4 studs.
- Roblox's Popper probably ignores the invisible (Transparency 1) greybox body, and the kit van has CanCollide off, so in Studio the camera may sit inside the roof **[verify in Studio]**.
- Either way, the bottom third of every spawn frame is the **VanZone**: Neon Getaway White at Transparency 0.6, with three WedgeParts that read as bars, not arrows.
- MASTERPLAN §3.5 (zoom 16, min 8, max 28, wall fade to 0.7) is not built.

**G6. Open doors and shutters float above the walls (a visible bug).**
- `WorldView` opens every door by moving the leaf **up** `height - 0.4` (9.6 studs). The leaf then spans y 9.6..19.6 above a 12-stud cut-away wall. See the dark slab over every open door in the `_2_objective` shots.
- Worse, the alarmLock street doors are open all night, so the **shutter hangs 7.6 studs above the storefront like a billboard** ([L5 street](levels/L5_cs5_clone_party_5_street.png), [L6 street](levels/L6_bk1_big_score_5_street.png)). That is exactly where the Crew Line-up street camera looks.
- The kit spec says something else: "Pocket door: slides 6 studs into the wall on its hinge side" and "`Shutter_8x10` rolled up = `Size.Y` 0.35" (STYLE_BIBLE §5.2, KIT_IMPORT).

**G7. Every Corner Shop level has the same first room.**
- Same shell, same storefront, the counter in nearly the same place, and plate A at (10, -8) in L1, L3 and L4.
- From spawn and at thumbnail size, L1-L4 are indistinguishable ([contact sheet](levels/contact_sheet.png)). A player can't tell they progressed, and a TikTok viewer can't tell the levels apart.

**G8. Most of the kit is unused.**
- Never placed by KitPlan in any launch level or daily vault: `Lamp_Ceiling`, `Safe`, `Gus_DonutBox` (STYLE_BIBLE's "one storytelling prop per room"), `Shelf_8x2`, `Hide_Curtain`, `TellerCounter_8x4`, `Wall_Window_8x12`, `Pedestal_Diamond`/`Diamond`.
- Density is 0.27-0.48 gameplay props per 100 sq studs in L1-L4 and L6, and **zero** decoration props.
- The only dressing is the Christmas layer: garlands, fairy lights, wreath and snow. It is brighter than any signal.

**G9. Hides don't look like hides, and nothing marks them as interactive.**
- The coat rack, crate, plant, deposit stacks and coat stand are plain furniture, and the greybox frame and translucent cover are removed on dress.
- Plates under hides (L4 B, L6 A-D) are found by accident (WALKTHROUGH §2.6).

**G10. Gus's cone reads well, but leaks.**
- Where Gus exists, the amber floor fan is the clearest signal in the level ([L4 plan](levels/L4_cs4_night_clerk_3_plan.png)).
- With 12 rays, the wedge between a ray that passes a doorway and one that hits the wall is drawn **over the wall into the next room** ([L4 solved](levels/L4_cs4_night_clerk_3b_plan_solved.png): amber triangles in the shop and the safe room; [L6](levels/L6_bk1_big_score_3_plan.png): over plate C). That tells a kid "Gus sees you there" when he cannot.
- Gus himself is small and dark and is never visible from spawn.

**G11. The street is a void.**
- A plum slab in indigo haze ([street shots](levels/L1_cs1_back_room_5_street.png)): no road, kerb, street lamp, neighbours or sign text. The storefront's sign band is blank.
- In L6, the fenced service alley gets **interior** floor tiles and 12-stud interior walls with garlands, so it reads as a corridor, not an alley (KitPlan floors the whole wall footprint, and the fence walls tile as `Wall_8x12`).

**G12. The door state lamp is the only device signal, and it is small.**
- `LevelBuilder` adds a 0.8-stud ball at the door's top, on the +Z face only: about 10 px at 1280x720 from the entrance and about 1 px in the thumbnail.
- Nothing on a door says which plate drives it, or (L6) how many plates are needed.

---

## 2. Per level

### L1 "Back Room" (FTUE)

![L1 spawn](levels/L1_cs1_back_room_1_spawn.png)
![L1 toward the goal](levels/L1_cs1_back_room_2_objective.png)
![L1 plan](levels/L1_cs1_back_room_3_plan.png) ![L1 thumb](levels/L1_cs1_back_room_4_thumb.png)

Also: [spawn with clone](levels/L1_cs1_back_room_1b_spawn_clones.png), [plan solved](levels/L1_cs1_back_room_3b_plan_solved.png), [street](levels/L1_cs1_back_room_5_street.png).

- **At spawn** you see a storefront, a shut wooden door at the back with a tiny red dot, and the white van slab under the camera. Plate A (10, -8) is hidden behind the right window. The cash (0, -28) is behind a solid wall, so MASTERPLAN §7.5's "cash glittering through glass" is not possible: the z -20 partition has no window.
- **On the plate (solved)** the link finally reads: the clone glows, the cable lights cyan to the door, the door lamp turns green, and the cash bag shows through the doorway. But the door leaf floats above the wall (G6), and the cash is a dark brown sack, about 25 px tall at 720p.
- **Density:** one counter in a 32 x 44 room. The back room is a bare box with one stand.
- **Top issues:**
  1. The plate is invisible and unlit at 0-8 s (G2).
  2. The cash is not visible or glinting from the front room (G4; no window).
  3. The spawn frame is dominated by the van zone and pinned to the van (G5).

### L2 "Two Doors"

![L2 spawn](levels/L2_cs2_two_doors_1_spawn.png)
![L2 toward the goal](levels/L2_cs2_two_doors_2_objective.png)
![L2 plan](levels/L2_cs2_two_doors_3_plan.png) ![L2 thumb](levels/L2_cs2_two_doors_4_thumb.png)

Also: [spawn with clones](levels/L2_cs2_two_doors_1b_spawn_clones.png), [plan solved](levels/L2_cs2_two_doors_3b_plan_solved.png), [street](levels/L2_cs2_two_doors_5_street.png).

- **The level's whole lesson is "this plate → that door", and the world draws the opposite.** Both cables run to x 0 and then share one line north, forming a T in front of the first door. Plate B's cable passes under the BackRoom door to reach the Stockroom. Both plates and both cables turn the same cyan in solo.
- The doors are identical, with no letters, and the second door (z -32) is only visible once the first is open.
- The "Safe" is a sack on a stand at (0, -40). The kit `Safe` is unused.
- The middle room (z -20..-32) is an empty corridor.
- **Top issues:**
  1. The cable routing implies the wrong mapping (G3).
  2. No A/B identity on the plates or doors (G2, G12).
  3. The goal doesn't read as a safe, and it is unlit (G4).

### L5 "Clone Party" (third in play order)

![L5 spawn](levels/L5_cs5_clone_party_1_spawn.png)
![L5 toward the goal](levels/L5_cs5_clone_party_2_objective.png)
![L5 plan solved](levels/L5_cs5_clone_party_3b_plan_solved.png) ![L5 thumb](levels/L5_cs5_clone_party_4_thumb.png)

Also: [spawn with clones](levels/L5_cs5_clone_party_1b_spawn_clones.png), [plan](levels/L5_cs5_clone_party_3_plan.png), [street](levels/L5_cs5_clone_party_5_street.png).

- **This is the best read of the six.** Gold-wrapped candy and toys on rows through the door say "a shop full of loot" at once. The Toy Shop gondolas give the room a silhouette.
- **But** every loot item sits on its own 1.8-stud ink stand **in the aisle**, beside the shelf instead of on it. Each 6-stud aisle keeps a 1.2-stud gap between two rows of pedestals, and clones visibly walk through the stands, which are visual only. It reads as cluttered and fake.
- The **till**, the level's top loot and the Alarm Run trigger, is a register on the floor at (-8.5, -1), **outside** its counter box (KIT_IMPORT fit table). It has no light, and its "LOCKED 0:07" label is distance-limited. From the entrance it hides behind the player ([objective](levels/L5_cs5_clone_party_2_objective.png)).
- Gus dozes facing the office's back wall, and his cone is a 4-stud sliver.
- The open shutter floats above the storefront (G6). The shutter's green "open" lamp sits in the middle of the wreath, so the wreath appears to glow green.
- **Top issues:**
  1. The loot belongs on the shelves, not on aisle pedestals.
  2. The till is not staged as the finale: off its counter and unlit.
  3. The floating shutter (G6) is in the Line-up street shot.

### L3 "Lights Out"

![L3 spawn](levels/L3_cs3_lights_out_1_spawn.png)
![L3 plan](levels/L3_cs3_lights_out_3_plan.png)
![L3 plan solved](levels/L3_cs3_lights_out_3b_plan_solved.png) ![L3 thumb](levels/L3_cs3_lights_out_4_thumb.png)

Also: [spawn with clones](levels/L3_cs3_lights_out_1b_spawn_clones.png), [toward the goal](levels/L3_cs3_lights_out_2_objective.png), [street](levels/L3_cs3_lights_out_5_street.png).

- From spawn, the level looks exactly like L1.
- The laser grid (z -34) is the brightest object in the plan, which is right for a hazard. **But plate B (12, -26), the plate that turns it off, has a cable that runs 4 studs east into the wall** (`deviceCenters` uses `laser.maxX + 0.5 = 16`, the wall line) and is never seen again. The HUD line names "Plate B", and nothing in the world is called B.
- The "Register" is a sack on a stand. The kit `CashRegister` is only used for top Cash loot.
- **Top issues:**
  1. There is no visible link from plate B to the grid (G3).
  2. No letters, but the text uses letters (G2).
  3. The first room is identical to L1 (G7).

### L4 "Night Clerk"

![L4 plan](levels/L4_cs4_night_clerk_3_plan.png)
![L4 plan solved](levels/L4_cs4_night_clerk_3b_plan_solved.png)
![L4 toward the goal](levels/L4_cs4_night_clerk_2_objective.png) ![L4 thumb](levels/L4_cs4_night_clerk_4_thumb.png)

Also: [spawn](levels/L4_cs4_night_clerk_1_spawn.png), [spawn with clones](levels/L4_cs4_night_clerk_1b_spawn_clones.png), [street](levels/L4_cs4_night_clerk_5_street.png).

- **Gus's cone is the best signal in the launch set.** You can see what he sees from above and through the open door ([objective](levels/L4_cs4_night_clerk_2_objective.png): the amber fan on the back-room floor).
- With both doors open, the 12-ray wedges paint amber **over the partition walls** into the shop and the safe room (G10).
- Plate B sits inside the coat rack's niche (-12, -23). Its cable is lit only when held. The rack itself looks like furniture, with nothing that says "walk in here".
- Gus's post has no prop: no desk, lamp or donut box.
- **Top issues:**
  1. Hides and the plate under the rack are not signposted (G9, G2).
  2. The cone leaks through walls (G10).
  3. The front room is again identical (G7), and the goal is again a sack behind two doors.

### L6 "The Big Score: Bank"

![L6 spawn](levels/L6_bk1_big_score_1_spawn.png)
![L6 toward the goal](levels/L6_bk1_big_score_2_objective.png)
![L6 plan](levels/L6_bk1_big_score_3_plan.png)
![L6 plan solved](levels/L6_bk1_big_score_3b_plan_solved.png) ![L6 thumb](levels/L6_bk1_big_score_4_thumb.png)

Also: [spawn with clones](levels/L6_bk1_big_score_1b_spawn_clones.png), [street](levels/L6_bk1_big_score_5_street.png).

- **The bank front has a real silhouette** (columns and pediment, with the vault glimpsed down the x 0 axis once all doors are open). In the objective shot, the lit cable spine accidentally becomes a leading line to the vault. That is the right idea, by accident.
- **What doesn't work:**
  - Four plates, three of them under furniture, feed one shared cable spine. The vault frame shows no "0/4 … 4/4" state.
  - Plate B (under the fern, west wall) sends its laser cable **east** across the whole hall to x 20, then into the east wall.
  - The open vault door rests on plate C and WestStack (KIT_IMPORT fit table, still open).
  - The lobby counters are the shop's `Counter_8x2` (the kit's `TellerCounter_8x4` with its glass screen is unused). The TellerDesk hide (-12, -10) has no cover piece.
  - The gold is about 70 studs from spawn, behind three walls, with no light.
  - The fenced alley looks like an interior corridor (G11). The shutter floats above the pediment (G6).
- **Top issues:**
  1. The "need all 4" rule is invisible: no per-plate lamps on the vault and no distinct cables (G3, G12).
  2. Cable routing for B and the vault (G3).
  3. No hero lighting on the vault and gold, and no lobby → vault sightline staging (G1, G4).

---

## 3. Comparison, honestly

| | Heist Yourself today | Monaco / Hitman GO / Sly Cooper | Top Roblox (Doors, Piggy, Entry Point, Jailbreak robberies) |
|---|---|---|---|
| Where to go | Text line only (6 s) | Hitman GO: the goal tile is flagged and visible from move 1. Monaco: the floor plan with an icon on every objective | Doors: the next door is lit and numbered. Entry Point: objective outline and marker |
| What a switch does | Same-hue cable that merges or hides in walls | Hitman GO: everything sits on visible node lines. Sly: interactives sparkle blue | Piggy: the red key fits the red door (colour pairing) |
| Light | None, uniform ambient | One key light plus pools, so objectives sit in light | Lit paths, dark sides |
| Density | Shell plus gameplay boxes | Every room has a purpose prop and a storytelling prop | Dense props, layered silhouettes |
| Thumbnail read (160x90) | The same storefront x4, a white slab | Single strong focal point | Saturated, one hero |

The art style (STYLE_BIBLE "Neon-Noir Diorama", which explicitly cites Hitman GO and Monaco) is right. The levels skip the two cheap things those references rely on most: **a lit focal point per room** and **a visible, unambiguous link from every switch to its device.**

---

## 4. Prioritized fixes

Tuning numbers go in `src/shared/Config.luau` (CLAUDE.md). Level-data changes (new solids, moved plates) must keep `lune run tests/run_sim.luau` green and update `tests/sim/Solutions.luau` where a position moves. Positions are level space (Roblox studs; floor y 0, walls 12).

### P0: before launch (comprehension and visible bugs)

**P0-1. Plates glow idle and carry a letter, and their devices carry the same letter.**
- **`src/server/Heist/KitDresser.luau` (plate swap):** keep a plate icon after the swap. Either move the greybox `Icon` to the kit plate before `old:Destroy()`, or add a `SurfaceGui`/`Decal` with the plate's `def.id` letter in Getaway White on the top face (y 0.36).
- **`src/client/Heist/WorldView.luau` (plates, idle):** rim in Neon **Bulb Warm `#F6C0A2`** at 50 % transparency, with a slow breathe (≤ `BLINK_HZ_MAX`, steady under reduced motion). On press it turns the clone hue. Bulb Warm is already the audited N1 idle for lamps and fairy lights: Oklab 0.207 / 0.274 / 0.389 / 0.152 from clone P1-P4 (`eh_palette.ok_dist`). Warm Marble `#D8C8A8` would be 0.150 from Ghost White and 0.086 from Torch Amber, so don't use it. Add it to `eh_palette.NEON` and re-run `python3 tools/blender/eh_palette.py`.
- **`src/server/Heist/LevelBuilder.luau`:** a letter plaque, a 1.6 x 1.6 steel disc with an ink letter, on each device the plate drives:
  - on the door frame header face, next to the lamp at (door cx ± 2, 10.8, line + 0.6), on both faces;
  - on the laser's near post at 7 studs high.

**P0-2. Visible, honest cables.**
- **`LevelBuilder.cable`:** make idle cables 0.5 wide in Vault Steel `#7C86A6`. Route each one to the device's **near jamb** (door: x = cx ∓ 3.5 on the plate's side; laser: the end post nearer the plate, i.e. `minX - 0.5` when the plate's x < laser centre), not the centre.
- **Offset parallel trunks** by plate index (x = -1.5, -0.5, 0.5, 1.5) so they never share a line.
- Keep cables **1.5 studs off any wall line**: kit walls cover the wall band.
- Concretely:
  - **L2:** A runs from (-10, -8) along z -8 to x -2.5, then to the west side of the BackRoom doorway (-2.5, -19). B runs from (10, -8) along z -8 to x 2.5, then along x 2.5 **through** the BackRoom doorway to the east side of the Stockroom doorway (2.5, -31). The two lines never touch, and B's visibly passes the first door.
  - **L3:** B runs from (12, -26) straight along x 12 to z -32.5, just in front of the grid, then along z -32.5 to the east post's base at x 15. Today it stops at (16, -26), inside the east wall.
  - **L6:** B runs from (-16, -18) along x -16 to z -32.5, then to the grid's **west** post (-19, -32.5). A, B, C and D enter the vault frame at x -1.5, -0.5, 0.5, 1.5.

**P0-3. Light the objective, the plates and each room.**
- **New `lamp` role in `src/server/Heist/KitPlan.luau`**, placed by `KitDresser`: `Lamp_Ceiling` (pivot at y 12) plus a `PointLight` on `Lamp_Ceiling_Bulb`. Use Bulb Warm `#F6C0A2`, `Shadows = false`, with Range/Brightness from a new `Config.Heist.LAMP = { range = 16, brightness = 1.2, heroRange = 22, heroBrightness = 2.2, heroShadows = true }`.
- Each lamp also gets a **Warm Marble disc** (Transparency 0.7, 10 wide, y 0.03) under it. This is the phone/no-shadow pool from STYLE_BIBLE §3.
- **Rules:** one lamp per plate (directly above it); one **hero** lamp (the only one with shadows, ≤ 4 per view) over the goal loot; one per room centre without either.
- **Positions:**

| Level | Lamps |
|---|---|
| L1 | (10, -8) plate; (0, -28) hero; (-10, -2) counter |
| L2 | (-10, -8), (10, -8) plates; (0, -26) middle room; (0, -40) hero |
| L3 | (10, -8), (12, -26) plates; (0, -40) hero; the grid keeps its own glow |
| L4 | (10, -8), (-12, -23) plates; (13, -30) Gus's post; (0, -42) hero |
| L5 | (-4, -14), (4, -14) aisles; (-12.5, -1) till hero; (0, -34) office desk lamp |
| L6 | (-12, -10), (-16, -18), (-13, -42), (13, -42) plates; (0, -6) lobby; (0, -24) hall; (0, -55) gold hero (spot down); (0, -42) scale room |

**P0-4. The goal reads as loot from where you stand.**
- **`WorldView` (loot at Home):** a Heist Gold sparkle (BillboardGui star or 2-3 Neon facets, ≤ 3 flashes/s) on every item of value ≥ 100 and on `top` items. Add a light shaft or a hero lamp (P0-3) over the goal.
- **Use the right displays.** Add an optional `display = "Safe" | "CashRegister" | "Counter"` field to loot specs and teach KitPlan to place the display under it. Then:
  - L2 `Safe` at (0, -41.5) against the back wall, on `Safe`;
  - L3 `Register` at (0, -40), on a `CashRegister` on a `Counter_8x4`;
  - L4 `NightDeposit` at (0, -42), on `Safe`.
- **L1:** let the player see the cash. Add `kit = "window"` support for solids in `KitPlan` (tile `Wall_Window_8x12` on those runs). In `src/shared/Levels/L1_BackRoom.luau`, mark the two partition solids at z -20 (x -16.5..-3 and 3..16.5) as windows. L1 has no Gus, so the glass doesn't change any sight rules. This delivers MASTERPLAN §7.5's "cash glittering through glass".

**P0-5. Fix the floating doors and shutters.**
- **`src/client/Heist/WorldView.luau` (door update):** open `Wall_Door_8x12_Leaf` doors as **pocket doors**, sliding `height`-wide along the wall run toward the hinge side (STYLE_BIBLE §5.2), not up.
- Roll `Shutter_8x10` up by `Size.Y` (top pinned, 10.35 → 0.35) as KIT_IMPORT specifies.
- This removes the slab over every open door and the "billboard" shutter in L5 and L6. It also matters in the Line-up street shot (MASTERPLAN §6.6).

**P0-6. Spawn framing and the van zone.**
- **Client camera module:** on run start, set `CameraMinZoomDistance` 8, `CameraMaxZoomDistance` 28, zoom 16 and pitch 20°, facing the shop (MASTERPLAN §3.5). Add the wall fade.
- **`LevelBuilder` / `WorldView` VanZone:** Transparency 0.85, no Neon, while the local player is not carrying loot. Light it fully, with true arrow meshes or decals pointing at the van (not 0.08-tall WedgeParts that read as bars), only while carrying.
- **[verify in Studio]** where the default camera ends up at spawn (z 26.1, y 7.7 vs the van roof at y 7.69). If it clips into the van, move the van 4 studs back in `Shop.VAN` (z 20..28 is a data change; Line-up z 28 is already an open item in MASTERPLAN §6.6) or start the camera with pitch 25°.

### P1: launch quality (density, identity, signposting)

**P1-1. Give each Corner Shop level its own first room.** Add new solids in `src/shared/Levels/L1..L4`, each a `Shelf_8x2` box 2 x 7.85 x 8 against a wall, which KitPlan already dresses as `Shelf_8x2` (`h >= 5`, `short <= 3`). All boxes below keep 2+ studs from every plate, door gap, loot point and Gus route. Check them with `lune run tests/run_sim.luau`.
- **L1:** west wall x -15.5..-13.5, z -18..-10; east wall x 13.5..15.5, z -18..-12; `Gus_DonutBox` on the counter at (-10, 3.5, -2) (visual, the room's storytelling prop).
- **L2:** east wall x 13.5..15.5, z 0..8; west wall x -15.5..-13.5, z -18..-12; middle room both walls x ±(13.5..15.5), z -30..-22.
- **L3:** east wall x 13.5..15.5, z 0..8; back room **west** wall only, x -15.5..-13.5, z -30..-22. Plate B at x 10..14 rules out the east wall there.
- **L4:** Gus's desk as a low counter, x 12.5..15.5, z -34..-32, `sight = false` (it is behind him at his first stop), with the donut box and his post lamp (P0-3).

Don't use hide pieces (`Hide_Crate`, `Hide_CoatRack`) as decoration: that breaks "interactive vs decoration" (G9). Also give each level a different counter position, or a sign colour from the location atlas. The aim is a different silhouette in the spawn view, so the four thumbnails stop being the same image.

**P1-2. Hide affordance.** In `LevelBuilder`, keep a Warm Marble floor outline (0.2-wide frame at y 0.03) of every `EH_Hide` volume. In `WorldView`, add a "◐" billboard within 12 studs. L4's plate B and L6's B/C/D then read as "go in there". For L6 TellerDesk, add the missing cover piece (`Hide_DepositStack`, open side to the counter; KIT_IMPORT).

**P1-3. L6 "need all 4" readout.** In `LevelBuilder`, put 4 lamps in a row on the vault frame's front face, at x -3, -1, 1, 3, y 10.5, z -47.3, lettered A-D. Each one turns the presser's hue while its plate is held (in `WorldView`, from the same plate attributes). Use `TellerCounter_8x4` for the lobby counters (KitPlan: `party == false and location == "Bank"` → TellerCounter). Move plate C and the WestStack hide 3 studs toward the street, to z -39 (plate box z -41..-37), so they leave the vault door's resting footprint (z -46.8..-42.25; KIT_IMPORT fit table). Update `Solutions.bk1_big_score`.

**P1-4. L5 loot on the shelves.** In `src/shared/Levels/L5_CloneParty.luau`, change the shelf loot x to `x ± 1.4` with `y = 3`. In `KitPlan`/`LevelBuilder`, skip the ink stand when the loot point lies inside a shelf solid's footprint ± 0.5 (the gondola is the dark display). Move the till onto the counter: the counter box is -15.5..-10, so put the till at (-12.5, -1) and widen the counter box to x -15.5..-9 (KIT_IMPORT fit-table item). Give it the hero lamp (P0-3).

**P1-5. Gus's cone without leaks.** In `src/client/Heist/GusView.luau`, use 24 rays (or 12 plus 1 extra ray at each solid corner inside the fan), and draw each wedge only to the shorter of its two rays (no wedge spans a hit/miss boundary). The cost is still 10 Hz.

**P1-6. Street dressing** (a new `street` pass in KitPlan, visual only):
- a kerb and road strip at z 12..34 (two `Floor_8x8` runs in a street atlas cell);
- one street lamp with a real PointLight at (-9, 0, 15), so the spawn stands in a warm pool;
- a painted shop sign in the storefront's empty sign band (emissive mask, not Neon; the 3-SurfaceAppearance budget allows it);
- 2 dark backdrop facades at x ±40.

For L6, floor the alley with a street cell and use a low fence piece instead of `Wall_8x12` for the lot fence.

### P2: polish

- **P2-1.** Make the Christmas layer dimmer than the signals: fairy lights at Neon Transparency 0.3, and never above a plate or a door lamp (STYLE_BIBLE §13 "never over a laser post" extended to every signal).
- **P2-2.** Door lamps: a 1.6 x 0.6 bar on both faces of the frame instead of a 0.8 ball on one face.
- **P2-3.** One storytelling prop per room (STYLE_BIBLE §5 rule), e.g. a mop bucket, a staff calendar or a lost teddy. Put them in `Levels/*` as `props = {...}` data, placed by KitPlan as visual only.
- **P2-4.** A Planning camera (MASTERPLAN §3.5, "simple version at launch") does not exist. `3_plan` shows what it would see. Even the simple version needs P0-1/P0-2 to be useful.
- **P2-5.** Re-run `tools/blender/level_shots.py` after each fix as the regression check. Spawn-view brightest-2 % should land on the plate, the goal or a lamp, not the van zone. Then confirm with Studio B1/B2 screenshots (STYLE_BIBLE §7).

---

## 5. What already works (keep it)

- The kit pieces: trims continue across modules, bevels catch light, and the Bank front has a real silhouette.
- Lit cables and clone glow **when active**. The 1b/2/3b shots read clearly; the problem is the idle state.
- Gus's amber cone (L4, L6).
- L5's gold loot rows seen through the door.
- The laser grid's red against the indigo.
- Placement maths: every kit piece lands within 0.0005 studs of KitPlan's frame, with no gaps or z-fighting in any render.

---

## 6. After phase 1 (light and levels track, 2026-11-12)

Re-rendered with `python3 tools/blender/level_shots.py --only L1|L2|L5 --samples 12 --out docs/audit/levels/after` (R2: Blender, not Studio). The tool now draws recipe A "Moonlit Diorama" (default.project.json), every `KitPlan.lamps` light with its unlit floor pool and `Lamp_Ceiling`, idle plates in Bulb Warm with their letter, the device letter discs, `KitPlan.cables`, pocketed doors and rolled-up shutters, the dim van zone with arrows, the goal sparkle, the L2 `Safe` display and L1's partition windows. Plan views hide the ceiling fixtures (a planning camera fades them). Overview: [`levels/after/contact_sheet.png`](levels/after/contact_sheet.png).

| Level | Spawn-view luminance, median (before → after) | What changed on screen | Score before → after |
|---|---|---|---|
| L1 Back Room | 0.086 → 0.170 | Van slab gone (dim zone + arrow); plate A glows with its letter in a warm pool; the cash glints through the new windows beside the door, under the hero lamp; door pocketed (no slab over the wall); "A" disc by the door lamp | **3 → 5.5** |
| L2 Two Doors | 0.086 → 0.170 | Two separate cables, B visibly passing the first door (no T); A/B letters on plates and doors; the goal sits on a `Safe` under the hero lamp; middle room and tip jar lit | **2.5 → 5.5** |
| L5 Clone Party | 0.083 → 0.178 | No floating shutter in the street shot; aisle and office lamps with pools; the till under its hero lamp; van zone no longer the brightest thing | **5.5 → 6.5** |

Still open (needs sim level data or later phases): spawn framing and the camera (P0-6, C0), the till on its counter and loot on the shelves (P1-4), every Corner Shop level's own first room (P1-1), street dressing and the backdrop (P1-6, W4), and the sky faces upload (the renders show the plain night sky the Sky node gets once `assets/sky/` is uploaded; Studio draws Roblox's day faces until then).

## 7. World track: backdrop, snow and signature silhouettes vs the golden frames (2026-11-12)

Rendered with `python3 tools/blender/level_shots.py --golden --samples 32` (R2: Blender, not Studio; `tools/blender/backdrop_shots.py` draws the same `Shared/Heist/BackdropPlan` the client builds, the uploaded Heist City sky faces as the camera-ray world, `Config.Backdrop.SNOW.maxAlive` flakes over the camera focus and a depth-pass haze for the Atmosphere). Files: [`levels/golden/G1a_diorama.png`](levels/golden/G1a_diorama.png) (pitch 50, distance 28, FOV 42), [`G1b_classic.png`](levels/golden/G1b_classic.png) (16 studs, FOV 70, pitch 15, 30 degrees right of the spawn axis so the van is at frame left), [`G2_party_wide.png`](levels/golden/G2_party_wide.png) (8 OF ME, pitch 55), each with a 160 x 90 thumbnail.

| Frame | Median sRGB luma | Warm share | Glow share | Score vs GOLDEN_FRAMES (0-10) |
|---|---|---|---|---|
| G1a diorama | 0.213 (R2 L1 spawn was 0.170) | 4 % (target about 60 %) | 1.5 % | **5.5** |
| G1b classic | 0.212 | 3 % | 9.0 % | **6.5** |
| G2 party wide | 0.204 | 3 % | 3.6 % | **6** |

**What reads now.** A snowy night street instead of a void: falling snow, snow on the awnings' upper slope and the sills, the striped awnings framing the door, amber (Corner Shop) and pink (Toy Shop) window light spilling onto the pavement, neighbour facades with lit windows either side of the shop, and in the classic view **the Snow Globe on Hoardsworth's tower rising over the shop roof** (burgundy and gold, full of stolen presents). Plate A and its letter read through the right display window. In G2 the giant toy drummer is the clear signature silhouette in the front corner, the room lamps tint the floor candy pink and gold, the crew of 8 sits in the central third under the stamp, Gus is in the back office.

**Self-critique (honest).**
- **Warm share 3-4 %, not 60 %.** The world is still indigo; the location colour only lives in the room-lamp pools and the window spill. Warm area needs W3/W5 work outside this track: warm rugs in the pools, warmer interior walls (the Corner Shop atlas), a warm street lamp pool (GOLDEN G1 lists one; there is no street lamp piece yet).
- **The van is the brightest thing in G1b** (Getaway White body and zone): a van/camera call (C0, LEVELS P0-6), not the backdrop's.
- **No cash glint from the spawn** in either G1 view: the counter is behind the left wall (camera C0 / level W5).
- **The diorama camera (G1a) never sees the sky:** at pitch 50 and FOV 42 the frame's top edge is 29 degrees below the horizon, so the landmark and skyline show only in the classic camera, the street and the garage. If the owner picks the diorama default (D5), the landmark needs a second, in-world read (a Hoardsworth billboard on a neighbour facade, say).
- **Facade windows render near-white** (Neon Bulb Warm + bloom). In Studio Neon keeps more of its colour; check, and make them smaller or dimmer if they still read as slabs.
- **Render-only artefacts:** the spill is drawn in 6 bands (the game uses a UIGradient); flakes are icospheres (the game uses the uploaded soft dot); the clones are the stripped stand-in, not avatars (clone track).
- **G2 compromises:** pitch 55 instead of about 45 (at 45 the 12-stud front wall hides the crew's legs unless they stand among the shelves); the world is not dimmed 15 %; the stamp is not the chosen display face. The pull-back camera and the stamp are the camera and HUD tracks'.

**[verify in Studio]** the sky orientation (Ft = Roblox -Z, so the tower stands behind the shop from the spawn; `Config.Backdrop.SKY_LANDMARK_YAW` / `SKY_TURN` fix it in one number), the awning snow slabs' fit on the slope, the spill gradient's direction (bright at the wall), the rings' haze at 300 / 600 studs under Atmosphere 0.28, and the snow's look with the uploaded flake texture.

## 8. Golden pass: warm interiors, the van, garage v1 (2026-11-12)

Rendered with `python3 tools/blender/level_shots.py --golden --samples 32` (G1a, G1b, G2) and `--garage --samples 32` (G3); R2: Blender, not Studio. G1a now uses the game's own diorama camera (`Config.Heist.CAMERA.DIORAMA`: pitch 52, distance 30, FOV 45, the focus leading you into the lower third by `CameraMath.lead`), not the old 50 / 28 / 42 centred shot; G1b and G2 keep §7's cameras; G3 is `CAMERA.GOLDEN.G3` on the part named `Van`, as `Heist/GoldenShots` stages it. Files: [`levels/golden/G1a_diorama.png`](levels/golden/G1a_diorama.png), [`G1b_classic.png`](levels/golden/G1b_classic.png), [`G2_party_wide.png`](levels/golden/G2_party_wide.png), [`G3_garage.png`](levels/golden/G3_garage.png), each with a 160 x 90 thumbnail; the numbers are in [`levels/golden/grades.json`](levels/golden/grades.json).

**How it is measured** (`tools/blender/frame_grade.py`, run on every golden frame by `level_shots.py`): **warm share** = the share of pixels of the finished frame (after haze, bloom and vignette) whose sRGB red exceeds blue by at least 8 levels and whose luma is at least 0.06. This reproduces §7's numbers on §7's own files (4.1 / 2.8 / 2.5 %, reported there as "3-4 %"). **Brightest element:** a Workbench pass renders every element group in a flat ID colour with occlusion (van, van zone, cash and loot displays, plates, lamp bulbs, the job board, rugs); the grader gives each group's 95th-percentile luma and which group owns the brightest 1 % of the frame.

| Frame | Warm share: §7 file → same camera before this pass → now | Median luma | Brightest-element check | Score (0-10) |
|---|---|---|---|---|
| G1a diorama | 4.1 → 8.5 → **47.4 %** | 0.387 | van not in frame; zone p95 0.45 vs plate A 0.90; the brightest 1 % is snow, bulbs and the plate pool, not the van zone | 5.5 → **7** |
| G1b classic | 2.8 → 2.8 → **25.3 %** | 0.237 | van p95 0.90 → **0.27**; it owned 88.5 % of the brightest 1 %, now **0 %** (lamp lanterns 23 %, the rest windows, snow and the Snow Globe) | 6.5 → **7** |
| G2 party wide | 2.5 → 2.5 → **21.5 %** | 0.263 | the clones stay the brightest, most saturated things; the till p95 0.90; zone 0.45 | 6 → **6.5** |
| G3 garage | new → **30.8 %** | 0.154 | the job board (its NEXT card) is the brightest group (p95 0.47) above your van (0.39); no bulb or pool outshines it | **6.5** |

**What changed on screen.**
- **Warm pass (L1, then L2 and Clone Party):** two new `StreetLamp` posts flank every storefront (LevelDress `street`, KitPlan lamp kind `street`: a warm PointLight at the lantern and a 20-stud, five-step warm pool), which washes the brick facade and the snow amber; the room lamps are brighter and wider (1.6, range 24, an 18-stud softer pool); new burgundy `Rug_8x6` rugs lie in the pools (L1 entrance and back room, L2 entrance / middle room / under the safe, Clone Party front area, office and both aisle runners) with a doormat at every door. Cool light is left to the moon, the sky, the street beyond the pools and the shadows.
- **The van:** its body is now `Van_Paint`, a runtime-coloured part, caramel `#8C6448` in a heist (`Config.Lighting.VAN.paint`, a mid value: luma 0.42), under a dark Vault Steel roof; the Getaway White chevrons on the dark band stay the exit signal. The zone idles at 0.92 transparency (was 0.85).
- **G3 garage v1** (`Heist/LobbyPlan` + `Heist/Lobby`): an 88 x 56 brick garage in the Corner Shop atlas, the `GarageDoor_16x12` half open onto a snowy street with a street lamp and drifts, 8 side-on van bays in their bay paints with painted lines and numbers, your bay right of the door with a shadowed key light, a work lamp washing the brick behind each van, aisle floods, the `JobBoard` (cork, pinned photos, red string) with its glowing NEXT card, and the trophy counter with your first ornament lit.

**Self-critique (honest).**
- **G1b and G2 miss the 40 % warm target; G1a passes.** G1b: 21 % of the frame is the van's dark roof and about 20 % the night sky (both cool by design). G2: the Toy Shop atlas is storybook navy walls and slate tiles (an owner-reviewed palette): pink and gold light on navy stays cool. Getting G2 warm needs a warmer Toy Shop wall and floor swatch: an owner call, not done here.
- **The cash still does not read from the spawn.** Geometry, not light: in L1 the cash stands at (0, -28), exactly on the axis behind the shut back-room door (x -3..3), so no classic camera at the spawn sees it through the partition windows, and the diorama frame's top edge reaches the floor at about z -22, so nothing at z -28 is in frame at any height. The hero light and the sparkle are there; making them visible needs **sim level data** (move the cash off the door's axis, e.g. x 6, so it shows through the right window) or the camera's run-start objective beat (C1). Not changed: both are outside this track.
- **The van could not move.** `Shop.VAN` (the bank zone, x -5..5, z 16..24) and `Shop.SPAWNS` are sim data (`src/shared/Levels/Shop.luau`), and the van body is drawn and collides right behind the zone; parking it beside the shop would leave the bank zone on an empty kerb or change the sim. Restyled only: it is no longer the brightest thing, but in G1b its (dark) roof still fills the lower left quarter. That is the classic camera's framing over the kerb (C0).
- **The pools read as flat stamped discs** in Blender; five rings soften the step but a radial-gradient image (roblox_quality §1.2 trick 1) would look better in the engine. The street lamps stand in the corner snow piles (a lamp in a drift is fine; check the base in Studio).
- **G3:** the trophies peek over your van's roof but read small at 22 studs; your van is the bay-1 teal (the P1 crew family), the coolest big shape in the frame; the floor checker stays dark and cool; no falling snow inside (the client turns it off indoors, so only the drifts and the street under the door carry the snow). The bay paints are per bay: the code has no bay owner, so "your van in your crew colour" is bay 1 in the P1 family, not your seat's colour.
- **[verify in Studio]** the warm pools' brightness against recipe A at quality 1-3 (voxel lighting smears the street lamps), the van paint under the moon key, the NEXT card at 48 px on a phone (in the G3 render it is about 90 x 60 px at 1280 x 720), the garage's greybox-to-kit switch (the kit dresses in the background once `KitService` is ready), and engine smoke section 8 (written, not run: the engine was busy).

## 9. Levels and world feedback: the warm pass on L3, L4 and L6, soft pools, world-side feedback (2026-11-12)

Rendered with `python3 tools/blender/level_shots.py --golden --samples 32` (G1a, G1b, G2 and the new level frames), `--garage --samples 32` (G3) and `--samples 12 --out docs/audit/levels/after` (all six levels, seven shots each, and the contact sheet); R2: Blender, not Studio. Graded by `tools/blender/frame_grade.py` into [`levels/golden/grades.json`](levels/golden/grades.json) (warm share = sRGB R - B >= 8 and luma >= 0.06). The pools before / after: [`levels/golden/pools_before_after.png`](levels/golden/pools_before_after.png).

**What changed.**
- **Warm pass on L3, L4, L6** (the L1/L2/L5 recipe, `LevelDress`): street lamps flanking each storefront; rugs in the pools (entrance, L3's grid room and under the register, L4's Gus post and the night deposit, L6's lobby, hall runner and scale room) and the doormats; an L3 grid-room lamp. L6: street lamps at the bank front, in the service alley and in both side alleys; a warm gold `accent` lamp over the vault's coins (the Bank's room lamps are green); the scale room's lamp is now an off-axis pair at (+-6, -39), so no fixture hangs between you and the vault row or the gold. Light budget per view held (unit specs per level: <= 9 lit, <= 2 shadowed; every daily vault has room lamps, a lamp and a letter per plate).
- **L6 "need all 4"**: `KitPlan.vaultRows` puts a lettered lamp per plate on the vault frame's scale-room face (A-D from your left, the gap doubled across the door lamp), dim Bulb Warm until its plate is held, then the presser's hue (WorldView, from the plate attributes), and a "VAULT n/4" count over the row (Go Green at 4/4). The daily need-all doors (DV02, DV07, DV11, DV12) get rows too.
- **L6 lobby**: the Bank's long counters are `TellerCounter_8x4` (marble top, glass screen) fitted to the sim counters (no sim change; scaled to the 2-deep box).
- **L6 cables**: the four vault trunks are ordered C, B, A, D west to east so no plate's cross run crosses another trunk (unit spec: no two cables touch); B's laser cable runs to the grid's west post.
- **L6 alley**: lot walls past the street front are outdoors (`KitPlan.buildingBox` = `BackdropPlan.levelSite`): no interior floor tiles in the alleys, the client's snow falls there, and street lamps light them. The fence is still the 12-tall brick wall (a low fence piece is a new kit asset: not done).
- **Hide spots / L4's plate under the coat rack**: the letter of a plate hidden in a hide hangs on a disc over the hide (L4 B; L6 A, B, C, D), and a soft Warm Marble outline of the hide fades in within 6 studs (FEEDBACK_TABLE "Hide spot"; not visible in these renders: nobody stands within 6 studs).
- **Soft pools**: one smooth radial falloff instead of stepped rings, `opacity = peak x (1 - (r/R)^2)`; in the engine the uploaded gradient (`EH_FX_Pool`, Decal 83512391533289, resolved at boot by `UiImages`) in one ImageLabel, until then 10 soft discs on the same curve. Every pool is cut at the wall lines it would cross (`KitPlan.poolRect`): **the golden pass's street pools were shining through the shop front onto the roofless interior** (visible from the diorama camera); now they stop at the wall face. A smooth edge alone lost warm share (G1a 47 -> 36 %), so the curve is gentler, 1.2x the old mean brightness, and room / street pools are 20 / 24 studs.
- **World feedback** (client only, `Config.WorldFx`, maths in `Shared/Heist/WorldFx`): plate sink 0.15 on a spring with a ~0.1 s overshoot; door dust puff and slide overshoot; three-layer lasers (ink sleeve, body, core) and the re-arm whine as the flicker starts; loot glint every 2 s, squash on grab, hop on drop; your own character carries loot in both hands in front of the chest (the clones' carry clip on your arms); the bank moment (<= 24 coins, van bounce, "+$100!" pop, `world.onBank(amount, worldPos)`); haptics on plate / grab / bank on phones only. None of these show in stills.

| Frame | Warm share (before -> now) | Median luma | Brightest-element check | Score (before -> now) |
|---|---|---|---|---|
| G1a diorama | 47.4 -> **44.7 %** | 0.387 -> 0.371 | bulbs and the plate pool own the brightest 1 % (4.4 / 3.7 %); zone p95 0.49 (was 0.45: the wider street pools reach it) | 7 -> **7.5** |
| G1b classic | 25.3 -> **26.0 %** | 0.240 | lanterns 23 % of the brightest 1 %, van 0 % | 7 -> **7** |
| G2 party wide | 21.5 -> **21.4 %** | 0.266 | cash p95 0.90, clones brightest | 6.5 -> **6.5** |
| G3 garage | 30.8 -> **30.5 %** | 0.154 | the NEXT card (board p95 0.48) over your van (0.39) | 6.5 -> **6.5** |
| L3 diorama (new) | **45.9 %** | 0.371 | as G1a: bulbs and plate A | 3 -> **6** |
| L3 grid (new) | **29.2 %** | 0.208 | the register's cash (p95 0.92), plate B 0.88 | **7** |
| L4 diorama (new) | **45.9 %** | 0.371 | as G1a | 4 -> **6** |
| L4 back room (new) | **44.4 %** | 0.202 | plate B under the coat rack owns 11.5 % of the brightest 1 %; Gus's amber cone is most of the warm area | **6.5** |
| L6 diorama (new) | **30.7 %** | 0.323 | lamps; the zone p95 0.31 | 4 -> **6.5** |
| L6 classic (new) | **18.8 %** | 0.228 | van 0 % of the brightest 1 % | **6** |
| L6 vault (new, VAULT 4/4) | **8.9 %** | 0.258 | the gold (p95 0.86) is the brightest group | **6** |

(L3 / L4 / L6 "before" scores are §2's audit scores of the whole level, not of these frames.)

**Self-critique (honest).**
- **L3 and L4 still open on L1's picture.** Their diorama frames grade exactly like L1's (45.9 % both): from the spawn every Corner Shop level is the same storefront, now warmer. P1-1 (each level's own first room) needs sim level data; the level-own frames (L3 grid, L4 back room) show what is different, but a thumbnail of the spawn does not.
- **G1a lost 2.7 points of warm share.** That is the honest price of not lighting the interior through the shop front (the golden pass's 47.4 % counted the leak); the pavement pools are smoother, wider and brighter at the centre. The cut at the wall face leaves a straight edge on the pavement at the facade's foot (reads as the wall's shadow line; check in Studio).
- **The vault frame is cold (8.9 %).** Steel door, navy walls and the green Bank room lamps; one gold accent (the budget allows one next to the scale-room pair) and the hero spot light only the gold and the coins. The frame's bottom third is the arch wall top. In the classic camera at eye height the vault's own hero lamp fixture still hangs over the doorway's top.
- **The "VAULT n/4" count** is a BillboardGui over the wall top (in Blender, flat text): check its size at 48 px on a phone and that it never covers the row; the row's letters (0.95-stud discs) need a phone look at play distance.
- **L6 alley**: reads as a lit, snowy service alley in the plan and street shots, but the lot fence is still a 12-tall brick wall (a low fence piece is a new kit asset). The side-alley pools are cut to 9-stud strips between the bank and the fence.
- **Teller counters** are squashed to the sim's 2-deep counter box (the kit piece is 4 deep); the glass screen reads as a rail from above. A 4-deep sim counter would look better but is sim data.
- **Not verified in the engine** (written, not run: engine smoke section 9): the soft pool canvas orientation (the pool part's Front face turned up: canvas right = +X, up = -Z), HapticEffect on a phone, the live carry clip on your own arms, the van bounce on the kit van, the dust and coin textures (built-in Roblox particles until art exists).
- **Sound**: PlateHum, LaserWhine, LootTinkle and VanToot are empty cues (docs/AUDIO.md "Missing (world feedback)").

## 10. WORLD 2.0: "black in the background" (owner feedback, Nov 2026)

The owner played the build in Studio: *"All maps must look better and must NOT be black in the background."* This section is the diagnosis, what changed and the before / after numbers for every level, two daily vaults (DV01 Corner Shop, DV10 Bank) and the garage, in both cameras.

**How it is measured.** `python3 tools/blender/level_shots.py --world2` (R2, Blender, not Studio) renders each site at a phone's full frame (19.5:9, 1280 x 592; Roblox's FOV is vertical, so a wide frame sees the most of the surroundings) in four shots: **diorama** (the game's camera at the spawn: pitch 52, distance 30, FOV 45), **classic** (follow cam behind you at the spawn, 16 studs, pitch 25, FOV 70: it sees the horizon and the sky), **diorama_mid** (you inside the building mid-run, the solution's clones on their plates) and **classic_rev** (turned round in the street: the far side and the sky). The after set adds **diorama_crew** (the diorama on the crew and its held plates) for the signal check. `tools/blender/frame_grade.py` grades each frame: **near-black** = luma < 5 %, **dark** = luma < 10 %, the median luma, the warm share (R - B >= 8), and, with a source mask, which layer each dark pixel belongs to (the level, the town / facade cards, the ground plane, the rings, the sky). Files: `docs/audit/levels/world2/before/`, `after/`, each with `grades.json`; the contact sheet [`world2/contact_sheet.png`](levels/world2/contact_sheet.png) shows every frame as a before | after pair with its near-black share and median luma.

**The tone-map proxy (new, and why the earlier renders said "fine").** Rendered with Blender's Standard view, the before frames had almost no near-black pixels (L1 diorama 0.0 %, diorama_mid 0.2 %), which contradicts what the owner saw. Standard has no toe; the engine's Default tone mapper is a filmic curve that crushes low values (assumption: modelled as the ACES fit, `backdrop_shots.tonemap`, applied to every WORLD 2.0 frame before haze and grading). A dark albedo lit only by the night ambient (linear ~0.005-0.02) lands in that toe and comes out black. With the proxy the before frames show 7-50 % near-black, which matches the owner's report; the earlier golden-frame numbers (§7-§9) were measured without it and are optimistic. The after frames are graded with the same proxy (and the Standard-view numbers are kept in `grades.json` under `standard_view`). It is a proxy, not a calibration: Studio shots in the Shots inbox (issue #1) would calibrate it.

### 10.1 Diagnosis: why it was black

In order of weight:

1. **The engine loaded recipe A as Voxel lighting** (found by the TECH POLISH track, confirmed here). Rojo writes only listed properties and `default.project.json` never listed `Lighting.Technology`, so every place loaded the class default (Voxel), which the engine maps to `LightingStyle` Soft + `PrioritizeLightingQuality` off. The live game never ran the Realistic look the renders assumed: no per-pixel local lights or shadows, flatter and darker interiors. Fixed: `"Technology": "Future"` in the project file; place_check now requires it (`REQUIRE_TECHNOLOGY = true`); perf_engine asserts Realistic + Prioritize at boot (ok on v55).
2. **Dark albedos under a weak night ambient, crushed by the tone mapper's toe.** The level interiors (brick `plum`, `plum_deep`, the `floor_a / floor_b` checker at V 15-30 %) are lit by the moon on one side and by OutdoorAmbient (115,110,165) elsewhere; in the moon's wall shadows only the ambient remains and those surfaces go black: the **level layer is the largest near-black source in every frame** (L1 diorama_mid: 36.6 % of the whole frame is near-black level pixels). The old backdrop made it worse round the edges: the facade cards were Ink-family bodies (V 23-29 %, median luma 0.03-0.09 in frame: 7.6 % near-black of the L1 classic frame) and the ground plane (74,72,112) sat at median luma 0.07-0.29.
3. **Gaps: nothing around most of the lot.** The facade ring was 16 cards, 10 studs deep, on the street line and across the street; the sides of the lot behind the street front and the area behind the lot were bare dark ground (the diorama's top edge and sides when you are inside the building), and the lot's own outdoor floor was the dark `floor` swatch.
4. **The Atmosphere and the sky pulled the distance toward darkness.** Atmosphere Color (90,80,150) / Decay (55,45,105) at Density 0.28: geometry faded toward a dark indigo, and the haze takes the sky's colour in some directions (roblox_quality §1.2), whose horizon was (90,80,150) and whose lower half was (30,27,52). Sky medians in frame 0.27-0.30; the zenith (22,21,50) read as black on a phone. Rings in the atlas's Ink faces: median 0.13-0.17.
5. **The far edge of the 2048-stud ground** and **the sky faces** are small contributors in the classic camera (the sky is 2-4 % of those frames, no near-black pixels in it); at low quality levels a "black fog" is reported for the Atmosphere (roblox_quality §1.1, [UNVERIFIED]), which recipe C now thins.
6. **Interiors behind the camera:** the levels are roofless, so the classic camera never looks into a closed room; with Poppercam off the backdrop (CanQuery off) a classic camera can sit inside a backdrop box, which is invisible from inside (no black).

**Client code paths checked** (`Heist/Backdrop`, `Heist/BackdropKit`, HeistClient, LightDirector):
- BackdropKit not replicated yet: the client built everything but the rings at once and waited 60 s for the kit; fine. The reconnect left one stray connection on ReplicatedStorage (harmless); rewritten (one wait, one Ready listener, box fallbacks until the kit lands).
- A tier dropping it: no tier dropped the backdrop (the far ring at 3, windows at 4); now nothing that fills the frame drops at any tier.
- Streaming: client-made parts never stream; the level is PersistentPerPlayer; no issue.
- Build order / garage teleport: `showHeist` after the level binds, `showGarage` on every garage sync; no issue. `showHeist` with no compiled level (a relaxed daily the client cannot compile) clears the backdrop entirely: unchanged, logged here as an edge.
- **Real bug fixed:** HeistClient's particle budget finds the snow by `FindFirstChild("Snow", true)`, but the old backdrop had dozens of Parts named "Snow" (the cornice snow) built before the emitter, so the lookup found a Part and counted the snow as 0 particles. The emitter is now built first and nothing else is named "Snow".
- **Real bug fixed:** nothing stopped a player walking off the lot's edge into the (non-colliding) backdrop and falling; a town at street level would invite it. The lot now has a client-only invisible fence (CanCollide on, CanQuery / CanTouch off: cameras, raycasts, Gus and the sim never see it).

### 10.2 What changed

- **A snowy neighbourhood round every lot and the garage** (`Shared/Heist/TownPlan`, client `Heist/Backdrop`, STYLE_BIBLE §16): the street at the lot's own height (warm sandstone pavements, kerbs, a road of packed snow with slushy tyre tracks), warm cobbles over the lot's outdoor floor, a snowfield (V 84 %) under everything; neighbours along the street on both sides (the first one long, its side lit toward the lot), a row behind the lot facing it and a row across the street: brick, terracotta, mustard and cream bodies, lit Bulb Warm windows, thick snow on every flat roof and cornice, `Roof_Gable` snow roofs on the houses, shop fronts with awnings (snow on top) and coloured doors, garlands under the cornices, wreaths on the doors; kit street lamps with unlit warm pools on the snow (no Light objects); parked cars with snow on the roof, bonnet and boot; decorated trees; snowmen; snow piles. The rings draw flat in a light haze colour instead of the atlas's Ink faces. The client-only lot fence keeps you on the lot.
- **Each map its own street** (PLAN §3.1): Corner Shop street (terraces, corner shops, gabled houses, a tree on the far pavement); Toy Shop high street (L5: candy bodies on rose paving, fairy-light strings on every front, two trees); Bank plaza (L6 and the Bank dailies: stone fronts, a paved plaza across the street with a 26-stud tree, four lamps and civic porticoes behind); the garage yard (workshops and houses round the yard, cars, a snowman). L1-L4 and the dailies share the Corner Shop street but each level has its own arrangement (seeded: building order, colours, cars, the tree and snowman spots); the unit spec checks that no two launch levels' streets are the same.
- **Atmosphere and sky:** Atmosphere Density 0.24, Color (158,158,214), Decay (124,120,184), Haze 1.6: the distance fades into a light snowy blue-violet haze. The Heist City cubemap re-rendered and re-uploaded: a deep but clearly blue zenith (34,48,116), a light haze horizon with a warm rose glow, the lower half the haze colour (never dark), Hoardsworth's tower and the Snow Globe unchanged.
- **Recipe A retuned within its intent** (night by hue, not darkness; all four project files and place_check): Technology Future; Brightness 1.5; Ambient (136,124,150) / OutdoorAmbient (174,160,186) (was (95,90,140) / (115,110,165): enough fill that a dark albedo in shadow stays out of the toe, and less blue, so the warm pools still win the spawn views); EnvironmentDiffuseScale 0.36; ExposureCompensation 0.4 (0.5 brightened the floor round the plates until the held rings lost their value contrast). Recipe C follows (Brightness 1.7, (146,134,160) / (184,170,196), exposure 0.35) and thins the Atmosphere on low phones (0.2 / Haze 1.4).
- **Daily vaults get street lamps** (`KitPlan.defaultStreet`): a level without hand dressing gets a lamp either side of its front, like L1-L4 / L6; the daily spawn views had no warm pool at all (DV10 diorama warm share 0.6 % before).
- **New kit** (gates pass, uploaded): `Roof_Gable` (32 tris), `Car_Parked` (476) + `Car_Parked_Paint` (88, runtime colour), `Snowman` (724).

### 10.3 Before / after (filmic proxy, 19.5:9, R2 Blender)

| Site | Camera | Before: near-black % / dark % / median luma / warm % | After | Median up |
|---|---|---|---|---|
| L1 | diorama | 8.3 / 16.2 / 0.31 / 39 | 0.0 / 0.5 / 0.61 / 52 | +95 % |
| L1 | classic | 12.0 / 22.2 / 0.30 / 35 | 0.0 / 1.0 / 0.53 / 53 | +74 % |
| L1 | diorama_mid | 50.1 / 66.7 / 0.05 / 2 | 0.0 / 3.3 / 0.22 / 68 | +355 % |
| L1 | classic_rev | 10.0 / 32.8 / 0.12 / 6 | 0.0 / 1.1 / 0.65 / 23 | +442 % |
| L2 | diorama | 7.3 / 15.8 / 0.32 / 39 | 0.0 / 0.5 / 0.62 / 51 | +93 % |
| L2 | classic | 11.3 / 21.9 / 0.31 / 35 | 0.0 / 1.0 / 0.52 / 54 | +70 % |
| L2 | diorama_mid | 30.2 / 58.2 / 0.08 / 14 | 0.0 / 2.0 / 0.21 / 73 | +176 % |
| L2 | classic_rev | 10.0 / 32.8 / 0.12 / 6 | 0.0 / 1.1 / 0.64 / 32 | +432 % |
| L3 | diorama | 7.4 / 16.4 / 0.32 / 40 | 0.0 / 0.5 / 0.62 / 52 | +95 % |
| L3 | classic | 11.4 / 21.8 / 0.30 / 35 | 0.0 / 1.0 / 0.59 / 50 | +93 % |
| L3 | diorama_mid | 22.9 / 47.9 / 0.11 / 20 | 0.0 / 1.4 / 0.26 / 65 | +135 % |
| L3 | classic_rev | 10.0 / 32.8 / 0.12 / 6 | 0.0 / 1.0 / 0.64 / 23 | +435 % |
| L4 | diorama | 7.5 / 16.3 / 0.32 / 40 | 0.0 / 0.5 / 0.63 / 50 | +97 % |
| L4 | classic | 11.4 / 21.9 / 0.30 / 35 | 0.0 / 1.0 / 0.60 / 50 | +95 % |
| L4 | diorama_mid | 18.2 / 41.2 / 0.15 / 31 | 0.0 / 1.2 / 0.35 / 75 | +129 % |
| L4 | classic_rev | 10.0 / 32.8 / 0.12 / 6 | 0.0 / 1.1 / 0.65 / 20 | +443 % |
| L5 | diorama | 7.8 / 16.5 / 0.31 / 30 | 0.0 / 0.3 / 0.62 / 34 | +99 % |
| L5 | classic | 11.5 / 22.0 / 0.31 / 30 | 0.0 / 0.9 / 0.56 / 41 | +82 % |
| L5 | diorama_mid | 21.7 / 51.8 / 0.09 / 3 | 0.0 / 2.2 / 0.26 / 18 | +177 % |
| L5 | classic_rev | 10.0 / 32.8 / 0.12 / 6 | 0.0 / 1.1 / 0.67 / 24 | +455 % |
| L6 | diorama | 11.3 / 25.7 / 0.30 / 31 | 0.0 / 0.6 / 0.57 / 37 | +87 % |
| L6 | classic | 13.2 / 22.2 / 0.29 / 31 | 0.0 / 2.3 / 0.55 / 41 | +87 % |
| L6 | diorama_mid | 22.2 / 36.3 / 0.17 / 16 | 0.0 / 2.1 / 0.29 / 21 | +68 % |
| L6 | classic_rev | 8.4 / 30.7 / 0.12 / 6 | 0.0 / 1.0 / 0.65 / 17 | +430 % |
| DV01 | diorama | 21.6 / 32.2 / 0.18 / 9 | 0.0 / 0.4 / 0.64 / 47 | +244 % |
| DV01 | classic | 23.0 / 37.1 / 0.15 / 3 | 0.0 / 1.2 / 0.65 / 43 | +325 % |
| DV01 | diorama_mid | 20.6 / 50.7 / 0.10 / 36 | 0.0 / 0.8 / 0.33 / 76 | +236 % |
| DV01 | classic_rev | 10.1 / 32.9 / 0.12 / 6 | 0.0 / 1.1 / 0.51 / 39 | +328 % |
| DV10 | diorama | 30.5 / 42.1 / 0.14 / 1 | 0.0 / 0.6 / 0.60 / 33 | +338 % |
| DV10 | classic | 29.3 / 41.9 / 0.13 / 1 | 0.0 / 2.5 / 0.62 / 31 | +388 % |
| DV10 | diorama_mid | 8.2 / 33.1 / 0.29 / 17 | 0.0 / 0.5 / 0.49 / 22 | +65 % |
| DV10 | classic_rev | 8.4 / 30.8 / 0.12 / 6 | 0.0 / 1.0 / 0.65 / 13 | +439 % |
| GA | diorama | 3.0 / 12.1 / 0.19 / 30 | 0.0 / 0.4 / 0.29 / 35 | +51 % |
| GA | classic | 9.4 / 21.1 / 0.21 / 12 | 0.0 / 0.5 / 0.34 / 27 | +62 % |
| GA | diorama_mid | 20.9 / 34.0 / 0.17 / 18 | 0.0 / 2.6 / 0.41 / 35 | +138 % |
| GA | classic_rev | 0.0 / 91.9 / 0.07 / 0 | 0.0 / 0.1 / 0.59 / 33 | +744 % |

Where the before frames' near-black pixels are (share of the whole frame that is near-black AND that layer; the layer's median luma in brackets):

| Frame | Level (lot, shop, van) | Town / facade cards | Ground plane | Rings | Sky |
|---|---|---|---|---|---|
| L1_diorama | 7.6 (0.39) | 0.8 (0.06) | 0.0 (0.28) | - | - |
| L1_classic | 4.4 (0.45) | 7.6 (0.04) | 0.0 (0.29) | 0.0 (0.13) | 0.0 (0.30) |
| L1_diorama_mid | 36.6 (0.06) | 13.5 (0.03) | 0.0 (0.07) | - | - |
| L1_classic_rev | 8.6 (0.12) | 1.4 (0.09) | 0.0 (0.21) | 0.0 (0.17) | 0.0 (0.27) |
| L2_diorama | 6.6 (0.40) | 0.8 (0.06) | 0.0 (0.28) | - | - |
| L2_classic | 4.2 (0.45) | 7.1 (0.04) | 0.0 (0.29) | 0.0 (0.14) | 0.0 (0.30) |
| L2_diorama_mid | 27.2 (0.07) | 3.0 (0.04) | 0.0 (0.08) | - | - |
| L2_classic_rev | 8.6 (0.12) | 1.4 (0.09) | 0.0 (0.21) | 0.0 (0.17) | 0.0 (0.27) |
| L3_diorama | 6.6 (0.39) | 0.8 (0.06) | 0.0 (0.28) | - | - |
| L3_classic | 4.4 (0.45) | 7.0 (0.04) | 0.0 (0.29) | 0.0 (0.14) | 0.0 (0.30) |
| L3_diorama_mid | 20.9 (0.12) | 2.0 (0.04) | 0.0 (0.09) | - | - |
| L3_classic_rev | 8.7 (0.12) | 1.4 (0.09) | 0.0 (0.21) | 0.0 (0.17) | 0.0 (0.27) |
| L4_diorama | 6.7 (0.39) | 0.8 (0.06) | 0.0 (0.28) | - | - |
| L4_classic | 4.4 (0.45) | 7.0 (0.04) | 0.0 (0.29) | 0.0 (0.14) | 0.0 (0.30) |
| L4_diorama_mid | 16.2 (0.17) | 2.0 (0.04) | 0.0 (0.09) | - | - |
| L4_classic_rev | 8.7 (0.12) | 1.4 (0.09) | 0.0 (0.21) | 0.0 (0.17) | 0.0 (0.27) |
| L5_diorama | 7.1 (0.35) | 0.8 (0.06) | 0.0 (0.28) | - | - |
| L5_classic | 4.2 (0.45) | 7.3 (0.04) | 0.0 (0.29) | 0.0 (0.14) | 0.0 (0.30) |
| L5_diorama_mid | 17.1 (0.10) | 4.6 (0.04) | 0.0 (0.08) | - | - |
| L5_classic_rev | 8.6 (0.12) | 1.4 (0.09) | 0.0 (0.21) | 0.0 (0.17) | 0.0 (0.27) |
| L6_diorama | 11.3 (0.30) | - | - | - | - |
| L6_classic | 12.8 (0.31) | 0.3 (0.05) | 0.0 (0.12) | 0.0 (0.14) | 0.0 (0.30) |
| L6_diorama_mid | 22.2 (0.17) | - | - | - | - |
| L6_classic_rev | 7.1 (0.12) | 1.4 (0.09) | 0.0 (0.21) | 0.0 (0.17) | 0.0 (0.27) |
| DV01_diorama | 20.9 (0.16) | 0.8 (0.06) | 0.0 (0.28) | - | - |
| DV01_classic | 15.4 (0.19) | 7.6 (0.04) | 0.0 (0.29) | 0.0 (0.13) | 0.0 (0.30) |
| DV01_diorama_mid | 7.1 (0.13) | 13.5 (0.03) | 0.0 (0.07) | - | - |
| DV01_classic_rev | 8.7 (0.12) | 1.4 (0.09) | 0.0 (0.21) | 0.0 (0.17) | 0.0 (0.27) |
| DV10_diorama | 30.5 (0.13) | - | 0.0 (0.29) | - | - |
| DV10_classic | 25.5 (0.12) | 3.8 (0.04) | 0.0 (0.28) | 0.0 (0.13) | 0.0 (0.30) |
| DV10_diorama_mid | 7.6 (0.31) | 0.7 (0.03) | 0.0 (0.08) | - | - |
| DV10_classic_rev | 7.0 (0.12) | 1.4 (0.09) | 0.0 (0.21) | 0.0 (0.17) | 0.0 (0.27) |
| GA_diorama | 3.0 (0.19) | - | - | - | - |
| GA_classic | 7.0 (0.22) | 2.5 (0.06) | 0.0 (0.33) | 0.0 (0.14) | 0.0 (0.30) |
| GA_diorama_mid | 16.5 (0.18) | 4.4 (0.03) | 0.0 (0.31) | - | - |
| GA_classic_rev | - | 0.0 (0.07) | - | - | - |

Measured bar (after): warm share in the diorama, the focal element against the brightest town surface (p95 luma), and signal pop on the crew frame (median value contrast against the surround):

| Site | Diorama warm % | Focal p95 (cash / plate) | Town p95 (ground / buildings / lot / props) | Signal pop (rings, lasers) | Clone pop |
|---|---|---|---|---|---|
| L1 | 51.8 | 0.86 | 0.75/0.80/0.85/- | 0.153 | 0.259 |
| L2 | 51.4 | 0.86 | 0.75/0.81/0.85/- | 0.094 | 0.243 |
| L3 | 51.7 | 0.86 | 0.75/0.80/0.85/- | 0.153 | 0.263 |
| L4 | 50.3 | 0.86 | 0.75/0.80/0.85/- | 0.153 | 0.263 |
| L5 | 33.8 | 0.77 | 0.75/0.80/0.85/- | - | 0.384 |
| L6 | 37.0 | 0.69 | -/-/0.83/- | - | 0.529 |
| DV01 | 47.3 | 0.86 | 0.75/0.80/0.85/- | - | - |
| DV10 | 33.0 | 0.85 | 0.73/0.78/0.83/- | - | - |
| GA | 34.7 | 0.00 | -/-/0.25/- | - | - |

**The bar, honestly:**
- **Near-black ≤ 3 %: met in every frame** (0.0 % in all 36 after frames; before 3-50 %). Dark (< 10 %) ≤ 3.3 % everywhere after.
- **Median luma up by a clear margin: met** (+51 % garage diorama to +7x the turned-round classic frames; the diorama spawn views about double).
- **Warm share ≥ 30 % in the diorama: met for every site** (L1-L4 50-52 %, L5 34 %, L6 37 %, DV01 47 %, DV10 33 %, garage 35 %). The turned-round classic frames (across the street, the sky) stay cooler (13-39 %): by design, cool outside and in shadow.
- **The focal prop the brightest non-signal element: partly.** In the Corner Shop levels and the dailies the plate / cash (p95 0.85-0.86) outshines the town (snow 0.75, roofs and walls 0.80 where the windows are; the lot's p95 0.85 is the level's own street-lamp pools). **L5 (cash 0.77) and L6 (gold 0.69, small in the vault far behind the lobby)** stay under the street-lamp pools and the warm windows in the spawn view, as they did before (L5's rug outshone the cash then, L6's gold was 0.48); a darker paving did not change it (the pools are unlit and set the p95). The town itself never becomes the brightest thing.
- **Signals pop (premium A1, ≥ 0.15 value contrast against the world round them): clones met everywhere** (0.24-0.53 after; 0.29-0.58 before: the brighter world costs some contrast but they stay well clear); **held plate rings just met on L1, L3, L4 (0.153), missed on L2 (0.094)** (before 0.21 on L1 / L3). A fully saturated Neon ring cannot get brighter, so its value contrast falls as the floor round it brightens; the ring's read is mostly hue (clone cyan on warm cream). L2's crew stands where its two plates' pools overlap. Owner call if it matters at 48 px: a darker plate surround (the plate mesh's rim) or a smaller plate pool.

**Self-critique and scores (0-10, "a lit Christmas snow-globe diorama, never black"):**
- **L1-L4 / DV01, 8 (before 4):** the spawn view is a warm shop front between snowy neighbours, the street and the lit far row in the classic camera, no black anywhere; mid-run the walls and floors read as brick and checker, not voids. Down: from the spawn every Corner Shop level is still the same storefront (P1-1, sim data); the neighbours are box houses (a cornice and a roof, no window frames or chimneys); the Neon windows render near-white in the proxy (Bulb Warm in Studio: check).
- **L5, 7.5 (before 4):** the candy high street with its light strings reads as its own place in the classic camera; the navy Toy Shop front stays the coolest big shape in the spawn view (an owner palette call, §8) and the cash is not the brightest thing.
- **L6 / DV10, 7.5 (before 3.5):** the Bank plaza and its big tree are the best new silhouette from the street; in the diorama the plaza is behind the camera, so the spawn view is the bank front and the lit side streets. The gold is far and small.
- **Garage, 7 (before 4):** the yard, cars and snowman out of the door, warm workshops round it, no void past the walls; the interior floor checker stays dark (atlas, not this track).
- **Risks:** the filmic proxy is uncalibrated (it explains the owner's black, it is not a measurement of Studio); the lot fence is new physics on your own character (walk the street edge and L6's alleys in Studio); recipe A is brighter overall, so check the night still reads as night on a phone; at quality 1-3 (voxel lighting) the town's look and the thinner recipe C haze are untested.

**Engine (Saved v55, after merging main with first person and the Rookie):** engine_smoke 133 ok / 0, client_engine 49 / 0, clone_engine 109 ok / 0, kit_engine 378 ok / 0, perf_engine 93 ok / 0. perf_engine section D builds the town round every heist instance and the garage: 287 (garage) to 553 (L6) instances against the 650 budget, **0 lights**, all kit pieces placed (17 published), every building there, the lot fence 4 / 4, no other collider; the Lighting loads Realistic + Prioritize. The busiest view: ~266k tris / ~293 draws at tier 1 (backdrop ~63k), ~132k / ~211 at tier 3 (backdrop ~10k) against 450k / 450 and 150k / 250.

## 11. Wave C (2026-11-13): the L1 cash and the Toy Shop walls, applied

- **L1 cash:** moved to (10, -26) on a `Safe` (LevelDress). x 6 (the §9 example) would sit behind the door frame from the spawn: the right window's glass spans x 5.5..10.5 at z -20. In first person the Rookie's eyes (~3.8 studs) are below the window sill (4.85), so only a raised cash shows: its top third from every seat ([fp spawn](levels/after/L1_cs1_back_room_1c_spawn_fp.png)), the whole bag from the classic camera ([spawn](levels/after/L1_cs1_back_room_1_spawn.png), [objective](levels/after/L1_cs1_back_room_2_objective.png)). Checked by `tests/unit/HeistL1Cash.spec.luau` and `tests/clone_engine.luau` section 7.
- **Toy Shop:** the navy wall and front cells became a warm berry-plum (#4F1E36 / #5C2941 / #7D475F, same lightness): WORLD 2.0 L5 warm share diorama 33.8 → 41.2 %, classic 41.2 → 47.9 %, mid-run 18.4 → 58.8 %, no near-black ([diorama](levels/world2/after/L5_diorama.png), [spawn](levels/after/L5_cs5_clone_party_1_spawn.png)). The giant drummer's red coat reads a little less against the berry wall than against navy (its white straps and black hat carry it).

## 12. BIG buildings (2026-11-13): huge, roofed, thought through (PLAN_FIRST_PERSON §5 "BIG")

The owner: *"Make sure all buildings are huge and that the problem is thought through."* The game is first person by
default now (eye ~3.8 studs over the floor), and the levels were single-storey, roofless boxes built for a top-down
diorama: indoors you looked up into the sky, from the street every building was a squat 12-stud box, and the town
round it was 10-24 studs tall.

### 12.1 The problem, thought through

- **What first person needs:** a ceiling over every playable room (never sky indoors), storeys over the street (the
  sense of a city), and a town whose scale matches. **What the other cameras need:** to keep seeing in. The diorama
  (pitch 52, distance 30: the camera ~24 studs over you), the classic camera zoomed out, and every presentation shot
  (the run-start beat from above, the level intros, golden staging, the 8 OF ME pull-back, the Line-up) all look
  down into the rooms. A tall roofed building would block every one of them.
- **What must not change:** the sim. The playable footprint, walls, doors, plates, Gus's sight and the server's
  collisions are exactly what they were (no file under `src/shared/Levels` or `src/shared/Sim` touched). So the BIG
  building is **visual only and above the playable storey**: everything at or over the wall tops (y 12), or outside the
  outer faces above the street front's storey; CanCollide, CanQuery, CanTouch and CastShadow off. CanQuery off also
  keeps every existing camera and gameplay raycast (look-to-interact, Poppercam, Gus's cone, the Line-up's lane
  search, the wall fade) exactly as it was. CastShadow off keeps the ground floor's moonlight (and the measured
  WORLD 2.0 interiors): a 50-stud facade's shadow over the street and the lot would have put them back in the filmic toe.
- **How the cameras still see in: a camera-aware cut-away** (client `Heist/CutAway`, the rule in the pure
  `Shared/Heist/CutMath`). Two rules, decided 30 times a second on a handful of boxes, faded over 0.18 s with
  LocalTransparencyModifier (no allocation per frame; a group's parts are written only while its fade moves):
  - **dollhouse:** when the camera is above the ground floor's ceiling (y 12.5) and a subject stands inside the
    building (you, or where the camera's look ray meets the floor: the diorama's focus, a shot's subject), the ceiling,
    the roof and every face the camera is outside of open (all of them when the camera hangs over the footprint);
  - **occlusion:** any roof, storey or tall town block whose box crosses the segment from the camera to a subject fades.
  - **First person never cuts:** while the camera is at your eyes nothing hides (and the eye, even jumping, is far
    under the ceiling plane). A presentation shot lifting the camera out of your eyes cuts like the diorama.
- **Budgets:** the storeys are shells (no interiors), a handful of instanced kit meshes, panes as Parts, signs as
  SurfaceGuis, 0 lights; layers drop with the performance tier (PERF.md §9).

### 12.2 What was built

- **The buildings** (server `Heist/TowerPlan` pure + `Heist/Overhead`, `Config.Big`, STYLE_BIBLE §18): ceiling tiles
  (`Ceiling_8x8`, coffered, their underside on the wall tops so `Lamp_Ceiling` hangs from it), a 2-stud band, then
  `Facade_8x10` storeys on all four faces (a tintable body with a window opening + the atlas trim: sill with snow,
  casings, lintel and keystone, dark reveal, white mullions), panes lit Bulb Warm (~58 %, seeded) or a blue-night dark
  pane, `Facade_Curtain` in about half of the lit ones, corner quoins, `Cornice_8` crowns under snow, parapets, the
  roof's snow; per location: the **Corner Shop tenement** (4 storeys of brick, fire escapes on the street front and the
  side, "CORNER SHOP" blade sign, water tank, chimneys, antenna), the **Toy Shop department store** (4 storeys of cream
  and raspberry, the big lit "HOARDSWORTH'S TOYS" board with a Neon frame, the giant toy soldier on the roof edge), the
  **Bank** (3 storeys of stone, a giant order of six columns, "HOARDSWORTH BANK" on the entablature, the pediment and
  its clock); Christmas light strings along the band and under the crown.
- **New kit** (`assets/blender/tower.py`, all gates pass, uploaded): Facade_8x10 (+ _Body) 113529009145373,
  Facade_Curtain 126557033004908, Cornice_8 103396754216844, FireEscape_8x10 123498752791133, Roof_WaterTank
  119013245679077, Roof_Chimney 135688851662342, Roof_Antenna 140071074744392, Pediment_24 101064256180333, Clock_6
  129403410104922, Ceiling_8x8 73725950733656, Truss_8 119550315330150, Railing_8 133295213985388; the town's window grid
  `EH_FX_Windows` (UI Decal 74221995905275, `tools/ui/make_window_fx.py`).
- **The town** (`Shared/Heist/TownPlan`, `Config.Backdrop.TOWN`): every neighbour a 4-8 storey block (a 12-stud ground
  floor + 3-8 storeys of 9), its windows one Texture per face on a "Skin" part with a few Neon panes on its grid;
  rooflines with setbacks, water tanks, chimneys and antennas; a second, taller row behind the back row and behind the
  across-street row (streets with depth, undecorated: seen only over roofs); two landmark towers (11-14 storeys,
  stepped crowns with a lit band, a spire) either side of Hoardsworth's tower in the sky. Every building's pieces are a
  cut-away occluder (a block between the diorama and you fades whole). Still 0 lights.
- **The warehouse garage** (`Heist/LobbyPlan.warehouse`, `Config.Lobby.WAREHOUSE`): over the 12-stud brick course a
  band, a clerestory of window bays, a frieze to the roof at 28.6; steel `Truss_8` trusses every 11 studs; a roof deck
  with three skylights (the aurora above); a walkable mezzanine over the front row of vans (deck, posts, rail and wall
  guards collide; the stair is a wedge up the right wall); a 20 x 18 roll-up door; the stations' dressing (a laptop
  desk, a wardrobe and mirror corner with a coat stand and the tree, a TV under the mezzanine, "THE CREW" sign, crates,
  shelves) and the **anchors for the LOBBY track** in `Garage/Anchors` (invisible, non-colliding Parts; CFrame = the
  spot, LookVector = the facing): `JobBoardSpot`, `LaptopSpot`, `WardrobeSpot`, `TVSpot`, `CrewSign`, `VanBay1..8`
  (`Lobby.anchor(name)`). GarageSpawn, `spawnFor` and the bays' colliders are unchanged (bay 3 moved 1.5 studs and the
  trophy shelf 1 stud for the wider door).
- **Light, value contrast and the pink cast:** the WORLD 2.0 after-frames read washed out and pinkish. Recipe A keeps
  its intent (night by hue) with a bluer, slightly darker fill and a stronger key: Brightness 1.5 → 1.6, Ambient
  (136,124,150) → (118,122,152), OutdoorAmbient (174,160,186) → (150,160,194), Atmosphere (158,158,214) / (124,120,184)
  → (148,160,208) / (112,122,178), ColorCorrection contrast 0.12 → 0.2, saturation 0.08 → 0.1, tint (238,242,255);
  recipe C follows. All four project files and place_check.

### 12.3 Measured

**Renders** (`python3 tools/blender/level_shots.py --big`, R2 Blender with the same filmic proxy, 19.5:9; one Blender
process per shot: Eevee crashes after a few Workbench mask passes in one process). First person from the eye (3.8 over
the floor, FOV 70): the shop from the street (`fp_street`), up the facade (`fp_up`), the street corner (`fp_corner`),
inside up at the ceiling (`fp_ceiling`) and round the room (`fp_inside`); the diorama and classic cameras at the spawn and
mid-run, with the cut-away applied exactly as `CutMath` decides; a raised street view (`street_wide`); the garage from the
spawn, up at the trusses, at the mezzanine, the stations, the diorama and the yard. Files: `docs/audit/levels/big/`,
`grades.json`, the [contact sheet](levels/big/contact_sheet.png).

| Frame | near-black % | dark % | median luma | value spread | RMS contrast | pink cast | warm % |
|---|---|---|---|---|---|---|---|
| [GA_diorama](levels/big/GA_diorama.png) | 0.0 | 1.5 | 0.26 | 0.67 | 0.249 | +0.011 | 29 |
| [GA_fp_mezzanine](levels/big/GA_fp_mezzanine.png) | 0.0 | 1.2 | 0.26 | 0.24 | 0.133 | +0.036 | 29 |
| [GA_fp_spawn](levels/big/GA_fp_spawn.png) | 0.0 | 2.3 | 0.23 | 0.66 | 0.226 | +0.012 | 44 |
| [GA_fp_stations](levels/big/GA_fp_stations.png) | 0.0 | 3.9 | 0.21 | 0.63 | 0.233 | +0.005 | 60 |
| [GA_fp_up](levels/big/GA_fp_up.png) | 0.0 | 0.1 | 0.21 | 0.29 | 0.128 | -0.001 | 30 |
| [GA_fp_yard](levels/big/GA_fp_yard.png) | 1.7 | 5.5 | 0.31 | 0.58 | 0.208 | +0.071 | 38 |
| [L1_classic](levels/big/L1_classic.png) | 0.0 | 2.5 | 0.47 | 0.62 | 0.233 | +0.028 | 55 |
| [L1_diorama](levels/big/L1_diorama.png) | 0.0 | 1.0 | 0.53 | 0.64 | 0.240 | +0.030 | 52 |
| [L1_diorama_mid](levels/big/L1_diorama_mid.png) | 0.0 | 9.7 | 0.15 | 0.51 | 0.188 | +0.006 | 36 |
| [L1_fp_ceiling](levels/big/L1_fp_ceiling.png) | 0.0 | 0.1 | 0.59 | 0.55 | 0.198 | +0.021 | 55 |
| [L1_fp_corner](levels/big/L1_fp_corner.png) | 1.0 | 5.8 | 0.35 | 0.50 | 0.180 | +0.058 | 50 |
| [L1_fp_inside](levels/big/L1_fp_inside.png) | 0.1 | 5.3 | 0.35 | 0.58 | 0.238 | +0.014 | 59 |
| [L1_fp_street](levels/big/L1_fp_street.png) | 0.0 | 3.8 | 0.43 | 0.58 | 0.213 | +0.044 | 57 |
| [L1_fp_up](levels/big/L1_fp_up.png) | 1.3 | 6.3 | 0.31 | 0.50 | 0.175 | +0.047 | 59 |
| [L1_street_wide](levels/big/L1_street_wide.png) | 0.0 | 0.6 | 0.36 | 0.43 | 0.177 | +0.056 | 60 |
| [L5_classic](levels/big/L5_classic.png) | 0.0 | 2.3 | 0.50 | 0.57 | 0.208 | +0.090 | 44 |
| [L5_diorama](levels/big/L5_diorama.png) | 0.0 | 0.7 | 0.56 | 0.63 | 0.228 | +0.082 | 37 |
| [L5_diorama_mid](levels/big/L5_diorama_mid.png) | 0.0 | 5.2 | 0.18 | 0.55 | 0.214 | +0.057 | 9 |
| [L5_fp_ceiling](levels/big/L5_fp_ceiling.png) | 0.0 | 0.0 | 0.53 | 0.53 | 0.199 | +0.044 | 29 |
| [L5_fp_street](levels/big/L5_fp_street.png) | 0.0 | 3.6 | 0.45 | 0.62 | 0.216 | +0.118 | 41 |
| [L5_fp_up](levels/big/L5_fp_up.png) | 1.9 | 8.4 | 0.41 | 0.54 | 0.191 | +0.093 | 51 |
| [L6_classic](levels/big/L6_classic.png) | 0.0 | 3.3 | 0.57 | 0.67 | 0.249 | +0.020 | 30 |
| [L6_diorama](levels/big/L6_diorama.png) | 0.0 | 1.3 | 0.58 | 0.66 | 0.243 | +0.024 | 32 |
| [L6_diorama_mid](levels/big/L6_diorama_mid.png) | 0.0 | 2.6 | 0.28 | 0.65 | 0.256 | -0.020 | 22 |
| [L6_fp_ceiling](levels/big/L6_fp_ceiling.png) | 0.0 | 0.0 | 0.61 | 0.43 | 0.165 | -0.019 | 23 |
| [L6_fp_street](levels/big/L6_fp_street.png) | 0.1 | 7.9 | 0.58 | 0.67 | 0.251 | +0.032 | 16 |
| [L6_fp_up](levels/big/L6_fp_up.png) | 1.0 | 7.7 | 0.35 | 0.54 | 0.223 | +0.029 | 24 |
| [L6_street_wide](levels/big/L6_street_wide.png) | 0.0 | 1.3 | 0.59 | 0.45 | 0.168 | +0.033 | 10 |

| Site / camera | WORLD 2.0 (spread / RMS / pink / near-black) | BIG (spread / RMS / pink / near-black) |
|---|---|---|
| L1_diorama | 0.62 / 0.225 / +0.060 / 0.0 % | 0.64 / 0.240 / +0.030 / 0.0 % |
| L1_classic | 0.54 / 0.215 / +0.044 / 0.0 % | 0.62 / 0.233 / +0.028 / 0.0 % |
| L1_diorama_mid | 0.54 / 0.213 / +0.052 / 0.0 % | 0.51 / 0.188 / +0.006 / 0.0 % |
| L5_diorama | 0.62 / 0.227 / +0.094 / 0.0 % | 0.63 / 0.228 / +0.082 / 0.0 % |
| L5_classic | 0.54 / 0.211 / +0.101 / 0.0 % | 0.57 / 0.208 / +0.090 / 0.0 % |
| L5_diorama_mid | 0.57 / 0.226 / +0.061 / 0.0 % | 0.55 / 0.214 / +0.057 / 0.0 % |
| L6_diorama | 0.66 / 0.251 / +0.054 / 0.0 % | 0.66 / 0.243 / +0.024 / 0.0 % |
| L6_classic | 0.67 / 0.244 / +0.053 / 0.0 % | 0.67 / 0.249 / +0.020 / 0.0 % |
| L6_diorama_mid | 0.67 / 0.271 / +0.001 / 0.0 % | 0.65 / 0.256 / -0.020 / 0.0 % |
| GA_diorama | 0.64 / 0.240 / +0.056 / 0.0 % | 0.67 / 0.249 / +0.011 / 0.0 % |

**The bar, honestly:**
- **Near-black ≤ 3 %: met in every frame** (0.0 % in every diorama, classic and interior frame; 1.0-1.9 % in the
  street frames that look up, all of it the sky's zenith in the proxy, not a building; the garage yard 1.7 %).
- **Value contrast back, less pink:** against the WORLD 2.0 after-frames of the same sites and cameras, the value spread
  holds or rises (L1 classic 0.54 → 0.62, garage diorama 0.64 → 0.67, L6 unchanged at 0.66-0.67) and the pink /
  lavender cast halves (L1 diorama +0.060 → +0.030, L6 +0.054 → +0.024, garage +0.056 → +0.011). The Toy Shop stays
  the pinkest site (+0.08-0.12): its candy street and raspberry store are pink by design. Mid-run dioramas lose a
  little spread (L1 0.54 → 0.51): the dollhouse view shows more of the darker interior and less bright town.
- **First person never sees sky indoors:** the engine look-up check passes on every launch level and two dailies (77-151
  spots each), and every `fp_ceiling` / `fp_inside` frame shows the coffered ceiling with the lamps hanging from it.
- **The cameras still see in:** the cut-away opens the shop at the L1 spawn (plate A visible in `L1_diorama`, engine-checked),
  the dollhouse mid-run on every site, and the client_engine checks pass for the Line-up, the L5 intro and the 8 OF ME
  pull-back.

**Self-critique and scores (0-10, "huge, thought through, never black"):**
- **L1-L4 / dailies, Corner Shop, 8:** from the street the shop is now the ground floor of a red-brick tenement with a fire
  escape, lit flats with curtains, a cornice under snow and light strings, between 5-7 storey neighbours; inside, a warm
  coffered ceiling with the lamps hanging from it. Down: every Corner Shop level is the same tenement (only the brick
  colour varies by seed); the town's window Textures are flat next to the kit facade; the blade sign is small.
- **L5, Toy Shop, 7.5:** the department store's big lit sign and the soldier on the roof read as a landmark; the street is
  very pink (by theme) and the store's cream body against candy neighbours is busy.
- **L6 / Bank dailies, 8.5:** the strongest silhouette: a stone temple front with a giant order, the bank's name and a
  pediment over the street; the plaza across. Down: the column plinths read dark in the proxy; the clock is small from the
  street.
- **Garage, 8:** a real warehouse: trusses and skylights overhead, the clerestory, the mezzanine over the vans, the TV, the
  crew sign, the big roll-up door to the snowy yard. Down: the clerestory panes are plain dark blue from inside; the
  stations are dressing only until the LOBBY track builds them.
- **Risks:** the cut-away's feel in Studio (fade speed, the dollhouse at the street spawn, the classic camera above a roof);
  the filmic proxy is uncalibrated; the Texture tiling origin of the town's window grids vs their Neon panes (the grid is
  sized in whole bays and storeys, so either origin lines up, unverified); tier 4's triangle estimate stays over budget
  (PERF.md §9).

**Engine (Saved v76, after merging main):** engine_smoke 170 ok / 0 (section 11: the BIG buildings on 8 sites, the
warehouse checks), client_engine 56 / 0, clone_engine 0 failures, perf_engine 0 failures (section E), kit_engine 503 ok / 0.

## 13. INTERIORS (2026-11-13): eye level, the light in first person, each level its own shop

The Steam-quality review (`docs/audit/REVIEW_STEAM_PLUS.md` gaps 8, 9 and 12): in first person the interiors were
empty painted boxes (`big/L1_fp_inside.png`: a counter, a door, two pendants and a plate); the unlit floor pools read
as painted fog at eye level; the white coffered ceiling was the brightest plane (L1_fp_ceiling median 0.59); and
L1-L4 plus the first daily vault shared one shop front and looked the same. Do-not-touch respected: no sim data, no
exterior storeys or cut-away change, no aurora, no Gus beats, **no Lighting service retune** (local lights, pools and
materials only).

### 13.1 What changed

- **Props at eye level in every room** (server `Heist/DecorPlan`, pure; STYLE_BIBLE §19; kit `assets/blender/interior.py`,
  6 new groups, new ids): Corner Shop fronts get stocked shelves (boxes, tins, jars), a drinks fridge with a glass door
  and a warm strip, a candy counter, a magazine rack, a cat bed with a sleeping tabby, posters, a clock, a Christmas
  card string; back rooms boxes, a mop bucket, coat hooks with coats, a corkboard with Gus's donut list, a desk with a
  lamp; the Toy Shop toy shelves (teddies, trains, blocks, boxed dolls), a gift-wrap table, a train loop, a rocking
  horse, giant candy canes; the Bank potted palms, marble benches, a queue rope, the waiting-room tree, deposit-box
  walls and **teller brass** on the teller counters. Every prop backs onto a wall (the middle of each room stays open),
  never on a plate, door approach, loot point, hide, laser, switch, Gus's route, a floor cable, the van zone or the
  sightline from the crew seat to a plate, door or the goal. Unit spec `HeistInterior` (9 tests, every launch level and
  daily vault, Christmas layer on and off): no overlap with a sim box, and a 0.5-stud walk grid still reaches every
  plate, door, loot point and hide with the props, by at most a 3-stud detour. 39-52 props per level, 10-15k tris.
- **Each level its own shop** (`Config.Interior.THEMES`): L1 **Pip's Grocery** (fruit stand in the window, green frieze),
  L2 **Sugar & Crumb Bakery** (cake stands, rose frieze, peach light), L3 **Tick-Tock Toy Repair** (workbench with a
  half-mended teddy and a wind-up robot, toy shelves, teal frieze, a deeper and dimmer amber), L4 **Night Owl Pharmacy**
  (dispensing counter with a green cross, mint frieze, cool white light), DV01 **Big Cheese Deli** (deli case with
  salamis); the other Corner Shop dailies rotate deli, jeweller, grocer, bakery, pharmacy, toy repair; L5 Hoardsworth's
  Toys, L6 and the bank dailies Hoardsworth & Co. Each: the name on the front's sign board (the fascia, a SurfaceGui on
  the board the Storefront mesh always had) and on the BIG blade sign, a hero display in the window beside the door, a
  tinted frieze under the crown, the ceiling colour and the room light colour.
- **The ceiling:** the BIG tile in a tintable copy (`Ceiling_8x8_Tin`) in the level's ceiling colour (its luma never
  above the location's wall cell); the lamp fixtures stay the brightest thing overhead.
- **The walls carry the light:** warm SpotLight wall washes (`LAMP.wash`, no shadows, no fixture) on each room band's side
  walls and far partition, kept only while every view stays <= 9 lights; tier 1 only (off from tier 2).
- **Pools in first person:** client `LightDirector` fades every floor pool by the camera's elevation over it (0.30 of its
  strength looking across it, 0.62 standing in it, 1 from the diorama and classic heights); the diorama looks unchanged.
- **Tiers:** props, the teller brass and the frieze hide from tier 3; the hero display, ceiling, light and fascia stay.

### 13.2 Measured

`python3 tools/blender/level_shots.py --interiors` (one Blender process per shot, 960 x 444, the filmic proxy, graded
with `frame_grade` plus a surface mask: ceiling / wall luma, and the plates' and loot's A1 value pop over their
surround). First person from the eye (3.8): at the spawn, just inside the front, toward the left wall, from the back
of the front room toward the window, up at the ceiling (32°), at the loot and beside it looking across its room, the
shop from the street; then the diorama and classic at the spawn and the diorama mid-run. `--before` renders the same
level without this track. Folder `docs/audit/levels/interiors/` with `grades.json`, `surfaces.json` and the
[contact sheet](levels/interiors/contact_sheet.png).

**Before → after** (the same camera, `--before` = without this track):

| Site / shot | near-black % | median luma | value spread | warm % | ceiling / wall luma | props' share of the frame % |
|---|---|---|---|---|---|---|
| L1 fp_front | 0.00 → 0.03 | 0.35 → 0.28 | 0.59 → 0.54 | 59 → 52 | 3.7 → 0.54 | 0 → 13.1 |
| L1 fp_left | 0.40 → 0.31 | 0.34 → 0.32 | 0.63 → 0.57 | 59 → 55 | 3.26 → 0.62 | 0 → 17.7 |
| L1 fp_ceiling | 0.00 → 0.00 | 0.49 → 0.15 | 0.56 → 0.54 | 47 → 38 | 4.84 → 0.53 | 0 → 7.1 |
| L2 fp_front | 0.00 → 0.00 | 0.36 → 0.30 | 0.65 → 0.56 | 55 → 43 | 3.36 → 0.54 | 0 → 12.3 |
| L2 fp_left | 0.04 → 0.01 | 0.47 → 0.37 | 0.69 → 0.59 | 51 → 46 | 3.08 → 0.65 | 0 → 17.2 |
| L2 fp_ceiling | 0.00 → 0.00 | 0.51 → 0.19 | 0.60 → 0.52 | 66 → 44 | 4.74 → 0.58 | 0 → 15.8 |
| L3 fp_front | 0.00 → 0.00 | 0.39 → 0.30 | 0.65 → 0.54 | 57 → 51 | 3.29 → 0.4 | 0 → 15.6 |
| L3 fp_left | 0.13 → 0.00 | 0.30 → 0.33 | 0.68 → 0.57 | 54 → 50 | 3.05 → 0.39 | 0 → 21.7 |
| L3 fp_ceiling | 0.00 → 0.00 | 0.49 → 0.14 | 0.57 → 0.50 | 60 → 38 | 4.47 → 0.44 | 0 → 9.7 |
| L4 fp_front | 0.00 → 0.00 | 0.43 → 0.36 | 0.68 → 0.56 | 51 → 35 | 3.26 → 0.57 | 0 → 13.9 |
| L4 fp_left | 0.10 → 0.00 | 0.30 → 0.33 | 0.70 → 0.60 | 52 → 33 | 3.08 → 0.7 | 0 → 14.0 |
| L4 fp_ceiling | 0.00 → 0.00 | 0.49 → 0.17 | 0.58 → 0.49 | 59 → 33 | 4.56 → 0.57 | 0 → 12.0 |
| DV01 fp_front | 0.00 → 0.00 | 0.36 → 0.33 | 0.65 → 0.53 | 54 → 53 | 3.33 → 0.56 | 0 → 12.9 |
| DV01 fp_left | 0.02 → 0.00 | 0.30 → 0.34 | 0.70 → 0.58 | 53 → 54 | 3.2 → 0.49 | 0 → 23.6 |
| DV01 fp_ceiling | 0.00 → 0.00 | 0.51 → 0.17 | 0.58 → 0.49 | 69 → 49 | 4.49 → 0.57 | 0 → 15.2 |
| L6 fp_front | 0.26 → 0.40 | 0.45 → 0.29 | 0.60 → 0.50 | 25 → 22 | 2.53 → 0.37 | 0 → 1.9 |
| L6 fp_left | 0.00 → 0.00 | 0.32 → 0.28 | 0.59 → 0.57 | 13 → 9 | 3.3 → 0.62 | 0 → 5.4 |
| L6 fp_ceiling | 0.00 → 0.00 | 0.57 → 0.34 | 0.62 → 0.61 | 21 → 10 | 2.42 → 0.37 | 0 → 1.5 |

**Every after frame:**

| Frame | near-black % | dark % | median luma | value spread | warm % | ceiling / wall | plate pop | loot pop |
|---|---|---|---|---|---|---|---|---|
| [DV01_classic](levels/interiors/DV01_classic.png) | 0.00 | 1.6 | 0.61 | 0.62 | 47 | - | - | - |
| [DV01_diorama](levels/interiors/DV01_diorama.png) | 0.00 | 0.4 | 0.58 | 0.62 | 49 | - | - | - |
| [DV01_fp_ceiling](levels/interiors/DV01_fp_ceiling.png) | 0.00 | 1.1 | 0.17 | 0.49 | 49 | 0.57 | - | - |
| [DV01_fp_front](levels/interiors/DV01_fp_front.png) | 0.00 | 1.9 | 0.33 | 0.53 | 53 | 0.56 | 0.27 | - |
| [DV01_fp_left](levels/interiors/DV01_fp_left.png) | 0.00 | 2.9 | 0.34 | 0.58 | 54 | 0.49 | - | -0.23 |
| [DV01_fp_loot](levels/interiors/DV01_fp_loot.png) | 0.00 | 7.0 | 0.23 | 0.60 | 88 | - | - | -0.49 |
| [DV01_fp_spawn](levels/interiors/DV01_fp_spawn.png) | 0.00 | 4.2 | 0.32 | 0.53 | 19 | 0.36 | 0.32 | -0.41 |
| [DV01_fp_street](levels/interiors/DV01_fp_street.png) | 1.23 | 7.7 | 0.34 | 0.56 | 36 | 0.36 | - | -0.31 |
| [L1_classic](levels/interiors/L1_classic.png) | 0.00 | 1.6 | 0.48 | 0.62 | 56 | - | - | - |
| [L1_diorama](levels/interiors/L1_diorama.png) | 0.00 | 0.8 | 0.54 | 0.63 | 52 | - | - | - |
| [L1_diorama_mid](levels/interiors/L1_diorama_mid.png) | 0.00 | 2.0 | 0.36 | 0.58 | 54 | - | -0.02 | - |
| [L1_fp_ceiling](levels/interiors/L1_fp_ceiling.png) | 0.00 | 2.2 | 0.15 | 0.54 | 38 | 0.53 | - | - |
| [L1_fp_front](levels/interiors/L1_fp_front.png) | 0.03 | 2.5 | 0.28 | 0.54 | 52 | 0.54 | 0.27 | - |
| [L1_fp_left](levels/interiors/L1_fp_left.png) | 0.31 | 4.0 | 0.32 | 0.57 | 55 | 0.62 | - | - |
| [L1_fp_loot](levels/interiors/L1_fp_loot.png) | 0.68 | 6.6 | 0.20 | 0.50 | 56 | 0.80 | - | 0.16 |
| [L1_fp_loot_round](levels/interiors/L1_fp_loot_round.png) | 0.18 | 10.4 | 0.19 | 0.50 | 51 | 0.87 | - | - |
| [L1_fp_spawn](levels/interiors/L1_fp_spawn.png) | 0.01 | 4.3 | 0.34 | 0.50 | 31 | 0.35 | 0.31 | - |
| [L1_fp_street](levels/interiors/L1_fp_street.png) | 1.19 | 7.8 | 0.37 | 0.56 | 38 | 0.36 | - | - |
| [L1_fp_window](levels/interiors/L1_fp_window.png) | 0.11 | 3.4 | 0.29 | 0.55 | 48 | 0.51 | 0.21 | - |
| [L2_classic](levels/interiors/L2_classic.png) | 0.00 | 1.5 | 0.49 | 0.62 | 55 | - | - | - |
| [L2_diorama](levels/interiors/L2_diorama.png) | 0.00 | 0.6 | 0.58 | 0.62 | 50 | - | - | - |
| [L2_diorama_mid](levels/interiors/L2_diorama_mid.png) | 0.00 | 0.9 | 0.40 | 0.61 | 47 | - | -0.01 | - |
| [L2_fp_ceiling](levels/interiors/L2_fp_ceiling.png) | 0.00 | 0.6 | 0.19 | 0.52 | 44 | 0.58 | - | - |
| [L2_fp_front](levels/interiors/L2_fp_front.png) | 0.00 | 2.4 | 0.30 | 0.56 | 43 | 0.54 | 0.28 | - |
| [L2_fp_left](levels/interiors/L2_fp_left.png) | 0.01 | 2.2 | 0.37 | 0.59 | 46 | 0.65 | 0.22 | -0.34 |
| [L2_fp_loot](levels/interiors/L2_fp_loot.png) | 0.46 | 11.3 | 0.20 | 0.52 | 58 | - | - | 0.17 |
| [L2_fp_loot_round](levels/interiors/L2_fp_loot_round.png) | 1.41 | 19.9 | 0.14 | 0.39 | 65 | 0.80 | - | - |
| [L2_fp_spawn](levels/interiors/L2_fp_spawn.png) | 0.00 | 5.4 | 0.35 | 0.55 | 22 | 0.36 | 0.31 | -0.41 |
| [L2_fp_street](levels/interiors/L2_fp_street.png) | 1.18 | 7.5 | 0.37 | 0.57 | 37 | 0.38 | 0.16 | -0.33 |
| [L2_fp_window](levels/interiors/L2_fp_window.png) | 0.01 | 2.2 | 0.32 | 0.59 | 41 | 0.52 | 0.20 | -0.38 |
| [L3_classic](levels/interiors/L3_classic.png) | 0.00 | 1.5 | 0.57 | 0.61 | 56 | - | - | - |
| [L3_diorama](levels/interiors/L3_diorama.png) | 0.00 | 0.7 | 0.57 | 0.62 | 53 | - | - | - |
| [L3_diorama_mid](levels/interiors/L3_diorama_mid.png) | 0.00 | 1.1 | 0.40 | 0.59 | 56 | - | -0.02 | - |
| [L3_fp_ceiling](levels/interiors/L3_fp_ceiling.png) | 0.00 | 30.4 | 0.14 | 0.50 | 38 | 0.44 | - | - |
| [L3_fp_front](levels/interiors/L3_fp_front.png) | 0.00 | 4.6 | 0.30 | 0.54 | 51 | 0.40 | 0.25 | - |
| [L3_fp_left](levels/interiors/L3_fp_left.png) | 0.00 | 8.1 | 0.33 | 0.57 | 50 | 0.39 | - | -0.17 |
| [L3_fp_loot](levels/interiors/L3_fp_loot.png) | 1.35 | 12.3 | 0.12 | 0.55 | 56 | - | - | 0.59 |
| [L3_fp_loot_round](levels/interiors/L3_fp_loot_round.png) | 0.41 | 16.7 | 0.13 | 0.41 | 54 | 0.71 | - | - |
| [L3_fp_spawn](levels/interiors/L3_fp_spawn.png) | 0.00 | 6.9 | 0.30 | 0.53 | 28 | 0.25 | 0.30 | -0.29 |
| [L3_fp_street](levels/interiors/L3_fp_street.png) | 1.18 | 8.4 | 0.36 | 0.57 | 37 | 0.30 | - | -0.25 |
| [L3_fp_window](levels/interiors/L3_fp_window.png) | 0.01 | 4.0 | 0.31 | 0.55 | 46 | 0.42 | 0.20 | -0.31 |
| [L4_classic](levels/interiors/L4_classic.png) | 0.00 | 1.5 | 0.58 | 0.61 | 53 | - | - | - |
| [L4_diorama](levels/interiors/L4_diorama.png) | 0.00 | 0.4 | 0.59 | 0.62 | 47 | - | - | - |
| [L4_diorama_mid](levels/interiors/L4_diorama_mid.png) | 0.00 | 0.7 | 0.42 | 0.61 | 45 | - | -0.02 | - |
| [L4_fp_ceiling](levels/interiors/L4_fp_ceiling.png) | 0.00 | 0.8 | 0.17 | 0.49 | 33 | 0.57 | - | - |
| [L4_fp_front](levels/interiors/L4_fp_front.png) | 0.00 | 2.1 | 0.36 | 0.56 | 35 | 0.57 | 0.24 | - |
| [L4_fp_left](levels/interiors/L4_fp_left.png) | 0.00 | 4.2 | 0.33 | 0.60 | 33 | 0.70 | - | -0.30 |
| [L4_fp_loot](levels/interiors/L4_fp_loot.png) | 0.27 | 7.8 | 0.23 | 0.52 | 61 | - | - | 0.48 |
| [L4_fp_loot_round](levels/interiors/L4_fp_loot_round.png) | 0.30 | 21.4 | 0.13 | 0.40 | 63 | 0.92 | - | - |
| [L4_fp_spawn](levels/interiors/L4_fp_spawn.png) | 0.00 | 3.0 | 0.42 | 0.53 | 12 | 0.37 | 0.28 | -0.04 |
| [L4_fp_street](levels/interiors/L4_fp_street.png) | 1.18 | 7.6 | 0.40 | 0.57 | 33 | 0.39 | - | -0.25 |
| [L4_fp_window](levels/interiors/L4_fp_window.png) | 0.00 | 1.9 | 0.34 | 0.58 | 30 | 0.57 | 0.21 | -0.38 |
| [L5_classic](levels/interiors/L5_classic.png) | 0.00 | 1.4 | 0.51 | 0.56 | 46 | - | - | - |
| [L5_diorama](levels/interiors/L5_diorama.png) | 0.00 | 0.6 | 0.58 | 0.61 | 39 | - | - | - |
| [L5_fp_ceiling](levels/interiors/L5_fp_ceiling.png) | 0.00 | 2.3 | 0.20 | 0.40 | 10 | 0.18 | - | - |
| [L5_fp_front](levels/interiors/L5_fp_front.png) | 0.00 | 7.1 | 0.23 | 0.56 | 29 | 0.68 | - | 0.12 |
| [L5_fp_left](levels/interiors/L5_fp_left.png) | 0.02 | 5.1 | 0.23 | 0.56 | 11 | 0.59 | - | 0.31 |
| [L5_fp_loot](levels/interiors/L5_fp_loot.png) | 0.51 | 9.2 | 0.24 | 0.58 | 24 | 0.83 | - | -0.21 |
| [L5_fp_spawn](levels/interiors/L5_fp_spawn.png) | 0.00 | 5.4 | 0.32 | 0.55 | 11 | 0.30 | - | 0.11 |
| [L5_fp_street](levels/interiors/L5_fp_street.png) | 1.14 | 8.6 | 0.43 | 0.58 | 32 | 0.32 | - | 0.08 |
| [L6_classic](levels/interiors/L6_classic.png) | 0.04 | 2.5 | 0.58 | 0.66 | 29 | - | - | - |
| [L6_diorama](levels/interiors/L6_diorama.png) | 0.00 | 1.1 | 0.59 | 0.65 | 32 | - | - | - |
| [L6_fp_ceiling](levels/interiors/L6_fp_ceiling.png) | 0.00 | 1.2 | 0.34 | 0.61 | 10 | 0.37 | - | - |
| [L6_fp_front](levels/interiors/L6_fp_front.png) | 0.40 | 2.6 | 0.29 | 0.50 | 22 | 0.37 | - | 0.12 |
| [L6_fp_left](levels/interiors/L6_fp_left.png) | 0.00 | 2.9 | 0.28 | 0.57 | 9 | 0.62 | 0.32 | - |
| [L6_fp_loot](levels/interiors/L6_fp_loot.png) | 0.29 | 9.8 | 0.37 | 0.56 | 16 | - | - | 0.06 |
| [L6_fp_spawn](levels/interiors/L6_fp_spawn.png) | 0.18 | 4.6 | 0.32 | 0.53 | 9 | 0.27 | - | -0.22 |
| [L6_fp_street](levels/interiors/L6_fp_street.png) | 1.42 | 11.7 | 0.34 | 0.60 | 15 | 0.62 | - | - |

**The bar, honestly:**
- **Near-black <= 3 %: met in every frame** (max 1.42 %, the street frames' sky as before; every interior frame <= 1.4 %).
  L3 "Lights Out" is the darkest site by design (dark share 30 % in `fp_ceiling`, 8-17 % round the room) but never
  near-black.
- **The ceiling no longer outshines the walls:** ceiling / wall luma in the front rooms 3.0-4.8 → **0.39-0.70**
  (fp_ceiling 0.44-0.58, the review's ~0.6x), the back rooms 0.71-0.92 (no far-wall wash there on every level); the
  Bank 2.4-3.3 → 0.37-0.62. The lamp fixtures stay the brightest thing overhead.
- **No room reads empty at eye level:** props fill 7-24 % of a Corner Shop first-person frame (0 before); every room
  band of every level has props (unit spec), 39-52 per level.
- **Signals stay the clearest:** plate rings pop +0.16-0.32 over their surround in the first-person frames (A1 >= 0.15);
  the focal loot pops +0.16 to +0.59 where the frame isolates it (L1 0.16, L2 0.17, L3 0.59, L4 0.48). The loot pops
  that read negative (DV01 -0.49, some spawn frames) measure the cash ID group, which includes the loot's dark display
  stand (frame_grade's ID table): in the frames the present, the gold and the bags are the brightest saturated things
  (looked at, every frame). In the diorama mid-run the idle plates pop -0.01 to -0.02 against their own lamp's pool,
  as before this track (the pools are unchanged from above).
- **Cost of the look:** the first-person value spread drops (0.56-0.70 → 0.49-0.60) and the warm share in the front
  rooms falls (L4 51 → 35 %, the pharmacy's cool white by design; L1 59 → 52 %): the bright cream ceiling and pools were
  a large share of the "warm" and the "spread". Median luma in the ceiling views 0.49-0.57 → 0.14-0.34.

**Self-critique and scores (0-10, "a room you would stand in, in first person"):**
- **L1 Pip's Grocery, 7.5** (before 4): stocked shelves, a fridge, the candy counter, the cat bed and the cards fill the
  front; the fruit stand dresses the right window; the dark coffers sit under the walls. Down: the props are boxy at
  arm's length, and the back room is sparser (desk, boxes, corkboard).
- **L2 Sugar & Crumb Bakery, 7.5**: rose frieze and peach light read as a bakery; the cake stands are the most charming
  prop. Down: a cake stand stands mid-wall by the door, not in the window, so the street sees shelves.
- **L3 Tick-Tock Toy Repair, 7**: darker, deeper amber and the toy shelves give it a different mood; still readable.
  Down: "dramatic" is mostly the dim light; no hero light on the workbench.
- **L4 Night Owl Pharmacy, 7.5**: the cool white light, mint frieze and grey ceiling make the strongest change of mood.
- **DV01 Big Cheese Deli, 7**: same shell, its own sign, case and red frieze.
- **L5 Hoardsworth's Toys, 6.5**: the party level's gondolas, loot and nav lanes leave room only for canes, a rocking
  horse and wall props in the front; the office is dressed.
- **L6 Hoardsworth & Co., 7.5**: the teller brass with its plaques, the queue rope, benches, palms and the waiting-room tree
  make the lobby a bank; deposit-box walls in the offices and the vault.
- **Risks / verify in Studio:** the SurfaceGui pool fade's feel when walking (15 Hz steps, smoothstep); the wall washes
  are tier 1 only (a phone at tier 2 sees the darker ceiling but not the washes); the fridge strip's bloom; the fascia
  text size on a phone; tintable MeshParts' colour against the filmic tone map (the proxy is uncalibrated).
