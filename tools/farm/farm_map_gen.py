#!/usr/bin/env python3
"""farm_map_gen.py - generator of the treetop farm "Min Trækronsgård" (the authoring aid behind data/maps/farm.map, package N01).

AFTER LANDING THE MAP FILE IS AUTHORITATIVE AND HAND-EDITABLE. This generator is how the file came to be (design3 track N, lifted verbatim);
it is kept so a layout idea can be tried quickly, never as the source of truth: it does NOT write into the repo unless told to, and
`--check` tells whether the committed map still equals what the generator produces (a hand edit makes it differ: that is fine, then
the checker `check_farm_map.py` and the section `maps_farm` are the contract).

The layout is authored in LOCAL cell coordinates around the DOOR cell of the farmhouse, D = (0, 0):
  +x = screen lower-right, +y = screen lower-left (the house extends towards -y, its front faces +y).
  tier-10 footprint  x -4..4, y -5..0 (54 cells, home.json footprint_rect [-4.5,-6,4.5,0] relative to the door-centre anchor)
  base deck (stage 0) x -4..4, y -2..0   growth stage 1/2/3 = rows y -3 / -4 / -5 (void at start)
The generator shifts everything so that the map starts at (MARGIN, MARGIN) and writes farm.map + farm_facts.json + preview PNGs.

usage: farm_map_gen.py --check [MAP]    compare the generator's map text with MAP (default data/maps/farm.map); exit 1 when they differ
       farm_map_gen.py --out DIR        write DIR/farm.map, DIR/farm_facts.json, DIR/shift.json and the preview PNGs (needs Pillow)
       farm_map_gen.py --stdout         print the map text
The one editor's change to the lifted prototype (decision DT14): the bunting dress markers read `event=festival_now`.
"""
import json, math, os, sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

MARGIN = 3
G = {}        # (x, y) -> ground char (absent = void '#')
O = {}        # (x, y) -> object char
MARK = {}     # char -> marker dict
PROP = {}     # char -> prop dict
LABEL = {}    # (x, y) -> doc label
GROWTH = {1: [], 2: [], 3: []}
ZONES = {}    # name -> set of local cells
SPAWNS = {}   # name -> local cell
SLOTS = {}    # name -> (front cell, fx, fy)
KEYS = {}     # declaration key -> char
POOL = list("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789%&*+^$!?:;<>|~_")
FOOT = {}     # (x, y) of prop front cell -> (fx, fy) footprint of the prop (cells blocked)


def hsh(x, y, salt=0):
    n = ((x + 1000) * 73856093) ^ ((y + 1000) * 19349663) ^ ((salt + 7) * 83492791)
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def disc(cx, cy, rx, ry, ch, only_void=False, clip=None):
    cells = set()
    for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                if clip and not clip(x, y):
                    continue
                if only_void and (x, y) in G:
                    continue
                G[(x, y)] = ch
                cells.add((x, y))
    return cells


def rect(x0, y0, x1, y1, ch, only_void=False):
    cells = set()
    for x in range(min(x0, x1), max(x0, x1) + 1):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            if only_void and (x, y) in G:
                continue
            G[(x, y)] = ch
            cells.add((x, y))
    return cells


def hline(y, x0, x1, ch, only_void=False):
    return rect(x0, y, x1, y, ch, only_void)


def vline(x, y0, y1, ch, only_void=False):
    return rect(x, y0, x, y1, ch, only_void)


def obj(x, y, ch, name=None):
    if (x, y) in O and O[(x, y)] != ch:
        raise SystemExit("object collision at %s: %s vs %s" % ((x, y), O[(x, y)], ch))
    O[(x, y)] = ch
    if name:
        LABEL[(x, y)] = name


def _alloc(kind, d, pref=None):
    key = (kind, tuple(sorted(d.items())))
    if key in KEYS:
        return KEYS[key]
    ch = pref if (pref and pref not in MARK and pref not in PROP) else None
    if ch is None:
        for c in POOL:
            if c not in MARK and c not in PROP:
                ch = c
                break
    KEYS[key] = ch
    return ch


def put_marker(x, y, mtype, doc=None, pref=None, **kw):
    d = {"marker": mtype}
    d.update({k: str(v) for k, v in kw.items()})
    ch = _alloc("m", d, pref)
    MARK[ch] = d
    obj(x, y, ch, doc or mtype)
    return ch


