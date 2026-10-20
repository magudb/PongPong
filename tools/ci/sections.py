#!/usr/bin/env python3
"""Partition every game-test section across CI jobs without changing its checks.

    tools/ci/sections.py --shard N [--count 4] [--pace all|normal|simulation] [--hero]
    tools/ci/sections.py --neutral
    tools/ci/sections.py --windowed --shard N [--count 4]
    tools/ci/sections.py --check
    tools/ci/sections.py --update-timings REPORT.json [REPORT.json ...]

Shards are balanced by the measured section times in tools/ci/section_seconds.json (largest first, each
to the shard with the least time so far; a section without a time counts as the median), so the shards
of one hero finish together. --hero leaves out the NEUTRAL sections: they check data, assets and tools
and never start a world for the run's hero, so CI runs them once (`--neutral`, job `project` of
.github/workflows/playtest.yml) instead of once per hero. Without --hero every section is in a shard
(a local gate that runs the shards for each hero keeps its full coverage).

--windowed lists the sections with run_windowed(t) (the real-window job), spread over the shards by name.
--check is the self-test CI runs: every section is in exactly one shard, NEUTRAL names real sections, and
no NEUTRAL section calls the hero-dependent harness API (HERO_API below), so a section that starts to
depend on the hero has to leave the list. --update-timings rewrites section_seconds.json from harness
reports (tests/run_playtest.sh --report=FILE; the slowest run of a section counts).
"""
import argparse
import json
import re
import statistics
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SECTIONS_DIR = ROOT / "tests/sections"
TIMINGS = Path(__file__).resolve().with_name("section_seconds.json")
SIMULATIONS = {"combat_acceptance", "dungeon_fights"}

# Run once, with the default hero. Each one reads data, assets or tools, or sets the hero it needs itself
# (cast_data, ghost_data, rarity); none starts a world for t.character.
NEUTRAL = frozenset({
    "arsenal", "art_cast_v2", "art_characters", "art_city", "art_equipment_fit", "art_festival",
    "art_forest_mother", "art_ghostfam", "art_home", "art_interiors", "art_shops", "art_style_consistency",
    "art_world_style", "cast_data", "contracts", "copy_completion", "copy_rules", "data", "data_registry",
    "dungeon_gen", "dungeon_items", "ghost_data", "loc", "npc_cast", "rarity",
})

# The harness calls whose result depends on the run's hero (tests/lib/flow.gd, drive.gd; Fresh.new_game(t)
# without a hero of its own), the screens that open over the booted world (UiAudit, the scene tree) and the
# shared test libraries that do either.
HERO_API = re.compile(
    r"\bt\.(character|character_type|start_world|new_game|ensure_world|boot|world|in_world|days|go_menu|go_to_neutral"
    r"|consume_opening|clear_scene|change_scene|tap|press|hold|release|physics|seconds)\b"
    r"|\bFresh\.new_game\(\s*t\s*(\)|,\s*\"\")|\bUiAudit\b|current_scene|/root/World|res://tests/lib/")


def section_sources():
    return {path.stem: path.read_text(encoding="utf-8") for path in sorted(SECTIONS_DIR.glob("*.gd"))
            if not path.name.startswith("_")}


def section_names():
    return sorted(section_sources())


def windowed_names():
    return sorted(name for name, src in section_sources().items() if re.search(r"^func run_windowed\(", src, re.M))


def timings():
    try:
        return {str(k): float(v) for k, v in json.loads(TIMINGS.read_text(encoding="utf-8"))["seconds"].items()}
    except (OSError, ValueError, KeyError):
        return {}


def balance(names, count, seconds):
    """Largest first, each section to the shard with the least time so far (ties: the lower shard)."""
    known = [seconds[n] for n in names if n in seconds]
    default = statistics.median(known) if known else 1.0
    cost = {n: seconds.get(n, default) for n in names}
    groups = [[] for _ in range(count)]
    load = [0.0] * count
    for name in sorted(names, key=lambda n: (-cost[n], n)):
        index = min(range(count), key=lambda i: (load[i], i))
        groups[index].append(name)
        load[index] += cost[name]
    return [sorted(group) for group in groups]


