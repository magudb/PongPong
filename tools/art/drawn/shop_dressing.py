#!/usr/bin/env python3
"""Deterministic optional art overlays for the published towns room snapshots.

Gameplay room geometry remains the towns package's data. This stage only adds
removable dressing and checks access without importing the unfinished branch.
"""
from __future__ import annotations

import json
import argparse
import hashlib
import importlib.util
import sys
from collections import deque
from pathlib import Path

from pack import ROOT, HERE

DOC = ROOT / "docs/art/shop-special"
OUT = ROOT / "data/interiors/dress"
WISHES = {
    "froebutikken": ["seed_display_table", "seed_sack_open", "seed_drawers_wall", "flowerpot_row"],
    "postkontoret": ["mailbox_indoor_red", "crate_stack", "shelf_wall_wide", "stamp_press"],
    "badehuset": ["towel_rack", "bath_stool", "bucket", "steam_vent"],
    "raadhuset": ["mayor_desk", "flag_stand", "banner_wall", "scale_brass"],
    "hoppe_hut": ["potting_bench", "carrot_crate", "seed_baskets_wall", "drying_herbs"],
    "bageriet": ["dough_table", "glass_display_case", "flour_sack", "bread_basket"],
    "smedjen": ["bellows", "grindstone", "weapon_rack", "tool_wall"],
    "troldmandstaarnet": ["star_globe", "crystal_ball_stand", "potion_shelf", "hanging_stars"],
    "uglehulen": ["owl_perch", "book_stack", "potion_shelf", "crystal_ball_stand"],
    "dyrehuset": ["feed_trough", "pen_fence", "cage_hanging", "bird_perch"],
    "toemmerhandlen": ["saw_bench", "blueprint_table", "nail_kegs", "rope_coil"],
    "moebelbutikken": ["folding_screen", "display_plinth", "shelf_floor_tall", "sample_tag_stand"],
    "skraedderiet": ["cloth_rolls_rack", "sewing_table", "standing_mirror", "fitting_curtain"],
    "brummes_vaerksted": ["plank_rack", "log_stack_indoor", "tool_hooks", "bell_counter"],
    "loppeloftet": ["junk_table", "old_trunk_flea", "umbrella_stand", "crates_mixed"],
}
# This already-full showroom reaches 2.984 MB in evening light before I4.
# Keep two useful accessories within its existing 3 MB whole-room limit;
# the larger designs remain exported for other room layouts/player furnishing.
BUDGET_OMISSIONS = {"moebelbutikken": ["folding_screen", "display_plinth", "shelf_floor_tall", "lantern_hanging"]}


def read(path: Path) -> dict:
    return json.loads(path.read_text())


def definitions() -> dict:
    items = read(ROOT / "assets/iso_props/furniture/furniture.json")["items"]
    items.update(read(HERE / "shop_core_layout.json")["pieces"])
    items.update(read(HERE / "shop_special_layout.json")["pieces"])
    return items


def cells(item: dict, defs: dict) -> set[tuple[int, int]]:
    fx, fy = defs[item["id"]]["footprint"]
    if item.get("rot", 0) % 2:
        fx, fy = fy, fx
    x, z = item["cell"]
    return {(x + a, z + b) for a in range(fx) for b in range(fy)}


def restrictions(room: dict, defs: dict) -> tuple[set, set, set, set]:
    posts = {tuple(p["cell"]) for p in room["posts"]}
    hosts = {tuple(m["cell"]) for m in room["markers"] if m["type"] not in ("door", "hatch")}
    hatch = {tuple(c) for m in room["markers"] if m["type"] == "hatch" for c in m.get("cells", [])}
    lane = {(room["door"]["cell"][0], z) for z in range(3, room["rows"])}
    band = hatch | hosts
    for it in room["items"]:
        if it.get("role") == "counter":
            band |= cells(it, defs)
    for p in room["posts"]:
        if p.get("kind") == "keeper":
            band |= {(p["cell"][0] + dx, z) for dx in (-1, 0, 1) for z in (1, 3)}
    return posts | hosts | hatch | lane | band, posts, hosts, hatch