def put_prop(x, y, art, doc=None, pref=None, foot=None, **kw):
    d = {"prop": art}
    d.update({k: str(v) for k, v in kw.items()})
    ch = _alloc("p", d, pref)
    PROP[ch] = d
    obj(x, y, ch, doc or art)
    if foot:
        FOOT[(x, y)] = foot
    return ch


def declare_marker_only(mtype, pref, **kw):
    """growth markers: declared without an object char in the rows (cells= only)."""
    d = {"marker": mtype}
    d.update({k: str(v) for k, v in kw.items()})
    assert pref not in MARK and pref not in PROP
    MARK[pref] = d
    return pref


# ===================================================================================================== the layout
def layout():
    # ------------------------------------------------------------ 1. the platform: limb + wings, one contiguous deck
    # (a) the house terrace (planks): flat NE rim at y = -2 at stage 0, growth rows y -3..-5 stay void until the house grows
    disc(0, 3, 10.5, 5.8, "d", clip=lambda x, y: y >= -2 and (y >= 1 or -4 <= x <= 8))
    rect(-4, -2, 8, 4, "d")                                 # no wing behind-left of the castle (its silhouette hides it)
    # (b) front yard lawn
    disc(0, 12, 15, 6.2, ".", only_void=True)
    # (c) west wing: the field lobe (F0 12 x 7 + fence ring + paths) and the pond lobe
    disc(-14, 12, 12.5, 7.8, ".", only_void=True)
    disc(-13, 22, 7.0, 5.5, ".", only_void=True)
    # (d) east wing: E1 (6 x 7) and the animal lobe
    disc(8, 12, 8.0, 7.8, ".", only_void=True)
    disc(14, 23, 8.8, 8.2, ".", only_void=True)
    # (e) boulevard to the foot + bridgehead (planks) + the hanging bridge
    rect(-3, 12, 3, 18, ".", only_void=True)
    disc(0, 20, 4.4, 3.4, "d")
    # (f) the orchard terrace (north-west satellite) joined by a plank bridge
    disc(-24, -5, 8.0, 7.2, ".")

    # ------------------------------------------------------------ 2. growth rows (void in @ground) + base reserve (planks)
    for st, y in ((1, -3), (2, -4), (3, -5)):
        for x in range(-4, 5):
            G.pop((x, y), None)
            GROWTH[st].append((x, y))
    for x in range(-4, 5):
        for y in range(-2, 1):
            G[(x, y)] = "d"

    # ------------------------------------------------------------ 3. field F0 (12 x 7), expansion E1 (6 x 7), pond
    ZONES["F0"] = rect(-19, 9, -8, 15, "f")                  # 84 tillable cells
    ZONES["E1"] = rect(5, 9, 10, 15, ".")                    # 42 cells, grass until bought (marker field_expansion lists them)
    ZONES["pond"] = disc(-13, 22, 4.6, 3.1, "~")

    # ------------------------------------------------------------ 4. paths (dirt) - nothing crosses the field blocks or the terrace
    vline(0, 9, 19, "p")                                      # the boulevard: terrace -> plaza -> bridgehead
    rect(-3, 10, 3, 11, "p")                                  # plaza
    hline(7, -21, -10, "p")                                   # north path of F0
    hline(17, -21, 3, "p")                                    # south path of F0 (to the boulevard)
    vline(-21, 7, 17, "p")                                    # west path of F0
    hline(7, 10, 12, "p")                                     # north path of E1
    hline(17, 3, 14, "p")                                     # south path of E1 towards the animals
    vline(12, 7, 17, "p")                                     # east path of E1
    vline(14, 17, 20, "p")                                    # into the animal yard
    # ------------------------------------------------------------ 5. bridges
    vline(0, 24, 32, "=")                                     # the hanging bridge to Traetoppen (9 planks, continues the boulevard)
    vline(-17, -1, 5, "=")                                    # the orchard bridge (7 planks)
    hline(-1, -23, -18, "p")                                  # path from the bridge landing to the trunk
    rect(-25, -3, -21, 0, "p")                                # the trunk plaza


layout()


