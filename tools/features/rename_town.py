#!/usr/bin/env python3
"""Rename the fairy town in text files (and optionally file names): CD2 of the feature content.

    python3 -I tools/features/rename_town.py --old OLDNAME [--new Hyggebyen] [--apply] [--rename-files] ROOT [ROOT ...]

The OLD name is an ARGUMENT and is never written in this repository (the project rule is that the retired name appears nowhere; tests build it with `"fes" + "by"`).
Dry run by default: prints every file with a count and the first matching line.  Variants handled (longest/most specific first, so the genitive keeps its s):
  Old -> New (and Olds -> News), OLD -> NEW (OLDS -> NEWS), old -> new (olds -> news)     [ids, file names, json keys, CSV keys: FIND_AREA_<OLD> -> FIND_AREA_<NEW>]
Never touches: .git, .godot, tools/art/.venv, binary files and the user's design export (files whose name contains "Style Guide").
Text files are recognised by suffix (TEXT_EXT): code and data (.lua .gd .gdshader .py .sh .js), localization and data (.csv .json .txt .po), Godot text resources (.tscn .tres .cfg .godot .import),
the TEXT MAPS of the area framework (.map) and vector art (.svg), docs (.md .html .yml ...).
Guards (exit 2, nothing is read or written): an EMPTY, blank or shorter-than-3-characters --old (every string contains the empty string: an empty shell variable with --apply used to rewrite every text file under the
roots, and a second run grew them exponentially) and --old equal to --new.

The lift copy of the reviewed pack (FC) was already renamed when it was snapshotted, so on the first run of this package the tool found nothing to change in
lua/, localization/, data/features/ (the report states the dry-run output); it stays as the checked way to rename again (one run, then `validate.py` rule N1 proves no old name is left).
"""
import argparse
import os
import sys

SKIP_DIRS = {".git", ".godot", "__pycache__", "node_modules", ".playwright-mcp", ".venv", "_stage"}
SKIP_NAMES_CONTAINING = ("Style Guide",)
TEXT_EXT = {".md", ".txt", ".json", ".lua", ".csv", ".gd", ".gdshader", ".tscn", ".tres", ".godot", ".cfg", ".py", ".js", ".sh", ".html", ".yml", ".yaml", ".toml", ".import", ".po", ".manifest",
            ".map", ".svg"}
MIN_OLD_LEN = 3                      # characters, after stripping whitespace; shorter / empty / blank --old is refused


def rules(old: str, new: str):
    """(from, to) pairs, case variants of the old name; a genitive s follows automatically because the replacement is a plain substring replacement."""
    out = []
    for a, b in ((old, new), (old.upper(), new.upper()), (old.lower(), new.lower())):
        if (a, b) not in out:
            out.append((a, b))
    return out


def is_text(path: str) -> bool:
    return os.path.splitext(path)[1].lower() in TEXT_EXT


def transform(s: str, rl) -> str:
    for a, b in rl:
        s = s.replace(a, b)
    return s


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--old", required=True, help="the name to replace (case variants are handled)")
    ap.add_argument("--new", default="Hyggebyen")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--rename-files", action="store_true")
    ap.add_argument("roots", nargs="+")
    a = ap.parse_args()
    if len(a.old.strip()) < MIN_OLD_LEN or a.old != a.old.strip():
        print(f"refused: --old {a.old!r} is empty, blank, padded with whitespace or shorter than {MIN_OLD_LEN} characters: replacing it would rewrite every text file", file=sys.stderr)
        return 2
    if not a.new.strip():
        print("refused: --new is empty", file=sys.stderr)
        return 2
    if a.old.lower() == a.new.lower():
        print("old and new name are the same")
        return 2
    rl = rules(a.old, a.new)
    self_path = os.path.abspath(__file__)
    total_files = total_hits = 0
    for root in a.roots:
        for dp, dns, fns in os.walk(root):
            dns[:] = [d for d in dns if d not in SKIP_DIRS]
            for fn in fns:
                p = os.path.join(dp, fn)
                if os.path.abspath(p) == self_path or any(k in p for k in SKIP_NAMES_CONTAINING) or not is_text(p):
                    continue
                try:
                    with open(p, "r", encoding="utf-8") as f:
                        src = f.read()
                except (UnicodeDecodeError, OSError):
                    continue
                low = src.lower()
                if a.old.lower() not in low:
                    continue
                hits = sum(src.count(x) for x, _ in rl)
                total_files += 1
                total_hits += hits
                print(f"{'APPLY' if a.apply else 'DRY  '} {hits:4d}  {p}")
                if not a.apply:
                    for line in src.splitlines():
                        if a.old.lower() in line.lower():
                            print("       |", line.strip()[:150])
                            break
                else:
                    with open(p, "w", encoding="utf-8") as f:
                        f.write(transform(src, rl))
    if a.rename_files and a.apply:
        for root in a.roots:
            for dp, dns, fns in os.walk(root, topdown=False):
                dns[:] = [d for d in dns if d not in SKIP_DIRS]
                for n in fns + dns:
                    if a.old.lower() in n.lower() and not any(k in n for k in SKIP_NAMES_CONTAINING):
                        new = transform(n, rl)
                        os.rename(os.path.join(dp, n), os.path.join(dp, new))
                        print("RENAMED", os.path.join(dp, n), "->", new)
    print(f"{total_files} files, {total_hits} replacements ({'applied' if a.apply else 'dry run'})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
