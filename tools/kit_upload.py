#!/usr/bin/env python3
"""Upload the art kit to Roblox with the Open Cloud Assets API (spike S2, automated path: no Studio).

One Model asset per kit model group (assets/fbx/<Model>.fbx, the `model` field of each part in
assets/fbx/kit_manifest.json), plus the textures in assets/textures/ as Decals. The ids go to
assets/kit_ids.json. KitService (src/server/Kit/KitService.luau) loads the groups at server boot with
InsertService:LoadAsset. Guide: docs/art/KIT_IMPORT.md "Automated path".

  python3 tools/kit_upload.py --probe            # upload ONE small file (the smallest pending group)
  python3 tools/kit_upload.py --all              # upload every new or changed group
  python3 tools/kit_upload.py --only Safe Van    # just these groups
  python3 tools/kit_upload.py --images           # upload new or changed assets/textures/*.png as Decals
  python3 tools/kit_upload.py --appearances      # build + upload the hero SurfaceAppearances (needs Lune)
  python3 tools/kit_upload.py --all --dry-run    # print what would happen
  python3 tools/kit_upload.py --status           # list groups and images: uploaded / changed / pending
  python3 tools/kit_upload.py --gen              # regenerate the Luau data only (no network)
  python3 tools/kit_upload.py --set-image EH_Palette_Bank 123   # record a Decal's resolved image id

Every run that changes ids (and --gen) regenerates src/server/Kit/KitData.luau (manifest + ids, read by
KitService) and the embedded table in tests/kit_engine.luau (the real-engine check), then formats both
with StyLua when it is installed.

Idempotent: a file whose hash matches the recorded hash is skipped. A changed FBX updates the SAME
asset (PATCH: a new asset version, so the id stays; LoadAsset gets the latest version); --new makes a
fresh asset instead (the old id goes to `history`). Decals cannot be updated: a changed PNG is a new
Decal. Ids are written after every upload, so a crash never loses one.

API (Roblox Open Cloud, Assets v1, Beta; checked against the LihFolk vault, Nov 2026):
  POST  /assets/v1/assets                 multipart: request (JSON) + fileContent (model/fbx, image/png)
  PATCH /assets/v1/assets/{assetId}       multipart: request {"assetId": id} + fileContent
  GET   /assets/v1/operations/{id}        poll until done; response.assetId
Key: an Open Cloud API key with asset:read + asset:write for the experience owner. In a Claude cloud
session the network proxy injects it (any placeholder works); locally set ROBLOX_API_KEY. The assets
must belong to the experience owner (user 10346200733), or InsertService:LoadAsset fails in the game.

Hero SurfaceAppearances (manifest `texture`, e.g. VaultDoor_DialFace): runtime scripts cannot write
SurfaceAppearance maps (ColorMapContent needs Plugin capability, measured), so --appearances builds one
rbxm with Lune (a Model of SurfaceAppearances named after the piece, maps = the uploaded image ids) and
uploads it as a Model; KitService clones each onto its piece. Run it after --images and --set-image.
"""
import argparse
import hashlib
import json
import os
import pathlib
import random
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "assets/fbx/kit_manifest.json"
IDS = ROOT / "assets/kit_ids.json"
FBX_DIR = ROOT / "assets/fbx"
TEX_DIR = ROOT / "assets/textures"
KIT_DATA = ROOT / "src/server/Kit/KitData.luau"
ENGINE_TEST = ROOT / "tests/kit_engine.luau"
sys.path.insert(0, str(ROOT / "tools/blender"))
from kit_docs import idle_colour  # noqa: E402  (the prepare script's colour rule: Neon idle, glass, ornaments)

