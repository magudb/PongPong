#!/usr/bin/env python3
"""Pack saved paintings for the towns core's existing room-piece interface.

This exports art and its placement metadata. It does not install town gameplay.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

from pack import ROOT, HERE, extract, building_footprint, project_building
from consistency import matte, PRESET

SRC = HERE / "sources/shop_core"
OUT = ROOT / "assets/iso_props/shops/core"
DOC = ROOT / "docs/art/shop-core"
LAYOUT = HERE / "shop_core_layout.json"
GROUPS = {
    "counters": (3, 4, ["counter_pine", "counter_end", "counter_hatch"]),
    "service": (5, 4, ["brick_oven", "forge", "anvil", "mannequin", "wooden_tub"]),
    "workroom": (6, 2, ["bread_rack", "plank_stack", "workbench", "letter_desk", "pigeonhole_wall", "notice_board_indoor"]),
}
SINGLES = ["cauldron_stand", "feed_sack_stack", "hay_bale", "mail_sack", "parcel_stack", "sign_bracket", "sign_bracket"]
EMBLEMS = ["seed", "loaf", "anvil", "paw", "crystal", "chair", "thread", "log", "junk", "posthorn", "tub", "scroll", "hammer", "plank", "carrot"]


def read(path: Path) -> dict:
    return json.loads(path.read_text())


def write(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n")


def save(image: Image.Image, name: str, lossless: bool = False) -> str:
    path = OUT / (name + ".webp")
    image.save(path, lossless=lossless, quality=90, method=6, exact=True)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(PRESET)
    return path.name


def rgba_bytes(size: list[int]) -> int:
    """Conservative uncompressed upload including every mip, rather than disk bytes."""
    w, h = size
    total = 0
    while True:
        total += w * h * 4
        if w == h == 1:
            return total
        w, h = max(1, w // 2), max(1, h // 2)


def body(drawing: Image.Image, item: dict, rotation: int) -> tuple[Image.Image, list[int]]:
    drawing = matte(drawing)
    fx, fy = item["footprint"]
    if rotation % 2:
        fx, fy = fy, fx
    if item["layer"] == "wall":
        # The mounting plane remains at the floor. A sign bracket instead shares
        # its origin with the separate 96 px emblem centred below its chain.
        if item["id"] == "sign_bracket":
            drawing.thumbnail((80, 148), Image.Resampling.LANCZOS)
            # The emblem hangs under the chain, rather than under the wall post.
            a = np.asarray(drawing.getchannel("A"))
            yy, xx = np.indices(a.shape)
            side = xx > drawing.width * .75 if rotation == 0 else xx < drawing.width * .25
            y, x = np.where((a > 100) & side & (yy > drawing.height * .35))
            end = y.max()
            return drawing, [round(float(x[y >= end - 2].mean())), int(end + 44)]
        return wall_body(drawing, item, rotation)
    name = item["id"]
    if name in ("counter_pine", "counter_end", "brick_oven", "forge"):
        corner = (.78 if rotation % 2 == 0 else .22) if name == "counter_pine" else .5
        planes = [[.02, .80 if name != "counter_pine" or rotation % 2 else .70],
                  [corner, .985], [.98, .80 if name != "counter_pine" or not rotation % 2 else .70]]
        image, pivot = project_building(drawing, planes, building_footprint(fx, fy) * .82)
    else:
        max_width = round((fx + fy) * 64 * .85)
        if name == "mannequin":
            max_width = 94
        drawing.thumbnail((max_width, 210), Image.Resampling.LANCZOS)
        image = drawing
        # The floor-centre anchor sits behind the forward foot of the object.
        depth = (fx + fy) * 19 * .85
        pivot = [image.width // 2, round(image.height - depth)]
    # A few detached pencil strokes should never move a floor anchor outside
    # its canvas. Padding is metadata-preserving and does not change the paint.
    pad = 3
    canvas = Image.new("RGBA", (image.width + pad * 2, image.height + pad * 2))
    canvas.alpha_composite(image, (pad, pad))
    return canvas, [int(pivot[0] + pad), int(pivot[1] + pad)]


def wall_body(drawing: Image.Image, item: dict, rotation: int, *, face_height: int = 72,
              mount_height: int = 45) -> tuple[Image.Image, list[int]]:
    """Project a cabinet/board onto its wall axis, anchored at the FIRST wall cell.

    The towns builder positions wall pieces at that cell's edge midpoint, not
    at the multi-cell footprint centre. Verticals remain upright under the shear.
    """
    span = item["footprint"][0] * 64
    width = span * .85
    direction = 1 if rotation == 0 else -1
    lx, rx = drawing.width * .04, drawing.width * .94
    ly, ry = (drawing.height * (.78 if direction == 1 else .98),
              drawing.height * (.98 if direction == 1 else .78))
    sx = width / (rx - lx)
    sy = face_height / (drawing.height * .72)
    slope = (ry - ly) / (rx - lx)
    target_slope = direction * 38 / 64
    def forward(x, y):
        x = (x - lx) * sx
        return [x, target_slope * x + sy * (y - ly - slope * x / sx)]
    corners = np.array([forward(x, y) for x in [0, drawing.width] for y in [0, drawing.height]])
    origin = np.floor(corners.min(axis=0)).astype(int) - 3
    size = np.ceil(corners.max(axis=0)).astype(int) - origin + 3
    image = drawing.transform(tuple(size), Image.Transform.AFFINE,
        (1 / sx, 0, origin[0] / sx + lx,
         -target_slope / sy + slope / sx, 1 / sy,
         (origin[1] - target_slope * origin[0]) / sy + ly + slope * origin[0] / sx), Image.Resampling.BICUBIC)
    anchor_x = 32 - (span - width) / 2
    if direction == -1:
        anchor_x = width - anchor_x
    pivot = [round(anchor_x - origin[0]), round(target_slope * anchor_x + mount_height - origin[1])]
    return image, pivot


def heat(image: Image.Image, name: str, rotation: int) -> tuple[Image.Image, tuple] | None:
    if name in ("forge", "brick_oven") and rotation >= 2:
        return None                     # No fire shines through the solid rear.
    a = np.asarray(image, dtype=float)
    r, g, b, alpha = (a[:, :, i] for i in range(4))
    hot = np.clip((r - g - 48) / 55, 0, 1) * np.clip((g - b - 55) / 55, 0, 1)
    hot *= np.clip((r - 180) / 50, 0, 1) * alpha * .65
    mask = Image.fromarray(np.uint8(hot)).filter(ImageFilter.GaussianBlur(.5))
    bounds = mask.getbbox()
    if bounds is None:
        return None
    layer = Image.new("RGBA", image.size, (255, 156, 66, 0))
    layer.putalpha(mask)
    return layer.crop(bounds), bounds


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    DOC.mkdir(parents=True, exist_ok=True)
    contract = read(LAYOUT)
    drawings = {}
    for atlas, (rows, cols, names) in GROUPS.items():
        cells = extract(SRC / (atlas + ".png"), rows, cols)
        for row, name in enumerate(names):
            for rotation in range(cols):
                drawings[name, rotation] = (cells[row * cols + rotation], atlas)
    for index, drawing in enumerate(extract(SRC / "small.png", 2, 4)[:7]):
        name = SINGLES[index]
        drawings[name, 1 if index == 6 else 0] = (drawing, "small")
    manifest = {"_doc": "Painted core room art. IDs/footprints/layers/authored-view counts follow the I3 / towns contract; no gameplay installed.",
                "_style": "approved matte gouache and warm pencil; saved built-in imagegen paintings", "items": {}}
    sources = {}
    sizes = []
    for name, item in contract["pieces"].items():
        entry = {k: v for k, v in item.items() if k != "rot_baked"}
        entry.update(baked=list(range(item["rot_baked"])), sym="wall2" if item["layer"] == "wall" else "none",
                     mirror_ok=False, interact="none", rot={})
        for rotation in range(item["rot_baked"]):
            drawing, atlas = drawings[name, rotation]
            image, pivot = body(drawing, item, rotation)
            fp = item["footprint"]
            if rotation % 2:
                fp = list(reversed(fp))
            rec = {"file": save(image, f"{name}_r{rotation}"), "size": list(image.size), "pivot": pivot,
                   # Ground-centre sorting keeps a keeper on the rear approach
                   # behind a long counter. Its left-corner y ties the keeper.
                   "footprint": fp, "ysort": [0, 0],
                   "illustration": f"tools/art/drawn/sources/shop_core/{atlas}.png", "view": rotation, "flip": False}
            if item["layer"] == "wall" and name != "sign_bracket":
                rec.update(wall_axis=[64 if rotation == 0 else -64, 38], mounting_height_px=45, anchor="first_wall_cell")
            if name in ("forge", "brick_oven", "cauldron_stand"):
                glow = heat(image, name, rotation)
                if glow is not None:
                    night, bounds = glow
                    rec.update(night=save(night, f"{name}_r{rotation}_night", True), night_size=list(night.size), night_offset=list(bounds[:2]),
                               glow={"size": list(night.size), "center": [bounds[0] + night.width / 2, bounds[1] + night.height / 2],
                                     "color": "#ffb36b", "blend": "add", "light_hint": "at_most_one_per_room"})
                    sizes.append(list(night.size))
            sizes.append(rec["size"])
            entry["rot"][str(rotation)] = rec
        manifest["items"][name] = entry
    emblems = {"_doc": "Text-free profession badges, front-on, 96 px lossless exports; bracket is a separate piece.", "emblems": {}}
    for name, drawing in zip(EMBLEMS, extract(SRC / "emblems.png", 3, 5), strict=True):
        drawing = matte(drawing)
        drawing.thumbnail((88, 88), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (96, 96))
        canvas.alpha_composite(drawing, ((96 - drawing.width) // 2, (96 - drawing.height) // 2))
        emblems["emblems"][name] = {"file": save(canvas, "emblem_" + name, True), "size": [96, 96], "pivot": [48, 48],
                                   "illustration": "tools/art/drawn/sources/shop_core/emblems.png"}
        sizes.append([96, 96])
    write(OUT / "shops.json", manifest)
    write(OUT / "emblems.json", emblems)
    for path in sorted(SRC.glob("*.png")):
        sources[path.name] = {"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    write(DOC / "sources.json", sources)
    packing = {"pieces": len(manifest["items"]), "authored_views": sum(len(v["rot"]) for v in manifest["items"].values()),
                               "emblems": len(emblems["emblems"]), "night_layers": len(list(OUT.glob("*_night.webp"))),
                               "disk_mb": sum(p.stat().st_size for p in OUT.glob("*.webp")) / 1e6,
                               "rgba8_mips_mb": sum(map(rgba_bytes, sizes)) / 1e6}
    write(DOC / "packing.json", packing)
    if packing["disk_mb"] > contract["budgets"]["disk_mb"] or packing["rgba8_mips_mb"] > contract["budgets"]["rgba8_mips_mb"]:
        raise ValueError(f"Core shop art exceeds its existing budget: {packing}")
    print(json.dumps(read(DOC / "packing.json")))


if __name__ == "__main__":
    main()
