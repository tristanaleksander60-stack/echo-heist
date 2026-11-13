# First-person hands: how premium games make them look right, and our rules

_Written 2026-11-13 for the owner's note "the hands still look far too clumsy; find out how Steam games do it; they must be PERFECT". Facts carry a source (URL or LihFolk vault note). **Observed** marks what I describe from the games themselves (play and widely shared footage), not from a developer statement. **Rule** marks our decision. Several press pages (pcgamer.com, gameinformer.com, critpoints.net) could not be fetched from this session; their claims are quoted from the search engine's excerpts and are marked so._

## 0. Why ours looked clumsy (v101, measured)

Before this pass the first-person arms were the Rookie's **third-person body pieces** (the R15 lower arm and the chunky mitt or the 7-piece hinged glove) drawn at 0.4 scale and 0.4 nearer the eye. In full-size terms the hand sat 1.2 studs from the eye at FOV 70:

| Measure (16:9, FOV 70) | v101 | Typical premium FP (observed) |
|---|---|---|
| Palm + fingers width / distance | 0.56 / 1.2 = **0.47** (2 × atan → 26° = 37 % of the screen height) | 0.18-0.25 (10-14° = 15-20 % of the height) |
| Forearm diameter / distance at the wrist | 0.54 / 1.0 = **0.54** | 0.15-0.22 |
| Fingers | 3 bumps (mitt) or 2 rigid blocks of 3 fused fingers | 4 fingers × 3 segments + thumb, knuckles visible |
| Hands at idle | always up, mid-screen corners | lowered / out of the way until needed (horror, cozy) or low and still (shooters) |
| Projection | world FOV 70 (≈ 102° horizontal at 16:9), hands at ≈ 43° off-axis: edge stretch | a separate, narrower viewmodel FOV (≈ 42-54° vertical) |

The body arm is built to read at 48 px from 30 studs away (chunky, a fat mitt). From the eye the same proportions are 2-2.5× too thick, the mitt has no articulation, and the wide FOV stretches them at the corners. That is "clumsy".

## 1. Proportions: dedicated first-person arms

