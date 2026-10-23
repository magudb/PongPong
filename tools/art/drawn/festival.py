#!/usr/bin/env python3
"""Pack saved I5 paintings into the existing isometric art interface.

This stage delivers art and declarative placement design. Festival scheduling,
TownDirector attachment and world-event lifecycle remain their gameplay package.
"""
from __future__ import annotations

import hashlib
import json

import numpy as np
from PIL import Image, ImageFilter

from pack import ROOT, HERE, extract, ensure_policy
from consistency import matte
from shop_core import body, wall_body, read, write, rgba_bytes

SRC = HERE / "sources/festival"
OUT = ROOT / "assets/iso_props/festival"
DOC = ROOT / "docs/art/festival"
SEASONS = ("spring", "summer", "autumn", "winter")
# Keep full-resolution source paintings. The fixed-view festival pack is drawn
# at the same world size with a slightly smaller upload; consumers apply the
# reciprocal scale once to body and child accents, without moving the ground.
PACK_SCALE = .82
SETS = {s: {"pole": "banner_pole_" + s, "string": "bunting_string_a" if s == "spring" else "bunting_string_b" if s == "autumn" else "lantern_string_a" if s == "summer" else "lantern_string_b",
            "stage": "festival_stage", "bench": "festival_bench", "centre": {"spring": "maypole", "summer": "bonfire_festival", "autumn": "pumpkin_pile", "winter": "ice_lantern"}[s],
            "awning": "market_stall_" + s, "door": "door_wreath_" + s} for s in SEASONS}
EXTRAS = {"spring": ["flower_arch"], "summer": [], "autumn": ["sheaf_stack"], "winter": []}
EVENTS = {
    "blomsterfesten": ("spring", "flower_arch", True), "honningdagen": ("spring", "maypole", True),
    "midsommerlanterner": ("summer", "bonfire_festival", False), "badedagen": ("summer", "flower_arch", False),
    "hoestfesten": ("autumn", "pumpkin_pile", True), "maanemarkedet": ("autumn", "bonfire_festival", False),
    "vinterlysene": ("winter", "ice_lantern", True), "bagedagen": ("winter", "bonfire_festival", True),
    "aarsskiftet": ("winter", "ice_lantern", True), "bryllupsfesten": ("spring", "flower_arch", True),
}


def string_body(drawing: Image.Image, rotation: int) -> tuple[Image.Image, list[int]]:
    """Align the two painted rope ends with posts three cells apart.

    Uprights/lanterns retain their proportions under a shear. The pivot is the
    first support post on the ground, rather than the centre of a wall cell.
    """
    drawing = matte(drawing)
    alpha = np.asarray(drawing.getchannel("A"))
    yy, xx = np.where(alpha > 100)
    lx, rx = float(xx.min()), float(xx.max())
    ly = float(yy[xx <= lx + drawing.width * .035].min())
    ry = float(yy[xx >= rx - drawing.width * .035].min())
    scale = 192 / (rx - lx)
    slope = (ry - ly) / (rx - lx)
    target = (1 if rotation == 0 else -1) * 38 / 64
    def point(x, y):
        u = (x - lx) * scale
        return [u, target * u + scale * (y - ly - slope * u / scale)]
    corners = np.array([point(x, y) for x in (0, drawing.width) for y in (0, drawing.height)])
    origin = np.floor(corners.min(axis=0)).astype(int) - 3
    size = np.ceil(corners.max(axis=0)).astype(int) - origin + 3
    image = drawing.transform(tuple(size), Image.Transform.AFFINE,
        (1 / scale, 0, origin[0] / scale + lx,
         (-target + slope) / scale, 1 / scale,
         (origin[1] - target * origin[0]) / scale + ly + slope * origin[0] / scale), Image.Resampling.BICUBIC)
    start = 0 if rotation == 0 else 192
    return image, [round(start - origin[0]), round(target * start + 225 - origin[1])]


