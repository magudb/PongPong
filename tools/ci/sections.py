#!/usr/bin/env python3
"""Partition every game-test section across CI jobs without changing its checks."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SIMULATIONS = {"combat_acceptance", "dungeon_fights"}


def partitions(count, pace="all"):
    names = sorted(path.stem for path in (ROOT / "tests/sections").glob("*.gd")
                   if not path.name.startswith("_"))
    if count < 1 or count > len(names):
        raise ValueError("Shard count must be between one and the number of test sections")
    if pace not in {"all", "normal", "simulation"} or not SIMULATIONS <= set(names):
        raise ValueError("Invalid pacing configuration or missing combat simulation")
    groups = [names[index::count] for index in range(count)]
    return [[name for name in group if pace == "all" or ((name in SIMULATIONS) == (pace == "simulation"))]
            for group in groups]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shard", type=int, required=True)
    parser.add_argument("--count", type=int, default=4)
    parser.add_argument("--pace", choices=("all", "normal", "simulation"), default="all")
    args = parser.parse_args()
    groups = partitions(args.count, args.pace)
    if not 0 <= args.shard < len(groups):
        parser.error("Shard index is outside the configured range")
    print(",".join(groups[args.shard]))


if __name__ == "__main__":
    main()
