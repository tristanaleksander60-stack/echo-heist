# STYLE BIBLE v1: "Neon-Noir Diorama"

_Heist Yourself (Echo Heist). v1 pass 2, 2026-11-12 (launch kit + review fixes). Source of the rules: MASTERPLAN §6. This file holds the numbers. Every rule here is a number, a hex value or a do/don't pair. If a rule is an adjective, it is a bug in this file._

**The look in one line.** Chunky, bevelled low-poly sets built like a model kit. They are lit at night in deep indigo (never black) with warm pools of light. One glowing colour family is reserved for clones. The art must read **with shadows off**, because phones at graphics quality 1-3 draw no shadows.

**Golden-asset candidates** (the style reference; every new asset is reviewed beside them; **golden only after the owner signs them off**, §9 rule 3: pending): `Wall_8x12`, `VaultDoor` (golden pass done: 8,156 tris, emissive combination face), `GoldBar` / `GoldStack`, `Diamond`, `Gus` v0, then the clone look (W2). Renders: `docs/art/turntables/`, kit in context: `KitPreview_<Location>.png`. Scores: `docs/art/ASSET_LOG.md`.

**Single sources of truth.**

| What | Where |
|---|---|
| Swatches, atlas cells, audit | `tools/blender/eh_palette.py` |
| Budgets and gates | `tools/blender/eh_kit.py` and `lihfolk_bpy.BUDGETS` |
| Lighting | `default.project.json` (Lighting node) |
| Kit sizes, tags, layers, pivots, joints after import | `assets/fbx/kit_manifest.json` |
| Location atlases (atlas swap) | `eh_palette.LOCATIONS`, `assets/textures/EH_Palette_<Location>.png` |

When this file and the code disagree, the code wins. Then fix this file.

---

## 1. Palette

### 1.1 Kit swatches (one 256 px atlas per location: `assets/textures/EH_Palette_<Location>.png`, 8 x 8 cells of 32 px; the kit is exported with the Bank atlas)

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
| Floor A | `floor_a` | `#262942` | 23 (7,2) | env (location) | 26 % | 0.17 | 0.29 / 0.046 / 278 |
| Floor B | `floor_b` | `#36314D` | 24 (0,3) | env (location) | 30 % | 0.20 | 0.33 / 0.049 / 292 |
| Wood shade | `wood_lo` | `#633F32` ² | 25 (1,3) | env (location) | 39 % | 0.27 | 0.41 / 0.055 / 41 |
| Wood | `wood` | `#7B5244` ² | 26 (2,3) | env (location) | 48 % | 0.35 | 0.48 / 0.060 / 40 |
| Wood light | `wood_hi` | `#956A5B` ² | 27 (3,3) | env (location) | 58 % | 0.45 | 0.56 / 0.060 / 40 |
| Gus skin shade | `skin_lo` | `#A87158` | 28 (4,3) | char | 66 % | 0.48 | 0.60 / 0.079 / 45 |
| Gus skin | `skin` | `#D09673` | 29 (5,3) | char | 82 % | 0.63 | 0.72 / 0.085 / 52 |
| Gus moustache | `hair` | `#5A493E` | 30 (6,3) | char | 35 % | 0.30 | 0.42 / 0.029 / 55 |
| Guard shirt shade | `shirt_lo` | `#516F8E` | 31 (7,3) | char | 56 % | 0.42 | 0.53 / 0.060 / 250 |
| Guard shirt | `shirt` | `#6E90AF` | 32 (0,4) | char | 69 % | 0.55 | 0.64 / 0.060 / 246 |
| Holly Green shade | `holly_lo` | `#1C7C48` | 33 (1,4) | xmas | 49 % | 0.39 | 0.52 / 0.119 / 154 |
| Ribbon light | `ribbon_hi` | `#AD536A` | 34 (2,4) | xmas | 68 % | 0.41 | 0.56 / 0.120 / 6 |
| Snow | `snow` | `#C0C3D5` | 35 (3,4) | xmas | 84 % | 0.77 | 0.82 / 0.025 / 278 |
| Leaf shade | `leaf_lo` | `#1F4127` | 36 (4,4) | env | 25 % | 0.22 | 0.34 / 0.061 / 150 |
| Leaf | `leaf` | `#345B35` | 37 (5,4) | env | 36 % | 0.31 | 0.43 / 0.076 / 145 |
| Leaf light | `leaf_hi` | `#52774A` | 38 (6,4) | env | 47 % | 0.42 | 0.53 / 0.080 / 140 |

