#!/usr/bin/env python3
"""Validator of the room specs (data/interiors/<core|ext>/int_<id>.json and the fixture rooms). Package T-towns-core, TOWNS addendum 4.4.

    python3 -I validate.py PATH [PATH ...]          every int_*.json under the paths (files starting `dress/` are overlays, merged below)
    python3 -I validate.py PATH --stand-ins         also list the stand-ins every room draws (never silent)
    python3 -I validate.py --selftest               mutate a generated room 14 ways and prove that every mutant is caught
Exit code 0 = "0 problems"; the last line is `validate: <rooms> room(s), <n> problem(s)`.

What is checked per room (schema in data/interiors/schema.json, a hand-written subset interpreter below):
  structure   schema; id = int_<building>; the door on the last row, the spawn in front of it; the exit spawn is from_int_<building>; every piece id is a kit id or a furniture id;
              every cell inside the room; no two solid pieces share a cell; no solid piece on the door lane (door column, rows 3..last) or on a host cell;
  the band    one hatch marker (cells on row 2, none under a piece) when a keeper stands behind a counter; the centre host (shop, post_counter, bar, appraisal, bath, board) on the
              middle cell (m, 3) with m = the keeper's column, exactly two `talk` hosts on the cells m - 1 and m + 1 (the customer cells in front of the counter ENDS) carrying the keeper,
              the builder yard's `desk` on m + 2; no piece, no post and no hatch bar on any host cell; the keeper post on (m, 1);
  flood fill  the player (hatch bars block him) walks from the spawn to every host, every customer post and the door, and can NOT reach the keeper post; a citizen (the hatch is open)
              reaches every post and the door;
  E-query     rules A / B / C of e_query_replay.py (the middle cell opens the panel, an end cell the keeper, a talk host is never selected from the middle cell);
  overlay     data/interiors/dress/int_<id>.json (items, owner I4) is merged after the room's items and the merged room must pass all of the above, and each dressing piece
              must stand on free cells only: never the door lane, the counter band, a post or a hatch cell.
"""
from __future__ import annotations

import argparse
import copy
import json
import os
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True                        # the tools never leave a __pycache__ in the repository, however they are started
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import e_query_replay as E  # noqa: E402
import grammar as G  # noqa: E402

ROOT = G.ROOT
SCHEMA_PATH = ROOT / "data" / "interiors" / "schema.json"
STAND_INS_PATH = ROOT / "data" / "interiors" / "stand_ins.json"
NON_ROOM = ("schema", "stand_ins", "kit_footprints")


# ------------------------------------------------------------------------------------------------------------------------------
# schema: a small interpreter of the JSON-schema subset schema.json uses (type, enum, required, properties, additionalProperties, items, minimum, maximum, minItems, maxItems, pattern, $ref)
# ------------------------------------------------------------------------------------------------------------------------------
def _type_ok(v, t: str) -> bool:
    if t == "object":
        return isinstance(v, dict)
    if t == "array":
        return isinstance(v, list)
    if t == "string":
        return isinstance(v, str)
    if t == "integer":
        return isinstance(v, int) and not isinstance(v, bool)
    if t == "number":
        return isinstance(v, (int, float)) and not isinstance(v, bool)
    if t == "boolean":
        return isinstance(v, bool)
    return False


