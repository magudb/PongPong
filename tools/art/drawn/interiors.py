#!/usr/bin/env python3
"""Export saved painted masters as modular room art and data-only furnishing studies.

The native camera, tile geometry and home floor plans remain the project's data.
This is the deterministic packing/projection stage; imagegen supplies the paintings.
"""
from __future__ import annotations

import copy
import json
import math
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

from pack import extract, project_building, building_footprint, TILE_W, TILE_H
from terrain import ROOT, HERE

OUT = ROOT / "assets/iso_props/painted_interiors"
DATA = ROOT / "assets/data/interiors/painted.json"
SOURCE = "tools/art/drawn/sources/"
PRESET = '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=2\ncompress/high_quality=false\nmipmaps/generate=true\nprocess/fix_alpha_border=true\n'

# Row-major names and floor footprints. Only the authored front view is claimed;
# these fixed room studies do not stand in for a four-rotation furniture pack.
DOMESTIC = [
    ("bed_patch", 1, 2), ("bed_oak", 2, 3), ("table_tea", 1, 1), ("chair_cottage", 1, 1),
    ("sofa_sage", 2, 1), ("hearth_cottage", 1, 1), ("kitchen_hutch", 2, 1), ("bookcase_cottage", 1, 1),
    ("wardrobe_cottage", 1, 1), ("chest_cottage", 1, 1), ("plant_cottage", 1, 1), ("loom_cottage", 1, 1),
]
SHOPS = [
    ("counter_pine", 3, 1), ("counter_end", 1, 1), ("counter_hatch", 1, 1), ("sign_bracket", 0, 0),
    ("brick_oven", 2, 1), ("bread_rack", 1, 1), ("anvil", 1, 1), ("forge", 2, 1),
    ("cauldron_stand", 1, 1), ("hay_bale", 1, 1), ("feed_sack_stack", 1, 1), ("plank_stack", 2, 1),
    ("workbench", 2, 1), ("mannequin", 1, 1), ("pigeonhole_wall", 2, 1), ("mail_sack", 1, 1),
    ("parcel_stack", 1, 1), ("letter_desk", 1, 1), ("wooden_tub", 2, 2), ("notice_board_indoor", 2, 1),
]
REGAL = [
    ("bed_canopy", 2, 3), ("table_manor", 3, 1), ("chair_manor", 1, 1), ("piano_manor", 2, 1),
    ("bookcase_manor", 2, 1), ("hearth_manor", 2, 1), ("throne_leaf", 1, 1), ("chandelier_leaf", 0, 0),
]
DRESSING = [("rug_braid", 0, 0), ("rug_sprig", 0, 0), ("rug_manor", 0, 0), ("wall_lantern", 0, 0),
            ("picture_leaf", 0, 0), ("seed_display", 2, 1), ("potion_shelf", 1, 1), ("fabric_rack", 2, 1),
            ("flowers_cottage", 1, 1), ("table_coffee", 1, 1), ("armchair_sage", 1, 1), ("herb_shelf", 0, 0)]
# Visually measured ground-plane junctions in the extracted paintings, L/front/R.
PLANES = {"counter_pine": [[.02, .76], [.80, .99], [.98, .80]],
          "counter_end": [[.02, .78], [.68, .99], [.98, .78]],
          "counter_hatch": [[.06, .72], [.93, .98], [.98, .90]],
          "brick_oven": [[.04, .83], [.75, .99], [.97, .80]],
          "workbench": [[.03, .83], [.76, .99], [.96, .83]]}
EMBLEMS = ["seed", "bakery", "smith", "animal", "magic", "furniture", "tailor", "timber", "flea", "post", "bath", "hall", "owl", "carpenter", "home"]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def export(name: str, image: Image.Image, record: dict, source: str, manifest: dict) -> None:
    image.save(OUT / (name + ".webp"), lossless=True, method=4, exact=True)
    preset = OUT / (name + ".webp.import")
    if not preset.exists():
        preset.write_text(PRESET)
    manifest[name] = dict(record, file=name + ".webp", size=list(image.size), illustration=SOURCE + source)


