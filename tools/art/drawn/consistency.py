#!/usr/bin/env python3
"""Pack the saved painted replacements; retain gameplay geometry and native anchors.

Imagegen supplies the artwork. This stage extracts, recolors materials, projects
repeatable surfaces and exports native canvases. It does not synthesize paintings.
"""
from __future__ import annotations

import argparse
import copy
import json
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageOps

from pack import ROOT, HERE, extract, window_light, project_building, building_footprint
from world import material, swatch

SRC = HERE / "sources/style_audit"
OUT = ROOT / "assets/iso_props/zz_painted_consistency"
DOC = ROOT / "docs/art/style-audit"
PRESET = '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\ncompress/mode=2\ncompress/high_quality=false\nmipmaps/generate=true\nprocess/fix_alpha_border=true\n'
FAMILIES = {
    "a_fixed": ["bed", "table", "chair", "sofa"],
    "b": ["wardrobe", "bookshelf", "chest", "fireplace"],
    "c": ["floor_lamp", "clock", "throne", "piano"],
    "d": ["plant", "rug", "painting", "shelf"],
    "e": ["curtain", "sconce", "vase", "table_lamp"],
    "f": ["candelabra", "chandelier", "round_table", "single_bed"],
    "g": ["bed_toadstool", "table_stump", "chair_stump", "sofa_leaf"],
    "h": ["wardrobe_hollow_log", "bookshelf_book_tree", "rug_flower_petal", "floor_lamp_glowshroom"],
    "i": ["fireplace_cauldron", "chest_snail", "plant_teapot_bonsai", "clock_owl"],
    "j_spaced": ["throne_root", "piano_toadstool", "painting_porthole", "shelf_birdhouse"],
    "k": ["chandelier_lantern_flower", "bed_moon", "sofa_cloud", "bookshelf_floating"],
    "l_fixed": ["rug_magic_circle", "floor_lamp_fairy", "fireplace_moon", "chest_rune"],
    "m": ["clock_moon", "throne_crystal", "piano_star", "chandelier_star"],
    "n": ["three_sofa", "narrow_wardrobe", "narrow_bookshelf", "round_rug"],
}
MATERIALS = ["plank_pine", "plank_oak", "plank_birch", "plank_walnut", "plank_cherry", "plank_ebony",
             "stone_block", "brick", "glass_pane", "roof_tile", "straw_bundle", "timber_beam", "marble_block", "slate", "copper_plate", "rose_quartz",
             "amber", "gold_leaf", "nails", "rope", "brass_bar", "varnish", "lime", "fabric_plain", "fabric_wool", "fabric_velvet", "fabric_damask",
             "blueprint_kongelig", "blueprint_solstuen", "blueprint_troldmanden", "blueprint_mestermurer", "milk_paint"]
WOOD = {"pine": "D6B27A", "oak": "B88A52", "birch": "EBDDBF", "walnut": "7A4E2D", "cherry": "A5523A", "ebony": "4A3F5C", "mossy": "8E7C58"}
PAINT = {"mosgroen": "8DB86A", "himmel": "A9D3E0", "rose": "E58FA6", "lavendel": "B6A6E6", "honning": "E8B04A", "kridt": "FBF5E6", "mynte": "7FC8A5"}
FABRIC = {"natur": "E9DCC0", "roed": "B8503A", "blaa": "6F8FBF", "groen": "6F9A52", "bordeaux": "8E3A55", "guld": "D8B25A", "rosendamask": "D68AA0", "kongeblaa": "3F5FA0"}


def read(path: Path) -> dict:
    return json.loads(path.read_text())


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=1 if path.name in ("furniture.json", "home.json") else 2) + "\n")


@lru_cache(maxsize=None)
def atlas(name: str, rows: int = 4, cols: int = 4) -> list[Image.Image]:
    path = SRC / (name + ".png")
    if not path.exists():
        path = HERE / "sources" / (name + ".png")
    return extract(path, rows, cols)


def matte(image: Image.Image) -> Image.Image:
    image = image.copy()
    image.putalpha(image.getchannel("A").point(lambda a: 255 if a >= 240 else (a if a > 24 else 0)))
    return image.crop(image.getchannel("A").getbbox())


