#!/usr/bin/env python3
"""Godot `.import` stubs for the sprite sheets (review R.7), the texture import policy of the whole assets/ tree
(review REND-03) and the audit that keeps them honest.

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
  every other texture     assets/**: the preset of the first POLICY rule that matches (see "the texture import policy"
        below); a texture no rule covers fails the audit. Bakers may write their own stubs, but the audit holds them to
        the table, and write mode patches a stale .import in place (the Godot-assigned uid survives).

Usage (no other arguments needed; the repo root is found from this file's location):
  tools/import/write_import_stubs.py             write every missing / stale stub (characters, tile atlases, keep files,
                                                 the policy presets of every other texture under assets/)
  tools/import/write_import_stubs.py --check     audit: exit 1 on ANY mismatch (run by tests/run_playtest.sh whenever
                                                 files under assets/ changed, and by tools/art/produce_all.sh after an install)
  options: --root DIR (another project root, tests), --only characters|tiles|keep|policy (write mode), -q/--quiet

A stub is minimal on purpose: Godot adds uid/path/dest_files itself on the first import. An existing `.import` that already
carries the wanted preset (including the complete files Godot wrote after the import) is never touched, and a stale one gets
only its [params] values rewritten, so the Godot-assigned uid survives (Godot re-imports a file whose parameters changed).
Bakers import `stub_for(path)` / `policy_problems(path)` from here instead of keeping their own preset strings.
Python 3.8+, standard library only.
"""
from __future__ import annotations

import argparse
import json
import os
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


# ---------------------------------------------------------------- the texture import policy (review REND-03)
#
# ONE table decides the import preset of every texture under assets/: the first rule whose glob matches the repo-relative
# path wins (`*` stays inside a folder, `**` crosses folders). The presets:
#   vram      compress/mode=2 (S3TC: DXT5, 1 byte per pixel instead of RGBA8's 4), high_quality off, mipmaps on. Painted
#             world art: character sheets, painted wardrobe, props, furniture, buildings, night layers. The camera zooms
#             out to 0.2, so these sprites are minified and need their mip chain. A full-pack round trip measured the same
#             colour error as the packs that were already S3TC (mean 6-12 / 255 on the visible pixels, festival and
#             shops 9-10) and no visible change at 2x on the largest houses and platforms.
#   backdrop  compress/mode=2, high_quality off, mipmaps as the baker chose: a sky stretched over the screen or a far layer
#             magnified by the parallax is never minified and may leave its mip chain out.
#   atlas     compress/mode=0, mipmaps off: periodic tile cells and packed frames would bleed into each other at mip >= 1
#             and must stay exact (R.1).
#   lossless  compress/mode 0 (or 3), mipmaps as the baker chose: UI, icons, portraits, the soft character shadow,
#             tint-ready layers, and the few world textures whose smooth gradients band under DXT (measured: rings in the
#             grey lantern light kernel, a shifted alpha band in the combat telegraphs). A texture without an .import gets
#             this preset from [importer_defaults] in project.godot.
POLICY = [
    ("assets/wardrobe/layers/**", "lossless"),
    ("assets/isometric_characters/*/portrait.webp", "lossless"),
    ("assets/isometric_characters/shadow.png", "lossless"),
    ("assets/isometric_characters/**", "vram"),
    ("assets/wardrobe/**", "vram"),
    ("assets/iso_tiles/**", "atlas"),
    ("assets/held_equipment/**", "atlas"),
    ("assets/art_studies/**", "atlas"),
    ("assets/iso_props/lantern_light.png", "lossless"),
    ("assets/iso_props/telegraph_*.png", "lossless"),
    ("assets/iso_props/**", "vram"),
    ("assets/backdrops/**", "backdrop"),
    ("assets/icons/**", "lossless"),
    ("assets/portraits/**", "lossless"),
    ("assets/ui/**", "lossless"),
]

# preset -> {param: accepted raw values}; the first value is the one write mode sets. Unlisted params are the baker's choice.
PRESETS = {
    "vram": {"compress/mode": ("2",), "compress/high_quality": ("false",), "mipmaps/generate": ("true",)},
    "backdrop": {"compress/mode": ("2",), "compress/high_quality": ("false",)},
    "atlas": {"compress/mode": ("0",), "mipmaps/generate": ("false",)},
    "lossless": {"compress/mode": ("0", "3")},
}
STUBS = {"vram": CHARACTER_SHEET, "backdrop": CHARACTER_SHEET, "atlas": TILE_ATLAS}
DEFAULT_PRESET = "lossless"   # what Godot imports a texture without an .import as ([importer_defaults] in project.godot)

