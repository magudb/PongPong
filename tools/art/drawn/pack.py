#!/usr/bin/env python3
"""Package the painted turnarounds as the game's native sprite atlases.

The imagegen drawings are the artwork; this only extracts alpha islands, fits
them to the existing pivots, and bakes a small continuous 2D puppet deformation.
No runtime shader, image generation, 3D model, or new sprite API is involved.
Run with tools/art/.venv/bin/python tools/art/drawn/pack.py.
"""
from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SOURCES = HERE / "sources"
CHARACTERS = ROOT / "assets/isometric_characters"
# Read the game's geometry instead of maintaining a second projection ratio.
_iso_source = (ROOT / "scripts/world2d/iso.gd").read_text()
TILE_W, TILE_H = (float(re.search(r"const " + name + r"\s*:=\s*(\d+)", _iso_source)[1])
                  for name in ["TILE_W", "TILE_H"])
QUADRUPEDS = {"capybara", "calf", "lamb", "puppy", "fawn"}
PACK = {"bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara",
        "fox", "raccoon", "penguin", "hedgehog", "frog"}
HEIGHTS = {"bat": 153, "bunny": 125, "calf": 139, "capybara": 141,
           "chick": 87, "duck": 98, "fawn": 131, "fox_cub": 136,
           "hen": 112, "kitten": 113, "lamb": 126, "lysesvamp": 133,
           "owl": 129, "puppy": 138, "snurresvamp": 190,
           "tornebusk": 157, "ugleoje": 160}
CAST = {
    "heroes": ["fox", "fairy", "hobbit_pip", "fairy_mayor"],
    "players2": ["rabbit", "hedgehog", "squirrel", "fairy_stardust"],
    "players3": ["fairy_dusk", "hobbit_moss", "hobbit_bramble", "fairy_lily"],
    "fairies1": ["fairy_baker", "fairy_shopkeeper", "fairy_king", "fairy_wizard"],
    "fairies2": ["fairy_builder", "fairy_furnisher", "fairy_tailor", "mouse_pippin"],
    "villagers1": ["cat_morfar_mis", "bear_guard", "rabbit_farmer", "raccoon_smith"],
    "villagers2": ["penguin_postman", "cat", "bear", "raccoon"],
    "pack": ["penguin", "monkey", "capybara", "frog"],
    "animals1": ["chick", "hen", "duck", "kitten"],
    "animals2": ["bunny", "puppy", "fox_cub", "lamb"],
    "animals3": ["calf", "fawn", "owl", "bat"],
    "creatures": ["ugleoje", "tornebusk", "lysesvamp", "snurresvamp"],
}
# Five authored views: front, front-left, left profile, rear-left and straight back.
# Three opposite-side views are mirrored; the N entry is replaced by its own drawing.
VIEWS = [(0, False), (1, False), (2, False), (3, False),
         (3, True), (3, True), (2, True), (1, True)]
NORTH_GROUPS = {
    "backs1": ["heroes", "players2", "players3", "fairies1"],
    "backs2": ["fairies2", "villagers1", "villagers2", "pack"],
    "backs3": ["animals1", "animals2", "animals3", "creatures"],
}
YY, XX = np.mgrid[:256, :256].astype(np.float32)


def extract(path: Path, rows: int, columns: int) -> list[Image.Image]:
    """Find whole figures, including drawings that stray over nominal grid lines.

    Keeping the original alpha islands avoids chopping hair, feet or chimneys.
    Tiny detached accents are assigned to the closest primary silhouette.
    """
    rgba = np.array(Image.open(path).convert("RGBA"))
    labels, _ = ndimage.label(rgba[:, :, 3] > 24)
    counts = np.bincount(labels.ravel())
    primary = sorted(range(1, len(counts)), key=lambda n: -counts[n])[:rows * columns]
    if len(primary) != rows * columns or min(counts[n] for n in primary) < 400:
        raise ValueError(f"{path}: expected {rows * columns} substantial separate drawings")
    boxes = ndimage.find_objects(labels)
    primary.sort(key=lambda n: sum((boxes[n - 1][0].start, boxes[n - 1][0].stop)))
    ordered = []
    for row in range(rows):
        ordered.extend(sorted(primary[row * columns:(row + 1) * columns],
                              key=lambda n: boxes[n - 1][1].start))
    seeds = np.where(np.isin(labels, primary), labels, 0)
    nearest = ndimage.distance_transform_edt(seeds == 0, return_distances=False, return_indices=True)
    owner = seeds[tuple(nearest)]
    images = []
    for n in ordered:
        mask = owner == n
        visible = mask & (rgba[:, :, 3] > 24)
        y, x = np.where(visible)
        x0, x1 = max(0, int(x.min()) - 2), min(rgba.shape[1], int(x.max()) + 3)
        y0, y1 = max(0, int(y.min()) - 2), min(rgba.shape[0], int(y.max()) + 3)
        crop = rgba[y0:y1, x0:x1].copy()
        crop[:, :, 3] *= mask[y0:y1, x0:x1]
        # Fully transparent RGB from the generator is irrelevant to the artwork.
        crop[crop[:, :, 3] == 0, :3] = 0
        images.append(Image.fromarray(crop))
    return images


