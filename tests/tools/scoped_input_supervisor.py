#!/usr/bin/env python3
"""Additive opt-in quality gate. Never edits/normalizes the raw playtest report.

Usage: python3 tests/tools/scoped_input_supervisor.py --raw-report=FILE
       --raw-exit=N --ledger=FILE [--ledger=FILE ...] [--output=FILE]
Original assertion/skip/allowance/source reconciliation remains independently required.
A clean scripted ledger does not establish an exclusive native/hardware input session.
"""
import argparse
import json
from pathlib import Path

MAX_ROWS = 4096
MAX_BYTES = 16 * 1024 * 1024


def ledger_issues(path: Path) -> list[str]:
    """Validate a bounded, fully flushed observer interval and its event totals."""
    try:
        if path.stat().st_size > MAX_BYTES:
            return ["ledger_byte_bound_exceeded"]
        rows = [json.loads(line) for line in path.read_text().splitlines()]
    except (OSError, ValueError):
        return ["ledger_missing_or_invalid"]
    if not 2 <= len(rows) <= MAX_ROWS or any(not isinstance(r, dict) for r in rows):
        return ["ledger_row_bound_or_shape"]
    if any(type(r.get("row")) is not int or r["row"] <= 0 for r in rows):
        return ["invalid_row_ordinal"]
    if [r.get("row") for r in rows] != list(range(1, len(rows) + 1)):
        return ["ledger_sequence_gap"]
    if rows[0].get("kind") != "begin" or rows[-1].get("kind") != "close":
        return ["ledger_not_closed"]
    if any(r.get("kind") not in {"event", "tool"} for r in rows[1:-1]):
        return ["ledger_unexpected_record"]
    final = rows[-1]
    issues = [
        "invalid_close_counter:" + field
        for field in ("sequence", "retired", "owned", "unowned", "tools", "pending")
        if type(final.get(field)) is not int or final[field] < 0
    ]
    if issues:
        return issues
    if final.get("accepted") is not True or final.get("closed") is not True or final.get("first_failure") != "":
        issues.append("interval_rejected:" + str(final.get("first_failure")))
    events = [r for r in rows if r.get("kind") == "event"]
    owned = sum(r.get("owned") is True for r in events)
    unowned = sum(r.get("owned") is not True for r in events)
    tools = sum(r.get("kind") == "tool" for r in rows)
    if unowned or final.get("unowned") != 0:
        issues.append("unowned_physical_event")
    if owned == 0 or final.get("owned") != owned or final.get("tools") != tools:
        issues.append("observation_totals_mismatch_or_empty")
    if final.get("pending") != 0 or final.get("sequence") != final.get("retired"):
        issues.append("owned_delivery_missing")
    return issues


def judge(raw_report: Path, raw_exit: int, ledgers: list[Path]) -> list[str]:
    issues = []
    if raw_exit != 0:
        issues.append("raw_exit_nonzero")
    try:
        report = json.loads(raw_report.read_text())
        if not isinstance(report, dict):
            issues.append("raw_report_empty_or_invalid")
            report = {}
        if type(report.get("checks")) is not int or report["checks"] <= 0:
            issues.append("raw_report_empty_or_invalid")
        if any(type(report.get(k)) is not int or report.get(k) != 0 for k in ("failed", "not_judged")):
            issues.append("raw_failure_or_unjudged")
        if any(report.get(k) != [] for k in ("engine", "known", "problems", "failures")):
            issues.append("raw_diagnostics")
    except (OSError, ValueError):
        issues.append("raw_report_missing_or_invalid")
    if not ledgers or len(ledgers) != len(set(ledgers)):
        issues.append("ledger_set_empty_or_duplicate")
    for path in ledgers:
        issues.extend(str(path) + ":" + issue for issue in ledger_issues(path))
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-report", type=Path, required=True)
    parser.add_argument("--raw-exit", type=int, required=True)
    parser.add_argument("--ledger", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    issues = judge(args.raw_report, args.raw_exit, args.ledger)
    result = {"accepted": not issues, "issues": issues, "raw_report": str(args.raw_report), "raw_exit": args.raw_exit, "ledgers": [str(p) for p in args.ledger]}
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")
    return int(bool(issues))


if __name__ == "__main__":
    raise SystemExit(main())