def furniture(manifest: dict) -> None:
    for sheet, rows, cols, entries in [("domestic", 3, 4, DOMESTIC), ("shops", 4, 5, SHOPS), ("regal", 2, 4, REGAL), ("dressing", 3, 4, DRESSING)]:
        paintings = extract(HERE / f"sources/interior_{sheet}.png", rows, cols)
        for (name, fx, fy), drawing in zip(entries, paintings, strict=True):
            image = drawing.copy()
            image.putalpha(image.getchannel("A").point(lambda a: 255 if a >= 240 else (a if a > 16 else 0)))
            width = round((fx + fy) * TILE_W * .5 * (.96 if name.startswith("counter") else .90)) if fx else 116
            image.thumbnail((width, 360), Image.Resampling.LANCZOS)
            # The footprint centre sits half a floor diamond behind the frontmost foot.
            pivot = [image.width / 2, image.height - max(6, (fx + fy) * 15)]
            if name == "chandelier_leaf":
                pivot = [image.width / 2, 0]
            if name in PLANES:
                image, pivot = project_building(drawing, PLANES[name], building_footprint(fx, fy))
            record = {"pivot": pivot, "footprint": [fx, fy], "view": "front_right",
                      "layer": "ceiling" if name == "chandelier_leaf" else ("wall" if fx == 0 else "floor")}
            if name in PLANES:
                record["source_ground_planes"] = PLANES[name]
            if name.startswith("rug_"):
                span = (2, 2) if name == "rug_braid" else (3, 2)
                image = ground_decal(drawing, *span)
                record.update(pivot=[image.width / 2, image.height / 2], ground_span=list(span), layer="ground")
            elif name in ["wall_lantern", "picture_leaf", "herb_shelf"]:
                image.thumbnail({"wall_lantern": (46, 84), "picture_leaf": (62, 82), "herb_shelf": (116, 100)}[name], Image.Resampling.LANCZOS)
                record["pivot"] = [image.width / 2, image.height / 2]
            export(name, image, record,
                   f"interior_{sheet}.png", manifest)
    for name, drawing in zip(EMBLEMS, extract(HERE / "sources/interior_emblems.png", 3, 5), strict=True):
        image = drawing.copy()
        image.putalpha(image.getchannel("A").point(lambda a: 255 if a >= 240 else (a if a > 16 else 0)))
        image.thumbnail((80, 80), Image.Resampling.LANCZOS)
        export("emblem_" + name, image, {"pivot": [image.width / 2, image.height / 2], "footprint": [0, 0], "layer": "wall"},
               "interior_emblems.png", manifest)


def ground_decal(drawing: Image.Image, fx: int, fy: int) -> Image.Image:
    """Project flat painted textile into the native floor plane without a collider."""
    w, h = round((fx + fy) * TILE_W / 2), round((fx + fy) * TILE_H / 2)
    a, b = drawing.width / (TILE_W * fx), drawing.width / (TILE_H * fx)
    d, e = -drawing.height / (TILE_W * fy), drawing.height / (TILE_H * fy)
    return drawing.transform((w, h), Image.Transform.AFFINE,
                             (a, b, drawing.width / 2 - a * w / 2 - b * h / 2,
                              d, e, drawing.height / 2 - d * w / 2 - e * h / 2), Image.Resampling.BICUBIC)


def wall_panel(drawing: Image.Image, record: dict, rotation: int) -> Image.Image:
    """Affine projection of a flat painted panel onto exactly one existing tile edge."""
    w, h = record["size"]
    px, py = record["pivot"]
    height = float(record["height_m"]) * 87.074 * math.cos(math.radians(36))
    raw = drawing.crop((5, 4, drawing.width - 5, drawing.height - 4)).resize((256, 512), Image.Resampling.LANCZOS)
    # Both orientations share the same native tile-edge centre.
    direction = 1 if rotation == 0 else -1
    sx, slope = 256.0 / (TILE_W * .5), TILE_H / TILE_W
    coeff = (sx, 0.0, (TILE_W * .25 - px) * sx,
             direction * slope * 512.0 / height, -512.0 / height,
             (py - direction * slope * px) * 512.0 / height)
    # Mapping above samples v from bottom to top; flip the master so its ceiling stays above its skirting.
    return ImageOps.flip(raw).transform((w, h), Image.Transform.AFFINE, coeff, Image.Resampling.BICUBIC)


