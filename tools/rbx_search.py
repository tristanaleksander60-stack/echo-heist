#!/usr/bin/env python3
"""Search Roblox experiences: rbx_search.py "query" ["query2" ...]  -> playing | upvotes | name | universeId"""
import json, sys, urllib.parse, urllib.request
def search(q):
    url = "https://apis.roblox.com/search-api/omni-search?" + urllib.parse.urlencode({"searchQuery": q, "sessionId": "cli", "pageType": "all"})
    d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "rbx-search-cli"}), timeout=20))
    out = []
    for g in d.get("searchResults", []):
        for c in g.get("contents", []):
            if c.get("contentType") == "Game" or "universeId" in c:
                out.append(c)
    return out
for q in sys.argv[1:]:
    print(f"== {q}")
    try:
        for c in search(q)[:15]:
            print(f"{c.get('playerCount',0):>7} | {c.get('totalUpVotes',0):>8} | {c.get('name')} | {c.get('universeId')}")
    except Exception as e:
        print("ERR", e)
