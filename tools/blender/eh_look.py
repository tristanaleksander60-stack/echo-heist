"""The Blender preview's look tricks, made into real kit data the engine draws (BLENDER LOOK track,
docs/audit/BLENDER_LOOK.md). The old previews looked good because Workbench drew a cavity pass and a black object
outline and Eevee added ambient occlusion; Roblox has none of those. Two of them can be baked into the meshes:

  bake_ao(asset)          ambient occlusion + cavity as a greyscale vertex colour (POINT domain, attribute EH_AO).
                          Roblox multiplies an FBX's vertex colours into the MeshPart's colour (the importer keeps
                          them; EditableMesh reads them back, kit_engine section B3), so a crease, the underside of a
                          prop and a limb against the torso come out darker at zero texture memory and zero
                          triangles. Deterministic (fixed ray directions, no render noise), so a rebuild keeps the
                          content hash and the uploaded id.
  make_hull(src, ...)     the inverted-hull outline: a copy of the piece pushed out along its vertex normals by
                          `thickness` studs, decimated (an outline needs the silhouette, not the detail), its faces
                          reversed. Roblox culls back faces (MeshPart.DoubleSided stays false), so only the part of
                          the hull outside the body's silhouette shows: a dark rim, like the Workbench outline. Neon in
                          Config.Outline.COLOUR at runtime (unlit, so it never picks up a highlight).

Numbers are build-time art constants (the Luau tuning knobs are Config.Outline: colour, thickness scale, tiers).
"""
import math

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

# ---------------------------------------------------------------- ambient occlusion + cavity

AO_ATTR = "EH_AO"
AO_RAYS = 40              # hemisphere rays per vertex (fixed Fibonacci set: deterministic)
AO_DIST = 1.1             # studs: contact occlusion (a limb against the torso, a bag on the floor)
CAVITY_DIST = 0.22        # studs: the creases (stitched grooves, the cap's brim, the stamp on a gold bar)
AO_STRENGTH = 0.42        # darkening at full contact occlusion ...
CAVITY_STRENGTH = 0.22    # ... and in a full crease
AO_FLOOR = 0.6            # never darker than this (the vault: soft and low-contrast; streaks show otherwise)
AO_MAX_DIM = 16.0         # studs: bigger pieces (walls, facades, floors) have too few vertices to carry it
AO_SKIP_CLASSES = ("module", "building")
EPS = 0.004               # ray origin lift off the surface
# Assets whose objects are always together in the game (a rig, a machine): their pieces occlude each other. Every
# other asset is a set of alternatives or separate props (caps, faces, ornaments, decor sets): each piece alone.
ASSEMBLED = {"Rookie", "Gus", "Hoardsworth", "Van", "VanBakery", "VanCamper", "VanSecurity", "VaultDoor", "Safe",
             "CashRegister", "Pedestal_Diamond", "Plate_4x4", "Intro_Lever", "Intro_Vacuum", "Intro_SnowGlobe",
             "Intro_Tower", "LaserEmitter", "LaserEmitter_CandyCane", "Wall_Door_8x12", "Pedestal_Diamond"}


def _fib_dirs(n):
    """n unit directions over the +Z hemisphere, cosine-weighted (more near the normal), fixed."""
    out = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        r = math.sqrt((i + 0.5) / n)
        phi = i * golden
        x, y = r * math.cos(phi), r * math.sin(phi)
        out.append(Vector((x, y, math.sqrt(max(0.0, 1.0 - r * r)))))
    return out


DIRS = _fib_dirs(AO_RAYS)


def _basis(n):
    a = Vector((1, 0, 0)) if abs(n.x) < 0.9 else Vector((0, 1, 0))
    t = n.cross(a).normalized()
    return t, n.cross(t)


def ao_eligible(o):
    """o: an eh_kit.Obj. Atlas / colour SmoothPlastic pieces small enough for per-vertex shading; no Neon, glass,
    hero SurfaceAppearance, skinned or already vertex-coloured mesh (the FP gloves bake their own shading)."""
    ob = o.ob
    if o.material != "SmoothPlastic" or o.transparency or o.texture or o.cls in AO_SKIP_CLASSES:
        return False
    if getattr(o, "outline", False):
        return False
    if ob.parent is not None and ob.parent.type == "ARMATURE":
        return False
    if len(ob.data.color_attributes) > 0:
        return False
    return max(ob.dimensions) <= AO_MAX_DIM


def _bvh(objs, ground):
    verts, polys = [], []
    for ob in objs:
        mw = ob.matrix_world
        base = len(verts)
        verts += [mw @ v.co for v in ob.data.vertices]
        polys += [[base + i for i in p.vertices] for p in ob.data.polygons]
    if ground is not None:
        lo, hi, z = ground
        base = len(verts)
        verts += [Vector((lo.x, lo.y, z)), Vector((hi.x, lo.y, z)), Vector((hi.x, hi.y, z)), Vector((lo.x, hi.y, z))]
        polys.append([base, base + 1, base + 2, base + 3])
    return BVHTree.FromPolygons(verts, polys, all_triangles=False, epsilon=0.0)