def walls(manifest: dict) -> None:
    paintings = extract(HERE / "sources/interior_walls.png", 2, 4)
    path = ROOT / "assets/iso_props/interior/interior.json"
    original = load(path)
    material_index = {"plank": 0, "plaster": 1, "paper": 2, "marble": 3}
    for style, index in material_index.items():
        template = "plank" if style == "plaster" else style
        for kind in ["a", "b", "win"]:
            for rotation in [0, 1]:
                name = f"wall_{style}_{kind}_r{rotation}"
                rec = copy.deepcopy(original["walls"][f"wall_{template}_{kind}_r{rotation}"])
                drawing = paintings[index + (4 if kind == "win" else 0)]
                image = wall_panel(drawing, rec, rotation)
                if kind == "win":
                    pixels = np.asarray(image).astype(float)
                    glass = (pixels[:, :, 2] > pixels[:, :, 0] + 9) & (pixels[:, :, 1] > pixels[:, :, 0] + 6)
                    light = Image.new("RGBA", image.size, (255, 173, 74, 0))
                    light.putalpha(Image.fromarray(np.uint8(glass * pixels[:, :, 3] * .35)))
                    export(name + "_night", light, {"pivot": rec["pivot"], "footprint": [0, 0], "blend": "add"}, "interior_walls.png", manifest)
                    rec["night"] = name + "_night.webp"
                export(name, image, dict(rec, footprint=[0, 0]), "interior_walls.png", manifest)
        # Preserve the narrow corner's authored silhouette while sampling its new painted material.
        name = "corner_" + style
        rec = copy.deepcopy(original["walls"]["corner_" + template])
        old = Image.open(path.parent / ("corner_" + template + ".webp")).convert("RGBA")
        image = paintings[index].crop((6, 5, 35, paintings[index].height - 5)).resize(old.size, Image.Resampling.LANCZOS)
        image.putalpha(old.getchannel("A"))
        export(name, image, dict(rec, footprint=[0, 0]), "interior_walls.png", manifest)
    # Existing consumers get painted shells without a new runtime interface or altered pivots.
    for name, rec in original["walls"].items():
        rec["file"] = "../painted_interiors/" + name + ".webp"
        rec["illustration"] = SOURCE + "interior_walls.png"
        if "night" in rec:
            rec["night"] = "../painted_interiors/" + name + "_night.webp"
    path.write_text(json.dumps(original, indent=1) + "\n")


def occupied(item: dict, manifest: dict) -> set[tuple[int, int]]:
    x, y = item["cell"]
    fx, fy = manifest[item["asset"]]["footprint"]
    return {(x + i, y + j) for i in range(fx) for j in range(fy)}


def connected(cells: set, start: tuple) -> bool:
    seen = {start}
    todo = deque([start])
    while todo:
        x, y = todo.popleft()
        for q in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]:
            if q in cells and q not in seen:
                seen.add(q)
                todo.append(q)
    return seen == cells