def schema_problems(value, schema: dict, root: dict, path: str = "$") -> list[str]:
    out: list[str] = []
    if "$ref" in schema:
        node = root
        for part in schema["$ref"].lstrip("#/").split("/"):
            node = node[part]
        return schema_problems(value, node, root, path)
    if "enum" in schema and value not in schema["enum"]:
        return [f"{path}: {value!r} is not one of {schema['enum']}"]
    if "type" in schema and not _type_ok(value, schema["type"]):
        return [f"{path}: expected {schema['type']}, got {type(value).__name__}"]
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            out.append(f"{path}: {value} is below {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            out.append(f"{path}: {value} is above {schema['maximum']}")
    if isinstance(value, str) and "pattern" in schema and re.search(schema["pattern"], value) is None:
        out.append(f"{path}: {value!r} does not match {schema['pattern']}")
    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            out.append(f"{path}: needs at least {schema['minItems']} entries")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            out.append(f"{path}: allows at most {schema['maxItems']} entries")
        if "items" in schema:
            for i, x in enumerate(value):
                out.extend(schema_problems(x, schema["items"], root, f"{path}[{i}]"))
    if isinstance(value, dict):
        for k in schema.get("required", []):
            if k not in value:
                out.append(f"{path}: missing `{k}`")
        props = schema.get("properties", {})
        for k, v in value.items():
            if k in props:
                out.extend(schema_problems(v, props[k], root, f"{path}.{k}"))
            elif schema.get("additionalProperties") is False:
                out.append(f"{path}: unknown key `{k}`")
    return out


def load_schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


# ------------------------------------------------------------------------------------------------------------------------------
# the room model of a spec
# ------------------------------------------------------------------------------------------------------------------------------
class Model:
    """Cells of a spec (plus the merged dressing items): solid cells, flat cells, hatch, hosts, posts."""

    def __init__(self, spec: dict, extra_items: list[dict] | None = None):
        self.spec = spec
        self.cols = int(spec["cols"])
        self.rows = int(spec["rows"])
        self.items = list(spec["items"]) + list(extra_items or [])
        self.dress_start = len(spec["items"])
        self.door = (int(spec["door"]["cell"][0]), int(spec["door"]["cell"][1]))
        self.spawn = (int(spec["spawn_cell"][0]), int(spec["spawn_cell"][1]))
        self.hatch = {(int(c[0]), int(c[1])) for mk in spec["markers"] if mk["type"] == "hatch" for c in mk.get("cells", [])}
        self.posts = {p["id"]: p for p in spec["posts"]}
        self.keeper = next((p for p in spec["posts"] if p.get("kind") == "keeper"), None)
        self.centre = next((mk for mk in spec["markers"] if mk["type"] in E.CENTRE_TYPES), None)
        self.talks = [mk for mk in spec["markers"] if mk["type"] == "talk"]
        self.desk = next((mk for mk in spec["markers"] if mk["type"] == "desk"), None)
        self.mailbox = next((mk for mk in spec["markers"] if mk["type"] == "mailbox"), None)
        self.occ: set[tuple[int, int]] = set()
        self.flat: set[tuple[int, int]] = set()
        self.unknown: list[str] = []
        for it in self.items:
            self.apply_item(it)

    def footprint_cells(self, it: dict) -> list[tuple[int, int]]:
        w, d = G.fp(it["id"], int(it.get("rot", 0)))
        return [(int(it["cell"][0]) + i, int(it["cell"][1]) + j) for i in range(w) for j in range(d)]

    def apply_item(self, it: dict) -> None:
        if G.piece(it["id"]) is None:
            self.unknown.append(it["id"])
            return
        layer = G.layer(it["id"])
        cells = self.footprint_cells(it)
        if layer == "floor":
            self.occ.update(cells)
        elif layer in ("rug", "tabletop"):
            self.flat.update(cells)

    def host_cells(self) -> set[tuple[int, int]]:
        out: set[tuple[int, int]] = set()
        for mk in self.spec["markers"]:
            if mk["type"] in E.CENTRE_TYPES + ("talk", "desk", "mailbox"):
                out.add((int(mk["cell"][0]), int(mk["cell"][1])))
        return out

    def door_lane(self) -> set[tuple[int, int]]:
        return {(self.door[0], z) for z in range(3, self.rows)}

    def band_cells(self) -> set[tuple[int, int]]:
        """The counter band: the counter, its keeper corridor, the counter front, the hatch bars and the host cells."""
        out = set(self.hatch) | self.host_cells()
        for it in self.items:
            if it.get("role") == "counter":
                out.update(self.footprint_cells(it))
        if self.keeper is not None:
            m = int(self.keeper["cell"][0])
            for x in range(m - 1, m + 2):
                out.add((x, 1))
                out.add((x, 3))
        return out

    def post_cells(self) -> set[tuple[int, int]]:
        return {(int(p["cell"][0]), int(p["cell"][1])) for p in self.spec["posts"]}

    def flood(self, npc: bool) -> set[tuple[int, int]]:
        blocked = set(self.occ) | (set() if npc else set(self.hatch))
        seen = {self.spawn}
        stack = [self.spawn]
        while stack:
            x, z = stack.pop()
            for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, z + dz)
                if 0 <= n[0] < self.cols and 0 <= n[1] < self.rows and n not in blocked and n not in seen:
                    seen.add(n)
                    stack.append(n)
        return seen


def in_room(c, cols: int, rows: int) -> bool:
    return 0 <= c[0] < cols and 0 <= c[1] < rows


