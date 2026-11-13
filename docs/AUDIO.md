# AUDIO: cue sheet, mix and wiring

_Audio track, 2026-11-12. MASTERPLAN §7.1-7.3, docs/research/feel.md D2-D5, lihfolk-sfx._

**Status.** 77 cues and 7 music sets. **76 of 77 cues have real, Roblox-licensed ids** and every music set
has real tracks. The audio pass of 2026-11-13 filled the 29 cues that were empty (Gus's beats, world feedback,
signature moments, the van-door wipe, the 13 intro cues, Heartbeat and a stand-in RewindStinger) from the APM
and Pro Sound Effects partner catalogues: see "Audio pass 2026-11-13" under the Gus cue sheet and the **owner
audition list** (§13). Only **GusStep** is still empty (no human footsteps in any partner catalogue). 191 distinct
ids in `src/shared/Audio/Manifest.luau` (143 used + 48 audition alternates), every one returned by the Creator Store
API from a licensed creator and every one **loaded in a real Roblox server** (`tests/audio_engine.luau`, Saved
place version 78: 191/191 ready, every cue and set with ids loads at least one take, store and engine lengths
agree). The AudioDirector built its graph in a real server (77 wires, all connected, `GetMixerTime` available)
and ran every API call without an error.

| File | What |
|---|---|
| `src/shared/Audio/Cues.luau` | the cue table (ids, alternates, search words, bus, volume, pitch/volume jitter, voices, cooldown, priority, rolloff, loop/choke/duck, tonal ladders, captions, audition notes), the music sets and states |
| `src/shared/Audio/Manifest.luau` | generated: what the Creator Store said about each id (creator, creator id, title, seconds, type, artist, album, upload date) and the licensed creator ids |
| `src/shared/Audio/CueCheck.luau` | pure validation of Cues against Manifest + Config.Audio ("Cue rules") and the summary counts |
| `src/shared/Audio/Voices.luau` | pure voice rules: cooldown, per-cue cap, choke, global cap with priority stealing, clone rate and nearest-4, round-robin bag |
| `src/shared/Audio/Mix.luau` | pure mix maths: dB, slider curve, Warnings floor, ducks, Crew Layers tier and set gains, tonal ladders, arpeggio spacing, bar grid, countdown, Christmas window |
| `src/shared/Audio/EventCues.luau` | pure map from each replicated sim event (Sim/EventLog.EV) to its cues, position and clone routing |
| `src/shared/Audio/LoadCheck.luau` | live load check: loads every Manifest id in a real server or client and reports silent ids |
| `src/client/Audio/AudioDirector.luau` | the client player: Audio API graph, pooled voices, buses, clone bus, music decks, Crew Layers, rewind tape-stop, ducking, settings hooks |
| `src/shared/Config.luau` `Config.Audio` | every shared mix and timing number |
| `tests/unit/AudioCues.spec.luau`, `AudioVoices.spec.luau`, `AudioMix.spec.luau`, `AudioEvents.spec.luau` | 39 Lune specs |

## 1. Decision: the Audio API, not Sound/SoundGroup

The vault (*The Audio API - Players Emitters Wires and Effects*, *Music and Adaptive Audio*, lihfolk-sfx
"Classic Sound vs the Audio API") recommends the Audio API for new work and the classic API only for broad
compatibility in small games. This game needs three things only the Audio API has:

1. **Crew Layers**: several music players started on the same sample with `AudioPlayer:Play(atTime)` on
   `SoundService:GetMixerTime()` (the S4 primary method; `task.delay` and sequential `Play()` drift).
2. **The clone bus**: a real effect chain (lowpass 5 kHz -> 90 ms echo -> -4 dB) that every clone sound
   passes through, 2D and 3D alike. With SoundGroups this means effects per group and no 3D routing.
3. **Faders as buses** with a master compressor and limiter, and music ducking by fader.

Costs, handled: 3D needs listeners (one `AudioListener` per positional bus on the camera, separated by
`AudioInteractionGroup` "EH_SFX" / "EH_Clone" / "EH_Warnings", re-parented when `CurrentCamera` changes);
`AudioPlayer.Volume` defaults to 1 (cue volumes are authored for that); `Play`/`Stop` do not reset
`TimePosition` (the director sets it to 0 before every start). The engine's default listener is only created
in voice-chat experiences and has no interaction group, so it never double-hears our emitters; leave
`SoundService.DefaultListenerLocation` at Default. The v0.1 prototype and `RewindDirector.sound` (classic
`Sound`) keep working until they are rewired.

## 2. Graph and mix

```
cue voices (2D) ----------------------------------------> SFX | UI | Ambience | Warnings | Music faders --\
cue voices (3D) -> AudioEmitter (EH_<bus>) ... AudioListener EH_<bus> on the camera -> bus fader          |
clone voices -> CloneIn -> AudioFilter Lowpass12dB 5 kHz -> AudioEcho 90 ms, fb 0.15, wet -12 dB          |
             -> Clone fader (-4 dB) -> SFX fader                                                          |
music set mixes -> mix faders -> set fader -> MusicDuck -> Music fader (stingers skip the duck)            |
SFX + Ambience faders -> WorldMuffle (AudioFilter Lowpass12dB, 20 kHz open, 800 Hz muffled) -> Master   |
                                        Master -> AudioCompressor (-18 dB, 3:1) -> AudioLimiter (-1 dB) -> AudioDeviceOutput
```

- **World muffle** (premium §6.2): `AudioDirector.muffle(on)` sweeps the `WorldMuffle` low-pass to 800 Hz in
  0.1 s and back open in 0.25 s (`Config.Audio.MUFFLE_*`). The rewind uses it from the start to the snap.

- **Buses** (`Config.Audio.BUS_DB`, dB at a full slider): Music -6, SFX 0, Clone -4 (under SFX), UI -6,
  Ambience -10, Warnings +2. Starting points from feel.md D5; re-level after the loudness pass.
- **Sliders** 0..1 map to `gain = slider ^ 2`. The Clone bus follows the SFX slider. **Warnings** (alarm,
  countdown, "?", "!", busted) keep at least 25 % (`WARNINGS_FLOOR`) and ignore the Music slider. Mute all
  silences Warnings too (`MUTE_KEEPS_WARNINGS = false`); captions still show.
- **Voices**: 24 live (16 on touch-only devices), 30 ms default cooldown, 4 per cue, priority stealing
  (lowest, oldest first, never a higher priority). Clone sounds: at most 6 starts per rolling second and the
  nearest 4 voiced. Positional sounds beyond their rolloff max never start. Takes are round-robin, never the
  same twice in a row; pitch +-4 % and volume +-8 % jitter, none on tonal stings and ladders.
- **Ducking**: cues with `duck` (GusAlert, Busted, DiamondShimmer, HeistFanfare) duck the music 4 dB for
  0.6 s (attack 0.05 s, release 0.25 s); ducks never stack. During the rewind, Ambience and the Clone bus
  duck 9 dB.

## 3. Music: Crew Layers with library tracks

Library music has no stems (feel.md D5), but the APM catalogue on Roblox carries **alternate mixes of the
same track at the same length** ("Alt1, NoMel", "Lite", "Underscore", "No drums mix"). The S4 fallback is
applied to those: every mix of a set starts together (same sample with `Play(atTime)`, or the same frame
with `STEM_START = "together"`), all at volume 0 but the current one, and the Crew Layers tier crossfades
which mix is heard (`MUSIC_MODE = "mixes"`). Same length means they loop together and stay aligned;
CueCheck rejects a set whose mixes differ by more than 2 s.

| Tier | Clones | Caper (story levels) | Xmas (Dec 3 - Jan 4) | BigScore (L5, L6) |
|---|---|---|---|---|
| S0 | 0 | Alt3 PizzTriangle | Sleigh Bells Underscore | Diamond Heist (c) |
| S1 | 1+ | Alt5 PizzLitePerc | Sleigh Bells Underscore | Diamond Heist (c) |
| S2 | 3+ | Alt2 Lite | Sleigh Bells Version | Diamond Heist (b) |
| S3 | 6+ | Alt1 NoMel | Sleigh Bells Version | Diamond Heist (a) |
| S4 | 10+ | full mix | Sleigh Bells Version | Diamond Heist (a) |
| S5 chase | Alarm Run | the Chase set ("Code Heist" full mix), crossfaded in over 0.4 s | | |

- Layers change on GO (`AudioDirector.layers(n)` / `go(n)`) and fade over one bar (1.875 s).
- **Commissioned stems (D10)** drop into the same `Cues.sets` table with `MUSIC_MODE = "stems"`: S0 always
  on, each tier adds its stem (`Mix.setGains`). Set `bpm = 128` on them so the bar grid applies.
- The library tracks' tempos are unknown (`bpm = nil`): runs are not whole bars of these tracks. The music
  restarts on GO either way.
