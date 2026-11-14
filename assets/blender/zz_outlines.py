"""Ink outlines (BLENDER LOOK track, docs/audit/BLENDER_LOOK.md): inverted hulls for the characters, the hero props
and the loot, the in-engine version of the Workbench object outline the Blender previews drew.

Build: python3 tools/blender/build_asset.py assets/blender/zz_outlines.py   (the "zz_" sorts it last in --all, after
every source spec has been rebuilt; the sources are rebuilt here from their own specs, not read back from FBX, so a
hull always matches its piece exactly).

One hull per piece, `<Piece>_Outline` (tools/blender/eh_look.make_hull: welded, decimated, pushed out along the vertex
normals by the thickness, faces reversed). Same origin as its piece, so KitService welds it on at the piece's kit point
(manifest `outlineOf`). Roblox culls back faces, so only the rim outside the piece's silhouette draws. Neon, CanCollide /
CanQuery / CanTouch / CastShadow off; colour and the per-tier budget are Config.Outline (client Heist/Outlines).

Groups (one FBX each, loaded with their source's phase):
  Rookie_Outline       the Rookie's body and the outfit pieces that change the silhouette (caps, scarves, gloves,
                       the mask; the flush stripes, cuffs and blocks ride on the body's hull)  -> priority phase
  Hoardsworth_Outline  the villain (intro phase)
  Van_Outline          the getaway van (intro phase, like Van)
  Gus_Outline          the guard
  Prop_Outline         hero props (vault door, the hideout vans, job board, plates, the door leaf) and the loot
Thickness in studs per asset size (an outline is world-space: 0.035 studs is ~1 px at ~27 studs on a 1080p screen).
"""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))

CHAR_T, CHAR_R = 0.035, 0.7    # thickness (studs), decimation ratio
HERO_T, HERO_R = 0.06, 0.6      # vans, the vault door
SMALL_T, SMALL_R = 0.045, 0.7   # job board, plates, the door leaf, the dial
LOOT_T, LOOT_R = 0.035, 0.8

OUTFIT_SKIP = ("Rookie_Stripes_", "Rookie_Block_")   # flush overlays: the body's hull already draws their outline

# group -> [(spec file, function or None for build(k), {asset: (class, thickness, ratio, keep(name) -> bool)})]
GROUPS = {
    "Rookie_Outline": [
        ("rookie.py", None, {
            "Rookie": ("char", CHAR_T, CHAR_R, lambda n: not n.startswith("Rookie_Face")),
            "Rookie_Outfits": ("char", 0.03, CHAR_R, lambda n: not n.startswith(OUTFIT_SKIP)),
        }),
    ],
    "Hoardsworth_Outline": [
        ("intro.py", "hoardsworth", {"Hoardsworth": ("char", CHAR_T, CHAR_R, lambda n: n != "Hoardsworth_Monocle")}),
    ],
    "Van_Outline": [
        ("van.py", None, {"Van": ("hero", HERO_T, HERO_R, lambda n: n != "Van_Shelf")}),
    ],
    "Gus_Outline": [
        ("gus.py", None, {"Gus": ("char", CHAR_T, CHAR_R, lambda n: n != "Gus_FlashlightLens")}),
    ],
    "Prop_Outline": [
        ("van_styles.py", None, {
            "VanBakery": ("hero", HERO_T, HERO_R, None),
            "VanCamper": ("hero", HERO_T, HERO_R, None),
            "VanSecurity": ("hero", HERO_T, HERO_R, None),
        }),
        ("vault_door.py", None, {"VaultDoor": ("hero", HERO_T, HERO_R,
                                               lambda n: n in ("VaultDoor_Door", "VaultDoor_Frame", "VaultDoor_Dial"))}),
        ("garage.py", "job_board", {"JobBoard": ("hero", SMALL_T, SMALL_R, None)}),
        ("mechanisms.py", "plate", {"Plate_4x4": ("hero", SMALL_T, SMALL_R, lambda n: n == "Plate_4x4")}),
        ("wall.py", "door", {"Wall_Door_8x12": ("hero", SMALL_T, SMALL_R, lambda n: n == "Wall_Door_8x12_Leaf")}),
        ("props.py", "cash_bag", {"CashBag": ("loot", LOOT_T, LOOT_R, None)}),
        ("loot.py", None, {name: ("loot", LOOT_T, LOOT_R, None) for name in ("Present", "Candy", "Toy", "Teddy")}),
        ("gold_bar.py", None, {"GoldBar": ("loot", 0.03, LOOT_R, None), "GoldStack": ("loot", 0.03, LOOT_R, None)}),
        ("diamond.py", None, {"Diamond": ("loot", 0.03, 1.0, None)}),
        ("hero_props.py", None, {
            "CashRegister": ("loot", 0.03, LOOT_R, lambda n: n == "CashRegister_Drawer"),
            "GiantPresent": ("hero", 0.06, HERO_R, None),   # a 7-stud heavy carry: hero-sized, tier 1 only
        }),
    ],
}


def _load(fname):
    path = os.path.join(HERE, fname)
    spec = importlib.util.spec_from_file_location("eh_outline_src_" + fname[:-3], path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def build(k):
    import bpy
    import eh_look
    ink = k.P.cell_uv("ink")[:2]
    out = []
    made_src = []
    for group, sources in GROUPS.items():
        objs = []
        for fname, fn, wanted in sources:
            mod = _load(fname)
            res = getattr(mod, fn)(k) if fn else mod.build(k)
            res = res if isinstance(res, list) else [res]
            for a in res:
                made_src += [o.ob for o in a.objects]
                if a.name not in wanted:
                    continue
                cls, t, ratio, keep = wanted[a.name]
                for o in a.objects:
                    if keep is not None and not keep(o.ob.name):
                        continue
                    if o.material != "SmoothPlastic" or o.transparency:
                        continue
                    hull = eh_look.make_hull(o.ob, o.ob.name + "_Outline", t, ratio, ink)
                    objs.append(k.Obj(
                        hull, o.cls, role=o.role, pivot="point", collision="Box", material="Neon",
                        can_collide=False, cast_shadow=False, atlas=False, layer=o.layer, outline=True,
                        notes=f"outline of {o.ob.name}: inverted hull, {t} studs, decimated to {ratio:.0%}",
                        extra={"outlineOf": o.ob.name, "outlineClass": cls, "outlineThickness": t}))
        out.append(k.Asset(group, objs, notes="Ink outlines (BLENDER LOOK): inverted hulls, Neon in "
                           "Config.Outline.COLOUR, welded to their piece by KitService; Heist/Outlines picks which "
                           "draw per tier (Config.Outline.TIERS)."))
    for ob in made_src:
        bpy.data.objects.remove(ob, do_unlink=True)
    return out