# ------------------------------------------------------------------------------------------------------------------------------
# the rules
# ------------------------------------------------------------------------------------------------------------------------------
def validate_spec(spec: dict, dress_items: list[dict] | None = None, schema: dict | None = None) -> list[str]:
    rid = spec.get("id", "?")
    problems = [f"{rid}: {p}" for p in schema_problems(spec, schema or load_schema(), schema or load_schema())]
    if problems:
        return problems                               # nothing below can be trusted on a spec that is not shaped right
    b = spec["building"]
    cols, rows = spec["cols"], spec["rows"]
    if rid != "int_" + b:
        problems.append(f"{rid}: id must be int_{b}")
    if spec["exit"]["spawn"] != "from_int_" + b:
        problems.append(f"{rid}: exit.spawn must be from_int_{b}, got {spec['exit']['spawn']}")
    mdl = Model(spec, dress_items)
    for u in mdl.unknown:
        problems.append(f"{rid}: unknown piece `{u}` (not a kit id of data/interiors/kit_footprints.json, not a furniture id)")
    if mdl.unknown:
        return problems
    if mdl.door[1] != rows - 1 or not in_room(mdl.door, cols, rows):
        problems.append(f"{rid}: the door must sit on the last row ({rows - 1}), got {list(mdl.door)}")
    if mdl.spawn != (mdl.door[0], mdl.door[1] - 1):
        problems.append(f"{rid}: the spawn must be the cell in front of the door {[mdl.door[0], mdl.door[1] - 1]}, got {list(mdl.spawn)}")
    # pieces: inside the room, solid pieces never overlap
    seen: dict[tuple[int, int], str] = {}
    lane = mdl.door_lane()
    hosts = mdl.host_cells()
    for idx, it in enumerate(mdl.items):
        who = "dressing piece" if idx >= mdl.dress_start else "piece"
        cells = mdl.footprint_cells(it)
        layer = G.layer(it["id"])
        if layer in ("floor", "rug", "tabletop", "wall") and any(not in_room(c, cols, rows) for c in cells):
            problems.append(f"{rid}: {who} {it['id']} at {it['cell']} leaves the room")
            continue
        if layer == "floor":
            for c in cells:
                if c in seen:
                    problems.append(f"{rid}: {who} {it['id']} at {it['cell']} overlaps {seen[c]} on {list(c)}")
                    break
                seen[c] = it["id"]
        if layer in ("floor", "rug", "tabletop"):
            if any(c in lane for c in cells) and (layer != "rug" or idx >= mdl.dress_start):
                problems.append(f"{rid}: {who} {it['id']} at {it['cell']} stands on the door lane")
            if it.get("role") != "counter" and any(c in hosts for c in cells):
                problems.append(f"{rid}: {who} {it['id']} at {it['cell']} stands on a host cell (the shop, a talk host, the desk or the mailbox)")
        if idx >= mdl.dress_start and layer in ("floor", "rug", "tabletop"):
            band = mdl.band_cells()
            if any(c in band for c in cells):
                problems.append(f"{rid}: dressing piece {it['id']} at {it['cell']} stands in the counter band")
            if any(c in mdl.post_cells() or c in mdl.hatch for c in cells):
                problems.append(f"{rid}: dressing piece {it['id']} at {it['cell']} stands on a post or a hatch cell")
    # posts
    ids = [p["id"] for p in spec["posts"]]
    if len(ids) != len(set(ids)):
        problems.append(f"{rid}: duplicate post ids")
    for p in spec["posts"]:
        c = (int(p["cell"][0]), int(p["cell"][1]))
        if not in_room(c, cols, rows):
            problems.append(f"{rid}: post {p['id']} {list(c)} is outside the room")
        elif c in mdl.occ:
            problems.append(f"{rid}: post {p['id']} {list(c)} is inside a solid piece")
        elif c in hosts and p.get("kind") != "keeper":
            problems.append(f"{rid}: post {p['id']} {list(c)} stands on a host cell")
    # the counter band
    has_counter = any(it.get("role") == "counter" for it in mdl.items)
    if mdl.hatch or mdl.centre is not None or mdl.talks or mdl.desk is not None:
        problems.extend(_band_problems(rid, spec, mdl, has_counter))
    # flood fill with the cell grid (the Godot section repeats it with the real colliders)
    problems.extend(_flood_problems(rid, spec, mdl))
    problems.extend(E.rule_problems(_with_items(spec, mdl.items)))
    return problems


