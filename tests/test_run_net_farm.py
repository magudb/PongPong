"""Adapter seam regressions; real connected reports are exercised separately."""
import contextlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

import run_net_farm as farm


class AdapterTests(unittest.TestCase):
    def test_actual_argv_and_retained_command_are_identical(self):
        cmd = [sys.executable, "-c", "import json,sys; print(json.dumps(sys.argv[1:]))", "res://tests/acceptance/net_peer.gd"]
        with farm.FarmPopen(cmd, stdout=subprocess.PIPE, text=True) as child:
            actual = json.loads(child.communicate(timeout=5)[0])
        self.assertEqual(child.returncode, 0)
        self.assertEqual(actual, ["res://tests/acceptance/net_farm_peer.gd"])
        self.assertEqual(cmd[-1], actual[0])

    def test_input_cases_dispatch_and_contract(self):
        for count in (2, 4):
            case = f"farm_input_{count}"
            cmd = [sys.executable, "-c", "import json,sys; print(json.dumps(sys.argv[1:]))", "res://tests/acceptance/net_peer.gd", f"--case={case}"]
            with farm.FarmPopen(cmd, stdout=subprocess.PIPE, text=True) as child:
                actual = json.loads(child.communicate(timeout=5)[0])
            self.assertEqual(child.returncode, 0)
            self.assertEqual(actual, ["res://tests/acceptance/net_farm_input_peer.gd", f"--case={case}"])
            self.assertEqual(cmd[-2:], actual)
            self.assertIn(child, farm._children)
            for role in ["host"] + [f"guest{i}" for i in range(1, count)]:
                ids = farm.required_assertions("movement", role, case)
                for actor in range(1, count):
                    self.assertIn(f"guest{actor}_input_till", ids)
                    self.assertIn(f"guest{actor}_input_gate_departure", ids)
                    self.assertIn(f"guest{actor}_input_near_click", ids)
                self.assertNotIn(f"guest{count}_input_till", ids)
                self.assertEqual("input_guest_no_save" in ids, role != "host")

    def test_owned_peers_settle_before_lease_release_on_failure(self):
        stack_type = getattr(farm, "FarmExitStack", None)
        self.assertIsNotNone(stack_type)
        child = None
        release_observations = []
        with self.assertRaisesRegex(RuntimeError, "fixture failure"):
            with stack_type() as stack:
                stack.callback(lambda: release_observations.append(child.poll()))
                cmd = [sys.executable, "-c", "import time; time.sleep(30)", "res://tests/acceptance/net_peer.gd"]
                child = farm.FarmPopen(cmd)
                raise RuntimeError("fixture failure")
        self.assertIsNotNone(child.poll())
        self.assertEqual(release_observations, [child.returncode])


if __name__ == "__main__":
    unittest.main()