- **Every serious first-person game ships separate first-person arms**, not the third-person body. Source and Unreal style rigs: the "viewmodel" or "1P mesh" is a different asset from the 3P body ([TF2 wiki: Viewmodel](https://wiki.teamfortress.com/wiki/Viewmodel); [s&box: First-Person Weapons](https://sbox.game/dev/doc/first-person-weapons/)). Roblox developers who reuse the body arms report they "cover half the screen", and the standard advice is a separate first-person viewmodel with its own animation, "which many fps games use" ([DevForum: smaller viewmodel arms](https://devforum.roblox.com/t/how-to-make-viewmodel-arms-smaller-and-longer/2453624); [DevForum: slimmer arms](https://devforum.roblox.com/t/how-to-make-slimmer-arms/2018702); [DevForum: custom hands](https://devforum.roblox.com/t/making-a-viewmodel-with-custom-hands/1828467)).
- **First-person arms are cheated, not correct.** Firewatch's first-person body looks like a "deformed, double-jointed freak" from behind, because it is posed for the eye only ([GamesRadar: Firewatch is a freak of nature in third person](https://www.gamesradar.com/firewatch-third-person); [Game Informer: how first-person games trick our brains](https://gameinformer.com/b/news/archive/2016/02/12/how-first-person-games-trick-our-brains-by-creating-monstrosities-firewatch-edition), search excerpt). A Godot thread sums up the industry habit: FPS games "make it look smaller or bigger and move it out of the center or point it in the wrong direction to make it look 'nice' instead of 'correct'" ([Godot forum](https://forum.godotengine.org/t/what-is-the-best-way-to-setup-a-fps-rig-with-ik/139099)).
- **Appeal comes from the hand, not the arm.** DICE's goals for Mirror's Edge's first-person mesh were "appealing arms, hands and fingers, no volume loss" ([DICE, GDC: Creating First Person Movement for Mirror's Edge](https://pt.slideshare.net/DICEStudio/creating-first-person-movement-for-mirrors-edge-3151885)). Firewatch keeps "big cartoon hands" ([PC Gamer, best hand animations](https://www.pcgamer.com/the-best-hand-animations-in-first-person-games), search excerpt): a stylised game can enlarge the **hand**, but the forearm stays slim so the hand reads.
- **Stylised (our case):** Firewatch, Content Warning, R.E.P.O., Lethal Company (**observed**): chunky-cute hands with clean, simple silhouettes, 4 separate fingers (Lethal Company's are thick but separate), a slim sleeve, a cuff that marks the wrist.

**Rules (proportions):**
1. A dedicated first-person arm kit, never the body pieces.
2. Forearm (sleeve) radius **≤ 0.6 × the palm half-width** at the wrist, tapering out by ≤ 25 % toward the elbow. Ours: palm 0.44 wide → sleeve radius 0.13 at the cuff, 0.16 at the far end (the body sleeve was 0.27).
3. Hand length (wrist to middle fingertip) **≈ 1.8-2.0 × palm width**; middle finger ≈ palm length × 0.85; index ≈ ring > pinky (0.8 × middle); the thumb's tip reaches the index's first knuckle. Cute, not long: fingers 15 % thicker than realistic (radius ≈ 0.12 × palm width), tips rounded.
4. Screen size at rest: one hand (palm + fingers, back view) spans **14-18 % of the screen height**; the visible sleeve at the wrist **8-10 %** of the height.

## 2. Placement, framing and the viewmodel FOV

- **A separate viewmodel FOV is the norm.** CS:GO / CS2 `viewmodel_fov` defaults to 60, range 54-68, independent of the world FOV ([csdb: viewmodel_fov](https://csdb.gg/commands/fov-and-viewmodel/viewmodel_fov)); TF2's goes 54-70 "and it doesn't affect your game field of view" ([esportstales: TF2 FoV](https://esportstales.com/team-fortress/best-fov-field-of-view)). Engines expose the same idea (Dark Engine `rend-model-fov` "alleviates issues with weapon models not being drawn as the author intended", [Doomsday tracker](https://tracker.dengine.net/issues/2358)); Unreal projects add a "weapon FOV" so the arms don't warp when the player widens the camera ([Unreal forum: render arms at a separate FOV](https://forums.unrealengine.com/t/render-your-first-person-arms-weapons-at-a-separate-fov-than-your-camera-fov/237944); [WeaponFOVAndClippingFix](https://www.github.com/gerlogu/WeaponFOVAndClippingFix)). Source values are horizontal on a 4:3 basis: 54-68 horizontal = **42-54° vertical**. With a world FOV of 90 horizontal (4:3) that is a tan ratio of **1.5-1.9**: the hands are drawn "telephoto".
- **Why:** a rectilinear projection stretches what sits off-axis. Roblox's FOV is vertical; at 70° on 16:9 the horizontal FOV is ≈ 102°, so hands in the lower corners sit ≈ 40-45° off-axis and stretch (the near knuckles balloon, the forearm smears toward the corner).
- **Roblox has one camera FOV and a fixed near plane** (`Camera.NearPlaneZ` is read-only, about 0.1 studs) and no "draw on top" (LihFolk vault, "First-Person Viewmodels - Arms Rig, Sway and Camera Binding" §3 "Clipping into walls"). Options from the vault: scale the rig down and move it closer (looks the same, sticks out less), a wall push, keep geometry beyond the near plane, or a ViewportFrame (never clips but loses world lighting and costs a render; "only worth it for stylised games").
- **Faking the viewmodel FOV in Roblox (our method):** a viewmodel FOV `V` under a world FOV `F` maps camera-space points `(x, y, z) → (k·x, k·y, z)` with `k = tan(F/2) / tan(V/2)` (same screen image as a second camera at V). Rigid parts can't shear, so each part gets the exact mapped centre, its axes mapped and re-orthonormalised, and its size scaled per local axis by the length of the mapped axis (a forearm along the view axis grows in cross-section by k but not in length). The error is the shear of tilted parts only. It also keeps the hands identical across the comfort slider (60-90): k follows F.
- **Where the hands sit (observed: CS2 / HL2 defaults, Lethal Company, Phasmophobia, Firewatch, Mirror's Edge, Thief):** in the lower corners, the right hand the anchor; the forearm enters from the **bottom edge** (not the side), the hand canted **inward 12-25°** (fingers toward the centre), rolled so the thumb side lifts **15-30°** (you see the back of the glove and a bit of the thumb, never a flat pancake), the wrist slightly extended. Nothing at idle crosses the central third of the width or rises above ≈ −0.35 of the half-height (the reticle and the HUD centre stay clear). Showing a forearm: 15-25 % of the screen height of sleeve below the hand, ending at the frame edge (never a visible elbow or cut sleeve end).
- **Phones:** 19.5:9 is wider, not taller. With a vertical FOV the hands keep their height and move toward the centre in width share; they must still stay inside the screen-safe rect (no part off the left/right edge except the sleeve leaving the bottom).

**Rules (framing):**
5. Viewmodel FOV **50° vertical** (Config `VIEW_FOV`), applied with the per-part mapping above. k = 1.50 at the default FOV 70.
6. Rest (raised) pose, 16:9 NDC (x as a share of the half-width, y of the half-height): right hand centre **x 0.48-0.58, y −0.55 to −0.65**; left mirrored; fingertips below **y −0.30**; the inner fingertips outside **|x| < 0.22**.
7. Inward cant 15-20°, thumb-side roll 20-28°, wrist pitch (fingers up) 6-12°.
8. Every part's projected box inside the screen-safe rect at 16:9 and 19.5:9 for every pose: **|x| ≤ 0.97, y ≥ −1.10 (the sleeve may leave the bottom), y ≤ 0.85**, and never nearer the eye than 0.15 studs at world scale (near plane 0.1 + margin).

## 3. Detail: articulation, silhouette, material, shading

- **Fingers sell the hand.** Phasmophobia's 2025-26 player character update made the hands visible for "just about every interaction" and later shipped "a complete overhaul of equipment hold poses to fix visual clipping" ([Kinetic Games: Player Character Update 0.17](https://www.kineticgames.co.uk/news/phasmophobia-player-character-update-01700); [Phasmophobia v0.17.1.0 patch notes](https://kineticgames.co.uk/news/phasmophobia-v01710-patch-notes)). Half-Life: Alyx: the hands "adapt to the contours of things", and the fingers "tell you that you really can't interact with this" ([TechCrunch](https://techcrunch.com/2020/03/23/half-lifealyx-delivers-the-watershed-moment-vr-gaming-needs/)); Valve "spent years" on them ([Kotaku via search](https://kotaku.com/half-life-alyx-almost-had-enemies-who-reacted-when-you-1846941509)). Thief (2014): "the wonderful animation of Garrett's hands... picking a lock, snuffing out a candle, feeling its way along surfaces"; the hands are "a character in themselves" ([PC Gamer](https://www.pcgamer.com/au/the-best-hand-animations-in-first-person-games), [PCGamesN](https://pcgamesn.com/thief/hands-thief), search excerpts).
- **Silhouette (observed):** the readable hand has a gap between each finger, a knuckle line, a thumb that separates from the palm, a wrist pinch (cuff) and a palm with thickness. Mitts and fused finger blocks read as paws.
- **Material (observed):** a glove reads by its value break against the sleeve (dark glove on a light sleeve or the reverse) plus a cuff; fabric gloves show seams or ribbing, leather a slight sheen. Smooth normals on the fingers (no faceting at 15 % of the screen height), a crease line on each knuckle.
- **Lighting:** the arms sit in the world's light. Roblox lights near parts like any part (Future lighting: per-pixel local lights), so a dark glove in a dim room goes black, and a cream sleeve under a lamp blows out. Common fixes: a weak camera-attached fill (no shadows), slightly lifted glove values, and a matte material (no strong specular).

**Rules (detail):**
9. Per hand: a palm with thickness and a knuckle ridge, **4 fingers × 3 segments** each with a knuckle bulge, **a 3-segment thumb**, rounded tips, smooth-shaded (auto-smooth 50°). Separate pieces per segment so the code curls them.
10. The sleeve is the Rookie's cream knit with a ribbed cuff; the crew colour is the sleeve stripe (Breton) or the colour-block cuff (outfit); the glove variant's cuff (knit roll or leather gauntlet) in the glove colour; the gold REWIND watch on the left wrist.
11. Budget: **≤ 2,700 triangles per hand set** (raised from a first guess of 2,400, see §8) (one hand + its sleeve, cuff and stripes; Config `ARMS.TRI_BUDGET`).
12. Lighting: one client-only fill (PointLight at the eye, Range ≈ 2.5 world studs at 0.4 scale ≈ the hands only, Brightness 0.5-0.8, no shadows); the first-person glove colour lifted toward a mid value so the knit indigo never drops under luma 0.12 in the dimmest room; the sleeve a step darker than the body's (no blow-out under lamps).

## 4. When the hands are visible

- **Horror and cozy co-op hide or lower idle hands.** Phasmophobia showed nothing for years and now shows hands for interactions and held equipment ([Kinetic Games 0.17](https://www.kineticgames.co.uk/news/phasmophobia-player-character-update-01700); one review notes they now "obscure more of the screen than ever", [Destructoid](https://www.destructoid.com/all-new-features-in-phasmophobia-player-character-update/)). Lethal Company shows arms with held items and for interact animations (the ship lever, charging) ([Thunderstore: First Person View mod notes](https://thunderstore.io/c/lethal-company/p/seechela/First_Person_View/)). R.E.P.O.'s arm appears when you grab (**observed**). Half-Life: Alyx deliberately renders **no arms** at all, "due to our experiences with playtesting" ([VentureBeat AMA](https://venturebeat.com/ai/half-life-alyx-ama-everything-we-learned)). PowerWash Simulator's gloves are visible because you always hold the washer, but "you won't always be able to see your outfit or gloves" ([Looper](https://www.looper.com/939464/powerwash-simulator-how-to-change-gloves)). Superliminal and Teardown (**observed**): no idle hands; Teardown shows the held tool.
- **Immersive sims keep hands present.** Thief's "hands are always in view and moving fluidly" ([Stevivor preview](https://stevivor.com/previews/thief-hands-off-gameplay-impressions/)); its designer: "in our everyday first person view [we] get quite a good look at our hands" (search excerpt). Mirror's Edge and Firewatch show the full body when you look down ([Game Informer / GamesRadar on Firewatch](https://www.gamesradar.com/firewatch-third-person)).
- **Roblox (Doors, Pressure, Dead Rails, Frontlines, observed):** Doors and Pressure show no idle arms; the hands come in for the lighter, flashlight or a held item. Dead Rails and Frontlines show weapon arms all the time (shooters).

**Rule (visibility):** 13. Config `VISIBILITY.MODE` = `"lowered"` (default): at idle the hands sink to a low "ready" pose where only the backs of the gloves and the curled fingers peek in at the bottom corners (≤ 9 % of the screen height); they **raise** (0.16 s) when you look at something you can use, carry, play an action, point (onboarding) or REWIND, and **lower** (0.45 s ease) 0.6 s after the last reason. `"hidden"` drops them out of view at idle; `"always"` keeps the raised rest.

## 5. Motion

- **Springs, not tweens.** Sway and recoil are springs fed by the camera's rotation (not mouse deltas, so touch and gamepad sway too) (LihFolk vault, "First-Person Viewmodels" common mistakes; [DevForum: springs in FPS viewmodels](https://devforum.roblox.com/t/how-to-incorporate-springs-into-fps-viewmodel/2276084); [Opsive: springs](https://opsive.com/support/documentation/ultimate-character-controller/animation/springs/): low stiffness = soft sway, low damping = "bobblehead", high = "heavy and stiff").
- **Bob:** GoldSrc defaults `cl_bob 0.01, cl_bobcycle 0.8, cl_bobup 0.5` ([Valve: Half-Life cvars](https://developer.valvesoftware.com/wiki/List_of_Half-Life_console_commands_and_variables)): a small vertical bob (≈ 1 % of the speed), one cycle per two steps, the up-swing half the cycle. Arms bob **with** the head but lag it by a phase (≈ 30-60°), and swing side to side at half the rate (figure-eight).
- **Look lag (inertia):** the hands trail the turn and overshoot once when you stop (damping ratio ≈ 0.5-0.7, 4-6 Hz), and roll a few degrees into the turn. Clamp it (≈ 4-6 % of the screen height) so a fast flick never throws the hands off screen.
- **Interactions:** Thief "snaps" to the target and plays a short contextual animation ([search excerpt](https://www.gameskinny.com/reviews/out-of-shadows-thief-review/)). Procedural pick-ups blend IK weight up near the grab moment ([Realtime animation tips: procedural power](https://sites.google.com/view/realtime-animation-tips/tutorials/animation-procedural-power); [Arrival in Hell dev blog: picking up with IK](https://www.moddb.com/news/arrival-in-hell-dev-blog-5-picking-up-objects-with-ik)); a centre-screen reach "feels unconvincing when the item is clearly to one side" and errors in weight and timing "are glaring in first-person" ([MoCap Online: first-person animation guide](https://mocaponline.com/blogs/mocap-news/first-person-animation-guide)).
- **Anticipation → action → settle (animation principles):** a 50-90 ms pull back before a reach, a fast move (100-150 ms), a 5-10 % overshoot, a 200-300 ms settle; fingers lead (open before the hand arrives, close on contact).
- **Carry weight:** a held object lowers the hands and slows the sway spring (heavier = lower frequency, more lag).

**Rules (motion):**
14. Look lag spring **5 Hz, ζ 0.6**, 0.0009 studs per °/s, clamp 0.12 (full size), roll 0.015 °/(°/s) clamped 5°; carrying: 3.8 Hz, lag × 1.35.
15. Idle breathing: 0.25 Hz vertical 0.010, 0.13 Hz lateral 0.006 (full size), **off while walking**; walk bob in phase with the head bob, arms lag it by **40°**, vertical 0.028, lateral 0.022 at half rate, roll 1.6°.
16. Reach (grab): anticipation 0.07 s (hand pulls back 0.04 and fingers spread), reach 0.12 s with an 8 % overshoot, contact hold 0.08 s (fingers close), settle 0.26 s. Press: the index extends 0.06 s before the hand moves. Every action blends by envelope; nothing pops.
17. Fingers: a **relaxed idle curl** (MCP 18°, PIP 26°, DIP 14°, more on the pinky side: a natural cascade), a spring per joint (9 Hz, ζ 0.75), the thumb resting on the index side.

## 6. Common mistakes that read as clumsy

| Mistake | How it reads | Fix (rule) |
|---|---|---|
| Third-person arms as the viewmodel | fat sleeves, mitts, half the screen | dedicated slim FP arms (1-4) |
| World FOV for the arms | stretched corners, balloon knuckles, changes with the FOV slider | viewmodel FOV mapping (5) |
| Hands dead centre or too high | blocks the reticle, "zombie arms" | rest framing (6-8) |
| Flat palm-down hands, no cant | pancakes, no thumb read | cant + roll (7) |
| Mitts / fused finger blocks | paws | 4 × 3 + thumb (9) |
| Rigid fingers that never move | mannequin | per-action finger poses + relaxed curl (17) |
| Sway from mouse deltas only | dead on touch and pad | sway from the camera rotation (14) |
| Underdamped spring | bobblehead jiggle | ζ ≥ 0.55 (14) |
| Bob in perfect sync with the head | arms glued to the face | phase lag (15) |
| Instant action poses | robotic | anticipation, overshoot, settle (16) |
| Hands always up at idle in a cozy/horror game | clutter, "why are my hands up?" | lowered idle (13) |
| Black gloves in dim rooms / blown sleeves under lamps | lost silhouette | fill light + value tuning (12) |
| A visible sleeve end or elbow | cut-off look | sleeve long enough to leave the frame bottom (8) |
| Clipping into walls or the near plane | broken illusion | scale trick + wall pull + near margin (8) |

## 7. Our rules in one table (Config.FirstPerson.VIEWMODEL)

| # | Rule | Number |
|---|---|---|
| 1-4 | Dedicated FP kit `Rookie_FPArms`; sleeve r ≤ 0.6 × palm half-width; hand ≈ 1.9 × palm width; a hand spans 14-18 % of the screen height | palm 0.44 wide, sleeve r 0.13 → 0.16 |
| 5 | Viewmodel FOV (vertical) | `VIEW_FOV = 50` (k 1.5 at FOV 70) |
| 6-8 | Rest framing, cant, roll, safe rect | R hand x 0.48-0.58, y −0.55..−0.65; cant 15-20°, roll 20-28°; \|x\| ≤ 0.97, −1.10 ≤ y ≤ 0.85 |
| 9-11 | 4 × 3 fingers + 3-segment thumb, smooth, cuff, stripe, watch | ≤ 2,700 tris per hand set (`ARMS.TRI_BUDGET`) |
| 12 | Fill light + glove lift | 1 PointLight, no shadows |
| 13 | Visibility | `VISIBILITY.MODE = "lowered"` (raise 0.16 s, lower 0.45 s after 0.6 s) |
| 14-17 | Springs and timings | lag 5 Hz ζ 0.6; bob lag 40°; reach 0.07 / 0.12 / 0.08 / 0.26 s, 8 % overshoot; fingers 9 Hz ζ 0.75 |

The numbers were checked in the Blender preview (`tools/blender/fp_hands_preview.py`, `docs/art/fp_hands/`), which reproduces the game camera and these exact transforms; section 8 records what the renders changed.

## 8. What the renders changed

The preview (`tools/blender/fp_hands_preview.py`, the game's own ViewmodelMath + FpRig through Lune, over the real L1
interior) changed these first guesses:

| First guess | What the render showed | Now |
|---|---|---|
| Fingers r 0.045-0.053, middle 0.38 long | spidery, "claw" fingers | r 0.052-0.060, lengths -15 % (chunky-cute), palm 0.444 wide |
| Rest pitch 14, roll 24 (thumb side up) | the hand seen edge-on, fingers pointing flat at the centre | pitch 34, roll 12: the back of the glove faces the eye |
| A fixed elbow | the reach became a long pole of sleeve across the screen | `ELBOW_FOLLOW` 0.85: the elbow travels with the hand |
| Sleeve 0.136 -> 0.176 | a stick in the reach and hands-up | 0.138 at the cuff -> 0.21 at the screen edge (a knit sleeve is loose) |
| Lowered idle -0.5 | only dark fingertip blobs at the bottom edge | -0.26: the backs of the gloves and the relaxed curl peek in |
| REWIND: both hands crossing | two dark hands overlapping, the watch lost | the left forearm across with the watch face to the eye, the right index taps from below |
| Point: index along the view | foreshortened, unreadable | the hand turned in 33 and rolled: the index reads in profile |
| Budget 2,400 tris a hand set | the 4 x 3 + 3 segments (96 tris each) need more | **2,700** (left set with the watch: 2,688) |
