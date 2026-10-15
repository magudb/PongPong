"""Project painted material swatches into continuous terrain atlases.

The twelve source swatches are a 3 by 4 sheet. Each material covers the complete
four-tile period, so atlas cells are adjacent pieces, rather than random stamps.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
ISO = (ROOT / "scripts/world2d/iso.gd").read_text()


def geometry(name: str) -> int:
    return int(re.search(r"const " + name + r"\s*:=\s*(\d+)", ISO)[1])


TW, TH = geometry("TILE_W"), geometry("TILE_H")
CW, CH = geometry("TILE_CELL_W"), geometry("TILE_CELL_H")
OW, OH = geometry("ORTHO_W"), geometry("ORTHO_H")
OCW, OCH = OW + 16, OH + 8  # ArtCatalog.ORTHO_CELL's filtering padding.


def periodic(image: Image.Image) -> np.ndarray:
    """Periodic-plus-smooth decomposition removes a swatch's boundary step.

    Solving the periodic Poisson equation removes the broad lighting mismatch
    without mirroring leaves, smearing the join, or repeating each tile's detail.
    """
    pixels = np.asarray(image.convert("RGB"), dtype=float)
    h, w, _ = pixels.shape
    border = np.zeros_like(pixels)
    border[0] = pixels[-1] - pixels[0]
    border[-1] = -border[0]
    border[:, 0] += pixels[:, -1] - pixels[:, 0]
    border[:, -1] -= pixels[:, -1] - pixels[:, 0]
    denominator = (2 * np.cos(2 * np.pi * np.arange(h) / h)[:, None]
                   + 2 * np.cos(2 * np.pi * np.arange(w) / w)[None, :] - 4)
    denominator[0, 0] = 1
    smooth = np.fft.fft2(border, axes=(0, 1)) / denominator[:, :, None]
    smooth[0, 0] = 0
    return np.clip(pixels - np.fft.ifft2(smooth, axes=(0, 1)).real, 0, 255)


def sample(surface: np.ndarray, u: np.ndarray, v: np.ndarray) -> np.ndarray:
    h, w, _ = surface.shape
    coords = [np.mod(v * h, h), np.mod(u * w, w)]
    return np.stack([ndimage.map_coordinates(surface[:, :, k], coords,
                     order=1, mode="grid-wrap") for k in range(3)], axis=-1)


def flowers(surface: np.ndarray, town: bool = False) -> np.ndarray:
    image = Image.fromarray(surface.astype("uint8"))
    painter = ImageDraw.Draw(image)
    rng = np.random.default_rng(31)
    for x, y in rng.integers(18, image.width - 18, (22, 2)):
        for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3)):
            painter.ellipse((x + dx - 2, y + dy - 2, x + dx + 2, y + dy + 2),
                            fill=(222, 165, 166) if town else (236, 226, 191))
        painter.ellipse((x - 1, y - 1, x + 1, y + 1), fill=(185, 146, 68))
    return np.asarray(image, dtype=float)


def atlas(surface: np.ndarray, ortho: bool = False, period: int = 4,
          phase: int | None = None) -> Image.Image:
    cw, ch = (OCW, OCH) if ortho else (CW, CH)
    yy, xx = np.mgrid[:ch, :cw]
    dx, dy = xx + .5 - cw / 2, yy + .5 - ch / 2
    if ortho:
        u, v = dx / OW, dy / OH
        alpha = np.ones((ch, cw))
    else:
        u, v = (dx / (TW / 2) + dy / (TH / 2)) / 2, (dy / (TH / 2) - dx / (TW / 2)) / 2
        distance = (1 - np.abs(dx) / (TW / 2) - np.abs(dy) / (TH / 2)) / np.sqrt(4 / TW**2 + 4 / TH**2)
        alpha = np.clip(distance + 1.9, 0, 1)  # Same 1.4 px overscan as PlaceholderArt.
    output = np.zeros((ch * period, cw * period, 4), dtype="uint8")
    for j in range(period):
        for i in range(period):
            su, sv = (u + i + .5) / period, (v + j + .5) / period
            if phase is not None:
                theta = phase * np.pi / 2
                su = su + .008 * np.cos(theta + sv * 2 * np.pi)
                sv = sv + .006 * np.sin(theta + su * 2 * np.pi)
            rgb = sample(surface, su, sv)
            tile = output[j * ch:(j + 1) * ch, i * cw:(i + 1) * cw]
            tile[:, :, :3] = np.uint8(np.clip(rgb, 0, 255))
            tile[:, :, 3] = np.uint8(alpha * 255)
    return Image.fromarray(output)


def edges(bark: np.ndarray, timber: np.ndarray) -> None:
    folder = ROOT / "assets/iso_props/drawn_terrain"
    folder.mkdir(exist_ok=True)
    manifest_path = folder / "props.json"
    manifest = {"_source": "Bark sidewalls and timber bridge decks from tools/art/drawn/sources/terrain.png"}
    for face, width, height, pivot in (("sw", 79, 143, [73, 13]),
                                       ("se", 79, 143, [6, 13]),
                                       ("corner", 146, 146, [73, 13])):
        yy, xx = np.mgrid[:height, :width]
        dx, dy = xx + .5 - pivot[0], yy + .5 - pivot[1]
        along = np.abs(dx) / (TW / 2)
        down = dy - TH / 2 * (1 - along)
        rgb = sample(bark, along, down / 84)
        # The grain stays vertical on both facades; no dark seams at tile joins.
        light = np.where(dx < 0, .89, 1.02) * (1 - .23 * np.clip(down / 84, 0, 1))
        rgb *= light[:, :, None]
        moss = np.exp(-np.maximum(down, 0) / 5) * .36
        rgb = rgb * (1 - moss[:, :, None]) + np.array([94, 104, 52]) * moss[:, :, None]
        alpha = np.clip(np.minimum.reduce([along * 64 + .6, (1 - along) * 64 + .6,
                                           down + .6, 84.6 - down]), 0, 1)
        if face != "corner":
            alpha *= (dx < .6) if face == "sw" else (dx > -.6)
        rgba = np.dstack((np.clip(rgb, 0, 255), alpha * 255)).astype("uint8")
        name = "platform_" + face
        Image.fromarray(rgba).save(folder / (name + ".webp"), lossless=True)
        manifest[name] = {"file": name + ".webp", "size": [width, height],
                          "pivot": pivot, "footprint": [1, 1], "proj": "iso"}
    for along_z in (False, True):
        # A bridge cell is one timber diamond with two weathered posts. Project
        # both deck and post grain from the paintings, preserving the old pivot.
        yy, xx = np.mgrid[:142, :138]
        dx, dy = xx + .5 - 69, yy + .5 - 100
        u, v = (dx / (TW / 2) + dy / (TH / 2)) / 2, (dy / (TH / 2) - dx / (TW / 2)) / 2
        rgb = sample(timber, (v if along_z else u) + .5, (u if along_z else v) + .5)
        distance = (1 - np.abs(dx) / (TW / 2) - np.abs(dy) / (TH / 2)) / np.sqrt(4 / TW**2 + 4 / TH**2)
        alpha = np.clip(distance + .5, 0, 1)
        image = Image.fromarray(np.dstack((rgb, alpha * 255)).astype("uint8"))
        along = np.array([-1 if along_z else 1, TH / TW], dtype=float)
        along /= np.linalg.norm(along)
        side = np.array([along[1], -along[0]])
        posts = [np.array([69, 100]) + side * 36 * sign + along * 10 for sign in (-1, 1)]
        for px, py in sorted(posts, key=lambda p: p[1]):
            mask = Image.new("L", image.size)
            painter = ImageDraw.Draw(mask)
            painter.polygon([(px - 4, py), (px + 4, py + 1), (px + 3, py - 49),
                             (px - 3, py - 51)], fill=255)
            painter.ellipse((px - 5, py - 55, px + 5, py - 48), fill=255)
            wood = sample(bark, (xx - px) / 32, (yy - py) / 100) * 1.1
            post = Image.fromarray(np.dstack((np.clip(wood, 0, 255), np.asarray(mask))).astype("uint8"))
            image.alpha_composite(post)
        name = "bridge_z" if along_z else "bridge_x"
        image.save(folder / (name + ".webp"), lossless=True)
        manifest[name] = {"file": name + ".webp", "size": [138, 142], "pivot": [69, 100],
                          "footprint": [1, 1], "proj": "iso"}
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")


def build() -> None:
    source = Image.open(HERE / "sources/terrain.png").convert("RGB")
    swatches = []
    for row in range(4):
        for col in range(3):
            # Avoid the material boundary itself when extracting each swatch.
            box = (round(col * source.width / 3) + 4, round(row * source.height / 4) + 4,
                   round((col + 1) * source.width / 3) - 4, round((row + 1) * source.height / 4) - 4)
            swatches.append(periodic(source.crop(box).resize((512, 512), Image.Resampling.LANCZOS)))
    grass, path, cobble, timber, soil, water, forest, bog, cave, crystal, canopy, bark = swatches
    grass = grass * .82 + np.array([142, 151, 87]) * .18
    # The untilled farm field keeps its lighter, faintly furrowed cue.
    field_x = np.arange(grass.shape[1])[None, :, None] / grass.shape[1]
    field_grass = grass * .72 + np.array([164, 166, 106]) * .28 + 6 * np.cos(2 * np.pi * field_x * 12)
    water = ndimage.gaussian_filter(water, (1.8, 1.8, 0), mode="wrap") * .70 + np.array([82, 143, 148]) * .30
    town_grass = grass * .88 + np.array([145, 169, 129]) * .12
    # Keep the luminous path distinct from ordinary forest litter at night.
    glow_forest = forest * .35 + np.array([64, 152, 146]) * .65
    terrains = {
        "grass": grass, "grass_flowers": flowers(grass), "field_grass": field_grass,
        "grass_hyggebyen": town_grass, "grass_hyggebyen_flowers": flowers(town_grass, True),
        "soil_tilled": soil, "soil_watered": soil * np.array([.72, .74, .76]),
        "path_dirt": path, "deck_farm": timber,
        "deck_hyggebyen": timber * .72 + np.array([181, 170, 183]) * .28,
        "cobble_hyggebyen": cobble, "forest_floor": forest, "forest_floor_glow": glow_forest,
        "void_haze": ndimage.gaussian_filter(water, (12, 12, 0)) * .2 + np.array([210, 223, 221]) * .8,
        "forest_floor_o": forest, "forest_floor_glow_o": glow_forest,
        "moss_path_o": forest * .55 + path * .45, "bog_o": bog,
        "cave_floor_o": cave, "crystal_floor_o": crystal, "wall_void_o": canopy,
    }
    terrains.update({"water_" + str(i): water for i in range(4)})
    interior = Image.open(HERE / "sources/interior_terrain.png").convert("RGB")
    for index, name in enumerate(["floor_stone", "floor_plank", "floor_parquet", "floor_marble"]):
        col, row = index % 2, index // 2
        box = (round(col * interior.width / 2) + 4, round(row * interior.height / 2) + 4,
               round((col + 1) * interior.width / 2) - 4, round((row + 1) * interior.height / 2) - 4)
        terrains[name] = periodic(interior.crop(box).resize((512, 512), Image.Resampling.LANCZOS))
    folder = ROOT / "assets/iso_tiles"
    manifest = {"_source": "Painted materials: tools/art/drawn/sources/terrain.png; continuous four-tile lattice."}
    for name, surface in terrains.items():
        ortho, animated = name.endswith("_o"), name.startswith("water_")
        period = 2 if animated else 4
        image = atlas(surface, ortho, period, int(name[-1]) if animated else None)
        file = "drawn_" + name + ".webp"
        image.save(folder / file, lossless=True, method=6)
        # Retire only the previous export of this same material. The source
        # painting and all pristine farm/environment atlases remain intact.
        (folder / ("drawn_" + name + ".png")).unlink(missing_ok=True)
        (folder / ("drawn_" + name + ".png.import")).unlink(missing_ok=True)
        manifest[name] = {"file": file, "cell": [OCW, OCH] if ortho else [CW, CH],
                          "variants": [period, period], "proj": "ortho" if ortho else "iso"}
    (folder / "tiles_drawn.json").write_text(json.dumps(manifest, indent=2) + "\n")
    # Farm/interior manifests sort after tiles_drawn.json. Override their
    # materials without changing the pristine source atlases or bake tools.
    overrides = {name: manifest[name] for name in terrains if name == "field_grass" or name.startswith("floor_")}
    (folder / "tiles_z_drawn.json").write_text(json.dumps(overrides, indent=2) + "\n")
    edges(bark, timber)
    print(f"Packed {len(terrains)} painted terrain atlases, 3 bark sides and 2 bridges")


if __name__ == "__main__":
    build()
