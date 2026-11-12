# Asset log

One row per asset. Every asset passes the hard gates (A1-A18 plus the Echo Heist gates; see STYLE_BIBLE §10). Then it is scored on the visual rubric V1-V9 (0-2 each), shown two ways that are never mixed: **/18** is the plain sum (the launch-kit bar: **≥ 16/18 with no zero**), **0-10** is the LihFolk quality score (`quality-score/rubrics/model.md`: V1 x3, V2-V5 x2, V6-V9 x1, `10 x sum(w x p / 2) / sum(w)`; bar **≥ 8.5**). An asset passes when it clears both.

- Scores come from the turntable sheets in `docs/art/turntables/<Asset>.png`. Those sheets are rendered from the **exported FBX** after a re-import, so they show what Studio will get. Claude read every sheet; assets that changed after a sheet was read were re-rendered and re-read.
- Kit context (V8 "matches the kit"): `docs/art/turntables/KitPreview_CornerShop.png`, `KitPreview_Bank.png`, `KitPreview_ToyShop.png` (each with a B3 top-down flat tile), `KitPreview_Street.png`, `KitPreview_BankStreet.png` (Christmas dressing off and on), `KitPreview_Tree.png` (the decorated advent tree) and the index `KitPreview.png`. Close-ups: `VaultDoor_DialFace_closeup.png`, `Ornaments_closeup.png`.
- Gate reports are in `assets/fbx/<Asset>.gate.json`. Every asset of this pass: **GATES PASS** (`python3 tools/blender/build_asset.py --all`).
- **Scoring rule v0:** V9 (Studio-ready) is capped at **1** until spike S2 proves size, pivot and collision in a real Studio import (`docs/art/KIT_IMPORT.md`, `tests/kit_check.luau`).
- Scores are Claude's self-review. Hero and borderline assets still need the blind Art Director review (`lihfolk:council-method`, Quick); see "Open".

Rubric key:

| | Criterion | | Criterion | | Criterion |
|---|---|---|---|---|---|
| V1 | silhouette at 64 px | V4 | bevels | V7 | geometry economy |
| V2 | big / medium / small hierarchy | V5 | shading | V8 | matches the kit |
| V3 | proportion | V6 | palette | V9 | Studio-ready |

## Launch kit v1 (2026-11-12, Blender 5.3 `bpy`)

**Pass 2 (review fixes, same day):** 50 FBX files, 92 MeshParts, 45,166 triangles. New: `Present`, `Candy`, `Toy`, `Teddy` (every LevelSpec loot kind now has a mesh), `Shutter_8x10`, `BankFront_24x12`, `Shelf_Gondola_8x2`, `Hide_CoatStand`, `Hide_DepositStack`. Remade: `Hide_Plant`, `Hide_CoatRack`, `Hide_Crate`, `Xmas_SnowPile`, tintable ornaments. Atlas: lighter wood in every location, Toy Shop walls navy (palette rule R1). Every FBX was re-exported once (the atlas is embedded); from now on unchanged assets keep their files (content hash).

Pass 1: 41 FBX files, 83 MeshParts, 38,454 triangles in all (Gus 3,488 in 18 rigid parts; vault door 8,156 in 5 parts). The meshes are location-neutral: Corner Shop, Toy Shop and Bank differ only by the atlas (STYLE_BIBLE §1.4). The bank kit v0 names are gone: `Bank_Wall_*` became `Wall_*`, `VaultDoor_Greybox` became `VaultDoor` (golden pass). Turntable = `docs/art/turntables/<Asset>.png`.

### Modules (location atlas swap)