API = "https://apis.roblox.com/assets/v1"
OWNER_USER_ID = "10346200733"  # experience owner (universe 10776026960)
CREATOR = {"userId": OWNER_USER_ID}  # --group <id> switches to a group-owned upload (a group-owned game)
DISPLAY_PREFIX = "EH Kit "  # display names are capped at 50 characters
GAP_SECONDS = 2.0  # pause between uploads (rate limits are not published; back off on 429)
POLL_LIMIT_SECONDS = 300
TABLE_START = "-- kit-table:start"
TABLE_END = "-- kit-table:end"
SCOPE_HELP = """
The API key cannot write assets (HTTP {code}). Owner action (Creator Dashboard > Open Cloud > API Keys):
  1. Edit the key this project uses (the one the Claude environment injects for apis.roblox.com).
  2. Access Permissions > Add API System: "Assets" (asset). Operations: Read AND Write.
  3. The key owner must be the experience owner (user {owner}); for a group game, a group key.
  4. Save. Then run: python3 tools/kit_upload.py --probe   (then --all and --images)
Server response: {body}
"""


class ScopeError(Exception):
    pass


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: pathlib.Path, default):
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return default


def save_ids(ids: dict) -> None:
    tmp = IDS.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(ids, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, IDS)


def load_ids() -> dict:
    ids = load_json(IDS, None) or {}
    ids.setdefault("note", "Generated by tools/kit_upload.py: one Open Cloud Model asset per kit model group "
                   "(assets/fbx/<model>.fbx) and one Decal per assets/textures/*.png. Read by "
                   "src/server/Kit/KitService.luau through the generated KitData.luau. Do not edit by hand.")
    ids.setdefault("creator", dict(CREATOR))
    ids.setdefault("models", {})
    ids.setdefault("images", {})
    ids.setdefault("appearances", None)
    return ids


def load_manifest() -> dict:
    manifest = load_json(MANIFEST, None)
    if manifest is None:
        sys.exit(f"missing {MANIFEST}")
    return manifest


def groups_from_manifest(manifest: dict) -> dict:
    """{model: [piece names]} in a stable order."""
    groups: dict = {}
    for name, part in sorted(manifest["parts"].items()):
        groups.setdefault(part["model"], []).append(name)
    return dict(sorted(groups.items()))


# ------------------------------------------------------------------------------------------ HTTP

def multipart(fields: list) -> tuple:
    """fields: [(name, filename or None, content_type, bytes)] -> (body, content type header)."""
    boundary = "----ehkit" + uuid.uuid4().hex
    out = bytearray()
    for name, filename, ctype, data in fields:
        out += f"--{boundary}\r\n".encode()
        disp = f'form-data; name="{name}"'
        if filename:
            disp += f'; filename="{filename}"'
        out += f"Content-Disposition: {disp}\r\nContent-Type: {ctype}\r\n\r\n".encode()
        out += data + b"\r\n"
    out += f"--{boundary}--\r\n".encode()
    return bytes(out), f"multipart/form-data; boundary={boundary}"


def call(method: str, url: str, key: str, body: bytes = None, ctype: str = None) -> dict:
    """HTTP with backoff on 429 / 5xx / network errors. 401/403 raise ScopeError."""
    for attempt in range(8):
        headers = {"x-api-key": key, "User-Agent": "eh-kit-upload"}
        if ctype:
            headers["Content-Type"] = ctype
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=180) as r:
                raw = r.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            text = e.read().decode(errors="replace")[:1500]
            if e.code in (401, 403):
                raise ScopeError(SCOPE_HELP.format(code=e.code, owner=OWNER_USER_ID, body=text))
            if e.code == 429 or e.code >= 500:
                retry = e.headers.get("Retry-After")
                wait = float(retry) if retry and retry.replace(".", "", 1).isdigit() else min(60, 2**attempt)
                wait += random.uniform(0, 1)
                print(f"  HTTP {e.code} on {method}; retry in {wait:.1f}s", flush=True)
                time.sleep(wait)
                continue
            raise RuntimeError(f"HTTP {e.code} on {method} {url}\n{text}")
        except urllib.error.URLError as e:
            wait = min(60, 2**attempt)
            print(f"  network error ({e.reason}); retry in {wait}s", flush=True)
            time.sleep(wait)
    raise RuntimeError(f"gave up on {method} {url} after retries")


