# Store art: the finals and how to upload them

_2026-11-13. Rendered by `python3 tools/blender/final_shots.py --only <name>` (one image per command), graded by `--grade` into [`grades.json`](grades.json), [`readability.png`](readability.png) (full, 150 px, 64 px, 64 px x3, 150 px greyscale) and [`grid_test.png`](grid_test.png) (phone-size tiles on the dark and light app themes). Rules behind them: ICON_THUMBNAILS.md §0.1._

These are **key art** (ICON_THUMBNAILS.md §0.4): the game's own meshes (the Rookie and his kit outfit with `Rookie_Cap_Santa`, clones in the EchoView look, Gus, the loot, L4 Night Clerk, the story town with Hoardsworth Tower, the Snow Globe Vault and the aurora) posed and lit in Blender, with a 2D finish (blurred background, colour gels, ink outline, glows, sparkles, Luckiest Guy text). Nothing in them is missing from the game. They are not in-game captures: if the owner keeps the "real capture only" rule for Home thumbnails (MASTERPLAN §9.4), use them as the target frames for the capture session (CAPTURE.md) and upload the icon only.

## The files

Scores are honest self-scores on the ICON_THUMBNAILS §7 rubric (the vault checklist's 10 criteria, 1 point each: focal subject, small-size read, value contrast, genre clarity, emotion, text discipline, safe area, brand, novelty in the row, clutter; upload bar 8.5) after both gates (truth, policy). "Grey pop" is the median greyscale value of the group against the band just round it at that size (`grades.json`; ≥ 0.15 reads; negative = a dark shape on a lighter ground, which reads too).

| File | What it shows | Grey pop 64 px (150 px) | Score | Notes |
|---|---|---|---|---|
| [`icon_512_1_santa-crew.png`](icon_512_1_santa-crew.png) | The Rookie in `Rookie_Cap_Santa`, smug side-eye, a cyan and a magenta copy behind him (the wordmark's double exposure), the cash bag at his shoulder, a gold field behind his cap | hero -0.20 (-0.19), copies 0.20 (0.20), bag 0.26 (0.30) | **8.8** | The best read: face, copies and loot are three separate values at 64 px; the magenta copy is cropped by the left edge (fine: it breaks the frame) |
| [`icon_512_3_santa-twins.png`](icon_512_3_santa-twins.png) | Square to camera, a cyan copy over one shoulder and a magenta one over the other, a gold stack, gold above his head and a dark aura round him | hero 0.16 (0.20), copies 0.21 (0.27), gold 0.08 (0.09) | **8.5** | Symmetric and very "copies of me"; the gold stack is small and low (an accent, not a read), the gloves are dark blobs at the bottom corners |
| [`icon_512_2_santa-solo.png`](icon_512_2_santa-solo.png) | Solo version: two cyan copies with the age ramp, a present, Leather Gloves, the aurora in the gold | hero -0.18 (**-0.12**), copies 0.23 (0.25), present -0.09 (-0.09) | **8.3** | **Below the bar.** At 150 px the hero's mid values sit too close to the gold field, and the raised gloves beside the present make the lower half busy. Kept as the solo-only alternative; don't upload it before a re-pose (gift held lower, both gloves on it) |
| [`thumb_1920x1080_1_8-of-me.png`](thumb_1920x1080_1_8-of-me.png) | You with the cash bag, seven glowing copies fanned behind (all seven visible), gold rain, the town blurred | hero 0.28 (0.32), clones 0.21 (0.22), bag 0.12 (0.13) | **8.7** | The hook in one look, our "number art" (rule 9); the older copies are dark (the real age ramp); warm share is low (gold only on the loot) |
| [`thumb_1920x1080_2_rob-with-clones.png`](thumb_1920x1080_2_rob-with-clones.png) | First person in L4: your gloves and the cash, your clone (pill 1) on plate A holding the back-room door open, Gus in his Santa hat in that doorway | gloves -0.10 (-0.06), cash 0.43 (0.50), clone 0.32 (0.37) | **8.5** | The only first-person image. Text is **ROB WITH CLONES**: the subtitle "ROB WITH YOUR CLONES" is 4 words and the bar is ≤ 3. The shop interior is brown and less saturated (0.42); Gus is small; the gloves are dark mitts, read by shape and outline, the cash and the clone carry the read |
| [`thumb_1920x1080_3_steal-back-christmas.png`](thumb_1920x1080_3_steal-back-christmas.png) | You in the Santa cap with a present and three copies carrying presents, Hoardsworth Tower with the H and the Snow Globe glowing on top, the aurora | hero 0.32 (0.35), clones 0.21 (0.24), presents -0.15 (-0.14) | **8.7** | Christmas in one look and the story's villain tower; the Snow Globe itself is small at 150 px (its glow reads, the glass doesn't). Key art: the town exists only in the intro |
| [`thumb_1920x1080_4_wrong-one.png`](thumb_1920x1080_4_wrong-one.png) | Gus's double-take: his flashlight on your shocked clone, the "?" over his head, while you sneak past in front with the cash, smug | hero 0.44 (0.46), clone 0.26 (0.25), bag -0.02 (-0.08) | **8.8** | The best joke and the clearest roles (guard, wrong one, you). Gus doesn't grab the clone: the game's catch is the double-take and the cone (ICON_THUMBNAILS §8), so the image shows that, not a collar grab |

All thumbnails are 16:9 1920 × 1080 PNG, 0.97-1.38 MB (under 3 MB); icons 512 × 512, ~0.3 MB. Text uses the game's display face Luckiest Guy (Apache-2.0, `assets/fonts`), ≤ 3 words, upper third, nothing in the bottom 18 %. Truth check: every character, item and place is in the game (`Rookie_Cap_Santa` ships with this commit, but it reaches players only after the owner re-uploads `Rookie_Outfits`; see below).

## Which to use first

- **Icon, Dec 3 - Jan 4: `icon_512_1_santa-crew.png`.** It is the strongest at 64 px. One icon at a time, with no icon change in December (§3.4). Before Dec 3, re-upload the outfit kit so the Santa cap is really in the game: `python3 tools/kit_upload.py --only Rookie_Outfits` (a PATCH, so the same asset id).
- **Icon, Jan 5:** the evergreen version of icon 1. Re-render it with the Flat Cap: in `final_shots.py` pass `outfit=T.DEFAULT` to `_icon` for `icon_1`, then `python3 tools/blender/final_shots.py --only icon_1_santa-crew`. Then run a **time-sliced** test of icon 3's evergreen version: 14 days each, outside update weeks, and trust only a 30 %+ difference (§3.4).
- **Home thumbnails (only 2 active until DAU > 1,000, MASTERPLAN §9.4):** at launch, **`thumb_3` STEAL BACK CHRISTMAS + `thumb_4` WRONG ONE!**. Add **`thumb_1` 8 OF ME** as the third once SwarmSeen ≥ 60 % by minute 10 is confirmed. **`thumb_2` ROB WITH CLONES** goes into the Dec 3-6 Plays ad test as the first-person challenger. If it wins there, it replaces the weaker of the active pair after 7+ days.
- **Detail page order:** thumb_3, thumb_1, thumb_4, thumb_2 (the season first, then the swarm promise, the joke, the first-person view). On Jan 5 move thumb_3 to the end.
- **The capture question (ICON_THUMBNAILS §0.4):** these are key art. If the owner keeps "Home thumbnails are real captures", shoot thumb_4 and thumb_1 in the capture place from these frames (CAPTURE.md B3, C1) and use these files as the targets.

## Creator Hub steps (the owner uploads)

**Is there an API?** The LihFolk vault (*Thumbnails Icons and Store Page*, *Thumbnail Specs, Rules and Upload*, Oct 2026) documents only the Creator Hub path for the icon and thumbnails and lists no Open Cloud endpoint for them, which matches the brief. A web search on 2026-11-13, however, found a newer Roblox Open Cloud guide, *Manage experience icons and thumbnails* (create.roblox.com/docs/cloud/guides/experience-icons-and-thumbnails, last updated 2026-11-10 per the search summary): the place icon via the Assets API with `updateMask=icon` (Place ID), the detail-page thumbnails with `updateMask=previews` (a full replacement of the list), and the Home thumbnails through the Thumbnail Personalization API (Universe ID). This session could not open create.roblox.com, so this is **[UNVERIFIED]**: the vault is behind on it, and our Open Cloud key has none of those scopes. Upload by hand as below. Automating it later needs a key with the right scopes, and the field names have to be checked against the live reference first.

Before you start: the files are PNG, the right size and under 3 MB (see the table). Upload them as they are, with no re-export.

### Icon (one per locale; moderation before anyone sees it)
1. Open **create.roblox.com → Creations**, then the experience **Heist Yourself: Rob With Your Clones**.
2. Left menu: **Configure → Places** (older layouts say "Configurations"), open the **start place** (the starred one).
3. **Icon** → upload `icon_512_1_santa-crew.png` (media type Image). Square and ≥ 512 × 512, so it is accepted as is.
4. Save. Wait for moderation (the old icon stays until it passes).
5. Check it at real size: the experience page on a phone (150 px), the Home tile, the light and the dark app theme.
6. **Jan 5 (evergreen):** re-render without the Santa cap (`final_shots.py`: pass `outfit=T.DEFAULT` to `_icon`) and upload it the same way. Don't change the icon in between: one icon at a time, time-sliced tests only (§3.4).

### Thumbnails
1. Same experience → **Configure → Places → start place → Thumbnails** (in some layouts: **Configure → Thumbnails**).
2. **Home Page** tab (the personalisation set, 2-5 active): **Upload** the thumbnails in the order below, one at a time, 1920 × 1080 PNG (16:9, under 3 MB). Add each one's **alt text** (below). Activate the ones the A/B plan says.
3. **Experience Detail Page** tab (the gallery on the page itself, a separate list): upload all four, drag them into the detail-page order below, add the alt text.
4. Data appears after a few hours: impressions, qualified plays, qualified play-through rate, the winning segment per thumbnail. Keep at least 2 active; don't judge before 7 days (§6, vault *A-B Testing*).

### Alt text
- `thumb_1920x1080_1_8-of-me`: "A smug robber holding a cash bag, with seven glowing cyan copies of himself behind him on a snowy street."
- `thumb_1920x1080_2_rob-with-clones`: "First-person view: your gloved hands hold a cash bag while your glowing clone stands on a pressure plate and the night guard watches through a door."
- `thumb_1920x1080_3_steal-back-christmas`: "A robber in a Santa cap and three glowing copies of him carry presents in front of a villain's tower topped with a giant snow globe under the northern lights."
- `thumb_1920x1080_4_wrong-one`: "The night guard shines his flashlight on a glowing clone while the real robber sneaks past with the cash."
