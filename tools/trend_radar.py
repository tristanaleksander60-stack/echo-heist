#!/usr/bin/env python3
"""Roblox trend radar: finds NEW experiences (created within --days) that are growing fast.

Usage: python3 trend_radar.py [--days 21] [--top 40] [--snapdir DIR]

- Pulls every sort on Roblox's explore page (Top Trending, Up-and-Coming, Fun with Friends, ...).
- Fetches created date, current players, visits and max server size for each game.
- Ranks young games by players and visits per day of age.
- Saves a timestamped snapshot; if an older snapshot exists, shows growth since then
  (the real early-warning signal: a young game whose CCU multiplies between runs).
"""
import argparse, datetime as dt, glob, json, os, sys, urllib.parse, urllib.request

UA = {"User-Agent": "trend-radar-cli"}


def get(url):
    req = urllib.request.Request(url, headers=UA)
    return json.load(urllib.request.urlopen(req, timeout=30))


def all_sorts():
    sorts, token = {}, None
    for _ in range(10):
        q = {"sessionId": "radar", "device": "computer", "country": "all"}
        if token:
            q["sortsPageToken"] = token
        d = get("https://apis.roblox.com/explore-api/v1/get-sorts?" + urllib.parse.urlencode(q))
        for s in d.get("sorts", []):
            games = s.get("games") or []
            if games:
                sorts[s.get("sortDisplayName") or s.get("sortId")] = [g["universeId"] for g in games if "universeId" in g]
        token = d.get("nextSortsPageToken")
        if not token:
            break
    return sorts


def details(ids):
    out = {}
    ids = list(ids)
    for i in range(0, len(ids), 50):
        chunk = ",".join(str(x) for x in ids[i:i + 50])
        for g in get("https://games.roblox.com/v1/games?universeIds=" + chunk).get("data", []):
            out[g["id"]] = g
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=21, help="max age in days")
    ap.add_argument("--top", type=int, default=40)
    ap.add_argument("--snapdir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "radar"))
    a = ap.parse_args()
    os.makedirs(a.snapdir, exist_ok=True)

    now = dt.datetime.now(dt.timezone.utc)
    sorts = all_sorts()
    where = {}
    for name, ids in sorts.items():
        for u in ids:
            where.setdefault(u, []).append(name)
    info = details(where.keys())

    rows = []
    for u, g in info.items():
        created = dt.datetime.fromisoformat(g["created"].replace("Z", "+00:00"))
        age = max((now - created).total_seconds() / 86400, 0.25)
        rows.append({
            "id": u, "name": g["name"], "playing": g.get("playing", 0), "visits": g.get("visits", 0),
            "age_days": round(age, 1), "visits_per_day": int(g.get("visits", 0) / age),
            "max_players": g.get("maxPlayers"), "created": g["created"][:10],
            "sorts": where[u], "desc": (g.get("description") or "").replace("\n", " ")[:160],
        })

    snap = os.path.join(a.snapdir, now.strftime("%Y%m%dT%H%M%SZ") + ".json")
    prev_files = sorted(glob.glob(os.path.join(a.snapdir, "*.json")))
    prev = {}
    prev_time = None
    if prev_files:
        with open(prev_files[-1]) as f:
            p = json.load(f)
        prev = {r["id"]: r for r in p["rows"]}
        prev_time = p["time"]
    with open(snap, "w") as f:
        json.dump({"time": now.isoformat(), "rows": rows}, f)

    young = [r for r in rows if r["age_days"] <= a.days]
    young.sort(key=lambda r: r["playing"], reverse=True)
    print(f"Radar {now:%Y-%m-%d %H:%M} UTC | {len(rows)} games on explore | {len(young)} created within {a.days} days"
          + (f" | growth vs {prev_time[:16]}" if prev_time else " | first snapshot (run again later for growth)"))
    print(f"{'players':>8} {'growth':>7} {'visits/day':>11} {'age':>5} {'srv':>4}  name  [sorts]")
    for r in young[:a.top]:
        g = ""
        if r["id"] in prev and prev[r["id"]]["playing"]:
            g = f"x{r['playing'] / prev[r['id']]['playing']:.1f}"
        elif prev_time:
            g = "NEW"
        print(f"{r['playing']:>8} {g:>7} {r['visits_per_day']:>11,} {r['age_days']:>5} {str(r['max_players']):>4}  {r['name']}  [{', '.join(s[:14] for s in r['sorts'])}]")
        print(f"{'':>40}{r['desc']}")


if __name__ == "__main__":
    sys.exit(main())
