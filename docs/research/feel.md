# Echo Heist: Game Feel, Audio, VFX, UI/UX and Onboarding (premium polish layer)

_Dimension: polish. Written 2026-11-12 against prototype v0.1 (`src/`), the sibling reports `docs/research/design.md` and `visuals.md`, LihFolk Vault V2 and web research. Facts carry a citation (URL or vault note). **Decision** and **Rec** mark my own calls. [UNVERIFIED] marks claims I could not confirm. This version replaces the earlier `feel.md` (commit `ebee82f`). Where I disagree with a sibling report, I say so and give the reason._

## Summary

A Roblox prototype reads as a premium Steam indie when three things are true. Every input gets sight and sound in under 100 ms. One signature moment is so satisfying that people clip it. And the screen almost never asks you to read. For Echo Heist that moment is the **Rewind**. The runner-up is **your crew of past selves materialising**. Everything below either feeds those two moments or keeps them readable on a phone with the sound off.

Eight decisions:

1. **Tape is the identity.** A loop is a "take", the rewind is a tape rewind, the timer is a tape counter and the final replay is "the tape". It is original, readable in one frame, and it explains the mechanic without words.
2. **The Rewind lasts 1.8 s (standard), 1.0 s (quick) or 0.8 s (reduced motion), not 2.5 s.** Corner Shop loops are 30 s (design.md). A 2.5 s transition every 30 s eats 8% of playtime, close to the vault's 10% ceiling for reward animations. The sequence: a tape-stop pitch dive, a cyan grade, VHS tracking bands, every actor's path reeling backwards, then a "clunk" and GO on the downbeat.
3. **The music is the clock.** At **128 BPM**, every loop length in design.md is a whole number of bars: 30 s = 16 bars, 45 s = 24, 60 s = 32, 75 s = 40. The music restarts on GO, and the last 4 bars are the countdown.
4. **The band grows with your crew.** Each echo-count threshold adds one of 5 or 6 synchronised stems. This is technically feasible (sample-aligned `AudioPlayer:Play(atTime)`), but **it needs commissioned music**: the Roblox library ships finished mixes, not stems. The launch fallback is licensed tracks in intensity variants.
5. **The echo-spawn arpeggio.** Echoes form 60 ms apart, each with a chime one pentatonic step higher. Eight echoes play an eight-note run, which becomes the audio logo of the "8 copies of me" clip.
6. **Echoes sound like memories.** Their actions route through an "Echo bus" (lowpass plus a slap delay), and they make no footstep sounds.
7. **A four-element HUD and at most 30 words of text in the first two minutes.** The teaching is done by plates with visible cables, by the echo itself, and by a "Mentor tape" ghost hint.
8. **Hue cannot carry player identity.** My Oklab colour-vision audit of the visuals.md echo palette found Magenta vs Violet at 0.056 (protan) and Lime vs guard Amber at 0.051 (deutan). The threshold for small signals is 0.15. An exhaustive search found no four bright hues that clear even 0.11 against our scene palette. **Decision:** identity is a **shape glyph plus a number** (●1 ■2 ▲3 ◆4). Hue is a supporting cue, using an improved set: Cyan, Magenta, Indigo, Ghost White.

About 65% of this spec is must-have for launch (see the phased plan).

## Findings (with citations)

### F1. Reference games

