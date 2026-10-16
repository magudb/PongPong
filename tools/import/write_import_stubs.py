#!/usr/bin/env python3
"""Godot `.import` stubs for the sprite sheets (review R.7) and the audit that keeps them honest.

Why: Godot honours a hand-written minimal `<file>.import` on the VERY FIRST import (verified in 4.7.2: only the
`.s3tc.ctex` is produced, no stale lossless cache; the 12 pack characters import in about 64 s). So the preset is written
BEFORE the first `godot --import`; there is no "import, rewrite, re-import" pass and no 400 MB of stale lossless textures.

  character clip sheets   assets/isometric_characters/<id>/<clip>.webp.import
        [remap] importer="texture" type="CompressedTexture2D"
        [params] compress/mode=2 compress/high_quality=false mipmaps/generate=true process/fix_alpha_border=true
        (S3TC: BPTC does not exist in the Compatibility renderer on macOS). EVERY folder counts, including the
        wardrobe-ready `*_base` folders. NOT portrait.webp (UI, lossless), NOT shadow.png.
  tile atlases            assets/iso_tiles/<atlas>.{png,webp}.import
        compress/mode=0 mipmaps/generate=false (periodic atlas cells would bleed into each other at mip >= 1, R.1)
  wardrobe layers         assets/wardrobe/layers/**  - NEVER a stub and NEVER VRAM compressed: tint-ready data must stay
        lossless RGBA8 (S3TC measured 14-19/255 mean error). The audit FAILS when a `.import` there carries a lossy or
        VRAM-compressed preset (compress/mode 1, 2 or 4).
  painted wardrobe        files named by assets/wardrobe/manifest.json: RGB paintings use S3TC + mipmaps, like bodies
  content files           lua/**/*.lua, data/maps/*.map  - importer="keep" stubs (the localization .csv convention):
        non-resource extensions are dropped by an export unless they are keep-imported or named in the export preset's
        filters; a missing stub is an export bug that only shows in a shipped build

Usage (no other arguments needed; the repo root is found from this file's location):
  tools/import/write_import_stubs.py             write every missing / stale stub (characters, tile atlases, keep files)
  tools/import/write_import_stubs.py --check     audit: exit 1 on ANY mismatch (run by tests/run_playtest.sh whenever
                                                 files under assets/ changed, and by tools/art/produce_all.sh after an install)
  options: --root DIR (another project root, tests), --only characters|tiles|keep (write mode), -q/--quiet

A stub is minimal on purpose: Godot adds uid/path/dest_files itself on the first import. An existing `.import` that already
carries the wanted preset (including the complete files Godot wrote after the import) is never touched, so the Godot-assigned
uid survives. Python 3.8+, standard library only.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

CHARACTER_SHEET = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
mipmaps/generate=true
process/fix_alpha_border=true
"""

TILE_ATLAS = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
mipmaps/generate=false
process/fix_alpha_border=true
"""

# compress/mode values of Godot's texture importer: 0 lossless, 1 lossy, 2 VRAM compressed, 3 VRAM uncompressed, 4 basis universal
LOSSLESS_MODES = {"0", "3"}
VRAM_MODES = {"2", "4"}

KEEP_FILE = """[remap]

