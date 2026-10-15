#!/usr/bin/env python3
"""Self-test of tools/import/write_import_stubs.py on throwaway project trees (standard library only).

    python tools/import/selftest.py          prints one "PASS <id>" / "FAIL <id>" line per check, exit 1 on any failure

Run by tests/sections/characters.gd (check characters.import_stub_tool_selftest). Every check builds its own temp tree,
so nothing in the real project is read or written.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE / "write_import_stubs.py"

results: list = []


def check(name: str, ok: bool, detail: str = "") -> None:
    results.append((name, bool(ok), detail))
    print(("PASS " if ok else "FAIL ") + name + ((" (" + detail + ")") if detail else ""))


def run(root: Path, *args: str):
    p = subprocess.run([sys.executable, str(TOOL), "--root", str(root), *args], capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


def make_char(root: Path, cid: str, clips=("idle", "walk"), portrait=True) -> Path:
    d = root / "assets" / "isometric_characters" / cid
    d.mkdir(parents=True, exist_ok=True)
    anim = {"character": cid, "animations": {c: {"frames": 4, "fps": 5, "loop": True, "sheet": c + ".webp"} for c in clips}}
    (d / "animations.json").write_text(json.dumps(anim))
    for c in clips:
        (d / (c + ".webp")).write_bytes(b"RIFF0000WEBPVP8 ")
    if portrait:
        (d / "portrait.webp").write_bytes(b"RIFF0000WEBPVP8 ")
    return d


def godot_complete(mode: int, hq: str = "false", mips: str = "true") -> str:
    """What Godot writes after the import (path / uid / dest_files plus the full parameter list)."""
    return """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://abc123"
path.s3tc="res://.godot/imported/x.s3tc.ctex"
metadata={
"imported_formats": ["s3tc_bptc"],
"vram_texture": true
}

[deps]

source_file="res://x.webp"
dest_files=["res://.godot/imported/x.s3tc.ctex"]

[params]

