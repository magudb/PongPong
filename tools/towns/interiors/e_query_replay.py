#!/usr/bin/env python3
"""Replay of the BUILT E-query on room specs (package T-towns-core, SE1 / SE2: the talk-cell geometry proof; lifted from D3/final_editor/se1/replay14.py and emit_expected.py).

The player's E key asks the physics space for the interaction hosts that overlap a circle r = 45 at the FACING cell and takes the host NEAREST TO THE PLAYER. A counter band therefore
has three kinds of host, decided by where the player STANDS: the middle cell selects the centre host (the shop panel), an end cell the `talk` host of that cell (the keeper's own
dialogue). The replay proves, for every spec with a centre host and two `talk` hosts:
    A  standing on an end cell and facing the counter selects that cell's talk host (9 sub-positions per cell, 18 per room)
    B  standing on the middle cell and facing the counter selects the centre host (9 per room)
    C  a talk host is NEVER selected from the middle cell, at any of the 8 facings (0 violations)
and counts E: how often the keeper itself (its own Interactable2D, 60 x 30) is selected over every standable cell (informational: with the old design it was 0 of 576).

Host geometry (half axes of the 12-gon interaction ellipse, screen px): centre host 150 x 40 (shop, post_counter, bar, appraisal, bath, board), talk 40 x 22, desk 40 x 22,
keeper and mailbox 60 x 30 (Interactable2D default).

    python3 -I e_query_replay.py DIR_OR_FILE [...]          rows per room + the totals; exit 1 when a rule is violated
    python3 -I e_query_replay.py DIR_OR_FILE --emit OUT     also writes the full selection table (room|cx,cy|sub|facing -> host) for the GDScript twin
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

sys.dont_write_bytecode = True                        # the tools never leave a __pycache__ in the repository, however they are started
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geom_lib import ic, select  # noqa: E402

CENTRE_TYPES = ("shop", "post_counter", "bar", "appraisal", "bath", "board")
SUBS = [(sx, sy) for sx in (-0.8, 0.0, 0.8) for sy in (-0.8, 0.0, 0.8)]
SHOP = (150.0, 40.0)
TALK = (40.0, 22.0)
KEEPER = (60.0, 30.0)
MAILBOX = (60.0, 30.0)


def hosts_of(spec: dict) -> dict:
    """{role: (centre_xy, half_axes)} of the spec: K keeper, S centre host, T0 / T1 talk (left, right), D desk, X mailbox; {} when the room has no counter band."""
    keeper = [p for p in spec["posts"] if p.get("kind") == "keeper"]
    centre = [mk for mk in spec["markers"] if mk["type"] in CENTRE_TYPES]
    talks = sorted([mk for mk in spec["markers"] if mk["type"] == "talk"], key=lambda mk: mk["cell"][0])
    if not keeper or not centre or len(talks) != 2:
        return {}
    h: dict = {"K": (ic(*keeper[0]["cell"]), KEEPER), "S": (ic(*centre[0]["cell"]), SHOP), "T0": (ic(*talks[0]["cell"]), TALK), "T1": (ic(*talks[1]["cell"]), TALK)}
    for mk in spec["markers"]:
        if mk["type"] == "desk":
            h["D"] = (ic(*mk["cell"]), TALK)
        elif mk["type"] == "mailbox":
            h["X"] = (ic(*mk["cell"]), MAILBOX)
    return h


def _sel(hosts: dict, cell: tuple, facing: int, sub: tuple) -> str | None:
    p0 = ic(*cell)
    return select((p0[0] + sub[0] * 32, p0[1] + sub[1] * 19), facing, cell, hosts)


def standable_cells(spec: dict) -> list[tuple[int, int]]:
    """Cells a customer can stand on: rows >= 3, not a hatch cell, not under a floor item."""
    hatch = {tuple(map(int, c)) for mk in spec["markers"] if mk["type"] == "hatch" for c in mk["cells"]}
    items = {tuple(i["cell"]) for i in spec["items"] if not i.get("wall")}
    return [(x, z) for x in range(spec["cols"]) for z in range(3, spec["rows"]) if (x, z) not in hatch and (x, z) not in items]


def replay(spec: dict) -> dict | None:
    """The A / B / C / E numbers of one spec (None for a room without a counter band)."""
    h = hosts_of(spec)
    if not h:
        return None
    keeper = [p for p in spec["posts"] if p.get("kind") == "keeper"][0]
    m = int(keeper["cell"][0])                                  # the keeper's column = the middle of the counter: the player stands on m - 1, m, m + 1 of row 3, NOT on wherever the markers say
    left, right, middle = (m - 1, 3), (m + 1, 3), (m, 3)
    row = dict(room=spec["id"], m=m, A=0, Amax=18, B=0, Bmax=9, C=0, K=0)
    for sub in SUBS:
        row["A"] += _sel(h, left, 5, sub) == "T0"
        row["A"] += _sel(h, right, 5, sub) == "T1"
        row["B"] += _sel(h, middle, 5, sub) == "S"
        for f in range(8):
            row["C"] += (_sel(h, middle, f, sub) or "").startswith("T")
    for cell in standable_cells(spec):
        for sub in SUBS:
            for f in range(8):
                row["K"] += _sel(h, cell, f, sub) == "K"
    return row


def rule_problems(spec: dict) -> list[str]:
    """The rules A / B / C as a list of problems (empty = they hold; a room without a counter band has nothing to prove)."""
    row = replay(spec)
    if row is None:
        return []
    out: list[str] = []
    if row["A"] != row["Amax"]:
        out.append(f"{spec['id']}: standing on an end cell facing the counter selects its talk host only {row['A']} of {row['Amax']} times (rule A)")
    if row["B"] != row["Bmax"]:
        out.append(f"{spec['id']}: standing on the middle cell facing the counter selects the centre host only {row['B']} of {row['Bmax']} times (rule B)")
    if row["C"] != 0:
        out.append(f"{spec['id']}: a talk host is selected from the middle cell {row['C']} times at the 8 facings (rule C)")
    return out


def table(spec: dict) -> dict[str, str]:
    """room|cx,cz|sub|facing -> role ("K", "S", "T0", "T1", "D", "X" or "none") over every standable cell: what the twin in GDScript must reproduce sample by sample."""
    h = hosts_of(spec)
    out: dict[str, str] = {}
    if not h:
        return out
    for cell in standable_cells(spec):
        for si, sub in enumerate(SUBS):
            for f in range(8):
                out[f"{spec['id']}|{cell[0]},{cell[1]}|{si}|{f}"] = _sel(h, cell, f, sub) or "none"
    return out


def spec_files(paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for p in paths:
        pp = Path(p)
        if pp.is_file():
            files.append(pp)
        else:
            files.extend(f for f in sorted(pp.rglob("int_*.json")) if "dress" not in f.parts)
    return files


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--emit")
    a = ap.parse_args()
    tot = dict(A=0, Amax=0, B=0, Bmax=0, C=0, K=0)
    emitted: dict[str, str] = {}
    bad = 0
    n = 0
    for f in spec_files(a.paths):
        spec = json.loads(f.read_text(encoding="utf-8"))
        row = replay(spec)
        if row is None:
            continue
        n += 1
        print(row)
        for k in tot:
            tot[k] += row[k]
        bad += len(rule_problems(spec))
        if a.emit:
            emitted.update(table(spec))
    print(f"over {n} rooms: A {tot['A']} / {tot['Amax']}, B {tot['B']} / {tot['Bmax']}, C violations {tot['C']}, keeper-direct selections {tot['K']}")
    if a.emit:
        Path(a.emit).write_text(json.dumps(emitted, sort_keys=True), encoding="utf-8")
        print(f"wrote {len(emitted)} samples to {a.emit}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