- **Christmas**: between `Config.Audio.CHRISTMAS` days (UTC) the Heist and Garage states swap to the Xmas
  and GarageXmas sets; `AudioDirector.setChristmas(true/false)` overrides. The "jingle layer" is the
  sleigh-bells mix of the Xmas set (it is the same track with bells), plus the SleighBells sparkle cue.
- **Off-platform**: none of these tracks may go into TikToks or trailers (Roblox-only licence; §7.2).

## 4. Rewind sound sequence (§7.1)

| t (s) | Call | Sound |
|---|---|---|
| input | `play("RewindClack")` in the END RUN action | tape-deck clack, locally, before any server reply |
| 0.00 | `AudioDirector.rewind()` when the transition starts | music `PlaybackSpeed` 1.0 -> 0.25 over 0.3 s and out (plain fade under reduced motion), TapeStop cue, Ambience + Clone duck 9 dB |
| 0.00 | `AudioDirector.muffle(true)` (Heist/RewindDirector, `Config.Moments.REWIND.MUFFLE`) | the world muffled: SFX (with the Clone bus) and Ambience through the `WorldMuffle` low-pass, 20 kHz -> 800 Hz in 0.1 s (`Config.Audio.MUFFLE_*`); UI, Warnings and music stay clear |
| 0.10 | `play("RewindWhirr")` + `play("RewindStinger")` at scrub start | fast film rewind whirr; the stinger (a licensed reverse swell at 1.9x, 1.36 s) until the owner's reversed bar |
| 1.35 | `AudioDirector.muffle(false)`, `play("RewindClunk")`, `AudioDirector.arpeggio(clones)` | the world opens again over 0.25 s; clunk on the bar line, then one chime per clone, 60 ms apart, C D E G A c d e (squeezed to 0.4 s) |
| 1.55 | `play("RunStamp")` | the "RUN n" stamp |
| 1.80 | `AudioDirector.go(clones)` when control returns | music restarts from the top on the downbeat at the new tier; ducks release |

## 5. Cue sheet

Every id below came back from the Creator Store API on 2026-11-12 and loaded in a real server. Durations
are the store's rounded seconds. "Alternates" are candidates from the same search that are not loaded:
audition and swap. Volumes are starting levels for un-normalised library files.

### Time (rewind)

| Cue | Bus | Takes (id "title" (creator, s)) | Alternates | Vol | Jitter | Voices | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| RewindClack | SFX | 9119716019 "Switch Cassette Deck Dbx Buttons Clicks 7 (SFX)" (ProSoundEffects, 0 s); 9119716036 "Switch Cassette Deck Dbx Buttons Clicks 9 (SFX)" (ProSoundEffects, 0 s); 9119715824 "Switch Cassette Deck Dbx Buttons Clicks 6 (SFX)" (ProSoundEffects, 0 s) |  | 0.70 | 0.03 | 2 | 0.1 |  |
| TapeStop | SFX | 9120059083 "Time Wave Intense Fluttering Slow Down 2 (SFX)" (ProSoundEffects, 1 s) | 9120059060 "Time Wave Intense Fluttering Slow Down 1 (SFX)" (ProSoundEffects, 3 s) | 0.60 | 0 | 1 | default |  |
| RewindWhirr | SFX | 9114413015 "Film Rewind 2 (SFX)" (ProSoundEffects, 1 s) | 9114452629 "Fishing Reel 6 (SFX)" (ProSoundEffects, 1 s) | 0.55 | 0.02 | 1 | default |  |
| RewindStinger | Music | 9040537602 "Existence Is Futile Short Swell" (APM, 2.59 s) | 9040531832 "Anarchy Reverse Swell" (APM, 2.74 s); 9046338511 "Smoldering Fate Swell" (APM, 3.08 s) | 0.70 | 0 | 1 | default | pitch 1.9 |
| RewindClunk | SFX | 9126019188 "Switches Otari Tape Recorder Turn On Clicks  (SFX)" (ProSoundEffects, 1 s); 9119725282 "Switches Otari Tape Recorder Clicks 9 (SFX)" (ProSoundEffects, 1 s); 9119725132 "Switches Otari Tape Recorder Clicks 7 (SFX)" (ProSoundEffects, 1 s) |  | 0.70 | 0.03 | 2 | default |  |
| RunStamp | UI | 9114026047 "Date Stamp Big Office Impact Good Squeak 2 (SFX)" (ProSoundEffects, 1 s); 9114025631 "Date Stamp Big Office Impact Good Squeak 2 (SFX)" (ProSoundEffects, 1 s); 9114025813 "Date Stamp Big Office Impact Good Squeak 8 (SFX)" (ProSoundEffects, 1 s) |  | 0.80 | 0.03 | 3 | 0.08 |  |
| CloneChime | Clone | 9126073001 "Synth Sparkle Tone High Pitch Bell Tone Ding (SFX)" (ProSoundEffects, 1 s) |  | 0.55 | 0 | 8 | 0 | stepped |
| CloneBusted | SFX | 9119901860 "Synth Zap High Pitch Video Breakup Glitch 4 (SFX)" (ProSoundEffects, 1 s); 9119901748 "Synth Zap High Pitch Video Breakup Glitch 2 (SFX)" (ProSoundEffects, 1 s); 9119902088 "Synth Zap High Pitch Video Breakup Glitch 6 (SFX)" (ProSoundEffects, 1 s) |  | 0.60 | default | 3 | default | 3D mid, clone bus, caption [Clone busted] |
| CountdownTick | Warnings | 9114071134 "Dial Switch Twisting Sharp Ticking 79 (SFX)" (ProSoundEffects, 0 s); 9114069409 "Dial Switch Twisting Sharp Ticking 48 (SFX)" (ProSoundEffects, 0 s) |  | 0.50 | 0 | 2 | 0.2 | stepped, caption [10 seconds] |
| Heartbeat | Warnings | 9043367376 "PERCUSSIVE NOISE 05-Kick 02" (APM, 0.44 s) | 9043367283 "PERCUSSIVE NOISE 04-Kick 01" (APM, 0.44 s); 9119882039 "Synth Whomps 38" (PSE, 0.94 s) | 0.60 | 0 | 1 | 0.25 |  |

### Mechanisms

| Cue | Bus | Takes (id "title" (creator, s)) | Alternates | Vol | Jitter | Voices | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| PlatePress | SFX | 9125626478 "Lever Mechanism Crank Clicks Big Metal Clunk (SFX)" (ProSoundEffects, 1 s); 9125626484 "Lever Mechanism Crank Clicks Big Metal Clunk (SFX)" (ProSoundEffects, 2 s); 9125626281 "Lever Mechanism Crank Clicks Big Metal Clunk (SFX)" (ProSoundEffects, 2 s) |  | 0.60 | default | 4 | default | 3D mid, clone bus |
| PlateRelease | SFX | 9120484397 "Wall Light Switch 3 (SFX)" (ProSoundEffects, 1 s); 9120484641 "Wall Light Switch 3 (SFX)" (ProSoundEffects, 1 s); 9120484192 "Wall Light Switch 2 (SFX)" (ProSoundEffects, 1 s) |  | 0.45 | default | 4 | default | 3D mid, clone bus |
| CableWhum | SFX | 9114245761 "Electric Hum 10 (SFX)" (ProSoundEffects, 1 s); 9114245917 "Electric Hum 12 (SFX)" (ProSoundEffects, 1 s) |  | 0.35 | default | 4 | default | 3D mid, clone bus |
| DoorOpen | SFX | 9117719772 "Pneumatics Servos Short Metallic Slides 6 (SFX)" (ProSoundEffects, 1 s) |  | 0.70 | default | 3 | default | 3D mid |
| DoorClose | SFX | 9117721077 "Pneumatics Servos Short Metallic Slides 9 (SFX)" (ProSoundEffects, 2 s) | 9119631707 "Steel Door 3 (SFX)" (ProSoundEffects, 3 s) | 0.70 | default | 3 | default | 3D mid, caption [Door closing] |
| DoorLock | SFX | 9114144270 "Door Lock Turn Deadbolt 11 (SFX)" (ProSoundEffects, 1 s) |  | 0.60 | default | 3 | default | 3D mid |
| DoorBeep | Warnings | 9113880475 "Computer Keyboard Beep 3 (SFX)" (ProSoundEffects, 0 s) |  | 0.35 | 0 | 2 | 0.2 | 3D near |
| LaserHum | SFX | 9116270244 "Light Bulb Buzz 3 (SFX)" (ProSoundEffects, 8 s) | 9114246115 "Electric Hum 15 (SFX)" (ProSoundEffects, 3 s) | 0.22 | 0.03 | 8 | 0 | loop, 3D near |
| LaserOff | SFX | 9117869243 "Power Down 1 (SFX)" (ProSoundEffects, 1 s) |  | 0.55 | default | 3 | default | 3D mid |
| LaserFlicker | SFX | 9126027558 "Switches Video Monitors On Off Electric Hum  (SFX)" (ProSoundEffects, 1 s) |  | 0.50 | default | 3 | default | 3D mid, caption [Lasers back on] |
| LaserZap | SFX | 9118068265 "Reactor Ignition Large Electrical Zaps 3 (SFX)" (ProSoundEffects, 1 s); 9118068267 "Reactor Ignition Large Electrical Zaps 1 (SFX)" (ProSoundEffects, 1 s) | 9119594928 "Static Zap Impact Gun Shot Buzz Twice 2 (SFX)" (ProSoundEffects, 2 s) | 0.70 | default | 3 | default | 3D mid, clone bus, caption [Zapped] |

