"""Kit import docs from the manifest and the level data: the generated sections of docs/art/KIT_IMPORT.md (between
`<!-- name:start -->` / `<!-- name:end -->` markers) and the Studio command-bar prepare script
docs/art/KitPrepare.commandbar.lua. No bpy needed.

    python3 tools/blender/kit_docs.py

Run it after `python3 tools/blender/build_asset.py --all` (the manifest is the single source of truth for the kit).
The fit table compares kit pieces, placed by the STYLE_BIBLE 5.2 rules, with the LevelSpec boxes of the launch levels
and daily vaults. The boxes come from `lune run tools/blender/level_boxes.luau` (cached in docs/art/level_boxes.json,
so the docs still build where Lune is missing).
"""
import json, math, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import eh_palette as P  # noqa: E402

REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
MANIFEST = os.path.join(REPO, "assets", "fbx", "kit_manifest.json")
DOC = os.path.join(REPO, "docs", "art", "KIT_IMPORT.md")
LUA = os.path.join(REPO, "docs", "art", "KitPrepare.commandbar.lua")
LEVELS_CACHE = os.path.join(REPO, "docs", "art", "level_boxes.json")

# Fallback (server-built meshes) cost model, DevForum report [UNVERIFIED]: per mesh + per 1,000 triangles.
CREATE_MS_PER_MESH, CREATE_MS_PER_KTRI = 22.0, 0.27


def load():
    with open(MANIFEST) as f:
        return json.load(f)


def idle_colour(name, p):
    """The colour the prepare script gives a part: Neon idle (eh_palette.NEON), glass tint, a tintable ornament's
    default, else none (white, the atlas carries the colour)."""
    if p["material"] == "Neon":
        if name not in P.NEON:
            raise SystemExit(f"kit_docs: Neon part {name} has no entry in eh_palette.NEON (idle colour + audit)")
        return P.NEON[name][0]
    if p["material"] == "Glass":
        return P.GLASS_TINT
    if name in P.ORNAMENT_IDLE:
        return P.ORNAMENT_TINTS[P.ORNAMENT_IDLE[name]]
    return None


# ---------------------------------------------------------------- import table

def table(man):
    rows = ["| Model (FBX) | MeshPart | Size in Studio (X x Y x Z) | Tris | Collision | Material | CanCollide | CastShadow | Layer |",
            "|---|---|---|---|---|---|---|---|---|"]
    parts = man["parts"]
    for name in sorted(parts, key=lambda n: (parts[n]["model"], n)):
        p = parts[name]
        size = " x ".join(f"{v:g}" for v in p["size"])
        mat = p["material"] + (" + SA" if p.get("texture") else "") + (f" (T {p['transparency']})" if p.get("transparency") else "")
        rows.append(f"| {p['model']}.fbx | {name} | {size} | {p['tris']} | {p['collision']} | {mat} | "
                    f"{'on' if p['canCollide'] else 'off'} | {'on' if p['castShadow'] else 'off'} | {p.get('layer', 'base')} |")
    models = {p["model"] for p in parts.values()}
    rows.append("")
    rows.append(f"**{len(models)} FBX files, {len(parts)} MeshParts, {sum(p['tris'] for p in parts.values()):,} triangles in all.** "
                f"Christmas layer: {sum(1 for p in parts.values() if p.get('layer') == 'xmas')} parts.")
    return "\n".join(rows)


# ---------------------------------------------------------------- level data and placement maths

def level_boxes():
    """{level id: level dict} from the level data (Lune), or the cache when Lune is not available."""
    data = None
    try:
        out = subprocess.run(["lune", "run", "tools/blender/level_boxes.luau"], cwd=REPO, capture_output=True, text=True,
                             check=True, timeout=120).stdout
        data = json.loads(out)
        with open(LEVELS_CACHE, "w") as f:
            json.dump(data, f, separators=(",", ":"), sort_keys=True)
            f.write("\n")
    except (OSError, subprocess.SubprocessError, ValueError) as e:
        print(f"kit_docs: level data from the cache ({e.__class__.__name__}: lune unavailable or failed)")
        with open(LEVELS_CACHE) as f:
            data = json.load(f)
    levels = {}
    for lv in data["levels"]:
        for key in ("solids", "plates", "doors", "lasers", "hides", "loot", "switches"):
            if not isinstance(lv.get(key), list):
                lv[key] = []          # serde writes an empty Luau table as {}
        levels[lv["id"]] = lv
    return levels


