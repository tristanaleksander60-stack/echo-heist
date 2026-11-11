# ECHO HEIST (working title), "Rob the vault with yourself"

**Pitch:** "Every heist is a 60-second loop. On each new run, your past selves replay exactly what you did, so you become your own crew."

## How it plays
- **Run 1:** you press the button that opens the vault door for 3 seconds. You can't make it through alone.
- **Run 2:** your *echo* (a recording of run 1) presses the button while you run through and grab the loot.
- **Run 3+:** more echoes: one distracts the guard, one carries the safe, one holds the laser door open.
- **Solo:** you plus your echoes are a full crew, so it works perfectly alone.
- **With friends (2-4):** everyone plus all their echoes means 10-16 robbers at once: coordinated heists or total chaos.

## Why it is funny and clip-friendly (works with the sound off)
- Your echoes **repeat your mistakes too**: your past self walks straight into the laser again, every single time.
- "My past self betrayed me": the echo opens the door at the wrong moment and the guard sees you.
- The satisfying clip: 8 copies of you doing a perfectly synchronised heist.
- The guard catches the echo and stands looking confused while the real you sneaks past.

## Progression (Dig to Escape addictiveness)
- Loot → upgrades: more echo slots, a longer loop, gadgets (rope, smoke bomb, magnet).
- Bigger targets: corner shop → bank → museum → casino → the moon base.
- Rare loot for your own hideout (a trophy wall that others can visit).
- Daily "Vault of the Day" (same level on all servers: "how few echoes did you need?").

## Christmas launch event
"Steal Back Christmas": a greedy toy tycoon has locked up all the presents in his vault. Use your echoes to get them back before Christmas morning. (An original villain, no borrowed IP.)

## Originality check (2026-11-11)
- **Roblox:** the "clone" games (Clone Engine 417M visits, Clone Friends 151M, Clone Yourself 240M, Clone Adventure 69M) are sandboxes where clones *follow* you or obey commands. **No game uses recordings of your past runs as co-op partners** (searched: clone yourself, past self, time clone, copies of yourself, replay yourself, echo heist, record and replay).
- **Steam:** the time-clone mechanic exists in older single-player puzzle indies, but it is not a current viral co-op hit.
- **Status: GREEN on the mechanic.** The risk is the flip side: no proven demand signal right now. The heist theme provides the demand (heist and steal games are big on Roblox).

## Technical notes
- Record each player's movement plus actions per tick (server-validated), and replay them as NPC rigs.
- Doors, buttons, guards and loot are server-authoritative and deterministic, so echoes trigger the same events.
- That is technically demanding, which is a moat: fast AI clones will struggle to copy it well.
