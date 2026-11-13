#!/usr/bin/env python3
"""Create the launch badges on Roblox with Open Cloud and write their ids into src/shared/Heist/Badges.luau.
Guide and costs: docs/marketing/badges/UPLOAD.md. Nothing is created unless you pass --create and --yes.

  python3 tools/badge_upload.py --status                   # the set, the ids recorded, the icons on disk
  python3 tools/badge_upload.py --quota                    # today's free badge quota (read-only)
  python3 tools/badge_upload.py --create --dry-run         # what would be created, no network writes
  python3 tools/badge_upload.py --create --yes             # create the missing ones, at most the free quota today
  python3 tools/badge_upload.py --create --yes --only ghost met_the_boss
  python3 tools/badge_upload.py --create --yes --allow-robux   # past the free quota: 100 Robux each (your balance)
  python3 tools/badge_upload.py --set ghost 1234567890 [--icon 987654321]   # record a badge made in Creator Hub

API (Roblox Open Cloud, legacy badges API; LihFolk vault "Badges and Achievement Design" section 1, Roblox docs):
  POST /legacy-badges/v1/universes/{universeId}/badges   multipart form: name, description, paymentSourceType
       (1 = user funds, 2 = group funds), expectedCost (0 while the free quota lasts, else 100), isActive, files
       (the 512 x 512 PNG). Response JSON: id, iconImageId, ... Scope: legacy-universe.badge:manage-and-spend-robux.
  GET  /legacy-badges/v1/universes/{universeId}/free-badges-quota   (scope legacy-universe.badge:read; when it cannot
       be read, the tool assumes 0 free and refuses without --allow-robux)
  100 requests / minute per key owner. The docs warn that a key missing a scope may answer success without the change,
  so every created id is printed for you to check in Creator Hub.
Key: an Open Cloud API key of the experience owner with the scope above. In a Claude cloud session the network proxy
injects it (ROBLOX_API_KEY=proxy-injected, header x-api-key); locally set ROBLOX_API_KEY to the real key.
Ids are written after every badge, so a crash never loses one. Re-running skips badges that already have an id.
"""
import argparse
import json
import os
import pathlib
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
BADGES_LUAU = ROOT / "src/shared/Heist/Badges.luau"
ICONS = ROOT / "docs/marketing/badges"
UNIVERSE = "10776026960"  # the test experience (tools/cloud_test.py); pass --universe for the live one
API = "https://apis.roblox.com/legacy-badges/v1"
FREE_PER_DAY = 5  # Config.Badges.FREE_PER_DAY
ROBUX_EACH = 100  # Config.Badges.ROBUX_EACH_AFTER
GAP_SECONDS = 1.5
BEGIN, END = "-- BEGIN BADGE IDS", "-- END BADGE IDS"


# ------------------------------------------------------------------ the Luau data module
def read_set():
    """The launch set from Badges.LIST (key, tier, name, description) and the IDS / ICONS block."""
    text = BADGES_LUAU.read_text()
    body = text[text.index("Badges.LIST"):text.index(BEGIN)]
    defs = []
    for m in re.finditer(r'key = "([a-z0-9_]+)",\s*tier = "(\w+)",\s*name = "([^"]+)",\s*description = "([^"]+)"',
                         body):
        defs.append({"key": m.group(1), "tier": m.group(2), "name": m.group(3), "description": m.group(4)})
    block = text[text.index(BEGIN):text.index(END)]
    ids, icons = {}, {}
    part = block.split("Badges.ICONS")
    for m in re.finditer(r"([a-z0-9_]+) = (\d+),", part[0]):
        ids[m.group(1)] = int(m.group(2))
    for m in re.finditer(r"([a-z0-9_]+) = (\d+),", part[1]):
        icons[m.group(1)] = int(m.group(2))
    return defs, ids, icons


def write_ids(defs, ids, icons):
    text = BADGES_LUAU.read_text()
    lines = [f"{BEGIN} (tools/badge_upload.py rewrites this block; 0 = not created yet)", "Badges.IDS = table.freeze({"]
    lines += [f"\t{d['key']} = {int(ids.get(d['key'], 0))}," for d in defs]
    lines += ["} :: { [string]: number })", "Badges.ICONS = table.freeze({"]
    lines += [f"\t{d['key']} = {int(icons.get(d['key'], 0))}," for d in defs]
    lines += ["} :: { [string]: number })", ""]
    a = text.index(BEGIN)
    b = text.index(END)
    BADGES_LUAU.write_text(text[:a] + "\n".join(lines) + text[b:])


# ------------------------------------------------------------------ HTTP
def key():
    k = os.environ.get("ROBLOX_API_KEY")
    if not k:
        sys.exit("set ROBLOX_API_KEY (in a Claude cloud session: ROBLOX_API_KEY=proxy-injected)")
    return k


def call(method, url, body=None, ctype=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": key()})
    if ctype:
        req.add_header("Content-Type", ctype)
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
                return r.status, json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:400]
            if e.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(10 * (attempt + 1))
                continue
            return e.code, {"error": msg}
    return 0, {"error": "no answer"}


def multipart(fields, file_field, file_path):
    boundary = uuid.uuid4().hex
    out = []
    for name, value in fields.items():
        out.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode())
    data = pathlib.Path(file_path).read_bytes()
    out.append((f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; '
                f'filename="{pathlib.Path(file_path).name}"\r\nContent-Type: image/png\r\n\r\n').encode())
    out.append(data)
    out.append(f"\r\n--{boundary}--\r\n".encode())
    return b"".join(out), f"multipart/form-data; boundary={boundary}"


