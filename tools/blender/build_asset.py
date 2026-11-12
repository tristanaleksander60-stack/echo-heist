"""Build Echo Heist kit assets from Python specs: build -> gates -> FBX export -> FBX check -> turntable.

    python3 tools/blender/build_asset.py assets/blender/gold_bar.py        # one spec
    python3 tools/blender/build_asset.py --all                             # every spec in assets/blender/
    options: --no-render  --no-mood  --size 384  --blend (also save build/blender/<Asset>.blend)
             --force (re-export and re-render even when the asset's content hash is unchanged)

A spec is a Python file with `build(k)` returning one eh_kit.Asset or a list of them (k = the eh_kit module).
For every asset this writes:
    assets/fbx/<Asset>.fbx              Roblox FBX (FBX Unit Scale, 1 stud = 1 unit, atlas embedded)
    assets/fbx/<Asset>.gate.json        gate report (A1-A18, kit grid/tile, palette, FBX check)
    docs/art/turntables/<Asset>.png     contact sheet rendered from the re-imported FBX (round trip)
Exit code 1 if any gate fails; failing assets are still exported so they can be inspected.
Unchanged assets are not rewritten: each gate report stores a content hash (mesh, colour cells, UVs, pivots, notes,
the embedded atlas and hero maps, the export settings). When it matches, the FBX, the turntable and the report stay
byte-identical, so an art pass only changes the files of the assets it touched (git history stays small).
"""
import argparse, glob, hashlib, importlib.util, json, os, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy  # noqa: E402
import eh_kit as k  # noqa: E402
import eh_palette as P  # noqa: E402
import turntable as tt  # noqa: E402

REPO = k.REPO
FBX_DIR = os.path.join(REPO, "assets", "fbx")
TT_DIR = os.path.join(REPO, "docs", "art", "turntables")
BLEND_DIR = os.path.join(REPO, "build", "blender")