def fitted(image: Image.Image, height: int, feet: int) -> Image.Image:
    scale = min(height / image.height, 218 / image.width)
    size = (round(image.width * scale), round(image.height * scale))
    image = image.resize(size, Image.Resampling.LANCZOS)
    alpha = np.asarray(image)[:, :, 3]
    y, _ = np.where(alpha > 24)
    _, foot_x = np.where((alpha > 24) & (np.indices(alpha.shape)[0] > y.max() - max(5, round(size[1] * .09))))
    ground_x = (float(foot_x.min()) + float(foot_x.max())) * .5
    canvas = Image.new("RGBA", (256, 256))
    canvas.alpha_composite(image, (round(127.5 - ground_x), feet + 1 - size[1]))
    return canvas


def outlined(image: Image.Image) -> Image.Image:
    """A clean two-pixel separation band survives the game's S3TC mipmaps."""
    image = image.copy()
    alpha = image.getchannel("A").point(lambda v: v if v > 32 else 0)
    image.putalpha(alpha)
    outer = alpha.point(lambda v: 255 if v > 0 else 0).filter(ImageFilter.MaxFilter(5))
    rim = Image.new("RGBA", image.size, (75, 60, 73, 0))
    rim.putalpha(outer.point(lambda v: 140 if v else 0))
    rim.alpha_composite(image)
    return rim


def puppet(base: Image.Image, clip: str, frame: int, frames: int, height: int, feet: int) -> Image.Image:
    """Bake smooth weighted motion, never cut the illustration into rigid pieces."""
    phase = frame / max(frames, 1)
    wave = math.sin(phase * math.tau)
    pulse = math.sin((frame + .5) / max(frames, 1) * math.pi)
    u = (XX - 127.5) / (height * .5)
    v = (YY - (feet - height)) / height
    legs = np.clip((v - .72) / .26, 0, 1)
    left = np.exp(-((u + .45) / .28) ** 2)
    right = np.exp(-((u - .45) / .28) ** 2)
    arms = np.exp(-((np.abs(u) - .7) / .3) ** 2 - ((v - .69) / .16) ** 2)
    head = np.exp(-((v - .3) / .35) ** 4)
    dx = np.zeros_like(XX)
    dy = np.zeros_like(YY)
    sx, sy, lift, lean = 1., 1., 0., 0.
    if clip in ("walk", "run"):
        stride = 4.5 if clip == "walk" else 7.
        dx += legs * (right - left) * wave * stride
        dy -= legs * (left * max(wave, 0) + right * max(-wave, 0)) * stride
        dy += arms * np.sign(u) * wave * 3.5
        dx += head * wave * .8
        sy = 1 - abs(wave) * .018
        lean = wave * .012
    elif clip in ("interact", "attack"):
        reach = 8. if clip == "interact" else 14.
        dx -= arms * pulse * reach
        dy -= arms * pulse * reach * .7
        lean = -.035 * pulse
        dy += head * pulse * 1.5
    elif clip == "celebrate":
        dy -= arms * pulse * 17.
        dx += arms * np.sign(u) * pulse * 3.
        sy = 1 + wave * .025
        lift = max(wave, 0) * 2.
    elif clip in ("hover", "fly", "takeoff", "flight_land"):
        dx += arms * np.sign(u) * wave * 4.
        sy = 1 + wave * .012
        lift = 4 + wave * 2.
    elif clip == "jump":
        sy = 1 + wave * .055
        lift = pulse * 8.
        dy -= arms * pulse * 6.
    elif clip == "fall":
        sy = 1.03 + wave * .012
        dy -= arms * 5.
    elif clip == "land":
        sy = 1 - pulse * .06
        sx = 1 + pulse * .025
    elif clip == "sleep":
        sy = .88 + wave * .008
        sx = 1.025
        lean = .04
    elif clip == "hit":
        lean = wave * .065
        sy = 1 - pulse * .025
    elif clip == "spin":
        lean = wave * .04
        sx = 1 + wave * .025
        dy += head * math.cos(phase * math.tau) * 1.3
        dx += arms * math.cos(phase * math.tau) * 3.
    elif clip == "talk":
        dy += head * wave * 1.5
        dy -= arms * max(wave, 0) * 3.
        sy = 1 + wave * .006
    else:
        sx = 1 + wave * .008
        sy = 1 + wave * .006
        dx += head * wave * .45
    sample_y = feet + (YY - feet + lift - dy) / sy
    sample_x = 127.5 + (XX - 127.5 - dx - (feet - YY) * lean) / sx
    a = np.asarray(base, dtype=np.float32) / 255
    a[:, :, :3] *= a[:, :, 3:4]
    result = np.stack([ndimage.map_coordinates(a[:, :, k], [sample_y, sample_x], order=1,
                                              mode="constant", cval=0) for k in range(4)], axis=-1)
    result[:, :, :3] /= np.maximum(result[:, :, 3:4], 1 / 255)
    return outlined(Image.fromarray(np.uint8(np.clip(result * 255, 0, 255))))


