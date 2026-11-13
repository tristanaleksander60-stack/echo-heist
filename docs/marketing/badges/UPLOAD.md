# Creating the badges on Roblox (owner)

The game already awards the 8 launch badges from the server. Until a badge exists on Roblox its id is `0`: players
still earn it, the in-game BADGE UNLOCKED card shows, and the profile keeps it. As soon as you create the badge and
its id is in `src/shared/Heist/Badges.luau`, the server sends it to every player who earned it on their next join.
So you can create them on any day, in any order.

## Cost

- Each experience creates **5 badges free per UTC day**. Each further badge that day costs **100 Robux** (Roblox docs,
  as of October 2026; LihFolk vault "Badges and Achievement Design").
- **8 badges over two days = 0 Robux** (5 on day 1, 3 on day 2). All 8 on one day = 300 Robux.
- Create them on the **live** experience (the one players join). Badges belong to one experience, and a badge
  only awards in a place of that experience. The test experience (universe 10776026960) is only for tests.

## The files

| Key | Name | Tier | Icon |
|---|---|---|---|
| welcome | Welcome to the Hideout | bronze | `welcome.png` |
| first_heist | First Score | bronze | `first_heist.png` |
| first_clone | Meet Yourself | bronze | `first_clone.png` |
| eight_of_me | 8 OF ME | silver | `eight_of_me.png` |
| crew_up | Crew Up | silver | `crew_up.png` |
| daily_streak_3 | Hot Streak | silver | `daily_streak_3.png` |
| ghost | Ghost | gold | `ghost.png` |
| met_the_boss | Met the Boss | owner (cyan + gold) | `met_the_boss.png` |

The descriptions to paste are in `src/shared/Heist/Badges.luau` (`Badges.LIST`) and `docs/marketing/BADGES.md`.
Every icon is 512 x 512, and Roblox crops it to a circle; `contact_sheet.png` shows them cropped.

## Option A: Creator Hub, by hand (about 10 minutes)

1. Creator Hub > your experience > **Engagement > Badges > Create a Badge**.
2. Upload the PNG, then paste the name and the description exactly as in the table and `Badges.LIST`.
3. Leave it **Enabled**. Free while the day's quota lasts; the page shows the cost before you confirm.
4. Copy the badge id from its URL, then record it:
   `python3 tools/badge_upload.py --set ghost 1234567890`
   (optionally `--icon <image id>`, so the in-game card shows the real icon).
5. Do 5 on day 1 and 3 on day 2 for 0 Robux. Create them in the table's order (the game page lists badges in
   creation order).

## Option B: run the tool (Open Cloud)

1. Make an Open Cloud API key on your account (Creator Hub > Open Cloud > API Keys) with the
   `legacy-universe.badge:manage-and-spend-robux` scope (and `legacy-universe.badge:read` for the quota check),
   limited to the live experience.
2. `ROBLOX_API_KEY=<key> python3 tools/badge_upload.py --status` lists what is missing and what it costs.
3. `... --create --dry-run` prints what it would create. Nothing is sent.
4. `... --universe <LIVE_UNIVERSE_ID> --create --yes` creates the missing badges, **at most today's free quota**.
   It stops before any paid one unless you add `--allow-robux`. If the quota cannot be read, it creates nothing
   paid. Run it again the next day for the rest.
5. The tool writes each id (and the icon image id) into `src/shared/Heist/Badges.luau` right after creating it,
   then runs StyLua. Check the badges in Creator Hub (the docs warn that a key missing a scope may answer success
   without the change), run the local suite, commit and publish.

## After creating them

- Check that each badge is **Enabled**. The server reads `IsEnabled` once per server and skips a disabled badge.
- Optional: `STAFF_USER_IDS` in `Config.Badges` lists more "boss" accounts (it is empty by default; the owner is
  found automatically from the experience's creator or the owning group's owner).
- Do not rename a key in `Badges.LIST`: the key is what the player profiles store.