TEXTURE_SUFFIXES = {".png", ".webp", ".jpg", ".jpeg", ".svg", ".tga", ".bmp", ".exr", ".hdr"}

# The textures' share of the exported PCK (review REPO-02), estimated from the files and the policy: a VRAM-compressed
# texture is stored as raw DXT5 blocks (16 bytes per 4x4 block, every mip level), a lossless one about as big as its
# source file. --check fails above the budget, so the package only grows on purpose: raise it here, in the same commit as
# the art that needs it, and say why. Measured with the Windows preset in 4.7.2 (review REPO-02): the estimate (1894 MB)
# is within 0.2 % of the textures' .ctex files in the exported PCK (1897 MB of a 1916 MB PCK; audio, scripts and data add
# about 19 MB). Nearly all of it is the character and wardrobe sheets (raw DXT5, fast to load; the download is zipped).
PCK_TEXTURE_BUDGET_MB = 1950


def _glob_re(pattern: str):
    out = ""
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
        elif pattern.startswith("**", i):
            out += ".*"
            i += 2
        elif pattern[i] == "*":
            out += "[^/]*"
            i += 1
        else:
            out += re.escape(pattern[i])
            i += 1
    return re.compile(out + r"\Z")


_POLICY_RE = [(_glob_re(g), preset) for g, preset in POLICY]


def preset_of(rel: str):
    """The POLICY preset of a repo-relative texture path ('assets/iso_props/x.webp'), None when no rule covers it."""
    for rx, preset in _POLICY_RE:
        if rx.match(rel):
            return preset
    return None


def image_size(path: Path):
    """(width, height) of a PNG or WebP from its header (standard library only), None for anything else."""
    with path.open("rb") as f:
        b = f.read(64)
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return int.from_bytes(b[16:20], "big"), int.from_bytes(b[20:24], "big")
    if b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        chunk = b[12:16]
        if chunk == b"VP8X":
            return int.from_bytes(b[24:27], "little") + 1, int.from_bytes(b[27:30], "little") + 1
        if chunk == b"VP8L":
            bits = int.from_bytes(b[21:25], "little")
            return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
        if chunk == b"VP8 ":
            return int.from_bytes(b[26:28], "little") & 0x3FFF, int.from_bytes(b[28:30], "little") & 0x3FFF
    return None


