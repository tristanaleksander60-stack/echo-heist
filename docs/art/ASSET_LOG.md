# Asset log

One row per asset. Every asset passes the hard gates (A1-A18 plus the Echo Heist gates; see STYLE_BIBLE §10). Then it is scored on the visual rubric V1-V9 (0-2 each), and accepted at **≥ 14/18 with no zero**.

- Scores come from the turntable sheets in `docs/art/turntables/`. Those sheets are rendered from the **exported FBX** after a re-import, so they show what Studio will get.
- Gate reports are in `assets/fbx/<Asset>.gate.json`.
- **Scoring rule v0:** V9 (Studio-ready) is capped at **1** until spike S2 proves size, pivot and collision in a real Studio import (`docs/art/KIT_IMPORT.md`, `tests/kit_check.luau`).
- Scores are Claude's self-review. Hero and borderline assets still need the blind Art Director review (`lihfolk:council-method`, Quick); see "Open".

Rubric key:

| | Criterion | | Criterion | | Criterion |
|---|---|---|---|---|---|
| V1 | silhouette at 64 px | V4 | bevels | V7 | geometry economy |
| V2 | big / medium / small hierarchy | V5 | shading | V8 | matches the kit |
| V3 | proportion | V6 | palette | V9 | Studio-ready |

## Bank kit v0 (2026-11-12, Blender 5.3 `bpy`, W1 golden-asset pass)

| Asset (FBX) | MeshParts | Class | Tris (target / ceiling) | Gates | V1 | V2 | V3 | V4 | V5 | V6 | V7 | V8 | V9 | **Score** | Turntable |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Bank_Wall_8x12 | 1 | module | 284 (800 / 2,000) | PASS, tile IoU 1.00 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | `docs/art/turntables/Bank_Wall_8x12.png` |
| Bank_Wall_4x12 | 1 | module | 196 (800 / 2,000) | PASS, tile IoU 1.00 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | `docs/art/turntables/Bank_Wall_4x12.png` |
| GoldBar | 1 | small | 52 (600 / 1,500) | PASS | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | `docs/art/turntables/GoldBar.png` |
| GoldStack | 1 | small | 312 (600 / 1,500) | PASS | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **17** | `docs/art/turntables/GoldStack.png` |
| Diamond | 1 | small | 94 (600 / 1,500) | PASS | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | 1 | **16** | `docs/art/turntables/Diamond.png` |
| VaultDoor_Greybox | 4 (Frame 1,196, Door 1,504, Dial 768, DialRing 288) | hero assembly | 3,756 (10,000 / 20,000) | PASS, seats 0.0, align 0.0 % | 1 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 1 | **16** | `docs/art/turntables/VaultDoor_Greybox.png` |

Kit in context (B1 and B2 bookmarks, Eevee plus flat albedo): `docs/art/turntables/KitPreview.png`.

### Why the points were lost

| Asset | Points lost |
|---|---|
| All | V9 is 1 until S2 (above) |
| Diamond | **V8 = 1.** It is the one deliberate flat-shaded (faceted) piece in a chamfered kit. That is right for a gem, but a reviewer may read it as a style break |
| VaultDoor_Greybox | **V1 = 1.** A wall-line piece: its 64 px silhouette is the 16 x 12 frame rectangle from every angle. The round door reads only through value inside the outline. The Door object alone has a clear round silhouette. In game it is seen in its wall, where the value ladder carries the read |

### Iterations (self-review notes, kept so the same mistakes are not repeated)

| Asset | Pass 1 problem (score) | Fix | Pass 2 |
|---|---|---|---|
| GoldBar | The engraved stamp took the whole top as a dark ring, so the bar read as an **open tray**. V2 1, V3 1 (**15**) | Double inset: gold rim, then a thin `gold_lo` groove around a gold plate. Bottom face kept flat (contact face), because chamfering a tapered bottom shrank the footprint to 1.96 x 0.96 | 17 |
| Diamond | The pavilion bulged (break ring off the girdle-culet line), so the 64 px silhouette was a squat **blob**. V1 1, V3 1 (**14**) | Pavilion depth 0.95 to 1.25, break ring on the straight line (0.47 / 0.47), crown 0.42, table 60 %. Now the iconic gem V from all 8 angles | 16 |
| Bank_Wall | The dado rail was 0.15 proud, under the d / 170 rule at 35 studs. V3 1 (**16**) | Dado 0.5 tall and 0.2 proud | 17 |
| VaultDoor_Greybox | Steel door on a steel frame: flat value, and in the flat-albedo tile the door barely separated from the frame. It ignored the wall's trim lines. V6 1, V8 1 (**14**, borderline) | Value ladder: `ink_hi` frame face, `steel` door, `steel_hi` bezel and bolts, DialRing focal. Marble cornice at the crown height, `ink` plinths at the baseboard height, marble pilasters; frame top is `plum_hi` like the wall cut. The pilasters were first `marble_lo`, which read as brass next to the loot gold, so they were changed to `marble` | 16 |
| All sheets | Workbench shadows drew as ghosting; the default studio light made gold look muddy | Turntable uses `paint.sl` studio light and no shadows. The sheet is quantized to 256 colours (900 KB down to about 100-180 KB) | — |

### Measured facts from this pass

- **bpy 5.3.0** works on Python 3.13 headless (`pip install bpy`). It needs Mesa EGL on a GPU-less box: `apt-get install libegl1 libegl-mesa0 libgl1-mesa-dri`. Workbench takes about 0.3 s per 384 px view. Eevee takes about 25 s for its first frame (shader compile); a full 8-angle sheet with the Eevee mood tile took 5-17 s per asset in a batch run.
- FBX exported with `FBX_SCALE_UNITS` has UnitScaleFactor **100** and no Lcl Scaling, and its vertex extents equal the Blender sizes. A deliberately wrong export (Blender defaults) is caught by gate A13 (`Lcl Scaling 100`).
- A deliberately broken test asset failed A1, A7, A12, A14, A15, A16 (floating shell) and P2 (gold on an env prop). The gates are not rubber stamps.
- Palette audit: the plan's Alarm Red `#FF3348` vs Clone Magenta is Oklab 0.194, under the 0.20 rule. Proposed `#FF3838` (0.209). Heist Gold vs Warm Marble is 0.122 Oklab and 0.02 luma, which gives the **display rule** in STYLE_BIBLE §1.3.

## Open

| Item | Owner |
|---|---|
| Spike S2: the owner imports the 6 FBX files and saves `assets/Kit.rbxm`; then Claude maps it and runs `tests/kit_check.luau`. This lifts the V9 cap | owner, then Claude |
| Blind Art Director review of VaultDoor_Greybox and Diamond (16 each) with the turntable sheets as evidence | coordinator (`lihfolk:council-method`) |
| Vault door golden pass: emissive mask (numbers or ticks) on the dial, detail to 8-10k tris, a pillar or corner module for exposed wall ends | Claude, W1-W2 |
| If D7 (freelance golden assets) is approved, these assets become placeholders and the bible is re-measured against the commissioned set | owner |