def furnish(room: dict, assets: list[str], manifest: dict, staff: bool = False) -> None:
    """Place studies without blocking the entrance, counter approaches or any public floor."""
    cells = {tuple(c) for c in room["cells"]}
    free = cells.copy()
    door = tuple(room["door"]["cell"])
    middle = door[0]
    reserved = {(x, y) for x, y in cells if x == middle or (y >= 2 and x == middle + 1)}
    room["items"] = []
    if staff:
        barrier = {(x, 2) for x, y in cells if y == 2}
        room["barrier_cells"] = [list(c) for c in sorted(barrier)]
        room["keeper_cell"] = [middle, 1]
        room["items"].append({"asset": "counter_pine", "cell": [middle - 1, 2]})
        for x, y in sorted(barrier - {(middle - 1, 2), (middle, 2), (middle + 1, 2)}):
            room["items"].append({"asset": "counter_hatch" if x in [middle - 2, middle + 2] else "counter_end", "cell": [x, y]})
        free -= barrier
        reserved |= {(middle, 1), (middle - 1, 3), (middle + 1, 3)}
    visits = {}
    for name in assets:
        nth = visits.get(name, 0)
        visits[name] = nth + 1
        fx, fy = manifest[name]["footprint"]
        if fx == 0:
            table = next((i for i in room["items"] if i["asset"] == "table_manor"), None)
            at = [table["cell"][0] + 1, table["cell"][1]] if table else [middle, max(1, len(room["rows"]) // 2)]
            room["items"].append({"asset": name, "cell": at, "height": 245})
            continue
        width, depth = max(room["rows"]), len(room["rows"])
        if not staff:
            # Spatial groups keep later homes from becoming one row of wall clutter.
            targets = {"bed": (0, max(1, depth * .16)), "kitchen": (width - 2, 0),
                       "hearth": (width * .38, depth * .26), "wardrobe": (0, depth * .45),
                       "sofa": (width * .45, depth * .60), "armchair": (width * .45, depth * .62),
                       "table_tea": (width * .43, depth * .62), "table_coffee": (width * .45, depth * .75),
                       "table_manor": (width * .55, depth * .34), "chair_manor": (width * .55 + nth * 2, depth * .34 + 1),
                       "chair_cottage": (width * .43 + 1, depth * .62 + 1), "bookcase": (0, depth * .65),
                       "piano": (width * .80, depth * .38), "letter_desk": (width * .72, depth * .65),
                       "workbench": (0, depth - 1), "loom": (0, depth * .70), "throne": (width * .55, 0),
                       "plant": (width - 1 if nth else 1, depth * .5 if nth else 0), "flowers": (width * .4, depth * .6)}
            target = next((pos for prefix, pos in targets.items() if name.startswith(prefix)), (width - 1, 0))
            candidates = sorted(cells, key=lambda c: ((c[0] - target[0]) ** 2 + (c[1] - target[1]) ** 2, c))
        else:
            customer = name in ["seed_display", "fabric_rack", "potion_shelf", "notice_board_indoor", "sofa_sage", "bed_patch", "table_tea", "chair_cottage", "plant_cottage"]
            candidates = sorted(cells, key=lambda c: (0 if (c[1] >= 4 if customer else c[1] < 2) else 1,
                                                       c[1], min(c[0], room["rows"][c[1]] - 1 - c[0]), c[0]))
        placed = False
        for x, y in candidates:
            item = {"asset": name, "cell": [x, y]}
            used = occupied(item, manifest)
            if not used <= free or used & reserved or (staff and any(c[1] == 2 for c in used)):
                continue
            left = free - used
            public = {c for c in left if not staff or c[1] >= 3}
            if not connected(public, door):
                continue
            # The keeper stays reachable through the staff corridor.
            if staff and not connected({c for c in left if c[1] < 2}, (middle, 1)):
                continue
            # Every floor piece keeps an adjacent free tile after later pieces land.
            inaccessible = False
            for probe in room["items"] + [item]:
                if manifest[probe["asset"]]["footprint"][0] == 0 or probe["asset"].startswith("counter"):
                    continue
                area = occupied(probe, manifest)
                around = {(a + dx, b + dy) for a, b in area for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]} - area
                if not around & left:
                    inaccessible = True
                    break
            if inaccessible:
                continue
            room["items"].append(item)
            free = left
            placed = True
            break
        if not placed:
            raise ValueError(f"{room['id']}: no accessible place for {name}")
    room["walkable_cells"] = [list(c) for c in sorted(free) if not staff or c[1] >= 3]
    # Rugs are visual art-study dressing, not free owned furniture or colliders.
    rug = "rug_manor" if room.get("tier", 0) >= 5 else "rug_sprig" if staff else "rug_braid"
    room["ground_decor"] = []
    if room.get("tier", 2) > 1:
        sx, sy = manifest[rug]["ground_span"]
        target = (middle, max(3, len(room["rows"]) // 2))
        possible = [(x, y) for x, y in cells if {(x + i, y + j) for i in range(sx) for j in range(sy)} <= cells
                    and (not staff or y >= 3)]
        if possible:
            x, y = min(possible, key=lambda c: (c[0] - target[0]) ** 2 + (c[1] - target[1]) ** 2)
            room["ground_decor"].append({"asset": rug, "cell": [x, y]})
    room["decor"] = [{"asset": "wall_lantern", "cell": [0, max(0, len(room["rows"]) - 2)], "wall": 1, "height": 120},
                     {"asset": "picture_leaf", "cell": [0, max(0, len(room["rows"]) // 2)], "wall": 1, "height": 130}]
    if room.get("tier", 2) > 1:
        cols = max(room["rows"])
        choices = [x for x in range(1, cols) if x not in room["windows"]["z"]]
        col = min(choices, key=lambda x: abs(x - cols / 2))
        room["decor"].append({"asset": "wall_lantern", "cell": [col, 0], "wall": 0, "height": 120})


def rooms(manifest: dict) -> dict:
    result = {}
    home_sets = [
        ["bed_patch", "chest_cottage", "workbench"],
        ["bed_patch", "kitchen_hutch", "hearth_cottage", "table_tea", "chair_cottage", "chest_cottage", "plant_cottage"],
        ["bed_patch", "kitchen_hutch", "hearth_cottage", "loom_cottage", "table_tea", "chair_cottage", "bookcase_cottage", "plant_cottage"],
        ["bed_oak", "kitchen_hutch", "hearth_cottage", "wardrobe_cottage", "sofa_sage", "table_tea", "loom_cottage", "plant_cottage"],
        ["bed_oak", "kitchen_hutch", "hearth_cottage", "wardrobe_cottage", "sofa_sage", "table_tea", "chair_cottage", "bookcase_cottage", "loom_cottage", "plant_cottage"],
        ["bed_oak", "kitchen_hutch", "hearth_cottage", "wardrobe_cottage", "sofa_sage", "table_tea", "chair_manor", "bookcase_manor", "letter_desk", "plant_cottage", "loom_cottage"],
        ["bed_oak", "kitchen_hutch", "hearth_manor", "wardrobe_cottage", "sofa_sage", "table_manor", "chair_manor", "bookcase_manor", "piano_manor", "letter_desk", "plant_cottage", "loom_cottage"],
        ["bed_canopy", "kitchen_hutch", "hearth_manor", "wardrobe_cottage", "sofa_sage", "table_manor", "chair_manor", "chair_manor", "bookcase_manor", "piano_manor", "letter_desk", "plant_cottage", "plant_cottage"],
        ["bed_canopy", "kitchen_hutch", "hearth_manor", "wardrobe_cottage", "sofa_sage", "table_manor", "chair_manor", "chair_manor", "bookcase_manor", "piano_manor", "letter_desk", "throne_leaf", "plant_cottage", "plant_cottage"],
        ["bed_canopy", "kitchen_hutch", "hearth_manor", "hearth_cottage", "wardrobe_cottage", "sofa_sage", "table_manor", "chair_manor", "chair_manor", "bookcase_manor", "bookcase_cottage", "piano_manor", "letter_desk", "throne_leaf", "chandelier_leaf", "plant_cottage", "plant_cottage", "loom_cottage", "workbench"],
    ]
    titles = ["The patched shelter", "A kitchen of your own", "The weaving cottage", "The timber home", "The farmhouse", "The tower study", "The country retreat", "The welcoming manor", "The leaf-crowned castle", "The lived-in palace"]
    for tier, assets in enumerate(home_sets, 1):
        if tier >= 4:
            assets = assets + ["table_coffee", "armchair_sage"]
        source = f"assets/data/home/rooms/room_t{tier:02}.json"
        room = load(ROOT / source)
        room.update(id=f"home_t{tier:02}", title=titles[tier - 1], kind="home_upgrade", source_room=source, emblem="home")
        room["wall_material"] = ("plank" if tier == 1 else "plaster" if tier < 5 else "paper" if tier < 8 else "marble")
        furnish(room, assets, manifest)
        result[room["id"]] = room
    # The 24 planned town interiors, dimensions and building IDs from the towns addendum §4.1/4.4.
    town = [
        ("froebutikken", "The seed shop", 8, 6, "seed", ["seed_display", "plant_cottage", "feed_sack_stack", "chest_cottage", "bookcase_cottage"]),
        ("bageriet", "The bakery", 8, 6, "bakery", ["brick_oven", "bread_rack", "bread_rack", "table_tea"]),
        ("smedjen", "The smithy", 8, 6, "smith", ["forge", "anvil", "workbench", "plank_stack"]),
        ("dyrehuset", "The animal house", 9, 7, "animal", ["hay_bale", "hay_bale", "feed_sack_stack", "feed_sack_stack", "bookcase_cottage", "plant_cottage"]),
        ("troldmandstaarnet", "The wizard's tower", 7, 6, "magic", ["cauldron_stand", "potion_shelf", "letter_desk", "plant_cottage"]),
        ("moebelbutikken", "The furniture shop", 10, 7, "furniture", ["sofa_sage", "table_tea", "chair_cottage", "wardrobe_cottage", "bed_patch", "plant_cottage"]),
        ("skraedderiet", "The tailor", 8, 6, "tailor", ["mannequin", "fabric_rack", "loom_cottage", "wardrobe_cottage", "letter_desk"]),
        ("toemmerhandlen", "The timber yard", 9, 6, "timber", ["workbench", "plank_stack", "plank_stack", "chest_cottage"]),
        ("loppeloftet", "The flea loft", 8, 5, "flea", ["chest_cottage", "chair_cottage", "parcel_stack", "table_tea", "bookcase_cottage"]),
        ("brummes_vaerksted", "Brumme's workshop", 9, 7, "carpenter", ["workbench", "plank_stack", "letter_desk", "chest_cottage", "plant_cottage"]),
        ("uglehulen", "The owl's appraisal room", 7, 5, "owl", ["bookcase_cottage", "letter_desk", "chest_cottage", "plant_cottage"]),
        ("postkontoret", "The post office", 8, 5, "post", ["pigeonhole_wall", "mail_sack", "parcel_stack", "letter_desk"]),
        ("badehuset", "The bathhouse", 9, 7, "bath", ["wooden_tub", "wooden_tub", "plant_cottage", "chair_cottage", "kitchen_hutch"]),
        ("raadhuset", "The town hall", 10, 8, "hall", ["notice_board_indoor", "letter_desk", "bookcase_manor", "table_manor", "chair_manor", "plant_cottage"]),
        ("torvekroen", "The treetop inn", 10, 7, "bakery", ["hearth_cottage", "kitchen_hutch", "table_tea", "table_tea", "chair_cottage", "chair_cottage", "sofa_sage"]),
        ("fekongens_hus", "The fairy king's home", 10, 8, "hall", ["throne_leaf", "hearth_manor", "table_manor", "chair_manor", "bookcase_manor", "plant_cottage", "chandelier_leaf"]),
    ]
    homes = [("hoppe_hut", "Hoppe's cottage", ["plant_cottage", "plant_cottage", "feed_sack_stack"]),
             ("brummes_hus", "Brumme's home", ["workbench", "plank_stack"]),
             ("vagthytten", "Oak's guard hut", ["chest_cottage", "letter_desk"]),
             ("kikis_hytte", "Kiki's cottage", ["bookcase_cottage", "plant_cottage"]),
             ("musikstuen", "The music room", ["piano_manor", "chair_cottage"]),
             ("hyldeblomsts_hus", "The mayor's home", ["bookcase_cottage", "letter_desk"]),
             ("pippins_hus", "Pippin's home", ["parcel_stack", "chest_cottage"]),
             ("birks_bistade", "Birk's honey house", ["plant_cottage", "kitchen_hutch"])]
    for building, title, assets in homes:
        town.append((building, title, 6, 5, "home", ["bed_patch", "table_tea", "chair_cottage", "hearth_cottage"] + assets))
    for building, title, width, height, emblem, assets in town:
        public = emblem != "home" and building not in ["badehuset", "fekongens_hus"]
        room = {"id": "int_" + building, "building": building, "title": title, "kind": "town_study", "rows": [width] * height,
                "cells": [[x, y] for y in range(height) for x in range(width)], "wall_material": "plank" if emblem in ["smith", "carpenter", "timber", "flea"] else "plaster",
                "wall_style": "plank", "floor": "floor_stone" if emblem in ["smith", "bath"] else "floor_plank",
                "door": {"cell": [width // 2, height - 1], "dir": [0, 1]}, "spawn_cell": [width // 2, height - 2],
                "windows": {"z": [1, width - 2], "x": [1]}, "emblem": emblem}
        if building in ["fekongens_hus", "raadhuset"]:
            room["wall_material"] = "marble" if building == "fekongens_hus" else "paper"
            room["floor"] = "floor_parquet"
        furnish(room, assets, manifest, staff=public)
        result[room["id"]] = room
    return result


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"_source": "Painted interior masters; docs/art/interiors/prompts.json. Fixed-view modular assets, not four-rotation replacements."}
    furniture(manifest)
    walls(manifest)
    (OUT / "props.json").write_text(json.dumps(manifest, indent=2) + "\n")
    DATA.parent.mkdir(parents=True, exist_ok=True)
    DATA.write_text(json.dumps({"version": 1, "art": "res://assets/iso_props/painted_interiors/props.json",
                               "scope": "Art kit and furnishing studies. Live home/town door, ownership, hours and upgrade services remain separate gameplay packages.",
                               "rooms": rooms(manifest)}, indent=2) + "\n")
    print(f"Packed {len(manifest) - 1} painted interior assets and 34 room studies")


if __name__ == "__main__":
    main()
