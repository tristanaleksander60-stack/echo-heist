# Echo Heist: Visual direction and graphics tech (research report)

_Dimension: visual direction and graphics tech ("Steam-quality look"). Written 2026-11-12. Facts carry a citation (web URL or vault note). Lines starting with **Decision** or **Recommendation** are my calls, not facts. Unconfirmed claims are marked [UNVERIFIED]._

---

## Summary

**The look in one line: "Neon-Noir Diorama".** Chunky, bevelled low-poly sets built like a model kit, lit at night with deep indigo shadows (never black), warm pools of interior light, and one glowing colour family that **only the echoes are allowed to use**. Think Hitman GO's miniature-board feel, Monaco 2's clean, readable 3D, and Teardown's trick of simple geometry under rich lighting. The echoes are the brand. Every frame should answer "which ones are the past me?" in under half a second, at thumbnail size and with the sound off.

Main decisions:

1. **Art style:** flat-colour (SmoothPlastic plus a shared palette atlas) chunky low-poly with 1-segment bevels. No photoreal PBR and no texture-heavy surfaces. The look must survive on phones at graphics quality 1-3, where Roblox draws **no shadows at all** (vault: *Stylized Lighting Recipes*, citing Roblox docs). Colour and value carry the image. Shadows are a bonus on better devices.
2. **Lighting:** `LightingStyle = Realistic` with `PrioritizeLightingQuality = true`. The levels are small interiors, so we give up view distance before lighting quality ([Unified Lighting announcement](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512)). We start from a custom "Heist Night" recipe derived from the vault's *Readable night* and *Neon city* recipes, with at most 4 shadow-casting local lights per view.
3. **Echoes:** each echo is a stripped, single-material, tinted copy of your own avatar silhouette (identity is the joke). It gets an outline-weighted **Highlight per echo group, not per echo**, a short motion trail, a loop-number badge, and a spawn and vanish "time shimmer". It casts no shadows. Echoes move to **client-side replay** so they look smooth.
4. **Colour language (strict):** cyan to violet means *time and echoes*. Red means *danger* (lasers, alarms, seen). Gold means *loot*. Warm yellow means *guard light*. White chevrons mean *exit*. No environment asset may use the echo hues.
5. **Presentation:** a third-person gameplay camera. A 2.5-second **"Rewind"** between loops: the level visibly runs backwards at speed, with desaturation, an FOV punch and the loop counter. A top-down **"Blueprint" plan view** between loops shows every echo's route as glowing lines. At the end of each heist comes a 12-15 second **"Heist Reel"**: all echoes replayed together from 3 cinematic angles with one slow-motion beat, framed so it survives a 9:16 crop. This is the built-in TikTok and Roblox Moments clip.
6. **Budgets (phone, busiest view):** at most 350 draw calls target (Roblox's English docs give about 600 as the ceiling in cluttered views), at most 300k triangles target (600k ceiling), level at most 6k instances, at most 360 live particles on touch devices, textures at 512 or below except 1-2 shared 1024 sheets. Avatars, the 16 echoes included, are **the biggest budget risk**, not the environment.
7. **Pipeline:** every shipped mesh comes from our own Blender scripts through the `roblox-blender-modeling` gates (A1-A18, visual rubric of at least 14/18). No Toolbox. No text-to-3D meshes in shipped art (Cube is for blockout ideas only). Write a 6-page numeric style bible with 3-5 golden assets before mass production.

Because of the Christmas launch, **phases 0-3 must fit in about 4.5 weeks** (look-dev golden room, then echoes and rewind, then the bank kit, then the reel, thumbnails and the Christmas reskin).

---

## Findings (with citations)

### F1. Platform reality: most players are on phones, and phones lose shadows

- About 80% of Roblox DAU played on mobile in 2024, with PC around 17% and console around 3% (Roblox annual report via [PocketGamer.biz](https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue)). Newer splits from 2025-2026 conflict and are lower-confidence [UNVERIFIED] ([HostingAdvice](https://www.hostingadvice.com/studies/roblox-statistics/)).
- "Shadows turn off entirely below graphics quality level 4", and many phones run there. So a stylised recipe "must still read with no shadows at all" (vault: *Stylized Lighting Recipes* §1 and *Art Budgets* "Shadows and lights", both citing Roblox docs). I could not find this sentence on today's web docs pages; the vault records it as docs-sourced as of 2026-10-29.
- Future (now "Realistic") lighting on Android: Roblox staff called it "costly in performance… it remains an expensive technology". One developer reported a game "unplayable for mobile devices with under 2gb of RAM" with Future lighting. Devices without support fall back to ShadowMap-style shading ([DevForum: Future is Bright on Android fully rolled out](https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808), [Future vs Shadowmap performance](https://devforum.roblox.com/t/future-vs-shadowmap-performance/3246937)).
- In Automatic quality mode, Future lighting "will increase or reduce its influence on shading" to balance performance ([DevForum: Progressive rollout of Future on Android](https://devforum.roblox.com/t/progressive-rollout-of-future-lighting-on-android-devices-client-beta/3064250)).

### F2. Roblox rendering tech as of late 2026

- **Unified Lighting** (fully live July 2025) replaced `Lighting.Technology` with `LightingStyle` (Realistic or Soft) and `PrioritizeLightingQuality`. Future maps to Realistic plus Prioritize on, ShadowMap to Soft plus on, and Voxel to Soft plus off. Prioritize decides whether shadow and shader quality or view distance is reduced first ([DevForum announcement](https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512); vault: *Lighting Technologies and Settings*). `Technology` cannot be set from scripts.
- **Post-processing set:** `BloomEffect`, `BlurEffect`, `ColorCorrectionEffect`, `DepthOfFieldEffect`, `SunRaysEffect`, `ColorGradingEffect` (tonemapper preset; only one applies, and it must sit in Lighting). Effects in `Lighting` are seen by everyone; effects in `CurrentCamera` are per-player ([Roblox docs: post-processing](https://create.roblox.com/docs/en-us/environment/post-processing-effects); vault: *Atmosphere Sky Clouds and Post-Processing* §4). I found no new post-effect types in 2026 ([DevForum "More lighting effects" request](https://devforum.roblox.com/t/more-lighting-effects/4755018)).
- **Bloom rule of thumb:** a threshold near 0.9-1.0 makes Neon glow (keep white surfaces off-white). A threshold of 1.5-2 limits glow to over-bright VFX. Beams, trails and particles accept `Brightness` far above 1, so they can exceed the threshold (vault: *Atmosphere… Post-Processing*).
- **Emissive masks** on `SurfaceAppearance` (`EmissiveMaskContent`, `EmissiveStrength`, `EmissiveTint`) are live in published experiences on all clients. They work as a grayscale mask, not full RGB emissive, chosen "to ensure the best performance and memory usage across all devices". They can be changed from scripts at runtime ([DevForum: Emissive masks now live](https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705), [SurfaceAppearance reference](https://create.roblox.com/docs/en-us/reference/engine/classes/SurfaceAppearance.md)).
- **Highlights:** the limit rose from 31 to **255** in November 2025. Disabled Highlights still take a slot. "The first Highlight rendered… incurs most of the performance cost (up to 1 millisecond of GPU time on mobile)." On mobile, cost grows with screen coverage. Adding or removing a Highlight can trigger a geometry rebuild, so animate the properties of a persistent one instead ([Roblox docs: Highlighting](https://create.roblox.com/docs/en-us/effects/highlighting), [Weekly Recap Nov 10-14 2025](https://devforum.roblox.com/t/weekly-recap-november-10-14-2025/4071175), [Lights, Camera, More Highlights](https://devforum.roblox.com/t/lights-camera-more-highlights/4061534); vault: *Highlights and Selection Effects*). A Highlight parented to a Model applies to the whole model, and highlighted objects should not be nested inside each other (same vault note).
- **EditableImage / EditableMesh:** creation returns `nil` when "the device-specific editable memory budget is exhausted". The budget is not published, and the memory budget is strict on clients. EditableImage is limited to 1024x1024 maximum and one display update per frame, and both need the "Allow Mesh / Image APIs" toggle (vault: *EditableImage for Pixel Buffers and Procedural 2D*). Community reports describe hitting the budget after only "a handful" of meshes and occasional invisible EditableMeshes on mobile [UNVERIFIED] ([DevForum Mesh & Image APIs thread](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293)).
- **Mesh streaming / LOD:** when `Workspace.MeshStreamingAndImprovedLoDs` is Enabled, `RenderFidelity` is ignored and Roblox makes the LODs. Do not hand-author LODs (vault: *Rendering Performance*; `roblox-blender-modeling` skill "Known traps").
- **ForceField material** gives a cheap Fresnel "energy shell" look. Its look depends on transparency (0.5-0.8 reads ghostly), and it has known glitches where it overlaps other transparent parts ([DevForum: hologram](https://devforum.roblox.com/t/how-to-make-model-look-like-a-hologram/2006802), [ForceField transparency problem](https://devforum.roblox.com/t/a-problem-with-transparency-when-using-the-new-material-force-field/280011)).
- **Captures and Moments:** `CaptureService` documents `StartVideoCaptureAsync`, `StopVideoCapture` and `PromptSaveCapturesToGallery`, and captures can be shared with an invite link ([CaptureService reference](https://create.roblox.com/docs/reference/engine/classes/CaptureService.md)). Roblox Moments (September 2025, 13+) is a short-video feed where clips are trimmed to at most 30 s and viewers can join the experience straight from a clip. Roblox reported more than 240M video captures since July 2025 ([TechCrunch](https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more), [ContentGrip](https://www.contentgrip.com/roblox-launches-moments/), [DevForum Moments](https://devforum.roblox.com/t/roblox-moments-a-new-era-of-user-generated-discovery-for-experiences-and-gameplay-is-here/3919813)). Which platforms support video capture today is [UNVERIFIED].

### F3. Performance budgets (numbers)

| Budget | Value | Source |
|---|---|---|
| Draw calls, cluttered view where FPS drops | stay below about 600 (English docs); about 1,000 in the German translation | [Roblox docs: Design for performance](https://create.roblox.com/docs/performance-optimization/design) via search summary |
| Triangles, same view | below about 650k (English docs) | same |
| Visible scene triangles, phone (rule of thumb) | 300k-600k | vault: *Art Budgets* |
| Hard mesh limit | 20,000 triangles per mesh | vault: *Art Budgets* (modeling specs) |
| Per-asset budgets (target / ceiling) | tiny 150/300, small 600/1,500, medium 2k/4k, module 800/2k, building 6k/10k, creature 5k/10.7k, hero 10k/20k | `roblox-blender-modeling` skill |
| Instances | zone fully dressed 3k-10k; prop under 50 | vault: *Art Budgets* |
| Textures | memory scales with pixels (1024 = 4x 512); "limit images to 512"; most minor images under 256; a PBR set = 4 textures | vault: *Textures Decals and Texture Memory* (Roblox docs) |
| Shadow lights | "a handful" of shadow-casting local lights per view on phones | vault: *Art Budgets* |
| Particles | live cap 900 PC / 360 touch; emitter rate at most 100/s on mobile | `lihfolk-vfx` skill; GAME_BIBLE §perf (Docs) |
| Glow share | Neon at most about 1/6 of an object's pixels | vault: *Art Budgets*, *Stylized Lighting Recipes* |
| VFX/UI headroom | 20-30% of the frame budget | vault: *Art Budgets* nuance 5 |
| Avatars | "part of the budget"; layered clothing and accessories can cost more than the environment | vault: *Art Budgets* nuance 3 |

Instancing only works when meshes share the same MeshContent and identical SurfaceAppearance, texture or material. Decals and particles batch poorly. "Clone, do not re-import" (vault: *Art Budgets*, Roblox docs).

### F4. Steam reference games: what makes their look iconic

| Game | What the sources say | Lesson for us |
|---|---|---|
| Monaco / Monaco 2 | The overhead blueprint look's "intense style serves a practical purpose, to make the game readable". Unseen areas are darkened. Monaco 2 uses "clean and expressive 3D" with "more subtle shadowing". A critic said scenery can blur into "an indistinct blur" ([Game Informer](https://gameinformer.com/games/monaco/b/pc/archive/2013/04/24/embrace-the-heist-fantasy), [Aftermath](https://aftermath.site/monaco-2-demo-interview/), [Giant Bomb](https://giantbomb.com/reviews/monaco-what-s-yours-is-mine-review)) | Readability beats detail. The plan view is a proven heist fantasy |
| Hitman GO | Levels shown "like a board game with characters modelled as miniature figures", drawing on "architectural models, dioramas" ([Game Developer](https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense)) | A diorama look is cheap in geometry and premium in feel, and frames whole rooms for the reel |
| Teardown | "a coalition between the abstract voxel appearance and the very realistic lighting" ([Shacknews](https://shacknews.com/article/135274/tuxedo-labs-teardown-interview?amphtml=1)) | Simple shapes plus rich light read as premium. On phones we fake the light with colour |
| Sly Cooper | "toon-shading", "one step away from a flattened graphic style", a cartoon heist "in a dark filter" ([Wikipedia](https://en.wikipedia.com/wiki/Sly_Cooper_and_the_Thievius_Raccoonus), [TechRaptor](https://techraptor.net/gaming/review/rewind-review-sly-cooper-and-thievius-raccoonus)) | Playful heist plus night palette works. Outlines are expensive on Roblox (inverted hulls double triangles, vault *Art Budgets*), so outlines go on echoes only |
| Ruiner | A red-neon identity, but "the overwhelming presence of red starts to dominate" ([GameSpot](https://gamespot.com/reviews/ruiner-review/1900-6416768/)) | One signature hue is iconic only if it stays scarce: reserve cyan for echoes |
| The Sexy Brutale | A "cartoonish and stylish" time-loop mansion, though reliving the day can be "tedious" ([PC Gamer](https://www.pcgamer.com/the-sexy-brutale-review/), [Game Informer](https://gameinformer.com/games/the_sexy_brutale/b/pc/archive/2017/04/10/the-sexy-brutale-game-informer-review)) | Each loop needs visible novelty: make each new echo's arrival a moment |
| The Last Clockwinder / Super Time Force | Clones mirror "subtle movements", giving the tension of "mechanical perfection… and the human imperfection of the player". You play "alongside a ghost version" of yourself ([Meta blog](https://www.meta.com/blog/designing-last-clockwinder-best-of-quest-2022/), [Wikipedia](https://en.wikipedia.org/wiki/Super_Time_Force)) | The exact clumsy replay is the comedy, so smooth replay matters more than shaders |
| Rewind effects (indie Unity team, Braid, Prince of Persia) | "Having no visual effect at this point was a really bad idea". Grayscale with key colours kept. VHS dropped because it did not fit the style. Prince of Persia split its rewind into a "ghost" look plus reversed motion ([Game Developer](https://www.gamedeveloper.com/design/time-manipulation-in-unity-rewinding-time), [AWN](https://www.awn.com/print/vfxworld/prince-persia-rewind-dagger-time)) | The rewind needs a loud, colour-coded effect, and reversed motion is the strongest signal |

### F5. Roblox high-craft lessons and the live market

- Top studios: **"One owner of style"** (Dandy's World's designer-artist oversees all art), "light as wayfinding", "environment identity readable from one frame" (Pressure's "cold blue-green palette… The art direction is the brand") (vault: *What Craft Looks Like on Roblox*, *Teardown - Pressure*, *Teardown - Dandy's World*). Grace: "each threat has its own colour, shape and screen-edge cue", and colour-only warnings are a mistake (vault: *Teardown - Grace*).
- Best-looking lists for 2026 still favour realistic showcases (Beyond The Dark, Frontlines, Rolling Thunder, Livetopia, Deepwoken) and warn that the best-looking games "are also well-optimized" ([PocketGamer](https://www.pocketgamer.com/roblox/best-looking-games/), [GamerTweak](https://gamertweak.com/best-realistic-games-roblox/)). The Innovation Awards have no visuals category. Steal a Brainrot won "Best Creative Direction" ([Beebom](https://beebom.com/roblox-innovation-awards-2025-winners)). Takeaway: on Roblox, "premium" means *coherent and readable*, not photoreal.
- Live data (games API, 2026-11-12): heist competitors are *Notoriety: A PAYDAY Experience* (1,364 playing, 566M visits, a licensed Payday look), *ROB IT* (1,608 playing, 315M visits), *Heist Evolution* (2,145 playing, created 2026-05). The clone sandboxes are *Clone Engine* (1,714 playing, 417M visits) and *Clone Yourself* (572 playing, 240M visits). The visual benchmarks *Pressure* (about 1,004 playing) and *DOORS* (about 17,382 playing) show that stylised-dark, readable art scales. Notoriety owns the realistic "masked crew" look, **so we must not use clown or heist masks as our icon**.

### F6. Asset-pipeline facts

- The `roblox-blender-modeling` skill has headless gates A1-A18 (budgets, symmetry, seating, flipped faces) and a visual rubric V1-V9 (accept 14/18 or more, no zeros, with V1 "silhouette reads as solid black at 64 px"). Trap: more than 2 bevel segments on small props is a mistake ("1 seg = 3.7x tris, 2 = 9x on a box", measured). AI or scan meshes are "triangle soup" and are never shipped raw. Style options include "Palette atlas: one small palette PNG shared by the whole kit".
- The LihFolk Asset Pack is **not installed** in this environment (`LIHFOLK_ASSETS` unset, no `~/LihFolk-Assets`). Skills "fall back to making assets with the Blender pipeline" (`/home/user/lihfolk-cy/v2-vault/assets/README.md`).
- Style bibles fail when "rules are adjectives, not numbers". Fit the bible in 4-8 pages and pick 3-5 golden assets (vault: *Style Bibles for Consistent Models*). The project's GAME_BIBLE already rules: "No AI-generated meshes", a gradient palette atlas plus SmoothPlastic, "test at the lowest graphics quality".
- Roblox Cube (text-to-3D, March 2025) gained "4D" interactive generation in February 2026 ([Roblox newsroom](https://corp.roblox.com/newsroom/2025/03/introducing-roblox-cube), [Roblox newsroom 2026-02](https://about.roblox.com/es/newsroom/2026/02/accelerating-creation-powered-roblox-cube-foundation-model)). It is useful for ideas. Its output fails our "own style" and budget gates without retopology.
- Hand-painted textures get lit again by Roblox (there is no unlit shading). Painted AO is fine; painted directional light is fragile (vault: *Hand-Painted and Stylized Texturing* §2).
- Colour-blind audit: Oklab distance of at least 0.15 for small signals and at least 0.20 plus a non-colour channel for critical reads. A lightness difference of 0.15 or more survives even total colour blindness (vault: *Colour-Blind Safe Design* §3).
- VFX value rule: every frame has a dark ink layer, an element body, a thin white-hot core and at most one accent hue (vault: *VFX Readability and Value*).

### F7. Current prototype state (read from code)

`src/server/Echoes.luau` builds echoes server-side from `CreateHumanoidModelFromDescriptionAsync`. Parts are set to Transparency 0.3 or more and CastShadow false. A **Highlight per echo** (cyan fill 0.55, Occluded) is added, plus a name label, and the echoes are moved on the server every Heartbeat. PROJECT_STATE already lists choppy replication as a risk. `LevelBuilder.luau` uses SmoothPlastic, Neon lasers and a grey/beige palette (floor `58,62,74`, walls `196,186,168`). The plate colours (blue `60,140,255`) collide with the echo cyan, and the red plate is the same hue as the lasers.

---

## Recommendations / decisions

### D1. Art direction: three options scored, one chosen

| Option | Thumbnail read | Phone cost | Fits the echo mechanic | Production for Claude plus Blender | Score |
|---|---|---|---|---|---|
| A. Realistic PBR heist (Payday-like) | weak at 64 px, and Notoriety already owns it | high (4 maps per asset, shadows) | ghosts get lost in detail | slow, high slop risk | 4/10 |
| B. Full toon / cel with outlines (Sly-like) | strong | outlines double triangles; Highlights on everything cost GPU | outlines stop being special to echoes | medium | 6.5/10 |
| **C. Neon-Noir Diorama (chunky low-poly, flat palette, night light pools, glow reserved for echoes)** | **strong: dark-indigo set, warm pools, cyan copies pop** | **low: palette atlas instancing; survives no-shadow** | **perfect: only echoes glow cyan** | **fast: procedural kits** | **8.5/10** |

**Decision: Option C.** Its rules:

- **Shape:** chunky proportions. Props are scaled 1.5-2x real size and buildings about 1.2x (vault bible example). Bevels are 1 segment: 0.06-0.08 studs on small props, 0.12-0.2 on medium, 0.2-0.3 chamfer on building corners. Every prop has one focal feature at least 1.5x larger than any secondary.
- **Surface:** `SmoothPlastic` plus `MeshPart.Color` or **one 256x256 palette atlas per kit** with UVs snapped to cells. Hero-only exceptions (vault door, diamond, Christmas tree) may use one 1024 SurfaceAppearance with an emissive mask.
- **Diorama framing:** every level is a "cut-away model". Exterior walls on the camera side fade to 0.7 transparency or are culled when they block the player (cheap: a client raycast at 10 Hz). The street outside has fog and haze so the set feels like a lit model on a dark table.

### D2. The colour language (style bible core)

| Role | Name | Hex | Use and rule |
|---|---|---|---|
| Base shadow | Ink Indigo | `#1C1F3B` | unlit walls and floors far from lights; never darker (night is hue, not black) |
| Base mid | Plum Slate | `#3A3560` | most walls; large surfaces at 30-55% value |
| Lit interior | Warm Marble | `#D8C8A8` | surfaces inside light pools |
| Metal | Vault Steel | `#7C86A6` | doors, safes, rails |
| **Danger** | Alarm Red | `#FF3348` | lasers, alarms, "seen!" only |
| Guard light | Torch Amber | `#FFD27A` | flashlight cones, guard lamps |
| **Loot** | Heist Gold | `#FFC21F` | gold, cash, loot sparkle; nothing else gold |
| Exit | Getaway White | `#F4F7FF` | van, chevrons, exit arrows (with icon) |
| **Echo P1 / solo** | Echo Cyan | `#3DE8FF` | reserved for time and echoes |
| Echo P2 | Echo Magenta | `#FF4FD8` | reserved |
| Echo P3 | Echo Violet | `#9B7BFF` | reserved |
| Echo P4 | Echo Lime | `#B8FF4A` | reserved (exit is white, not green, to free this hue) |

Rules:

- No environment asset may use a hue within ±20° of an echo hue at saturation above 40%. That means the current blue plate becomes a **steel plate with a white icon**, and plates show *who is standing on them* by taking on that echo's colour.
- Run the vault's Oklab audit in CI (Lune). Every echo hue against the base colours needs distance of at least 0.15. Alarm Red against every echo hue needs at least 0.20, plus a shape channel (lasers are thin beams; echoes are humanoid).
- **Greyscale test:** characters, loot and danger must differ from the ground by 15% value or more (vault: *Readable night*).

### D3. Lighting recipe "Heist Night" v1 (starting numbers)

These are adapted from the vault's *Readable night* and *Neon city* recipes, so tune them on a phone.

- `Lighting`: LightingStyle Realistic, PrioritizeLightingQuality true, GlobalShadows true, ClockTime 0, Brightness 0.5, Ambient (55, 55, 95), OutdoorAmbient (75, 80, 130), ColorShift_Top (255, 210, 160) (warm lit side), EnvironmentDiffuseScale 0.25, EnvironmentSpecularScale 0.35 (a hint of shine on the vault floor), ExposureCompensation 0.2.
- `Atmosphere` (exterior streets only, swapped on entering a building): Density 0.3, Color (70, 60, 120), Decay (35, 30, 75), Haze 0.8.
- `BloomEffect`: Intensity 0.8, Size 28, Threshold 1.0. Neon and echo outlines glow; Warm Marble stays below the threshold.
- `ColorCorrectionEffect` (Lighting): Contrast 0.12, Saturation 0.1, TintColor (235, 230, 255).
- `ColorGradingEffect`: Default tonemapper.
- No SunRays (night interiors). `DepthOfFieldEffect` **only** in the Plan view, the Heist Reel and menus, never during play.
- **Local lights:** at most 4 shadow-casting lights per view on desktop, and 0 shadows on lights by default (`Light.Shadows = false`) unless it is a hero light such as the vault spotlight. Fake every other "light pool" with a floor decal or a transparent Warm-Marble disc plus Neon fixtures. Sleep lights beyond 120 studs.
- **Store the recipe as data** (one module, `LightingController` is its only owner). Christmas, museum, casino and moon each get their own named recipe.

### D4. How the echoes look (the hero visual)

Goal: "that's me, but a ghost from 20 seconds ago", readable at 64 px and in a 15 s silent clip.

**Echo build (client-side):**

1. **Client-side replay (prerequisite).** The server keeps recording at 15 Hz and stays authoritative for the gameplay actors (plates, guards). Each client renders the visual echoes by interpolating frames (Catmull-Rom on position, slerp on yaw) at render rate, giving smooth 60 fps motion. Owners: the networking or architecture dimension. Visuals depend on it.
2. **Silhouette:** clone the player's avatar, then **strip** it. Remove all `SurfaceAppearance`, `TextureID`, decals, face and layered clothing (WrapLayer), and keep at most 2 accessories (hat or hair) for identity. Set every part to SmoothPlastic, tinted with the echo hue at 35% value and Transparency 0.45. Same-player echoes then share meshes and material, so they can instance (F3), and the triangle and draw-call cost per echo drops sharply. Run a Studio measurement before and after; the per-avatar cost is [UNVERIFIED].
3. **Rim, not fill:** **one Highlight per echo group** (one Model folder per player, so at most 4 Highlights for 16 echoes). Settings: OutlineColor = echo hue, OutlineTransparency 0, FillColor = echo hue, FillTransparency 0.85, DepthMode Occluded. Persistent: never create or destroy them per loop, only animate them. A **separate "x-ray" Highlight group** set to AlwaysOnTop at OutlineTransparency 0.6 is used only for *your* echoes standing on a plate behind a wall, so you always know your crew is holding the door.
4. **Age ramp:** the newest echo has 100% outline brightness. Each older loop loses 12% and shifts hue up to 25° toward violet, so the cyan-to-violet gradient in "8 copies" shots looks gorgeous. Older echoes also get +0.1 transparency.
5. **Loop badge:** a small BillboardGui above the head reading "#3" in the echo colour (it becomes a non-colour channel for colour-blind players). It hides beyond 60 studs and in the Heist Reel's close-ups.
6. **Motion trail:** a `Trail` between two attachments (shoulder to hip), Lifetime 0.25 s, WidthScale 1 to 0, Transparency 0.4 to 1, LightEmission 1, Brightness 2. It is enabled only when speed is above 6 studs/s, so standing echoes stay clean.
7. **Spawn and vanish ("time shimmer"):** on loop start, each echo forms over 0.35 s. Transparency goes 1 to 0.45, with a vertical scan of 12 particles from a foot ring (Neon disc, scale 0 to 1.2 to 1) and a soft "chime". On busted or vanished, the echo breaks into 20 cyan shards with a short reverse "zip" sound. Budget per event: at most 30 particles, inside the 360 touch cap.
8. **Afterimages, sparingly:** on a jump or grab only, drop 2 frozen ghost copies (outline only) that fade over 0.3 s, reusing the `lihfolk-vfx` DashTrail "ghosts" idea. Never continuous.
9. **Stack rule (overdraw guard):** when 3 or more echoes overlap within 2 studs (a common case: everyone stands on one plate), render the newest one fully, fade the others to outline only, and show a "x3" badge. This stops 8 stacked translucent avatars from multiplying overdraw on phones and reads better too.
10. **Real players vs echoes:** real players are fully opaque, lit, cast shadows and get a thin white rim Highlight in co-op (one group Highlight). Echoes are translucent, shadowless and coloured. The difference survives the greyscale test.
11. **Multiplayer perspective:** on each client, *your* echoes get full brightness. Other players' echoes keep their own hue at 70% brightness with their name on the badge. That is client-side rendering, so it costs nothing on the server.
12. **ForceField material: test, don't commit.** A ForceField shell gives a free animated Fresnel shimmer, but it has known overlap glitches and adds transparent layers. Run an A/B test in look-dev (`Tint` SmoothPlastic vs ForceField) on a phone, and pick by clip read plus frame time.

**Guard and threat readability:** the guard's vision is a **flat cone mesh** on the floor (Torch Amber, Transparency 0.75, a Neon edge line, raycast-clipped against walls like Monaco's cones, using a fan of 12 rays at 10 Hz on the client). It has a SpotLight with shadows off. When the guard sees an echo, the cone flashes **red** and a "?" pops above the guard (the "confused guard" clip). Lasers are a dark-ink beam core plus a red body plus a thin white-hot core (vault VFX value rule), with a red floor dot.

### D5. Camera and presentation

- **Gameplay camera:** Roblox third-person, so it works with the default mobile controls and keeps your avatar visible, which is what makes the echoes funny. Default zoom 16 studs, min 8, max 28, FOV 70. A slight downward bias in the diorama rooms. Walls toward the camera fade (D1).
- **Rewind (between loops, about 2.5 s total, client-side):**
  1. 0-0.15 s: "◀◀" hit. FOV 70 to 82, ColorCorrection Saturation 0 to -0.85 (echo outlines keep glowing through bloom), plus a cyan tint.
  2. 0.15-1.6 s: the **world runs backwards**. Every actor's recording plays in reverse at an eased 25-45x, with trails on, so the whole heist "un-happens". This is a signature clip and cheap, because the recordings already exist.
  3. 1.6-2.5 s: snap to loop start. A big "LOOP 3" card, a new-echo shimmer, saturation back to 0 and FOV back to 70.
  - It respects a **Reduced motion** setting (no FOV punch, shorter, plain fade). One `ScreenFX` owner holds the grade stack (vault grade-stack pattern).
- **Blueprint plan view** (optional during the rewind pause, or by holding the map button): the camera goes top-down with FOV 30 at about 120 studs height. Ambient goes deep blue, and a world-space grid (one tiling Texture on a floor plane) appears. Every echo's route is drawn as **Beams** between path points sampled every 0.5 s, in the echo's hue, with plates and guard routes as icons. This is the "planning a heist" fantasy Monaco and Hitman GO sell, and it makes a second clip format ("watch the plan, then the execution"). Use Beams, not EditableImage (F2 budget risk).
- **Heist Reel (end of each heist, 12-15 s, skippable after 2 s):**
  - It replays the final loop with **all echoes plus players together**, client-side from the recordings.
  - Three auto-picked shots: (1) a wide diorama establishing shot, (2) a tracking shot on the loot carrier, (3) a "hero moment" (the door opening while the echoes hold the plates) at **0.35x slow motion** for 1.5 s, then a snap back to 1x.
  - It ends on a title card: "**8 OF ME. 1 VAULT.**", or "Your past self got caught 3 times", from stats.
  - **Crop-safe framing:** keep the subject in the **central 32% of the frame width** (a 9:16 crop of a 16:9 frame keeps 9/16 ÷ 16/9 ≈ 31.6% of the width). Big text goes in the centre third.
  - The "SAVE CLIP" button calls `CaptureService:StartVideoCaptureAsync` if available on the device and falls back to "Screenshot" ([CaptureService](https://create.roblox.com/docs/reference/engine/classes/CaptureService.md)). Captures carry an invite link, and clips feed Roblox Moments (at most 30 s).
- **Slow motion in live play:** cosmetic only (the server time doesn't dilate). When the last loot reaches the van with less than 3 s on the clock, slow the local animations to 0.5x for 0.6 s with a whoosh, while the server logic continues.

### D6. Rendering tech choices (with numbers)

| Topic | Decision |
|---|---|
| Lighting style | Realistic + PrioritizeLightingQuality on (small levels). **Kill switch:** if the look-dev test on a low Android (2-3 GB RAM) runs under 30 fps at Automatic quality, switch to Soft and keep the colour recipe. The look is built to survive both. |
| Shadows | Sun or moon only plus at most 4 hero local lights. Small parts, Neon, echoes and moving objects get `CastShadow = false`. |
| PBR | Not the default. At most 3 hero SurfaceAppearances per level (vault door, diamond, event centrepiece). Only Color plus Roughness at 1024, plus an emissive mask. No metalness map. |
| Emissive masks | Used for signage, vault dials and the Christmas lights instead of extra Neon parts. Tint driven at runtime for alarms. |
| Post | As in D3. DoF and Blur only in menus, the plan view and the reel. A per-tier toggle for Bloom intensity (Performance tier: Bloom 0.5). |
| EditableMesh/Image | **Not used** in the shipped core. One optional experiment: a plan-view minimap, behind a `pcall` with a Frame fallback. |
| Streaming | StreamingEnabled. Each level Model is `Atomic`. MeshStreamingAndImprovedLoDs on. No RenderFidelity logic. |
| Graphics presets | Auto / Performance / Balanced / Quality (vault *Mobile and Low-End Optimization* recommend() heuristic). **Echo visuals, guard cones and lasers are gameplay and exempt from culling.** Decoration (dust, sparkle, trails) scales 0.6x on touch. |
| Per-view budget (phone) | at most 350 draw calls target and 600 ceiling. At most 300k triangles target and 600k ceiling. At most 6k instances per level. At most 360 live particles. At most 4 Highlights for echoes plus at most 6 others. |
| Textures per level | 1 kit palette atlas (256), 1 shared 1024 trim sheet, at most 3 hero 1024 sets (2 maps each), UI icons at most 256. That is about 10 "1024-equivalents" in total. |
| Avatars | Budget 16 echoes plus 4 players. Stripped echoes (D4.2). If the measured cost of one echo is above 25 draw calls, add an "echo LOD": beyond 50 studs, swap to a shared mannequin mesh in the echo colour. |

### D7. Asset pipeline: model vs buy vs generate

- **Model (Claude, Blender scripts plus gates):** everything shipped. That covers the bank kit (about 35 modules: walls 4x8, 8x8, corners, door frames, counters, safes, vault ring, pillars, lamps, desks, laser emitters, plates, van), the corner-shop kit (reuses about 50% of the bank modules with a new atlas), the guard character (a "creature" class, 5k tris, or an R15 rig with our own mesh parts), and loot props (small class at most 1,500 tris).
- **Buy:** nothing from the Toolbox (IP and slop risk). Licensed SFX (lihfolk-sfx). Optional: a commercial font licensed for games.
- **Generate:** AI images only for **moodboards and concept exploration**, never as shipped textures or thumbnail claims. Cube or text-to-3D only for blockout silhouette ideas, never shipped. This matches the bible's "No AI-generated meshes" rule.
- **Gates:** every asset passes A1-A18 and V1-V9 at 14/18 or more (`roblox-blender-modeling`). Hero assets also get a quick Art Director council review. Then a **Studio-side audit**: run `budgetReport(root, "mobile")` from `LihFolkWorld.luau`, through Open Cloud Luau Execution against the real place, and diff it against the last pass.
- **How we avoid "AI slop":** (1) one owner of style (the owner signs off the golden assets); (2) numeric rules only; (3) 3-5 golden assets beside every new asset in review renders; (4) shape grammar with "do and don't" pairs; (5) no generic sci-fi glow everywhere, because glow is reserved; (6) a purposeful detail: every room has one "storytelling prop" (the toy tycoon's portrait, the night guard's donut box).

**Golden assets (build first):** (1) the **vault door** (hero, 8-10k tris, emissive dial), (2) a **bank wall module plus counter** (module class), (3) the **gold bar stack plus diamond** (small class, gold and sparkle VFX), (4) the **guard** (stylised, big flashlight, readable silhouette), (5) the **echo look** itself (the D4 recipe, captured as a reference clip).

### D8. Thumbnail and icon

- **Icon:** one subject. Your avatar-style silhouette in front, with 4 echo copies fanned behind it, fading cyan to violet, against a glowing vault-door circle on Ink Indigo. It must pass the greyscale test and read at 64 px (vault: *Game Icon Design - Readable at Small Sizes*). **No masks** (Payday/Notoriety association).
- **Thumbnails:** real in-game captures from a capture place with the same lighting (GAME_BIBLE rule). Three variants for A/B testing: "8 copies", "my past self betrayed me" (the echo walks into the laser), and the "confused guard".

---

## Phased plan for this dimension

The Christmas launch event is the deadline driver: about 6 weeks from 2026-11-12. Phases 0-3 are needed for launch; phase 4 comes after.

**Phase 0: Look-dev golden room (week 1, about 5 days)**

- Build a 24x24-stud "vault antechamber" slice with golden assets 1-3. Apply the "Heist Night" recipe as data and Echo look v1 (D4 items 2-6). Build the guard cone and laser.
- Owner-run test protocol (there is no Studio in the cloud): screenshots and 20 s clips on (a) PC Quality 10, (b) the owner's phone at Automatic, (c) a phone forced to quality 1-3 (no shadows). Plus a MicroProfiler or Shift+F2 readout of draw calls and triangles in the busiest view.
- Gates: greyscale test pass. Echo vs player read under 0.5 s (blind 3-person check). At least 30 fps on a low phone. At most 350 draw calls with 8 echoes visible. Decide Realistic vs Soft, and Tint vs ForceField echoes.

**Phase 1: Echoes, rewind and threats (weeks 2-3)**

- Client-side echo replay (with architecture). The full D4 recipe: group Highlights, age ramp, badges, trails, shimmer, stack rule. The Rewind effect with reverse playback. Guard confused or seen states. Laser VFX. Plate colours that take on the echo colour.
- Gates: 16 echoes at 30 fps or more on a low phone. Highlights 10 or fewer. Particles under 360. Colour-blind audit pass. Reduced-motion setting works.

**Phase 2: Bank kit and style bible (weeks 2-4, in parallel)**

- Write `docs/STYLE_BIBLE.md`: 6 pages with the palette table, value bands, bevel and segment tables, triangle budgets, materials, shape grammar and golden-asset renders.
- Produce the ~35-module bank kit plus the corner-shop atlas swap through the Blender pipeline. Rebuild `LevelBuilder` to place kit meshes (clone, never re-import).
- Gates: every asset 14/18 or more. Level at most 6k instances. Audit diff checked.

**Phase 3: Presentation and launch art (weeks 4-5)**

- Blueprint plan view (Beams). Heist Reel (3 shots, slow-mo beat, title card, crop-safe framing, Save Clip). Graphics presets. Capture place. Icon plus 3 thumbnails.
- **"Steal Back Christmas" reskin:** a snowy street (white terrain plus warm window pools), a "Toy Tycoon" vault with candy-cane lasers (still Alarm Red), and a gift loot model. Lighting recipe "Christmas Eve": a warmer ColorShift_Top and Ambient +10%.
- Gates: the reel exported as a 9:16 crop looks good with the sound off. The icon reads at 64 px. Thumbnails A/B ready.

**Phase 4: Post-launch targets (each about 1-1.5 weeks of art)**

- Each target gets one **signature light and hue** that never touches the echo hues: museum (cold moonlight skylight, Marble), casino (red and gold, so lasers turn white-hot and need care), moon base (low-saturation white and grey with black sky; echo cyan reads strongest here).
- Each reuses 40-60% of the kit through atlas swaps.

---

## Risks

1. **Avatar cost is the real budget killer.** Twenty avatars (16 echoes plus 4 players) with accessories and layered clothing could exceed the whole environment's draw calls (vault *Art Budgets* nuance 3; per-avatar numbers [UNVERIFIED]). *Mitigation:* stripped echoes (D4.2), group Highlights, an echo LOD mannequin and the stack rule. Measure in phase 0.
2. **Realistic (Future) lighting on low Android.** It is documented as "expensive", with a report of being unplayable under 2 GB RAM. *Mitigation:* the recipe is colour-first, there is a Soft kill switch, and shadow lights are kept to 4 or fewer.
3. **No shadows below quality 4.** If the look relies on shadows, phones see flat mush. *Mitigation:* the colour recipe, light-pool decals and a test at quality 1-3 every phase.
4. **Translucent overdraw** from stacked echoes and ForceField. *Mitigation:* the stack rule, Transparency 0.45 (not many layers) and no fill-heavy Highlights. Highlight cost on mobile grows with screen coverage.
5. **Server-side echo movement looks choppy** and ruins the "perfect sync" clip. *Mitigation:* client-side replay in phase 1 (a hard dependency).
6. **No direct Studio access.** Claude cannot see renders in Roblox. *Mitigation:* Blender review renders for every asset, an owner screenshot and clip protocol (phase 0), budget audits via Open Cloud Luau Execution, and a blind 3-reviewer panel for the final call.
7. **AI-slop or asset-flip look.** *Mitigation:* golden assets, numeric bible, one style owner, no text-to-3D and no Toolbox.
8. **IP adjacency.** Notoriety (licensed PAYDAY) owns the masked-crew look. Monaco owns the 2D blueprint art. *Mitigation:* no masks, our own blueprint grid style (3D diorama), our own names and palette.
9. **Colour collisions** (the current blue plate vs echo cyan, red plate vs lasers). *Mitigation:* the D2 reserved-hue rule plus the Oklab audit in CI.
10. **Capture API availability** on each platform is unclear [UNVERIFIED]. *Mitigation:* the reel is designed to be screen-recorded by players anyway (crop-safe), with Save Clip as a bonus.
11. **Timeline:** 4.5 weeks of art before the Christmas event is tight for a solo team. *Mitigation:* the Christmas reskin reuses the bank kit, and museum, casino and moon move to after launch.

---

## Sources

**Web**

1. Roblox Unified Lighting announcement: https://devforum.roblox.com/t/let-there-be-unified-light-unified-lighting-is-fully-live/3401512
2. Future is Bright on Android (fully rolled out): https://devforum.roblox.com/t/future-is-bright-on-android-is-fully-rolled-out-client-beta/3235808
3. Progressive rollout of Future on Android: https://devforum.roblox.com/t/progressive-rollout-of-future-lighting-on-android-devices-client-beta/3064250
4. Future vs Shadowmap performance: https://devforum.roblox.com/t/future-vs-shadowmap-performance/3246937
5. Roblox docs, Highlighting objects: https://create.roblox.com/docs/en-us/effects/highlighting
6. Lights, Camera, More Highlights: https://devforum.roblox.com/t/lights-camera-more-highlights/4061534 and Weekly Recap Nov 10-14 2025: https://devforum.roblox.com/t/weekly-recap-november-10-14-2025/4071175
7. Roblox docs, post-processing effects: https://create.roblox.com/docs/en-us/environment/post-processing-effects
8. DevForum, More lighting effects (request): https://devforum.roblox.com/t/more-lighting-effects/4755018
9. Emissive masks live: https://devforum.roblox.com/t/emissive-masks-are-now-live-for-published-experiences/4357705 and the SurfaceAppearance reference: https://create.roblox.com/docs/en-us/reference/engine/classes/SurfaceAppearance.md
10. Mesh & Image APIs thread: https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293
11. Roblox docs, Design for performance: https://create.roblox.com/docs/performance-optimization/design
12. CaptureService reference: https://create.roblox.com/docs/reference/engine/classes/CaptureService.md
13. Roblox Moments: https://techcrunch.com/2025/09/05/roblox-announces-short-form-video-feed-for-gameplay-clips-new-ai-tools-for-creators-and-more ; https://www.contentgrip.com/roblox-launches-moments/ ; https://devforum.roblox.com/t/roblox-moments-a-new-era-of-user-generated-discovery-for-experiences-and-gameplay-is-here/3919813
14. Mobile share 80%: https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue ; https://www.hostingadvice.com/studies/roblox-statistics/
15. ForceField hologram threads: https://devforum.roblox.com/t/how-to-make-model-look-like-a-hologram/2006802 ; https://devforum.roblox.com/t/a-problem-with-transparency-when-using-the-new-material-force-field/280011
16. Monaco: https://gameinformer.com/games/monaco/b/pc/archive/2013/04/24/embrace-the-heist-fantasy ; https://giantbomb.com/reviews/monaco-what-s-yours-is-mine-review ; https://aftermath.site/monaco-2-demo-interview/ ; https://www.pcgamer.com/indie-heist-sim-monaco-is-getting-a-3d-sequel
17. Hitman GO: https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense ; https://Www.Wikipedia.org/wiki/Hitman_Go
18. Teardown: https://shacknews.com/article/135274/tuxedo-labs-teardown-interview?amphtml=1 ; https://techradar.com/gaming/consoles-pc/ray-tracing-is-so-crucial-to-teardown-that-the-world-goes-black-if-you-turn-it-off
19. Sly Cooper: https://en.wikipedia.com/wiki/Sly_Cooper_and_the_Thievius_Raccoonus ; https://techraptor.net/gaming/review/rewind-review-sly-cooper-and-thievius-raccoonus
20. Ruiner: https://pcgamer.com/the-cyberpunk-art-of-benedykt-szneider-gave-ruiner-a-brutal-beauty ; https://gamespot.com/reviews/ruiner-review/1900-6416768/
21. The Sexy Brutale: https://www.pcgamer.com/the-sexy-brutale-review/ ; https://gameinformer.com/games/the_sexy_brutale/b/pc/archive/2017/04/10/the-sexy-brutale-game-informer-review
22. The Last Clockwinder: https://www.meta.com/blog/designing-last-clockwinder-best-of-quest-2022/ ; Super Time Force: https://en.wikipedia.org/wiki/Super_Time_Force
23. Rewind effects: https://www.gamedeveloper.com/design/time-manipulation-in-unity-rewinding-time ; https://www.awn.com/print/vfxworld/prince-persia-rewind-dagger-time
24. Best-looking Roblox games: https://www.pocketgamer.com/roblox/best-looking-games/ ; https://gamertweak.com/best-realistic-games-roblox/
25. Innovation Awards 2025: https://beebom.com/roblox-innovation-awards-2025-winners
26. Roblox Cube: https://corp.roblox.com/newsroom/2025/03/introducing-roblox-cube ; https://about.roblox.com/es/newsroom/2026/02/accelerating-creation-powered-roblox-cube-foundation-model
27. TikTok clip practice (vendor blogs, low confidence): https://www.opus.pro/blog/tiktok-hook-formulas ; https://autoclip.dev/blog/why-3-second-hooks-are-overrated

**LihFolk Vault V2 notes (verified 2026-10-29)**

*Art Budgets - Triangles Draw Calls Memory*; *Highlights and Selection Effects*; *Stylized Lighting Recipes*; *Lighting Technologies and Settings*; *Atmosphere Sky Clouds and Post-Processing*; *Textures Decals and Texture Memory*; *EditableImage for Pixel Buffers and Procedural 2D*; *Mobile and Low-End Optimization*; *Rendering Performance*; *Hand-Painted and Stylized Texturing*; *Style Bibles for Consistent Models*; *Colour-Blind Safe Design*; *VFX Readability and Value - Lessons from Blind Reviews*; *Game Icon Design - Readable at Small Sizes*; *Photo Mode and In-Game Screenshots with CaptureService*; *What Craft Looks Like on Roblox*; *Teardown - Pressure*; *Teardown - Grace*; *Teardown - Dandy's World*. Skills: `roblox-blender-modeling`, `lihfolk-vfx`, `lihfolk-worldbuilding`; assets README.

**Live Roblox data (2026-11-12)**

`tools/rbx_search.py` ("heist", "bank heist", "time loop", "clone", "echo", "pressure", "doors") and `games.roblox.com/v1/games` for universes 16680835 (Notoriety), 9472441390 (ROB IT), 10107832573 (Heist Evolution), 6128091457 (Clone Engine) and 1761773144 (Clone Yourself).

**Project files**

`README.md`, `PROJECT_STATE.md`, `src/server/Echoes.luau`, `src/server/LevelBuilder.luau`, `src/client/init.client.luau`, `src/shared/Config.luau`, `docs/IDEA_ECHO_HEIST.md`, `docs/VIRAL_PLAYBOOK.md`, `docs/GAME_BIBLE.md` (grep only).
