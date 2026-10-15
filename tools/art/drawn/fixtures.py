"""Export the approved paintings into historical fixture filenames.

The recipe records the old canvas and anchor. Tile grids keep their native cells;
objects with different source canvases fit around the original ground anchor.
Only trimmed city window layers adopt the painted window bounds and offsets.
No illustration is drawn here: all visible pigments come from approved masters.
"""
from __future__ import annotations

import argparse
from functools import lru_cache
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
RECIPES = HERE / "fixture_recipes.json"


@lru_cache(maxsize=1)
def recipes() -> dict:
    return json.loads(RECIPES.read_text())["assets"]


@lru_cache(maxsize=1)
def geometry() -> dict:
    # There are no original coloured CG sprites in this archive. Channel sums
    # preserve the measured joint/contact shading; alpha preserves silhouettes.
    with np.load(HERE / "sources/fixture_geometry.npz", allow_pickle=False) as data:
        return {key: data[key] for key in data.files}


def geometry_source(path: Path) -> Image.Image:
    """Immutable geometry for exporters, avoiding repeated painted re-shading."""
    key = str(path.resolve().relative_to(ROOT))
    if key not in recipes():
        return Image.open(path).convert("RGBA")
    rec = recipes()[key]
    if key + "::alpha" in geometry():
        total = geometry()[key + "::sum"]
        base, extra = total // 3, total % 3
        rgb = np.stack([base + (extra > i) for i in range(3)], axis=2)
        return Image.fromarray(np.dstack((rgb, geometry()[key + "::alpha"])).astype("uint8"))
    # Other consumers need only the measured body bounds, never old pigments.
    image = Image.new("RGBA", rec["size"])
    if rec["body_bounds"]:
        x0, y0, x1, y1 = rec["body_bounds"]
        ImageDraw.Draw(image).rectangle((x0, y0, x1 - 1, y1 - 1), fill=(128, 128, 128, 255))
    return image


def anchored(image: Image.Image, rec: dict) -> Image.Image:
    w, h = rec["size"]
    px, py = rec["pivot"]
    sx, sy = rec["source_pivot"]
    # Keep the whole source canvas on the original canvas, with its ground pivot
    # fixed. One uniform scale avoids stretching trees, fences and buildings.
    limits = [(space / extent) for space, extent in
              [(px, sx), (w - px, image.width - sx),
               (py, sy), (h - py, image.height - sy)] if extent > 0]
    scale = min(limits)
    if scale <= 0:
        raise ValueError(f"Invalid fixture anchor: {rec}")
    image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (w, h))
    out.alpha_composite(image, (round(px - sx * scale), round(py - sy * scale)))
    return out


def render(path: str, rec: dict) -> Image.Image:
    mode = rec["mode"]
    if mode == "timber":
        from world import material, swatch
        return material(geometry_source(ROOT / path), swatch(3), vertical=True)
    image = Image.open(ROOT / rec["source"]).convert("RGBA")
    if mode == "anchored":
        return anchored(image, rec)
    if mode == "night":
        return image
    if mode == "doormat":
        if path.endswith("r1.webp"):
            # Rotate 90 degrees in the floor plane, preserving the handedness
            # of the painted sprig and braid rather than reflecting them.
            from pack import TILE_W, TILE_H
            ratio = TILE_W / TILE_H
            cx, cy = image.width / 2, image.height / 2
            image = image.transform(image.size, Image.Transform.AFFINE,
                                    (0, ratio, cx - ratio * cy,
                                     -1 / ratio, 0, cy + cx / ratio), Image.Resampling.BICUBIC)
    return image.resize(rec["size"], Image.Resampling.LANCZOS) if image.size != tuple(rec["size"]) else image


def build(check: bool = False) -> None:
    report, manifests, failures = {}, {}, []
    for path, rec in recipes().items():
        target = ROOT / path
        if rec["mode"] == "technical":
            if hashlib.sha256(target.read_bytes()).hexdigest() != rec["prior_sha256"]:
                failures.append(path + ": technical kernel changed")
            continue
        image = render(path, rec)
        # Lossless WebP keeps repeat edges and additive mask values exact.
        import io
        encoded = io.BytesIO()
        image.save(encoded, format="PNG" if target.suffix == ".png" else "WEBP", lossless=True, method=6, exact=True)
        data = encoded.getvalue()
        if check:
            if target.read_bytes() != data:
                failures.append(path + ": differs from its painted recipe")
        else:
            target.write_bytes(data)
        if rec["mode"] == "night":
            manifest_path = ROOT / rec["manifest"]
            if manifest_path not in manifests:
                manifests[manifest_path] = json.loads(manifest_path.read_text())
            manifest = manifests[manifest_path]
            painted = json.loads((ROOT / "assets/iso_props/painted_world/props.json").read_text())
            name = rec["id"]
            for key in ["size", "pivot", "night_offset"]:
                manifest[name][key] = painted[name][key]
            manifest[name.removesuffix("_night")]["night_offset"] = painted[name.removesuffix("_night")]["night_offset"]
        report[path] = {"source": rec["source"], "mode": rec["mode"], "size": list(image.size),
                        "sha256": hashlib.sha256(data).hexdigest()}
    for path, manifest in manifests.items():
        data = json.dumps(manifest, indent=1) + "\n"
        if check:
            if json.loads(path.read_text()) != manifest:
                failures.append(str(path.relative_to(ROOT)) + ": painted night offsets differ")
        else:
            path.write_text(data)
    if failures:
        raise SystemExit("\n".join(failures))
    if not check:
        (ROOT / "docs/art/style-audit/current/fixture-exports.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"PAINTED FIXTURES {'CHECK' if check else 'EXPORT'} PASS: {len(report)} re-exports, {len(recipes()) - len(report)} technical kernels preserved")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    build(parser.parse_args().check)
