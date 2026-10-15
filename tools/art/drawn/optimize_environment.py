#!/usr/bin/env python3
"""Export compact environment textures from full-colour masters, preserving alpha.

Run once after rebuilding the storybook backgrounds or root giant tree crown.
The source files are retained under sources/environment_masters/; this script
always reads those masters so repeated runs never compound quantization.
"""
from pathlib import Path
import json
import re

import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[3]
MASTERS = Path(__file__).resolve().parent / "sources/environment_masters"
ASSETS = [f"assets/backdrops/{name}_sky.png" for name in
          ["cave", "forest", "hyggebyen", "home", "farm"]]


def build() -> dict:
    rows = []
    for relative in ASSETS:
        master = MASTERS / Path(relative).name
        if not master.exists():
            raise FileNotFoundError(f"Missing full-colour master: {master}")
        source = Image.open(master).convert("RGBA")
        if "/backdrops/" in relative:
            # Keep the existing native sky contract; the generated masters
            # have a taller aspect ratio, so crop centrally rather than stretch.
            source = ImageOps.fit(source, (1920, 1080), method=Image.Resampling.LANCZOS)
        pixels = np.asarray(source)
        rgb = source.convert("RGB")
        colours = 128 if "/backdrops/" in relative else 256
        indexed = rgb.quantize(colors=colours, method=Image.Quantize.MEDIANCUT,
                               dither=Image.Dither.NONE)
        target = ROOT / relative
        if "/iso_props/" in relative:
            target = target.with_suffix(".webp")
        if np.all(pixels[:, :, 3] == 255):
            indexed.save(target, optimize=True)
        else:
            reduced = indexed.convert("RGBA")
            reduced.putalpha(source.getchannel("A"))
            reduced.save(target, lossless=True, method=6)
        if target.suffix == ".webp":
            manifest_path = ROOT / "assets/iso_props/props.json"
            manifest = json.loads(manifest_path.read_text())
            manifest["tree_giant_crown"]["file"] = target.name
            manifest_path.write_text(json.dumps(manifest, indent=1) + "\n")
            (ROOT / relative).unlink(missing_ok=True)
            (ROOT / (relative + ".import")).unlink(missing_ok=True)
        if "/backdrops/" in relative:
            # Backgrounds use the same S3TC/mipmap preset as the farm's far
            # layer. Lossless upload of a 1920x1080 sky alone costs 8.3 MB,
            # exceeding the unchanged 20 MB farm texture-memory budget.
            stub = target.with_name(target.name + ".import")
            body = stub.read_text() if stub.exists() else '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
            for key, value in {"compress/mode": "2", "compress/high_quality": "false",
                               "mipmaps/generate": "true", "process/fix_alpha_border": "true"}.items():
                pattern = r"(?m)^" + re.escape(key) + r"=.*$"
                if re.search(pattern, body):
                    body = re.sub(pattern, key + "=" + value, body)
                else:
                    body += key + "=" + value + "\n"
            if not stub.exists() or stub.read_text() != body:
                stub.write_text(body)
        packed = np.asarray(Image.open(target).convert("RGBA"))
        assert packed.shape == pixels.shape
        assert np.array_equal(packed[:, :, 3], pixels[:, :, 3]), relative
        visible = pixels[:, :, 3] > 24
        delta = np.abs(packed[:, :, :3].astype(float) - pixels[:, :, :3])
        row = {"asset": str(target.relative_to(ROOT)), "master": str(master.relative_to(ROOT)),
               "before_bytes": master.stat().st_size, "after_bytes": target.stat().st_size,
               "mean_visible_rgb_error": round(float(delta[visible].mean()), 3),
               "p99_visible_rgb_error": round(float(np.quantile(delta[visible], .99)), 3),
               "alpha_identical": True, "palette_colours": colours, "size": list(source.size),
               "import": "S3TC with mipmaps" if "/backdrops/" in relative else "lossless"}
        rows.append(row)
        print(f"optimized {relative}: {row['before_bytes']} -> {row['after_bytes']} bytes; mean RGB error {row['mean_visible_rgb_error']}", flush=True)
    # Compatibility paths now receive the approved drawings too. Never restore
    # the old terrain/crown masters over a reviewed painted fixture library.
    from fixtures import build as fixtures
    fixtures()
    rows.extend({"asset": path, **rec} for path, rec in json.loads((ROOT / "docs/art/style-audit/current/fixture-exports.json").read_text()).items())
    total = sum(p.stat().st_size for folder in ["iso_tiles", "iso_props", "backdrops"]
                for p in (ROOT / "assets" / folder).iterdir()
                if p.suffix in {".png", ".webp", ".json"})
    result = {"assets": rows, "top_level_environment_bytes": total, "budget_bytes": 40000000}
    (Path(__file__).resolve().parent / "environment-export.json").write_text(
        json.dumps(result, indent=2) + "\n")
    print(f"environment bytes: {total} / 40000000", flush=True)
    if total >= 40000000:
        raise SystemExit("Environment export exceeds its painted fixture disk budget")
    return result


if __name__ == "__main__":
    build()