def rot(x, z, yaw):
    """CFrame.Angles(0, yaw, 0) applied to (x, z)."""
    t = math.radians(yaw)
    c, s = math.cos(t), math.sin(t)
    return x * c + z * s, -x * s + z * c


def footprint(man, part, at, yaw, lo=None, hi=None):
    """World X / Z range of a part placed with its Model pivot at `at` (x, y, z) and yaw (degrees). lo / hi: a local
    box in the Model's space instead of the part's bounds (openings, niches)."""
    p = man["parts"][part]
    if lo is None:
        o = p["origin"]
        lo = [o[i] + p["boundsMin"][i] for i in range(3)]
        hi = [o[i] + p["boundsMax"][i] for i in range(3)]
    xs, zs = [], []
    for x in (lo[0], hi[0]):
        for z in (lo[2], hi[2]):
            rx, rz = rot(x, z, yaw)
            xs.append(at[0] + rx)
            zs.append(at[2] + rz)
    return min(xs), max(xs), min(zs), max(zs)


def item(levels, level, kind, iid):
    for it in levels[level][kind]:
        if str(it.get("id")) == str(iid):
            return it
    raise SystemExit(f"kit_docs: no {kind} '{iid}' in {level} (the level data changed: update FIT)")


def fmt_range(a, b):
    return f"{a:g}..{b:g}"


def fmt_box(b):
    return f"X {fmt_range(b[0], b[3])}, Z {fmt_range(b[2], b[5])}"