# ===================================================================================================== objects and markers
def objects():
    # ---- growth rows: declared by markers, no object char needed (chars g h i are reserved first)
    declare_marker_only("growth", "g", stage=1, cells="-4..4,-3")
    declare_marker_only("growth", "h", stage=2, cells="-4..4,-4")
    declare_marker_only("growth", "i", stage=3, cells="-4..4,-5")
    # ---- the house: marker home at the DOOR-CENTRE cell, the tent beside it (outside the tier-10 rect)
    put_marker(0, 0, "home", "house door", pref="H")
    put_marker(8, 0, "tent", "tent (while building)", pref="t")                    # 2x2 front cell: x 7..8, y -1..0
    # ---- spawns
    SPAWNS["default"] = (1, 4)
    obj(1, 4, "@", "default spawn (intro)")
    put_marker(0, 2, "spawn", "from_home", name="from_home")
    SPAWNS["from_home"] = (0, 2)
    put_marker(0, 29, "spawn", "from_traetoppen", name="from_traetoppen")
    SPAWNS["from_traetoppen"] = (0, 29)
    # ---- the front: bed, mailbox, bin, shed, bench, lamps
    put_marker(-3, 2, "bed", "bed (door mat)", pref="B")
    put_marker(3, 2, "mailbox", "mailbox", pref="X", prop="mailbox_red")
    put_marker(-5, 4, "shipping_bin", "shipping bin", pref="K", prop="shipping_bin")      # 2 x 1: x -6..-5, y 4
    put_marker(7, 4, "tool_shed", "tool shed", pref="E", prop="tool_shed")                # 2 x 2: x 6..7, y 3..4
    put_prop(-5, 14, "bench", "bench", pref="N", foot=(2, 1))
    for (x, y) in ((-2, 6), (2, 6), (-3, 13), (3, 13)):
        put_prop(x, y, "lantern_post", "lantern post", pref="L")
    # ---- field F0: fence ring (north / south rows are fence cells, the paths run outside), gate towards the plaza
    for x in range(-20, -7):
        put_prop(x, 8, "fence_x", "fence F0 north", pref="F")
        put_prop(x, 16, "fence_x", "fence F0 south", pref="F")
    for y in range(9, 16):
        put_prop(-20, y, "fence_z", "fence F0 west", pref="Z")
    for y in range(8, 17):
        if y == 12:
            put_prop(-7, y, "fence_gate_x", "gate F0 east", pref="G")
        else:
            put_prop(-7, y, "fence_z", "fence F0 east", pref="Z")
    put_prop(-6, 10, "scarecrow", "scarecrow", pref="S")
    # ---- field expansion E1 (zone cells + stake sign on its west edge) - the handler adds the rope ring while locked
    put_marker(4, 12, "field_expansion", "stake sign E1", pref="x", id="east", cells="5..10,9..15", price="800")
    # ---- orchard: 3 apple trees, a sign, a bench, the trunk, tree hollow (loot) and the forest sign (the Skovport is removed by the reconciled v2 design)
    for (x, y) in ((-20, -6), (-18, -3), (-26, 1)):
        put_marker(x, y, "node", "apple tree", pref="A", kind="apple_tree")
    put_marker(-21, -2, "sign", "orchard sign", pref="s", text="SIGN_ORCHARD")
    put_prop(-27, -1, "bench", "orchard bench", pref="N", foot=(2, 1))
    put_marker(-23, -2, "unique_spot", "tree hollow (trae_hulning)", pref="v", id="trae_hulning")
    put_marker(-23, 2, "sign", "forest sign (where the Skovport was)", pref="j", text="SIGN_FARM_FOREST")
    put_prop(-23, -4, "trunk_giant_b", "orchard trunk (solid)", pref="Q", foot=(3, 3))
    # the great trunk behind the house (void cells north of the tier-10 rect, footprint 5 x 3 centred on the door column)
    put_prop(2, -6, "trunk_giant_a", "trunk behind the house", pref="R", foot=(5, 3))
    # ---- the pillars under the deck (z -11, below the skirts): the platform stands on trunks
    put_marker(-3, 15, "underdeck", "pillar under the yard", pref="1", prop="trunk_under_a")
    put_marker(15, 26, "underdeck", "pillar under the animals", pref="2", prop="trunk_under_b")
    put_marker(-13, 24, "underdeck", "pillar under the pond", pref="3", prop="trunk_under_b")
    # ---- loot markers (F1 data/features/map_markers.json: 2 dig spots + 2 unique spots on the farm)
    put_marker(-23, 12, "dig_spot", "dig spot 1", pref="z")
    put_marker(17, 17, "dig_spot", "dig spot 2", pref="z")
    put_marker(9, 3, "unique_spot", "birdhouse (fuglehuset)", pref="u", id="fuglehuset")
    # ---- resource nodes
    put_marker(-28, 0, "node", "chop tree", pref="k", kind="tree_chop")
    put_marker(-19, 0, "node", "chop tree", pref="k", kind="tree_chop")
    put_marker(20, 19, "node", "stone", pref="o", kind="rock_stone")
    put_marker(-18, 21, "node", "stone", pref="o", kind="rock_stone")
    put_marker(-21, -4, "node", "flower patch", pref="w", kind="flower_patch")
    # ---- animals: yard + three building slots (front cells; footprints coop 3x2, barn 4x3, animal house 3x2)
    put_marker(14, 24, "animal_yard", "animal yard", pref="a", r="3")
    put_marker(13, 20, "building_slot", "coop slot", pref="c", type="coop")
    SLOTS["coop"] = ((13, 20), 3, 2)
    put_marker(21, 25, "building_slot", "barn slot", pref="d", type="barn")
    SLOTS["barn"] = ((21, 25), 4, 3)
    put_marker(12, 30, "building_slot", "animal house slot", pref="e", type="house")
    SLOTS["house"] = ((12, 30), 3, 2)
    # EXTENDED hook (package N07, a greenhouse for winter crops): a reserved 4 x 3 footprint, data marker only (no handler until N07 lands)
    put_marker(10, 25, "greenhouse_slot", "greenhouse slot (reserved)", pref="G")
    SLOTS["greenhouse"] = ((10, 25), 4, 3)
    # ---- bridge: warp at the last plank, paw prints, lights, signs
    put_marker(0, 32, "warp", "bridge warp", pref="W", to="traetoppen", spawn="from_farm", label="ZONE_TRAETOPPEN")
    put_marker(0, 27, "quest_spot", "paw prints", pref="q", quest="lost_cat", objective="follow_pawprints", prompt="WORLD_PROMPT_USE",
               prop="paw_prints", when="quest:lost_cat")
    put_marker(0, 25, "light", "bridge lantern", pref="l", kind="lantern", r="240", h="70")
    put_marker(0, 30, "light", "bridge lantern", pref="l", kind="lantern", r="240", h="70")
    put_marker(3, 19, "sign", "bridge sign", pref="n", text="SIGN_FARM_BRIDGE")
    put_prop(-2, 18, "lantern_post", "lantern post", pref="L")
    put_prop(2, 18, "lantern_post", "lantern post", pref="L")
    put_prop(-21, 6, "lantern_post", "lantern post", pref="L")
    put_prop(12, 6, "lantern_post", "lantern post", pref="L")
    put_marker(-22, -1, "light", "orchard glow", pref="m", kind="lantern", r="260", h="60")
    # ---- NPC / visitor posts (data markers; the NPC director of the social track reads them with find_markers("post"))
    for (x, y, nm, fac, act) in ((4, 3, "pip_mailbox", "SW", "stand"), (-22, 12, "hoppe_fence", "E", "stand"), (-5, 15, "bench_a", "SW", "sit"),
                                 (5, 2, "porch", "SW", "stand"), (-18, 6, "field_edge", "S", "stand")):
        put_marker(x, y, "post", "post " + nm, name=nm, facing=fac, act=act)
    # the anchor of the towns track's director (one per map): it places the citizens whose routine post is on this map (Pip at pip_mailbox ...)
    put_marker(3, 10, "town", "town director anchor (towns track)", pref="T", curfew="false")
    # ---- ambient fx (one per map: canopy frame, leaves, fireflies by season)
    put_marker(10, 2, "ambient_fx", "ambient fx", kind="auto")
    # ---- dress markers (handler N02): props that appear with the home tier (the estate grows), the season or a town festival
    for (x, y, nm, kw) in (
            (-2, 1, "porch flower box W", dict(tier=3, prop="flower_box")),
            (2, 1, "porch flower box E", dict(tier=3, prop="flower_box")),
            (0, 9, "garden arch over the path", dict(tier=5, prop="garden_arch")),
            (-4, 13, "plaza fountain", dict(tier=8, prop="fountain_small")),
            (-5, 6, "banner W", dict(tier=10, prop="royal_banner")),
            (5, 6, "banner E", dict(tier=10, prop="royal_banner")),
            (-11, 5, "spring blossoms", dict(season="foraar", prop="blossom_cluster")),
            (9, 6, "spring blossoms", dict(season="foraar", prop="blossom_cluster")),
            (-8, 18, "sunflower row", dict(season="sommer", prop="sunflower_row")),
            (4, 18, "sunflower row", dict(season="sommer", prop="sunflower_row")),
            (6, 8, "leaf pile", dict(season="efteraar", prop="leaf_pile")),
            (-9, 7, "pumpkin stack", dict(season="efteraar", prop="pumpkin_stack")),
            (6, 6, "snow patch", dict(season="vinter", prop="snow_patch")),
            (-3, 8, "snow patch", dict(season="vinter", prop="snow_patch")),
            (-1, 12, "bunting over the plaza", dict(event="festival_now", prop="bunting_x")),
            (1, 12, "bunting over the plaza", dict(event="festival_now", prop="bunting_x"))):
        put_marker(x, y, "dress", nm, **kw)
    deco()