def load_spec(path):
    d = os.path.dirname(os.path.abspath(path))
    if d not in sys.path:
        sys.path.insert(0, d)            # specs share assets/blender/_kitlib.py
    spec = importlib.util.spec_from_file_location("eh_spec_" + os.path.splitext(os.path.basename(path))[0], path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


EXPORT_VERSION = "fbx-1"   # bump when export_fbx / verify_fbx / the turntable layout change (forces a rebuild)


def content_hash(asset, render, mood, size):
    """What the FBX and the turntable are made of: geometry, colour cells, UVs, object names and pivots, the notes
    printed on the sheet, every image the export embeds, and the export / render settings."""
    h = hashlib.sha256(EXPORT_VERSION.encode())
    h.update(json.dumps([asset.name, asset.notes, render, mood, size]).encode())
    images = set()
    for o in asset.objects:
        ob = o.ob
        me = ob.data
        h.update(json.dumps([ob.name, [round(c, 5) for c in ob.location], o.notes]).encode())
        h.update(b"".join(b"%.5f,%.5f,%.5f;" % tuple(v.co) for v in me.vertices))
        # polygons in a canonical form (bmesh may start a face at another vertex from run to run): each face rotated
        # to its lowest vertex index, with its colour cell and loop UVs, then sorted
        at = me.attributes.get("eh_col")
        uv = me.uv_layers[0].data if me.uv_layers else None
        faces = []
        for p in me.polygons:
            vs, ls = list(p.vertices), list(p.loop_indices)
            i = vs.index(min(vs))
            vs, ls = vs[i:] + vs[:i], ls[i:] + ls[:i]
            faces.append((tuple(vs), at.data[p.index].value if at else 0,
                          tuple((round(uv[j].uv[0], 4), round(uv[j].uv[1], 4)) for j in ls) if uv else ()))
        h.update(str(sorted(faces)).encode())
        for slot in ob.material_slots:
            if slot.material and slot.material.node_tree:
                for n in slot.material.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image and n.image.filepath:
                        images.add(bpy.path.abspath(n.image.filepath))
    for path in sorted(images):
        with open(path, "rb") as f:
            h.update(f.read())
    return h.hexdigest()[:20]


def _previous(name):
    try:
        with open(os.path.join(FBX_DIR, name + ".gate.json")) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def build_spec(path, render=True, mood=True, size=384, blend=False, man=None, force=False):
    P.write_atlases()
    k.reset_scene()
    mod = load_spec(path)
    assets = mod.build(k)
    assets = assets if isinstance(assets, list) else [assets]
    results, kept = [], []
    for a in assets:
        t0 = time.time()
        passed, rep = k.gate_asset(a)
        objs = [o.ob for o in a.objects]
        fbx = os.path.join(FBX_DIR, a.name + ".fbx")
        png = os.path.join(TT_DIR, a.name + ".png")
        rep["contentHash"] = content_hash(a, render, mood, size)
        prev = _previous(a.name)
        if (not force and prev and prev.get("contentHash") == rep["contentHash"] and prev.get("passed") == passed
                and os.path.isfile(fbx) and (not render or os.path.isfile(png))):
            # unchanged: keep the FBX, the turntable and the report byte for byte (only the manifest is refreshed)
            print(f"\n== {a.name}: {'PASS' if passed else 'FAIL'}, unchanged (content hash {rep['contentHash']}): "
                  "FBX, turntable and report kept")
            update_manifest(a, rep, man)
            kept.append(passed)
            continue
        k.export_fbx(objs, fbx)
        ok, fails, info = k.verify_fbx(fbx, objs)
        rep["fbx"] = {"path": os.path.relpath(fbx, REPO), "bytes": os.path.getsize(fbx), "ok": ok, "fails": fails, **info}
        if not ok:
            rep["asset_fails"] += fails
            passed = False
        rep["passed"] = passed
        rep["spec"] = os.path.relpath(path, REPO)
        rep["notes"] = a.notes
        if blend:
            os.makedirs(BLEND_DIR, exist_ok=True)
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, a.name + ".blend"), copy=True)
        results.append((a, passed, rep, fbx, t0))
    for a, passed, rep, fbx, t0 in results:
        if render:
            png = os.path.join(TT_DIR, a.name + ".png")
            objs = tt.load_file(fbx)
            fails = [f for o in rep["objects"] for f in o["fails"]] + rep["asset_fails"]
            info = [("GATES PASS" if passed else "GATES FAIL: " + "; ".join(fails)[:180]) +
                    f"   |  FBX {rep['fbx']['bytes'] // 1024} KB, UnitScaleFactor {rep['fbx'].get('UnitScaleFactor')}"]
            if a.notes:
                info.append(a.notes[:170])
            tt.render_contact_sheet(png, objs, 8, size, f"{a.name}  (rendered from {os.path.relpath(fbx, REPO)})",
                                    info, mood=mood)
            rep["turntable"] = os.path.relpath(png, REPO)
        rep["seconds"] = round(time.time() - t0, 1)
        with open(os.path.join(FBX_DIR, a.name + ".gate.json"), "w") as f:
            json.dump(rep, f, indent=1, default=str)
        update_manifest(a, rep, man)
        print_summary(rep)
    return all(p for _a, p, *_r in results) and all(kept)


MANIFEST = os.path.join(FBX_DIR, "kit_manifest.json")


def _roblox(v):
    """Sizes: Blender (X, Y, Z) -> Roblox (X, Y, Z) = (x, z, y) (the FBX is Y-up)."""
    return [round(v[0], 3), round(v[2], 3), round(v[1], 3)]


def _roblox_point(v):
    """Points: the export (axis_forward Z, axis_up Y) is the proper rotation Blender (x, y, z) -> FBX / Roblox
    (-x, z, y): Blender's front -Y becomes Roblox -Z (the LookVector side) and Blender -X becomes Roblox +X, which is
    still the viewer's left when facing the front (no mirror; only the X label flips). [UNVERIFIED until spike S2:
    KIT_IMPORT step 3 prints the check.]"""
    return [round(-v[0], 3) + 0.0, round(v[2], 3), round(v[1], 3)]


def _load_manifest(reset=False):
    man = None
    if not reset:
        try:
            with open(MANIFEST) as f:
                man = json.load(f)
        except (OSError, ValueError):
            man = None
    man = man or {"parts": {}}
    man["note"] = ("Generated by tools/blender/build_asset.py; read by tests/kit_check.luau and the level layout "
                   "pipeline. size = Roblox X, Y, Z (Y up, front -Z). Sizes are what Studio shows after Import 3D.")
    man["atlases"] = {loc: os.path.relpath(P.atlas_path(loc), REPO) for loc in P.LOCATIONS}
    man["atlasDefault"] = "Bank"
    man["locationCells"] = list(P.LOCATION_CELLS)
    man["ornamentDays"] = P.ornament_days()
    man["neon"] = {part: {"idle": idle, "runtime": what} for part, (idle, what, _fixed) in P.NEON.items()}
    return man