² **Pass 2.** The first mahogany (`#41261C` / `#59392E` / `#704F42`) had the luma of the Bank's floors and wainscot (counter tops on `floor_a`: 0.003 luma, 0.08 Oklab), so counters vanished from above (rule R1, §1.3). Same hue, one value step lighter.

¹ **Confirmed by the owner on 2026-11-12: Alarm Red is `#FF3838` everywhere** (code: `Heist/Palette.alarm`; Blender: `eh_palette` cell 18). The plan's `#FF3348` is only Oklab **0.194** from Clone Magenta, and the rule (§1.3) needs 0.20 or more. `#FF3838` gives 0.209. This is the smallest change: only the blue channel moves from 0x48 to 0x38.

- **Cell order is append-only.** Never reorder: kit UVs point at cell indices. A location re-skin (Corner Shop, Toy Shop) is an **atlas swap** (§1.4). Christmas is not an atlas swap: it is the removable dressing layer (§13).
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
| Alarm Red is never decoration | Christmas lights are warm white, never red; berries and Santa hats are Ribbon Burgundy | — |
| Characters vs the ground | Gus's shirt luma 0.55 and skin 0.63 vs ground ≤ 0.22: step ≥ **0.15** | PASS (audit) |
| Characters never read as loot | `skin`, `skin_lo`, `shirt` vs Heist Gold Oklab ≥ **0.15** | PASS (0.165 closest) |
| Snow is a small-area colour | Snow vs Clone Cyan / Ghost White is Oklab 0.134 / 0.156 | WARN: piles and wall-top caps only, never a floor field |
| **R1 readability** (pass 2). Movement blockers and hides read against the walls and floors around them, from the side (B2) and from above (B3) | `wood_lo` (tops), `wood` (bodies), `leaf`, `leaf_hi` vs `plum_deep`, `plum`, `floor_a`, `floor_b` of **every location**: Oklab ≥ **0.10** or luma step ≥ **0.08**; `wood` vs `wood_lo` luma ≥ 0.05. Shade cells (`leaf_lo`, `wood_hi`) and `wood_lo` vs the wall tops (`plum_hi`) are warnings | PASS in all three atlases. The v1 audit only compared signals, loot and Gus with the ground, so it missed Corner Shop counters in brick and tile colour (0.02 Oklab, 0.000 luma) and Toy Shop plants on sage walls (0.01). Hides keep `leaf_lo` for stems and back faces only |
| **N1 runtime glows** (pass 2). Every Neon idle colour and fixed runtime colour (`eh_palette.NEON`) vs every clone colour | Oklab ≥ **0.15**: a clone press always changes a ring's colour, and no lamp or fairy light reads as a clone | PASS. Plate rings and switch lamps idle in dim Vault Steel shade `#4E5675` (v1: the plate ring idled in Ghost White itself, so a P4 press showed no change); the dial ring in Warm Marble shade `#A8987A` (Warm Marble was 0.150 from Ghost White); lamps, fairy lights and the tree star in **Bulb Warm `#F6C0A2`** (v1 `#FFE7B8` / `#FFE2B8` were 0.087 / 0.089 from Ghost White). Bulb Warm vs Torch Amber 0.077 and vs Heist Gold 0.115: shape carries it (dots on a wire vs a cone vs a sparkle) |
| **O1 ornament tints** | The tints of the tintable ornaments follow the environment rules (reserved clone hues, ≥ 0.20 from Alarm Red), and every advent day has its own (mesh, tint) look | PASS (`ribbon_hi` was dropped as a tint: 0.159 from Alarm Red) |

### 1.4 Location atlases (the atlas swap, MASTERPLAN 6.7)

One mesh set for every location. Code sets `MeshPart.TextureID` to the location's atlas id when it builds a level, so every piece of a location still instances (same MeshId + TextureID + Material). Only the **location cells** change: `plum_deep`, `plum`, `plum_hi` (walls), `floor_a`, `floor_b` (floors), `wood_lo`, `wood`, `wood_hi` (furniture). Ink, steel, marble, loot, signals, characters and Christmas cells never change.

