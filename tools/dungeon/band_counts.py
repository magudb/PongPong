#!/usr/bin/env python3
"""Count marker instances exported from the live Lua table, using its runtime parser."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="dungeon-counts-") as directory:
    subprocess.run([sys.executable,str(ROOT/"tools/dungeon/run.py"),"inspect","out="+directory],check=True,stdout=subprocess.DEVNULL)
    print(json.dumps(json.loads((Path(directory)/"band_counts.json").read_text()),indent=2))
