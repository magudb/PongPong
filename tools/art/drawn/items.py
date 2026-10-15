"""Pack painted item pictures and palette variants into the real UI lookup paths."""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

from pack import ROOT, SOURCES, save_webp


def cells(name: str) -> list[Image.Image]:
    """Inventory sheets have generous gutters; keep disconnected pairs together."""
    sheet = Image.open(SOURCES / (name + ".png")).convert("RGBA")
    output = []
    for row in range(4):
        for col in range(4):
            image = sheet.crop((round(col * sheet.width / 4), round(row * sheet.height / 4),
                                round((col + 1) * sheet.width / 4), round((row + 1) * sheet.height / 4)))
            alpha = image.getchannel("A").point(lambda a: a if a > 32 else 0)
            # Keep intentional disconnected pairs (earrings, seeds), but remove
            # tiny fragments that spill in from a neighbouring atlas cell.
            labels, count = ndimage.label(np.asarray(alpha) > 32)
            areas = np.bincount(labels.ravel())
            largest = int(areas[1:].max()) if count else 0
            keep = []
            for label, box in enumerate(ndimage.find_objects(labels), start=1):
                if box is None or areas[label] < max(20, largest * .015):
                    continue
                touches_edge = box[0].start <= 1 or box[1].start <= 1 or box[0].stop >= image.height - 1 or box[1].stop >= image.width - 1
                if not touches_edge or areas[label] == largest:
                    keep.append(label)
            alpha = Image.fromarray(np.where(np.isin(labels, keep), np.asarray(alpha), 0).astype("uint8"))
            image.putalpha(alpha)
            bounds = alpha.getbbox()
            if bounds is None:
                raise ValueError(f"{name}: blank icon in row {row}, column {col}")
            output.append(image.crop(bounds))
    return output


def palette_variant(image: Image.Image, palette: list[str], material: str = "cloth") -> Image.Image:
    """Recolor the authored sage cloth and lavender trim, preserving ink/grain."""
    rgba = np.asarray(image, dtype=float).copy()
    rgb = rgba[:, :, :3]
    source_rgb = rgb.copy()
    pigment = np.clip((rgb.max(axis=2) - 85) / 30, 0, 1)
    green = np.clip((rgb[:, :, 1] - rgb[:, :, 0] + 6) / 8, 0, 1) * np.clip((rgb[:, :, 1] - rgb[:, :, 2] - 2) / 12, 0, 1) * pigment
    lavender = np.clip((rgb[:, :, 2] - rgb[:, :, 1] - 3) / 15, 0, 1) * np.clip((np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1] - 3) / 12, 0, 1) * pigment
    def anchor_for(weight: np.ndarray, fallback: list[int]) -> np.ndarray:
        region = source_rgb[(weight > .6) & (rgba[:, :, 3] > 200)]
        return np.median(region, axis=0) if len(region) >= 30 else np.array(fallback)
    channels = [(green, [132, 184, 157], palette[0]),
                (lavender, [178, 161, 200], palette[1])]
    channels = [(weight, anchor_for(weight, anchor), color) for weight, anchor, color in channels]
    if material in ("wood", "leather", "metal"):
        warm = np.clip((rgb[:, :, 0] - rgb[:, :, 1] - 6) / 18, 0, 1) * np.clip((rgb[:, :, 1] - rgb[:, :, 2] - 5) / 22, 0, 1) * np.clip((rgb[:, :, 0] - 95) / 40, 0, 1)
        anchor = {"wood": [181, 138, 82], "leather": [139, 102, 71], "metal": [190, 157, 88]}[material]
        channels.append((warm, anchor, palette[0]))
    elif material == "red":
        red = np.clip((rgb[:, :, 0] - rgb[:, :, 1] - 12) / 30, 0, 1) * np.clip((rgb[:, :, 0] - rgb[:, :, 2] - 12) / 30, 0, 1)
        channels.append((red, [201, 119, 103], palette[0]))
    for weight, anchor, color in channels:
        target = np.array([int(color[i:i + 2], 16) for i in (0, 2, 4)])
        rgb += (target - anchor) * weight[:, :, None]
    return Image.fromarray(np.uint8(np.clip(rgba, 0, 255)))


def icon(image: Image.Image, scale: float = 1) -> Image.Image:
    image = image.copy()
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("Cannot pack an empty item picture")
    image = image.crop(bounds)
    image.thumbnail((round(104 * scale), round(108 * scale)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (128, 128))
    canvas.alpha_composite(image, ((128 - image.width) // 2, (128 - image.height) // 2))
    return canvas


def night_rim(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    rim = alpha.point(lambda a: 255 if a > 24 else 0).filter(ImageFilter.MaxFilter(9))
    canvas = Image.new("RGBA", image.size, (228, 239, 245, 0))
    canvas.putalpha(rim)
    canvas.alpha_composite(image)
    return canvas


def build() -> None:
    recipes = json.loads((Path(__file__).parent / "item_recipes.json").read_text())["items"]
    atlases = {}
    packed = {}
    outputs = {}

    def drawing(recipe: dict) -> Image.Image:
        name = recipe["sheet"]
        if name not in atlases:
            atlases[name] = cells(name)
        image = atlases[name][recipe["index"]]
        if recipe.get("palette"):
            image = palette_variant(image, recipe["palette"], recipe.get("material", "cloth"))
        return image

    # Plain pictures first; seed envelopes and kits then reuse those drawings.
    for item_id, recipe in recipes.items():
        if recipe["kind"] == "animal":
            folder = ROOT / "assets/isometric_characters" / recipe["character"]
            metadata = json.loads((folder / "animations.json").read_text())
            image = Image.open(folder / metadata["animations"]["idle"]["sheet"]).convert("RGBA").crop((0, 0, 256, 256))
        elif recipe["kind"] == "painted":
            image = drawing(recipe)
        else:
            continue
        packed[item_id] = icon(image, recipe.get("scale", 1))
    for item_id, recipe in recipes.items():
        if recipe["kind"] == "seed":
            canvas = icon(drawing(recipe))
            crop = packed[recipe["crop"]].copy()
            crop.thumbnail((42, 42), Image.Resampling.LANCZOS)
            canvas.alpha_composite(crop, ((128 - crop.width) // 2, 48))
            packed[item_id] = canvas
        elif recipe["kind"] == "coop_kit":
            canvas = icon(drawing(recipe))
            eggs = packed["egg"].resize((42, 42), Image.Resampling.LANCZOS)
            canvas.alpha_composite(eggs, (51, 57))
            packed[item_id] = canvas
    for item_id, recipe in recipes.items():
        folder = ROOT / "assets/icons" / ("wardrobe" if recipe["category"] == "clothing" else "items")
        target = folder / (item_id + ".webp")
        save_webp(packed[item_id], target)
        if recipe["rarity"] in ("legendary", "unique"):
            save_webp(night_rim(packed[item_id]), folder / (item_id + "_night.webp"))
        outputs[item_id] = str(target.relative_to(ROOT))
    if len(outputs) != len(recipes):
        raise ValueError("The item pack omitted one or more recipes")
    print(f"Packed {len(outputs)} painted item pictures, including {sum(r['category'] == 'clothing' for r in recipes.values())} wardrobe variants")


if __name__ == "__main__":
    build()
