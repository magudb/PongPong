#!/usr/bin/env python3
"""Farming scenario adapter; reuse the pinned ENet supervisor and its contracts."""
import argparse
import contextlib
import ctypes
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace
import run_net_loop as loop

FARM_IDS = {"farm_intent_available", "farm_till_applied", "farm_till_cost_owner", "farm_till_replicated", "farm_plant_applied", "farm_plant_cost_owner", "farm_plant_replicated"}
FARM_IDS |= {"farm_water_applied", "farm_water_cost_owner", "farm_water_replicated"}
FARM_IDS |= {"farm_growth_ready", "farm_harvest_applied", "farm_harvest_reward_owner", "farm_harvest_replicated"}
FARM_IDS |= {"farm_replay_refused_once", "farm_authoritative_range", "farm_insufficient_stamina", "farm_area_refused", "farm_flying_refused", "farm_forged_actor_refused", "farm_stale_epoch_refused", "farm_insufficient_seeds"}
FARM_IDS.add("farm_result_immutable")
FARM_IDS.add("farm_cooldown_bounds_mutation")
FARM_IDS.add("farm_rate_quota_bounded")
FARM_IDS.add("farm_closed_bounded_schema")
_original_required = loop.required_assertions
_original_popen = subprocess.Popen
_original_stack = contextlib.ExitStack
_children = []


def required_assertions(phase, role, case="normal"):
    if case == "farm_close":
        common = {"isolated_user_data", "transport_started", "application_admitted", "successor_progress", "all_counterparts_done"}
        return common if role == "host" else common | {"nonempty_projection_ready", "close_callback_executed", "offline_immediate_integrity", "offline_unwound_integrity", "retired_snapshot_serial_zero", "retired_notifications_stop", "offline_late_integrity", "successor_transport_started", "successor_admitted", "successor_close_preserves_offline"}
    return _original_required("admission", role, "normal") | FARM_IDS | ({"farm_callback_replay_denied"} if role == "host" else {"farm_guest_no_economic_replay", "farm_guest_projection_only", "farm_guest_no_save"})


class FarmPopen(_original_popen):
    def __init__(self, args, *rest, **kwargs):
        # Keep the supervisor's command receipt identical to the actual argv.
        for i, value in enumerate(args):
            if value == "res://tests/acceptance/net_peer.gd":
                args[i] = "res://tests/acceptance/net_farm_close_peer.gd" if "--case=farm_close" in args else "res://tests/acceptance/net_farm_peer.gd"
        super().__init__(args, *rest, **kwargs)
        if any(script in args for script in ("res://tests/acceptance/net_farm_peer.gd", "res://tests/acceptance/net_farm_close_peer.gd")):
            _children.append(self)


class FarmExitStack(_original_stack):
    def __exit__(self, *exc):
        # The inherited supervisor releases its ExitStack before its finally.
        # Settle owned peers first on EVERY failure, while leases remain held.
        try:
            for child in _children:
                if child.poll() is None:
                    child.terminate()
                    try:
                        child.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        child.kill()
                        child.wait(timeout=5)
        finally:
            suppressed = super().__exit__(*exc)
        return suppressed


def clone_tree(source, destination):
    """APFS clone regular files; never follow symlinks or copy credentials/envs."""
    libc = ctypes.CDLL(None, use_errno=True)
    clone = libc.clonefile
    clone.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
    for root, dirs, files in os.walk(source, followlinks=False):
        dirs[:] = [d for d in dirs if d not in (".git", ".venv", "__pycache__", "docs") and not (Path(root) / d).is_symlink()]
        target = destination / Path(root).relative_to(source)
        target.mkdir(parents=True, exist_ok=True)
        for name in files:
            src, dst = Path(root) / name, target / name
            if src.is_symlink() or dst.exists() or name == ".git":
                continue
            if clone(os.fsencode(src), os.fsencode(dst), 0):
                raise OSError(ctypes.get_errno(), f"APFS clone failed: {src}")


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--scratch", type=Path)
    ap.add_argument("--count", type=int, default=2)
    ap.add_argument("--warm-cache", type=Path)
    args, _ = ap.parse_known_args()
    if args.warm_cache:
        if args.scratch is None:
            raise ValueError("warming requires scratch")
        for role in ["host"] + [f"guest{i}" for i in range(1, args.count)]:
            base = args.scratch.resolve() / "peers" / role
            base.mkdir(parents=True, exist_ok=True)
            with (base / "runtime.lock").open("a+") as lease:
                fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
                clone_tree(loop.ROOT, base / "project")
                clone_tree(args.warm_cache.resolve(), base / "project" / ".godot")
        i = sys.argv.index("--warm-cache")
        del sys.argv[i:i + 2]
    loop.required_assertions = required_assertions
    # Only the script entrypoint changes. Original argv, HOME, source pin,
    # deadlines, exact participant reconciliation and diagnostic policy remain.
    loop.subprocess = SimpleNamespace(Popen=FarmPopen, run=subprocess.run, TimeoutExpired=subprocess.TimeoutExpired, STDOUT=subprocess.STDOUT)
    loop.contextlib = SimpleNamespace(ExitStack=FarmExitStack)
    rc = loop.main()
    if args.scratch is not None:
        # Audit setup and sandbox logs too, not only the inherited peer console.
        argv = sys.argv
        label = argv[argv.index("--label") + 1] if "--label" in argv else next((a.split("=", 1)[1] for a in argv if a.startswith("--label=")), "")
        if label:
            run = args.scratch.resolve() / label
            records = {}
            for file in [*run.glob("*-import.log"), *run.glob("homes/**/*.log")]:
                matches = [line for line in file.read_text(errors="replace").splitlines() if any(mark in line for mark in ("SCRIPT ERROR:", "ERROR:", "WARNING:", "handle_crash:", "Program crashed"))]
                if matches:
                    records[str(file.relative_to(run))] = matches
            audit = {"supervisor_exit": rc, "raw_diagnostics": records, "ok": rc == 0 and not records}
            (run / "farm-audit.json").write_text(json.dumps(audit, indent=2))
            if records:
                print(json.dumps(audit, indent=2))
            rc = 0 if audit["ok"] else 1
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