| Game | Fact | Lesson |
|---|---|---|
| **Teardown** | Planning is untimed. A 60 s alarm countdown starts only once you commit. The timer was added because resource limits clashed with sandbox freedom. Reviewers call the countdown "palpable tension... the most fun part" ([Voxagon](https://blog.voxagon.se/2020/11/05/teardown-design-notes.html), [PC Gamer](https://pcgamer.com/teardown-review), [Press Start](https://press-start.com.au/reviews/xbox-series-x-reviews/2023/11/15/teardown-review-break-stuff/)) | Our loop *is* that execution window. Make the countdown musical. Keep the planning view off the clock. |
| **Superhot** | Time moves only when you move. The audio speeds up and slows "immensely" with your motion. The HUD is spare: a crosshair bloom signals when you can fire ([Wikipedia](https://en.wikipedia.org/wiki/Superhot), [Kill Screen](https://www.killscreen.com/superhot-wants-get-inside-your-brain-and-change-how-you-think/), [GamesRadar](https://www.gamesradar.com/superhot-fps-only-moves-when-you-do)) | Bind the audio to the time mechanic. When every move is recorded, every move matters. |
| **Braid** | Blow wanted instruments that "worked well with the rewind" and stayed interesting played backwards ([GameSpot](https://www.gamespot.com/articles/spot-on-the-music-of-braid/1100-6197644/)). Negative pitch does not reverse audio in engines like Unity ([Game Developer](https://gamedeveloper.com/programming/braid-style-rewind-system-01)). One reviewer found the rewind sound tiring ([Giant Bomb](https://giantbomb.com/user-reviews/id/1114/you-are-your-own-castle)) | Brief the composer on reversibility, pre-render reversed audio, and keep the rewind short. |
| **Life is Strange** | Its rewind uses a "double-exposure effect" that shows the present and prior events at once ([GamesRadar](https://www.gamesradar.com/life-strange-video-shows-time-rewinding-troubles/), [PC Gamer](https://www.pcgamer.com/au/life-is-strange-dev-diary-discusses-time-travel)) | Draw the past over the live scene while rewinding. |
| **Monaco** | Line-of-sight cones "swoop through open doors", and the designer says the intense style serves readability. Critics note that icons, characters and scenery sometimes "blur together" ([GamesBeat](https://gamesbeat.com/monaco-review/), [Kill Screen](https://www.killscreen.com/kill-screen-review-monaco-will-steal-your-time-and-your-heart/), [Giant Bomb](https://giantbomb.com/reviews/monaco-what-s-yours-is-mine-review)) | Draw guard cones on the floor. Never let juice cost readability once 16 echoes are on screen. |
| **Hitman GO** | Enemies move between nodes "like pieces of a mechanical diorama". The look draws on board games and architectural models ([Game Developer](https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense), [Kotaku](https://kotaku.com/the-latest-hitman-game-was-inspired-by-the-rich-kids-of-1569825822)) | The plan view should feel like a diorama, and it should telegraph the machine's next move. |
| **Payday 2 / Goose Game** | Payday tracks reportedly move from stealth to "frantic" sections as heists go loud ([TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/AwesomeMusic/PAYDAY2)) [UNVERIFIED detail]. In Goose Game, Debussy was recorded in normal and soft takes and cut into "hundreds of stems" that swap with player action; it worked because the pieces are solo piano ([Game Developer](https://gamedeveloper.com/audio/getting-goosey-with-debussy-creating-an-adaptive-score-for-i-untitled-goose-game-i-), [FMOD](https://www.fmod.com/blog/untitled-goose-game-interview), [DiGRAA](https://digraa.org/wp-content/uploads/2020/01/DiGRAA_2020_paper_47.pdf)) | Music escalates with the job and multiplies comedy. Use layerable instrumentation, with stems in the brief from day one. |
| **Racing ghosts** | Players call solid ghosts "too solid... distracting". Requested fixes are transparency sliders, wireframes and fading near the camera. A plugin exists because many ghosts at once are hard to read ([Steam](https://steamcommunity.com/app/1097130/discussions/0/3124911622551642956), [Openplanet](https://openplanet.dev/plugin/toomanyghosts), [freegamedev](https://forum.freegamedev.net/viewtopic.php?p=58693)) | Use rim lighting, fade echoes near the camera, and add an opacity setting. |
| **DOORS (Roblox)** | Each entity has an audio signature that teaches a response ([RoWatcher](https://rowatcher.com/news/sound-design-roblox-s-most-underrated-competitive-edge)). Live: 16,976 playing, 8.02 B visits. Its description warns of "loud sounds, flashing lights" (games API, 2026-11-12) | On Roblox, informative audio is the proven premium signal. Add a photosensitivity line to our description. |
| **Juice canon** | "Juice it or lose it" made a plain breakout game great without adding a single mechanic ([summary](https://roblog.co.uk/2024/03/juicy-games/)). Swink describes game feel as control "emphasised by polish" ([Game Developer](https://www.gamedeveloper.com/design/principles-of-virtual-sensation)). HUDs in top games are getting more minimal over time ([Univ. Bonn 2026](https://bonndoc.ulb.uni-bonn.de/xmlui/handle/20.500.11811/14207)) | Polish multiplies the mechanic we already have, and a minimal HUD reads as premium. |

### F2. Roblox platform constraints

- **Mobile is the majority:** roughly 70% of sessions to 82% of hours, while mobile-*only* players are 12-24% ([RoLearn](https://rolearn.dev/trend-reports/roblox-mobile-gaming-trends-2026), [HostingAdvice](https://www.hostingadvice.com/studies/roblox-statistics/), [GameAnalytics via GameDevReports](https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox)).
- **No custom shaders.** Distortion comes from ColorCorrection, Blur, Bloom, DepthOfField, FOV and UI overlays. Personal effects belong under `CurrentCamera` on the client, owned by one module (vault: *Atmosphere Sky Clouds and Post-Processing*; *Screen Damage Effects*). The prototype parents its rewind `ColorCorrectionEffect` to `Lighting` (`src/client/init.client.luau:181`).
- **No reverse audio.** Negative speed is unsupported. The workaround is to reverse the file offline and upload it ([DevForum](https://devforum.roblox.com/t/how-can-i-make-a-sound-play-in-reverse/1847141), [DevForum](https://devforum.roblox.com/t/reuploading-roblox-audio-in-reverse/1471171)). `AudioPlayer` Play and Stop don't reset `TimePosition` ([DevForum](https://devforum.roblox.com/t/audioplayer-is-debounced/4743400)).
- **Stems and buses.** "Start all stems together with `AudioPlayer:Play(atTime)` on `SoundService:GetMixerTime()`"; `task.delay` drifts (vault: *Music and Adaptive Audio*). Buses are `AudioFader` chains into a compressor, a limiter and `AudioDeviceOutput`, with one listener per category via `AudioInteractionGroup` (vault: *The Audio API* §6). Confirmed current via `vault.py --api`: AudioPlayer, AudioFilter, AudioEcho, AudioPitchShifter, AudioDistortion, AudioFlanger, GetMixerTime.
- **Licensing.** The licensed catalogue has more than 100,000 SFX and music tracks, free in experiences ([Docs](https://create.roblox.com/docs/audio/assets)). Partners include APM, Monstercat, Pro Sound Effects, Nettwerk and Position Music. Use is Roblox-only, with no downloading ([DevForum](https://devforum.roblox.com/t/1701697)). A cap of 250 distinct licensed tracks per experience is quoted on the forum ([DevForum](https://devforum.roblox.com/t/finding-free-music-for-your-games-both-in-and-off-platform/2179490)) [UNVERIFIED]. Uploads are capped at 7 min and 20 MB, are private by default, and must be uploaded under the owning group (vault: *Music Licensing and Audio Upload Rules for 2026*). Off-platform use of library music is [UNVERIFIED], so trailers use owned music only.
- **Highlights:** up to 255 on screen, and disabled ones count. Adding or removing one can rebuild geometry. On mobile the cost scales with screen coverage, and the first Highlight costs up to about 1 ms (vault: *Highlights and Selection Effects*, docs as of October 2026). The prototype creates one Highlight per echo every loop (`src/server/Echoes.luau:152`).
- **Haptics:** `HapticEffect` runs on most modern phones and gamepads, and buttons get `ClickHaptic` ([Docs](https://create.roblox.com/docs/reference/engine/classes/HapticEffect), [DevForum](https://devforum.roblox.com/t/full-release-you-can-now-publish-haptic-effects-in-your-experience/3660577)).
- **Localization:** auto-translation covers 16 languages, and **Danish is not one of them**. It fills only blank entries, under quotas ([Roblox](https://about.roblox.com/newsroom/2024/02/breaking-down-language-barriers-with-a-multilingual-translation-model), [Docs](https://create.roblox.com/docs/en-us/production/localization/automatic-translations.md)). Scripted text uses `GetTranslatorForPlayerAsync` plus `FormatByKey`, re-translated on `LocaleId` change (vault: *Localization*).
- **Funnels:** `AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, customFields)` allows 8,000 unique custom-field combinations and counts only from published servers ([Docs](https://create.roblox.com/docs/en-us/reference/engine/classes/AnalyticsService)).
- **Comfort:** honour `GuiService.ReducedMotionEnabled` and `PreferredTransparency`, cap flashes at 3 per second, let shake scale to 0, and never roll the camera (vault: *Motion Sensitivity and Camera Comfort*; *Comfort Toggles*).

### F3. Numbers we design against (vault and skills)

- **Feedback:** a pop and a sound within 100 ms of every input, motion and a number on every reward (*Game Feel and Juice*). Sound 0-30 ms late fuses with the action, 80 ms or more feels laggy (GAME_BIBLE §6.5). UI feedback tweens take 0.1-0.2 s, and reveals 0.35-0.6 s (roblox-ui-builder).
- **Layout:** text at least 12 px (14-16 on phones), taps at least 44 px (48 for HUD), gaps at least 8 px. Test at 7 viewports (roblox-ui-builder).
- **FTUE:** control in about 10 s, first action 10-20 s later, first reward under 60 s, objective text 8 words or fewer, stuck hint after 6-10 s, at least 90% per step, at least 70% completion (*Onboarding and FTUE*; lihfolk-tutorial).
- **Hit-stop and rewards:** important stops are at least 66 ms long, since 50 ms is 1-2 frames at 30 fps (*Hit-Stop and Screen Shake Tuning by Numbers*). Only the top reward tier dims the world, and reward animations take under 10% of play time (*Reward Moments and Celebrations*). Captions show at most 3 lines and stay at least 1.5 s (*Captions and Audio Accessibility*).

### F4. Colour-vision audit (my measurement)

Method: the vault's *Colour-Blind Safe Design* §3, using Machado 2009 full-severity matrices and Oklab distance. Thresholds are 0.15 for small signals and 0.20 for critical reads.

| Pair (visuals.md palette) | Worst distance | Under |
|---|---|---|
| Echo Magenta `#FF4FD8` vs Echo Violet `#9B7BFF` | **0.056** | protan |
| Echo Lime `#B8FF4A` vs Torch Amber `#FFD27A` | **0.051** | deutan |
| Echo Lime vs Heist Gold `#FFC21F` | **0.068** | deutan |
| Heist Gold vs Torch Amber | **0.051** | tritan |
| Echo Magenta vs Alarm Red `#FF3348` (the research value; Alarm Red is `#FF3838` since 2026-11-12, STYLE_BIBLE §1.3) | 0.105 | tritan |

I searched 326 candidate colours with Cyan fixed, requiring at least 0.25 from the Ink and Plum bases, at least 0.20 from Alarm Red and at least 0.12 from Gold and Amber. No four-colour set beats a pairwise minimum of **0.105**. Four player hues cannot be told apart by colour alone in this art direction. That is a design fact, not a tuning problem. Gold vs Amber also fails, so loot and guard light need different shapes (sparkle vs cone).

### F5. Prototype today (from code)

The rewind is a 1.1 s ColorCorrection tween with a hard-coded `task.delay(0.9, startLoop)` in `Main.luau`, which breaks the rule that tuning numbers live in Config. Every echo shares one cyan Highlight and an "ECHO n" billboard, and echoes move on the server every Heartbeat, which can look choppy. The HUD has a multi-line objectives list, and there is no audio. The server already sends every feedback moment (`rewind`, `loop`, `caught`, `echoBusted`, `banked`, `votes`, `complete`), so the polish layer can live on the client.

## Recommendations / decisions

### D1. The Rewind

**Decision:** a client `RewindDirector` owns the sequence and runs on the `rewind` notification. The server only waits for `Config.REWIND_TRANSITION`.

| t (s) | Picture | Sound |
|---|---|---|
| 0.00, on input | The button presses in (0.9 scale). In co-op, your vote pip fills. | Tape-deck "clack" (UI bus), played locally before any server reply |
| 0.00, server `rewind` | 66 ms freeze, then a 0.06 s white flash at 25% (counts toward the flash cap) | Music `PlaybackSpeed` goes 1.0 → 0.25 over 0.3 s, a tape-stop dive, then stops [verify that AudioPlayer pitch follows speed in Studio] |
| 0.10-1.35 | Saturation -0.8, tint `#9FDFFF`, contrast +0.25, Blur 6. Two or three VHS tracking bands roll up the screen with a "◀◀" OSD. **Every actor's path from this take reels backwards** as thin owner-coloured Beams eaten from end to start (the double exposure). The tape counter spins back to full. FOV 70 → 64. | A pre-reversed 1.2 s stinger (rewind whirr plus the reversed last bar of the track, rendered offline per track), then a reverse-cymbal swell peaking at 1.35 |
| 1.35-1.55 | The grade snaps back over 0.15 s. Echoes form (D2). | "Clunk" on the bar line, then the echo arpeggio |
| 1.55-1.80 | "TAKE 4" stamps in (UIScale 1.25 → 1.0, Back Out, 0.25 s). Control returns at 1.8 s. | Music restarts on the downbeat |

- **Quick rewind (1.0 s)**, automatic from the 4th rewind of a session or set in Settings: drop the path reel. Transition time becomes 3% of a 30 s loop.
- **Reduced motion (0.8 s):** no FOV change, no tracking bands, no reel. A 0.3 s crossfade to the grade, the same audio, and a static "◀◀".
- **Path data:** at `endLoop` the server sends every actor's path at 5 Hz in one `buffer`. At 12 bytes per point that is 3.6 KB per 60 s path, or about 72 KB for 20 actors once per loop. Once client echo replay exists (P1), the reel can play the avatars themselves backwards at 25x.
- **Auto-rewind at 0:00** gets its own "tape runs out" flap and the counter blinks "0:00" twice, so players can tell "I rewound" from "time ran out".

### D2. Echoes: spawn, look, trail, voice

- **Spawn ("tape print"):** echoes appear in record order, 60 ms apart, with the total stagger capped at 0.4 s. Each goes from Transparency 1 to its resting value over 0.3 s, a scanline sweeps up the body in 0.25 s, and a floor ring grows from 0 to 4 studs while fading. Each one plays a glassy chime on C-major pentatonic (C D E G A c d e), one step higher per echo, through the Echo bus. **This arpeggio is the sonic signature of the game.**
- **Look:** I agree with visuals.md D4: stripped avatars, **one persistent Highlight per owner group** (at most 4), Occluded, and an x-ray group only for your echoes holding plates behind walls. Additions:
  - **A glyph badge** (a 28 px Billboard showing ●1, ■2, ▲3 or ◆4 plus the echo digit) replaces the "ECHO n" text, which is hard to read and to localise. Owner names appear only in co-op.
  - **Palette (replaces visuals.md P2-P4):** P1 Cyan `#3DE8FF`, P2 Magenta `#FF4FD8`, P3 Indigo `#6A5CFF`, P4 Ghost White `#F4F7FF`. Measured worst pair: 0.081. Worst against the scene: 0.105. That beats the current 0.051/0.056 and removes the lime-versus-loot conflict. Exit chevrons stay white but always carry an arrow shape. Solo play is always Cyan.
  - **Proximity fade:** echoes within 6 studs of the camera go to 0.8 transparency. Settings adds an echo opacity slider (50-100%).
- **Trail:** one `Trail` per echo root, Lifetime 0.5 s, width 0.35 → 0, owner hue, shown only while the echo moves faster than `ECHO_WALK_SPEED_THRESHOLD`. Full afterimage clones (lihfolk-vfx `DashTrail` style) appear only in the Heist Reel, because of the avatar budget.
- **Future-path telegraph (P1, needs client replay):** a dotted floor line shows where each of *your* echoes will be over the next 2 s, plus an icon (✋ grab, ⬇ plate) about 1 s before an action. This is the Hitman GO lesson. It turns "why did my echo do that" into planning.
- **Voice:** no echo footsteps. Echo events play at the echo through the **Echo bus**: `AudioFilter` lowpass at 5 kHz, then `AudioEcho` with 90 ms delay, 0.15 feedback and -12 dB wet, all 4 dB under the player's version of the same sound. Cap at 6 events per second, with only the nearest 4 voiced.
- **Busted echo:** the echo glitches (body slices offset for 0.2 s), freezes and bursts into tape-ribbon particles with a "tape-chew" sound. The guard plays a 1.5 s confused "?" idle, which is the clip joke from IDEA_ECHO_HEIST.md.

### D3. World feedback

| Object | Idle | Active | Telegraph | Sound |
|---|---|---|---|---|
| **Plate** | Steel disc with a white icon of what it powers, and a floor **cable** (a Beam) running to the device | Sinks 0.15 studs in 0.06 s. The rim takes the presser's hue and glyph. A pulse runs along the cable in 0.25 s. | On release, the cable light drains back over `PLATE_GRACE` (0.4 s), so you *see* the door about to close | "Clunk" plus an electric "whum" (3D). Echo presses play through the Echo bus. |
| **Vault door** | Red lamp | Green lamp, slides open in 0.35 s with Quad Out | Closing: amber lamp at 4 Hz plus a beep. **Fix:** make the door solid only once it is fully shut. | Servo slide, lock thunk |
| **Lasers** | Alarm Red with a hum loop (40-stud max distance) | When disabled, beams retract to their emitters with sparks over 0.2 s | 3 flickers over 0.3 s before re-enabling | Hum, power-down sweep, zap |
| **Guard** | A floor-projected Torch Amber cone at 70% transparency that swoops through doors | The cone goes amber, then red, with "?" then "!" | **Rec:** a 0.35 s detection grace before "caught" (`Config.GUARD_DETECT_SECONDS`). It is deterministic, so echoes still replay identically. The design owner must confirm it. | Footsteps, radio bed, "?" murmur, "!" sting (Warnings bus) |

### D4. Caught, banking, heist complete

- **Caught (player), 1.2 s:** a 66 ms freeze, a red vignette pulse (0.15 → 0 over 0.4 s), a 0.4 s camera ease toward the guard (skipped under reduced motion), a hands-up pose, then a "tape-eject" wipe home. A brass "wah-wah" sting plays on the Warnings bus, with the caption "[Guard spotted you]". No shake: getting caught is information, not impact.
- **Banking:** a "ka-ching" at the van, a **24-coin burst** (`ParticleEmitter:Emit(24)`, gravity, 0.8 s lifetime, Heist Gold), and a "+$100" label that flies to the loot meter in 0.45 s. The meter **counts up** over 0.35-1.0 s on a log scale, with ticks rising 4-7 semitones and a "done" sound. When an echo banks, the label carries its glyph ("◆2 +$100").
- **Diamond (top tier):** the world dims 15% for 0.6 s, the HUD hides, and a sustained chord plays. It is the only mid-heist moment allowed to dim the world.
- **Heist complete:**
  1. A "HEIST COMPLETE" stamp, at most 120 money-rain particles, and the track resolves.
  2. **"Watch the tape":** the 10-15 s Heist Reel from visuals.md, safe for a 9:16 crop, autoplaying once and skippable after 1 s.
  3. A **results card**: the Haul, Crew and Clean medals stamp in one at a time, 0.25 s apart, each with a thunk. It shows "x echoes · y takes · m:ss" and the developer's echo count (the Diamond medal bait), with Replay, Next target and Share buttons. The clip-capture API is [UNVERIFIED].

### D5. Audio direction

**Style: "tape caper".** Upright bass, brushed kit, Rhodes or vibraphone, muted trumpet and an analogue pad, with light tape saturation and wow. It reads as a heist film in two seconds, it is ours, and its narrow instrumentation layers cleanly.

**Crew Layers (adaptive music):**

| Stem | Enters at | Content |
|---|---|---|
| S0 Base | always | bass and brushes |
| S1 Keys | 1 or more echoes | Rhodes comping |
| S2 Lead | 3 or more | vibes or trumpet melody |
| S3 Brass | 6 or more | stabs and a counter-line |
| S4 Full | 10 or more | full kit and synth arp |
| S5 Tension | last 4 bars (7.5 s), or guard "!" | ticking hats, riser, low pulse |

- Clients start every stem at `GetMixerTime() + (LoopStart - GetServerTimeNow())`. Layers change only on GO and fade in over one bar (1.875 s). Only Tension may enter mid-loop.
- **One stem per echo?** The voice count is fine: 16 AudioPlayers is modest. Musically it fails: 16 parts that each sound good alone and together is unrealistic, and library tracks have no stems. Threshold bands keep the payoff, a bigger band for more echoes. **P2 "Echo Choir":** each recorded echo action fires an in-key note, quantised to the next eighth note (234 ms), so an 8-echo crew plays a melody. This is cosmetic only and never touches the server timeline.
- **Sources:** P0 and soft launch use Roblox-licensed Creator Store tracks (lobby, one heist track per location, a results sting) with intensity done by crossfading between two decks. For launch, **commission 3 stemmed tracks** (Corner Shop, Bank, Christmas) under a contract that covers Roblox, trailers and streams. Price [UNVERIFIED]. AI music is acceptable only under commercial terms at generation time, with the terms saved (vault: *AI Audio*).

**Launch SFX (about 38 sounds; anything that repeats gets 3 or more variations):**

| Group | Sounds | Bus | Caption |
|---|---|---|---|
| Time | clack, tape-stop, rewind whirr (per track), clunk, tape-runs-out, take stamp, echo chime ×8, glitch, tape-chew | UI / Echo / SFX | "[Rewinding]", "[Echo busted]" |
| Mechanisms | plate down/up, cable whum, door slide, lock, door beep, laser hum, laser off, flicker, zap | SFX | "[Door closing]", "[Lasers back on]" |
| Guard | footsteps ×4, radio bed, "?" murmur, "!" sting, wah-wah | SFX / Warnings | "[Guard suspicious]", "[Spotted!]" |
| Loot | clink ×3, diamond shimmer, carry jingle, drop thud, ka-ching, coin burst, tick, done | SFX / UI | none (shown visually) |
| Countdown | 10-1 ticks rising in pitch, last-3 heartbeat | Warnings | "[10 seconds]" |
| UI and ambience | hover, press, back, toggle, error, medal ×3; street bed, bank room tone, vault hum | UI / Ambience | none |

- **Mix** (vault *Audio API* §6): faders for **Music, SFX (with an Echo sub-bus), UI, Ambience and Warnings**, then Master, Compressor, Limiter and Output. Warnings ignore the Music slider and have an Alerts slider with a 25% floor. Starting targets, to be measured: SFX -18 LUFS, Echo -22, UI -24, Music -22 in play and -16 in menus, Warnings -16. Music ducks 4 dB for 0.6 s on caught, diamond and complete.
- **Rules:** every sound has a bus and cosmetic sounds play on the client. Onsets are trimmed under 10 ms and first-impression sounds are preloaded. An id manifest records source, licence and uploader, and live load checks catch silent ids.

### D6. UI/UX

**HUD (four elements, everything else contextual):**
1. **Top centre, tape counter and take bar:** monospaced "0:27" next to "TAKE 3", with a thin timeline below showing icons for your echoes' recorded events (design.md's timeline bar). In the last 10 s the counter pulses 1.0 → 1.06 each second (colour-only under reduced motion). In the last 5 s it turns Alarm Red and gains a ring glyph.
2. **Top left, loot meter:** "$400 / $1,000" with a bar that counts up.
3. **Top right, Echo Deck strip:** one pip per echo (glyph, digit, hue). A busted echo turns grey with a ✕. Tapping opens Retake or Delete (design.md).
4. **Bottom right, REWIND:** 72 px with a "◀◀" icon. In co-op it shows "READY 1/2". R on keyboard, Y on gamepad. Interact is a custom-styled `ProximityPrompt`.
- **Objective line:** one line of 8 words or fewer, shown only when it changes or when the player is stuck. It replaces the current multi-line list. A **hide-HUD** toggle (H, or Settings) keeps the counter visible. Text is at least 14 px on phones and sits in the `CoreUISafeInsets` area.

**Planning ("Blueprint" in visuals.md):** a top-down diorama opened from the van before take 1, or between takes (hold TAB, or a 2-finger tap). It shows plates with cables, the guard route and cone, loot values, and in later levels the echo routes in owner colours. **P2:** a scrubbable "tape timeline" to preview where the crew is at any second.

**Level select:** VHS tapes on a shelf with medal stickers on the spines. A 3D corkboard hideout comes in P2.

**Accessibility (launch):**
- Every echo signal uses glyph plus number plus colour. Plates carry icons. Danger always comes with a shape.
- Captions are on by default, use `PreferredTransparency`, have three sizes, and follow the D5 cue list (priority: Warnings 10, mechanisms 5).
- A `Comfort` module: reduced motion (Follow / On / Off), shake 0-100% (default 50%, 0% under reduced motion), a 3/s flash cap, an FOV-kick toggle, echo opacity, and the Rewind mode (tap or hold) and quick-rewind settings.
- A **"Relaxed Time"** assist makes loops 1.5x longer. It is flagged on the results card and excluded from the Vault of the Day leaderboard. Precedents: Moving Out's assist ([GamesRadar](https://gamesradar.com/moving-out-developer-talks-accessibility-we-want-everyone-to-be-able-to-finish-it-and-everyone-to-be-able-to-play)) and the Game Accessibility Guidelines ([basic](https://gameaccessibilityguidelines.com/basic/), [intermediate](https://gameaccessibilityguidelines.com/intermediate/)).
- A photosensitivity line in the game description.

**Localization:** every string is a key in a source CSV kept in Git. Use `FormatByKey` with named placeholders, and bake no text into images (tape labels are TextLabels). The source language is English, with auto-translation for the 16 languages. **Danish needs a manual table.** Short labels leave room for German. Size controls with `AutomaticSize`.

### D7. Onboarding: the echo taught in under 60 s, with 30 words or fewer

**Level 1 "Back Room" (Corner Shop, 30 s loop):**

| t | The player does | The game shows | Text |
|---|---|---|---|
| 0-8 s | Spawns at the van | Shop door shut. A glowing plate with a cable to the door. The register is visible through the glass. | "Step on the plate" |
| 8-14 s | Steps on and off | The door opens, then the cable drains and the door shuts | none |
| 14-20 s | Realises they can't hold the plate and go through | After 2 s near the door, REWIND pulses | "Rewind. Your past self will help." |
| 20-22 s | Rewinds (the first rewind is a quick one) | The rewind look | none |
| 22-30 s | Watches | **The echo forms (chime) and walks to the plate.** The door opens. | "That's you, 10 seconds ago." |
| 30-45 s | Grabs the cash and runs | Gold chevrons to the van | "Bank it at the van" |
| ≈45 s | **First reward:** ka-ching, coins, count-up | "TAKE 2 · $100" | none |
| 45-120 s | Laser plate (needs 2 echoes), then the medals | Objective only when stuck | 9 more words at most |

- **Stuck hints** step up at 8, 16 and 24 s without progress; A/B test 6 s against 10 s for the first. The steps are: re-pulse the cable and plate; a beam from your feet; then the **Mentor tape**, a gold pre-recorded developer ghost that performs the step once (the vault's ghost-player pattern, a natural fit for us). Progress resets the timer. A step the player has done unhinted never hints again.
- **The mistake gag (Level 2):** route the guard so that the most natural first path gets your echo caught on the next take. The confused guard teaches "echoes repeat mistakes" without words, and that is where Retake is introduced.
- **Rules:** no offers during the FTUE, returning accounts can skip it, progress is saved per step, and friends who join drop straight in (GAME_BIBLE §7.1).
- **Funnel `FTUE_v1`** (server-only, forward-only): Joined, FirstMove, FirstPlate, FirstRewind, FirstEchoSeen, EchoOpenedDoor, FirstGrab, FirstBank, L1Complete, L2Started, FirstEchoBusted, Minute10. Hints and skips are logged as custom events with the step id. Track the time between steps. Targets: first echo within 30 s, first bank within 60 s, at least 90% per step, at least 70% reaching L1Complete.

## Phased plan for this dimension

| Phase | When | Build | Exit gate |
|---|---|---|---|
| **P0 Feel gate** | Nov 12-19 | Comfort and Settings modules. AudioBus (5 faders, Echo sub-bus, Warnings). RewindDirector v1 (grade, tape-stop, whirr, clunk, stamp, streak reel). `Config.REWIND_TRANSITION`. Effects moved to `CurrentCamera`. Echo arpeggio. Glyph badges and the new palette. Group Highlights. Plate cables and drain. Door fix. Guard floor cone. Bank count-up and coins. Last-10 s countdown. 8 caption cues. Licensed placeholder music on two decks. | 5 testers: 4 of 5 rewind unprompted within 30 s; 3 or more say "satisfying" or "funny"; under 33 ms frame time with 8 echoes on a mid-range phone |
| **P1 Launch must-have** | Nov 19-Dec 10 | Client echo replay and future-path telegraph. Echo failure states. FTUE, Mentor tape and funnel. HUD v1 and hide-HUD. Static Blueprint. Results card and Heist Reel. Full SFX set (licensed, levelled, manifest). Crew Layers (commissioned Shop and Christmas stems, or the fallback). Localization keys. Relaxed Time. Quick rewind. 7-viewport pass. | Soft launch: at least 70% reach L1Complete; median first bank 60 s or less; 0 unlevelled audio ids; 0 UI overlaps; quality-score UI and tutorial at 8.5 or higher |
| **P2 Post-launch** | Jan+ | Echo Choir, tape timeline, 3D hideout, haptics (plate, caught, bank, `ClickHaptic`), streamer mode, echo cosmetic trails, Danish table, reel camera presets | D1/D7 against the soft-launch baseline; clip-share rate |

**Must-have:** D1 (all three variants), D2 except the Choir, D3, D4, the D5 SFX set and mix with at least the fallback music, the D6 HUD with accessibility and localization keys, and all of D7. **Later:** the remaining commissioned stems, Choir, tape timeline, 3D hideout, haptics, streamer mode.

## Risks

1. **Visual noise at 16 echoes** (the Monaco critique). *Mitigation:* proximity fade, rims instead of fills, trails only while moving, badges hidden beyond 40 studs, and frames reviewed at 160x90.
2. **Rewind fatigue** (the Braid review). *Mitigation:* the 1.8, 1.0 and 0.8 s variants and an automatic switch to quick from the 4th rewind.
3. **Licensing.** Library stems don't exist, and off-platform use is [UNVERIFIED]. *Mitigation:* the fallback music plan, trailer rights in commission contracts, owned music in every TikTok, and a manifest with live load checks.
4. **Local stem drift.** *Mitigation:* always use `Play(atTime)`, and resync on the next bar if drift exceeds 20 ms.
5. **Client visuals vs server authority.** Replay and telegraph are visual only; plates, lasers and the guard stay server decisions from `Actors`. *Mitigation:* client and server read the same recording frames, and the client renders about 100 ms behind (vault: *Snapshot Interpolation*).
6. **Mobile GPU cost.** *Mitigation:* 4 persistent Highlights, Blur only during the 1.2 s rewind, Bloom 0.5 on the performance tier, and frame time measured on a real phone in P0.
7. **Colour identity is still weak.** *Mitigation:* glyph and number are mandatory, not a setting, and a Lune CI test runs the Oklab audit so new art cannot regress it.
8. **Timings inline instead of in Config** (the 0.9 s delay already is). *Mitigation:* every duration here becomes a Config entry (`REWIND_TRANSITION`, `ECHO_SPAWN_STAGGER`, `GUARD_DETECT_SECONDS`, `HINT_DELAYS`, `MUSIC_BPM`).

## Sources

**Web:** [Voxagon Teardown notes](https://blog.voxagon.se/2020/11/05/teardown-design-notes.html) · [PC Gamer Teardown](https://pcgamer.com/teardown-review) · [Press Start Teardown](https://press-start.com.au/reviews/xbox-series-x-reviews/2023/11/15/teardown-review-break-stuff/) · [Superhot Wikipedia](https://en.wikipedia.org/wiki/Superhot) · [Kill Screen Superhot](https://www.killscreen.com/superhot-wants-get-inside-your-brain-and-change-how-you-think/) · [GamesRadar Superhot](https://www.gamesradar.com/superhot-fps-only-moves-when-you-do) · [GameSpot Braid music](https://www.gamespot.com/articles/spot-on-the-music-of-braid/1100-6197644/) · [Game Developer Braid-style rewind](https://gamedeveloper.com/programming/braid-style-rewind-system-01) · [Giant Bomb Braid](https://giantbomb.com/user-reviews/id/1114/you-are-your-own-castle) · [GamesRadar LiS](https://www.gamesradar.com/life-strange-video-shows-time-rewinding-troubles/) · [PC Gamer LiS](https://www.pcgamer.com/au/life-is-strange-dev-diary-discusses-time-travel) · [GamesBeat Monaco](https://gamesbeat.com/monaco-review/) · [Kill Screen Monaco](https://www.killscreen.com/kill-screen-review-monaco-will-steal-your-time-and-your-heart/) · [Giant Bomb Monaco](https://giantbomb.com/reviews/monaco-what-s-yours-is-mine-review) · [Game Developer Hitman GO](https://www.gamedeveloper.com/design/for-square-enix-designing-i-hitman-i-as-a-board-game-just-made-sense) · [Kotaku Hitman GO](https://kotaku.com/the-latest-hitman-game-was-inspired-by-the-rich-kids-of-1569825822) · [Game Developer Goose score](https://gamedeveloper.com/audio/getting-goosey-with-debussy-creating-an-adaptive-score-for-i-untitled-goose-game-i-) · [FMOD Goose](https://www.fmod.com/blog/untitled-goose-game-interview) · [DiGRAA Goose paper](https://digraa.org/wp-content/uploads/2020/01/DiGRAA_2020_paper_47.pdf) · [TV Tropes Payday 2](https://tvtropes.org/pmwiki/pmwiki.php/AwesomeMusic/PAYDAY2) · [Steam Payday thread](https://steamcommunity.com/app/1272080/discussions/0/3800527434456095994) · [Steam ghosts thread](https://steamcommunity.com/app/1097130/discussions/0/3124911622551642956) · [Openplanet Too Many Ghosts](https://openplanet.dev/plugin/toomanyghosts) · [freegamedev ghosts](https://forum.freegamedev.net/viewtopic.php?p=58693) · [RoWatcher sound design](https://rowatcher.com/news/sound-design-roblox-s-most-underrated-competitive-edge) · [PC Gamer Overcooked](https://www.pcgamer.com/au/overcooked-review) · [GamesRadar Moving Out](https://gamesradar.com/moving-out-developer-talks-accessibility-we-want-everyone-to-be-able-to-finish-it-and-everyone-to-be-able-to-play) · [Juice it or lose it](https://roblog.co.uk/2024/03/juicy-games/) · [Swink](https://www.gamedeveloper.com/design/principles-of-virtual-sensation) · [Bonn HUD study](https://bonndoc.ulb.uni-bonn.de/xmlui/handle/20.500.11811/14207) · [Roblox audio assets](https://create.roblox.com/docs/audio/assets) · [Audio privacy](https://devforum.roblox.com/t/1701697) · [Free music thread](https://devforum.roblox.com/t/finding-free-music-for-your-games-both-in-and-off-platform/2179490) · [Reverse sound](https://devforum.roblox.com/t/how-can-i-make-a-sound-play-in-reverse/1847141) · [Reupload reversed](https://devforum.roblox.com/t/reuploading-roblox-audio-in-reverse/1471171) · [AudioPlayer debounced](https://devforum.roblox.com/t/audioplayer-is-debounced/4743400) · [HapticEffect](https://create.roblox.com/docs/reference/engine/classes/HapticEffect) · [Haptics release](https://devforum.roblox.com/t/full-release-you-can-now-publish-haptic-effects-in-your-experience/3660577) · [AnalyticsService](https://create.roblox.com/docs/en-us/reference/engine/classes/AnalyticsService) · [Auto-translation docs](https://create.roblox.com/docs/en-us/production/localization/automatic-translations.md) · [Roblox translation model](https://about.roblox.com/newsroom/2024/02/breaking-down-language-barriers-with-a-multilingual-translation-model) · [RoLearn mobile](https://rolearn.dev/trend-reports/roblox-mobile-gaming-trends-2026) · [HostingAdvice](https://www.hostingadvice.com/studies/roblox-statistics/) · [GameDevReports](https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox) · [GAG basic](https://gameaccessibilityguidelines.com/basic/) · [GAG intermediate](https://gameaccessibilityguidelines.com/intermediate/) · [Okabe-Ito](https://conceptviz.app/fr/blog/okabe-ito-palette-hex-codes-complete-reference)

**LihFolk Vault V2:** Game Feel and Juice; Hit-Stop and Screen Shake Tuning by Numbers; Comfort Toggles; Screen Damage Effects; Atmosphere Sky Clouds and Post-Processing; Music and Adaptive Audio; The Audio API; Spatial Audio and Mixing; Sound Fundamentals; Music Licensing and Audio Upload Rules for 2026; AI Audio; Captions and Audio Accessibility; Colour-Blind Safe Design; Motion Sensitivity and Camera Comfort; Highlights and Selection Effects; Reward Moments and Celebrations; HUD Design; Localization; Onboarding and FTUE; Measuring Onboarding; Snapshot Interpolation. **Skills:** lihfolk-vfx, lihfolk-sfx, lihfolk-tutorial, roblox-ui-builder.

**Live Roblox data (2026-11-12):** `rbx_search.py` for "heist", "time loop", "rewind" and "doors". No record-and-replay crew game appeared; the "Rewind" titles are troll towers and obbies. Games API: DOORS 16,976 playing / 8.02 B visits, Notoriety 1,518 / 566 M, ROB IT 2,008 / 315 M, Think Twice 2,927 / 36 M.

**Project:** README, PROJECT_STATE, `src/client/init.client.luau`, `src/server/Echoes.luau`, `src/server/Main.luau`, `src/shared/Config.luau`, GAME_BIBLE / VIRAL_PLAYBOOK / IDEA_ECHO_HEIST (grep), docs/research/visuals.md and design.md (grep).
