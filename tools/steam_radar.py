#!/usr/bin/env python3
"""Steam radar: rising indie co-op games, live player counts, and whether Roblox already has a copy.

Usage: python3 steam_radar.py [--lists popularnew,popularcomingsoon,topsellers] [--count 50] [--min-players 300]

For each game on the chosen Steam search lists (filtered to Online Co-Op by default):
- current players (Steam Web API), release date, short description, price;
- a Roblox search on the game's name, showing the best match and its CCU, so you can see if it is already copied;
- a snapshot in ../radar/steam-*.json so the next run shows player growth (the early-warning signal).
"""
import argparse, datetime as dt, glob, json, os, re, sys, time, urllib.parse, urllib.request

UA = {"User-Agent": "steam-radar-cli"}
TAGS = {"online-coop": "3843", "coop": "1685", "multiplayer": "3859", "none": ""}


def get(url, raw=False):
    req = urllib.request.Request(url, headers=UA)
    data = urllib.request.urlopen(req, timeout=30).read()
    return data.decode("utf-8", "replace") if raw else json.loads(data)


def steam_list(filt, tag, count):
    q = {"filter": filt, "json": 1, "count": count, "cc": "us", "l": "english"}
    if tag:
        q["tags"] = tag
    items = get("https://store.steampowered.com/search/results/?" + urllib.parse.urlencode(q)).get("items", [])
    out = []
    for it in items:
        m = re.search(r"/apps/(\d+)/", it.get("logo", ""))
        if m:
            out.append((int(m.group(1)), it["name"]))
    return out


def players(appid):
    try:
        return get(f"https://api.steampowered.com/ISteamUserStats/GetNumberOfCurrentPlayers/v1/?appid={appid}")["response"].get("player_count", 0)
    except Exception:
        return None


def appdetails(appid):
    try:
        d = get(f"https://store.steampowered.com/api/appdetails?appids={appid}&cc=us&l=english")[str(appid)]
        return d.get("data", {}) if d.get("success") else {}
    except Exception:
        return {}


def roblox_best(name):
    try:
        q = re.sub(r"[^\w\s']", " ", name).strip()
        url = "https://apis.roblox.com/search-api/omni-search?" + urllib.parse.urlencode({"searchQuery": q, "sessionId": "radar", "pageType": "all"})
        d = get(url)
        games = [c for g in d.get("searchResults", []) for c in g.get("contents", []) if "universeId" in c]
        words = {w.lower() for w in q.split() if len(w) > 3}
        hits = [c for c in games if words and words & {w.lower() for w in re.findall(r"\w+", c.get("name", ""))}]
        if not hits:
            return "none found"
        best = max(hits, key=lambda c: c.get("playerCount", 0))
        return f"{best.get('playerCount', 0)} CCU: {best.get('name')}"
    except Exception as e:
        return f"error {e.__class__.__name__}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lists", default="popularnew,popularcomingsoon")
    ap.add_argument("--tag", default="online-coop", choices=TAGS.keys())
    ap.add_argument("--count", type=int, default=40)
    ap.add_argument("--min-players", type=int, default=0)
    ap.add_argument("--snapdir", default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "radar"))
    a = ap.parse_args()
    os.makedirs(a.snapdir, exist_ok=True)
    now = dt.datetime.now(dt.timezone.utc)

    seen = {}
    for filt in a.lists.split(","):
        for appid, name in steam_list(filt, TAGS[a.tag], a.count):
            seen.setdefault(appid, {"name": name, "lists": []})["lists"].append(filt)

    prev_files = sorted(glob.glob(os.path.join(a.snapdir, "steam-*.json")))
    prev = json.load(open(prev_files[-1]))["rows"] if prev_files else {}

    rows = {}
    for appid, v in seen.items():
        p = players(appid)
        det = appdetails(appid)
        rows[str(appid)] = {
            "name": v["name"], "lists": v["lists"], "players": p,
            "release": (det.get("release_date") or {}).get("date", "?"),
            "coming_soon": (det.get("release_date") or {}).get("coming_soon"),
            "price": (det.get("price_overview") or {}).get("final_formatted", "free" if det.get("is_free") else "?"),
            "desc": (det.get("short_description") or "")[:170],
        }
        time.sleep(0.3)
    json.dump({"time": now.isoformat(), "rows": rows}, open(os.path.join(a.snapdir, now.strftime("steam-%Y%m%dT%H%M%SZ.json")), "w"))

    ranked = sorted(rows.items(), key=lambda kv: kv[1]["players"] or 0, reverse=True)
    print(f"Steam radar {now:%Y-%m-%d %H:%M} UTC | lists={a.lists} tag={a.tag} | {len(rows)} games"
          + ("" if prev else " | first snapshot (run again later for growth)"))
    for appid, r in ranked:
        if (r["players"] or 0) < a.min_players and not r["coming_soon"]:
            continue
        g = ""
        if appid in prev and prev[appid].get("players"):
            g = f" x{(r['players'] or 0) / prev[appid]['players']:.1f}"
        print(f"{str(r['players']):>7}{g:>6} | {r['name']} | {r['release']} | {r['price']} | {','.join(r['lists'])}")
        print(f"         {r['desc']}")
        print(f"         Roblox: {roblox_best(r['name'])}")


if __name__ == "__main__":
    sys.exit(main())
