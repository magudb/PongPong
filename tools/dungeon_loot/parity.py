#!/usr/bin/env python3
"""Compare 20,000 real GDScript draws with the independent live-data Python model."""
import argparse
import collections
import json
from pathlib import Path
import random
from mc import World, depth_odds

parser = argparse.ArgumentParser()
parser.add_argument("godot_log", type=Path)
parser.add_argument("--out", type=Path)
args = parser.parse_args()
records = []
for line in args.godot_log.read_text().splitlines():
    if "LOOT_MC " in line:
        records.append(json.loads(line.split("LOOT_MC ",1)[1]))
if not records:
    raise SystemExit("no LOOT_MC observations in the Godot log")
world = World()
rng = random.Random(81821)
results = []
for record in records:
    probabilities = depth_odds(world, record["tier"],record["floor"],record["luck"])
    counts = collections.Counter()
    for _ in range(record["n"]):
        draw = rng.random()
        rarity = "normal" if draw < probabilities[0] else "uncommon" if draw < sum(probabilities[:2]) else "rare"
        counts[rarity] += 1
    errors = {rarity:abs(counts[rarity]-record["counts"][rarity])/record["n"] for rarity in counts}
    results.append({"godot":record,"python":dict(counts),"share_errors":errors,"passed":max(errors.values()) <= .015})
payload = {"samples":sum(r["godot"]["n"] for r in results),"results":results,"passed":all(r["passed"] for r in results)}
if args.out:
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(payload,indent=2)+"\n")
print(json.dumps(payload))
raise SystemExit(0 if payload["passed"] else 1)
