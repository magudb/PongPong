#!/usr/bin/env python3
"""Inventory every shipped asset and make labeled, read-only visual review pages.

These pages are inspection aids, not edited game art or an automated style score.
Run with --phase=before/after after exporting the effective Godot catalog.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/art/style-audit"
FONT = ImageFont.truetype(str(ROOT / "assets/fonts/IBMPlexMono-Regular.ttf"), 12)
TITLE = ImageFont.truetype(str(ROOT / "assets/fonts/IBMPlexMono-Regular.ttf"), 20)


def asset_roles(catalog: dict) -> dict[Path, str]:
    """Record usage, not a machine-generated aesthetic verdict."""
    roles = {}
    for group in ["props", "items", "tiles"]:
        for rec in catalog[group]:
            roles[local(rec["path"]).resolve()] = "effective-" + group
    for path in (ROOT / "assets/isometric_characters").rglob("*.webp"):
        roles[path.resolve()] = "character-sheet-or-portrait"
    roles[(ROOT / "assets/isometric_characters/shadow.png").resolve()] = "runtime-shadow-mask"
    for path in (ROOT / "assets/portraits").glob("*.webp"):
        roles[path.resolve()] = "character-selection-thumbnail"
    furniture = ROOT / "assets/iso_props/furniture/furniture.json"
    for rec in json.loads(furniture.read_text())["items"].values():
        for view in rec["rot"].values():
            roles[(furniture.parent / view["file"]).resolve()] = "furniture-view"
            if "float" in view:
                roles[(furniture.parent / view["float"]["file"]).resolve()] = "legendary-overlay"
        for tail in [".webp", "_night.webp"]:
            icon = furniture.parent / (rec["icon"].removesuffix(".webp") + tail)
            if icon.exists(): roles[icon.resolve()] = "furniture-icon"
    for path in (ROOT / "assets/iso_props/home").glob("*.webp"):
        roles[path.resolve()] = "home-upgrade-or-construction"
    # Light/ground entries are secondary textures, not necessarily catalog IDs.
    for row in catalog["props"]:
        path = local(row["path"])
        for manifest in [path.parent / "props.json"]:
            if not manifest.exists(): continue
            rec = json.loads(manifest.read_text()).get(row["id"], {})
            for key in ["glow", "ground"]:
                if "file" in rec.get(key, {}):
                    roles[(path.parent / rec[key]["file"]).resolve()] = "runtime-" + key + "-mask"
    for path in (ROOT / "assets/backdrops").glob("*_sky.png"):
        roles[path.resolve()] = "painted-sky"
    roles[(ROOT / "assets/ui/keyart/title.png").resolve()] = "title-illustration"
    for path in (ROOT / "assets/art_studies").rglob("*.webp"):
        roles[path.resolve()] = "equipment-design-study"
    return roles


def local(path: str) -> Path:
    return ROOT / path.removeprefix("res://")


def load_image(path: Path) -> Image.Image:
    with Image.open(path) as src:
        return src.convert("RGBA")


def thumb(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.copy()
    image.thumbnail(size, Image.Resampling.LANCZOS)
    return image


def pages(name: str, entries: list[tuple[str, Path]], target: Path) -> list[str]:
    cols, rows, cw, ch = 6, 5, 240, 210
    saved = []
    for start in range(0, len(entries), cols * rows):
        part = entries[start:start + cols * rows]
        canvas = Image.new("RGBA", (cols * cw, rows * ch + 50), "#eee7d8")
        draw = ImageDraw.Draw(canvas)
        draw.text((15, 12), f"{name} | {start + 1}-{start + len(part)} / {len(entries)}", font=TITLE, fill="#4b3c49")
        for index, (label, path) in enumerate(part):
            x, y = (index % cols) * cw, (index // cols) * ch + 50
            # Alternating light/dark backgrounds make pale masks and cutout rims visible.
            dark = any(word in label for word in ("glow", "halo", "night", "spark", "mist", "light"))
            draw.rectangle((x + 3, y + 3, x + cw - 3, y + 165), fill="#343448" if dark else "#f9f2e4")
            image = thumb(load_image(path), (cw - 20, 155))
            canvas.alpha_composite(image, (x + (cw - image.width) // 2, y + (165 - image.height) // 2))
            for line, text in enumerate([label[i:i + 31] for i in range(0, min(len(label), 90), 31)]):
                draw.text((x + 6, y + 170 + 13 * line), text, font=FONT, fill="#4b3c49")
        path = target / f"{name}-{start // (cols * rows) + 1:02}.webp"
        canvas.convert("RGB").save(path, quality=92, method=4)
        saved.append(str(path.relative_to(ROOT)))
    return saved


def character_pages(target: Path) -> list[str]:
    characters = sorted((ROOT / "assets/isometric_characters").glob("*/animations.json"))
    saved = []
    for start in range(0, len(characters), 6):
        canvas = Image.new("RGBA", (1800, 6 * 235 + 45), "#eee7d8")
        draw = ImageDraw.Draw(canvas)
        draw.text((12, 10), "Every character: all clip files at a middle frame; idle directions below", font=TITLE, fill="#4b3c49")
        for row, meta_path in enumerate(characters[start:start + 6]):
            meta = json.loads(meta_path.read_text())
            y = 45 + row * 235
            draw.text((8, y), meta_path.parent.name, font=TITLE, fill="#4b3c49")
            for col, (clip, spec) in enumerate(meta["animations"].items()):
                image = load_image(meta_path.parent / spec["sheet"])
                frame = int(spec["frames"]) // 2
                image = image.crop((frame * 256, 256, (frame + 1) * 256, 512))
                image = thumb(image, (108, 108))
                canvas.alpha_composite(image, (8 + col * 116, y + 24))
                draw.text((8 + col * 116, y + 130), clip[:15], font=FONT, fill="#4b3c49")
            idle = load_image(meta_path.parent / meta["animations"]["idle"]["sheet"])
            for direction in range(8):
                image = thumb(idle.crop((0, direction * 256, 256, (direction + 1) * 256)), (80, 80))
                canvas.alpha_composite(image, (8 + direction * 90, y + 146))
            portrait = load_image(meta_path.parent / "portrait.webp")
            portrait = thumb(portrait, (84, 84))
            canvas.alpha_composite(portrait, (800, y + 146))
        path = target / f"characters-{start // 6 + 1:02}.webp"
        canvas.convert("RGB").save(path, quality=94, method=4)
        saved.append(str(path.relative_to(ROOT)))
    return saved


def archive_native() -> None:
    """Compact documentation copies; pixel assertions ran on the original PNGs."""
    folder = OUT / "native"
    report = OUT / "native-captures.json"
    records = json.loads(report.read_text()) if report.exists() else {}
    for path in sorted(folder.glob("art_style_consistency_*.png")):
        if "_world_" in path.name:
            continue  # retain the eight original world screenshots
        target = path.with_suffix(".webp")
        with Image.open(path) as source:
            source.convert("RGB").save(target, quality=97, method=4)
        records[path.stem] = {"png_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                              "review_copy": str(target.relative_to(ROOT)),
                              "encoding": "WebP quality 97, documentation only; original PNG used for native render checks"}
        path.unlink()
    report.write_text(json.dumps(records, indent=2) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", choices=["before", "after"], default="before")
    parser.add_argument("--archive-native", action="store_true", help="Compact native gallery PNGs as documentation WebPs; retain original world screenshots")
    args = parser.parse_args()
    target = OUT / args.phase
    target.mkdir(parents=True, exist_ok=True)
    catalog = json.loads((OUT / f"catalog-{args.phase}.json").read_text())
    inventory = []
    errors = []
    roles = asset_roles(catalog)
    for path in sorted((ROOT / "assets").rglob("*")):
        if not path.is_file():
            continue
        rec = {"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
               "sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "kind": path.suffix, "width": "", "height": "",
               "role": roles.get(path.resolve(), "retained-export" if path.suffix in [".png", ".webp"] else "metadata-or-license")}
        try:
            if path.suffix in [".webp", ".png"]:
                with Image.open(path) as im:
                    im.load()
                    rec.update(width=im.width, height=im.height)
            elif path.suffix == ".json":
                json.loads(path.read_text())
            elif path.suffix == ".svg":
                ET.parse(path)
                rec["role"] = "theme-vector-symbol"
            elif path.suffix == ".ttf":
                ImageFont.truetype(str(path), 20)
                rec["role"] = "bundled-typeface"
        except Exception as exc:
            errors.append({"path": rec["path"], "error": str(exc)})
        inventory.append(rec)
    with (OUT / f"inventory-{args.phase}.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=list(inventory[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(inventory)
    groups = {"effective-props": [(r["id"], local(r["path"])) for r in catalog["props"]],
              "item-icons": [(r["id"], local(r["path"])) for r in catalog["items"]],
              "terrain": [(r["id"], local(r["path"])) for r in catalog["tiles"]]}
    furn_path = ROOT / "assets/iso_props/furniture/furniture.json"
    furn = json.loads(furn_path.read_text())["items"]
    groups["furniture"] = [(id_ + " r" + rotation, furn_path.parent / r["file"])
                           for id_, item in furn.items() for rotation, r in item["rot"].items()]
    home_path = ROOT / "assets/iso_props/home/home.json"
    groups["home-extra"] = [(p.stem, p) for p in home_path.parent.glob("*.webp")]
    groups["equipment-studies"] = [(p.stem, p) for p in sorted((ROOT / "assets/art_studies").rglob("*.webp"))]
    groups["backdrops-and-title"] = [(p.stem, p) for p in sorted((ROOT / "assets/backdrops").iterdir()) if p.suffix in [".png", ".webp"]]
    groups["backdrops-and-title"].append(("title", ROOT / "assets/ui/keyart/title.png"))
    named = {p.resolve() for entries in groups.values() for _, p in entries}
    groups["retained-and-other"] = [(str(p.relative_to(ROOT / "assets")), p) for p in sorted((ROOT / "assets").rglob("*"))
                                    if p.suffix in [".png", ".webp"] and p.resolve() not in named
                                    and "isometric_characters" not in p.parts and "art_studies" not in p.parts]
    saved = []
    for name, entries in groups.items():
        saved.extend(pages(name, entries, target))
    saved.extend(character_pages(target))
    report = {"phase": args.phase, "files": len(inventory), "raster_files": sum(r["kind"] in [".png", ".webp"] for r in inventory),
              "decode_errors": errors, "review_pages": saved, "groups": {k: len(v) for k, v in groups.items()},
              "note": "Technical decoding/provenance and labeled review pages. Visual verdicts require human inspection; this is not an automated style pass."}
    (OUT / f"scan-{args.phase}.json").write_text(json.dumps(report, indent=2) + "\n")
    if args.archive_native:
        archive_native()
    print(json.dumps({k: v for k, v in report.items() if k != "review_pages"}, indent=2))


if __name__ == "__main__":
    main()