| Asset (FBX) | MeshParts (tris) | Class | Tris | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | V9 | **/18** | **0-10** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Wall_4x12 | Wall_4x12 196 | module | 196 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Wall_8x12 | Wall_8x12 284 | module | 284 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Wall_Window_8x12 | Wall_Window_8x12 768, Glass 12 | module | 780 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Wall_Door_8x12 | Wall_Door_8x12 664, Leaf 508 | module | 1,172 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Pillar_2x12 | Pillar_2x12 324 | module | 324 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Storefront_24x12 | Storefront_24x12 1980, Glass 24 | medium | 2,004 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Floor_8x8 | Floor_8x8 144 | module | 144 | 2 | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Counter_4x4 | Counter_4x4 208 | module | 208 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Counter_8x4 | Counter_8x4 316 | module | 316 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Counter_8x2 | Counter_8x2 244 | module | 244 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Shelf_8x2 | Shelf_8x2 776 | module | 776 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Lamp_Ceiling | Lamp_Ceiling 568, Bulb 120 | small | 688 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| TellerCounter_8x4 | TellerCounter_8x4 412, Glass 24 | module | 436 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| BankFront_24x12 | BankFront_24x12 2244 | medium | 2,244 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 2 | 1 | **16** | **9.3** |
| Shelf_Gondola_8x2 | Shelf_Gondola_8x2 744 | module | 744 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |

### Mechanisms, hiding spots, props

| Asset (FBX) | MeshParts (tris) | Class | Tris | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | V9 | **/18** | **0-10** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Plate_4x4 | Plate_4x4 484, Ring 288 | small | 772 | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **16** | **8.7** |
| Switch_Wall | Switch_Wall 224, Lamp 58, Lever 172 | small | 454 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| LaserEmitter | LaserEmitter 428, Lens 200 | small | 628 | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **16** | **8.7** |
| Hide_Crate | Hide_Crate 552 | small | 552 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Hide_Plant | Hide_Plant 568 | small | 568 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Hide_Curtain | Hide_Curtain 468 | small | 468 | 1 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **15** | **8.0** |
| Hide_CoatRack | Hide_CoatRack 544 | small | 544 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Safe | Safe 452, Door 548 | small | 1,000 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Van | Van 1856, Shelf 124 | medium | 1,980 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| CashBag | CashBag 600 | small | 600 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| GoldBar | GoldBar 52 | small | 52 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| GoldStack | GoldStack 312 | small | 312 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Diamond | Diamond 94 | small | 94 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **16** | **9.3** |
| Shutter_8x10 | Shutter_8x10 556 | small | 556 | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **16** | **8.7** |
| Hide_CoatStand | Hide_CoatStand 572 | small | 572 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Hide_DepositStack | Hide_DepositStack 696 | module | 696 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Present | Present 388 | small | 388 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Candy | Candy 336 | small | 336 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Toy | Toy 580 | small | 580 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Teddy | Teddy 596 | small | 596 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |

### Hero props

| Asset (FBX) | MeshParts (tris) | Class | Tris | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | V9 | **/18** | **0-10** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| VaultDoor | 5 | hero | 8,156 | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **16** | **8.7** |
| CashRegister | CashRegister 1032, Drawer 488 | hero | 1,520 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Pedestal_Diamond | Pedestal_Diamond 528, Case 60 | small | 588 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| GiantPresent | GiantPresent 1380 | hero | 1,380 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |

### Christmas dressing layer

| Asset (FBX) | MeshParts (tris) | Class | Tris | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | V9 | **/18** | **0-10** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Xmas_Garland_8 | Xmas_Garland_8 736 | module | 736 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Xmas_Lights_8 | Xmas_Lights_8 286, Bulbs 400 | small | 686 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Xmas_Wreath | Xmas_Wreath 548 | small | 548 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Xmas_SnowCap_8 | Xmas_SnowCap_8 512 | small | 512 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Xmas_SnowPile | Xmas_SnowPile 576 | small | 576 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |
| Xmas_Tree | Xmas_Tree 312, Lights 400 | small | 712 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| LaserEmitter_CandyCane | LaserEmitter_CandyCane 888 | medium | 888 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Ornaments | 7 | small | 2,112 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Gus_SantaHat | Gus_SantaHat 360 | small | 360 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |

