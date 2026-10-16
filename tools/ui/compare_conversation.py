#!/usr/bin/env python3
"""Score conversation UI against the original mock, retaining unmasked scores.

Only the superseded portrait placeholder interior is masked in BOTH dialogue
inputs. Frame, nameplate, text, choices, footer and shadow stay scored. The book
uses the authored historical guide fixture; production captures retain real Lua.
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
    full = guide.compare(str(ROOT / "tests/checkpoints/guide_ref_ui/dialogue_box.png"),
                         str(args.shots / "npc_dialogue_crop.png"), frame_crop=False)
    reference, actual = full["ref_img"].copy(), full["shot_img"].copy()
    mask = [34, 34, 179, 179]
    for im in (reference, actual):
        ImageDraw.Draw(im).rectangle(mask, fill=(244, 230, 196))
    ref_path, shot_path = args.shots / "reference_dialogue_ui.png", args.shots / "comparison_dialogue_ui.png"
    reference.save(ref_path)
    actual.save(shot_path)
    ui = guide.compare(str(ref_path), str(shot_path), frame_crop=False)
    book = guide.compare(guide.bundled_ref("quest"), str(args.shots / "npc_journal_guide.png"))
    # Ratchet: ceil(first accepted UI mean + 0.5), below the original <=16 ceiling.
    result = {"dialogue": {"full_mean": round(full["mean"], 3), "ui_mean": round(ui["mean"], 3),
                           "limit": 15, "masks": [mask], "ok": ui["mean"] <= 15},
              "journal": {"full_mean": round(book["mean"], 3), "limit": 12, "masks": [], "ok": book["mean"] <= 12}}
    print(json.dumps(result, indent=2))
    return 0 if all(row["ok"] for row in result.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
