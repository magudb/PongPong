#!/usr/bin/env python3
"""Bake a two-body layered fit proof from saved imagegen paintings.

No character catalog or gameplay wardrobe files are installed. All parts share
one offline deformation field; grips are solved against that same field. The
held sword is rigid. The native review samples IsoChibiSprite2D's existing clock.
"""
from __future__ import annotations

import hashlib
import json
import math
import time
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

from pack import HERE, ROOT, extract, fitted, ensure_policy

SOURCE = HERE / "sources/equipment_fit"
OUT = ROOT / "assets/art_studies/equipment_fit"
DOC = ROOT / "docs/art/equipment-fit"
YY, XX = np.mgrid[:256, :256].astype(np.float32)


def garments(path: Path) -> tuple[list[Image.Image], list[list[int]]]:
    """Group every disconnected boot/charm with its row, preserving source alpha.

    Shirt silhouettes locate the eight irregularly spaced rows. Components are
    assigned whole, so ribbon ends crossing nominal column boundaries survive.
    Tiny detached pigment marks follow their closest substantial component.
    """
    rgba = np.array(Image.open(path).convert("RGBA"))
    labels, _ = ndimage.label(rgba[:, :, 3] > 24)
    sizes = np.bincount(labels.ravel())
    boxes = ndimage.find_objects(labels)
    primary = [i for i in range(1, len(sizes)) if sizes[i] >= 100]
    centers = {i: [(s.start + s.stop) * .5 for s in boxes[i - 1]] for i in primary}
    shirts = sorted((i for i in primary if .25 < centers[i][1] / rgba.shape[1] < .5),
                    key=lambda i: -sizes[i])[:8]
    if len(shirts) != 8:
        raise ValueError(f"{path}: need eight distinct shirt silhouettes")
    rows = sorted(centers[i][0] for i in shirts)
    seeds = np.where(np.isin(labels, primary), labels, 0)
    nearest = ndimage.distance_transform_edt(seeds == 0, return_distances=False, return_indices=True)
    owner = seeds[tuple(nearest)]
    cells = np.zeros(len(sizes), dtype=np.int16)
    for i in primary:
        y, x = centers[i]
        row = min(range(8), key=lambda r: abs(rows[r] - y))
        col = min(3, int(x / rgba.shape[1] * 4))
        cells[i] = row * 4 + col + 1
    assigned = cells[owner]
    drawings, bounds = [], []
    for index in range(32):
        keep = assigned == index + 1
        y, x = np.where(keep & (rgba[:, :, 3] > 24))
        if len(x) < 100:
            raise ValueError(f"{path}: missing cell {index}")
        box = [max(0, int(x.min()) - 2), max(0, int(y.min()) - 2),
               min(rgba.shape[1], int(x.max()) + 3), min(rgba.shape[0], int(y.max()) + 3)]
        x0, y0, x1, y1 = box
        crop = rgba[y0:y1, x0:x1].copy()
        crop[:, :, 3] *= keep[y0:y1, x0:x1]
        crop[crop[:, :, 3] == 0, :3] = 0
        drawings.append(Image.fromarray(crop))
        bounds.append(box)
    return drawings, bounds


def canvas_part(image: Image.Image, box: list[int]) -> Image.Image:
    x, y, w, h = box
    result = Image.new("RGBA", (256, 256))
    result.alpha_composite(image.resize((w, h), Image.Resampling.LANCZOS), (x, y))
    return result


