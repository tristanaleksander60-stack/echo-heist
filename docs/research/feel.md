# Echo Heist: Game Feel, Audio, VFX, UI/UX and Onboarding (premium polish layer)

_Research dimension: polish. Written 2026-11-12. Grounded in prototype v0.1 (`src/`), the sibling reports `docs/research/design.md` and `docs/research/visuals.md`, the LihFolk Vault V2 and web research. Facts carry a citation; everything written as "Decision" or "Recommendation" is my call. Unverified claims are marked [UNVERIFIED]._

## Summary

Echo Heist already has the one idea that sells itself: your past selves are your crew. What separates a "Roblox prototype" from a "Steam-looking indie" is not more content. It is three things: **every action answers in under 100 ms with sight and sound**, **one signature moment (the Rewind) that is so satisfying people clip it**, and **almost no text**. This report turns that into a spec.

The six decisions that matter most:

1. **The Rewind is the brand.** A 2.5 s client-side sequence: tape-stop on the music, a VHS "◀◀" on-screen display, the world playing backwards at 25-45x (from `visuals.md`), a reverse-cymbal swell that lands exactly on "LOOP 3" and a 3-2-1-GO on the musical downbeat. A reduced-motion version runs in 0.8 s.
2. **"The music is the clock."** All loops are whole bars at **128 BPM**: 30 s is 16 bars, 45 s is 24, 60 s is 32 and 75 s is 40. The music restarts on every GO, the last 4 bars carry the countdown, and the rewind always lands on a bar line.
3. **"Crew Layers" adaptive music.** One song per location, split into 6 synchronised stems. Each new echo in the server adds one stem, so the band literally grows with your crew. The 8-copies clip comes with its own crescendo. The idea is feasible (the vault documents sample-aligned `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()`), but it **needs commissioned music**, because Roblox's licensed library ships full mixes, not stems. Launch fallback: licensed tracks in 3 intensity variants.
4. **The echo-spawn arpeggio.** Each echo forms 60 ms after the previous one with a chime pitched one step up a pentatonic scale. Eight echoes make an 8-note run, which is an audio logo you can hear in any clip.
5. **A HUD with 4 elements and a 30-word tutorial.** The HUD has a timeline bar, a loot meter, an echo deck pip row and one thumb cluster. The first two minutes of onboarding use no more than 30 words of on-screen text in total. Plates, beams and the echo itself do the teaching.
6. **Accessibility is designed in, not added later.** Echo identity uses colour **plus** number **plus** shape. Information-bearing sounds are captioned. The game follows `GuiService.ReducedMotionEnabled` and `PreferredTransparency`, has a flash limiter, offers an optional "Relaxed Time" assist (Teardown precedent) and is localization-ready from day one.

Launch scope ("must-have") is roughly 70% of this spec. Commissioned stems, the corkboard hideout, haptics and the streamer-mode music swap come after the soft launch.

## Findings (with citations)

### F1. What "great feel" looks like in the reference games

