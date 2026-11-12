# Heist Yourself: the "Steam premium" bar (research report)

_Dimension: what makes a game feel premium, and the bar Heist Yourself must clear. Written 2026-11-12. It builds on, and does not repeat, MASTERPLAN §6-7, `docs/STYLE_BIBLE.md`, `docs/research/visuals.md` (art direction, palette, lighting, clone look) and `docs/research/feel.md` (rewind, audio, HUD, FTUE). Where those docs already decide something, this report cites the section and adds only what is new._

**Evidence tags.** **[S]** a web source (linked). **[V]** a LihFolk vault note. **[A]** my analysis of a game's well-known behaviour, from play and footage, not from a cited source: check it against a 2-minute clip before quoting it as fact. **[UNVERIFIED]** I found a claim but could not confirm it. Lines that start with **Decision** or **Rule** are my calls.

---

## Summary

"Premium" is not detail or fidelity. Across the ten Steam games and eight Roblox games studied, the same four properties come up every time:

1. **One reading order per frame.** Each game reserves a tiny visual vocabulary and never breaks it. Superhot: red = enemy, black = usable, white = everything else ([S](https://www.reddit.com/r/SUPERHOTbackers/comments/2tfaxd/friday_update_8_making_a_black_and_white_game_pop/)). Sly Cooper: blue sparkles = "you can do a thief move here" ([S](https://en.wikipedia.org/wiki/Sly_Cooper_and_the_Thievius_Raccoonus)). Overcooked: "bright solid images which read well from a distance" ([S](https://caneandrinse.com/ghost-town-games/)).
2. **Every input is answered fast, on several channels.** The answer comes within 0.1 s (Nielsen's direct-manipulation limit, [S](https://www.nngroup.com/articles/website-response-times/)), with sound no more than 30 ms after the picture ([V] *Feedback Timing*), and through 2-4 channels at once: picture, sound, motion, sometimes haptics.
3. **Restraint in quantity, generosity at the peaks.** Juice is a budget. Hitman GO and Lara Croft GO are almost silent between moves. Their premium feel comes from a few perfect, tactile moments ([S](https://www.playstationlifestyle.net/2016/02/23/hitman-go-review-relaxing-assassinations-ps4/)), not from constant particles. The vault's reward ladder makes the same point: only the top tier may dim the world ([V] *Reward Moments*).
4. **Authorship you can see in one second.** A wordmark, a sound logo, a signature transition, and one silhouette nobody else owns. Superhot's shatter, the Goose's honk ("the honk went in on day one or two", [S](https://fmod.com/blog/untitled-goose-game-interview)) and Hitman GO's figurines each read in one second with the sound off.

Our plans already cover most of point 1 (STYLE_BIBLE §1-2) and much of point 2 (MASTERPLAN §7). The gaps: **UI craft** (no type scale, motion tokens or UI sound map), **character acting**, **telegraphing the machine** (Gus and lasers don't show their next move as the GO games do) and **tactile world feedback**. Section 4 is a 60-item checklist, section 5 the 10 biggest MVP gaps, section 6 the mapping onto our features.

---

## 1. Teardowns: ten Steam reference games

Each entry covers the dimensions that teach us something new (visuals.md F4 and feel.md F1 already summarise several of these games) and ends with **Steal**.

### 1.1 Monaco 2 (Pocketwatch Games, 2025)

- **Art and readability.** The move from pixel art to isometric 3D was partly a response to players who "struggled to understand the original" ([S](https://aftermath.site/monaco-2-demo-interview/)). Reviews praise a "rich palette [that] pops without distraction" and say "the legibility of the UI and characters is great" ([S](https://www.gamescreed.com/reviews/monaco-2-review)). Each crew member has "a distinct silhouette and colour scheme to go with their unique abilities" ([S](https://www.gamegrin.com/reviews/monaco-2-review)).
- **The counter-example that matters for us.** Steam Deck HQ (Japanese review, paraphrased) found guards, items and interactables hard to spot on a 7-inch screen and called the game unsuited to small screens ([S](https://steamdeckhq.com/ja/game-reviews/monaco-2/)). Our median screen is smaller than a Deck.
- **Fog of war as art direction [A].** Unseen rooms are drawn as dim blueprint; information is the lighting. The original's vision cones "swoop across the level and through open doors" ([S](https://gamesbeat.com/monaco-review/)).
- **1-second read:** a lit room cut out of a dark blueprint, four colour-coded thieves running.
- **Steal:** (a) a **minimum on-screen size** for every gameplay-critical object on our smallest screen (checklist A6); (b) progress rings **on the actor** for timed interactions (cracking, carrying) rather than in the HUD.

### 1.2 Hitman GO (Square Enix Montréal, 2014)

- **Art.** Enemies slide between nodes "like pieces of a mechanical diorama" ([S](https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense)), lit with Unity's default lightmaps ([S](https://www.pocketgamer.biz/interview/75079/square-enix-montral-design-team-on-crafting-beautiful-gaming-experiences-for-small-screens/)). Constraints (price, session length, production) drove the design ([S](https://gdcvault.com/play/1021908/Design-by-Constraints-Hitman-GO)).
- **Animation [A]:** figures don't walk. They **slide and tilt**: a short lift, a glide and a settle, like a hand moving a piece. Taken pieces are knocked over and **set beside the board** like captured chess pieces. No character acting at all, yet it reads as charming because the fiction (toys) explains the stiffness.
- **Audio.** Reviews say the sound effects "drive home the board game design" and that you hear "noises players would associate with different materials" ([S](https://www.cgmagonline.com/review/hitman-go-definitive-edition-ps4-review/), [S](https://www.playstationlifestyle.net/2016/02/23/hitman-go-review-relaxing-assassinations-ps4/)). The criticism was a thin, repetitive soundtrack.
- **First 60 s [A]:** the whole board is shown, one swipe moves 47 one node. **Juice density:** very low, one tactile beat per move.
- **1-second read:** a plastic figurine on a lit board in a dark void.
- **Steal:** the **fiction explains the stiffness**. Our clones are "tape prints" and Gus is a rigid-part rig (MASTERPLAN 6.5, 6.7). Lean into it: clones and Gus can move like *wind-up toys* where we can't afford acting (section 6.3). Busted clones go "beside the board", onto a busted shelf at the van (section 6.7).

### 1.3 Lara Croft GO (Square Enix Montréal, 2015)

- **Art.** "The cool 2015 version of" the original Tomb Raider's low-poly look: large flat-colour surfaces rather than visible triangles, plus fog, vistas and foreground silhouettes ([S](https://en.wikipedia.org/wiki/Lara_Croft_Go)). It needed a **custom lighting system**, unlike Hitman GO ([S](https://www.pocketgamer.biz/interview/75079/square-enix-montral-design-team-on-crafting-beautiful-gaming-experiences-for-small-screens/)).
- **Camera.** Phone-first, with **no player camera**: "swipe anywhere on the screen and Lara moves, and that's it". ([S](https://gamedeveloper.com/design/-i-lara-croft-go-i-dev-remake-how-you-felt-playing-a-classic-game-not-the-game-itself)).
- **Onboarding.** No text tutorial. "The levels themselves are designed to teach you" each new mechanic or enemy on first contact ([S](https://en.wikipedia.org/wiki/Lara_Croft_Go)). A developer's counterpoint: without any diagram "many things remained unclear" ([S](https://itch.io/post/6262506)). Show-don't-tell needs a fallback.
- **Telegraphing [A]:** every enemy shows its next move (a snake faces its strike tile, a lizard glows on its path) and moves only after you do. The machine is fully predictable.
- **Animation:** fully animated, because "Lara's incredibly athletic" ([S](https://gamesbeat.com/lara-croft-go-developer-on-turning-an-action-blockbuster-into-a-turn-based-mobile-game/)); [A] ledge-grab anticipation, heavy landing settles.
- **Steal:** **telegraph the machine.** Gus and the lasers are deterministic (MASTERPLAN 3.2 #3), so we can show their next 2 s for free (section 6.4).

### 1.4 Sly Cooper and the Thievius Raccoonus (Sucker Punch, 2002)

- **Art.** "Toon-shading": detailed, illustrated backgrounds with cel-shaded foreground characters, compared with animated film. The look was praised for "a film noir feel" while still reading as a cartoon ([S](https://en.wikipedia.org/wiki/Sly_Cooper_and_the_Thievius_Raccoonus), [S](https://gameinformer.com/b/features/archive/2017/10/21/celebrating-15-years-of-sly-cooper-sonys-most-stylish-mascot.aspx)).
- **Affordance language.** Interactable thief spots wear **blue sparkles** ("thief senses"), and one button acts near any sparkle ([S](https://en.wikipedia.org/wiki/Sly_Cooper_and_the_Thievius_Raccoonus)). Collectible clue bottles **tinkle when you are near** ([S](https://slycooper.fandom.com/wiki/Clue_bottle)).
- **Animation [A]:** Sly's sneak is the series' signature: tiptoe with exaggerated knee lift, cane held back, a squash on every footfall. Guards do slow, broad double-takes before the alarm. The "tiptoe" music plays while sneaking.
- **Juice [A]:** medium. **1-second read:** a raccoon tiptoeing in silhouette against a blue-violet night.
- **Steal:** (a) **one affordance glyph** for "you can do something here" that works on every interactable, plus a proximity tinkle for loot; (b) **guard double-takes** as acting beats (Gus's "?" stage); (c) **a sneak walk** for the player and clones when walking slowly near Gus (section 6.1).

### 1.5 Untitled Goose Game (House House, 2019)

- **Art.** "Low poly meshes, flat colours, and untextured 3D models", inherited from their 2D flat-colour game ([S](https://en.wikipedia.org/wiki/Untitled_Goose_Game)). The closest proof that untextured, SmoothPlastic-style art can win awards (STYLE_BIBLE §4 follows it).
- **Animation.** The goose's head tracks the gardener through IK, so the goose is always *looking* at its target ([S](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-house-house-s-i-untitled-goose-game-i-)). [A] There are two locomotion modes, a waddle and a neck-low run with wings out. The comedy is in the NPCs' acted reactions (puzzled, angry, sulking).
- **Audio.** The honk was "one of the most important parts of the game" and went in "in the first day or two" ([S](https://fmod.com/blog/untitled-goose-game-interview)). The adaptive Debussy score is covered in feel.md F1.
- **Onboarding.** A short controls area, then a **to-do list** that structures each area ([S](https://www.nintendolife.com/news/2020/05/guide_untitled_goose_game_walkthrough_-_puzzle_solutions_and_to-do_list_objectives)); [A] items are struck through with a pencil line. Failure is gentle: no health or lives.
- **1-second read:** a white goose, neck out, running with a stolen object, a human chasing it.
- **Steal:** (a) a **verb with no purpose but comedy** (honk). For us: a whistle or emote that **clones replay**, so a crew of 8 whistling is a clip (section 6.1); (b) **head tracking** on clones and Gus: clones look at what they will grab next, and Gus looks at the nearest actor in his cone; (c) the **job sheet with pencil strike-throughs** as the medal and bonus-goal UI (section 6.6).

### 1.6 Superhot (Superhot Team, 2016)

- **Art.** The team "couldn't produce AAA-quality assets", so constraints set the style: red enemies, a white world, black usable items, with greyscale used "to make objects pop a little bit more" ([S](https://www.reddit.com/r/SUPERHOTbackers/comments/2tfaxd/friday_update_8_making_a_black_and_white_game_pop/)). Reviews describe enemies as "featureless human-like shapes that shatter like glass" ([S](https://bit-tech.net/reviews/gaming/superhotsuperhotsuperhot/2/); outlet attribution of the exact quote not pinned).
- **Audio.** In combat "everything is heavily filtered and sounds muffled… Gun shots and impact sounds are slowed down to suit the current speed" ([S](https://www.thesoundarchitect.co.uk/superhot/)). Audio is bound to the time mechanic.
- **Presentation [A]:** after each level, **your whole run replays at real speed** while a robotic voice chants "SUPER. HOT." This is the most direct ancestor of our Heist Reel: the replay shows the player that what felt slow and careful was in fact an action movie.
- **UI [A]:** almost none. Text is part of the fiction (a fake terminal OS).
- **1-second read:** a red crystal man shattering in a white room.
- **Steal:** (a) **muffle the world** (low-pass) during rewind and planning, so "time is stopped" can be heard; (b) the **real-time replay plus a sound logo** is our Reel (the clone arpeggio, MASTERPLAN 7.2); (c) **failure that shatters** satisfies even in defeat, as our Busted tape-ribbon burst does (MASTERPLAN 6.5 #6).

### 1.7 Teardown (Tuxedo Labs, 2022)

- **Art.** "A coalition between this abstract voxel appearance… with the very realistic lighting" ([S](https://www.techradar.com/gaming/consoles-pc/ray-tracing-is-so-crucial-to-teardown-that-the-world-goes-black-if-you-turn-it-off)). It uses ray tracing for AO, soft shadows and specular occlusion, without full GI ([S](https://80.lv/articles/teardown-developer-breaks-down-multiplayer-and-voxel-destruction-tech)). We can't ship that light on phones; STYLE_BIBLE §2 bakes the "bevels catch light" read into the atlas instead.
- **Structure.** Untimed planning; taking the first alarmed target starts a **60 s** escape window ([S](https://get-teardown.readthedocs.io/en/latest/gameplay/heist-basics.html)). Already adopted (feel.md F1).
- **UI [A]:** the hub is a diegetic computer (email, briefings).
- **1-second read:** a wall caving into voxels, a car smashing through it, a timer counting down.
- **Steal:** the **plan → commit → alarm** rhythm, already in our Alarm Run (MASTERPLAN 3.6). New: a **diegetic briefing screen** in the van (a CRT with the level's "job card": target, Gus's name, the par) instead of a flat menu (section 6.5).

### 1.8 Ruiner (Reikon Games, 2017)

- **Art.** Creative director Benedykt Szneider came from logotypes, comics and marketing art ([S](https://www.lacedrecords.com/blogs/blog/seeing-red-ruiner-s-creative-director-on-how-style-can-precede-substance)); influences were Akira, Lain and Ghost in the Shell ([S](https://www.pcgamesinsider.biz/indie-interview/66175/hotline-miami-akira-and-polish-history-reikon-tells-us-about-cyberpunk-action-game-ruiner/)).
- **Animation and VFX [A]:** a dash with afterimages, slow-mo on the dash aim, enemies thrown with exaggerated ragdolls and brief hit-stop. Bold, graphic, Japanese-inflected typography stamps.
- **Juice density [A]:** very high, which the hostile setting justifies. Reviews call the combat "gloriously chaotic" but samey after a while ([S](https://www.cgmagonline.com/review/ruiner-pc-review/)).
- **1-second read:** a red-lit masked figure dashing through enemies with afterimages.
- **Steal:** a **logotype mindset**. The creative lead thought in marks and stamps, so every stamp ("RUN 4", "BUSTED", "CLEAN") is part of the brand. **Afterimages** are the cheapest "motion" read on Roblox: a 3-ghost trail is our clone theme in miniature (section 6.1).

### 1.9 The Sexy Brutale (Cavalier Game Studios and Tequila Works, 2017)

- **Concept.** A 12-hour time loop. Items and characters reset each loop, and you often "stalk the guests for a loop, the staff for a loop" to solve a murder ([S](https://en.wikipedia.org/wiki/The_Sexy_Brutale)). The masks keep guests "unaware" of the loop ([S](https://www.pcgamesn.com/the-sexy-brutale/the-sexy-brutale-preview)). Reviewers praised the "living diorama" of art deco rooms ([S](https://gamegrin.com/reviews/the-sexy-brutale-review)) but found reliving the day tedious (visuals.md F4).
- **UI.** Reviews describe a **stopwatch in the corner showing the mask of the next guest to die and when**, so the player knows how much time is left to act [S: reported in several reviews; outlet not pinned, UNVERIFIED wording].
- **Steal:** (a) **show the next scheduled event** on the run bar: "Gus turns at 0:24", "laser off 0:31-0:36" (section 6.4); (b) answer tedium with **fast-forward and visible novelty** per loop (MASTERPLAN 3.4; feel.md D2).

### 1.10 Overcooked (Ghost Town Games, 2016)

- **Design intent.** "The challenge was the communication between the players, rather than the complexity of the inputs"; a **timer beat lives** in convention playtests ([S](https://en.wikipedia.org/wiki/Overcooked)). Art aims for "bright solid images which read well from a distance" ([S](https://caneandrinse.com/ghost-town-games/)).
- **UI [A]:** order tickets carry **icon recipes** with a draining colour timer (green, then yellow, then red with a shake). Every cooking station has a **world-space progress ring**, and a flashing "!" warns before a fire. The results screen **stamps 1-3 stars** against visible thresholds, then counts the score up.
- **Animation [A]:** tiny big-headed chefs, dash puffs, a chop squash; silhouettes stay readable when 4 players overlap.
- **Audio [A]:** a ding on delivery, a sizzle that rises before burning, an alarm before fire. **The sound warns before the picture fails.**
- **Steal:** (a) **warning sound before failure**: lasers re-arming and Gus's "?" stage get a rising cue 0.5-1 s ahead (feel.md has the heartbeat; add it to the lasers); (b) **star thresholds shown up front** on the job sheet, then stamped on results; (c) **world-space rings** for timed interactions.

---

## 2. Teardowns: Roblox games known for visual and feel quality (2025-2026)

Source quality is weaker here: few primary developer statements, much SEO filler (discarded). The vault case studies are the best material.

| Game | What sets it apart (with numbers) | Steal |
|---|---|---|
| **Pressure** | "The art direction is the brand": cold blue-green palette, pipes, wet surfaces, readable at thumbnail size. Audio is the primary sensor: every lethal creature has a sound signature audible "at the distance where hiding is still possible". Death screens teach in lore. Peak **112,111 CCU** (28 Mar 2026). A content warning screen since Aug 2024 ([V] *Teardown - Pressure*). The store page recommends headphones and graphics level 8+ ([S](https://rowatcher.com/games/4367208330/pressure)) | Tune the warning sound to the reaction window. A light, kind content warning line |
| **DOORS** | One tell and one counter per entity (Rush flickers the lights → hide). The death screen is the tutorial (Guiding Light). A custom wordmark with door-shaped Os survives 50 px ([V] *Case Study - Doors*). Each entity has an audio signature ([S](https://endsights.com/horror-game-design)) | **Busted card = one sentence of counterplay** keyed by cause. A wordmark with a custom letterform |
| **Dead Rails** | A single visible progress object (the train) is home, transport and score. "Novelty on top of familiarity" (MAYA). Promoted by Roblox's own channels in early 2025 ([S](https://gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula); [V] *Case Study - Dead Rails*) | **The van is our train**: home, progress shelf and exit in one object (section 6.5) |
| **99 Nights in the Forest** | Peak **14.2 M CCU** ([S](https://www.pcgamer.com/games/survival-crafting/with-a-peak-player-count-of-14-2-million-99-nights-in-the-forest-has-an-audience-other-multiplayer-games-would-kill-for-to-find-these-behemoth-playerbases-you-need-to-be-on-a-platform-like-roblox/)) with "no flashy visuals". Lighting and sound carry it: the night shrinks the world to the campfire's light radius, and the Deer waits at its edge ([V] *Case Study - 99 Nights*). The tutorial is the environment | **Light as rule**: our lit pools could be "safe" and dark could be where Gus's cone reads best. Light is information, not decoration |
| **Grow a Garden (UI)** | Cash always in one corner; **3 top buttons teleport** to shop, garden and sell; the loop takes a few clicks; restock countdown every ~5 min ([S](https://www.metaversemarcom.io/post/inside-the-monetization-playbook-of-roblox-s-biggest-hit), [S](https://www.pcgamer.com/games/survival-crafting/i-played-the-roblox-hit-thats-pulled-in-10-billion-visits-and-while-im-not-sold-on-it-i-can-see-how-its-cultivated-a-mass-following)). The first click after spawning can be a purchase ([V]) | **Fewest taps to the loop**: garage → heist in ≤ 2 taps. One countdown that matters (the daily vault) |
| **Frontlines** | Since 2017; the aim was to test whether high fidelity was possible, focused on "how players feel" ([S](https://about.roblox.com/newsroom/2026/07/roblox-studio-fidelity-creator-interviews-twin-atlas-fluorlite-maximillian-ecos)); "you can boot it up on your mobile" ([S](https://www.pocketgamer.biz/interview/81103/maximilian-studios-on-the-success-of-frontlines-you-dont-need-a-3000-rig-or-a-500-console-you-can-boot-it-up-on-your-mobile-device/)) | Fidelity must survive the phone |
| **Fisch** | The controls are taught **on the store page** (hold to cast, shake, keep the white bar on the blue line). First catch in under a minute. A 5-page tutorial overlays the reel bar on first use. "Shake" prompts are optional speed-ups ([V] *Case Study - Fisch*; [S](https://videogameschronicle.com/guide/fisch-fishing-tips)) | **Store description = 3-line manual** (our verbs: plate, END RUN, grab). Optional skill speed-ups on the core verb |
| **DONT SPLASH** | Created 17 Oct 2026 by Bacon Theory, an obby-runner where skipped pebbles lure a monster off your path; ~97K playing at a recent peak ([S](https://www.rotrends.com/game/10771421858/DONT-SPLASH), [S](https://rowatcher.com/games/10771421858/dont-splash)). I found **no** source analysing its visuals [UNVERIFIED as a visual benchmark] | A **lure verb** is a clip in itself. Nothing visual to copy until someone plays it |

**Cross-Roblox pattern.** The breakout visual hits (Pressure, DOORS, 99 Nights) are dark, stylised and lit for information, with **audio carrying half the readability**. The realistic showcases (Frontlines, TTK, Creatures of Sonaria) are praised for fidelity, but their teams talk about feel and phone support ([S](https://gamesbeat.com/twin-atlas-is-among-the-studios-changing-what-roblox-games-look-like-exclusive-interview/)). On Roblox, "premium" = coherent + informative + runs on a phone (visuals.md F5 reached the same conclusion).

---

## 3. What the premium games share: twelve patterns

1. **A reserved vocabulary.** 3-6 meanings, each owning a colour plus a shape plus a sound, never reused for decoration (Superhot, Sly, Overcooked, Pressure). *We have the colours (STYLE_BIBLE §1.3). We lack the matching sound and glyph table for each meaning (checklist E2).*
2. **The fiction explains the limits.** Toys slide (Hitman GO), voxels break (Teardown), tape glitches (our clones). A claimed limit looks like style; an unclaimed one looks like a bug.
3. **The machine telegraphs.** GO enemies, Overcooked's pre-fire "!", DOORS' flicker and Pressure's sounds all warn before they punish. The best warnings come 0.5-1.5 s ahead, in two channels.
4. **Acting is spent on reactions, not locomotion** (Goose NPCs, Sly's guards, Overcooked's chefs).
5. **Feedback on several channels and on one clock.** Picture, sound, motion and (on phones) haptics land within 30 ms of each other ([V] *Feedback Timing*). Balatro's whole feel is this layering of shake, particles, count-up and sound ([S](https://www.avclub.com/balatro-hones-the-art-of-making-numbers-go-up)).
6. **Escalate by adding layers, not volume.** Hit-stop scales with weight (fighting games use about 8/12/16 frames for light/medium/heavy, [S](https://game.capcom.com/cfn/sfv/column/131545?lang=en)). Reward tiers add channels ([V] *Reward Moments*).
7. **Quiet baseline, loud peaks** (Hitman GO, Lara Croft GO, Superhot).
8. **The menu is part of the game world.** Teardown's computer, Superhot's OS, Persona's ransom-note type, which was "impossible to read at first" until "lots of tweaking" ([S](https://kotaku.com/-metaphor-refantazio-persona-5-menu-ui-hashino-1851667088)). Legibility first, one accent colour (Persona used no sub-colours outside HP/MP, per CEDEC 2017 coverage, [S](https://www.playstationlifestyle.net/?p=615973)).
9. **Teach in the level, with a fallback.** Lara Croft GO, Goose, 99 Nights and DOORS teach without text. The fallback is a hint ladder (MASTERPLAN 7.5 has this).
10. **A replay shows the player their own skill.** Superhot's real-time replay. Our Reel is the strongest version of this in the genre.
11. **A recognisable 1-second signature**: silhouette plus motion plus colour. Viewers skip to gameplay ([S](https://newsletter.gamediscover.co/p/how-to-get-to-your-games-hook-quick)) and decide "within 45 seconds" ([S](https://newsletter.gamediscover.co/p/the-perfect-steam-trailer-overlooked)).
12. **Forgiveness is hidden in the controls.** Celeste's coyote time, jump buffering, corner correction, and wall jumps from 2 px away ([S](https://www.gamespot.com/articles/celeste-dev-explains-how-they-made-their-game-feel/1100-6474775/)). For us: a plate should count a foot slightly outside its ring and an early GRAB tap should buffer briefly (values in `Config`, decided in the sim so clones and players match).

---

## 4. The premium bar: 60 testable criteria

Each item can be tested in a capture, a stopwatch test, a script or a 5-person playtest. "Phone" means the 360-dp Android in landscape from MASTERPLAN 7.4, at graphics quality 1-3 unless stated. **Owner** is who checks it: **C** = Claude in code or headless tests, **O** = the owner on a device, **P** = a playtest.

### A. Frame and readability

| # | Criterion | Test | Owner |
|---|---|---|---|
| A1 | In a greyscale screenshot of any gameplay frame, players, clones, Gus, loot and danger each differ from their ground by ≥ 15% value | Desaturate the 4 bookmark shots (STYLE_BIBLE §7), sample with a picker | C/O |
| A2 | A 64 px thumbnail of the busiest view answers "which ones are past me?" in ≤ 0.5 s for 4 of 5 testers | Show for 0.5 s, ask | P |
| A3 | Every frame has at most **one** element at 100% saturation that is not a clone, loot or danger | Screenshot audit | O |
| A4 | Nothing in the environment glows (STYLE_BIBLE rule 5). Glow pixels belong to clones, signals or runtime-tinted parts only | Bloom-only capture | O |
| A5 | Gameplay reads with shadows off: same pass/fail on A1-A2 at quality 1 | Phone capture | O |
| A6 | **Minimum on-screen size** at default zoom (16 studs) on the phone: Gus ≥ 48 px tall, loot ≥ 20 px, a plate ring ≥ 36 px wide, a clone badge ≥ 28 px (the Monaco 2 Steam Deck lesson) | Measure in the capture | O |
| A7 | Each room has exactly one focal light pool and one storytelling prop (STYLE_BIBLE §5) | Level review | O |
| A8 | No two meanings share colour **and** shape: Oklab ≥ 0.15 for signals, ≥ 0.20 plus a shape for danger | `eh_palette.py` CI | C |

### B. Lighting and VFX

| # | Criterion | Test | Owner |
|---|---|---|---|
| B1 | Every VFX has an ink layer, a body, a white-hot core and ≤ 1 accent hue ([V] *VFX Readability and Value*) | Frame-step the effect | O |
| B2 | ≤ 3 full-screen flashes per second, always (Comfort) | Script counter in the Flash module | C |
| B3 | Every effect has a low-tier substitute rather than being deleted (blur → 2-frame Frame at 0.85; confetti → UIGradient shine; [V] *Juice on a Budget* §5) | Juice governor table has a row per effect | C |
| B4 | Only the top two reward tiers dim the world: the diamond (15%, 0.6 s) and Heist Complete | Grep the code for world-dim calls | C |
| B5 | Lasers and cones show their **next state** ≥ 0.5 s before it happens (3 flickers before re-arm; cone sweep preview) | Capture | O |
| B6 | Particle budget ≤ 360 live on touch, and no emitter is created per event (emit only) | MicroProfiler and pool check | C |

### C. Animation and acting

| # | Criterion | Test | Owner |
|---|---|---|---|
| C1 | Every state change of a character has an **anticipation of ≥ 2 frames at 30 fps (≥ 66 ms)** before the main move: Gus turns, clone forms, door opens | Frame-step | O |
| C2 | Every landing or stop has a settle: squash 0.9 / stretch 1.08 recovering in 0.12-0.2 s, pivot at the feet (rigid parts: a root dip of 0.08-0.12 studs) | Frame-step | O |
| C3 | Gus has ≥ 6 readable acting beats at 64 px: idle (donut), patrol, "?" double-take, "!" point, chase, confused "WRONG ONE" | Turntable or screen recording, owner daily slot | O |
| C4 | Characters **look** before they act: Gus's head leads his body by 0.15-0.25 s on turns; clones face their next target 0.2 s before grabbing (Goose IK) | Capture | O |
| C5 | Secondary motion on at least 2 elements per character: Gus's torch beam sway and moustache bounce; the clone's 0.5 s owner-hue trail | Capture | O |
| C6 | Failure states are funnier than success: each of Bonk, Zap, Busted and Shrug has a distinct silhouette in its first 0.3 s | 4-panel contact sheet | O |
| C7 | No foot sliding ≥ 0.3 studs per stride on clones at replay speed 1x and 3x | Headless replay plus a capture | C/O |

### D. UI, typography and motion

| # | Criterion | Test | Owner |
|---|---|---|---|
| D1 | **Two font families at most** ([V] *Text Fonts and Rich Text*): Builder Sans for UI, plus one display face for stamps and titles. The tape counter uses fixed-width digit slots (one TextLabel per digit) so digits never jitter | Grep FontFace uses | C |
| D2 | A written **type scale** with ≤ 5 sizes (e.g. 14 / 18 / 24 / 36 / 64 at 720×330 design size), with no text below 14 px on the phone | Theme module and 7-viewport test | C |
| D3 | **Button press:** the art layer goes to 0.92 instantly (or ≤ 60 ms), then on release overshoots to 1.04 and settles to 1.0 in 0.2-0.3 s (Back Out or a spring at ζ≈0.5). The label pops ≤ 1.03 and is never squashed ([V] *Squash Stretch* §2) | Frame capture of every button type | C/O |
| D4 | Motion tokens only: Enter 0.18-0.30 s Out/Back Out; Exit 0.10-0.18 s Quad In (never Back In); Feedback 0.06-0.12 s; Emphasis 0.25-0.45 s ([V] *UI Motion Language*). No raw `TweenInfo` outside the motion module | Grep `TweenInfo.new` outside it | C |
| D5 | Lists stagger at 0.03-0.07 s per item with a 0.4 s cap | Results card and Clone Deck capture | C |
| D6 | Input is accepted on the first visible frame of any panel; exit is 0.55-0.75× the enter time | Tap-through test | C/P |
| D7 | Every HUD element shows a meaningful state change by **motion** as well as colour (pulse, slide, stamp), and keeps a colour-only version under reduced motion | Reduced-motion run | C/O |
| D8 | Icons share one grid and one stroke weight: a 24 px grid, 2.5 px stroke at design size, rounded caps; each glyph (●■▲◆, ✕, ⚡, ↻) reads at 16 px | Icon sheet at 1x | O |
| D9 | Tap targets ≥ 48 px with ≥ 8 px gaps; END RUN 72 px; nothing interactive in the inset area | 7-viewport test | C |
| D10 | Numbers that change **count** (Quad Out, 0.35-1.0 s, text updates at 10-30 Hz) and end on a 1.0 → 1.15 → 1.0 pop | Capture | C |
| D11 | **One UI skin**: one corner radius (e.g. 10 px at design size), one stroke (2 px ink `#1C1F3B`), one drop shadow; no default Roblox grey anywhere | Screenshot every panel side by side | O |
| D12 | Every panel has an empty state, a loading state (skeleton or anticipation, never blank) and an error state | Kill the network in Studio | C |

### E. Audio

| # | Criterion | Test | Owner |
|---|---|---|---|
| E1 | Every input sounds within 100 ms, and the sound is never ahead of the picture; same-frame starts for local actions | Record screen and audio, frame-count | C/O |
| E2 | **The meaning-to-sound table:** each reserved meaning (clone, loot, danger, exit, Gus, mechanism) owns a timbre family, and no sound is used for two meanings | `Audio/Cues.luau` review | C |
| E3 | UI sounds follow a hierarchy: hover/scroll near-silent or none, tap soft, confirm present, reward loud ([S](https://www.audiokinetic.com/en/blog/approaching-ui-audio-ui-design-perspective-1)) | Listen-through of all panels | O |
| E4 | ≥ 3 variations or ±5% pitch randomisation on anything that repeats more than once per 10 s | Manifest check (lihfolk-sfx) | C |
| E5 | Every danger has a pre-warning sound ≥ 0.5 s ahead (laser re-arm whine, Gus "?" heartbeat) | Capture | O |
| E6 | The world muffles (low-pass about 800 Hz) during rewind, planning and menus over a running heist | Listen | O |
| E7 | Loudness: music −18 LUFS short-term, SFX peaks about 6 dB over music, warnings never ducked below 25% | Meter on a recording | O |

### F. Feedback and juice

| # | Criterion | Test | Owner |
|---|---|---|---|
| F1 | **Every interactable has 3 feedback channels on use**: visual (state change plus effect), audio, motion (a squash, a sink or a shake). Phones add haptics on the 3 key verbs (plate, grab, bank) | Interactable matrix | C/O |
| F2 | Every interactable has an **idle affordance** visible from ≥ 12 studs: a pulse, a glint or a tinkle (Sly) | Capture | O |
| F3 | Hit-stop only on the 4 heavy beats (rewind start, busted, diamond, heist complete), each ≥ 66 ms, never on routine actions | Grep the freeze calls | C |
| F4 | Camera shake: off by default except on the Alarm trigger, scaled by the shake slider, never rolling | Comfort test | C |
| F5 | Every reward has the four beats (anticipation, reveal, payoff, settle), and the button appears last with a 0.3 s guard ([V] *Reward Moments*) | Capture | O |
| F6 | Reward animation stays < 10% of play time across a 10-minute session | Analytics timer | C |
| F7 | Floating numbers merge within 0.55 s; ≤ 12 on screen (6 on low tier) | Stress test with 12 clone banks | C |

### G. Onboarding and first 60 seconds

| # | Criterion | Test | Owner |
|---|---|---|---|
| G1 | Control within 10 s of the first frame; first clone ≤ 30 s; first bank ≤ 45 s; ≤ 30 words (MASTERPLAN 7.5) | Funnel and stopwatch | C/P |
| G2 | The first 5 actions get extra care: first step, first plate press, first rewind, first clone and first bank each have a unique, slightly bigger feedback than later repeats | Capture | O |
| G3 | The store description teaches the 3 verbs in ≤ 3 lines (the Fisch pattern) | Read the page | O |
| G4 | Every failure shows **one sentence of counterplay** keyed by cause, within 1 s (the DOORS pattern) | Trigger each cause | C |
| G5 | No modal, offer or shop before L1Complete | Funnel run | C |

### H. Camera and presentation

| # | Criterion | Test | Owner |
|---|---|---|---|
| H1 | No camera cut or FOV change without a motivated ease (≥ 0.2 s Sine InOut), except the rewind snap | Capture | O |
| H2 | Walls between the camera and the player fade within 0.1 s; the player is never fully occluded for > 0.3 s | Walk test | C/O |
| H3 | The end-of-heist cut keeps its subject in the central 32% of frame width (9:16-safe) with the HUD hidden | Crop test | C |
| H4 | Every transition between game states (garage → heist → results → garage) has an authored in/out of ≤ 0.6 s, with no pop to black | Capture | O |

### I. Identity, robustness and performance

| # | Criterion | Test | Owner |
|---|---|---|---|
| I1 | A sound-off, 1-second clip from any heist is recognisably ours (clone glow plus badge plus diorama) for 4 of 5 testers who saw the icon once | Clip test | P |
| I2 | The 16.6 ms frame budget holds in the busiest view on the mid Android (MASTERPLAN 6.8) | Bench | O |
| I3 | No visible placeholder ships: no grey default parts, no "Label" text, no Studio default sky | Script scan for default names and colours | C |
| I4 | No UI or effect waits on the server to start its first frame: the latency-mask pattern on every remote-driven animation ([V] *Squash Stretch* §6) | Throttle to 250 ms and press everything | C/O |

**60 criteria.** Gate: before the Nov 30 launch gate, **all of A, F1-F3, G and I4 pass**, plus ≥ 80% of the rest. Each failure becomes a PROJECT_STATE line.

---

## 5. The 10 biggest gaps of a typical Roblox MVP

From the vault teardowns, the v0.1 code (visuals.md F7, feel.md F5) and the bar above.

1. **Default UI skin.** Stock fonts, stock grey frames, `TextScaled` everywhere, no type scale, tweens written inline at random durations. *Premium games have a motion and type system.* Fix: D1-D4, D11.
2. **Feedback on one channel.** A part changes colour, and nothing sounds or moves. Fix: F1 matrix.
3. **Nothing is telegraphed.** Hazards switch on and off in one frame and guards turn instantly, so failure feels random. Fix: B5, C1, E5.
4. **Walk cycles but no acting.** Characters slide or play the default walk, with no reactions. The comedy in our premise depends on reactions. Fix: C3, C6.
5. **Effects with no hierarchy.** Neon everywhere, glow on decoration, flashes on routine pickups, the same "pop" for $10 and the diamond. Fix: A3-A4, B4, F3.
6. **Audio added last.** Free-model sounds, no buses, no variation, sounds that arrive late through a server round trip. Fix: E1-E7.
7. **Text tutorials.** Walls of text, arrows to everything, an offer popup at 30 s. Fix: G1-G5.
8. **No presentation layer between states.** Teleports, black cuts and abrupt menus; the results screen is a TextLabel. Fix: H4, F5, and the results card (section 6.6).
9. **Readability tested only on PC.** Gameplay objects become 6 px specks on a phone (the Monaco 2 Deck lesson, now at phone scale). Fix: A5-A6, D9.
10. **Server-gated feel.** The button waits for the server, so the game feels laggy at 150 ms ping. Fix: I4, and the local clack in MASTERPLAN 7.1.

**For us now** (PROJECT_STATE): gaps 1, 2, 4, 6 and 8 are open in v0.1 (one 268-line `init.client.luau` with no motion or theme module; a guard that "probably slides"). Gaps 3, 5, 7 and 9 are planned in MASTERPLAN 6-7 but not built.

---

## 6. How the techniques map onto Heist Yourself

Each item names the source game, then the concrete spec. Items already decided in MASTERPLAN are only referenced; what follows is new or sharper.

### 6.1 Clones

- **Wind-up toy fiction for cheap motion (Hitman GO).** Where the replay has to hold a pose (end of path, waiting on a plate), clones do a 1.5 s **idle "tick"**: a 2° sway at 0.66 Hz plus a tiny tape-flutter flicker (Transparency ±0.05). It reads as "paused tape", not "frozen bug".
- **Look-ahead head turn (Untitled Goose Game IK).** The recording knows the next event, so for 0.25 s before a grab or press the clone's Neck rotates toward the target (≤ 45° yaw). Client pose layer only; no sim state.
- **Sneak walk (Sly Cooper).** If a recorded actor's speed is < 60% of WalkSpeed within 20 studs of Gus, play the sneak variant (a lower root, 1.3x knee lift, arms back) for players and clones alike. Cost: a 4th authored clip (MASTERPLAN 6.7 budgets 3) [OPEN, owner].
- **Afterimages on the newest clone's spawn (Ruiner).** At "tape print", 3 ghost copies trail 60 ms apart, at 0.6/0.4/0.2 alpha, owner hue, for 0.3 s. Only when pooled rigs are free; otherwise the scanline sweep alone.
- **Comedy verb (Goose's honk).** A **whistle** chip (PC: V; unlocked after L1, per the one-verb-per-button rule in MASTERPLAN 3.4) plays a 2-note whistle and a head-tilt, is recorded as an `emote` event (MASTERPLAN 3.2 #1) and is replayed by the clones. Eight copies whistling in sequence is a clip. No gameplay effect at launch.
- **Failure acting (Overcooked, Goose NPCs).** C6 contact sheet: Bonk = flatten to 0.6 height in 50 ms, then a 3-bounce recovery and stars; Zap = an instant silhouette change (hair-up spikes, ink body flash for 2 frames), then the flop; Busted = a freeze, then a vertical glitch-slice and ribbons; Shrug = a palms-out pose held 0.6 s. Each must be readable in its first 0.3 s at 64 px.

### 6.2 The Rewind

MASTERPLAN 7.1 is already at the premium bar on picture and sound. Additions:

- **Muffle first (Superhot).** In the first 0.1 s, an `AudioFilter` low-pass on the SFX bus sweeps 20 kHz → 800 Hz together with the tape-stop. The music already dives (E6).
- **Run bar rewinds visibly.** The playhead on the top-centre run bar slides back to 0 in sync with the path reel (Quad InOut, 1.2 s), and the event icons flip into their "recorded" style (filled → outlined in owner hue). The HUD tells the same story as the world.
- **Haptics.** A 3-pulse "tape stop" on supporting phones (`HapticEffect`, feel.md F2): 40 ms at 0.6, 40 ms at 0.4, 80 ms at 0.25, spaced 60 ms. Off under reduced motion.

### 6.3 Gus

- **Telegraph the patrol (Lara Croft GO).** Gus's patrol is `patrol(t)` (pure, Sim/Guards). Draw his **next 2 s of path as 4 fading boot-print decals**, updated at 10 Hz on the client. Colour by value contrast, not hue: `marble_hi` on dark floors, ink on lit pools; **never Torch Amber**, which is reserved for cones (MASTERPLAN 6.2), and run it through the P1 palette check. This is the single highest-value readability add. Toggle in Comfort ("Show guard path", default on for L1-L4, off in Big Scores for challenge) [OPEN, design].
- **Head leads body (C4).** On every patrol turn, Gus_Head rotates 0.2 s before the torso; the torch beam sways ±4° at 0.5 Hz while walking.
- **Six acting beats (C3, Sly's guards).** The double-take at "?" is the key one: head snaps 30° toward the stimulus in 2 frames, holds 0.3 s, then the body follows with a 0.95 → 1.03 vertical squash on the rigid root. Use the "WRONG ONE" confused shrug when he busts a clone (MASTERPLAN 3.2 #2).
- **Donut storytelling (Goose's NPC routines).** In L1-L2 Gus's idle is eating from the donut box (STYLE_BIBLE §5's storytelling prop). A clone stealing the donut is a cosmetic Easter egg and a clip.
- **Sound signature (Pressure, DOORS).** Gus has a jingling key ring audible at 30 studs, a footstep timbre, and a 2-note "hm?" at "?". "You hear his keys, so hide": tune the audible distance so an instant reaction escapes the cone (Pressure rule).

### 6.4 Plates, doors and lasers

- **The 3-channel matrix (F1).** Most of this is decided in MASTERPLAN 7.3; this makes it testable:

| Object | Idle affordance (F2) | Visual on use | Audio on use | Motion on use | Haptic |
|---|---|---|---|---|---|
| Plate | Steel ring breathes 0.9 → 1.0 brightness at 0.5 Hz; cable pulses toward the device every 2 s | Rim takes the presser's hue and glyph; cable pulse | Heavy "clunk", then a cable "zip" | Sinks 0.15 studs in 0.06 s; release overshoot +0.03 | 1 pulse 30 ms |
| Vault door | Lamp red with a slow blink | Lamp → green; amber blink while closing | Servo whirr plus a bolt "chunk" at full open | 0.35 s slide, 40 ms anticipation pull-back of 0.05 studs | — |
| Laser | Hum; floor dot shimmer | Retract with sparks; **re-arm preview: 3 flickers plus a rising whine 0.6 s before** | Power-down "vwoom"; re-arm whine | Emitter head nods 5° on toggle | — |
| Loot | Heist Gold sparkle every 1.2 s plus a proximity tinkle at ≤ 10 studs (Sly's clue bottles) | Item flies into the backpack slot | "Ching" with 3 variations | Pop 1.0 → 1.2 → 0 in 0.18 s | 1 pulse 20 ms |
| Van (bank) | Rear door ajar with an interior warm light | Coin burst; "+$100" flies to the meter | Ka-ching | Van rocks 1.5° on its suspension | 2 pulses |

- **Next-event markers (The Sexy Brutale's stopwatch).** The run bar (MASTERPLAN 7.4 #1) also shows **world events**: Gus's turn points as small amber ticks and laser cycles as red segments. The kid sees "laser off from 0:31 to 0:36" before committing a clone. All of it comes from deterministic data.
- **Mechanism "toy" sounds (Hitman GO).** Plates and doors use **material** sounds (steel, rubber, brass), not synth bleeps, so the diorama sounds like a model kit. Brief this for the licensed SFX pick (~38 sounds, MASTERPLAN 7.2).

### 6.5 Garage (lobby)

- **The van is the train (Dead Rails).** The van is the menu: the tape shelf is level select (MASTERPLAN 7.4), the trophy shelf is progress, the rear door is "start heist", and a **CRT in the van** shows the job card (Teardown's diegetic computer). Phones also get a 2D panel from the same buttons.
- **Two taps to a heist (Grow a Garden).** From spawn: tap "▶ Next job" (always the next unlocked level, pre-selected), then the run starts.
- **Idle life.** Your Mentor-tape line-up loops (MASTERPLAN 6.6). Add **ambient garage sound** (a radio playing the theme lo-fi, rain on the roof) so the lobby is never silent: silence reads as "loading".
- **Typography in the world.** Tape labels and job cards use the display face in TextLabels (localisable, feel.md D6), with a slight random rotation of ±2° so they look hand-placed.

### 6.6 Results card

- **Job sheet with pencil strikes (Goose's to-do list plus Overcooked's star stamps).** Before the heist, the van CRT shows the sheet: "Haul $1,000 · Crew ≤ 4 clones · Clean (no busts)", each with its medal outline. On results, each line gets a **pencil strike-through** (0.25 s, Quad Out, a scribble sound) and then its medal stamps in (UIScale 1.4 → 1.0 Back Out 0.25 s, a stamp "thunk", 0.25 s apart; MASTERPLAN 7.3 already sets the 0.25 s spacing). A missed medal shows an outline plus a one-line hint ("Try with 3 clones").
- **Count-up rules (D10).** Haul counts up with Quad Out over 0.35-1.0 s, scaled by log10 of the value; the text updates at 30 Hz on PC and 10 Hz on the low tier; it ends on a 1.15 pop plus a "ka-ching" on the final digit.
- **Buttons last.** Replay / Next / Save Clip appear after the last stamp and become clickable 0.3 s later (F5). "Next" is the primary button (filled), the others are outlined.
- **One sentence of counterplay (DOORS)** on failed runs or busts: "Gus saw clone ●3 at 0:24. Try the shadow." Keyed by cause from the blooper log.

### 6.7 Crew Line-up and the busted shelf

- **Captured pieces beside the board (Hitman GO).** In the Line-up, busted clones are not hidden. They stand **apart, on a small "busted" podium in Tape Grey, slumped**, and each does a sheepish shrug on the beat. Failure joins the payoff photo (MASTERPLAN 6.6's blooper culture).
- **Synchronised pose with a stagger (MASTERPLAN 3.2 #8) plus a drumroll.** A 0.6 s snare roll during the 60 ms stagger, landing on the pose with the arpeggio's top note. Sound and picture peak on the same frame ([V] *Reward Moments*).
- **Camera.** A slow 0.35x dolly-in (H1), the subject inside the central 32% for 9:16 (H3; the open framing item in MASTERPLAN 6.6 is still the owner's call).

### 6.8 HUD

- **Run bar as Overcooked ticket.** It drains like an Overcooked ticket (pulse at 10 s, Alarm Red with a ring at 5 s, MASTERPLAN 7.4). New: a **tiny shake (±2 px, 12 Hz)** in the last 3 s, which is off under reduced motion.
- **Doc inconsistency to fix:** MASTERPLAN §3.4 places END RUN "at ~45% height", while §7.4 says ~35% (`END_RUN_Y`) because 45% "left it too close to the jump button". §3.4 should be updated to 35%.

---

## 7. What to build first (ordered by premium per hour)

1. **Motion and theme module** (D1-D4, D11): one `UiMotion` plus one `UiTheme` in `src/client`, with tokens in `Config.Ui`. Every later UI item depends on it. About 1 day.
2. **Interactable feedback matrix** (F1-F2, section 6.4 table) as data in Config, played by one client `Feedback` module from the event log. About 1-2 days.
3. **Gus telegraph** (footprints, head-lead, keys sound; section 6.3). About 1 day, all client-side from `patrol(t)`.
4. **Results job sheet** (section 6.6). About 1 day.
5. **Clone look-ahead and idle tick** (section 6.1). About 0.5 day.
6. **Checklist runner**: script the C-owned checks (A8, B2, D1, D4, E4, F3, I3) into CI as a `premium_check.luau`. About 0.5 day.

---

## Sources

**Steam games**
- Monaco 2: [Aftermath interview](https://aftermath.site/monaco-2-demo-interview/), [Game Informer preview](https://www.gameinformer.com/preview/2024/07/04/sneaking-in-a-new-dimension), [GamesCreed review](https://www.gamescreed.com/reviews/monaco-2-review), [GameGrin review](https://www.gamegrin.com/reviews/monaco-2-review), [Steam Deck HQ review](https://steamdeckhq.com/ja/game-reviews/monaco-2/), [GamesBeat Monaco review](https://gamesbeat.com/monaco-review/), [Shacknews GDC 2024](https://shacknews.com/article/139427/monaco-2-gdc-2024-preview)
- Hitman GO: [Game Developer](https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense), [GDC Vault "Design by Constraints"](https://gdcvault.com/play/1021908/Design-by-Constraints-Hitman-GO), [Postmortem video](https://gamedeveloper.com/design/video-the-i-hitman-go-i-design-postmortem), [CGM review](https://www.cgmagonline.com/review/hitman-go-definitive-edition-ps4-review/), [PlayStation LifeStyle review](https://www.playstationlifestyle.net/2016/02/23/hitman-go-review-relaxing-assassinations-ps4/)
- Lara Croft GO: [Wikipedia](https://en.wikipedia.org/wiki/Lara_Croft_Go), [PocketGamer.biz interview](https://www.pocketgamer.biz/interview/75079/square-enix-montral-design-team-on-crafting-beautiful-gaming-experiences-for-small-screens/), [Game Developer postmortem](https://gamedeveloper.com/design/-i-lara-croft-go-i-dev-remake-how-you-felt-playing-a-classic-game-not-the-game-itself), [GamesBeat](https://gamesbeat.com/lara-croft-go-developer-on-turning-an-action-blockbuster-into-a-turn-based-mobile-game/), [Kill Screen](https://www.killscreen.com/lara-croft-go-reminds-us-lara-sometimes-raids-tombs/), [itch.io developer comment](https://itch.io/post/6262506)
- Sly Cooper: [Wikipedia](https://en.wikipedia.org/wiki/Sly_Cooper_and_the_Thievius_Raccoonus), [Game Informer retrospective](https://gameinformer.com/b/features/archive/2017/10/21/celebrating-15-years-of-sly-cooper-sonys-most-stylish-mascot.aspx), [Clue bottle wiki](https://slycooper.fandom.com/wiki/Clue_bottle)
- Untitled Goose Game: [Wikipedia](https://en.wikipedia.org/wiki/Untitled_Goose_Game), [FMOD interview](https://fmod.com/blog/untitled-goose-game-interview), [Road to the IGF](https://www.gamedeveloper.com/game-platforms/road-to-the-igf-house-house-s-i-untitled-goose-game-i-), [Nintendo Life on Mario 64](https://www.nintendolife.com/news/2019/09/random_3d_movement_in_untitled_goose_game_was_inspired_by_super_mario_64), [Nintendo Life to-do guide](https://www.nintendolife.com/news/2020/05/guide_untitled_goose_game_walkthrough_-_puzzle_solutions_and_to-do_list_objectives)
- Superhot: [Backer update "making a black and white game pop"](https://www.reddit.com/r/SUPERHOTbackers/comments/2tfaxd/friday_update_8_making_a_black_and_white_game_pop/), [The Sound Architect](https://www.thesoundarchitect.co.uk/superhot/), [bit-tech review](https://bit-tech.net/reviews/gaming/superhotsuperhotsuperhot/2/), [GamesRadar review](https://www.gamesradar.com/superhot-review/)
- Teardown: [TechRadar](https://www.techradar.com/gaming/consoles-pc/ray-tracing-is-so-crucial-to-teardown-that-the-world-goes-black-if-you-turn-it-off), [80.lv](https://80.lv/articles/teardown-developer-breaks-down-multiplayer-and-voxel-destruction-tech), [acko.net frame teardown](https://acko.net/blog/teardown-frame-teardown/), [Heist basics](https://get-teardown.readthedocs.io/en/latest/gameplay/heist-basics.html)
- Ruiner: [Laced Records interview](https://www.lacedrecords.com/blogs/blog/seeing-red-ruiner-s-creative-director-on-how-style-can-precede-substance), [PC Games Insider](https://www.pcgamesinsider.biz/indie-interview/66175/hotline-miami-akira-and-polish-history-reikon-tells-us-about-cyberpunk-action-game-ruiner/), [CGM review](https://www.cgmagonline.com/review/ruiner-pc-review/)
- The Sexy Brutale: [Wikipedia](https://en.wikipedia.org/wiki/The_Sexy_Brutale), [PCGamesN preview](https://www.pcgamesn.com/the-sexy-brutale/the-sexy-brutale-preview), [GameGrin review](https://gamegrin.com/reviews/the-sexy-brutale-review)
- Overcooked: [Wikipedia](https://en.wikipedia.org/wiki/Overcooked), [Cane and Rinse interview](https://caneandrinse.com/ghost-town-games/), [Road to the IGF](https://gamedeveloper.com/design/road-to-the-igf-ghost-town-games-i-overcooked-i-), [UX of Overcooked](https://uxdesign.cc/the-ux-of-overcooked-from-umami-to-unexpected-design-principles-56e9ea146f7e)

**Roblox games**
- [Roblox newsroom: fidelity creator interviews (Jul 2026)](https://about.roblox.com/newsroom/2026/07/roblox-studio-fidelity-creator-interviews-twin-atlas-fluorlite-maximillian-ecos), [PocketGamer.biz: Frontlines](https://www.pocketgamer.biz/interview/81103/maximilian-studios-on-the-success-of-frontlines-you-dont-need-a-3000-rig-or-a-500-console-you-can-boot-it-up-on-your-mobile-device/), [GamesBeat: Twin Atlas](https://gamesbeat.com/twin-atlas-is-among-the-studios-changing-what-roblox-games-look-like-exclusive-interview/)
- [GameAnalytics: Dead Rails](https://gameanalytics.com/blog/dead-rails-and-the-hit-makers-formula), [PC Gamer: 99 Nights](https://www.pcgamer.com/games/survival-crafting/with-a-peak-player-count-of-14-2-million-99-nights-in-the-forest-has-an-audience-other-multiplayer-games-would-kill-for-to-find-these-behemoth-playerbases-you-need-to-be-on-a-platform-like-roblox/), [PC Gamer: Grow a Garden](https://www.pcgamer.com/games/survival-crafting/i-played-the-roblox-hit-thats-pulled-in-10-billion-visits-and-while-im-not-sold-on-it-i-can-see-how-its-cultivated-a-mass-following), [Grow a Garden monetisation](https://www.metaversemarcom.io/post/inside-the-monetization-playbook-of-roblox-s-biggest-hit), [VGC: Fisch](https://videogameschronicle.com/guide/fisch-fishing-tips), [RoTrends: DONT SPLASH](https://www.rotrends.com/game/10771421858/DONT-SPLASH), [RoWatcher: DONT SPLASH](https://rowatcher.com/games/10771421858/dont-splash), [RoWatcher: Pressure](https://rowatcher.com/games/4367208330/pressure), [Endsights: horror design](https://endsights.com/horror-game-design), [Roblox UI appearance modifiers](https://create.roblox.com/docs/ui/appearance-modifiers)

**Craft and feel**
- [Nielsen: response times](https://www.nngroup.com/articles/website-response-times/), [Capcom: hit stop](https://game.capcom.com/cfn/sfv/column/131545?lang=en), [GameSpot: Celeste tricks](https://www.gamespot.com/articles/celeste-dev-explains-how-they-made-their-game-feel/1100-6474775/), [Game Developer: Vlambeer advice](https://gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games), [AV Club: Balatro](https://www.avclub.com/balatro-hones-the-art-of-making-numbers-go-up), [Kotaku: Persona menus](https://kotaku.com/-metaphor-refantazio-persona-5-menu-ui-hashino-1851667088), [Audiokinetic: UI audio](https://www.audiokinetic.com/en/blog/approaching-ui-audio-ui-design-perspective-1), [GDC: Civilization VII UI sound](https://schedule.gdconf.com/session/civilization-vii-impactful-ui-sound-design-at-scale/915690), [GameDiscoverCo: hook](https://newsletter.gamediscover.co/p/how-to-get-to-your-games-hook-quick), [GameDiscoverCo: trailer](https://newsletter.gamediscover.co/p/the-perfect-steam-trailer-overlooked)

**LihFolk vault notes:** *Teardown - Pressure*, *Case Study - Doors*, *Case Study - Dead Rails*, *Case Study - 99 Nights in the Forest*, *Case Study - Grow a Garden*, *Case Study - Fisch*, *What Craft Looks Like on Roblox*, *UI Motion Language and Timing*, *Squash Stretch and Anticipation in UI and Characters*, *Feedback Timing - Sound Visual and Haptic Sync*, *Juice on a Budget - Mobile and Low-End*, *Reward Moments and Celebrations*, *Hit-Stop and Screen Shake Tuning by Numbers*, *Text Fonts and Rich Text*, *VFX Readability and Value*.