def reserved(x, y):
    if -9 <= x <= 9 and -9 <= y <= 2:
        return True
    if (x, y) in O:
        return True
    for z in ("F0", "E1", "pond"):
        if (x, y) in ZONES[z]:
            return True
    ch = G.get((x, y), "#")
    if ch in "pf~=#d":
        return True
    for nm, (front, fx, fy) in SLOTS.items():
        if front[0] - fx <= x <= front[0] + 1 and front[1] - fy <= y <= front[1] + 1:
            return True
    for (px, py), (fx, fy) in FOOT.items():
        if px - fx <= x <= px + 1 and py - fy <= y <= py + 1:
            return True
    return False


def deco():
    cells = sorted(c for c in G if G[c] == ".")
    for (x, y) in cells:
        if reserved(x, y):
            continue
        near_path = any(G.get((x + dx, y + dy)) in ("p", "f", "=") for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2))
        rim = any(G.get((x + dx, y + dy), "#") == "#" for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1)))
        h = hsh(x, y, 3)
        if rim and not near_path and h < 0.16:
            art = "tree_oak_farm" if h < 0.07 else ("tree_oak_farm_b" if h < 0.11 else "bush_farm")
            put_prop(x, y, art, art, pref={"tree_oak_farm": "T", "tree_oak_farm_b": "U", "bush_farm": "b"}[art])
        elif not near_path and not rim and h > 0.965:
            put_prop(x, y, "rock_grey", "rock", pref="r")
        elif not near_path and h > 0.90 and G[(x, y)] == ".":
            G[(x, y)] = "," if h < 0.95 else ";"