def dxt5_bytes(w: int, h: int, mipmaps: bool) -> int:
    total = 0
    while True:
        total += ((w + 3) // 4) * ((h + 3) // 4) * 16
        if not mipmaps or (w == 1 and h == 1):
            return total
        w, h = max(1, w // 2), max(1, h // 2)


def export_excluded(root: Path) -> list:
    """The exclude_filter globs of the first export preset (what the PCK leaves out), as compiled regexes."""
    cfg = root / "export_presets.cfg"
    if not cfg.is_file():
        return []
    m = re.search(r'^exclude_filter="([^"]*)"', cfg.read_text(encoding="utf-8"), re.M)
    return [_glob_re(g.strip().replace("*", "**")) for g in (m.group(1).split(",") if m else []) if g.strip()]


def texture_payload(root: Path) -> dict:
    """{preset: estimated bytes in the exported PCK} of every exported texture under assets/."""
    out: dict = {}
    excluded = export_excluded(root)
    for tex in textures(root):
        rel = tex.relative_to(root).as_posix()
        if any(rx.match(rel) for rx in excluded):
            continue
        preset = preset_of(rel) or DEFAULT_PRESET
        imp = import_path(tex)
        prm = parse_import(imp).get("params", {}) if imp.is_file() else {}
        size = image_size(tex)
        if prm.get("compress/mode") in VRAM_MODES and size is not None:
            n = dxt5_bytes(size[0], size[1], prm.get("mipmaps/generate", "true") == "true")
        else:
            n = tex.stat().st_size
        out[preset] = out.get(preset, 0) + n
    return out


def textures(root: Path) -> list:
    """Every texture under assets/ that Godot imports (folders below a .gdignore are skipped)."""
    out = []
    base = root / "assets"
    for dirpath, dirnames, filenames in os.walk(base):
        if (Path(dirpath) / ".gdignore").exists():
            dirnames[:] = []
            continue
        dirnames.sort()
        out.extend(Path(dirpath) / f for f in sorted(filenames) if Path(f).suffix.lower() in TEXTURE_SUFFIXES)
    return out


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


def _rel(asset: Path, root=None) -> str:
    root = Path(root) if root is not None else Path(__file__).resolve().parents[2]
    return Path(os.path.abspath(asset)).relative_to(Path(os.path.abspath(root))).as_posix()


def stub_for(asset, root=None) -> str:
    """The minimal .import stub of the POLICY preset of `asset` (a path inside the project), for bakers that write their
    stubs before the first import. "" for the lossless preset: [importer_defaults] already gives it, no stub needed."""
    preset = preset_of(_rel(Path(asset), root))
    if preset is None:
        raise ValueError("no import policy rule covers %s: add one to POLICY in tools/import/write_import_stubs.py" % asset)
    return STUBS.get(preset, "")


def ensure_policy(asset, root=None) -> str:
    """Give `asset` the .import its POLICY preset needs (bakers call this after writing a texture): 'kept', 'wrote' (a new
    stub) or 'replaced' (a stale .import got the preset's parameters, its uid kept)."""
    root = Path(root) if root is not None else Path(__file__).resolve().parents[2]
    preset = preset_of(_rel(Path(asset), root))
    if preset is None:
        raise ValueError("no import policy rule covers %s: add one to POLICY in tools/import/write_import_stubs.py" % asset)
    return write_stub(Path(asset), STUBS.get(preset, ""), preset, True, root)


def policy_problems(asset, root=None) -> list:
    """Why the .import of `asset` disagrees with its POLICY preset; [] when it agrees (bakers' stale-stub checks)."""
    preset = preset_of(_rel(Path(asset), root))
    if preset is None:
        return ["no import policy rule covers it"]
    return problems_of_import(Path(asset), preset)


# ---------------------------------------------------------------- audit of one import file

KIND_PRESET = {"character": "vram", "tile": "atlas"}


def problems_of_import(asset: Path, kind: str) -> list:
    """Why `<asset>.import` does not carry the preset of `kind` (a PRESETS key; 'character' = vram, 'tile' = atlas); []
    when it does. A missing .import is fine only for the preset Godot's [importer_defaults] gives."""
    preset = KIND_PRESET.get(kind, kind)
    imp = import_path(asset)
    if not imp.is_file():
        if preset == DEFAULT_PRESET:
            return []
        return ["no %s (write the stub BEFORE the first import: tools/import/write_import_stubs.py)" % imp.name]
    parsed = parse_import(imp)
    bad = []
    remap = parsed.get("remap", {})
    if unquote(remap.get("importer", "")) != "texture":
        bad.append('importer is %s, want "texture"' % remap.get("importer", "missing"))
    if "type" in remap and unquote(remap["type"]) != "CompressedTexture2D":
        bad.append("type is %s, want CompressedTexture2D" % remap["type"])
    for key, vals in PRESETS[preset].items():
        got = param(parsed, key)
        if got not in vals:
            bad.append("%s=%s, want %s" % (key, got if got is not None else "missing", " or ".join(vals)))
    fab = param(parsed, "process/fix_alpha_border")
    if fab is not None and fab != "true":
        bad.append("process/fix_alpha_border=%s, want true" % fab)
    return bad


# ---------------------------------------------------------------- audit

def check(root: Path, quiet: bool = False) -> int:
    failures: list = []
    notes: list = []
    n_dirs = n_sheets = 0
    audited: set = set()   # textures the dedicated audits below already held to their preset

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
            audited.add(s)
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
        audited.add(atlas)
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
                audited.add(asset)
                for why in problems_of_import(asset, "character"):
                    failures.append("%s: %s" % (asset.relative_to(root), why))

    for f in keep_files(root):
        n_keep += 1
        for why in problems_of_keep(f):
            failures.append("%s: %s" % (f.relative_to(root).as_posix(), why))

    # every other texture: the POLICY table
    by_preset: dict = {}
    for tex in textures(root):
        rel = tex.relative_to(root).as_posix()
        preset = preset_of(rel)
        if preset is None:
            failures.append("%s: no import policy rule covers it (add one to POLICY in tools/import/write_import_stubs.py)" % rel)
            continue
        by_preset[preset] = by_preset.get(preset, 0) + 1
        if tex in audited:
            continue
        for why in problems_of_import(tex, preset):
            failures.append("%s: %s (policy preset %s)" % (rel, why, preset))
    n_policy = sum(by_preset.values())
    payload = texture_payload(root)
    payload_mb = sum(payload.values()) / 1e6
    if PCK_TEXTURE_BUDGET_MB and payload_mb > PCK_TEXTURE_BUDGET_MB:
        failures.append("exported textures weigh about %.0f MB, above the %g MB budget (PCK_TEXTURE_BUDGET_MB: raise it on purpose, in the commit that needs it): %s"
                        % (payload_mb, PCK_TEXTURE_BUDGET_MB, ", ".join("%s %.0f MB" % (k, v / 1e6) for k, v in sorted(payload.items()))))

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
        print("write_import_stubs --check: ok (%d character folders, %d sheets with the S3TC preset, %d tile atlases, %d wardrobe layer imports lossless, %d painted wardrobe textures with S3TC, %d keep files; %d textures follow the import policy: %s; exported textures about %.0f MB of the %g MB budget)"
              % (n_dirs, n_sheets, n_tiles, n_layers, n_painted, n_keep, n_policy,
                 ", ".join("%s %d" % (k, by_preset[k]) for k in sorted(by_preset)), payload_mb, PCK_TEXTURE_BUDGET_MB))
    return 0


# ---------------------------------------------------------------- write

def patch_params(imp: Path, preset: str) -> None:
    """Rewrite the [params] values of an existing .import that disagree with `preset` (the first accepted value), adding
    missing keys; everything else - uid, path, dest_files, the other parameters - stays, so the Godot uid survives and
    Godot re-imports the file because its parameters changed."""
    want = PRESETS[preset]
    lines = imp.read_text(encoding="utf-8").splitlines()
    section = ""
    seen = set()
    end_of_params = None
    for i, line in enumerate(lines):
        m = re.match(r"^\[(.+)\]$", line.strip())
        if m:
            section = m.group(1)
            continue
        if section == "params":
            end_of_params = i + 1
            if "=" in line:
                key, val = (x.strip() for x in line.split("=", 1))
                if key in want:
                    seen.add(key)
                    if val not in want[key]:
                        lines[i] = "%s=%s" % (key, want[key][0])
    missing = ["%s=%s" % (k, v[0]) for k, v in want.items() if k not in seen]
    if missing:
        if end_of_params is None:
            lines += ["", "[params]", ""]
            end_of_params = len(lines)
        lines[end_of_params:end_of_params] = missing
    imp.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_stub(asset: Path, body: str, kind: str, quiet: bool, root: Path) -> str:
    """'kept' (already has the preset), 'wrote' (a new stub) or 'replaced' (a stale import got the preset's parameter
    values, its uid kept)."""
    imp = import_path(asset)
    if not problems_of_import(asset, kind):
        return "kept"
    if imp.is_file():
        patch_params(imp, KIND_PRESET.get(kind, kind))
        state = "replaced"
    else:
        imp.write_text(body, encoding="utf-8")
        state = "wrote"
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
    if only in ("all", "policy"):
        layers = root / LAYERS
        for tex in textures(root):
            preset = preset_of(tex.relative_to(root).as_posix())
            if preset is None or layers in tex.parents:
                continue   # no rule: --check names it; layers: never a stub (see the header)
            counts[write_stub(tex, STUBS.get(preset, ""), preset, quiet, root)] += 1
    if not quiet or counts["wrote"] or counts["replaced"]:
        print("write_import_stubs: %d written, %d replaced, %d already fine" % (counts["wrote"], counts["replaced"], counts["kept"]))
    if counts["replaced"]:
        print("note  %d stale .import file(s) got the preset's parameters (uid kept); the next godot --import re-imports them" % counts["replaced"])
    return 0


def main(argv: list) -> int:
    ap = argparse.ArgumentParser(description="Write the S3TC / tile-atlas .import stubs before the first import, or audit them (--check).")
    ap.add_argument("--check", action="store_true", help="audit only; exit 1 on any mismatch")
    ap.add_argument("--root", default=None, help="project root (default: the repo this file lives in)")
    ap.add_argument("--only", choices=["all", "characters", "tiles", "keep", "policy"], default="all", help="write mode: which stubs")
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