# Fit rows: (label, level, kind, id, kit part, Model pivot (x, y, z), yaw deg, mode, extra). Pivots follow STYLE_BIBLE
# 5.2: wall modules centred on their line (formula in KIT_IMPORT), free pieces centred on their box or plate.
FIT = [
    ("Shell wall (L1 west, x = -16)", "cs1_back_room", "solids", "3", "Wall_8x12", (-17, 0, -8), 90, "wall", {"axis": "x"}),
    ("Partition (L2, z = -20)", "cs2_two_doors", "solids", "6", "Wall_8x12", (-4, 0, -21), 0, "wall", {"axis": "z"}),
    ("Front wall beside the storefront (L1, z = 10)", "cs1_back_room", "solids", "1", "Wall_4x12", (-16, 0, 11), 180, "wall",
     {"axis": "z"}),
    ("Door frame (L1 BackRoom door)", "cs1_back_room", "doors", "BackRoom", "Wall_Door_8x12", (4, 0, -21), 0, "opening", {}),
    ("Door leaf (L1 BackRoom door)", "cs1_back_room", "doors", "BackRoom", "Wall_Door_8x12_Leaf", (4, 0, -21), 0, "door", {}),
    ("Storefront entrance (L5 Shutter)", "cs5_clone_party", "doors", "Shutter", "Storefront_24x12", (-12, 0, 11), 180, "opening", {}),
    ("Shutter (L5 Shutter, DV09 Shutter)", "cs5_clone_party", "doors", "Shutter", "Shutter_8x10", (0, 10.35, 10), 180, "door", {}),
    ("Bank front entrance (L6 FrontDoors)", "bk1_big_score", "doors", "FrontDoors", "BankFront_24x12", (-12, 0, 11), 180, "opening", {}),
    ("Shutter (L6 FrontDoors)", "bk1_big_score", "doors", "FrontDoors", "Shutter_8x10", (0, 10.35, 10), 180, "door", {}),
    ("Vault frame (L6 VaultDoor)", "bk1_big_score", "doors", "VaultDoor", "VaultDoor_Frame", (-8, 0, -47), 180, "opening", {}),
    ("Vault door OPEN (L6)", "bk1_big_score", "doors", "VaultDoor", "VaultDoor_Door", (-8, 0, -47), 180, "clear", {}),
    ("Plate (L1 A)", "cs1_back_room", "plates", "A", "Plate_4x4", (10, 0, -8), 0, "exact", {}),
    ("Laser post (L3 Grid, west end)", "cs3_lights_out", "lasers", "Grid", "LaserEmitter", (-15, 0, -34), -90, "end", {}),
    ("Counter (L2-L4, west wall)", "cs2_two_doors", "solids", "10", "Counter_4x4", (-11, 0, 0), -90, "solid", {"backed": "-x"}),
    ("Counter (L1)", "cs1_back_room", "solids", "8", "Counter_8x4", (-14, 0, 0), 180, "solid",
     {"note": "Content track: widen the L1 counter box to X -14..-6 to match the 8-wide module"}),
    ("Counter + till (L5, west wall)", "cs5_clone_party", "solids", "8", "Counter_8x4", (-15, 0, 1), 180, "solid",
     {"backed": "-x", "note": "The till (Register loot at X -8.5, Z -1) sits on the counter's east end, outside the box: "
                              "content track, widen the box to X -15.5..-7 (or move the till to X <= -10.5)"}),
    ("Lobby counter run (L6, west half, 1 of 2 modules)", "bk1_big_score", "solids", "16", "Counter_8x2", (-11, 0, -4), 180, "wall",
     {"axis": "z"}),
    ("Aisle shelf (L5 west row, 1 of 2 modules)", "cs5_clone_party", "solids", "9", "Shelf_Gondola_8x2", (-9, 0, -22), 90, "wall",
     {"axis": "x"}),
    ("Pillar (L6 StaffPillar)", "bk1_big_score", "solids", "StaffPillar", "Pillar_2x12", (4, 0, -18), 0, "solid", {}),
    ("Hide: L4 Crate", "cs4_night_clerk", "hides", "Crate", "Hide_Crate", None, 180, "hide", {"backTo": -35}),
    ("Hide: L4 CoatRack (plate B)", "cs4_night_clerk", "hides", "CoatRack", "Hide_CoatRack", (-12, 0, -23), 0, "hide", {"plate": "B"}),
    ("Hide: DV09 CoatRack (plate A)", "dv09_sleigh_bell_alarm", "hides", "CoatRack", "Hide_CoatRack", (10, 0, -8), 0, "hide", {"plate": "A"}),
    ("Hide: L6 Fern (plate B; DV10, DV12 same)", "bk1_big_score", "hides", "Fern", "Hide_Plant", (-16, 0, -18), 90, "hide", {"plate": "B"}),
    ("Hide: L6 WestStack (plate C)", "bk1_big_score", "hides", "WestStack", "Hide_DepositStack", (-13, 0, -42), 180, "hide", {"plate": "C"}),
    ("Hide: L6 EastStack (plate D)", "bk1_big_score", "hides", "EastStack", "Hide_DepositStack", (13, 0, -42), 180, "hide", {"plate": "D"}),
    ("Hide: L6 CoatStand", "bk1_big_score", "hides", "CoatStand", "Hide_CoatStand", (16, 0, -17), 90, "hide", {}),
    ("Hide: DV12 CoatStand", "dv12_night_before", "hides", "CoatStand", "Hide_CoatStand", (16.25, 0, -17.75), 90, "hide", {}),
    ("Hide: DV04 Tree (Christmas layer piece)", "dv04_mistletoe_patrol", "hides", "Tree", "Xmas_Tree", (-13, 0, -24), 0, "hide", {}),
    ("Hide: L6 TellerDesk (plate A)", "bk1_big_score", "hides", "TellerDesk", None, None, 0, "none", {"plate": "A"}),
]


def side_text(m):
    """m = {side: margin}; margin > 0: the sim box reaches past the kit there; < 0: the kit reaches past the box."""
    return ", ".join(f"{s} {v:+.2f}" for s, v in m.items() if abs(v) >= 0.005) or "exact"