objects()

# ground flowers on lawns (never inside the home reserve, never in E1)
for (x, y), ch in list(G.items()):
    if ch == "." and (x, y) not in O and not (-9 <= x <= 9 and -9 <= y <= 2) and (x, y) not in ZONES["E1"]:
        if hsh(x, y, 11) > 0.93:
            G[(x, y)] = "," if hsh(x, y, 12) < 0.5 else ";"


# ===================================================================================================== output
def finalize(shift_margin=MARGIN):
    xs = [c[0] for c in G if G[c] != "#"]
    ys = [c[1] for c in G if G[c] != "#"]
    for c in O:
        xs.append(c[0]); ys.append(c[1])
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    dx, dy = shift_margin - x0, shift_margin - y0
    W, H = x1 - x0 + 1 + 2 * shift_margin, y1 - y0 + 1 + 2 * shift_margin
    g_rows, o_rows = [], []
    for y in range(H):
        gr, orow = "", ""
        for x in range(W):
            lx, ly = x - dx, y - dy
            gr += G.get((lx, ly), "#")
            orow += O.get((lx, ly), ".")
        g_rows.append(gr)
        o_rows.append(orow)
    return W, H, dx, dy, g_rows, o_rows


def shift_cells_text(text, dx, dy):
    out = []
    for part in text.split(";"):
        xs, ys = part.split(",")
        def sh(t, d):
            if ".." in t:
                a, b = t.split("..")
                return "%d..%d" % (int(a) + d, int(b) + d)
            return str(int(t) + d)
        out.append("%s,%s" % (sh(xs, dx), sh(ys, dy)))
    return ";".join(out)


