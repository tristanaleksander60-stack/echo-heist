# BADGES: the Roblox badges of Heist Yourself

_BADGES track, 2026-11-13. These are Roblox **badges** (achievements on the game page and the player's profile).
They are not Roblox Experience Events (STORE_PAGE.md §9 covers those)._

Owner decision: **start with exactly 8 badges**, all detectable in the current build, and keep a "later" list for
the rest (no icons for those yet). Code: `src/shared/Heist/Badges.luau` (data + pure conditions), server
`src/server/Data/Awards.luau` (the pipeline), client `src/client/Heist/BadgeView.luau` (the card and the boss's marks).
Numbers: `Config.Badges`. Words: `Strings` (card) and `Badges.LIST` (the badge text on Roblox). Icons:
`docs/marketing/badges/` (render: `tools/blender/badge_icons.py`). Creating them on Roblox: `badges/UPLOAD.md`.

## 1. The launch set (8)

| # | Key | Name | Tier | Description (Roblox shows this) | Decided by the server from |
|---|---|---|---|---|---|
| 1 | `welcome` | Welcome to the Hideout | bronze | Join Heist Yourself and step into the hideout. | the profile loading (DataService.Loaded); offline Studio: PlayerAdded |
| 2 | `first_heist` | First Score | bronze | Clear your first heist. | the sim's result at heist end (complete, untainted); a profile with `stats.clears > 0` counts too |
| 3 | `first_clone` | Meet Yourself | bronze | Rewind and see your first clone replay your run. | the sim's `RunStart`: one of your own (non-helper) clone actors is in the run |
| 4 | `eight_of_me` | 8 OF ME | silver | Have 8 copies of yourself in one run: 7 clones and you. | the sim's `Swarm` event: your copies >= `Config.Sim.SWARM_OF_ME` (8); the same fact as the in-game stamp |
| 5 | `crew_up` | Crew Up | silver | Clear a heist with a crew of 2 or more players. | heist end: cleared, untainted, `CREW_UP_MIN` (2) real players still in the crew |
| 6 | `daily_streak_3` | Hot Streak | silver | Reach a daily vault streak of 3. | the profile: `daily.bestStreak >= STREAK_DAYS` (3), checked on join and after each daily vault |
| 7 | `ghost` | Ghost | gold | Clear a heist that Gus guards without him spotting you on the winning run. | heist end: cleared, untainted, not Relaxed, the level has a Gus, you played the final run live, and no sim `Spotted` event hit your live run in it |
| 8 | `met_the_boss` | Met the Boss | owner | Play in the same server as the creator of Heist Yourself for a minute. | the server's own player list: a boss is here and you add up `BOSS_TOGETHER_SECONDS` (60) together |

Why these 8: welcome, first heist and first clone teach the loop (onboarding rewards). 8 OF ME is the game's promise
(T1 thumbnail, the stamp). Crew Up rewards co-op. Hot Streak is the daily habit. Ghost is the skill badge. Met the Boss
is the community badge. Every tier is used: 3 bronze, 3 silver, 1 gold, 1 owner.

### Met the Boss (Played with the Owner): the rules
- **Who is the boss:** the experience owner. A user-owned game uses `game.CreatorId`; a group-owned game uses the
  group's owner (`GroupService:GetGroupInfoAsync(...).Owner.Id`). `Config.Badges.STAFF_USER_IDS` can add more ids
  (empty by default).
- **Decided on the server only:** the server's player list, ticked every `BOSS_TICK_SECONDS`. A client can claim nothing.
- **Not farmable:** it is a one-time badge, it needs the owner online in that very server (owners are rarely online),
  and it needs 60 s together. Time adds up over visits, and a server hitch adds at most two ticks. The boss never
  earns it from themselves.
- **My call:** being in the server is enough, with no need to finish a heist together. Heists are per crew, so
  "finish a heist with the owner" would need the owner to crew up with strangers; that is unsafe (it pushes
  strangers into the owner's crew) and rare. A minute in the same hideout is honest ("Play in the same server") and safe.
- **Replicated as attributes, no remotes:** `ReplicatedStorage.BossUserId` (non-zero while a boss is here) makes
  every client show **THE BOSS IS HERE!** on the message rail (not on the boss's own screen). `Player.Boss = true`
  puts a gold **THE BOSS** pill over that player's Rookie on every other screen.

## 2. Platform rules (LihFolk vault, Roblox docs as of Oct 2026)

- **Creation:** 5 free badges per experience per UTC day, then **100 Robux** each. 8 badges over 2 days cost 0.
  Open Cloud: `POST /legacy-badges/v1/universes/{id}/badges`, scope `legacy-universe.badge:manage-and-spend-robux`
  (a 6th badge spends Robux), 100 requests per minute per key owner.
- **API names (2026):** `BadgeService:AwardBadgeAsync`, `UserHasBadgeAsync`, `GetBadgeInfoAsync`,
  `CheckUserBadgesAsync`. The old `AwardBadge` and `UserHasBadge` were renamed on Jan 14, 2026.
- **Award rules:** server only; the player must be in the server now; they must not own it already (a player may
  delete a badge and earn it again); the badge must be enabled and belong to this experience. The rate limit is
  **50 + 35 x players per minute** (shared here with `UserHasBadgeAsync`; we use half: `RATE_HEADROOM`).
- **Text:** a name and a description that says what the player must do. Roblox's exact length caps were not
  reachable from the vault or the docs mirror here, so we keep our own caps (`Config.Badges.NAME_MAX` 50,
  `DESCRIPTION_MAX` 200; checked by `Badges.validate` and the unit spec). No misleading text: every description is
  exactly the server's condition (e.g. Ghost says "on the winning run", Met the Boss says "for a minute").
- **Icon:** a 512 x 512 upload, shown cropped to a circle. Keep the subject inside the circle.

## 3. How awarding works (server)

1. A server-decided fact calls `Awards.earn(player, key)`. Sources: `HeistInstance` (the sim's `RunStart`, `Swarm`,
   `Spotted` events and the heist result), `DataService.Loaded` / `Changed` (the profile), and the boss loop.
2. The **ledger** is the profile (additive Schema fields, sanitized like the others; no migration):
   - `Heist.badges`: badge key -> unix time earned. Kept even while the badge id is 0. Unknown keys are kept, so a
     rollback build never forgets a newer badge.
   - `Heist.badgesSent`: badge key -> true once Roblox has it (`AwardBadgeAsync` returned true, or
     `UserHasBadgeAsync` said owned). A sent badge is never sent again: a player who deleted it does not get it
     back on every join.
3. The first earn writes the ledger, sets the player attribute `BadgeToast = "<key>#<n>"` (the client's BADGE
   UNLOCKED card) and queues the Roblox award. A per-player cache answers repeats without touching the profile or
   the API.
4. The **worker** (every 0.5 s) checks `GetBadgeInfoAsync` once per badge per server (cached; a disabled badge is
   skipped and logged once), spends the rate budget, and calls `AwardBadgeAsync` in pcall. On a failure it asks
   `UserHasBadgeAsync`, then retries with backoff (2 s, 6 s, 15 s). After 3 tries it waits for the next join.
5. **Id 0** (not created yet): nothing is called. The badge stays earned in the profile and is sent on a later join
   once the id exists.
6. **Joins:** badges earned before the profile loaded are written, earned-but-unsent ones are queued again, and old
   progress counts (a profile with clears gets First Score; a best streak of 3 gets Hot Streak).

Player attributes: `BadgeToast` (string), `BadgesEarned` (whole number, the card's "3 OF 8 BADGES"), `Boss` (true on
the boss). ReplicatedStorage: `BossUserId` (number, 0 = none). No new remotes.

## 4. Later (not in the launch set; no icons yet)

| Idea | Detectable now? | What it needs |
|---|---|---|
| All 6 heists cleared ("Full Tape") | yes: `levels[*].clears` per `LEVEL_ORDER` | add to `profileBadges` |
| All stars / every medal ("Star Thief") | yes: `Progress.totalStars` against the max | a max-stars helper |
| Speed run under par ("Fast Hands") | partly: `clones <= par` is the Crew medal; time par is not defined | a time par per level |
| Full 4-player van crew ("Full Van") | yes: crewPlayers >= 4 at heist end | one more `heistBadges` rule |
| 16 robbers at once ("16 ROBBERS") | yes: the `Swarm` event's `c` = crew copies | a rule on `c >= 16` |
| Daily streak 7 ("On Fire") | yes: `bestStreak >= 7` | one more `profileBadges` rule |
| Every advent day ("Advent Complete") | yes: the ornaments on the advent tree (`trophies`) | count December ornaments |
| Christmas finale ("Steal Back Christmas") | **no**: the event level is not in the build (L6 is the launch finale) | future, with the event level |
| Slide past Gus ("Slick") | partly: slides are recorded (`EVENT.Slide`); "past Gus" has no sim fact yet | a sim fact for a slide inside Gus's cone without a Spotted |
| Wardrobe ("Dressed to Steal") | yes: `outfit` changes / unlocked outfit pieces | a rule on the outfit unlocks |
| Gus catches your clone instead of you ("Wrong One!", secret) | yes: `Busted` on your clone in a run where you were not caught | a heist-scoped fact per member |

## 5. Icons

Rendered from the real kit in Blender (`python3 tools/blender/badge_icons.py --all`): the Rookie in his default
outfit (flat cap, long scarf, Breton stripes, knit gloves), clones in crew hues (cyan, magenta, indigo) drawn like
EchoView, Gus with his torch, the cash bag and the vault door. The 2D finish adds a themed disc, a numeral or a
speech bubble where it helps the read, and an ink outline. Every badge has the same rim: a metal ring in the tier
colour with **tier studs** (1 bronze, 2 silver, 3 gold), so the tier never rests on colour alone. The owner badge
has a cyan ring, a gold inner ring and a crown. Everything sits inside the inner disc (radius 0.405 of the image).
Corners are ink.

### Icon checklist (ICON_THUMBNAILS §3.2 and §7 adapted to badges)
Measured by `--sheet` (grades.json): contrast at 64 px, value range, subject centred, crop-safe, colour pop. Rim,
tier and originality are by construction. Judged on the contact sheet at 150 and 64 px: focal subject, meaning (does
it say the achievement), emotion or action, text discipline (one numeral or one short word at most), clutter, and
novelty within the set. Pass: **>= 8.5**.

| Badge | Score | Weakest item (fixed) |
|---|---|---|
| welcome | 9.08 | meaning: the "HI!" bubble was added to the wave |
| first_heist | 9.23 | the bag hid the face, so it moved to the chest |
| first_clone | 9.28 | the hero was cropped, so the camera pulled back |
| eight_of_me | 9.22 | the "8" was hidden behind the hero; it is now a stamp in front |
| crew_up | 9.11 | contrast at 64 px (6.2): a brighter disc and a key light |
| daily_streak_3 | 9.23 | the dark vault door filled the frame: it was shrunk and lit |
| ghost | 8.97 | the dark silhouette and the "?" over the hero: Gus now turns away against amber, with the "?" over Gus |
| met_the_boss | 9.39 | the second Rookie was off-frame, so the shot frames both heads |

Still to do by people (ICON_THUMBNAILS §3.2): the phone check at 48-150 px and the owner's sign-off.
