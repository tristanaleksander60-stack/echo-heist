# STYLE BIBLE v0: "Neon-Noir Diorama"

_Heist Yourself (Echo Heist). v0, 2026-11-12. Source of the rules: MASTERPLAN §6. This file holds the numbers. Every rule here is a number, a hex value or a do/don't pair. If a rule is an adjective, it is a bug in this file._

**The look in one line.** Chunky, bevelled low-poly sets built like a model kit. They are lit at night in deep indigo (never black) with warm pools of light. One glowing colour family is reserved for clones. The art must read **with shadows off**, because phones at graphics quality 1-3 draw no shadows.

**Golden assets** (the style reference; every new asset is reviewed beside them): `Bank_Wall_8x12`, `VaultDoor_Greybox` (golden pass pending), `GoldBar` / `GoldStack`, `Diamond`, then Gus and the clone look (W2). Renders: `docs/art/turntables/`. Scores: `docs/art/ASSET_LOG.md`.

**Single sources of truth.**

| What | Where |
|---|---|
| Swatches, atlas cells, audit | `tools/blender/eh_palette.py` |
| Budgets and gates | `tools/blender/eh_kit.py` and `lihfolk_bpy.BUDGETS` |
| Lighting | `default.project.json` (Lighting node) |
| Kit sizes after import | `assets/fbx/kit_manifest.json` |

When this file and the code disagree, the code wins. Then fix this file.

---

## 1. Palette

### 1.1 Kit swatches (one 256 px atlas: `assets/textures/EH_Palette_Bank.png`, 8 x 8 cells of 32 px)