compress/mode=%d
compress/high_quality=%s
compress/lossy_quality=0.7
mipmaps/generate=%s
process/fix_alpha_border=true
process/size_limit=0
""" % (mode, hq, mips)


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="p05_stubs_") as tmp:
        base = Path(tmp)

        # 1. write mode creates a stub for every sheet except the portrait, content is exactly the contract
        r = base / "t1"
        d = make_char(r, "fox", ("idle", "walk", "run"))
        make_char(r, "fox_base", ("idle", "walk"))
        code, out = run(r)
        stubs = sorted(p.name for p in d.glob("*.import"))
        check("write_stubs_for_every_sheet", code == 0 and stubs == ["idle.webp.import", "run.webp.import", "walk.webp.import"], str(stubs))
        check("write_stubs_for_base_folders", (r / "assets/isometric_characters/fox_base/idle.webp.import").is_file())
        check("no_stub_for_portrait", not (d / "portrait.webp.import").exists())
        body = (d / "idle.webp.import").read_text()
        want = ['importer="texture"', 'type="CompressedTexture2D"', "compress/mode=2", "compress/high_quality=false", "mipmaps/generate=true", "process/fix_alpha_border=true"]
        check("stub_content_is_the_contract", all(w in body for w in want))
        code, out = run(r, "--check")
        check("check_passes_after_write", code == 0, out.strip().splitlines()[-1] if out.strip() else "")

        # 2. --check fails on a missing stub, a lossless one, a high-quality one, a no-mipmap one
        r = base / "t2"
        d = make_char(r, "cat", ("idle", "walk", "run", "jump"))
        run(r)
        (d / "walk.webp.import").unlink()
        code, out = run(r, "--check")
        check("check_fails_on_missing_stub", code == 1 and "walk.webp" in out, out.strip().splitlines()[0] if out.strip() else "")
        run(r)
        (d / "run.webp.import").write_text(godot_complete(0))
        code, out = run(r, "--check")
        check("check_fails_on_lossless_sheet", code == 1 and "run.webp" in out and "compress/mode=0" in out)
        (d / "run.webp.import").write_text(godot_complete(2, hq="true"))
        code, out = run(r, "--check")
        check("check_fails_on_high_quality", code == 1 and "compress/high_quality" in out)
        (d / "run.webp.import").write_text(godot_complete(2, mips="false"))
        code, out = run(r, "--check")
        check("check_fails_on_no_mipmaps", code == 1 and "mipmaps/generate" in out)

        # 3. a Godot-complete file with the preset is accepted AND never overwritten (the uid survives)
        r = base / "t3"
        d = make_char(r, "bat", ("idle",))
        (d / "idle.webp.import").write_text(godot_complete(2))
        before = (d / "idle.webp.import").read_text()
        code, out = run(r)
        check("complete_import_kept_with_uid", code == 0 and (d / "idle.webp.import").read_text() == before and "uid://abc123" in before)
        code, out = run(r, "--check")
        check("check_accepts_godot_complete_import", code == 0, out.strip().splitlines()[-1] if out.strip() else "")
        # a stale lossless import is replaced by write mode
        (d / "idle.webp.import").write_text(godot_complete(0))
        code, out = run(r)
        check("stale_lossless_is_replaced", code == 0 and "compress/mode=2" in (d / "idle.webp.import").read_text() and "replaced" in out)

        # 4. a sheet listed in animations.json but missing fails the audit; portrait must stay lossless
        r = base / "t4"
        d = make_char(r, "frog", ("idle", "walk"))
        run(r)
        (d / "walk.webp").unlink()
        (d / "walk.webp.import").unlink()
        code, out = run(r, "--check")
        check("check_fails_on_listed_but_missing_sheet", code == 1 and "walk.webp" in out and "missing" in out)
        (d / "walk.webp").write_bytes(b"RIFF0000WEBPVP8 ")
        run(r)
        (d / "portrait.webp.import").write_text(godot_complete(2))
        code, out = run(r, "--check")
        check("check_fails_on_vram_portrait", code == 1 and "portrait" in out)
        (d / "portrait.webp.import").write_text(godot_complete(0, mips="true"))
        code, out = run(r, "--check")
        check("check_accepts_lossless_portrait", code == 0, out.strip().splitlines()[-1] if out.strip() else "")

        # 5. tile atlases: minimal stub = lossless without mipmaps; a mipmapped atlas fails
        r = base / "t5"
        t = r / "assets" / "iso_tiles"
        t.mkdir(parents=True)
        (t / "grass.png").write_bytes(b"\x89PNG")
        code, out = run(r, "--check")
        check("check_fails_on_tile_atlas_without_stub", code == 1 and "grass.png" in out)
        code, out = run(r, "--only", "tiles")
        body = (t / "grass.png.import").read_text()
        check("tile_stub_is_lossless_no_mipmaps", code == 0 and "compress/mode=0" in body and "mipmaps/generate=false" in body)
        code, out = run(r, "--check")
        check("check_accepts_tile_stub", code == 0, out.strip().splitlines()[-1] if out.strip() else "")
        (t / "grass.png.import").write_text(godot_complete(0, mips="true"))
        code, out = run(r, "--check")
        check("check_fails_on_mipmapped_tile_atlas", code == 1 and "mipmaps/generate" in out)

        # Painted material exports use lossless WebP. They need the same
        # no-mipmap preset, including when an imported file has a stale preset.
        (t / "drawn_grass.webp").write_bytes(b"RIFF0000WEBPVP8L")
        code, out = run(r, "--check")
        check("check_fails_on_webp_tile_without_stub", code == 1 and "drawn_grass.webp" in out)
        code, out = run(r, "--only", "tiles")
        body = (t / "drawn_grass.webp.import").read_text()
        check("webp_tile_is_lossless_no_mipmaps", code == 0 and "compress/mode=0" in body and "mipmaps/generate=false" in body)
        (t / "drawn_grass.webp.import").write_text(godot_complete(2))
        code, out = run(r, "--check")
        check("check_fails_on_vram_webp_tile", code == 1 and "drawn_grass.webp" in out and "compress/mode=2" in out)

        # 6. wardrobe layers must stay lossless (addendum 4.4 P05 task 3)
        r = base / "t6"
        lay = r / "assets" / "wardrobe" / "layers" / "fox"
        lay.mkdir(parents=True)
        (lay / "shirt.loco.webp").write_bytes(b"RIFF0000WEBPVP8 ")
        code, out = run(r, "--check")
        check("layers_without_import_are_fine", code == 0)
        (lay / "shirt.loco.webp.import").write_text(godot_complete(0, mips="true"))
        code, out = run(r, "--check")
        check("layers_lossless_import_passes", code == 0, out.strip().splitlines()[-1] if out.strip() else "")
        for mode in (2, 4, 1):
            (lay / "shirt.loco.webp.import").write_text(godot_complete(mode))
            code, out = run(r, "--check")
            check("layers_fail_on_compress_mode_%d" % mode, code == 1 and "wardrobe/layers" in out and "compress/mode=%d" % mode in out)
        # write mode never creates a stub in a layers folder
        (lay / "shirt.loco.webp.import").unlink()
        run(r)
        check("write_never_stubs_layers", not (lay / "shirt.loco.webp.import").exists())

        # 7. an empty project is fine, a bad root is a usage error
        r = base / "t7"
        r.mkdir()
        code, out = run(r, "--check")
        check("empty_project_passes", code == 0)
        code, out = run(base / "does_not_exist", "--check")
        check("bad_root_exits_2", code == 2)

    bad = [n for n, ok, _ in results if not ok]
    print("selftest: %d checks, %d failed" % (len(results), len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
