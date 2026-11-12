"""Echo Heist kit builder: bmesh primitives with palette-atlas UVs, gates and Roblox FBX export.

Used by asset spec scripts in assets/blender/*.py through tools/blender/build_asset.py. Runs on the pip `bpy`
module (Blender 5.3, Python 3.13) or inside Blender. 1 Blender unit = 1 stud. Front of every asset faces -Y.

Look: chamfers are real geometry (1 segment, sizes from STYLE_BIBLE), faces are smooth-shaded with sharp edges
above 30 degrees, so the flat-faced look never depends on custom normals surviving the Roblox import. Every face
gets a UV square inside one palette cell (eh_palette), one material per object (the shared atlas).
"""
import bpy, bmesh, math, os, re, sys, importlib
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import eh_palette as P  # noqa: E402


def _load_lf():
    """The LihFolk gate helpers: the live plugin copy when present, else the vendored one."""
    cands = [os.environ.get("LIHFOLK_BLENDER_SCRIPTS", ""),
             "/home/user/lihfolk-cy/v2-vault/skills/roblox-blender-modeling/scripts",
             os.path.join(HERE, "vendor")]
    for c in cands:
        if c and os.path.isfile(os.path.join(c, "lihfolk_bpy.py")):
            if c not in sys.path:
                sys.path.insert(0, c)
            mod = importlib.import_module("lihfolk_bpy")
            mod.EH_SOURCE = c
            return mod
    raise ImportError("lihfolk_bpy.py not found (set LIHFOLK_BLENDER_SCRIPTS)")


lf = _load_lf()
ATLAS_PATH = os.path.join(REPO, "assets", "textures", "EH_Palette_Bank.png")
MATERIAL_NAME = "EH_KitAtlas"

# Bevel (chamfer) sizes in studs, MASTERPLAN 6.1 (one segment only).
BEVEL = {"small": 0.07, "medium": 0.15, "building": 0.25}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    lf.setup_scene()
    s = bpy.context.scene
    s.view_settings.view_transform = "Standard"
    if s.world is None:
        s.world = bpy.data.worlds.new("EH_World")
    return s


def _basis(axis):
    """Orthonormal (a, u, w) with a = axis direction."""
    a = Vector(axis).normalized()
    ref = Vector((1, 0, 0)) if abs(a.x) < 0.9 else Vector((0, 1, 0))
    u = (ref - a * ref.dot(a)).normalized()
    return a, u, a.cross(u)