def fit_row(man, levels, row):
    label, level, kind, iid, part, at, yaw, mode, ex = row
    it = item(levels, level, kind, iid)
    b = it["box"]
    box_txt = fmt_box(b)
    if mode == "none":
        plate = item(levels, level, "plates", ex["plate"])["box"]
        return (label, box_txt, "none", "-", "-",
                f"**No kit piece reads as cover here.** Plate {ex['plate']} ({fmt_box(plate)}) sits in the box, behind the "
                "3.5-tall lobby counter: a 5.2 avatar shows above it. Suggest a `Hide_DepositStack` (open side to the counter) "
                "or a `Hide_CoatStand`: content-track call")
    p = man["parts"][part]
    if at is None and "backTo" in ex:        # back of the piece on a wall face (z); centred on the box in X
        fx = footprint(man, part, (0, 0, 0), yaw)
        cx = (b[0] + b[3]) / 2
        at = (cx - (fx[0] + fx[1]) / 2, 0, ex["backTo"] - fx[2])
    place = f"`{part}` pivot ({round(at[0], 2):g}, {round(at[1], 2):g}, {round(at[2], 2):g}), yaw {yaw:g}"
    if mode == "opening":
        op = p["opening"]
        o = p["origin"]
        fx = footprint(man, part, at, yaw, [o[0] + op["x"][0], 0, o[2]], [o[0] + op["x"][1], 0, o[2]])
        d0, d1 = fx[0] - b[0], b[3] - fx[1]
        verdict = ("Exact" if abs(d0) < 0.01 and abs(d1) < 0.01 else
                   f"Kit opening {'narrower' if d0 > 0 else 'wider'} by {abs(d0):.2f} / {abs(d1):.2f}"
                   + (" (solid to physics where the sim is open: the safe direction)" if d0 > 0 and d1 > 0 else " (CHECK)"))
        return label, box_txt, place, f"opening X {fmt_range(round(fx[0], 2), round(fx[1], 2))}", "-", verdict
    if mode == "clear":                       # the open vault door's resting footprint vs everything in the level
        op = p["open"]
        fx = footprint(man, part, at, yaw, op["footprintMin"], op["footprintMax"])
        hits = []
        for k2 in ("plates", "hides"):
            for other in levels[level][k2]:
                ob = other["box"]
                if ob[0] < fx[1] and ob[3] > fx[0] and ob[2] < fx[3] and ob[5] > fx[2]:
                    ox = min(ob[3], fx[1]) - max(ob[0], fx[0])
                    oz = min(ob[5], fx[3]) - max(ob[2], fx[2])
                    hits.append(f"{k2[:-1]} {other['id']} ({ox:.1f} x {oz:.1f})")
        for lt in levels[level]["loot"]:
            if fx[0] < lt["x"] < fx[1] and fx[2] < lt["z"] < fx[3]:
                hits.append(f"loot {lt['id']}")
        verdict = ("Clear" if not hits else "**CONFLICT: the open door rests on " + ", ".join(hits) +
                   "** (CanCollide is off while open, but it covers them visually): content track, move them >= 3 studs north")
        return (label, box_txt, place + f", open yaw {op['yawDeg']} at the hinge",
                f"X {fmt_range(round(fx[0], 2), round(fx[1], 2))}, Z {fmt_range(round(fx[2], 2), round(fx[3], 2))}", "-", verdict)
    fx = footprint(man, part, at, yaw)
    foot = f"X {fmt_range(round(fx[0], 2), round(fx[1], 2))}, Z {fmt_range(round(fx[2], 2), round(fx[3], 2))}"
    m = {"-X": fx[0] - b[0], "+X": b[3] - fx[1], "-Z": fx[2] - b[2], "+Z": b[5] - fx[3]}
    if mode == "wall":
        ax = ex["axis"].upper()
        mm = {k: v for k, v in m.items() if k.endswith(ax)}
        ok = all(v <= 0.01 for v in mm.values())
        verdict = ("Kit covers the sim wall (the safe direction)" if ok else "**SIM BOX OUTSIDE THE KIT** (unsafe)")
        return label, box_txt, place, foot, side_text(mm), verdict
    if mode in ("solid", "door", "exact"):
        backed = ex.get("backed", "")
        unsafe = {k: v for k, v in m.items() if v > 0.01 and k.lower() != backed}
        if mode == "exact":
            verdict = "Exact" if all(abs(v) < 0.01 for v in m.values()) else "**NOT EXACT**"
        elif unsafe:
            verdict = "**SIM BOX OUTSIDE THE KIT on " + ", ".join(unsafe) + "** (unsafe: open to physics, solid to the sim)"
        elif all(abs(v) < 0.01 for v in m.values()):
            verdict = "Exact"
        else:
            wider = {k: -v for k, v in m.items() if v < -0.01}
            verdict = ("Kit covers the box" + (f" (the box's {backed.upper()} end is inside the wall)" if backed else "") +
                       (f"; kit wider by {', '.join(f'{k} {v:.2f}' for k, v in wider.items())}: solid to physics where the sim "
                        "is open (safe)" if wider else ""))
        if ex.get("note"):
            verdict += ". " + ex["note"]
        return label, box_txt, place, foot, side_text(m), verdict
    if mode == "end":
        return (label, box_txt, place, foot, side_text({k: v for k, v in m.items() if k != "+X"}),
                "Post on the wall face, lens toward +X; beams by code from lens to lens. The box's last 0.5 is inside the wall")
    # hides
    notes = []
    beyond = {k: -v for k, v in m.items() if v < -0.3}
    loose = {k: v for k, v in m.items() if v > 1.2}
    if beyond:
        notes.append("kit reaches past the box (" + ", ".join(f"{k} {v:.2f}" for k, v in beyond.items()) + "): looks like cover, not hidden there")
    if loose:
        notes.append("box reaches past the kit (" + ", ".join(f"{k} {v:.2f}" for k, v in loose.items()) + "): hidden with no cover there")
    if "plate" in ex:
        pb = item(levels, level, "plates", ex["plate"])["box"]
        cx, cz = (pb[0] + pb[3]) / 2, (pb[2] + pb[5]) / 2
        niche = p.get("niche")
        if niche:
            nx = footprint(man, part, at, yaw, [niche["x"][0], 0, niche["z"][0]], [niche["x"][1], 0, niche["z"][1]])
            r = 1.65   # Plate_4x4_Ring half size
            inside = nx[0] <= cx - r + 0.01 and nx[1] >= cx + r - 0.01 and nx[2] <= cz - r + 0.01 and nx[3] >= cz + r - 0.01
            notes.append(f"plate {ex['plate']} ring {'inside the open niche (visible)' if inside else '**NOT inside the niche**'}")
        else:
            notes.append(f"**plate {ex['plate']} has no niche in this piece**")
    if part == "Xmas_Tree":
        notes.append("a Christmas-layer piece: DV04 needs the dressing on while it is live")
    verdict = "; ".join(notes) if notes else "Inside the box"
    return label, box_txt, place, foot, side_text(m), verdict[0].upper() + verdict[1:]