def _with_items(spec: dict, items: list[dict]) -> dict:
    s = copy.deepcopy(spec)
    s["items"] = items
    return s


def _band_problems(rid: str, spec: dict, mdl: Model, has_counter: bool) -> list[str]:
    out: list[str] = []
    cols, rows = mdl.cols, mdl.rows
    hatch_markers = [mk for mk in spec["markers"] if mk["type"] == "hatch"]
    if len(hatch_markers) != 1:
        out.append(f"{rid}: a counter band has exactly ONE hatch marker, got {len(hatch_markers)}")
    if mdl.keeper is None:
        out.append(f"{rid}: a counter band needs a keeper post (kind keeper)")
        return out
    m = int(mdl.keeper["cell"][0])
    if [int(mdl.keeper["cell"][1])] != [1]:
        out.append(f"{rid}: the keeper post must stand one row behind the counter (row 1), got {mdl.keeper['cell']}")
    if not has_counter:
        out.append(f"{rid}: no piece carries the role counter")
    counter = next((it for it in mdl.items if it.get("role") == "counter"), None)
    if counter is not None:
        w, _ = G.fp(counter["id"], int(counter.get("rot", 0)))
        x0 = int(counter["cell"][0])
        if int(counter["cell"][1]) != 2 or w != 3 or x0 + 1 != m:
            out.append(f"{rid}: the counter must be 3 x 1 on row 2 with the keeper's column {m} in its middle, got {counter['id']} at {counter['cell']}")
    for c in sorted(mdl.hatch):
        if c[1] != 2 or not in_room(c, cols, rows):
            out.append(f"{rid}: hatch cell {list(c)} is not on row 2")
        if c in mdl.occ:
            out.append(f"{rid}: hatch cell {list(c)} lies under a solid piece")
    if mdl.centre is None:
        out.append(f"{rid}: a counter band needs a centre host (one of {', '.join(E.CENTRE_TYPES)})")
    elif [int(mdl.centre["cell"][0]), int(mdl.centre["cell"][1])] != [m, 3]:
        out.append(f"{rid}: the centre host must stand on the middle cell {[m, 3]}, got {mdl.centre['cell']}")
    if mdl.centre is not None and mdl.centre["type"] in ("shop", "post_counter", "bar", "appraisal", "bath", "board") and "keeper" not in mdl.centre:
        out.append(f"{rid}: the centre host {mdl.centre['type']} must name its keeper")
    cells = sorted(int(mk["cell"][0]) for mk in mdl.talks)
    if cells != [m - 1, m + 1] or any(int(mk["cell"][1]) != 3 for mk in mdl.talks):
        out.append(f"{rid}: exactly two talk hosts are required, on the customer cells {[m - 1, 3]} and {[m + 1, 3]} in front of the counter ends, got {[mk['cell'] for mk in mdl.talks]}")
    for mk in mdl.talks:
        if mk.get("keeper") != M_keeper(spec):
            out.append(f"{rid}: talk host {mk['cell']} must carry the keeper `{M_keeper(spec)}`")
    if mdl.desk is not None and [int(mdl.desk["cell"][0]), int(mdl.desk["cell"][1])] != [m + 2, 3]:
        out.append(f"{rid}: the desk must stand on {[m + 2, 3]}, got {mdl.desk['cell']}")
    for mk in spec["markers"]:
        if mk["type"] in E.CENTRE_TYPES + ("talk", "desk", "mailbox"):
            c = (int(mk["cell"][0]), int(mk["cell"][1]))
            if c in mdl.occ or c in mdl.flat or c in mdl.hatch:
                out.append(f"{rid}: the {mk['type']} host on {list(c)} is covered by a piece or a hatch bar (host cells stay free)")
    return out


def M_keeper(spec: dict) -> str:
    centre = next((mk for mk in spec["markers"] if mk["type"] in E.CENTRE_TYPES), None)
    return str(centre.get("keeper", "")) if centre is not None else ""


