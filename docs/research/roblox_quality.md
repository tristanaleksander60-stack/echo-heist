# Roblox quality ceiling, late 2026: concrete recipes for Heist Yourself

_Research report, 2026-11-12. How good can Heist Yourself look and feel on a low-end phone, and exactly what to set. Builds on MASTERPLAN §6, §6.8, §8.6, STYLE_BIBLE, `visuals.md`, `tech.md`. Sources: the LihFolk vault (*vault: Note title*), LihFolk skills, the vault's Roblox API dump of 2026-10-27, DevForum/Creator Hub web searches (both hosts were blocked for direct fetch in this session, so those facts come from search summaries) and this repo. **[UNVERIFIED]** = not confirmed from a primary source; **[spike]** = a short test decides it._

---

## Summary

1. **Why it is nearly black.** Levels have **no `Light` objects** and **no `Sky`**; the only key is a weak moon (`ClockTime 0`, `Brightness 0.5`), so `Ambient (55,55,95)` does the work. In linear light that is about 4%: a Plum wall lands near **3% screen luminance**, the Ink floor near **1%**. The void is the default night sky behind a dark Atmosphere.
2. **Fix: recipe A "Moonlit Diorama".** A fake night (daytime sun recoloured as moonlight, so a key light exists at every quality level), a custom night-city skybox, OutdoorAmbient about (115,110,165), 6-9 local lights per room (≤ 2 shadowed), additive Beam pools, unlit SurfaceGuis and emissive masks (visible at all quality levels). C "Soft Toybox" is the measured fallback; B "True Midnight" is for events.
3. **Around the level:** a hazed ground plane, a ring of reused kit façades, two skyline-card rings with emissive windows (300 and 600 studs), a Blender-rendered city skybox with a landmark. Client-side, about 30 draw calls.
4. **UI:** BuilderSans + Oswald (+ RobotoMono for tape timecodes), script-generated 9-slices, double `UIStroke` (`ScaledSize`), Linear `UIGradient` sheens, `CanvasGroup` only for fades, Blender icon sheets uploaded by Open Cloud, motion tokens.
5. **Animation:** code-authored `KeyframeSequence` written to `.rbxmx` by Lune and uploaded as an **Animation** asset (an Open Cloud type), so the engine Animator plays it; the Lua pose player is the fallback. Clones play **their owner's own animation pack**, driven by a state derived from the server recording.
6. **Verification:** a ladder from CI maths and engine audits, to Blender previews calibrated against a Studio board, to one-click Studio shots through the plugin API **`StudioCaptureService`** (returns a pixel buffer), to phone shots routed through a DataStore Claude reads with Open Cloud [spike]. Python grades every shot.

---

## 0. Diagnosis: the numbers behind "nearly black, flat, void"

**What the scene contains.** `default.project.json`: Realistic, `ClockTime 0`, `Brightness 0.5`, `Ambient (55,55,95)`, `OutdoorAmbient (75,80,130)`, `ExposureCompensation 0.2`, Atmosphere `Color (70,60,120)`, `Decay (35,30,75)`. No `Sky`. No level code creates a `Light` (only Neon lamps; `WorldView.luau`: "emissive parts, no lights").

