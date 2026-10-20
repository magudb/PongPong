#!/usr/bin/env python3
"""Markdown table of harness reports (tests/run_playtest.sh --report=FILE) for the CI job summary.

    tools/ci/report_summary.py REPORT.json [REPORT.json ...] >> "$GITHUB_STEP_SUMMARY"

One row per report: mode, hero, result, checks, failed and skipped checks, slow timings, run time. The skip
column is the number to watch: a headless run skips every pixel check (they run in the windowed job), and a
skip that appears in a new place is a check that stopped running. A missing report (the run never wrote one)
is a row too. Always exits 0: the harness exit code is the gate, this is only the overview.
"""
import json
import sys
from pathlib import Path


def row(path):
    try:
        report = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        return "| %s | | | no report (%s) | | | | | |" % (Path(path).name, type(error).__name__)
    return "| %s | %s | %s | %s | %d | %d | %d | %d | %.0f s |" % (
        Path(path).name, report.get("mode", ""), report.get("character", ""), report.get("result", ""),
        int(report.get("checks", 0)), int(report.get("failed", 0)), int(report.get("skipped", 0)),
        len(report.get("slow", [])), float(report.get("elapsed_s", 0.0)))


def main(paths):
    print("| report | mode | hero | result | checks | failed | skipped | slow | time |")
    print("|---|---|---|---|---:|---:|---:|---:|---:|")
    for path in paths:
        print(row(path))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
