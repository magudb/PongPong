#!/usr/bin/env python3
"""prune_legacy.py - list (and, with --apply, remove) the rows of the legacy localization/da.csv that are dead. Used by P26 only.

  python tools/loc/prune_legacy.py [--root .] [--refs refs.json | --godot [GODOT_BINARY]] [--apply] [--only a,b] [--keep-comments]

A row of da.csv is removed when it is
  overridden   its key is defined by another localization/*.csv (the other file wins at runtime anyway)
  malformed    its key does not match ^[A-Z0-9_]+$ or it has the wrong number of columns (the loader skips it)
  duplicate    an EARLIER row of a key that da.csv defines again later (the last row is the effective one)
  unreferenced nothing in scripts/ scenes/ lua/ data/maps/ names the key: no literal use, no expanded dynamic family
               (ITEM_<id> ... see tests/loc_check.gd), no key-looking string literal at all, and no dynamic prefix of code
               that is NOT enumerated by loc_check (a prefix such as ITEM_ is enumerated: the Lua items are the truth)
`--only` limits the reasons (default: all four). Without --apply nothing is written.

The reference index comes from tests/loc_check.gd (single implementation of the scan): pass a file written with
`godot --headless --path . -s res://tests/loc_check.gd -- --dump=refs.json`, or let --godot run it ($GODOT or the macOS app path).
After --apply run `godot --headless --path . -s res://tests/loc_check.gd -- --strict` and review the diff by eye (P26 task 1).
"""
import argparse
import csv
import io
import json
import os
import re
import subprocess
import sys
import tempfile

KEY_RX = re.compile(r"^[A-Z0-9_]+$")
DEFAULT_GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
ALL_REASONS = ("overridden", "malformed", "duplicate", "unreferenced")


def records(text):
    """[(first_line, last_line, cells)] of a CSV text (1-based, inclusive); the header is record 0."""
    rd = csv.reader(io.StringIO(text, newline=""))
    out, last = [], 0
    for cells in rd:
        out.append((last + 1, rd.line_num, cells))
        last = rd.line_num
    return out


def other_keys(folder):
    keys = {}
    for f in sorted(os.listdir(folder)):
        if not f.endswith(".csv") or f == "da.csv":
            continue
        with open(os.path.join(folder, f), encoding="utf-8-sig", newline="") as fh:
            for i, row in enumerate(csv.reader(fh)):
                if i and row and KEY_RX.match(row[0].strip()):
                    keys.setdefault(row[0].strip(), f)
    return keys


