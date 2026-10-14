#!/usr/bin/env python3
"""build_traetoppen_json.py - writes data/traetoppen/traetoppen.json (package V3-levels) from the parsed sketch.

  tools/art/.venv/bin/python scripts/world2d/levels/source/build_traetoppen_json.py [--check]

Input   scripts/world2d/levels/source/v2_city_extract.json
        = the geometry parsed from the SVG of docs/Trætoppen Style Guide Review/Trætoppen Miljøer v2.dc.html (viewBox 1800 x 1240,
          sketch px; platforms, trunks, huts, bridges, ladder, lift, lanterns, door lamps, owl holes, bat houses, planters).
          Read-only copy of the design analysis file (design2/analysis/v2_env_scripts/v2_city_extract.json); the test section
          city_levels compares the shipped JSON against it (json_matches_extract_within_1px).
Output  data/traetoppen/traetoppen.json   (sketch px, header `scale` 3.0 = world px per sketch px)

Everything the extract does not hold is written HERE, once, with its source:
  * ranks / tuck order / bridge ids and from-to levels     design_v2.md 4.2 (the sketch's own painter order x 10)
  * the Raadhus (lavender hall, 14th building)            analysis/v2_environment.md 2.1 table and the SVG path of the hall
  * props, spawns, landmarks, lights, markers, stubs      design_v2.md 4.3 / 4.4 / 4.7 (positions read from the SVG where it draws them,
                                                          marked "design" where the design places them)
The script is deterministic: same extract -> same bytes. --check compares instead of writing (exit 1 on a difference).
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
SRC = os.path.join(HERE, "v2_city_extract.json")
OUT = os.path.join(ROOT, "data", "traetoppen", "traetoppen.json")

K = 3.0
RIM = 16.0                       # rim (skirt) thickness of every platform disc, sketch px (parsed: skirt thickness=16.0)
INSET = 0.96
FIRST_BIT = 12

# id, tree, rank, painted height z (analysis 2.1), index into extract["platforms"]
LEVELS = [
    ("a", "tree_hoppe", 10, 520, 0),
    ("b", "tree_post", 20, 470, 1),
    ("c", "tree_brumme", 70, 400, 2),
    ("torvet", "tree_torv", 80, 380, 3),
    ("upper", "tree_torv", 90, 560, 4),
    ("e", "tree_bad", 100, 420, 5),
    ("f", "tree_front_left", 150, 300, 6),
    ("g", "tree_kitchen", 160, 340, 7),
]
# trunk radii (sketch px) per platform: from the extract's trunk pairs (keyed by the tree's x)
TRUNK_KEY = {"a": "519", "b": "1281", "c": "276", "torvet": "900", "upper": "900", "e": "1524", "f": "588", "g": "1212"}

# bridges in the order of the SVG: id, from, to, rank, width class is parsed. design_v2.md 4.2 table.
BRIDGES = [
    ("b0", "a", "upper", 30), ("b1", "b", "upper", 40), ("b2", "a", "c", 50), ("b3", "b", "e", 60),
    ("b4", "c", "torvet", 110), ("b5", "e", "torvet", 120), ("b6", "f", "torvet", 130), ("b7", "g", "torvet", 140),
    ("b8", "f", "g", 170),
]
SAG = {"b0": 14, "b1": 14, "b2": 16, "b3": 16, "b4": 10, "b5": 10, "b6": 14, "b7": 14, "b8": 14}   # rope sag at mid span, sketch px

HUT_IDS = ["h1", "h2", "h3", "h4", "h5", "h6", "h7", "h8", "h9", "h10", "h11", "h12", "h13"]
# the 13 huts of the extract are in SVG order and sit on these levels (analysis 2.1 table H1..H13)
HUT_LEVEL = ["a", "a", "b", "b", "c", "c", "torvet", "torvet", "torvet", "e", "f", "f", "g"]
# pennant colour on the apex (analysis 2.1: pink Hoppe, blue Post, gold Raadhus, mint on hut G1) and chimney smoke
PENNANT = {"h1": "e58fa6", "h3": "6fa8e0", "raadhus": "f2c14e", "h13": "6fd6c4"}
SMOKE = ["h3", "h6", "h10"]


def _scalar(v):
    return not isinstance(v, (dict, list))


def dumps(v, ind=0):
    """compact deterministic JSON: scalars and short lists of numbers on one line, dictionaries one key per line"""
    pad = " " * (ind + 1)
    if isinstance(v, dict):
        if v and all(_scalar(x) or (isinstance(x, list) and all(_scalar(y) for y in x)) for x in v.values()) and len(json.dumps(v)) <= 110:
            return json.dumps(v, ensure_ascii=False, separators=(", ", ": "))
        items = ["%s%s: %s" % (pad, json.dumps(k, ensure_ascii=False), dumps(x, ind + 1)) for k, x in v.items()]
        return "{\n" + ",\n".join(items) + "\n" + " " * ind + "}"
    if isinstance(v, list):
        if all(_scalar(x) or (isinstance(x, list) and all(_scalar(y) for y in x)) for x in v) and len(json.dumps(v)) <= 110:
            return json.dumps(v, ensure_ascii=False, separators=(", ", ": "))
        items = [pad + dumps(x, ind + 1) for x in v]
        return "[\n" + ",\n".join(items) + "\n" + " " * ind + "]"
    return json.dumps(v, ensure_ascii=False)


def r1(v):
    return round(float(v) + 0.0, 1)


def pt(p):
    return [r1(p[0]), r1(p[1])]


def norm_r(level, p):
    """normalised radius of a point against the full ellipse of a level record"""
    cx, cy = level["centre"]
    return math.hypot((p[0] - cx) / level["rx"], (p[1] - cy) / level["ry"])


def main(argv):
    ex = json.load(open(SRC, encoding="utf-8"))
    plats = ex["platforms"]
    levels = []
    for i, (lid, tree, rank, z, pi) in enumerate(LEVELS):
        p = plats[pi]
        t = ex["trunks"][TRUNK_KEY[lid]][0]
        levels.append({
            "id": lid, "kind": "platform", "tree": tree, "rank": rank, "bit": FIRST_BIT + i, "z": z,
            "centre": [p["cx"], p["cy"]], "rx": p["rx"], "ry": p["ry"], "rim": RIM,
            "trunk": {"rx": t["rx"], "ry": t["ry"]},
            "walk": {"inset": INSET, "keepout": []},
        })
    by_id = {l["id"]: l for l in levels}

    def level_of(x, y):
        """the level whose ellipse holds the point (smallest normalised radius <= 1.15), like the extractor's platform_of"""
        best, bd = None, 9.9
        for l in levels:
            d = norm_r(l, (x, y))
            if d <= 1.15 and d < bd:
                best, bd = l["id"], d
        return best

    # ---- buildings: the 13 huts of the extract + the Raadhus
    buildings = []
    for i, h in enumerate(ex["huts"]):
        hid = HUT_IDS[i]
        b = {
            "id": hid, "level": HUT_LEVEL[i], "cx": r1(h["cx"]), "base_y": r1(h["base_y"]), "wall_r": h["wall_r"], "wall_h": h["wall_h"],
            "roof": {"fill": h["roof"]["fill"].lstrip("#"), "h": r1(h["roof"]["h"]), "rx": h["roof"]["rx"], "ry": h["roof"]["ry"]},
            "door": {"x": h["door"]["x"], "y": h["door"]["y"]},
            "occlude_fade": True,
        }
        if hid in PENNANT:
            b["pennant"] = PENNANT[hid]
        if hid in SMOKE:
            b["smoke"] = True
        buildings.append(b)
    buildings.append({
        "id": "raadhus", "level": "upper", "cx": 1002.9, "base_y": 449.1, "wall_r": 63.7, "wall_h": 52.0,
        "roof": {"fill": "9b86d6", "h": 88.0, "rx": 82.8, "ry": 47.8},
        "door": {"x": 993.0, "y": 480.0},          # design3 design_towns.md 4.1: the Raadhus door at sketch px (993, 480), level upper
        "pennant": PENNANT["raadhus"], "occlude_fade": True,
    })
    for b in buildings:
        assert b["level"] == level_of(b["cx"], b["base_y"] - 10) or b["id"] in ("raadhus",), (b["id"], level_of(b["cx"], b["base_y"] - 10))

    # ---- props (decor with a footprint): at = ground centre, keep = ground ellipse radii used as a keep-out + collider
    props = [
        {"id": "stall", "level": "torvet", "at": [702.1, 670.0], "keep": [44.0, 18.0], "art": "market_stall_traetoppen", "decor": True},
        {"id": "fire_pit", "level": "torvet", "at": [879.0, 735.4], "keep": [40.0, 20.0], "art": "fire_pit", "decor": True},
        {"id": "mailbox", "level": "b", "at": [1255.0, 309.1], "keep": [10.0, 6.0], "art": "mailbox_red", "decor": True},
        {"id": "log_stack", "level": "c", "at": [194.2, 666.0], "keep": [38.0, 18.0], "art": "log_stack", "decor": True},
        {"id": "bath_tub", "level": "e", "at": [1454.5, 635.9], "keep": [50.0, 25.0], "art": "bath_tub_back", "decor": True},
        {"id": "notice_board", "level": "upper", "at": [930.0, 520.0], "keep": [14.0, 8.0], "art": "notice_board", "decor": True},
        {"id": "seed_basket", "level": "a", "at": [437.0, 237.0], "keep": [12.0, 7.0], "art": "seed_basket", "decor": True, "source": "design"},
    ]
    for i, p in enumerate(ex["planters"]):
        props.append({"id": "planter%d" % (i + 1), "level": "g", "at": pt(p), "keep": [28.0, 14.0], "art": "planter_box", "decor": True})
    for p in props:
        assert p["level"] == level_of(p["at"][0], p["at"][1]) or p["id"] in ("notice_board", "seed_basket"), (p["id"], level_of(p["at"][0], p["at"][1]))

    # ---- keep-outs of the walk polygons (design 4.3: trunk circle, huts, stall, fire pit, the Upper deck shadow on the Torvet)
    for l in levels:
        ko = [{"circle": "trunk"}]
        if l["id"] == "torvet":
            ko.append({"ellipse": "upper_deck_shadow"})
        for b in buildings:
            if b["level"] == l["id"]:
                ko.append({"hut": b["id"]})
        for p in props:
            if p["level"] == l["id"]:
                ko.append({"prop": p["id"]})
        l["walk"]["keepout"] = ko

    # ---- bridges
    bridges = []
    for i, (bid, frm, to, rank) in enumerate(BRIDGES):
        s = ex["bridges"][i]
        ends = ["over" if rank > by_id[frm]["rank"] else "under", "over" if rank > by_id[to]["rank"] else "under"]
        bridges.append({
            "id": bid, "from": frm, "to": to, "rank": rank, "bit": FIRST_BIT + len(LEVELS) + i,
            "path": [pt(s["start"]), pt(s["end"])], "width": r1(s["width"]), "sag": SAG[bid],
            "ends": ends,
        })
        # the extract's bridge ends must lie on the two levels they join (inside the full ellipse)
        assert norm_r(by_id[frm], s["start"]) < 1.0, (bid, "start")
        assert norm_r(by_id[to], s["end"]) < 1.0, (bid, "end")

    # ---- stubs: the two bridge stubs that leave the map (farm on G's east rim, Hyggebyen on F's west rim). They are part of
    # the platform level they leave from (same rank and bit), so the player can stand on them and reach the warp at the end.
    by_id["g"]["stubs"] = [{
        "id": "farm_stub", "path": [[1390.0, 975.0], [1690.0, 1005.0]], "width": 44.0, "sag": 12,
        "exit": {"area": "farm", "spawn": "from_traetoppen", "label": "ZONE_FARM"},
    }]
    by_id["f"]["stubs"] = [{
        "id": "hyggebyen_stub", "path": [[430.0, 1018.0], [140.0, 1110.0]], "width": 44.0, "sag": 12,
        "exit": {"area": "hyggebyen", "spawn": "from_traetoppen", "label": "ZONE_CITY"},
    }]

    # ---- ladder (the extract: lane x 825.3-845.3, y 510.9-690.9) and the monkey's trunk climb
    ld = ex["ladders"][0]
    xm = (ld["x0"] + ld["x1"]) / 2.0
    ladders = [{"id": "main_ladder", "from": "torvet", "to": "upper", "lane": [[r1(xm), r1(ld["y_bottom"])], [r1(xm), r1(ld["y_top"])]],
                "width": ld["width"], "seconds": 1.1, "rungs": ld["rungs"], "prompt": "LEVEL_PROMPT_CLIMB"}]
    climb_zones = [{"id": "main_trunk_climb", "from": "torvet", "to": "upper", "a": [900.0, 712.0], "b": [900.0, 530.0], "r": 70.0,
                    "seconds": 1.1, "perk": "climb_speed_mult", "prompt": "LEVEL_PROMPT_CLIMB"}]

    # ---- rope lift (the basket on a 500 px rope at the rim of tree B)
    lf = ex["lift"]
    lifts = [{"id": "skovlift", "level": "b", "top": [lf["x"], lf["y_top"]], "basket": [lf["x"], lf["y_basket"]], "stand": [1388.0, 310.0],
              "to_area": "moerkeskoven", "spawn": "from_traetoppen", "seconds": 1.6, "prompt": "LEVEL_PROMPT_LIFT"}]

    # ---- lanterns and door lamps with their level (nearest by normalised radius, like the prototype)
    def nearest(x, y):
        best, bd = "a", 1e9
        for l in levels:
            d = norm_r(l, (x, y))
            if d < bd:
                best, bd = l["id"], d
        return best

    lanterns = [{"at": pt(p), "level": nearest(p[0], p[1])} for p in ex["lanterns"]]
    door_lamps = []
    for p in ex["door_lamps"]:
        # the lamp hangs beside the door of the nearest hut
        best = min(buildings, key=lambda b: math.hypot(b["door"]["x"] + 10.0 - p[0], b["door"]["y"] - p[1]))
        door_lamps.append({"at": pt(p), "level": best["level"], "building": best["id"]})
    assert len(lanterns) == 32 and len(door_lamps) == 14

    # ---- the at most 12 PointLight2D (the rest are additive halos); `at` is in sketch px, `r_px` is the light radius in WORLD px: fire pit, tub steam, post office and Raadhus door lamps,
    # one hanging lantern per platform (the one nearest to the platform centre)
    lights = [
        {"id": "fire_pit", "at": [879.0, 725.4], "r_px": 420.0, "color": "ffb35a", "energy": 0.9},
        {"id": "bath_steam", "at": [1454.5, 612.0], "r_px": 300.0, "color": "ffe0a0", "energy": 0.6},
        {"id": "post_door", "at": door_lamps[[d["building"] for d in door_lamps].index("h3")]["at"], "r_px": 300.0, "color": "ffd98a", "energy": 0.8},
        {"id": "raadhus_door", "at": door_lamps[[d["building"] for d in door_lamps].index("raadhus")]["at"] if "raadhus" in [d["building"] for d in door_lamps] else [955.0, 444.8], "r_px": 300.0, "color": "ffd98a", "energy": 0.8},
    ]
    for l in levels:
        cand = [q for q in lanterns if q["level"] == l["id"]]
        if not cand:
            continue
        q = min(cand, key=lambda q: math.hypot(q["at"][0] - l["centre"][0], q["at"][1] - l["centre"][1]))
        lights.append({"id": "lantern_" + l["id"], "at": q["at"], "r_px": 300.0, "color": "ffd98a", "energy": 0.8})
    assert len(lights) <= 12, len(lights)

    # ---- trunks: the visible segments. lower = below its platform down to the ground (drawn before the floor, rank-6),
    # upper = from the platform up out of the picture (drawn as an object with the platform's rank, pivot = platform centre)
    trunks = []
    names = {"519": "a", "1281": "b", "276": "c", "1524": "e", "588": "f", "1212": "g"}
    for key, segs in ex["trunks"].items():
        if key == "900":
            continue
        lid = names[key]
        lv = by_id[lid]
        low = [s for s in segs if s["y_top"] == lv["centre"][1] and s["y_bot"] > s["y_top"]][0]
        up = [s for s in segs if s["y_bot"] == lv["centre"][1]][0]
        trunks.append({"id": "t_%s_lower" % lid, "level": lid, "part": "lower", "cx": r1(low["cx"]), "y_top": low["y_top"], "y_bot": low["y_bot"],
                       "rx": low["rx"], "ry": low["ry"], "rank": lv["rank"] - 6})
        trunks.append({"id": "t_%s_upper" % lid, "level": lid, "part": "upper", "cx": r1(up["cx"]), "y_top": up["y_top"], "y_bot": up["y_bot"],
                       "rx": up["rx"], "ry": up["ry"], "rank": lv["rank"], "occlude_fade": True})
    tt = ex["trunks"]["900"]
    t_low = [s for s in tt if s["y_top"] == 630.0][0]
    t_mid = [s for s in tt if s["y_top"] == 450.0][0]
    t_up = [s for s in tt if s["y_top"] < 0][0]
    trunks.append({"id": "t_torvet_lower", "level": "torvet", "part": "lower", "cx": 900.0, "y_top": t_low["y_top"], "y_bot": t_low["y_bot"],
                   "rx": t_low["rx"], "ry": t_low["ry"], "rank": 74})
    trunks.append({"id": "t_torvet_upper", "level": "torvet", "part": "upper", "cx": 900.0, "y_top": t_mid["y_top"], "y_bot": t_mid["y_bot"],
                   "rx": t_mid["rx"], "ry": t_mid["ry"], "rank": 80, "occlude_fade": True})
    trunks.append({"id": "t_upper_upper", "level": "upper", "part": "upper", "cx": 900.0, "y_top": t_up["y_top"], "y_bot": t_up["y_bot"],
                   "rx": t_up["rx"], "ry": t_up["ry"], "rank": 90, "occlude_fade": True})

    # ---- decor with its own ranks (painter order: design_v2.md 4.2 "other ranks")
    owl_holes = [{"at": pt(p), "tree": "tree_hoppe" if i != 1 else "tree_post", "rank": 175} for i, p in enumerate(ex["owl_holes"])]
    # extract order is (A hole 1, B hole, A hole 2): A is the first tree of the design's "first owl hole" (Fru Ugle) -> sort A holes first
    owl_holes = [{"at": pt(ex["owl_holes"][0]), "tree": "tree_hoppe", "rank": 175},
                 {"at": pt(ex["owl_holes"][2]), "tree": "tree_hoppe", "rank": 175},
                 {"at": pt(ex["owl_holes"][1]), "tree": "tree_post", "rank": 175}]
    bat_houses = [{"cx": b["cx"], "y_top": b["y_top"], "tip_y": b["tip_y"], "w": b["w"], "rank": 180} for b in ex["bat_houses"]]
    foliage = [
        {"id": "foliage_f", "level": "f", "at": [588.2, 730.0], "rx": 136.0, "ry": 96.0, "rank": 155, "alpha": 0.5},
        {"id": "foliage_g", "level": "g", "at": [1211.8, 690.0], "rx": 136.0, "ry": 96.0, "rank": 165, "alpha": 0.5},
    ]

    spawns = {"default": [870.0, 700.0], "from_farm": [1385.0, 975.0], "from_hyggebyen": [430.0, 1018.0], "from_skovlift": [1380.0, 305.0]}

    landmarks = [
        {"n": 1, "id": "torvet", "level": "torvet", "circle": [900.0, 630.0, 230.0]},
        {"n": 2, "id": "raadhuset", "level": "upper", "circle": [1003.0, 470.0, 150.0]},
        {"n": 3, "id": "postkontoret", "level": "b", "circle": [1397.0, 265.0, 130.0]},
        {"n": 4, "id": "hoppes_hytte", "level": "a", "circle": [408.0, 215.0, 130.0]},
        {"n": 5, "id": "brummes_vaerksted", "level": "c", "circle": [190.0, 630.0, 150.0]},
        {"n": 6, "id": "badehuset", "level": "e", "circle": [1454.0, 620.0, 150.0]},
        {"n": 7, "id": "koekkenhaverne", "level": "g", "circle": [1164.0, 1042.0, 110.0]},
        {"n": 8, "id": "haengebroer", "level": "b8", "circle": [894.0, 990.0, 120.0]},
        {"n": 9, "id": "uglehulerne", "level": "b2", "circle": [399.0, 400.0, 150.0]},
        {"n": 10, "id": "flagermusenes_huse", "level": "e", "circle": [1525.0, 680.0, 150.0]},
    ]
    for lm in landmarks:
        lm["name_key"] = "TRAE_LANDMARK_%d" % lm["n"]

    # ---- markers V4 places (NPC slots and interactables). RT29: no `board`, `bath` or post-office `mailbox` marker here -
    # those handlers live inside the interiors of the towns track; the decor props above keep the sketch's art positions.
    markers = [
        {"type": "npc", "id": "gardener_hoppe", "at": [509.2, 203.2], "level": "a"},
        {"type": "npc", "id": "postman_pip", "at": [1420.0, 292.0], "level": "b"},
        {"type": "npc", "id": "carpenter_brumme", "at": [225.0, 640.0], "level": "c", "when": "flag:brumme_at_work"},
        {"type": "npc", "id": "carpenter_brumme", "at": [753.2, 590.3], "level": "torvet", "when": "flag:brumme_at_stall"},
        {"type": "npc", "id": "bathkeeper_sofus", "at": [1454.5, 600.0], "level": "e"},
        {"type": "npc", "id": "appraiser_fru_ugle", "at": [519.0, 380.0], "level": "a", "window": True, "reach": 420},
        {"type": "npc", "id": "guard_oak", "at": [1350.0, 298.0], "level": "b"},
        {"type": "seed_basket", "at": [437.0, 237.0], "level": "a"},
        {"type": "lift", "id": "skovlift", "at": [1388.0, 310.0], "level": "b"},
        {"type": "climb", "id": "main_ladder", "level": "torvet"},
    ]

    out = {
        "version": 1,
        "scale": K,
        "source": "docs/Trætoppen Style Guide Review/Trætoppen Miljøer v2.dc.html (viewBox 1800 x 1240) via scripts/world2d/levels/source/v2_city_extract.json",
        "bounds": [-200.0, 0.0, 2250.0, 1300.0],
        "zoom": {"default": 0.4, "min": 0.2, "max": 0.7},
        "body_radius": 25.0,
        "rim": RIM,
        "levels": levels,
        "bridges": bridges,
        "ladders": ladders,
        "climb_zones": climb_zones,
        "lifts": lifts,
        "buildings": buildings,
        "trunks": trunks,
        "props": props,
        "lanterns": lanterns,
        "door_lamps": door_lamps,
        "lights": lights,
        "owl_holes": owl_holes,
        "bat_houses": bat_houses,
        "foliage": foliage,
        "decor_ranks": {"lift_rope": 125, "foliage_f": 155, "foliage_g": 165, "owl_holes": 175, "bat_houses": 180},
        "spawns": spawns,
        "landmarks": landmarks,
        "markers": markers,
        "canopy": {"layer": 3},
    }
    text = dumps(out) + "\n"
    if "--check" in argv:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            print("build_traetoppen_json: %s differs from the generator output" % OUT)
            return 1
        print("build_traetoppen_json: %s is up to date" % OUT)
        return 0
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(text)
    print("build_traetoppen_json: wrote %s (%d bytes, %d levels, %d bridges, %d buildings, %d lights)" % (OUT, len(text), len(levels), len(bridges), len(buildings), len(lights)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