### Gus

| Cue | Bus | Takes (id "title" (creator, s)) | Alternates | Vol | Jitter | Voices | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| GusStep | SFX | **none yet**: search "footsteps hard shoes concrete walk" |  | 0.35 | 0.06 | 2 | 0.15 | 3D near |
| GusRadio | SFX | 9120456889 "Walkie Talkie 12 (SFX)" (ProSoundEffects, 1 s); 9120458059 "Walkie Talkie 5 (SFX)" (ProSoundEffects, 1 s); 9120456241 "Walkie Talkie 1 (SFX)" (ProSoundEffects, 1 s) |  | 0.30 | default | 1 | 4 | 3D near |
| GusHuh | Warnings | 9045118824 "Sneaky Schemes - Hit2" (APMOfficial, 2 s) |  | 0.60 | 0 | 1 | 0.5 | caption [Guard suspicious] |
| GusAlert | Warnings | 9045118821 "Sneaky Schemes - Hit1" (APMOfficial, 2 s) |  | 0.80 | 0 | 1 | 0.5 | ducks music, caption [Spotted!] |
| Busted | Warnings | 1840568386 "Trumpet Wah-Wah (N)" (APMOfficial, 4 s); 1840568339 "Trumpet Wah-Wah (L)" (APMOfficial, 4 s) |  | 0.70 | 0 | 1 | 0.5 | ducks music, caption [Guard spotted you] |
| GusKeys | SFX | 9116177077 "Keys Movement 2" (PSE, 1.43 s); 9116177509 "Keys Movement 9" (PSE, 1.37 s); 9125616843 "Keys Handling Small Ring With Metal Clinks G" (PSE, 0.84 s); 9125616819 "Keys Handling Small Ring With Metal Clinks G" (PSE, 1.20 s) | 9116177238 "Keys Movement 6" (PSE, 1.76 s) | 0.40 | 0.08 | 1 | 0.3 | 3D near; every 2nd step on patrol |
| GusSnore | SFX | 9113862562 "Comic Snoring Male Vocals Steady Pace 1" (PSE, 4.76 s); 9113862741 "Comic Snoring Male Vocals Steady Pace 4" (PSE, 5.54 s); 9113862894 "Comic Snoring Male Vocals Steady Pace 6" (PSE, 5.90 s) | 9113862899 "Comic Snoring Male Vocals Steady Pace 8" (PSE, 5.88 s); 9113862891 "Comic Snoring Male Vocals Steady Pace 7" (PSE, 5.73 s) | 0.50 | 0.05 | 1 | 2 | 3D near; one per nod while he dozes, caption [Gus snores]; pitch 1.15 |
| GusBarkHey | SFX | 9118909467 "Sergeant Shouts 3" (PSE, 0.77 s); 9118910037 "Sergeant Shouts 11" (PSE, 0.95 s); 9118910062 "Sergeant Shouts 9" (PSE, 0.96 s) | 9118909743 "Sergeant Shouts 6" (PSE, 1.20 s) | 0.65 | 0.04 | 1 | 1 | 3D mid; wake-startle and chase start, caption [Gus: Hey!] |
| GusBarkHm | SFX | 9116453449 "Male Reaction 2" (PSE, 0.73 s); 9116453436 "Male Reaction 3" (PSE, 0.65 s); 9116453647 "Male Reaction 4" (PSE, 0.61 s) | 9116453396 "Male Reaction 1" (PSE, 1.39 s); 9116453659 "Male Reaction 5" (PSE, 0.81 s) | 0.60 | 0.04 | 1 | 1 | 3D mid; the double-take snap, caption [Gus: Hm?] |
| GusBarkGotcha | SFX | 9120415730 "Video Game Effects 1" (PSE, 0.84 s); 9120416707 "Video Game Effects 15" (PSE, 0.67 s); 9120416355 "Video Game Effects 11" (PSE, 0.73 s) | 9120416077 "Video Game Effects 6" (PSE, 1.00 s); 9120415788 "Video Game Effects 2" (PSE, 0.56 s) | 0.65 | 0.04 | 1 | 1 | 3D mid; the catch lunge, caption [Gus: Gotcha!] |
| GusBarkWrongOne | SFX | 9114877032 "Intercom Vocals Male What Huh Pa Clicks 1" (PSE, 1.04 s); 9114877145 "Intercom Vocals Male What Huh Pa Clicks 4" (PSE, 1.11 s); 9114877072 "Intercom Vocals Male What Huh Pa Clicks 2" (PSE, 1.27 s) |  | 0.70 | 0.04 | 1 | 1 | 3D mid; busted a clone, caption [Gus: Wrong one?!] |

#### Audio pass 2026-11-13 (the cues that were empty)

The tracks that added these cues (Gus, world feedback, signature moments, presentation, intro) left them with empty
`ids`. Every id below came back from `toolbox-service/v1/marketplace/3` with `creatorTargetId` set to a licensed
partner, its row in Manifest.luau is the `items/details` response, and it loaded in a real server (AudioPlayer
`IsReady`, engine `TimeLength` in the tables; `GetProductInfoAsync` names the same creator). Licence: Roblox-only
partner audio ("owned and uploaded by Roblox or our music and SFX partners will remain public and usable by anyone in
any experience"); never download, re-upload or use off-platform. No id is shared with another cue (one meaning, one
sound, premium E2); repeating cues have at least 3 takes (E4); volumes follow the existing family levels (shouts and
fight yells 0.65, one-shot stings 0.6-0.7, beds 0.18-0.45) until the loudness pass. The owner auditions them in the
order of §13.

**Gus beats** (Heist/GusView). Gus's barks are library stand-ins from Pro Sound Effects voice sets: the "Hm?" and
"What?/Huh?" are real words, "Hey!" and "Gotcha!" are a sergeant's shouts and fight yells read with the caption. One
recorded actor (D10) replaces all four barks when there is one.

| Cue | Bus | Takes (id "title" (source, engine s)) | Alternates | Vol | Pitch | Source / licence | What it is |
|---|---|---|---|---|---|---|---|
| GusKeys | SFX | 9116177077 "Keys Movement 2" (PSE, 1.43 s); 9116177509 "Keys Movement 9" (PSE, 1.37 s); 9125616843 "Keys Handling Small Ring With Metal Clinks G" (PSE, 0.84 s); 9125616819 "Keys Handling Small Ring With Metal Clinks G" (PSE, 1.20 s) | 9116177238 "Keys Movement 6" (PSE, 1.76 s) | 0.4 | 1 | Pro Sound Effects (ProSoundEffects) | a metal key ring jingling (shake/rattle and two small-ring grabs) every 2nd patrol step |
| GusSnore | SFX | 9113862562 "Comic Snoring Male Vocals Steady Pace 1" (PSE, 4.76 s); 9113862741 "Comic Snoring Male Vocals Steady Pace 4" (PSE, 5.54 s); 9113862894 "Comic Snoring Male Vocals Steady Pace 6" (PSE, 5.90 s) | 9113862899 "Comic Snoring Male Vocals Steady Pace 8" (PSE, 5.88 s); 9113862891 "Comic Snoring Male Vocals Steady Pace 7" (PSE, 5.73 s) | 0.5 | 1.15 | Pro Sound Effects (ProSoundEffects) | a comic male snore at 1.15x (4.8-5.9 s files, the next nod cuts the tail) |
| GusBarkHey | SFX | 9118909467 "Sergeant Shouts 3" (PSE, 0.77 s); 9118910037 "Sergeant Shouts 11" (PSE, 0.95 s); 9118910062 "Sergeant Shouts 9" (PSE, 0.96 s) | 9118909743 "Sergeant Shouts 6" (PSE, 1.20 s) | 0.65 | 1 | Pro Sound Effects (ProSoundEffects) | a drill-sergeant shout (English orders, words not checked): the startled 'Hey!' |
| GusBarkHm | SFX | 9116453449 "Male Reaction 2" (PSE, 0.73 s); 9116453436 "Male Reaction 3" (PSE, 0.65 s); 9116453647 "Male Reaction 4" (PSE, 0.61 s) | 9116453396 "Male Reaction 1" (PSE, 1.39 s); 9116453659 "Male Reaction 5" (PSE, 0.81 s) | 0.6 | 1 | Pro Sound Effects (ProSoundEffects) | one man's breathy 'Hmm' reactions: the double-take |
| GusBarkGotcha | SFX | 9120415730 "Video Game Effects 1" (PSE, 0.84 s); 9120416707 "Video Game Effects 15" (PSE, 0.67 s); 9120416355 "Video Game Effects 11" (PSE, 0.73 s) | 9120416077 "Video Game Effects 6" (PSE, 1.00 s); 9120415788 "Video Game Effects 2" (PSE, 0.56 s) | 0.65 | 1 | Pro Sound Effects (ProSoundEffects) | short fight-effort yells ('attacking'): the catch lunge |
| GusBarkWrongOne | SFX | 9114877032 "Intercom Vocals Male What Huh Pa Clicks 1" (PSE, 1.04 s); 9114877145 "Intercom Vocals Male What Huh Pa Clicks 4" (PSE, 1.11 s); 9114877072 "Intercom Vocals Male What Huh Pa Clicks 2" (PSE, 1.27 s) |  | 0.7 | 1 | Pro Sound Effects (ProSoundEffects) | a man's 'What?' / 'Huh?' through a PA click: baffled over his radio |

