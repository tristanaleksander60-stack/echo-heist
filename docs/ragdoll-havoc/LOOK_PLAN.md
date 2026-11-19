# RAGDOLL HAVOC: the "clean look" plan (2026-11-19)

The owner's verdict on the release build (phone/PC capture, 19 Nov): "it looks like AI slop, not a Steam game".

## Why it looks cheap (found in code)

| # | Cause | Where | Value now |
|---|---|---|---|
| 1 | A grey haze over everything | `Client/ZoneLighting.luau` (Atmosphere) | Density 0.24, **Haze 1.1** |
| 2 | Flat light with no shadow depth | ZoneLighting `Day` | OutdoorAmbient (128,134,150), ClockTime 14.6 (overhead sun), ShadowSoftness 0.25 |
| 3 | Glowing, blurred, washed out | ZoneLighting | Bloom 0.55; DepthOfField Far 0.12 |
| 4 | Cold blue-grey, desaturated | `Client/ChristmasFx.luau` | Tint (236,243,255), Saturation -0.06 on top of the day grade |
| 5 | Green "zombie" dummies | `Client/NpcGlow.luau` | Highlight fill (90,230,110), pulsing |
| 6 | Text in the world everywhere | `Playground.luau` BillboardGuis (LAVA!, SPIKES!, BULLSEYE, PUT RAGDOLL HERE…); `WorldDress` boards; neon leaderboards; OWNER tag; VIP | about 15 labels in one view |
| 7 | Mixed styles | realistic sky + concrete MaterialVariants next to cartoon fonts, neon frames, Santa hats, coloured suits (`DummyFactory.SUITS`) | — |
| 8 | HUD with about 20 elements | HudMenu column (6), sandbox column + event cards (7), bar (7), NEXT banner, people list, ammo "17 / 17" mid-screen | — |
| 9 | Floating black cubes | probably `WorldDress` (lamp heads or light towers) | must be checked in Studio |

## How the big ragdoll games do it

- **The image servers could not be reached from the cloud session** (thumbnails.roblox.com is blocked by the proxy), so no competitor screenshots were graded here.
- What is known comes from their store pages, research/COMPETITORS.md and public guides:
  - Hyper Realistic Ragdoll's "realistic" means the physics (limp, stumble, crawl), not textures. Players choose map, weather and time of day, and the look is plain and calm.
  - The leaders have one style each, either fully realistic or fully cartoon, never both.
  - They use very little text in the world and a small hotbar with icons. Menus stay hidden until opened.
- Common devforum practice for realistic lighting:
  - Future lighting;
  - Ambient near black and EnvironmentDiffuse/Specular 1;
  - hard shadows and a low sun;
  - a little Bloom and ColorCorrection;
  - little or no haze.
- To grade this properly, the owner should send 2-3 Studio or phone screenshots of Hyper Realistic Ragdoll and Ragdoll Research. Judge only real captures (MASTER_PLAN lesson 1).

## The pass (one session, every step behind `Config.LOOK_V3` so it can be switched back)

1. **Light** (ZoneLighting `Day` + atmosphere + ChristmasFx):

   | Group | Settings |
   |---|---|
   | Lighting | ClockTime 16.3, Brightness 3.5, Ambient (30,32,38), OutdoorAmbient (70,72,82), EnvDiffuse 1, EnvSpecular 1, ShadowSoftness 0.05 |
   | Atmosphere | Density 0.28, Offset 0.25, **Haze 0**, Glare 0.2, warm Color |
   | Bloom | Intensity 0.15, Threshold 1.6 |
   | ColorCorrection | Contrast 0.22, Saturation 0, a slight warm tint |
   | DepthOfField | off outside replays |

   Christmas keeps the snow only, with no blue tint.
2. **One style: a realistic test lab.**
   - Dummies get the grey mannequin skin only. No green glow: NpcGlow goes off, or becomes a thin white outline only while you aim.
   - No coloured suits or back numbers.
   - Santa hats only from 1 Dec.
   - Neon only on the 3 launch pads.
3. **World text down about 80 %.**
   - Station labels become flat floor decals (SurfaceGui on the pad, about 2 studs high, no glow), seen only within about 25 studs.
   - Remove LAVA!/SPIKES!/DANGER boards.
   - The two leaderboards become one small wall board without neon or crowns.
   - OWNER and VIP tags off by default.
4. **HUD of 5 things (PC):** the bar (6 small icon slots, number above), one MENU button, a small crosshair, ammo next to the bar, and the experiment line at the top.
   - The NEXT banner, the shop/rewards/places/settings column and the sandbox column move into MENU, with their keys kept.
   - The people list stays hidden (Tab).
   - Phones keep SHOOT, GRAB and RAGDOLL.
5. **Fix the floating cubes** (find them in Studio, then fix WorldDress).
6. **Proof:** before/after captures from Studio at the same 3 camera spots (spawn, cannon, crash wall) on PC and phone, plus LayoutCheck at 0 problems.