def partitions(count, pace="all", hero=False):
    names = section_names()
    if count < 1 or count > len(names):
        raise ValueError("Shard count must be between one and the number of test sections")
    if pace not in {"all", "normal", "simulation"} or not SIMULATIONS <= set(names):
        raise ValueError("Invalid pacing configuration or missing combat simulation")
    if hero:
        names = [name for name in names if name not in NEUTRAL]
    groups = balance(names, count, timings())
    return [[name for name in group if pace == "all" or ((name in SIMULATIONS) == (pace == "simulation"))]
            for group in groups]


def windowed_partitions(count):
    names = windowed_names()
    if count < 1 or count > len(names):
        raise ValueError("Shard count must be between one and the number of windowed sections")
    return [names[index::count] for index in range(count)]


def check():
    problems = []
    sources = section_sources()
    for name in sorted(NEUTRAL):
        src = sources.get(name)
        if src is None:
            problems.append("NEUTRAL names %s, which is not a section" % name)
            continue
        if not re.search(r"^func run\(", src, re.M):
            problems.append("NEUTRAL section %s has no run(t)" % name)
        code = "\n".join(line for line in src.splitlines() if not line.lstrip().startswith("#"))
        hits = sorted(set(m.group(0) for m in HERO_API.finditer(code)))
        if hits:
            problems.append("NEUTRAL section %s uses the hero-dependent harness API %s: take it off NEUTRAL in tools/ci/sections.py" % (name, hits))
    if NEUTRAL & SIMULATIONS:
        problems.append("a combat simulation cannot be NEUTRAL")
    names = set(sources)
    for count in (1, 2, 4):
        for hero in (False, True):
            want = names - NEUTRAL if hero else names
            seen = [n for pace in ("normal", "simulation") for group in partitions(count, pace, hero) for n in group]
            if sorted(seen) != sorted(want):
                problems.append("count %d hero=%s: the shards do not hold every section exactly once" % (count, hero))
    win = windowed_names()
    if sorted(n for group in windowed_partitions(4) for n in group) != win:
        problems.append("the windowed shards do not hold every windowed section exactly once")
    stale = sorted(set(timings()) - names)
    for problem in problems:
        print("FAIL " + problem)
    print("sections: %d (%d neutral, %d windowed), %d timings%s: %s" % (
        len(names), len(NEUTRAL), len(win), len(timings()),
        " (%d of sections that no longer exist: %s)" % (len(stale), ", ".join(stale)) if stale else "",
        "FAIL" if problems else "ok"))
    return 1 if problems else 0


def update_timings(paths):
    seconds = {}
    for path in paths:
        report = json.loads(Path(path).read_text(encoding="utf-8"))
        for name, stats in report.get("sections", {}).items():
            seconds[name] = max(seconds.get(name, 0.0), round(float(stats.get("ms", 0)) / 1000.0, 1))
    names = set(section_names())
    data = {"about": "Slowest measured run time of each section in seconds (tools/ci/sections.py --update-timings); "
                     "it only balances the CI shards, a missing or stale time never drops a section.",
            "seconds": {name: seconds[name] for name in sorted(seconds) if name in names}}
    TIMINGS.write_text(json.dumps(data, indent=1) + "\n", encoding="utf-8")
    print("wrote %d section times to %s" % (len(data["seconds"]), TIMINGS))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--shard", type=int)
    parser.add_argument("--count", type=int, default=4)
    parser.add_argument("--pace", choices=("all", "normal", "simulation"), default="all")
    parser.add_argument("--hero", action="store_true", help="leave out the NEUTRAL sections (they run once, see --neutral)")
    parser.add_argument("--neutral", action="store_true", help="print the sections CI runs once instead of once per hero")
    parser.add_argument("--windowed", action="store_true", help="shard the sections with run_windowed(t)")
    parser.add_argument("--check", action="store_true", help="self-test of the partition and the NEUTRAL list")
    parser.add_argument("--update-timings", nargs="+", metavar="REPORT", help="rewrite section_seconds.json from harness reports")
    args = parser.parse_args()
    if args.check:
        return check()
    if args.update_timings:
        return update_timings(args.update_timings)
    if args.neutral:
        print(",".join(sorted(NEUTRAL)))
        return 0
    if args.shard is None:
        parser.error("--shard is required")
    groups = windowed_partitions(args.count) if args.windowed else partitions(args.count, args.pace, args.hero)
    if not 0 <= args.shard < len(groups):
        parser.error("Shard index is outside the configured range")
    print(",".join(groups[args.shard]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