### Gus v0

| Asset (FBX) | MeshParts (tris) | Class | Tris | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | V9 | **/18** | **0-10** |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Gus | 18 | creature | 3,488 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | **9.7** |
| Gus_DonutBox | Gus_DonutBox 596 | small | 596 | 2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 | 1 | **16** | **9.0** |

### Why the points were lost

| Asset(s) | Points lost |
|---|---|
| All | V9 is 1 until S2 (above) |
| Hide_Curtain | **15/18, 8.0: below both bars** (pass 2 re-score). V1 = 1: from the front (B1, KitPreview_Bank) it reads as a green wall banner, not a curtain with room behind it; V4 = 1 (fabric). No launch level uses a curtain hide; redesign (an alcove or a tie-back that shows the space behind) before one does |
| Shutter_8x10 | **V1 = 1.** A slatted slab: its read is the drop (code) and the entrance it fills |
| BankFront_24x12 | **V7 = 1.** 2,244 tris, over the 2,000 medium target (pilasters, pediment, barred windows) |
| Hide_Plant, Hide_CoatRack, Hide_CoatStand, Candy, Teddy | **V4 = 1.** Leaves, coats, a foil sweet and a plush bear: soft shapes with no chamfers (as the pass-1 soft pieces) |
| VaultDoor | **V1 = 1.** A wall-line piece: its 64 px silhouette is the 16 x 12 frame rectangle from every angle; the round door reads through value inside the outline (as v0) |
| Plate_4x4, LaserEmitter | **V1 = 1.** A floor slab and a post: generic silhouettes. Their read is from above (the ring) and from the lenses and beams (code) |
| Floor_8x8 | **V2 = 1.** One level of detail (four tiles); a floor should stay calm |
| Hide_Curtain, Hide_CoatRack, Xmas_* (garland, lights, wreath, snow), Gus_DonutBox | **V4 = 1.** Soft or organic shapes with no chamfers (fabric, coats, foliage, snow, cardboard). Deliberate, but a reviewer may read it as a break from the chamfered kit |
| Diamond | **V8 = 1.** The one deliberate flat-shaded gem in a chamfered kit (as v0) |

### Iterations (self-review notes, kept so the same mistakes are not repeated)