def mounted(drawing: Image.Image, item: dict, rotation: int) -> tuple[Image.Image, list[int]]:
    if item["layer"] == "ceiling":
        return string_body(drawing, rotation)
    if item["layer"] == "wall":
        return wall_body(matte(drawing), item, rotation, face_height=42, mount_height=95)
    if item["template"] == "banner_pole" or item["id"] == "flower_arch":
        drawing = matte(drawing)
        drawing.thumbnail((108, 310) if item["template"] == "banner_pole" else (150, 220), Image.Resampling.LANCZOS)
        image = Image.new("RGBA", (drawing.width + 6, drawing.height + 6))
        image.alpha_composite(drawing, (3, 3))
        return image, [image.width // 2, round(drawing.height - 38 * .85) + 3]
    return body(drawing, item, rotation)


def accent(image: Image.Image) -> tuple[Image.Image, tuple[int, ...]]:
    raw = np.asarray(image, dtype=float)
    r, g, b, alpha = (raw[:, :, k] for k in range(4))
    strength = np.clip((r - 175) / 65, 0, 1) * np.clip((g - b - 18) / 65, 0, 1)
    strength *= np.clip((r - g - 6) / 45, 0, 1) * alpha * .55
    mask = Image.fromarray(np.uint8(strength)).filter(ImageFilter.GaussianBlur(.35))
    bounds = mask.getbbox()
    if bounds is None:
        raise ValueError("No warm painted candle/flame found")
    layer = Image.new("RGBA", image.size, (255, 183, 88, 0))
    layer.putalpha(mask)
    return layer.crop(bounds), bounds


def save(image: Image.Image, stem: str, lossless: bool = False) -> str:
    path = OUT / (stem + ".webp")
    image.save(path, lossless=lossless, quality=90, method=4, exact=True)
    ensure_policy(path)
    return path.name


def layout() -> list[dict]:
    rows = [{"slot": "stage", "post": "host", "offset": [0, 0], "rot": 0},
            {"slot": "centre", "post": "judge", "offset": [0, .5], "rot": 0}]
    rows += [{"slot": "awning", "post": f"stall_{k}", "offset": [.4, .4], "rot": 0} for k in range(1, 5)]
    rows += [{"slot": "bench", "post": f"table_{k}", "offset": [0, 0], "rot": k - 1} for k in range(1, 3)]
    for first, last, offset in [(1, 4, [-.4, -.4]), (13, 16, [.6, .6])]:
        rows += [{"slot": "pole", "post": f"gather_{k}", "offset": offset, "rot": 0 if k == first else 1} for k in (first, last)]
        rows.append({"slot": "string", "post": f"gather_{first}", "to_post": f"gather_{last}", "offset": offset, "rot": 0})
    return rows


def design() -> dict:
    return {"_doc": "I5 declarative art placement design. Post names are suffixes of fest_<spot>_; only the live director may resolve them. No festival gameplay is installed by this art package.",
            "sets": SETS, "season_accents": EXTRAS, "layout": layout(),
            "festivals": {id: {"set": s, "centre": centre, "slots_used": list(SETS[s]), "door_wreaths": doors} for id, (s, centre, doors) in EVENTS.items()}}


def write_lua(config: dict) -> None:
    def lua(value):
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, str):
            return json.dumps(value, ensure_ascii=False)
        if isinstance(value, dict):
            return "{ " + ", ".join(k + " = " + lua(v) for k, v in value.items()) + " }"
        if isinstance(value, list):
            return "{ " + ", ".join(map(lua, value)) + " }"
        return str(value)
    lines = ["-- I5 art placement design. Calendar/runtime attachment is owned by the towns/social integration.",
             '-- No new autoload or event handler is installed by this file.', 'kind = "config"', "", "config = {", "  festival_decor = {"]
    for key in ("sets", "season_accents", "festivals"):
        lines += ["    " + key + " = {"]
        lines += ["      " + k + " = " + lua(v) + "," for k, v in config[key].items()]
        lines += ["    },"]
    lines += ["    layout = {"] + ["      " + lua(v) + "," for v in config["layout"]] + ["    },", "  },", "}", ""]
    (ROOT / "lua/config/festival_decor.lua").write_text("\n".join(lines))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    contract = read(HERE / "festival_layout.json")
    drawings = {}
    for job in read(DOC / "prompts.json")["jobs"]:
        for cell, image in zip(job["cells"], extract(SRC / (job["name"] + ".png"), job["rows"], job["cols"]), strict=True):
            if not cell["id"].startswith("_unused"):
                drawings[cell["id"], cell["rot"]] = (image, job["name"])
    manifest = {"_doc": "Painted I5 art contract; 24 pieces / 53 independent authored views. Non-solid decoration, no calendar or live town integration.",
                "_style": "approved matte gouache/watercolor and warm irregular pencil", "items": {}, "sets": SETS, "season_accents": EXTRAS}
    sizes, night_count = [], 0
    for name, item in contract["pieces"].items():
        entry = {k: v for k, v in item.items() if k != "rot_baked"}
        entry.update(baked=list(range(item["rot_baked"])), sym="wall2" if item["layer"] == "wall" else "none", mirror_ok=False, solid=False, interact="none", rot={})
        for rot in range(item["rot_baked"]):
            drawing, source = drawings[name, rot]
            image, pivot = mounted(drawing, item, rot)
            image = image.resize((round(image.width * PACK_SCALE), round(image.height * PACK_SCALE)), Image.Resampling.LANCZOS)
            pivot = [p * PACK_SCALE for p in pivot]
            fp = item["footprint"] if rot % 2 == 0 else list(reversed(item["footprint"]))
            rec = {"file": save(image, f"{name}_r{rot}"), "size": list(image.size), "pivot": pivot, "render_scale": 1 / PACK_SCALE, "footprint": fp, "ysort": [0, 0],
                   "illustration": f"tools/art/drawn/sources/festival/{source}.png", "view": rot, "flip": False}
            if item["layer"] == "ceiling":
                rec.update(anchor="first_post", span_cells=3, span_px=[192 if rot == 0 else -192, 114], elevation_px=225)
            elif item["layer"] == "wall":
                rec.update(anchor="first_wall_cell", wall_axis=[64 if rot == 0 else -64, 38], mounting_height_px=95)
            if item["template"] in ("lantern_string", "bonfire", "ice_lantern"):
                night, bounds = accent(image)
                rec.update(night=save(night, f"{name}_r{rot}_night", True), night_size=list(night.size), night_offset=list(bounds[:2]),
                           glow={"blend": "add", "light_hint": "none", "point_lights": 0})
                sizes.append(list(night.size))
                night_count += 1
            sizes.append(list(image.size))
            entry["rot"][str(rot)] = rec
        manifest["items"][name] = entry
    write(OUT / "festival.json", manifest)
    config = design()
    write(DOC / "placement.json", config)
    write_lua(config)
    write(DOC / "sources.json", {p.name: {"path": str(p.relative_to(ROOT)), "size": list(Image.open(p).size), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(SRC.glob("*.png"))})
    packing = {"pieces": len(manifest["items"]), "authored_views": sum(len(v["rot"]) for v in manifest["items"].values()), "night_layers": night_count,
               "disk_mb": sum(p.stat().st_size for p in OUT.glob("*.webp")) / 1e6, "rgba8_mips_mb": sum(map(rgba_bytes, sizes)) / 1e6}
    write(DOC / "packing.json", packing)
    if packing["disk_mb"] > .7 or packing["rgba8_mips_mb"] > 7:
        raise ValueError(f"Festival art exceeds the published budget: {packing}")
    print(json.dumps(packing))


if __name__ == "__main__":
    main()