importer="keep"
"""

# (directory, glob) of content files an export must ship verbatim (not imported resources): a `keep` stub is what a
# non-resource extension needs to ride into the PCK (the localization .csv files do the same, written by tools/loc/new_csv.py)
KEEP_CONTENT = [(Path("lua"), "*.lua"), (Path("data/maps"), "*.map")]

MAX_LISTED = 25   # failures printed by --check (a missing preset repeats for every sheet)

CHARACTERS = Path("assets/isometric_characters")
TILES = Path("assets/iso_tiles")
LAYERS = Path("assets/wardrobe/layers")


# ---------------------------------------------------------------- import file parsing

def parse_import(path: Path) -> dict:
    """{section: {key: raw value}} of a Godot .import (or stub) file. Values stay raw ("true", "2", '"texture"')."""
    out: dict = {}
    section = ""
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            section = m.group(1)
            out.setdefault(section, {})
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            out.setdefault(section, {})[k.strip()] = v.strip()
    return out


def unquote(v: str) -> str:
    return v[1:-1] if len(v) >= 2 and v[0] == v[-1] == '"' else v


def param(parsed: dict, key: str):
    return parsed.get("params", {}).get(key)


def import_path(asset: Path) -> Path:
    return asset.with_name(asset.name + ".import")


# ---------------------------------------------------------------- what exists

def character_dirs(root: Path) -> list:
    base = root / CHARACTERS
    if not base.is_dir():
        return []
    return sorted(d for d in base.iterdir() if d.is_dir() and not d.name.startswith("."))


def sheets_of(char_dir: Path) -> list:
    """Every clip sheet of a character folder: all *.webp except portrait.webp."""
    return sorted(f for f in char_dir.glob("*.webp") if f.name != "portrait.webp")


def tile_atlases(root: Path) -> list:
    base = root / TILES
    return sorted(f for f in base.iterdir() if f.suffix in {".png", ".webp"}) if base.is_dir() else []


def keep_files(root: Path) -> list:
    """Every content file that ships verbatim: lua/**/*.lua, data/maps/*.map."""
    out = []
    for base, pattern in KEEP_CONTENT:
        d = root / base
        if d.is_dir():
            out.extend(sorted(d.rglob(pattern)))
    return out


def problems_of_keep(f: Path) -> list:
    imp = import_path(f)
    if not imp.is_file():
        return ["no %s.import (a non-resource file needs importer=\"keep\" to be exported)" % f.name]
    if unquote(parse_import(imp).get("remap", {}).get("importer", "")) != "keep":
        return ["importer is not \"keep\""]
    return []


def has_preset(asset: Path, kind: str) -> bool:
    imp = import_path(asset)
    if not imp.is_file():
        return False
    return not problems_of_import(asset, kind)


# ---------------------------------------------------------------- audit of one import file

def problems_of_import(asset: Path, kind: str) -> list:
    """Why `<asset>.import` does not carry the preset of `kind` ('character' | 'tile'); [] when it does."""
    imp = import_path(asset)
    if not imp.is_file():
        return ["no %s (write the stub BEFORE the first import: tools/import/write_import_stubs.py)" % imp.name]
    parsed = parse_import(imp)
    bad = []
    remap = parsed.get("remap", {})
    if unquote(remap.get("importer", "")) != "texture":
        bad.append('importer is %s, want "texture"' % remap.get("importer", "missing"))
    if "type" in remap and unquote(remap["type"]) != "CompressedTexture2D":
        bad.append("type is %s, want CompressedTexture2D" % remap["type"])
    if kind == "character":
        want = {"compress/mode": "2", "compress/high_quality": "false", "mipmaps/generate": "true"}
    else:
        want = {"compress/mode": "0", "mipmaps/generate": "false"}
    for key, val in want.items():
        got = param(parsed, key)
        if got != val:
            bad.append("%s=%s, want %s" % (key, got if got is not None else "missing", val))
    fab = param(parsed, "process/fix_alpha_border")
    if fab is not None and fab != "true":
        bad.append("process/fix_alpha_border=%s, want true" % fab)
    return bad


# ---------------------------------------------------------------- audit

def check(root: Path, quiet: bool = False) -> int:
    failures: list = []
    notes: list = []
    n_dirs = n_sheets = 0

    for d in character_dirs(root):
        sheets = sheets_of(d)
        anim = d / "animations.json"
        if not sheets and not anim.is_file():
            continue
        n_dirs += 1
        listed = set()
        if anim.is_file():
            try:
                data = json.loads(anim.read_text(encoding="utf-8"))
                for clip, spec in (data.get("animations") or {}).items():
                    sheet = (spec or {}).get("sheet", clip + ".webp")
                    listed.add(sheet)
                    if not (d / sheet).is_file():
                        failures.append("%s: animations.json lists %s but the file is missing" % (d.name, sheet))
            except (ValueError, AttributeError) as e:
                failures.append("%s: animations.json is not valid (%s)" % (d.name, e))
        else:
            notes.append("%s: no animations.json (not a character folder yet?)" % d.name)
        for s in sheets:
            n_sheets += 1
            if listed and s.name not in listed:
                notes.append("%s/%s: sheet is not listed in animations.json" % (d.name, s.name))
            for why in problems_of_import(s, "character"):
                failures.append("%s/%s: %s" % (d.name, s.name, why))
        # portrait + shadow are UI / soft-alpha textures: never VRAM compressed
        portrait = d / "portrait.webp"
        if portrait.is_file() and import_path(portrait).is_file():
            mode = param(parse_import(import_path(portrait)), "compress/mode")
            if mode in VRAM_MODES:
                failures.append("%s/portrait.webp: VRAM compressed (compress/mode=%s); portraits stay lossless" % (d.name, mode))
        # a stub whose sheet is gone is harmless but noisy
        for imp in sorted(d.glob("*.webp.import")):
            if not (d / imp.name[: -len(".import")]).is_file():
                notes.append("%s/%s: orphaned import file (its sheet is gone)" % (d.name, imp.name))

    shadow = root / CHARACTERS / "shadow.png"
    if shadow.is_file() and import_path(shadow).is_file():
        mode = param(parse_import(import_path(shadow)), "compress/mode")
        if mode in VRAM_MODES:
            failures.append("shadow.png: VRAM compressed (compress/mode=%s); the soft shadow would band" % mode)

    n_tiles = 0
    for atlas in tile_atlases(root):
        n_tiles += 1
        for why in problems_of_import(atlas, "tile"):
            failures.append("iso_tiles/%s: %s" % (atlas.name, why))

    n_layers = 0
    layers = root / LAYERS
    if layers.is_dir():
        for imp in sorted(layers.rglob("*.import")):
            n_layers += 1
            mode = param(parse_import(imp), "compress/mode")
            if mode is not None and mode not in LOSSLESS_MODES:
                failures.append("%s: wardrobe layer is lossy / VRAM compressed (compress/mode=%s); tint-ready layers must stay lossless RGBA8"
                                % (imp.relative_to(root).as_posix(), mode))

    n_keep = 0
    # New RGB paintings retain pigment in S3TC; these are not the historical
    # lossless tint-index textures above. Audit exactly the manifest's files.
    n_painted = 0
    manifest = root / "assets/wardrobe/manifest.json"
    if manifest.is_file():
        for body in json.loads(manifest.read_text())["bodies"].values():
            for filename in list(body["layers"].values()) + [body["base"], body["mask"]]:
                if not filename:
                    continue
                n_painted += 1
                asset = manifest.parent / filename
                if not asset.is_file():
                    failures.append("missing painted wardrobe texture: " + str(asset.relative_to(root)))
                for why in problems_of_import(asset, "character"):
                    failures.append("%s: %s" % (asset.relative_to(root), why))

    for f in keep_files(root):
        n_keep += 1
        for why in problems_of_keep(f):
            failures.append("%s: %s" % (f.relative_to(root).as_posix(), why))

    if not quiet:
        for n in notes:
            print("note  " + n)
    if failures:
        for f in failures[:MAX_LISTED]:
            print("FAIL  " + f)
        if len(failures) > MAX_LISTED:
            print("FAIL  ... and %d more (the first problem of a kind is the cause of the rest)" % (len(failures) - MAX_LISTED))
        print("write_import_stubs --check: FAILED (%d problem(s)); %d character folders, %d sheets, %d tile atlases, %d layer imports, %d keep files looked at"
              % (len(failures), n_dirs, n_sheets, n_tiles, n_layers, n_keep))
        return 1
    if not quiet:
        print("write_import_stubs --check: ok (%d character folders, %d sheets with the S3TC preset, %d tile atlases, %d wardrobe layer imports lossless, %d painted wardrobe textures with S3TC, %d keep files)"
              % (n_dirs, n_sheets, n_tiles, n_layers, n_painted, n_keep))
    return 0


# ---------------------------------------------------------------- write

def write_stub(asset: Path, body: str, kind: str, quiet: bool, root: Path) -> str:
    """'kept' (already has the preset), 'wrote' or 'replaced' (a stale import with another preset was overwritten)."""
    imp = import_path(asset)
    if has_preset(asset, kind):
        return "kept"
    state = "replaced" if imp.is_file() else "wrote"
    imp.write_text(body, encoding="utf-8")
    if not quiet:
        print("%-8s %s" % (state, imp.relative_to(root).as_posix()))
    return state


def has_keep(f: Path) -> bool:
    """True when f.import exists and carries importer="keep"."""
    return not problems_of_keep(f)


def write_keep(f: Path, quiet: bool, root: Path) -> str:
    if has_keep(f):
        return "kept"
    imp = import_path(f)
    state = "replaced" if imp.is_file() else "wrote"
    imp.write_text(KEEP_FILE, encoding="utf-8")
    if not quiet:
        print("%-8s %s" % (state, imp.relative_to(root).as_posix()))
    return state


def write_all(root: Path, only: str, quiet: bool) -> int:
    counts = {"kept": 0, "wrote": 0, "replaced": 0}
    if only in ("all", "characters"):
        for d in character_dirs(root):
            for s in sheets_of(d):
                counts[write_stub(s, CHARACTER_SHEET, "character", quiet, root)] += 1
    if only in ("all", "tiles"):
        for a in tile_atlases(root):
            counts[write_stub(a, TILE_ATLAS, "tile", quiet, root)] += 1
    if only in ("all", "keep"):
        for f in keep_files(root):
            counts[write_keep(f, quiet, root)] += 1
    if not quiet or counts["wrote"] or counts["replaced"]:
        print("write_import_stubs: %d written, %d replaced, %d already fine" % (counts["wrote"], counts["replaced"], counts["kept"]))
    if counts["replaced"]:
        print("note  %d stale .import file(s) were replaced: delete their old cache files in .godot/imported (or the whole .godot) "
              "before the next import so no lossless texture stays behind" % counts["replaced"])
    return 0


def main(argv: list) -> int:
    ap = argparse.ArgumentParser(description="Write the S3TC / tile-atlas .import stubs before the first import, or audit them (--check).")
    ap.add_argument("--check", action="store_true", help="audit only; exit 1 on any mismatch")
    ap.add_argument("--root", default=None, help="project root (default: the repo this file lives in)")
    ap.add_argument("--only", choices=["all", "characters", "tiles", "keep"], default="all", help="write mode: which stubs")
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args(argv)
    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parents[2]
    if not root.is_dir():
        print("write_import_stubs: root %s is not a directory" % root, file=sys.stderr)
        return 2
    if args.check:
        return check(root, args.quiet)
    return write_all(root, args.only, args.quiet)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