def save(image: Image.Image, path: Path, quality: int = 87) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, quality=quality, method=6, exact=True)
    stub = path.with_name(path.name + ".import")
    if not stub.exists():
        stub.write_text(PRESET)


def pigment(image: Image.Image, style: dict, template: str) -> Image.Image:
    """Shift authored pigments, preserving ink, paper grain and painted shading."""
    rgba = np.asarray(image, dtype=float).copy()
    rgb = rgba[:, :, :3].copy()
    r, g, b = (rgb[:, :, i] for i in range(3))
    visible = rgba[:, :, 3] > 200
    warm = np.clip((r - g - 5) / 18, 0, 1) * np.clip((g - b - 4) / 20, 0, 1) * np.clip((r - 80) / 50, 0, 1)
    warm *= np.clip((r - b - 45) / 30, 0, 1)  # leave cream pillows/paper alone
    green = np.clip((g - r + 20) / 25, 0, 1) * np.clip((g - b - 4) / 20, 0, 1) * np.clip((g - 65) / 60, 0, 1)
    if template in ("rug", "curtain"):
        green = np.maximum(green, np.clip((b - 125) / 45, 0, 1) * np.clip((r - b) / 20 + .25, 0, 1))
    # The wide neutral shades of lamps and stone hearths are separate materials.
    changes = []
    wood = PAINT.get(style.get("paint"), WOOD.get(style.get("wood"), WOOD["pine"]))
    changes.append((warm, wood))
    if template == "table_lamp" and "metal" in style:
        changes[0] = (warm, {"messing": "BA975C", "kobber": "B77C59"}.get(style["metal"], "C8AB70"))
    if "fabric" in style:
        changes.append((green, FABRIC.get(style["fabric"], "E9DCC0")))
    if template == "fireplace":
        stone = {"granit": "9A9AA6", "marmor": "F0EAE0", "skifer": "6E7A98"}.get(style.get("stone"))
        if stone:
            neutral = np.clip((90 - (rgb.max(2) - rgb.min(2))) / 45, 0, 1) * np.clip((r - 85) / 50, 0, 1)
            changes.append((neutral, stone))
    if template in ("sconce", "candelabra", "chandelier"):
        metal = {"kobber": "B77C59", "messing": "BA975C", "guld": "C8AB70"}.get(style.get("metal"), "625764")
        changes = [(warm, metal)]
    for weight, color in changes:
        samples = rgb[(weight > .6) & visible]
        if len(samples) < 20:
            continue
        anchor = np.median(samples, axis=0)
        target = np.array([int(color[i:i + 2], 16) for i in (0, 2, 4)])
        rgba[:, :, :3] += (target - anchor) * weight[:, :, None]
    return Image.fromarray(np.uint8(np.clip(rgba, 0, 255)))