def load_refs(args, root):
    if args.refs:
        if not os.path.isfile(args.refs):
            raise SystemExit("prune_legacy: reference file not found: %s" % args.refs)
        return json.load(open(args.refs, encoding="utf-8"))
    godot = args.godot if isinstance(args.godot, str) and args.godot else os.environ.get("GODOT", DEFAULT_GODOT)
    out = os.path.join(tempfile.mkdtemp(prefix="loc_refs_"), "refs.json")
    cmd = [godot, "--headless", "--path", root, "-s", "res://tests/loc_check.gd", "--", "--quiet", "--dump=" + out]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if not os.path.isfile(out):
        sys.stderr.write(proc.stdout + proc.stderr)
        raise SystemExit("prune_legacy: loc_check.gd did not write the reference dump (is Godot at %s?)" % godot)
    return json.load(open(out, encoding="utf-8"))


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description="List / remove dead rows of the legacy da.csv.")
    ap.add_argument("--root", default=os.path.abspath(os.path.join(here, "..", "..")))
    ap.add_argument("--refs", help="reference dump written by tests/loc_check.gd --dump=FILE")
    ap.add_argument("--godot", nargs="?", const="", default=None, help="run loc_check.gd to get the references (optional binary path)")
    ap.add_argument("--apply", action="store_true", help="rewrite localization/da.csv")
    ap.add_argument("--only", default=",".join(ALL_REASONS), help="comma list of reasons to act on: " + ",".join(ALL_REASONS))
    ap.add_argument("--keep-comments", action="store_true", help="do not remove section comments that became empty")
    a = ap.parse_args(argv)
    if not a.refs and a.godot is None:
        ap.error("give --refs FILE (from loc_check.gd --dump=FILE) or --godot")
    reasons = set(x.strip() for x in a.only.split(",") if x.strip())
    if not reasons <= set(ALL_REASONS):
        ap.error("--only takes: " + ",".join(ALL_REASONS))
    root = os.path.abspath(a.root)
    folder = os.path.join(root, "localization")
    path = os.path.join(folder, "da.csv")
    text = open(path, encoding="utf-8", newline="").read()
    recs = records(text)
    if not recs:
        print("prune_legacy: da.csv is empty")
        return 0
    refs = load_refs(a, root)
    strong = set(refs.get("referenced", {}))
    for g in refs.get("groups", []):
        strong.update(g.get("keys", []))
    if not strong:
        print("prune_legacy: the reference index is empty - the scan failed, refusing to continue", file=sys.stderr)
        return 2
    weak = set(refs.get("weak", []))
    enumerated = set(refs.get("enumerated_prefixes", []))
    dyn = sorted({d["prefix"] for d in refs.get("dynamic_prefixes", []) if d["prefix"] not in enumerated})
    overridden = other_keys(folder)
    hcount = len(recs[0][2])
    last_row = {}
    for first, _last, cells in recs[1:]:
        k = cells[0].strip() if cells else ""
        if KEY_RX.match(k) and len(cells) == hcount:
            last_row[k] = first
    drop, why = {}, {}
    for first, last, cells in recs[1:]:
        key = cells[0].strip() if cells else ""
        if key == "" or key.startswith((";", "#")):
            continue
        reason = None
        if not KEY_RX.match(key) or len(cells) != hcount:
            reason = "malformed"
        elif last_row.get(key, first) != first:
            reason = "duplicate"
        elif key in overridden:
            reason = "overridden (%s)" % overridden[key]
        elif key not in strong and key not in weak and not any(key.startswith(p) for p in dyn):
            reason = "unreferenced"
        if reason and reason.split(" ")[0] in reasons:
            drop[(first, last)] = key
            why[(first, last)] = reason
    by_reason = {}
    for span, reason in why.items():
        by_reason.setdefault(reason.split(" ")[0], []).append((span[0], drop[span], reason))
    total = len([1 for r in recs[1:] if r[2] and r[2][0].strip() and not r[2][0].strip().startswith((";", "#"))])
    for r in ALL_REASONS:
        rows = by_reason.get(r, [])
        print("%s: %d row(s)" % (r, len(rows)))
        for line, key, reason in rows:
            print("   da.csv:%d %s%s" % (line, key[:60], "  -> " + reason[reason.find("("):] if "(" in reason else ""))
    print("prune_legacy: %d of %d da.csv rows would be removed, %d would stay%s" % (len(drop), total, total - len(drop), "" if a.apply else " (dry run; --apply rewrites da.csv)"))
    if not a.apply:
        return 0
    lines = text.split("\n")

    def is_comment(cells):
        return not cells or cells[0].strip() == "" or cells[0].strip().startswith((";", "#"))

    # sections = a run of comment/blank records followed by data rows; a section whose rows were all removed loses its comments too
    sections, cur = [], {"head": [], "rows": []}
    for rec in recs[1:]:
        if is_comment(rec[2]):
            if cur["rows"]:
                sections.append(cur)
                cur = {"head": [], "rows": []}
            cur["head"].append(rec)
        else:
            cur["rows"].append(rec)
    sections.append(cur)
    out_lines = lines[recs[0][0] - 1:recs[0][1]]
    for sec in sections:
        kept_rows = [r for r in sec["rows"] if (r[0], r[1]) not in drop]
        if sec["rows"] and not kept_rows and not a.keep_comments:
            continue
        for r in sec["head"] + kept_rows:
            out_lines.extend(lines[r[0] - 1:r[1]])
    kept = out_lines
    open(path, "w", encoding="utf-8", newline="").write("\n".join(kept).rstrip("\n") + "\n")
    print("prune_legacy: wrote %s (%d rows removed)" % (os.path.relpath(path, root), len(drop)))
    return 0


if __name__ == "__main__":
    for _stream in (sys.stdout, sys.stderr):
        _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