| Game | Fact (cited) | Lesson for Echo Heist |
|---|---|---|
| Superhot | Movement is "choreography": "even your tiniest move matters" (Iwanicki, GDC 2016, [Kill Screen](https://www.killscreen.com/superhot-wants-get-inside-your-brain-and-change-how-you-think/); [GDC Vault](https://gdcvault.com/play/1023483/Game-Design-and-Mind-Control)) | Every input will be replayed, so every input must feel meaningful |
| Hitman GO | Anything that can't be used is "inert, part of the scenery" ([Game Developer](https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense)); white space, colour only for important differences, almost no text ([Gamezebo](https://www.gamezebo.com/reviews/hitman-go-review/)) | Keep saturated colour for things that matter (the reserved echo hues in `visuals.md` D2) |
| Monaco | Almost entirely solo piano in a ragtime and silent-film style, changed over the game ([Classical MPR](https://www.classicalmpr.org/story/2013/05/31/austin-wintory-and-monaco-whats-yours-is-mine-on-top-score); [OSV](https://www.originalsoundversion.com/monaco-whats-yours-is-mine-review/)) | One instrument family in one strong "caper" genre gives instant identity |
| Payday 2 | Heist tracks have four phases: stealth, control, anticipation and assault ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/AwesomeMusic/PAYDAY2); [Superjump](https://superjumpmagazine.com/payday-2-so-much-more-than-heists)); the trigger logic is undocumented [UNVERIFIED] | Music should escalate with the state of the job |
| Untitled Goose Game | "Reactive music": Debussy recorded in high and low energy takes, cut into stems (the longest is 478 ms) and chosen by player actions ([Wikipedia](https://en.wikipedia.org/wiki/Untitled_Goose_Game); [Mixdown](https://mixdownmag.com.au/features/dan-golding-untitled-goose-game/)) | Music that reacts to comedy actions multiplies the comedy |
| Braid | Music chosen to "work well with the rewind" ([GameSpot](https://www.gamespot.com/articles/spot-on-the-music-of-braid/1100-6197644/)); rewind plays back fast "like a VCR" ([GDC Vault](https://gdcvault.com/play/1012210/contactUs)); one reviewer found the 2024 remaster's rewind screech "too loud" ([MP1st](https://mp1st.com/reviews/braid-anniversary-edition-review-revisiting-the-past)) | The rewind sound must be sweet, not shrill, and ducked |
| Teardown | A 60 s alarm timer is the core of each heist; "nobody likes a timer" ([Voxagon](https://blog.voxagon.se/2020/11/05/teardown-design-notes.html)); an accessibility option extends it ([wiki](https://get-teardown.readthedocs.io/en/latest/gameplay/heist-basics.html)) | Timers make tension, so offer a timer assist |
| Balatro | Several feedback channels on every score event, numbers rolling up over about 300 ms, audio building to a crescendo ([design guide](https://blakecrosley.com/guides/design/balatro); [PSU](https://www.psu.com/news/why-winning-feels-so-good-reward-design-from-arcades-to-balatro/)) | Banking loot should be a multi-channel count-up that escalates |
| Time-loop games | Players can't tell "present me" from clones; the fixes are a present-self marker, translucent past selves and per-loop colours ([itch.io](https://itch.io/post/2784044/view-in-topic)); Lemnis Gate calls information "one of the most critical aspects" of its 25 s loop ([Ratloop](https://ratloopgamescanada.com/dev-blog/time)) | Readability is a feature, not a coat of paint |

### F2. Platform facts that shape the polish

- **Most players are on phones:** 80% of DAU in Roblox's 2024 annual report ([Pocketgamer.biz](https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue)); 2025 third-party estimates say 72-74% [UNVERIFIED] ([Search Engine Land](https://searchengineland.com/guide/roblox-users)).
- **No custom shaders.** Roblox has only built-in post effects (Bloom, Blur, ColorCorrection, ColorGrading, DepthOfField, SunRays), so a VHS look has to be UI overlays plus grading, not a shader like [this Godot one](https://godotshaders.com/shader/vhs-and-crt-monitor-effect/). Personal screen effects belong under `CurrentCamera` on the client (Vault: *Atmosphere Sky Clouds and Post-Processing*).
- **Audio API:** effects such as `AudioPitchShifter` (Pitch 0.5-2) and `AudioDistortion` are wired in a graph ([docs](https://create.roblox.com/docs/audio/effects); [announcement](https://devforum.roblox.com/t/2848873)). The vault lists `AudioPlayer:Play(atTime)` with `SoundService:GetMixerTime()` for sample-aligned stems (Vault: *SoundService - Engine Reference Card*), and the local API dump confirms `GetMixerTime`. The public [AudioPlayer page](https://create.roblox.com/docs/reference/engine/classes/AudioPlayer) as surfaced by search showed no `atTime`, and DevForum users report legacy `Sound` drift ([thread](https://devforum.roblox.com/t/allow-us-to-continuously-sync-timeposition-of-2-sound-objects/4518239)). Stem sync is **verify first** [UNVERIFIED].
- **Licensed audio:** 100,000+ rights-cleared tracks and SFX (APM, Monstercat, Pro Sound Effects and others). They stay public and free in experiences, capped at 250 licensed tracks per experience; APM is "only on the Roblox platform" ([audio privacy post](https://devforum.roblox.com/t/1701697); [Monstercat](https://devforum.roblox.com/t/roblox-monstercat-3/688452)). Uploads: 2,000 per 30 days if ID-verified, 100 otherwise, private by default ([audio assets](https://create.roblox.com/docs/en-us/audio/assets)). Upload under the owning group or the audio is silent live (Vault: *Music Licensing and Audio Upload Rules for 2026*).
- **Accessibility hooks:** `GuiService.ReducedMotionEnabled` and `PreferredTransparency` (multiply background transparency by it; set tween time to 0 or fade under reduced motion) ([docs](https://create.roblox.com/docs/en-us/production/publishing/accessibility); [announcement](https://devforum.roblox.com/t/introducing-accessibility-settings/2723187)). `PreferredTextSize` is in the API dump.
- **Input Action System** is publishable: give every action keyboard, gamepad and touch bindings, and link a touch binding to a GUI button through `UIButton` ([docs](https://create.roblox.com/docs/input/input-action-system); [DevForum](https://devforum.roblox.com/t/client-beta-input-action-system-is-now-available-to-publish-in-experiences/3890979)).
- **Clips:** video captures run up to 30 s, **strip the in-experience UI**, and feed Roblox Moments (beta, 13+). There is a developer capture API, and over 240M videos were captured in the first weeks ([newsroom](https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery); [DevForum](https://devforum.roblox.com/t/roblox-moments-a-new-era-of-user-generated-discovery-for-experiences-and-gameplay-is-here/3919813)). Clip-critical information must therefore live **in the world**.
- **Localization:** automatic translation covers about 12 languages (the list returned omitted Spanish, so re-check [UNVERIFIED]); chat translation covers 16 ([docs](https://create.roblox.com/docs/en-us/production/localization/automatic-translations.md); [newsroom](https://about.roblox.com/newsroom/2024/02/roblox-introduces-ai-powered-real-time-chat-translations-in-16-languages)). Danish is on neither list.
- **Funnels:** `LogOnboardingFunnelStepEvent` is server-only, works in published games only, is meant for one-time funnels, and the dashboard has up to 10 funnel tabs ([docs](https://create.roblox.com/docs/production/analytics/funnel-events.md)).
- **Photosensitivity and motion:** test every game for seizure triggers and reduce flash contrast, rate and area (XAG 118). Avoid shake, bob and blur, or make them optional (XAG 117) ([XAG 118](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/118); [XAG](https://learn.microsoft.com/en-us/gaming/accessibility/guidelines)). The Okabe-Ito palette (#56B4E9, #E69F00, #CC79A7, #F0E442, #009E73, #0072B2, #D55E00) is the colour-blind-safe reference ([abratabia](https://www.abratabia.com/game-accessibility/colorblind-modes.php); [Smashing](https://uxdesign.smashingmagazine.com/2024/02/designing-for-colorblindness)).

### F3. Vault rules (LihFolk Vault V2, verified to 2026-10-29)

- **Timing** (*Feedback Timing - Sound Visual and Haptic Sync*): visuals land 1-2 frames after input. Sound files hide 30-80 ms of lead-in, and Bluetooth adds 100-300 ms. Preload sounds, trim onsets, and set visuals in the input handler or `PreRender`.
- **Juice** (*Game Feel and Juice*; *UI Motion Language and Timing*): every input gets a pop and a sound within 100 ms, and every reward gets motion, a number and a pop. Press 0.9 over 0.08 s, release Back over 0.3 s, panels 0.26 s in and 0.14 s out. Feedback takes 0.1-0.2 s, entrances 0.2-0.35 s, and over 0.6 s only inside an enjoyed reward.
- **Reward ladder** (*Reward Moments and Celebrations*): common 0.3-0.5 s, rare 1-1.5 s, legendary 3-4 s. Only the top tier dims the world or hides the HUD. Celebrations take under 10% of play time.
- **Mix** (*Audio Mixer Settings with SoundGroups*; *Sound Fundamentals*; `GAME_BIBLE.md` 6.5): Master, Music, SFX, UI and Voice buses, plus a Warnings group the music slider can't mute. Every sound has a `SoundGroup`, sliders use a squared curve, and ducking is on. Voices are pooled. Level to about -18 LUFS with 3+ variations.
- **Sourcing** (skill `lihfolk-sfx`): Roblox-licensed Creator Store audio first, then perpetual licences (Sonniss, BOOM, A Sound Effect). Never "Distribute" a library sound. Never invent ids. Keep a manifest per id.
- **Budgets** (*Highlights and Selection Effects*; *Juice on a Budget*): up to 255 Highlights per client, with the first costing up to 1 ms GPU on mobile, so animate properties rather than create and destroy them. Particles: 100/s per emitter on mobile, 360 alive on touch. Tag effects `info` or `decor`, and never cull `info`.
- **Tutorial** (skill `lihfolk-tutorial`): first verb within 10-20 s, one goal and one pointer, 8 words or fewer, hints after 6-10 s stuck, never gate friends. Each step keeps 90% or more of players, the first reward comes under 60 s, and 70% or more finish.
- **Accessibility and text** (*Captions and Audio Accessibility*; *Colour-Blind Safe Design*; *Motion Sensitivity and Camera Comfort*; *Localization Pipeline*): caption information-bearing sounds only, for 1.5 s or more. Every colour signal gets a second channel. One comfort module owns reduced motion, FOV (60-100) and shake (0-100%). No string literals in code, and no text baked into images.

### F4. Live Roblox market (tools/rbx_search.py and games API, 2026-11-12)

| Game | CCU | Visits | Note |
|---|---|---|---|
| Notoriety: A PAYDAY Experience (16680835) | 1,511 | 566M | The polish benchmark for heists on Roblox; updated 2026-11-11 |
| Entry Point: Freelancer's Cut (324740367) | 97 | 10.9M | Stealth heist; shows the audience for stealth |
| **ECHOES: Clone Puzzles [MULTIPLAYER]** (10769139317) | 1 | 20.9k | **Same core idea, created 2026-10-03.** No traction so far, so the concept alone is not the moat |
| Clone Engine (6128091457) | 1,841 | 417M | Clone fantasy is proven |
| Think Twice (10456881513) | 2,829 | 36M | A new puzzle-ish hit (created 2026-07) |

Implication: someone else shipped "record yourself, cooperate with clones" a month ago and it has 1 CCU. **Feel, clarity and clip-ability decide whether this genre works on Roblox, not the mechanic.** That is the case for this whole report.

### F5. Prototype state (read from code)

`src/client/init.client.luau` (231 lines) has a basic HUD, a rewind ColorCorrection tween (1.1 s) and big messages. `src/server/Echoes.luau` gives echoes a cyan `Highlight` (FillTransparency 0.55) and moves them on the server every Heartbeat. There are no sounds, SoundGroups, input actions, settings or localization yet. Config: 60 s loops, 15 Hz recording, 4 echoes per player. `design.md` changes the controls to "R = End my take, hold R = Scrap" and sets per-location loop lengths (30/45/60/60/75 s). This report adopts both.

## Recommendations / decisions

### D1. The input contract (applies to everything below)

- **Decision:** every player input shows a visual on the **same frame** it is read, and starts its sound with a trimmed onset (under 10 ms of silence), on the client, before any server reply. The server then confirms or corrects. A denied action still gets a "nope" wobble and a soft thud (F3 juice rule).
- **Decision:** all cosmetic SFX and VFX run on the client from replicated state or attributes. Nothing cosmetic is server-parented. One `ScreenFX` owner holds the grade stack (ColorCorrection, Blur, FOV kicks), and one `Comfort` module gates intensity.
- Budgets: at most 24 simultaneous SFX voices per client (pooled, with oldest-quietest stealing), at most 4 echo-event voices at once (repeats merged), and at most 30 particles per event within the 360 touch cap.

### D2. The Rewind (signature moment, client-side, about 2.5 s)

This builds on the visual timeline in `visuals.md` D5 and adds sound, UI and tuning.

| t (s) | Visual | Audio | UI |
|---|---|---|---|
| 0.00 (input frame) | End-take button squash (0.9, 0.08 s); white flash at 0.25 opacity, 1 frame | **Tape stop:** music PlaybackSpeed ramps 1.0 to 0.25 over 0.30 s (pitch falls with it), then fades to 0. Trimmed "clunk" of a VCR key | The VCR OSD "◀◀ REWIND" appears top-left in mono caps, white with a cyan shadow offset 2 px (a fake chromatic split) |
| 0.05-0.15 | FOV 70 to 82 (Quad Out). Saturation 0 to -0.85, TintColor cyan-white. Blur 0 to 4 | A low "whirr" loop starts at 0.6 pitch | A scanline overlay (tiled 4 px ImageLabel, 0.85 transparency) fades in. A tracking bar (a 6% tall soft white band) scrolls bottom to top once every 0.5 s |
| 0.15-1.60 | **World runs backwards**: every actor's recording replays in reverse at an eased 25-45x, with trails on (visuals D5) | Whirr pitch rises 0.6 to 1.6 with the scrub speed (AudioPitchShifter or PlaybackSpeed). Ghost "zip" ticks every time an echo un-grabs loot (max 4) | Loop timer digits **count backwards** fast (0:42 to 0:00), in sync with the scrub |
| 1.60-2.10 | Snap to the start pose. Saturation back to 0 over 0.3 s, FOV back to 70 with a small overshoot | **Reverse-cymbal swell** (0.5 s) peaks exactly at 2.10 | The OSD swaps to "▶ PLAY". The scanlines fade out. A card reads "LOOP 3" (scale 0.82 to 1, Back Out, 0.26 s) |
| 2.10-... | Echo spawn arpeggio (D4). 3-2-1 countdown, one number per beat (0.469 s at 128 BPM) | Count-in on rim clicks. On "GO" the music starts on the downbeat from bar 1, and the band has one more stem (D7) | "GO" stamp, then the HUD slides back in over 0.2 s |

- **Decision:** the rewind sound family is **warm and sweet**: tape, felt and cymbal. There are no screeches above 4 kHz (low-pass the whirr at 5 kHz), and it is ducked so the whirr sits 6 dB under the music's normal level. This is the Braid remaster lesson (F1).
- **Reduced motion** (`ReducedMotionEnabled` or the in-game override): no FOV kick, no scrolling scanlines, no reverse scrub. Instead there is a 0.8 s crossfade to a still, desaturated frame, the "LOOP 3" card fades in, and the same audio plays (audio is not motion).
- **Skip:** in solo, tapping during the scrub jumps straight to the 1.60 s mark. The scrub is the fun part for watchers and the boring part on loop 9.
- **Co-op:** the rewind starts when the server ends the loop, so every client plays it from the same server timestamp (`GetServerTimeNow()`) and the GO lands at the same moment for everyone.

### D3. Loop countdown tension (the last 4 bars)

At 128 BPM, 4 bars is 7.5 s. For each loop:

- **T-7.5 s (4 bars left):** the music adds its "anticipation" stem (hi-hats and a riser), the Payday anticipation-phase idea (F1). The timeline bar's fill changes from white to Torch Amber.
- **T-3.75 s (2 bars):** a clock tick on every beat, rising one semitone per beat (8 ticks). The timer digits pop to 1.15x on each second. On a phone that supports it, a short `HapticEffect` UIClick plays on each of the last 3 seconds (best effort, F3).
- **T-1.9 s (last bar):** a soft red vignette at 0.75 transparency, static under reduced motion. The guard's music stab is muted so the ticks own the space.
- **T-0:** a "tape out" sound (a short tape stop), and the rewind sequence starts. Hitting 0 counts as "End my take" (`design.md`).
- **Never:** full-screen red flashes, or more than 3 flashes per second.

### D4. Echo presence: spawn, trail and voice

- The visual build follows `visuals.md` D4: a 0.35 s time shimmer, a rim Highlight per player group, an age ramp, number badges, a shoulder-to-hip Trail above 6 studs/s, and the stack rule.
- **Decision, the echo-spawn arpeggio:** spawns are staggered **60 ms** apart, oldest first. Each spawn chime is pitched to the next note of a major pentatonic scale in the song's key (C D E G A C' D' E'), so 8 echoes give an 8-note run. Volume is -12 dB per chime with a soft attack. In co-op, each player's echoes use their own octave (P1 middle, P2 +1 octave, P3 -1, P4 a fifth up), so a full server sounds like a chord.
- **Echoes are quiet.** No footsteps. Echoes only make **event sounds** (grab, plate press, bonk, zap, busted), routed to an Echo bus with a 3.5 kHz low-pass and a short reverb (a ghostly "memory" sound) at -6 dB against the live player's version. That keeps 12 echoes from turning into noise and tells your ear what is past and what is present.
- **Echo failure stings** (from `design.md` failure states), each with a visual and a timeline marker:
  - **Bonk:** a cartoon "boing" and a 0.15 s squash to 0.6 height.
  - **Zap:** an electric crackle and a 2-frame skeleton flash, capped at 3 flashes per second.
  - **Busted:** handcuff clank, then "?!" and a poof into 20 shards (visuals).
  - **Shrug:** a "huh" kazoo blip.
  - **Stuck:** a "..." bubble and a low hum.
  - These are the comedy beats, so they must be funny with the sound **off** (`VIRAL_PLAYBOOK.md` rule 1): the pose and bubble carry it, and the sound adds to it.

### D5. Mechanism feedback (plates, doors, lasers, guard)

- **Causality wires (Decision, must-have).** Every plate is visibly connected to what it powers by a floor-level Beam "cable" (dark core). When the plate is held, a pulse of the **occupant's echo colour** runs along the cable (0.25 s travel), and the door or laser it reaches lights up its matching icon. This is the most important readability fix in the game: viewers of a 15 s clip must see "her past self is holding *that* door".
- **Plate press:** the plate drops 0.15 studs at once (set the extreme instantly, spring back with overshoot, per Vault: *Squash Stretch and Anticipation*). A ring in the occupant's colour and shape icon appears, with a metallic "clunk" plus a soft tone in the song's key. Release gives a reverse tone, and the door shows a shrinking ring for the 0.4 s grace (`Config.PLATE_GRACE`).
- **Vault door:** a 0.15 s anticipation shudder (2 studs of shake on the door only, never the camera), then a hydraulic open with a bass thump on full open. Closing has a warning "beep-beep" 0.5 s before the door turns solid, which also fixes the PROJECT_STATE risk of the door pushing people.
- **Lasers:** an active grid has a spatial hum (3D emitter, about 20 studs rolloff). Switching off plays a descending "zhoom" and the beams retract from the ends inward over 0.2 s. Switching on plays the reverse. The floor dot stays as an "armed" marker (visuals D4).
- **Guard detection:** the vision cone (visuals) fills from the guard outward over **0.5 s** before a catch, with a rising "hmm?" whine and a "!" that grows over the guard. This meets the 500 ms or more telegraph rule (`GAME_BIBLE.md` rule 5). A muted player sees the cone fill, a caption reads "[Guard notices you]", and phones that support it get a haptic.

### D6. Getting caught and banking loot (reward ladder)

**Caught (live player, ends your take):** a 0.10 s hit-stop (local animation freeze), a "BUSTED" stamp rotated -8° as a **world BillboardGui** above you so it survives UI-less captures, a record scratch, a two-note "wah-wah" muted trumpet, and a camera nudge of 0.3 studs (disabled under reduced motion). Total 1.5 s, then spectator mode. It is not a punishment screen. It is a joke the player is in on.

**Banking (the core reward), mapped onto the tier ladder (F3):**

| Tier | Trigger | Length | Layers |
|---|---|---|---|
| Common | Gold bar or cash bag banked | 0.45 s | The bag drops into the van, which squashes to 0.92 and springs back. 12 gold coin particles. A "+$100" text in Heist Gold flies along a screen-space arc to the loot meter. The meter counts up over 0.4 s with coin ticks. A cash register "ka-ching" on arrival |
| Combo | Another bank within 3 s | +0.1 s | The ka-ching pitch rises one semitone per combo step (up to +5). The "+$" text grows 1.1x per step |
| Rare | Diamond or a set piece | 1.2 s | Plus a short riser before the drop, a 0.3 s 0.5x local slow-motion, a white sparkle burst (20 particles), and a brief music stab |
| Milestone | The loot target reached | 2 s | Plus a screen-edge gold glow, a "TARGET MET - GET OUT!" banner (localized key), and the music's "getaway" stem enters |
| Top | Heist complete | 5-6 s | Plus world dimming, HUD hidden, the final hit, then the Heist Reel (D8) |

### D7. Audio direction

**Genre (Decision):** **"VHS caper funk."** Upright or electric bass, brushed-to-funk drums, Rhodes, vibraphone, muted brass stabs and wah guitar, with a subtle tape wobble on the master. Monaco owns ragtime piano and Payday owns techno. "Caper funk on a worn tape" fits our rewind fiction and reads as "heist" to a 12-year-old in one bar. Location variants:
- Corner Shop and Bank: the core kit.
- Museum: pizzicato strings and harpsichord.
- Casino: lounge swing and brass.
- Moon Base: synthwave version of the theme.
- "Steal Back Christmas": sleigh bells, celesta and jingle funk.

**"The music is the clock" (Decision):** **128 BPM** for every location (half-time feel where the genre needs it). Loop lengths from `design.md` become whole bars: 30 s is 16 bars, 45 s is 24, 60 s is 32 and 75 s is 40. Each loop's track is cut to exactly that length, so the music restarts with every GO and the rewind always lands on a bar line.

**"Crew Layers" (Decision for v1.1; feasibility below):** one song per location, with 6 stems:

| Stem | Enters when |
|---|---|
| 0 Bass + kick | Always, from GO |
| 1 Drums full | 1 echo in the server |
| 2 Keys/guitar | 2 echoes |
| 3 Brass stabs | 4 echoes |
| 4 Lead melody | 6 echoes |
| 5 "Big band" (strings and choir pad) | 8 or more echoes: the "8 of me" moment |
| + Anticipation | The last 4 bars (D3) |
| + Alarm | A guard is alerted (state-driven, smoothed over 2 s) |

- **Feasibility:** vertical layering is a standard technique ([bugnet adaptive music guide](https://bugnet.io/blog/adaptive-music-a-beginners-guide); [Game Developer](https://www.gamedeveloper.com/audio/horizontal-resequencing-and-dynamic-transitions-for-game-music-composers)). The vault documents scheduled starts on the mixer clock (F2). With 8 streams of a 30-75 s loop, memory is modest [UNVERIFIED, measure]. **Prototype it first:** a spike on a real phone through Open Cloud, logging the drift between stems over 10 loops. Fallback: start all stems at Volume 0 on the same frame and only change volumes (never seek). Re-sync at each loop start, which happens every 30-75 s anyway, so drift cannot build up.
- **Rights:** Roblox's licensed library ships finished mixes. Stems therefore need **commissioned or self-owned music**. That also fixes the off-platform problem: APM is Roblox-only (F2), and owned music can go in TikTok trailers. Budget: 6 locations with 8 stems each, commissioned from an indie game composer [UNVERIFIED, get quotes]. Get a written grant covering Roblox, trailers and streams (Vault: *Music Licensing*).
- **Launch fallback (must-have):** Roblox-licensed library tracks in the caper and spy genre. Per location, pick 3 tracks for horizontal resequencing: "Prowl" (loops 1-2), "Crew" (3 or more echoes) and "Getaway" (target met), crossfaded on loop starts with two decks. Keep tracks in one key family if possible. Tape-stop and swell are SFX, so they work with any track.

**SFX list (launch set, about 40 roles, 3 variations each where repeated):**

| Role key | Bus | Caption? | Notes |
|---|---|---|---|
| ui.tap / ui.back / ui.deny | UI | no | Tap is under 40 ms onset; deny is a soft thud |
| rewind.tapeStop / rewind.whirr / rewind.swell / rewind.vcrKey | SFX | "[Rewinding]" once | Ducks the music by 8 dB |
| loop.countIn / loop.go | SFX | no | On the beat |
| loop.tick (x8 pitched) / loop.tapeOut | Warnings | "[Time running out]" | Not muted by the music slider |
| echo.spawnChime (pentatonic set) | Echo | no | 60 ms stagger |
| echo.grab / echo.bonk / echo.zap / echo.busted / echo.shrug / echo.stuck | Echo | Busted: "[Your echo was caught]" | Low-passed |
| plate.press / plate.release / plate.tone | SFX | no | The tone is in the song's key |
| door.shudder / door.open / door.closeWarn / door.slam | SFX | closeWarn: "[Door closing]" | 3D |
| laser.hum (loop) / laser.off / laser.on | SFX | on/off when off-screen | 3D |
| guard.footstep / guard.hmm / guard.alert / guard.huh (sees an echo) | SFX + Warnings | alert: "[Guard alerted]" | Alert is in the Warnings bus |
| player.caught (scratch + wah-wah) | SFX | "[Busted]" | |
| loot.pickup.gold / loot.pickup.diamond / loot.carryLoop | SFX | no | Carry is a soft jingle |
| bank.drop / bank.coins / bank.kaching (pitched) / bank.riser | SFX | no | |
| heist.finalHit / heist.stampMedal (x3 rising) / heist.reelWhoosh | SFX | no | |
| amb.bank.night / amb.street / amb.museum ... | Ambience | no | One player per bed; equal-power crossfades |
| van.engineIdle / van.doorSlam | SFX | no | Used in the FTUE spawn |

**Bus tree (Decision):** Master > Music (−14 dB under SFX at rest), SFX (Gameplay, Echo, Ambience), UI, **Warnings** (no slider except Master), and Voice (proximity voice is a bonus, never required). Sliders use a squared curve. Ducking: music −6 dB during big messages, −8 dB during the rewind, and −3 dB while voice is active. Master limiter on. Loudness: SFX levelled to about −18 LUFS integrated with peaks under −1 dBTP. Every id goes in the `audio_manifest` with source, licence, uploader and date. A Lune CI check fails on any Sound without a SoundGroup or with an id not in the manifest.

**Licensing (Decision):** launch with **Roblox-licensed Creator Store audio only** (the brief's rule). Use only ids found through a Creator Store search in-session or given by the owner, and never invent ids (lihfolk-sfx rule). Any custom uploads (commissioned music, edited SFX) go to the **group that owns the game**, as private assets. Never tick "Distribute". Stay well under the 250 licensed tracks per experience: about 18 tracks planned. Make our own trailers with owned music only, and add a "Streamer mode" toggle when owned music exists.

### D8. Heist complete and the Heist Reel

1. **Last bank:** a local 0.5x slow-motion for 0.6 s if the clock has less than 3 s left (visuals D5), then the top-tier ladder.
2. **The "HEIST COMPLETE" stamp** slams in (scale 1.6 to 1, rotated −6°, 0.18 s, with a 0.12 s hit-stop). The music plays its final chord, and every echo turns to the camera and does the player's equipped emote **at the same time**. That is the "8 synchronised copies" clip, made into a feature.
3. **The Heist Reel** (12-15 s, skippable after 2 s; shots and crop-safe framing per visuals D5) is scored with a 15 s "reel edit" of the location's theme. There is a **"SAVE CLIP"** button (capture API where available, F2). Stats render as **world text** in the final frame, because captures strip the UI. Example: "8 OF ME. 1 VAULT." or "Your past self got caught 3 times."
4. **Results card:** 3 medals (Clean, Fast, Few Echoes) stamp in 0.3 s apart with rising notes (C, E, G). Then "+$ total" counts up over 0.8 s. The buttons are **Next Heist** (primary, pulsing gently), **Retry for medal**, and **Share**. There is no purchase prompt on this screen in the first session (`GAME_BIBLE.md` rule 31).

### D9. UI/UX

**HUD (Decision: 4 elements during play, everything else contextual):**

| Zone | Element | Notes |
|---|---|---|
| Top centre | **Timeline bar** (loop number, time left, echo event icons along it, red failure markers) | This is the heist's "score". 60% width on phones, 40% on PC. Below the Roblox top bar inset |
| Top right | **Loot meter** ($ banked / target, with a bag icon) | The count-up target for D6 |
| Top left | **Crew pips** (one pip per echo in its colour, number and shape) | Tap opens the Echo Deck |
| Bottom right (thumb) | **Action cluster**: Interact (88 px, contextual: Grab, Drop, Use, with a device-correct glyph) and **End Take** (72 px, hold 0.6 s to Scrap, with a radial fill) | Jump stays where Roblox puts it. All are InputActions with keyboard, gamepad and touch bindings |
| Transient | Objective line (8 words or fewer, 4 s, then shrinks to an icon next to the timeline), big stamps, captions (bottom centre, above the thumb zone) | One popup queue with priorities; nothing over a stamp |

- **Visual language:** dark translucent "dossier" plates (Ink Indigo at 0.25 transparency × `PreferredTransparency`), 2 px rounded strokes, a strictly reserved palette (`visuals.md` D2: gold only for loot, cyan, magenta, violet and lime only for echoes, red only for danger). Numbers use tabular figures. Typography: one bold geometric sans for UI (Builder Sans, Roblox's own family, chosen for glyph coverage across languages [UNVERIFIED coverage]) plus one display face for stamps only. All stamp text is **live text with UIStroke**, never baked images (localization).
- **Motion:** use the vault numbers (F3): press 0.9 over 0.08 s, release Back over 0.3 s, panels 0.26 s in and 0.14 s out. Tween UIScale, never Size. Under reduced motion, use fades only.
- **Mobile-first:** test at 5 viewports plus a notched phone, with 12 px minimum text, 44 px or larger taps (we use 64-88 for the main actions) and 0 overlaps (Vault: *Responsive UI*). Interactive UI stays inside `ScreenInsets` CoreUISafeInsets.
- **Plan view and Echo Deck (between loops):** holding Map (or tapping the crew pips) opens the blueprint top-down view (visuals D5). It shows each echo's route as Beams, plus cards at the bottom: `#1 #2 #3`, each with Retake and Delete (`design.md`). Solo play pauses the game. In co-op, each player can view it while the other players' countdowns continue. After 10 s, the ready check auto-starts the loop so no one waits on a menu.
- **Hideout and level select (post-FTUE):** a diegetic garage hideout. The **corkboard** with red string is the level select: polaroids of each target, pinned medals, and the "Vault of the Day" as a glowing envelope. A trophy shelf holds stolen set pieces. It uses SurfaceGuis with a 2D fallback list for gamepad and touch accessibility. Launch version: a simple 2D "dossier" panel. The 3D corkboard comes later.
- **Settings (reachable from the first second):**
  - Audio: Master, Music, SFX and UI sliders, plus music on/off.
  - Comfort: reduced motion (Follow / On / Off), camera shake 0-100% (default 60%), FOV 60-100, flash limiter (always on), "Relaxed Time" assist.
  - Interface: text size following `PreferredTextSize` with an override, background opacity, captions on/off (default **on** for sound captions).
  - Colour: Echo palette Standard / High-distinction.
  - Controls: hold-to-scrap or tap-twice.

**Accessibility (Decisions):**
- Echo identity uses three channels: hue (`visuals.md` D2) **plus** the number badge **plus** a per-player **shape** (P1 ●, P2 ▲, P3 ■, P4 ◆) on badges, plate rings and pips. Hue alone never carries meaning.
- **"High-distinction" palette** derived from Okabe-Ito: P1 sky blue #56B4E9, P2 reddish purple #CC79A7, P3 bluish green #009E73, P4 yellow #F0E442. It also switches the Torch Amber guard light to white, so yellow stays free. Validate both palettes with the vault's Oklab audit under protan, deutan and tritan simulation in Lune CI.
- **Captions** only for information-bearing sounds (the table in D7). They show a direction arrow when the source is off-screen, use at most 2 lines and stay 1.5 s or more.
- **"Relaxed Time"** (solo or all-agree in co-op): loops are 1.5x long, with the music time-stretched by switching to a 96 BPM arrangement (or simply looping the last bars [UNVERIFIED feel]). Medals are still awarded, but runs are flagged off the speed leaderboard.
- Every hold has a toggle alternative. There are no rapid-tap actions. Gamepad is fully supported.

**Localization (Decision):** English source. Every string is a key with named placeholders and full sentences, numbers are formatted on the client, and the server sends kind plus parameters, never English (Vault: *Localization Pipeline*; *Notification and Toast Systems*). Turn on automatic translation at launch and hand-review Portuguese (BR), Spanish, Indonesian and German by playtesters [UNVERIFIED that Spanish is auto-supported]. Add **Danish** by hand (the owner is Danish, and it is not auto-supported). The design leans on icons and numbers, so text volume stays small: the target is under 250 strings at launch.

### D10. Onboarding / FTUE: teach the echo in under 60 s without a text wall

This adopts the `design.md` C timeline (spawn in the van, the plate that opens a door you can't walk through, the first rewind about 22 s in, the "wow" about 25 s in, the first bank under 40 s). The polish layer adds:

- **Objective copy for the whole first heist, 30 words or fewer in total:** "Stand on the plate." / "Rewind time." / "Grab the cash." / "Get to the van." / "One echo isn't enough." / "Rewind again." The device glyph appears next to each verb.
- **The "wow" camera beat:** after the first GO, the camera eases 25° toward the van for 0.8 s, so the player sees **their own avatar** climb out and walk to the plate, with a warm "that's me" chime and the spawn shimmer. Skipped under reduced motion; an arrow and a ring are used instead. Input is never locked: if the player moves, the nudge ends at once.
- **Rewind button teaching:** a pulse on End Take starts only after the player has stood on the plate and stepped off once (the moment the problem is felt). This is the "show the problem, then the tool" pattern.
- **Stuck ladder** (server-driven, timers pause while idle in menus):
  1. 8 s with no progress: a world cue (the target glows and the causality wire pulses).
  2. 15 s: an edge arrow.
  3. 2 loops without progress: a **Ghost Hint** that plays a faint pre-recorded solution echo in white for one loop (`design.md`).
  4. 4 loops: the objective line adds the "how" ("Your echo can hold it").
  - Competence ends the guidance: when the player does the action without a hint, the beam is dropped.
- **Co-op FTUE:** the Corner Shop works with 1-4 players, and friends who join mid-FTUE drop straight into the current loop. In co-op the first objective becomes "One of you: stand on the plate." Hints are local, so a veteran friend never sees them.
- **Funnel** (server-only, forward-only, versioned `FTUE_v1`): `Joined → FirstMove → FirstPlate → FirstRewind → FirstEchoSeen → FirstBank → L1Complete → FirstBusted → FirstRetake → L4Complete → Minute10` (from `design.md`), plus custom events `HintShown{tier, step}` and `RewindSkipped`. Track the **median seconds between steps**. Targets: `FirstRewind` by 30 s, `FirstEchoSeen` by 35 s, `FirstBank` by 60 s, each early step keeping 90% or more of players, and L1 completion at 70% or more.

## Phased plan for this dimension

| Phase | When | Deliverables | Gate |
|---|---|---|---|
| **P0: Feel foundation** | Weeks 1-2 (with the client-side echo replay from tech/visuals) | `ScreenFX` and `Comfort` modules. SoundGroup bus tree and manifest with a Lune CI check. InputActions (Interact, End Take or Scrap, Map). The Rewind v1 (D2) using licensed placeholders. Plate, door and laser feedback and **causality wires** (D5). Banking common tier (D6). HUD re-layout to 4 elements (D9) | A phone test through Open Cloud. Every input shows feedback on the same frame. 0 sounds without a SoundGroup |
| **P1: Readability and FTUE** | Weeks 3-4 | Echo spawn arpeggio, echo event sounds and failure stings (D4). Guard 0.5 s telegraph and caught sequence. Countdown tension (D3). FTUE script, stuck ladder and Ghost Hint (D10). Funnel events. Captions. Reduced-motion paths. Localization keys | `quality-score` tutorial rubric 8.5 or higher (3 blind reviewers). A muted playthrough has no surprise catches |
| **P2: Launch polish** | Weeks 5-6 (soft launch) | Licensed music in 3 variants per location with two-deck crossfades. Rare, milestone and top tiers. Heist complete with synchronised emote and Heist Reel (D8). Results card. Settings menu complete. High-distinction palette with Oklab CI. Juice governor (info vs decor) | 5 viewports with 0 overlaps. A mid Android phone holds 30 fps or better during a rewind with 12 echoes. UI rubric 8.5 or higher |
| **P3: Signature upgrades** | After soft launch, by data | **Crew Layers** stems (commissioned, after the sync spike passes). Streamer mode. 3D corkboard hideout. `HapticEffect` set. Christmas audio pack (jingle-funk stems, sleigh-bell spawn arpeggio). Moments capture hooks | D1 and the funnel fixed first. Ship stems only if the drift test passes |

**Must-have for launch:** D1, D2 (full and reduced-motion), D3, D4 (except the co-op octave chord, which is nice-to-have), D5 (all of it, causality wires above everything), D6 (all tiers), D8 (stamp, synchronised emote, Reel, results), D9 HUD, settings and accessibility, D10 entirely, D7 bus tree, licensing and the licensed-music fallback.

**Later:** Crew Layers stems, streamer mode, the 3D corkboard, haptics, the co-op octave chord, Relaxed Time's 96 BPM arrangement, and hand-made translations beyond Danish.

## Risks

1. **Stem sync may not hold** on Roblox clients, because the `Play(atTime)` evidence comes only from the vault, not the public page I found [UNVERIFIED]. *Mitigation:* the volume-only fallback with a re-sync every loop, a measured spike before commissioning, and the licensed-track fallback ships first.
2. **Bluetooth latency of 100-300 ms** will make the 128 BPM count-in and the ticks feel off for some phone players (F3). *Mitigation:* the visuals drive the beat (the countdown numbers are the truth), and the audio supports them.
3. **Over-juicing:** 12 echoes each sparkling, chiming and trailing can become noise and drop frames. *Mitigation:* echo voices capped at 4, the stack rule (visuals), info vs decor tags, the reward ladder that keeps big channels for big moments, and the 360-particle touch cap.
4. **Motion sickness and photosensitivity** from the rewind (FOV kick, scrub, scanlines). *Mitigation:* follow `ReducedMotionEnabled`, shake default 60%, the 3 flashes per second limiter, and an XAG 118-style review of the rewind and zap flashes.
5. **Music rights off-platform:** library music in our trailers or in clips that others repost. APM is Roblox-only (F2). *Mitigation:* make trailers with owned music only. Roblox's own capture and Moments handle in-platform music [UNVERIFIED on how capture treats licensed tracks]. Add streamer mode once owned music exists.
6. **Captures strip UI,** so clips lose the timeline and the stamps. *Mitigation:* key information is in the world (badges, rings, world-space stamps, world text in the Reel).
7. **The audio asset pipeline:** ids that work in Studio go silent live if they were uploaded personally. Takedowns fail silently. *Mitigation:* group uploads, the manifest, and periodic load checks through Open Cloud Luau Execution.
8. **Competition:** "ECHOES: Clone Puzzles" (live since 2026-10-03, 1 CCU) shows the mechanic alone does not pull players. If our polish slips to "prototype feel", we are that game. *Mitigation:* the P0-P2 gates above are hard gates, not wishes.
9. **The owner cannot test in Studio from the cloud session.** Feel is subjective and needs hands. *Mitigation:* Open Cloud runs for logic and timing, scripted capture of rewind frame times, and the owner plays one 10-minute session on a phone per phase, against a written checklist (D1-D10).

## Sources

**Web**
- Superhot GDC 2016 talk listing: https://gdcvault.com/play/1023483/Game-Design-and-Mind-Control
- Kill Screen on Superhot: https://www.killscreen.com/superhot-wants-get-inside-your-brain-and-change-how-you-think/
- Giant Bomb on Superhot time: https://giantbomb.com/users/3929/articles/time-is-on-your-side-the-gameplay-of-superhot
- Game Developer on Hitman GO: https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense
- Gamezebo Hitman GO review: https://www.gamezebo.com/reviews/hitman-go-review/
- Classical MPR on the Monaco score: https://www.classicalmpr.org/story/2013/05/31/austin-wintory-and-monaco-whats-yours-is-mine-on-top-score
- OSV Monaco OST review: https://www.originalsoundversion.com/monaco-whats-yours-is-mine-review/
- Payday 2 music phases (TV Tropes): https://tvtropes.org/pmwiki/pmwiki.php/AwesomeMusic/PAYDAY2
- Superjump on Payday 2: https://superjumpmagazine.com/payday-2-so-much-more-than-heists
- Untitled Goose Game (Wikipedia): https://en.wikipedia.org/wiki/Untitled_Goose_Game
- Mixdown on Dan Golding's score: https://mixdownmag.com.au/features/dan-golding-untitled-goose-game/
- GameSpot on Braid's music: https://www.gamespot.com/articles/spot-on-the-music-of-braid/1100-6197644/
- Braid rewind GDC talk: https://gdcvault.com/play/1012210/contactUs
- MP1st Braid Anniversary review: https://mp1st.com/reviews/braid-anniversary-edition-review-revisiting-the-past
- Teardown design notes: https://blog.voxagon.se/2020/11/05/teardown-design-notes.html
- Teardown heist basics: https://get-teardown.readthedocs.io/en/latest/gameplay/heist-basics.html
- Balatro design guide: https://blakecrosley.com/guides/design/balatro
- PSU on reward design: https://www.psu.com/news/why-winning-feels-so-good-reward-design-from-arcades-to-balatro/
- Time-loop clone readability (itch.io): https://itch.io/post/2784044/view-in-topic
- Lemnis Gate dev blog: https://ratloopgamescanada.com/dev-blog/time
- Adaptive music guide: https://bugnet.io/blog/adaptive-music-a-beginners-guide
- Horizontal resequencing (Game Developer): https://www.gamedeveloper.com/audio/horizontal-resequencing-and-dynamic-transitions-for-game-music-composers
- Roblox audio effects: https://create.roblox.com/docs/audio/effects
- AudioPitchShifter reference: https://create.roblox.com/docs/reference/engine/classes/AudioPitchShifter
- Audio API beta announcement: https://devforum.roblox.com/t/2848873
- AudioPlayer reference: https://create.roblox.com/docs/reference/engine/classes/AudioPlayer
- Sync complaint thread: https://devforum.roblox.com/t/allow-us-to-continuously-sync-timeposition-of-2-sound-objects/4518239
- Audio assets docs: https://create.roblox.com/docs/en-us/audio/assets
- Audio privacy and licensed catalogue: https://devforum.roblox.com/t/1701697
- Roblox and Monstercat: https://devforum.roblox.com/t/roblox-monstercat-3/688452
- Roblox accessibility docs: https://create.roblox.com/docs/en-us/production/publishing/accessibility
- Accessibility settings announcement: https://devforum.roblox.com/t/introducing-accessibility-settings/2723187
- Input Action System: https://create.roblox.com/docs/input/input-action-system
- Input Action System publish announcement: https://devforum.roblox.com/t/client-beta-input-action-system-is-now-available-to-publish-in-experiences/3890979
- Roblox Moments newsroom: https://about.roblox.com/newsroom/2025/09/roblox-moments-user-generated-discovery
- Moments DevForum: https://devforum.roblox.com/t/roblox-moments-a-new-era-of-user-generated-discovery-for-experiences-and-gameplay-is-here/3919813
- Automatic translations: https://create.roblox.com/docs/en-us/production/localization/automatic-translations.md
- Chat translation (16 languages): https://about.roblox.com/newsroom/2024/02/roblox-introduces-ai-powered-real-time-chat-translations-in-16-languages
- Funnel events docs: https://create.roblox.com/docs/production/analytics/funnel-events.md
- Mobile share (Pocketgamer.biz): https://www.pocketgamer.biz/80-of-roblox-users-are-on-mobile-contributing-46-of-robux-revenue
- Roblox user stats: https://searchengineland.com/guide/roblox-users
- XAG 118 Photosensitivity: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/118
- Xbox Accessibility Guidelines: https://learn.microsoft.com/en-us/gaming/accessibility/guidelines
- Colour-blind modes (Okabe-Ito): https://www.abratabia.com/game-accessibility/colorblind-modes.php
- Smashing on colour-blind design: https://uxdesign.smashingmagazine.com/2024/02/designing-for-colorblindness
- VHS shader reference: https://godotshaders.com/shader/vhs-and-crt-monitor-effect/

**LihFolk Vault V2 notes**
- *Feedback Timing - Sound Visual and Haptic Sync*
- *Game Feel and Juice*
- *Reward Moments and Celebrations*
- *UI Motion Language and Timing*
- *Squash Stretch and Anticipation in UI and Characters*
- *Music and Adaptive Audio*
- *SoundService - Engine Reference Card*
- *AudioPlayer* (API atlas)
- *Music Licensing and Audio Upload Rules for 2026*
- *AI Audio - Voice Music and SFX*
- *Audio Mixer Settings with SoundGroups*
- *Sound Fundamentals*
- *Ambient Soundscapes*
- *Captions and Audio Accessibility*
- *Colour-Blind Safe Design*
- *Motion Sensitivity and Camera Comfort*
- *Comfort Toggles - Flashes Damage Numbers and Hit-Stop*
- *Highlights and Selection Effects*
- *Juice on a Budget - Mobile and Low-End*
- *VFX Performance Budgets and Culling*
- *Hit-Stop and Screen Shake Tuning by Numbers*
- *HUD Design*
- *Responsive UI for Phone Tablet Console and PC*
- *Localization Pipeline*
- *Notification and Toast Systems*
- *Measuring Onboarding - Funnels, Drop-off and A-B Tests*
- *Tutorial Step Design Patterns - Teach by Doing*
- *Puzzle Dependency Charts and Hint Systems*

**Skills:** `lihfolk-sfx`, `lihfolk-tutorial`, `lihfolk-vfx` and `roblox-ui-builder` (SKILL.md files), plus the local API dump `_tools/roblox_api.json` (confirms `GetMixerTime`, `PreferredTextSize`, `ReducedMotionEnabled`, `StartVideoCaptureAsync` and the Audio effect classes).

**Live Roblox data (2026-11-12):** `tools/rbx_search.py` queries "heist", "bank robbery", "time loop" and "clone puzzle", plus `games.roblox.com/v1/games` for universes 16680835, 324740367, 10769139317, 6128091457 and 10456881513.

**Project docs:** `README.md`, `PROJECT_STATE.md`, `src/client/init.client.luau`, `src/server/Echoes.luau`, `src/shared/Config.luau`, `docs/GAME_BIBLE.md` (grepped), `docs/VIRAL_PLAYBOOK.md`, `docs/IDEA_ECHO_HEIST.md`, `docs/research/design.md`, `docs/research/visuals.md`.