| Location | plum_deep / plum / plum_hi | floor_a / floor_b | wood_lo / wood / wood_hi | Status |
|---|---|---|---|---|
| Bank (base) | `#2E2A50` / `#3A3560` / `#4D4778` (plum) | `#262942` / `#36314D` | `#633F32` / `#7B5244` / `#956A5B` (mahogany; pass 2, was `#41261C` / `#59392E` / `#704F42`: tops vanished on the floors) | golden candidate |
| Corner Shop | `#44281F` / `#573429` / `#704B3E` (dusty brick) | `#2D2C3A` / `#4D372E` (cool / warm checker) | `#816243` / `#9A7755` / `#B3916D` (light pine; pass 2, was `#503721` / `#6B4F34` / `#85684C`: the brick's own colour) | [decision, owner review] |
| Toy Shop (Dec 11) | `#143352` / `#1F3F5F` / `#3D5E7F` (storybook navy; pass 2, was sage: every plant and the green curtain vanished on it) | `#242B39` / `#453127` (slate / cocoa) | `#7D6441` / `#967952` / `#B0936B` (light pine) | [decision, owner review] |

| Rule | Number |
|---|---|
| A location wall colour stays calm | Oklch C ≤ **0.093** for every overridden location cell |
| A location wall must not hide a laser in greyscale | Wall luma (`plum`, `plum_deep`, floors) ≤ **0.24**: Alarm Red's luma is 0.39, the step must be ≥ 0.15. The audit failed the first brick (0.27) and sage (0.31) walls |
| Every location atlas passes the full audit | `python3 tools/blender/eh_palette.py` audits all three, including R1 (furniture and hides vs that location's walls and floors) |
| P3: characters never use location cells | Gus (role `char`) uses `skin*`, `hair`, `shirt*`, ink, steel, marble only: he looks the same everywhere (gate P3) |

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

## 3. Lighting: recipe A "Moonlit Diorama" (reference; the values live in `default.project.json`)

Replaced "Heist Night" v1 on 2026-11-12 (PLAN_STEAM_PLUS §4.1 W1, `docs/research/roblox_quality.md` §1.2): night is shown by **hue**, not darkness. A daytime sun recoloured as moonlight gives a real key light at every quality level.

| Node | Values |
|---|---|
| Lighting | LightingStyle Realistic, PrioritizeLightingQuality on, GlobalShadows on, **ClockTime 15, GeographicLatitude 20**, Brightness 1.4, ColorShift_Top (150,175,255), ColorShift_Bottom (40,30,70), Ambient (95,90,140), OutdoorAmbient (115,110,165) (Ambient ≤ OutdoorAmbient in every channel), EnvironmentDiffuseScale 0.30, EnvironmentSpecularScale 0.40, ExposureCompensation 0.30, ShadowSoftness 0.3 |
| Sky | CelestialBodiesShown, SunTextureId `rbxasset://sky/moon.jpg` (the key light drawn as a moon), SunAngularSize 9, MoonAngularSize 0, StarCount 0. **Faces: Roblox's default (a day sky) until the plain night faces (`assets/sky/`, `tools/blender/sky_faces.py`) are uploaded and pasted in**; the Heist City cubemap is phase 2 (W4) |
| Atmosphere | Density 0.28, Offset 0.12, Color (90,80,150), Decay (55,45,105), Glare 0, Haze 1.3 |
| Bloom | Intensity 0.6, Size 24, **Threshold 1.15**: lit marble stays below it; Neon and over-bright effects glow |
| ColorCorrection | Brightness 0, Contrast 0.12, Saturation 0.08, Tint (240,240,255) (mild: the night lives in the Lighting values) |
| Never | SunRays; DepthOfField or Blur in play (menus, planning camera and reel only) |

- **Local lights (W2):** every level gets lamps from `Heist/KitPlan.lamps`: one over each plate, one **hero** SpotLight over the goal (the only shadowed light), and room centres (`Heist/LevelDress`, else automatic). Each is a `Lamp_Ceiling` with a warm light (Config.Lighting.LAMP, about 60 % warm area inside) and an **unlit floor pool** (SurfaceGui, LightInfluence 0, concentric Warm Marble discs). Never a plain Decal: decals are lit and darken at night. Budget per view: ≤ 9 lights, ≤ 2 shadowed (unit spec + engine_smoke). The client `LightDirector` drops hero shadows at tier ≥ 3 and pools at tier 4.
- Light pools are faked (pools, emissive, Neon), never with extra real lights. Loot inside a pool still sits on a dark display (§1.3 display rule).
- **Floors (W3):** the greybox floor uses the runtime `floor` swatch `#3A365C` (Heist/Palette; audited in `eh_palette.py` RUNTIME), a value step above Ink, which is black under any night light. Ink stays for the table edge, display stands and the outer void. The kit's floor checker cells (`floor_a` / `floor_b`) are unchanged in this pass: lifting them is an atlas re-upload (see PROJECT_STATE).
- The Blender previews (`tools/blender/level_shots.py`, `kit_preview.py`) approximate this recipe in Eevee. They are previews; Studio screenshots decide.

---

## 4. Materials and textures

| Rule | Number |
|---|---|
| Kit pieces | `SmoothPlastic`, `Color` white (255,255,255), `TextureID` = the one kit atlas (256 px). One material per MeshPart |
| Parts tinted at runtime | `Neon`, `TextureID` empty, `Color` set by code: `VaultDoor_DialRing`, `Plate_4x4_Ring`, `Switch_Wall_Lamp`, `LaserEmitter_Lens`, `Lamp_Ceiling_Bulb`, `Gus_FlashlightLens`, `Xmas_Lights_8_Bulbs`, `Xmas_Tree_Lights`. Idle and runtime colours: `eh_palette.NEON` (audited, rule N1; copied into the prepare script and the manifest's `neon`) |
| Tintable atlas parts | `Ornament_Bauble`, `_Bell`, `_Star`: atlas texture **and** a `Color` (the tint cell is white, Snow and light steel give shade bands). The day's colour: `eh_palette.ORNAMENT_DAYS` |
| Glass parts (`*_Glass`, `*_Case`) | `Glass`, Transparency **0.6** (windows, teller screen) or **0.7** (diamond case), Color Vault Steel light `#A9B2CC`, `TextureID` empty, CanCollide off |
| Hero SurfaceAppearances per level | ≤ **3** (vault door, diamond, event centrepiece): Color + Roughness at 1024 plus an emissive mask. No metalness map. Built: `VaultDoor_DialFace` (`assets/textures/VaultDoor_DialFace_{Color,Roughness,Emissive}.png`, planar UV, 0-90 numbers and 100 ticks glow; `EmissiveTint` follows the DialRing colour) |
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

### 5.1 Kit grid (every location)

| Item | Number |
|---|---|
| Grid | **4 studs**. Module widths are 4, 8 and 16 |
| Wall | Height **12**, thickness **2** (core 1.4, trims proud up to 0.3). Footprint in **Blender** axes `[0,W] x [0,2] x [0,12]`; in **Roblox** axes the module spans **X [-W, 0], Y [0, 12], Z [0, 2]** from its pivot (Blender +X is Roblox -X: the pivot is the module's left end seen from the front, the module extends to its RIGHT along -X). Placing a module as if it spanned X [0, W] puts it one module off |
| Origin | **Front-bottom-left grid corner**: (0,0,0) is the front plane, floor, left end. Front = Blender **-Y** = Roblox **-Z** (the LookVector side) |
| Trim lines (both faces) | Baseboard 0-0.97 (`ink`, 0.12 chamfer); wainscot to 4.35 (`plum_deep` + raised `plum` panels 3.0 x 2.35); dado rail 4.35-4.85 (`marble`, 0.2 proud); upper wall to 10.95 (`plum`); crown 10.95-12 (`marble`, 0.3 proud); cut-away top `plum_hi` |
| Hero modules in the wall line | Continue the trim lines. The vault frame (16 wide) carries the cornice at the crown height and the plinths at the baseboard height |
| Doorways | Floor-level, no lip. The vault opening is a 9-stud circle cut flat by the floor, giving a 5.4-stud threshold |
| Naming | `Family_Variant_WxH` (PascalCase, `Wall_8x12`, `Wall_Door_8x12`). Multi-part pieces use `Asset_Part` (`VaultDoor_Dial`, `Gus_Head`). Location-neutral names (the atlas carries the location). No `.001`; never `_Att`, `_OuterCage` or `_InnerCage` |

### 5.2 Placement and pivots (what the level layout needs)

| Piece | Origin (pivot) | Placement rule |
|---|---|---|
| Walls, window, door frame, vault frame | Front-bottom-left grid corner | **Every wall module is centred on its grid line** (pass 2): the module's centre plane (Roblox local Z = 1) on the LevelSpec wall line, so the 2-thick kit wall covers the 1-thick sim wall (line ± 0.5) with 0.5 to spare on both faces and an actor can never reach a sim wall box. Shell walls and partitions alike; modules run grid point to grid point and their ends meet inside the corner pillar. Pivot formulas: KIT_IMPORT "Walls are centred" (yaw 0 / 180 / ±90). v1 put the shell walls' front face on the line, 2 thick outward: that left a 0.5 band inside the visible room that the sim treats as wall (the unsafe direction) |
| `Storefront_24x12`, `BankFront_24x12` | Front-bottom-left grid corner | Their front (-Z) is the **street**, the back is the interior wall: rotate them so the front faces the street, centred on the line. Street at +Z (Shop.shell / Bank.shell): pivot **(-12, 0, zLine + 1), yaw 180** spans x -12..12 with the 8 x 10 entrance on -4..4; `Wall_4x12` (shop) or `Wall_8x12` (bank) each side |
| `Pillar_2x12` | Grid corner of its 2 x 2 cell | **Centred on the outside corner grid point** (pivot (gx + 1, 0, gz - 1)) where two walls meet, or on an exposed wall end |
| `Floor_8x8` | **Top** front-left corner | Walking surface on y = 0 |
| Doorways | — | `Wall_Door_8x12`: 6 x 10 opening at x 1-7 (LevelSpec `doorAt(z, -3, 3)`). `Storefront_24x12`: 8 x 10 entrance at x 8-16 (the shell's front gap -4..4). Floor-level, no lip |
| Door leaf | Hinge-side bottom edge on the wall centre plane | Pocket door: slides 6 studs into the wall on its hinge side (needs a solid wall ≥ 6 wide there) |
| `Shutter_8x10` | Top centre, on the wall centre plane, 0.35 inside the header | The LOCKDOWN leaf of a street entrance; rolled up = `Size.Y` 0.35 (hidden in the header), drop = tween `Size.Y` to 10.35 with the top pinned. 1 thick = the sim door box |
| Vault door leaf | Hinge axis at the floor | Opens outward, -175° about the hinge, onto the wall face on the viewer's left; visual only while open (CanCollide off). Keep plates, hides and loot out of its resting footprint (manifest `open`) |
| Hides over a plate | Niche centre on the floor | The niche centre (= the pivot) on the plate centre; the 4 x 4 niche stays open floor so the plate ring shows (manifest `niche`) |
| Wall-mounted props (switch, laser post, curtain, wreath) | Bottom (or back) centre on the **wall core face** (0.3 in from the module's front plane) | Front faces into the room |
| Free-standing props, loot, hides | Bottom centre (diamond: centre) | On the floor or a dark display top |
| Lamp | Top centre at the cut-away ceiling plane (y 12) | Hangs to y 8.62 |
| Christmas wall dressing | The wall module's own origin | Same CFrame as the module it dresses |
| Rigid rigs (Gus) | Each part at its joint with its parent | `joint = {name, parent}` in the manifest |

**Placing pieces.** Only with `PivotTo` / `GetPivot`. A MeshPart's `CFrame` is its bounding-box centre; the kit point lives in `PivotOffset` (KIT_IMPORT).

**Axes.** The FBX export maps Blender (x, y, z) to Roblox (-x, z, y): Blender's front -Y is Roblox -Z (LookVector); Blender -X becomes Roblox +X, still the viewer's left when facing the front (a rotation, no mirror). Manifest points (`origin`, `boundsMin/Max`, `grips`, `hooks`, `hangPoint`) are in Roblox axes. [UNVERIFIED until S2: the prepare script prints two axis checks.]

---

## 6. Budgets

| Class (`lf.BUDGETS`) | Target / ceiling tris | Launch kit v1 |
|---|---|---|
| tiny | 150 / 300 | — |
| small (loot, props) | 600 / 1,500 | GoldBar 52, Diamond 94, CashBag 600, Present 388, Candy 336, Toy 580, Teddy 596, Plate 484, Safe 452 + door 548, Shutter 556, hides 468-572, ornaments 164-472 |
| module (wall pieces) | 800 / 2,000 | Wall_4x12 196, Wall_8x12 284, Wall_Window 768, Wall_Door 664 (+ leaf 508), Pillar 324, Floor 144, counters 208-316, Shelf 776, Shelf_Gondola 744, Hide_DepositStack 696, Garland 736 |
| medium | 2,000 / 4,000 | Storefront_24x12 1,980, BankFront_24x12 2,244, Van 1,856, VaultDoor_Frame 2,452, VaultDoor_Door 3,832, CandyCane 888 |
| hero (assembly) | 10,000 / 20,000 | VaultDoor 8,156 (golden pass, 8-10k), CashRegister 1,520, GiantPresent 1,380 |
| creature (Gus) | 5,000 / 10,742 | Gus 3,488 in 18 rigid parts |
| Whole launch kit | — | 55 FBX, 99 MeshParts, 51,706 tris (W4/W5, Nov 12: + the backdrop skyline quarters Skyline_Near 1,288 and Skyline_Far 1,588 (client backdrop only, 4 instanced copies each), ToySoldier 2,736, Column_2x12 600, BankersLamp 328; was 50 FBX, 92 MeshParts, 45,166 tris in pass 2). A dressed 32 x 24 room (KitPreview): Corner Shop 20.3k (29.1k with the Christmas layer), Bank 22.9k (31.8k), Toy Shop 20.2k (27.8k): about a tenth of the 300k "triangles in view" target |
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
| Walls centred on the sim's wall line, so the kit covers the sim box | A visible wall face behind the sim face (an actor's root ends up inside a sim wall) |
| A hide over a plate with an open floor niche: the plate ring shows | A pot, crate or prop standing on the plate (a kid cannot find it) |
| Furniture that reads on its floor and wall from above (R1) | Counters in the floor's or the wall's colour (they vanish in the B3 planning view) |
| `PivotTo` / `GetPivot` for every kit piece | Setting `.CFrame` to a kit point (the CFrame is the bounding-box centre) |

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
| Build, gate, export, turntable | `python3 tools/blender/build_asset.py assets/blender/<spec>.py` (or `--all`: one Blender process per spec, rebuilds the manifest). An asset whose content hash (geometry, cells, UVs, pivots, notes, embedded images, settings) is unchanged keeps its FBX, turntable and report byte for byte, so only touched assets reach git (`--force` re-renders all) |
| Import table, fit table, loot and ornament tables + Studio prepare script | `python3 tools/blender/kit_docs.py` (KIT_IMPORT.md generated sections from the manifest and the level data via `lune run tools/blender/level_boxes.luau`, cached in `docs/art/level_boxes.json`; `docs/art/KitPrepare.commandbar.lua`) |
| Turntable of any file | `python3 tools/blender/turntable.py <file.fbx\|.glb\|.blend> [--mood]` |
| Kit context render | `python3 tools/blender/kit_preview.py` (Corner Shop, Bank, Toy Shop, Street, Bank street, the decorated advent tree; Christmas off / on; atlas swap applied; B3 top-down flat tiles for the planning-view read) |
| Palette audit | `python3 tools/blender/eh_palette.py` (audits and rebuilds every location atlas: reserved hues, signals, greyscale, display rule, R1 furniture / hide readability, N1 runtime glows, O1 ornament tints) |
| Hard gates (`lihfolk_bpy.gate`) | A1 tris within class ceiling · A2 watertight · A3 normals · A4 no n-gons · A5 no loose or degenerate geometry · A6 transforms applied · A7 expected size · A8 one UV map in 0-1 · A10 one material · A15 symmetry ≤ 1 % · A17 no self-intersections · A18 clean caps, no flipped faces |
| Echo Heist gates | A11 atlas is a power of two ≤ 1024 · A12 origin at the kit point · A13 FBX check (UnitScaleFactor 100, no Lcl Scaling, vertex extents = sizes, no animation) · A14 names · A16 seating and floating shells (parts held by another part, like glass panes and bulbs, are seat-checked against their holder) · KIT grid and tile check · P1 palette audit (all locations) · P2 role may use these swatches · P3 characters use no location cells |
| Visual rubric | V1-V9, 0-2 each. Accept **≥ 16/18 with no zero** (launch kit bar, ASSET_LOG) **and ≥ 8.5 / 10** on the LihFolk weighted scale (V1 x3, V2-V5 x2, V6-V9 x1; `quality-score/rubrics/model.md`). The log shows both; they are never mixed |
| Studio (spike S2) | `docs/art/KIT_IMPORT.md`, then `lune run tests/kit_check.luau build/EchoHeist.rbxlx` |

## 11. Open items (v1)

- **Golden-asset sign-off** (§9 rule 3): the owner signs off `Wall_8x12`, `VaultDoor`, `GoldBar` / `GoldStack`, `Diamond` and `Gus` v0 (or asks for changes) from the turntables and `KitPreview_*.png`. Until then they are candidates.
- **Location atlases** (§1.4): owner to confirm the Corner Shop (brick + light pine) and Toy Shop (navy + light pine) colours from `KitPreview_CornerShop.png` and `KitPreview_ToyShop.png` (both B3 top-down tiles included).
- **S2 Studio checks:** the two axis checks of the prepare script; do smooth plus sharp-edge normals survive the import; CollisionFidelity of the door frames, both street fronts, the vault frame and the van (Lune cannot read it back).
- **Level data vs kit** (content track; the KIT_IMPORT fit table lists them): the L1 counter box, the L5 till outside its counter, the L6 open vault door over WestStack / plate C, a cover piece for L6's TellerDesk hide.
- **Blind Art Director review** of the heroes, Gus and the 16/18 pieces.
- Freelance golden assets (D7): if commissioned, they replace these as the style reference, and this file is re-measured against them.

## 12. Characters (Gus)

| Rule | Number |
|---|---|
| Rig | Rigid parts with R15 names (`Gus_Head`, `Gus_UpperTorso`, `Gus_LeftUpperArm`...), no skinning; each part's pivot is its joint (`Neck`, `Waist`, `RightShoulder`...). Pose clips are code data on these joints (MASTERPLAN 6.7): `part:PivotTo(parent:GetPivot() * C0 * pose)` with `C0 = CFrame.new(origin[child] - origin[parent])` (KIT_IMPORT "Gus"), never `part.CFrame` |
| Budget | ≤ **5,000** tris for the whole rig (Gus v0: 3,488 in 18 parts) |
| Height | 6.5 studs to the cap top (players 5.2): the grown-up in a room of kids |
| 64 px read | Peaked cap with a visor and a marble badge, round head, a dark handlebar moustache on light skin (luma step 0.33), a light shirt (luma 0.55) on dark legs, and an oversized torch in his right hand |
| Colours | `char` cells + ink, steel, marble (rule P3). Never Torch Amber on the mesh: the amber is the code-drawn cone, the lens is a Neon part |
| Swaps | `Gus_SantaHat` (Christmas layer) shares `HatAttach` with `Gus_Cap`; show one |

## 13. Christmas dressing layer (Dec 3 - Jan 4)

| Rule | Number |
|---|---|
| What it is | Removable pieces, manifest `layer = "xmas"`: `Xmas_Garland_8`, `Xmas_Lights_8`, `Xmas_Wreath`, `Xmas_SnowCap_8`, `Xmas_SnowPile`, `Xmas_Tree`, `LaserEmitter_CandyCane`, `Ornament_*`, `Gus_SantaHat`. Off = not cloned; never a republish |
| Colours | Holly Green, Holly shade, Ribbon Burgundy, Ribbon light, Snow; plus env cells. Fairy lights and the tree star are Bulb Warm Neon `#F6C0A2` (pass 2: `#FFE7B8` was 0.087 from Ghost White, rule N1). Never Alarm Red |
| Coverage | **Garland:** continuous runs along one or two walls of a room (the garland is designed for runs: each module's x = 0 bow covers the shared pin, so it never doubles), at most half of a room's wall modules. **Lights:** at most half of a room's wall modules, never over a laser post. Snow caps on exterior walls only. One tree per scene (the van's tree carries the 22 advent ornaments on its `hooks`, at 0.65 size) |
| Ornaments | Each advent day its own look: `Ornament_Bauble` / `_Bell` / `_Star` take the day's `MeshPart.Color`, `_VaultDoor` / `_Donut` / `_Van` are fixed (`eh_palette.ORNAMENT_DAYS`, KIT_IMPORT table). Decorated tree: `KitPreview_Tree.png` |
| [decision] Neon MeshParts for the lights | MASTERPLAN §4.3 says "fairy lights through emissive masks". Emissive masks need a SurfaceAppearance, and a level may have **≤ 3** (§4: vault door, diamond, centrepiece); a Neon bulb string is one instanced MeshPart per module (one draw call per mesh type) with no texture. So the bulbs and the tree star are Neon parts; bloom gives the glow |
| [decision] Snow as meshes | MASTERPLAN §4.3 / §6.4 say "snow decals". A decal on a cut-away wall top or a kerb is a texture per face that does not instance; `Xmas_SnowCap_8` / `Xmas_SnowPile` are atlas meshes that instance with the kit and add a silhouette (the drift, the cap lip) a decal cannot |
| [decision] Holly on present loot | MASTERPLAN §6.2 keeps the Christmas accents to the dressing layer. `GiantPresent` and `Present` are **loot** (layer base: the daily vaults keep them after the season) wrapped in Holly paper with a **Heist Gold** ribbon and bow: the gold carries the loot read, the paper says "present". They are the only loot allowed the Holly cells (palette role `present`) |
| Lighting | Christmas Eve recipe: Ambient +10 % (§3); no extra lights for the dressing (Neon + bloom only) |

## 14. World backdrop and signature silhouettes (W4 / W5, 2026-11-12)

| Rule | Number |
|---|---|
| Layers | L0 ground plane 1.2 below the lot + a kerb band; L1 16 facade cards round the lot (body, Warm Marble shade cornice, Snow on it, Bulb Warm Neon windows on every 3rd slot); L2 `Skyline_Near` (radius 300, heights 30-58); L3 `Skyline_Far` (radius 600, 56-104, Vault Steel shade faces, sparser windows); the Heist City sky. Built on the client (`Heist/Backdrop`, plan in `Shared/Heist/BackdropPlan`), never collides, never queried, no shadows. No searchlights |
| Heights | Rings stay under about 10.5 degrees from the street camera, so the sky's landmark (the Snow Globe at 12-19 degrees) always rises above them and above the shop roof line (10 degrees from the classic camera) |
| Budget | About 30 draw calls and 25k triangles for the whole backdrop (unit spec: L1 measures 14 draw calls, 12.7k triangles, 115 instances at tier 1). Tier 3+ drops the far ring; tier 4 the facade windows |
| Glow | Only the windows (Bulb Warm `#F6C0A2`, small, static: the PLAN §3.1 exception), listed in `eh_palette.NEON` like every Neon kit part |
| Landmark | Hoardsworth Tower with the Snow Globe Vault (`tools/blender/sky_city.py`): burgundy body, antique gold fins and cradle (never Heist Gold), a glass globe full of stolen presents. One landmark only; it stands toward -Z (the spawn views' direction); `Config.Backdrop.SKY_LANDMARK_YAW` and `Sky.SkyboxOrientation` turn it for a site whose first view faces elsewhere |
| Snow | Falling: 40 / s, 4.5-6 s, <= 240 alive in a 48 x 22 x 48 volume over the camera focus (120 on tier 3+); reduced motion 0.5x rate and 0.45x speed (never off); off inside a building footprint (no roofs). Caps: the upper 38 % of each awning slope and the sills only (the stripes stay visible); Snow stays a small-area colour (§1.3) |
| Signature silhouettes | Corner Shop: the striped awning (Storefront_24x12) + amber room light. Toy Shop: `ToySoldier` (11.3 tall drummer, role `toy`: burgundy coat, never gold) + candy pink and gold room light. Bank: `Column_2x12` (6 in L6) + `BankersLamp` (Leaf glass, 2 on the teller counters) + green room light (`Config.Lighting.LOCATION`). All visual only, placed by `Heist/LevelDress.props`, kept off every plate, door, laser, hide, loot point, nav point and spawn (unit spec) |