HEADER = """# data/maps/farm.map - "Min Trækronsgård" (the player's treetop farm). PROTOTYPE of design3 track N (generated by gen_farm_map.py).
# Orientation (layout DIAMOND_DOWN): text COLUMNS run toward screen lower-RIGHT (+x), text ROWS toward screen lower-LEFT (+y);
# top-left char = NORTH corner, top-right = EAST, bottom-right = SOUTH, bottom-left = WEST.
# The farmhouse stands against the great trunk at the north-east rim; its door cell carries marker H (home). Reserve (tier 10 = 9 x 6):
# base deck x D-4..D+4, y D-2..D, growth rows y D-3 / D-4 / D-5 are VOID here and turn into deck with set_growth_stage(1..3).
@id farm
@title ZONE_FARM
@projection iso
@ambient farm
@theme farm
@zone farm
@flight true
@music farm_theme"""


def map_text(dx, dy, g_rows, o_rows):
    """The text of data/maps/farm.map for the generated layout."""
    lines = [HEADER]
    lines.append("# props: object char -> ART id (collision, strips and lights come from lua/config/props.lua + props_extra.lua)")
    for ch in sorted(PROP):
        d = PROP[ch]
        extra = " ".join("%s=%s" % (k, v) for k, v in d.items() if k != "prop")
        lines.append(("@prop %s %s %s" % (ch, d["prop"], extra)).rstrip())
    lines.append("# markers: spawn warp sign bed quest_spot light growth are built in; every other type is resolved by the handler registry")
    lines.append("# (a type without a handler script yet is skipped silently and stays readable through area.find_markers(type))")
    for ch in sorted(MARK, key=lambda c: (MARK[c]["marker"], c)):
        d = dict(MARK[ch])
        parts = []
        for k, v in d.items():
            if k == "marker":
                continue
            if k == "cells":
                v = shift_cells_text(v, dx, dy)
            parts.append("%s=%s" % (k, v))
        lines.append(("@marker %s %s %s" % (ch, d["marker"], " ".join(parts))).rstrip())
    lines.append("@ground")
    lines.extend(g_rows)
    lines.append("@objects")
    lines.extend(o_rows)
    return "\n".join(lines) + "\n"


def write_map(path, W, H, dx, dy, g_rows, o_rows):
    with open(path, "w", encoding="utf-8") as f:
        f.write(map_text(dx, dy, g_rows, o_rows))


def facts(W, H, dx, dy, g_rows, o_rows):
    """Everything the doc quotes: counts, zones, lengths, reserve geometry, validation findings."""
    F = {"size": [W, H], "non_void": sum(1 for r in g_rows for ch in r if ch != "#"), "ground_counts": {}, "shift": [dx, dy]}
    for r in g_rows:
        for ch in r:
            F["ground_counts"][ch] = F["ground_counts"].get(ch, 0) + 1
    F["door"] = [dx, dy]
    F["zones"] = {k: len(v) for k, v in ZONES.items()}
    F["markers"] = {}
    for (x, y), ch in O.items():
        t = MARK[ch]["marker"] if ch in MARK else ("prop:" + PROP[ch]["prop"] if ch in PROP else "spawn@")
        F["markers"][t] = F["markers"].get(t, 0) + 1
    # findings: object chars on void cells (allowed: the trunks and the tent only), props overlapping footprints
    off = []
    for (x, y), ch in O.items():
        if G.get((x, y), "#") == "#":
            nm = MARK[ch]["marker"] if ch in MARK else (PROP[ch]["prop"] if ch in PROP else "@")
            if nm not in ("trunk_giant_a", "trunk_giant_b", "tent"):
                off.append([nm, x + dx, y + dy])
    F["objects_on_void"] = off
    # v rows: distance of every interactive marker to the top of the map (the canopy frame band) in anti-diagonals
    vtop = min(x + y for (x, y), c in G.items() if c != "#")
    F["v_top_local"] = vtop
    inter = ("node", "sign", "bed", "mailbox", "shipping_bin", "tool_shed", "warp", "field_expansion", "dig_spot", "unique_spot", "quest_spot", "animal_yard", "building_slot")
    close = []
    for (x, y), ch in O.items():
        if ch in MARK and MARK[ch]["marker"] in inter and (x + y) - vtop < 8:
            close.append([MARK[ch]["marker"], x, y, (x + y) - vtop])
    F["interactives_within_8_rows_of_the_top"] = close
    F["lights"] = sum(1 for (x, y), ch in O.items() if (ch in PROP and PROP[ch]["prop"] == "lantern_post") or (ch in MARK and MARK[ch]["marker"] == "light"))
    return F


