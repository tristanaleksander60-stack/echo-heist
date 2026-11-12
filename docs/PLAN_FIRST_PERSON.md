# PLAN: First person, own character, Phasmophobia-style lobby, aurora (v1)

The owner's request (2026-11-12, approved in full, "go non-stop"):

> Make it so you are not your own Roblox character but a fun, Steam-quality character. Phasmophobia / "RV There Yet?" style lobby: you spawn into a lobby, can pick a van, and choose solo or with others. You spawn in first person, can see your hands and pick things up like a Steam game, at the same quality. Northern lights in the sky, in good quality. Plan everything plus what's left from before, then go non-stop.

This plan **extends** docs/PLAN_STEAM_PLUS.md. The quality bar (§2), the verification ladder (§8) and the cut order still apply.

---

## 1. What changes and why

| From | To | Consequence |
|---|---|---|
| Your Roblox avatar; clones are copies of it | **"The Rookie"**: an original, Steam-quality robber character (MASTERPLAN §2.2: flat cap, long scarf, smug side-eye). Every player is a Rookie in their **crew colour and outfit**; clones are copies of *your* Rookie | Avatars.luau's template comes from the Rookie, not `GetHumanoidDescriptionFromUserIdAsync`. Crew cards show a Rookie portrait, not a Roblox headshot. "That's me" is carried by **your outfit and colour** (plus your name on the pill), and personalisation becomes a key progression hook |
| Diorama / classic third-person camera | **First person by default**, in the heists and the lobby. Diorama and classic stay as options in Settings and for presentation shots (rewind, 8 OF ME, Line-up, busted view) | CameraDirector gets an `fp` mode. All presentation moments still take the camera and hand it back |
| GRAB button with proximity pick | **Look-to-interact**: a centre reticle; the object you look at (within reach) highlights with a prompt; you pick it up **into your hands** (visible viewmodel), carry it, drop or throw it, and bank it at the van | The server still decides (CLAUDE.md): the client sends `Interact` with the target id it looked at, and the sim validates range and line. Loot carry is visible in first person (viewmodel) and third person (clones and other players) |
| Public garage with 8 bays; level select in a HUD panel | **Phasmophobia / RV There Yet? lobby**: you spawn in first person in the crew hideout (garage). You **walk to a van**, pick it (style and paint), and choose **SOLO** or **CREW** at it. The level is chosen on the **job board / laptop** in the world, not a HUD panel. The leader starts by climbing in and pressing **GO** on the dashboard → van-door wipe → drive transition → heist | Lobby, LobbyPlan, JobBoard and Garage UI are reworked. Party formation keeps the existing systems (PartyId, Join friend, Quick Crew opt-in) but surfaces them as van seats |
| Night sky with the Snow Globe tower | Plus **northern lights** (aurora): animated curtains in green, teal and violet, high quality, cheap on phones | A client Aurora module (layered Beams with scrolling gradient textures on curved spines) and an updated skybox. Per-tier budget |

## 2. Workstreams

### FP: first person and hands (track FP)
- **Camera:** `CameraDirector` mode `fp`, the default:
  - head-locked, FOV 70 (comfort slider 60-90), no roll;
  - head bob and landing dip, reduced-motion aware;
  - mouse lock on PC; touch drag to look, with the thumbstick on the left;
  - gamepad right stick.
  - The local character's body is hidden from the camera, except the viewmodel.
  - Presentation moments still use `setShot` / `setMomentShot`.