def reachable(room: dict, blocked: set) -> set:
    start = tuple(room["spawn_cell"])
    if start in blocked:
        return set()
    seen = {start}
    todo = deque([start])
    while todo:
        x, z = todo.popleft()
        for q in [(x + 1, z), (x - 1, z), (x, z + 1), (x, z - 1)]:
            if 0 <= q[0] < room["cols"] and 0 <= q[1] < room["rows"] and q not in blocked and q not in seen:
                seen.add(q)
                todo.append(q)
    return seen


def validate(room: dict, overlay: list[dict], defs: dict) -> list[str]:
    forbidden, posts, hosts, hatch = restrictions(room, defs)
    errors = []
    occupied = set()
    for it in room["items"]:
        if defs[it["id"]]["layer"] == "floor":
            occupied |= cells(it, defs)
    for it in overlay:
        name = it.get("id", "")
        if name not in defs or set(it) - {"id", "cell", "rot", "wall"}:
            errors.append(f"unknown piece or schema fields: {it}")
            continue
        definition = defs[name]
        rot = it.get("rot", -1)
        if rot not in range(definition["rot_baked"]):
            errors.append(f"unavailable authored view: {name} r{rot}")
            continue
        area = cells(it, defs)
        if any(not (0 <= x < room["cols"] and 0 <= z < room["rows"]) for x, z in area):
            errors.append(f"outside floor: {name}")
        layer = definition["layer"]
        if layer in ("floor", "tabletop", "fx", "ceiling") and area & forbidden:
            errors.append(f"reserved access cell: {name}")
        if layer == "floor":
            if area & occupied:
                errors.append(f"overlapping furniture: {name}")
            occupied |= area
        if layer == "tabletop" and not area <= support_cells(room, overlay, defs):
            errors.append(f"tabletop has no complete supporting surface: {name}")
    citizen = reachable(room, occupied)
    player = reachable(room, occupied | hatch)
    if not posts <= citizen:
        errors.append("citizen post unreachable")
    if not hosts <= player or tuple(room["door"]["cell"]) not in player:
        errors.append("door or counter approach unreachable")
    return errors


def support_cells(room: dict, extra: list, defs: dict) -> set:
    supported = set()
    for it in room["items"] + extra:
        d = defs[it["id"]]
        if d.get("surface") or d.get("template") == "table" or it["id"] in ["dough_table", "sewing_table", "seed_display_table", "potting_bench", "blueprint_table", "junk_table"]:
            supported |= cells(it, defs)
    return supported


