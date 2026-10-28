#!/usr/bin/env python3
"""Unit controls using supplied real engine evidence; mutations are explicit negatives.
Run: python3 tests/tools/scoped_input_supervisor_test.py EVIDENCE_ROOT
"""
import json
import copy
import shutil
import os
from pathlib import Path
import sys
import tempfile
import unittest
from scoped_input_supervisor import judge, ledger_issues

ROOT = Path(sys.argv.pop(1))
REPORT = ROOT / "guard-complete-controls.json"
LEDGER = ROOT / "guard-complete-controls-ledgers/held_owned.jsonl"


class SupervisorControls(unittest.TestCase):
    def _assert_row_mutants(self, values, specific_reason):
        ledger = Path(os.environ.get("SCOPED_INPUT_ORDINAL_LEDGER", str(ROOT / "final-acceptance-controls-ledgers/owned.jsonl")))
        report = Path(os.environ.get("SCOPED_INPUT_ORDINAL_REPORT", str(ROOT / "final-acceptance-controls.json")))
        original = [json.loads(line) for line in ledger.read_text().splitlines()]
        self.assertEqual(judge(report, 0, [ledger]), [])
        self.assertEqual([row["kind"] for row in original], ["begin", "event", "event", "close"])
        with tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"]) as directory:
            for index in range(len(original)):
                for label, value in values(index + 1):
                    with self.subTest(record=index + 1, variant=label):
                        rows = copy.deepcopy(original)
                        if label == "missing":
                            del rows[index]["row"]
                        else:
                            rows[index]["row"] = value
                        path = Path(directory) / ("row_" + str(index + 1) + "_" + label + ".jsonl")
                        path.write_text("\n".join(json.dumps(row) for row in rows) + "\n")
                        if os.environ.get("SCOPED_INPUT_MUTANT_DIR"):
                            archive = Path(os.environ["SCOPED_INPUT_MUTANT_DIR"])
                            archive.mkdir(parents=True, exist_ok=True)
                            shutil.copyfile(path, archive / path.name)
                        issues = ledger_issues(path)
                        if specific_reason:
                            self.assertEqual(issues, ["invalid_row_ordinal"])
                        else:
                            self.assertTrue(issues)
                        self.assertTrue(judge(report, 0, [path]))

    def test_boolean_and_whole_float_row_ordinals_fail_closed(self):
        self._assert_row_mutants(lambda ordinal: [("true", True), ("false", False), ("whole_float", float(ordinal))], True)

    def test_other_malformed_row_ordinals_remain_rejected(self):
        self._assert_row_mutants(lambda ordinal: [("missing", None), ("null", None), ("string", str(ordinal)), ("zero", 0), ("negative", -1), ("array", []), ("object", {}), ("fraction", ordinal + 0.5)], False)

    def test_raw_count_types_remain_strict(self):
        original = json.loads(REPORT.read_text())
        self.assertEqual(judge(REPORT, 0, [LEDGER]), [])
        with tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"]) as directory:
            path = Path(directory) / "labelled_raw_count_mutant.json"
            for field in ("checks", "failed", "not_judged"):
                for label, value in [("missing", None), ("null", None), ("false", False), ("true", True), ("negative", -1), ("string", "0"), ("whole_float", float(original[field])), ("array", []), ("object", {})]:
                    with self.subTest(field=field, variant=label):
                        report = copy.deepcopy(original)
                        if label == "missing":
                            del report[field]
                        else:
                            report[field] = value
                        path.write_text(json.dumps(report))
                        issues = judge(path, 0, [LEDGER])
                        reason = "raw_report_empty_or_invalid" if field == "checks" else "raw_failure_or_unjudged"
                        self.assertIn(reason, issues)

    def test_real_owned_watermark_one_positive(self):
        ledger = ROOT / "final-acceptance-controls-ledgers/owned.jsonl"
        rows = [json.loads(line) for line in ledger.read_text().splitlines()]
        for field in ("sequence", "retired"):
            self.assertIs(type(rows[-1][field]), int)
            self.assertEqual(rows[-1][field], 1)
        self.assertEqual(judge(ROOT / "final-acceptance-controls.json", 0, [ledger]), [])

    def _assert_close_mutants(self, cases):
        ledger = ROOT / "final-acceptance-controls-ledgers/owned.jsonl"
        original = [json.loads(line) for line in ledger.read_text().splitlines()]
        self.assertEqual(ledger_issues(ledger), [])
        with tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"]) as directory:
            for label, changes, removed, fields in cases:
                with self.subTest(variant=label):
                    rows = copy.deepcopy(original)
                    rows[-1].update(changes)
                    for field in removed:
                        del rows[-1][field]
                    path = Path(directory) / (label + ".jsonl")
                    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n")
                    if os.environ.get("SCOPED_INPUT_MUTANT_DIR"):
                        archive = Path(os.environ["SCOPED_INPUT_MUTANT_DIR"])
                        archive.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(path, archive / path.name)
                    issues = ledger_issues(path)
                    for field in fields:
                        self.assertIn("invalid_close_counter:" + field, issues)
                    self.assertTrue(judge(ROOT / "final-acceptance-controls.json", 0, [path]))

    def test_missing_close_watermarks_fail_closed(self):
        self._assert_close_mutants([
            ("missing_sequence", {}, ["sequence"], ["sequence"]),
            ("missing_retired", {}, ["retired"], ["retired"]),
            ("missing_both_watermarks", {}, ["sequence", "retired"], ["sequence", "retired"]),
        ])

    def test_malformed_close_counters_fail_closed(self):
        cases = []
        for field in ("sequence", "retired", "owned", "unowned", "tools", "pending"):
            cases.append(("missing_" + field, {}, [field], [field]))
            for label, value in [("null", None), ("false", False), ("true", True), ("negative", -1), ("string", "1"), ("float", 1.0), ("zero_float", 0.0), ("array", []), ("object", {})]:
                cases.append((field + "_" + label, {field: value}, [], [field]))
        self._assert_close_mutants(cases)

    def test_equal_malformed_watermarks_fail_closed(self):
        self._assert_close_mutants([
            ("both_" + label, {"sequence": value, "retired": value}, [], ["sequence", "retired"])
            for label, value in [("null", None), ("false", False), ("true", True), ("negative", -1), ("string", "1"), ("float", 1.0), ("array", []), ("object", {})]
        ])

    def test_real_owned_engine_interval(self):
        self.assertEqual(judge(REPORT, 0, [LEDGER]), [])

    def test_real_unowned_raw_green_rejected(self):
        foreign = ROOT / "guard-complete-controls-ledgers/foreign.jsonl"
        self.assertTrue(judge(REPORT, 0, [foreign]))

    def test_no_scope_duplicate_and_nonzero(self):
        self.assertTrue(judge(REPORT, 0, []))
        self.assertTrue(judge(REPORT, 0, [LEDGER, LEDGER]))
        self.assertTrue(judge(REPORT, 1, [LEDGER]))

    def test_real_failed_intervals_remain_rejected(self):
        for name in ["detached", "same_section_replaced", "wrong_section", "source_replaced", "source_detached", "source_rebound", "profile_replaced", "owner_unregistered", "owner_detached", "owner_freed", "wrong", "lost", "replayed", "lost_delivery", "closed_stream", "bounded", "same_id_old", "queued_owner", "detached_auto", "world_detached"]:
            with self.subTest(name=name):
                self.assertTrue(ledger_issues(ROOT / "guard-complete-controls-ledgers" / (name + ".jsonl")))

    def test_malformed_raw_shapes_fail_closed(self):
        with tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"]) as directory:
            path = Path(directory) / "mutant.json"
            for value in [[], None, True, {}, {"checks": True, "failed": 0, "not_judged": 0, "engine": [], "known": [], "problems": [], "failures": []}]:
                with self.subTest(value=value):
                    path.write_text(json.dumps(value))
                    self.assertTrue(judge(path, 0, [LEDGER]))

    def test_actual_ledger_mutants(self):
        original = LEDGER.read_text()
        rows = [json.loads(line) for line in original.splitlines()]
        with tempfile.TemporaryDirectory(dir=os.environ["TMPDIR"]) as directory:
            path = Path(directory) / "mutant.jsonl"
            for text in [original[:-2], "\n".join(original.splitlines()[:-1]) + "\n", "{}\n", "\n"]:
                path.write_text(text)
                self.assertTrue(ledger_issues(path))
            rows[-1]["owned"] += 1
            path.write_text("\n".join(json.dumps(row) for row in rows) + "\n")
            self.assertTrue(ledger_issues(path))


if __name__ == "__main__":
    unittest.main(verbosity=2)