def fit_table(man, levels):
    rows = ["Boxes and footprints are **X range, Z range in Roblox world studs** (Y is up; heights are left out). "
            "\"Fit\" lists, per side, how far the sim box reaches past the kit piece (+) or the kit past the box (-). "
            "Generated from `kit_manifest.json` and the level data by `tools/blender/kit_docs.py`.",
            "",
            "| Level item | Sim box | Kit piece and placement (Model pivot X, Y, Z; yaw) | Kit footprint | Fit (+ box past kit) | Verdict |",
            "|---|---|---|---|---|---|"]
    for r in FIT:
        rows.append("| " + " | ".join(fit_row(man, levels, r)) + " |")
    return "\n".join(rows)


# ---------------------------------------------------------------- loot kinds, ornaments, fallback cost

LOOT_MESH = {   # LevelSpec loot kind -> (kit mesh, how it is shown)
    "Cash": ("CashBag", "carried; a till (`top` Register) is `CashRegister` + `CashRegister_Drawer`"),
    "Gold": ("GoldBar", "carried; on display a `GoldStack` (L6 Gold: the stack on a dark pedestal or Counter_8x2 top)"),
    "Diamond": ("Diamond", "on `Pedestal_Diamond` (+ `_Case`); hovers 1.25 above the cushion"),
    "Present": ("Present", "carried (daily vaults); heavy loot (`heavy`) is `GiantPresent` with 4 `grips`"),
    "Candy": ("Candy", "carried; on window displays and shelf boards (dark tops only)"),
    "Toy": ("Toy", "carried; on `Shelf_Gondola_8x2` boards (L5)"),
    "Teddy": ("Teddy", "carried; on `Shelf_Gondola_8x2` boards (L5 back rows)"),
}