def bake_ao(obj_specs, occluders=None, ground=False):
    """Writes EH_AO (POINT, FLOAT_COLOR, greyscale, alpha 1) on every eligible object. occluders: the objects the
    rays may hit (default: each object alone, the right answer for alternatives such as caps or faces that never
    appear together); ground: a floor plane at the asset's lowest point (props and characters stand on it).
    Returns {object name: (min, mean)} for the report."""
    report = {}
    objs = [o.ob for o in obj_specs]
    if not objs:
        return report
    bpy.context.view_layer.update()      # matrix_world of freshly placed objects
    lo = Vector((min((o.matrix_world @ Vector(c)).x for o in objs for c in o.bound_box),
                 min((o.matrix_world @ Vector(c)).y for o in objs for c in o.bound_box), 0))
    hi = Vector((max((o.matrix_world @ Vector(c)).x for o in objs for c in o.bound_box),
                 max((o.matrix_world @ Vector(c)).y for o in objs for c in o.bound_box), 0))
    zmin = min((o.matrix_world @ Vector(c)).z for o in objs for c in o.bound_box)
    pad = Vector((4, 4, 0))
    gplane = (lo - pad, hi + pad, zmin) if ground else None
    shared = _bvh(occluders, gplane) if occluders else None
    for o in obj_specs:
        if not ao_eligible(o):
            continue
        ob = o.ob
        me = ob.data
        tree = shared or _bvh([ob], gplane)
        mw = ob.matrix_world
        nm = mw.to_3x3().inverted().transposed()
        bm = bmesh.new()
        bm.from_mesh(me)
        bm.verts.ensure_lookup_table()
        values = []
        for v in bm.verts:
            n = (nm @ v.normal)
            if n.length < 1e-6:
                values.append(1.0)
                continue
            n.normalize()
            p = mw @ v.co + n * EPS
            t, b = _basis(n)
            far = near = 0.0
            for d in DIRS:
                w = (t * d.x + b * d.y + n * d.z)
                hit = tree.ray_cast(p, w, AO_DIST)
                if hit[0] is not None:
                    far += 1.0
                    if hit[3] <= CAVITY_DIST:
                        near += 1.0
            f = 1.0 - AO_STRENGTH * far / len(DIRS) - CAVITY_STRENGTH * near / len(DIRS)
            values.append(round(max(AO_FLOOR, min(1.0, f)) * 255) / 255)
        bm.free()
        attr = me.color_attributes.new(AO_ATTR, "FLOAT_COLOR", "POINT")
        for i, val in enumerate(values):
            attr.data[i].color = (val, val, val, 1.0)
        me.color_attributes.active_color = attr
        me.color_attributes.render_color_index = me.color_attributes.active_color_index
        report[ob.name] = (round(min(values), 3), round(sum(values) / len(values), 3))
    return report


# ---------------------------------------------------------------- inverted-hull outlines

HULL_MIN_TRIS = 60        # pieces this small are copied as they are (decimating them chews the silhouette)
SHELL_MAX = 1.8           # even-thickness factor cap at sharp corners


def make_hull(src, name, thickness, ratio, ink_uv):
    """A new object `name`: src's mesh, welded, decimated to `ratio` (when bigger than HULL_MIN_TRIS), pushed out
    along its vertex normals by `thickness` studs (even thickness at corners), faces reversed (normals inward),
    all smooth, every UV on the ink cell. Same origin as src, so the piece and its hull share the kit point."""
    me = src.data.copy()
    me.name = name
    for ca in list(me.color_attributes):
        me.color_attributes.remove(ca)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = src.location.copy()
    ob.rotation_euler = src.rotation_euler.copy()
    ob.scale = src.scale.copy()
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
    # a canonical vertex and face order: the decimation depends on it, and some specs build in set order
    vrank = {v: i for i, v in enumerate(sorted(bm.verts, key=lambda v: (round(v.co.x, 5), round(v.co.y, 5),
                                                                            round(v.co.z, 5))))}
    bm.verts.sort(key=lambda v: vrank[v])
    bm.verts.index_update()
    frank = {f: i for i, f in enumerate(sorted(bm.faces, key=lambda f: tuple(sorted(v.index for v in f.verts))))}
    bm.faces.sort(key=lambda f: frank[f])
    bm.to_mesh(me)
    bm.free()
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    if ratio < 1.0 and tris > HULL_MIN_TRIS:
        mod = ob.modifiers.new("EH_Decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = ratio
        mod.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        new = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        ob.modifiers.remove(mod)
        old = ob.data
        ob.data = new
        new.name = name
        bpy.data.meshes.remove(old)
        me = new
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.normal_update()
    offs = []
    for v in bm.verts:
        s = min(SHELL_MAX, max(1.0, v.calc_shell_factor())) if v.link_faces else 1.0
        offs.append(v.normal * thickness * s)
    for v, d in zip(bm.verts, offs):
        v.co += d
    bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    ngon = [f for f in bm.faces if len(f.verts) > 3]
    if ngon:
        bmesh.ops.triangulate(bm, faces=ngon)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = True
    for lay in list(bm.loops.layers.uv):
        bm.loops.layers.uv.remove(lay)
    uvl = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        for lp in f.loops:
            lp[uvl].uv = ink_uv
    bm.to_mesh(me)
    bm.free()
    me.update()
    me.materials.clear()
    for slot in src.data.materials:
        me.materials.append(slot)
        break
    return ob


def signed_volume(ob):
    """Signed volume of the mesh (negative = faces wound inward, i.e. a flipped hull)."""
    vol = 0.0
    me = ob.data
    for p in me.polygons:
        vs = [me.vertices[i].co for i in p.vertices]
        for i in range(1, len(vs) - 1):
            vol += vs[0].dot(vs[i].cross(vs[i + 1])) / 6.0
    return vol