**A first-order model** (matte surface × ambient in linear light × 2^EV, no tonemapper; Roblox's exact shading is undocumented, so check against the calibration board in §6):

| Ambient used (OutdoorAmbient) | EV | Ink floor `#1C1F3B` | Plum wall `#3A3560` | Steel `#7C86A6` | Marble `#D8C8A8` |
|---|---|---|---|---|---|
| **(55,55,95), today's indoor** | 0.2 | **1.2 %** | **2.9 %** | 11 % | 18 % |
| (75,80,130), today's outdoor | 0.2 | 2.2 % | 5.3 % | 17 % | 26 % |
| (100,100,150) | 0.5 | 3.9 % | 8.8 % | 24 % | 37 % |
| **(115-120,110-115,165-170), recipe A** | 0.3-0.5 | 4.5-5 % | 10-11 % | 26-28 % | 40-43 % |
| (140,135,190) | 1.0 | 8.6 % | 16 % | 39 % | 59 % |

The weak moon and the dark night sky (through `EnvironmentDiffuseScale`) add little, and the tonemapper compresses darks further: everything but marble and Neon sits under 5% luminance, as the owner's screenshots show. The vault's rule: "night is shown by **hue** … not by darkness; ambient stays around a third of full brightness" (*vault: Stylized Lighting Recipes* §3.4).

**Second cause: albedo.** STYLE_BIBLE §2 sets value bands for *surface colours*, but players see colour × light; Ink's luminance is about 12% even under white light, so as a night floor it can only be black. **Proposed rule:** the bands apply to *on-screen* luminance at bookmark B2 on a phone at quality 1: floors ≥ 12%, walls 15-30%, trims and loot displays ≥ 35%. Floors move from `ink` to a new `floor` swatch near `#3A365C`, with warm-marble rugs inside light pools; Ink stays for the table edge and outer void.

**Why it looks flat.** With no key and no local lights, every face gets the same ambient. The vault target is lit faces 1.5-2.5× shadow faces, with a warm/cool split (*vault: Lighting Untextured Art in Roblox*).

---

## 1. Night lighting that reads on low-end phones

### 1.1 What survives on a cheap phone (property table)

At quality 1-3 "shadows are disabled", lighting uses the voxel grid and draw distance shrinks (*vault: Mobile and Low-End Optimization* §2; [DevForum](https://devforum.roblox.com/t/if-i-care-about-performance-on-mobile-which-lighting-mode-should-i-use/431662)).

| Feature | Low phone (Q1-3) | Mid/high | Use it for |
|---|---|---|---|
| `Ambient`, `OutdoorAmbient`, `ColorShift_Top/Bottom`, `Brightness`, `ExposureCompensation` | yes | yes | **The night hue and the value floor. Put the mood here.** |
| Sun/moon direct light (no shadow) | yes | yes, plus shadows | The directional key: lit side vs shadow side |
| `GlobalShadows` / sun shadows | **no** | yes (`ShadowSoftness` only under Realistic) | Bonus depth on PC and high-end phones only |
| Local `Light` objects | yes, voxel: soft 4-stud blobs that leak through thin walls | per-pixel | Warm pools that read without shadows |
| `Light.Shadows` | no | yes (Realistic) | At most 2 hero lights |
| `EnvironmentDiffuseScale` / `EnvironmentSpecularScale` | reduced [UNVERIFIED by level] | yes | A sky-coloured fill and floor sheen |
| Bloom / ColorCorrection | "some effects may not show" at low quality (*vault: Atmosphere…* §4) [which: UNVERIFIED] | yes | Polish only; **never carry the night tint in ColorCorrection alone** |
| `Atmosphere` | yes; a "black fog" report at the lowest setting ([DevForum](https://devforum.roblox.com/t/black-fog-appears-on-low-graphics-and-shadow-rendering-issues/4141621)) | yes | Horizon fade; test at Q1 |
| `Material.Neon` | bright and flat; glows only where bloom runs | glows | Fixtures, lasers, signals |
| **SurfaceAppearance emissive masks** | **yes: "Emissives will now appear at all quality levels and they won't fade out in far distances"** ([beta](https://devforum.roblox.com/t/studio-beta-emissive-masks/4034414), [live](https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705)) | yes | Windows, signs, dials, skyline |
| `SurfaceGui.LightInfluence = 0` (+ `Brightness`) | yes | yes | Unlit light pools and signs (*vault: World-Space UI - BillboardGui and SurfaceGui*) |
| Beam/Trail/Particle `LightEmission 1`, `LightInfluence 0`, `Brightness > 1` | yes (particle counts scale with quality) | yes | Additive fake light: pools, shafts, haloes |
| `Highlight` | yes; the first one costs up to about 1 ms GPU on mobile | yes | Clone rims (already budgeted) |

Rule: **the frame must read at Q1 with no post-processing.** Hue comes from `ColorShift_Top` and ambient, value from albedo, local lights and unlit additive cards, and focus from emissive and Neon.

### 1.2 Recipe A, "Moonlit Diorama" (RECOMMENDED)

A **fake night**: night `ClockTime` gives a weak moon whose shadows "lose their crispness" ([DevForum fake-night threads](https://devforum.roblox.com/t/fake-night-system/3962991)). Keep a daytime sun, recolour it as moonlight and give the sun disc a moon texture; a custom night-city skybox makes `EnvironmentDiffuseScale` add indigo, not day-blue, fill. Result: a directional key at every quality level and night shown by hue.

| Node | Values |
|---|---|
| `Lighting` | `LightingStyle Realistic`, `PrioritizeLightingQuality true`, `GlobalShadows true`, **`ClockTime 15.0`, `GeographicLatitude 20`** (then tune so the sun is 45-55° up and 30-45° to one side of bookmark B1's yaw; check with `Lighting:GetSunDirection()`), **`Brightness 1.4`**, **`ColorShift_Top (150,175,255)`** (cool moon on lit faces), **`ColorShift_Bottom (40,30,70)`**, **`Ambient (95,90,140)`**, **`OutdoorAmbient (115,110,165)`** (Ambient ≤ OutdoorAmbient in every channel, or Ambient leaks outdoors: *vault: Lighting Technologies and Settings* §3), `EnvironmentDiffuseScale 0.30`, `EnvironmentSpecularScale 0.40`, `ExposureCompensation 0.30`, `ShadowSoftness 0.3` |
| `Sky` (new) | Six 1024 px faces of the "Heist City" night cubemap rendered in Blender (§2.1, L5), `CelestialBodiesShown true`, **`SunTextureId` = a moon image**, `SunAngularSize 9`, `MoonAngularSize 0`, `StarCount 0` (stars are baked into the faces) |
| `Atmosphere` | `Density 0.28`, `Offset 0.12` (the skyline silhouettes instead of ghosting), `Color (90,80,150)`, `Decay (55,45,105)`, `Glare 0`, `Haze 1.3`. Paint the skybox horizon in the same colour: haze takes its colour from the sky in some directions ([DevForum](https://devforum.roblox.com/t/atmosphere-haze-color-is-dark-in-one-direction-severity-depending-on-skybox/621787)) |
| `BloomEffect` | `Intensity 0.6`, `Size 24`, **`Threshold 1.15`**. The scene is brighter now, and threshold 1.0 would make marble glow; Neon and over-bright effects still exceed 1.15 |
| `ColorCorrectionEffect` | `Brightness 0`, `Contrast 0.12`, `Saturation 0.08`, `TintColor (240,240,255)` (mild: the night lives in the Lighting values) |
| `ColorGradingEffect` | `TonemapperPreset Default` |
| No | SunRays (the "moon" is rarely on screen); DepthOfField and Blur in play |

**Local lights per room (32 × 24 studs).** All have `Shadows = false` unless marked. Each is parented to an Attachment in the kit fixture, outside the shade mesh: a light inside its own lamp with shadows on is shadowed by the lamp (*vault: Light Sources and Shadows* §2).

| Light | Count | Settings | Why |
|---|---|---|---|
| Hero SpotLight over the focal prop (vault door, diamond) | 1 | `Range 36`, `Angle 60`, `Brightness 3`, `Color (255,214,160)`, **`Shadows true`** | Makes the focal feature the brightest thing; the only shadowed light in most rooms |
| Warm ceiling PointLights (the `Lamp_Ceiling_Bulb` fixtures) | 3-5 | `Range 20`, `Brightness 1.2`, `Color (255,205,150)` | Warm pools that keep the main route lit |
| Cool street/window SurfaceLight | 1 | `Range 30`, `Angle 90`, `Brightness 0.8`, `Color (150,170,255)`, on the street-side window face | The cool/warm split that sells "night heist" |
| Second shadowed light | 0-1 | as the hero spot; only in Big Score rooms | Masterplan ceiling of ≤ 4 shadow lights per view; aim for 2 |
| Gameplay lights | 0-2 | laser emitter `PointLight Range 6, Brightness 1, Alarm Red`; Gus's torch is `SpotLight Range 24, Angle 45, Brightness 2, Torch Amber, Shadows false` | Threats glow in their own colour |
| **Total per view** | **6-9 lit, ≤ 2 shadowed** | under the vault's 8-12 (2-3 shadowed) mid-phone rule of thumb (*vault: Light Sources and Shadows* §4) | |

Range now goes to 120 studs, but cost rises with range ([Extended Light Ranges](https://devforum.roblox.com/t/extended-light-ranges-doubling-the-limit-to-120/3954367)): keep ranges room-sized. Decorative lights get a `Culled` tag and the vault's client `LightDirector` (disable beyond 120 studs at 10 Hz, flicker; *vault: Light Sources and Shadows* §5). At low quality the voxel grid leaks through walls under 4 studs thick: keep lights 4+ studs from partitions that split two moods.

**Fake-light tricks (zero lighting cost).**

1. **Additive floor pool (Beam).** Two floor Attachments 14 studs apart; `Width0 = Width1 = 14`, `Segments 1`, `FaceCamera false` (rotate attachments so the ribbon lies flat; check once), a 256 px radial falloff PNG, `TextureMode Stretch`, `LightEmission 1`, `LightInfluence 0`, `Brightness 1.2`, warm marble, `Transparency 0.55`. One per lamp; it adds light rather than painting over the floor.
2. **Unlit SurfaceGui pool** (for shaped pools: window grids, sign glow): an invisible Part 0.03 studs above the floor, `SurfaceGui Face Top`, **`LightInfluence 0`**, `Brightness 1-1.5`, radial `ImageLabel`, `ImageTransparency 0.5`. **Never plain Decals:** they are lit, so they darken at night. (`Decal.EmissiveMaskContent` is in the 2026-10-27 API dump, but staff called decal emissives "in progress" [UNVERIFIED release].)
3. **Light shafts.** A Beam from the lamp down to the floor: `Width0 0.8 → Width1 10`, a vertical falloff texture, `LightEmission 1`, `Transparency 0.8`, `Brightness 1`, plus 6-10 dust motes (`Rate 2`, `Lifetime 5`, `Size 0.08`, `LightInfluence 0`). Only over hero props; at most 3 per view.
4. **Emissive masks over Neon** for windows, signage, the vault dial and fairy lights: `EmissiveStrength 1.5-3` (higher clips to white), `EmissiveTint` by code for alarms; every quality level, no extra instances. Glow stays at 1-16% of the frame ("above ~16% shapes dissolve in bloom", *budgets.md*).
5. **Painted light:** atlas cells for lit floor tiles and wall gradients near lamps, darker contact cells at wall bases, so contact shadows survive at Q1.

**Shadow strategy.** Sun shadows are a PC/high-end bonus; nothing depends on them. One shadowed hero light per room, two in the Big Score. Clones, VFX, glass, Neon, clutter and backdrop get `CastShadow = false`. The perf governor (tier ≥ 3) also clears `Shadows` on lights tagged `HeroShadow` (disable, never delete).

### 1.3 Recipe B, "True Midnight" (event locations: Museum, Moon)

| Node | Values |
|---|---|
| `Lighting` | Realistic + Prioritize, `ClockTime 0`, `GeographicLatitude 41.7`, `Brightness 2.0` (the moon is weak; tune), `ColorShift_Top (140,165,255)`, `Ambient (110,100,160)`, `OutdoorAmbient (130,120,180)`, `EnvironmentDiffuseScale 0.10` (the night sky is dark), `EnvironmentSpecularScale 0.35`, `ExposureCompensation 0.6` |
| `Sky` | default or custom; `StarCount 4000`, `MoonAngularSize 16` |
| `Atmosphere` | `Density 0.22`, `Offset 0.2`, `Color (70,65,130)`, `Decay (35,30,80)`, `Haze 0.8` |
| Post | Bloom 0.8 / 28 / 1.1; ColorCorrection Contrast 0.1, Saturation 0.05, Tint (235,235,255) |
| Local lights | 10-12 per view (2 shadowed): the moon key is weaker, so the pools carry more |

Risks: soft moon shadows; custom-skybox dimming at night [UNVERIFIED]; more lights than A. Derived from the vault's *Readable night* with ambient raised about 30%.

### 1.4 Recipe C, "Soft Toybox" (performance fallback)

Cheapest and most uniform across devices; Soft + Prioritize behaves like the old ShadowMap path (*vault: Lighting Technologies and Settings* §1).

| Node | Values |
|---|---|
| `Lighting` | **`LightingStyle Soft`, `PrioritizeLightingQuality true`**, fake-night sun as in A (`ClockTime 15`, `Latitude 20`), `Brightness 1.6`, `ColorShift_Top (170,190,255)`, `Ambient (120,110,170)`, `OutdoorAmbient (135,125,185)`, `EnvironmentDiffuseScale 0.2`, `EnvironmentSpecularScale 0`, `ExposureCompensation 0.2` |
| Sky / Atmosphere | as in A |
| Post | Bloom 0.9 / 24 / 1.0 (Neon carries the night; keep white surfaces off-white), ColorCorrection Contrast 0.15, Saturation 0.12 |
| Local lights | 6-8 PointLights, `Range 16-24`, no shadows; Beam pools as in A; contact shadows baked into the atlas |

### 1.5 Recommendation and order of work

1. Ship **A** in `default.project.json` with a `Sky` node (faces set by `KitService` from `assets/kit_ids.json` if Rojo cannot write them [spike]); update STYLE_BIBLE §3 and `place_check`.
2. Lights as **kit attachments** (`LightPoint`, `LightSpot`, `LightPool` in `kit_manifest.json`); `KitDresser` builds Light, Beam and SurfaceGui from `Config.Lighting`; the greybox gets the same lamp grid.
3. Lift the floor albedo (§0).
4. Gate on the W1 golden room's 12 daily shots. Switch to **C** only if the S1 bench stays above 33 ms p95 on the low Android, or Q1 shots fail §6.3.
5. Per-location recipes as data: Christmas Eve = A, OutdoorAmbient +10%; Museum = B; Sky Lounge = A with `ColorShift_Top (255,215,160)`; Moon = B with grey ambient.

---

## 2. Environment around the level (killing the void)

A diorama should sit on a **table inside a world**, not float in black. Everything below is static decoration, so **the client builds it** (cloned from `ReplicatedStorage/Backdrop` to the crew's instance origin; instances sit 3,000 studs apart): no replication, no server cost, no streaming. Every part is `Anchored` with `CanCollide/CanQuery/CanTouch/CastShadow` false, so raycasts and Gus's fan never hit it (*vault: Level of Detail and Model Streaming*, nuance 6).

### 2.1 Layers (near to far)

| Layer | Distance | What | Construction | Budget |
|---|---|---|---|---|
| L0 Table | under the level to ~1,500 studs | Ground plane (`floor`/`ink_hi`) with a 3-stud bevelled plinth edge round the playable bounds | One 2048² Part; plinth from kit trims; Atmosphere fades it into the horizon | 5 instances, < 1k tris |
| L1 Street | 20-120 studs | Street, sidewalk, lamp posts, **neighbour façades** (`Storefront_24x12`, `BankFront_24x12`, darker atlas, emissive windows) | Reused kit meshes so they instance; 1-2 street `SpotLight`s (Range 30, no shadows) + Beam pools | ≤ 25 instances, ≤ 15k tris |
| L2 Skyline ring near | radius 300, height 50-90 | Building silhouettes with lit windows | **One inward-facing cylinder mesh** (48 quads) with `SurfaceAppearance`: ColorMap 1024×256 (alpha cut-out, `AlphaMode Transparency`) + **EmissiveMask** (windows) with `EmissiveStrength 2`, tint warm and cool. Subtends about 10-17° from the level (*vault: Level Design Principles*, angular size) | 1 draw, ~100 tris, 2 maps |
| L3 Skyline ring far | radius 600, height 120-160 | Taller towers, a bluer tint, sparser windows | Same as L2, second texture | 1 draw, ~100 tris, 2 maps |
| L4 Life | 100-600 | 2 searchlight Beams (`FaceCamera`, `Width 8 → 40`, `Transparency 0.85`, `LightEmission 1`, yaw ±25° over 9 s); 3 blinking Neon aircraft lights on L3 towers (1 Hz); 1 traffic Beam (headlight dots, `TextureSpeed 0.6`) | one client loop | 6 instances |
| L5 Sky | ∞ | **"Heist City" cubemap**: horizon glow band (Plum/Torch), baked stars, **one landmark** (clock tower with a beacon) ≥ 3-5° tall; under ~2° it is "a speck on a phone" (*budgets.md*) | Blender equirectangular render cut into 6 × 1024 px faces, uploaded by `kit_upload.py --images` | 6 × 1024² textures |
| Snow (Christmas) | follows the camera | `Rate 40`, `Lifetime 6`, `Size 0.15`, `Speed 3`, `LightInfluence 0.3` | emitter on a camera-following Part | ≤ 240 alive (Q1: 120) |

Rings *and* a skybox, because the skybox has no parallax; rings at 300 and 600 studs slide against each other as the camera orbits (*vault: Water Sky and Atmosphere Art*, "Sky dressing").

### 2.2 Budgets for the whole backdrop

| Item | Budget |
|---|---|
| Draw calls | ≤ 30 (L1 ≤ 22 with instancing, L2-L4 ≤ 8) |
| Triangles | ≤ 25k |
| Instances | ≤ 60 |
| Textures | 4 maps at 1024×256 (rings) + 6 × 1024² (sky); the sky faces can drop to 512 for the Moon level if memory telemetry is tight |
| Lights | ≤ 2 (street lamps), no shadows |
| Client cost | one Heartbeat loop for searchlights and blinkers, < 0.05 ms |

### 2.3 Fog and atmosphere rules

- Atmosphere hides distance but does not cull it (*vault: Atmosphere Sky Clouds and Post-Processing* §1); fine here, the backdrop is cheap.
- **Planning camera B3 is 120 studs up**, so haze greys the level: tween `Density` to 0.1 in the plan view, owned by the one `LightingController`.
- Keep `Offset` ≥ 0.1 or distant geometry ghosts against the sky.

### 2.4 Streaming

The level stays `PersistentPerPlayer` (already in `LevelBuilder`), mechanisms `Atomic`. If the backdrop ever moves to the server: rings as one small `Persistent` model, `SLIM` on static façades (no Humanoids; [SLIM docs](https://create.roblox.com/docs/workspace/streaming/slim)).

---

## 3. Premium UI on Roblox (late 2026)

### 3.1 What is available now

| Feature | Status (Nov 2026) | Use |
|---|---|---|
| `FontFace` (`Font.new/fromName/fromId`) | Live. Built-ins (API dump): AmaticSC, Arimo, Bangers, Bodoni, **BuilderSans**, Creepster, DenkOne, Fondamento, FredokaOne, Garamond, GrenzeGotisch, IndieFlower, JosefinSans, Jura, Kalam, LuckiestGuy, Merriweather, Michroma, **Montserrat** (Gotham maps to it), Nunito, **Oswald**, PatrickHand, PermanentMarker, Roboto, RobotoCondensed, **RobotoMono**, Sarpanch, SourceSans, SpecialElite, TitilliumWeb, Ubuntu; ~80 Creator Store families via `fromId` ([marketplace fonts](https://devforum.roblox.com/t/fonts-in-creator-marketplace-81-new-fonts/2164977)); **no custom upload** ([DevForum](https://devforum.roblox.com/t/can-i-add-a-custom-font-to-my-roblox-game/2542482)) | §3.2 |
| `UIStroke` with `StrokeSizingMode` (ScaledSize), `BorderOffset`, `BorderStrokePosition`, `ZIndex` (several strokes per object) | Live (properties in the API dump) ([UIStroke improvements](https://devforum.roblox.com/t/studio-beta-uistroke-improvements-scaling-offsets-and-more/3958036)) | Double outlines, outer glow rings |
| `UIGradient` Linear | Live | Sheens, panel shading |
| `UIGradient.Type` Radial/Elliptical/Conical, `Scale`, `TileMode` | **Studio beta: "you can't publish live games"** with them ([Upgraded UI Gradients](https://devforum.roblox.com/t/studio-beta-upgraded-ui-gradients/4846594)) | Not before release; use a radial PNG |
| `UIShadow` (BlurRadius, Spread, Offset, Inset, Mode) | In the dump; upgraded version in Studio beta, live publishing blocked [UNVERIFIED]; "native UI shadows and glows" on the mid-2026 roadmap ([Roadmap](https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473)) | When live; until then a 9-slice shadow PNG |
| **UI Styling** (`StyleSheet`, `StyleRule`, `StyleLink`, `StyleDerive`, tokens as attributes, StyleQuery May 2026, **Styling Transitions** July 2026) | Full release ([UI Styling](https://devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082), [Transitions](https://devforum.roblox.com/t/full-release-styling-transitions/4646870)) | The token layer for theme, hover and press |
| `Path2D` + rotated clipping | Live; the old clipping flag was removed on 2026-11-03 ([clipping post](https://devforum.roblox.com/t/opt-in-phase-introducing-clipping-support-for-rotated-elements-path2d/4737864)) | Route lines on the Clone Deck, tape-reel shapes |
| UI blur, text shadows, 2D animated images | Announced at RDC26 for "late 2026" ([RDC26](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880)) | Watch list |
| `CanvasGroup` | Live; memory per group, black fills on some low-end phones, low resolution at quality ≤ 3 ([1](https://devforum.roblox.com/t/canvasgroup-makes-its-content-low-quality-at-certain-sizes-and-graphics-level-3-or-below/2946471), [2](https://devforum.roblox.com/t/canvas-group-filled-with-black-for-mobile-devices/2208465)) | Short fades only |

### 3.2 Type system

Two families (the vault's limit, *vault: Text Fonts and Rich Text* §1), plus one mono font that only appears inside the "tape" motif:

| Role | Face | Size at the 1080p design height | Stroke |
|---|---|---|---|
| Display: level titles, "8 OF ME", "LOOP 3" card | `Font.fromName("Oswald", Enum.FontWeight.Bold)` (condensed caper poster; big numbers stay narrow on phones) | 48-72 | ink outer stroke 8% of the size, `ScaledSize`, `LineJoinMode Round` |
| HUD labels, buttons | `BuilderSans` ExtraBold (already used in `Hud.luau`) | 22-32 | 2 px ink |
| Body, tips, settings | `BuilderSans` Medium/Bold | 16-20 (never under 12 px drawn on phones) | none |
| **Tape/timecode**: "◀ ME, 20 SEC AGO", "REC 00:42", Run counter | `RobotoMono` Bold | 18-28 | 2 px ink |
| Retire | `Enum.Font.FredokaOne` (one use left in `src/client`) | — | — |

Preload the faces during load (`ContentProvider:PreloadAsync`). Draw ◀ ▶▶ and the badge glyphs ●■▲◆ as **images**, so font fallback cannot change them.

### 3.3 Panels: 9-slice, strokes, gradients

- **Script-generated 9-slices** (`tools/ui/panels.py`, Pillow): 128×128, 24 px radius, 2 px top inner highlight (white 18%), 3 px bottom bevel (ink 25%), 2% grain (kills banding and the "flat Frame" look). `ScaleType Slice`, `SliceCenter Rect(32,32,96,96)`, `SliceScale` 0.5 phone / 1 PC. Tints by `ImageColor3` (Ink panel at 8% transparency, Plum card, Marble chip), not separate uploads. A soft-shadow 9-slice (64 px blur, ink 55%, offset (0,4)) until `UIShadow` is live.
- **Double stroke** on primary buttons: stroke A `Border`, `ZIndex 1`, 3 px ink, `Outer`; stroke B `ZIndex 2`, 1 px white at 70% transparency, `Inner`. Text strokes `ScaledSize`. **Never tween text stroke `Thickness`** (it re-renders glyph sizes every frame; *vault: Text Fonts and Rich Text* §5): pulse a `UIScale`.
- **Gradients:** Linear top→bottom (1.0 → 0.85 value) on slabs; a **sheen** Frame with `Transparency` (1, 0.6, 1), `Rotation 20`, `Offset` (-1,0) → (1,0) in 0.6 s every 4 s, only on the "next action" button.
- **CanvasGroup** only for the 0.2 s fade of the Results card and Clone Deck; ≤ 2 alive; no static text inside; `Visible = false` once faded.
- Clone hues in UI only as player/clone identity (badges, deck rows), never decoration.

### 3.4 Icon pipeline (no Studio)

1. **Render in Blender** (`tools/blender`): the kit-preview light rig (warm key (255,210,160), cool rim, indigo world), Eevee, `film_transparent`, 512 px, 2-tone toon split, upper-left rim highlight, thick dark hull outline; no hairline outlines, no smooth gradients (*vault: Glossy Icon Style - Owner Reference*).
2. **Downsample to 256 px** (the UI maximum, *vault: UI Asset Pipeline*) and pack **1024² sheets of 4×4**, drawn with `ImageRectOffset/Size`.
3. **Upload** with `tools/kit_upload.py --images` (Open Cloud, `assetType Decal`). Resolve decal → image id automatically with a Luau Execution task (`InsertService:LoadAsset(decalId)`, read `Decal.Texture`) instead of `--set-image` [spike]. Ids live in `Theme.Images`.
4. **Gate:** a 32/48/64 px contact sheet on dark and light swatches, which Claude reads before upload.

### 3.5 Motion tokens

One `Motion` module (*roblox-ui-builder* §4): 0.1-0.2 s feedback and exits, 0.2-0.35 s entrances, 0.35-0.6 s big reveals; under 0.08 s is invisible on low-end phones.

| Token | Spec |
|---|---|
| `press` | `UIScale` 1 → 0.92, 0.06 s Quad Out; release → 1, 0.14 s Back Out; plus a click sound and `HapticService` light on touch |
| `pop` (cards, badges) | `UIScale` 0.6 → 1.05 (0.18 s Quad Out) → 1 (0.1 s Sine InOut), about the centre (*vault: UI and GUI Animation*, Pattern 1) |
| `slideIn` (panels) | position offset 24 px → 0 + transparency 1 → 0 over 0.24 s Quint Out; distance-scaled `clamp(0.12 + 0.012·√px, 0.15, 0.45)` |
| `counter` (Cash, loot) | numbers roll over 0.35 s (Quad Out); the counter bumps `UIScale` 1 → 1.15 → 1 in 0.18 s on each increase; the pitch rises a semitone per pickup within 0.5 s |
| `flyToHud` (coins) | 3-6 coin icons on a quadratic Bézier, 0.45 s, staggered 40 ms, landing on the counter bump |
| `stamp` ("BUSTED", "8 OF ME") | scale 1.6 → 1, 0.12 s Quad In, then 2 frames of 4 px shake, then rotation -6° held |
| Reduced motion | `GuiService.ReducedMotionEnabled`: movement becomes fades and colour; no scale overshoot, no shake |

Styling Transitions (July 2026) can carry `press`/hover declaratively if `Ui.luau` moves its tokens into a `StyleSheet`; optional for launch.

### 3.6 Mobile safe areas and the top bar

- **Two layers** (started in `Hud.luau`): interactive UI with `ScreenInsets = CoreUISafeInsets`; full-bleed effects (scanlines, vignette, flashes) with `None`, `DisplayOrder` one below; `SafeAreaCompatibility = None` on both (*vault: Safe Areas and Insets* §6).
- **Top-bar row:** pause chip and gear in a `TopbarSafeInsets` gui with a horizontal `UIListLayout`; anything else aligned to the bar reads `GuiService.TopbarInset` live (*same note* §9).
- **Jump button:** GRAB, END RUN and REWIND are laid out around `TouchGui.TouchControlFrame.JumpButton.AbsolutePosition` read at runtime: ≥ 12 px gaps, ≥ 44 px drawn targets, primaries 72-96 px (*vault: LihFolk UI Spec*).
- **Test** layout in the Device Simulator (19.5:9 notch, iPad 4:3, 1080p); feel only on the real phone.

---

## 4. Character animation without Studio

### 4.1 Pipeline options

| Path | How | Pros | Cons |
|---|---|---|---|
| **A. Code-authored clip → Open Cloud Animation asset (recommended spike)** | Pose data as Luau tables in `src/shared/AnimData/` (keys per joint: time, CFrame as euler degrees, easing). A Lune script (`tools/anim_build.luau`) builds `KeyframeSequence > Keyframe(Time) > Pose("HumanoidRootPart", Weight 0) > Pose("LowerTorso", Weight 1) > …` with `@lune/roblox`, then writes `.rbxmx`. Upload with Open Cloud `POST /assets/v1/assets`, `assetType Animation`, file `.rbxm/.rbxmx` (supported type: [usage guide](https://create.roblox.com/docs/cloud/guides/usage-assets), [more asset types](https://devforum.roblox.com/t/open-cloud-upload-support-for-more-asset-types/4022082)). The id goes into `Config` | The engine Animator plays it: free CPU, blending, priorities, markers, `ClientAnimatorThrottling`, works with IK and Animation Graphs | The docs warn that "rbxm or rbxmx files edited outside of Roblox Studio might not upload or function" → **[spike]** with one 2-key clip on Gus; assets must belong to the experience owner (*vault: Animation Asset Permissions and Groups*) |
| B. Lua pose player (fallback, already in MASTERPLAN §6.7) | The same pose tables sampled on the client; write `Motor6D.Transform` in `PreSimulation` (writes in PreRender/Heartbeat get overwritten: *vault* symptom table) | Nothing to publish, no permissions; measured 22 µs per 25-joint rig-frame, ≤ 0.084° error vs the Animator (*vault: Lua Keyframe Player*) | Implement rotation-vector interpolation, fades and weights yourself; distance LOD needed |
| C. CurveAnimation | The same upload path; Studio-only `RegisterAnimationClip` ids never play live (*vault: CurveAnimation and Curve Channels*) | Fewer keys for smooth motion | Only if A works |

`Register*` ids load nothing live (*vault: Replication and Ownership*); `place_check` greps for them. **Clip rules:** times in seconds on a 30 fps grid; root pose weight 0; CubicV2 easing (legacy Cubic runs reversed); an anticipation key before big actions; 3-5 frame holds on contacts; 5-10° overshoot on settles. Gus's three clips are 8-14 keys each.

### 4.2 Procedural walk for rigid characters (Gus, mannequin clones)

A rigid stylised walk needs no IK: a sine FK cycle on the Motor6Ds, with phase advanced by the vault's cadence formula so step rate tracks speed and never resets (*vault: Procedural Gait and Footstep Planning*):

```lua
--!strict
-- Client: FK walk for a rigid R15-like rig. v = ground speed (studs/s), dt = frame time.
-- Write in RunService.PreSimulation so the Animator does not overwrite it.
local W = { hipSwing = 28, kneeLift = 40, armSwing = 24, elbow = 18, bob = 0.12, twist = 6, lean = 4 }
local phase = 0
local function step(m: { [string]: Motor6D }, v: number, dt: number)
	local mv = math.clamp(v / 10, 0, 1)
	local f = math.clamp(1.45 + 0.0105 * v, 1.55, 2.75) -- cycles per second
	phase = (phase + f * dt * mv) % 1
	local s, c = math.sin(phase * 2 * math.pi), math.cos(phase * 2 * math.pi)
	local r = math.rad
	m.LeftHip.Transform = CFrame.Angles(r(W.hipSwing * s * mv), 0, 0)
	m.RightHip.Transform = CFrame.Angles(r(-W.hipSwing * s * mv), 0, 0)
	m.LeftKnee.Transform = CFrame.Angles(r(-W.kneeLift * math.max(0, -c) * mv), 0, 0) -- bend only in swing
	m.RightKnee.Transform = CFrame.Angles(r(-W.kneeLift * math.max(0, c) * mv), 0, 0)
	m.LeftShoulder.Transform = CFrame.Angles(r(-W.armSwing * s * mv), 0, 0)
	m.RightShoulder.Transform = CFrame.Angles(r(W.armSwing * s * mv), 0, 0)
	m.LeftElbow.Transform = CFrame.Angles(r(W.elbow * mv), 0, 0)
	m.RightElbow.Transform = CFrame.Angles(r(W.elbow * mv), 0, 0)
	-- Two dips per cycle (one per step), torso counter-twist, slight forward lean
	m.Root.Transform = CFrame.new(0, -W.bob * mv * (1 + math.cos(4 * math.pi * phase)) / 2, 0)
		* CFrame.Angles(r(-W.lean * mv), r(W.twist * s * mv), 0)
	m.Neck.Transform = CFrame.Angles(0, r(-W.twist * 0.7 * s * mv), 0) -- head keeps facing forward
end
```

Weights go in `Config.Gus`. Add 2 frames of squash per contact (root Y −0.05) and idle breathing (root Y ±0.03 at 0.25 Hz, shoulders ±2°) when `mv < 0.1` (*vault: Idle Breathing and Secondary Motion*). Mannequin clones (look C) reuse it.

### 4.3 IK for looking (Gus, Line-up, garage)

`IKControl` `Type LookAt`, `EndEffector Head`, `ChainRoot UpperTorso`, `SmoothTime 0.15`, `Weight` tweened over 0.12-0.2 s (toggling `Enabled` pops). **Clamp the target yourself**: yaw ±70°, pitch ±40°, elliptical, and lose interest behind with 30° hysteresis (*vault: IKControl Reference*, *Look-At Aim and Head Tracking*). Uses: Gus's head finds the suspicious actor before his body turns (the double-take); Line-up clones look at the camera.

### 4.4 Making avatar clones mirror the player

Goal: a clone moves like *that* player, including their animation pack (Ninja run, Stylish walk): free "it's me" recognition.

1. **State from the recording, not the client.** The client view derives state from the 20 Hz samples and recorded events (`src/shared/Rec`): speed (Catmull-Rom derivative), airborne/rising, `grab`, `carry`, `press`, `busted`. No new intents, no trust issue, nothing added to the format (CLAUDE.md: echoes act only through Actors and recorded events).
2. **The owner's pack.** When `Avatars.luau` builds the template, the server reads the owner's `Animate` script children (`walk.WalkAnim`, `run.RunAnim`, `idle.Animation1/2`, `jump`, `fall`, `climb`) into template attributes (`EH_AnimWalk` …), default R15 ids as fallback. Catalog packs are Roblox-owned and should play on any rig [UNVERIFIED: spike with 3 packs]; `HumanoidDescription` fields are bundle-level and unreliable ([DevForum](https://devforum.roblox.com/t/animations-applied-to-humanoiddescription-do-not-work/1560673)).
3. **Clone animator** (client, pooled rig): idle/walk/run loaded; weights cross-fade by speed (walk 0-10, run 10-18 studs/s); `AdjustSpeed(speed / clipBase)` (about 8 walk, 16 run; measure per pack); jump/fall one-shots; carry as an `Action` upper-body clip. A `Blend1DNode` on `SetParameter("Speed")` is the documented graph setup (*tech.md F1*).
4. **Phase lock:** on seek, rewind or reel, `TimePosition = (distanceTravelled / stride) % Length`, so live loop, rewind and reel match. Reverse play by negative `AdjustSpeed` [verify] or per-frame seek.
5. **Budget:** `ClientAnimatorThrottling = Enabled`; ≤ 4 tracks per clone (Server Authority caps Animators at 8); beyond 25 studs, the mannequin plus §4.2 FK; `EH.EchoAnim` inside ≤ 1.5 ms for 12 clones (§8.6).

---

## 5. VFX recipes

Rules (*lihfolk-vfx*): client only, one Heartbeat loop, `Emit()` bursts; VFX parts anchored, non-colliding, `CastShadow false`; three tones (white core, body, saturated dark ink); `LightInfluence 0` on glow emitters (the default 1 darkens them in shade); touch density 0.6, cap 360 live. Preload textures early: an unloaded Beam texture draws a solid bar, and fresh uploads fail `PreloadAsync` for 20-60 s (*vault: Beams and Trails*).

### 5.1 Hologram clones (on top of the W1 look B)

| Layer | Settings | Cost |
|---|---|---|
| Body | Opaque SmoothPlastic in the owner hue at 85% value; older runs 12% dimmer each (MASTERPLAN §6.5) | the rig |
| Rim | **one persistent `Highlight` per owner group**: `OutlineColor` hue, `OutlineTransparency 0`, `FillColor` hue, `FillTransparency 0.8`, `DepthMode Occluded`; the x-ray group is `AlwaysOnTop` with `OutlineTransparency 0.6` | ≤ 4 + 1 Highlights |
| **Floor projector pool** | a flat additive Beam disc under each clone (§1.2 trick 1): `Width 3.2`, hue, `LightEmission 1`, `LightInfluence 0`, `Brightness 1.5`, `Transparency 0.55` | 1 Beam per clone |
| Scan band (newest clone only) | one Neon ring part (`Size 3.4×0.12×3.4` cylinder, `Transparency 0.3`) sweeping feet → head in 0.9 s, every 3 s | 1 part |
| Flicker | every 2.5-4 s at random, `LocalTransparencyModifier` 0 → 0.5 → 0 over 2 frames; older runs more often | none |
| Motion trail | `Trail` from shoulder to hip attachment, `Lifetime 0.3`, `WidthScale 1 → 0`, `Transparency 0.4 → 1`, `LightEmission 1`, `Brightness 2`, enabled only above 6 studs/s | 1 Trail per clone |
| Clone light (High tier only) | a PointLight on the newest clone of each owner: `Range 8`, `Brightness 0.6`, hue, `Shadows false`; 0 on tiers ≥ 2 | ≤ 4 lights |
| Busted | 3 × 2-frame glitch slices (parts offset ±0.3 studs on X), then a tape-ribbon burst: 20-30 particles, ribbon texture, `Squash -0.6`, `Speed 10-16`, `Drag 4`, `RotSpeed ±240`, `Lifetime 0.5-0.8`, Tape Grey + hue | ≤ 30 particles |

ForceField's free Fresnel shimmer glitches over other transparent parts (*visuals.md* F2): S1 bench only.

### 5.2 Rewind ("◀◀", RewindDirector 1.8 / 1.0 / 0.8 s)

| Beat | Recipe |
|---|---|
| Hit (0-0.15 s) | Camera-parented `ColorCorrectionEffect` (the grade stack, *vault: Atmosphere…* §4): `Saturation 0 → -0.8`, `TintColor (205,235,255)`, `Contrast +0.15`, Quad Out; FOV 70 → 80 (none under reduced motion); `BlurEffect Size 0 → 6` |
| Run back | Every actor plays its recording backwards at an eased 25-45x with Trails on (`Lifetime 0.4`, `LightEmission 1`, hue). Full-bleed gui (`ScreenInsets None`): a scanline `ImageLabel` (`ScaleType Tile`, `TileSize` 4 px, `ImageTransparency 0.85`) scrolling 60 px/s; 2 tracking-noise bars (Frames with Linear `UIGradient` transparency) sliding down in 0.4 s each; a "◀◀ REWIND" label in RobotoMono with a 2 px offset copy in Clone Cyan at 60% (a chromatic split); tape-hiss audio pitched down |
| Snap (last 0.12 s) | white flash Frame, transparency 0.5 → 1 over 0.12 s; blur back to 0; saturation back to 0 over 0.2 s; "LOOP 3" `stamp`; then the new clone's tape print |
| Reduced motion | no FOV, blur or scanline scroll; a cross-fade with the label only |

### 5.3 Plate press

- Pad sinks 0.15 studs in 0.06 s (Quad Out) and springs back 0.12 s after release; the rim ring tints to the presser's hue (STYLE_BIBLE: the plate ring is a runtime-tinted Neon part).
- Pulse: one pooled flat ring part per plate scales 1 → 1.6 while transparency goes 0.2 → 1 over 0.35 s.
- Sparks: `Emit(8)`, square spark texture, hue, `LightEmission 1`, `LightInfluence 0`, `Size 0.25 → 0`, `Speed 6-10`, `SpreadAngle 70` upward, `Drag 6`, `Acceleration (0,-20,0)`, `Lifetime 0.25-0.4`.
- **Causality wire:** a chevron Beam from plate to door (`TextureMode Wrap`, `TextureSpeed 3` toward the door, presser hue, `Width 0.4`, `Transparency 0.4`), 0.6 s on press, 0.8 transparency while held (*vault: Beams and Trails* §3); the door lamp turns green as the pulse arrives. Clack sound and a light haptic for the presser.

### 5.4 Laser

- Three Beams between the emitter attachments, `FaceCamera true`: **dark edge** `Width 0.55`, `Color (60,0,12)`, `LightEmission 0`, `Transparency 0.45` (it keeps the laser readable over marble); **body** `Width 0.32`, Alarm Red `#FF3838`, `LightEmission 1`, `LightInfluence 0`, `Brightness 3`, noise strip texture, `TextureSpeed 2`, `TextureLength 4`; **core** `Width 0.07`, white, `Brightness 6`.
- A floor/impact dot: a Neon sphere of 0.3 studs plus an emitter at `Rate 6` (tiny sparks, `Lifetime 0.2`).
- Light: one `PointLight Range 6, Brightness 1, red, Shadows false` per emitter pair; at most 2 per view.
- Off/on: 3 flickers over 0.6 s (transparency 0 ↔ 0.8 at 10 Hz) timed to the server window (MASTERPLAN §8.10), then a 0.1 s "charge" brightness ramp 6 → 10 → 6 on the core.
- **Seen:** the beam brightness doubles for 0.15 s and a red ring expands on the floor at the contact point.

### 5.5 Coin and loot burst (banking)

- Bank: `Emit(12)` at the van, sparkle texture, Heist Gold, `Size 0.6 → 0`, `LightEmission 0.6`, `LightInfluence 0`, `Brightness 2`, `Speed 12-18`, `SpreadAngle 50` up, `Acceleration (0,-40,0)`, `Drag 2`, `Lifetime 0.5-0.8`, `RotSpeed ±180`; a gold ground ring (0.3 s) and a small white flash card 1 frame late. UI: `flyToHud` + `counter`, aggregated to one "+$1,240" per 0.2 s (*vault: Collectible Pickup FX*).
- Idle loot: one shared bob/spin loop (`BulkMoveTo`), phase-seeded, a glint `Emit(1)` every 1.5-3 s, never a constant emitter.
- Big Score finale: `Emit(24)` gold fountain + confetti flipbook (custom flipbook layouts are a Client Beta: [DevForum](https://devforum.roblox.com/t/client-beta-optimize-your-particle-animations-with-custom-flipbook-layouts/4005128); standard grids work today).

### 5.6 Budgets per event (touch, density 0.6)

| Event | Particles | Beams/Trails | Parts | Lights |
|---|---|---|---|---|
| Clone spawn (each) | ≤ 18 | 0 | 1 ring | 0 |
| Busted | ≤ 30 | 0 | 0 | 0 |
| Plate press | ≤ 8 | 1 wire | 1 ring (pooled) | 0 |
| Laser (steady, per pair) | ≤ 3 | 3 | 1 dot | ≤ 1 |
| Bank | ≤ 14 | 0 | 1 ring | 0 |
| Rewind | 0 world particles | 1 Trail per actor | 0 | 0 |

---

## 6. Verification: trustworthy visuals when Claude cannot see Studio

### 6.1 Is there a headless render path? (checked thoroughly)

| Path | Renders? | Verdict |
|---|---|---|
| Open Cloud Luau Execution (`tools/cloud_test.py`) | No: a headless server, no GPU | Good for **audits** (counts, flags, budgets), not pixels |
| `ViewportFrame` / `EditableImage` on a server | No rendering on servers; EditableImage is pixel memory, not a camera | No |
| **`StudioCaptureService`** (plugin): `RequestScreenshotPermissionAsync`, `CanCaptureScreenshot`, `CaptureScreenshot` → **`StudioScreenshotCapture`** with `GetBuffer`, `BufferFormat` (RGBA8 default), `Resolution`, `ScaleAsync`, `UICaptureMode` (API dump 2026-10-27; [docs](https://create.roblox.com/docs/reference/engine/classes/StudioCaptureService.md) via search) | **Yes, real pixels from Studio's 3D viewport** on the owner's PC | **Best Studio path** (§6.2 R3) |
| Studio MCP `screen_capture` | Yes, on the owner's machine; black if Studio is not the foreground window; AlwaysOnTop billboards missing (*vault: Roblox Studio MCP Server* §5.4). The dump also has `CaptureService.StartVideoCaptureForMCPAsync` | Works when Claude runs on the owner's PC; this cloud session would need a Remote Control folder |
| `CaptureService:CaptureScreenshot` (client, published game) → `AssetService:CreateEditableImageAsync` → `ReadPixelsBuffer` | Real **device** pixels; one developer used it to send captures to a web server, but others got "cannot … create editable image from temporary texture id" ([Captures APIs thread](https://devforum.roblox.com/t/captures-apis-are-now-available/2838188/154)); EditableImage is capped at 1024², and needs the Mesh/Image API toggle | **[spike]**; the only automatic phone path |
| `TakeScreenshotCaptureAsync` | Listed in the docs, disputed on the forum ([thread](https://devforum.roblox.com/t/captureservicetakescreenshotcaptureasync-api-does-not-exist/4267335)) | Ignore until confirmed |

### 6.2 The verification ladder (report the rung reached for every visual change)

- **R0, CI maths:** `place_check` asserts the recipe; `eh_palette.py` gains the §0 model and fails if a gameplay swatch under OutdoorAmbient and EV alone falls below 8% screen luminance (floor 6%); Oklab and reserved-hue audits as today.
- **R1, engine audit** (Open Cloud Luau Execution on the saved test place): lights per room ≤ 9, shadowed ≤ 2, `CastShadow` off on VFX/clone/backdrop parts, emissive count, Neon share, instances and triangles (`LihFolkWorld.budgetReport`), no `Register*` ids.
- **R2, calibrated Blender:** a **calibration board** (8 swatch cubes, a white cube, a Neon strip, a pool, a hero spot under recipe A) built in both engines; after one Studio capture, Claude fits world/sun/light strength and exposure in `kit_preview.py` until per-swatch luminance error is ≤ 3 points. Blender shots are then trusted for *relative* choices and labelled "approximation".
- **R3, Studio one click:** a **PhotoBooth plugin** (installed once) poses B1-B4, captures with `StudioCaptureService:CaptureScreenshot` (UI excluded through `UICaptureMode`), reads `GetBuffer()`, encodes a PNG (stored DEFLATE, about 80 lines of Luau) and POSTs it to the GitHub contents API on a `shots` branch (the token is kept in `plugin:SetSetting`). Claude pulls and reads the PNGs. The Q1 row sets `settings().Rendering.EditQualityLevel` [verify writable]. **[spike, ~2 h]**
- **R4, phone one tap:** a dev-only Photo mode (owner UserId, test place) hides HUD and nameplates, cycles B1-B4 with a burned-in caption, then `CaptureScreenshot` → `CreateEditableImageAsync` → `ReadPixelsBuffer` → 640×360 RGB565 (460 KB) → 60 KB chunks over a remote → DataStore key `_TEST_Shots/<date>/<B#>` → `tools/fetch_shots.py` (Open Cloud DataStore) → PNG. Fallback: `PromptSaveCapturesToGallery`, and the owner drops files in `docs/art/shots/inbox/`.
- **R5, telemetry:** the `Perf` controller's frame times by device tier set LOD distances and the clone cap after launch (MASTERPLAN §8.6).

### 6.3 Automatic photo grading (Python, on every R2-R4 image)

| Gate | Pass |
|---|---|
| Crushed blacks | ≤ 15% of non-UI pixels under 5% luminance |
| Mid-tone | median luminance 18-40% |
| Character vs floor (B2) | ≥ 15% value difference in a sampled patch (MASTERPLAN greyscale test), contrast ratio ≥ 3 (*budgets.md*) |
| Glow share | 1-16% of pixels above 90% luminance |
| Hue | mean hue of mid-tones in the 230-280° band (indigo/plum night), saturation ≤ 0.45 outside signals |
| Void | outside the level's screen bounds, ≤ 30% of pixels under 5% luminance (the backdrop is doing its job) |
| Q1 vs PC | the same gates at Q1; ΔE of the median colour between Q1 and PC ≤ 12 |

### 6.4 Performance budgets per phone tier

Tiers map to the governor in `HeistClient.luau` (picked by measured frame time). Split at 60 fps: rendering 8-10 ms, simulation 2-3, scripts 2, headroom 2-3 (*roblox-performance-audit*).

| Budget (busiest view: Big Score, 4 players, 12 clones, 2 guards) | T3 low Android 2-3 GB (Q1-3, 30 fps) | T2 mid Android ~4 GB / iPhone XR-11 (Q4-6, 60 fps) | T1 high phone 6 GB+ / iPhone 13+ (Q7-10) | PC |
|---|---|---|---|---|
| Frame time p95 | ≤ 33 ms | ≤ 16.6 ms | ≤ 16.6 ms | ≤ 8.3 ms at 120 Hz optional |
| Draw calls | ≤ 250 | ≤ 350 | ≤ 450 | ≤ 600 |
| Triangles in view | ≤ 150k | ≤ 300k | ≤ 450k | ≤ 600k |
| Local lights affecting view / shadowed | 6 / 0 | 9 / 2 | 9 / 2 | 12 / 4 |
| Live particles | ≤ 150 | ≤ 360 | ≤ 360 | ≤ 900 |
| Highlights | 4 clone groups + 1 x-ray, others off | 4 + 1 + 5 | 4 + 1 + 5 | same |
| Clone look | B within 15 studs, mannequin C beyond | B within 25, C beyond | B within 40 | B everywhere |
| Clone lights / floor pools / trails | 0 / on / off | 0 / on / on | 4 / on / on | 4 / on / on |
| Backdrop | L0, L1, L2, sky (no L3/L4) | all | all | all |
| Bloom / ColorCorrection | off / on | on / on | on / on | on / on |
| Client memory | ≤ 60% of device (about 700 MB on 2 GB) | ≤ 60% | ≤ 60% | — |

Thermals appear after 5-10 minutes: every release gets a **15-minute soak** on the low Android with the numbers recorded (*vault: Mobile and Low-End Optimization* §7).

---

## 7. Ordered action list

1. Recipe A + `Sky` in `default.project.json`; STYLE_BIBLE §2-3 on-screen luminance rule; `place_check` and the R0 gate (0.5 day).
2. Lights and pools as kit attachments, `Config.Lighting`, `LightDirector`, greybox lamp grid (1 day).
3. Floor albedo lift and atlas cells for lit floor and contact shadow (0.5 day).
4. Backdrop: skyline rings, Heist City cubemap, client backdrop module (1.5 days).
5. Calibration board + PhotoBooth plugin; the owner installs it once (0.5 day + 10 min).
6. Animation spike (code clip → Animation asset), owner-pack mirroring, Gus FK walk (1 day).
7. UI pass: fonts, 9-slices, double strokes, motion tokens, icon sheets (1.5 days).
8. VFX pass per §5 (1 day). 9. Phone Photo mode R4 spike (0.5 day).

---

## Sources

**LihFolk vault** (`/home/user/lihfolk-cy/v2-vault/LihFolk Vault V2`, notes as of Oct-Nov 2026): *Stylized Lighting Recipes* (§3.4 Readable night, §3.5 Neon city, Common mistakes); *Lighting Technologies and Settings* (§2-3, §7); *Light Sources and Shadows* (§1-5, LightDirector code); *Atmosphere Sky Clouds and Post-Processing* (§1-4, grade stack); *Lighting Untextured Art in Roblox*; *Lighting Mood and Time of Day*; *Zone and Biome Art Direction* §4, §8; *Level Design Principles - Flow Sightlines and Landmarks* (angular size, fog); *Level of Detail and Model Streaming* (SLIM, streaming modes, nuances); *Water Sky and Atmosphere Art*; *What Craft Looks Like on Roblox - Lessons from Top Studios* §5; *Teardown - Pressure*; *Text Fonts and Rich Text* §1, §5; *Safe Areas and Insets* §1, §6, §9; *UI Asset Pipeline* Stage 6; *UI and GUI Animation* Pattern 1; *LihFolk UI Spec*; *Glossy Icon Style - Owner Reference*; *World-Space UI - BillboardGui and SurfaceGui*; *Publishing Animations* §6; *Lua Keyframe Player*; *CurveAnimation and Curve Channels*; *Replication and Ownership* (animation ids); *Animation Asset Permissions and Groups*; *Asset Upload Automation with Open Cloud*; *Procedural Gait and Footstep Planning*; *Idle Breathing and Secondary Motion*; *IKControl Reference*; *Look-At Aim and Head Tracking*; *Beams and Trails* §3, §5; *Particle Emitters In Depth*; *Collectible Pickup FX - Idle Glint, Magnet Pull and Collect Pop*; *VFX Readability and Value - Lessons from Blind Reviews*; *Mobile and Low-End Optimization* §1-2, §7; *Roblox Studio MCP Server* §3.5, §5.4; *Prompting and Verifying AI Output*; API snapshot `_tools/roblox_api.json` (dump 2026-10-27: `StudioCaptureService`, `StudioScreenshotCapture`, `CaptureService`, `UIShadow`, `UIGradient`, `Decal`, `Sky`, `Beam`, `ParticleEmitter`, `SurfaceAppearance`, `Lighting`, `Workspace` members, `Enum.Font`).

**LihFolk skills** (`/home/user/lihfolk-cy/v2-vault/skills`): `lihfolk-vfx` (rules, budgets, Beam laser, aura), `lihfolk-worldbuilding/references/budgets.md`, `roblox-ui-builder` (motion durations, safe areas), `roblox-performance-audit` (frame budget split).

**Web (DevForum and Creator Hub, via search; pages could not be opened from this session):**
- Emissive masks: [Studio beta](https://devforum.roblox.com/t/studio-beta-emissive-masks/4034414), [live](https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705); decal emissives: [request thread](https://devforum.roblox.com/t/decal-texture-emissive-maps/4743835)
- [Extended Light Ranges: 120](https://devforum.roblox.com/t/extended-light-ranges-doubling-the-limit-to-120/3954367); [Unified Lighting live](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512); [Future on Android](https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808); [mobile lighting mode thread](https://devforum.roblox.com/t/if-i-care-about-performance-on-mobile-which-lighting-mode-should-i-use/431662); [black fog on low graphics](https://devforum.roblox.com/t/black-fog-appears-on-low-graphics-and-shadow-rendering-issues/4141621); [haze dark by skybox](https://devforum.roblox.com/t/atmosphere-haze-color-is-dark-in-one-direction-severity-depending-on-skybox/621787); [fake night system](https://devforum.roblox.com/t/fake-night-system/3962991); [4K texture rendering](https://devforum.roblox.com/t/studio-beta-4k-texture-rendering/4144950)
- UI: [UIStroke improvements](https://devforum.roblox.com/t/studio-beta-uistroke-improvements-scaling-offsets-and-more/3958036); [Upgraded UI Gradients](https://devforum.roblox.com/t/studio-beta-upgraded-ui-gradients/4846594); [UIShadow reference](https://create.roblox.com/docs/reference/engine/classes/UIShadow); [UI Styling full release](https://devforum.roblox.com/t/full-release-ui-styling-is-officially-released/4275082); [StyleQuery](https://devforum.roblox.com/t/full-release-stylequery-more-styling-features/4566519); [Styling Transitions](https://devforum.roblox.com/t/full-release-styling-transitions/4646870); [Path2D clipping](https://devforum.roblox.com/t/opt-in-phase-introducing-clipping-support-for-rotated-elements-path2d/4737864); [CanvasGroup low quality](https://devforum.roblox.com/t/canvasgroup-makes-its-content-low-quality-at-certain-sizes-and-graphics-level-3-or-below/2946471); [CanvasGroup black fill](https://devforum.roblox.com/t/canvas-group-filled-with-black-for-mobile-devices/2208465); [Fonts in Creator Marketplace](https://devforum.roblox.com/t/fonts-in-creator-marketplace-81-new-fonts/2164977); [Font datatype](https://create.roblox.com/docs/reference/engine/datatypes/Font); [custom fonts](https://devforum.roblox.com/t/can-i-add-a-custom-font-to-my-roblox-game/2542482)
- Roadmap: [Creator Roadmap 2026 Spring](https://devforum.roblox.com/t/creator-roadmap-2026-spring-update/4625473); [RDC26](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880); [RDC 2026 newsroom](https://about.roblox.com/newsroom/2026/09/rdc-2026-the-world-needs-more-play)
- Animation and assets: [Open Cloud assets usage guide](https://create.roblox.com/docs/cloud/guides/usage-assets); [Open Cloud upload for more asset types](https://devforum.roblox.com/t/open-cloud-upload-support-for-more-asset-types/4022082); [HumanoidDescription animations](https://devforum.roblox.com/t/animations-applied-to-humanoiddescription-do-not-work/1560673); [custom flipbook layouts](https://devforum.roblox.com/t/client-beta-optimize-your-particle-animations-with-custom-flipbook-layouts/4005128)
- Capture: [Captures APIs thread](https://devforum.roblox.com/t/captures-apis-are-now-available/2838188/154); [TakeScreenshotCaptureAsync dispute](https://devforum.roblox.com/t/captureservicetakescreenshotcaptureasync-api-does-not-exist/4267335); [StudioCaptureService](https://create.roblox.com/docs/reference/engine/classes/StudioCaptureService.md); [plugin viewport capture request](https://devforum.roblox.com/t/plugin-access-to-screenshot-button-functionalityviewport-image-for-ai-integrationautomation/4223805)

**Repo:** `default.project.json` (Lighting node), `src/server/Heist/LevelBuilder.luau`, `src/client/Heist/WorldView.luau`, `src/client/Heist/HeistClient.luau` (tier governor), `src/client/Heist/Rigs.luau`, `src/server/Heist/Avatars.luau`, `src/client/Heist/Hud.luau`, `tools/kit_upload.py`, `tools/blender/kit_preview.py`, `docs/MASTERPLAN.md` §6, §6.8, §8.6, `docs/STYLE_BIBLE.md`, `docs/research/visuals.md`, `docs/research/tech.md`, `PROJECT_STATE.md`.
