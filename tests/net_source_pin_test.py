#!/usr/bin/env python3
"""Real archived inputs bound to an independent, explicit run source contract."""
import argparse
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--run', type=Path, required=True)
parser.add_argument('--expected-source-pin', required=True)
parser.add_argument('--evidence', type=Path, required=True)
parser.add_argument('--legacy-red', action='store_true', help='Replay old CLI before the explicit-pin option exists')
ARGS = parser.parse_args()
ARGS.evidence.mkdir(parents=True, exist_ok=False)
REPORTS = [json.loads((ARGS.run / (role + '.json')).read_text()) for role in ('host', 'guest1', 'guest2')]
SPEC = importlib.util.spec_from_file_location('net_loop', ROOT / 'tests/run_net_loop.py')
assert SPEC is not None and SPEC.loader is not None
NET = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NET)

class SourcePinTests(unittest.TestCase):
    def test_actual_cli_source_contract(self):
        mutations = [('positive', None), ('missing', 'omit'), ('null', None), ('bool', False), ('object', {}), ('empty', ''), ('malformed', 'not-a-sha256'), ('wrong-valid', '0' * 64)]
        receipts = []
        for label, value in mutations:
            reports = copy.deepcopy(REPORTS)
            if label != 'positive':
                for report in reports:
                    if label == 'missing':
                        del report['source_pin']
                    else:
                        report['source_pin'] = value
            for mode, payload in [('report', reports[0]), ('participants', reports)]:
                with self.subTest(label=label, mode=mode):
                    path = ARGS.evidence / (label + '-' + mode + '.json')
                    path.write_text(json.dumps(payload, indent=2))
                    argv = [sys.executable, str(ROOT / 'tests/run_net_loop.py'), '--verify-' + mode, str(path), '--count', '3', '--phase', 'save', '--case', 'area_lifetime']
                    if not ARGS.legacy_red:
                        argv += ['--expected-source-pin', ARGS.expected_source_pin]
                    result = subprocess.run(argv, capture_output=True, text=True)
                    row = {'label': label, 'mode': mode, 'argv': argv, 'expected_source_pin': ARGS.expected_source_pin, 'expected_exit': 0 if label == 'positive' else 1, 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr}
                    receipts.append(row)
                    (ARGS.evidence / 'commands.json').write_text(json.dumps(receipts, indent=2))
                    self.assertEqual(row['exit'], row['expected_exit'], result.stdout + result.stderr)

    def test_shared_reconciler_contract(self):
        if ARGS.legacy_red:
            self.skipTest('new explicit interface is not installed in the starting source')
        self.assertEqual(NET.reconcile_participants(REPORTS, ['host', 'guest1', 'guest2'], ARGS.expected_source_pin), [])
        for value in (None, False, {}, '', 'not-a-sha256', '0' * 64):
            reports = copy.deepcopy(REPORTS)
            for report in reports:
                report['source_pin'] = value
            with self.subTest(value=value):
                problems = NET.reconcile_participants(reports, ['host', 'guest1', 'guest2'], ARGS.expected_source_pin)
                self.assertTrue(any('source' in p for p in problems), problems)
        for expected in (None, False, {}, '', 'bad'):
            with self.subTest(expected=expected):
                self.assertTrue(NET.reconcile(REPORTS[0], 'host', expected))

unittest.main(argv=[__file__])