def feature(base: Image.Image, points: list, ellipse: bool = False) -> Image.Image:
    """Separate an authored body-space occluder, without recoloring the painting."""
    mask = Image.new("L", (256, 256))
    draw = ImageDraw.Draw(mask)
    if ellipse:
        draw.ellipse(points, fill=255)
    else:
        for polygon in points:
            draw.polygon(polygon, fill=255)
    pixels = np.array(base)
    pixels[:, :, 3] = (pixels[:, :, 3].astype(np.uint16) * np.array(mask) // 255).astype(np.uint8)
    return Image.fromarray(pixels)


def field(clip: str, frame: int, frames: int, height: int) -> tuple[np.ndarray, np.ndarray]:
    """The painted pack's idle/stride/reach vocabulary, shared by every fit layer.

    Dedicated to the four proof clips: this returns the sampling field so an
    attachment and occluder can use precisely the same motion as their body.
    No per-layer outlines or independent limb clocks are introduced.
    """
    wave = math.sin(frame / frames * math.tau)
    pulse = math.sin((frame + .5) / frames * math.pi)
    u = (XX - 127.5) / (height * .5)
    v = (YY - (200 - height)) / height
    legs = np.clip((v - .72) / .26, 0, 1)
    left = np.exp(-((u + .45) / .28) ** 2)
    right = np.exp(-((u - .45) / .28) ** 2)
    arms = np.exp(-((np.abs(u) - .7) / .3) ** 2 - ((v - .69) / .16) ** 2)
    head = np.exp(-((v - .3) / .35) ** 4)
    dx, dy = np.zeros_like(XX), np.zeros_like(YY)
    sx, sy, lean = 1., 1., 0.
    if clip in ("walk", "run"):
        stride = 4.5 if clip == "walk" else 7.
        dx += legs * (right - left) * wave * stride
        dy -= legs * (left * max(wave, 0) + right * max(-wave, 0)) * stride
        dy += arms * np.sign(u) * wave * 3.5
        dx += head * wave * .8
        sy, lean = 1 - abs(wave) * .018, wave * .012
    elif clip == "interact":
        dx -= arms * pulse * 8.
        dy -= arms * pulse * 5.6
        dy += head * pulse * 1.5
        lean = -.035 * pulse
    else:
        sx, sy = 1 + wave * .008, 1 + wave * .006
        dx += head * wave * .45
    return (127.5 + (XX - 127.5 - dx - (200 - YY) * lean) / sx,
            200 + (YY - 200 - dy) / sy)


def warp(image: Image.Image, sample: tuple) -> Image.Image:
    a = np.asarray(image, dtype=np.float32) / 255
    a[:, :, :3] *= a[:, :, 3:4]
    x, y = sample
    result = np.stack([ndimage.map_coordinates(a[:, :, k], [y, x], order=1,
                                             mode="constant", cval=0) for k in range(4)], axis=-1)
    result[:, :, :3] /= np.maximum(result[:, :, 3:4], 1 / 255)
    return Image.fromarray(np.uint8(np.clip(result * 255, 0, 255)))


def socket(point: list[float], sample: tuple) -> list[float]:
    p = np.array(point, dtype=float)
    for _ in range(12):
        actual = np.array([ndimage.map_coordinates(a, [[p[1]], [p[0]]], order=1)[0] for a in sample])
        p += np.array(point) - actual
    return [round(float(v), 4) for v in p]


def sword_at(drawing: Image.Image, grip: list[float], angle: float) -> Image.Image:
    """Rigid attachment: its authored grip pivot follows the solved body socket."""
    h = 79
    w = round(drawing.width / drawing.height * h)
    sword = drawing.resize((w, h), Image.Resampling.LANCZOS)
    # All eight source swords have their leather grip 80% down the full canvas.
    local = Image.new("RGBA", (256, 256))
    local.alpha_composite(sword, (128 - w // 2, 128 - round(h * .8)))
    rotated = local.rotate(-angle, Image.Resampling.BICUBIC, center=(128, 128))
    return rotated.transform((256, 256), Image.Transform.AFFINE,
                             (1, 0, 128 - grip[0], 0, 1, 128 - grip[1]), Image.Resampling.BICUBIC)


def atlas(cells: list[tuple[str, Image.Image]]) -> tuple[Image.Image, dict]:
    """Tight RGBA8 shelf atlas with two transparent pixels around each rectangle."""
    entries = []
    for key, image in cells:
        bounds = image.getbbox()
        if bounds:
            entries.append((key, image.crop(bounds), bounds[:2]))
    entries.sort(key=lambda r: (-r[1].height, -r[1].width, r[0]))
    x, y, shelf = 2, 2, 0
    rects = {}
    for key, image, origin in entries:
        if x + image.width + 2 > 1024:
            x, y, shelf = 2, y + shelf + 4, 0
        rects[key] = {"rect": [x, y, image.width, image.height], "canvas_offset": list(origin)}
        x += image.width + 4
        shelf = max(shelf, image.height)
    height = math.ceil((y + shelf + 2) / 4) * 4
    result = Image.new("RGBA", (1024, height))
    for key, image, _ in entries:
        result.alpha_composite(image, tuple(rects[key]["rect"][:2]))
    return result, rects


def build() -> None:
    started = time.perf_counter()
    layout = json.loads((HERE / "equipment_fit_layout.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    DOC.mkdir(parents=True, exist_ok=True)
    manifest = {k: layout[k] for k in ["version", "scope", "canvas", "ground_anchor", "directions", "parts", "items"]}
    manifest.update(status="fit_proof", animation="shared offline 2D deformation; not separately hand-painted action frames",
                    import_mode="lossless RGBA8; no mips; two-pixel atlas gutters", mirror_ok=False, bodies={})
    swords = extract(SOURCE / "sword.png", 2, 4)
    report = {"bodies": {}, "sources": {}, "sockets": 0, "maximum_socket_error_px": 0.0}
    source_names = {"sword.png"}
    for name, body in layout["bodies"].items():
        source_names.update([body["base"], body["garments"]])
        bases = extract(SOURCE / body["base"], 2, 4)
        clothes, source_bounds = garments(SOURCE / body["garments"])
        base_parts = []
        for direction, drawing in enumerate(bases):
            fit = body["fit"][direction]
            base = Image.new("RGBA", (256, 256))
            base.alpha_composite(fitted(drawing, body["height"], 200), (body["shift_x"][direction], 0))
            parts = {"body": base}
            for col, part in enumerate(["hat", "shirt", "pants", "shoes"]):
                parts[part] = canvas_part(clothes[direction * 4 + col], fit[part])
            for hand, point_key, visible_key in [("hand_r", "right", "r_visible"), ("hand_l", "left", "l_visible")]:
                cx, cy = fit[point_key]
                radius = 11 if name == "rasmus" else 12
                parts[hand] = feature(base, [cx - radius, cy - 10, cx + radius, cy + 10], True) if fit[visible_key] else Image.new("RGBA", (256, 256))
            parts["ears"] = feature(base, [[(72, 83), (79, 29), (104, 49), (115, 77)],
                                           [(142, 77), (153, 48), (177, 29), (187, 83)]]) if name == "rasmus" else Image.new("RGBA", (256, 256))
            base_parts.append(parts)
        rec = {"stock": body["stock"], "skin": body["skin"], "base_source": str((SOURCE / body["base"]).relative_to(ROOT)),
               "garment_source": str((SOURCE / body["garments"]).relative_to(ROOT)), "clips": {}}
        body_report = {"resident_rgba8_bytes": 0, "disk_bytes": 0, "poses": 0, "garment_source_bounds": source_bounds}
        for clip, spec in layout["clips"].items():
            cells, poses = [], []
            for direction in range(8):
                row = []
                fit = body["fit"][direction]
                for frame in range(spec["frames"]):
                    sample = field(clip, frame, spec["frames"], body["height"])
                    pose = {"sockets": {}, "parts": {}, "order": ["body", "pants", "shoes", "shirt", "hat", "ears", "hand_l", "hand_r"]}
                    for side, point_key, visible_key in [("r", "right", "r_visible"), ("l", "left", "l_visible")]:
                        source_point = fit[point_key]
                        position = socket(source_point, sample)
                        basis = [socket([source_point[0] + 1, source_point[1]], sample), socket([source_point[0], source_point[1] + 1], sample)]
                        basis = [[round(v[axis] - position[axis], 4) for axis in range(2)] for v in basis]
                        actual = [ndimage.map_coordinates(a, [[position[1]], [position[0]]], order=1)[0] for a in sample]
                        error = float(np.linalg.norm(np.array(actual) - source_point))
                        report["maximum_socket_error_px"] = max(report["maximum_socket_error_px"], error)
                        report["sockets"] += 1
                        pose["sockets"]["grip_" + side] = {"position": position, "basis": basis, "visible": fit[visible_key], "depth": fit["depth"] if side == "r" else "front"}
                    grip = pose["sockets"]["grip_r"]["position"]
                    swing = ([-10, -22, 18, 7][frame] if clip == "interact" else 0) * (1 if fit["angle"] >= 0 else -1)
                    angle = fit["angle"] + swing
                    pose["held"] = {"item": "iron_sword", "socket": "grip_r", "grip": grip, "angle_deg": angle, "depth": fit["depth"], "support_socket": None, "hands_required": 1}
                    pose["order"].insert(0 if fit["depth"] == "rear" else pose["order"].index("hand_r"), "sword")
                    for part in layout["parts"]:
                        key = f"{direction}/{frame}/{part}"
                        image = sword_at(swords[direction], grip, angle) if part == "sword" else warp(base_parts[direction][part], sample)
                        cells.append((key, image))
                        pose["parts"][part] = {"key": key, "visible": image.getbbox() is not None}
                    row.append(pose)
                    body_report["poses"] += 1
                poses.append(row)
            image, rectangles = atlas(cells)
            filename = f"{name}_{clip}.webp"
            image.save(OUT / filename, lossless=True, method=4, exact=True)
            ensure_policy(OUT / filename)
            for row in poses:
                for pose in row:
                    for part in pose["parts"].values():
                        key = part.pop("key")
                        if key in rectangles:
                            part.update(rectangles[key])
            rec["clips"][clip] = {**spec, "file": filename, "size": list(image.size), "poses": poses}
            body_report["resident_rgba8_bytes"] += image.width * image.height * 4
            body_report["disk_bytes"] += (OUT / filename).stat().st_size
        manifest["bodies"][name] = rec
        report["bodies"][name] = body_report
    for name in sorted(source_names):
        report["sources"][str((SOURCE / name).relative_to(ROOT))] = hashlib.sha256((SOURCE / name).read_bytes()).hexdigest()
    (OUT / "manifest.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")
    report["elapsed_seconds"] = round(time.perf_counter() - started, 3)
    (DOC / "packing.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: {x: v[x] for x in ["resident_rgba8_bytes", "disk_bytes", "poses"]} for k, v in report["bodies"].items()}, indent=2))
    print(f"Saved {report['sockets']} explicit per-pose grips; max field error {report['maximum_socket_error_px']:.5f}px")


if __name__ == "__main__":
    build()
