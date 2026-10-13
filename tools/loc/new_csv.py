#!/usr/bin/env python3
"""new_csv.py - create a localization CSV together with its keep-import (PLAN R.4).

  python tools/loc/new_csv.py NAME [--root .] [--row "KEY=da text|en text" ...] [--force]

Creates  localization/NAME.csv        header `keys,da,en` (+ the --row rows)
         localization/NAME.csv.import [remap] importer="keep"

Why the stub: without it `godot --import` turns every new CSV into NAME.da.translation / NAME.en.translation junk and an export packs
that output instead of the raw CSV, which the runtime loader (LocalizationManager) reads. LocalizationManager.lint() and csv_lint.py fail
when a CSV has no keep-import.

NAME is lower-case [a-z][a-z0-9_]* ("da" is the frozen legacy base, "zz_final" the copy-pass layer owned by P26).
The new file's key families must also be listed in tools/loc/key_owners.json (owner: P03; other packages hand the change over),
otherwise csv_lint prints a warning and the file's keys are only checked for uniqueness.
"""
import argparse
import os
import re
import sys

KEEP_IMPORT = '[remap]\n\nimporter="keep"\n'


def quote(text):
    return '"%s"' % text.replace('"', '""')


def main(argv=None):
    ap = argparse.ArgumentParser(description="Create a localization CSV + its keep-import.")
    ap.add_argument("name", help="file name without .csv (lower-case, e.g. hud)")
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--root", default=os.path.abspath(os.path.join(here, "..", "..")), help="repository root")
    ap.add_argument("--row", action="append", default=[], help='initial row "KEY=Danish text|English text" (repeatable)')
    ap.add_argument("--force", action="store_true", help="overwrite an existing file")
    a = ap.parse_args(argv)
    # argv is decoded with the locale; in the C locale non-ASCII bytes arrive as surrogates - recover the UTF-8 text
    a.row = [os.fsencode(r).decode("utf-8", "replace") for r in a.row]
    if not re.fullmatch(r"[a-z][a-z0-9_]*", a.name):
        print("new_csv: NAME must be lower-case letters, digits and underscores (got %r)" % a.name, file=sys.stderr)
        return 2
    if a.name == "da" and not a.force:
        print("new_csv: da.csv is the frozen legacy base (owner P26); use a new name", file=sys.stderr)
        return 2
    folder = os.path.join(os.path.abspath(a.root), "localization")
    csv_path = os.path.join(folder, a.name + ".csv")
    imp_path = csv_path + ".import"
    if (os.path.exists(csv_path) or os.path.exists(imp_path)) and not a.force:
        print("new_csv: %s already exists (use --force to overwrite)" % csv_path, file=sys.stderr)
        return 1
    lines = ["keys,da,en"]
    seen = set()
    for r in a.row:
        m = re.fullmatch(r"([A-Z0-9_]+)=(.*)\|(.*)", r, re.S)
        if not m:
            print('new_csv: --row must look like "KEY=da text|en text" with KEY matching ^[A-Z0-9_]+$ (got %r)' % r, file=sys.stderr)
            return 2
        if m.group(1) in seen:
            print("new_csv: key %s given twice" % m.group(1), file=sys.stderr)
            return 2
        seen.add(m.group(1))
        lines.append("%s,%s,%s" % (m.group(1), quote(m.group(2)), quote(m.group(3))))
    os.makedirs(folder, exist_ok=True)
    with open(csv_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")
    with open(imp_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(KEEP_IMPORT)
    print("new_csv: wrote %s and %s" % (os.path.relpath(csv_path, a.root), os.path.relpath(imp_path, a.root)))
    print("new_csv: next - list the key families of %s.csv in tools/loc/key_owners.json (owner P03: hand it over as a change request)" % a.name)
    return 0


if __name__ == "__main__":
    for _stream in (sys.stdout, sys.stderr):
        _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