def main(argv):
    out_dir, check, to_stdout, check_path = None, False, False, os.path.join(REPO, "data", "maps", "farm.map")
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--out" and i + 1 < len(argv):
            out_dir = argv[i + 1]
            i += 1
        elif a == "--check":
            check = True
            if i + 1 < len(argv) and not argv[i + 1].startswith("--"):
                check_path = argv[i + 1]
                i += 1
        elif a == "--stdout":
            to_stdout = True
        else:
            print(__doc__)
            return 2
        i += 1
    if not (out_dir or check or to_stdout):
        check = True                      # the harmless default: compare, write nothing
    W, H, dx, dy, g_rows, o_rows = finalize()
    text = map_text(dx, dy, g_rows, o_rows)
    if to_stdout:
        sys.stdout.write(text)
    rc = 0
    if check:
        with open(check_path, encoding="utf-8") as f:
            have = f.read()
        if have == text:
            print("OK: %s equals the generator output (%d x %d cells, %d non-void)" % (os.path.relpath(check_path, REPO), W, H, sum(1 for r in g_rows for ch in r if ch != "#")))
        else:
            hl, gl = have.splitlines(), text.splitlines()
            diff = [i + 1 for i in range(max(len(hl), len(gl))) if (hl[i] if i < len(hl) else None) != (gl[i] if i < len(gl) else None)]
            print("DIFFERENT: %s differs from the generator output in %d line(s), first at line %s (a hand edit of the authoritative file is allowed;"
                  " run check_farm_map.py for the contract)" % (os.path.relpath(check_path, REPO), len(diff), diff[0] if diff else "?"))
            rc = 1
    if out_dir:
        from farm_preview import render
        os.makedirs(out_dir, exist_ok=True)
        write_map(os.path.join(out_dir, "farm.map"), W, H, dx, dy, g_rows, o_rows)
        print("map size", W, "x", H, "shift", dx, dy)
        print("non-void cells", sum(1 for r in g_rows for ch in r if ch not in "#"))
        gc = {}
        for st, cells in GROWTH.items():
            for (x, y) in cells:
                gc[(x + dx, y + dy)] = st
        spawn = (SPAWNS["default"][0] + dx, SPAWNS["default"][1] + dy)
        render(g_rows, o_rows, MARK, PROP, scale=0.2, path=os.path.join(out_dir, "preview_layout.png"), growth_cells=gc,
               reserve=(-4 + dx, -5 + dy, 4 + dx, 0 + dy),
               view_boxes=[(spawn[0], spawn[1], 3200, 1800, (200, 0, 200, 255)), (spawn[0], spawn[1], 4267, 2400, (0, 120, 200, 255))],
               silhouette=(dx, dy, 281, 669, 1135))
        with open(os.path.join(out_dir, "shift.json"), "w") as f:
            json.dump({"W": W, "H": H, "dx": dx, "dy": dy}, f)
        F = facts(W, H, dx, dy, g_rows, o_rows)
        with open(os.path.join(out_dir, "farm_facts.json"), "w") as f:
            json.dump(F, f, indent=1)
        print(json.dumps({k: F[k] for k in ("size", "non_void", "zones", "objects_on_void", "interactives_within_8_rows_of_the_top", "lights")}))
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