class MB:
    """Mesh builder: one bmesh, a face int layer holding the palette swatch index, named part ranges."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.faces.layers.int.new("eh_col")
        self.parts = {}

    # ---- low level
    def v(self, co):
        return self.bm.verts.new(Vector(co))

    def f(self, verts, col):
        fc = self.bm.faces.new(verts)
        fc[self.col] = P.INDEX[col]
        return fc

    def _part(self, part, verts):
        if part:
            self.parts.setdefault(part, []).extend(verts)

    def part_bbox(self, part):
        pts = [v.co for v in self.parts[part] if v.is_valid]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        return lo, hi

    def xform(self, verts, mat):
        """Applies a 4x4 Matrix to verts (rotate / place a primitive after building it at the origin)."""
        bmesh.ops.transform(self.bm, matrix=mat, verts=[v for v in verts if v.is_valid])
        return verts

    def rotate(self, verts, deg, axis="Z", centre=(0, 0, 0)):
        c = Vector(centre)
        m = Matrix.Translation(c) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-c)
        return self.xform(verts, m)

    def move(self, verts, d):
        return self.xform(verts, Matrix.Translation(Vector(d)))

    def recolour(self, verts, col):
        """Sets the swatch of every face whose verts are all in `verts`."""
        vs = set(v for v in verts if v.is_valid)
        for fc in {f for v in vs for f in v.link_faces}:
            if all(x in vs for x in fc.verts):
                fc[self.col] = P.INDEX[col]

    def _colour_chamfers(self, faces, base, cham):
        for fc in faces:
            fc.normal_update()
            fc[self.col] = P.INDEX[base if (cham is None or fc.normal.z < -0.3) else cham]

    # ---- primitives
    def box(self, lo, hi, col, chamfer=0.0, cham_col=None, flat=(), taper=None, part=None, face_cols=None):
        """Axis-aligned box from lo to hi. chamfer: 1-segment bevel on every edge except the edges of the faces
        named in `flat` ('-x', '+x', '-y', '+y', '-z', '+z': contact faces stay flat so modules tile).
        taper=(sx, sy) scales the top face about its centre (gold bars). face_cols={'+z': key} overrides."""
        x0, y0, z0 = lo; x1, y1, z1 = hi
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        sx, sy = taper or (1, 1)
        def top(x, y):
            return (cx + (x - cx) * sx, cy + (y - cy) * sy, z1)
        vs = [self.v((x0, y0, z0)), self.v((x1, y0, z0)), self.v((x1, y1, z0)), self.v((x0, y1, z0)),
              self.v(top(x0, y0)), self.v(top(x1, y0)), self.v(top(x1, y1)), self.v(top(x0, y1))]
        fc = face_cols or {}
        idx = {"-z": (0, 3, 2, 1), "+z": (4, 5, 6, 7), "-y": (0, 1, 5, 4), "+x": (1, 2, 6, 5),
               "+y": (2, 3, 7, 6), "-x": (3, 0, 4, 7)}
        faces = {k: self.f([vs[i] for i in t], fc.get(k, col)) for k, t in idx.items()}
        # a chamfer wider than ~half the thinnest side collapses faces (A5 degenerate): clamp it
        chamfer = min(chamfer, 0.45 * min(x1 - x0, y1 - y0, z1 - z0)) if chamfer > 0 else 0.0
        if chamfer > 0:
            keep = set()
            for k in flat:
                keep |= set(faces[k].edges)
            edges = [e for e in {e for fcc in faces.values() for e in fcc.edges} if e not in keep]
            res = bmesh.ops.bevel(self.bm, geom=edges, offset=chamfer, offset_type="OFFSET", segments=1,
                                  profile=0.5, affect="EDGES", clamp_overlap=True)
            self._colour_chamfers(res["faces"], col, cham_col)
            vs = list({v for f in res["faces"] for v in f.verts} | {v for v in vs if v.is_valid})
        self._part(part, vs)
        return vs

    def prism(self, poly, axis, a0, a1, cols, cap_col, origin=(0, 0, 0), chamfer=0.0, cham_col=None,
              cham_edges=None, part=None):
        """Extrudes a simple 2D polygon (points (p, q)) along `axis` from a0 to a1.
        axis 'X': (p, q) = (y, z); 'Y': (p, q) = (x, z); 'Z': (p, q) = (x, y). cols[i] colours the side wall of
        edge i (poly[i] -> poly[i+1]); cap_col colours both caps. chamfer > 0 bevels the cap edges listed in
        cham_edges (edge indices, both caps) for 1-segment chamfers on visible outer edges."""
        o = Vector(origin)
        def co(pq, a):
            p, q = pq
            return o + {"X": Vector((a, p, q)), "Y": Vector((p, a, q)), "Z": Vector((p, q, a))}[axis]
        n = len(poly)
        A = [self.v(co(pq, a0)) for pq in poly]
        B = [self.v(co(pq, a1)) for pq in poly]
        capA = self.f(A, cap_col)
        capB = self.f(list(reversed(B)), cap_col)
        for i in range(n):
            j = (i + 1) % n
            self.f([A[i], A[j], B[j], B[i]], cols[i] if isinstance(cols, (list, tuple)) else cols)
        vs = A + B
        if chamfer > 0 and cham_edges:
            edges = []
            for i in cham_edges:
                j = (i + 1) % n
                for ring in (A, B):
                    e = self.bm.edges.get((ring[i], ring[j]))
                    if e:
                        edges.append(e)
            res = bmesh.ops.bevel(self.bm, geom=edges, offset=chamfer, offset_type="OFFSET", segments=1,
                                  profile=0.5, affect="EDGES", clamp_overlap=True)
            base = cols if isinstance(cols, str) else cap_col
            self._colour_chamfers(res["faces"], base, cham_col)
            vs = list({v for f in res["faces"] for v in f.verts} | {v for v in vs if v.is_valid})
        self._part(part, vs)
        return vs

    def lathe(self, profile, segs, cols, centre, axis=(0, 0, 1), closed=False, phase=0.0, part=None):
        """Revolves profile [(r, h), ...] around `axis` through `centre` (h along the axis). Points with r == 0
        become single pole vertices (fan triangles, no n-gon caps). cols[i] colours the band of profile edge i.
        closed=True joins the last point back to the first (rings, torus-like bezels)."""
        a, u, w = _basis(axis)
        c = Vector(centre)
        rings = []
        for r, h in profile:
            if r < 1e-9:
                rings.append([self.v(c + a * h)])
            else:
                rings.append([self.v(c + a * h + r * (math.cos(t) * u + math.sin(t) * w))
                              for t in (phase + 2 * math.pi * j / segs for j in range(segs))])
        m = len(profile) if closed else len(profile) - 1
        for i in range(m):
            R0, R1 = rings[i], rings[(i + 1) % len(profile)]
            col = cols[i] if isinstance(cols, (list, tuple)) else cols
            for j in range(segs):
                k = (j + 1) % segs
                if len(R0) == 1 and len(R1) == 1:
                    continue
                if len(R0) == 1:
                    self.f([R0[0], R1[j], R1[k]], col)
                elif len(R1) == 1:
                    self.f([R0[j], R0[k], R1[0]], col)
                else:
                    self.f([R0[j], R0[k], R1[k], R1[j]], col)
        vs = [v for R in rings for v in R]
        self._part(part, vs)
        return vs

    def cylinder(self, centre, axis, r, h0, h1, segs, col, cap_col=None, chamfer=0.0, cham_col=None, part=None,
                 phase=0.0):
        cap_col = cap_col or col
        if chamfer > 0:
            c = min(chamfer, r * 0.45, (h1 - h0) * 0.45)
            prof = [(0, h0), (r - c, h0), (r, h0 + c), (r, h1 - c), (r - c, h1), (0, h1)]
            cols = [cap_col, cham_col or col, col, cham_col or col, cap_col]
        else:
            prof = [(0, h0), (r, h0), (r, h1), (0, h1)]
            cols = [cap_col, col, cap_col]
        return self.lathe(prof, segs, cols, centre, axis, phase=phase, part=part)

    def sphere(self, centre, r, segs=8, rings=5, col="steel", axis=(0, 0, 1), part=None):
        prof = [(r * math.sin(math.pi * i / rings), -r * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
        prof[0] = (0, prof[0][1]); prof[-1] = (0, prof[-1][1])
        return self.lathe(prof, segs, col, centre, axis, part=part)

    def clip(self, plane_co, plane_no, cap_col, part_verts=None):
        """Cuts the geometry (or only part_verts' faces) by a plane, deletes the side the normal points away
        from, and caps the cut with one planar face per loop (triangulated later). Used to sit round shapes on
        the floor."""
        # sorted by element index: sets of BMesh elements iterate in memory-address order, which changes from run
        # to run, and bisect_plane numbers the new verts in input order (the content hash must not churn)
        for seq in (self.bm.verts, self.bm.edges, self.bm.faces):
            seq.index_update()
        by_index = lambda xs: sorted(xs, key=lambda x: x.index)  # noqa: E731
        geom_faces = list(self.bm.faces) if part_verts is None else by_index({f for v in part_verts if v.is_valid for f in v.link_faces})
        geom = by_index({e for f in geom_faces for e in f.edges}) + geom_faces + by_index({v for f in geom_faces for v in f.verts})
        res = bmesh.ops.bisect_plane(self.bm, geom=geom, dist=1e-6, plane_co=Vector(plane_co),
                                     plane_no=Vector(plane_no), clear_inner=True)
        cut_edges = [e for e in res["geom_cut"] if isinstance(e, bmesh.types.BMEdge) and e.is_valid and e.is_boundary]
        if cut_edges:
            fill = bmesh.ops.edgenet_fill(self.bm, edges=cut_edges)
            for fc in fill["faces"]:
                fc[self.col] = P.INDEX[cap_col]
            if len(fill["faces"]) == 0:
                bmesh.ops.holes_fill(self.bm, edges=cut_edges, sides=0)
        return res


# ---------------------------------------------------------------- material and object

def atlas_material():
    m = bpy.data.materials.get(MATERIAL_NAME)
    if m:
        return m
    m = bpy.data.materials.new(MATERIAL_NAME)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    if not os.path.isfile(ATLAS_PATH):
        P.write_atlas(ATLAS_PATH)
    tex.image = bpy.data.images.load(ATLAS_PATH, check_existing=True)
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.7
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = 0.0
    return m


def hero_material(name, image_path):
    """One material with its own colour map (hero SurfaceAppearance sets, STYLE_BIBLE 4: <= 3 per level)."""
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(image_path, check_existing=True)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.5
    return m


def finalize(mb, shading="angle", angle=30.0, pivot=(0, 0, 0), planar=None, material=None):
    """Triangulates n-gons, recalculates normals, sets shading, writes atlas UVs and returns the object.
    The mesh is authored in assembly coordinates; the object origin is moved to `pivot` (same coordinates),
    so the object stays where it was authored and its Roblox pivot is the pivot point.
    planar=(axis_u, axis_v, lo_u, hi_u, lo_v, hi_v): instead of atlas cells, project UVs onto a plane (hero
    texture sets, e.g. the vault dial face); material=(name, image path) replaces the kit atlas material."""
    bm = mb.bm
    ngons = [f for f in bm.faces if len(f.verts) > 4]
    if ngons:
        bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    for fc in bm.faces:
        fc.smooth = shading != "flat"
    lim = math.radians(angle)
    for e in bm.edges:
        e.smooth = shading != "flat" and len(e.link_faces) == 2 and e.calc_face_angle(math.pi) < lim
    uvl = bm.loops.layers.uv.new("UVMap")
    keys = [k for k, *_r in P.SWATCHES]
    if planar:
        au, av, u0, u1, v0, v1 = planar
        iu, iv = "XYZ".index(au.lstrip("-")), "XYZ".index(av.lstrip("-"))
        su, sv = (-1 if au.startswith("-") else 1), (-1 if av.startswith("-") else 1)
        for fc in bm.faces:
            for lp in fc.loops:
                x, y = su * lp.vert.co[iu], sv * lp.vert.co[iv]
                lp[uvl].uv = (min(1, max(0, (x - u0) / (u1 - u0))), min(1, max(0, (y - v0) / (v1 - v0))))
    else:
        for fc in bm.faces:
            u, v, hs = P.cell_uv(keys[fc[mb.col]])
            n = len(fc.loops)
            for i, lp in enumerate(fc.loops):
                t = 2 * math.pi * i / n + math.pi / 4
                lp[uvl].uv = (u + hs * math.cos(t), v + hs * math.sin(t))
    pv = Vector(pivot)
    bmesh.ops.translate(bm, verts=list(bm.verts), vec=-pv)
    me = bpy.data.meshes.new(mb.name)
    bm.to_mesh(me)
    me.update()
    ob = bpy.data.objects.new(mb.name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = pv
    me.materials.append(hero_material(*material) if material else atlas_material())
    ob["eh_parts"] = {k: [*mb.part_bbox(k)[0], *mb.part_bbox(k)[1]] for k in mb.parts}   # local lo + hi
    return ob


def used_swatches(ob):
    at = ob.data.attributes.get("eh_col")
    keys = [k for k, *_r in P.SWATCHES]
    return sorted({keys[d.value] for d in at.data}) if at else []


# ---------------------------------------------------------------- specs

def roblox_point(v, origin=(0, 0, 0)):
    """A Blender point (relative to `origin`) in Roblox axes: (x, y, z) -> (-x, z, y) (see build_asset._roblox_point)."""
    x, y, z = (v[i] - origin[i] for i in range(3))
    return [round(-x, 3) + 0.0, round(z, 3), round(y, 3)]


class Obj:
    """One exported object (one MeshPart in Studio)."""

    def __init__(self, ob, cls, role="env", symmetric=None, pivot="corner", collision="Box", material="SmoothPlastic",
                 can_collide=True, cast_shadow=True, expect_dims=None, tint=None, notes="", layer="base", tags=(),
                 joint=None, atlas=None, transparency=0.0, texture=None, sim=None, free_shells=False, extra=None,
                 on_floor=False):
        self.ob, self.cls, self.role, self.symmetric, self.pivot = ob, cls, role, symmetric, pivot
        self.collision, self.material, self.can_collide, self.cast_shadow = collision, material, can_collide, cast_shadow
        self.expect_dims, self.tint, self.notes = expect_dims, tint, notes
        # Kit metadata for the layout pipeline (MASTERPLAN 8.5) and the import check:
        #   layer "base" | "xmas" (the removable Christmas dressing layer), tags = CollectionService tags the level
        #   layout gives the piece (EH_Plate, EH_Door, EH_Hide...), joint = {"parent", "name"} for rigid rigs (Gus),
        #   atlas = uses the kit atlas TextureID (default: SmoothPlastic pieces), transparency (glass),
        #   texture = hero SurfaceAppearance set name, sim = "solid" | "low" (Gus sees over) | "none" | "door" ...
        self.layer, self.tags, self.joint = layer, list(tags), joint
        self.atlas = (material == "SmoothPlastic" and texture is None) if atlas is None else atlas
        self.transparency, self.texture, self.sim = transparency, texture, sim
        # free_shells: an object made of separate pieces held by ANOTHER object (glass panes in a frame, bulbs on
        # a wire). Its A16 floating-shell check is replaced by an asset seat check against the holder.
        self.free_shells = free_shells
        # on_floor: every shell stands on z = 0 (backdrop skylines: separate buildings on the ground, pivot at the
        # ring centre); A16 treats floor contact as seated, as it does for "bottom" and "corner" pivots.
        self.on_floor = on_floor
        self.extra = dict(extra or {})   # more manifest fields (Roblox axes): grips, hooks, light points...


class Asset:
    """One FBX file (one Model in Studio) of one or more objects."""

    def __init__(self, name, objects, budget_cls=None, grid=None, tile_x=None, seats=(), align=(), notes=""):
        self.name, self.objects, self.budget_cls = name, list(objects), budget_cls
        self.grid, self.tile_x, self.seats, self.align, self.notes = grid, tile_x, list(seats), list(align), notes


# ---------------------------------------------------------------- gates (A1-A18 via lihfolk_bpy, plus kit checks)

NAME_RE = re.compile(r"^[A-Z][A-Za-z0-9]*(_[A-Za-z0-9]+)*$")
RESERVED_SUFFIX = ("_Att", "_OuterCage", "_InnerCage")


def _shells(ob):
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    par = list(range(len(bm.verts)))
    def find(i):
        while par[i] != i:
            par[i] = par[par[i]]; i = par[i]
        return i
    for e in bm.edges:
        a, b = find(e.verts[0].index), find(e.verts[1].index)
        if a != b:
            par[a] = b
    groups = {}
    for f in bm.faces:
        groups.setdefault(find(f.verts[0].index), []).append(f.index)
    return bm, list(groups.values())


def floating_shells(ob, tol=0.02, floor_z=None):
    """Shells of one object that touch nothing: no other shell within tol and (if floor_z) not on the floor.
    The biggest shell is the base and is exempt. Returns a list of {'shell', 'faces', 'gap'}."""
    bm, groups = _shells(ob)
    if len(groups) < 2:
        bm.free(); return []
    def vol(g):
        pts = [v.co for i in g for v in bm.faces[i].verts]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        d = hi - lo
        return d.x * d.y * d.z
    base = max(range(len(groups)), key=lambda i: vol(groups[i]))
    out = []
    for gi, g in enumerate(groups):
        if gi == base:
            continue
        others = [i for gj, h in enumerate(groups) if gj != gi for i in h]
        verts = [v.co.copy() for v in bm.verts]
        polys_o = [[v.index for v in bm.faces[i].verts] for i in others]
        polys_s = [[v.index for v in bm.faces[i].verts] for i in g]
        to, ts = BVHTree.FromPolygons(verts, polys_o), BVHTree.FromPolygons(verts, polys_s)
        if to.overlap(ts):
            continue
        gap = min(to.find_nearest(verts[vi])[3] for p in polys_s for vi in p)
        on_floor = floor_z is not None and min(verts[vi].z for p in polys_s for vi in p) <= floor_z + tol
        if gap > tol and not on_floor:
            out.append({"shell": gi, "faces": len(g), "gap": round(gap, 4)})
    bm.free()
    return out


def pivot_check(ob, rule, tol=1e-3):
    """A12: the origin sits where the kit rule says. corner = local bbox min at (0,0,0); bottom = bottom centre;
    center = bbox centre; point = a named point (hinge, grid corner) set by the spec, always reported."""
    lo = Vector([min(c[i] for c in ob.bound_box) for i in range(3)])
    hi = Vector([max(c[i] for c in ob.bound_box) for i in range(3)])
    c = (lo + hi) / 2
    if rule == "corner":
        ok = lo.length < tol
    elif rule == "bottom":
        ok = abs(c.x) < tol and abs(c.y) < tol and abs(lo.z) < tol
    elif rule == "center":
        ok = c.length < tol
    else:
        ok = True
    return ok, {"rule": rule, "local_min": [round(x, 4) for x in lo], "local_max": [round(x, 4) for x in hi]}


def gate_asset(asset):
    """Runs every gate for an asset. Returns (passed, report dict)."""
    rep = {"asset": asset.name, "objects": [], "asset_fails": [], "lihfolk_bpy": "vendored 666ae79" if getattr(lf, "EH_SOURCE", "").endswith("vendor") else "LihFolk plugin"}
    names = [o.ob.name for o in asset.objects]
    total = 0
    for o in asset.objects:
        ob = o.ob
        passed, fails, r = lf.gate(ob, o.cls, symmetric=o.symmetric)
        fails = list(fails)
        total += r["tris"]
        ok, pr = pivot_check(ob, o.pivot)
        if not ok:
            fails.append(f"A12 origin not at the '{o.pivot}' point: {pr}")
        if o.expect_dims:
            d = [round(x, 3) for x in ob.dimensions]
            if any(abs(a - b) > 0.011 for a, b in zip(d, o.expect_dims)):
                fails.append(f"A7 dimensions {d} != expected {list(o.expect_dims)}")
        if not NAME_RE.match(ob.name) or ob.name.endswith(RESERVED_SUFFIX) or names.count(ob.name) > 1:
            fails.append(f"A14 bad name '{ob.name}'")
        used = used_swatches(ob)
        allowed = P.ROLE_RULES[o.role]
        bad = [k for k in used if P.ROLE[k] not in allowed]
        if bad:
            fails.append(f"P2 role '{o.role}' may not use reserved swatches {bad}")
        if o.role in P.FIXED_ROLES:
            loc = [k for k in used if k in P.LOCATION_CELLS]
            if loc:
                fails.append(f"P3 role '{o.role}' may not use location cells {loc} (they change per atlas swap)")
        on_floor = o.on_floor or o.pivot in ("bottom", "corner")
        fl = [] if o.free_shells else floating_shells(ob, floor_z=0.0 if on_floor else None)
        if fl:
            fails.append(f"A16 {len(fl)} floating shell(s): {fl}")
        tgt, ceil_ = lf.BUDGETS[o.cls]
        rep["objects"].append({
            "name": ob.name, "class": o.cls, "tris": r["tris"], "budget": [tgt, ceil_], "budget_note": r["budget_note"],
            "dims": [round(x, 3) for x in ob.dimensions], "pivot": pr, "swatches": used,
            "location": [round(x, 4) for x in ob.location],
            "symmetry_error": r.get("symmetry_error"), "self_intersections": r.get("self_intersections"),
            "cross_shell_overlaps": r.get("cross_shell_overlaps"), "cap_overlaps": r.get("cap_overlaps"),
            "flipped_faces": r.get("flipped_faces"), "boundary_edges": r["boundary_edges"],
            "non_manifold_edges": r["non_manifold_edges"], "ngons": r["ngons"], "materials": r["materials"],
            "uv_layers": r["uv_layers"], "uv_out_of_0_1": r.get("uv_out_of_0_1"),
            "studio": {"Material": o.material, "Color": "white (255,255,255)" if not o.tint else o.tint,
                       "CollisionFidelity": o.collision, "CanCollide": o.can_collide, "CastShadow": o.cast_shadow,
                       "Transparency": o.transparency, "atlas": o.atlas, "texture": o.texture},
            "layer": o.layer, "tags": o.tags, "joint": o.joint, "role": o.role,
            "notes": o.notes, "fails": fails, "passed": not fails})
    rep["tris_total"] = total
    if asset.budget_cls:
        tgt, ceil_ = lf.BUDGETS[asset.budget_cls]
        rep["asset_budget"] = {"class": asset.budget_cls, "target": tgt, "ceiling": ceil_}
        if total > ceil_:
            rep["asset_fails"].append(f"A1 assembly {total} tris > {asset.budget_cls} ceiling {ceil_}")
    if asset.grid:
        W, D, H, step = asset.grid
        ob = asset.objects[0].ob
        g = lf.grid_check(ob, (W, D, H), step=2.0)
        g["on_kit_grid"] = abs(W / step - round(W / step)) < 1e-6
        rep["grid"] = g
        if not (g["ok"] and g["on_kit_grid"]):
            rep["asset_fails"].append(f"KIT grid check failed: {g}")
    if asset.tile_x:
        t = lf.tile_check(asset.objects[0].ob, "X", asset.tile_x)
        rep["tile_x"] = t
        if not t["ok"]:
            rep["asset_fails"].append(f"KIT tile check failed: {t}")
    by = {o.ob.name: o.ob for o in asset.objects}
    rep["seats"] = []
    for feat, surf in asset.seats:
        s = lf.seated(by[feat], by[surf])
        rep["seats"].append(s)
        if not s["seated"]:
            rep["asset_fails"].append(f"A16 '{feat}' floats {s['gap']} studs off '{surf}'")
    rep["align"] = []
    for feat, parent, axes, target in asset.align:
        if ":" in feat:   # a named part inside one object: centre of its bbox vs target
            oname, pname = feat.split(":")
            ob = by[oname]; bb = list(ob["eh_parts"][pname])
            ctr = (Vector(bb[:3]) + Vector(bb[3:])) / 2 + ob.location
            size = max(by[parent].dimensions) or 1.0
            off = {x: round((ctr["XYZ".index(x)] - target["XYZ".index(x)]) / size, 5) for x in axes}
            a = {"name": feat, "offset": off, "max": max(abs(v) for v in off.values())}
        else:
            a = lf.alignment_report([by[feat]], by[parent], axes=axes, target=target)[0]
        rep["align"].append(a)
        if a["max"] > 0.02:
            rep["asset_fails"].append(f"A16 '{feat}' off-centre on '{parent}' by {a['max']:.2%}")
    w, h = bpy.data.images.load(ATLAS_PATH, check_existing=True).size
    rep["A11_atlas"] = [w, h]
    if not (w == h and w <= 1024 and (w & (w - 1)) == 0):
        rep["asset_fails"].append(f"A11 atlas {w}x{h} not a power of two <= 1024")
    pal_ok, _ = P.audit(verbose=False)
    rep["palette_audit"] = pal_ok
    if not pal_ok:
        rep["asset_fails"].append("P1 palette audit failed (python3 tools/blender/eh_palette.py)")
    passed = all(o["passed"] for o in rep["objects"]) and not rep["asset_fails"]
    rep["passed"] = passed
    return passed, rep


# ---------------------------------------------------------------- export (A13) and FBX verification

def export_fbx(objs, path):
    """Same parameters as lihfolk_bpy.export_fbx (FBX_SCALE_UNITS: no 100x import), for several objects."""
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             apply_scale_options="FBX_SCALE_UNITS", axis_forward="Z", axis_up="Y",
                             add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True,
                             use_mesh_modifiers=True, mesh_smooth_type="OFF", use_custom_props=False)
    return path


def verify_fbx(path, objs):
    """A13: parse the written FBX. UnitScaleFactor must be 100 (metres, = FBX Unit Scale), no Model may carry a
    Lcl Scaling other than 1 (the 100x bug), and each geometry's vertex extent must equal the object's size."""
    from io_scene_fbx import parse_fbx
    root, _ver = parse_fbx.parse(path)
    def kids(e, name):
        return [c for c in e.elems if c.id == name]
    def props70(e):
        out = {}
        for p70 in kids(e, b"Properties70"):
            for p in kids(p70, b"P"):
                out[p.props[0].decode()] = p.props[4:]
        return out
    fails, info = [], {}
    gs = next(iter(kids(root, b"GlobalSettings")), None)
    usf = props70(gs).get("UnitScaleFactor", [None])[0] if gs else None
    info["UnitScaleFactor"] = usf
    if usf is None or abs(usf - 100.0) > 1e-6:
        fails.append(f"A13 UnitScaleFactor {usf} != 100 (export without FBX_SCALE_UNITS)")
    objects = next(iter(kids(root, b"Objects")), None)
    models, geoms = [], []
    if objects:
        for e in objects.elems:
            if e.id == b"Model":
                sc = props70(e).get("Lcl Scaling")
                models.append((e.props[1].split(b"\x00")[0].decode(), sc))
            elif e.id == b"Geometry":
                vs = kids(e, b"Vertices")
                if vs:
                    a = vs[0].props[0]
                    xs, ys, zs = a[0::3], a[1::3], a[2::3]
                    geoms.append(sorted([max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)]))
    info["models"] = [m[0] for m in models]
    for name, sc in models:
        if sc and any(abs(float(s) - 1.0) > 1e-4 for s in sc[:3]):
            fails.append(f"A13 Model '{name}' has Lcl Scaling {list(sc[:3])} (100x import)")
    want = sorted(sorted(round(d, 3) for d in ob.dimensions) for ob in objs)
    got = sorted(sorted(round(d, 3) for d in g) for g in geoms)
    info["geometry_extents"] = got
    if len(got) != len(want) or any(abs(a - b) > 0.01 for g, w in zip(got, want) for a, b in zip(g, w)):
        fails.append(f"A13 FBX vertex extents {got} != object sizes {want}")
    anim = kids(objects, b"AnimationStack") if objects else []
    if anim:
        fails.append("A13 FBX contains an animation stack (bake_anim must be off)")
    return not fails, fails, info
