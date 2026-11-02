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