def wait_operation(key: str, op_path: str) -> dict:
    op_id = op_path.split("/")[-1]
    start = time.time()
    delay = 1.0
    while time.time() - start < POLL_LIMIT_SECONDS:
        res = call("GET", f"{API}/operations/{op_id}", key)
        if res.get("done"):
            if "error" in res:
                raise RuntimeError("operation failed: " + json.dumps(res["error"]))
            return res.get("response") or {}
        time.sleep(delay)
        delay = min(8.0, delay * 1.5)
    raise RuntimeError(f"operation {op_id} not done after {POLL_LIMIT_SECONDS}s")


def send(key: str, path: pathlib.Path, ctype: str, asset_type: str, display: str, prev_id=None) -> dict:
    """Create an asset (prev_id None) or add a version to prev_id. Returns the finished operation summary."""
    data = path.read_bytes()
    if prev_id:
        request = {"assetId": int(prev_id)}
        url, method, mode = f"{API}/assets/{int(prev_id)}", "PATCH", "update"
    else:
        request = {
            "assetType": asset_type,
            "displayName": (DISPLAY_PREFIX + display)[:50],
            "description": f"Echo Heist art kit: {path.relative_to(ROOT)} (sha256 {sha256(path)[:16]})"[:1000],
            "creationContext": {"creator": CREATOR},
        }
        url, method, mode = f"{API}/assets", "POST", "create"
    body, form_type = multipart([
        ("request", None, "application/json", json.dumps(request).encode()),
        ("fileContent", path.name, ctype, data),
    ])
    op = call(method, url, key, body, form_type)
    if "path" not in op:
        raise RuntimeError(f"unexpected {mode} response: {json.dumps(op)[:800]}")
    resp = wait_operation(key, op["path"])
    asset_id = resp.get("assetId") or prev_id
    if not asset_id:
        raise RuntimeError(f"operation finished without an assetId: {json.dumps(resp)[:800]}")
    return {
        "assetId": int(asset_id),
        "mode": mode,
        "revisionId": resp.get("revisionId"),
        "moderation": (resp.get("moderationResult") or {}).get("moderationState"),
    }


# ------------------------------------------------------------------------------------------ status

def model_rows(groups: dict, ids: dict) -> list:
    rows = []
    for model, pieces in groups.items():
        path = FBX_DIR / f"{model}.fbx"
        rec = ids["models"].get(model)
        if not path.exists():
            state = "missing-file"
        elif rec is None:
            state = "pending"
        elif rec.get("sha256") != sha256(path):
            state = "changed"
        else:
            state = "uploaded"
        rows.append({"name": model, "state": state, "rec": rec, "pieces": pieces, "path": path})
    return rows


def image_rows(ids: dict) -> list:
    rows = []
    for path in sorted(TEX_DIR.glob("*.png")):
        rec = ids["images"].get(path.stem)
        if rec is None:
            state = "pending"
        elif rec.get("sha256") != sha256(path):
            state = "changed"
        else:
            state = "uploaded"
        rows.append({"name": path.stem, "state": state, "rec": rec, "pieces": [], "path": path})
    return rows


def print_status(rows: list, label: str) -> None:
    for r in rows:
        aid = r["rec"]["assetId"] if r["rec"] else "-"
        extra = f"{len(r['pieces'])} piece(s)" if r["pieces"] else ""
        if r["rec"] and r["rec"].get("image"):
            extra = f"image {r['rec']['image']}"
        print(f"{r['state']:12} {r['name']:30} {aid!s:16} {extra}")
    counts: dict = {}
    for r in rows:
        counts[r["state"]] = counts.get(r["state"], 0) + 1
    print(", ".join(f"{k} {v}" for k, v in sorted(counts.items())), f"(of {len(rows)} {label})")


# ------------------------------------------------------------------------------------------ codegen

def num(x) -> str:
    x = float(x)
    if x == int(x):
        return str(int(x))
    return repr(round(x, 6))


def vec(v) -> str:
    return "{ " + ", ".join(num(c) for c in v) + " }"