def loot_table(man, levels):
    uses = {}
    for lv in levels.values():
        for lt in lv["loot"]:
            uses.setdefault(lt["kind"], []).append(lv["id"])
    rows = ["| Loot kind | Kit mesh | Placed in | Shown as |", "|---|---|---|---|"]
    for kind in sorted(set(uses) | set(LOOT_MESH)):
        mesh, how = LOOT_MESH.get(kind, (None, ""))
        if mesh is None or mesh not in man["parts"]:
            raise SystemExit(f"kit_docs: loot kind {kind} has no kit mesh (add one, or a LOOT_MESH row)")
        lv = uses.get(kind, [])
        where = f"{len(lv)} in {len(set(lv))} level(s)" if lv else "no launch level yet"
        rows.append(f"| {kind} | `{mesh}` | {where} | {how} |")
    return "\n".join(rows)


def ornament_table(man):
    rows = ["| Dec | Trophy id | Mesh | MeshPart.Color |", "|---|---|---|---|"]
    for o in man.get("ornamentDays") or P.ornament_days():
        rows.append(f"| {o['day']} | `Orn_Advent2026_{o['day']:02d}` | `{o['mesh']}` | `{o['color']}`"
                    + (" (fixed colours: keep white)" if o["color"] == "#FFFFFF" else "") + " |")
    return "\n".join(rows)


def fallback_cost(man):
    n = len(man["parts"])
    tris = sum(p["tris"] for p in man["parts"].values())
    secs = (n * CREATE_MS_PER_MESH + tris / 1000 * CREATE_MS_PER_KTRI) / 1000
    return (f"4. Cost: about {CREATE_MS_PER_MESH:g} ms per mesh plus {CREATE_MS_PER_KTRI:g} ms per 1,000 triangles "
            f"[UNVERIFIED, DevForum report]: for this kit's {n} MeshParts and {tris:,} triangles about **{secs:.1f} s** at "
            "boot (generated by kit_docs.py). Boot only, never per heist.")


# ---------------------------------------------------------------- the Studio prepare script

