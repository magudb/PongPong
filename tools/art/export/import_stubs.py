#!/usr/bin/env python3
"""Inline Godot `.import` stub writer of the art exporter (review R.7; equivalent of tools/import/write_import_stubs.py of P05).

Godot honours a hand-written minimal `.import` on the VERY FIRST import (verified in 4.7.2 by the review: only the
`.s3tc.ctex` is produced, no stale lossless cache), so the exporter writes the stub BEFORE the first `godot --import`:

  character clip sheets   assets/isometric_characters/<id>/<clip>.webp.import   VRAM-compressed S3TC, mipmaps on
                          (compress/mode=2, high_quality=false).  NOT portrait.webp, NOT shadow.png, never layers.
  tile atlases            assets/iso_tiles/<terrain>.png.import                 lossless, mipmaps OFF (periodic atlas
                          cells would bleed into each other at mip >= 1, review R.1)

Everything else (props, icons, portraits, key art) uses the project defaults and needs no stub.
Only importer, type and the params that matter are written; Godot adds uid/path/dest_files itself.  An existing `.import`
that already carries the wanted preset is left alone (it holds the Godot-assigned uid).
"""
from __future__ import annotations
import re
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


def param(text: str, key: str):
    m = re.search(r'^' + re.escape(key) + r'=(.+)$', text, re.M)
    return m.group(1).strip() if m else None


def has_preset(import_file: Path, want: dict) -> bool:
    """True when an existing .import already carries every wanted param (so it must not be overwritten)."""
    if not import_file.exists():
        return False
    t = import_file.read_text()
    return all(param(t, k) == v for k, v in want.items())


S3TC_WANT = {'compress/mode': '2', 'compress/high_quality': 'false'}
TILE_WANT = {'compress/mode': '0', 'mipmaps/generate': 'false'}


def write_stub(sheet: Path, body: str, want: dict) -> bool:
    """Write `<sheet>.import` unless it already has the wanted preset.  Returns True when a file was written."""
    imp = sheet.with_name(sheet.name + '.import')
    if has_preset(imp, want):
        return False
    imp.write_text(body)
    return True


def write_character_stubs(char_dir: Path) -> list:
    """S3TC stub next to every clip sheet of one character folder (all *.webp except portrait.webp)."""
    written = []
    for f in sorted(Path(char_dir).glob('*.webp')):
        if f.name == 'portrait.webp':
            continue
        if write_stub(f, CHARACTER_SHEET, S3TC_WANT):
            written.append(f.name + '.import')
    return written


def write_tile_stubs(tiles_dir: Path) -> list:
    """No-mipmap lossless stub next to every tile atlas png of assets/iso_tiles."""
    written = []
    for f in sorted(Path(tiles_dir).glob('*.png')):
        if write_stub(f, TILE_ATLAS, TILE_WANT):
            written.append(f.name + '.import')
    return written


if __name__ == '__main__':
    import sys
    if len(sys.argv) < 3 or sys.argv[1] not in ('characters', 'tiles'):
        raise SystemExit('usage: import_stubs.py characters|tiles DIR   (characters: a folder with clip sheets; tiles: assets/iso_tiles)')
    fn = write_character_stubs if sys.argv[1] == 'characters' else write_tile_stubs
    for w in fn(Path(sys.argv[2])):
        print('wrote', w)