def luau_parts(manifest: dict, indent: str, full: bool) -> list:
    """Luau lines for the parts table. full=False keeps what the engine test needs."""
    lines = []
    for name, p in sorted(manifest["parts"].items()):
        fields = [f'model = "{p["model"]}"', f"size = {vec(p['size'])}"]
        if full:
            fields += [f"boundsMin = {vec(p['boundsMin'])}", f"boundsMax = {vec(p['boundsMax'])}",
                       f"origin = {vec(p['origin'])}"]
        else:
            lo, hi, o = p["boundsMin"], p["boundsMax"], p["origin"]
            center = [(lo[i] + hi[i]) / 2 for i in range(3)]
            fields.append(f"center = {vec(center)}")
            fields.append(f"scene = {vec([o[i] + center[i] for i in range(3)])}")
        fields.append(f'collision = "{p["collision"]}"')
        if full:
            fields += [f'material = "{p["material"]}"', f"canCollide = {str(p['canCollide']).lower()}",
                       f"castShadow = {str(p['castShadow']).lower()}", f"atlas = {str(p['atlas']).lower()}",
                       f'layer = "{p["layer"]}"']
            col = idle_colour(name, p)
            if col:
                fields.append(f'color = "{col}"')
            if p.get("transparency"):
                fields.append(f"transparency = {num(p['transparency'])}")
            if p.get("texture"):
                fields.append(f'texture = "{p["texture"]}"')
            if p.get("tintable"):
                fields.append("tintable = true")
        else:
            fields.append(f"canCollide = {str(p['canCollide']).lower()}")
        lines.append(f"{indent}{name} = {{")
        lines += [f"{indent}\t{f}," for f in fields]
        lines.append(f"{indent}}},")
    return lines


def kit_data_source(manifest: dict, ids: dict) -> str:
    out = [
        "--!strict",
        "-- GENERATED by tools/kit_upload.py from assets/fbx/kit_manifest.json and assets/kit_ids.json. Do not edit:",
        "-- re-run `python3 tools/kit_upload.py --gen` (or any upload) after an art rebuild.",
        "-- assets: kit model group -> Open Cloud Model asset id (InsertService:LoadAsset at boot).",
        "-- images: texture file stem -> Decal id and, once resolved, the image id KitService uses.",
        "-- atlases: location -> texture file stem (MeshPart.TextureContent atlas swap, STYLE_BIBLE §1.4).",
        "-- parts: per MeshPart, Roblox axes: size, bounds about the pivot (the kit point), origin = pivot in",
        "-- the model's scene space, and the look the prepare script gives it (colour: Neon idle, glass, ornament).",
        "",
        "return {",
        "\tassets = {",
    ]
    for model, rec in sorted(ids["models"].items()):
        out.append(f"\t\t{model} = {int(rec['assetId'])},")
    out.append("\t},")
    out.append("\timages = {")
    for stem, rec in sorted(ids["images"].items()):
        image = f", image = {int(rec['image'])}" if rec.get("image") else ""
        out.append(f"\t\t{stem} = {{ decal = {int(rec['assetId'])}{image} }},")
    out.append("\t},")
    app = ids.get("appearances")
    if app:
        out.append(f"\tappearances = {int(app['assetId'])},")
    out.append("\tatlases = {")
    for loc, file in sorted(manifest["atlases"].items()):
        out.append(f'\t\t{loc} = "{pathlib.Path(file).stem}",')
    out.append("\t},")
    out.append("\tparts = {")
    out += luau_parts(manifest, "\t\t", True)
    out.append("\t},")
    out.append("}")
    return "\n".join(out) + "\n"


