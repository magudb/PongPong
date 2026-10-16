#!/usr/bin/env python3
"""Retain unmasked comparisons to the historical social prototypes and reviewed pins."""
import argparse
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("guide", ROOT / "tests/checkpoints/compare_guide.py")
guide = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guide)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shots", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    results = {}
    for name in ("people", "gift", "calendar", "social_hud"):
        shot = args.shots / f"social_ui_{name}.png"
        original = guide.compare(str(ROOT / f"tests/checkpoints/guide_ref_social/{name}.png"), str(shot), frame_crop=False)
        pinned = guide.compare(str(ROOT / f"docs/qa/ui_baseline/{name}.png"), str(shot), frame_crop=False)
        results[name] = {"historical_full_mean": round(original["mean"], 3),
                         "reviewed_full_mean": round(pinned["mean"], 3), "reviewed_limit": 1.5,
                         "ok": pinned["mean"] <= 1.5}
    output = json.dumps(results, indent=2) + "\n"
    if args.report:
        args.report.write_text(output)
    print(output, end="")
    return 0 if all(row["ok"] for row in results.values()) else 1


if __name__ == "__main__":
    raise SystemExit(main())