"V" is HSV value (the plan's "30-55 % value" bands). "Luma" is the Rec.709 greyscale value used by the greyscale test. Oklch is L / C / h.

| Swatch | Key | Hex | Cell (col,row) | Role | V | Luma | Oklch |
|---|---|---|---|---|---|---|---|
| Ink Indigo | `ink` | `#1C1F3B` | 0 (0,0) | env | 23 % | 0.13 | 0.25 / 0.053 / 277 |
| Ink Indigo light | `ink_hi` | `#2A2D52` | 1 (1,0) | env | 32 % | 0.18 | 0.31 / 0.066 / 278 |
| Plum Slate deep | `plum_deep` | `#2E2A50` | 2 (2,0) | env | 31 % | 0.18 | 0.31 / 0.067 / 287 |
| **Plum Slate** | `plum` | `#3A3560` | 3 (3,0) | env | 38 % | 0.22 | 0.36 / 0.073 / 287 |
| Plum Slate light | `plum_hi` | `#4D4778` | 4 (4,0) | env | 47 % | 0.30 | 0.43 / 0.080 / 288 |
| Warm Marble shade | `marble_lo` | `#A8987A` | 5 (5,0) | env | 66 % | 0.60 | 0.69 / 0.046 / 83 |
| **Warm Marble** | `marble` | `#D8C8A8` | 6 (6,0) | env | 85 % | 0.79 | 0.84 / 0.047 / 85 |
| Warm Marble light | `marble_hi` | `#EDE2C8` | 7 (7,0) | env | 93 % | 0.89 | 0.91 / 0.036 / 88 |
| Vault Steel shade | `steel_lo` | `#4E5675` | 8 (0,1) | env | 46 % | 0.34 | 0.46 / 0.052 / 273 |
| **Vault Steel** | `steel` | `#7C86A6` | 9 (1,1) | env | 65 % | 0.53 | 0.62 / 0.050 / 271 |
| Vault Steel light | `steel_hi` | `#A9B2CC` | 10 (2,1) | env | 80 % | 0.70 | 0.76 / 0.039 / 270 |
| Heist Gold shade | `gold_lo` | `#B87A0A` | 11 (3,1) | **loot** | 72 % | 0.50 | 0.63 / 0.132 / 73 |
| **Heist Gold** | `gold` | `#FFC21F` | 12 (4,1) | **loot** | 100 % | 0.77 | 0.85 / 0.168 / 85 |
| Heist Gold light | `gold_hi` | `#FFE69C` | 13 (5,1) | **loot** | 100 % | 0.90 | 0.93 / 0.097 / 92 |
| Diamond Ice shade | `ice_lo` | `#8F98C4` | 14 (6,1) | **loot** | 77 % | 0.60 | 0.69 / 0.066 / 276 |
| Diamond Ice | `ice` | `#C9D0EE` | 15 (7,1) | **loot** | 93 % | 0.82 | 0.86 / 0.042 / 275 |
| Diamond Ice light | `ice_hi` | `#EEF1FB` | 16 (0,2) | **loot** | 98 % | 0.95 | 0.96 / 0.014 / 273 |
| Tint White | `white` | `#FFFFFF` | 17 (1,2) | tint | 100 % | 1.00 | for parts tinted by `Color` |
| **Alarm Red** | `alarm` | `#FF3838` ¹ | 18 (2,2) | danger | 100 % | 0.39 | 0.65 / 0.233 / 27 |
| Torch Amber | `amber` | `#FFD27A` | 19 (3,2) | guard | 100 % | 0.84 | 0.88 / 0.118 / 83 |
| Getaway White | `exit` | `#F4F7FF` | 20 (4,2) | exit | 100 % | 0.97 | 0.98 / 0.011 / 270 |
| Holly Green | `holly` | `#2FBF71` | 21 (5,2) | xmas | 75 % | 0.61 | 0.71 / 0.164 / 154 |
| Ribbon Burgundy | `ribbon` | `#8C2F4B` | 22 (6,2) | xmas | 55 % | 0.27 | 0.45 / 0.128 / 5 |

¹ **Proposed v0 tweak, owner to confirm.** The plan's `#FF3348` is only Oklab **0.194** from Clone Magenta, and the rule (§1.3) needs 0.20 or more. `#FF3838` gives 0.209. This is the smallest change: only the blue channel moves from 0x48 to 0x38. Apply it to the laser and alarm code colours when confirmed.

- **Cell order is append-only.** Never reorder: kit UVs point at cell indices. A location re-skin (Corner Shop, Toy Shop, Christmas) is an **atlas swap**. It keeps the same cells with new colours (`eh_palette.write_atlas(path, overrides)`), uses one `TextureID` per kit, and changes no meshes.
- Unused cells are mid grey `#808080`, so a wrong UV is visible at once.
- Each face's UVs form a square inside its cell, ¼ cell wide (8 px). Bilinear filtering and the first 3 mips never bleed into the next cell.

### 1.2 Clone colours (never in kit meshes)

| Player | Name | Hex | Glyph badge | Luma | Oklch |
|---|---|---|---|---|---|
| P1 / solo | Clone Cyan | `#3DE8FF` | ● 1 | 0.77 | 0.86 / 0.136 / 209 |
| P2 | Clone Magenta | `#FF4FD8` | ■ 2 | 0.50 | 0.72 / 0.251 / 338 |
| P3 | Clone Indigo | `#6A5CFF` | ▲ 3 | 0.42 | 0.58 / 0.232 / 280 |
| P4 | Ghost White | `#F4F7FF` (as a glow only) | ◆ 4 | 0.97 | 0.98 / 0.011 / 270 |
| left the game | Tape Grey | `#8A8FA8` | (keeps the glyph) | 0.56 | 0.65 / 0.038 / 276 |

- **Identity = glyph + number + hue**, always all three. The badge is 28 px and is hidden beyond 40 studs.
- Age ramp: each older run is 12 % dimmer. In solo, older runs drift up to 25° toward violet.
- Other players' clones render at 70 % brightness on your screen.

### 1.3 Colour rules with numbers (checked by `python3 tools/blender/eh_palette.py`, rule P1, and by every build)

| Rule | Number | Status v0 |
|---|---|---|
| **Reserved hue.** No environment colour may be within **±20° Oklch hue** of a clone hue at more than **40 % of that clone's Oklch chroma** | Purple and indigo env colours (h 260-300) must have **C ≤ 0.093** | PASS. `plum_hi` is the closest at C 0.080 (34 %). Do not add a more saturated purple |
| Clone vs ground (ink, plum_deep, plum) | Oklab ≥ **0.15** | PASS |
| Alarm Red vs every clone hue | Oklab ≥ **0.20** plus a shape (beam, zigzag, ring) | PASS with `#FF3838` (0.209). The plan's value fails (0.194) |
| Greyscale: loot, danger, clones vs the ground | Luma difference ≥ **0.15** | PASS on ink, plum_deep and plum. Alarm Red vs steel is 0.05-0.14, so lasers keep the white-hot core |
| **Display rule.** Loot never sits on or against a colour closer than Oklab 0.15 or luma 0.15 | Gold: never on `marble`, `marble_hi` or `steel_hi`. Ice: never on `marble`, `marble_hi` or `steel_hi` | **Heist Gold vs Warm Marble is only 0.122 Oklab and 0.02 luma.** Loot displays are dark: tables `ink_hi` or `plum_deep`, pedestals `steel_lo` |
| Gold vs Torch Amber | 0.063 (fails colour-blind) | Shape carries it: gold = sparkle, amber = cone. Never put amber on a prop |
| Nothing darker than Ink Indigo | Luma ≥ 0.13 | PASS |
| Neon (emissive) area | ≤ **1/6** of an object's pixels | The vault DialRing is about 8 % of the door face (annulus r 1.25-1.75 on r 4.4) |
| Alarm Red is never decoration | Christmas lights are warm white, never red | — |

---

## 2. Value and contrast

| Layer | Swatches | V (HSV) | Job |
|---|---|---|---|
| Ground and shadow | ink, plum_deep | 23-31 % | The table the diorama sits on. Never black |
| Walls (big fields) | plum, plum_hi | 38-47 % (plan band 30-55 %) | Calm; carries signs and props |
| Metal | steel_lo, steel, steel_hi | 46-80 % | Doors, safes, plates, rails |
| Trims and lit pools | marble_lo, marble, marble_hi | 66-93 % | Lines that tie the kit together; light pools |
| Signals | gold, ice, alarm, amber, exit | 100 % | The only saturated things in a frame |
| Clones | §1.2 | 100 % + glow | The brand. The only glow family |

- **One focal feature per prop**, at least **1.5x** the size of any secondary feature. Examples: the vault's dial ring and wheel, the gold bar's trapezoid, the diamond's crown.
- **Value ladder per hero:** dark surround, then mid body, then light edges, then the focal glow. Example: vault frame `ink_hi`, then door `steel`, then bezel and bolts `steel_hi`, then DialRing Neon.
- **Chamfer colour rule:** chamfers facing up or sideways get the **light variant** of their face colour (`*_hi`). Chamfers facing down (normal z below -0.3) keep the base colour. This bakes the "bevels catch light" read into the atlas, so it also works with shadows off.

---

## 3. Lighting: "Heist Night" v1 (reference; the values live in `default.project.json`)

| Node | Values |
|---|---|
| Lighting | LightingStyle Realistic, PrioritizeLightingQuality on, GlobalShadows on, ClockTime 0, Brightness 0.5, Ambient (55,55,95), OutdoorAmbient (75,80,130), ColorShift_Top (255,210,160), EnvironmentDiffuseScale 0.25, EnvironmentSpecularScale 0.35, ExposureCompensation 0.2 |
| Atmosphere (streets only) | Density 0.3, Color (70,60,120), Decay (35,30,75), Haze 0.8 |
| Bloom | Intensity 0.8, Size 28, **Threshold 1.0**: Warm Marble stays below the threshold, Neon and clone outlines glow |
| ColorCorrection | Contrast 0.12, Saturation 0.1, Tint (235,230,255) |
| Never | SunRays; DepthOfField or Blur in play (menus, planning camera and reel only) |

- Local lights: `Shadows = false` by default. At most **4** shadow-casting hero lights per view. Sleep lights beyond **120 studs**.
- Light pools are faked with a floor decal or a transparent Warm Marble disc, never with extra real lights. Loot inside a pool still sits on a dark display (§1.3 display rule).
- The Blender turntable "mood" tile and `tools/blender/kit_preview.py` approximate this recipe in Eevee (indigo world (55,55,95), warm key (255,210,160), cool rim). They are previews; Studio screenshots decide.

---

## 4. Materials and textures

| Rule | Number |
|---|---|
| Kit pieces | `SmoothPlastic`, `Color` white (255,255,255), `TextureID` = the one kit atlas (256 px). One material per MeshPart |
| Parts tinted at runtime (dial ring, plate icons, lamps) | `Neon` (or SmoothPlastic), `TextureID` empty, `Color` set by code |
| Hero SurfaceAppearances per level | ≤ **3** (vault door, diamond, event centrepiece): Color + Roughness at 1024 plus an emissive mask. No metalness map |
| Textures per level | 1 kit atlas (256) + 1 trim sheet (1024) + ≤ 3 hero sets x 2 maps |
| UVs | One UV map, inside 0-1. Atlas pieces use cell squares (§1.1) |
| Shading | Chamfers are real geometry. Faces are smooth with **sharp edges above 30°**, so the flat-faced look does not depend on custom normals surviving the import (open question, skill research §7). Gems use deliberate flat shading |
| Never | EditableMesh or EditableImage in the core; vertex colours **and** a TextureID on the same part (they multiply); DoubleSided on closed meshes |

---

## 5. Shape grammar

| Rule | Number |
|---|---|
| Scale | Props **1.5-2x** real size (gold bar 2.0 x 1.0 x 0.6, diamond 2.0 wide). Buildings about **1.2x**. Reference: R15 avatar about 5 studs tall |
| Bevel (1 segment only) | S **0.06-0.08** (small props: gold 0.07, rivets 0.07, panels 0.06); M **0.12-0.20** (trims, hinge, door steps: 0.12-0.15); L **0.20-0.30** (building corners: vault frame 0.25, crown 0.2) |
| More than 1 segment | Never on kit pieces. 1 segment costs 3.7x the tris of a box, 2 segments cost 9x |
| Thinnest visible feature | ≥ **d / 170** studs at camera distance d (≥ 0.2 at 35 studs). Example: the dado rail is 0.2 proud |
| Contact faces | Flat, no bevel: wall ends at x = 0 and x = W, the bottoms of floor props. Detail stays inside the footprint |
| Symmetry | Symmetric-by-design objects are built as half + mirror. Gate A15: error ≤ 1 % of size |
| Seating | Features overlap their surface by 0.03-0.1 studs. Gate A16: no floating shells |
| Round shapes | 48 segments at r ≥ 4 studs; 24-32 at r 1-2; 8-12 for bolts and knobs |
| Storytelling | One storytelling prop per room (for example, Gus's donut box) |

### 5.1 Kit grid (Bank kit)

| Item | Number |
|---|---|
| Grid | **4 studs**. Module widths are 4, 8 and 16 |
| Wall | Height **12**, thickness **2** (core 1.4, trims proud up to 0.3). Footprint `[0,W] x [0,2] x [0,12]` |
| Origin | **Front-bottom-left grid corner**: (0,0,0) is the front plane, floor, left end. Front = Blender **-Y** = Roblox **-Z** (the LookVector side) |
| Trim lines (both faces) | Baseboard 0-0.97 (`ink`, 0.12 chamfer); wainscot to 4.35 (`plum_deep` + raised `plum` panels 3.0 x 2.35); dado rail 4.35-4.85 (`marble`, 0.2 proud); upper wall to 10.95 (`plum`); crown 10.95-12 (`marble`, 0.3 proud); cut-away top `plum_hi` |
| Hero modules in the wall line | Continue the trim lines. The vault frame (16 wide) carries the cornice at the crown height and the plinths at the baseboard height |
| Doorways | Floor-level, no lip. The vault opening is a 9-stud circle cut flat by the floor, giving a 5.4-stud threshold |
| Naming | `Family_Variant_WxH` (PascalCase, `Bank_Wall_8x12`). Multi-part pieces use `Asset_Part` (`VaultDoor_Dial`). No `.001`; never `_Att`, `_OuterCage` or `_InnerCage` |

---

## 6. Budgets

| Class (`lf.BUDGETS`) | Target / ceiling tris | Bank kit v0 |
|---|---|---|
| tiny | 150 / 300 | — |
| small (loot, props) | 600 / 1,500 | GoldBar 52, GoldStack 312, Diamond 94, VaultDoor_Dial 768, VaultDoor_DialRing 288 |
| module (wall pieces) | 800 / 2,000 | Bank_Wall_4x12 196, Bank_Wall_8x12 284 |
| medium | 2,000 / 4,000 | VaultDoor_Frame 1,196, VaultDoor_Door 1,504 |
| hero (assembly) | 10,000 / 20,000 | VaultDoor_Greybox 3,756 (golden pass target 8-10k) |
| creature (Gus) | 5,000 / 10,742 | Gus ≤ 5k in rigid pieces |
| Hard Roblox limit | 20,000 per mesh | — |

**Busiest phone view** (MASTERPLAN §6.8): Big Score with 4 players, 12 clones and 2 guards.

| Budget | Target | Ceiling |
|---|---|---|
| Frame time | ≤ 16.6 ms on a mid Android | 33 ms on a low Android |
| Draw calls | ≤ 350, clones ≤ 120 | 600 |
| Triangles in view | ≤ 300k | 600k |
| Level instances | ≤ 6k | — |
| Shadow lights | ≤ 4 | — |
| Highlights | ≤ 4 clone groups + 1 x-ray + 5 others | — |

A kit piece must instance: same MeshId + same TextureID + same Material. That is why the atlas is shared and never per piece.

---

## 7. Camera bookmarks (the daily 15-minute screenshot slot)

All four bookmarks are measured from the golden room's **anchor T**: the centre of the vault door's dial (on the door face, 3.6 studs above the floor). Yaw is measured from the vault's front normal (Roblox -Z side), positive to the right. Pitch is downward.

| # | Name | FOV (vertical) | Yaw | Pitch | Distance | Checks |
|---|---|---|---|---|---|---|
| B1 | Diorama 3/4 | 40° | +28° | 38° | 46 studs to T | Palette, value ladder, kit seams, "is it one model on a dark table?" |
| B2 | Player eye | 70° (game default) | +8° | 14° | 16 studs (default zoom) behind a player standing 6 studs in front of T | Phone readability: gold pops on its display, trims read, clones vs set |
| B3 | Planning | 30° | 0° | 90° (top-down) | 120 studs above the room centre | Routes, plates, Gus cone legible from above (§3.5) |
| B4 | Thumbnail / clip | 50° | -20° | 10° | 10 studs to the loot display, vault in the background | 9:16 safe: subject inside the central **32 %** of frame width; burned-in "◀ ME, 20 SEC AGO" fits |

Each bookmark is shot 3 times: **PC Quality 10**, **phone Automatic**, **phone quality 1-3 (no shadows)**. That gives 12 screenshots a day, saved as `YYYY-MM-DD_B1_pc.png`. The Blender stand-in for B1 and B2 is `python3 tools/blender/kit_preview.py`.

---

## 8. Do / don't

| Do | Don't |
|---|---|
| One chunky 1-segment chamfer that catches light | 3-4 bevel segments, or razor edges |
| A dark surround around a lit focal feature (vault: ink frame, steel door, glowing ring) | The same mid-value everywhere (the first vault pass: steel door on steel frame) |
| Loot on a dark table or pedestal (`ink_hi`, `steel_lo`) | Gold on Warm Marble: 0.02 luma apart, it vanishes in greyscale |
| Trims that continue across modules (baseboard, dado, crown lines) | Each module with its own trim heights |
| Plum or indigo env colours with Oklch C ≤ 0.093 | A "cool" violet or cyan wall accent: it steals the clone hues |
| Cream marble trims (`marble`) | Tan or khaki trims next to gold (`marble_lo` read as brass on the vault pilasters, so they were changed) |
| Glow only on clones, signals and runtime-tinted parts | Generic sci-fi glow strips on walls |
| Gem facets: flat-shaded, 3 values of one hue | A smooth-shaded "blob" gem |
| Flat contact faces on modules | Bevelled ends that leave a V-gap between tiled walls |
| A wall-line hero piece that continues the kit lines | A hero piece that ignores the walls it sits in |

---

## 9. How we avoid "AI slop"

1. **Numbers, not adjectives.** Every rule above is a number, a hex value or a pair. Reviews quote the rule ID (A1-A18, V1-V9, P1, P2, the display rule).
2. **Golden assets side by side.** Every new asset is reviewed in `kit_preview.py` next to the golden assets, not alone on a grey background.
3. **One style owner.** The owner signs off the golden assets. Claude builds the rest to match them.
4. **No generated meshes or textures ship.** No text-to-3D and no Toolbox. AI images are for moodboards only. All shipped meshes are built by spec scripts in `assets/blender/` that anyone can read, re-run and diff.
5. **Glow is reserved** (§1.3). No neon trim "because it looks cool".
6. **Purposeful detail only.** Every detail must change the silhouette or the shading (V7), or tell a story (one storytelling prop per room).
7. **Correctness before style.** The gates check symmetry, seating, flipped faces and dirty caps before anyone discusses taste.
8. **Blind review for heroes.** Hero assets and borderline scores (14-15/18) get a blind Art Director review (`lihfolk:council-method`, Quick) with the turntable sheet as evidence.

---

## 10. Pipeline and gates (summary)

| Step | Command or check |
|---|---|
| Build, gate, export, turntable | `python3 tools/blender/build_asset.py assets/blender/<spec>.py` (or `--all`) |
| Turntable of any file | `python3 tools/blender/turntable.py <file.fbx\|.glb\|.blend> [--mood]` |
| Kit context render | `python3 tools/blender/kit_preview.py` |
| Palette audit | `python3 tools/blender/eh_palette.py` (also rebuilds the atlas) |
| Hard gates (`lihfolk_bpy.gate`) | A1 tris within class ceiling · A2 watertight · A3 normals · A4 no n-gons · A5 no loose or degenerate geometry · A6 transforms applied · A7 expected size · A8 one UV map in 0-1 · A10 one material · A15 symmetry ≤ 1 % · A17 no self-intersections · A18 clean caps, no flipped faces |
| Echo Heist gates | A11 atlas is a power of two ≤ 1024 · A12 origin at the kit point · A13 FBX check (UnitScaleFactor 100, no Lcl Scaling, vertex extents = sizes, no animation) · A14 names · A16 seating and floating shells · KIT grid and tile check · P1 palette audit · P2 role may use these swatches |
| Visual rubric | V1-V9, 0-2 each. Accept **≥ 14/18 with no zero** (ASSET_LOG) |
| Studio (spike S2) | `docs/art/KIT_IMPORT.md`, then `lune run tests/kit_check.luau build/EchoHeist.rbxlx` |

## 11. Open items (v0)

- **Alarm Red `#FF3838`** (§1.1): owner to confirm, then update the laser and alarm colours in code.
- **S2 Studio checks:**
  - FBX axis: the front must face -Z (the KIT_IMPORT script checks it).
  - Do smooth plus sharp-edge normals survive the import?
  - CollisionFidelity of the vault frame (Lune cannot read it back, so it is checked in Studio).
- **Vault door golden pass:**
  - Emissive mask on the dial with numbers or ticks.
  - Detail up to 8-10k tris.
  - A pillar or corner module to cap exposed wall ends.
  - Blind Art Director review.
- Freelance golden assets (D7): if commissioned, they replace these as the style reference, and this file is re-measured against them.
