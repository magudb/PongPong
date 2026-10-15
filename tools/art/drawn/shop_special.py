#!/usr/bin/env python3
"""Export saved specialist-shop paintings and optional room dressing.

No artwork is synthesized here: this extracts, scales and mounts the saved
built-in imagegen masters in the existing 128:76 room-piece interface.
"""
from __future__ import annotations

import hashlib
import json
from collections import defaultdict

import numpy as np
from PIL import Image, ImageFilter

from pack import ROOT, HERE, extract
from consistency import matte, PRESET
from shop_core import body, wall_body, read, write, rgba_bytes

SRC = HERE / "sources/shop_special"
OUT = ROOT / "assets/iso_props/shops/special"
DOC = ROOT / "docs/art/shop-special"
# Native face height and bottom mounting height above the first wall cell.
WALL = {
    "shelf_wall_wide": (56, 86), "price_board": (38, 96),
    "seed_drawers_wall": (72, 58), "banner_wall": (112, 38),
    "seed_baskets_wall": (55, 82), "weapon_rack": (68, 72),
    "tool_wall": (62, 78), "potion_shelf": (60, 80),
    "tool_hooks": (46, 94), "fitting_curtain": (150, 0),
}
TABLE_WIDTH = {"scale_brass": 50, "bell_counter": 26, "flowerpot_row": 105,
               "stamp_press": 40, "bread_basket": 65, "sample_tag_stand": 28}


def mounted(drawing: Image.Image, item: dict, rotation: int) -> tuple[Image.Image, list[int]]:
    layer, name = item["layer"], item["id"]
    if layer == "wall":
        face, mount = WALL[name]
        return wall_body(matte(drawing), item, rotation, face_height=face, mount_height=mount)
    if layer == "floor":
        return body(drawing, item, rotation)
    drawing = matte(drawing)
    cap = (TABLE_WIDTH[name], 75) if layer == "tabletop" else (86, 115) if layer == "ceiling" else (64, 80)
    drawing.thumbnail(cap, Image.Resampling.LANCZOS)
    pad = 3
    image = Image.new("RGBA", (drawing.width + 6, drawing.height + 6))
    image.alpha_composite(drawing, (pad, pad))
    elevation = 60 if layer == "tabletop" else 112 if layer == "ceiling" else 6
    return image, [image.width // 2, drawing.height + pad + elevation]


def effect(image: Image.Image, name: str) -> tuple[Image.Image, tuple[int, ...]]:
    """Trim a separate additive accent; ordinary paint remains on the body."""
    raw = np.asarray(image, dtype=float)
    r, g, b, alpha = (raw[:, :, i] for i in range(4))
    yy = np.indices(alpha.shape)[0] / image.height
    pale = np.clip((np.minimum(r, g) - 165) / 70, 0, 1)
    # Steam accents only the cool wisps above the ceramic vent. Stars retain a
    # quiet amber glint; neither mask is a real-time light or a radial quad.
    select = (np.clip((b - r + 14) / 32, 0, 1) * (yy < .78)) if name == "steam_vent" else np.clip((r - b + 12) / 42, 0, 1)
    mask = Image.fromarray(np.uint8(pale * select * alpha * .48)).filter(ImageFilter.GaussianBlur(.35))
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError(f"No painted accent available: {name}")
    layer = Image.new("RGBA", image.size, (219, 232, 232, 0) if name == "steam_vent" else (255, 218, 133, 0))
    layer.putalpha(mask)
    return layer.crop(bounds), bounds


def save(image: Image.Image, stem: str, lossless: bool = False) -> str:
    path = OUT / (stem + ".webp")
    image.save(path, lossless=lossless, quality=90, method=6, exact=True)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(PRESET)
    return path.name


def main() -> None:
    contract = read(HERE / "shop_special_layout.json")
    jobs = read(DOC / "prompts.json")["jobs"]
    drawings = {}
    for job in jobs:
        images = extract(SRC / (job["name"] + ".png"), job["rows"], job["cols"])
        if len(job["ids"]) == job["rows"]:
            for row, name in enumerate(job["ids"]):
                for rot in range(job["cols"]):
                    drawings[name, rot] = (images[row * job["cols"] + rot], job["name"])
        else:
            for name, image in zip(job["ids"], images, strict=True):
                if not name.startswith("_unused"):
                    drawings[name, 0] = (image, job["name"])
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"_doc": "I4 specialist shop art; 69 pieces / 115 independent authored views. Optional dressing, no installed town gameplay.",
                "_style": "approved matte gouache and warm pencil; saved built-in imagegen paintings", "items": {}}
    sizes, sets = [], defaultdict(lambda: {"pieces": 0, "authored_views": 0, "rgba8_mips_bytes": 0})
    for name, item in contract["pieces"].items():
        entry = {k: v for k, v in item.items() if k != "rot_baked"}
        entry.update(baked=list(range(item["rot_baked"])), sym="wall2" if item["layer"] == "wall" else "none",
                     mirror_ok=False, interact="none", rot={})
        budget = sets[item["set"]]
        budget["pieces"] += 1
        for rot in range(item["rot_baked"]):
            drawing, source = drawings[name, rot]
            image, pivot = mounted(drawing, item, rot)
            fp = item["footprint"] if rot % 2 == 0 else list(reversed(item["footprint"]))
            rec = {"file": save(image, f"{name}_r{rot}"), "size": list(image.size), "pivot": pivot,
                   "footprint": fp, "ysort": [0, 19] if item["layer"] == "tabletop" else [0, 0],
                   "illustration": f"tools/art/drawn/sources/shop_special/{source}.png", "view": rot, "flip": False}
            if item["layer"] == "wall":
                rec.update(wall_axis=[64 if rot == 0 else -64, 38], mounting_height_px=WALL[name][1], anchor="first_wall_cell")
            if item["layer"] in ("tabletop", "ceiling"):
                rec["elevation_px"] = 60 if item["layer"] == "tabletop" else 112
            if name in ("steam_vent", "hanging_stars"):
                layer, bounds = effect(image, name)
                rec.update(night=save(layer, f"{name}_r{rot}_night", True), night_size=list(layer.size), night_offset=list(bounds[:2]),
                           glow={"blend": "add", "light_hint": "none", "point_lights": 0})
                sizes.append(list(layer.size))
                budget["rgba8_mips_bytes"] += rgba_bytes(list(layer.size))
            entry["rot"][str(rot)] = rec
            sizes.append(list(image.size))
            budget["authored_views"] += 1
            budget["rgba8_mips_bytes"] += rgba_bytes(list(image.size))
        manifest["items"][name] = entry
    write(OUT / "shops.json", manifest)
    write(DOC / "sources.json", {p.name: {"path": str(p.relative_to(ROOT)), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                                 for p in sorted(SRC.glob("*.png"))})
    packing = {"pieces": len(manifest["items"]), "authored_views": sum(len(v["rot"]) for v in manifest["items"].values()),
               "sets": dict(sets), "night_layers": 2, "disk_mb": sum(p.stat().st_size for p in OUT.glob("*.webp")) / 1e6,
               "rgba8_mips_mb": sum(map(rgba_bytes, sizes)) / 1e6}
    write(DOC / "packing.json", packing)
    if packing["disk_mb"] > contract["budgets"]["disk_mb"] or packing["rgba8_mips_mb"] > contract["budgets"]["rgba8_mips_mb"]:
        raise ValueError(f"Specialist art exceeds its published budget: {packing}")
    from shop_dressing import main as dressing
    dressing()
    print(json.dumps(packing))


if __name__ == "__main__":
    main()
