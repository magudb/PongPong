#!/usr/bin/env python3
"""Compare catalog UI with the immutable prototype mock, preserving full scores.

The prototype's keeper frame contains a text placeholder. The approved painted
bust supersedes that placeholder. Only that frame's interior is masked in BOTH
shop inputs for the UI score; its border, nameplate and every shop control stay
scored. Full images and unmasked scores remain available for review.
"""
import argparse
import importlib.util
import json
from pathlib import Path

from PIL import ImageDraw

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("guide", ROOT / "tests/checkpoints/compare_guide.py")
guide = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guide)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shots", type=Path, required=True)
    args = parser.parse_args()
    results = {}
    for name, limit in (("shop", 18), ("inventory", 22)):
        shot = args.shots / f"shop_ui_{name}_fixture.png"
        full = guide.compare(guide.bundled_ref(name), str(shot))
        reference, actual = full["ref_img"].copy(), full["shot_img"].copy()
        masks = []
        if name == "shop":
            masks = [[62, 342, 398, 669]]
            for im in (reference, actual):
                ImageDraw.Draw(im).rectangle(masks[0], fill=(244, 230, 196))
        ref_path = args.shots / f"reference_{name}_ui.png"
        shot_path = args.shots / f"comparison_{name}_ui.png"
        reference.save(ref_path)
        actual.save(shot_path)
        ui = guide.compare(str(ref_path), str(shot_path), frame_crop=False)
        results[name] = {"full_mean": round(full["mean"], 3), "ui_mean": round(ui["mean"], 3),
                         "limit": limit, "masks": masks, "ok": ui["mean"] <= limit}
    print(json.dumps({"screens": results}, indent=2))
    return 0 if all(row["ok"] for row in results.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