**World feedback** (Heist/WorldView, docs/FEEDBACK_TABLE.md).

| Cue | Bus | Takes (id "title" (source, engine s)) | Alternates | Vol | Pitch | Source / licence | What it is |
|---|---|---|---|---|---|---|---|
| PlateHum | SFX | 9119807517 "Synth Drone Low Slightly Pulsing Idle 1" (PSE, 36.01 s) | 9116389843 "Magic Glow Constant Deep Ticking Bassy Hum 1" (PSE, 18.02 s) | 0.18 | 1 | Pro Sound Effects (ProSoundEffects) | a low, slightly pulsing synth drone loop (36 s) under a held plate |
| LaserWhine | Warnings | 9125980435 "Spaceship Pre Blast Electric Charge Up Buzzy" (PSE, 1.35 s); 9125980784 "Spaceship Pre Blast Electric Charge Up Buzzy" (PSE, 1.75 s); 9125980459 "Spaceship Pre Blast Electric Charge Up Buzzy" (PSE, 1.77 s) | 9125980113 "Spaceship Pre Blast Electric Charge Up Buzzy" (PSE, 1.80 s); 9125980176 "Spaceship Pre Blast Electric Charge Up Buzzy" (PSE, 1.91 s) | 0.4 | 1.8 | Pro Sound Effects (ProSoundEffects) | a buzzy, ringy electric charge-up at 1.8x (0.75-0.97 s) before the beams re-arm |
| LootTinkle | SFX | 9116394545 "Magic Glows Soft Clusters Of Chiming Hits 1" (PSE, 1.43 s); 9116394876 "Magic Glows Soft Clusters Of Chiming Hits 2" (PSE, 2.01 s); 9116395089 "Magic Glows Soft Clusters Of Chiming Hits 4" (PSE, 2.46 s) | 9116394756 "Magic Glows Soft Clusters Of Chiming Hits 3" (PSE, 3.33 s) | 0.3 | 1 | Pro Sound Effects (ProSoundEffects) | soft clusters of chiming, twinkling hits (magic glow) |
| VanToot | SFX | 9113438364 "Bike Horn Squeeze 1" (PSE, 1.53 s); 9113438365 "Bike Horn Squeeze 2" (PSE, 1.26 s); 9113438679 "Bike Horn Squeeze 3" (PSE, 0.73 s) | 9113438543 "Bike Horn Squeeze 4" (PSE, 0.60 s); 9113439393 "Bike Horn Squeeze 5" (PSE, 0.68 s) | 0.6 | 1 | Pro Sound Effects (ProSoundEffects) | a classic toy bike horn, squeezed (several honks per file): cheerful, nothing like the VanHorn warning |

**Signature moments** (Heist/MomentDirector, Heist/LineupDirector; PLAN_STEAM_PLUS §4.4 F1-F5). The 8 OF ME roll
call plays one `CloneChime` per copy and lands on `ChoirHit`; heist complete adds `VaultSlam` to the fanfare.

| Cue | Bus | Takes (id "title" (source, engine s)) | Alternates | Vol | Pitch | Source / licence | What it is |
|---|---|---|---|---|---|---|---|
| ChoirHit | Music | 1843088383 "Orchestra Hit High C" (APM, 10.28 s) | 1843054115 "Orchestra Hit C" (APM, 9.31 s) | 0.6 | 1 | APM Music (APMOfficial) | an orchestra + choir hit on high C (in key with the C pentatonic arpeggio), 10 s ring-out |
| SnareRoll | SFX | 9120365379 "Vaudeville Drum Stings 1" (PSE, 3.23 s) | 9120365917 "Vaudeville Drum Stings 1" (PSE, 4.22 s); 1836342006 "Short Roll" (APM, 4.54 s) | 0.55 | 1 | APM Music (APMOfficial) + Pro Sound Effects (ProSoundEffects) | a vaudeville snare roll into a muted cymbal hit with kick (3.2 s) |
| VaultSlam | SFX | 9119630175 "Steel Door 4" (PSE, 2.14 s); 9119630452 "Steel Door 6" (PSE, 2.11 s) | 9119632615 "Steel Door 8" (PSE, 2.61 s) | 0.8 | 1 | Pro Sound Effects (ProSoundEffects) | a steel door: big hollow hits with a rattling decay |

**Presentation shell** (Heist/Transition, the van-door wipe, 2D UI bus).

| Cue | Bus | Takes (id "title" (source, engine s)) | Alternates | Vol | Pitch | Source / licence | What it is |
|---|---|---|---|---|---|---|---|
| VanDoor | UI | 9119200218 "Sliding Door Grab Door Impacts Rub 2" (PSE, 0.56 s); 9119200415 "Sliding Door Grab Door Impacts Rub 3" (PSE, 0.67 s); 9119200399 "Sliding Door Grab Door Impacts Rub 5" (PSE, 0.73 s) | 9119200216 "Sliding Door Grab Door Impacts Rub 1" (PSE, 0.64 s); 9114153584 "Door Slide Open Close 1" (PSE, 1.70 s); 9119203830 "Sliding Glass Door 1" (PSE, 1.49 s) | 0.5 | 1 | Pro Sound Effects (ProSoundEffects) | a sliding door grabbed shut: short wooden impact and rub (0.56-0.73 s); alts include a slide that bangs shut |

**Time** (the rewind and the warning heartbeat; also in the Time table above).

| Cue | Bus | Takes (id "title" (source, engine s)) | Alternates | Vol | Pitch | Source / licence | What it is |
|---|---|---|---|---|---|---|---|
| RewindStinger | Music | 9040537602 "Existence Is Futile Short Swell" (APM, 2.59 s) | 9040531832 "Anarchy Reverse Swell" (APM, 2.74 s); 9046338511 "Smoldering Fate Swell" (APM, 3.08 s) | 0.7 | 1.9 | APM Music (APMOfficial) | a reverse swell at 1.9x (1.36 s), peaking on the clunk: stand-in for the owner's reversed bar |
| Heartbeat | Warnings | 9043367376 "PERCUSSIVE NOISE 05-Kick 02" (APM, 0.44 s) | 9043367283 "PERCUSSIVE NOISE 04-Kick 01" (APM, 0.44 s); 9119882039 "Synth Whomps 38" (PSE, 0.94 s) | 0.6 | 1 | APM Music (APMOfficial) + Pro Sound Effects (ProSoundEffects) | a dry kick drum from APM's Horror Tools: one low thump per call |

