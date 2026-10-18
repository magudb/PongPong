#!/usr/bin/env python3
"""Partition every game-test section across CI jobs without changing its checks."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def partitions(count):
    names = sorted(path.stem for path in (ROOT / "tests/sections").glob("*.gd")
                   if not path.name.startswith("_"))
    if count < 1 or count > len(names):
        raise ValueError("Shard count must be between one and the number of test sections")
    return [names[index::count] for index in range(count)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shard", type=int, required=True)
    parser.add_argument("--count", type=int, default=4)
    args = parser.parse_args()
    groups = partitions(args.count)
    if not 0 <= args.shard < len(groups):
        parser.error("Shard index is outside the configured range")
    print(",".join(groups[args.shard]))


if __name__ == "__main__":
    main()