def save_webp(image: Image.Image, path: Path, quality: int = 97, method: int = 2) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "WEBP", quality=quality, method=method, exact=True)


def align_rows(cells: list[Image.Image]) -> list[Image.Image]:
    """Opposed silhouettes balance about the ground pivot, including long tails."""
    for row in range(4):
        centers = []
        for index in (row, row + 4):
            _, x = np.where(np.asarray(cells[index])[:, :, 3] > 24)
            centers.append((float(x.min()) + float(x.max())) * .5)
        shift = round((255 - sum(centers)) * .5)
        if shift:
            for index in (row, row + 4):
                moved = Image.new("RGBA", (256, 256))
                moved.alpha_composite(cells[index], (shift, 0))
                cells[index] = moved
    return cells


def character(name: str, drawings: list[Image.Image], source: str, north: Image.Image,
              north_source: str, portraits_only: bool = False) -> None:
    folder = CHARACTERS / name
    metadata = json.loads((folder / "animations.json").read_text())
    # Fixed measurements make repeated builds independent of installed output.
    height = HEIGHTS.get(name, 168)
    feet = 219 if name in QUADRUPEDS else (215 if name == "lysesvamp" else 207)
    bases = [fitted(ImageOps.mirror(drawings[view]) if mirror else drawings[view], height, feet)
             for view, mirror in VIEWS]
    bases[4] = fitted(north, height, feet)
    for clip, spec in (metadata["animations"].items() if not portraits_only else []):
        frames = spec["frames"]
        atlas = Image.new("RGBA", (256 * frames, 2048))
        for frame in range(frames):
            cells = [puppet(bases[(row + frame) % 8] if clip == "spin" else bases[row],
                            clip, frame, frames, height, feet) for row in range(8)]
            for row, cell in enumerate(align_rows(cells)):
                atlas.alpha_composite(cell, (frame * 256, row * 256))
        save_webp(atlas, folder / spec["sheet"])
    # A head-and-shoulders crop, with breathing room at the top and sides.
    front = drawings[0]
    bust = front.crop((0, 0, front.width, round(front.height * .77)))
    bust.thumbnail((228, 248), Image.Resampling.LANCZOS)
    portrait = Image.new("RGBA", (256, 256))
    portrait.alpha_composite(bust, ((256 - bust.width) // 2, 256 - bust.height))
    if name in PACK:
        # The pack keeps a full-body thumbnail as well as its dialogue bust.
        save_webp(fitted(front, 224, 246), folder / "portrait.webp")
        save_webp(portrait, ROOT / "assets/portraits" / (name + ".webp"))
    else:
        save_webp(portrait, folder / "portrait.webp")
    metadata["source"] = "Painted imagegen turnaround + offline continuous 2D puppet bake"
    metadata["illustration"] = {"source": "tools/art/drawn/sources/" + source + ".png",
                                "views": ["front", "front_left", "left", "rear_left", "back"],
                                "opposite_views": "mirrored",
                                "north_source": "tools/art/drawn/sources/" + north_source + ".png"}
    (folder / "animations.json").write_text(json.dumps(metadata, indent=2) + "\n")
    print("packed character", name, flush=True)


def prop_sprite(image: Image.Image, width: int, height: int, pivot: tuple[int, int],
                name: str, footprint: tuple[int, int], manifest: dict, mirror: bool = False) -> None:
    if mirror:
        image = ImageOps.mirror(image)
    image = image.copy()
    image.thumbnail((width - 8, height - 8), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (width, height))
    canvas.alpha_composite(image, ((width - image.width) // 2, height - 4 - image.height))
    target = ROOT / "assets/iso_props/drawn" / (name + ".webp")
    save_webp(canvas, target)
    manifest[name] = {"file": target.name, "size": [width, height], "pivot": list(pivot),
                      "footprint": list(footprint), "proj": "iso"}
    if name.startswith("house_"):
        glow, bounds = window_light(canvas)
        glow_path = target.with_name(name + "_glow.webp")
        save_webp(glow, glow_path)
        manifest[name]["glow"] = {"file": glow_path.name,
                                   "center": [bounds[0] + glow.width * .5, bounds[1] + glow.height * .5],
                                   "size": list(glow.size), "color": "#ffffff", "blend": "add"}


def window_light(image: Image.Image) -> tuple[Image.Image, tuple[int, int, int, int]]:
    """An additive mask from the painted amber windows, in their new locations."""
    a = np.asarray(image, dtype=np.float32)
    warm = np.clip((a[:, :, 0] - a[:, :, 2] - 60) / 140, 0, 1)
    warm *= np.clip((a[:, :, 1] - 100) / 120, 0, 1) * a[:, :, 3] * .45
    alpha = Image.fromarray(np.uint8(warm)).filter(ImageFilter.GaussianBlur(1.2))
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("painted windows produced no night light")
    glow = Image.new("RGBA", image.size, (255, 206, 128, 0))
    glow.putalpha(alpha)
    return glow.crop(bounds), bounds


def building_footprint(fx: int, fy: int) -> np.ndarray:
    """The same centre-relative T/R/B/L corners as Iso.iso_footprint()."""
    x, y = (fx - fy) * TILE_W / 4, (fx + fy) * TILE_H / 4
    width, side_y = (fx + fy) * TILE_W / 4, (fx - fy) * TILE_H / 4
    return np.array([[-x, -y], [width, side_y], [x, y], [-width, -side_y]])


def project_building(drawing: Image.Image, planes: list, footprint: np.ndarray) -> tuple[Image.Image, list[int]]:
    """Align both wall planes with the tile axes while keeping verticals upright.

    Each facade receives one affine projection. Unlike tracing the ragged alpha
    bottom, the measured wall junctions keep windows, balconies, and roof eaves
    parallel. Potted plants and steps retain their small natural overhangs.
    """
    source = np.array(planes) * [drawing.width, drawing.height]
    left, front, right = source
    target_left, target_front, target_right = footprint[[3, 2, 1]]
    horizontal = (target_right[0] - target_left[0]) / (right[0] - left[0])
    scale_left = (target_front[0] - target_left[0]) / (front[0] - left[0])
    scale_right = (target_right[0] - target_front[0]) / (right[0] - front[0])
    source_slopes = [(left[1] - front[1]) / (left[0] - front[0]),
                     (right[1] - front[1]) / (right[0] - front[0])]

    def forward(x: float, y: float) -> tuple[float, float]:
        side = 0 if x < front[0] else 1
        scale_x = scale_left if side == 0 else scale_right
        screen_x = target_front[0] + (x - front[0]) * scale_x
        ground_y = target_front[1] - abs(screen_x - target_front[0]) * (TILE_H / TILE_W)
        source_y = front[1] + (x - front[0]) * source_slopes[side]
        return screen_x, ground_y + (y - source_y) * horizontal

    corners = np.array([forward(x, y) for x in [0, front[0], drawing.width]
                        for y in [0, drawing.height]])
    origin = np.floor(corners.min(axis=0)).astype(int) - 6
    size = np.ceil(corners.max(axis=0)).astype(int) - origin + 6
    yy, xx = np.mgrid[:size[1], :size[0]]
    world_x, world_y = xx + origin[0], yy + origin[1]
    sample_x = front[0] + (world_x - target_front[0]) / np.where(world_x < target_front[0], scale_left, scale_right)
    source_base = front[1] + (sample_x - front[0]) * np.where(sample_x < front[0], source_slopes[0], source_slopes[1])
    ground_y = target_front[1] - np.abs(world_x - target_front[0]) * (TILE_H / TILE_W)
    sample_y = source_base + (world_y - ground_y) / horizontal
    raw = np.asarray(drawing, dtype=np.float32) / 255
    raw[:, :, :3] *= raw[:, :, 3:4]
    sampled = np.stack([ndimage.map_coordinates(raw[:, :, k], [sample_y, sample_x],
                                                order=1, mode="constant", cval=0)
                        for k in range(4)], axis=-1)
    sampled[:, :, :3] /= np.maximum(sampled[:, :, 3:4], 1 / 255)
    image = Image.fromarray(np.uint8(np.clip(sampled * 255, 0, 255)))
    # Trim transparent padding only. The pivot stays the footprint centre.
    bounds = image.getchannel("A").getbbox()
    image = image.crop(bounds)
    pivot = [-int(origin[0]) - bounds[0], -int(origin[1]) - bounds[1]]
    return image, pivot


def building_ground(footprint: np.ndarray) -> tuple[Image.Image, list[int]]:
    """Soft soil contact and an upper-left-lit cast shadow, on the ground plane."""
    offset = np.array([23., 14.])
    origin = np.floor(footprint.min(axis=0) - 26).astype(int)
    end = np.ceil(footprint.max(axis=0) + offset + 32).astype(int)
    size = tuple(end - origin)
    points = [tuple(point - origin) for point in footprint]
    contact = Image.new("L", size)
    ImageDraw.Draw(contact).polygon(points, fill=255)
    soil = contact.filter(ImageFilter.GaussianBlur(10))
    shadow = Image.new("L", size)
    # The projected roof shadow extends toward screen lower-right.
    painter = ImageDraw.Draw(shadow)
    painter.polygon(points, fill=255)
    painter.polygon([tuple(point + offset - origin) for point in footprint], fill=255)
    for i in range(4):
        edge = footprint[[i, (i + 1) % 4]]
        painter.polygon([tuple(point - origin) for point in [edge[0], edge[1], edge[1] + offset, edge[0] + offset]], fill=255)
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    yy, xx = np.mgrid[:size[1], :size[0]]
    # Slight pigment variation removes a mechanically smooth oval/polygon edge.
    grain = .92 + .06 * np.sin(xx * .31 + np.sin(yy * .17)) * np.cos(yy * .23)
    rgba = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    rgba[:, :, :3] = [74, 66, 56]
    rgba[:, :, 3] = np.uint8(np.clip((np.asarray(soil) * .13 + np.asarray(shadow) * .25) * grain, 0, 255))
    return Image.fromarray(rgba), [-int(origin[0]), -int(origin[1])]


def building_sprite(drawing: Image.Image, name: str, fx: int, fy: int, planes: list, manifest: dict) -> None:
    footprint = building_footprint(fx, fy)
    image, pivot = project_building(drawing, planes, footprint)
    folder = ROOT / "assets/iso_props/drawn"
    save_webp(image, folder / (name + ".webp"))
    ground, ground_pivot = building_ground(footprint)
    save_webp(ground, folder / (name + "_ground.webp"))
    glow, bounds = window_light(image)
    save_webp(glow, folder / (name + "_glow.webp"))
    manifest[name] = {
        "file": name + ".webp", "size": list(image.size), "pivot": pivot,
        "footprint": [fx, fy], "proj": "iso",
        "ground": {"file": name + "_ground.webp", "pivot": ground_pivot},
        "base_corners": (footprint[[3, 2, 1]] + pivot).tolist(),
        "glow": {"file": name + "_glow.webp",
                 "center": [bounds[0] + glow.width * .5, bounds[1] + glow.height * .5],
                 "size": list(glow.size), "color": "#ffffff", "blend": "add"},
    }


def props() -> None:
    manifest = {"_source": "Painted sprites, tools/art/drawn/sources; existing Lua collision and y-sort contracts."}
    buildings = extract(SOURCES / "buildings.png", 2, 2)
    planes = json.loads((HERE / "building_planes.json").read_text())
    for i, (name, fx, fy) in enumerate([
        ("house_farm", 3, 2), ("house_mushroom_rose", 2, 2),
        ("house_mushroom_lavender", 2, 2), ("house_mushroom_mint", 2, 2),
    ]):
        building_sprite(buildings[i], name, fx, fy, planes[name], manifest)
    nature = extract(SOURCES / "nature.png", 3, 3)
    recipes = [
        (0, "tree_oak_farm", 230, 280, (115, 260), False),
        (0, "tree_oak_farm_b", 230, 280, (115, 260), True),
        (1, "tree_blossom_hyggebyen", 230, 280, (115, 260), False),
        (2, "tree_pine_forest", 190, 290, (95, 270), False),
        (2, "tree_pine_forest_b", 190, 290, (95, 270), True),
        (2, "tree_twisted", 190, 290, (95, 270), False),
        (3, "bush_farm", 112, 90, (56, 76), False),
        (3, "bush_berry", 112, 90, (56, 76), True),
        (3, "bush_forest", 112, 90, (56, 76), False),
        (4, "rock_grey", 112, 92, (56, 76), False),
        (4, "rock_mossy", 112, 92, (56, 76), True),
        (4, "rock_dark", 112, 92, (56, 76), False),
        (5, "lantern_post", 100, 172, (72, 155), False),
        (6, "fence_x", 130, 106, (65, 78), False),
        (6, "fence_z", 130, 106, (65, 78), True),
        (7, "scarecrow", 120, 155, (60, 143), False),
        (8, "signpost", 86, 118, (43, 106), False),
    ]
    for index, name, width, height, pivot, mirror in recipes:
        prop_sprite(nature[index], width, height, pivot, name, (1, 1), manifest, mirror)
    (ROOT / "assets/iso_props/drawn/props.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("packed", len(manifest) - 1, "world props", flush=True)


def homes() -> None:
    """Fit painted houses above the existing door-centred stone foundations.

    The foundation is the actual collision footprint. Keeping that ground plane
    makes upgrades and y-sorting work with organically drawn eaves and plants.
    Rooflines and the rest of the silhouette come entirely from the paintings.
    """
    folder = ROOT / "assets/iso_props/home"
    manifest_path = folder / "home.json"
    manifest = json.loads(manifest_path.read_text())
    drawings = sum((extract(SOURCES / (name + ".png"), 2, 2)
                    for name in ["homes1", "homes2", "homes3"]), [])[:10]
    # Sample the existing stone floor material, without its transparent diamond edges.
    stone = Image.open(ROOT / "assets/iso_tiles/floor_stone.png").convert("RGB")
    stone = stone.crop((stone.width // 2 - 8, stone.height // 2 - 8,
                        stone.width // 2 + 8, stone.height // 2 + 8))
    for tier, drawing in zip(manifest["tiers"], drawings):
        exterior = tier["exterior"]
        width, height = exterior["size"]
        px, py = exterior["pivot"]
        x0, z0, x1, z1 = tier["footprint_rect"]
        points = [(px + 64 * (x - z), py + 37.6 * (x + z))
                  for x, z in [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]]
        # A thin, textured stone footing supports the painted building, and keeps
        # the exact game-space footprint readable at its base.
        foundation = Image.new("RGBA", (width, height))
        for y in range(0, height, 16):
            for x in range(0, width, 16):
                foundation.paste(stone, (x, y))
        foundation_mask = Image.new("L", (width, height))
        ImageDraw.Draw(foundation_mask).polygon(points, fill=255)
        foundation.putalpha(foundation_mask)
        ygrid, xgrid = np.mgrid[:height, :width]
        # Reproject the drawing's base to the actual isometric front edges.
        # A dedicated door control point keeps its centre on the saved anchor.
        front_x = px + 64 * (x1 - z1)
        front_y = py + 37.6 * (x1 + z1)
        source_x = np.interp(np.arange(width),
                             [points[3][0], px, front_x, points[1][0]],
                             [drawing.width * .03, drawing.width * .30,
                              drawing.width * .53, drawing.width * .97])
        # np.interp clamps beyond its end points; extrapolate instead, or the
        # last painted column would become a streak along the canvas edges.
        left_of = np.arange(width) < points[3][0]
        right_of = np.arange(width) > points[1][0]
        source_x[left_of] = drawing.width * .03 + (np.arange(width)[left_of] - points[3][0]) * (drawing.width * .27 / (px - points[3][0]))
        source_x[right_of] = drawing.width * .97 + (np.arange(width)[right_of] - points[1][0]) * (drawing.width * .44 / (points[1][0] - front_x))
        ground = front_y - np.abs(np.arange(width) - front_x) * (37.6 / 64)
        source_ground = drawing.height * .99 - np.abs(source_x - drawing.width * .53) * (drawing.height * .13 / (drawing.width * .47))
        raw = np.asarray(drawing, dtype=np.float32) / 255
        visible = raw[:, :, 3] > .1
        bottom = np.where(visible, np.arange(drawing.height)[:, None], 0).max(axis=0).astype(float)
        fallback = drawing.height * .99 - np.abs(np.arange(drawing.width) - drawing.width * .53) * (drawing.height * .13 / (drawing.width * .47))
        bottom = np.where(bottom > drawing.height * .72, bottom, fallback)
        bottom = ndimage.gaussian_filter1d(bottom, drawing.width * .018)
        source_ground = np.interp(source_x, np.arange(drawing.width), bottom)
        top = np.where(visible, np.arange(drawing.height)[:, None], drawing.height).min(axis=0)
        source_top = np.interp(source_x, np.arange(drawing.width), top)
        valid = (source_top < drawing.height) & (source_ground > source_top + 5)
        vertical_scale = float(np.min((ground[valid] - 4) / (source_ground[valid] - source_top[valid])))
        sample_x = np.broadcast_to(source_x, (height, width))
        sample_y = source_ground[None, :] - (ground[None, :] - ygrid) / vertical_scale
        raw[:, :, :3] *= raw[:, :, 3:4]
        sampled = np.stack([ndimage.map_coordinates(raw[:, :, k], [sample_y, sample_x],
                                                    order=1, mode="constant", cval=0)
                            for k in range(4)], axis=-1)
        sampled[:, :, :3] /= np.maximum(sampled[:, :, 3:4], 1 / 255)
        rgba = np.uint8(np.clip(sampled * 255, 0, 255))
        limit = ground[None, :] + 16
        rgba[:, :, 3] = np.where(ygrid <= limit, rgba[:, :, 3], 0)
        foundation.alpha_composite(Image.fromarray(rgba))
        save_webp(foundation, folder / exterior["day"], quality=90, method=6)
        # Additive night light is derived from the new windows and lanterns,
        # so the old geometric house's windows cannot shine through this art.
        glow, bounds = window_light(foundation)
        save_webp(glow, folder / exterior["night"])
        exterior["night_offset"] = list(bounds[:2])
        exterior["night_size"] = list(glow.size)
        exterior["illustration"] = "tools/art/drawn/sources/homes%d.png" % ((tier["tier"] - 1) // 4 + 1)
        print("packed home tier", tier["tier"], flush=True)
    manifest_path.write_text(json.dumps(manifest, indent=1) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=["characters", "props", "homes"])
    parser.add_argument("--sheet", choices=list(CAST), nargs="+")
    parser.add_argument("--portraits-only", action="store_true")
    args = parser.parse_args()
    if args.only in (None, "characters"):
        north_cache = {}
        for sheet, cast in CAST.items():
            if args.sheet and sheet not in args.sheet:
                continue
            path = SOURCES / (sheet + ".png")
            if not path.exists():
                raise FileNotFoundError(path)
            drawings = extract(path, 4, 4)
            north_source, north_sheets = next((name, sheets) for name, sheets in NORTH_GROUPS.items() if sheet in sheets)
            if north_source not in north_cache:
                north_cache[north_source] = extract(SOURCES / (north_source + ".png"), 4, 4)
            norths = north_cache[north_source]
            for row, name in enumerate(cast):
                character(name, drawings[row * 4:(row + 1) * 4], sheet,
                          norths[north_sheets.index(sheet) * 4 + row], north_source, args.portraits_only)
    if args.only in (None, "props"):
        props()
    if args.only in (None, "homes"):
        homes()


if __name__ == "__main__":
    main()