**Intro** (Heist/Cinematic at the times in `Shared/Heist/IntroPlan`; SKIP stops the two loops). Library stand-ins
until the D10 music commission (one 33.7 s score with these hit points; retimed 2026-11-13 for the villain close-up,
REVIEW_STEAM_PLUS #7); every caption card reads without sound. A laugh voice for the close-up (9.0-11.7 s) has no cue
yet: the caption MINE. ALL MINE. carries it.

| Cue | Bus | When (s from the first frame) | What |
|---|---|---|---|
| IntroMusic | Music, loop | 0.0 (stopped at 33.7 or on SKIP) | the score: music-box town (0-4.8), villain brass (4.8-12.4, the close-up from 9.0), suction build (12.4-19), a hush (19-24.5), caper bass (24.5-31.2), the title hit at 31.2 |
| IntroBells | Ambience | 0.2 | a soft music-box twinkle under CHRISTMAS EVE. |
| IntroHoardSting | Music | 4.8 | Hoardsworth's low brass "dun-dun" (funny-sinister, not scary) |
| IntroMonocle | SFX | 9.45 (the close-up) | the monocle glint: one bright "ting" |
| IntroLever | SFX | 11.75 | a big brass lever yanked down |
| IntroWhoosh | SFX | 12.4 | the whip-pan to the vacuum (also the slide's whoosh: Heist/Slide, Config.Slide) |
| IntroVacuumOn | SFX (ducks music) | 12.75 | the giant vacuum switching on: clunk, rising whine, roar |
| IntroSuction | SFX, loop | 13.0 (stopped at 19.0) | the suction roar under the swirl |
| IntroGlobeThunk | SFX | 19.0 | the last present thunks into the Snow Globe, then silence for ...GONE. |
| IntroLetter | SFX | 21.3 | the kid's letter fluttering down |
| IntroHeadlights | SFX | 24.5 | two heavy clunks as the van's headlights flick on |
| IntroTapePrint | Clone | 28.1 | a VHS glitch-print under the clones' entrance |
| IntroTitleSmash | Music | 31.2 | the HEIST YOURSELF title hit |

| Cue | Bus | Takes (id "title" (source, engine s)) | Alternates | Vol | Pitch | Source / licence | What it is |
|---|---|---|---|---|---|---|---|
| IntroMusic | Music | 9038463810 "Carefree Christmas" (APM, 36.36 s) | 9038464849 "Down The Chimney" (APM, 28.63 s) | 0.6 | 1 | APM Music (APMOfficial) | "Carefree Christmas" (Kosinus, Folky Christmas 2): glockenspiel, pizzicato, bells, 36.4 s |
| IntroBells | Ambience | 9119447936 "Sparkle Bell Tree Wind Chimes 1" (PSE, 5.28 s) | 9041824834 "Winter Bells" (APM, 5.56 s) | 0.45 | 1 | APM Music (APMOfficial) + Pro Sound Effects (ProSoundEffects) | a bell tree / wind-chime sparkle burst |
| IntroHoardSting | Music | 9045808575 "Sliced, Diced and Heist (sting)" (APM, 2.56 s) | 9042306864 "Evil Genius - Sting 1" (APM, 2.38 s) | 0.6 | 1 | APM Music (APMOfficial) | "Sliced, Diced and Heist": a big, brash brass drop (KPM, Cool and Quirky Horns) |
| IntroMonocle | SFX | 9116224608 "Large Metal Triangle Single Ringing Hits 13" (PSE, 0.90 s) | 9116224180 "Large Metal Triangle Single Ringing Hits 7" (PSE, 1.39 s) | 0.5 | 1 | Pro Sound Effects (ProSoundEffects) | one large triangle hit, muted by hand: a bright 'ting' |
| IntroLever | SFX | 9116259834 "Lever Two Large Metal Pulls 1" (PSE, 1.10 s); 9116260154 "Lever Two Large Metal Pulls 2" (PSE, 0.91 s) |  | 0.6 | 1 | Pro Sound Effects (ProSoundEffects) | two large metal lever pulls |
| IntroWhoosh | SFX | 9126228631 "Whoosh Back Zoom Swoosh Fast Camera In And O" (PSE, 1.93 s); 9126229255 "Whoosh By Fast Airy Swooshing Whipping Thuds" (PSE, 1.02 s) |  | 0.5 | 1 | Pro Sound Effects (ProSoundEffects) | a fast camera zoom whoosh (in and out) and an airy whip with a thud |
| IntroVacuumOn | SFX | 9117882918 "Power Up Accelerating Motors 2" (PSE, 3.52 s) | 9114583503 "Giant Servo Motor Powering Up 2" (PSE, 4.90 s) | 0.7 | 1 | Pro Sound Effects (ProSoundEffects) | accelerating motors powering up: whirring tone, airy hiss |
| IntroSuction | SFX | 9119462099 "Spiraling Wind Data Tunnel Travelling 1" (PSE, 18.00 s) | 9125742262 "Plasma Trails Constant Airy Whooshing Windy" (PSE, 33.16 s) | 0.45 | 1 | Pro Sound Effects (ProSoundEffects) | a spiraling wind tunnel loop (18 s) |
| IntroGlobeThunk | SFX | 9114588782 "Glass Boom 2" (PSE, 1.76 s) | 9116897176 "Metal Thunk 22" (PSE, 2.25 s) | 0.6 | 0.85 | Pro Sound Effects (ProSoundEffects) | a huge glass boom with plate rattle at 0.85x |
| IntroLetter | SFX | 9125633461 "Magazine Paper Flutter Single Page Passing B" (PSE, 1.85 s) | 9126143225 "Typing Paper Flutter Single Sheet Passing By" (PSE, 2.75 s) | 0.4 | 1 | Pro Sound Effects (ProSoundEffects) | a single magazine page fluttering past |
| IntroHeadlights | SFX | 9119717074 "Switch Circuit Breaker Clicks 5" (PSE, 1.50 s) | 9119727134 "Switch Impact On Flip Up Large Metal 2" (PSE, 0.44 s); 9112953597 "1965 Jaguar E- Type Car Headlight Switch 1" (PSE, 0.77 s) | 0.6 | 1 | Pro Sound Effects (ProSoundEffects) | circuit-breaker switch clicks (two clunks in 1.5 s) |
| IntroTapePrint | Clone | 9116458170 "Malfunction Beeps Glitch Staticky 2" (PSE, 1.13 s); 9125388626 "Beeps Short Multi Tone Beeps Squelch Glitchy" (PSE, 0.68 s) |  | 0.5 | 1 | Pro Sound Effects (ProSoundEffects) | staticky malfunction glitch beeps and a short squelchy glitch |
| IntroTitleSmash | Music | 9045118430 "Sneaky Schemes - Tag2" (APM, 5.51 s) | 9045118436 "Sneaky Schemes - Tag3" (APM, 7.00 s); 9045734444 "Hustle and Heist (sting b)" (APM, 4.47 s) | 0.75 | 1 | APM Music (APMOfficial) | "Sneaky Schemes - Tag2": the Caper theme's own 5.5 s button (pizzicato, woodwinds) |

#### Still missing

| Cue | Why | What to do |
|---|---|---|
| GusStep | no human footsteps in the APM, Pro Sound Effects or Roblox catalogues (re-searched 2026-11-13: footsteps, shoes, boots, heels, walking, stairs; only robot, creature, animal and puddle steps); `GusKeys` every 2nd step already carries "you hear him coming" | owner records or buys 4-6 hard-shoe-on-concrete takes and uploads them under the experience owner (manifest row + `LICENSED_CREATORS` for the owner id) |
| (lobby) | no lobby engine / drive cue exists yet; the LOBBY track adds one if it wants it | no clean licensed van idle loop was found: PSE "Go Kart Exhaust Constant" (toy putt-putt) and "Pod Idle Or Cruising" are the closest; "Cartoon Jalopy" has vocal gags and the pickup idles drive away mid-file |

### Loot and bank

| Cue | Bus | Takes (id "title" (creator, s)) | Alternates | Vol | Jitter | Voices | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| Grab | SFX | 9113727824 "Cash Movement 8 (SFX)" (ProSoundEffects, 1 s); 9113727636 "Cash Movement 7 (SFX)" (ProSoundEffects, 1 s); 9113727630 "Cash Movement 6 (SFX)" (ProSoundEffects, 1 s) |  | 0.60 | default | 4 | default | 3D mid, clone bus |
| GrabClink | SFX | 9113849492 "Coins Or Keys Jingle 6 (SFX)" (ProSoundEffects, 1 s) |  | 0.50 | 0.08 | 4 | default | 3D mid, clone bus |
| DiamondShimmer | SFX | 9126072453 "Synth Sparkle Tone High Pitch Bell Tone Burs (SFX)" (ProSoundEffects, 1 s); 9126071775 "Synth Sparkle Tone High Pitch Bell Tone Burs (SFX)" (ProSoundEffects, 1 s) |  | 0.70 | 0 | 1 | default | ducks music |
| DropThud | SFX | 9113246043 "Bag Drop Wood Floor 7 (SFX)" (ProSoundEffects, 1 s); 9113245890 "Bag Drop Wood Floor 4 (SFX)" (ProSoundEffects, 1 s); 9113246038 "Bag Drop Wood Floor 6 (SFX)" (ProSoundEffects, 1 s) |  | 0.60 | default | 3 | default | 3D mid, clone bus |
| BankKaching | SFX | 9113728756 "Cash Register 5 (SFX)" (ProSoundEffects, 1 s); 9113728625 "Cash Register 1 (SFX)" (ProSoundEffects, 1 s) |  | 0.75 | default | 3 | 0.08 | 3D far, clone bus |
| BankCoins | SFX | 9113849583 "Coin Throws 2 (SFX)" (ProSoundEffects, 2 s); 9113849579 "Coin Throws 1 (SFX)" (ProSoundEffects, 2 s) |  | 0.50 | default | 2 | 0.1 |  |
| CountTick | UI | 9114071110 "Dial Switch Twisting Sharp Ticking 78 (SFX)" (ProSoundEffects, 1 s) |  | 0.35 | 0 | 3 | 0.04 | stepped |
| CountDone | UI | 9119802009 "Synth Chime Single Synth Tone 3 (SFX)" (ProSoundEffects, 1 s) |  | 0.45 | 0 | 1 | default |  |

### Alarm and van

| Cue | Bus | Takes (id "title" (creator, s)) | Alternates | Vol | Jitter | Voices | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| AlarmBell | Warnings | 9125544264 "Elevator Alarm Bell Emergency Several Rings  (SFX)" (ProSoundEffects, 8 s) | 9125544285 "Elevator Alarm Bell Emergency Several Rings  (SFX)" (ProSoundEffects, 12 s) | 0.35 | 0 | 1 | default | loop, caption [Alarm!] |
| VanHorn | SFX | 9113018513 "2007 Dodge Charger Horn Honking 2 (SFX)" (ProSoundEffects, 1 s); 9113019386 "2007 Dodge Charger Horn Honking 9 (SFX)" (ProSoundEffects, 1 s) |  | 0.70 | default | 2 | 0.4 | 3D far, caption [Van horn] |
| VanEngine | SFX | 9125657802 "Mercedes- Benz 280 Sl Failed Starts Engine S (SFX)" (ProSoundEffects, 3 s) |  | 0.70 | 0 | 1 | default | 3D far, caption [Van leaving] |
| VanDoor | UI | 9119200218 "Sliding Door Grab Door Impacts Rub 2" (PSE, 0.56 s); 9119200415 "Sliding Door Grab Door Impacts Rub 3" (PSE, 0.67 s); 9119200399 "Sliding Door Grab Door Impacts Rub 5" (PSE, 0.73 s) | 9119200216 "Sliding Door Grab Door Impacts Rub 1" (PSE, 0.64 s); 9114153584 "Door Slide Open Close 1" (PSE, 1.70 s); 9119203830 "Sliding Glass Door 1" (PSE, 1.49 s) | 0.50 | default | 1 | 0.2 | the van-door wipe closing (Heist/Transition) |

### Complete

| Cue | Bus | Takes (id "title" (creator, s)) | Alternates | Vol | Jitter | Voices | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| HeistFanfare | Music | 1845411858 "Top Prize" (APMOfficial, 5 s) | 9038513902 "Diamond Heist (sting)" (APMOfficial, 6 s) | 0.80 | 0 | 1 | default | ducks music |
| TrackResolve | Music | 9045118431 "Sneaky Schemes - Tag1" (APMOfficial, 5 s) |  | 0.70 | 0 | 1 | default |  |

### UI

| Cue | Bus | Takes (id "title" (creator, s)) | Alternates | Vol | Jitter | Voices | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| UIClick | UI | 9125759320 "Plastic Switch Single Clicks Metallic Ringin (SFX)" (ProSoundEffects, 1 s); 9125759093 "Plastic Switch Single Clicks Metallic Ringin (SFX)" (ProSoundEffects, 1 s); 9125758559 "Plastic Switch Single Clicks Metallic Ringin (SFX)" (ProSoundEffects, 1 s) |  | 0.45 | default | 3 | 0.04 |  |
| UIBack | UI | 9125759320 "Plastic Switch Single Clicks Metallic Ringin (SFX)" (ProSoundEffects, 1 s); 9125759093 "Plastic Switch Single Clicks Metallic Ringin (SFX)" (ProSoundEffects, 1 s); 9125758559 "Plastic Switch Single Clicks Metallic Ringin (SFX)" (ProSoundEffects, 1 s) |  | 0.40 | default | 2 | 0.04 |  |
| UIHover | UI | 9118138693 "Relay Clicks 15 (SFX)" (ProSoundEffects, 0 s) |  | 0.18 | default | 2 | 0.05 |  |
| UIToggle | UI | 9119727934 "Switch In- Line Plastic Switch Clicks 14 (SFX)" (ProSoundEffects, 1 s); 9119727950 "Switch In- Line Plastic Switch Clicks 15 (SFX)" (ProSoundEffects, 1 s) |  | 0.45 | default | 2 | 0.04 |  |
| UIConfirm | UI | 9119802003 "Synth Chime Single Synth Tone 1 (SFX)" (ProSoundEffects, 1 s) |  | 0.45 | 0 | 1 | 0.1 |  |
| UIError | UI | 9113085764 "Alarm Buzzer 5 (SFX)" (ProSoundEffects, 1 s) |  | 0.35 | 0 | 1 | 0.2 |  |

### Ambience and Christmas

| Cue | Bus | Takes (id "title" (creator, s)) | Alternates | Vol | Jitter | Voices | Cooldown | Notes |
|---|---|---|---|---|---|---|---|---|
| AmbStreet | Ambience | 9112759541 "City Night Ambience 1 (SFX)" (ProSoundEffects, 36 s) |  | 0.35 | 0 | 1 | default | loop |
| AmbRoom | Ambience | 9125446564 "Command Room Tone Deep Air Conditioning Hum  (SFX)" (ProSoundEffects, 35 s) |  | 0.30 | 0 | 1 | default | loop |
| AmbVault | Ambience | 9125446543 "Command Room Tone Deep Air Conditioning Hum  (SFX)" (ProSoundEffects, 18 s) |  | 0.30 | 0 | 1 | default | loop |
| SleighBells | Ambience | 9114826043 "Horse Bells Sleigh Shaking Movement 2 (SFX)" (ProSoundEffects, 5 s) | 1840229014 "Sleigh Bell Roll" (APMOfficial, 7 s) | 0.40 | default | 2 | 0.3 |  |

### Music sets

| Set | Kind | Mixes / tracks (id "title" (creator, s)) | Alternates | Crew Layers S0..S4 -> mix |
|---|---|---|---|---|
| Garage | playlist | 1835698719 "Paname's Rififi" (APMOfficial, 189 s); 1845476443 "Agent X" (APMOfficial, 100 s) |  | - |
| GarageXmas | playlist | 1836687831 "Has Anybody Seen Kris Kringle?" (APMOfficial, 177 s) |  | - |
| Caper | mixes | 9045117610 "Sneaky Schemes - Alt3, PizzTriangle" (APMOfficial, 130 s); 9045117678 "Sneaky Schemes - Alt5, PizzLitePerc" (APMOfficial, 130 s); 9045117303 "Sneaky Schemes - Alt2, Lite" (APMOfficial, 130 s); 9045117358 "Sneaky Schemes - Alt1, NoMel" (APMOfficial, 130 s); 9045109623 "Sneaky Schemes" (APMOfficial, 130 s) | 9045117617 "Sneaky Schemes - Alt4, NoPerc" (APMOfficial, 130 s) | 1 2 3 4 5 |
| Xmas | mixes | 1842909687 "Fun And Games (Sleigh Bells Underscore Version)" (APMOfficial, 141 s); 1842909673 "Fun And Games (Sleigh Bells Version)" (APMOfficial, 141 s) |  | 1 1 2 2 2 |
| BigScore | mixes | 9038506885 "Diamond Heist (c)" (APMOfficial, 130 s); 9038506583 "Diamond Heist (b)" (APMOfficial, 130 s); 9038505017 "Diamond Heist (a)" (APMOfficial, 130 s) |  | 1 1 2 3 3 |
| Chase | mixes | 9045939292 "Code Heist" (APMOfficial, 108 s) | 9045939631 "Code Heist - Alternative Mix" (APMOfficial, 108 s); 9045939618 "Code Heist - Underscore" (APMOfficial, 108 s) | 1 1 1 1 1 |
| Results | playlist | 9045117895 "Sneaky Schemes - 60" (APMOfficial, 61 s) |  | - |

## 6. Sourcing (how the ids were found, and how to find more)

- **Search**: `GET https://apis.roblox.com/toolbox-service/v1/marketplace/3?keyword=<words>&limit=30&creatorTargetId=<creator>&creatorType=1`
  (asset type 3 = Audio; public, no key needed). It returns ids only.
- **Details**: `GET https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=<id,id,...>` (up to 30):
  name, description, duration, `audioDetails` (type, artist, album, SFX category), creator (id, name,
  verified) and whether it is free. Manifest.luau is generated from these responses.
- The newer Open Cloud `GET /toolbox-service/v2/assets:search` answered **403 "Scope not authorized"** with
  the project key and without it: it needs a Creator Store scope the key does not have. v1 was enough.
- **Licensed creators** (`Manifest.LICENSED_CREATORS`): **APMOfficial** (7462718749, APM Music: the
  Roblox-licensed music library; APM tracks first uploaded by the Roblox account now show this creator,
  DevForum thread "About the user named APMOfficial") and **ProSoundEffects** (7462895450, Pro Sound
  Effects: descriptions read "Courtesy of Pro Sound Effects.", uploaded 2022-03-16 with the licensed
  catalogue), plus **Roblox** (1). Roblox: "audio that is owned and uploaded by Roblox or our music and SFX
  partners will remain public and usable by anyone in any experience" (DevForum 1701697, asset privacy for
  audio). Use is Roblox-only; never download or re-upload.
  The partner status of the two accounts is inferred from those facts; the web did not return an official
  page naming them (owner check, below).
- Searched and **not found** in the partner catalogue: human footsteps (only robot, creature, animal steps),
  a single heartbeat (APM's are 60 s 96 BPM loops; the cue uses an APM Horror Tools kick), a tape rewind or
  cassette rewind (closest: "Film Rewind"), a cash-register "cha-ching" with bell (the ones found are
  electronic hatch sounds), spoken "Hey!" / "Gotcha!" lines (PSE has "Hmm", "What", "Huh", sergeant shouts and
  fight yells), a choir stab under 1 s (APM's orchestra + choir hits ring for 9-10 s), a clean van idle loop.
- Audio pass 2026-11-13: the search helper lives in the session scratchpad, not the repo; it is the two calls
  above (marketplace search with `creatorTargetId` 7462718749 / 7462895450 / 1, then `items/details`), and the
  engine check is `tests/audio_engine.luau`. `tools/rbx_search.py` searches experiences, not audio.
- Re-verify an id: `curl -s "https://apis.roblox.com/toolbox-service/v1/items/details?assetIds=<id>"` and
  check `creator.id` is in `LICENSED_CREATORS`. A new id goes into Manifest.luau only with the fields from
  that response; CueCheck refuses any id that is not in the manifest or not from a licensed creator.

## 7. Cue rules (CueCheck, enforced by tests/unit/AudioCues.spec)

Every id is a positive integer in the manifest, uploaded by a licensed creator, at most once per cue; every
cue has a known bus, volume 0.01-4, pitch 0.5-2, pitch jitter 0-0.2, volume jitter 0-0.3, 1-16 voices,
cooldown 0-30 s, priority 1-5, a known rolloff preset, booleans for flags, no unknown fields (typos) and
search words even when it has no ids; a stepped (tonal) cue has no pitch jitter; a loop never chokes. A
"mixes" set has same-length mixes (2 s tolerance) and a 5-entry S0..S4 map that never steps down; a
playlist has no map; every music state names an existing set; every `Config.Audio.PRELOAD` name is a cue.
The AudioDirector also runs CueCheck at boot and warns once per problem.

## 8. API (src/client/Audio/AudioDirector.luau)

```lua
local AudioDirector = require(StarterPlayerScripts.Client.Audio.AudioDirector) -- from Heist modules: script.Parent.Parent.Audio.AudioDirector
AudioDirector.preload({ "Caper", "Garage" })            -- boot: first-impression cues + likely music
local stop = AudioDirector.play("PlatePress", { at = platePart, clone = true }) -- returns stop()
AudioDirector.play("CountdownTick", { step = 3, caption = false })
AudioDirector.stopCue("AlarmBell")
AudioDirector.music("Heist", { set = "BigScore" })      -- "Off" | "Garage" | "Heist" | "Alarm" | "Results"
AudioDirector.layers(cloneCount)                         -- Crew Layers tier (call on GO)
AudioDirector.rewind() ; AudioDirector.go(cloneCount)    -- the rewind window
AudioDirector.arpeggio(cloneCount)                       -- the sound logo
AudioDirector.event(e, resolver)                         -- every sound of a replicated sim event
AudioDirector.duck("Diamond")                            -- 4 dB for 0.6 s
AudioDirector.muffle(true)                               -- SFX + Ambience through the 800 Hz WorldMuffle low-pass (false: open)
AudioDirector.setBusVolume("Music", 0.6) ; AudioDirector.setMuted(false)
AudioDirector.setReducedMotion(true) ; AudioDirector.setChristmas(nil)
AudioDirector.setCaptionHandler(function(text, position) hud.toast(text) end)
AudioDirector.stopAll() ; AudioDirector.status()
```

`play` options: `at` (Vector3, BasePart or Attachment: positional on SFX, Clone and Warnings cues; UI, Music
and Ambience are always 2D), `clone` (a clone's version: Clone bus, when the cue is `cloneable`), `step`
(index on the cue's semitone ladder), `volume` and `pitch` (multipliers), `delay` (seconds; sample-accurate
on the mixer clock), `caption = false`. A cue without ids warns once and returns a no-op stop.

## 9. Call sites to wire (src/client/Heist, owned by the wiring agent)

Require it in `HeistClient.luau` next to the views:
`local AudioDirector = require(script.Parent.Parent:WaitForChild("Audio"):WaitForChild("AudioDirector"))`.
Line numbers are from 2026-11-12.

**HeistClient.luau**
1. `HeistClient.start()` after the views are created: `AudioDirector.preload({ "Caper", "Garage" })`,
   `AudioDirector.setReducedMotion(state.reduced)` (and in the `ReducedMotionEnabled` signal handler),
   `AudioDirector.setCaptionHandler(function(text) hud.toast(text) end)` until the HUD has a caption line.
2. `actions.endRun` (line 92): replace `RewindDirector.sound("Clack")` with `AudioDirector.play("RewindClack")`.
3. `applyEvent(e, live)` (lines 146-189): at the top, `if live then AudioDirector.event(e, resolver) end`,
   and delete the four `RewindDirector.sound(...)` calls (Busted, Zap, Busted, KaChing): EventCues covers
   Busted, Zap, Caught, Bank and 20 more kinds (plates, doors, lasers, switches, grabs, drops, "?", alarm,
   van, complete, dawn, goal, tier, refused). The resolver:
   - `isClone(id)`: `state.run.actorById[id].kind == "clone"`
   - `isMine(id)`: `kind == "live" and owner == localPlayer.UserId`
   - `position(what, index)`: `what == "actor"` -> `echo.positionOf(index)`; otherwise the level part
     with attributes `EH_Kind == what` and `EH_Index == index` (LevelBuilder tags plate, door, laser,
     loot, switch, van; build the map once in `setupInstance` from `levelModel:GetDescendants()`, use a
     laser Model's first beam part).
4. `applyRun(msg, live)` (line 211; the live branch at line 240): count `msg.actors` with `kind == "clone"` and pass it to
   the RewindDirector (or keep it in `state`) for the arpeggio and `go(clones)`; on the first run of an
   instance call `AudioDirector.music("Heist", { set = <"BigScore" for cs5_clone_party and bk1_big_score> })`.
5. `setupInstance(p)` (line 248): `AudioDirector.play("AmbRoom")` (store the stop; `AmbVault` for the bank
   level), `AudioDirector.stopCue("AmbStreet")`.
6. `toGarage(p)` (line 276): `AudioDirector.music("Garage")`, `AudioDirector.stopCue("AmbRoom")`,
   `AudioDirector.stopCue("AmbVault")`, `AudioDirector.stopCue("AlarmBell")`, `AudioDirector.stopCue("LaserHum")`,
   `AudioDirector.play("AmbStreet")`.
7. `handle` "Over" (line 371): `AudioDirector.music("Results")`.

**RewindDirector.luau** (replace `sound()` and `Config.Heist.SOUNDS`)
8. `director.play` (line 188): replace `sound("Clack")` with `AudioDirector.rewind()` (the clack already
   played on input; the rewind call plays TapeStop and dives the music).
9. Stage 1 (line 221): `sound("Stinger")` -> `AudioDirector.play("RewindWhirr")` and
   `AudioDirector.play("RewindStinger")` (a licensed reverse-swell stand-in until the owner's render).
10. Stage 2 (lines 249-250): `sound("Clunk")` -> `AudioDirector.play("RewindClunk")`; `sound("Arpeggio")` ->
    `AudioDirector.arpeggio(cloneCount)`.
11. The stamp (line 254, `u >= snapTo`, first frame): `AudioDirector.play("RunStamp")`; `u >= 1` (line 260, control returns, the
    `onDone` callback): `AudioDirector.go(cloneCount)`. Intro (run 1): the stamp and `go(0)` only.
12. `director.stamp(text, ...)` (line 283: BUSTED, ZAPPED, HEIST COMPLETE): `AudioDirector.play("RunStamp")`.
    Then delete `RewindDirector.sound` and `Config.Heist.SOUNDS`.

**WorldView.luau** `view.update`
13. Lasers (line 185, `l.view = v`): on `bind`, start `AudioDirector.play("LaserHum", { at = <first beam> })`
    per laser and keep the stop; when `v` becomes `"off"` stop it, when it becomes `"on"` start it again.
    (Off/flicker one-shots come from the LaserOff/LaserOn events.)
14. Doors (line 146, `d.view = v`): while `v == "closing"`, `AudioDirector.play("DoorBeep", { at = d.part })`
    on every other amber blink (`math.floor(now * 4)` changes). Open/close/lock come from events.

**GusView.luau** `view.update`
15. Footsteps: when Gus has moved `Config.Audio.GUS_STEP_STRIDE` studs since his last step,
    `AudioDirector.play("GusStep", { at = <his root part> })` (silent until the owner picks takes).
16. Radio: every `GUS_RADIO_SECONDS` (random in the range) while patrolling, `play("GusRadio", { at = root })`.
17. The bubble (lines 291-302): "?" and "!" stings come from the Suspect and Caught events; when the label
    first turns "?" for the local player's actor, start `play("Heartbeat")` once per second until it clears.
    Wired (Gus track): GusKeys every `Config.Gus.KEYS_STEPS` steps on patrol, GusSnore once per doze nod,
    GusBarkHey on wake and chase start, GusBarkHm on the double-take snap, GusBarkGotcha on a catch,
    GusBarkWrongOne when he busts a clone (all positional at his head).

**EchoView.luau**
18. No clone footsteps (§7.2). Clone outcomes already sound through the events (Busted, Zap); Stuck and
    Shrug are silent by design.

**Hud.luau**
19. `hud.update` timer (line 1055): when the whole second changes and
    `Mix.countdownStep(remaining, Config.Audio.COUNTDOWN_FROM)` is a step,
    `AudioDirector.play("CountdownTick", { step = step, caption = step == 0 })`; from
    `HEARTBEAT_FROM` seconds left also `play("Heartbeat")`.
20. `hud.onEvent` Bank branch (line 923): the loot meter count-up plays `play("CountTick", { step = k })` per
    tick and `play("CountDone")` when it lands (the ka-ching itself comes from the event).
21. `hud.onOver` (line 572): the Haul, Crew and Clean stamps `play("RunStamp", { pitch = 1 + i *
    Config.Audio.MEDAL_PITCH_STEP })`, `MEDAL_STAMP_GAP` apart.
22. Diamond grabbed (world dim moment): `AudioDirector.play("DiamondShimmer")` (it ducks the music).
23. Garage van shelf, presents, advent unlock in December: `play("SleighBells")`.
24. Settings (Comfort module, when it exists): sliders -> `AudioDirector.setBusVolume(bus, v)`, a mute
    toggle -> `setMuted`.

**Ui.luau**
25. `Ui.button` (line 98): `b.Activated:Connect(function() AudioDirector.play("UIClick"); onActivated() end)`;
    `UIBack` for close/back buttons, `UIToggle` for toggles, `UIConfirm` on ready/equip/granted, `UIError`
    on refused, `UIHover` on `MouseEnter` (PC only).

**Slide.luau** (Config.Slide)
26. A slide starts (Ctrl / B / SLIDE): `Sound.play("IntroWhoosh")`, the intro's whoosh reused (no new cue: a fast
    airy whip fits a slide). Your clones replay slides silently (their positions only).

## 10. Settings and data

Settings now hold `musicVolume` and `sfxVolume` (0..1, default 1; additive, `Data.SetSetting` validates the
range, docs/DATA.md). The settings panel (`Hud/SettingsPanel`, PLAN_STEAM_PLUS U7) drives
`setBusVolume("Music", v)` and the SFX slider drives `SFX`, `UI` and `Ambience` (`Config.Ui.SFX_BUSES`;
Warnings keep their floor); `HeistClient` applies the saved values at boot. `captions` (default on) gates the
caption handler. `uiVolume`, `alertsVolume` and `muteAll` are not built.

## 11. Live load check

`src/shared/Audio/LoadCheck.luau` loads every manifest id into a throwaway AudioPlayer and reports ids that never
become ready (takedowns and permission problems are silent in Roblox). `tests/audio_engine.luau` runs it in a real
server and also checks that every cue and music set with ids has at least one take that loads, warns on a store /
engine length gap over 1.5 s, and asks `MarketplaceService:GetProductInfoAsync` for the creator of 12 first takes.
2026-11-13, Saved place version 78: **191/191 ready, 83 cues and sets each load, 12/12 licensed creators, no
length gap**; only GusStep is empty. Re-run before each release (lihfolk-sfx review 8):

```
ROBLOX_API_KEY=proxy-injected python3 tools/cloud_test.py --universe 10776026960 --place 70772627070328 \
    --script tests/audio_engine.luau --timeout 180          # add --version N to test an existing build
```

A Luau Execution server does not render audio (an AudioAnalyzer reads 0 there), so loudness and where a hit falls
inside a file are audition work (§13), not engine checks.

## 12. Owner actions

1. **Audition** in Studio (Toolbox > Creator Store > Audio, paste the id) every cue's takes and alternates;
   swap a take with its alternate in `Cues.luau` (only ids already in the manifest). Most important: the
   Caper ladder order (does each mix sound fuller than the last?), CloneChime (glassy, dry, pitched cleanly
   up an octave and a third), RewindWhirr, BankKaching, Busted.
2. **Audition the audio pass** (§13, most-heard first) and swap takes with their alternates in `Cues.luau`
   (only ids in the manifest). Still to source: **GusStep** (4-6 takes, hard shoes on concrete), and render
   **RewindStinger** (reversed last bar of each heist track + whirr, 1.2 s) from owned music to replace the
   licensed reverse swell; upload under the experience owner and paste the ids. A non-partner id needs its
   manifest row with `creatorId` added to `LICENSED_CREATORS` only for your own uploads. Gus's four barks want one
   recorded actor eventually (the library takes are stand-ins).
3. **Confirm the partner accounts** (APMOfficial, ProSoundEffects) are Roblox's licensed partners in the
   Creator Store UI (they show as the publishers of the free licensed catalogue).
4. **Loudness pass**: measure the used files in Studio (AudioAnalyzer RMS on a test bus) and re-level the
   cue volumes to the -18 LUFS family targets; check phone speakers (1-4 kHz cues stay audible).
5. **D10 music**: if 2 stemmed tracks are commissioned (main theme + Christmas, with trailer rights, by
   Dec 9), add them as `kind = "mixes"` sets with stems in order and `bpm = 128`, and set
   `Config.Audio.MUSIC_MODE = "stems"`. Library tracks never go into TikToks or trailers.
6. **S4 spike**: paste two mixes of one Caper track (e.g. 9045117610 and 9045109623, both 130 s) into
   `src/spikes/stems/shared/StemsConfig.luau` as STEM_A / STEM_B (`rbxassetid://<id>`) to test drift with
   real music.

## 13. Owner audition list (audio pass 2026-11-13)

Sorted by how often players hear each cue, so the first rows matter most. In Studio: Toolbox > Creator Store >
Audio, paste the id (or play the cue with `AudioDirector.play`); swap a take with an alternate in `Cues.luau`.
Bold items need a decision, not just a listen.

| # | Cue | Heard | Listen for |
|---|---|---|---|
| 1 | GusKeys | every 2nd step of every patrolling Gus | does it read as a guard's key ring at 3D near range? not too busy every 2nd step |
| 2 | RewindStinger | every rewind (every run) | does the swell peak on the clunk at 1.35 s? pitch 1.9 is a guess from the length; replace with the reversed last bar when rendered |
| 3 | LootTinkle | every loot glint within 8 studs | soft enough to repeat; not confused with CloneChime / DiamondShimmer (synth sparkle) |
| 4 | Heartbeat | every '?' on you and the last seconds of every run | a heartbeat, not a kick drum? try alt 9119882039 (synth thud) |
| 5 | PlateHum | every held plate | a toy hum under PlatePress, not the CableWhum / LaserHum buzz |
| 6 | VanToot | every bank | cheerful double toot? each file holds a few squeezes: keep the ones with two |
| 7 | VanDoor | every garage/heist/results wipe (0.35 s) | a door, not a drawer? toy-like enough? alt 9114153584 is a longer slide that bangs shut |
| 8 | LaserWhine | every laser flicker | rising and short at 1.8x; alts are longer variants of the same charge-up |
| 9 | GusBarkHm | every double-take | a curious 'hm?', same man as the other barks? |
| 10 | GusBarkHey | every wake and chase start | **check the words**: drill-sergeant orders, not yet heard; keep only takes that sound like 'Hey!' or a wordless shout |
| 11 | GusBarkGotcha | every catch | **check**: game fight yells may include laughs or pain; keep the triumphant ones |
| 12 | GusBarkWrongOne | every busted clone | 'What?' / 'Huh?' through a PA click: does the radio colour fit Gus? |
| 13 | GusSnore | each nod while Gus dozes (L5) | male comic snore at 1.15x; the 4 s nod cuts the tail |
| 14 | VaultSlam | heist complete | heavy enough; distinct from DoorClose's alt (Steel Door 3) |
| 15 | SnareRoll | every Line-up | **align**: the hit must land on the pose; measure where the hit is and set Config.Moments.LINEUP.SNARE_SECONDS (0.6 now) |
| 16 | ChoirHit | 8 OF ME roll calls | in key with the C ladder? the 10 s ring-out is long: try alt 1843054115 (C) |
| 17 | IntroMusic | once per new player (the intro) | fits the 33.7 s shot list? sweet throughout: the stings carry the villain beats |
| 18 | IntroTitleSmash | intro, 31.2 s | a title 'smash'? it is the theme's button; alt Tag3 or the 'Hustle and Heist' piano sting |
| 19 | IntroHoardSting | intro, 4.8 s | funny-sinister brass, not scary |
| 20 | IntroVacuumOn + IntroSuction | intro, 12.75-19 s | a giant vacuum, not a spaceship |
| 21 | IntroBells, IntroMonocle, IntroLever, IntroWhoosh, IntroGlobeThunk, IntroLetter, IntroHeadlights, IntroTapePrint | intro | each one beat; skip with SKIP to check the loops stop |