def engine_table(manifest: dict, ids: dict) -> str:
    out = [TABLE_START + " (generated by tools/kit_upload.py; do not edit by hand)", "local ASSETS: { [string]: number } = {"]
    for model, rec in sorted(ids["models"].items()):
        out.append(f"\t{model} = {int(rec['assetId'])},")
    out.append("}")
    out.append("local IMAGES: { [string]: number } = {")
    for stem, rec in sorted(ids["images"].items()):
        out.append(f"\t{stem} = {int(rec['assetId'])},")
    out.append("}")
    app = ids.get("appearances")
    out.append(f"local APPEARANCES: number? = {int(app['assetId']) if app else 'nil'}")
    out.append("local PARTS: { [string]: any } = {")
    out += luau_parts(manifest, "\t", False)
    out.append("}")
    out.append(TABLE_END)
    return "\n".join(out)


def stylua(*paths: pathlib.Path) -> None:
    exe = shutil.which("stylua")
    if exe is None:
        print("  (stylua not installed: generated files left unformatted)")
        return
    subprocess.run([exe, *[str(p) for p in paths]], cwd=ROOT, check=False)


def generate(manifest: dict, ids: dict) -> None:
    KIT_DATA.parent.mkdir(parents=True, exist_ok=True)
    KIT_DATA.write_text(kit_data_source(manifest, ids), encoding="utf-8")
    touched = [KIT_DATA]
    if ENGINE_TEST.exists():
        text = ENGINE_TEST.read_text(encoding="utf-8")
        a, b = text.find(TABLE_START), text.find(TABLE_END)
        if a >= 0 and b > a:
            text = text[:a] + engine_table(manifest, ids) + text[b + len(TABLE_END):]
            ENGINE_TEST.write_text(text, encoding="utf-8")
            touched.append(ENGINE_TEST)
        else:
            print(f"  {ENGINE_TEST.relative_to(ROOT)} has no {TABLE_START} / {TABLE_END} markers: not updated")
    stylua(*touched)
    print("generated", ", ".join(str(p.relative_to(ROOT)) for p in touched))


# ------------------------------------------------------------------------------------------ main

APPEARANCE_LUNE = r"""
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local items = serde.decode("json", process.args[1])
local model = roblox.Instance.new("Model")
model.Name = "KitAppearances"
for _, it in items do
	local sa = roblox.Instance.new("SurfaceAppearance")
	sa.Name = it.name
	sa.ColorMapContent = roblox.Content.fromUri(it.color)
	if it.roughness then
		sa.RoughnessMapContent = roblox.Content.fromUri(it.roughness)
	end
	if it.emissive then
		sa.EmissiveMaskContent = roblox.Content.fromUri(it.emissive)
	end
	sa.EmissiveStrength = it.strength
	sa.EmissiveTint = roblox.Color3.fromRGB(it.tint[1], it.tint[2], it.tint[3])
	sa.Parent = model
end
fs.writeFile(process.args[2], roblox.serializeModel({ model }))
"""
HERO_EMISSIVE_STRENGTH = 2  # as the Studio prepare script (docs/art/KitPrepare.commandbar.lua)


def appearance_items(manifest: dict, ids: dict) -> list:
    """One SurfaceAppearance per manifest piece with a `texture` (maps <texture>_Color/_Roughness/_Emissive)."""
    ring = idle_colour("VaultDoor_DialRing", manifest["parts"]["VaultDoor_DialRing"]) or "#FFFFFF"
    items = []
    for name, p in sorted(manifest["parts"].items()):
        tex = p.get("texture")
        if not tex:
            continue
        maps = {}
        for key, suffix in (("color", "_Color"), ("roughness", "_Roughness"), ("emissive", "_Emissive")):
            rec = ids["images"].get(tex + suffix)
            if rec and rec.get("image"):
                maps[key] = f"rbxassetid://{int(rec['image'])}"
        if "color" not in maps:
            raise RuntimeError(f"{name}: no image id for {tex}_Color (run --images, then --set-image)")
        tint = [int(ring[i:i + 2], 16) for i in (1, 3, 5)]
        items.append({"name": name, **maps, "strength": HERO_EMISSIVE_STRENGTH, "tint": tint})
    return items


