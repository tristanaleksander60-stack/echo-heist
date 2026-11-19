# RAGDOLL HAVOC v3: maps, look and lab activities (owner request, 19 Nov 2026)

The owner's words: "Tag inspiration af ALT grafisk, helt ned til mindste detalje. Brug maps, biler (fine if from other creators). Tilføj en masse forskellige ting ved de forskellige maps, og især kæmpe opgradering i ens eget lab i forhold til aktiviteter, så folk altid har noget nyt at lave."

Reference: Hyper Realistic Ragdoll gameplay captures (80k CCU), see LOOK_PLAN.md.

**Rules:**
- Free Creator Store models are allowed. Never copy files out of another game.
- Every inserted model gets a malware pass before it is kept. Delete every Script and LocalScript unless we wrote it, and search for `require(`, `getfenv`, `loadstring`, `TeleportService` and `HttpService`. We found malware four times already.

## What their captures show, detail by detail

| Area | Detail |
|---|---|
| Light | Overcast but clean. Roblox cloud sky, soft shadows, no haze on the play area, a slight distance fade on the hills. Low contrast and natural colours. |
| Ground | **Terrain**: Grass (textured, with brown patches), Sand on the island, Ground or Mud on the site. Wide light concrete paths of about 12 studs with joint lines. |
| Backdrop | Rolling green hills (terrain) with low-poly pines and broadleaf trees. The sea is terrain water to the horizon. |
| Props | Real-world objects at 1:1 scale with plain materials: a train on a track, a tank, a monster truck, a blue sedan, a white sports car, red-white barrels, a brick wall, a boxing ring, a wooden crate, a big red push button, benches, a castle tower, a giant fan, a slide tower, a rocket, a pool, a bunker with a truck. |
| Island | A beach ring, palms, a jetty, parked vehicles on concrete pads, a catapult, **a gorilla in a pen** (rocks and logs), a cliff, and a world screen showing the map list. |
| Building site | A concrete mixer, scaffolding, a building frame, a tower crane with a hanging hook, sand and gravel piles, a wheelbarrow, a cable drum, jersey barriers, mesh fences, a fenced pit, pallets, bricks. |
| Dummies | Plain white, **many wander idle** across the map. Speech bubbles are small black boxes: yellow text with a gun icon when you aim ("Is that a gun?", "Whoa, put that down!", "Don't shoot!"), white text for idle chatter ("I wish I had a dog."). |
| HUD | Left: Shop, Tools and Lab (big square icon and word). Right: Maps and Events. Bottom: 6 icon-only slots. Bottom-left chips: R Revive · G Spawn · V Scan. Top-right: a gift icon and a "Next: Golf Club 2/3" pill. A Here/Friends/Global board. One font, dark glass, white icons. |

## The build, in phases (each behind a Config switch, `LOOK_V3`)

### Phase A: look and HUD (code, can be done in the cloud session)
1. **Lighting.** A `ZoneLighting.Overcast` profile:
   - ClockTime 13;
   - Brightness 2.2;
   - Ambient (70,72,78), OutdoorAmbient (120,124,130);
   - EnvDiffuse 1, EnvSpecular 0.6;
   - ShadowSoftness 0.35;
   - Atmosphere Density 0.3, Offset 0.1, Haze 0.4, Glare 0, Color (199,205,214), Decay (106,112,125);
   - Bloom 0.1, ColorCorrection Contrast 0.05, Saturation -0.05;
   - no DepthOfField or SunRays.

   ChristmasFx keeps the snow only.
2. **Dummies:**
   - plain white (`DummySkin` colour 245,245,245), no NpcGlow, no suits or numbers;
   - `DummyLife.BUBBLES = true` with two line sets: fear (when aimed at, with a gun icon, yellow) and idle (white, every 20-40 s, max 2 at a time per screen);
   - idle wander for every free dummy.