def lua(man):
    parts = man["parts"]
    out = ["-- Echo Heist kit prepare + check (generated by tools/blender/kit_docs.py from assets/fbx/kit_manifest.json).",
           "-- Select the Kit folder, paste into View > Command Bar, press Enter. Re-run after every re-import.",
           "-- 1. Paste the uploaded image ids (docs/art/KIT_IMPORT.md step 3) here: a number (123456789) or a full",
           "--    rbxassetid://123456789. Leave \"\" to skip a map.",
           'local ATLAS = "" -- assets/textures/EH_Palette_Bank.png (empty: use the first TextureID the importer made)',
           'local DIALFACE_COLOR = "" -- assets/textures/VaultDoor_DialFace_Color.png',
           'local DIALFACE_ROUGHNESS = "" -- assets/textures/VaultDoor_DialFace_Roughness.png',
           'local DIALFACE_EMISSIVE = "" -- assets/textures/VaultDoor_DialFace_Emissive.png',
           "",
           'local Selection = game:GetService("Selection")',
           "local kit = Selection:Get()[1]",
           'assert(kit and kit.Name == "Kit", "Select the Kit folder first")',
           "",
           "-- A bare number becomes rbxassetid://<number>; anything else is used as it is.",
           "local function uri(id: string): string",
           '\tlocal s = string.match(id, "^%s*(.-)%s*$") or ""',
           '\tif string.match(s, "^%d+$") then',
           '\t\treturn "rbxassetid://" .. s',
           "\tend",
           "\treturn s",
           "end",
           "",
           "local WANT = {"]
    for name in sorted(parts):
        p = parts[name]
        x, y, z = p["size"]
        col = idle_colour(name, p)
        fields = [f'model = "{p["model"]}"', f"size = Vector3.new({x:g}, {y:g}, {z:g})", f'collision = "{p["collision"]}"',
                  f'material = "{p["material"]}"', f"canCollide = {str(p['canCollide']).lower()}",
                  f"castShadow = {str(p['castShadow']).lower()}", f"atlas = {str(p['atlas']).lower()}"]
        if p.get("transparency"):
            fields.append(f"transparency = {p['transparency']:g}")
        if col:
            fields.append(f'color = "{col}"')
        if p.get("texture"):
            fields.append(f'texture = "{p["texture"]}"')
        out.append(f"\t{name} = {{ {', '.join(fields)} }},")
    out += ["}",
            "",
            "local function hex(h: string): Color3",
            "\treturn Color3.fromHex(h)",
            "end",
            "",
            "-- 2. Every MeshPart under Kit, by name. Each Model is named after its FBX file and many MeshParts share their",
            "-- Model's name (CashBag inside CashBag, Safe inside Safe), so FindFirstChild(name, true) would return the Model:",
            "-- never look kit pieces up that way (tests/kit_check.luau must not either).",
            "local parts: { [string]: MeshPart } = {}",
            "local problems = 0",
            "for _, d in kit:GetDescendants() do",
            '\tif d:IsA("MeshPart") then',
            "\t\tif parts[d.Name] then",
            "\t\t\tproblems += 1",
            '\t\t\twarn("DUPLICATE MeshPart name", d:GetFullName(), "and", parts[d.Name]:GetFullName())',
            "\t\telse",
            "\t\t\tparts[d.Name] = d",
            "\t\tend",
            "\t\tif not WANT[d.Name] then",
            '\t\t\twarn("NOT IN THE MANIFEST (an old or renamed piece: delete it)", d:GetFullName())',
            "\t\tend",
            "\tend",
            "end",
            "",
            "-- 3. The kit atlas: the first TextureID the importer uploaded, unless ATLAS is set.",
            "local atlas = uri(ATLAS)",
            "if atlas == \"\" then",
            "\tfor name, p in parts do",
            "\t\tlocal w = WANT[name]",
            "\t\tif w and w.atlas then",
            "\t\t\tif p.TextureID ~= \"\" then",
            "\t\t\t\tatlas = p.TextureID",
            "\t\t\t\tbreak",
            "\t\t\tend",
            "\t\t\tlocal sa = p:FindFirstChildOfClass(\"SurfaceAppearance\")",
            "\t\t\tlocal found = sa and sa.ColorMapContent.Uri",
            "\t\t\tif found and found ~= \"\" then",
            "\t\t\t\tatlas = found",
            "\t\t\t\tbreak",
            "\t\t\tend",
            "\t\tend",
            "\tend",
            "end",
            'print("Kit atlas texture:", atlas ~= "" and atlas or "NOT FOUND: upload assets/textures/EH_Palette_Bank.png, paste its id in ATLAS")',
            "",
            "-- 4. Same look on every piece, then check it.",
            "for name, w in WANT do",
            "\tlocal p = parts[name]",
            "\tif p == nil then",
            "\t\tproblems += 1",
            '\t\twarn("MISSING", name, "(import " .. w.model .. ".fbx)")',
            "\t\tcontinue",
            "\tend",
            '\tlocal model = p:FindFirstAncestorOfClass("Model")',
            "\tif model == nil or model.Name ~= w.model then",
            "\t\tproblems += 1",
            '\t\twarn("WRONG MODEL", p:GetFullName(), "belongs in the Model", w.model)',
            "\tend",
            "\tfor _, sa in p:GetChildren() do",
            "\t\tif sa:IsA(\"SurfaceAppearance\") and not w.texture then",
            "\t\t\tsa:Destroy()",
            "\t\tend",
            "\tend",
            "\tif w.texture then -- the hero SurfaceAppearance (vault combination face)",
            "\t\tlocal sa = p:FindFirstChildOfClass(\"SurfaceAppearance\") or Instance.new(\"SurfaceAppearance\")",
            "\t\tif DIALFACE_COLOR ~= \"\" then",
            "\t\t\tsa.ColorMapContent = Content.fromUri(uri(DIALFACE_COLOR))",
            "\t\tend",
            "\t\tif DIALFACE_ROUGHNESS ~= \"\" then",
            "\t\t\tsa.RoughnessMapContent = Content.fromUri(uri(DIALFACE_ROUGHNESS))",
            "\t\tend",
            "\t\tif DIALFACE_EMISSIVE ~= \"\" then",
            "\t\t\tsa.EmissiveMaskContent = Content.fromUri(uri(DIALFACE_EMISSIVE))",
            "\t\tend",
            "\t\tsa.EmissiveStrength = 2",
            f'\t\tsa.EmissiveTint = hex("{P.NEON["VaultDoor_DialRing"][0]}")',
            "\t\tsa.Parent = p",
            "\tend",
            "\tp.Material = Enum.Material[w.material]",
            "\tp.TextureID = if w.atlas then atlas else \"\"",
            "\tp.Color = if w.color then hex(w.color) else Color3.new(1, 1, 1)",
            "\tp.Transparency = w.transparency or 0",
            "\tp.Anchored = true",
            "\tp.CanCollide = w.canCollide",
            "\tp.CanTouch = w.canCollide",
            "\tp.CastShadow = w.castShadow",
            "\tlocal sizeOk = (p.Size - w.size).Magnitude < 0.05",
            "\tlocal nativeOk = (p.Size - p.MeshSize).Magnitude < 0.05",
            "\tlocal collOk = p.CollisionFidelity.Name == w.collision",
            "\tif not (sizeOk and nativeOk and collOk) then",
            "\t\tproblems += 1",
            "\tend",
            "\tprint(string.format(\"%-26s size %s %s | native %s | collision %s %s\", name, tostring(p.Size),",
            "\t\tsizeOk and \"ok\" or (\"WANT \" .. tostring(w.size)), nativeOk and \"ok\" or \"SCALED IN STUDIO\",",
            "\t\tp.CollisionFidelity.Name, collOk and \"ok\" or (\"SET TO \" .. w.collision)))",
            "end",
            "",
            "-- 5. Axis checks: the vault dial must sit on the front (-Z, the LookVector side) of the frame, and Gus's",
            "-- right hand (the torch) on +X (the RightVector side of a -Z-facing character).",
            "local frame, dial = parts.VaultDoor_Frame, parts.VaultDoor_Dial",
            "if frame and dial then",
            "\tprint(\"Vault front faces -Z:\", dial.Position.Z < frame.Position.Z and \"yes\" or \"NO, tell Claude (FBX axis)\")",
            "end",
            "local torso, torch = parts.Gus_UpperTorso, parts.Gus_Flashlight",
            "if torso and torch then",
            "\tprint(\"Gus torch on his right (+X):\", torch.Position.X > torso.Position.X and \"yes\" or \"NO, tell Claude (FBX X axis)\")",
            "end",
            "print(problems == 0 and \"KIT OK\" or (problems .. \" problem(s): fix them, then run again\"))",
            ""]
    return "\n".join(out)


# ---------------------------------------------------------------- write

def put(doc, name, body):
    pat = re.compile(rf"(<!-- {name}:start -->)\n.*?(<!-- {name}:end -->)", re.S)
    if not pat.search(doc):
        raise SystemExit(f"KIT_IMPORT.md has no {name} markers")
    return pat.sub(lambda m: m.group(1) + "\n" + body + "\n" + m.group(2), doc)


def main():
    man = load()
    levels = level_boxes()
    with open(DOC) as f:
        doc = f.read()
    doc = put(doc, "kit-table", table(man))
    doc = put(doc, "fit-table", fit_table(man, levels))
    doc = put(doc, "loot-table", loot_table(man, levels))
    doc = put(doc, "ornament-table", ornament_table(man))
    doc = put(doc, "fallback-cost", fallback_cost(man))
    with open(DOC, "w") as f:
        f.write(doc)
    with open(LUA, "w") as f:
        f.write(lua(man))
    print("kit docs:", os.path.relpath(DOC, REPO), os.path.relpath(LUA, REPO), os.path.relpath(LEVELS_CACHE, REPO))


if __name__ == "__main__":
    main()