| Asset | Pass 1 problem | Fix | Result |
|---|---|---|---|
| Storefront | At 16 wide the two display windows were 2.4-stud slots: it read as a gate, not a shop | 24 wide (6 cells), 6.4-stud windows with a mullion, 7-stripe awnings. Still the LevelSpec 8 x 10 entrance | 17 |
| Hide_Curtain | Plum velvet on a plum wall: no contrast, it read as a banner | Green velvet (leaf cells), deeper pleats, a cream hem band in the same mesh (no extra boxes) | 16 |
| Hide_Crate | 4.45 tall: a 5.2-stud avatar's head would poke through the top (hides are walk-in, CanCollide off) | 5.85 tall; the lid leans on the side instead of swinging out 3.5 studs | 17 |
| Hide_Plant | Smaller than the avatar it must hide | Scaled 1.35x (7.8 tall) | 17 (pass 1; wrong, see pass 2) |
| Hide_Plant (pass 2) | Review: the opaque 3.8-wide pot stood on the centre of its hide box, where L6 puts plate B: the pot hid the plate and the hidden avatar stood inside the pot. The pass-1 17 was too generous (V3 should have been 1) | Two planter troughs flanking a 4.2-wide open floor niche over the plate; narrow fronds arch over the open ends (from above the ring shows, B3), the rest stand up; everything within 3 of the plate centre. Fit table: plate ring inside the niche | 16 / 9.0 |
| Hide_CoatRack (pass 2) | 1.8 deep in a 5.5-deep hide box: an actor 3.7 in front of the coats counted as hidden; plate B is under the box | A double garment rack (6 x 4.8): coats on two rails, the plate niche between them; knobs and hooks dropped for the budget | 16 / 9.0 |
| Hide_Crate (pass 2) | 5.7 x 3.2 with the lid leaned out 1.6; 3 deep where the box's back 0.5 is inside the partition | 3.6 x 2.5 body, lid leaned upright (+0.6): 4.4 x 2.7, inside the 4 x 3 box with its back on the partition face | 17 / 9.7 |
| Xmas_SnowPile (pass 2) | Three round mounds read as a lying animal (a head and a tail) at 64 px | One long drift with a heaped back, a snow shovel stuck in it, the snowball stash | 16 / 9.0 |
| Hide_DepositStack | Lining boxes were coplanar with the tower faces (z-fighting moire); open doors stuck 0.65 out of the 6 x 6 box | Lining 0.04 proud of the faces; doors open 15 degrees | 17 / 9.7 |
| Toy, Teddy, hides | First builds 680-924 tris, over the 600 small target (V7) | Fewer segments on spheres and cylinders, no chamfers on tiny boxes | 544-596 |
| Ornament tree (Tree preview) | Full-size ornaments on the 6-tall tree reached the floor and crowded the tiers | `ornamentScale` 0.65 on the tree (full size on the shelf stand) | — |
| Xmas_Garland_8 | A striped tube read as a caterpillar; thin bow tails read as insect legs; the tube folded at the pin cusp (A17) | Overlapping low-poly puffs per swag; chunky bows; one rope per swag; no bow at x = 8 (the next module's x = 0 bow covers that pin, no doubles in a run) | 16 |
| LaserEmitter_CandyCane | Per-face colouring gave staircase stripes | Each ring turns half a segment, so the faces follow the helix: smooth stripes | 17 |
| GiantPresent | Two small bow loops: no bow in the 64 px silhouette | Four loops (two big, two small, tilted outward) | 17 |
| Gus | Santa hat and cap in one model overlapped in the sheet; torch too small for "huge flashlight" | Santa hat is its own model (Christmas layer); torch 1.2x | 17 |
| Gus_DonutBox | The bakery label was on the hidden face of the open lid | Label on the face that turns to the viewer | 16 |
| Lamp_Ceiling | One steel value everywhere | Dark shade, light rim, warm lit inside | 17 |
| Pillar_2x12, snow pieces | V2 1: plain shaft / plain slab / two similar mounds | Raised panels on the shaft; snow lip and drifts; a snowball stash | 17 / 16 |
| Pedestal_Diamond, glass parts | Glass rendered as an opaque slab in the turntable | Turntables draw `_Glass` / `_Case` parts as wire edges (Studio: Glass, Transparency 0.6-0.7) | 17 |
| VaultDoor | Golden pass first build: door 4,296 tris, over the medium ceiling | Bolt heads 6 sides, knobs 10 x 6, hinge 12 sides | 8,156 total, inside the 8-10k golden target |
| Several | Chamfers wider than half a thin box collapsed faces (A5); the tube helper twisted at a reference flip (A17) | `MB.box` clamps the chamfer to 0.45 x the thinnest side; tubes use parallel transport (or a fixed plane normal) | — |

### Measured facts from this pass

- **Pass 2: bmesh face order is not stable between runs** (a face may start at another vertex), so the content hash canonicalises each face (rotated to its lowest vertex, with its colour cell and loop UVs, then sorted). Measured: two builds of `Ornaments` gave the same canonical hash and different raw ones.
- **Integration check (Nov 12): `VaultDoor` still churned on every `--all`** (new FBX, report and turntable each run, gates passing): `Builder.clip` fed `bisect_plane` geometry from Python sets of BMesh elements, which iterate in memory-address order, so the cut verts were numbered differently each run (same vertex set, other order). `clip` now sorts its input by element index; three `--all` runs in a row then leave every file byte-identical.
- **Pass 2: the v1 prepare script could never pass.** In Lune, a `Kit` folder holding Model `CashBag` > MeshPart `CashBag`: `kit:FindFirstChild("CashBag", true)` returns the **Model** (a direct child is found before its descendants); the v2 name map of MeshPart descendants returns the MeshPart. 38 of the 83 v1 pieces share their Model's name.
- **One bpy process per spec.** A headless `bpy` process that builds and renders ~30 assets in a row exits silently (no traceback) partway; so does a multi-scene Eevee run. `build_asset.py --all` and `kit_preview.py` now start one process per spec / scene.
- **Axis mapping of the export** (`axis_forward Z`, `axis_up Y`): a proper rotation, Blender (x, y, z) → Roblox (-x, z, y). Front -Y → Roblox -Z (LookVector), and Blender -X → Roblox +X, which is still the viewer's left when facing the front (no mirror). Gus's right hand (torch) is at Blender -X = Roblox +X = his RightVector side. The manifest's `origin` / `boundsMin` / `boundsMax` / `grips` / `hooks` use this mapping. **[UNVERIFIED until S2]**: the prepare script prints both axis checks.
- **Palette:** 16 new append-only cells (23-38: floor, wood, Gus, Christmas extras, leaves). Location atlases pass the same audit. The audit caught the first Corner Shop and Toy Shop walls: Alarm Red's luma (0.39) was within 0.15 of them, so lasers would vanish in greyscale; the walls went darker (luma ≤ 0.24).
- **Sizes:** FBX 20-225 KB each (vault door 225 KB with its embedded 1024 dial map), 2.4 MB for `assets/` in all.

### Bank kit v0 (2026-11-12, W1 golden-asset pass): superseded

The v0 rows (Bank_Wall_4x12 / 8x12 17, GoldBar 17, GoldStack 17, Diamond 16, VaultDoor_Greybox 16) are replaced by the table above. GoldBar, GoldStack and Diamond are unchanged meshes (rebuilt on the extended atlas, same cells).

## Open

| Item | Owner |
|---|---|
| Owner sign-off of the golden-asset candidates (`Wall_8x12`, `VaultDoor`, `GoldBar` / `GoldStack`, `Diamond`, `Gus` v0): they are not golden until then (STYLE_BIBLE §9 rule 3) | owner |
| Spike S2: import the 50 FBX files, save `assets/Kit.rbxm` (KIT_IMPORT); then Claude maps it and runs `tests/kit_check.luau`. Lifts the V9 cap and verifies both axis checks | owner, then Claude |
| Level data vs kit (KIT_IMPORT fit table): L1 counter box 6 wide (module 8), L5 till outside its counter box, L6 open vault door resting on WestStack / plate C, no cover piece for L6 TellerDesk | content track |
| Hide_Curtain below the bar (15/18): redesign before a level uses it | Claude |
| Upload the 3 location atlases and the 3 dial-face maps; put the atlas ids in `Config.Kit.Atlas` (Bank, CornerShop, ToyShop) | owner, then the code track |
| Blind Art Director review (`lihfolk:council-method`, Quick) of the heroes (VaultDoor, CashRegister, GiantPresent), Gus and the 16/18 pieces, with the turntables and KitPreview sheets as evidence | coordinator |
| Confirm Alarm Red `#FF3838` (laser lenses, alarm lamps; STYLE_BIBLE §1.1) | owner |
| Confirm the Corner Shop (brick + light pine) and Toy Shop (navy + light pine) atlas colours from `KitPreview_CornerShop.png` / `KitPreview_ToyShop.png` | owner |
| `MeshPart.TextureID` set at runtime for the atlas swap is expected to work [UNVERIFIED in the engine smoke]; fallback: one kit folder per location | code track |
| Gus pose clips (double-take, shrug, heavy carry) on the joint pivots, MASTERPLAN 6.7 | code track |
| If D7 (freelance golden assets) is approved, these assets become placeholders and the bible is re-measured against the commissioned set | owner |