def _flood_problems(rid: str, spec: dict, mdl: Model) -> list[str]:
    out: list[str] = []
    player = mdl.flood(False)
    citizen = mdl.flood(True)
    if mdl.door not in citizen:
        out.append(f"{rid}: the door is not reachable")
    if mdl.door not in player:
        out.append(f"{rid}: the player cannot reach the door")
    for mk in spec["markers"]:
        if mk["type"] in E.CENTRE_TYPES + ("talk", "desk", "mailbox"):
            c = (int(mk["cell"][0]), int(mk["cell"][1]))
            if c not in player:
                out.append(f"{rid}: the player cannot reach the {mk['type']} host on {list(c)}")
    for p in spec["posts"]:
        c = (int(p["cell"][0]), int(p["cell"][1]))
        if c in mdl.occ or not in_room(c, mdl.cols, mdl.rows):
            continue
        if c not in citizen:
            out.append(f"{rid}: post {p['id']} {list(c)} is not reachable by a citizen")
        if p.get("kind") == "customer" and c not in player:
            out.append(f"{rid}: customer post {p['id']} {list(c)} is not reachable by the player")
    if mdl.hatch and mdl.keeper is not None:
        kc = (int(mdl.keeper["cell"][0]), int(mdl.keeper["cell"][1]))
        if kc in player:
            out.append(f"{rid}: the player can walk behind the counter to the keeper post {list(kc)} (the hatch leaks)")
        if kc not in citizen and kc not in mdl.occ:
            out.append(f"{rid}: a citizen cannot reach the keeper post {list(kc)}")
    return out


