#!/usr/bin/env python3
"""Real-report CLI controls for reviewed participant ownership defects."""
import argparse
import copy
import importlib.util
import json
import sys
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--run', type=Path, required=True)
parser.add_argument('--evidence', type=Path, required=True)
parser.add_argument('--expected-source-pin', required=True)
ARGS = parser.parse_args()
ARGS.evidence.mkdir(exist_ok=False, parents=True)
HOST = json.loads((ARGS.run / 'host.json').read_text())

class ParticipantTests(unittest.TestCase):
    def cli(self, label, report, expected):
        path = ARGS.evidence / (label + '.json')
        path.write_text(json.dumps(report, indent=2))
        mode = ['--verify-participants', str(path)] if isinstance(report, list) else ['--verify-report', str(path), '--role', report['role']]
        argv = [sys.executable, str(ROOT / 'tests/run_net_loop.py'), *mode, '--count', str(HOST['count']), '--phase', HOST['phase'], '--case', HOST['case'], '--expected-source-pin', ARGS.expected_source_pin]
        record = {'argv': argv, 'expected_exit': expected}
        receipt = ARGS.evidence / (label + '-command.json')
        receipt.write_text(json.dumps(record, indent=2))
        result = subprocess.run(argv, capture_output=True, text=True)
        record.update(exit=result.returncode, stdout=result.stdout, stderr=result.stderr)
        receipt.write_text(json.dumps(record, indent=2))
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def test_real_host_cli_positive(self):
        self.cli('real-host', HOST, 0)

    def test_impossible_host_local_guest_cli(self):
        mutant = copy.deepcopy(HOST)
        target = next(b for b in mutant['details']['view'] if b['id'] == 'p1')
        mutant['details']['self_peer'] = target['peer']
        for body in mutant['details']['view']:
            body['local'] = body['camera'] = body['id'] == 'p1'
        self.cli('labelled-impossible-host-local-p1', mutant, 1)

    def reports(self):
        return [json.loads((ARGS.run / (role + '.json')).read_text())
                for role in ['host'] + [f'guest{i}' for i in range(1, HOST['count'])]]

    def test_real_participants_cli_positive(self):
        self.cli('real-participants', self.reports(), 0)

    def test_disagreeing_guest_map_cli(self):
        reports = self.reports()
        remote = next(body for body in reports[1]['details']['view'] if body['id'] != 'p0' and not body['local'])
        remote['peer'] = max(body['peer'] for body in HOST['details']['view']) + 17
        self.cli('labelled-disagreeing-guest-map', reports, 1)

    def test_swapped_guest_peer_slots_cli(self):
        reports = self.reports()
        view = reports[1]['details']['view']
        first = next(b for b in view if b['id'] == 'p1')
        second = next(b for b in view if b['id'] == 'p2')
        first['peer'], second['peer'] = second['peer'], first['peer']
        reports[1]['details']['self_peer'] = next(b['peer'] for b in view if b['local'])
        self.cli('labelled-swapped-guest-peer-slots', reports, 1)

    def test_missing_participant_cli(self):
        self.cli('labelled-missing-participant', self.reports()[:-1], 1)

    def test_duplicate_participant_cli(self):
        reports = self.reports()
        reports[-1] = copy.deepcopy(reports[1])
        self.cli('labelled-duplicate-participant', reports, 1)

unittest.main(argv=[__file__])