3. **HUD v3 (`Client/HudV3`):**
   - Left column Shop / Weapons / Lab and right Maps / Events. Square cards of 132x120, dark glass at 0.25 transparency, a white icon of 56 px and an 18 px word.
   - The icon-only bar (6 slots, 88 px, number top-left).
   - Key chips bottom-left.
   - Next pill top-right.
   - Hide the NEXT banner, the chaos meter, the sandbox column, the event side cards, the level badge and the experiment card on PC. The experiment moves into the Lab window.
   - Phone: the same with smaller cards; SHOOT, GRAB and RAGDOLL stay.
4. **Windows:** a black body, one header colour each (Weapons red, Lab teal, Maps olive, Events magenta), tabs left, big icons.
5. **World text off:** `Playground` billboards, `WorldDress` boards, leaderboard neon and the OWNER/VIP tags (switch).

### Phase B: maps (local session with Studio MCP and the Creator Store)
Every map is a Model under `ServerStorage.Maps`, streamed in for that player's lab (per-player lab stays). A Maps window shows a screenshot and ENTER. There are 6 maps, each with **at least 25 props and 3 activities**.

| Map | Ground and backdrop | Props (free models allowed) | Activities |
|---|---|---|---|
| **Test Ground** (the new own lab) | grass terrain, concrete paths, hills and pines | a train and a looping track, a tank, a monster truck, a sedan, a sports car, barrels, a brick wall, a boxing ring, crates, benches, a castle tower, a giant fan, a slide tower, a rocket, a pool, a bunker | drive vehicles, the train runs dummies over, a fan wind tunnel, a slide, a boxing ring, a big red button (random event), explosive barrels, a rocket launch |
| **Island** | a sand beach ring, sea, palms, a cliff | a jetty, a boat, parked vehicles, a catapult, a gorilla pen, a lighthouse, beach huts | the catapult launch, the gorilla throws dummies, a cliff dive, boat ramming, waves |
| **Building Site** | ground/mud terrain, a site fence | a tower crane and hook, a building frame, scaffolding, a mixer, piles, a wheelbarrow, barriers, a pit, pallets | the crane grabs and drops, a wrecking ball, a falling scaffold, a mixer spin, digger scoops |
| **Clean Room** | a white room, soft ceiling lights | nothing but a few cubes | pure testing with no clutter |
| **City Street** (ours) | asphalt, pavements, shop fronts | buses, taxis, traffic lights, hydrants, lamp posts, a bus stop | bus runs, crash test at a junction, a crosswalk |
| **Christmas Village** (from Dec 1) | snow terrain, cabins | a sleigh, a chimney launcher, a present pile, a tree, a skating pond | the sleigh ramp, the chimney launch, an ice slide, snowball cannons |

### Phase C: lab activities ("always something new")
- **Vehicles** (VehicleSeat on our own simple chassis, never a free-model chassis script):
  - car, monster truck, tank (shell = Blast), bus;
  - hit speed above 30 studs/s ragdolls a dummy;
  - an F prompt to enter.
- **Machines:**
  - the train (a fixed path, 30 s loop);
  - the giant fan (VectorForce cone);
  - the crane hook (grab and drop);
  - the catapult (a charged launch);
  - the wrecking ball (exists);
  - the big red button (fires a random Event, 60 s cooldown);
  - explosive barrels (respawn after 20 s).
- **Animals:** a gorilla that wanders and throws a dummy within 10 studs, and later a bull.
- **Activity of the day:** one machine or map highlighted each UTC day, plus an Experiment tied to it (ExperimentService exists).
- **Lab upgrades for Bolts:**
  - buy and place machines in your own lab (BuildService exists);
  - 3 lab sizes;
  - a "Lab Controls" pass (fly, stop time, spawn dummies, launch, explode), as the leader sells.

### Phase D: economy (as in LOOK_PLAN)
- First unlocks at 2/3/4 takedowns.
- SKIP R$9-49 per locked weapon (dev products by tier).
- Events R$25/49/89 with one free a day (already close).

## Order and proof
1. Phase A first, judged on real Studio captures from the same 3 camera spots before and after.
2. Then one map at a time, Test Ground first.
3. Each map gets its activities in the same step, plus a SelfTest (`T9x_Map<Name>`: prop count, no scripts in models, activities fire).
4. LayoutCheck stays at 0 problems.
5. The owner publishes after each phase.