def make(room: dict, names: list[str], defs: dict) -> tuple[list, list]:
    extra, omitted = [], []
    forbidden, _, _, _ = restrictions(room, defs)
    wall_taken = {0: set(room["windows"]["z"]), 1: set(room["windows"]["x"])}
    for it in room["items"]:
        if defs[it["id"]]["layer"] == "wall":
            r = it.get("rot", 0)
            start = it["cell"][r]
            wall_taken[r] |= set(range(start, start + defs[it["id"]]["footprint"][0]))
    # Larger functional pieces get their chance before small clutter.
    for name in names:
        definition = defs[name]
        layer = definition["layer"]
        options = []
        if layer == "wall":
            for rot in range(2):
                span = definition["footprint"][0]
                limit = room["cols"] if rot == 0 else room["rows"]
                for start in range(limit - span + 1):
                    if set(range(start, start + span)) & wall_taken[rot]:
                        continue
                    options.append({"id": name, "cell": [start, 0] if rot == 0 else [0, start], "rot": rot, "wall": True})
            # A legal wall span can still hide a curtain or board behind a
            # wardrobe. Prefer visible spans before accepting an obscured one.
            occluders = set()
            for existing in room["items"] + extra:
                d = defs[existing["id"]]
                if d["layer"] == "floor" and (name == "fitting_curtain" or
                        d.get("template") in ("wardrobe", "bookshelf", "clock", "oven", "forge", "mannequin") or
                        existing["id"].startswith(("wardrobe", "bookshelf", "clock", "brick_oven"))):
                    occluders |= cells(existing, defs)
            options.sort(key=lambda it: len(cells(it, defs) & occluders))
        else:
            candidates = [(x, z) for z in range(room["rows"] - 1) for x in range(room["cols"])]
            candidates.sort(key=lambda c: (-abs(c[0] - room["cols"] / 2), c[1], c[0]))
            if layer == "tabletop":
                support = support_cells(room, extra, defs)
                candidates = [c for c in candidates if c in support]
            for rot in range(min(2, definition["rot_baked"])):
                options += [{"id": name, "cell": list(c), "rot": rot} for c in candidates if c not in forbidden]
        for it in options:
            if any(c in forbidden for c in cells(it, defs)) and layer != "wall":
                continue
            if validate(room, extra + [it], defs):
                continue
            # Dressing at different heights is allowed; two clutter sprites at
            # the SAME height are not piled invisibly on one another.
            if any(defs[e["id"]]["layer"] == layer and cells(e, defs) & cells(it, defs) for e in extra):
                continue
            extra.append(it)
            if layer == "wall":
                wall_taken[it["rot"]] |= {c[it["rot"]] for c in cells(it, defs)}
            break
        else:
            omitted.append(name)
    return extra, omitted


def main() -> None:
    rooms = read(DOC / "room-contracts.json")["rooms"]
    defs = definitions()
    OUT.mkdir(parents=True, exist_ok=True)
    record = {}
    for name, wishes in WISHES.items():
        room = rooms[name]
        budget_omissions = BUDGET_OMISSIONS.get(name, [])
        extra, omitted = make(room, [n for n in wishes + ["price_board", "lantern_hanging"] if n not in budget_omissions], defs)
        errors = validate(room, extra, defs)
        if errors or not 2 <= len(extra) <= 6:
            raise ValueError((name, errors, len(extra)))
        (OUT / (room["id"] + ".json")).write_text(json.dumps({"items": extra}, indent=2) + "\n")
        record[name] = {"pieces": len(extra), "omitted_for_space_or_support": omitted,
                        "omitted_for_texture_budget": budget_omissions, "errors": errors}
    (DOC / "dressing.json").write_text(json.dumps(record, indent=2) + "\n")
    print(f"Authored {len(record)} optional overlays; all access checks pass.")


def towns_evidence(checkout: Path) -> None:
    """Read the implementation owner's validator without modifying its checkout."""
    source = checkout / "tools/towns/interiors/validate.py"
    previous = sys.dont_write_bytecode
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(source.parent))
    try:
        spec = importlib.util.spec_from_file_location("towns_validator", source)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        rooms = read(DOC / "room-contracts.json")["rooms"]
        results, inputs = {}, {}
        for name in WISHES:
            path = OUT / (rooms[name]["id"] + ".json")
            results[name] = module.validate_spec(rooms[name], read(path)["items"])
            inputs[str(path.relative_to(ROOT))] = hashlib.sha256(path.read_bytes()).hexdigest()
        snapshot = DOC / "room-contracts.json"
        inputs[str(snapshot.relative_to(ROOT))] = hashlib.sha256(snapshot.read_bytes()).hexdigest()
        report = {"source": "read-only m1b tools/towns/interiors/validate.py",
                  "validator_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                  "inputs_sha256": inputs, "rooms": results}
        (DOC / "towns-validator.json").write_text(json.dumps(report, indent=2) + "\n")
        if any(results.values()):
            raise ValueError(results)
        print(f"Town validator: {len(results)} rooms; 0 problems")
    finally:
        sys.path.pop(0)
        sys.dont_write_bytecode = previous


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--towns-checkout", type=Path, help="Optional read-only checkout containing the actual towns validator")
    args = parser.parse_args()
    main()
    if args.towns_checkout:
        towns_evidence(args.towns_checkout)