# ------------------------------------------------------------------------------------------------------------------------------
# files and the CLI
# ------------------------------------------------------------------------------------------------------------------------------
def room_files(paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        pp = Path(p)
        if pp.is_file():
            files.append(pp)
        else:
            files.extend(f for f in sorted(pp.rglob("*.json")) if f.stem not in NON_ROOM and "dress" not in f.parts and f.stem.startswith("int_"))
    return files


def dress_for(path: Path, explicit: str | None) -> list[dict]:
    """The overlay items of a room (data/interiors/dress/int_<id>.json: {items: [...]}), looked for next to the spec, one level up and in the repo."""
    names = [path.stem + ".json"]
    cands = [Path(explicit) / names[0]] if explicit else []
    cands += [path.parent / "dress" / names[0], path.parent.parent / "dress" / names[0], ROOT / "data" / "interiors" / "dress" / names[0]]
    for c in cands:
        if c.exists():
            data = json.loads(c.read_text(encoding="utf-8"))
            return list(data.get("items", []))
    return []


def stand_in_lines(spec: dict, dress: list[dict], without_kit: bool = False) -> list[str]:
    table = json.loads(STAND_INS_PATH.read_text(encoding="utf-8"))["stand_ins"]
    baked = set()
    if not without_kit:
        for kit in ("core", "special"):
            manifest = ROOT / "assets" / "iso_props" / "shops" / kit / "shops.json"
            if manifest.exists():
                baked.update(json.loads(manifest.read_text(encoding="utf-8")).get("items", {}))
    used = sorted({it["id"] for it in list(spec["items"]) + dress
                   if it["id"] in table and it["id"] not in baked and it["id"] not in G.furniture()})
    return [f"stand-in {spec['id']}: {k} -> {table[k]}" for k in used]


def run_paths(paths: list[str], dress_dir: str | None, show_stand_ins: bool, without_kit: bool = False) -> tuple[int, int]:
    schema = load_schema()
    rooms = 0
    total = 0
    for f in room_files(paths):
        spec = json.loads(f.read_text(encoding="utf-8"))
        dress = dress_for(f, dress_dir)
        problems = validate_spec(spec, dress, schema)
        rooms += 1
        total += len(problems)
        if problems:
            for p in problems:
                print("FAIL " + p)
        else:
            print(f"PASS {spec['id']}" + (f" (+{len(dress)} dressing pieces)" if dress else ""))
        if show_stand_ins:
            for line in stand_in_lines(spec, dress, without_kit):
                print(line)
    return rooms, total


def mutants(spec: dict) -> list[tuple[str, dict]]:
    """Mutated copies of a shop-band room: each one breaks ONE rule and must be caught."""
    out: list[tuple[str, dict]] = []

    def mut(name: str, fn) -> None:
        s = copy.deepcopy(spec)
        fn(s)
        out.append((name, s))

    centre = lambda s: next(mk for mk in s["markers"] if mk["type"] in E.CENTRE_TYPES)  # noqa: E731
    talks = lambda s: [mk for mk in s["markers"] if mk["type"] == "talk"]  # noqa: E731
    m = spec["posts"][[p.get("kind") for p in spec["posts"]].index("keeper")]["cell"][0]
    mut("talk_cell_on_a_piece", lambda s: s["items"].append({"id": "chest_oak", "cell": list(talks(s)[0]["cell"]), "rot": 0}))
    mut("hatch_marker_removed", lambda s: s["markers"].remove(next(mk for mk in s["markers"] if mk["type"] == "hatch")))
    mut("piece_on_the_door_lane", lambda s: s["items"].append({"id": "plant_fern", "cell": [s["door"]["cell"][0], s["rows"] - 2], "rot": 0}))
    mut("hatch_leaks", lambda s: next(mk for mk in s["markers"] if mk["type"] == "hatch")["cells"].remove([m - 2, 2]))
    mut("customer_post_inside_a_piece", lambda s: s["posts"].__setitem__([p.get("kind") for p in s["posts"]].index("customer"), dict(next(p for p in s["posts"] if p.get("kind") == "customer"), cell=[s["items"][1]["cell"][0], s["items"][1]["cell"][1]])))
    mut("talk_host_one_cell_too_far", lambda s: talks(s)[1]["cell"].__setitem__(0, m + 2))
    mut("unknown_wall_style", lambda s: s.__setitem__("wall_style", "granite"))
    mut("unknown_piece", lambda s: s["items"].append({"id": "no_such_piece_anywhere", "cell": [0, 4], "rot": 0}))
    mut("door_not_on_the_last_row", lambda s: s["door"]["cell"].__setitem__(1, s["rows"] - 2))
    mut("two_hatch_markers", lambda s: s["markers"].append({"type": "hatch", "cells": [[0, 2]]}))
    mut("talk_host_without_keeper", lambda s: talks(s)[0].pop("keeper"))
    mut("centre_host_off_the_middle", lambda s: centre(s).__setitem__("cell", [m + 1, 3]))
    mut("one_talk_host_missing", lambda s: s["markers"].remove(talks(s)[0]))
    mut("stand_in_field_present", lambda s: s["items"][0].__setitem__("stand_in", "table_stump"))
    return out


def selftest() -> int:
    from generate import generate  # noqa: E402

    base = generate(["froebutikken"])["froebutikken"]
    schema = load_schema()
    clean = validate_spec(base, None, schema)
    bad = 0
    print(("PASS" if not clean else "FAIL") + " selftest_base_room_is_clean" + ("" if not clean else f" {clean}"))
    bad += 1 if clean else 0
    for name, s in mutants(base):
        problems = validate_spec(s, None, schema)
        caught = len(problems) > 0
        print(("PASS" if caught else "FAIL") + f" mutant_{name}" + (f" -> {problems[0]}" if caught else " NOT CAUGHT"))
        bad += 0 if caught else 1
    # an overlay that stands in the counter band is refused, one on free cells passes
    over_bad = validate_spec(base, [{"id": "rug_round_red", "cell": [base["door"]["cell"][0], 3], "rot": 0}], schema)
    over_ok = validate_spec(base, [{"id": "plant_fern", "cell": [0, 5], "rot": 0}], schema)
    print(("PASS" if over_bad else "FAIL") + " mutant_overlay_on_the_door_lane")
    print(("PASS" if not over_ok else "FAIL") + " overlay_on_free_cells_passes" + ("" if not over_ok else f" {over_ok}"))
    bad += (0 if over_bad else 1) + (1 if over_ok else 0)
    return 1 if bad else 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--dress-dir")
    ap.add_argument("--stand-ins", action="store_true")
    ap.add_argument("--without-kit", action="store_true", help="report fallback art as if shop kits were absent (regression fixtures)")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--reach", action="store_true", help="print the cells the player and a citizen reach from the spawn per room as JSON (the Godot section compares them with the real colliders)")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if a.reach:
        out = {}
        for f in room_files(a.paths):
            spec = json.loads(f.read_text(encoding="utf-8"))
            mdl = Model(spec, dress_for(f, a.dress_dir))
            out[spec["id"]] = {"player": sorted([list(c) for c in mdl.flood(False)]), "citizen": sorted([list(c) for c in mdl.flood(True)])}
        print(json.dumps(out, sort_keys=True))
        return 0
    if not a.paths:
        ap.error("give at least one directory or spec file (or --selftest)")
    rooms, total = run_paths(a.paths, a.dress_dir, a.stand_ins, a.without_kit)
    print(f"validate: {rooms} room(s), {total} problem(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