- **Viewmodel:** a local-only arms rig (the Rookie's sleeves and gloves) bound to the camera:
  - idle sway, walk bob, look lag;
  - pick-up reach, carry pose (the loot held in front, in view), throw, push (doors), button press, a REWIND wrist-watch tap.
  - Animated in Lua or Animator (the clips are uploaded, as done for clones).
- **Interaction:**
  - a centre reticle; a ray from the camera picks the looked-at interactable within `Config` reach;
  - the target gets an outline and a prompt ("GRAB", "OPEN", "BANK"; icon + word; touch shows a tap button);
  - the client sends the existing `Heist.Interact(kind, targetId)`; the server and sim validate. No new remote.
  - Plates are still stepped on.
- **Carry:** the held loot is visible in the viewmodel; others see it in the 3rd-person carry pose (clones already have it).
  - **Drop:** the existing drop rule.
  - **Throw:** only if the sim already supports it; otherwise not at launch (cut list).
- **HUD:** reduced to the essentials in first person (reticle, prompt, timer, clone pills, REWIND). The Clone Deck, results etc. stay as panels.

### CH: the Rookie character (track CH)
- **Model:** an original Blender character through the art pipeline gates, R15-compatible (named MeshParts and attachments), so Roblox animations and our clips work.
  - Style: stylised, chunky, readable at 48 px (like Gus); a flat cap, a long scarf, a smug side-eye, gloves and a robber sweater.
  - **Crew colour** on the scarf and sweater stripes; **outfit slots**: cap, scarf, sweater, gloves, mask. At launch: 4 variants per slot from the palette, as unlockables.
  - `StarterCharacter` (or server-side character loading) makes every player a Rookie, so the Roblox avatar is never shown.
- **Clones:** Avatars.luau builds the clone template from the player's Rookie with their outfit, so clones are copies of *your* Rookie. The CloneHealth, joint gate and fill logic stay.
- **Viewmodel arms** from the same meshes.
- **Faces:** an expressive face decal set (idle, smug, shocked, busted) swapped by state.
- **Crew cards and Line-up** use a Rookie portrait (a ViewportFrame) instead of the Roblox headshot.
- **Data:** an `outfit` field in the schema (additive), validated server-side; the outfit picker sits in the lobby at a mirror or wardrobe.

### LB: the lobby (track LB)
- **Layout:** spawn in first person inside the **hideout garage**:
  - a row of vans (3-4 styles × paints, choose by walking up and pressing PICK);
  - the job board (level select);
  - a laptop (daily vault, leaderboard);
  - a wardrobe and mirror (outfit);
  - the trophy shelf.
- **Van flow:**
  - your van is the one you picked;
  - **SOLO:** climb in, press GO;
  - **CREW:** your van's back doors open, friends who walk in (or join through Roblox invite / Join friend) take a seat; the leader presses GO when everyone is "ready" (seat lights);
  - Quick Crew stays opt-in at a "LOOKING FOR CREW" sign.
- **Transitions:** GO → doors shut → a short drive (an engine rumble, the town passing by the windows, 2-3 s, skippable) → the van-door wipe → the heist start. After the heist: the van returns, then the results.
- **Interaction:** all 3D: SurfaceGuis plus look-to-interact. The HUD panels only open when you interact with the board, laptop or wardrobe (Phasmophobia's computer screen pattern).
- **Server:** party formation reuses the existing crews/PartyId, `Heist.JoinFriend`, `SelectLevel` and `Ready`. Any new intent goes through an existing `Heist.*` remote with a validated argument. No new remote names.

### SKY: northern lights (track SKY)
- A client Aurora module: 3-5 curtain layers, each a chain of Beams along a curved spine high in the sky.
  - Textures: vertical streak gradients (uploaded), green → teal with violet tips, additive (LightEmission), slowly scrolling and undulating.
  - Subtle in the diorama view, a showpiece in first person when looking up and in the lobby yard.
- A skybox update with a lighter horizon and stars; the aurora reflects in snow as a faint green tint on exterior ambient (very low).
- **Tiers:** tier 1-2 full; tier 3 two layers; tier 4 one static layer.
- Reduced motion: slower, not off.

### Leftovers from before (still in force)
- **World 2.0:** finish (no black backgrounds, a neighbourhood per map); Technology Future.
- **Sound:** 13+ empty cues (the owner provides licensed ids); music commission.
- **Owner checks in Studio and on phone:**
  - the golden frames;
  - the type face pick;
  - the L1 cash and Toy Shop wall decisions (owner said everything is approved → **apply the recommendations: move the L1 cash into the window's view (x 6) and warm the Toy Shop walls**).
- **Kid tests**, round 1 and round 2, the phone bench (docs/PERF.md §8), store page and thumbnails from real shots, and clips.

## 3. Order (non-stop, at most 3 agents at once)

| Wave | Tracks | Gate |
|---|---|---|
| A | World 2.0 (finishing) · CH Rookie character · FP camera + interaction (placeholder hands until CH lands) | Local suite + engine suites green; Blender turntable of the Rookie |
| B | LB lobby · SKY aurora · FP integration with the Rookie viewmodel | Same, plus lobby engine tests (party flow) |
| C | Owner-approved level changes (L1 cash, Toy Shop walls) · first-person tuning across all levels (reach, prompts, Gus readability in first person, clone visibility tests in first person) · onboarding text for first person ("Look at the cash and tap GRAB") | Bots and help still pass; FP clone visibility test |
| D | Polish pass + blind review against the golden frames, then a publish | Every engine suite at 0 failures; published |

## 4. Risks
- **First person changes onboarding:** the L1 lines refer to positions. Fix: rewrite the lines for first person in wave C, with the bots re-run.
- **Gus and cones in first person:** a 3rd-person readable cone may be confusing up close. Fix: the cone stays a floor light, plus a screen-edge warning when he looks at you.
- **Clone recognition without the Roblox avatar:** outfit + colour + name pill. The kid-test gate "4 of 5 find their clone" still applies.
- **Phones in first person:** look + move + interact on touch. Fix: big tap targets, auto-aim assist on interactables within the reach cone (a "sticky" reticle).
- **Scope:** the cut order: throw → the drive transition (keep a door wipe only) → outfit slots beyond 2 → aurora layers beyond 2.
