# Golden frames: the target image (PLAN_STEAM_PLUS §3.3, phase 1.5)

Three frames are built to final quality in the engine, captured on the owner's phone and in Studio, and **signed off by the owner** (target: Wed Nov 18). After sign-off they are the style reference: every later shot is graded side by side against the matching frame (PLAN §8.2). No multi-level art work goes past them before the sign-off.

The one-sentence look (PLAN §3.1): **"A Christmas Eve caper in a toy-sized town, and the whole crew is you."**

Each frame lists its composition, what must be in it, and the pass checks. Scene staging for capture uses a Studio-only attribute, `EH_Scenario` (PLAN §8.1 R3 step 3), never a new remote.

---

## G1: L1 "Back Room", the first view after the van doors open

**Camera:** the gameplay default from decision D5. Shot twice for the A/B:
- **(a) diorama:** pitch 52°, distance 30, FOV 45, you in the lower third (the focus leads you). Tuned inside the plan's bands on this spawn: at 50° / 28 / 42 the shop front's top hid plate A's near half; now it clears the plate by about 2 studs (`tests/unit/HeistCamera.spec.luau`);
- **(b) classic:** follow cam, 16 studs, FOV 70. From the street it still cannot see plate A (the shop front is in the way).

The player stands on the street in front of the van, facing the shop.

**In frame:**
- The Corner Shop front: its **striped awning** (the location's signature silhouette) and **warm amber light** spilling from the windows onto the snowy pavement.
- **Falling snow**, and snow on the awning and sills.
- A street lamp pool on the pavement.
- Through the shop window: the lit counter with the **cash glinting**, and plate **A** glowing Bulb Warm with its letter readable.
- The van at frame left or bottom, dim, with arrows that read as arrows. The van must not be the brightest thing.
- Behind the shop: the hazy skyline, lit windows, and **Hoardsworth's tower with the Snow Globe on top**.
- The player avatar with its warm rim light and ground ring, readable against the floor.

**Composition:** the player in the lower third, the shop door and plate in the upper third. The brightest non-signal thing is the cash, or the plate pool. Nothing in the foreground outshines it.

**Pass checks:**
- **Grading (§8.2):** floor ≥ 12 %, walls 15-30 %, lit:shadow faces 1.5-2.5×, glow 1-16 % of the frame.
- **Readability:** the plate and its letter read at 48 px on a 360-dp phone.
- **Warm share:** about 60 % of the area.
- **Owner:** "would I stop scrolling on this?"

## G2: L5 Clone Party, wide shot at "8 OF ME"

**Camera:** the 8 OF ME pull-back. Every clone sits inside the **central 32 %** of frame width (9:16-safe, criterion H3). The pitch is about 45°.

**In frame:**
- The Toy Shop interior: **candy pink and gold** light, and **one giant toy soldier** as the signature silhouette.
- Gold loot on displays (not cluttered stands).
- **Eight copies of the player's own avatar**, each clearly *you*:
  - textured;
  - a crew-colour fill;
  - a floor glow;
  - a numbered pill badge.
- Older runs drift toward violet (solo).
- **Gus** dozing in the back office (Zz), with his "GUS" nameplate.
- The 8 OF ME stamp in the chunky display face.
- The world dimmed 15 %.

**Composition:** the 8 clones are the brightest, most saturated things in frame. The stamp sits above them and covers no face.

**Pass checks:**
- **Recognisability:** 4 of 5 testers pick out *their own* clone in a 64 px crop (PLAN §3.1).
- **Thumbnail:** the 64 px thumbnail answers "which ones are past me?" in ≤ 0.5 s (premium A2).
- **Sound-off:** a sound-off 1-second clip of it is recognisably ours (premium I1).

## G3: the garage, your van

**Camera:** a 3/4 view of your van bay at about 30° pitch, about 22 studs away, FOV 45.

**In frame:**
- A warm, lit garage interior built from the kit:
  - brick, a roll-up door half open to the snowy street;
  - a work lamp pool on your van.
- Your van in your crew colour.
- The trophy shelf with your first trophy lit.
- The **job board** (pinned photos, string), with the NEXT job glowing.
- Neighbouring van bays dimmer.
- Snow drifting in at the door.

**Composition:** your van and the job board share the light. The job board's NEXT card is the focal point.

**Pass checks:**
- the grading;
- the NEXT card reads at 48 px on the phone;
- no default Roblox grey or white blocks anywhere.

---

## Typography specimen (decision D8)

One Studio frame shows the wordmark "HEIST YOURSELF" (chunky rounded capitals with a cyan double-exposure offset), with **Luckiest Guy** and **Fredoka One** at 14, 24, 36 and 64 px. Each is shown on the stamp, a button label and a results line, on top of a G1 background. The owner picks one. Builder Sans stays the UI face.

## Clone recognisability A/B (PLAN §3.1)

The same G2 frame is shot twice:
- **(a)** the textured avatar under the crew-colour fill (0.55);
- **(b)** a stripped hologram (no textures).

Shown to testers as 64 px crops with 4 avatars each.

## Capture

The owner takes each frame on their phone and in Studio (Quality 10 and Automatic), and drops the shots in the **Shots inbox** (GitHub issue #1). Claude grades them and puts them side by side with the Blender previews, which are calibrated once against the Studio shots.

### Staging a frame in Studio (`EH_Scenario`)

1. In Studio, select **Workspace** in the Explorer. In Properties > Attributes, add a **string** attribute named `EH_Scenario` with one of the values below.
2. Press **Play**. The server stages the scene for the first player; the camera goes to the frame's framing and the Studio debug chip hides itself.
3. Take the shot. To return to normal play, delete the attribute (or clear its value) before the next Play.

| Value | What you get |
|---|---|
| `G1` | L1 "Back Room" starts at once, you at the street spawn. The camera is the gameplay camera; MENU > **CAMERA: DIORAMA / CLASSIC** flips it for the (a) / (b) pair. |
| `G2` | L5 Clone Party starts with **7 clones** from the level's solution recordings in your deck, so run 1 is you + 7 = **8 OF ME** (the stamp fires after the tape print). The camera is the pull-back: pitch 45°, FOV 45, the distance fitted so you and every clone sit inside the central 32 % of the width. |
| `G3` | The garage (no heist starts). The camera holds a 3/4 shot of the first van bay: pitch 30°, 22 studs, FOV 45. |
| `TYPE` | `G1` plus the type specimen overlay: the wordmark, Luckiest Guy and Fredoka One at 14 / 24 / 36 / 64 px. |
| `CLONE_AB` | `G2`. Add a string attribute `EH_Variant` = `B` for the stripped arm (clone templates without textures or clothing); `A` or no attribute is the textured arm. |

It is **Studio only**: the server and the client read the attribute only through `Scenario.resolve(RunService:IsStudio(), ...)`, so a live server ignores it (`tests/unit/HeistScenario.spec.luau` checks the gate and scans the sources). Code: `src/shared/Heist/Scenario.luau`, `src/server/Heist/Staging.luau`, `src/client/Heist/GoldenShots.luau`; numbers in `Config.Heist.CAMERA.GOLDEN`. The G2 clones are `src/server/Heist/StagingTapes.luau`, generated by `lune run tools/staging_tapes.luau` from `tests/sim/Solutions.cs5_clone_party` (the scripted PLACEHOLDER until the owner records the real solution; rerun the tool when the level or the solution changes, `tests/sim/StagingTapes.spec.luau` fails until you do).
