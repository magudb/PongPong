#!/usr/bin/env python3
"""Audit a native illustration bake against its pristine source, including every alpha pixel.

This inspects artwork only; generation and rendering belong to imagegen and Godot.
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("assets", type=Path)
    parser.add_argument("audit", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    entries = json.loads(args.audit.read_text())
    failures = []
    changed = 0
    preserved = 0
    maximum_alpha_error = 0
    updated_mirror_flags = 0
    for entry in entries:
        relative = entry["path"]
        before = args.source / relative
        after = args.assets / relative
        if not after.is_file():
            failures.append(f"Missing: {relative}")
            continue
        if entry["treatment"].startswith("preserved"):
            preserved += 1
            if before.read_bytes() != after.read_bytes():
                failures.append(f"Light/shadow changed: {relative}")
            continue
        original = np.asarray(Image.open(before).convert("RGBA"))
        illustrated = np.asarray(Image.open(after).convert("RGBA"))
        if original.shape != illustrated.shape:
            failures.append(f"Size changed: {relative}")
            continue
        alpha_error = int(np.abs(original[..., 3].astype(np.int16) - illustrated[..., 3]).max())
        maximum_alpha_error = max(maximum_alpha_error, alpha_error)
        if alpha_error > 1:
            failures.append(f"Alpha changed by {alpha_error}: {relative}")
        if not np.array_equal(original[..., 3] > 24, illustrated[..., 3] > 24):
            failures.append(f"Silhouette changed: {relative}")
        visible = original[..., 3] > 128
        if np.any(original[..., :3][visible] != illustrated[..., :3][visible]):
            changed += 1
        else:
            failures.append(f"No visible illustration change: {relative}")
    image_paths = {str(p.relative_to(args.source)) for p in args.source.rglob("*") if p.suffix in (".png", ".webp")}
    audited_paths = {e["path"] for e in entries}
    if image_paths != audited_paths:
        failures.append(f"Unaudited images: {sorted(image_paths - audited_paths)}")
    for metadata in args.source.rglob("*.json"):
        relative = metadata.relative_to(args.source)
        original = json.loads(metadata.read_text())
        updated = json.loads((args.assets / relative).read_text())
        if str(relative) == "iso_props/furniture/furniture.json":
            # Pencil accents can change safe mirror fallbacks; all true rotations and spatial metadata must match.
            for iid, entry in original["items"].items():
                other = updated["items"][iid]
                updated_mirror_flags += entry.get("mirror_ok", False) != other.get("mirror_ok", False)
                entry.pop("mirror_ok", None)
                other.pop("mirror_ok", None)
        if original != updated:
            failures.append(f"Metadata changed: {relative}")
    report = {"audited": len(entries), "illustrated": changed, "preserved_effects": preserved,
              "maximum_alpha_error": maximum_alpha_error, "updated_mirror_flags": updated_mirror_flags,
              "failures": failures}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    raise SystemExit(bool(failures))


if __name__ == "__main__":
    main()