def free_quota(universe):
    status, body = call("GET", f"{API}/universes/{universe}/free-badges-quota")
    if status == 200 and isinstance(body, int):
        return body
    if status == 200 and isinstance(body, dict):
        for k in ("freeBadgesQuota", "quota", "remaining"):
            if isinstance(body.get(k), int):
                return body[k]
    return None


# ------------------------------------------------------------------ commands
def validate(defs):
    problems = []
    for d in defs:
        if not (3 <= len(d["name"]) <= 50):
            problems.append(f"{d['key']}: name length {len(d['name'])}")
        if not (10 <= len(d["description"]) <= 200):
            problems.append(f"{d['key']}: description length {len(d['description'])}")
        if not (ICONS / f"{d['key']}.png").is_file():
            problems.append(f"{d['key']}: icon missing ({ICONS / (d['key'] + '.png')})")
    return problems


def status(defs, ids, icons):
    for d in defs:
        icon = ICONS / f"{d['key']}.png"
        print(f"{d['key']:16s} {d['tier']:7s} id {ids.get(d['key'], 0):>12}  icon id {icons.get(d['key'], 0):>12}  "
              f"{'png ok' if icon.is_file() else 'PNG MISSING'}  {d['name']}")
    todo = sum(1 for d in defs if not ids.get(d["key"]))
    print(f"\n{todo} of {len(defs)} not created yet. Free: {FREE_PER_DAY} per UTC day per experience, then "
          f"{ROBUX_EACH} Robux each. Creating all {todo} in one day costs {max(0, todo - FREE_PER_DAY) * ROBUX_EACH} "
          f"Robux; over two days, 0.")


def create(defs, ids, icons, a):
    problems = validate(defs)
    if problems:
        sys.exit("refusing: " + "; ".join(problems))
    todo = [d for d in defs if not ids.get(d["key"]) and (not a.only or d["key"] in a.only)]
    if not todo:
        print("nothing to create: every badge has an id")
        return
    if a.dry_run or not a.yes:
        for d in todo:
            print(f"would create {d['key']}: {d['name']!r} / {d['description']!r} with {d['key']}.png")
        print(f"\n{len(todo)} badge(s). Add --yes to create them (see --quota and docs/marketing/badges/UPLOAD.md).")
        return
    free = free_quota(a.universe)
    print(f"free badge quota today: {free if free is not None else 'unknown (treated as 0)'}")
    free = free or 0
    made = 0
    for d in todo:
        paid = made >= free
        if paid and not a.allow_robux:
            print(f"stop: the free quota is used up; {d['key']} and later ones would cost {ROBUX_EACH} Robux each. "
                  "Run again tomorrow (UTC) or add --allow-robux.")
            break
        fields = {"name": d["name"], "description": d["description"], "paymentSourceType": str(a.payment),
                  "expectedCost": str(ROBUX_EACH if paid else 0), "isActive": "true"}
        body, ctype = multipart(fields, "files", ICONS / f"{d['key']}.png")
        st, res = call("POST", f"{API}/universes/{a.universe}/badges", body, ctype)
        if st not in (200, 201) or not isinstance(res, dict) or not res.get("id"):
            print(f"FAILED {d['key']}: HTTP {st} {res}")
            break
        ids[d["key"]] = int(res["id"])
        if res.get("iconImageId"):
            icons[d["key"]] = int(res["iconImageId"])
        write_ids(defs, ids, icons)  # after every badge: a crash never loses an id
        made += 1
        print(f"created {d['key']}: badge {ids[d['key']]} (icon {icons.get(d['key'], 0)})")
        time.sleep(GAP_SECONDS)
    if made:
        fmt()
        print("\nIds written to src/shared/Heist/Badges.luau. Check them in Creator Hub > Engagement > Badges, then "
              "run the local suite and commit.")


def fmt():
    if subprocess.run(["which", "stylua"], capture_output=True).returncode == 0:
        subprocess.run(["stylua", str(BADGES_LUAU)])


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--quota", action="store_true")
    ap.add_argument("--create", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--yes", action="store_true", help="really create (may use the free quota)")
    ap.add_argument("--allow-robux", action="store_true", help="also past the free quota (100 Robux each)")
    ap.add_argument("--only", nargs="+")
    ap.add_argument("--universe", default=UNIVERSE)
    ap.add_argument("--payment", type=int, default=1, choices=(1, 2), help="1 = user funds, 2 = group funds")
    ap.add_argument("--set", nargs=2, metavar=("KEY", "BADGE_ID"))
    ap.add_argument("--icon", type=int, help="with --set: the badge's icon image id")
    a = ap.parse_args(argv)
    defs, ids, icons = read_set()
    if not defs:
        sys.exit("could not read Badges.LIST from " + str(BADGES_LUAU))
    if a.set:
        k, v = a.set
        if k not in {d["key"] for d in defs} or not v.isdigit():
            sys.exit("--set KEY BADGE_ID: a known key and a numeric id")
        ids[k] = int(v)
        if a.icon:
            icons[k] = a.icon
        write_ids(defs, ids, icons)
        fmt()
        print(f"recorded {k} = {v}")
    elif a.quota:
        q = free_quota(a.universe)
        print(f"free badges left today (universe {a.universe}): {q if q is not None else 'unknown (endpoint refused)'}")
    elif a.create:
        create(defs, ids, icons, a)
    else:
        status(defs, ids, icons)


if __name__ == "__main__":
    main(sys.argv[1:])