def upload_appearances(key: str, manifest: dict, ids: dict, force: bool, dry: bool) -> int:
    items = appearance_items(manifest, ids)
    digest = hashlib.sha256(json.dumps(items, sort_keys=True).encode()).hexdigest()
    prev = ids.get("appearances")
    if prev and prev.get("sha256") == digest and not force:
        print("appearances: unchanged")
        return 0
    print(f"appearances: {', '.join(i['name'] for i in items)}")
    if dry:
        return 0
    lune = shutil.which("lune")
    if lune is None:
        sys.exit("lune is needed to build the appearances rbxm")
    with tempfile.TemporaryDirectory() as tmp:
        script = pathlib.Path(tmp) / "appearances.luau"
        script.write_text(APPEARANCE_LUNE, encoding="utf-8")
        rbxm = pathlib.Path(tmp) / "KitAppearances.rbxm"
        subprocess.run([lune, "run", str(script), json.dumps(items), str(rbxm)], check=True)
        request = {
            "assetType": "Model",
            "displayName": DISPLAY_PREFIX + "Appearances",
            "description": f"Echo Heist art kit: hero SurfaceAppearances (inputs sha256 {digest[:16]})",
            "creationContext": {"creator": CREATOR},
        }
        body, form_type = multipart([
            ("request", None, "application/json", json.dumps(request).encode()),
            ("fileContent", rbxm.name, "model/x-rbxm", rbxm.read_bytes()),
        ])
        try:
            op = call("POST", f"{API}/assets", key, body, form_type)
            resp = wait_operation(key, op["path"])
        except ScopeError as e:
            print(str(e))
            return 3
    history = list((prev or {}).get("history", []))
    if prev:
        history.append(prev["assetId"])
    ids["appearances"] = {
        "assetId": int(resp["assetId"]),
        "sha256": digest,
        "pieces": [i["name"] for i in items],
        "moderation": (resp.get("moderationResult") or {}).get("moderationState"),
        "uploaded": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "history": history,
    }
    save_ids(ids)
    print(f"  ok appearances -> {ids['appearances']['assetId']}")
    return 0