def fitted_body(drawing: Image.Image, rec: dict) -> Image.Image:
    """Use the original native body extent and foot row, including hanging anchors."""
    drawing = matte(drawing)
    x0, y0, x1, y1 = rec["body_bounds"]
    drawing = drawing.resize((x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", tuple(rec["size"]))
    canvas.alpha_composite(drawing, (x0, y0))
    return canvas


def rug_body(drawing: Image.Image, rec: dict, scale: float = 1) -> Image.Image:
    """Reproject a painted quadrilateral onto this rug's actual native footprint.

    A runner and a rectangular rug have nearly the same bounding-box aspect
    ratio in isometric view. Resizing their bounding boxes loses their shape.
    """
    drawing = matte(drawing)
    alpha = np.asarray(drawing.getchannel("A"))
    y, x = np.where(alpha > 128)
    # Fringe may protrude slightly; average the outermost rows/columns rather
    # than attaching a corner to one stray fibre.
    source = np.array([[float(x[y <= y.min() + 2].mean()), float(y.min())],
                       [float(x.max()), float(y[x >= x.max() - 2].mean())],
                       [float(x[y >= y.max() - 2].mean()), float(y.max())],
                       [float(x.min()), float(y[x <= x.min() + 2].mean())]])
    target = building_footprint(*rec["footprint"]) * .94
    target += np.array(rec["pivot"])
    target *= scale
    matrix, values = [], []
    for (u, v), (sx, sy) in zip(target, source, strict=True):
        matrix.extend([[u, v, 1, 0, 0, 0, -sx * u, -sx * v],
                       [0, 0, 0, u, v, 1, -sy * u, -sy * v]])
        values.extend([sx, sy])
    coeff = np.linalg.solve(np.array(matrix), np.array(values))
    return drawing.transform(tuple(round(v * scale) for v in rec["size"]), Image.Transform.PERSPECTIVE,
                             tuple(coeff), Image.Resampling.BICUBIC)


def contact(rec: dict, layer: str) -> Image.Image:
    canvas = Image.new("RGBA", tuple(rec["size"]))
    draw = ImageDraw.Draw(canvas)
    px, py = rec["pivot"]
    fx, fz = rec["footprint"]
    if layer in ("floor", "rug"):
        def point(x: float, z: float) -> tuple[float, float]:
            return px + (x - z) * 64, py + (x + z) * 37.6
        corners = [point(-fx / 2 + .12, -fz / 2 + .12), point(fx / 2 - .12, -fz / 2 + .12),
                   point(fx / 2 - .12, fz / 2 - .12), point(-fx / 2 + .12, fz / 2 - .12)]
        draw.polygon(corners, fill=(43, 35, 50, 55 if layer == "floor" else 30))
    elif layer == "tabletop":
        draw.ellipse((px - 17, py - 10, px + 18, py + 13), fill=(43, 35, 50, 65))
    return canvas.filter(ImageFilter.GaussianBlur(1))


def icon(drawing: Image.Image, night: bool = False) -> Image.Image:
    drawing = matte(drawing)
    drawing.thumbnail((110, 110), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (128, 128))
    canvas.alpha_composite(drawing, ((128 - drawing.width) // 2, (128 - drawing.height) // 2))
    alpha = canvas.getchannel("A").point(lambda a: 255 if a > 32 else 0)
    outer = alpha.filter(ImageFilter.MaxFilter(5))
    rim = Image.new("RGBA", (128, 128), (43, 35, 64, 0))
    rim.putalpha(outer)
    rim.alpha_composite(canvas)
    if night:
        halo = Image.new("RGBA", (128, 128), (228, 239, 245, 0))
        halo.putalpha(outer.filter(ImageFilter.MaxFilter(7)))
        halo.alpha_composite(rim)
        return halo
    return rim


def install_icon(id_: str, drawing: Image.Image, legendary: bool = False) -> None:
    for folder in (ROOT / "assets/icons/home", ROOT / "assets/icons/items"):
        # home is the furniture/material contract; update the higher-priority
        # items alias too when one already exists.
        if folder.name != "home" and not (folder / (id_ + ".webp")).exists():
            continue
        save(icon(drawing), folder / (id_ + ".webp"), 94)
        if legendary:
            save(icon(drawing, True), folder / (id_ + "_night.webp"), 94)


def furniture(only: set[str] | None = None) -> None:
    baseline = read(HERE / "consistency_layout.json")
    spec = read(ROOT / "tools/art/features/home/specs/furniture_art_spec.json")["items"]
    sources = {name: ("furniture_" + key, row) for key, names in FAMILIES.items() for row, name in enumerate(names)}
    sources.update(plant_flowering=("furniture_e", 2), plant_rose_pot=("furniture_e", 2))
    folder = ROOT / "assets/iso_props/furniture"
    result = read(folder / "furniture.json") if only else copy.deepcopy(baseline)
    provenance = read(DOC / "furniture-recipes.json") if only else {}
    for definition in spec:
        id_, template, kw = definition["id"], definition["template"], definition["kw"]
        if only and id_ not in only:
            continue
        source_key = id_ if id_ in sources else template
        if source_key == template:
            if template == "bed" and kw.get("size") == "single": source_key = "single_bed"
            if template == "table" and kw.get("size") == "round": source_key = "round_table"
            if template == "sofa" and kw.get("seats") == 3: source_key = "three_sofa"
            if template in ("wardrobe", "bookshelf") and kw.get("size") == "narrow": source_key = "narrow_" + template
            if template == "rug" and kw.get("shape") == "round": source_key = "round_rug"
        name, row = sources[source_key]
        drawings = atlas(name)[row * 4:row * 4 + 4]
        e = result["items"][id_]
        original = baseline["items"][id_]
        # Authored grain, foliage, handles and embroidery are asymmetric. Every
        # free-standing piece receives its four drawings; wall objects use two.
        e["sym"] = "wall2" if e["layer"] == "wall" else "none"
        rotations = [0, 1] if e["layer"] == "wall" else list(range(4))
        e["baked"] = rotations
        e["rot_map"] = [[k if k in rotations else k % 2, False] for k in range(4)]
        e["mirror_ok"] = False
        e["illustration"] = "tools/art/drawn/sources/style_audit/" + name + ".png"
        e["rot"] = {}
        for k in rotations:
            old_key = str(k) if str(k) in original["rot"] else str(k % 2 if str(k % 2) in original["rot"] else 0)
            rec = copy.deepcopy(original["rot"][old_key])
            rec["file"] = f"{id_}_r{k}.webp"
            drawing = drawings[k]
            if definition["rarity"] not in ("unique", "legendary"):
                drawing = pigment(drawing, definition["style"], template)
            body = rug_body(drawing, rec) if template == "rug" and kw.get("shape") != "round" else fitted_body(drawing, rec)
            image = contact(rec, e["layer"])
            image.alpha_composite(body)
            save(image, folder / rec["file"])
            # Existing physical floating books remain a separate painted overlay;
            # small stars/dots are intentional runtime effect masks.
            if "float" in rec:
                old_float = rec["float"]["file"]
                rec["float"]["file"] = f"{id_}_r{k}_float.webp"
                source = Image.open(SRC / "float_layers" / old_float).convert("RGBA")
                if id_ == "bookshelf_floating": source = material(source, swatch(3))
                save(source, folder / rec["float"]["file"], 93)
            rec.pop("body_bounds")
            e["rot"][str(k)] = rec
        provenance[id_] = {"master": e["illustration"], "row": row, "rotations": rotations, "palette": definition["style"]}
    # Use the high-resolution paintings with the shipped proportions, so tiny
    # tabletop sprites do not become blurry enlarged inventory pictures.
    by_id = {d["id"]: d for d in spec}
    for id_, entry in result["items"].items():
        recipe, definition = provenance[id_], by_id[id_]
        drawing = atlas(Path(recipe["master"]).stem)[recipe["row"] * 4]
        if entry["rarity"] not in ("unique", "legendary"):
            drawing = pigment(drawing, definition["style"], definition["template"])
        x0, y0, x1, y1 = baseline["items"][id_]["rot"]["0"]["body_bounds"]
        factor = max(2.0, 220.0 / max(x1 - x0, y1 - y0))
        if definition["template"] == "rug" and definition["kw"].get("shape") != "round":
            drawing = rug_body(drawing, baseline["items"][id_]["rot"]["0"], 3)
        else:
            drawing = matte(drawing).resize((round((x1 - x0) * factor), round((y1 - y0) * factor)), Image.Resampling.LANCZOS)
        install_icon(id_, drawing, entry["rarity"] == "legendary")
    for index, id_ in enumerate(MATERIALS):
        name = "materials_a" if index < 16 else "materials_b"
        install_icon(id_, atlas(name)[index % 16])
    result["_contract"]["illustration"] = "painted-consistency-v1"
    result["_contract"]["rotation_policy"] = "Four authored views of all free-standing painted objects, two wall views. No mirror fallback: grain and embroidery are asymmetric."
    write_json(folder / "furniture.json", result)
    write_json(DOC / "furniture-recipes.json", provenance)
    home = ROOT / "assets/iso_props/home"
    home_doc = read(home / "home.json")
    for path in sorted((SRC / "structural_bases").glob("scaffold*.webp")):
        base = Image.open(path).convert("RGBA")
        painted = material(base, swatch(3))
        save(painted, home / path.name, 90)
    home_doc["_contract"]["scaffold_illustration"] = "tools/art/drawn/sources/terrain.png; painted timber projected over unchanged construction geometry"
    write_json(home / "home.json", home_doc)
    print(f"Packed {len(spec)} furniture designs, {sum(len(v['rot']) for v in result['items'].values())} true views and 162 painted icons")


def props(only: set[str] | None = None) -> None:
    originals = {}
    for path in [ROOT / "assets/iso_props/props.json", *sorted((ROOT / "assets/iso_props").glob("*/props.json"))]:
        if path.parent == OUT:
            continue
        for name, rec in read(path).items():
            if isinstance(rec, dict) and "file" in rec:
                originals[name] = (rec, path.parent)
    manifest = read(OUT / "props.json") if only else {"_source": "Painted consistency pass; docs/art/style-audit. Gameplay IDs, footprints, interaction and collision definitions retained."}
    recipes = read(DOC / "prop-recipes.json") if only else {}
    OUT.mkdir(exist_ok=True)

    def export(id_: str, drawing: Image.Image, source: str, *, building: bool = False) -> None:
        if only and id_ not in only:
            return
        original, folder = originals[id_]
        rec = copy.deepcopy(original)
        old = Image.open(folder / rec["file"]).convert("RGBA")
        if building:
            # Measured wall/foundation junctions; footsteps and plants may extend
            # outside the facade plane. Project both walls to native tile axes.
            planes = [[.07, .86], [.55, .965], [.94, .86]]
            drawing, pivot = project_building(matte(drawing), planes, building_footprint(*rec["footprint"]))
            image = drawing
            rec.update(size=list(image.size), pivot=pivot, source_ground_planes=planes)
        else:
            bounds = old.getchannel("A").point(lambda a: 255 if a > 170 else 0).getbbox()
            image = fitted_body(drawing, dict(rec, body_bounds=bounds))
        rec["file"] = id_ + ".webp"
        rec["illustration"] = "tools/art/drawn/sources/" + source
        save(image, OUT / rec["file"], 90 if max(image.size) < 1024 else 86)
        if "glow" in rec:
            if building:
                windows = np.asarray(image).copy()
                # Exclude roofs/soil. Warm pixels within cream walls are the
                # lamps and windows; wood below stays below the value threshold.
                r, g, b = (windows[:, :, i].astype(float) for i in range(3))
                keep = (r > 205) & (g > 120) & (g < r - 14) & (b < g - 35)
                keep[:round(image.height * .40)] = False
                keep[round(image.height * .94):] = False
                windows[:, :, 3] *= keep
                glow, box = window_light(Image.fromarray(windows))
                filename = id_ + "_windows.webp"
                save(glow, OUT / filename, 97)
                rec["glow"] = {"file": filename, "center": [(box[0] + box[2]) / 2, (box[1] + box[3]) / 2], "size": list(glow.size), "color": "#ffffff"}
            else:
                rec["glow"]["file"] = str((folder / rec["glow"]["file"]).relative_to(OUT.parent.parent))
                rec["glow"]["file"] = "../../" + rec["glow"]["file"]
        manifest[id_] = rec
        recipes[id_] = {"master": rec["illustration"], "building_projection": building}

    utility_a = ["ore_copper", "ore_iron", "ore_gold", "marble_vein", "slate_vein", "crystal_amethyst", "crystal_emerald", "crystal_moonstone",
                 "glowmush_blue", "glowmush_pink", "glowmush_teal", "well", "fountain", "chest_closed", "chest_open", "chest_konge"]
    for index, id_ in enumerate(utility_a): export(id_, atlas("utility_a")[index], "style_audit/utility_a.png")
    utility_b = ["beehive_stand", "mailbox_red", "shipping_bin", "tent", "wheat_sack", "build_stake", "rope_stake_x", "rope_stake_z",
                 "fence_gate_x", "bench", "stake_sign", "chest_fe", "apple_tree", "tornebaer", "lantern_hand", "market_stall"]
    for index, id_ in enumerate(utility_b):
        if id_ == "tornebaer":
            continue
        drawing = atlas("utility_b")[index]
        if id_ == "rope_stake_z": drawing = ImageOps.mirror(drawing)
        export(id_, drawing, "style_audit/utility_b.png")
    for index, id_ in enumerate(["tornebaer", "roof_patch"]):
        export(id_, atlas("utility_c", 1, 2)[index], "style_audit/utility_c.png")
    for name, source, index in [("chest_trae", "utility_a", 13), ("chest_jern", "utility_a", 13), ("chest_noegle", "utility_a", 15),
                                ("market_stall_furniture", "utility_b", 15), ("market_stall_tailor", "utility_b", 15)]:
        drawing = atlas(source)[index]
        if name == "chest_jern": drawing = pigment(drawing, {"wood": "ebony"}, "chest")
        if name == "market_stall_furniture": drawing = pigment(drawing, {"fabric": "guld"}, "curtain")
        if name == "market_stall_tailor": drawing = pigment(drawing, {"fabric": "rosendamask"}, "curtain")
        export(name, drawing, "style_audit/" + source + ".png")
    for index, name in enumerate(["coop_small", "barn_small", "animal_house", "tool_shed"]):
        export(name, atlas("farm_buildings", 2, 2)[index], "style_audit/farm_buildings.png", building=True)
    crops = ["carrot", "pumpkin", "strawberry", "sunflower", "turnip", "catnip", "glow_berry", "moonflower"]
    for row, crop in enumerate(crops):
        source = "crops_a_spaced" if row < 4 else "crops_b"
        for stage in range(4): export(f"crop_{crop}_{stage}", atlas(source)[(row % 4) * 4 + stage], "style_audit/" + source + ".png")
    # Existing approved paintings supply shared props rather than new designs.
    for name, sheet, rows, cols, index in [
        ("bed", "furniture_a_fixed", 4, 4, 0),
        ("house_seedshop", "buildings", 2, 2, 3), ("house_bakery", "buildings", 2, 2, 1),
        ("house_smithy", "homes1", 2, 2, 0), ("house_animalstore", "homes1", 2, 2, 2),
        ("house_town_hall", "homes2", 2, 2, 2), ("house_king_treetop", "homes3", 2, 2, 1),
        ("tower_wizard", "homes2", 2, 2, 1), ("warp_gate_stone", "forest_painted", 3, 3, 3),
        ("tree_giant_crown", "giant_trees", 2, 2, 0), ("trunk_giant_a", "giant_trees", 2, 2, 0),
        ("trunk_giant_b", "giant_trees", 2, 2, 1), ("trunk_under_a", "giant_trees", 2, 2, 2), ("trunk_under_b", "giant_trees", 2, 2, 3)]:
        generated = sheet.startswith("furniture_") or sheet == "giant_trees"
        export(name, atlas(sheet, rows, cols)[index], ("style_audit/" if generated else "") + sheet + ".png", building=name.startswith("house_") or name == "tower_wizard")
    for suffix, paint in [("lavender", "lavendel"), ("mint", "mynte"), ("rose", "rose")]:
        export("lantern_post_" + suffix, pigment(atlas("nature", 3, 3)[5], {"paint": paint}, "lantern"), "nature.png")
    # Technical shapes keep their geometry/alpha; their visible surfaces now
    # sample exactly the approved painted terrain instead of synthetic fills.
    for name in ["floor_patch_a", "floor_patch_b", "floor_patch_c", "path_tile_o", "pond_water_o", "home_rope",
                 "stone_path_a", "stone_path_b", "stone_path_c", *[f"pennant_{color}{frame}" for color in ["blue", "gold", "mint", "pink"] for frame in ["", "_f1"]]]:
        if only and name not in only:
            continue
        rec, folder = originals[name]
        old = Image.open(folder / rec["file"]).convert("RGBA")
        index = 5 if name == "pond_water_o" else (1 if name == "path_tile_o" else (2 if "stone_path" in name else 3))
        if name.startswith("pennant"):
            surface = swatch(3).copy()
            target = {"blue": [139, 169, 181], "gold": [211, 184, 117], "mint": [141, 178, 146], "pink": [194, 144, 153]}[name.split("_")[1]]
            surface = surface * .30 + np.array(target) * .70
        else: surface = swatch(index)
        image = material(old, surface)
        new = copy.deepcopy(rec)
        new.update(file=name + ".webp", illustration="tools/art/drawn/sources/terrain.png")
        if "glow" in new:
            new["glow"]["file"] = "../../" + str((folder / new["glow"]["file"]).relative_to(OUT.parent.parent))
        save(image, OUT / new["file"], 93)
        manifest[name] = new
        recipes[name] = {"master": new["illustration"], "operation": "painted material projection over native technical shape"}
    # Farm parallax uses the approved trees at reduced contrast in atmospheric
    # perspective. Edge copies make the repeat continuous at the texture seam.
    if not only or any(id_.startswith("backdrop_") for id_ in only):
        backdrop(manifest)
    write_json(OUT / "props.json", manifest)
    write_json(DOC / "prop-recipes.json", recipes)
    print(f"Packed {len(manifest) - 1} painted props and parallax entries")


def backdrop(manifest: dict) -> None:
    far = Image.new("RGBA", (2048, 1024))
    tree = matte(atlas("nature", 3, 3)[0]).resize((660, 730), Image.Resampling.LANCZOS)
    pixels = np.asarray(tree, dtype=float).copy()
    pixels[:, :, :3] = pixels[:, :, :3] * .35 + np.array([164, 183, 142]) * .65
    pixels[:, :, 3] *= .65
    tree = Image.fromarray(pixels.astype("uint8"))
    for x, y in [(-330, 280), (220, 360), (800, 260), (1370, 350), (1718, 280)]: far.alpha_composite(tree, (x, y))
    pixels = np.asarray(far).copy(); pixels[:, -1] = pixels[:, 0]
    save(Image.fromarray(pixels), OUT / "backdrop_farm_far.webp", 89)
    manifest["backdrop_farm_far"] = {"file": "backdrop_farm_far.webp", "size": [2048, 1024], "pivot": [0, 0], "footprint": [0, 0], "kind": "backdrop", "illustration": "tools/art/drawn/sources/nature.png"}
    for theme, index, tint in [("forest", 2, [42, 62, 67]), ("hyggebyen", 1, [168, 151, 169])]:
        old = Image.open(ROOT / "assets/backdrops" / (theme + "_far.webp"))
        w, h = old.size
        image = Image.new("RGBA", old.size)
        tree = matte(atlas("nature", 3, 3)[index])
        tree.thumbnail((round(h * .70), round(h * .92)), Image.Resampling.LANCZOS)
        a = np.asarray(tree, dtype=float).copy()
        a[:, :, :3] = a[:, :, :3] * .25 + np.array(tint) * .75
        a[:, :, 3] *= .55
        tree = Image.fromarray(a.astype("uint8"))
        step = max(1, round(tree.width * .75))
        # Compose periodic edge copies, so the repeated silhouettes meet.
        for x in range(-tree.width, w + tree.width, step):
            y = h - tree.height + (x // step % 3) * 15
            for shift in [-w, 0, w]: image.alpha_composite(tree, (x + shift, y))
        a = np.asarray(image).copy(); a[:, -1] = a[:, 0]
        name = "backdrop_" + theme + "_far"
        save(Image.fromarray(a), OUT / (name + ".webp"), 89)
        manifest[name] = {"file": name + ".webp", "size": [w, h], "pivot": [0, 0], "footprint": [0, 0], "kind": "backdrop", "illustration": "tools/art/drawn/sources/nature.png"}
    # The former one-pixel treetop gradient is superseded by the approved farm
    # sky painting. A soft 384px atmospheric export stays within the city's
    # existing 70 MB conservative RGBA upload budget.
    sky = Image.open(ROOT / "assets/backdrops/farm_sky.png").convert("RGB")
    sky = sky.resize((384, 216), Image.Resampling.LANCZOS)
    path = ROOT / "assets/backdrops/treetop_sky.png"
    sky.save(path, optimize=True)
    stub = path.with_name(path.name + ".import")
    if not stub.exists(): stub.write_text(PRESET)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=["furniture", "props", "all"], default="all")
    parser.add_argument("--ids", nargs="+", help="Re-export selected IDs; preserve other installed entries")
    args = parser.parse_args()
    selected = set(args.ids) if args.ids else None
    if args.only in ("furniture", "all"): furniture(selected)
    if args.only in ("props", "all"): props(selected)


if __name__ == "__main__":
    main()
