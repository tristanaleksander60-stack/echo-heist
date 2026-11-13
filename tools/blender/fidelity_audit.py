"""Studio-fidelity audit of the exported kit FBX files (docs/audit/STUDIO_FIDELITY.md).

    python3 tools/blender/fidelity_audit.py                    # every assets/fbx/*.fbx, summary + worst offenders
    python3 tools/blender/fidelity_audit.py --json out.json    # also write the per-mesh table
    python3 tools/blender/fidelity_audit.py --gate             # exit 1 when a curved mesh ships all-flat normals

Reads what Roblox receives (the FBX, not the Blender scene): per Geometry the triangle count, the normal layer's
mapping, whether vertex colours or a smoothing layer were written, and two normal measures:
  flatCorners        fraction of corner normals equal to their face normal (1.0 = every face flat-shaded)
  curvedFlatCorners  the same, but only over faces that belong to a curved (revolved) surface: faces whose
                     neighbours across an edge differ by 5-40 degrees on at least two edges. A cylinder, sphere or
                     limb shaded flat scores ~1.0 here; a box with chamfers is not curved and does not count.
A curved mesh with curvedFlatCorners >= 0.9 renders as visible facets in the engine (Future lighting's specular
picks out every flat face); the Blender turntables at 384 px hid it.
"""
import argparse, glob, json, math, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
import bpy  # noqa: E402,F401  (puts the bundled io_scene_fbx add-on on sys.path)
from io_scene_fbx import parse_fbx  # noqa: E402


def _kids(e, n):
    return [c for c in e.elems if c.id == n]


def _one(e, n):
    k = _kids(e, n)
    return k[0] if k else None


def _norm(v):
    l = math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]) or 1.0
    return (v[0] / l, v[1] / l, v[2] / l)


def _face_normal(pts):
    # Newell's method (n-gons and quads)
    nx = ny = nz = 0.0
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        nx += (a[1] - b[1]) * (a[2] + b[2])
        ny += (a[2] - b[2]) * (a[0] + b[0])
        nz += (a[0] - b[0]) * (a[1] + b[1])
    return _norm((nx, ny, nz))


def audit_geometry(g):
    V = _one(g, b"Vertices").props[0]
    PVI = _one(g, b"PolygonVertexIndex").props[0]
    ln = _one(g, b"LayerElementNormal")
    mapping = _one(ln, b"MappingInformationType").props[0].decode() if ln else None
    N = _one(ln, b"Normals").props[0] if ln else []
    ref = _one(ln, b"ReferenceInformationType").props[0].decode() if ln else None
    NI = _one(ln, b"NormalsIndex").props[0] if (ln and ref == "IndexToDirect") else None
    polys, cur = [], []
    for x in PVI:
        if x < 0:
            cur.append(~x)
            polys.append(cur)
            cur = []
        else:
            cur.append(x)
    P = [(V[3 * i], V[3 * i + 1], V[3 * i + 2]) for i in range(len(V) // 3)]
    fns = [_face_normal([P[i] for i in p]) for p in polys]
    # edge -> faces, by welded position (the export splits verts per UV island)
    key = [tuple(round(c, 4) for c in p) for p in P]
    edges = {}
    for fi, p in enumerate(polys):
        for j in range(len(p)):
            a, b = key[p[j]], key[p[(j + 1) % len(p)]]
            edges.setdefault((min(a, b), max(a, b)), []).append(fi)
    soft = [0] * len(polys)
    for fs in edges.values():
        if len(fs) == 2:
            a, b = fns[fs[0]], fns[fs[1]]
            ang = math.degrees(math.acos(max(-1.0, min(1.0, a[0] * b[0] + a[1] * b[1] + a[2] * b[2]))))
            if 5.0 <= ang <= 40.0:   # a 1-segment 45-degree chamfer and a 90-degree corner are not curvature
                soft[fs[0]] += 1
                soft[fs[1]] += 1
    flat = tot = cflat = ctot = 0
    ci = 0
    for fi, p in enumerate(polys):
        fn = fns[fi]
        curved = soft[fi] >= 2
        for vi in p:
            if mapping in ("ByPolygonVertex", "ByVertice", "ByVertex"):
                j = ci if mapping == "ByPolygonVertex" else vi
                j = NI[j] if NI is not None else j
                n = _norm((N[3 * j], N[3 * j + 1], N[3 * j + 2]))
            else:
                n = fn
            ci += 1
            isflat = fn[0] * n[0] + fn[1] * n[1] + fn[2] * n[2] > 0.9995
            tot += 1
            flat += isflat
            if curved:
                ctot += 1
                cflat += isflat
    return {
        "tris": sum(len(p) - 2 for p in polys),
        "mapping": mapping,
        "vertexColors": _one(g, b"LayerElementColor") is not None,
        "smoothingLayer": _one(g, b"LayerElementSmoothing") is not None,
        "flatCorners": round(flat / max(1, tot), 3),
        "curvedShare": round(ctot / max(1, tot), 3),
        "curvedFlatCorners": round(cflat / ctot, 3) if ctot else None,
    }


def audit_file(path):
    root, _v = parse_fbx.parse(path)
    out = {}
    objs = _one(root, b"Objects")
    for g in _kids(objs, b"Geometry"):
        if not _one(g, b"Vertices"):
            continue
        name = g.props[1].split(b"\x00")[0].decode()
        r = audit_geometry(g)
        r["file"] = os.path.basename(path)
        out[name] = r
    return out


def faceted(r, share=0.15, limit=0.9):
    """A mesh that is meaningfully curved and ships flat normals on its curved faces."""
    return r["curvedFlatCorners"] is not None and r["curvedShare"] >= share and r["curvedFlatCorners"] >= limit


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("pattern", nargs="?", default=os.path.join(REPO, "assets", "fbx", "*.fbx"))
    ap.add_argument("--json")
    ap.add_argument("--gate", action="store_true")
    a = ap.parse_args(argv)
    res = {}
    for p in sorted(glob.glob(a.pattern)):
        res.update(audit_file(p))
    bad = sorted(n for n, r in res.items() if faceted(r))
    curved = [n for n, r in res.items() if r["curvedFlatCorners"] is not None and r["curvedShare"] >= 0.15]
    print(f"{len(res)} meshes; {len(curved)} curved (>= 15% curved faces); {len(bad)} of them ship flat normals on "
          f"their curved faces; vertex colour layers: {sum(r['vertexColors'] for r in res.values())}; "
          f"smoothing layers: {sum(r['smoothingLayer'] for r in res.values())}")
    for n in bad[:40]:
        r = res[n]
        print(f"   {n:<32} curved {r['curvedShare']:.2f}  flat on curved {r['curvedFlatCorners']:.2f}  tris {r['tris']}")
    if a.json:
        with open(a.json, "w") as f:
            json.dump({"summary": {"meshes": len(res), "curved": len(curved), "facetedCurved": len(bad)},
                       "meshes": res}, f, indent=1, sort_keys=True)
    return 1 if (a.gate and bad) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