def update_manifest(asset, rep, man=None):
    """assets/fbx/kit_manifest.json: what Studio should show for every MeshPart after Import 3D (spike S2), plus
    the kit metadata the level layout needs (layer, tags, sim, joint). Size is in Roblox axes."""
    own = man is None
    man = man or _load_manifest()
    for o, spec in zip(rep["objects"], asset.objects):
        e = {"model": asset.name, "size": _roblox(o["dims"]), "tris": o["tris"], "class": o["class"],
             "collision": spec.collision, "material": spec.material, "canCollide": spec.can_collide,
             "castShadow": spec.cast_shadow, "atlas": spec.atlas, "pivot": spec.pivot, "role": spec.role,
             "layer": spec.layer, "passed": o["passed"]}
        lo, hi = o["pivot"]["local_min"], o["pivot"]["local_max"]
        # bounds relative to the pivot and the pivot's position in the Model, both in Roblox axes (_roblox_point)
        a, b = _roblox_point(lo), _roblox_point(hi)
        e["boundsMin"] = [min(a[i], b[i]) for i in range(3)]
        e["boundsMax"] = [max(a[i], b[i]) for i in range(3)]
        e["origin"] = _roblox_point(o["location"])
        if spec.tags:
            e["tags"] = spec.tags
        if spec.sim:
            e["sim"] = spec.sim
        if spec.joint:
            e["joint"] = spec.joint
        if spec.transparency:
            e["transparency"] = spec.transparency
        if spec.texture:
            e["texture"] = spec.texture
        if spec.tint:
            e["tint"] = spec.tint
        e.update(spec.extra)
        man["parts"][o["name"]] = e
    man["parts"] = dict(sorted(man["parts"].items()))
    if own:
        save_manifest(man)
    return man


def save_manifest(man):
    with open(MANIFEST, "w") as f:
        json.dump(man, f, indent=1)


def print_summary(rep):
    print(f"\n== {rep['asset']}: {'PASS' if rep['passed'] else 'FAIL'}  ({rep['tris_total']} tris, {rep.get('seconds')} s)")
    for o in rep["objects"]:
        print(f"   {o['name']:<24} {o['class']:<8} {o['tris']:>6} tris (target {o['budget'][0]}, ceiling {o['budget'][1]})"
              f"  dims {o['dims']}  {'ok' if o['passed'] else 'FAIL'}")
        for f in o["fails"]:
            print("      -", f)
    for f in rep["asset_fails"]:
        print("   -", f)
    if rep.get("turntable"):
        print("   turntable:", rep["turntable"])


def main(argv):
    ap = argparse.ArgumentParser(description="Build Echo Heist kit assets from spec scripts")
    ap.add_argument("specs", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--no-render", action="store_true")
    ap.add_argument("--no-mood", action="store_true")
    ap.add_argument("--size", type=int, default=384)
    ap.add_argument("--blend", action="store_true")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args(argv)
    specs = sorted(glob.glob(os.path.join(REPO, "assets", "blender", "*.py"))) if a.all else a.specs
    specs = [s for s in specs if not os.path.basename(s).startswith("_")]
    if not specs:
        ap.error("give a spec path or --all")
    ok = True
    if a.all or len(specs) > 1:
        # One Blender process per spec: dozens of factory resets and renders in one headless process can crash
        # (measured: a silent exit after ~30 assets). --all also rebuilds the manifest from scratch, so renamed or
        # removed pieces drop out.
        import subprocess
        if a.all:
            save_manifest(_load_manifest(reset=True))
        flags = (["--no-render"] if a.no_render else []) + (["--no-mood"] if a.no_mood else []) + \
                ["--size", str(a.size)] + (["--blend"] if a.blend else []) + (["--force"] if a.force else [])
        failed = []
        for s in specs:
            r = subprocess.run([sys.executable, os.path.abspath(__file__), os.path.abspath(s)] + flags)
            if r.returncode != 0:
                failed.append(os.path.basename(s))
        print("\nALL GATES PASS" if not failed else f"\nSOME GATES FAILED (or crashed): {failed}")
        return 0 if not failed else 1
    man = _load_manifest()
    for s in specs:
        ok &= build_spec(os.path.abspath(s), not a.no_render, not a.no_mood, a.size, a.blend, man, a.force)
        save_manifest(man)
    print("\nALL GATES PASS" if ok else "\nSOME GATES FAILED")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
