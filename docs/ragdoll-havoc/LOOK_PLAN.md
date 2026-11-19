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

## Update: Hyper Realistic Ragdoll's store page, seen (19 Nov)

The 9 store images were downloaded via thumbnails.roblox.com (the video could not be fetched: asset delivery is blocked and the poster is a placeholder).

- **All 9 are polished 3D renders made for marketing, not gameplay captures.** They look like AI or 3D-artist renders.
- **The look is extremely simple:**
  - the classic bright green grid baseplate;
  - a blue sky with white clouds;
  - a few blocky trees and grey blocks far away;
  - smooth **white** mannequins with the classic Roblox face.
- **Each image shows ONE action:** bat to the head (with an X-ray skull), punched into a wall, a hammer into the ground, a snake, a T-rex, arrows and knives, a boulder.
- **No text, no UI, no logos and no signs** in any image.
- **The lesson:** the leader at 43k CCU is not "Steam realistic". It wins on **clarity**: one clean floor, one sky, white dummies, and big readable physics moments. "Hyper realistic" means the physics.

**Changed direction for the pass:** not a dark realistic lab but a **clean, bright crash-test lab**.
- A clear blue sky with no haze, and soft but visible shadows.
- A clean light floor; the props get one or two colours each.
- **White** smooth dummies (lighten DummySkin) with a simple face.
- Close to zero text in the world, a minimal HUD, and big hit moments (X-ray, dust, cracks in the floor).
- Store images in the same style: one action each, no text. The thumbnails made on 19 Nov carry text, so make a new set without it.

## Teardown from real gameplay captures (owner, 19 Nov, Hyper Realistic Ragdoll at about 80k CCU)

### World ("Test Ground")
- **Calm, natural daylight.** Light overcast, with soft shadows under the player. Distance fog only on the far hills, and no grey wash on the play area.
- **Muted, real-world colours:** concrete tiles, grass, army-green machines, brick, wood. No neon anywhere.
- **Props are things a kid recognises:** a giant fan, a tower with a slide, a rocket, a monster truck, a car, benches, trees, a castle tower and a pool. Each has 1-2 colours and is not glowing.
- **Text in the world:** one small "DANGER" sign and a speech bubble from a dummy ("Don't shoot!", the Talk tool). That is all.
- **Dummies** are plain white mannequins that react and talk.
- **The world sits in a landscape** of green hills and pine trees. It is not floating on a void or a rooftop.

### HUD (PC), one style for everything
- **Left:** 3 big square buttons with an icon and a word: Shop, Tools, Lab.
- **Right:** 2 more, Maps and Events. All are the same size and the same dark glass.
- **Bottom centre:** 5 **icon-only** slots with a small number and no names: hand, gun, fist, talk, kick.
- **Bottom left:** key hints as plain chips: "R Revive · G Spawn · V Scan".
- **Top right:** a gift icon, a "Next: Kick 0/2" pill with a thin bar, and a small Here/Friends/Global list (KOs, Revives).
- **Style:** one font (bold sans, white), white flat icons, dark translucent panels. No gradients, outlines, glow or colour per button.

### Windows
- A black body with a coloured header bar per window: Tools red, Lab teal, Maps olive, Events magenta. Icon and title sit left, a big X right.
- **Tools:** tabs on the left (Melee, Guns, Throw, Power, Medic, Robux) and "UNLOCKED 4/72".
  - Cards show a big white icon, a one-line description, POWER/RATE/REACH bars, and EQUIP/UNEQUIP.
  - Locked cards show "0 / 2 KOs" plus a purple **SKIP R$9**.
  - **The first unlocks need only 2, 3 and 4 KOs.**
- **Lab:**
  - free: Slow time on/off with a speed slider, Free cam (L);
  - locked "Comes with Lab Controls" (a pass): Stop time, Fly, Spawn dummies, Launch, Explode.
- **Maps:** 4 maps (Test Ground, Island, Building Site, Clean Room). Each has a real screenshot, one line of text and ENTER. Revive dummies, Back to spawn and Always revive sit along the bottom.
- **Events:** 9 cards with rendered 3D icons (Weightless, Deep Freeze, Falling Dummies, Wildfire, Mini Dummies, Giant Dummy, Meteor Rain, Tornado, Black Hole), "Free today" USE, then BUY R$25, x3 R$49, x6 R$89.

### What we copy as practice (own art and names, no assets or text copied)
1. **The world:**
   - a ground-level test ground in a hill landscape (no rooftop or void);
   - natural light with no haze on the play area;
   - muted materials;
   - real-world props in 1-2 colours;
   - **remove neon and almost all world text.**
2. **Dummies:**
   - plain white mannequins and no glow;
   - a short speech bubble when one is aimed at (we have DummyLife bubbles, BUBBLES=false: turn them on, short lines only).
3. **The HUD in one style:**
   - square dark-glass buttons with an icon and a word: 3 left (Shop, Weapons, Lab) and 2 right (Maps, Events);
   - an icon-only bar;
   - key chips bottom left;
   - one "Next: X 0/2" pill top right.
   - Remove the NEXT banner, the coloured slabs, the chaos meter, the sandbox column and the event side cards. Events get their own window.
4. **Windows:** a black body with one header colour per window, tabs on the left and big icons on the cards.
5. **Economy:**
   - first unlocks at 2/3/4 takedowns;
   - **SKIP for a small Robux price** on each locked weapon (a dev product per price tier);
   - a "Lab Controls" pass (fly, stop time, spawn, launch, explode);
   - events at 25/49/89 with one free per day.
6. **Maps:** several clean maps in place of one crowded lab. One of them is a plain "clean room". We have WorldMaps (Office, WhiteRoom): put them in a Maps window with screenshots.