def run_uploads(key: str, todo: list, kind: str, ids: dict, new: bool, dry: bool) -> tuple:
    """Upload todo rows of kind "models" or "images". Returns (exit code or None, failures)."""
    failures = []
    for i, r in enumerate(todo):
        rec, path = r["rec"], r["path"]
        update = kind == "models" and rec is not None and not new
        verb = "update" if update else "create"
        print(f"[{i + 1}/{len(todo)}] {verb} {r['name']} ({path.name}, {path.stat().st_size / 1024:.0f} KB)", flush=True)
        if dry:
            continue
        try:
            if kind == "models":
                res = send(key, path, "model/fbx", "Model", r["name"], rec["assetId"] if update else None)
            else:
                res = send(key, path, "image/png", "Decal", r["name"])
        except ScopeError as e:
            print(str(e))
            return 3, failures
        except RuntimeError as e:
            print(f"  FAILED {r['name']}: {e}", flush=True)
            failures.append(r["name"])
            continue
        history = list((rec or {}).get("history", []))
        if rec and rec.get("assetId") != res["assetId"]:
            history.append(rec["assetId"])  # the old id, kept for rollback
        entry = {
            "assetId": res["assetId"],
            "file": str(path.relative_to(ROOT)),
            "sha256": sha256(path),
            "revisionId": res["revisionId"],
            "moderation": res["moderation"],
            "uploaded": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "history": history,
        }
        if kind == "models":
            entry["pieces"] = r["pieces"]
        ids[kind][r["name"]] = entry
        save_ids(ids)  # write as we go
        print(f"  ok {r['name']} -> {res['assetId']} ({res['mode']}, moderation {res['moderation']})", flush=True)
        if i + 1 < len(todo):
            time.sleep(GAP_SECONDS)
    return None, failures


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--probe", action="store_true", help="upload one small pending group, then stop")
    ap.add_argument("--all", action="store_true", help="upload every new or changed group")
    ap.add_argument("--only", nargs="+", metavar="MODEL", help="upload just these model groups")
    ap.add_argument("--images", action="store_true", help="upload new or changed assets/textures/*.png as Decals")
    ap.add_argument("--appearances", action="store_true", help="build + upload the hero SurfaceAppearances rbxm")
    ap.add_argument("--new", action="store_true", help="a changed FBX makes a new asset instead of a new version")
    ap.add_argument("--force", action="store_true", help="re-upload even when the hash is unchanged")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--status", action="store_true")
    ap.add_argument("--gen", action="store_true", help="regenerate KitData.luau and the engine test table only")
    ap.add_argument("--set-image", nargs=2, metavar=("STEM", "IMAGE_ID"), help="record a Decal's image id")
    ap.add_argument("--group", metavar="GROUP_ID", help="upload as this group (the game's owner) instead of the user")
    a = ap.parse_args()
    if a.group:
        CREATOR.clear()
        CREATOR["groupId"] = str(int(a.group))

    manifest = load_manifest()
    groups = groups_from_manifest(manifest)
    ids = load_ids()
    if (a.all or a.probe or a.only or a.images or a.appearances) and ids["creator"] != CREATOR and not a.new:
        sys.exit(f"kit_ids.json was uploaded as {ids['creator']}, this run is {CREATOR}: re-upload everything with "
                 "--new --force (LoadAsset needs the experience owner's assets), then commit the new ids")
    if a.new and a.force:
        ids["creator"] = dict(CREATOR)
    models = model_rows(groups, ids)
    images = image_rows(ids)

    if a.set_image:
        stem, image = a.set_image
        if stem not in ids["images"]:
            sys.exit(f"no uploaded image {stem} in {IDS.relative_to(ROOT)}")
        ids["images"][stem]["image"] = int(image)
        save_ids(ids)
        generate(manifest, ids)
        return 0
    if a.gen:
        generate(manifest, ids)
        return 0
    if a.status or not (a.probe or a.all or a.only or a.images or a.appearances):
        print_status(models, "model groups")
        print_status(images, "images")
        app = ids.get("appearances")
        print("appearances:", f"{app['assetId']} ({', '.join(app['pieces'])})" if app else "not uploaded")
        return 0
    if a.appearances:
        code = upload_appearances(os.environ.get("ROBLOX_API_KEY", "proxy-injected"), manifest, ids, a.force, a.dry_run)
        if code == 0 and not a.dry_run:
            generate(manifest, ids)
        return code

    todo_models = []
    if a.all or a.probe:
        todo_models = [r for r in models if r["state"] in ("pending", "changed") or (a.force and r["state"] == "uploaded")]
    if a.only:
        unknown = set(a.only) - set(groups)
        if unknown:
            sys.exit(f"unknown model group(s): {', '.join(sorted(unknown))}")
        todo_models = [r for r in models if r["name"] in a.only and (r["state"] != "uploaded" or a.force)]
    if a.probe:
        todo_models = sorted(todo_models, key=lambda r: r["path"].stat().st_size)[:1]
    todo_images = []
    if a.images:
        todo_images = [r for r in images if r["state"] in ("pending", "changed") or (a.force and r["state"] == "uploaded")]
    if not todo_models and not todo_images:
        print("nothing to upload: every file matches its recorded hash")
        return 0

    key = os.environ.get("ROBLOX_API_KEY", "proxy-injected")
    code, failed = run_uploads(key, todo_models, "models", ids, a.new, a.dry_run)
    if code is None and todo_images:
        code, failed_images = run_uploads(key, todo_images, "images", ids, a.new, a.dry_run)
        failed += failed_images
    if not a.dry_run:
        generate(manifest, ids)
    done = sum(1 for r in model_rows(groups, ids) if r["state"] == "uploaded")
    print(f"{done}/{len(groups)} model groups, {len(ids['images'])} image(s) uploaded; ids in {IDS.relative_to(ROOT)}")
    if code is not None:
        return code
    if failed:
        print("failed:", ", ".join(failed), "(re-run to retry just these)")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
