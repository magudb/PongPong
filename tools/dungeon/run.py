#!/usr/bin/env python3
"""Run a dungeon data driver with an isolated user directory and honest exit status."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
ROOT = Path(__file__).resolve().parents[2]

def main():
    driver, *args = sys.argv[1:]
    if driver not in {"stress", "find_fallback", "inspect"}:
        raise SystemExit("expected stress, find_fallback or inspect")
    with tempfile.TemporaryDirectory(prefix="traetoppen-dungeon-") as user_dir:
        env = dict(os.environ, HOME=user_dir)
        command = [os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot"), "--headless", "--path", str(ROOT), "-s", f"res://tools/dungeon/{driver}.gd", "--", *args]
        result = subprocess.run(command, env=env, cwd=ROOT)
        return result.returncode

if __name__ == "__main__":
    raise SystemExit(main())
