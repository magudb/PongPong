#!/usr/bin/env python3
"""Pack the painted city/forest masters into the existing runtime art contracts.

This is the deterministic atlas/export stage, like pack.py and terrain.py. Artwork
comes from the saved imagegen masters; geometry, pivots and collisions stay data.
The original V5/V22 exports remain available for their generator regression tests.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

from pack import extract, window_light
from terrain import HERE, ROOT, periodic, sample

OUT = ROOT / "assets/iso_props/painted_world"
SOURCE = "tools/art/drawn/sources/"
MANIFEST: dict = {"_source": "Painted city/forest masters; docs/art/world-consistency/prompts.json; geometry and sorting from the original manifests."}


def read(path: Path) -> dict:
    return json.loads(path.read_text())


def fit(drawing: Image.Image, size: tuple[int, int], mirror: bool = False) -> Image.Image:
    """Fit an alpha island inside its existing canvas without cropping its silhouette."""
    drawing = ImageOps.mirror(drawing) if mirror else drawing.copy()
    drawing.putalpha(drawing.getchannel("A").point(lambda value: 255 if value >= 240 else (value if value > 12 else 0)))
    drawing.thumbnail((size[0] - 4, size[1] - 4), Image.Resampling.LANCZOS)
    image = Image.new("RGBA", size)
    image.alpha_composite(drawing, ((size[0] - drawing.width) // 2, size[1] - drawing.height - 2))
    return image


def write(name: str, image: Image.Image, original: dict, source: str, **extra) -> None:
    image.save(OUT / (name + ".webp"), lossless=True, method=6, exact=True)
    record = copy.deepcopy(original)
    record.update(file=name + ".webp", size=list(image.size), illustration=SOURCE + source, **extra)
    MANIFEST[name] = record


def swatch(index: int) -> np.ndarray:
    sheet = Image.open(HERE / "sources/terrain.png")
    row, col = divmod(index, 3)
    return periodic(sheet.crop((round(col * sheet.width / 3) + 4, round(row * sheet.height / 4) + 4,
                                round((col + 1) * sheet.width / 3) - 4, round((row + 1) * sheet.height / 4) - 4)))


def material(image: Image.Image, surface: np.ndarray, *, vertical: bool = False,
             period_x: bool = False, period_y: bool = False) -> Image.Image:
    """Project the same painted tile pigments over the authored native geometry."""
    old = np.asarray(image.convert("RGBA"), dtype=np.float32)
    h, w = old.shape[:2]
    y, x = np.mgrid[:h, :w]
    rgb = sample(surface, x / max(w - 1, 1) * (1 if vertical else 2), y / 512 if vertical else y / max(h - 1, 1))
    # Keep the authored joints, rope braids and contact contours, rather than
    # replacing geometry with a flat rectangular material stamp.
    luma = old[:, :, :3].mean(axis=2)
    visible = old[:, :, 3] > 128
    centre = float(np.median(luma[visible])) if visible.any() else 100.0
    contrast = np.clip(luma / max(centre, 1), .48, 1.15)
    rgb *= contrast[:, :, None]
    result = np.dstack((np.clip(rgb, 0, 255), old[:, :, 3])).astype("uint8")
    if period_x:
        edge = ((result[:, 0].astype(float) + result[:, -1]) * .5).astype("uint8")
        result[:, 0] = edge
        result[:, -1] = edge
    if period_y:
        edge = ((result[0].astype(float) + result[-1]) * .5).astype("uint8")
        result[0] = edge
        result[-1] = edge
    return Image.fromarray(result)


def city(drawings: list[Image.Image], forest: list[Image.Image], details: list[Image.Image]) -> None:
    folder = ROOT / "assets/iso_props/city"
    original = read(folder / "props.json")
    wood, bark = swatch(3), swatch(11)
    hut_roofs = {"straw": 0, "moss": 1, "dark": 2}
    for name, record in original.items():
        if name.startswith("_") or not isinstance(record, dict) or "file" not in record:
            continue
        old = Image.open(folder / record["file"]).convert("RGBA")
        size = old.size
        if record.get("kind") == "hut":
            index = 3 if name == "hut_raadhus" else hut_roofs[name.rsplit("_", 1)[1]]
            image = fit(drawings[index], size)
            write(name, image, record, "city_painted.png")
            MANIFEST[name]["apex"] = [size[0] / 2, image.getchannel("A").getbbox()[1] + 5]
            # A warm roof is not a window. Only pick amber pixels on the lower walls.
            walls = image.copy()
            a = np.asarray(walls).copy()
            a[:round(size[1] * .57), :, 3] = 0
            walls = Image.fromarray(a)
            glow, box = window_light(walls)
            pivot = record["pivot"]
            night = name + "_night"
            write(night, glow, original[night], "city_painted.png",
                  pivot=[pivot[0] - box[0], pivot[1] - box[1]], night_offset=list(box[:2]))
            MANIFEST[name]["night_offset"] = list(box[:2])
            continue
        if record.get("kind") == "hut_night":
            continue
        detail_map = {"lift_basket": 0, "lantern_hang": 1, "lamp_door": 2,
                      "fire_pit": 3, "lift_pulley": 4, "owl_shelf": 5}
        if name in detail_map:
            write(name, fit(details[detail_map[name]], size), record, "city_details_painted.png")
            continue
        mapping = {"bat_house_hanging": 4, "trunk_hole_owl": 5, "trunk_hole_owl_b": 5,
                   "market_stall_traetoppen": 6, "notice_board": 7, "planter_box": 8,
                   "planter_box_berry": 8, "log_stack": 9, "seed_basket": 10}
        if name in mapping:
            image = fit(drawings[mapping[name]], size, name in ["trunk_hole_owl_b", "planter_box_berry"])
            write(name, image, record, "city_painted.png")
        elif name.startswith("bath_tub_"):
            # Both halves use one painting and one water anchor. Their canvases
            # have different pivots because the front is sorted after Sofus.
            full = fit(drawings[11], (276, 206))
            back = full.crop((0, 0, 276, 120))
            front = full.crop((0, 86, 276, 206))
            if name.endswith("front"):
                a = np.asarray(front).copy()
                a[:round(120 * .25), :, 3] = 0
                image = Image.fromarray(a)
            else:
                image = back
            write(name, image, record, "city_painted.png")
        elif name.startswith(("foliage_front_", "canopy_top_")):
            image = Image.new("RGBA", size)
            leaf = forest[0].copy()
            if name.startswith("canopy"):
                leaf = leaf.resize((650, 520), Image.Resampling.LANCZOS)
                for x in range(-325, size[0] + 650, 440):
                    image.alpha_composite(leaf, (x, -235))
                # The same canopy clump covers both edges of the repeat.
                arr = np.asarray(image).copy()
                arr[:, -1] = arr[:, 0]
                image = Image.fromarray(arr)
            else:
                # Contain the whole alpha island: a cover crop cuts the leafy
                # silhouette into a conspicuous rectangle over the trunks.
                image = fit(leaf, size, name.endswith("b"))
                image.putalpha(image.getchannel("A").point(lambda value: round(value * .5)))
            write(name, image, record, "forest_painted.png")
        elif name.startswith(("platform_disc_", "trunk_", "bridge_deck_", "bridge_post", "rope_", "ladder_", "lift_", "owl_shelf")):
            vertical = name.startswith("trunk_")
            image = material(old, bark if vertical else wood, vertical=vertical,
                             period_x=name.startswith("bridge_deck_"),
                             period_y=name.startswith(("trunk_bark_", "rope_tile", "ladder_tile")))
            if name.startswith("platform_disc_"):
                # Grain follows the native radial boards. Sampling a narrow band
                # within the painted plank avoids a second set of crossing joints.
                y, x = np.mgrid[:size[1], :size[0]]
                px, py = record["pivot"]
                u, v = (x - px) / (size[0] / 2 - 2.6), (y - py) / (py - 2.6)
                radius = np.sqrt(u * u + v * v)
                angle = np.arctan2(v, u)
                pigment = sample(wood, radius * 2, .12 + .06 * np.sin(angle * 30))
                shade = np.asarray(old)[:, :, :3].mean(axis=2) / 163.0
                rgb = np.clip(pigment * np.clip(shade, .5, 1.12)[:, :, None], 0, 255).astype("uint8")
                pixels = np.asarray(image).copy()
                top = radius <= 1
                pixels[top, :3] = rgb[top]
                image = Image.fromarray(pixels)
            if name.startswith("trunk_foot_"):
                bark_name = name.replace("trunk_foot_", "trunk_bark_")
                new_bark = Image.open(OUT / (bark_name + ".webp")).convert("RGBA")
                neck = int(record["neck_px"])
                image.paste(new_bark.crop((0, 0, size[0], neck)), (0, 0))
            write(name, image, record, "terrain.png")
    # Use the actual drawn bat instead of retaining the old geometric stand-in.
    bats = extract(HERE / "sources/animals3.png", 4, 4)
    for name in ["bat_hang", "bat_hang_f1"]:
        rec = original[name]
        write(name, fit(bats[12].rotate(180), tuple(rec["size"]), name.endswith("f1")), rec, "animals3.png")


def forest(drawings: list[Image.Image]) -> None:
    original = read(ROOT / "assets/iso_props/props.json")
    for name, rec in original.items():
        if not isinstance(rec, dict) or "file" not in rec:
            continue
        size = tuple(rec["size"])
        if name.startswith("crown_") and "disc" in rec:
            radius = rec["disc"]["radius"]
            px, py = rec["pivot"]
            image = Image.new("RGBA", size)
            shadow = Image.new("RGBA", size)
            ImageDraw.Draw(shadow).ellipse((px + 48 - radius, py + 35 - radius * .588,
                                            px + 48 + radius, py + 35 + radius * .588), fill=(39, 34, 47, 75))
            image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(2)))
            index = {"s": 0, "m": 1, "l": 2}[name.split("_")[1]]
            crown = drawings[index].copy()
            if name.endswith("b"):
                crown = ImageOps.mirror(crown)
            crown = crown.resize((radius * 2, radius * 2), Image.Resampling.LANCZOS)
            image.alpha_composite(crown, (round(px - radius), round(py - .81 * radius - radius)))
            write(name, image, rec, "forest_painted.png")
            if name.split("_")[1] in ["s", "m"]:
                alias = name + "_solid"
                write(alias, image, rec, "forest_painted.png", visual_alias_of=name)
        else:
            mapping = {"cave_ring": 3, "cave_ring_up": 3, "runestone_dormant": 4,
                       "runestone_active": 4, "empty_bush": 6, "bush_eyes_a": 6,
                       "bush_eyes_b": 6, "pond_lily": 8}
            if name.startswith("cave_stone_"):
                mapping[name] = 7
            if name not in mapping:
                continue
            image = fit(drawings[mapping[name]], size, name.endswith(("_b", "_d", "_up")))
            if name == "runestone_active":
                pixels = np.asarray(image).astype(float)
                teal = (pixels[:, :, 1] > pixels[:, :, 0] + 8) & (pixels[:, :, 2] > pixels[:, :, 0] + 3)
                glow = Image.new("RGBA", size, (111, 214, 196, 0))
                glow.putalpha(Image.fromarray(np.uint8(teal * pixels[:, :, 3] * .8)))
                write("rune_glow", glow, original["rune_glow"], "forest_painted.png")
            elif name == "runestone_dormant":
                # Keep the carved glyph, but reserve its turquoise light for
                # the active state and its additive layer.
                pixels = np.asarray(image).copy().astype(float)
                teal = (pixels[:, :, 1] > pixels[:, :, 0] + 8) & (pixels[:, :, 2] > pixels[:, :, 0] + 3)
                grey = pixels[:, :, :3].mean(axis=2)
                pixels[teal, :3] = np.stack((grey * .78, grey * .82, grey * .89), axis=2)[teal]
                image = Image.fromarray(pixels.astype("uint8"))
            write(name, image, rec, "forest_painted.png")
    rec = {"pivot": [75, 68], "footprint": [1, 1], "proj": "ortho"}
    write("glow_mushroom_cluster", fit(drawings[5], (150, 98)), rec, "forest_painted.png")
    # Resource-only alias names must resolve to the same newly painted stones.
    alias = copy.deepcopy(MANIFEST["cave_stone_a"])
    alias["visual_alias_of"] = "cave_stone_a"
    MANIFEST["cave_stone"] = alias


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    city_drawings = extract(HERE / "sources/city_painted.png", 3, 4)
    forest_drawings = extract(HERE / "sources/forest_painted.png", 3, 3)
    details = extract(HERE / "sources/city_details_painted.png", 2, 3)
    forest(forest_drawings)
    city(city_drawings, forest_drawings, details)
    # The distant forest uses the same authored oak as the farm, softened by
    # atmospheric pigment. Keep V5's 2048x1024 canvas and lossless upload budget.
    oak = extract(HERE / "sources/nature.png", 3, 3)[0]
    far = Image.new("RGBA", (2048, 1024))
    for index, x in enumerate(range(-500, 2600, 470)):
        tree = oak.resize((790, 1160), Image.Resampling.LANCZOS)
        pixels = np.asarray(tree).copy().astype(float)
        pixels[:, :, :3] = pixels[:, :, :3] * .28 + np.array([161, 183, 133]) * .72
        pixels[:, :, 3] *= .55
        far.alpha_composite(Image.fromarray(pixels.astype("uint8")), (x, -220 + (index % 3) * 80))
    pixels = np.asarray(far).copy()
    pixels[:, -1] = pixels[:, 0]
    write("backdrop_treetop_far", Image.fromarray(pixels),
          {"pivot": [0, 0], "footprint": [0, 0], "kind": "backdrop"}, "nature.png")
    (OUT / "props.json").write_text(json.dumps(MANIFEST, indent=2) + "\n")
    # P22's base catalog also indexes newly declared gameplay art. Existing
    # generator rows stay intact; the override pack owns the painted replacements.
    base_path = ROOT / "assets/iso_props/props.json"
    base = read(base_path)
    mushroom = copy.deepcopy(MANIFEST["glow_mushroom_cluster"])
    mushroom["file"] = "painted_world/" + mushroom["file"]
    base["glow_mushroom_cluster"] = mushroom
    base_path.write_text(json.dumps(base, indent=1) + "\n")
    print("Packed", len(MANIFEST) - 1, "painted city/forest assets")


if __name__ == "__main__":
    main()
