#!/usr/bin/env python3
"""Mutate a real successful engine report; reject incomplete/malformed evidence."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("net_loop", Path(__file__).with_name("run_net_loop.py"))
assert SPEC is not None and SPEC.loader is not None
NET = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NET)
parser = argparse.ArgumentParser()
parser.add_argument("--report", required=True, type=Path)
parser.add_argument("--expected-source-pin", required=True)
ARGS = parser.parse_args()
VALID = json.loads(ARGS.report.read_text())


class EvidenceTests(unittest.TestCase):
    def test_real_positive(self):
        self.assertEqual(NET.reconcile(VALID, VALID["role"], ARGS.expected_source_pin), [])

    def test_bad_ordinals(self):
        for value in (None, True, False, 1.0, -1, 0, "1", 9):
            with self.subTest(value=value):
                mutant = copy.deepcopy(VALID)
                mutant["checks"][0]["ordinal"] = value
                self.assertTrue(NET.reconcile(mutant, VALID["role"], ARGS.expected_source_pin))

    def test_missing_ordinal(self):
        mutant = copy.deepcopy(VALID)
        del mutant["checks"][0]["ordinal"]
        self.assertTrue(NET.reconcile(mutant, VALID["role"], ARGS.expected_source_pin))

    def test_bad_counts(self):
        for value in (None, True, False, 3.0, -1, 0, "3", 5):
            with self.subTest(value=value):
                mutant = copy.deepcopy(VALID)
                mutant["count"] = value
                self.assertTrue(NET.reconcile(mutant, VALID["role"], ARGS.expected_source_pin))

    def test_missing_required_assertion(self):
        mutant = copy.deepcopy(VALID)
        mutant["checks"].pop()
        self.assertTrue(NET.reconcile(mutant, VALID["role"], ARGS.expected_source_pin))

    def test_malformed_peer_ids(self):
        for value in (True, None, 1.0, -1, "1"):
            with self.subTest(value=value):
                mutant = copy.deepcopy(VALID)
                mutant["details"]["view"][0]["peer"] = value
                self.assertTrue(NET.reconcile(mutant, VALID["role"], ARGS.expected_source_pin))

    def test_duplicate_roster(self):
        mutant = copy.deepcopy(VALID)
        mutant["details"]["view"][1] = copy.deepcopy(mutant["details"]["view"][0])
        self.assertTrue(NET.reconcile(mutant, VALID["role"], ARGS.expected_source_pin))

    def test_unregistered_body(self):
        mutant = copy.deepcopy(VALID)
        mutant["details"]["view"][0]["registered"] = False
        self.assertTrue(NET.reconcile(mutant, VALID["role"], ARGS.expected_source_pin))


unittest.main(argv=[__file__])
